# API Preload Validée - Formats de Données

## Queue API ✅ VALIDÉ

### setRepeat(mode) ✅ CRITIQUE
```javascript
// ✅ CORRECT (format actuel qui fonctionne):
setRepeat: (mode) => ipcRenderer.invoke('queue:setRepeat', mode)

// ❌ ANCIEN FORMAT CASSÉ (ne pas restaurer):
// setRepeat: (mode) => ipcRenderer.invoke('queue:setRepeat', { mode })
```

**Usage Frontend**:
```typescript
await electron.queue.setRepeat('one');   // ✅ Envoie "one"
await electron.queue.setRepeat('all');   // ✅ Envoie "all"  
await electron.queue.setRepeat('none');  // ✅ Envoie "none"
```

**Handler Backend** (ipcQueue.ts):
```typescript
ipcMain.handle('queue:setRepeat', async (_e, mode: 'none' | 'one' | 'all') => {
  console.log('[QUEUE] setRepeat appelé:', mode, 'typeof:', typeof mode);
  queueState.repeatMode = mode;  // Direct assignment
  return queueState;
});
```

### playNow(id) ✅ VALIDÉ
```javascript
playNow: (id) => ipcRenderer.invoke('queue:playNow', { id })
```

### get() ✅ VALIDÉ
```javascript
get: () => ipcRenderer.invoke('queue:get')
```

## Autres APIs Validées

### Player API ✅
```javascript
player: {
  play: () => ipcRenderer.invoke('player:play'),
  pause: () => ipcRenderer.invoke('player:pause'),
  seek: (time) => ipcRenderer.invoke('player:seek', { time }),
  // etc...
}
```

### Stats API ✅
```javascript
stats: {
  get: () => ipcRenderer.invoke('stats:get'),
  incrementViews: (id) => ipcRenderer.invoke('stats:incrementViews', { id }),
  addPlayedMs: (id, ms) => ipcRenderer.invoke('stats:addPlayedMs', { id, ms })
}
```

## Format des Retours

### Queue State ✅
```typescript
interface QueueState {
  items: QueueItem[];
  currentIndex: number;
  isPlaying: boolean;
  isPaused: boolean;
  repeatMode: 'none' | 'one' | 'all';  // ⚠️ TOUJOURS une string
  shuffleMode: boolean;
}
```

### UI Safety Pattern ✅
```typescript
// Dans tous les composants React:
const mode = String(queue.repeatMode || 'none');
const displayText = mode.toUpperCase();  // Sûr maintenant
```

## Tests de Validation API

### Test 1: Type Consistency
```typescript
// Vérifier que repeatMode est toujours une string
const queue = await electron.queue.get();
console.log(typeof queue.repeatMode);  // Doit être "string"
```

### Test 2: SetRepeat Flow
```typescript
await electron.queue.setRepeat('one');
const updated = await electron.queue.get();
console.log(updated.repeatMode === 'one');  // Doit être true
```

### Test 3: UI Display
```typescript
// Doit fonctionner sans erreur:
const mode = String(queue.repeatMode || 'none');
const label = `Repeat: ${mode.toUpperCase()}`;
```

## Logs de Validation

### Preload Correct
```
[preload.cjs] window.electron exposé: ...,queue,...
[preload.cjs] methods queue: get,playNow,setRepeat,...
```

### Backend Reception
```
[QUEUE] setRepeat appelé: one typeof: string
[QUEUE] queueState.repeatMode après assignation: one typeof: string
```

### Frontend Safe
```
[control] Repeat mode défini: one
```

## ⚠️ Points de Vigilance

1. **Type Safety**: `repeatMode` doit TOUJOURS être une string
2. **No Object Wrapping**: setRepeat envoie `mode` directement, pas `{ mode }`
3. **Defensive UI**: Toujours wrapper avec `String()` dans l'interface
4. **Single Source**: Un seul handler `queue:setRepeat` dans `ipcQueue.ts`

---
**Date**: 15 septembre 2025  
**Status**: ✅ API VALIDÉE - Formats de données verrouillés
