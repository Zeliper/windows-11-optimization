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

Write-Host "=== Windows 11 NTFS/SSD 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "NTFS 파일 시스템 최적화, SSD 성능 향상, Native NVMe 드라이버 활성화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 6


# [1/6] NTFS 8.3 파일명 생성 비활성화
Write-Host "[1/$totalSteps] NTFS 8.3 파일명 생성 비활성화 중..." -ForegroundColor Yellow

# 8.3 파일명: DOS 호환을 위한 짧은 파일명 (PROGRA~1 등)
# 비활성화하면 파일 생성 시 I/O 감소, SSD 성능 향상
$fileSystemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

# NtfsDisable8dot3NameCreation = 1 (새 파일에 대해 비활성화)
# 0 = 활성화 (기본값)
# 1 = 모든 볼륨에서 비활성화
# 2 = 볼륨별 설정
# 3 = 시스템 볼륨 제외하고 비활성화
Set-ItemProperty -Path $fileSystemPath -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord
Write-Host "  - NtfsDisable8dot3NameCreation: 1 (8.3 파일명 비활성화)" -ForegroundColor Green

# fsutil 명령으로도 설정 (즉시 적용)
try {
    $result = fsutil behavior set disable8dot3 1 2>&1
    Write-Host "  - fsutil: 8.3 파일명 생성 비활성화 완료" -ForegroundColor Green
} catch {
    Write-Host "  - fsutil 명령 실행 실패: $_" -ForegroundColor Red
}


# [2/6] NTFS Last Access Time 업데이트 비활성화
Write-Host ""
Write-Host "[2/$totalSteps] NTFS Last Access Time 업데이트 비활성화 중..." -ForegroundColor Yellow

# Last Access Time: 파일 읽기 시 마지막 접근 시간 업데이트
# 비활성화하면 파일 읽기 시 쓰기 I/O 방지, SSD 성능 향상
# 값: 0x80000001 = User Managed, Disabled
Set-ItemProperty -Path $fileSystemPath -Name "NtfsDisableLastAccessUpdate" -Value 0x80000001 -Type DWord
Write-Host "  - NtfsDisableLastAccessUpdate: 0x80000001 (User Managed, Disabled)" -ForegroundColor Green

# fsutil 명령으로도 설정
try {
    $result = fsutil behavior set disablelastaccess 1 2>&1
    Write-Host "  - fsutil: Last Access Time 업데이트 비활성화 완료" -ForegroundColor Green
} catch {
    Write-Host "  - fsutil 명령 실행 실패: $_" -ForegroundColor Red
}


# [3/6] TRIM 상태 확인 및 최적화
Write-Host ""
Write-Host "[3/$totalSteps] TRIM 상태 확인 및 최적화 중..." -ForegroundColor Yellow

# TRIM: SSD에서 삭제된 블록을 드라이브에 알려주는 기능
# DisableDeleteNotify = 0 이면 TRIM 활성화 (정상)
try {
    $trimStatus = fsutil behavior query disabledeletenotify 2>&1
    if ($trimStatus -match "DisableDeleteNotify\s*=\s*0" -or $trimStatus -match "NTFS DisableDeleteNotify\s*=\s*0") {
        Write-Host "  - TRIM: 활성화됨 (정상)" -ForegroundColor Green
    } elseif ($trimStatus -match "DisableDeleteNotify\s*=\s*1" -or $trimStatus -match "NTFS DisableDeleteNotify\s*=\s*1") {
        Write-Host "  - TRIM: 비활성화됨 (문제 발견)" -ForegroundColor Red
        Write-Host "  - TRIM 활성화 시도 중..." -ForegroundColor Yellow
        fsutil behavior set disabledeletenotify NTFS 0 2>&1 | Out-Null
        Write-Host "  - TRIM: 활성화 완료" -ForegroundColor Green
    } else {
        Write-Host "  - TRIM 상태: $trimStatus" -ForegroundColor Gray
    }
} catch {
    Write-Host "  - TRIM 상태 확인 실패: $_" -ForegroundColor Red
}


# [4/6] Native NVMe 드라이버 활성화 (Windows 11 25H2)
Write-Host ""
Write-Host "[4/$totalSteps] Native NVMe 드라이버 활성화 중..." -ForegroundColor Yellow

# Windows 11 25H2 Native NVMe 드라이버
# Windows Server 2025에서 도입된 기능으로 최대 85% IOPS 향상
# 레지스트리 Feature Flag로 활성화
$featurePath = "HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides"

