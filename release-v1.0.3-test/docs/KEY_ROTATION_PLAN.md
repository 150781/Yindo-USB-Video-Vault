# 🔑 Plan de Rotation des Clés - Yindo License System

## 📋 Vue d'Ensemble

### Architecture Actuelle
```
Kid → Clé Publique (Table de Correspondance)
===========================================
1   → 879c35f5ae011c56528c27abb0f5b61539bf0d134158ec56ac4e8b8dd08c9d78
2   → [RÉSERVÉ - Prochaine rotation]
3   → [RÉSERVÉ - Rotation d'urgence]
```

### Politique de Rotation
- **Rotation normale**: 12 mois
- **Rotation d'urgence**: Immédiate si compromission
- **Overlap**: 30 jours entre ancienne/nouvelle clé
- **Historique**: Conservation 24 mois pour support

## 🔄 Procédure de Rotation Standard

### Phase 1: Préparation (J-30)
```bash
# 1. Générer nouvelle paire de clés
node scripts/keygen.cjs --kid 2 --output vault-keys/

# 2. Mettre à jour PUB_KEYS
# Ajouter kid-2 dans src/main/licenseSecure.ts

# 3. Tester en parallèle
$env:PACKAGER_PRIVATE_HEX = "NOUVELLE_CLE_PRIVEE"
node scripts/make-license.mjs "test-machine" --kid 2
```

### Phase 2: Déploiement (J-0)
```bash
# 1. Release application avec PUB_KEYS étendu
npm run build:all
npm run pack:usb

# 2. Basculer génération vers kid-2
$env:PACKAGER_PRIVATE_HEX = "NOUVELLE_CLE_PRIVEE"

# 3. Nouvelles licences avec kid-2
node scripts/make-license.mjs "fingerprint" --kid 2
```

### Phase 3: Migration (J+1 à J+30)
```bash
# Régénérer licences clients avec kid-2
# Anciennes licences (kid-1) restent valides

# Surveillance
node scripts/verify-license.mjs vault-path/
```

### Phase 4: Décommission (J+30)
```bash
# Retirer kid-1 de PUB_KEYS
# src/main/licenseSecure.ts

# Archive clé privée kid-1
mv keys/private-kid-1.pem keys/archived/
```

## 🚨 Rotation d'Urgence

### Déclencheurs
- Exposition clé privée
- Violation sécurité
- Audit externe

### Procédure Express (4h)
```bash
# 1. Générer clé d'urgence
node scripts/keygen.cjs --kid 3 --emergency

# 2. Hot-fix application
# Ajouter kid-3, désactiver kids compromis

# 3. Release urgente
npm run build:emergency

# 4. Régénération massive
./scripts/mass-regenerate-licenses.sh --kid 3

# 5. Notification clients
./scripts/send-license-alert.sh
```

## 📊 Monitoring & Alertes

### Métriques Clés
```bash
# Distribution des kids en production
SELECT kid, COUNT(*) FROM licenses_issued GROUP BY kid;

# Licences proches expiration
SELECT * FROM licenses WHERE exp < NOW() + INTERVAL 30 DAY;

# Échecs validation par kid
grep "License verification failed" logs/ | grep -oE "kid-[0-9]+" | sort | uniq -c
```

### Alertes Automatiques
- **30j avant expiration clé**: Préparer rotation
- **7j avant expiration clé**: Rotation obligatoire
- **Kid inconnu détecté**: Investigation sécurité
- **Pic d'échecs validation**: Vérifier déploiement

## 🔐 Gestion des Secrets

### Variables d'Environnement CI/CD
```bash
# Clés actives
PACKAGER_PRIVATE_HEX_KID_1="..."
PACKAGER_PRIVATE_HEX_KID_2="..."
PACKAGER_PRIVATE_HEX_KID_3="..."

# Clé active courante
CURRENT_SIGNING_KID="2"

# Backup/Archive
ARCHIVED_KEYS_VAULT="azure-key-vault://licenses"
```

### Accès Contrôlé
- **Génération**: CI/CD uniquement
- **Rotation**: 2 personnes minimum
- **Archive**: Backup chiffré, accès audité
- **Urgence**: Procédure break-glass documentée

## 📝 Runbook Opérateur

### Commandes Essentielles
```bash
# Vérifier distribution kids
node scripts/analyze-kid-distribution.mjs

# Tester toutes les clés actives
node scripts/test-all-keys.mjs

# Générer rapport rotation
node scripts/rotation-report.mjs --kid 2

# Valider déploiement post-rotation
node scripts/validate-rotation.mjs --old-kid 1 --new-kid 2
```

### Checklist Rotation
```
□ Nouvelle paire générée et testée
□ PUB_KEYS mis à jour dans le code
□ Tests automatisés passés
□ Release déployée
□ Nouvelles licences générées avec nouveau kid
□ Monitoring activé
□ Ancien kid désactivé après période de grâce
□ Clés archivées en sécurité
□ Documentation mise à jour
□ Équipe notifiée
```

## 📚 Historique des Rotations

| Date | Ancien Kid | Nouveau Kid | Raison | Durée |
|------|------------|-------------|---------|--------|
| 2024-09-19 | - | 1 | Déploiement initial | - |
| [À venir] | 1 | 2 | Rotation planifiée | 12 mois |

---
**Document confidentiel - Équipe DevSecOps uniquement**