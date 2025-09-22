# Script de renouvellement automatique gÃ©nÃ©rÃ© le 2025-09-22 14:54:17
# A exÃ©cuter depuis le rÃ©pertoire racine du projet

Import-Csv "routine-output\renewal\ring1-renewals-20250922.csv" | ForEach-Object {
    Write-Host "Renouvellement: $($_.Machine)" -ForegroundColor Yellow
    
    # GÃ©nÃ©ration nouvelle licence
    node .\scripts\make-license.mjs $_.Fingerprint $_.UsbSerial
    
    # DÃ©placement vers rÃ©pertoire de livraison
    $newLicensePath = ".\deliveries\renewals\$($_.Machine)-license-renewed.bin"
    Move-Item .\license.bin $newLicensePath -Force
    
    # VÃ©rification
    node .\scripts\verify-license.mjs $newLicensePath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "âœ… Licence renouvelÃ©e: $newLicensePath" -ForegroundColor Green
    } else {
        Write-Host "âŒ Erreur renouvellement: $($_.Machine)" -ForegroundColor Red
    }
}

Write-Host "
Renouvellement terminÃ©. VÃ©rifiez le rÃ©pertoire .\deliveries\renewals\" -ForegroundColor Cyan
