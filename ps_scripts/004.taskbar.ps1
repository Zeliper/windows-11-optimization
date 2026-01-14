# Windows 11 Taskbar & Explorer Optimization Script
# Refactored to use core.ps1

#Requires -RunAsAdministrator

# Load Core Module
$corePath = Join-Path $PSScriptRoot "core.ps1"
if (Test-Path $corePath) {
    . $corePath
} else {
    Write-Warning "Core module not found at $corePath."
}

Init-OptimizationLog -ScriptName "004.taskbar.ps1" -ScriptVersion "1.2.0"

$steps = @(
    @{
        Name = "작업 표시줄 요소 숨기기 (검색, 작업보기, 채팅)"
        Action = {
            $advanced = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            
            # Search Box (0=Hidden)
            Set-Registry -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0 -Description "검색 상자 숨김"
            
            # Task View (0=Hidden)
            Set-Registry -Path $advanced -Name "ShowTaskViewButton" -Value 0 -Description "작업 보기 버튼 숨김"
            
            # Chat/Teams (0=Hidden)
            Set-Registry -Path $advanced -Name "TaskbarMn" -Value 0 -Description "채팅(Teams) 버튼 숨김"
        }
    },
    @{
        Name = "위젯 비활성화"
        Action = {
            # Policy (HKLM)
            Set-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -Value 0 -Description "위젯 정책 비활성화"
            
            # Remove Appx
            $pkg = Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" -ErrorAction SilentlyContinue
            if ($pkg) {
                 Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
                 Write-Host "  - Windows Web Experience Pack 제거됨" -ForegroundColor Green
            }
        }
    },
    @{
        Name = "작업 표시줄 고정 앱 제거"
        Action = {
            $pinnedPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
            if (Test-Path $pinnedPath) {
                Remove-Item -Path "$pinnedPath\*" -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  - 고정된 앱 바로가기 삭제 완료" -ForegroundColor Green
            }
            
            # Clear Cache
            $taskband = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
            Remove-ItemProperty -Path $taskband -Name "Favorites" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $taskband -Name "Pinned" -ErrorAction SilentlyContinue

            # Clear AutomaticDestinations & CustomDestinations (Jump Lists & Quick Access)
            $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
            $destinations = @("AutomaticDestinations", "CustomDestinations")
            
            foreach ($dest in $destinations) {
                $path = Join-Path $recentPath $dest
                if (Test-Path $path) {
                    Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    Write-Host "  - $dest 초기화 완료" -ForegroundColor Green
                }
            }
        }
    },
    @{
        Name = "Windows 10 스타일 컨텍스트 메뉴"
        Action = {
            $key = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
            if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
            
            # Default value must be empty string
            Set-ItemProperty -Path $key -Name "(Default)" -Value "" -Type String
            Write-Host "  - 레지스트리 키 생성 완료 (Explorer 재시작 후 적용)" -ForegroundColor Green
            Write-OptLog -Step "Context Menu" -Status "적용됨" -Message "Win10 스타일 메뉴 활성화"
        }
    },
    @{
        Name = "파일 탐색기 최적화"
        Action = {
            $advanced = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            
            # Launch to PC (1)
            Set-Registry -Path $advanced -Name "LaunchTo" -Value 1 -Description "내 PC로 시작"
            
            # Privacy 
            Set-Registry -Path $advanced -Name "ShowRecent" -Value 0 -Description "최근 파일 숨김"
            Set-Registry -Path $advanced -Name "ShowFrequent" -Value 0 -Description "자주 쓰는 폴더 숨김"
            Set-Registry -Path $advanced -Name "ShowCloudFilesInQuickAccess" -Value 0 -Description "클라우드 파일 숨김"
            
            # Extensions
            Set-Registry -Path $advanced -Name "HideFileExt" -Value 0 -Description "파일 확장자 표시"
            Set-Registry -Path $advanced -Name "Hidden" -Value 1 -Description "숨김 파일 표시"
            
            # Clear History
            Remove-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  - 탐색기 기록 삭제" -ForegroundColor Green

            # Fix Personalization -> Background Page Lag
            $wall = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers"
            if (Test-Path $wall) {
                Remove-ItemProperty -Path $wall -Name "BackgroundHistoryPath*" -ErrorAction SilentlyContinue
                Write-Host "  - 배경화면 히스토리 삭제 (설정 페이지 로딩 지연 수정)" -ForegroundColor Green
            }
        }
    }
)

Run-OptimizationSteps -Title "작업 표시줄 및 탐색기 최적화" -Steps $steps

# Restart Explorer if running standalone
if (-not $global:OrchestrateMode) {
    Write-Host "Explorer를 재시작합니다..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process explorer
}



