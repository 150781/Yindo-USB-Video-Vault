// src/types/shared.ts
export type MediaSource = { mediaId?: string; src?: string }; // vault = mediaId, asset = src
export type QueueItem = MediaSource & {
  id: string;             // unique
  title: string;
  artist?: string;
  year?: number;
  genre?: string;
  durationMs?: number | null;
  source: 'asset' | 'vault';
};

export type QueueState = {
  items: QueueItem[];
  currentIndex: number;   // -1 si rien
  repeat: 'off' | 'one' | 'all';
};

export type MediaEntry = QueueItem;

export type PlaylistStore = {
  items: QueueItem[];
  selectedId?: string | null;
};
