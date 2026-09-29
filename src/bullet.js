import { FIELD_W, FIELD_H, TICK_RATE } from './config.js';

const MISSILE_TURN_RATE = 0.15; // radians per tick
const MAX_LIFETIME = 6 * TICK_RATE;

export class Bullet {
  constructor({ x, y, angle, speed, damage, type, target = null }) {
    this.x = this.prevX = x;
    this.y = this.prevY = y;
    this.angle = angle;
    this.speed = speed;
    this.damage = damage;
    this.type = type; // 'normal' | 'missile'
    this.target = target;
    this.radius = type === 'missile' ? 4 : 2.5;
    this.age = 0;
    this.alive = true;
  }

  update(enemies) {
    this.prevX = this.x;
    this.prevY = this.y;
    this.age++;

    // Missiles steer towards their target while it's alive, then fly straight.
    if (this.type === 'missile' && this.target?.alive) {
      const want = Math.atan2(this.target.y - this.y, this.target.x - this.x);
      let diff = want - this.angle;
      diff = Math.atan2(Math.sin(diff), Math.cos(diff));
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

  // Swept collision: tests the whole segment travelled during this tick, so
  // fast bullets can't tunnel through enemies. Returns the first enemy hit.
  findHit(enemies) {
    const sx = this.prevX, sy = this.prevY;
    const dx = this.x - sx, dy = this.y - sy;
    const len2 = dx * dx + dy * dy;
    let best = null, bestT = Infinity;
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
