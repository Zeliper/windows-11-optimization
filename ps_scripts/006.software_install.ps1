# Windows 11 Software Installation Script
# Refactored to use Winget with detailed logging

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "006.software_install.ps1" -ScriptVersion "1.3.0"

# Disable progress bar globally
$ProgressPreference = 'SilentlyContinue'

# --- Debug Helper ---
function Write-Debug-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "  [$timestamp] $Message" -ForegroundColor DarkGray
}

# --- Winget Install Helper ---
function Install-WithWinget {
    param(
        [string]$Name,
        [string]$WingetId,
        [string[]]$CheckPaths = @()
    )

    Write-Debug-Log "Checking if $Name is installed..."

    # Check by path first (faster)
    foreach ($path in $CheckPaths) {
        if (Test-Path $path) {
            Write-Host "  - $Name 이미 설치됨 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $Name -Status "스킵됨" -Message "이미 설치됨"
            return $true
        }
    }

    # Check via winget
    Write-Debug-Log "Path check failed, checking winget list..."
    $wingetCheck = winget list --id $WingetId --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -and $wingetCheck -notmatch "No installed package") {
        Write-Host "  - $Name 이미 설치됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $Name -Status "스킵됨" -Message "이미 설치됨 (winget)"
        return $true
    }

    # Install
    Write-Host "  - $Name 설치 중 (winget)..." -ForegroundColor Yellow
    Write-Debug-Log "Running: winget install --id $WingetId"

    $process = Start-Process -FilePath "winget" -ArgumentList @(
        "install",
        "--id", $WingetId,
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    ) -NoNewWindow -Wait -PassThru

    Write-Debug-Log "Winget exit code: $($process.ExitCode)"

    if ($process.ExitCode -eq 0) {
        Write-Host "  - $Name 설치 완료" -ForegroundColor Green
        Write-OptLog -Step $Name -Status "설치됨" -Message "winget 설치 완료"
        return $true
    } else {
        Write-Host "  - $Name 설치 실패 (ExitCode: $($process.ExitCode))" -ForegroundColor Red
        Write-OptLog -Step $Name -Status "실패" -Message "ExitCode: $($process.ExitCode)"
        return $false
    }
}

# --- Direct Download Install Helper (for software not in winget) ---
function Install-Direct {
    param(
        [string]$Name,
        [string]$Url,
        [string]$InstallerName,
        [string]$Arguments,
        [string[]]$CheckPaths = @()
    )

    Write-Debug-Log "Checking if $Name is installed..."

    foreach ($path in $CheckPaths) {
        if (Test-Path $path) {
            Write-Host "  - $Name 이미 설치됨 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $Name -Status "스킵됨" -Message "이미 설치됨"
            return $true
        }
    }

    $installer = Join-Path $env:TEMP $InstallerName

    Write-Host "  - $Name 다운로드 중..." -ForegroundColor Yellow
    Write-Debug-Log "Downloading from: $Url"

    try {
        Invoke-WebRequest -Uri $Url -OutFile $installer -UseBasicParsing -TimeoutSec 120
        Write-Debug-Log "Download complete: $installer"
    } catch {
        Write-Host "  - 다운로드 실패: $_" -ForegroundColor Red
        return $false
    }

    if (-not (Test-Path $installer)) {
        Write-Host "  - 다운로드 파일 없음" -ForegroundColor Red
        return $false
    }

    Write-Host "  - $Name 설치 중..." -ForegroundColor Yellow
    Write-Debug-Log "Running: $installer $Arguments"

    $proc = Start-Process -FilePath $installer -ArgumentList $Arguments -NoNewWindow -PassThru
    $proc | Wait-Process -Timeout 300 -ErrorAction SilentlyContinue

    if (-not $proc.HasExited) {
        Write-Host "  - 설치 타임아웃, 강제 종료" -ForegroundColor Red
        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
    } else {
        Write-Debug-Log "Installer exit code: $($proc.ExitCode)"
    }

    Remove-Item $installer -Force -ErrorAction SilentlyContinue
    Write-Host "  - $Name 설치 완료" -ForegroundColor Green
    Write-OptLog -Step $Name -Status "설치됨" -Message "직접 설치 완료"
    return $true
}

