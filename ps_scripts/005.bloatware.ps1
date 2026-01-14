# Windows 11 Bloatware Removal Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "005.bloatware.ps1" -ScriptVersion "1.2.0"

# List of apps to remove
$bloatwareApps = @(
    "Microsoft.3DBuilder", "Microsoft.549981C3F5F10", "Microsoft.BingNews", "Microsoft.BingWeather",
    "Microsoft.BingFinance", "Microsoft.BingSports", "Microsoft.BingTranslator", "Microsoft.BingTravel",
    "Microsoft.BingFoodAndDrink", "Microsoft.BingHealthAndFitness", "Microsoft.GetHelp", "Microsoft.Getstarted",
    "Microsoft.Messaging", "Microsoft.Microsoft3DViewer", "Microsoft.MicrosoftOfficeHub", "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal", "Microsoft.OneConnect", "Microsoft.People", "Microsoft.Print3D", "Microsoft.SkypeApp",
    "Microsoft.Wallet", "Microsoft.WindowsAlarms", "Microsoft.WindowsCommunicationsApps", 
    "Microsoft.WindowsFeedbackHub", "Microsoft.WindowsMaps", "Microsoft.WindowsSoundRecorder", "Microsoft.WindowsCamera",
    "Microsoft.Xbox.TCUI", "Microsoft.XboxApp", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay", "Microsoft.YourPhone", "Microsoft.ZuneVideo",
    "Microsoft.ZuneMusic", "Microsoft.GamingApp", "Microsoft.PowerAutomateDesktop", "Microsoft.Todos", "Microsoft.ScreenSketch",
    "MicrosoftCorporationII.QuickAssist", "Microsoft.MicrosoftStickyNotes", "Microsoft.OutlookForWindows", "Microsoft.Copilot",
    "Microsoft.Windows.DevHome", "Microsoft.Windows.Photos", "MicrosoftTeams", "MSTeams", "MicrosoftCorporationII.MicrosoftTeams",
    
    # 3rd Party
    "Disney.37853FC22B2CE", "SpotifyAB.SpotifyMusic", "Clipchamp.Clipchamp", "BytedancePte.Ltd.TikTok",
    "5319275A.WhatsAppDesktop", "FACEBOOK.FACEBOOK", "Facebook.Instagram", "9E2F88E3.Twitter",
    "AmazonVideo.PrimeVideo", "Netflix", "DolbyLaboratories.DolbyAccess", "Duolingo-LearnLanguagesforFree",
    "EclipseManager", "ActiproSoftwareLLC", "AdobeSystemsIncorporated.AdobePhotoshopExpress",
    "CandyCrush", "king.com.CandyCrushSaga", "king.com.CandyCrushSodaSaga", "king.com.CandyCrushFriends",
    "king.com.FarmHeroesSaga", "king.com.BubbleWitch3Saga", "Zynga", "NORDCURRENT.COOKINGFEVER",
    "PandoraMediaInc", "Fitbit.FitbitCoach", "Flipboard.Flipboard", "ShazamEntertainmentLtd.Shazam",
    "LinkedInforWindows", "LinkedIn", "7EE7776C.LinkedInforWindows", "GAMELOFTSA", "A278AB0D.MarchofEmpires",
    "A278AB0D.DragonManiaLegends", "Drawboard.DrawboardPDF", "D52A8D61.FarmVille2CountryEscape",
    "ThumbmunkeysLtd.PhototasticCollage", "TuneIn.TuneInRadio", "XINGAG.XING"
)

