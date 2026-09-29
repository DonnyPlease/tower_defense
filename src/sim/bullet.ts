import { FIELD_W, FIELD_H, TICK_RATE, type BulletType } from '../config';
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
  target?: Enemy | null;
}

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
  target: Enemy | null;
  age = 0;
  alive = true;

  constructor(init: BulletInit) {
    this.x = this.prevX = init.x;
    this.y = this.prevY = init.y;
    this.angle = init.angle;
    this.speed = init.speed;
    this.damage = init.damage;
    this.type = init.type;
    this.target = init.target ?? null;
    this.radius = this.type === 'missile' ? 4 : 2.5;
  }

  /** Moves the bullet; returns the enemy it hit this tick, if any. */
  update(enemies: readonly Enemy[]): Enemy | null {
    this.prevX = this.x;
    this.prevY = this.y;
    this.age++;

    // Missiles steer towards their target while it's alive, then fly straight.
    if (this.type === 'missile' && this.target?.alive) {
      const want = Math.atan2(this.target.y - this.y, this.target.x - this.x);
      const diff = Math.atan2(Math.sin(want - this.angle), Math.cos(want - this.angle));
      this.angle += Math.max(-MISSILE_TURN_RATE, Math.min(MISSILE_TURN_RATE, diff));
    }
    this.x += Math.cos(this.angle) * this.speed;
    this.y += Math.sin(this.angle) * this.speed;

    const hit = this.findHit(enemies);
    if (hit) {
      this.alive = false;
      return hit;
    }
    if (this.age > MAX_LIFETIME || this.x < -50 || this.x > FIELD_W + 50 ||
        this.y < -50 || this.y > FIELD_H + 50) {
      this.alive = false;
    }
    return null;
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
      if (!e.alive) continue;
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
