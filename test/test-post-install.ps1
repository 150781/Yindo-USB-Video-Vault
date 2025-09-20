# Test du script post-install avec logs simules

# Creer un log de test
$testLogDir = Join-Path $env:APPDATA "USB Video Vault\logs"
New-Item -ItemType Directory -Force -Path $testLogDir | Out-Null

$testLogPath = Join-Path $testLogDir "main.log"
$logContent = @"
[2025-09-19T22:30:00.000Z] [INFO] Application demarree
[2025-09-19T22:30:01.000Z] [INFO] Chargement vault...
[2025-09-19T22:30:02.000Z] [LICENSE] Chargement et validation...
[2025-09-19T22:30:02.100Z] [LICENSE] license.bin trouve et decompresse
[2025-09-19T22:30:02.200Z] [LICENSE] Verification signature (kid=1): OK
[2025-09-19T22:30:02.300Z] [LICENSE] Machine binding: ba33ce76... OK
[2025-09-19T22:30:02.400Z] [LICENSE] Licence validee avec succes
[2025-09-19T22:30:03.000Z] [INFO] Interface utilisateur initialisee
"@

Set-Content -Path $testLogPath -Value $logContent -Encoding UTF8

Write-Host "Log de test cree: $testLogPath" -ForegroundColor Green
Write-Host "Contenu:"
Get-Content $testLogPath

Write-Host "`nTest du script avec ce log..." -ForegroundColor Yellow