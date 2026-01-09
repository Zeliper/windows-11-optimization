# Windows 11 25H2 공통 최적화 스크립트
# 디스크 정리, DNS 설정, 불필요한 서비스 비활성화, 부팅 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "008.common_optimization.ps1"

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
$logFileName = "Windows11Optimizer_008_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
Windows 11 Optimization Log - Common Optimization
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

Write-Host "=== Windows 11 25H2 공통 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "디스크 정리, DNS 설정, 서비스 최적화, 부팅 최적화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 8


# [1/8] 디스크 정리
Write-Host "[1/$totalSteps] 디스크 정리 중..." -ForegroundColor Yellow

# 사용자 임시 파일 삭제
$userTemp = $env:TEMP
$tempFiles = Get-ChildItem -Path $userTemp -Recurse -Force -ErrorAction SilentlyContinue
$tempCount = ($tempFiles | Measure-Object).Count
if ($tempCount -gt 0) {
    Remove-Item -Path "$userTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - 사용자 임시 파일 : $tempCount 개 삭제 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step "디스크 정리" -Status "적용됨" -Message "사용자 임시 파일 $tempCount 개 삭제"
} else {
    Write-Host "  - 사용자 임시 파일 : 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "디스크 정리" -Status "스킵됨" -Message "사용자 임시 파일 없음"
}

# Windows 임시 파일 삭제
$windowsTemp = "$env:SystemRoot\Temp"
$winTempFiles = Get-ChildItem -Path $windowsTemp -Recurse -Force -ErrorAction SilentlyContinue
$winTempCount = ($winTempFiles | Measure-Object).Count
if ($winTempCount -gt 0) {
    Remove-Item -Path "$windowsTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - Windows 임시 파일 : $winTempCount 개 삭제 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step "디스크 정리" -Status "적용됨" -Message "Windows 임시 파일 $winTempCount 개 삭제"
} else {
    Write-Host "  - Windows 임시 파일 : 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "디스크 정리" -Status "스킵됨" -Message "Windows 임시 파일 없음"
}

# Windows Update 캐시 정리
$wuCachePath = "$env:SystemRoot\SoftwareDistribution\Download"
if (Test-Path $wuCachePath) {
    $wuFiles = Get-ChildItem -Path $wuCachePath -Recurse -Force -ErrorAction SilentlyContinue
    $wuCount = ($wuFiles | Measure-Object).Count
    if ($wuCount -gt 0) {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$wuCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Write-Host "  - Windows Update 캐시 : $wuCount 개 삭제 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step "디스크 정리" -Status "적용됨" -Message "Windows Update 캐시 $wuCount 개 삭제"
    } else {
        Write-Host "  - Windows Update 캐시 : 없음 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step "디스크 정리" -Status "스킵됨" -Message "Windows Update 캐시 없음"
    }
}

