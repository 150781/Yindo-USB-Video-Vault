# USB Video Vault - Documentation Complète du Système

## 📋 Vue d'ensemble du projet

**USB Video Vault** est une application Electron permettant la gestion et la lecture de contenus vidéo/audio avec un système de vault sécurisé et de licensing. L'application fonctionne sur clé USB avec un système de protection par licence.

### 🎯 Fonctionnalités principales

1. **Système de Playlist Intelligent**
   - Drag & drop depuis catalogue vers playlist
   - Réorganisation par glisser-déposer dans la playlist
   - Support des doublons volontaires
   - Protection contre les doublons involontaires

2. **Lecteur Multimédia Intégré**
   - Lecture vidéo/audio
   - Contrôles play/pause/stop/next/previous
   - Gestion du volume avec mute
   - Modes de répétition (none/one/all)

3. **Système de Vault Sécurisé**
   - Chiffrement des médias (.enc)
   - Protocoles personnalisés (asset://, vault://)
   - Licensing avec validation

4. **Interface Dual-Window**
   - Fenêtre de contrôle (catalogue + playlist + contrôles)
   - Fenêtre d'affichage (lecture plein écran)

## 🏗️ Architecture Technique

### Structure des fichiers

```
src/
├── main/                          # Processus principal Electron
│   ├── index.ts                   # Point d'entrée principal
│   ├── windows.ts                 # Gestion des fenêtres
│   ├── ipc.ts                     # Handlers IPC généraux
│   ├── ipcQueue.ts               # ⭐ Logique playlist/queue
│   ├── ipcQueueStats.ts          # Statistiques d'écoute
│   ├── vault.ts                  # Gestion du vault sécurisé
│   ├── license.ts                # Validation de licence
│   ├── manifest.ts               # Gestion du manifeste
│   ├── protocol.ts               # Protocoles asset:// et vault://
│   ├── playbackAuth.ts           # Autorisation de lecture
│   └── preload.ts                # Script de préchargement
│
├── renderer/                      # Interface utilisateur
│   ├── index.html                # Page principale
│   ├── display.html              # Page d'affichage
│   ├── main_control.tsx          # Point d'entrée contrôle
│   ├── main_display.tsx          # Point d'entrée affichage
│   └── modules/
│       ├── ControlWindowClean.tsx # ⭐ Interface principale
│       └── DisplayApp.tsx        # Interface d'affichage
│
├── shared/                        # Code partagé
│   ├── device.ts                 # Gestion périphériques
│   └── keys/                     # Gestion cryptographique
│
└── types/                         # Définitions TypeScript
    ├── electron-api.d.ts         # API Electron exposée
    └── shared.ts                 # Types partagés
```

### 🔄 Architecture de communication

```
┌─────────────────────┐    IPC     ┌─────────────────────┐
│   Renderer Process  │ ◄────────► │    Main Process     │
│                     │            │                     │
│  ControlWindowClean │            │   ipcQueue.ts       │
│  - Interface UI     │            │   - Queue logic     │
│  - Drag & Drop      │            │   - State mgmt      │
│  - Event handlers   │            │   - Persistence     │
│                     │            │                     │
│  DisplayApp         │            │   protocol.ts       │
│  - Video player     │            │   - asset://        │
│  - Plein écran      │            │   - vault://        │
└─────────────────────┘            └─────────────────────┘
        │                                     │
        └─────────────── preload.ts ──────────┘
                    (API bridge sécurisé)
```

## 🎵 Système de Playlist - Fonctionnalités Détaillées

### Interface utilisateur (ControlWindowClean.tsx)

**Zones principales** :
- **Catalogue de médias** (gauche) : Liste des fichiers disponibles
- **Playlist active** (droite) : Queue de lecture actuelle
- **Contrôles de lecture** (bas) : Play/pause, volume, modes

**États de l'interface** :
```typescript
// État principal de la queue
const [queue, setQueue] = useState<QueueState>({
  items: QueueItem[],              // Éléments de la playlist
  currentIndex: number,            // Index en cours de lecture
  isPlaying: boolean,              // État de lecture
  isPaused: boolean,               // État de pause
  repeatMode: 'none'|'one'|'all',  // Mode de répétition
  shuffleMode: boolean             // Mode aléatoire
});

// États du drag & drop
const [draggedItem, setDraggedItem] = useState<number | null>(null);
const [draggedFromCatalog, setDraggedFromCatalog] = useState<MediaEntry | null>(null);
const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);
const isDropInProgress = useRef<boolean>(false); // Protection anti-double-drop
```

### Fonctionnalités de Drag & Drop

#### 1. Drag depuis le catalogue vers playlist
```typescript
const handleDrop = useCallback(async (e: React.DragEvent) => {
  e.preventDefault();
  
  // Protection contre drops multiples
  if (isDropInProgress.current) {
    console.log('[DRAG] 🚫 Drop ignoré car un drop est déjà en cours');
    return;
  }
  
  try {
    isDropInProgress.current = true;
    
    const data = e.dataTransfer.getData("application/json");
    if (data) {
      const items = JSON.parse(data);
      if (Array.isArray(items) && items.length > 0) {
        await addToQueue(items); // Ajout via backend
      }
    }
    
    resetDragState();
  } finally {
    setTimeout(() => {
      isDropInProgress.current = false;
    }, 100);
  }
}, []);
```

#### 2. Réorganisation dans la playlist
```typescript
const handlePlaylistDrop = useCallback(async (e: React.DragEvent, dropIndex: number) => {
  e.preventDefault();
  e.stopPropagation();
  
  // Protection contre drops multiples
  if (isDropInProgress.current) return;
  
  try {
    isDropInProgress.current = true;
    
    // Réorganisation via backend
    const result = await electron?.queue?.reorder?.(draggedIndex, dropIndex);
    if (result) {
      setQueue(result); // Synchronisation avec backend
    }
  } finally {
    resetDragState();
    setTimeout(() => {
      isDropInProgress.current = false;
    }, 100);
  }
}, []);
```

### Logique Backend (ipcQueue.ts)

**État global de la queue** :
```typescript
let queueState: QueueState = {
  items: [],
  currentIndex: -1,
  isPlaying: false,
  isPaused: false,
  repeatMode: 'none',
  shuffleMode: false
};
```

**Handlers IPC principaux** :
```typescript
// Ajout d'éléments multiples
ipcMain.handle('queue:addMany', async (event, items: MediaEntry[]) => {
  console.log('[QUEUE] ⚠️ queue:addMany appelé avec:', items.length, 'items');
  
  const queueItems: QueueItem[] = items.map(item => ({
    id: item.id,
    title: item.title,
    durationMs: item.durationMs,
    source: item.source,
    src: item.src,
    mediaId: item.mediaId
  }));
  
  queueState.items.push(...queueItems);
  
  console.log('[QUEUE] ⚠️ queue:addMany - après ajout, queue nouvelle:', queueState.items.length, 'items');
  
  return { ...queueState };
});

// Réorganisation de la playlist
ipcMain.handle('queue:reorder', async (event, fromIndex: number, toIndex: number) => {
  if (fromIndex < 0 || fromIndex >= queueState.items.length) return null;
  if (toIndex < 0 || toIndex >= queueState.items.length) return null;
  
  const item = queueState.items.splice(fromIndex, 1)[0];
  queueState.items.splice(toIndex, 0, item);
  
  // Ajustement de l'index de lecture
  if (queueState.currentIndex === fromIndex) {
    queueState.currentIndex = toIndex;
  } else if (queueState.currentIndex > fromIndex && queueState.currentIndex <= toIndex) {
    queueState.currentIndex--;
  } else if (queueState.currentIndex < fromIndex && queueState.currentIndex >= toIndex) {
    queueState.currentIndex++;
  }
  
  return { ...queueState };
});
```

## 🎮 Système de Lecture Multimédia

### Contrôles de lecture
```typescript
// Contrôles principaux
const playerControl = useCallback(async (action: string, value?: any) => {
  console.log('[control] playerControl appelé - action:', action, 'value:', value);
  
  switch (action) {
    case 'play':
      await electron?.player?.play?.();
      setQueue(prev => ({ ...prev, isPlaying: true, isPaused: false }));
      break;
      
    case 'pause':
      await electron?.player?.pause?.();
      setQueue(prev => ({ ...prev, isPlaying: false, isPaused: true }));
      break;
      
    case 'stop':
      await electron?.player?.stop?.();
      setQueue(prev => ({ ...prev, isPlaying: false, isPaused: false }));
      break;
      
    case 'next':
      await electron?.queue?.next?.();
      await loadQueue(); // Recharger l'état
      break;
      
    case 'previous':
      await electron?.queue?.previous?.();
      await loadQueue();
      break;
  }
}, [electron, loadQueue]);
```

### Gestion du volume
```typescript
const [volume, setVolume] = useState<number>(1.0);
const [isMuted, setIsMuted] = useState<boolean>(false);

const toggleMute = useCallback(async () => {
  if (isMuted) {
    // Réactiver le son
    await electron?.player?.setVolume?.(volume);
    setIsMuted(false);
  } else {
    // Couper le son
    setPreviousVolume(volume);
    await electron?.player?.setVolume?.(0);
    setIsMuted(true);
  }
}, [electron, volume, isMuted]);
```

## 🔐 Système de Vault et Sécurité

### Protocoles personnalisés
```typescript
// protocol.ts - Gestion des protocoles asset:// et vault://

// Protocole pour les assets locaux
protocol.handle('asset', async (request) => {
  const url = new URL(request.url);
  const relativePath = decodeURIComponent(url.pathname);
  const fullPath = path.join(ASSETS_DIR, relativePath);
  
  console.log('[protocol asset] résolution:', relativePath, '->', fullPath);
  
  return net.fetch(`file://${fullPath}`);
});

