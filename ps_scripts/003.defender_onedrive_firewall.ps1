# OneDrive 삭제, 방화벽 해제 스크립트
# 서버/로컬 네트워크 환경용 리소스 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Progress Bar 비활성화 (병렬 실행 시 출력 겹침 방지)
$ProgressPreference = 'SilentlyContinue'

# Orchestrate 모드 확인
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

Write-Host "=== OneDrive 삭제, 방화벽 해제 스크립트 ===" -ForegroundColor Cyan
Write-Host "주의: 이 스크립트는 서버/로컬 네트워크 환경용입니다." -ForegroundColor Red
Write-Host ""


# 1. Windows Defender 보호 기능 비활성화
Write-Host "[1/5] Windows Defender 보호 기능 비활성화" -ForegroundColor Yellow
Write-Host ""

# Tamper Protection 확인 및 안내
Write-Host "  [1-1] Tamper Protection 상태 확인..." -ForegroundColor Cyan
try {
    $tamperProtection = (Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected
    if ($tamperProtection) {
        Write-Host "    - Tamper Protection이 활성화되어 있습니다!" -ForegroundColor Red
        Write-Host "    - 아래 설정이 적용되지 않을 수 있습니다." -ForegroundColor Red
        Write-Host "    - 수동 해제 방법:" -ForegroundColor Yellow
        Write-Host "      1. Windows 보안 앱 열기" -ForegroundColor White
        Write-Host "      2. 바이러스 및 위협 방지 > 설정 관리" -ForegroundColor White
        Write-Host "      3. 변조 보호 끄기" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "    - Tamper Protection이 비활성화되어 있습니다" -ForegroundColor Green
    }
} catch {
    Write-Host "    - Defender 상태 확인 실패 (이미 비활성화됨)" -ForegroundColor Yellow
}

# 1-2. 실시간 보호 비활성화
Write-Host "  [1-2] 실시간 보호 비활성화..." -ForegroundColor Cyan
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
    Write-Host "    - 실시간 보호 비활성화 완료" -ForegroundColor Green
} catch {
    Write-Host "    - 실시간 보호 비활성화 실패 (Tamper Protection 또는 권한 문제)" -ForegroundColor Red
    # 레지스트리로 시도
    $defenderPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
    if (!(Test-Path $defenderPolicyPath)) {
        New-Item -Path $defenderPolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $defenderPolicyPath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "    - 레지스트리로 실시간 보호 정책 설정" -ForegroundColor Yellow
}

# 1-3. 개발자 드라이브 보호 비활성화
Write-Host "  [1-3] 개발자 드라이브 보호 비활성화..." -ForegroundColor Cyan
try {
    # Windows 11 23H2+ 에서만 지원
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Build -ge 22631) {
        Set-MpPreference -EnableDevDriveProtection $false -ErrorAction Stop
        Write-Host "    - 개발자 드라이브 보호 비활성화 완료" -ForegroundColor Green
    } else {
        Write-Host "    - 개발자 드라이브 보호는 Windows 11 23H2+ 에서만 지원" -ForegroundColor Yellow
    }
} catch {
    Write-Host "    - 개발자 드라이브 보호 비활성화 실패" -ForegroundColor Red
}

# 1-4. 클라우드 전송 보호 비활성화
Write-Host "  [1-4] 클라우드 전송 보호 비활성화..." -ForegroundColor Cyan
try {
    # MAPSReporting: 0=비활성화, 1=기본, 2=고급
    Set-MpPreference -MAPSReporting 0 -ErrorAction Stop
    Write-Host "    - 클라우드 전송 보호 (MAPS) 비활성화 완료" -ForegroundColor Green
} catch {
    Write-Host "    - 클라우드 전송 보호 비활성화 실패" -ForegroundColor Red
    # 레지스트리로 시도
    $spynetPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet"
    if (!(Test-Path $spynetPath)) {
        New-Item -Path $spynetPath -Force | Out-Null
    }
    Set-ItemProperty -Path $spynetPath -Name "SpynetReporting" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $spynetPath -Name "SubmitSamplesConsent" -Value 2 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "    - 레지스트리로 클라우드 보호 정책 설정" -ForegroundColor Yellow
}

