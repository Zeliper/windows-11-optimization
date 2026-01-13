# Windows 11 25H2 개인정보 보호 최적화 스크립트
# 위치 서비스, 진단 피드백, 앱 권한, 백그라운드 앱, 동기화, 활동 기록, 광고 추적, 파일 탐색기 개인정보 비활성화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.2"
$scriptName = "013.privacy_optimization.ps1"

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

# Orchestrate 모드용 메타데이터
$script:ScriptMetadata = @{
    Name = "개인정보 보호 최적화"
    Description = "위치 서비스, 진단 피드백, 앱 권한, 백그라운드 앱, 동기화, 활동 기록, 광고 추적 비활성화"
    RequiresReboot = $true
}

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_013_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
    $logContent = @"
================================================================================
Windows 11 Optimization Log - Privacy Optimization
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
스크립트: $scriptName v$scriptVersion
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

    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name

    if ($currentValue -eq $Value) {
        $msg = if ($Description) { "$Description : 이미 설정됨" } else { "$Name : 이미 설정됨" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "$Name 이미 최적값" -PreviousValue "$currentValue" -NewValue "$Value"
        return $false
    }

    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        $msg = if ($Description) { "$Description : $currentValue → $Value" } else { "$Name : $currentValue → $Value" }
        Write-Host "  - $msg (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "$Name 변경됨" -PreviousValue "$currentValue" -NewValue "$Value"
        return $true
    } catch {
        $msg = if ($Description) { "$Description : 설정 실패" } else { "$Name : 설정 실패" }
        Write-Host "  - $msg" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "$Name 설정 실패: $_"
        return $false
    }
}

