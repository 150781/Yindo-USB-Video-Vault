import React, { useEffect, useState } from 'react';
import LicenseGate from './LicenseGate';

// Types simplifiés
interface MediaEntry {
  id: string;
  title: string;
  artist?: string;
  genre?: string;
  year?: number;
  durationSec?: number;
  durationMs?: number | null;
  source?: 'asset' | 'vault';
  src?: string;
}

interface QueueState {
  queue: string[];
  index: number;
  currentId?: string;
  shuffle: boolean;
  repeat: 'off' | 'one' | 'all';
}

interface PlaylistEntry {
  id: string;
  name: string;
  itemIds: string[];
}

interface PlaylistStore {
  playlists: PlaylistEntry[];
}

// Utilitaires
function useElectron() {
  return typeof window !== 'undefined' ? (window as any).electron : null;
}

function normalize(str: string): string {
  return (str || '').toLowerCase().normalize('NFD').replace(/\p{Diacritic}/gu, '');
}

function formatDuration(seconds?: number): string {
  if (!seconds || !isFinite(seconds)) return '–';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) {
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export default function ControlWindow() {
  const electron = useElectron();
  
  // États principaux
  const [media, setMedia] = useState<MediaEntry[]>([]);
  const [queue, setQueue] = useState<QueueState>({
    queue: [],
    index: -1,
    shuffle: false,
    repeat: 'off'
  });
  const [playlists, setPlaylists] = useState<PlaylistStore>({ playlists: [] });
  
  // États UI
  const [searchQuery, setSearchQuery] = useState('');
  const [newPlaylistName, setNewPlaylistName] = useState('');

  // Fonction pour charger les médias du catalogue unifié
  const loadMedia = async () => {
    if (!electron?.catalog?.list) {
      console.error('[ControlWindow] electron.catalog.list non disponible');
      return;
    }
    try {
      console.log('[ControlWindow] Tentative de chargement du catalogue...');
      const result = await electron.catalog.list();
      console.log('[ControlWindow] Résultat catalog.list:', result);
      if (result?.ok) {
        console.log('[ControlWindow] Catalogue reçu:', result.list?.length || 0, 'entrées');
        setMedia(result.list || []);
      } else {
        console.error('[ControlWindow] Erreur catalog.list:', result?.error);
      }
    } catch (e) {
      console.error('[ControlWindow] Erreur chargement catalogue:', e);
    }
  };

  // Chargement initial des données (sauf médias qui nécessitent licence)
  useEffect(() => {
    if (!electron) return;
    
    // Charger la queue
    electron.queue?.get?.()
      .then(setQueue)
      .catch(console.error);

    // Charger les playlists
    electron.playlists?.list?.()
      .then(setPlaylists)
      .catch(console.error);

    // Les médias seront chargés uniquement après déverrouillage via onUnlock
  }, [electron]);

  // Filtrage des médias
  const filteredMedia = React.useMemo(() => {
    if (!searchQuery.trim()) return media;

    const normalizedQuery = normalize(searchQuery);

    return media.filter(item => {
      const searchText = `${normalize(item.title)} ${normalize(item.artist || '')} ${normalize(item.id)} ${item.year || ''} ${normalize(item.genre || '')}`;
      return normalizedQuery.split(/\s+/).every(term => searchText.includes(term));
    });
  }, [media, searchQuery]);

  // Actions de la queue
  async function addToQueue(mediaIds: string[]) {
    if (!electron?.queue?.add) return;
    try {
      const newQueue = await electron.queue.add(mediaIds);
      setQueue(newQueue);
    } catch (e) {
      console.error('Erreur ajout queue:', e);
    }
  }

  async function playNow(entry: MediaEntry) {
    if (!electron) return;
    
    try {
      console.log('[ControlWindow] 🎬 CLIC SUR LIRE - Début de playNow pour:', entry.title);
      console.log('[ControlWindow] Entry complète:', entry);
      
      // Utiliser queue.playNow pour tout type de média
      const queueItem = {
        id: entry.id,
        title: entry.title,
        artist: entry.artist,
        genre: entry.genre,
        year: entry.year,
        durationMs: entry.durationMs,
        source: entry.source || 'asset',
        src: entry.src,
        mediaId: entry.source === 'vault' ? entry.id : undefined
      };
      
      console.log('[ControlWindow] QueueItem envoyé:', queueItem);
      console.log('[ControlWindow] Appel de electron.queue.playNow...');
      
      const newQueue = await electron.queue.playNow(queueItem);
      console.log('[ControlWindow] ✅ Queue mise à jour:', newQueue);
      
      // Mettre à jour l'état local de la queue
      if (newQueue && newQueue.items) {
        const repeatMode = typeof newQueue.repeatMode === 'string' ? newQueue.repeatMode : 'none';
        setQueue({
          queue: newQueue.items.map((item: any) => item.id),
          index: newQueue.currentIndex,
          currentId: newQueue.items[newQueue.currentIndex]?.id,
          shuffle: newQueue.shuffleMode,
          repeat: repeatMode === 'none' ? 'off' : repeatMode
        });
      }
    } catch (error) {
      console.error('[ControlWindow] ❌ Erreur lors de la lecture:', error);
    }
  }

  async function controlPlayer(action: 'play' | 'pause' | 'stop') {
    if (!electron?.ipc) return;
    try {
      await electron.ipc.invoke('player:control', { action });
    } catch (e) {
      console.error(`Erreur contrôle ${action}:`, e);
    }
  }

  async function navigateQueue(direction: 'prev' | 'next') {
    if (!electron?.queue) return;
    try {
      const newQueue = direction === 'prev' 
        ? await electron.queue.prev()
        : await electron.queue.next();
      setQueue(newQueue);
    } catch (e) {
      console.error(`Erreur navigation ${direction}:`, e);
    }
  }

  async function openDisplay() {
    if (!electron?.ipc) return;
    try {
      await electron.ipc.invoke('display:open', {});
    } catch (e) {
      console.error('Erreur ouverture affichage:', e);
    }
  }

  const currentMedia = queue.currentId ? media.find(m => m.id === queue.currentId) : null;

  return (
    <LicenseGate onUnlock={loadMedia}>
      <div className="p-6 max-w-7xl mx-auto text-white min-h-screen bg-gradient-to-br from-gray-900 to-black">
        <h1 className="text-3xl font-bold mb-6 text-center bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
          USB Video Vault — Control Center
        </h1>

        {/* Section Affichage */}
        <div className="mb-6 p-4 rounded-xl bg-white/5 border border-white/10">
          <h2 className="text-lg font-semibold mb-3 text-blue-300">🖥️ Contrôles d'affichage</h2>
          <div className="flex gap-3 flex-wrap">
            <button 
              onClick={openDisplay}
              className="px-4 py-2 rounded-lg bg-blue-600 hover:bg-blue-700 transition-colors"
              disabled={!electron}
            >
              Ouvrir écran d'affichage
            </button>
          </div>
        </div>

        {/* Section Recherche et Catalogue */}
        <div className="mb-6 p-4 rounded-xl bg-white/5 border border-white/10">
          <h2 className="text-lg font-semibold mb-3 text-cyan-300">🔍 Catalogue ({media.length} médias)</h2>
          
          <div className="flex gap-3 items-center mb-4 flex-wrap">
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder='Rechercher... (titre, artiste, année, genre)'
              className="flex-1 min-w-[400px] px-3 py-2 rounded-lg bg-white/10 border border-white/20 focus:border-cyan-400 focus:outline-none"
            />
            <button
              onClick={() => addToQueue(filteredMedia.map(m => m.id))}
              className="px-4 py-2 rounded-lg bg-cyan-600 hover:bg-cyan-700 transition-colors"
              disabled={!electron || filteredMedia.length === 0}
            >
              + Tout ajouter ({filteredMedia.length})
            </button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-white/20">
                  <th className="text-left p-3 font-semibold text-gray-300">Titre</th>
                  <th className="text-left p-3 font-semibold text-gray-300">Artiste</th>
                  <th className="text-left p-3 font-semibold text-gray-300">Genre</th>
                  <th className="text-left p-3 font-semibold text-gray-300">Année</th>
                  <th className="text-left p-3 font-semibold text-gray-300">Source</th>
                  <th className="text-left p-3 font-semibold text-gray-300">Durée</th>
                  <th className="text-right p-3 font-semibold text-gray-300">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/10">
                {filteredMedia.map((item) => (
                  <tr
                    key={item.id}
                    className={`hover:bg-white/5 transition-colors ${
                      item.id === queue.currentId ? 'bg-green-500/20' : ''
                    }`}
                  >
                    <td className="p-3">
                      <div className="font-medium">{item.title}</div>
                      <div className="text-xs text-gray-400 mt-1">{item.id}</div>
                    </td>
                    <td className="p-3 text-gray-300">{item.artist || '—'}</td>
                    <td className="p-3 text-gray-300">{item.genre || '—'}</td>
                    <td className="p-3 text-gray-300">{item.year || '—'}</td>
                    <td className="p-3">
                      <span className={`px-2 py-1 rounded text-xs ${
                        item.source === 'asset' 
                          ? 'bg-purple-600/20 text-purple-300 border border-purple-500/30' 
                          : 'bg-blue-600/20 text-blue-300 border border-blue-500/30'
                      }`}>
                        {item.source === 'asset' ? '📁 Assets' : '🔒 Vault'}
                      </span>
                    </td>
                    <td className="p-3 text-gray-300 font-mono">{formatDuration(item.durationSec || (item.durationMs ? item.durationMs / 1000 : undefined))}</td>
                    <td className="p-3">
                      <div className="flex gap-2 justify-end">
                        <button
                          onClick={() => addToQueue([item.id])}
                          className="px-3 py-1 rounded bg-blue-600 hover:bg-blue-700 transition-colors text-xs"
                        >
                          + Queue
                        </button>
                        <button
                          onClick={() => {
                            console.log('CLIC!!!');
                            // Envoi d'un log au main process pour qu'il apparaisse dans le terminal
                            if (electron?.ipc?.send) {
                              electron.ipc.send('debug-log', 'UI: CLIC sur bouton Lire');
                            }
                            playNow(item);
                          }}
                          className="px-3 py-1 rounded bg-green-600 hover:bg-green-700 transition-colors text-xs"
                        >
                          ▶ Lire
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        {/* Section Contrôles de lecture */}
        <div className="p-4 rounded-xl bg-white/5 border border-white/10">
          <h2 className="text-lg font-semibold mb-3 text-yellow-300">🎵 Lecture</h2>
          
          {currentMedia && (
            <div className="mb-4 p-3 rounded-lg bg-green-500/20 border border-green-500/40">
              <div className="font-medium text-green-200">En cours:</div>
              <div className="text-green-100">{currentMedia.title}</div>
              {currentMedia.artist && (
                <div className="text-green-300 text-sm">{currentMedia.artist}</div>
              )}
            </div>
          )}

          <div className="flex gap-2 items-center justify-center mb-4">
            <button
              onClick={() => navigateQueue('prev')}
              className="px-4 py-2 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
              disabled={!electron}
            >
              ⏮️
            </button>
            <button
              onClick={() => controlPlayer('play')}
              className="px-4 py-2 rounded-lg bg-green-600 hover:bg-green-700 transition-colors"
              disabled={!electron}
            >
              ▶️
            </button>
            <button
              onClick={() => controlPlayer('pause')}
              className="px-4 py-2 rounded-lg bg-yellow-600 hover:bg-yellow-700 transition-colors"
              disabled={!electron}
            >
              ⏸️
            </button>
            <button
              onClick={() => controlPlayer('stop')}
              className="px-4 py-2 rounded-lg bg-red-600 hover:bg-red-700 transition-colors"
              disabled={!electron}
            >
              ⏹️
            </button>
            <button
              onClick={() => navigateQueue('next')}
              className="px-4 py-2 rounded-lg bg-white/10 hover:bg-white/20 transition-colors"
              disabled={!electron}
            >
              ⏭️
            </button>
          </div>
        </div>
      </div>
    </LicenseGate>
  );
}
