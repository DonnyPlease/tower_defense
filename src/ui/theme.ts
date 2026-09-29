import * as Phaser from 'phaser';
import { WIDTH, HEIGHT } from '../config';

/** Generated textures are drawn this many times larger than their display size. */
export const GEN = 2;

export const COLORS = {
  background: 0x14171f,
  panel: 0x1e2230,
  panelLight: 0x2a3042,
  panelLighter: 0x353d54,
  border: 0x454f6b,
  gold: 0xf5c542,
  red: 0xe5534b,
  green: 0x57c26b,
  accent: 0x4f8ef7,
  grass: 0x5d8f3b,
  grassAlt: 0x659a41,
  path: 0xdcc594,
  pathEdge: 0xb89f6b,
  high: 0x86b25a,
  highEdgeLight: 0xa9cf7c,
  highEdgeDark: 0x4d7530,
  rock: 0x7b8088,
  rockDark: 0x555a61,
  water: 0x3a7bd5,
  waterLight: 0x6fa8f0,
  bridge: 0x9c6b3c,
  bridgeDark: 0x6e4a27,
};

export const CSS = {
  text: '#e8ecf4',
  textDim: '#9aa3b8',
  gold: '#f5c542',
  red: '#e5534b',
  green: '#57c26b',
};

export const FONT = 'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';

/**
 * Render resolution multiplier. The game logic always works in a 1000x600
 * coordinate space; the canvas is rendered RES times larger and the cameras
 * zoom in, so text and sprites stay sharp on large and high-DPI screens.
 */
export const RES = (() => {
  const dpr = window.devicePixelRatio || 1;
  const fit = Math.min(window.innerWidth / WIDTH, window.innerHeight / HEIGHT) * dpr;
  return Math.min(3, Math.max(1, Math.ceil(fit)));
})();

export function setupCamera(scene: Phaser.Scene): void {
  scene.cameras.main.setOrigin(0, 0).setZoom(RES);
}

export function addText(
  scene: Phaser.Scene, x: number, y: number, text: string,
  style: Phaser.Types.GameObjects.Text.TextStyle = {},
): Phaser.GameObjects.Text {
  return scene.add.text(x, y, text, {
    fontFamily: FONT,
    fontSize: '16px',
    color: CSS.text,
    resolution: RES,
    ...style,
  });
}



/** Scale that shows a sprite texture at one tile (40 px), whatever its source size. */
export function spriteScale(scene: Phaser.Scene, key: string): number {
  const w = scene.textures.get(key).getSourceImage().width || 40;
  return 40 / w;
}

/** Texture showing a whole tower (base + turret) for icons and previews. */
export function towerIcon(scene: Phaser.Scene, kind: string): string {
  return scene.textures.exists(`${kind}-icon`) ? `${kind}-icon` : `${kind}-0`;
}
