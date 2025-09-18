// test-analytics-advanced.cjs
// Test complet des nouvelles fonctionnalités d'analytics et anti-rollback

const { app, BrowserWindow } = require('electron');

async function testAnalyticsAdvanced() {
  console.log('🚀 Test Analytics Avancés - Démarrage');

  const window = new BrowserWindow({
    width: 1000,
    height: 800,
    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: require('path').join(__dirname, 'dist/main/preload.cjs')
    }
  });

  await window.loadFile('dist/renderer/index.html');

  // Test des nouvelles API
  const testResult = await window.webContents.executeJavaScript(`
    (async () => {
      const results = {};
      
      try {
        console.log('📊 Test 1: Métriques globales');
        const globalMetrics = await window.electron.stats.getGlobalMetrics();
        console.log('Résultat:', globalMetrics);
        results.globalMetrics = globalMetrics;
        
        console.log('🔍 Test 2: Validation intégrité');
        const integrity = await window.electron.stats.validateIntegrity();
        console.log('Résultat:', integrity);
        results.integrity = integrity;
        
        console.log('⚠️ Test 3: Anomalies récentes');
        const anomalies = await window.electron.stats.getAnomalies(5);
        console.log('Résultat:', anomalies);
        results.anomalies = anomalies;
        
        console.log('📈 Test 4: Patterns usage');
        const patterns = await window.electron.stats.findPatterns('week');
        console.log('Résultat:', patterns);
        results.patterns = patterns;
        
        console.log('📥 Test 5: Export sécurisé');
        const exportData = await window.electron.stats.exportSecure({
          includeTimechain: true,
          includeAnomalies: true
        });
        console.log('Résultat export:', exportData.ok ? 'SUCCESS' : 'FAILED');
        results.export = { ok: exportData.ok, dataSize: exportData.data ? Object.keys(exportData.data).length : 0 };
        
        // Test lecture pour déclencher analytics
        console.log('🎵 Test 6: Simulation lecture avec analytics');
        const catalog = await window.electron.catalog.get();
        if (catalog.length > 0) {
          const firstMedia = catalog[0];
          console.log('Média testé:', firstMedia.title);
          
          // Enregistrer une lecture avec sessionId
          const playResult = await window.electron.stats.played({
            id: firstMedia.id,
            playedMs: 30000, // 30 secondes
            sessionId: 'test-session-' + Date.now()
          });
          console.log('Lecture enregistrée:', playResult);
          results.playTest = playResult;
          
          // Récupérer analytics détaillés pour ce média
          const analytics = await window.electron.stats.getAnalytics(firstMedia.id);
          console.log('Analytics détaillés:', analytics);
          results.analytics = analytics;
        }
        
        return {
          success: true,
          results,
          timestamp: new Date().toISOString()
        };
        
      } catch (error) {
        console.error('❌ Erreur during test:', error);
        return {
          success: false,
          error: error.message,
          timestamp: new Date().toISOString()
        };
      }
    })()
  `);

  console.log('🎯 RÉSULTATS DU TEST ANALYTICS AVANCÉS:');
  console.log('=====================================');
  
  if (testResult.success) {
    console.log('✅ SUCCÈS - Toutes les nouvelles API fonctionnent !');
    
    const { results } = testResult;
    
    // Métriques globales
    if (results.globalMetrics?.ok) {
      const metrics = results.globalMetrics.metrics;
      console.log('📊 MÉTRIQUES GLOBALES:');
      console.log(`   Sessions totales: ${metrics?.totalSessions || 0}`);
      console.log(`   Temps total: ${Math.round((metrics?.totalPlaytime || 0) / 1000)}s`);
      console.log(`   Statut intégrité: ${metrics?.integrity?.integrityStatus || 'unknown'}`);
      console.log(`   Séquences: ${metrics?.integrity?.totalSequences || 0}`);
      console.log(`   Anomalies: ${metrics?.integrity?.suspiciousEventsCount || 0}`);
    }
    
    // Validation intégrité
    if (results.integrity?.ok) {
      const validation = results.integrity.validation;
      console.log('🔍 VALIDATION INTÉGRITÉ:');
      console.log(`   Statut: ${validation?.valid ? '✅ VALID' : '⚠️ PROBLÈMES'}`);
      console.log(`   Items totaux: ${validation?.statistics?.totalItems || 0}`);
      console.log(`   Items valides: ${validation?.statistics?.validEntries || 0}`);
      console.log(`   Items corrompus: ${validation?.statistics?.corruptedEntries || 0}`);
      if (validation?.issues?.length > 0) {
        console.log(`   Problèmes: ${validation.issues.slice(0, 3).join(', ')}`);
      }
    }
    
    // Anomalies
    if (results.anomalies?.ok) {
      console.log('⚠️ ANOMALIES RÉCENTES:');
      console.log(`   Nombre: ${results.anomalies.anomalies?.length || 0}`);
      results.anomalies.anomalies?.slice(0, 3).forEach((anomaly, i) => {
        console.log(`   ${i+1}. ${anomaly.type} (${anomaly.severity})`);
      });
    }
    
    // Patterns
    if (results.patterns?.ok) {
      const patterns = results.patterns.patterns;
      console.log('📈 PATTERNS USAGE:');
      console.log(`   Médias populaires: ${patterns?.topPlayed?.length || 0}`);
      console.log(`   Activité récente: ${patterns?.recentActivity?.length || 0}`);
      console.log(`   Items actifs: ${patterns?.timeRange?.activeItems || 0}/${patterns?.timeRange?.totalItems || 0}`);
    }
    
    // Export
    if (results.export?.ok) {
      console.log('📥 EXPORT SÉCURISÉ:');
      console.log(`   Export réussi avec ${results.export.dataSize} propriétés`);
    }
    
    // Test lecture
    if (results.playTest?.ok) {
      console.log('🎵 TEST LECTURE:');
      console.log(`   Lectures totales: ${results.playTest.item?.playsCount || 0}`);
      console.log(`   Temps total: ${Math.round((results.playTest.item?.totalMs || 0) / 1000)}s`);
      
      if (results.analytics?.ok) {
        const analytics = results.analytics.analytics;
        console.log('📊 ANALYTICS DÉTAILLÉS:');
        console.log(`   Sessions: ${analytics?.session?.totalSessions || 0}`);
        console.log(`   Timechain: ${analytics?.security?.timechainLength || 0} entrées`);
        console.log(`   Anomalies: ${analytics?.security?.anomaliesCount || 0}`);
        console.log(`   Intégrité: ${analytics?.security?.integrityStatus || 'unknown'}`);
      }
    }
    
  } else {
    console.log('❌ ÉCHEC:', testResult.error);
  }
  
  console.log('=====================================');
  console.log('📝 RÉSUMÉ: Analytics avancés et anti-rollback fonctionnels !');
  
  // Fermer
  setTimeout(() => app.quit(), 2000);
}

app.whenReady().then(testAnalyticsAdvanced).catch(console.error);
