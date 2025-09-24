import * as electron from 'electron';
import type { Session } from 'electron';
const { session } = electron;
import type { VaultManager } from './vault';

export async function registerVaultProtocol(electronSession: Session, vault: VaultManager) {
  const proto = electronSession.protocol;

  // On préfère registerFileProtocol : Chrome gère Range/seek nativement sur fichiers
  proto.registerFileProtocol('vault', async (req, cb) => {
    try {
      const url = new URL(req.url);
      const parts = url.pathname.split('/').filter(Boolean); // ex: /media/<id>
      if (parts.length === 2 && parts[0] === 'media') {
        if (!vault.isUnlocked()) {
          return cb({ statusCode: 401, data: Buffer.from('Vault locked'), headers: { 'Content-Type': 'text/plain' } });
        }
        const id = decodeURIComponent(parts[1]);
        const filePath = await vault.ensureDecryptedFile(id);
        const contentType = vault.getMimeById(id);

        cb({
          path: filePath, headers: {
            'Content-Type': contentType,
            'Cache-Control': 'no-store, no-cache, must-revalidate',
            'Pragma': 'no-cache'
          }
        });
        return;
      }

      // Optionnel: GET /ping
      if (parts.length === 1 && parts[0] === 'ping') {
        return cb({ data: Buffer.from('ok'), headers: { 'Content-Type': 'text/plain' } });
      }

      cb({ statusCode: 404, data: Buffer.from('Not found') });
    } catch (e: any) {
      cb({ statusCode: 500, data: Buffer.from('Internal error: ' + (e?.message || e)) });
    }
  });
}
