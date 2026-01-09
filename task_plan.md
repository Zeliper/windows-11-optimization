# 스크립트 확장 및 최적화 작업 계획

## 개요

기존 스크립트(018, 022)에 새로운 기능을 추가하고, 전체 스크립트에 공통적으로 적용할 개선사항을 구현합니다.

---

## 작업 목록

### Phase 1: 018.memory_optimization.ps1 확장

#### 1.1 시스템 드라이브 타입 감지 기능 추가

**목표:** OS 드라이브가 NVMe인지 SATA인지 자동 식별

**구현 방법:**
```powershell
# 시스템 드라이브 식별
$systemDrive = $env:SystemDrive.TrimEnd(':')
$disk = Get-PhysicalDisk | Where-Object {
    (Get-Disk | Where-Object { $_.Number -eq $_.DeviceId }).PartitionStyle -ne $null
}

# 또는 WMI 사용
$osDrive = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty SystemDrive
$partition = Get-Partition -DriveLetter $osDrive.TrimEnd(':')
$disk = Get-Disk -Number $partition.DiskNumber
$physicalDisk = Get-PhysicalDisk -DeviceNumber $disk.Number

# MediaType: SSD, HDD, Unspecified
# BusType: NVMe, SATA, SAS, USB 등
$mediaType = $physicalDisk.MediaType
$busType = $physicalDisk.BusType
```

**출력 예시:**
```
[시스템 드라이브 분석]
  - 드라이브: C:
  - 미디어 타입: SSD
  - 버스 타입: NVMe
  - 모델: Samsung 980 PRO 1TB
  → NVMe SSD 감지됨: Superfetch/Prefetch 비활성화 권장
```

#### 1.2 Superfetch/SysMain 자동 설정

**로직:**
| 드라이브 타입 | 동작 |
|--------------|------|
| NVMe SSD | SysMain 비활성화 (I/O 감소, SSD 수명) |
| SATA SSD | SysMain 비활성화 (I/O 감소) |
| HDD | SysMain 활성화 유지 (앱 로딩 속도) |

**구현:**
```powershell
# 현재 상태 확인
$sysMainService = Get-Service -Name "SysMain" -ErrorAction SilentlyContinue
$currentStatus = $sysMainService.Status
$currentStartType = $sysMainService.StartType

# 드라이브 타입에 따른 처리
if ($busType -eq "NVMe" -or $mediaType -eq "SSD") {
    if ($currentStartType -ne "Disabled") {
        Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "SysMain" -StartupType Disabled
        $action = "비활성화됨"
    } else {
        $action = "이미 비활성화됨 (스킵)"
    }
} else {
    # HDD: 활성화 유지
    $action = "활성화 유지 (HDD)"
}
```

#### 1.3 Prefetch 자동 설정

**로직:**
| 드라이브 타입 | EnablePrefetcher 값 | 설명 |
|--------------|---------------------|------|
| NVMe SSD | 0 | 완전 비활성화 |
| SATA SSD | 2 | 부팅만 활성화 |
| HDD | 3 | 앱+부팅 모두 활성화 |

**구현:**
```powershell
$prefetchPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
$currentValue = (Get-ItemProperty -Path $prefetchPath -Name "EnablePrefetcher" -ErrorAction SilentlyContinue).EnablePrefetcher

if ($busType -eq "NVMe") {
    $targetValue = 0
    $description = "완전 비활성화 (NVMe)"
} elseif ($mediaType -eq "SSD") {
    $targetValue = 2
    $description = "부팅만 활성화 (SATA SSD)"
} else {
    $targetValue = 3
    $description = "앱+부팅 활성화 (HDD)"
}

if ($currentValue -ne $targetValue) {
    Set-ItemProperty -Path $prefetchPath -Name "EnablePrefetcher" -Value $targetValue -Type DWord
    $action = "변경됨: $currentValue → $targetValue"
} else {
    $action = "이미 최적값 (스킵)"
}
```

---

### Phase 2: 022.advanced_gaming_optimization.ps1 확장

#### 2.1 Game Bar/DVR 완전 비활성화 추가

**새 단계 추가:** `[9/10] Game Bar/DVR 완전 비활성화`

