# OneDrive 삭제, 방화벽 해제 스크립트
# 서버/로컬 네트워크 환경용 리소스 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.3"

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

# ForceOverride 모드 확인
if ($null -eq $global:ForceOverride) {
    $global:ForceOverride = $false
}

#region 공통 함수

# 로그 파일 경로 설정
$logFileName = "Windows11Optimizer_003_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir $logFileName
$global:LogEntries = [System.Collections.ArrayList]@()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Message,
        [ValidateSet("Applied", "Skipped", "Failed", "Info")]
        [string]$Status = "Info"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Status] $Message"
    [void]$global:LogEntries.Add($logEntry)

    switch ($Status) {
        "Applied" { $global:AppliedCount++ }
        "Skipped" { $global:SkippedCount++ }
        "Failed" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    if ($global:LogEntries.Count -gt 0) {
        $global:LogEntries | Out-File -FilePath $global:LogFilePath -Encoding UTF8
    }
}

function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$StepName,
        [string]$Description = ""
    )

    try {
        # 경로가 없으면 생성
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        $currentValue = $null
        try {
            $currentValue = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
        } catch {
            $currentValue = $null
        }

        # ForceOverride가 아니고 값이 같으면 스킵
        if (-not $global:ForceOverride -and $currentValue -eq $Value) {
            $displayDesc = if ($Description) { " - $Description" } else { "" }
            Write-Host "  - $StepName : 이미 적용됨 (스킵)$displayDesc" -ForegroundColor Gray
            Write-OptLog -Message "$StepName : 이미 적용됨 ($Name = $Value)" -Status "Skipped"
            return $false
        }

        # 값 설정
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        $displayDesc = if ($Description) { " - $Description" } else { "" }
        Write-Host "  - $StepName : 적용됨$displayDesc" -ForegroundColor Green
        Write-OptLog -Message "$StepName : 적용됨 ($Name = $Value)" -Status "Applied"
        return $true
    } catch {
        Write-Host "  - $StepName : 실패 - $($_.Exception.Message)" -ForegroundColor Red
        Write-OptLog -Message "$StepName : 실패 - $($_.Exception.Message)" -Status "Failed"
        return $false
    }
}

function Set-ServiceIfDifferent {
    param(
        [string]$ServiceName,
        [string]$StartupType,
        [string]$StepName,
        [switch]$StopService
    )

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        $currentStartType = (Get-WmiObject Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue).StartMode

        # 매핑: Automatic -> Auto, Manual -> Manual, Disabled -> Disabled
        $targetStartMode = switch ($StartupType) {
            "Automatic" { "Auto" }
            "Manual" { "Manual" }
            "Disabled" { "Disabled" }
            default { $StartupType }
        }

        if (-not $global:ForceOverride -and $currentStartType -eq $targetStartMode) {
            Write-Host "  - $StepName : 이미 $StartupType (스킵)" -ForegroundColor Gray
            Write-OptLog -Message "$StepName : 이미 $StartupType" -Status "Skipped"
            return $false
        }

        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
        if ($StopService -and $service.Status -eq 'Running') {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        }
        Write-Host "  - $StepName : $StartupType 로 변경됨" -ForegroundColor Green
        Write-OptLog -Message "$StepName : $StartupType 로 변경됨" -Status "Applied"
        return $true
    } catch {
        if ($_.Exception.Message -like "*was not found*" -or $_.Exception.Message -like "*찾을 수 없*") {
            Write-Host "  - $StepName : 서비스 없음 (스킵)" -ForegroundColor Gray
            Write-OptLog -Message "$StepName : 서비스 없음" -Status "Skipped"
        } else {
            Write-Host "  - $StepName : 실패 - $($_.Exception.Message)" -ForegroundColor Red
            Write-OptLog -Message "$StepName : 실패 - $($_.Exception.Message)" -Status "Failed"
        }
        return $false
    }
}

