# 필수 소프트웨어 자동 설치 (Notepad++, Chrome, 7-Zip, ShareX, Honeyview, PotPlayer, Everything)
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.2"
$scriptName = "006.software_install.ps1"

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Orchestrate 모드 확인
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

# 다운로드 속도 개선 (진행률 표시 비활성화)
$ProgressPreference = 'SilentlyContinue'

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_006_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir $logFileName
$global:LogEntries = [System.Collections.ArrayList]@()
$global:InstalledCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Step,
        [string]$Status,
        [string]$Message,
        [string]$PreviousValue = "",
        [string]$NewValue = ""
    )

    $entry = [PSCustomObject]@{
        Timestamp = Get-Date -Format "HH:mm:ss"
        Step = $Step
        Status = $Status
        Message = $Message
        PreviousValue = $PreviousValue
        NewValue = $NewValue
    }

    [void]$global:LogEntries.Add($entry)

    switch ($Status) {
        "설치됨" { $global:InstalledCount++ }
        "스킵됨" { $global:SkippedCount++ }
        "실패" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    $logContent = @"
================================================================================
Windows 11 Optimization Log - Software Install
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
스크립트: $scriptName v$scriptVersion
================================================================================

================================================================================
단계별 결과
================================================================================

"@

    foreach ($entry in $global:LogEntries) {
        $logContent += "[$($entry.Timestamp)] [$($entry.Step)]`n"
        $logContent += "  상태: $($entry.Status)`n"
        $logContent += "  내용: $($entry.Message)`n"
        if ($entry.PreviousValue) {
            $logContent += "  이전값: $($entry.PreviousValue)`n"
        }
        if ($entry.NewValue) {
            $logContent += "  새값: $($entry.NewValue)`n"
        }
        $logContent += "`n"
    }

    $logContent += @"
================================================================================
Summary
================================================================================
총 항목: $($global:InstalledCount + $global:SkippedCount + $global:FailedCount)
설치됨: $global:InstalledCount
스킵됨: $global:SkippedCount (이미 설치됨)
실패: $global:FailedCount

로그 파일: $global:LogFilePath
================================================================================
"@

    $logContent | Set-Content -Path $global:LogFilePath -Encoding UTF8
}

# ===== 소프트웨어 체크 함수 =====
function Test-SoftwareInstalled {
    param(
        [string]$Name,
        [string[]]$Paths,
        [string]$WingetId = ""
    )

    # 경로 체크
    foreach ($path in $Paths) {
        if (Test-Path $path) {
            return $true
        }
    }

    # winget 체크
    if ($WingetId) {
        $wingetResult = winget list --id $WingetId 2>$null
        if ($LASTEXITCODE -eq 0 -and $wingetResult -notmatch "No installed package") {
            return $true
        }
    }

    return $false
}

# 파일 연결이 특정 ProgId로 설정되어 있는지 확인하는 함수
function Test-FileAssociation {
    param(
        [string]$Extension,
        [string]$ExpectedProgId
    )

    # UserChoice에서 현재 연결된 ProgId 확인
    $userChoicePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"
    $currentProgId = (Get-ItemProperty -Path $userChoicePath -Name "ProgId" -ErrorAction SilentlyContinue).ProgId

    if ($currentProgId -and $currentProgId -like "*$ExpectedProgId*") {
        return $true
    }
    return $false
}

# URL 프로토콜 연결 확인 함수
function Test-ProtocolAssociation {
    param(
        [string]$Protocol,
        [string]$ExpectedProgId
    )

    $userChoicePath = "HKCU:\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$Protocol\UserChoice"
    $currentProgId = (Get-ItemProperty -Path $userChoicePath -Name "ProgId" -ErrorAction SilentlyContinue).ProgId

    if ($currentProgId -and $currentProgId -like "*$ExpectedProgId*") {
        return $true
    }
    return $false
}

Write-Host "=== 필수 소프트웨어 자동 설치 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "Notepad++, Chrome, 7-Zip, ShareX, Honeyview, PotPlayer, Everything을 자동으로 설치합니다." -ForegroundColor White
Write-Host ""

$tempDir = $env:TEMP

# [1/21] Notepad++ 설치 (winget - GitHub API rate limit 회피)
Write-Host "[1/21] Notepad++ 설치 중 (winget)..." -ForegroundColor Yellow
$nppPaths = @(
    "${env:ProgramFiles}\Notepad++\notepad++.exe",
    "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
)
if (Test-SoftwareInstalled -Name "Notepad++" -Paths $nppPaths -WingetId "Notepad++.Notepad++") {
    Write-Host "  - Notepad++ : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "Notepad++ 설치" -Status "스킵됨" -Message "이미 설치됨"
} else {
    try {
        $wingetResult = winget install Notepad++.Notepad++ --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -or $wingetResult -match "already installed") {
            Write-Host "  - Notepad++ : 설치됨 (적용됨)" -ForegroundColor Green
            Write-OptLog -Step "Notepad++ 설치" -Status "설치됨" -Message "winget으로 설치 완료"
        } else {
            Write-Host "  - Notepad++ : 설치 실패" -ForegroundColor Red
            Write-OptLog -Step "Notepad++ 설치" -Status "실패" -Message "$wingetResult"
        }
    } catch {
        Write-Host "  - Notepad++ : 설치 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "Notepad++ 설치" -Status "실패" -Message "$_"
    }
}

# [2/21] Notepad++ 설치 확인
Write-Host "[2/21] Notepad++ 설치 확인..." -ForegroundColor Yellow
$nppPath = "${env:ProgramFiles}\Notepad++\notepad++.exe"
if (Test-Path $nppPath) {
    Write-Host "  - Notepad++ 설치 확인됨" -ForegroundColor Green
} else {
    Write-Host "  - Notepad++ 경로 없음 (설치 지연 가능)" -ForegroundColor Yellow
}

# [3/21] Chrome 다운로드 및 설치
Write-Host "[3/21] Chrome 다운로드 중..." -ForegroundColor Yellow
$chromePaths = @(
    "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
)
$chromeInstaller = $null
if (Test-SoftwareInstalled -Name "Chrome" -Paths $chromePaths) {
    Write-Host "  - Chrome : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "Chrome 다운로드" -Status "스킵됨" -Message "이미 설치됨"
} else {
    try {
        $chromeUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
        $chromeInstaller = Join-Path $tempDir "chrome_installer.msi"
        Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeInstaller -UseBasicParsing
        Write-Host "  - 다운로드 완료" -ForegroundColor Green
    } catch {
        Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
        $chromeInstaller = $null
        Write-OptLog -Step "Chrome 다운로드" -Status "실패" -Message "$_"
    }
}

