# 최적화 카테고리별 기능 정리

Windows 11 최적화 스크립트를 기능 카테고리별로 분류하고, 각 카테고리에 해당하는 스크립트와 주요 기능을 매핑합니다.

---

## 1. 전원 관리

### 관련 스크립트
- **002.power_network.ps1** - 전원/네트워크 최적화

### 주요 기능

#### 전원 옵션 설정
- 고성능/최고 성능 전원 관리 옵션 활성화
- 절전 모드 비활성화 (AC/DC 모두)
- 모니터 끄기 비활성화
- 하드 디스크 끄기 비활성화
- 최대 절전 모드 비활성화

#### USB 및 PCI 전원 관리
- USB 선택적 절전 모드 비활성화
- PCI Express 링크 상태 전원 관리 끄기

#### 효과
- 시스템 응답성 향상
- USB 장치 연결 안정성 개선
- 그래픽 카드 성능 향상

---

## 2. 네트워크 최적화

### 관련 스크립트
- **002.power_network.ps1** - 전원/네트워크 최적화
- **010.game_server.ps1** - 게임 서버 최적화

### 주요 기능

#### 네트워크 어댑터 최적화 (002)
- 네트워크 어댑터 절전 모드 비활성화
- Nagle 알고리즘 비활성화
- TCP ACK 지연 비활성화

#### TCP/IP 글로벌 최적화 (010)
- TCP Auto-Tuning 설정 (normal)
- ECN (Explicit Congestion Notification) 활성화
- TCP Timestamps 활성화
- Direct Cache Access 활성화
- RSS (Receive Side Scaling) 활성화

#### Congestion Control 알고리즘 (010)
- DCTCP (데이터센터/로컬 네트워크용)
- CUBIC (일반 인터넷 환경용)
- NewReno (레거시 호환성)

#### TCP Window 크기 최적화 (010)
- TCP Window Size: 4MB
- Global Max TCP Window: 16MB
- TCP 1323 옵션 활성화 (Window Scaling)

#### 동시 연결 수 최적화 (010)
- MaxUserPort: 65534
- TcpTimedWaitDelay: 30초
- TcpNumConnections: 16777214
- 동적 포트 범위: 1025-65535

#### 네트워크 어댑터 고급 설정 (010)
- Interrupt Moderation 비활성화 (낮은 레이턴시)
- RSS 활성화 및 큐 수 최적화
- 네트워크 버퍼 크기 최적화
- UDP/TCP Checksum Offload 활성화
- Large Send Offload 활성화

#### QoS 정책 (010)
- UDP 트래픽: DSCP 46 (Expedited Forwarding)
- TCP 트래픽: DSCP 34 (AF41)
- QoS 대역폭 제한 제거 (100% 사용 가능)

#### 효과
- 네트워크 레이턴시 감소
- 동시 연결 처리 능력 향상
- 게임 서버 응답성 개선

---

## 3. 보안 및 프라이버시

### 관련 스크립트
- **001.disable_update.ps1** - Windows Update 수동 설정
- **002.power_network.ps1** - 전원/네트워크 최적화
- **003.defender_onedrive_firewall.ps1** - OneDrive/방화벽 설정
- **009.gaming_optimization.ps1** - 게임용 최적화
- **011.web_server.ps1** - 웹 서버 IIS 최적화
- **012.ai_features.ps1** - 25H2 AI 기능 비활성화

### 주요 기능

#### Windows Update 설정 (001)
- Windows Update를 수동 모드로 변경
- 자동 재시작 방지
- UAC 프롬프트 비활성화 (보안 수준 유지)

#### 텔레메트리 비활성화 (002)
- DiagTrack 서비스 비활성화
- dmwappushservice 비활성화
- 진단 데이터 수집 비활성화
- 피드백 요청 비활성화
- 광고 ID 비활성화
- 활동 기록 비활성화
- 텔레메트리 예약 작업 비활성화

#### Windows Defender 관리 (003)
- Windows Defender 안내 (서드파티 백신 권장)
- Defender는 서드파티 백신 설치 시 자동 비활성화됨

#### 방화벽 설정 (003)
- Windows 방화벽 완전 해제
- RDP 포트 (3389) 명시적 허용
- 원격 데스크톱 (RDP) 활성화
- 네트워크 레벨 인증 (NLA) 유지 (보안 강화)

#### OneDrive 제거 (003)
- OneDrive 프로세스 종료 및 제거
- OneDrive 자동 시작 제거
- OneDrive 동기화 비활성화 정책
- OneDrive 폴더 및 레지스트리 정리