# 레지스트리 경로 생성
if (!(Test-Path $featurePath)) {
    New-Item -Path $featurePath -Force | Out-Null
    Write-Host "  - FeatureManagement\Overrides 키 생성" -ForegroundColor Gray
}

# Feature ID 735209102 (Native NVMe Driver)
Set-ItemProperty -Path $featurePath -Name "735209102" -Value 1 -Type DWord
Write-Host "  - Feature 735209102: 활성화" -ForegroundColor Green

# Feature ID 156965516 (Native NVMe Driver - 추가)
Set-ItemProperty -Path $featurePath -Name "156965516" -Value 1 -Type DWord
Write-Host "  - Feature 156965516: 활성화" -ForegroundColor Green

Write-Host "  - Native NVMe 드라이버: 활성화됨 (최대 85% IOPS 향상 가능)" -ForegroundColor Green
Write-Host "  - 주의: Microsoft 기본 NVMe 드라이버 사용 시에만 적용됨" -ForegroundColor Yellow
Write-Host "  - 주의: Samsung, WD 등 제조사 드라이버 사용 시 효과 없음" -ForegroundColor Yellow


# [5/6] SSD 드라이브 감지 및 최적화
Write-Host ""
Write-Host "[5/$totalSteps] SSD 드라이브 감지 및 최적화 중..." -ForegroundColor Yellow

# SSD 드라이브 감지
$physicalDisks = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" -or $_.MediaType -eq "NVMe" }

if ($physicalDisks.Count -gt 0) {
    Write-Host "  - 감지된 SSD 드라이브:" -ForegroundColor White
    foreach ($disk in $physicalDisks) {
        Write-Host "    - $($disk.FriendlyName) ($($disk.MediaType), $([math]::Round($disk.Size / 1GB, 0)) GB)" -ForegroundColor Gray
    }

    # SSD Defrag 예약 작업 최적화
    # SSD는 자동 TRIM으로 충분, 조각 모음 불필요
    try {
        $defragTask = Get-ScheduledTask -TaskName "ScheduledDefrag" -ErrorAction SilentlyContinue
        if ($defragTask) {
            # 예약 작업 상태 확인
            Write-Host "  - 예약된 디스크 최적화 작업: 존재함" -ForegroundColor Gray
            Write-Host "    (Windows는 SSD에 대해 자동으로 TRIM만 수행)" -ForegroundColor Gray
        }
    } catch {
        Write-Host "  - 예약된 디스크 최적화 작업 확인 실패" -ForegroundColor Gray
    }

    # Prefetch 설정 (SSD에서는 비활성화 권장하지 않음)
    # Windows 10 이후 SSD에서도 Prefetch 효과 있음
    $prefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
    $currentValue = (Get-ItemProperty -Path $prefetchPath -Name "EnablePrefetcher" -ErrorAction SilentlyContinue).EnablePrefetcher
    if ($currentValue) {
        Write-Host "  - Prefetch 현재 설정: $currentValue (3 = 모두 활성화, 권장)" -ForegroundColor Gray
    }

} else {
    Write-Host "  - SSD 드라이브를 찾을 수 없습니다." -ForegroundColor Gray
    Write-Host "    (HDD만 있거나 드라이브 타입을 감지할 수 없음)" -ForegroundColor Gray
}

# NVMe 드라이버 확인
Write-Host ""
Write-Host "  NVMe 드라이버 상태 확인 중..." -ForegroundColor White
try {
    $nvmeControllers = Get-PnpDevice -Class "SCSIAdapter" -Status OK -ErrorAction SilentlyContinue |
                       Where-Object { $_.FriendlyName -match "NVMe" }

    if ($nvmeControllers.Count -gt 0) {
        foreach ($controller in $nvmeControllers) {
            $driver = Get-PnpDeviceProperty -InstanceId $controller.InstanceId -KeyName "DEVPKEY_Device_DriverInfPath" -ErrorAction SilentlyContinue
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

# 현재 NTFS 설정 확인
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


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NTFS/SSD 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - NTFS 8.3 파일명 생성: 비활성화 (SSD I/O 감소)" -ForegroundColor White
Write-Host "  - NTFS Last Access Time: 비활성화 (파일 읽기 시 쓰기 방지)" -ForegroundColor White
Write-Host "  - TRIM: 활성화 확인 (SSD 성능 유지)" -ForegroundColor White
Write-Host "  - Native NVMe 드라이버: 활성화 (최대 85% IOPS 향상)" -ForegroundColor White
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