# [4/21] Chrome 설치
Write-Host "[4/21] Chrome 설치 중..." -ForegroundColor Yellow
if (Test-SoftwareInstalled -Name "Chrome" -Paths $chromePaths) {
    Write-Host "  - Chrome : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "Chrome 설치" -Status "스킵됨" -Message "이미 설치됨"
} elseif ($chromeInstaller -and (Test-Path $chromeInstaller)) {
    try {
        Start-Process msiexec -ArgumentList "/i `"$chromeInstaller`" /qn /norestart" -Wait -NoNewWindow
        Remove-Item $chromeInstaller -Force -ErrorAction SilentlyContinue

        # Chrome 기본 브라우저 확인 팝업 비활성화
        $chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        if (-not (Test-Path $chromePolicyPath)) {
            New-Item -Path $chromePolicyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $chromePolicyPath -Name "DefaultBrowserSettingEnabled" -Value 0 -Type DWord -Force

        Write-Host "  - Chrome : 설치됨 (기본 브라우저 확인 비활성화)" -ForegroundColor Green
        Write-OptLog -Step "Chrome 설치" -Status "설치됨" -Message "MSI로 설치 완료"
    } catch {
        Write-Host "  - Chrome : 설치 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "Chrome 설치" -Status "실패" -Message "$_"
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [5/21] 7-Zip 다운로드 및 설치
Write-Host "[5/21] 7-Zip 다운로드 중..." -ForegroundColor Yellow
$sevenZipPaths = @(
    "${env:ProgramFiles}\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
)
$sevenZipInstaller = $null
if (Test-SoftwareInstalled -Name "7-Zip" -Paths $sevenZipPaths) {
    Write-Host "  - 7-Zip : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "7-Zip 다운로드" -Status "스킵됨" -Message "이미 설치됨"
} else {
    try {
        $sevenZipUrl = "https://www.7-zip.org/a/7z2408-x64.msi"
        $sevenZipInstaller = Join-Path $tempDir "7zip_installer.msi"
        Invoke-WebRequest -Uri $sevenZipUrl -OutFile $sevenZipInstaller -UseBasicParsing
        Write-Host "  - 다운로드 완료" -ForegroundColor Green
    } catch {
        Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
        $sevenZipInstaller = $null
        Write-OptLog -Step "7-Zip 다운로드" -Status "실패" -Message "$_"
    }
}

# [6/21] 7-Zip 설치
Write-Host "[6/21] 7-Zip 설치 중..." -ForegroundColor Yellow
if (Test-SoftwareInstalled -Name "7-Zip" -Paths $sevenZipPaths) {
    Write-Host "  - 7-Zip : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "7-Zip 설치" -Status "스킵됨" -Message "이미 설치됨"
} elseif ($sevenZipInstaller -and (Test-Path $sevenZipInstaller)) {
    try {
        Start-Process msiexec -ArgumentList "/i `"$sevenZipInstaller`" /qn" -Wait -NoNewWindow
        Remove-Item $sevenZipInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 7-Zip : 설치됨 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step "7-Zip 설치" -Status "설치됨" -Message "MSI로 설치 완료"
    } catch {
        Write-Host "  - 7-Zip : 설치 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "7-Zip 설치" -Status "실패" -Message "$_"
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [7/21] ShareX 설치 (winget - GitHub API rate limit 회피)
Write-Host "[7/21] ShareX 설치 중 (winget)..." -ForegroundColor Yellow
$shareXPaths = @(
    "${env:ProgramFiles}\ShareX\ShareX.exe"
)
if (Test-SoftwareInstalled -Name "ShareX" -Paths $shareXPaths -WingetId "ShareX.ShareX") {
    Write-Host "  - ShareX : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "ShareX 설치" -Status "스킵됨" -Message "이미 설치됨"
} else {
    try {
        $wingetResult = winget install ShareX.ShareX --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -or $wingetResult -match "already installed") {
            Write-Host "  - ShareX : 설치됨 (적용됨)" -ForegroundColor Green
            Write-OptLog -Step "ShareX 설치" -Status "설치됨" -Message "winget으로 설치 완료"
        } else {
            Write-Host "  - ShareX : 설치 실패" -ForegroundColor Red
            Write-OptLog -Step "ShareX 설치" -Status "실패" -Message "$wingetResult"
        }
    } catch {
        Write-Host "  - ShareX : 설치 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "ShareX 설치" -Status "실패" -Message "$_"
    }
}

# [8/21] ShareX 설정 파일 적용 (업로드 기능 비활성화)
Write-Host "[8/21] ShareX 설정 파일 적용 중..." -ForegroundColor Yellow
$shareXConfigDir = "$env:USERPROFILE\Documents\ShareX"
$shareXConfigPath = "$shareXConfigDir\ApplicationConfig.json"
if (Test-Path $shareXConfigPath) {
    Write-Host "  - ShareX 설정 : 이미 존재함 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "ShareX 설정" -Status "스킵됨" -Message "설정 파일 이미 존재"
} else {
    try {
        $shareXConfigUrl = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Configs/ShareX/ApplicationConfig.json"

        # 설정 디렉토리 생성
        if (!(Test-Path $shareXConfigDir)) {
            New-Item -Path $shareXConfigDir -ItemType Directory -Force | Out-Null
        }

        # 설정 파일 다운로드
        Invoke-WebRequest -Uri $shareXConfigUrl -OutFile $shareXConfigPath -UseBasicParsing
        Write-Host "  - ShareX 설정 : 적용됨 (업로드 비활성화)" -ForegroundColor Green
        Write-OptLog -Step "ShareX 설정" -Status "설치됨" -Message "설정 파일 다운로드 완료"
    } catch {
        Write-Host "  - ShareX 설정 : 적용 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "ShareX 설정" -Status "실패" -Message "$_"
    }
}

# [9/21] ShareX 컨텍스트 메뉴 제거
Write-Host "[9/21] ShareX 컨텍스트 메뉴 제거 중..." -ForegroundColor Yellow
try {
    # ShareX 컨텍스트 메뉴 레지스트리 키 삭제 (모든 파일용)
    $contextMenuPaths = @(
        "HKCR:\*\shell\ShareX",
        "HKLM:\SOFTWARE\Classes\*\shell\ShareX",
        "HKCU:\SOFTWARE\Classes\*\shell\ShareX",
        # Directory 컨텍스트 메뉴
        "HKCR:\Directory\shell\ShareX",
        "HKLM:\SOFTWARE\Classes\Directory\shell\ShareX",
        "HKCU:\SOFTWARE\Classes\Directory\shell\ShareX"
    )

    # HKCR 드라이브 생성 (없는 경우)
    if (-not (Test-Path "HKCR:")) {
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
    }

    $removedCount = 0
    foreach ($path in $contextMenuPaths) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            $removedCount++
        }
    }

    if ($removedCount -gt 0) {
        Write-Host "  - ShareX 컨텍스트 메뉴 : 제거됨 ($removedCount개)" -ForegroundColor Green
        Write-OptLog -Step "ShareX 컨텍스트 메뉴" -Status "설치됨" -Message "$removedCount개 경로 제거됨"
    } else {
        Write-Host "  - ShareX 컨텍스트 메뉴 : 이미 제거됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step "ShareX 컨텍스트 메뉴" -Status "스킵됨" -Message "이미 제거됨"
    }
} catch {
    Write-Host "  - ShareX 컨텍스트 메뉴 : 제거 실패 - $_" -ForegroundColor Red
    Write-OptLog -Step "ShareX 컨텍스트 메뉴" -Status "실패" -Message "$_"
}

