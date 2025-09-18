# Architecture du Système de Playlist - Guide Technique

## 📋 Vue d'ensemble

Ce document décrit l'architecture complète du système de playlist, les interactions entre les composants, et les patterns à suivre pour maintenir la cohérence.

## 🏗️ Architecture Globale

```
┌─────────────────┐    IPC Events    ┌──────────────────┐
│   Frontend      │ ◄──────────────► │    Backend       │
│ (Renderer)      │                  │    (Main)        │
├─────────────────┤                  ├──────────────────┤
│ ControlWindow   │                  │ ipcQueue.ts      │
│ - État UI       │                  │ - Queue logic    │
│ - Drag & Drop   │                  │ - Persistence    │
│ - Event handlers│                  │ - State mgmt     │
└─────────────────┘                  └──────────────────┘
```

## 🔄 Flux de données

### 1. Ajout d'éléments à la playlist

```
User Action (Drag & Drop)
         ↓
Frontend: handleDrop()
         ↓
Frontend: addToQueue()
         ↓
IPC: electron.queue.addMany()
         ↓
Backend: ipcQueue.addMany()
         ↓
Backend: Persist + Update State
         ↓
IPC Response: New Queue State
         ↓
Frontend: setQueue(newState)
         ↓
UI Update
```

### 2. Réorganisation de la playlist

```
User Action (Drag within playlist)
         ↓
Frontend: handlePlaylistDrop()
         ↓
IPC: electron.queue.reorder()
         ↓
Backend: ipcQueue.reorder()
         ↓
Backend: Recompute positions
         ↓
IPC Response: Updated Queue
         ↓
Frontend: setQueue(result)
         ↓
UI Update
```

## 📁 Structure des fichiers

### Frontend (`src/renderer/modules/ControlWindowClean.tsx`)

```typescript
// États principaux
const [queue, setQueue] = useState<QueueState>({
  items: QueueItem[],           // Liste des éléments
  currentIndex: number,         // Index de lecture actuel
  isPlaying: boolean,           // État de lecture
  isPaused: boolean,            // État de pause
  repeatMode: 'none'|'one'|'all', // Mode de répétition
  shuffleMode: boolean          // Mode aléatoire
});

// États de drag & drop
const [draggedItem, setDraggedItem] = useState<number | null>(null);
const [draggedFromCatalog, setDraggedFromCatalog] = useState<MediaEntry | null>(null);
const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);
const [dragRefreshKey, setDragRefreshKey] = useState<number>(0);
const isDropInProgress = useRef<boolean>(false);

// Fonctions principales
- loadQueue()           // Charger l'état depuis le backend
- addToQueue()          // Ajouter des éléments
- handleDrop()          // Gérer drop depuis catalogue
- handlePlaylistDrop()  // Gérer drop dans playlist
- resetDragState()      // Reset des états de drag
```

### Backend (`src/main/ipcQueue.ts`)

```typescript
// État global
let queueState: QueueState = {
  items: [],
  currentIndex: -1,
  isPlaying: false,
  isPaused: false,
  repeatMode: 'none',
  shuffleMode: false
};

// Handlers IPC
- 'queue:get'         // Récupérer l'état actuel
- 'queue:add'         // Ajouter un élément
- 'queue:addMany'     // Ajouter plusieurs éléments
- 'queue:remove'      // Supprimer un élément
- 'queue:clear'       // Vider la queue
- 'queue:reorder'     // Réorganiser les éléments
- 'queue:next'        // Passer au suivant
- 'queue:previous'    // Passer au précédent
```

## 🎯 Patterns et Conventions

### 1. Pattern de synchronisation état

**Règle d'or** : Le backend est toujours la source de vérité

```typescript
// ✅ CORRECT : Utiliser la réponse du backend
const result = await electron?.queue?.addMany?.(items);
if (result) {
  setQueue(result); // État cohérent garanti
}

// ❌ INCORRECT : Modifier l'état local puis espérer sync
setQueue(prev => ({ ...prev, items: [...prev.items, ...newItems] }));
await electron?.queue?.addMany?.(items);
```

### 2. Pattern de gestion d'erreurs

```typescript
const addToQueue = async (items: MediaEntry[]) => {
  try {
    console.log('[FRONTEND] ⚠️ addToQueue appelé avec:', items.length, 'items');
    
    const result = await electron?.queue?.addMany?.(items);
    if (result) {
      setQueue(result);
      console.log('[FRONTEND] ✅ Queue mise à jour avec succès');
    } else {
      console.warn('[FRONTEND] ❌ Pas de réponse du backend');
      await loadQueue(); // Fallback: recharger depuis backend
    }
  } catch (error) {
    console.error('[FRONTEND] ❌ Erreur addToQueue:', error);
    await loadQueue(); // Fallback: recharger depuis backend
  }
};
```

### 3. Pattern de protection événements

