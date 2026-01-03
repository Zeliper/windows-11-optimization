# 전체 스크립트 개요

Windows 11 25H2 최적화 스크립트 프로젝트의 전체 스크립트 목록과 각 스크립트의 상세 정보입니다.

## 스크립트 목록

| 번호 | 스크립트 파일 | 이름 | 용도 | 그룹 | 재부팅 필요 |
|------|--------------|------|------|------|------------|
| 000 | 000.orchestrate.ps1 | 오케스트레이터 | 전체 스크립트 관리 및 실행 | 시스템 | - |
| 001 | 001.disable_update.ps1 | Windows Update 수동 설정 | 자동 업데이트 비활성화 및 UAC 최적화 | 기본 | ❌ |
| 002 | 002.power_network.ps1 | 전원/네트워크 최적화 | 전원 관리, 네트워크 최적화, 텔레메트리 비활성화 | 기본 | ✅ |
| 003 | 003.defender_onedrive_firewall.ps1 | OneDrive/방화벽 설정 | OneDrive 제거, 방화벽 해제, RDP 활성화 | 기본 | ❌ |
| 004 | 004.taskbar.ps1 | 작업 표시줄/컨텍스트 메뉴 | UI 정리 및 Windows 10 스타일 메뉴 복원 | 기본 | ❌ |
| 005 | 005.bloatware.ps1 | 블로트웨어 제거 | 사전 설치 앱 및 불필요한 기능 제거 | 기본 | ❌ |
| 006 | 006.software_install.ps1 | 필수 소프트웨어 설치 | Notepad++, Chrome, 7-Zip 등 설치 | 기본 | ❌ |
| 007 | 007.openssh_rsync.ps1 | OpenSSH/rsync 설정 | SSH 서버 및 rsync 설치 | 선택 | ❌ |
| 008 | 008.common_optimization.ps1 | 공통 최적화 | DNS, 서비스, 부팅 최적화 | 기본 | ✅ |
| 009 | 009.gaming_optimization.ps1 | 게임용 최적화 | VBS 비활성화, GPU 최적화 | 게임 | ✅ |
| 010 | 010.game_server.ps1 | 게임 서버 최적화 | TCP/UDP 최적화, RSS, QoS | 서버 | ✅ |
| 011 | 011.web_server.ps1 | 웹 서버 IIS 최적화 | IIS 설치 및 성능 최적화 | 서버 | ✅ |
| 012 | 012.ai_features.ps1 | 25H2 AI 기능 비활성화 | Recall, Copilot 등 AI 기능 제거 | 25H2 | ✅ |
| 013 | 013.disable_defender.ps1 | Windows Defender 완전 비활성화 | Defender 및 모든 보호 기능 영구 비활성화 | 보안 | ✅ |
| 014 | 014.task_scheduler.ps1 | 작업 스케줄러 정리 | 불필요한 예약 작업 비활성화 | 기본 | ❌ |
| 015 | 015.privacy.ps1 | 개인정보 보호 강화 | 텔레메트리, 추적, 광고 ID 비활성화 | 기본 | ❌ |
| 016 | 016.advanced_tweaks.ps1 | 고급 시스템 조정 | 레지스트리 최적화 및 시스템 미세 조정 | 고급 | ✅ |

## 스크립트 상세 설명

### 000. 오케스트레이터 (000.orchestrate.ps1)
**용도**: 전체 스크립트 통합 관리
**그룹**: 시스템
**재부팅**: 해당없음

**주요 기능**:
- 대화형 메뉴를 통한 스크립트 선택
- 프리셋 지원 (기본, 게임, 서버, 웹서버)
- 병렬 실행 및 충돌 관리
- 재부팅 후 자동 재개
- 상태 저장 및 복원

**프리셋 구성**:
- **기본**: 1, 2, 3, 4, 5, 6, 8, 12, 14, 15, 16
- **게임**: 1, 2, 3, 4, 5, 6, 8, 9, 12, 14, 15, 16
- **서버**: 1, 2, 3, 8, 10, 13, 14, 15, 16
- **웹서버**: 1, 2, 3, 8, 11, 13, 14, 15, 16

---

### 001. Windows Update 수동 설정
**용도**: Windows 업데이트 및 UAC 설정
**그룹**: 기본
**재부팅**: 불필요

