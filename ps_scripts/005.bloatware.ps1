# Windows 11 블로트웨어 제거 스크립트
# 사전 설치된 불필요한 앱 및 기능 제거
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.3"

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Progress Bar 비활성화 (병렬 실행 시 출력 겹침 방지)
$ProgressPreference = 'SilentlyContinue'

# Orchestrate 모드 확인
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

# ForceOverride 모드 확인
if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

#region 공통 함수

# 로그 파일 경로 설정
$logFileName = "Windows11Optimizer_005_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir $logFileName
$global:LogEntries = [System.Collections.ArrayList]@()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Message,
        [ValidateSet("Applied", "Skipped", "Failed", "Info")]
        [string]$Status = "Info"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Status] $Message"
    [void]$global:LogEntries.Add($logEntry)

    switch ($Status) {
        "Applied" { $global:AppliedCount++ }
        "Skipped" { $global:SkippedCount++ }
        "Failed" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    if ($global:LogEntries.Count -gt 0) {
        $global:LogEntries | Out-File -FilePath $global:LogFilePath -Encoding UTF8
    }
}

function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$StepName,
        [string]$Description = ""
    )

    try {
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $currentValue = $null
        try {
            $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        } catch {
            $currentValue = $null
        }

        if (-not $global:ForceOverride -and $currentValue -eq $Value) {
            $displayDesc = if ($Description) { " - $Description" } else { "" }
            Write-Host "  - $StepName : 이미 적용됨 (스킵)$displayDesc" -ForegroundColor Gray
            Write-OptLog -Message "$StepName : 이미 적용됨 ($Name = $Value)" -Status "Skipped"
            return $false
        }

        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        $displayDesc = if ($Description) { " - $Description" } else { "" }
        Write-Host "  - $StepName : 적용됨$displayDesc" -ForegroundColor Green
        Write-OptLog -Message "$StepName : 적용됨 ($Name = $Value)" -Status "Applied"
        return $true
    } catch {
        Write-Host "  - $StepName : 실패 - $($_.Exception.Message)" -ForegroundColor Red
        Write-OptLog -Message "$StepName : 실패 - $($_.Exception.Message)" -Status "Failed"
        return $false
    }
}

#endregion 공통 함수

Write-Host "=== Windows 11 블로트웨어 제거 v$scriptVersion ===" -ForegroundColor Cyan
if ($global:ForceOverride) {
    Write-Host "[ForceOverride 모드: 모든 설정 강제 재적용]" -ForegroundColor Magenta
}
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
    "Microsoft.ScreenSketch"            # 캡쳐도구 (ShareX로 대체)
    "MicrosoftCorporationII.QuickAssist"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.OutlookForWindows"       # New Outlook
    "Microsoft.Copilot"                 # Windows Copilot
    "Microsoft.Windows.DevHome"
    "Microsoft.Windows.Photos"          # Windows 사진 앱 (Honeyview로 대체)
    "MicrosoftTeams"                    # Microsoft Teams (classic)
    "MSTeams"                           # Microsoft Teams (new)
    "MicrosoftCorporationII.MicrosoftTeams" # Microsoft Teams

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
    "LinkedIn"                          # LinkedIn (다른 패키지명)
    "7EE7776C.LinkedInforWindows"       # LinkedIn (전체 패키지명)
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
Write-Host "[1/5] 현재 사용자 블로트웨어 앱 제거 중..." -ForegroundColor Yellow

# 한 번의 호출로 모든 패키지 가져오기 (성능 최적화)
$allPackages = Get-AppxPackage -ErrorAction SilentlyContinue
$removedCount = 0
$skippedAppCount = 0

foreach ($app in $bloatwareApps) {
    $matched = $allPackages | Where-Object { $_.Name -like "*$app*" }
    if (-not $matched) {
        $skippedAppCount++
        continue
    }
    foreach ($package in $matched) {
        try {
            $package | Remove-AppxPackage -ErrorAction SilentlyContinue
            Write-Host "  - $($package.Name) 제거됨" -ForegroundColor Green
            Write-OptLog -Message "앱 제거: $($package.Name)" -Status "Applied"
            $removedCount++
        }
        catch {
            Write-Host "  - $($package.Name) 제거 실패" -ForegroundColor Red
            Write-OptLog -Message "앱 제거 실패: $($package.Name)" -Status "Failed"
        }
    }
}

if ($removedCount -eq 0) {
    Write-Host "  - 제거할 앱이 없습니다 (이미 제거됨)" -ForegroundColor Gray
    Write-OptLog -Message "현재 사용자 앱: 모두 이미 제거됨" -Status "Skipped"
} else {
    Write-Host "  - 총 $removedCount 개 앱 제거 완료" -ForegroundColor Green
}


# 2. 모든 사용자에서 앱 제거 (타임아웃 적용)
Write-Host ""
Write-Host "[2/5] 모든 사용자 블로트웨어 앱 제거 중..." -ForegroundColor Yellow

