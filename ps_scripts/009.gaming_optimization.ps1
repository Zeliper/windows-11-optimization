# Windows 11 25H2 게임용 PC 최적화 스크립트
# VBS, Memory Integrity, GPU 스케줄링, 시각 효과, Xbox Game Bar 등 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "=== Windows 11 25H2 게임용 PC 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "VBS 비활성화, GPU 최적화, 시각 효과 제거 등 게임 성능을 향상시킵니다." -ForegroundColor White
Write-Host ""
Write-Host "================================================" -ForegroundColor Red
Write-Host "경고: 이 스크립트는 일부 보안 기능을 비활성화합니다." -ForegroundColor Red
Write-Host "게임 전용 PC에서만 사용을 권장합니다." -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "계속하시겠습니까? (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "사용자가 취소하였습니다." -ForegroundColor Red
    exit
}

$totalSteps = 9
Write-Host ""


# [1/9] VBS (Virtualization-Based Security) 비활성화
Write-Host "[1/$totalSteps] VBS (Virtualization-Based Security) 비활성화 중..." -ForegroundColor Yellow
Write-Host "  - 예상 성능 향상: ~5%" -ForegroundColor Gray

$deviceGuardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
if (!(Test-Path $deviceGuardPath)) {
    New-Item -Path $deviceGuardPath -Force | Out-Null
}

# VBS 비활성화
Set-ItemProperty -Path $deviceGuardPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord
Set-ItemProperty -Path $deviceGuardPath -Name "RequirePlatformSecurityFeatures" -Value 0 -Type DWord
Write-Host "  - VBS 비활성화 완료" -ForegroundColor Green

# Credential Guard 비활성화
Set-ItemProperty -Path $deviceGuardPath -Name "LsaCfgFlags" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Credential Guard 비활성화" -ForegroundColor Green


# [2/9] Memory Integrity (HVCI) 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] Memory Integrity (HVCI) 비활성화 중..." -ForegroundColor Yellow

$hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
if (!(Test-Path $hvciPath)) {
    New-Item -Path $hvciPath -Force | Out-Null
}

Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value 0 -Type DWord
Write-Host "  - Memory Integrity (HVCI) 비활성화 완료" -ForegroundColor Green
Write-Host "    확인: Windows 보안 > 장치 보안 > 코어 격리 > 메모리 무결성" -ForegroundColor Gray


# [3/9] Hardware-accelerated GPU Scheduling 활성화
Write-Host ""
Write-Host "[3/$totalSteps] Hardware-accelerated GPU Scheduling 활성화 중..." -ForegroundColor Yellow

$graphicsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
if (!(Test-Path $graphicsPath)) {
    New-Item -Path $graphicsPath -Force | Out-Null
}

# HwSchMode: 1 = 비활성화, 2 = 활성화
Set-ItemProperty -Path $graphicsPath -Name "HwSchMode" -Value 2 -Type DWord
Write-Host "  - Hardware-accelerated GPU Scheduling 활성화 완료" -ForegroundColor Green
Write-Host "    참고: NVIDIA RTX 10xx+, AMD RX 5000+ 이상 필요" -ForegroundColor Gray


# [4/9] Game Mode 및 Game DVR 최적화
Write-Host ""
Write-Host "[4/$totalSteps] Game Mode 및 Game DVR 최적화 중..." -ForegroundColor Yellow

# Game Mode 활성화
$gameModePath = "HKCU:\Software\Microsoft\GameBar"
if (!(Test-Path $gameModePath)) {
    New-Item -Path $gameModePath -Force | Out-Null
}
Set-ItemProperty -Path $gameModePath -Name "AllowAutoGameMode" -Value 1 -Type DWord
Set-ItemProperty -Path $gameModePath -Name "AutoGameModeEnabled" -Value 1 -Type DWord
Write-Host "  - Game Mode 활성화" -ForegroundColor Green

