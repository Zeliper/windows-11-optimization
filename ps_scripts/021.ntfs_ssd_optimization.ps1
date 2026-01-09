# Windows 11 NTFS 및 SSD 최적화 스크립트
# NTFS 8.3 파일명 비활성화, Last Access Time 비활성화, Native NVMe 드라이버 활성화
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

# ForceOverride 모드 확인
if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

# ExperimentalOptions 확인 (Orchestrate 모드에서 전달됨)
if ($null -eq $global:ExperimentalOptions) {
    $global:ExperimentalOptions = @{}
}

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "021.ntfs_ssd_optimization.ps1"

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_021_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
    $logContent = @()
    $logContent += "===== Windows 11 Optimizer Log ====="
    $logContent += "스크립트: $scriptName v$scriptVersion"
    $logContent += "실행 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $logContent += "====================================="
    $logContent += ""
    foreach ($entry in $global:LogEntries) {
        $line = "[$($entry.Timestamp)] [$($entry.Status)] $($entry.Step): $($entry.Message)"
        if ($entry.PreviousValue -or $entry.NewValue) {
            $line += " ($($entry.PreviousValue) -> $($entry.NewValue))"
        }
        $logContent += $line
    }
    $logContent += ""
    $logContent += "===== Summary ====="
    $logContent += "적용됨: $global:AppliedCount"
    $logContent += "스킵됨: $global:SkippedCount"
    $logContent += "실패: $global:FailedCount"
    $logContent | Out-File -FilePath $global:LogFilePath -Encoding UTF8
}

function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord",
        [string]$StepName
    )
    try {
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
        if (-not $global:ForceOverride -and $currentValue -eq $Value) {
            Write-Host "  - $StepName : 이미 설정됨 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 최적 설정" -PreviousValue "$currentValue" -NewValue "$Value"
            return $false
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
        Write-Host "  - $StepName : $currentValue → $Value (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "레지스트리 변경" -PreviousValue "$currentValue" -NewValue "$Value"
        return $true
    } catch {
        Write-Host "  - $StepName : 설정 실패" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "$_"
        return $false
    }
}

function Set-FsutilIfDifferent {
    param(
        [string]$BehaviorName,
        [string]$TargetValue,
        [string]$StepName
    )
    try {
        $queryResult = fsutil behavior query $BehaviorName 2>&1
        $currentValue = if ($queryResult -match "=\s*(\d+)") { $matches[1] } else { "Unknown" }

        if (-not $global:ForceOverride -and $currentValue -eq $TargetValue) {
            Write-Host "  - $StepName : 이미 $TargetValue (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 최적 설정" -PreviousValue $currentValue -NewValue $TargetValue
            return $false
        }

        $result = fsutil behavior set $BehaviorName $TargetValue 2>&1
        Write-Host "  - $StepName : $currentValue → $TargetValue (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $StepName -Status "적용됨" -Message "fsutil 설정 변경" -PreviousValue $currentValue -NewValue $TargetValue
        return $true
    } catch {
        Write-Host "  - $StepName : 설정 실패" -ForegroundColor Red
        Write-OptLog -Step $StepName -Status "실패" -Message "$_"
        return $false
    }
}

Write-Host "=== Windows 11 NTFS/SSD 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "NTFS 파일 시스템 최적화, SSD 성능 향상, Native NVMe 드라이버 활성화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 6

# [1/6] NTFS 8.3 파일명 생성 비활성화
Write-Host "[1/$totalSteps] NTFS 8.3 파일명 생성 비활성화 중..." -ForegroundColor Yellow

$fileSystemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

Set-RegistryIfDifferent -Path $fileSystemPath -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord -StepName "NtfsDisable8dot3NameCreation (레지스트리)"
Set-FsutilIfDifferent -BehaviorName "disable8dot3" -TargetValue "1" -StepName "disable8dot3 (fsutil)"

# [2/6] NTFS Last Access Time 업데이트 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] NTFS Last Access Time 업데이트 비활성화 중..." -ForegroundColor Yellow

