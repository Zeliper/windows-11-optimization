# 필수 소프트웨어 자동 설치 (Notepad++, Chrome, 7-Zip, ShareX, ImageGlass, MSEdgeRedirect)
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
Write-Host "Notepad++, Chrome, 7-Zip, ShareX, ImageGlass, MSEdgeRedirect를 자동으로 설치합니다." -ForegroundColor White
Write-Host ""

$tempDir = $env:TEMP
$successCount = 0
$failCount = 0

# [1/20] Notepad++ 다운로드
Write-Host "[1/20] Notepad++ 다운로드 중..." -ForegroundColor Yellow
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

# [2/20] Notepad++ 설치
Write-Host "[2/20] Notepad++ 설치 중..." -ForegroundColor Yellow
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

# [3/20] Chrome 다운로드
Write-Host "[3/20] Chrome 다운로드 중..." -ForegroundColor Yellow
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

# [4/20] Chrome 설치
Write-Host "[4/20] Chrome 설치 중..." -ForegroundColor Yellow
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

# [5/20] 7-Zip 다운로드
Write-Host "[5/20] 7-Zip 다운로드 중..." -ForegroundColor Yellow
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

# [6/20] 7-Zip 설치
Write-Host "[6/20] 7-Zip 설치 중..." -ForegroundColor Yellow
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

# [7/20] ShareX 다운로드
Write-Host "[7/20] ShareX 다운로드 중..." -ForegroundColor Yellow
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

# [8/20] ShareX 설치 (업로드 기능 비활성화)
Write-Host "[8/20] ShareX 설치 중 (업로드 기능 비활성화)..." -ForegroundColor Yellow
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

# [9/20] ShareX 컨텍스트 메뉴 제거
Write-Host "[9/20] ShareX 컨텍스트 메뉴 제거 중..." -ForegroundColor Yellow
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

# [10/20] ShareX 시작 시 트레이 모드 설정
Write-Host "[10/20] ShareX 시작 프로그램 등록 중..." -ForegroundColor Yellow
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

# [11/20] ImageGlass 다운로드
Write-Host "[11/20] ImageGlass 다운로드 중..." -ForegroundColor Yellow
try {
    $imageGlassRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/d2phap/ImageGlass/releases/latest"
    $imageGlassAsset = $imageGlassRelease.assets | Where-Object { $_.name -match "ImageGlass_.*_x64\.msi$" } | Select-Object -First 1
    $imageGlassUrl = $imageGlassAsset.browser_download_url
    $imageGlassInstaller = Join-Path $tempDir "ImageGlass_installer.msi"
    Invoke-WebRequest -Uri $imageGlassUrl -OutFile $imageGlassInstaller -UseBasicParsing
    Write-Host "  - 다운로드 완료: $($imageGlassAsset.name)" -ForegroundColor Green
} catch {
    Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
    $imageGlassInstaller = $null
    $failCount++
}

