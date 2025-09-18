#!/usr/bin/env node

// Test basique du CLI
import { execSync } from 'child_process';
import { join } from 'path';

console.log('🧪 Test du CLI USB Video Vault');

const cliPath = join(process.cwd(), 'dist', 'index.js');

try {
  // Test commande info
  console.log('\n📝 Test: vault-cli info');
  const infoOutput = execSync(`node "${cliPath}" info`, { encoding: 'utf8' });
  console.log(infoOutput);

  // Test commande help
  console.log('\n📝 Test: vault-cli --help');
  const helpOutput = execSync(`node "${cliPath}" --help`, { encoding: 'utf8' });
  console.log(helpOutput);

  // Test gen-license dry run
  console.log('\n📝 Test: vault-cli gen-license --test-mode');
  const genOutput = execSync(`node "${cliPath}" gen-license --test-mode --output ./test-licenses`, { encoding: 'utf8' });
  console.log(genOutput);

  console.log('\n✅ Tests CLI réussis');

} catch (error) {
  console.error('\n❌ Erreur test CLI:', error?.message || error);
  console.error(error.stdout?.toString());
  process.exit(1);
}