# [10/21] ShareX 시작 시 트레이 모드 설정
Write-Host "[10/21] ShareX 시작 프로그램 등록 중..." -ForegroundColor Yellow
$shareXExe = "${env:ProgramFiles}\ShareX\ShareX.exe"
$startupKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$currentShareXStartup = (Get-ItemProperty -Path $startupKey -Name "ShareX" -ErrorAction SilentlyContinue).ShareX

if (Test-Path $shareXExe) {
    $expectedValue = "`"$shareXExe`" -silent"
    if ($currentShareXStartup -eq $expectedValue) {
        Write-Host "  - ShareX 시작 프로그램 : 이미 등록됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step "ShareX 시작 프로그램" -Status "스킵됨" -Message "이미 등록됨"
    } else {
        try {
            Set-ItemProperty -Path $startupKey -Name "ShareX" -Value $expectedValue -Force
            Write-Host "  - ShareX 시작 프로그램 : 등록됨 (트레이 모드)" -ForegroundColor Green
            Write-OptLog -Step "ShareX 시작 프로그램" -Status "설치됨" -Message "트레이 모드로 등록됨"
        } catch {
            Write-Host "  - ShareX 시작 프로그램 : 등록 실패 - $_" -ForegroundColor Red
            Write-OptLog -Step "ShareX 시작 프로그램" -Status "실패" -Message "$_"
        }
    }
} else {
    Write-Host "  - ShareX가 설치되지 않아 건너뜀" -ForegroundColor Yellow
    Write-OptLog -Step "ShareX 시작 프로그램" -Status "스킵됨" -Message "ShareX 미설치"
}

# [11/21] Honeyview 설치 (winget)
Write-Host "[11/21] Honeyview 설치 중 (winget)..." -ForegroundColor Yellow
$honeyviewPaths = @(
    "${env:ProgramFiles}\Honeyview\Honeyview.exe"
)
if (Test-SoftwareInstalled -Name "Honeyview" -Paths $honeyviewPaths -WingetId "Bandisoft.Honeyview") {
    Write-Host "  - Honeyview : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "Honeyview 설치" -Status "스킵됨" -Message "이미 설치됨"
} else {
    try {
        $wingetResult = winget install Bandisoft.Honeyview --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -or $wingetResult -match "already installed") {
            Write-Host "  - Honeyview : 설치됨 (적용됨)" -ForegroundColor Green
            Write-OptLog -Step "Honeyview 설치" -Status "설치됨" -Message "winget으로 설치 완료"
        } else {
            Write-Host "  - Honeyview : 설치 실패" -ForegroundColor Red
            Write-OptLog -Step "Honeyview 설치" -Status "실패" -Message "$wingetResult"
        }
    } catch {
        Write-Host "  - Honeyview : 설치 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "Honeyview 설치" -Status "실패" -Message "$_"
    }
}

# [12/21] Honeyview 설정 적용 (작은 이미지 늘리기, 제목표시줄/컨트롤바 고정 해제)
Write-Host "[12/21] Honeyview 설정 적용 중..." -ForegroundColor Yellow
$honeyviewRegPath = "HKCU:\Software\Honeyview"
$hvCurrentStretch = (Get-ItemProperty -Path $honeyviewRegPath -Name "bStretchWhenSmall" -ErrorAction SilentlyContinue).bStretchWhenSmall

if ($hvCurrentStretch -eq 1) {
    Write-Host "  - Honeyview 설정 : 이미 적용됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "Honeyview 설정" -Status "스킵됨" -Message "이미 적용됨"
} else {
    try {
        if (-not (Test-Path $honeyviewRegPath)) {
            New-Item -Path $honeyviewRegPath -Force | Out-Null
        }
        # bStretchWhenSmall=1: 작은 이미지를 창에 맞게 늘리기
        Set-ItemProperty -Path $honeyviewRegPath -Name "bStretchWhenSmall" -Value 1 -Type DWord -Force
        # bLockTitlebarNormal=0: 제목 표시줄 고정 해제 (자동 숨김)
        Set-ItemProperty -Path $honeyviewRegPath -Name "bLockTitlebarNormal" -Value 0 -Type DWord -Force
        # bLockControlbar=0: 컨트롤바 고정 해제 (자동 숨김)
        Set-ItemProperty -Path $honeyviewRegPath -Name "bLockControlbar" -Value 0 -Type DWord -Force
        # Enter 키로 전체화면 전환 (사용자 정의 단축키)
        Set-ItemProperty -Path $honeyviewRegPath -Name "CustomKey_Enable_00" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $honeyviewRegPath -Name "CustomKey_Key_00" -Value 0x0d -Type DWord -Force  # 0x0d = Enter
        Set-ItemProperty -Path $honeyviewRegPath -Name "CustomKey_Cmd_00" -Value "CMD_FULLSCREEN" -Type String -Force
        Write-Host "  - Honeyview 설정 : 적용됨" -ForegroundColor Green
        Write-Host "    - 작은 이미지 늘리기, 제목/컨트롤바 자동 숨김, Enter=전체화면" -ForegroundColor Gray
        Write-OptLog -Step "Honeyview 설정" -Status "설치됨" -Message "레지스트리 설정 적용됨"
    } catch {
        Write-Host "  - Honeyview 설정 : 적용 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "Honeyview 설정" -Status "실패" -Message "$_"
    }
}

# [13/21] PotPlayer 다운로드 및 설치
Write-Host "[13/21] PotPlayer 다운로드 중..." -ForegroundColor Yellow
$potPlayerPaths = @(
    "${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe"
)
$potPlayerInstaller = $null
if (Test-SoftwareInstalled -Name "PotPlayer" -Paths $potPlayerPaths) {
    Write-Host "  - PotPlayer : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "PotPlayer 다운로드" -Status "스킵됨" -Message "이미 설치됨"
} else {
    try {
        $potPlayerUrl = "https://t1.kakaocdn.net/potplayer/PotPlayer/Version/Latest/PotPlayerSetup64.exe"
        $potPlayerInstaller = Join-Path $tempDir "PotPlayerSetup64.exe"
        Invoke-WebRequest -Uri $potPlayerUrl -OutFile $potPlayerInstaller -UseBasicParsing
        Write-Host "  - 다운로드 완료" -ForegroundColor Green
    } catch {
        Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
        $potPlayerInstaller = $null
        Write-OptLog -Step "PotPlayer 다운로드" -Status "실패" -Message "$_"
    }
}

# [14/21] PotPlayer 설치
Write-Host "[14/21] PotPlayer 설치 중..." -ForegroundColor Yellow
if (Test-SoftwareInstalled -Name "PotPlayer" -Paths $potPlayerPaths) {
    Write-Host "  - PotPlayer : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "PotPlayer 설치" -Status "스킵됨" -Message "이미 설치됨"
} elseif ($potPlayerInstaller -and (Test-Path $potPlayerInstaller)) {
    try {
        Start-Process -FilePath $potPlayerInstaller -ArgumentList "/S" -Wait -NoNewWindow
        Remove-Item $potPlayerInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - PotPlayer : 설치됨 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step "PotPlayer 설치" -Status "설치됨" -Message "Silent 설치 완료"
    } catch {
        Write-Host "  - PotPlayer : 설치 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "PotPlayer 설치" -Status "실패" -Message "$_"
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [15/21] PotPlayer 설정 적용
Write-Host "[15/21] PotPlayer 설정 적용 중..." -ForegroundColor Yellow
$potRegPath = "HKCU:\Software\DAUM\PotPlayerMini64"
$potCurrentUseIni = (Get-ItemProperty -Path $potRegPath -Name "UseIni" -ErrorAction SilentlyContinue).UseIni

if ($potCurrentUseIni -eq 1) {
    Write-Host "  - PotPlayer 설정 : 이미 적용됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "PotPlayer 설정" -Status "스킵됨" -Message "이미 적용됨"
} else {
    try {
        $potPlayerConfigDir = "$env:APPDATA\PotPlayerMini64"
        if (!(Test-Path $potPlayerConfigDir)) {
            New-Item -Path $potPlayerConfigDir -ItemType Directory -Force | Out-Null
        }

        # 레지스트리에 INI 모드 활성화 (PotPlayer가 INI 파일 설정을 사용하도록)
        if (!(Test-Path $potRegPath)) {
            New-Item -Path $potRegPath -Force | Out-Null
        }
        # UseIni=1: INI 파일에 설정 저장, CheckAutoUpdate=0: 자동 업데이트 체크 비활성화
        Set-ItemProperty -Path $potRegPath -Name "UseIni" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $potRegPath -Name "CheckAutoUpdate" -Value 0 -Type DWord -Force

        # 재생목록/방송목록 창 숨김 설정
        $potPositionsPath = "HKCU:\Software\DAUM\PotPlayer64\Positions"
        if (-not (Test-Path $potPositionsPath)) {
            New-Item -Path $potPositionsPath -Force | Out-Null
        }
        Set-ItemProperty -Path $potPositionsPath -Name "ChatWindowVisible" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $potPositionsPath -Name "PlayListWindowVisible" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $potPositionsPath -Name "BroadcastListWindowVisible" -Value 0 -Type DWord -Force

        # 단축키 설정 (F1~F5 북마크, Ctrl+W 종료)
        $potShortCutPath = "HKCU:\Software\DAUM\PotPlayer64\MainShortCutList"
        if (-not (Test-Path $potShortCutPath)) {
            New-Item -Path $potShortCutPath -Force | Out-Null
        }
        Set-ItemProperty -Path $potShortCutPath -Name "0" -Value "112,6,10281,1" -Type String -Force
        Set-ItemProperty -Path $potShortCutPath -Name "1" -Value "113,6,10282,1" -Type String -Force
        Set-ItemProperty -Path $potShortCutPath -Name "2" -Value "114,6,10283,1" -Type String -Force
        Set-ItemProperty -Path $potShortCutPath -Name "3" -Value "115,6,10284,1" -Type String -Force
        Set-ItemProperty -Path $potShortCutPath -Name "4" -Value "116,6,10285,1" -Type String -Force
        Set-ItemProperty -Path $potShortCutPath -Name "5" -Value "87,2,57665,0" -Type String -Force
        Set-ItemProperty -Path $potShortCutPath -Name "6" -Value "" -Type String -Force

        # INI 파일 다운로드 (외부 설정 파일 사용)
        $iniPath = "$potPlayerConfigDir\PotPlayerMini64.ini"
        $potPlayerConfigUrl = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Configs/PotPlayer/PotPlayerMini64.ini"
        Invoke-WebRequest -Uri $potPlayerConfigUrl -OutFile $iniPath -UseBasicParsing

        Write-Host "  - PotPlayer 설정 : 적용됨" -ForegroundColor Green
        Write-Host "    - INI 모드, 단축키, 창 숨김 설정됨" -ForegroundColor Gray
        Write-OptLog -Step "PotPlayer 설정" -Status "설치됨" -Message "레지스트리 및 INI 설정 적용됨"
    } catch {
        Write-Host "  - PotPlayer 설정 : 적용 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "PotPlayer 설정" -Status "실패" -Message "$_"
    }
}

# [16/21] SetUserFTA 다운로드 (파일 연결 도구)
# SetUserFTA by Christoph Kolbicz - Personal Edition (비상업적/테스트 목적)
# 라이선스: https://github.com/Zeliper/windows-11-optimization/blob/main/LICENSES/SetUserFTA.md
Write-Host "[16/21] SetUserFTA 다운로드 중..." -ForegroundColor Yellow
$setUserFtaPath = Join-Path $tempDir "SetUserFTA.exe"
$setUserFtaUrl = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Utils/SetUserFTA.exe"

try {
    Invoke-WebRequest -Uri $setUserFtaUrl -OutFile $setUserFtaPath -UseBasicParsing -TimeoutSec 30
    if (Test-Path $setUserFtaPath) {
        Write-Host "  - SetUserFTA : 다운로드 완료" -ForegroundColor Green
    } else {
        Write-Host "  - SetUserFTA : 다운로드 실패" -ForegroundColor Red
        $setUserFtaPath = $null
    }
} catch {
    Write-Host "  - SetUserFTA : 다운로드 실패 - $_" -ForegroundColor Red
    Write-Host "  - 파일 연결 설정을 건너뜁니다 (수동 설정 필요)" -ForegroundColor Yellow
    $setUserFtaPath = $null
}

# [17/21] Notepad++ 파일 연결 설정 (SetUserFTA 병렬 실행)
Write-Host "[17/21] Notepad++ 파일 연결 설정 중..." -ForegroundColor Yellow
$nppPath = "${env:ProgramFiles}\Notepad++\notepad++.exe"
if ((Test-Path $nppPath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
    # 연결할 확장자 목록 (실행 스크립트 제외: .bat, .cmd, .ps1, .vbs 등)
    $extensions = @(
        ".txt", ".ini", ".cfg", ".conf", ".config",
        ".properties", ".property", ".log", ".md",
        ".json", ".xml", ".yaml", ".yml",
        ".sql", ".csv", ".tsv", ".sh"
    )

    # ProgId를 HKCU\SOFTWARE\Classes에 등록 (사용자별 설정)
    $progId = "Notepad++_file"

    # 이미 모든 확장자가 Notepad++로 연결되어 있는지 확인
    $alreadySet = $true
    foreach ($ext in $extensions) {
        if (-not (Test-FileAssociation -Extension $ext -ExpectedProgId $progId)) {
            $alreadySet = $false
            break
        }
    }

    if ($alreadySet) {
        Write-Host "  - Notepad++ 파일 연결 : 이미 설정됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step "Notepad++ 파일 연결" -Status "스킵됨" -Message "이미 모든 확장자가 Notepad++로 연결됨"
    } else {
        $hkcuClassesPath = "HKCU:\SOFTWARE\Classes\$progId"

        try {
            if (-not (Test-Path $hkcuClassesPath)) {
                New-Item -Path $hkcuClassesPath -Force | Out-Null
                New-Item -Path "$hkcuClassesPath\shell\open\command" -Force | Out-Null
            }
            Set-ItemProperty -Path $hkcuClassesPath -Name "(Default)" -Value "Notepad++ Document" -Force
            Set-ItemProperty -Path "$hkcuClassesPath\shell\open\command" -Name "(Default)" -Value "`"$nppPath`" `"%1`"" -Force

            # OpenWithProgids 정리 및 ProgId 추가
            foreach ($ext in $extensions) {
                $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                $openWithProgids = "$fileExtPath\OpenWithProgids"
                if (-not (Test-Path $openWithProgids)) {
                    New-Item -Path $openWithProgids -Force | Out-Null
                }
                # 기존 ProgId 제거
                $existingProps = Get-ItemProperty -Path $openWithProgids -ErrorAction SilentlyContinue
                if ($existingProps) {
                    foreach ($prop in $existingProps.PSObject.Properties) {
                        if ($prop.Name -notlike "PS*") {
                            Remove-ItemProperty -Path $openWithProgids -Name $prop.Name -ErrorAction SilentlyContinue
                        }
                    }
                }
                # 우리 ProgId만 추가
                New-ItemProperty -Path $openWithProgids -Name $progId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null
            }

            # SetUserFTA 순차 실행
            $setCount = 0
            foreach ($ext in $extensions) {
                $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                if ($result -and $result.ExitCode -eq 0) { $setCount++ }
            }
            Write-Host "  - Notepad++ 파일 연결 : $setCount/$($extensions.Count)개 확장자 (적용됨)" -ForegroundColor Green
            Write-OptLog -Step "Notepad++ 파일 연결" -Status "설치됨" -Message "$setCount/$($extensions.Count)개 확장자 연결됨"
        } catch {
            Write-Host "  - Notepad++ 파일 연결 : 실패 - $_" -ForegroundColor Red
            Write-OptLog -Step "Notepad++ 파일 연결" -Status "실패" -Message "$_"
        }
    }
} elseif (!(Test-Path $nppPath)) {
    Write-Host "  - Notepad++ 파일 연결 : 건너뜀 (Notepad++ 미설치)" -ForegroundColor Gray
    Write-OptLog -Step "Notepad++ 파일 연결" -Status "스킵됨" -Message "Notepad++ 미설치"
} else {
    Write-Host "  - Notepad++ 파일 연결 : 건너뜀 (SetUserFTA 없음)" -ForegroundColor Gray
    Write-OptLog -Step "Notepad++ 파일 연결" -Status "스킵됨" -Message "SetUserFTA 없음"
}