#### VBS/HVCI 비활성화 (009)
- VBS (Virtualization-Based Security) 비활성화
- Memory Integrity (HVCI) 비활성화
- Credential Guard 비활성화
- **주의**: 보안 수준 저하, 게임 전용 PC에서만 사용

#### TLS 보안 설정 (011)
- TLS 1.2/1.3 활성화
- 약한 프로토콜 비활성화 (SSL 2.0/3.0, TLS 1.0/1.1)
- 약한 암호 비활성화 (DES, RC2, RC4, NULL)

#### AI 데이터 수집 차단 (012)
- AI 데이터 분석 비활성화
- Input Insights (타이핑 데이터 수집) 비활성화
- AI 텔레메트리 비활성화
- 검색 상자 AI 제안 비활성화
- 클라우드 최적화 콘텐츠 비활성화

#### 효과
- 개인정보 보호 강화
- 네트워크 대역폭 절약
- 시스템 리소스 절약

---

## 4. UI/UX 최적화

### 관련 스크립트
- **004.taskbar.ps1** - 작업 표시줄/컨텍스트 메뉴
- **009.gaming_optimization.ps1** - 게임용 최적화

### 주요 기능

#### 작업 표시줄 정리 (004)
- 검색 상자 숨기기
- 작업 보기 버튼 숨기기
- 위젯 버튼 숨기기 및 Windows Web Experience Pack 제거
- 채팅(Teams) 버튼 숨기기
- 작업 표시줄 고정 앱 모두 제거

#### 컨텍스트 메뉴 (004)
- Windows 10 스타일 컨텍스트 메뉴 복원

#### 파일 탐색기 최적화 (004)
- 시작 위치를 "내 PC"로 변경
- 최근 사용한 파일 표시 해제
- 자주 사용하는 폴더 표시 해제
- Office.com 파일 표시 해제
- 파일 탐색기 기록 삭제
- 파일 확장자명 표시
- 숨김 파일 표시

#### 시각 효과 비활성화 (009)
- 투명 효과 비활성화
- 애니메이션 효과 비활성화
- 작업 표시줄 애니메이션 비활성화

#### 효과
- 깔끔한 작업 환경
- 시스템 리소스 절약
- 사용자 생산성 향상

---

## 5. 블로트웨어 제거

### 관련 스크립트
- **005.bloatware.ps1** - 블로트웨어 제거

### 주요 기능

#### Microsoft 기본 앱 제거
- Cortana
- Bing 앱 (News, Weather, Finance, Sports 등)
- Xbox 앱 (TCUI, App, GameOverlay, GamingOverlay 등)
- OneDrive
- Mail, Calendar
- People
- Phone Link (Your Phone)
- Feedback Hub
- Windows Maps
- Groove Music, Movies & TV
- Microsoft Teams
- Windows Copilot
- Dev Home
- Quick Assist
- Sticky Notes
- New Outlook

#### 제3자 앱 제거
- Disney+
- Spotify
- Clipchamp
- TikTok
- WhatsApp
- Facebook, Instagram, Twitter
- Netflix, Amazon Prime Video
- Dolby Access
- Candy Crush 시리즈
- LinkedIn
- 기타 게임 및 엔터테인먼트 앱

#### Windows 기능 제거
- 수학 인식기
- 워드패드
- XPS 서비스
- Internet Explorer
- Windows Media Player
- 작업 폴더

#### 추가 정리
- 시작 메뉴 고정 앱 제거
- 바탕화면 검은색으로 설정
- 프로비저닝 패키지 제거 (새 사용자 설치 방지)

#### 효과
- 디스크 공간 확보
- 시스템 리소스 절약
- 깔끔한 시작 메뉴

---

## 6. 소프트웨어 설치 및 설정

### 관련 스크립트
- **006.software_install.ps1** - 필수 소프트웨어 설치
- **007.openssh_rsync.ps1** - OpenSSH/rsync 설정

### 주요 기능

#### 필수 소프트웨어 설치 (006)
- **Notepad++**: 텍스트 에디터 및 파일 연결 (.txt, .ini, .json, .xml 등)
- **Google Chrome**: 웹 브라우저 및 기본 브라우저 설정
- **7-Zip**: 압축 프로그램
- **ShareX**: 스크린샷 도구 (업로드 비활성화, 컨텍스트 메뉴 제거)
- **ImageGlass**: 이미지 뷰어 및 이미지 파일 연결
- **MSEdgeRedirect**: Edge 강제 링크 → Chrome 리다이렉트

