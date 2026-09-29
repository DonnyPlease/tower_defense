import { TILE, COLS, ROWS } from '../config';

export interface Tile {
  col: number;
  row: number;
}
export interface Point {
  x: number;
  y: number;
}
export type Dir = readonly [number, number];
export type Terrain = 'grass' | 'road' | 'high' | 'rock' | 'water' | 'bridge';

export const DIRS: readonly Dir[] = [[1, 0], [0, 1], [-1, 0], [0, -1]];

const TERRAIN: Record<string, Terrain> = {
  '.': 'grass', '#': 'road', S: 'road', E: 'road', H: 'high', R: 'rock', '~': 'water', '=': 'bridge',
};

export const tileCenter = (t: Tile): Point => ({ x: t.col * TILE + TILE / 2, y: t.row * TILE + TILE / 2 });

/** Distance (in tiles) from every tile to the nearest exit; Infinity if unreachable. */
export type DistanceField = number[][];

export interface MapSource {
  name: string;
  tiles: string[];
  maze?: boolean;
}

export class GameMap {
  readonly name: string;
  readonly maze: boolean;
  readonly starts: Tile[] = [];
  readonly ends: Tile[] = [];
  /** Road levels: one fixed route (pixel waypoints) per start/end pair. */
  readonly routes: Point[][] = [];
  /** Straight routes for flying enemies, one per start/end pair. */
  readonly flightRoutes: Point[][] = [];
  private readonly terrain: Terrain[][];

  constructor(def: MapSource) {
    this.name = def.name;
    this.maze = def.maze ?? false;
    if (def.tiles.length !== ROWS || def.tiles.some((r) => r.length !== COLS)) {
      throw new Error(`Map "${def.name}" must be ${COLS}x${ROWS} tiles`);
    }
    this.terrain = def.tiles.map((row, r) => [...row].map((ch, c) => {
      const t = TERRAIN[ch];
      if (!t) throw new Error(`Map "${def.name}": unknown tile '${ch}' at ${c},${r}`);
      if (ch === 'S') this.starts.push({ col: c, row: r });
      if (ch === 'E') this.ends.push({ col: c, row: r });
      return t;
    }));
    if (!this.starts.length || !this.ends.length) {
      throw new Error(`Map "${def.name}" needs at least one S and one E tile`);
    }
    for (const s of this.starts) {
      for (const e of this.ends) {
        const tiles = this.findPath(s, e);
        if (!tiles) throw new Error(`Map "${def.name}": no path from S to E`);
        this.routes.push(this.toWaypoints(tiles));
        this.flightRoutes.push([this.outside(s), tileCenter(s), tileCenter(e), this.outside(e)]);
      }
    }
  }

  inBounds(col: number, row: number): boolean {
    return col >= 0 && col < COLS && row >= 0 && row < ROWS;
  }

  terrainAt(col: number, row: number): Terrain | null {
    return this.inBounds(col, row) ? this.terrain[row][col] : null;
  }

  /** Drawn as road (road or bridge). */
  isRoad(col: number, row: number): boolean {
    const t = this.terrainAt(col, row);
    return t === 'road' || t === 'bridge';
  }

  isBuildableTerrain(col: number, row: number): boolean {
    const t = this.terrainAt(col, row);
    return t === 'grass' || t === 'high';
  }

  isHighGround(col: number, row: number): boolean {
    return this.terrainAt(col, row) === 'high';
  }

  /** Whether ground enemies may walk here, ignoring towers. */
  isWalkable(col: number, row: number): boolean {
    const t = this.terrainAt(col, row);
    if (t === 'road' || t === 'bridge') return true;
    return this.maze && (t === 'grass' || t === 'high');
  }

  /**
   * BFS distance field from all exits over walkable tiles. `blocked` marks
   * extra obstacles (towers in maze levels).
   */
  distanceField(
    blocked: (col: number, row: number) => boolean = () => false,
    exits: readonly Tile[] = this.ends,
  ): DistanceField {
    const dist = Array.from({ length: ROWS }, () => new Array<number>(COLS).fill(Infinity));
    const queue: Tile[] = [];
    for (const e of exits) {
      dist[e.row][e.col] = 0;
      queue.push(e);
    }
    for (let i = 0; i < queue.length; i++) {
      const { col, row } = queue[i];
      for (const [dc, dr] of DIRS) {
        const c = col + dc, r = row + dr;
        if (this.isWalkable(c, r) && !blocked(c, r) && dist[r][c] === Infinity) {
          dist[r][c] = dist[row][col] + 1;
          queue.push({ col: c, row: r });
        }
      }
    }
    return dist;
  }

  /**
   * Next tile towards the exit, following the distance field and preferring
   * to keep going in direction `dir` (fewer turns). Null at an exit or when the
   * tile can't reach one.
   */
  static nextTile(dist: DistanceField, cur: Tile, dir: Dir | null): Tile | null {
    const d = dist[cur.row]?.[cur.col] ?? Infinity;
    if (d === 0 || !Number.isFinite(d)) return null; // at the exit, or cut off from it
    const options = dir ? [dir, ...DIRS] : DIRS;
    for (const [dc, dr] of options) {
      const c = cur.col + dc, r = cur.row + dr;
      if ((dist[r]?.[c] ?? Infinity) === d - 1) return { col: c, row: r };
    }
    return null;
  }

  /** Shortest path of tiles from `start` to the exit `end` (fewest turns). */
  findPath(start: Tile, end: Tile): Tile[] | null {
    const dist = this.distanceField(undefined, [end]);
    if (dist[start.row][start.col] === Infinity) return null;
    const tiles = [start];
    let cur = start;
    const [oc, or] = this.outward(start);
    let dir: Dir = [-oc, -or];
    for (;;) {
      const next = GameMap.nextTile(dist, cur, dir);
      if (!next) break;
      dir = [next.col - cur.col, next.row - cur.row];
      cur = next;
      tiles.push(cur);
    }
    return tiles;
  }

  /** Direction pointing off the map from a border tile. */
  outward({ col, row }: Tile): Dir {
    if (col === 0) return [-1, 0];
    if (col === COLS - 1) return [1, 0];
    if (row === 0) return [0, -1];
    if (row === ROWS - 1) return [0, 1];
    return [0, 0];
  }

  /** Centre of the tile just outside the map next to a border tile. */
  outside(t: Tile): Point {
    const [dc, dr] = this.outward(t);
    return tileCenter({ col: t.col + dc, row: t.row + dr });
  }

  /**
   * Converts a tile path into pixel waypoints, starting one tile outside the
   * map and ending one tile outside the map. Collinear points are dropped.
   */
  toWaypoints(tiles: Tile[]): Point[] {
    const pts = [this.outside(tiles[0]), ...tiles.map(tileCenter), this.outside(tiles[tiles.length - 1])];
    const out = [pts[0]];
    for (let i = 1; i < pts.length - 1; i++) {
      const a = out[out.length - 1], b = pts[i], c = pts[i + 1];
      const cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross !== 0) out.push(b);
    }
    out.push(pts[pts.length - 1]);
    return out;
  }
}
