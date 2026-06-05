import { cpSync, existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

function copyInstallerImages() {
  let buildOutDir = 'dist';
  return {
    name: 'copy-installer-images',
    configResolved(config) {
      buildOutDir = config.build.outDir || 'dist';
    },
    closeBundle() {
      const sourceDir = path.resolve(__dirname, 'imgs');
      const filesToCopy = [
        'logoterminal.png',
        'ragton.png',
      ];
      const directoriesToCopy = [
        'calamares-timezones',
      ];
      const outDir = path.resolve(__dirname, buildOutDir, 'imgs');
      mkdirSync(outDir, { recursive: true });

      for (const relativeFile of filesToCopy) {
        const sourceFile = path.resolve(sourceDir, relativeFile);
        if (!existsSync(sourceFile)) {
          continue;
        }
        cpSync(sourceFile, path.resolve(outDir, relativeFile));
      }

      for (const relativeDir of directoriesToCopy) {
        const sourcePath = path.resolve(sourceDir, relativeDir);
        if (!existsSync(sourcePath)) {
          continue;
        }
        cpSync(sourcePath, path.resolve(outDir, relativeDir), { recursive: true });
      }
    },
  };
}

export default defineConfig({
  plugins: [react(), copyInstallerImages()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/health':   'http://127.0.0.1:8080',
      '/probe':    'http://127.0.0.1:8080',
      '/plan':     'http://127.0.0.1:8080',
      '/dry-run':  'http://127.0.0.1:8080',
      '/install':  'http://127.0.0.1:8080',
      '/api':      'http://127.0.0.1:8080',
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
    sourcemap: false,
  },
});
