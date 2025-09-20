# Guide Drag & Drop - Bonnes Pratiques et Prévention des Erreurs

## 📋 Table des Matières
1. [Vue d'ensemble](#vue-densemble)
2. [Architecture du système](#architecture-du-système)
3. [Problèmes courants et solutions](#problèmes-courants-et-solutions)
4. [Bonnes pratiques](#bonnes-pratiques)
5. [Guide de débogage](#guide-de-débogage)
6. [Checklist de validation](#checklist-de-validation)

## 🎯 Vue d'ensemble

Le système de drag & drop de l'application permet de :
- Glisser des éléments du catalogue vers la playlist
- Réorganiser les éléments dans la playlist
- Permettre les doublons volontaires tout en évitant les doublons involontaires

### Composants impliqués
- **Frontend** : `ControlWindowClean.tsx` - Gestion UI et événements drag & drop
- **Backend** : `ipcQueue.ts` - Logique métier et persistance de la queue
- **IPC** : Communication entre frontend et backend via Electron

## 🏗️ Architecture du système

### Frontend (ControlWindowClean.tsx)
```typescript
// États de drag & drop
const [draggedItem, setDraggedItem] = useState<number | null>(null);           // Index de l'élément draggé dans la playlist
const [draggedFromCatalog, setDraggedFromCatalog] = useState<MediaEntry | null>(null); // Élément draggé depuis le catalogue
const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);      // Index de survol actuel
const isDropInProgress = useRef<boolean>(false);                             // Protection contre drops multiples
```

### Backend (ipcQueue.ts)
```typescript
// Méthodes principales
- queue:add        // Ajouter UN élément
- queue:addMany    // Ajouter PLUSIEURS éléments
- queue:reorder    // Réorganiser la playlist
- queue:get        // Récupérer l'état actuel
```

## ⚠️ Problèmes courants et solutions

### 1. Doublons involontaires lors du drag & drop

**Symptôme** : Un seul drag produit deux éléments identiques dans la playlist

**Cause** : Plusieurs gestionnaires d'événements réagissent au même drop
```javascript
// PROBLÈME : Deux handlers reçoivent le même événement drop
[DRAG] 📋 Drop sur zone playlist - Type de drag: {draggedItem: null, draggedFromCatalog: null}
[DRAG] 📋 Drop sur zone playlist - Type de drag: {draggedItem: null, draggedFromCatalog: null} // ← DOUBLON !
```

**Solution** : Protection avec flag de drop en cours
```typescript
const isDropInProgress = useRef<boolean>(false);

const handleDrop = useCallback(async (e: React.DragEvent) => {
  e.preventDefault();
  
  // Protection contre les drops multiples
  if (isDropInProgress.current) {
    console.log('[DRAG] 🚫 Drop ignoré car un drop est déjà en cours');
    return;
  }
  
  try {
    isDropInProgress.current = true;
    // ... logique de drop
  } finally {
    setTimeout(() => {
      isDropInProgress.current = false;
    }, 100);
  }
}, []);
```

### 2. État incohérent entre frontend et backend

**Symptôme** : L'UI ne reflète pas l'état réel de la queue

**Cause** : État local non synchronisé avec le backend

**Solution** : Toujours utiliser le backend comme source de vérité
```typescript
// ✅ BON : Utiliser le résultat du backend
const result = await electron?.queue?.addMany?.(items);
if (result) {
  setQueue(result); // Utiliser directement la réponse du backend
}

// ❌ MAUVAIS : Modifier l'état local puis sync
setQueue(prev => ({ ...prev, items: [...prev.items, ...newItems] })); // État peut diverger
```

### 3. Memory leaks dans les event listeners

**Symptôme** : Performance dégradée, comportements erratiques

**Cause** : Event listeners non nettoyés

**Solution** : Cleanup approprié
```typescript
useEffect(() => {
  const handleGlobalDrop = (e: DragEvent) => {
    // Prévenir les drops sur la fenêtre globale
    e.preventDefault();
  };
  
  window.addEventListener('drop', handleGlobalDrop);
  window.addEventListener('dragover', handleGlobalDrop);
  
  return () => {
    window.removeEventListener('drop', handleGlobalDrop);
    window.removeEventListener('dragover', handleGlobalDrop);
  };
}, []);
```

## 📋 Bonnes pratiques

### 1. Gestion des événements

```typescript
// ✅ Toujours prévenir le comportement par défaut
const handleDrop = (e: React.DragEvent) => {
  e.preventDefault();
  e.stopPropagation(); // Empêcher la propagation si nécessaire
};

// ✅ Utiliser des callbacks avec dépendances appropriées
const handleDrop = useCallback(async (e: React.DragEvent) => {
  // ... logique
}, [electron, loadQueue, draggedItem]); // Dépendances explicites
```

### 2. Logging et débogage

```typescript
// ✅ Logs structurés avec prefixes
console.log('[DRAG] 🎬 Catalogue - DragStart pour:', item.title);
console.log('[DRAG] 📋 Drop sur zone playlist');
console.log('[DRAG] 🚫 Drop ignoré car un drop est déjà en cours');
console.log('[FRONTEND] ⚠️ addToQueue appelé avec:', items.length, 'items');
```

**Conventions de logging** :
- `[DRAG]` : Événements de drag & drop
- `[FRONTEND]` : Actions frontend
- `[QUEUE]` : Actions backend queue
- `🎬` : Actions catalogue
- `📋` : Actions playlist
- `🚫` : Actions bloquées/ignorées
- `⚠️` : Avertissements/debug

### 3. Gestion d'état

```typescript
// ✅ État minimal et dérivé
const [queue, setQueue] = useState<QueueState>({
  items: [],
  currentIndex: -1,
  isPlaying: false,
  isPaused: false,
  repeatMode: 'none',
  shuffleMode: false
});

// ✅ Reset propre des états
const resetDragState = useCallback(() => {
  setDraggedItem(null);
  setDraggedFromCatalog(null);
  setDragOverIndex(null);
  setDragRefreshKey(prev => prev + 1);
  console.log('[DRAG] 🔄 Reset drag state - all types');
}, []);
```

### 4. Validation des données

```typescript
// ✅ Validation avant traitement
const handleDrop = async (e: React.DragEvent) => {
  try {
    const data = e.dataTransfer.getData("application/json");
    if (!data) return;
    
    const items = JSON.parse(data);
    if (!Array.isArray(items) || items.length === 0) {
      console.warn('[DRAG] Données invalides:', items);
      return;
    }
    
    // Traitement...
  } catch (error) {
    console.warn('[DRAG] Erreur parsing:', error);
  }
};
```

## 🔍 Guide de débogage

### 1. Activation des logs de debug

Lors du développement, activez tous les logs :
```bash
# Lancer avec logs détaillés
npx electron dist/main/index.js --enable-logging
```

### 2. Analyse des patterns de logs

**Pattern normal (drag réussi)** :
```
[DRAG] 🎬 Catalogue - DragStart pour: Nom du fichier
[DRAG] 🎬 Catalogue - Données de drag définies
[DRAG] 🎬 Catalogue - DragOver sur zone playlist
[DRAG] 📋 Drop sur zone playlist
[DRAG] ⚠️ 📋 Drop depuis catalogue sur espace vide détecté
[FRONTEND] ⚠️ addToQueue appelé avec: 1 items
[QUEUE] ⚠️ queue:addMany appelé avec: 1 items
[DRAG] 🔄 Reset drag state - all types
```

**Pattern problématique (double drop)** :
```
[DRAG] 📋 Drop sur zone playlist
[DRAG] 📋 Drop sur zone playlist  ← DOUBLON DÉTECTÉ
[DRAG] 🚫 Drop ignoré car un drop est déjà en cours  ← PROTECTION ACTIVÉE
```

### 3. Points de contrôle

Vérifiez ces éléments lors du débogage :

1. **Event listeners** : Y a-t-il des listeners multiples ?
2. **État de protection** : `isDropInProgress.current` fonctionne-t-il ?
3. **Propagation** : Les événements sont-ils correctement stoppés ?
4. **Synchronisation** : L'état frontend reflète-t-il le backend ?

### 4. Outils de débogage

```typescript
// Debug helper pour inspecter l'état
const debugState = () => {
  console.log('[DEBUG] État drag:', {
    draggedItem,
    draggedFromCatalog: draggedFromCatalog?.title,
    dragOverIndex,
    isDropInProgress: isDropInProgress.current,
    queueLength: queue.items.length
  });
};

// Appeler avant/après les opérations critiques
```

## ✅ Checklist de validation

### Avant de committer du code drag & drop

- [ ] **Protection contre drops multiples** implémentée
- [ ] **Event listeners** correctement nettoyés
- [ ] **Logs de debug** ajoutés aux points critiques
- [ ] **Validation des données** avant traitement
- [ ] **Tests manuels** avec différents scénarios :
  - [ ] Drag depuis catalogue vers playlist vide
  - [ ] Drag depuis catalogue vers playlist existante
  - [ ] Réorganisation dans la playlist
  - [ ] Drag rapide/multiple
  - [ ] Interruption de drag (Escape, etc.)

### Scénarios de test obligatoires

1. **Test de base** : Glisser 5 éléments différents un par un
2. **Test de stress** : Glisser rapidement plusieurs éléments
3. **Test de réorganisation** : Déplacer des éléments dans la playlist
4. **Test d'interruption** : Commencer un drag puis annuler (Escape)
5. **Test de validation** : Vérifier que les logs ne montrent pas de doublons

### Métriques de qualité

- **Zéro doublon involontaire** dans les logs
- **Synchronisation** : État frontend = état backend
- **Performance** : Pas de lag lors des opérations
- **Robustesse** : Aucun crash sur actions rapides/multiples

## 🚨 Signaux d'alarme

Surveillez ces indicateurs de problèmes :

1. **Logs** : Messages de drop/add multiples pour une seule action utilisateur
2. **État** : Différences entre l'affichage et l'état réel
3. **Performance** : Lenteur lors des drags
4. **Mémoire** : Augmentation continue de l'utilisation mémoire
5. **Comportement** : Actions imprévisibles ou incohérentes

## 📚 Ressources supplémentaires

- [Documentation Electron DnD](https://www.electronjs.org/docs/api/web-contents#webcontentsstartdragitem)
- [React DnD Best Practices](https://react-dnd.github.io/react-dnd/docs/overview)
- [HTML5 Drag and Drop API](https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API)

## 🔄 Historique des corrections

### v1.0 - Correction du double-drop (Sept 2025)
- **Problème** : Drag unique créait des doublons
- **Solution** : Protection `isDropInProgress.current`
- **Impact** : Élimination complète des doublons involontaires
- **Commit** : [À remplir avec le hash du commit]

---

**Note** : Ce document doit être mis à jour à chaque modification du système de drag & drop.
