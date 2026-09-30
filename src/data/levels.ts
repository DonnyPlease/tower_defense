import type { EnemyType } from './enemies';

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

/**
 * Map tiles (20 x 15):
 *   .  grass (buildable)          #  road
 *   S  road where enemies enter   E  road where enemies leave (on the border)
 *   H  high ground (buildable, +25 % tower range)
 *   R  rock (blocked)             ~  water (blocked)     =  bridge (road over water)
 * In maze levels enemies may also walk on grass and high ground, so the
 * towers themselves form the walls.
 */
export interface LevelDef {
  id: string;
  name: string;
  description: string;
  tiles: string[];
  maze?: boolean;
  money: number;
  lives: number;
  /** Multiplies every enemy's hitpoints on this level (the main difficulty knob). */
  hpScale?: number;
  waves: Wave[];
}

export const LEVELS: LevelDef[] = [
  {
    id: 'meadow',
    name: 'Meadow',
    description: 'A gentle start. Learn the basics.',
    money: 250,
    lives: 20,
    hpScale: 0.88, // tuned with npm run balance:tune
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
    waves: [
      [g('scout', 8, 1.0)],
      [g('scout', 12, 0.7)],
      [g('scout', 8, 0.8), g('racer', 5, 0.7, 3)],
      [g('tank', 3, 2.5), g('scout', 10, 0.6, 2)],
      [g('racer', 14, 0.45)],
      [g('tank', 4, 2), g('scout', 12, 0.5, 1)],
      [g('tank', 6, 1.6), g('racer', 10, 0.45, 3)],
      [g('brute', 1, 1), g('scout', 14, 0.6, 2), g('tank', 3, 2, 6)],
    ],
  },
  {
    id: 'riverside',
    name: 'Riverside',
    description: 'Two roads, one bridge. Watch the sky.',
    money: 350,
    lives: 20,
    hpScale: 0.97, // tuned with npm run balance:tune
    tiles: [
      '.........~~.........',
      '.........~~.........',
      '.........~~..#####..',
      'S#####...~~..#...#..',
      '.....#...~~..#...#..',
      '.....#...~~..#...#..',
      '.....#...~~..#...#..',
      '.....####==###...#..',
      '.....#...~~......#..',
      '.....#...~~......#..',
      '.....#...~~......#..',
      'S#####...~~......##E',
      '.........~~.........',
      '.........~~.........',
      '.........~~.........',
    ],
    waves: [
      [g('scout', 10, 0.8)],
      [g('scout', 8, 0.7), g('racer', 6, 0.6, 3)],
      [g('drone', 5, 1.2)],
      [g('shielded', 6, 1.0), g('scout', 8, 0.6, 2)],
      [g('tank', 4, 2), g('healer', 2, 4, 1), g('scout', 10, 0.5, 3)],
      [g('drone', 8, 0.7), g('racer', 10, 0.45, 3)],
      [g('armored', 6, 1.5), g('healer', 3, 3, 2)],
      [g('shielded', 12, 0.5), g('drone', 8, 0.7, 4)],
      [g('tank', 8, 1.2), g('healer', 4, 2.5, 2), g('racer', 12, 0.35, 5)],
      [g('boss', 1, 1), g('shielded', 8, 0.7, 3), g('drone', 8, 0.6, 6), g('healer', 2, 4, 4)],
    ],
  },
  {
    id: 'highlands',
    name: 'Highlands',
    description: 'A long winding road. Hold the high ground.',
    money: 320,
    lives: 20,
    hpScale: 1.04, // tuned with npm run balance:tune
    tiles: [
      '....................',
      'S##########HH.......',
      '..........#.RR......',
      '..HH......#.........',
      '..HH......#####.....',
      '..............#..R..',
      '..#############.....',
      '..#.......RR........',
      '..#.....HH..........',
      '..#.....HH..........',
      '..###########.......',
      '............#...HH..',
      '..RR........#...HH..',
      '............#######E',
      '....................',
    ],
    waves: [
      [g('scout', 12, 0.7)],
      [g('splitter', 5, 1.5)],
      [g('racer', 12, 0.4), g('drone', 5, 1, 3)],
      [g('armored', 6, 1.5), g('scout', 10, 0.5, 2)],
      [g('splitter', 8, 1.1), g('healer', 2, 4, 2)],
      [g('boss', 1, 1), g('scout', 12, 0.6, 3)],
      [g('shielded', 12, 0.6), g('drone', 8, 0.8, 3)],
      [g('tank', 8, 1.2), g('armored', 6, 1.4, 4)],
      [g('splitter', 12, 0.8), g('healer', 4, 2.5, 3)],
      [g('racer', 25, 0.25), g('drone', 12, 0.5, 4)],
      [g('armored', 10, 1), g('shielded', 12, 0.5, 3), g('healer', 4, 2.5, 5)],
      [g('boss', 2, 8), g('splitter', 10, 0.9, 3), g('tank', 8, 1.2, 8)],
    ],
  },
  {
    id: 'openfield',
    name: 'Open Field',
    description: 'No road at all. Build a maze with your towers.',
    maze: true,
    money: 500,
    lives: 20,
    hpScale: 0.94, // tuned with npm run balance:tune
    tiles: [
      'RRRRRRRRRRRRRRRRRRRR',
      '......R.............',
      '......R.............',
      '......R......R......',
      '......R......R......',
      '......R......R......',
      'S.....R......R.....E',
      'S............R.....E',
      'S............R.....E',
      '......R......R......',
      '......R.............',
      '......R.............',
      '......R.............',
      '......R.............',
      'RRRRRRRRRRRRRRRRRRRR',
    ],
    waves: [
      [g('scout', 12, 0.8)],
      [g('racer', 12, 0.5)],
      [g('tank', 4, 2), g('scout', 10, 0.5, 2)],
      [g('shielded', 10, 0.7), g('drone', 4, 1.2, 3)],
      [g('splitter', 8, 1.2)],
      [g('armored', 8, 1.3), g('healer', 3, 3, 2)],
      [g('drone', 10, 0.6), g('shielded', 10, 0.6, 3)],
      [g('boss', 1, 1), g('racer', 12, 0.4, 3)],
      [g('tank', 10, 1.1), g('healer', 4, 2.5, 2)],
      [g('splitter', 14, 0.7), g('armored', 8, 1.2, 4)],
      [g('racer', 30, 0.2), g('drone', 14, 0.45, 3), g('shielded', 12, 0.5, 6)],
      [g('boss', 2, 10), g('armored', 12, 0.9, 2), g('splitter', 12, 0.8, 6), g('healer', 5, 2, 4)],
    ],
  },
];

