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

## 작업 표시줄 정리 스크립트

관리자 권한 PowerShell에서 실행:

```powershell
irm https://raw.githubusercontent.com/Zeliper/windows-11-optimization/main/ps_scripts/004.taskbar.ps1 | iex
```

**작업 표시줄 정리:**
- 검색 상자 숨김
- 작업 보기 버튼 숨김
- 위젯 버튼 숨김
- 채팅(Teams) 버튼 숨김
- 고정된 앱 모두 제거
- 작업 표시줄 캐시 초기화

> 스크립트 실행 후 Explorer가 자동으로 재시작됩니다.

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/004.taskbar.ps1)
