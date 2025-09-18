# ⚡ TÂCHE 4 - ANALYSE ET PLAN D'IMPLÉMENTATION

## 🎯 Objectif : Stats locales & anti-rollback avancé

### ✅ Ce qui existe déjà
1. **StatsManager** : Persistance chiffrée (AES-256-GCM)
2. **Handlers IPC** : stats:get, stats:getOne, stats:played
3. **UI intégrée** : Affichage temps réel des compteurs
4. **Anti-rollback basique** : lastPlayedAt + timestamps

### 🚀 Ce qui manque (à implémenter)

#### 1. **Analytics sécurisés étendus**
- **Métriques détaillées** : durée session, patterns d'usage, fréquence
- **Détection anomalies** : tentatives de manipulation temporelle
- **Agrégations** : stats hebdomadaires/mensuelles
- **Export sécurisé** : rapports chiffrés

#### 2. **Anti-rollback robuste**
- **Blockchain locale** : séquences de hash pour empêcher retour arrière
- **Synchronisation temps** : validation NTP + tolérance réseau
- **Détection manipulation** : alertes si timestamps suspects
- **Backup redondant** : persistence multi-fichiers

#### 3. **Performance et robustesse**
- **Cache optimisé** : métriques fréquentes en mémoire
- **Batch operations** : groupement des écritures
- **Recovery automatique** : réparation fichiers corrompus
- **Limitations** : protection contre spam/DOS

## 📋 Plan d'implémentation

### Phase 1 : Analytics étendus
- [ ] Nouveaux types StatsItem détaillés
- [ ] Métriques session (durée, patterns)
- [ ] Détection anomalies temporelles
- [ ] Interface de monitoring avancé

### Phase 2 : Anti-rollback robuste
- [ ] Blockchain locale pour séquences
- [ ] Validation temps NTP
- [ ] Détection manipulation
- [ ] Alertes sécurité

### Phase 3 : Performance et UX
- [ ] Cache optimisé
- [ ] Batch operations
- [ ] Recovery automatique
- [ ] Interface analytics avancée

## 🔧 Architecture technique

```typescript
interface StatsItemExtended {
  // Existant
  id: string;
  playsCount: number;
  totalMs: number;
  lastPlayedAt?: string;
  
  // Nouveau
  sessionData: SessionMetrics;
  timechain: TimechainEntry[];
  anomalies: AnomalyRecord[];
}

interface SessionMetrics {
  dailyPlays: Record<string, number>;   // ISO date -> count
  weeklyPlays: Record<string, number>;  // ISO week -> count
  avgSessionMs: number;                 // moyenne durée session
  peakHours: number[];                  // heures de pic d'usage
  lastSessionStarted?: string;          // ISO
  currentSessionMs: number;             // session courante
}

interface TimechainEntry {
  timestamp: string;                    // ISO timestamp
  prevHash: string;                     // hash entrée précédente
  currentHash: string;                  // hash entrée courante
  playEvent: {
    mediaId: string;
    playedMs: number;
    sessionId: string;
  };
}

interface AnomalyRecord {
  timestamp: string;
  type: 'time-rollback' | 'suspicious-frequency' | 'invalid-sequence';
  details: string;
  severity: 'low' | 'medium' | 'high';
}
```

## ⚡ Première implémentation

Commencer par **étendre StatsManager** avec analytics détaillés et anti-rollback basique.
