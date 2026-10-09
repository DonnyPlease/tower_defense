import { defineConfig } from '@playwright/test';

// A browser without a GPU draws WebGL in software.
const SOFTWARE_GL = ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];
const DEBUG_PORT = 8060; // build/web-debug: shows script errors in the console
const RELEASE_PORT = 8061; // build/web: what players get

export default defineConfig({
  testDir: '.',
  testMatch: '*.spec.mjs',
  timeout: 120_000,
  workers: 1, // one page at a time: software rendering is slow, and timings matter
  retries: 0, // a flaky test is a bug, not something to run again
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    launchOptions: { args: SOFTWARE_GL },
    deviceScaleFactor: 1,
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  // The two web exports (tests/run.sh web builds them).
  webServer: [DEBUG_PORT, RELEASE_PORT].map((port) => ({
    command: `python3 -m http.server ${port} --directory ../../build/${port === DEBUG_PORT ? 'web-debug' : 'web'}`,
    url: `http://127.0.0.1:${port}/index.html`,
    reuseExistingServer: !process.env.CI,
  })),
  projects: [
    // Everything, on the debug build.
    { name: 'desktop', use: { baseURL: `http://127.0.0.1:${DEBUG_PORT}`, viewport: { width: 1000, height: 600 } } },
    // A phone held sideways: the game fills it and is played by touch.
    {
      name: 'phone',
      use: { baseURL: `http://127.0.0.1:${DEBUG_PORT}`, viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true },
    },
    // The build players get (script errors are not printed there, so only the main flow is played).
    { name: 'release', grep: /@release/, use: { baseURL: `http://127.0.0.1:${RELEASE_PORT}`, viewport: { width: 1000, height: 600 } } },
  ],
});
