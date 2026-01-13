# Windows 11 25H2 게임용 PC 최적화 스크립트
# VBS, Memory Integrity, GPU 스케줄링, 시각 효과, Xbox Game Bar 등 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.2"
$scriptName = "009.gaming_optimization.ps1"

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
$logFileName = "Windows11Optimizer_009_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
Windows 11 Optimization Log - Gaming Optimization
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
스크립트: $scriptName v$scriptVersion
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

Write-Host "=== Windows 11 25H2 게임용 PC 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "VBS 비활성화, GPU 최적화, 시각 효과 제거 등 게임 성능을 향상시킵니다." -ForegroundColor White
Write-Host ""
Write-Host "================================================" -ForegroundColor Red
Write-Host "경고: 이 스크립트는 일부 보안 기능을 비활성화합니다." -ForegroundColor Red
Write-Host "게임 전용 PC에서만 사용을 권장합니다." -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
Write-Host ""

if (-not $global:OrchestrateMode) {
    $confirm = Read-Host "계속하시겠습니까? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "사용자가 취소하였습니다." -ForegroundColor Red
        exit
    }
}

$totalSteps = 9
Write-Host ""


# [1/9] VBS (Virtualization-Based Security) 비활성화
Write-Host "[1/$totalSteps] VBS (Virtualization-Based Security) 비활성화 중..." -ForegroundColor Yellow
Write-Host "  - 예상 성능 향상: ~5%" -ForegroundColor Gray

$vbsStep = "VBS 비활성화"
$deviceGuardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"

# VBS 비활성화
Set-RegistryIfDifferent -Path $deviceGuardPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -StepName $vbsStep -Description "VBS"
Set-RegistryIfDifferent -Path $deviceGuardPath -Name "RequirePlatformSecurityFeatures" -Value 0 -StepName $vbsStep -Description "Platform Security Features"

# Credential Guard 비활성화
Set-RegistryIfDifferent -Path $deviceGuardPath -Name "LsaCfgFlags" -Value 0 -StepName $vbsStep -Description "Credential Guard"


# [2/9] Memory Integrity (HVCI) 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] Memory Integrity (HVCI) 비활성화 중..." -ForegroundColor Yellow

$hvciStep = "HVCI 비활성화"
$hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"

Set-RegistryIfDifferent -Path $hvciPath -Name "Enabled" -Value 0 -StepName $hvciStep -Description "Memory Integrity (HVCI)"
Write-Host "    확인: Windows 보안 > 장치 보안 > 코어 격리 > 메모리 무결성" -ForegroundColor Gray


# [3/9] Hardware-accelerated GPU Scheduling 활성화
Write-Host ""
Write-Host "[3/$totalSteps] Hardware-accelerated GPU Scheduling 활성화 중..." -ForegroundColor Yellow

$gpuStep = "GPU 스케줄링"
$graphicsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"

# HwSchMode: 1 = 비활성화, 2 = 활성화
Set-RegistryIfDifferent -Path $graphicsPath -Name "HwSchMode" -Value 2 -StepName $gpuStep -Description "Hardware-accelerated GPU Scheduling"
Write-Host "    참고: NVIDIA RTX 10xx+, AMD RX 5000+ 이상 필요" -ForegroundColor Gray


# [4/9] Game Mode 및 Game DVR 최적화
Write-Host ""
Write-Host "[4/$totalSteps] Game Mode 및 Game DVR 최적화 중..." -ForegroundColor Yellow

$gameModeStep = "Game Mode/DVR"
$gameModePath = "HKCU:\Software\Microsoft\GameBar"

# Game Mode 활성화
Set-RegistryIfDifferent -Path $gameModePath -Name "AllowAutoGameMode" -Value 1 -StepName $gameModeStep -Description "Auto Game Mode"
Set-RegistryIfDifferent -Path $gameModePath -Name "AutoGameModeEnabled" -Value 1 -StepName $gameModeStep -Description "Game Mode Enabled"

# Game DVR 비활성화 (녹화 기능 - 성능 영향)
$gameDVRPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
Set-RegistryIfDifferent -Path $gameDVRPath -Name "AppCaptureEnabled" -Value 0 -StepName $gameModeStep -Description "Game DVR (게임 녹화)"

# Game DVR 정책 비활성화
$gameDVRPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
Set-RegistryIfDifferent -Path $gameDVRPolicyPath -Name "AllowGameDVR" -Value 0 -StepName $gameModeStep -Description "Game DVR 정책"


