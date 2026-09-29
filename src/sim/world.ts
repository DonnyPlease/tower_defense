import {
  TILE, TICK_RATE, WAVE_HP_GROWTH, ENDLESS_HP_GROWTH, INTEREST_RATE, interestCap, waveBonus, earlyBonus,
} from '../config';
import { towerDef, TOWER_KINDS, type TowerKind, type TargetMode, type BulletType } from '../data/towers';
import { enemyDef, type EnemyType } from '../data/enemies';
import type { Wave } from '../data/levels';
import { NO_MODIFIERS, type Modifiers } from '../data/perks';
import { GameMap, type DistanceField, type MapSource, type Tile } from './map';
import { FlowNav, RouteNav, type Nav } from './nav';
import { Enemy } from './enemy';
import { Tower, type TowerContext } from './tower';
import type { Bullet } from './bullet';

export type GameStatus = 'playing' | 'won' | 'lost';

/** Things that happened during a tick; the view drains them for effects and sound. */
export type WorldEvent =
  | { type: 'build'; x: number; y: number; kind: TowerKind }
  | { type: 'upgrade'; x: number; y: number; level: number }
  | { type: 'sell'; x: number; y: number; amount: number }
  | { type: 'shot'; x: number; y: number; kind: TowerKind }
  | { type: 'hit'; x: number; y: number; bullet: BulletType }
  | { type: 'explode'; x: number; y: number; radius: number }
  | { type: 'pulse'; x: number; y: number; radius: number }
  | { type: 'kill'; x: number; y: number; amount: number; enemy: EnemyType }
  | { type: 'leak'; x: number; y: number; amount: number }
  | { type: 'heal'; x: number; y: number; radius: number }
  | { type: 'summon'; x: number; y: number }
  | { type: 'waveStarted'; wave: number; early: number }
  | { type: 'waveCleared'; wave: number; bonus: number; interest: number }
  | { type: 'won' }
  | { type: 'lost' };

export interface LevelSource extends MapSource {
  id: string;
  money: number;
  lives: number;
  waves?: Wave[];
}

export interface WorldOptions {
  /** Endless mode: waves come from this generator and never run out. */
  endlessWaves?: (index: number) => Wave;
  modifiers?: Modifiers;
  /** Towers the player may build (default: all). */
  unlocked?: readonly TowerKind[];
}

/** Everything needed to resume a game between waves. */
export interface WorldSnapshot {
  v: 1;
  levelId: string;
  endless: boolean;
  money: number;
  lives: number;
  waveIndex: number;
  wavesCleared: number;
  towers: { kind: TowerKind; col: number; row: number; level: number; targetMode: TargetMode; invested: number }[];
}

type BlockReason = 'terrain' | 'occupied' | 'enemy' | 'blocks-path' | null;

/**
 * The whole game simulation for one level. It knows nothing about rendering
 * or input, so it can run headless (see tests/).
 */
export class World {
  readonly map: GameMap;
  readonly levelId: string;
  readonly endless: boolean;
  readonly modifiers: Modifiers;
  readonly unlocked: ReadonlySet<TowerKind>;
  readonly startLives: number;
  money: number;
  lives: number;
  tick = 0;
  enemies: Enemy[] = [];
  towers: Tower[] = [];
  bullets: Bullet[] = [];
  waveIndex = -1; // index of the last started wave
  wavesCleared = 0;
  kills = 0;
  status: GameStatus = 'playing';
  events: WorldEvent[] = [];

  private readonly staticWaves: Wave[];
  private readonly endlessWaves: ((index: number) => Wave) | null;
  private readonly waveCache = new Map<number, Wave>();
  private spawnQueue: { tick: number; type: EnemyType }[] = [];
  private pendingBonus = 0;
  private spawnCounter = 0;
  private flow: DistanceField;

  constructor(level: LevelSource, opts: WorldOptions = {}) {
    this.map = new GameMap(level);
    this.levelId = level.id;
    this.modifiers = opts.modifiers ?? NO_MODIFIERS;
    this.unlocked = new Set(opts.unlocked ?? TOWER_KINDS);
    this.endlessWaves = opts.endlessWaves ?? null;
    this.endless = this.endlessWaves !== null;
    this.staticWaves = level.waves ?? [];
    this.money = level.money + this.modifiers.money;
    this.lives = this.startLives = level.lives + this.modifiers.lives;
    this.flow = this.map.distanceField((c, r) => this.towerAt(c, r) !== null);
  }

