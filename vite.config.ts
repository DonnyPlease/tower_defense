import { defineConfig } from 'vitest/config';

export default defineConfig({
  // Relative asset paths, so the build works from any sub-folder
  // (GitHub Pages, itch.io, or a Capacitor mobile app).
  base: './',
  build: {
    chunkSizeWarningLimit: 2000, // Phaser itself is ~1.5 MB
  },
  test: {
    include: ['tests/**/*.test.ts'],
    coverage: {
      provider: 'v8',
      include: ['src/**/*.ts'],
      // Phaser scenes, widgets and rendering need a real browser; they are
      // covered by the Playwright smoke test in e2e/ instead.
      exclude: ['src/main.ts', 'src/scenes/**', 'src/view/**', 'src/ui/{Button,Hud,Overlay,minimap,theme}.ts'],
      reporter: ['text', 'json-summary', 'html'],
      thresholds: { lines: 97, statements: 97, functions: 97, branches: 92 },
    },
  },
});
