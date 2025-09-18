// src/main/ipcStatsExtended.ts
import { ipcMain } from 'electron';
import { statsManager } from './index.js';

/**
 * Handlers IPC pour les nouvelles fonctionnalités d'analytics étendus
 * Complément aux handlers IPC de base dans ipc.ts
 */

export function registerStatsExtendedIPC() {
  console.log('[STATS_EXTENDED] Enregistrement des handlers IPC étendus...');

  // Analytics détaillés pour un média
  ipcMain.handle('stats:getAnalytics', async (_e, id: string) => {
    try {
      const analytics = statsManager.getAnalytics(id);
      return { ok: true, analytics };
    } catch (e: any) {
      console.error('[STATS_EXTENDED] Erreur getAnalytics:', e?.message);
      return { ok: false, error: e?.message || String(e), analytics: null };
    }
  });

  // Métriques globales
  ipcMain.handle('stats:getGlobalMetrics', async () => {
    try {
      const metrics = statsManager.getGlobalMetrics();
      return { ok: true, metrics };
    } catch (e: any) {
      console.error('[STATS_EXTENDED] Erreur getGlobalMetrics:', e?.message);
      return { ok: false, error: e?.message || String(e), metrics: null };
    }
  });

  // Anomalies récentes
  ipcMain.handle('stats:getAnomalies', async (_e, limit?: number) => {
    try {
      const anomalies = statsManager.getRecentAnomalies(limit);
      return { ok: true, anomalies };
    } catch (e: any) {
      console.error('[STATS_EXTENDED] Erreur getAnomalies:', e?.message);
      return { ok: false, error: e?.message || String(e), anomalies: [] };
    }
  });

  // Validation d'intégrité
  ipcMain.handle('stats:validateIntegrity', async () => {
    try {
      const validation = await statsManager.validateIntegrity();
      return { ok: true, validation };
    } catch (e: any) {
      console.error('[STATS_EXTENDED] Erreur validateIntegrity:', e?.message);
      return { ok: false, error: e?.message || String(e), validation: null };
    }
  });

  // Export sécurisé des données (pour backup/analytics)
  ipcMain.handle('stats:exportSecure', async (_e, options?: { includeTimechain?: boolean; includeAnomalies?: boolean }) => {
    try {
      const data = statsManager.getAll();
      const globalMetrics = statsManager.getGlobalMetrics();
      
      const exportData = {
        timestamp: new Date().toISOString(),
        deviceId: (statsManager as any).deviceId,
        globalMetrics,
        items: data.map(item => ({
          id: item.id,
          playsCount: item.playsCount,
          totalMs: item.totalMs,
          lastPlayedAt: item.lastPlayedAt,
          ...(options?.includeTimechain && { timechainLength: item.timechain?.length || 0 }),
          ...(options?.includeAnomalies && { anomaliesCount: item.anomalies?.length || 0 })
        }))
      };
      
      return { ok: true, data: exportData };
    } catch (e: any) {
      console.error('[STATS_EXTENDED] Erreur exportSecure:', e?.message);
      return { ok: false, error: e?.message || String(e), data: null };
    }
  });

  // Recherche d'patterns d'usage
  ipcMain.handle('stats:findPatterns', async (_e, timeRange?: 'day' | 'week' | 'month') => {
    try {
      const range = timeRange || 'week';
      const data = statsManager.getAll();
      const now = new Date();
      
      // Calcul de la période
      let startDate: Date;
      switch (range) {
        case 'day':
          startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
          break;
        case 'week':
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
          break;
        case 'month':
          startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
          break;
        default:
          startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      }
      
      // Analyse des patterns
      const patterns = {
        topPlayed: data
          .filter(item => item.lastPlayedAt && new Date(item.lastPlayedAt) >= startDate)
          .sort((a, b) => b.playsCount - a.playsCount)
          .slice(0, 10)
          .map(item => ({
            id: item.id,
            playsCount: item.playsCount,
            totalMs: item.totalMs,
            avgPlayDuration: item.playsCount > 0 ? item.totalMs / item.playsCount : 0
          })),
        
        recentActivity: data
          .filter(item => item.lastPlayedAt && new Date(item.lastPlayedAt) >= startDate)
          .sort((a, b) => (b.lastPlayedAt || '').localeCompare(a.lastPlayedAt || ''))
          .slice(0, 20)
          .map(item => ({
            id: item.id,
            lastPlayedAt: item.lastPlayedAt,
            playsCount: item.playsCount
          })),
          
        timeRange: {
          start: startDate.toISOString(),
          end: now.toISOString(),
          totalItems: data.length,
          activeItems: data.filter(item => item.lastPlayedAt && new Date(item.lastPlayedAt) >= startDate).length
        }
      };
      
      return { ok: true, patterns };
    } catch (e: any) {
      console.error('[STATS_EXTENDED] Erreur findPatterns:', e?.message);
      return { ok: false, error: e?.message || String(e), patterns: null };
    }
  });

  console.log('[STATS_EXTENDED] ✅ Handlers IPC étendus enregistrés');
}

// Types pour TypeScript côté renderer
export interface StatsExtendedAPI {
  getAnalytics: (id: string) => Promise<{ ok: boolean; analytics?: any; error?: string }>;
  getGlobalMetrics: () => Promise<{ ok: boolean; metrics?: any; error?: string }>;
  getAnomalies: (limit?: number) => Promise<{ ok: boolean; anomalies?: any[]; error?: string }>;
  validateIntegrity: () => Promise<{ ok: boolean; validation?: any; error?: string }>;
  exportSecure: (options?: { includeTimechain?: boolean; includeAnomalies?: boolean }) => Promise<{ ok: boolean; data?: any; error?: string }>;
  findPatterns: (timeRange?: 'day' | 'week' | 'month') => Promise<{ ok: boolean; patterns?: any; error?: string }>;
}
