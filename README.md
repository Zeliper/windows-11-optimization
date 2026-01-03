# Windows 11 설치 및 초기 설정

## 로컬 계정 생성

<kbd>Shift</kbd> + <kbd>F10</kbd> 으로 Console Open

```cmd
start ms-cxh:localonly
```

## Powershell 권한 해제

```powershell
Set-ExecutionPolicy RemoteSigned -Force
```

## 변조 방지(Tamper Protection) 비활성화

> Windows Defender를 완전히 비활성화하려면 먼저 변조 방지를 꺼야 합니다.

**수동 설정 (필수):**
1. `Windows 보안` 앱 실행 (Win + I → 개인 정보 및 보안 → Windows 보안)
2. `바이러스 및 위협 방지` 클릭
3. `바이러스 및 위협 방지 설정`에서 `설정 관리` 클릭
4. `변조 방지`를 **끔**으로 설정

또는 PowerShell에서 설정 페이지 직접 열기:
```powershell
start windowsdefender://threatsettings
```

## 윈도우즈 업데이트 수동 설정 및 UAC 프롬프트 비활성화 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/001.disable_update.ps1 | iex
```

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/001.disable_update.ps1)

## 전원 관리, 네트워크 최적화 및 텔레메트리 비활성화 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/002.power_network.ps1 | iex
```

**전원 관리:**
- 전원 옵션을 고성능/최고 성능으로 설정
- 절전 모드, 모니터 끄기, 하드 디스크 끄기 비활성화
- USB 선택적 절전 모드 비활성화
- PCI Express 링크 상태 전원 관리 끄기

**네트워크 최적화:**
- 네트워크 어댑터 절전 모드 비활성화
- Nagle 알고리즘 비활성화
- TCP ACK 지연 비활성화

**텔레메트리 비활성화:**
- DiagTrack, dmwappushservice 서비스 비활성화
- 진단 데이터 수집 비활성화
- 피드백 요청, 광고 ID 비활성화
- 활동 기록, 맞춤형 환경 비활성화
- 텔레메트리 예약 작업 비활성화

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/002.power_network.ps1)

## Defender, OneDrive, 방화벽 스크립트

⚠️ **주의: 서버/로컬 네트워크 환경용 스크립트입니다.**

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/003.defender_onedrive_firewall.ps1 | iex
```

**Windows Defender 보호 기능 비활성화:**
- 실시간 보호 비활성화
- 개발자 드라이브 보호 비활성화 (23H2+)
- 클라우드 전송 보호 (MAPS) 비활성화
- 자동 샘플 전송 비활성화
- ⚠️ Tamper Protection이 켜져 있으면 수동 해제 필요

**Windows 방화벽 해제:**
- 도메인, 공용, 개인 프로필 방화벽 해제
- RDP(원격 데스크톱) 서비스 활성화

**OneDrive 완전 삭제:**
- OneDrive 제거
- 자동 시작 제거
- 동기화 비활성화 정책 적용
- 탐색기에서 OneDrive 숨김
- 관련 폴더 및 예약 작업 삭제

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/003.defender_onedrive_firewall.ps1)

## 작업 표시줄 및 컨텍스트 메뉴 정리 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/004.taskbar.ps1 | iex
```

**작업 표시줄 정리:**
- 검색 상자 숨김
- 작업 보기 버튼 숨김
- 위젯 버튼 숨김 (Web Experience Pack 제거)
- 채팅(Teams) 버튼 숨김
- 고정된 앱 모두 제거

**컨텍스트 메뉴:**
- Windows 10 스타일 컨텍스트 메뉴 복원

**파일 탐색기 설정:**
- 파일 탐색기 시작 위치를 "내 PC"로 변경
- 개인정보 보호 설정 해제 (최근 파일, 자주 사용 폴더 표시 안 함)
- 파일 탐색기 기록 지우기 (최근 문서, 점프 목록 등)
- 파일 확장자명 표시
- 숨김 파일 표시

> 스크립트 실행 후 Explorer가 자동으로 재시작됩니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/004.taskbar.ps1)

