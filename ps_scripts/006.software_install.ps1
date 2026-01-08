# 필수 소프트웨어 자동 설치 (Notepad++, Chrome, 7-Zip, ShareX, Honeyview, PotPlayer, Everything)
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.0.10"

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

Write-Host "=== 필수 소프트웨어 자동 설치 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "Notepad++, Chrome, 7-Zip, ShareX, Honeyview, PotPlayer, Everything을 자동으로 설치합니다." -ForegroundColor White
Write-Host ""

$tempDir = $env:TEMP
$successCount = 0
$failCount = 0

# [1/22] Notepad++ 설치 (winget - GitHub API rate limit 회피)
Write-Host "[1/22] Notepad++ 설치 중 (winget)..." -ForegroundColor Yellow
try {
    $wingetResult = winget install Notepad++.Notepad++ --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
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

# [2/22] (예약됨 - 단계 번호 유지)
Write-Host "[2/22] Notepad++ 설치 확인..." -ForegroundColor Yellow
$nppPath = "${env:ProgramFiles}\Notepad++\notepad++.exe"
if (Test-Path $nppPath) {
    Write-Host "  - Notepad++ 설치 확인됨" -ForegroundColor Green
} else {
    Write-Host "  - Notepad++ 경로 없음 (설치 지연 가능)" -ForegroundColor Yellow
}

# [3/22] Chrome 다운로드
Write-Host "[3/22] Chrome 다운로드 중..." -ForegroundColor Yellow
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

# [4/22] Chrome 설치
Write-Host "[4/22] Chrome 설치 중..." -ForegroundColor Yellow
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

# [5/22] 7-Zip 다운로드
Write-Host "[5/22] 7-Zip 다운로드 중..." -ForegroundColor Yellow
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

# [6/22] 7-Zip 설치
Write-Host "[6/22] 7-Zip 설치 중..." -ForegroundColor Yellow
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

# [7/22] ShareX 설치 (winget - GitHub API rate limit 회피)
Write-Host "[7/22] ShareX 설치 중 (winget)..." -ForegroundColor Yellow
try {
    $wingetResult = winget install ShareX.ShareX --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
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

# [8/22] ShareX 설정 파일 적용 (업로드 기능 비활성화)
Write-Host "[8/22] ShareX 설정 파일 적용 중..." -ForegroundColor Yellow
try {
    # ShareX 설정 파일 다운로드 및 복사 (Documents 폴더에 저장)
    $shareXConfigDir = "$env:USERPROFILE\Documents\ShareX"
    $shareXConfigPath = "$shareXConfigDir\ApplicationConfig.json"
    $shareXConfigUrl = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Configs/ShareX/ApplicationConfig.json"

    # 설정 디렉토리 생성
    if (!(Test-Path $shareXConfigDir)) {
        New-Item -Path $shareXConfigDir -ItemType Directory -Force | Out-Null
    }

    # 설정 파일 다운로드
    Invoke-WebRequest -Uri $shareXConfigUrl -OutFile $shareXConfigPath -UseBasicParsing
    Write-Host "  - 설정 파일 적용 완료 (업로드 비활성화)" -ForegroundColor Green
} catch {
    Write-Host "  - 설정 파일 적용 실패: $_" -ForegroundColor Red
}

# [9/22] ShareX 컨텍스트 메뉴 제거
Write-Host "[9/22] ShareX 컨텍스트 메뉴 제거 중..." -ForegroundColor Yellow
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

# [10/22] ShareX 시작 시 트레이 모드 설정
Write-Host "[10/22] ShareX 시작 프로그램 등록 중..." -ForegroundColor Yellow
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

# [11/22] Honeyview 설치 (winget)
Write-Host "[11/22] Honeyview 설치 중 (winget)..." -ForegroundColor Yellow
try {
    $wingetResult = winget install Bandisoft.Honeyview --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
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

# [12/22] Honeyview 설정 적용 (작은 이미지 늘리기, 제목표시줄/컨트롤바 고정 해제)
Write-Host "[12/22] Honeyview 설정 적용 중..." -ForegroundColor Yellow
try {
    $honeyviewRegPath = "HKCU:\Software\Honeyview"
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
    Write-Host "  - 작은 이미지 늘리기 활성화" -ForegroundColor Green
    Write-Host "  - 제목 표시줄/컨트롤바 자동 숨김 설정" -ForegroundColor Green
    Write-Host "  - Enter 키 = 전체화면 단축키 설정" -ForegroundColor Green
} catch {
    Write-Host "  - 설정 적용 실패: $_" -ForegroundColor Red
}

# [13/22] PotPlayer 다운로드
Write-Host "[13/22] PotPlayer 다운로드 중..." -ForegroundColor Yellow
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

# [14/22] PotPlayer 설치
Write-Host "[14/22] PotPlayer 설치 중..." -ForegroundColor Yellow
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

# [15/22] PotPlayer 설정 적용
Write-Host "[15/22] PotPlayer 설정 적용 중..." -ForegroundColor Yellow
try {
    $potPlayerConfigDir = "$env:APPDATA\PotPlayerMini64"
    if (!(Test-Path $potPlayerConfigDir)) {
        New-Item -Path $potPlayerConfigDir -ItemType Directory -Force | Out-Null
    }

    # 레지스트리에 INI 모드 활성화 (PotPlayer가 INI 파일 설정을 사용하도록)
    $potRegPath = "HKCU:\Software\DAUM\PotPlayerMini64"
    if (!(Test-Path $potRegPath)) {
        New-Item -Path $potRegPath -Force | Out-Null
    }
    # UseIni=1: INI 파일에 설정 저장, CheckAutoUpdate=0: 자동 업데이트 체크 비활성화
    Set-ItemProperty -Path $potRegPath -Name "UseIni" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $potRegPath -Name "CheckAutoUpdate" -Value 0 -Type DWord -Force
    Write-Host "  - 레지스트리: INI 모드 활성화" -ForegroundColor Green

    # 재생목록/방송목록 창 숨김 설정
    $potPositionsPath = "HKCU:\Software\DAUM\PotPlayer64\Positions"
    if (-not (Test-Path $potPositionsPath)) {
        New-Item -Path $potPositionsPath -Force | Out-Null
    }
    Set-ItemProperty -Path $potPositionsPath -Name "ChatWindowVisible" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $potPositionsPath -Name "PlayListWindowVisible" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $potPositionsPath -Name "BroadcastListWindowVisible" -Value 0 -Type DWord -Force
    Write-Host "  - 채팅/재생목록/방송목록 창 숨김 설정" -ForegroundColor Green

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
    Write-Host "  - 단축키 설정 완료 (F1~F5 북마크, Ctrl+W 종료)" -ForegroundColor Green

    # INI 파일 다운로드 (외부 설정 파일 사용)
    $iniPath = "$potPlayerConfigDir\PotPlayerMini64.ini"
    $potPlayerConfigUrl = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Configs/PotPlayer/PotPlayerMini64.ini"
    Invoke-WebRequest -Uri $potPlayerConfigUrl -OutFile $iniPath -UseBasicParsing
    Write-Host "  - 설정 파일 다운로드 완료" -ForegroundColor Green
    Write-Host "  - 단축키: Ctrl+W=종료, Enter=전체화면, Space=재생/일시정지, Esc=종료" -ForegroundColor Green
    Write-Host "  - OSD 최소화, 컨트롤 바 자동 숨김 설정됨" -ForegroundColor Green
} catch {
    Write-Host "  - 설정 적용 실패: $_" -ForegroundColor Red
}

# [16/22] SetUserFTA 다운로드 (파일 연결 도구)
# SetUserFTA by Christoph Kolbicz - Personal Edition (비상업적/테스트 목적)
# 라이선스: https://github.com/Zeliper/windows-11-optimization/blob/main/LICENSES/SetUserFTA.md
Write-Host "[16/22] SetUserFTA 다운로드 중..." -ForegroundColor Yellow
$setUserFtaPath = Join-Path $tempDir "SetUserFTA.exe"
$setUserFtaUrl = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Utils/SetUserFTA.exe"

try {
    Invoke-WebRequest -Uri $setUserFtaUrl -OutFile $setUserFtaPath -UseBasicParsing -TimeoutSec 30
    if (Test-Path $setUserFtaPath) {
        Write-Host "  - 다운로드 완료" -ForegroundColor Green
    } else {
        Write-Host "  - 다운로드 실패" -ForegroundColor Red
        $setUserFtaPath = $null
    }
} catch {
    Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
    Write-Host "  - 파일 연결 설정을 건너뜁니다 (수동 설정 필요)" -ForegroundColor Yellow
    $setUserFtaPath = $null
}

# [17/22] Notepad++ 파일 연결 설정 (SetUserFTA 병렬 실행)
Write-Host "[17/22] Notepad++ 파일 연결 설정 중..." -ForegroundColor Yellow
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
        Write-Host "  - 파일 연결 완료: $setCount/$($extensions.Count)개 확장자 (ProgId: $progId)" -ForegroundColor Green
    } elseif (!(Test-Path $nppPath)) {
        Write-Host "  - 건너뜀 (Notepad++ 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 파일 연결 실패: $_" -ForegroundColor Red
}

# [18/22] Honeyview 이미지 파일 연결 설정 (Honeyview.{ext} ProgId 사용)
Write-Host "[18/22] Honeyview 이미지 파일 연결 설정 중..." -ForegroundColor Yellow
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
        Write-Host "  - 경쟁 앱 연결 제거 및 OpenWithProgids 정리됨" -ForegroundColor Green

        # SetUserFTA로 각 확장자에 Honeyview.{ext} ProgId 연결
        $setCount = 0
        foreach ($ext in $imageExtensions) {
            $extWithoutDot = $ext.TrimStart(".")
            $honeyviewProgId = "Honeyview.$extWithoutDot"
            $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $honeyviewProgId" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
            if ($result -and $result.ExitCode -eq 0) { $setCount++ }
        }
        Write-Host "  - 이미지 연결 완료: $setCount/$($imageExtensions.Count)개 확장자 (ProgId: Honeyview.{ext})" -ForegroundColor Green
    } elseif (!(Test-Path $honeyviewPath)) {
        Write-Host "  - 건너뜀 (Honeyview 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 이미지 연결 실패: $_" -ForegroundColor Red
}

# [19/22] PotPlayer 동영상/오디오 파일 연결 (SetUserFTA 사용, PotPlayer 자체 ProgId 활용)
Write-Host "[19/22] PotPlayer 동영상/오디오 파일 연결 설정 중..." -ForegroundColor Yellow
try {
    $potPlayerPath = "${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe"
    if ((Test-Path $potPlayerPath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
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

        # PotPlayer ProgId 직접 등록 (설치 직후 자동 등록 안 될 수 있음)
        $potPlayerProgId = "Applications\PotPlayerMini64.exe"
        $progIdPath = "HKCU:\SOFTWARE\Classes\$potPlayerProgId"
        if (-not (Test-Path $progIdPath)) {
            New-Item -Path "$progIdPath\shell\open\command" -Force | Out-Null
        }
        Set-ItemProperty -Path $progIdPath -Name "(Default)" -Value "PotPlayer 64 bit" -Force
        Set-ItemProperty -Path "$progIdPath\shell\open\command" -Name "(Default)" -Value "`"$potPlayerPath`" `"%1`"" -Force
        Write-Host "  - PotPlayer ProgId 등록됨" -ForegroundColor Green

        # OpenWithProgids 정리 및 ProgId 추가
        foreach ($ext in $mediaExtensions) {
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
            New-ItemProperty -Path $openWithProgids -Name $potPlayerProgId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null
        }

        # SetUserFTA 순차 실행
        $setCount = 0
        foreach ($ext in $mediaExtensions) {
            $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $potPlayerProgId" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
            if ($result -and $result.ExitCode -eq 0) { $setCount++ }
        }
        Write-Host "  - 동영상 연결 완료: $($videoExtensions.Count)개 확장자" -ForegroundColor Green
        Write-Host "  - 오디오 연결 완료: $($audioExtensions.Count)개 확장자" -ForegroundColor Green
        Write-Host "  - 총 미디어 연결: $setCount/$($mediaExtensions.Count)개" -ForegroundColor Green
    } elseif (!(Test-Path $potPlayerPath)) {
        Write-Host "  - 건너뜀 (PotPlayer 설치 경로 없음)" -ForegroundColor Red
    } else {
        Write-Host "  - 건너뜀 (SetUserFTA 없음)" -ForegroundColor Red
    }
} catch {
    Write-Host "  - 미디어 연결 실패: $_" -ForegroundColor Red
}

# [20/22] Chrome 기본 브라우저 설정 (SetUserFTA 사용)
Write-Host "[20/22] Chrome 기본 브라우저 설정 중..." -ForegroundColor Yellow
try {
    $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
    if ((Test-Path $chromePath) -and $setUserFtaPath -and (Test-Path $setUserFtaPath)) {
        # ChromeHTML ProgId 존재 확인
        $chromeProgId = Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\ChromeHTML" -ErrorAction SilentlyContinue
        if (-not $chromeProgId) {
            $chromeProgId = Get-ItemProperty -Path "HKCU:\SOFTWARE\Classes\ChromeHTML" -ErrorAction SilentlyContinue
        }

        if ($chromeProgId) {
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
            Write-Host "  - http/https OpenWithProgids 정리됨 (ChromeHTML만 유지)" -ForegroundColor Green

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
            Write-Host "  - Edge 연결 프로그램 제거됨" -ForegroundColor Green

            # SetUserFTA로 Chrome을 기본 브라우저로 설정
            # 파일 확장자 (.html, .htm만 - .url은 InternetShortcut으로 유지해야 정상 작동)
            $fileAssocs = @(".html", ".htm")
            $fileSuccessCount = 0
            foreach ($ext in $fileAssocs) {
                $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext ChromeHTML" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                if ($result.ExitCode -eq 0) { $fileSuccessCount++ }
            }
            Write-Host "  - 파일 연결 완료: $fileSuccessCount/$($fileAssocs.Count)개 (.html, .htm)" -ForegroundColor Green

            # URL 프로토콜 (http, https) - SetUserFTA로 설정 (UserChoice는 위에서 이미 삭제됨)
            $protocolAssocs = @("http", "https")
            $protocolSuccessCount = 0
            foreach ($protocol in $protocolAssocs) {
                $result = Start-Process -FilePath $setUserFtaPath -ArgumentList "$protocol ChromeHTML" -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                if ($result.ExitCode -eq 0) { $protocolSuccessCount++ }
            }
            Write-Host "  - 프로토콜 연결 완료: $protocolSuccessCount/$($protocolAssocs.Count)개 (http, https)" -ForegroundColor Green

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
            Write-Host "  - 프로토콜 핸들러 설정 완료 (HKCR/HKCU)" -ForegroundColor Green

            $totalSuccess = $fileSuccessCount + $protocolSuccessCount
            $totalAssocs = $fileAssocs.Count + $protocolAssocs.Count
            if ($totalSuccess -eq $totalAssocs) {
                Write-Host "  - 기본 브라우저 설정 완료 ($totalSuccess/$totalAssocs)" -ForegroundColor Green
            } else {
                Write-Host "  - 일부 설정 실패 ($totalSuccess/$totalAssocs)" -ForegroundColor Yellow
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

# [21/22] Windows 배경화면 기본 설정 (Spotlight 제거)
Write-Host "[21/22] Windows 배경화면 기본 설정 중..." -ForegroundColor Yellow
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

# [22/22] Everything 설치 (winget)
Write-Host "[22/22] Everything 설치 중 (winget)..." -ForegroundColor Yellow
try {
    $wingetResult = winget install voidtools.Everything --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
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

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "소프트웨어 설치가 완료되었습니다!" -ForegroundColor Green
Write-Host "성공: $successCount개, 실패: $failCount개" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
