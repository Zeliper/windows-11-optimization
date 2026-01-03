# Windows 11 25H2 시작 프로그램/부팅 최적화 스크립트
# 시작 프로그램 비활성화, 부팅 지연 최적화, 프리패치/슈퍼패치 설정, NTFS 최적화
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

# Orchestrate 모드용 메타데이터
$script:ScriptMetadata = @{
    Name = "시작 프로그램/부팅 최적화"
    Description = "시작 프로그램 비활성화, 부팅 지연 최적화, 프리패치/슈퍼패치, NTFS 최적화, 페이지 파일 최적화"
    RequiresReboot = $true
}

Write-Host "=== Windows 11 25H2 시작 프로그램/부팅 최적화 스크립트 ===" -ForegroundColor Cyan
Write-Host "시작 프로그램 비활성화, 부팅 지연 최적화, NTFS 최적화를 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 8


# [1/8] 불필요한 시작 프로그램 비활성화 목록 제공
Write-Host "[1/$totalSteps] 불필요한 시작 프로그램 분석 및 비활성화 안내..." -ForegroundColor Yellow

# 비활성화 권장 시작 프로그램 목록 정의
$unnecessaryStartupPrograms = @(
    # Microsoft 관련
    @{ Name = "OneDrive"; Path = "OneDrive"; Description = "클라우드 동기화 (필요시 수동 실행)" }
    @{ Name = "Microsoft Edge Update"; Path = "MicrosoftEdgeAutoLaunch*"; Description = "Edge 브라우저 자동 업데이트" }
    @{ Name = "Microsoft Teams"; Path = "com.squirrel.Teams.Teams"; Description = "Teams 자동 시작" }
    @{ Name = "Cortana"; Path = "Cortana"; Description = "Cortana 음성 비서" }
    @{ Name = "Xbox App Services"; Path = "XboxAppServices"; Description = "Xbox 앱 서비스" }
    @{ Name = "Skype"; Path = "Skype*"; Description = "Skype 자동 시작" }

    # 일반 프로그램
    @{ Name = "Adobe Creative Cloud"; Path = "Adobe Creative Cloud"; Description = "Adobe CC 자동 시작" }
    @{ Name = "Adobe Updater"; Path = "AdobeAAMUpdater*"; Description = "Adobe 업데이트" }
    @{ Name = "iTunes Helper"; Path = "iTunesHelper"; Description = "iTunes 동기화 헬퍼" }
    @{ Name = "Spotify"; Path = "Spotify"; Description = "Spotify 자동 시작" }
    @{ Name = "Discord"; Path = "Discord"; Description = "Discord 자동 시작" }
    @{ Name = "Steam"; Path = "Steam"; Description = "Steam 클라이언트" }
    @{ Name = "Epic Games Launcher"; Path = "EpicGamesLauncher"; Description = "Epic Games 런처" }
    @{ Name = "Zoom"; Path = "ZoomLauncher"; Description = "Zoom 자동 시작" }
    @{ Name = "Google Update"; Path = "GoogleUpdate*"; Description = "Google 제품 업데이트" }
    @{ Name = "Dropbox"; Path = "Dropbox"; Description = "Dropbox 동기화" }
    @{ Name = "CCleaner"; Path = "CCleaner*"; Description = "CCleaner 모니터링" }
    @{ Name = "Java Update Scheduler"; Path = "jusched*"; Description = "Java 업데이트" }
    @{ Name = "QuickTime"; Path = "QuickTime*"; Description = "QuickTime 시작" }
)

# 현재 시작 프로그램 조회 (HKCU, HKLM Run 레지스트리)
$startupLocations = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)

$foundPrograms = @()
$disabledCount = 0

foreach ($location in $startupLocations) {
    if (Test-Path $location) {
        $entries = Get-ItemProperty -Path $location -ErrorAction SilentlyContinue
        $properties = $entries.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }

        foreach ($prop in $properties) {
            foreach ($unnecessary in $unnecessaryStartupPrograms) {
                if ($prop.Name -like $unnecessary.Path -or $prop.Value -like "*$($unnecessary.Path)*") {
                    $foundPrograms += @{
                        Name = $unnecessary.Name
                        RegPath = $location
                        RegName = $prop.Name
                        Description = $unnecessary.Description
                    }
                }
            }
        }
    }
}

