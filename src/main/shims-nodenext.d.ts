// src/main/shims-nodenext.d.ts
// Aide TypeScript à résoudre les imports ESM avec extension .js vers les sources .ts pendant le typage
declare module './windows.js' {
  export * from './windows';
}
declare module './ipc.js' {
  export * from './ipc';
}
declare module './protocol.js' {
  export * from './protocol';
}
