# Windows 11 메모리 최적화 스크립트
# 페이지 파일 최적화, 시스템 캐시, 메모리 압축, SysMain/Prefetch 자동화, NDU 메모리 누수 해결
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
$scriptVersion = "1.1.0"
$scriptName = "018.memory_optimization.ps1"

# ===== 로깅 시스템 =====
$logFileName = "Windows11Optimizer_018_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$global:LogFilePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $logFileName
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
    param(
        [string]$SystemInfo,
        [string]$DriveInfo
    )

    $logContent = @"
================================================================================
Windows 11 Optimization Log
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
스크립트: $scriptName v$scriptVersion
================================================================================

$SystemInfo

$DriveInfo

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

Write-Host "=== Windows 11 메모리 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "페이지 파일, SysMain/Prefetch 자동 설정, 메모리 최적화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 9


# [1/9] 시스템 메모리 분석
Write-Host "[1/$totalSteps] 시스템 메모리 분석 중..." -ForegroundColor Yellow

$totalRAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
$availableRAM = [math]::Round((Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
$usedRAM = $totalRAM - $availableRAM
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$osVersion = "$($osInfo.Caption) (Build $($osInfo.BuildNumber))"

Write-Host "  - 총 RAM: $totalRAM GB" -ForegroundColor White
Write-Host "  - 사용 가능 RAM: $availableRAM GB" -ForegroundColor White
Write-Host "  - 사용 중: $([math]::Round($usedRAM, 1)) GB ($([math]::Round(($usedRAM / $totalRAM) * 100, 1))%)" -ForegroundColor White

$systemInfo = @"
[시스템 정보]
  OS: $osVersion
  총 RAM: $totalRAM GB
  사용 가능: $availableRAM GB
  사용 중: $([math]::Round($usedRAM, 1)) GB ($([math]::Round(($usedRAM / $totalRAM) * 100, 1))%)
"@

Write-OptLog -Step "시스템 분석" -Status "적용됨" -Message "RAM $totalRAM GB, 사용 가능 $availableRAM GB"


# [2/9] 시스템 드라이브 분석
Write-Host ""
Write-Host "[2/$totalSteps] 시스템 드라이브 분석 중..." -ForegroundColor Yellow

$systemDriveLetter = $env:SystemDrive.TrimEnd(':')
$driveMediaType = "Unknown"
$driveBusType = "Unknown"
$driveModel = "Unknown"
$isNVMe = $false
$isSSD = $false

try {
    # 파티션에서 디스크 번호 찾기
    $partition = Get-Partition -DriveLetter $systemDriveLetter -ErrorAction SilentlyContinue
    if ($partition) {
        $diskNumber = $partition.DiskNumber
        $physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq "$diskNumber" }

        if ($physicalDisk) {
            $driveMediaType = $physicalDisk.MediaType
            $driveBusType = $physicalDisk.BusType
            $driveModel = $physicalDisk.FriendlyName

            # NVMe 또는 SSD 판별
            $isNVMe = ($driveBusType -eq "NVMe")
            $isSSD = ($driveMediaType -eq "SSD") -or $isNVMe
        }
    }
} catch {
    Write-Host "  - 드라이브 정보 조회 실패: $_" -ForegroundColor Yellow
}

Write-Host "  - 드라이브: $env:SystemDrive" -ForegroundColor White
Write-Host "  - 미디어 타입: $driveMediaType" -ForegroundColor White
Write-Host "  - 버스 타입: $driveBusType" -ForegroundColor White
Write-Host "  - 모델: $driveModel" -ForegroundColor White

if ($isNVMe) {
    Write-Host "  → NVMe SSD 감지됨: Superfetch/Prefetch 비활성화 권장" -ForegroundColor Cyan
} elseif ($isSSD) {
    Write-Host "  → SATA SSD 감지됨: Superfetch 비활성화, Prefetch 부팅만 권장" -ForegroundColor Cyan
} else {
    Write-Host "  → HDD 감지됨: Superfetch/Prefetch 활성화 유지" -ForegroundColor Cyan
}

$driveInfo = @"
[시스템 드라이브]
  드라이브: $env:SystemDrive
  미디어 타입: $driveMediaType
  버스 타입: $driveBusType
  모델: $driveModel
  NVMe: $isNVMe
  SSD: $isSSD
"@

Write-OptLog -Step "드라이브 분석" -Status "적용됨" -Message "드라이브 타입: $driveBusType ($driveMediaType)"


# [3/9] Superfetch/SysMain 자동 설정
Write-Host ""
Write-Host "[3/$totalSteps] Superfetch/SysMain 설정 중..." -ForegroundColor Yellow

$sysMainStep = "SysMain 설정"

if ($isNVMe -or $isSSD) {
    # SSD/NVMe: SysMain 비활성화
    $targetStartType = "Disabled"
    $reason = if ($isNVMe) { "NVMe SSD" } else { "SATA SSD" }
    Write-Host "  - 목표: 비활성화 ($reason 감지됨)" -ForegroundColor White
    Set-ServiceIfDifferent -ServiceName "SysMain" -StartupType $targetStartType -StopService $true -StepName $sysMainStep -Description "SysMain"
} else {
    # HDD: SysMain 활성화 유지
    Write-Host "  - SysMain: 활성화 유지 (HDD 감지됨)" -ForegroundColor Gray
    Write-OptLog -Step $sysMainStep -Status "스킵됨" -Message "HDD 감지, 활성화 유지 권장"
}


# [4/9] Prefetch 자동 설정
Write-Host ""
Write-Host "[4/$totalSteps] Prefetch 설정 중..." -ForegroundColor Yellow

$prefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
$prefetchStep = "Prefetch 설정"

# 드라이브 타입별 Prefetch 값 결정
# 0 = 비활성화, 1 = 앱만, 2 = 부팅만, 3 = 앱+부팅
if ($isNVMe) {
    $targetPrefetch = 0
    $prefetchDesc = "완전 비활성화 (NVMe)"
} elseif ($isSSD) {
    $targetPrefetch = 2
    $prefetchDesc = "부팅만 활성화 (SATA SSD)"
} else {
    $targetPrefetch = 3
    $prefetchDesc = "앱+부팅 활성화 (HDD)"
}

Write-Host "  - 목표: $prefetchDesc" -ForegroundColor White
Set-RegistryIfDifferent -Path $prefetchPath -Name "EnablePrefetcher" -Value $targetPrefetch -StepName $prefetchStep -Description "EnablePrefetcher"

# EnableSuperfetch도 동일하게 설정
Set-RegistryIfDifferent -Path $prefetchPath -Name "EnableSuperfetch" -Value $targetPrefetch -StepName $prefetchStep -Description "EnableSuperfetch"


# [5/9] 페이지 파일 최적화
Write-Host ""
Write-Host "[5/$totalSteps] 페이지 파일 최적화 중..." -ForegroundColor Yellow

$pageFileStep = "페이지 파일"

# 페이지 파일 권장 크기 계산
if ($totalRAM -le 8) {
    $recommendedMinGB = [math]::Ceiling($totalRAM * 1.5)
    $recommendedMaxGB = $totalRAM * 3
} elseif ($totalRAM -le 16) {
    $recommendedMinGB = $totalRAM
    $recommendedMaxGB = $totalRAM * 2
} elseif ($totalRAM -le 32) {
    $recommendedMinGB = [math]::Min($totalRAM, 16)
    $recommendedMaxGB = $totalRAM
} else {
    $recommendedMinGB = 16
    $recommendedMaxGB = 24
}

$recommendedMinMB = $recommendedMinGB * 1024
$recommendedMaxMB = $recommendedMaxGB * 1024

# 현재 페이지 파일 설정 확인
$pageFile = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue
$autoManaged = (Get-CimInstance -ClassName Win32_ComputerSystem).AutomaticManagedPagefile

$needsChange = $false
if ($autoManaged) {
    Write-Host "  - 현재 설정: 자동 관리" -ForegroundColor White
    $needsChange = $true
} elseif ($pageFile) {
    Write-Host "  - 현재: $($pageFile.InitialSize) ~ $($pageFile.MaximumSize) MB" -ForegroundColor White
    if ($pageFile.InitialSize -ne $recommendedMinMB -or $pageFile.MaximumSize -ne $recommendedMaxMB) {
        $needsChange = $true
    }
} else {
    Write-Host "  - 현재: 감지되지 않음" -ForegroundColor Yellow
    $needsChange = $true
}

Write-Host "  - 권장: $recommendedMinMB ~ $recommendedMaxMB MB (RAM $totalRAM GB 기준)" -ForegroundColor White

$optimizePageFile = "Y"
if (-not $global:OrchestrateMode -and $needsChange) {
    $optimizePageFile = Read-Host "  페이지 파일을 권장 설정으로 변경하시겠습니까? (Y/N, 기본값: Y)"
    if ([string]::IsNullOrEmpty($optimizePageFile)) { $optimizePageFile = "Y" }
}

if (($optimizePageFile -eq "Y" -or $optimizePageFile -eq "y") -and $needsChange) {
    try {
        $compSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $compSystem | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }

        Get-CimInstance -ClassName Win32_PageFileSetting | Remove-CimInstance -ErrorAction SilentlyContinue

        $pageFilePath = "$env:SystemDrive\pagefile.sys"
        New-CimInstance -ClassName Win32_PageFileSetting -Property @{
            Name = $pageFilePath
            InitialSize = $recommendedMinMB
            MaximumSize = $recommendedMaxMB
        } -ErrorAction SilentlyContinue

        Write-Host "  - 페이지 파일: $recommendedMinMB ~ $recommendedMaxMB MB (적용됨)" -ForegroundColor Green
        Write-OptLog -Step $pageFileStep -Status "적용됨" -Message "페이지 파일 변경됨" -PreviousValue "자동 관리" -NewValue "$recommendedMinMB ~ $recommendedMaxMB MB"
    } catch {
        Write-Host "  - 페이지 파일 설정 실패: $_" -ForegroundColor Red
        Write-OptLog -Step $pageFileStep -Status "실패" -Message "설정 실패: $_"
    }
} elseif (-not $needsChange) {
    Write-Host "  - 페이지 파일: 이미 최적 설정 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $pageFileStep -Status "스킵됨" -Message "이미 최적 설정"
} else {
    Write-Host "  - 페이지 파일: 사용자 선택으로 유지" -ForegroundColor Gray
    Write-OptLog -Step $pageFileStep -Status "스킵됨" -Message "사용자 선택으로 유지"
}