# [5/9] 시각 효과 비활성화 (성능 우선)
Write-Host ""
Write-Host "[5/$totalSteps] 시각 효과 비활성화 중 (성능 우선)..." -ForegroundColor Yellow

$visualStep = "시각 효과"

# 시각 효과 설정
$visualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
# VisualFXSetting: 0 = 최적 모양, 1 = 최적 성능, 2 = 사용자 지정, 3 = 자동
Set-RegistryIfDifferent -Path $visualEffectsPath -Name "VisualFXSetting" -Value 2 -StepName $visualStep -Description "시각 효과 모드 (사용자 지정)"

# 투명 효과 비활성화
$personalizePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
Set-RegistryIfDifferent -Path $personalizePath -Name "EnableTransparency" -Value 0 -StepName $visualStep -Description "투명 효과"

# 애니메이션 효과 비활성화 (DragFullWindows는 유지)
$desktopPath = "HKCU:\Control Panel\Desktop"
$currentUserPrefs = (Get-ItemProperty -Path $desktopPath -Name "UserPreferencesMask" -ErrorAction SilentlyContinue).UserPreferencesMask
# 0x92: 비트1 활성화 = 전체 창 끌기 유지
$targetUserPrefs = [byte[]](0x92,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
if ($null -eq $currentUserPrefs -or ($currentUserPrefs -join ",") -ne ($targetUserPrefs -join ",")) {
    Set-ItemProperty -Path $desktopPath -Name "UserPreferencesMask" -Value $targetUserPrefs -Type Binary
    Write-Host "  - UserPreferencesMask : 적용됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $visualStep -Status "적용됨" -Message "UserPreferencesMask 변경됨"
} else {
    Write-Host "  - UserPreferencesMask : 이미 설정됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $visualStep -Status "스킵됨" -Message "UserPreferencesMask 이미 최적"
}

Set-RegistryIfDifferent -Path $desktopPath -Name "MinAnimate" -Value "0" -Type "String" -StepName $visualStep -Description "창 최소화 애니메이션"
# DragFullWindows 제거: 사용자가 창 드래그 시 전체 창 표시를 선호
Set-RegistryIfDifferent -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Type "String" -StepName $visualStep -Description "메뉴 표시 지연"

# 작업 표시줄 애니메이션 비활성화
$advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-RegistryIfDifferent -Path $advancedPath -Name "TaskbarAnimations" -Value 0 -StepName $visualStep -Description "작업 표시줄 애니메이션"


# [6/9] 전체 화면 최적화 비활성화
Write-Host ""
Write-Host "[6/$totalSteps] 전체 화면 최적화 비활성화 중..." -ForegroundColor Yellow

$fseStep = "전체 화면 최적화"
$gameConfigPath = "HKCU:\System\GameConfigStore"

# 전체 화면 최적화 비활성화
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_Enabled" -Value 0 -StepName $fseStep -Description "GameDVR"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -StepName $fseStep -Description "FSE Behavior Mode"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -StepName $fseStep -Description "Honor User FSE"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_FSEBehavior" -Value 2 -StepName $fseStep -Description "FSE Behavior"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -StepName $fseStep -Description "DXGI Honor FSE"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_EFSEFeatureFlags" -Value 0 -StepName $fseStep -Description "EFSE Feature Flags"

Write-Host "    게임별 설정: 실행 파일 > 속성 > 호환성 > 전체 화면 최적화 사용 안 함" -ForegroundColor Gray


# [7/9] Xbox Game Bar 완전 비활성화
Write-Host ""
Write-Host "[7/$totalSteps] Xbox Game Bar 완전 비활성화 중..." -ForegroundColor Yellow

$xboxStep = "Xbox Game Bar"

# Game Bar 비활성화
Set-RegistryIfDifferent -Path $gameModePath -Name "UseNexusForGameBarEnabled" -Value 0 -StepName $xboxStep -Description "Game Bar Nexus"
Set-RegistryIfDifferent -Path $gameModePath -Name "ShowStartupPanel" -Value 0 -StepName $xboxStep -Description "Game Bar Startup Panel"

# Game Bar 앱 비활성화
$gameBarFeaturePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
Set-RegistryIfDifferent -Path $gameBarFeaturePath -Name "AppCaptureEnabled" -Value 0 -StepName $xboxStep -Description "Game Bar Capture"

# Xbox Game Monitoring 서비스 비활성화
Set-ServiceIfDifferent -ServiceName "xbgm" -StartupType "Disabled" -StopService $true -StepName $xboxStep -Description "Xbox Game Monitoring"

# Xbox Accessory Management Service 비활성화
Set-ServiceIfDifferent -ServiceName "XboxGipSvc" -StartupType "Disabled" -StopService $true -StepName $xboxStep -Description "Xbox Accessory Management"


# [8/9] GPU 우선순위 및 시스템 응답성 최적화
Write-Host ""
Write-Host "[8/$totalSteps] GPU 우선순위 및 시스템 응답성 최적화 중..." -ForegroundColor Yellow

$priorityStep = "GPU/시스템 우선순위"

# 게임용 시스템 프로필 설정
$gamesProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"

Set-RegistryIfDifferent -Path $gamesProfilePath -Name "GPU Priority" -Value 8 -StepName $priorityStep -Description "게임 GPU Priority"
Set-RegistryIfDifferent -Path $gamesProfilePath -Name "Priority" -Value 6 -StepName $priorityStep -Description "게임 Priority"
Set-RegistryIfDifferent -Path $gamesProfilePath -Name "Scheduling Category" -Value "High" -Type "String" -StepName $priorityStep -Description "게임 Scheduling Category"
Set-RegistryIfDifferent -Path $gamesProfilePath -Name "SFIO Priority" -Value "High" -Type "String" -StepName $priorityStep -Description "게임 SFIO Priority"

# 시스템 응답성 설정 (0 = 게임 최적화, 백그라운드 서비스 리소스 최소화)
$systemProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-RegistryIfDifferent -Path $systemProfilePath -Name "SystemResponsiveness" -Value 0 -StepName $priorityStep -Description "시스템 응답성 (게임 최적화)"

# 네트워크 스로틀링 비활성화
Set-RegistryIfDifferent -Path $systemProfilePath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -StepName $priorityStep -Description "네트워크 스로틀링 비활성화"


# [9/9] AppX Deployment Service 수동 시작 (25H2)
Write-Host ""
Write-Host "[9/$totalSteps] AppX Deployment Service 최적화 (25H2)..." -ForegroundColor Yellow

$appxStep = "AppX/Delivery 서비스"

# AppX Deployment Service 수동 시작으로 변경
Set-ServiceIfDifferent -ServiceName "AppXSvc" -StartupType "Manual" -StepName $appxStep -Description "AppX Deployment Service"

# Delivery Optimization 서비스 수동으로 변경
Set-ServiceIfDifferent -ServiceName "DoSvc" -StartupType "Manual" -StepName $appxStep -Description "Delivery Optimization"

# 추가 불필요 서비스 비활성화
$gamingServices = @(
    @{ Name = "XblAuthManager"; Desc = "Xbox Live 인증 관리자" },
    @{ Name = "XblGameSave"; Desc = "Xbox Live 게임 저장" }
)

foreach ($svc in $gamingServices) {
    Set-ServiceIfDifferent -ServiceName $svc.Name -StartupType "Disabled" -StopService $true -StepName $appxStep -Description $svc.Desc
}


# ===== 로그 저장 =====
Save-OptLog


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "게임용 PC 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount 개" -ForegroundColor $(if ($global:FailedCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - VBS (Virtualization-Based Security) 비활성화 (~5% 성능 향상)" -ForegroundColor White
Write-Host "  - Memory Integrity (HVCI) 비활성화" -ForegroundColor White
Write-Host "  - Hardware-accelerated GPU Scheduling 활성화" -ForegroundColor White
Write-Host "  - Game Mode 활성화 및 Game DVR 비활성화" -ForegroundColor White
Write-Host "  - 시각 효과 비활성화 (투명, 애니메이션)" -ForegroundColor White
Write-Host "  - 전체 화면 최적화 비활성화" -ForegroundColor White
Write-Host "  - Xbox Game Bar 완전 비활성화" -ForegroundColor White
Write-Host "  - GPU 우선순위 및 시스템 응답성 최적화" -ForegroundColor White
Write-Host "  - AppX/Delivery Optimization 서비스 수동 시작" -ForegroundColor White
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================" -ForegroundColor Red
Write-Host "주의: VBS/HVCI 비활성화로 보안 수준이 낮아졌습니다." -ForegroundColor Red
Write-Host "이 PC는 게임 전용으로만 사용하세요." -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
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
