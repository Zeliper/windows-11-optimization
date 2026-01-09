# Task Plan: 모든 스크립트에 적용 여부 체크 및 스킵/Override 기능 추가

## Goal
이미 한 번 실행했던 OS에서 다시 스크립트를 실행할 때, 각 설정 항목이 이미 적용되어 있으면 스킵하고, 사용자가 원하면 Override할 수 있도록 모든 스크립트를 개선한다.

## Current Phase
Phase 6 (completed) - 000.orchestrate.ps1 업데이트

## 핵심 설계 원칙

### 1. 참조 모델
018.memory_optimization.ps1과 022.advanced_gaming_optimization.ps1이 이미 이상적인 패턴 구현:
- `Set-RegistryIfDifferent` - 레지스트리 값 비교 후 변경
- `Set-ServiceIfDifferent` - 서비스 상태 비교 후 변경
- `Write-OptLog` - 로그 기록
- `Save-OptLog` - 로그 파일 저장 (Documents 폴더)
- Summary 출력 (적용됨/스킵됨/실패)

### 2. 스크립트별 적용 체크 유형

| 유형 | 체크 방법 | 예시 스크립트 |
|------|----------|---------------|
| 레지스트리 값 | 현재 값과 목표 값 비교 | 001, 002, 004, 012-022 |
| 서비스 상태 | StartupType 비교 | 003, 008 |
| 파일/디렉토리 존재 | Test-Path | 006, 007 |
| 앱 패키지 설치 여부 | Get-AppxPackage | 005 |
| 방화벽 상태 | Get-NetFirewallProfile | 003 |
| 예약 작업 | Get-ScheduledTask | 003 |
| 기능 설치 여부 | Get-WindowsCapability | 007, 011 |

### 3. 출력 형식 표준
```
[1/N] 작업 설명...
  - 항목명 : 이미 설정됨 (스킵)     ← Gray
  - 항목명 : 이전값 → 새값 (적용됨)  ← Green
  - 항목명 : 설정 실패              ← Red
```

### 4. Summary 출력
```
Summary:
  - 적용됨: X 개
  - 스킵됨: Y 개 (이미 최적 설정)
  - 실패: Z 개

로그 파일: C:\Users\User\Documents\Windows11Optimizer_XXX_YYYYMMDD_HHMMSS.log
```

## Phases

### Phase 1: 공통 함수 모듈 생성
- [ ] Common.ps1 파일 생성 (ps_scripts/Common/Common.ps1)
- [ ] 모든 공통 함수 구현
- **Status:** in_progress

### Phase 2: 001-005 스크립트 업데이트
- [ ] 001.disable_update.ps1 - 레지스트리 체크 추가 (v1.0.0 → v1.1.0)
- [ ] 002.power_network.ps1 - 전원/네트워크 설정 체크 추가 (v1.0.0 → v1.1.0)
- [ ] 003.defender_onedrive_firewall.ps1 - Defender/OneDrive/방화벽 체크 (v1.0.0 → v1.1.0)
- [ ] 004.taskbar.ps1 - 작업 표시줄 설정 체크 (v1.0.0 → v1.1.0)
- [ ] 005.bloatware.ps1 - 앱 패키지 존재 여부 체크 (v1.0.0 → v1.1.0)
- **Status:** pending

### Phase 3: 006-011 스크립트 업데이트
- [x] 006.software_install.ps1 - 소프트웨어 설치 여부 체크 (v1.0.12 → v1.1.0)
- [ ] 007.openssh_rsync.ps1 - SSH/rsync 설치 여부 체크
- [x] 008.common_optimization.ps1 - 공통 최적화 설정 체크 (v1.0.0 → v1.1.0)
- [x] 009.gaming_optimization.ps1 - 게임 최적화 설정 체크 (v1.0.0 → v1.1.0)
- [x] 010.game_server.ps1 - 게임 서버 설정 체크 (v1.0.0 → v1.1.0)
- [x] 011.web_server.ps1 - 웹 서버 설정 체크 (v1.0.0 → v1.1.0)
- **Status:** completed (007 제외)