# 썸네일 캐시 정리
$thumbCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
$thumbCaches = Get-ChildItem -Path $thumbCachePath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue
$thumbCount = ($thumbCaches | Measure-Object).Count
if ($thumbCount -gt 0) {
    foreach ($cache in $thumbCaches) {
        Remove-Item -Path $cache.FullName -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  - 썸네일 캐시 : $thumbCount 개 삭제 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step "디스크 정리" -Status "적용됨" -Message "썸네일 캐시 $thumbCount 개 삭제"
} else {
    Write-Host "  - 썸네일 캐시 : 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "디스크 정리" -Status "스킵됨" -Message "썸네일 캐시 없음"
}

# 시스템 오류 메모리 덤프 삭제
$dumpPath = "$env:SystemRoot\MEMORY.DMP"
if (Test-Path $dumpPath) {
    Remove-Item -Path $dumpPath -Force -ErrorAction SilentlyContinue
    Write-Host "  - 시스템 메모리 덤프 : 삭제됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step "디스크 정리" -Status "적용됨" -Message "시스템 메모리 덤프 삭제"
} else {
    Write-Host "  - 시스템 메모리 덤프 : 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "디스크 정리" -Status "스킵됨" -Message "시스템 메모리 덤프 없음"
}

# 미니덤프 삭제
$minidumpPath = "$env:SystemRoot\Minidump"
if (Test-Path $minidumpPath) {
    $minidumps = Get-ChildItem -Path $minidumpPath -Force -ErrorAction SilentlyContinue
    $dumpCount = ($minidumps | Measure-Object).Count
    if ($dumpCount -gt 0) {
        Remove-Item -Path "$minidumpPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  - 미니덤프 : $dumpCount 개 삭제 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step "디스크 정리" -Status "적용됨" -Message "미니덤프 $dumpCount 개 삭제"
    } else {
        Write-Host "  - 미니덤프 : 없음 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step "디스크 정리" -Status "스킵됨" -Message "미니덤프 없음"
    }
}

# 휴지통 비우기
$shell = New-Object -ComObject Shell.Application
$recycleBin = $shell.NameSpace(0xa)
$recycleBinItems = $recycleBin.Items()
$recycleCount = ($recycleBinItems | Measure-Object).Count
if ($recycleCount -gt 0) {
    $recycleBinItems | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host "  - 휴지통 : $recycleCount 개 항목 삭제 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step "디스크 정리" -Status "적용됨" -Message "휴지통 $recycleCount 개 항목 삭제"
} else {
    Write-Host "  - 휴지통 : 비어있음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "디스크 정리" -Status "스킵됨" -Message "휴지통 비어있음"
}


# [2/8] DNS 설정
Write-Host ""
Write-Host "[2/$totalSteps] DNS 설정 중..." -ForegroundColor Yellow

# 활성 네트워크 어댑터 가져오기
$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
$dnsStep = "DNS 설정"

foreach ($adapter in $adapters) {
    $adapterName = $adapter.Name
    $ifIndex = $adapter.ifIndex

    # 현재 DNS 확인
    $currentDns = (Get-DnsClientServerAddress -InterfaceIndex $ifIndex -AddressFamily IPv4).ServerAddresses
    $targetDns = @("1.1.1.1", "8.8.8.8")

    if ($currentDns -join "," -eq $targetDns -join ",") {
        Write-Host "  - $adapterName IPv4 DNS : 이미 설정됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $dnsStep -Status "스킵됨" -Message "$adapterName IPv4 DNS 이미 최적"
    } else {
        Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $targetDns -ErrorAction SilentlyContinue
        Write-Host "  - $adapterName IPv4 DNS : 1.1.1.1, 8.8.8.8 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $dnsStep -Status "적용됨" -Message "$adapterName IPv4 DNS 변경됨" -PreviousValue ($currentDns -join ",") -NewValue ($targetDns -join ",")
    }

    # IPv6 DNS 설정
    $currentDnsV6 = (Get-DnsClientServerAddress -InterfaceIndex $ifIndex -AddressFamily IPv6).ServerAddresses
    $targetDnsV6 = @("2606:4700:4700::1111", "2001:4860:4860::8888")

    if ($currentDnsV6 -join "," -eq $targetDnsV6 -join ",") {
        Write-Host "  - $adapterName IPv6 DNS : 이미 설정됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $dnsStep -Status "스킵됨" -Message "$adapterName IPv6 DNS 이미 최적"
    } else {
        Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $targetDnsV6 -ErrorAction SilentlyContinue
        Write-Host "  - $adapterName IPv6 DNS : Cloudflare, Google (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $dnsStep -Status "적용됨" -Message "$adapterName IPv6 DNS 변경됨"
    }
}

# DNS 캐시 플러시
Clear-DnsClientCache
Write-Host "  - DNS 캐시 플러시 완료" -ForegroundColor Green
Write-OptLog -Step $dnsStep -Status "적용됨" -Message "DNS 캐시 플러시"


# [3/8] 불필요한 서비스 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] 불필요한 서비스 비활성화 중..." -ForegroundColor Yellow

$serviceStep = "서비스 비활성화"

# SysMain (SuperFetch) 비활성화 - SSD 환경에서 불필요
Set-ServiceIfDifferent -ServiceName "SysMain" -StartupType "Disabled" -StopService $true -StepName $serviceStep -Description "SysMain (SuperFetch)"

# Connected Devices Platform Service 비활성화
Set-ServiceIfDifferent -ServiceName "CDPSvc" -StartupType "Disabled" -StopService $true -StepName $serviceStep -Description "Connected Devices Platform"

# Downloaded Maps Manager 비활성화
Set-ServiceIfDifferent -ServiceName "MapsBroker" -StartupType "Disabled" -StopService $true -StepName $serviceStep -Description "Downloaded Maps Manager"

# Retail Demo Service 비활성화
Set-ServiceIfDifferent -ServiceName "RetailDemo" -StartupType "Disabled" -StopService $true -StepName $serviceStep -Description "Retail Demo Service"

# Fax 서비스 비활성화
Set-ServiceIfDifferent -ServiceName "Fax" -StartupType "Disabled" -StopService $true -StepName $serviceStep -Description "Fax 서비스"

# Windows Error Reporting Service 비활성화
Set-ServiceIfDifferent -ServiceName "WerSvc" -StartupType "Disabled" -StopService $true -StepName $serviceStep -Description "Windows Error Reporting"


# [4/8] 부팅 최적화
Write-Host ""
Write-Host "[4/$totalSteps] 부팅 최적화 중..." -ForegroundColor Yellow

$bootStep = "부팅 최적화"

# 빠른 시작 활성화 확인 및 설정
$fastStartupPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
Set-RegistryIfDifferent -Path $fastStartupPath -Name "HiberbootEnabled" -Value 1 -StepName $bootStep -Description "빠른 시작"

# 부팅 시간 제한 설정 (3초) - bcdedit 체크
$currentTimeout = (bcdedit /enum | Select-String "timeout" | Out-String).Trim()
if ($currentTimeout -match "3") {
    Write-Host "  - 부팅 메뉴 대기 시간 : 이미 3초 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $bootStep -Status "스킵됨" -Message "부팅 대기 시간 이미 3초"
} else {
    bcdedit /timeout 3 2>$null
    Write-Host "  - 부팅 메뉴 대기 시간 : 3초 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $bootStep -Status "적용됨" -Message "부팅 대기 시간 3초로 변경"
}

# 시작 프로그램 정리 안내
Write-Host "  - 시작 프로그램 정리:" -ForegroundColor Yellow
Write-Host "    작업 관리자 > 시작 프로그램 탭에서 불필요한 항목 비활성화" -ForegroundColor Gray


# [5/8] AppX Deployment Service 최적화 (25H2 신규)
Write-Host ""
Write-Host "[5/$totalSteps] AppX Deployment Service 최적화 중 (25H2)..." -ForegroundColor Yellow

$appxStep = "AppX 서비스"

# AppX Deployment Service 수동 시작으로 변경
Set-ServiceIfDifferent -ServiceName "AppXSvc" -StartupType "Manual" -StepName $appxStep -Description "AppX Deployment Service"

# 관련 예약 작업 비활성화
$appxTasks = @(
    "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup"
)
foreach ($task in $appxTasks) {
    $scheduledTask = Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue
    if ($scheduledTask -and $scheduledTask.State -ne "Disabled") {
        Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  - AppX 예약 작업 : 비활성화됨 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $appxStep -Status "적용됨" -Message "AppX 예약 작업 비활성화"
    } else {
        Write-Host "  - AppX 예약 작업 : 이미 비활성화 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $appxStep -Status "스킵됨" -Message "AppX 예약 작업 이미 비활성화"
    }
}


# [6/8] 메모리 최적화
Write-Host ""
Write-Host "[6/$totalSteps] 메모리 최적화 중..." -ForegroundColor Yellow

$memStep = "메모리 최적화"

# 시스템 메모리 확인
$totalRAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
Write-Host "  - 시스템 RAM: $totalRAM GB" -ForegroundColor White

# 대규모 시스템 캐시 활성화 (서버 워크로드에 적합, RAM 16GB 이상 권장)
$memMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

if ($totalRAM -ge 16) {
    Set-RegistryIfDifferent -Path $memMgmtPath -Name "LargeSystemCache" -Value 1 -StepName $memStep -Description "대규모 시스템 캐시 (RAM 16GB+)"
} else {
    Write-Host "  - 대규모 시스템 캐시 : RAM 16GB 미만 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $memStep -Status "스킵됨" -Message "대규모 시스템 캐시 - RAM 16GB 미만"
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

    Write-Host "  - 시스템 파일 무결성 검사 : 완료 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step "SFC/DISM" -Status "적용됨" -Message "시스템 파일 무결성 검사 완료"
} else {
    Write-Host "  - 시스템 파일 무결성 검사 : 건너뜀 (스킵)" -ForegroundColor Gray
    Write-Host "    나중에 실행하려면: DISM /Online /Cleanup-Image /RestoreHealth && sfc /scannow" -ForegroundColor Gray
    Write-OptLog -Step "SFC/DISM" -Status "스킵됨" -Message "사용자 선택으로 건너뜀"
}


# [8/8] 추가 최적화 및 정리
Write-Host ""
Write-Host "[8/$totalSteps] 추가 최적화 및 정리 중..." -ForegroundColor Yellow

$additionalStep = "추가 최적화"

# Windows 업데이트 전달 최적화 비활성화 (P2P 업데이트)
$doPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"
Set-RegistryIfDifferent -Path $doPath -Name "DODownloadMode" -Value 0 -StepName $additionalStep -Description "P2P 업데이트 비활성화"

# 사전 설치된 앱 자동 설치 비활성화
$contentDeliveryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (Test-Path $contentDeliveryPath) {
    Set-RegistryIfDifferent -Path $contentDeliveryPath -Name "SilentInstalledAppsEnabled" -Value 0 -StepName $additionalStep -Description "자동 앱 설치 비활성화"
    Set-RegistryIfDifferent -Path $contentDeliveryPath -Name "SystemPaneSuggestionsEnabled" -Value 0 -StepName $additionalStep -Description "시스템 제안 비활성화"
    Set-RegistryIfDifferent -Path $contentDeliveryPath -Name "SoftLandingEnabled" -Value 0 -StepName $additionalStep -Description "팁/제안 비활성화"
    Set-RegistryIfDifferent -Path $contentDeliveryPath -Name "SubscribedContent-338388Enabled" -Value 0 -StepName $additionalStep -Description "구독 콘텐츠 338388"
    Set-RegistryIfDifferent -Path $contentDeliveryPath -Name "SubscribedContent-338389Enabled" -Value 0 -StepName $additionalStep -Description "구독 콘텐츠 338389"
}

# 레지스트리 정리 안내
Write-Host "  - 레지스트리 정리 도구 안내:" -ForegroundColor Yellow
Write-Host "    CCleaner, Wise Registry Cleaner 등 사용 권장" -ForegroundColor Gray


# ===== 로그 저장 =====
Save-OptLog


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "공통 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount 개" -ForegroundColor $(if ($global:FailedCount -gt 0) { "Red" } else { "Gray" })
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
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor Cyan
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