  // ---- waves ---------------------------------------------------------------

  /** Number of waves, or null in endless mode. */
  get totalWaves(): number | null {
    return this.endless ? null : this.staticWaves.length;
  }

  waveAt(index: number): Wave | null {
    if (!this.endlessWaves) return this.staticWaves[index] ?? null;
    let wave = this.waveCache.get(index);
    if (!wave) {
      wave = this.endlessWaves(index);
      this.waveCache.set(index, wave);
    }
    return wave;
  }

  get nextWave(): Wave | null {
    return this.waveAt(this.waveIndex + 1);
  }

  /** Enemies of the current wave still waiting to spawn. */
  get spawning(): boolean {
    return this.spawnQueue.length > 0;
  }

  get waveInProgress(): boolean {
    return this.spawning || this.enemies.length > 0;
  }

  /** The next wave may start once the current one has fully spawned. */
  get canStartWave(): boolean {
    return this.status === 'playing' && !this.spawning && this.nextWave !== null;
  }

  /** Bonus paid for calling the next wave right now (0 if the field is clear). */
  get earlyBonusNow(): number {
    return this.enemies.length > 0 ? earlyBonus(this.waveIndex + 1) : 0;
  }

  get enemiesRemaining(): number {
    return this.spawnQueue.length + this.enemies.length;
  }

  get hpMultiplier(): number {
    const i = Math.max(0, this.waveIndex);
    // Endless waves also get tougher quadratically, so every run ends eventually.
    return 1 + WAVE_HP_GROWTH * i + (this.endless ? ENDLESS_HP_GROWTH * i * i : 0);
  }

  // ---- queries -------------------------------------------------------------

  towerAt(col: number, row: number): Tower | null {
    return this.towers.find((t) => t.col === col && t.row === row) ?? null;
  }

  isUnlocked(kind: TowerKind): boolean {
    return this.unlocked.has(kind);
  }

  costOf(kind: TowerKind): number {
    return Math.round(towerDef(kind).levels[0].cost * this.modifiers.costMultiplier);
  }

  upgradeCostOf(tower: Tower): number | null {
    const base = tower.upgradeCost;
    return base === null ? null : Math.round(base * this.modifiers.costMultiplier);
  }

  canAfford(kind: TowerKind): boolean {
    return this.money >= this.costOf(kind);
  }

  buildBlockReason(col: number, row: number): BlockReason {
    if (!this.map.isBuildableTerrain(col, row)) return 'terrain';
    if (this.towerAt(col, row)) return 'occupied';
    if (!this.map.maze) return null;

    // Maze levels: never trap enemies or cut off the exit.
    for (const e of this.enemies) {
      if (e.flying) continue;
      const t = e.nav.targetTile;
      if ((Math.floor(e.x / TILE) === col && Math.floor(e.y / TILE) === row) ||
          (t && t.col === col && t.row === row)) return 'enemy';
    }
    const field = this.map.distanceField((c, r) => (c === col && r === row) || this.towerAt(c, r) !== null);
    const reachable = (t: Tile) => Number.isFinite(field[t.row][t.col]);
    if (!this.map.starts.every(reachable)) return 'blocks-path';
    for (const e of this.enemies) {
      const t = e.nav.targetTile;
      if (!e.flying && t && !reachable(t)) return 'blocks-path';
    }
    return null;
  }

  canBuildAt(col: number, row: number): boolean {
    return this.buildBlockReason(col, row) === null;
  }

  /** Current distance field (maze levels), for drawing the enemy path. */
  get distanceField(): DistanceField {
    return this.flow;
  }

  // ---- player actions ------------------------------------------------------

  build(kind: TowerKind, col: number, row: number): Tower | null {
    if (this.status !== 'playing' || !this.isUnlocked(kind) || !this.canAfford(kind) ||
        !this.canBuildAt(col, row)) return null;
    const cost = this.costOf(kind);
    const tower = new Tower(kind, col, row, { highGround: this.map.isHighGround(col, row), invested: cost });
    this.towers.push(tower);
    this.money -= cost;
    this.towersChanged();
    this.events.push({ type: 'build', x: tower.x, y: tower.y, kind });
    return tower;
  }