**주요 기능**:
- Windows Update를 수동 모드로 변경
- 자동 재시작 방지
- UAC 프롬프트 비활성화 (보안 유지)

---

### 002. 전원/네트워크 최적화
**용도**: 전원 관리 및 네트워크 최적화
**그룹**: 기본
**재부팅**: 필요

**주요 기능**:
- 고성능 전원 관리 옵션 활성화
- 절전 모드, 모니터 끄기, 하드 디스크 끄기 비활성화
- USB 선택적 절전 모드 비활성화
- PCI Express 전원 관리 비활성화
- 네트워크 어댑터 절전 모드 비활성화
- Nagle 알고리즘 비활성화
- 텔레메트리 비활성화 (DiagTrack, 진단 데이터)

---

### 003. OneDrive/방화벽 설정
**용도**: OneDrive 제거 및 방화벽 설정
**그룹**: 기본
**재부팅**: 불필요 (권장)

**주요 기능**:
- Windows Defender 안내 (서드파티 백신 권장)
- Windows 방화벽 완전 해제
- RDP (원격 데스크톱) 활성화
- OneDrive 완전 제거
- OneDrive 잔여 파일 및 레지스트리 정리

---

### 004. 작업 표시줄/컨텍스트 메뉴
**용도**: UI 정리 및 사용자 경험 개선
**그룹**: 기본
**재부팅**: 불필요

**주요 기능**:
- 검색 상자, 작업 보기, 위젯, 채팅 버튼 숨기기
- Windows Web Experience Pack 제거
- 작업 표시줄 고정 앱 제거
- Windows 10 스타일 컨텍스트 메뉴 복원
- 파일 탐색기 시작 위치를 "내 PC"로 변경
- 파일 탐색기 개인정보 보호 설정 해제
- 파일 확장자명 및 숨김 파일 표시

---

### 005. 블로트웨어 제거
**용도**: 사전 설치 앱 및 불필요한 기능 제거
**그룹**: 기본
**재부팅**: 불필요

**주요 기능**:
- Microsoft 기본 앱 제거 (Cortana, Xbox, Teams, OneDrive 등)
- 제3자 앱 제거 (Spotify, TikTok, LinkedIn, Candy Crush 등)
- 프로비저닝 패키지 제거 (새 사용자 설치 방지)
- Windows 선택적 기능 제거 (워드패드, XPS 서비스 등)
- 시작 메뉴 고정 앱 제거
- 바탕화면 검은색으로 설정

---

### 006. 필수 소프트웨어 설치
**용도**: 일상적인 작업에 필요한 소프트웨어 자동 설치
**그룹**: 기본
**재부팅**: 불필요

**주요 기능**:
- Notepad++ 설치 및 파일 연결
- Google Chrome 설치 및 기본 브라우저 설정
- 7-Zip 설치
- ShareX 설치 (업로드 비활성화, 컨텍스트 메뉴 제거)
- ImageGlass 설치 및 이미지 파일 연결
- MSEdgeRedirect 설치 (Edge 강제 링크 → Chrome)
- Windows 배경화면 기본 설정 (Spotlight 제거)

---

### 007. OpenSSH/rsync 설정
**용도**: SSH 서버 및 rsync 설치
**그룹**: 선택
**재부팅**: 불필요

**주요 기능**:
- OpenSSH 서버 설치 및 활성화
- SSH 기본 셸을 PowerShell로 설정
- 방화벽 규칙 설정 (포트 22)
- cwRsync 설치
- 환경 변수 PATH 설정
- SSH 보안 설정 최적화

---

### 008. 공통 최적화
**용도**: 디스크, DNS, 서비스, 부팅 최적화
**그룹**: 기본
**재부팅**: 필요

**주요 기능**:
- 디스크 정리 (임시 파일, Windows Update 캐시, 썸네일 캐시)
- DNS 설정 (Cloudflare 1.1.1.1, Google 8.8.8.8)
- 불필요한 서비스 비활성화 (SysMain, CDPSvc, MapsBroker 등)
- 부팅 최적화 (빠른 시작, 부팅 시간 제한 3초)
- AppX Deployment Service 수동 시작 (25H2)
- 메모리 최적화 (대규모 시스템 캐시, RAM 16GB 이상)
- P2P 업데이트 및 자동 앱 설치 비활성화

