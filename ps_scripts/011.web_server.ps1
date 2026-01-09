# Windows 11 25H2 IIS 웹 서버 최적화 스크립트
# IIS 설치, 성능 최적화, TLS 보안 설정
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# 스크립트 버전
$scriptVersion = "1.1.1"
$scriptName = "011.web_server"

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

# =============================================
# 로깅 시스템
# =============================================
$logDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "windows11-optimization-logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$global:LogFilePath = Join-Path $logDir "${scriptName}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$global:LogEntries = @()
$global:AppliedCount = 0
$global:SkippedCount = 0
$global:FailedCount = 0

function Write-OptLog {
    param(
        [string]$Step,
        [string]$Status,  # Applied, Skipped, Failed, Info
        [string]$Message,
        [string]$PreviousValue = "",
        [string]$NewValue = ""
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = [PSCustomObject]@{
        Timestamp = $timestamp
        Step = $Step
        Status = $Status
        Message = $Message
        PreviousValue = $PreviousValue
        NewValue = $NewValue
    }
    $global:LogEntries += $logEntry

    switch ($Status) {
        "Applied" { $global:AppliedCount++ }
        "Skipped" { $global:SkippedCount++ }
        "Failed" { $global:FailedCount++ }
    }
}

function Save-OptLog {
    $logContent = @()
    $logContent += "=" * 60
    $logContent += "Windows 11 IIS 웹 서버 최적화 로그"
    $logContent += "스크립트: $scriptName v$scriptVersion"
    $logContent += "실행 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $logContent += "=" * 60
    $logContent += ""
    $logContent += "## 요약"
    $logContent += "- 적용됨: $global:AppliedCount"
    $logContent += "- 건너뜀 (이미 설정됨): $global:SkippedCount"
    $logContent += "- 실패: $global:FailedCount"
    $logContent += ""
    $logContent += "## 상세 로그"
    $logContent += "-" * 60

    foreach ($entry in $global:LogEntries) {
        $logContent += "[$($entry.Timestamp)] [$($entry.Status)] $($entry.Step)"
        $logContent += "  $($entry.Message)"
        if ($entry.PreviousValue -or $entry.NewValue) {
            $logContent += "  이전: $($entry.PreviousValue) -> 이후: $($entry.NewValue)"
        }
        $logContent += ""
    }

    $logContent | Out-File -FilePath $global:LogFilePath -Encoding UTF8
}

# =============================================
# 헬퍼 함수
# =============================================
function Set-RegistryIfDifferent {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord",
        [string]$Step,
        [string]$Description
    )

    try {
        # 경로가 없으면 생성
        if (!(Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
            Write-OptLog -Step $Step -Status "Applied" -Message "$Description (경로 생성됨)" -NewValue $Value
        }

        $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue

        if ($null -eq $currentValue -or $currentValue.$Name -ne $Value) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
            $prevVal = if ($null -eq $currentValue) { "(없음)" } else { $currentValue.$Name }
            Write-OptLog -Step $Step -Status "Applied" -Message $Description -PreviousValue $prevVal -NewValue $Value
            return $true
        } else {
            Write-OptLog -Step $Step -Status "Skipped" -Message "$Description (이미 설정됨)" -PreviousValue $currentValue.$Name -NewValue $Value
            return $false
        }
    } catch {
        Write-OptLog -Step $Step -Status "Failed" -Message "$Description - 오류: $_"
        return $false
    }
}

Write-Host "=== Windows 11 IIS 웹 서버 최적화 v$scriptVersion ===" -ForegroundColor Cyan
Write-Host "IIS 설치, 성능 최적화, 보안 설정을 수행합니다." -ForegroundColor White
Write-Host ""

$totalSteps = 11


# [1/11] IIS 설치 확인 및 사용자 동의
Write-Host "[1/$totalSteps] IIS 설치 확인 중..." -ForegroundColor Yellow

$iisInstalled = Get-WindowsOptionalFeature -Online -FeatureName "IIS-WebServer" -ErrorAction SilentlyContinue
$iisStatus = if ($iisInstalled.State -eq "Enabled") { "설치됨" } else { "미설치" }

