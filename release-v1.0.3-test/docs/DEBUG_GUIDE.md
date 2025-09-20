# Guide de Débogage - Système de Playlist

## 🔍 Vue d'ensemble

Ce guide fournit les outils et méthodes pour diagnostiquer et résoudre les problèmes dans le système de playlist de l'application.

## 🚨 Symptômes courants et diagnostics

### 1. Doublons involontaires dans la playlist

**Symptôme** : Un seul drag & drop ajoute plusieurs fois le même élément

**Diagnostic** :
```javascript
// Rechercher ces patterns dans les logs
[DRAG] 📋 Drop sur zone playlist - Type de drag: {draggedItem: null, draggedFromCatalog: null}
[FRONTEND] ⚠️ addToQueue appelé avec: 1 items
[QUEUE] ⚠️ queue:addMany appelé avec: 1 items
[DRAG] 📋 Drop sur zone playlist - Type de drag: {draggedItem: null, draggedFromCatalog: null}  // ← DOUBLON
[FRONTEND] ⚠️ addToQueue appelé avec: 1 items  // ← DOUBLON
```

**Solution** :
- Vérifier la protection `isDropInProgress.current`
- S'assurer que `e.stopPropagation()` est appelé
- Valider qu'un seul handler traite l'événement

### 2. État incohérent entre UI et backend

**Symptôme** : L'affichage ne correspond pas à l'état réel de la queue

**Diagnostic** :
```javascript
// Comparer ces valeurs dans les logs
[FRONTEND] État affiché: 5 items
[BACKEND] État réel: 3 items  // ← INCOHÉRENCE
```

**Solution** :
- Forcer un `loadQueue()` pour resynchroniser
- Vérifier que les réponses IPC sont bien utilisées
- S'assurer qu'aucune mutation locale ne contourne le backend

### 3. Lag ou freeze lors du drag & drop

**Symptôme** : Interface bloquée pendant les opérations de drag

**Diagnostic** :
- Temps de réponse > 100ms dans les logs
- Absence de logs de completion d'opération
- Accumulation de handlers non nettoyés

**Solution** :
- Identifier les opérations synchrones bloquantes
- Vérifier le cleanup des event listeners
- Optimiser les re-renders inutiles

## 🛠️ Outils de débogage

### 1. Logs de debug structurés

Activez tous les logs pendant le développement :

```bash
# Terminal 1 : Application avec logs détaillés
npx electron dist/main/index.js --enable-logging

# Terminal 2 : Surveiller les logs en temps réel
# (Windows PowerShell)
Get-Content -Path "logs/debug.log" -Wait
```

### 2. Console de débogage intégrée

Ajoutez ces helpers dans `ControlWindowClean.tsx` :

```typescript
// Debug helper global
(window as any).debugPlaylist = {
  // Inspecter l'état actuel
  getState: () => ({
    queue: queue,
    dragState: {
      draggedItem,
      draggedFromCatalog: draggedFromCatalog?.title,
      dragOverIndex,
      isDropInProgress: isDropInProgress.current
    }
  }),
  
  // Forcer une resynchronisation
  forceSync: async () => {
    console.log('[DEBUG] Force sync avec backend...');
    await loadQueue();
  },
  
  // Vider la playlist
  clearAll: async () => {
    console.log('[DEBUG] Clear playlist...');
    await electron?.queue?.clear?.();
    await loadQueue();
  },
  
  // Simuler un état d'erreur
  simulateError: () => {
    console.log('[DEBUG] Simulation état d\'erreur...');
    setQueue({ items: [], currentIndex: -1, isPlaying: false, isPaused: false, repeatMode: 'none', shuffleMode: false });
  }
};

// Usage dans la console DevTools :
// debugPlaylist.getState()
// debugPlaylist.forceSync()
```

### 3. Monitoring d'événements

```typescript
// Monitor global pour tous les événements drag
useEffect(() => {
  const monitorDragEvents = (e: DragEvent) => {
    console.log('[DEBUG] Global drag event:', e.type, {
      target: e.target?.tagName,
      dataTransfer: e.dataTransfer?.types,
      effectAllowed: e.dataTransfer?.effectAllowed
    });
  };
  
  ['drag', 'dragstart', 'dragend', 'dragover', 'dragenter', 'dragleave', 'drop'].forEach(event => {
    window.addEventListener(event, monitorDragEvents, true);
  });
  
  return () => {
    ['drag', 'dragstart', 'dragend', 'dragover', 'dragenter', 'dragleave', 'drop'].forEach(event => {
      window.removeEventListener(event, monitorDragEvents, true);
    });
  };
}, []);
```