**구현할 설정:**
```powershell
# 1. Game Bar 사용자 설정
$gameBarPath = "HKCU:\Software\Microsoft\GameBar"
$settings = @{
    "AllowAutoGameMode" = 0
    "AutoGameModeEnabled" = 0
    "ShowStartupPanel" = 0
    "GamePanelStartupTipIndex" = 3
    "UseNexusForGameBarEnabled" = 0
}

# 2. Game DVR 정책 (시스템 전체)
$gameDVRPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
Set-ItemProperty -Path $gameDVRPolicyPath -Name "AllowGameDVR" -Value 0 -Type DWord

# 3. Game DVR 사용자 설정
$gameConfigPath = "HKCU:\System\GameConfigStore"
$configSettings = @{
    "GameDVR_Enabled" = 0
    "GameDVR_FSEBehavior" = 2
    "GameDVR_FSEBehaviorMode" = 2
    "GameDVR_HonorUserFSEBehaviorMode" = 1
    "GameDVR_DXGIHonorFSEWindowsCompatible" = 1
}

# 4. Xbox 앱 캡처 비활성화
$xboxPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
Set-ItemProperty -Path $xboxPath -Name "AppCaptureEnabled" -Value 0 -Type DWord
```

**스킵 로직:**
```powershell
# 각 설정별로 현재 값 확인 후 다르면 적용
foreach ($key in $settings.Keys) {
    $current = (Get-ItemProperty -Path $gameBarPath -Name $key -ErrorAction SilentlyContinue).$key
    if ($current -ne $settings[$key]) {
        Set-ItemProperty -Path $gameBarPath -Name $key -Value $settings[$key] -Type DWord
        # 로그: "적용됨"
    } else {
        # 로그: "스킵 (이미 설정됨)"
    }
}
```

#### 2.2 DWM 최적화 추가

**새 단계 추가:** `[10/10] DWM 최적화`

**구현할 설정:**
```powershell
$dwmPath = "HKCU:\Software\Microsoft\Windows\DWM"

# OverlayTestMode: 5 = DWM 버퍼링 최소화
$currentOverlay = (Get-ItemProperty -Path $dwmPath -Name "OverlayTestMode" -ErrorAction SilentlyContinue).OverlayTestMode

if ($currentOverlay -ne 5) {
    Set-ItemProperty -Path $dwmPath -Name "OverlayTestMode" -Value 5 -Type DWord
    $action = "적용됨"
} else {
    $action = "스킵 (이미 설정됨)"
}

# 시스템 DWM 설정 (선택적)
$dwmSystemPath = "HKLM:\SOFTWARE\Microsoft\Windows\DWM"
if (Test-Path $dwmSystemPath) {
    Set-ItemProperty -Path $dwmSystemPath -Name "OverlayTestMode" -Value 5 -Type DWord -ErrorAction SilentlyContinue
}
```

---

### Phase 3: 공통 개선사항

#### 3.1 로깅 시스템 구현

**로그 파일 경로:** `%USERPROFILE%\Documents\Windows11Optimizer_YYYYMMDD_HHMMSS.log`

**로그 포맷:**
```
================================================================================
Windows 11 Optimization Log
================================================================================
실행 시간: 2025-01-09 15:30:45
스크립트: 018.memory_optimization.ps1 v1.0.1
시스템 정보:
  - OS: Windows 11 Pro 25H2 (Build 26100)
  - RAM: 32 GB
  - 시스템 드라이브: NVMe SSD (Samsung 980 PRO)
================================================================================

[1/8] 시스템 메모리 분석
  상태: 완료
  결과: 총 RAM 32GB, 사용 가능 24.5GB

[2/8] 시스템 드라이브 분석
  상태: 완료
  드라이브: C:
  미디어 타입: SSD
  버스 타입: NVMe
  모델: Samsung 980 PRO 1TB

[3/8] Superfetch/SysMain 설정
  이전 값: Automatic
  목표 값: Disabled
  동작: 적용됨 (NVMe SSD 감지)

[4/8] Prefetch 설정
  이전 값: 3
  목표 값: 0
  동작: 적용됨 (NVMe SSD)

...

================================================================================
Summary
================================================================================
총 단계: 8
적용됨: 5
스킵됨: 3 (이미 최적 설정)
실패: 0

권장 사항:
  - 재부팅 필요: 예
  - 예상 효과: SSD I/O 감소, 메모리 효율 향상
================================================================================
```

