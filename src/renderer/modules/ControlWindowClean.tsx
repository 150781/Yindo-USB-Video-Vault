/// <reference path="../../types/electron-api.d.ts" />
import React, { useEffect, useMemo, useState, useCallback, useRef } from "react";
import SecurityControl from "./SecurityControl";
import AnalyticsMonitor from "./AnalyticsMonitor";

// Cache local pour les durées détectées
const durationCache: Record<string, number | null> = {};

/**
 * ⚠️ RÈGLE D'OR POUR CE FICHIER :
 * - Aucun hook (useState/useEffect/...) ne doit être dans une condition/loop/return anticipé.
 * - On déclare TOUS les hooks d'abord, puis on fait du rendu conditionnel en JSX à la fin.
 */

// Types réutilisés tels quels
type Source = 'asset' | 'vault';

type MediaEntry = {
  id: string; 
  title: string;
  artist?: string; 
  genre?: string; 
  year?: number;
  durationMs?: number | null;
  source: Source; 
  src?: string; 
  mediaId?: string;
};

type QueueItem = {
  id: string; 
  title: string;
  durationMs?: number | null;
  source: Source; 
  src?: string; 
  mediaId?: string;
};

type QueueState = {
  items: QueueItem[]; 
  currentIndex: number;
  isPlaying: boolean; 
  isPaused: boolean;
  repeatMode: 'none'|'one'|'all'; 
  shuffleMode: boolean;
};

type StatEntry = { 
  id: string; 
  playsCount: number; 
  lastPlayedAt?: string 
};

