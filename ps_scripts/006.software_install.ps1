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
        # ShareX 설치 (NORUN으로 설치만)
        Start-Process -FilePath $shareXInstaller -ArgumentList "/SP- /VERYSILENT /NORESTART /NORUN /SUPPRESSMSGBOXES" -Wait -NoNewWindow
        Remove-Item $shareXInstaller -Force -ErrorAction SilentlyContinue
        Write-Host "  - 설치 완료" -ForegroundColor Green
        $successCount++

        # ShareX를 silent 모드로 실행하여 설정 파일 초기화
        $shareXExe = "${env:ProgramFiles}\ShareX\ShareX.exe"
        $shareXConfigDir = "$env:APPDATA\ShareX"
        $shareXConfigPath = "$shareXConfigDir\ApplicationConfig.json"

        if (Test-Path $shareXExe) {
            # silent 모드로 실행 (트레이로 바로 들어감)
            Start-Process -FilePath $shareXExe -ArgumentList "-silent" -WindowStyle Hidden
            Write-Host "  - ShareX 초기화 중..." -ForegroundColor Yellow

            # 설정 파일 생성 대기
            $maxWait = 10
            $waited = 0
            while ((-not (Test-Path $shareXConfigPath)) -and ($waited -lt $maxWait)) {
                Start-Sleep -Seconds 1
                $waited++
            }

            # ShareX 프로세스 종료
            Start-Sleep -Seconds 2
            Stop-Process -Name "ShareX" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }

        # 설정 파일이 생성되었으면 수정, 아니면 새로 생성
        if (Test-Path $shareXConfigPath) {
            # 기존 설정 파일 읽기 및 수정
            $configContent = Get-Content $shareXConfigPath -Raw -Encoding UTF8
            $config = $configContent | ConvertFrom-Json

            # 업로드 관련 설정 수정
            $config | Add-Member -NotePropertyName "DisableUpload" -NotePropertyValue $true -Force
            $config | Add-Member -NotePropertyName "ShowUploadWarning" -NotePropertyValue $false -Force
            $config | Add-Member -NotePropertyName "ShowMultiUploadWarning" -NotePropertyValue $false -Force
            $config | Add-Member -NotePropertyName "ShowAfterUploadForm" -NotePropertyValue $false -Force
            $config | Add-Member -NotePropertyName "ShowLargeFileSizeWarning" -NotePropertyValue 0 -Force
            $config | Add-Member -NotePropertyName "ShowFirstTimeUploadWarning" -NotePropertyValue $false -Force
            $config | Add-Member -NotePropertyName "AutoCheckUpdate" -NotePropertyValue $false -Force

            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $shareXConfigPath -Encoding UTF8 -Force
            Write-Host "  - 업로드 기능 비활성화 설정 완료 (기존 설정 수정)" -ForegroundColor Green
        } else {
            # 설정 파일이 없으면 디렉토리 생성 후 새로 생성
            if (!(Test-Path $shareXConfigDir)) {
                New-Item -Path $shareXConfigDir -ItemType Directory -Force | Out-Null
            }

            $config = @{
                "IsFirstRun" = $false
                "IsExportUpgrade" = $true
                "DisableUpload" = $true
                "ShowUploadWarning" = $false
                "ShowMultiUploadWarning" = $false
                "ShowAfterUploadForm" = $false
                "ShowLargeFileSizeWarning" = 0
                "ShowFirstTimeUploadWarning" = $false
                "AutoCheckUpdate" = $false
                "SilentRun" = $true
                "TrayIconProgressEnabled" = $true
                "TaskbarProgressEnabled" = $true
                "RememberMainFormSize" = $true
            }

            $config | ConvertTo-Json -Depth 10 | Set-Content -Path $shareXConfigPath -Encoding UTF8 -Force
            Write-Host "  - 업로드 기능 비활성화 설정 완료 (새 설정 생성)" -ForegroundColor Green
        }
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

    # 레지스트리에 INI 모드 활성화 (PotPlayer가 INI 파일 설정을 사용하도록)
    $potRegPath = "HKCU:\Software\DAUM\PotPlayerMini64"
    if (!(Test-Path $potRegPath)) {
        New-Item -Path $potRegPath -Force | Out-Null
    }
    # UseIni=1: INI 파일에 설정 저장, CheckAutoUpdate=0: 자동 업데이트 체크 비활성화
    Set-ItemProperty -Path $potRegPath -Name "UseIni" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $potRegPath -Name "CheckAutoUpdate" -Value 0 -Type DWord -Force
    Write-Host "  - 레지스트리: INI 모드 활성화" -ForegroundColor Green

    # INI 파일 생성 - 주석 없이 작성 (PotPlayer 파싱 호환성)
    $iniContent = @"
