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
