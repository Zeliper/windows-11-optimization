# Windows 11 Mouse/Input Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "017.mouse_input_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "마우스 가속 비활성화"
        Action = {
            $mouse = "HKCU:\Control Panel\Mouse"
            Set-Registry -Path $mouse -Name "MouseSpeed" -Value "0" -Type String
            Set-Registry -Path $mouse -Name "MouseThreshold1" -Value "0" -Type String
            Set-Registry -Path $mouse -Name "MouseThreshold2" -Value "0" -Type String
            
            # Linear Curve
            $linearX = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, 0xC0,0xCC,0x0C,0x00,0x00,0x00,0x00,0x00, 0x80,0x99,0x19,0x00,0x00,0x00,0x00,0x00, 0x40,0x66,0x26,0x00,0x00,0x00,0x00,0x00, 0x00,0x33,0x33,0x00,0x00,0x00,0x00,0x00)
            $linearY = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0x70,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0xA8,0x00,0x00,0x00,0x00,0x00, 0x00,0x00,0xE0,0x00,0x00,0x00,0x00,0x00)
            
            Set-ItemProperty -Path $mouse -Name "SmoothMouseXCurve" -Value $linearX -Type Binary -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $mouse -Name "SmoothMouseYCurve" -Value $linearY -Type Binary -ErrorAction SilentlyContinue
            Write-Host "  - 마우스 가속 커브 선형화 완료" -ForegroundColor Green
        }
    },
    @{
        Name = "키보드 반응 속도 최적화"
        Action = {
            $kbd = "HKCU:\Control Panel\Keyboard"
            Set-Registry -Path $kbd -Name "KeyboardDelay" -Value "0" -Type String
            Set-Registry -Path $kbd -Name "KeyboardSpeed" -Value "31" -Type String
        }
    },
    @{
        Name = "입력 장치 버퍼(Queue) 최적화"
        Action = {
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" -Name "MouseDataQueueSize" -Value 100
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" -Name "KeyboardDataQueueSize" -Value 100
        }
    },
    @{
        Name = "시스템 응답성 및 게임 우선순위"
        Action = {
            Set-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -Name "SystemResponsiveness" -Value 0
            Set-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows Media Foundation\Platform" -Name "EnableFrameServerMode" -Value 0
        }
    },
    @{
        Name = "터치패드 설정 (Precision)"
        Action = {
            if (Test-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad") {
                Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad" -Name "AAPThreshold" -Value 0
            }
        }
    }
)

Run-OptimizationSteps -Title "마우스/입력 장치 최적화" -Steps $steps