function Remove-OneDriveIfExists {
    param([string]$StepName)

    # OneDrive 설치 여부 확인
    $oneDriveSetup64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    $oneDriveSetup32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
    $oneDriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
    $oneDriveFolder = "$env:USERPROFILE\OneDrive"
    $oneDriveApp = "$env:LOCALAPPDATA\Microsoft\OneDrive"

    # OneDrive가 이미 제거되었는지 확인
    $isOneDriveInstalled = (Test-Path $oneDriveSetup64) -or (Test-Path $oneDriveSetup32) -or
                           $oneDriveProcess -or (Test-Path $oneDriveApp)

    if (-not $global:ForceOverride -and -not $isOneDriveInstalled) {
        Write-Host "  - $StepName : 이미 제거됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "$StepName : 이미 제거됨" -Status "Skipped"
        return $false
    }

    return $true  # 제거 진행 필요
}

function Test-FirewallDisabled {
    param([string]$ProfileName)

    try {
        $profile = Get-NetFirewallProfile -Name $ProfileName -ErrorAction Stop
        return ($profile.Enabled -eq $false)
    } catch {
        return $false
    }
}

function Test-DefenderRealTimeDisabled {
    try {
        $mpStatus = Get-MpComputerStatus -ErrorAction Stop
        return (-not $mpStatus.RealTimeProtectionEnabled)
    } catch {
        # Defender 상태 확인 불가 = 비활성화됨으로 간주
        return $true
    }
}

#endregion 공통 함수

Write-Host "=== OneDrive 삭제, 방화벽 해제 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "주의: 이 스크립트는 서버/로컬 네트워크 환경용입니다." -ForegroundColor Red
if ($global:ForceOverride) {
    Write-Host "[ForceOverride 모드: 모든 설정 강제 재적용]" -ForegroundColor Magenta
}
Write-Host ""


# 1. Windows Defender 보호 기능 비활성화
Write-Host "[1/5] Windows Defender 보호 기능 비활성화" -ForegroundColor Yellow
Write-Host ""