# [6/9] 시스템 캐시 크기 최적화 (LargeSystemCache)
Write-Host ""
Write-Host "[6/$totalSteps] 시스템 캐시 크기 최적화 중..." -ForegroundColor Yellow

$memMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
$cacheStep = "LargeSystemCache"

$targetCache = if ($totalRAM -ge 16) { 1 } else { 0 }
$cacheDesc = if ($totalRAM -ge 16) { "활성화 (RAM 16GB+)" } else { "비활성화 (RAM 16GB 미만)" }

Write-Host "  - 목표: $cacheDesc" -ForegroundColor White
Set-RegistryIfDifferent -Path $memMgmtPath -Name "LargeSystemCache" -Value $targetCache -StepName $cacheStep -Description "LargeSystemCache"


# [7/9] 메모리 압축 설정
Write-Host ""
Write-Host "[7/$totalSteps] 메모리 압축 설정 중..." -ForegroundColor Yellow

$compressionStep = "메모리 압축"

try {
    $memCompression = Get-MMAgent
    $currentCompression = $memCompression.MemoryCompression

    if ($totalRAM -ge 32) {
        # 32GB+: 비활성화
        if ($currentCompression) {
            Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            Write-Host "  - 메모리 압축: True → False (적용됨, RAM 32GB+)" -ForegroundColor Green
            Write-OptLog -Step $compressionStep -Status "적용됨" -Message "비활성화됨" -PreviousValue "True" -NewValue "False"
        } else {
            Write-Host "  - 메모리 압축: 이미 비활성화 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $compressionStep -Status "스킵됨" -Message "이미 비활성화"
        }
    } else {
        # 32GB 미만: 활성화
        if (-not $currentCompression) {
            Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
            Write-Host "  - 메모리 압축: False → True (적용됨, RAM 32GB 미만)" -ForegroundColor Green
            Write-OptLog -Step $compressionStep -Status "적용됨" -Message "활성화됨" -PreviousValue "False" -NewValue "True"
        } else {
            Write-Host "  - 메모리 압축: 이미 활성화 (스킵)" -ForegroundColor Gray
            Write-OptLog -Step $compressionStep -Status "스킵됨" -Message "이미 활성화"
        }
    }
} catch {
    Write-Host "  - 메모리 압축 설정 실패 (MMAgent 미지원)" -ForegroundColor Yellow
    Write-OptLog -Step $compressionStep -Status "실패" -Message "MMAgent 미지원: $_"
}


