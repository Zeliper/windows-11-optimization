# Windows 11 Startup Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "015.startup_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "불필요한 시작 프로그램 비활성화"
        Action = {
            $targets = @("OneDrive", "MicrosoftEdgeAutoLaunch", "Cortana", "Skype", "Steam", "Discord", "Zoom", "Dropbox")
            $locations = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
            )
            
            $doDisable = $false
            if ($global:OrchestrateMode) {
                 # In orchestrate mode, we might skip or default. For now, let's just log potential ones.
                 # Or if you want to be aggressive, set $doDisable = $true.
                 # The original script asked the user if not orchestrated, and defaulted to Y.
                 # If orchestrated, it just showed them? Actually code says: "If OrchestrateMode... else { Write-Host ... }"
                 # The original only disabled if user confirmed in interactive mode.
                 Write-Host "  - 스킵: 자동화 모드에서는 기본적으로 시작 프로그램을 건드리지 않습니다." -ForegroundColor Gray
            } else {
                 $ans = Read-Host "발견된 권장 시작 프로그램을 비활성화하시겠습니까? (Y/N)"
                 if ($ans -match "y") { $doDisable = $true }
            }
            
            if ($doDisable) {
                foreach ($loc in $locations) {
                    $keys = Get-ItemProperty $loc -ErrorAction SilentlyContinue
                    foreach ($p in $keys.PSObject.Properties) {
                        foreach ($t in $targets) {
                            if ($p.Name -like "*$t*" -or $p.Value -like "*$t*") {
                                # Move to Disabled key (simulate) or just delete? Original moved to Run-Disabled.
                                $disabled = $loc -replace "Run", "Run-Disabled"
                                if (!(Test-Path $disabled)) { New-Item $disabled -Force | Out-Null }
                                Set-ItemProperty $disabled -Name $p.Name -Value $p.Value
                                Remove-ItemProperty $loc -Name $p.Name
                                Write-Host "    - $($p.Name) 비활성화됨" -ForegroundColor Green
                            }
                        }
                    }
                }
            }
        }
    },
    @{
        Name = "부팅 지연 및 시간 초과 설정"
        Action = {
            $exp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
            if (!(Test-Path $exp)) { New-Item $exp -Force | Out-Null }
            Set-Registry -Path $exp -Name "StartupDelayInMSec" -Value 0
            
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "ServicesPipeTimeout" -Value 60000
            
            # Boot Menu Timeout
            bcdedit /timeout 0 2>$null | Out-Null
            bcdedit /set "{current}" bootlog No 2>$null | Out-Null
        }
    },
    @{
        Name = "프리패치 및 슈퍼패치 최적화"
        Action = {
            # Check SSD
            $isSSD = $true # Simplified assumption or check
            $pd = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq 0 } # System disk assumption
            if ($pd -and $pd.MediaType -eq "HDD") { $isSSD = $false }
            
            $pp = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
            if ($isSSD) {
                Set-Registry -Path $pp -Name "EnablePrefetcher" -Value 2 -Description "Prefetcher 부팅만 (SSD)"
                Set-Registry -Path $pp -Name "EnableSuperfetch" -Value 0 -Description "Superfetch 끄기 (SSD)"
                Set-Service -Name "SysMain" -StartupType "Disabled"
            } else {
                Set-Registry -Path $pp -Name "EnablePrefetcher" -Value 3
                Set-Registry -Path $pp -Name "EnableSuperfetch" -Value 3
            }
        }
    },
    @{
        Name = "NTFS 및 파일 시스템 최적화"
        Action = {
            fsutil behavior set DisableLastAccess 1 2>$null | Out-Null
            fsutil behavior set disable8dot3 1 2>$null | Out-Null
            Write-Host "  - Last Access 업데이트 및 8.3 파일명 생성 비활성화" -ForegroundColor Green
        }
    },
    @{
        Name = "로그온 최적화"
        Action = {
            $sys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            Set-Registry -Path $sys -Name "RunLogonScriptSync" -Value 0
            Set-Registry -Path $sys -Name "DelayedDesktopSwitchTimeout" -Value 0
        }
    }
)

Run-OptimizationSteps -Title "시작 프로그램 및 부팅 최적화" -Steps $steps