Write-Host "  - 현재 IIS 상태: $iisStatus" -ForegroundColor White
Write-OptLog -Step "1/11" -Status "Info" -Message "현재 IIS 상태: $iisStatus"

if ($iisInstalled.State -eq "Enabled") {
    Write-Host ""
    Write-Host "  경고: 기존 IIS 설정이 발견되었습니다." -ForegroundColor Red
    Write-Host "  이 스크립트는 기존 설정을 백업한 후 최적화를 적용합니다." -ForegroundColor Yellow
    Write-Host ""
}

if (-not $global:OrchestrateMode) {
    $confirm = Read-Host "IIS 설치 및 최적화를 진행하시겠습니까? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-Host "사용자가 취소하였습니다." -ForegroundColor Red
        Write-OptLog -Step "1/11" -Status "Info" -Message "사용자가 취소함"
        Save-OptLog
        exit
    }
    Write-Host "  - 사용자 동의 확인됨" -ForegroundColor Green
    Write-OptLog -Step "1/11" -Status "Info" -Message "사용자 동의 확인됨"
}


# [2/11] 기존 IIS 설정 백업
Write-Host ""
Write-Host "[2/$totalSteps] 기존 IIS 설정 백업 중..." -ForegroundColor Yellow

$backupDir = "$env:USERPROFILE\IIS_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

if ($iisInstalled.State -eq "Enabled") {
    try {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        Write-OptLog -Step "2/11" -Status "Applied" -Message "백업 디렉토리 생성: $backupDir"

        # applicationHost.config 백업
        $appHostConfig = "$env:SystemRoot\System32\inetsrv\config\applicationHost.config"
        if (Test-Path $appHostConfig) {
            Copy-Item -Path $appHostConfig -Destination "$backupDir\applicationHost.config" -Force
            Write-Host "  - applicationHost.config 백업됨" -ForegroundColor Green
            Write-OptLog -Step "2/11" -Status "Applied" -Message "applicationHost.config 백업됨"
        }

        # root web.config 백업
        $rootWebConfig = "$env:SystemDrive\inetpub\wwwroot\web.config"
        if (Test-Path $rootWebConfig) {
            Copy-Item -Path $rootWebConfig -Destination "$backupDir\web.config" -Force
            Write-Host "  - root web.config 백업됨" -ForegroundColor Green
            Write-OptLog -Step "2/11" -Status "Applied" -Message "root web.config 백업됨"
        }

        Write-Host "  - 백업 위치: $backupDir" -ForegroundColor Green
    } catch {
        Write-Host "  - 백업 중 오류 발생: $_" -ForegroundColor Red
        Write-OptLog -Step "2/11" -Status "Failed" -Message "백업 중 오류: $_"
    }
} else {
    Write-Host "  - 기존 IIS 설정 없음 (백업 건너뜀)" -ForegroundColor Yellow
    Write-OptLog -Step "2/11" -Status "Skipped" -Message "기존 IIS 설정 없음 (백업 건너뜀)"
}


# [3/11] IIS 기능 활성화
Write-Host ""
Write-Host "[3/$totalSteps] IIS 기능 활성화 중... (시간이 걸릴 수 있습니다)" -ForegroundColor Yellow

$iisFeatures = @(
    "IIS-WebServer",
    "IIS-WebServerRole",
    "IIS-CommonHttpFeatures",
    "IIS-HttpErrors",
    "IIS-DefaultDocument",
    "IIS-DirectoryBrowsing",
    "IIS-StaticContent",
    "IIS-HttpCompressionStatic",
    "IIS-HttpCompressionDynamic",
    "IIS-Performance",
    "IIS-Security",
    "IIS-RequestFiltering",
    "IIS-BasicAuthentication",
    "IIS-WindowsAuthentication",
    "IIS-HealthAndDiagnostics",
    "IIS-HttpLogging",
    "IIS-RequestMonitor",
    "IIS-ApplicationDevelopment",
    "IIS-NetFxExtensibility45",
    "IIS-ASPNET45",
    "IIS-ISAPIExtensions",
    "IIS-ISAPIFilter",
    "IIS-ManagementConsole",
    "IIS-ManagementScriptingTools",
    "IIS-WebSockets"
)

