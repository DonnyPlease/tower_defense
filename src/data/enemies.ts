// Enemy types. `texture` is a Phaser texture key: enemy-scout/tank/racer come
// from public/assets/enemies, the rest are generated in BootScene.

export interface EnemyDef {
  name: string;
  texture: string;
  tint?: number;
  scale?: number;
  speed: number; // pixels per tick
  hitpoints: number;
  reward: number;
  damage: number; // lives lost when it escapes
  radius: number;
  armor?: number; // flat damage reduction per hit (a hit always does at least 25 %)
  shield?: number; // regenerating shield points on top of hitpoints
  flying?: boolean; // ignores the road and flies straight to the exit
  split?: { type: EnemyType; count: number }; // spawns these when killed
  heal?: { radius: number; fraction: number; interval: number }; // heals nearby enemies
  summon?: { type: EnemyType; count: number; interval: number }; // boss ability
  boss?: boolean;
  description: string;
}

export type EnemyType =
  | 'scout' | 'racer' | 'tank' | 'armored' | 'shielded' | 'splitter' | 'mini' | 'healer' | 'drone' | 'boss';

export const ENEMIES: Record<EnemyType, EnemyDef> = {
  scout: {
    name: 'Scout', texture: 'enemy-scout', speed: 1.5, hitpoints: 20, reward: 5, damage: 1, radius: 14,
    description: 'Basic light tank.',
  },
  racer: {
    name: 'Racer', texture: 'enemy-racer', speed: 3.0, hitpoints: 14, reward: 6, damage: 1, radius: 14,
    description: 'Very fast, fragile.',
  },
  tank: {
    name: 'Tank', texture: 'enemy-tank', speed: 1.0, hitpoints: 110, reward: 18, damage: 3, radius: 17,
    description: 'Slow and tough. Costs 3 lives.',
  },
  armored: {
    name: 'Armored', texture: 'enemy-armored', speed: 1.1, hitpoints: 60, armor: 4, reward: 15, damage: 2, radius: 16,
    description: 'Armor 4: weak hits barely scratch it. Use cannons or lasers.',
  },
  shielded: {
    name: 'Shielded', texture: 'enemy-shielded', speed: 1.4, hitpoints: 30, shield: 30, reward: 12, damage: 1, radius: 15,
    description: 'Energy shield that recharges when not hit for 3 s.',
  },
  splitter: {
    name: 'Splitter', texture: 'enemy-splitter', speed: 1.2, hitpoints: 60, reward: 10, damage: 2, radius: 16,
    split: { type: 'mini', count: 3 },
    description: 'Splits into 3 minis when destroyed.',
  },
  mini: {
    name: 'Mini', texture: 'enemy-splitter', scale: 0.55, speed: 2.0, hitpoints: 12, reward: 2, damage: 1, radius: 9,
    description: 'Fragment of a splitter.',
  },
  healer: {
    name: 'Medic', texture: 'enemy-healer', speed: 1.3, hitpoints: 45, reward: 14, damage: 1, radius: 15,
    heal: { radius: 85, fraction: 0.06, interval: 1 },
    description: 'Repairs nearby enemies every second. Kill it first.',
  },
  drone: {
    name: 'Drone', texture: 'enemy-drone', speed: 1.6, hitpoints: 22, reward: 8, damage: 1, radius: 13, flying: true,
    description: 'Flies straight over everything. Only Gun, Missile and Laser can hit it.',
  },
  boss: {
    name: 'Warlord', texture: 'enemy-tank', tint: 0xff6b6b, scale: 1.75, speed: 0.55, hitpoints: 1200, armor: 3,
    reward: 150, damage: 10, radius: 26, boss: true,
    summon: { type: 'scout', count: 2, interval: 7 },
    description: 'Boss. Armored, calls in reinforcements. Costs 10 lives.',
  },
};
export const ENEMY_TYPES = Object.keys(ENEMIES) as EnemyType[];

export function enemyDef(type: EnemyType): EnemyDef {
  return ENEMIES[type];
}
