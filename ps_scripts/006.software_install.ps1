# 필수 소프트웨어 자동 설치 (Notepad++, Chrome, 7-Zip, ShareX, Honeyview, PotPlayer)
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
Write-Host "Notepad++, Chrome, 7-Zip, ShareX, Honeyview, PotPlayer를 자동으로 설치합니다." -ForegroundColor White
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

        # Chrome 기본 브라우저 확인 팝업 비활성화
        $chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"
        if (-not (Test-Path $chromePolicyPath)) {
            New-Item -Path $chromePolicyPath -Force | Out-Null
        }
        Set-ItemProperty -Path $chromePolicyPath -Name "DefaultBrowserSettingEnabled" -Value 0 -Type DWord -Force

        Write-Host "  - 설치 완료 (기본 브라우저 확인 비활성화)" -ForegroundColor Green
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

# [11/20] Honeyview 설치 (winget)
Write-Host "[11/20] Honeyview 설치 중 (winget)..." -ForegroundColor Yellow
try {
    $wingetResult = winget install Bandisoft.Honeyview --silent --accept-package-agreements --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $wingetResult -match "already installed") {
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++
    } else {
        Write-Host "  - 설치 실패: $wingetResult" -ForegroundColor Red
        $failCount++
    }
} catch {
    Write-Host "  - 설치 실패: $_" -ForegroundColor Red
    $failCount++
}

# [12/20] PotPlayer 다운로드
Write-Host "[12/20] PotPlayer 다운로드 중..." -ForegroundColor Yellow
try {
    $potPlayerUrl = "https://t1.kakaocdn.net/potplayer/PotPlayer/Version/Latest/PotPlayerSetup64.exe"
    $potPlayerInstaller = Join-Path $tempDir "PotPlayerSetup64.exe"
    Invoke-WebRequest -Uri $potPlayerUrl -OutFile $potPlayerInstaller -UseBasicParsing
    Write-Host "  - 다운로드 완료" -ForegroundColor Green
} catch {
    Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
    $potPlayerInstaller = $null
    $failCount++
}

# [13/20] PotPlayer 설치
Write-Host "[13/20] PotPlayer 설치 중..." -ForegroundColor Yellow
if ($potPlayerInstaller -and (Test-Path $potPlayerInstaller)) {
    try {
        Start-Process -FilePath $potPlayerInstaller -ArgumentList "/S" -Wait -NoNewWindow
        Remove-Item $potPlayerInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  - 설치 실패: $_" -ForegroundColor Red
        $failCount++
    }
} else {
    Write-Host "  - 건너뜀 (다운로드 실패)" -ForegroundColor Red
}

# [14/20] PotPlayer 설정 적용
Write-Host "[14/20] PotPlayer 설정 적용 중..." -ForegroundColor Yellow
try {
    $potPlayerConfigDir = "$env:APPDATA\PotPlayerMini64"
    if (!(Test-Path $potPlayerConfigDir)) {
        New-Item -Path $potPlayerConfigDir -ItemType Directory -Force | Out-Null
    }

    # INI 파일 생성 - 설정 저장 모드 활성화, 단축키, OSD 설정
    $iniContent = @"
[Settings]
; 설정을 INI 파일에 저장
CheckAutoUpdate=0
SkinUseOsc=1
; OSD 최소화
ShowOSDOnPlayStart=0
ShowOSDOnSeek=0
ShowOSDMessage=0
; 컨트롤 바 자동 숨김
AutoHideControl=1
AutoHideControlTime=1000
; 타이틀 바 숨김 (전체화면 아닐 때)
ShowTitleBar=0

[MainShortCutList]
; Ctrl+W (W=87, Ctrl modifier=2) -> Exit (10002)
0=87,2,10002,0
; Enter (13) -> Fullscreen toggle (10010)
1=13,0,10010,0
; Space (32) -> Play/Pause (10014)
2=32,0,10014,0
; Escape (27) -> Exit fullscreen or close (10015)
3=27,0,10015,0
"@

    $iniPath = "$potPlayerConfigDir\PotPlayerMini64.ini"
    $iniContent | Set-Content -Path $iniPath -Encoding UTF8 -Force
    Write-Host "  - 설정 적용 완료 (단축키: Ctrl+W=종료, Enter=전체화면)" -ForegroundColor Green
    Write-Host "  - OSD 최소화, 컨트롤 바 자동 숨김 설정됨" -ForegroundColor Green
} catch {
    Write-Host "  - 설정 적용 실패: $_" -ForegroundColor Red
}

