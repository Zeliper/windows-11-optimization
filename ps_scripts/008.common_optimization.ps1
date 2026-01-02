# Windows 11 25H2 공통 최적화 스크립트
# 디스크 정리, DNS 설정, 불필요한 서비스 비활성화, 부팅 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Orchestrate 모드 확인
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

Write-Host "=== Windows 11 25H2 공통 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "디스크 정리, DNS 설정, 서비스 최적화, 부팅 최적화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 8


# [1/8] 디스크 정리
Write-Host "[1/$totalSteps] 디스크 정리 중..." -ForegroundColor Yellow

# 사용자 임시 파일 삭제
$userTemp = $env:TEMP
$tempFiles = Get-ChildItem -Path $userTemp -Recurse -Force -ErrorAction SilentlyContinue
$tempCount = ($tempFiles | Measure-Object).Count
Remove-Item -Path "$userTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  - 사용자 임시 파일 삭제 ($tempCount 개)" -ForegroundColor Green

# Windows 임시 파일 삭제
$windowsTemp = "$env:SystemRoot\Temp"
$winTempFiles = Get-ChildItem -Path $windowsTemp -Recurse -Force -ErrorAction SilentlyContinue
$winTempCount = ($winTempFiles | Measure-Object).Count
Remove-Item -Path "$windowsTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  - Windows 임시 파일 삭제 ($winTempCount 개)" -ForegroundColor Green

# Windows Update 캐시 정리
$wuCachePath = "$env:SystemRoot\SoftwareDistribution\Download"
if (Test-Path $wuCachePath) {
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    $wuFiles = Get-ChildItem -Path $wuCachePath -Recurse -Force -ErrorAction SilentlyContinue
    $wuCount = ($wuFiles | Measure-Object).Count
    Remove-Item -Path "$wuCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    Write-Host "  - Windows Update 캐시 삭제 ($wuCount 개)" -ForegroundColor Green
}

# 썸네일 캐시 정리
$thumbCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
$thumbCaches = Get-ChildItem -Path $thumbCachePath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue
$thumbCount = ($thumbCaches | Measure-Object).Count
foreach ($cache in $thumbCaches) {
    Remove-Item -Path $cache.FullName -Force -ErrorAction SilentlyContinue
}
Write-Host "  - 썸네일 캐시 삭제 ($thumbCount 개)" -ForegroundColor Green

# 시스템 오류 메모리 덤프 삭제
$dumpPath = "$env:SystemRoot\MEMORY.DMP"
if (Test-Path $dumpPath) {
    Remove-Item -Path $dumpPath -Force -ErrorAction SilentlyContinue
    Write-Host "  - 시스템 메모리 덤프 삭제" -ForegroundColor Green
}

# 미니덤프 삭제
$minidumpPath = "$env:SystemRoot\Minidump"
if (Test-Path $minidumpPath) {
    $minidumps = Get-ChildItem -Path $minidumpPath -Force -ErrorAction SilentlyContinue
    $dumpCount = ($minidumps | Measure-Object).Count
    Remove-Item -Path "$minidumpPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - 미니덤프 삭제 ($dumpCount 개)" -ForegroundColor Green
}

# 휴지통 비우기
$shell = New-Object -ComObject Shell.Application
$recycleBin = $shell.NameSpace(0xa)
$recycleBin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host "  - 휴지통 비우기 완료" -ForegroundColor Green


# [2/8] DNS 설정
Write-Host ""
Write-Host "[2/$totalSteps] DNS 설정 중..." -ForegroundColor Yellow

# 활성 네트워크 어댑터 가져오기
$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

foreach ($adapter in $adapters) {
    $adapterName = $adapter.Name
    $ifIndex = $adapter.ifIndex

    # IPv4 DNS 설정 (Cloudflare 1.1.1.1, Google 8.8.8.8)
    Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses ("1.1.1.1", "8.8.8.8") -ErrorAction SilentlyContinue
    Write-Host "  - $adapterName IPv4 DNS: 1.1.1.1, 8.8.8.8" -ForegroundColor Green

    # IPv6 DNS 설정
    Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses ("2606:4700:4700::1111", "2001:4860:4860::8888") -ErrorAction SilentlyContinue
    Write-Host "  - $adapterName IPv6 DNS: Cloudflare, Google" -ForegroundColor Green
}

