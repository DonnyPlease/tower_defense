import { TILE, TOWERS, TICK_RATE, SELL_REFUND } from './config.js';
import { Bullet } from './bullet.js';

const ANIMATION_FRAMES = 7;
const ANIMATION_SPEED = 0.35; // frames per tick while shooting
const MUZZLE = 16; // distance from tower centre where bullets appear

// Angle to shoot at so that a bullet with `speed` meets an enemy moving with
// constant velocity (vx, vy). Solves |d + v*t| = speed*t for the smallest t > 0.
// Falls back to aiming straight at the enemy when no solution exists.
export function leadAngle(fromX, fromY, enemy, speed) {
  const dx = enemy.x - fromX, dy = enemy.y - fromY;
  const a = enemy.vx * enemy.vx + enemy.vy * enemy.vy - speed * speed;
  const b = 2 * (dx * enemy.vx + dy * enemy.vy);
  const c = dx * dx + dy * dy;
  let t = -1;
  if (Math.abs(a) < 1e-9) {
    if (Math.abs(b) > 1e-9) t = -c / b;
  } else {
    const disc = b * b - 4 * a * c;
    if (disc >= 0) {
      const s = Math.sqrt(disc);
      const t1 = (-b - s) / (2 * a), t2 = (-b + s) / (2 * a);
      t = Math.min(t1, t2) > 0 ? Math.min(t1, t2) : Math.max(t1, t2);
    }
  }
  if (t <= 0) return Math.atan2(dy, dx);
  return Math.atan2(dy + enemy.vy * t, dx + enemy.vx * t);
}

export class Tower {
  constructor(kind, col, row) {
    const def = TOWERS[kind];
    if (!def) throw new Error(`Unknown tower kind "${kind}"`);
    this.kind = kind;
    this.def = def;
    this.col = col;
    this.row = row;
    this.x = col * TILE + TILE / 2;
    this.y = row * TILE + TILE / 2;
    this.angle = this.prevAngle = -Math.PI / 2; // pointing up
    this.cooldown = 0; // ticks until the next shot is allowed
    this.frame = 0; // animation frame (fractional)
    this.shooting = false;
    this.target = null;
  }

  inRange(enemy) {
    const r = this.def.range + enemy.radius;
    const dx = enemy.x - this.x, dy = enemy.y - this.y;
    return dx * dx + dy * dy <= r * r;
  }

  // Targets the enemy that is furthest along the path (the most dangerous one).
  pickTarget(enemies) {
    let best = null;
    for (const e of enemies) {
      if (e.alive && this.inRange(e) && (!best || e.distance > best.distance)) best = e;
    }
    return best;
  }

  // Returns a new Bullet when the tower fires this tick, otherwise null.
  update(enemies) {
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

  get sellValue() {
    return Math.floor(this.def.cost * SELL_REFUND);
  }
}
