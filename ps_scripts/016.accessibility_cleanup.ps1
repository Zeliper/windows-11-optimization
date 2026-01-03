# Windows 11 25H2 접근성 기능 정리 스크립트
# 불필요한 접근성 단축키 팝업 방지 및 자동 시작 기능 비활성화
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

# Orchestrate 모드용 메타데이터
$script:ScriptMetadata = @{
    Name = "접근성 기능 정리"
    Description = "고정 키, 토글 키, 필터 키, 마우스 키 비활성화 및 접근성 자동 시작 기능 비활성화"
    RequiresReboot = $false
}

Write-Host "=== Windows 11 25H2 접근성 기능 정리 스크립트 ===" -ForegroundColor Cyan
Write-Host "불필요한 접근성 단축키 팝업 방지 및 자동 시작 기능을 비활성화합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 8


# [1/8] 고정 키 비활성화 (Shift 5회 연타 팝업 방지)
Write-Host "[1/$totalSteps] 고정 키 비활성화 중..." -ForegroundColor Yellow

$stickyKeysPath = "HKCU:\Control Panel\Accessibility\StickyKeys"
if (!(Test-Path $stickyKeysPath)) {
    New-Item -Path $stickyKeysPath -Force | Out-Null
}

# Flags 값 설정
# 506 = 고정 키 비활성화 + 단축키(Shift 5회) 비활성화 + 소리 비활성화
# 기본값은 510 (활성화 상태)
Set-ItemProperty -Path $stickyKeysPath -Name "Flags" -Value "506" -Type String -ErrorAction SilentlyContinue
Write-Host "  - 고정 키 기능: 비활성화" -ForegroundColor Green
Write-Host "  - Shift 5회 연타 팝업: 비활성화" -ForegroundColor Green


# [2/8] 토글 키 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] 토글 키 비활성화 중..." -ForegroundColor Yellow

$toggleKeysPath = "HKCU:\Control Panel\Accessibility\ToggleKeys"
if (!(Test-Path $toggleKeysPath)) {
    New-Item -Path $toggleKeysPath -Force | Out-Null
}

# Flags 값 설정
# 58 = 토글 키 비활성화 + 단축키(NumLock 5초) 비활성화
# 기본값은 62 (활성화 상태)
Set-ItemProperty -Path $toggleKeysPath -Name "Flags" -Value "58" -Type String -ErrorAction SilentlyContinue
Write-Host "  - 토글 키 기능: 비활성화" -ForegroundColor Green
Write-Host "  - NumLock 5초 누름 팝업: 비활성화" -ForegroundColor Green


# [3/8] 필터 키 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] 필터 키 비활성화 중..." -ForegroundColor Yellow

$filterKeysPath = "HKCU:\Control Panel\Accessibility\Keyboard Response"
if (!(Test-Path $filterKeysPath)) {
    New-Item -Path $filterKeysPath -Force | Out-Null
}

# Flags 값 설정
# 122 = 필터 키 비활성화 + 단축키(오른쪽 Shift 8초) 비활성화
# 기본값은 126 (활성화 상태)
Set-ItemProperty -Path $filterKeysPath -Name "Flags" -Value "122" -Type String -ErrorAction SilentlyContinue
Write-Host "  - 필터 키 기능: 비활성화" -ForegroundColor Green
Write-Host "  - 오른쪽 Shift 8초 누름 팝업: 비활성화" -ForegroundColor Green


# [4/8] 마우스 키 비활성화
Write-Host ""
Write-Host "[4/$totalSteps] 마우스 키 비활성화 중..." -ForegroundColor Yellow

$mouseKeysPath = "HKCU:\Control Panel\Accessibility\MouseKeys"
if (!(Test-Path $mouseKeysPath)) {
    New-Item -Path $mouseKeysPath -Force | Out-Null
}

# Flags 값 설정
# 58 = 마우스 키 비활성화 + 단축키(Alt+Shift+NumLock) 비활성화
# 기본값은 62 (활성화 상태)
Set-ItemProperty -Path $mouseKeysPath -Name "Flags" -Value "58" -Type String -ErrorAction SilentlyContinue
Write-Host "  - 마우스 키 기능: 비활성화" -ForegroundColor Green
Write-Host "  - Alt+Shift+NumLock 단축키: 비활성화" -ForegroundColor Green


