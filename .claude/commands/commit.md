# 커밋 및 푸시

현재 변경사항을 커밋하고 원격 저장소에 푸시합니다.

## 사용법
```
/commit {커밋 메시지 (선택)}
```

## 작업 순서

1. **git status 확인**: 변경된 파일 목록 확인
2. **git diff 확인**: 변경 내용 확인
3. **git add**: 모든 변경사항 스테이징
4. **git commit**: 커밋 메시지 형식 준수
   ```
   {영문 제목}

   - {한글 설명}

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```
5. **git push**: 원격 저장소에 푸시
6. **결과 출력**: 커밋 해시 및 푸시 결과 표시

## 입력
$ARGUMENTS
