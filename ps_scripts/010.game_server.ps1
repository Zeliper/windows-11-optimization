# Windows 11 25H2 게임 서버 최적화 스크립트
# TCP/UDP 최적화, RSS, QoS, Native NVMe, NUMA 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.2"
$scriptName = "010.game_server"

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

# =============================================
# 로깅 시스템
# =============================================
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir "${scriptName}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$global:LogEntries = @()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Step,
        [string]$Status,  # Applied, Skipped, Failed, Info
        [string]$Message,
        [string]$PreviousValue = "",
        [string]$NewValue = ""
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = [PSCustomObject]@{
        Timestamp = $timestamp
        Step = $Step
        Status = $Status
        Message = $Message
        PreviousValue = $PreviousValue
        NewValue = $NewValue
    }
    $global:LogEntries += $logEntry

    switch ($Status) {
        "Applied" { $global:AppliedCount++ }
        "Skipped" { $global:SkippedCount++ }
        "Failed" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    $logContent = @()
    $logContent += "=" * 60
    $logContent += "Windows 11 게임 서버 최적화 로그"
    $logContent += "스크립트: $scriptName v$scriptVersion"
    $logContent += "실행 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $logContent += "=" * 60
    $logContent += ""
    $logContent += "## 요약"
    $logContent += "- 적용됨: $global:AppliedCount"
    $logContent += "- 건너뜀 (이미 설정됨): $global:SkippedCount"
    $logContent += "- 실패: $global:FailedCount"
    $logContent += ""
    $logContent += "## 상세 로그"
    $logContent += "-" * 60

    foreach ($entry in $global:LogEntries) {
        $logContent += "[$($entry.Timestamp)] [$($entry.Status)] $($entry.Step)"
        $logContent += "  $($entry.Message)"
        if ($entry.PreviousValue -or $entry.NewValue) {
            $logContent += "  이전: $($entry.PreviousValue) -> 이후: $($entry.NewValue)"
        }
        $logContent += ""
    }

    $logContent | Out-File -FilePath $global:LogFilePath -Encoding UTF8
}

# =============================================
# 헬퍼 함수
# =============================================
function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$Step,
        [string]$Description
    )

    try {
        # 경로가 없으면 생성
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-OptLog -Step $Step -Status "Applied" -Message "$Description (경로 생성됨)" -NewValue $Value
        }

        $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue

        if ($null -eq $currentValue -or $currentValue.$Name -ne $Value) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
            $prevVal = if ($null -eq $currentValue) { "(없음)" } else { $currentValue.$Name }
            Write-OptLog -Step $Step -Status "Applied" -Message $Description -PreviousValue $prevVal -NewValue $Value
            return $true
        } else {
            Write-OptLog -Step $Step -Status "Skipped" -Message "$Description (이미 설정됨)" -PreviousValue $currentValue.$Name -NewValue $Value
            return $false
        }
    } catch {
        Write-OptLog -Step $Step -Status "Failed" -Message "$Description - 오류: $_"
        return $false
    }
}

Write-Host "=== Windows 11 25H2 게임 서버 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "TCP/UDP, 네트워크 어댑터, NVMe, NUMA 최적화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 12


# [1/12] TCP/IP 글로벌 최적화
Write-Host "[1/$totalSteps] TCP/IP 글로벌 최적화 중..." -ForegroundColor Yellow

# TCP Auto-Tuning 설정 (normal 권장)
$result = netsh interface tcp set global autotuninglevel=normal 2>&1
if ($result -notmatch "오류|error") {
    Write-OptLog -Step "1/12" -Status "Applied" -Message "TCP Auto-Tuning: normal"
} else {
    Write-OptLog -Step "1/12" -Status "Failed" -Message "TCP Auto-Tuning 설정 실패"
}
Write-Host "  - TCP Auto-Tuning: normal" -ForegroundColor Green

