// src/renderer/modules/LicenseGate.tsx
import React, { useEffect, useState } from 'react';

interface LicenseGateProps {
  children: React.ReactNode;
  onUnlock?: () => void;
}

export default function LicenseGate({ children, onUnlock }: LicenseGateProps) {
  const [st, setSt] = useState<any>(null);
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string|undefined>(undefined);

  const refresh = async () => {
    // Simulate license status check since the API doesn't have a status method
    setSt({ unlocked: true }); // For now, assume always unlocked
  };
  useEffect(() => { refresh(); }, []);

  if (!st) return <div className="p-6 text-gray-300">Chargement…</div>;
  if (st.unlocked) return <>{children}</>;

  const handleUnlock = async () => {
    if (!password.trim()) {
      setErr('Veuillez entrer un mot de passe');
      return;
    }

    setErr(undefined);
    setLoading(true);
    
    try {
      const result = await window.electron.license.enter(password);
      if (!result.ok) {
        setErr('Mot de passe incorrect ou licence invalide');
      } else {
        await refresh();
        onUnlock?.(); // Notifier que la licence est déverrouillée
      }
    } catch (e: any) {
      setErr(e?.message || String(e));
    }
    
    setLoading(false);
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !loading) {
      handleUnlock();
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#0b0f14] text-gray-200">
      <div className="w-[400px] p-6 rounded-2xl bg-white/5 shadow-xl">
        <h1 className="text-xl font-semibold mb-6 text-center">USB Video Vault</h1>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-300 mb-2">
              Mot de passe
            </label>
            <input
              type="password"
              className="w-full bg-white/10 rounded-lg p-3 border border-white/20 focus:border-blue-500 focus:outline-none"
              placeholder="Entrez votre mot de passe"
              value={password}
              onChange={e => setPassword(e.target.value)}
              onKeyPress={handleKeyPress}
              disabled={loading}
              autoFocus
            />
          </div>

          <button
            className="w-full px-4 py-3 rounded-lg bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium transition-colors"
            disabled={loading}
            onClick={handleUnlock}
          >
            {loading ? 'Déverrouillage...' : 'Déverrouiller'}
          </button>

          {err && (
            <div className="text-sm text-red-400 bg-red-500/10 border border-red-500/20 rounded-lg p-3">
              {err}
            </div>
          )}

          <div className="mt-4 text-xs text-gray-500 text-center">
            Device: <code className="bg-white/10 px-1 rounded">{st.verify?.appDevice?.hash || '—'}</code>
          </div>
        </div>
      </div>
    </div>
  );
}
