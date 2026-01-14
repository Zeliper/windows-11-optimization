# Windows 11 NTFS/SSD Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "021.ntfs_ssd_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "NTFS 파일 시스템 최적화"
        Action = {
            $fs = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
            Set-Registry -Path $fs -Name "NtfsDisable8dot3NameCreation" -Value 1
            Set-Registry -Path $fs -Name "NtfsDisableLastAccessUpdate" -Value 0x80000001
            
            fsutil behavior set disable8dot3 1 2>&1 | Out-Null
            fsutil behavior set disablelastaccess 1 2>&1 | Out-Null
            Write-Host "  - 8.3 파일명 및 Last Access Time 업데이트 비활성화" -ForegroundColor Green
        }
    },
    @{
        Name = "TRIM 활성화 확인 및 설정"
        Action = {
            $trim = fsutil behavior query disabledeletenotify 2>&1
            if ($trim -match "= 1") {
                fsutil behavior set disabledeletenotify NTFS 0 2>&1 | Out-Null
                Write-Host "  - TRIM이 비활성화되어 있어 활성화했습니다." -ForegroundColor Green
            } else {
                Write-Host "  - TRIM이 이미 활성화되어 있습니다." -ForegroundColor Gray
            }
        }
    },
    @{
        Name = "Native NVMe 드라이버 활성화 (실험적)"
        Action = {
            # Only enable if requested via experimental options logic or if we decide to
            # Current decision: Skip by default in this refactor unless specific instruction.
            # Original script had interactive prompt.
            if ($global:OrchestrateMode) {
                 Write-Host "  - 실험적 기능(Native NVMe)은 자동으로 활성화하지 않습니다." -ForegroundColor Gray
            }
        }
    }
)

Run-OptimizationSteps -Title "NTFS 및 SSD 최적화" -Steps $steps
