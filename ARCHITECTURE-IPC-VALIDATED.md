# Architecture IPC Validée - Ne Pas Modifier

## Import Structure Validée ✅

### `src/main/index.ts` - Imports corrects
```typescript
import './ipc.js';          // ✅ Handlers généraux
import './ipcQueue.js';     // ✅ SEUL fichier pour handlers queue:*
// import './ipcQueueStats.js'; // ❌ NE JAMAIS décommenter cette ligne
```

## Handlers IPC Distribution

### ipc.ts ✅
- Handlers généraux de l'application
- `catalog:*`, `license:*`, `manifest:*`, etc.

### ipcQueue.ts ✅ CRITIQUE
- `queue:playNow` - Lance la lecture avec ensureDisplayAndSend
- `queue:setRepeat` - Définit le mode repeat (string directe)
- `queue:getRepeat` - Récupère le mode repeat
- `queue:get` - État de la queue
- `player:event` - Gestion ended/repeat/next ⚠️ CRITIQUE

### ipcQueueStats.ts ❌ NON UTILISÉ
- Fichier désactivé pour éviter les conflits
- Contient des handlers dupliqués
- NE JAMAIS l'importer dans index.ts

## Validation Technique

### Test 1: Un seul handler par channel
```bash
# Vérifier qu'il n'y a qu'un seul handler queue:setRepeat
grep -r "queue:setRepeat" src/main/
# Résultat attendu: SEULEMENT dans ipcQueue.ts
```

### Test 2: Import correct
```bash
# Vérifier les imports dans index.ts
grep "ipcQueue" src/main/index.ts
# Résultat attendu: import './ipcQueue.js'; (sans Stats)
```

### Test 3: Preload API format
```bash
# Vérifier le format dans preload.cjs
grep "setRepeat" src/main/preload.cjs
# Résultat attendu: setRepeat: (mode) => invoke('queue:setRepeat', mode)
```

## ⚠️ Points Critiques de Régression

1. **Handler Conflicts**: Un seul `queue:setRepeat` handler autorisé
2. **Data Format**: setRepeat doit envoyer `mode` pas `{ mode }`
3. **Event Logic**: `player:event` dans ipcQueue.ts contient la logique repeat
4. **UI Safety**: Tous les `repeatMode` doivent être wrapped avec `String()`

## Messages de Log Validation

### Au démarrage
```
[main] IPC Queue & Stats chargé via import
```

### Lors du setRepeat
```
[QUEUE] setRepeat appelé: one typeof: string
[QUEUE] queueState.repeatMode après assignation: one typeof: string
```

### Lors de l'ended event
```
[QUEUE] player:event ended reçu - gestion du repeat/next
[QUEUE] État actuel: { repeatMode: "one", currentIndex: 0, itemsLength: 1 }
[QUEUE] Mode repeat "one" - relancement fichier actuel
```

## Scripts de Validation

### Build Safe
```bash
npm run build       # Build complet recommandé
npm run build:main  # Si changements backend seulement
```

### Test Complet
```bash
npx electron dist/main/index.js --enable-logging
# Vérifier les logs ci-dessus
```

---
**Date de validation**: 15 septembre 2025  
**Status**: ✅ FONCTIONNEL - Architecture verrouillée
