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
        Name = "파일 연결 설정 (시스템 기본값)"
        Action = {
            Write-Debug-Log "[START] 파일 연결 설정 (XML Import)"

            # 연결할 목록 정의
            $associations = @()

            # Helper Function
            function Add-Assoc {
                param($Ext, $ProgId, $AppName)
                # Note: modifying parent scope variable
                $script:associationsTemp += [PSCustomObject]@{
                    Identifier = $Ext
                    ProgId = $ProgId
                    ApplicationName = $AppName
                }
            }
            $script:associationsTemp = @()

            # 1. Notepad++
            $nppPath = $null
            if (Test-Path "${env:ProgramFiles}\Notepad++\notepad++.exe") { $nppPath = "${env:ProgramFiles}\Notepad++\notepad++.exe" }
            elseif (Test-Path "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe") { $nppPath = "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe" }

            if ($nppPath) {
                # Ensure ProgID exists (HKLM & HKCU)
                $progId = "Notepad++_file"
                
                # HKLM (System-wide, required for ftype/DefaultAssociations to see it reliably)
                $hklm = "HKLM:\SOFTWARE\Classes\$progId"
                if (!(Test-Path $hklm)) {
                     New-Item "$hklm\shell\open\command" -Force | Out-Null 
                     Set-ItemProperty $hklm -Name "(Default)" -Value "Notepad++ Document" -Force
                     Set-ItemProperty "$hklm\shell\open\command" -Name "(Default)" -Value "`"$nppPath`" `"%1`"" -Force
                }
                
                # HKCU (Per-user fallback)
                $hkcu = "HKCU:\SOFTWARE\Classes\$progId"
                if (!(Test-Path $hkcu)) { 
                    New-Item "$hkcu\shell\open\command" -Force | Out-Null 
                    Set-ItemProperty $hkcu -Name "(Default)" -Value "Notepad++ Document" -Force
                    Set-ItemProperty "$hkcu\shell\open\command" -Name "(Default)" -Value "`"$nppPath`" `"%1`"" -Force
                }

                $nppExts = @(
                    ".txt", ".ini", ".log", ".md", ".json", ".xml", ".yaml", ".sql", ".sh", ".cfg", ".conf", ".properties",
                    ".inf", ".scp", ".wtx", ".ps1", ".psd1", ".psm1", ".css", ".js", ".ts", ".bat", ".cmd", ".vbs", ".reg"
                )
                foreach ($ext in $nppExts) { 
                    Add-Assoc -Ext $ext -ProgId $progId -AppName "Notepad++"
                }
                Write-Host "  - Notepad++ 확장자 목록 준비 완료" -ForegroundColor Gray
            }

            # 2. Honeyview (Images)
            # Remove Photos app
            Get-AppxPackage *Photos* | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*Photos*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null

            $hvPath = $null
            if (Test-Path "${env:ProgramFiles}\Honeyview\Honeyview.exe") { $hvPath = "${env:ProgramFiles}\Honeyview\Honeyview.exe" }
            elseif (Test-Path "${env:ProgramFiles(x86)}\Honeyview\Honeyview.exe") { $hvPath = "${env:ProgramFiles(x86)}\Honeyview\Honeyview.exe" }

            if ($hvPath) {
                # Define ProgIDs for Honeyview if not present
                # Honeyview usually registers Honeyview.jpg, Honeyview.png etc. 
                # Use a specific one for reference or ensure we register generic
                
                $hvExts = @(
                    ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".ico", ".webp",
                    ".tiff", ".tif", ".heic", ".heif", ".avif", ".psd", ".jfif", ".jpe",
                    ".wdp", ".jxr", ".rle", ".wmf", ".emf"
                )
                foreach ($ext in $hvExts) { 
                    $cleanExt = $ext.TrimStart('.')
                    $hvProgId = "Honeyview.$cleanExt"
                    
                    # Ensure HKLM ProgId exists for each ext
                    $hvKey = "HKLM:\SOFTWARE\Classes\$hvProgId"
                    if (!(Test-Path $hvKey)) {
                        New-Item "$hvKey\shell\open\command" -Force | Out-Null
                        Set-ItemProperty $hvKey -Name "(Default)" -Value "Honeyview Image" -Force
                        Set-ItemProperty "$hvKey\shell\open\command" -Name "(Default)" -Value "`"$hvPath`" `"%1`"" -Force
                    }

                    Add-Assoc -Ext $ext -ProgId $hvProgId -AppName "꿀뷰"
                }
                Write-Host "  - Honeyview 확장자 목록 준비 완료" -ForegroundColor Gray
            }

            # 3. PotPlayer (Video/Audio)
            $potPath = "${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe"
            if (Test-Path $potPath) {
                $mediaExts = @(
                    ".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".mpg", ".mpeg", ".ts", ".3gp", ".m2ts", ".vob",
                    ".mp3", ".flac", ".wav", ".aac", ".ogg", ".wma", ".m4a", ".opus", ".aiff", ".ape"
                )
                foreach ($ext in $mediaExts) {
                    $cleanExt = $ext.TrimStart('.')
                    $potProgId = "PotPlayer64.$cleanExt"
                    
                    # Ensure HKLM ProgId exists
                    $potKey = "HKLM:\SOFTWARE\Classes\$potProgId"
                    if (!(Test-Path $potKey)) {
                        New-Item "$potKey\shell\open\command" -Force | Out-Null
                        Set-ItemProperty $potKey -Name "(Default)" -Value "PotPlayer Media" -Force
                        Set-ItemProperty "$potKey\shell\open\command" -Name "(Default)" -Value "`"$potPath`" `"%1`"" -Force
                    }

                    Add-Assoc -Ext $ext -ProgId $potProgId -AppName "팟플레이어(64 비트)"
                }
                Write-Host "  - PotPlayer 확장자 목록 준비 완료" -ForegroundColor Gray
            }

            # 4. Chrome (Web)
            $chromePath = $null
            if (Test-Path "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe") { $chromePath = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe" }
            elseif (Test-Path "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") { $chromePath = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe" }

            if ($chromePath) {
                # Ensure ChromeHTML ProgID exists (usually does, but for safety)
                $chromeProgId = "ChromeHTML"
                
                # HKLM
                $chromeKey = "HKLM:\SOFTWARE\Classes\$chromeProgId"
                if (!(Test-Path $chromeKey)) {
                    New-Item "$chromeKey\shell\open\command" -Force | Out-Null
                    Set-ItemProperty $chromeKey -Name "(Default)" -Value "Chrome HTML Document" -Force
                    Set-ItemProperty "$chromeKey\shell\open\command" -Name "(Default)" -Value "`"$chromePath`" --single-argument `"%1`"" -Force
                }

                $webExts = @(".html", ".htm", "http", "https", ".shtml", ".xht", ".xhtml")
                foreach ($ext in $webExts) { 
                    Add-Assoc -Ext $ext -ProgId $chromeProgId -AppName "Google Chrome"
                }
                Write-Host "  - Chrome 확장자 목록 준비 완료" -ForegroundColor Gray
            }

            # XML 생성
            if ($script:associationsTemp.Count -gt 0) {
                # C:\ProgramData에 저장하여 영구적으로 사용
                $configDir = "$env:ProgramData\WindowsOptimization"
                if (-not (Test-Path $configDir)) { New-Item -Path $configDir -ItemType Directory -Force | Out-Null }
                
                $xmlPath = Join-Path $configDir "DefaultAppAssociations.xml"
                
                $xmlBuilder = New-Object System.Text.StringBuilder
                [void]$xmlBuilder.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
                [void]$xmlBuilder.AppendLine('<DefaultAssociations>')
                
                foreach ($assoc in $script:associationsTemp) {
                    $line = '  <Association Identifier="{0}" ProgId="{1}" ApplicationName="{2}" />' -f $assoc.Identifier, $assoc.ProgId, $assoc.ApplicationName
                    [void]$xmlBuilder.AppendLine($line)
                }
                
                [void]$xmlBuilder.AppendLine('</DefaultAssociations>')
                
                Set-Content -Path $xmlPath -Value $xmlBuilder.ToString() -Encoding UTF8 -Force
                
                # Registry Policy 설정 (기존 유저 적용 - 강제)
                Write-Debug-Log "Applying DefaultAssociationsConfiguration policy..."
                Write-Host "  - 기본 앱 연결 정책 설정 중 (Registry Policy)..." -ForegroundColor Yellow
                
                $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
                
                try {
                    if (-not (Test-Path $policyPath)) { New-Item -Path $policyPath -Force | Out-Null }
                    
                    # Set-Registry 함수 사용 (core.ps1에 정의됨)
                    Set-Registry -Path $policyPath -Name "DefaultAssociationsConfiguration" -Value $xmlPath -Type String
                    
                    # GPUpdate 트리거 (선택 사항, 즉시 적용 시도)
                    Start-Process -FilePath "gpupdate.exe" -ArgumentList "/force" -NoNewWindow -Wait
                    
                    Write-Host "  - 앱 연결 정책 설정 완료 (재로그인 시 적용)" -ForegroundColor Green
                    Write-OptLog -Step "FileAssoc" -Status "완료" -Message "Policy Set: $xmlPath"
                } catch {
                    Write-Host "  - 정책 설정 실패: $_" -ForegroundColor Red
                    Write-OptLog -Step "FileAssoc" -Status "실패" -Message "Policy Error: $_"
                }
                
                # UserChoice 초기화 (기존 유저 강제 적용을 위해)
                Write-Debug-Log "Resetting UserChoice for target extensions..."
                Write-Host "  - 기존 파일 연결 초기화 중 (UserChoice 삭제)..." -ForegroundColor Yellow
                
                foreach ($assoc in $script:associationsTemp) {
                    $ext = $assoc.Identifier
                    $userChoicePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
                    if (Test-Path $userChoicePath) {
                        try {
                            # 권한 문제로 실패할 수 있으나 시도함
                            Remove-Item -Path $userChoicePath -Force -ErrorAction SilentlyContinue
                        } catch {
                            Write-Debug-Log "Failed to remove UserChoice for $ext"
                        }
                    }
                }
                Write-Host "  - 기존 파일 연결 초기화 완료" -ForegroundColor Gray

            } else {
                Write-Host "  - 설정할 파일 연결 없음" -ForegroundColor Gray
            }
            $script:associationsTemp = $null

            Write-Debug-Log "[END] 파일 연결 설정 (Registry Policy)"
        }
    }
)

Run-OptimizationSteps -Title "필수 소프트웨어 설치" -Steps $steps





