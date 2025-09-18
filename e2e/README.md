# 🎭 E2E Tests - USB Video Vault

Tests end-to-end avec Playwright pour valider la sécurité et les fonctionnalités.

## 🚀 Installation

```bash
cd e2e
npm install
npx playwright install
```

## 🧪 Exécution des Tests

```bash
# Tests en mode headless
npm run test:e2e

# Tests avec interface graphique
npm run test:e2e:headed

# Mode debug interactif
npm run test:e2e:debug

# Interface UI de Playwright
npm run test:e2e:ui
```

## 🔐 Tests de Sécurité

### **CSP (Content Security Policy)**
- ✅ Prévention XSS par injection de scripts
- ✅ Blocage des ressources externes malveillantes
- ✅ Validation des headers CSP stricts

### **Anti-Debug**
- ✅ Détection d'ouverture DevTools
- ✅ Protection contre l'ingénierie inverse
- ✅ Mesures anti-tamper

### **Protection du Contenu**
- ✅ `disablePictureInPicture` activé
- ✅ `controlsList="nodownload"` configuré
- ✅ Prévention de l'extraction vidéo

### **Multi-Fenêtres**
- ✅ Isolation entre contextes
- ✅ CSP cohérent sur toutes les fenêtres
- ✅ Limitation des accès cross-window

## 🎬 Tests Fonctionnels

### **Lecture Vidéo**
- ✅ Déchiffrement AES-256-GCM
- ✅ Intégrité des métadonnées
- ✅ Validation de la durée vidéo

### **Gestion des Stats**
- ✅ Tracking sécurisé des vues
- ✅ Pas d'exposition d'infos sensibles
- ✅ API StatsManager validée

## 🚨 Tests de Resilience

### **Gestion d'Erreurs**
- ✅ Fichiers .enc corrompus
- ✅ Messages d'erreur sécurisés
- ✅ Pas de leak d'informations

### **Licence Expirée**
- ✅ Détection automatique
- ✅ Désactivation des fonctionnalités
- ✅ Interface d'erreur appropriée

## ⚡ Tests de Performance

### **Temps de Démarrage**
- 🎯 Cible : < 5 secondes
- ✅ Mesure automatisée

### **Latence de Déchiffrement**
- 🎯 Cible : < 2 secondes
- ✅ Validation temps réel

## 📊 Rapports

Les tests génèrent automatiquement :
- **HTML Report** : `playwright-report/index.html`
- **JSON Results** : `test-results.json`
- **JUnit XML** : `test-results.xml`

## 🔧 Configuration

Voir `playwright.config.ts` pour :
- Timeouts et retries
- Screenshots/vidéos d'échec
- Configuration des devices
- Paramètres de trace

## 🎯 CI/CD Integration

Ces tests sont intégrés dans `.github/workflows/build.yml` :
- Exécution automatique sur PR/push
- Validation sur Windows + Linux
- Artefacts de test conservés en cas d'échec