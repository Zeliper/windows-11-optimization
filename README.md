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

## 전원 관리 및 네트워크 최적화 스크립트

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

[스크립트 보기](https://github.com/Zeliper/windows-11-optimization/blob/main/ps_scripts/002.power_network.ps1)
