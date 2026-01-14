# Windows 11 25H2 One-Click Optimization Script
# Orchestrator for individual optimization scripts

#Requires -RunAsAdministrator

# Script Version
$scriptVersion = "1.2.0"

# UTF-8 Encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Ensure PSScriptRoot is defined
if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    if ($MyInvocation.MyCommand.Path) {
        $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
    } else {
        $PSScriptRoot = Get-Location | Select-Object -ExpandProperty Path
    }
}

# Disable Progress Bar
$ProgressPreference = 'SilentlyContinue'

# Global State
$global:OrchestrateMode = $true
if ($null -eq $global:ForceOverride) { $global:ForceOverride = $false }

# Logging
$global:OrchestrateStartTime = Get-Date
$global:OrchestrateLogDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $global:OrchestrateLogDir)) { New-Item -Path $global:OrchestrateLogDir -ItemType Directory -Force | Out-Null }
$global:OrchestrateLogFile = Join-Path $global:OrchestrateLogDir "Windows11Optimizer_ORCHESTRATE_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$global:ScriptResults = [System.Collections.ArrayList]@()

# Load Core Module (for logging definitions if needed, though Orchestrate uses its own summary)
# Note: Helper scripts will load core.ps1 themselves.

# System Info Collection (for Log)
function Get-SystemInfoForLog {
    $os = Get-CimInstance Win32_OperatingSystem
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    
    return @"
[System Info]
OS: $($os.Caption) Build $($os.BuildNumber)
Computer: $env:COMPUTERNAME
User: $env:USERNAME
RAM: $ramGB GB
Processor: $((Get-CimInstance Win32_Processor).Name)
"@
}

function Add-ScriptResult {
    param($ScriptId, $ScriptName, $Status, $AppliedCount=0, $SkippedCount=0, $FailedCount=0, $Notes="", $Duration="")
    $global:ScriptResults.Add([PSCustomObject]@{
        Id = $ScriptId; Name = $ScriptName; Status = $Status; 
        AppliedCount = $AppliedCount; SkippedCount = $SkippedCount; FailedCount = $FailedCount; 
        Notes = $Notes; Duration = $Duration; Timestamp = Get-Date -Format "HH:mm:ss"
    }) | Out-Null
}

function Save-OrchestrateSummary {
    param($CompletedItems, $FailedItems)
    
    $duration = "{0:hh\:mm\:ss}" -f ((Get-Date) - $global:OrchestrateStartTime)
    $log = @"
================================================================================
Windows 11 Optimization - Orchestrate Summary
================================================================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Duration: $duration
Version: $scriptVersion
ForceOverride: $global:ForceOverride

$(Get-SystemInfoForLog)

================================================================================
Script Results
================================================================================
"@
    foreach ($r in $global:ScriptResults) {
        $log += "`n[$($r.Timestamp)] [$($r.Status)] $($r.Name) (Applied: $($r.AppliedCount), Skipped: $($r.SkippedCount), Failed: $($r.FailedCount))"
        if ($r.Notes) { $log += "`n  Note: $($r.Notes)" }
    }
    
    $log += @"

================================================================================
Totals: Applied: $(($global:ScriptResults | Measure-Object AppliedCount -Sum).Sum) | Skipped: $(($global:ScriptResults | Measure-Object SkippedCount -Sum).Sum) | Failed: $(($global:ScriptResults | Measure-Object FailedCount -Sum).Sum)
================================================================================
"@
    
    $log | Set-Content $global:OrchestrateLogFile -Encoding UTF8
    
    return @{ TotalApplied = ($global:ScriptResults | Measure-Object AppliedCount -Sum).Sum; Duration = $duration }
}

