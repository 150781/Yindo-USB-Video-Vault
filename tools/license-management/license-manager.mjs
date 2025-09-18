#!/usr/bin/env node

/**
 * 🔐 LICENSE MANAGEMENT SYSTEM
 * KEK Master + Registry + Revocation Pack
 */

import { existsSync, writeFileSync, readFileSync, mkdirSync } from 'fs';
import { join } from 'path';
import crypto from 'crypto';

class LicenseManager {
  constructor() {
    this.baseDir = './tools/license-management';
    this.secretsDir = join(this.baseDir, 'secrets');
    this.registryDir = join(this.baseDir, 'registry');
    this.revocationDir = join(this.baseDir, 'revocation');
    
    // Créer directories
    [this.secretsDir, this.registryDir, this.revocationDir].forEach(dir => {
      if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
      }
    });
    
    this.registryPath = join(this.registryDir, 'issued.json');
    this.kekPath = join(this.secretsDir, 'kek-master.json');
  }
  
  // 1. Initialiser KEK Maître (Une seule fois !)
  async initializeMasterKEK(force = false) {
    if (existsSync(this.kekPath) && !force) {
      throw new Error('KEK Maître déjà initialisée ! Utiliser --force pour écraser.');
    }
    
    console.log('🔐 Génération KEK Maître...');
    
    // Générer clé AES-256 aléatoire
    const masterKey = crypto.randomBytes(32);
    const salt = crypto.randomBytes(32);
    const created = new Date().toISOString();
    
    const kek = {
      version: "1.0.0",
      created,
      algorithm: "AES-256-GCM",
      key: masterKey.toString('base64'),
      salt: salt.toString('base64'),
      metadata: {
        purpose: "USB Video Vault Master KEK",
        usage: "Offline storage only - Never distribute",
        security: "Store in secure offline location"
      }
    };
    
    // Écrire avec permissions restreintes
    writeFileSync(this.kekPath, JSON.stringify(kek, null, 2), { mode: 0o600 });
    
    console.log('✅ KEK Maître générée et sauvée (OFFLINE)');
    console.log(`📁 Chemin: ${this.kekPath}`);
    console.log('⚠️  IMPORTANT: Sauvegarder ce fichier hors ligne !');
    
    return kek;
  }
  
  // 2. Initialiser registre licences
  async initializeRegistry() {
    if (existsSync(this.registryPath)) {
      console.log('📋 Registre existe déjà');
      return this.loadRegistry();
    }
    
    const registry = {
      version: "1.0.0",
      created: new Date().toISOString(),
      licenses: [],
      stats: {
        total_issued: 0,
        active: 0,
        expired: 0,
        revoked: 0
      }
    };
    
    writeFileSync(this.registryPath, JSON.stringify(registry, null, 2));
    console.log('✅ Registre licences initialisé');
    
    return registry;
  }
  
  // 3. Enregistrer nouvelle licence
  async registerLicense(licenseData) {
    const registry = await this.loadRegistry();
    
    // Vérifier ID unique
    if (registry.licenses.find(l => l.id === licenseData.id)) {
      throw new Error(`Licence ID déjà existante: ${licenseData.id}`);
    }
    
    const license = {
      id: licenseData.id,
      client: licenseData.client,
      issued: new Date().toISOString(),
      expires: licenseData.expires,
      features: licenseData.features || ['playback'],
      binding: licenseData.binding || { usb: 'auto', machine: 'optional' },
      hash: licenseData.hash || '',
      status: 'active',
      metadata: {
        created_by: 'License Manager',
        version: '1.0.0'
      }
    };
    
    registry.licenses.push(license);
    registry.stats.total_issued++;
    registry.stats.active++;
    
    this.saveRegistry(registry);
    
    console.log(`✅ Licence enregistrée: ${license.id}`);
    return license;
  }
  
  // 4. Créer pack de révocation
  async createRevocationPack(licenseIds, reason = 'security_incident') {
    const registry = await this.loadRegistry();
    const timestamp = new Date().toISOString();
    const packId = `revocation-${Date.now()}`;
    
    const revocationPack = {
      version: "1.0.0",
      pack_id: packId,
      created: timestamp,
      reason,
      revoked_licenses: [],
      signature: null
    };
    
    // Traiter chaque licence
    for (const licenseId of licenseIds) {
      const license = registry.licenses.find(l => l.id === licenseId);
      if (!license) {
        console.warn(`⚠️ Licence introuvable: ${licenseId}`);
        continue;
      }
      
      if (license.status === 'revoked') {
        console.warn(`⚠️ Licence déjà révoquée: ${licenseId}`);
        continue;
      }
      
      // Marquer comme révoquée
      license.status = 'revoked';
      license.revoked = timestamp;
      license.revocation_reason = reason;
      
      revocationPack.revoked_licenses.push({
        id: licenseId,
        client: license.client,
        hash: license.hash,
        revoked: timestamp
      });
      
      registry.stats.active--;
      registry.stats.revoked++;
      
      console.log(`❌ Licence révoquée: ${licenseId}`);
    }
    
    // Signer le pack avec KEK
    revocationPack.signature = await this.signRevocationPack(revocationPack);
    
    // Sauvegarder
    const packPath = join(this.revocationDir, `${packId}.json`);
    writeFileSync(packPath, JSON.stringify(revocationPack, null, 2));
    
    this.saveRegistry(registry);
    
    console.log(`🔒 Pack révocation créé: ${packPath}`);
    console.log(`📊 Licences révoquées: ${revocationPack.revoked_licenses.length}`);
    
    return {
      packId,
      packPath,
      revokedCount: revocationPack.revoked_licenses.length
    };
  }
  
  // 5. Rotation clés (pour futures versions)
  async rotateKeys() {
    console.log('🔄 Rotation des clés...');
    
    const oldKek = await this.loadKEK();
    const newKek = await this.initializeMasterKEK(true);
    
    // Archiver ancienne clé
    const archivePath = join(this.secretsDir, `kek-archive-${Date.now()}.json`);
    writeFileSync(archivePath, JSON.stringify(oldKek, null, 2));
    
    console.log('✅ Rotation terminée');
    console.log(`📦 Ancienne clé archivée: ${archivePath}`);
    console.log('⚠️  Toutes les nouvelles licences utiliseront la nouvelle KEK');
    
    return { oldKek, newKek, archivePath };
  }
  
  // 6. Statistiques du registre
  async getStats() {
    const registry = await this.loadRegistry();
    
    // Recalculer stats en temps réel
    const stats = {
      total: registry.licenses.length,
      active: 0,
      expired: 0,
      revoked: 0,
      expiring_soon: 0
    };
    
    const now = new Date();
    const weekFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    
    registry.licenses.forEach(license => {
      switch (license.status) {
        case 'active':
          const expiry = new Date(license.expires);
          if (expiry <= now) {
            stats.expired++;
          } else if (expiry <= weekFromNow) {
            stats.expiring_soon++;
            stats.active++;
          } else {
            stats.active++;
          }
          break;
        case 'revoked':
          stats.revoked++;
          break;
        case 'expired':
          stats.expired++;
          break;
      }
    });
    
    return stats;
  }
  
  // Helpers
  async loadKEK() {
    if (!existsSync(this.kekPath)) {
      throw new Error('KEK Maître non initialisée. Utiliser: init-kek');
    }
    return JSON.parse(readFileSync(this.kekPath, 'utf8'));
  }
  
  async loadRegistry() {
    if (!existsSync(this.registryPath)) {
      return await this.initializeRegistry();
    }
    return JSON.parse(readFileSync(this.registryPath, 'utf8'));
  }
  
  saveRegistry(registry) {
    registry.updated = new Date().toISOString();
    writeFileSync(this.registryPath, JSON.stringify(registry, null, 2));
  }
  
  async signRevocationPack(pack) {
    try {
      const kek = await this.loadKEK();
      const key = Buffer.from(kek.key, 'base64');
      
      // Créer signature HMAC
      const data = JSON.stringify({
        pack_id: pack.pack_id,
        created: pack.created,
        revoked_licenses: pack.revoked_licenses
      });
      
      const hmac = crypto.createHmac('sha256', key);
      hmac.update(data);
      return hmac.digest('hex');
    } catch (error) {
      console.warn('⚠️ Signature échouée:', error.message);
      return 'unsigned';
    }
  }
}

