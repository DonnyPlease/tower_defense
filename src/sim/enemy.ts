import { TICK_RATE } from '../config';
import { enemyDef, type EnemyDef, type EnemyType } from '../data/enemies';
import type { Nav } from './nav';

const SHIELD_DELAY = 3 * TICK_RATE; // ticks without damage before the shield recharges
const SHIELD_REGEN = 0.25 / TICK_RATE; // fraction of max shield per tick
const MIN_DAMAGE_FRACTION = 0.25; // armor never blocks more than 75 % of a hit

let nextId = 1;

export class Enemy {
  readonly id = nextId++;
  readonly def: EnemyDef;
  readonly radius: number;
  readonly maxHitpoints: number;
  readonly maxShield: number;
  hitpoints: number;
  shield: number;

  x: number;
  y: number;
  prevX: number; // position at the previous tick, for render interpolation
  prevY: number;
  vx = 0; // displacement during the last tick, used for aim prediction
  vy = 0;
  angle: number; // smoothed heading, for drawing
  prevAngle: number;
  remaining = Infinity; // path length left to the exit, used for "first"/"last" targeting
  alive = true;
  escaped = false;

  slow = 0; // current speed reduction 0..1
  hitFlash = 0; // ticks left of the white "got hit" flash
  abilityTimer = 0; // ticks until the next heal / summon

  private slowTicks = 0;
  private shieldCooldown = 0;

  constructor(readonly type: EnemyType, readonly nav: Nav, hpMultiplier = 1) {
    this.def = enemyDef(type);
    this.radius = this.def.radius;
    this.maxHitpoints = Math.round(this.def.hitpoints * hpMultiplier);
    this.hitpoints = this.maxHitpoints;
    this.maxShield = Math.round((this.def.shield ?? 0) * hpMultiplier);
    this.shield = this.maxShield;
    this.x = this.prevX = nav.x;
    this.y = this.prevY = nav.y;
    this.angle = this.prevAngle = nav.heading;
    const ability = this.def.heal?.interval ?? this.def.summon?.interval ?? 0;
    this.abilityTimer = Math.round(ability * TICK_RATE);
    this.remaining = nav.remaining();
  }

  get flying(): boolean {
    return this.def.flying ?? false;
  }

  get speed(): number {
    return this.def.speed * (1 - this.slow);
  }

  /** Walks along the path (the Nav decides how). */
  update(): void {
    this.prevX = this.x;
    this.prevY = this.y;
    this.prevAngle = this.angle;
    if (this.hitFlash > 0) this.hitFlash--;
    if (this.slowTicks > 0 && --this.slowTicks === 0) this.slow = 0;
    if (this.maxShield > 0) {
      if (this.shieldCooldown > 0) this.shieldCooldown--;
      else this.shield = Math.min(this.maxShield, this.shield + this.maxShield * SHIELD_REGEN);
    }

    if (!this.nav.move(this.speed)) {
      this.alive = false;
      this.escaped = true;
    }
    this.x = this.nav.x;
    this.y = this.nav.y;
    this.vx = this.x - this.prevX;
    this.vy = this.y - this.prevY;
    this.remaining = this.nav.remaining();

    // Turn the sprite smoothly instead of snapping at corners.
    const diff = Math.atan2(Math.sin(this.nav.heading - this.angle), Math.cos(this.nav.heading - this.angle));
    this.angle += diff * 0.25;
  }

  applySlow(amount: number, ticks: number): void {
    if (this.flying) return;
    this.slow = Math.max(this.slow, amount);
    this.slowTicks = Math.max(this.slowTicks, ticks);
  }

  heal(amount: number): number {
    const before = this.hitpoints;
    this.hitpoints = Math.min(this.maxHitpoints, this.hitpoints + amount);
    return this.hitpoints - before;
  }

  /** Applies damage through armor and shield. Returns true when this hit killed the enemy. */
  hit(damage: number, opts: { ignoresArmor?: boolean; flash?: boolean } = {}): boolean {
    if (!this.alive || damage <= 0) return false;
    let dmg = damage;
    const armor = this.def.armor ?? 0;
    if (armor > 0 && !opts.ignoresArmor) dmg = Math.max(dmg * MIN_DAMAGE_FRACTION, dmg - armor);
    if (this.maxShield > 0) {
      this.shieldCooldown = SHIELD_DELAY;
      const absorbed = Math.min(this.shield, dmg);
      this.shield -= absorbed;
      dmg -= absorbed;
    }
    if (opts.flash ?? true) this.hitFlash = 4;
    this.hitpoints -= dmg;
    if (this.hitpoints <= 0) {
      this.hitpoints = 0;
      this.alive = false;
      return true;
    }
    return false;
  }
}
