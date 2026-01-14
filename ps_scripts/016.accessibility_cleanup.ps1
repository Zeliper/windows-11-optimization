# Windows 11 Accessibility Cleanup Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "016.accessibility_cleanup.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "키보드 접근성 기능 (고정/토글/필터 키) 비활성화"
        Action = {
             # Sticky Keys
             Set-Registry -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506" -Type String
             # Toggle Keys
             Set-Registry -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value "58" -Type String
             # Filter Keys
             Set-Registry -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "122" -Type String
             Write-Host "  - 키보드 접근성 단축키 비활성화됨" -ForegroundColor Green
        }
    },
    @{
        Name = "마우스 키 및 고대비 비활성화"
        Action = {
            Set-Registry -Path "HKCU:\Control Panel\Accessibility\MouseKeys" -Name "Flags" -Value "58" -Type String
            Set-Registry -Path "HKCU:\Control Panel\Accessibility\HighContrast" -Name "Flags" -Value "4194" -Type String
        }
    },
    @{
        Name = "돋보기 및 내레이터 자동 시작 끄기"
        Action = {
            $mag = "HKCU:\Software\Microsoft\ScreenMagnifier"
            Set-Registry -Path $mag -Name "FollowCaret" -Value 0
            Set-Registry -Path $mag -Name "FollowMouse" -Value 0
            
            $nar = "HKCU:\Software\Microsoft\Narrator"
            Set-Registry -Path $nar -Name "WinEnterLaunchEnabled" -Value 0
            
            # Clean Configuration
            $acc = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility"
            if (Test-Path $acc) {
                $cfg = (Get-ItemProperty $acc).Configuration
                if ($cfg) {
                    # Remove magnifierpane, narrator, osk
                    $newCfg = $cfg -replace "magnifierpane", "" -replace "narrator", "" -replace "osk", "" -replace ";;", ";"
                    Set-ItemProperty -Path $acc -Name "Configuration" -Value $newCfg
                    Write-Host "  - 접근성 도구 자동 시작 제거" -ForegroundColor Green
                }
            }
        }
    },
    @{
        Name = "화면 키보드 및 터치 포인터 비활성화"
        Action = {
             Set-Registry -Path "HKCU:\Software\Microsoft\TabletTip\1.7" -Name "EnableDesktopModeAutoInvoke" -Value 0
             Set-Registry -Path "HKCU:\Software\Microsoft\TabletTip\1.7" -Name "TipbandDesiredVisibility" -Value 0
        }
    }
)

Run-OptimizationSteps -Title "접근성 기능 정리" -Steps $steps

