# Windows 11 Software Installation Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "006.software_install.ps1" -ScriptVersion "1.2.0"

# --- Helper Functions ---
function Test-SoftwareInstalled {
    param(
        [string]$Name,
        [string[]]$Paths,
        [string]$WingetId = ""
    )
    foreach ($path in $Paths) {
        if (Test-Path $path) { return $true }
    }
    if ($WingetId) {
        $wingetResult = winget list --id $WingetId 2>$null
        if ($LASTEXITCODE -eq 0 -and $wingetResult -notmatch "No installed package") { return $true }
    }
    return $false
}

function Test-FileAssociation {
    param([string]$Extension, [string]$ExpectedProgId)
    $path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$Extension\UserChoice"
    $curr = (Get-ItemProperty -Path $path -Name "ProgId" -ErrorAction SilentlyContinue).ProgId
    return ($curr -and $curr -like "*$ExpectedProgId*")
}

$tempDir = $env:TEMP
$setUserFtaPath = Join-Path $tempDir "SetUserFTA.exe" # Will be set during execution

$steps = @(
    # --- Notepad++ ---
    # --- Notepad++ ---
    @{
        Name = "Notepad++ 설치"
        Action = {
            $paths = @("${env:ProgramFiles}\Notepad++\notepad++.exe", "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe")
            if (Test-SoftwareInstalled -Name "Notepad++" -Paths $paths -WingetId "Notepad++.Notepad++") {
                Write-Host "  - Notepad++ 이미 설치됨 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "Notepad++" -Status "스킵됨" -Message "이미 설치됨"
            } else {
                Write-Host "  - 다운로드 및 설치 중 (Direct)..." -ForegroundColor Yellow
                $installer = Join-Path $tempDir "npp_installer.exe"
                # Using specific version 8.7.5 for stability
                Invoke-WebRequest -Uri "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.7.5/npp.8.7.5.Installer.x64.exe" -OutFile $installer -UseBasicParsing
                
                Start-Process -FilePath $installer -ArgumentList "/S" -Wait -NoNewWindow
                Remove-Item $installer -Force -ErrorAction SilentlyContinue
                Write-OptLog -Step "Notepad++" -Status "설치됨" -Message "설치 완료"
            }
        }
    },
    
    # --- Chrome ---
    @{
        Name = "Chrome 설치"
        Action = {
            $paths = @("${env:ProgramFiles}\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe")
            if (Test-SoftwareInstalled -Name "Chrome" -Paths $paths) {
                 Write-Host "  - Chrome 이미 설치됨 (스킵)" -ForegroundColor Gray
                 Write-OptLog -Step "Chrome" -Status "스킵됨" -Message "이미 설치됨"
            } else {
                $installer = Join-Path $tempDir "chrome_installer.msi"
                Write-Host "  - 다운로드 중..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" -OutFile $installer -UseBasicParsing
                
                Write-Host "  - 설치 중..." -ForegroundColor Yellow
                Start-Process msiexec -ArgumentList "/i `"$installer`" /qn /norestart" -Wait -NoNewWindow
                Remove-Item $installer -Force -ErrorAction SilentlyContinue
                
                # Disable default browser check
                Set-Registry -Path "HKLM:\SOFTWARE\Policies\Google\Chrome" -Name "DefaultBrowserSettingEnabled" -Value 0
                Write-OptLog -Step "Chrome" -Status "설치됨" -Message "MSI 설치 완료"
            }
        }
    },

    # --- 7-Zip ---
    @{
        Name = "7-Zip 설치"
        Action = {
            $paths = @("${env:ProgramFiles}\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe")
            if (Test-SoftwareInstalled -Name "7-Zip" -Paths $paths) {
                Write-Host "  - 7-Zip 이미 설치됨 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "7-Zip" -Status "스킵됨" -Message "이미 설치됨"
            } else {
                $installer = Join-Path $tempDir "7zip_installer.msi"
                Write-Host "  - 다운로드 중..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri "https://www.7-zip.org/a/7z2408-x64.msi" -OutFile $installer -UseBasicParsing
                
                Write-Host "  - 설치 중..." -ForegroundColor Yellow
                Start-Process msiexec -ArgumentList "/i `"$installer`" /qn" -Wait -NoNewWindow
                Remove-Item $installer -Force -ErrorAction SilentlyContinue
                Write-OptLog -Step "7-Zip" -Status "설치됨" -Message "MSI 설치 완료"
            }
        }
    },

    # --- Everything ---
    @{
        Name = "Everything 설치"
        Action = {
            $paths = @("${env:ProgramFiles}\Everything\Everything.exe", "${env:ProgramFiles(x86)}\Everything\Everything.exe")
            if (Test-SoftwareInstalled -Name "Everything" -Paths $paths -WingetId "voidtools.Everything") {
                Write-Host "  - Everything 이미 설치됨 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "Everything" -Status "스킵됨" -Message "이미 설치됨"
            } else {
                Write-Host "  - 다운로드 및 설치 중 (Direct)..." -ForegroundColor Yellow
                $installer = Join-Path $tempDir "Everything.exe"
                # Direct download is faster and more reliable
                Invoke-WebRequest "https://www.voidtools.com/Everything-1.4.1.1024.x64-Setup.exe" -OutFile $installer -UseBasicParsing
                Start-Process -FilePath $installer -ArgumentList "/S" -Wait -NoNewWindow
                Remove-Item $installer -Force -ErrorAction SilentlyContinue
                
                # Auto Start
                $installedPath = if (Test-Path $paths[0]) { $paths[0] } else { $paths[1] }
                if ($installedPath) {
                    Set-Registry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "Everything" -Value "`"$installedPath`" -startup" -Type String
                }
                Write-OptLog -Step "Everything" -Status "설치됨" -Message "설치 완료"
            }
        }
    },

    # --- ShareX ---
    @{
        Name = "ShareX 설치 및 설정"
        Action = {
            # 1. Install
            $paths = @("${env:ProgramFiles}\ShareX\ShareX.exe")
            if (Test-SoftwareInstalled -Name "ShareX" -Paths $paths -WingetId "ShareX.ShareX") {
                Write-Host "  - ShareX 이미 설치됨" -ForegroundColor Gray
            } else {
                Write-Host "  - 다운로드 및 설치 중 (Direct)..." -ForegroundColor Yellow
                $installer = Join-Path $tempDir "ShareX_setup.exe"
                # Using v16.1.0
                Invoke-WebRequest -Uri "https://github.com/ShareX/ShareX/releases/download/v16.1.0/ShareX-16.1.0-setup.exe" -OutFile $installer -UseBasicParsing
                Start-Process -FilePath $installer -ArgumentList "/VERYSILENT /NORESTART" -Wait -NoNewWindow
                Remove-Item $installer -Force -ErrorAction SilentlyContinue
                Write-OptLog -Step "ShareX" -Status "설치됨" -Message "설치 완료"
            }

            # 2. Config
            $cfgPath = "$env:USERPROFILE\Documents\ShareX\ApplicationConfig.json"
            if (-not (Test-Path $cfgPath)) {
                New-Item -Path (Split-Path $cfgPath) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Configs/ShareX/ApplicationConfig.json" -OutFile $cfgPath -UseBasicParsing
                Write-OptLog -Step "ShareX Config" -Status "적용됨" -Message "설정 파일 다운로드"
            }

            # 3. Startup (Tray mode)
            if (Test-Path $paths[0]) {
                Set-Registry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "ShareX" -Value "`"$($paths[0])`" -silent" -Type String
            }

            # 4. Remove Context Menus
            $ctxPaths = @(
                "HKCR:\*\shell\ShareX", "HKLM:\SOFTWARE\Classes\*\shell\ShareX", "HKCU:\SOFTWARE\Classes\*\shell\ShareX",
                "HKCR:\Directory\shell\ShareX", "HKLM:\SOFTWARE\Classes\Directory\shell\ShareX", "HKCU:\SOFTWARE\Classes\Directory\shell\ShareX"
            )
            foreach ($p in $ctxPaths) { 
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
            }
        }
    },

    # --- Honeyview ---
    @{
        Name = "Honeyview 설치 및 설정"
        Action = {
            # 1. Install
            $paths = @("${env:ProgramFiles}\Honeyview\Honeyview.exe")
            if (Test-SoftwareInstalled -Name "Honeyview" -Paths $paths -WingetId "Bandisoft.Honeyview") {
                Write-Host "  - Honeyview 이미 설치됨" -ForegroundColor Gray
            } else {
                Write-Host "  - 다운로드 및 설치 중 (Direct)..." -ForegroundColor Yellow
                $installer = Join-Path $tempDir "HONEYVIEW-SETUP.exe"
                Invoke-WebRequest -Uri "https://dl.bandisoft.com/honeyview/HONEYVIEW-SETUP-KR.EXE" -OutFile $installer -UseBasicParsing
                Start-Process -FilePath $installer -ArgumentList "/S" -Wait -NoNewWindow
                Remove-Item $installer -Force -ErrorAction SilentlyContinue
                Write-OptLog -Step "Honeyview" -Status "설치됨" -Message "설치 완료"
            }

            # 2. Registry Config
            $reg = "HKCU:\Software\Honeyview"
            Set-Registry -Path $reg -Name "bStretchWhenSmall" -Value 1 -Description "작은 이미지 늘리기"
            Set-Registry -Path $reg -Name "bLockTitlebarNormal" -Value 0 -Description "제목표시줄 고정 해제"
            Set-Registry -Path $reg -Name "bLockControlbar" -Value 0 -Description "컨트롤바 고정 해제"
            # Enter key fullscreen
            Set-Registry -Path $reg -Name "CustomKey_Enable_00" -Value 1
            Set-Registry -Path $reg -Name "CustomKey_Key_00" -Value 0x0d
            Set-Registry -Path $reg -Name "CustomKey_Cmd_00" -Value "CMD_FULLSCREEN" -Type String
        }
    },

    # --- PotPlayer ---
    @{
        Name = "PotPlayer 설치 및 설정"
        Action = {
            # 1. Install
            $paths = @("${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe")
            if (Test-SoftwareInstalled -Name "PotPlayer" -Paths $paths) {
                 Write-Host "  - PotPlayer 이미 설치됨" -ForegroundColor Gray
            } else {
                $inst = Join-Path $tempDir "PotPlayerSetup64.exe"
                Write-Host "  - 다운로드 중..." -ForegroundColor Yellow
                Invoke-WebRequest -Uri "https://t1.kakaocdn.net/potplayer/PotPlayer/Version/Latest/PotPlayerSetup64.exe" -OutFile $inst -UseBasicParsing
                Write-Host "  - 설치 중..." -ForegroundColor Yellow
                Start-Process -FilePath $inst -ArgumentList "/S" -Wait -NoNewWindow
                Remove-Item $inst -Force -ErrorAction SilentlyContinue
                Write-OptLog -Step "PotPlayer" -Status "설치됨" -Message "설치 완료"
            }

            # 2. Config (INI Mode)
            $reg = "HKCU:\Software\DAUM\PotPlayerMini64"
            Set-Registry -Path $reg -Name "UseIni" -Value 1
            Set-Registry -Path $reg -Name "CheckAutoUpdate" -Value 0
            
            # 3. UI Tweaks
            $pos = "HKCU:\Software\DAUM\PotPlayer64\Positions"
            Set-Registry -Path $pos -Name "ChatWindowVisible" -Value 0
            Set-Registry -Path $pos -Name "PlayListWindowVisible" -Value 0
            Set-Registry -Path $pos -Name "BroadcastListWindowVisible" -Value 0

            # 4. Shortcuts (Restored from history)
            $sc = "HKCU:\Software\DAUM\PotPlayer64\MainShortCutList"
            # F1~F4 Bookmark, F5 Open, Ctrl+W Exit
            Set-Registry -Path $sc -Name "0" -Value "112,6,10281,1" -Type String
            Set-Registry -Path $sc -Name "1" -Value "113,6,10282,1" -Type String
            Set-Registry -Path $sc -Name "2" -Value "114,6,10283,1" -Type String
            Set-Registry -Path $sc -Name "3" -Value "115,6,10284,1" -Type String
            Set-Registry -Path $sc -Name "4" -Value "116,6,10285,1" -Type String
            Set-Registry -Path $sc -Name "5" -Value "87,2,57665,0" -Type String
            Set-Registry -Path $sc -Name "6" -Value "" -Type String
            
            # 5. INI File
            $confDir = "$env:APPDATA\PotPlayerMini64"
            if (!(Test-Path $confDir)) { New-Item -Path $confDir -ItemType Directory -Force | Out-Null }
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Configs/PotPlayer/PotPlayerMini64.ini" -OutFile "$confDir\PotPlayerMini64.ini" -UseBasicParsing
        }
    },

    # --- File Associations ---
    @{
        Name = "파일 연결 설정 (SetUserFTA)"
        Action = {
            # Download Tool
            $setUserFtaPath = Join-Path $env:TEMP "SetUserFTA.exe"
            $url = "https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/Utils/SetUserFTA.exe"
            try {
                Invoke-WebRequest -Uri $url -OutFile $setUserFtaPath -UseBasicParsing -TimeoutSec 30
            } catch {
                Write-Host "  - SetUserFTA 다운로드 실패, 파일 연결 스킵" -ForegroundColor Red
                return
            }

            if (-not (Test-Path $setUserFtaPath)) { return }

            # 1. Notepad++
            $npp = "${env:ProgramFiles}\Notepad++\notepad++.exe"
            if (Test-Path $npp) {
                $exts = @(".txt", ".ini", ".log", ".md", ".json", ".xml", ".yaml", ".sql", ".sh", ".cfg", ".conf", ".properties")
                $progId = "Notepad++_file"
                
                # Register ProgID in Registry
                $hkcu = "HKCU:\SOFTWARE\Classes\$progId"
                if (!(Test-Path $hkcu)) { New-Item "$hkcu\shell\open\command" -Force | Out-Null }
                Set-ItemProperty $hkcu -Name "(Default)" -Value "Notepad++ Document" -Force
                Set-ItemProperty "$hkcu\shell\open\command" -Name "(Default)" -Value "`"$npp`" `"%1`"" -Force
                
                foreach ($ext in $exts) {
                    # Aggressive Cleanup to prevent prompts
                    $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                    $openWith = "$fileExtPath\OpenWithProgids"
                    if (!(Test-Path $openWith)) { New-Item -Path $openWith -Force | Out-Null }
                    
                    # Clear existing
                    $props = Get-ItemProperty -Path $openWith -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($p in $props.PSObject.Properties) {
                            if ($p.Name -notlike "PS*") { Remove-ItemProperty -Path $openWith -Name $p.Name -ErrorAction SilentlyContinue }
                        }
                    }
                    # Add Ours
                    New-ItemProperty -Path $openWith -Name $progId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null
                    
                    # Clear OpenWithList & UserChoice
                    Remove-Item "$fileExtPath\OpenWithList" -Recurse -Force -ErrorAction SilentlyContinue
                    try { Remove-Item "$fileExtPath\UserChoice" -Recurse -Force -ErrorAction SilentlyContinue } catch {}
                    
                    # Set Association
                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -Wait
                }
                Write-Host "  - Notepad++ 파일 연결 완료 (강제 적용)" -ForegroundColor Green
            }

            # 2. Honeyview (Images)
            # Remove Photos App first to avoid conflict and ensure Honeyview takes precedence
            Get-AppxPackage *Photos* | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*Photos*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
            
            $hv = "${env:ProgramFiles}\Honeyview\Honeyview.exe"
            if (Test-Path $hv) {
                # Detailed Image Extensions List
                $imgs = @(
                    ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".ico", ".webp",
                    ".tiff", ".tif", ".heic", ".heif", ".avif",
                    ".cr2", ".nef", ".arw", ".dng", ".orf", ".rw2",
                    ".psd", ".jfif", ".jpe", ".wdp", ".jxr"
                )
                
                foreach ($ext in $imgs) {
                    $extNoDot = $ext.TrimStart('.')
                    $progId = "Honeyview.$extNoDot"
                    
                    # 1. Clean OpenWithProgids (remove competitors)
                    $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                    $openWithProgids = "$fileExtPath\OpenWithProgids"
                    if (!(Test-Path $openWithProgids)) { New-Item -Path $openWithProgids -Force | Out-Null }
                    
                    # Remove all existing
                    $props = Get-ItemProperty -Path $openWithProgids -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($p in $props.PSObject.Properties) {
                            if ($p.Name -notlike "PS*") { Remove-ItemProperty -Path $openWithProgids -Name $p.Name -ErrorAction SilentlyContinue }
                        }
                    }
                    # Add Honeyview ProgID
                    New-ItemProperty -Path $openWithProgids -Name $progId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null
                    
                    # 2. Clean OpenWithList
                    $openWithList = "$fileExtPath\OpenWithList"
                    if (Test-Path $openWithList) { Remove-Item -Path $openWithList -Recurse -Force -ErrorAction SilentlyContinue }
                    
                    # 3. Clean UserChoice (Force New Hashing by SetUserFTA)
                    $userChoice = "$fileExtPath\UserChoice"
                    if (Test-Path $userChoice) {
                        # Try to correct permission then delete
                        try {
                           $acl = Get-Acl $userChoice
                           # This might fail due to system protection, but SetUserFTA often handles overwrite if key is missing or hashes mismatch
                           # We attempt deletion to be safe
                           Remove-Item -Path $userChoice -Recurse -Force -ErrorAction SilentlyContinue
                        } catch {}
                    }
                    
                    # 4. Set Association
                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -Wait
                }
                Write-Host "  - Honeyview 이미지 연결 완료 (강제 적용)" -ForegroundColor Green
            }

            # 3. PotPlayer (Video & Audio)
            $pot = "${env:ProgramFiles}\DAUM\PotPlayer\PotPlayerMini64.exe"
            if (Test-Path $pot) {
                # Video Extensions
                $vids = @(
                    ".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm",
                    ".m4v", ".mpg", ".mpeg", ".ts", ".3gp", ".m2ts", ".vob"
                )
                # Audio Extensions
                $auds = @(
                    ".mp3", ".flac", ".wav", ".aac", ".ogg", ".wma", ".m4a",
                    ".opus", ".aiff", ".ape", ".alac", ".dsd", ".dsf", ".dff"
                )
                
                $allMedia = $vids + $auds
                
                # PotPlayer Logic: also aggressive cleanup
                foreach ($ext in $allMedia) {
                    $extNoDot = $ext.TrimStart('.')
                    $progId = "PotPlayer64.$extNoDot"
                    
                    # 1. OpenWithProgids
                    $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
                    $openWith = "$fileExtPath\OpenWithProgids"
                    if (!(Test-Path $openWith)) { New-Item -Path $openWith -Force | Out-Null }
                    
                    # Clear existing
                    $props = Get-ItemProperty -Path $openWith -ErrorAction SilentlyContinue
                    if ($props) {
                        foreach ($p in $props.PSObject.Properties) {
                            if ($p.Name -notlike "PS*") { Remove-ItemProperty -Path $openWith -Name $p.Name -ErrorAction SilentlyContinue }
                        }
                    }
                    # Add Ours
                    New-ItemProperty -Path $openWith -Name $progId -PropertyType Binary -Value ([byte[]]@()) -Force -ErrorAction SilentlyContinue | Out-Null
                    
                    # 2. Cleanup Lists
                    Remove-Item "$fileExtPath\OpenWithList" -Recurse -Force -ErrorAction SilentlyContinue
                    try { Remove-Item "$fileExtPath\UserChoice" -Recurse -Force -ErrorAction SilentlyContinue } catch {}

                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -Wait
                }
                Write-Host "  - PotPlayer 미디어 연결 완료 (동영상 & 오디오)" -ForegroundColor Green
            }

            # 4. Chrome (Browser)
            $chrome = "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"
            if (-not (Test-Path $chrome)) { 
                $chrome = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
            }
            if (Test-Path $chrome) {
                $webs = @(".html", ".htm", "http", "https")
                foreach ($ext in $webs) {
                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext ChromeHTML" -NoNewWindow -Wait
                }
                Write-Host "  - Chrome 브라우저 연결 완료" -ForegroundColor Green
            }
        }
    }
)

Run-OptimizationSteps -Title "필수 소프트웨어 설치" -Steps $steps


