# Windows 11 Privacy Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "013.privacy_optimization.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "위치 서비스 비활성화"
        Action = {
            Set-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type "String"
            Set-Registry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Deny" -Type "String"
            
            $pol = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
            Set-Registry -Path $pol -Name "DisableLocation" -Value 1
            Set-Registry -Path $pol -Name "DisableLocationScripting" -Value 1
            Set-Registry -Path $pol -Name "DisableWindowsLocationProvider" -Value 1
            
            Set-Service -Name "lfsvc" -StartupType "Disabled"
            if ((Get-Service "lfsvc" -ErrorAction SilentlyContinue).Status -eq "Running") { Stop-Service "lfsvc" -Force -ErrorAction SilentlyContinue }
        }
    },
    @{
        Name = "진단 데이터 및 피드백 끄기"
        Action = {
            $data = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
            Set-Registry -Path $data -Name "AllowTelemetry" -Value 0
            Set-Registry -Path $data -Name "MaxTelemetryAllowed" -Value 0
            
            $siuf = "HKCU:\Software\Microsoft\Siuf\Rules"
            Set-Registry -Path $siuf -Name "NumberOfSIUFInPeriod" -Value 0
            
            foreach ($s in @("DiagTrack", "dmwappushservice")) {
                Set-Service -Name $s -StartupType "Disabled"
                if ((Get-Service $s -ErrorAction SilentlyContinue).Status -eq "Running") { Stop-Service $s -Force -ErrorAction SilentlyContinue }
            }
            
            $wer = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"
            Set-Registry -Path $wer -Name "Disabled" -Value 1
            
            # Ink/Typing
            $ink = "HKCU:\Software\Microsoft\InputPersonalization"
            Set-Registry -Path $ink -Name "RestrictImplicitInkCollection" -Value 1
            Set-Registry -Path $ink -Name "RestrictImplicitTextCollection" -Value 1
        }
    },
    @{
        Name = "앱 권한 제한 (카메라/마이크 등)"
        Action = {
            $caps = @("webcam","microphone","contacts","appointments","email","userAccountInformation","broadFileSystemAccess")
            foreach ($c in $caps) {
                $p = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$c"
                if (!(Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
                Set-ItemProperty -Path $p -Name "Value" -Value "Deny" -Type String -ErrorAction SilentlyContinue
                
                $pUser = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\$c"
                if (!(Test-Path $pUser)) { New-Item -Path $pUser -Force | Out-Null }
                Set-ItemProperty -Path $pUser -Name "Value" -Value "Deny" -Type String -ErrorAction SilentlyContinue
            }
            Write-Host "  - 주요 앱 권한(카메라, 마이크 등) 차단됨" -ForegroundColor Green
        }
    },
    @{
        Name = "백그라운드 앱 및 동기화 비활성화"
        Action = {
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" -Name "GlobalUserDisabled" -Value 1
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" -Name "LetAppsRunInBackground" -Value 2
            
            # Sync
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\SettingSync" -Name "SyncPolicy" -Value 5
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSyncNGSC" -Value 1
            
            # Activity History
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Value 0
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Value 0
        }
    },
    @{
        Name = "파일 탐색기 개인정보 보호"
        Action = {
            $exp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Set-Registry -Path $exp -Name "Start_TrackDocs" -Value 0
            Set-Registry -Path $exp -Name "Start_TrackProgs" -Value 0
            Set-Registry -Path $exp -Name "ShowRecent" -Value 0 -Description "최근 항목 숨기기" (Get-ItemProperty $exp).ShowRecent
            
            # Clear Recent
            $recent = "$env:APPDATA\Microsoft\Windows\Recent"
            if (Test-Path $recent) { Get-ChildItem $recent -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
        }
    },
    @{
        Name = "광고 추적 방지 (Advertising ID)"
        Action = {
            Set-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Value 1
            
            # Start Menu Suggestions
            $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Set-Registry -Path $cdm -Name "SystemPaneSuggestionsEnabled" -Value 0
            Set-Registry -Path $cdm -Name "SubscribedContent-338388Enabled" -Value 0
            Set-Registry -Path $cdm -Name "SilentInstalledAppsEnabled" -Value 0
            
            # Edge Tracking
            $edge = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
            Set-Registry -Path $edge -Name "TrackingPrevention" -Value 3
            Set-Registry -Path $edge -Name "ConfigureDoNotTrack" -Value 1
        }
    }
)

Run-OptimizationSteps -Title "개인정보 보호 최적화" -Steps $steps