## 블로트웨어 제거 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/005.bloatware.ps1 | iex
```

**제거 대상:**
- Microsoft 기본 앱 (Cortana, Xbox, Teams, People, Mail, Calendar 등)
- 사전 설치된 제3자 앱 (게임, SNS, LinkedIn, 스트리밍 앱 등)
- 프로비저닝된 패키지 (새 사용자 계정 설치 방지)
- 불필요한 Windows 기능 (워드패드, 수학 인식기 등)
- 시작 메뉴 고정 앱 초기화

**바탕화면 설정:**
- 바탕화면 배경을 검은색 단색으로 설정

> 참고: 일부 시스템 보호 앱은 제거되지 않습니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/005.bloatware.ps1)

## 필수 소프트웨어 자동 설치 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/006.software_install.ps1 | iex
```

**설치 대상 (20단계):**
- Notepad++ (최신 버전 자동 감지)
- Google Chrome (Enterprise 64비트)
- 7-Zip (64비트)
- ShareX (최신 버전, 업로드 기능 비활성화, 트레이 시작)
- Honeyview (이미지 뷰어, 반디소프트 - winget 설치)
- PotPlayer (동영상 플레이어, 깔끔한 재생 화면 설정)

**파일 연결 (SetUserFTA 병렬 실행):**
- Notepad++: txt, ini, cfg, conf, config, json, xml, yaml, md, log 등 16개 확장자
- Honeyview: jpg, png, gif, bmp, webp, heic, avif, raw, psd 등 24개 이미지 확장자
- PotPlayer: mp4, mkv, avi, mov, wmv, flv, webm, ts 등 14개 동영상 확장자
- Chrome: html, htm, http, https (기본 브라우저)

**ShareX 설정:**
- 업로드 기능 비활성화
- 컨텍스트 메뉴 제거
- 시작 시 트레이 모드로 자동 실행

**PotPlayer 자동 설정:**
- 단축키: Ctrl+W=종료, Enter=전체화면, Space=재생/일시정지
- OSD 최소화 (재생 시작/탐색 시 표시 안함)
- 컨트롤 바 자동 숨김
- 자동 업데이트 비활성화

**추가 설정:**
- Windows 배경화면을 기본값으로 변경 (Spotlight 제거 → 설정 로딩 속도 개선)

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/006.software_install.ps1)

## OpenSSH 서버 및 rsync 설치 스크립트

> **참고:** 이 스크립트는 설치 시간이 오래 걸려 통합 스크립트(orchestrate)에서 제외되었습니다. 필요시 개별 실행하세요.

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/007.openssh_rsync.ps1 | iex
```

**OpenSSH 서버:**
- OpenSSH 서버/클라이언트 기능 설치
- sshd 서비스 자동 시작 설정
- 방화벽 규칙 자동 생성 (포트 22)
- 기본 셸을 PowerShell로 설정
- 비밀번호/공개키 인증 활성화

**rsync 설치:**
- cwRsync (무료 버전) 자동 다운로드 및 설치
- 시스템 PATH 환경 변수 자동 등록
- Windows에서 rsync 명령어 사용 가능

**사용 예시:**
- SSH 접속: `ssh 사용자명@컴퓨터명`
- rsync 동기화: `rsync -avz /source/ user@host:/destination/`

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/007.openssh_rsync.ps1)

## 공통 최적화 스크립트 (Windows 11 25H2)

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/008.common_optimization.ps1 | iex
```

**디스크 정리:**
- Windows 임시 파일 삭제 (%TEMP%, C:\Windows\Temp)
- Windows Update 캐시 정리
- 썸네일 캐시, 메모리 덤프, 휴지통 비우기

**DNS 설정:**
- Primary: Cloudflare 1.1.1.1
- Secondary: Google 8.8.8.8
- IPv6: Cloudflare, Google

**서비스 최적화:**
- SysMain (SuperFetch) 비활성화 - SSD 환경
- Connected Devices Platform, Maps, Fax, Error Reporting 비활성화
- AppX Deployment Service 수동 시작 (25H2)

