# Core shared module for Windows 11 Optimization Scripts
# Provides logging, helper functions, and the main execution engine

#Requires -RunAsAdministrator

# ===== Initialization & Global State =====

if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

# UTF-8 Encoding for Korean output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$ProgressPreference = 'SilentlyContinue'

# ===== Logging System =====

function Init-OptimizationLog {
    param(
        [string]$ScriptName,
        [string]$ScriptVersion
    )

    $global:CurrentScriptName = $ScriptName
    $global:CurrentScriptVersion = $ScriptVersion
    
    # Define log directory
    $logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    
    # Define log file path
    $dateStr = Get-Date -Format 'yyyyMMdd_HHmmss'
    $safeName = $ScriptName -replace '\.ps1$', ''
    $global:LogFilePath = Join-Path $logDir "Windows11Optimizer_${safeName}_${dateStr}.log"
    
    $global:LogEntries = [System.Collections.ArrayList]@()
    $global:AppliedCount = 0
    $global:SkippedCount = 0
    $global:FailedCount = 0
}

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
    if (-not $global:LogFilePath) { return }

    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osVersion = if ($osInfo) { "$($osInfo.Caption) (Build $($osInfo.BuildNumber))" } else { "Unknown" }

    $logContent = @"
================================================================================
Windows 11 Optimization Log
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
스크립트: $global:CurrentScriptName v$global:CurrentScriptVersion
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

# ===== Helper Functions =====

function Set-Registry {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$Description = "" # Optional override for log message
    )
    
    # Determine step name from current scope if possible, or default
    $stepName = if ($global:CurrentStepName) { $global:CurrentStepName } else { "Registry" }
    $dispName = if ($Description) { $Description } else { "$Name" }

    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name

    if (-not $global:ForceOverride -and $currentValue -eq $Value) {
        Write-Host "  - $dispName : 이미 설정됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $stepName -Status "스킵됨" -Message "$dispName 이미 최적값" -PreviousValue "$currentValue" -NewValue "$Value"
        return
    }

    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        $prevDisplay = if ($null -eq $currentValue) { "(없음)" } else { $currentValue }
        Write-Host "  - $dispName : $prevDisplay → $Value (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $stepName -Status "적용됨" -Message "$dispName 변경됨" -PreviousValue "$prevDisplay" -NewValue "$Value"
    } catch {
        Write-Host "  - $dispName : 설정 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step $stepName -Status "실패" -Message "$dispName 설정 실패: $_"
    }
}

function Set-Service {
    param(
        [string]$Name,
        [string]$StartupType,
        [bool]$Stop = $false,
        [string]$Description = ""
    )

    $stepName = if ($global:CurrentStepName) { $global:CurrentStepName } else { "Service" }
    $dispName = if ($Description) { $Description } else { "$Name" }

    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Host "  - $dispName : 서비스 없음 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $stepName -Status "스킵됨" -Message "서비스 없음"
        return
    }

    $currentStartType = $service.StartType.ToString()

    if (-not $global:ForceOverride -and $currentStartType -eq $StartupType) {
        # If stopping is requested but service is running, we might still need to act
        if ($Stop -and $service.Status -eq "Running") {
            # Need to stop
        } else {
            Write-Host "  - $dispName : 이미 $StartupType (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $stepName -Status "스킵됨" -Message "이미 $StartupType" -PreviousValue $currentStartType
            return
        }
    }

    try {
        if ($Stop -and $service.Status -eq "Running") {
            Stop-Service -Name $Name -Force -ErrorAction Stop
        }

        if ($currentStartType -ne $StartupType) {
            Microsoft.PowerShell.Management\Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
            Write-Host "  - $dispName : $currentStartType → $StartupType (적용됨)" -ForegroundColor Green
            Write-OptLog -Step $stepName -Status "적용됨" -Message "시작 유형 변경됨" -PreviousValue $currentStartType -NewValue $StartupType
        } elseif ($Stop) {
            Write-Host "  - $dispName : 서비스 중지됨 (적용됨)" -ForegroundColor Green
            Write-OptLog -Step $stepName -Status "적용됨" -Message "서비스 중지됨"
        }
    } catch {
        Write-Host "  - $dispName : 설정 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step $stepName -Status "실패" -Message "설정 실패: $_"
    }
}

function Disable-ScheduledTask_Safe {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Description = ""
    )

    $stepName = if ($global:CurrentStepName) { $global:CurrentStepName } else { "Task" }
    $dispName = if ($Description) { $Description } else { "$Name" }

    try {
        $task = Get-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-Host "  - $dispName : 작업 없음 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $stepName -Status "스킵됨" -Message "작업 없음"
            return
        }

        if (-not $global:ForceOverride -and $task.State -eq "Disabled") {
            Write-Host "  - $dispName : 이미 비활성화됨 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $stepName -Status "스킵됨" -Message "이미 비활성화됨"
            return
        }

        Disable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction Stop | Out-Null
        Write-Host "  - $dispName : 비활성화됨 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $stepName -Status "적용됨" -Message "비활성화됨"
    } catch {
        Write-Host "  - $dispName : 비활성화 실패 - $_" -ForegroundColor Red
        Write-OptLog -Step $stepName -Status "실패" -Message "비활성화 실패: $_"
    }
}

# ===== Execution Engine =====

function Run-OptimizationSteps {
    param(
        [string]$Title,
        [array]$Steps
    )

    Write-Host "=== $Title v$global:CurrentScriptVersion ===" -ForegroundColor Cyan
    Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor Gray
    Write-Host ""

    $totalSteps = $Steps.Count
    $currentIndex = 1

    foreach ($step in $Steps) {
        $global:CurrentStepName = $step.Name
        
        Write-Host "[$currentIndex/$totalSteps] $($step.Name)" -ForegroundColor Yellow
        
        try {
            # Execute the action block
            & $step.Action
        } catch {
            Write-Host "  - 에러 발생: $_" -ForegroundColor Red
            Write-OptLog -Step $step.Name -Status "실패" -Message "스크립트 오류: $_"
        }

        Write-Host ""
        $currentIndex++
    }

    Save-OptLog

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
    Write-Host "Summary: 적용 $global:AppliedCount | 스킵 $global:SkippedCount | 실패 $global:FailedCount" -ForegroundColor Yellow
    Write-Host "로그: $global:LogFilePath" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}


