# Windows 11 전원 관리, 네트워크 최적화 및 텔레메트리 비활성화 스크립트
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Orchestrate 모드 확인
if ($null -eq $global:OrchestrateMode) {
    $global:OrchestrateMode = $false
}

Write-Host "=== 전원 관리, 네트워크 최적화 및 텔레메트리 비활성화 스크립트 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 전원 옵션을 최고 성능으로 설정
Write-Host "[1/7] 전원 옵션 설정 중..." -ForegroundColor Yellow

# GUID 추출 함수 (정규식 사용)
function Get-PowerSchemeGuid {
    param([string]$Line)
    $match = [regex]::Match($Line, '[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}')
    if ($match.Success) { return $match.Value }
    return $null
}

# 최고 성능 전원 관리 옵션 활성화 (숨겨진 옵션)
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null

# 고성능 모드로 설정
$highPerf = powercfg -list | Select-String "고성능|High performance" | Select-Object -First 1
if ($highPerf) {
    $guid = Get-PowerSchemeGuid -Line $highPerf.Line
    if ($guid) {
        powercfg -setactive $guid
        Write-Host "  - 고성능 전원 관리 옵션 활성화" -ForegroundColor Green
    } else {
        Write-Host "  - 고성능 GUID 추출 실패" -ForegroundColor Red
    }
} else {
    # 최고 성능 모드 시도
    $ultimatePerf = powercfg -list | Select-String "최고 성능|Ultimate Performance" | Select-Object -First 1
    if ($ultimatePerf) {
        $guid = Get-PowerSchemeGuid -Line $ultimatePerf.Line
        if ($guid) {
            powercfg -setactive $guid
            Write-Host "  - 최고 성능 전원 관리 옵션 활성화" -ForegroundColor Green
        } else {
            Write-Host "  - 최고 성능 GUID 추출 실패" -ForegroundColor Red
        }
    } else {
        Write-Host "  - 고성능 옵션을 찾을 수 없음, 기본값 유지" -ForegroundColor Red
    }
}


# 2. 절전 모드, 모니터 끄기, 하드 디스크 끄기 비활성화
Write-Host ""
Write-Host "[2/7] 절전 설정 비활성화 중..." -ForegroundColor Yellow

# 절전 모드 사용 안 함 (AC/DC 둘 다)
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 0
Write-Host "  - 절전 모드 비활성화" -ForegroundColor Green

# 모니터 끄기 사용 안 함
powercfg -change -monitor-timeout-ac 0
powercfg -change -monitor-timeout-dc 0
Write-Host "  - 모니터 끄기 비활성화" -ForegroundColor Green

# 하드 디스크 끄기 사용 안 함
powercfg -change -disk-timeout-ac 0
powercfg -change -disk-timeout-dc 0
Write-Host "  - 하드 디스크 끄기 비활성화" -ForegroundColor Green

# 최대 절전 모드 비활성화
powercfg -hibernate off
Write-Host "  - 최대 절전 모드 비활성화" -ForegroundColor Green


# 3. USB 선택적 절전 모드 비활성화
Write-Host ""
Write-Host "[3/7] USB 선택적 절전 모드 비활성화 중..." -ForegroundColor Yellow

# 현재 전원 관리 옵션의 GUID 가져오기 (정규식 사용)
$activeSchemeOutput = powercfg -getactivescheme
$activeScheme = Get-PowerSchemeGuid -Line $activeSchemeOutput

if ($activeScheme) {
    # USB 선택적 절전 모드 설정 (AC: 0=비활성화, DC: 0=비활성화)
    # USB 설정 GUID: 2a737441-1930-4402-8d77-b2bebba308a3
    # USB 선택적 절전 GUID: 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
    powercfg -setacvalueindex $activeScheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg -setdcvalueindex $activeScheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg -setactive $activeScheme
    Write-Host "  - USB 선택적 절전 모드 비활성화 완료" -ForegroundColor Green
} else {
    Write-Host "  - 활성 전원 구성표 GUID를 가져올 수 없음" -ForegroundColor Red
}


# 4. PCI Express 링크 상태 전원 관리 끄기
Write-Host ""
Write-Host "[4/7] PCI Express 전원 관리 비활성화 중..." -ForegroundColor Yellow

if ($activeScheme) {
    # PCI Express 설정 GUID: 501a4d13-42af-4429-9fd1-a8218c268e20
    # 링크 상태 전원 관리 GUID: ee12f906-d277-404b-b6da-e5fa1a576df5
    # 0 = 끄기, 1 = 보통 절전, 2 = 최대 절전
    powercfg -setacvalueindex $activeScheme 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
    powercfg -setdcvalueindex $activeScheme 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
    powercfg -setactive $activeScheme
    Write-Host "  - PCI Express 링크 상태 전원 관리 끄기 완료" -ForegroundColor Green
} else {
    Write-Host "  - 활성 전원 구성표를 사용할 수 없어 건너뜀" -ForegroundColor Red
}


