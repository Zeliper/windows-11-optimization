# Windows 11 작업 표시줄, 컨텍스트 메뉴 및 파일 탐색기 정리 스크립트
# 검색 상자, 작업 보기, 위젯 숨기기, 고정된 앱 제거, Windows 10 컨텍스트 메뉴 복원
# 파일 탐색기 설정 최적화
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

# Orchestrate 모드 확인
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

# ForceOverride 모드 확인
if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

#region 공통 함수

# 로그 파일 경로 설정
$logFileName = "Windows11Optimizer_004_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir $logFileName
$global:LogEntries = [System.Collections.ArrayList]@()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Message,
        [ValidateSet("Applied", "Skipped", "Failed", "Info")]
        [string]$Status = "Info"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Status] $Message"
    [void]$global:LogEntries.Add($logEntry)

    switch ($Status) {
        "Applied" { $global:AppliedCount++ }
        "Skipped" { $global:SkippedCount++ }
        "Failed" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    if ($global:LogEntries.Count -gt 0) {
        $global:LogEntries | Out-File -FilePath $global:LogFilePath -Encoding UTF8
    }
}

function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$StepName,
        [string]$Description = ""
    )

    try {
        # 경로가 없으면 생성
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $currentValue = $null
        try {
            $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        } catch {
            $currentValue = $null
        }

        # ForceOverride가 아니고 값이 같으면 스킵
        if (-not $global:ForceOverride -and $currentValue -eq $Value) {
            $displayDesc = if ($Description) { " - $Description" } else { "" }
            Write-Host "  - $StepName : 이미 적용됨 (스킵)$displayDesc" -ForegroundColor Gray
            Write-OptLog -Message "$StepName : 이미 적용됨 ($Name = $Value)" -Status "Skipped"
            return $false
        }

        # 값 설정
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        $displayDesc = if ($Description) { " - $Description" } else { "" }
        Write-Host "  - $StepName : 적용됨$displayDesc" -ForegroundColor Green
        Write-OptLog -Message "$StepName : 적용됨 ($Name = $Value)" -Status "Applied"
        return $true
    } catch {
        Write-Host "  - $StepName : 실패 - $($_.Exception.Message)" -ForegroundColor Red
        Write-OptLog -Message "$StepName : 실패 - $($_.Exception.Message)" -Status "Failed"
        return $false
    }
}

function Remove-AppxPackageIfExists {
    param(
        [string]$PackageName,
        [string]$StepName,
        [switch]$RemoveProvisioned
    )

    $package = Get-AppxPackage -AllUsers -Name $PackageName -ErrorAction SilentlyContinue
    if (-not $global:ForceOverride -and -not $package) {
        Write-Host "  - $StepName : 이미 제거됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "$StepName : 이미 제거됨" -Status "Skipped"
        return $false
    }

    try {
        # 현재 사용자에서 제거
        Get-AppxPackage -Name $PackageName | Remove-AppxPackage -ErrorAction SilentlyContinue
        # 모든 사용자에서 제거
        Get-AppxPackage -AllUsers -Name $PackageName | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

        if ($RemoveProvisioned) {
            # 프로비저닝된 패키지 제거
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$PackageName*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        }

        Write-Host "  - $StepName : 제거 완료" -ForegroundColor Green
        Write-OptLog -Message "$StepName : 제거됨" -Status "Applied"
        return $true
    } catch {
        Write-Host "  - $StepName : 제거 실패 - $($_.Exception.Message)" -ForegroundColor Red
        Write-OptLog -Message "$StepName : 실패 - $($_.Exception.Message)" -Status "Failed"
        return $false
    }
}

#endregion 공통 함수

Write-Host "=== Windows 11 작업 표시줄/컨텍스트 메뉴 정리 v$scriptVersion ===" -ForegroundColor Cyan
if ($global:ForceOverride) {
    Write-Host "[ForceOverride 모드: 모든 설정 강제 재적용]" -ForegroundColor Magenta
}
Write-Host ""

$advancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# 1. 검색 상자 숨기기
Write-Host "[1/9] 검색 상자 숨기기..." -ForegroundColor Yellow

$searchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
Set-RegistryIfDifferent -Path $searchPath -Name "SearchboxTaskbarMode" -Value 0 `
    -StepName "검색 상자 숨김" -Description "0=숨김, 1=아이콘, 2=상자"


# 2. 작업 보기 버튼 숨기기
Write-Host ""
Write-Host "[2/9] 작업 보기 버튼 숨기기..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $advancedPath -Name "ShowTaskViewButton" -Value 0 `
    -StepName "작업 보기 버튼 숨김"


