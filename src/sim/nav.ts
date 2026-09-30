import { TILE } from '../config';
import { GameMap, tileCenter, type DistanceField, type Dir, type Point, type Tile } from './map';
import type { Route } from './route';

/** Moves one enemy through the map. Each enemy owns its own Nav. */
export interface Nav {
  readonly x: number;
  readonly y: number;
  /** Direction the enemy is walking in (radians). */
  readonly heading: number;
  /** Walks `step` pixels. Returns false once the enemy has left the map. */
  move(step: number): boolean;
  /** Remaining path length to the exit, used for targeting. */
  remaining(): number;
  /** Tile the enemy is heading to (maze levels only). */
  readonly targetTile: Tile | null;
  /** Moves `dist` pixels back along the way the enemy came (splitters' children). */
  fallBack(dist: number): void;
  /** Copy at the same spot (for splitters' children), with its own lane from `seed`. */
  clone(seed: number): Nav;
}

/** Deterministic pseudo random number in [0, 1) for an integer seed. */
export function hash01(seed: number, salt = 0): number {
  let t = (Math.imul(seed ^ 0x9e3779b9, 0x85ebca6b) + Math.imul(salt + 1, 0xc2b2ae35)) >>> 0;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

const LANE_SHIFT = 0.35; // how fast an enemy may change lane (px sideways per px forward)

/**
 * Walks along a smooth route (road levels and flyers). Every enemy keeps to
 * its own lane and sways a little, so a wave spreads over the road instead of
 * marching in single file.
 */
export class RouteNav implements Nav {
  x = 0;
  y = 0;
  heading = 0;
  private s = 0; // distance travelled along the route
  private i = 0; // current sample segment
  private offset: number; // current sideways offset (px, left positive)
  private readonly lane: number; // preferred offset
  private readonly sway: number; // amplitude of the weave
  private readonly wavelength: number;
  private readonly phase: number;

  constructor(private readonly route: Route, seed: number, flying = false, from?: RouteNav) {
    const spread = flying ? 0.9 : 0.75;
    this.lane = (hash01(seed, 1) * 2 - 1) * spread * TILE;
    this.sway = (flying ? 10 : 4) + hash01(seed, 2) * (flying ? 12 : 6);
    this.wavelength = (flying ? 260 : 180) + hash01(seed, 3) * 160;
    this.phase = hash01(seed, 4) * Math.PI * 2;
    if (from) {
      this.s = from.s;
      this.i = from.i;
      this.offset = from.offset;
      this.heading = from.heading;
    } else {
      this.offset = route.clampOffset(this.desiredOffset(), 0);
    }
    this.place();
    if (!from) {
      const a = route.points[0], b = route.points[Math.min(1, route.points.length - 1)];
      this.heading = Math.atan2(b.y - a.y, b.x - a.x);
    }
  }

  get targetTile(): Tile | null {
    return null;
  }

  private desiredOffset(): number {
    return this.lane + this.sway * Math.sin((this.s / this.wavelength) * Math.PI * 2 + this.phase);
  }

  private place(): void {
    const p = this.route.at(this.s, this.offset, this.i);
    this.x = p.x;
    this.y = p.y;
  }

  move(step: number): boolean {
    if (step <= 0) return true;
    const x0 = this.x, y0 = this.y, s0 = this.s, off0 = this.offset;
    // Walk `ds` along the centre line; on the outside of a bend that covers
    // more ground than `ds`, so correct once to keep the real speed right.
    let ds = step;
    for (let k = 0; k < 2; k++) {
      this.s = s0 + ds;
      this.i = this.route.seek(this.s, this.i);
      const want = this.desiredOffset();
      const shift = Math.max(-LANE_SHIFT * ds, Math.min(LANE_SHIFT * ds, want - off0));
      this.offset = this.route.clampOffset(off0 + shift, this.i);
      this.place();
      const moved = Math.hypot(this.x - x0, this.y - y0);
      if (k === 0 && moved > 1e-6) ds = Math.max(0.5 * step, Math.min(2 * step, (ds * step) / moved));
    }
    const dx = this.x - x0, dy = this.y - y0;
    if (dx * dx + dy * dy > 1e-8) this.heading = Math.atan2(dy, dx);
    return this.s < this.route.length;
  }

  fallBack(dist: number): void {
    this.s = Math.max(0, this.s - dist);
    this.i = this.route.seek(this.s, this.i);
    this.offset = this.route.clampOffset(this.offset, this.i);
    this.place();
  }

  remaining(): number {
    return Math.max(0, this.route.length - this.s);
  }

  clone(seed: number): Nav {
    return new RouteNav(this.route, seed, false, this);
  }
}

const TURN_RADIUS = 0.3 * TILE; // tightest turn when walking at full speed
const ADVANCE = 0.45 * TILE; // head for the next tile once this close to the current one
const AIM_JITTER = 0.18 * TILE; // how far from tile centres each enemy walks

/**
 * Walks tile by tile down a shared distance field that the world recomputes
 * whenever towers change (maze levels), so enemies re-route around new walls.
 * Enemies steer like vehicles: they start the next turn before reaching a
 * tile's centre, turn at a limited rate and slow down for sharp turns.
 */
export class FlowNav implements Nav {
  x: number;
  y: number;
  heading: number;
  private target: Point;
  private exiting = false;
  private readonly ax: number; // this enemy's aim offset from tile centres
  private readonly ay: number;

  constructor(
    private readonly map: GameMap,
    private readonly field: () => DistanceField,
    private tile: Tile,
    seed: number,
    private dir: Dir | null = null,
    from?: FlowNav,
  ) {
    this.ax = (hash01(seed, 5) * 2 - 1) * AIM_JITTER;
    this.ay = (hash01(seed, 6) * 2 - 1) * AIM_JITTER;
    if (from) {
      this.x = from.x;
      this.y = from.y;
      this.heading = from.heading;
      this.exiting = from.exiting;
      this.target = this.exiting ? from.target : this.aim(tile);
    } else {
      const start = map.outside(tile);
      this.x = start.x;
      this.y = start.y;
      this.target = this.aim(tile);
      this.heading = Math.atan2(this.target.y - this.y, this.target.x - this.x);
    }
  }

  get targetTile(): Tile | null {
    return this.exiting ? null : this.tile;
  }

  private aim(t: Tile): Point {
    const c = tileCenter(t);
    return { x: c.x + this.ax, y: c.y + this.ay };
  }

  /** Picks the next tile. Returns false when there is nowhere to go (cut off). */
  private advance(): boolean {
    const dist = this.field();
    const next = GameMap.nextTile(dist, this.tile, this.dir);
    if (!next) {
      if (dist[this.tile.row][this.tile.col] !== 0) return false; // cut off: should not happen, wait
      this.exiting = true;
      const out = this.map.outside(this.tile);
      this.target = { x: out.x + this.ax, y: out.y + this.ay };
      return true;
    }
    this.dir = [next.col - this.tile.col, next.row - this.tile.row];
    this.tile = next;
    this.target = this.aim(next);
    return true;
  }

  move(step: number): boolean {
    if (step <= 0) return true;
    let d = Math.hypot(this.target.x - this.x, this.target.y - this.y);
    if (this.exiting) {
      if (d <= step) return false;
    } else if (d < ADVANCE) {
      if (!this.advance()) {
        // Nowhere to go: walk onto the tile and wait.
        const k = Math.min(1, step / (d || 1));
        this.x += (this.target.x - this.x) * k;
        this.y += (this.target.y - this.y) * k;
        return true;
      }
      d = Math.hypot(this.target.x - this.x, this.target.y - this.y);
    }
    const want = Math.atan2(this.target.y - this.y, this.target.x - this.x);
    const diff = Math.atan2(Math.sin(want - this.heading), Math.cos(want - this.heading));
    const maxTurn = step / TURN_RADIUS;
    this.heading += Math.max(-maxTurn, Math.min(maxTurn, diff));
    // Slow down while facing away from the target, like a vehicle turning.
    const left = Math.atan2(Math.sin(want - this.heading), Math.cos(want - this.heading));
    const forward = Math.min(d, step * Math.max(0.25, Math.cos(left)));
    this.x += Math.cos(this.heading) * forward;
    this.y += Math.sin(this.heading) * forward;
    return true;
  }

  fallBack(dist: number): void {
    this.x -= Math.cos(this.heading) * dist;
    this.y -= Math.sin(this.heading) * dist;
  }

  remaining(): number {
    const toTarget = Math.hypot(this.target.x - this.x, this.target.y - this.y);
    if (this.exiting) return toTarget;
    const d = this.field()[this.tile.row][this.tile.col];
    return toTarget + (Number.isFinite(d) ? d : 99) * TILE + TILE;
  }

  clone(seed: number): Nav {
    return new FlowNav(this.map, this.field, this.tile, seed, this.dir, this);
  }
}