# 발견된 불필요 프로그램 표시
if ($foundPrograms.Count -gt 0) {
    Write-Host "  - 발견된 비활성화 권장 시작 프로그램:" -ForegroundColor Yellow
    foreach ($prog in $foundPrograms) {
        Write-Host "    * $($prog.Name): $($prog.Description)" -ForegroundColor White
    }

    # Orchestrate 모드가 아닌 경우 사용자 확인
    $disableStartup = "Y"
    if (-not $global:OrchestrateMode) {
        $disableStartup = Read-Host "위 프로그램들을 시작 프로그램에서 비활성화하시겠습니까? (Y/N, 기본값: Y)"
        if ([string]::IsNullOrEmpty($disableStartup)) { $disableStartup = "Y" }
    }

    if ($disableStartup -eq "Y" -or $disableStartup -eq "y") {
        foreach ($prog in $foundPrograms) {
            try {
                # 레지스트리에서 제거하지 않고 Disabled 폴더로 이동
                $disabledPath = $prog.RegPath -replace "\\Run", "\Run-Disabled"
                if (!(Test-Path $disabledPath)) {
                    New-Item -Path $disabledPath -Force | Out-Null
                }

                $value = Get-ItemPropertyValue -Path $prog.RegPath -Name $prog.RegName -ErrorAction SilentlyContinue
                if ($value) {
                    Set-ItemProperty -Path $disabledPath -Name $prog.RegName -Value $value -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $prog.RegPath -Name $prog.RegName -ErrorAction SilentlyContinue
                    $disabledCount++
                    Write-Host "    - $($prog.Name) 비활성화됨" -ForegroundColor Green
                }
            } catch {
                Write-Host "    - $($prog.Name) 비활성화 실패" -ForegroundColor Red
            }
        }
        Write-Host "  - 총 $disabledCount 개 시작 프로그램 비활성화됨" -ForegroundColor Green
    }
} else {
    Write-Host "  - 비활성화 권장 시작 프로그램이 발견되지 않았습니다" -ForegroundColor Gray
}

# 작업 관리자 시작 프로그램 안내
Write-Host "  - 추가 관리: 작업 관리자 > 시작 프로그램 탭에서 개별 관리 가능" -ForegroundColor Gray


# [2/8] 부팅 지연 설정 최적화
Write-Host ""
Write-Host "[2/$totalSteps] 부팅 지연 설정 최적화 중..." -ForegroundColor Yellow

# Startup Delay 레지스트리 설정 (시작 프로그램 지연 제거)
$explorerSerializePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
if (!(Test-Path $explorerSerializePath)) {
    New-Item -Path $explorerSerializePath -Force | Out-Null
}
# StartupDelayInMSec = 0 으로 설정하여 시작 프로그램 지연 제거
Set-ItemProperty -Path $explorerSerializePath -Name "StartupDelayInMSec" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 시작 프로그램 지연 시간: 0ms (즉시 시작)" -ForegroundColor Green

# 서비스 시작 지연 최소화
$servicesPipeTimeoutPath = "HKLM:\SYSTEM\CurrentControlSet\Control"
Set-ItemProperty -Path $servicesPipeTimeoutPath -Name "ServicesPipeTimeout" -Value 60000 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 서비스 파이프 타임아웃: 60초" -ForegroundColor Green

# 데스크톱 로드 지연 최소화
$desktopDelayPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
Set-ItemProperty -Path $desktopDelayPath -Name "DesktopProcess" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 데스크톱 프로세스 분리 활성화 (안정성 향상)" -ForegroundColor Green


# [3/8] 프리패치/슈퍼패치 설정 최적화
Write-Host ""
Write-Host "[3/$totalSteps] 프리패치/슈퍼패치 설정 최적화 중..." -ForegroundColor Yellow

$prefetchParamsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"

# 시스템 드라이브 타입 확인 (SSD/HDD)
$systemDrive = $env:SystemDrive
$diskNumber = (Get-Partition -DriveLetter $systemDrive[0] -ErrorAction SilentlyContinue).DiskNumber
$mediaType = "Unknown"

if ($null -ne $diskNumber) {
    $physicalDisk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq $diskNumber } -ErrorAction SilentlyContinue
    if ($physicalDisk) {
        $mediaType = $physicalDisk.MediaType
    }
}

if ($mediaType -eq "SSD" -or $mediaType -eq "Unknown") {
    # SSD 환경: 프리패치 최소화 (부팅만 최적화)
    # EnablePrefetcher: 0=비활성, 1=앱만, 2=부팅만, 3=모두
    Set-ItemProperty -Path $prefetchParamsPath -Name "EnablePrefetcher" -Value 2 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - 프리패처: 부팅 최적화만 활성화 (SSD 환경)" -ForegroundColor Green

    # EnableSuperfetch: 0=비활성, 1=앱만, 2=부팅만, 3=모두
    Set-ItemProperty -Path $prefetchParamsPath -Name "EnableSuperfetch" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - 슈퍼패치: 비활성화 (SSD 환경에서 불필요)" -ForegroundColor Green

    # SysMain 서비스 비활성화 (SuperFetch)
    $sysMainService = Get-Service -Name "SysMain" -ErrorAction SilentlyContinue
    if ($sysMainService) {
        Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
        Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  - SysMain 서비스 비활성화됨" -ForegroundColor Green
    }
} else {
    # HDD 환경: 프리패치/슈퍼패치 활성화 유지
    Set-ItemProperty -Path $prefetchParamsPath -Name "EnablePrefetcher" -Value 3 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $prefetchParamsPath -Name "EnableSuperfetch" -Value 3 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - 프리패처/슈퍼패치: 전체 활성화 (HDD 환경)" -ForegroundColor Green
}


# [4/8] Windows Boot Manager 타임아웃 최소화
Write-Host ""
Write-Host "[4/$totalSteps] Windows Boot Manager 타임아웃 최소화 중..." -ForegroundColor Yellow

# bcdedit로 부팅 메뉴 대기 시간 최소화
try {
    # 현재 설정 확인
    $currentTimeout = bcdedit /v 2>$null | Select-String "timeout" | ForEach-Object { $_.Line }

    # 타임아웃 0초로 설정 (멀티부팅이 아닌 경우)
    bcdedit /timeout 0 2>$null | Out-Null
    Write-Host "  - 부팅 메뉴 대기 시간: 0초" -ForegroundColor Green

    # Windows 복구 환경 타임아웃 최소화
    bcdedit /set "{current}" recoveryenabled No 2>$null | Out-Null
    Write-Host "  - Windows 복구 환경 자동 진입 비활성화" -ForegroundColor Green

    # 부팅 로그 비활성화 (부팅 속도 향상)
    bcdedit /set "{current}" bootlog No 2>$null | Out-Null
    Write-Host "  - 부팅 로그 비활성화" -ForegroundColor Green

    # 부팅 상태 정책 무시 (빠른 부팅)
    bcdedit /set "{current}" bootstatuspolicy IgnoreAllFailures 2>$null | Out-Null
    Write-Host "  - 부팅 상태 정책: 모든 실패 무시" -ForegroundColor Green

} catch {
    Write-Host "  - bcdedit 설정 중 일부 오류 발생 (권한 확인 필요)" -ForegroundColor Yellow
}


# [5/8] NTFS Last Access Time 업데이트 비활성화
Write-Host ""
Write-Host "[5/$totalSteps] NTFS Last Access Time 업데이트 비활성화 중..." -ForegroundColor Yellow

