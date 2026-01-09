# Windows 11 Pro 설정 스크립트
# 관리자 권한으로 실행 필요
# 설정: 수동 업데이트, 자동 재시작 방지, UAC 프롬프트 비활성화

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "001.disable_update.ps1"

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Progress Bar 비활성화 (병렬 실행 시 출력 겹침 방지)
$ProgressPreference = 'SilentlyContinue'

# Orchestrate 모드 확인
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

# ForceOverride 모드 확인 (이미 적용된 설정도 강제 재적용)
if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_001_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir $logFileName
$global:LogEntries = [System.Collections.ArrayList]@()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Step,
        [string]$Status,
        [string]$Message,
        [string]$PreviousValue = "",
        [string]$NewValue = ""
    )

    $entry = [PSCustomObject]@{
        Timestamp = Get-Date -Format "HH:mm:ss"
        Step = $Step
        Status = $Status
        Message = $Message
        PreviousValue = $PreviousValue
        NewValue = $NewValue
    }

    [void]$global:LogEntries.Add($entry)

    switch ($Status) {
        "적용됨" { $global:AppliedCount++ }
        "스킵됨" { $global:SkippedCount++ }
        "실패" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osVersion = if ($osInfo) { "$($osInfo.Caption) (Build $($osInfo.BuildNumber))" } else { "Unknown" }

    $logContent = @"
================================================================================
Windows 11 Optimization Log
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
스크립트: $scriptName v$scriptVersion
OS: $osVersion
================================================================================

================================================================================
단계별 결과
================================================================================

"@

    foreach ($entry in $global:LogEntries) {
        $logContent += "[$($entry.Timestamp)] [$($entry.Step)]`n"
        $logContent += "  상태: $($entry.Status)`n"
        $logContent += "  내용: $($entry.Message)`n"
        if ($entry.PreviousValue) {
            $logContent += "  이전값: $($entry.PreviousValue)`n"
        }
        if ($entry.NewValue) {
            $logContent += "  새값: $($entry.NewValue)`n"
        }
        $logContent += "`n"
    }

    $logContent += @"
================================================================================
Summary
================================================================================
총 항목: $($global:AppliedCount + $global:SkippedCount + $global:FailedCount)
적용됨: $global:AppliedCount
스킵됨: $global:SkippedCount (이미 최적 설정)
실패: $global:FailedCount

로그 파일: $global:LogFilePath
================================================================================
"@

    $logContent | Set-Content -Path $global:LogFilePath -Encoding UTF8
}

# ===== 공통 함수 =====
function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$StepName,
        [string]$Description = ""
    )

    # 경로 생성
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    # 현재 값 확인
    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name

    # ForceOverride가 아니고 현재 값이 목표 값과 같으면 스킵
    if (-not $global:ForceOverride -and $currentValue -eq $Value) {
        $msg = if ($Description) { "$Description : 이미 설정됨" } else { "$Name : 이미 설정됨" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "$Name 이미 최적값" -PreviousValue "$currentValue" -NewValue "$Value"
        return $false
    }

    # 값 설정
    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        $prevDisplay = if ($null -eq $currentValue) { "(없음)" } else { $currentValue }
        $msg = if ($Description) { "$Description : $prevDisplay → $Value" } else { "$Name : $prevDisplay → $Value" }
        Write-Host "  - $msg (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "$Name 변경됨" -PreviousValue "$prevDisplay" -NewValue "$Value"
        return $true
    } catch {
        $msg = if ($Description) { "$Description : 설정 실패" } else { "$Name : 설정 실패" }
        Write-Host "  - $msg" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "$Name 설정 실패: $_"
        return $false
    }
}

# ===== 메인 스크립트 시작 =====

Write-Host "=== Windows 11 Pro 설정 스크립트 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "Windows Update 수동 설정, 자동 재시작 방지, UAC 프롬프트 비활성화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 3


# [1/3] Windows Update 정책 설정 (레지스트리)
Write-Host "[1/$totalSteps] Windows Update 정책 설정 중..." -ForegroundColor Yellow

$WUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$step1Name = "Windows Update 정책"

# 자동 업데이트 구성: 2 = 다운로드 및 설치 알림 (수동)
Set-RegistryIfDifferent -Path $WUPath -Name "AUOptions" -Value 2 -StepName $step1Name -Description "AUOptions (2=수동)"

# 자동 업데이트 활성화 (정책 적용을 위해)
Set-RegistryIfDifferent -Path $WUPath -Name "NoAutoUpdate" -Value 0 -StepName $step1Name -Description "NoAutoUpdate (0=정책 적용)"

# 로그온 사용자 있을 때 자동 재시작 안 함
Set-RegistryIfDifferent -Path $WUPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -StepName $step1Name -Description "NoAutoRebootWithLoggedOnUsers (1=비활성화)"


# [2/3] 추가 Windows Update 설정
Write-Host ""
Write-Host "[2/$totalSteps] 추가 업데이트 설정 중..." -ForegroundColor Yellow

$WUSettingsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
$step2Name = "추가 업데이트 설정"

# 예약된 설치 비활성화
Set-RegistryIfDifferent -Path $WUSettingsPath -Name "AUOptions" -Value 2 -StepName $step2Name -Description "AUOptions (2=수동)"


# [3/3] UAC (사용자 계정 컨트롤) 프롬프트 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] UAC 프롬프트 비활성화 중..." -ForegroundColor Yellow

$UACPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$step3Name = "UAC 설정"

# EnableLUA는 1로 유지 (완전 해제 시 로그인 문제, UI 오류 발생 가능)
Set-RegistryIfDifferent -Path $UACPath -Name "EnableLUA" -Value 1 -StepName $step3Name -Description "EnableLUA (1=UAC 활성화 유지)"

# UAC 프롬프트 동작 설정
# 관리자: 0 = 알림 없이 권한 상승 (편의성)
Set-RegistryIfDifferent -Path $UACPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -StepName $step3Name -Description "ConsentPromptBehaviorAdmin (0=알림 없음)"

# 일반 사용자: 3 = 자격 증명 요청 (보안 유지)
Set-RegistryIfDifferent -Path $UACPath -Name "ConsentPromptBehaviorUser" -Value 3 -StepName $step3Name -Description "ConsentPromptBehaviorUser (3=자격 증명 요청)"

# 보안 데스크톱에서 프롬프트 표시 안 함
Set-RegistryIfDifferent -Path $UACPath -Name "PromptOnSecureDesktop" -Value 0 -StepName $step3Name -Description "PromptOnSecureDesktop (0=비활성화)"


# ===== 로그 저장 =====
Save-OptLog


# ===== 완료 메시지 =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount 개" -ForegroundColor $(if ($global:FailedCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor Cyan
Write-Host ""
Write-Host "변경 사항을 적용하려면 재부팅이 필요합니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인
if (-not $global:OrchestrateMode) {
    $restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        Write-Host "10초 후 재부팅됩니다..." -ForegroundColor Red
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        Write-Host "나중에 수동으로 재부팅해주세요." -ForegroundColor Yellow
    }
}
