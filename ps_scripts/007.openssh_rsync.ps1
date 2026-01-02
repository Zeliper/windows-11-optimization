# OpenSSH 서버 설정 및 rsync 설치 스크립트
# Windows 11에서 SSH 서버 활성화 및 rsync 사용 가능하도록 설정
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

Write-Host "=== OpenSSH 서버 설정 및 rsync 설치 ===" -ForegroundColor Cyan
Write-Host ""

# 총 단계 수
$totalSteps = 7

# [1/7] OpenSSH 서버 기능 설치
Write-Host "[1/$totalSteps] OpenSSH 서버 기능 설치 중..." -ForegroundColor Yellow

$opensshServer = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($opensshServer.State -eq 'Installed') {
    Write-Host "  - OpenSSH 서버가 이미 설치되어 있습니다" -ForegroundColor Green
} else {
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop
        Write-Host "  - OpenSSH 서버 설치 완료" -ForegroundColor Green
    } catch {
        Write-Host "  - OpenSSH 서버 설치 실패: $_" -ForegroundColor Red
    }
}

# OpenSSH 클라이언트도 확인
$opensshClient = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
if ($opensshClient.State -ne 'Installed') {
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 -ErrorAction Stop
        Write-Host "  - OpenSSH 클라이언트 설치 완료" -ForegroundColor Green
    } catch {
        Write-Host "  - OpenSSH 클라이언트 설치 실패: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  - OpenSSH 클라이언트가 이미 설치되어 있습니다" -ForegroundColor Green
}

# [2/7] OpenSSH 서버 서비스 설정
Write-Host ""
Write-Host "[2/$totalSteps] OpenSSH 서버 서비스 설정 중..." -ForegroundColor Yellow

try {
    # sshd 서비스 시작 유형을 자동으로 설정
    Set-Service -Name sshd -StartupType Automatic -ErrorAction Stop
    Write-Host "  - sshd 서비스 시작 유형: 자동" -ForegroundColor Green

    # sshd 서비스 시작
    Start-Service sshd -ErrorAction Stop
    Write-Host "  - sshd 서비스 시작됨" -ForegroundColor Green
} catch {
    Write-Host "  - sshd 서비스 설정 실패: $_" -ForegroundColor Red
}

# ssh-agent 서비스도 활성화
try {
    Set-Service -Name ssh-agent -StartupType Automatic -ErrorAction Stop
    Start-Service ssh-agent -ErrorAction Stop
    Write-Host "  - ssh-agent 서비스 활성화됨" -ForegroundColor Green
} catch {
    Write-Host "  - ssh-agent 서비스 설정 실패: $_" -ForegroundColor Red
}

# [3/7] 방화벽 규칙 설정
Write-Host ""
Write-Host "[3/$totalSteps] 방화벽 규칙 설정 중..." -ForegroundColor Yellow

# 방화벽 서비스 상태 확인
$mpssvc = Get-Service -Name "mpssvc" -ErrorAction SilentlyContinue
Write-Host "  - 방화벽 서비스(mpssvc) 상태: $($mpssvc.Status)" -ForegroundColor White

if ($mpssvc.Status -ne "Running") {
    Write-Host "  - 경고: 방화벽 서비스가 실행되지 않음" -ForegroundColor Red
    Write-Host "  - 방화벽 규칙 설정을 건너뜁니다 (SSH 서비스는 계속 설치됨)" -ForegroundColor Yellow
    Write-Host "  - 003 스크립트 실행 후 재부팅하면 방화벽이 정상화됩니다" -ForegroundColor Yellow
} else {
    $firewallRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
    if ($firewallRule) {
        Write-Host "  - OpenSSH 방화벽 규칙이 이미 존재합니다" -ForegroundColor Green
    } else {
        try {
            New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" `
                -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction Stop
            Write-Host "  - OpenSSH 방화벽 규칙 생성 완료 (포트 22)" -ForegroundColor Green
        } catch {
            Write-Host "  - 방화벽 규칙 생성 실패: $_" -ForegroundColor Red
            Write-Host "  - SSH 서비스는 계속 설치됩니다" -ForegroundColor Yellow
        }
    }
}

# [4/7] 기본 셸을 PowerShell로 설정
Write-Host ""
Write-Host "[4/$totalSteps] SSH 기본 셸을 PowerShell로 설정 중..." -ForegroundColor Yellow