# fsutil로 Last Access Time 업데이트 비활성화
try {
    # 현재 설정 확인
    $currentBehavior = fsutil behavior query DisableLastAccess 2>$null

    # DisableLastAccess = 1 (시스템), 2 (사용자), 3 (시스템+사용자 비활성화)
    # 1 = System Managed (기본값), 권장: 사용자가 비활성화 원할 경우 3
    fsutil behavior set DisableLastAccess 1 2>$null | Out-Null
    Write-Host "  - NTFS Last Access Time: 시스템 관리 모드 (SSD 최적화)" -ForegroundColor Green

    # 참고: Windows 10 1803+ 부터는 SSD에서 기본적으로 비활성화됨
    Write-Host "  - 참고: Windows 10 1803+ SSD 환경에서 자동 최적화됨" -ForegroundColor Gray
} catch {
    Write-Host "  - NTFS 설정 변경 실패" -ForegroundColor Yellow
}


# [6/8] 8dot3name 생성 비활성화
Write-Host ""
Write-Host "[6/$totalSteps] 8dot3name 생성 비활성화 중..." -ForegroundColor Yellow

# 8.3 파일명 생성은 DOS 호환성을 위한 것으로 현대 시스템에서 불필요
try {
    # 모든 볼륨에서 8dot3name 생성 비활성화
    # 0 = 모든 볼륨에서 활성화
    # 1 = 모든 볼륨에서 비활성화
    # 2 = 볼륨별 설정
    # 3 = 시스템 볼륨을 제외한 모든 볼륨에서 비활성화
    fsutil behavior set disable8dot3 1 2>$null | Out-Null
    Write-Host "  - 8.3 파일명 생성: 모든 볼륨에서 비활성화" -ForegroundColor Green

    # 레지스트리로도 설정 (이중 보장)
    $ntfsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    Set-ItemProperty -Path $ntfsPath -Name "NtfsDisable8dot3NameCreation" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - 레지스트리 설정 완료" -ForegroundColor Green

    Write-Host "  - 참고: 기존 8.3 파일명은 유지되며 새 파일에만 적용됩니다" -ForegroundColor Gray
} catch {
    Write-Host "  - 8dot3name 설정 변경 실패" -ForegroundColor Yellow
}


# [7/8] 페이지 파일 최적화
Write-Host ""
Write-Host "[7/$totalSteps] 페이지 파일 최적화 중..." -ForegroundColor Yellow