# [12/20] ImageGlass 설치
Write-Host "[12/20] ImageGlass 설치 중..." -ForegroundColor Yellow
if ($imageGlassInstaller -and (Test-Path $imageGlassInstaller)) {
    try {
        Start-Process msiexec -ArgumentList "/i `"$imageGlassInstaller`" /qn /norestart" -Wait -NoNewWindow
        Remove-Item $imageGlassInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  - 설치 실패: $_" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [13/20] ImageGlass 설정 적용
Write-Host "[13/20] ImageGlass 설정 적용 중..." -ForegroundColor Yellow
try {
    $imageGlassConfigDir = "$env:LOCALAPPDATA\ImageGlass"
    if (!(Test-Path $imageGlassConfigDir)) {
        New-Item -Path $imageGlassConfigDir -ItemType Directory -Force | Out-Null
    }

    $config = @{
        "_Metadata" = @{
            "Description" = "ImageGlass configuration file"
            "Version" = "9.1"
        }
        "QuickSetupVersion" = 10

        # UI 설정 - 미니멀 모드
        "ShowToolbar" = $false
        "ShowGallery" = $false
        "ShowWelcomeImage" = $false

        # 배경 스타일
        "WindowBackdrop" = "Mica"
        "BackgroundColor" = "#FF1E1E1E"

        # 기본 줌 모드 - 화면 맞춤
        "ZoomMode" = "ScaleToFit"

        # 단축키 설정
        "MenuHotkeys" = @{
            "MnuFullScreen" = @("Enter", "F11")
            "MnuExit" = @("Ctrl+W", "Escape")
            "MnuFitScreen" = @("F")
            "MnuScaleToFit" = @("D5", "NumPad5", "Z")
            "MnuActualPixel" = @("Ctrl+0")
            "MnuZoomIn" = @("Ctrl+Plus", "Plus")
            "MnuZoomOut" = @("Ctrl+Minus", "Minus")
            "MnuRotateRight" = @("R")
            "MnuRotateLeft" = @("L")
            "MnuDeleteFromHardDisk" = @()
            "MnuMoveToRecycleBin" = @()
        }
    }

    $configPath = "$imageGlassConfigDir\igconfig.json"
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Encoding UTF8 -Force
    Write-Host "  - 설정 적용 완료 (미니멀 모드, Mica 배경)" -ForegroundColor Green
} catch {
    Write-Host "  - 설정 적용 실패: $_" -ForegroundColor Red
}

# [14/20] SetUserFTA 다운로드 (파일 연결 도구)
Write-Host "[14/20] SetUserFTA 다운로드 중..." -ForegroundColor Yellow
$setUserFtaPath = Join-Path $tempDir "SetUserFTA.exe"
$downloaded = $false

# 다운로드 URL 목록 (GitHub 우선 - kolbi.cz 불안정)
$setUserFtaUrls = @(
    @{ Url = "https://github.com/mrmattipants/Adobe_Reader_And_Adobe_Acrobat_Pro_File_Type_Associations/raw/main/SetUserFTA/SetUserFTA.exe"; IsZip = $false },
    @{ Url = "https://kolbi.cz/SetUserFTA.zip"; IsZip = $true }
)

foreach ($source in $setUserFtaUrls) {
    if ($downloaded) { break }
    try {
        if ($source.IsZip) {
            # ZIP 파일 다운로드 후 압축 해제
            $zipPath = Join-Path $tempDir "SetUserFTA.zip"
            Invoke-WebRequest -Uri $source.Url -OutFile $zipPath -UseBasicParsing -TimeoutSec 30
            Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
            if (Test-Path $setUserFtaPath) {
                $downloaded = $true
                Write-Host "  - 다운로드 완료 (kolbi.cz)" -ForegroundColor Green
            }
            Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        } else {
            # EXE 직접 다운로드
            Invoke-WebRequest -Uri $source.Url -OutFile $setUserFtaPath -UseBasicParsing -TimeoutSec 30
            if (Test-Path $setUserFtaPath) {
                $downloaded = $true
                Write-Host "  - 다운로드 완료 (GitHub)" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  - $($source.Url) 실패, 다음 소스 시도..." -ForegroundColor Yellow
    }
}

if (-not $downloaded) {
    Write-Host "  - 모든 소스에서 다운로드 실패" -ForegroundColor Red
    $setUserFtaPath = $null
}

# [15/20] Notepad++ 파일 연결 설정 (SetUserFTA 사용)
Write-Host "[15/20] Notepad++ 파일 연결 설정 중..." -ForegroundColor Yellow
try {
    $nppPath = "${env:ProgramFiles}\Notepad++\notepad++.exe"
    if ((Test-Path $nppPath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
        # 연결할 확장자 목록 (실행 스크립트 제외: .bat, .cmd, .ps1, .vbs 등)
        $extensions = @(
            ".txt", ".ini", ".cfg", ".conf", ".config",
            ".properties", ".property", ".log", ".md",
            ".json", ".xml", ".yaml", ".yml",
            ".sql", ".csv", ".tsv", ".sh"
        )

        # Notepad++ ProgId 찾기 (레지스트리에서 검색)
        $progId = $null
        $nppProgIds = @("Notepad++_file", "Applications\notepad++.exe")
        foreach ($testId in $nppProgIds) {
            $regPath = "HKCR:\$testId"
            if (-not (Test-Path "HKCR:")) {
                New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
            }
            if (Test-Path $regPath) {
                $progId = $testId
                break
            }
        }

        if (-not $progId) {
            # ProgId가 없으면 직접 등록
            $progId = "Notepad++_file"
            New-Item -Path "HKCR:\$progId" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item -Path "HKCR:\$progId\shell\open\command" -Force -ErrorAction SilentlyContinue | Out-Null
            Set-ItemProperty -Path "HKCR:\$progId\shell\open\command" -Name "(Default)" -Value "`"$nppPath`" `"%1`"" -Force -ErrorAction SilentlyContinue
        }

        # SetUserFTA로 파일 연결 설정
        $setCount = 0
        foreach ($ext in $extensions) {
            $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
            if ($result.ExitCode -eq 0) { $setCount++ }
        }
        Write-Host "  - 파일 연결 완료: $setCount/$($extensions.Count)개 확장자 (ProgId: $progId)" -ForegroundColor Green
    } elseif (!(Test-Path $nppPath)) {
        Write-Host "  - 건너뜀 (Notepad++ 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 파일 연결 실패: $_" -ForegroundColor Red
}