# [8/9] 추가 메모리 설정
Write-Host ""
Write-Host "[8/$totalSteps] 추가 메모리 설정 중..." -ForegroundColor Yellow

$additionalStep = "추가 설정"

# ClearPageFileAtShutdown
Set-RegistryIfDifferent -Path $memMgmtPath -Name "ClearPageFileAtShutdown" -Value 0 -StepName $additionalStep -Description "ClearPageFileAtShutdown (빠른 종료)"

# IoPageLockLimit
if ($totalRAM -ge 32) {
    $ioLimit = 1073741824  # 1GB
    $ioLimitDisplay = "1GB"
} elseif ($totalRAM -ge 16) {
    $ioLimit = 536870912  # 512MB
    $ioLimitDisplay = "512MB"
} elseif ($totalRAM -ge 8) {
    $ioLimit = 268435456  # 256MB
    $ioLimitDisplay = "256MB"
} else {
    $ioLimit = 0
    $ioLimitDisplay = "자동"
}
Set-RegistryIfDifferent -Path $memMgmtPath -Name "IoPageLockLimit" -Value $ioLimit -StepName $additionalStep -Description "IoPageLockLimit ($ioLimitDisplay)"

# SessionPoolSize
Set-RegistryIfDifferent -Path $memMgmtPath -Name "SessionPoolSize" -Value 48 -StepName $additionalStep -Description "SessionPoolSize"


