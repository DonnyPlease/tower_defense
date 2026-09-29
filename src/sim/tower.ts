import { TILE, TICK_RATE, SELL_REFUND, HIGH_GROUND_RANGE } from '../config';
import { towerDef, type TowerDef, type TowerKind, type TowerLevel, type TargetMode } from '../data/towers';
import { Bullet } from './bullet';
import type { Enemy } from './enemy';

const ANIMATION_SPEED = 0.35; // frames per tick while shooting
const MUZZLE = 16; // distance from the tower centre where bullets appear
const LASER_MAX_HEAT = 2; // extra damage multiplier at full heat (so up to 3x)
const LASER_HEAT_TIME = 2 * TICK_RATE; // ticks on one target to reach full heat
const SLOW_TICKS = 12; // frost slow lingers this long after leaving the aura

interface Moving {
  x: number;
  y: number;
  vx: number;
  vy: number;
}

/**
 * Time (in ticks) until a projectile with `speed` fired from (fromX, fromY)
 * meets a target moving with constant velocity: solves |d + v*t| = speed*t
 * for the smallest t > 0. Returns -1 if there is no solution.
 */
function interceptTime(fromX: number, fromY: number, target: Moving, speed: number): number {
  const dx = target.x - fromX, dy = target.y - fromY;
  const a = target.vx * target.vx + target.vy * target.vy - speed * speed;
  const b = 2 * (dx * target.vx + dy * target.vy);
  const c = dx * dx + dy * dy;
  if (Math.abs(a) < 1e-9) return Math.abs(b) > 1e-9 ? -c / b : -1;
  const disc = b * b - 4 * a * c;
  if (disc < 0) return -1;
  const s = Math.sqrt(disc);
  const t1 = (-b - s) / (2 * a), t2 = (-b + s) / (2 * a);
  const lo = Math.min(t1, t2), hi = Math.max(t1, t2);
  return lo > 0 ? lo : hi;
}

/** Point where a projectile should be aimed to hit a moving target. */
export function leadPoint(fromX: number, fromY: number, target: Moving, speed: number): { x: number; y: number } {
  const t = interceptTime(fromX, fromY, target, speed);
  if (t <= 0) return { x: target.x, y: target.y };
  return { x: target.x + target.vx * t, y: target.y + target.vy * t };
}

/** Angle to shoot at so that the projectile meets the moving target. */
export function leadAngle(fromX: number, fromY: number, target: Moving, speed: number): number {
  const p = leadPoint(fromX, fromY, target, speed);
  return Math.atan2(p.y - fromY, p.x - fromX);
}

/** What a tower can do to the world during its update. */
export interface TowerContext {
  enemies: readonly Enemy[];
  damageMultiplier: number;
  damage(enemy: Enemy, amount: number, opts: { ignoresArmor?: boolean; flash?: boolean }): void;
  fire(bullet: Bullet, from: Tower): void;
  pulse(tower: Tower): void; // frost aura pulse, for effects
}

let nextId = 1;

export class Tower {
  readonly id = nextId++;
  readonly def: TowerDef;
  readonly x: number;
  readonly y: number;
  readonly highGround: boolean;
  level = 0; // 0..2
  targetMode: TargetMode = 'first';
  invested: number; // money spent on this tower, for the sell refund
  angle = -Math.PI / 2; // pointing up
  prevAngle = -Math.PI / 2;
  cooldown = 0; // ticks until the next shot is allowed
  frame = 0; // animation frame (fractional)
  shooting = false;
  target: Enemy | null = null;
  buff = 0; // fire-rate bonus from nearby beacons, set by the world every tick
  heat = 0; // laser: ticks spent on the current target

  constructor(readonly kind: TowerKind, readonly col: number, readonly row: number,
    opts: { highGround?: boolean; invested?: number } = {}) {
    this.def = towerDef(kind);
    this.x = col * TILE + TILE / 2;
    this.y = row * TILE + TILE / 2;
    this.highGround = opts.highGround ?? false;
    this.invested = opts.invested ?? this.def.levels[0].cost;
  }

  get stats(): TowerLevel {
    return this.def.levels[this.level];
  }

  get range(): number {
    return this.stats.range * (this.highGround ? HIGH_GROUND_RANGE : 1);
  }

  get fireRate(): number {
    return this.stats.fireRate * (1 + this.buff);
  }

  get maxLevel(): boolean {
    return this.level >= this.def.levels.length - 1;
  }

