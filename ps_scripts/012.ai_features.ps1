# Windows 11 AI Features Disable Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "012.ai_features.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "Windows Recall 비활성화"
        Action = {
            $pol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
            Set-Registry -Path $pol -Name "AllowRecallEnablement" -Value 0
            Set-Registry -Path $pol -Name "DisableAIDataAnalysis" -Value 1
            Set-Registry -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -Value 1
            
            $tasks = @("RecallBackgroundActivity", "RecallHistoryCreation")
            foreach ($t in $tasks) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
        }
    },
    @{
        Name = "Windows Copilot 비활성화"
        Action = {
            Set-Registry -Path "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -Value 1
            
            # Apps
            $pkgs = @("Microsoft.Copilot", "Microsoft.Windows.Copilot", "Microsoft.CopilotRuntime")
            foreach ($p in $pkgs) { Get-AppxPackage *$p* | Remove-AppxPackage -ErrorAction SilentlyContinue }
            
            # Edge
            $edge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
            Set-Registry -Path $edge -Name "HubsSidebarEnabled" -Value 0
            Set-Registry -Path $edge -Name "CopilotCDPPageContext" -Value 0
        }
    },
    @{
        Name = "AI Actions 및 Click to Do 비활성화"
        Action = {
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowAIActions" -Value 0
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard" -Name "Disabled" -Value 1
            
            # Input Insights
            Set-Registry -Path "HKCU:\Software\Microsoft\Input\Settings" -Name "InsightsEnabled" -Value 0
        }
    },
    @{
        Name = "앱 내 AI 기능 끄기 (Paint/Photos)"
        Action = {
            Set-Registry -Path "HKCU:\Software\Microsoft\Paint" -Name "CocreatorEnabled" -Value 0
            Set-Registry -Path "HKCU:\Software\Microsoft\Paint" -Name "ImageCreatorEnabled" -Value 0
            Set-Registry -Path "HKCU:\Software\Microsoft\Notepad" -Name "RewriteEnabled" -Value 0
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Photos" -Name "AiErasingEnabled" -Value 0
        }
    },
    @{
        Name = "AI 서비스 및 텔레메트리 끄기"
        Action = {
            foreach ($s in @("AIXHost", "AIFabricService")) {
                Set-Service -Name $s -StartupType "Disabled"
                if ((Get-Service $s -ErrorAction SilentlyContinue).Status -eq "Running") { Stop-Service $s -Force -ErrorAction SilentlyContinue }
            }
            Set-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack" -Name "AIDataCollection" -Value 0
        }
    },
    @{
        Name = "AI 관련 패키지 및 기능 제거"
        Action = {
            # Search / Spotlight AI
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Value 0
            
            # Content Delivery (Prevent Auto Install)
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SilentInstalledAppsEnabled" -Value 0
            
            # Remove Recall Feature
            Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }
    }
)

Run-OptimizationSteps -Title "AI 기능 비활성화" -Steps $steps

