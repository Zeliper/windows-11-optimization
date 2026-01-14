# Windows 11 Search Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "019.search_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "인덱싱 정책 최적화"
        Action = {
            $pol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            Set-Registry -Path $pol -Name "PreventIndexingLowDiskSpaceMB" -Value 5000
            Set-Registry -Path $pol -Name "PreventIndexingEncryptedStores" -Value 1
            Set-Registry -Path $pol -Name "PreventIndexingOutlook" -Value 1
            
            # Background activity
            Set-Registry -Path $pol -Name "PreventIndexOnBattery" -Value 1
            Set-Registry -Path $pol -Name "DisableBackOff" -Value 0
            Set-Registry -Path $pol -Name "DisableRemovableDriveIndexing" -Value 1
            Set-Registry -Path $pol -Name "PreventIndexingNetworkDrives" -Value 1
        }
    },
    @{
        Name = "클라우드 검색 및 제안 비활성화"
        Action = {
            $set = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
            Set-Registry -Path $set -Name "IsDeviceSearchHistoryEnabled" -Value 0
            Set-Registry -Path $set -Name "IsAADCloudSearchEnabled" -Value 0
            Set-Registry -Path $set -Name "IsMSACloudSearchEnabled" -Value 0
            Set-Registry -Path $set -Name "SafeSearchMode" -Value 0
            
            $search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
            Set-Registry -Path $search -Name "BingSearchEnabled" -Value 0
            Set-Registry -Path $search -Name "CortanaConsent" -Value 0
            Set-Registry -Path $search -Name "AllowStoreResults" -Value 0
            
            # Web Search Policies
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "DisableWebSearch" -Value 1
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "ConnectedSearchUseWeb" -Value 0
        }
    },
    @{
        Name = "Windows Search 서비스 설정"
        Action = {
            # Default to Manual as per recommendation
            Set-Service -Name "WSearch" -StartupType "Manual"
            # We don't stop it if it's manual, it runs on demand
            Write-Host "  - Windows Search 서비스: 수동 시작으로 설정됨" -ForegroundColor Green
        }
    },
    @{
        Name = "인덱스 재구축 (선택 사항)"
        Action = {
            if (-not $global:OrchestrateMode) {
                # Interactive only
                Write-Host "  - 인덱스 재구축은 시간이 오래 걸리므로 이 스크립트에서는 자동으로 수행하지 않습니다." -ForegroundColor Gray
            }
        }
    }
)

Run-OptimizationSteps -Title "Windows Search 최적화" -Steps $steps

