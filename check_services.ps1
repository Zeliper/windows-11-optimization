# Check services that may cause Settings app delay
$patterns = @('CDP', 'Wpn', 'Device', 'Cloud', 'Account', 'Token', 'AIX', 'AIFabric', 'DiagTrack')

Write-Host "=== Settings App Related Services ===" -ForegroundColor Cyan
foreach ($p in $patterns) {
    $svcs = Get-Service | Where-Object { $_.Name -like "*$p*" }
    foreach ($s in $svcs) {
        Write-Host "$($s.Name) - Status: $($s.Status), StartType: $($s.StartType)" -ForegroundColor Yellow
    }
}

Write-Host "`n=== AI/Copilot Related Services ===" -ForegroundColor Cyan
Get-Service | Where-Object { $_.Name -match 'AI|Copilot' } | ForEach-Object {
    Write-Host "$($_.Name) - Status: $($_.Status), StartType: $($_.StartType)" -ForegroundColor Yellow
}
