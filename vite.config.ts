import { defineConfig } from 'vite';

export default defineConfig({
  // Relative asset paths, so the build works from any sub-folder
  // (GitHub Pages, itch.io, or a Capacitor mobile app).
  base: './',
  build: {
    chunkSizeWarningLimit: 2000, // Phaser itself is ~1.5 MB
  },
});
