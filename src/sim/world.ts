import {
  TICK_RATE, TOWERS, WAVES, STARTING_MONEY, STARTING_LIVES, WAVE_HP_GROWTH, waveBonus,
  type MapDef, type Wave, type TowerKind, type EnemyType, type BulletType,
} from '../config';
import { GameMap } from './map';
import { Enemy } from './enemy';
import { Tower } from './tower';
import type { Bullet } from './bullet';

export type GameStatus = 'playing' | 'won' | 'lost';

/** Things that happened during a tick; the view drains them for effects. */
export type WorldEvent =
  | { type: 'build'; x: number; y: number; kind: TowerKind }
  | { type: 'sell'; x: number; y: number; amount: number }
  | { type: 'shot'; x: number; y: number; kind: TowerKind }
  | { type: 'hit'; x: number; y: number; bullet: BulletType }
  | { type: 'kill'; x: number; y: number; amount: number; enemy: EnemyType }
  | { type: 'leak'; x: number; y: number; amount: number }
  | { type: 'waveStarted'; wave: number }
  | { type: 'waveCleared'; wave: number; amount: number }
  | { type: 'won' }
  | { type: 'lost' };

export interface WorldOptions {
  waves?: Wave[];
  money?: number;
  lives?: number;
}

/**
 * The whole game simulation for one level. It knows nothing about rendering
 * or input, so it can run headless (see tests/).
 */
export class World {
  readonly map: GameMap;
  readonly waves: Wave[];
  money: number;
  lives: number;
  tick = 0;
  enemies: Enemy[] = [];
  towers: Tower[] = [];
  bullets: Bullet[] = [];
  waveIndex = -1; // index of the last started wave
  status: GameStatus = 'playing';
  events: WorldEvent[] = [];

  private spawnQueue: { tick: number; type: EnemyType }[] = [];
  private routeCounter = 0;

  constructor(mapDef: MapDef, opts: WorldOptions = {}) {
    this.map = new GameMap(mapDef);
    this.waves = opts.waves ?? WAVES;
    this.money = opts.money ?? STARTING_MONEY;
    this.lives = opts.lives ?? STARTING_LIVES;
  }

  // ---- queries -------------------------------------------------------------

  get waveInProgress(): boolean {
    return this.spawnQueue.length > 0 || this.enemies.length > 0;
  }

  get canStartWave(): boolean {
    return this.status === 'playing' && !this.waveInProgress &&
      this.waveIndex < this.waves.length - 1;
  }

  /** Enemies still to come in the current wave, including those on the field. */
  get enemiesRemaining(): number {
    return this.spawnQueue.length + this.enemies.length;
  }

  towerAt(col: number, row: number): Tower | null {
    return this.towers.find((t) => t.col === col && t.row === row) ?? null;
  }

  canBuildAt(col: number, row: number): boolean {
    return this.map.inBounds(col, row) && !this.map.isPath(col, row) && !this.towerAt(col, row);
  }

  canAfford(kind: TowerKind): boolean {
    return this.money >= TOWERS[kind].cost;
  }

  // ---- actions -------------------------------------------------------------

  build(kind: TowerKind, col: number, row: number): Tower | null {
    if (this.status !== 'playing' || !this.canBuildAt(col, row) || !this.canAfford(kind)) return null;
    const tower = new Tower(kind, col, row);
    this.towers.push(tower);
    this.money -= tower.def.cost;
    this.events.push({ type: 'build', x: tower.x, y: tower.y, kind });
    return tower;
  }

  sell(col: number, row: number): boolean {
    const tower = this.towerAt(col, row);
    if (!tower || this.status !== 'playing') return false;
    this.towers.splice(this.towers.indexOf(tower), 1);
    this.money += tower.sellValue;
    this.events.push({ type: 'sell', x: tower.x, y: tower.y, amount: tower.sellValue });
    return true;
  }

  startNextWave(): boolean {
    if (!this.canStartWave) return false;
    this.waveIndex++;
    for (const group of this.waves[this.waveIndex]) {
      for (let i = 0; i < group.count; i++) {
        const at = this.tick + Math.round((group.delay + i * group.interval) * TICK_RATE);
        this.spawnQueue.push({ tick: at, type: group.type });
      }
    }
    this.spawnQueue.sort((a, b) => a.tick - b.tick);
    this.events.push({ type: 'waveStarted', wave: this.waveIndex });
    return true;
  }

  spawn(type: EnemyType): Enemy {
    const routes = this.map.routes;
    const route = routes[this.routeCounter++ % routes.length];
    const hp = 1 + WAVE_HP_GROWTH * Math.max(0, this.waveIndex);
    const enemy = new Enemy(type, route, hp);
    this.enemies.push(enemy);
    return enemy;
  }

  // ---- simulation ----------------------------------------------------------

  update(): void {
    if (this.status !== 'playing') return;
    this.tick++;
    const hadWave = this.waveInProgress;

    while (this.spawnQueue.length && this.spawnQueue[0].tick <= this.tick) {
      this.spawn(this.spawnQueue.shift()!.type);
    }

    for (const e of this.enemies) {
      e.update();
      if (e.escaped) {
        this.lives = Math.max(0, this.lives - e.def.damage);
        this.events.push({ type: 'leak', x: e.x, y: e.y, amount: e.def.damage });
      }
    }

    for (const t of this.towers) {
      const bullet = t.update(this.enemies);
      if (bullet) {
        this.bullets.push(bullet);
        this.events.push({ type: 'shot', x: bullet.x, y: bullet.y, kind: t.kind });
      }
    }

    for (const b of this.bullets) {
      const enemy = b.update(this.enemies);
      if (!enemy) continue;
      this.events.push({ type: 'hit', x: b.x, y: b.y, bullet: b.type });
      if (enemy.hit(b.damage)) {
        this.money += enemy.reward;
        this.events.push({ type: 'kill', x: enemy.x, y: enemy.y, amount: enemy.reward, enemy: enemy.type });
      }
    }

    this.enemies = this.enemies.filter((e) => e.alive);
    this.bullets = this.bullets.filter((b) => b.alive);

    if (this.lives <= 0) {
      this.status = 'lost';
      this.events.push({ type: 'lost' });
    } else if (hadWave && !this.waveInProgress && this.waveIndex >= 0) {
      const bonus = waveBonus(this.waveIndex);
      this.money += bonus;
      this.events.push({ type: 'waveCleared', wave: this.waveIndex, amount: bonus });
      if (this.waveIndex === this.waves.length - 1) {
        this.status = 'won';
        this.events.push({ type: 'won' });
      }
    }
  }
}
