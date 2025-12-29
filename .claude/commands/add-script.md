# 새 PowerShell 스크립트 추가

새로운 Windows 11 최적화 스크립트를 추가합니다.

## 사용법
```
/add-script {번호} {기능 설명}
```

## 작업 순서

1. **스크립트 번호 확인**: ps_scripts 폴더에서 다음 번호 확인
2. **스크립트 생성**: `ps_scripts/{번호}.{기능명}.ps1` 파일 생성
   - CLAUDE.md의 스크립트 템플릿 준수
   - UTF-8 인코딩 설정 포함
   - #Requires -RunAsAdministrator 포함
   - 단계별 진행 표시 [N/M]
   - 색상 규칙 준수
3. **README.md 업데이트**: 새 스크립트 섹션 추가
4. **CLAUDE.md 업데이트**: 스크립트 목록 테이블에 추가
5. **커밋 및 푸시**: 자동으로 git add, commit, push 수행

## 입력
$ARGUMENTS