# [15/20] SetUserFTA 다운로드 (파일 연결 도구)
Write-Host "[15/20] SetUserFTA 다운로드 중..." -ForegroundColor Yellow
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

# [16/20] Notepad++ 파일 연결 설정 (SetUserFTA 병렬 실행)
Write-Host "[16/20] Notepad++ 파일 연결 설정 중..." -ForegroundColor Yellow
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

        # ProgId를 HKCU\SOFTWARE\Classes에 등록 (사용자별 설정)
        $progId = "Notepad++_file"
        $hkcuClassesPath = "HKCU:\SOFTWARE\Classes\$progId"

        if (-not (Test-Path $hkcuClassesPath)) {
            New-Item -Path $hkcuClassesPath -Force | Out-Null
            New-Item -Path "$hkcuClassesPath\shell\open\command" -Force | Out-Null
        }
        Set-ItemProperty -Path $hkcuClassesPath -Name "(Default)" -Value "Notepad++ Document" -Force
        Set-ItemProperty -Path "$hkcuClassesPath\shell\open\command" -Name "(Default)" -Value "`"$nppPath`" `"%1`"" -Force

        # SetUserFTA로 파일 연결 설정 (병렬 실행)
        $jobs = @()
        foreach ($ext in $extensions) {
            $jobs += Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        }
        # 모든 작업 완료 대기
        $jobs | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue
        $setCount = ($jobs | Where-Object { $_.ExitCode -eq 0 }).Count
        Write-Host "  - 파일 연결 완료: $setCount/$($extensions.Count)개 확장자 (ProgId: $progId)" -ForegroundColor Green
    } elseif (!(Test-Path $nppPath)) {
        Write-Host "  - 건너뜀 (Notepad++ 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 파일 연결 실패: $_" -ForegroundColor Red
}

