/**
 * 🚨 SAUVEGARDE D'URGENCE - Solutions Yindo-USB-Video-Vault 🚨
 * 
 * Date: 16 septembre 2025
 * Statut: TOUTES FONCTIONNALITÉS OPÉRATIONNELLES
 * 
 * ⚠️ CRITIQUE: Ce fichier contient les solutions ESSENTIELLES
 * pour maintenir le bon fonctionnement de l'application !
 */

// ================================================================================
// 🎯 PROBLÈME #1: DRAG-AND-DROP CASSÉ
// ================================================================================

/* 
CAUSE RACINE: Format de données incompatible
- Frontend envoyait: MediaEntry
- Backend attendait: QueueItem
- Résultat: Communication IPC silencieuse cassée
*/

// ✅ SOLUTION: Conversion explicite des types
// Fichier: src/renderer/modules/ControlWindowClean.tsx
// Fonction: addToQueueUnique

const addToQueueUnique = async (items: MediaEntry[]) => {
  console.log('[DRAG] 🎵 addToQueueUnique appelé avec items:', items.map(item => item.title));
  
  const queueItems = queue.items || [];
  console.log('[DRAG] 🎵 Queue actuelle:', queueItems.map(item => item.title));
  
  // Filtrer les doublons
  const itemsToAdd = items.filter(newItem => 
    !queueItems.some(existingItem => existingItem.id === newItem.id)
  );
  
  console.log('[DRAG] 🎵 Items à ajouter après filtrage doublons:', itemsToAdd.map(item => item.title));
  
  // ⚠️ CRITIQUE: CONVERSION MediaEntry → QueueItem
  for (const mediaEntry of itemsToAdd) {
    const queueItem: QueueItem = {
      id: mediaEntry.id,
      title: mediaEntry.title,
      artist: mediaEntry.artist,
      mediaId: mediaEntry.id,
      src: mediaEntry.src,
      duration: mediaEntry.duration || 0,
      thumbnail: mediaEntry.thumbnail
    };
    
    console.log('[DRAG] 🎵 Appel electron.queue.add avec:', queueItem);
    await window.electron.queue.add(queueItem);
  }
};

// ================================================================================
// 🎯 PROBLÈME #2: LECTURE AUTOMATIQUE CASSÉE  
// ================================================================================

/*
CAUSE RACINE: Mode "none" ne passait pas à la chanson suivante
- Frontend: Arrêtait la lecture au lieu de continuer
- Backend: Même problème, logique incohérente
*/

// ✅ SOLUTION: Correction Backend
// Fichier: src/main/ipcQueue.ts

// AVANT (CASSÉ):
// } else {
//   console.log('[QUEUE] Mode repeat "none" - arrêt');
//   // Ne rien faire
// }

// APRÈS (CORRIGÉ):
} else {
  // Mode 'none' - lecture séquentielle normale
  console.log('[QUEUE] Mode repeat "none" - lecture séquentielle');
  if (queueState.currentIndex < queueState.items.length - 1) {
    console.log('[QUEUE] Passage à la chanson suivante (mode none)');
    queueState.currentIndex++;
    const next = queueState.items[queueState.currentIndex];
    if (next) {
      const payload = toOpenPayload(next);
      if (payload) {
        await ensureDisplayAndSend(payload);
      }
    }
  } else {
    console.log('[QUEUE] Fin de playlist - arrêt de la lecture');
  }
}

// ✅ SOLUTION: Correction Frontend  
// Fichier: src/renderer/modules/ControlWindowClean.tsx

// AVANT (CASSÉ):
// console.log('[control] Mode repeat "none" - arrêt');
// await electron?.player?.stop?.();

// APRÈS (CORRIGÉ):
console.log('[control] Mode repeat "none" - lecture séquentielle');
if (idx < items.length - 1) {
  console.log('[control] Passage à la chanson suivante (mode none)');
  await electron?.queue?.next?.();
} else {
  console.log('[control] Fin de playlist - arrêt');
  await electron?.player?.stop?.();
}

// ================================================================================
// 🎯 PROBLÈME #3: STATS LIVE CASSÉES
// ================================================================================

/*
CAUSE RACINE: Parsing incorrect des données stats
- Backend retournait: {assetId: 1} 
- Frontend cherchait: 1.playsCount (toujours undefined!)
*/

// ✅ SOLUTION: Correction du parsing
// Fichier: src/renderer/modules/ControlWindowClean.tsx
// Fonction: getPlays

const getPlays = (assetId: string): number => {
  if (!assetId || !stats) return 0;
  
  const v = stats[assetId];
  
  // ⚠️ CRITIQUE: Vérification de type AVANT extraction  
  const count = typeof v === 'number' ? v : (v?.playsCount ?? v?.count ?? v?.plays ?? 0);
  
  return count;
};

// ✅ SOLUTION: Rechargement automatique des stats
// Fonction: handleEnded (dans useEffect)

const handleEnded = async () => {
  console.log('[control] Video ended');
  setCurrentlyPlaying(null);
  setIsPlaying(false);
  
  // ⚠️ CRITIQUE: Recharger stats après chaque lecture
  await loadStats();
  
  // ... reste de la logique de lecture automatique
};

// ================================================================================
// 🚨 RÈGLES CRITIQUES À RESPECTER
// ================================================================================

/*
1. TYPES DE DONNÉES:
   - TOUJOURS convertir MediaEntry → QueueItem avant envoi backend
   - JAMAIS envoyer MediaEntry directement aux handlers de queue
   
2. MODES DE LECTURE:
   - Mode "none" = lecture séquentielle normale (PAS arrêt!)
   - Vérifier cohérence Frontend ↔ Backend
   
3. STATS LIVE:
   - TOUJOURS recharger stats après lecture (loadStats)
   - Parser correctement: vérifier typeof avant extraction propriétés
   
4. EVENT LISTENERS:
   - Éviter trop de dépendances dans useEffect
   - Limiter les ré-inscriptions d'événements
   
5. TESTS DE RÉGRESSION:
   - Tester ajout multiple chansons
   - Vérifier lecture automatique  
   - Confirmer incrémentation stats live
*/

// ================================================================================
// 📋 CHECKLIST DE MAINTENANCE
// ================================================================================

/*
AVANT TOUTE MODIFICATION:

□ Vérifier types de données échangés (MediaEntry vs QueueItem)
□ Maintenir conversion explicite avant appels IPC
□ Tester ajout multiple chansons du catalogue
□ Vérifier lecture automatique mode "none"
□ Confirmer incrémentation stats en temps réel
□ Valider persistance stats après redémarrage
□ Tester tous les modes de lecture (none/one/all)
□ Conserver logs de débogage essentiels

FICHIERS CRITIQUES:
- src/renderer/modules/ControlWindowClean.tsx (UI principale)
- src/main/ipcQueueStats.ts (Handlers IPC)  
- src/main/ipcQueue.ts (Logique queue)
- src/renderer/modules/DisplayApp.tsx (Lecture vidéo)
*/

// ================================================================================
// 🎉 ÉTAT FINAL: SUCCÈS COMPLET!
// ================================================================================

/*
✅ Drag-and-drop: Multiples chansons ajoutées parfaitement
✅ Lecture automatique: Séquentielle en mode "none" 
✅ Stats live: Incrémentation temps réel dans catalogue
✅ Communication IPC: Frontend ↔ Backend synchronisés
✅ Logs: Visibilité complète des flux de données
✅ Performance: UI fluide, pas de ralentissements

RÉSULTAT: Application 100% fonctionnelle !
*/
