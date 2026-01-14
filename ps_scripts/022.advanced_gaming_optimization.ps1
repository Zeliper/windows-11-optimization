# Windows 11 Advanced Gaming Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "022.advanced_gaming_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "Power Throttling 비활성화"
        Action = {
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "EnergyEstimationEnabled" -Value 0
        }
    },
    @{
        Name = "시스템 타이머 및 응답성 최적화"
        Action = {
            bcdedit /set useplatformtick yes 2>$null | Out-Null
            bcdedit /set disabledynamictick yes 2>$null | Out-Null
            
            Set-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0
        }
    },
    @{
        Name = "오디오 및 게임 작업 우선순위"
        Action = {
            Set-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio" -Name "DisableProtectedAudioDG" -Value 1
            
            $tasks = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks"
            # Audio
            Set-Registry -Path "$tasks\Audio" -Name "Priority" -Value 1
            Set-Registry -Path "$tasks\Audio" -Name "Scheduling Category" -Value "High" -Type String
            Set-Registry -Path "$tasks\Audio" -Name "SFIO Priority" -Value "High" -Type String
            
            # Games
            Set-Registry -Path "$tasks\Games" -Name "GPU Priority" -Value 8
            Set-Registry -Path "$tasks\Games" -Name "Priority" -Value 6
            Set-Registry -Path "$tasks\Games" -Name "Scheduling Category" -Value "High" -Type String
            Set-Registry -Path "$tasks\Games" -Name "SFIO Priority" -Value "High" -Type String
        }
    },
    @{
        Name = "네트워크 어댑터 최적화 (Interrupt/FlowControl)"
        Action = {
            $adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
            foreach ($a in $adapters) {
                try { Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
                try { Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword "*FlowControl" -RegistryValue 0 -ErrorAction SilentlyContinue } catch {}
            }
        }
    },
    @{
        Name = "Edge 및 Chrome 백그라운드 차단"
        Action = {
            $edge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
            Set-Registry -Path $edge -Name "BackgroundModeEnabled" -Value 0
            Set-Registry -Path $edge -Name "StartupBoostEnabled" -Value 0
            
            $chrome = "HKLM:\SOFTWARE\Policies\Google\Chrome"
            Set-Registry -Path $chrome -Name "BackgroundModeEnabled" -Value 0
        }
    },
    @{
        Name = "Game Bar 및 DVR 비활성화"
        Action = {
            $gb = "HKCU:\Software\Microsoft\GameBar"
            Set-Registry -Path $gb -Name "ShowStartupPanel" -Value 0
            
            $dvrPol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
            Set-Registry -Path $dvrPol -Name "AllowGameDVR" -Value 0
            
            $gc = "HKCU:\System\GameConfigStore"
            Set-Registry -Path $gc -Name "GameDVR_Enabled" -Value 0
            Set-Registry -Path $gc -Name "GameDVR_FSEBehavior" -Value 2
        }
    }
)

Run-OptimizationSteps -Title "고급 게임 최적화" -Steps $steps
