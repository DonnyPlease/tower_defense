// A simple greedy player used to check that levels are beatable and balanced.
import { TILE, COLS, ROWS } from '../src/config';
import { towerDef, TOWER_KINDS, type TowerKind } from '../src/data/towers';
import { GameMap } from '../src/sim/map';
import type { World } from '../src/sim/world';
import type { Tower } from '../src/sim/tower';

/** Tiles enemies currently walk on (for maze levels this follows the live flow field). */
function pathTiles(w: World): { col: number; row: number }[] {
  if (!w.map.maze) {
    const out = [];
    for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) if (w.map.isRoad(c, r)) out.push({ col: c, row: r });
    return out;
  }
  const seen = new Set<string>();
  const out = [];
  for (const s of w.map.starts) {
    let cur: { col: number; row: number } | null = s;
    while (cur && !seen.has(`${cur.col},${cur.row}`)) {
      seen.add(`${cur.col},${cur.row}`);
      out.push(cur);
      cur = GameMap.nextTile(w.distanceField, cur, null);
    }
  }
  return out;
}

function coverage(path: { col: number; row: number }[], col: number, row: number, range: number): number {
  let n = 0;
  for (const t of path) if (Math.hypot(t.col - col, t.row - row) * TILE <= range) n++;
  return n;
}

/** Rough usefulness of a tower level per tile of path it covers. */
function power(kind: TowerKind, level: number): number {
  const d = towerDef(kind), s = d.levels[level];
  switch (d.behavior) {
    case 'projectile': return s.damage * s.fireRate * (s.splash ? 2.2 : 1);
    case 'beam': return s.damage * 2;
    case 'aura': return s.damage * s.fireRate + 25 * (s.slow ?? 0);
    case 'support': return 0;
  }
}

/** How many tiles longer the enemies' walk gets if (col, row) is blocked. */
function mazeGain(w: World, col: number, row: number): number {
  const len = (f: number[][]) => Math.min(...w.map.starts.map((s) => f[s.row][s.col]));
  const before = len(w.distanceField);
  const after = len(w.map.distanceField((c, r) => (c === col && r === row) || w.towerAt(c, r) !== null));
  return Number.isFinite(after) ? after - before : -100;
}

function bestSpot(w: World, kind: TowerKind, path: { col: number; row: number }[]) {
  let best: { col: number; row: number; score: number } | null = null;
  for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
    if (!w.map.isBuildableTerrain(c, r) || w.towerAt(c, r)) continue;
    const range = towerDef(kind).levels[0].range * (w.map.isHighGround(c, r) ? 1.25 : 1);
    let score = kind === 'support'
      ? w.towers.filter((t) => t.def.behavior !== 'support' && Math.hypot(t.x - (c * TILE + 20), t.y - (r * TILE + 20)) <= range).length
      : coverage(path, c, r, range);
    if (w.map.maze && kind !== 'support') score += 0.6 * mazeGain(w, c, r);
    if ((!best || score > best.score) && w.canBuildAt(c, r)) best = { col: c, row: r, score };
  }
  return best;
}

/** Makes one purchase if a worthwhile one is affordable. Returns false when done. */
function buyOne(w: World): boolean {
  const path = pathTiles(w);
  const drones = (w.nextWave ?? []).filter((g) => g.type === 'drone').reduce((n, g) => n + g.count, 0);
  const airPower = w.towers.filter((t) => t.def.hitsAir).reduce((n, t) => n + power(t.kind, t.level), 0);
  const needsAir = airPower < drones * 2.5;
  let bestAction: (() => void) | null = null;
  let bestValue = 0;

  for (const kind of TOWER_KINDS) {
    if (!w.isUnlocked(kind) || !w.canAfford(kind)) continue;
    if (needsAir && !towerDef(kind).hitsAir) continue;
    if (kind === 'support' && w.towers.length < 6) continue;
    if (kind === 'frost' && w.towers.filter((t) => t.kind === 'frost').length >= 2) continue;
    const spot = bestSpot(w, kind, path);
    if (!spot || spot.score === 0) continue;
    const same = w.towers.filter((t) => t.kind === kind).length;
    const value = (kind === 'support'
      ? spot.score * 6 / w.costOf(kind)
      : (spot.score * power(kind, 0)) / w.costOf(kind)) * 0.9 ** same;
    if (value > bestValue) {
      bestValue = value;
      bestAction = () => w.build(kind, spot.col, spot.row);
    }
  }
  for (const t of w.towers) {
    const cost = w.upgradeCostOf(t);
    if (cost === null || cost > w.money || t.def.behavior === 'support') continue;
    if (needsAir && !t.def.hitsAir) continue;
    const cov = coverage(path, t.col, t.row, t.range);
    const value = (cov * (power(t.kind, t.level + 1) - power(t.kind, t.level))) / cost * 1.1;
    if (value > bestValue) {
      bestValue = value;
      bestAction = () => w.upgrade(t as Tower);
    }
  }
  if (!bestAction) return false;
  bestAction();
  return true;
}

/** Plays until the game ends (or `maxWaves` are cleared). */
export function playBot(w: World, maxWaves = Infinity): World {
  for (let i = 0; i < 2_000_000 && w.status === 'playing' && w.wavesCleared < maxWaves; i++) {
    if (!w.waveInProgress) {
      while (buyOne(w)) { /* spend everything */ }
      w.startNextWave();
    }
    w.update();
  }
  return w;
}