# ECN (Explicit Congestion Notification) 활성화
netsh interface tcp set global ecncapability=enabled 2>$null
Write-OptLog -Step "1/12" -Status "Applied" -Message "ECN 활성화"
Write-Host "  - ECN 활성화" -ForegroundColor Green

# TCP Timestamps 활성화 (RTT 측정 정확도 향상)
netsh interface tcp set global timestamps=enabled 2>$null
Write-OptLog -Step "1/12" -Status "Applied" -Message "TCP Timestamps 활성화"
Write-Host "  - TCP Timestamps 활성화" -ForegroundColor Green

# Direct Cache Access 활성화
netsh interface tcp set global dca=enabled 2>$null
Write-OptLog -Step "1/12" -Status "Applied" -Message "Direct Cache Access 활성화"
Write-Host "  - Direct Cache Access 활성화" -ForegroundColor Green

# RSS (Receive Side Scaling) 기본 활성화
netsh interface tcp set global rss=enabled 2>$null
Write-OptLog -Step "1/12" -Status "Applied" -Message "RSS 글로벌 활성화"
Write-Host "  - RSS 글로벌 활성화" -ForegroundColor Green


# [2/12] Congestion Control 알고리즘 설정
Write-Host ""
Write-Host "[2/$totalSteps] Congestion Control 알고리즘 설정 중..." -ForegroundColor Yellow

Write-Host ""
Write-Host "  Congestion Control 알고리즘 선택:" -ForegroundColor Cyan
Write-Host "  [1] DCTCP - 데이터센터/로컬 네트워크용 (권장)" -ForegroundColor White
Write-Host "  [2] CUBIC - 일반 인터넷 환경용" -ForegroundColor White
Write-Host "  [3] NewReno (CTCP) - 레거시 호환성" -ForegroundColor White
Write-Host ""

$ccChoice = "1"
if (-not $global:OrchestrateMode) {
    $ccChoice = Read-Host "선택 (1-3, 기본값: 1)"
    if ([string]::IsNullOrEmpty($ccChoice)) { $ccChoice = "1" }
}

switch ($ccChoice) {
    "1" {
        Set-NetTCPSetting -SettingName "Datacenter" -CongestionProvider DCTCP -ErrorAction SilentlyContinue
        Set-NetTCPSetting -SettingName "DatacenterCustom" -CongestionProvider DCTCP -ErrorAction SilentlyContinue
        Write-OptLog -Step "2/12" -Status "Applied" -Message "DCTCP 알고리즘 설정"
        Write-Host "  - DCTCP 알고리즘 설정 완료" -ForegroundColor Green
    }
    "2" {
        Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CUBIC -ErrorAction SilentlyContinue
        Set-NetTCPSetting -SettingName "InternetCustom" -CongestionProvider CUBIC -ErrorAction SilentlyContinue
        Write-OptLog -Step "2/12" -Status "Applied" -Message "CUBIC 알고리즘 설정"
        Write-Host "  - CUBIC 알고리즘 설정 완료" -ForegroundColor Green
    }
    "3" {
        Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CTCP -ErrorAction SilentlyContinue
        Write-OptLog -Step "2/12" -Status "Applied" -Message "CTCP (NewReno) 알고리즘 설정"
        Write-Host "  - CTCP (NewReno) 알고리즘 설정 완료" -ForegroundColor Green
    }
    default {
        Set-NetTCPSetting -SettingName "Datacenter" -CongestionProvider DCTCP -ErrorAction SilentlyContinue
        Write-OptLog -Step "2/12" -Status "Applied" -Message "DCTCP 알고리즘 설정 (기본값)"
        Write-Host "  - DCTCP 알고리즘 설정 완료 (기본값)" -ForegroundColor Green
    }
}


# [3/12] TCP Window 크기 최적화
Write-Host ""
Write-Host "[3/$totalSteps] TCP Window 크기 최적화 중..." -ForegroundColor Yellow

$tcpParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"

