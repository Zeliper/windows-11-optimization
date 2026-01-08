# 새 스크립트 추가 명령어

새로운 PowerShell 최적화 스크립트를 추가합니다.

## 입력 정보
- 스크립트 설명: $ARGUMENTS

## 수행 작업

### 1. 다음 번호 확인
- `ps_scripts/` 폴더에서 가장 높은 번호 확인
- 다음 번호 할당 (3자리 패딩: 001, 002, ...)

### 2. 스크립트 파일 생성
- 파일명: `{번호}.{기능명}.ps1`
- CLAUDE.md의 스크립트 템플릿 규칙 준수:
  - `#Requires -RunAsAdministrator`
  - UTF-8 인코딩 설정
  - `$global:OrchestrateMode` 지원
  - 색상 규칙 (Cyan/Yellow/Green/Red)

### 3. 문서 업데이트 (필수)
다음 파일들을 **반드시** 업데이트:

1. **CLAUDE.md**
   - "현재 스크립트 목록" 테이블에 새 항목 추가

2. **README.md**
   - 새 스크립트 섹션 추가
   - `irm | iex` 실행 명령어 포함
   - 기능 설명 추가

3. **000.orchestrate.ps1**
   - `$global:ScriptItems` 배열에 항목 추가
   - 적절한 프리셋에 추가 (기본/게임/서버/웹서버)

### 4. 완료 후
- 모든 변경사항 확인
- `/commit` 명령어로 커밋 권장
