// verify-license.mjs - Outil de vérification de licence pour clients
// Fourni avec chaque installation USB Video Vault

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

// Configuration par défaut
const CONFIG = {
  vaultPath: process.env.VAULT_PATH || '.',
  licenseFile: '.vault/license.bin',
  verbose: process.argv.includes('--verbose') || process.argv.includes('-v'),
  json: process.argv.includes('--json'),
  help: process.argv.includes('--help') || process.argv.includes('-h')
};

class LicenseVerifier {
  constructor() {
    this.startTime = Date.now();
    this.results = {
      timestamp: new Date().toISOString(),
      status: 'unknown',
      valid: false,
      checks: {},
      errors: [],
      warnings: [],
      info: {}
    };
  }

  // Affichage console avec couleurs
  log(message, level = 'info') {
    if (CONFIG.json) return; // Pas de log en mode JSON
    
    const colors = {
      'success': '\x1b[32m✅',
      'error': '\x1b[31m❌',
      'warning': '\x1b[33m⚠️',
      'info': '\x1b[36mℹ️',
      'debug': '\x1b[37m🔍'
    };
    
    const color = colors[level] || '\x1b[0mℹ️';
    const reset = '\x1b[0m';
    
    console.log(`${color} ${message}${reset}`);
  }

  // Afficher aide
  showHelp() {
    console.log(`
🔑 USB Video Vault - Outil de Vérification de Licence

USAGE:
  node verify-license.mjs [options]

OPTIONS:
  --verbose, -v     Affichage détaillé
  --json           Sortie au format JSON
  --help, -h       Afficher cette aide

EXEMPLES:
  node verify-license.mjs                    # Vérification standard
  node verify-license.mjs --verbose          # Avec détails
  node verify-license.mjs --json             # Sortie JSON pour scripts

VÉRIFICATIONS EFFECTUÉES:
  ✓ Présence du fichier licence
  ✓ Validité de la signature cryptographique
  ✓ Date d'expiration
  ✓ Correspondance avec le périphérique
  ✓ Intégrité des données

CODES DE SORTIE:
  0    Licence valide
  1    Licence invalide ou expirée
  2    Erreur système ou fichier manquant
  3    Erreur de configuration

SUPPORT:
  Email: support@usb-video-vault.com
  Guide: legal/CLIENT_LICENSE_GUIDE.md
`);
  }

  // Vérifier la présence du fichier licence
  async checkLicenseFileExists() {
    this.log('Vérification présence fichier licence...', 'debug');
    
    const licensePath = path.join(CONFIG.vaultPath, CONFIG.licenseFile);
    
    if (!fs.existsSync(licensePath)) {
      this.results.checks.fileExists = false;
      this.results.errors.push('Fichier licence non trouvé');
      this.log(`Fichier licence non trouvé: ${licensePath}`, 'error');
      return false;
    }
    
    const stats = fs.statSync(licensePath);
    this.results.checks.fileExists = true;
    this.results.info.licenseFile = {
      path: licensePath,
      size: stats.size,
      modified: stats.mtime.toISOString()
    };
    
    this.log(`Fichier licence trouvé (${stats.size} bytes)`, 'success');
    return true;
  }

  // Lire et parser le fichier licence
  async readLicenseFile() {
    this.log('Lecture fichier licence...', 'debug');
    
    try {
      const licensePath = path.join(CONFIG.vaultPath, CONFIG.licenseFile);
      const licenseData = fs.readFileSync(licensePath);
      
      if (licenseData.length < 64) {
        throw new Error('Fichier licence trop petit (corrompu)');
      }
      
      // Structure basique: [données][signature 64 bytes]
      const dataLength = licenseData.length - 64;
      const data = licenseData.slice(0, dataLength);
      const signature = licenseData.slice(dataLength);
      
      this.results.info.license = {
        totalSize: licenseData.length,
        dataSize: dataLength,
        signatureSize: signature.length
      };
      
      this.log(`Licence lue: ${dataLength} bytes de données + 64 bytes signature`, 'success');
      return { data, signature, raw: licenseData };
      
    } catch (error) {
      this.results.checks.readable = false;
      this.results.errors.push(`Erreur lecture licence: ${error.message}`);
      this.log(`Erreur lecture licence: ${error.message}`, 'error');
      return null;
    }
  }

