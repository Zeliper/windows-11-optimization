# Windows 11 25H2 AI 기능 비활성화 스크립트
# Recall, Copilot, AI Actions, Click to Do, 텔레메트리 비활성화
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

Write-Host "=== Windows 11 25H2 AI 기능 비활성화 스크립트 ===" -ForegroundColor Cyan
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


# [1/8] Windows Recall 비활성화
Write-Host "[1/$totalSteps] Windows Recall 비활성화 중..." -ForegroundColor Yellow

$windowsAIPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
if (!(Test-Path $windowsAIPath)) {
    New-Item -Path $windowsAIPath -Force | Out-Null
}

# AllowRecallEnablement = 0 (Recall 비활성화)
Set-ItemProperty -Path $windowsAIPath -Name "AllowRecallEnablement" -Value 0 -Type DWord
Write-Host "  - AllowRecallEnablement 비활성화" -ForegroundColor Green

# DisableAIDataAnalysis = 1 (AI 데이터 분석 비활성화)
Set-ItemProperty -Path $windowsAIPath -Name "DisableAIDataAnalysis" -Value 1 -Type DWord
Write-Host "  - DisableAIDataAnalysis 활성화" -ForegroundColor Green

# HKCU에도 설정 적용
$windowsAIPathUser = "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI"
if (!(Test-Path $windowsAIPathUser)) {
    New-Item -Path $windowsAIPathUser -Force | Out-Null
}
Set-ItemProperty -Path $windowsAIPathUser -Name "DisableAIDataAnalysis" -Value 1 -Type DWord
Write-Host "  - 사용자 레벨 AI 데이터 분석 비활성화" -ForegroundColor Green