# [18/21] Honeyview 이미지 파일 연결 설정 (Honeyview.{ext} ProgId 사용)
Write-Host "[18/21] Honeyview 이미지 파일 연결 설정 중..." -ForegroundColor Yellow
try {
    # Windows 사진 앱 제거 (파일 연결 충돌 방지)
    $photosApp = Get-AppxPackage -Name "Microsoft.Windows.Photos" -ErrorAction SilentlyContinue
    if ($photosApp) {
        try {
            $photosApp | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Host "  - Windows 사진 앱 제거됨" -ForegroundColor Green
        } catch {
            Write-Host "  - 사진 앱 제거 실패 (수동 제거 필요)" -ForegroundColor Yellow
        }
    }

    # 프로비저닝된 사진 앱도 제거 (새 사용자 설치 방지)
    $photosProvisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like "*Photos*" }
    if ($photosProvisioned) {
        try {
            $photosProvisioned | ForEach-Object {
                Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
            }
            Write-Host "  - 사진 앱 프로비저닝 제거됨" -ForegroundColor Green
        } catch {
            # 무시
        }
    }

    $honeyviewPath = "${env:ProgramFiles}\Honeyview\Honeyview.exe"
    if ((Test-Path $honeyviewPath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
        # 이미지 확장자 목록 (Honeyview가 지원하는 확장자 기준)
        $imageExtensions = @(
            ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".ico", ".webp",
            ".tiff", ".tif", ".heic", ".heif", ".avif",
            ".cr2", ".nef", ".arw", ".dng", ".orf", ".rw2",
            ".psd", ".jfif", ".jpe", ".wdp", ".jxr"
        )

        # 이미 모든 이미지 확장자가 Honeyview로 연결되어 있는지 확인
        $alreadySet = $true
        foreach ($ext in $imageExtensions) {
            $extWithoutDot = $ext.TrimStart(".")
            if (-not (Test-FileAssociation -Extension $ext -ExpectedProgId "Honeyview.$extWithoutDot")) {
                $alreadySet = $false
                break
            }
        }

        if ($alreadySet) {
            Write-Host "  - Honeyview 이미지 연결 : 이미 설정됨 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step "Honeyview 이미지 연결" -Status "스킵됨" -Message "이미 모든 이미지가 Honeyview로 연결됨"
        } else {
            # OpenWithProgids 정리: Honeyview.{ext} ProgId만 남기고 경쟁 앱 모두 제거
            foreach ($ext in $imageExtensions) {
                $extWithoutDot = $ext.TrimStart(".")
                $honeyviewProgId = "Honeyview.$extWithoutDot"

                $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                $openWithProgids = "$fileExtPath\OpenWithProgids"

                # OpenWithProgids 키가 없으면 생성
                if (-not (Test-Path $openWithProgids)) {
                    New-Item -Path $openWithProgids -Force | Out-Null
                }

                # 기존 모든 ProgId 제거 (경쟁 앱 완전 제거)
                $existingProps = Get-ItemProperty -Path $openWithProgids -ErrorAction SilentlyContinue
                if ($existingProps) {
                    foreach ($prop in $existingProps.PSObject.Properties) {
                        if ($prop.Name -notlike "PS*") {  # PowerShell 내부 속성 제외
                            Remove-ItemProperty -Path $openWithProgids -Name $prop.Name -ErrorAction SilentlyContinue
                        }
                    }
                }

                # Honeyview.{ext} ProgId만 추가 (Honeyview 설치 시 등록된 ProgId 사용)
                New-ItemProperty -Path $openWithProgids -Name $honeyviewProgId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null

                # OpenWithList도 정리
                $openWithList = "$fileExtPath\OpenWithList"
                if (Test-Path $openWithList) {
                    Remove-Item -Path $openWithList -Recurse -Force -ErrorAction SilentlyContinue
                }

                # UserChoice 키 삭제 (SetUserFTA가 새로 생성하도록)
                $userChoice = "$fileExtPath\UserChoice"
                if (Test-Path $userChoice) {
                    try {
                        $acl = Get-Acl -Path $userChoice
                        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
                            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                            "FullControl",
                            "Allow"
                        )
                        $acl.SetAccessRule($rule)
                        Set-Acl -Path $userChoice -AclObject $acl -ErrorAction SilentlyContinue
                        Remove-Item -Path $userChoice -Recurse -Force -ErrorAction SilentlyContinue
                    } catch {
                        # 권한 변경 실패해도 계속 진행
                    }
                }
            }

            # SetUserFTA로 각 확장자에 Honeyview.{ext} ProgId 연결
            $setCount = 0
            foreach ($ext in $imageExtensions) {
                $extWithoutDot = $ext.TrimStart(".")
                $honeyviewProgId = "Honeyview.$extWithoutDot"
                $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $honeyviewProgId" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                if ($result -and $result.ExitCode -eq 0) { $setCount++ }
            }
            Write-Host "  - Honeyview 이미지 연결 : $setCount/$($imageExtensions.Count)개 확장자 (적용됨)" -ForegroundColor Green
            Write-OptLog -Step "Honeyview 이미지 연결" -Status "설치됨" -Message "$setCount/$($imageExtensions.Count)개 확장자 연결됨"
        }
    } elseif (!(Test-Path $honeyviewPath)) {
        Write-Host "  - Honeyview 이미지 연결 : 건너뜀 (Honeyview 미설치)" -ForegroundColor Gray
        Write-OptLog -Step "Honeyview 이미지 연결" -Status "스킵됨" -Message "Honeyview 미설치"
    } else {
        Write-Host "  - Honeyview 이미지 연결 : 건너뜀 (SetUserFTA 없음)" -ForegroundColor Gray
        Write-OptLog -Step "Honeyview 이미지 연결" -Status "스킵됨" -Message "SetUserFTA 없음"
    }
} catch {
    Write-Host "  - Honeyview 이미지 연결 : 실패 - $_" -ForegroundColor Red
    Write-OptLog -Step "Honeyview 이미지 연결" -Status "실패" -Message "$_"
}