# 3. 위젯 비활성화 (정책 + 앱 제거)
Write-Host ""
Write-Host "[3/9] 위젯 비활성화 중..." -ForegroundColor Yellow

# TaskbarDa 레지스트리 설정 제거됨 - 권한 문제로 실패하며 정책/앱 제거로 충분
# 위젯 정책 비활성화 (HKLM 권한 문제 가능 - 별도 처리)
$dshPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
try {
    if (!(Test-Path $dshPolicyPath)) {
        New-Item -Path $dshPolicyPath -Force -ErrorAction Stop | Out-Null
    }
    $currentValue = (Get-ItemProperty -Path $dshPolicyPath -Name "AllowNewsAndInterests" -ErrorAction SilentlyContinue).AllowNewsAndInterests
    if (-not $global:ForceOverride -and $currentValue -eq 0) {
        Write-Host "  - 위젯 정책 비활성화 : 이미 적용됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "위젯 정책 비활성화 : 이미 적용됨 (AllowNewsAndInterests = 0)" -Status "Skipped"
    } else {
        Set-ItemProperty -Path $dshPolicyPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -ErrorAction Stop
        Write-Host "  - 위젯 정책 비활성화 : 적용됨" -ForegroundColor Green
        Write-OptLog -Message "위젯 정책 비활성화 : 적용됨 (AllowNewsAndInterests = 0)" -Status "Applied"
    }
} catch {
    # 권한 문제 시 스킵 (위젯 버튼 숨김은 HKCU에서 이미 처리됨)
    Write-Host "  - 위젯 정책 비활성화 : 권한 부족으로 스킵 (위젯 버튼 숨김은 적용됨)" -ForegroundColor Yellow
    Write-OptLog -Message "위젯 정책 비활성화 : 권한 부족 스킵 - $($_.Exception.Message)" -Status "Skipped"
}

# Windows Web Experience Pack 제거
Remove-AppxPackageIfExists -PackageName "MicrosoftWindows.Client.WebExperience" `
    -StepName "Windows Web Experience Pack" -RemoveProvisioned

# 위젯 프로세스 종료
$widgetsProcess = Get-Process -Name "Widgets" -ErrorAction SilentlyContinue
$widgetServiceProcess = Get-Process -Name "WidgetService" -ErrorAction SilentlyContinue
if ($widgetsProcess -or $widgetServiceProcess) {
    Stop-Process -Name "Widgets" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "WidgetService" -Force -ErrorAction SilentlyContinue
    Write-Host "  - 위젯 프로세스 종료" -ForegroundColor Green
    Write-OptLog -Message "위젯 프로세스 종료" -Status "Applied"
} else {
    Write-Host "  - 위젯 프로세스 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "위젯 프로세스: 없음" -Status "Skipped"
}


# 4. 채팅(Teams) 버튼 숨기기
Write-Host ""
Write-Host "[4/9] 채팅(Teams) 버튼 숨기기..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $advancedPath -Name "TaskbarMn" -Value 0 `
    -StepName "채팅 버튼 숨김"


# 5. 작업 표시줄 고정된 앱 모두 제거
Write-Host ""
Write-Host "[5/9] 작업 표시줄 고정된 앱 제거 중..." -ForegroundColor Yellow

$pinnedPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"

if (Test-Path $pinnedPath) {
    $pinnedItems = Get-ChildItem -Path $pinnedPath -ErrorAction SilentlyContinue
    $count = ($pinnedItems | Measure-Object).Count

    if (-not $global:ForceOverride -and $count -eq 0) {
        Write-Host "  - 고정된 앱이 없습니다 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "고정된 앱: 없음" -Status "Skipped"
    } elseif ($count -gt 0) {
        Remove-Item -Path "$pinnedPath\*" -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  - 고정된 앱 $count 개 제거 완료" -ForegroundColor Green
        Write-OptLog -Message "고정된 앱 $count 개 제거" -Status "Applied"
    }
} else {
    Write-Host "  - 고정된 앱 폴더 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "고정된 앱 폴더: 없음" -Status "Skipped"
}

