# Windows 11 고급 게임 최적화 스크립트
# Power Throttling, 시스템 타이머, 오디오 지연, Game Bar/DVR, DWM 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

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

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "022.advanced_gaming_optimization.ps1"

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_022_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir $logFileName
$global:LogEntries = [System.Collections.ArrayList]@()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Step,
        [string]$Status,
        [string]$Message,
        [string]$PreviousValue = "",
        [string]$NewValue = ""
    )

    $entry = [PSCustomObject]@{
        Timestamp = Get-Date -Format "HH:mm:ss"
        Step = $Step
        Status = $Status
        Message = $Message
        PreviousValue = $PreviousValue
        NewValue = $NewValue
    }

    [void]$global:LogEntries.Add($entry)

    switch ($Status) {
        "적용됨" { $global:AppliedCount++ }
        "스킵됨" { $global:SkippedCount++ }
        "실패" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $osVersion = "$($osInfo.Caption) (Build $($osInfo.BuildNumber))"

    $logContent = @"
================================================================================
Windows 11 Optimization Log
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
스크립트: $scriptName v$scriptVersion
OS: $osVersion
================================================================================

================================================================================
단계별 결과
================================================================================

"@

    foreach ($entry in $global:LogEntries) {
        $logContent += "[$($entry.Timestamp)] [$($entry.Step)]`n"
        $logContent += "  상태: $($entry.Status)`n"
        $logContent += "  내용: $($entry.Message)`n"
        if ($entry.PreviousValue) {
            $logContent += "  이전값: $($entry.PreviousValue)`n"
        }
        if ($entry.NewValue) {
            $logContent += "  새값: $($entry.NewValue)`n"
        }
        $logContent += "`n"
    }

    $logContent += @"
================================================================================
Summary
================================================================================
총 항목: $($global:AppliedCount + $global:SkippedCount + $global:FailedCount)
적용됨: $global:AppliedCount
스킵됨: $global:SkippedCount (이미 최적 설정)
실패: $global:FailedCount

로그 파일: $global:LogFilePath
================================================================================
"@

    $logContent | Set-Content -Path $global:LogFilePath -Encoding UTF8
}

# ===== 공통 함수 =====
function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$StepName,
        [string]$Description = ""
    )

    # 경로 생성
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    # 현재 값 확인
    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name

    if ($currentValue -eq $Value) {
        $msg = if ($Description) { "$Description : 이미 설정됨" } else { "$Name : 이미 설정됨" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "$Name 이미 최적값" -PreviousValue "$currentValue" -NewValue "$Value"
        return $false
    }

    # 값 설정
    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        $msg = if ($Description) { "$Description : $currentValue → $Value" } else { "$Name : $currentValue → $Value" }
        Write-Host "  - $msg (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "$Name 변경됨" -PreviousValue "$currentValue" -NewValue "$Value"
        return $true
    } catch {
        $msg = if ($Description) { "$Description : 설정 실패" } else { "$Name : 설정 실패" }
        Write-Host "  - $msg" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "$Name 설정 실패: $_"
        return $false
    }
}

