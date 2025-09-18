export type SourceKind = 'asset' | 'vault';

export interface MediaMeta {
  id: string;               // "asset:<hash>" ou "vault:<uuid>"
  title: string;
  artist?: string;
  genre?: string;
  year?: number;
  durationMs?: number | null;
  source: SourceKind;       // ici "vault"
  sha256: string;           // du FICHIER EN CLAIR
  ext?: string;             // extension d'origine (hint)
}

export interface ManifestJson {
  version: 1;
  createdAt: string;
  items: MediaMeta[];
}

export interface DeviceTag {
  version: 1;
  deviceId: string;         // uuid
  saltHex: string;          // sel pour scrypt
  createdAt: string;
  tool: string;             // e.g. "packager/1.0"
}