## 📊 Analyse des logs

### Patterns de logs sains

**1. Drag & drop normal** :
```
[DRAG] 🎬 Catalogue - DragStart pour: Song Title
[DRAG] 🎬 Catalogue - Données de drag définies
[DRAG] 🎬 Catalogue - DragOver sur zone playlist
[DRAG] 📋 Drop sur zone playlist - Type de drag: {draggedItem: null, draggedFromCatalog: null}
[DRAG] ⚠️ 📋 Drop depuis catalogue sur espace vide détecté
[FRONTEND] ⚠️ addToQueue appelé avec: 1 items
[QUEUE] ⚠️ queue:addMany appelé avec: 1 items
[QUEUE] ⚠️ queue:addMany - avant ajout, queue actuelle: 2 items
[QUEUE] ⚠️ queue:addMany - après ajout, queue nouvelle: 3 items
[DRAG] 🔄 Reset drag state - all types
[control] QUEUE CHANGE DETECTED - Queue items length: 3
```

**2. Réorganisation de playlist** :
```
[control] DRAG START - Initialisation du drag pour index: 2
[control] Setting draggedItem to: 2
[control] DROP - draggedItem: 2 dropIndex: 0
[control] Réorganisation playlist: 2 -> 0
[control] Appel IPC queue:reorder en cours...
[QUEUE] Reorder: moving item from 2 to 0
[control] Résultat reçu du backend: {items: Array(5), currentIndex: -1, ...}
[DRAG] 🔄 Reset drag state - all types
```

### Patterns de logs problématiques

**1. Double drop détecté** :
```
[DRAG] 📋 Drop sur zone playlist
[FRONTEND] ⚠️ addToQueue appelé avec: 1 items
[DRAG] 📋 Drop sur zone playlist  ← PROBLÈME : 2ème drop
[DRAG] 🚫 Drop ignoré car un drop est déjà en cours  ← PROTECTION OK
```

**2. État désynchronisé** :
```
[FRONTEND] ⚠️ addToQueue appelé avec: 1 items
[QUEUE] ⚠️ queue:addMany appelé avec: 1 items
[control] QUEUE CHANGE DETECTED - Queue items length: 5
[control] QUEUE CHANGE DETECTED - Queue items length: 3  ← INCOHÉRENCE
```

**3. Memory leak détecté** :
```
[DRAG] 🎬 Catalogue - DragStart pour: Song1
[DRAG] 🎬 Catalogue - DragStart pour: Song1  ← DOUBLON sans reset
[DRAG] 🎬 Catalogue - DragStart pour: Song1  ← MULTIPLE HANDLERS
```

## 🔧 Procédures de diagnostic

### 1. Diagnostic rapide (< 5 min)

```bash
# 1. Vérifier l'état de l'application
npx electron dist/main/index.js --enable-logging > debug.log 2>&1 &

# 2. Reproduire le problème en suivant les logs
tail -f debug.log | grep -E "\[DRAG\]|\[QUEUE\]|\[FRONTEND\]"

# 3. Rechercher des patterns problématiques
grep -E "Drop sur zone playlist.*Drop sur zone playlist" debug.log
grep -E "queue:addMany.*queue:addMany" debug.log
```

### 2. Diagnostic approfondi (15-30 min)

1. **Activer tous les logs** dans le code
2. **Reproduire le problème** avec des actions lentes et délibérées
3. **Analyser la séquence** d'événements
4. **Identifier le point de divergence** entre comportement attendu et réel
5. **Vérifier l'état** avant/après chaque opération critique

### 3. Test de régression

Après chaque correction :

```typescript
// Test manuel structuré
const regressionTest = async () => {
  console.log('[TEST] Début test de régression...');
  
  // 1. Tester ajout simple
  console.log('[TEST] Test ajout simple...');
  // Glisser un élément du catalogue
  
  // 2. Tester ajouts multiples
  console.log('[TEST] Test ajouts multiples...');
  // Glisser 5 éléments rapidement
  
  // 3. Tester réorganisation
  console.log('[TEST] Test réorganisation...');
  // Déplacer des éléments dans la playlist
  
  // 4. Tester cas limite
  console.log('[TEST] Test cas limite...');
  // Actions rapides, interruptions, etc.
  
  console.log('[TEST] Test de régression terminé');
};
```

