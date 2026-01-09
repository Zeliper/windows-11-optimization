# Windows 11 마우스/입력 장치 최적화 스크립트
# 마우스 가속도 비활성화, 키보드 반복 속도 최적화, 입력 지연 최소화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "017.mouse_input_optimization.ps1"

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
    Name = "마우스/입력 장치 최적화"
    Description = "마우스 가속 비활성화, 키보드 속도 최적화, 입력 지연 최소화"
    RequiresReboot = $false
}

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_017_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
    $logContent = "================================================================================`nWindows 11 Optimization Log - Mouse/Input Optimization`n================================================================================`n실행 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n스크립트: $scriptName v$scriptVersion`n================================================================================`n`n단계별 결과`n================================================================================`n`n"
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

Write-Host "=== Windows 11 마우스/입력 장치 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "마우스 가속 비활성화, 키보드 속도 최적화, 입력 지연 최소화를 수행합니다." -ForegroundColor White
Write-Host "게이머 및 정밀 작업 사용자에게 권장됩니다." -ForegroundColor White
Write-Host ""

$totalSteps = 6


# [1/6] 마우스 가속도 비활성화
Write-Host "[1/$totalSteps] 마우스 가속도 비활성화 중..." -ForegroundColor Yellow

$stepName = "1. 마우스 가속"
$mousePath = "HKCU:\Control Panel\Mouse"

Set-RegistryIfDifferent -Path $mousePath -Name "MouseSpeed" -Value "0" -Type "String" -StepName $stepName -Description "MouseSpeed (가속 곡선)"
Set-RegistryIfDifferent -Path $mousePath -Name "MouseThreshold1" -Value "0" -Type "String" -StepName $stepName -Description "MouseThreshold1 (임계값 1)"
Set-RegistryIfDifferent -Path $mousePath -Name "MouseThreshold2" -Value "0" -Type "String" -StepName $stepName -Description "MouseThreshold2 (임계값 2)"


# [2/6] 마우스 포인터 정확도 향상 (Enhance Pointer Precision 비활성화)
Write-Host ""
Write-Host "[2/$totalSteps] 마우스 포인터 정확도 향상 설정 중..." -ForegroundColor Yellow

$stepName = "2. 포인터 정확도"
Set-RegistryIfDifferent -Path $mousePath -Name "MouseSensitivity" -Value "10" -Type "String" -StepName $stepName -Description "MouseSensitivity (1:1 매핑)"

# SmoothMouseXCurve / SmoothMouseYCurve - 선형 곡선으로 설정 (가속 없음)
$linearXCurve = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                          0xC0,0xCC,0x0C,0x00,0x00,0x00,0x00,0x00,
                          0x80,0x99,0x19,0x00,0x00,0x00,0x00,0x00,
                          0x40,0x66,0x26,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x33,0x33,0x00,0x00,0x00,0x00,0x00)
$linearYCurve = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x00,0x38,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x00,0x70,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x00,0xA8,0x00,0x00,0x00,0x00,0x00,
                          0x00,0x00,0xE0,0x00,0x00,0x00,0x00,0x00)

# Binary 값은 비교가 복잡하므로 항상 적용
$currentXCurve = (Get-ItemProperty -Path $mousePath -Name "SmoothMouseXCurve" -ErrorAction SilentlyContinue).SmoothMouseXCurve
if ($null -eq $currentXCurve -or (Compare-Object $currentXCurve $linearXCurve)) {
    Set-ItemProperty -Path $mousePath -Name "SmoothMouseXCurve" -Value $linearXCurve -Type Binary
    Set-ItemProperty -Path $mousePath -Name "SmoothMouseYCurve" -Value $linearYCurve -Type Binary
    Write-Host "  - SmoothMouseXCurve/YCurve : 선형 곡선 적용 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $stepName -Status "적용됨" -Message "SmoothMouseXCurve/YCurve 선형 곡선 적용"
} else {
    Write-Host "  - SmoothMouseXCurve/YCurve : 이미 설정됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $stepName -Status "스킵됨" -Message "SmoothMouseXCurve/YCurve 이미 선형 곡선"
}


# [3/6] 키보드 반복 속도 최적화
Write-Host ""
Write-Host "[3/$totalSteps] 키보드 반복 속도 최적화 중..." -ForegroundColor Yellow

$stepName = "3. 키보드 속도"
$keyboardPath = "HKCU:\Control Panel\Keyboard"