**구현:**
```powershell
# 로그 초기화
$logFileName = "Windows11Optimizer_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$global:LogFilePath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) $logFileName
$global:LogEntries = @()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Step,
        [string]$Status,    # "적용됨", "스킵됨", "실패"
        [string]$Message,
        [string]$PreviousValue = "",
        [string]$NewValue = ""
    )

    $entry = @{
        Step = $Step
        Status = $Status
        Message = $Message
        PreviousValue = $PreviousValue
        NewValue = $NewValue
        Timestamp = Get-Date -Format "HH:mm:ss"
    }

    $global:LogEntries += $entry

    switch ($Status) {
        "적용됨" { $global:AppliedCount++ }
        "스킵됨" { $global:SkippedCount++ }
        "실패" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    # 로그 파일 생성 및 저장
    $logContent = @"
================================================================================
Windows 11 Optimization Log
================================================================================
실행 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
스크립트: $scriptName v$scriptVersion
...
"@

    $logContent | Set-Content -Path $global:LogFilePath -Encoding UTF8
}
```

#### 3.2 스킵 로직 공통 함수

```powershell
function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$StepName
    )

    # 경로 생성
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    # 현재 값 확인
    $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name

    if ($currentValue -eq $Value) {
        Write-Host "  - $Name : 이미 설정됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "$Name 이미 최적값" -PreviousValue $currentValue -NewValue $Value
        return $false
    }

    # 값 설정
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
    Write-Host "  - $Name : $currentValue → $Value" -ForegroundColor Green
    Write-OptLog -Step $StepName -Status "적용됨" -Message "$Name 변경됨" -PreviousValue $currentValue -NewValue $Value
    return $true
}

function Set-ServiceIfDifferent {
    param(
        [string]$ServiceName,
        [string]$StartupType,
        [bool]$StopService = $false,
        [string]$StepName
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Host "  - $ServiceName : 서비스 없음 (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "서비스 없음"
        return $false
    }

    $currentStartType = $service.StartType.ToString()

    if ($currentStartType -eq $StartupType) {
        Write-Host "  - $ServiceName : 이미 $StartupType (스킵)" -ForegroundColor Gray
        Write-OptLog -Step $StepName -Status "스킵됨" -Message "이미 $StartupType"
        return $false
    }

    if ($StopService -and $service.Status -eq "Running") {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    }

    Set-Service -Name $ServiceName -StartupType $StartupType
    Write-Host "  - $ServiceName : $currentStartType → $StartupType" -ForegroundColor Green
    Write-OptLog -Step $StepName -Status "적용됨" -Message "변경됨" -PreviousValue $currentStartType -NewValue $StartupType
    return $true
}
```

#### 3.3 실행 속도 최적화

**병렬 레지스트리 처리:**
```powershell
# 여러 레지스트리 설정을 한 번에 처리
$registrySettings = @(
    @{ Path = "HKCU:\..."; Name = "Setting1"; Value = 0 }
    @{ Path = "HKCU:\..."; Name = "Setting2"; Value = 1 }
    @{ Path = "HKLM:\..."; Name = "Setting3"; Value = 0 }
)

# 배치 처리
foreach ($setting in $registrySettings) {
    Set-RegistryIfDifferent @setting -StepName $stepName
}
```

**서비스 상태 캐싱:**
```powershell
# 시작 시 한 번만 서비스 목록 조회
$global:ServiceCache = Get-Service | Group-Object -Property Name -AsHashTable
```

---

### Phase 4: 버전 및 문서 업데이트

#### 4.1 스크립트 버전 업데이트

| 스크립트 | 현재 버전 | 새 버전 | 변경 사항 |
|----------|----------|---------|----------|
| 018.memory_optimization.ps1 | v1.0.0 | v1.1.0 | 드라이브 감지, SysMain/Prefetch 자동화, 로깅 |
| 022.advanced_gaming_optimization.ps1 | v1.0.0 | v1.1.0 | Game Bar/DVR, DWM 최적화, 로깅 |

#### 4.2 문서 업데이트