#### 파일 연결 설정 (006)
- SetUserFTA를 사용한 파일 연결 자동화
- Notepad++: 텍스트 파일 연결
- ImageGlass: 이미지 파일 연결
- Chrome: HTML, PDF 파일 연결

#### SSH 서버 설정 (007)
- OpenSSH 서버 및 클라이언트 설치
- SSH 기본 셸을 PowerShell로 설정
- 방화벽 규칙 설정 (포트 22)
- SSH 보안 설정 (공개키 인증, 브루트포스 방지)

#### rsync 설치 (007)
- cwRsync 다운로드 및 설치
- 환경 변수 PATH 설정

#### 효과
- 즉시 사용 가능한 작업 환경
- 일관된 소프트웨어 구성
- 파일 관리 효율성 향상

---

## 7. 서비스 최적화

### 관련 스크립트
- **002.power_network.ps1** - 전원/네트워크 최적화
- **008.common_optimization.ps1** - 공통 최적화
- **009.gaming_optimization.ps1** - 게임용 최적화

### 주요 기능

#### 텔레메트리 서비스 비활성화 (002)
- DiagTrack (Connected User Experiences and Telemetry)
- dmwappushservice (WAP Push Message Routing)

#### 불필요한 서비스 비활성화 (008)
- SysMain (SuperFetch) - SSD 환경에서 불필요
- Connected Devices Platform Service
- Downloaded Maps Manager
- Retail Demo Service
- Fax 서비스
- Windows Error Reporting Service

#### AppX 서비스 최적화 (008, 009)
- AppX Deployment Service를 수동 시작으로 변경
- AppX 예약 작업 비활성화

#### Xbox 서비스 비활성화 (009)
- Xbox Game Monitoring (xbgm)
- Xbox Accessory Management (XboxGipSvc)
- Xbox Live 인증 관리자 (XblAuthManager)
- Xbox Live 게임 저장 (XblGameSave)

#### Delivery Optimization (009)
- Delivery Optimization 서비스를 수동 시작으로 변경

#### 효과
- 부팅 시간 단축
- 백그라운드 CPU/메모리 사용량 감소
- 네트워크 대역폭 절약

---

## 8. 게임 최적화

### 관련 스크립트
- **009.gaming_optimization.ps1** - 게임용 최적화
- **010.game_server.ps1** - 게임 서버 최적화

### 주요 기능

#### VBS/HVCI 비활성화 (009)
- VBS (Virtualization-Based Security) 비활성화 (~5% 성능 향상)
- Memory Integrity (HVCI) 비활성화
- Credential Guard 비활성화
- **주의**: 보안 수준 저하

#### GPU 최적화 (009)
- Hardware-accelerated GPU Scheduling 활성화
- GPU 우선순위: 8 (최고)
- 네트워크 스로틀링 비활성화

#### Game Mode 최적화 (009)
- Game Mode 활성화
- Game DVR (게임 녹화) 비활성화
- 전체 화면 최적화 비활성화
- Xbox Game Bar 완전 비활성화

#### 시각 효과 비활성화 (009)
- 투명 효과 비활성화
- 애니메이션 효과 비활성화
- 작업 표시줄 애니메이션 비활성화

#### 시스템 응답성 최적화 (009)
- SystemResponsiveness: 0 (게임 최적화)
- Priority: 6 (High)
- Scheduling Category: High

#### 네트워크 최적화 (010)
- 게임 서버용 TCP/IP 최적화
- QoS 정책 (UDP DSCP 46, TCP DSCP 34)
- Interrupt Moderation 비활성화
- RSS 활성화

#### 효과
- 게임 FPS 향상 (~5-10%)
- 입력 레이턴시 감소
- 네트워크 레이턴시 감소

---

## 9. 서버 최적화

### 관련 스크립트
- **010.game_server.ps1** - 게임 서버 최적화
- **011.web_server.ps1** - 웹 서버 IIS 최적화

### 주요 기능

#### 게임 서버 네트워크 최적화 (010)
- TCP/IP 글로벌 최적화
- Congestion Control 알고리즘 설정 (DCTCP, CUBIC, NewReno)
- TCP Window 크기 증가 (4MB/16MB)
- MaxUserPort 65534, TcpTimedWaitDelay 30초
- 동적 포트 범위 확장 (1025-65535)
- Interrupt Moderation 비활성화
- RSS 활성화
- 네트워크 버퍼 크기 최적화
- QoS 정책 설정
- Native NVMe 지원 활성화 (실험적)

