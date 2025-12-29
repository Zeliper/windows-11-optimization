# Windows 11 전원 관리 및 네트워크 최적화 스크립트
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "=== 전원 관리 및 네트워크 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host ""

# 1. 전원 옵션을 최고 성능으로 설정
Write-Host "[1/6] 전원 옵션 설정 중..." -ForegroundColor Yellow

# 최고 성능 전원 관리 옵션 활성화 (숨겨진 옵션)
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
# 고성능 모드로 설정
$highPerf = powercfg -list | Select-String "고성능|High performance" | Select-Object -First 1
if ($highPerf) {
    $guid = ($highPerf -split '\s+')[3]
    powercfg -setactive $guid
    Write-Host "  - 고성능 전원 관리 옵션 활성화" -ForegroundColor Green
} else {
    # 최고 성능 모드 시도
    $ultimatePerf = powercfg -list | Select-String "최고 성능|Ultimate Performance" | Select-Object -First 1
    if ($ultimatePerf) {
        $guid = ($ultimatePerf -split '\s+')[3]
        powercfg -setactive $guid
        Write-Host "  - 최고 성능 전원 관리 옵션 활성화" -ForegroundColor Green
    } else {
        Write-Host "  - 고성능 옵션을 찾을 수 없음, 기본값 유지" -ForegroundColor Red
    }
}


# 2. 절전 모드, 모니터 끄기, 하드 디스크 끄기 비활성화
Write-Host ""
Write-Host "[2/6] 절전 설정 비활성화 중..." -ForegroundColor Yellow

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
Write-Host "[3/6] USB 선택적 절전 모드 비활성화 중..." -ForegroundColor Yellow

# 현재 전원 관리 옵션의 GUID 가져오기
$activeScheme = (powercfg -getactivescheme) -replace '.*:\s*(.{36}).*', '$1'

# USB 선택적 절전 모드 설정 (AC: 0=비활성화, DC: 0=비활성화)
# USB 설정 GUID: 2a737441-1930-4402-8d77-b2bebba308a3
# USB 선택적 절전 GUID: 48e6b7a6-50f5-4782-a5d4-53bb8f07e226
powercfg -setacvalueindex $activeScheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg -setdcvalueindex $activeScheme 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg -setactive $activeScheme
Write-Host "  - USB 선택적 절전 모드 비활성화 완료" -ForegroundColor Green


# 4. PCI Express 링크 상태 전원 관리 끄기
Write-Host ""
Write-Host "[4/6] PCI Express 전원 관리 비활성화 중..." -ForegroundColor Yellow

# PCI Express 설정 GUID: 501a4d13-42af-4429-9fd1-a8218c268e20
# 링크 상태 전원 관리 GUID: ee12f906-d277-404b-b6da-e5fa1a576df5
# 0 = 끄기, 1 = 보통 절전, 2 = 최대 절전
powercfg -setacvalueindex $activeScheme 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg -setdcvalueindex $activeScheme 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg -setactive $activeScheme
Write-Host "  - PCI Express 링크 상태 전원 관리 끄기 완료" -ForegroundColor Green


# 5. 네트워크 어댑터 절전 모드 비활성화
Write-Host ""
Write-Host "[5/6] 네트워크 어댑터 절전 모드 비활성화 중..." -ForegroundColor Yellow

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
Write-Host "[6/6] Nagle 알고리즘 비활성화 중..." -ForegroundColor Yellow

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


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "일부 변경 사항은 재부팅 후 적용됩니다." -ForegroundColor Yellow
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