# 작업 표시줄 레지스트리 캐시 초기화
$taskbandPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
if (Test-Path $taskbandPath) {
    $favorites = Get-ItemProperty -Path $taskbandPath -Name "Favorites" -ErrorAction SilentlyContinue
    if (-not $global:ForceOverride -and -not $favorites) {
        Write-Host "  - 작업 표시줄 캐시 이미 초기화됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "작업 표시줄 캐시: 이미 초기화됨" -Status "Skipped"
    } else {
        Remove-ItemProperty -Path $taskbandPath -Name "Favorites" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $taskbandPath -Name "FavoritesResolve" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $taskbandPath -Name "FavoritesVersion" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $taskbandPath -Name "FavoritesChanges" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $taskbandPath -Name "Pinned" -ErrorAction SilentlyContinue
        Write-Host "  - 작업 표시줄 캐시 초기화 완료" -ForegroundColor Green
        Write-OptLog -Message "작업 표시줄 캐시 초기화" -Status "Applied"
    }
}


# 6. Windows 10 스타일 컨텍스트 메뉴 복원
Write-Host ""
Write-Host "[6/9] Windows 10 스타일 컨텍스트 메뉴 복원 중..." -ForegroundColor Yellow

$contextMenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"

# 이미 복원되었는지 확인
$contextMenuRestored = $false
if (Test-Path $contextMenuPath) {
    $defaultValue = (Get-ItemProperty -Path $contextMenuPath -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)"
    if ($defaultValue -eq "") {
        $contextMenuRestored = $true
    }
}

if (-not $global:ForceOverride -and $contextMenuRestored) {
    Write-Host "  - Windows 10 컨텍스트 메뉴 이미 복원됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "Windows 10 컨텍스트 메뉴: 이미 복원됨" -Status "Skipped"
} else {
    if (!(Test-Path $contextMenuPath)) {
        New-Item -Path $contextMenuPath -Force | Out-Null
    }
    Set-ItemProperty -Path $contextMenuPath -Name "(Default)" -Value "" -Type String
    Write-Host "  - Windows 10 스타일 컨텍스트 메뉴 복원 완료" -ForegroundColor Green
    Write-OptLog -Message "Windows 10 컨텍스트 메뉴 복원" -Status "Applied"
}


# 7. 파일 탐색기 시작 위치를 "내 PC"로 변경
Write-Host ""
Write-Host "[7/9] 파일 탐색기 시작 위치를 '내 PC'로 변경..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $advancedPath -Name "LaunchTo" -Value 1 `
    -StepName "파일 탐색기 시작 위치" -Description "1=내 PC"


# 8. 파일 탐색기 개인정보 보호 설정 해제 및 기록 지우기
Write-Host ""
Write-Host "[8/9] 파일 탐색기 개인정보 보호 설정 해제..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $advancedPath -Name "ShowRecent" -Value 0 `
    -StepName "최근 사용한 파일 표시 해제"

Set-RegistryIfDifferent -Path $advancedPath -Name "ShowFrequent" -Value 0 `
    -StepName "자주 사용하는 폴더 표시 해제"

Set-RegistryIfDifferent -Path $advancedPath -Name "ShowCloudFilesInQuickAccess" -Value 0 `
    -StepName "Office.com 파일 표시 해제"

# 파일 탐색기 기록 지우기
$explorerBagMRU = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU"
if (Test-Path $explorerBagMRU) {
    if (-not $global:ForceOverride) {
        $mruItems = Get-ChildItem -Path $explorerBagMRU -ErrorAction SilentlyContinue
        if (-not $mruItems -or $mruItems.Count -eq 0) {
            Write-Host "  - 파일 열기/저장 기록 없음 (스킵)" -ForegroundColor Gray
            Write-OptLog -Message "파일 열기/저장 기록: 없음" -Status "Skipped"
        } else {
            Remove-Item -Path $explorerBagMRU -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  - 파일 열기/저장 기록 삭제" -ForegroundColor Green
            Write-OptLog -Message "파일 열기/저장 기록 삭제" -Status "Applied"
        }
    } else {
        Remove-Item -Path $explorerBagMRU -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  - 파일 열기/저장 기록 삭제" -ForegroundColor Green
        Write-OptLog -Message "파일 열기/저장 기록 삭제" -Status "Applied"
    }
} else {
    Write-Host "  - 파일 열기/저장 기록 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "파일 열기/저장 기록: 없음" -Status "Skipped"
}

