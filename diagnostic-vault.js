const fs = require('fs');
const path = require('path');

console.log('=== DIAGNOSTIC VAULT 404 ===');

// Fonction pour lister récursivement
function listDir(dir, prefix = '') {
  const results = [];
  try {
    if (!fs.existsSync(dir)) {
      results.push(`${prefix}❌ ${dir} n'existe pas`);
      return results;
    }
    
    const items = fs.readdirSync(dir);
    results.push(`${prefix}📁 ${dir}/ (${items.length} items)`);
    
    items.forEach(item => {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        results.push(`${prefix}  📁 ${item}/`);
        results.push(...listDir(fullPath, prefix + '    '));
      } else {
        const sizeMB = (stat.size / (1024*1024)).toFixed(2);
        results.push(`${prefix}  📄 ${item} (${sizeMB} MB)`);
      }
    });
  } catch (err) {
    results.push(`${prefix}❌ Erreur: ${err.message}`);
  }
  return results;
}

// Diagnostic
const report = [];
report.push('=== DIAGNOSTIC VAULT 404 ===');
report.push(`Répertoire actuel: ${process.cwd()}`);
report.push('');

// Structure vault
report.push('STRUCTURE VAULT:');
report.push(...listDir('usb-package'));
report.push('');

// Manifest si présent
try {
  const manifestPath = 'usb-package/vault/manifest.json';
  if (fs.existsSync(manifestPath)) {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    report.push('CONTENU MANIFEST:');
    report.push(`Version: ${manifest.version}`);
    report.push(`Médias: ${manifest.media?.length || 0}`);
    
    if (manifest.media) {
      manifest.media.forEach((m, i) => {
        report.push(`  ${i+1}. ID: ${m.id}`);
        report.push(`     sha256Enc: ${m.sha256Enc?.slice(0, 16)}...`);
        report.push(`     Titre: ${m.title}`);
      });
    }
  } else {
    report.push('❌ Manifest introuvable');
  }
} catch (err) {
  report.push(`❌ Erreur lecture manifest: ${err.message}`);
}

// Écriture du rapport
const reportContent = report.join('\n');
console.log(reportContent);

fs.writeFileSync('diagnostic-vault.txt', reportContent);
console.log('\n📄 Rapport sauvegardé dans diagnostic-vault.txt');
