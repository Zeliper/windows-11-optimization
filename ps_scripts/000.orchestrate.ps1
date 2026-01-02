# Windows 11 25H2 원클릭 최적화 스크립트
# 모든 최적화 항목을 대화형 메뉴로 선택하여 실행
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Orchestrate 모드 플래그 설정
$global:OrchestrateMode = $true

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
    @{ Id = 7;  File = "007.openssh_rsync.ps1";               Name = "OpenSSH/rsync 설치";                RequiresReboot = $false; Group = "서버" }
    @{ Id = 8;  File = "008.common_optimization.ps1";         Name = "공통 최적화 (DNS/서비스/부팅)";      RequiresReboot = $true;  Group = "기본" }
    @{ Id = 9;  File = "009.gaming_optimization.ps1";         Name = "게임용 최적화 (VBS/GPU)";           RequiresReboot = $true;  Group = "게임" }
    @{ Id = 10; File = "010.game_server.ps1";                 Name = "게임 서버 최적화 (TCP/UDP)";         RequiresReboot = $true;  Group = "서버" }
    @{ Id = 11; File = "011.web_server.ps1";                  Name = "웹 서버 IIS 최적화";                 RequiresReboot = $true;  Group = "서버" }
    @{ Id = 12; File = "012.ai_features.ps1";                 Name = "25H2 AI 기능 비활성화";              RequiresReboot = $true;  Group = "25H2" }
)

# 프리셋 정의
$global:Presets = @{
    "기본"   = @(1, 2, 3, 4, 5, 6, 8, 12)       # 기본 최적화 + AI 비활성화
    "게임"   = @(1, 2, 3, 4, 5, 6, 8, 9, 12)    # 게임용 PC
    "서버"   = @(1, 2, 3, 7, 8, 10)             # 게임 서버용
    "웹서버" = @(1, 2, 3, 7, 8, 11)             # 웹 서버용
}


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

function Show-Menu {
    param([hashtable]$SelectedItems)

    Clear-Host
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  Windows 11 25H2 원클릭 최적화 스크립트" -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
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
            default {
                $num = 0
                if ([int]::TryParse($key, [ref]$num) -and $num -ge 1 -and $num -le 12) {
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


# ===== 스크립트 실행 함수 =====

function Invoke-OptimizationScript {
    param([int]$ScriptId)

    $item = $global:ScriptItems | Where-Object { $_.Id -eq $ScriptId }
    if (-not $item) { return $false }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "[$($item.Id)/12] $($item.Name) 실행 중..." -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    try {
        $scriptUrl = "$global:ScriptBaseUrl/$($item.File)"
        $scriptContent = Invoke-RestMethod $scriptUrl
        Invoke-Expression $scriptContent
        return $true
    } catch {
        Write-Host "오류 발생: $_" -ForegroundColor Red
        return $false
    }
}

function Start-OptimizationProcess {
    param([hashtable]$State)

    $pendingItems = [array]$State.PendingItems
    $completedItems = [System.Collections.ArrayList]@()
    if ($State.CompletedItems) {
        $completedItems.AddRange($State.CompletedItems)
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

    # 재부팅 불필요 항목 먼저 실행
    if ($noRebootItems.Count -gt 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Phase 1: 재부팅 불필요 항목 실행" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan

        foreach ($id in $noRebootItems) {
            if (Invoke-OptimizationScript -ScriptId $id) {
                $completedItems.Add($id) | Out-Null
            }
        }
    }

    # 재부팅 필요 항목 실행
    if ($rebootItems.Count -gt 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Yellow
        Write-Host "Phase 2: 재부팅 필요 항목 실행" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Yellow

        foreach ($id in $rebootItems) {
            if (Invoke-OptimizationScript -ScriptId $id) {
                $completedItems.Add($id) | Out-Null
            }
        }
    }

    # 완료 메시지
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "  모든 최적화가 완료되었습니다!" -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "완료된 항목:" -ForegroundColor Yellow
    foreach ($id in $completedItems) {
        $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
        Write-Host "  - $($item.Name)" -ForegroundColor White
    }

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
Write-Host "=== Windows 11 25H2 원클릭 최적화 스크립트 ===" -ForegroundColor Cyan
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
Start-OptimizationProcess -State $userSelection
