# 스크립트 확장 가능 항목 가이드

이 문서는 기존 최적화 스크립트에 추가할 수 있는 기능들과 각 기능이 시스템에 미치는 영향을 정리합니다.

---

## 목차

1. [010.game_server.ps1 - 네트워크 확장](#1-010game_serverps1---네트워크-확장)
2. [018.memory_optimization.ps1 - 메모리 확장](#2-018memory_optimizationps1---메모리-확장)
3. [022.advanced_gaming_optimization.ps1 - 게임 최적화 확장](#3-022advanced_gaming_optimizationps1---게임-최적화-확장)
4. [우선순위 및 권장사항](#4-우선순위-및-권장사항)

---

## 1. 010.game_server.ps1 - 네트워크 확장

### 현재 구현된 기능

| 단계 | 기능 | 설명 |
|------|------|------|
| 1 | TCP/IP 글로벌 최적화 | Auto-Tuning, ECN, Timestamps, DCA, RSS |
| 2 | Congestion Control | DCTCP/CUBIC/CTCP 알고리즘 선택 |
| 3 | TCP Window 크기 | 4MB 기본, 16MB 최대 |
| 4 | 동시 연결 최적화 | MaxUserPort 65534, TIME_WAIT 30초 |
| 5 | 네트워크 어댑터 감지 | 활성 물리 어댑터 목록 |
| 6 | Interrupt Moderation | 비활성화 (저지연) |
| 7 | RSS | Receive Side Scaling 활성화 |
| 8 | 네트워크 버퍼 | 송수신 버퍼 최대화 |
| 9 | QoS 정책 | UDP DSCP 46, TCP DSCP 34 |
| 10 | 추가 최적화 | 체크섬/LSO 오프로드, Nagle 비활성화 |
| 11 | Native NVMe | 25H2 실험적 기능 |
| 12 | 설정 요약 | 현재 상태 출력 |

### 확장 가능 기능

#### 1.1 TCP Fast Open (TFO)

| 항목 | 내용 |
|------|------|
| **기능** | TCP 연결 시 첫 번째 SYN 패킷에 데이터 포함 |
| **효과** | 연결 설정 시간 1 RTT 감소 (약 50-100ms 절약) |
| **적용 대상** | 빈번한 연결/해제가 발생하는 웹 서버, API 서버 |
| **장점** | 웹 페이지 로딩 속도 향상, API 응답 시간 단축 |
| **단점** | 일부 방화벽/보안 장비에서 차단될 수 있음 |
| **위험도** | 낮음 |
| **호환성** | Windows 10 1607+ / Windows Server 2016+ |

```powershell
# 구현 예시
netsh interface tcp set global fastopen=enabled
netsh interface tcp set global fastopenfallback=enabled
```

#### 1.2 QUIC 프로토콜 최적화

| 항목 | 내용 |
|------|------|
| **기능** | UDP 기반 HTTP/3 프로토콜 설정 |
| **효과** | 패킷 손실 시에도 다른 스트림 영향 없음, 연결 마이그레이션 |
| **적용 대상** | 웹 브라우징, 스트리밍, 클라우드 게임 |
| **장점** | 불안정한 네트워크에서 성능 향상, 모바일 핸드오프 |
| **단점** | 레거시 시스템과 호환성 문제 가능 |
| **위험도** | 낮음 |
| **호환성** | Windows 11 / Edge, Chrome 최신 버전 |

```powershell
# 구현 예시 - QUIC 활성화 (기본값)
$quicPath = "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"
Set-ItemProperty -Path $quicPath -Name "EnableHttp3" -Value 1 -Type DWord
```

#### 1.3 Receive Segment Coalescing (RSC)

| 항목 | 내용 |
|------|------|
| **기능** | 여러 수신 TCP 세그먼트를 하나로 병합 |
| **효과** | CPU 인터럽트 감소, 처리량 향상 |
| **적용 대상** | 대용량 파일 전송, 스트리밍 서버 |
| **장점** | CPU 사용량 감소 (최대 30%), 처리량 증가 |
| **단점** | 지연 시간 증가 가능 (병합 대기) |
| **위험도** | 낮음 |
| **권장 설정** | 처리량 우선 시 활성화, 저지연 우선 시 비활성화 |

```powershell
# 구현 예시
# 처리량 우선 (서버)
Enable-NetAdapterRsc -Name $adapter.Name

# 저지연 우선 (게임)
Disable-NetAdapterRsc -Name $adapter.Name
```

#### 1.4 TCP Chimney Offload

| 항목 | 내용 |
|------|------|
| **기능** | TCP/IP 처리를 NIC 하드웨어로 오프로드 |
| **효과** | CPU 부하 감소, 네트워크 처리량 향상 |
| **적용 대상** | 고성능 NIC (10GbE+) 환경 |
| **장점** | CPU 사용량 대폭 감소 |
| **단점** | Windows 10 1709+에서 제거됨 (레거시 전용) |
| **위험도** | 해당 없음 (Windows 11에서 미지원) |
| **상태** | ~~추가 불필요~~ (Windows 11에서 지원 종료) |

#### 1.5 Network Direct (RDMA)

| 항목 | 내용 |
|------|------|
| **기능** | Remote Direct Memory Access - 커널 바이패스 네트워킹 |
| **효과** | 초저지연 네트워킹 (마이크로초 단위) |
| **적용 대상** | 데이터센터, 클러스터 컴퓨팅, 고빈도 거래 |
| **장점** | CPU 오버헤드 제거, 극한의 저지연 |
| **단점** | 특수 NIC 필요 (Mellanox, Intel RDMA 등) |
| **위험도** | 중간 (하드웨어 의존) |
| **호환성** | RDMA 지원 NIC + Windows Server / Windows 11 Pro for Workstations |

```powershell
# 구현 예시 (RDMA NIC 존재 시)
Enable-NetAdapterRdma -Name $adapter.Name
Get-NetAdapterRdma | Format-Table Name, Enabled, Operational
```

#### 1.6 UDP Segmentation Offload (USO)

| 항목 | 내용 |
|------|------|
| **기능** | 대형 UDP 패킷 분할을 NIC에서 처리 |
| **효과** | UDP 기반 애플리케이션 성능 향상 |
| **적용 대상** | 게임 서버, VoIP, 미디어 스트리밍 |
| **장점** | UDP 처리량 증가, CPU 부하 감소 |
| **단점** | 일부 NIC에서 미지원 |
| **위험도** | 낮음 |
| **호환성** | Windows 10 1903+ / 지원 NIC |

```powershell
# 구현 예시
Enable-NetAdapterUso -Name $adapter.Name
```

---

## 2. 018.memory_optimization.ps1 - 메모리 확장

### 현재 구현된 기능

| 단계 | 기능 | 설명 |
|------|------|------|
| 1 | 시스템 메모리 분석 | 총 RAM, 사용량 표시 |
| 2 | 페이지 파일 최적화 | RAM별 자동 크기 계산 |
| 3 | LargeSystemCache | 16GB+ 활성화, 미만 비활성화 |
| 4 | 메모리 압축 | 32GB+ 비활성화, 미만 활성화 |
| 5 | ClearPageFileAtShutdown | 빠른 종료 위해 비활성화 |
| 6 | IoPageLockLimit | RAM별 I/O 잠금 제한 |
| 7 | NDU 메모리 누수 해결 | NDU 서비스 비활성화 |

### 확장 가능 기능

#### 2.1 Superfetch/SysMain 서비스 제어

| 항목 | 내용 |
|------|------|
| **기능** | 자주 사용하는 앱을 메모리에 미리 로드 |
| **효과** | 앱 시작 시간 단축 vs 메모리 사용량 증가 |
| **적용 대상** | SSD 사용 환경 |
| **장점 (비활성화 시)** | SSD I/O 감소, 메모리 확보, SSD 수명 연장 |
| **단점 (비활성화 시)** | 앱 초기 로딩 시간 증가 (SSD에서는 미미) |
| **위험도** | 낮음 |
| **권장** | NVMe SSD: 비활성화, HDD: 활성화 유지 |

```powershell
# 구현 예시
# SSD 환경에서 비활성화
Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
Set-Service -Name "SysMain" -StartupType Disabled
Write-Host "  - SysMain (Superfetch): 비활성화" -ForegroundColor Green

# 서비스 상태 확인
$sysMainStatus = (Get-Service -Name "SysMain" -ErrorAction SilentlyContinue).Status
```

#### 2.2 Prefetch 설정

| 항목 | 내용 |
|------|------|
| **기능** | 앱 실행 패턴 학습 및 프리로드 |
| **설정값** | 0=비활성화, 1=앱만, 2=부팅만, 3=둘다 |
| **효과** | 부팅/앱 시작 시간 vs 디스크 I/O |
| **적용 대상** | 모든 Windows 시스템 |
| **장점 (값=0)** | 디스크 I/O 감소, 클린한 시스템 |
| **단점 (값=0)** | 앱 첫 실행 시 로딩 증가 |
| **위험도** | 낮음 |
| **권장** | SSD: 0 또는 2, HDD: 3 |

```powershell
# 구현 예시
$prefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"

# SSD용 설정 (앱 프리페치 비활성화, 부팅만 유지)
Set-ItemProperty -Path $prefetchPath -Name "EnablePrefetcher" -Value 2 -Type DWord

# 또는 완전 비활성화
Set-ItemProperty -Path $prefetchPath -Name "EnablePrefetcher" -Value 0 -Type DWord
```

#### 2.3 Working Set Trim 간격

| 항목 | 내용 |
|------|------|
| **기능** | 미사용 메모리 페이지를 워킹셋에서 제거하는 간격 |
| **효과** | 메모리 회수 빈도 조절 |
| **적용 대상** | 메모리 부족 시스템 또는 장시간 운영 서버 |
| **장점 (빈번)** | 더 많은 가용 메모리 확보 |
| **단점 (빈번)** | 페이지 폴트 증가, 성능 저하 가능 |
| **위험도** | 중간 |
| **권장** | 기본값 유지 (시스템 자동) |

```powershell
# 참고: Windows에서 직접적인 레지스트리 제어 없음
# 프로세스별 SetProcessWorkingSetSize API 사용
# 일반적으로 기본값 권장
```

#### 2.4 Standby List 정리 옵션

| 항목 | 내용 |
|------|------|
| **기능** | 대기 메모리(Standby List)를 수동으로 정리 |
| **효과** | 즉시 가용 메모리 확보 |
| **적용 대상** | 게임 시작 전, 메모리 집약적 작업 전 |
| **장점** | 깨끗한 메모리 상태에서 시작 |
| **단점** | 캐시된 데이터 손실, 디스크 I/O 증가 |
| **위험도** | 낮음 |
| **구현 방법** | RAMMap 또는 EmptyStandbyList API 호출 |

```powershell
# 구현 예시 - C# 코드를 PowerShell에서 호출
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class MemoryManagement {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, IntPtr Info, int Length);

    public static void ClearStandbyList() {
        // SystemMemoryListInformation = 80
        // MemoryPurgeStandbyList = 4
        int SystemMemoryListInformation = 80;
        int MemoryPurgeStandbyList = 4;

        GCHandle handle = GCHandle.Alloc(MemoryPurgeStandbyList, GCHandleType.Pinned);
        try {
            NtSetSystemInformation(SystemMemoryListInformation, handle.AddrOfPinnedObject(), sizeof(int));
        }
        finally {
            handle.Free();
        }
    }
}
"@

# 호출
[MemoryManagement]::ClearStandbyList()
```

#### 2.5 NUMA 인식 메모리 할당

| 항목 | 내용 |
|------|------|
| **기능** | 다중 소켓 시스템에서 메모리 접근 최적화 |
| **효과** | 로컬 메모리 노드 우선 사용 |
| **적용 대상** | 듀얼 소켓+ 서버, HEDT 시스템 |
| **장점** | 메모리 지연 감소, 대역폭 향상 |
| **단점** | 단일 소켓 시스템에서는 효과 없음 |
| **위험도** | 낮음 |
| **호환성** | 다중 NUMA 노드 시스템만 해당 |

```powershell
# 구현 예시 - NUMA 노드 정보 확인
$numaNodes = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfProcessors

if ($numaNodes -gt 1) {
    # NUMA 인식 활성화 (기본적으로 Windows가 자동 관리)
    $memMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $memMgmtPath -Name "FeatureSettings" -Value 1 -Type DWord
}
```

#### 2.6 메모리 압축 정책 세부 설정

| 항목 | 내용 |
|------|------|
| **기능** | 메모리 압축 알고리즘 및 임계값 조정 |
| **효과** | 압축 효율 vs CPU 오버헤드 균형 |
| **적용 대상** | RAM 16-32GB 시스템 |
| **장점** | 세밀한 메모리 관리 |
| **단점** | 잘못된 설정 시 성능 저하 |
| **위험도** | 중간 |
| **권장** | 기본값 사용 (018에서 RAM별 자동 설정) |

```powershell
# 현재 메모리 압축 상태 확인
Get-MMAgent | Format-List

# ApplicationLaunchPrefetching: 앱 실행 프리페치
# ApplicationPreLaunch: 앱 사전 실행
# MemoryCompression: 메모리 압축
# OperationAPI: 최적화 API
# PageCombining: 페이지 결합 (중복 제거)

# 예시: 페이지 결합 비활성화 (게임에서 지연 발생 시)
Disable-MMAgent -PageCombining
```

---

## 3. 022.advanced_gaming_optimization.ps1 - 게임 최적화 확장

### 현재 구현된 기능

| 단계 | 기능 | 설명 |
|------|------|------|
| 1 | Power Throttling | 비활성화 (CPU 성능 제한 해제) |
| 2 | 시스템 타이머 | useplatformtick, disabledynamictick |
| 3 | 오디오 지연 | DisableProtectedAudioDG, 우선순위 |
| 4 | 네트워크 어댑터 | Interrupt Moderation, Flow Control, EEE |
| 5 | Edge 백그라운드 | 완전 차단 |
| 6 | Print Spooler | 선택적 비활성화 |
| 7 | Start Menu | 25H2 추천 항목 비활성화 |
| 8 | Chrome 최적화 | 백그라운드, GPU 가속, 메모리 절약 |

### 확장 가능 기능

#### 3.1 WASAPI 배타 모드 설정

| 항목 | 내용 |
|------|------|
| **기능** | 앱이 오디오 장치를 독점 사용하도록 허용 |
| **효과** | 오디오 지연 최소화 (1-5ms) |
| **적용 대상** | 음악 제작, 프로 오디오, 경쟁 게임 |
| **장점** | 최저 오디오 지연, 다른 앱 간섭 없음 |
| **단점** | 독점 모드 중 다른 앱 소리 안 들림 |
| **위험도** | 낮음 |
| **호환성** | Windows Vista+ / WASAPI 지원 앱 |

```powershell
# 구현 예시 - 모든 오디오 장치에 배타 모드 허용
# 참고: 이 설정은 사용자 프로필별로 저장됨

$audioEndpointPath = "HKCU:\Software\Microsoft\Multimedia\Audio"

# 기본적으로 배타 모드는 각 오디오 장치 속성에서 설정
# 레지스트리로 전역 설정은 제한적

# 대안: 오디오 서비스 최적화
$audioServicePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Pro Audio"
if (!(Test-Path $audioServicePath)) {
    New-Item -Path $audioServicePath -Force | Out-Null
}

Set-ItemProperty -Path $audioServicePath -Name "Affinity" -Value 0 -Type DWord
Set-ItemProperty -Path $audioServicePath -Name "Background Only" -Value "False" -Type String
Set-ItemProperty -Path $audioServicePath -Name "Clock Rate" -Value 10000 -Type DWord
Set-ItemProperty -Path $audioServicePath -Name "GPU Priority" -Value 8 -Type DWord
Set-ItemProperty -Path $audioServicePath -Name "Priority" -Value 1 -Type DWord
Set-ItemProperty -Path $audioServicePath -Name "Scheduling Category" -Value "High" -Type String
Set-ItemProperty -Path $audioServicePath -Name "SFIO Priority" -Value "High" -Type String
```

#### 3.2 오디오 샘플링 레이트/비트 깊이 설정

| 항목 | 내용 |
|------|------|
| **기능** | 기본 오디오 포맷 설정 (샘플 레이트, 비트 깊이) |
| **효과** | 오디오 품질 vs 처리 부하 조절 |
| **적용 대상** | 모든 오디오 출력 장치 |
| **설정값** | 44.1kHz/16bit ~ 192kHz/32bit |
| **장점 (낮은 설정)** | CPU 부하 감소, 지연 감소 |
| **단점 (낮은 설정)** | 오디오 품질 저하 |
| **위험도** | 낮음 |
| **권장** | 게임: 48kHz/16bit, 음악: 48kHz/24bit |

```powershell
# 참고: 오디오 포맷은 장치별로 사운드 설정에서 수동 변경 권장
# PowerShell로 자동화하려면 COM 객체 또는 서드파티 도구 필요

# 대안: 오디오 향상 기능 비활성화 (지연 감소)
# 사운드 설정 > 장치 속성 > 향상 탭 > "모든 향상 기능 비활성화" 체크
```

#### 3.3 USB 폴링 레이트 최적화

| 항목 | 내용 |
|------|------|
| **기능** | USB HID 장치(마우스, 키보드) 폴링 간격 조정 |
| **효과** | 입력 지연 감소 |
| **적용 대상** | 게이밍 마우스/키보드 |
| **기본값** | 125Hz (8ms) 또는 제조사 드라이버에 따름 |
| **최적값** | 1000Hz (1ms) 또는 그 이상 |
| **장점** | 입력 응답 시간 단축 (최대 7ms 개선) |
| **단점** | CPU 인터럽트 증가 (미미) |
| **위험도** | 낮음 |
| **권장** | 마우스 제조사 소프트웨어 사용 권장 |

```powershell
# 참고: USB 폴링 레이트는 일반적으로 마우스/키보드 드라이버에서 설정
# Windows 기본 드라이버는 125Hz로 제한됨

# 대안: USB 선택적 절전 비활성화 (이미 002에 구현됨)
$usbPath = "HKLM:\SYSTEM\CurrentControlSet\Services\USB"
Set-ItemProperty -Path $usbPath -Name "DisableSelectiveSuspend" -Value 1 -Type DWord

# USB xHCI 전원 관리 비활성화
Get-PnpDevice -Class USB | ForEach-Object {
    $instancePath = $_.InstanceId
    $powerMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$instancePath\Device Parameters"
    if (Test-Path $powerMgmtPath) {
        Set-ItemProperty -Path $powerMgmtPath -Name "SelectiveSuspendEnabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }
}
```

#### 3.4 Game Bar/DVR 완전 비활성화

| 항목 | 내용 |
|------|------|
| **기능** | Xbox Game Bar 및 게임 DVR 완전 비활성화 |
| **효과** | GPU/CPU 오버헤드 제거 |
| **적용 대상** | 모든 게임 PC |
| **장점** | 프레임 드랍 감소, 입력 지연 감소, GPU 메모리 확보 |
| **단점** | 게임 녹화/캡처 기능 사용 불가 |
| **위험도** | 낮음 |
| **대안** | OBS, Nvidia ShadowPlay, AMD ReLive 사용 |

```powershell
# 구현 예시 - Game Bar 완전 비활성화

# 사용자 설정
$gameBarPath = "HKCU:\Software\Microsoft\GameBar"
if (!(Test-Path $gameBarPath)) {
    New-Item -Path $gameBarPath -Force | Out-Null
}
Set-ItemProperty -Path $gameBarPath -Name "AllowAutoGameMode" -Value 0 -Type DWord
Set-ItemProperty -Path $gameBarPath -Name "AutoGameModeEnabled" -Value 0 -Type DWord
Set-ItemProperty -Path $gameBarPath -Name "ShowStartupPanel" -Value 0 -Type DWord
Set-ItemProperty -Path $gameBarPath -Name "GamePanelStartupTipIndex" -Value 3 -Type DWord
Set-ItemProperty -Path $gameBarPath -Name "UseNexusForGameBarEnabled" -Value 0 -Type DWord

# Game DVR 정책 (시스템 전체)
$gameDVRPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (!(Test-Path $gameDVRPolicyPath)) {
    New-Item -Path $gameDVRPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $gameDVRPolicyPath -Name "AllowGameDVR" -Value 0 -Type DWord

# Game DVR 사용자 설정
$gameDVRPath = "HKCU:\System\GameConfigStore"
if (Test-Path $gameDVRPath) {
    Set-ItemProperty -Path $gameDVRPath -Name "GameDVR_Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $gameDVRPath -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord
    Set-ItemProperty -Path $gameDVRPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord
    Set-ItemProperty -Path $gameDVRPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord
    Set-ItemProperty -Path $gameDVRPath -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Value 1 -Type DWord
}

# Xbox 앱 백그라운드 차단
$xboxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
if (!(Test-Path $xboxPath)) {
    New-Item -Path $xboxPath -Force | Out-Null
}
Set-ItemProperty -Path $xboxPath -Name "AppCaptureEnabled" -Value 0 -Type DWord

Write-Host "  - Game Bar/DVR 완전 비활성화" -ForegroundColor Green
```

#### 3.5 DWM (Desktop Window Manager) 최적화

| 항목 | 내용 |
|------|------|
| **기능** | 데스크톱 합성 엔진 설정 조정 |
| **효과** | 프레임 버퍼링 및 렌더링 지연 조절 |
| **적용 대상** | 창 모드/테두리 없는 창 게임 |
| **장점** | 입력 지연 감소 (창 모드에서) |
| **단점** | 일부 시각 효과 변경 가능 |
| **위험도** | 중간 |
| **권장** | 전체 화면 게임에서는 효과 없음 |

```powershell
# 구현 예시 - DWM 최적화

$dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
if (!(Test-Path $dwmPath)) {
    New-Item -Path $dwmPath -Force | Out-Null
}

# OverlayTestMode: 5 = DWM 버퍼링 최소화
Set-ItemProperty -Path $dwmPath -Name "OverlayTestMode" -Value 5 -Type DWord

# 투명 효과 비활성화 (선택)
Set-ItemProperty -Path $dwmPath -Name "EnableAeroPeek" -Value 0 -Type DWord
Set-ItemProperty -Path $dwmPath -Name "AlwaysHibernateThumbnails" -Value 0 -Type DWord

# DWM 관련 시스템 설정
$dwmSystemPath = "HKLM:\SOFTWARE\Microsoft\Windows\DWM"
if (Test-Path $dwmSystemPath) {
    Set-ItemProperty -Path $dwmSystemPath -Name "OverlayTestMode" -Value 5 -Type DWord -ErrorAction SilentlyContinue
}

Write-Host "  - DWM 최적화 (OverlayTestMode: 5)" -ForegroundColor Green
```

#### 3.6 GPU 프로세스 우선순위

| 항목 | 내용 |
|------|------|
| **기능** | GPU 작업 스케줄링 우선순위 설정 |
| **효과** | 게임 렌더링 우선 처리 |
| **적용 대상** | 멀티 GPU 또는 GPU 공유 환경 |
| **장점** | 백그라운드 GPU 작업으로 인한 스터터링 감소 |
| **단점** | 다른 GPU 작업 지연 가능 |
| **위험도** | 낮음 |
| **호환성** | Windows 10 2004+ / WDDM 2.7+ |

```powershell
# 구현 예시 - GPU 우선순위 설정

# Games 작업 우선순위 향상
$gamesTaskPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
if (!(Test-Path $gamesTaskPath)) {
    New-Item -Path $gamesTaskPath -Force | Out-Null
}

Set-ItemProperty -Path $gamesTaskPath -Name "Affinity" -Value 0 -Type DWord
Set-ItemProperty -Path $gamesTaskPath -Name "Background Only" -Value "False" -Type String
Set-ItemProperty -Path $gamesTaskPath -Name "Clock Rate" -Value 10000 -Type DWord
Set-ItemProperty -Path $gamesTaskPath -Name "GPU Priority" -Value 8 -Type DWord  # 0-31, 8=High
Set-ItemProperty -Path $gamesTaskPath -Name "Priority" -Value 6 -Type DWord      # 1-8, 6=High
Set-ItemProperty -Path $gamesTaskPath -Name "Scheduling Category" -Value "High" -Type String
Set-ItemProperty -Path $gamesTaskPath -Name "SFIO Priority" -Value "High" -Type String

Write-Host "  - Games 작업 GPU 우선순위: 8 (High)" -ForegroundColor Green
```

#### 3.7 Fullscreen Optimizations 비활성화

| 항목 | 내용 |
|------|------|
| **기능** | Windows 전체 화면 최적화 기능 비활성화 |
| **효과** | 레거시 전체 화면 모드 사용 |
| **적용 대상** | 입력 지연에 민감한 경쟁 게임 |
| **장점** | 입력 지연 감소, 일관된 프레임 타이밍 |
| **단점** | Alt+Tab 전환 느려짐, HDR 사용 불가 |
| **위험도** | 낮음 |
| **권장** | 게임별로 개별 설정 권장 |

```powershell
# 구현 예시 - 전역 Fullscreen Optimizations 비활성화

# 시스템 전역 설정
$gameConfigPath = "HKCU:\System\GameConfigStore"
if (!(Test-Path $gameConfigPath)) {
    New-Item -Path $gameConfigPath -Force | Out-Null
}

# GameDVR_FSEBehavior: 2 = Fullscreen Optimizations 비활성화
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_FSEBehavior" -Value 2 -Type DWord
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_FSEBehaviorMode" -Value 2 -Type DWord
Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_HonorUserFSEBehaviorMode" -Value 1 -Type DWord

Write-Host "  - Fullscreen Optimizations: 비활성화 (전역)" -ForegroundColor Green

# 참고: 개별 게임 exe 파일에 대해서는 호환성 탭에서 수동 설정 필요
# 또는 레지스트리 HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
# "C:\Path\To\Game.exe" = "~ DISABLEDXMAXIMIZEDWINDOWEDMODE"
```

---

## 4. 우선순위 및 권장사항

### 4.1 확장 우선순위 매트릭스

| 순위 | 스크립트 | 기능 | 난이도 | 영향도 | 위험도 | 권장 여부 |
|------|----------|------|--------|--------|--------|-----------|
| **1** | 022 | Game Bar/DVR 완전 비활성화 | 낮음 | **높음** | 낮음 | **강력 권장** |
| **2** | 022 | Fullscreen Optimizations 비활성화 | 낮음 | **높음** | 낮음 | **강력 권장** |
| **3** | 022 | GPU 프로세스 우선순위 | 낮음 | 중간 | 낮음 | 권장 |
| **4** | 018 | Superfetch/SysMain 비활성화 | 낮음 | 중간 | 낮음 | SSD 환경 권장 |
| **5** | 018 | Prefetch 설정 | 낮음 | 중간 | 낮음 | SSD 환경 권장 |
| **6** | 022 | WASAPI Pro Audio 설정 | 중간 | 중간 | 낮음 | 오디오 민감 시 권장 |
| **7** | 010 | TCP Fast Open | 낮음 | 중간 | 낮음 | 권장 |
| **8** | 022 | DWM 최적화 | 낮음 | 낮음-중간 | 중간 | 창 모드 시 권장 |
| **9** | 018 | Standby List 정리 옵션 | 중간 | 중간 | 낮음 | 선택적 |
| **10** | 010 | UDP Segmentation Offload | 낮음 | 낮음 | 낮음 | 선택적 |
| **11** | 010 | RSC 비활성화 | 낮음 | 낮음 | 낮음 | 게임 서버만 |
| **12** | 018 | NUMA 메모리 최적화 | 낮음 | 낮음 | 낮음 | 다중 소켓만 |

### 4.2 환경별 권장 설정

#### 게임 PC (일반 사용자)

| 스크립트 | 추가 기능 | 우선순위 |
|----------|----------|----------|
| 022 | Game Bar/DVR 비활성화 | 필수 |
| 022 | Fullscreen Optimizations 비활성화 | 필수 |
| 022 | GPU 프로세스 우선순위 | 권장 |
| 018 | SysMain 비활성화 (SSD) | 권장 |

#### 경쟁 게임 / e스포츠

| 스크립트 | 추가 기능 | 우선순위 |
|----------|----------|----------|
| 022 | 위 게임 PC 전체 | 필수 |
| 022 | WASAPI Pro Audio | 권장 |
| 022 | DWM 최적화 | 권장 |
| 018 | Standby List 정리 | 선택 |

#### 게임 서버

| 스크립트 | 추가 기능 | 우선순위 |
|----------|----------|----------|
| 010 | TCP Fast Open | 권장 |
| 010 | USO 활성화 | 권장 |
| 010 | RSC 비활성화 | 권장 |
| 018 | NUMA 최적화 | 다중 소켓 시 |

#### 스트리머 / 콘텐츠 크리에이터

| 스크립트 | 추가 기능 | 우선순위 |
|----------|----------|----------|
| 022 | Game Bar/DVR 비활성화 | 필수 (OBS 사용) |
| 022 | GPU 프로세스 우선순위 | 권장 |
| 018 | 페이지 파일 최적화 | 권장 |
| 022 | Chrome 백그라운드 비활성화 | 권장 |

### 4.3 주의사항

1. **백업 권장**: 레지스트리 변경 전 시스템 복원 지점 생성
2. **테스트 필수**: 새 설정 적용 후 안정성 테스트 필요
3. **롤백 계획**: 문제 발생 시 원래 설정으로 복원할 수 있도록 기존 값 기록
4. **환경 의존성**: 일부 설정은 하드웨어/드라이버에 따라 효과가 다름

---

## 변경 이력

| 날짜 | 버전 | 내용 |
|------|------|------|
| 2025-01-09 | 1.0.0 | 초기 문서 작성 |