# 1-5. 자동 샘플 전송 비활성화
Write-Host "  [1-5] 자동 샘플 전송 비활성화..." -ForegroundColor Cyan
try {
    # SubmitSamplesConsent: 0=항상 묻기, 1=안전한 샘플 자동 전송, 2=전송 안함, 3=모든 샘플 자동 전송
    Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction Stop
    Write-Host "    - 자동 샘플 전송 비활성화 완료" -ForegroundColor Green
} catch {
    Write-Host "    - 자동 샘플 전송 비활성화 실패" -ForegroundColor Red
}

# 1-6. 추가 Defender 정책 레지스트리 설정
Write-Host "  [1-6] Defender 정책 레지스트리 설정..." -ForegroundColor Cyan
$defenderPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (!(Test-Path $defenderPolicyPath)) {
    New-Item -Path $defenderPolicyPath -Force | Out-Null
}
# Defender 자체 비활성화 정책
Set-ItemProperty -Path $defenderPolicyPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $defenderPolicyPath -Name "DisableAntiVirus" -Value 1 -Type DWord -ErrorAction SilentlyContinue

# Real-Time Protection 정책 경로
$rtpPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
if (!(Test-Path $rtpPolicyPath)) {
    New-Item -Path $rtpPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $rtpPolicyPath -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $rtpPolicyPath -Name "DisableOnAccessProtection" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $rtpPolicyPath -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $rtpPolicyPath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Set-ItemProperty -Path $rtpPolicyPath -Name "DisableIOAVProtection" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "    - Defender 비활성화 정책 레지스트리 설정 완료" -ForegroundColor Green

# 1-7. 부팅 시 Defender 비활성화 예약 작업 등록
Write-Host "  [1-7] 부팅 시 Defender 비활성화 예약 작업 등록..." -ForegroundColor Cyan
$taskName = "DisableDefenderRealtime"
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

# 기존 작업 삭제
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
}

# PowerShell 명령 (실시간 보호 및 관련 기능 비활성화)
$psCommand = @'
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
'@

try {
    # 예약 작업 액션 생성
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$psCommand`""

    # 트리거: 시스템 시작 시 (1분 지연)
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = "PT1M"

    # 설정: SYSTEM 계정으로 실행, 최고 권한
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

    # 작업 설정
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    # 예약 작업 등록
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Disable Windows Defender Real-time Protection on boot" -Force | Out-Null
    Write-Host "    - 부팅 시 Defender 비활성화 예약 작업 등록 완료" -ForegroundColor Green

    # 즉시 한 번 실행
    Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Write-Host "    - 예약 작업 즉시 실행" -ForegroundColor Green
} catch {
    Write-Host "    - 예약 작업 등록 실패: $($_.Exception.Message)" -ForegroundColor Red
}

# 1-8. 로그온 시에도 비활성화 (백업용)
Write-Host "  [1-8] 로그온 시 Defender 비활성화 예약 작업 등록..." -ForegroundColor Cyan
$taskNameLogon = "DisableDefenderRealtimeLogon"
$existingTaskLogon = Get-ScheduledTask -TaskName $taskNameLogon -ErrorAction SilentlyContinue

if ($existingTaskLogon) {
    Unregister-ScheduledTask -TaskName $taskNameLogon -Confirm:$false -ErrorAction SilentlyContinue
}

try {
    $actionLogon = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$psCommand`""
    $triggerLogon = New-ScheduledTaskTrigger -AtLogOn
    $principalLogon = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest
    $settingsLogon = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

    Register-ScheduledTask -TaskName $taskNameLogon -Action $actionLogon -Trigger $triggerLogon -Principal $principalLogon -Settings $settingsLogon -Description "Disable Windows Defender Real-time Protection on logon" -Force | Out-Null
    Write-Host "    - 로그온 시 Defender 비활성화 예약 작업 등록 완료" -ForegroundColor Green
} catch {
    Write-Host "    - 로그온 예약 작업 등록 실패: $($_.Exception.Message)" -ForegroundColor Red
}

# 1-9. WinDefend 서비스 비활성화 (Antimalware Service Executable 완전 중지)
Write-Host "  [1-9] WinDefend 서비스 비활성화 중..." -ForegroundColor Cyan
Write-Host "    - 이 설정은 Tamper Protection이 꺼져 있어야 작동합니다" -ForegroundColor Yellow

$winDefendPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend"
$securityHealthPath = "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService"
$wscsvcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\wscsvc"

