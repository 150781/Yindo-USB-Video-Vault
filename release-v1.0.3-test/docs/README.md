# README - Documentation du Système de Playlist

## 📚 Documentation Disponible

Ce dossier contient la documentation complète du système de playlist de l'application USB Video Vault.

### 📋 Documents

1. **[Guide Drag & Drop](./DRAG_DROP_GUIDE.md)** 🎯
   - Bonnes pratiques pour le drag & drop
   - Prévention des erreurs courantes
   - Patterns de protection contre les événements multiples
   - Checklist de validation

2. **[Architecture Playlist](./PLAYLIST_ARCHITECTURE.md)** 🏗️
   - Vue d'ensemble de l'architecture système
   - Flux de données frontend ↔ backend
   - Types de données et conventions
   - Patterns de synchronisation d'état

3. **[Guide de Débogage](./DEBUG_GUIDE.md)** 🔍
   - Diagnostic des problèmes courants
   - Outils de débogage avancés
   - Analyse des logs structurés
   - Procédures de résolution étape par étape

## 🚀 Démarrage Rapide

### Pour les développeurs

1. **Avant de modifier le code drag & drop** → Lire le [Guide Drag & Drop](./DRAG_DROP_GUIDE.md)
2. **Pour comprendre l'architecture** → Consulter [Architecture Playlist](./PLAYLIST_ARCHITECTURE.md)
3. **En cas de problème** → Suivre le [Guide de Débogage](./DEBUG_GUIDE.md)

### Pour les nouveaux contributeurs

```bash
# 1. Cloner et installer
git clone <repo>
cd Yindo-USB-Video-Vault
npm install

# 2. Lancer en mode debug
npm run build
npx electron dist/main/index.js --enable-logging

# 3. Consulter la documentation
# Commencer par PLAYLIST_ARCHITECTURE.md pour comprendre le système
```

## 🎯 Résolution de problèmes courants

### ❓ Problème de doublons dans la playlist ?
→ Voir [Guide Drag & Drop - Section Problèmes courants](./DRAG_DROP_GUIDE.md#problèmes-courants-et-solutions)

### ❓ Interface qui ne répond plus lors du drag ?
→ Voir [Guide de Débogage - Lag ou freeze](./DEBUG_GUIDE.md#3-lag-ou-freeze-lors-du-drag--drop)

### ❓ État incohérent entre affichage et données réelles ?
→ Voir [Architecture - Pattern de synchronisation](./PLAYLIST_ARCHITECTURE.md#1-pattern-de-synchronisation-état)

## 📊 Standards de qualité

### Code Review Checklist

Avant d'approuver une PR touchant au système de playlist :

- [ ] **Protection anti-double événements** implémentée
- [ ] **Logs de debug** ajoutés aux points critiques
- [ ] **Tests manuels** effectués (voir checklist dans [DRAG_DROP_GUIDE.md](./DRAG_DROP_GUIDE.md))
- [ ] **Documentation** mise à jour si nécessaire
- [ ] **Performance** validée (pas de lag notable)

### Tests obligatoires

1. **Fonctionnels**
   - Drag depuis catalogue vers playlist vide ✅
   - Drag depuis catalogue vers playlist existante ✅
   - Réorganisation dans la playlist ✅
   - Actions rapides/multiples ✅

2. **Non-fonctionnels**
   - Pas de doublons involontaires ✅
   - Interface réactive (< 100ms) ✅
   - Logs propres sans erreurs ✅
   - État synchronisé frontend/backend ✅

## 🔄 Historique et évolutions

### Version 1.0 (Septembre 2025)
- ✅ **Correction du bug de doublons** lors du drag & drop
- ✅ **Protection contre événements multiples** avec `isDropInProgress`
- ✅ **Documentation complète** du système
- ✅ **Guides de débogage** et bonnes pratiques

### Fonctionnalités prévues

- **V1.1** : Tests automatisés du drag & drop
- **V1.2** : Interface d'administration de la playlist
- **V1.3** : Support drag & drop multi-sélection

## 🤝 Contribution

### Workflow de développement

1. **Étudier** la documentation pertinente
2. **Créer une branche** depuis `main`
3. **Implémenter** en suivant les patterns documentés
4. **Tester** selon la checklist
5. **Documenter** les changements significatifs
6. **Soumettre** une PR avec description détaillée

### Standards de commit

```
type(scope): description courte

Description détaillée si nécessaire

- Changement 1
- Changement 2

Fixes #123
```

**Types** : `feat`, `fix`, `docs`, `refactor`, `test`, `perf`
**Scopes** : `playlist`, `drag-drop`, `queue`, `ui`, `backend`

Exemples :
```
fix(drag-drop): empêcher les doublons lors du drop multiple
feat(playlist): ajouter support réorganisation par clavier
docs(drag-drop): mettre à jour guide avec nouveaux patterns
```

## 📞 Support

### Problème technique urgent ?

1. **Consulter** le [Guide de Débogage](./DEBUG_GUIDE.md)
2. **Collecter** les logs et informations de reproduction
3. **Créer** une issue avec template approprié
4. **Taguer** selon la priorité (`bug`, `enhancement`, `question`)

### Amélioration de la documentation ?

1. **Identifier** la lacune ou imprécision
2. **Proposer** une amélioration via PR
3. **Maintenir** la cohérence avec le style existant
4. **Tester** les exemples de code proposés

## 📄 Licence et crédits

Ce projet est sous licence [voir LICENSE]. La documentation est maintenue par l'équipe de développement.

---

**Dernière mise à jour** : Septembre 2025  
**Version de la documentation** : 1.0  
**Maintenu par** : Équipe développement USB Video Vault
