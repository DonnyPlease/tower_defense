import { PNG } from 'pngjs';
import { expect } from '@playwright/test';

// Colours of src/ui/palette.gd.
export const COLORS = {
  grass: '#5d8f3b',
  grassAlt: '#659a41',
  panel: '#1e2230',
  accent: '#4f8ef7',
  panelLight: '#2a3042',
  border: '#454f6b',
  gold: '#f5c542',
  path: '#dcc594',
  stone: '#8d939c',
};

// Where things are, in game coordinates (the game is 1000 x 600).
export const AT = {
  menuPlay: [500, 263], // click the Play button here (centre)
  menuPlayColor: [400, 250], // a point of it without text, when there is no saved game
  menuContinue: [500, 233], // click the Continue button here (only with a saved game)
  menuContinueColor: [400, 225],
  menuMusicBorder: [370, 384], // left edge of the music button
  levelMeadowPlay: [190, 305], // click here
  levelMeadowPlayColor: [100, 305], // the same button, without text
  towerGun: [854, 121],
  waveButton: [900, 519], // click here
  waveButtonColor: [830, 505], // the same button, without text
  tile: (col, row) => [col * 40 + 20, row * 40 + 20],
  // The bar along the bottom of the field: wall, time slow, damage boost, ... (84 px wide, 4 px apart).
  abilityButton: (i) => [50 + i * 88 + 42, 579],
  fieldFrame: [400, 1.5], // the strip along the top edge where a running ability draws its frame
};

function hexOf(r, g, b) {
  return '#' + [r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('');
}

function distance(hexA, hexB) {
  const a = hexA.match(/\w\w/g).map((h) => parseInt(h, 16));
  const b = hexB.match(/\w\w/g).map((h) => parseInt(h, 16));
  return Math.max(...a.map((v, i) => Math.abs(v - b[i])));
}

/**
 * The game in a browser page. Everything goes through the page like a person
 * would: mouse clicks or finger taps on the canvas, and looking at the pixels.
 */
export class Game {
  constructor(page, { touch }) {
    this.page = page;
    this.touch = touch;
    this.problems = [];
    page.on('pageerror', (e) => this.problems.push(`page error: ${e.message}`));
    page.on('console', (m) => {
      // Browsers refuse to start audio before the first click; that is expected.
      if (m.type() === 'error' || (m.type() === 'warning' && !/AudioContext was not allowed/.test(m.text()))) {
        this.problems.push(`console ${m.type()}: ${m.text()}`);
      }
    });
    page.on('requestfailed', (r) => this.problems.push(`request failed: ${r.url()}`));
    page.on('response', (r) => {
      if (r.status() >= 400) this.problems.push(`HTTP ${r.status()}: ${r.url()}`);
    });
  }

  /** Where the 1000 x 600 game sits in the window (it keeps its aspect ratio). */
  layout() {
    const { width, height } = this.page.viewportSize();
    const scale = Math.min(width / 1000, height / 600);
    return { scale, x: (width - 1000 * scale) / 2, y: (height - 600 * scale) / 2, width, height };
  }

  toPage(gx, gy) {
    const l = this.layout();
    return [l.x + gx * l.scale, l.y + gy * l.scale];
  }

  async click([gx, gy]) {
    const [x, y] = this.toPage(gx, gy);
    if (this.touch) await this.page.touchscreen.tap(x, y);
    else await this.page.mouse.click(x, y);
  }

  /** Colours (as "#rrggbb") of points in game coordinates, from one screenshot. */
  async colors(...points) {
    const png = PNG.sync.read(await this.page.screenshot({ type: 'png' }));
    return points.map(([gx, gy]) => {
      const [x, y] = this.toPage(gx, gy).map((v) => Math.min(Math.floor(v), png.width - 1));
      const i = (png.width * y + x) * 4;
      return hexOf(png.data[i], png.data[i + 1], png.data[i + 2]);
    });
  }

  /** The red, green and blue (0-255) of a point. */
  async channels(point) {
    const hex = (await this.colors(point))[0];
    return hex.match(/\w\w/g).map((h) => parseInt(h, 16));
  }

  /** Waits until a point has a colour (or, with `not`, stops having it). */
  async waitForColor(point, hex, { not = false, tolerance = 12, timeout = 30_000, what = '' } = {}) {
    await expect
      .poll(async () => distance((await this.colors(point))[0], hex) <= tolerance, {
        message: `${what || `pixel ${point}`} should ${not ? 'not ' : ''}be ${hex}`,
        timeout,
        intervals: [250],
      })
      .toBe(!not);
  }

  async open() {
    await this.page.goto('/');
    await this.waitForMenu();
  }

  /** The title screen: the Play (or Continue) button is drawn in the accent colour. */
  async waitForMenu({ saved = false } = {}) {
    await this.waitForColor(saved ? AT.menuContinueColor : AT.menuPlayColor, COLORS.accent, {
      timeout: 60_000,
      what: saved ? 'the Continue button' : 'the Play button',
    });
  }

  async startMeadow() {
    await this.click(AT.menuPlay);
    await this.waitForColor(AT.levelMeadowPlayColor, COLORS.accent, { what: 'the level select screen' });
    await this.click(AT.levelMeadowPlay);
    await this.waitForColor(AT.tile(0, 0), COLORS.grassAlt, { tolerance: 8, what: 'the game field' });
  }

  /** Builds a gun tower on a free grass tile and waits until it is drawn. */
  async buildGun(col, row) {
    await this.waitForColor(AT.tile(col, row), COLORS.grass, { tolerance: 8, what: `free grass at ${col},${row}` });
    await this.click(AT.towerGun);
    await this.click(AT.tile(col, row));
    // Put the tool away and the pointer elsewhere, so only a real tower is left on the tile
    // (while building, a preview of the tower is drawn under the pointer).
    await this.page.keyboard.press('Escape');
    if (!this.touch) await this.page.mouse.move(...this.toPage(900, 300));
    await this.waitForColor(AT.tile(col, row), COLORS.grass, { not: true, tolerance: 20, what: `a tower at ${col},${row}` });
  }

  expectNoProblems() {
    expect(this.problems, 'errors in the browser console').toEqual([]);
  }
}