# [16/20] ImageGlass 이미지 파일 연결 설정 (SetUserFTA 사용)
Write-Host "[16/20] ImageGlass 이미지 파일 연결 설정 중..." -ForegroundColor Yellow
try {
    $imageGlassPath = "${env:ProgramFiles}\ImageGlass\ImageGlass.exe"
    if ((Test-Path $imageGlassPath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
        # 이미지 확장자 목록
        $imageExtensions = @(
            ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".ico", ".webp",
            ".tiff", ".tif", ".svg", ".heic", ".heif", ".avif",
            ".raw", ".cr2", ".nef", ".arw", ".dng", ".orf", ".rw2",
            ".psd", ".xcf", ".jfif", ".jpe", ".dib", ".wdp", ".jxr"
        )

        # HKCR 드라이브 생성
        if (-not (Test-Path "HKCR:")) {
            New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
        }

        # ImageGlass ProgId 등록 (확장자별로 등록)
        $progIdBase = "ImageGlass.AssocFile"
        $setCount = 0

        foreach ($ext in $imageExtensions) {
            $extName = $ext.TrimStart(".")
            $progId = "$progIdBase.$extName"

            # ProgId 등록 (없으면 생성)
            if (-not (Test-Path "HKCR:\$progId")) {
                New-Item -Path "HKCR:\$progId" -Force -ErrorAction SilentlyContinue | Out-Null
                New-Item -Path "HKCR:\$progId\shell\open\command" -Force -ErrorAction SilentlyContinue | Out-Null
                Set-ItemProperty -Path "HKCR:\$progId\shell\open\command" -Name "(Default)" -Value "`"$imageGlassPath`" `"%1`"" -Force -ErrorAction SilentlyContinue
            }

            # SetUserFTA로 연결
            $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
            if ($result.ExitCode -eq 0) { $setCount++ }
        }
        Write-Host "  - 이미지 연결 완료: $setCount/$($imageExtensions.Count)개 확장자" -ForegroundColor Green
    } elseif (!(Test-Path $imageGlassPath)) {
        Write-Host "  - 건너뜀 (ImageGlass 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 이미지 연결 실패: $_" -ForegroundColor Red
}

# [17/20] MSEdgeRedirect 다운로드
Write-Host "[17/20] MSEdgeRedirect 다운로드 중..." -ForegroundColor Yellow
try {
    $msEdgeRedirectRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/rcmaehl/MSEdgeRedirect/releases/latest"
    $msEdgeRedirectAsset = $msEdgeRedirectRelease.assets | Where-Object { $_.name -match "MSEdgeRedirect\.exe$" } | Select-Object -First 1
    $msEdgeRedirectUrl = $msEdgeRedirectAsset.browser_download_url
    $msEdgeRedirectInstaller = Join-Path $tempDir "MSEdgeRedirect.exe"
    Invoke-WebRequest -Uri $msEdgeRedirectUrl -OutFile $msEdgeRedirectInstaller -UseBasicParsing
    Write-Host "  - 다운로드 완료: $($msEdgeRedirectAsset.name)" -ForegroundColor Green
} catch {
    Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
    $msEdgeRedirectInstaller = $null
    $failCount++
}

# [18/20] MSEdgeRedirect 설치 (시작 메뉴 검색 → Chrome 리다이렉트)
Write-Host "[18/20] MSEdgeRedirect 설치 중 (Edge 강제 링크 → Chrome)..." -ForegroundColor Yellow
if ($msEdgeRedirectInstaller -and (Test-Path $msEdgeRedirectInstaller)) {
    try {
        $installPath = "$env:LOCALAPPDATA\MSEdgeRedirect"
        if (!(Test-Path $installPath)) {
            New-Item -Path $installPath -ItemType Directory -Force | Out-Null
        }
        Copy-Item $msEdgeRedirectInstaller "$installPath\MSEdgeRedirect.exe" -Force
        Remove-Item $msEdgeRedirectInstaller -Force -ErrorAction SilentlyContinue

        # Chrome 경로 확인
        $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
        if (-not (Test-Path $chromePath)) {
            $chromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        }

        # 설정 파일 생성 (INI 형식) - 자동 설정
        $settingsPath = "$installPath\Settings.ini"
        $settingsContent = @"
[MSEdgeRedirect]
AdsEnabled=0
AppMode=2
CheckUpdates=0
EdgeDeflectorEnabled=1
Enabled=1
FirstRun=0
NoApps=1
NoBing=1
NoCopilot=1
NoMSN=1
NoOOBE=1
NoWeather=1
NoWidgets=1
SearchEngine=Google
SetupComplete=1
StartMenuSearchEnabled=1
UseProxy=0
"@

        # Chrome 경로 추가 (존재하는 경우)
        if (Test-Path $chromePath) {
            $settingsContent += "`nCustomBrowserPath=$chromePath"
        }

        $settingsContent | Set-Content -Path $settingsPath -Encoding UTF8 -Force

        # 시작 프로그램에 등록
        $startupKey = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $startupKey -Name "MSEdgeRedirect" -Value "`"$installPath\MSEdgeRedirect.exe`"" -Force

        # 백그라운드에서 실행 (설정 파일이 있으므로 UI 없이 동작)
        Start-Process "$installPath\MSEdgeRedirect.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue

        Write-Host "  - 설치 완료 (자동 설정 적용)" -ForegroundColor Green
        Write-Host "  - 시작 메뉴/위젯 검색이 Chrome으로 열립니다" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  - 설치 실패: $_" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [19/20] Chrome 기본 브라우저 설정 (SetUserFTA 사용)
Write-Host "[19/20] Chrome 기본 브라우저 설정 중..." -ForegroundColor Yellow
try {
    $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    if ((Test-Path $chromePath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
        # SetUserFTA로 Chrome을 기본 브라우저로 설정
        $browserAssocs = @(".html", ".htm", ".xhtml", "http", "https")
        foreach ($assoc in $browserAssocs) {
            Start-Process -FilePath $setUserFtaPath -ArgumentList "$assoc ChromeHTML" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        }
        # PDF도 Chrome으로 열기
        Start-Process -FilePath $setUserFtaPath -ArgumentList ".pdf ChromeHTML" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        Write-Host "  - 기본 브라우저 설정 완료 (html, htm, http, https, pdf)" -ForegroundColor Green
    } elseif (!(Test-Path $chromePath)) {
        Write-Host "  - 건너뜀 (Chrome 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 기본 브라우저 설정 실패: $_" -ForegroundColor Red
}

# [20/20] Windows 배경화면 기본 설정 (Spotlight 제거)
Write-Host "[20/20] Windows 배경화면 기본 설정 중..." -ForegroundColor Yellow
try {
    # 기본 Windows 배경화면 경로
    $defaultWallpaper = "C:\Windows\Web\Wallpaper\Windows\img0.jpg"
    if (Test-Path $defaultWallpaper) {
        # 레지스트리에서 배경화면 설정
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $defaultWallpaper -Force
        Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "10" -Force  # Fill

        # SystemParametersInfo로 즉시 적용
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
        [Wallpaper]::SystemParametersInfo(0x0014, 0, $defaultWallpaper, 0x01 -bor 0x02) | Out-Null

        Write-Host "  - 기본 배경화면으로 변경 완료" -ForegroundColor Green
        Write-Host "  - Spotlight 배경 제거됨 (설정 로딩 속도 개선)" -ForegroundColor Green
    } else {
        Write-Host "  - 기본 배경화면 파일 없음, 건너뜀" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  - 배경화면 설정 실패: $_" -ForegroundColor Red
}

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "소프트웨어 설치가 완료되었습니다!" -ForegroundColor Green
Write-Host "성공: $successCount개, 실패: $failCount개" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
