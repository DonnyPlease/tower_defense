// Simulated players used to measure how hard each level is.
//
// - playExpert: a parameterised greedy strategy. `searchExpert` tunes its
//   parameters per level, which approximates the best possible play.
// - playHuman: a human-like player with a skill level from 0 (novice) to 1.
//   It places towers imperfectly, picks tower types semi-randomly and does
//   not always spend its money well. Run it with many seeds for a win rate.
import { TILE, COLS, ROWS, HIGH_GROUND_RANGE } from '../src/config';
import { towerDef, TOWER_KINDS, type TowerKind } from '../src/data/towers';
import { GameMap, type Tile } from '../src/sim/map';
import type { World } from '../src/sim/world';

// ---- helpers ---------------------------------------------------------------

/** Small seeded PRNG so every simulated game is reproducible. */
export function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Tiles enemies currently walk on (maze levels follow the live flow field). */
export function pathTiles(w: World): Tile[] {
  if (!w.map.maze) {
    const out: Tile[] = [];
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) if (w.map.isRoad(c, r)) out.push({ col: c, row: r });
    return out;
  }
  const seen = new Set<string>();
  const out: Tile[] = [];
  for (const s of w.map.starts) {
    let cur: Tile | null = s;
    while (cur && !seen.has(`${cur.col},${cur.row}`)) {
      seen.add(`${cur.col},${cur.row}`);
      out.push(cur);
      cur = GameMap.nextTile(w.distanceField, cur, null);
    }
  }
  return out;
}

function coverage(path: Tile[], col: number, row: number, range: number): number {
  let n = 0;
  for (const t of path) if (Math.hypot(t.col - col, t.row - row) * TILE <= range) n++;
  return n;
}

function rangeAt(w: World, kind: TowerKind, col: number, row: number): number {
  return towerDef(kind).levels[0].range * (w.map.isHighGround(col, row) ? HIGH_GROUND_RANGE : 1);
}

/** Rough damage output of a tower level, used to value purchases. */
export function power(kind: TowerKind, level: number, vsArmor = 0): number {
  const d = towerDef(kind), s = d.levels[level];
  const hit = (dmg: number) => (d.ignoresArmor ? dmg : Math.max(dmg * 0.25, dmg - vsArmor));
  switch (d.behavior) {
    case 'projectile': return hit(s.damage) * s.fireRate * (s.splash ? 2.2 : 1);
    case 'beam': return hit(s.damage) * 2;
    case 'aura': return hit(s.damage) * s.fireRate + 25 * (s.slow ?? 0);
    case 'support': return 0;
  }
}

/** How many tiles longer the enemies' walk gets if (col, row) is blocked (maze levels). */
function mazeGain(w: World, col: number, row: number): number {
  const len = (f: number[][]) => Math.min(...w.map.starts.map((s) => f[s.row][s.col]));
  const before = len(w.distanceField);
  const after = len(w.map.distanceField((c, r) => (c === col && r === row) || w.towerAt(c, r) !== null));
  return Number.isFinite(after) ? after - before : -100;
}

/** Candidate build spots for a tower kind, best first. */
function rankSpots(w: World, kind: TowerKind, path: Tile[], mazeWeight: number) {
  const spots: { col: number; row: number; score: number }[] = [];
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    if (!w.map.isBuildableTerrain(c, r) || w.towerAt(c, r)) continue;
    const range = rangeAt(w, kind, c, r);
    const score = kind === 'support'
      ? w.towers.filter((t) => t.def.behavior !== 'support' && Math.hypot(t.x - (c * TILE + 20), t.y - (r * TILE + 20)) <= range).length
      : coverage(path, c, r, range);
    if (score > 0) spots.push({ col: c, row: r, score });
  }
  spots.sort((a, b) => b.score - a.score);
  // Maze levels: also value making the path longer. That needs a path search
  // per spot, so only the most promising spots are checked.
  if (w.map.maze && kind !== 'support' && mazeWeight > 0) {
    for (const s of spots.slice(0, 30)) s.score += mazeWeight * mazeGain(w, s.col, s.row);
    spots.sort((a, b) => b.score - a.score);
  }
  return spots;
}

/** Enemy armor and air share in the next wave, so players can react to it. */
function nextWaveThreat(w: World) {
  let total = 0, air = 0, armor = 0;
  for (const g of w.nextWave ?? []) {
    total += g.count;
    if (g.type === 'drone') air += g.count;
    if (g.type === 'armored' || g.type === 'boss') armor += g.count;
  }
  return { air: total ? air / total : 0, armored: armor > 0 };
}