$enabledCount = 0
$skippedCount = 0

foreach ($feature in $iisFeatures) {
    $featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
    if ($featureState -and $featureState.State -ne "Enabled") {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
            $enabledCount++
            Write-OptLog -Step "3/11" -Status "Applied" -Message "IIS 기능 활성화: $feature"
        } catch {
            Write-OptLog -Step "3/11" -Status "Failed" -Message "IIS 기능 활성화 실패: $feature - $_"
        }
    } else {
        $skippedCount++
    }
}

if ($enabledCount -gt 0) {
    Write-Host "  - $enabledCount 개 IIS 기능 활성화됨" -ForegroundColor Green
} else {
    Write-Host "  - 모든 IIS 기능이 이미 활성화되어 있습니다" -ForegroundColor Green
}
Write-OptLog -Step "3/11" -Status "Info" -Message "IIS 기능: $enabledCount 개 활성화, $skippedCount 개 이미 활성화"


# [4/11] .NET Framework 확인
Write-Host ""
Write-Host "[4/$totalSteps] .NET Framework 확인 중..." -ForegroundColor Yellow

# .NET Framework 4.x 기능 활성화
$dotNetFeatures = @("NetFx4-AdvSrvs", "NetFx4Extended-ASPNET45")
foreach ($feature in $dotNetFeatures) {
    $featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
    if ($featureState -and $featureState.State -ne "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -ErrorAction SilentlyContinue | Out-Null
        Write-OptLog -Step "4/11" -Status "Applied" -Message ".NET 기능 활성화: $feature"
    } else {
        Write-OptLog -Step "4/11" -Status "Skipped" -Message ".NET 기능 이미 활성화: $feature"
    }
}

$dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Release
if ($dotNetVersion -ge 528040) {
    Write-Host "  - .NET Framework 4.8 이상 설치됨" -ForegroundColor Green
    Write-OptLog -Step "4/11" -Status "Info" -Message ".NET Framework 4.8 이상 설치됨 (Release: $dotNetVersion)"
} elseif ($dotNetVersion -ge 461808) {
    Write-Host "  - .NET Framework 4.7.2 이상 설치됨" -ForegroundColor Green
    Write-OptLog -Step "4/11" -Status "Info" -Message ".NET Framework 4.7.2 이상 설치됨 (Release: $dotNetVersion)"
} else {
    Write-Host "  - .NET Framework 업데이트가 권장됩니다" -ForegroundColor Yellow
    Write-OptLog -Step "4/11" -Status "Info" -Message ".NET Framework 업데이트 권장 (Release: $dotNetVersion)"
}


# [5/11] HTTP 압축 설정
Write-Host ""
Write-Host "[5/$totalSteps] HTTP 압축 설정 중..." -ForegroundColor Yellow

try {
    Import-Module WebAdministration -ErrorAction SilentlyContinue

    # 정적/동적 압축 활성화
    Set-WebConfigurationProperty -Filter "system.webServer/urlCompression" -PSPath "MACHINE/WEBROOT/APPHOST" -Name "doStaticCompression" -Value $true -ErrorAction SilentlyContinue
    Set-WebConfigurationProperty -Filter "system.webServer/urlCompression" -PSPath "MACHINE/WEBROOT/APPHOST" -Name "doDynamicCompression" -Value $true -ErrorAction SilentlyContinue
    Write-Host "  - 정적/동적 콘텐츠 압축 활성화" -ForegroundColor Green
    Write-Host "    참고: Brotli 압축은 IIS Compression 모듈 별도 설치 필요" -ForegroundColor Gray
    Write-OptLog -Step "5/11" -Status "Applied" -Message "정적/동적 콘텐츠 압축 활성화"
} catch {
    Write-Host "  - HTTP 압축 설정 중 오류 (WebAdministration 모듈 필요)" -ForegroundColor Yellow
    Write-OptLog -Step "5/11" -Status "Failed" -Message "HTTP 압축 설정 실패: $_"
}