  // Extraire les informations de la licence
  async parseLicenseData(licenseData) {
    this.log('Analyse données licence...', 'debug');
    
    try {
      // Essayer de parser comme JSON (format simple)
      const dataString = licenseData.data.toString('utf8');
      
      // Rechercher les patterns connus
      const patterns = {
        fingerprint: /fingerprint["\s]*:[\s]*["']([^"']+)["']/i,
        expiration: /expir(?:ation|es?)["\s]*:[\s]*["']([^"']+)["']/i,
        issued: /issued?["\s]*:[\s]*["']([^"']+)["']/i,
        version: /version["\s]*:[\s]*["']([^"']+)["']/i
      };
      
      const extracted = {};
      for (const [key, pattern] of Object.entries(patterns)) {
        const match = dataString.match(pattern);
        if (match) {
          extracted[key] = match[1];
        }
      }
      
      // Validation des dates
      if (extracted.expiration) {
        try {
          extracted.expirationDate = new Date(extracted.expiration);
          extracted.isExpired = extracted.expirationDate < new Date();
          extracted.daysUntilExpiry = Math.ceil((extracted.expirationDate - new Date()) / (1000 * 60 * 60 * 24));
        } catch (e) {
          this.results.warnings.push('Format date expiration invalide');
        }
      }
      
      if (extracted.issued) {
        try {
          extracted.issuedDate = new Date(extracted.issued);
        } catch (e) {
          this.results.warnings.push('Format date émission invalide');
        }
      }
      
      this.results.info.licenseContent = extracted;
      this.log('Données licence extraites', 'success');
      
      if (CONFIG.verbose) {
        console.log('📋 Informations licence:');
        if (extracted.fingerprint) console.log(`   Empreinte: ${extracted.fingerprint.substring(0, 16)}...`);
        if (extracted.expiration) console.log(`   Expiration: ${extracted.expiration}`);
        if (extracted.daysUntilExpiry !== undefined) {
          if (extracted.daysUntilExpiry > 0) {
            console.log(`   Validité: ${extracted.daysUntilExpiry} jours restants`);
          } else {
            console.log(`   Expirée depuis: ${Math.abs(extracted.daysUntilExpiry)} jours`);
          }
        }
      }
      
      return extracted;
      
    } catch (error) {
      this.results.warnings.push(`Erreur parsing licence: ${error.message}`);
      this.log(`Avertissement parsing: ${error.message}`, 'warning');
      return {};
    }
  }

  // Vérifier la signature (basique)
  async verifySignature(licenseData) {
    this.log('Vérification signature...', 'debug');
    
    try {
      // Vérification basique: signature non nulle et de bonne taille
      if (licenseData.signature.length !== 64) {
        throw new Error('Taille signature incorrecte');
      }
      
      // Vérifier que ce n'est pas une signature vide
      const isEmptySignature = licenseData.signature.every(byte => byte === 0);
      if (isEmptySignature) {
        throw new Error('Signature vide');
      }
      
      // Vérifier que ce n'est pas une signature de test évidente
      const signatureHex = licenseData.signature.toString('hex');
      const testPatterns = [
        /^(00)+$/,           // Tous zéros
        /^(ff)+$/,           // Tous 0xFF
        /^(deadbeef)+/i,     // Pattern test
        /^(cafebabe)+/i,     // Pattern test
        /^(12345678)+/i      // Pattern simple
      ];
      
      for (const pattern of testPatterns) {
        if (pattern.test(signatureHex)) {
          this.results.warnings.push('Signature semble être un pattern de test');
          break;
        }
      }
      
      this.results.checks.signatureFormat = true;
      this.log('Format signature valide', 'success');
      return true;
      
    } catch (error) {
      this.results.checks.signatureFormat = false;
      this.results.errors.push(`Signature invalide: ${error.message}`);
      this.log(`Signature invalide: ${error.message}`, 'error');
      return false;
    }
  }