# TCP 수신 버퍼 크기 증가 (4MB)
Set-RegistryIfDifferent -Path $tcpParamsPath -Name "TcpWindowSize" -Value 4194304 -Step "3/12" -Description "TCP Window Size: 4MB"
Write-Host "  - TCP Window Size: 4MB" -ForegroundColor Green

# Global Max TCP Window 크기 (16MB)
Set-RegistryIfDifferent -Path $tcpParamsPath -Name "GlobalMaxTcpWindowSize" -Value 16777216 -Step "3/12" -Description "Global Max TCP Window: 16MB"
Write-Host "  - Global Max TCP Window: 16MB" -ForegroundColor Green

# TCP 1323 옵션 활성화 (Window Scaling, Timestamps)
Set-RegistryIfDifferent -Path $tcpParamsPath -Name "Tcp1323Opts" -Value 3 -Step "3/12" -Description "TCP 1323 옵션 (Window Scaling) 활성화"
Write-Host "  - TCP 1323 옵션 (Window Scaling) 활성화" -ForegroundColor Green


# [4/12] 동시 연결 수 및 TIME_WAIT 최적화
Write-Host ""
Write-Host "[4/$totalSteps] 동시 연결 수 및 TIME_WAIT 최적화 중..." -ForegroundColor Yellow

# MaxUserPort 증가 (기본: 5000, 최대: 65534)
Set-RegistryIfDifferent -Path $tcpParamsPath -Name "MaxUserPort" -Value 65534 -Step "4/12" -Description "MaxUserPort: 65534"
Write-Host "  - MaxUserPort: 65534" -ForegroundColor Green

# TcpTimedWaitDelay 단축 (기본: 240초 -> 30초)
Set-RegistryIfDifferent -Path $tcpParamsPath -Name "TcpTimedWaitDelay" -Value 30 -Step "4/12" -Description "TcpTimedWaitDelay: 30초"
Write-Host "  - TcpTimedWaitDelay: 30초" -ForegroundColor Green

# TcpNumConnections 증가
Set-RegistryIfDifferent -Path $tcpParamsPath -Name "TcpNumConnections" -Value 16777214 -Step "4/12" -Description "TcpNumConnections: 16777214"
Write-Host "  - TcpNumConnections: 16777214" -ForegroundColor Green

# 동적 포트 범위 확장 (1025-65535)
netsh int ipv4 set dynamicport tcp start=1025 num=64510 2>$null
netsh int ipv4 set dynamicport udp start=1025 num=64510 2>$null
Write-OptLog -Step "4/12" -Status "Applied" -Message "동적 포트 범위: 1025-65535"
Write-Host "  - 동적 포트 범위: 1025-65535" -ForegroundColor Green


# [5/12] 네트워크 어댑터 감지
Write-Host ""
Write-Host "[5/$totalSteps] 네트워크 어댑터 감지 중..." -ForegroundColor Yellow

$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

if ($adapters.Count -eq 0) {
    Write-Host "  - 경고: 활성화된 물리적 네트워크 어댑터를 찾을 수 없습니다" -ForegroundColor Red
    Write-OptLog -Step "5/12" -Status "Info" -Message "활성화된 물리적 네트워크 어댑터 없음"
} else {
    Write-Host "  - 감지된 어댑터:" -ForegroundColor Green
    foreach ($adapter in $adapters) {
        $speed = if ($adapter.LinkSpeed) { $adapter.LinkSpeed } else { "Unknown" }
        Write-Host "    * $($adapter.Name) - $($adapter.InterfaceDescription) ($speed)" -ForegroundColor White
        Write-OptLog -Step "5/12" -Status "Info" -Message "어댑터 감지: $($adapter.Name) - $($adapter.InterfaceDescription) ($speed)"
    }
}


# [6/12] Interrupt Moderation 비활성화 (낮은 레이턴시)
Write-Host ""
Write-Host "[6/$totalSteps] Interrupt Moderation 비활성화 중 (낮은 레이턴시)..." -ForegroundColor Yellow

