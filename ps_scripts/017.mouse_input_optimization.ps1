# Windows 11 마우스/입력 장치 최적화 스크립트
# 마우스 가속도 비활성화, 키보드 반복 속도 최적화, 입력 지연 최소화
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

Write-Host "=== Windows 11 마우스/입력 장치 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "마우스 가속 비활성화, 키보드 속도 최적화, 입력 지연 최소화를 수행합니다." -ForegroundColor White
Write-Host "게이머 및 정밀 작업 사용자에게 권장됩니다." -ForegroundColor White
Write-Host ""

$totalSteps = 6


# [1/6] 마우스 가속도 비활성화
Write-Host "[1/$totalSteps] 마우스 가속도 비활성화 중..." -ForegroundColor Yellow

$mousePath = "HKCU:\Control Panel\Mouse"

# MouseSpeed = 0 (가속 곡선 비활성화)
Set-ItemProperty -Path $mousePath -Name "MouseSpeed" -Value "0" -Type String
Write-Host "  - MouseSpeed: 0 (가속 곡선 비활성화)" -ForegroundColor Green

# MouseThreshold1 = 0 (가속 시작 임계값 1)
Set-ItemProperty -Path $mousePath -Name "MouseThreshold1" -Value "0" -Type String
Write-Host "  - MouseThreshold1: 0" -ForegroundColor Green

# MouseThreshold2 = 0 (가속 시작 임계값 2)
Set-ItemProperty -Path $mousePath -Name "MouseThreshold2" -Value "0" -Type String
Write-Host "  - MouseThreshold2: 0" -ForegroundColor Green


# [2/6] 마우스 포인터 정확도 향상 (Enhance Pointer Precision 비활성화)
Write-Host ""
Write-Host "[2/$totalSteps] 마우스 포인터 정확도 향상 설정 중..." -ForegroundColor Yellow

# MouseSensitivity = 10 (중간값, 1:1 매핑)
Set-ItemProperty -Path $mousePath -Name "MouseSensitivity" -Value "10" -Type String
Write-Host "  - MouseSensitivity: 10 (1:1 매핑)" -ForegroundColor Green

# SmoothMouseXCurve / SmoothMouseYCurve - 선형 곡선으로 설정 (가속 없음)
$linearXCurve = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                          0xC0,0xCC,0x0C,0x00,0x00,0x00,0x00,0x00,
                          0x80,0x99,0x19,0x00,0x00,0x00,0x00,0x00,
                          0x40,0x66,0x26,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x33,0x33,0x00,0x00,0x00,0x00,0x00)
$linearYCurve = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x00,0x70,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x00,0xA8,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x00,0xE0,0x00,0x00,0x00,0x00,0x00)

Set-ItemProperty -Path $mousePath -Name "SmoothMouseXCurve" -Value $linearXCurve -Type Binary
Set-ItemProperty -Path $mousePath -Name "SmoothMouseYCurve" -Value $linearYCurve -Type Binary
Write-Host "  - SmoothMouseXCurve/YCurve: 선형 곡선 적용 (가속 없음)" -ForegroundColor Green


# [3/6] 키보드 반복 속도 최적화
Write-Host ""
Write-Host "[3/$totalSteps] 키보드 반복 속도 최적화 중..." -ForegroundColor Yellow

$keyboardPath = "HKCU:\Control Panel\Keyboard"

# KeyboardDelay = 0 (0=최소 지연, 3=최대 지연)
Set-ItemProperty -Path $keyboardPath -Name "KeyboardDelay" -Value "0" -Type String
Write-Host "  - KeyboardDelay: 0 (최소 지연)" -ForegroundColor Green

# KeyboardSpeed = 31 (0=최소 속도, 31=최대 속도)
Set-ItemProperty -Path $keyboardPath -Name "KeyboardSpeed" -Value "31" -Type String
Write-Host "  - KeyboardSpeed: 31 (최대 속도)" -ForegroundColor Green


# [4/6] 입력 지연 최소화
Write-Host ""
Write-Host "[4/$totalSteps] 입력 지연 최소화 설정 중..." -ForegroundColor Yellow

# 마우스 데이터 큐 크기 증가
$mouseclassPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
if (!(Test-Path $mouseclassPath)) {
    New-Item -Path $mouseclassPath -Force | Out-Null
}
Set-ItemProperty -Path $mouseclassPath -Name "MouseDataQueueSize" -Value 100 -Type DWord
Write-Host "  - MouseDataQueueSize: 100 (데이터 큐 증가)" -ForegroundColor Green