# [6/11] 커널 모드 캐싱 활성화
Write-Host ""
Write-Host "[6/$totalSteps] 커널 모드 캐싱 활성화 중..." -ForegroundColor Yellow

$httpSysPath = "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"

Set-RegistryIfDifferent -Path $httpSysPath -Name "UriEnableCache" -Value 1 -Step "6/11" -Description "UriEnableCache: 1"
Set-RegistryIfDifferent -Path $httpSysPath -Name "UriMaxCacheMegabyteCount" -Value 512 -Step "6/11" -Description "UriMaxCacheMegabyteCount: 512MB"
Set-RegistryIfDifferent -Path $httpSysPath -Name "UriMaxUriBytes" -Value 262144 -Step "6/11" -Description "UriMaxUriBytes: 256KB"
Write-Host "  - 커널 모드 캐싱 활성화 (최대 512MB)" -ForegroundColor Green


# [7/11] Application Pool 최적화
Write-Host ""
Write-Host "[7/$totalSteps] Application Pool 최적화 중..." -ForegroundColor Yellow

try {
    Import-Module WebAdministration -ErrorAction SilentlyContinue

    $defaultPool = "DefaultAppPool"
    $poolPath = "IIS:\AppPools\$defaultPool"

    if (Test-Path $poolPath) {
        # 64비트 모드
        $current32bit = (Get-ItemProperty -Path $poolPath -Name "enable32BitAppOnWin64" -ErrorAction SilentlyContinue)
        Set-ItemProperty -Path $poolPath -Name "enable32BitAppOnWin64" -Value $false -ErrorAction SilentlyContinue
        Write-Host "  - 64비트 애플리케이션 모드 설정" -ForegroundColor Green
        Write-OptLog -Step "7/11" -Status "Applied" -Message "64비트 애플리케이션 모드 설정"

        # Idle Timeout: 20분
        Set-ItemProperty -Path $poolPath -Name "processModel.idleTimeout" -Value ([TimeSpan]::FromMinutes(20)) -ErrorAction SilentlyContinue
        Write-Host "  - Idle Timeout: 20분" -ForegroundColor Green
        Write-OptLog -Step "7/11" -Status "Applied" -Message "Idle Timeout: 20분"

        # Queue Length
        Set-ItemProperty -Path $poolPath -Name "queueLength" -Value 5000 -ErrorAction SilentlyContinue
        Write-Host "  - Queue Length: 5000" -ForegroundColor Green
        Write-OptLog -Step "7/11" -Status "Applied" -Message "Queue Length: 5000"

        # Start Mode: AlwaysRunning
        Set-ItemProperty -Path $poolPath -Name "startMode" -Value "AlwaysRunning" -ErrorAction SilentlyContinue
        Write-Host "  - Start Mode: AlwaysRunning" -ForegroundColor Green
        Write-OptLog -Step "7/11" -Status "Applied" -Message "Start Mode: AlwaysRunning"
    } else {
        Write-Host "  - DefaultAppPool을 찾을 수 없음" -ForegroundColor Yellow
        Write-OptLog -Step "7/11" -Status "Skipped" -Message "DefaultAppPool을 찾을 수 없음"
    }
} catch {
    Write-Host "  - Application Pool 설정 중 오류" -ForegroundColor Yellow
    Write-OptLog -Step "7/11" -Status "Failed" -Message "Application Pool 설정 실패: $_"
}


# [8/11] HTTP/2 활성화
Write-Host ""
Write-Host "[8/$totalSteps] HTTP/2 활성화 중..." -ForegroundColor Yellow

$http2Path = "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"

Set-RegistryIfDifferent -Path $http2Path -Name "EnableHttp2Tls" -Value 1 -Step "8/11" -Description "HTTP/2 TLS 활성화"
Set-RegistryIfDifferent -Path $http2Path -Name "EnableHttp2Cleartext" -Value 1 -Step "8/11" -Description "HTTP/2 Cleartext 활성화"
Set-RegistryIfDifferent -Path $http2Path -Name "Http2MaxConcurrentClientStreamsPerConnection" -Value 100 -Step "8/11" -Description "최대 동시 스트림: 100"
Write-Host "  - HTTP/2 활성화 (HTTPS, HTTP)" -ForegroundColor Green
Write-Host "  - 최대 동시 스트림: 100" -ForegroundColor Green


