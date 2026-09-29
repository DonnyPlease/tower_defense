import { ENEMIES } from './config.js';

let nextId = 1;

export class Enemy {
  constructor(type, route, hpMultiplier = 1) {
    const def = ENEMIES[type];
    if (!def) throw new Error(`Unknown enemy type "${type}"`);
    this.id = nextId++;
    this.type = type;
    this.def = def;
    this.speed = def.speed;
    this.radius = def.radius;
    this.maxHitpoints = Math.round(def.hitpoints * hpMultiplier);
    this.hitpoints = this.maxHitpoints;
    this.reward = def.reward;

    this.route = route;
    this.waypoint = 1; // index of the waypoint we're heading to
    this.x = this.prevX = route[0].x;
    this.y = this.prevY = route[0].y;
    this.vx = 0; // displacement during the last tick, used for aim prediction
    this.vy = 0;
    this.heading = Math.atan2(route[1].y - route[0].y, route[1].x - route[0].x);
    this.angle = this.prevAngle = this.heading; // smoothed, for drawing
    this.distance = 0; // total distance travelled, used for "first" targeting
    this.alive = true;
    this.escaped = false;
  }

  // Moves along the route. Leftover movement carries over corners so the
  // speed stays constant.
  update() {
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
    let diff = this.heading - this.angle;
    diff = Math.atan2(Math.sin(diff), Math.cos(diff));
    this.angle += diff * 0.25;

    if (this.waypoint >= this.route.length) {
      this.alive = false;
      this.escaped = true;
    }
  }

  // Returns true when this hit killed the enemy.
  hit(damage) {
    if (!this.alive) return false;
    this.hitpoints -= damage;
    if (this.hitpoints <= 0) {
      this.alive = false;
      return true;
    }
    return false;
  }
}