$tempDir = $env:TEMP

# Security Protocol Fix
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$steps = @(
    # --- Notepad++ ---
    @{
        Name = "Notepad++ 설치"
        Action = {
            Write-Debug-Log "[START] Notepad++ installation step"
            Install-WithWinget -Name "Notepad++" -WingetId "Notepad++.Notepad++" -CheckPaths @(
                "${env:ProgramFiles}\Notepad++\notepad++.exe",
                "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
            )
            Write-Debug-Log "[END] Notepad++ installation step"
        }
    },

    # --- Chrome ---
    @{
        Name = "Chrome 설치"
        Action = {
            Write-Debug-Log "[START] Chrome installation step"
            $paths = @(
                "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
            )
            
            # Check if installed
            $isInstalled = $false
            foreach ($p in $paths) { if (Test-Path $p) { $isInstalled = $true; break } }

            if ($isInstalled) {
                Write-Host "  - Chrome 이미 설치됨 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "Chrome" -Status "스킵됨" -Message "이미 설치됨"
            } else {
                Write-Host "  - Chrome 다운로드 중 (Direct MSI)..." -ForegroundColor Yellow
                $msi = Join-Path $env:TEMP "ChromeSetup.msi"
                $url = "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi"
                
                try {
                    Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing -TimeoutSec 300
                    
                    if (Test-Path $msi) {
                        Write-Host "  - Chrome 설치 중..." -ForegroundColor Yellow
                        Write-Debug-Log "Running: msiexec /i $msi /qn /norestart"
                        $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
                        
                        if ($proc.ExitCode -eq 0) {
                            Write-Host "  - Chrome 설치 완료" -ForegroundColor Green
                            Write-OptLog -Step "Chrome" -Status "설치됨" -Message "설치 완료 (Direct)"
                        } else {
                            Write-Host "  - Chrome 설치 실패 (ExitCode: $($proc.ExitCode))" -ForegroundColor Red
                            Write-OptLog -Step "Chrome" -Status "실패" -Message "ExitCode: $($proc.ExitCode)"
                        }
                        Remove-Item $msi -Force -ErrorAction SilentlyContinue
                    }
                } catch {
                     Write-Host "  - Chrome 다운로드 실패: $_" -ForegroundColor Red
                     Write-OptLog -Step "Chrome" -Status "실패" -Message "다운로드 오류"
                }
            }

            # Disable default browser check
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "DefaultBrowserSettingEnabled" -Value 0
            Write-Debug-Log "[END] Chrome installation step"
        }
    },

    # --- 7-Zip ---
    @{
        Name = "7-Zip 설치"
        Action = {
            Write-Debug-Log "[START] 7-Zip installation step"
            Install-WithWinget -Name "7-Zip" -WingetId "7zip.7zip" -CheckPaths @(
                "${env:ProgramFiles}\7-Zip\7z.exe",
                "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
            )
            Write-Debug-Log "[END] 7-Zip installation step"
        }
    },

    # --- Everything ---
    @{
        Name = "Everything 설치"
        Action = {
            Write-Debug-Log "[START] Everything installation step"
            $paths = @("${env:ProgramFiles}\Everything\Everything.exe", "${env:ProgramFiles(x86)}\Everything\Everything.exe")
            $installed = Install-WithWinget -Name "Everything" -WingetId "voidtools.Everything" -CheckPaths $paths

            if ($installed) {
                Write-Debug-Log "Setting up Everything autostart..."
                $installedPath = if (Test-Path $paths[0]) { $paths[0] } else { $paths[1] }
                if ($installedPath -and (Test-Path $installedPath)) {
                    Set-Registry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "Everything" -Value "`"$installedPath`" -startup" -Type String
                }
            }
            Write-Debug-Log "[END] Everything installation step"
        }
    },

    # --- ShareX ---
    @{
        Name = "ShareX 설치 및 설정"
        Action = {
            Write-Debug-Log "[START] ShareX installation step"
            $paths = @("${env:ProgramFiles}\ShareX\ShareX.exe")
            $installed = Install-WithWinget -Name "ShareX" -WingetId "ShareX.ShareX" -CheckPaths $paths

            # Config
            Write-Debug-Log "Setting up ShareX config..."
            $cfgPath = "$env:USERPROFILE\Documents\ShareX\ApplicationConfig.json"
            if (-not (Test-Path $cfgPath)) {
                New-Item -Path (Split-Path $cfgPath) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                try {
                    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Configs/ShareX/ApplicationConfig.json" -OutFile $cfgPath -UseBasicParsing -TimeoutSec 30
                    Write-OptLog -Step "ShareX Config" -Status "적용됨" -Message "설정 파일 다운로드"
                } catch {
                    Write-Debug-Log "Config download failed: $_"
                }
            }

            # Startup (Tray mode)
            if (Test-Path $paths[0]) {
                Set-Registry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "ShareX" -Value "`"$($paths[0])`" -silent" -Type String
            }

            # Remove Context Menus
            Write-Debug-Log "Removing ShareX context menus..."
            $ctxPaths = @(
                "HKCR:\*\shell\ShareX", "HKLM:\SOFTWARE\Classes\*\shell\ShareX", "HKCU:\SOFTWARE\Classes\*\shell\ShareX",
                "HKCR:\Directory\shell\ShareX", "HKLM:\SOFTWARE\Classes\Directory\shell\ShareX", "HKCU:\SOFTWARE\Classes\Directory\shell\ShareX"
            )
            foreach ($p in $ctxPaths) {
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Write-Debug-Log "[END] ShareX installation step"
        }
    },

    # --- Honeyview ---
    @{
        Name = "Honeyview 설치 및 설정"
        Action = {
            Write-Debug-Log "[START] Honeyview installation step"
            $paths = @("${env:ProgramFiles}\Honeyview\Honeyview.exe")
            Install-WithWinget -Name "Honeyview" -WingetId "Bandisoft.Honeyview" -CheckPaths $paths

            # Registry Config
            Write-Debug-Log "Applying Honeyview registry settings..."
            $reg = "HKCU:\Software\Honeyview"
            Set-Registry -Path $reg -Name "bStretchWhenSmall" -Value 1 -Description "작은 이미지 늘리기"
            Set-Registry -Path $reg -Name "bLockTitlebarNormal" -Value 0 -Description "제목표시줄 고정 해제"
            Set-Registry -Path $reg -Name "bLockControlbar" -Value 0 -Description "컨트롤바 고정 해제"
            # Enter key fullscreen
            Set-Registry -Path $reg -Name "CustomKey_Enable_00" -Value 1
            Set-Registry -Path $reg -Name "CustomKey_Key_00" -Value 0x0d
            Set-Registry -Path $reg -Name "CustomKey_Cmd_00" -Value "CMD_FULLSCREEN" -Type String
            Write-Debug-Log "[END] Honeyview installation step"
        }
    },

    # --- PotPlayer ---
    @{
        Name = "PotPlayer 설치 및 설정"
        Action = {
            Write-Debug-Log "[START] PotPlayer installation step"
            $paths = @("${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe")

            # PotPlayer is not in winget with good ID, use direct download
            Install-Direct -Name "PotPlayer" `
                -Url "https://t1.kakaocdn.net/potplayer/PotPlayer/Version/Latest/PotPlayerSetup64.exe" `
                -InstallerName "PotPlayerSetup64.exe" `
                -Arguments "/S" `
                -CheckPaths $paths

            # Config (INI Mode)
            Write-Debug-Log "Applying PotPlayer registry settings..."
            $reg = "HKCU:\Software\DAUM\PotPlayerMini64"
            Set-Registry -Path $reg -Name "UseIni" -Value 1
            Set-Registry -Path $reg -Name "CheckAutoUpdate" -Value 0

            # UI Tweaks
            $pos = "HKCU:\Software\DAUM\PotPlayer64\Positions"
            Set-Registry -Path $pos -Name "ChatWindowVisible" -Value 0
            Set-Registry -Path $pos -Name "PlayListWindowVisible" -Value 0
            Set-Registry -Path $pos -Name "BroadcastListWindowVisible" -Value 0

            # Shortcuts
            $sc = "HKCU:\Software\DAUM\PotPlayer64\MainShortCutList"
            Set-Registry -Path $sc -Name "0" -Value "112,6,10281,1" -Type String
            Set-Registry -Path $sc -Name "1" -Value "113,6,10282,1" -Type String
            Set-Registry -Path $sc -Name "2" -Value "114,6,10283,1" -Type String
            Set-Registry -Path $sc -Name "3" -Value "115,6,10284,1" -Type String
            Set-Registry -Path $sc -Name "4" -Value "116,6,10285,1" -Type String
            Set-Registry -Path $sc -Name "5" -Value "87,2,57665,0" -Type String
            Set-Registry -Path $sc -Name "6" -Value "" -Type String

            # INI File
            Write-Debug-Log "Downloading PotPlayer INI config..."
            $confDir = "$env:APPDATA\PotPlayerMini64"
            if (!(Test-Path $confDir)) { New-Item -Path $confDir -ItemType Directory -Force | Out-Null }
            try {
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Configs/PotPlayer/PotPlayerMini64.ini" -OutFile "$confDir\PotPlayerMini64.ini" -UseBasicParsing -TimeoutSec 30
            } catch {
                Write-Debug-Log "INI download failed: $_"
            }
            Write-Debug-Log "[END] PotPlayer installation step"
        }
    },

    # --- File Associations ---
    @{
        Name = "파일 연결 설정 (SetUserFTA)"
        Action = {
            Write-Debug-Log "[START] file association step"

            # Download Tool
            $setUserFtaPath = Join-Path $env:TEMP "SetUserFTA.exe"
            $url = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Utils/SetUserFTA.exe"
            Write-Debug-Log "Downloading SetUserFTA..."
            try {
                Invoke-WebRequest -Uri $url -OutFile $setUserFtaPath -UseBasicParsing -TimeoutSec 30
            } catch {
                Write-Host "  - SetUserFTA 다운로드 실패, 파일 연결 스킵" -ForegroundColor Red
                Write-Debug-Log "SetUserFTA download failed: $_"
                return
            }

            if (-not (Test-Path $setUserFtaPath)) {
                Write-Debug-Log "SetUserFTA not found after download"
                return
            }

            # 1. Notepad++
            Write-Debug-Log "Setting up Notepad++ file associations..."
            $npp = "${env:ProgramFiles}\Notepad++\notepad++.exe"
            if (Test-Path $npp) {
                $exts = @(".txt", ".ini", ".log", ".md", ".json", ".xml", ".yaml", ".sql", ".sh", ".cfg", ".conf", ".properties")
                $progId = "Notepad++_file"

                $hkcu = "HKCU:\SOFTWARE\Classes\$progId"
                if (!(Test-Path $hkcu)) { New-Item "$hkcu\shell\open\command" -Force | Out-Null }
                Set-ItemProperty $hkcu -Name "(Default)" -Value "Notepad++ Document" -Force
                Set-ItemProperty "$hkcu\shell\open\command" -Name "(Default)" -Value "`"$npp`" `"%1`"" -Force

                foreach ($ext in $exts) {
                    Write-Debug-Log "  Setting $ext -> $progId"
                    $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                    $openWith = "$fileExtPath\OpenWithProgids"
                    if (!(Test-Path $openWith)) { New-Item -Path $openWith -Force | Out-Null }

                    $props = Get-ItemProperty -Path $openWith -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($p in $props.PSObject.Properties) {
                            if ($p.Name -notlike "PS*") { Remove-ItemProperty -Path $openWith -Name $p.Name -ErrorAction SilentlyContinue }
                        }
                    }
                    New-ItemProperty -Path $openWith -Name $progId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null
                    Remove-Item "$fileExtPath\OpenWithList" -Recurse -Force -ErrorAction SilentlyContinue
                    try { Remove-Item "$fileExtPath\UserChoice" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -Wait
                }
                Write-Host "  - Notepad++ 파일 연결 완료" -ForegroundColor Green
            }

            # 2. Honeyview (Images)
            Write-Debug-Log "Removing Photos app..."
            Get-AppxPackage *Photos* | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*Photos*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null

            Write-Debug-Log "Setting up Honeyview file associations..."
            $hv = "${env:ProgramFiles}\Honeyview\Honeyview.exe"
            if (Test-Path $hv) {
                $imgs = @(
                    ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".ico", ".webp",
                    ".tiff", ".tif", ".heic", ".heif", ".avif",
                    ".cr2", ".nef", ".arw", ".dng", ".orf", ".rw2",
                    ".psd", ".jfif", ".jpe", ".wdp", ".jxr"
                )

                foreach ($ext in $imgs) {
                    Write-Debug-Log "  Setting $ext -> Honeyview"
                    $extNoDot = $ext.TrimStart('.')
                    $progId = "Honeyview.$extNoDot"

                    $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                    $openWithProgids = "$fileExtPath\OpenWithProgids"
                    if (!(Test-Path $openWithProgids)) { New-Item -Path $openWithProgids -Force | Out-Null }

                    $props = Get-ItemProperty -Path $openWithProgids -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($p in $props.PSObject.Properties) {
                            if ($p.Name -notlike "PS*") { Remove-ItemProperty -Path $openWithProgids -Name $p.Name -ErrorAction SilentlyContinue }
                        }
                    }
                    New-ItemProperty -Path $openWithProgids -Name $progId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null

                    $openWithList = "$fileExtPath\OpenWithList"
                    if (Test-Path $openWithList) { Remove-Item -Path $openWithList -Recurse -Force -ErrorAction SilentlyContinue }

                    $userChoice = "$fileExtPath\UserChoice"
                    if (Test-Path $userChoice) {
                        try { Remove-Item -Path $userChoice -Recurse -Force -ErrorAction SilentlyContinue } catch {}
                    }

                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -Wait
                }
                Write-Host "  - Honeyview 이미지 연결 완료" -ForegroundColor Green
            }

            # 3. PotPlayer (Video & Audio)
            Write-Debug-Log "Setting up PotPlayer file associations..."
            $pot = "${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe"
            if (Test-Path $pot) {
                $vids = @(".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".mpg", ".mpeg", ".ts", ".3gp", ".m2ts", ".vob")
                $auds = @(".mp3", ".flac", ".wav", ".aac", ".ogg", ".wma", ".m4a", ".opus", ".aiff", ".ape", ".alac", ".dsd", ".dsf", ".dff")
                $allMedia = $vids + $auds

                foreach ($ext in $allMedia) {
                    Write-Debug-Log "  Setting $ext -> PotPlayer"
                    $extNoDot = $ext.TrimStart('.')
                    $progId = "PotPlayer64.$extNoDot"

                    $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                    $openWith = "$fileExtPath\OpenWithProgids"
                    if (!(Test-Path $openWith)) { New-Item -Path $openWith -Force | Out-Null }

                    $props = Get-ItemProperty -Path $openWith -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($p in $props.PSObject.Properties) {
                            if ($p.Name -notlike "PS*") { Remove-ItemProperty -Path $openWith -Name $p.Name -ErrorAction SilentlyContinue }
                        }
                    }
                    New-ItemProperty -Path $openWith -Name $progId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null

                    Remove-Item "$fileExtPath\OpenWithList" -Recurse -Force -ErrorAction SilentlyContinue
                    try { Remove-Item "$fileExtPath\UserChoice" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -Wait
                }
                Write-Host "  - PotPlayer 미디어 연결 완료" -ForegroundColor Green
            }

            # 4. Chrome (Browser)
            Write-Debug-Log "Setting up Chrome file associations..."
            $chrome = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
            if (-not (Test-Path $chrome)) {
                $chrome = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
            }
            if (Test-Path $chrome) {
                $webs = @(".html", ".htm", "http", "https")
                foreach ($ext in $webs) {
                    Write-Debug-Log "  Setting $ext -> ChromeHTML"
                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext ChromeHTML" -NoNewWindow -Wait
                }
                Write-Host "  - Chrome 브라우저 연결 완료" -ForegroundColor Green
            }

            Write-Debug-Log "[END] file association step"
        }
    }
)

Run-OptimizationSteps -Title "필수 소프트웨어 설치" -Steps $steps




