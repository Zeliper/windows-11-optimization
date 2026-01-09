# Windows 11 25H2 접근성 기능 정리 스크립트
# 불필요한 접근성 단축키 팝업 방지 및 자동 시작 기능 비활성화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "016.accessibility_cleanup.ps1"

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

# Orchestrate 모드용 메타데이터
$script:ScriptMetadata = @{
    Name = "접근성 기능 정리"
    Description = "고정 키, 토글 키, 필터 키, 마우스 키 비활성화 및 접근성 자동 시작 기능 비활성화"
    RequiresReboot = $false
}

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_016_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir $logFileName
$global:LogEntries = [System.Collections.ArrayList]@()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param([string]$Step, [string]$Status, [string]$Message, [string]$PreviousValue = "", [string]$NewValue = "")
    $entry = [PSCustomObject]@{ Timestamp = Get-Date -Format "HH:mm:ss"; Step = $Step; Status = $Status; Message = $Message; PreviousValue = $PreviousValue; NewValue = $NewValue }
    [void]$global:LogEntries.Add($entry)
    switch ($Status) { "적용됨" { $global:AppliedCount++ } "스킵됨" { $global:SkippedCount++ } "실패" { $global:FailedCount++ } }
}

function Save-OptLog {
    $logContent = "================================================================================`nWindows 11 Optimization Log - Accessibility Cleanup`n================================================================================`n실행 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n스크립트: $scriptName v$scriptVersion`n================================================================================`n`n단계별 결과`n================================================================================`n`n"
    foreach ($entry in $global:LogEntries) {
        $logContent += "[$($entry.Timestamp)] [$($entry.Step)]`n  상태: $($entry.Status)`n  내용: $($entry.Message)`n"
        if ($entry.PreviousValue) { $logContent += "  이전값: $($entry.PreviousValue)`n" }
        if ($entry.NewValue) { $logContent += "  새값: $($entry.NewValue)`n" }
        $logContent += "`n"
    }
    $logContent += "================================================================================`nSummary`n================================================================================`n총 항목: $($global:AppliedCount + $global:SkippedCount + $global:FailedCount)`n적용됨: $global:AppliedCount`n스킵됨: $global:SkippedCount (이미 최적 설정)`n실패: $global:FailedCount`n`n로그 파일: $global:LogFilePath`n================================================================================"
    $logContent | Set-Content -Path $global:LogFilePath -Encoding UTF8
}

