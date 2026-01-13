# Windows 11 25H2 원클릭 최적화 스크립트
# 모든 최적화 항목을 대화형 메뉴로 선택하여 실행
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.5"

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Progress Bar 비활성화 (병렬 실행 시 출력 겹침 방지)
$ProgressPreference = 'SilentlyContinue'

# Orchestrate 모드 플래그 설정
$global:OrchestrateMode = $true

# ForceOverride 플래그 (true 시 이미 적용된 설정도 강제 재적용)
if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

# ===== Orchestrate 전용 Summary 로깅 시스템 =====
$global:OrchestrateStartTime = Get-Date
$global:OrchestrateLogDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $global:OrchestrateLogDir)) { New-Item -Path $global:OrchestrateLogDir -ItemType Directory -Force | Out-Null }
$global:OrchestrateLogFile = Join-Path $global:OrchestrateLogDir "Windows11Optimizer_ORCHESTRATE_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# 전체 실행 결과 수집용 (스크립트별 Summary)
$global:ScriptResults = [System.Collections.ArrayList]@()

# 시스템 정보 수집 (상세)
function Get-SystemInfoForLog {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $gpu = (Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1).Name

    # 메모리 용량 기반 분기 정보
    $memoryCategory = if ($ramGB -ge 32) { "대용량 (32GB+) - Prefetch 비활성화 권장" }
                      elseif ($ramGB -ge 16) { "중간 (16-31GB) - SysMain 조건부 비활성화" }
                      else { "소용량 (<16GB) - SysMain/Prefetch 유지 권장" }

    $systemInfo = @"
[시스템 정보]
- OS: $($os.Caption) Build $($os.BuildNumber)
- CPU: $($cpu.Name)
- RAM: ${ramGB} GB
- RAM 분기: $memoryCategory
- GPU: $gpu
- 컴퓨터 이름: $env:COMPUTERNAME
- 사용자: $env:USERNAME
"@
    return $systemInfo
}

# 드라이브 정보 수집 (상세 - NVMe/SATA 구분)
function Get-DriveInfoForLog {
    $driveInfo = "[드라이브 정보]`n"

    # 물리 디스크 정보
    $physicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    if ($physicalDisks) {
        foreach ($disk in $physicalDisks) {
            $mediaType = switch ($disk.MediaType) {
                "SSD" { "SSD" }
                "HDD" { "HDD" }
                "Unspecified" { "알 수 없음" }
                default { $disk.MediaType }
            }
            $sizeGB = [math]::Round($disk.Size / 1GB, 0)

            # 버스 타입 확인 (NVMe vs SATA)
            $busType = switch ($disk.BusType) {
                "NVMe" { "NVMe" }
                "SATA" { "SATA" }
                "USB" { "USB" }
                "RAID" { "RAID" }
                default { $disk.BusType }
            }

            # NVMe/SATA 분기 정보
            $busNote = if ($busType -eq "NVMe") { " (Native NVMe 드라이버 적용 가능)" }
                       elseif ($busType -eq "SATA" -and $mediaType -eq "SSD") { " (SATA SSD - TRIM 활성화)" }
                       elseif ($busType -eq "SATA" -and $mediaType -eq "HDD") { " (SATA HDD - Prefetch 유지 권장)" }
                       else { "" }

            $driveInfo += "- $($disk.FriendlyName): $mediaType ($busType), ${sizeGB}GB$busNote`n"
        }
    }

    # SSD 존재 여부 요약
    $hasSSD = ($physicalDisks | Where-Object { $_.MediaType -eq "SSD" }).Count -gt 0
    $hasNVMe = ($physicalDisks | Where-Object { $_.BusType -eq "NVMe" }).Count -gt 0
    $hasHDD = ($physicalDisks | Where-Object { $_.MediaType -eq "HDD" }).Count -gt 0

    $driveInfo += "`n[드라이브 분기 결정]`n"
    $driveInfo += "- SSD 감지: $(if ($hasSSD) { "예 - Last Access Time 비활성화, Prefetch 조정" } else { "아니오" })`n"
    $driveInfo += "- NVMe 감지: $(if ($hasNVMe) { "예 - Native NVMe 드라이버 활성화 가능" } else { "아니오" })`n"
    $driveInfo += "- HDD 감지: $(if ($hasHDD) { "예 - Prefetch/Superfetch 유지 권장" } else { "아니오" })`n"

    return $driveInfo.TrimEnd()
}

