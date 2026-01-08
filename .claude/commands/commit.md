# 프로젝트 커밋 명령어

프로젝트 규칙에 맞게 변경사항을 커밋합니다.

## 커밋 메시지 (선택): $ARGUMENTS

## 수행 작업

### 1. 변경사항 확인
- `git status`로 변경된 파일 확인
- `git diff`로 변경 내용 확인
- 최근 커밋 스타일 확인

### 2. 커밋 메시지 작성 규칙
```
Add/Update/Fix 기능 설명 (영문)

- 한글 설명 1
- 한글 설명 2

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

### 3. 커밋 유형
- `Add` - 새 기능/스크립트 추가
- `Update` - 기존 기능 개선
- `Fix` - 버그 수정
- `Remove` - 기능/파일 삭제
- `Refactor` - 코드 리팩토링

### 4. 실행
- 모든 관련 파일 스테이징 (`git add`)
- HEREDOC 형식으로 커밋 메시지 작성
- `git push origin main`으로 푸시

### 주의사항
- 새 스크립트 추가 시 CLAUDE.md, README.md, orchestrate.ps1 함께 커밋
- 민감한 정보 (.env 등) 커밋 금지
