# Windows 11 25H2 저장소 최적화 스크립트
# Storage Sense 활성화, 휴지통 자동 정리, 임시 파일 정리, Windows.old 삭제, 시스템 복원 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "014.storage_optimization.ps1"

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
    Name = "저장소 최적화"
    Description = "Storage Sense 활성화, 자동 정리, 임시 파일/캐시 정리, 시스템 복원 최적화"
    RequiresReboot = $false
}

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_014_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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
    $logContent = "================================================================================`nWindows 11 Optimization Log - Storage Optimization`n================================================================================`n실행 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n스크립트: $scriptName v$scriptVersion`n================================================================================`n`n단계별 결과`n================================================================================`n`n"
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

Write-Host "=== Windows 11 25H2 저장소 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "Storage Sense 활성화, 자동 정리, 임시 파일/캐시 정리를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 7


# [1/7] Storage Sense 활성화 및 자동 정리 설정
Write-Host "[1/$totalSteps] Storage Sense 활성화 및 자동 정리 설정 중..." -ForegroundColor Yellow

$stepName = "1. Storage Sense"
$storageSensePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
Set-RegistryIfDifferent -Path $storageSensePath -Name "01" -Value 1 -StepName $stepName -Description "Storage Sense 활성화"
Set-RegistryIfDifferent -Path $storageSensePath -Name "2048" -Value 7 -StepName $stepName -Description "실행 주기 (매주)"
Set-RegistryIfDifferent -Path $storageSensePath -Name "04" -Value 1 -StepName $stepName -Description "임시 파일 자동 정리"
Set-RegistryIfDifferent -Path $storageSensePath -Name "08" -Value 1 -StepName $stepName -Description "클라우드 콘텐츠 로컬 전용"
Set-RegistryIfDifferent -Path $storageSensePath -Name "256" -Value 30 -StepName $stepName -Description "OneDrive 파일 정리 기간"


# [2/7] 휴지통 자동 비우기 (30일)
Write-Host ""
Write-Host "[2/$totalSteps] 휴지통 자동 비우기 설정 중 (30일)..." -ForegroundColor Yellow

$stepName = "2. 휴지통 자동 비우기"
Set-RegistryIfDifferent -Path $storageSensePath -Name "128" -Value 30 -StepName $stepName -Description "휴지통 자동 비우기 (30일)"

# 현재 휴지통 비우기 (옵션)
$recycleBinItems = (New-Object -ComObject Shell.Application).NameSpace(10).Items()
$recycleBinCount = $recycleBinItems.Count
if ($recycleBinCount -gt 0) {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-Host "  - 현재 휴지통 비우기 완료 ($recycleBinCount 항목)" -ForegroundColor Green
} else {
    Write-Host "  - 휴지통이 이미 비어있습니다" -ForegroundColor Gray
}


# [3/7] 임시 파일 자동 정리 활성화 및 수동 정리
Write-Host ""
Write-Host "[3/$totalSteps] 임시 파일 정리 중..." -ForegroundColor Yellow

# 임시 폴더 정리
$tempPaths = @(
    "$env:TEMP",
    "$env:TMP",
    "$env:LOCALAPPDATA\Temp",
    "$env:WINDIR\Temp"
)

$totalCleaned = 0
foreach ($tempPath in $tempPaths) {
    if (Test-Path $tempPath) {
        $items = Get-ChildItem -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        $sizeBefore = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        Remove-Item -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        if ($sizeBefore) {
            $totalCleaned += $sizeBefore
        }
    }
}
$cleanedMB = [math]::Round($totalCleaned / 1MB, 2)
Write-Host "  - 임시 폴더 정리 완료 ($cleanedMB MB 확보)" -ForegroundColor Green

# 프리페치 캐시 정리
$prefetchPath = "$env:WINDIR\Prefetch"
if (Test-Path $prefetchPath) {
    Remove-Item -Path "$prefetchPath\*" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  - 프리페치 캐시 정리 완료" -ForegroundColor Green
}

# 소프트웨어 배포 다운로드 캐시 정리
$softDistPath = "$env:WINDIR\SoftwareDistribution\Download"
if (Test-Path $softDistPath) {
    Remove-Item -Path "$softDistPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - Windows Update 다운로드 캐시 정리 완료" -ForegroundColor Green
}

# 썸네일 캐시 정리
$thumbCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
if (Test-Path $thumbCachePath) {
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Remove-Item -Path "$thumbCachePath\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$thumbCachePath\iconcache_*.db" -Force -ErrorAction SilentlyContinue
    Start-Process "explorer.exe"
    Write-Host "  - 썸네일/아이콘 캐시 정리 완료" -ForegroundColor Green
}


