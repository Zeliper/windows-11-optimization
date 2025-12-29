# Windows 11 Optimization Scripts Project

## 프로젝트 개요

Windows 11 최적화를 위한 PowerShell 스크립트 모음입니다. 서버 및 로컬 네트워크 환경에서 사용할 수 있습니다.

## 스크립트 작성 규칙

### 파일 명명 규칙
- 파일명: `{번호}.{기능명}.ps1` (예: `005.example.ps1`)
- 번호는 3자리 숫자로 패딩 (001, 002, ...)

### 스크립트 템플릿
모든 스크립트는 다음 구조를 따릅니다:

```powershell
# 스크립트 설명
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "=== 스크립트 제목 ===" -ForegroundColor Cyan
Write-Host ""

# 각 단계는 [N/M] 형식으로 표시
Write-Host "[1/N] 작업 설명..." -ForegroundColor Yellow
# 작업 수행
Write-Host "  - 완료 메시지" -ForegroundColor Green

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
```

### 색상 규칙
- 제목/구분선: `Cyan`
- 단계 표시: `Yellow`
- 성공 메시지: `Green`
- 경고/주의: `Red`
- 일반 정보: `White`

## 자동 커밋 및 푸시

스크립트 작업 완료 후 **반드시** 다음을 수행합니다:

1. 새 스크립트 또는 수정된 파일을 스테이징
2. README.md 업데이트 (새 스크립트 추가 시)
3. 커밋 메시지 형식:
   ```
   Add/Update 기능 설명 (영문)

   - 한글 설명 1
   - 한글 설명 2

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```
4. 원격 저장소에 푸시

## README.md 업데이트 형식

새 스크립트 추가 시 README.md에 다음 형식으로 추가:

```markdown
## 스크립트 제목

관리자 권한 PowerShell에서 실행:

\`\`\`powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/{파일명} | iex
\`\`\`

**기능 카테고리:**
- 기능 1
- 기능 2

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/{파일명})
```

## 현재 스크립트 목록

| 번호 | 파일명 | 설명 |
|------|--------|------|
| 001 | disable_update.ps1 | Windows Update 정책, UAC 해제 |
| 002 | power_network.ps1 | 전원 관리, 네트워크 최적화, 텔레메트리 비활성화 |
| 003 | defender_onedrive_firewall.ps1 | Defender, OneDrive, 방화벽 해제 |
| 004 | taskbar.ps1 | 작업 표시줄 정리, 컨텍스트 메뉴 복원 |
