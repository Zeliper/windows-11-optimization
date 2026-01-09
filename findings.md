# Findings - 스크립트 확장 작업

## 기존 코드 분석

### 018.memory_optimization.ps1 현재 구조
- 총 7단계 (v1.0.0)
- 시스템 메모리 분석
- 페이지 파일 최적화
- LargeSystemCache 설정
- 메모리 압축 설정
- ClearPageFileAtShutdown
- IoPageLockLimit
- NDU 메모리 누수 해결

### 022.advanced_gaming_optimization.ps1 현재 구조
- 총 8단계 (v1.0.0)
- Power Throttling 비활성화
- 시스템 타이머 최적화
- 오디오 지연 최소화
- 네트워크 어댑터 최적화
- Edge 백그라운드 차단
- Print Spooler 설정
- 25H2 Start Menu 최적화
- Chrome 성능 최적화

## 드라이브 타입 감지 방법

### PowerShell 명령어
```powershell
# 시스템 드라이브 파티션 정보
$systemDrive = $env:SystemDrive.TrimEnd(':')
$partition = Get-Partition -DriveLetter $systemDrive
$diskNumber = $partition.DiskNumber

# 물리 디스크 정보
$physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $diskNumber }

# 주요 속성
# MediaType: SSD, HDD, Unspecified
# BusType: NVMe, SATA, SAS, USB, RAID 등
```

### 드라이브 타입별 권장 설정
| 드라이브 | SysMain | Prefetch | 이유 |
|---------|---------|----------|------|
| NVMe | Disabled | 0 | I/O 이미 빠름, 프리페치 불필요 |
| SATA SSD | Disabled | 2 | 부팅만 유지, 앱은 불필요 |
| HDD | Automatic | 3 | 프리페치로 앱 로딩 개선 |

## 로깅 시스템 설계

### 로그 파일 위치
`$env:USERPROFILE\Documents\Windows11Optimizer_YYYYMMDD_HHMMSS.log`

### 로그 구조
1. 헤더: 실행 시간, 스크립트 정보, 시스템 정보
2. 단계별 결과: 상태, 이전값, 새값, 동작
3. Summary: 적용/스킵/실패 카운트

## Game Bar/DVR 레지스트리 경로

### 사용자 설정
- `HKCU:\Software\Microsoft\GameBar` - Game Bar 메인 설정
- `HKCU:\System\GameConfigStore` - Game DVR 설정
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR` - Xbox 캡처

### 시스템 정책
- `HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR` - DVR 정책

## DWM 최적화 경로

- `HKCU:\Software\Microsoft\Windows\DWM` - 사용자 DWM 설정
- `HKLM:\SOFTWARE\Microsoft\Windows\DWM` - 시스템 DWM 설정
- `OverlayTestMode = 5` - 버퍼링 최소화

## 발견된 이슈

(작업 중 발견되는 이슈 기록)

## 참고 자료

- Docs/SCRIPT_EXTENSION_GUIDE.md - 확장 기능 상세 설명
- CLAUDE.md - 프로젝트 규칙 및 템플릿
