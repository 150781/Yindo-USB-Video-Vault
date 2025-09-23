# Certificate Revocation List (CRL) - USB Video Vault
# Système de révocation de licences par licenseId/kid

## Vue d'ensemble

Le système CRL (Certificate Revocation List) permet de révoquer des licences de manière centralisée et sécurisée, même après leur émission et distribution.

## Architecture

### Composants
1. **CRL Server** : Service centralisé de gestion des révocations
2. **CRL Cache** : Cache local dans l'application
3. **CRL Management Tools** : Outils opérationnels de gestion
4. **Verification Engine** : Moteur de vérification intégré

### Flux de Révocation
```
[Opérateur] → [CRL Management] → [CRL Server] → [Application] → [Vérification]
```

## Structure CRL

### Format JSON Signé
```json
{
  "version": "1.0",
  "issuer": "USB Video Vault CA",
  "issuedAt": "2024-01-15T10:30:00Z",
  "nextUpdate": "2024-01-16T10:30:00Z",
  "revokedLicenses": [
    {
      "licenseId": "abc123...",
      "kid": "42",
      "revokedAt": "2024-01-15T09:15:00Z",
      "reason": "suspected_compromise",
      "serial": "UV-2024-001234"
    }
  ],
  "signature": "..."
}
```

### Raisons de Révocation
- `suspected_compromise` : Compromission suspectée
- `unauthorized_use` : Usage non autorisé détecté
- `license_abuse` : Abus de licence
- `administrative` : Révocation administrative
- `superseded` : Remplacée par une nouvelle licence

## Implémentation

### 1. CRL Server (Optionnel - Future)
Service HTTP sécurisé pour distribuer les CRL.

### 2. CRL Embarquée (Actuelle)
CRL distribuée avec les mises à jour de l'application.

### 3. Vérification Locale
Vérification systématique au démarrage de l'application.

## Sécurité

### Protection de la CRL
- **Signature cryptographique** : RSA-2048 ou ECDSA
- **Horodatage sécurisé** : Prévention des attaques de rollback
- **Validation d'intégrité** : Vérification de la chaîne de signatures

### Gestion des Clés
- **Clé privée CRL** : Stockage HSM (Hardware Security Module)
- **Clé publique CRL** : Intégrée dans l'application
- **Rotation de clés** : Processus de rotation automatique

## Procédures Opérationnelles

### Révocation d'Urgence
1. **Identification** : Détection d'un problème de sécurité
2. **Décision** : Validation par l'équipe sécurité
3. **Révocation** : Ajout à la CRL et signature
4. **Distribution** : Mise à jour immédiate ou différée

### Révocation Standard
1. **Demande** : Formulaire de demande de révocation
2. **Validation** : Vérification des justifications
3. **Traitement** : Ajout à la CRL programmée
4. **Notification** : Information des parties concernées

## Monitoring et Audit

### Métriques
- Nombre de licences révoquées
- Fréquence des vérifications CRL
- Taux d'échec de vérification
- Temps de propagation des révocations

### Logs d'Audit
- Toutes les révocations avec justifications
- Tentatives d'usage de licences révoquées
- Erreurs de vérification CRL
- Mises à jour de la CRL

## Limites et Considérations

### Disponibilité Offline
- L'application peut fonctionner sans accès CRL
- Cache local de la dernière CRL connue
- Période de grâce configurable

### Performance
- Cache local pour éviter les vérifications répétées
- Vérification asynchrone en arrière-plan
- Optimisation pour les grandes CRL

### Faux Positifs
- Processus de réclamation pour les révocations erronées
- Procédure de restauration de licence
- Audit trail complet

Cette architecture CRL offre un équilibre entre sécurité, performance et facilité de gestion opérationnelle.