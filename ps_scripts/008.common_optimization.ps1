# Windows 11 Common Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "008.common_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "디스크 정리 (임시 파일, 캐시)"
        Action = {
            # User Temp
            $userTemp = $env:TEMP
            $files = Get-ChildItem $userTemp -Recurse -Force -ErrorAction SilentlyContinue
            if ($files) { 
                Remove-Item "$userTemp\*" -Recurse -Force -ErrorAction SilentlyContinue 
                Write-Host "  - 사용자 임시 파일 삭제됨" -ForegroundColor Green
            }

            # Windows Temp
            $winTemp = "$env:SystemRoot\Temp"
            $files = Get-ChildItem $winTemp -Recurse -Force -ErrorAction SilentlyContinue
            if ($files) {
                Remove-Item "$winTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  - Windows 임시 파일 삭제됨" -ForegroundColor Green
            }

            # WU Cache
            $wuPath = "$env:SystemRoot\SoftwareDistribution\Download"
            if (Test-Path $wuPath) {
                # Ensure the specific subdirectory exists to avoid error
                $wuInst = "$wuPath\Install"
                if (Test-Path $wuInst) { 
                    # ... 
                }
                
                Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
                if (Test-Path "$wuPath") {
                   Get-ChildItem "$wuPath" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
                Start-Service wuauserv -ErrorAction SilentlyContinue
                Write-Host "  - Windows Update 캐시 삭제됨" -ForegroundColor Green
            }

            # Thumbnail Cache
            $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
            if (Test-Path $thumbPath) {
                Get-ChildItem $thumbPath -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            }
            
            # Dumps
            Remove-Item "$env:SystemRoot\MEMORY.DMP" -Force -ErrorAction SilentlyContinue
            if (Test-Path "$env:SystemRoot\Minidump") { Remove-Item "$env:SystemRoot\Minidump\*" -Recurse -Force -ErrorAction SilentlyContinue }

            # Recycle Bin
            $shell = New-Object -ComObject Shell.Application
            $bin = $shell.NameSpace(0xa)
            if ($bin -and $bin.Items().Count -gt 0) {
                 $bin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
                 Write-Host "  - 휴지통 비우기 완료" -ForegroundColor Green
            }
            
            Write-OptLog -Step "Disk Cleanup" -Status "적용됨" -Message "임시 파일 및 캐시 정리 완료"
        }
    },
    @{
        Name = "DNS 설정 (Cloudflare/Google)"
        Action = {
            $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
            foreach ($nic in $adapters) {
                # IPv4
                $curv4 = (Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4).ServerAddresses
                $targetv4 = @("1.1.1.1", "8.8.8.8")
                if (($curv4 -join ',') -ne ($targetv4 -join ',')) {
                    Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $targetv4 -ErrorAction SilentlyContinue
                    Write-Host "  - $($nic.Name) IPv4 DNS 설정됨" -ForegroundColor Green
                }

                # IPv6
                $curv6 = (Get-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv6).ServerAddresses
                $targetv6 = @("2606:4700:4700::1111", "2001:4860:4860::8888")
                if (($curv6 -join ',') -ne ($targetv6 -join ',')) {
                    try {
                         Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $targetv6 -ErrorAction SilentlyContinue
                         Write-Host "  - $($nic.Name) IPv6 DNS 설정됨" -ForegroundColor Green
                    } catch {}
                }
            }
            Clear-DnsClientCache
            Write-OptLog -Step "DNS" -Status "적용됨" -Message "DNS 서버 설정 완료 (1.1.1.1/8.8.8.8)"
        }
    },
    @{
        Name = "불필요한 서비스 비활성화"
        Action = {
            $svcs = @(
                @{Name="SysMain"; Desc="SuperFetch"},
                @{Name="CDPSvc"; Desc="Connected Devices Platform"},
                @{Name="MapsBroker"; Desc="Downloaded Maps Manager"},
                @{Name="RetailDemo"; Desc="Retail Demo Service"},
                @{Name="Fax"; Desc="Fax Service"},
                @{Name="WerSvc"; Desc="Windows Error Reporting"}
            )
            foreach ($s in $svcs) {
                Set-Service -Name $s.Name -StartupType "Disabled"
                if ((Get-Service $s.Name -ErrorAction SilentlyContinue).Status -eq "Running") {
                    Stop-Service $s.Name -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Host "  - 불필요한 서비스 비활성화됨" -ForegroundColor Green
            Write-OptLog -Step "Services" -Status "적용됨" -Message "SysMain 등 서비스 비활성화"
        }
    },
    @{
        Name = "부팅 최적화"
        Action = {
            # Fast Startup
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 1 -Description "빠른 시작"
            
            # Boot Timeout
            $timeout = (bcdedit /enum | Select-String "timeout" | Out-String).Trim()
            if ($timeout -notmatch "3") {
                bcdedit /timeout 3 2>$null
                Write-Host "  - 부팅 대기 시간 3초로 변경" -ForegroundColor Green
            }
        }
    },
    @{
        Name = "AppX Deployment 최적화"
        Action = {
            # AppXSvc is often protected. Try to set but ignore failure.
            try {
                $svc = Get-Service -Name "AppXSvc" -ErrorAction SilentlyContinue
                if ($svc -and $svc.StartType -ne "Manual") {
                     Set-Service -Name "AppXSvc" -StartupType "Manual" -ErrorAction Stop
                }
            } catch {
                Write-Host "  - AppXSvc 서비스는 보호되어 변경할 수 없습니다. (정상)" -ForegroundColor Gray
            }
            
            # Tasks
            $task = "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup"
            Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
        }
    },
    @{
        Name = "메모리 최적화 (LargeSystemCache)"
        Action = {
            $mem = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
            if ($mem -ge 16) {
                Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "LargeSystemCache" -Value 1
            } else {
                Write-Host "  - RAM 16GB 미만으로 스킵" -ForegroundColor Gray
            }
        }
    },
    @{
        Name = "추가 최적화 (Delivery Optimization)"
        Action = {
            # Disable P2P Update
            Set-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Value 0
            
            # Disable Content Delivery
            $cdm = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            if (Test-Path $cdm) {
                $vals = @("SilentInstalledAppsEnabled", "SystemPaneSuggestionsEnabled", "SoftLandingEnabled", "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled")
                foreach ($v in $vals) { Set-Registry -Path $cdm -Name $v -Value 0 }
            }
        }
    }
)

# Optional SFC (Only if not in Orchestration mode and confirmed)
if (-not $global:OrchestrateMode) {
    Write-Host "시스템 파일 무결성 검사(SFC/DISM)를 실행하시겠습니까? (Y/N)" -ForegroundColor Yellow
    $yn = Read-Host 
    if ($yn -match "y") {
        $steps += @{
            Name = "시스템 파일 무결성 검사"
            Action = {
                DISM /Online /Cleanup-Image /RestoreHealth
                sfc /scannow
            }
        }
    }
}

Run-OptimizationSteps -Title "공통 시스템 최적화" -Steps $steps



