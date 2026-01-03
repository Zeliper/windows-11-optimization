# Windows 11 Optimization Scripts Project

## 프로젝트 개요

Windows 11 최적화를 위한 PowerShell 스크립트 모음입니다. 서버 및 로컬 네트워크 환경에서 사용할 수 있습니다.

## 📚 Docs 폴더 참조

프로젝트 문서화 자료는 `Docs/` 폴더에 있습니다:

- **[OPTIMIZATION_CATEGORIES.md](./Docs/OPTIMIZATION_CATEGORIES.md)** - 최적화 카테고리 분류 및 설명
- **[ORCHESTRATE_INTEGRATION.md](./Docs/ORCHESTRATE_INTEGRATION.md)** - Orchestrate 통합 가이드 (스크립트 추가/수정 시 필수 참조)
- **[SCRIPT_DEVELOPMENT_GUIDE.md](./Docs/SCRIPT_DEVELOPMENT_GUIDE.md)** - 스크립트 개발 가이드
- **[SCRIPTS_OVERVIEW.md](./Docs/SCRIPTS_OVERVIEW.md)** - 전체 스크립트 개요
- **[README.md](./Docs/README.md)** - Docs 폴더 설명

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

# Orchestrate 모드 확인 (통합 스크립트에서 호출 시 대화 건너뜀)
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

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

