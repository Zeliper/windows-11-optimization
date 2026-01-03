# Windows 11 Windows Search 최적화 스크립트
# 인덱싱 최적화, 클라우드 검색 비활성화, WSearch 서비스 설정
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

Write-Host "=== Windows 11 Windows Search 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "인덱싱 최적화, 클라우드 검색 비활성화, WSearch 서비스 설정을 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 6


# [1/6] Windows Search 현재 상태 분석
Write-Host "[1/$totalSteps] Windows Search 현재 상태 분석 중..." -ForegroundColor Yellow

$wsearchService = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
if ($wsearchService) {
    Write-Host "  - WSearch 서비스 상태: $($wsearchService.Status)" -ForegroundColor White
    Write-Host "  - 시작 유형: $($wsearchService.StartType)" -ForegroundColor White
} else {
    Write-Host "  - WSearch 서비스를 찾을 수 없습니다" -ForegroundColor Yellow
}

# 인덱스 크기 확인
$indexPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows"
if (Test-Path $indexPath) {
    try {
        $indexSize = [math]::Round((Get-ChildItem -Path $indexPath -Recurse -ErrorAction SilentlyContinue |
                                    Measure-Object -Property Length -Sum).Sum / 1MB, 2)
        Write-Host "  - 현재 인덱스 크기: $indexSize MB" -ForegroundColor White
    } catch {
        Write-Host "  - 인덱스 크기 확인 실패" -ForegroundColor Yellow
    }
} else {
    Write-Host "  - 인덱스 폴더를 찾을 수 없습니다" -ForegroundColor Gray
}


# [2/6] 인덱싱 정책 최적화
Write-Host ""
Write-Host "[2/$totalSteps] 인덱싱 정책 최적화 중..." -ForegroundColor Yellow

$searchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (!(Test-Path $searchPolicyPath)) {
    New-Item -Path $searchPolicyPath -Force | Out-Null
}

# 디스크 공간 부족 시 인덱싱 중단 (5GB 미만)
Set-ItemProperty -Path $searchPolicyPath -Name "PreventIndexingLowDiskSpaceMB" -Value 5000 -Type DWord
Write-Host "  - 디스크 공간 5GB 미만 시 인덱싱 중단 설정" -ForegroundColor Green

# 암호화된 파일 인덱싱 비활성화 (성능 향상)
Set-ItemProperty -Path $searchPolicyPath -Name "PreventIndexingEncryptedStores" -Value 1 -Type DWord
Write-Host "  - 암호화된 파일 인덱싱: 비활성화" -ForegroundColor Green

# Outlook 오프라인 파일 인덱싱 비활성화
Set-ItemProperty -Path $searchPolicyPath -Name "PreventIndexingOutlook" -Value 1 -Type DWord
Write-Host "  - Outlook 오프라인 파일 인덱싱: 비활성화" -ForegroundColor Green


# [3/6] 클라우드 검색 및 검색 기록 비활성화
Write-Host ""
Write-Host "[3/$totalSteps] 클라우드 검색 및 검색 기록 비활성화 중..." -ForegroundColor Yellow

$searchSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
if (!(Test-Path $searchSettingsPath)) {
    New-Item -Path $searchSettingsPath -Force | Out-Null
}

# 검색 기록 비활성화
Set-ItemProperty -Path $searchSettingsPath -Name "IsDeviceSearchHistoryEnabled" -Value 0 -Type DWord
Write-Host "  - 장치 검색 기록: 비활성화" -ForegroundColor Green

# Azure AD 클라우드 검색 비활성화
Set-ItemProperty -Path $searchSettingsPath -Name "IsAADCloudSearchEnabled" -Value 0 -Type DWord
Write-Host "  - Azure AD 클라우드 검색: 비활성화" -ForegroundColor Green

# Microsoft 계정 클라우드 검색 비활성화
Set-ItemProperty -Path $searchSettingsPath -Name "IsMSACloudSearchEnabled" -Value 0 -Type DWord
Write-Host "  - Microsoft 계정 클라우드 검색: 비활성화" -ForegroundColor Green

# Safe Search 모드 설정 (선택적)
$safeSearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
Set-ItemProperty -Path $safeSearchPath -Name "SafeSearchMode" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Safe Search: 필터링 비활성화" -ForegroundColor Green


# [4/6] 백그라운드 인덱싱 활동 관리
Write-Host ""
Write-Host "[4/$totalSteps] 백그라운드 인덱싱 활동 관리 중..." -ForegroundColor Yellow

# 배터리 모드에서 인덱싱 비활성화
Set-ItemProperty -Path $searchPolicyPath -Name "PreventIndexOnBattery" -Value 1 -Type DWord
Write-Host "  - 배터리 모드 인덱싱: 비활성화" -ForegroundColor Green

# 시스템 부하 시 인덱싱 백오프 활성화
Set-ItemProperty -Path $searchPolicyPath -Name "DisableBackOff" -Value 0 -Type DWord
Write-Host "  - 시스템 부하 시 인덱싱 백오프: 활성화" -ForegroundColor Green

# 이동식 드라이브 인덱싱 비활성화
Set-ItemProperty -Path $searchPolicyPath -Name "DisableRemovableDriveIndexing" -Value 1 -Type DWord
Write-Host "  - 이동식 드라이브 인덱싱: 비활성화" -ForegroundColor Green