# [17/20] Honeyview 이미지 파일 연결 설정 (SetUserFTA 병렬 실행)
Write-Host "[17/20] Honeyview 이미지 파일 연결 설정 중..." -ForegroundColor Yellow
try {
    $honeyviewPath = "${env:ProgramFiles}\Honeyview\Honeyview.exe"
    if ((Test-Path $honeyviewPath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
        # 이미지 확장자 목록
        $imageExtensions = @(
            ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".ico", ".webp",
            ".tiff", ".tif", ".svg", ".heic", ".heif", ".avif",
            ".raw", ".cr2", ".nef", ".arw", ".dng", ".orf", ".rw2",
            ".psd", ".xcf", ".jfif", ".jpe", ".dib", ".wdp", ".jxr"
        )

        # Honeyview ProgId 등록 (HKCU\SOFTWARE\Classes 사용)
        $progIdBase = "Honeyview.AssocFile"

        # 1단계: 모든 ProgId 레지스트리 등록 (먼저 완료)
        foreach ($ext in $imageExtensions) {
            $extName = $ext.TrimStart(".")
            $progId = "$progIdBase.$extName"
            $hkcuClassesPath = "HKCU:\SOFTWARE\Classes\$progId"

            if (-not (Test-Path $hkcuClassesPath)) {
                New-Item -Path $hkcuClassesPath -Force | Out-Null
                New-Item -Path "$hkcuClassesPath\shell\open\command" -Force | Out-Null
            }
            Set-ItemProperty -Path $hkcuClassesPath -Name "(Default)" -Value "Honeyview $extName" -Force
            Set-ItemProperty -Path "$hkcuClassesPath\shell\open\command" -Name "(Default)" -Value "`"$honeyviewPath`" `"%1`"" -Force
        }

        # 2단계: SetUserFTA 병렬 실행
        $jobs = @()
        foreach ($ext in $imageExtensions) {
            $extName = $ext.TrimStart(".")
            $progId = "$progIdBase.$extName"
            $jobs += Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        }

        # 3단계: 모든 작업 완료 대기
        $jobs | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue
        $setCount = ($jobs | Where-Object { $_.ExitCode -eq 0 }).Count
        Write-Host "  - 이미지 연결 완료: $setCount/$($imageExtensions.Count)개 확장자" -ForegroundColor Green
    } elseif (!(Test-Path $honeyviewPath)) {
        Write-Host "  - 건너뜀 (Honeyview 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 이미지 연결 실패: $_" -ForegroundColor Red
}

# [18/20] PotPlayer 동영상 파일 연결 (SetUserFTA 병렬 실행)
Write-Host "[18/20] PotPlayer 동영상 파일 연결 설정 중..." -ForegroundColor Yellow
try {
    $potPlayerPath = "${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe"
    if ((Test-Path $potPlayerPath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
        # 동영상 확장자 목록
        $videoExtensions = @(
            ".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm",
            ".m4v", ".mpg", ".mpeg", ".ts", ".3gp", ".m2ts", ".vob"
        )

        # PotPlayer ProgId 등록 (HKCU\SOFTWARE\Classes 사용)
        $progIdBase = "PotPlayer.AssocFile"

        # 1단계: 모든 ProgId 레지스트리 등록 (먼저 완료)
        foreach ($ext in $videoExtensions) {
            $extName = $ext.TrimStart(".")
            $progId = "$progIdBase.$extName"
            $hkcuClassesPath = "HKCU:\SOFTWARE\Classes\$progId"

            if (-not (Test-Path $hkcuClassesPath)) {
                New-Item -Path $hkcuClassesPath -Force | Out-Null
                New-Item -Path "$hkcuClassesPath\shell\open\command" -Force | Out-Null
            }
            Set-ItemProperty -Path $hkcuClassesPath -Name "(Default)" -Value "PotPlayer $extName" -Force
            Set-ItemProperty -Path "$hkcuClassesPath\shell\open\command" -Name "(Default)" -Value "`"$potPlayerPath`" `"%1`"" -Force
        }

        # 2단계: SetUserFTA 병렬 실행
        $jobs = @()
        foreach ($ext in $videoExtensions) {
            $extName = $ext.TrimStart(".")
            $progId = "$progIdBase.$extName"
            $jobs += Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        }

        # 3단계: 모든 작업 완료 대기
        $jobs | Wait-Process -Timeout 60 -ErrorAction SilentlyContinue
        $setCount = ($jobs | Where-Object { $_.ExitCode -eq 0 }).Count
        Write-Host "  - 동영상 연결 완료: $setCount/$($videoExtensions.Count)개 확장자" -ForegroundColor Green
    } elseif (!(Test-Path $potPlayerPath)) {
        Write-Host "  - 건너뜀 (PotPlayer 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 동영상 연결 실패: $_" -ForegroundColor Red
}

# [19/20] Chrome 기본 브라우저 설정 (SetUserFTA 사용)
Write-Host "[19/20] Chrome 기본 브라우저 설정 중..." -ForegroundColor Yellow
try {
    $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    if ((Test-Path $chromePath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
        # ChromeHTML ProgId 존재 확인
        $chromeProgId = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\ChromeHTML" -ErrorAction SilentlyContinue
        if (-not $chromeProgId) {
            $chromeProgId = Get-ItemProperty -Path "HKCU:\SOFTWARE\Classes\ChromeHTML" -ErrorAction SilentlyContinue
        }

        if ($chromeProgId) {
            # SetUserFTA로 Chrome을 기본 브라우저로 설정
            $browserAssocs = @(".html", ".htm", "http", "https")
            $browserSuccessCount = 0
            foreach ($assoc in $browserAssocs) {
                $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$assoc ChromeHTML" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                if ($result.ExitCode -eq 0) { $browserSuccessCount++ }
            }

            if ($browserSuccessCount -eq $browserAssocs.Count) {
                Write-Host "  - 기본 브라우저 설정 완료 ($browserSuccessCount/$($browserAssocs.Count))" -ForegroundColor Green
            } else {
                Write-Host "  - 일부 설정 실패 ($browserSuccessCount/$($browserAssocs.Count))" -ForegroundColor Yellow
                Write-Host "  - 수동 설정 필요: 설정 > 앱 > 기본 앱 > Google Chrome" -ForegroundColor Cyan
                Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "  - ChromeHTML ProgId를 찾을 수 없음" -ForegroundColor Yellow
            Write-Host "  - 수동 설정 필요: 설정 > 앱 > 기본 앱 > Google Chrome" -ForegroundColor Cyan
            Start-Process "ms-settings:defaultapps" -ErrorAction SilentlyContinue
        }
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
