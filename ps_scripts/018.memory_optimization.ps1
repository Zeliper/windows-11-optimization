# Windows 11 Memory Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "018.memory_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "시스템 메모리 및 드라이브 분석"
        Action = {
            $os = Get-CimInstance Win32_OperatingSystem
            $cs = Get-CimInstance Win32_ComputerSystem
            $totalRAM = [math]::Round($cs.TotalPhysicalMemory / 1GB)
            Write-Host "  - RAM: $totalRAM GB" -ForegroundColor White
            
            # Check SSD
            $drive = $env:SystemDrive.Substring(0,1)
            $isSSD = $false
            $pd = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq 0 } # Assumes disk 0 is system, simplistic check
            # Better check via partition?
            try {
                $partition = Get-Partition -DriveLetter $drive -ErrorAction SilentlyContinue
                if ($partition) {
                    $pd = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $partition.DiskNumber }
                    if ($pd.MediaType -eq "SSD" -or $pd.BusType -eq "NVMe") { $isSSD = $true }
                }
            } catch {}
            
            Write-Host "  - Drive Type: $(if ($isSSD) {'SSD'} else {'HDD'})" -ForegroundColor White
            
            # Save for next steps
            $global:MemOpt_TotalRAM = $totalRAM
            $global:MemOpt_IsSSD = $isSSD
        }
    },
    @{
        Name = "Superfetch/SysMain 및 Prefetch 설정"
        Action = {
            $pp = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
            if ($global:MemOpt_IsSSD) {
                # SSD: SysMain Off, Prefetch Boot Only (2) or Off (0) if NVMe
                Set-Service -Name "SysMain" -StartupType "Disabled"
                if ((Get-Service "SysMain").Status -eq "Running") { Stop-Service "SysMain" -Force }
                Set-Registry -Path $pp -Name "EnablePrefetcher" -Value 2 -Description "Prefetcher 부팅만 (SSD)"
                Set-Registry -Path $pp -Name "EnableSuperfetch" -Value 0 -Description "Superfetch 끄기 (SSD)"
            } else {
                # HDD: Enable
                Set-Service -Name "SysMain" -StartupType "Automatic"
                Set-Registry -Path $pp -Name "EnablePrefetcher" -Value 3
                Set-Registry -Path $pp -Name "EnableSuperfetch" -Value 3
            }
        }
    },
    @{
        Name = "페이지 파일 최적화"
        Action = {
            # Logic: If orchestrated, maybe skip or set to auto?
            # Original script logic: if RAM <= 8 set 1.5x, etc.
            # We will default to Auto Managed unless ForceOverride is used to specific values?
            # Actually, let's stick to the script's recommendation but only apply if user agrees or we decide to enforce.
            # For safety in automation, resetting to System Managed is often safest, OR setting fixed size if we are sure.
            # Let's keep it simple: If RAM > 16GB, set fixed 16-24GB?
            # The original script asked user. In orchestration, we might assume 'Yes' or skip.
            # Let's just log the recommendation for now to avoid breaking systems with weird drive setups.
            
            $ram = $global:MemOpt_TotalRAM
            $min = 16GB / 1MB; $max = 24GB / 1MB
            if ($ram -le 8) { $min = $ram * 1.5 * 1024; $max = $ram * 3 * 1024 }
            elseif ($ram -lt 32) { $min = $ram * 1024; $max = $ram * 2 * 1024 }
            
            Write-Host "  - 페이지 파일 권장: ${min}MB ~ ${max}MB" -ForegroundColor Gray
            
            if ($global:OrchestrateMode) {
                 Write-Host "  - 자동화 모드: 페이지 파일 설정을 건너뜁니다 (위험 방지)" -ForegroundColor Yellow
            }
        }
    },
    @{
        Name = "메모리 관리 레지스트리 최적화"
        Action = {
            $mm = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
            $lsc = if ($global:MemOpt_TotalRAM -ge 16) { 1 } else { 0 }
            Set-Registry -Path $mm -Name "LargeSystemCache" -Value $lsc
            Set-Registry -Path $mm -Name "ClearPageFileAtShutdown" -Value 0
            Set-Registry -Path $mm -Name "SessionPoolSize" -Value 48
            
            # Memory Compression
            if ($global:MemOpt_TotalRAM -ge 32) {
                Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
                Write-Host "  - 메모리 압축 비활성화 (32GB+)" -ForegroundColor Green
            } else {
                Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
                Write-Host "  - 메모리 압축 활성화 (<32GB)" -ForegroundColor Green
            }
        }
    },
    @{
        Name = "NDU (Network Data Usage) 메모리 누수 방지"
        Action = {
            Set-Registry -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Ndu" -Name "Start" -Value 4 -Description "NDU 서비스 비활성화"
        }
    }
)

Run-OptimizationSteps -Title "메모리 최적화" -Steps $steps