# 전체 Defender 비활성화 여부 체크
$defenderAlreadyDisabled = Test-DefenderRealTimeDisabled
if (-not $global:ForceOverride -and $defenderAlreadyDisabled) {
    Write-Host "  [1-1~1-11] Windows Defender 이미 비활성화됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "Windows Defender 설정 11개: 이미 비활성화됨" -Status "Skipped"
} else {
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
            Write-OptLog -Message "Tamper Protection 활성화됨 - 수동 해제 필요" -Status "Info"
        } else {
            Write-Host "    - Tamper Protection이 비활성화되어 있습니다" -ForegroundColor Green
            Write-OptLog -Message "Tamper Protection 비활성화 확인" -Status "Info"
        }
    } catch {
        Write-Host "    - Defender 상태 확인 실패 (이미 비활성화됨)" -ForegroundColor Yellow
        Write-OptLog -Message "Defender 상태 확인 불가 - 이미 비활성화된 것으로 추정" -Status "Info"
    }

    # 1-2. 실시간 보호 비활성화
    Write-Host "  [1-2] 실시간 보호 비활성화..." -ForegroundColor Cyan
    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
        Write-Host "    - 실시간 보호 비활성화 완료" -ForegroundColor Green
        Write-OptLog -Message "실시간 보호 비활성화" -Status "Applied"
    } catch {
        Write-Host "    - 실시간 보호 비활성화 실패 (Tamper Protection 또는 권한 문제)" -ForegroundColor Red
        # 레지스트리로 시도
        Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" `
            -Name "DisableRealtimeMonitoring" -Value 1 -StepName "실시간 보호 정책 (레지스트리)"
    }

    # 1-3. 개발자 드라이브 보호 비활성화
    Write-Host "  [1-3] 개발자 드라이브 보호 비활성화..." -ForegroundColor Cyan
    try {
        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Build -ge 22631) {
            # Dev Drive 존재 여부 확인
            $devDriveExists = $false
            try {
                $fsutilOutput = & fsutil devdrv query 2>$null
                if ($fsutilOutput -and $fsutilOutput -notmatch "Developer volumes are not enabled") {
                    $devDriveExists = $true
                }
            } catch { }

            if ($devDriveExists) {
                Set-MpPreference -EnableDevDriveProtection $false -ErrorAction Stop
                Write-Host "    - 개발자 드라이브 보호 비활성화 완료" -ForegroundColor Green
                Write-OptLog -Message "개발자 드라이브 보호 비활성화" -Status "Applied"
            } else {
                Write-Host "    - 개발자 드라이브가 없음 - 설정 스킵" -ForegroundColor Yellow
                Write-OptLog -Message "개발자 드라이브 보호 - Dev Drive 없음" -Status "Skipped"
            }
        } else {
            Write-Host "    - 개발자 드라이브 보호는 Windows 11 23H2+ 에서만 지원" -ForegroundColor Yellow
            Write-OptLog -Message "개발자 드라이브 보호 - OS 버전 미지원" -Status "Skipped"
        }
    } catch {
        Write-Host "    - 개발자 드라이브 보호 비활성화 실패: $_" -ForegroundColor Red
        Write-OptLog -Message "개발자 드라이브 보호 비활성화 실패" -Status "Failed"
    }

    # 1-4. 클라우드 전송 보호 비활성화
    Write-Host "  [1-4] 클라우드 전송 보호 비활성화..." -ForegroundColor Cyan
    try {
        Set-MpPreference -MAPSReporting 0 -ErrorAction Stop
        Write-Host "    - 클라우드 전송 보호 (MAPS) 비활성화 완료" -ForegroundColor Green
        Write-OptLog -Message "클라우드 전송 보호 비활성화" -Status "Applied"
    } catch {
        Write-Host "    - 클라우드 전송 보호 비활성화 실패" -ForegroundColor Red
        # 레지스트리로 시도
        Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" `
            -Name "SpynetReporting" -Value 0 -StepName "MAPS 정책 (레지스트리)"
        Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet" `
            -Name "SubmitSamplesConsent" -Value 2 -StepName "샘플 전송 정책 (레지스트리)"
    }

    # 1-5. 자동 샘플 전송 비활성화
    Write-Host "  [1-5] 자동 샘플 전송 비활성화..." -ForegroundColor Cyan
    try {
        Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction Stop
        Write-Host "    - 자동 샘플 전송 비활성화 완료" -ForegroundColor Green
        Write-OptLog -Message "자동 샘플 전송 비활성화" -Status "Applied"
    } catch {
        Write-Host "    - 자동 샘플 전송 비활성화 실패" -ForegroundColor Red
        Write-OptLog -Message "자동 샘플 전송 비활성화 실패" -Status "Failed"
    }

    # 1-6. 추가 Defender 정책 레지스트리 설정
    Write-Host "  [1-6] Defender 정책 레지스트리 설정..." -ForegroundColor Cyan
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" `
        -Name "DisableAntiSpyware" -Value 1 -StepName "DisableAntiSpyware"
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" `
        -Name "DisableAntiVirus" -Value 1 -StepName "DisableAntiVirus"

    # Real-Time Protection 정책
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -Name "DisableBehaviorMonitoring" -Value 1 -StepName "DisableBehaviorMonitoring"
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -Name "DisableOnAccessProtection" -Value 1 -StepName "DisableOnAccessProtection"
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -Name "DisableScanOnRealtimeEnable" -Value 1 -StepName "DisableScanOnRealtimeEnable"
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -Name "DisableRealtimeMonitoring" -Value 1 -StepName "DisableRealtimeMonitoring (정책)"
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" `
        -Name "DisableIOAVProtection" -Value 1 -StepName "DisableIOAVProtection"

    # 1-7. 부팅 시 Defender 비활성화 예약 작업 등록
    Write-Host "  [1-7] 부팅 시 Defender 비활성화 예약 작업 등록..." -ForegroundColor Cyan
    $taskName = "DisableDefenderRealtime"
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if (-not $global:ForceOverride -and $existingTask) {
        Write-Host "    - 예약 작업 이미 등록됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "Defender 비활성화 예약 작업 (부팅): 이미 등록됨" -Status "Skipped"
    } else {
        # 기존 작업 삭제
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        }

        $psCommand = @'
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
Set-MpPreference -MAPSReporting 0 -ErrorAction SilentlyContinue
Set-MpPreference -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
'@

        try {
            $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"$psCommand`""
            $trigger = New-ScheduledTaskTrigger -AtStartup
            $trigger.Delay = "PT1M"
            $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Disable Windows Defender Real-time Protection on boot" -Force | Out-Null
            Write-Host "    - 부팅 시 Defender 비활성화 예약 작업 등록 완료" -ForegroundColor Green
            Write-OptLog -Message "Defender 비활성화 예약 작업 (부팅) 등록" -Status "Applied"

            Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            Write-Host "    - 예약 작업 즉시 실행" -ForegroundColor Green
        } catch {
            Write-Host "    - 예약 작업 등록 실패: $($_.Exception.Message)" -ForegroundColor Red
            Write-OptLog -Message "Defender 비활성화 예약 작업 등록 실패: $($_.Exception.Message)" -Status "Failed"
        }
    }

    # 1-8. 로그온 시에도 비활성화 (백업용)
    Write-Host "  [1-8] 로그온 시 Defender 비활성화 예약 작업 등록..." -ForegroundColor Cyan
    $taskNameLogon = "DisableDefenderRealtimeLogon"
    $existingTaskLogon = Get-ScheduledTask -TaskName $taskNameLogon -ErrorAction SilentlyContinue

    if (-not $global:ForceOverride -and $existingTaskLogon) {
        Write-Host "    - 로그온 예약 작업 이미 등록됨 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "Defender 비활성화 예약 작업 (로그온): 이미 등록됨" -Status "Skipped"
    } else {
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
            Write-OptLog -Message "Defender 비활성화 예약 작업 (로그온) 등록" -Status "Applied"
        } catch {
            Write-Host "    - 로그온 예약 작업 등록 실패: $($_.Exception.Message)" -ForegroundColor Red
            Write-OptLog -Message "Defender 비활성화 예약 작업 (로그온) 실패: $($_.Exception.Message)" -Status "Failed"
        }
    }

    # 1-9. Windows Security 알림 비활성화 (TrustedInstaller 권한 필요 항목 제거됨)
    # 참고: WinDefend, SecurityHealthService, wscsvc, Defender 드라이버 비활성화는
    #       TrustedInstaller 권한이 필요하여 제거됨. 정책 레지스트리와 예약 작업으로 대체.
    Write-Host "  [1-9] Windows Security 알림 비활성화 중..." -ForegroundColor Cyan
    Set-RegistryIfDifferent -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance" `
        -Name "Enabled" -Value 0 -StepName "Windows Security 알림 비활성화"

    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" `
        -Name "HideSystray" -Value 1 -StepName "시스템 트레이 보안 아이콘 숨기기"

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
}
Write-Host ""


