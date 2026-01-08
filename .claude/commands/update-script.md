# 기존 스크립트 수정 명령어

기존 PowerShell 스크립트를 수정하고 관련 문서를 업데이트합니다.

## 수정할 스크립트: $ARGUMENTS

## 수행 작업

### 1. 스크립트 확인
- `ps_scripts/` 폴더에서 해당 스크립트 찾기
- 현재 코드 분석

### 2. 수정 시 확인사항
- [ ] OrchestrateMode 지원 유지
- [ ] UTF-8 인코딩 설정 유지
- [ ] 색상 규칙 준수
- [ ] 단계 표시 형식 `[N/M]` 유지

### 3. 문서 업데이트 (변경 내용에 따라)

**파일명 변경 시:**
- CLAUDE.md 테이블 업데이트
- README.md 업데이트
- 000.orchestrate.ps1의 `$global:ScriptItems` 업데이트

**기능 설명 변경 시:**
- CLAUDE.md 설명 업데이트
- README.md 기능 목록 업데이트

**RequiresReboot 변경 시:**
- 000.orchestrate.ps1의 해당 항목 수정

### 4. 완료 후
- 변경사항 테스트
- `/commit` 명령어로 커밋