---

### 009. 게임용 최적화
**용도**: 게임 성능 최대화
**그룹**: 게임
**재부팅**: 필요

**주요 기능**:
- VBS (Virtualization-Based Security) 비활성화 (~5% 성능 향상)
- Memory Integrity (HVCI) 비활성화
- Hardware-accelerated GPU Scheduling 활성화
- Game Mode 활성화 및 Game DVR 비활성화
- 시각 효과 비활성화 (투명, 애니메이션)
- 전체 화면 최적화 비활성화
- Xbox Game Bar 완전 비활성화
- GPU 우선순위 및 시스템 응답성 최적화
- 네트워크 스로틀링 비활성화

---

### 010. 게임 서버 최적화
**용도**: 게임 서버 네트워크 성능 최대화
**그룹**: 서버
**재부팅**: 필요

**주요 기능**:
- TCP/IP 글로벌 최적화 (Auto-Tuning, ECN, Timestamps)
- Congestion Control 알고리즘 설정 (DCTCP, CUBIC, NewReno)
- TCP Window 크기 증가 (4MB/16MB)
- MaxUserPort 65534, TcpTimedWaitDelay 30초
- 동적 포트 범위 확장 (1025-65535)
- Interrupt Moderation 비활성화
- RSS (Receive Side Scaling) 활성화
- 네트워크 버퍼 크기 최적화
- QoS 정책 (UDP DSCP 46, TCP DSCP 34)
- Native NVMe 지원 활성화 (실험적)

---

### 011. 웹 서버 IIS 최적화
**용도**: IIS 웹 서버 설치 및 성능 최적화
**그룹**: 서버
**재부팅**: 필요

**주요 기능**:
- IIS 기능 활성화 (웹 서버, 압축, 보안, ASP.NET)
- .NET Framework 구성
- HTTP 압축 (정적/동적) 활성화
- 커널 모드 캐싱 활성화 (512MB)
- Application Pool 최적화 (64비트, AlwaysRunning)
- HTTP/2 활성화
- TLS 1.2/1.3 활성화
- 약한 프로토콜/암호 비활성화 (SSL 2.0/3.0, TLS 1.0/1.1)

---

### 012. 25H2 AI 기능 비활성화
**용도**: Windows 11 25H2 AI 기능 제거
**그룹**: 25H2
**재부팅**: 필요

**주요 기능**:
- Windows Recall 비활성화
- Windows Copilot / Edge Copilot 비활성화
- AI Actions / Click to Do 비활성화
- Input Insights (타이핑 데이터 수집) 비활성화
- Paint/Notepad/Photos AI 기능 비활성화
- AI Fabric Service 비활성화
- AI 텔레메트리 비활성화
- Voice Access AI / Live Captions 비활성화
- AI AppX 패키지 강제 제거
- Recall Optional Feature 제거
- AI 자동 설치 방지 정책
- Windows Search AI 추천 비활성화
- Windows Spotlight AI 비활성화
- ML 서비스 및 AI 예약 작업 비활성화

---

### 013. Windows Defender 완전 비활성화
**용도**: Windows Defender 및 모든 보호 기능 영구 비활성화
**그룹**: 보안
**재부팅**: 필요

**주요 기능**:
- 실시간 보호 완전 비활성화
- 클라우드 제공 보호 비활성화
- 자동 샘플 제출 비활성화
- SmartScreen 비활성화 (Edge, Explorer, Store)
- Windows Defender 서비스 완전 중지
- Defender 스캔 엔진 비활성화
- Defender 컨텍스트 메뉴 제거
- Exploit Protection 비활성화
- Controlled Folder Access 비활성화
- Network Protection 비활성화
- Tamper Protection 비활성화
- Windows Security Center 알림 비활성화
- Defender 예약 작업 모두 비활성화

**경고**: 이 스크립트는 모든 보안 기능을 비활성화합니다. 서드파티 백신 솔루션 사용을 강력히 권장합니다.

---

### 014. 작업 스케줄러 정리
**용도**: 불필요한 Windows 예약 작업 비활성화
**그룹**: 기본
**재부팅**: 불필요