# 2. Windows 방화벽 완전 해제
Write-Host ""
Write-Host "[2/5] Windows 방화벽 해제 중..." -ForegroundColor Yellow

# 방화벽이 이미 해제되었는지 확인
$domainFwDisabled = Test-FirewallDisabled -ProfileName "Domain"
$privateFwDisabled = Test-FirewallDisabled -ProfileName "Private"
$publicFwDisabled = Test-FirewallDisabled -ProfileName "Public"
$allFirewallsDisabled = $domainFwDisabled -and $privateFwDisabled -and $publicFwDisabled

if (-not $global:ForceOverride -and $allFirewallsDisabled) {
    Write-Host "  [2-1~2-6] 모든 방화벽 프로필 이미 해제됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "방화벽 설정: 모든 프로필 이미 해제됨" -Status "Skipped"
} else {
    # 2-1. mpsdrv (방화벽 드라이버) 활성화
    Write-Host "  [2-1] mpsdrv (방화벽 드라이버) 확인 중..." -ForegroundColor Cyan
    $mpsdrvRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\mpsdrv"
    $mpsdrvStart = (Get-ItemProperty -Path $mpsdrvRegPath -Name "Start" -ErrorAction SilentlyContinue).Start

    if (-not $global:ForceOverride -and $mpsdrvStart -eq 0) {
        Write-Host "    - mpsdrv 이미 Boot 시작 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "mpsdrv: 이미 Boot 시작" -Status "Skipped"
    } else {
        Write-Host "    - 현재 mpsdrv Start 값: $mpsdrvStart (0=Boot, 1=System, 2=Auto, 3=수동, 4=비활성화)" -ForegroundColor White
        Set-ItemProperty -Path $mpsdrvRegPath -Name "Start" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Write-Host "    - mpsdrv Start 값을 0 (Boot)으로 변경" -ForegroundColor Green
        Write-OptLog -Message "mpsdrv Start 값 변경 (Boot)" -Status "Applied"
    }
    $scResult = sc.exe config mpsdrv start= boot 2>&1
    Write-Host "    - sc config mpsdrv: $scResult" -ForegroundColor White
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
        Write-OptLog -Message "BFE 서비스 자동 시작 설정" -Status "Applied"
        $scStartBfe = sc.exe start BFE 2>&1
        Write-Host "    - sc start BFE: $scStartBfe" -ForegroundColor White
        Start-Sleep -Seconds 2
        $bfeService = Get-Service -Name "BFE" -ErrorAction SilentlyContinue
        Write-Host "    - BFE 상태 (재확인): $($bfeService.Status)" -ForegroundColor White
    } else {
        Write-Host "    - BFE 이미 실행 중" -ForegroundColor Green
        Write-OptLog -Message "BFE 서비스: 이미 실행 중" -Status "Skipped"
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
        Write-OptLog -Message "mpssvc 서비스 자동 시작 설정" -Status "Applied"
        $scStartMpssvc = sc.exe start mpssvc 2>&1
        Write-Host "    - sc start mpssvc: $scStartMpssvc" -ForegroundColor White
        Start-Sleep -Seconds 2
        $firewallService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
        Write-Host "    - mpssvc 상태 (재확인): $($firewallService.Status)" -ForegroundColor White

        if ($firewallService.Status -ne "Running") {
            Write-Host "    - 경고: mpssvc 시작 실패. 재부팅 후 다시 시도 필요" -ForegroundColor Red
            Write-OptLog -Message "mpssvc 서비스 시작 실패" -Status "Failed"
        }
    } else {
        Write-Host "    - mpssvc 이미 실행 중" -ForegroundColor Green
        Write-OptLog -Message "mpssvc 서비스: 이미 실행 중" -Status "Skipped"
    }

    # 2-4. 방화벽 설정 적용
    Write-Host "  [2-4] 방화벽 설정 적용 중..." -ForegroundColor Cyan
    $firewallService = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
    if ($firewallService.Status -eq "Running") {
        # 모든 프로필 방화벽 해제
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
        Write-Host "    - 도메인, 공용, 개인 프로필 방화벽 해제" -ForegroundColor Green
        Write-OptLog -Message "방화벽 프로필 해제 (Domain, Public, Private)" -Status "Applied"

        # 방화벽 기본 동작을 Allow로 설정
        Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Allow -DefaultOutboundAction Allow
        Write-Host "    - 기본 인바운드/아웃바운드 정책을 Allow로 설정" -ForegroundColor Green
        Write-OptLog -Message "방화벽 기본 정책 Allow 설정" -Status "Applied"

        # RDP 포트 명시적 허용
        $rdpRuleName = "Remote Desktop - User Mode (TCP-In) - Custom"
        $existingRule = Get-NetFirewallRule -DisplayName $rdpRuleName -ErrorAction SilentlyContinue
        if (!$existingRule) {
            New-NetFirewallRule -DisplayName $rdpRuleName -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -Profile Any -Enabled True | Out-Null
            Write-Host "    - RDP 포트 (3389) 방화벽 규칙 추가" -ForegroundColor Green
            Write-OptLog -Message "RDP 방화벽 규칙 추가" -Status "Applied"
        } else {
            Set-NetFirewallRule -DisplayName $rdpRuleName -Enabled True
            Write-Host "    - RDP 포트 (3389) 방화벽 규칙 활성화" -ForegroundColor Green
            Write-OptLog -Message "RDP 방화벽 규칙: 이미 존재" -Status "Skipped"
        }

        Get-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue | Set-NetFirewallRule -Enabled True -ErrorAction SilentlyContinue
        Write-Host "    - 기존 원격 데스크톱 규칙 활성화" -ForegroundColor Green
    } else {
        Write-Host "    - 경고: mpssvc가 실행되지 않아 방화벽 설정을 건너뜀" -ForegroundColor Red
        Write-Host "    - 재부팅 후 스크립트를 다시 실행하세요" -ForegroundColor Red
        Write-OptLog -Message "방화벽 설정 건너뜀 - mpssvc 미실행" -Status "Failed"
    }

    # 방화벽 정책 비활성화 (레지스트리)
    Write-Host "  [2-5] 방화벽 정책 레지스트리 설정 중..." -ForegroundColor Cyan
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile" `
        -Name "EnableFirewall" -Value 0 -StepName "DomainProfile 방화벽 정책"
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile" `
        -Name "EnableFirewall" -Value 0 -StepName "StandardProfile 방화벽 정책"
    Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\PublicProfile" `
        -Name "EnableFirewall" -Value 0 -StepName "PublicProfile 방화벽 정책"

    # 2-6. RDP (원격 데스크톱) 서비스 활성화
    Write-Host "  [2-6] RDP (원격 데스크톱) 서비스 활성화 중..." -ForegroundColor Cyan

    $rdpRegPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
    Set-RegistryIfDifferent -Path $rdpRegPath -Name "fDenyTSConnections" -Value 0 `
        -StepName "RDP 연결 허용" -Description "0=활성화"

    $rdpTcpPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
    Set-RegistryIfDifferent -Path $rdpTcpPath -Name "UserAuthentication" -Value 1 `
        -StepName "네트워크 레벨 인증(NLA)" -Description "보안 유지"

    # TermService 확인
    Write-Host "    - TermService (원격 데스크톱 서비스) 확인 중..." -ForegroundColor White
    $termService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
    if ($termService.Status -ne "Running") {
        sc.exe config TermService start= auto | Out-Null
        $scStartTerm = sc.exe start TermService 2>&1
        Write-Host "    - sc start TermService: $scStartTerm" -ForegroundColor White
        Write-OptLog -Message "TermService 시작" -Status "Applied"
        Start-Sleep -Seconds 2
        $termService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue
        Write-Host "    - TermService 상태 (재확인): $($termService.Status)" -ForegroundColor White
    } else {
        Write-Host "    - TermService 이미 실행 중" -ForegroundColor Green
        Write-OptLog -Message "TermService: 이미 실행 중" -Status "Skipped"
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
}


