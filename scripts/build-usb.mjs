#!/usr/bin/env node

/**
 * Script de build USB Video Vault
 * Génère un package portable prêt pour USB
 */

import fs from 'fs-extra';
import path from 'path';
import { execSync } from 'child_process';

const OUTPUT_DIR = 'usb-package';
const VAULT_NAME = 'vault';

async function buildUSBPackage() {
  console.log('🚀 Building USB Video Vault Package...\n');

  // 1. Clean and build
  console.log('📦 Building application...');
  execSync('npm run build', { stdio: 'inherit' });
  execSync('npm run dist:win', { stdio: 'inherit' });

  // 2. Create package directory
  console.log('\n📁 Creating USB package directory...');
  await fs.remove(OUTPUT_DIR);
  await fs.ensureDir(OUTPUT_DIR);

  // 3. Copy portable executable
  console.log('📋 Copying portable executable...');
  const exeFiles = await fs.readdir('dist');
  const portableExe = exeFiles.find(f => f.includes('portable.exe'));
  if (!portableExe) {
    throw new Error('Portable executable not found in dist/');
  }
  await fs.copy(`dist/${portableExe}`, `${OUTPUT_DIR}/${portableExe}`);

  // 4. Create vault structure
  console.log('🔐 Creating vault structure...');
  const vaultDir = path.join(OUTPUT_DIR, VAULT_NAME);
  
  // Initialize proper vault with packager
  console.log('📦 Initializing vault...');
  execSync(`node tools/packager/pack.js init --vault ${OUTPUT_DIR}/${VAULT_NAME}`, { stdio: 'inherit' });
  
  // Add media files
  console.log('🎵 Adding media...');
  execSync(`node tools/packager/pack.js add-media --vault ${OUTPUT_DIR}/${VAULT_NAME} --file "src/assets/demo.mp4" --title "Demo Video" --artist "Test Artist"`, { stdio: 'inherit' });
  execSync(`node tools/packager/pack.js add-media --vault ${OUTPUT_DIR}/${VAULT_NAME} --file "src/assets/Odogwu.mp4" --title "Odogwu" --artist "Burna Boy"`, { stdio: 'inherit' });
  
  // Build and seal manifest
  console.log('📋 Building manifest...');
  execSync(`node tools/packager/pack.js build-manifest --vault ${OUTPUT_DIR}/${VAULT_NAME}`, { stdio: 'inherit' });
  execSync(`node tools/packager/pack.js seal-manifest --vault ${OUTPUT_DIR}/${VAULT_NAME}`, { stdio: 'inherit' });
  
  // Generate license
  console.log('🔑 Generating license...');
  const machineId = '928fb2e42e9de3a9e7305842ef114ae7ef35cb2e7e8003a37da07fd410e45bc5';
  execSync(`node tools/packager/pack.js issue-license --vault ${OUTPUT_DIR}/${VAULT_NAME} --owner "Test User" --expiry "2025-12-31" --passphrase "test123" --machine "${machineId}" --all`, { stdio: 'inherit' });

  // 5. Create launcher
  console.log('🚀 Creating launcher...');
  const launchScript = `@echo off
echo Lancement de USB Video Vault...
start "" "%~dp0${portableExe}"`;
  await fs.writeFile(path.join(OUTPUT_DIR, 'launch.bat'), launchScript);

  // 6. Copy documentation
  console.log('📖 Copying documentation...');
  await fs.copy('test-usb/README.md', path.join(OUTPUT_DIR, 'README.md'));

  console.log(`\n✅ USB package created in: ${OUTPUT_DIR}/`);
  console.log('\n📋 Package contents:');
  
  const listFiles = async (dir, prefix = '') => {
    const items = await fs.readdir(dir, { withFileTypes: true });
    for (const item of items) {
      const fullPath = path.join(dir, item.name);
      if (item.isDirectory()) {
        console.log(`${prefix}📁 ${item.name}/`);
        await listFiles(fullPath, prefix + '  ');
      } else {
        const stats = await fs.stat(fullPath);
        const size = (stats.size / 1024 / 1024).toFixed(1);
        console.log(`${prefix}📄 ${item.name} (${size} MB)`);
      }
    }
  };

  await listFiles(OUTPUT_DIR);
  
  console.log('\n🎉 Ready for USB deployment!');
  console.log(`💡 Copy the contents of ${OUTPUT_DIR}/ to your USB drive`);
}

// Run if called directly
console.log('Script URL:', import.meta.url);
console.log('Process argv[1]:', process.argv[1]);

buildUSBPackage().catch(err => {
  console.error('Build failed:', err);
  process.exit(1);
});

export { buildUSBPackage };