# Recall 예약 작업 비활성화
$recallTasks = @(
    "\Microsoft\Windows\WindowsAI\RecallBackgroundActivity"
    "\Microsoft\Windows\WindowsAI\RecallHistoryCreation"
)
foreach ($task in $recallTasks) {
    Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "  - Recall 예약 작업 비활성화" -ForegroundColor Green


# [2/8] Windows Copilot 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] Windows Copilot 비활성화 중..." -ForegroundColor Yellow

# HKCU Copilot 정책
$copilotPathUser = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
if (!(Test-Path $copilotPathUser)) {
    New-Item -Path $copilotPathUser -Force | Out-Null
}
Set-ItemProperty -Path $copilotPathUser -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord
Write-Host "  - 사용자 레벨 Copilot 비활성화" -ForegroundColor Green

# HKLM Copilot 정책
$copilotPathMachine = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
if (!(Test-Path $copilotPathMachine)) {
    New-Item -Path $copilotPathMachine -Force | Out-Null
}
Set-ItemProperty -Path $copilotPathMachine -Name "TurnOffWindowsCopilot" -Value 1 -Type DWord
Write-Host "  - 시스템 레벨 Copilot 비활성화" -ForegroundColor Green

# Copilot 앱 제거
$copilotPackages = @(
    "Microsoft.Copilot"
    "Microsoft.Windows.Copilot"
    "Microsoft.CopilotRuntime"
)
foreach ($pkg in $copilotPackages) {
    Get-AppxPackage -AllUsers -Name "*$pkg*" -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.PackageName -like "*$pkg*" } |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "  - Copilot 앱 패키지 제거" -ForegroundColor Green

# Edge Copilot 비활성화
$edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (!(Test-Path $edgePolicyPath)) {
    New-Item -Path $edgePolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $edgePolicyPath -Name "HubsSidebarEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $edgePolicyPath -Name "CopilotCDPPageContext" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Edge Copilot 사이드바 비활성화" -ForegroundColor Green


# [3/8] AI Actions / Click to Do 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] AI Actions / Click to Do 비활성화 중..." -ForegroundColor Yellow

# AI Actions 레지스트리 비활성화
$aiActionsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $aiActionsPath -Name "ShowAIActions" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 파일 탐색기 AI Actions 메뉴 비활성화" -ForegroundColor Green

# Click to Do 비활성화
$clickToDoPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard"
if (!(Test-Path $clickToDoPath)) {
    New-Item -Path $clickToDoPath -Force | Out-Null
}
Set-ItemProperty -Path $clickToDoPath -Name "Disabled" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Click to Do (Smart Clipboard) 비활성화" -ForegroundColor Green


# [4/8] Input Insights 비활성화
Write-Host ""
Write-Host "[4/$totalSteps] Input Insights (타이핑 데이터 수집) 비활성화 중..." -ForegroundColor Yellow

$inputInsightsPath = "HKCU:\Software\Microsoft\Input\Settings"
if (!(Test-Path $inputInsightsPath)) {
    New-Item -Path $inputInsightsPath -Force | Out-Null
}
Set-ItemProperty -Path $inputInsightsPath -Name "InsightsEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Input Insights 비활성화" -ForegroundColor Green

# 개인 맞춤화 비활성화
$personalizationPath = "HKCU:\Software\Microsoft\Personalization\Settings"
if (!(Test-Path $personalizationPath)) {
    New-Item -Path $personalizationPath -Force | Out-Null
}
Set-ItemProperty -Path $personalizationPath -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 입력 개인 맞춤화 비활성화" -ForegroundColor Green


# [5/8] 앱 내 AI 기능 비활성화 (Paint, Notepad 등)
Write-Host ""
Write-Host "[5/$totalSteps] 앱 내 AI 기능 비활성화 (Paint, Notepad 등)..." -ForegroundColor Yellow

# Paint Image Creator 비활성화
$paintAIPath = "HKCU:\Software\Microsoft\Paint"
if (!(Test-Path $paintAIPath)) {
    New-Item -Path $paintAIPath -Force | Out-Null
}
Set-ItemProperty -Path $paintAIPath -Name "CocreatorEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $paintAIPath -Name "ImageCreatorEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Paint AI Image Creator 비활성화" -ForegroundColor Green

# Notepad Rewrite AI 비활성화
$notepadAIPath = "HKCU:\Software\Microsoft\Notepad"
if (!(Test-Path $notepadAIPath)) {
    New-Item -Path $notepadAIPath -Force | Out-Null
}
Set-ItemProperty -Path $notepadAIPath -Name "RewriteEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Notepad Rewrite AI 비활성화" -ForegroundColor Green

# Photos AI 기능 비활성화
$photosAIPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Photos"
if (!(Test-Path $photosAIPath)) {
    New-Item -Path $photosAIPath -Force | Out-Null
}
Set-ItemProperty -Path $photosAIPath -Name "AiErasingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $photosAIPath -Name "AiSuggestionsEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Photos AI 기능 비활성화" -ForegroundColor Green


# [6/8] AI Fabric Service 비활성화
Write-Host ""
Write-Host "[6/$totalSteps] AI Fabric Service 비활성화 중..." -ForegroundColor Yellow

# AI 관련 서비스 비활성화
$aiServices = @(
    "AIXHost"              # AI Experience Host
    "AIFabricService"      # AI Fabric Service
)

foreach ($service in $aiServices) {
    $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  - $service 서비스 비활성화" -ForegroundColor Green
    }
}
Write-Host "  - AI 서비스 확인 완료" -ForegroundColor Green


# [7/8] AI 관련 텔레메트리 비활성화
Write-Host ""
Write-Host "[7/$totalSteps] AI 관련 텔레메트리 비활성화 중..." -ForegroundColor Yellow

# AI 진단 데이터 비활성화
$diagPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack"
if (!(Test-Path $diagPath)) {
    New-Item -Path $diagPath -Force | Out-Null
}
Set-ItemProperty -Path $diagPath -Name "AIDataCollection" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - AI 진단 데이터 수집 비활성화" -ForegroundColor Green

# 검색 박스 AI 제안 비활성화
$explorerPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
if (!(Test-Path $explorerPath)) {
    New-Item -Path $explorerPath -Force | Out-Null
}
Set-ItemProperty -Path $explorerPath -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord
Write-Host "  - 검색 상자 AI 제안 비활성화" -ForegroundColor Green

# 클라우드 최적화 콘텐츠 비활성화
$systemPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (!(Test-Path $systemPolicyPath)) {
    New-Item -Path $systemPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $systemPolicyPath -Name "DisableCloudOptimizedContent" -Value 1 -Type DWord
Write-Host "  - 클라우드 최적화 콘텐츠 비활성화" -ForegroundColor Green


# [8/8] Voice Access AI 기능 비활성화
Write-Host ""
Write-Host "[8/$totalSteps] Voice Access AI 기능 비활성화 중..." -ForegroundColor Yellow

$voiceAccessPath = "HKCU:\Software\Microsoft\Speech_OneCore\Settings\VoiceAccess"
if (!(Test-Path $voiceAccessPath)) {
    New-Item -Path $voiceAccessPath -Force | Out-Null
}
Set-ItemProperty -Path $voiceAccessPath -Name "AIVoiceEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Voice Access AI 음성 효과 비활성화" -ForegroundColor Green

# Live Captions 비활성화
$liveCaptionsPath = "HKCU:\Software\Microsoft\Accessibility"
if (!(Test-Path $liveCaptionsPath)) {
    New-Item -Path $liveCaptionsPath -Force | Out-Null
}
Set-ItemProperty -Path $liveCaptionsPath -Name "LiveCaptionsEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Live Captions 비활성화" -ForegroundColor Green


# [9/14] AI AppX 패키지 강제 제거
Write-Host ""
Write-Host "[9/$totalSteps] AI AppX 패키지 강제 제거 중..." -ForegroundColor Yellow

$aiPackagePatterns = @(
    "*Copilot*"
    "*Recall*"
    "*Microsoft.Windows.Ai*"
    "*Microsoft.AI*"
)

foreach ($pattern in $aiPackagePatterns) {
    # 사용자 패키지 제거
    Get-AppxPackage -AllUsers -Name $pattern -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host "  - 제거 중: $($_.Name)" -ForegroundColor White
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
    # 프로비저닝 패키지 제거
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $pattern } |
        ForEach-Object {
            Write-Host "  - 프로비저닝 제거 중: $($_.DisplayName)" -ForegroundColor White
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
        }
}
Write-Host "  - AI 패키지 제거 완료" -ForegroundColor Green


# [10/14] Recall Optional Feature 제거
Write-Host ""
Write-Host "[10/$totalSteps] Recall Optional Feature 제거 중..." -ForegroundColor Yellow

try {
    # DISM으로 Recall 기능 제거 시도
    $recallFeature = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue
    if ($recallFeature -and $recallFeature.State -eq "Enabled") {
        Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  - Recall 선택적 기능 제거됨" -ForegroundColor Green
    } else {
        Write-Host "  - Recall 기능이 설치되어 있지 않거나 이미 비활성화됨" -ForegroundColor Green
    }
} catch {
    Write-Host "  - Recall 기능 제거 건너뜀 (설치되지 않음)" -ForegroundColor Green
}


# [11/14] AI 자동 설치 방지 정책
Write-Host ""
Write-Host "[11/$totalSteps] AI 자동 설치 방지 정책 설정 중..." -ForegroundColor Yellow

# ContentDeliveryManager - 자동 앱 설치 비활성화
$cdmPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (!(Test-Path $cdmPath)) {
    New-Item -Path $cdmPath -Force | Out-Null
}
Set-ItemProperty -Path $cdmPath -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPath -Name "ContentDeliveryAllowed" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPath -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPath -Name "PreInstalledAppsEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPath -Name "PreInstalledAppsEverEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPath -Name "SoftLandingEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPath -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord
Write-Host "  - 앱 자동 설치 비활성화" -ForegroundColor Green

# AI 자동 배포 차단
$deploymentPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Experience"
if (!(Test-Path $deploymentPath)) {
    New-Item -Path $deploymentPath -Force | Out-Null
}
Set-ItemProperty -Path $deploymentPath -Name "AllowCopilot" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - AI 자동 배포 정책 설정" -ForegroundColor Green


# [12/14] Windows Search AI 추천 비활성화
Write-Host ""
Write-Host "[12/$totalSteps] Windows Search AI 추천 비활성화 중..." -ForegroundColor Yellow

# Search 설정
$searchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
if (!(Test-Path $searchPath)) {
    New-Item -Path $searchPath -Force | Out-Null
}
Set-ItemProperty -Path $searchPath -Name "BingSearchEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $searchPath -Name "CortanaConsent" -Value 0 -Type DWord
Set-ItemProperty -Path $searchPath -Name "AllowCloudSearch" -Value 0 -Type DWord
Set-ItemProperty -Path $searchPath -Name "AllowSearchToUseLocation" -Value 0 -Type DWord
Write-Host "  - Bing/Cloud 검색 비활성화" -ForegroundColor Green

# SearchSettings - 검색 하이라이트 비활성화
$searchSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
if (!(Test-Path $searchSettingsPath)) {
    New-Item -Path $searchSettingsPath -Force | Out-Null
}
Set-ItemProperty -Path $searchSettingsPath -Name "IsDynamicSearchBoxEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $searchSettingsPath -Name "IsAADCloudSearchEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $searchSettingsPath -Name "IsMSACloudSearchEnabled" -Value 0 -Type DWord
Write-Host "  - 검색 하이라이트/클라우드 검색 비활성화" -ForegroundColor Green

# 검색 히스토리 비활성화
$historyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $historyPath -Name "Start_TrackDocs" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 검색 히스토리 비활성화" -ForegroundColor Green


# [13/14] Windows Spotlight AI 비활성화
Write-Host ""
Write-Host "[13/$totalSteps] Windows Spotlight AI 비활성화 중..." -ForegroundColor Yellow

# Spotlight 및 추천 콘텐츠 비활성화
$cdmPathSpotlight = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
Set-ItemProperty -Path $cdmPathSpotlight -Name "RotatingLockScreenEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPathSpotlight -Name "RotatingLockScreenOverlayEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPathSpotlight -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPathSpotlight -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPathSpotlight -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPathSpotlight -Name "SubscribedContent-353694Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPathSpotlight -Name "SubscribedContent-353696Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $cdmPathSpotlight -Name "SubscribedContent-310093Enabled" -Value 0 -Type DWord
Write-Host "  - Windows Spotlight 비활성화" -ForegroundColor Green

# 잠금 화면 팁 비활성화
Set-ItemProperty -Path $cdmPathSpotlight -Name "SubscribedContent-338393Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $cdmPathSpotlight -Name "SubscribedContent-353698Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 잠금 화면 팁/추천 비활성화" -ForegroundColor Green


# [14/14] ML 서비스 및 AI 예약 작업 비활성화
Write-Host ""
Write-Host "[14/$totalSteps] ML 서비스 및 AI 예약 작업 비활성화 중..." -ForegroundColor Yellow

# Machine Learning Service 비활성화
$mlServices = @("mlsvc", "WMPNetworkSvc")
foreach ($svc in $mlServices) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  - $svc 서비스 비활성화" -ForegroundColor Green
    }
}

# AI 관련 예약 작업 비활성화
$aiTaskPaths = @(
    "\Microsoft\Windows\AI\"
    "\Microsoft\Windows\Shell\AI\"
    "\Microsoft\Windows\WindowsAI\"
)

foreach ($taskPath in $aiTaskPaths) {
    Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue |
        ForEach-Object {
            Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  - 작업 비활성화: $($_.TaskName)" -ForegroundColor White
        }
}
Write-Host "  - AI 예약 작업 비활성화 완료" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows 11 25H2 AI 기능 비활성화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
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
