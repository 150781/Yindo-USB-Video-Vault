// src/main/stats.ts
import { promises as fs } from 'fs';
import * as path from 'path';
import * as os from 'os';
import { randomUUID, scryptSync, createCipheriv, createDecipheriv, randomBytes, createHash } from 'crypto';

export interface SessionMetrics {
  dailyPlays: Record<string, number>;   // ISO date -> count
  weeklyPlays: Record<string, number>;  // ISO week -> count
  avgSessionMs: number;                 // moyenne durée session
  peakHours: number[];                  // heures de pic d'usage [0-23]
  lastSessionStarted?: string;          // ISO
  currentSessionMs: number;             // session courante
  totalSessions: number;                // nombre total de sessions
}

export interface TimechainEntry {
  timestamp: string;                    // ISO timestamp
  prevHash: string;                     // hash entrée précédente
  currentHash: string;                  // hash entrée courante
  sequenceNumber: number;               // numéro de séquence
  playEvent: {
    mediaId: string;
    playedMs: number;
    sessionId: string;
  };
}

export interface AnomalyRecord {
  timestamp: string;
  type: 'time-rollback' | 'suspicious-frequency' | 'invalid-sequence' | 'tampering-detected';
  details: string;
  severity: 'low' | 'medium' | 'high';
  resolved: boolean;
}

export interface StatsItem {
  id: string;             // media id (vault:<hash12> ou asset:<...>)
  playsCount: number;     // nb de lectures (incrémenté sur ended)
  totalMs: number;        // temps total joué cumulé (approx via playedMs transmis)
  lastPlayedAt?: string;  // ISO
  
  // Analytics étendus
  sessionData: SessionMetrics;
  timechain: TimechainEntry[];          // blockchain locale pour anti-rollback
  anomalies: AnomalyRecord[];           // détection d'anomalies
  integrity: {
    checksum: string;                   // checksum pour validation intégrité
    lastValidated: string;              // dernière validation
  };
}

export interface StatsFile {
  version: 2;                           // version augmentée pour nouvelles features
  deviceId: string;                     // pour lier au vault courant
  updatedAt: string;
  items: Record<string, StatsItem>;
  
  // Analytics globaux
  globalMetrics: {
    totalSessions: number;
    totalPlaytime: number;              // ms total sur tous médias
    firstUsage: string;                 // ISO première utilisation
    averageSessionDuration: number;     // ms moyenne par session
    peakUsageHours: number[];           // heures de pic global [0-23]
  };
  
  // Anti-rollback global
  integrity: {
    globalSequence: number;             // séquence globale pour timechain
    lastTimestamp: string;              // dernier timestamp valide
    masterChecksum: string;             // checksum global du fichier
    ntpLastSync?: string;               // dernière sync NTP
    suspiciousEvents: AnomalyRecord[];  // événements suspects
  };
}

export class StatsManager {
  private filePath!: string;
  private deviceId!: string;
  private key?: Buffer; // dérivée via scrypt(pass, saltHex)
  private data: StatsFile | null = null;

  /** userData/stats/<deviceId>.bin */
  init(userDataDir: string, deviceId: string) {
    this.deviceId = deviceId;
    this.filePath = path.join(userDataDir, 'stats', `${deviceId}.bin`);
    return fs.mkdir(path.dirname(this.filePath), { recursive: true });
  }

  /** à appeler après unlock(pass) côté vault, avec le même saltHex */
  deriveKey(pass: string, saltHex: string) {
    this.key = scryptSync(pass, Buffer.from(saltHex, 'hex'), 32);
  }

  private ensureKey() {
    if (!this.key) throw new Error('StatsManager locked (no key)');
  }

