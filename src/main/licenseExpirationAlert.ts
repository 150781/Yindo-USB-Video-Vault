// License Expiration Alert System
// Système d'alerte d'expiration de licence USB Video Vault

import * as electron from 'electron';
import type { BrowserWindow } from 'electron';
const { BrowserWindow: BrowserWindowImpl, dialog, shell } = electron;
import { spawn } from 'child_process';

export interface ExpirationAlert {
  daysRemaining: number;
  severity: 'info' | 'warning' | 'critical' | 'expired';
  title: string;
  message: string;
  actions: ExpirationAction[];
}

export interface ExpirationAction {
  label: string;
  action: 'contact_support' | 'check_license' | 'backup_data' | 'dismiss' | 'remind_later';
  url?: string;
}

export class LicenseExpirationManager {
  private static instance: LicenseExpirationManager;
  private lastAlertShown: number = 0;
  private reminderInterval: number = 24 * 60 * 60 * 1000; // 24 heures par défaut
  private alertWindow: BrowserWindow | null = null;

  static getInstance(): LicenseExpirationManager {
    if (!LicenseExpirationManager.instance) {
      LicenseExpirationManager.instance = new LicenseExpirationManager();
    }
    return LicenseExpirationManager.instance;
  }

  // Vérifier et afficher alerte si nécessaire
  async checkAndShowExpirationAlert(licenseData: any): Promise<void> {
    try {
      const alert = this.evaluateExpiration(licenseData);

      if (alert && this.shouldShowAlert(alert)) {
        await this.showExpirationAlert(alert);
        this.lastAlertShown = Date.now();
      }

    } catch (error) {
      console.error('❌ Erreur vérification expiration:', error);
    }
  }

