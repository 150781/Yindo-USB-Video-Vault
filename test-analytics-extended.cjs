// test-analytics-extended.cjs
// Test des nouvelles fonctionnalités d'analytics étendus et anti-rollback

const { app, BrowserWindow } = require('electron');

async function testAnalyticsExtended() {
  console.log('🧪 Test Analytics Étendus & Anti-rollback\n');
  
  const testWindow = new BrowserWindow({
    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: require('path').join(__dirname, 'dist/main/preload.cjs')
    }
  });

  await testWindow.loadFile('dist/renderer/index.html');

  const results = await testWindow.webContents.executeJavaScript(`
    (async () => {
      const results = [];
      
      try {
        // Test 1: Vérification API disponibles
        console.log('📊 Test 1: Vérification des nouvelles API...');
        const hasNewAPIs = typeof window.electron?.stats?.getGlobalMetrics === 'function' &&
                           typeof window.electron?.stats?.getAnalytics === 'function' &&
                           typeof window.electron?.stats?.validateIntegrity === 'function';
        
        results.push({
          test: 'APIs Extended disponibles',
          result: hasNewAPIs ? 'PASS' : 'FAIL',
          details: hasNewAPIs ? 'Toutes les API étendues présentes' : 'API manquantes'
        });

        // Test 2: Métriques globales
        console.log('📈 Test 2: Récupération métriques globales...');
        const globalMetrics = await window.electron.stats.getGlobalMetrics();
        results.push({
          test: 'Métriques globales',
          result: globalMetrics.ok ? 'PASS' : 'FAIL',
          details: globalMetrics.ok ? 
            \`Sessions: \${globalMetrics.metrics?.totalSessions || 0}, Playtime: \${globalMetrics.metrics?.totalPlaytime || 0}ms\` :
            \`Erreur: \${globalMetrics.error}\`
        });

        // Test 3: Validation intégrité
        console.log('🔍 Test 3: Validation d\'intégrité...');
        const integrity = await window.electron.stats.validateIntegrity();
        results.push({
          test: 'Validation intégrité',
          result: integrity.ok ? 'PASS' : 'FAIL',
          details: integrity.ok ? 
            \`Valid: \${integrity.validation?.valid}, Items: \${integrity.validation?.statistics?.totalItems || 0}\` :
            \`Erreur: \${integrity.error}\`
        });

        // Test 4: Anomalies
        console.log('⚠️ Test 4: Récupération anomalies...');
        const anomalies = await window.electron.stats.getAnomalies(5);
        results.push({
          test: 'Récupération anomalies',
          result: anomalies.ok ? 'PASS' : 'FAIL',
          details: anomalies.ok ? 
            \`\${anomalies.anomalies?.length || 0} anomalies trouvées\` :
            \`Erreur: \${anomalies.error}\`
        });

        // Test 5: Simuler lecture pour créer timechain
        console.log('🎵 Test 5: Test timechain avec lecture...');
        const catalog = await window.electron.catalog.list();
        if (catalog.list && catalog.list.length > 0) {
          const firstMedia = catalog.list[0];
          
          // Lecture simulée
          await window.electron.stats.played(firstMedia.id, 30000); // 30 secondes
          
          // Vérification analytics
          const analytics = await window.electron.stats.getAnalytics(firstMedia.id);
          results.push({
            test: 'Analytics après lecture',
            result: analytics.ok ? 'PASS' : 'FAIL',
            details: analytics.ok ? 
              \`Lectures: \${analytics.analytics?.basic?.playsCount || 0}, Timechain: \${analytics.analytics?.security?.timechainLength || 0}\` :
              \`Erreur: \${analytics.error}\`
          });
        } else {
          results.push({
            test: 'Analytics après lecture',
            result: 'SKIP',
            details: 'Aucun média disponible pour test'
          });
        }

        // Test 6: Export sécurisé
        console.log('📥 Test 6: Export sécurisé...');
        const exportData = await window.electron.stats.exportSecure({
          includeTimechain: true,
          includeAnomalies: true
        });
        results.push({
          test: 'Export sécurisé',
          result: exportData.ok ? 'PASS' : 'FAIL',
          details: exportData.ok ? 
            \`\${exportData.data?.items?.length || 0} items exportés\` :
            \`Erreur: \${exportData.error}\`
        });

        // Test 7: Patterns d'usage
        console.log('📊 Test 7: Analyse patterns...');
        const patterns = await window.electron.stats.findPatterns('week');
        results.push({
          test: 'Patterns d\'usage',
          result: patterns.ok ? 'PASS' : 'FAIL',
          details: patterns.ok ? 
            \`Top played: \${patterns.patterns?.topPlayed?.length || 0}, Recent: \${patterns.patterns?.recentActivity?.length || 0}\` :
            \`Erreur: \${patterns.error}\`
        });

        return results;
      } catch (error) {
        return [{ test: 'ERREUR GÉNÉRALE', result: 'FAIL', details: error.toString() }];
      }
    })()
  `);

  testWindow.close();
  
  // Affichage résultats
  console.log('📋 RÉSULTATS DES TESTS:');
  console.log('========================');
  
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  
  results.forEach(result => {
    const icon = result.result === 'PASS' ? '✅' : result.result === 'FAIL' ? '❌' : '⏸️';
    console.log(`${icon} ${result.test}: ${result.result}`);
    console.log(`   ${result.details}\n`);
    
    if (result.result === 'PASS') passed++;
    else if (result.result === 'FAIL') failed++;
    else skipped++;
  });
  
  console.log('📊 RÉSUMÉ:');
  console.log(`   ✅ Réussis: ${passed}`);
  console.log(`   ❌ Échoués: ${failed}`);
  console.log(`   ⏸️ Ignorés: ${skipped}`);
  console.log(`   📈 Taux de réussite: ${Math.round(passed / (passed + failed) * 100)}%`);
  
  if (failed === 0) {
    console.log('\n🎉 TOUS LES TESTS RÉUSSIS - Analytics étendus fonctionnels !');
  } else {
    console.log(`\n⚠️ ${failed} test(s) échoué(s) - Vérification nécessaire`);
  }
  
  return { passed, failed, skipped };
}

// Lancement des tests si ce script est exécuté directement
if (require.main === module) {
  app.whenReady().then(async () => {
    try {
      await testAnalyticsExtended();
      app.quit();
    } catch (error) {
      console.error('❌ Erreur durant les tests:', error);
      app.quit();
    }
  });
}

module.exports = { testAnalyticsExtended };
