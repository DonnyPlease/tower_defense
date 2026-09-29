import { defineConfig, devices } from '@playwright/test';

// Browser smoke tests: they run the built game (npm run build first) and
// click through the real Phaser screens.
export default defineConfig({
  testDir: 'e2e',
  timeout: 60_000,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['github'], ['list']] : 'list',
  use: {
    baseURL: 'http://localhost:4173',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1000, height: 600 } }, grepInvert: /@touch/ },
    { name: 'phone', use: { ...devices['Pixel 7'], viewport: { width: 844, height: 390 } }, grep: /@touch/ },
  ],
  webServer: {
    command: 'npx vite preview --port 4173 --strictPort',
    url: 'http://localhost:4173',
    reuseExistingServer: !process.env.CI,
  },
});
