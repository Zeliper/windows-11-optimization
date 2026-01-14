# Windows 11 IIS Web Server Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "011.web_server.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "IIS 기능 활성화"
        Action = {
            $feats = @(
                "IIS-WebServer", "IIS-WebServerRole", "IIS-CommonHttpFeatures", "IIS-HttpErrors", 
                "IIS-StaticContent", "IIS-HttpCompressionStatic", "IIS-HttpCompressionDynamic", 
                "IIS-Performance", "IIS-Security", "IIS-RequestFiltering", "IIS-WindowsAuthentication", 
                "IIS-ApplicationDevelopment", "IIS-NetFxExtensibility45", "IIS-ASPNET45", 
                "IIS-ManagementConsole", "IIS-WebSockets"
            )
            foreach ($f in $feats) {
                 Enable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart -ErrorAction SilentlyContinue | Out-Null
            }
            Write-Host "  - IIS 기능 활성화 완료" -ForegroundColor Green
        }
    },
    @{
        Name = ".NET Framework 설정"
        Action = {
             Enable-WindowsOptionalFeature -Online -FeatureName "NetFx4-AdvSrvs" -NoRestart -ErrorAction SilentlyContinue | Out-Null
             Enable-WindowsOptionalFeature -Online -FeatureName "NetFx4Extended-ASPNET45" -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }
    },
    @{
        Name = "HTTP 압축 및 캐시 설정"
        Action = {
             try {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                Set-WebConfigurationProperty -Filter "system.webServer/urlCompression" -PSPath "MACHINE/WEBROOT/APPHOST" -Name "doStaticCompression" -Value $true -ErrorAction SilentlyContinue
                Set-WebConfigurationProperty -Filter "system.webServer/urlCompression" -PSPath "MACHINE/WEBROOT/APPHOST" -Name "doDynamicCompression" -Value $true -ErrorAction SilentlyContinue
             } catch {}
             
             # Kernel Cache
             $http = "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"
             Set-Registry -Path $http -Name "UriEnableCache" -Value 1
             Set-Registry -Path $http -Name "UriMaxCacheMegabyteCount" -Value 512
             Set-Registry -Path $http -Name "UriMaxUriBytes" -Value 262144
        }
    },
    @{
        Name = "Application Pool 최적화 (DefaultAppPool)"
        Action = {
             try {
                 Import-Module WebAdministration -ErrorAction SilentlyContinue
                 $poolPath = "IIS:\AppPools\DefaultAppPool"
                 if (Test-Path $poolPath) {
                     Set-ItemProperty -Path $poolPath -Name "enable32BitAppOnWin64" -Value $false -ErrorAction SilentlyContinue
                     Set-ItemProperty -Path $poolPath -Name "processModel.idleTimeout" -Value ([TimeSpan]::FromMinutes(20)) -ErrorAction SilentlyContinue
                     Set-ItemProperty -Path $poolPath -Name "queueLength" -Value 5000 -ErrorAction SilentlyContinue
                     Set-ItemProperty -Path $poolPath -Name "startMode" -Value "AlwaysRunning" -ErrorAction SilentlyContinue
                     Write-Host "  - DefaultAppPool 최적화됨" -ForegroundColor Green
                 }
             } catch {}
        }
    },
    @{
        Name = "HTTP/2 및 TLS 보안 강화"
        Action = {
            # HTTP/2
            $http = "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters"
            Set-Registry -Path $http -Name "EnableHttp2Tls" -Value 1
            Set-Registry -Path $http -Name "EnableHttp2Cleartext" -Value 1
            
            # TLS 1.2/1.3 Enable
            $schannel = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL"
            foreach ($ver in @("TLS 1.2", "TLS 1.3")) {
                foreach ($side in @("Server", "Client")) {
                    $p = "$schannel\Protocols\$ver\$side"
                    Set-Registry -Path $p -Name "Enabled" -Value 1
                    Set-Registry -Path $p -Name "DisabledByDefault" -Value 0
                }
            }
            
            # Weak Protocols Disable (SSL 2.0/3.0, TLS 1.0/1.1)
            foreach ($ver in @("SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1")) {
                foreach ($side in @("Server", "Client")) {
                    $p = "$schannel\Protocols\$ver\$side"
                    Set-Registry -Path $p -Name "Enabled" -Value 0
                    Set-Registry -Path $p -Name "DisabledByDefault" -Value 1
                }
            }
        }
    },
    @{
        Name = "IIS 재시작"
        Action = {
            iisreset /restart
            Write-Host "  - IIS 서비스 재시작됨" -ForegroundColor Green
        }
    }
)

# User consent check if not orchestrated (since installing IIS is heavy)
if (-not $global:OrchestrateMode) {
    if (!(Get-WindowsOptionalFeature -Online -FeatureName "IIS-WebServer").State -eq 'Enabled') {
         $c = Read-Host "IIS가 설치되지 않았습니다. 설치 및 최적화를 진행하시겠습니까? (Y/N)"
         if ($c -notmatch "y") { exit }
    }
}

Run-OptimizationSteps -Title "IIS 웹 서버 최적화" -Steps $steps