# 5. 네트워크 어댑터 절전 모드 비활성화
Write-Host ""
Write-Host "[5/7] 네트워크 어댑터 절전 모드 비활성화 중..." -ForegroundColor Yellow

$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    $adapterName = $adapter.Name
    $pnpDevice = Get-PnpDevice | Where-Object { $_.FriendlyName -eq $adapter.InterfaceDescription }

    if ($pnpDevice) {
        $instanceId = $pnpDevice.InstanceId
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$instanceId\Device Parameters"

        # PnP 절전 관리 비활성화
        $pnpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
        Get-ChildItem $pnpPath -ErrorAction SilentlyContinue | ForEach-Object {
            $driverDesc = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            if ($driverDesc -eq $adapter.InterfaceDescription) {
                # PnPCapabilities: 24 = 절전 모드 비활성화
                Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Host "  - $adapterName 절전 모드 비활성화" -ForegroundColor Green
}


# 6. Nagle 알고리즘 비활성화
Write-Host ""
Write-Host "[6/7] Nagle 알고리즘 비활성화 중..." -ForegroundColor Yellow

$tcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
$interfaces = Get-ChildItem $tcpipPath

foreach ($interface in $interfaces) {
    $ifPath = $interface.PSPath

    # TcpAckFrequency = 1 (모든 패킷에 즉시 ACK)
    Set-ItemProperty -Path $ifPath -Name "TcpAckFrequency" -Value 1 -Type DWord -ErrorAction SilentlyContinue

    # TCPNoDelay = 1 (Nagle 알고리즘 비활성화)
    Set-ItemProperty -Path $ifPath -Name "TcpNoDelay" -Value 1 -Type DWord -ErrorAction SilentlyContinue
}

Write-Host "  - Nagle 알고리즘 비활성화 완료" -ForegroundColor Green
Write-Host "  - TCP ACK 지연 비활성화 완료" -ForegroundColor Green


# 7. 텔레메트리 비활성화
Write-Host ""
Write-Host "[7/7] 텔레메트리 비활성화 중..." -ForegroundColor Yellow

# DiagTrack 서비스 (Connected User Experiences and Telemetry) 비활성화
Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - DiagTrack 서비스 비활성화" -ForegroundColor Green

# dmwappushservice (WAP Push Message Routing Service) 비활성화
Stop-Service -Name "dmwappushservice" -Force -ErrorAction SilentlyContinue
Set-Service -Name "dmwappushservice" -StartupType Disabled -ErrorAction SilentlyContinue
Write-Host "  - dmwappushservice 비활성화" -ForegroundColor Green

# 진단 데이터 수준을 최소로 설정 (0 = Security/Off, 1 = Basic)
$dataCollectionPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
if (!(Test-Path $dataCollectionPath)) {
    New-Item -Path $dataCollectionPath -Force | Out-Null
}
Set-ItemProperty -Path $dataCollectionPath -Name "AllowTelemetry" -Value 0 -Type DWord
Set-ItemProperty -Path $dataCollectionPath -Name "MaxTelemetryAllowed" -Value 0 -Type DWord
Write-Host "  - 진단 데이터 수집 비활성화" -ForegroundColor Green

# 피드백 빈도 비활성화
$siufPath = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"
if (!(Test-Path $siufPath)) {
    New-Item -Path $siufPath -Force | Out-Null
}
Set-ItemProperty -Path $siufPath -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWord
Write-Host "  - 피드백 요청 비활성화" -ForegroundColor Green

# 광고 ID 비활성화
$advertisingPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
if (!(Test-Path $advertisingPath)) {
    New-Item -Path $advertisingPath -Force | Out-Null
}
Set-ItemProperty -Path $advertisingPath -Name "Enabled" -Value 0 -Type DWord
Write-Host "  - 광고 ID 비활성화" -ForegroundColor Green

# 활동 기록 비활성화
$activityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (!(Test-Path $activityPath)) {
    New-Item -Path $activityPath -Force | Out-Null
}
Set-ItemProperty -Path $activityPath -Name "EnableActivityFeed" -Value 0 -Type DWord
Set-ItemProperty -Path $activityPath -Name "PublishUserActivities" -Value 0 -Type DWord
Set-ItemProperty -Path $activityPath -Name "UploadUserActivities" -Value 0 -Type DWord
Write-Host "  - 활동 기록 비활성화" -ForegroundColor Green

# 앱 진단 비활성화
$appDiagPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
if (!(Test-Path $appDiagPath)) {
    New-Item -Path $appDiagPath -Force | Out-Null
}
Set-ItemProperty -Path $appDiagPath -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Type DWord
Write-Host "  - 맞춤형 환경 비활성화" -ForegroundColor Green

# 텔레메트리 예약 작업 비활성화
$telemetryTasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
)

foreach ($task in $telemetryTasks) {
    Disable-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue | Out-Null
}
Write-Host "  - 텔레메트리 예약 작업 비활성화" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "일부 변경 사항은 재부팅 후 적용됩니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인
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
