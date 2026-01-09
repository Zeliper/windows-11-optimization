# Windows 11 Windows Search 최적화 스크립트
# 인덱싱 최적화, 클라우드 검색 비활성화, WSearch 서비스 설정
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
$scriptName = "019.search_optimization.ps1"

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_019_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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

function Set-ServiceIfDifferent {
    param(
        [string]$ServiceName,
        [string]$StartupType,
        [switch]$StopService,
        [string]$StepName
    )
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Host "  - $StepName : 서비스 없음 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $StepName -Status "스킵됨" -Message "서비스가 존재하지 않음"
            return $false
        }
        $currentStartType = (Get-Service -Name $ServiceName).StartType.ToString()
        if (-not $global:ForceOverride -and $currentStartType -eq $StartupType) {
            Write-Host "  - $StepName : 이미 $StartupType (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 최적 설정" -PreviousValue $currentStartType -NewValue $StartupType
            return $false
        }
        Set-Service -Name $ServiceName -StartupType $StartupType
        if ($StopService -and $service.Status -eq "Running") {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  - $StepName : $currentStartType → $StartupType (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "서비스 설정 변경" -PreviousValue $currentStartType -NewValue $StartupType
        return $true
    } catch {
        Write-Host "  - $StepName : 설정 실패" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "$_"
        return $false
    }
}

Write-Host "=== Windows 11 Windows Search 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "인덱싱 최적화, 클라우드 검색 비활성화, WSearch 서비스 설정을 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 6

# [1/6] Windows Search 현재 상태 분석
Write-Host "[1/$totalSteps] Windows Search 현재 상태 분석 중..." -ForegroundColor Yellow

$wsearchService = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
if ($wsearchService) {
    Write-Host "  - WSearch 서비스 상태: $($wsearchService.Status)" -ForegroundColor White
    Write-Host "  - 시작 유형: $($wsearchService.StartType)" -ForegroundColor White
} else {
    Write-Host "  - WSearch 서비스를 찾을 수 없습니다" -ForegroundColor Yellow
}

$indexPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows"
if (Test-Path $indexPath) {
    try {
        $indexSize = [math]::Round((Get-ChildItem -Path $indexPath -Recurse -ErrorAction SilentlyContinue |
                                    Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-Host "  - 현재 인덱스 크기: $indexSize MB" -ForegroundColor White
    } catch {
        Write-Host "  - 인덱스 크기 확인 실패" -ForegroundColor Yellow
    }
} else {
    Write-Host "  - 인덱스 폴더를 찾을 수 없습니다" -ForegroundColor Gray
}

# [2/6] 인덱싱 정책 최적화
Write-Host ""
Write-Host "[2/$totalSteps] 인덱싱 정책 최적화 중..." -ForegroundColor Yellow

$searchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"

Set-RegistryIfDifferent -Path $searchPolicyPath -Name "PreventIndexingLowDiskSpaceMB" -Value 5000 -Type DWord -StepName "디스크 5GB 미만 시 인덱싱 중단"
Set-RegistryIfDifferent -Path $searchPolicyPath -Name "PreventIndexingEncryptedStores" -Value 1 -Type DWord -StepName "암호화된 파일 인덱싱 비활성화"
Set-RegistryIfDifferent -Path $searchPolicyPath -Name "PreventIndexingOutlook" -Value 1 -Type DWord -StepName "Outlook 오프라인 파일 인덱싱 비활성화"

# [3/6] 클라우드 검색 및 검색 기록 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] 클라우드 검색 및 검색 기록 비활성화 중..." -ForegroundColor Yellow

$searchSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"

Set-RegistryIfDifferent -Path $searchSettingsPath -Name "IsDeviceSearchHistoryEnabled" -Value 0 -Type DWord -StepName "장치 검색 기록 비활성화"
Set-RegistryIfDifferent -Path $searchSettingsPath -Name "IsAADCloudSearchEnabled" -Value 0 -Type DWord -StepName "Azure AD 클라우드 검색 비활성화"
Set-RegistryIfDifferent -Path $searchSettingsPath -Name "IsMSACloudSearchEnabled" -Value 0 -Type DWord -StepName "Microsoft 계정 클라우드 검색 비활성화"
Set-RegistryIfDifferent -Path $searchSettingsPath -Name "SafeSearchMode" -Value 0 -Type DWord -StepName "Safe Search 필터링 비활성화"

# [4/6] 백그라운드 인덱싱 활동 관리
Write-Host ""
Write-Host "[4/$totalSteps] 백그라운드 인덱싱 활동 관리 중..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $searchPolicyPath -Name "PreventIndexOnBattery" -Value 1 -Type DWord -StepName "배터리 모드 인덱싱 비활성화"
Set-RegistryIfDifferent -Path $searchPolicyPath -Name "DisableBackOff" -Value 0 -Type DWord -StepName "시스템 부하 시 인덱싱 백오프 활성화"
Set-RegistryIfDifferent -Path $searchPolicyPath -Name "DisableRemovableDriveIndexing" -Value 1 -Type DWord -StepName "이동식 드라이브 인덱싱 비활성화"
Set-RegistryIfDifferent -Path $searchPolicyPath -Name "PreventIndexingNetworkDrives" -Value 1 -Type DWord -StepName "네트워크 드라이브 인덱싱 비활성화"

# [5/6] WSearch 서비스 최적화
Write-Host ""
Write-Host "[5/$totalSteps] WSearch 서비스 최적화 중..." -ForegroundColor Yellow

$wsearchChoice = "1"
if (-not $global:OrchestrateMode) {
    Write-Host ""
    Write-Host "  Windows Search 서비스 옵션:" -ForegroundColor Cyan
    Write-Host "  [1] 수동 시작 (권장 - 검색 시에만 활성화)" -ForegroundColor White
    Write-Host "  [2] 자동 시작 (기본값 유지)" -ForegroundColor White
    Write-Host "  [3] 비활성화 (검색 기능 사용 안 함)" -ForegroundColor White
    $wsearchChoice = Read-Host "선택 (1-3, 기본값: 1)"
    if ([string]::IsNullOrEmpty($wsearchChoice)) { $wsearchChoice = "1" }
}

switch ($wsearchChoice) {
    "2" {
        Set-ServiceIfDifferent -ServiceName "WSearch" -StartupType "Automatic" -StepName "WSearch 서비스"
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
    }
    "3" {
        Set-ServiceIfDifferent -ServiceName "WSearch" -StartupType "Disabled" -StopService -StepName "WSearch 서비스"
        Write-Host "    주의: 파일 탐색기 및 시작 메뉴 검색이 작동하지 않습니다" -ForegroundColor Red
    }
    default {
        Set-ServiceIfDifferent -ServiceName "WSearch" -StartupType "Manual" -StepName "WSearch 서비스"
    }
}

Write-Host "  - 참고: SearchIndexer.exe는 시스템 유휴 시에만 인덱싱 수행" -ForegroundColor Gray

# [6/6] 검색 인덱스 재구축 옵션
Write-Host ""
Write-Host "[6/$totalSteps] 검색 인덱스 관리..." -ForegroundColor Yellow

$rebuildIndex = "N"
if (-not $global:OrchestrateMode) {
    Write-Host ""
    Write-Host "  검색 인덱스 재구축 옵션:" -ForegroundColor Cyan
    Write-Host "  - 재구축 시 기존 인덱스가 삭제되고 새로 생성됩니다" -ForegroundColor Gray
    Write-Host "  - 완료까지 수 시간이 소요될 수 있습니다 (백그라운드 진행)" -ForegroundColor Gray
    $rebuildIndex = Read-Host "검색 인덱스를 재구축하시겠습니까? (Y/N, 기본값: N)"
}

if ($rebuildIndex -eq "Y" -or $rebuildIndex -eq "y") {
    Write-Host "  - 검색 인덱스 재구축 시작 중..." -ForegroundColor Yellow
    try {
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $indexDataPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows"
        if (Test-Path $indexDataPath) {
            Remove-Item -Path "$indexDataPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  - 기존 인덱스 파일 삭제 완료" -ForegroundColor Green
            Write-OptLog -Step "인덱스 재구축" -Status "적용됨" -Message "기존 인덱스 파일 삭제 완료"
        }
        if ($wsearchChoice -ne "3") {
            Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
            Write-Host "  - WSearch 서비스 재시작됨" -ForegroundColor Green
            Write-Host "  - 인덱스 재구축이 백그라운드에서 진행됩니다" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  - 인덱스 재구축 중 오류 발생: $_" -ForegroundColor Red
        Write-OptLog -Step "인덱스 재구축" -Status "실패" -Message "$_"
    }
} else {
    Write-Host "  - 검색 인덱스 재구축 건너뜀" -ForegroundColor Gray
}

# Cortana/Bing 검색 비활성화
$cortanaSearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
Set-RegistryIfDifferent -Path $cortanaSearchPath -Name "BingSearchEnabled" -Value 0 -Type DWord -StepName "Bing 웹 검색 비활성화"
Set-RegistryIfDifferent -Path $cortanaSearchPath -Name "CortanaConsent" -Value 0 -Type DWord -StepName "Cortana 동의 비활성화"

# 로그 저장
Save-OptLog

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Search 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor White
Write-Host ""
Write-Host "설정은 즉시 적용됩니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $global:OrchestrateMode) {
    Write-Host "참고: 이 스크립트는 재부팅이 필요하지 않습니다." -ForegroundColor Gray
}
