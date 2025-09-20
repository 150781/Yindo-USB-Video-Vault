# 🧪 Tests QA Finaux - Licence System

## 📋 Scénarios de Validation (à cocher)

### ✅ 1. Génération de Licence

#### 1.1 Génération Standard
```bash
□ CLI avec fingerprint valide
□ CLI avec options --kid, --exp, --out
□ Sortie license.bin + license.json
□ Tailles fichiers correctes
□ Format base64 valide
```

#### 1.2 Génération avec Erreurs
```bash
□ Fingerprint invalide (trop court)
□ Fingerprint invalide (caractères non-hex)
□ Kid inexistant
□ Date expiration passée
□ Clé privée manquante
□ Permissions insuffisantes (écriture)
```

### ✅ 2. Validation en Production

#### 2.1 Licences Valides
```bash
□ License.bin standard (kid-1)
□ License.json fallback
□ Machine matching exact
□ Expiration future
□ Signature correcte
```

#### 2.2 Licences Invalides
```bash
□ Fichier corrompu
□ Signature altérée
□ Kid inconnu
□ Machine différente
□ Expiration passée
□ Format invalide
□ Fichier manquant
```

### ✅ 3. Anti-Rollback

#### 3.1 Protection Normale
```bash
□ Premier démarrage (pas de state)
□ Renouvellement licence (même exp)
□ Upgrade licence (exp future)
□ Redémarrage application (state conservé)
```

#### 3.2 Détection Rollback
```bash
□ Licence exp antérieure rejetée
□ State file corrompu détecté
□ Tentative modification state
□ Récupération automatique state
```

### ✅ 4. Binding Machine/USB

#### 4.1 Machine Binding
```bash
□ Fingerprint exact match
□ Fingerprint case insensitive
□ Machine déplacée (nouveau HW)
□ VM migration
```

#### 4.2 USB Binding (si applicable)
```bash
□ USB série exact match
□ USB débranché/rebranché
□ USB différent connecté
□ Plusieurs USB connectés
```

### ✅ 5. Gestion des Erreurs

#### 5.1 Messages d'Erreur
```bash
□ "License file not found" - clair
□ "Invalid signature" - ne révèle pas détails
□ "License expired" - avec date
□ "Machine binding failed" - avec hint
□ "Rollback attempt detected" - sécurisé
```

#### 5.2 Logs Sécurisés
```bash
□ Pas de données sensibles loggées
□ Fingerprints tronqués (ba33ce76...)
□ Signatures non-loggées
□ Timestamps précis
□ Niveaux appropriés (warn/error)
```

### ✅ 6. Performance

#### 6.1 Temps de Validation
```bash
□ < 100ms pour licence valide
□ < 50ms pour licence en cache
□ < 200ms pour première validation
□ Pas de blocage UI
```

#### 6.2 Mémoire et Resources
```bash
□ Pas de fuite mémoire
□ Clés privées non-exposées
□ Cleanup automatique
□ Threads non-bloqués
```

## 🤖 Tests Automatisés

### Script de Test Complet
```bash
# Lancer tous les scénarios
node test/qa-license-complete.js

# Résultats attendus:
# ✅ 47 tests passés
# ❌ 0 tests échoués
# ⚠️  0 tests skippés
```

### Tests Individuels
```bash
# Test génération
node test/test-license-generation.js

# Test validation
node test/test-license-validation.js

# Test anti-rollback
node test/test-anti-rollback.js

# Test performance
node test/test-performance.js
```

## 📊 Métriques de Réussite

### Critères d'Acceptation
```
□ 100% scénarios valides passent
□ 100% scénarios invalides échouent correctement
□ 0 faux positifs de sécurité
□ < 1% faux négatifs (erreurs réseau)
□ Temps validation < 100ms médian
□ 0 données sensibles dans les logs
```

### Benchmarks Performance
```
Opération                    Target    Mesurée
================================== 
Validation licence valide    < 100ms   [__ms]
Cache hit                    < 50ms    [__ms]
Génération licence          < 2s      [__s]
Anti-rollback check         < 10ms    [__ms]
Machine fingerprint         < 500ms   [__ms]
```

## 🔧 Procédure de Test

### Environnement de Test
```bash
# Setup environnement propre
rm -rf test-env/
mkdir test-env/
cd test-env/

# Variables test
$env:PACKAGER_PRIVATE_HEX = "TEST_KEY_HEX"
$env:TEST_MODE = "true"
```

### Exécution Séquentielle
```bash
# 1. Tests génération
npm run test:generation

# 2. Tests validation
npm run test:validation  

# 3. Tests sécurité
npm run test:security

# 4. Tests performance
npm run test:performance

# 5. Tests intégration
npm run test:integration
```

## 🚨 Critères d'Échec

### Bloquants (stop release)
- Licence valide rejetée
- Licence invalide acceptée
- Données sensibles loggées
- Performance < targets
- Anti-rollback bypassé

### Non-bloquants (fix post-release)
- Messages d'erreur peu clairs
- Logs verbeux
- Performance 10% au-dessus target
- UI mineure

## ✅ Validation Finale

```bash
Date: ___________
Testeur: ___________
Version: ___________

□ Tous les tests automatisés passent
□ Tests manuels complets
□ Performance dans les targets
□ Sécurité validée
□ Documentation jour
□ Prêt pour release

Signature: ___________
```

---
**Tests obligatoires avant tout déploiement production**