# 3. OneDrive 프로세스 종료
Write-Host ""
Write-Host "[3/5] OneDrive 프로세스 종료 중..." -ForegroundColor Yellow

$oneDriveProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
if (-not $global:ForceOverride -and -not $oneDriveProcess) {
    Write-Host "  - OneDrive 프로세스 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "OneDrive 프로세스: 실행 중 아님" -Status "Skipped"
} else {
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-Host "  - OneDrive 프로세스 종료" -ForegroundColor Green
    Write-OptLog -Message "OneDrive 프로세스 종료" -Status "Applied"
}


# 4. OneDrive 제거
Write-Host ""
Write-Host "[4/5] OneDrive 제거 중..." -ForegroundColor Yellow

if (Remove-OneDriveIfExists -StepName "OneDrive 제거") {
    $oneDriveSetup64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    $oneDriveSetup32 = "$env:SystemRoot\System32\OneDriveSetup.exe"

    if (Test-Path $oneDriveSetup64) {
        Start-Process $oneDriveSetup64 -ArgumentList "/uninstall" -Wait -NoNewWindow
        Write-Host "  - OneDrive 제거 완료 (64비트)" -ForegroundColor Green
        Write-OptLog -Message "OneDrive 제거 (64비트)" -Status "Applied"
    } elseif (Test-Path $oneDriveSetup32) {
        Start-Process $oneDriveSetup32 -ArgumentList "/uninstall" -Wait -NoNewWindow
        Write-Host "  - OneDrive 제거 완료 (32비트)" -ForegroundColor Green
        Write-OptLog -Message "OneDrive 제거 (32비트)" -Status "Applied"
    } else {
        $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetPath) {
            winget uninstall "Microsoft.OneDrive" --silent --accept-source-agreements 2>$null
            Write-Host "  - OneDrive 제거 완료 (winget)" -ForegroundColor Green
            Write-OptLog -Message "OneDrive 제거 (winget)" -Status "Applied"
        } else {
            Write-Host "  - OneDrive가 이미 제거되었거나 찾을 수 없음" -ForegroundColor Yellow
            Write-OptLog -Message "OneDrive: 이미 제거됨" -Status "Skipped"
        }
    }
}


