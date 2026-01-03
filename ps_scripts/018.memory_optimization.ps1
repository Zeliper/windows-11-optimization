# Windows 11 메모리 최적화 스크립트
# 페이지 파일 최적화, 시스템 캐시, 메모리 압축, NDU 메모리 누수 해결
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

Write-Host "=== Windows 11 메모리 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "페이지 파일 최적화, 시스템 캐시, 메모리 압축, NDU 메모리 누수 해결을 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 7


# [1/7] 시스템 메모리 분석
Write-Host "[1/$totalSteps] 시스템 메모리 분석 중..." -ForegroundColor Yellow

$totalRAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
$availableRAM = [math]::Round((Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
$usedRAM = $totalRAM - $availableRAM

Write-Host "  - 총 RAM: $totalRAM GB" -ForegroundColor White
Write-Host "  - 사용 가능 RAM: $availableRAM GB" -ForegroundColor White
Write-Host "  - 사용 중: $([math]::Round($usedRAM, 1)) GB ($([math]::Round(($usedRAM / $totalRAM) * 100, 1))%)" -ForegroundColor White


# [2/7] 페이지 파일 최적화 (RAM 용량별 자동 계산)
Write-Host ""
Write-Host "[2/$totalSteps] 페이지 파일 최적화 중..." -ForegroundColor Yellow

# 페이지 파일 권장 크기 계산
# RAM 8GB 이하: RAM의 1.5~3배
# RAM 16GB: RAM의 1~2배
# RAM 32GB+: 16~24GB 고정
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
    # 32GB 이상: 고정 16~24GB
    $recommendedMinGB = 16
    $recommendedMaxGB = 24
}

$recommendedMinMB = $recommendedMinGB * 1024
$recommendedMaxMB = $recommendedMaxGB * 1024

# 현재 페이지 파일 설정 확인
$pageFile = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue
$autoManaged = (Get-CimInstance -ClassName Win32_ComputerSystem).AutomaticManagedPagefile

if ($autoManaged) {
    Write-Host "  - 현재 설정: 자동 관리" -ForegroundColor White
} elseif ($pageFile) {
    Write-Host "  - 현재 페이지 파일: $($pageFile.Name)" -ForegroundColor White
    Write-Host "    초기 크기: $($pageFile.InitialSize) MB, 최대 크기: $($pageFile.MaximumSize) MB" -ForegroundColor Gray
} else {
    Write-Host "  - 현재 페이지 파일: 감지되지 않음" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  RAM $totalRAM GB 기준 권장 설정:" -ForegroundColor Yellow
Write-Host "    - 초기 크기: $recommendedMinMB MB ($recommendedMinGB GB)" -ForegroundColor White
Write-Host "    - 최대 크기: $recommendedMaxMB MB ($recommendedMaxGB GB)" -ForegroundColor White

# 페이지 파일 최적화 옵션
$optimizePageFile = "Y"
if (-not $global:OrchestrateMode) {
    Write-Host ""
    $optimizePageFile = Read-Host "페이지 파일을 권장 설정으로 변경하시겠습니까? (Y/N, 기본값: Y)"
    if ([string]::IsNullOrEmpty($optimizePageFile)) { $optimizePageFile = "Y" }
}

if ($optimizePageFile -eq "Y" -or $optimizePageFile -eq "y") {
    try {
        # 자동 관리 비활성화
        $compSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $compSystem | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }
        Write-Host "  - 페이지 파일 자동 관리 비활성화" -ForegroundColor Green

        # 기존 페이지 파일 제거
        Get-CimInstance -ClassName Win32_PageFileSetting | Remove-CimInstance -ErrorAction SilentlyContinue

        # 새 페이지 파일 설정 (시스템 드라이브에 고정 크기)
        $pageFilePath = "$env:SystemDrive\pagefile.sys"
        New-CimInstance -ClassName Win32_PageFileSetting -Property @{
            Name = $pageFilePath
            InitialSize = $recommendedMinMB
            MaximumSize = $recommendedMaxMB
        } -ErrorAction SilentlyContinue

        Write-Host "  - 페이지 파일 설정: $recommendedMinMB ~ $recommendedMaxMB MB" -ForegroundColor Green
        Write-Host "  - 재부팅 후 적용됩니다" -ForegroundColor Yellow
    } catch {
        Write-Host "  - 페이지 파일 설정 변경 실패: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  - 페이지 파일 설정 유지" -ForegroundColor Gray
}


# [3/7] 시스템 캐시 크기 최적화 (LargeSystemCache)
Write-Host ""
Write-Host "[3/$totalSteps] 시스템 캐시 크기 최적화 중..." -ForegroundColor Yellow

$memMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

if ($totalRAM -ge 16) {
    # 16GB 이상: 서버 워크로드/대용량 파일 처리에 적합
    Set-ItemProperty -Path $memMgmtPath -Name "LargeSystemCache" -Value 1 -Type DWord
    Write-Host "  - LargeSystemCache: 활성화 (RAM 16GB+, 대용량 파일 처리 최적화)" -ForegroundColor Green
} else {
    # 16GB 미만: 데스크탑 워크로드에 적합
    Set-ItemProperty -Path $memMgmtPath -Name "LargeSystemCache" -Value 0 -Type DWord
    Write-Host "  - LargeSystemCache: 비활성화 (RAM 16GB 미만, 앱 성능 우선)" -ForegroundColor Green
}


# [4/7] 메모리 압축 설정
Write-Host ""
Write-Host "[4/$totalSteps] 메모리 압축 설정 중..." -ForegroundColor Yellow

# 현재 메모리 압축 상태 확인
try {
    $memCompression = Get-MMAgent
    $currentCompression = $memCompression.MemoryCompression
    Write-Host "  - 현재 메모리 압축 상태: $currentCompression" -ForegroundColor White

    # RAM 32GB 이상: 메모리 압축 비활성화 (CPU 오버헤드 감소)
    # RAM 32GB 미만: 메모리 압축 활성화 (메모리 효율)
    if ($totalRAM -ge 32) {
        Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
        Write-Host "  - 메모리 압축: 비활성화 (RAM 32GB+, CPU 오버헤드 감소)" -ForegroundColor Green
    } else {
        Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
        Write-Host "  - 메모리 압축: 활성화 (RAM 32GB 미만, 메모리 효율 최적화)" -ForegroundColor Green
    }
} catch {
    Write-Host "  - 메모리 압축 설정 확인 실패 (MMAgent 미지원)" -ForegroundColor Yellow
}


# [5/7] ClearPageFileAtShutdown 설정
Write-Host ""
Write-Host "[5/$totalSteps] 페이지 파일 종료 시 정리 설정 중..." -ForegroundColor Yellow

# 0 = 종료 시 페이지 파일 삭제 안 함 (빠른 종료)
# 1 = 종료 시 페이지 파일 삭제 (보안 강화, 느린 종료)
Set-ItemProperty -Path $memMgmtPath -Name "ClearPageFileAtShutdown" -Value 0 -Type DWord
Write-Host "  - ClearPageFileAtShutdown: 비활성화 (빠른 종료)" -ForegroundColor Green
Write-Host "    보안 필요 시 1로 변경 (종료 시 페이지 파일 삭제)" -ForegroundColor Gray


# [6/7] IoPageLockLimit 설정
Write-Host ""
Write-Host "[6/$totalSteps] I/O 페이지 잠금 제한 설정 중..." -ForegroundColor Yellow

# IoPageLockLimit: I/O 작업에 잠길 수 있는 최대 메모리 바이트
# 0 = 시스템 자동 (기본값)
# 고성능 시스템: RAM의 약 10% 권장 (바이트 단위)
if ($totalRAM -ge 32) {
    # 32GB+ : 1GB 잠금 허용
    $ioLimit = 1073741824  # 1GB in bytes
    $ioLimitDisplay = "1 GB"
} elseif ($totalRAM -ge 16) {
    # 16GB+ : 512MB 잠금 허용
    $ioLimit = 536870912  # 512MB in bytes
    $ioLimitDisplay = "512 MB"
} elseif ($totalRAM -ge 8) {
    # 8GB+ : 256MB 잠금 허용
    $ioLimit = 268435456  # 256MB in bytes
    $ioLimitDisplay = "256 MB"
} else {
    # 그 외: 시스템 기본값
    $ioLimit = 0
    $ioLimitDisplay = "시스템 자동"
}

Set-ItemProperty -Path $memMgmtPath -Name "IoPageLockLimit" -Value $ioLimit -Type DWord
Write-Host "  - IoPageLockLimit: $ioLimitDisplay (RAM $totalRAM GB 기준)" -ForegroundColor Green


# [7/7] NDU (Network Data Usage) 메모리 누수 해결
Write-Host ""
Write-Host "[7/$totalSteps] NDU 메모리 누수 해결 중..." -ForegroundColor Yellow

# NDU 서비스는 네트워크 사용량 모니터링 기능
# 알려진 메모리 누수 이슈가 있어 비활성화 권장
$nduPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Ndu"
if (Test-Path $nduPath) {
    $currentStart = (Get-ItemProperty -Path $nduPath -Name "Start" -ErrorAction SilentlyContinue).Start

    # Start: 2 = 자동, 3 = 수동, 4 = 비활성화
    if ($currentStart -ne 4) {
        Set-ItemProperty -Path $nduPath -Name "Start" -Value 4 -Type DWord
        Write-Host "  - NDU 서비스: 비활성화 (메모리 누수 방지)" -ForegroundColor Green
    } else {
        Write-Host "  - NDU 서비스: 이미 비활성화됨" -ForegroundColor Gray
    }
} else {
    Write-Host "  - NDU 서비스 경로를 찾을 수 없음" -ForegroundColor Yellow
}

# NonPagedPool 설정 (시스템 자동 관리)
$currentNonPagedPool = (Get-ItemProperty -Path $memMgmtPath -Name "NonPagedPoolSize" -ErrorAction SilentlyContinue).NonPagedPoolSize
if ($null -eq $currentNonPagedPool -or $currentNonPagedPool -eq 0) {
    Write-Host "  - NonPagedPoolSize: 시스템 자동 관리 (기본값)" -ForegroundColor Gray
} else {
    Set-ItemProperty -Path $memMgmtPath -Name "NonPagedPoolSize" -Value 0 -Type DWord
    Write-Host "  - NonPagedPoolSize: 시스템 자동 관리로 복원" -ForegroundColor Green
}

# 세션 풀 설정 최적화
$sessionPoolPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-ItemProperty -Path $sessionPoolPath -Name "SessionPoolSize" -Value 48 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - SessionPoolSize: 48 (세션 메모리 최적화)" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "메모리 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 페이지 파일: RAM $totalRAM GB 기준 최적화" -ForegroundColor White
Write-Host "  - 시스템 캐시: $(if ($totalRAM -ge 16) { '활성화' } else { '비활성화' })" -ForegroundColor White
Write-Host "  - 메모리 압축: $(if ($totalRAM -ge 32) { '비활성화 (CPU 부하 감소)' } else { '활성화' })" -ForegroundColor White
Write-Host "  - 페이지 파일 종료 시 삭제: 비활성화 (빠른 종료)" -ForegroundColor White
Write-Host "  - I/O 페이지 잠금: $ioLimitDisplay" -ForegroundColor White
Write-Host "  - NDU 서비스: 비활성화 (메모리 누수 방지)" -ForegroundColor White
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
