import { TILE, TOWERS, TICK_RATE, SELL_REFUND, type TowerDef, type TowerKind } from '../config';
import { Bullet } from './bullet';
import type { Enemy } from './enemy';

export const ANIMATION_FRAMES = 7;
const ANIMATION_SPEED = 0.35; // frames per tick while shooting
const MUZZLE = 16; // distance from the tower centre where bullets appear

interface Moving {
  x: number;
  y: number;
  vx: number;
  vy: number;
}

/**
 * Angle to shoot at so that a bullet with `speed` meets a target moving with
 * constant velocity (vx, vy): solves |d + v*t| = speed*t for the smallest t > 0.
 * Falls back to aiming straight at the target when no solution exists.
 */
export function leadAngle(fromX: number, fromY: number, target: Moving, speed: number): number {
  const dx = target.x - fromX, dy = target.y - fromY;
  const a = target.vx * target.vx + target.vy * target.vy - speed * speed;
  const b = 2 * (dx * target.vx + dy * target.vy);
  const c = dx * dx + dy * dy;
  let t = -1;
  if (Math.abs(a) < 1e-9) {
    if (Math.abs(b) > 1e-9) t = -c / b;
  } else {
    const disc = b * b - 4 * a * c;
    if (disc >= 0) {
      const s = Math.sqrt(disc);
      const t1 = (-b - s) / (2 * a), t2 = (-b + s) / (2 * a);
      const lo = Math.min(t1, t2), hi = Math.max(t1, t2);
      t = lo > 0 ? lo : hi;
    }
  }
  if (t <= 0) return Math.atan2(dy, dx);
  return Math.atan2(dy + target.vy * t, dx + target.vx * t);
}

let nextId = 1;

export class Tower {
  readonly id = nextId++;
  readonly def: TowerDef;
  readonly x: number;
  readonly y: number;
  angle = -Math.PI / 2; // pointing up
  prevAngle = -Math.PI / 2;
  cooldown = 0; // ticks until the next shot is allowed
  frame = 0; // animation frame (fractional)
  shooting = false;
  target: Enemy | null = null;

  constructor(readonly kind: TowerKind, readonly col: number, readonly row: number) {
    this.def = TOWERS[kind];
    this.x = col * TILE + TILE / 2;
    this.y = row * TILE + TILE / 2;
  }

  get sellValue(): number {
    return Math.floor(this.def.cost * SELL_REFUND);
  }

  inRange(enemy: Enemy): boolean {
    const r = this.def.range + enemy.radius;
    const dx = enemy.x - this.x, dy = enemy.y - this.y;
    return dx * dx + dy * dy <= r * r;
  }

  /** Targets the enemy that is furthest along the path (the most dangerous one). */
  pickTarget(enemies: readonly Enemy[]): Enemy | null {
    let best: Enemy | null = null;
    for (const e of enemies) {
      if (e.alive && this.inRange(e) && (!best || e.distance > best.distance)) best = e;
    }
    return best;
  }

  /** Returns a new Bullet when the tower fires this tick, otherwise null. */
  update(enemies: readonly Enemy[]): Bullet | null {
    this.prevAngle = this.angle;
    if (this.cooldown > 0) this.cooldown--;
    if (this.shooting) {
      this.frame += ANIMATION_SPEED;
      if (this.frame >= ANIMATION_FRAMES) {
        this.frame = 0;
        this.shooting = false;
      }
    }

    this.target = this.pickTarget(enemies);
    if (!this.target) return null;

    this.angle = this.def.bulletType === 'missile'
      ? Math.atan2(this.target.y - this.y, this.target.x - this.x)
      : leadAngle(this.x, this.y, this.target, this.def.bulletSpeed);

    if (this.cooldown > 0) return null;
    this.cooldown = Math.round(TICK_RATE / this.def.fireRate);
    this.shooting = true;
    this.frame = 0;
    return new Bullet({
      x: this.x + Math.cos(this.angle) * MUZZLE,
      y: this.y + Math.sin(this.angle) * MUZZLE,
      angle: this.angle,
      speed: this.def.bulletSpeed,
      damage: this.def.damage,
      type: this.def.bulletType,
      target: this.target,
    });
  }
}
