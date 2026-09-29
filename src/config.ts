// Global constants and game balance. Everything tweakable lives here.

export const TILE = 40;
export const COLS = 20;
export const ROWS = 15;
export const FIELD_W = COLS * TILE; // 800 - the playing field
export const FIELD_H = ROWS * TILE; // 600
export const SIDEBAR_W = 200;
export const WIDTH = FIELD_W + SIDEBAR_W; // 1000 - logical game size
export const HEIGHT = FIELD_H;

// The simulation runs at a fixed rate, independent of the monitor refresh
// rate. All speeds below are in pixels per tick, all times in seconds.
export const TICK_RATE = 60;
export const MAX_TICKS_PER_FRAME = 10; // protects against the "spiral of death"

export const STARTING_MONEY = 250;
export const STARTING_LIVES = 20;
export const SELL_REFUND = 0.5; // fraction of the cost returned when selling
export const WAVE_HP_GROWTH = 0.15; // enemy hitpoints grow by 15 % per wave

export type BulletType = 'normal' | 'missile';

export interface TowerDef {
  name: string;
  sprite: string; // folder in public/assets/towers with frames 0.png-6.png, pointing up
  cost: number;
  range: number;
  fireRate: number; // shots per second
  damage: number;
  bulletSpeed: number;
  bulletType: BulletType;
  hotkey: string;
  description: string;
}

export const TOWERS = {
  missile: {
    name: 'Missile',
    sprite: 'tower1',
    cost: 50,
    range: 200,
    fireRate: 0.8,
    damage: 6,
    bulletSpeed: 4,
    bulletType: 'missile',
    hotkey: 'Q',
    description: 'Slow homing missiles. Cheap and never misses.',
  },
  gun: {
    name: 'Gun',
    sprite: 'tower2',
    cost: 100,
    range: 170,
    fireRate: 3,
    damage: 3,
    bulletSpeed: 16,
    bulletType: 'normal',
    hotkey: 'W',
    description: 'Rapid fire. Aims ahead of moving targets.',
  },
} satisfies Record<string, TowerDef>;

export type TowerKind = keyof typeof TOWERS;
export const TOWER_KINDS = Object.keys(TOWERS) as TowerKind[];

export interface EnemyDef {
  sprite: string; // folder in public/assets/enemies with 0.png facing right
  speed: number;
  hitpoints: number;
  reward: number;
  damage: number; // lives lost when it escapes
  radius: number;
}

export const ENEMIES = {
  scout: { sprite: 'enemy1', speed: 1.5, hitpoints: 20, reward: 6, damage: 1, radius: 14 },
  tank: { sprite: 'enemy2', speed: 1.0, hitpoints: 110, reward: 20, damage: 3, radius: 17 },
  racer: { sprite: 'enemy3', speed: 3.2, hitpoints: 14, reward: 8, damage: 1, radius: 14 },
} satisfies Record<string, EnemyDef>;

export type EnemyType = keyof typeof ENEMIES;
export const ENEMY_TYPES = Object.keys(ENEMIES) as EnemyType[];

// Waves: each group spawns `count` enemies of `type`, one every `interval`
// seconds, starting `delay` seconds after the wave begins.
export interface SpawnGroup {
  type: EnemyType;
  count: number;
  interval: number;
  delay: number;
}
export type Wave = SpawnGroup[];

const g = (type: EnemyType, count: number, interval: number, delay = 0): SpawnGroup =>
  ({ type, count, interval, delay });

export const WAVES: Wave[] = [
  [g('scout', 8, 1.0)],
  [g('scout', 12, 0.7)],
  [g('scout', 8, 0.8), g('racer', 4, 0.8, 3)],
  [g('tank', 3, 2.5), g('scout', 10, 0.6, 2)],
  [g('racer', 14, 0.45)],
  [g('tank', 6, 1.8), g('scout', 12, 0.5, 1)],
  [g('scout', 15, 0.4), g('racer', 10, 0.5, 2), g('tank', 4, 2, 4)],
  [g('tank', 10, 1.2)],
  [g('racer', 22, 0.3), g('tank', 6, 1.5, 3)],
  [g('tank', 8, 1.2), g('scout', 16, 0.4, 1), g('racer', 12, 0.45, 6)],
];

export const waveBonus = (waveIndex: number): number => 25 + 10 * waveIndex;

// Maps are plain ASCII: '#' = path, '.' = buildable ground.
// 'S' / 'E' are path tiles on the border where enemies enter / leave.
export interface MapDef {
  name: string;
  tiles: string[];
}

export const MAPS: MapDef[] = [
  {
    name: 'Meadow',
    tiles: [
      '....................',
      '....................',
      '...........######...',
      '...........######...',
      '...........###.###..',
      '..........###..####.',
      '..........###...###E',
      '..........###...###E',
      '.........####.......',
      '........####........',
      'S#####.#####........',
      'S###########........',
      'S##########.........',
      '....................',
      '....................',
    ],
  },
];