```typescript
// Protection contre événements multiples
const isOperationInProgress = useRef<boolean>(false);

const protectedOperation = async () => {
  if (isOperationInProgress.current) {
    console.log('[PROTECTION] Opération ignorée - déjà en cours');
    return;
  }
  
  try {
    isOperationInProgress.current = true;
    // ... opération
  } finally {
    setTimeout(() => {
      isOperationInProgress.current = false;
    }, 100); // Délai de sécurité
  }
};
```

## 🔍 Types de données

### QueueItem
```typescript
type QueueItem = {
  id: string;                    // Identifiant unique
  title: string;                 // Titre du média
  durationMs?: number | null;    // Durée en millisecondes
  source: 'asset' | 'vault';     // Source du fichier
  src?: string;                  // URL/path du fichier
  mediaId?: string;              // ID du média original
};
```

### QueueState
```typescript
type QueueState = {
  items: QueueItem[];            // Liste des éléments
  currentIndex: number;          // Index actuel (-1 si aucun)
  isPlaying: boolean;            // En cours de lecture
  isPaused: boolean;             // En pause
  repeatMode: 'none'|'one'|'all'; // Mode de répétition
  shuffleMode: boolean;          // Mode aléatoire
};
```

### MediaEntry (Catalogue)
```typescript
type MediaEntry = {
  id: string;                    // Identifiant unique
  title: string;                 // Titre du média
  artist?: string;               // Artiste
  genre?: string;                // Genre musical
  year?: number;                 // Année
  durationMs?: number | null;    // Durée
  source: 'asset' | 'vault';     // Source
  src?: string;                  // URL/path
  mediaId?: string;              // ID média
};
```

## 📋 Conventions de nommage

### Fonctions
- `load*()` : Charger des données depuis le backend
- `handle*()` : Gestionnaires d'événements UI
- `add*()` : Ajouter des éléments
- `remove*()` : Supprimer des éléments
- `reset*()` : Réinitialiser des états

### Variables d'état
- `*State` : État principal (ex: `queueState`)
- `dragged*` : États de drag & drop
- `is*InProgress` : Flags de protection
- `*Index` : Index/positions
- `*Key` : Clés de refresh/rerender

### Logs
- `[FRONTEND]` : Actions frontend
- `[BACKEND]` : Actions backend
- `[IPC]` : Communications IPC
- `[DRAG]` : Drag & drop
- `[QUEUE]` : Opérations queue
- `[PROTECTION]` : Mécanismes de protection

## ⚠️ Pièges courants à éviter

### 1. Mutation directe d'état

```typescript
// ❌ INCORRECT : Mutation directe
queue.items.push(newItem);
setQueue(queue);

// ✅ CORRECT : Nouvel objet
setQueue(prev => ({
  ...prev,
  items: [...prev.items, newItem]
}));
```

### 2. Oubli de cleanup

```typescript
// ❌ INCORRECT : Pas de cleanup
useEffect(() => {
  window.addEventListener('drop', handler);
}, []);

// ✅ CORRECT : Avec cleanup
useEffect(() => {
  window.addEventListener('drop', handler);
  return () => window.removeEventListener('drop', handler);
}, []);
```

### 3. Dépendances manquantes

```typescript
// ❌ INCORRECT : Dépendances manquantes
const callback = useCallback(() => {
  doSomethingWith(externalValue);
}, []); // externalValue pas dans les deps

// ✅ CORRECT : Dépendances complètes
const callback = useCallback(() => {
  doSomethingWith(externalValue);
}, [externalValue]);
```

## 🧪 Guide de test

### Tests unitaires requis

1. **Queue Operations**
   - Ajout d'éléments uniques
   - Ajout d'éléments multiples
   - Suppression d'éléments
   - Réorganisation

2. **Drag & Drop**
   - Drag depuis catalogue
   - Drag dans playlist
   - Protection contre drops multiples
   - Gestion des interruptions

3. **Synchronisation**
   - Cohérence frontend/backend
   - Gestion des erreurs réseau
   - Fallbacks appropriés

### Tests d'intégration

1. **Scénarios utilisateur complets**
   - Créer une playlist de A à Z
   - Réorganiser une playlist existante
   - Gérer des erreurs/interruptions

2. **Performance**
   - Playlists longues (100+ éléments)
   - Operations rapides/multiples
   - Utilisation mémoire

## 📊 Métriques de qualité

### Code Quality
- **Coverage** : > 80% sur les fonctions critiques
- **Complexity** : Fonctions < 20 lignes cyclomatiques
- **Documentation** : Toutes les fonctions publiques documentées

### Performance
- **Latence** : Opérations UI < 100ms
- **Mémoire** : Pas de fuites détectées
- **CPU** : < 5% d'utilisation continue

### Robustesse
- **Erreurs** : Gestion gracieuse des cas d'erreur
- **Edge cases** : Validation des entrées utilisateur
- **État cohérent** : Synchronisation frontend/backend

---

**Dernière mise à jour** : Septembre 2025
**Version** : 1.0
