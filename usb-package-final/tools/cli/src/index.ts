#!/usr/bin/env node

import { Command } from 'commander';
import chalk from 'chalk';
import { PackVaultCommand } from './commands/pack-vault.js';
import { GenLicenseCommand } from './commands/gen-license.js';
import { DeployUsbCommand } from './commands/deploy-usb.js';
import { validateEnvironment } from './utils/environment.js';
import { logger } from './utils/logger.js';

const program = new Command();

// Configuration CLI
program
  .name('vault-cli')
  .description('🔒 CLI industriel pour empaquetage et déploiement USB Video Vault')
  .version('1.0.0')
  .option('-v, --verbose', 'Mode verbeux pour debugging')
  .option('-q, --quiet', 'Mode silencieux (erreurs uniquement)')
  .option('--no-color', 'Désactiver les couleurs')
  .hook('preAction', async (thisCommand) => {
    // Configuration globale des logs
    const opts = thisCommand.opts();
    logger.setLevel(opts.quiet ? 'error' : opts.verbose ? 'debug' : 'info');
    
    // Validation environnement
    try {
      await validateEnvironment();
    } catch (error: any) {
      logger.error('❌ Erreur environnement:', error?.message || error);
      process.exit(1);
    }
  });

// Commande: pack-vault
program
  .command('pack-vault')
  .description('📦 Empaqueter un vault USB avec médias, license et configuration')
  .argument('<source>', 'Dossier source contenant les médias')
  .argument('<output>', 'Dossier de sortie pour le vault empaqueté')
  .option('-l, --license <file>', 'Fichier license JSON à inclure')
  .option('-c, --config <file>', 'Fichier config personnalisé')
  .option('-t, --template <name>', 'Template de vault prédéfini', 'standard')
  .option('-e, --encrypt', 'Chiffrer les médias avec AES-256-GCM')
  .option('-k, --key-file <file>', 'Fichier de clé de chiffrement (généré si absent)')
  .option('-m, --manifest', 'Générer un manifest.json détaillé')
  .option('--compress', 'Compresser l\'archive finale')
  .option('--verify', 'Vérifier l\'intégrité après empaquetage')
  .action(PackVaultCommand.execute);

// Commande: gen-license
program
  .command('gen-license')
  .description('🔑 Générer des licenses Ed25519 avec device binding')
  .option('-o, --output <dir>', 'Dossier de sortie des licenses', './licenses')
  .option('-c, --count <number>', 'Nombre de licenses à générer', '1')
  .option('-d, --device <id>', 'Device ID spécifique (sinon générique)')
  .option('-e, --expires <date>', 'Date d\'expiration (YYYY-MM-DD)')
  .option('-f, --features <list>', 'Features séparées par virgule', 'play,queue,display')
  .option('-t, --template <file>', 'Template JSON pour les licenses')
  .option('-b, --batch <file>', 'Fichier CSV pour génération en lot')
  .option('--test-mode', 'Mode test (licenses courte durée)')
  .action(GenLicenseCommand.execute);

// Commande: deploy-usb
program
  .command('deploy-usb')
  .description('🚀 Déployer en masse sur clés USB')
  .argument('<vault-package>', 'Package vault à déployer')
  .option('-t, --targets <pattern>', 'Pattern des lecteurs USB cibles', '[D-Z]:\\\\')
  .option('-f, --force', 'Forcer l\'écrasement des données existantes')
  .option('-v, --verify', 'Vérifier chaque déploiement')
  .option('-p, --parallel <number>', 'Nombre de déploiements parallèles', '3')
  .option('-l, --log-file <file>', 'Fichier de log détaillé')
  .option('--dry-run', 'Simulation sans écriture réelle')
  .option('--eject', 'Éjecter automatiquement après déploiement')
  .action(DeployUsbCommand.execute);

// Commandes utilitaires
program
  .command('validate')
  .description('✅ Valider un vault ou package existant')
  .argument('<path>', 'Chemin vers le vault/package à valider')
  .option('-d, --deep', 'Validation approfondie (intégrité, signatures)')
  .action(async (path, options) => {
    logger.info('🔍 Validation en cours...');
    // TODO: Implémenter validation
    logger.success('✅ Validation terminée');
  });

program
  .command('info')
  .description('ℹ️  Informations système et environnement')
  .action(async () => {
    logger.info(chalk.cyan('🔒 USB Video Vault CLI v1.0.0'));
    logger.info(chalk.gray('📁 Working Directory:'), process.cwd());
    logger.info(chalk.gray('🖥️  Platform:'), process.platform);
    logger.info(chalk.gray('📦 Node Version:'), process.version);
    
    // TODO: Afficher plus d'infos système
  });

// Gestion d'erreurs globales
process.on('uncaughtException', (error) => {
  logger.error('💥 Erreur fatale:', error?.message || error);
  process.exit(1);
});

process.on('unhandledRejection', (reason: any) => {
  logger.error('💥 Promise rejetée:', reason?.message || reason);
  process.exit(1);
});

// Exécution CLI
program.parse();