foreach ($adapter in $adapters) {
    $adapterName = $adapter.Name

    try {
        # Interrupt Moderation 비활성화
        $intModProp = Get-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Interrupt Moderation*" -ErrorAction SilentlyContinue
        if ($intModProp) {
            $currentVal = $intModProp.DisplayValue
            if ($currentVal -ne "Disabled") {
                Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Interrupt Moderation*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
                Write-OptLog -Step "6/12" -Status "Applied" -Message "$adapterName : Interrupt Moderation 비활성화" -PreviousValue $currentVal -NewValue "Disabled"
            } else {
                Write-OptLog -Step "6/12" -Status "Skipped" -Message "$adapterName : Interrupt Moderation (이미 Disabled)"
            }
            Write-Host "  - $adapterName : Interrupt Moderation 비활성화" -ForegroundColor Green
        }

        # ITR (Intel NIC)
        $itrProp = Get-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*ITR*" -ErrorAction SilentlyContinue
        if ($itrProp) {
            Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*ITR*" -DisplayValue "Off" -ErrorAction SilentlyContinue
            Write-OptLog -Step "6/12" -Status "Applied" -Message "$adapterName : ITR Off"
        }
    } catch {
        Write-Host "  - $adapterName : 일부 설정 적용 실패 (드라이버 미지원)" -ForegroundColor Yellow
        Write-OptLog -Step "6/12" -Status "Failed" -Message "$adapterName : Interrupt Moderation 설정 실패 - $_"
    }
}


# [7/12] RSS (Receive Side Scaling) 활성화
Write-Host ""
Write-Host "[7/$totalSteps] RSS (Receive Side Scaling) 활성화 중..." -ForegroundColor Yellow

$cpuCount = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors
$rssQueues = [Math]::Min($cpuCount, 16)

foreach ($adapter in $adapters) {
    $adapterName = $adapter.Name

    try {
        Enable-NetAdapterRss -Name $adapterName -ErrorAction SilentlyContinue
        Set-NetAdapterRss -Name $adapterName -NumberOfReceiveQueues $rssQueues -ErrorAction SilentlyContinue
        Write-Host "  - $adapterName : RSS 활성화 (큐: $rssQueues)" -ForegroundColor Green
        Write-OptLog -Step "7/12" -Status "Applied" -Message "$adapterName : RSS 활성화 (큐: $rssQueues)"
    } catch {
        Write-Host "  - $adapterName : RSS 설정 실패" -ForegroundColor Yellow
        Write-OptLog -Step "7/12" -Status "Failed" -Message "$adapterName : RSS 설정 실패 - $_"
    }
}


# [8/12] 네트워크 버퍼 크기 최적화
Write-Host ""
Write-Host "[8/$totalSteps] 네트워크 버퍼 크기 최적화 중..." -ForegroundColor Yellow