function Set-ServiceIfDifferent {
    param(
        [string]$ServiceName,
        [string]$StartupType,
        [bool]$StopService = $false,
        [string]$StepName,
        [string]$Description = ""
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        $msg = if ($Description) { "$Description : 서비스 없음" } else { "$ServiceName : 서비스 없음" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "서비스 없음"
        return $false
    }

    $currentStartType = $service.StartType.ToString()

    if ($currentStartType -eq $StartupType) {
        $msg = if ($Description) { "$Description : 이미 $StartupType" } else { "$ServiceName : 이미 $StartupType" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 $StartupType" -PreviousValue $currentStartType
        return $false
    }

    try {
        if ($StopService -and $service.Status -eq "Running") {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        }

        Set-Service -Name $ServiceName -StartupType $StartupType
        $msg = if ($Description) { "$Description : $currentStartType → $StartupType" } else { "$ServiceName : $currentStartType → $StartupType" }
        Write-Host "  - $msg (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "변경됨" -PreviousValue $currentStartType -NewValue $StartupType
        return $true
    } catch {
        $msg = if ($Description) { "$Description : 설정 실패" } else { "$ServiceName : 설정 실패" }
        Write-Host "  - $msg" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "설정 실패: $_"
        return $false
    }
}

# ===== 메인 스크립트 시작 =====

Write-Host "=== Windows 11 고급 게임 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "Power Throttling, Game Bar/DVR, DWM, 오디오 등 게임 성능 최적화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 10


# [1/10] Power Throttling 비활성화
Write-Host "[1/$totalSteps] Power Throttling 비활성화 중..." -ForegroundColor Yellow

$powerStep = "Power Throttling"
$powerThrottlingPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
$powerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"

Set-RegistryIfDifferent -Path $powerThrottlingPath -Name "PowerThrottlingOff" -Value 1 -StepName $powerStep -Description "PowerThrottlingOff"
Set-RegistryIfDifferent -Path $powerPath -Name "EnergyEstimationEnabled" -Value 0 -StepName $powerStep -Description "EnergyEstimationEnabled"


# [2/10] 시스템 타이머 최적화
Write-Host ""
Write-Host "[2/$totalSteps] 시스템 타이머 최적화 중..." -ForegroundColor Yellow

$timerStep = "시스템 타이머"

try {
    # bcdedit 현재 값 확인
    $bcdOutput = bcdedit /enum "{current}" 2>&1

    # useplatformtick 확인 및 설정
    if ($bcdOutput -match "useplatformtick\s+Yes") {
        Write-Host "  - useplatformtick: 이미 설정됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $timerStep -Status "스킵됨" -Message "useplatformtick 이미 Yes"
    } else {
        $result1 = bcdedit /set useplatformtick yes 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  - useplatformtick: No → Yes (적용됨)" -ForegroundColor Green
            Write-OptLog -Step $timerStep -Status "적용됨" -Message "useplatformtick 설정됨" -NewValue "Yes"
        } else {
            Write-Host "  - useplatformtick 설정 실패" -ForegroundColor Red
            Write-OptLog -Step $timerStep -Status "실패" -Message "useplatformtick 설정 실패: $result1"
        }
    }

    # disabledynamictick 확인 및 설정
    if ($bcdOutput -match "disabledynamictick\s+Yes") {
        Write-Host "  - disabledynamictick: 이미 설정됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $timerStep -Status "스킵됨" -Message "disabledynamictick 이미 Yes"
    } else {
        $result2 = bcdedit /set disabledynamictick yes 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  - disabledynamictick: No → Yes (적용됨)" -ForegroundColor Green
            Write-OptLog -Step $timerStep -Status "적용됨" -Message "disabledynamictick 설정됨" -NewValue "Yes"
        } else {
            Write-Host "  - disabledynamictick 설정 실패" -ForegroundColor Red
            Write-OptLog -Step $timerStep -Status "실패" -Message "disabledynamictick 설정 실패: $result2"
        }
    }
} catch {
    Write-Host "  - bcdedit 명령 실행 실패: $_" -ForegroundColor Red
    Write-OptLog -Step $timerStep -Status "실패" -Message "bcdedit 실행 실패: $_"
}

# SystemResponsiveness
$multimediaPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-RegistryIfDifferent -Path $multimediaPath -Name "SystemResponsiveness" -Value 0 -StepName $timerStep -Description "SystemResponsiveness (100% 포그라운드)"


# [3/10] 오디오 지연 최소화
Write-Host ""
Write-Host "[3/$totalSteps] 오디오 지연 최소화 중..." -ForegroundColor Yellow

$audioStep = "오디오 최적화"
$audioPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio"
$audioServicePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"

Set-RegistryIfDifferent -Path $audioPath -Name "DisableProtectedAudioDG" -Value 1 -StepName $audioStep -Description "DisableProtectedAudioDG"
Set-RegistryIfDifferent -Path $audioServicePath -Name "Priority" -Value 1 -StepName $audioStep -Description "Audio Priority"
Set-RegistryIfDifferent -Path $audioServicePath -Name "Scheduling Category" -Value "High" -Type String -StepName $audioStep -Description "Audio Scheduling"
Set-RegistryIfDifferent -Path $audioServicePath -Name "SFIO Priority" -Value "High" -Type String -StepName $audioStep -Description "Audio SFIO Priority"


