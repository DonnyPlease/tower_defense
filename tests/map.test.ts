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
      expect(route.points[0].x).toBe(-TILE / 2);
      expect(route.points[route.points.length - 1].x).toBe(COLS * TILE + TILE / 2);
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

  it('routes are smooth: no sharp corners anywhere', () => {
    for (const level of LEVELS) {
      const map = new GameMap(level);
      for (const route of [...map.routes, ...map.flightRoutes]) {
        const p = route.points;
        for (let i = 1; i < p.length - 1; i++) {
          const a1 = Math.atan2(p[i].y - p[i - 1].y, p[i].x - p[i - 1].x);
          const a2 = Math.atan2(p[i + 1].y - p[i].y, p[i + 1].x - p[i].x);
          expect(Math.abs(Math.atan2(Math.sin(a2 - a1), Math.cos(a2 - a1)))).toBeLessThan(0.5);
        }
      }
    }
  });

  it('keeps to the middle of wide roads and knows how much room there is', () => {
    // Meadow's first straight is 3 tiles wide (rows 10-12), with room on both sides.
    const route = meadow.routes[0];
    const i = route.points.findIndex((p) => p.x >= 2 * TILE);
    expect(route.points[i].y).toBeGreaterThan(10 * TILE + 14);
    expect(route.points[i].y).toBeLessThan(13 * TILE - 14);
    expect(route.left[i]).toBeGreaterThan(TILE / 2);
    expect(route.right[i]).toBeGreaterThan(TILE / 2);
    // Riverside's roads are one tile wide: hardly any room to the sides.
    const river = new GameMap(levelById('riverside'));
    const j = river.routes[0].points.findIndex((p) => p.x >= 2 * TILE);
    expect(river.routes[0].left[j]).toBeLessThan(10);
    expect(river.routes[0].right[j]).toBeLessThan(10);
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

describe('GameMap validation and edges', () => {
  const blank = () => Array.from({ length: ROWS }, () => '.'.repeat(COLS));

  it('rejects maps of the wrong size', () => {
    expect(() => new GameMap({ name: 'small', tiles: ['S..E'] })).toThrow(/must be 20x15/);
  });

  it('rejects maps without an entrance or exit', () => {
    const tiles = blank();
    tiles[0] = 'S' + '#'.repeat(COLS - 1);
    expect(() => new GameMap({ name: 'no exit', tiles })).toThrow(/at least one S and one E/);
  });

  it('points off the map from every border', () => {
    const tiles = blank();
    tiles[0] = '.S' + '.'.repeat(COLS - 2);
    for (let r = 1; r < ROWS - 1; r++) tiles[r] = '.#' + '.'.repeat(COLS - 2);
    tiles[ROWS - 1] = '.E' + '.'.repeat(COLS - 2);
    const map = new GameMap({ name: 'vertical', tiles });
    expect(map.outward({ col: 1, row: 0 })).toEqual([0, -1]);
    expect(map.outward({ col: 1, row: ROWS - 1 })).toEqual([0, 1]);
    expect(map.outward({ col: COLS - 1, row: 5 })).toEqual([1, 0]);
    expect(map.outward({ col: 5, row: 5 })).toEqual([0, 0]);
    expect(map.routes[0].points[0].y).toBeLessThan(0); // enters from above
  });

  it('nextTile stops at the exit and outside the field', () => {
    const map = new GameMap(levelById('meadow'));
    const field = map.distanceField();
    expect(GameMap.nextTile(field, map.ends[0], null)).toBeNull();
    expect(GameMap.nextTile(field, { col: -5, row: -5 }, null)).toBeNull();
  });
});