# DNS 캐시 플러시
Clear-DnsClientCache
Write-Host "  - DNS 캐시 플러시 완료" -ForegroundColor Green


# [3/8] 불필요한 서비스 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] 불필요한 서비스 비활성화 중..." -ForegroundColor Yellow

# SysMain (SuperFetch) 비활성화 - SSD 환경에서 불필요
$sysMainService = Get-Service -Name "SysMain" -ErrorAction SilentlyContinue
if ($sysMainService) {
    Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
    Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "  - SysMain (SuperFetch) 비활성화" -ForegroundColor Green
}

# Connected Devices Platform Service 비활성화
Stop-Service -Name "CDPSvc" -Force -ErrorAction SilentlyContinue
Set-Service -Name "CDPSvc" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - Connected Devices Platform Service 비활성화" -ForegroundColor Green

# Downloaded Maps Manager 비활성화
Stop-Service -Name "MapsBroker" -Force -ErrorAction SilentlyContinue
Set-Service -Name "MapsBroker" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - Downloaded Maps Manager 비활성화" -ForegroundColor Green

# Retail Demo Service 비활성화
Stop-Service -Name "RetailDemo" -Force -ErrorAction SilentlyContinue
Set-Service -Name "RetailDemo" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - Retail Demo Service 비활성화" -ForegroundColor Green

# Fax 서비스 비활성화
Stop-Service -Name "Fax" -Force -ErrorAction SilentlyContinue
Set-Service -Name "Fax" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - Fax 서비스 비활성화" -ForegroundColor Green

# Windows Error Reporting Service 비활성화
Stop-Service -Name "WerSvc" -Force -ErrorAction SilentlyContinue
Set-Service -Name "WerSvc" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - Windows Error Reporting Service 비활성화" -ForegroundColor Green


# [4/8] 부팅 최적화
Write-Host ""
Write-Host "[4/$totalSteps] 부팅 최적화 중..." -ForegroundColor Yellow

# 빠른 시작 활성화 확인 및 설정
$fastStartupPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
if (!(Test-Path $fastStartupPath)) {
    New-Item -Path $fastStartupPath -Force | Out-Null
}
Set-ItemProperty -Path $fastStartupPath -Name "HiberbootEnabled" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 빠른 시작 활성화됨" -ForegroundColor Green

# 부팅 시간 제한 설정 (3초)
bcdedit /timeout 3 2>$null
Write-Host "  - 부팅 메뉴 대기 시간: 3초" -ForegroundColor Green

# 부팅 로고 비활성화 (선택적)
# bcdedit /set {current} quietboot yes 2>$null
# Write-Host "  - 부팅 로고 비활성화" -ForegroundColor Green

# 시작 프로그램 정리 안내
Write-Host "  - 시작 프로그램 정리:" -ForegroundColor Yellow
Write-Host "    작업 관리자 > 시작 프로그램 탭에서 불필요한 항목 비활성화" -ForegroundColor Gray


# [5/8] AppX Deployment Service 최적화 (25H2 신규)
Write-Host ""
Write-Host "[5/$totalSteps] AppX Deployment Service 최적화 중 (25H2)..." -ForegroundColor Yellow

# AppX Deployment Service 수동 시작으로 변경
$appxService = Get-Service -Name "AppXSvc" -ErrorAction SilentlyContinue
if ($appxService) {
    Set-Service -Name "AppXSvc" -StartupType Manual -ErrorAction SilentlyContinue
    Write-Host "  - AppX Deployment Service 수동 시작으로 변경" -ForegroundColor Green
    Write-Host "    참고: Microsoft Store 앱 설치 시 자동으로 시작됩니다" -ForegroundColor Gray
}