#### IIS 웹 서버 최적화 (011)
- IIS 기능 활성화 (웹 서버, 압축, 보안, ASP.NET)
- .NET Framework 구성
- HTTP 압축 (정적/동적) 활성화
- 커널 모드 캐싱 활성화 (512MB)
- Application Pool 최적화 (64비트, AlwaysRunning)
- HTTP/2 활성화
- TLS 1.2/1.3 활성화
- 약한 프로토콜/암호 비활성화

#### 효과
- 동시 접속자 처리 능력 향상
- 네트워크 레이턴시 감소
- 웹 서버 응답 속도 향상
- 보안 강화

---

## 10. AI 기능 제거 (Windows 11 25H2)

### 관련 스크립트
- **012.ai_features.ps1** - 25H2 AI 기능 비활성화

### 주요 기능

#### Windows Recall 비활성화
- AllowRecallEnablement 비활성화
- DisableAIDataAnalysis 활성화
- Recall 예약 작업 비활성화
- Recall Optional Feature 제거

#### Windows Copilot 비활성화
- TurnOffWindowsCopilot 활성화 (사용자/시스템 레벨)
- Copilot 앱 패키지 제거
- Edge Copilot 사이드바 비활성화

#### AI Actions / Click to Do 비활성화
- 파일 탐색기 AI Actions 메뉴 비활성화
- Click to Do (Smart Clipboard) 비활성화

#### Input Insights 비활성화
- InsightsEnabled 비활성화
- 입력 개인 맞춤화 비활성화

#### 앱 내 AI 기능 비활성화
- Paint AI Image Creator 비활성화
- Notepad Rewrite AI 비활성화
- Photos AI 기능 비활성화

#### AI 서비스 비활성화
- AIXHost (AI Experience Host)
- AIFabricService (AI Fabric Service)
- ML 서비스 (mlsvc, WMPNetworkSvc)

#### AI 텔레메트리 비활성화
- AI 진단 데이터 수집 비활성화
- 검색 상자 AI 제안 비활성화
- 클라우드 최적화 콘텐츠 비활성화

#### Voice Access AI 비활성화
- AIVoiceEnabled 비활성화
- Live Captions 비활성화

#### AI AppX 패키지 제거
- Copilot, Recall, AI 관련 패키지 강제 제거
- 프로비저닝 패키지 제거

#### AI 자동 설치 방지
- ContentDeliveryManager 설정
- 앱 자동 설치 비활성화
- AI 자동 배포 정책 설정

#### Windows Search AI 비활성화
- Bing/Cloud 검색 비활성화
- 검색 하이라이트 비활성화
- 검색 히스토리 비활성화

#### Windows Spotlight AI 비활성화
- Spotlight 및 추천 콘텐츠 비활성화
- 잠금 화면 팁 비활성화

#### AI 예약 작업 비활성화
- AI, Shell\AI, WindowsAI 경로의 예약 작업 비활성화

#### 효과
- 개인정보 보호 강화
- 시스템 리소스 절약
- 네트워크 대역폭 절약
- AI 데이터 수집 차단

---

## 11. 개인정보 보호 강화

### 관련 스크립트
- **013.privacy_hardening.ps1** - 개인정보 보호 강화

### 주요 기능

#### 앱 권한 차단
- 위치 접근 차단
- 카메라 접근 차단
- 마이크 접근 차단
- 연락처/달력/통화 기록 접근 차단
- 알림/계정 정보 접근 차단
- 백그라운드 앱 실행 차단

#### 광고 및 추적 차단
- 광고 ID 비활성화
- 앱 추적 차단
- 웹사이트 언어 목록 접근 차단
- 음성 인식 온라인 서비스 비활성화

#### Windows 추적 기능 비활성화
- 활동 기록 비활성화
- 클립보드 동기화 비활성화
- Timeline 기능 비활성화
- 피드백 및 진단 데이터 최소화

#### 효과
- 개인정보 유출 방지
- 앱 권한 최소화
- 광고 추적 차단
- 시스템 리소스 절약

---

## 12. Storage 관리

### 관련 스크립트
- **014.storage_management.ps1** - Storage 관리

### 주요 기능

#### Storage Sense 최적화
- Storage Sense 활성화
- 임시 파일 자동 정리
- 휴지통 자동 비우기 (30일)
- 다운로드 폴더 자동 정리 (60일)