# Define Scripts
$global:ScriptItems = @(
    @{ Id = 1;  File = "001.disable_update.ps1";              Name = "Windows Update 수동 설정";          RequiresReboot = $false; Group = "기본" }
    @{ Id = 2;  File = "002.power_network.ps1";               Name = "전원/네트워크 최적화";               RequiresReboot = $true;  Group = "기본" }
    @{ Id = 3;  File = "003.defender_onedrive_firewall.ps1";  Name = "OneDrive/방화벽 설정";              RequiresReboot = $false; Group = "기본" }
    @{ Id = 4;  File = "004.taskbar.ps1";                     Name = "작업 표시줄/컨텍스트 메뉴";          RequiresReboot = $false; Group = "기본" }
    @{ Id = 5;  File = "005.bloatware.ps1";                   Name = "블로트웨어 제거";                    RequiresReboot = $false; Group = "기본" }
    @{ Id = 6;  File = "006.software_install.ps1";            Name = "필수 소프트웨어 설치";               RequiresReboot = $false; Group = "기본" }
    @{ Id = 7;  File = "007.openssh_rsync.ps1";               Name = "OpenSSH 및 Rsync 설정";             RequiresReboot = $false; Group = "서버" }
    @{ Id = 8;  File = "008.common_optimization.ps1";         Name = "공통 최적화 (DNS/서비스)";           RequiresReboot = $true;  Group = "기본" }
    @{ Id = 9;  File = "009.gaming_optimization.ps1";         Name = "게임용 최적화 (VBS/GPU)";           RequiresReboot = $true;  Group = "게임" }
    @{ Id = 10; File = "010.game_server.ps1";                 Name = "게임 서버 최적화 (TCP/UDP)";         RequiresReboot = $true;  Group = "서버" }
    @{ Id = 11; File = "011.web_server.ps1";                  Name = "웹 서버 IIS 최적화";                 RequiresReboot = $true;  Group = "서버" }
    @{ Id = 12; File = "012.ai_features.ps1";                 Name = "25H2 AI 기능 비활성화";              RequiresReboot = $true;  Group = "25H2" }
    @{ Id = 13; File = "013.privacy_optimization.ps1";        Name = "개인정보 보호 강화";                 RequiresReboot = $true;  Group = "기본" }
    @{ Id = 14; File = "014.storage_optimization.ps1";        Name = "Storage 자동 정리";                  RequiresReboot = $false; Group = "기본" }
    @{ Id = 15; File = "015.startup_optimization.ps1";        Name = "시작 프로그램 최적화";               RequiresReboot = $true;  Group = "기본" }
    @{ Id = 16; File = "016.accessibility_cleanup.ps1";       Name = "접근성 단축키 정리";                 RequiresReboot = $false; Group = "기본" }
    @{ Id = 17; File = "017.mouse_input_optimization.ps1";    Name = "마우스/입력 장치 최적화";            RequiresReboot = $false; Group = "게임" }
    @{ Id = 18; File = "018.memory_optimization.ps1";         Name = "메모리 최적화";                      RequiresReboot = $true;  Group = "기본" }
    @{ Id = 19; File = "019.search_optimization.ps1";         Name = "Windows Search 최적화";              RequiresReboot = $false; Group = "기본" }
    @{ Id = 20; File = "020.registry_tweaks.ps1";             Name = "레지스트리 미세 조정";               RequiresReboot = $true;  Group = "기본" }
    @{ Id = 21; File = "021.ntfs_ssd_optimization.ps1";       Name = "NTFS/SSD 최적화";                   RequiresReboot = $true;  Group = "기본" }
    @{ Id = 22; File = "022.advanced_gaming_optimization.ps1"; Name = "고급 게임 최적화";                  RequiresReboot = $true;  Group = "게임" }
)

# Presets
$global:Presets = @{
    "기본"   = @(1, 2, 3, 4, 5, 6, 8, 12, 13, 14, 15, 16, 18, 19, 20, 21)
    "게임"   = @(1, 2, 3, 4, 5, 6, 8, 9, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22)
    "서버"   = @(1, 2, 3, 7, 8, 10, 18, 20, 21)
    "웹서버" = @(1, 2, 3, 7, 8, 11, 18, 20, 21)
}

$global:ExperimentalFeatures = @(
    @{ ScriptId = 21; Name = "Native NVMe 지원"; Variable = "EnableNativeNVMe"; Description = "Windows 11 25H2 실험적 기능"; Warning = "호환성 주의"; Default = $false }
)
$global:ExperimentalOptions = @{}

