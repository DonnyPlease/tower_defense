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

// Where things are on the menus, which are laid out for 1000 x 600 and centred
// in the view (see Game.centred).
export const AT = {
  menuPlay: [500, 263], // click the Play button here (centre)
  menuPlayColor: [400, 250], // a point of it without text, when there is no saved game
  menuContinue: [500, 233], // click the Continue button here (only with a saved game)
  menuContinueColor: [400, 225],
  menuMusicBorder: [370, 384], // left edge of the music button
  menuMusic: [432, 384],
  levelMeadowPlay: [190, 305], // click here
  levelMeadowPlayColor: [100, 305], // the same button, without text
};

// The game screen (src/scenes/game_scene.gd, src/ui/hud.gd, src/ui/ability_bar.gd).
const RAIL_W = 116;
const FIELD = [800, 600];
// A new profile owns two towers (and a "?" slot): two rows of build buttons,
// so the wall button starts at y = 80 + 2 * 54 + 4.
const TOOLS_Y = 192;

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

  /**
   * How the game fills the window. It is designed for a 1000 x 600 view; the
   * view keeps that scale and grows to the window's shape (no black bars), so
   * it is at least 1000 x 600 game units and `scale` page pixels per unit.
   */
  layout() {
    const { width, height } = this.page.viewportSize();
    const scale = Math.min(width / 1000, height / 600);
    return { scale, viewW: width / scale, viewH: height / scale, width, height };
  }

  /** A point of the view on the page. */
  toPage(gx, gy) {
    const l = this.layout();
    return [gx * l.scale, gy * l.scale];
  }

  /** A point of a screen laid out for 1000 x 600 (the menus), centred in the view. */
  centred([x, y]) {
    const l = this.layout();
    return [x + Math.floor((l.viewW - 1000) / 2), y + Math.floor((l.viewH - 600) / 2)];
  }

  /** The game screen: a point of the field (800 x 600) on the view (the map is scaled to fit left of the rail). */
  field(fx, fy) {
    const l = this.layout();
    const areaW = l.viewW - RAIL_W;
    const k = Math.min(areaW / FIELD[0], l.viewH / FIELD[1]);
    const x0 = Math.round((areaW - FIELD[0] * k) / 2);
    const y0 = Math.round((l.viewH - FIELD[1] * k) / 2);
    return [x0 + fx * k, y0 + fy * k];
  }

  /** The game screen: centre of a map tile. */
  tile(col, row) {
    return this.field(col * 40 + 20, row * 40 + 20);
  }

  /** The game screen: points on the rail at the right edge (and its drop-down). */
  rail(what) {
    const l = this.layout();
    const left = l.viewW - RAIL_W;
    const waveTop = l.viewH - 8 - 32 - 8 - 54;
    return {
      towerGun: [left + 32, 105], // the first build button (two per row)
      wall: [left + 58, TOOLS_Y + 17], // the wall button
      abilities: [left + 58, TOOLS_Y + 40 + 17], // opens the abilities' drop-down
      slow: [left - 168, 109], // its first button (time slow), while it is open
      background: [left + 58, TOOLS_Y + 150], // the rail between its buttons
      waveButton: [left + 58, waveTop + 27], // centre of the wave button
      waveButtonColor: [left + 14, waveTop + 27], // the same button, without text
    }[what];
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
    await this.waitForColor(this.centred(saved ? AT.menuContinueColor : AT.menuPlayColor), COLORS.accent, {
      timeout: 60_000,
      what: saved ? 'the Continue button' : 'the Play button',
    });
  }

  async startMeadow() {
    await this.click(this.centred(AT.menuPlay));
    await this.waitForColor(this.centred(AT.levelMeadowPlayColor), COLORS.accent, { what: 'the level select screen' });
    await this.click(this.centred(AT.levelMeadowPlay));
    await this.waitForColor(this.tile(0, 0), COLORS.grassAlt, { tolerance: 8, what: 'the game field' });
  }

  /** Builds a gun tower on a free grass tile and waits until it is drawn. */
  async buildGun(col, row) {
    await this.waitForColor(this.tile(col, row), COLORS.grass, { tolerance: 8, what: `free grass at ${col},${row}` });
    await this.click(this.rail('towerGun'));
    await this.click(this.tile(col, row));
    // Put the tool away and the pointer elsewhere, so only a real tower is left on the tile
    // (while building, a preview of the tower is drawn under the pointer).
    await this.page.keyboard.press('Escape');
    if (!this.touch) await this.page.mouse.move(...this.toPage(...this.rail('background')));
    await this.waitForColor(this.tile(col, row), COLORS.grass, { not: true, tolerance: 20, what: `a tower at ${col},${row}` });
  }

  expectNoProblems() {
    expect(this.problems, 'errors in the browser console').toEqual([]);
  }
}
