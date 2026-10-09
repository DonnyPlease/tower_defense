import { test, expect } from '@playwright/test';
import { AT, COLORS, Game } from './game.mjs';

// Plays the exported web build in a real browser (desktop: mouse; phone: touch).
// The "release" project plays the tests tagged @release on the release export.
// Only what a person sees is checked: pixels of the canvas.

let game;

test.beforeEach(async ({ page }, info) => {
  game = new Game(page, { touch: info.project.name === 'phone' });
});

test('starts at the title screen without any browser errors @release', async () => {
  await game.open();
  // The demo game fills the window behind the menu: no black bars anywhere.
  const l = game.layout();
  for (const c of await game.colors([2, 2], [l.viewW - 3, l.viewH - 3])) expect(c).not.toBe('#000000');
  game.expectNoProblems();
});

test('plays the first level: build a tower, start a wave @release', async () => {
  await game.open();
  await game.startMeadow();
  await game.waitForColor(game.rail('background'), COLORS.panel, { what: 'the rail' });
  await game.buildGun(6, 9);

  // The wave button is blue until a wave is running, then it dims.
  await game.waitForColor(game.rail('waveButtonColor'), COLORS.accent, { what: 'the Start wave button' });
  await game.click(game.rail('waveButton'));
  await game.waitForColor(game.rail('waveButtonColor'), COLORS.accent, { not: true, tolerance: 20, what: 'the Start wave button (wave running)' });

  await game.page.waitForTimeout(4000); // let the enemies walk and the tower shoot
  game.expectNoProblems();
});

test('a saved game survives reloading the page @release', async ({ page }) => {
  await game.open();
  await game.startMeadow();
  await game.buildGun(6, 9); // building saves the game
  await page.waitForTimeout(1500); // the browser writes its storage in the background

  await page.reload();
  await game.waitForMenu({ saved: true }); // "Continue" is offered
  await game.click(game.centred(AT.menuContinue));
  await game.waitForColor(game.tile(0, 0), COLORS.grassAlt, { tolerance: 8, what: 'the continued game' });
  await game.waitForColor(game.tile(6, 9), COLORS.grass, { not: true, tolerance: 20, what: 'the saved tower' });
  game.expectNoProblems();
});

test('a wall can be built on the road and an ability used @release', async () => {
  await game.open();
  await game.startMeadow();
  const road = game.tile(5, 11);
  await game.waitForColor(road, COLORS.path, { tolerance: 20, what: 'free road' });
  await game.click(game.rail('wall')); // the wall tool
  await game.click(road);
  // The wall is stone, not road (the pointer's preview is gone once the tool is put away).
  await game.page.keyboard.press('Escape');
  await game.waitForColor([road[0], road[1] - 12], COLORS.stone, { tolerance: 25, what: 'a wall on the road' });

  const frame = game.field(400, 1.5); // the strip along the field's top edge where a running ability draws its frame
  const [r0, , b0] = await game.channels(frame);
  await game.click(game.rail('abilities')); // the abilities drop down
  await game.page.waitForTimeout(400);
  await game.click(game.rail('slow')); // time slow
  await expect
    .poll(async () => {
      const [r, , b] = await game.channels(frame);
      return b - r - (b0 - r0);
    }, { message: 'the blue frame of time slow', timeout: 15_000 })
    .toBeGreaterThan(40);
  game.expectNoProblems();
});

test('the music setting is remembered after a reload', async ({ page }) => {
  await game.open();
  // Music starts on: its button has a gold outline.
  await game.waitForColor(game.centred(AT.menuMusicBorder), COLORS.gold, { tolerance: 40, what: 'the music button (on)' });
  await game.click(game.centred(AT.menuMusic));
  await game.waitForColor(game.centred(AT.menuMusicBorder), COLORS.border, { tolerance: 40, what: 'the music button (off)' });
  await page.waitForTimeout(1500);

  await page.reload();
  await game.waitForMenu();
  await game.waitForColor(game.centred(AT.menuMusicBorder), COLORS.border, { tolerance: 40, what: 'the music button after reload' });
  game.expectNoProblems();
});

test.describe('desktop window', () => {
  test.beforeEach(({}, info) => test.skip(info.project.name !== 'desktop', 'desktop only'));

  test('follows the window size and keeps working', async ({ page }) => {
    await game.open();
    await page.setViewportSize({ width: 700, height: 500 }); // narrower: the view grows taller, the menu stays centred
    await game.waitForColor(game.centred(AT.menuPlayColor), COLORS.accent, { what: 'the Play button after resizing' });
    await game.click(game.centred(AT.menuPlay));
    await game.waitForColor(game.centred(AT.levelMeadowPlayColor), COLORS.accent, { what: 'the level select screen' });
    game.expectNoProblems();
  });
});

test.describe('phone', () => {
  test.beforeEach(({}, info) => test.skip(info.project.name !== 'phone', 'phone only'));

  test('fills the screen and plays by touch', async ({ page }) => {
    await game.open();
    const l = game.layout();
    expect(l.scale).toBeCloseTo(0.65, 2);
    const [left, right] = await game.colors([2, 300], [l.viewW - 3, 300]);
    expect(left).not.toBe('#000000'); // no black bars: the demo game reaches the edges
    expect(right).not.toBe('#000000');

    await page.touchscreen.tap(10, 195); // beside the menu, level with the Play button
    await page.waitForTimeout(1000);
    await game.waitForColor(game.centred(AT.menuPlayColor), COLORS.accent, { what: 'the title screen (still)' });

    await game.startMeadow(); // taps on the buttons themselves work
    await game.buildGun(6, 9);
    game.expectNoProblems();
  });
});

test('can be installed as an app: manifest, icons and offline support @release', async ({ page }) => {
  const manifest = await (await page.request.get('/index.manifest.json')).json();
  expect(manifest.name).toBe('Tower Defense');
  expect(manifest.orientation).toBe('landscape'); // the field plays sideways
  expect(manifest.icons.length).toBeGreaterThan(0);
  for (const icon of manifest.icons) {
    expect((await page.request.get('/' + icon.src)).ok(), icon.src).toBeTruthy();
  }
  expect((await page.request.get('/index.service.worker.js')).ok()).toBeTruthy();
  expect((await page.request.get('/index.offline.html')).ok()).toBeTruthy();
  await game.open();
  // The page registers the service worker that makes it work offline.
  await expect.poll(() => page.evaluate(async () => (await navigator.serviceWorker.getRegistrations()).length), {
    timeout: 20_000,
  }).toBeGreaterThan(0);
  game.expectNoProblems();
});