**부팅 최적화:**
- 빠른 시작 활성화
- 부팅 메뉴 대기 시간: 3초

**추가 설정:**
- P2P 업데이트 비활성화
- 자동 앱 설치 비활성화
- 대규모 시스템 캐시 활성화 (RAM 16GB 이상)

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/008.common_optimization.ps1)

## 게임용 PC 최적화 스크립트 (Windows 11 25H2)

⚠️ **경고: 일부 보안 기능을 비활성화합니다. 게임 전용 PC에서만 권장됩니다.**

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/009.gaming_optimization.ps1 | iex
```

**보안 관련 설정 (성능 향상):**
- VBS (Virtualization-Based Security) 비활성화 (~5% 성능 향상)
- Memory Integrity (HVCI) 비활성화

**게임 최적화:**
- Hardware-accelerated GPU Scheduling 활성화
- Game Mode 최적화 및 Game DVR 비활성화
- 전체 화면 최적화 비활성화
- Xbox Game Bar 완전 비활성화

**시스템 최적화:**
- 시각 효과 비활성화 (애니메이션, 투명 효과)
- GPU 우선순위 설정 (SystemResponsiveness: 0)
- 네트워크 스로틀링 비활성화
- AppX/Delivery Optimization 서비스 수동 시작

> 재부팅 후 모든 설정이 적용됩니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/009.gaming_optimization.ps1)

## 게임 서버 최적화 스크립트 (Windows 11 25H2)

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/010.game_server.ps1 | iex
```

**TCP/IP 최적화:**
- TCP Auto-Tuning, ECN, Timestamps 활성화
- Congestion Control 알고리즘 선택 (DCTCP/CUBIC/CTCP)
- TCP Window 크기 증가 (4MB/16MB)
- MaxUserPort: 65534, TcpTimedWaitDelay: 30초
- 동적 포트 범위: 1025-65535

**네트워크 어댑터 최적화:**
- Interrupt Moderation 비활성화 (낮은 레이턴시)
- RSS (Receive Side Scaling) 활성화
- 네트워크 버퍼 크기 최적화

**QoS 정책:**
- UDP: DSCP 46 (Expedited Forwarding)
- TCP: DSCP 34 (AF41)
- 대역폭 제한 제거

**실험적 기능:**
- Native NVMe 지원 (최대 80% IOPS 향상, 선택적)

> 재부팅 후 모든 설정이 적용됩니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/010.game_server.ps1)

## IIS 웹 서버 최적화 스크립트 (Windows 11)

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/011.web_server.ps1 | iex
```

**IIS 설치 및 기본 설정:**
- IIS 웹 서버 기능 활성화
- .NET Framework 4.x 구성
- 기존 IIS 설정 자동 백업

**성능 최적화:**
- HTTP 압축 (정적/동적) 활성화
- 커널 모드 캐싱 활성화 (최대 512MB)
- HTTP/2 활성화
- Application Pool 최적화 (64비트, AlwaysRunning, Queue 5000)

**보안 강화:**
- TLS 1.2/1.3 활성화
- 약한 프로토콜 비활성화 (SSL 2.0/3.0, TLS 1.0/1.1)
- 약한 암호 비활성화 (DES, RC2, RC4, NULL)

**다음 단계:**
1. HTTPS 인증서 설치 (Let's Encrypt 또는 상용 인증서)
2. 웹 사이트 바인딩 설정
3. 방화벽 포트 개방 (80, 443)

> IIS 관리자 실행: `inetmgr`

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/011.web_server.ps1)

## 25H2 AI 기능 비활성화 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/012.ai_features.ps1 | iex
```

**Windows Recall 비활성화:**
- AllowRecallEnablement 정책 설정
- AI 데이터 분석 비활성화
- Recall 예약 작업 비활성화

**Windows Copilot 비활성화:**
- 시스템/사용자 레벨 Copilot 정책 설정
- Copilot 앱 패키지 제거
- Edge Copilot 사이드바 비활성화

