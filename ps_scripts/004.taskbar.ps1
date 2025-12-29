# Windows 11 작업 표시줄 정리 스크립트
# 검색 상자, 작업 보기, 위젯 숨기기 및 고정된 앱 제거
# 관리자 권한으로 실행 필요

#Requires -RunAsAdministrator

# UTF-8 인코딩 설정 (irm | iex 실행 시 한글 출력용)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

Write-Host "=== Windows 11 작업 표시줄 정리 스크립트 ===" -ForegroundColor Cyan
Write-Host ""


# 1. 검색 상자 숨기기
Write-Host "[1/5] 검색 상자 숨기기..." -ForegroundColor Yellow

$searchPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"
if (!(Test-Path $searchPath)) {
    New-Item -Path $searchPath -Force | Out-Null
}
# 0 = 숨김, 1 = 아이콘만, 2 = 검색 상자
Set-ItemProperty -Path $searchPath -Name "SearchboxTaskbarMode" -Value 0 -Type DWord
Write-Host "  - 검색 상자 숨김 완료" -ForegroundColor Green


# 2. 작업 보기 버튼 숨기기
Write-Host ""
Write-Host "[2/5] 작업 보기 버튼 숨기기..." -ForegroundColor Yellow

$advancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (!(Test-Path $advancedPath)) {
    New-Item -Path $advancedPath -Force | Out-Null
}
Set-ItemProperty -Path $advancedPath -Name "ShowTaskViewButton" -Value 0 -Type DWord
Write-Host "  - 작업 보기 버튼 숨김 완료" -ForegroundColor Green


# 3. 위젯 버튼 숨기기
Write-Host ""
Write-Host "[3/5] 위젯 버튼 숨기기..." -ForegroundColor Yellow

# TaskbarDa = 0 (위젯 숨김)
Set-ItemProperty -Path $advancedPath -Name "TaskbarDa" -Value 0 -Type DWord
Write-Host "  - 위젯 버튼 숨김 완료" -ForegroundColor Green


# 4. 채팅(Teams) 버튼 숨기기
Write-Host ""
Write-Host "[4/5] 채팅(Teams) 버튼 숨기기..." -ForegroundColor Yellow

# TaskbarMn = 0 (채팅 숨김)
Set-ItemProperty -Path $advancedPath -Name "TaskbarMn" -Value 0 -Type DWord
Write-Host "  - 채팅 버튼 숨김 완료" -ForegroundColor Green


# 5. 작업 표시줄 고정된 앱 모두 제거
Write-Host ""
Write-Host "[5/5] 작업 표시줄 고정된 앱 제거 중..." -ForegroundColor Yellow

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
Write-Host "========================================" -ForegroundColor Cyan
