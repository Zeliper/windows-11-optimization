# Windows 11 전원 관리, 네트워크 최적화 및 텔레메트리 비활성화 스크립트
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "002.power_network.ps1"

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

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_002_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osVersion = if ($osInfo) { "$($osInfo.Caption) (Build $($osInfo.BuildNumber))" } else { "Unknown" }

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

    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name

    if (-not $global:ForceOverride -and $currentValue -eq $Value) {
        $msg = if ($Description) { "$Description : 이미 설정됨" } else { "$Name : 이미 설정됨" }
        Write-Host "  - $msg (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "$Name 이미 최적값" -PreviousValue "$currentValue" -NewValue "$Value"
        return $false
    }

    try {
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        $prevDisplay = if ($null -eq $currentValue) { "(없음)" } else { $currentValue }
        $msg = if ($Description) { "$Description : $prevDisplay → $Value" } else { "$Name : $prevDisplay → $Value" }
        Write-Host "  - $msg (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "$Name 변경됨" -PreviousValue "$prevDisplay" -NewValue "$Value"
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

    if (-not $global:ForceOverride -and $currentStartType -eq $StartupType) {
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

function Disable-ScheduledTaskIfEnabled {
    param(
        [string]$TaskPath,
        [string]$TaskName,
        [string]$StepName,
        [string]$Description = ""
    )

    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) {
            $displayName = if ($Description) { $Description } else { $TaskName }
            Write-Host "  - $displayName : 작업 없음 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $StepName -Status "스킵됨" -Message "$TaskName 작업 없음"
            return $false
        }

        if (-not $global:ForceOverride -and $task.State -eq "Disabled") {
            $displayName = if ($Description) { $Description } else { $TaskName }
            Write-Host "  - $displayName : 이미 비활성화됨 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $StepName -Status "스킵됨" -Message "$TaskName 이미 비활성화됨"
            return $false
        }

        Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
        $displayName = if ($Description) { $Description } else { $TaskName }
        Write-Host "  - $displayName : 비활성화됨 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "$TaskName 비활성화됨"
        return $true
    } catch {
        $displayName = if ($Description) { $Description } else { $TaskName }
        Write-Host "  - $displayName : 비활성화 실패" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "$TaskName 비활성화 실패: $_"
        return $false
    }
}

# ===== 메인 스크립트 시작 =====

Write-Host "=== 전원 관리, 네트워크 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "전원 옵션, 네트워크, 텔레메트리 최적화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 7

# GUID 추출 함수 (정규식 사용)
function Get-PowerSchemeGuid {
    param([string]$Line)
    $match = [regex]::Match($Line, '[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}')
    if ($match.Success) { return $match.Value }
    return $null
}


# [1/7] 전원 옵션을 최고 성능으로 설정
Write-Host "[1/$totalSteps] 전원 옵션 설정 중..." -ForegroundColor Yellow

$powerStep = "전원 옵션"

# 현재 활성 전원 구성표 확인
$activeSchemeOutput = powercfg -getactivescheme
$currentSchemeGuid = Get-PowerSchemeGuid -Line $activeSchemeOutput

# 고성능 또는 최고 성능 GUID 확인
$highPerfGuid = $null
$ultimatePerfGuid = $null

$allSchemes = powercfg -list
$highPerf = $allSchemes | Select-String "고성능|High performance" | Select-Object -First 1
$ultimatePerf = $allSchemes | Select-String "최고 성능|Ultimate Performance" | Select-Object -First 1

if ($ultimatePerf) {
    $ultimatePerfGuid = Get-PowerSchemeGuid -Line $ultimatePerf.Line
}
if ($highPerf) {
    $highPerfGuid = Get-PowerSchemeGuid -Line $highPerf.Line
}

# 현재 구성표가 이미 고성능/최고 성능인지 확인
$isAlreadyHighPerf = ($currentSchemeGuid -eq $highPerfGuid) -or ($currentSchemeGuid -eq $ultimatePerfGuid)

