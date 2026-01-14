# Windows 11 Storage Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "014.storage_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "Storage Sense 활성화"
        Action = {
            $ss = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
            Set-Registry -Path $ss -Name "01" -Value 1 -Description "Storage Sense 켜기"
            Set-Registry -Path $ss -Name "2048" -Value 7 -Description "매주 실행"
            Set-Registry -Path $ss -Name "04" -Value 1 -Description "임시 파일 정리"
            Set-Registry -Path $ss -Name "128" -Value 30 -Description "휴지통 30일 후 삭제"
        }
    },
    @{
        Name = "임시 파일 및 캐시 정리"
        Action = {
            # Stop Windows Update Service for cleaner cleanup
            Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
            
            $dirs = @("$env:TEMP", "$env:TMP", "$env:WINDIR\Temp", "$env:WINDIR\SoftwareDistribution\Download")
            foreach ($d in $dirs) {
                if (Test-Path $d) {
                    # Avoid deleting the current running script directory if it's in Temp (Remote Mode)
                    if ($global:OptimizationRoot -and $d -like "*$global:OptimizationRoot*") {
                        continue
                    }
                    # Also exclude the parent temp dir if we are in it
                    if ($global:OptimizationRoot -and (Split-Path $global:OptimizationRoot -Parent) -eq $d) {
                         Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike "$global:OptimizationRoot*" } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    } else {
                         Get-ChildItem $d -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            Write-Host "  - 임시 폴더 및 업데이트 캐시 정리됨" -ForegroundColor Green
            
            # Prefetch
            if (Test-Path "$env:WINDIR\Prefetch") {
                Get-ChildItem "$env:WINDIR\Prefetch" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }

            # Restart Service
            Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        }
    },
    @{
        Name = "Windows.old 및 업그레이드 잔여물 삭제"
        Action = {
            $paths = @("$env:SystemDrive\Windows.old", "$env:SystemDrive\`$Windows.~BT", "$env:SystemDrive\`$Windows.~WS")
            foreach ($p in $paths) {
                if (Test-Path $p) {
                    Write-Host "  - $p 삭제 중..." -ForegroundColor Yellow
                    try {
                        # Take Ownership
                        Start-Process cmd -ArgumentList "/c takeown /F `"$p`" /R /A /D Y" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                        # Grant Permissions
                        Start-Process cmd -ArgumentList "/c icacls `"$p`" /grant Administrators:F /T /Q" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                        # Remove
                        Remove-Item -Path $p -Recurse -Force -ErrorAction Stop
                        Write-Host "  - $p 삭제 완료" -ForegroundColor Green
                    } catch {
                        Write-Host "  - 삭제 실패 (권한 부족 또는 사용 중): $_" -ForegroundColor Gray
                    }
                }
            }
        }
    },
    @{
        Name = "시스템 복원 포인트 최적화"
        Action = {
            $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
            if ($drive) {
                $sizeGB = [math]::Round($drive.Size / 1GB * 0.05)
                if ($sizeGB -gt 10) { $sizeGB = 10 }
                if ($sizeGB -gt 10) { $sizeGB = 10 }
                $vssCommand = "vssadmin resize shadowstorage /for=$env:SystemDrive /on=$env:SystemDrive /maxsize=${sizeGB}GB"
                Start-Process cmd -ArgumentList "/c $vssCommand" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                Write-Host "  - 복원 포인트 용량 ${sizeGB}GB 제한" -ForegroundColor Green
                
                # Delete oldest
                # vssadmin delete shadows /for=$env:SystemDrive /oldest /quiet 2>$null
            }
        }
    },
    @{
        Name = "배달 최적화(Delivery Optimization) 정리"
        Action = {
            Stop-Service "DoSvc" -Force -ErrorAction SilentlyContinue
            $doCache = "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization"
            if (Test-Path $doCache) {
                 Remove-Item "$doCache\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
                 Remove-Item "$doCache\Downloads\*" -Recurse -Force -ErrorAction SilentlyContinue
            }
            Start-Service "DoSvc" -ErrorAction SilentlyContinue
            
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode" -Value 1 -Description "배달 최적화 LAN Only"
        }
    },
    @{
        Name = "로그 파일 정리"
        Action = {
            $logDirs = @("$env:WINDIR\Logs\CBS", "$env:WINDIR\Logs\DISM", "$env:WINDIR\Logs\WindowsUpdate")
            foreach ($l in $logDirs) {
                if (Test-Path $l) { Get-ChildItem $l -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Write-Host "  - 시스템 로그 파일 정리됨" -ForegroundColor Green
        }
    }
)

Run-OptimizationSteps -Title "저장소 최적화" -Steps $steps

