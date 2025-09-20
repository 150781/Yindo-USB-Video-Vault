// src/main/safe-console.ts
import log from 'electron-log';

try {
  log.initialize({ preload: true });
} catch {}

try {
  // Ignore "broken pipe" on stdout/stderr
  // @ts-ignore
  process.stdout?.on?.('error', (e: any) => { if (e?.code === 'EPIPE') {/* ignore */} });
  // @ts-ignore
  process.stderr?.on?.('error', (e: any) => { if (e?.code === 'EPIPE') {/* ignore */} });
} catch {}

const toFile = (fn: (...a: any[]) => void) => (...a: any[]) => {
  try { fn(...a); } catch { /* swallow */ }
};

console.log   = toFile((...a) => log.info(...a));
console.info  = toFile((...a) => log.info(...a));
console.warn  = toFile((...a) => log.warn(...a));
console.error = toFile((...a) => log.error(...a));