# Windows Defender 해제, OneDrive 삭제, 방화벽 해제 스크립트
# 서버/로컬 네트워크 환경용 리소스 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "=== Windows Defender, OneDrive, 방화벽 해제 스크립트 ===" -ForegroundColor Cyan
Write-Host "주의: 이 스크립트는 서버/로컬 네트워크 환경용입니다." -ForegroundColor Red
Write-Host ""


# 1. Windows Defender 실시간 보호 비활성화
Write-Host "[1/7] Windows Defender 실시간 보호 비활성화 중..." -ForegroundColor Yellow

try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisablePrivacyMode $true -ErrorAction SilentlyContinue
    Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
    Set-MpPreference -MAPSReporting Disabled -ErrorAction SilentlyContinue
    Set-MpPreference -SubmitSamplesConsent NeverSend -ErrorAction SilentlyContinue
    Write-Host "  - 실시간 보호 비활성화 완료" -ForegroundColor Green
} catch {
    Write-Host "  - 실시간 보호 비활성화 실패 (Tamper Protection 확인 필요)" -ForegroundColor Red
}


# 2. Windows Defender 서비스 비활성화 (레지스트리)
Write-Host ""
Write-Host "[2/7] Windows Defender 서비스 비활성화 중..." -ForegroundColor Yellow

# Windows Defender 정책 레지스트리
$defenderPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (!(Test-Path $defenderPolicyPath)) {
    New-Item -Path $defenderPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $defenderPolicyPath -Name "DisableAntiSpyware" -Value 1 -Type DWord
Set-ItemProperty -Path $defenderPolicyPath -Name "DisableAntiVirus" -Value 1 -Type DWord
Write-Host "  - Defender 정책 비활성화" -ForegroundColor Green

# 실시간 보호 정책
$realtimePath = "$defenderPolicyPath\Real-Time Protection"
if (!(Test-Path $realtimePath)) {
    New-Item -Path $realtimePath -Force | Out-Null
}
Set-ItemProperty -Path $realtimePath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord
Set-ItemProperty -Path $realtimePath -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord
Set-ItemProperty -Path $realtimePath -Name "DisableOnAccessProtection" -Value 1 -Type DWord
Set-ItemProperty -Path $realtimePath -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord
Set-ItemProperty -Path $realtimePath -Name "DisableIOAVProtection" -Value 1 -Type DWord
Write-Host "  - 실시간 보호 정책 비활성화" -ForegroundColor Green

# SpyNet (클라우드 보호) 비활성화
$spynetPath = "$defenderPolicyPath\Spynet"
if (!(Test-Path $spynetPath)) {
    New-Item -Path $spynetPath -Force | Out-Null
}
Set-ItemProperty -Path $spynetPath -Name "SpynetReporting" -Value 0 -Type DWord
Set-ItemProperty -Path $spynetPath -Name "SubmitSamplesConsent" -Value 2 -Type DWord
Write-Host "  - 클라우드 보호 비활성화" -ForegroundColor Green

# Windows Defender 서비스 비활성화 시도
$defenderServices = @("WinDefend", "WdNisSvc", "WdNisDrv", "WdFilter", "WdBoot")
foreach ($service in $defenderServices) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$service"
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
    }
}
Write-Host "  - Defender 서비스 비활성화 (재부팅 후 적용)" -ForegroundColor Green


# 3. Windows Security Center 알림 비활성화
Write-Host ""
Write-Host "[3/7] Windows Security Center 알림 비활성화 중..." -ForegroundColor Yellow

$secCenterPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center"
if (!(Test-Path $secCenterPath)) {
    New-Item -Path $secCenterPath -Force | Out-Null
}

# 각 보호 영역 알림 비활성화
$notifications = @(
    "App and Browser protection",
    "Device performance and health",
    "Family options",
    "Firewall and network protection",
    "Virus and threat protection"
)

foreach ($notification in $notifications) {
    $notifPath = "$secCenterPath\Notifications"
    if (!(Test-Path $notifPath)) {
        New-Item -Path $notifPath -Force | Out-Null
    }
    Set-ItemProperty -Path $notifPath -Name "DisableNotifications" -Value 1 -Type DWord -ErrorAction SilentlyContinue
}

# 시스템 트레이 아이콘 숨기기
$explorerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray"
if (!(Test-Path $explorerPath)) {
    New-Item -Path $explorerPath -Force | Out-Null
}
Set-ItemProperty -Path $explorerPath -Name "HideSystray" -Value 1 -Type DWord
Write-Host "  - Security Center 알림 및 트레이 아이콘 비활성화" -ForegroundColor Green


