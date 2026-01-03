# Windows 11 25H2 게임 서버 최적화 스크립트
# TCP/UDP 최적화, RSS, QoS, Native NVMe, NUMA 최적화
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

Write-Host "=== Windows 11 25H2 게임 서버 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "TCP/UDP, 네트워크 어댑터, NVMe, NUMA 최적화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 12


# [1/12] TCP/IP 글로벌 최적화
Write-Host "[1/$totalSteps] TCP/IP 글로벌 최적화 중..." -ForegroundColor Yellow

# TCP Auto-Tuning 설정 (normal 권장)
netsh interface tcp set global autotuninglevel=normal 2>$null
Write-Host "  - TCP Auto-Tuning: normal" -ForegroundColor Green

# ECN (Explicit Congestion Notification) 활성화
netsh interface tcp set global ecncapability=enabled 2>$null
Write-Host "  - ECN 활성화" -ForegroundColor Green

# TCP Timestamps 활성화 (RTT 측정 정확도 향상)
netsh interface tcp set global timestamps=enabled 2>$null
Write-Host "  - TCP Timestamps 활성화" -ForegroundColor Green

# Direct Cache Access 활성화
netsh interface tcp set global dca=enabled 2>$null
Write-Host "  - Direct Cache Access 활성화" -ForegroundColor Green

# RSS (Receive Side Scaling) 기본 활성화
netsh interface tcp set global rss=enabled 2>$null
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
        Write-Host "  - DCTCP 알고리즘 설정 완료" -ForegroundColor Green
    }
    "2" {
        Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CUBIC -ErrorAction SilentlyContinue
        Set-NetTCPSetting -SettingName "InternetCustom" -CongestionProvider CUBIC -ErrorAction SilentlyContinue
        Write-Host "  - CUBIC 알고리즘 설정 완료" -ForegroundColor Green
    }
    "3" {
        Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CTCP -ErrorAction SilentlyContinue
        Write-Host "  - CTCP (NewReno) 알고리즘 설정 완료" -ForegroundColor Green
    }
    default {
        Set-NetTCPSetting -SettingName "Datacenter" -CongestionProvider DCTCP -ErrorAction SilentlyContinue
        Write-Host "  - DCTCP 알고리즘 설정 완료 (기본값)" -ForegroundColor Green
    }
}


# [3/12] TCP Window 크기 최적화
Write-Host ""
Write-Host "[3/$totalSteps] TCP Window 크기 최적화 중..." -ForegroundColor Yellow

$tcpParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
if (!(Test-Path $tcpParamsPath)) {
    New-Item -Path $tcpParamsPath -Force | Out-Null
}

# TCP 수신 버퍼 크기 증가 (4MB)
Set-ItemProperty -Path $tcpParamsPath -Name "TcpWindowSize" -Value 4194304 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - TCP Window Size: 4MB" -ForegroundColor Green

# Global Max TCP Window 크기 (16MB)
Set-ItemProperty -Path $tcpParamsPath -Name "GlobalMaxTcpWindowSize" -Value 16777216 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Global Max TCP Window: 16MB" -ForegroundColor Green

# TCP 1323 옵션 활성화 (Window Scaling, Timestamps)
Set-ItemProperty -Path $tcpParamsPath -Name "Tcp1323Opts" -Value 3 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - TCP 1323 옵션 (Window Scaling) 활성화" -ForegroundColor Green


# [4/12] 동시 연결 수 및 TIME_WAIT 최적화
Write-Host ""
Write-Host "[4/$totalSteps] 동시 연결 수 및 TIME_WAIT 최적화 중..." -ForegroundColor Yellow

# MaxUserPort 증가 (기본: 5000, 최대: 65534)
Set-ItemProperty -Path $tcpParamsPath -Name "MaxUserPort" -Value 65534 -Type DWord
Write-Host "  - MaxUserPort: 65534" -ForegroundColor Green

# TcpTimedWaitDelay 단축 (기본: 240초 -> 30초)
Set-ItemProperty -Path $tcpParamsPath -Name "TcpTimedWaitDelay" -Value 30 -Type DWord
Write-Host "  - TcpTimedWaitDelay: 30초" -ForegroundColor Green

# TcpNumConnections 증가
Set-ItemProperty -Path $tcpParamsPath -Name "TcpNumConnections" -Value 16777214 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - TcpNumConnections: 16777214" -ForegroundColor Green

# 동적 포트 범위 확장 (1025-65535)
netsh int ipv4 set dynamicport tcp start=1025 num=64510 2>$null
netsh int ipv4 set dynamicport udp start=1025 num=64510 2>$null
Write-Host "  - 동적 포트 범위: 1025-65535" -ForegroundColor Green


# [5/12] 네트워크 어댑터 감지
Write-Host ""
Write-Host "[5/$totalSteps] 네트워크 어댑터 감지 중..." -ForegroundColor Yellow

$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