foreach ($adapter in $adapters) {
    $adapterName = $adapter.Name

    try {
        # 수신 버퍼 크기
        $rxBuffers = Get-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Receive Buffers*" -ErrorAction SilentlyContinue
        if ($rxBuffers -and $rxBuffers.ValidDisplayValues) {
            $maxValue = $rxBuffers.ValidDisplayValues | ForEach-Object { [int]$_ } | Sort-Object -Descending | Select-Object -First 1
            $currentVal = $rxBuffers.DisplayValue
            if ($currentVal -ne $maxValue.ToString()) {
                Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Receive Buffers*" -DisplayValue $maxValue -ErrorAction SilentlyContinue
                Write-OptLog -Step "8/12" -Status "Applied" -Message "$adapterName : 수신 버퍼" -PreviousValue $currentVal -NewValue $maxValue
            } else {
                Write-OptLog -Step "8/12" -Status "Skipped" -Message "$adapterName : 수신 버퍼 (이미 최대값)"
            }
            Write-Host "  - $adapterName : 수신 버퍼 -> $maxValue" -ForegroundColor Green
        }

        # 송신 버퍼 크기
        $txBuffers = Get-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Transmit Buffers*" -ErrorAction SilentlyContinue
        if ($txBuffers -and $txBuffers.ValidDisplayValues) {
            $maxValue = $txBuffers.ValidDisplayValues | ForEach-Object { [int]$_ } | Sort-Object -Descending | Select-Object -First 1
            $currentVal = $txBuffers.DisplayValue
            if ($currentVal -ne $maxValue.ToString()) {
                Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Transmit Buffers*" -DisplayValue $maxValue -ErrorAction SilentlyContinue
                Write-OptLog -Step "8/12" -Status "Applied" -Message "$adapterName : 송신 버퍼" -PreviousValue $currentVal -NewValue $maxValue
            } else {
                Write-OptLog -Step "8/12" -Status "Skipped" -Message "$adapterName : 송신 버퍼 (이미 최대값)"
            }
            Write-Host "  - $adapterName : 송신 버퍼 -> $maxValue" -ForegroundColor Green
        }
    } catch {
        Write-Host "  - $adapterName : 버퍼 설정 실패" -ForegroundColor Yellow
        Write-OptLog -Step "8/12" -Status "Failed" -Message "$adapterName : 버퍼 설정 실패 - $_"
    }
}


# [9/12] QoS 정책 설정
Write-Host ""
Write-Host "[9/$totalSteps] QoS (Quality of Service) 정책 설정 중..." -ForegroundColor Yellow

# 기존 정책 제거
Remove-NetQosPolicy -Name "GameServerUDP" -ErrorAction SilentlyContinue -Confirm:$false
Remove-NetQosPolicy -Name "GameServerTCP" -ErrorAction SilentlyContinue -Confirm:$false

# UDP 트래픽 우선순위 (DSCP 46 - Expedited Forwarding)
New-NetQosPolicy -Name "GameServerUDP" -IPProtocol UDP -DSCPAction 46 -NetworkProfile All -ErrorAction SilentlyContinue | Out-Null
Write-OptLog -Step "9/12" -Status "Applied" -Message "GameServerUDP QoS 정책 생성 (DSCP 46)"
Write-Host "  - GameServerUDP QoS 정책 생성 (DSCP 46)" -ForegroundColor Green

# TCP 트래픽 우선순위 (DSCP 34 - AF41)
New-NetQosPolicy -Name "GameServerTCP" -IPProtocol TCP -DSCPAction 34 -NetworkProfile All -ErrorAction SilentlyContinue | Out-Null
Write-OptLog -Step "9/12" -Status "Applied" -Message "GameServerTCP QoS 정책 생성 (DSCP 34)"
Write-Host "  - GameServerTCP QoS 정책 생성 (DSCP 34)" -ForegroundColor Green

# QoS 대역폭 제한 제거
$qosThrottlePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
Set-RegistryIfDifferent -Path $qosThrottlePath -Name "NonBestEffortLimit" -Value 0 -Step "9/12" -Description "QoS 대역폭 제한 제거 (100% 사용 가능)"
Write-Host "  - QoS 대역폭 제한 제거 (100% 사용 가능)" -ForegroundColor Green


# [10/12] 추가 네트워크 최적화
Write-Host ""
Write-Host "[10/$totalSteps] 추가 네트워크 최적화 중..." -ForegroundColor Yellow

foreach ($adapter in $adapters) {
    try {
        # UDP/TCP Checksum Offload 활성화 (RxTxEnabled가 올바른 열거자)
        Set-NetAdapterChecksumOffload -Name $adapter.Name -UdpIPv4 RxTxEnabled -UdpIPv6 RxTxEnabled -ErrorAction SilentlyContinue
        Set-NetAdapterChecksumOffload -Name $adapter.Name -TcpIPv4 RxTxEnabled -TcpIPv6 RxTxEnabled -ErrorAction SilentlyContinue
        Write-OptLog -Step "10/12" -Status "Applied" -Message "$($adapter.Name) : 체크섬 오프로드 활성화"

        # Large Send Offload 활성화
        Enable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue
        Write-OptLog -Step "10/12" -Status "Applied" -Message "$($adapter.Name) : Large Send Offload 활성화"
    } catch {
        Write-OptLog -Step "10/12" -Status "Failed" -Message "$($adapter.Name) : 오프로드 설정 실패 - $_"
    }
}
Write-Host "  - 체크섬 오프로드 활성화" -ForegroundColor Green
Write-Host "  - Large Send Offload 활성화" -ForegroundColor Green