export interface GameResult {
  won: boolean;
  lives: number;
  startLives: number;
  wavesCleared: number;
}

function result(w: World): GameResult {
  return { won: w.status === 'won', lives: w.lives, startLives: w.startLives, wavesCleared: w.wavesCleared };
}

function run(w: World, beforeWave: (w: World) => void, maxWaves: number, callEarly = false): GameResult {
  for (let i = 0; i < 3_000_000 && w.status === 'playing' && w.wavesCleared < maxWaves; i++) {
    if (!w.waveInProgress) {
      beforeWave(w);
      w.startNextWave();
    } else if (callEarly && w.canStartWave && w.enemies.length <= 2) {
      beforeWave(w);
      w.startNextWave();
    }
    w.update();
  }
  return result(w);
}

// ---- expert ----------------------------------------------------------------

export interface ExpertParams {
  weights: Record<TowerKind, number>; // preference multiplier per tower
  upgradeBias: number; // multiplier on the value of upgrades
  diversity: number; // 0..1, penalty for building the same tower again
  mazeWeight: number; // maze levels: how much to value lengthening the path
  armorAware: boolean; // value damage against armored enemies
  callEarly: boolean; // call waves early for the bonus
}

export const DEFAULT_EXPERT: ExpertParams = {
  weights: { gun: 1, missile: 1, cannon: 1, frost: 1, laser: 1, support: 1 },
  upgradeBias: 1.1,
  diversity: 0.1,
  mazeWeight: 0.6,
  armorAware: true,
  callEarly: false,
};

function expertBuy(w: World, p: ExpertParams): boolean {
  const path = pathTiles(w);
  const threat = nextWaveThreat(w);
  const armor = p.armorAware && threat.armored ? 3 : 0;
  const airPower = w.towers.filter((t) => t.def.hitsAir).reduce((n, t) => n + power(t.kind, t.level), 0);
  const needsAir = threat.air > 0 && airPower < 6 + 40 * threat.air;
  let best: (() => void) | null = null;
  let bestValue = 0;

  for (const kind of TOWER_KINDS) {
    if (!w.isUnlocked(kind) || !w.canAfford(kind) || p.weights[kind] <= 0) continue;
    if (needsAir && !towerDef(kind).hitsAir) continue;
    if (kind === 'support' && w.towers.length < 6) continue;
    const spot = rankSpots(w, kind, path, p.mazeWeight).find((s) => w.canBuildAt(s.col, s.row));
    if (!spot) continue;
    const same = w.towers.filter((t) => t.kind === kind).length;
    const base = kind === 'support' ? spot.score * 6 : spot.score * power(kind, 0, armor);
    const value = (base / w.costOf(kind)) * p.weights[kind] * (1 - p.diversity) ** same;
    if (value > bestValue) {
      bestValue = value;
      best = () => w.build(kind, spot.col, spot.row);
    }
  }
  for (const t of w.towers) {
    const cost = w.upgradeCostOf(t);
    if (cost === null || cost > w.money || t.def.behavior === 'support') continue;
    if (needsAir && !t.def.hitsAir) continue;
    const cov = coverage(path, t.col, t.row, t.range);
    const gain = power(t.kind, t.level + 1, armor) - power(t.kind, t.level, armor);
    const value = ((cov * gain) / cost) * p.upgradeBias * p.weights[t.kind];
    if (value > bestValue) {
      bestValue = value;
      best = () => w.upgrade(t);
    }
  }
  if (!best) return false;
  best();
  return true;
}

export function playExpert(w: World, p: ExpertParams = DEFAULT_EXPERT, maxWaves = Infinity): GameResult {
  return run(w, (world) => { while (expertBuy(world, p)) { /* spend */ } }, maxWaves, p.callEarly);
}

// ---- human-like ------------------------------------------------------------

/**
 * A human-like player. `skill` 0 = novice, 1 = very good:
 * - places towers somewhere among the top spots (the lower the skill, the wider the pick),
 * - chooses tower types at random, only reacting to armor/air when skilled,
 * - upgrades now and then instead of building,
 * - sometimes keeps a little money unspent.
 */
