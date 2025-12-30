# Windows 11 설치 및 초기 설정

## 로컬 계정 생성

<kbd>Ctrl</kbd> + <kbd>F10</kbd> 으로 Console Open

```cmd
start ms-cxh:localonly
```

## Powershell 권한 해제

```powershell
Set-ExecutionPolicy RemoteSigned -Force
```

## 윈도우즈 업데이트 중지 및 사용자 계정 컨트롤 해제 스크립트

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

## Windows Defender, OneDrive, 방화벽 해제 스크립트

⚠️ **주의: 서버/로컬 네트워크 환경용 스크립트입니다.**

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/003.defender_onedrive_firewall.ps1 | iex
```

**Windows Defender 해제:**
- 실시간 보호 비활성화
- Defender 서비스 비활성화
- 클라우드 보호 비활성화
- Security Center 알림 및 트레이 아이콘 숨김

**Windows 방화벽 해제:**
- 도메인, 공용, 개인 프로필 방화벽 해제
- 방화벽 서비스 비활성화

**OneDrive 완전 삭제:**
- OneDrive 제거
- 자동 시작 제거
- 동기화 비활성화 정책 적용
- 탐색기에서 OneDrive 숨김
- 관련 폴더 및 예약 작업 삭제

> 💡 **Tamper Protection**: Defender가 완전히 비활성화되지 않으면 Windows 보안 > 바이러스 및 위협 방지 > 설정 관리에서 "변조 방지"를 먼저 끄세요.

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

**설치 대상:**
- Notepad++ (최신 버전 자동 감지)
- Google Chrome (Enterprise 64비트)
- 7-Zip (64비트)
- ShareX (최신 버전, 업로드 기능 및 컨텍스트 메뉴 비활성화)

**특징:**
- GitHub API를 통한 최신 버전 자동 감지 (Notepad++, ShareX)
- 완전 자동(headless) 설치
- Notepad++ 파일 연결 자동 설정 (txt, ini, cfg, conf, config, properties, json, xml, yaml 등)
- Chrome 기본 브라우저 설정
- ShareX 업로드 기능 레지스트리로 비활성화
- ShareX 우클릭 컨텍스트 메뉴 제거
- 개별 설치 실패 시 다음 프로그램으로 계속 진행

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/006.software_install.ps1)

## OpenSSH 서버 및 rsync 설치 스크립트

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
