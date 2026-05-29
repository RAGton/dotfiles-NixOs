import { cpSync, existsSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

function copyInstallerImages() {
  return {
    name: 'copy-installer-images',
    closeBundle() {
      const sourceDir = path.resolve(__dirname, 'imgs');
      const filesToCopy = [
        'logoterminal.png',
        'ragton.png',
      ];
      const directoriesToCopy = [
        'calamares-timezones',
      ];
      const outDir = path.resolve(__dirname, 'static', 'imgs');
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
  },
  build: {
    outDir: 'static',
    emptyOutDir: true,
    sourcemap: false,
  },
});