  /** Base price of the next upgrade, or null at max level. */
  get upgradeCost(): number | null {
    return this.maxLevel ? null : this.def.levels[this.level + 1].cost;
  }

  get sellValue(): number {
    return Math.floor(this.invested * SELL_REFUND);
  }

  /** Laser heat as 0..1. */
  get heatFraction(): number {
    return Math.min(1, this.heat / LASER_HEAT_TIME);
  }

  canTarget(e: Enemy): boolean {
    return e.alive && (e.flying ? this.def.hitsAir : this.def.hitsGround);
  }

  inRange(e: { x: number; y: number; radius: number }, range = this.range): boolean {
    const r = range + e.radius;
    const dx = e.x - this.x, dy = e.y - this.y;
    return dx * dx + dy * dy <= r * r;
  }

  pickTarget(enemies: readonly Enemy[]): Enemy | null {
    let best: Enemy | null = null;
    let bestScore = -Infinity;
    for (const e of enemies) {
      if (!this.canTarget(e) || !this.inRange(e)) continue;
      let score: number;
      switch (this.targetMode) {
        case 'first': score = -e.remaining; break;
        case 'last': score = e.remaining; break;
        case 'strongest': score = e.hitpoints + e.shield; break;
        case 'closest': score = -Math.hypot(e.x - this.x, e.y - this.y); break;
      }
      if (score > bestScore) {
        best = e;
        bestScore = score;
      }
    }
    return best;
  }

  update(ctx: TowerContext): void {
    this.prevAngle = this.angle;
    if (this.cooldown > 0) this.cooldown--;
    if (this.shooting) {
      this.frame += ANIMATION_SPEED;
      if (this.frame >= this.def.frames) {
        this.frame = 0;
        this.shooting = false;
      }
    }
    switch (this.def.behavior) {
      case 'projectile': return this.updateProjectile(ctx);
      case 'beam': return this.updateBeam(ctx);
      case 'aura': return this.updateAura(ctx);
      case 'support': return; // handled by the world (buffs)
    }
  }

  private startShot(): void {
    this.cooldown = Math.round(TICK_RATE / this.fireRate);
    this.shooting = true;
    this.frame = 0;
  }

  private updateProjectile(ctx: TowerContext): void {
    this.target = this.pickTarget(ctx.enemies);
    if (!this.target) return;
    const speed = this.def.bulletSpeed ?? 10;
    const aim = this.def.bullet === 'missile'
      ? { x: this.target.x, y: this.target.y }
      : leadPoint(this.x, this.y, this.target, speed);
    this.angle = Math.atan2(aim.y - this.y, aim.x - this.x);
    if (this.cooldown > 0) return;
    this.startShot();
    ctx.fire(new Bullet({
      x: this.x + Math.cos(this.angle) * MUZZLE,
      y: this.y + Math.sin(this.angle) * MUZZLE,
      angle: this.angle,
      speed,
      damage: this.stats.damage * ctx.damageMultiplier,
      type: this.def.bullet ?? 'normal',
      hitsAir: this.def.hitsAir,
      hitsGround: this.def.hitsGround,
      target: this.target,
      aim,
      splash: this.stats.splash,
    }), this);
  }

  private updateBeam(ctx: TowerContext): void {
    const previous = this.target;
    // Keep burning the same target while it stays in range, to build heat.
    this.target = previous && this.canTarget(previous) && this.inRange(previous)
      ? previous
      : this.pickTarget(ctx.enemies);
    if (!this.target) {
      this.heat = 0;
      return;
    }
    this.heat = this.target === previous ? this.heat + 1 : 0;
    this.angle = Math.atan2(this.target.y - this.y, this.target.x - this.x);
    const perTick = (this.stats.damage * (1 + this.buff) * ctx.damageMultiplier) / TICK_RATE;
    ctx.damage(this.target, perTick * (1 + LASER_MAX_HEAT * this.heatFraction),
      { ignoresArmor: this.def.ignoresArmor, flash: false });
  }

  private updateAura(ctx: TowerContext): void {
    const slow = this.stats.slow ?? 0;
    let any = false;
    for (const e of ctx.enemies) {
      if (!this.canTarget(e) || !this.inRange(e)) continue;
      e.applySlow(slow, SLOW_TICKS);
      any = true;
    }
    if (!any || this.cooldown > 0) return;
    this.startShot();
    ctx.pulse(this);
    for (const e of ctx.enemies) {
      if (this.canTarget(e) && this.inRange(e)) ctx.damage(e, this.stats.damage * ctx.damageMultiplier, {});
    }
  }
}