$steps = @(
    @{
        Name = "현재 사용자 앱 제거"
        Action = {
            # 1. Get All Packages once
            $packages = Get-AppxPackage -ErrorAction SilentlyContinue
            
            foreach ($app in $bloatwareApps) {
                $matched = $packages | Where-Object { $_.Name -like "*$app*" }
                if ($matched) {
                    foreach ($p in $matched) {
                        Write-Host "  Removing $($p.Name)..." -ForegroundColor Gray
                        $p | Remove-AppxPackage -ErrorAction SilentlyContinue
                        Write-OptLog -Step "User Apps" -Status "Applied" -Message "Removed $($p.Name)"
                    }
                }
            }
        }
    },
    @{
        Name = "모든 사용자/프로비저닝 앱 제거"
        Action = {
            # 2. Provisioned Packages
            $prov = Get-AppxProvisionedPackage -Online
            foreach ($app in $bloatwareApps) {
                $matched = $prov | Where-Object { $_.PackageName -like "*$app*" }
                foreach ($p in $matched) {
                     Write-Host "  Deprovisioning $($p.DisplayName)..." -ForegroundColor Gray
                     
                     # Job with timeout for safety
                     $job = Start-Job -ScriptBlock { 
                        param($pkgName)
                        Remove-AppxProvisionedPackage -Online -PackageName $pkgName -ErrorAction SilentlyContinue
                     } -ArgumentList $p.PackageName
                     
                     if (Wait-Job $job -Timeout 60) {
                         Receive-Job $job | Out-Null
                         Write-OptLog -Step "Provisioned Apps" -Status "Applied" -Message "Removed $($p.DisplayName)"
                     } else {
                         Stop-Job $job
                         Write-Host "    - 제거 시간 초과 (건너뜀)" -ForegroundColor Red
                         Write-OptLog -Step "Provisioned Apps" -Status "실패" -Message "Timeout removing $($p.DisplayName)"
                     }
                     Remove-Job $job
                }
            }
            
            # 3. All Users (System-wide removal attempts)
            # Some apps linger in AllUsers even if removed from CurrentUser
            Start-Job -ScriptBlock {
                param($apps)
                foreach ($a in $apps) {
                    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object {$_.Name -like "*$a*"} | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                }
            } -ArgumentList (,$bloatwareApps) | Wait-Job -Timeout 120 | Remove-Job
        }
    },
    @{
        Name = "선택적 기능 정리"
        Action = {
            $features = @("MathRecognizer", "Microsoft.Windows.WordPad", "Printing-XPSServices-Features", "Internet-Explorer-Optional-amd64")
            foreach ($f in $features) {
                if (Get-WindowsCapability -Online | Where-Object { $_.Name -like "*$f*" -and $_.State -eq "Installed" }) {
                    Write-Host "  Removing feature $f..." -ForegroundColor Gray
                    Remove-WindowsCapability -Online -Name $f -ErrorAction SilentlyContinue | Out-Null
                }
            }
            
            # Optional Features (DISM)
            $opt = @("WindowsMediaPlayer", "WorkFolders-Client")
            foreach ($o in $opt) {
                if ((Get-WindowsOptionalFeature -Online -FeatureName $o -ErrorAction SilentlyContinue).State -eq "Enabled") {
                    Write-Host "  Disabling feature $o..." -ForegroundColor Gray
                    Disable-WindowsOptionalFeature -Online -FeatureName $o -NoRestart -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
    },
    @{
        Name = "시작 메뉴 및 Teams 데이터 정리"
        Action = {
            # Start Menu
            $start2 = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
            if (Test-Path $start2) { Remove-Item $start2 -Force; Write-Host "  - 시작 메뉴 레이아웃 초기화" -ForegroundColor Green }
            
            # Start Menu Cache
            $cachePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
            if (Test-Path $cachePath) {
                Get-ChildItem -Path "$cachePath\`$windows.data.unifiedtile.startglobalproperties`$*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                Get-ChildItem -Path "$cachePath\`$windows.data.unifiedtile.pinnedtileiddata`$*" -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }

            # Teams
            $teamsPaths = @("$env:LOCALAPPDATA\Microsoft\Teams", "$env:ProgramData\Microsoft\Teams")
            foreach ($path in $teamsPaths) {
                if (Test-Path $path) { Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "com.squirrel.Teams.Teams" -ErrorAction SilentlyContinue
            Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "Teams" -ErrorAction SilentlyContinue
        }
    }
)

Run-OptimizationSteps -Title "블로트웨어 제거" -Steps $steps

if (-not $global:OrchestrateMode) {
    Write-Host "시작 메뉴 적용을 위해 Explorer를 재시작합니다."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep 1
    Start-Process explorer
}

