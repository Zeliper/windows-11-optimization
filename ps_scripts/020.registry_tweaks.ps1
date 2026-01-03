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

Write-Host "=== Windows 11 레지스트리 미세 조정 스크립트 ===" -ForegroundColor Cyan
Write-Host "메뉴 지연 제거, 앱 응답 시간 최적화, 네트워크 성능 향상 등을 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 7


# [1/7] 메뉴 지연 제거 (MenuShowDelay)
Write-Host "[1/$totalSteps] 메뉴 지연 제거 중..." -ForegroundColor Yellow

$desktopPath = "HKCU:\Control Panel\Desktop"

# MenuShowDelay = 0 (기본값: 400ms)
# 메뉴, 서브메뉴, 툴팁 등 표시 지연 시간
Set-ItemProperty -Path $desktopPath -Name "MenuShowDelay" -Value "0" -Type String
Write-Host "  - MenuShowDelay: 0ms (즉시 표시)" -ForegroundColor Green


# [2/7] 앱 응답 대기 시간 최적화
Write-Host ""
Write-Host "[2/$totalSteps] 앱 응답 대기 시간 최적화 중..." -ForegroundColor Yellow

# HungAppTimeout = 2000 (기본값: 5000ms)
# 응답 없는 앱 대기 시간 (밀리초)
Set-ItemProperty -Path $desktopPath -Name "HungAppTimeout" -Value "2000" -Type String
Write-Host "  - HungAppTimeout: 2000ms (응답 대기 2초)" -ForegroundColor Green

# WaitToKillAppTimeout = 3000 (기본값: 20000ms)
# 앱 강제 종료 전 대기 시간
Set-ItemProperty -Path $desktopPath -Name "WaitToKillAppTimeout" -Value "3000" -Type String
Write-Host "  - WaitToKillAppTimeout: 3000ms (앱 종료 대기 3초)" -ForegroundColor Green

# WaitToKillServiceTimeout = 3000 (기본값: 20000ms)
# 서비스 강제 종료 전 대기 시간
$controlPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
Set-ItemProperty -Path $controlPath -Name "WaitToKillServiceTimeout" -Value "3000" -Type String
Write-Host "  - WaitToKillServiceTimeout: 3000ms (서비스 종료 대기 3초)" -ForegroundColor Green


# [3/7] 자동 앱 종료 활성화 (AutoEndTasks)
Write-Host ""
Write-Host "[3/$totalSteps] 자동 앱 종료 활성화 중..." -ForegroundColor Yellow

# AutoEndTasks = 1 (기본값: 0)
# 로그오프/종료 시 응답 없는 앱 자동 종료
Set-ItemProperty -Path $desktopPath -Name "AutoEndTasks" -Value "1" -Type String
Write-Host "  - AutoEndTasks: 활성화 (종료 시 앱 자동 종료)" -ForegroundColor Green


# [4/7] 네트워크 공유 성능 향상 (IRPStackSize)
Write-Host ""
Write-Host "[4/$totalSteps] 네트워크 공유 성능 향상 중..." -ForegroundColor Yellow

$lanmanPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
if (!(Test-Path $lanmanPath)) {
    New-Item -Path $lanmanPath -Force | Out-Null
}

# IRPStackSize 기본값: 15
# 네트워크 공유, 파일 서버 환경: 20-50 권장
# 너무 높으면 메모리 사용량 증가
Set-ItemProperty -Path $lanmanPath -Name "IRPStackSize" -Value 20 -Type DWord
Write-Host "  - IRPStackSize: 20 (네트워크 공유 성능 향상)" -ForegroundColor Green

# Size 파라미터 (서버 최적화)
# 1 = 최소, 2 = 중간, 3 = 최대 메모리/처리량
Set-ItemProperty -Path $lanmanPath -Name "Size" -Value 3 -Type DWord
Write-Host "  - LanmanServer Size: 3 (최대 처리량)" -ForegroundColor Green


# [5/7] 긴 경로 지원 활성화 (LongPathsEnabled)
Write-Host ""
Write-Host "[5/$totalSteps] 긴 경로 지원 활성화 중..." -ForegroundColor Yellow

$fileSystemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

