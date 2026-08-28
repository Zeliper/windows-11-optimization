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
    },
    @{
        Name = "설정 앱 및 Shell AI 통합 서비스 제거 (심화)"
        Action = {
            # 설정 앱의 AI 기능 접근 비활성화
            $settingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications"
            Set-Registry -Path $settingsPath -Name "EnableAccountNotifications" -Value 0 -Description "설정 계정 알림 끄기"

            # AI Hub/Spotlight 비활성화 (설정 앱 로딩 지연 원인)
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Start_IrisRecommendations" -Value 0 -Description "Iris AI 추천 끄기"

            # Windows Shell Experience Host AI 기능 끄기
            $shellExp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            $subs = @("SubscribedContent-310093Enabled", "SubscribedContent-338393Enabled", "SubscribedContent-353698Enabled")
            foreach ($s in $subs) {
                Set-Registry -Path $shellExp -Name $s -Value 0 -Description "$s 비활성화"
            }
            
            # 서비스 강제 비활성화 (Registry)
            # WSAIFabricSvc
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WSAIFabricSvc" -Name "Start" -Value 4 -Description "WSAIFabricSvc 서비스 시작 중지"
            
            # CDPUserSvc (설정 앱 지연 주원인)
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Services\CDPUserSvc" -Name "Start" -Value 4 -Description "CDPUserSvc 서비스 시작 중지"
        }
    }
)

Run-OptimizationSteps -Title "AI 기능 비활성화" -Steps $steps



