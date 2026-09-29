import * as Phaser from 'phaser';
import { COLS, ROWS } from '../config';
import { GameMap } from '../sim/map';
import { COLORS } from './theme';

/** Draws a small picture of a map (used on the level-select cards). */
export function drawMinimap(g: Phaser.GameObjects.Graphics, map: GameMap, x: number, y: number, tile: number): void {
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      const color = {
        grass: (r + c) % 2 ? COLORS.grass : COLORS.grassAlt,
        road: COLORS.path,
        high: COLORS.high,
        rock: COLORS.rock,
        water: COLORS.water,
        bridge: COLORS.bridge,
      }[map.terrainAt(c, r) ?? 'grass'];
      g.fillStyle(color, 1).fillRect(x + c * tile, y + r * tile, tile, tile);
    }
  }
  g.lineStyle(1, 0x000000, 0.4).strokeRect(x, y, COLS * tile, ROWS * tile);
}
