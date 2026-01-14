# Windows 11 Defender, Firewall, OneDrive Cleanup Script
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
Init-OptimizationLog -ScriptName "003.defender_onedrive_firewall.ps1" -ScriptVersion "1.2.0"

# --- Helper Functions specific to this script ---

function Test-DefenderRealTimeDisabled {
    try {
        $mpStatus = Get-MpComputerStatus -ErrorAction Stop
        return (-not $mpStatus.RealTimeProtectionEnabled)
    } catch {
        return $true
    }
}

function Test-FirewallDisabled {
    param([string]$ProfileName)
    try {
        $profile = Get-NetFirewallProfile -Name $ProfileName -ErrorAction Stop
        return ($profile.Enabled -eq $false)
    } catch {
        return $false
    }
}

function Remove-OneDriveIfExists {
    $oneDriveSetup64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    $oneDriveSetup32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
    $oneDriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    $oneDriveFolder = "$env:USERPROFILE\OneDrive"
    $oneDriveApp = "$env:LOCALAPPDATA\Microsoft\OneDrive"

    $isInstalled = (Test-Path $oneDriveSetup64) -or (Test-Path $oneDriveSetup32) -or
                   $oneDriveProcess -or (Test-Path $oneDriveApp)
                   
    return $isInstalled
}

$steps = @(
    @{
        Name = "Windows Defender 보호 기능 비활성화"
        Action = {
            if (-not $global:ForceOverride -and (Test-DefenderRealTimeDisabled)) {
                Write-Host "  - Windows Defender 이미 비활성화됨 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "Defender" -Status "스킵됨" -Message "이미 비활성화됨"
                return
            }
            
            # Tamper Protection Check
            try {
                $tamper = (Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected
                if ($tamper) {
                    Write-Host "    [!] Tamper Protection 활성화됨. 일부 설정이 실패할 수 있음." -ForegroundColor Red
                    Write-Host "        수동으로 '변조 보호'를 꺼야 합니다." -ForegroundColor Yellow
                }
            } catch {}

            # Disable via CMDlets
            try {
                Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
                Set-MpPreference -EnableDevDriveProtection $false -ErrorAction SilentlyContinue
                Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
                Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
                Write-Host "  - Defender 기본 보호 기능 비활성화 명령 실행됨" -ForegroundColor Green
            } catch {
                Write-Host "  - Defender 명령 실행 실패 (레지스트리 시도 예정)" -ForegroundColor Yellow
            }

            # Registry Fallbacks
            $policies = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
            Set-Registry -Path $policies -Name "DisableAntiSpyware" -Value 1
            Set-Registry -Path $policies -Name "DisableAntiVirus" -Value 1
            
            $rtPolicies = "$policies\Real-Time Protection"
            Set-Registry -Path $rtPolicies -Name "DisableBehaviorMonitoring" -Value 1
            Set-Registry -Path $rtPolicies -Name "DisableOnAccessProtection" -Value 1
            Set-Registry -Path $rtPolicies -Name "DisableScanOnRealtimeEnable" -Value 1
            Set-Registry -Path $rtPolicies -Name "DisableRealtimeMonitoring" -Value 1
            Set-Registry -Path $rtPolicies -Name "DisableIOAVProtection" -Value 1

            # Boot Task
            $taskName = "DisableDefenderRealtime"
            $psCommand = "Set-MpPreference -DisableRealtimeMonitoring `$true -ErrorAction SilentlyContinue; Set-MpPreference -DisableBehaviorMonitoring `$true -ErrorAction SilentlyContinue"
            
            try {
                $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$psCommand`""
                $trigger = New-ScheduledTaskTrigger -AtStartup
                $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
                Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
                Write-Host "  - 부팅 시 Defender 비활성화 작업 등록됨" -ForegroundColor Green
            } catch {}
            
            Write-OptLog -Step "Defender" -Status "적용됨" -Message "Defender 정책 및 예약 작업 설정 완료"
        }
    },
    @{
        Name = "Windows 방화벽 해제 및 RDP 허용"
        Action = {
            # Check existing state
            $allDisabled = (Test-FirewallDisabled "Domain") -and (Test-FirewallDisabled "Private") -and (Test-FirewallDisabled "Public")
            if (-not $global:ForceOverride -and $allDisabled) {
                Write-Host "  - 방화벽 이미 해제됨 (스킵)" -ForegroundColor Gray
                # Ensure services are correct though
            } else {
                # Enable Services needed to manage Firewall
                Set-Service -Name "mpsdrv" -StartupType "Automatic" # Actually boot/system driver, simplified here or use sc/reg
                Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mpsdrv" -Name "Start" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                
                Set-Service -Name "BFE" -StartupType "Automatic"
                if ((Get-Service "BFE").Status -ne "Running") { Start-Service "BFE" -ErrorAction SilentlyContinue }
                
                Set-Service -Name "mpssvc" -StartupType "Automatic"
                if ((Get-Service "mpssvc").Status -ne "Running") { Start-Service "mpssvc" -ErrorAction SilentlyContinue }

                # Disable Profiles
                Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction SilentlyContinue
                Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Allow -DefaultOutboundAction Allow -ErrorAction SilentlyContinue
                
                # Allow RDP explicitly
                New-NetFirewallRule -DisplayName "RDP Allow" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -Profile Any -Enabled True -ErrorAction SilentlyContinue | Out-Null
                
                Write-Host "  - 방화벽 프로필 해제 및 RDP 허용 규칙 추가됨" -ForegroundColor Green
                Write-OptLog -Step "Firewall" -Status "적용됨" -Message "방화벽 해제 완료"
            }
            
            # Policy Registry
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" -Name "EnableFirewall" -Value 0
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile" -Name "EnableFirewall" -Value 0
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile" -Name "EnableFirewall" -Value 0
            
            # RDP Service Enable
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Description "RDP 연결 허용"
            Set-Service -Name "TermService" -StartupType "Automatic"
        }
    },
    @{
        Name = "OneDrive 제거 및 정리"
        Action = {
            if (-not $global:ForceOverride -and -not (Remove-OneDriveIfExists)) {
                Write-Host "  - OneDrive 이미 제거됨 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "OneDrive" -Status "스킵됨" -Message "이미 제거됨"
            } else {
                # Kill Process
                Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                
                # Uninstall
                $setup64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
                if (Test-Path $setup64) {
                    Start-Process $setup64 -ArgumentList "/uninstall" -Wait -NoNewWindow
                    Write-Host "  - OneDrive 제거 실행 (64bit)" -ForegroundColor Green
                }
                
                # Registry & Cleanup
                Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
                Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1
                
                # Hide from Explorer
                $clsid = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
                if (Test-Path $clsid) {
                    Set-ItemProperty -Path $clsid -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -ErrorAction SilentlyContinue
                }
                
                # Remove Folders
                Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
                
                Write-OptLog -Step "OneDrive" -Status "적용됨" -Message "OneDrive 제거 및 잔여 파일 정리 완료"
            }
        }
    }
)

Run-OptimizationSteps -Title "보안 및 클라우드 정리 (Defender/Firewall/OneDrive)" -Steps $steps