// CLI Interface
async function main() {
  const [command, ...args] = process.argv.slice(2);
  const manager = new LicenseManager();
  
  try {
    switch (command) {
      case 'init-kek':
        const force = args.includes('--force');
        await manager.initializeMasterKEK(force);
        break;
        
      case 'init-registry':
        await manager.initializeRegistry();
        break;
        
      case 'register':
        const licenseData = JSON.parse(args[0] || '{}');
        await manager.registerLicense(licenseData);
        break;
        
      case 'revoke':
        const ids = args[0].split(',');
        const reason = args[1] || 'manual_revocation';
        const result = await manager.createRevocationPack(ids, reason);
        console.log(`📦 Pack: ${result.packId}`);
        break;
        
      case 'rotate':
        await manager.rotateKeys();
        break;
        
      case 'stats':
        const stats = await manager.getStats();
        console.log('📊 Statistiques licences:');
        console.log(`   Total: ${stats.total}`);
        console.log(`   Actives: ${stats.active}`);
        console.log(`   Expirées: ${stats.expired}`);
        console.log(`   Révoquées: ${stats.revoked}`);
        console.log(`   Expirent bientôt: ${stats.expiring_soon}`);
        break;
        
      default:
        console.log(`
🔐 LICENSE MANAGEMENT SYSTEM

Commands:
  init-kek [--force]              Initialiser KEK maître
  init-registry                   Initialiser registre licences
  register '{"id":"...","client":"..."}'  Enregistrer licence
  revoke "ID1,ID2" "raison"       Créer pack révocation
  rotate                          Rotation clés
  stats                          Afficher statistiques

Examples:
  node license-manager.mjs init-kek
  node license-manager.mjs register '{"id":"TEST-001","client":"ACME","expires":"2026-12-31T23:59:59Z"}'
  node license-manager.mjs revoke "TEST-001,TEST-002" "security_incident"
  node license-manager.mjs stats
`);
        break;
    }
  } catch (error) {
    console.error(`❌ Erreur: ${error.message}`);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

export { LicenseManager };