# [19/21] PotPlayer 동영상/오디오 파일 연결 (SetUserFTA 사용, PotPlayer 자체 ProgId 활용)
Write-Host "[19/21] PotPlayer 동영상/오디오 파일 연결 설정 중..." -ForegroundColor Yellow
$potPlayerPath = "${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe"
if ((Test-Path $potPlayerPath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
    try {
        # 동영상 확장자 목록
        $videoExtensions = @(
            ".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm",
            ".m4v", ".mpg", ".mpeg", ".ts", ".3gp", ".m2ts", ".vob"
        )

        # 오디오 확장자 목록
        $audioExtensions = @(
            ".mp3", ".flac", ".wav", ".aac", ".ogg", ".wma", ".m4a",
            ".opus", ".aiff", ".ape", ".alac", ".dsd", ".dsf", ".dff"
        )

        # 전체 미디어 확장자
        $mediaExtensions = $videoExtensions + $audioExtensions

        # 이미 모든 미디어 확장자가 PotPlayer로 연결되어 있는지 확인
        $alreadySet = $true
        foreach ($ext in $mediaExtensions) {
            $extWithoutDot = $ext.TrimStart(".")
            if (-not (Test-FileAssociation -Extension $ext -ExpectedProgId "PotPlayer64.$extWithoutDot")) {
                $alreadySet = $false
                break
            }
        }

        if ($alreadySet) {
            Write-Host "  - PotPlayer 미디어 연결 : 이미 설정됨 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step "PotPlayer 미디어 연결" -Status "스킵됨" -Message "이미 모든 미디어가 PotPlayer로 연결됨"
        } else {
            # OpenWithProgids 정리: PotPlayer64.{ext} ProgId만 남기고 경쟁 앱 모두 제거 (Honeyview 방식)
            foreach ($ext in $mediaExtensions) {
                $extWithoutDot = $ext.TrimStart(".")
                $potPlayerProgId = "PotPlayer64.$extWithoutDot"

                $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                $openWithProgids = "$fileExtPath\OpenWithProgids"

                # OpenWithProgids 키가 없으면 생성
                if (-not (Test-Path $openWithProgids)) {
                    New-Item -Path $openWithProgids -Force | Out-Null
                }

                # 기존 모든 ProgId 제거 (경쟁 앱 완전 제거)
                $existingProps = Get-ItemProperty -Path $openWithProgids -ErrorAction SilentlyContinue
                if ($existingProps) {
                    foreach ($prop in $existingProps.PSObject.Properties) {
                        if ($prop.Name -notlike "PS*") {
                            Remove-ItemProperty -Path $openWithProgids -Name $prop.Name -ErrorAction SilentlyContinue
                        }
                    }
                }

                # PotPlayer64.{ext} ProgId만 추가 (PotPlayer 설치 시 등록된 ProgId 사용)
                New-ItemProperty -Path $openWithProgids -Name $potPlayerProgId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null

                # OpenWithList도 정리
                $openWithList = "$fileExtPath\OpenWithList"
                if (Test-Path $openWithList) {
                    Remove-Item -Path $openWithList -Recurse -Force -ErrorAction SilentlyContinue
                }

                # UserChoice 키 삭제 (SetUserFTA가 새로 생성하도록)
                $userChoice = "$fileExtPath\UserChoice"
                if (Test-Path $userChoice) {
                    try {
                        $acl = Get-Acl -Path $userChoice
                        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
                            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                            "FullControl",
                            "Allow"
                        )
                        $acl.SetAccessRule($rule)
                        Set-Acl -Path $userChoice -AclObject $acl -ErrorAction SilentlyContinue
                        Remove-Item -Path $userChoice -Recurse -Force -ErrorAction SilentlyContinue
                    } catch {
                        # 권한 변경 실패해도 계속 진행
                    }
                }
            }

            # SetUserFTA로 각 확장자에 PotPlayer64.{ext} ProgId 연결
            $setCount = 0
            foreach ($ext in $mediaExtensions) {
                $extWithoutDot = $ext.TrimStart(".")
                $potPlayerProgId = "PotPlayer64.$extWithoutDot"
                $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $potPlayerProgId" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
                if ($result -and $result.ExitCode -eq 0) { $setCount++ }
            }
            Write-Host "  - PotPlayer 미디어 연결 : $setCount/$($mediaExtensions.Count)개 확장자 (적용됨)" -ForegroundColor Green
            Write-Host "    - 동영상: $($videoExtensions.Count)개, 오디오: $($audioExtensions.Count)개" -ForegroundColor Gray
            Write-OptLog -Step "PotPlayer 미디어 연결" -Status "설치됨" -Message "$setCount/$($mediaExtensions.Count)개 확장자 연결됨"
        }
    } catch {
        Write-Host "  - PotPlayer 미디어 연결 : 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "PotPlayer 미디어 연결" -Status "실패" -Message "$_"
    }
} elseif (!(Test-Path $potPlayerPath)) {
    Write-Host "  - PotPlayer 미디어 연결 : 건너뜀 (PotPlayer 미설치)" -ForegroundColor Gray
    Write-OptLog -Step "PotPlayer 미디어 연결" -Status "스킵됨" -Message "PotPlayer 미설치"
} else {
    Write-Host "  - PotPlayer 미디어 연결 : 건너뜀 (SetUserFTA 없음)" -ForegroundColor Gray
    Write-OptLog -Step "PotPlayer 미디어 연결" -Status "스킵됨" -Message "SetUserFTA 없음"
}