**주요 기능**:
- 텔레메트리 관련 작업 비활성화 (Application Experience, Customer Experience Improvement Program)
- Windows Update 관련 불필요한 작업 비활성화
- Disk Diagnostics 작업 비활성화
- Windows Defender 예약 스캔 비활성화
- OneDrive 동기화 작업 비활성화
- Windows Error Reporting 작업 비활성화
- Consolidator 작업 비활성화
- Proxy 작업 비활성화
- 클라우드 백업 작업 비활성화
- Microsoft Compatibility Appraiser 비활성화
- Program Data Updater 비활성화
- Startup App Task 비활성화
- Family Safety 작업 비활성화
- Windows Spotlight 작업 비활성화

---

### 015. 개인정보 보호 강화
**용도**: 텔레메트리, 추적, 광고 ID 비활성화
**그룹**: 기본
**재부팅**: 불필요

**주요 기능**:
- 텔레메트리 완전 비활성화 (Security 레벨)
- 광고 ID 비활성화
- 위치 추적 비활성화
- 활동 기록 비활성화
- 앱 진단 정보 수집 비활성화
- 잉크 및 입력 개인 설정 비활성화
- 음성 인식 온라인 학습 비활성화
- 피드백 및 진단 데이터 최소화
- 맞춤형 광고 비활성화
- 타임라인 기능 비활성화
- 앱 권한 기본값 제한 (카메라, 마이크, 위치, 연락처 등)
- Cortana 개인 정보 수집 비활성화
- Windows 사용 현황 데이터 비활성화
- Bing 검색 통합 비활성화
- 웹 검색 결과 비활성화

---

### 016. 고급 시스템 조정
**용도**: 레지스트리 최적화 및 시스템 미세 조정
**그룹**: 고급
**재부팅**: 필요

**주요 기능**:
- NTFS 성능 최적화 (Last Access Time 비활성화)
- 파일 시스템 캐시 최적화
- 메모리 관리 최적화 (대규모 페이지 활성화, Paging Executive 비활성화)
- CPU 스케줄링 최적화 (멀티미디어 응답성)
- 디스크 I/O 우선순위 최적화
- 네트워크 스택 최적화 (RFC 1323, Window Scaling)
- IRPStackSize 증가 (네트워크 공유 성능)
- SuperFetch/Prefetch 비활성화
- Windows Search 인덱싱 최적화
- 시스템 복원 지점 비활성화
- 하이버네이션 파일 비활성화
- 가상 메모리 페이징 파일 최적화
- 시스템 응답성 최적화 (MMCSS)
- DMA 리매핑 비활성화 (성능 향상)
- 불필요한 시스템 사운드 비활성화

## 실행 순서 권장사항

### 일반 사용자 PC (기본 최적화)
1. 001 → 002 (재부팅) → 003 → 004 → 005 → 006 → 014 → 015 → 008 (재부팅) → 012 (재부팅) → 016 (재부팅)
   - **선택 사항**: 013 (Defender 비활성화 - 서드파티 백신 사용 시)

### 게임 PC (최대 성능)
1. 001 → 002 (재부팅) → 003 → 004 → 005 → 006 → 014 → 015 → 008 (재부팅) → 009 (재부팅) → 012 (재부팅) → 016 (재부팅)
   - **선택 사항**: 013 (Defender 비활성화 - 최대 성능 필요 시)

### 게임 서버 (네트워크 최적화)
1. 001 → 002 (재부팅) → 003 → 014 → 015 → 008 (재부팅) → 010 (재부팅) → 016 (재부팅)
   - **권장**: 013 (Defender 비활성화 - 서버 성능 향상)

### 웹 서버 (IIS 최적화)
1. 001 → 002 (재부팅) → 003 → 014 → 015 → 008 (재부팅) → 011 (재부팅) → 016 (재부팅)
   - **권장**: 013 (Defender 비활성화 - 웹 서버 성능 향상)

## 참고사항

- 재부팅 필요 항목은 가능한 한 한 번에 실행하여 재부팅 횟수를 최소화합니다.
- 000.orchestrate.ps1을 사용하면 자동으로 최적화된 실행 순서를 적용합니다.
- 일부 스크립트는 보안 기능을 비활성화하므로 용도에 맞게 선택적으로 실행하세요.