  async loadOrCreate() {
    this.ensureKey();
    try {
      const enc = await fs.readFile(this.filePath);
      if (enc.length < 12 + 16) throw new Error('corrupted');
      const iv = enc.subarray(0, 12);
      const tag = enc.subarray(enc.length - 16);
      const data = enc.subarray(12, enc.length - 16);
      const decipher = createDecipheriv('aes-256-gcm', this.key!, iv);
      decipher.setAuthTag(tag);
      const plain = Buffer.concat([decipher.update(data), decipher.final()]);
      const parsedData = JSON.parse(plain.toString());
      
      // Migration automatique si nécessaire
      if (parsedData.version === 1) {
        console.log('[STATS] Ancien format détecté, migration en cours...');
        this.data = await this.migrateFromV1(parsedData);
        await this.save(); // Sauvegarde immédiate de la version migrée
      } else if (parsedData.version === 2) {
        this.data = parsedData as StatsFile;
      } else {
        throw new Error(`Version non supportée: ${parsedData.version}`);
      }
      
      // Validation intégrité au chargement
      const validation = await this.validateIntegrity();
      if (!validation.valid) {
        console.warn('[STATS] ⚠️ Problèmes d\'intégrité détectés:', validation.issues.length);
        validation.issues.forEach(issue => console.warn('[STATS]', issue));
      } else {
        console.log('[STATS] ✅ Intégrité validée:', validation.statistics);
      }
    } catch (err) {
      console.log('[STATS] Création nouveau fichier stats v2');
      // Créer nouveau fichier avec structure étenddue
      this.data = { 
        version: 2, 
        deviceId: this.deviceId, 
        updatedAt: new Date().toISOString(), 
        items: {},
        globalMetrics: {
          totalSessions: 0,
          totalPlaytime: 0,
          firstUsage: new Date().toISOString(),
          averageSessionDuration: 0,
          peakUsageHours: []
        },
        integrity: {
          globalSequence: 0,
          lastTimestamp: new Date().toISOString(),
          masterChecksum: '',
          suspiciousEvents: []
        }
      };
      await this.save();
    }
  }

