import type { Page } from '@playwright/test';

/** Test helpers: talk to the game through the canvas and the debug `window.game` handle. */

export interface ProfileSeed {
  stars?: Record<string, number>;
  save?: unknown;
}

/** Starts the game with a given profile, with sound off, and collects page errors. */
export async function openGame(page: Page, seed: ProfileSeed = {}): Promise<string[]> {
  const errors: string[] = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.addInitScript((s) => {
    if (sessionStorage.getItem('seeded')) return; // keep progress across reloads
    sessionStorage.setItem('seeded', '1');
    localStorage.setItem('tower-defense-profile', JSON.stringify({
      v: 1, stars: s.stars ?? {}, perks: {}, endlessBest: 0, sfx: false, music: false, save: s.save ?? null,
    }));
  }, seed);
  await page.goto('/');
  await waitForScene(page, 'menu');
  return errors;
}

export async function waitForScene(page: Page, key: string): Promise<void> {
  await page.waitForFunction((k) => {
    const g = (window as any).game;
    return g?.scene?.isActive(k) && g.scene.getScene(k).children?.length > 0;
  }, key);
  await page.waitForTimeout(150); // let the first frame render
}

/** Clicks / taps at a point in the game's own 1000 x 600 coordinates. */
export async function press(page: Page, x: number, y: number, touch = false): Promise<void> {
  const box = await page.locator('canvas').boundingBox();
  if (!box) throw new Error('no canvas');
  const px = box.x + (x / 1000) * box.width, py = box.y + (y / 600) * box.height;
  if (touch) await page.touchscreen.tap(px, py);
  else await page.mouse.click(px, py);
}

/** Centre of a map tile in game coordinates. */
export const tile = (col: number, row: number) => [col * 40 + 20, row * 40 + 20] as const;

/** Reads a value from the running GameScene. */
export function game<T>(page: Page, fn: (scene: any) => T): Promise<T> {
  return page.evaluate(`(${fn.toString()})(window.game.scene.getScene('game'))`) as Promise<T>;
}

export function profile(page: Page): Promise<any> {
  return page.evaluate(() => JSON.parse(localStorage.getItem('tower-defense-profile') ?? 'null'));
}

// Button positions (game coordinates) used by several tests.
export const UI = {
  menuFirstButton: [500, 263] as const, // Play (or Continue when a save exists; menu is taller then)
  levelPlay: (i: number) => [45 + 145 + (i % 3) * 310, 96 + Math.floor(i / 3) * 256 + 209] as const,
  buildTile: (i: number) => [812 + 42 + (i % 2) * 92, 94 + 27 + Math.floor(i / 2) * 60] as const,
  upgrade: [900, 374] as const,
  target: [900, 411] as const,
  sell: [900, 445] as const,
  wave: [900, 519] as const,
};