if (-not $global:ForceOverride -and $isAlreadyHighPerf) {
    $currentName = if ($currentSchemeGuid -eq $ultimatePerfGuid) { "최고 성능" } else { "고성능" }
    Write-Host "  - 전원 옵션: 이미 $currentName (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $powerStep -Status "스킵됨" -Message "이미 $currentName 모드"
} else {
    # 최고 성능 모드 활성화 (없으면 생성)
    if (-not $ultimatePerfGuid) {
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
        $allSchemes = powercfg -list
        $ultimatePerf = $allSchemes | Select-String "최고 성능|Ultimate Performance" | Select-Object -First 1
        if ($ultimatePerf) {
            $ultimatePerfGuid = Get-PowerSchemeGuid -Line $ultimatePerf.Line
        }
    }

    # 최고 성능 또는 고성능으로 설정
    $targetGuid = if ($ultimatePerfGuid) { $ultimatePerfGuid } else { $highPerfGuid }
    $targetName = if ($ultimatePerfGuid) { "최고 성능" } else { "고성능" }

    if ($targetGuid) {
        powercfg -setactive $targetGuid
        Write-Host "  - 전원 옵션: $targetName 활성화 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $powerStep -Status "적용됨" -Message "$targetName 전원 옵션 활성화"
    } else {
        Write-Host "  - 전원 옵션: 고성능 옵션을 찾을 수 없음" -ForegroundColor Red
        Write-OptLog -Step $powerStep -Status "실패" -Message "고성능 옵션 없음"
    }
}


# [2/7] 절전 설정 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] 절전 설정 비활성화 중..." -ForegroundColor Yellow

$sleepStep = "절전 설정"

# 현재 설정 확인 함수
function Get-PowerSettingValue {
    param([string]$SubGroup, [string]$Setting, [string]$Type)  # Type: AC or DC
    $output = powercfg /query SCHEME_CURRENT $SubGroup $Setting 2>$null
    $pattern = if ($Type -eq "AC") { "현재 AC 전원 설정 인덱스|Current AC Power Setting Index" } else { "현재 DC 전원 설정 인덱스|Current DC Power Setting Index" }
    $match = $output | Select-String $pattern
    if ($match) {
        $hexMatch = [regex]::Match($match.Line, '0x([0-9a-fA-F]+)')
        if ($hexMatch.Success) {
            return [Convert]::ToInt32($hexMatch.Groups[1].Value, 16)
        }
    }
    return -1
}

# 절전 모드 (SUB_SLEEP STANDBYIDLE)
$standbyAC = Get-PowerSettingValue -SubGroup "SUB_SLEEP" -Setting "STANDBYIDLE" -Type "AC"
$standbyDC = Get-PowerSettingValue -SubGroup "SUB_SLEEP" -Setting "STANDBYIDLE" -Type "DC"

if (-not $global:ForceOverride -and $standbyAC -eq 0 -and $standbyDC -eq 0) {
    Write-Host "  - 절전 모드: 이미 비활성화됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $sleepStep -Status "스킵됨" -Message "절전 모드 이미 비활성화"
} else {
    powercfg -change -standby-timeout-ac 0
    powercfg -change -standby-timeout-dc 0
    Write-Host "  - 절전 모드: 비활성화됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $sleepStep -Status "적용됨" -Message "절전 모드 비활성화"
}

# 모니터 끄기 (SUB_VIDEO VIDEOIDLE)
$monitorAC = Get-PowerSettingValue -SubGroup "SUB_VIDEO" -Setting "VIDEOIDLE" -Type "AC"
$monitorDC = Get-PowerSettingValue -SubGroup "SUB_VIDEO" -Setting "VIDEOIDLE" -Type "DC"

if (-not $global:ForceOverride -and $monitorAC -eq 0 -and $monitorDC -eq 0) {
    Write-Host "  - 모니터 끄기: 이미 비활성화됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $sleepStep -Status "스킵됨" -Message "모니터 끄기 이미 비활성화"
} else {
    powercfg -change -monitor-timeout-ac 0
    powercfg -change -monitor-timeout-dc 0
    Write-Host "  - 모니터 끄기: 비활성화됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $sleepStep -Status "적용됨" -Message "모니터 끄기 비활성화"
}