  upgrade(tower: Tower): boolean {
    const cost = this.upgradeCostOf(tower);
    if (this.status !== 'playing' || cost === null || this.money < cost) return false;
    this.money -= cost;
    tower.invested += cost;
    tower.level++;
    this.events.push({ type: 'upgrade', x: tower.x, y: tower.y, level: tower.level });
    return true;
  }

  sell(tower: Tower): boolean {
    const i = this.towers.indexOf(tower);
    if (i < 0 || this.status !== 'playing') return false;
    this.towers.splice(i, 1);
    this.money += tower.sellValue;
    this.towersChanged();
    this.events.push({ type: 'sell', x: tower.x, y: tower.y, amount: tower.sellValue });
    return true;
  }

  setTargetMode(tower: Tower, mode: TargetMode): void {
    tower.targetMode = mode;
  }

  startNextWave(): boolean {
    if (!this.canStartWave) return false;
    const early = this.earlyBonusNow;
    this.money += early;
    this.waveIndex++;
    this.pendingBonus += waveBonus(this.waveIndex);
    for (const group of this.waveAt(this.waveIndex)!) {
      for (let i = 0; i < group.count; i++) {
        const at = this.tick + Math.round((group.delay + i * group.interval) * TICK_RATE);
        this.spawnQueue.push({ tick: at, type: group.type });
      }
    }
    this.spawnQueue.sort((a, b) => a.tick - b.tick);
    this.events.push({ type: 'waveStarted', wave: this.waveIndex, early });
    return true;
  }

  private towersChanged(): void {
    if (this.map.maze) this.flow = this.map.distanceField((c, r) => this.towerAt(c, r) !== null);
  }

  // ---- enemies ---------------------------------------------------------------

  /** Spawns an enemy at a map entrance (or, with `from`, as a copy of another's position). */
  spawn(type: EnemyType, from?: Enemy): Enemy {
    const hp = this.hpMultiplier;
    let enemy: Enemy;
    if (from) {
      enemy = new Enemy(type, from.nav.clone(), { x: from.x, y: from.y }, hp);
    } else {
      const i = this.spawnCounter++;
      let nav: Nav;
      let start: { x: number; y: number };
      if (enemyDef(type).flying) {
        const route = this.map.flightRoutes[i % this.map.flightRoutes.length];
        nav = new RouteNav(route);
        start = route[0];
      } else if (this.map.maze) {
        const s = this.map.starts[i % this.map.starts.length];
        nav = new FlowNav(this.map, () => this.flow, s);
        start = this.map.outside(s);
      } else {
        const route = this.map.routes[i % this.map.routes.length];
        nav = new RouteNav(route);
        start = route[0];
      }
      enemy = new Enemy(type, nav, start, hp);
    }
    this.enemies.push(enemy);
    return enemy;
  }

  private damageEnemy(e: Enemy, amount: number, opts: { ignoresArmor?: boolean; flash?: boolean }): void {
    if (!e.hit(amount, opts)) return;
    this.kills++;
    this.money += e.def.reward;
    this.events.push({ type: 'kill', x: e.x, y: e.y, amount: e.def.reward, enemy: e.type });
    const split = e.def.split;
    if (split) {
      for (let i = 0; i < split.count; i++) {
        const child = this.spawn(split.type, e);
        // Spread the children a little along the way they're walking.
        const back = (i - (split.count - 1) / 2) * 10;
        child.x -= Math.cos(e.angle) * back;
        child.y -= Math.sin(e.angle) * back;
        child.prevX = child.x;
        child.prevY = child.y;
      }
    }
  }

  private updateAbilities(e: Enemy): void {
    const { heal, summon } = e.def;
    if (!heal && !summon) return;
    if (--e.abilityTimer > 0) return;
    if (heal) {
      e.abilityTimer = Math.round(heal.interval * TICK_RATE);
      let healed = 0;
      for (const o of this.enemies) {
        if (o !== e && o.alive && Math.hypot(o.x - e.x, o.y - e.y) <= heal.radius) {
          healed += o.heal(o.maxHitpoints * heal.fraction);
        }
      }
      if (healed > 0) this.events.push({ type: 'heal', x: e.x, y: e.y, radius: heal.radius });
    }
    if (summon) {
      e.abilityTimer = Math.round(summon.interval * TICK_RATE);
      for (let i = 0; i < summon.count; i++) this.spawn(summon.type, e);
      this.events.push({ type: 'summon', x: e.x, y: e.y });
    }
  }

  // ---- simulation ------------------------------------------------------------