# 네트워크 위치 인덱싱 비활성화
Set-ItemProperty -Path $searchPolicyPath -Name "PreventIndexingNetworkDrives" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 네트워크 드라이브 인덱싱: 비활성화" -ForegroundColor Green


# [5/6] WSearch 서비스 최적화
Write-Host ""
Write-Host "[5/$totalSteps] WSearch 서비스 최적화 중..." -ForegroundColor Yellow

# 서비스 시작 유형 선택
$wsearchChoice = "1"
if (-not $global:OrchestrateMode) {
    Write-Host ""
    Write-Host "  Windows Search 서비스 옵션:" -ForegroundColor Cyan
    Write-Host "  [1] 수동 시작 (권장 - 검색 시에만 활성화)" -ForegroundColor White
    Write-Host "  [2] 자동 시작 (기본값 유지)" -ForegroundColor White
    Write-Host "  [3] 비활성화 (검색 기능 사용 안 함)" -ForegroundColor White
    $wsearchChoice = Read-Host "선택 (1-3, 기본값: 1)"
    if ([string]::IsNullOrEmpty($wsearchChoice)) { $wsearchChoice = "1" }
}

switch ($wsearchChoice) {
    "2" {
        Set-Service -Name "WSearch" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
        Write-Host "  - WSearch 서비스: 자동 시작" -ForegroundColor Green
    }
    "3" {
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  - WSearch 서비스: 비활성화" -ForegroundColor Yellow
        Write-Host "    주의: 파일 탐색기 및 시작 메뉴 검색이 작동하지 않습니다" -ForegroundColor Red
    }
    default {
        Set-Service -Name "WSearch" -StartupType Manual -ErrorAction SilentlyContinue
        Write-Host "  - WSearch 서비스: 수동 시작 (검색 시 자동 활성화)" -ForegroundColor Green
    }
}

# SearchIndexer 프로세스 우선순위 낮춤 (레지스트리로 제어 불가, 정보 제공)
Write-Host "  - 참고: SearchIndexer.exe는 시스템 유휴 시에만 인덱싱 수행" -ForegroundColor Gray


# [6/6] 검색 인덱스 재구축 옵션
Write-Host ""
Write-Host "[6/$totalSteps] 검색 인덱스 관리..." -ForegroundColor Yellow

$rebuildIndex = "N"
if (-not $global:OrchestrateMode) {
    Write-Host ""
    Write-Host "  검색 인덱스 재구축 옵션:" -ForegroundColor Cyan
    Write-Host "  - 재구축 시 기존 인덱스가 삭제되고 새로 생성됩니다" -ForegroundColor Gray
    Write-Host "  - 완료까지 수 시간이 소요될 수 있습니다 (백그라운드 진행)" -ForegroundColor Gray
    $rebuildIndex = Read-Host "검색 인덱스를 재구축하시겠습니까? (Y/N, 기본값: N)"
}

if ($rebuildIndex -eq "Y" -or $rebuildIndex -eq "y") {
    Write-Host "  - 검색 인덱스 재구축 시작 중..." -ForegroundColor Yellow

    try {
        # 서비스 중지
        Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        # 인덱스 파일 삭제
        $indexDataPath = "$env:ProgramData\Microsoft\Search\Data\Applications\Windows"
        if (Test-Path $indexDataPath) {
            Remove-Item -Path "$indexDataPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  - 기존 인덱스 파일 삭제 완료" -ForegroundColor Green
        }

        # 서비스 재시작 (수동이 아닌 경우)
        if ($wsearchChoice -ne "3") {
            Start-Service -Name "WSearch" -ErrorAction SilentlyContinue
            Write-Host "  - WSearch 서비스 재시작됨" -ForegroundColor Green
            Write-Host "  - 인덱스 재구축이 백그라운드에서 진행됩니다" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  - 인덱스 재구축 중 오류 발생: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  - 검색 인덱스 재구축 건너뜀" -ForegroundColor Gray
}


# 추가 최적화: Cortana 검색 비활성화 (이미 다른 스크립트에서 처리될 수 있음)
$cortanaSearchPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
if (!(Test-Path $cortanaSearchPath)) {
    New-Item -Path $cortanaSearchPath -Force | Out-Null
}
Set-ItemProperty -Path $cortanaSearchPath -Name "BingSearchEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $cortanaSearchPath -Name "CortanaConsent" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Bing/Cortana 웹 검색: 비활성화" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Windows Search 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 인덱싱 정책: 디스크 5GB 미만 시 중단" -ForegroundColor White
Write-Host "  - 암호화/Outlook 파일 인덱싱: 비활성화" -ForegroundColor White
Write-Host "  - 클라우드 검색 및 검색 기록: 비활성화" -ForegroundColor White
Write-Host "  - 배터리/이동식/네트워크 드라이브 인덱싱: 비활성화" -ForegroundColor White
Write-Host "  - WSearch 서비스: $(switch($wsearchChoice) { '2' { '자동' } '3' { '비활성화' } default { '수동' } })" -ForegroundColor White
Write-Host "  - Bing/Cortana 웹 검색: 비활성화" -ForegroundColor White
Write-Host ""
Write-Host "설정은 즉시 적용됩니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 이 스크립트는 재부팅 불필요
if (-not $global:OrchestrateMode) {
    Write-Host "참고: 이 스크립트는 재부팅이 필요하지 않습니다." -ForegroundColor Gray
}
