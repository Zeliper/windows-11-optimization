# Windows 11 고급 게임 최적화 스크립트
# Power Throttling, 시스템 타이머, 오디오 지연, Edge 백그라운드 차단, 네트워크 어댑터 최적화
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

Write-Host "=== Windows 11 고급 게임 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "Power Throttling, 시스템 타이머, 오디오, Edge 백그라운드 차단 등을 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 8


# [1/8] Power Throttling 비활성화
Write-Host "[1/$totalSteps] Power Throttling 비활성화 중..." -ForegroundColor Yellow

# Power Throttling: Windows 10 Fall Creators Update부터 도입
# 백그라운드 앱의 CPU 성능을 제한하여 전력 소비 감소
# 게임 PC에서는 비활성화 권장
$powerThrottlingPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"

if (!(Test-Path $powerThrottlingPath)) {
    New-Item -Path $powerThrottlingPath -Force | Out-Null
}

# PowerThrottlingOff = 1 (비활성화)
Set-ItemProperty -Path $powerThrottlingPath -Name "PowerThrottlingOff" -Value 1 -Type DWord
Write-Host "  - PowerThrottlingOff: 1 (Power Throttling 비활성화)" -ForegroundColor Green

# EnergyEstimationEnabled 비활성화 (에너지 추정 기능)
$powerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
Set-ItemProperty -Path $powerPath -Name "EnergyEstimationEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - EnergyEstimationEnabled: 0 (에너지 추정 비활성화)" -ForegroundColor Green


# [2/8] 시스템 타이머 최적화 (High Resolution Timer)
Write-Host ""
Write-Host "[2/$totalSteps] 시스템 타이머 최적화 중..." -ForegroundColor Yellow

# useplatformtick: 플랫폼 클록 소스 사용 (고해상도 타이머)
# disabledynamictick: 동적 틱 비활성화 (일정한 타이머 인터럽트)
# 게임에서 일관된 프레임 타이밍에 도움

try {
    # useplatformtick 설정
    $result1 = bcdedit /set useplatformtick yes 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  - useplatformtick: yes (플랫폼 클록 사용)" -ForegroundColor Green
    } else {
        Write-Host "  - useplatformtick 설정 실패: $result1" -ForegroundColor Red
    }

    # disabledynamictick 설정
    $result2 = bcdedit /set disabledynamictick yes 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  - disabledynamictick: yes (동적 틱 비활성화)" -ForegroundColor Green
    } else {
        Write-Host "  - disabledynamictick 설정 실패: $result2" -ForegroundColor Red
    }
} catch {
    Write-Host "  - bcdedit 명령 실행 실패: $_" -ForegroundColor Red
}

# 추가 타이머 설정
$multimediaPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
if (!(Test-Path $multimediaPath)) {
    New-Item -Path $multimediaPath -Force | Out-Null
}

# SystemResponsiveness = 0 (게임/미디어 최우선)
# 기본값: 20 (20%를 백그라운드 작업에 할당)
Set-ItemProperty -Path $multimediaPath -Name "SystemResponsiveness" -Value 0 -Type DWord
Write-Host "  - SystemResponsiveness: 0 (100% 포그라운드 우선)" -ForegroundColor Green


# [3/8] 오디오 지연 최소화
Write-Host ""
Write-Host "[3/$totalSteps] 오디오 지연 최소화 중..." -ForegroundColor Yellow

# DisableProtectedAudioDG: DRM 오디오 보호 비활성화 (지연 감소)
$audioPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio"
if (!(Test-Path $audioPath)) {
    New-Item -Path $audioPath -Force | Out-Null
}

Set-ItemProperty -Path $audioPath -Name "DisableProtectedAudioDG" -Value 1 -Type DWord
Write-Host "  - DisableProtectedAudioDG: 1 (오디오 보호 비활성화, 지연 감소)" -ForegroundColor Green

# 오디오 서비스 우선순위 향상
$audioServicePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
if (!(Test-Path $audioServicePath)) {
    New-Item -Path $audioServicePath -Force | Out-Null
}

Set-ItemProperty -Path $audioServicePath -Name "Priority" -Value 1 -Type DWord
Set-ItemProperty -Path $audioServicePath -Name "Scheduling Category" -Value "High" -Type String
Set-ItemProperty -Path $audioServicePath -Name "SFIO Priority" -Value "High" -Type String
Write-Host "  - 오디오 작업 우선순위: High" -ForegroundColor Green


