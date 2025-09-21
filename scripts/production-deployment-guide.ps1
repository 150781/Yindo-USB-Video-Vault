# Guide Déploiement Production J+0 → J+7
# USB Video Vault - Passage du mode simulation au déploiement réel

Write-Host "=== GUIDE DEPLOIEMENT PRODUCTION USB VIDEO VAULT ===" -ForegroundColor Cyan
Write-Host ""

# ===== J+0 : LANCEMENT PRODUCTION =====

Write-Host "=== J+0 : LANCEMENT PRODUCTION ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. Pre-vol reel :" -ForegroundColor Green
Write-Host "   .\scripts\deployment-plan-j0-j7.ps1 -Phase PreFlight -Version v1.0.4" -ForegroundColor White
Write-Host "   Verifie cles, build signe, SBOM, hashes" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Ring 0 reel :" -ForegroundColor Green
Write-Host "   .\scripts\deployment-plan-j0-j7.ps1 -Phase Ring0 -Version v1.0.4" -ForegroundColor White
Write-Host "   Genere 10 licences + installe + smoke tests" -ForegroundColor Gray
Write-Host ""

Write-Host "3. Monitoring 48h :" -ForegroundColor Green
Write-Host "   .\scripts\deployment-plan-j0-j7.ps1 -Phase Monitor -Version v1.0.4" -ForegroundColor White
Write-Host "   Surveillance continue Ring 0" -ForegroundColor Gray
Write-Host ""

# ===== J+2 : GO/NO-GO AUTOMATISE =====

Write-Host "=== J+2 : GO/NO-GO AUTOMATISE ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "4. Decision automatique :" -ForegroundColor Green
Write-Host "   .\scripts\deployment-plan-j0-j7.ps1 -Phase Ring1 -Version v1.0.4" -ForegroundColor White
Write-Host "   Phase Ring1 lancee seulement si Go/No-Go = GO" -ForegroundColor Gray
Write-Host ""

# ===== RING 1 : COLLECTE EMPREINTES CLIENTS =====

Write-Host "=== RING 1 : COLLECTE EMPREINTES CLIENTS ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "Envoyer aux 3 pilotes (CLIENT-ALPHA, CLIENT-BETA, CLIENT-GAMMA) :" -ForegroundColor Green
Write-Host ""

Write-Host ":: Collecteur minimal (Windows)" -ForegroundColor Cyan
Write-Host "node scripts\print-bindings.mjs > fingerprint.json" -ForegroundColor White
Write-Host "type fingerprint.json" -ForegroundColor White
Write-Host ""

Write-Host "Ils vous renvoient fingerprint.json. Ensuite, generer et livrer :" -ForegroundColor Green
Write-Host ""

Write-Host "# Generer licence (exemple)" -ForegroundColor Cyan
Write-Host 'node .\scripts\make-license.mjs "<MACHINE_FINGERPRINT>" "<USB_SERIAL_IF_ANY>"' -ForegroundColor White
Write-Host 'move .\license.bin .\deliveries\<CLIENT>-<HOST>-license.bin -Force' -ForegroundColor White
Write-Host ""

Write-Host "# Verifier avant envoi" -ForegroundColor Cyan
Write-Host 'node .\scripts\verify-license.mjs .\deliveries\<CLIENT>-<HOST>-license.bin' -ForegroundColor White
Write-Host ""

# ===== DEPLOIEMENT RING 1 =====

Write-Host "=== DEPLOIEMENT RING 1 (AU CHOIX) ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "Option A - MSI (GPO/Intune/SCCM recommande) :" -ForegroundColor Green
Write-Host ""
Write-Host "Commande d'installation silencieuse :" -ForegroundColor Cyan
Write-Host 'msiexec /i "\\share\USB-Video-Vault-Setup.msi" /qn /L*v "C:\Windows\Temp\usb-vault-install.log"' -ForegroundColor White
Write-Host ""
Write-Host "Post-install (copie licence + VAULT_PATH) :" -ForegroundColor Cyan
Write-Host '& "C:\Program Files\USB Video Vault\post-install-simple.ps1" -Verbose' -ForegroundColor White
Write-Host ""

Write-Host "Option B - EXE silencieux (NSIS/Inno) :" -ForegroundColor Green
Write-Host 'Start-Process "\\share\USB-Video-Vault-Setup.exe" -ArgumentList "/S" -Wait' -ForegroundColor White
Write-Host '& "C:\Program Files\USB Video Vault\post-install-simple.ps1" -Verbose' -ForegroundColor White
Write-Host ""

Write-Host "Option C - Remote push rapide (PowerShell Remoting) :" -ForegroundColor Green
Write-Host '$targets = @("PC-DEV-01","PC-QA-01", "PC-TEST-01")' -ForegroundColor White
Write-Host 'Invoke-Command -ComputerName $targets -ScriptBlock {' -ForegroundColor White
Write-Host '  Start-Process "\\share\USB-Video-Vault-Setup.msi" -ArgumentList "/qn" -Wait' -ForegroundColor White
Write-Host '  & "C:\Program Files\USB Video Vault\post-install-simple.ps1" -Verbose' -ForegroundColor White
Write-Host '}' -ForegroundColor White
Write-Host ""

# ===== CONTROLES DE PRODUCTION =====

Write-Host "=== CONTROLES DE PRODUCTION (A COCHER VITE) ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. Signatures :" -ForegroundColor Green
Write-Host '   Get-AuthenticodeSignature "C:\Program Files\USB Video Vault\USB Video Vault.exe"' -ForegroundColor White
Write-Host "   Status = Valid" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Hashes :" -ForegroundColor Green
Write-Host "   certutil -hashfile <fichier> SHA256" -ForegroundColor White
Write-Host "   = valeurs du fichier SHA256SUMS" -ForegroundColor Gray
Write-Host ""

Write-Host "3. Licence active :" -ForegroundColor Green
Write-Host 'node scripts\verify-license.mjs "C:\...\license.bin"' -ForegroundColor White
Write-Host "   exit code = 0" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Logs :" -ForegroundColor Green
Write-Host "   Pas de: Signature de licence invalide, Anti-rollback, Licence expiree" -ForegroundColor Gray
Write-Host ""

# ===== J+3 → J+7 : PILOTER RING 1 =====

Write-Host "=== J+3 -> J+7 : PILOTER RING 1 ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "Suivre metriques :" -ForegroundColor Green
Write-Host "- Memoire < 150 MB" -ForegroundColor Gray
Write-Host "- Demarrage < 3 s" -ForegroundColor Gray
Write-Host "- 0 erreurs critiques" -ForegroundColor Gray
Write-Host ""

Write-Host "Si OK, lancer release GA :" -ForegroundColor Green
Write-Host "   .\scripts\deployment-plan-j0-j7.ps1 -Phase GA -Version v1.0.4" -ForegroundColor White
Write-Host ""

# ===== DERNIERS DURCISSEMENTS =====

Write-Host "=== DERNIERS DURCISSEMENTS (RAPIDES) ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. Certificat prod + horodatage actives dans create-release-prod.ps1" -ForegroundColor Green
Write-Host "2. Desactiver fallback dev (NODE_ENV=production)" -ForegroundColor Green
Write-Host "3. NTP cote clients (anti-rollback fiable)" -ForegroundColor Green
Write-Host "4. Sauvegarde cle privee confirmee" -ForegroundColor Green
Write-Host "5. Table kid -> cle publique a jour + plan KID 2 date" -ForegroundColor Green
Write-Host ""

Write-Host "=== DEPLOIEMENT PRODUCTION PRET ! ===" -ForegroundColor Cyan