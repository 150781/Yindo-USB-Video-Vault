// Script simple pour tester que l'API preload refactorée fonctionne
// À exécuter dans la DevTools Console de l'application Electron

console.log("=== Test de l'API Electron refactorée ===");

// Test 1: Vérifier que l'API est exposée
if (window.electron) {
  console.log("✓ window.electron est défini");
  console.log("API disponible:", Object.keys(window.electron));
} else {
  console.error("✗ window.electron n'est pas défini");
}

// Test 2: Vérifier les sous-API
const apis = ['license', 'manifest', 'stats', 'ipc'];
apis.forEach(api => {
  if (window.electron && window.electron[api]) {
    console.log(`✓ window.electron.${api} est défini`);
  } else {
    console.error(`✗ window.electron.${api} n'est pas défini`);
  }
});

// Test 3: Tester license.status() (qui ne nécessite pas de passphrase)
if (window.electron && window.electron.license && window.electron.license.status) {
  window.electron.license.status()
    .then(result => {
      console.log("✓ license.status() fonctionne:", result);
    })
    .catch(err => {
      console.error("✗ license.status() a échoué:", err);
    });
} else {
  console.error("✗ license.status() n'est pas disponible");
}

// Test 4: Tester stats.get()
if (window.electron && window.electron.stats && window.electron.stats.get) {
  window.electron.stats.get()
    .then(result => {
      console.log("✓ stats.get() fonctionne:", result);
    })
    .catch(err => {
      console.error("✗ stats.get() a échoué:", err);
    });
} else {
  console.error("✗ stats.get() n'est pas disponible");
}

console.log("=== Fin du test ===");