const ControlWindowClean: React.FC = () => {
  // Protection contre window.electron non défini
  const electron = (window as any)?.electron ?? {};

  // 1) Détection progressive de window.electron (SANS retour anticipé)
  const [electronReady, setElectronReady] = useState<boolean>(!!((window as any)?.electron));

  // 2) États de la UI / données
  const [locked, setLocked] = useState<boolean>(false);
  const [passphrase, setPassphrase] = useState<string>("");

  const [catalogue, setCatalogue] = useState<MediaEntry[]>([]);
  const [stats, setStats] = useState<Record<string, number>>({});
  const [isLoading, setIsLoading] = useState<boolean>(true);

  // Filtres
  const [searchTerm, setSearchTerm] = useState<string>("");
  const [selectedGenre, setSelectedGenre] = useState<string>("Tout");
  const [selectedYear, setSelectedYear] = useState<string>("Toutes");
  const [selectedArtist, setSelectedArtist] = useState<string>("Tous");

  // États playlist et player
  const [queue, setQueue] = useState<QueueState>({
    items: [],
    currentIndex: -1,
    isPlaying: false,
    isPaused: false,
    repeatMode: 'none',
    shuffleMode: false
  });

  // État du volume (0.0 à 1.0)
  const [volume, setVolume] = useState<number>(1.0);
  const [isMuted, setIsMuted] = useState<boolean>(false);
  const [previousVolume, setPreviousVolume] = useState<number>(1.0);

  // États pour le drag and drop de la playlist
  const [draggedItem, setDraggedItem] = useState<number | null>(null);
  const [draggedFromCatalog, setDraggedFromCatalog] = useState<MediaEntry | null>(null);
  const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);
  const [dragRefreshKey, setDragRefreshKey] = useState<number>(0); // Pour forcer le re-rendu
  
  // Protection contre les drops multiples
  const isDropInProgress = useRef<boolean>(false);

  // 4) Effet : surveiller l'apparition de window.electron
  useEffect(() => {
    if (electronReady) return;
    const t = window.setInterval(() => {
      const api = (window as any)?.electron;
      if (api) {
        setElectronReady(true);
        window.clearInterval(t);
      }
    }, 100);
    return () => window.clearInterval(t);
  }, [electronReady]);

  // 4) Effet : pings d'activité (auto-lock)
  useEffect(() => {
    if (!electronReady) return;
    const ping = () => electron?.session?.activity?.();
    const onMove = () => ping();
    const onKey = () => ping();
    window.addEventListener("mousemove", onMove);
    window.addEventListener("keydown", onKey);
    const id = window.setInterval(ping, 15000);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("keydown", onKey);
      window.clearInterval(id);
    };
  }, [electronReady, electron]);

  // 5) Effet : statut licence + auto-lock
  useEffect(() => {
    if (!electronReady) return;

    let offLocked: any;
    // status initial
    (async () => {
      try {
        const st = await electron?.license?.status?.();
        setLocked(!!st?.locked);
      } catch {
        setLocked(false);
      }
    })();

    // subscription lock event
    if (electron?.session?.onLocked) {
      offLocked = electron.session.onLocked(() => setLocked(true));
    }

    return () => {
      if (typeof offLocked === "function") offLocked();
    };
  }, [electronReady, electron]);

  // 6) Chargement catalogue + stats + queue
  const loadStats = useCallback(async () => {
    try {
      const res = await electron?.stats?.get?.();
      
      // Normalisation défensive des stats
      if (Array.isArray(res)) {
        const map = Object.fromEntries(
          res.filter(Boolean).map((x: any) => [x.id, x?.playsCount ?? 0])
        );
        setStats(map);
        return;
      }

      if (res && typeof res === 'object' && Array.isArray((res as any).list)) {
        const map = Object.fromEntries(
          (res as any).list.map((x: any) => [x.id, x?.playsCount ?? 0])
        );
        setStats(map);
        return;
      }

      if (res && typeof res === 'object' && (res as any).byId && typeof (res as any).byId === 'object') {
        const byId = (res as any).byId;
        const map = Object.fromEntries(
          Object.entries(byId).map(([id, v]: any) => {
            // La valeur v est déjà le nombre de vues (number) ou un objet avec une propriété
            const count = typeof v === 'number' ? v : (v?.playsCount ?? v?.count ?? v?.plays ?? 0);
            return [id, count];
          })
        );
        setStats(map);
        return;
      }

      if (res && typeof res === 'object') {
        setStats(res);
        return;
      }
      
      setStats({});
    } catch (e) {
      console.warn('[control] Erreur chargement stats :', e);
      setStats({});
    }
  }, [electron]);

  const loadCatalogue = useCallback(async () => {
    try {
      setIsLoading(true);
      const res = await electron?.catalog?.list?.();
      const list = Array.isArray(res) ? res : res?.list;
      const safe = Array.isArray(list) ? list : [];
      
      // 🔧 CORRIGER : Restaurer les durées depuis le cache AVANT de setter le catalogue
      const catalogueWithCachedDurations = safe.map(entry => {
        if (entry?.id && entry.id in durationCache) {
          return { ...entry, durationMs: durationCache[entry.id] };
        }
        return entry;
      });
      
      setCatalogue(catalogueWithCachedDurations);

      // 🔎 Lancer le probe des durées manquantes sur la liste fraiche
      const missing = catalogueWithCachedDurations.filter(e => e && (e.durationMs == null) && !(e.id in durationCache)).slice(0, 8);
      missing.forEach(async (entry) => {
        const ms = await probeDuration(entry);
        if (ms && ms > 0) {
          durationCache[entry.id] = ms;
          setCatalogue(prev => prev.map(x => x.id === entry.id ? { ...x, durationMs: ms } : x));
        }
      });
    } catch (e) {
      console.warn('[control] Erreur chargement catalogue :', e);
      setCatalogue([]);
    } finally {
      setIsLoading(false);
    }
  }, [electron]);

  // Fonction probeDuration
  async function probeDuration(entry: MediaEntry): Promise<number | null> {
    try {
      if (!entry) return null;
      if (entry.id in durationCache) return durationCache[entry.id];

      return new Promise((resolve) => {
        const v = document.createElement('video');
        v.preload = 'metadata';
        v.muted = true;
        v.onloadedmetadata = () => {
          const ms = isFinite(v.duration) ? Math.round(v.duration * 1000) : 0;
          durationCache[entry.id] = ms || null;
          v.remove();
          resolve(ms || null);
        };
        v.onerror = () => { durationCache[entry.id] = null; v.remove(); resolve(null); };
        v.src = entry.mediaId ? `vault://media/${entry.mediaId}` : (entry.src || '');
      });
    } catch {
      return null;
    }
  }

  const loadQueue = useCallback(async () => {
    try {
      const queueData = await electron?.queue?.get?.();
      if (queueData) {
        setQueue(prev => ({ ...prev, ...queueData }));
      }
    } catch (e) {
      console.warn('[control] Erreur chargement queue :', e);
    }
  }, [electron]);

  useEffect(() => {
    if (!electronReady) return;
    loadStats();
    loadCatalogue();
    loadQueue();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [electronReady]);

  // Persistence du volume dans localStorage
  useEffect(() => {
    // Charger le volume sauvegardé au démarrage
    const savedVolume = localStorage.getItem('yindo-volume');
    const savedMute = localStorage.getItem('yindo-muted');
    
    if (savedVolume !== null) {
      const vol = parseFloat(savedVolume);
      if (!isNaN(vol) && vol >= 0 && vol <= 1) {
        setVolume(vol);
      }
    }
    
    if (savedMute !== null) {
      setIsMuted(savedMute === 'true');
    }
  }, []);

  // Sauvegarder le volume à chaque changement
  useEffect(() => {
    localStorage.setItem('yindo-volume', volume.toString());
  }, [volume]);

  useEffect(() => {
    localStorage.setItem('yindo-muted', isMuted.toString());
  }, [isMuted]);

  // 7) Écoute les métadonnées envoyées par l'écran d'affichage
  useEffect(() => {
    if (!electronReady) return;

    const onMeta = (payload: { id?: string; durationMs?: number }) => {
      if (!payload?.id || !payload?.durationMs) return;
      durationCache[payload.id] = payload.durationMs;
      setCatalogue(prev => prev.map(x => x.id === payload.id ? { ...x, durationMs: payload.durationMs! } : x));
    };

    electron?.ipc?.on?.('player:meta', onMeta);
    return () => electron?.ipc?.off?.('player:meta', onMeta);
  }, [electronReady, electron]);

  // 8) Écoute les mises à jour de statistiques depuis DisplayApp
  useEffect(() => {
    if (!electronReady) return;

    const onStatsUpdated = async (payload: { id?: string }) => {
      console.log('[control] Stats updated reçu pour:', payload.id);
      // Recharger SEULEMENT les stats - pas besoin de recharger le catalogue
      // car les vues sont affichées via getPlays() qui utilise l'état stats
      await loadStats();
      console.log('[control] � Stats rechargés après mise à jour - vues mises à jour');
    };

    electron?.ipc?.on?.('stats:updated', onStatsUpdated);
    return () => electron?.ipc?.off?.('stats:updated', onStatsUpdated);
  }, [electronReady, electron, loadStats]);

  // 9) Écoute les événements de statut de lecture pour synchroniser l'interface
  useEffect(() => {
    if (!electronReady) return;

    const onStatusUpdate = (payload: { isPlaying: boolean; isPaused: boolean; currentTime?: number }) => {
      console.log('[control] Status update reçu:', payload);
      setQueue(prev => ({ 
        ...prev, 
        isPlaying: payload.isPlaying,
        isPaused: payload.isPaused 
      }));
    };

    electron?.ipc?.on?.('player:status:update', onStatusUpdate);
    return () => electron?.ipc?.off?.('player:status:update', onStatusUpdate);
  }, [electronReady, electron]);

  // 8) Actions player et queue
  const playItem = useCallback(async (item: MediaEntry) => {
    try {
      console.log('[control] playItem appelé pour:', item.title);
      await electron?.queue?.playNow?.(item);
      
      // Mettre à jour l'état local pour indiquer qu'une lecture commence
      setQueue(prev => ({ ...prev, isPlaying: true, isPaused: false }));
      console.log('[control] État local mis à jour après playItem - isPlaying: true');
      
      await loadQueue(); // Refresh queue state
    } catch (e) {
      console.warn('[control] Erreur lecture :', e);
    }
  }, [electron, loadQueue]);

  const addToQueue = useCallback(async (items: MediaEntry | MediaEntry[]) => {
    try {
      const itemsArray = Array.isArray(items) ? items : [items];
      console.log('[FRONTEND] ⚠️ addToQueue appelé avec:', itemsArray.length, 'items');
      console.log('[FRONTEND] ⚠️ addToQueue - titres:', itemsArray.map(i => i.title));
      await electron?.queue?.addMany?.(itemsArray);
      await loadQueue(); // Refresh queue state
    } catch (e) {
      console.warn('[control] Erreur ajout queue :', e);
    }
  }, [electron, loadQueue]);

  const removeFromQueue = useCallback(async (index: number) => {
    try {
      await electron?.queue?.removeAt?.(index);
      await loadQueue(); // Refresh queue state
    } catch (e) {
      console.warn('[control] Erreur suppression queue :', e);
    }
  }, [electron, loadQueue]);

  // Fonctions pour le drag and drop de la playlist
  const resetDragState = useCallback(() => {
    console.log('[DRAG] 🔄 Reset drag state - all types');
    setDraggedItem(null);
    setDraggedFromCatalog(null);
    setDragOverIndex(null);
    
    // Forcer un re-rendu des éléments draggables
    setDragRefreshKey(prev => prev + 1);
    
    // Restaurer l'opacité et réactiver le draggable de tous les éléments playlist
    setTimeout(() => {
      const playlistItems = document.querySelectorAll('[data-playlist-item]');
      playlistItems.forEach((element) => {
        const htmlElement = element as HTMLElement;
        htmlElement.style.opacity = '1';
        htmlElement.setAttribute('draggable', 'true');
        // Forcer la mise à jour du style
        htmlElement.style.cursor = 'move';
      });
      console.log('[control] Éléments draggables réactivés:', playlistItems.length);
    }, 50);
  }, []);

  // Réinitialiser l'état de drag quand la playlist change (nouvelles chansons ajoutées)
  useEffect(() => {
    console.log('[control] QUEUE CHANGE DETECTED - Queue items length:', queue.items.length);
    // Réinitialiser le drag state seulement si on a vraiment un drag en cours et que la playlist a changé
    if (queue.items.length > 0 && (draggedItem !== null || dragOverIndex !== null)) {
      console.log('[control] Resetting drag state for new playlist items (drag was active)');
      resetDragState();
    }
  }, [queue.items.length, resetDragState]);

  // Reset d'urgence si quelque chose va mal avec le drag
  useEffect(() => {
    const handleGlobalMouseUp = () => {
      if (draggedItem !== null) {
        console.log('[control] URGENCE - Reset drag state sur mouseup global - draggedItem:', draggedItem);
        setTimeout(() => resetDragState(), 100); // Délai pour laisser le temps aux événements
      }
    };
    
    const handleGlobalDragEnd = (e: DragEvent) => {
      // Ne réagir que si on a vraiment un drag en cours
      if (draggedItem !== null) {
        console.log('[control] URGENCE - Global dragend détecté avec draggedItem:', draggedItem);
        setTimeout(() => resetDragState(), 100);
      }
    };
    
    document.addEventListener('mouseup', handleGlobalMouseUp);
    document.addEventListener('dragend', handleGlobalDragEnd);
    return () => {
      document.removeEventListener('mouseup', handleGlobalMouseUp);
      document.removeEventListener('dragend', handleGlobalDragEnd);
    };
  }, [draggedItem, resetDragState]);

  const handlePlaylistDragStart = useCallback((e: React.DragEvent, index: number) => {
    e.stopPropagation(); // Empêcher la propagation
    console.log('[control] DRAG START TRIGGERED - index:', index, 'current draggedItem:', draggedItem);
    console.log('[control] Playlist items count:', queue.items.length);
    
    // Vérifier que l'index est valide
    if (index < 0 || index >= queue.items.length) {
      console.warn('[control] DRAG START - Index invalide:', index);
      return;
    }
    
    // Vérifier qu'on ne fait pas déjà un drag
    if (draggedItem !== null) {
      console.warn('[control] DRAG START - Drag déjà en cours, ignoré');
      return;
    }
    
    console.log('[control] DRAG START - Initialisation du drag pour index:', index);
    
    // D'abord réinitialiser tout état précédent
    setDraggedItem(null);
    setDragOverIndex(null);
    
    // Attendre un tick avant de définir le nouvel état
    setTimeout(() => {
      console.log('[control] Setting draggedItem to:', index);
      setDraggedItem(index);
    }, 0);
    
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/playlist-item', index.toString());
    
    // Style visuel pendant le drag
    const element = e.currentTarget as HTMLElement;
    element.style.opacity = '0.5';
    
    console.log('[control] DRAG START completed for index:', index);
  }, [draggedItem, queue.items.length]);

  const handlePlaylistDragEnd = useCallback((e: React.DragEvent) => {
    e.stopPropagation(); // Empêcher la propagation
    console.log('[control] DRAG END');
    
    // Utiliser la fonction de reset
    resetDragState();
  }, [resetDragState]);

  const handlePlaylistDragOver = useCallback((e: React.DragEvent, index: number) => {
    e.preventDefault();
    e.stopPropagation(); // Empêcher la propagation
    e.dataTransfer.dropEffect = 'move';
    
    if (draggedItem !== null && draggedItem !== index) {
      console.log('[control] DRAG OVER - draggedItem:', draggedItem, 'targetIndex:', index, 'DROP ZONE ACTIVE');
      setDragOverIndex(index);
    }
  }, [draggedItem]);

  const handlePlaylistDragLeave = useCallback((e: React.DragEvent) => {
    e.stopPropagation(); // Empêcher la propagation
    console.log('[control] DRAG LEAVE');
    // Ne clear que si on quitte vraiment l'élément (pas un enfant)
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const x = e.clientX;
    const y = e.clientY;
    
    if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) {
      setDragOverIndex(null);
    }
  }, []);

  const handlePlaylistDrop = useCallback(async (e: React.DragEvent, dropIndex: number) => {
    e.preventDefault();
    e.stopPropagation(); // Empêcher la propagation
    
    // Protection contre les drops multiples
    if (isDropInProgress.current) {
      console.log('[DRAG] 🚫 Drop sur playlist ignoré car un drop est déjà en cours');
      return;
    }
    
    console.log('[control] DROP - draggedItem:', draggedItem, 'dropIndex:', dropIndex);
    
    try {
      // Marquer le drop comme en cours
      isDropInProgress.current = true;
      
      // 🎯 PRIORITÉ 1: Vérifier s'il s'agit d'un ajout depuis le catalogue
      const data = e.dataTransfer.getData("application/json");
      if (data) {
        console.log('[DRAG] ⚠️ 📋 Drop depuis catalogue sur élément existant détecté');
        const items = JSON.parse(data);
        if (Array.isArray(items) && items.length > 0) {
          console.log('[DRAG] ⚠️ 📋 Items à ajouter:', items.map(i => i.title));
          await addToQueue(items);
          resetDragState();
          return;
        }
      }
    } catch (error) {
      console.warn("Erreur lors du parsing des données de drag:", error);
    }
    
    // 🎯 PRIORITÉ 2: Gérer la réorganisation de playlist si draggedItem existe
    const draggedIndex = draggedItem;
    if (draggedIndex === null || draggedIndex === dropIndex) {
      console.log('[control] DROP annulé - même index ou pas de draggedItem');
      resetDragState();
      return;
    }

    try {
      console.log('[control] Réorganisation playlist:', draggedIndex, '->', dropIndex);
      console.log('[control] Queue avant reorder:', queue.items.map((item, i) => `${i}: ${item.title}`));
      
      // Déboguer l'appel IPC
      console.log('[control] Vérification electron.queue.reorder:', typeof electron?.queue?.reorder);
      
      // Appeler directement le backend sans réorganisation locale
      console.log('[control] Appel IPC queue:reorder en cours...');
      const result = await electron?.queue?.reorder?.(draggedIndex, dropIndex);
      console.log('[control] Résultat reçu du backend:', result);
      
      if (result) {
        // Utiliser directement le résultat du backend
        setQueue(prev => ({ 
          ...prev, 
          items: result.items,
          currentIndex: result.currentIndex
        }));
        console.log('[control] Réorganisation réussie, nouvel état:', result.items.map((item: any, i: number) => `${i}: ${item.title}`));
      } else {
        console.warn('[control] Pas de résultat du backend');
        await loadQueue(); // Fallback
      }
      
    } catch (e) {
      console.warn('[control] Erreur réorganisation playlist :', e);
      // En cas d'erreur, recharger l'état depuis le backend
      await loadQueue();
    } finally {
      // Toujours réinitialiser l'état à la fin
      resetDragState();
      // Réinitialiser la protection après un délai pour éviter les conflits
      setTimeout(() => {
        isDropInProgress.current = false;
      }, 100);
    }
  }, [draggedItem, electron, loadQueue, queue.items, resetDragState]);

  const playerControl = useCallback(async (action: string, value?: any) => {
    try {
      console.log('[control] playerControl appelé - action:', action, 'value:', value);
      await electron?.player?.control?.({ action, value });
      
      // Mettre à jour l'état local immédiatement pour une meilleure réactivité UI
      if (action === 'play') {
        setQueue(prev => ({ ...prev, isPlaying: true, isPaused: false }));
        console.log('[control] État local mis à jour - isPlaying: true');
      } else if (action === 'pause') {
        setQueue(prev => ({ ...prev, isPlaying: false, isPaused: true }));
        console.log('[control] État local mis à jour - isPlaying: false');
      } else if (action === 'stop') {
        setQueue(prev => ({ ...prev, isPlaying: false, isPaused: false }));
        console.log('[control] État local mis à jour - stopped');
      }
      
      await loadQueue(); // Refresh état
    } catch (e) {
      console.warn('[control] Erreur contrôle player :', e);
    }
  }, [electron, loadQueue]);

  const setRepeatMode = useCallback(async (mode: 'none' | 'one' | 'all') => {
    setQueue(prev => ({ ...prev, repeatMode: mode }));
    try {
      await electron?.queue?.setRepeat?.(mode);
      console.log('[control] Repeat mode défini:', mode);
    } catch (e) {
      console.warn('[control] Erreur repeat mode :', e);
    }
  }, [electron]);

  // Fonctions de contrôle du volume
  const setVolumeLevel = useCallback(async (newVolume: number) => {
    const clampedVolume = Math.max(0, Math.min(1, newVolume));
    setVolume(clampedVolume);
    setIsMuted(clampedVolume === 0);
    
    try {
      await electron?.player?.control?.({ action: 'setVolume', value: clampedVolume });
      console.log('[control] Volume défini:', clampedVolume);
    } catch (e) {
      console.warn('[control] Erreur volume :', e);
    }
  }, [electron]);

  const toggleMute = useCallback(async () => {
    if (isMuted) {
      // Désactiver le mute, restaurer le volume précédent
      await setVolumeLevel(previousVolume > 0 ? previousVolume : 0.5);
      setIsMuted(false);
    } else {
      // Activer le mute, sauvegarder le volume actuel
      setPreviousVolume(volume);
      await setVolumeLevel(0);
      setIsMuted(true);
    }
  }, [isMuted, volume, previousVolume, setVolumeLevel]);

  const adjustVolume = useCallback(async (delta: number) => {
    const newVolume = volume + delta;
    await setVolumeLevel(newVolume);
  }, [volume, setVolumeLevel]);

  // 8) Actions de déverrouillage
  const unlock = useCallback(async () => {
    try {
      const r = await electron?.license?.enterPassphrase?.(passphrase);
      if (r?.ok || r === true) {
        setLocked(false);
        setPassphrase("");
      } else {
        alert("Mot de passe invalide.");
      }
    } catch (e) {
      console.warn("[control] unlock error:", e);
      alert("Échec du déverrouillage.");
    }
  }, [electron, passphrase]);

  // 9) Utilitaires
  const formatDuration = useCallback((ms?: number | null) => {
    if (!ms && ms !== 0) return "--:--";
    const m = Math.floor((ms ?? 0) / 60000);
    const s = Math.floor(((ms ?? 0) % 60000) / 1000);
    return `${m}:${s.toString().padStart(2, "0")}`;
  }, []);

  const getPlays = useCallback((id: string) => {
    try {
      return (stats && typeof stats === 'object' && id in stats) ? (stats[id] ?? 0) : 0;
    } catch {
      return 0;
    }
  }, [stats]);

  // 10) Filtrage du catalogue
  const uniqueGenres = useMemo(() => {
    const genres = new Set<string>();
    catalogue.forEach(item => {
      if (item.genre) genres.add(item.genre);
    });
    return ["Tout", ...Array.from(genres).sort()];
  }, [catalogue]);

  const uniqueYears = useMemo(() => {
    const years = new Set<number>();
    catalogue.forEach(item => {
      if (item.year) years.add(item.year);
    });
    return ["Toutes", ...Array.from(years).sort((a, b) => b - a).map(String)];
  }, [catalogue]);

  const uniqueArtists = useMemo(() => {
    const artists = new Set<string>();
    catalogue.forEach(item => {
      if (item.artist) artists.add(item.artist);
    });
    return ["Tous", ...Array.from(artists).sort()];
  }, [catalogue]);

  const filteredCatalogue = useMemo(() => {
    return catalogue.filter((entry: MediaEntry) => {
      // Filtre par terme de recherche
      const query = searchTerm.toLowerCase();
      const matchesSearch = !query || (
        (entry.title ?? "").toLowerCase().includes(query) ||
        (entry.artist ?? "").toLowerCase().includes(query) ||
        (entry.genre ?? "").toLowerCase().includes(query) ||
        String(entry.year ?? "").includes(query)
      );

      // Filtres par sélection
      const matchesGenre = selectedGenre === "Tout" || entry.genre === selectedGenre;
      const matchesYear = selectedYear === "Toutes" || String(entry.year) === selectedYear;
      const matchesArtist = selectedArtist === "Tous" || entry.artist === selectedArtist;

      return matchesSearch && matchesGenre && matchesYear && matchesArtist;
    });
  }, [catalogue, searchTerm, selectedGenre, selectedYear, selectedArtist]);

  // 11) Gestion drag & drop
  const handleDragStart = useCallback((e: React.DragEvent, entry: MediaEntry) => {
    console.log('[DRAG] 🎬 Catalogue - DragStart pour:', entry.title);
    e.dataTransfer.setData("application/json", JSON.stringify([entry]));
    e.dataTransfer.effectAllowed = "copy";
    console.log('[DRAG] 🎬 Catalogue - Données de drag définies');
  }, []);

  const handleDragOver = useCallback((e: React.DragEvent) => {
    console.log('[DRAG] 🎬 Catalogue - DragOver sur zone playlist');
    e.preventDefault();
    e.dataTransfer.dropEffect = "copy";
  }, []);

  const handleDrop = useCallback(async (e: React.DragEvent) => {
    e.preventDefault();
    
    // Protection contre les drops multiples
    if (isDropInProgress.current) {
      console.log('[DRAG] � Drop ignoré car un drop est déjà en cours');
      return;
    }
    
    console.log('[DRAG] �📋 Drop sur zone playlist - Type de drag:', { 
      draggedItem: draggedItem !== null ? 'playlist-reorder' : null,
      draggedFromCatalog: draggedFromCatalog !== null ? 'catalog-add' : null 
    });
    
    try {
      // Marquer le drop comme en cours
      isDropInProgress.current = true;
      
      // Si c'est un drag depuis le catalogue
      const data = e.dataTransfer.getData("application/json");
      if (data) {
        console.log('[DRAG] ⚠️ 📋 Drop depuis catalogue sur espace vide détecté');
        const items = JSON.parse(data);
        if (Array.isArray(items) && items.length > 0) {
          console.log('[DRAG] ⚠️ 📋 Items à ajouter sur espace vide:', items.map(i => i.title));
          await addToQueue(items);
        }
        resetDragState();
        return;
      }
      
      // Si aucune donnée, reset le drag state
      resetDragState();
    } catch (error) {
      console.warn("Erreur lors du drop:", error);
      resetDragState();
    } finally {
      // Réinitialiser la protection après un délai pour éviter les conflits
      setTimeout(() => {
        isDropInProgress.current = false;
      }, 100);
    }
  }, [electron, loadQueue, draggedItem, draggedFromCatalog, resetDragState]);

  // 12) Gestion des événements de lecture (status updates et fin de lecture)
  useEffect(() => {
    if (!electronReady) return;

    // Gestion des mises à jour de statut du player
    const handlePlayerStatus = (status: any) => {
      console.log('[control] player:status:update reçu:', status);
      if (status && typeof status === 'object') {
        // Mettre à jour l'état isPlaying selon l'état pausé
        const isCurrentlyPlaying = !status.paused;
        setQueue(prev => ({
          ...prev,
          isPlaying: isCurrentlyPlaying,
          isPaused: status.paused || false
        }));
        console.log('[control] État lecture mis à jour - isPlaying:', isCurrentlyPlaying);
      }
    };

    const handlePlayerEvent = async (event: any) => {
      console.log('[control] player:event reçu:', event);
      if (event?.type !== 'ended') return;

      console.log('[control] Gestion de ended, mode repeat:', queue.repeatMode);

      // Toujours repartir d'un état queue frais
      const fresh = await electron?.queue?.get?.();
      if (fresh) setQueue(prev => ({ ...prev, ...fresh }));

      const idx = fresh?.currentIndex ?? queue.currentIndex;
      const items = fresh?.items ?? queue.items;
      const item = idx >= 0 ? items[idx] : null;

      console.log('[control] Repeat logic - idx:', idx, 'mode:', fresh?.repeatMode ?? queue.repeatMode, 'items.length:', items.length);

      // Stats: compter la lecture
      try {
        if (item?.id) {
          const playedMs = item.durationMs ?? 0;
          await electron?.stats?.played?.({ id: item.id, playedMs });
          console.log('[control] Stats played envoyées pour:', item.id);
          
          // 🔄 Recharger immédiatement les stats pour mettre à jour les compteurs de vues
          await loadStats();
          console.log('[control] Stats rechargées après lecture');
        }
      } catch (e) {
        console.warn('[control] Erreur stats played :', e);
      }

      // Repeat logic
      const mode = fresh?.repeatMode ?? queue.repeatMode;
      if (mode === 'one' && idx >= 0) {
        console.log('[control] Mode repeat "one" - rejouer idx:', idx);
        await electron?.queue?.playAt?.(idx);
        return;
      }
      if (mode === 'all') {
        console.log('[control] Mode repeat "all" - idx:', idx, 'length:', items.length);
        if (idx < items.length - 1) {
          console.log('[control] Passage à la chanson suivante');
          await electron?.queue?.next?.();
        } else {
          console.log('[control] Retour au début de la playlist');
          await electron?.queue?.playAt?.(0);
        }
        return;
      }
      // none - lecture séquentielle normale
      console.log('[control] Mode repeat "none" - lecture séquentielle');
      if (idx < items.length - 1) {
        console.log('[control] Passage à la chanson suivante (mode none)');
        await electron?.queue?.next?.();
      } else {
        console.log('[control] Fin de playlist - arrêt');
        await electron?.player?.stop?.();
      }
    };

    const unsubscribeStatus = electron?.ipc?.on?.('player:status:update', handlePlayerStatus);
    const unsubscribeEvent = electron?.ipc?.on?.('player:event', handlePlayerEvent);
    
    return () => {
      unsubscribeStatus?.();
      unsubscribeEvent?.();
    };
  }, [electronReady, electron]);

  // 13) Icônes et labels pour repeat mode
  const getRepeatIcon = useCallback(() => {
    const mode = String(queue.repeatMode || 'none');
    switch (mode) {
      case 'one': return '🔂';
      case 'all': return '🔁';
      default: return '↩️';
    }
  }, [queue.repeatMode]);

  const getRepeatLabel = useCallback(() => {
    const mode = String(queue.repeatMode || 'none');
    switch (mode) {
      case 'one': return 'Répéter: Une fois';
      case 'all': return 'Répéter: Tout';
      default: return 'Répéter: Désactivé';
    }
  }, [queue.repeatMode]);

  // 14) Rendu conditionnel (TOUS LES HOOKS DÉJÀ APPELÉS)
  return (
    <div className="min-h-screen bg-gray-900 text-white">
      {/* État INIT: electron pas encore prêt */}
      {!electronReady && (
        <div className="h-screen grid place-items-center">
          <div className="text-center opacity-80">
            <div className="text-xl font-semibold mb-2">Initialisation…</div>
            <div className="text-sm">
              En attente de <code>window.electron</code>…
            </div>
          </div>
        </div>
      )}

      {/* Écran de déverrouillage */}
      {electronReady && locked && (
        <div className="h-screen grid place-items-center bg-gray-900">
          <div className="w-[400px] bg-white/5 border border-white/10 rounded-2xl p-8">
            <div className="text-2xl font-semibold mb-4 text-center">Session verrouillée</div>
            <div className="text-white/70 text-sm mb-6 text-center">
              Entrez la passphrase pour déverrouiller.
            </div>
            <div className="space-y-4">
              <input
                type="password"
                value={passphrase}
                onChange={(e) => setPassphrase(e.target.value)}
                placeholder="Mot de passe (test123)"
                className="w-full px-4 py-3 bg-white/10 rounded-lg outline-none text-white placeholder-gray-400"
                autoFocus
                onKeyDown={(e) => e.key === "Enter" && unlock()}
              />
              <button
                onClick={unlock}
                className="w-full px-4 py-3 bg-emerald-600 hover:bg-emerald-700 rounded-lg transition-colors font-medium"
              >
                Déverrouiller
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Interface principale */}
      {electronReady && !locked && (
        <div className="flex flex-col h-screen">
          {/* Header */}
          <header className="bg-gray-800 border-b border-gray-700 p-4">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-2xl font-bold">USB Video Vault — Contrôle</h1>
                <div className="text-sm text-gray-400 mt-1">
                  Catalogue : {catalogue.length} | Queue : {queue.items.length} | Stats : {Object.keys(stats).length}
                </div>
              </div>
              <button
                onClick={async () => {
                  try { await electron?.player?.control?.({ action: 'stop' }); } catch {}
                  try { await electron?.queue?.clear?.(); } catch {}
                  try {
                    if (electron?.session?.lock) {
                      await electron.session.lock();
                    } else if (electron?.license?.save) {
                      await electron.license.save({ locked: true });
                    }
                  } catch {}
                  setLocked(true);
                }}
                className="px-3 py-2 bg-red-600 hover:bg-red-700 rounded text-sm font-medium transition-colors"
              >
                Terminer la session
              </button>
            </div>
          </header>

          {/* Layout principal - Grid responsive */}
          <div className="flex-1 grid grid-cols-1 lg:grid-cols-3 gap-4 p-4 overflow-hidden">
            
            {/* Colonne gauche - Catalogue */}
            <section className="flex flex-col bg-gray-800/50 rounded-lg lg:col-span-2">
              <div className="p-4 border-b border-gray-700">
                <h2 className="text-xl font-semibold mb-4">📚 Catalogue</h2>
                
                {/* Filtres - Uniquement barre de recherche */}
                <div className="mb-4">
                  {/* Boutons de filtre masqués - logique conservée */}
                  <div style={{ display: 'none' }}>
                    <select
                      value={selectedGenre}
                      onChange={(e) => setSelectedGenre(e.target.value)}
                    >
                      {uniqueGenres.map(genre => (
                        <option key={genre} value={genre}>Genre: {genre}</option>
                      ))}
                    </select>
                    
                    <select
                      value={selectedYear}
                      onChange={(e) => setSelectedYear(e.target.value)}
                    >
                      {uniqueYears.map(year => (
                        <option key={year} value={year}>Année: {year}</option>
                      ))}
                    </select>
                    
                    <select
                      value={selectedArtist}
                      onChange={(e) => setSelectedArtist(e.target.value)}
                    >
                      {uniqueArtists.map(artist => (
                        <option key={artist} value={artist}>Artiste: {artist}</option>
                      ))}
                    </select>
                  </div>
                  
                  {/* Barre de recherche unique et visible */}
                  <input
                    type="text"
                    placeholder="Recherche globale..."
                    value={searchTerm}
                    onChange={(e) => setSearchTerm(e.target.value)}
                    className="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white text-sm placeholder-gray-400"
                  />
                </div>
              </div>

              {/* Liste du catalogue */}
              <div className="flex-1 p-4" style={{ height: '400px', overflowY: 'scroll' }}>
                {isLoading ? (
                  <div className="p-8 text-center text-gray-400">
                    <div className="animate-spin w-8 h-8 border-2 border-blue-500 border-t-transparent rounded-full mx-auto mb-4"></div>
                    Chargement du catalogue…
                  </div>
                ) : filteredCatalogue.length > 0 ? (
                  <div className="space-y-2">
                    {filteredCatalogue.map((entry: MediaEntry) => (
                      <div
                        key={entry.id}
                        draggable
                        onDragStart={(e) => handleDragStart(e, entry)}
                        className="flex items-center justify-between p-3 bg-gray-700 hover:bg-gray-600 rounded-lg transition-colors cursor-move"
                      >
                        <div className="min-w-0 flex-1">
                          <div className="font-medium truncate">
                            {entry.title ?? "Sans titre"}
                          </div>
                          <div className="text-sm text-gray-400 truncate">
                            🎤 {entry.artist ?? "Artiste inconnu"} • 
                            🎵 {entry.genre ?? "Genre ?"} • 
                            📅 {entry.year ?? "—"}
                          </div>
                        </div>
                        <div className="flex items-center gap-3 text-sm">
                          <span className="text-gray-400">
                            ⏱️ {formatDuration(entry.durationMs)}
                          </span>
                          <span className="text-blue-400 font-semibold">
                            👁️ {getPlays(entry.id)} vues
                          </span>
                          <button
                            onClick={() => playItem(entry)}
                            className="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm font-medium transition-colors"
                          >
                            ▶️ Lire
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="p-8 text-center text-gray-400">
                    <div className="text-6xl mb-4">🔍</div>
                    <div className="text-lg mb-2">Aucun résultat</div>
                    <div className="text-sm">Ajustez vos filtres ou votre recherche</div>
                  </div>
                )}
              </div>
            </section>

            {/* Colonne droite - Contrôles & Sécurité */}
            <section className="flex flex-col gap-4">
              {/* Sécurité du lecteur */}
              <SecurityControl electron={electron} />
              
              {/* Analytics et Anti-rollback */}
              <div className="bg-gray-800/50 rounded-lg p-4">
                <AnalyticsMonitor electron={electron} />
              </div>
              
              {/* Playlist & Contrôles */}
              <div className="flex flex-col bg-gray-800/50 rounded-lg">
                <div className="p-4 border-b border-gray-700">
                  <h2 className="text-xl font-semibold mb-4">🎵 Playlist & Contrôles</h2>
                
                {/* Contrôles player */}
                <div className="flex items-center gap-3 mb-4 p-3 bg-gray-700 rounded-lg">
                  <button
                    onClick={async () => {
                      try {
                        await electron?.queue?.prev?.();
                        await loadQueue(); // Refresh état après navigation
                      } catch (e) {
                        console.warn('[control] Erreur prev:', e);
                      }
                    }}
                    className="p-2 bg-gray-600 hover:bg-gray-500 rounded transition-colors"
                    title="Précédent"
                  >
                    ⏮️
                  </button>
                  <button
                    onClick={() => playerControl(queue.isPlaying ? 'pause' : 'play')}
                    className="p-2 bg-blue-600 hover:bg-blue-700 rounded transition-colors"
                    title={queue.isPlaying ? "Pause" : "Lecture"}
                  >
                    {queue.isPlaying ? '⏸️' : '▶️'}
                  </button>
                  <button
                    onClick={async () => {
                      try {
                        await electron?.queue?.next?.();
                        await loadQueue(); // Refresh état après navigation
                      } catch (e) {
                        console.warn('[control] Erreur next:', e);
                      }
                    }}
                    className="p-2 bg-gray-600 hover:bg-gray-500 rounded transition-colors"
                    title="Suivant"
                  >
                    ⏭️
                  </button>
                  <button
                    onClick={() => playerControl('stop')}
                    className="p-2 bg-red-600 hover:bg-red-700 rounded transition-colors"
                    title="Arrêter"
                  >
                    ⏹️
                  </button>
                  <div className="flex-1"></div>
                  <button
                    onClick={() => {
                      const modes: Array<'none' | 'one' | 'all'> = ['none', 'one', 'all'];
                      const currentMode = String(queue.repeatMode || 'none') as 'none' | 'one' | 'all';
                      const currentIndex = modes.indexOf(currentMode);
                      const nextMode = modes[(currentIndex + 1) % modes.length];
                      setRepeatMode(nextMode);
                    }}
                    className="px-3 py-2 bg-gray-600 hover:bg-gray-500 rounded transition-colors text-sm"
                    title={getRepeatLabel()}
                  >
                    {getRepeatIcon()} {String(queue.repeatMode || 'none').toUpperCase()}
                  </button>
                </div>

                {/* Contrôles de volume */}
                <div className="flex items-center gap-3 mb-4 p-3 bg-gray-700 rounded-lg">
                  <span className="text-sm text-gray-300 min-w-[60px]">🔊 Volume</span>
                  
                  {/* Bouton mute/unmute */}
                  <button
                    onClick={toggleMute}
                    className="p-2 bg-gray-600 hover:bg-gray-500 rounded transition-colors"
                    title={isMuted ? "Activer le son" : "Couper le son"}
                  >
                    {isMuted ? '🔇' : volume > 0.5 ? '🔊' : volume > 0 ? '🔉' : '🔈'}
                  </button>

                  {/* Boutons volume - et + */}
                  <button
                    onClick={() => adjustVolume(-0.1)}
                    className="p-1 bg-gray-600 hover:bg-gray-500 rounded transition-colors text-sm"
                    title="Diminuer le volume"
                  >
                    -
                  </button>

                  {/* Slider de volume */}
                  <div className="flex-1 relative">
                    <input
                      type="range"
                      min="0"
                      max="1"
                      step="0.01"
                      value={volume}
                      onChange={(e) => setVolumeLevel(parseFloat(e.target.value))}
                      className="w-full h-2 bg-gray-600 rounded-lg appearance-none cursor-pointer slider"
                      style={{
                        background: `linear-gradient(to right, #3b82f6 0%, #3b82f6 ${volume * 100}%, #4b5563 ${volume * 100}%, #4b5563 100%)`
                      }}
                    />
                  </div>

                  <button
                    onClick={() => adjustVolume(0.1)}
                    className="p-1 bg-gray-600 hover:bg-gray-500 rounded transition-colors text-sm"
                    title="Augmenter le volume"
                  >
                    +
                  </button>

                  {/* Affichage du pourcentage */}
                  <span className="text-sm text-gray-300 min-w-[40px] text-right">
                    {Math.round(volume * 100)}%
                  </span>
                </div>
              </div>

              {/* Zone de drop + Liste playlist */}
              <div 
                className="overflow-y-scroll p-4 border border-gray-600 rounded"
                style={{
                  height: '200px',
                  scrollbarWidth: 'thin',
                  scrollbarColor: '#6b7280 #374151',
                  overflowY: 'scroll',
                  WebkitOverflowScrolling: 'touch'
                }}
                onDragOver={handleDragOver}
                onDrop={handleDrop}
              >
                {draggedItem !== null && (
                  <div className="mb-3 p-2 bg-blue-900/50 border border-blue-500 rounded-lg text-center text-sm text-blue-200">
                    🎯 Glissez sur une autre chanson pour la réorganiser dans la playlist
                  </div>
                )}
                {queue.items.length > 0 ? (
                  <div className="space-y-2">
                    {queue.items.map((item: QueueItem, index: number) => (
                      <div
                        key={`${item.id}-${index}-${dragRefreshKey}`}
                        data-playlist-item={index}
                        draggable={true}
                        onDragStart={(e) => handlePlaylistDragStart(e, index)}
                        onDragEnd={handlePlaylistDragEnd}
                        onDragOver={(e) => handlePlaylistDragOver(e, index)}
                        onDragLeave={handlePlaylistDragLeave}
                        onDrop={(e) => handlePlaylistDrop(e, index)}
                        className={`flex items-center justify-between p-3 rounded-lg transition-all cursor-move relative ${
                          index === queue.currentIndex 
                            ? 'bg-blue-600/30 border border-blue-500' 
                            : 'bg-gray-700 hover:bg-gray-600'
                        } ${
                          dragOverIndex === index ? 'border-2 border-green-400 border-dashed bg-green-900/20 shadow-lg' : ''
                        } ${
                          draggedItem === index ? 'opacity-50 transform scale-95 border-2 border-orange-400 border-dashed' : ''
                        }`}
                      >
                        {/* Indicateur de drag */}
                        <div className="absolute left-1 top-1/2 transform -translate-y-1/2 text-gray-500 opacity-60">
                          ⋮⋮
                        </div>
                        
                        <div className="min-w-0 flex-1 ml-4">
                          <div className="font-medium truncate">
                            {item.title ?? "Sans titre"}
                          </div>
                          <div className="text-sm text-gray-400 truncate">
                            ⏱️ {formatDuration(item.durationMs)}
                          </div>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="text-xs text-gray-500">#{index + 1}</span>
                          <button
                            onClick={async () => {
                              try {
                                await electron?.queue?.playAt?.(index);
                                await loadQueue();
                              } catch (e) {
                                console.warn('[control] Erreur playAt :', e);
                              }
                            }}
                            className="px-2 py-1 bg-green-600 hover:bg-green-700 rounded text-xs transition-colors"
                          >
                            ▶️
                          </button>
                          <button
                            onClick={() => removeFromQueue(index)}
                            className="px-2 py-1 bg-red-600 hover:bg-red-700 rounded text-xs transition-colors"
                            title="Retirer"
                          >
                            ✕
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div
                    className="h-full border-2 border-dashed border-gray-600 rounded-lg p-8 text-center text-gray-400 hover:border-gray-500 transition-colors"
                    onDragOver={handleDragOver}
                    onDrop={handleDrop}
                  >
                    <div className="text-4xl mb-4">🎵</div>
                    <div className="text-lg mb-2">Playlist vide</div>
                    <div className="text-sm">
                      Glissez des médias du catalogue ici pour créer votre playlist
                    </div>
                  </div>
                )}
              </div>
              </div>
            </section>
          </div>

          {/* Footer avec debug */}
          <footer className="bg-gray-800 border-t border-gray-700 p-3">
            <div className="flex items-center justify-between text-sm text-gray-400">
              <div className="flex items-center gap-6">
                <span>📊 Stats: {Object.keys(stats).length} entrées</span>
                <span>🔒 Session: {locked ? 'Verrouillée' : 'Déverrouillée'}</span>
                <span>🎵 Queue: {queue.items.length} élément{queue.items.length !== 1 ? 's' : ''}</span>
                <span>🔄 Repeat: {queue.repeatMode}</span>
              </div>
              <div className="text-xs">
                USB Video Vault v0.1.0 • Interface restaurée
              </div>
            </div>
          </footer>
        </div>
      )}
    </div>
  );
};

export default ControlWindowClean;