# 키보드 데이터 큐 크기 증가
$kbdclassPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
if (!(Test-Path $kbdclassPath)) {
    New-Item -Path $kbdclassPath -Force | Out-Null
}
Set-ItemProperty -Path $kbdclassPath -Name "KeyboardDataQueueSize" -Value 100 -Type DWord
Write-Host "  - KeyboardDataQueueSize: 100 (데이터 큐 증가)" -ForegroundColor Green


# [5/6] 게임용 입력 우선순위 설정
Write-Host ""
Write-Host "[5/$totalSteps] 게임용 입력 우선순위 설정 중..." -ForegroundColor Yellow

# MMCSS (Multimedia Class Scheduler Service) 최적화
$mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
if (!(Test-Path $mmcssPath)) {
    New-Item -Path $mmcssPath -Force | Out-Null
}

# 시스템 응답성 최적화 (이미 009에서 설정될 수 있으나 독립 실행 대비)
$currentValue = Get-ItemProperty -Path $mmcssPath -Name "SystemResponsiveness" -ErrorAction SilentlyContinue
if ($null -eq $currentValue -or $currentValue.SystemResponsiveness -ne 0) {
    Set-ItemProperty -Path $mmcssPath -Name "SystemResponsiveness" -Value 0 -Type DWord
    Write-Host "  - SystemResponsiveness: 0 (게임/입력 우선)" -ForegroundColor Green
} else {
    Write-Host "  - SystemResponsiveness: 이미 최적화됨" -ForegroundColor Gray
}

# 프레임 서버 모드 비활성화 (마우스 입력 지연 감소)
$frameServerPath = "HKLM:\SOFTWARE\Microsoft\Windows Media Foundation\Platform"
if (!(Test-Path $frameServerPath)) {
    New-Item -Path $frameServerPath -Force | Out-Null
}
Set-ItemProperty -Path $frameServerPath -Name "EnableFrameServerMode" -Value 0 -Type DWord
Write-Host "  - FrameServerMode: 비활성화 (입력 지연 감소)" -ForegroundColor Green

# WOW64 경로도 설정 (32비트 앱 호환)
$frameServerPathWow64 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Media Foundation\Platform"
if (!(Test-Path $frameServerPathWow64)) {
    New-Item -Path $frameServerPathWow64 -Force | Out-Null
}
Set-ItemProperty -Path $frameServerPathWow64 -Name "EnableFrameServerMode" -Value 0 -Type DWord
Write-Host "  - FrameServerMode (WOW64): 비활성화" -ForegroundColor Green


# [6/6] 터치패드 응답성 최적화 (노트북용)
Write-Host ""
Write-Host "[6/$totalSteps] 터치패드 응답성 최적화 중 (노트북용)..." -ForegroundColor Yellow

# Precision Touchpad 설정 (Windows 11)
$touchpadPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"
if (Test-Path $touchpadPath) {
    # 터치패드 감도 설정
    Set-ItemProperty -Path $touchpadPath -Name "AAPThreshold" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - PrecisionTouchPad 감도: 최대" -ForegroundColor Green
} else {
    Write-Host "  - PrecisionTouchPad: 감지되지 않음 (건너뜀)" -ForegroundColor Gray
}

# Synaptics 터치패드 (레거시)
$synapticsPath = "HKCU:\Software\Synaptics\SynTP\TouchPadPS2"
if (Test-Path $synapticsPath) {
    Set-ItemProperty -Path $synapticsPath -Name "PalmDetectConfig" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - Synaptics 터치패드: 손바닥 감지 비활성화" -ForegroundColor Green
} else {
    Write-Host "  - Synaptics 터치패드: 감지되지 않음 (건너뜀)" -ForegroundColor Gray
}


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "마우스/입력 장치 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 마우스 가속도 완전 비활성화" -ForegroundColor White
Write-Host "  - 마우스 포인터 1:1 매핑 (선형 곡선)" -ForegroundColor White
Write-Host "  - 키보드 반복 속도 최대화" -ForegroundColor White
Write-Host "  - 입력 데이터 큐 크기 증가" -ForegroundColor White
Write-Host "  - 프레임 서버 모드 비활성화" -ForegroundColor White
Write-Host "  - 터치패드 응답성 최적화 (해당 시)" -ForegroundColor White
Write-Host ""
Write-Host "로그오프 후 다시 로그인하면 모든 설정이 적용됩니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인 (이 스크립트는 재부팅 불필요, 로그오프/로그인으로 충분)
if (-not $global:OrchestrateMode) {
    Write-Host "참고: 이 스크립트는 재부팅이 필요하지 않습니다." -ForegroundColor Gray
    Write-Host "로그오프 후 다시 로그인하면 모든 설정이 적용됩니다." -ForegroundColor Gray
}
