import { test, expect } from '@playwright/test';
import { openGame, waitForScene, press, tile, game, profile, UI } from './game';

const ALL_STARS = { meadow: 3, riverside: 3, highlands: 3 };

test('menu → level select → build, upgrade, sell, play a wave', async ({ page }) => {
  const errors = await openGame(page);
  await press(page, ...UI.menuFirstButton);
  await waitForScene(page, 'levels');
  await press(page, ...UI.levelPlay(0));
  await waitForScene(page, 'game');

  // Build a missile tower with the sidebar and a click on the grass.
  await press(page, ...UI.buildTile(1));
  await press(page, ...tile(6, 9));
  expect(await game(page, (s) => s.world.towers.map((t: any) => t.kind))).toEqual(['missile']);

  // Select it, upgrade it, change its target, then build a second one and sell it.
  await press(page, ...tile(6, 9));
  expect(await game(page, (s) => s.selected?.kind)).toBe('missile');
  await press(page, ...UI.upgrade);
  await press(page, ...UI.target);
  expect(await game(page, (s) => [s.selected.level, s.selected.targetMode])).toEqual([1, 'last']);
  await page.keyboard.press('2');
  await press(page, ...tile(13, 7));
  await press(page, ...tile(13, 7));
  await press(page, ...UI.sell);
  expect(await game(page, (s) => s.world.towers.length)).toBe(1);

  // Start the wave and let the tower shoot something.
  await press(page, ...UI.wave);
  await page.waitForFunction(() => (window as any).game.scene.getScene('game').world.kills > 0, null, { timeout: 30_000 });
  expect(errors).toEqual([]);
});

test('pausing, leaving and continuing a saved game', async ({ page }) => {
  const errors = await openGame(page);
  await page.evaluate(() => (window as any).game.scene.getScene('menu').scene.start('game', { levelId: 'meadow' }));
  await waitForScene(page, 'game');
  await page.keyboard.press('1');
  await press(page, ...tile(3, 9));
  await page.keyboard.press('Escape'); // cancel build tool
  await page.keyboard.press('Escape'); // pause
  expect(await game(page, (s) => s.paused)).toBe(true);
  await press(page, 500, 600 / 2 - (160 + 240) / 2 + 144 + 3 * 60 + 24); // Main menu
  await waitForScene(page, 'menu');
  expect((await profile(page)).save.towers).toHaveLength(1);

  await page.reload();
  await waitForScene(page, 'menu');
  await press(page, 500, 90 + 118 + 25); // Continue (menu is taller with a save)
  await waitForScene(page, 'game');
  expect(await game(page, (s) => s.world.towers.map((t: any) => `${t.kind}@${t.col},${t.row}`))).toEqual(['gun@3,9']);
  expect(errors).toEqual([]);
});

test('winning a level awards stars and unlocks towers', async ({ page }) => {
  const errors = await openGame(page);
  await page.evaluate(() => (window as any).game.scene.getScene('menu').scene.start('game', { levelId: 'meadow' }));
  await waitForScene(page, 'game');
  await game(page, (s) => {
    const w = s.world;
    w.money = 1e6;
    w.waveIndex = w.totalWaves - 2;
    for (const [c, r] of [[6, 9], [9, 9], [13, 8], [12, 11], [14, 5], [9, 7], [16, 5], [17, 8], [13, 10], [10, 13]]) {
      const t = w.build(c % 2 ? 'missile' : 'gun', c, r);
      if (t) { w.upgrade(t); w.upgrade(t); }
    }
    w.startNextWave();
    s.speed = 3;
  });
  await page.waitForFunction(() => (window as any).game.scene.getScene('game').world.status !== 'playing', null, { timeout: 50_000 });
  const p = await profile(page);
  expect(await game(page, (s) => s.world.status)).toBe('won');
  expect(p.stars.meadow).toBeGreaterThanOrEqual(1);
  expect(p.save).toBeNull();
  expect(errors).toEqual([]);
});

for (const levelId of ['meadow', 'riverside', 'highlands', 'openfield', 'endless']) {
  test(`${levelId} runs a busy wave without errors`, async ({ page }) => {
    const errors = await openGame(page, { stars: ALL_STARS });
    await page.evaluate((id) => (window as any).game.scene.getScene('menu').scene.start('game', { levelId: id }), levelId);
    await waitForScene(page, 'game');
    await game(page, (s) => {
      const w = s.world;
      w.money = 1e6;
      w.lives = 1e6;
      let n = 0;
      const kinds = ['gun', 'missile', 'cannon', 'frost', 'laser', 'support'];
      for (let r = 0; r < 15 && n < 14; r++) for (let c = 2; c < 18 && n < 14; c += 3) {
        const t = w.build(kinds[n % kinds.length], c, r);
        if (t) { n++; if (n % 2) w.upgrade(t); }
      }
      for (const type of ['boss', 'splitter', 'healer', 'drone', 'shielded', 'armored']) w.spawn(type);
      w.startNextWave();
      s.speed = 3;
    });
    await page.waitForTimeout(4000);
    const state = await game(page, (s) => ({ tick: s.world.tick, kills: s.world.kills, towers: s.world.towers.length }));
    expect(state.tick).toBeGreaterThan(100);
    expect(state.towers).toBeGreaterThan(5);
    expect(errors).toEqual([]);
  });
}

test('upgrades screen buys a perk with stars', async ({ page }) => {
  const errors = await openGame(page, { stars: { meadow: 3 } });
  await press(page, 500, 120 + 118 + 60 + 25); // Upgrades
  await waitForScene(page, 'upgrades');
  await press(page, 538, 100 + 32); // Buy War Chest
  expect((await profile(page)).perks.capital).toBe(1);
  expect(errors).toEqual([]);
});

test('touch controls work on a phone @touch', async ({ page }) => {
  const errors = await openGame(page);
  await press(page, ...UI.menuFirstButton, true);
  await waitForScene(page, 'levels');
  await press(page, ...UI.levelPlay(0), true);
  await waitForScene(page, 'game');
  await press(page, ...UI.buildTile(1), true);
  await press(page, ...tile(6, 9), true);
  await press(page, ...tile(6, 9), true);
  await press(page, ...UI.upgrade, true);
  await press(page, ...UI.wave, true);
  expect(await game(page, (s) => [s.world.towers[0]?.level, s.world.waveIndex])).toEqual([1, 0]);
  expect(errors).toEqual([]);
});
