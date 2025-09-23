# Guide de Licence Client
## USB Video Vault

**Version 1.0 - Guide Utilisateur**

---

## 🔑 Comprendre votre licence USB Video Vault

### Qu'est-ce qu'une licence USB Video Vault ?

Votre licence USB Video Vault est un **certificat numérique sécurisé** qui :
- ✅ Autorise l'utilisation du logiciel sur **votre périphérique USB spécifique**
- 🔒 Garantit que **vos données restent privées et sécurisées**
- 🛡️ Protège contre l'utilisation non autorisée
- 📱 Lie le logiciel à l'**empreinte unique** de votre périphérique

---

## 📋 Informations sur votre licence

### Comment vérifier votre licence

1. **Dans l'application :**
   - Ouvrez USB Video Vault
   - Allez dans `Aide > Informations sur la licence`
   - Vérifiez le statut et la date d'expiration

2. **Via l'outil de vérification :**
   ```bash
   # Fourni avec votre installation
   node verify-license.mjs
   ```

### Statuts possibles

| Statut | Description | Action |
|--------|-------------|---------|
| ✅ **Valide** | Licence active et fonctionnelle | Aucune action requise |
| ⚠️ **Expire bientôt** | Licence expire dans moins de 30 jours | Contactez le support pour renouvellement |
| ❌ **Expirée** | Licence dépassée | Renouvellement nécessaire |
| 🚫 **Invalide** | Problème de signature ou corruption | Contactez le support immédiatement |

---

## 🔧 Gestion de votre licence

### Installation initiale

1. **Réception de votre licence :**
   - Vous recevrez un fichier `license.bin` sécurisé
   - Ce fichier est **unique** à votre périphérique USB
   - ⚠️ **Ne partagez jamais ce fichier** avec d'autres personnes

2. **Installation :**
   - Placez le fichier `license.bin` dans le dossier `.vault` de votre périphérique USB
   - Redémarrez l'application
   - Vérifiez que le statut affiche "Licence valide"

### Sauvegarde de votre licence

```bash
# Créer une copie de sauvegarde sécurisée
copy ".vault\license.bin" "backup\license-backup-$(Get-Date -Format 'yyyy-MM-dd').bin"
```

⚠️ **Important :** Stockez cette sauvegarde dans un lieu sûr, séparé de votre périphérique USB principal.

---

## 🛠️ Résolution des problèmes courants

### Erreur : "Licence non trouvée"

**Causes possibles :**
- Fichier `license.bin` manquant dans `.vault/`
- Périphérique USB non détecté correctement
- Permissions insuffisantes

**Solutions :**
1. Vérifiez la présence du fichier : `.vault/license.bin`
2. Redémarrez l'application en tant qu'administrateur
3. Vérifiez les permissions du dossier `.vault`

### Erreur : "Signature de licence invalide"

**Causes possibles :**
- Fichier licence corrompu
- Tentative d'utilisation sur un autre périphérique
- Modification non autorisée du fichier

**Solutions :**
1. Restaurez votre fichier licence depuis la sauvegarde
2. Contactez le support avec votre numéro de série
3. ⚠️ **Ne modifiez jamais manuellement le fichier licence**

### Erreur : "Licence expirée"

**Causes possibles :**
- Date d'expiration dépassée
- Horloge système incorrecte
- Tentative de manipulation de l'horloge

**Solutions :**
1. Vérifiez la date/heure de votre système
2. Contactez le support pour renouvellement
3. **Évitez de modifier l'horloge système** pour contourner l'expiration

### Erreur : "Périphérique non autorisé"

**Causes possibles :**
- Licence générée pour un autre périphérique
- Changement matériel du périphérique USB
- Corruption de l'empreinte matérielle

**Solutions :**
1. Vérifiez que vous utilisez le bon périphérique USB
2. Contactez le support avec votre numéro de série et l'empreinte de votre périphérique
3. Une nouvelle licence peut être nécessaire

---

## 🔍 Outils de diagnostic

### Script de vérification inclus

Votre installation inclut un outil de vérification :

```javascript
// verify-license.mjs - Fourni avec votre installation
// Usage : node verify-license.mjs

console.log("🔍 Vérification de la licence USB Video Vault...");

// Vérifications automatiques :
// ✓ Présence du fichier licence
// ✓ Validité de la signature
// ✓ Date d'expiration
// ✓ Correspondance avec le périphérique
// ✓ Intégrité des données
```