Set-RegistryIfDifferent -Path $fileSystemPath -Name "NtfsDisableLastAccessUpdate" -Value 0x80000001 -Type DWord -StepName "NtfsDisableLastAccessUpdate (레지스트리)"
Set-FsutilIfDifferent -BehaviorName "disablelastaccess" -TargetValue "1" -StepName "disablelastaccess (fsutil)"

# [3/6] TRIM 상태 확인 및 최적화
Write-Host ""
Write-Host "[3/$totalSteps] TRIM 상태 확인 및 최적화 중..." -ForegroundColor Yellow

try {
    $trimStatus = fsutil behavior query disabledeletenotify 2>&1
    if ($trimStatus -match "DisableDeleteNotify\s*=\s*0" -or $trimStatus -match "NTFS DisableDeleteNotify\s*=\s*0") {
        Write-Host "  - TRIM: 활성화됨 (정상)" -ForegroundColor Green
        Write-OptLog -Step "TRIM 상태" -Status "스킵됨" -Message "이미 활성화됨"
    } elseif ($trimStatus -match "DisableDeleteNotify\s*=\s*1" -or $trimStatus -match "NTFS DisableDeleteNotify\s*=\s*1") {
        Write-Host "  - TRIM: 비활성화됨 (문제 발견)" -ForegroundColor Red
        Write-Host "  - TRIM 활성화 시도 중..." -ForegroundColor Yellow
        fsutil behavior set disabledeletenotify NTFS 0 2>&1 | Out-Null
        Write-Host "  - TRIM: 활성화 완료" -ForegroundColor Green
        Write-OptLog -Step "TRIM 활성화" -Status "적용됨" -Message "TRIM 활성화 완료"
    } else {
        Write-Host "  - TRIM 상태: $trimStatus" -ForegroundColor Gray
        Write-OptLog -Step "TRIM 상태" -Status "스킵됨" -Message "상태 확인 불가: $trimStatus"
    }
} catch {
    Write-Host "  - TRIM 상태 확인 실패: $_" -ForegroundColor Red
    Write-OptLog -Step "TRIM 상태" -Status "실패" -Message "$_"
}

# [4/6] Native NVMe 드라이버 활성화 (Windows 11 25H2) - 실험적 기능
Write-Host ""
Write-Host "[4/$totalSteps] Native NVMe 드라이버 활성화 확인 중..." -ForegroundColor Yellow

# 실험적 기능 활성화 여부 확인
$enableNativeNVMe = $false

if ($global:OrchestrateMode) {
    # Orchestrate 모드: ExperimentalOptions에서 사용자 선택 확인
    if ($global:ExperimentalOptions -and $global:ExperimentalOptions["EnableNativeNVMe"] -eq $true) {
        $enableNativeNVMe = $true
        Write-Host "  - Native NVMe 활성화 (사용자 선택)" -ForegroundColor Green
    } else {
        Write-Host "  - Native NVMe 건너뜀 (실험적 기능 미선택)" -ForegroundColor Yellow
        Write-OptLog -Step "Native NVMe" -Status "스킵됨" -Message "실험적 기능 미선택"
    }
} else {
    # 단독 실행: 사용자에게 직접 질문
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host "경고: Native NVMe 지원은 실험적 기능입니다!" -ForegroundColor Red
    Write-Host "================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "장점: 최대 80% IOPS 향상, I/O 레이턴시 감소" -ForegroundColor Green
    Write-Host "위험: 일부 NVMe 드라이브에서 호환성 문제 가능" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "Native NVMe를 활성화하시겠습니까? (Y/N, 기본값: N)"
    if ($choice -eq "Y" -or $choice -eq "y") {
        $enableNativeNVMe = $true
    }
}

if ($enableNativeNVMe) {
    $featurePath = "HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides"

    Set-RegistryIfDifferent -Path $featurePath -Name "735209102" -Value 1 -Type DWord -StepName "Feature 735209102 (Native NVMe)"
    Set-RegistryIfDifferent -Path $featurePath -Name "156965516" -Value 1 -Type DWord -StepName "Feature 156965516 (Native NVMe 추가)"

    Write-Host "  - 참고: Microsoft 기본 NVMe 드라이버 사용 시에만 적용됨" -ForegroundColor Yellow
    Write-Host "  - 참고: Samsung, WD 등 제조사 드라이버 사용 시 효과 없음" -ForegroundColor Yellow
}