Set-RegistryIfDifferent -Path $keyboardPath -Name "KeyboardDelay" -Value "0" -Type "String" -StepName $stepName -Description "KeyboardDelay (최소 지연)"
Set-RegistryIfDifferent -Path $keyboardPath -Name "KeyboardSpeed" -Value "31" -Type "String" -StepName $stepName -Description "KeyboardSpeed (최대 속도)"


# [4/6] 입력 지연 최소화
Write-Host ""
Write-Host "[4/$totalSteps] 입력 지연 최소화 설정 중..." -ForegroundColor Yellow

$stepName = "4. 입력 지연"
$mouseclassPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters"
Set-RegistryIfDifferent -Path $mouseclassPath -Name "MouseDataQueueSize" -Value 100 -StepName $stepName -Description "MouseDataQueueSize (데이터 큐)"

$kbdclassPath = "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters"
Set-RegistryIfDifferent -Path $kbdclassPath -Name "KeyboardDataQueueSize" -Value 100 -StepName $stepName -Description "KeyboardDataQueueSize (데이터 큐)"


# [5/6] 게임용 입력 우선순위 설정
Write-Host ""
Write-Host "[5/$totalSteps] 게임용 입력 우선순위 설정 중..." -ForegroundColor Yellow

$stepName = "5. 입력 우선순위"
$mmcssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-RegistryIfDifferent -Path $mmcssPath -Name "SystemResponsiveness" -Value 0 -StepName $stepName -Description "SystemResponsiveness (게임/입력 우선)"

$frameServerPath = "HKLM:\SOFTWARE\Microsoft\Windows Media Foundation\Platform"
Set-RegistryIfDifferent -Path $frameServerPath -Name "EnableFrameServerMode" -Value 0 -StepName $stepName -Description "FrameServerMode (입력 지연 감소)"

$frameServerPathWow64 = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Media Foundation\Platform"
Set-RegistryIfDifferent -Path $frameServerPathWow64 -Name "EnableFrameServerMode" -Value 0 -StepName $stepName -Description "FrameServerMode WOW64 (32비트)"


# [6/6] 터치패드 응답성 최적화 (노트북용)
Write-Host ""
Write-Host "[6/$totalSteps] 터치패드 응답성 최적화 중 (노트북용)..." -ForegroundColor Yellow

$stepName = "6. 터치패드"

# Precision Touchpad 설정 (Windows 11)
$touchpadPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad"
if (Test-Path $touchpadPath) {
    Set-RegistryIfDifferent -Path $touchpadPath -Name "AAPThreshold" -Value 0 -StepName $stepName -Description "PrecisionTouchPad 감도"
} else {
    Write-Host "  - PrecisionTouchPad : 감지되지 않음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $stepName -Status "스킵됨" -Message "PrecisionTouchPad 레지스트리 경로 없음"
}

# Synaptics 터치패드 (레거시)
$synapticsPath = "HKCU:\Software\Synaptics\SynTP\TouchPadPS2"
if (Test-Path $synapticsPath) {
    Set-RegistryIfDifferent -Path $synapticsPath -Name "PalmDetectConfig" -Value 0 -StepName $stepName -Description "Synaptics 손바닥 감지"
} else {
    Write-Host "  - Synaptics 터치패드 : 감지되지 않음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $stepName -Status "스킵됨" -Message "Synaptics 레지스트리 경로 없음"
}


# 로그 저장
Save-OptLog

# Summary 출력
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "마우스/입력 장치 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $($global:AppliedCount) 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $($global:SkippedCount) 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $($global:FailedCount) 개" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $($global:LogFilePath)" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 마우스 가속도 완전 비활성화" -ForegroundColor White
Write-Host "  - 마우스 포인터 1:1 매핑 (선형 곡선)" -ForegroundColor White
Write-Host "  - 키보드 반복 속도 최대화" -ForegroundColor White
Write-Host "  - 입력 데이터 큐 크기 증가" -ForegroundColor White
Write-Host "  - 프레임 서버 모드 비활성화" -ForegroundColor White
Write-Host "  - 터치패드 응답성 최적화 (해당 시)" -ForegroundColor White
Write-Host ""
Write-Host "로그오프 후 다시 로그인하면 모든 설정이 적용됩니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인 (이 스크립트는 재부팅 불필요, 로그오프/로그인으로 충분)
if (-not $global:OrchestrateMode) {
    Write-Host "참고: 이 스크립트는 재부팅이 필요하지 않습니다." -ForegroundColor Gray
    Write-Host "로그오프 후 다시 로그인하면 모든 설정이 적용됩니다." -ForegroundColor Gray
}
