import { TILE, COLS, ROWS } from '../config';
import { Route } from './route';

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

const VERGE_COST = 2; // extra cost of a road tile next to the verge (divided by its clearance)
const MAX_LANE = 1.2 * TILE; // furthest an enemy walks from the middle of the road
const LANE_MARGIN = 14; // keep enemies' bodies this far inside the road edge
const FLIGHT_LANE = 1.2 * TILE; // flyers spread this far to either side

/** Routes only depend on the tiles, and smoothing them takes a moment: build each map's once. */
const ROUTES = new Map<string, { routes: Route[]; flightRoutes: Route[] }>();

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
  /** Road levels: one smooth route along the middle of the road per start/end pair. */
  readonly routes: readonly Route[];
  /** Nearly straight routes for flying enemies, one per start/end pair. */
  readonly flightRoutes: readonly Route[];
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
    const key = def.tiles.join('\n') + (this.maze ? 'm' : '');
    let cached = ROUTES.get(key);
    if (!cached) {
      cached = { routes: [], flightRoutes: [] };
      for (const s of this.starts) {
        for (const e of this.ends) {
          const tiles = this.findPath(s, e);
          if (!tiles) throw new Error(`Map "${def.name}": no path from S to E`);
          const pts = [this.outside(s), ...tiles.map(tileCenter), this.outside(e)];
          // Maze levels steer with the flow field instead, so skip the smoothing.
          cached.routes.push(new Route(pts, (p, n) => this.roadWidth(p, n), this.maze ? undefined : (p) => this.clearanceAt(p)));
          const flight = [this.outside(s), tileCenter(s), tileCenter(e), this.outside(e)];
          cached.flightRoutes.push(new Route(flight, () => FLIGHT_LANE));
        }
      }
      ROUTES.set(key, cached);
    }
    this.routes = cached.routes;
    this.flightRoutes = cached.flightRoutes;
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

  /**
   * Path of tiles from `start` to the exit `end` that is short but keeps to
   * the middle of wide roads (tiles next to the verge cost more).
   */
  findPath(start: Tile, end: Tile): Tile[] | null {
    const clear = this.clearance();
    const cost = Array.from({ length: ROWS }, () => new Array<number>(COLS).fill(Infinity));
    const done = Array.from({ length: ROWS }, () => new Array<boolean>(COLS).fill(false));
    cost[end.row][end.col] = 0;
    for (;;) {
      let cur: Tile | null = null;
      for (let r = 0; r < ROWS; r++) {
        for (let c = 0; c < COLS; c++) {
          if (!done[r][c] && cost[r][c] < Infinity && (!cur || cost[r][c] < cost[cur.row][cur.col])) cur = { col: c, row: r };
        }
      }
      if (!cur) break;
      done[cur.row][cur.col] = true;
      for (const [dc, dr] of DIRS) {
        const c = cur.col + dc, r = cur.row + dr;
        if (!this.isWalkable(c, r)) continue;
        const d = cost[cur.row][cur.col] + 1 + VERGE_COST / clear[r][c];
        if (d < cost[r][c]) cost[r][c] = d;
      }
    }
    if (cost[start.row][start.col] === Infinity) return null;
    const tiles = [start];
    let cur = start;
    while (cur.col !== end.col || cur.row !== end.row) {
      let best: Tile | null = null;
      for (const [dc, dr] of DIRS) {
        const c = cur.col + dc, r = cur.row + dr;
        if (this.inBounds(c, r) && (!best || cost[r][c] < cost[best.row][best.col])) best = { col: c, row: r };
      }
      cur = best!;
      tiles.push(cur);
    }
    return tiles;
  }

  /** For every walkable tile, how many steps (8 directions) to the nearest unwalkable tile. */
  private clearance(): number[][] {
    const out = Array.from({ length: ROWS }, () => new Array<number>(COLS).fill(Infinity));
    const queue: Tile[] = [];
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (!this.isWalkable(c, r)) {
          out[r][c] = 0;
          queue.push({ col: c, row: r });
        }
      }
    }
    for (let i = 0; i < queue.length; i++) {
      const { col, row } = queue[i];
      for (let dr = -1; dr <= 1; dr++) {
        for (let dc = -1; dc <= 1; dc++) {
          const c = col + dc, r = row + dr;
          if (this.inBounds(c, r) && out[r][c] === Infinity) {
            out[r][c] = out[row][col] + 1;
            queue.push({ col: c, row: r });
          }
        }
      }
    }
    return out;
  }

  /** Distance (pixels) from `p` to the nearest unwalkable tile; negative inside one. */
  private clearanceAt(p: Point): number {
    const col = Math.min(COLS - 1, Math.max(0, Math.floor(p.x / TILE)));
    const row = Math.min(ROWS - 1, Math.max(0, Math.floor(p.y / TILE)));
    if (!this.isWalkable(col, row)) return -1;
    let best = Infinity;
    for (let r = row - 1; r <= row + 1; r++) {
      for (let c = col - 1; c <= col + 1; c++) {
        if (!this.inBounds(c, r) || this.isWalkable(c, r)) continue;
        const dx = Math.max(c * TILE - p.x, 0, p.x - (c + 1) * TILE);
        const dy = Math.max(r * TILE - p.y, 0, p.y - (r + 1) * TILE);
        best = Math.min(best, Math.hypot(dx, dy));
      }
    }
    return best;
  }

  /**
   * How far (pixels) an enemy may stray from point `p` in direction `n` and
   * still walk on the road. Off the map, the nearest border tile counts.
   */
  private roadWidth(p: Point, n: Point): number {
    let ok = 0;
    for (let o = 2; o <= MAX_LANE + LANE_MARGIN; o += 2) {
      const col = Math.min(COLS - 1, Math.max(0, Math.floor((p.x + n.x * o) / TILE)));
      const row = Math.min(ROWS - 1, Math.max(0, Math.floor((p.y + n.y * o) / TILE)));
      if (!this.isWalkable(col, row)) break;
      ok = o;
    }
    return Math.max(0, Math.min(MAX_LANE, ok - LANE_MARGIN));
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
}
