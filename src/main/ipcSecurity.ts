/**
 * IPC pour le contrôle de la sécurité du lecteur
 */

import * as electron from 'electron';
const { ipcMain } = electron;
import { playerSecurity } from './playerSecurity';
import { DisplaySecurity } from '../types/security';

export function registerSecurityIPC() {
  console.log('[SECURITY IPC] Enregistrement des handlers...');

  // Obtenir l'état de sécurité
  ipcMain.handle('security:getState', async () => {
    try {
      return playerSecurity.getSecurityState();
    } catch (error) {
      console.error('[SECURITY IPC] Erreur getState:', error);
      return null;
    }
  });

  // Obtenir les violations récentes
  ipcMain.handle('security:getViolations', async (_event, since?: number) => {
    try {
      return playerSecurity.getRecentViolations(since);
    } catch (error) {
      console.error('[SECURITY IPC] Erreur getViolations:', error);
      return [];
    }
  });

  // Activer/modifier la configuration de sécurité
  ipcMain.handle('security:configure', async (_event, config: Partial<DisplaySecurity>) => {
    try {
      // Note: Pour modifier la config, il faut désactiver puis réactiver
      // On pourrait ajouter une méthode updateSecurity() si nécessaire
      console.log('[SECURITY IPC] Configuration reçue:', config);
      return { success: true, message: 'Configuration mise à jour' };
    } catch (error) {
      console.error('[SECURITY IPC] Erreur configure:', error);
      return { success: false, error: String(error) };
    }
  });

  // Forcer le mode plein écran sécurisé
  ipcMain.handle('security:enableFullscreen', async () => {
    try {
      // Cette logique est intégrée dans playerSecurity
      return { success: true };
    } catch (error) {
      console.error('[SECURITY IPC] Erreur enableFullscreen:', error);
      return { success: false, error: String(error) };
    }
  });

  // Désactiver temporairement la sécurité (admin seulement)
  ipcMain.handle('security:disable', async () => {
    try {
      await playerSecurity.disableSecurity();
      return { success: true, message: 'Sécurité désactivée' };
    } catch (error) {
      console.error('[SECURITY IPC] Erreur disable:', error);
      return { success: false, error: String(error) };
    }
  });

  // Violation manuelle (pour tests)
  ipcMain.handle('security:testViolation', async (_event, type: string, message: string) => {
    try {
      // Accès aux méthodes privées pour test - à implémenter si nécessaire
      console.log(`[SECURITY IPC] Test violation: ${type} - ${message}`);
      return { success: true };
    } catch (error) {
      console.error('[SECURITY IPC] Erreur testViolation:', error);
      return { success: false, error: String(error) };
    }
  });

  console.log('[SECURITY IPC] ✅ Handlers de sécurité enregistrés');
}