# [9/11] Output 캐싱 설정
Write-Host ""
Write-Host "[9/$totalSteps] Output 캐싱 프로필 설정 중..." -ForegroundColor Yellow

Write-Host "  - Output 캐싱 권장 설정:" -ForegroundColor White
Write-Host "    HTML: 5분, CSS/JS: 1시간, 이미지: 24시간" -ForegroundColor Gray
Write-Host "    IIS 관리자에서 사이트별로 설정하세요" -ForegroundColor Gray
Write-OptLog -Step "9/11" -Status "Info" -Message "Output 캐싱은 IIS 관리자에서 사이트별로 설정 필요"


# [10/11] HTTPS/TLS 보안 강화
Write-Host ""
Write-Host "[10/$totalSteps] HTTPS/TLS 보안 강화 중..." -ForegroundColor Yellow

$schannelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL"

# TLS 1.2 활성화
$tls12ServerPath = "$schannelPath\Protocols\TLS 1.2\Server"
$tls12ClientPath = "$schannelPath\Protocols\TLS 1.2\Client"

New-Item -Path $tls12ServerPath -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -Path $tls12ClientPath -Force -ErrorAction SilentlyContinue | Out-Null

Set-RegistryIfDifferent -Path $tls12ServerPath -Name "Enabled" -Value 1 -Step "10/11" -Description "TLS 1.2 Server Enabled"
Set-RegistryIfDifferent -Path $tls12ServerPath -Name "DisabledByDefault" -Value 0 -Step "10/11" -Description "TLS 1.2 Server DisabledByDefault"
Set-RegistryIfDifferent -Path $tls12ClientPath -Name "Enabled" -Value 1 -Step "10/11" -Description "TLS 1.2 Client Enabled"
Set-RegistryIfDifferent -Path $tls12ClientPath -Name "DisabledByDefault" -Value 0 -Step "10/11" -Description "TLS 1.2 Client DisabledByDefault"
Write-Host "  - TLS 1.2 활성화" -ForegroundColor Green

# TLS 1.3 활성화
$tls13ServerPath = "$schannelPath\Protocols\TLS 1.3\Server"
$tls13ClientPath = "$schannelPath\Protocols\TLS 1.3\Client"

New-Item -Path $tls13ServerPath -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -Path $tls13ClientPath -Force -ErrorAction SilentlyContinue | Out-Null

Set-RegistryIfDifferent -Path $tls13ServerPath -Name "Enabled" -Value 1 -Step "10/11" -Description "TLS 1.3 Server Enabled"
Set-RegistryIfDifferent -Path $tls13ServerPath -Name "DisabledByDefault" -Value 0 -Step "10/11" -Description "TLS 1.3 Server DisabledByDefault"
Set-RegistryIfDifferent -Path $tls13ClientPath -Name "Enabled" -Value 1 -Step "10/11" -Description "TLS 1.3 Client Enabled"
Set-RegistryIfDifferent -Path $tls13ClientPath -Name "DisabledByDefault" -Value 0 -Step "10/11" -Description "TLS 1.3 Client DisabledByDefault"
Write-Host "  - TLS 1.3 활성화" -ForegroundColor Green

# 약한 프로토콜 비활성화
$weakProtocols = @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1")

foreach ($protocol in $weakProtocols) {
    $serverPath = "$schannelPath\Protocols\$protocol\Server"
    $clientPath = "$schannelPath\Protocols\$protocol\Client"

    New-Item -Path $serverPath -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -Path $clientPath -Force -ErrorAction SilentlyContinue | Out-Null

    Set-RegistryIfDifferent -Path $serverPath -Name "Enabled" -Value 0 -Step "10/11" -Description "$protocol Server 비활성화"
    Set-RegistryIfDifferent -Path $serverPath -Name "DisabledByDefault" -Value 1 -Step "10/11" -Description "$protocol Server DisabledByDefault"
    Set-RegistryIfDifferent -Path $clientPath -Name "Enabled" -Value 0 -Step "10/11" -Description "$protocol Client 비활성화"
    Set-RegistryIfDifferent -Path $clientPath -Name "DisabledByDefault" -Value 1 -Step "10/11" -Description "$protocol Client DisabledByDefault"
}
Write-Host "  - 약한 프로토콜 비활성화 (SSL 2.0/3.0, TLS 1.0/1.1)" -ForegroundColor Green

