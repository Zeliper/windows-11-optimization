# 스크립트 작성 및 수정 가이드

이 문서는 Windows 11 최적화 스크립트 프로젝트에서 신규 스크립트를 작성하거나 기존 스크립트를 수정할 때 반드시 준수해야 할 규칙과 가이드라인을 제공합니다.

## 목차

1. [스크립트 템플릿 구조](#1-스크립트-템플릿-구조)
2. [파일 명명 규칙](#2-파일-명명-규칙)
3. [필수 헤더 섹션](#3-필수-헤더-섹션)
4. [OrchestrateMode 연동](#4-orchestratemode-연동)
5. [색상 및 출력 규칙](#5-색상-및-출력-규칙)
6. [진행 상태 표시](#6-진행-상태-표시)
7. [에러 처리](#7-에러-처리)
8. [재부팅 처리](#8-재부팅-처리)
9. [코드 스타일 가이드](#9-코드-스타일-가이드)
10. [테스트 체크리스트](#10-테스트-체크리스트)

---

## 1. 스크립트 템플릿 구조

모든 스크립트는 다음 템플릿을 기반으로 작성되어야 합니다:

```powershell
# [스크립트 제목]
# [스크립트 설명 - 1~2줄]
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

Write-Host "=== [스크립트 제목] ===" -ForegroundColor Cyan
Write-Host ""

# ===== 메인 작업 시작 =====

# [작업 1]
Write-Host "[1/N] [작업 설명] 중..." -ForegroundColor Yellow
# 작업 코드...
Write-Host "  - [완료 메시지]" -ForegroundColor Green

# [작업 2]
Write-Host ""
Write-Host "[2/N] [작업 설명] 중..." -ForegroundColor Yellow
# 작업 코드...
Write-Host "  - [완료 메시지]" -ForegroundColor Green

# ===== 완료 메시지 =====

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "[추가 안내 메시지 (선택)]" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인 (필요한 경우만)
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
```

---

## 2. 파일 명명 규칙

### 2.1 파일명 형식

```
[번호].[기능명].ps1
```

- **번호**: 3자리 숫자 (예: `001`, `002`, `013`)
  - `000`: orchestrate 스크립트 전용
  - `001~099`: 기본 최적화 스크립트
  - `100~199`: 고급/실험적 스크립트 (향후 확장용)

- **기능명**: 소문자 + 언더스코어 조합 (snake_case)
  - 축약어보다는 명확한 단어 사용
  - 여러 단어는 `_`로 구분

### 2.2 좋은 예시

```
001.disable_update.ps1          # ✅ 명확한 기능명
002.power_network.ps1           # ✅ 복합 기능 표현
009.gaming_optimization.ps1     # ✅ 카테고리가 명확함
012.ai_features.ps1             # ✅ 간결하고 명확함
```

### 2.3 나쁜 예시

```
013.DisableUpdate.ps1           # ❌ CamelCase 사용
014.pwr_net.ps1                 # ❌ 과도한 축약
015.script.ps1                  # ❌ 기능이 불명확
016.gaming-opt.ps1              # ❌ 하이픈(-) 사용
```

---

## 3. 필수 헤더 섹션

모든 스크립트는 다음 헤더 구성요소를 **반드시** 포함해야 합니다:

### 3.1 관리자 권한 요구

```powershell
#Requires -RunAsAdministrator
```

- 스크립트 최상단에 위치
- 레지스트리/서비스 변경 시 필수

### 3.2 UTF-8 인코딩 설정

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null
```

- **필수**: `irm | iex` 실행 시 한글 깨짐 방지
- 항상 동일한 순서로 작성

### 3.3 Progress Bar 비활성화

```powershell
$ProgressPreference = 'SilentlyContinue'
```

- **필수**: 병렬 실행 시 출력 겹침 방지
- 성능 향상 효과

### 3.4 OrchestrateMode 확인

```powershell
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}
```

- **필수**: 단독 실행과 orchestrate 실행 구분
- 반드시 `$null -eq` 순서로 작성 (역순 불가)

---

## 4. OrchestrateMode 연동

### 4.1 OrchestrateMode란?

- `000.orchestrate.ps1`에서 스크립트를 병렬/순차 실행할 때 사용
- `$global:OrchestrateMode = $true`로 설정됨
- 이 모드에서는 사용자 입력 대화를 건너뛰어야 함

### 4.2 재부팅 프롬프트 조건부 처리

**필수 패턴:**

```powershell
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
```

- **OrchestrateMode에서는**: 재부팅 프롬프트를 표시하지 않음
- **단독 실행에서만**: 재부팅 여부를 사용자에게 물어봄

### 4.3 기타 사용자 입력

**피해야 할 패턴:**

```powershell
# ❌ 나쁜 예: OrchestrateMode 체크 없이 입력 요청
$confirm = Read-Host "계속하시겠습니까? (Y/N)"
```

**권장 패턴:**

```powershell
# ✅ 좋은 예: OrchestrateMode에서는 자동 진행
if (-not $global:OrchestrateMode) {
    $confirm = Read-Host "계속하시겠습니까? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "작업을 취소합니다." -ForegroundColor Yellow
        exit
    }
}
```

---

## 5. 색상 및 출력 규칙

### 5.1 표준 색상 가이드

| 용도 | 색상 | 사용 예시 |
|------|------|----------|
| **제목/구분선** | `Cyan` | 스크립트 제목, 섹션 구분 |
| **진행 중** | `Yellow` | 작업 시작 알림 |
| **성공** | `Green` | 작업 완료, 설정 적용 완료 |
| **경고** | `Yellow` | 선택적 알림, 권장사항 |
| **오류/위험** | `Red` | 에러, 실패, 재부팅 카운트다운 |
| **일반 정보** | `White` | 세부 정보, 설명 |
| **비활성/숨김** | `Gray` | 예시 명령어, 참고 정보 |

### 5.2 출력 형식 예시

```powershell
# 스크립트 시작
Write-Host "=== Windows Update 설정 스크립트 ===" -ForegroundColor Cyan
Write-Host ""

# 작업 시작 (진행 번호 표시)
Write-Host "[1/3] Windows Update 정책 설정 중..." -ForegroundColor Yellow

# 세부 완료 메시지 (들여쓰기 2칸)
Write-Host "  - 업데이트: 다운로드 및 설치 알림 (수동)" -ForegroundColor Green
Write-Host "  - 자동 재시작 방지 활성화" -ForegroundColor Green

# 경고 메시지
Write-Host "  - 경고: 일부 설정은 재부팅 후 적용됩니다" -ForegroundColor Yellow

# 오류 메시지
Write-Host "  - 오류: 서비스 시작 실패" -ForegroundColor Red

# 완료 구분선
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
```

### 5.3 구분선 규칙

```powershell
# 메인 제목 구분선 (50자)
Write-Host "==================================================" -ForegroundColor Cyan

# 중간 제목 구분선 (40자)
Write-Host "========================================" -ForegroundColor Cyan

# 서브 섹션 구분선 (40자)
Write-Host "  ========================================" -ForegroundColor Cyan

# 짧은 구분선 (작업 사이, 빈 줄 + Write-Host ""로 간격 조절)
Write-Host ""
```

---

## 6. 진행 상태 표시

### 6.1 작업 번호 표시

```powershell
Write-Host "[1/5] 첫 번째 작업 중..." -ForegroundColor Yellow
# ...
Write-Host "[2/5] 두 번째 작업 중..." -ForegroundColor Yellow
# ...
Write-Host "[5/5] 마지막 작업 중..." -ForegroundColor Yellow
```

- **형식**: `[현재/전체]`
- **전체 개수**: 스크립트의 메인 작업 단계 수

### 6.2 하위 작업 표시

```powershell
Write-Host "[3/5] 방화벽 설정 중..." -ForegroundColor Yellow
Write-Host "  [3-1] mpsdrv 드라이버 확인 중..." -ForegroundColor Cyan
# ...
Write-Host "  [3-2] BFE 서비스 확인 중..." -ForegroundColor Cyan
# ...
```

---

## 7. 에러 처리

### 7.1 기본 에러 처리 패턴

```powershell
# 서비스 시작 예시
try {
    Start-Service -Name "ServiceName" -ErrorAction Stop
    Write-Host "  - 서비스 시작 완료" -ForegroundColor Green
} catch {
    Write-Host "  - 오류: 서비스 시작 실패 - $_" -ForegroundColor Red
}
```

### 7.2 SilentlyContinue 사용

```powershell
# 레지스트리 설정 (실패해도 계속 진행)
Set-ItemProperty -Path $regPath -Name "ValueName" -Value 1 -Type DWord -ErrorAction SilentlyContinue

# 서비스 중지 (이미 중지되어 있어도 에러 무시)
Stop-Service -Name "ServiceName" -Force -ErrorAction SilentlyContinue
```

### 7.3 에러 메시지 출력

```powershell
# 조건부 에러 체크
$service = Get-Service -Name "ServiceName" -ErrorAction SilentlyContinue
if ($service.Status -ne "Running") {
    Write-Host "  - 경고: 서비스가 실행되지 않았습니다" -ForegroundColor Red
    Write-Host "  - 재부팅 후 다시 시도하세요" -ForegroundColor Red
}
```

---

## 8. 재부팅 처리

### 8.1 RequiresReboot 판단 기준

스크립트가 다음 중 하나라도 해당되면 `RequiresReboot = $true`:

1. **레지스트리 HKLM 변경**
   - 시스템 전역 설정 (전원 관리, 네트워크, 서비스 등)

2. **서비스 시작 유형 변경**
   - `Set-Service -StartupType Disabled/Automatic`

3. **드라이버 설정 변경**
   - `mpsdrv`, `nvlddmkm` 등

4. **시스템 파일 삭제/변경**
   - `%SystemRoot%` 내 파일 수정

5. **그룹 정책 변경**
   - `HKLM:\SOFTWARE\Policies` 하위 변경

### 8.2 RequiresReboot = $false 예시

- **사용자 레지스트리만 변경** (`HKCU:\`)
- **실행 중인 프로세스만 종료**
- **일반 앱 설치/제거** (winget)

### 8.3 재부팅 메시지

```powershell
# RequiresReboot = true인 경우
Write-Host "일부 설정은 재부팅 후 적용됩니다." -ForegroundColor Yellow

# RequiresReboot = false인 경우
Write-Host "모든 설정이 즉시 적용되었습니다." -ForegroundColor Green
```

---

## 9. 코드 스타일 가이드

### 9.1 변수 명명

```powershell
# ✅ 좋은 예: PascalCase
$ServiceName = "mpssvc"
$RegPath = "HKLM:\SOFTWARE\..."
$FirewallService = Get-Service -Name "mpssvc"

# ❌ 나쁜 예
$service_name = "mpssvc"      # snake_case
$regpath = "HKLM:\..."        # 모두 소문자
$fs = Get-Service...          # 과도한 축약
```

### 9.2 주석 작성

```powershell
# ===== 큰 섹션 구분 =====

# 중간 섹션 설명

# 단일 라인 설명
Set-ItemProperty -Path $path -Name "Value" -Value 1

# 복잡한 코드 블록 설명
# USB 선택적 절전 모드 비활성화
# GUID: 2a737441-1930-4402-8d77-b2bebba308a3 (USB 설정)
# GUID: 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 (선택적 절전)
powercfg -setacvalueindex $scheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
```

### 9.3 들여쓰기

- **탭 대신 공백 4칸** 사용
- if/foreach 블록 내부는 한 단계 들여쓰기

```powershell
if ($condition) {
    # 4칸 들여쓰기
    Write-Host "Test" -ForegroundColor Green

    if ($nestedCondition) {
        # 8칸 들여쓰기
        Write-Host "Nested" -ForegroundColor Yellow
    }
}
```

### 9.4 줄 바꿈

```powershell
# 긴 명령어는 백틱(`)으로 줄 바꿈
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
    -Name "ConsentPromptBehaviorAdmin" `
    -Value 0 `
    -Type DWord

# 파이프라인은 자연스럽게 줄 바꿈
Get-ChildItem $path |
    Where-Object { $_.Name -like "*.txt" } |
    ForEach-Object { Remove-Item $_.FullName }
```

---

## 10. 테스트 체크리스트

### 10.1 단독 실행 테스트

```powershell
# PowerShell 관리자 권한으로 실행
.\001.your_script.ps1
```

**확인 사항:**
- [ ] UTF-8 한글이 깨지지 않는가?
- [ ] 진행 상태가 순서대로 표시되는가?
- [ ] 완료 메시지가 정상 출력되는가?
- [ ] 재부팅 프롬프트가 동작하는가?

### 10.2 Orchestrate 실행 테스트

```powershell
# 000.orchestrate.ps1에서 해당 스크립트 선택 후 실행
```

**확인 사항:**
- [ ] 병렬 실행 시 출력이 겹치지 않는가?
- [ ] OrchestrateMode에서 재부팅 프롬프트가 나타나지 않는가?
- [ ] 다른 스크립트와 동시 실행 시 충돌이 없는가?

### 10.3 원격 실행 테스트

```powershell
# GitHub raw URL로 실행
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/001.your_script.ps1 | iex
```

**확인 사항:**
- [ ] UTF-8 인코딩이 정상 동작하는가?
- [ ] 한글이 깨지지 않는가?

### 10.4 재부팅 후 검증

**RequiresReboot = true인 경우:**
- [ ] 설정이 재부팅 후 실제로 적용되었는가?
- [ ] 레지스트리 값이 정확히 설정되었는가?
- [ ] 서비스 상태가 의도대로 변경되었는가?

---

## 11. 자주 하는 실수

### 11.1 UTF-8 인코딩 누락

```powershell
# ❌ 이렇게 하지 마세요
Write-Host "한글 테스트"  # irm | iex 실행 시 깨짐

# ✅ 반드시 헤더에 UTF-8 설정 추가
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null
```

### 11.2 OrchestrateMode 체크 누락

```powershell
# ❌ 이렇게 하지 마세요
$restart = Read-Host "재부팅하시겠습니까?"  # orchestrate에서 멈춤

# ✅ 반드시 조건문으로 감싸기
if (-not $global:OrchestrateMode) {
    $restart = Read-Host "재부팅하시겠습니까? (Y/N)"
}
```

### 11.3 에러 무시

```powershell
# ❌ 이렇게 하지 마세요
Set-Service -Name "NonExistentService" -StartupType Disabled  # 에러 발생

# ✅ ErrorAction 명시적 지정
Set-Service -Name "NonExistentService" -StartupType Disabled -ErrorAction SilentlyContinue
```

### 11.4 Progress Bar 미비활성화

```powershell
# ❌ 이렇게 하지 마세요 (병렬 실행 시 출력 겹침)
Invoke-WebRequest -Uri $url  # Progress Bar 표시됨

# ✅ 헤더에서 미리 비활성화
$ProgressPreference = 'SilentlyContinue'
```

---

## 12. 참고 자료

### 12.1 기존 스크립트 참고

- `001.disable_update.ps1`: 기본 템플릿
- `002.power_network.ps1`: 복잡한 작업 구성
- `003.defender_onedrive_firewall.ps1`: 서비스 제어 예시
- `000.orchestrate.ps1`: OrchestrateMode 구현

### 12.2 관련 문서

- [ORCHESTRATE_INTEGRATION.md](./ORCHESTRATE_INTEGRATION.md): orchestrate 연동 가이드
- [SCRIPTS_OVERVIEW.md](./SCRIPTS_OVERVIEW.md): 스크립트 개요
- [OPTIMIZATION_CATEGORIES.md](./OPTIMIZATION_CATEGORIES.md): 최적화 카테고리

---

## 마무리

이 가이드를 준수하면:
- ✅ 일관성 있는 코드 스타일
- ✅ orchestrate와 완벽한 호환성
- ✅ 안정적인 병렬 실행
- ✅ 사용자 친화적인 출력

**문제 발생 시**: 기존 스크립트 코드를 참고하거나, 이 가이드의 템플릿을 다시 확인하세요.