### Phase 4: 012-017 스크립트 업데이트
- [ ] 012.ai_features.ps1 - AI 기능 설정 체크 (v1.0.0 → v1.1.0)
- [ ] 013.privacy_optimization.ps1 - 개인정보 설정 체크 (v1.0.0 → v1.1.0)
- [ ] 014.storage_optimization.ps1 - 저장소 설정 체크 (v1.0.0 → v1.1.0)
- [ ] 015.startup_optimization.ps1 - 시작 프로그램 설정 체크 (v1.0.0 → v1.1.0)
- [ ] 016.accessibility_cleanup.ps1 - 접근성 설정 체크 (v1.0.0 → v1.1.0)
- [ ] 017.mouse_input_optimization.ps1 - 입력 장치 설정 체크 (v1.0.0 → v1.1.0)
- **Status:** pending

### Phase 4.5: 로그 경로 변경
- [x] 모든 스크립트의 로그 경로를 `%USERPROFILE%\Documents\windows11-optimization-logs`로 변경
- [x] 디렉토리가 없을 경우 자동 생성 로직 추가
- [x] 영향 받는 스크립트: 001-006, 008-018, 022 (총 17개)
- [x] 각 스크립트 Patch 버전 증분 (v1.1.0 → v1.1.1)
- **Status:** completed

### Phase 5: 019-021 스크립트 업데이트
- [x] 018.memory_optimization.ps1 - 이미 적용됨 (참조 모델, v1.1.0 → v1.1.1)
- [x] 019.search_optimization.ps1 - 검색 최적화 설정 체크 (v1.0.0 → v1.1.0)
- [x] 020.registry_tweaks.ps1 - 레지스트리 설정 체크 (v1.0.0 → v1.1.0)
- [x] 021.ntfs_ssd_optimization.ps1 - NTFS/SSD 설정 체크 (v1.0.0 → v1.1.0)
- [x] 022.advanced_gaming_optimization.ps1 - 이미 적용됨 (참조 모델, v1.1.0 → v1.1.1)
- **Status:** completed

### Phase 6: 000.orchestrate.ps1 업데이트
- [x] `$global:ForceOverride` 플래그 추가 (전체 강제 적용 옵션)
- [x] 메뉴에 시스템 정보 표시 (RAM, 드라이브 타입, ForceOverride 상태)
- [x] 메뉴에 ForceOverride 토글 옵션 [F] 추가
- [x] 스크립트 실행 결과 요약 수집 (Add-ScriptResult 함수)
- [x] 전체 Summary 출력 (Show-OrchestrateSummary 함수)
- [x] Orchestrate 전용 로그 파일 저장 (Save-OrchestrateSummary 함수)
- [x] 시스템 분기 정보 로그에 포함 (RAM 분기, SSD/NVMe/HDD 분기)
- [x] 버전 v1.0.0 → v1.1.0 증분
- **Status:** completed

### Phase 7: 문서 업데이트 및 커밋
- [ ] CLAUDE.md 버전 업데이트
- [ ] README.md 새 기능 설명 추가
- [ ] 커밋 및 푸시
- **Status:** pending

## Key Questions
1. Override 옵션은 전역 플래그로 설정할지, 개별 프롬프트로 할지?
   → **결정:** OrchestrateMode + ForceOverride 전역 플래그 조합
2. 로그 파일은 어디에 저장할지?
   → **결정:** Documents 폴더 (018/022 참조)

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Common.ps1 공통 모듈 사용 | 코드 중복 방지, 일관된 동작 보장 |
| 018/022 패턴 참조 | 이미 검증된 패턴 |
| Gray/Green/Red 색상 규칙 | 직관적인 상태 표시 |
| Documents 폴더에 로그 저장 | 사용자 접근성 |
| 각 스크립트 Minor 버전 증가 | 새 기능 추가 (스킵/Override) |

## 스크립트 수정 총 개수
- 신규 파일: 1개 (Common.ps1)
- 수정 파일: 20개 (000-005, 006-011, 012-017, 019-021)
- 참조 모델 (수정 불필요): 2개 (018, 022)

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
|       | 1       |            |

## Notes
- 018.memory_optimization.ps1과 022.advanced_gaming_optimization.ps1이 이미 이상적인 패턴 구현
- 각 스크립트마다 Minor 버전 증분 필요 (새 기능 추가)
- OrchestrateMode에서는 사용자 프롬프트 건너뛰기
- ForceOverride 플래그로 이미 적용된 설정도 강제 재적용 가능
