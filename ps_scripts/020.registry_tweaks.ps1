# Windows 11 레지스트리 미세 조정 스크립트
# 메뉴 지연 제거, 앱 응답 시간, IRPStackSize, LongPaths 등 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

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

# ForceOverride 모드 확인
if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

# 스크립트 버전
$scriptVersion = "1.1.0"
$scriptName = "020.registry_tweaks.ps1"

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_020_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
    $logContent = @()
    $logContent += "===== Windows 11 Optimizer Log ====="
    $logContent += "스크립트: $scriptName v$scriptVersion"
    $logContent += "실행 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $logContent += "====================================="
    $logContent += ""
    foreach ($entry in $global:LogEntries) {
        $line = "[$($entry.Timestamp)] [$($entry.Status)] $($entry.Step): $($entry.Message)"
        if ($entry.PreviousValue -or $entry.NewValue) {
            $line += " ($($entry.PreviousValue) -> $($entry.NewValue))"
        }
        $logContent += $line
    }
    $logContent += ""
    $logContent += "===== Summary ====="
    $logContent += "적용됨: $global:AppliedCount"
    $logContent += "스킵됨: $global:SkippedCount"
    $logContent += "실패: $global:FailedCount"
    $logContent | Out-File -FilePath $global:LogFilePath -Encoding UTF8
}

function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord",
        [string]$StepName
    )
    try {
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
        if (-not $global:ForceOverride -and $currentValue -eq $Value) {
            Write-Host "  - $StepName : 이미 설정됨 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 최적 설정" -PreviousValue "$currentValue" -NewValue "$Value"
            return $false
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        Write-Host "  - $StepName : $currentValue → $Value (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "레지스트리 변경" -PreviousValue "$currentValue" -NewValue "$Value"
        return $true
    } catch {
        Write-Host "  - $StepName : 설정 실패" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "$_"
        return $false
    }
}

Write-Host "=== Windows 11 레지스트리 미세 조정 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "메뉴 지연 제거, 앱 응답 시간 최적화, 네트워크 성능 향상 등을 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 7

# [1/7] 메뉴 지연 제거 (MenuShowDelay)
Write-Host "[1/$totalSteps] 메뉴 지연 제거 중..." -ForegroundColor Yellow

$desktopPath = "HKCU:\Control Panel\Desktop"

Set-RegistryIfDifferent -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Type String -StepName "MenuShowDelay (메뉴 표시 지연)"

# [2/7] 앱 응답 대기 시간 최적화
Write-Host ""
Write-Host "[2/$totalSteps] 앱 응답 대기 시간 최적화 중..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $desktopPath -Name "HungAppTimeout" -Value "2000" -Type String -StepName "HungAppTimeout (응답 대기 시간)"
Set-RegistryIfDifferent -Path $desktopPath -Name "WaitToKillAppTimeout" -Value "3000" -Type String -StepName "WaitToKillAppTimeout (앱 종료 대기)"

$controlPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
Set-RegistryIfDifferent -Path $controlPath -Name "WaitToKillServiceTimeout" -Value "3000" -Type String -StepName "WaitToKillServiceTimeout (서비스 종료 대기)"

# [3/7] 자동 앱 종료 활성화 (AutoEndTasks)
Write-Host ""
Write-Host "[3/$totalSteps] 자동 앱 종료 활성화 중..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $desktopPath -Name "AutoEndTasks" -Value "1" -Type String -StepName "AutoEndTasks (자동 앱 종료)"

# [4/7] 네트워크 공유 성능 향상 (IRPStackSize)
Write-Host ""
Write-Host "[4/$totalSteps] 네트워크 공유 성능 향상 중..." -ForegroundColor Yellow

$lanmanPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"

Set-RegistryIfDifferent -Path $lanmanPath -Name "IRPStackSize" -Value 20 -Type DWord -StepName "IRPStackSize (네트워크 공유 성능)"
Set-RegistryIfDifferent -Path $lanmanPath -Name "Size" -Value 3 -Type DWord -StepName "LanmanServer Size (최대 처리량)"

# [5/7] 긴 경로 지원 활성화 (LongPathsEnabled)
Write-Host ""
Write-Host "[5/$totalSteps] 긴 경로 지원 활성화 중..." -ForegroundColor Yellow

$fileSystemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

Set-RegistryIfDifferent -Path $fileSystemPath -Name "LongPathsEnabled" -Value 1 -Type DWord -StepName "LongPathsEnabled (260자 경로 제한 해제)"

# [6/7] 디스크 공간 부족 경고 비활성화 (옵션)
Write-Host ""
Write-Host "[6/$totalSteps] 기타 알림 설정 중..." -ForegroundColor Yellow

$lowDiskChoice = "N"
if (-not $global:OrchestrateMode) {
    Write-Host ""
    Write-Host "  디스크 공간 부족 경고 알림을 비활성화하시겠습니까?" -ForegroundColor Cyan
    Write-Host "  (저장 공간이 부족할 때 시스템 트레이 알림 비활성화)" -ForegroundColor Gray
    $lowDiskChoice = Read-Host "비활성화 (Y/N, 기본값: N)"
}

if ($lowDiskChoice -eq "Y" -or $lowDiskChoice -eq "y") {
    $explorerPoliciesPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    Set-RegistryIfDifferent -Path $explorerPoliciesPath -Name "NoLowDiskSpaceChecks" -Value 1 -Type DWord -StepName "NoLowDiskSpaceChecks (디스크 공간 경고)"
} else {
    Write-Host "  - 디스크 공간 부족 경고: 기본값 유지" -ForegroundColor Gray
}

# [7/7] 추가 레지스트리 미세 조정
Write-Host ""
Write-Host "[7/$totalSteps] 추가 레지스트리 미세 조정 중..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $desktopPath -Name "ForegroundLockTimeout" -Value 0 -Type DWord -StepName "ForegroundLockTimeout (포커스 즉시 전환)"
Set-RegistryIfDifferent -Path $desktopPath -Name "LowLevelHooksTimeout" -Value 1000 -Type DWord -StepName "LowLevelHooksTimeout (저수준 훅 대기)"
Set-RegistryIfDifferent -Path $desktopPath -Name "MouseHoverTime" -Value "10" -Type String -StepName "MouseHoverTime (마우스 호버 반응)"

$prioritySepPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
Set-RegistryIfDifferent -Path $prioritySepPath -Name "Win32PrioritySeparation" -Value 38 -Type DWord -StepName "Win32PrioritySeparation (포그라운드 우선)"

# SvcHostSplitThresholdInKB (RAM 기준)
$totalRAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1KB, 0)
$svcHostPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
Set-RegistryIfDifferent -Path $svcHostPath -Name "SvcHostSplitThresholdInKB" -Value $totalRAM -Type DWord -StepName "SvcHostSplitThresholdInKB (서비스 분리)"

$shellPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
Set-RegistryIfDifferent -Path $shellPath -Name "ConfirmFileDelete" -Value 0 -Type DWord -StepName "ConfirmFileDelete (삭제 확인 비활성화)"

$tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-RegistryIfDifferent -Path $tcpipPath -Name "DefaultTTL" -Value 64 -Type DWord -StepName "DefaultTTL (네트워크 TTL)"

# 로그 저장
Save-OptLog

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "레지스트리 미세 조정이 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor White
Write-Host ""
Write-Host "재부팅 후 모든 설정이 적용됩니다." -ForegroundColor Yellow
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