export function levelById(id: string): LevelDef {
  const level = LEVELS.find((l) => l.id === id);
  if (!level) throw new Error(`Unknown level "${id}"`);
  return level;
}

// ---- Endless mode --------------------------------------------------------

export const ENDLESS: Omit<LevelDef, 'waves'> = {
  id: 'endless',
  name: 'Endless',
  description: 'Waves never stop. How long can you last?',
  money: 350,
  lives: 20,
  hpScale: 1.45, // tuned: average players survive about 20 waves
  tiles: LEVELS[2].tiles,
};

// Threat cost of each enemy type, and the first endless wave it may appear in.
const ENDLESS_POOL: { type: EnemyType; cost: number; from: number; interval: number }[] = [
  { type: 'scout', cost: 4, from: 0, interval: 0.6 },
  { type: 'racer', cost: 4, from: 1, interval: 0.35 },
  { type: 'tank', cost: 14, from: 2, interval: 1.4 },
  { type: 'drone', cost: 7, from: 3, interval: 0.6 },
  { type: 'shielded', cost: 9, from: 4, interval: 0.6 },
  { type: 'armored', cost: 12, from: 5, interval: 1.2 },
  { type: 'splitter', cost: 12, from: 6, interval: 1.0 },
  { type: 'healer', cost: 14, from: 7, interval: 2.5 },
];

/** Small deterministic PRNG so an endless wave is the same every time. */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function endlessWave(index: number): Wave {
  const rand = mulberry32(index * 7919 + 17);
  const wave: Wave = [];
  let budget = 40 + 18 * index + 0.8 * index * index;
  let delay = 0;
  if (index > 0 && (index + 1) % 10 === 0) {
    const bosses = Math.floor((index + 1) / 10);
    wave.push(g('boss', bosses, 8));
    budget *= 0.5;
    delay = 3;
  }
  const pool = ENDLESS_POOL.filter((p) => p.from <= index);
  const groups = Math.min(4, 1 + Math.floor(index / 3));
  for (let i = 0; i < groups && budget > 4; i++) {
    const p = pool[Math.floor(rand() * pool.length)];
    let share = i === groups - 1 ? budget : budget * (0.3 + rand() * 0.4);
    if (p.type === 'drone') share *= 0.5; // only some towers can hit them
    const count = Math.max(1, Math.min(30, Math.round(share / p.cost)));
    wave.push(g(p.type, count, p.interval, delay));
    budget -= count * p.cost;
    delay += 2 + rand() * 3;
  }
  return wave;
}
