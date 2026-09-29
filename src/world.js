import {
  TICK_RATE, TOWERS, WAVES, STARTING_MONEY, STARTING_LIVES, WAVE_HP_GROWTH, waveBonus,
} from './config.js';
import { GameMap } from './map.js';
import { Enemy } from './enemy.js';
import { Tower } from './tower.js';

// The whole game simulation for one level. It knows nothing about rendering
// or input, so it can run headless (see tests/).
export class World {
  constructor(mapDef, { waves = WAVES, money = STARTING_MONEY, lives = STARTING_LIVES } = {}) {
    this.map = new GameMap(mapDef);
    this.waves = waves;
    this.money = money;
    this.lives = lives;
    this.tick = 0;
    this.enemies = [];
    this.towers = [];
    this.bullets = [];
    this.waveIndex = -1; // index of the last started wave
    this.spawnQueue = []; // [{ tick, type }] sorted by tick
    this.status = 'playing'; // 'playing' | 'won' | 'lost'
    this.events = []; // things that happened, drained by the renderer
    this.routeCounter = 0;
  }

  // ---- queries -------------------------------------------------------------

  get waveInProgress() {
    return this.spawnQueue.length > 0 || this.enemies.length > 0;
  }

  get canStartWave() {
    return this.status === 'playing' && !this.waveInProgress &&
      this.waveIndex < this.waves.length - 1;
  }

  towerAt(col, row) {
    return this.towers.find((t) => t.col === col && t.row === row) ?? null;
  }

  canBuildAt(col, row) {
    return this.map.inBounds(col, row) && !this.map.isPath(col, row) && !this.towerAt(col, row);
  }

  canAfford(kind) {
    return this.money >= TOWERS[kind].cost;
  }

  // ---- actions -------------------------------------------------------------

  build(kind, col, row) {
    if (this.status !== 'playing' || !this.canBuildAt(col, row) || !this.canAfford(kind)) return null;
    const tower = new Tower(kind, col, row);
    this.towers.push(tower);
    this.money -= tower.def.cost;
    this.events.push({ type: 'build', x: tower.x, y: tower.y });
    return tower;
  }

  sell(col, row) {
    const tower = this.towerAt(col, row);
    if (!tower || this.status !== 'playing') return false;
    this.towers.splice(this.towers.indexOf(tower), 1);
    this.money += tower.sellValue;
    this.events.push({ type: 'sell', x: tower.x, y: tower.y, amount: tower.sellValue });
    return true;
  }

  startNextWave() {
    if (!this.canStartWave) return false;
    this.waveIndex++;
    for (const group of this.waves[this.waveIndex]) {
      for (let i = 0; i < group.count; i++) {
        const at = this.tick + Math.round((group.delay + i * group.interval) * TICK_RATE);
        this.spawnQueue.push({ tick: at, type: group.type });
      }
    }
    this.spawnQueue.sort((a, b) => a.tick - b.tick);
    return true;
  }

  spawn(type) {
    const routes = this.map.routes;
    const route = routes[this.routeCounter++ % routes.length];
    const hp = 1 + WAVE_HP_GROWTH * Math.max(0, this.waveIndex);
    const enemy = new Enemy(type, route, hp);
    this.enemies.push(enemy);
    return enemy;
  }

  // ---- simulation ----------------------------------------------------------

  update() {
    if (this.status !== 'playing') return;
    this.tick++;
    const hadWave = this.waveInProgress;

    while (this.spawnQueue.length && this.spawnQueue[0].tick <= this.tick) {
      this.spawn(this.spawnQueue.shift().type);
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