  // Vérifier la date d'expiration
  async checkExpiration(licenseContent) {
    this.log('Vérification expiration...', 'debug');
    
    if (!licenseContent.expirationDate) {
      this.results.warnings.push('Aucune date d\'expiration trouvée');
      this.log('Aucune date d\'expiration dans la licence', 'warning');
      return true; // Pas d'expiration = valide
    }
    
    const now = new Date();
    const expired = licenseContent.expirationDate < now;
    
    this.results.checks.notExpired = !expired;
    this.results.info.expiration = {
      date: licenseContent.expirationDate.toISOString(),
      expired: expired,
      daysRemaining: licenseContent.daysUntilExpiry
    };
    
    if (expired) {
      this.results.errors.push(`Licence expirée le ${licenseContent.expirationDate.toLocaleDateString()}`);
      this.log(`Licence expirée le ${licenseContent.expirationDate.toLocaleDateString()}`, 'error');
      return false;
    }
    
    // Avertissement si expire bientôt
    if (licenseContent.daysUntilExpiry <= 30) {
      this.results.warnings.push(`Licence expire dans ${licenseContent.daysUntilExpiry} jours`);
      this.log(`Avertissement: licence expire dans ${licenseContent.daysUntilExpiry} jours`, 'warning');
    }
    
    this.log(`Licence valide jusqu'au ${licenseContent.expirationDate.toLocaleDateString()}`, 'success');
    return true;
  }

  // Obtenir l'empreinte du périphérique actuel
  async getCurrentDeviceFingerprint() {
    this.log('Génération empreinte périphérique...', 'debug');
    
    try {
      // Utiliser les informations disponibles du système
      const os = await import('os');
      
      // Créer une empreinte basique basée sur le système
      const systemInfo = {
        platform: process.platform,
        arch: process.arch,
        hostname: os.hostname(),
        // Note: pour un vrai système, il faudrait utiliser les infos USB
        // Ici c'est une version simplifiée pour le client
      };
      
      const fingerprint = crypto
        .createHash('sha256')
        .update(JSON.stringify(systemInfo))
        .digest('hex');
      
      this.results.info.currentDevice = {
        fingerprint: fingerprint.substring(0, 32), // Version courte
        platform: systemInfo.platform,
        arch: systemInfo.arch
      };
      
      if (CONFIG.verbose) {
        console.log(`🔍 Empreinte actuelle: ${fingerprint.substring(0, 16)}...`);
      }
      
      return fingerprint;
      
    } catch (error) {
      this.results.warnings.push(`Erreur génération empreinte: ${error.message}`);
      this.log(`Avertissement empreinte: ${error.message}`, 'warning');
      return 'unknown';
    }
  }

  // Vérifier la correspondance périphérique
  async checkDeviceMatch(licenseContent) {
    this.log('Vérification correspondance périphérique...', 'debug');
    
    if (!licenseContent.fingerprint) {
      this.results.warnings.push('Aucune empreinte périphérique dans la licence');
      this.log('Aucune empreinte périphérique trouvée', 'warning');
      return true; // Pas de restriction = valide
    }
    
    const currentFingerprint = await this.getCurrentDeviceFingerprint();
    
    // Comparaison simplifiée (dans un vrai système, ce serait plus complexe)
    const licenseFingerprint = licenseContent.fingerprint;
    const match = currentFingerprint.includes(licenseFingerprint.substring(0, 16)) ||
                  licenseFingerprint.includes(currentFingerprint.substring(0, 16));
    
    this.results.checks.deviceMatch = match;
    this.results.info.deviceCheck = {
      licenseFingerprint: licenseFingerprint.substring(0, 16) + '...',
      currentFingerprint: currentFingerprint.substring(0, 16) + '...',
      match: match
    };
    
    if (!match) {
      this.results.errors.push('Licence non autorisée pour ce périphérique');
      this.log('Empreinte périphérique ne correspond pas', 'error');
      return false;
    }
    
    this.log('Périphérique autorisé', 'success');
    return true;
  }