# 네트워크 스로틀링 비활성화
$throttlePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-RegistryIfDifferent -Path $throttlePath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Step "10/12" -Description "NetworkThrottlingIndex 비활성화"
Set-RegistryIfDifferent -Path $throttlePath -Name "SystemResponsiveness" -Value 0 -Step "10/12" -Description "SystemResponsiveness: 0 (게임 서버 최적화)"
Write-Host "  - 네트워크 스로틀링 비활성화" -ForegroundColor Green

# Nagle 알고리즘 비활성화 확인
$tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
$interfaceCount = 0
Get-ChildItem $tcpipPath -ErrorAction SilentlyContinue | ForEach-Object {
    Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $_.PSPath -Name "TcpNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    $interfaceCount++
}
Write-OptLog -Step "10/12" -Status "Applied" -Message "Nagle 알고리즘 비활성화 ($interfaceCount 인터페이스)"
Write-Host "  - Nagle 알고리즘 비활성화" -ForegroundColor Green


# [11/12] Native NVMe 지원 활성화 (실험적)
Write-Host ""
Write-Host "[11/$totalSteps] Native NVMe 지원 확인 (Windows 11 25H2 실험적 기능)..." -ForegroundColor Yellow

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Red
Write-Host "  경고: Native NVMe 지원은 실험적 기능입니다!" -ForegroundColor Red
Write-Host "  ================================================" -ForegroundColor Red
Write-Host ""
Write-Host "  장점: 최대 80% IOPS 향상, I/O 레이턴시 감소" -ForegroundColor Green
Write-Host "  위험: 일부 NVMe 드라이브에서 호환성 문제 가능" -ForegroundColor Red
Write-Host ""

# OrchestrateMode 확인: 글로벌 옵션에서 EnableNativeNVMe 확인
$nvmeChoice = "N"
if ($global:OrchestrateMode) {
    # Orchestrate 모드: 시작 시 선택한 실험적 기능 옵션 확인
    if ($global:ExperimentalOptions -and $global:ExperimentalOptions.EnableNativeNVMe -eq $true) {
        $nvmeChoice = "Y"
        Write-Host "  - Orchestrate 모드: 실험적 기능 활성화 선택됨" -ForegroundColor Cyan
    }
} else {
    # 단독 실행: 사용자에게 직접 물어봄
    $nvmeChoice = Read-Host "Native NVMe 지원을 활성화하시겠습니까? (Y/N, 기본값: N)"
}

