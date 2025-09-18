# Corrections du Système Repeat/Next - Documentation

**Date**: 15 septembre 2025  
**Status**: ✅ FONCTIONNEL - Ne pas modifier

## Résumé des Problèmes Résolus

### Problème 1: Erreur `repeatMode.toUpperCase is not a function`
- **Cause**: Le frontend recevait parfois un objet `{ mode: 'one' }` au lieu d'une chaîne `'one'`
- **Solution**: Utiliser `String(queue.repeatMode)` dans tous les composants UI

### Problème 2: Handlers IPC en conflit
- **Cause**: Deux handlers `queue:setRepeat` dans `ipcQueue.ts` et `ipcQueueStats.ts`
- **Solution**: Supprimer le handler de `ipcQueueStats.ts`, garder seulement celui de `ipcQueue.ts`

### Problème 3: Format de données incohérent dans preload
- **Cause**: Le preload envoyait `{ mode }` mais le handler attendait `mode` directement
- **Solution**: Corriger le preload pour envoyer `mode` directement

### Problème 4: Repeat mode ne fonctionnait pas
- **Cause**: Logique de repeat/next pas implémentée dans le handler `player:event`
- **Solution**: Ajouter la logique complète dans `ipcQueue.ts`

## Fichiers Modifiés (NE PAS TOUCHER)

### 1. `src/main/preload.cjs` - ✅ CRITIQUE
```javascript
// AVANT (CASSÉ):
setRepeat: (mode) => ipcRenderer.invoke('queue:setRepeat', { mode }),

// APRÈS (FONCTIONNEL):
setRepeat: (mode) => ipcRenderer.invoke('queue:setRepeat', mode),
```

### 2. `src/main/ipcQueue.ts` - ✅ CRITIQUE
- Handler `queue:setRepeat` avec logs détaillés
- Handler `player:event` avec logique repeat/next complète
- Seul fichier autorisé pour les handlers `queue:*`

### 3. `src/main/ipcQueueStats.ts` - ✅ CRITIQUE
- Handler `queue:setRepeat` SUPPRIMÉ pour éviter les conflits
- NE DOIT PLUS être importé dans `index.ts`

### 4. `src/renderer/modules/ControlWindowClean.tsx` - ✅ CRITIQUE
```typescript
// Toutes les utilisations de repeatMode sont maintenant défensives:
const mode = String(queue.repeatMode || 'none');
const displayText = mode.toUpperCase(); // Sûr maintenant
```

### 5. `src/renderer/modules/DisplayApp.tsx` - ✅ CRITIQUE
- Logique "skip reload" remplacée par `currentTime = 0; play()` pour même fichier
- Permet la relecture du même fichier en mode repeat

## Architecture IPC Validée

### Handlers Queue (SEULEMENT dans ipcQueue.ts)
- `queue:playNow` ✅
- `queue:setRepeat` ✅
- `queue:getRepeat` ✅
- `queue:get` ✅

### Event Handler Critical
- `player:event` avec logique repeat/next complète ✅

## Tests de Validation

### Test 1: Repeat "one"
1. Jouer une chanson
2. Activer repeat "one" 
3. Attendre la fin → doit rejouer la même chanson

### Test 2: Repeat "all" 
1. Ajouter plusieurs chansons à la queue
2. Activer repeat "all"
3. Attendre la fin de la liste → doit reprendre au début

### Test 3: Repeat "none"
1. Jouer une chanson
2. Mode repeat "none" (défaut)
3. Attendre la fin → doit s'arrêter

### Test 4: Relecture même fichier
1. Jouer une chanson
2. Cliquer "Lire" à nouveau sur la même chanson
3. Doit redémarrer à currentTime=0

## Commandes Build Validées

```bash
# Build complet (recommandé)
npm run build

# Build partiel si nécessaire
npm run build:renderer  
npm run build:main

# Lancement
npx electron dist/main/index.js --enable-logging
```

## Logs de Debug Importants

Rechercher ces logs pour validation:
- `[QUEUE] setRepeat appelé:` - Vérifier le type
- `[QUEUE] player:event ended reçu` - Vérifier la logique repeat
- `[QUEUE] Mode repeat "one" - relancement` - Repeat one fonctionne
- `[QUEUE] Passage à la suivante en repeat "all"` - Repeat all fonctionne

## ⚠️ IMPORTANT - Ne Pas Casser

1. **NE JAMAIS** ré-importer `ipcQueueStats.ts` dans `index.ts`
2. **NE JAMAIS** changer le preload `setRepeat` pour envoyer un objet
3. **NE JAMAIS** supprimer les `String()` dans les composants UI
4. **NE JAMAIS** modifier la logique `player:event` dans `ipcQueue.ts`

## Prochaines Améliorations Possibles

- Ajouter des tests unitaires pour les handlers IPC
- Implémenter le mode shuffle
- Ajouter persistence du mode repeat
- Interface UI pour shuffle/repeat plus intuitive

---
**🎯 ÉTAT ACTUEL**: Tous les modes repeat fonctionnent parfaitement. Ne pas modifier sans tests complets.
