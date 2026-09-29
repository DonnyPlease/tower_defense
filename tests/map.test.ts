import { describe, it, expect } from 'vitest';
import { GameMap, tileCenter } from '../src/sim/map';
import { LEVELS, levelById } from '../src/data/levels';
import { TILE, COLS, ROWS } from '../src/config';

describe('GameMap', () => {
  const meadow = new GameMap(levelById('meadow'));

  it('every level parses and has a route for every start/exit pair', () => {
    for (const level of LEVELS) {
      const map = new GameMap(level);
      expect(map.routes.length).toBe(map.starts.length * map.ends.length);
      expect(map.flightRoutes.length).toBe(map.routes.length);
    }
  });

  it('routes start and end one tile outside the field', () => {
    for (const route of meadow.routes) {
      expect(route[0].x).toBe(-TILE / 2);
      expect(route[route.length - 1].x).toBe(COLS * TILE + TILE / 2);
    }
  });

  it('finds a connected path over walkable tiles', () => {
    const tiles = meadow.findPath({ col: 0, row: 11 }, { col: 19, row: 6 })!;
    for (let i = 1; i < tiles.length; i++) {
      const a = tiles[i - 1], b = tiles[i];
      expect(Math.abs(a.col - b.col) + Math.abs(a.row - b.row)).toBe(1);
      expect(meadow.isWalkable(b.col, b.row)).toBe(true);
    }
  });

  it('only turns at waypoints (no collinear points)', () => {
    for (const route of meadow.routes) {
      for (let i = 1; i < route.length - 1; i++) {
        const [a, b, c] = [route[i - 1], route[i], route[i + 1]];
        expect((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)).not.toBe(0);
      }
    }
  });

  it('understands terrain', () => {
    const river = new GameMap(levelById('riverside'));
    expect(river.terrainAt(9, 0)).toBe('water');
    expect(river.isBuildableTerrain(9, 0)).toBe(false);
    expect(river.terrainAt(9, 7)).toBe('bridge');
    expect(river.isWalkable(9, 7)).toBe(true);
    const high = new GameMap(levelById('highlands'));
    expect(high.isHighGround(2, 3)).toBe(true);
    expect(high.isBuildableTerrain(2, 3)).toBe(true);
    expect(high.terrainAt(12, 2)).toBe('rock');
  });

  it('lets enemies walk on grass only in maze levels', () => {
    expect(meadow.isWalkable(0, 0)).toBe(false);
    const field = new GameMap(levelById('openfield'));
    expect(field.isWalkable(1, 1)).toBe(true);
    expect(field.isWalkable(6, 1)).toBe(false); // rock
  });

  it('rejects broken maps', () => {
    const tiles = Array.from({ length: ROWS }, () => '.'.repeat(COLS));
    tiles[0] = 'S' + '.'.repeat(COLS - 2) + 'E';
    expect(() => new GameMap({ name: 'no path', tiles })).toThrow(/no path/);
    tiles[0] = 'S' + 'X'.repeat(COLS - 2) + 'E';
    expect(() => new GameMap({ name: 'bad tile', tiles })).toThrow(/unknown tile/);
  });

  it('tileCenter is the middle of the tile', () => {
    expect(tileCenter({ col: 2, row: 3 })).toEqual({ x: 2 * TILE + TILE / 2, y: 3 * TILE + TILE / 2 });
  });
});
