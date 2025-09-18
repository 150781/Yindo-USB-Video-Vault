import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  root: 'src/renderer',
  plugins: [react()],
  server: {
    port: 5176,
  },
  base: './', // Utilise des chemins relatifs pour l'application packagée
  build: {
    outDir: '../../dist/renderer',
    emptyOutDir: true,
    rollupOptions: {
      input: {
        index: resolve(__dirname, 'src/renderer/index.html'),
        display: resolve(__dirname, 'src/renderer/display.html'),
      },
    },
  },
});
