// @ts-nocheck
/* eslint-disable */
import { test, expect, _electron as electron } from '@playwright/test';
import { ElectronApplication, Page, ConsoleMessage } from 'playwright';
import path from 'path';

// Types pour window.electronAPI
declare global {
  interface Window {
    electronAPI: {
      getStats?: () => any;
      loadVideo?: (filename: string) => void;
    };
  }
}

test.describe('🔐 USB Video Vault - E2E Security Tests', () => {
  let electronApp: ElectronApplication;
  let mainWindow: Page;

  test.beforeAll(async () => {
    // Lancer l'app Electron
    electronApp = await electron.launch({
      args: [path.resolve(__dirname, '../dist/main/main.js')],
      env: {
        ...process.env,
        NODE_ENV: 'test',
        ELECTRON_ENABLE_LOGGING: '1'
      }
    });

    // Obtenir la fenêtre principale
    mainWindow = await electronApp.firstWindow();
    await mainWindow.waitForLoadState('domcontentloaded');
  });

  test.afterAll(async () => {
    await electronApp?.close();
  });

  // ================================
  // 🔒 Tests de Sécurité CSP
  // ================================
  test('🛡️ CSP strict - Prévention XSS', async () => {
    // Vérifier que CSP bloque les scripts inline
    const cspViolations: string[] = [];
    
    mainWindow.on('console', (msg: ConsoleMessage) => {
      if (msg.text().includes('Content Security Policy')) {
        cspViolations.push(msg.text());
      }
    });

    // Tenter d'injecter un script malveillant
    await mainWindow.evaluate(() => {
      try {
        const script = document.createElement('script');
        script.innerHTML = 'console.log("XSS injection test")';
        document.head.appendChild(script);
      } catch (e) {
        console.log('CSP blocked script injection:', e);
      }
    });

    await mainWindow.waitForTimeout(1000);
    
    // CSP doit bloquer l'injection
    expect(cspViolations.length).toBeGreaterThan(0);
  });

  test('🚫 Anti-Debug - Détection DevTools', async () => {
    let debugDetected = false;

    // Intercepter les messages de détection anti-debug
    mainWindow.on('console', (msg: ConsoleMessage) => {
      if (msg.text().includes('Debug detected') || msg.text().includes('DevTools')) {
        debugDetected = true;
      }
    });

    // Ouvrir DevTools (doit être détecté)
    await mainWindow.evaluate(() => {
      // Simuler l'ouverture de DevTools
      if (window.outerHeight - window.innerHeight > 100) {
        console.log('Debug detected - DevTools height change');
      }
    });

    await mainWindow.waitForTimeout(2000);
    
    // La détection anti-debug doit se déclencher
    expect(debugDetected).toBe(true);
  });

  // ================================
  // 🎬 Tests de Lecture Vidéo
  // ================================
  test('🎥 Lecture vidéo chiffrée - Intégrité', async () => {
    // Attendre que l'interface soit chargée
    await mainWindow.waitForSelector('[data-testid="video-player"]', { timeout: 10000 });

    // Sélectionner une vidéo chiffrée
    const videoList = await mainWindow.locator('[data-testid="video-list"] .video-item');
    await videoList.first().click();

    // Vérifier que la vidéo se charge
    const videoElement = mainWindow.locator('video');
    await expect(videoElement).toBeVisible({ timeout: 15000 });

    // Vérifier que les méta-données sont décryptées
    const videoTitle = await mainWindow.locator('[data-testid="video-title"]').textContent();
    expect(videoTitle).toBeTruthy();
    expect(videoTitle).not.toContain('.enc');

    // Vérifier que la lecture fonctionne (durée > 0)
    const duration = await videoElement.evaluate((el: HTMLVideoElement) => el.duration);
    expect(duration).toBeGreaterThan(0);
  });

  test('🔐 Protection du contenu - ContentProtection', async () => {
    // Charger une vidéo
    await mainWindow.waitForSelector('[data-testid="video-player"]');
    const videoList = await mainWindow.locator('[data-testid="video-list"] .video-item');
    await videoList.first().click();

    const videoElement = mainWindow.locator('video');
    await expect(videoElement).toBeVisible();

    // Vérifier que les attributs de protection sont activés
    const protectionAttributes = await videoElement.evaluate((el: HTMLVideoElement) => ({
      controlsList: (el as any).controlsList?.value || '',
      disablePictureInPicture: el.disablePictureInPicture,
      disableRemotePlaycast: (el as any).disableRemotePlaycast
    }));

    expect(protectionAttributes.controlsList).toContain('nodownload');
    expect(protectionAttributes.disablePictureInPicture).toBe(true);
    expect(protectionAttributes.disableRemotePlaycast).toBe(true);
  });

  // ================================
  // 🪟 Tests Multi-Fenêtres
  // ================================
  test('🪟 Sécurité multi-fenêtres - Isolation', async () => {
    // Ouvrir une seconde fenêtre
    await mainWindow.evaluate(() => {
      window.open('', '_blank', 'width=800,height=600');
    });

    const allWindows = electronApp.windows();
    await expect(allWindows).toHaveLength(2);

    const secondWindow = allWindows[1];
    await secondWindow.waitForLoadState();

    // Vérifier que la seconde fenêtre a les mêmes protections CSP
    const cspHeader = await secondWindow.evaluate(() => {
      const metaCsp = document.querySelector('meta[http-equiv="Content-Security-Policy"]');
      return metaCsp?.getAttribute('content') || '';
    });

    expect(cspHeader).toContain("default-src 'self'");
    expect(cspHeader).toContain("script-src 'self'");

    // Vérifier l'isolation entre fenêtres
    const crossWindowAccess = await mainWindow.evaluate(() => {
      try {
        // Tenter d'accéder à la seconde fenêtre
        const windows = Array.from(window.frames);
        return windows.length;
      } catch (e) {
        return -1; // Accès bloqué
      }
    });

    // L'accès cross-window doit être limité
    expect(crossWindowAccess).toBeLessThanOrEqual(0);
  });

  // ================================
  // 📊 Tests de Gestion des Stats
  // ================================
  test('📈 Stats Manager - Tracking sécurisé', async () => {
    // Charger une vidéo et la lire
    await mainWindow.waitForSelector('[data-testid="video-player"]');
    const videoList = await mainWindow.locator('[data-testid="video-list"] .video-item');
    await videoList.first().click();

    const videoElement = mainWindow.locator('video');
    await expect(videoElement).toBeVisible();

    // Démarrer la lecture
    await videoElement.evaluate((el: HTMLVideoElement) => el.play());
    await mainWindow.waitForTimeout(3000);

    // Vérifier que les stats sont trackées
    const statsData = await mainWindow.evaluate(() => {
      // Accéder au StatsManager via l'API sécurisée
      return window.electronAPI?.getStats?.();
    });

    expect(statsData).toBeTruthy();
    expect(statsData.playCount).toBeGreaterThan(0);
    expect(statsData.totalWatchTime).toBeGreaterThan(0);

    // Vérifier que les stats ne contiennent pas d'infos sensibles
    const statsString = JSON.stringify(statsData);
    expect(statsString).not.toContain('password');
    expect(statsString).not.toContain('key');
    expect(statsString).not.toContain('.enc');
  });

  // ================================
  // 🚨 Tests de Scenarios d'Échec
  // ================================
  test('🚨 Gestion d\'erreurs - Fichier corrompu', async () => {
    // Simuler un fichier .enc corrompu
    const errorMessages: string[] = [];
    
    mainWindow.on('console', (msg: ConsoleMessage) => {
      if (msg.type() === 'error') {
        errorMessages.push(msg.text());
      }
    });

    // Tenter de charger un fichier inexistant/corrompu
    await mainWindow.evaluate(() => {
      // Déclencher une erreur de déchiffrement
      window.electronAPI?.loadVideo?.('fake-corrupted-file.enc');
    });

    await mainWindow.waitForTimeout(2000);

    // Vérifier qu'une erreur appropriée est affichée
    const errorDialog = mainWindow.locator('[data-testid="error-dialog"]');
    await expect(errorDialog).toBeVisible({ timeout: 5000 });

    const errorText = await errorDialog.textContent();
    expect(errorText).toMatch(/chiffrement|corruption|authentification/i);

    // Vérifier qu'aucune information sensible n'est exposée
    expect(errorText).not.toContain('key');
    expect(errorText).not.toContain('password');
  });

  test('⏰ Gestion licence expirée', async () => {
    // Simuler une licence expirée
    await mainWindow.evaluate(() => {
      // Forcer l'expiration de licence
      const expiredDate = new Date('2020-01-01').toISOString();
      localStorage.setItem('license-expiry', expiredDate);
    });

    // Recharger l'app
    await mainWindow.reload();
    await mainWindow.waitForLoadState();

    // Vérifier que l'erreur de licence est affichée
    const licenseError = mainWindow.locator('[data-testid="license-error"]');
    await expect(licenseError).toBeVisible({ timeout: 10000 });

    const errorText = await licenseError.textContent();
    expect(errorText).toMatch(/licence.*expir|expired/i);

    // Vérifier que les fonctionnalités sont désactivées
    const videoPlayer = mainWindow.locator('[data-testid="video-player"]');
    await expect(videoPlayer).not.toBeVisible();
  });

  // ================================
  // 🎯 Tests de Performance
  // ================================
  test('⚡ Performance - Temps de démarrage', async () => {
    const startTime = Date.now();
    
    // Mesurer le temps jusqu'à l'interface chargée
    await mainWindow.waitForSelector('[data-testid="app-ready"]', { timeout: 10000 });
    
    const loadTime = Date.now() - startTime;
    
    // L'app doit charger en moins de 5 secondes
    expect(loadTime).toBeLessThan(5000);
    
    console.log(`⚡ Temps de démarrage: ${loadTime}ms`);
  });

  test('🎬 Performance - Latence déchiffrement', async () => {
    await mainWindow.waitForSelector('[data-testid="video-player"]');
    
    const videoList = await mainWindow.locator('[data-testid="video-list"] .video-item');
    
    const startTime = Date.now();
    await videoList.first().click();
    
    // Attendre que la vidéo soit prête
    const videoElement = mainWindow.locator('video');
    await expect(videoElement).toBeVisible();
    
    await videoElement.evaluate((el: HTMLVideoElement) => {
      return new Promise<void>((resolve) => {
        if (el.readyState >= 3) { // HAVE_FUTURE_DATA
          resolve();
        } else {
          el.addEventListener('canplay', () => resolve(), { once: true });
        }
      });
    });
    
    const decryptTime = Date.now() - startTime;
    
    // Le déchiffrement doit prendre moins de 2 secondes
    expect(decryptTime).toBeLessThan(2000);
    
    console.log(`🔐 Latence déchiffrement: ${decryptTime}ms`);
  });
});