import React, { useState, useEffect } from 'react';
import type { ElectronAPI } from '../../types/electron-api';

interface AnalyticsMonitorProps {
  electron: ElectronAPI;
}

interface GlobalMetrics {
  totalSessions: number;
  totalPlaytime: number;
  firstUsage: string;
  averageSessionDuration: number;
  peakUsageHours: number[];
  integrity: {
    totalSequences: number;
    suspiciousEventsCount: number;
    lastTimestamp: string;
    integrityStatus: string;
  };
}

interface Anomaly {
  timestamp: string;
  type: string;
  details: string;
  severity: 'low' | 'medium' | 'high';
  resolved: boolean;
  source: string;
}

export default function AnalyticsMonitor({ electron }: AnalyticsMonitorProps) {
  const [globalMetrics, setGlobalMetrics] = useState<GlobalMetrics | null>(null);
  const [anomalies, setAnomalies] = useState<Anomaly[]>([]);
  const [integrityStatus, setIntegrityStatus] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadGlobalMetrics = async () => {
    try {
      const result = await electron.stats.getGlobalMetrics();
      if (result.ok) {
        setGlobalMetrics(result.metrics);
      } else {
        console.error('[AnalyticsMonitor] Erreur global metrics:', result.error);
      }
    } catch (err) {
      console.error('[AnalyticsMonitor] Erreur loadGlobalMetrics:', err);
    }
  };

  const loadAnomalies = async () => {
    try {
      const result = await electron.stats.getAnomalies(10);
      if (result.ok) {
        setAnomalies(result.anomalies || []);
      } else {
        console.error('[AnalyticsMonitor] Erreur anomalies:', result.error);
      }
    } catch (err) {
      console.error('[AnalyticsMonitor] Erreur loadAnomalies:', err);
    }
  };

  const validateIntegrity = async () => {
    setLoading(true);
    setError(null);
    try {
      const result = await electron.stats.validateIntegrity();
      if (result.ok) {
        setIntegrityStatus(result.validation);
        if (!result.validation.valid) {
          setError(`${result.validation.issues.length} problème(s) d'intégrité détecté(s)`);
        }
      } else {
        setError(`Erreur validation: ${result.error}`);
      }
    } catch (err) {
      setError(`Erreur: ${err}`);
    } finally {
      setLoading(false);
    }
  };

  const exportData = async () => {
    try {
      const result = await electron.stats.exportSecure({
        includeTimechain: true,
        includeAnomalies: true
      });
      
      if (result.ok) {
        // Créer un blob et télécharger
        const blob = new Blob([JSON.stringify(result.data, null, 2)], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `stats-export-${new Date().toISOString().split('T')[0]}.json`;
        a.click();
        URL.revokeObjectURL(url);
      } else {
        setError(`Erreur export: ${result.error}`);
      }
    } catch (err) {
      setError(`Erreur export: ${err}`);
    }
  };

  const formatDuration = (ms: number): string => {
    const hours = Math.floor(ms / 3600000);
    const minutes = Math.floor((ms % 3600000) / 60000);
    return `${hours}h ${minutes}m`;
  };

  const formatDate = (isoString: string): string => {
    return new Date(isoString).toLocaleString('fr-FR');
  };

  const getSeverityColor = (severity: string): string => {
    switch (severity) {
      case 'high': return 'text-red-600 bg-red-50';
      case 'medium': return 'text-orange-600 bg-orange-50';
      case 'low': return 'text-yellow-600 bg-yellow-50';
      default: return 'text-gray-600 bg-gray-50';
    }
  };

  useEffect(() => {
    loadGlobalMetrics();
    loadAnomalies();
  }, []);

  if (!globalMetrics) {
    return (
      <div className="p-4 bg-gray-50 rounded-lg">
        <p className="text-gray-600">Chargement des analytics...</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* En-tête */}
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold text-gray-900">📊 Analytics & Anti-rollback</h3>
        <div className="flex gap-2">
          <button
            onClick={validateIntegrity}
            disabled={loading}
            className="px-3 py-1 text-sm bg-blue-500 text-white rounded hover:bg-blue-600 disabled:opacity-50"
          >
            {loading ? '⏳' : '🔍'} Valider intégrité
          </button>
          <button
            onClick={exportData}
            className="px-3 py-1 text-sm bg-green-500 text-white rounded hover:bg-green-600"
          >
            📥 Exporter
          </button>
        </div>
      </div>

      {/* Erreurs */}
      {error && (
        <div className="p-3 bg-red-50 border border-red-200 rounded-lg">
          <p className="text-red-700 text-sm">{error}</p>
        </div>
      )}

      {/* Métriques globales */}
      <div className="grid grid-cols-2 gap-4">
        <div className="p-4 bg-white border border-gray-200 rounded-lg">
          <h4 className="font-medium text-gray-900 mb-2">🎯 Usage</h4>
          <div className="space-y-1 text-sm">
            <div>Sessions: <span className="font-mono">{globalMetrics.totalSessions}</span></div>
            <div>Temps total: <span className="font-mono">{formatDuration(globalMetrics.totalPlaytime)}</span></div>
            <div>Moy. session: <span className="font-mono">{formatDuration(globalMetrics.averageSessionDuration)}</span></div>
            <div>Depuis: <span className="font-mono text-xs">{formatDate(globalMetrics.firstUsage)}</span></div>
          </div>
        </div>

        <div className="p-4 bg-white border border-gray-200 rounded-lg">
          <h4 className="font-medium text-gray-900 mb-2">🔒 Sécurité</h4>
          <div className="space-y-1 text-sm">
            <div>Séquences: <span className="font-mono">{globalMetrics.integrity.totalSequences}</span></div>
            <div>Anomalies: <span className="font-mono">{globalMetrics.integrity.suspiciousEventsCount}</span></div>
            <div className={`inline-block px-2 py-1 rounded text-xs ${
              globalMetrics.integrity.integrityStatus === 'valid' 
                ? 'bg-green-100 text-green-700' 
                : 'bg-red-100 text-red-700'
            }`}>
              {globalMetrics.integrity.integrityStatus === 'valid' ? '✅ Intègre' : '⚠️ Suspect'}
            </div>
          </div>
        </div>
      </div>

      {/* Status de validation d'intégrité */}
      {integrityStatus && (
        <div className="p-4 bg-white border border-gray-200 rounded-lg">
          <h4 className="font-medium text-gray-900 mb-2">
            🔍 Validation d'intégrité
            <span className={`ml-2 px-2 py-1 rounded text-xs ${
              integrityStatus.valid ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
            }`}>
              {integrityStatus.valid ? 'VALID' : 'PROBLÈMES'}
            </span>
          </h4>
          <div className="grid grid-cols-3 gap-4 text-sm">
            <div>Total: <span className="font-mono">{integrityStatus.statistics.totalItems}</span></div>
            <div>Valides: <span className="font-mono text-green-600">{integrityStatus.statistics.validEntries}</span></div>
            <div>Corrompus: <span className="font-mono text-red-600">{integrityStatus.statistics.corruptedEntries}</span></div>
          </div>
          {integrityStatus.issues.length > 0 && (
            <div className="mt-2">
              <p className="text-xs text-gray-600 mb-1">Problèmes détectés:</p>
              <ul className="text-xs text-red-600 space-y-1">
                {integrityStatus.issues.slice(0, 5).map((issue: string, idx: number) => (
                  <li key={idx}>• {issue}</li>
                ))}
                {integrityStatus.issues.length > 5 && (
                  <li>... et {integrityStatus.issues.length - 5} autres</li>
                )}
              </ul>
            </div>
          )}
        </div>
      )}

      {/* Anomalies récentes */}
      {anomalies.length > 0 && (
        <div className="p-4 bg-white border border-gray-200 rounded-lg">
          <h4 className="font-medium text-gray-900 mb-3">⚠️ Anomalies récentes</h4>
          <div className="space-y-2">
            {anomalies.slice(0, 5).map((anomaly, idx) => (
              <div key={idx} className={`p-2 rounded text-xs ${getSeverityColor(anomaly.severity)}`}>
                <div className="flex items-center justify-between">
                  <span className="font-medium">{anomaly.type}</span>
                  <span className="text-xs opacity-75">{formatDate(anomaly.timestamp)}</span>
                </div>
                <div className="mt-1">{anomaly.details}</div>
                <div className="mt-1 text-xs opacity-75">Source: {anomaly.source}</div>
              </div>
            ))}
            {anomalies.length > 5 && (
              <p className="text-xs text-gray-500 text-center">
                ... et {anomalies.length - 5} autres anomalies
              </p>
            )}
          </div>
        </div>
      )}

      {/* Heures de pic */}
      {globalMetrics.peakUsageHours.length > 0 && (
        <div className="p-4 bg-white border border-gray-200 rounded-lg">
          <h4 className="font-medium text-gray-900 mb-2">📈 Heures de pic</h4>
          <div className="flex flex-wrap gap-1">
            {globalMetrics.peakUsageHours.map(hour => (
              <span key={hour} className="px-2 py-1 bg-blue-100 text-blue-700 rounded text-xs">
                {hour.toString().padStart(2, '0')}h
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