# 5. OneDrive 관련 레지스트리 및 폴더 정리
Write-Host ""
Write-Host "[5/5] OneDrive 잔여 파일 정리 중..." -ForegroundColor Yellow

# OneDrive 자동 시작 제거
$oneDriveAutoStart = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
if (-not $global:ForceOverride -and -not $oneDriveAutoStart) {
    Write-Host "  - OneDrive 자동 시작 이미 제거됨 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "OneDrive 자동 시작: 이미 제거됨" -Status "Skipped"
} else {
    Remove-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -ErrorAction SilentlyContinue
    Write-Host "  - OneDrive 자동 시작 제거" -ForegroundColor Green
    Write-OptLog -Message "OneDrive 자동 시작 제거" -Status "Applied"
}

# OneDrive 설치 방지 정책
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" `
    -Name "DisableFileSyncNGSC" -Value 1 -StepName "OneDrive 동기화 비활성화 정책"
Set-RegistryIfDifferent -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" `
    -Name "DisableFileSync" -Value 1 -StepName "OneDrive 파일 동기화 비활성화"

# 탐색기에서 OneDrive 숨기기
$explorerCLSID = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
$explorerWow64 = "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"

if (!(Test-Path "HKCR:")) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
}

if (Test-Path $explorerCLSID) {
    $currentVal = (Get-ItemProperty -Path $explorerCLSID -Name "System.IsPinnedToNameSpaceTree" -ErrorAction SilentlyContinue)."System.IsPinnedToNameSpaceTree"
    if (-not $global:ForceOverride -and $currentVal -eq 0) {
        Write-Host "  - 탐색기 OneDrive 이미 숨김 (스킵)" -ForegroundColor Gray
        Write-OptLog -Message "탐색기 OneDrive 숨김: 이미 적용됨" -Status "Skipped"
    } else {
        Set-ItemProperty -Path $explorerCLSID -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Write-Host "  - 탐색기에서 OneDrive 숨김" -ForegroundColor Green
        Write-OptLog -Message "탐색기 OneDrive 숨김" -Status "Applied"
    }
}
if (Test-Path $explorerWow64) {
    Set-ItemProperty -Path $explorerWow64 -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}