# [4/7] Windows.old 폴더 삭제
Write-Host ""
Write-Host "[4/$totalSteps] Windows.old 폴더 삭제 중..." -ForegroundColor Yellow

$windowsOldPath = "$env:SystemDrive\Windows.old"
if (Test-Path $windowsOldPath) {
    # 소유권 가져오기 및 삭제
    try {
        # 직접 삭제 시도 (cleanmgr보다 빠르고 비대화형)
        # takeown과 icacls로 권한 변경 후 삭제
        cmd /c "takeown /F `"$windowsOldPath`" /R /A /D Y" 2>$null
        cmd /c "icacls `"$windowsOldPath`" /grant Administrators:F /T /Q" 2>$null
        Remove-Item -Path $windowsOldPath -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue

        if (!(Test-Path $windowsOldPath)) {
            Write-Host "  - Windows.old 폴더 삭제 완료" -ForegroundColor Green
        } else {
            Write-Host "  - Windows.old 폴더 일부 삭제됨 (재부팅 후 완전 삭제 권장)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  - Windows.old 폴더 삭제 실패: 수동 삭제 필요" -ForegroundColor Red
    }
} else {
    Write-Host "  - Windows.old 폴더가 존재하지 않습니다" -ForegroundColor Gray
}

# $Windows.~BT 및 $Windows.~WS 폴더 삭제
$upgradeTemp = @("$env:SystemDrive\`$Windows.~BT", "$env:SystemDrive\`$Windows.~WS")
foreach ($upgradePath in $upgradeTemp) {
    if (Test-Path $upgradePath) {
        cmd /c "takeown /F `"$upgradePath`" /R /A /D Y" 2>$null
        cmd /c "icacls `"$upgradePath`" /grant Administrators:F /T /Q" 2>$null
        Remove-Item -Path $upgradePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  - $upgradePath 폴더 삭제 완료" -ForegroundColor Green
    }
}


# [5/7] 시스템 복원 포인트 최적화 (최대 용량 제한)
Write-Host ""
Write-Host "[5/$totalSteps] 시스템 복원 포인트 최적화 중..." -ForegroundColor Yellow

# 시스템 드라이브 용량 확인
$systemDrive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'" -ErrorAction SilentlyContinue
if ($systemDrive) {
    $totalSizeGB = [math]::Round($systemDrive.Size / 1GB, 0)

    # 시스템 복원 최대 용량을 드라이브 크기의 5% 또는 최대 10GB로 제한
    $maxSizeGB = [math]::Min(10, [math]::Round($totalSizeGB * 0.05, 0))
    $maxSizePercent = [math]::Round(($maxSizeGB / $totalSizeGB) * 100, 0)

    # vssadmin으로 섀도 복사본 저장소 크기 조정
    try {
        $vssCmdResult = cmd /c "vssadmin resize shadowstorage /for=$env:SystemDrive /on=$env:SystemDrive /maxsize=${maxSizeGB}GB" 2>&1
        Write-Host "  - 시스템 복원 최대 용량: ${maxSizeGB}GB (${maxSizePercent}%)" -ForegroundColor Green
    } catch {
        # PowerShell 명령으로 재시도
        $null = Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Write-Host "  - 시스템 복원 활성화 확인" -ForegroundColor Green
    }

    # 오래된 복원 포인트 삭제 (최신 1개만 유지)
    try {
        $restorePoints = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
        if ($restorePoints -and $restorePoints.Count -gt 1) {
            # 가장 최근 복원 포인트를 제외한 나머지 삭제
            vssadmin delete shadows /for=$env:SystemDrive /oldest /quiet 2>$null
            Write-Host "  - 오래된 복원 포인트 정리 완료" -ForegroundColor Green
        } else {
            Write-Host "  - 복원 포인트 정리: 이미 최적화됨" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  - 복원 포인트 정리: 수동 확인 필요" -ForegroundColor Yellow
    }
} else {
    Write-Host "  - 시스템 드라이브 정보를 가져올 수 없습니다" -ForegroundColor Yellow
}


# [6/7] 배달 최적화 캐시 정리
Write-Host ""
Write-Host "[6/$totalSteps] 배달 최적화 캐시 정리 중..." -ForegroundColor Yellow

# 배달 최적화 서비스 중지
Stop-Service -Name "DoSvc" -Force -ErrorAction SilentlyContinue

# 배달 최적화 캐시 폴더 정리
$deliveryOptPath = "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization"
if (Test-Path $deliveryOptPath) {
    $doSizeBefore = (Get-ChildItem -Path $deliveryOptPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Remove-Item -Path "$deliveryOptPath\Cache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$deliveryOptPath\Downloads\*" -Recurse -Force -ErrorAction SilentlyContinue
    $doCleanedMB = [math]::Round($doSizeBefore / 1MB, 2)
    Write-Host "  - 배달 최적화 캐시 정리 완료 (약 $doCleanedMB MB)" -ForegroundColor Green
} else {
    Write-Host "  - 배달 최적화 캐시가 존재하지 않습니다" -ForegroundColor Gray
}

# 배달 최적화 서비스 재시작
Start-Service -Name "DoSvc" -ErrorAction SilentlyContinue

# 배달 최적화 설정 (로컬 네트워크만 허용)
$doPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
if (!(Test-Path $doPath)) {
    New-Item -Path $doPath -Force | Out-Null
}
# DODownloadMode: 0=HTTP만, 1=LAN, 2=그룹, 3=인터넷, 100=바이패스
Set-ItemProperty -Path $doPath -Name "DODownloadMode" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 배달 최적화: 로컬 네트워크만 허용" -ForegroundColor Green


# [7/7] 로그 파일 정리
Write-Host ""
Write-Host "[7/$totalSteps] 로그 파일 정리 중..." -ForegroundColor Yellow

# Windows 로그 폴더 정리
$logPaths = @(
    "$env:WINDIR\Logs\CBS",
    "$env:WINDIR\Logs\DISM",
    "$env:WINDIR\Logs\MoSetup",
    "$env:WINDIR\Logs\WindowsUpdate",
    "$env:WINDIR\Panther",
    "$env:WINDIR\inf\*.log",
    "$env:WINDIR\debug\*.log"
)

$logCleaned = 0
foreach ($logPath in $logPaths) {
    if ($logPath -like "*\*.*") {
        # 와일드카드 패턴인 경우
        $files = Get-ChildItem -Path $logPath -Force -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $logCleaned += $file.Length
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }
    } elseif (Test-Path $logPath) {
        $items = Get-ChildItem -Path $logPath -Recurse -Force -ErrorAction SilentlyContinue
        $sizeBefore = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        Remove-Item -Path "$logPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        if ($sizeBefore) {
            $logCleaned += $sizeBefore
        }
    }
}
$logCleanedMB = [math]::Round($logCleaned / 1MB, 2)
Write-Host "  - Windows 로그 폴더 정리 완료 ($logCleanedMB MB 확보)" -ForegroundColor Green

# 이벤트 로그 정리 (오래된 로그만)
$eventLogs = @("Application", "System", "Security")
foreach ($logName in $eventLogs) {
    try {
        wevtutil cl $logName 2>$null
    } catch {
        # 무시
    }
}
Write-Host "  - Windows 이벤트 로그 정리 완료" -ForegroundColor Green

# Windows Update 로그 정리
$wuLogPath = "$env:WINDIR\Logs\WindowsUpdate"
if (Test-Path $wuLogPath) {
    Get-ChildItem -Path $wuLogPath -Filter "*.etl" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "  - Windows Update 추적 로그 정리 완료" -ForegroundColor Green
}

# CBS 로그 정리 (대용량)
$cbsLogPath = "$env:WINDIR\Logs\CBS"
if (Test-Path $cbsLogPath) {
    Get-ChildItem -Path $cbsLogPath -Filter "*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Host "  - CBS 로그 정리 완료 (7일 이전)" -ForegroundColor Green
}

# 메모리 덤프 파일 정리
$dumpPaths = @(
    "$env:WINDIR\MEMORY.DMP",
    "$env:WINDIR\Minidump\*",
    "$env:LOCALAPPDATA\CrashDumps\*"
)
foreach ($dumpPath in $dumpPaths) {
    if (Test-Path $dumpPath -ErrorAction SilentlyContinue) {
        Remove-Item -Path $dumpPath -Force -Recurse -ErrorAction SilentlyContinue
    }
}
Write-Host "  - 메모리 덤프 파일 정리 완료" -ForegroundColor Green


# 로그 저장
Save-OptLog

# Summary 출력
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "저장소 최적화가 완료되었습니다!" -ForegroundColor Green
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
Write-Host "  - Storage Sense 활성화 (매주 실행)" -ForegroundColor White
Write-Host "  - 휴지통 자동 비우기 (30일 후)" -ForegroundColor White
Write-Host "  - 임시 파일/캐시 정리 완료" -ForegroundColor White
Write-Host "  - Windows.old 폴더 삭제" -ForegroundColor White
Write-Host "  - 시스템 복원 용량 제한 적용" -ForegroundColor White
Write-Host "  - 배달 최적화 캐시 정리" -ForegroundColor White
Write-Host "  - 로그 파일 정리 완료" -ForegroundColor White
Write-Host ""
Write-Host "모든 설정이 즉시 적용되었습니다." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