# [9/9] NDU 메모리 누수 해결
Write-Host ""
Write-Host "[9/$totalSteps] NDU 메모리 누수 해결 중..." -ForegroundColor Yellow

$nduStep = "NDU 서비스"
$nduPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Ndu"

if (Test-Path $nduPath) {
    Set-RegistryIfDifferent -Path $nduPath -Name "Start" -Value 4 -StepName $nduStep -Description "NDU 서비스 (4=비활성화)"
} else {
    Write-Host "  - NDU 서비스: 경로 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Step $nduStep -Status "스킵됨" -Message "경로 없음"
}

# NonPagedPoolSize 확인
$currentNonPagedPool = (Get-ItemProperty -Path $memMgmtPath -Name "NonPagedPoolSize" -ErrorAction SilentlyContinue).NonPagedPoolSize
if ($null -ne $currentNonPagedPool -and $currentNonPagedPool -ne 0) {
    Set-RegistryIfDifferent -Path $memMgmtPath -Name "NonPagedPoolSize" -Value 0 -StepName $nduStep -Description "NonPagedPoolSize (시스템 자동)"
}


# ===== 로그 저장 =====
Save-OptLog -SystemInfo $systemInfo -DriveInfo $driveInfo


# ===== 완료 메시지 =====
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "메모리 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $global:AppliedCount 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $global:SkippedCount 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $global:FailedCount 개" -ForegroundColor $(if ($global:FailedCount -gt 0) { "Red" } else { "Gray" })
Write-Host ""
Write-Host "드라이브 기반 설정:" -ForegroundColor Yellow
Write-Host "  - 시스템 드라이브: $driveBusType ($driveMediaType)" -ForegroundColor White
Write-Host "  - SysMain: $(if ($isNVMe -or $isSSD) { '비활성화' } else { '활성화 유지' })" -ForegroundColor White
Write-Host "  - Prefetch: $prefetchDesc" -ForegroundColor White
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
