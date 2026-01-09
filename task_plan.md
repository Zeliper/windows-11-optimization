# 로그 분석 및 스크립트 수정 계획

## 분석 요약

### 1. 실패 항목 (3건) - 모두 수정 완료

| 스크립트 | 항목 | 원인 | 조치 | 상태 |
|---------|------|------|------|------|
| 004.taskbar.ps1 | 위젯 버튼 숨김 | HKLM 레지스트리 권한 문제 | try/catch 추가, 실패 시 스킵 처리 | **완료** |
| 002.power_network.ps1 | 전원 옵션 | "고성능 옵션 없음" | 균형 모드 fallback 추가 | **완료** |
| 010.game_server.ps1 | 오프로드 설정 | `TxRxEnabled` 잘못된 열거자 | `RxTxEnabled`로 수정 | **완료** |

### 2. 프로그램 설치 + 확장자 연결 중복 문제 - 수정 완료

006.software_install.ps1 로그:
- 프로그램들이 "이미 설치됨"으로 스킵
- **수정**: 확장자 연결도 이미 설정되어 있으면 스킵하도록 수정

추가된 함수:
- `Test-FileAssociation`: 파일 확장자가 특정 ProgId로 설정되어 있는지 확인
- `Test-ProtocolAssociation`: URL 프로토콜이 특정 ProgId로 설정되어 있는지 확인

### 3. Native NVMe 실험적 기능 문제 - 수정 완료

**원인**: `000.orchestrate.ps1`에서 Job으로 병렬 실행 시 `$global:ExperimentalOptions`가 전달되지 않음

**해결**: ExperimentalOptions를 JSON으로 직렬화하여 Job에 전달하도록 수정

---

## 수정된 파일 목록 (v1.1.2)

| 파일 | 이전 버전 | 새 버전 | 변경 내용 |
|------|----------|---------|-----------|
| 000.orchestrate.ps1 | v1.1.0 | v1.1.1 | ExperimentalOptions JSON 직렬화 및 Job 전달 |
| 002.power_network.ps1 | v1.1.1 | v1.1.2 | 균형 모드 fallback (고성능 없는 노트북 지원) |
| 004.taskbar.ps1 | v1.1.1 | v1.1.2 | 위젯 정책 HKLM 권한 문제 try/catch 처리 |
| 006.software_install.ps1 | v1.1.1 | v1.1.2 | 파일 연결 스킵 로직 (이미 설정된 경우) |
| 010.game_server.ps1 | v1.1.1 | v1.1.2 | TxRxEnabled → RxTxEnabled 열거자 수정 |

---

## 중복 설정 분석 (참고용)

| 설정 | 스크립트 | 비고 |
|------|---------|------|
| NetworkThrottlingIndex | 010.game_server, 022.advanced_gaming | 동일 레지스트리 (현재 상태 유지) |
| Nagle 알고리즘 | 002.power_network, 010.game_server | TcpNoDelay 설정 중복 (현재 상태 유지) |
| Native NVMe | 010.game_server, 021.ntfs_ssd_optimization | 021은 항상 활성화, 010은 선택적 |

---

## 현재 진행 상태

- [x] 로그 분석 완료
- [x] 원인 파악 완료
- [x] 010.game_server.ps1: TxRxEnabled 수정
- [x] 002.power_network.ps1: 균형 모드 fallback
- [x] 004.taskbar.ps1: 위젯 정책 권한 처리
- [x] 000.orchestrate.ps1: ExperimentalOptions 전달
- [x] 006.software_install.ps1: 파일 연결 스킵 로직
- [x] CLAUDE.md 버전 테이블 업데이트
- [ ] 커밋 및 푸시