try {
    $pwshPath = (Get-Command powershell.exe -ErrorAction Stop).Source
    $openSSHPath = "HKLM:\SOFTWARE\OpenSSH"
    # 레지스트리 경로가 없으면 생성
    if (!(Test-Path $openSSHPath)) {
        New-Item -Path $openSSHPath -Force | Out-Null
    }
    New-ItemProperty -Path $openSSHPath -Name DefaultShell -Value $pwshPath -PropertyType String -Force | Out-Null
    Write-Host "  - 기본 셸: PowerShell ($pwshPath)" -ForegroundColor Green
} catch {
    Write-Host "  - 기본 셸 설정 실패: $_" -ForegroundColor Red
}

# [5/7] rsync를 위한 MSYS2/cwRsync 설치
Write-Host ""
Write-Host "[5/$totalSteps] rsync 설치 중 (cwRsync)..." -ForegroundColor Yellow

$rsyncDir = "$env:ProgramFiles\cwRsync"
$rsyncBin = "$rsyncDir\bin"
$rsyncExe = "$rsyncBin\rsync.exe"

if (Test-Path $rsyncExe) {
    Write-Host "  - rsync가 이미 설치되어 있습니다: $rsyncExe" -ForegroundColor Green
} else {
    try {
        # cwRsync 다운로드 URL (무료 버전)
        $cwrsyncUrl = "https://itefix.net/dl/free-software/cwrsync_6.3.1_x64_free.zip"
        $tempZip = "$env:TEMP\cwrsync.zip"

        Write-Host "  - cwRsync 다운로드 중..." -ForegroundColor White

        # TLS 1.2 사용
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # 다운로드
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($cwrsyncUrl, $tempZip)

        Write-Host "  - 압축 해제 중..." -ForegroundColor White

        # 압축 해제
        if (Test-Path $rsyncDir) {
            Remove-Item -Path $rsyncDir -Recurse -Force
        }
        Expand-Archive -Path $tempZip -DestinationPath "$env:ProgramFiles" -Force

        # cwrsync 폴더명 확인 및 이름 변경
        $extractedDir = Get-ChildItem -Path "$env:ProgramFiles" -Directory | Where-Object { $_.Name -like "cwrsync*" } | Select-Object -First 1
        if ($extractedDir -and $extractedDir.FullName -ne $rsyncDir) {
            Rename-Item -Path $extractedDir.FullName -NewName "cwRsync" -Force
        }

        # 임시 파일 삭제
        Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue

        if (Test-Path $rsyncExe) {
            Write-Host "  - rsync 설치 완료: $rsyncExe" -ForegroundColor Green
        } else {
            Write-Host "  - rsync 설치 확인 필요 - 경로를 확인하세요" -ForegroundColor Red
        }
    } catch {
        Write-Host "  - rsync 다운로드/설치 실패: $_" -ForegroundColor Red
        Write-Host "  - 수동 설치: https://itefix.net/cwrsync" -ForegroundColor White
    }
}

# [6/7] 환경 변수 PATH에 rsync 추가
Write-Host ""
Write-Host "[6/$totalSteps] 환경 변수 PATH 설정 중..." -ForegroundColor Yellow

