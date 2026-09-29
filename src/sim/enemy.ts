import { ENEMIES, type EnemyDef, type EnemyType } from '../config';
import type { Point } from './map';

let nextId = 1;

export class Enemy {
  readonly id = nextId++;
  readonly def: EnemyDef;
  readonly speed: number;
  readonly radius: number;
  readonly maxHitpoints: number;
  readonly reward: number;
  hitpoints: number;

  x: number;
  y: number;
  prevX: number; // position at the previous tick, for render interpolation
  prevY: number;
  vx = 0; // displacement during the last tick, used for aim prediction
  vy = 0;
  angle: number; // smoothed heading, for drawing
  prevAngle: number;
  distance = 0; // total distance travelled, used for "first" targeting
  alive = true;
  escaped = false;

  private heading: number;
  private waypoint = 1; // index of the waypoint we're heading to

  constructor(readonly type: EnemyType, private readonly route: Point[], hpMultiplier = 1) {
    this.def = ENEMIES[type];
    this.speed = this.def.speed;
    this.radius = this.def.radius;
    this.maxHitpoints = Math.round(this.def.hitpoints * hpMultiplier);
    this.hitpoints = this.maxHitpoints;
    this.reward = this.def.reward;
    this.x = this.prevX = route[0].x;
    this.y = this.prevY = route[0].y;
    this.heading = Math.atan2(route[1].y - route[0].y, route[1].x - route[0].x);
    this.angle = this.prevAngle = this.heading;
  }

  /** Moves along the route; leftover movement carries over corners. */
  update(): void {
    this.prevX = this.x;
    this.prevY = this.y;
    this.prevAngle = this.angle;

    let step = this.speed;
    while (step > 0 && this.waypoint < this.route.length) {
      const target = this.route[this.waypoint];
      const dx = target.x - this.x, dy = target.y - this.y;
      const d = Math.hypot(dx, dy);
      if (d <= step) {
        this.x = target.x;
        this.y = target.y;
        step -= d;
        this.distance += d;
        this.waypoint++;
      } else {
        this.x += (dx / d) * step;
        this.y += (dy / d) * step;
        this.distance += step;
        this.heading = Math.atan2(dy, dx);
        step = 0;
      }
    }
    this.vx = this.x - this.prevX;
    this.vy = this.y - this.prevY;

    // Turn the sprite smoothly instead of snapping at corners.
    const diff = Math.atan2(Math.sin(this.heading - this.angle), Math.cos(this.heading - this.angle));
    this.angle += diff * 0.25;

    if (this.waypoint >= this.route.length) {
      this.alive = false;
      this.escaped = true;
    }
  }

  /** Returns true when this hit killed the enemy. */
  hit(damage: number): boolean {
    if (!this.alive) return false;
    this.hitpoints -= damage;
    if (this.hitpoints <= 0) {
      this.alive = false;
      return true;
    }
    return false;
  }
}