# [4/8] 네트워크 어댑터 고급 최적화
Write-Host ""
Write-Host "[4/$totalSteps] 네트워크 어댑터 고급 최적화 중..." -ForegroundColor Yellow

# 활성 네트워크 어댑터 가져오기
$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

if ($adapters.Count -gt 0) {
    foreach ($adapter in $adapters) {
        Write-Host "  - 어댑터: $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor White

        # Interrupt Moderation 비활성화 (낮은 지연)
        try {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 0 -ErrorAction SilentlyContinue
            Write-Host "    - Interrupt Moderation: 비활성화" -ForegroundColor Green
        } catch {
            Write-Host "    - Interrupt Moderation: 설정 불가 (어댑터 미지원)" -ForegroundColor Gray
        }

        # Flow Control 비활성화
        try {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*FlowControl" -RegistryValue 0 -ErrorAction SilentlyContinue
            Write-Host "    - Flow Control: 비활성화" -ForegroundColor Green
        } catch {
            Write-Host "    - Flow Control: 설정 불가 (어댑터 미지원)" -ForegroundColor Gray
        }

        # Energy Efficient Ethernet 비활성화 (있는 경우)
        try {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*EEE" -RegistryValue 0 -ErrorAction SilentlyContinue
            Write-Host "    - Energy Efficient Ethernet: 비활성화" -ForegroundColor Green
        } catch {
            # 무시 (많은 어댑터에서 지원하지 않음)
        }
    }
} else {
    Write-Host "  - 활성 물리적 네트워크 어댑터를 찾을 수 없습니다." -ForegroundColor Gray
}


# [5/8] Edge 백그라운드 실행 완전 차단
Write-Host ""
Write-Host "[5/$totalSteps] Edge 백그라운드 실행 완전 차단 중..." -ForegroundColor Yellow

# Edge 정책 레지스트리 경로
$edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (!(Test-Path $edgePolicyPath)) {
    New-Item -Path $edgePolicyPath -Force | Out-Null
}

# BackgroundModeEnabled = 0 (백그라운드 실행 비활성화)
Set-ItemProperty -Path $edgePolicyPath -Name "BackgroundModeEnabled" -Value 0 -Type DWord
Write-Host "  - BackgroundModeEnabled: 0 (백그라운드 실행 비활성화)" -ForegroundColor Green

# StartupBoostEnabled = 0 (시작 부스트 비활성화)
Set-ItemProperty -Path $edgePolicyPath -Name "StartupBoostEnabled" -Value 0 -Type DWord
Write-Host "  - StartupBoostEnabled: 0 (시작 부스트 비활성화)" -ForegroundColor Green

# AllowPrelaunch = 0 (사전 로드 비활성화)
Set-ItemProperty -Path $edgePolicyPath -Name "AllowPrelaunch" -Value 0 -Type DWord
Write-Host "  - AllowPrelaunch: 0 (사전 로드 비활성화)" -ForegroundColor Green

# ComponentUpdatesEnabled = 0 (구성 요소 업데이트 비활성화)
Set-ItemProperty -Path $edgePolicyPath -Name "ComponentUpdatesEnabled" -Value 0 -Type DWord
Write-Host "  - ComponentUpdatesEnabled: 0 (구성 요소 업데이트 비활성화)" -ForegroundColor Green

# Edge 업데이트 정책
$edgeUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"
if (!(Test-Path $edgeUpdatePath)) {
    New-Item -Path $edgeUpdatePath -Force | Out-Null
}

# UpdateDefault = 0 (자동 업데이트 비활성화)
Set-ItemProperty -Path $edgeUpdatePath -Name "UpdateDefault" -Value 0 -Type DWord
Write-Host "  - Edge Update: 비활성화" -ForegroundColor Green

# Edge 시작 프로그램에서 제거
$runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$edgeAutoLaunch = Get-ItemProperty -Path $runPath -ErrorAction SilentlyContinue |
                  Get-Member -MemberType NoteProperty |
                  Where-Object { $_.Name -match "MicrosoftEdgeAutoLaunch" }

if ($edgeAutoLaunch) {
    foreach ($entry in $edgeAutoLaunch) {
        Remove-ItemProperty -Path $runPath -Name $entry.Name -ErrorAction SilentlyContinue
        Write-Host "  - 시작 프로그램에서 제거: $($entry.Name)" -ForegroundColor Green
    }
} else {
    Write-Host "  - Edge 자동 시작 항목: 없음" -ForegroundColor Gray
}