function Set-RegistryIfDifferent {
    param([string]$Path, [string]$Name, [object]$Value, [string]$Type = "DWord", [string]$StepName, [string]$Description = "")
    if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($currentValue -eq $Value) {
        $msg = if ($Description) { "$Description : 이미 설정됨" } else { "$Name : 이미 설정됨" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "$Name 이미 최적값" -PreviousValue "$currentValue" -NewValue "$Value"
        return $false
    }
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

# ===== 메인 스크립트 시작 =====

Write-Host "=== Windows 11 25H2 접근성 기능 정리 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "불필요한 접근성 단축키 팝업 방지 및 자동 시작 기능을 비활성화합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 8


# [1/8] 고정 키 비활성화 (Shift 5회 연타 팝업 방지)
Write-Host "[1/$totalSteps] 고정 키 비활성화 중..." -ForegroundColor Yellow

$stepName = "1. 고정 키"
Set-RegistryIfDifferent -Path "HKCU:\Control Panel\Accessibility\StickyKeys" -Name "Flags" -Value "506" -Type "String" -StepName $stepName -Description "고정 키 (Shift 5회 팝업)"


# [2/8] 토글 키 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] 토글 키 비활성화 중..." -ForegroundColor Yellow

$stepName = "2. 토글 키"
Set-RegistryIfDifferent -Path "HKCU:\Control Panel\Accessibility\ToggleKeys" -Name "Flags" -Value "58" -Type "String" -StepName $stepName -Description "토글 키 (NumLock 5초 팝업)"


# [3/8] 필터 키 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] 필터 키 비활성화 중..." -ForegroundColor Yellow

$stepName = "3. 필터 키"
Set-RegistryIfDifferent -Path "HKCU:\Control Panel\Accessibility\Keyboard Response" -Name "Flags" -Value "122" -Type "String" -StepName $stepName -Description "필터 키 (Shift 8초 팝업)"


# [4/8] 마우스 키 비활성화
Write-Host ""
Write-Host "[4/$totalSteps] 마우스 키 비활성화 중..." -ForegroundColor Yellow

$stepName = "4. 마우스 키"
Set-RegistryIfDifferent -Path "HKCU:\Control Panel\Accessibility\MouseKeys" -Name "Flags" -Value "58" -Type "String" -StepName $stepName -Description "마우스 키 (Alt+Shift+NumLock)"


# [5/8] 돋보기 자동 시작 비활성화
Write-Host ""
Write-Host "[5/$totalSteps] 돋보기 자동 시작 비활성화 중..." -ForegroundColor Yellow

$stepName = "5. 돋보기"
$magnifierPath = "HKCU:\Software\Microsoft\ScreenMagnifier"
Set-RegistryIfDifferent -Path $magnifierPath -Name "FollowCaret" -Value 0 -StepName $stepName -Description "돋보기 커서 추적"
Set-RegistryIfDifferent -Path $magnifierPath -Name "FollowNarrator" -Value 0 -StepName $stepName -Description "돋보기 내레이터 추적"
Set-RegistryIfDifferent -Path $magnifierPath -Name "FollowMouse" -Value 0 -StepName $stepName -Description "돋보기 마우스 추적"
Set-RegistryIfDifferent -Path $magnifierPath -Name "FollowFocus" -Value 0 -StepName $stepName -Description "돋보기 포커스 추적"

# Configuration 값에서 magnifierpane 제거 (ATconfig에서 자동 시작 비활성화)
$accessibilityPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility"
if (!(Test-Path $accessibilityPath)) { New-Item -Path $accessibilityPath -Force | Out-Null }
$atConfig = Get-ItemProperty -Path $accessibilityPath -Name "Configuration" -ErrorAction SilentlyContinue
if ($atConfig -and $atConfig.Configuration -and $atConfig.Configuration -like "*magnifierpane*") {
    $newConfig = $atConfig.Configuration -replace "magnifierpane", ""
    $newConfig = $newConfig -replace ";;", ";"
    $newConfig = $newConfig.Trim(";")
    Set-ItemProperty -Path $accessibilityPath -Name "Configuration" -Value $newConfig -ErrorAction SilentlyContinue
    Write-Host "  - 돋보기 자동 시작 (Configuration) : 제거됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $stepName -Status "적용됨" -Message "Configuration에서 magnifierpane 제거"
} else {
    Write-Host "  - 돋보기 자동 시작 (Configuration) : 이미 설정됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $stepName -Status "스킵됨" -Message "Configuration에 magnifierpane 없음"
}


# [6/8] 내레이터 자동 시작 비활성화
Write-Host ""
Write-Host "[6/$totalSteps] 내레이터 자동 시작 비활성화 중..." -ForegroundColor Yellow

$stepName = "6. 내레이터"
$narratorPath = "HKCU:\Software\Microsoft\Narrator"
Set-RegistryIfDifferent -Path $narratorPath -Name "NarratorCursorHighlight" -Value 0 -StepName $stepName -Description "내레이터 커서 하이라이트"
Set-RegistryIfDifferent -Path $narratorPath -Name "IntonationPause" -Value 0 -StepName $stepName -Description "내레이터 억양 일시정지"
Set-RegistryIfDifferent -Path $narratorPath -Name "ReadingWithIntent" -Value 0 -StepName $stepName -Description "내레이터 의도 읽기"
Set-RegistryIfDifferent -Path $narratorPath -Name "WinEnterLaunchEnabled" -Value 0 -StepName $stepName -Description "Win+Enter 내레이터 시작"

$narratorNoRoamPath = "HKCU:\Software\Microsoft\Narrator\NoRoam"
Set-RegistryIfDifferent -Path $narratorNoRoamPath -Name "RunNarratorOnLogon" -Value 0 -StepName $stepName -Description "로그온 시 내레이터 시작"
Set-RegistryIfDifferent -Path $narratorNoRoamPath -Name "DuckAudio" -Value 0 -StepName $stepName -Description "내레이터 오디오 덕킹"
Set-RegistryIfDifferent -Path $narratorNoRoamPath -Name "WinEnterLaunchEnabled" -Value 0 -StepName $stepName -Description "Win+Enter (NoRoam)"

# Configuration에서 narrator 제거
$atConfig = Get-ItemProperty -Path $accessibilityPath -Name "Configuration" -ErrorAction SilentlyContinue
if ($atConfig -and $atConfig.Configuration -and $atConfig.Configuration -like "*narrator*") {
    $newConfig = $atConfig.Configuration -replace "narrator", ""
    $newConfig = $newConfig -replace ";;", ";"
    $newConfig = $newConfig.Trim(";")
    Set-ItemProperty -Path $accessibilityPath -Name "Configuration" -Value $newConfig -ErrorAction SilentlyContinue
    Write-Host "  - 내레이터 자동 시작 (Configuration) : 제거됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $stepName -Status "적용됨" -Message "Configuration에서 narrator 제거"
} else {
    Write-Host "  - 내레이터 자동 시작 (Configuration) : 이미 설정됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $stepName -Status "스킵됨" -Message "Configuration에 narrator 없음"
}


# [7/8] 화면 키보드 자동 시작 비활성화
Write-Host ""
Write-Host "[7/$totalSteps] 화면 키보드 자동 시작 비활성화 중..." -ForegroundColor Yellow

$stepName = "7. 화면 키보드"

# Configuration에서 osk 제거
$atConfig = Get-ItemProperty -Path $accessibilityPath -Name "Configuration" -ErrorAction SilentlyContinue
if ($atConfig -and $atConfig.Configuration -and $atConfig.Configuration -like "*osk*") {
    $newConfig = $atConfig.Configuration -replace "osk", ""
    $newConfig = $newConfig -replace ";;", ";"
    $newConfig = $newConfig.Trim(";")
    Set-ItemProperty -Path $accessibilityPath -Name "Configuration" -Value $newConfig -ErrorAction SilentlyContinue
    Write-Host "  - 화면 키보드 자동 시작 (Configuration) : 제거됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $stepName -Status "적용됨" -Message "Configuration에서 osk 제거"
} else {
    Write-Host "  - 화면 키보드 자동 시작 (Configuration) : 이미 설정됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $stepName -Status "스킵됨" -Message "Configuration에 osk 없음"
}

# 터치 키보드 자동 호출 비활성화
$tabTipPath = "HKCU:\Software\Microsoft\TabletTip\1.7"
Set-RegistryIfDifferent -Path $tabTipPath -Name "EnableDesktopModeAutoInvoke" -Value 0 -StepName $stepName -Description "터치 키보드 자동 호출"
Set-RegistryIfDifferent -Path $tabTipPath -Name "TipbandDesiredVisibility" -Value 0 -StepName $stepName -Description "터치 키보드 가시성"


# [8/8] 고대비 테마 바로가기 비활성화
Write-Host ""
Write-Host "[8/$totalSteps] 고대비 테마 바로가기 비활성화 중..." -ForegroundColor Yellow

$stepName = "8. 고대비"
Set-RegistryIfDifferent -Path "HKCU:\Control Panel\Accessibility\HighContrast" -Name "Flags" -Value "4194" -Type "String" -StepName $stepName -Description "고대비 (Alt+Shift+PrintScreen)"


# 로그 저장
Save-OptLog

# Summary 출력
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "접근성 기능 정리가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $($global:AppliedCount) 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $($global:SkippedCount) 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $($global:FailedCount) 개" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $($global:LogFilePath)" -ForegroundColor Cyan
Write-Host ""
Write-Host "비활성화된 설정:" -ForegroundColor Yellow
Write-Host "  - 고정 키 (Shift 5회 연타 팝업 방지)" -ForegroundColor White
Write-Host "  - 토글 키 (NumLock 5초 누름 팝업 방지)" -ForegroundColor White
Write-Host "  - 필터 키 (오른쪽 Shift 8초 팝업 방지)" -ForegroundColor White
Write-Host "  - 마우스 키 (Alt+Shift+NumLock 방지)" -ForegroundColor White
Write-Host "  - 돋보기 자동 시작" -ForegroundColor White
Write-Host "  - 내레이터 자동 시작" -ForegroundColor White
Write-Host "  - 화면 키보드 자동 시작" -ForegroundColor White
Write-Host "  - 고대비 테마 바로가기 (Alt+Shift+PrintScreen)" -ForegroundColor White
Write-Host ""
Write-Host "모든 설정이 즉시 적용되었습니다." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
