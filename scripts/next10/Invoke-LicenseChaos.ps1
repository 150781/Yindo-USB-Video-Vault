param(
  [Parameter()][ValidateSet('Expire','InvalidSignature','MissingUSB')][string]$Scenario = 'Expire'
)
$ErrorActionPreference='Stop'
$vault = Join-Path $env:USERPROFILE "Documents\Yindo-USB-Video-Vault\vault-real\.vault"
$lic = Join-Path $vault "license.bin"
if(-not (Test-Path $vault)){ throw "Vault introuvable: $vault" }

switch($Scenario){
  'Expire' {
    # crée un fallback JSON expiré (sans toucher au prod license.bin)
    $obj = [pscustomobject]@{
      data = @{ licenseId="chaos-expired"; version=1; exp="2000-01-01T00:00:00.000Z"; machineFingerprint="TEST"; features=@("playback") }
      signature = "INVALIDBASE64=="
    }
    $p = Join-Path $vault "license-test-expired.json"
    $obj | ConvertTo-Json -Depth 5 | Out-File $p -Encoding UTF8
    Write-Host "Injecté: $p (expiré)" -ForegroundColor Yellow
  }
  'InvalidSignature' {
    if(-not (Test-Path $lic)){ throw "license.bin absent" }
    $tmp = Get-Content $lic -Raw | ConvertFrom-Json
    $tmp.signature = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=="
    $p = Join-Path $vault "license-invalid.bin"
    $tmp | ConvertTo-Json -Depth 5 | Out-File $p -Encoding UTF8
    Write-Host "Créé: $p (signature invalide)" -ForegroundColor Yellow
  }
  'MissingUSB' {
    Write-Host "Simulez la clé USB manquante en retirant le périphérique. Aucun fichier modifié." -ForegroundColor Yellow
  }
}
exit 0