**AI Actions 비활성화:**
- 파일 탐색기 AI Actions 메뉴 비활성화
- Click to Do (Smart Clipboard) 비활성화
- Input Insights (타이핑 데이터 수집) 비활성화

**앱 내 AI 기능:**
- Paint AI Image Creator 비활성화
- Notepad Rewrite AI 비활성화
- Photos AI 기능 비활성화

**서비스 및 텔레메트리:**
- AI Fabric Service 비활성화
- AI 진단 데이터 수집 비활성화
- Voice Access AI, Live Captions 비활성화

**추가 최적화 (25H2 심화):**
- AI AppX 패키지 강제 제거 (Nonremovable 포함)
- Recall Optional Feature 완전 제거
- AI 자동 설치 방지 정책 설정
- Windows Search AI 추천 비활성화 (Bing, 클라우드 검색)
- Windows Spotlight AI 추천 콘텐츠 비활성화
- ML 서비스 (mlsvc) 및 AI 예약 작업 비활성화

> 재부팅 후 모든 설정이 적용됩니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/012.ai_features.ps1)

## 개인정보 보호 최적화 스크립트

⚠️ **경고: 일부 앱 기능이 제한될 수 있습니다.**

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/013.privacy_optimization.ps1 | iex
```

**위치 서비스 비활성화:**
- 시스템/사용자 레벨 위치 서비스 비활성화
- 위치 센서 및 스크립팅 비활성화
- Geolocation Service (lfsvc) 비활성화

**진단 피드백 완전 비활성화:**
- 진단 데이터 수준 최소화 (Security)
- 피드백 요청 빈도 비활성화
- 진단 서비스 (DiagTrack, dmwappushservice) 비활성화
- Windows 오류 보고 비활성화
- 필기/타이핑 데이터 수집 비활성화

**앱 권한 제한:**
- 카메라, 마이크, 연락처, 일정, 이메일 등 20+ 항목 권한 제한
- 시스템/사용자 레벨 앱 권한 제한 적용
- 위치 권한 요청 프롬프트 비활성화

**백그라운드 앱 비활성화:**
- 전역 백그라운드 앱 비활성화
- 백그라운드 앱 정책 비활성화
- 검색 백그라운드 작업 비활성화

**동기화 설정 비활성화:**
- 설정 동기화 비활성화 (테마, 언어, 시작 메뉴 등)
- 클라우드 동기화 정책 비활성화
- OneDrive 파일 동기화 비활성화
- 클립보드 기록 및 동기화 비활성화

**활동 기록 완전 삭제:**
- 활동 피드 및 타임라인 비활성화
- 로컬 활동 기록 데이터 삭제
- 최근 사용 파일/프로그램 추적 비활성화
- 점프 목록 비활성화

**광고 추적 비활성화 강화:**
- 광고 ID 비활성화 및 삭제
- 시작 메뉴 앱 제안 비활성화
- 잠금 화면 광고/팁 비활성화
- 자동 앱 설치 및 콘텐츠 전달 비활성화
- Edge 추적 방지 강화 (Strict 모드)

> 재부팅 후 모든 설정이 적용됩니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/013.privacy_optimization.ps1)

## 저장소 최적화 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/014.storage_optimization.ps1 | iex
```

**Storage Sense 활성화 및 자동 정리:**
- Storage Sense 활성화 (매주 실행)
- 임시 파일 자동 정리
- OneDrive 파일 로컬 전용 설정 (30일 미사용 시)

**휴지통 및 다운로드 폴더 정리:**
- 휴지통 자동 비우기 (30일 후)
- 다운로드 폴더 자동 정리 (60일 미사용 파일)
- 현재 휴지통 비우기

**임시 파일 정리:**
- 임시 폴더 정리 (%TEMP%, C:\Windows\Temp)
- 프리페치 캐시 정리
- Windows Update 다운로드 캐시 정리
- 썸네일/아이콘 캐시 정리

**Windows.old 폴더 삭제:**
- Windows.old 폴더 완전 삭제
- $Windows.~BT 및 $Windows.~WS 폴더 삭제
- 디스크 정리 도구 활용