# WinDefend 서비스 비활성화 (Start = 4)
try {
    # 현재 상태 확인
    $currentStart = (Get-ItemProperty -Path $winDefendPath -Name "Start" -ErrorAction SilentlyContinue).Start
    Write-Host "    - WinDefend 현재 Start 값: $currentStart (2=자동, 3=수동, 4=비활성화)" -ForegroundColor White

    # 레지스트리로 비활성화 시도
    Set-ItemProperty -Path $winDefendPath -Name "Start" -Value 4 -Type DWord -ErrorAction Stop
    Write-Host "    - WinDefend 서비스 비활성화 (레지스트리)" -ForegroundColor Green
} catch {
    Write-Host "    - WinDefend 레지스트리 수정 실패 (Tamper Protection 활성화됨)" -ForegroundColor Red

    # 대안: reg.exe 사용
    try {
        $regResult = reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\WinDefend" /v Start /t REG_DWORD /d 4 /f 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    - WinDefend 서비스 비활성화 (reg.exe)" -ForegroundColor Green
        } else {
            Write-Host "    - reg.exe 실패: $regResult" -ForegroundColor Red
        }
    } catch {
        Write-Host "    - reg.exe 실행 실패" -ForegroundColor Red
    }
}

# SecurityHealthService 비활성화 (Windows 보안 센터)
try {
    Set-ItemProperty -Path $securityHealthPath -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "    - SecurityHealthService 비활성화" -ForegroundColor Green
} catch {
    Write-Host "    - SecurityHealthService 비활성화 실패" -ForegroundColor Yellow
}

# wscsvc (Security Center) 비활성화
try {
    Set-ItemProperty -Path $wscsvcPath -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "    - wscsvc (Security Center) 비활성화" -ForegroundColor Green
} catch {
    Write-Host "    - wscsvc 비활성화 실패" -ForegroundColor Yellow
}

# WinDefend 서비스 중지 시도
Write-Host "    - WinDefend 서비스 중지 시도 중..." -ForegroundColor Cyan
try {
    $winDefendService = Get-Service -Name "WinDefend" -ErrorAction SilentlyContinue
    if ($winDefendService -and $winDefendService.Status -eq "Running") {
        Stop-Service -Name "WinDefend" -Force -ErrorAction Stop
        Write-Host "    - WinDefend 서비스 중지 완료" -ForegroundColor Green
    } else {
        Write-Host "    - WinDefend 서비스가 이미 중지되었거나 없음" -ForegroundColor Green
    }
} catch {
    Write-Host "    - WinDefend 서비스 중지 실패 (보호됨)" -ForegroundColor Yellow
    # sc.exe로 시도
    $scResult = sc.exe stop WinDefend 2>&1
    Write-Host "    - sc.exe stop WinDefend: $scResult" -ForegroundColor White
}

# MsMpEng.exe 프로세스 종료 시도
Write-Host "    - MsMpEng.exe (Antimalware Service Executable) 종료 시도..." -ForegroundColor Cyan
try {
    $msMpEng = Get-Process -Name "MsMpEng" -ErrorAction SilentlyContinue
    if ($msMpEng) {
        Stop-Process -Name "MsMpEng" -Force -ErrorAction Stop
        Write-Host "    - MsMpEng.exe 종료 완료" -ForegroundColor Green
    } else {
        Write-Host "    - MsMpEng.exe가 실행 중이지 않음" -ForegroundColor Green
    }
} catch {
    Write-Host "    - MsMpEng.exe 종료 실패 (시스템 보호 프로세스)" -ForegroundColor Yellow
    # taskkill로 시도
    $taskKillResult = taskkill /F /IM MsMpEng.exe 2>&1
    Write-Host "    - taskkill 결과: $taskKillResult" -ForegroundColor White
}

# 1-10. Defender 드라이버 비활성화
Write-Host "  [1-10] Defender 관련 드라이버 비활성화 중..." -ForegroundColor Cyan

$defenderDrivers = @(
    @{ Name = "WdFilter"; Desc = "Windows Defender Mini-Filter Driver" },
    @{ Name = "WdNisDrv"; Desc = "Windows Defender Network Inspection Driver" },
    @{ Name = "WdNisSvc"; Desc = "Windows Defender Network Inspection Service" },
    @{ Name = "WdBoot"; Desc = "Windows Defender Boot Driver" }
)