# [5/6] SSD 드라이브 감지 및 최적화
Write-Host ""
Write-Host "[5/$totalSteps] SSD 드라이브 감지 및 최적화 중..." -ForegroundColor Yellow

$physicalDisks = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" -or $_.MediaType -eq "NVMe" }

if ($physicalDisks.Count -gt 0) {
    Write-Host "  - 감지된 SSD 드라이브:" -ForegroundColor White
    foreach ($disk in $physicalDisks) {
        Write-Host "    - $($disk.FriendlyName) ($($disk.MediaType), $([math]::Round($disk.Size / 1GB, 0)) GB)" -ForegroundColor Gray
    }

    try {
        $defragTask = Get-ScheduledTask -TaskName "ScheduledDefrag" -ErrorAction SilentlyContinue
        if ($defragTask) {
            Write-Host "  - 예약된 디스크 최적화 작업: 존재함" -ForegroundColor Gray
            Write-Host "    (Windows는 SSD에 대해 자동으로 TRIM만 수행)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  - 예약된 디스크 최적화 작업 확인 실패" -ForegroundColor Gray
    }

    $prefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    $currentValue = (Get-ItemProperty -Path $prefetchPath -Name "EnablePrefetcher" -ErrorAction SilentlyContinue).EnablePrefetcher
    if ($currentValue) {
        Write-Host "  - Prefetch 현재 설정: $currentValue (3 = 모두 활성화, 권장)" -ForegroundColor Gray
    }
} else {
    Write-Host "  - SSD 드라이브를 찾을 수 없습니다." -ForegroundColor Gray
    Write-Host "    (HDD만 있거나 드라이브 타입을 감지할 수 없음)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "  NVMe 드라이버 상태 확인 중..." -ForegroundColor White
try {
    $nvmeControllers = Get-PnpDevice -Class "SCSIAdapter" -Status OK -ErrorAction SilentlyContinue |
                       Where-Object { $_.FriendlyName -match "NVMe" }

    if ($nvmeControllers.Count -gt 0) {
        foreach ($controller in $nvmeControllers) {
            $driverDesc = Get-PnpDeviceProperty -InstanceId $controller.InstanceId -KeyName "DEVPKEY_Device_DriverDesc" -ErrorAction SilentlyContinue
            Write-Host "  - $($controller.FriendlyName)" -ForegroundColor Gray
            if ($driverDesc) {
                Write-Host "    드라이버: $($driverDesc.Data)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  - NVMe 컨트롤러를 찾을 수 없습니다." -ForegroundColor Gray
    }
} catch {
    Write-Host "  - NVMe 드라이버 확인 실패: $_" -ForegroundColor Gray
}

# [6/6] 설정 확인 및 완료
Write-Host ""
Write-Host "[6/$totalSteps] 설정 확인 중..." -ForegroundColor Yellow

Write-Host ""
Write-Host "  현재 NTFS 설정:" -ForegroundColor White
try {
    $behavior8dot3 = fsutil behavior query disable8dot3 2>&1
    $behaviorLastAccess = fsutil behavior query disablelastaccess 2>&1
    $behaviorTrim = fsutil behavior query disabledeletenotify 2>&1

    Write-Host "  - 8.3 파일명: $behavior8dot3" -ForegroundColor Gray
    Write-Host "  - Last Access: $behaviorLastAccess" -ForegroundColor Gray
    Write-Host "  - TRIM: $behaviorTrim" -ForegroundColor Gray
} catch {
    Write-Host "  - 설정 확인 실패" -ForegroundColor Red
}

# 로그 저장
Save-OptLog

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NTFS/SSD 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor White
Write-Host ""
Write-Host "주의사항:" -ForegroundColor Red
Write-Host "  - Native NVMe는 Microsoft 기본 드라이버 사용 시에만 적용" -ForegroundColor Yellow
Write-Host "  - Samsung, WD 등 제조사 드라이버 사용 시 효과 없음" -ForegroundColor Yellow
Write-Host "  - 재부팅 후 Device Manager에서 'Storage disks' 카테고리 확인" -ForegroundColor Yellow
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