// Protocole pour les fichiers du vault chiffrés
protocol.handle('vault', async (request) => {
  const url = new URL(request.url);
  const mediaId = url.pathname.substring(1); // Enlever le '/' initial
  
  const mediaInfo = await getVaultMediaInfo(mediaId);
  if (!mediaInfo) {
    throw new Error(`Média vault non trouvé: ${mediaId}`);
  }
  
  // Déchiffrement et streaming du contenu
  return streamDecryptedMedia(mediaInfo);
});
```

### Chiffrement des médias
```typescript
// vault.ts - Gestion du vault sécurisé

export const encryptMediaFile = async (inputPath: string, outputPath: string): Promise<void> => {
  // Chiffrement AES du fichier média
  const cipher = crypto.createCipher('aes-256-cbc', VAULT_KEY);
  const input = fs.createReadStream(inputPath);
  const output = fs.createWriteStream(outputPath);
  
  input.pipe(cipher).pipe(output);
};

export const decryptMediaFile = async (encryptedPath: string): Promise<Buffer> => {
  // Déchiffrement pour la lecture
  const decipher = crypto.createDecipher('aes-256-cbc', VAULT_KEY);
  const encryptedData = fs.readFileSync(encryptedPath);
  
  return Buffer.concat([decipher.update(encryptedData), decipher.final()]);
};
```

## 📊 Types de Données Principales

### QueueItem
```typescript
type QueueItem = {
  id: string;                    // Identifiant unique
  title: string;                 // Titre du média
  durationMs?: number | null;    // Durée en millisecondes
  source: 'asset' | 'vault';     // Source du fichier
  src?: string;                  // URL/chemin du fichier
  mediaId?: string;              // ID du média original
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
  src?: string;                  // URL/chemin
  mediaId?: string;              // ID média
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

## 🛠️ Innovations et Solutions Techniques

### 1. Protection contre les doublons involontaires
**Problème résolu** : Le drag & drop créait des doublons à cause d'événements multiples
**Solution** : Protection avec flag `isDropInProgress.current`
```typescript
const isDropInProgress = useRef<boolean>(false);

// Dans chaque handler de drop
if (isDropInProgress.current) {
  console.log('[DRAG] 🚫 Drop ignoré car un drop est déjà en cours');
  return;
}
```

### 2. Synchronisation d'état Frontend/Backend
**Principe** : Le backend est toujours la source de vérité
```typescript
// ✅ CORRECT : Utiliser la réponse du backend
const result = await electron?.queue?.addMany?.(items);
if (result) {
  setQueue(result); // État cohérent garanti
}

// ❌ INCORRECT : Modifier l'état local puis espérer sync
setQueue(prev => ({ ...prev, items: [...prev.items, ...newItems] }));
```

### 3. Logging structuré pour debugging
```typescript
// Conventions de logging
console.log('[DRAG] 🎬 Catalogue - DragStart pour:', item.title);
console.log('[DRAG] 📋 Drop sur zone playlist');
console.log('[FRONTEND] ⚠️ addToQueue appelé avec:', items.length, 'items');
console.log('[QUEUE] ⚠️ queue:addMany appelé avec:', items.length, 'items');

// Prefixes : [DRAG], [FRONTEND], [QUEUE], [BACKEND]
// Emojis : 🎬 (catalogue), 📋 (playlist), 🚫 (bloqué), ⚠️ (debug)
```

### 4. Gestion gracieuse des erreurs
```typescript
const addToQueue = async (items: MediaEntry[]) => {
  try {
    const result = await electron?.queue?.addMany?.(items);
    if (result) {
      setQueue(result);
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

## 🎨 Interface Utilisateur

### Fenêtre de contrôle (ControlWindowClean.tsx)
- **Layout responsive** avec Tailwind CSS
- **Drag & Drop visuel** avec zones de drop highlightées
- **États visuels** pour les éléments draggés/survolés
- **Contrôles intuitifs** pour lecture/volume

### Fenêtre d'affichage (DisplayApp.tsx)
- **Lecture plein écran** des vidéos
- **Overlay de contrôles** discret
- **Synchronisation** avec la fenêtre de contrôle

## 🔧 Outils de Développement

### Build et développement
```bash
# Build complet
npm run build

# Build renderer seulement
npm run build:renderer

# Build main seulement  
npm run build:main

# Lancement avec logs
npx electron dist/main/index.js --enable-logging
```

### Scripts utiles
```bash
# Nettoyage des processus
taskkill /F /IM electron.exe

# Tests de performance
npm run test:performance

# Validation de la playlist
npm run test:playlist
```

## 📈 Métriques et Performance

### Critères de qualité
- **Latence UI** : < 100ms pour toutes les interactions
- **Synchronisation** : État frontend === état backend
- **Mémoire** : Pas de fuites d'event listeners
- **Logs** : Aucun doublon involontaire détecté

### Monitoring
```typescript
// Performance monitoring intégré
const performanceMonitor = {
  start: (operation: string) => performance.mark(`${operation}-start`),
  end: (operation: string) => {
    performance.mark(`${operation}-end`);
    const measure = performance.measure(operation, `${operation}-start`, `${operation}-end`);
    if (measure.duration > 100) {
      console.warn(`[PERF] ${operation} took ${measure.duration.toFixed(2)}ms`);
    }
  }
};
```

## 🚀 Déploiement et Distribution

### Structure de déploiement USB
```
USB-Video-Vault/
├── USB-Video-Vault-0.1.0-portable.exe    # Exécutable principal
├── launch.bat                             # Script de lancement
├── README.md                              # Instructions utilisateur
└── vault/                                 # Dossier vault chiffré
    ├── media/                             # Fichiers .enc chiffrés
    │   ├── [uuid].enc                     # Médias chiffrés
    │   └── manifest.json                  # Manifeste des médias
    └── keys/                              # Clés de déchiffrement
        └── vault.key                      # Clé principale
```

### Système de licensing
- **Validation au démarrage** via `license.ts`
- **Binding périphérique** avec l'ID de la clé USB
- **Expiration temporelle** configurable
- **Protection anti-copie** intégrée

## 🧪 Tests et Validation

### Tests manuels obligatoires
1. **Test drag & drop basique** : Catalogue → Playlist
2. **Test réorganisation** : Déplacement dans playlist
3. **Test doublons volontaires** : Même fichier 3x
4. **Test protection** : Actions rapides/multiples
5. **Test lecture** : Play/pause/next/previous
6. **Test volume** : Contrôles audio + mute

### Validation automatique
```typescript
// Tests de régression intégrés
const regressionTest = async () => {
  console.log('[TEST] Début test de régression...');
  
  // 1. Test ajout simple
  await testSingleAdd();
  
  // 2. Test ajouts multiples  
  await testMultipleAdd();
  
  // 3. Test réorganisation
  await testReorder();
  
  console.log('[TEST] Test de régression terminé');
};
```

## 📚 Documentation Disponible

1. **[DRAG_DROP_GUIDE.md](./DRAG_DROP_GUIDE.md)** - Guide drag & drop et prévention erreurs
2. **[PLAYLIST_ARCHITECTURE.md](./PLAYLIST_ARCHITECTURE.md)** - Architecture système playlist
3. **[DEBUG_GUIDE.md](./DEBUG_GUIDE.md)** - Diagnostic et résolution problèmes
4. **[MANUAL_TESTS.md](./MANUAL_TESTS.md)** - Procédures de test manuel

## 🎯 Fonctionnalités Clés Accomplies

### ✅ Système de Playlist Complet
- [x] Drag & drop catalogue → playlist
- [x] Réorganisation par glisser-déposer
- [x] Support doublons volontaires
- [x] Protection anti-doublons involontaires
- [x] Synchronisation frontend/backend robuste

### ✅ Lecteur Multimédia Intégré  
- [x] Lecture vidéo/audio fluide
- [x] Contrôles complets (play/pause/stop/next/prev)
- [x] Gestion volume avec mute
- [x] Modes de répétition

### ✅ Architecture Technique Solide
- [x] Communication IPC sécurisée
- [x] Gestion d'état centralisée
- [x] Logging structuré pour debug
- [x] Gestion d'erreurs gracieuse

### ✅ Sécurité et Protection
- [x] Système de vault chiffré
- [x] Protocoles personnalisés (asset://, vault://)
- [x] Licensing avec validation
- [x] Protection anti-copie

### ✅ Documentation Complète
- [x] Architecture système documentée
- [x] Guide des bonnes pratiques
- [x] Procédures de debug
- [x] Tests de validation

## 🔮 Évolutions Futures

### Prochaines versions
- **V1.1** : Tests automatisés du drag & drop
- **V1.2** : Interface d'administration vault
- **V1.3** : Support multi-sélection drag & drop
- **V1.4** : Streaming réseau sécurisé

### Améliorations techniques
- Migration vers TypeScript strict
- Optimisation mémoire pour grandes playlists
- Cache intelligent des métadonnées
- Interface responsive pour tablettes

---

**Date de création** : Septembre 2025  
**Version de l'application** : 1.0  
**Version de la documentation** : 1.0  
**Auteur** : Équipe de développement USB Video Vault  

**Note** : Ce document constitue la référence complète du système. Il doit être mis à jour à chaque évolution majeure de l'architecture ou des fonctionnalités.