# LongPathsEnabled = 1
# 260자 경로 제한 해제 (최대 32,767자)
# 개발자, Node.js, npm 등에서 유용
Set-ItemProperty -Path $fileSystemPath -Name "LongPathsEnabled" -Value 1 -Type DWord
Write-Host "  - LongPathsEnabled: 활성화 (260자 경로 제한 해제)" -ForegroundColor Green


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
    if (!(Test-Path $explorerPoliciesPath)) {
        New-Item -Path $explorerPoliciesPath -Force | Out-Null
    }

    # NoLowDiskSpaceChecks = 1
    Set-ItemProperty -Path $explorerPoliciesPath -Name "NoLowDiskSpaceChecks" -Value 1 -Type DWord
    Write-Host "  - 디스크 공간 부족 경고: 비활성화" -ForegroundColor Green
} else {
    Write-Host "  - 디스크 공간 부족 경고: 기본값 유지" -ForegroundColor Gray
}


# [7/7] 추가 레지스트리 미세 조정
Write-Host ""
Write-Host "[7/$totalSteps] 추가 레지스트리 미세 조정 중..." -ForegroundColor Yellow

# ForegroundLockTimeout (포커스 전환 대기 시간)
# 0 = 즉시 포커스 전환 허용
Set-ItemProperty -Path $desktopPath -Name "ForegroundLockTimeout" -Value 0 -Type DWord
Write-Host "  - ForegroundLockTimeout: 0 (포커스 즉시 전환)" -ForegroundColor Green

# LowLevelHooksTimeout (저수준 훅 대기 시간)
# 기본값: 5000ms, 최적화: 1000ms
Set-ItemProperty -Path $desktopPath -Name "LowLevelHooksTimeout" -Value 1000 -Type DWord
Write-Host "  - LowLevelHooksTimeout: 1000ms" -ForegroundColor Green

# 마우스 호버 시간 단축
Set-ItemProperty -Path $desktopPath -Name "MouseHoverTime" -Value "10" -Type String
Write-Host "  - MouseHoverTime: 10ms (마우스 호버 반응 단축)" -ForegroundColor Green

# Win32PrioritySeparation (포그라운드 앱 우선순위)
# 값: 38 (0x26) = 짧은 가변 퀀텀, 포그라운드 우선 (게임/데스크탑 권장)
# 값: 24 (0x18) = 긴 고정 퀀텀 (서버 권장)
$prioritySepPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
Set-ItemProperty -Path $prioritySepPath -Name "Win32PrioritySeparation" -Value 38 -Type DWord
Write-Host "  - Win32PrioritySeparation: 38 (포그라운드 앱 우선순위)" -ForegroundColor Green

# SvcHostSplitThresholdInKB (서비스 호스트 분리 임계값)
# RAM 용량에 따라 서비스 호스트 프로세스 분리
# 기본값은 시스템에서 자동 계산
$totalRAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1KB, 0)
$svcHostPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
Set-ItemProperty -Path $svcHostPath -Name "SvcHostSplitThresholdInKB" -Value $totalRAM -Type DWord
Write-Host "  - SvcHostSplitThresholdInKB: $([math]::Round($totalRAM / 1MB, 0)) GB (서비스 분리 최적화)" -ForegroundColor Green

# 파일 삭제 확인 대화상자 비활성화 (휴지통으로 이동 시)
$shellPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (!(Test-Path $shellPath)) {
    New-Item -Path $shellPath -Force | Out-Null
}
Set-ItemProperty -Path $shellPath -Name "ConfirmFileDelete" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 파일 삭제 확인 대화상자: 비활성화" -ForegroundColor Green

# 네트워크 어댑터 대기 시간 최적화
$tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
Set-ItemProperty -Path $tcpipPath -Name "DefaultTTL" -Value 64 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - DefaultTTL: 64 (네트워크 홉 최적화)" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "레지스트리 미세 조정이 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - MenuShowDelay: 0ms (메뉴 즉시 표시)" -ForegroundColor White
Write-Host "  - HungAppTimeout: 2000ms (응답 대기 단축)" -ForegroundColor White
Write-Host "  - WaitToKillAppTimeout: 3000ms (앱 종료 대기 단축)" -ForegroundColor White
Write-Host "  - WaitToKillServiceTimeout: 3000ms (서비스 종료 대기 단축)" -ForegroundColor White
Write-Host "  - AutoEndTasks: 활성화 (종료 시 자동 종료)" -ForegroundColor White
Write-Host "  - IRPStackSize: 20 (네트워크 공유 성능)" -ForegroundColor White
Write-Host "  - LongPathsEnabled: 활성화 (260자 제한 해제)" -ForegroundColor White
Write-Host "  - Win32PrioritySeparation: 38 (포그라운드 우선)" -ForegroundColor White
Write-Host "  - SvcHostSplitThresholdInKB: RAM 기준 최적화" -ForegroundColor White
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
