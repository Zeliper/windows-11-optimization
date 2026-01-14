# Windows 11 Pro Update Settings Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
# If running via Orchestrator, PSScriptRoot might be valid if dot-sourced.
# If running standalone, we try to find core.ps1 in the same directory.
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    # Fallback for remote/other execution contexts if needed, or error
    Write-Warning "Core module not found at $corePath. Attempting to proceed if already loaded."
}

# Initialize Script Config
Init-OptimizationLog -ScriptName "001.disable_update.ps1" -ScriptVersion "1.2.0"

# User-Defined Steps
$steps = @(
    @{
        Name = "Windows Update 정책 설정"
        Action = {
            $WUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            
            # AUOptions: 2 = Notify before download (Manual)
            Set-Registry -Path $WUPath -Name "AUOptions" -Value 2 -Description "자동 업데이트 알림(수동) 설정"
            
            # NoAutoUpdate: 0 (Enables the policy settings above)
            Set-Registry -Path $WUPath -Name "NoAutoUpdate" -Value 0 -Description "자동 업데이트 정책 활성화"
            
            # NoAutoRebootWithLoggedOnUsers: 1 (Prevents reboot while user logged in)
            Set-Registry -Path $WUPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Description "로그온 중 자동 재시작 방지"
        }
    },
    @{
        Name = "추가 업데이트 설정"
        Action = {
            $WUSettingsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"
            Set-Registry -Path $WUSettingsPath -Name "AUOptions" -Value 2 -Description "추가 업데이트 설정(수동)"
        }
    },
    @{
        Name = "UAC(사용자 계정 컨트롤) 설정"
        Action = {
            $UACPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            
            # EnableLUA: 1 (Keep UAC on, disabling causes UI issues)
            Set-Registry -Path $UACPath -Name "EnableLUA" -Value 1 -Description "UAC 활성화 유지"
            
            # Admin Prompt: 0 (Elevate without prompting)
            Set-Registry -Path $UACPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -Description "관리자 승인 프롬프트 끄기"
            
            # User Prompt: 3 (Prompt for credentials)
            Set-Registry -Path $UACPath -Name "ConsentPromptBehaviorUser" -Value 3 -Description "일반 사용자 자격 증명 요청"
            
            # Secure Desktop: 0 (Disable dimming screen)
            Set-Registry -Path $UACPath -Name "PromptOnSecureDesktop" -Value 0 -Description "보안 데스크톱 비활성화"
        }
    }
)

# Execute
Run-OptimizationSteps -Title "Windows Update 및 보안 설정" -Steps $steps


