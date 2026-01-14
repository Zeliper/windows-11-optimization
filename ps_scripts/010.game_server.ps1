# Windows 11 Game Server Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "010.game_server.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "TCP/IP 글로벌 최적화 (Auto-Tuning, ECN)"
        Action = {
            netsh interface tcp set global autotuninglevel=normal 2>$null
            netsh interface tcp set global ecncapability=enabled 2>$null
            netsh interface tcp set global timestamps=enabled 2>$null
            netsh interface tcp set global dca=enabled 2>$null
            netsh interface tcp set global rss=enabled 2>$null
            Write-Host "  - TCP 글로벌 설정 적용됨" -ForegroundColor Green
            Write-OptLog -Step "TCP Global" -Status "적용됨" -Message "Auto-Tuning, ECN, Timestamps, DCA, RSS 설정"
        }
    },
    @{
        Name = "Congestion Control 알고리즘 설정 (DCTCP)"
        Action = {
            # Default to DCTCP as recommended
            $algo = "DCTCP"
            if (-not $global:OrchestrateMode) {
                 Write-Host "Congestion Control: [1] DCTCP (권장), [2] CUBIC, [3] NewReno"
                 $c = Read-Host "선택 (기본값 1)"
                 if ($c -eq "2") { $algo = "CUBIC" }
                 elseif ($c -eq "3") { $algo = "CTCP" }
            }
            
            if ($algo -eq "DCTCP") {
                Set-NetTCPSetting -SettingName "Datacenter" -CongestionProvider DCTCP -ErrorAction SilentlyContinue
                Set-NetTCPSetting -SettingName "DatacenterCustom" -CongestionProvider DCTCP -ErrorAction SilentlyContinue
            } elseif ($algo -eq "CUBIC") {
                Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CUBIC -ErrorAction SilentlyContinue
                Set-NetTCPSetting -SettingName "InternetCustom" -CongestionProvider CUBIC -ErrorAction SilentlyContinue
            } else {
                Set-NetTCPSetting -SettingName "Internet" -CongestionProvider CTCP -ErrorAction SilentlyContinue
            }
            Write-Host "  - 알고리즘: $algo" -ForegroundColor Green
            Write-OptLog -Step "Congestion Control" -Status "적용됨" -Message "알고리즘: $algo"
        }
    },
    @{
        Name = "TCP Window 및 연결 최적화"
        Action = {
            $tcp = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            Set-Registry -Path $tcp -Name "TcpWindowSize" -Value 4194304
            Set-Registry -Path $tcp -Name "GlobalMaxTcpWindowSize" -Value 16777216
            Set-Registry -Path $tcp -Name "Tcp1323Opts" -Value 3 -Description "Window Scaling"
            
            Set-Registry -Path $tcp -Name "MaxUserPort" -Value 65534
            Set-Registry -Path $tcp -Name "TcpTimedWaitDelay" -Value 30
            Set-Registry -Path $tcp -Name "TcpNumConnections" -Value 16777214
            
            netsh int ipv4 set dynamicport tcp start=1025 num=64510 2>$null
            netsh int ipv4 set dynamicport udp start=1025 num=64510 2>$null
        }
    },
    @{
        Name = "네트워크 어댑터 최적화 (Interrupt, RSS, Buffers)"
        Action = {
            $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
            $cpuCount = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
            $queues = [Math]::Min($cpuCount, 16)
            
            foreach ($nic in $adapters) {
                # Interrupt Moderation Disable
                Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName "*Interrupt Moderation*" -DisplayValue "Disabled" -ErrorAction SilentlyContinue
                
                # RSS
                Enable-NetAdapterRss -Name $nic.Name -ErrorAction SilentlyContinue
                Set-NetAdapterRss -Name $nic.Name -NumberOfReceiveQueues $queues -ErrorAction SilentlyContinue
                
                # Buffers (Max)
                foreach ($buf in @("*Receive Buffers*", "*Transmit Buffers*")) {
                    $prop = Get-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $buf -ErrorAction SilentlyContinue
                    if ($prop -and $prop.ValidDisplayValues) {
                        $max = $prop.ValidDisplayValues | ForEach-Object {[int]$_} | Sort-Object -Descending | Select-Object -First 1
                         Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $buf -DisplayValue $max -ErrorAction SilentlyContinue
                    }
                }
                
                # Offloads
                Set-NetAdapterChecksumOffload -Name $nic.Name -UdpIPv4 RxTxEnabled -UdpIPv6 RxTxEnabled -ErrorAction SilentlyContinue
                Set-NetAdapterChecksumOffload -Name $nic.Name -TcpIPv4 RxTxEnabled -TcpIPv6 RxTxEnabled -ErrorAction SilentlyContinue
                Enable-NetAdapterLso -Name $nic.Name -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = "QoS 정책 및 스로틀링 해제"
        Action = {
            Remove-NetQosPolicy -Name "GameServerUDP" -ErrorAction SilentlyContinue -Confirm:$false
            Remove-NetQosPolicy -Name "GameServerTCP" -ErrorAction SilentlyContinue -Confirm:$false
            
            New-NetQosPolicy -Name "GameServerUDP" -IPProtocol UDP -DSCPAction 46 -NetworkProfile All -ErrorAction SilentlyContinue | Out-Null
            New-NetQosPolicy -Name "GameServerTCP" -IPProtocol TCP -DSCPAction 34 -NetworkProfile All -ErrorAction SilentlyContinue | Out-Null
            
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" -Name "NonBestEffortLimit" -Value 0
            
            $sys = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            Set-Registry -Path $sys -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF
            Set-Registry -Path $sys -Name "SystemResponsiveness" -Value 0
            
            # Nagle
            Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
                Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty -Path $_.PSPath -Name "TcpNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
            }
        }
    },
    @{
        Name = "Native NVMe 지원 (실험적, 25H2+)"
        Action = {
            $enableNVMe = $false
            if ($global:OrchestrateMode) {
                 if ($global:ExperimentalOptions -and $global:ExperimentalOptions.EnableNativeNVMe) { $enableNVMe = $true }
            } else {
                 $yn = Read-Host "Native NVMe 지원을 활성화하시겠습니까? (Y/N)"
                 if ($yn -match "y") { $enableNVMe = $true }
            }
            
            if ($enableNVMe) {
                 if ([System.Environment]::OSVersion.Version.Build -ge 26100) {
                     $path = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
                     Set-Registry -Path $path -Name "ForcedPhysicalSectorSizeInBytes" -Value 4096
                     fsutil behavior set DisableDeleteNotify 0 2>$null
                 } else {
                     Write-Host "  - Windows 빌드 26100+ 필요 (스킵)" -ForegroundColor Red
                 }
            } else {
                Write-Host "  - 사용자 선택으로 스킵" -ForegroundColor Gray
            }
        }
    }
)

Run-OptimizationSteps -Title "게임 서버 네트워크 최적화" -Steps $steps