# [20/21] Chrome 기본 브라우저 설정 (SetUserFTA 사용)
Write-Host "[20/21] Chrome 기본 브라우저 설정 중..." -ForegroundColor Yellow
$chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
if ((Test-Path $chromePath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
    try {
        # ChromeHTML ProgId 존재 확인
        $chromeProgId = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\ChromeHTML" -ErrorAction SilentlyContinue
        if (-not $chromeProgId) {
            $chromeProgId = Get-ItemProperty -Path "HKCU:\SOFTWARE\Classes\ChromeHTML" -ErrorAction SilentlyContinue
        }

        if ($chromeProgId) {
            # 이미 Chrome이 기본 브라우저로 설정되어 있는지 확인
            $httpAlreadySet = Test-ProtocolAssociation -Protocol "http" -ExpectedProgId "ChromeHTML"
            $httpsAlreadySet = Test-ProtocolAssociation -Protocol "https" -ExpectedProgId "ChromeHTML"
            $htmlAlreadySet = Test-FileAssociation -Extension ".html" -ExpectedProgId "ChromeHTML"

            if ($httpAlreadySet -and $httpsAlreadySet -and $htmlAlreadySet) {
                Write-Host "  - Chrome 기본 브라우저 : 이미 설정됨 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "Chrome 기본 브라우저" -Status "스킵됨" -Message "이미 Chrome이 기본 브라우저로 설정됨"
            } else {
                # http/https 프로토콜 OpenWithProgids 정리 (Honeyview 방식 - 경쟁 앱 완전 제거)
                foreach ($protocol in @("http", "https")) {
                $urlAssocPath = "HKCU:\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$protocol"
                $openWithProgids = "$urlAssocPath\OpenWithProgids"

                # OpenWithProgids 키가 없으면 생성
                if (-not (Test-Path $openWithProgids)) {
                    New-Item -Path $openWithProgids -Force | Out-Null
                }

                # 기존 모든 ProgId 제거 (경쟁 앱 완전 제거)
                $existingProps = Get-ItemProperty -Path $openWithProgids -ErrorAction SilentlyContinue
                if ($existingProps) {
                    foreach ($prop in $existingProps.PSObject.Properties) {
                        if ($prop.Name -notlike "PS*") {
                            Remove-ItemProperty -Path $openWithProgids -Name $prop.Name -ErrorAction SilentlyContinue
                        }
                    }
                }

                # ChromeHTML ProgId만 추가
                New-ItemProperty -Path $openWithProgids -Name "ChromeHTML" -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null

                # OpenWithList도 정리
                $openWithList = "$urlAssocPath\OpenWithList"
                if (Test-Path $openWithList) {
                    Remove-Item -Path $openWithList -Recurse -Force -ErrorAction SilentlyContinue
                }

                # UserChoice 키 삭제 (SetUserFTA가 새로 생성하도록)
                $userChoice = "$urlAssocPath\UserChoice"
                if (Test-Path $userChoice) {
                    try {
                        $acl = Get-Acl -Path $userChoice
                        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
                            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
                            "FullControl",
                            "Allow"
                        )
                        $acl.SetAccessRule($rule)
                        Set-Acl -Path $userChoice -AclObject $acl -ErrorAction SilentlyContinue
                        Remove-Item -Path $userChoice -Recurse -Force -ErrorAction SilentlyContinue
                    } catch {
                        # 권한 변경 실패해도 계속 진행
                    }
                }
            }

            # Edge ProgId 삭제 (UserChoice 보호 우회 - SetUserFTA가 작동하도록)
            # 주의: Edge를 사용하지 않는 경우에만 안전함
            $edgeProgIdsToDelete = @("MSEdgeHTM", "MSEdgeMHT", "MSEdgePDF")
            foreach ($progId in $edgeProgIdsToDelete) {
                $progIdPath = "HKLM:\SOFTWARE\Classes\$progId"
                if (Test-Path $progIdPath) {
                    try {
                        # reg.exe로 삭제 (PowerShell보다 권한 처리가 나음)
                        $regResult = & reg delete "HKLM\SOFTWARE\Classes\$progId" /f 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  - $progId ProgId 삭제됨" -ForegroundColor Green
                        }
                    } catch {
                        # 삭제 실패해도 계속 진행
                    }
                }
            }

            # Edge를 연결 프로그램 목록에서 제거 (선택 창 방지)
            $edgeProgIds = @("MSEdgeHTM", "MSEdgePDF", "MSEdgeMHT", "AppXq0fevzme2pys62n3e0fbqa7peapykr8v")

            # .html, .htm 확장자에서 Edge 제거 (.url은 InternetShortcut으로 유지)
            foreach ($ext in @(".html", ".htm")) {
                $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                $openWithProgids = "$fileExtPath\OpenWithProgids"
                if (Test-Path $openWithProgids) {
                    foreach ($edgeId in $edgeProgIds) {
                        Remove-ItemProperty -Path $openWithProgids -Name $edgeId -ErrorAction SilentlyContinue
                    }
                }
                $openWithList = "$fileExtPath\OpenWithList"
                if (Test-Path $openWithList) {
                    $props = Get-ItemProperty -Path $openWithList -ErrorAction SilentlyContinue
                    foreach ($prop in $props.PSObject.Properties) {
                        if ($prop.Value -like "*edge*" -or $prop.Value -like "*MSEdge*") {
                            Remove-ItemProperty -Path $openWithList -Name $prop.Name -ErrorAction SilentlyContinue
                        }
                    }
                }
            }

            # SetUserFTA로 Chrome을 기본 브라우저로 설정
            # 파일 확장자 (.html, .htm만 - .url은 InternetShortcut으로 유지해야 정상 작동)
            $fileAssocs = @(".html", ".htm")
            $fileSuccessCount = 0
            foreach ($ext in $fileAssocs) {
                $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext ChromeHTML" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                if ($result.ExitCode -eq 0) { $fileSuccessCount++ }
            }

            # URL 프로토콜 (http, https) - SetUserFTA로 설정 (UserChoice는 위에서 이미 삭제됨)
            $protocolAssocs = @("http", "https")
            $protocolSuccessCount = 0
            foreach ($protocol in $protocolAssocs) {
                $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$protocol ChromeHTML" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                if ($result.ExitCode -eq 0) { $protocolSuccessCount++ }
            }

            # HKCR 프로토콜 핸들러 설정 (앱에서 URL 클릭 시 Chrome으로 열리도록)
            if (-not (Test-Path "HKCR:")) {
                New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
            }
            foreach ($protocol in @("http", "https")) {
                try {
                    # HKCR 프로토콜 핸들러 command 설정
                    $hkcrPath = "HKCR:\$protocol\shell\open\command"
                    if (Test-Path $hkcrPath) {
                        Set-ItemProperty -Path $hkcrPath -Name "(Default)" -Value "`"$chromePath`" -- `"%1`"" -Force -ErrorAction SilentlyContinue
                    }
                    # HKCU Classes에도 설정 (사용자별 우선순위)
                    $hkcuPath = "HKCU:\SOFTWARE\Classes\$protocol\shell\open\command"
                    if (-not (Test-Path $hkcuPath)) {
                        New-Item -Path $hkcuPath -Force | Out-Null
                    }
                    Set-ItemProperty -Path $hkcuPath -Name "(Default)" -Value "`"$chromePath`" -- `"%1`"" -Force
                } catch {
                    # 실패해도 계속 진행
                }
            }

            $totalSuccess = $fileSuccessCount + $protocolSuccessCount
            $totalAssocs = $fileAssocs.Count + $protocolAssocs.Count
                if ($totalSuccess -eq $totalAssocs) {
                    Write-Host "  - Chrome 기본 브라우저 : 설정 완료 ($totalSuccess/$totalAssocs)" -ForegroundColor Green
                    Write-OptLog -Step "Chrome 기본 브라우저" -Status "설치됨" -Message "$totalSuccess/$totalAssocs 연결 완료"
                } else {
                    Write-Host "  - Chrome 기본 브라우저 : 일부 설정 완료 ($totalSuccess/$totalAssocs)" -ForegroundColor Yellow
                    Write-Host "  - 수동 설정 필요: 설정 > 앱 > 기본 앱 > Google Chrome" -ForegroundColor Cyan
                    Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue
                    Write-OptLog -Step "Chrome 기본 브라우저" -Status "설치됨" -Message "$totalSuccess/$totalAssocs 연결 완료 (일부 실패)"
                }
            }
        } else {
            Write-Host "  - Chrome 기본 브라우저 : ChromeHTML ProgId 없음" -ForegroundColor Yellow
            Write-Host "  - 수동 설정 필요: 설정 > 앱 > 기본 앱 > Google Chrome" -ForegroundColor Cyan
            Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue
            Write-OptLog -Step "Chrome 기본 브라우저" -Status "스킵됨" -Message "ChromeHTML ProgId 없음"
        }
    } catch {
        Write-Host "  - Chrome 기본 브라우저 : 설정 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "Chrome 기본 브라우저" -Status "실패" -Message "$_"
    }
} elseif (!(Test-Path $chromePath)) {
    Write-Host "  - Chrome 기본 브라우저 : 건너뜀 (Chrome 미설치)" -ForegroundColor Gray
    Write-OptLog -Step "Chrome 기본 브라우저" -Status "스킵됨" -Message "Chrome 미설치"
} else {
    Write-Host "  - Chrome 기본 브라우저 : 건너뜀 (SetUserFTA 없음)" -ForegroundColor Gray
    Write-OptLog -Step "Chrome 기본 브라우저" -Status "스킵됨" -Message "SetUserFTA 없음"
}