# 약한 암호 비활성화
$ciphersPath = "$schannelPath\Ciphers"
$weakCiphers = @("DES 56/56", "RC2 40/128", "RC2 56/128", "RC2 128/128", "RC4 40/128", "RC4 56/128", "RC4 64/128", "RC4 128/128", "NULL")

foreach ($cipher in $weakCiphers) {
    $cipherPath = "$ciphersPath\$cipher"
    New-Item -Path $cipherPath -Force -ErrorAction SilentlyContinue | Out-Null
    Set-RegistryIfDifferent -Path $cipherPath -Name "Enabled" -Value 0 -Step "10/11" -Description "$cipher 암호 비활성화"
}
Write-Host "  - 약한 암호 비활성화 (DES, RC2, RC4, NULL)" -ForegroundColor Green


# [11/11] IIS 서비스 재시작
Write-Host ""
Write-Host "[11/$totalSteps] IIS 서비스 재시작 중..." -ForegroundColor Yellow

try {
    iisreset /restart 2>$null
    Write-Host "  - IIS 서비스 재시작 완료" -ForegroundColor Green
    Write-OptLog -Step "11/11" -Status "Applied" -Message "IIS 서비스 재시작 완료"
} catch {
    Write-Host "  - IIS 재시작 실패, 수동으로 재시작하세요: iisreset /restart" -ForegroundColor Yellow
    Write-OptLog -Step "11/11" -Status "Failed" -Message "IIS 재시작 실패: $_"
}

# 로그 저장
Save-OptLog

# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IIS 웹 서버 최적화가 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 요약 정보 출력
Write-Host "## 변경 요약" -ForegroundColor Cyan
Write-Host "  - 적용됨: $global:AppliedCount" -ForegroundColor Green
Write-Host "  - 건너뜀 (이미 설정됨): $global:SkippedCount" -ForegroundColor Yellow
Write-Host "  - 실패: $global:FailedCount" -ForegroundColor Red
Write-Host ""
Write-Host "로그 파일: $global:LogFilePath" -ForegroundColor White
Write-Host ""

Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - IIS 기능 활성화 (웹 서버, 압축, 보안, ASP.NET)" -ForegroundColor White
Write-Host "  - .NET Framework 구성" -ForegroundColor White
Write-Host "  - HTTP 압축 (정적/동적) 활성화" -ForegroundColor White
Write-Host "  - 커널 모드 캐싱 활성화 (512MB)" -ForegroundColor White
Write-Host "  - Application Pool 최적화 (64비트, AlwaysRunning)" -ForegroundColor White
Write-Host "  - HTTP/2 활성화" -ForegroundColor White
Write-Host "  - TLS 1.2/1.3 활성화" -ForegroundColor White
Write-Host "  - 약한 프로토콜/암호 비활성화" -ForegroundColor White
Write-Host ""

if ($iisInstalled.State -eq "Enabled") {
    Write-Host "백업 위치:" -ForegroundColor Yellow
    Write-Host "  $backupDir" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "다음 단계:" -ForegroundColor Yellow
Write-Host "  1. HTTPS 인증서 설치 (Let's Encrypt 또는 상용 인증서)" -ForegroundColor White
Write-Host "  2. 웹 사이트 바인딩 설정" -ForegroundColor White
Write-Host "  3. 방화벽 포트 개방 (80, 443)" -ForegroundColor White
Write-Host ""
Write-Host "IIS 관리자 실행: inetmgr" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인
Write-Host "일부 설정은 재부팅 후 완전히 적용됩니다." -ForegroundColor Yellow
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
