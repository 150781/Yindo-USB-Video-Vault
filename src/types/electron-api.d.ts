export {};

declare global {
  interface Window { electron: ElectronAPI; }
}

type RepeatMode = 'none' | 'one' | 'all';

export interface MediaEntry {
  id: string;
  title: string;
  artist?: string;
  genre?: string;
  year?: number;
  durationMs?: number | null;
  source: 'asset' | 'vault';
  src?: string; // present si source = asset
}

export interface QueueItem {
  id: string;
  title: string;
  durationMs?: number | null;
  source: 'asset' | 'vault';
  src?: string;
}

export interface QueueState {
  items: QueueItem[];
  currentIndex: number;
  isPlaying: boolean;
  isPaused: boolean;
  repeatMode: RepeatMode;
  shuffleMode: boolean;
}

type StatsPlayedPayload = { id: string; playedMs: number };

export interface ElectronAPI {
  ipc: {
    on(channel: string, listener: (...args: any[]) => void): () => void;
    send(channel: string, payload?: any): void;
  };

  // Fenêtres / affichage
  openDisplayWindow(params?: { displayId?: number }): Promise<boolean>;
  closeDisplayWindow(): Promise<boolean>;
  toggleFullscreen(): Promise<boolean>;

  // Licence / session (auto-lock)
  license: {
    enter(pass: string): Promise<{ ok: boolean; error?: string }>;
    enterPassphrase(pass: string): Promise<{ ok: boolean; error?: string }>; // Alias pour compatibilité
  };
  session: {
    activity(): Promise<boolean>; // heartbeat
    status(): Promise<{ locked: boolean }>;
    onLocked(fn: (p: any) => void): () => void;
    onUnlocked(fn: () => void): () => void;
  };

  // Catalogue
  catalog: { list(): Promise<{ list: MediaEntry[] }> };

  // Player & queue
  player: {
    open(payload: { id?: string; mediaId?: string; src?: string; title?: string; artist?: string }): Promise<boolean>;
    control(payload: { action: 'play'|'pause'|'stop'|'seek'|'setVolume'; value?: number }): Promise<boolean>;
    play(): Promise<void>;
    pause(): Promise<void>;
    stop(): Promise<void>;
    seek(time: number): Promise<void>;
    setVolume(volume: number): Promise<void>;
    getStatus(): Promise<{ isPlaying: boolean; paused: boolean; currentTime: number; duration: number }>;
    ended(): void; // event depuis DisplayApp
  };
  queue: {
    get(): Promise<QueueState>;
    add(item: QueueItem): Promise<QueueState>;
    addMany(items: QueueItem[]): Promise<QueueState>;
    removeAt(index: number): Promise<QueueState>;
    clear(): Promise<QueueState>;
    next(): Promise<QueueState>;
    prev(): Promise<QueueState>;
    playNow(item: QueueItem | MediaEntry): Promise<boolean>;
    playAt(index: number): Promise<QueueState>;
    status(): Promise<QueueState>;
    reorder(fromIndex: number, toIndex: number): Promise<QueueState>;
    setRepeat(mode: RepeatMode): Promise<QueueState>;
    getRepeat(): Promise<{ repeatMode: RepeatMode }>;
  };

  // Stats (avec surcharge)
  stats: {
    get(limit?: number): Promise<{ ok: boolean; items: any[] }>;
    getOne(id: string): Promise<{ ok: boolean; item: any | null }>;
    played(payload: StatsPlayedPayload): Promise<{ ok: boolean }>;
    played(id: string, playedMs: number): Promise<{ ok: boolean }>;
    
    // Analytics étendus
    getAnalytics(id: string): Promise<{ ok: boolean; analytics?: any; error?: string }>;
    getGlobalMetrics(): Promise<{ ok: boolean; metrics?: any; error?: string }>;
    getAnomalies(limit?: number): Promise<{ ok: boolean; anomalies?: any[]; error?: string }>;
    validateIntegrity(): Promise<{ ok: boolean; validation?: any; error?: string }>;
    exportSecure(options?: { includeTimechain?: boolean; includeAnomalies?: boolean }): Promise<{ ok: boolean; data?: any; error?: string }>;
    findPatterns(timeRange?: 'day' | 'week' | 'month'): Promise<{ ok: boolean; patterns?: any; error?: string }>;
  };

  // Sécurité du lecteur
  security: {
    getState(): Promise<any>;
    getViolations(since?: number): Promise<any[]>;
    configure(config: any): Promise<{ success: boolean; message?: string; error?: string }>;
    enableFullscreen(): Promise<{ success: boolean; error?: string }>;
    disable(): Promise<{ success: boolean; message?: string; error?: string }>;
    testViolation(type: string, message: string): Promise<{ success: boolean; error?: string }>;
  };
}