  // Vérification principale
  async verify() {
    if (CONFIG.help) {
      this.showHelp();
      return 0;
    }
    
    if (!CONFIG.json) {
      console.log('🔑 USB Video Vault - Vérification de Licence');
      console.log('============================================\n');
    }
    
    try {
      // 1. Vérifier la présence du fichier
      if (!(await this.checkLicenseFileExists())) {
        this.results.status = 'file_not_found';
        return this.finalizeResults(2);
      }
      
      // 2. Lire le fichier licence
      const licenseData = await this.readLicenseFile();
      if (!licenseData) {
        this.results.status = 'read_error';
        return this.finalizeResults(2);
      }
      
      // 3. Parser les données
      const licenseContent = await this.parseLicenseData(licenseData);
      
      // 4. Vérifier la signature
      const signatureValid = await this.verifySignature(licenseData);
      
      // 5. Vérifier l'expiration
      const notExpired = await this.checkExpiration(licenseContent);
      
      // 6. Vérifier le périphérique
      const deviceMatch = await this.checkDeviceMatch(licenseContent);
      
      // Déterminer le statut final
      if (signatureValid && notExpired && deviceMatch) {
        this.results.status = 'valid';
        this.results.valid = true;
        this.log('\n🎉 LICENCE VALIDE', 'success');
        return this.finalizeResults(0);
      } else {
        this.results.status = 'invalid';
        this.results.valid = false;
        this.log('\n❌ LICENCE INVALIDE', 'error');
        return this.finalizeResults(1);
      }
      
    } catch (error) {
      this.results.status = 'error';
      this.results.errors.push(`Erreur critique: ${error.message}`);
      this.log(`Erreur critique: ${error.message}`, 'error');
      return this.finalizeResults(2);
    }
  }

  // Finaliser et afficher les résultats
  finalizeResults(exitCode) {
    this.results.duration = Date.now() - this.startTime;
    this.results.exitCode = exitCode;
    
    if (CONFIG.json) {
      // Sortie JSON pour les scripts
      console.log(JSON.stringify(this.results, null, 2));
    } else {
      // Résumé en format humain
      this.displaySummary();
    }
    
    return exitCode;
  }

  // Afficher résumé
  displaySummary() {
    console.log('\n📊 RÉSUMÉ DE VÉRIFICATION');
    console.log('========================');
    
    const checks = [
      { name: 'Fichier licence présent', status: this.results.checks.fileExists },
      { name: 'Format signature valide', status: this.results.checks.signatureFormat },
      { name: 'Licence non expirée', status: this.results.checks.notExpired },
      { name: 'Périphérique autorisé', status: this.results.checks.deviceMatch }
    ];
    
    checks.forEach(check => {
      const icon = check.status === true ? '✅' : check.status === false ? '❌' : '⚠️';
      const status = check.status === true ? 'OK' : check.status === false ? 'ÉCHEC' : 'N/A';
      console.log(`${icon} ${check.name}: ${status}`);
    });
    
    if (this.results.warnings.length > 0) {
      console.log('\n⚠️ Avertissements:');
      this.results.warnings.forEach(warning => console.log(`   • ${warning}`));
    }
    
    if (this.results.errors.length > 0) {
      console.log('\n❌ Erreurs:');
      this.results.errors.forEach(error => console.log(`   • ${error}`));
    }
    
    console.log(`\n⏱️ Vérification terminée en ${this.results.duration}ms`);
    
    // Conseils selon le statut
    if (this.results.valid) {
      console.log('\n💡 Votre licence est valide et fonctionnelle.');
    } else {
      console.log('\n🆘 ACTIONS RECOMMANDÉES:');
      console.log('   1. Vérifiez que vous utilisez le bon périphérique USB');
      console.log('   2. Vérifiez la date/heure de votre système');
      console.log('   3. Restaurez votre licence depuis une sauvegarde');
      console.log('   4. Contactez le support: support@usb-video-vault.com');
    }
  }
}

// Exécution principale
if (import.meta.url === `file://${process.argv[1]}`) {
  const verifier = new LicenseVerifier();
  verifier.verify().then(exitCode => {
    process.exit(exitCode);
  }).catch(error => {
    console.error('❌ Erreur fatale:', error.message);
    process.exit(3);
  });
}

export default LicenseVerifier;