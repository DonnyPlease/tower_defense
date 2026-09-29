// Tower types. Each tower has 3 levels: levels[0].cost is the build price,
// levels[1] and levels[2] cost is the price of that upgrade.

export type TowerBehavior = 'projectile' | 'beam' | 'aura' | 'support';
export type BulletType = 'normal' | 'missile' | 'shell';
export type TargetMode = 'first' | 'last' | 'strongest' | 'closest';
export const TARGET_MODES: TargetMode[] = ['first', 'last', 'strongest', 'closest'];

export interface TowerLevel {
  cost: number;
  range: number;
  damage: number; // per shot; per second for beams; per pulse for auras
  fireRate: number; // shots (or pulses) per second
  splash?: number; // cannon: explosion radius
  slow?: number; // frost: speed reduction, 0.4 = 40 % slower
  buff?: number; // support: fire-rate bonus for nearby towers, 0.2 = +20 %
}

export interface TowerDef {
  name: string;
  description: string;
  behavior: TowerBehavior;
  bullet?: BulletType;
  bulletSpeed?: number; // pixels per tick
  hitsAir: boolean;
  hitsGround: boolean;
  ignoresArmor?: boolean;
  /** Optional folder in public/assets/towers with `frames` PNGs pointing up; otherwise the art is drawn in BootScene. */
  sprite?: string;
  frames: number;
  /** Total stars needed before the tower can be used. */
  unlockStars: number;
  color: number; // accent colour for UI and effects
  levels: [TowerLevel, TowerLevel, TowerLevel];
}

export const TOWERS = {
  gun: {
    name: 'Gun',
    description: 'Rapid fire. Aims ahead of moving targets. Hits air.',
    behavior: 'projectile', bullet: 'normal', bulletSpeed: 16,
    hitsAir: true, hitsGround: true,
    frames: 7, unlockStars: 0, color: 0xe63946,
    levels: [
      { cost: 100, range: 170, damage: 3, fireRate: 3 },
      { cost: 70, range: 180, damage: 5, fireRate: 3.5 },
      { cost: 130, range: 195, damage: 8, fireRate: 4 },
    ],
  },
  missile: {
    name: 'Missile',
    description: 'Cheap homing missiles that never miss. Hits air.',
    behavior: 'projectile', bullet: 'missile', bulletSpeed: 4,
    hitsAir: true, hitsGround: true,
    frames: 7, unlockStars: 0, color: 0x57c26b,
    levels: [
      { cost: 50, range: 200, damage: 6, fireRate: 0.8 },
      { cost: 50, range: 215, damage: 10, fireRate: 0.9 },
      { cost: 90, range: 230, damage: 16, fireRate: 1 },
    ],
  },
  cannon: {
    name: 'Cannon',
    description: 'Heavy shells with splash damage. Breaks armor. Ground only.',
    behavior: 'projectile', bullet: 'shell', bulletSpeed: 6,
    hitsAir: false, hitsGround: true,
    frames: 1, unlockStars: 1, color: 0x8d99ae,
    levels: [
      { cost: 120, range: 160, damage: 16, fireRate: 0.6, splash: 45 },
      { cost: 100, range: 170, damage: 26, fireRate: 0.65, splash: 55 },
      { cost: 160, range: 180, damage: 40, fireRate: 0.7, splash: 65 },
    ],
  },
  frost: {
    name: 'Frost',
    description: 'Slows every ground enemy in range and chills them with pulses.',
    behavior: 'aura',
    hitsAir: false, hitsGround: true,
    frames: 1, unlockStars: 3, color: 0x7ad3ff,
    levels: [
      { cost: 90, range: 110, damage: 2, fireRate: 1, slow: 0.35 },
      { cost: 80, range: 120, damage: 3, fireRate: 1, slow: 0.45 },
      { cost: 120, range: 135, damage: 5, fireRate: 1, slow: 0.55 },
    ],
  },
  laser: {
    name: 'Laser',
    description: 'Beam that heats up (up to 3x) on one target. Ignores armor.',
    behavior: 'beam',
    hitsAir: true, hitsGround: true, ignoresArmor: true,
    frames: 1, unlockStars: 5, color: 0xd35cff,
    levels: [
      { cost: 150, range: 150, damage: 9, fireRate: 1 },
      { cost: 130, range: 160, damage: 15, fireRate: 1 },
      { cost: 200, range: 175, damage: 24, fireRate: 1 },
    ],
  },
  support: {
    name: 'Beacon',
    description: 'Boosts the fire rate of towers in range. Does not attack.',
    behavior: 'support',
    hitsAir: false, hitsGround: false,
    frames: 1, unlockStars: 7, color: 0xf5c542,
    levels: [
      { cost: 120, range: 100, damage: 0, fireRate: 0, buff: 0.2 },
      { cost: 100, range: 115, damage: 0, fireRate: 0, buff: 0.3 },
      { cost: 150, range: 130, damage: 0, fireRate: 0, buff: 0.45 },
    ],
  },
} satisfies Record<string, TowerDef>;

export type TowerKind = keyof typeof TOWERS;
export const TOWER_KINDS = Object.keys(TOWERS) as TowerKind[];

export function towerDef(kind: TowerKind): TowerDef {
  return TOWERS[kind] as TowerDef;
}
