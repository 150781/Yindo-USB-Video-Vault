# TEST-VM-WINDOWS.PS1 - Guide test sur VM Windows propre
param(
    [string]$Version = "0.1.5",
    [string]$ReleaseUrl = "https://github.com/150781/Yindo-USB-Video-Vault/releases/tag/v0.1.5"
)

Write-Host "=== GUIDE TEST VM WINDOWS PROPRE ===" -ForegroundColor Green
Write-Host "Version testée: v$Version" -ForegroundColor Cyan
Write-Host "Release URL: $ReleaseUrl" -ForegroundColor Cyan

Write-Host "`n📋 CHECKLIST PRÉPARATION VM:" -ForegroundColor Blue
Write-Host "   ✅ VM Windows 10/11 fraîche (sans SDK/outils dev)" -ForegroundColor White
Write-Host "   ✅ SmartScreen activé (par défaut)" -ForegroundColor White
Write-Host "   ✅ Windows Defender activé" -ForegroundColor White
Write-Host "   ✅ Connexion Internet active" -ForegroundColor White
Write-Host "   ✅ Navigateur (Edge/Chrome/Firefox)" -ForegroundColor White

Write-Host "`n🔽 ÉTAPES DE TEST:" -ForegroundColor Blue

Write-Host "`n1. TÉLÉCHARGEMENT DEPUIS GITHUB" -ForegroundColor Yellow
Write-Host "   - Ouvrir: $ReleaseUrl" -ForegroundColor White
Write-Host "   - Télécharger: USB Video Vault Setup $Version.exe" -ForegroundColor White
Write-Host "   - Télécharger: USB Video Vault $Version.exe (portable)" -ForegroundColor White
Write-Host "   - Télécharger: SHA256SUMS" -ForegroundColor White
Write-Host "   ⚠️  IMPORTANT: Télécharger DEPUIS GITHUB pour avoir Mark-of-the-Web" -ForegroundColor Red

Write-Host "`n2. VÉRIFICATION CHECKSUMS (optionnel mais recommandé)" -ForegroundColor Yellow
Write-Host "   - Ouvrir PowerShell dans le dossier de téléchargement" -ForegroundColor White
Write-Host "   - Exécuter ces commandes:" -ForegroundColor White
Write-Host "     `$setupHash = (Get-FileHash 'USB Video Vault Setup $Version.exe' -Algorithm SHA256).Hash.ToLower()" -ForegroundColor Cyan
Write-Host "     `$portableHash = (Get-FileHash 'USB Video Vault $Version.exe' -Algorithm SHA256).Hash.ToLower()" -ForegroundColor Cyan
Write-Host "     Get-Content SHA256SUMS" -ForegroundColor Cyan
Write-Host "   - Comparer les hashes manuellement" -ForegroundColor White

Write-Host "`n3. TEST SMARTSCREEN - SETUP" -ForegroundColor Yellow
Write-Host "   - Double-cliquer sur: USB Video Vault Setup $Version.exe" -ForegroundColor White
Write-Host "   - AVEC SIGNATURE EV:" -ForegroundColor Green
Write-Host "     ✅ Devrait s'installer directement (pas d'avertissement)" -ForegroundColor Green
Write-Host "   - AVEC SIGNATURE OV:" -ForegroundColor Yellow
Write-Host "     ⚠️  Peut afficher 'Windows a protégé votre PC'" -ForegroundColor Yellow
Write-Host "     ➡️  Cliquer 'Informations complémentaires' → 'Exécuter quand même'" -ForegroundColor Yellow
Write-Host "   - SANS SIGNATURE:" -ForegroundColor Red
Write-Host "     ❌ Avertissement rouge 'Éditeur inconnu'" -ForegroundColor Red

Write-Host "`n4. TEST INSTALLATION" -ForegroundColor Yellow
Write-Host "   - L'installateur devrait démarrer normalement" -ForegroundColor White
Write-Host "   - Suivre l'installation standard" -ForegroundColor White
Write-Host "   - Vérifier que l'application se lance après installation" -ForegroundColor White

Write-Host "`n5. TEST PORTABLE" -ForegroundColor Yellow
Write-Host "   - Double-cliquer sur: USB Video Vault $Version.exe" -ForegroundColor White
Write-Host "   - Même comportement SmartScreen attendu" -ForegroundColor White
Write-Host "   - L'application devrait se lancer directement" -ForegroundColor White