# 재부팅 확인 (OrchestrateMode에서는 건너뜀)
if (-not $global:OrchestrateMode) {
    $restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        Write-Host "10초 후 재부팅됩니다..." -ForegroundColor Red
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
}
```

### OrchestrateMode 규칙
- 모든 스크립트는 `$global:OrchestrateMode` 플래그를 확인해야 합니다
- `OrchestrateMode`가 `$true`일 때 다음을 건너뜁니다:
  - 사용자 확인 프롬프트 (`Read-Host "계속하시겠습니까?"`)
  - 재부팅 확인 프롬프트 (`Read-Host "지금 재부팅하시겠습니까?"`)
  - 선택적 기능 프롬프트 (기본값 사용)

### 색상 규칙
- 제목/구분선: `Cyan`
- 단계 표시: `Yellow`
- 성공 메시지: `Green`
- 경고/주의: `Red`
- 일반 정보: `White`

## ⚠️ 기능 수정 시 문서 업데이트 필수

스크립트를 **추가하거나 수정할 때** 다음 문서들을 **반드시** 업데이트해야 합니다:

### 필수 업데이트 문서
1. **CLAUDE.md** (이 파일)
   - "현재 스크립트 목록" 테이블 업데이트
   - 새 스크립트 추가 시 번호, 파일명, 설명 추가

2. **README.md**
   - 사용자용 스크립트 설명 추가
   - 실행 명령어 (`irm | iex`) 추가
   - 기능 카테고리 및 설명 추가

3. **000.orchestrate.ps1** (새 스크립트 추가 시)
   - `$global:ScriptItems` 배열에 항목 추가
   - 프리셋 업데이트 (필요 시)
   - **자세한 절차는 아래 "000.orchestrate.ps1 연동 체크리스트" 참조**

4. **Docs/SCRIPTS_OVERVIEW.md** (권장)
   - 전체 스크립트 개요 문서 업데이트

### 업데이트 체크리스트
- [ ] CLAUDE.md 스크립트 목록 테이블 업데이트
- [ ] README.md 스크립트 설명 추가
- [ ] 000.orchestrate.ps1 업데이트 (새 스크립트인 경우)
- [ ] Docs/SCRIPTS_OVERVIEW.md 업데이트 (선택)

## 자동 커밋 및 푸시

스크립트 작업 완료 후 **반드시** 다음을 수행합니다:

1. 새 스크립트 또는 수정된 파일을 스테이징
2. README.md 업데이트 (새 스크립트 추가 시)
3. **000.orchestrate.ps1 업데이트** (새 스크립트 추가 시 - 아래 참조)
4. 커밋 메시지 형식:
   ```
   Add/Update 기능 설명 (영문)

   - 한글 설명 1
   - 한글 설명 2

   🤖 Generated with [Claude Code](https://claude.com/claude-code)

   Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
   ```
5. 원격 저장소에 푸시

## 🔧 000.orchestrate.ps1 연동 체크리스트

새 스크립트를 추가하거나 기존 스크립트를 수정할 때 다음 절차를 따르세요.

### ✅ 스크립트 추가/수정 전 확인 사항

1. **스크립트가 OrchestrateMode를 지원하는가?**
   - [ ] `$global:OrchestrateMode` 변수 확인 코드 포함
   - [ ] OrchestrateMode 시 사용자 프롬프트 건너뛰기 구현
   - [ ] OrchestrateMode 시 재부팅 프롬프트 건너뛰기 구현

2. **스크립트 템플릿 규칙을 따르는가?**
   - [ ] UTF-8 인코딩 설정 포함
   - [ ] `#Requires -RunAsAdministrator` 포함
   - [ ] 색상 규칙 준수 (Cyan/Yellow/Green/Red)

3. **orchestrate.ps1 업데이트가 필요한가?**
   - **새 스크립트 추가 시**: **예 (필수)**
   - 기존 스크립트 수정 시: 대부분 아니오 (파일명 변경 시 필요)

### 📋 000.orchestrate.ps1 업데이트 방법

새 스크립트 추가 시 **반드시** `000.orchestrate.ps1`을 업데이트해야 합니다.

#### 1. ScriptItems 배열에 항목 추가

`$global:ScriptItems` 배열에 새 스크립트 항목을 추가합니다:

```powershell
$global:ScriptItems = @(
    # ... 기존 항목 ...
    @{ Id = 13; File = "013.new_script.ps1"; Name = "새 기능 설명"; RequiresReboot = $false; Group = "기본" }
)
```

| 속성 | 설명 |
|------|------|
| Id | 고유 번호 (메뉴에서 선택 키) |
| File | 스크립트 파일명 |
| Name | 메뉴에 표시될 이름 (한글) |
| RequiresReboot | 재부팅 필요 여부 (`$true`/`$false`) |
| Group | 그룹 표시 (기본, 서버, 게임, 25H2 등) |

#### 2. 프리셋 업데이트 (필요 시)

새 스크립트가 특정 프리셋에 포함되어야 하면 `$global:Presets`를 업데이트합니다:

```powershell
$global:Presets = @{
    "기본"   = @(1, 2, 3, 4, 5, 6, 8, 12, 13)      # 새 항목 13 추가
    "게임"   = @(1, 2, 3, 4, 5, 6, 8, 9, 12, 13)   # 게임에도 해당되면 추가
    "서버"   = @(1, 2, 3, 7, 8, 10)                 # 서버용이면 여기 추가
    "웹서버" = @(1, 2, 3, 7, 8, 11)                 # 웹서버용이면 여기 추가
}
```

#### 3. RequiresReboot 기준

다음 경우 `RequiresReboot = $true`로 설정:
- VBS/HVCI 설정 변경
- 드라이버 서비스 비활성화
- 시스템 서비스 시작 유형 변경
- 커널 레벨 설정 변경

#### 4. 통합 가이드 참조

더 자세한 orchestrate.ps1 통합 절차는 다음 문서를 참조하세요:
- **[Docs/ORCHESTRATE_INTEGRATION.md](./Docs/ORCHESTRATE_INTEGRATION.md)** - Orchestrate 통합 상세 가이드

---

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
| 000 | orchestrate.ps1 | **통합 원클릭 스크립트** (대화형 메뉴, 프리셋, 재부팅 관리) |
| 001 | disable_update.ps1 | Windows Update 수동 설정, UAC 프롬프트 비활성화 |
| 002 | power_network.ps1 | 전원 관리, 네트워크 최적화, 텔레메트리 비활성화 |
| 003 | defender_onedrive_firewall.ps1 | Defender 보호 기능 비활성화, OneDrive 삭제, 방화벽 해제 |
| 004 | taskbar.ps1 | 작업 표시줄 정리, 컨텍스트 메뉴 복원 |
| 005 | bloatware.ps1 | 블로트웨어 앱 및 기능 제거 |
| 006 | software_install.ps1 | 필수 소프트웨어 자동 설치 (Notepad++, Chrome, 7-Zip, ShareX, Honeyview, PotPlayer) |
| 008 | common_optimization.ps1 | 공통 최적화 (디스크 정리, DNS, 서비스, 부팅) |
| 009 | gaming_optimization.ps1 | 게임용 PC 최적화 (VBS, GPU, 시각효과) |
| 010 | game_server.ps1 | 게임 서버 최적화 (TCP/UDP, NVMe, QoS) |
| 011 | web_server.ps1 | 웹 서버 IIS 최적화 (압축, 캐싱, TLS) |
| 012 | ai_features.ps1 | **25H2 AI 기능 비활성화** (Recall, Copilot, AI Actions, Search AI, Spotlight 등 14단계) |
| 013 | privacy_optimization.ps1 | 개인정보 보호 강화 (위치 서비스, 권한 설정, 동기화 비활성화) |
| 014 | storage_optimization.ps1 | Storage Sense 활성화, 자동 정리 설정 |
| 015 | startup_optimization.ps1 | 부팅 시간 단축, 시작 프로그램 최적화 |
| 016 | accessibility_cleanup.ps1 | 접근성 단축키 정리 (Windows 키 + U, Shift 5회 등) |
| 017 | mouse_input_optimization.ps1 | 마우스/입력 장치 최적화 (가속 비활성화, 키보드 속도, 입력 지연) |
| 018 | memory_optimization.ps1 | 메모리 최적화 (페이지 파일, LargeSystemCache, NDU 누수 해결) |
| 019 | search_optimization.ps1 | Windows Search 최적화 (인덱싱, 클라우드 검색 비활성화) |
| 020 | registry_tweaks.ps1 | 레지스트리 미세 조정 (MenuShowDelay, IRPStackSize, LongPaths) |
| 021 | ntfs_ssd_optimization.ps1 | NTFS/SSD 최적화 (8.3 파일명, Last Access Time, Native NVMe 드라이버) |
| 022 | advanced_gaming_optimization.ps1 | 고급 게임 최적화 (Power Throttling, 타이머, 오디오, Edge 백그라운드 차단) |
