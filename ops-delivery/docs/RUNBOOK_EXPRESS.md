# 🚀 Runbook Opérateur Express - USB Video Vault

## ⚡ Génération Licence Client (1 commande)

### 🚀 Script One-Liner (RECOMMANDÉ)
```powershell
# Secret une fois par session
$env:PACKAGER_PRIVATE_HEX = "[SECRET_VAULT]"

# Génération complète automatique
.\scripts\generate-client-license.ps1 -ClientFingerprint "FINGERPRINT" -ClientName "ClientXYZ"

# Avec USB si requis
.\scripts\generate-client-license.ps1 -ClientFingerprint "FINGERPRINT" -UsbSerial "USB123" -ClientName "ClientXYZ" -ExpirationDate "2026-12-31T23:59:59Z"
```
**Résultat :** Package complet `delivery-ClientXYZ/` prêt à envoyer

### 📋 Méthode Manuelle (3 étapes)
```powershell
# 1. Empreinte machine
node scripts/print-bindings.mjs

# 2. Génération licence
node scripts/make-license.mjs "FINGERPRINT" --kid 1 --exp "2026-09-19T23:59:59Z"

# 3. Vérification
node scripts/verify-license.mjs "vault-real"
```

---

## 📦 Livraison Client (automatique)

### Package automatique avec script one-liner
```powershell
# Déjà inclus dans generate-client-license.ps1
# Résultat: dossier delivery-ClientXYZ/ avec:
# - license.bin (licence)
# - install.ps1 (installation auto)
# - README.md (guide client)
# - PACKAGE-INFO.txt (infos package)
```

### Instructions client (copier-coller)
```
1. Extraire le package delivery-ClientXYZ.zip
2. PowerShell en admin: .\install.ps1  
3. Vérifier: "INSTALLATION REUSSIE"
4. Si problème: capture écran au support
```

---

## 🔧 Diagnostic Client Express

### Problème signature/binding
```powershell
# 1. Nouvelle empreinte
node scripts/print-bindings.mjs

# 2. Régénérer si différente
node scripts/make-license.mjs "NOUVELLE_EMPREINTE" --kid 1 --exp "2026-09-19T23:59:59Z"

# 3. Renvoyer license.bin
```

### Problème expiration
```powershell
# Renouveler 1 an
node scripts/make-license.mjs "FINGERPRINT" --kid 1 --exp "2026-09-19T23:59:59Z"
```

---

## 🚨 Urgence - Rotation Clé

### Si clé compromise (kid=1)
```powershell
# 1. Utiliser kid=2 d'urgence
node scripts/make-license.mjs "FINGERPRINT" --kid 2 --exp "2026-09-19T23:59:59Z"

# 2. Notifier équipe dev pour mise à jour PUB_KEYS
```

---

## 📋 Variables Essentielles

### Secrets (Azure Key Vault)
```bash
PACKAGER_PRIVATE_HEX_KID_1="[VAULT:licenses/private-1]"
PACKAGER_PRIVATE_HEX_KID_2="[VAULT:licenses/private-2]"  
```

### Durées standard
```
- Demo/Test: 30 jours
- Standard: 1 an (365 jours)
- Premium: 2 ans (730 jours)
- Enterprise: 5 ans (1825 jours)
```

### Kids actifs
```
kid=1: Clé production principale (active)
kid=2: Clé rotation/urgence (prête)
kid=3: Clé future (à préparer)
```

---

## ✅ Checklist Rapide

### Avant génération
```
□ Empreinte machine obtenue
□ USB serial si requis
□ Durée validée avec client
□ Secret CI/CD disponible
```

### Après génération  
```
□ Vérification avec verify-license.mjs
□ Taille license.bin > 400 bytes
□ Package client préparé
□ Instructions envoyées
```

### Suivi client
```
□ Installation confirmée
□ "INSTALLATION REUSSIE" reçu
□ Application fonctionne
□ Support fermé
```

---

## 🎯 Commandes Copier-Coller

### ⚡ Workflow Ultra-Rapide (RECOMMANDÉ)
```powershell
# 1. Secret (une fois par session)
$env:PACKAGER_PRIVATE_HEX = "[SECRET_VAULT]"

# 2. Génération complète (remplacer FINGERPRINT et CLIENT)
.\scripts\generate-client-license.ps1 -ClientFingerprint "FINGERPRINT" -ClientName "CLIENT"

# 3. Livraison
# → Zip et envoyer dossier delivery-CLIENT/
# → Instructions: .\install.ps1
```
**⏱️ Temps total : 30 secondes**

### 📋 Workflow Manuel (si besoin)
```powershell
# 1. Empreinte (chez client ou remote)
node scripts/print-bindings.mjs

# 2. Secret (une fois par session)
$env:PACKAGER_PRIVATE_HEX = "[SECRET_VAULT]"

# 3. Génération (remplacer FINGERPRINT)
node scripts/make-license.mjs "FINGERPRINT" --kid 1 --exp "2026-09-19T23:59:59Z"

# 4. Vérification  
node scripts/verify-license.mjs "vault-real"

# 5. Livraison manuelle
# → Envoyer license.bin + install.ps1 + README.md
```
**⏱️ Temps total : 2 minutes**

### Support diagnostic
```powershell
# Client exécute pour diagnostic
.\install.ps1 -Verbose

# Codes retour:
# 0 = OK
# 1 = Erreur technique  
# 2 = Licence invalide
```

---

**� Workflow Ultra-Rapide : 30 secondes génération → livraison**  
**📞 Support Level 1 : Script one-liner suffit**  
**🆘 Escalade si : Kids épuisés ou corruption système**