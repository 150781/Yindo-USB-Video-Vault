import { getLicenseStatus, getRules } from './license.js';

export async function authorizeAndCount(mediaId: string): Promise<{ok:boolean; error?:string}> {
  const lic = getLicenseStatus();
  if (!lic.ok) return { ok:false, error: lic.error || 'Licence non chargée' };

  const r = getRules() || {};
  const now = Date.now();

  if (r.validFrom && Date.parse(r.validFrom) > now) return { ok:false, error: 'Licence pas encore valide' };
  const until = r.validUntil || lic.info?.expiryUtc;
  if (until && Date.parse(until) < now) return { ok:false, error: 'Licence expirée' };

  // Note: Les quotas basés sur les stats sont désormais optionnels car les stats 
  // sont maintenant chiffrées et gérées via le StatsManager
  
  return { ok:true };
}
