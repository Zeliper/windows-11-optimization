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
    "Microsoft.BingFinance", "Microsoft.BingSports", "Microsoft.GetHelp", "Microsoft.Getstarted",
    "Microsoft.Messaging", "Microsoft.Microsoft3DViewer", "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MixedReality.Portal", "Microsoft.OneConnect", "Microsoft.People", "Microsoft.SkypeApp",
    "Microsoft.Wallet", "Microsoft.WindowsAlarms", "Microsoft.WindowsCommunicationsApps", 
    "Microsoft.WindowsFeedbackHub", "Microsoft.WindowsMaps", "Microsoft.WindowsSoundRecorder",
    "Microsoft.Xbox.TCUI", "Microsoft.XboxApp", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay", "Microsoft.YourPhone",
    "Microsoft.ZuneVideo", "Microsoft.ZuneMusic", "Microsoft.PowerAutomateDesktop", "Microsoft.Todos",
    "Microsoft.Windows.DevHome", "MicrosoftTeams", "MSTeams", "MicrosoftCorporationII.MicrosoftTeams",
    "Disney.37853FC22B2CE", "SpotifyAB.SpotifyMusic", "Clipchamp.Clipchamp", "BytedancePte.Ltd.TikTok",
    "Facebook.Instagram", "9E2F88E3.Twitter", "AmazonVideo.PrimeVideo", "Netflix", "DolbyLaboratories.DolbyAccess"
)

$steps = @(
    @{
        Name = "현재 사용자 앱 제거"
        Action = {
            $packages = Get-AppxPackage
            foreach ($app in $bloatwareApps) {
                $matched = $packages | Where-Object { $_.Name -like "*$app*" }
                foreach ($p in $matched) {
                    Write-Host "  Removing $($p.Name)..." -ForegroundColor Gray
                    Remove-AppxPackage -Package $p.PackageFullName -ErrorAction SilentlyContinue
                    Write-OptLog -Step "User Apps" -Status "Applied" -Message "Removed $($p.Name)"
                }
            }
        }
    },
    @{
        Name = "모든 사용자/프로비저닝 앱 제거"
        Action = {
            # Provisioned packages (prevents new users from getting them)
            $prov = Get-AppxProvisionedPackage -Online
            foreach ($app in $bloatwareApps) {
                $matched = $prov | Where-Object { $_.PackageName -like "*$app*" }
                foreach ($p in $matched) {
                     Write-Host "  Deprovisioning $($p.DisplayName)..." -ForegroundColor Gray
                     Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction SilentlyContinue | Out-Null
                     Write-OptLog -Step "Provisioned Apps" -Status "Applied" -Message "Removed $($p.DisplayName)"
                }
            }
        }
    },
    @{
        Name = "선택적 기능 정리"
        Action = {
            $features = @("MathRecognizer", "Microsoft.Windows.WordPad", "Printing-XPSServices-Features")
            foreach ($f in $features) {
                $cap = Get-WindowsCapability -Online | Where-Object { $_.Name -like "*$f*" -and $_.State -eq "Installed" }
                if ($cap) {
                    Write-Host "  Removing feature $($cap.Name)..." -ForegroundColor Gray
                    Remove-WindowsCapability -Online -Name $cap.Name -ErrorAction SilentlyContinue | Out-Null
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
            
            # Teams
            $teamsPaths = @("$env:LOCALAPPDATA\Microsoft\Teams", "$env:ProgramData\Microsoft\Teams")
            foreach ($path in $teamsPaths) {
                if (Test-Path $path) { Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue }
            }
            Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "com.squirrel.Teams.Teams" -ErrorAction SilentlyContinue
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
