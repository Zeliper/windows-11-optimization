# Windows 11 OpenSSH & Rsync Setup Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "007.openssh_rsync.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "OpenSSH 서버/클라이언트 설치"
            # Ensure Windows Update service is running (Required for Capability installation)
            $wuService = Get-Service "wuauserv" -ErrorAction SilentlyContinue
            if ($wuService.Status -ne "Running") {
                Write-Host "  - Windows Update 서비스 시작 중 (기능 설치 필수)..." -ForegroundColor Yellow
                Start-Service "wuauserv" -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 2
            }

            # Helper function for installing capability
            function Install-Cap ($Name, $DisplayName) {
                 Write-Host "  - $DisplayName 설치 시도 중..." -ForegroundColor Yellow
                 try {
                     # Try direct installation (Fastest)
                     Add-WindowsCapability -Online -Name $Name -ErrorAction Stop
                     Write-OptLog -Step "OpenSSH" -Status "설치됨" -Message "$DisplayName 설치 완료"
                     return $true
                 } catch {
                     Write-Host "  - 직접 설치 실패, 이름 검색으로 재시도..." -ForegroundColor Yellow
                     # Fallback to search (Slower but safer)
                     $cap = Get-WindowsCapability -Online | Where-Object { $_.Name -like "$($Name.Split('~')[0])*"} | Select-Object -First 1
                     if ($cap -and $cap.State -ne 'Installed') {
                         Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop
                         Write-OptLog -Step "OpenSSH" -Status "설치됨" -Message "$DisplayName 설치 완료 (검색)"
                         return $true
                     }
                 }
                 return $false
            }

            # Fast check for SSH Server (Service based)
            if (Get-Service "sshd" -ErrorAction SilentlyContinue) {
                Write-Host "  - OpenSSH Server가 이미 설치 되어 있습니다. (Service Check)" -ForegroundColor Green
                Write-OptLog -Step "OpenSSH" -Status "스킵됨" -Message "OpenSSH.Server 이미 설치됨"
            } else {
                 Install-Cap -Name "OpenSSH.Server~~~~0.0.1.0" -DisplayName "OpenSSH Server" | Out-Null
            }

            # Fast check for SSH Client (Command based)
            if (Get-Command "ssh.exe" -ErrorAction SilentlyContinue) {
                Write-Host "  - OpenSSH Client가 이미 설치 되어 있습니다. (Command Check)" -ForegroundColor Green
                Write-OptLog -Step "OpenSSH" -Status "스킵됨" -Message "OpenSSH.Client 이미 설치됨"
            } else {
                 Install-Cap -Name "OpenSSH.Client~~~~0.0.1.0" -DisplayName "OpenSSH Client" | Out-Null
            }
    },
    @{
        Name = "SSH 서비스 설정 (sshd, ssh-agent)"
        Action = {
            # sshd
            Set-Service -Name "sshd" -StartupType "Automatic"
            if ((Get-Service "sshd").Status -ne "Running") { Start-Service "sshd" -ErrorAction SilentlyContinue }
            
            # ssh-agent
            Set-Service -Name "ssh-agent" -StartupType "Automatic"
            if ((Get-Service "ssh-agent").Status -ne "Running") { Start-Service "ssh-agent" -ErrorAction SilentlyContinue }
            
            Write-Host "  - 서비스 설정 및 시작 완료" -ForegroundColor Green
        }
    },
    @{
        Name = "SSH 방화벽 규칙 (TCP 22)"
        Action = {
            if (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue) {
                Write-Host "  - 방화벽 규칙 이미 존재함" -ForegroundColor Gray
            } else {
                New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" `
                    -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue
                Write-Host "  - 방화벽 규칙 생성됨" -ForegroundColor Green
                Write-OptLog -Step "Firewall" -Status "적용됨" -Message "Port 22 허용"
            }
        }
    },
    @{
        Name = "기본 셸을 PowerShell로 설정"
        Action = {
            $pwsh = (Get-Command powershell.exe).Source
            Set-Registry -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" -Value $pwsh -Type String -Description "기본 셸 설정"
        }
    },
    @{
        Name = "rsync 설치 (cwRsync)"
        Action = {
            $rsyncExe = "$env:ProgramFiles\cwRsync\bin\rsync.exe"
            if (Test-Path $rsyncExe) {
                Write-Host "  - rsync 이미 설치됨" -ForegroundColor Gray
                Write-OptLog -Step "rsync" -Status "스킵됨" -Message "이미 설치됨"
            } else {
                $zip = "$env:TEMP\cwrsync.zip"
                Write-Host "  - cwRsync 다운로드 중..." -ForegroundColor Yellow
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest "https://itefix.net/dl/free-software/cwrsync_6.3.1_x64_free.zip" -OutFile $zip -UseBasicParsing
                
                Write-Host "  - 압축 해제 중..." -ForegroundColor Yellow
                Expand-Archive -Path $zip -DestinationPath "$env:ProgramFiles" -Force
                
                # Rename folder logic
                $extracted = Get-ChildItem "$env:ProgramFiles" -Directory | Where-Object { $_.Name -like "cwrsync*" } | Select-Object -First 1
                if ($extracted) {
                    Rename-Item $extracted.FullName -NewName "cwRsync" -Force -ErrorAction SilentlyContinue
                }
                
                Remove-Item $zip -Force -ErrorAction SilentlyContinue
                Write-OptLog -Step "rsync" -Status "설치됨" -Message "설치 및 압축해제 완료"
            }
        }
    },
    @{
        Name = "PATH 환경변수 추가"
        Action = {
            $bin = "$env:ProgramFiles\cwRsync\bin"
            $current = [Environment]::GetEnvironmentVariable("Path", "Machine")
            if ($current -notlike "*$bin*") {
                [Environment]::SetEnvironmentVariable("Path", "$current;$bin", "Machine")
                $env:Path += ";$bin"
                Write-Host "  - PATH 추가됨: $bin" -ForegroundColor Green
                Write-OptLog -Step "Path" -Status "적용됨" -Message "rsync 경로 추가"
            } else {
                Write-Host "  - PATH 이미 존재함" -ForegroundColor Gray
            }
        }
    },
    @{
        Name = "sshd_config 최적화 (PubkeyAuth, SFTP)"
        Action = {
            $cfg = "$env:ProgramData\ssh\sshd_config"
            if (Test-Path $cfg) {
                $content = Get-Content $cfg -Raw
                $newContent = $content
                $modified = $false
                
                if ($content -notmatch "PubkeyAuthentication yes") {
                    $newContent = $newContent -replace "#?PubkeyAuthentication\s+\w+", "PubkeyAuthentication yes"
                    $modified = $true
                }
                if ($content -notmatch "Subsystem\s+sftp") {
                    $newContent += "`r`nSubsystem sftp sftp-server.exe"
                    $modified = $true
                }
                
                if ($modified) {
                    Set-Content -Path $cfg -Value $newContent -Force
                    Restart-Service sshd -Force
                    Write-Host "  - sshd_config 수정 및 서비스 재시작" -ForegroundColor Green
                    Write-OptLog -Step "Config" -Status "적용됨" -Message "설정 최적화 완료"
                } else {
                    Write-Host "  - 설정 이미 최적화됨" -ForegroundColor Gray
                }
            }
        }
    }
)

Run-OptimizationSteps -Title "OpenSSH 및 rsync 설정" -Steps $steps



