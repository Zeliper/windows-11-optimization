# Orchestrate 연동 가이드

이 문서는 `000.orchestrate.ps1`과 개별 스크립트를 연동하는 방법을 설명합니다. 신규 스크립트를 추가하거나 기존 스크립트를 수정할 때 이 가이드를 따라 orchestrate 시스템에 등록하세요.

## 목차

1. [Orchestrate 시스템 개요](#1-orchestrate-시스템-개요)
2. [ScriptItems 배열 등록](#2-scriptitems-배열-등록)
3. [프리셋 업데이트](#3-프리셋-업데이트)
4. [ConflictGroups 설정](#4-conflictgroups-설정)
5. [RequiresReboot 판단 기준](#5-requiresreboot-판단-기준)
6. [실행 흐름 이해](#6-실행-흐름-이해)
7. [병렬 실행 메커니즘](#7-병렬-실행-메커니즘)
8. [상태 관리 시스템](#8-상태-관리-시스템)
9. [문제 해결](#9-문제-해결)

---

## 1. Orchestrate 시스템 개요

### 1.1 주요 기능

`000.orchestrate.ps1`은 다음 기능을 제공합니다:

1. **대화형 메뉴**: 체크박스 방식으로 스크립트 선택
2. **프리셋 지원**: 기본, 게임, 서버, 웹서버 프리셋
3. **병렬 실행**: 충돌 없는 스크립트를 동시 실행 (성능 최적화)
4. **충돌 회피**: ConflictGroups로 동시 실행 불가 스크립트 관리
5. **재부팅 관리**: 재부팅 필요/불필요 항목 분리 실행
6. **상태 저장**: 재부팅 후 자동 재개 기능

### 1.2 시스템 구조

```
000.orchestrate.ps1
├── ScriptItems 배열          # 스크립트 메타데이터
├── Presets 해시테이블        # 프리셋 정의
├── ConflictGroups 배열       # 충돌 관계 정의
├── 상태 관리 함수
│   ├── Save-State
│   ├── Get-SavedState
│   └── Clear-State
├── 메뉴 UI 함수
│   ├── Show-Menu
│   └── Get-UserSelection
├── 배치 생성 함수
│   └── Get-ExecutionBatches
└── 실행 함수
    ├── Invoke-OptimizationScript
    ├── Invoke-ParallelScripts
    └── Start-OptimizationProcess
```

---

## 2. ScriptItems 배열 등록

### 2.1 기본 구조

`000.orchestrate.ps1`의 23~35번째 줄에 위치한 `$global:ScriptItems` 배열:

```powershell
$global:ScriptItems = @(
    @{ Id = 1;  File = "001.disable_update.ps1";              Name = "Windows Update 수동 설정";          RequiresReboot = $false; Group = "기본" }
    @{ Id = 2;  File = "002.power_network.ps1";               Name = "전원/네트워크 최적화";               RequiresReboot = $true;  Group = "기본" }
    @{ Id = 3;  File = "003.defender_onedrive_firewall.ps1";  Name = "OneDrive/방화벽 설정";              RequiresReboot = $false; Group = "기본" }
    # ... 추가 항목
)
```

### 2.2 항목 속성 설명

| 속성 | 타입 | 설명 | 예시 |
|------|------|------|------|
| **Id** | `int` | 고유 식별 번호 (1~99) | `1`, `2`, `13` |
| **File** | `string` | 파일명 (ps_scripts/ 기준) | `"001.disable_update.ps1"` |
| **Name** | `string` | 메뉴에 표시될 이름 (32자 이하 권장) | `"Windows Update 수동 설정"` |
| **RequiresReboot** | `bool` | 재부팅 필요 여부 | `$true` / `$false` |
| **Group** | `string` | 카테고리 (태그) | `"기본"`, `"게임"`, `"서버"` |

### 2.3 신규 스크립트 추가 예시

**시나리오**: `013.custom_tweaks.ps1` (사용자 정의 최적화) 추가

```powershell
$global:ScriptItems = @(
    @{ Id = 1;  File = "001.disable_update.ps1";              Name = "Windows Update 수동 설정";          RequiresReboot = $false; Group = "기본" }
    # ... 기존 항목들 ...
    @{ Id = 12; File = "012.ai_features.ps1";                 Name = "25H2 AI 기능 비활성화";              RequiresReboot = $true;  Group = "25H2" }
    @{ Id = 13; File = "013.custom_tweaks.ps1";               Name = "사용자 정의 레지스트리 최적화";      RequiresReboot = $true;  Group = "고급" }  # ← 새로 추가
)
```

### 2.4 Id 선택 가이드

- **1~8**: 기본 최적화 (모든 프리셋에 포함 가능)
- **9~12**: 특화 최적화 (게임, 서버 등)
- **13~99**: 고급/실험적 기능
- **Id는 중복 불가**, 순차적일 필요는 없음

### 2.5 Name 작성 가이드

```powershell
# ✅ 좋은 예 (명확하고 간결)
Name = "Windows Update 수동 설정"
Name = "전원/네트워크 최적화"
Name = "게임용 최적화 (VBS/GPU)"

# ❌ 나쁜 예
Name = "최적화 스크립트 1"                           # 너무 모호함
Name = "Windows Update를 수동으로 설정하고 자동 재시작을 방지합니다"  # 너무 김 (36자)
Name = "update_disable"                             # 영어 + 축약어
```

### 2.6 Group 카테고리

| Group | 설명 | 사용 예시 |
|-------|------|----------|
| `"기본"` | 모든 PC에 적용 가능한 최적화 | 업데이트 설정, 블로트웨어 제거 |
| `"게임"` | 게임 성능 향상 관련 | VBS 비활성화, GPU 최적화 |
| `"서버"` | 서버 환경 최적화 | 게임 서버, 웹 서버 전용 |
| `"25H2"` | Windows 11 25H2 특화 | AI 기능 비활성화 |
| `"고급"` | 실험적/위험한 최적화 | 시스템 깊은 변경 |

---

## 3. 프리셋 업데이트

### 3.1 프리셋 정의 위치

`000.orchestrate.ps1`의 37~43번째 줄:

```powershell
$global:Presets = @{
    "기본"   = @(1, 2, 3, 4, 5, 6, 8, 12)       # 기본 최적화 + AI 비활성화
    "게임"   = @(1, 2, 3, 4, 5, 6, 8, 9, 12)    # 게임용 PC
    "서버"   = @(1, 2, 3, 8, 10)                # 게임 서버용
    "웹서버" = @(1, 2, 3, 8, 11)                # 웹 서버용
}
```

### 3.2 프리셋 구성 철학

| 프리셋 | 대상 사용자 | 포함 기준 |
|--------|-------------|----------|
| **기본** | 일반 PC 사용자 | 안전하고 보편적인 최적화 |
| **게임** | 게이머 | 기본 + 게임 성능 최적화 |
| **서버** | 게임 서버 관리자 | 최소한의 최적화 + 네트워크 |
| **웹서버** | 웹 개발자/서버 관리자 | 기본 + IIS 최적화 |

### 3.3 프리셋 업데이트 예시

**시나리오**: `013.custom_tweaks.ps1`을 "고급" 사용자를 위한 새 프리셋에 추가

```powershell
$global:Presets = @{
    "기본"   = @(1, 2, 3, 4, 5, 6, 8, 12)
    "게임"   = @(1, 2, 3, 4, 5, 6, 8, 9, 12)
    "서버"   = @(1, 2, 3, 8, 10)
    "웹서버" = @(1, 2, 3, 8, 11)
    "고급"   = @(1, 2, 3, 4, 5, 6, 8, 9, 12, 13)  # ← 새 프리셋 추가
}
```

**메뉴에 버튼 추가** (`000.orchestrate.ps1` 143~145번째 줄):

```powershell
Write-Host " [B] 기본 프리셋    [G] 게임 프리셋" -ForegroundColor Cyan
Write-Host " [S] 서버 프리셋    [W] 웹서버 프리셋" -ForegroundColor Cyan
Write-Host " [X] 고급 프리셋" -ForegroundColor Cyan  # ← 새 버튼
```

**선택 핸들러 추가** (`000.orchestrate.ps1` 189번째 줄 이후):

```powershell
"W" {
    $selected = @{}
    foreach ($id in $global:Presets["웹서버"]) {
        $selected[$id] = $true
    }
}
"X" {  # ← 새 핸들러
    $selected = @{}
    foreach ($id in $global:Presets["고급"]) {
        $selected[$id] = $true
    }
}
```

### 3.4 프리셋 구성 원칙

```powershell
# ✅ 좋은 구성
"기본"   = @(1, 2, 3, 4, 5, 6, 8, 12)
# → 모든 사용자에게 안전하고 유용한 항목만 포함

# ❌ 나쁜 구성
"기본"   = @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13)
# → 너무 많은 항목 (게임/서버 전용 포함)
# → 일반 사용자에게 위험할 수 있음
```

---

## 4. ConflictGroups 설정

### 4.1 ConflictGroups의 목적

병렬 실행 시 **리소스 충돌을 방지**하기 위한 설정:

- 같은 레지스트리 키를 동시에 수정하는 스크립트
- 같은 서비스를 제어하는 스크립트
- 같은 파일/폴더를 다루는 스크립트

### 4.2 현재 정의 (`000.orchestrate.ps1` 46~50번째 줄)

```powershell
$global:ConflictGroups = @(
    @(4, 5),    # taskbar ↔ bloatware (explorer/AppX 충돌)
    @(8, 12),   # common ↔ ai_features (ContentDeliveryManager 충돌)
    @(9, 10)    # gaming ↔ game_server (NetworkThrottlingIndex 충돌)
)
```

### 4.3 충돌 예시 분석

#### 예시 1: taskbar (4) ↔ bloatware (5)

**충돌 이유**:
- `004.taskbar.ps1`: `explorer.exe` 재시작 + AppX 설정 변경
- `005.bloatware.ps1`: AppX 패키지 제거 + `explorer.exe` 재시작

**동시 실행 시 문제**:
- 두 스크립트가 동시에 `explorer.exe`를 재시작 → 충돌
- AppX 패키지가 제거되는 동안 레지스트리 접근 → 에러

**해결**: ConflictGroup에 등록하여 순차 실행

#### 예시 2: common (8) ↔ ai_features (12)

**충돌 이유**:
- `008.common_optimization.ps1`: `HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager` 수정
- `012.ai_features.ps1`: 동일한 레지스트리 키 수정

**동시 실행 시 문제**:
- 레지스트리 쓰기 경합 (Race Condition)

### 4.4 신규 충돌 그룹 추가

**시나리오**: `013.custom_tweaks.ps1`이 `008.common_optimization.ps1`과 충돌

```powershell
$global:ConflictGroups = @(
    @(4, 5),
    @(8, 12),
    @(9, 10),
    @(8, 13)    # ← 새로운 충돌 관계 추가
)
```

### 4.5 충돌 판단 기준

| 충돌 유형 | 예시 | 대응 |
|----------|------|------|
| **동일 서비스 제어** | 두 스크립트가 모두 `mpssvc` 서비스를 재시작 | ConflictGroup 등록 |
| **동일 레지스트리 키** | `HKCU:\Software\Microsoft\Windows\...` 동시 수정 | ConflictGroup 등록 |
| **Explorer 재시작** | 두 스크립트가 모두 `explorer.exe`를 종료/재시작 | ConflictGroup 등록 |
| **파일 잠금** | 두 스크립트가 동일 파일을 삭제/수정 | ConflictGroup 등록 |
| **독립적인 작업** | A는 네트워크 설정, B는 블로트웨어 제거 | 등록 불필요 (병렬 가능) |

### 4.6 충돌 테스트 방법

```powershell
# 1. orchestrate에서 충돌 가능성이 있는 두 스크립트 선택
# 2. 병렬 실행 시 에러 로그 확인
# 3. 에러 발생 시 ConflictGroup에 추가
```

---

## 5. RequiresReboot 판단 기준

### 5.1 RequiresReboot = $true (재부팅 필요)

다음 중 **하나라도** 해당되면 `$true`:

| 카테고리 | 세부 조건 | 예시 스크립트 |
|---------|----------|---------------|
| **HKLM 레지스트리 변경** | `HKLM:\SYSTEM`, `HKLM:\SOFTWARE` 수정 | `002.power_network.ps1` |
| **서비스 시작 유형 변경** | `Set-Service -StartupType` | `002.power_network.ps1` (DiagTrack) |
| **드라이버 설정** | `sc config <driver> start=` | `003.defender_onedrive_firewall.ps1` (mpsdrv) |
| **전원 관리 설정** | `powercfg -setactive`, PCI Express 설정 | `002.power_network.ps1` |
| **네트워크 어댑터 설정** | NIC 속성 변경 (`PnPCapabilities`) | `002.power_network.ps1` |
| **부팅 관련 설정** | BCD, 부팅 옵션 수정 | `008.common_optimization.ps1` |
| **커널 설정** | VBS, HVCI, Hyper-V | `009.gaming_optimization.ps1` |

### 5.2 RequiresReboot = $false (재부팅 불필요)

다음만 수행하면 `$false`:

| 카테고리 | 세부 조건 | 예시 스크립트 |
|---------|----------|---------------|
| **HKCU 레지스트리만 변경** | 사용자 설정만 변경 | `004.taskbar.ps1` |
| **프로세스 종료** | `Stop-Process`, `taskkill` | `003.defender_onedrive_firewall.ps1` (OneDrive) |
| **일반 앱 설치/제거** | `winget install/uninstall` | `006.software_install.ps1` |
| **파일/폴더 삭제** | `Remove-Item` (시스템 폴더 외) | `005.bloatware.ps1` |
| **예약 작업 변경** | `Disable-ScheduledTask` | `002.power_network.ps1` (일부) |

### 5.3 애매한 경우 판단 기준

**원칙**: **안전을 위해 $true로 설정**

```powershell
# 예시: 레지스트리 HKLM + HKCU 둘 다 변경
RequiresReboot = $true  # HKLM이 포함되었으므로

# 예시: 서비스 중지만 하고 StartupType은 변경 안 함
RequiresReboot = $false  # 서비스 중지는 즉시 적용

# 예시: 방화벽 규칙 추가
RequiresReboot = $false  # 방화벽 규칙은 즉시 적용
```

### 5.4 현재 스크립트별 RequiresReboot 값

| Id | 스크립트 | RequiresReboot | 이유 |
|----|---------|----------------|------|
| 1 | `disable_update.ps1` | `$false` | HKLM 레지스트리 변경이지만 UAC 설정은 로그아웃 후 적용 가능 |
| 2 | `power_network.ps1` | `$true` | 전원 관리, 네트워크 어댑터, 서비스 StartupType 변경 |
| 3 | `defender_onedrive_firewall.ps1` | `$false` | 방화벽 설정, OneDrive 제거는 즉시 적용 |
| 4 | `taskbar.ps1` | `$false` | HKCU 레지스트리만 변경 |
| 5 | `bloatware.ps1` | `$false` | AppX 제거, 파일 삭제 |
| 6 | `software_install.ps1` | `$false` | winget 앱 설치 |
| 8 | `common_optimization.ps1` | `$true` | DNS 설정, 부팅 최적화 |
| 9 | `gaming_optimization.ps1` | `$true` | VBS, HVCI 비활성화 (커널 설정) |
| 10 | `game_server.ps1` | `$true` | 네트워크 스택 설정 (HKLM) |
| 11 | `web_server.ps1` | `$true` | IIS 설정 (시스템 설정) |
| 12 | `ai_features.ps1` | `$true` | HKLM 레지스트리 변경 |

---

## 6. 실행 흐름 이해

### 6.1 전체 실행 순서

```
1. 000.orchestrate.ps1 시작
   ↓
2. 저장된 상태 확인 (재부팅 후 재개?)
   ↓
3. 메뉴 표시 (Show-Menu)
   ↓
4. 사용자 선택 (Get-UserSelection)
   ↓
5. 실행 시작 (Start-OptimizationProcess)
   ├─ Phase 1: RequiresReboot = false 항목
   │   ↓
   │   배치 생성 (Get-ExecutionBatches)
   │   ↓
   │   병렬 실행 (Invoke-ParallelScripts)
   ↓
   ├─ Phase 2: RequiresReboot = true 항목
   │   ↓
   │   배치 생성
   │   ↓
   │   병렬 실행
   ↓
6. 완료 메시지 + 재부팅 프롬프트
```

### 6.2 Phase 1 vs Phase 2 분리 이유

**Phase 1 (재부팅 불필요)**:
- 즉시 적용 가능한 설정
- 재부팅 전에 완료해야 안전
- 예: 블로트웨어 제거, 작업 표시줄 설정

**Phase 2 (재부팅 필요)**:
- 시스템 깊은 변경
- 재부팅 후 적용
- 예: 전원 관리, VBS 비활성화

**분리의 이점**:
- 재부팅 불필요 작업은 즉시 완료
- 재부팅 필요 작업은 모아서 한 번에 재부팅

---

## 7. 병렬 실행 메커니즘

### 7.1 배치 생성 알고리즘

`Get-ExecutionBatches` 함수 (`000.orchestrate.ps1` 227~267번째 줄):

```powershell
function Get-ExecutionBatches {
    param([array]$ScriptIds)

    $batches = @()
    $remaining = [System.Collections.ArrayList]@($ScriptIds)

    while ($remaining.Count -gt 0) {
        $batch = @()
        $toRemove = @()

        foreach ($id in $remaining) {
            $canAdd = $true

            # 현재 배치의 다른 스크립트와 충돌 체크
            foreach ($batchId in $batch) {
                foreach ($group in $global:ConflictGroups) {
                    if (($group -contains $id) -and ($group -contains $batchId)) {
                        $canAdd = $false
                        break
                    }
                }
                if (-not $canAdd) { break }
            }

            if ($canAdd) {
                $batch += $id
                $toRemove += $id
            }
        }

        foreach ($id in $toRemove) {
            $remaining.Remove($id) | Out-Null
        }

        if ($batch.Count -gt 0) {
            $batches += ,@($batch)
        }
    }

    return $batches
}
```

### 7.2 배치 생성 예시

**입력**: `@(1, 2, 3, 4, 5, 8, 12)`

**ConflictGroups**:
```powershell
@(4, 5)    # taskbar ↔ bloatware
@(8, 12)   # common ↔ ai_features
```

**생성된 배치**:
```
Batch 1: [1, 2, 3, 4, 8]     # 5와 12는 충돌로 제외
Batch 2: [5, 12]             # 4, 8과 각각 충돌하므로 별도 배치
```

**실행 순서**:
1. Batch 1 병렬 실행 (1, 2, 3, 4, 8 동시)
2. Batch 1 완료 대기
3. Batch 2 병렬 실행 (5, 12 동시)
4. Batch 2 완료

### 7.3 병렬 실행 구현

`Invoke-ParallelScripts` 함수 (`000.orchestrate.ps1` 295~366번째 줄):

```powershell
# Start-Job으로 각 스크립트 백그라운드 실행
$jobs = @()
foreach ($id in $ScriptIds) {
    $item = $global:ScriptItems | Where-Object { $_.Id -eq $id }
    $scriptUrl = "$global:ScriptBaseUrl/$($item.File)"

    $job = Start-Job -ScriptBlock {
        param($url)
        # UTF-8 인코딩 설정
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $OutputEncoding = [System.Text.Encoding]::UTF8

        # OrchestrateMode 설정
        $global:OrchestrateMode = $true

        try {
            $content = Invoke-RestMethod $url
            Invoke-Expression $content
            return @{ Success = $true; Error = $null }
        } catch {
            return @{ Success = $false; Error = $_.Exception.Message }
        }
    } -ArgumentList $scriptUrl

    $jobs += @{ Job = $job; Id = $id }
}

# 모든 Job 완료 대기
foreach ($jobInfo in $jobs) {
    Wait-Job -Job $jobInfo.Job | Out-Null
    $output = Receive-Job -Job $jobInfo.Job
    Remove-Job -Job $jobInfo.Job
    # 결과 수집...
}
```

### 7.4 병렬 실행 주의사항

**출력 중복 방지**:
```powershell
# 각 스크립트 헤더에 반드시 포함
$ProgressPreference = 'SilentlyContinue'
```

**OrchestrateMode 설정**:
```powershell
# Job 내부에서 자동 설정됨
$global:OrchestrateMode = $true
```

---

## 8. 상태 관리 시스템

### 8.1 상태 저장 경로

```powershell
$global:StateFilePath = "$env:LOCALAPPDATA\Windows11Optimizer\state.json"
# C:\Users\<사용자>\AppData\Local\Windows11Optimizer\state.json
```

### 8.2 상태 파일 구조

```json
{
  "PendingItems": [1, 2, 3, 4, 5, 6, 8, 12],
  "CompletedItems": [1, 2, 3],
  "CurrentIndex": 3,
  "NeedsReboot": true,
  "Timestamp": "2025-01-03T14:30:00.0000000+09:00"
}
```

### 8.3 재부팅 후 자동 재개

**RunOnce 레지스트리 등록** (`Register-RunOnce` 함수):

```powershell
function Register-RunOnce {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    $scriptUrl = "$global:ScriptBaseUrl/000.orchestrate.ps1"

    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"irm '$scriptUrl' | iex`""

    Set-ItemProperty -Path $regPath -Name "Windows11Optimizer" -Value $command -Type String
}
```

**재시작 후 실행 흐름**:
1. Windows 로그인
2. RunOnce가 `000.orchestrate.ps1` 실행
3. `Get-SavedState`로 이전 상태 로드
4. "계속하시겠습니까?" 프롬프트
5. 남은 항목 계속 실행

### 8.4 상태 관리 함수

| 함수 | 설명 |
|------|------|
| `Save-State` | 현재 진행 상태를 JSON으로 저장 |
| `Get-SavedState` | 저장된 상태 로드 (없으면 $null) |
| `Clear-State` | 상태 파일 삭제 + RunOnce 해제 |
| `Register-RunOnce` | 재부팅 후 자동 실행 등록 |
| `Unregister-RunOnce` | 자동 실행 등록 해제 |

---

## 9. 문제 해결

### 9.1 스크립트가 메뉴에 나타나지 않음

**원인**:
- `ScriptItems`에 등록하지 않음

**해결**:
```powershell
# 000.orchestrate.ps1의 ScriptItems에 추가
@{ Id = 13; File = "013.custom_tweaks.ps1"; Name = "사용자 정의 최적화"; RequiresReboot = $true; Group = "고급" }
```

### 9.2 병렬 실행 시 에러 발생

**원인**:
- ConflictGroup에 등록되지 않은 충돌

**해결**:
```powershell
# 충돌하는 스크립트 Id를 ConflictGroups에 추가
$global:ConflictGroups = @(
    @(4, 5),
    @(8, 12),
    @(9, 10),
    @(8, 13)  # ← 충돌 관계 추가
)
```

### 9.3 재부팅 후 자동 재개되지 않음

**원인**:
- `Register-RunOnce`가 호출되지 않음
- 상태 파일 손상

**해결**:
```powershell
# 상태 파일 확인
Get-Content "$env:LOCALAPPDATA\Windows11Optimizer\state.json"

# RunOnce 레지스트리 확인
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "Windows11Optimizer"
```

### 9.4 한글 깨짐 (irm | iex 실행 시)

**원인**:
- 개별 스크립트에 UTF-8 설정 누락

**해결**:
```powershell
# 스크립트 헤더에 반드시 추가
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null
```

### 9.5 OrchestrateMode에서 재부팅 프롬프트 나타남

**원인**:
- 개별 스크립트에 OrchestrateMode 체크 누락

**해결**:
```powershell
# 재부팅 프롬프트 앞에 조건문 추가
if (-not $global:OrchestrateMode) {
    $restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
    # ...
}
```

---

## 10. 체크리스트

### 10.1 신규 스크립트 추가 시

- [ ] 파일명이 `[번호].[기능명].ps1` 형식인가?
- [ ] `ScriptItems`에 항목을 추가했는가?
  - [ ] `Id`가 고유한가?
  - [ ] `Name`이 32자 이하인가?
  - [ ] `RequiresReboot`을 정확히 판단했는가?
  - [ ] `Group`을 적절히 선택했는가?
- [ ] 적절한 프리셋에 추가했는가?
- [ ] 충돌 가능성이 있는 스크립트를 `ConflictGroups`에 등록했는가?
- [ ] 스크립트 템플릿을 준수했는가? (UTF-8, OrchestrateMode, ProgressPreference)

### 10.2 프리셋 수정 시

- [ ] 프리셋의 대상 사용자가 명확한가?
- [ ] 포함된 스크립트가 모두 대상 사용자에게 안전한가?
- [ ] 메뉴에 새 프리셋 버튼을 추가했는가? (4개 이상 시)
- [ ] 선택 핸들러를 추가했는가?

### 10.3 ConflictGroups 수정 시

- [ ] 충돌 관계를 정확히 파악했는가?
- [ ] 병렬 실행 테스트를 수행했는가?
- [ ] 불필요한 순차 실행으로 성능 저하가 없는가?

---

## 11. 고급 팁

### 11.1 성능 최적화

**배치 크기 극대화**:
- ConflictGroups를 최소화하여 병렬 실행 극대화
- 불필요한 충돌 관계 제거

**RequiresReboot 정확히 판단**:
- `$false`로 설정 가능한 항목은 Phase 1에서 먼저 실행
- 재부팅 횟수 최소화

### 11.2 디버깅

**병렬 실행 로그 확인**:
```powershell
# Start-Job 내부에 디버그 출력 추가
Write-Host "DEBUG: 스크립트 $id 시작" -ForegroundColor Magenta
```

**상태 파일 수동 편집**:
```powershell
# 특정 항목을 완료 처리하여 재실행 방지
$state = Get-Content "$env:LOCALAPPDATA\Windows11Optimizer\state.json" | ConvertFrom-Json
$state.CompletedItems += 5  # 5번 스크립트 완료 처리
$state | ConvertTo-Json | Set-Content "$env:LOCALAPPDATA\Windows11Optimizer\state.json"
```

---

## 12. 참고 자료

- [SCRIPT_DEVELOPMENT_GUIDE.md](./SCRIPT_DEVELOPMENT_GUIDE.md): 스크립트 작성 가이드
- [SCRIPTS_OVERVIEW.md](./SCRIPTS_OVERVIEW.md): 스크립트 개요
- [000.orchestrate.ps1](../ps_scripts/000.orchestrate.ps1): Orchestrate 스크립트 소스

---

**마지막 업데이트**: 2025-01-03
