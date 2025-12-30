# Windows 11 작업 표시줄, 컨텍스트 메뉴 및 파일 탐색기 정리 스크립트
# 검색 상자, 작업 보기, 위젯 숨기기, 고정된 앱 제거, Windows 10 컨텍스트 메뉴 복원
# 파일 탐색기 설정 최적화
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "=== Windows 11 작업 표시줄, 컨텍스트 메뉴 및 파일 탐색기 정리 스크립트 ===" -ForegroundColor Cyan
Write-Host ""


# 1. 검색 상자 숨기기
Write-Host "[1/9] 검색 상자 숨기기..." -ForegroundColor Yellow

$searchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
if (!(Test-Path $searchPath)) {
    New-Item -Path $searchPath -Force | Out-Null
}
# 0 = 숨김, 1 = 아이콘만, 2 = 검색 상자
Set-ItemProperty -Path $searchPath -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
Write-Host "  - 검색 상자 숨김 완료" -ForegroundColor Green


# 2. 작업 보기 버튼 숨기기
Write-Host ""
Write-Host "[2/9] 작업 보기 버튼 숨기기..." -ForegroundColor Yellow

$advancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (!(Test-Path $advancedPath)) {
    New-Item -Path $advancedPath -Force | Out-Null
}
Set-ItemProperty -Path $advancedPath -Name "ShowTaskViewButton" -Value 0 -Type DWord
Write-Host "  - 작업 보기 버튼 숨김 완료" -ForegroundColor Green


# 3. 위젯 버튼 숨기기
Write-Host ""
Write-Host "[3/9] 위젯 버튼 숨기기..." -ForegroundColor Yellow

# TaskbarDa = 0 (위젯 숨김)
Set-ItemProperty -Path $advancedPath -Name "TaskbarDa" -Value 0 -Type DWord
Write-Host "  - 위젯 버튼 숨김 (사용자 설정)" -ForegroundColor Green

