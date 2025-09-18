/**
 * Composant de contrôle et monitoring de la sécurité du lecteur
 */

import React, { useState, useEffect } from 'react';
import { PlayerSecurityState, SecurityViolation } from '../../types/security';

interface SecurityControlProps {
  electron?: any;
}

export default function SecurityControl({ electron }: SecurityControlProps) {
  const [securityState, setSecurityState] = useState<PlayerSecurityState | null>(null);
  const [violations, setViolations] = useState<SecurityViolation[]>([]);
  const [loading, setLoading] = useState(false);
  const [lastUpdate, setLastUpdate] = useState<number>(0);

  // Charger l'état de sécurité
  const loadSecurityState = async () => {
    if (!electron?.ipc) return;
    
    try {
      setLoading(true);
      const state = await electron.ipc.invoke('security:getState');
      const recentViolations = await electron.ipc.invoke('security:getViolations', Date.now() - 300000); // 5 minutes

      setSecurityState(state);
      setViolations(recentViolations || []);
      setLastUpdate(Date.now());
    } catch (error) {
      console.error('[SecurityControl] Erreur chargement état:', error);
    } finally {
      setLoading(false);
    }
  };

  // Auto-refresh de l'état
  useEffect(() => {
    loadSecurityState();
    
    const interval = setInterval(loadSecurityState, 5000); // Toutes les 5 secondes
    return () => clearInterval(interval);
  }, [electron]);

  // Actions de sécurité
  const toggleFullscreen = async () => {
    if (!electron?.ipc) return;
    
    try {
      await electron.ipc.invoke('security:enableFullscreen');
      await loadSecurityState();
    } catch (error) {
      console.error('[SecurityControl] Erreur fullscreen:', error);
    }
  };

  const disableSecurity = async () => {
    if (!electron?.ipc) return;
    
    if (!confirm('Désactiver la sécurité du lecteur ? Cela peut compromettre la protection du contenu.')) {
      return;
    }
    
    try {
      await electron.ipc.invoke('security:disable');
      await loadSecurityState();
    } catch (error) {
      console.error('[SecurityControl] Erreur désactivation:', error);
    }
  };

  const testViolation = async () => {
    if (!electron?.ipc) return;
    
    try {
      await electron.ipc.invoke('security:testViolation', 'debug_detected', 'Test de violation manuelle');
      await loadSecurityState();
    } catch (error) {
      console.error('[SecurityControl] Erreur test violation:', error);
    }
  };

  // Formatage des violations
  const getSeverityColor = (severity: SecurityViolation['severity']) => {
    switch (severity) {
      case 'low': return 'text-yellow-400 bg-yellow-900/20 border-yellow-500/30';
      case 'medium': return 'text-orange-400 bg-orange-900/20 border-orange-500/30';
      case 'high': return 'text-red-400 bg-red-900/20 border-red-500/30';
      case 'critical': return 'text-red-300 bg-red-800/30 border-red-400/50';
      default: return 'text-gray-400 bg-gray-900/20 border-gray-500/30';
    }
  };

  const getViolationIcon = (type: SecurityViolation['type']) => {
    switch (type) {
      case 'screen_capture': return '📷';
      case 'debug_detected': return '🐛';
      case 'unauthorized_display': return '🖥️';
      case 'mirror_detected': return '📺';
      case 'external_app': return '⚠️';
      default: return '🔒';
    }
  };

  if (!securityState) {
    return (
      <div className="p-4 rounded-xl bg-white/5 border border-white/10">
        <h2 className="text-lg font-semibold mb-3 text-red-300">🔒 Sécurité du lecteur</h2>
        <div className="text-gray-400">
          {loading ? 'Chargement...' : 'État de sécurité non disponible'}
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 rounded-xl bg-white/5 border border-white/10">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-lg font-semibold text-red-300">🔒 Sécurité du lecteur</h2>
        <div className="flex items-center gap-2">
          <div className={`w-3 h-3 rounded-full ${
            securityState.isSecured ? 'bg-green-400' : 'bg-red-400'
          }`}></div>
          <span className={`text-sm font-medium ${
            securityState.isSecured ? 'text-green-300' : 'text-red-300'
          }`}>
            {securityState.isSecured ? 'Sécurisé' : 'Non sécurisé'}
          </span>
        </div>
      </div>

      {/* État des fonctionnalités de sécurité */}
      <div className="grid grid-cols-2 gap-3 mb-4">
        <div className="p-3 rounded-lg bg-gray-800/50 border border-gray-600">
          <div className="text-xs text-gray-400 mb-1">Protection capture</div>
          <div className={`text-sm font-medium ${
            securityState.securityFeatures.preventScreenCapture ? 'text-green-300' : 'text-red-300'
          }`}>
            {securityState.securityFeatures.preventScreenCapture ? '✅ Activée' : '❌ Désactivée'}
          </div>
        </div>

        <div className="p-3 rounded-lg bg-gray-800/50 border border-gray-600">
          <div className="text-xs text-gray-400 mb-1">Mode kiosque</div>
          <div className={`text-sm font-medium ${
            securityState.securityFeatures.kioskMode ? 'text-green-300' : 'text-red-300'
          }`}>
            {securityState.securityFeatures.kioskMode ? '✅ Activé' : '❌ Désactivé'}
          </div>
        </div>

        <div className="p-3 rounded-lg bg-gray-800/50 border border-gray-600">
          <div className="text-xs text-gray-400 mb-1">Anti-debug</div>
          <div className={`text-sm font-medium ${
            securityState.securityFeatures.antiDebug ? 'text-green-300' : 'text-red-300'
          }`}>
            {securityState.securityFeatures.antiDebug ? '✅ Activé' : '❌ Désactivé'}
          </div>
        </div>

        <div className="p-3 rounded-lg bg-gray-800/50 border border-gray-600">
          <div className="text-xs text-gray-400 mb-1">Watermark</div>
          <div className="text-sm font-medium text-blue-300">
            {securityState.securityFeatures.watermark.opacity > 0 ? '✅ Actif' : '❌ Inactif'}
          </div>
        </div>
      </div>

      {/* Contrôles de sécurité */}
      <div className="flex gap-2 mb-4">
        <button
          onClick={toggleFullscreen}
          className="px-3 py-2 bg-blue-600 hover:bg-blue-700 rounded text-sm transition-colors"
          disabled={loading}
        >
          🖥️ Plein écran
        </button>
        
        <button
          onClick={disableSecurity}
          className="px-3 py-2 bg-red-600 hover:bg-red-700 rounded text-sm transition-colors"
          disabled={loading}
        >
          ⚠️ Désactiver
        </button>

        {/* Bouton de test en développement */}
        <button
          onClick={testViolation}
          className="px-3 py-2 bg-orange-600 hover:bg-orange-700 rounded text-sm transition-colors"
          disabled={loading}
          title="Test de violation (développement)"
        >
          🧪 Test
        </button>
      </div>

      {/* Violations de sécurité */}
      {violations.length > 0 && (
        <div>
          <h3 className="text-sm font-semibold mb-2 text-yellow-300">
            ⚠️ Violations récentes ({violations.length})
          </h3>
          <div className="space-y-2 max-h-32 overflow-y-auto">
            {violations.slice(-5).reverse().map((violation, index) => (
              <div
                key={index}
                className={`p-2 rounded border text-xs ${getSeverityColor(violation.severity)}`}
              >
                <div className="flex items-center gap-2 mb-1">
                  <span>{getViolationIcon(violation.type)}</span>
                  <span className="font-medium">{violation.type}</span>
                  <span className="text-xs opacity-70">
                    {new Date(violation.timestamp).toLocaleTimeString()}
                  </span>
                </div>
                <div className="opacity-80">{violation.message}</div>
                <div className="text-xs mt-1 opacity-60">
                  Action: {violation.action}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Informations watermark */}
      <div className="mt-4 p-3 rounded-lg bg-blue-900/20 border border-blue-500/30">
        <h4 className="text-sm font-semibold text-blue-300 mb-2">🌊 Configuration Watermark</h4>
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div>
            <span className="text-gray-400">Position:</span>
            <span className="ml-2 text-blue-200">{securityState.securityFeatures.watermark.position}</span>
          </div>
          <div>
            <span className="text-gray-400">Opacité:</span>
            <span className="ml-2 text-blue-200">{Math.round(securityState.securityFeatures.watermark.opacity * 100)}%</span>
          </div>
          <div>
            <span className="text-gray-400">Rotation:</span>
            <span className="ml-2 text-blue-200">{securityState.securityFeatures.watermark.rotation}°</span>
          </div>
          <div>
            <span className="text-gray-400">Fréquence:</span>
            <span className="ml-2 text-blue-200">{securityState.securityFeatures.watermark.frequency}s</span>
          </div>
        </div>
      </div>

      {/* Dernière mise à jour */}
      <div className="mt-3 text-xs text-gray-500 text-center">
        Dernière vérification: {new Date(lastUpdate).toLocaleTimeString()}
      </div>
    </div>
  );
}