#### 디스크 정리 자동화
- Windows 업데이트 정리
- 임시 파일 정리
- 축소판 캐시 정리
- 시스템 오류 보고서 정리

#### 저장소 최적화
- OneDrive Files On-Demand 비활성화
- 압축 메모리 최적화
- 페이지 파일 최적화

#### 효과
- 디스크 공간 확보
- 자동 정리로 유지보수 감소
- 저장소 성능 향상
- 시스템 안정성 향상

---

## 13. 시작 및 부팅 최적화

### 관련 스크립트
- **015.startup_boot.ps1** - 시작 및 부팅 최적화

### 주요 기능

#### 부팅 최적화
- 빠른 시작 활성화
- 부팅 메뉴 시간 초과 단축 (3초)
- 불필요한 시작 프로그램 비활성화
- 시작 프로그램 지연 시작 설정

#### UEFI/BIOS 최적화
- Ultra Fast Boot 지원 설정
- 부팅 순서 최적화
- 불필요한 부팅 장치 비활성화

#### 로그인 최적화
- 자동 로그인 설정 (선택사항)
- 로그인 화면 배경 비활성화
- 시작 지연 감소

#### 효과
- 부팅 시간 단축
- 시스템 시작 속도 향상
- 로그인 시간 단축
- 사용자 경험 개선

---

## 14. 접근성 정리

### 관련 스크립트
- **016.accessibility_cleanup.ps1** - 접근성 정리

### 주요 기능

#### 접근성 기능 비활성화
- 내레이터 비활성화
- 돋보기 비활성화
- 화상 키보드 비활성화
- 고대비 테마 비활성화

#### 접근성 단축키 비활성화
- 고정 키 비활성화
- 필터 키 비활성화
- 토글 키 비활성화
- 마우스 키 비활성화

#### 접근성 서비스 정리
- 접근성 관련 서비스 비활성화
- 접근성 예약 작업 비활성화
- 접근성 앱 제거

#### 효과
- 시스템 리소스 절약
- 부팅 시간 단축
- 불필요한 기능 제거
- 깔끔한 시스템 환경

---

## 카테고리별 스크립트 매핑 요약

| 카테고리 | 주요 스크립트 | 재부팅 필요 |
|---------|-------------|-----------|
| **전원 관리** | 002 | ✅ |
| **네트워크 최적화** | 002, 010 | ✅ |
| **보안/프라이버시** | 001, 002, 003, 009, 011, 012 | 혼합 |
| **UI/UX 최적화** | 004, 009 | 혼합 |
| **블로트웨어 제거** | 005 | ❌ |
| **소프트웨어 설치** | 006, 007 | ❌ |
| **서비스 최적화** | 002, 008, 009 | 혼합 |
| **게임 최적화** | 009, 010 | ✅ |
| **서버 최적화** | 010, 011 | ✅ |
| **AI 기능 제거** | 012 | ✅ |
| **개인정보 보호 강화** | 013 | 혼합 |
| **Storage 관리** | 014 | ❌ |
| **시작 및 부팅 최적화** | 015 | ✅ |
| **접근성 정리** | 016 | 혼합 |

---

## 용도별 추천 카테고리

### 일반 사용자 PC
- 전원 관리
- 보안/프라이버시
- UI/UX 최적화
- 블로트웨어 제거
- 소프트웨어 설치
- 서비스 최적화
- AI 기능 제거

### 게임 PC
- 전원 관리
- 네트워크 최적화
- UI/UX 최적화
- 블로트웨어 제거
- 소프트웨어 설치
- 서비스 최적화
- 게임 최적화
- AI 기능 제거

### 게임 서버
- 전원 관리
- 네트워크 최적화
- 보안/프라이버시
- 서비스 최적화
- 서버 최적화

### 웹 서버
- 전원 관리
- 네트워크 최적화
- 보안/프라이버시
- 서비스 최적화
- 서버 최적화

---

## 주의사항

1. **보안 카테고리**: 일부 기능은 보안 수준을 낮출 수 있습니다 (예: VBS 비활성화).
2. **게임 최적화**: 게임 전용 PC에서만 사용을 권장합니다.
3. **서버 최적화**: 프로덕션 환경 적용 전 테스트 필수입니다.
4. **AI 기능 제거**: Windows 11 25H2 이상에서만 작동합니다.
5. **재부팅**: 대부분의 최적화는 재부팅 후 적용됩니다.