# msedge.exe 프로세스 종료 (현재 실행 중인 경우)
$edgeProcesses = Get-Process -Name "msedge" -ErrorAction SilentlyContinue
if ($edgeProcesses) {
    Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
    Write-Host "  - msedge.exe 프로세스 종료됨" -ForegroundColor Green
}


# [6/8] Print Spooler 비활성화 (선택)
Write-Host ""
Write-Host "[6/$totalSteps] Print Spooler 설정 중..." -ForegroundColor Yellow

$disableSpooler = "N"
if (-not $global:OrchestrateMode) {
    Write-Host ""
    Write-Host "  프린터를 사용하지 않는 경우 Print Spooler 서비스를 비활성화할 수 있습니다." -ForegroundColor Cyan
    Write-Host "  (PrintNightmare 보안 취약점 방지 및 리소스 절약)" -ForegroundColor Gray
    $disableSpooler = Read-Host "Print Spooler 비활성화 (Y/N, 기본값: N)"
}

if ($disableSpooler -eq "Y" -or $disableSpooler -eq "y") {
    Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "Spooler" -StartupType Disabled
    Write-Host "  - Print Spooler: 비활성화됨" -ForegroundColor Green
} else {
    Write-Host "  - Print Spooler: 기본값 유지" -ForegroundColor Gray
}


# [7/8] 25H2 Start Menu 최적화
Write-Host ""
Write-Host "[7/$totalSteps] 25H2 Start Menu 최적화 중..." -ForegroundColor Yellow

$explorerAdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Start_IrisRecommendations = 0 (추천 항목 비활성화)
Set-ItemProperty -Path $explorerAdvancedPath -Name "Start_IrisRecommendations" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Start_IrisRecommendations: 0 (추천 항목 비활성화)" -ForegroundColor Green

# Start_AccountNotifications = 0 (계정 알림 비활성화)
Set-ItemProperty -Path $explorerAdvancedPath -Name "Start_AccountNotifications" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Start_AccountNotifications: 0 (계정 알림 비활성화)" -ForegroundColor Green


# [8/8] Chrome 성능 최적화 (선택)
Write-Host ""
Write-Host "[8/$totalSteps] Chrome 성능 최적화 중..." -ForegroundColor Yellow

# Chrome 정책 경로
$chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
if (!(Test-Path $chromePolicyPath)) {
    New-Item -Path $chromePolicyPath -Force | Out-Null
}

# BackgroundModeEnabled = 0 (Chrome 백그라운드 실행 비활성화)
Set-ItemProperty -Path $chromePolicyPath -Name "BackgroundModeEnabled" -Value 0 -Type DWord
Write-Host "  - Chrome BackgroundModeEnabled: 0 (백그라운드 실행 비활성화)" -ForegroundColor Green

# HardwareAccelerationModeEnabled = 1 (하드웨어 가속 활성화)
Set-ItemProperty -Path $chromePolicyPath -Name "HardwareAccelerationModeEnabled" -Value 1 -Type DWord
Write-Host "  - Chrome HardwareAccelerationModeEnabled: 1 (GPU 가속 활성화)" -ForegroundColor Green

# HighEfficiencyModeEnabled = 1 (메모리 절약 모드 활성화)
Set-ItemProperty -Path $chromePolicyPath -Name "HighEfficiencyModeEnabled" -Value 1 -Type DWord
Write-Host "  - Chrome HighEfficiencyModeEnabled: 1 (메모리 절약 모드)" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "고급 게임 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - Power Throttling: 비활성화 (CPU 성능 제한 해제)" -ForegroundColor White
Write-Host "  - 시스템 타이머: 최적화 (일관된 프레임 타이밍)" -ForegroundColor White
Write-Host "  - 오디오 지연: 최소화 (DRM 보호 비활성화)" -ForegroundColor White
Write-Host "  - 네트워크 어댑터: 고급 최적화 (Interrupt Moderation Off)" -ForegroundColor White
Write-Host "  - Edge 백그라운드: 완전 차단 (리소스 절약)" -ForegroundColor White
Write-Host "  - Start Menu: 25H2 최적화 (추천 항목 비활성화)" -ForegroundColor White
Write-Host "  - Chrome: 성능 최적화 (GPU 가속, 메모리 절약)" -ForegroundColor White
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