  update(): void {
    if (this.status !== 'playing') return;
    this.tick++;
    const hadWave = this.waveInProgress;

    while (this.spawnQueue.length && this.spawnQueue[0].tick <= this.tick) {
      this.spawn(this.spawnQueue.shift()!.type);
    }

    for (const e of [...this.enemies]) {
      e.update();
      if (e.escaped) {
        this.lives = Math.max(0, this.lives - e.def.damage);
        this.events.push({ type: 'leak', x: e.x, y: e.y, amount: e.def.damage });
      } else {
        this.updateAbilities(e);
      }
    }

    this.updateBuffs();
    const ctx: TowerContext = {
      enemies: this.enemies,
      damageMultiplier: this.modifiers.damageMultiplier,
      damage: (e, amount, opts) => this.damageEnemy(e, amount, opts),
      fire: (b, from) => {
        this.bullets.push(b);
        this.events.push({ type: 'shot', x: b.x, y: b.y, kind: from.kind });
      },
      pulse: (t) => this.events.push({ type: 'pulse', x: t.x, y: t.y, radius: t.range }),
    };
    for (const t of this.towers) t.update(ctx);

    for (const b of this.bullets) {
      const result = b.update(this.enemies);
      if (!result) continue;
      if (result.kind === 'hit') {
        this.events.push({ type: 'hit', x: b.x, y: b.y, bullet: b.type });
        this.damageEnemy(result.enemy, b.damage, {});
      } else {
        this.events.push({ type: 'explode', x: result.x, y: result.y, radius: result.radius });
        for (const e of [...this.enemies]) {
          if (b.canHit(e) && Math.hypot(e.x - result.x, e.y - result.y) <= result.radius + e.radius) {
            this.damageEnemy(e, b.damage, {});
          }
        }
      }
    }

    this.enemies = this.enemies.filter((e) => e.alive);
    this.bullets = this.bullets.filter((b) => b.alive);

    if (this.lives <= 0) {
      this.status = 'lost';
      this.events.push({ type: 'lost' });
    } else if (hadWave && !this.waveInProgress && this.pendingBonus > 0) {
      const interest = Math.min(Math.floor(this.money * INTEREST_RATE), interestCap(this.waveIndex));
      const bonus = this.pendingBonus;
      this.money += bonus + interest;
      this.pendingBonus = 0;
      this.wavesCleared = this.waveIndex + 1;
      this.events.push({ type: 'waveCleared', wave: this.waveIndex, bonus, interest });
      if (!this.endless && this.waveIndex === this.staticWaves.length - 1) {
        this.status = 'won';
        this.events.push({ type: 'won' });
      }
    }
  }

  /** Beacons boost the fire rate of towers around them (the best one counts). */
  private updateBuffs(): void {
    const beacons = this.towers.filter((t) => t.def.behavior === 'support');
    for (const t of this.towers) {
      t.buff = 0;
      if (t.def.behavior === 'support') continue;
      for (const s of beacons) {
        if (Math.hypot(t.x - s.x, t.y - s.y) <= s.range) t.buff = Math.max(t.buff, s.stats.buff ?? 0);
      }
    }
  }

  // ---- save / resume ---------------------------------------------------------

  /** A snapshot can only be taken between waves. */
  snapshot(): WorldSnapshot | null {
    if (this.waveInProgress || this.status !== 'playing') return null;
    return {
      v: 1,
      levelId: this.levelId,
      endless: this.endless,
      money: this.money,
      lives: this.lives,
      waveIndex: this.waveIndex,
      wavesCleared: this.wavesCleared,
      towers: this.towers.map((t) => ({
        kind: t.kind, col: t.col, row: t.row, level: t.level, targetMode: t.targetMode, invested: t.invested,
      })),
    };
  }

  restore(s: WorldSnapshot): void {
    this.money = s.money;
    this.lives = s.lives;
    this.waveIndex = s.waveIndex;
    this.wavesCleared = s.wavesCleared;
    this.towers = s.towers
      .filter((t) => this.map.isBuildableTerrain(t.col, t.row))
      .map((t) => {
        const tower = new Tower(t.kind, t.col, t.row, { highGround: this.map.isHighGround(t.col, t.row), invested: t.invested });
        tower.level = Math.max(0, Math.min(2, t.level));
        tower.targetMode = t.targetMode;
        return tower;
      });
    this.towersChanged();
  }
}