foreach ($driver in $defenderDrivers) {
    $driverPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($driver.Name)"
    try {
        if (Test-Path $driverPath) {
            Set-ItemProperty -Path $driverPath -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
            Write-Host "    - $($driver.Name) ($($driver.Desc)) 비활성화" -ForegroundColor Green
        }
    } catch {
        Write-Host "    - $($driver.Name) 비활성화 실패" -ForegroundColor Yellow
    }
}

# 1-11. Windows Security 알림 비활성화
Write-Host "  [1-11] Windows Security 알림 비활성화 중..." -ForegroundColor Cyan
$notificationPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance"
if (!(Test-Path $notificationPath)) {
    New-Item -Path $notificationPath -Force | Out-Null
}
Set-ItemProperty -Path $notificationPath -Name "Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "    - Windows Security 알림 비활성화 완료" -ForegroundColor Green

# 시스템 트레이 보안 아이콘 숨기기
$explorerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray"
if (!(Test-Path $explorerPath)) {
    New-Item -Path $explorerPath -Force | Out-Null
}
Set-ItemProperty -Path $explorerPath -Name "HideSystray" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "    - 시스템 트레이 보안 아이콘 숨기기" -ForegroundColor Green

# 현재 상태 출력
Write-Host ""
Write-Host "  === Windows Defender 현재 상태 ===" -ForegroundColor Cyan
try {
    $mpStatus = Get-MpComputerStatus -ErrorAction Stop
    Write-Host "    - 실시간 보호: $(if($mpStatus.RealTimeProtectionEnabled){'활성화'}else{'비활성화'})" -ForegroundColor $(if($mpStatus.RealTimeProtectionEnabled){'Red'}else{'Green'})
    Write-Host "    - 클라우드 보호: $(if($mpStatus.OnAccessProtectionEnabled){'활성화'}else{'비활성화'})" -ForegroundColor White
    Write-Host "    - Tamper Protection: $(if($mpStatus.IsTamperProtected){'활성화'}else{'비활성화'})" -ForegroundColor $(if($mpStatus.IsTamperProtected){'Red'}else{'Green'})
} catch {
    Write-Host "    - Defender 상태를 확인할 수 없습니다" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "  참고: Tamper Protection이 켜져 있으면 일부 설정이" -ForegroundColor Yellow
Write-Host "        Windows 보안 앱에서 수동으로 해제해야 합니다." -ForegroundColor Yellow
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""


# 2. Windows 방화벽 완전 해제
Write-Host ""
Write-Host "[2/5] Windows 방화벽 해제 중..." -ForegroundColor Yellow

# 2-1. mpsdrv (방화벽 드라이버) 활성화 - mpssvc의 필수 의존성
Write-Host "  [2-1] mpsdrv (방화벽 드라이버) 확인 중..." -ForegroundColor Cyan
$mpsdrvRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mpsdrv"
$mpsdrvStart = (Get-ItemProperty -Path $mpsdrvRegPath -Name "Start" -ErrorAction SilentlyContinue).Start
Write-Host "    - 현재 mpsdrv Start 값: $mpsdrvStart (0=Boot, 1=System, 2=Auto, 3=수동, 4=비활성화)" -ForegroundColor White
if ($mpsdrvStart -ne 0) {
    Set-ItemProperty -Path $mpsdrvRegPath -Name "Start" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "    - mpsdrv Start 값을 0 (Boot)으로 변경" -ForegroundColor Green
}
# sc config로도 설정 (더 확실함)
$scResult = sc.exe config mpsdrv start= boot 2>&1
Write-Host "    - sc config mpsdrv: $scResult" -ForegroundColor White
# 드라이버 시작 시도
$scStartResult = sc.exe start mpsdrv 2>&1
Write-Host "    - sc start mpsdrv: $scStartResult" -ForegroundColor White

# 2-2. BFE (Base Filtering Engine) 서비스 확인 및 시작
Write-Host "  [2-2] BFE (Base Filtering Engine) 서비스 확인 중..." -ForegroundColor Cyan
$bfeService = Get-Service -Name "BFE" -ErrorAction SilentlyContinue
Write-Host "    - 현재 BFE 상태: $($bfeService.Status)" -ForegroundColor White
if ($bfeService.Status -ne "Running") {
    $bfeRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\BFE"
    Set-ItemProperty -Path $bfeRegPath -Name "Start" -Value 2 -Type DWord -ErrorAction SilentlyContinue
    sc.exe config BFE start= auto | Out-Null
    Write-Host "    - BFE 시작 유형을 자동으로 설정" -ForegroundColor Green
    $scStartBfe = sc.exe start BFE 2>&1
    Write-Host "    - sc start BFE: $scStartBfe" -ForegroundColor White
    Start-Sleep -Seconds 2
    $bfeService = Get-Service -Name "BFE" -ErrorAction SilentlyContinue
    Write-Host "    - BFE 상태 (재확인): $($bfeService.Status)" -ForegroundColor White
} else {
    Write-Host "    - BFE 이미 실행 중" -ForegroundColor Green
}

# 2-3. mpssvc (Windows Defender Firewall) 서비스 확인 및 시작
Write-Host "  [2-3] mpssvc (방화벽 서비스) 확인 중..." -ForegroundColor Cyan
$firewallService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
Write-Host "    - 현재 mpssvc 상태: $($firewallService.Status)" -ForegroundColor White
if ($firewallService.Status -ne "Running") {
    $firewallRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mpssvc"
    Set-ItemProperty -Path $firewallRegPath -Name "Start" -Value 2 -Type DWord -ErrorAction SilentlyContinue
    sc.exe config mpssvc start= auto | Out-Null
    Write-Host "    - mpssvc 시작 유형을 자동으로 설정" -ForegroundColor Green
    $scStartMpssvc = sc.exe start mpssvc 2>&1
    Write-Host "    - sc start mpssvc: $scStartMpssvc" -ForegroundColor White
    Start-Sleep -Seconds 2
    $firewallService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
    Write-Host "    - mpssvc 상태 (재확인): $($firewallService.Status)" -ForegroundColor White

    if ($firewallService.Status -ne "Running") {
        Write-Host "    - 경고: mpssvc 시작 실패. 재부팅 후 다시 시도 필요" -ForegroundColor Red
    }
} else {
    Write-Host "    - mpssvc 이미 실행 중" -ForegroundColor Green
}

# 2-4. 방화벽 설정 적용
Write-Host "  [2-4] 방화벽 설정 적용 중..." -ForegroundColor Cyan
$firewallService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
if ($firewallService.Status -eq "Running") {
    # 모든 프로필 방화벽 해제
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
    Write-Host "    - 도메인, 공용, 개인 프로필 방화벽 해제" -ForegroundColor Green

    # 방화벽 기본 동작을 Allow로 설정 (추가 보호)
    Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Allow -DefaultOutboundAction Allow
    Write-Host "    - 기본 인바운드/아웃바운드 정책을 Allow로 설정" -ForegroundColor Green

    # RDP 포트 명시적 허용 (방화벽이 켜져있어도 작동하도록)
    $rdpRuleName = "Remote Desktop - User Mode (TCP-In) - Custom"
    $existingRule = Get-NetFirewallRule -DisplayName $rdpRuleName -ErrorAction SilentlyContinue
    if (!$existingRule) {
        New-NetFirewallRule -DisplayName $rdpRuleName -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -Profile Any -Enabled True | Out-Null
        Write-Host "    - RDP 포트 (3389) 방화벽 규칙 추가" -ForegroundColor Green
    } else {
        Set-NetFirewallRule -DisplayName $rdpRuleName -Enabled True
        Write-Host "    - RDP 포트 (3389) 방화벽 규칙 활성화" -ForegroundColor Green
    }

    # 기존 RDP 규칙도 활성화
    Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue | Set-NetFirewallRule -Enabled True -ErrorAction SilentlyContinue
    Write-Host "    - 기존 원격 데스크톱 규칙 활성화" -ForegroundColor Green
} else {
    Write-Host "    - 경고: mpssvc가 실행되지 않아 방화벽 설정을 건너뜀" -ForegroundColor Red
    Write-Host "    - 재부팅 후 스크립트를 다시 실행하세요" -ForegroundColor Red
}

# 방화벽 정책 비활성화 (레지스트리 - 서비스 상태와 무관)
Write-Host "  [2-5] 방화벽 정책 레지스트리 설정 중..." -ForegroundColor Cyan
$firewallPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall"
if (!(Test-Path "$firewallPolicyPath\DomainProfile")) {
    New-Item -Path "$firewallPolicyPath\DomainProfile" -Force | Out-Null
}
if (!(Test-Path "$firewallPolicyPath\StandardProfile")) {
    New-Item -Path "$firewallPolicyPath\StandardProfile" -Force | Out-Null
}
if (!(Test-Path "$firewallPolicyPath\PublicProfile")) {
    New-Item -Path "$firewallPolicyPath\PublicProfile" -Force | Out-Null
}
Set-ItemProperty -Path "$firewallPolicyPath\DomainProfile" -Name "EnableFirewall" -Value 0 -Type DWord
Set-ItemProperty -Path "$firewallPolicyPath\StandardProfile" -Name "EnableFirewall" -Value 0 -Type DWord
Set-ItemProperty -Path "$firewallPolicyPath\PublicProfile" -Name "EnableFirewall" -Value 0 -Type DWord
Write-Host "    - 방화벽 정책 레지스트리 비활성화" -ForegroundColor Green

# 2-6. RDP (원격 데스크톱) 서비스 활성화
Write-Host "  [2-6] RDP (원격 데스크톱) 서비스 활성화 중..." -ForegroundColor Cyan

# RDP 활성화 (레지스트리)
$rdpRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
$currentRdpValue = (Get-ItemProperty -Path $rdpRegPath -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
Write-Host "    - 현재 fDenyTSConnections 값: $currentRdpValue (0=활성화, 1=비활성화)" -ForegroundColor White
Set-ItemProperty -Path $rdpRegPath -Name "fDenyTSConnections" -Value 0 -Type DWord
Write-Host "    - RDP 연결 허용 설정 완료" -ForegroundColor Green

# 네트워크 레벨 인증(NLA) 활성화 유지 (보안 강화)
# NLA는 RDP 연결 전 인증을 요구하여 무단 접근 방지
$rdpTcpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
Set-ItemProperty -Path $rdpTcpPath -Name "UserAuthentication" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "    - 네트워크 레벨 인증(NLA) 활성화 (보안 유지)" -ForegroundColor Green

# TermService (원격 데스크톱 서비스) 활성화 및 시작
Write-Host "    - TermService (원격 데스크톱 서비스) 확인 중..." -ForegroundColor White
$termService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
Write-Host "    - 현재 TermService 상태: $($termService.Status)" -ForegroundColor White
if ($termService.Status -ne "Running") {
    sc.exe config TermService start= auto | Out-Null
    $scStartTerm = sc.exe start TermService 2>&1
    Write-Host "    - sc start TermService: $scStartTerm" -ForegroundColor White
    Start-Sleep -Seconds 2
    $termService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
    Write-Host "    - TermService 상태 (재확인): $($termService.Status)" -ForegroundColor White
} else {
    Write-Host "    - TermService 이미 실행 중" -ForegroundColor Green
}

# 서비스 최종 상태 요약
Write-Host ""
Write-Host "  === 방화벽/RDP 서비스 최종 상태 ===" -ForegroundColor Cyan
$finalMpsdrv = sc.exe query mpsdrv 2>&1 | Select-String "STATE"
$finalBfe = (Get-Service -Name "BFE" -ErrorAction SilentlyContinue).Status
$finalMpssvc = (Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue).Status
$finalTermService = (Get-Service -Name "TermService" -ErrorAction SilentlyContinue).Status
Write-Host "    - mpsdrv: $finalMpsdrv" -ForegroundColor White
Write-Host "    - BFE: $finalBfe" -ForegroundColor White
Write-Host "    - mpssvc: $finalMpssvc" -ForegroundColor White
Write-Host "    - TermService (RDP): $finalTermService" -ForegroundColor White


# 3. OneDrive 프로세스 종료
Write-Host ""
Write-Host "[3/5] OneDrive 프로세스 종료 중..." -ForegroundColor Yellow

Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "  - OneDrive 프로세스 종료" -ForegroundColor Green


# 4. OneDrive 제거
Write-Host ""
Write-Host "[4/5] OneDrive 제거 중..." -ForegroundColor Yellow

# OneDrive 제거 실행
$oneDriveSetup64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
$oneDriveSetup32 = "$env:SystemRoot\System32\OneDriveSetup.exe"

if (Test-Path $oneDriveSetup64) {
    Start-Process $oneDriveSetup64 -ArgumentList "/uninstall" -Wait -NoNewWindow
    Write-Host "  - OneDrive 제거 완료 (64비트)" -ForegroundColor Green
} elseif (Test-Path $oneDriveSetup32) {
    Start-Process $oneDriveSetup32 -ArgumentList "/uninstall" -Wait -NoNewWindow
    Write-Host "  - OneDrive 제거 완료 (32비트)" -ForegroundColor Green
} else {
    # winget으로 제거 시도
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        winget uninstall "Microsoft.OneDrive" --silent --accept-source-agreements 2>$null
        Write-Host "  - OneDrive 제거 완료 (winget)" -ForegroundColor Green
    } else {
        Write-Host "  - OneDrive가 이미 제거되었거나 찾을 수 없음" -ForegroundColor Yellow
    }
}


# 5. OneDrive 관련 레지스트리 및 폴더 정리
Write-Host ""
Write-Host "[5/5] OneDrive 잔여 파일 정리 중..." -ForegroundColor Yellow

# OneDrive 자동 시작 제거
Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
Write-Host "  - OneDrive 자동 시작 제거" -ForegroundColor Green

# OneDrive 설치 방지 정책
$oneDrivePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
if (!(Test-Path $oneDrivePolicyPath)) {
    New-Item -Path $oneDrivePolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $oneDrivePolicyPath -Name "DisableFileSyncNGSC" -Value 1 -Type DWord
Set-ItemProperty -Path $oneDrivePolicyPath -Name "DisableFileSync" -Value 1 -Type DWord
Write-Host "  - OneDrive 동기화 비활성화 정책 적용" -ForegroundColor Green

# 탐색기에서 OneDrive 숨기기
$explorerCLSID = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
$explorerWow64 = "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"

# HKCR 드라이브 마운트
if (!(Test-Path "HKCR:")) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
}

if (Test-Path $explorerCLSID) {
    Set-ItemProperty -Path $explorerCLSID -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
if (Test-Path $explorerWow64) {
    Set-ItemProperty -Path $explorerWow64 -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
Write-Host "  - 탐색기에서 OneDrive 숨김" -ForegroundColor Green

# OneDrive 폴더 삭제
$oneDriveFolders = @(
    "$env:USERPROFILE\OneDrive",
    "$env:LOCALAPPDATA\Microsoft\OneDrive",
    "$env:PROGRAMDATA\Microsoft OneDrive",
    "C:\OneDriveTemp"
)

foreach ($folder in $oneDriveFolders) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "  - OneDrive 폴더 삭제 완료" -ForegroundColor Green

# 예약 작업 제거
Get-ScheduledTask -TaskPath '\' -TaskName '*OneDrive*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  - OneDrive 예약 작업 제거" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - Windows Defender 보호 기능 비활성화 시도" -ForegroundColor White
Write-Host "    (실시간 보호, 개발자 드라이브 보호, 클라우드 보호, 샘플 전송)" -ForegroundColor White
Write-Host "  - WinDefend 서비스 비활성화 (Antimalware Service Executable)" -ForegroundColor White
Write-Host "  - Defender 드라이버 비활성화 (WdFilter, WdNisDrv, WdBoot)" -ForegroundColor White
Write-Host "  - Windows 방화벽 해제" -ForegroundColor White
Write-Host "  - OneDrive 완전 삭제" -ForegroundColor White
Write-Host ""
Write-Host "Defender가 여전히 활성화되어 있다면:" -ForegroundColor Yellow
Write-Host "  1. Windows 보안 > 바이러스 및 위협 방지 > 설정 관리" -ForegroundColor White
Write-Host "  2. Tamper Protection (변조 보호) 끄기" -ForegroundColor White
Write-Host "  3. 재부팅 후 스크립트 다시 실행" -ForegroundColor White
Write-Host ""
Write-Host "RDP 연결 관련:" -ForegroundColor Yellow
Write-Host "  - WinDefend 비활성화는 RDP에 영향을 주지 않습니다" -ForegroundColor White
Write-Host "  - RDP는 TermService를 사용하며 Defender와 무관합니다" -ForegroundColor White
Write-Host ""
Write-Host "변경 사항을 완전히 적용하려면 재부팅이 필요합니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인 (OrchestrateMode에서는 건너뜀)
if (-not $global:OrchestrateMode) {
    $restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
    if ($restart -eq "Y" -or $restart -eq "y") {
        Write-Host "10초 후 재부팅됩니다..." -ForegroundColor Red
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    } else {
        Write-Host "나중에 수동으로 재부팅해주세요." -ForegroundColor Yellow
    }
}
