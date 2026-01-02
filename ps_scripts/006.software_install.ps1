# 필수 소프트웨어 자동 설치 (Notepad++, Chrome, 7-Zip, ShareX)
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

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

Write-Host "=== 필수 소프트웨어 자동 설치 ===" -ForegroundColor Cyan
Write-Host "Notepad++, Chrome, 7-Zip, ShareX를 자동으로 설치합니다." -ForegroundColor White
Write-Host ""

$tempDir = $env:TEMP
$successCount = 0
$failCount = 0

# [1/12] Notepad++ 다운로드
Write-Host "[1/12] Notepad++ 다운로드 중..." -ForegroundColor Yellow
try {
    $nppRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest"
    $nppAsset = $nppRelease.assets | Where-Object { $_.name -match "npp.*Installer\.x64\.exe$" } | Select-Object -First 1
    $nppUrl = $nppAsset.browser_download_url
    $nppInstaller = Join-Path $tempDir "npp_installer.exe"
    Invoke-WebRequest -Uri $nppUrl -OutFile $nppInstaller -UseBasicParsing
    Write-Host "  - 다운로드 완료: $($nppAsset.name)" -ForegroundColor Green
} catch {
    Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
    $nppInstaller = $null
    $failCount++
}

# [2/12] Notepad++ 설치
Write-Host "[2/12] Notepad++ 설치 중..." -ForegroundColor Yellow
if ($nppInstaller -and (Test-Path $nppInstaller)) {
    try {
        Start-Process -FilePath $nppInstaller -ArgumentList "/S" -Wait -NoNewWindow
        Remove-Item $nppInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  - 설치 실패: $_" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [3/12] Chrome 다운로드
Write-Host "[3/12] Chrome 다운로드 중..." -ForegroundColor Yellow
try {
    $chromeUrl = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
    $chromeInstaller = Join-Path $tempDir "chrome_installer.msi"
    Invoke-WebRequest -Uri $chromeUrl -OutFile $chromeInstaller -UseBasicParsing
    Write-Host "  - 다운로드 완료" -ForegroundColor Green
} catch {
    Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
    $chromeInstaller = $null
    $failCount++
}

# [4/12] Chrome 설치
Write-Host "[4/12] Chrome 설치 중..." -ForegroundColor Yellow
if ($chromeInstaller -and (Test-Path $chromeInstaller)) {
    try {
        Start-Process msiexec -ArgumentList "/i `"$chromeInstaller`" /qn /norestart" -Wait -NoNewWindow
        Remove-Item $chromeInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  - 설치 실패: $_" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [5/12] 7-Zip 다운로드
Write-Host "[5/12] 7-Zip 다운로드 중..." -ForegroundColor Yellow
try {
    $sevenZipUrl = "https://www.7-zip.org/a/7z2408-x64.msi"
    $sevenZipInstaller = Join-Path $tempDir "7zip_installer.msi"
    Invoke-WebRequest -Uri $sevenZipUrl -OutFile $sevenZipInstaller -UseBasicParsing
    Write-Host "  - 다운로드 완료" -ForegroundColor Green
} catch {
    Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
    $sevenZipInstaller = $null
    $failCount++
}

# [6/12] 7-Zip 설치
Write-Host "[6/12] 7-Zip 설치 중..." -ForegroundColor Yellow
if ($sevenZipInstaller -and (Test-Path $sevenZipInstaller)) {
    try {
        Start-Process msiexec -ArgumentList "/i `"$sevenZipInstaller`" /qn" -Wait -NoNewWindow
        Remove-Item $sevenZipInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  - 설치 실패: $_" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [7/12] ShareX 다운로드
Write-Host "[7/12] ShareX 다운로드 중..." -ForegroundColor Yellow
try {
    $shareXRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/ShareX/ShareX/releases/latest"
    $shareXAsset = $shareXRelease.assets | Where-Object { $_.name -match "ShareX-.*-setup\.exe$" } | Select-Object -First 1
    $shareXUrl = $shareXAsset.browser_download_url
    $shareXInstaller = Join-Path $tempDir "sharex_installer.exe"
    Invoke-WebRequest -Uri $shareXUrl -OutFile $shareXInstaller -UseBasicParsing
    Write-Host "  - 다운로드 완료: $($shareXAsset.name)" -ForegroundColor Green
} catch {
    Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
    $shareXInstaller = $null
    $failCount++
}

# [8/12] ShareX 설치 (업로드 기능 비활성화)
Write-Host "[8/12] ShareX 설치 중 (업로드 기능 비활성화)..." -ForegroundColor Yellow
if ($shareXInstaller -and (Test-Path $shareXInstaller)) {
    try {
        # ShareX 설치
        Start-Process -FilePath $shareXInstaller -ArgumentList "/SP- /VERYSILENT /NORESTART /NORUN /SUPPRESSMSGBOXES" -Wait -NoNewWindow
        Remove-Item $shareXInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++

        # 업로드 비활성화 설정 (JSON 설정 파일)
        $shareXConfigDir = "$env:APPDATA\ShareX"
        $shareXConfigPath = "$shareXConfigDir\ApplicationConfig.json"
        if (!(Test-Path $shareXConfigDir)) {
            New-Item -Path $shareXConfigDir -ItemType Directory -Force | Out-Null
        }
        $config = @{
            "DisableUploadActions" = $true
            "ShowAfterUploadForm" = $false
        }
        $config | ConvertTo-Json | Set-Content -Path $shareXConfigPath -Encoding UTF8 -Force
        Write-Host "  - 업로드 기능 비활성화 설정 완료" -ForegroundColor Green
    } catch {
        Write-Host "  - 설치 실패: $_" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [9/12] ShareX 컨텍스트 메뉴 제거
Write-Host "[9/12] ShareX 컨텍스트 메뉴 제거 중..." -ForegroundColor Yellow
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

    foreach ($path in $contextMenuPaths) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  - 컨텍스트 메뉴 제거 완료" -ForegroundColor Green
} catch {
    Write-Host "  - 컨텍스트 메뉴 제거 실패: $_" -ForegroundColor Red
}

# [10/12] ShareX 시작 시 트레이 모드 설정
Write-Host "[10/12] ShareX 시작 프로그램 등록 중..." -ForegroundColor Yellow
try {
    $shareXExe = "${env:ProgramFiles}\ShareX\ShareX.exe"
    if (Test-Path $shareXExe) {
        # 시작 프로그램에 ShareX 등록 (-silent 옵션으로 트레이에서 시작)
        $startupKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $startupKey -Name "ShareX" -Value "`"$shareXExe`" -silent" -Force
        Write-Host "  - 시작 프로그램 등록 완료 (트레이 모드)" -ForegroundColor Green
    } else {
        Write-Host "  - ShareX가 설치되지 않아 건너뜀" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  - 시작 프로그램 등록 실패: $_" -ForegroundColor Red
}

# [11/12] Notepad++ 파일 연결 설정
Write-Host "[11/12] Notepad++ 파일 연결 설정 중..." -ForegroundColor Yellow
try {
    $nppPath = "${env:ProgramFiles}\Notepad++\notepad++.exe"
    if (Test-Path $nppPath) {
        # 연결할 확장자 목록 (실행 스크립트 제외: .bat, .cmd, .ps1, .vbs 등)
        $extensions = @(
            ".txt", ".ini", ".cfg", ".conf", ".config",
            ".properties", ".property", ".log", ".md",
            ".json", ".xml", ".yaml", ".yml",
            ".sql", ".csv", ".tsv", ".sh"
        )

        # ftype/assoc 명령 사용 (Windows 11 호환)
        foreach ($ext in $extensions) {
            $extName = $ext.TrimStart('.')
            $progId = "Notepad++.$extName"
            cmd /c "ftype $progId=`"$nppPath`" `"%1`"" 2>$null
            cmd /c "assoc $ext=$progId" 2>$null
        }
        Write-Host "  - 파일 연결 시도 완료: $($extensions.Count)개 확장자" -ForegroundColor Green
        Write-Host "  - 참고: 일부 확장자는 Windows 설정에서 수동 변경 필요" -ForegroundColor Yellow
    } else {
        Write-Host "  - 건너뜀 (Notepad++ 설치 경로 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 파일 연결 실패: $_" -ForegroundColor Red
}

# [12/12] Chrome 기본 브라우저 설정
Write-Host "[12/12] Chrome 기본 브라우저 설정 중..." -ForegroundColor Yellow
try {
    $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    if (Test-Path $chromePath) {
        # ftype/assoc 명령 사용 (Windows 11 호환)
        cmd /c "ftype ChromeHTML=`"$chromePath`" -- `"%1`"" 2>$null
        cmd /c "assoc .html=ChromeHTML" 2>$null
        cmd /c "assoc .htm=ChromeHTML" 2>$null

        # Chrome 자체 기본 브라우저 설정 호출
        Start-Process $chromePath -ArgumentList "--make-default-browser" -WindowStyle Hidden

        Write-Host "  - 기본 브라우저 설정 시도 완료" -ForegroundColor Green
        Write-Host "  - 참고: Windows 설정에서 확인 필요할 수 있음" -ForegroundColor Yellow
    } else {
        Write-Host "  - 건너뜀 (Chrome 설치 경로 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 기본 브라우저 설정 실패: $_" -ForegroundColor Red
}

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "소프트웨어 설치가 완료되었습니다!" -ForegroundColor Green
Write-Host "성공: $successCount개, 실패: $failCount개" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