### Collecte d'informations pour le support

En cas de problème, utilisez notre outil de diagnostic :

```powershell
# Script de support fourni
.\generate-support-bundle.ps1
```

Cet outil collecte **uniquement les informations techniques nécessaires** :
- Journaux d'erreurs (sans données personnelles)
- Statut de la licence (sans le contenu)
- Informations système de base
- Configuration de l'application

⚠️ **Aucune donnée média ou personnelle** n'est incluse dans le bundle de support.

---

## 📞 Support et assistance

### Avant de contacter le support

1. **Vérifiez votre licence :**
   ```bash
   node verify-license.mjs
   ```

2. **Collectez les informations de diagnostic :**
   ```powershell
   .\generate-support-bundle.ps1
   ```

3. **Notez les détails :**
   - Message d'erreur exact
   - Heure d'occurrence
   - Actions effectuées avant l'erreur

### Contact du support

**Email :** support@usb-video-vault.com  
**Sujet :** [LICENCE] Description du problème  

**Informations à inclure :**
- Votre numéro de série (si disponible)
- Bundle de support généré
- Description détaillée du problème
- Screenshots des messages d'erreur

**Temps de réponse :**
- Problèmes de licence : 24-48 heures
- Questions générales : 72 heures
- Urgences sécurité : 4-8 heures

---

## 🛡️ Sécurité et bonnes pratiques

### Protection de votre licence

1. **Ne jamais partager :**
   - Votre fichier `license.bin`
   - Votre numéro de série
   - Vos informations de périphérique

2. **Sauvegarde régulière :**
   - Copiez `license.bin` dans un lieu sûr
   - Testez régulièrement vos sauvegardes
   - Gardez plusieurs copies dans des lieux différents

3. **Utilisation sécurisée :**
   - N'utilisez que sur votre périphérique autorisé
   - Évitez les modifications de l'horloge système
   - Maintenez votre système à jour

### Signes d'alerte

Contactez immédiatement le support si :
- ❌ Votre licence fonctionne sur un périphérique non autorisé
- ❌ Des messages d'erreur inhabituels apparaissent
- ❌ Le comportement de l'application change soudainement
- ❌ Vous suspectez une compromission de sécurité

---

## 📜 Conformité et légal

### Utilisation autorisée

Votre licence autorise :
- ✅ Usage personnel sur le périphérique spécifié
- ✅ Sauvegarde de vos données média
- ✅ Utilisation normale des fonctionnalités

### Utilisation interdite

Votre licence interdit :
- ❌ Partage ou distribution de la licence
- ❌ Utilisation sur d'autres périphériques
- ❌ Modification ou contournement des protections
- ❌ Usage commercial (sauf licence spécifique)

### Respect de la vie privée

- 🔒 **Vos données restent locales** sur votre périphérique USB
- 🚫 **Aucune collecte** de données personnelles ou média
- 🔐 **Chiffrement complet** de vos informations
- 👤 **Contrôle total** sur vos données

---

## 💡 Conseils et astuces

### Optimisation des performances

1. **Périphérique USB :**
   - Utilisez USB 3.0 ou supérieur pour de meilleures performances
   - Évitez les hubs USB non alimentés
   - Gardez votre périphérique propre et en bon état

2. **Système :**
   - Maintenez votre OS à jour
   - Libérez régulièrement l'espace disque
   - Fermez les applications inutiles

### Maintenance préventive

- **Hebdomadaire :** Vérifiez le statut de votre licence
- **Mensuel :** Sauvegardez votre fichier licence
- **Trimestriel :** Testez vos sauvegardes
- **Annuel :** Vérifiez la date d'expiration

---

## 📚 Ressources supplémentaires

### Documentation

- **Guide utilisateur complet :** `docs/USER_GUIDE.md`
- **FAQ :** https://usb-video-vault.com/faq
- **Tutoriels vidéo :** https://usb-video-vault.com/tutorials

### Communauté

- **Forum utilisateurs :** https://community.usb-video-vault.com
- **Base de connaissances :** https://kb.usb-video-vault.com
- **Mises à jour :** https://usb-video-vault.com/updates

---

**© 2024 USB Video Vault. Tous droits réservés.**

*Ce guide est fourni avec votre licence et fait partie intégrante de votre expérience USB Video Vault. Gardez-le accessible pour référence future.*