# 한 번의 호출로 모든 AllUsers 패키지 가져오기 (성능 최적화)
$allUsersPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
$allUsersRemoved = 0
$timeoutSeconds = 30

foreach ($app in $bloatwareApps) {
    $matched = $allUsersPackages | Where-Object { $_.Name -like "*$app*" }
    if (-not $matched) { continue }
    foreach ($package in $matched) {
        $pkgName = $package.Name
        try {
            # Start-Job으로 타임아웃 적용 (시스템 앱 무한 대기 방지)
            $job = Start-Job -ScriptBlock {
                param($pkg)
                $pkg | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            } -ArgumentList $package

            $completed = Wait-Job -Job $job -Timeout $timeoutSeconds

            if ($null -eq $completed) {
                # 타임아웃 발생
                Stop-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                Write-Host "  - $pkgName 제거 타임아웃 (스킵)" -ForegroundColor Yellow
                Write-OptLog -Message "앱 제거 타임아웃 (AllUsers): $pkgName" -Status "Skipped"
            } else {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                Write-Host "  - $pkgName 제거됨 (AllUsers)" -ForegroundColor Green
                Write-OptLog -Message "앱 제거 (AllUsers): $pkgName" -Status "Applied"
                $allUsersRemoved++
            }
        }
        catch {
            # 일부 앱은 AllUsers에서 제거 불가
        }
    }
}

if ($allUsersRemoved -gt 0) {
    Write-Host "  - 총 $allUsersRemoved 개 앱 (AllUsers) 제거 완료" -ForegroundColor Green
} else {
    Write-Host "  - 추가 제거할 앱 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "AllUsers 앱: 추가 제거 없음" -Status "Skipped"
}


# 3. 프로비저닝된 앱 제거 (새 사용자 계정에 설치 방지)
Write-Host ""
Write-Host "[3/5] 프로비저닝된 패키지 제거 중 (새 사용자 설치 방지)..." -ForegroundColor Yellow

$provisionedRemoved = 0
$provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

foreach ($app in $bloatwareApps) {
    $matched = $provisionedPackages | Where-Object { $_.PackageName -like "*$app*" }
    if (-not $matched) { continue }
    foreach ($pkg in $matched) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $pkg.PackageName -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  - $($pkg.DisplayName) 프로비저닝 제거됨" -ForegroundColor Green
            Write-OptLog -Message "프로비저닝 제거: $($pkg.DisplayName)" -Status "Applied"
            $provisionedRemoved++
        }
        catch {
            # 일부 패키지는 제거 불가
        }
    }
}

if ($provisionedRemoved -eq 0) {
    Write-Host "  - 프로비저닝된 블로트웨어 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "프로비저닝 패키지: 없음" -Status "Skipped"
} else {
    Write-Host "  - 총 $provisionedRemoved 개 프로비저닝 패키지 제거 완료" -ForegroundColor Green
}


# 4. Windows 선택적 기능 제거
Write-Host ""
Write-Host "[4/5] 불필요한 Windows 기능 제거 중..." -ForegroundColor Yellow

$features = @(
    "MathRecognizer"           # 수학 인식기
    "Microsoft.Windows.WordPad" # 워드패드
    "Printing-XPSServices-Features" # XPS 서비스
    "Internet-Explorer-Optional-amd64" # Internet Explorer (레거시)
)

$featureRemoved = 0
foreach ($feature in $features) {
    $capability = Get-WindowsCapability -Online | Where-Object { $_.Name -like "*$feature*" -and $_.State -eq "Installed" }
    if ($capability) {
        try {
            $capability | Remove-WindowsCapability -Online -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  - $($capability.Name) 기능 제거됨" -ForegroundColor Green
            Write-OptLog -Message "기능 제거: $($capability.Name)" -Status "Applied"
            $featureRemoved++
        }
        catch {
            Write-Host "  - $feature 기능 제거 실패" -ForegroundColor Red
            Write-OptLog -Message "기능 제거 실패: $feature" -Status "Failed"
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
            Write-OptLog -Message "기능 비활성화: $feature" -Status "Applied"
            $featureRemoved++
        }
        catch {
            # 일부 기능은 비활성화 불가
        }
    }
}

if ($featureRemoved -eq 0) {
    Write-Host "  - Windows 기능 이미 정리됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "Windows 기능: 이미 정리됨" -Status "Skipped"
} else {
    Write-Host "  - Windows 기능 정리 완료" -ForegroundColor Green
}


# 5. 시작 메뉴 고정 앱 제거
Write-Host ""
Write-Host "[5/5] 시작 메뉴 고정 앱 제거 중..." -ForegroundColor Yellow

# Windows 11 시작 메뉴 레이아웃 초기화 (고정 앱 제거)
$startMenuPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount"
$startMenuCleared = $false