## 📋 Checklist de résolution

### Avant de creuser plus profond

- [ ] **Reproduire** le problème de manière consistante
- [ ] **Capturer** les logs de l'occurrence du problème
- [ ] **Identifier** le pattern dans les logs
- [ ] **Localiser** le code responsable

### Pendant l'investigation

- [ ] **Isoler** le composant problématique (frontend vs backend)
- [ ] **Tracer** le flux de données étape par étape
- [ ] **Vérifier** les assumptions sur l'état
- [ ] **Tester** les cas de bord

### Après la correction

- [ ] **Vérifier** que les logs montrent le comportement attendu
- [ ] **Tester** les scénarios de régression
- [ ] **Documenter** la cause et la solution
- [ ] **Mettre à jour** les tests si nécessaire

## 🚀 Outils avancés

### 1. Profiling de performance

```typescript
// Performance monitor
const performanceMonitor = {
  start: (operation: string) => {
    performance.mark(`${operation}-start`);
  },
  
  end: (operation: string) => {
    performance.mark(`${operation}-end`);
    performance.measure(operation, `${operation}-start`, `${operation}-end`);
    
    const measure = performance.getEntriesByName(operation, 'measure')[0];
    if (measure.duration > 100) {
      console.warn(`[PERF] ${operation} took ${measure.duration.toFixed(2)}ms`);
    }
  }
};

// Usage
performanceMonitor.start('addToQueue');
await addToQueue(items);
performanceMonitor.end('addToQueue');
```

### 2. État tracker

```typescript
// Tracker d'état pour détecter les incohérences
const stateTracker = {
  lastKnownState: null as QueueState | null,
  
  track: (newState: QueueState, source: string) => {
    if (this.lastKnownState) {
      const diff = this.compare(this.lastKnownState, newState);
      if (diff.length > 0) {
        console.log(`[STATE] Changement détecté via ${source}:`, diff);
      }
    }
    this.lastKnownState = { ...newState };
  },
  
  compare: (oldState: QueueState, newState: QueueState) => {
    const differences = [];
    if (oldState.items.length !== newState.items.length) {
      differences.push(`items: ${oldState.items.length} -> ${newState.items.length}`);
    }
    if (oldState.currentIndex !== newState.currentIndex) {
      differences.push(`currentIndex: ${oldState.currentIndex} -> ${newState.currentIndex}`);
    }
    return differences;
  }
};
```

### 3. Event recorder

```typescript
// Enregistrer tous les événements pour replay
const eventRecorder = {
  events: [] as Array<{timestamp: number, type: string, data: any}>,
  recording: false,
  
  start: () => {
    this.recording = true;
    this.events = [];
    console.log('[RECORDER] Enregistrement démarré');
  },
  
  record: (type: string, data: any) => {
    if (this.recording) {
      this.events.push({
        timestamp: Date.now(),
        type,
        data: JSON.parse(JSON.stringify(data))
      });
    }
  },
  
  stop: () => {
    this.recording = false;
    console.log('[RECORDER] Enregistrement arrêté, événements:', this.events.length);
    return this.events;
  },
  
  export: () => {
    const blob = new Blob([JSON.stringify(this.events, null, 2)], 
                         { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `events-${Date.now()}.json`;
    a.click();
  }
};
```

## 📞 Escalade et support

### Niveaux d'escalade

1. **Niveau 1** : Auto-résolution avec ce guide (< 1h)
2. **Niveau 2** : Consultation documentation technique (< 4h)
3. **Niveau 3** : Analyse de code approfondie (< 1 jour)
4. **Niveau 4** : Refactoring/réécriture partielle (> 1 jour)

### Informations à collecter pour l'escalade

- **Logs complets** de reproduction du problème
- **Version** du code et dépendances
- **Environnement** (OS, Node.js, Electron version)
- **Étapes de reproduction** détaillées
- **Fréquence** du problème
- **Impact** sur l'utilisateur

---

**Dernière mise à jour** : Septembre 2025  
**Auteur** : Équipe développement  
**Version** : 1.0
