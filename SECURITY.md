# Security Policy - USB Video Vault

## Signalement des vulnérabilités

### Canaux sécurisés
- **Email chiffré :** security@usbvideovault.example (GPG: voir ci-dessous)
- **GitHub Private Reports :** Via le système de Security Advisories
- **Délai de réponse :** 48h maximum pour accusé de réception

### Processus de divulgation
1. **Signalement initial** - Description détaillée via canal sécurisé
2. **Confirmation** - Accusé de réception et évaluation préliminaire (48h)
3. **Investigation** - Analyse approfondie et reproduction (1-2 semaines)
4. **Correction** - Développement et tests du correctif (2-4 semaines)
5. **Publication** - Release coordonnée et advisory public (après correctif)

## Vulnérabilités couvertes

### 🔴 Critique (P0)
- Exécution de code arbitraire
- Escalade de privilèges
- Corruption/fuite de données chiffrées
- Bypass des mécanismes de sécurité du vault

### 🟠 Haute (P1)
- Déni de service local/distant
- Fuite d'informations sensibles
- Vulnérabilités de désérialisation
- Injection dans les métadonnées

### 🟡 Moyenne (P2)
- Fuite d'informations système
- Bugs de validation d'entrée
- Vulnérabilités de path traversal
- Problèmes de gestion de session

### 🟢 Faible (P3)
- Problèmes de configuration
- Vulnérabilités d'interface utilisateur
- Fuites d'informations mineures

## Scope de sécurité

### ✅ Dans le scope
- Application principale (processus main/renderer)
- Scripts de build et packaging
- Gestion des clés de chiffrement
- API de communication IPC
- Mécanismes de validation des fichiers

### ❌ Hors scope
- Vulnérabilités dans les dépendances tierces (sauf si spécifiques à notre usage)
- Attaques nécessitant un accès physique à la machine
- Social engineering
- Déni de service par saturation réseau

## Récompenses

### Programme de Bug Bounty
- **P0 (Critique) :** 500-1000€
- **P1 (Haute) :** 200-500€
- **P2 (Moyenne) :** 50-200€
- **P3 (Faible) :** Reconnaissance publique

### Conditions
- Premier signalement de la vulnérabilité
- Rapport détaillé avec preuve de concept
- Respect du processus de divulgation responsable
- Pas d'exploitation malveillante

## Clé GPG publique

```
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQENBGXXXXXXBCADxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
=XXXX
-----END PGP PUBLIC KEY BLOCK-----
```

**Empreinte :** `1234 5678 9ABC DEF0 1234 5678 9ABC DEF0 1234 5678`

## Contact d'urgence

En cas de vulnérabilité critique exploitée activement :
- **Téléphone :** +33 X XX XX XX XX (24h/7j)
- **Signal/WhatsApp :** +33 X XX XX XX XX
- **Telegram :** @SecurityUVV

## Versions supportées

| Version | Support Sécurité | Fin de support |
|---------|------------------|----------------|
| 1.x.x   | ✅ Complet       | TBD            |
| 0.1.x   | ⚠️ Critique uniquement | 2024-12-31 |

## Historique des vulnérabilités

*Aucune vulnérabilité publique à ce jour.*

Les futurs advisories seront publiés sur :
- GitHub Security Advisories
- CVE Database (si applicable)
- Site web officiel

---

**Dernière mise à jour :** 2024-01-10
**Version de cette politique :** 1.0