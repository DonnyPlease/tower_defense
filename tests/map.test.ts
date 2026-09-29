import { describe, it, expect } from 'vitest';
import { GameMap } from '../src/sim/map';
import { MAPS, TILE, COLS, ROWS } from '../src/config';

describe('GameMap', () => {
  const map = new GameMap(MAPS[0]);

  it('finds the S and E tiles', () => {
    expect(map.starts).toHaveLength(3);
    expect(map.ends).toHaveLength(2);
    expect(map.routes).toHaveLength(6);
  });

  it('routes start and end one tile outside the field', () => {
    for (const route of map.routes) {
      expect(route[0].x).toBe(-TILE / 2);
      expect(route[route.length - 1].x).toBe(COLS * TILE + TILE / 2);
    }
  });

  it('finds a connected shortest path of path tiles', () => {
    const tiles = map.findPath({ col: 0, row: 11 }, { col: 19, row: 6 })!;
    expect(tiles).not.toBeNull();
    for (let i = 1; i < tiles.length; i++) {
      const a = tiles[i - 1], b = tiles[i];
      expect(Math.abs(a.col - b.col) + Math.abs(a.row - b.row)).toBe(1);
      expect(map.isPath(b.col, b.row)).toBe(true);
    }
  });

  it('only turns at waypoints (no collinear points)', () => {
    for (const route of map.routes) {
      for (let i = 1; i < route.length - 1; i++) {
        const [a, b, c] = [route[i - 1], route[i], route[i + 1]];
        expect((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)).not.toBe(0);
      }
    }
  });

  it('rejects maps without a path', () => {
    const tiles = Array.from({ length: ROWS }, () => '.'.repeat(COLS));
    tiles[0] = 'S' + '.'.repeat(COLS - 2) + 'E';
    expect(() => new GameMap({ name: 'broken', tiles })).toThrow(/no path/);
  });
});