# 위젯 정책 비활성화 (Dsh = Dashboard)
$dshPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
if (!(Test-Path $dshPolicyPath)) {
    New-Item -Path $dshPolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $dshPolicyPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord
Write-Host "  - 위젯 정책 비활성화" -ForegroundColor Green

# Windows Web Experience Pack 제거 (위젯 완전 제거)
$webExperience = Get-AppxPackage -AllUsers -Name "MicrosoftWindows.Client.WebExperience" -ErrorAction SilentlyContinue
if ($webExperience) {
    # 현재 사용자에서 제거
    Get-AppxPackage -Name "MicrosoftWindows.Client.WebExperience" | Remove-AppxPackage -ErrorAction SilentlyContinue
    # 모든 사용자에서 제거
    Get-AppxPackage -AllUsers -Name "MicrosoftWindows.Client.WebExperience" | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    # 프로비저닝된 패키지 제거 (새 사용자에게 설치 방지)
    Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*WebExperience*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    Write-Host "  - Windows Web Experience Pack 제거 완료" -ForegroundColor Green
} else {
    Write-Host "  - Windows Web Experience Pack 이미 제거됨" -ForegroundColor Yellow
}

# 위젯 프로세스 종료
Stop-Process -Name "Widgets" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "WidgetService" -Force -ErrorAction SilentlyContinue
Write-Host "  - 위젯 프로세스 종료" -ForegroundColor Green


# 4. 채팅(Teams) 버튼 숨기기
Write-Host ""
Write-Host "[4/9] 채팅(Teams) 버튼 숨기기..." -ForegroundColor Yellow

# TaskbarMn = 0 (채팅 숨김)
Set-ItemProperty -Path $advancedPath -Name "TaskbarMn" -Value 0 -Type DWord
Write-Host "  - 채팅 버튼 숨김 완료" -ForegroundColor Green


# 5. 작업 표시줄 고정된 앱 모두 제거
Write-Host ""
Write-Host "[5/9] 작업 표시줄 고정된 앱 제거 중..." -ForegroundColor Yellow

# 고정된 앱 바로가기 폴더
$pinnedPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"

if (Test-Path $pinnedPath) {
    $pinnedItems = Get-ChildItem -Path $pinnedPath -ErrorAction SilentlyContinue
    $count = ($pinnedItems | Measure-Object).Count

    if ($count -gt 0) {
        Remove-Item -Path "$pinnedPath\*" -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "  - 고정된 앱 $count 개 제거 완료" -ForegroundColor Green
    } else {
        Write-Host "  - 고정된 앱이 없습니다" -ForegroundColor Yellow
    }
} else {
    Write-Host "  - 고정된 앱 폴더를 찾을 수 없습니다" -ForegroundColor Yellow
}

# 작업 표시줄 레지스트리 캐시 초기화
$taskbandPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
if (Test-Path $taskbandPath) {
    Remove-ItemProperty -Path $taskbandPath -Name "Favorites" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $taskbandPath -Name "FavoritesResolve" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $taskbandPath -Name "FavoritesVersion" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $taskbandPath -Name "FavoritesChanges" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $taskbandPath -Name "Pinned" -ErrorAction SilentlyContinue
    Write-Host "  - 작업 표시줄 캐시 초기화 완료" -ForegroundColor Green
}


# 6. Windows 10 스타일 컨텍스트 메뉴 복원
Write-Host ""
Write-Host "[6/9] Windows 10 스타일 컨텍스트 메뉴 복원 중..." -ForegroundColor Yellow

$contextMenuPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
if (!(Test-Path $contextMenuPath)) {
    New-Item -Path $contextMenuPath -Force | Out-Null
}
# 기본값을 빈 문자열로 설정하면 Windows 10 스타일 컨텍스트 메뉴 활성화
Set-ItemProperty -Path $contextMenuPath -Name "(Default)" -Value "" -Type String
Write-Host "  - Windows 10 스타일 컨텍스트 메뉴 복원 완료" -ForegroundColor Green


# 7. 파일 탐색기 시작 위치를 "내 PC"로 변경
Write-Host ""
Write-Host "[7/9] 파일 탐색기 시작 위치를 '내 PC'로 변경..." -ForegroundColor Yellow

# LaunchTo: 1 = 내 PC, 2 = 빠른 액세스, 3 = 다운로드
Set-ItemProperty -Path $advancedPath -Name "LaunchTo" -Value 1 -Type DWord
Write-Host "  - 파일 탐색기 시작 위치 '내 PC' 설정 완료" -ForegroundColor Green


# 8. 파일 탐색기 개인정보 보호 설정 해제 및 기록 지우기
Write-Host ""
Write-Host "[8/9] 파일 탐색기 개인정보 보호 설정 해제..." -ForegroundColor Yellow

# 최근에 사용한 파일을 빠른 액세스에 표시 안 함
Set-ItemProperty -Path $advancedPath -Name "ShowRecent" -Value 0 -Type DWord
Write-Host "  - 최근 사용한 파일 표시 해제" -ForegroundColor Green

# 자주 사용하는 폴더를 빠른 액세스에 표시 안 함
Set-ItemProperty -Path $advancedPath -Name "ShowFrequent" -Value 0 -Type DWord
Write-Host "  - 자주 사용하는 폴더 표시 해제" -ForegroundColor Green

# Office.com의 파일 표시 안 함 (Windows 11)
Set-ItemProperty -Path $advancedPath -Name "ShowCloudFilesInQuickAccess" -Value 0 -Type DWord -ErrorAction SilentlyContinue
Write-Host "  - Office.com 파일 표시 해제" -ForegroundColor Green

# 파일 탐색기 기록 지우기
$explorerBagMRU = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU"
if (Test-Path $explorerBagMRU) {
    Remove-Item -Path $explorerBagMRU -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  - 파일 열기/저장 기록 삭제" -ForegroundColor Green
}

$recentDocs = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs"
if (Test-Path $recentDocs) {
    Remove-Item -Path $recentDocs -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $recentDocs -Force | Out-Null
    Write-Host "  - 최근 문서 기록 삭제" -ForegroundColor Green
}

# 최근 항목 폴더 비우기
$recentFolder = "$env:APPDATA\Microsoft\Windows\Recent"
if (Test-Path $recentFolder) {
    Remove-Item -Path "$recentFolder\*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Host "  - 최근 항목 폴더 비우기 완료" -ForegroundColor Green
}

# 자동 재생 폴더 비우기
$automaticDestinations = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
$customDestinations = "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations"
if (Test-Path $automaticDestinations) {
    Remove-Item -Path "$automaticDestinations\*" -Force -ErrorAction SilentlyContinue
}
if (Test-Path $customDestinations) {
    Remove-Item -Path "$customDestinations\*" -Force -ErrorAction SilentlyContinue
}
Write-Host "  - 점프 목록 기록 삭제 완료" -ForegroundColor Green


# 9. 파일 확장자명 표시
Write-Host ""
Write-Host "[9/9] 파일 확장자명 표시 설정..." -ForegroundColor Yellow

# HideFileExt: 0 = 확장자 표시, 1 = 확장자 숨김
Set-ItemProperty -Path $advancedPath -Name "HideFileExt" -Value 0 -Type DWord
Write-Host "  - 파일 확장자명 표시 설정 완료" -ForegroundColor Green

# 숨김 파일 표시 (보너스)
Set-ItemProperty -Path $advancedPath -Name "Hidden" -Value 1 -Type DWord
Write-Host "  - 숨김 파일 표시 설정 완료" -ForegroundColor Green


# Explorer 재시작하여 변경사항 적용
Write-Host ""
Write-Host "변경사항을 적용하기 위해 Explorer를 재시작합니다..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host ""
Write-Host "적용된 설정:" -ForegroundColor Yellow
Write-Host "  - 검색 상자 숨김" -ForegroundColor White
Write-Host "  - 작업 보기 버튼 숨김" -ForegroundColor White
Write-Host "  - 위젯 버튼 숨김" -ForegroundColor White
Write-Host "  - 채팅(Teams) 버튼 숨김" -ForegroundColor White
Write-Host "  - 고정된 앱 모두 제거" -ForegroundColor White
Write-Host "  - Windows 10 스타일 컨텍스트 메뉴 복원" -ForegroundColor White
Write-Host "  - 파일 탐색기 시작 위치 '내 PC' 설정" -ForegroundColor White
Write-Host "  - 파일 탐색기 개인정보 보호 설정 해제 및 기록 삭제" -ForegroundColor White
Write-Host "  - 파일 확장자명 및 숨김 파일 표시" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