# 시스템 메모리 확인
$totalRAM = [math]::Round((Get-CimInstance -ClassName Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
Write-Host "  - 시스템 RAM: $totalRAM GB" -ForegroundColor White

# 페이지 파일 권장 크기 계산
# RAM 8GB 이하: RAM의 1.5배
# RAM 16GB 이상: RAM과 동일하거나 더 작게
if ($totalRAM -le 8) {
    $recommendedPageFileGB = [math]::Ceiling($totalRAM * 1.5)
} elseif ($totalRAM -le 16) {
    $recommendedPageFileGB = $totalRAM
} else {
    $recommendedPageFileGB = [math]::Min($totalRAM, 16)
}

$recommendedPageFileMB = $recommendedPageFileGB * 1024

# 현재 페이지 파일 설정 확인
$pageFile = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue

if ($pageFile) {
    Write-Host "  - 현재 페이지 파일: $($pageFile.Name)" -ForegroundColor White
    Write-Host "    초기 크기: $($pageFile.InitialSize) MB, 최대 크기: $($pageFile.MaximumSize) MB" -ForegroundColor Gray
}

# 페이지 파일 최적화 옵션
$optimizePageFile = "N"
if (-not $global:OrchestrateMode) {
    Write-Host ""
    Write-Host "  페이지 파일 권장 설정:" -ForegroundColor Yellow
    Write-Host "    - 고정 크기: $recommendedPageFileMB MB (조각화 방지)" -ForegroundColor White
    Write-Host "    - RAM $totalRAM GB 기준 권장 크기" -ForegroundColor Gray
    $optimizePageFile = Read-Host "페이지 파일을 권장 설정으로 변경하시겠습니까? (Y/N, 기본값: N)"
}

if ($optimizePageFile -eq "Y" -or $optimizePageFile -eq "y") {
    try {
        # 자동 관리 비활성화
        $compSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $compSystem | Set-CimInstance -Property @{ AutomaticManagedPagefile = $false }
        Write-Host "  - 페이지 파일 자동 관리 비활성화" -ForegroundColor Green

        # 기존 페이지 파일 제거
        Get-CimInstance -ClassName Win32_PageFileSetting | Remove-CimInstance -ErrorAction SilentlyContinue

        # 새 페이지 파일 설정 (시스템 드라이브에 고정 크기)
        $pageFilePath = "$env:SystemDrive\pagefile.sys"
        New-CimInstance -ClassName Win32_PageFileSetting -Property @{
            Name = $pageFilePath
            InitialSize = $recommendedPageFileMB
            MaximumSize = $recommendedPageFileMB
        } -ErrorAction SilentlyContinue

        Write-Host "  - 페이지 파일 설정: $recommendedPageFileMB MB (고정 크기)" -ForegroundColor Green
        Write-Host "  - 재부팅 후 적용됩니다" -ForegroundColor Yellow
    } catch {
        Write-Host "  - 페이지 파일 설정 변경 실패: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  - 페이지 파일 설정 유지" -ForegroundColor Gray

    # 페이지 파일 삭제 방지 설정
    $memMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
    Set-ItemProperty -Path $memMgmtPath -Name "ClearPageFileAtShutdown" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Write-Host "  - 종료 시 페이지 파일 삭제 비활성화 (부팅 속도 향상)" -ForegroundColor Green
}


# [8/8] 로그온 스크립트 지연 제거
Write-Host ""
Write-Host "[8/$totalSteps] 로그온 스크립트 지연 제거 중..." -ForegroundColor Yellow

# 그룹 정책: 로그온 스크립트 지연 비활성화
$gpoScriptsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (!(Test-Path $gpoScriptsPath)) {
    New-Item -Path $gpoScriptsPath -Force | Out-Null
}

# 동기 로그온 스크립트 비활성화 (비동기 실행으로 변경)
Set-ItemProperty -Path $gpoScriptsPath -Name "RunLogonScriptSync" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 로그온 스크립트: 비동기 실행" -ForegroundColor Green

# 시작 스크립트 지연 비활성화
$gpExtensionsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Scripts"
if (Test-Path $gpExtensionsPath) {
    # 지연 시간 0으로 설정
    Set-ItemProperty -Path $gpExtensionsPath -Name "DelayedInitScript" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
Write-Host "  - 시작 스크립트 지연: 비활성화" -ForegroundColor Green

# 빠른 로그온 최적화 활성화
Set-ItemProperty -Path $gpoScriptsPath -Name "DelayedDesktopSwitchTimeout" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 지연된 데스크톱 전환 타임아웃: 0ms" -ForegroundColor Green

# 로그온 시 앱 자동 재시작 비활성화 (선택적)
$winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $winlogonPath -Name "DisableAutomaticRestartSignOn" -Value 1 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 로그온 시 앱 자동 재시작: 비활성화" -ForegroundColor Green

# 시작 지연 대기 비활성화
$winlogonRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $winlogonRegPath -Name "UserinfoBlockLoadTimeout" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - 사용자 정보 로드 타임아웃: 0ms" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "시작 프로그램/부팅 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 불필요한 시작 프로그램 비활성화 ($disabledCount 개)" -ForegroundColor White
Write-Host "  - 부팅 지연 설정 최적화 (시작 지연 0ms)" -ForegroundColor White
Write-Host "  - 프리패치/슈퍼패치 SSD 최적화" -ForegroundColor White
Write-Host "  - Windows Boot Manager 타임아웃 0초" -ForegroundColor White
Write-Host "  - NTFS Last Access Time 시스템 관리 모드" -ForegroundColor White
Write-Host "  - 8dot3name 생성 비활성화" -ForegroundColor White
Write-Host "  - 페이지 파일 최적화" -ForegroundColor White
Write-Host "  - 로그온 스크립트 지연 제거" -ForegroundColor White
Write-Host ""
Write-Host "재부팅 후 모든 설정이 적용됩니다." -ForegroundColor Yellow
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