# 관련 예약 작업 비활성화
$appxTasks = @(
    "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup"
)
foreach ($task in $appxTasks) {
    Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "  - AppX 예약 작업 비활성화" -ForegroundColor Green


# [6/8] 메모리 최적화
Write-Host ""
Write-Host "[6/$totalSteps] 메모리 최적화 중..." -ForegroundColor Yellow

# 시스템 메모리 확인
$totalRAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
Write-Host "  - 시스템 RAM: $totalRAM GB" -ForegroundColor White

# 대규모 시스템 캐시 활성화 (서버 워크로드에 적합, RAM 16GB 이상 권장)
if ($totalRAM -ge 16) {
    $memMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $memMgmtPath -Name "LargeSystemCache" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - 대규모 시스템 캐시 활성화 (RAM 16GB 이상)" -ForegroundColor Green
} else {
    Write-Host "  - 대규모 시스템 캐시: RAM 16GB 미만으로 건너뜀" -ForegroundColor Yellow
}

# 가상 메모리 설정 안내
Write-Host "  - 가상 메모리 설정 안내:" -ForegroundColor Yellow
Write-Host "    시스템 속성 > 고급 > 성능 설정 > 고급 > 가상 메모리" -ForegroundColor Gray
Write-Host "    권장: 시스템 관리 크기 또는 RAM의 1.5~2배" -ForegroundColor Gray


# [7/8] 시스템 파일 무결성 검사 (선택)
Write-Host ""
Write-Host "[7/$totalSteps] 시스템 파일 무결성 검사..." -ForegroundColor Yellow

$runSFC = "N"
if (-not $global:OrchestrateMode) {
    $runSFC = Read-Host "시스템 파일 무결성 검사를 실행하시겠습니까? (Y/N, 기본값: N)"
}

if ($runSFC -eq "Y" -or $runSFC -eq "y") {
    Write-Host "  - DISM 이미지 복구 중... (시간이 걸릴 수 있습니다)" -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /RestoreHealth

    Write-Host "  - SFC 시스템 파일 검사 중..." -ForegroundColor Yellow
    sfc /scannow

    Write-Host "  - 시스템 파일 무결성 검사 완료" -ForegroundColor Green
} else {
    Write-Host "  - 시스템 파일 무결성 검사 건너뜀" -ForegroundColor Yellow
    Write-Host "    나중에 실행하려면: DISM /Online /Cleanup-Image /RestoreHealth && sfc /scannow" -ForegroundColor Gray
}


# [8/8] 추가 최적화 및 정리
Write-Host ""
Write-Host "[8/$totalSteps] 추가 최적화 및 정리 중..." -ForegroundColor Yellow

# Windows 업데이트 전달 최적화 비활성화 (P2P 업데이트)
$doPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
if (!(Test-Path $doPath)) {
    New-Item -Path $doPath -Force | Out-Null
}
Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Windows 업데이트 전달 최적화 (P2P) 비활성화" -ForegroundColor Green

# 사전 설치된 앱 자동 설치 비활성화
$contentDeliveryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (Test-Path $contentDeliveryPath) {
    Set-ItemProperty -Path $contentDeliveryPath -Name "SilentInstalledAppsEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $contentDeliveryPath -Name "SystemPaneSuggestionsEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $contentDeliveryPath -Name "SoftLandingEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $contentDeliveryPath -Name "SubscribedContent-338388Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $contentDeliveryPath -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
Write-Host "  - 사전 설치된 앱 자동 설치 비활성화" -ForegroundColor Green

# 레지스트리 정리 안내
Write-Host "  - 레지스트리 정리 도구 안내:" -ForegroundColor Yellow
Write-Host "    CCleaner, Wise Registry Cleaner 등 사용 권장" -ForegroundColor Gray


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "공통 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 임시 파일, 캐시, 덤프 파일 정리" -ForegroundColor White
Write-Host "  - DNS 설정 (Cloudflare 1.1.1.1, Google 8.8.8.8)" -ForegroundColor White
Write-Host "  - 불필요한 서비스 비활성화 (SysMain, MapsBroker 등)" -ForegroundColor White
Write-Host "  - 부팅 최적화 (빠른 시작, 부팅 대기 시간 3초)" -ForegroundColor White
Write-Host "  - AppX Deployment Service 수동 시작 (25H2)" -ForegroundColor White
Write-Host "  - 메모리 최적화 (대규모 시스템 캐시)" -ForegroundColor White
Write-Host "  - P2P 업데이트 및 자동 앱 설치 비활성화" -ForegroundColor White
Write-Host ""
Write-Host "일부 설정은 재부팅 후 적용됩니다." -ForegroundColor Yellow
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