function Set-ServiceIfDifferent {
    param(
        [string]$ServiceName,
        [string]$StartupType,
        [bool]$StopService = $false,
        [string]$StepName,
        [string]$Description = ""
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        $msg = if ($Description) { "$Description : 서비스 없음" } else { "$ServiceName : 서비스 없음" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "서비스 없음"
        return $false
    }

    $currentStartType = $service.StartType.ToString()

    if ($currentStartType -eq $StartupType) {
        $msg = if ($Description) { "$Description : 이미 $StartupType" } else { "$ServiceName : 이미 $StartupType" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 $StartupType" -PreviousValue $currentStartType
        return $false
    }

    try {
        if ($StopService -and $service.Status -eq "Running") {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        }

        Set-Service -Name $ServiceName -StartupType $StartupType
        $msg = if ($Description) { "$Description : $currentStartType → $StartupType" } else { "$ServiceName : $currentStartType → $StartupType" }
        Write-Host "  - $msg (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "변경됨" -PreviousValue $currentStartType -NewValue $StartupType
        return $true
    } catch {
        $msg = if ($Description) { "$Description : 설정 실패" } else { "$ServiceName : 설정 실패" }
        Write-Host "  - $msg" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "설정 실패: $_"
        return $false
    }
}

function Disable-ScheduledTaskIfEnabled {
    param(
        [string]$TaskName,
        [string]$StepName,
        [string]$Description = ""
    )

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        $msg = if ($Description) { "$Description : 작업 없음" } else { "$TaskName : 작업 없음" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "작업 없음"
        return $false
    }

    if ($task.State -eq "Disabled") {
        $msg = if ($Description) { "$Description : 이미 비활성화됨" } else { "$TaskName : 이미 비활성화됨" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 비활성화됨"
        return $false
    }

    try {
        Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
        $msg = if ($Description) { "$Description : 비활성화됨" } else { "$TaskName : 비활성화됨" }
        Write-Host "  - $msg (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "비활성화됨"
        return $true
    } catch {
        $msg = if ($Description) { "$Description : 비활성화 실패" } else { "$TaskName : 비활성화 실패" }
        Write-Host "  - $msg" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "비활성화 실패: $_"
        return $false
    }
}

# ===== 메인 스크립트 시작 =====

Write-Host "=== Windows 11 25H2 개인정보 보호 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "위치 서비스, 진단 피드백, 앱 권한, 광고 추적 등을 비활성화합니다." -ForegroundColor White
Write-Host ""
Write-Host "================================================" -ForegroundColor Red
Write-Host "경고: 일부 앱 기능이 제한될 수 있습니다." -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
Write-Host ""

if (-not $global:OrchestrateMode) {
    $confirm = Read-Host "계속하시겠습니까? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "사용자가 취소하였습니다." -ForegroundColor Red
        exit
    }
}

$totalSteps = 7
Write-Host ""


# [1/7] 위치 서비스 비활성화
Write-Host "[1/$totalSteps] 위치 서비스 비활성화 중..." -ForegroundColor Yellow

$stepName = "1. 위치 서비스"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type "String" -StepName $stepName -Description "시스템 위치 서비스"
Set-RegistryIfDifferent -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type "String" -StepName $stepName -Description "사용자 위치 서비스"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocation" -Value 1 -StepName $stepName -Description "위치 비활성화"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableLocationScripting" -Value 1 -StepName $stepName -Description "위치 스크립팅 비활성화"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" -Name "DisableWindowsLocationProvider" -Value 1 -StepName $stepName -Description "위치 제공자 비활성화"

# 위치 서비스 관련 서비스 비활성화
Set-ServiceIfDifferent -ServiceName "lfsvc" -StartupType "Disabled" -StopService $true -StepName $stepName -Description "Geolocation Service"


# [2/7] 진단 피드백 완전 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] 진단 피드백 완전 비활성화 중..." -ForegroundColor Yellow

$stepName = "2. 진단 피드백"
$diagDataPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
Set-RegistryIfDifferent -Path $diagDataPath -Name "AllowTelemetry" -Value 0 -StepName $stepName -Description "진단 데이터 수준"
Set-RegistryIfDifferent -Path $diagDataPath -Name "MaxTelemetryAllowed" -Value 0 -StepName $stepName -Description "최대 텔레메트리"
Set-RegistryIfDifferent -Path $diagDataPath -Name "DisableEnterpriseAuthProxy" -Value 1 -StepName $stepName -Description "엔터프라이즈 인증 프록시"

$feedbackPath = "HKCU:\Software\Microsoft\Siuf\Rules"
Set-RegistryIfDifferent -Path $feedbackPath -Name "NumberOfSIUFInPeriod" -Value 0 -StepName $stepName -Description "피드백 요청 횟수"
Set-RegistryIfDifferent -Path $feedbackPath -Name "PeriodInNanoSeconds" -Value 0 -StepName $stepName -Description "피드백 요청 기간"

# 진단 서비스 비활성화
$diagServices = @("DiagTrack", "dmwappushservice")
foreach ($svc in $diagServices) {
    Set-ServiceIfDifferent -ServiceName $svc -StartupType "Disabled" -StopService $true -StepName $stepName -Description $svc
}

$diagViewerPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey"
Set-RegistryIfDifferent -Path $diagViewerPath -Name "EnableEventTranscript" -Value 0 -StepName $stepName -Description "진단 데이터 뷰어"

# 오류 보고 비활성화
$werPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
Set-RegistryIfDifferent -Path $werPath -Name "Disabled" -Value 1 -StepName $stepName -Description "오류 보고 비활성화"
Set-RegistryIfDifferent -Path $werPath -Name "DontSendAdditionalData" -Value 1 -StepName $stepName -Description "추가 데이터 전송 안함"
Set-RegistryIfDifferent -Path $werPath -Name "LoggingDisabled" -Value 1 -StepName $stepName -Description "로깅 비활성화"

# 필기 및 타이핑 데이터 수집 비활성화
$inkTypingPath = "HKCU:\Software\Microsoft\InputPersonalization"
Set-RegistryIfDifferent -Path $inkTypingPath -Name "RestrictImplicitInkCollection" -Value 1 -StepName $stepName -Description "필기 데이터 수집 제한"
Set-RegistryIfDifferent -Path $inkTypingPath -Name "RestrictImplicitTextCollection" -Value 1 -StepName $stepName -Description "타이핑 데이터 수집 제한"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore" -Name "HarvestContacts" -Value 0 -StepName $stepName -Description "연락처 수집"


# [3/7] 앱 권한 제한 (카메라, 마이크, 연락처 등)
Write-Host ""
Write-Host "[3/$totalSteps] 앱 권한 제한 중..." -ForegroundColor Yellow

# 앱 권한 제어 경로
$capabilityPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"

# 제한할 권한 목록
$capabilities = @{
    "webcam" = "카메라"
    "microphone" = "마이크"
    "contacts" = "연락처"
    "appointments" = "일정"
    "phoneCallHistory" = "통화 기록"
    "email" = "이메일"
    "userAccountInformation" = "계정 정보"
    "documentsLibrary" = "문서 라이브러리"
    "picturesLibrary" = "사진 라이브러리"
    "videosLibrary" = "비디오 라이브러리"
    "broadFileSystemAccess" = "파일 시스템"
    "cellularData" = "셀룰러 데이터"
    "chat" = "메시징"
    "radios" = "라디오 (블루투스/WiFi 제어)"
    "gazeInput" = "시선 추적"
    "humanInterfaceDevice" = "HID 장치"
    "activity" = "활동"
    "appDiagnostics" = "앱 진단"
    "voiceActivation" = "음성 활성화"
    "graphicsCaptureProgrammatic" = "화면 캡처"
    "graphicsCaptureWithoutBorder" = "테두리 없는 화면 캡처"
}

foreach ($capability in $capabilities.Keys) {
    $capPath = "$capabilityPath\$capability"
    if (!(Test-Path $capPath)) {
        New-Item -Path $capPath -Force | Out-Null
    }
    Set-ItemProperty -Path $capPath -Name "Value" -Value "Deny" -Type String -ErrorAction SilentlyContinue
}
Write-Host "  - 시스템 레벨 앱 권한 제한 적용 완료" -ForegroundColor Green
Write-Host "    (카메라, 마이크, 연락처, 일정, 이메일 등)" -ForegroundColor White

# 사용자 레벨 권한 제한
$capabilityPathUser = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"
foreach ($capability in $capabilities.Keys) {
    $capPath = "$capabilityPathUser\$capability"
    if (!(Test-Path $capPath)) {
        New-Item -Path $capPath -Force | Out-Null
    }
    Set-ItemProperty -Path $capPath -Name "Value" -Value "Deny" -Type String -ErrorAction SilentlyContinue
}
Write-Host "  - 사용자 레벨 앱 권한 제한 적용 완료" -ForegroundColor Green

# 위치 기반 권한 추가 제한
$locationNotify = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
if (Test-Path $locationNotify) {
    Set-ItemProperty -Path $locationNotify -Name "ShowGlobalPrompts" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
Write-Host "  - 위치 권한 요청 프롬프트 비활성화" -ForegroundColor Green


# [4/7] 백그라운드 앱 비활성화
Write-Host ""
Write-Host "[4/$totalSteps] 백그라운드 앱 비활성화 중..." -ForegroundColor Yellow

# 전역 백그라운드 앱 비활성화
$bgAppsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications"
if (!(Test-Path $bgAppsPath)) {
    New-Item -Path $bgAppsPath -Force | Out-Null
}
Set-ItemProperty -Path $bgAppsPath -Name "GlobalUserDisabled" -Value 1 -Type DWord
Write-Host "  - 전역 백그라운드 앱 비활성화" -ForegroundColor Green

# 백그라운드 앱 정책 설정
$bgAppsPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
if (!(Test-Path $bgAppsPolicyPath)) {
    New-Item -Path $bgAppsPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $bgAppsPolicyPath -Name "LetAppsRunInBackground" -Value 2 -Type DWord
Write-Host "  - 백그라운드 앱 정책 비활성화" -ForegroundColor Green

# 개별 앱 백그라운드 권한 제한
$bgAppsSearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
if (!(Test-Path $bgAppsSearchPath)) {
    New-Item -Path $bgAppsSearchPath -Force | Out-Null
}
Set-ItemProperty -Path $bgAppsSearchPath -Name "BackgroundAppGlobalToggle" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 검색 백그라운드 작업 비활성화" -ForegroundColor Green

# 백그라운드 지능형 전송 서비스 (BITS) 제한 (옵션)
# 참고: Windows Update에 필요하므로 완전 비활성화하지 않음
Write-Host "  - BITS 서비스: Windows Update 필요로 유지" -ForegroundColor Yellow


# [5/7] 동기화 설정 비활성화
Write-Host ""
Write-Host "[5/$totalSteps] 동기화 설정 비활성화 중..." -ForegroundColor Yellow

# 설정 동기화 비활성화
$syncPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync"
if (!(Test-Path $syncPath)) {
    New-Item -Path $syncPath -Force | Out-Null
}
Set-ItemProperty -Path $syncPath -Name "SyncPolicy" -Value 5 -Type DWord
Write-Host "  - 설정 동기화 비활성화" -ForegroundColor Green

# 동기화 그룹 비활성화
$syncGroups = @(
    "Accessibility",
    "AppSync",
    "BrowserSettings",
    "Credentials",
    "DesktopTheme",
    "Language",
    "PackageState",
    "Personalization",
    "StartLayout",
    "Windows"
)

$syncGroupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync\Groups"
foreach ($group in $syncGroups) {
    $groupPath = "$syncGroupPath\$group"
    if (!(Test-Path $groupPath)) {
        New-Item -Path $groupPath -Force | Out-Null
    }
    Set-ItemProperty -Path $groupPath -Name "Enabled" -Value 0 -Type DWord
}
Write-Host "  - 동기화 그룹 비활성화 (테마, 언어, 시작 메뉴 등)" -ForegroundColor Green

# 클라우드 동기화 정책
$cloudSyncPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SettingSync"
if (!(Test-Path $cloudSyncPath)) {
    New-Item -Path $cloudSyncPath -Force | Out-Null
}
Set-ItemProperty -Path $cloudSyncPath -Name "DisableSettingSync" -Value 2 -Type DWord
Set-ItemProperty -Path $cloudSyncPath -Name "DisableSettingSyncUserOverride" -Value 1 -Type DWord
Set-ItemProperty -Path $cloudSyncPath -Name "DisableSyncOnPaidNetwork" -Value 1 -Type DWord
Write-Host "  - 클라우드 동기화 정책 비활성화" -ForegroundColor Green

# OneDrive 동기화 프롬프트 비활성화
$oneDrivePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
if (!(Test-Path $oneDrivePath)) {
    New-Item -Path $oneDrivePath -Force | Out-Null
}
Set-ItemProperty -Path $oneDrivePath -Name "DisableFileSyncNGSC" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - OneDrive 파일 동기화 비활성화" -ForegroundColor Green

# 클립보드 동기화 비활성화
$clipboardPath = "HKCU:\Software\Microsoft\Clipboard"
if (!(Test-Path $clipboardPath)) {
    New-Item -Path $clipboardPath -Force | Out-Null
}
Set-ItemProperty -Path $clipboardPath -Name "EnableClipboardHistory" -Value 0 -Type DWord
Set-ItemProperty -Path $clipboardPath -Name "EnableCloudClipboard" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 클립보드 기록 및 동기화 비활성화" -ForegroundColor Green


# [6/7] 활동 기록 완전 삭제
Write-Host ""
Write-Host "[6/$totalSteps] 활동 기록 완전 삭제 중..." -ForegroundColor Yellow

# 활동 기록 수집 비활성화
$activityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (!(Test-Path $activityPath)) {
    New-Item -Path $activityPath -Force | Out-Null
}
Set-ItemProperty -Path $activityPath -Name "EnableActivityFeed" -Value 0 -Type DWord
Set-ItemProperty -Path $activityPath -Name "PublishUserActivities" -Value 0 -Type DWord
Set-ItemProperty -Path $activityPath -Name "UploadUserActivities" -Value 0 -Type DWord
Write-Host "  - 활동 피드 비활성화" -ForegroundColor Green

# 사용자 활동 게시 비활성화
$activityUserPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
if (!(Test-Path $activityUserPath)) {
    New-Item -Path $activityUserPath -Force | Out-Null
}
Set-ItemProperty -Path $activityUserPath -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord
Write-Host "  - 맞춤형 경험 비활성화" -ForegroundColor Green

# 타임라인 비활성화
$timelinePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
Set-ItemProperty -Path $timelinePath -Name "EnableCdp" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 타임라인 (CDP) 비활성화" -ForegroundColor Green

# 활동 기록 데이터 삭제
$activityHistoryPath = "$env:LOCALAPPDATA\ConnectedDevicesPlatform"
if (Test-Path $activityHistoryPath) {
    # CDP 서비스 중지 후 삭제
    Stop-Service -Name "CDPSvc" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "CDPUserSvc*" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item -Path "$activityHistoryPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - 로컬 활동 기록 데이터 삭제" -ForegroundColor Green
}

# 최근 사용 파일 기록 비활성화
$explorerAdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (!(Test-Path $explorerAdvPath)) {
    New-Item -Path $explorerAdvPath -Force | Out-Null
}
Set-ItemProperty -Path $explorerAdvPath -Name "Start_TrackDocs" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $explorerAdvPath -Name "Start_TrackProgs" -Value 0 -Type DWord -Force
Write-Host "  - 최근 사용 파일/프로그램 추적 비활성화" -ForegroundColor Green

# 점프 목록 비활성화
Set-ItemProperty -Path $explorerAdvPath -Name "JumpListItems" -Value 0 -Type DWord -Force
Write-Host "  - 점프 목록 비활성화" -ForegroundColor Green

# 파일 탐색기 개인 정보 보호 설정 (폴더 옵션) - 강화 버전

# 1. 탐색기 먼저 종료 (파일 잠금 해제 및 설정 즉시 반영) - OrchestrateMode에서는 중앙 관리
if (-not $global:OrchestrateMode) {
    Write-Host "  - 파일 탐색기 종료 중..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# 2. 그룹 정책 레지스트리 추가 (강제 적용)
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
if (!(Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}
Set-ItemProperty -Path $policyPath -Name "NoRecentDocsHistory" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $policyPath -Name "NoRecentDocsMenu" -Value 1 -Type DWord -Force
Write-Host "  - 그룹 정책: 최근 문서 기록 비활성화" -ForegroundColor Green

# 3. 사용자 레지스트리 설정
$explorerBasePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
if (!(Test-Path $explorerBasePath)) {
    New-Item -Path $explorerBasePath -Force | Out-Null
}
Set-ItemProperty -Path $explorerBasePath -Name "ShowRecent" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $explorerBasePath -Name "ShowFrequent" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $explorerBasePath -Name "ShowCloudFilesInQuickAccess" -Value 0 -Type DWord -Force
Write-Host "  - 최근 파일/자주 사용 폴더/Office.com 파일 표시 비활성화" -ForegroundColor Green

# 4. Windows 11 24H2+ 추가 레지스트리 (시작 메뉴 연동)
$startPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"
if (!(Test-Path $startPath)) {
    New-Item -Path $startPath -Force | Out-Null
}
Set-ItemProperty -Path $startPath -Name "ShowRecentList" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Write-Host "  - Windows 11 시작 메뉴 최근 목록 비활성화" -ForegroundColor Green

# 5. 파일 탐색기 홈에서 "권장" 섹션 비활성화 (Windows 11)
Set-ItemProperty -Path $explorerAdvPath -Name "Start_IrisRecommendations" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Write-Host "  - 파일 탐색기 홈 권장 섹션 비활성화" -ForegroundColor Green

# 6. 히스토리 파일 완전 삭제 (탐색기 종료 상태에서)
$recentPaths = @(
    "$env:APPDATA\Microsoft\Windows\Recent",
    "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
)
foreach ($path in $recentPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -File -Force | Remove-Item -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "  - 최근 파일 히스토리 삭제 완료" -ForegroundColor Green

# 7. 탐색기 재시작 (OrchestrateMode에서는 중앙 관리)
if (-not $global:OrchestrateMode) {
    Start-Sleep -Seconds 1
    Start-Process explorer
    Write-Host "  - 파일 탐색기 재시작 완료" -ForegroundColor Green
} else {
    Write-Host "  - 파일 탐색기 재시작 예약됨 (Orchestrate 종료 시)" -ForegroundColor Gray
}


# [7/7] 광고 추적 비활성화 강화
Write-Host ""
Write-Host "[7/$totalSteps] 광고 추적 비활성화 강화 중..." -ForegroundColor Yellow

# 광고 ID 비활성화
$advInfoPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
if (!(Test-Path $advInfoPath)) {
    New-Item -Path $advInfoPath -Force | Out-Null
}
Set-ItemProperty -Path $advInfoPath -Name "Enabled" -Value 0 -Type DWord
Write-Host "  - 광고 ID 비활성화" -ForegroundColor Green

# 광고 ID 리셋 및 삭제
Remove-ItemProperty -Path $advInfoPath -Name "Id" -ErrorAction SilentlyContinue
Write-Host "  - 기존 광고 ID 삭제" -ForegroundColor Green

# 광고 정책 설정
$advPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"
if (!(Test-Path $advPolicyPath)) {
    New-Item -Path $advPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $advPolicyPath -Name "DisabledByGroupPolicy" -Value 1 -Type DWord
Write-Host "  - 광고 ID 정책 비활성화" -ForegroundColor Green

# 시작 메뉴 앱 제안 비활성화
$startSuggestionsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (!(Test-Path $startSuggestionsPath)) {
    New-Item -Path $startSuggestionsPath -Force | Out-Null
}
Set-ItemProperty -Path $startSuggestionsPath -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SubscribedContent-338393Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SubscribedContent-353694Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SubscribedContent-353696Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SubscribedContent-353698Enabled" -Value 0 -Type DWord
Write-Host "  - 시작 메뉴 앱 제안 비활성화" -ForegroundColor Green

# 잠금 화면 광고 비활성화
Set-ItemProperty -Path $startSuggestionsPath -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord
Write-Host "  - 잠금 화면 광고/팁 비활성화" -ForegroundColor Green

# 설정 앱 광고 비활성화
Set-ItemProperty -Path $startSuggestionsPath -Name "SoftLandingEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "ContentDeliveryAllowed" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "PreInstalledAppsEverEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $startSuggestionsPath -Name "FeatureManagementEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 자동 앱 설치 및 콘텐츠 전달 비활성화" -ForegroundColor Green

# 앱 실행 추적 비활성화
$privacyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $privacyPath -Name "Start_TrackEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 앱 실행 추적 비활성화" -ForegroundColor Green

# SmartScreen 광고 데이터 비활성화 (보안 유지, 광고 데이터만 제한)
$smartScreenPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy"
Set-ItemProperty -Path $smartScreenPath -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 맞춤형 광고 경험 비활성화" -ForegroundColor Green

# Edge 추적 방지 강화 (정책 설정)
$edgePath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (!(Test-Path $edgePath)) {
    New-Item -Path $edgePath -Force | Out-Null
}
Set-ItemProperty -Path $edgePath -Name "TrackingPrevention" -Value 3 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $edgePath -Name "PersonalizationReportingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $edgePath -Name "AddressBarMicrosoftSearchInBingProviderEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Edge 추적 방지 강화 (Strict 모드)" -ForegroundColor Green

# Do Not Track 헤더 활성화
Set-ItemProperty -Path $edgePath -Name "ConfigureDoNotTrack" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Do Not Track 헤더 활성화" -ForegroundColor Green

# 광고 관련 예약 작업 비활성화
$adTasks = @(
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
)
foreach ($task in $adTasks) {
    Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "  - 고객 환경 개선 프로그램 작업 비활성화" -ForegroundColor Green


# 완료 메시지
# 로그 저장
Save-OptLog

# Summary 출력
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "개인정보 보호 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $($global:AppliedCount) 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $($global:SkippedCount) 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $($global:FailedCount) 개" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $($global:LogFilePath)" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 위치 서비스 완전 비활성화" -ForegroundColor White
Write-Host "  - 진단 데이터 및 피드백 비활성화" -ForegroundColor White
Write-Host "  - 앱 권한 제한 (카메라, 마이크, 연락처 등 20+ 항목)" -ForegroundColor White
Write-Host "  - 백그라운드 앱 전역 비활성화" -ForegroundColor White
Write-Host "  - 동기화 설정 비활성화 (클라우드, 클립보드 등)" -ForegroundColor White
Write-Host "  - 활동 기록 완전 삭제 및 추적 비활성화" -ForegroundColor White
Write-Host "  - 파일 탐색기 개인 정보 보호 (최근 파일, 자주 사용 폴더, Office.com 파일)" -ForegroundColor White
Write-Host "  - 광고 추적 강화 비활성화 (광고 ID, 맞춤 광고 등)" -ForegroundColor White
Write-Host ""
Write-Host "참고사항:" -ForegroundColor Yellow
Write-Host "  - 일부 앱에서 위치, 카메라, 마이크 기능이 작동하지 않을 수 있습니다." -ForegroundColor Gray
Write-Host "  - 필요 시 설정 > 개인 정보에서 개별 권한을 다시 활성화할 수 있습니다." -ForegroundColor Gray
Write-Host ""
Write-Host "재부팅 후 모든 설정이 완전히 적용됩니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

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