# 하드 디스크 끄기 (SUB_DISK DISKIDLE)
$diskAC = Get-PowerSettingValue -SubGroup "SUB_DISK" -Setting "DISKIDLE" -Type "AC"
$diskDC = Get-PowerSettingValue -SubGroup "SUB_DISK" -Setting "DISKIDLE" -Type "DC"

if (-not $global:ForceOverride -and $diskAC -eq 0 -and $diskDC -eq 0) {
    Write-Host "  - 하드 디스크 끄기: 이미 비활성화됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $sleepStep -Status "스킵됨" -Message "하드 디스크 끄기 이미 비활성화"
} else {
    powercfg -change -disk-timeout-ac 0
    powercfg -change -disk-timeout-dc 0
    Write-Host "  - 하드 디스크 끄기: 비활성화됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $sleepStep -Status "적용됨" -Message "하드 디스크 끄기 비활성화"
}

# 최대 절전 모드 상태 확인
$hibernateStatus = powercfg /a 2>$null | Select-String "최대 절전 모드|Hibernate|Hibernation"
$isHibernateOff = ($hibernateStatus | Select-String "지원 안 함|disabled|not available|not supported").Count -gt 0

if (-not $global:ForceOverride -and $isHibernateOff) {
    Write-Host "  - 최대 절전 모드: 이미 비활성화됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $sleepStep -Status "스킵됨" -Message "최대 절전 모드 이미 비활성화"
} else {
    powercfg -hibernate off
    Write-Host "  - 최대 절전 모드: 비활성화됨 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $sleepStep -Status "적용됨" -Message "최대 절전 모드 비활성화"
}


# [3/7] USB 선택적 절전 모드 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] USB 선택적 절전 모드 비활성화 중..." -ForegroundColor Yellow

$usbStep = "USB 절전"
$activeScheme = Get-PowerSchemeGuid -Line (powercfg -getactivescheme)

if ($activeScheme) {
    # USB 선택적 절전 현재 값 확인
    # USB 설정 GUID: 2a737441-1930-4402-8d77-b2bebba308a3
    # USB 선택적 절전 GUID: 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
    $usbSuspendAC = Get-PowerSettingValue -SubGroup "2a737441-1930-4402-8d77-b2bebba308a3" -Setting "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" -Type "AC"
    $usbSuspendDC = Get-PowerSettingValue -SubGroup "2a737441-1930-4402-8d77-b2bebba308a3" -Setting "48e6b7a6-50f5-4782-a5d4-53bb8f07e226" -Type "DC"

    if (-not $global:ForceOverride -and $usbSuspendAC -eq 0 -and $usbSuspendDC -eq 0) {
        Write-Host "  - USB 선택적 절전 모드: 이미 비활성화됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $usbStep -Status "스킵됨" -Message "USB 선택적 절전 이미 비활성화"
    } else {
        powercfg -setacvalueindex $activeScheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg -setdcvalueindex $activeScheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
        powercfg -setactive $activeScheme
        Write-Host "  - USB 선택적 절전 모드: 비활성화됨 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $usbStep -Status "적용됨" -Message "USB 선택적 절전 비활성화"
    }
} else {
    Write-Host "  - 활성 전원 구성표 GUID를 가져올 수 없음" -ForegroundColor Red
    Write-OptLog -Step $usbStep -Status "실패" -Message "전원 구성표 GUID 없음"
}


# [4/7] PCI Express 링크 상태 전원 관리 끄기
Write-Host ""
Write-Host "[4/$totalSteps] PCI Express 전원 관리 비활성화 중..." -ForegroundColor Yellow

$pcieStep = "PCIe 전원"