# Game DVR 비활성화 (녹화 기능 - 성능 영향)
$gameDVRPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
if (!(Test-Path $gameDVRPath)) {
    New-Item -Path $gameDVRPath -Force | Out-Null
}
Set-ItemProperty -Path $gameDVRPath -Name "AppCaptureEnabled" -Value 0 -Type DWord
Write-Host "  - Game DVR (게임 녹화) 비활성화" -ForegroundColor Green

# Game DVR 정책 비활성화
$gameDVRPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (!(Test-Path $gameDVRPolicyPath)) {
    New-Item -Path $gameDVRPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $gameDVRPolicyPath -Name "AllowGameDVR" -Value 0 -Type DWord
Write-Host "  - Game DVR 정책 비활성화" -ForegroundColor Green


# [5/9] 시각 효과 비활성화 (성능 우선)
Write-Host ""
Write-Host "[5/$totalSteps] 시각 효과 비활성화 중 (성능 우선)..." -ForegroundColor Yellow

# 시각 효과 설정
$visualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
if (!(Test-Path $visualEffectsPath)) {
    New-Item -Path $visualEffectsPath -Force | Out-Null
}
# VisualFXSetting: 0 = 최적 모양, 1 = 최적 성능, 2 = 사용자 지정, 3 = 자동
Set-ItemProperty -Path $visualEffectsPath -Name "VisualFXSetting" -Value 2 -Type DWord
Write-Host "  - 시각 효과 사용자 지정 모드 설정" -ForegroundColor Green

# 투명 효과 비활성화
$personalizePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (!(Test-Path $personalizePath)) {
    New-Item -Path $personalizePath -Force | Out-Null
}
Set-ItemProperty -Path $personalizePath -Name "EnableTransparency" -Value 0 -Type DWord
Write-Host "  - 투명 효과 비활성화" -ForegroundColor Green

# 애니메이션 효과 비활성화
$desktopPath = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $desktopPath -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary
Set-ItemProperty -Path $desktopPath -Name "MinAnimate" -Value "0" -Type String
Set-ItemProperty -Path $desktopPath -Name "DragFullWindows" -Value "0" -Type String
Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Type String
Write-Host "  - 애니메이션 효과 비활성화" -ForegroundColor Green

# 작업 표시줄 애니메이션 비활성화
$advancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $advancedPath -Name "TaskbarAnimations" -Value 0 -Type DWord
Write-Host "  - 작업 표시줄 애니메이션 비활성화" -ForegroundColor Green


# [6/9] 전체 화면 최적화 비활성화
Write-Host ""
Write-Host "[6/$totalSteps] 전체 화면 최적화 비활성화 중..." -ForegroundColor Yellow

$gameConfigPath = "HKCU:\System\GameConfigStore"
if (!(Test-Path $gameConfigPath)) {
    New-Item -Path $gameConfigPath -Force | Out-Null
}

# 전체 화면 최적화 비활성화
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_Enabled" -Value 0 -Type DWord
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_EFSEFeatureFlags" -Value 0 -Type DWord
Write-Host "  - 전체 화면 최적화 비활성화 완료" -ForegroundColor Green
Write-Host "    게임별 설정: 실행 파일 > 속성 > 호환성 > 전체 화면 최적화 사용 안 함" -ForegroundColor Gray


# [7/9] Xbox Game Bar 완전 비활성화
Write-Host ""
Write-Host "[7/$totalSteps] Xbox Game Bar 완전 비활성화 중..." -ForegroundColor Yellow

# Game Bar 비활성화
Set-ItemProperty -Path $gameModePath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $gameModePath -Name "ShowStartupPanel" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Xbox Game Bar 오버레이 비활성화" -ForegroundColor Green

# Game Bar 앱 비활성화
$gameBarFeaturePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
if (!(Test-Path $gameBarFeaturePath)) {
    New-Item -Path $gameBarFeaturePath -Force | Out-Null
}
Set-ItemProperty -Path $gameBarFeaturePath -Name "AppCaptureEnabled" -Value 0 -Type DWord
Write-Host "  - Game Bar 캡처 기능 비활성화" -ForegroundColor Green

# Xbox Game Monitoring 서비스 비활성화
Stop-Service -Name "xbgm" -Force -ErrorAction SilentlyContinue
Set-Service -Name "xbgm" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - Xbox Game Monitoring 서비스 비활성화" -ForegroundColor Green

# Xbox Accessory Management Service 비활성화
Stop-Service -Name "XboxGipSvc" -Force -ErrorAction SilentlyContinue
Set-Service -Name "XboxGipSvc" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - Xbox Accessory Management Service 비활성화" -ForegroundColor Green


# [8/9] GPU 우선순위 및 시스템 응답성 최적화
Write-Host ""
Write-Host "[8/$totalSteps] GPU 우선순위 및 시스템 응답성 최적화 중..." -ForegroundColor Yellow

# 게임용 시스템 프로필 설정
$gamesProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
if (!(Test-Path $gamesProfilePath)) {
    New-Item -Path $gamesProfilePath -Force | Out-Null
}

Set-ItemProperty -Path $gamesProfilePath -Name "GPU Priority" -Value 8 -Type DWord
Set-ItemProperty -Path $gamesProfilePath -Name "Priority" -Value 6 -Type DWord
Set-ItemProperty -Path $gamesProfilePath -Name "Scheduling Category" -Value "High" -Type String
Set-ItemProperty -Path $gamesProfilePath -Name "SFIO Priority" -Value "High" -Type String
Write-Host "  - 게임 GPU 우선순위 최적화" -ForegroundColor Green

# 시스템 응답성 설정 (0 = 게임 최적화, 백그라운드 서비스 리소스 최소화)
$systemProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $systemProfilePath -Name "SystemResponsiveness" -Value 0 -Type DWord
Write-Host "  - 시스템 응답성 게임용 최적화" -ForegroundColor Green

# 네트워크 스로틀링 비활성화
Set-ItemProperty -Path $systemProfilePath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord
Write-Host "  - 네트워크 스로틀링 비활성화" -ForegroundColor Green


# [9/9] AppX Deployment Service 수동 시작 (25H2)
Write-Host ""
Write-Host "[9/$totalSteps] AppX Deployment Service 최적화 (25H2)..." -ForegroundColor Yellow

$appxService = Get-Service -Name "AppXSvc" -ErrorAction SilentlyContinue
if ($appxService) {
    Set-Service -Name "AppXSvc" -StartupType Manual -ErrorAction SilentlyContinue
    Write-Host "  - AppX Deployment Service 수동 시작으로 변경" -ForegroundColor Green
}

# Delivery Optimization 서비스 수동으로 변경
Set-Service -Name "DoSvc" -StartupType Manual -ErrorAction SilentlyContinue
Write-Host "  - Delivery Optimization 서비스 수동 시작으로 변경" -ForegroundColor Green

# 추가 불필요 서비스 비활성화
$gamingServices = @(
    "XblAuthManager",  # Xbox Live 인증 관리자
    "XblGameSave"      # Xbox Live 게임 저장
)

foreach ($service in $gamingServices) {
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
}
Write-Host "  - Xbox Live 관련 서비스 비활성화" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "게임용 PC 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
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
Write-Host "================================================" -ForegroundColor Red
Write-Host "주의: VBS/HVCI 비활성화로 보안 수준이 낮아졌습니다." -ForegroundColor Red
Write-Host "이 PC는 게임 전용으로만 사용하세요." -ForegroundColor Red
Write-Host "================================================" -ForegroundColor Red
Write-Host ""
Write-Host "재부팅 후 모든 설정이 적용됩니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인
$restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host "10초 후 재부팅됩니다..." -ForegroundColor Red
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "나중에 수동으로 재부팅해주세요." -ForegroundColor Yellow
}
