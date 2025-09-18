#!/usr/bin/env node
/**
 * Script de validation complète des tests de sécurité TypeScript
 * Vérifie que la migration est réussie et tous les diagnostics résolus
 */

import { execSync } from 'child_process';
import { existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface ValidationResult {
  test: string;
  passed: boolean;
  details: string;
}

class MigrationValidator {
  private results: ValidationResult[] = [];

  addResult(test: string, passed: boolean, details: string): void {
    this.results.push({ test, passed, details });
    const icon = passed ? '✅' : '❌';
    console.log(`${icon} ${test}: ${details}`);
  }

  async validateMigration(): Promise<boolean> {
    console.log('🔍 === VALIDATION MIGRATION TYPESCRIPT ===\n');

    // 1. Vérifier que les anciens fichiers .mjs n'existent plus
    this.validateOldFilesRemoved();

    // 2. Vérifier que les nouveaux fichiers .ts existent
    this.validateNewFilesExist();

    // 3. Vérifier la configuration TypeScript
    this.validateTsConfig();

    // 4. Vérifier les scripts npm
    this.validateNpmScripts();

    // 5. Exécuter le typecheck
    await this.validateTypecheck();

    // 6. Générer le rapport
    this.generateReport();

    return this.results.every(r => r.passed);
  }

  private validateOldFilesRemoved(): void {
    console.log('📁 Vérification suppression anciens fichiers...');

    const oldFiles = [
      'test-security-complete.mjs',
      'test-security-hardening.mjs'
    ];

    for (const file of oldFiles) {
      const exists = existsSync(join(__dirname, '..', file));
      this.addResult(
        `Suppression ${file}`,
        !exists,
        exists ? 'Fichier encore présent' : 'Fichier supprimé'
      );
    }
  }

  private validateNewFilesExist(): void {
    console.log('\n📄 Vérification nouveaux fichiers TypeScript...');

    const newFiles = [
      'test/test-security-complete.test.ts',
      'test/test-security-hardening.test.ts'
    ];

    for (const file of newFiles) {
      const exists = existsSync(join(__dirname, '..', file));
      this.addResult(
        `Existence ${file}`,
        exists,
        exists ? 'Fichier créé' : 'Fichier manquant'
      );
    }
  }

  private validateTsConfig(): void {
    console.log('\n⚙️ Vérification configuration TypeScript...');

    try {
      const tsConfigPath = join(__dirname, '..', 'tsconfig.json');
      const exists = existsSync(tsConfigPath);
      
      this.addResult(
        'tsconfig.json',
        exists,
        exists ? 'Configuration trouvée' : 'Configuration manquante'
      );

      if (exists) {
        const config = JSON.parse(require('fs').readFileSync(tsConfigPath, 'utf8'));
        
        // Vérifier les includes
        const hasTestInclude = config.include?.some((path: string) => path.includes('test'));
        this.addResult(
          'Inclusion test/**',
          hasTestInclude,
          hasTestInclude ? 'Tests inclus dans tsconfig' : 'Tests non inclus'
        );

        // Vérifier les types
        const hasNodeTypes = config.compilerOptions?.types?.includes('node');
        this.addResult(
          'Types Node.js',
          hasNodeTypes,
          hasNodeTypes ? 'Types Node.js configurés' : 'Types Node.js manquants'
        );
      }
    } catch (error) {
      this.addResult(
        'tsconfig.json',
        false,
        `Erreur: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private validateNpmScripts(): void {
    console.log('\n📦 Vérification scripts npm...');

    try {
      const packageJsonPath = join(__dirname, '..', 'package.json');
      const packageJson = JSON.parse(require('fs').readFileSync(packageJsonPath, 'utf8'));
      
      const requiredScripts = [
        'test:typecheck',
        'test:security',
        'test:hardening',
        'test:direct'
      ];

      for (const script of requiredScripts) {
        const exists = script in packageJson.scripts;
        this.addResult(
          `Script ${script}`,
          exists,
          exists ? 'Script configuré' : 'Script manquant'
        );
      }
    } catch (error) {
      this.addResult(
        'Scripts npm',
        false,
        `Erreur: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private async validateTypecheck(): Promise<void> {
    console.log('\n🔍 Exécution typecheck...');

    try {
      const output = execSync('npm run test:typecheck', { 
        encoding: 'utf8',
        cwd: join(__dirname, '..'),
        stdio: 'pipe'
      });

      this.addResult(
        'TypeScript Typecheck',
        true,
        'Aucune erreur TypeScript détectée'
      );
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      this.addResult(
        'TypeScript Typecheck',
        false,
        `Erreurs TypeScript: ${errorMessage}`
      );
    }
  }

  private generateReport(): void {
    console.log('\n📊 === RAPPORT DE VALIDATION ===');
    
    const total = this.results.length;
    const passed = this.results.filter(r => r.passed).length;
    const failed = this.results.filter(r => !r.passed);
    
    console.log(`✅ Tests réussis: ${passed}/${total}`);
    console.log(`❌ Tests échoués: ${failed.length}/${total}`);
    
    if (failed.length > 0) {
      console.log('\n❌ ÉCHECS DÉTECTÉS:');
      failed.forEach(r => console.log(`   - ${r.test}: ${r.details}`));
    }
    
    const success = failed.length === 0;
    console.log(`\n${success ? '🎉' : '🚨'} MIGRATION ${success ? 'RÉUSSIE' : 'ÉCHOUÉE'}`);
    
    if (success) {
      console.log('✨ Tous les diagnostics TypeScript ont été éliminés');
      console.log('✨ Scripts de test migrés vers TypeScript');
      console.log('✨ Configuration et scripts npm mis à jour');
    }
  }

  getResults(): ValidationResult[] {
    return this.results;
  }
}

async function main(): Promise<void> {
  const validator = new MigrationValidator();
  const success = await validator.validateMigration();
  
  process.exit(success ? 0 : 1);
}

if (import.meta.url === new URL(process.argv[1], 'file:').href) {
  main().catch(console.error);
}

export { MigrationValidator };
export type { ValidationResult };