if ($activeScheme) {
    # PCI Express 설정 GUID: 501a4d13-42af-4429-9fd1-a8218c268e20
    # 링크 상태 전원 관리 GUID: ee12f906-d277-404b-b6da-e5fa1a576df5
    $pcieAC = Get-PowerSettingValue -SubGroup "501a4d13-42af-4429-9fd1-a8218c268e20" -Setting "ee12f906-d277-404b-b6da-e5fa1a576df5" -Type "AC"
    $pcieDC = Get-PowerSettingValue -SubGroup "501a4d13-42af-4429-9fd1-a8218c268e20" -Setting "ee12f906-d277-404b-b6da-e5fa1a576df5" -Type "DC"

    if (-not $global:ForceOverride -and $pcieAC -eq 0 -and $pcieDC -eq 0) {
        Write-Host "  - PCI Express 링크 상태 전원 관리: 이미 비활성화됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $pcieStep -Status "스킵됨" -Message "PCIe 전원 관리 이미 비활성화"
    } else {
        powercfg -setacvalueindex $activeScheme 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg -setdcvalueindex $activeScheme 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
        powercfg -setactive $activeScheme
        Write-Host "  - PCI Express 링크 상태 전원 관리: 비활성화됨 (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $pcieStep -Status "적용됨" -Message "PCIe 전원 관리 비활성화"
    }
} else {
    Write-Host "  - 활성 전원 구성표를 사용할 수 없어 건너뜀" -ForegroundColor Red
    Write-OptLog -Step $pcieStep -Status "실패" -Message "전원 구성표 없음"
}


# [5/7] 네트워크 어댑터 절전 모드 비활성화
Write-Host ""
Write-Host "[5/$totalSteps] 네트워크 어댑터 절전 모드 비활성화 중..." -ForegroundColor Yellow

$networkStep = "네트워크 어댑터"
$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

if ($adapters.Count -gt 0) {
    foreach ($adapter in $adapters) {
        $adapterName = $adapter.Name
        $pnpDevice = Get-PnpDevice | Where-Object { $_.FriendlyName -eq $adapter.InterfaceDescription }

        if ($pnpDevice) {
            $pnpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
            Get-ChildItem $pnpPath -ErrorAction SilentlyContinue | ForEach-Object {
                $driverDesc = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
                if ($driverDesc -eq $adapter.InterfaceDescription) {
                    $currentPnp = (Get-ItemProperty $_.PSPath -Name "PnPCapabilities" -ErrorAction SilentlyContinue).PnPCapabilities
                    if (-not $global:ForceOverride -and $currentPnp -eq 24) {
                        Write-Host "  - $adapterName : 이미 비활성화됨 (스킵)" -ForegroundColor Gray
                        Write-OptLog -Step $networkStep -Status "스킵됨" -Message "$adapterName 이미 절전 비활성화"
                    } else {
                        Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -ErrorAction SilentlyContinue
                        Write-Host "  - $adapterName : 절전 비활성화됨 (적용됨)" -ForegroundColor Green
                        Write-OptLog -Step $networkStep -Status "적용됨" -Message "$adapterName 절전 비활성화"
                    }
                }
            }
        }
    }
} else {
    Write-Host "  - 활성 물리적 네트워크 어댑터 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $networkStep -Status "스킵됨" -Message "활성 어댑터 없음"
}


# [6/7] Nagle 알고리즘 비활성화
Write-Host ""
Write-Host "[6/$totalSteps] Nagle 알고리즘 비활성화 중..." -ForegroundColor Yellow

$nagleStep = "Nagle 알고리즘"
$tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
$interfaces = Get-ChildItem $tcpipPath -ErrorAction SilentlyContinue

$nagleApplied = 0
$nagleSkipped = 0

foreach ($interface in $interfaces) {
    $ifPath = $interface.PSPath
    $currentAckFreq = (Get-ItemProperty -Path $ifPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue).TcpAckFrequency
    $currentNoDelay = (Get-ItemProperty -Path $ifPath -Name "TcpNoDelay" -ErrorAction SilentlyContinue).TcpNoDelay

    if (-not $global:ForceOverride -and $currentAckFreq -eq 1 -and $currentNoDelay -eq 1) {
        $nagleSkipped++
    } else {
        Set-ItemProperty -Path $ifPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $ifPath -Name "TcpNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
        $nagleApplied++
    }
}