if ($nvmeChoice -eq "Y" -or $nvmeChoice -eq "y") {
    $buildNumber = [System.Environment]::OSVersion.Version.Build

    if ($buildNumber -ge 26100) {
        try {
            $stornvmePath = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
            if (!(Test-Path $stornvmePath)) {
                New-Item -Path $stornvmePath -Force | Out-Null
            }

            Set-ItemProperty -Path $stornvmePath -Name "ForcedPhysicalSectorSizeInBytes" -Value 4096 -Type DWord
            Write-OptLog -Step "11/12" -Status "Applied" -Message "Native NVMe 설정 적용됨 (ForcedPhysicalSectorSizeInBytes: 4096)"

            # TRIM 활성화 확인
            fsutil behavior set DisableDeleteNotify 0 2>$null
            Write-OptLog -Step "11/12" -Status "Applied" -Message "TRIM 활성화 확인"

            Write-Host "  - Native NVMe 설정 적용됨" -ForegroundColor Green
            Write-Host "  - 재부팅 후 적용됩니다" -ForegroundColor Yellow
        } catch {
            Write-Host "  - Native NVMe 설정 실패: $_" -ForegroundColor Red
            Write-OptLog -Step "11/12" -Status "Failed" -Message "Native NVMe 설정 실패: $_"
        }
    } else {
        Write-Host "  - Windows 11 25H2 이상에서만 지원됩니다" -ForegroundColor Red
        Write-Host "  - 현재 빌드: $buildNumber (필요: 26100+)" -ForegroundColor Yellow
        Write-OptLog -Step "11/12" -Status "Skipped" -Message "Windows 11 25H2 이상 필요 (현재: $buildNumber)"
    }
} else {
    if ($global:OrchestrateMode) {
        Write-Host "  - Native NVMe 활성화 건너뜀 (Orchestrate 모드: 실험적 기능 미선택)" -ForegroundColor Yellow
        Write-OptLog -Step "11/12" -Status "Skipped" -Message "Native NVMe 건너뜀 (Orchestrate 모드: 실험적 기능 미선택)"
    } else {
        Write-Host "  - Native NVMe 활성화 건너뜀 (사용자 선택)" -ForegroundColor Yellow
        Write-OptLog -Step "11/12" -Status "Skipped" -Message "Native NVMe 건너뜀 (사용자 선택)"
    }
}


# [12/12] 설정 요약 및 상태 확인
Write-Host ""
Write-Host "[12/$totalSteps] 설정 요약..." -ForegroundColor Yellow

Write-Host ""
Write-Host "  === 현재 TCP 설정 ===" -ForegroundColor Cyan
netsh interface tcp show global 2>$null | Select-String -Pattern "수신|자동|ECN|타임스탬프|Receive|Auto|Timestamps" | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

Write-Host ""
Write-Host "  === 동적 포트 범위 ===" -ForegroundColor Cyan
$portRange = netsh int ipv4 show dynamicport tcp 2>$null
$portRange | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

Write-Host ""
Write-Host "  === QoS 정책 ===" -ForegroundColor Cyan
Get-NetQosPolicy -ErrorAction SilentlyContinue | Format-Table Name, IPProtocol, DSCPAction -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor White }

# 로그 저장
Save-OptLog

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "게임 서버 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 요약 정보 출력
Write-Host "## 변경 요약" -ForegroundColor Cyan
Write-Host "  - 적용됨: $global:AppliedCount" -ForegroundColor Green
Write-Host "  - 건너뜀 (이미 설정됨): $global:SkippedCount" -ForegroundColor Yellow
Write-Host "  - 실패: $global:FailedCount" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor White
Write-Host ""

Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - TCP/IP 글로벌 최적화 (Auto-Tuning, ECN, Timestamps)" -ForegroundColor White
Write-Host "  - Congestion Control 알고리즘 설정" -ForegroundColor White
Write-Host "  - TCP Window 크기 증가 (4MB/16MB)" -ForegroundColor White
Write-Host "  - MaxUserPort 65534, TcpTimedWaitDelay 30초" -ForegroundColor White
Write-Host "  - 동적 포트 범위: 1025-65535" -ForegroundColor White
Write-Host "  - Interrupt Moderation 비활성화" -ForegroundColor White
Write-Host "  - RSS (Receive Side Scaling) 활성화" -ForegroundColor White
Write-Host "  - 네트워크 버퍼 크기 최적화" -ForegroundColor White
Write-Host "  - QoS 정책 (UDP DSCP 46, TCP DSCP 34)" -ForegroundColor White
Write-Host "  - 체크섬/LSO 오프로드, 네트워크 스로틀링 비활성화" -ForegroundColor White
if ($nvmeChoice -eq "Y" -or $nvmeChoice -eq "y") {
    Write-Host "  - Native NVMe 지원 활성화 (실험적)" -ForegroundColor White
}
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