# Execution Function
function Invoke-OptimizationScript {
    param($ScriptId)
    
    $item = $global:ScriptItems | Where-Object { $_.Id -eq $ScriptId }
    if (!$item) { return }
    
    Write-Host "`n=== [$($item.Id)] $($item.Name) 실행 중... ===" -ForegroundColor Yellow
    
    # Reset counters (accessed by core.ps1)
    $global:AppliedCount = 0
    $global:SkippedCount = 0
    $global:FailedCount = 0
    
    $start = Get-Date
    try {
        $localPath = Join-Path $PSScriptRoot $item.File
        if (Test-Path $localPath) {
            . $localPath
        } else {
            Write-Warning "File not found: $localPath"
            throw "File not found"
        }
        
        $dur = "{0:mm\:ss}" -f ((Get-Date) - $start)
        Add-ScriptResult -ScriptId $item.Id -ScriptName $item.Name -Status "완료" `
            -AppliedCount $global:AppliedCount -SkippedCount $global:SkippedCount -FailedCount $global:FailedCount -Duration $dur
            
        return @{ Success = $true; Applied = $global:AppliedCount }
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        Add-ScriptResult -ScriptId $item.Id -ScriptName $item.Name -Status "실패" -FailedCount 1 -Notes "$_"
        return @{ Success = $false }
    }
}

# Parallel Execution (Simplified to Sequential for reliability in this refactor, or preserve parallel if needed)
# Since core.ps1 uses global log entries, parallel execution within the SAME process is dangerous unless we use jobs.
# The original script used Start-Job. That creates a separate process, which is good.
# But jobs need to know about core.ps1 too.
# If we dot-source local files in jobs, we need to ensure they can find core.ps1.
# The simpler approach for the user is sequential execution to see the output clearly, OR carefully managed jobs.
# Given complexity, I will stick to SEQUENTIAL execution for reliability in this version, unless speed is critical.
# Parallel is nice but complex to debug.
# I will implement Sequential for now to ensure stability.

function Start-OptimizationProcess {
    param($State)
    $pending = $State.PendingItems
    $completed = @()
    $failed = @()
    
    # Check Reboot items vs Non-Reboot?
    # Simple sort by ID is usually fine, but grouping by reboot requirement is good.
    
    $rebootItems = @()
    $noRebootItems = @()
    foreach ($id in $pending) {
        $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
        if ($item.RequiresReboot) { $rebootItems += $id } else { $noRebootItems += $id }
    }
    
    # Execute NoReboot first
    foreach ($id in $noRebootItems) {
        $res = Invoke-OptimizationScript -ScriptId $id
        if ($res.Success) { $completed += $id } else { $failed += $id }
    }
    
    # Execute Reboot items
    foreach ($id in $rebootItems) {
        $res = Invoke-OptimizationScript -ScriptId $id
        if ($res.Success) { $completed += $id } else { $failed += $id }
    }
    
    # Summary
    $stats = Save-OrchestrateSummary -CompletedItems $completed -FailedItems $failed
    
    Write-Host "`n=== 최적화 완료 ===" -ForegroundColor Cyan
    Write-Host "적용: $($stats.TotalApplied) | 실패: $($stats.TotalFailed)" -ForegroundColor Yellow
    Write-Host "로그: $global:OrchestrateLogFile" -ForegroundColor Gray
    
    if ($rebootItems.Count -gt 0) {
        Write-Host "`n재부팅이 필요한 항목이 있습니다." -ForegroundColor Red
        if ((Read-Host "지금 재부팅하시겠습니까? (Y/N)") -eq 'Y') {
            Restart-Computer -Force
        }
    }
}

# UI / Menu Functions
function Show-Menu {
    param($Selected)
    Clear-Host
    Write-Host "Windows 11 Optimization Orchestrator v$scriptVersion" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
    foreach ($item in $global:ScriptItems) {
        $mark = if ($Selected[$item.Id]) { "[X]" } else { "[ ]" }
        $col = if ($Selected[$item.Id]) { "Green" } else { "White" }
        Write-Host "$($item.Id.ToString().PadLeft(2)) $mark $($item.Name)" -ForegroundColor $col
    }
    Write-Host "--------------------------------------------------" -ForegroundColor Gray
    Write-Host "[A] All  [N] None  [B] Basic  [G] Game  [S] Server" -ForegroundColor Yellow
    Write-Host "[R] Run  [Q] Quit" -ForegroundColor Yellow
}

# Main Loop
$selected = @{}
while ($true) {
    Show-Menu -Selected $selected
    $in = Read-Host "선택"
    switch ($in.ToUpper()) {
        "A" { $global:ScriptItems | ForEach-Object { $selected[$_.Id] = $true } }
        "N" { $selected.Clear() }
        "B" { $selected.Clear(); $global:Presets["기본"] | ForEach-Object { $selected[$_] = $true } }
        "G" { $selected.Clear(); $global:Presets["게임"] | ForEach-Object { $selected[$_] = $true } }
        "S" { $selected.Clear(); $global:Presets["서버"] | ForEach-Object { $selected[$_] = $true } }
        "Q" { exit }
        "R" {
            if ($selected.Count -eq 0) { continue }
            
            # Experimental
            if ($selected[21]) {
                # Ask NVMe
                 if ((Read-Host "Enable Native NVMe (Experimental)? (Y/N)") -eq 'Y') {
                     $global:ExperimentalOptions["EnableNativeNVMe"] = $true
                 }
            }
            
            Start-OptimizationProcess -State @{ PendingItems = $selected.Keys | Sort-Object }
            exit
        }
        default {
            if ($in -match "^\d+$" -and ($item = $global:ScriptItems | Where-Object Id -eq $in)) {
                if ($selected[$item.Id]) { $selected.Remove($item.Id) } else { $selected[$item.Id] = $true }
            }
        }
    }
}
