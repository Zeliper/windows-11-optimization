# Windows 11 블로트웨어 제거 스크립트
# 사전 설치된 불필요한 앱 및 기능 제거
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "=== Windows 11 블로트웨어 제거 스크립트 ===" -ForegroundColor Cyan
Write-Host ""


# 제거할 앱 목록 정의
$bloatwareApps = @(
    # Microsoft 기본 앱
    "Microsoft.3DBuilder"
    "Microsoft.549981C3F5F10"          # Cortana
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.BingFinance"
    "Microsoft.BingSports"
    "Microsoft.BingTranslator"
    "Microsoft.BingTravel"
    "Microsoft.BingFoodAndDrink"
    "Microsoft.BingHealthAndFitness"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"              # Tips
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MixedReality.Portal"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Wallet"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCommunicationsApps"  # Mail, Calendar
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"               # Phone Link
    "Microsoft.ZuneMusic"               # Groove Music
    "Microsoft.ZuneVideo"               # Movies & TV
    "Microsoft.GamingApp"               # Xbox App
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.Todos"
    "Microsoft.WindowsCamera"
    "MicrosoftCorporationII.QuickAssist"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.OutlookForWindows"       # New Outlook
    "Microsoft.Copilot"                 # Windows Copilot
    "Microsoft.Windows.DevHome"

    # 제3자 앱 (프리설치)
    "Disney.37853FC22B2CE"              # Disney+
    "SpotifyAB.SpotifyMusic"
    "Clipchamp.Clipchamp"
    "BytedancePte.Ltd.TikTok"
    "5319275A.WhatsAppDesktop"
    "FACEBOOK.FACEBOOK"
    "Facebook.Instagram"
    "9E2F88E3.Twitter"
    "AmazonVideo.PrimeVideo"
    "Netflix"
    "DolbyLaboratories.DolbyAccess"
    "Duolingo-LearnLanguagesforFree"
    "EclipseManager"
    "ActiproSoftwareLLC"
    "AdobeSystemsIncorporated.AdobePhotoshopExpress"
    "CandyCrush"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushSodaSaga"
    "king.com.CandyCrushFriends"
    "king.com.FarmHeroesSaga"
    "king.com.BubbleWitch3Saga"
    "Zynga"
    "NORDCURRENT.COOKINGFEVER"
    "PandoraMediaInc"
    "Fitbit.FitbitCoach"
    "Flipboard.Flipboard"
    "ShazamEntertainmentLtd.Shazam"
    "LinkedInforWindows"
    "GAMELOFTSA"
    "A278AB0D.MarchofEmpires"
    "A278AB0D.DragonManiaLegends"
    "Drawboard.DrawboardPDF"
    "D5EA27B7.Duolingo-LearnLanguagesforFree"
    "46928bounde.EclipseManager"
    "D52A8D61.FarmVille2CountryEscape"
    "ThumbmunkeysLtd.PhototasticCollage"
    "TuneIn.TuneInRadio"
    "XINGAG.XING"
)


# 1. UWP 앱 제거 (현재 사용자)
Write-Host "[1/4] 현재 사용자 블로트웨어 앱 제거 중..." -ForegroundColor Yellow

$removedCount = 0
$skippedCount = 0

foreach ($app in $bloatwareApps) {
    $package = Get-AppxPackage -Name "*$app*" -ErrorAction SilentlyContinue
    if ($package) {
        try {
            $package | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Host "  - $($package.Name) 제거됨" -ForegroundColor Green
            $removedCount++
        }
        catch {
            Write-Host "  - $app 제거 실패" -ForegroundColor Red
        }
    }
}

if ($removedCount -eq 0) {
    Write-Host "  - 제거할 앱이 없습니다 (이미 제거됨)" -ForegroundColor Yellow
} else {
    Write-Host "  - 총 $removedCount 개 앱 제거 완료" -ForegroundColor Green
}


# 2. 모든 사용자에서 앱 제거
Write-Host ""
Write-Host "[2/4] 모든 사용자 블로트웨어 앱 제거 중..." -ForegroundColor Yellow

$allUsersRemoved = 0
foreach ($app in $bloatwareApps) {
    $package = Get-AppxPackage -AllUsers -Name "*$app*" -ErrorAction SilentlyContinue
    if ($package) {
        try {
            $package | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            $allUsersRemoved++
        }
        catch {
            # 일부 앱은 AllUsers에서 제거 불가
        }
    }
}

if ($allUsersRemoved -gt 0) {
    Write-Host "  - 총 $allUsersRemoved 개 앱 (AllUsers) 제거 완료" -ForegroundColor Green
} else {
    Write-Host "  - 추가 제거할 앱 없음" -ForegroundColor Yellow
}


# 3. 프로비저닝된 앱 제거 (새 사용자 계정에 설치 방지)
Write-Host ""
Write-Host "[3/4] 프로비저닝된 패키지 제거 중 (새 사용자 설치 방지)..." -ForegroundColor Yellow

$provisionedRemoved = 0
$provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

foreach ($app in $bloatwareApps) {
    $matched = $provisionedPackages | Where-Object { $_.PackageName -like "*$app*" }
    foreach ($pkg in $matched) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  - $($pkg.DisplayName) 프로비저닝 제거됨" -ForegroundColor Green
            $provisionedRemoved++
        }
        catch {
            # 일부 패키지는 제거 불가
        }
    }
}

if ($provisionedRemoved -eq 0) {
    Write-Host "  - 프로비저닝된 블로트웨어 없음" -ForegroundColor Yellow
} else {
    Write-Host "  - 총 $provisionedRemoved 개 프로비저닝 패키지 제거 완료" -ForegroundColor Green
}


# 4. Windows 선택적 기능 제거
Write-Host ""
Write-Host "[4/4] 불필요한 Windows 기능 제거 중..." -ForegroundColor Yellow

$features = @(
    "MathRecognizer"           # 수학 인식기
    "Microsoft.Windows.WordPad" # 워드패드
    "Printing-XPSServices-Features" # XPS 서비스
    "Internet-Explorer-Optional-amd64" # Internet Explorer (레거시)
)

foreach ($feature in $features) {
    $capability = Get-WindowsCapability -Online | Where-Object { $_.Name -like "*$feature*" -and $_.State -eq "Installed" }
    if ($capability) {
        try {
            $capability | Remove-WindowsCapability -Online -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  - $($capability.Name) 기능 제거됨" -ForegroundColor Green
        }
        catch {
            Write-Host "  - $feature 기능 제거 실패" -ForegroundColor Red
        }
    }
}

# 선택적 기능 (DISM 방식)
$optionalFeatures = @(
    "WindowsMediaPlayer"       # Windows Media Player
    "WorkFolders-Client"       # 작업 폴더
)

foreach ($feature in $optionalFeatures) {
    $state = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
    if ($state -and $state.State -eq "Enabled") {
        try {
            Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  - $feature 기능 비활성화됨" -ForegroundColor Green
        }
        catch {
            # 일부 기능은 비활성화 불가
        }
    }
}

Write-Host "  - Windows 기능 정리 완료" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 블로트웨어 제거가 완료되었습니다!" -ForegroundColor Green
Write-Host ""
Write-Host "제거된 항목:" -ForegroundColor Yellow
Write-Host "  - Microsoft 기본 앱 (Cortana, Xbox, People 등)" -ForegroundColor White
Write-Host "  - 사전 설치된 제3자 앱 (게임, SNS 등)" -ForegroundColor White
Write-Host "  - 불필요한 Windows 기능" -ForegroundColor White
Write-Host ""
Write-Host "참고: 일부 시스템 앱은 보호되어 제거되지 않습니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