if ($nagleApplied -gt 0) {
    Write-Host "  - Nagle 알고리즘: $nagleApplied 개 인터페이스 비활성화 (적용됨)" -ForegroundColor Green
    Write-OptLog -Step $nagleStep -Status "적용됨" -Message "$nagleApplied 개 인터페이스 Nagle 비활성화"
}
if ($nagleSkipped -gt 0) {
    Write-Host "  - Nagle 알고리즘: $nagleSkipped 개 인터페이스 이미 비활성화 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $nagleStep -Status "스킵됨" -Message "$nagleSkipped 개 인터페이스 이미 비활성화"
}


# [7/7] 텔레메트리 비활성화
Write-Host ""
Write-Host "[7/$totalSteps] 텔레메트리 비활성화 중..." -ForegroundColor Yellow

$telemetryStep = "텔레메트리"

# DiagTrack 서비스
Set-ServiceIfDifferent -ServiceName "DiagTrack" -StartupType "Disabled" -StopService $true -StepName $telemetryStep -Description "DiagTrack 서비스"

# dmwappushservice
Set-ServiceIfDifferent -ServiceName "dmwappushservice" -StartupType "Disabled" -StopService $true -StepName $telemetryStep -Description "dmwappushservice"

# 진단 데이터 수준 레지스트리
$dataCollectionPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
Set-RegistryIfDifferent -Path $dataCollectionPath -Name "AllowTelemetry" -Value 0 -StepName $telemetryStep -Description "AllowTelemetry (0=비활성화)"
Set-RegistryIfDifferent -Path $dataCollectionPath -Name "MaxTelemetryAllowed" -Value 0 -StepName $telemetryStep -Description "MaxTelemetryAllowed (0=비활성화)"

# 피드백 빈도
$siufPath = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"
Set-RegistryIfDifferent -Path $siufPath -Name "NumberOfSIUFInPeriod" -Value 0 -StepName $telemetryStep -Description "NumberOfSIUFInPeriod (0=비활성화)"

# 광고 ID
$advertisingPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
Set-RegistryIfDifferent -Path $advertisingPath -Name "Enabled" -Value 0 -StepName $telemetryStep -Description "광고 ID (0=비활성화)"

# 활동 기록
$activityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
Set-RegistryIfDifferent -Path $activityPath -Name "EnableActivityFeed" -Value 0 -StepName $telemetryStep -Description "EnableActivityFeed (0=비활성화)"
Set-RegistryIfDifferent -Path $activityPath -Name "PublishUserActivities" -Value 0 -StepName $telemetryStep -Description "PublishUserActivities (0=비활성화)"
Set-RegistryIfDifferent -Path $activityPath -Name "UploadUserActivities" -Value 0 -StepName $telemetryStep -Description "UploadUserActivities (0=비활성화)"

# 맞춤형 환경
$appDiagPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
Set-RegistryIfDifferent -Path $appDiagPath -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -StepName $telemetryStep -Description "맞춤형 환경 (0=비활성화)"

# 텔레메트리 예약 작업 비활성화
$telemetryTasks = @(
    @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser" },
    @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "ProgramDataUpdater" },
    @{ Path = "\Microsoft\Windows\Autochk\"; Name = "Proxy" },
    @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "Consolidator" },
    @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "UsbCeip" },
    @{ Path = "\Microsoft\Windows\DiskDiagnostic\"; Name = "Microsoft-Windows-DiskDiagnosticDataCollector" }
)

foreach ($task in $telemetryTasks) {
    Disable-ScheduledTaskIfEnabled -TaskPath $task.Path -TaskName $task.Name -StepName $telemetryStep -Description $task.Name
}


# ===== 로그 저장 =====
Save-OptLog


# ===== 완료 메시지 =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount 개" -ForegroundColor $(if ($global:FailedCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor Cyan
Write-Host ""
Write-Host "일부 변경 사항은 재부팅 후 적용됩니다." -ForegroundColor Yellow
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
