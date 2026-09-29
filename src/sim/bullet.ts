import { FIELD_W, FIELD_H, TICK_RATE } from '../config';
import type { BulletType } from '../data/towers';
import type { Enemy } from './enemy';

const MISSILE_TURN_RATE = 0.15; // radians per tick
const MAX_LIFETIME = 6 * TICK_RATE;

let nextId = 1;

export interface BulletInit {
  x: number;
  y: number;
  angle: number;
  speed: number;
  damage: number;
  type: BulletType;
  hitsAir: boolean;
  hitsGround: boolean;
  target?: Enemy | null;
  /** Shells: where to explode. */
  aim?: { x: number; y: number };
  splash?: number;
}

export type BulletResult =
  | { kind: 'hit'; enemy: Enemy }
  | { kind: 'explode'; x: number; y: number; radius: number };

export class Bullet {
  readonly id = nextId++;
  x: number;
  y: number;
  prevX: number;
  prevY: number;
  angle: number;
  readonly speed: number;
  readonly damage: number;
  readonly type: BulletType;
  readonly radius: number;
  readonly hitsAir: boolean;
  readonly hitsGround: boolean;
  readonly splash: number;
  target: Enemy | null;
  /** Shells: total flight distance and progress, for the arc drawn by the view. */
  readonly flight: number;
  travelled = 0;
  age = 0;
  alive = true;

  constructor(init: BulletInit) {
    this.x = this.prevX = init.x;
    this.y = this.prevY = init.y;
    this.angle = init.angle;
    this.speed = init.speed;
    this.damage = init.damage;
    this.type = init.type;
    this.hitsAir = init.hitsAir;
    this.hitsGround = init.hitsGround;
    this.splash = init.splash ?? 0;
    this.target = init.target ?? null;
    this.radius = this.type === 'normal' ? 2.5 : 4;
    this.flight = init.aim ? Math.hypot(init.aim.x - init.x, init.aim.y - init.y) : 0;
  }

  /** Moves the bullet; returns what happened this tick, if anything. */
  update(enemies: readonly Enemy[]): BulletResult | null {
    this.prevX = this.x;
    this.prevY = this.y;
    this.age++;

    // Missiles steer towards their target while it's alive, then fly straight.
    if (this.type === 'missile' && this.target?.alive) {
      const want = Math.atan2(this.target.y - this.y, this.target.x - this.x);
      const diff = Math.atan2(Math.sin(want - this.angle), Math.cos(want - this.angle));
      this.angle += Math.max(-MISSILE_TURN_RATE, Math.min(MISSILE_TURN_RATE, diff));
    }

    // Shells fly over everything and burst at their aim point.
    if (this.type === 'shell') {
      const step = Math.min(this.speed, this.flight - this.travelled);
      this.x += Math.cos(this.angle) * step;
      this.y += Math.sin(this.angle) * step;
      this.travelled += step;
      if (this.travelled >= this.flight - 1e-6) {
        this.alive = false;
        return { kind: 'explode', x: this.x, y: this.y, radius: this.splash };
      }
      return null;
    }

    this.x += Math.cos(this.angle) * this.speed;
    this.y += Math.sin(this.angle) * this.speed;

    const hit = this.findHit(enemies);
    if (hit) {
      this.alive = false;
      return { kind: 'hit', enemy: hit };
    }
    if (this.age > MAX_LIFETIME || this.x < -50 || this.x > FIELD_W + 50 ||
        this.y < -50 || this.y > FIELD_H + 50) {
      this.alive = false;
    }
    return null;
  }

  canHit(e: Enemy): boolean {
    return e.alive && (e.flying ? this.hitsAir : this.hitsGround);
  }

  /**
   * Swept collision: tests the whole segment travelled during this tick, so
   * fast bullets can't tunnel through enemies. Returns the first enemy hit.
   */
  findHit(enemies: readonly Enemy[]): Enemy | null {
    const sx = this.prevX, sy = this.prevY;
    const dx = this.x - sx, dy = this.y - sy;
    const len2 = dx * dx + dy * dy;
    let best: Enemy | null = null;
    let bestT = Infinity;
    for (const e of enemies) {
      if (!this.canHit(e)) continue;
      const r = e.radius + this.radius;
      let t = len2 > 0 ? ((e.x - sx) * dx + (e.y - sy) * dy) / len2 : 0;
      t = Math.max(0, Math.min(1, t));
      const px = sx + dx * t - e.x, py = sy + dy * t - e.y;
      if (px * px + py * py <= r * r && t < bestT) {
        best = e;
        bestT = t;
      }
    }
    return best;
  }
}
