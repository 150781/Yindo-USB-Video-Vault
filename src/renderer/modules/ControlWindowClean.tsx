/// <reference path="../../types/electron-api.d.ts" />
import React, {
  useEffect,
  useMemo,
  useState,
  useCallback,
  useRef,
} from "react";

// --- Types -------------------------------------------------------------------

type Source = "asset" | "vault";

export type MediaEntry = {
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

export type QueueItem = {
  id: string;
  title: string;
  durationMs?: number | null;
  source: Source;
  src?: string;
  mediaId?: string;
};

export type QueueState = {
  items: QueueItem[];
  currentIndex: number;
  isPlaying: boolean;
  isPaused: boolean;
  repeatMode: "none" | "one" | "all";
  shuffleMode: boolean;
};

type ElectronAPI = any; // si tu as des .d.ts pour l'API preload, remplace "any" par tes types

// --- Cache local pour les durées détectées -----------------------------------
const durationCache: Record<string, number | null> = {};

// --- Composants "placeholder" si absents -------------------------------------
// Remplace ces deux imports si tu as déjà les composants réels.
const SecurityControl: React.FC<{
  locked: boolean;
  passphrase: string;
  onUnlock: (pp: string) => void;
}> = ({ locked, passphrase, onUnlock }) => {
  if (!locked) return null;
  return (
    <div style={{ padding: 12, border: "1px solid #555", marginBottom: 12 }}>
      <h3>Verrouillé</h3>
      <input
        value={passphrase}
        onChange={(e: React.ChangeEvent<HTMLInputElement>) =>
          onUnlock(e.target.value)
        }
        placeholder="Passphrase"
      />
    </div>
  );
};

const AnalyticsMonitor: React.FC<{ stats: Record<string, number> }> = ({
  stats,
}) => {
  const total = useMemo(
    () => Object.values(stats).reduce((a, b) => a + (b || 0), 0),
    [stats]
  );
  return (
    <div style={{ padding: 8, opacity: 0.8 }}>
      <small>Lectures totales: {total}</small>
    </div>
  );
};

// --- Composant principal ------------------------------------------------------

const ControlWindowClean: React.FC = () => {
  // Sécurité d'accès à window.electron
  const electron: ElectronAPI = (window as any)?.electron ?? {};

  // Détection progressive de l'API preload
  const [electronReady, setElectronReady] = useState<boolean>(
    !!(window as any)?.electron
  );

  // UI / données
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

  // Playlist / lecteur
  const [queue, setQueue] = useState<QueueState>({
    items: [],
    currentIndex: -1,
    isPlaying: false,
    isPaused: false,
    repeatMode: "none",
    shuffleMode: false,
  });

  // Volume
  const [volume, setVolume] = useState<number>(1.0);
  const [isMuted, setIsMuted] = useState<boolean>(false);
  const [previousVolume, setPreviousVolume] = useState<number>(1.0);

  // Drag & drop state
  const [draggedItem, setDraggedItem] = useState<number | null>(null);
  const [draggedFromCatalog, setDraggedFromCatalog] =
    useState<MediaEntry | null>(null);
  const [dragOverIndex, setDragOverIndex] = useState<number | null>(null);
  const [dragRefreshKey, setDragRefreshKey] = useState<number>(0);

  const isDropInProgress = useRef<boolean>(false);

  // --- Effets -----------------------------------------------------------------

  // Veille l'apparition de window.electron
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

  // Pings activité (auto-lock)
  useEffect(() => {
    if (!electronReady) return;
    const ping = () => electron?.session?.activity?.();
    const onMove = () => ping();
    const onKey = () => ping();
    window.addEventListener("mousemove", onMove);
    window.addEventListener("keydown", onKey);
    const id = window.setInterval(ping, 15_000);
    return () => {
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("keydown", onKey);
      window.clearInterval(id);
    };
  }, [electronReady, electron]);

  // Statut licence + auto-lock events
  useEffect(() => {
    if (!electronReady) return;

    let offLocked: (() => void) | undefined;
    (async () => {
      try {
        const st = await electron?.license?.status?.();
        setLocked(!!st?.locked);
      } catch {
        setLocked(false);
      }
    })();

    if (electron?.session?.onLocked) {
      offLocked = electron.session.onLocked(() => setLocked(true));
    }
    return () => {
      if (typeof offLocked === "function") offLocked();
    };
  }, [electronReady, electron]);

  // Chargement Stats
  const loadStats = useCallback(async () => {
    try {
      const res: unknown = await electron?.stats?.get?.();

      if (Array.isArray(res)) {
        const map = Object.fromEntries(
          res
            .filter(Boolean)
            .map((x: any) => [x.id as string, x?.playsCount ?? 0])
        );
        setStats(map);
        return;
      }

      if (res && typeof res === "object" && Array.isArray((res as any).list)) {
        const map = Object.fromEntries(
          (res as any).list.map((x: any) => [x.id as string, x?.playsCount ?? 0])
        );
        setStats(map);
        return;
      }

      if (
        res &&
        typeof res === "object" &&
        (res as any).byId &&
        typeof (res as any).byId === "object"
      ) {
        const byId = (res as any).byId as Record<string, unknown>;
        const map = Object.fromEntries(
          Object.entries(byId).map(([id, v]) => {
            const count =
              typeof v === "number"
                ? v
                : (v as any)?.playsCount ??
                (v as any)?.count ??
                (v as any)?.plays ??
                0;
            return [id, count as number];
          })
        );
        setStats(map);
        return;
      }

      if (res && typeof res === "object") {
        setStats(res as Record<string, number>);
        return;
      }

      setStats({});
    } catch (e) {
      console.warn("[control] Erreur chargement stats :", e);
      setStats({});
    }
  }, [electron]);

  // Chargement Catalogue
  const probeDuration = useCallback(async (entry: MediaEntry): Promise<number | null> => {
    try {
      if (!entry) return null;
      if (entry.id in durationCache) return durationCache[entry.id];

      return await new Promise<number | null>((resolve) => {
        const v = document.createElement("video");
        v.preload = "metadata";
        v.muted = true;
        v.onloadedmetadata = () => {
          const ms = isFinite(v.duration) ? Math.round(v.duration * 1000) : 0;
          durationCache[entry.id] = ms || null;
          v.remove();
          resolve(ms || null);
        };
        v.onerror = () => {
          durationCache[entry.id] = null;
          v.remove();
          resolve(null);
        };
        v.src = entry.mediaId
          ? `vault://media/${entry.mediaId}`
          : entry.src || "";
      });
    } catch {
      return null;
    }
  }, []);

  const loadCatalogue = useCallback(async () => {
    try {
      setIsLoading(true);
      const res: any = await electron?.catalog?.list?.();
      const list = Array.isArray(res) ? res : res?.list;
      const safe: MediaEntry[] = Array.isArray(list) ? list : [];

      const withCache = safe.map((entry: MediaEntry) => {
        if (entry?.id && entry.id in durationCache) {
          return { ...entry, durationMs: durationCache[entry.id] };
        }
        return entry;
      });

      setCatalogue(withCache);

      // probe limité
      const missing = withCache
        .filter(
          (e) => e && (e.durationMs == null) && !(e.id in durationCache)
        )
        .slice(0, 8);

      missing.forEach(async (entry) => {
        const ms = await probeDuration(entry);
        if (ms && ms > 0) {
          durationCache[entry.id] = ms;
          setCatalogue((prev: MediaEntry[]) =>
            prev.map((x) => (x.id === entry.id ? { ...x, durationMs: ms } : x))
          );
        }
      });
    } catch (e) {
      console.warn("[control] Erreur chargement catalogue :", e);
      setCatalogue([]);
    } finally {
      setIsLoading(false);
    }
  }, [electron, probeDuration]);

  // Chargement Queue
  const loadQueue = useCallback(async () => {
    try {
      const queueData: Partial<QueueState> | undefined =
        await electron?.queue?.get?.();
      if (queueData) {
        setQueue((prev: QueueState) => ({ ...prev, ...queueData }));
      }
    } catch (e) {
      console.warn("[control] Erreur chargement queue :", e);
    }
  }, [electron]);

  // Initial fetchs
  useEffect(() => {
    if (!electronReady) return;
    void loadStats();
    void loadCatalogue();
    void loadQueue();
  }, [electronReady, loadStats, loadCatalogue, loadQueue]);

  // Persist volume
  useEffect(() => {
    const savedVolume = localStorage.getItem("yindo-volume");
    const savedMute = localStorage.getItem("yindo-muted");

    if (savedVolume !== null) {
      const vol = parseFloat(savedVolume);
      if (!Number.isNaN(vol) && vol >= 0 && vol <= 1) {
        setVolume(vol);
      }
    }
    if (savedMute !== null) {
      setIsMuted(savedMute === "true");
    }
  }, []);
  useEffect(() => {
    localStorage.setItem("yindo-volume", volume.toString());
  }, [volume]);
  useEffect(() => {
    localStorage.setItem("yindo-muted", isMuted.toString());
  }, [isMuted]);

  // Métadonnées envoyées par l'écran display
  useEffect(() => {
    if (!electronReady) return;

    const onMeta = (payload: { id?: string; durationMs?: number }) => {
      if (!payload?.id || !payload?.durationMs) return;
      durationCache[payload.id] = payload.durationMs;
      setCatalogue((prev: MediaEntry[]) =>
        prev.map((x) =>
          x.id === payload.id ? { ...x, durationMs: payload.durationMs! } : x
        )
      );
    };

    electron?.ipc?.on?.("player:meta", onMeta);
    return () => electron?.ipc?.off?.("player:meta", onMeta);
  }, [electronReady, electron]);

  // Mises à jour stats depuis DisplayApp
  useEffect(() => {
    if (!electronReady) return;

    const onStatsUpdated = async (_payload: { id?: string }) => {
      await loadStats();
    };

    electron?.ipc?.on?.("stats:updated", onStatsUpdated);
    return () => electron?.ipc?.off?.("stats:updated", onStatsUpdated);
  }, [electronReady, electron, loadStats]);

  // Statut player
  useEffect(() => {
    if (!electronReady) return;

    const onStatusUpdate = (payload: {
      isPlaying: boolean;
      isPaused: boolean;
      currentTime?: number;
    }) => {
      setQueue((prev: QueueState) => ({
        ...prev,
        isPlaying: payload.isPlaying,
        isPaused: payload.isPaused,
      }));
    };

    electron?.ipc?.on?.("player:status:update", onStatusUpdate);
    return () => electron?.ipc?.off?.("player:status:update", onStatusUpdate);
  }, [electronReady, electron]);

  // --- Actions player/queue ---------------------------------------------------

  const playItem = useCallback(
    async (item: MediaEntry) => {
      try {
        await electron?.queue?.playNow?.(item);
        setQueue((prev: QueueState) => ({
          ...prev,
          isPlaying: true,
          isPaused: false,
        }));
        await loadQueue();
      } catch (e) {
        console.warn("[control] Erreur lecture :", e);
      }
    },
    [electron, loadQueue]
  );

  const addToQueue = useCallback(
    async (items: MediaEntry | MediaEntry[]) => {
      try {
        const itemsArray = Array.isArray(items) ? items : [items];
        await electron?.queue?.addMany?.(itemsArray);
        await loadQueue();
      } catch (e) {
        console.warn("[control] Erreur ajout queue :", e);
      }
    },
    [electron, loadQueue]
  );

  const removeFromQueue = useCallback(
    async (index: number) => {
      try {
        await electron?.queue?.removeAt?.(index);
        await loadQueue();
      } catch (e) {
        console.warn("[control] Erreur suppression queue :", e);
      }
    },
    [electron, loadQueue]
  );

  // --- Drag & Drop playlist ---------------------------------------------------

  const resetDragState = useCallback(() => {
    setDraggedItem(null);
    setDraggedFromCatalog(null);
    setDragOverIndex(null);
    setDragRefreshKey((prev: number) => prev + 1);

    setTimeout(() => {
      const playlistItems = document.querySelectorAll("[data-playlist-item]");
      playlistItems.forEach((el) => {
        const html = el as HTMLElement;
        html.style.opacity = "1";
        html.setAttribute("draggable", "true");
        html.style.cursor = "move";
      });
    }, 50);
  }, []);

  useEffect(() => {
    if (queue.items.length > 0 && (draggedItem !== null || dragOverIndex !== null)) {
      resetDragState();
    }
  }, [queue.items.length, draggedItem, dragOverIndex, resetDragState]);

  useEffect(() => {
    const handleGlobalMouseUp = () => {
      if (draggedItem !== null) {
        setTimeout(() => resetDragState(), 100);
      }
    };
    const handleGlobalDragEnd = (_e: DragEvent) => {
      if (draggedItem !== null) {
        setTimeout(() => resetDragState(), 100);
      }
    };
    document.addEventListener("mouseup", handleGlobalMouseUp);
    document.addEventListener("dragend", handleGlobalDragEnd);
    return () => {
      document.removeEventListener("mouseup", handleGlobalMouseUp);
      document.removeEventListener("dragend", handleGlobalDragEnd);
    };
  }, [draggedItem, resetDragState]);

  const handlePlaylistDragStart = useCallback(
    (e: React.DragEvent<HTMLElement>, index: number) => {
      e.stopPropagation();
      if (index < 0 || index >= queue.items.length) return;
      if (draggedItem !== null) return;

      setDraggedItem(null);
      setDragOverIndex(null);

      setTimeout(() => setDraggedItem(index), 0);

      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/playlist-item", index.toString());
    },
    [draggedItem, queue.items.length]
  );

  const handlePlaylistDragOver = useCallback(
    (e: React.DragEvent<HTMLElement>, overIndex: number) => {
      e.preventDefault();
      if (draggedItem === null) return;
      if (overIndex < 0 || overIndex >= queue.items.length) return;
      if (dragOverIndex !== overIndex) {
        setDragOverIndex(overIndex);
      }
    },
    [draggedItem, dragOverIndex, queue.items.length]
  );

  const handlePlaylistDrop = useCallback(
    async (_e: React.DragEvent<HTMLElement>, dropIndex: number) => {
      if (isDropInProgress.current) return;
      isDropInProgress.current = true;
      try {
        if (draggedItem === null) return;
        if (dropIndex < 0 || dropIndex >= queue.items.length) return;
        if (draggedItem === dropIndex) return;

        await electron?.queue?.move?.(draggedItem, dropIndex);
        await loadQueue();
      } finally {
        resetDragState();
        isDropInProgress.current = false;
      }
    },
    [draggedItem, queue.items.length, electron, loadQueue, resetDragState]
  );

  // --- Filtres ----------------------------------------------------------------

  const filteredCatalogue = useMemo(() => {
    const term = searchTerm.trim().toLowerCase();
    return catalogue.filter((item: MediaEntry) => {
      if (selectedGenre !== "Tout" && (item.genre ?? "") !== selectedGenre) {
        return false;
      }
      if (selectedYear !== "Toutes") {
        const y = Number(selectedYear);
        if (!Number.isNaN(y) && item.year !== y) return false;
      }
      if (selectedArtist !== "Tous" && (item.artist ?? "") !== selectedArtist) {
        return false;
      }
      if (!term) return true;
      const hay = `${item.title} ${item.artist ?? ""} ${item.genre ?? ""} ${item.year ?? ""
        }`.toLowerCase();
      return hay.includes(term);
    });
  }, [catalogue, searchTerm, selectedGenre, selectedYear, selectedArtist]);

  const genres = useMemo<string[]>(() => {
    const s = new Set<string>(["Tout"]);
    catalogue.forEach((x) => x.genre && s.add(x.genre));
    return Array.from(s);
  }, [catalogue]);

  const years = useMemo<string[]>(() => {
    const s = new Set<string>(["Toutes"]);
    catalogue.forEach((x) => typeof x.year === "number" && s.add(String(x.year)));
    return Array.from(s);
  }, [catalogue]);

  const artists = useMemo<string[]>(() => {
    const s = new Set<string>(["Tous"]);
    catalogue.forEach((x) => x.artist && s.add(x.artist));
    return Array.from(s);
  }, [catalogue]);

  // --- UI Handlers ------------------------------------------------------------

  const onChangeSearch = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => setSearchTerm(e.target.value),
    []
  );
  const onChangeGenre = useCallback(
    (e: React.ChangeEvent<HTMLSelectElement>) => setSelectedGenre(e.target.value),
    []
  );
  const onChangeYear = useCallback(
    (e: React.ChangeEvent<HTMLSelectElement>) => setSelectedYear(e.target.value),
    []
  );
  const onChangeArtist = useCallback(
    (e: React.ChangeEvent<HTMLSelectElement>) =>
      setSelectedArtist(e.target.value),
    []
  );

  const toggleMute = useCallback(() => {
    setIsMuted((prev: boolean) => {
      if (!prev) setPreviousVolume(volume);
      else setVolume(previousVolume);
      return !prev;
    });
  }, [previousVolume, volume]);

  const onChangeVolume = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const v = Math.max(0, Math.min(1, Number(e.target.value)));
      setVolume(v);
      if (v === 0) setIsMuted(true);
      else if (isMuted) setIsMuted(false);
      electron?.player?.setVolume?.(v);
    },
    [electron, isMuted]
  );

  const getPlays = useCallback(
    (id: string): number => stats[id] ?? 0,
    [stats]
  );

  // --- Render -----------------------------------------------------------------

  return (
    <div style={{ padding: 16 }}>
      {/* Sécurité */}
      <SecurityControl
        locked={locked}
        passphrase={passphrase}
        onUnlock={(pp: string) => setPassphrase(pp)}
      />

      {/* Filtres */}
      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        <input
          placeholder="Rechercher…"
          value={searchTerm}
          onChange={onChangeSearch}
        />
        <select value={selectedGenre} onChange={onChangeGenre}>
          {genres.map((g) => (
            <option key={g} value={g}>
              {g}
            </option>
          ))}
        </select>
        <select value={selectedYear} onChange={onChangeYear}>
          {years.map((y) => (
            <option key={y} value={y}>
              {y}
            </option>
          ))}
        </select>
        <select value={selectedArtist} onChange={onChangeArtist}>
          {artists.map((a) => (
            <option key={a} value={a}>
              {a}
            </option>
          ))}
        </select>
      </div>

      {/* Catalogue */}
      <div style={{ marginBottom: 16 }}>
        <h3>Catalogue {isLoading ? "(chargement…)" : ""}</h3>
        <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
          {filteredCatalogue.map((item: MediaEntry) => (
            <li
              key={item.id}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                padding: "6px 0",
                borderBottom: "1px solid #eee",
              }}
            >
              <button onClick={() => playItem(item)}>▶</button>
              <button onClick={() => addToQueue(item)}>＋ file d'attente</button>
              <span style={{ flex: 1 }}>
                {item.title}{" "}
                <small style={{ opacity: 0.7 }}>
                  {item.artist ? `— ${item.artist} ` : ""}
                  {item.genre ? `(${item.genre}) ` : ""}
                  {typeof item.year === "number" ? `• ${item.year}` : ""}
                  {typeof item.durationMs === "number"
                    ? ` • ${Math.round(item.durationMs / 1000)}s`
                    : ""}
                  {` • vues: ${getPlays(item.id)}`}
                </small>
              </span>
            </li>
          ))}
        </ul>
      </div>

      {/* Playlist */}
      <div>
        <h3>File d'attente</h3>
        <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
          {queue.items.map((qi: QueueItem, index: number) => (
            <li
              key={`${qi.id}-${index}-${dragRefreshKey}`}
              data-playlist-item
              draggable
              onDragStart={(e: React.DragEvent<HTMLLIElement>) =>
                handlePlaylistDragStart(e, index)
              }
              onDragOver={(e: React.DragEvent<HTMLLIElement>) =>
                handlePlaylistDragOver(e, index)
              }
              onDrop={(e: React.DragEvent<HTMLLIElement>) =>
                handlePlaylistDrop(e, index)
              }
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                padding: "6px 0",
                borderBottom: "1px solid #eee",
                background:
                  dragOverIndex === index ? "rgba(0, 128, 255, 0.08)" : "none",
                cursor: "move",
              }}
            >
              <span style={{ width: 18, textAlign: "center" }}>≡</span>
              <button onClick={() => removeFromQueue(index)}>✕</button>
              <span style={{ flex: 1 }}>
                {qi.title}{" "}
                <small style={{ opacity: 0.7 }}>
                  {typeof qi.durationMs === "number"
                    ? `(${Math.round(qi.durationMs / 1000)}s)`
                    : ""}
                </small>
              </span>
              {index === queue.currentIndex && (
                <span style={{ fontSize: 12, opacity: 0.7 }}>(en cours)</span>
              )}
            </li>
          ))}
        </ul>
      </div>

      {/* Volume */}
      <div style={{ marginTop: 16 }}>
        <button onClick={toggleMute}>{isMuted ? "🔇" : "🔊"}</button>
        <input
          type="range"
          min={0}
          max={1}
          step={0.01}
          value={volume}
          onChange={onChangeVolume}
        />
      </div>

      {/* Analytics */}
      <AnalyticsMonitor stats={stats} />
    </div>
  );
};

export default ControlWindowClean;