[Settings]
UseIni=1
CheckAutoUpdate=0
SkinUseOsc=1
ShowOSDOnPlayStart=0
ShowOSDOnSeek=0
ShowOSDMessage=0
AutoHideControl=1
AutoHideControlTime=1000
ShowTitleBar=0

[MainShortCutList]
0=87,2,10002,0
1=13,0,10010,0
2=32,0,10014,0
3=27,0,10015,0
"@

    $iniPath = "$potPlayerConfigDir\PotPlayerMini64.ini"
    # BOM 없는 UTF8로 저장 (PotPlayer 호환성)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($iniPath, $iniContent, $utf8NoBom)
    Write-Host "  - 설정 적용 완료 (단축키: Ctrl+W=종료, Enter=전체화면)" -ForegroundColor Green
    Write-Host "  - OSD 최소화, 컨트롤 바 자동 숨김 설정됨" -ForegroundColor Green
} catch {
    Write-Host "  - 설정 적용 실패: $_" -ForegroundColor Red
}

# [15/20] SetUserFTA 다운로드 (파일 연결 도구)
# SetUserFTA by Christoph Kolbicz - Personal Edition (비상업적/테스트 목적)
# 라이선스: https://github.com/Zeliper/windows-11-optimization/blob/main/LICENSES/SetUserFTA.md
Write-Host "[15/20] SetUserFTA 다운로드 중..." -ForegroundColor Yellow
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

# [17/20] Honeyview 이미지 파일 연결 설정 (Honeyview.{ext} ProgId 사용)
Write-Host "[17/20] Honeyview 이미지 파일 연결 설정 중..." -ForegroundColor Yellow
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

# [18/20] PotPlayer 동영상/오디오 파일 연결 (SetUserFTA 사용, PotPlayer 자체 ProgId 활용)
Write-Host "[18/20] PotPlayer 동영상/오디오 파일 연결 설정 중..." -ForegroundColor Yellow
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
            # Edge를 연결 프로그램 목록에서 제거 (선택 창 방지)
            $edgeProgIds = @("MSEdgeHTM", "MSEdgePDF", "MSEdgeMHT", "AppXq0fevzme2pys62n3e0fbqa7peapykr8v")

            # http/https 프로토콜에서 Edge 제거
            foreach ($protocol in @("http", "https")) {
                $urlAssocPath = "HKCU:\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\$protocol"
                $openWithProgids = "$urlAssocPath\OpenWithProgids"
                if (Test-Path $openWithProgids) {
                    foreach ($edgeId in $edgeProgIds) {
                        Remove-ItemProperty -Path $openWithProgids -Name $edgeId -ErrorAction SilentlyContinue
                    }
                }
                $openWithList = "$urlAssocPath\OpenWithList"
                if (Test-Path $openWithList) {
                    $props = Get-ItemProperty -Path $openWithList -ErrorAction SilentlyContinue
                    foreach ($prop in $props.PSObject.Properties) {
                        if ($prop.Value -like "*edge*" -or $prop.Value -like "*MSEdge*") {
                            Remove-ItemProperty -Path $openWithList -Name $prop.Name -ErrorAction SilentlyContinue
                        }
                    }
                }
            }

            # .html, .htm 확장자에서 Edge 제거
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