$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($currentPath -notlike "*$rsyncBin*") {
    try {
        $newPath = $currentPath + ";$rsyncBin"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Host "  - PATH에 rsync 경로 추가됨: $rsyncBin" -ForegroundColor Green

        # 현재 세션에도 적용
        $env:Path = $env:Path + ";$rsyncBin"
    } catch {
        Write-Host "  - PATH 설정 실패: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  - rsync 경로가 이미 PATH에 있습니다" -ForegroundColor Green
}

# [7/7] SSH 서버 설정 최적화
Write-Host ""
Write-Host "[7/$totalSteps] SSH 서버 설정 최적화 중..." -ForegroundColor Yellow

$sshdConfigPath = "$env:ProgramData\ssh\sshd_config"

if (Test-Path $sshdConfigPath) {
    try {
        $sshdConfig = Get-Content $sshdConfigPath -Raw
        $modified = $false

        # 공개키 인증 활성화 (권장)
        if ($sshdConfig -notmatch "(?m)^PubkeyAuthentication\s+yes") {
            $sshdConfig = $sshdConfig -replace "(?m)^#?PubkeyAuthentication\s+\w+", "PubkeyAuthentication yes"
            $modified = $true
            Write-Host "  - 공개키 인증 활성화됨" -ForegroundColor Green
        }

        # 비밀번호 인증 유지 (공개키 설정 전에도 접속 가능)
        # 보안 강화가 필요하면 공개키 설정 후 수동으로 PasswordAuthentication no 설정

        # 브루트포스 방지: 최대 인증 시도 횟수 제한
        if ($sshdConfig -notmatch "(?m)^MaxAuthTries\s+") {
            $sshdConfig = $sshdConfig + "`nMaxAuthTries 3"
            $modified = $true
            Write-Host "  - 최대 인증 시도 횟수 제한 (3회)" -ForegroundColor Green
        }

        # 로그인 유예 시간 제한
        if ($sshdConfig -notmatch "(?m)^LoginGraceTime\s+") {
            $sshdConfig = $sshdConfig + "`nLoginGraceTime 60"
            $modified = $true
            Write-Host "  - 로그인 유예 시간 제한 (60초)" -ForegroundColor Green
        }

        # Subsystem sftp 설정 확인
        if ($sshdConfig -notmatch "(?m)^Subsystem\s+sftp") {
            $sshdConfig = $sshdConfig + "`nSubsystem sftp sftp-server.exe"
            $modified = $true
            Write-Host "  - SFTP 서브시스템 추가됨" -ForegroundColor Green
        }

        if ($modified) {
            Set-Content -Path $sshdConfigPath -Value $sshdConfig -Force

            # sshd 서비스 재시작
            Restart-Service sshd -Force
            Write-Host "  - sshd 서비스 재시작됨" -ForegroundColor Green
        } else {
            Write-Host "  - SSH 설정이 이미 최적화되어 있습니다" -ForegroundColor Green
        }
    } catch {
        Write-Host "  - SSH 설정 최적화 실패: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  - sshd_config 파일을 찾을 수 없습니다" -ForegroundColor Red
}

# 완료 및 상태 확인
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 서비스 상태 확인
Write-Host "[상태 확인]" -ForegroundColor Cyan
$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($sshdService) {
    Write-Host "  - sshd 서비스: $($sshdService.Status)" -ForegroundColor White
}

# rsync 버전 확인
if (Test-Path $rsyncExe) {
    try {
        $rsyncVersion = & $rsyncExe --version 2>&1 | Select-Object -First 1
        Write-Host "  - rsync: $rsyncVersion" -ForegroundColor White
    } catch {
        Write-Host "  - rsync 설치됨 (버전 확인 불가)" -ForegroundColor White
    }
}

Write-Host ""
Write-Host "[SSH 접속 방법]" -ForegroundColor Cyan
Write-Host "  비밀번호 인증이 활성화되어 있어 바로 접속 가능합니다." -ForegroundColor Green
Write-Host ""
Write-Host "[SSH 키 설정 방법 (선택 - 보안 강화)]" -ForegroundColor Cyan
Write-Host "  1. 클라이언트에서 키 생성:" -ForegroundColor White
Write-Host "     ssh-keygen -t ed25519" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. 공개키를 서버에 복사:" -ForegroundColor White
Write-Host "     - 일반 사용자: %USERPROFILE%\.ssh\authorized_keys" -ForegroundColor Gray
Write-Host "     - 관리자: %ProgramData%\ssh\administrators_authorized_keys" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. 관리자 키 파일 권한 설정 (관리자 PowerShell):" -ForegroundColor White
Write-Host "     icacls `"%ProgramData%\ssh\administrators_authorized_keys`" /inheritance:r /grant `"Administrators:F`" /grant `"SYSTEM:F`"" -ForegroundColor Gray
Write-Host ""
Write-Host "[사용 방법]" -ForegroundColor Cyan
Write-Host "  - SSH 접속: ssh 사용자명@$env:COMPUTERNAME" -ForegroundColor White
Write-Host "  - rsync 예시: rsync -avz /source/ user@$($env:COMPUTERNAME):/destination/" -ForegroundColor White
Write-Host ""
Write-Host "참고: 새 PowerShell 창에서 rsync 명령어를 사용하세요." -ForegroundColor Yellow
