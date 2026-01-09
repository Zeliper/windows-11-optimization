# Findings - 스킵/Override 기능 추가 작업

## 요구사항
- 이미 한 번 실행한 OS에서도 모든 스크립트가 각각 적용 여부 체크 필요
- 이미 적용된 설정은 스킵
- 사용자가 원하면 Override(강제 재적용) 가능해야 함

## 참조 모델 분석 (018.memory_optimization.ps1)

### 1. 로깅 시스템
```powershell
$global:LogFilePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $logFileName
$global:LogEntries = [System.Collections.ArrayList]@()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0
```

### 2. Set-RegistryIfDifferent 함수
- 경로 자동 생성 `New-Item -Path $Path -Force`
- 현재 값과 목표 값 비교
- 같으면 Gray로 "(스킵)" 출력
- 다르면 Green으로 "(적용됨)" 출력
- Write-OptLog 호출로 로그 기록
- return $true/$false로 변경 여부 반환

### 3. Set-ServiceIfDifferent 함수
- 서비스 존재 여부 확인
- StartupType 비교
- 변경 시 서비스 중지 옵션 ($StopService)

### 4. Summary 출력
```
Summary:
  - 적용됨: X 개 (Green)
  - 스킵됨: Y 개 (Gray) - (이미 최적 설정)
  - 실패: Z 개 (Red)

로그 파일: C:\Users\User\Documents\Windows11Optimizer_XXX_YYYYMMDD_HHMMSS.log
```

## 스크립트별 체크 항목 분류

| 스크립트 | 주요 체크 유형 | 특이사항 |
|----------|---------------|----------|
| 001.disable_update | 레지스트리 | 간단 |
| 002.power_network | 레지스트리, powercfg | powercfg -duplicatescheme 특수 처리 |
| 003.defender_onedrive | 서비스, 방화벽, 예약작업, 파일 | 복잡 |
| 004.taskbar | 레지스트리 | 간단 |
| 005.bloatware | AppxPackage | Get-AppxPackage로 존재 여부 체크 |
| 006.software_install | 파일 존재 | Test-Path로 EXE 존재 체크 |
| 007.openssh_rsync | WindowsCapability, 서비스 | Get-WindowsCapability |
| 008.common_optimization | 레지스트리, 서비스 | 많은 항목 |
| 009.gaming_optimization | 레지스트리, bcdedit | bcdedit 특수 처리 |
| 010.game_server | 레지스트리, 서비스 | 네트워크 설정 |
| 011.web_server | WindowsCapability, IIS | IIS 설정 |
| 012.ai_features | 레지스트리, 예약작업 | 예약작업 체크 |
| 013.privacy_optimization | 레지스트리 | 많은 항목 |
| 014.storage_optimization | 레지스트리 | Storage Sense |
| 015.startup_optimization | 레지스트리 | 시작 최적화 |
| 016.accessibility_cleanup | 레지스트리 | 접근성 설정 |
| 017.mouse_input_optimization | 레지스트리 | 입력 설정 |
| 019.search_optimization | 레지스트리, 서비스 | WSearch 서비스 |
| 020.registry_tweaks | 레지스트리 | 간단 |
| 021.ntfs_ssd_optimization | fsutil, 레지스트리 | fsutil 특수 처리 |

## 기술적 결정사항

### 1. 공통 함수 인라인 포함
**이유:** `irm | iex` 실행 시 외부 모듈 로드 불가
**해결:** 각 스크립트에 공통 함수 직접 포함

### 2. ForceOverride 플래그
```powershell
if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

# Set-RegistryIfDifferent에서
if (-not $global:ForceOverride -and $currentValue -eq $Value) {
    # 스킵
}
```

### 3. 로그 파일 경로 및 형식
**경로:** `%USERPROFILE%\Documents\windows11-optimization-logs`
- 디렉토리가 없을 경우 자동 생성

**파일명:** `Windows11Optimizer_{스크립트번호}_{YYYYMMDD_HHmmss}.log`
예: `Windows11Optimizer_001_20250109_153045.log`

**구현 코드:**
```powershell
$logFileName = "Windows11Optimizer_XXX_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir $logFileName
```

### 4. 특수 체크 함수 필요

#### Remove-AppxPackageIfExists (005용)
```powershell
function Remove-AppxPackageIfExists {
    param([string]$PackageName, [string]$StepName)
    $package = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
    if (-not $package) {
        Write-Host "  - $PackageName : 이미 제거됨 (스킵)" -ForegroundColor Gray
        return $false
    }
    # 제거 로직
}
```

#### Test-SoftwareInstalled (006용)
```powershell
function Test-SoftwareInstalled {
    param([string]$ExePath, [string]$Name)
    if (Test-Path $ExePath) {
        Write-Host "  - $Name : 이미 설치됨 (스킵)" -ForegroundColor Gray
        return $true
    }
    return $false
}
```

#### Disable-ScheduledTaskIfEnabled (012용)
```powershell
function Disable-ScheduledTaskIfEnabled {
    param([string]$TaskPath, [string]$TaskName, [string]$StepName)
    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) {
        # 작업 없음
    } elseif ($task.State -eq "Disabled") {
        # 이미 비활성화
    } else {
        # 비활성화 수행
    }
}
```

## 발견된 이슈

| 이슈 | 해결 방안 |
|------|----------|
| irm \| iex 시 외부 모듈 불가 | 인라인 포함 |
| 방화벽 상태 체크 | Get-NetFirewallProfile |
| bcdedit 값 체크 | bcdedit /enum 파싱 |
| fsutil 값 체크 | fsutil behavior query 파싱 |

### 5. Set-FsutilIfDifferent 함수 (021용)
```powershell
function Set-FsutilIfDifferent {
    param(
        [string]$BehaviorName,
        [string]$TargetValue,
        [string]$StepName
    )
    $queryResult = fsutil behavior query $BehaviorName 2>&1
    $currentValue = if ($queryResult -match "=\s*(\d+)") { $matches[1] } else { "Unknown" }
    if (-not $global:ForceOverride -and $currentValue -eq $TargetValue) {
        # 스킵
    } else {
        fsutil behavior set $BehaviorName $TargetValue 2>&1
        # 적용됨
    }
}
```

---
*Updated: 2026-01-09*
