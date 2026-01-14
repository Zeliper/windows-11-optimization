# Windows 11 Gaming Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "009.gaming_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "VBS/HVCI 비활성화 (보안 기능 끄기)"
        Action = {
            $dg = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
            Set-Registry -Path $dg -Name "EnableVirtualizationBasedSecurity" -Value 0
            Set-Registry -Path $dg -Name "RequirePlatformSecurityFeatures" -Value 0
            Set-Registry -Path $dg -Name "LsaCfgFlags" -Value 0
            
            $hvci = "$dg\Scenarios\HypervisorEnforcedCodeIntegrity"
            Set-Registry -Path $hvci -Name "Enabled" -Value 0
        }
    },
    @{
        Name = "GPU 스케줄링 및 Game Mode"
        Action = {
            # HAGS
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -Description "HAGS 활성화"
            
            # Game Mode
            $gm = "HKCU:\Software\Microsoft\GameBar"
            Set-Registry -Path $gm -Name "AllowAutoGameMode" -Value 1
            Set-Registry -Path $gm -Name "AutoGameModeEnabled" -Value 1
            
            # Game DVR Disable
            Set-Registry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0
        }
    },
    @{
        Name = "시각 효과 최적화"
        Action = {
            # Visual Effects: Custom
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2
            
            # Transparency
            Set-Registry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0
            
            # UserPreferencesMask (Performance tweaks but keep drag window)
            $desktop = "HKCU:\Control Panel\Desktop"
            $mask = [byte[]](0x92,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
            Set-ItemProperty -Path $desktop -Name "UserPreferencesMask" -Value $mask -Type Binary -Force
            
            Set-Registry -Path $desktop -Name "MinAnimate" -Value "0" -Type String
            Set-Registry -Path $desktop -Name "MenuShowDelay" -Value "0" -Type String
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0
        }
    },
    @{
        Name = "전체 화면 최적화 및 Game Bar 끄기"
        Action = {
            # FSE Disable
            $gc = "HKCU:\System\GameConfigStore"
            Set-Registry -Path $gc -Name "GameDVR_Enabled" -Value 0
            Set-Registry -Path $gc -Name "GameDVR_FSEBehaviorMode" -Value 2
            Set-Registry -Path $gc -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1
            Set-Registry -Path $gc -Name "GameDVR_FSEBehavior" -Value 2
            Set-Registry -Path $gc -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1
            Set-Registry -Path $gc -Name "GameDVR_EFSEFeatureFlags" -Value 0
            
            # Xbox Game Bar Disable
            $gm = "HKCU:\Software\Microsoft\GameBar" 
            Set-Registry -Path $gm -Name "UseNexusForGameBarEnabled" -Value 0
            Set-Registry -Path $gm -Name "ShowStartupPanel" -Value 0
            Set-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
            
            # Services
            foreach ($s in @("xbgm", "XboxGipSvc")) {
                Set-Service -Name $s -StartupType "Disabled"
                if ((Get-Service $s -ErrorAction SilentlyContinue).Status -eq "Running") { Stop-Service $s -Force -ErrorAction SilentlyContinue }
            }
        }
    },
    @{
        Name = "GPU 우선순위 (SystemProfile)"
        Action = {
            $tasks = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            Set-Registry -Path $tasks -Name "GPU Priority" -Value 8
            Set-Registry -Path $tasks -Name "Priority" -Value 6
            Set-Registry -Path $tasks -Name "Scheduling Category" -Value "High" -Type String
            Set-Registry -Path $tasks -Name "SFIO Priority" -Value "High" -Type String
            
            $sys = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            Set-Registry -Path $sys -Name "SystemResponsiveness" -Value 0
            Set-Registry -Path $sys -Name "NetworkThrottlingIndex" -Value 0xFFFFFFFF
        }
    },
        Name = "AppX/Gaming 서비스 최적화"
        Action = {
            $services = @("AppXSvc", "DoSvc", "XblAuthManager", "XblGameSave")
            $modes    = @("Manual", "Manual", "Disabled", "Disabled")

            for ($i=0; $i -lt $services.Count; $i++) {
                $s = $services[$i]
                $m = $modes[$i]
                
                try {
                    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
                    if ($svc -and $svc.StartType -ne $m) {
                        Set-Service -Name $s -StartupType $m -ErrorAction Stop
                    }
                } catch {
                     Write-Host "  - $s 서비스 설정 건너뜀 (보호됨/권한 부족)" -ForegroundColor Gray
                }
            }
        }
)

Write-Host "주의: 이 스크립트는 VBS/HVCI 등 보안 기능을 비활성화합니다." -ForegroundColor Red
if (-not $global:OrchestrateMode) {
    $c = Read-Host "계속하시겠습니까? (Y/N)"
    if ($c -notmatch "y") { exit }
}

Run-OptimizationSteps -Title "게임 성능 최적화" -Steps $steps