**시스템 복원 포인트 최적화:**
- 시스템 복원 최대 용량 제한 (5% 또는 최대 10GB)
- 오래된 복원 포인트 정리 (최신 1개만 유지)

**배달 최적화 캐시 정리:**
- 배달 최적화 캐시 폴더 정리
- 로컬 네트워크만 허용 설정

**로그 파일 정리:**
- Windows 로그 폴더 정리
- 이벤트 로그 정리
- CBS 로그 정리 (7일 이전)
- 메모리 덤프 파일 정리

> 모든 설정이 즉시 적용되었습니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/014.storage_optimization.ps1)

## 시작 프로그램/부팅 최적화 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/015.startup_optimization.ps1 | iex
```

**불필요한 시작 프로그램 비활성화:**
- OneDrive, Teams, Cortana, Xbox 등 자동 시작 비활성화
- Adobe, Spotify, Discord, Steam 등 일반 프로그램 자동 시작 비활성화
- 비활성화된 항목은 Run-Disabled 폴더로 이동 (복원 가능)

**부팅 지연 설정 최적화:**
- 시작 프로그램 지연 시간 0ms (즉시 시작)
- 서비스 파이프 타임아웃 60초
- 데스크톱 프로세스 분리 활성화

**프리패치/슈퍼패치 설정:**
- SSD 환경: 부팅 최적화만 활성화, 슈퍼패치 비활성화
- HDD 환경: 전체 활성화 유지
- SysMain 서비스 비활성화 (SSD)

**Windows Boot Manager 최적화:**
- 부팅 메뉴 대기 시간 0초
- Windows 복구 환경 자동 진입 비활성화
- 부팅 로그 비활성화
- 부팅 상태 정책: 모든 실패 무시

**NTFS 최적화:**
- Last Access Time 시스템 관리 모드 (SSD 최적화)
- 8dot3name 생성 비활성화 (DOS 호환성 제거)

**페이지 파일 최적화:**
- RAM 용량 기준 권장 크기 계산
- 고정 크기 설정 (조각화 방지)
- 종료 시 페이지 파일 삭제 비활성화

**로그온 스크립트 지연 제거:**
- 로그온 스크립트 비동기 실행
- 시작 스크립트 지연 비활성화
- 로그온 시 앱 자동 재시작 비활성화

> 재부팅 후 모든 설정이 적용됩니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/015.startup_optimization.ps1)

## 접근성 기능 정리 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/016.accessibility_cleanup.ps1 | iex
```

**고정 키 비활성화:**
- Shift 5회 연타 팝업 비활성화
- 고정 키 기능 완전 비활성화

**토글 키 비활성화:**
- NumLock 5초 누름 팝업 비활성화
- 토글 키 기능 완전 비활성화

**필터 키 비활성화:**
- 오른쪽 Shift 8초 누름 팝업 비활성화
- 필터 키 기능 완전 비활성화

**마우스 키 비활성화:**
- Alt+Shift+NumLock 단축키 비활성화
- 마우스 키 기능 완전 비활성화

**돋보기 자동 시작 비활성화:**
- 돋보기 자동 시작 비활성화
- 돋보기 추적 옵션 (캐럿, 마우스, 포커스) 모두 비활성화

**내레이터 자동 시작 비활성화:**
- 내레이터 자동 시작 비활성화
- Win+Enter 내레이터 단축키 비활성화

**화면 키보드 자동 시작 비활성화:**
- 화면 키보드(OSK) 자동 시작 비활성화
- 터치 키보드 자동 호출 비활성화

**고대비 테마 바로가기 비활성화:**
- Alt+Shift+PrintScreen 단축키 비활성화
- 고대비 테마 기능 비활성화

> 모든 설정이 즉시 적용되었습니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/016.accessibility_cleanup.ps1)

---

## 문서

이 프로젝트의 상세한 문서는 `Docs` 폴더에 위치합니다:

### [README.md](./Docs/README.md)
프로젝트 개요 및 문서 목차

### [SCRIPTS_OVERVIEW.md](./Docs/SCRIPTS_OVERVIEW.md)
전체 스크립트 목록 및 각 스크립트의 상세 설명, 실행 순서 권장사항