$recentDocs = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs"
if (Test-Path $recentDocs) {
    $docItems = Get-ChildItem -Path $recentDocs -ErrorAction SilentlyContinue
    if (-not $global:ForceOverride -and (-not $docItems -or $docItems.Count -eq 0)) {
        Write-Host "  - 최근 문서 기록 없음 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "최근 문서 기록: 없음" -Status "Skipped"
    } else {
        Remove-Item -Path $recentDocs -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -Path $recentDocs -Force | Out-Null
        Write-Host "  - 최근 문서 기록 삭제" -ForegroundColor Green
        Write-OptLog -Message "최근 문서 기록 삭제" -Status "Applied"
    }
}

# 최근 항목 폴더 비우기
$recentFolder = "$env:APPDATA\Microsoft\Windows\Recent"
if (Test-Path $recentFolder) {
    $recentItems = Get-ChildItem -Path $recentFolder -ErrorAction SilentlyContinue
    if (-not $global:ForceOverride -and (-not $recentItems -or $recentItems.Count -eq 0)) {
        Write-Host "  - 최근 항목 폴더 비어있음 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "최근 항목 폴더: 비어있음" -Status "Skipped"
    } else {
        Remove-Item -Path "$recentFolder\*" -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  - 최근 항목 폴더 비우기 완료" -ForegroundColor Green
        Write-OptLog -Message "최근 항목 폴더 비우기" -Status "Applied"
    }
}

# 점프 목록 폴더 비우기
$automaticDestinations = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
$customDestinations = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
$jumpListCleared = $false

if (Test-Path $automaticDestinations) {
    $autoItems = Get-ChildItem -Path $automaticDestinations -ErrorAction SilentlyContinue
    if ($autoItems -and $autoItems.Count -gt 0) {
        Remove-Item -Path "$automaticDestinations\*" -Force -ErrorAction SilentlyContinue
        $jumpListCleared = $true
    }
}
if (Test-Path $customDestinations) {
    $customItems = Get-ChildItem -Path $customDestinations -ErrorAction SilentlyContinue
    if ($customItems -and $customItems.Count -gt 0) {
        Remove-Item -Path "$customDestinations\*" -Force -ErrorAction SilentlyContinue
        $jumpListCleared = $true
    }
}

if (-not $global:ForceOverride -and -not $jumpListCleared) {
    Write-Host "  - 점프 목록 기록 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "점프 목록 기록: 없음" -Status "Skipped"
} else {
    Write-Host "  - 점프 목록 기록 삭제 완료" -ForegroundColor Green
    Write-OptLog -Message "점프 목록 기록 삭제" -Status "Applied"
}


# 9. 파일 확장자명 표시
Write-Host ""
Write-Host "[9/9] 파일 확장자명 표시 설정..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $advancedPath -Name "HideFileExt" -Value 0 `
    -StepName "파일 확장자명 표시" -Description "0=표시"

Set-RegistryIfDifferent -Path $advancedPath -Name "Hidden" -Value 1 `
    -StepName "숨김 파일 표시" -Description "1=표시"


# 로그 저장
Save-OptLog

# Explorer 재시작하여 변경사항 적용 (OrchestrateMode에서는 중앙 관리)
if (-not $global:OrchestrateMode) {
    Write-Host ""
    Write-Host "변경사항을 적용하기 위해 Explorer를 재시작합니다..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2

    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $($global:AppliedCount) 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $($global:SkippedCount) 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $($global:FailedCount) 개" -ForegroundColor $(if($global:FailedCount -gt 0){"Red"}else{"Gray"})
Write-Host ""
Write-Host "로그 파일: $($global:LogFilePath)" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 검색 상자 숨김" -ForegroundColor White
Write-Host "  - 작업 보기 버튼 숨김" -ForegroundColor White
Write-Host "  - 위젯 버튼 숨김" -ForegroundColor White
Write-Host "  - 채팅(Teams) 버튼 숨김" -ForegroundColor White
Write-Host "  - 고정된 앱 모두 제거" -ForegroundColor White
Write-Host "  - Windows 10 스타일 컨텍스트 메뉴 복원" -ForegroundColor White
Write-Host "  - 파일 탐색기 시작 위치 '내 PC' 설정" -ForegroundColor White
Write-Host "  - 파일 탐색기 개인정보 보호 설정 해제 및 기록 삭제" -ForegroundColor White
Write-Host "  - 파일 확장자명 및 숨김 파일 표시" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
