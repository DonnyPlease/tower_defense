import { TILE } from '../config';
import { GameMap, tileCenter, type DistanceField, type Dir, type Point, type Tile } from './map';

/** Tells an enemy where to walk next. */
export interface Nav {
  /** Current waypoint the enemy is heading to. */
  readonly target: Point;
  /** Moves on to the next waypoint; null when the enemy has left the map. */
  advance(): Point | null;
  /** Remaining path length from (x, y) to the exit, used for targeting. */
  remaining(x: number, y: number): number;
  /** Tile the enemy is heading to (maze levels only). */
  readonly targetTile: Tile | null;
  clone(): Nav;
}

/** Follows a fixed list of waypoints (road levels and flying enemies). */
export class RouteNav implements Nav {
  private readonly suffix: number[]; // path length from waypoint i to the end

  constructor(private readonly route: Point[], private idx = 1, suffix?: number[]) {
    if (suffix) {
      this.suffix = suffix;
    } else {
      this.suffix = new Array<number>(route.length).fill(0);
      for (let i = route.length - 2; i >= 0; i--) {
        this.suffix[i] = this.suffix[i + 1] + Math.hypot(route[i + 1].x - route[i].x, route[i + 1].y - route[i].y);
      }
    }
  }

  get start(): Point {
    return this.route[0];
  }

  get target(): Point {
    return this.route[Math.min(this.idx, this.route.length - 1)];
  }

  get targetTile(): Tile | null {
    return null;
  }

  advance(): Point | null {
    this.idx++;
    return this.idx < this.route.length ? this.route[this.idx] : null;
  }

  remaining(x: number, y: number): number {
    const t = this.target;
    return Math.hypot(t.x - x, t.y - y) + this.suffix[Math.min(this.idx, this.route.length - 1)];
  }

  clone(): Nav {
    return new RouteNav(this.route, this.idx, this.suffix);
  }
}

/**
 * Walks tile by tile down a shared distance field that the world recomputes
 * whenever towers change (maze levels), so enemies re-route around new walls.
 */
export class FlowNav implements Nav {
  target: Point;
  private exiting = false;

  constructor(
    private readonly map: GameMap,
    private readonly field: () => DistanceField,
    private tile: Tile,
    private dir: Dir | null = null,
  ) {
    this.target = tileCenter(tile);
  }

  get targetTile(): Tile | null {
    return this.exiting ? null : this.tile;
  }

  advance(): Point | null {
    if (this.exiting) return null;
    const dist = this.field();
    const next = GameMap.nextTile(dist, this.tile, this.dir);
    if (!next) {
      if (dist[this.tile.row][this.tile.col] === 0) {
        this.exiting = true;
        this.target = this.map.outside(this.tile);
      }
      // Otherwise the tile is cut off (should not happen: builds are validated). Wait here.
      return this.target;
    }
    this.dir = [next.col - this.tile.col, next.row - this.tile.row];
    this.tile = next;
    this.target = tileCenter(next);
    return this.target;
  }

  remaining(x: number, y: number): number {
    const toTarget = Math.hypot(this.target.x - x, this.target.y - y);
    if (this.exiting) return toTarget;
    const d = this.field()[this.tile.row][this.tile.col];
    return toTarget + (Number.isFinite(d) ? d : 99) * TILE + TILE;
  }

  clone(): Nav {
    const c = new FlowNav(this.map, this.field, this.tile, this.dir);
    c.target = this.target;
    c.exiting = this.exiting;
    return c;
  }
}
