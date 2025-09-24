// Guard pour s'assurer que "type": "module" ne revient jamais dans package.json
const fs = require('fs');
const path = require('path');

const packagePath = path.join(__dirname, '..', 'package.json');

if (fs.existsSync(packagePath)) {
  const content = fs.readFileSync(packagePath, 'utf8');
  const packageJson = JSON.parse(content);

  if (packageJson.type === 'module') {
    console.error('❌ ERREUR: "type": "module" détecté dans package.json !');
    console.error('   Cela causera des erreurs avec Electron main process.');
    console.error('   Suppression automatique...');

    delete packageJson.type;
    fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2) + '\r\n');
    console.log('✅ "type": "module" supprimé de package.json');
  } else {
    console.log('✅ package.json OK - pas de "type": "module"');
  }
} else {
  console.error('❌ package.json introuvable');
}
