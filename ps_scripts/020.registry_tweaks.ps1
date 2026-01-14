# Windows 11 Registry Tweaks Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "020.registry_tweaks.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "UI 반응성 향상 (메뉴 지연 등)"
        Action = {
            $desk = "HKCU:\Control Panel\Desktop"
            Set-Registry -Path $desk -Name "MenuShowDelay" -Value "0" -Type String
            Set-Registry -Path $desk -Name "HungAppTimeout" -Value "2000" -Type String
            Set-Registry -Path $desk -Name "WaitToKillAppTimeout" -Value "3000" -Type String
            Set-Registry -Path $desk -Name "AutoEndTasks" -Value "1" -Type String
            Set-Registry -Path $desk -Name "ForegroundLockTimeout" -Value 0
            Set-Registry -Path $desk -Name "MouseHoverTime" -Value "10" -Type String
            
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "WaitToKillServiceTimeout" -Value "3000" -Type String
        }
    },
    @{
        Name = "시스템 및 네트워크 성능 튜닝"
        Action = {
            $lan = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
            Set-Registry -Path $lan -Name "IRPStackSize" -Value 20
            Set-Registry -Path $lan -Name "Size" -Value 3
            
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "DefaultTTL" -Value 64
        }
    },
    @{
        Name = "탐색기 및 기타 설정"
        Action = {
            $exp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
            Set-Registry -Path $exp -Name "NoLowDiskSpaceChecks" -Value 1
            Set-Registry -Path $exp -Name "ConfirmFileDelete" -Value 0
            
            # SvcHost Separation based on RAM
            $ramKB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1KB)
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Value $ramKB
        }
    }
)

Run-OptimizationSteps -Title "레지스트리 미세 조정" -Steps $steps