  // Évaluer l'état d'expiration de la licence
  private evaluateExpiration(licenseData: any): ExpirationAlert | null {
    if (!licenseData || !licenseData.expires) {
      return null;
    }

    const now = new Date();
    const expirationDate = new Date(licenseData.expires);
    const daysRemaining = Math.ceil((expirationDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

    // Licence expirée
    if (daysRemaining <= 0) {
      return {
        daysRemaining: Math.abs(daysRemaining),
        severity: 'expired',
        title: '🚫 Licence Expirée',
        message: `Votre licence USB Video Vault a expiré il y a ${Math.abs(daysRemaining)} jour(s).\n\nL'application ne peut plus fonctionner avec une licence expirée. Contactez le support pour renouveler votre licence.`,
        actions: [
          {
            label: 'Contacter le Support',
            action: 'contact_support',
            url: 'mailto:support@usb-video-vault.com?subject=Renouvellement de licence expirée'
          },
          {
            label: 'Sauvegarder mes Données',
            action: 'backup_data'
          }
        ]
      };
    }

    // Critique (≤ 7 jours)
    if (daysRemaining <= 7) {
      return {
        daysRemaining,
        severity: 'critical',
        title: '⚠️ Licence Expire Bientôt',
        message: `Votre licence USB Video Vault expire dans ${daysRemaining} jour(s) seulement !\n\nAction urgente requise pour éviter l'interruption du service. Contactez immédiatement le support pour renouveler votre licence.`,
        actions: [
          {
            label: 'Contacter le Support URGENT',
            action: 'contact_support',
            url: 'mailto:support@usb-video-vault.com?subject=Renouvellement licence urgent - expire dans ' + daysRemaining + ' jours'
          },
          {
            label: 'Vérifier ma Licence',
            action: 'check_license'
          },
          {
            label: 'Me Rappeler Demain',
            action: 'remind_later'
          }
        ]
      };
    }

    // Avertissement (≤ 30 jours)
    if (daysRemaining <= 30) {
      return {
        daysRemaining,
        severity: 'warning',
        title: '⏰ Renouvellement Licence Recommandé',
        message: `Votre licence USB Video Vault expire dans ${daysRemaining} jour(s).\n\nIl est recommandé de commencer le processus de renouvellement maintenant pour éviter toute interruption.`,
        actions: [
          {
            label: 'Contacter le Support',
            action: 'contact_support',
            url: 'mailto:support@usb-video-vault.com?subject=Renouvellement de licence - expire dans ' + daysRemaining + ' jours'
          },
          {
            label: 'Vérifier ma Licence',
            action: 'check_license'
          },
          {
            label: 'Me Rappeler dans 7 jours',
            action: 'remind_later'
          },
          {
            label: 'Ne Plus Afficher',
            action: 'dismiss'
          }
        ]
      };
    }

    // Information (≤ 60 jours)
    if (daysRemaining <= 60) {
      return {
        daysRemaining,
        severity: 'info',
        title: '📅 Information Licence',
        message: `Votre licence USB Video Vault expire dans ${daysRemaining} jour(s).\n\nVous pouvez commencer à planifier le renouvellement si nécessaire.`,
        actions: [
          {
            label: 'Contacter le Support',
            action: 'contact_support',
            url: 'mailto:support@usb-video-vault.com?subject=Information renouvellement licence'
          },
          {
            label: 'Vérifier ma Licence',
            action: 'check_license'
          },
          {
            label: 'Me Rappeler dans 15 jours',
            action: 'remind_later'
          },
          {
            label: 'OK',
            action: 'dismiss'
          }
        ]
      };
    }

    return null; // Pas d'alerte nécessaire
  }

  // Déterminer si l'alerte doit être affichée
  private shouldShowAlert(alert: ExpirationAlert): boolean {
    const timeSinceLastAlert = Date.now() - this.lastAlertShown;

    switch (alert.severity) {
      case 'expired':
        return true; // Toujours afficher pour licence expirée

      case 'critical':
        return timeSinceLastAlert > (6 * 60 * 60 * 1000); // Toutes les 6 heures

      case 'warning':
        return timeSinceLastAlert > (24 * 60 * 60 * 1000); // Une fois par jour

      case 'info':
        return timeSinceLastAlert > (7 * 24 * 60 * 60 * 1000); // Une fois par semaine

      default:
        return false;
    }
  }

  // Afficher l'alerte d'expiration
  private async showExpirationAlert(alert: ExpirationAlert): Promise<void> {
    try {
      // Utiliser dialog natif pour maximum compatibilité
      const result = await dialog.showMessageBox({
        type: this.getDialogType(alert.severity),
        title: alert.title,
        message: alert.message,
        detail: this.getAdditionalInfo(alert),
        buttons: alert.actions.map(action => action.label),
        defaultId: 0,
        cancelId: alert.actions.length - 1,
        noLink: false
      });

      // Traiter l'action choisie
      const selectedAction = alert.actions[result.response];
      if (selectedAction) {
        await this.handleExpirationAction(selectedAction, alert);
      }

    } catch (error) {
      console.error('❌ Erreur affichage alerte:', error);

      // Fallback : alerte simple
      const result = await dialog.showMessageBox({
        type: 'warning',
        title: 'Alerte Licence',
        message: `Votre licence expire dans ${alert.daysRemaining} jours.`,
        buttons: ['OK', 'Contacter Support'],
        defaultId: 0
      });

      if (result.response === 1) {
        shell.openExternal('mailto:support@usb-video-vault.com?subject=Alerte expiration licence');
      }
    }
  }

  // Traiter les actions utilisateur
  private async handleExpirationAction(action: ExpirationAction, alert: ExpirationAlert): Promise<void> {
    switch (action.action) {
      case 'contact_support':
        if (action.url) {
          await shell.openExternal(action.url);
        } else {
          await shell.openExternal('mailto:support@usb-video-vault.com?subject=Support licence USB Video Vault');
        }
        break;

      case 'check_license':
        // Ouvrir l'outil de vérification de licence
        try {
          spawn('node', ['tools/verify-license.mjs', '--verbose'], {
            detached: true,
            stdio: 'ignore'
          });
        } catch (error) {
          console.error('❌ Erreur ouverture vérificateur licence:', error);

          // Fallback : montrer les infos dans une boîte de dialogue
          await dialog.showMessageBox({
            type: 'info',
            title: 'Informations Licence',
            message: `Licence expire dans ${alert.daysRemaining} jours`,
            detail: 'Utilisez l\'outil "Vérifier Licence" depuis le menu Démarrer pour plus de détails.'
          });
        }
        break;

      case 'backup_data':
        await dialog.showMessageBox({
          type: 'info',
          title: 'Sauvegarde des Données',
          message: 'Sauvegarde Recommandée',
          detail: 'Il est recommandé de sauvegarder vos données importantes depuis votre périphérique USB vers un autre support sécurisé.\n\nVos fichiers média sont dans le dossier principal de votre périphérique USB.'
        });
        break;

      case 'remind_later':
        // Programmer un rappel (implémentation simple)
        const remindDelay = alert.severity === 'critical' ? 24 * 60 * 60 * 1000 : 7 * 24 * 60 * 60 * 1000;
        this.lastAlertShown = Date.now() - this.reminderInterval + remindDelay;
        console.log(`📅 Rappel programmé dans ${remindDelay / (1000 * 60 * 60)} heures`);
        break;

      case 'dismiss':
        // Marquer comme ignoré pour cette session
        this.lastAlertShown = Date.now();
        console.log('🔕 Alertes d\'expiration désactivées pour cette session');
        break;
    }
  }

  // Obtenir le type de dialogue approprié
  private getDialogType(severity: ExpirationAlert['severity']): 'error' | 'warning' | 'info' {
    switch (severity) {
      case 'expired':
      case 'critical':
        return 'error';
      case 'warning':
        return 'warning';
      default:
        return 'info';
    }
  }

  // Obtenir informations additionnelles
  private getAdditionalInfo(alert: ExpirationAlert): string {
    const baseInfo = `Expire dans: ${alert.daysRemaining} jour(s)`;

    switch (alert.severity) {
      case 'expired':
        return `${baseInfo}\n\n⚠️ L'application ne peut plus fonctionner avec une licence expirée.`;

      case 'critical':
        return `${baseInfo}\n\n🚨 Action urgente requise pour éviter l'interruption du service.`;

      case 'warning':
        return `${baseInfo}\n\n💡 Commencez le processus de renouvellement maintenant.`;

      case 'info':
        return `${baseInfo}\n\n📋 Information pour planification future.`;

      default:
        return baseInfo;
    }
  }

  // Forcer l'affichage d'une alerte de test
  async showTestAlert(daysRemaining: number = 15): Promise<void> {
    const testAlert: ExpirationAlert = {
      daysRemaining,
      severity: daysRemaining <= 7 ? 'critical' : daysRemaining <= 30 ? 'warning' : 'info',
      title: '🧪 Test Alerte Expiration',
      message: `Test du système d'alerte : votre licence expire dans ${daysRemaining} jours.`,
      actions: [
        {
          label: 'Test Contact Support',
          action: 'contact_support'
        },
        {
          label: 'Test Vérification',
          action: 'check_license'
        },
        {
          label: 'Fermer Test',
          action: 'dismiss'
        }
      ]
    };

    await this.showExpirationAlert(testAlert);
  }

  // Réinitialiser les alertes (pour les tests)
  resetAlerts(): void {
    this.lastAlertShown = 0;
  }

  // Obtenir le statut des alertes
  getAlertStatus(): {
    lastAlertShown: string;
    reminderInterval: number;
    canShowAlert: boolean;
  } {
    return {
      lastAlertShown: new Date(this.lastAlertShown).toISOString(),
      reminderInterval: this.reminderInterval,
      canShowAlert: Date.now() - this.lastAlertShown > this.reminderInterval
    };
  }
}

// Export pour intégration avec le système de licence principal
export default LicenseExpirationManager;