# 4. Windows 방화벽 완전 해제
Write-Host ""
Write-Host "[4/7] Windows 방화벽 해제 중..." -ForegroundColor Yellow

# 4-1. mpsdrv (방화벽 드라이버) 활성화 - mpssvc의 필수 의존성
Write-Host "  [4-1] mpsdrv (방화벽 드라이버) 확인 중..." -ForegroundColor Cyan
$mpsdrvRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mpsdrv"
$mpsdrvStart = (Get-ItemProperty -Path $mpsdrvRegPath -Name "Start" -ErrorAction SilentlyContinue).Start
Write-Host "    - 현재 mpsdrv Start 값: $mpsdrvStart (3=수동, 4=비활성화)" -ForegroundColor White
if ($mpsdrvStart -ne 3) {
    Set-ItemProperty -Path $mpsdrvRegPath -Name "Start" -Value 3 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "    - mpsdrv Start 값을 3 (수동)으로 변경" -ForegroundColor Green
}
# sc config로도 설정 (더 확실함)
$scResult = sc.exe config mpsdrv start= demand 2>&1
Write-Host "    - sc config mpsdrv: $scResult" -ForegroundColor White
# 드라이버 시작 시도
$scStartResult = sc.exe start mpsdrv 2>&1
Write-Host "    - sc start mpsdrv: $scStartResult" -ForegroundColor White

# 4-2. BFE (Base Filtering Engine) 서비스 확인 및 시작
Write-Host "  [4-2] BFE (Base Filtering Engine) 서비스 확인 중..." -ForegroundColor Cyan
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

# 4-3. mpssvc (Windows Defender Firewall) 서비스 확인 및 시작
Write-Host "  [4-3] mpssvc (방화벽 서비스) 확인 중..." -ForegroundColor Cyan
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

# 4-4. 방화벽 설정 적용
Write-Host "  [4-4] 방화벽 설정 적용 중..." -ForegroundColor Cyan
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
Write-Host "  [4-5] 방화벽 정책 레지스트리 설정 중..." -ForegroundColor Cyan
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

# 서비스 최종 상태 요약
Write-Host ""
Write-Host "  === 방화벽 서비스 최종 상태 ===" -ForegroundColor Cyan
$finalMpsdrv = sc.exe query mpsdrv 2>&1 | Select-String "STATE"
$finalBfe = (Get-Service -Name "BFE" -ErrorAction SilentlyContinue).Status
$finalMpssvc = (Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue).Status
Write-Host "    - mpsdrv: $finalMpsdrv" -ForegroundColor White
Write-Host "    - BFE: $finalBfe" -ForegroundColor White
Write-Host "    - mpssvc: $finalMpssvc" -ForegroundColor White


# 5. OneDrive 프로세스 종료
Write-Host ""
Write-Host "[5/7] OneDrive 프로세스 종료 중..." -ForegroundColor Yellow

Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "  - OneDrive 프로세스 종료" -ForegroundColor Green


# 6. OneDrive 제거
Write-Host ""
Write-Host "[6/7] OneDrive 제거 중..." -ForegroundColor Yellow

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


# 7. OneDrive 관련 레지스트리 및 폴더 정리
Write-Host ""
Write-Host "[7/7] OneDrive 잔여 파일 정리 중..." -ForegroundColor Yellow

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
Write-Host "  - Windows Defender 비활성화" -ForegroundColor White
Write-Host "  - Windows 방화벽 해제" -ForegroundColor White
Write-Host "  - OneDrive 완전 삭제" -ForegroundColor White
Write-Host ""
Write-Host "주의: Tamper Protection이 켜져 있으면 Defender가" -ForegroundColor Red
Write-Host "      완전히 비활성화되지 않을 수 있습니다." -ForegroundColor Red
Write-Host "      Windows 보안 > 바이러스 및 위협 방지 > 설정 관리" -ForegroundColor Red
Write-Host "      에서 변조 방지를 먼저 끄세요." -ForegroundColor Red
Write-Host ""
Write-Host "변경 사항을 완전히 적용하려면 재부팅이 필요합니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인
$restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host "10초 후 재부팅됩니다..." -ForegroundColor Red
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "나중에 수동으로 재부팅해주세요." -ForegroundColor Yellow
}