# [21/21] Everything 설치 (winget)
Write-Host "[21/21] Everything 설치 중 (winget)..." -ForegroundColor Yellow
$everythingPaths = @(
    "${env:ProgramFiles}\Everything\Everything.exe",
    "${env:ProgramFiles(x86)}\Everything\Everything.exe"
)
if (Test-SoftwareInstalled -Name "Everything" -Paths $everythingPaths -WingetId "voidtools.Everything") {
    Write-Host "  - Everything : 이미 설치됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step "Everything 설치" -Status "스킵됨" -Message "이미 설치됨"
} else {
    try {
        $wingetResult = winget install voidtools.Everything --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0 -or $wingetResult -match "already installed") {
            Write-Host "  - Everything : 설치됨 (적용됨)" -ForegroundColor Green
            Write-OptLog -Step "Everything 설치" -Status "설치됨" -Message "winget으로 설치 완료"
        } else {
            Write-Host "  - Everything : 설치 실패" -ForegroundColor Red
            Write-OptLog -Step "Everything 설치" -Status "실패" -Message "$wingetResult"
        }
    } catch {
        Write-Host "  - Everything : 설치 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step "Everything 설치" -Status "실패" -Message "$_"
    }
}

# ===== 로그 저장 =====
Save-OptLog

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "소프트웨어 설치가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 설치됨: $global:InstalledCount 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount 개 (이미 설치됨)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount 개" -ForegroundColor $(if ($global:FailedCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