# 시작 메뉴 캐시 제거
$startCachePaths = @(
    "$startMenuPath\`$`$windows.data.unifiedtile.startglobalproperties`$`$*",
    "$startMenuPath\`$`$windows.data.unifiedtile.pinnedtileiddata`$`$*"
)

foreach ($cachePath in $startCachePaths) {
    $items = Get-ChildItem -Path $cachePath -ErrorAction SilentlyContinue
    if ($items) {
        $items | ForEach-Object {
            Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        $startMenuCleared = $true
    }
}

if ($startMenuCleared) {
    Write-Host "  - 시작 메뉴 고정 앱 캐시 제거됨" -ForegroundColor Green
    Write-OptLog -Message "시작 메뉴 캐시 제거" -Status "Applied"
} else {
    Write-Host "  - 시작 메뉴 캐시 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "시작 메뉴 캐시: 없음" -Status "Skipped"
}

# start2.bin 파일 삭제 (시작 메뉴 레이아웃 초기화)
$start2BinPath = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
if (Test-Path $start2BinPath) {
    Remove-Item -Path $start2BinPath -Force -ErrorAction SilentlyContinue
    Write-Host "  - 시작 메뉴 레이아웃 초기화됨" -ForegroundColor Green
    Write-OptLog -Message "시작 메뉴 레이아웃 초기화" -Status "Applied"
} else {
    Write-Host "  - 시작 메뉴 레이아웃 파일 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "시작 메뉴 레이아웃: 파일 없음" -Status "Skipped"
}

# Explorer 재시작으로 시작 메뉴 변경사항 즉시 적용 (OrchestrateMode에서는 중앙 관리)
if (-not $global:OrchestrateMode) {
    Write-Host "  - Explorer 재시작 중..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer
    Write-Host "  - 시작 메뉴 변경사항 적용됨" -ForegroundColor Green
} else {
    Write-Host "  - Explorer 재시작 예약됨 (Orchestrate 종료 시)" -ForegroundColor Gray
}

# Microsoft Teams 관련 추가 정리
$teamsPath = "$env:LOCALAPPDATA\Microsoft\Teams"
$teamsProgramData = "$env:ProgramData\Microsoft\Teams"
$teamsCleared = $false

if (Test-Path $teamsPath) {
    Remove-Item -Path $teamsPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - Teams 로컬 데이터 제거됨" -ForegroundColor Green
    Write-OptLog -Message "Teams 로컬 데이터 제거" -Status "Applied"
    $teamsCleared = $true
}
if (Test-Path $teamsProgramData) {
    Remove-Item -Path $teamsProgramData -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - Teams ProgramData 제거됨" -ForegroundColor Green
    Write-OptLog -Message "Teams ProgramData 제거" -Status "Applied"
    $teamsCleared = $true
}

if (-not $teamsCleared) {
    Write-Host "  - Teams 데이터 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "Teams 데이터: 없음" -Status "Skipped"
}

# Teams 자동 시작 레지스트리 제거
$teamsAutoStart = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$teamsReg1 = Get-ItemProperty -Path $teamsAutoStart -Name "com.squirrel.Teams.Teams" -ErrorAction SilentlyContinue
$teamsReg2 = Get-ItemProperty -Path $teamsAutoStart -Name "Teams" -ErrorAction SilentlyContinue

if ($teamsReg1 -or $teamsReg2) {
    Remove-ItemProperty -Path $teamsAutoStart -Name "com.squirrel.Teams.Teams" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $teamsAutoStart -Name "Teams" -ErrorAction SilentlyContinue
    Write-Host "  - Teams 자동 시작 제거됨" -ForegroundColor Green
    Write-OptLog -Message "Teams 자동 시작 제거" -Status "Applied"
} else {
    Write-Host "  - Teams 자동 시작 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "Teams 자동 시작: 없음" -Status "Skipped"
}


# 로그 저장
Save-OptLog

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 블로트웨어 제거가 완료되었습니다!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $($global:AppliedCount) 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $($global:SkippedCount) 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $($global:FailedCount) 개" -ForegroundColor $(if($global:FailedCount -gt 0){"Red"}else{"Gray"})
Write-Host ""
Write-Host "로그 파일: $($global:LogFilePath)" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 항목:" -ForegroundColor Yellow
Write-Host "  - Microsoft 기본 앱 제거 (Cortana, Xbox, Teams, People 등)" -ForegroundColor White
Write-Host "  - 사전 설치된 제3자 앱 제거 (게임, SNS, LinkedIn 등)" -ForegroundColor White
Write-Host "  - 불필요한 Windows 기능 제거" -ForegroundColor White
Write-Host "  - 시작 메뉴 고정 앱 제거" -ForegroundColor White
Write-Host "  - 바탕화면 검은색으로 설정" -ForegroundColor White
Write-Host ""
Write-Host "참고: 일부 시스템 앱은 보호되어 제거되지 않습니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
