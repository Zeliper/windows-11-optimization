# Windows 11 25H2 AI 기능 비활성화 스크립트
# Recall, Copilot, AI Actions, Click to Do, 텔레메트리 비활성화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "012.ai_features.ps1"

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

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_012_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
Windows 11 Optimization Log - AI Features Disable
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

    # 경로 생성
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    # 현재 값 확인
    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name

    if ($currentValue -eq $Value) {
        $msg = if ($Description) { "$Description : 이미 설정됨" } else { "$Name : 이미 설정됨" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "$Name 이미 최적값" -PreviousValue "$currentValue" -NewValue "$Value"
        return $false
    }

    # 값 설정
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

function Remove-AppxPackageIfExists {
    param(
        [string]$PackageName,
        [string]$StepName,
        [string]$Description = ""
    )

    $packages = Get-AppxPackage -AllUsers -Name "*$PackageName*" -ErrorAction SilentlyContinue

    if (-not $packages -or $packages.Count -eq 0) {
        $msg = if ($Description) { "$Description : 이미 제거됨" } else { "$PackageName : 이미 제거됨" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 제거됨"
        return $false
    }

    try {
        foreach ($pkg in $packages) {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }

        # 프로비저닝 패키지도 제거
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*$PackageName*" } |
            ForEach-Object {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
            }

        $msg = if ($Description) { "$Description : 제거됨" } else { "$PackageName : 제거됨" }
        Write-Host "  - $msg (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "제거됨"
        return $true
    } catch {
        $msg = if ($Description) { "$Description : 제거 실패" } else { "$PackageName : 제거 실패" }
        Write-Host "  - $msg" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "제거 실패: $_"
        return $false
    }
}

# ===== 메인 스크립트 시작 =====

Write-Host "=== Windows 11 25H2 AI 기능 비활성화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "Recall, Copilot, AI Actions 등 AI 관련 기능을 비활성화합니다." -ForegroundColor White
Write-Host ""
Write-Host "================================================" -ForegroundColor Red
Write-Host "경고: 이 스크립트는 Windows 11 25H2 이상에서 작동합니다." -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
Write-Host ""

if (-not $global:OrchestrateMode) {
    $confirm = Read-Host "계속하시겠습니까? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "사용자가 취소하였습니다." -ForegroundColor Red
        exit
    }
}

$totalSteps = 14
Write-Host ""


# [1/14] Windows Recall 비활성화
Write-Host "[1/$totalSteps] Windows Recall 비활성화 중..." -ForegroundColor Yellow

$stepName = "1. Windows Recall"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "AllowRecallEnablement" -Value 0 -StepName $stepName -Description "AllowRecallEnablement"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -StepName $stepName -Description "DisableAIDataAnalysis"
Set-RegistryIfDifferent -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1 -StepName $stepName -Description "사용자 레벨 AI 데이터 분석"

# Recall 예약 작업 비활성화
$recallTasks = @(
    "RecallBackgroundActivity"
    "RecallHistoryCreation"
)
foreach ($taskName in $recallTasks) {
    Disable-ScheduledTaskIfEnabled -TaskName $taskName -StepName $stepName -Description "Recall 작업: $taskName"
}


# [2/14] Windows Copilot 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] Windows Copilot 비활성화 중..." -ForegroundColor Yellow

$stepName = "2. Windows Copilot"
Set-RegistryIfDifferent -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -StepName $stepName -Description "사용자 레벨 Copilot"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1 -StepName $stepName -Description "시스템 레벨 Copilot"

# Copilot 앱 제거
$copilotPackages = @("Microsoft.Copilot", "Microsoft.Windows.Copilot", "Microsoft.CopilotRuntime")
foreach ($pkg in $copilotPackages) {
    Remove-AppxPackageIfExists -PackageName $pkg -StepName $stepName -Description "Copilot 패키지: $pkg"
}

# Edge Copilot 비활성화
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "HubsSidebarEnabled" -Value 0 -StepName $stepName -Description "Edge Copilot 사이드바"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name "CopilotCDPPageContext" -Value 0 -StepName $stepName -Description "Edge Copilot CDP"


# [3/14] AI Actions / Click to Do 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] AI Actions / Click to Do 비활성화 중..." -ForegroundColor Yellow

$stepName = "3. AI Actions"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowAIActions" -Value 0 -StepName $stepName -Description "파일 탐색기 AI Actions 메뉴"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard" -Name "Disabled" -Value 1 -StepName $stepName -Description "Click to Do (Smart Clipboard)"


# [4/14] Input Insights 비활성화
Write-Host ""
Write-Host "[4/$totalSteps] Input Insights (타이핑 데이터 수집) 비활성화 중..." -ForegroundColor Yellow

$stepName = "4. Input Insights"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Input\Settings" -Name "InsightsEnabled" -Value 0 -StepName $stepName -Description "Input Insights"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Personalization\Settings" -Name "AcceptedPrivacyPolicy" -Value 0 -StepName $stepName -Description "입력 개인 맞춤화"


# [5/14] 앱 내 AI 기능 비활성화 (Paint, Notepad 등)
Write-Host ""
Write-Host "[5/$totalSteps] 앱 내 AI 기능 비활성화 (Paint, Notepad 등)..." -ForegroundColor Yellow

$stepName = "5. 앱 내 AI 기능"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Paint" -Name "CocreatorEnabled" -Value 0 -StepName $stepName -Description "Paint Cocreator"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Paint" -Name "ImageCreatorEnabled" -Value 0 -StepName $stepName -Description "Paint Image Creator"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Notepad" -Name "RewriteEnabled" -Value 0 -StepName $stepName -Description "Notepad Rewrite AI"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Photos" -Name "AiErasingEnabled" -Value 0 -StepName $stepName -Description "Photos AI Erasing"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Photos" -Name "AiSuggestionsEnabled" -Value 0 -StepName $stepName -Description "Photos AI Suggestions"


# [6/14] AI Fabric Service 비활성화
Write-Host ""
Write-Host "[6/$totalSteps] AI Fabric Service 비활성화 중..." -ForegroundColor Yellow

$stepName = "6. AI 서비스"
$aiServices = @("AIXHost", "AIFabricService")
foreach ($svcName in $aiServices) {
    Set-ServiceIfDifferent -ServiceName $svcName -StartupType "Disabled" -StopService $true -StepName $stepName -Description $svcName
}


# [7/14] AI 관련 텔레메트리 비활성화
Write-Host ""
Write-Host "[7/$totalSteps] AI 관련 텔레메트리 비활성화 중..." -ForegroundColor Yellow

$stepName = "7. AI 텔레메트리"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name "AIDataCollection" -Value 0 -StepName $stepName -Description "AI 진단 데이터 수집"
Set-RegistryIfDifferent -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1 -StepName $stepName -Description "검색 상자 AI 제안"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "DisableCloudOptimizedContent" -Value 1 -StepName $stepName -Description "클라우드 최적화 콘텐츠"


# [8/14] Voice Access AI 기능 비활성화
Write-Host ""
Write-Host "[8/$totalSteps] Voice Access AI 기능 비활성화 중..." -ForegroundColor Yellow

$stepName = "8. Voice Access AI"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceAccess" -Name "AIVoiceEnabled" -Value 0 -StepName $stepName -Description "Voice Access AI 음성"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Accessibility" -Name "LiveCaptionsEnabled" -Value 0 -StepName $stepName -Description "Live Captions"


# [9/14] AI AppX 패키지 강제 제거
Write-Host ""
Write-Host "[9/$totalSteps] AI AppX 패키지 강제 제거 중..." -ForegroundColor Yellow

$stepName = "9. AI 패키지 제거"
$aiPackagePatterns = @("Copilot", "Recall", "Microsoft.Windows.Ai", "Microsoft.AI")
foreach ($pattern in $aiPackagePatterns) {
    Remove-AppxPackageIfExists -PackageName $pattern -StepName $stepName -Description "AI 패키지: $pattern"
}


# [10/14] Recall Optional Feature 제거
Write-Host ""
Write-Host "[10/$totalSteps] Recall Optional Feature 제거 중..." -ForegroundColor Yellow

$stepName = "10. Recall Optional Feature"
try {
    $recallFeature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
    if ($recallFeature -and $recallFeature.State -eq "Enabled") {
        Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  - Recall 선택적 기능 제거됨 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $stepName -Status "적용됨" -Message "Recall 선택적 기능 제거됨"
    } else {
        Write-Host "  - Recall 기능이 설치되어 있지 않거나 이미 비활성화됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $stepName -Status "스킵됨" -Message "이미 비활성화됨 또는 미설치"
    }
} catch {
    Write-Host "  - Recall 기능 제거 건너뜀 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $stepName -Status "스킵됨" -Message "설치되지 않음"
}


# [11/14] AI 자동 설치 방지 정책
Write-Host ""
Write-Host "[11/$totalSteps] AI 자동 설치 방지 정책 설정 중..." -ForegroundColor Yellow

$stepName = "11. AI 자동 설치 방지"
$cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-RegistryIfDifferent -Path $cdmPath -Name "SilentInstalledAppsEnabled" -Value 0 -StepName $stepName -Description "자동 앱 설치"
Set-RegistryIfDifferent -Path $cdmPath -Name "ContentDeliveryAllowed" -Value 0 -StepName $stepName -Description "콘텐츠 전달"
Set-RegistryIfDifferent -Path $cdmPath -Name "OemPreInstalledAppsEnabled" -Value 0 -StepName $stepName -Description "OEM 앱 설치"
Set-RegistryIfDifferent -Path $cdmPath -Name "PreInstalledAppsEnabled" -Value 0 -StepName $stepName -Description "사전 설치 앱"
Set-RegistryIfDifferent -Path $cdmPath -Name "PreInstalledAppsEverEnabled" -Value 0 -StepName $stepName -Description "사전 설치 앱 기록"
Set-RegistryIfDifferent -Path $cdmPath -Name "SoftLandingEnabled" -Value 0 -StepName $stepName -Description "SoftLanding"
Set-RegistryIfDifferent -Path $cdmPath -Name "SystemPaneSuggestionsEnabled" -Value 0 -StepName $stepName -Description "시스템 패널 제안"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Experience" -Name "AllowCopilot" -Value 0 -StepName $stepName -Description "Copilot 자동 배포"


# [12/14] Windows Search AI 추천 비활성화
Write-Host ""
Write-Host "[12/$totalSteps] Windows Search AI 추천 비활성화 중..." -ForegroundColor Yellow

$stepName = "12. Search AI 추천"
$searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
Set-RegistryIfDifferent -Path $searchPath -Name "BingSearchEnabled" -Value 0 -StepName $stepName -Description "Bing 검색"
Set-RegistryIfDifferent -Path $searchPath -Name "CortanaConsent" -Value 0 -StepName $stepName -Description "Cortana 동의"
Set-RegistryIfDifferent -Path $searchPath -Name "AllowCloudSearch" -Value 0 -StepName $stepName -Description "클라우드 검색"
Set-RegistryIfDifferent -Path $searchPath -Name "AllowSearchToUseLocation" -Value 0 -StepName $stepName -Description "위치 기반 검색"

$searchSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
Set-RegistryIfDifferent -Path $searchSettingsPath -Name "IsDynamicSearchBoxEnabled" -Value 0 -StepName $stepName -Description "동적 검색 상자"
Set-RegistryIfDifferent -Path $searchSettingsPath -Name "IsAADCloudSearchEnabled" -Value 0 -StepName $stepName -Description "AAD 클라우드 검색"
Set-RegistryIfDifferent -Path $searchSettingsPath -Name "IsMSACloudSearchEnabled" -Value 0 -StepName $stepName -Description "MSA 클라우드 검색"
Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_TrackDocs" -Value 0 -StepName $stepName -Description "검색 히스토리"


# [13/14] Windows Spotlight AI 비활성화
Write-Host ""
Write-Host "[13/$totalSteps] Windows Spotlight AI 비활성화 중..." -ForegroundColor Yellow

$stepName = "13. Windows Spotlight"
$cdmPathSpotlight = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "RotatingLockScreenEnabled" -Value 0 -StepName $stepName -Description "회전 잠금 화면"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "RotatingLockScreenOverlayEnabled" -Value 0 -StepName $stepName -Description "잠금 화면 오버레이"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "SubscribedContent-338387Enabled" -Value 0 -StepName $stepName -Description "구독 콘텐츠 338387"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "SubscribedContent-338388Enabled" -Value 0 -StepName $stepName -Description "구독 콘텐츠 338388"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "SubscribedContent-338389Enabled" -Value 0 -StepName $stepName -Description "구독 콘텐츠 338389"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "SubscribedContent-353694Enabled" -Value 0 -StepName $stepName -Description "구독 콘텐츠 353694"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "SubscribedContent-353696Enabled" -Value 0 -StepName $stepName -Description "구독 콘텐츠 353696"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "SubscribedContent-310093Enabled" -Value 0 -StepName $stepName -Description "구독 콘텐츠 310093"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "SubscribedContent-338393Enabled" -Value 0 -StepName $stepName -Description "잠금 화면 팁"
Set-RegistryIfDifferent -Path $cdmPathSpotlight -Name "SubscribedContent-353698Enabled" -Value 0 -StepName $stepName -Description "추천 콘텐츠"


# [14/14] ML 서비스 및 AI 예약 작업 비활성화
Write-Host ""
Write-Host "[14/$totalSteps] ML 서비스 및 AI 예약 작업 비활성화 중..." -ForegroundColor Yellow

$stepName = "14. ML 서비스 및 AI 작업"
$mlServices = @("mlsvc", "WMPNetworkSvc")
foreach ($svcName in $mlServices) {
    Set-ServiceIfDifferent -ServiceName $svcName -StartupType "Disabled" -StopService $true -StepName $stepName -Description $svcName
}

# AI 관련 예약 작업 비활성화
$aiTaskPaths = @("\Microsoft\Windows\AI\", "\Microsoft\Windows\Shell\AI\", "\Microsoft\Windows\WindowsAI\")
foreach ($taskPath in $aiTaskPaths) {
    Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue |
        ForEach-Object {
            Disable-ScheduledTaskIfEnabled -TaskName $_.TaskName -StepName $stepName -Description "AI 작업: $($_.TaskName)"
        }
}


# 로그 저장
Save-OptLog

# Summary 출력
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows 11 25H2 AI 기능 비활성화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $($global:AppliedCount) 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $($global:SkippedCount) 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $($global:FailedCount) 개" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $($global:LogFilePath)" -ForegroundColor Cyan
Write-Host ""
Write-Host "비활성화된 기능:" -ForegroundColor Yellow
Write-Host "  - Windows Recall (스냅샷 캡처)" -ForegroundColor White
Write-Host "  - Windows Copilot / Edge Copilot" -ForegroundColor White
Write-Host "  - AI Actions / Click to Do" -ForegroundColor White
Write-Host "  - Input Insights (타이핑 데이터 수집)" -ForegroundColor White
Write-Host "  - Paint/Notepad/Photos AI 기능" -ForegroundColor White
Write-Host "  - AI Fabric Service" -ForegroundColor White
Write-Host "  - AI 텔레메트리" -ForegroundColor White
Write-Host "  - Voice Access AI / Live Captions" -ForegroundColor White
Write-Host "  - AI AppX 패키지 강제 제거" -ForegroundColor White
Write-Host "  - Recall Optional Feature 제거" -ForegroundColor White
Write-Host "  - AI 자동 설치 방지 정책" -ForegroundColor White
Write-Host "  - Windows Search AI 추천" -ForegroundColor White
Write-Host "  - Windows Spotlight AI" -ForegroundColor White
Write-Host "  - ML 서비스 및 AI 예약 작업" -ForegroundColor White
Write-Host ""
Write-Host "재부팅 후 모든 설정이 적용됩니다." -ForegroundColor Yellow
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