# 전역 시스템 분기 정보 저장 (스크립트들이 참조)
$global:SystemProfile = @{
    RamGB = [math]::Round((Get-CimInstance -ClassName Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)
    HasSSD = $false
    HasNVMe = $false
    HasHDD = $false
}

# 드라이브 정보 미리 로드
$physicalDisksInit = Get-PhysicalDisk -ErrorAction SilentlyContinue
if ($physicalDisksInit) {
    $global:SystemProfile.HasSSD = ($physicalDisksInit | Where-Object { $_.MediaType -eq "SSD" }).Count -gt 0
    $global:SystemProfile.HasNVMe = ($physicalDisksInit | Where-Object { $_.BusType -eq "NVMe" }).Count -gt 0
    $global:SystemProfile.HasHDD = ($physicalDisksInit | Where-Object { $_.MediaType -eq "HDD" }).Count -gt 0
}

# 스크립트 실행 결과 기록
function Add-ScriptResult {
    param(
        [int]$ScriptId,
        [string]$ScriptName,
        [string]$Status,  # "완료", "실패", "스킵"
        [int]$AppliedCount = 0,
        [int]$SkippedCount = 0,
        [int]$FailedCount = 0,
        [string]$Notes = "",
        [string]$Duration = ""
    )

    $result = [PSCustomObject]@{
        Id = $ScriptId
        Name = $ScriptName
        Status = $Status
        AppliedCount = $AppliedCount
        SkippedCount = $SkippedCount
        FailedCount = $FailedCount
        Notes = $Notes
        Duration = $Duration
        Timestamp = Get-Date -Format "HH:mm:ss"
    }

    [void]$global:ScriptResults.Add($result)
}

# 전체 Summary 저장
function Save-OrchestrateSummary {
    param(
        [array]$CompletedItems,
        [array]$FailedItems,
        [array]$SkippedItems
    )

    $endTime = Get-Date
    $totalDuration = $endTime - $global:OrchestrateStartTime
    $durationStr = "{0:hh\:mm\:ss}" -f $totalDuration

    $systemInfo = Get-SystemInfoForLog
    $driveInfo = Get-DriveInfoForLog

    # 전체 통계 계산
    $totalApplied = ($global:ScriptResults | Measure-Object -Property AppliedCount -Sum).Sum
    $totalSkipped = ($global:ScriptResults | Measure-Object -Property SkippedCount -Sum).Sum
    $totalFailed = ($global:ScriptResults | Measure-Object -Property FailedCount -Sum).Sum

    $logContent = @"
================================================================================
Windows 11 Optimization - Orchestrate Summary Log
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
총 소요 시간: $durationStr
스크립트: 000.orchestrate.ps1 v$scriptVersion
ForceOverride: $($global:ForceOverride)
================================================================================

$systemInfo

$driveInfo

================================================================================
스크립트별 실행 결과
================================================================================

"@

    foreach ($result in $global:ScriptResults) {
        $statusColor = switch ($result.Status) {
            "완료" { "[성공]" }
            "실패" { "[실패]" }
            "스킵" { "[스킵]" }
            default { "[$($result.Status)]" }
        }

        $logContent += @"
[$($result.Timestamp)] [$($result.Id.ToString().PadLeft(2, '0'))] $($result.Name)
  상태: $statusColor
  적용됨: $($result.AppliedCount) | 스킵됨: $($result.SkippedCount) | 실패: $($result.FailedCount)

"@
        if ($result.Notes) {
            $logContent += "  비고: $($result.Notes)`n"
        }
        $logContent += "`n"
    }

    $logContent += @"
================================================================================
실행 항목 요약
================================================================================
[완료된 스크립트] ($($CompletedItems.Count) 개)
"@

    foreach ($id in $CompletedItems) {
        $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
        $logContent += "  - [$id] $($item.Name)`n"
    }

    if ($SkippedItems.Count -gt 0) {
        $logContent += "`n[사용자 미선택 스크립트] ($($SkippedItems.Count) 개)`n"
        foreach ($id in $SkippedItems) {
            $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
            $logContent += "  - [$id] $($item.Name)`n"
        }
    }

    if ($FailedItems.Count -gt 0) {
        $logContent += "`n[실패한 스크립트] ($($FailedItems.Count) 개)`n"
        foreach ($id in $FailedItems) {
            $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
            $logContent += "  - [$id] $($item.Name)`n"
        }
    }

    # 시스템 분기에 따른 자동 결정 사항 (실시간 조회)
    $currentRamGB = [math]::Round((Get-CimInstance -ClassName Win32_OperatingSystem).TotalVisibleMemorySize / 1MB, 1)
    $currentDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue
    $currentHasNVMe = ($currentDisks | Where-Object { $_.BusType -eq "NVMe" }).Count -gt 0
    $currentHasSSD = ($currentDisks | Where-Object { $_.MediaType -eq "SSD" }).Count -gt 0
    $currentHasHDD = ($currentDisks | Where-Object { $_.MediaType -eq "HDD" }).Count -gt 0

    $logContent += @"

================================================================================
시스템 분기에 따른 자동 결정 사항
================================================================================
[메모리 기반 분기]
- RAM 용량: $currentRamGB GB
- SysMain/Prefetch: $(
    if ($currentRamGB -ge 32) { "비활성화 (대용량 RAM으로 불필요)" }
    elseif ($currentRamGB -ge 16) { "SysMain 비활성화, Prefetch 부팅만" }
    else { "활성화 유지 (소용량 RAM)" }
)
- 페이지 파일: $(
    if ($currentRamGB -ge 32) { "8-16GB 권장" }
    elseif ($currentRamGB -ge 16) { "16-32GB 권장" }
    else { "RAM의 1.5-3배 권장" }
)
- Large System Cache: $(if ($currentRamGB -ge 16) { "활성화 (RAM 16GB+)" } else { "비활성화" })

[드라이브 기반 분기]
- NVMe 드라이브: $(if ($currentHasNVMe) { "감지됨 - Native NVMe 드라이버 활성화, SysMain 비활성화" } else { "미감지" })
- SATA SSD: $(if ($currentHasSSD -and -not $currentHasNVMe) { "감지됨 - Last Access Time 비활성화, TRIM 활성화" } else { "미감지" })
- HDD: $(if ($currentHasHDD) { "감지됨 - Prefetch/Superfetch 유지, 디스크 조각모음 예약" } else { "미감지" })

[ForceOverride 설정]
- 상태: $(if ($global:ForceOverride) { "활성화 - 모든 설정 강제 재적용" } else { "비활성화 - 이미 적용된 설정 스킵" })
"@

    $logContent += @"

================================================================================
전체 통계 (모든 스크립트 합산)
================================================================================
총 설정 항목: $($totalApplied + $totalSkipped + $totalFailed) 개
  - 적용됨: $totalApplied 개
  - 스킵됨: $totalSkipped 개 (이미 최적 설정)
  - 실패: $totalFailed 개

================================================================================
로그 파일: $global:OrchestrateLogFile
================================================================================
"@

    $logContent | Set-Content -Path $global:OrchestrateLogFile -Encoding UTF8
    return @{
        TotalApplied = $totalApplied
        TotalSkipped = $totalSkipped
        TotalFailed = $totalFailed
        Duration = $durationStr
    }
}

# Summary 콘솔 출력
function Show-OrchestrateSummary {
    param(
        [array]$CompletedItems,
        [array]$FailedItems
    )

    $stats = Save-OrchestrateSummary -CompletedItems $CompletedItems -FailedItems $FailedItems -SkippedItems @()

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  전체 최적화 Summary" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " 총 소요 시간: $($stats.Duration)" -ForegroundColor White
    Write-Host ""
    Write-Host " [스크립트별 결과]" -ForegroundColor Yellow
    Write-Host " ------------------------------------------------" -ForegroundColor Gray

    foreach ($result in $global:ScriptResults) {
        $statusIcon = switch ($result.Status) {
            "완료" { "[V]" }
            "실패" { "[X]" }
            "스킵" { "[-]" }
            default { "[?]" }
        }
        $statusColor = switch ($result.Status) {
            "완료" { "Green" }
            "실패" { "Red" }
            "스킵" { "Gray" }
            default { "White" }
        }

        $idStr = $result.Id.ToString().PadLeft(2)
        $nameStr = $result.Name.PadRight(28)
        $statsStr = "적용:$($result.AppliedCount) 스킵:$($result.SkippedCount) 실패:$($result.FailedCount)"

        Write-Host " $statusIcon $idStr. $nameStr $statsStr" -ForegroundColor $statusColor
    }

    Write-Host " ------------------------------------------------" -ForegroundColor Gray
    Write-Host ""
    Write-Host " [전체 통계]" -ForegroundColor Yellow
    Write-Host "  - 적용됨: $($stats.TotalApplied) 개" -ForegroundColor Green
    Write-Host "  - 스킵됨: $($stats.TotalSkipped) 개 (이미 최적 설정)" -ForegroundColor Gray
    Write-Host "  - 실패: $($stats.TotalFailed) 개" -ForegroundColor Red
    Write-Host ""
    Write-Host " 로그 파일: $global:OrchestrateLogFile" -ForegroundColor Cyan
    Write-Host ""
}

# 상태 저장 경로 정의
$global:StateFilePath = "$env:LOCALAPPDATA\Windows11Optimizer\state.json"
$global:ScriptBaseUrl = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts"

# 스크립트 정의 (순서, 파일명, 설명, 재부팅 필요 여부, 그룹)
$global:ScriptItems = @(
    @{ Id = 1;  File = "001.disable_update.ps1";              Name = "Windows Update 수동 설정";          RequiresReboot = $false; Group = "기본" }
    @{ Id = 2;  File = "002.power_network.ps1";               Name = "전원/네트워크 최적화";               RequiresReboot = $true;  Group = "기본" }
    @{ Id = 3;  File = "003.defender_onedrive_firewall.ps1";  Name = "OneDrive/방화벽 설정";              RequiresReboot = $false; Group = "기본" }
    @{ Id = 4;  File = "004.taskbar.ps1";                     Name = "작업 표시줄/컨텍스트 메뉴";          RequiresReboot = $false; Group = "기본" }
    @{ Id = 5;  File = "005.bloatware.ps1";                   Name = "블로트웨어 제거";                    RequiresReboot = $false; Group = "기본" }
    @{ Id = 6;  File = "006.software_install.ps1";            Name = "필수 소프트웨어 설치";               RequiresReboot = $false; Group = "기본" }
    @{ Id = 8;  File = "008.common_optimization.ps1";         Name = "공통 최적화 (DNS/서비스/부팅)";      RequiresReboot = $true;  Group = "기본" }
    @{ Id = 9;  File = "009.gaming_optimization.ps1";         Name = "게임용 최적화 (VBS/GPU)";           RequiresReboot = $true;  Group = "게임" }
    @{ Id = 10; File = "010.game_server.ps1";                 Name = "게임 서버 최적화 (TCP/UDP)";         RequiresReboot = $true;  Group = "서버" }
    @{ Id = 11; File = "011.web_server.ps1";                  Name = "웹 서버 IIS 최적화";                 RequiresReboot = $true;  Group = "서버" }
    @{ Id = 12; File = "012.ai_features.ps1";                 Name = "25H2 AI 기능 비활성화";              RequiresReboot = $true;  Group = "25H2" }
    @{ Id = 13; File = "013.privacy_optimization.ps1";       Name = "개인정보 보호 강화";                 RequiresReboot = $true;  Group = "기본" }
    @{ Id = 14; File = "014.storage_optimization.ps1";       Name = "Storage 자동 정리";                  RequiresReboot = $false; Group = "기본" }
    @{ Id = 15; File = "015.startup_optimization.ps1";       Name = "시작 프로그램 최적화";               RequiresReboot = $true;  Group = "기본" }
    @{ Id = 16; File = "016.accessibility_cleanup.ps1";      Name = "접근성 단축키 정리";                 RequiresReboot = $false; Group = "기본" }
    @{ Id = 17; File = "017.mouse_input_optimization.ps1";  Name = "마우스/입력 장치 최적화";            RequiresReboot = $false; Group = "게임" }
    @{ Id = 18; File = "018.memory_optimization.ps1";       Name = "메모리 최적화";                      RequiresReboot = $true;  Group = "기본" }
    @{ Id = 19; File = "019.search_optimization.ps1";       Name = "Windows Search 최적화";              RequiresReboot = $false; Group = "기본" }
    @{ Id = 20; File = "020.registry_tweaks.ps1";           Name = "레지스트리 미세 조정";               RequiresReboot = $true;  Group = "기본" }
    @{ Id = 21; File = "021.ntfs_ssd_optimization.ps1";    Name = "NTFS/SSD 최적화";                   RequiresReboot = $true;  Group = "기본" }
    @{ Id = 22; File = "022.advanced_gaming_optimization.ps1"; Name = "고급 게임 최적화";              RequiresReboot = $true;  Group = "게임" }
)

# 프리셋 정의
$global:Presets = @{
    "기본"   = @(1, 2, 3, 4, 5, 6, 8, 12, 13, 14, 15, 16, 18, 19, 20, 21)              # 기본 최적화 + AI 비활성화 + NTFS/SSD
    "게임"   = @(1, 2, 3, 4, 5, 6, 8, 9, 12, 13, 14, 15, 16, 17, 18, 20, 21, 22)       # 게임용 PC + 고급 게임 최적화
    "서버"   = @(1, 2, 3, 8, 10, 18, 20, 21)                                            # 게임 서버용 + NTFS/SSD
    "웹서버" = @(1, 2, 3, 8, 11, 18, 20, 21)                                            # 웹 서버용 + NTFS/SSD
}

# 동시 실행 불가능한 스크립트 쌍 정의 (리소스 충돌)
$global:ConflictGroups = @(
    @(4, 5),    # taskbar ↔ bloatware (explorer/AppX 충돌)
    @(8, 12),   # common ↔ ai_features (ContentDeliveryManager 충돌)
    @(9, 10),   # gaming ↔ game_server (NetworkThrottlingIndex 충돌)
    @(6, 1, 3, 4, 5, 14, 16)  # software_install 단독 실행 (Add-Type/Start-Process Job 비호환)
)

# 실험적 기능 정의 (스크립트별)
$global:ExperimentalFeatures = @(
    @{
        ScriptId = 21  # ntfs_ssd_optimization.ps1
        Name = "Native NVMe 지원"
        Description = "Windows 11 25H2 실험적 기능 - 최대 80% IOPS 향상"
        Warning = "일부 NVMe 드라이브에서 호환성 문제 가능"
        Variable = "EnableNativeNVMe"
        Default = $false
    }
)

# 실험적 기능 선택 결과 저장 (글로벌)
$global:ExperimentalOptions = @{}


# ===== 상태 관리 함수 =====

function Save-State {
    param(
        [array]$PendingItems,
        [array]$CompletedItems,
        [int]$CurrentIndex,
        [bool]$NeedsReboot
    )

    $stateDir = Split-Path $global:StateFilePath -Parent
    if (!(Test-Path $stateDir)) {
        New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
    }

    $state = @{
        PendingItems = $PendingItems
        CompletedItems = $CompletedItems
        CurrentIndex = $CurrentIndex
        NeedsReboot = $NeedsReboot
        Timestamp = (Get-Date).ToString("o")
    }

    $state | ConvertTo-Json | Set-Content -Path $global:StateFilePath -Encoding UTF8
}

function Get-SavedState {
    if (Test-Path $global:StateFilePath) {
        try {
            $content = Get-Content -Path $global:StateFilePath -Raw -Encoding UTF8
            return $content | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Clear-State {
    if (Test-Path $global:StateFilePath) {
        Remove-Item -Path $global:StateFilePath -Force
    }
    Unregister-RunOnce
}

function Register-RunOnce {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $scriptUrl = "$global:ScriptBaseUrl/000.orchestrate.ps1"

    # PowerShell 창을 열어서 스크립트 계속 실행
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"irm '$scriptUrl' | iex`""

    Set-ItemProperty -Path $regPath -Name "Windows11Optimizer" -Value $command -Type String
}

function Unregister-RunOnce {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    Remove-ItemProperty -Path $regPath -Name "Windows11Optimizer" -ErrorAction SilentlyContinue
}


# ===== 메뉴 UI 함수 =====

function Show-SystemInfo {
    Write-Host ""
    Write-Host " [시스템 정보]" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------" -ForegroundColor Gray

    # RAM 정보
    $ramInfo = if ($global:SystemProfile.RamGB -ge 32) { "$(($global:SystemProfile.RamGB)) GB (대용량)" }
               elseif ($global:SystemProfile.RamGB -ge 16) { "$(($global:SystemProfile.RamGB)) GB (중간)" }
               else { "$(($global:SystemProfile.RamGB)) GB (소용량)" }
    Write-Host " RAM: $ramInfo" -ForegroundColor White

    # 드라이브 정보
    $driveInfo = @()
    if ($global:SystemProfile.HasNVMe) { $driveInfo += "NVMe" }
    if ($global:SystemProfile.HasSSD -and -not $global:SystemProfile.HasNVMe) { $driveInfo += "SATA SSD" }
    if ($global:SystemProfile.HasHDD) { $driveInfo += "HDD" }
    $driveStr = if ($driveInfo.Count -gt 0) { $driveInfo -join ", " } else { "감지 안됨" }
    Write-Host " 드라이브: $driveStr" -ForegroundColor White

    # ForceOverride 상태
    $forceStr = if ($global:ForceOverride) { "활성화 (모든 설정 강제 재적용)" } else { "비활성화 (이미 적용된 설정 스킵)" }
    $forceColor = if ($global:ForceOverride) { "Yellow" } else { "Gray" }
    Write-Host " ForceOverride: $forceStr" -ForegroundColor $forceColor
    Write-Host " ------------------------------------------------" -ForegroundColor Gray
}

function Show-Menu {
    param([hashtable]$SelectedItems)

    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  Windows 11 25H2 원클릭 최적화 스크립트 v$scriptVersion" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan

    # 시스템 정보 표시
    Show-SystemInfo

    Write-Host ""
    Write-Host " 숫자를 눌러 항목을 선택/해제하세요 (체크박스 토글)" -ForegroundColor White
    Write-Host ""
    Write-Host " ------------------------------------------------" -ForegroundColor Gray

    foreach ($item in $global:ScriptItems) {
        $checkbox = if ($SelectedItems[$item.Id]) { "[X]" } else { "[ ]" }
        $rebootMark = if ($item.RequiresReboot) { "*" } else { " " }
        $groupTag = "[$($item.Group)]"

        $color = if ($SelectedItems[$item.Id]) { "Green" } else { "White" }
        $idStr = $item.Id.ToString().PadLeft(2)
        Write-Host " $idStr. $checkbox $($item.Name.PadRight(32))$rebootMark $groupTag" -ForegroundColor $color
    }

    Write-Host " ------------------------------------------------" -ForegroundColor Gray
    Write-Host ""
    Write-Host " * = 재부팅 필요 항목" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " [A] 전체 선택      [N] 전체 해제" -ForegroundColor Cyan
    Write-Host " [B] 기본 프리셋    [G] 게임 프리셋" -ForegroundColor Cyan
    Write-Host " [S] 서버 프리셋    [W] 웹서버 프리셋" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [F] ForceOverride 토글 (현재: $(if ($global:ForceOverride) { 'ON' } else { 'OFF' }))" -ForegroundColor $(if ($global:ForceOverride) { 'Yellow' } else { 'Gray' })
    Write-Host ""
    Write-Host " [R] 실행 시작      [Q] 종료" -ForegroundColor Yellow
    Write-Host ""
}

function Get-UserSelection {
    $selected = @{}

    while ($true) {
        Show-Menu -SelectedItems $selected
        $key = Read-Host "선택"

        switch ($key.ToUpper()) {
            "A" {
                foreach ($item in $global:ScriptItems) {
                    $selected[$item.Id] = $true
                }
            }
            "N" {
                $selected = @{}
            }
            "B" {
                $selected = @{}
                foreach ($id in $global:Presets["기본"]) {
                    $selected[$id] = $true
                }
            }
            "G" {
                $selected = @{}
                foreach ($id in $global:Presets["게임"]) {
                    $selected[$id] = $true
                }
            }
            "S" {
                $selected = @{}
                foreach ($id in $global:Presets["서버"]) {
                    $selected[$id] = $true
                }
            }
            "W" {
                $selected = @{}
                foreach ($id in $global:Presets["웹서버"]) {
                    $selected[$id] = $true
                }
            }
            "R" {
                if ($selected.Count -gt 0) {
                    $sortedIds = $selected.Keys | Sort-Object
                    return @{
                        SelectedItems = $selected
                        PendingItems = [array]$sortedIds
                        CompletedItems = @()
                        CurrentIndex = 0
                    }
                } else {
                    Write-Host ""
                    Write-Host "하나 이상의 항목을 선택하세요." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
            "Q" {
                Write-Host ""
                Write-Host "종료합니다." -ForegroundColor Yellow
                exit
            }
            "F" {
                # ForceOverride 토글
                $global:ForceOverride = -not $global:ForceOverride
                if ($global:ForceOverride) {
                    Write-Host ""
                    Write-Host "ForceOverride 활성화: 이미 적용된 설정도 강제로 재적용합니다." -ForegroundColor Yellow
                } else {
                    Write-Host ""
                    Write-Host "ForceOverride 비활성화: 이미 적용된 설정은 스킵합니다." -ForegroundColor Gray
                }
                Start-Sleep -Seconds 1
            }
            default {
                $num = 0
                if ([int]::TryParse($key, [ref]$num) -and $num -ge 1 -and $num -le 22) {
                    if ($selected[$num]) {
                        $selected.Remove($num)
                    } else {
                        $selected[$num] = $true
                    }
                }
            }
        }
    }
}


# ===== 배치 생성 함수 =====

function Get-ExecutionBatches {
    param([array]$ScriptIds)

    $batches = @()
    $remaining = [System.Collections.ArrayList]@($ScriptIds)

    while ($remaining.Count -gt 0) {
        $batch = @()
        $toRemove = @()

        foreach ($id in $remaining) {
            $canAdd = $true

            # 현재 배치의 다른 스크립트와 충돌 체크
            foreach ($batchId in $batch) {
                foreach ($group in $global:ConflictGroups) {
                    if (($group -contains $id) -and ($group -contains $batchId)) {
                        $canAdd = $false
                        break
                    }
                }
                if (-not $canAdd) { break }
            }

            if ($canAdd) {
                $batch += $id
                $toRemove += $id
            }
        }

        foreach ($id in $toRemove) {
            $remaining.Remove($id) | Out-Null
        }

        if ($batch.Count -gt 0) {
            $batches += ,@($batch)
        }
    }

    return $batches
}

# 실험적 기능 선택 함수
function Get-ExperimentalOptions {
    param([array]$SelectedIds)

    # 선택된 스크립트에 해당하는 실험적 기능 필터링
    $relevantFeatures = $global:ExperimentalFeatures | Where-Object {
        $SelectedIds -contains $_.ScriptId
    }

    if ($relevantFeatures.Count -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host "  실험적 기능 설정" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " 선택한 스크립트에 실험적 기능이 포함되어 있습니다." -ForegroundColor White
    Write-Host " 활성화할 기능을 선택하세요 (기본값: 비활성화)" -ForegroundColor Gray
    Write-Host ""

    foreach ($feature in $relevantFeatures) {
        Write-Host " ------------------------------------------------" -ForegroundColor Gray
        Write-Host " $($feature.Name)" -ForegroundColor Cyan
        Write-Host "   설명: $($feature.Description)" -ForegroundColor Green
        Write-Host "   경고: $($feature.Warning)" -ForegroundColor Red
        Write-Host ""

        $choice = Read-Host "   활성화하시겠습니까? (Y/N, 기본값: N)"
        if ($choice -eq "Y" -or $choice -eq "y") {
            $global:ExperimentalOptions[$feature.Variable] = $true
            Write-Host "   → 활성화됨" -ForegroundColor Green
        } else {
            $global:ExperimentalOptions[$feature.Variable] = $false
            Write-Host "   → 비활성화됨 (기본값)" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    Write-Host " ------------------------------------------------" -ForegroundColor Gray
    Write-Host ""
    Start-Sleep -Seconds 1
}


# ===== 스크립트 실행 함수 =====

function Invoke-OptimizationScript {
    param([int]$ScriptId)

    $item = $global:ScriptItems | Where-Object { $_.Id -eq $ScriptId }
    if (-not $item) { return @{ Success = $false; AppliedCount = 0; SkippedCount = 0; FailedCount = 0 } }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[$($item.Id)/$($global:ScriptItems.Count)] $($item.Name) 실행 중..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    # 스크립트 실행 전 카운터 초기화 (개별 스크립트의 카운터를 가져오기 위해)
    $global:AppliedCount = 0
    $global:SkippedCount = 0
    $global:FailedCount = 0

    $startTime = Get-Date

    try {
        $scriptUrl = "$global:ScriptBaseUrl/$($item.File)"
        $scriptContent = Invoke-RestMethod $scriptUrl
        Invoke-Expression $scriptContent

        $endTime = Get-Date
        $duration = "{0:mm\:ss}" -f ($endTime - $startTime)

        # 스크립트 실행 결과 기록 (개별 스크립트에서 설정한 카운터 값 사용)
        Add-ScriptResult -ScriptId $item.Id -ScriptName $item.Name -Status "완료" `
            -AppliedCount $global:AppliedCount -SkippedCount $global:SkippedCount -FailedCount $global:FailedCount `
            -Duration $duration

        return @{
            Success = $true
            AppliedCount = $global:AppliedCount
            SkippedCount = $global:SkippedCount
            FailedCount = $global:FailedCount
        }
    } catch {
        Write-Host "오류 발생: $_" -ForegroundColor Red

        # 실패 기록
        Add-ScriptResult -ScriptId $item.Id -ScriptName $item.Name -Status "실패" `
            -AppliedCount 0 -SkippedCount 0 -FailedCount 1 `
            -Notes "오류: $_"

        return @{
            Success = $false
            AppliedCount = 0
            SkippedCount = 0
            FailedCount = 1
        }
    }
}

function Invoke-ParallelScripts {
    param([array]$ScriptIds)

    if ($ScriptIds.Count -eq 0) { return @() }

    # 단일 스크립트는 직접 실행
    if ($ScriptIds.Count -eq 1) {
        $result = Invoke-OptimizationScript -ScriptId $ScriptIds[0]
        return @(@{
            Id = $ScriptIds[0]
            Success = $result.Success
            AppliedCount = $result.AppliedCount
            SkippedCount = $result.SkippedCount
            FailedCount = $result.FailedCount
        })
    }

    # 병렬 실행 시작 알림
    $scriptNames = $ScriptIds | ForEach-Object {
        $item = $global:ScriptItems | Where-Object { $_.Id -eq $_ }
        $item.Name
    }
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "병렬 실행 시작: $($scriptNames -join ', ')" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan

    # Start-Job으로 각 스크립트 백그라운드 실행
    $jobs = @()
    foreach ($id in $ScriptIds) {
        $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
        $scriptUrl = "$global:ScriptBaseUrl/$($item.File)"

        # ExperimentalOptions를 JSON으로 직렬화하여 전달 (Job 간 글로벌 변수 공유 불가)
        $experimentalOptionsJson = if ($global:ExperimentalOptions) {
            $global:ExperimentalOptions | ConvertTo-Json -Compress
        } else {
            "{}"
        }

        $job = Start-Job -ScriptBlock {
            param($url, $forceOverride, $experimentalJson)
            # UTF-8 인코딩 설정
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $OutputEncoding = [System.Text.Encoding]::UTF8

            # OrchestrateMode 및 ForceOverride 설정
            $global:OrchestrateMode = $true
            $global:ForceOverride = $forceOverride

            # ExperimentalOptions 복원
            try {
                $global:ExperimentalOptions = $experimentalJson | ConvertFrom-Json -AsHashtable
            } catch {
                $global:ExperimentalOptions = @{}
            }

            # 카운터 초기화
            $global:AppliedCount = 0
            $global:SkippedCount = 0
            $global:FailedCount = 0

            try {
                $content = Invoke-RestMethod $url
                Invoke-Expression $content
                return @{
                    Success = $true
                    Error = $null
                    AppliedCount = $global:AppliedCount
                    SkippedCount = $global:SkippedCount
                    FailedCount = $global:FailedCount
                }
            } catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    AppliedCount = 0
                    SkippedCount = 0
                    FailedCount = 1
                }
            }
        } -ArgumentList $scriptUrl, $global:ForceOverride, $experimentalOptionsJson

        $jobs += @{ Job = $job; Id = $id }
    }

    # 모든 Job 완료 대기 및 결과 수집
    $results = @()
    foreach ($jobInfo in $jobs) {
        $job = $jobInfo.Job
        $id = $jobInfo.Id
        $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }

        Wait-Job -Job $job | Out-Null
        $output = Receive-Job -Job $job
        Remove-Job -Job $job

        # 결과 출력
        Write-Host ""
        if ($output.Success) {
            Write-Host "[$id] $($item.Name) 완료 (적용:$($output.AppliedCount) 스킵:$($output.SkippedCount) 실패:$($output.FailedCount))" -ForegroundColor Green
            Add-ScriptResult -ScriptId $id -ScriptName $item.Name -Status "완료" `
                -AppliedCount $output.AppliedCount -SkippedCount $output.SkippedCount -FailedCount $output.FailedCount
        } else {
            Write-Host "[$id] $($item.Name) 실패: $($output.Error)" -ForegroundColor Red
            Add-ScriptResult -ScriptId $id -ScriptName $item.Name -Status "실패" `
                -AppliedCount 0 -SkippedCount 0 -FailedCount 1 -Notes "오류: $($output.Error)"
        }

        $results += @{
            Id = $id
            Success = $output.Success
            AppliedCount = $output.AppliedCount
            SkippedCount = $output.SkippedCount
            FailedCount = $output.FailedCount
        }
    }

    return $results
}

function Start-OptimizationProcess {
    param([hashtable]$State)

    $pendingItems = [array]$State.PendingItems
    $completedItems = [System.Collections.ArrayList]@()
    $failedItems = [System.Collections.ArrayList]@()
    if ($State.CompletedItems) {
        $completedItems.AddRange($State.CompletedItems)
    }

    # Explorer 종료 (최적화 중 반복 재시작 방지)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Explorer 종료 중 (최적화 중 재시작 방지)..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan

    # Explorer 강제 종료 (Windows 자동 재시작 방지를 위해 반복 시도)
    $maxAttempts = 5
    for ($i = 1; $i -le $maxAttempts; $i++) {
        $explorerProc = Get-Process -Name explorer -ErrorAction SilentlyContinue
        if ($null -eq $explorerProc) {
            Write-Host "  - Explorer 종료됨" -ForegroundColor Green
            break
        }

        Write-Host "  - Explorer 종료 시도 $i/$maxAttempts..." -ForegroundColor Yellow
        taskkill /F /IM explorer.exe 2>$null | Out-Null
        Start-Sleep -Seconds 1

        if ($i -eq $maxAttempts) {
            $explorerProc = Get-Process -Name explorer -ErrorAction SilentlyContinue
            if ($null -eq $explorerProc) {
                Write-Host "  - Explorer 종료됨" -ForegroundColor Green
            } else {
                Write-Host "  - Explorer 종료 실패 (자동 재시작됨) - 계속 진행" -ForegroundColor Yellow
            }
        }
    }

    # 재부팅 불필요 항목과 필요 항목 분리
    $noRebootItems = @()
    $rebootItems = @()

    foreach ($id in $pendingItems) {
        if ($id -in $completedItems) { continue }

        $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
        if ($item.RequiresReboot) {
            $rebootItems += $id
        } else {
            $noRebootItems += $id
        }
    }

    # 재부팅 불필요 항목 먼저 실행 (배치 병렬)
    if ($noRebootItems.Count -gt 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Phase 1: 재부팅 불필요 항목 실행" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan

        $batches = Get-ExecutionBatches -ScriptIds $noRebootItems
        foreach ($batch in $batches) {
            $results = Invoke-ParallelScripts -ScriptIds $batch
            foreach ($r in $results) {
                if ($r.Success) {
                    $completedItems.Add($r.Id) | Out-Null
                } else {
                    $failedItems.Add($r.Id) | Out-Null
                }
            }
        }
    }

    # 재부팅 필요 항목 실행 (배치 병렬)
    if ($rebootItems.Count -gt 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "Phase 2: 재부팅 필요 항목 실행" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow

        $batches = Get-ExecutionBatches -ScriptIds $rebootItems
        foreach ($batch in $batches) {
            $results = Invoke-ParallelScripts -ScriptIds $batch
            foreach ($r in $results) {
                if ($r.Success) {
                    $completedItems.Add($r.Id) | Out-Null
                } else {
                    $failedItems.Add($r.Id) | Out-Null
                }
            }
        }
    }

    # 바탕화면 바로가기 정리
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "바탕화면 바로가기 정리 중..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan

    $desktopPaths = @(
        [Environment]::GetFolderPath('Desktop'),
        [Environment]::GetFolderPath('CommonDesktopDirectory')
    )

    $removedCount = 0
    foreach ($desktopPath in $desktopPaths) {
        if (Test-Path $desktopPath) {
            $shortcuts = Get-ChildItem -Path $desktopPath -Filter "*.lnk" -ErrorAction SilentlyContinue
            foreach ($shortcut in $shortcuts) {
                try {
                    Remove-Item -Path $shortcut.FullName -Force
                    Write-Host "  - 삭제: $($shortcut.Name)" -ForegroundColor Green
                    $removedCount++
                } catch {
                    Write-Host "  - 삭제 실패: $($shortcut.Name)" -ForegroundColor Red
                }
            }
        }
    }

    if ($removedCount -eq 0) {
        Write-Host "  - 삭제할 바로가기가 없습니다." -ForegroundColor Gray
    } else {
        Write-Host "  - 총 $removedCount 개 바로가기 삭제 완료" -ForegroundColor Green
    }

    # Explorer 재시작
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Explorer 재시작 중..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Start-Process explorer
    Start-Sleep -Seconds 3
    Write-Host "  - Explorer 재시작됨" -ForegroundColor Green

    # 전체 Summary 출력 및 로그 저장
    Show-OrchestrateSummary -CompletedItems ([array]$completedItems) -FailedItems ([array]$failedItems)

    # 완료 메시지
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  모든 최적화가 완료되었습니다!" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Cyan

    # 재부팅 필요 여부 확인
    $hasRebootItems = $false
    foreach ($id in $completedItems) {
        $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
        if ($item.RequiresReboot) {
            $hasRebootItems = $true
            break
        }
    }

    if ($hasRebootItems) {
        Write-Host ""
        Write-Host "일부 설정은 재부팅 후 적용됩니다." -ForegroundColor Yellow
        Write-Host ""

        $restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
        if ($restart -eq "Y" -or $restart -eq "y") {
            Clear-State
            Write-Host ""
            Write-Host "10초 후 재부팅됩니다..." -ForegroundColor Red
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        } else {
            Clear-State
            Write-Host ""
            Write-Host "나중에 수동으로 재부팅해주세요." -ForegroundColor Yellow
        }
    } else {
        Clear-State
    }
}


# ===== 메인 실행 =====

Write-Host ""
Write-Host "=== Windows 11 25H2 원클릭 최적화 스크립트 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host ""

# 저장된 상태 확인 (재부팅 후 자동 재개)
$savedState = Get-SavedState
if ($savedState -and $savedState.PendingItems.Count -gt 0) {
    $remainingCount = $savedState.PendingItems.Count - $savedState.CompletedItems.Count

    if ($remainingCount -gt 0) {
        Write-Host "이전 실행이 중단되었습니다. ($remainingCount 개 항목 남음)" -ForegroundColor Yellow
        Write-Host ""
        $continue = Read-Host "계속하시겠습니까? (Y/N)"

        if ($continue -eq "Y" -or $continue -eq "y") {
            Start-OptimizationProcess -State @{
                PendingItems = $savedState.PendingItems
                CompletedItems = $savedState.CompletedItems
                CurrentIndex = $savedState.CurrentIndex
            }
            exit
        } else {
            Clear-State
        }
    }
}

# 새 실행: 메뉴 표시
$userSelection = Get-UserSelection

# 실험적 기능 선택 (해당 스크립트가 선택된 경우에만 표시)
Get-ExperimentalOptions -SelectedIds $userSelection.PendingItems

Start-OptimizationProcess -State $userSelection