  private async save() {
    this.ensureKey();
    const plain = Buffer.from(JSON.stringify(this.data), 'utf8');
    const iv = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key!, iv);
    const enc = Buffer.concat([cipher.update(plain), cipher.final()]);
    const tag = cipher.getAuthTag();
    const out = Buffer.concat([iv, enc, tag]);
    await fs.writeFile(this.filePath, out);
  }

  /** Incrémente la lecture pour un media avec analytics étendus et anti-rollback */
  async markPlayed(id: string, playedMs: number, sessionId?: string) {
    if (!this.data) await this.loadOrCreate();
    
    const now = new Date().toISOString();
    const actualSessionId = sessionId || this.generateSessionId();
    
    // Validation timestamp
    if (!this.validateTimestamp(now)) {
      console.warn('[STATS] Timestamp invalide, lecture ignorée');
      return null;
    }
    
    // Détection d'anomalies
    const anomalies = this.detectAnomalies(now, id);
    if (anomalies.some(a => a.severity === 'high')) {
      console.error('[STATS] Anomalie critique détectée, arrêt traitement');
      // Enregistrer l'anomalie mais ne pas traiter la lecture
      this.data!.integrity.suspiciousEvents.push(...anomalies);
      await this.save();
      throw new Error('Anomalie de sécurité détectée - lecture refusée');
    }
    
    // Initialisation/récupération item
    const item = this.initializeItemIfNeeded(id);
    
    // Création entrée timechain
    const timechainEntry = this.createTimechainEntry(id, playedMs, actualSessionId);
    
    // Mise à jour données de base
    item.playsCount += 1;
    item.totalMs += Math.max(0, Math.round(playedMs || 0));
    item.lastPlayedAt = now;
    
    // Mise à jour analytics
    this.updateSessionMetrics(item, playedMs);
    item.timechain.push(timechainEntry);
    
    // Limitation timechain (garder max 1000 entrées)
    if (item.timechain.length > 1000) {
      item.timechain = item.timechain.slice(-1000);
    }
    
    // Ajout anomalies détectées (non critiques)
    item.anomalies.push(...anomalies.filter(a => a.severity !== 'high'));
    
    // Limitation anomalies (garder max 100 entrées)
    if (item.anomalies.length > 100) {
      item.anomalies = item.anomalies.slice(-100);
    }
    
    // Mise à jour intégrité item
    item.integrity = {
      checksum: this.calculateChecksum(item),
      lastValidated: now
    };
    
    // Mise à jour métriques globales
    this.updateGlobalMetrics(playedMs);
    
    // Mise à jour intégrité globale
    this.data!.integrity.globalSequence += 1;
    this.data!.integrity.lastTimestamp = now;
    this.data!.updatedAt = now;
    this.data!.integrity.masterChecksum = this.calculateChecksum(this.data);
    
    await this.save();
    
    console.log(`[STATS] ✅ Lecture enregistrée: ${id} (${playedMs}ms) -> ${item.playsCount} lectures [seq:${this.data!.integrity.globalSequence}]`);
    
    return item;
  }

  getAll(limit = 100) {
    if (!this.data) return [];
    const arr = Object.values(this.data.items);
    arr.sort((a, b) => (b.lastPlayedAt || '').localeCompare(a.lastPlayedAt || ''));
    return arr.slice(0, limit);
  }

  getOne(id: string) {
    if (!this.data) return null;
    return this.data.items[id] || null;
  }

  lock() {
    this.key = undefined;
    this.data = null;
  }

  // ================================================================================
  // ANALYTICS AVANCÉS & ANTI-ROLLBACK
  // ================================================================================

  private generateSessionId(): string {
    return `session_${Date.now()}_${randomUUID().slice(0, 8)}`;
  }

  private calculateChecksum(data: any): string {
    const str = JSON.stringify(data, Object.keys(data).sort());
    return createHash('sha256').update(str).digest('hex').slice(0, 16);
  }

  private validateTimestamp(timestamp: string): boolean {
    const now = Date.now();
    const ts = new Date(timestamp).getTime();
    
    // Tolérance de 5 minutes dans le futur, pas de limite dans le passé pour recovery
    const futureLimit = now + (5 * 60 * 1000);
    
    if (ts > futureLimit) {
      console.warn('[STATS] Timestamp suspect (futur):', timestamp);
      return false;
    }
    
    return true;
  }

  private detectAnomalies(newTimestamp: string, mediaId: string): AnomalyRecord[] {
    if (!this.data) return [];
    
    const anomalies: AnomalyRecord[] = [];
    const now = new Date();
    const newTs = new Date(newTimestamp);
    
    // 1. Détection rollback temporel
    if (this.data.integrity.lastTimestamp) {
      const lastTs = new Date(this.data.integrity.lastTimestamp);
      if (newTs < lastTs) {
        anomalies.push({
          timestamp: newTimestamp,
          type: 'time-rollback',
          details: `Timestamp ${newTimestamp} antérieur au dernier timestamp ${this.data.integrity.lastTimestamp}`,
          severity: 'high',
          resolved: false
        });
      }
    }

    // 2. Détection fréquence suspecte (plus de 10 lectures/minute)
    const item = this.data.items[mediaId];
    if (item && item.timechain.length > 0) {
      const recentPlays = item.timechain.filter(entry => {
        const entryTime = new Date(entry.timestamp);
        return (now.getTime() - entryTime.getTime()) < 60000; // dernière minute
      });
      
      if (recentPlays.length > 10) {
        anomalies.push({
          timestamp: newTimestamp,
          type: 'suspicious-frequency',
          details: `${recentPlays.length} lectures dans la dernière minute pour ${mediaId}`,
          severity: 'medium',
          resolved: false
        });
      }
    }

    return anomalies;
  }

  private createTimechainEntry(mediaId: string, playedMs: number, sessionId: string): TimechainEntry {
    if (!this.data) throw new Error('StatsManager not initialized');
    
    const timestamp = new Date().toISOString();
    const item = this.data.items[mediaId];
    const prevHash = item?.timechain?.slice(-1)[0]?.currentHash || '0'.repeat(64);
    
    const entryData = {
      timestamp,
      prevHash,
      sequenceNumber: this.data.integrity.globalSequence + 1,
      playEvent: { mediaId, playedMs, sessionId }
    };
    
    const currentHash = this.calculateChecksum(entryData);
    
    return {
      ...entryData,
      currentHash
    };
  }

  private initializeItemIfNeeded(id: string): StatsItem {
    if (!this.data) throw new Error('StatsManager not initialized');
    
    if (!this.data.items[id]) {
      this.data.items[id] = {
        id,
        playsCount: 0,
        totalMs: 0,
        sessionData: {
          dailyPlays: {},
          weeklyPlays: {},
          avgSessionMs: 0,
          peakHours: [],
          currentSessionMs: 0,
          totalSessions: 0
        },
        timechain: [],
        anomalies: [],
        integrity: {
          checksum: '',
          lastValidated: new Date().toISOString()
        }
      };
    }
    
    return this.data.items[id];
  }

  private updateSessionMetrics(item: StatsItem, playedMs: number) {
    const now = new Date();
    const dateKey = now.toISOString().split('T')[0]; // YYYY-MM-DD
    const weekKey = this.getISOWeek(now);
    const hour = now.getHours();
    
    // Mise à jour métriques quotidiennes/hebdomadaires
    item.sessionData.dailyPlays[dateKey] = (item.sessionData.dailyPlays[dateKey] || 0) + 1;
    item.sessionData.weeklyPlays[weekKey] = (item.sessionData.weeklyPlays[weekKey] || 0) + 1;
    
    // Mise à jour heures de pic
    if (!item.sessionData.peakHours.includes(hour)) {
      item.sessionData.peakHours.push(hour);
      item.sessionData.peakHours.sort((a, b) => a - b);
    }
    
    // Mise à jour session courante
    item.sessionData.currentSessionMs += playedMs;
    
    // Recalcul moyenne session
    if (item.sessionData.totalSessions > 0) {
      item.sessionData.avgSessionMs = 
        (item.sessionData.avgSessionMs * item.sessionData.totalSessions + playedMs) / 
        (item.sessionData.totalSessions + 1);
    } else {
      item.sessionData.avgSessionMs = playedMs;
    }
  }

  private updateGlobalMetrics(playedMs: number) {
    if (!this.data) return;
    
    this.data.globalMetrics.totalPlaytime += playedMs;
    this.data.globalMetrics.totalSessions += 1;
    
    if (this.data.globalMetrics.totalSessions > 0) {
      this.data.globalMetrics.averageSessionDuration = 
        this.data.globalMetrics.totalPlaytime / this.data.globalMetrics.totalSessions;
    }
  }

  private getISOWeek(date: Date): string {
    const year = date.getFullYear();
    const start = new Date(year, 0, 1);
    const days = Math.floor((date.getTime() - start.getTime()) / (24 * 60 * 60 * 1000));
    const week = Math.ceil((days + start.getDay() + 1) / 7);
    return `${year}-W${week.toString().padStart(2, '0')}`;
  }

  // ================================================================================
  // NOUVELLES MÉTHODES PUBLIQUES POUR ANALYTICS
  // ================================================================================

  /** Récupère les analytics détaillés pour un média */
  getAnalytics(id: string) {
    if (!this.data || !this.data.items[id]) return null;
    
    const item = this.data.items[id];
    return {
      basic: {
        playsCount: item.playsCount,
        totalMs: item.totalMs,
        lastPlayedAt: item.lastPlayedAt
      },
      session: item.sessionData,
      security: {
        timechainLength: item.timechain.length,
        anomaliesCount: item.anomalies.length,
        lastValidated: item.integrity.lastValidated,
        integrityStatus: item.integrity.checksum ? 'valid' : 'unknown'
      }
    };
  }

  /** Récupère les métriques globales */
  getGlobalMetrics() {
    if (!this.data) return null;
    
    return {
      ...this.data.globalMetrics,
      integrity: {
        totalSequences: this.data.integrity.globalSequence,
        suspiciousEventsCount: this.data.integrity.suspiciousEvents.length,
        lastTimestamp: this.data.integrity.lastTimestamp,
        integrityStatus: this.data.integrity.masterChecksum ? 'valid' : 'unknown'
      }
    };
  }

  /** Récupère les anomalies récentes */
  getRecentAnomalies(limit = 50) {
    if (!this.data) return [];
    
    const allAnomalies: (AnomalyRecord & { source: string })[] = [];
    
    // Anomalies globales
    this.data.integrity.suspiciousEvents.forEach(anomaly => {
      allAnomalies.push({ ...anomaly, source: 'global' });
    });
    
    // Anomalies par média
    Object.entries(this.data.items).forEach(([mediaId, item]) => {
      item.anomalies.forEach(anomaly => {
        allAnomalies.push({ ...anomaly, source: mediaId });
      });
    });
    
    // Tri par timestamp décroissant
    allAnomalies.sort((a, b) => b.timestamp.localeCompare(a.timestamp));
    
    return allAnomalies.slice(0, limit);
  }

  /** Valide l'intégrité complète des données */
  async validateIntegrity() {
    if (!this.data) await this.loadOrCreate();
    
    const issues: string[] = [];
    let validEntries = 0;
    let corruptedEntries = 0;
    
    // Validation de chaque média
    Object.entries(this.data!.items).forEach(([mediaId, item]) => {
      try {
        // Vérification checksum
        const expectedChecksum = this.calculateChecksum(item);
        if (item.integrity.checksum !== expectedChecksum) {
          issues.push(`Checksum invalide pour ${mediaId}`);
          corruptedEntries++;
        } else {
          validEntries++;
        }
        
        // Vérification timechain
        for (let i = 1; i < item.timechain.length; i++) {
          const current = item.timechain[i];
          const previous = item.timechain[i - 1];
          
          if (current.prevHash !== previous.currentHash) {
            issues.push(`Chaîne temporelle brisée pour ${mediaId} à l'index ${i}`);
            corruptedEntries++;
          }
        }
      } catch (error) {
        issues.push(`Erreur validation ${mediaId}: ${error}`);
        corruptedEntries++;
      }
    });
    
    // Validation globale
    const expectedMasterChecksum = this.calculateChecksum(this.data);
    if (this.data!.integrity.masterChecksum !== expectedMasterChecksum) {
      issues.push('Checksum global invalide');
    }
    
    const result = {
      valid: issues.length === 0,
      issues,
      statistics: {
        totalItems: Object.keys(this.data!.items).length,
        validEntries,
        corruptedEntries,
        globalSequence: this.data!.integrity.globalSequence
      }
    };
    
    console.log('[STATS] Validation intégrité:', result);
    return result;
  }

  /** Migration automatique depuis ancien format (version 1) */
  private async migrateFromV1(oldData: any) {
    console.log('[STATS] Migration depuis format v1...');
    
    const migratedData: StatsFile = {
      version: 2,
      deviceId: oldData.deviceId,
      updatedAt: new Date().toISOString(),
      items: {},
      globalMetrics: {
        totalSessions: 0,
        totalPlaytime: 0,
        firstUsage: oldData.updatedAt || new Date().toISOString(),
        averageSessionDuration: 0,
        peakUsageHours: []
      },
      integrity: {
        globalSequence: 0,
        lastTimestamp: new Date().toISOString(),
        masterChecksum: '',
        suspiciousEvents: []
      }
    };
    
    // Migration des items existants
    Object.entries(oldData.items || {}).forEach(([id, oldItem]: [string, any]) => {
      const sessionId = this.generateSessionId();
      
      migratedData.items[id] = {
        id,
        playsCount: oldItem.playsCount || 0,
        totalMs: oldItem.totalMs || 0,
        lastPlayedAt: oldItem.lastPlayedAt,
        sessionData: {
          dailyPlays: {},
          weeklyPlays: {},
          avgSessionMs: oldItem.totalMs || 0,
          peakHours: [],
          currentSessionMs: 0,
          totalSessions: 1
        },
        timechain: oldItem.lastPlayedAt ? [{
          timestamp: oldItem.lastPlayedAt,
          prevHash: '0'.repeat(64),
          currentHash: this.calculateChecksum({ id, timestamp: oldItem.lastPlayedAt }),
          sequenceNumber: 1,
          playEvent: {
            mediaId: id,
            playedMs: oldItem.totalMs || 0,
            sessionId
          }
        }] : [],
        anomalies: [],
        integrity: {
          checksum: '',
          lastValidated: new Date().toISOString()
        }
      };
      
      // Mise à jour checksum
      migratedData.items[id].integrity.checksum = this.calculateChecksum(migratedData.items[id]);
      
      // Mise à jour métriques globales
      migratedData.globalMetrics.totalPlaytime += oldItem.totalMs || 0;
      migratedData.globalMetrics.totalSessions += oldItem.playsCount || 0;
      migratedData.integrity.globalSequence += 1;
    });
    
    // Checksum global
    migratedData.integrity.masterChecksum = this.calculateChecksum(migratedData);
    
    console.log(`[STATS] Migration terminée: ${Object.keys(migratedData.items).length} items migrés`);
    return migratedData;
  }
}