export function playHuman(w: World, skill: number, seed: number, maxWaves = Infinity): GameResult {
  const rand = rng(seed);
  const pickCount = Math.round(2 + (1 - skill) * 20);
  const upgradeChance = 0.2 + 0.25 * skill;

  const buy = (world: World) => {
    const reserve = rand() < (1 - skill) * 0.5 ? 20 + rand() * 60 : 0;
    const threat = nextWaveThreat(world);
    for (let guard = 0; guard < 60; guard++) {
      const budget = world.money - reserve;
      const affordable = TOWER_KINDS.filter((k) => world.isUnlocked(k) && world.costOf(k) <= budget &&
        (k !== 'support' || world.towers.length >= 5));
      const upgradable = world.towers.filter((t) => {
        const c = world.upgradeCostOf(t);
        return c !== null && c <= budget;
      });

      if (upgradable.length && (rand() < upgradeChance || !affordable.length)) {
        // Skilled players upgrade their best-placed towers; novices pick at random.
        const path = pathTiles(world);
        const sorted = upgradable.map((t) => ({ t, cov: coverage(path, t.col, t.row, t.range) }))
          .sort((a, b) => b.cov - a.cov);
        const pick = sorted[Math.floor(rand() ** (1 + 2 * skill) * sorted.length)];
        world.upgrade(pick.t);
        continue;
      }
      if (!affordable.length) break;

      let pool = affordable;
      if (skill >= 0.5 && threat.air > 0.3 && !world.towers.some((t) => t.def.hitsAir)) {
        pool = pool.filter((k) => towerDef(k).hitsAir);
      }
      if (skill >= 0.7 && threat.armored) {
        const strong = pool.filter((k) => k === 'cannon' || k === 'laser' || k === 'missile');
        if (strong.length) pool = strong;
      }
      if (!pool.length) break;
      const kind = pool[Math.floor(rand() * pool.length)];
      const spots = rankSpots(world, kind, pathTiles(world), world.map.maze ? 0.4 * skill : 0)
        .filter((s) => world.canBuildAt(s.col, s.row));
      if (!spots.length) break;
      const spot = spots[Math.floor(rand() * Math.min(pickCount, spots.length))];
      if (!world.build(kind, spot.col, spot.row)) break;
    }
  };
  return run(w, buy, maxWaves);
}

// ---- strategy search ---------------------------------------------------------

/** Higher is better: winning dominates, then lives kept, then progress. */
export function scoreResult(r: GameResult): number {
  return r.won ? 1000 + r.lives : r.wavesCleared * 10 + r.lives;
}

function randomParams(rand: () => number): ExpertParams {
  const weights = {} as Record<TowerKind, number>;
  for (const k of TOWER_KINDS) weights[k] = rand() < 0.15 ? 0 : 0.3 + rand() * 1.7;
  return {
    weights,
    upgradeBias: 0.4 + rand() * 2,
    diversity: rand() * 0.4,
    mazeWeight: rand() * 1.5,
    armorAware: rand() < 0.7,
    callEarly: rand() < 0.3,
  };
}

function mutate(p: ExpertParams, rand: () => number): ExpertParams {
  const q: ExpertParams = { ...p, weights: { ...p.weights } };
  const k = TOWER_KINDS[Math.floor(rand() * TOWER_KINDS.length)];
  q.weights[k] = Math.max(0, q.weights[k] + (rand() - 0.5));
  q.upgradeBias = Math.max(0.1, q.upgradeBias * (0.7 + rand() * 0.6));
  q.diversity = Math.min(0.6, Math.max(0, q.diversity + (rand() - 0.5) * 0.1));
  q.mazeWeight = Math.max(0, q.mazeWeight + (rand() - 0.5) * 0.4);
  if (rand() < 0.1) q.armorAware = !q.armorAware;
  if (rand() < 0.1) q.callEarly = !q.callEarly;
  return q;
}

/**
 * Random search followed by hill climbing over the expert's parameters.
 * Returns the best strategy found and its result.
 */
export function searchExpert(newWorld: () => World, opts: { samples?: number; climbs?: number; seed?: number } = {}) {
  const rand = rng(opts.seed ?? 1);
  let best = { params: DEFAULT_EXPERT, result: playExpert(newWorld(), DEFAULT_EXPERT) };
  const consider = (params: ExpertParams) => {
    const r = playExpert(newWorld(), params);
    if (scoreResult(r) > scoreResult(best.result)) best = { params, result: r };
  };
  for (let i = 0; i < (opts.samples ?? 40); i++) consider(randomParams(rand));
  for (let i = 0; i < (opts.climbs ?? 40); i++) consider(mutate(best.params, rand));
  return best;
}