- [ ] CLAUDE.md 스크립트 버전 업데이트
- [ ] Docs/SCRIPT_EXTENSION_GUIDE.md 구현 완료 표시
- [ ] README.md 새 기능 설명 추가

---

## 작업 순서

1. **공통 로깅 모듈 작성** (재사용 가능한 함수)
2. **018.memory_optimization.ps1 수정**
   - 드라이브 타입 감지 추가
   - SysMain 자동 설정 추가
   - Prefetch 자동 설정 추가
   - 로깅 통합
   - 스킵 로직 적용
3. **022.advanced_gaming_optimization.ps1 수정**
   - Game Bar/DVR 비활성화 추가
   - DWM 최적화 추가
   - 로깅 통합
   - 스킵 로직 적용
4. **테스트**
   - Hyper-V VM에서 실행 테스트
   - 로그 파일 확인
   - 스킵 로직 확인 (2회 실행 시)
5. **문서 업데이트 및 커밋**

---

## 예상 결과

### 018.memory_optimization.ps1 실행 시

```
=== Windows 11 메모리 최적화 v1.1.0 ===
페이지 파일 최적화, SysMain/Prefetch 자동 설정을 수행합니다.

[1/9] 시스템 메모리 분석 중...
  - 총 RAM: 32 GB
  - 사용 가능 RAM: 24.5 GB
  - 사용 중: 7.5 GB (23.4%)

[2/9] 시스템 드라이브 분석 중...
  - 드라이브: C:
  - 미디어 타입: SSD
  - 버스 타입: NVMe
  - 모델: Samsung 980 PRO 1TB
  → NVMe SSD 감지됨

[3/9] Superfetch/SysMain 설정 중...
  - 현재 상태: Running (Automatic)
  - 목표 상태: Disabled (NVMe SSD)
  - SysMain: Automatic → Disabled (적용됨)

[4/9] Prefetch 설정 중...
  - 현재 값: 3 (앱+부팅)
  - 목표 값: 0 (비활성화, NVMe)
  - EnablePrefetcher: 3 → 0 (적용됨)

...

========================================
메모리 최적화가 완료되었습니다!
========================================

Summary:
  - 적용됨: 6개
  - 스킵됨: 3개 (이미 최적 설정)
  - 실패: 0개

로그 파일: C:\Users\User\Documents\Windows11Optimizer_20250109_153045.log
```

### 022.advanced_gaming_optimization.ps1 실행 시

```
=== Windows 11 고급 게임 최적화 v1.1.0 ===

...

[9/10] Game Bar/DVR 완전 비활성화 중...
  - AllowAutoGameMode: 이미 0 (스킵)
  - AutoGameModeEnabled: 1 → 0 (적용됨)
  - ShowStartupPanel: 이미 0 (스킵)
  - AllowGameDVR (정책): 이미 0 (스킵)
  - GameDVR_Enabled: 1 → 0 (적용됨)
  - AppCaptureEnabled: 1 → 0 (적용됨)

[10/10] DWM 최적화 중...
  - OverlayTestMode: 이미 5 (스킵)

========================================
고급 게임 최적화가 완료되었습니다!
========================================

Summary:
  - 적용됨: 7개
  - 스킵됨: 5개 (이미 최적 설정)
  - 실패: 0개

로그 파일: C:\Users\User\Documents\Windows11Optimizer_20250109_153245.log
```

---

## 체크리스트

- [ ] 공통 로깅 함수 구현
- [ ] 공통 스킵 로직 함수 구현
- [ ] 018.memory_optimization.ps1 드라이브 감지 추가
- [ ] 018.memory_optimization.ps1 SysMain 자동화
- [ ] 018.memory_optimization.ps1 Prefetch 자동화
- [ ] 018.memory_optimization.ps1 로깅 통합
- [ ] 022.advanced_gaming_optimization.ps1 Game Bar/DVR 추가
- [ ] 022.advanced_gaming_optimization.ps1 DWM 최적화 추가
- [ ] 022.advanced_gaming_optimization.ps1 로깅 통합
- [ ] 버전 업데이트 (v1.0.0 → v1.1.0)
- [ ] Hyper-V VM 테스트
- [ ] 문서 업데이트
- [ ] 커밋 및 푸시