# [5/8] 돋보기 자동 시작 비활성화
Write-Host ""
Write-Host "[5/$totalSteps] 돋보기 자동 시작 비활성화 중..." -ForegroundColor Yellow

$magnifierPath = "HKCU:\Software\Microsoft\ScreenMagnifier"
if (!(Test-Path $magnifierPath)) {
    New-Item -Path $magnifierPath -Force | Out-Null
}

# 돋보기 자동 시작 비활성화
Set-ItemProperty -Path $magnifierPath -Name "FollowCaret" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $magnifierPath -Name "FollowNarrator" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $magnifierPath -Name "FollowMouse" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $magnifierPath -Name "FollowFocus" -Value 0 -Type DWord -ErrorAction SilentlyContinue

# 로그온 시 돋보기 시작 비활성화
$accessibilityPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility"
if (!(Test-Path $accessibilityPath)) {
    New-Item -Path $accessibilityPath -Force | Out-Null
}

# Configuration 값에서 magnifierpane 제거 (ATconfig에서 자동 시작 비활성화)
$atConfig = Get-ItemProperty -Path $accessibilityPath -Name "Configuration" -ErrorAction SilentlyContinue
if ($atConfig -and $atConfig.Configuration) {
    $newConfig = $atConfig.Configuration -replace "magnifierpane", ""
    $newConfig = $newConfig -replace ";;", ";"
    $newConfig = $newConfig.Trim(";")
    Set-ItemProperty -Path $accessibilityPath -Name "Configuration" -Value $newConfig -ErrorAction SilentlyContinue
}

# HKLM 경로에서도 비활성화
$magnifierHKLMPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Accessibility\ATs\magnifier"
if (Test-Path $magnifierHKLMPath) {
    Set-ItemProperty -Path $magnifierHKLMPath -Name "StartExe" -Value "" -Type String -ErrorAction SilentlyContinue
}

Write-Host "  - 돋보기 자동 시작: 비활성화" -ForegroundColor Green
Write-Host "  - 돋보기 추적 옵션: 모두 비활성화" -ForegroundColor Green


# [6/8] 내레이터 자동 시작 비활성화
Write-Host ""
Write-Host "[6/$totalSteps] 내레이터 자동 시작 비활성화 중..." -ForegroundColor Yellow

$narratorPath = "HKCU:\Software\Microsoft\Narrator"
if (!(Test-Path $narratorPath)) {
    New-Item -Path $narratorPath -Force | Out-Null
}

# 내레이터 관련 설정
Set-ItemProperty -Path $narratorPath -Name "NarratorCursorHighlight" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $narratorPath -Name "IntonationPause" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $narratorPath -Name "ReadingWithIntent" -Value 0 -Type DWord -ErrorAction SilentlyContinue

# 내레이터 NoRoam 설정
$narratorNoRoamPath = "HKCU:\Software\Microsoft\Narrator\NoRoam"
if (!(Test-Path $narratorNoRoamPath)) {
    New-Item -Path $narratorNoRoamPath -Force | Out-Null
}

# 로그인 시 자동 시작 비활성화
Set-ItemProperty -Path $narratorNoRoamPath -Name "RunNarratorOnLogon" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $narratorNoRoamPath -Name "DuckAudio" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $narratorNoRoamPath -Name "WinEnterLaunchEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

# Configuration에서 narrator 제거
$atConfig = Get-ItemProperty -Path $accessibilityPath -Name "Configuration" -ErrorAction SilentlyContinue
if ($atConfig -and $atConfig.Configuration) {
    $newConfig = $atConfig.Configuration -replace "narrator", ""
    $newConfig = $newConfig -replace ";;", ";"
    $newConfig = $newConfig.Trim(";")
    Set-ItemProperty -Path $accessibilityPath -Name "Configuration" -Value $newConfig -ErrorAction SilentlyContinue
}

