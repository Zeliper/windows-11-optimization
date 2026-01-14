# Windows 11 Power & Network Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

# Initialize
Init-OptimizationLog -ScriptName "002.power_network.ps1" -ScriptVersion "1.2.0"

# Helper for Power GUID
function Get-PowerSchemeGuid {
    param([string]$Line)
    $match = [regex]::Match($Line, '[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}')
    if ($match.Success) { return $match.Value }
    return $null
}

# Utility for power settings check
function Get-PowerSettingValue {
    param([string]$SubGroup, [string]$Setting, [string]$Type)
    $output = powercfg /query SCHEME_CURRENT $SubGroup $Setting 2>$null
    $pattern = if ($Type -eq "AC") { "현재 AC 전원 설정 인덱스|Current AC Power Setting Index" } else { "현재 DC 전원 설정 인덱스|Current DC Power Setting Index" }
    $match = $output | Select-String $pattern
    if ($match) {
        $hexMatch = [regex]::Match($match.Line, '0x([0-9a-fA-F]+)')
        if ($hexMatch.Success) {
            return [Convert]::ToInt32($hexMatch.Groups[1].Value, 16)
        }
    }
    return -1
}

$steps = @(
    @{
        Name = "최고 성능/고성능 전원 옵션 설정"
        Action = {
            $activeSchemeOutput = powercfg -getactivescheme
            $currentSchemeGuid = Get-PowerSchemeGuid -Line $activeSchemeOutput

            $allSchemes = powercfg -list
            $ultimatePerf = $allSchemes | Select-String "최고 성능|Ultimate Performance" | Select-Object -First 1
            $highPerf = $allSchemes | Select-String "고성능|High performance" | Select-Object -First 1
            $balanced = $allSchemes | Select-String "균형|Balanced" | Select-Object -First 1

            $ultimatePerfGuid = if ($ultimatePerf) { Get-PowerSchemeGuid -Line $ultimatePerf.Line }
            $highPerfGuid = if ($highPerf) { Get-PowerSchemeGuid -Line $highPerf.Line }

            # Create Ultimate Performance if missing
            if (-not $ultimatePerfGuid) {
                powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
                $allSchemes = powercfg -list
                $ultimatePerf = $allSchemes | Select-String "최고 성능|Ultimate Performance" | Select-Object -First 1
                if ($ultimatePerf) { $ultimatePerfGuid = Get-PowerSchemeGuid -Line $ultimatePerf.Line }
            }

            # Select Target
            $targetGuid = if ($ultimatePerfGuid) { $ultimatePerfGuid } elseif ($highPerfGuid) { $highPerfGuid } else { $balancedGuid }
            $targetName = if ($ultimatePerfGuid) { "최고 성능" } elseif ($highPerfGuid) { "고성능" } else { "균형" }

            if ($targetGuid -and ($global:ForceOverride -or $currentSchemeGuid -ne $targetGuid)) {
                powercfg -setactive $targetGuid
                Write-Host "  - 전원 구성표 변경: $targetName ($targetGuid)" -ForegroundColor Green
                Write-OptLog -Step "전원 옵션" -Status "적용됨" -Message "전원 구성표를 $targetName(으)로 변경"
            } else {
                Write-Host "  - 이미 $targetName 사용 중 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "전원 옵션" -Status "스킵됨" -Message "이미 $targetName"
            }
        }
    },
    @{
        Name = "절전 설정 비활성화"
        Action = {
            # Sleep
            powercfg -change -standby-timeout-ac 0
            powercfg -change -standby-timeout-dc 0
            
            # Monitor
            powercfg -change -monitor-timeout-ac 0
            powercfg -change -monitor-timeout-dc 0
            
            # Disk
            powercfg -change -disk-timeout-ac 0
            powercfg -change -disk-timeout-dc 0
            
            # Hibernate
            powercfg -hibernate off
            
            Write-Host "  - 절전, 모니터 끄기, 디스크 끄기, 최대 절전 모드 비활성화 완료" -ForegroundColor Green
            Write-OptLog -Step "절전 설정" -Status "적용됨" -Message "모든 절전 타이머 0 설정 및 최대 절전 끄기"
        }
    },
    @{
        Name = "USB 및 PCIe 절전 비활성화"
        Action = {
            $activeScheme = Get-PowerSchemeGuid -Line (powercfg -getactivescheme)
            if ($activeScheme) {
                # USB Selective Suspend
                powercfg -setacvalueindex $activeScheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
                powercfg -setdcvalueindex $activeScheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
                
                # PCIe Link State Power Management
                powercfg -setacvalueindex $activeScheme 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
                powercfg -setdcvalueindex $activeScheme 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
                
                powercfg -setactive $activeScheme
                Write-Host "  - USB 및 PCIe 전원 관리 비활성화 완료" -ForegroundColor Green
                Write-OptLog -Step "고급 전원" -Status "적용됨" -Message "USB/PCIe 절전 끄기"
            }
        }
    },
    @{
        Name = "네트워크 어댑터 절전 모드 해제"
        Action = {
            $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
            foreach ($adapter in $adapters) {
                $pnpDevice = Get-PnpDevice | Where-Object { $_.FriendlyName -eq $adapter.InterfaceDescription }
                if ($pnpDevice) {
                     $pnpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
                     Get-ChildItem $pnpPath -ErrorAction SilentlyContinue | ForEach-Object {
                        $driverDesc = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
                        if ($driverDesc -eq $adapter.InterfaceDescription) {
                            Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -ErrorAction SilentlyContinue
                            Write-Host "  - $($adapter.Name): 절전 모드 해제" -ForegroundColor Green
                        }
                     }
                }
            }
        }
    },
    @{
        Name = "네트워크 응답 속도 최적화 (Nagle Algorithm)"
        Action = {
            $tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
            $interfaces = Get-ChildItem $tcpipPath -ErrorAction SilentlyContinue
            foreach ($iface in $interfaces) {
                 Set-Registry -Path $iface.PSPath -Name "TcpAckFrequency" -Value 1 -Description "TcpAckFrequency ($($iface.PSChildName))"
                 Set-Registry -Path $iface.PSPath -Name "TcpNoDelay" -Value 1 -Description "TcpNoDelay ($($iface.PSChildName))"
            }
        }
    },
    @{
        Name = "텔레메트리 및 데이터 수집 비활성화"
        Action = {
            # Services
            Set-Service -Name "DiagTrack" -StartupType "Disabled" -Stop $true -Description "Connected User Experiences and Telemetry"
            Set-Service -Name "dmwappushservice" -StartupType "Disabled" -Stop $true -Description "WAP Push Service"

            # Registry Settings
            $dataCollectionPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
            Set-Registry -Path $dataCollectionPath -Name "AllowTelemetry" -Value 0
            Set-Registry -Path $dataCollectionPath -Name "MaxTelemetryAllowed" -Value 0
            
            $siufPath = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"
            Set-Registry -Path $siufPath -Name "NumberOfSIUFInPeriod" -Value 0 -Description "피드백 알림 빈도"

            $advertisingPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
            Set-Registry -Path $advertisingPath -Name "Enabled" -Value 0 -Description "광고 ID"

            # Scheduled Tasks
            Disable-ScheduledTask_Safe -Path "\Microsoft\Windows\Application Experience\" -Name "Microsoft Compatibility Appraiser"
            Disable-ScheduledTask_Safe -Path "\Microsoft\Windows\Customer Experience Improvement Program\" -Name "Consolidator"
        }
    }
)

Run-OptimizationSteps -Title "전원 및 네트워크 최적화" -Steps $steps