# OneDrive 폴더 삭제
$oneDriveFolders = @(
    "$env:USERPROFILE\OneDrive",
    "$env:LOCALAPPDATA\Microsoft\OneDrive",
    "$env:PROGRAMDATA\Microsoft OneDrive",
    "C:\OneDriveTemp"
)

$foldersExist = $false
foreach ($folder in $oneDriveFolders) {
    if (Test-Path $folder) {
        $foldersExist = $true
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if ($foldersExist) {
    Write-Host "  - OneDrive 폴더 삭제 완료" -ForegroundColor Green
    Write-OptLog -Message "OneDrive 폴더 삭제" -Status "Applied"
} else {
    Write-Host "  - OneDrive 폴더 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "OneDrive 폴더: 이미 삭제됨" -Status "Skipped"
}

# 예약 작업 제거
$oneDriveTasks = Get-ScheduledTask -TaskPath '\' -TaskName '*OneDrive*' -ErrorAction SilentlyContinue
if (-not $global:ForceOverride -and -not $oneDriveTasks) {
    Write-Host "  - OneDrive 예약 작업 없음 (스킵)" -ForegroundColor Gray
    Write-OptLog -Message "OneDrive 예약 작업: 없음" -Status "Skipped"
} else {
    $oneDriveTasks | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  - OneDrive 예약 작업 제거" -ForegroundColor Green
    Write-OptLog -Message "OneDrive 예약 작업 제거" -Status "Applied"
}


# 로그 저장
Save-OptLog

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  - 적용됨: $($global:AppliedCount) 개" -ForegroundColor Green
Write-Host "  - 스킵됨: $($global:SkippedCount) 개 (이미 최적 설정)" -ForegroundColor Gray
Write-Host "  - 실패: $($global:FailedCount) 개" -ForegroundColor $(if($global:FailedCount -gt 0){"Red"}else{"Gray"})
Write-Host ""
Write-Host "로그 파일: $($global:LogFilePath)" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - Windows Defender 보호 기능 비활성화 (정책 + 예약 작업)" -ForegroundColor White
Write-Host "    (실시간 보호, 클라우드 보호, 샘플 전송 비활성화)" -ForegroundColor White
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
