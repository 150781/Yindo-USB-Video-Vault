// Shared activity management

let lastActivity = Date.now();

export function touchActivity() {
  const now = Date.now();
  lastActivity = now;
  console.log(`[activity] Activité mise à jour: ${new Date(now).toLocaleTimeString()}`);
}

export function getLastActivity() {
  return lastActivity;
}

export function getIdleTime() {
  return Date.now() - lastActivity;
}