# Win+Enter로 내레이터 시작 비활성화
$narratorHotkeyPath = "HKCU:\Software\Microsoft\Narrator"
Set-ItemProperty -Path $narratorHotkeyPath -Name "WinEnterLaunchEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue

Write-Host "  - 내레이터 자동 시작: 비활성화" -ForegroundColor Green
Write-Host "  - Win+Enter 내레이터 단축키: 비활성화" -ForegroundColor Green


# [7/8] 화면 키보드 자동 시작 비활성화
Write-Host ""
Write-Host "[7/$totalSteps] 화면 키보드 자동 시작 비활성화 중..." -ForegroundColor Yellow

# 화면 키보드 (OSK) 자동 시작 비활성화
$oskPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Accessibility"
if (!(Test-Path $oskPath)) {
    New-Item -Path $oskPath -Force | Out-Null
}

# Configuration에서 osk 제거
$atConfig = Get-ItemProperty -Path $accessibilityPath -Name "Configuration" -ErrorAction SilentlyContinue
if ($atConfig -and $atConfig.Configuration) {
    $newConfig = $atConfig.Configuration -replace "osk", ""
    $newConfig = $newConfig -replace ";;", ";"
    $newConfig = $newConfig.Trim(";")
    Set-ItemProperty -Path $accessibilityPath -Name "Configuration" -Value $newConfig -ErrorAction SilentlyContinue
}

# 터치 키보드 자동 실행 비활성화
$tabTipPath = "HKCU:\Software\Microsoft\TabletTip\1.7"
if (!(Test-Path $tabTipPath)) {
    New-Item -Path $tabTipPath -Force | Out-Null
}

# 터치 키보드 자동 호출 비활성화
Set-ItemProperty -Path $tabTipPath -Name "EnableDesktopModeAutoInvoke" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $tabTipPath -Name "TipbandDesiredVisibility" -Value 0 -Type DWord -ErrorAction SilentlyContinue

Write-Host "  - 화면 키보드(OSK) 자동 시작: 비활성화" -ForegroundColor Green
Write-Host "  - 터치 키보드 자동 호출: 비활성화" -ForegroundColor Green


# [8/8] 고대비 테마 바로가기 비활성화
Write-Host ""
Write-Host "[8/$totalSteps] 고대비 테마 바로가기 비활성화 중..." -ForegroundColor Yellow

$highContrastPath = "HKCU:\Control Panel\Accessibility\HighContrast"
if (!(Test-Path $highContrastPath)) {
    New-Item -Path $highContrastPath -Force | Out-Null
}

# Flags 값 설정
# 4194 = 고대비 비활성화 + 단축키(왼쪽 Alt+왼쪽 Shift+PrintScreen) 비활성화
# 기본값은 4198 (활성화 상태)
Set-ItemProperty -Path $highContrastPath -Name "Flags" -Value "4194" -Type String -ErrorAction SilentlyContinue
Write-Host "  - 고대비 테마: 비활성화" -ForegroundColor Green
Write-Host "  - Alt+Shift+PrintScreen 단축키: 비활성화" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "접근성 기능 정리가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "비활성화된 설정:" -ForegroundColor Yellow
Write-Host "  - 고정 키 (Shift 5회 연타 팝업 방지)" -ForegroundColor White
Write-Host "  - 토글 키 (NumLock 5초 누름 팝업 방지)" -ForegroundColor White
Write-Host "  - 필터 키 (오른쪽 Shift 8초 팝업 방지)" -ForegroundColor White
Write-Host "  - 마우스 키 (Alt+Shift+NumLock 방지)" -ForegroundColor White
Write-Host "  - 돋보기 자동 시작" -ForegroundColor White
Write-Host "  - 내레이터 자동 시작" -ForegroundColor White
Write-Host "  - 화면 키보드 자동 시작" -ForegroundColor White
Write-Host "  - 고대비 테마 바로가기 (Alt+Shift+PrintScreen)" -ForegroundColor White
Write-Host ""
Write-Host "모든 설정이 즉시 적용되었습니다." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