if ($adapters.Count -eq 0) {
    Write-Host "  - 경고: 활성화된 물리적 네트워크 어댑터를 찾을 수 없습니다" -ForegroundColor Red
} else {
    Write-Host "  - 감지된 어댑터:" -ForegroundColor Green
    foreach ($adapter in $adapters) {
        $speed = if ($adapter.LinkSpeed) { $adapter.LinkSpeed } else { "Unknown" }
        Write-Host "    * $($adapter.Name) - $($adapter.InterfaceDescription) ($speed)" -ForegroundColor White
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
            Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Interrupt Moderation*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
            Write-Host "  - $adapterName : Interrupt Moderation 비활성화" -ForegroundColor Green
        }

        # ITR (Intel NIC)
        $itrProp = Get-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*ITR*" -ErrorAction SilentlyContinue
        if ($itrProp) {
            Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*ITR*" -DisplayValue "Off" -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "  - $adapterName : 일부 설정 적용 실패 (드라이버 미지원)" -ForegroundColor Yellow
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
    } catch {
        Write-Host "  - $adapterName : RSS 설정 실패" -ForegroundColor Yellow
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
            Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Receive Buffers*" -DisplayValue $maxValue -ErrorAction SilentlyContinue
            Write-Host "  - $adapterName : 수신 버퍼 -> $maxValue" -ForegroundColor Green
        }

        # 송신 버퍼 크기
        $txBuffers = Get-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Transmit Buffers*" -ErrorAction SilentlyContinue
        if ($txBuffers -and $txBuffers.ValidDisplayValues) {
            $maxValue = $txBuffers.ValidDisplayValues | ForEach-Object { [int]$_ } | Sort-Object -Descending | Select-Object -First 1
            Set-NetAdapterAdvancedProperty -Name $adapterName -DisplayName "*Transmit Buffers*" -DisplayValue $maxValue -ErrorAction SilentlyContinue
            Write-Host "  - $adapterName : 송신 버퍼 -> $maxValue" -ForegroundColor Green
        }
    } catch {
        Write-Host "  - $adapterName : 버퍼 설정 실패" -ForegroundColor Yellow
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
Write-Host "  - GameServerUDP QoS 정책 생성 (DSCP 46)" -ForegroundColor Green

# TCP 트래픽 우선순위 (DSCP 34 - AF41)
New-NetQosPolicy -Name "GameServerTCP" -IPProtocol TCP -DSCPAction 34 -NetworkProfile All -ErrorAction SilentlyContinue | Out-Null
Write-Host "  - GameServerTCP QoS 정책 생성 (DSCP 34)" -ForegroundColor Green

# QoS 대역폭 제한 제거
$qosThrottlePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
if (!(Test-Path $qosThrottlePath)) {
    New-Item -Path $qosThrottlePath -Force | Out-Null
}
Set-ItemProperty -Path $qosThrottlePath -Name "NonBestEffortLimit" -Value 0 -Type DWord
Write-Host "  - QoS 대역폭 제한 제거 (100% 사용 가능)" -ForegroundColor Green


# [10/12] 추가 네트워크 최적화
Write-Host ""
Write-Host "[10/$totalSteps] 추가 네트워크 최적화 중..." -ForegroundColor Yellow

foreach ($adapter in $adapters) {
    try {
        # UDP/TCP Checksum Offload 활성화
        Set-NetAdapterChecksumOffload -Name $adapter.Name -UdpIPv4 TxRxEnabled -UdpIPv6 TxRxEnabled -ErrorAction SilentlyContinue
        Set-NetAdapterChecksumOffload -Name $adapter.Name -TcpIPv4 TxRxEnabled -TcpIPv6 TxRxEnabled -ErrorAction SilentlyContinue

        # Large Send Offload 활성화
        Enable-NetAdapterLso -Name $adapter.Name -ErrorAction SilentlyContinue
    } catch {
        # 무시
    }
}
Write-Host "  - 체크섬 오프로드 활성화" -ForegroundColor Green
Write-Host "  - Large Send Offload 활성화" -ForegroundColor Green

# 네트워크 스로틀링 비활성화
$throttlePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-ItemProperty -Path $throttlePath -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF -Type DWord
Set-ItemProperty -Path $throttlePath -Name "SystemResponsiveness" -Value 0 -Type DWord
Write-Host "  - 네트워크 스로틀링 비활성화" -ForegroundColor Green

# Nagle 알고리즘 비활성화 확인
$tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
Get-ChildItem $tcpipPath -ErrorAction SilentlyContinue | ForEach-Object {
    Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $_.PSPath -Name "TcpNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
}
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

$nvmeChoice = "N"
if (-not $global:OrchestrateMode) {
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

            # TRIM 활성화 확인
            fsutil behavior set DisableDeleteNotify 0 2>$null

            Write-Host "  - Native NVMe 설정 적용됨" -ForegroundColor Green
            Write-Host "  - 재부팅 후 적용됩니다" -ForegroundColor Yellow
        } catch {
            Write-Host "  - Native NVMe 설정 실패: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "  - Windows 11 25H2 이상에서만 지원됩니다" -ForegroundColor Red
        Write-Host "  - 현재 빌드: $buildNumber (필요: 26100+)" -ForegroundColor Yellow
    }
} else {
    if ($global:OrchestrateMode) {
        Write-Host "  - Native NVMe 활성화 건너뜀 (Orchestrate 모드: 실험적 기능 기본 비활성화)" -ForegroundColor Yellow
    } else {
        Write-Host "  - Native NVMe 활성화 건너뜀 (사용자 선택)" -ForegroundColor Yellow
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


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "게임 서버 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
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
