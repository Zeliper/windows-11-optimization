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
    @{
        Name = "Notepad++ 설치"
        Action = {
            $paths = @("${env:ProgramFiles}\Notepad++\notepad++.exe", "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe")
            if (Test-SoftwareInstalled -Name "Notepad++" -Paths $paths -WingetId "Notepad++.Notepad++") {
                Write-Host "  - Notepad++ 이미 설치됨 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step "Notepad++" -Status "스킵됨" -Message "이미 설치됨"
            } else {
                Write-Host "  - winget으로 설치 중..." -ForegroundColor Yellow
                $res = winget install Notepad++.Notepad++ --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
                if ($LASTEXITCODE -eq 0 -or $res -match "already installed") {
                    Write-OptLog -Step "Notepad++" -Status "설치됨" -Message "설치 완료"
                } else {
                    throw "설치 실패: $res"
                }
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

    # --- ShareX ---
    @{
        Name = "ShareX 설치 및 설정"
        Action = {
            # 1. Install
            $paths = @("${env:ProgramFiles}\ShareX\ShareX.exe")
            if (Test-SoftwareInstalled -Name "ShareX" -Paths $paths -WingetId "ShareX.ShareX") {
                Write-Host "  - ShareX 이미 설치됨" -ForegroundColor Gray
            } else {
                Write-Host "  - ShareX 설치 중 (winget)..." -ForegroundColor Yellow
                winget install ShareX.ShareX --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
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
                Write-Host "  - 설치 중 (winget)..." -ForegroundColor Yellow
                winget install Bandisoft.Honeyview --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
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
            
            # 4. INI File
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
                $exts = @(".txt", ".ini", ".log", ".md", ".json", ".xml", ".yaml", ".sql", ".sh")
                $progId = "Notepad++_file"
                
                # Register ProgID in Registry
                $hkcu = "HKCU:\SOFTWARE\Classes\$progId"
                if (!(Test-Path $hkcu)) { New-Item "$hkcu\shell\open\command" -Force | Out-Null }
                Set-ItemProperty $hkcu -Name "(Default)" -Value "Notepad++ Document" -Force
                Set-ItemProperty "$hkcu\shell\open\command" -Name "(Default)" -Value "`"$npp`" `"%1`"" -Force
                
                foreach ($ext in $exts) {
                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $progId" -NoNewWindow -Wait
                }
                Write-Host "  - Notepad++ 파일 연결 완료" -ForegroundColor Green
            }

            # 2. Honeyview (Images)
            # Remove Photos App first to avoid conflict
            Get-AppxPackage *Photos* | Remove-AppxPackage -ErrorAction SilentlyContinue
            
            $hv = "${env:ProgramFiles}\Honeyview\Honeyview.exe"
            if (Test-Path $hv) {
                $imgs = @(".jpg", ".png", ".gif", ".bmp", ".webp", ".heic")
                foreach ($ext in $imgs) {
                    $pid = "Honeyview" + $ext.TrimStart('.')
                    Start-Process -FilePath $setUserFtaPath -ArgumentList "$ext $pid" -NoNewWindow -Wait
                }
                Write-Host "  - Honeyview 이미지 연결 완료" -ForegroundColor Green
            }
        }
    }
)

Run-OptimizationSteps -Title "필수 소프트웨어 설치" -Steps $steps