# [4/10] 네트워크 어댑터 고급 최적화
Write-Host ""
Write-Host "[4/$totalSteps] 네트워크 어댑터 고급 최적화 중..." -ForegroundColor Yellow

$networkStep = "네트워크 어댑터"
$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

if ($adapters.Count -gt 0) {
    foreach ($adapter in $adapters) {
        Write-Host "  - 어댑터: $($adapter.Name)" -ForegroundColor White

        # Interrupt Moderation
        try {
            $currentIM = (Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -ErrorAction SilentlyContinue).RegistryValue
            if ($currentIM -eq 0) {
                Write-Host "    - Interrupt Moderation: 이미 비활성화 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step $networkStep -Status "스킵됨" -Message "$($adapter.Name) Interrupt Moderation 이미 비활성화"
            } else {
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*InterruptModeration" -RegistryValue 0 -ErrorAction Stop
                Write-Host "    - Interrupt Moderation: 비활성화 (적용됨)" -ForegroundColor Green
                Write-OptLog -Step $networkStep -Status "적용됨" -Message "$($adapter.Name) Interrupt Moderation 비활성화"
            }
        } catch {
            Write-Host "    - Interrupt Moderation: 미지원 (스킵)" -ForegroundColor Gray
        }

        # Flow Control
        try {
            $currentFC = (Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*FlowControl" -ErrorAction SilentlyContinue).RegistryValue
            if ($currentFC -eq 0) {
                Write-Host "    - Flow Control: 이미 비활성화 (스킵)" -ForegroundColor Gray
                Write-OptLog -Step $networkStep -Status "스킵됨" -Message "$($adapter.Name) Flow Control 이미 비활성화"
            } else {
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*FlowControl" -RegistryValue 0 -ErrorAction Stop
                Write-Host "    - Flow Control: 비활성화 (적용됨)" -ForegroundColor Green
                Write-OptLog -Step $networkStep -Status "적용됨" -Message "$($adapter.Name) Flow Control 비활성화"
            }
        } catch {
            Write-Host "    - Flow Control: 미지원 (스킵)" -ForegroundColor Gray
        }

        # Energy Efficient Ethernet
        try {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword "*EEE" -RegistryValue 0 -ErrorAction SilentlyContinue
        } catch { }
    }
} else {
    Write-Host "  - 활성 물리적 네트워크 어댑터 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $networkStep -Status "스킵됨" -Message "활성 어댑터 없음"
}


# [5/10] Edge 백그라운드 완전 차단
Write-Host ""
Write-Host "[5/$totalSteps] Edge 백그라운드 완전 차단 중..." -ForegroundColor Yellow

$edgeStep = "Edge 백그라운드"
$edgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$edgeUpdatePath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"

Set-RegistryIfDifferent -Path $edgePolicyPath -Name "BackgroundModeEnabled" -Value 0 -StepName $edgeStep -Description "BackgroundModeEnabled"
Set-RegistryIfDifferent -Path $edgePolicyPath -Name "StartupBoostEnabled" -Value 0 -StepName $edgeStep -Description "StartupBoostEnabled"
Set-RegistryIfDifferent -Path $edgePolicyPath -Name "AllowPrelaunch" -Value 0 -StepName $edgeStep -Description "AllowPrelaunch"
Set-RegistryIfDifferent -Path $edgePolicyPath -Name "ComponentUpdatesEnabled" -Value 0 -StepName $edgeStep -Description "ComponentUpdatesEnabled"
Set-RegistryIfDifferent -Path $edgeUpdatePath -Name "UpdateDefault" -Value 0 -StepName $edgeStep -Description "Edge UpdateDefault"

# Edge 시작 프로그램 제거
$runPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$edgeAutoLaunch = Get-ItemProperty -Path $runPath -ErrorAction SilentlyContinue |
                  Get-Member -MemberType NoteProperty |
                  Where-Object { $_.Name -match "MicrosoftEdgeAutoLaunch" }

if ($edgeAutoLaunch) {
    foreach ($entry in $edgeAutoLaunch) {
        Remove-ItemProperty -Path $runPath -Name $entry.Name -ErrorAction SilentlyContinue
        Write-Host "  - 시작 프로그램 제거: $($entry.Name) (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $edgeStep -Status "적용됨" -Message "시작 프로그램 제거: $($entry.Name)"
    }
}


# [6/10] Print Spooler 설정 (선택)
Write-Host ""
Write-Host "[6/$totalSteps] Print Spooler 설정 중..." -ForegroundColor Yellow

$spoolerStep = "Print Spooler"
$disableSpooler = "N"

if (-not $global:OrchestrateMode) {
    Write-Host "  프린터 미사용 시 Print Spooler 비활성화 가능 (보안/리소스 절약)" -ForegroundColor Cyan
    $disableSpooler = Read-Host "  Print Spooler 비활성화 (Y/N, 기본값: N)"
}

if ($disableSpooler -eq "Y" -or $disableSpooler -eq "y") {
    Set-ServiceIfDifferent -ServiceName "Spooler" -StartupType "Disabled" -StopService $true -StepName $spoolerStep -Description "Print Spooler"
} else {
    Write-Host "  - Print Spooler: 기본값 유지 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $spoolerStep -Status "스킵됨" -Message "사용자 선택으로 유지"
}


# [7/10] 25H2 Start Menu 최적화
Write-Host ""
Write-Host "[7/$totalSteps] 25H2 Start Menu 최적화 중..." -ForegroundColor Yellow

$startMenuStep = "Start Menu"
$explorerAdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

Set-RegistryIfDifferent -Path $explorerAdvancedPath -Name "Start_IrisRecommendations" -Value 0 -StepName $startMenuStep -Description "Start_IrisRecommendations (추천 비활성화)"
Set-RegistryIfDifferent -Path $explorerAdvancedPath -Name "Start_AccountNotifications" -Value 0 -StepName $startMenuStep -Description "Start_AccountNotifications (계정 알림 비활성화)"


# [8/10] Chrome 성능 최적화
Write-Host ""
Write-Host "[8/$totalSteps] Chrome 성능 최적화 중..." -ForegroundColor Yellow

$chromeStep = "Chrome 최적화"
$chromePolicyPath = "HKLM:\SOFTWARE\Policies\Google\Chrome"

Set-RegistryIfDifferent -Path $chromePolicyPath -Name "BackgroundModeEnabled" -Value 0 -StepName $chromeStep -Description "Chrome BackgroundModeEnabled"
Set-RegistryIfDifferent -Path $chromePolicyPath -Name "HardwareAccelerationModeEnabled" -Value 1 -StepName $chromeStep -Description "Chrome HardwareAccelerationModeEnabled"
Set-RegistryIfDifferent -Path $chromePolicyPath -Name "HighEfficiencyModeEnabled" -Value 1 -StepName $chromeStep -Description "Chrome HighEfficiencyModeEnabled"


# [9/10] Game Bar/DVR 완전 비활성화
Write-Host ""
Write-Host "[9/$totalSteps] Game Bar/DVR 완전 비활성화 중..." -ForegroundColor Yellow

$gameBarStep = "Game Bar/DVR"

# Game Bar 사용자 설정
$gameBarPath = "HKCU:\Software\Microsoft\GameBar"
Set-RegistryIfDifferent -Path $gameBarPath -Name "AllowAutoGameMode" -Value 0 -StepName $gameBarStep -Description "AllowAutoGameMode"
Set-RegistryIfDifferent -Path $gameBarPath -Name "AutoGameModeEnabled" -Value 0 -StepName $gameBarStep -Description "AutoGameModeEnabled"
Set-RegistryIfDifferent -Path $gameBarPath -Name "ShowStartupPanel" -Value 0 -StepName $gameBarStep -Description "ShowStartupPanel"
Set-RegistryIfDifferent -Path $gameBarPath -Name "GamePanelStartupTipIndex" -Value 3 -StepName $gameBarStep -Description "GamePanelStartupTipIndex"
Set-RegistryIfDifferent -Path $gameBarPath -Name "UseNexusForGameBarEnabled" -Value 0 -StepName $gameBarStep -Description "UseNexusForGameBarEnabled"

# Game DVR 정책 (시스템 전체)
$gameDVRPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
Set-RegistryIfDifferent -Path $gameDVRPolicyPath -Name "AllowGameDVR" -Value 0 -StepName $gameBarStep -Description "AllowGameDVR (정책)"

# Game DVR 사용자 설정
$gameConfigPath = "HKCU:\System\GameConfigStore"
if (!(Test-Path $gameConfigPath)) {
    New-Item -Path $gameConfigPath -Force | Out-Null
}
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_Enabled" -Value 0 -StepName $gameBarStep -Description "GameDVR_Enabled"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_FSEBehavior" -Value 2 -StepName $gameBarStep -Description "GameDVR_FSEBehavior (전체화면 최적화 비활성화)"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -StepName $gameBarStep -Description "GameDVR_FSEBehaviorMode"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -StepName $gameBarStep -Description "GameDVR_HonorUserFSEBehaviorMode"
Set-RegistryIfDifferent -Path $gameConfigPath -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -StepName $gameBarStep -Description "GameDVR_DXGIHonorFSEWindowsCompatible"

# Xbox 앱 캡처 비활성화
$xboxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
Set-RegistryIfDifferent -Path $xboxPath -Name "AppCaptureEnabled" -Value 0 -StepName $gameBarStep -Description "AppCaptureEnabled"

# Games 작업 GPU 우선순위
$gamesTaskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
Set-RegistryIfDifferent -Path $gamesTaskPath -Name "GPU Priority" -Value 8 -StepName $gameBarStep -Description "Games GPU Priority (8=High)"
Set-RegistryIfDifferent -Path $gamesTaskPath -Name "Priority" -Value 6 -StepName $gameBarStep -Description "Games Priority (6=High)"
Set-RegistryIfDifferent -Path $gamesTaskPath -Name "Scheduling Category" -Value "High" -Type String -StepName $gameBarStep -Description "Games Scheduling Category"
Set-RegistryIfDifferent -Path $gamesTaskPath -Name "SFIO Priority" -Value "High" -Type String -StepName $gameBarStep -Description "Games SFIO Priority"


# [10/10] DWM (Desktop Window Manager) 최적화
Write-Host ""
Write-Host "[10/$totalSteps] DWM 최적화 중..." -ForegroundColor Yellow

$dwmStep = "DWM 최적화"
$dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"

# OverlayTestMode: 5 = DWM 버퍼링 최소화
Set-RegistryIfDifferent -Path $dwmPath -Name "OverlayTestMode" -Value 5 -StepName $dwmStep -Description "OverlayTestMode (버퍼링 최소화)"

# 시스템 DWM 설정 (선택적)
$dwmSystemPath = "HKLM:\SOFTWARE\Microsoft\Windows\DWM"
if (Test-Path $dwmSystemPath) {
    Set-RegistryIfDifferent -Path $dwmSystemPath -Name "OverlayTestMode" -Value 5 -StepName $dwmStep -Description "System OverlayTestMode"
}


# ===== 로그 저장 =====
Save-OptLog


# ===== 완료 메시지 =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "고급 게임 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount 개" -ForegroundColor $(if ($global:FailedCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "주요 적용 항목:" -ForegroundColor Yellow
Write-Host "  - Power Throttling: 비활성화" -ForegroundColor White
Write-Host "  - 시스템 타이머: 최적화 (일관된 프레임 타이밍)" -ForegroundColor White
Write-Host "  - Game Bar/DVR: 완전 비활성화" -ForegroundColor White
Write-Host "  - 전체화면 최적화: 비활성화 (입력 지연 감소)" -ForegroundColor White
Write-Host "  - DWM: 버퍼링 최소화 (창 모드 지연 감소)" -ForegroundColor White
Write-Host "  - Games 작업: GPU/CPU 우선순위 High" -ForegroundColor White
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor Cyan
Write-Host ""
Write-Host "재부팅 후 모든 설정이 적용됩니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인
if (-not $global:OrchestrateMode) {
    $restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        Write-Host "10초 후 재부팅됩니다..." -ForegroundColor Red
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        Write-Host "나중에 수동으로 재부팅해주세요." -ForegroundColor Yellow
    }
}
