# 필수 소프트웨어 자동 설치 (Notepad++, Chrome, 7-Zip, ShareX)
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "=== 필수 소프트웨어 자동 설치 ===" -ForegroundColor Cyan
Write-Host "Notepad++, Chrome, 7-Zip, ShareX를 자동으로 설치합니다." -ForegroundColor White
Write-Host ""

$tempDir = $env:TEMP
$successCount = 0
$failCount = 0

# [1/11] Notepad++ 다운로드
Write-Host "[1/11] Notepad++ 다운로드 중..." -ForegroundColor Yellow
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

# [2/11] Notepad++ 설치
Write-Host "[2/11] Notepad++ 설치 중..." -ForegroundColor Yellow
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

# [3/11] Chrome 다운로드
Write-Host "[3/11] Chrome 다운로드 중..." -ForegroundColor Yellow
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

# [4/11] Chrome 설치
Write-Host "[4/11] Chrome 설치 중..." -ForegroundColor Yellow
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

# [5/11] 7-Zip 다운로드
Write-Host "[5/11] 7-Zip 다운로드 중..." -ForegroundColor Yellow
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

# [6/11] 7-Zip 설치
Write-Host "[6/11] 7-Zip 설치 중..." -ForegroundColor Yellow
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

# [7/11] ShareX 다운로드
Write-Host "[7/11] ShareX 다운로드 중..." -ForegroundColor Yellow
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

# [8/11] ShareX 설치 (업로드 기능 비활성화)
Write-Host "[8/11] ShareX 설치 중 (업로드 기능 비활성화)..." -ForegroundColor Yellow
if ($shareXInstaller -and (Test-Path $shareXInstaller)) {
    try {
        # 업로드 비활성화 레지스트리 설정 (설치 전)
        New-Item -Path "HKLM:\SOFTWARE\ShareX" -Force | Out-Null
        New-ItemProperty -Path "HKLM:\SOFTWARE\ShareX" -Name "DisableUpload" -Value 1 -PropertyType DWORD -Force | Out-Null
        Write-Host "  - 업로드 기능 비활성화 레지스트리 설정 완료" -ForegroundColor Green

        # ShareX 설치
        Start-Process -FilePath $shareXInstaller -ArgumentList "/SP- /VERYSILENT /NORESTART /NORUN /SUPPRESSMSGBOXES" -Wait -NoNewWindow
        Remove-Item $shareXInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  - 설치 실패: $_" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [9/11] ShareX 컨텍스트 메뉴 제거
Write-Host "[9/11] ShareX 컨텍스트 메뉴 제거 중..." -ForegroundColor Yellow
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
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  - 컨텍스트 메뉴 제거 완료" -ForegroundColor Green
} catch {
    Write-Host "  - 컨텍스트 메뉴 제거 실패: $_" -ForegroundColor Red
}

# [10/11] Notepad++ 파일 연결 설정
Write-Host "[10/11] Notepad++ 파일 연결 설정 중..." -ForegroundColor Yellow
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

        foreach ($ext in $extensions) {
            $extName = $ext.TrimStart('.')
            $progId = "Notepad++.$extName"

            # ProgId 등록
            New-Item -Path "HKLM:\SOFTWARE\Classes\$progId" -Force | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$progId" -Name "(Default)" -Value "$extName File" -Force
            New-Item -Path "HKLM:\SOFTWARE\Classes\$progId\DefaultIcon" -Force | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$progId\DefaultIcon" -Name "(Default)" -Value "`"$nppPath`",0" -Force
            New-Item -Path "HKLM:\SOFTWARE\Classes\$progId\shell\open\command" -Force | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$progId\shell\open\command" -Name "(Default)" -Value "`"$nppPath`" `"%1`"" -Force

            # 확장자 연결
            New-Item -Path "HKLM:\SOFTWARE\Classes\$ext" -Force | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$ext" -Name "(Default)" -Value $progId -Force
        }
        Write-Host "  - 파일 연결 완료: $($extensions.Count)개 확장자" -ForegroundColor Green
    } else {
        Write-Host "  - 건너뜀 (Notepad++ 설치 경로 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 파일 연결 실패: $_" -ForegroundColor Red
}

# [11/11] Chrome 기본 브라우저 설정
Write-Host "[11/11] Chrome 기본 브라우저 설정 중..." -ForegroundColor Yellow
try {
    $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    if (Test-Path $chromePath) {
        # Chrome ProgId 설정
        $chromeProgId = "ChromeHTML"

        # HTTP/HTTPS URL 연결
        $urlProtocols = @("http", "https")
        foreach ($protocol in $urlProtocols) {
            # 사용자 선택 설정 (UserChoice는 시스템에서 관리되므로 ProgId만 설정)
            New-Item -Path "HKLM:\SOFTWARE\Classes\$protocol\shell\open\command" -Force | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$protocol\shell\open\command" -Name "(Default)" -Value "`"$chromePath`" -- `"%1`"" -Force
        }

        # HTML 파일 연결
        $htmlExts = @(".htm", ".html", ".shtml", ".xht", ".xhtml")
        foreach ($ext in $htmlExts) {
            New-Item -Path "HKLM:\SOFTWARE\Classes\$ext" -Force | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$ext" -Name "(Default)" -Value $chromeProgId -Force
        }

        Write-Host "  - Chrome 기본 브라우저 설정 완료" -ForegroundColor Green
        Write-Host "  - 참고: 완전한 기본 브라우저 설정은 설정 앱에서 확인 필요" -ForegroundColor White
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