### [OPTIMIZATION_CATEGORIES.md](./Docs/OPTIMIZATION_CATEGORIES.md)
최적화 기능을 카테고리별로 분류한 상세 정보 (전원 관리, 네트워크 최적화, 보안, UI/UX, 게임 최적화, 서버 최적화 등)

### [SCRIPT_DEVELOPMENT_GUIDE.md](./Docs/SCRIPT_DEVELOPMENT_GUIDE.md)
신규 스크립트 작성 및 기존 스크립트 수정 시 준수해야 할 가이드라인 (템플릿, 명명 규칙, 색상 규칙, 에러 처리 등)

### [ORCHESTRATE_INTEGRATION.md](./Docs/ORCHESTRATE_INTEGRATION.md)
000.orchestrate.ps1과 개별 스크립트의 연동 방법, ScriptItems 등록, 프리셋 설정, 충돌 관계 정의 등

---

## 개발자 가이드

이 프로젝트에 기여하거나 스크립트를 확장하려는 개발자를 위한 가이드입니다:

### 신규 스크립트 작성
[SCRIPT_DEVELOPMENT_GUIDE.md](./Docs/SCRIPT_DEVELOPMENT_GUIDE.md)를 참조하여 다음 사항을 준수하세요:
- 파일명 규칙: `[번호].[기능명].ps1`
- 필수 헤더: UTF-8 인코딩, OrchestrateMode 확인, ProgressPreference 설정
- 색상 및 출력 규칙에 따른 일관된 UI
- 적절한 에러 처리 및 재부팅 처리

### Orchestrate 연동
[ORCHESTRATE_INTEGRATION.md](./Docs/ORCHESTRATE_INTEGRATION.md)를 참조하여:
- ScriptItems 배열에 신규 스크립트 등록
- 적절한 Group 선택 및 RequiresReboot 판단
- 필요시 프리셋에 추가
- ConflictGroups에서 충돌 관계 정의

### 프로젝트 구조 이해
[SCRIPTS_OVERVIEW.md](./Docs/SCRIPTS_OVERVIEW.md)와 [OPTIMIZATION_CATEGORIES.md](./Docs/OPTIMIZATION_CATEGORIES.md)를 읽어 전체 구조 및 기능을 파악하세요.

### 기여 방식
1. Fork 또는 Clone
2. 신규 스크립트 또는 기존 스크립트 수정
3. 개발 가이드 준수
4. Pull Request 제출

---

## 원클릭 통합 최적화 스크립트 (25H2)

Windows 11 설치 후 한 번만 실행하면 되는 대화형 통합 최적화 스크립트입니다.

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/000.orchestrate.ps1 | iex
```

**주요 기능:**
- 대화형 콘솔 메뉴로 원하는 항목 선택/해제 (체크박스 토글)
- 프리셋 지원: 기본, 게임용, 서버용, 웹서버용
- **병렬 실행**: 충돌하지 않는 스크립트는 동시 실행 (속도 향상)
- 재부팅 필요 항목 자동 그룹화 (마지막에 한 번만 재부팅)
- 25H2 AI 기능 완전 비활성화 포함

**프리셋 구성:**

| 프리셋 | 포함 항목 |
|--------|----------|
| 기본 | Update, 전원/네트워크, OneDrive, 작업표시줄, 블로트웨어, 소프트웨어, 공통최적화, AI비활성화 |
| 게임 | 기본 + 게임용 최적화 (VBS/GPU) |
| 서버 | Update, 전원/네트워크, OneDrive, 공통최적화, 게임서버 최적화 |
| 웹서버 | Update, 전원/네트워크, OneDrive, 공통최적화, IIS 최적화 |

**사용 방법:**
1. 스크립트 실행 후 콘솔 메뉴 표시
2. 숫자 키로 항목 선택/해제 또는 프리셋 선택 (B/G/S/W)
3. [R] 키로 실행 시작
4. 모든 최적화 완료 후 재부팅 안내

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/000.orchestrate.ps1)
