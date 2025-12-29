# Windows 11 Pro 설정 스크립트
# 관리자 권한으로 실행 필요
# 설정: 수동 업데이트, 자동 재시작 방지, UAC 해제

#Requires -RunAsAdministrator

Write-Host "=== Windows 11 Pro 설정 스크립트 ===" -ForegroundColor Cyan
Write-Host ""

# 1. Windows Update 정책 설정 (레지스트리)
Write-Host "[1/3] Windows Update 정책 설정 중..." -ForegroundColor Yellow

$WUPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

# 레지스트리 경로가 없으면 생성
if (!(Test-Path $WUPath)) {
    New-Item -Path $WUPath -Force | Out-Null
}

# 자동 업데이트 구성: 2 = 다운로드 및 설치 알림 (수동)
Set-ItemProperty -Path $WUPath -Name "AUOptions" -Value 2 -Type DWord

# 자동 업데이트 활성화 (정책 적용을 위해)
Set-ItemProperty -Path $WUPath -Name "NoAutoUpdate" -Value 0 -Type DWord

# 로그온 사용자 있을 때 자동 재시작 안 함
Set-ItemProperty -Path $WUPath -Name "NoAutoRebootWithLoggedOnUsers" -Value 1 -Type DWord

Write-Host "  - 업데이트: 다운로드 및 설치 알림 (수동)" -ForegroundColor Green
Write-Host "  - 자동 재시작 방지 활성화" -ForegroundColor Green


# 2. 추가 Windows Update 설정
Write-Host ""
Write-Host "[2/3] 추가 업데이트 설정 중..." -ForegroundColor Yellow

$WUSettingsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update"

if (!(Test-Path $WUSettingsPath)) {
    New-Item -Path $WUSettingsPath -Force | Out-Null
}

# 예약된 설치 비활성화
Set-ItemProperty -Path $WUSettingsPath -Name "AUOptions" -Value 2 -Type DWord

Write-Host "  - 예약 설치 비활성화 완료" -ForegroundColor Green


# 3. UAC (사용자 계정 컨트롤) 해제
Write-Host ""
Write-Host "[3/3] UAC (사용자 계정 컨트롤) 해제 중..." -ForegroundColor Yellow

$UACPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

# UAC 완전 해제
Set-ItemProperty -Path $UACPath -Name "EnableLUA" -Value 0 -Type DWord

# UAC 프롬프트 동작 설정 (0 = 알림 없이 권한 상승)
Set-ItemProperty -Path $UACPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord
Set-ItemProperty -Path $UACPath -Name "ConsentPromptBehaviorUser" -Value 0 -Type DWord

# 보안 데스크톱에서 프롬프트 표시 안 함
Set-ItemProperty -Path $UACPath -Name "PromptOnSecureDesktop" -Value 0 -Type DWord

Write-Host "  - UAC 해제 완료" -ForegroundColor Green


# 완료 메시지
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "모든 설정이 완료되었습니다!" -ForegroundColor Green
Write-Host "변경 사항을 적용하려면 재부팅이 필요합니다." -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 재부팅 확인
$restart = Read-Host "지금 재부팅하시겠습니까? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host "10초 후 재부팅됩니다..." -ForegroundColor Red
    Start-Sleep -Seconds 10
    Restart-Computer -Force
} else {
    Write-Host "나중에 수동으로 재부팅해주세요." -ForegroundColor Yellow
}