Write-Host "`n6. VÉRIFICATION SIGNATURE (dans la VM)" -ForegroundColor Yellow
Write-Host "   - Clic-droit sur les EXE → Propriétés → Signatures numériques" -ForegroundColor White
Write-Host "   - Devrait afficher votre certificat" -ForegroundColor White
Write-Host "   - Ou en PowerShell:" -ForegroundColor White
Write-Host "     Get-AuthenticodeSignature 'USB Video Vault Setup $Version.exe'" -ForegroundColor Cyan

Write-Host "`n🎯 RÉSULTATS ATTENDUS:" -ForegroundColor Blue

Write-Host "`n   AVEC CERTIFICAT EV (Extended Validation):" -ForegroundColor Green
Write-Host "   ✅ Aucun avertissement SmartScreen" -ForegroundColor Green
Write-Host "   ✅ Installation silencieuse possible" -ForegroundColor Green
Write-Host "   ✅ Réputation immédiate" -ForegroundColor Green

Write-Host "`n   AVEC CERTIFICAT OV (Organization Validation):" -ForegroundColor Yellow
Write-Host "   ⚠️  Premier avertissement SmartScreen possible" -ForegroundColor Yellow
Write-Host "   ✅ Après quelques téléchargements, réputation s'améliore" -ForegroundColor Green
Write-Host "   ✅ Installation fonctionne après 'Exécuter quand même'" -ForegroundColor Green

Write-Host "`n   SANS CERTIFICAT:" -ForegroundColor Red
Write-Host "   ❌ Avertissement rouge permanent" -ForegroundColor Red
Write-Host "   ❌ Beaucoup d'utilisateurs n'oseront pas installer" -ForegroundColor Red
Write-Host "   ❌ Bloqué par certaines politiques d'entreprise" -ForegroundColor Red

Write-Host "`n🔧 DÉPANNAGE:" -ForegroundColor Blue

Write-Host "`n   Si SmartScreen bloque même avec signature:" -ForegroundColor Yellow
Write-Host "   1. Vérifier que le téléchargement vient bien de GitHub (Mark-of-the-Web)" -ForegroundColor White
Write-Host "   2. Essayer: Unblock-File '.\USB*.exe'" -ForegroundColor Cyan
Write-Host "   3. Vérifier que le certificat n'est pas expiré" -ForegroundColor White
Write-Host "   4. Tester sur plusieurs VM (Win10/Win11, différents comptes)" -ForegroundColor White

Write-Host "`n   Si l'installation échoue:" -ForegroundColor Yellow
Write-Host "   1. Vérifier les logs Windows (Event Viewer)" -ForegroundColor White
Write-Host "   2. Tester en mode administrateur" -ForegroundColor White
Write-Host "   3. Vérifier l'intégrité du fichier (checksum)" -ForegroundColor White

Write-Host "`n📊 MÉTRIQUES À SUIVRE:" -ForegroundColor Blue
Write-Host "   - % d'installations réussies sans avertissement" -ForegroundColor White
Write-Host "   - % d'utilisateurs qui cliquent 'Exécuter quand même'" -ForegroundColor White
Write-Host "   - Évolution de la réputation SmartScreen dans le temps" -ForegroundColor White
Write-Host "   - Feedback utilisateurs sur les avertissements" -ForegroundColor White

Write-Host "`n=== COMMANDES RAPIDES POUR LA VM ===" -ForegroundColor Green

Write-Host "`n# Téléchargement PowerShell (si besoin):" -ForegroundColor Cyan
Write-Host "Invoke-WebRequest -Uri '$ReleaseUrl/download/USB%20Video%20Vault%20Setup%20$Version.exe' -OutFile 'Setup.exe'" -ForegroundColor Yellow
Write-Host "Invoke-WebRequest -Uri '$ReleaseUrl/download/USB%20Video%20Vault%20$Version.exe' -OutFile 'Portable.exe'" -ForegroundColor Yellow
Write-Host "Invoke-WebRequest -Uri '$ReleaseUrl/download/SHA256SUMS' -OutFile 'SHA256SUMS'" -ForegroundColor Yellow

Write-Host "`n# Vérification signature:" -ForegroundColor Cyan
Write-Host "Get-AuthenticodeSignature Setup.exe | Select-Object Status, SignerCertificate" -ForegroundColor Yellow
Write-Host "Get-AuthenticodeSignature Portable.exe | Select-Object Status, SignerCertificate" -ForegroundColor Yellow

Write-Host "`n# Installation silencieuse (test IT):" -ForegroundColor Cyan
Write-Host ".\Setup.exe /S" -ForegroundColor Yellow

Write-Host "`n🏁 Après ces tests, vous saurez si votre signature fonctionne correctement !" -ForegroundColor Green