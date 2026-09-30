// Balance report: how do an optimised expert and human-like players of
// different skill fare on every level?
//
//   npm run balance              full report (a few minutes)
//   npm run balance -- --quick   fewer games, rougher numbers
//   npm run balance -- meadow    only some levels
import { World } from '../src/sim/world';
import { LEVELS, ENDLESS, endlessWave, type LevelDef } from '../src/data/levels';
import { TOWER_KINDS, towerDef, type TowerKind } from '../src/data/towers';
import { playHuman, searchExpert, type GameResult } from './players';

/** Towers a typical player has when reaching level `index` (about 2 stars per level). */
export function typicalUnlocks(index: number): TowerKind[] {
  return TOWER_KINDS.filter((k) => towerDef(k).unlockStars <= 2 * index);
}

export const SKILLS = { novice: 0.25, average: 0.55, good: 0.85 };

export interface LevelReport {
  level: string;
  unlocked: TowerKind[];
  expert: GameResult;
  humans: Record<keyof typeof SKILLS, { winRate: number; avgLives: number; avgWaves: number }>;
}

export function reportLevel(level: LevelDef, index: number, games: number, search = { samples: 40, climbs: 40 }): LevelReport {
  const unlocked = typicalUnlocks(index);
  const make = () => new World(level, { unlocked });
  const expert = searchExpert(make, search).result;
  const humans = {} as LevelReport['humans'];
  for (const [name, skill] of Object.entries(SKILLS) as [keyof typeof SKILLS, number][]) {
    const results = Array.from({ length: games }, (_, seed) => playHuman(make(), skill, seed + 1));
    humans[name] = {
      winRate: results.filter((r) => r.won).length / games,
      avgLives: results.reduce((n, r) => n + r.lives, 0) / games,
      avgWaves: results.reduce((n, r) => n + r.wavesCleared, 0) / games,
    };
  }
  return { level: level.id, unlocked, expert, humans };
}

function main() {
  const args = process.argv.slice(2);
  const quick = args.includes('--quick');
  const only = args.filter((a) => !a.startsWith('--'));
  const games = quick ? 10 : 40;
  const search = quick ? { samples: 12, climbs: 12 } : { samples: 40, climbs: 40 };
  const pct = (x: number) => `${Math.round(x * 100)}%`.padStart(5);

  console.log(`Level        Towers                         Expert (best found)   Novice          Average         Good`);
  LEVELS.forEach((level, i) => {
    if (only.length && !only.includes(level.id)) return;
    const r = reportLevel(level, i, games, search);
    const e = r.expert;
    const expert = e.won ? `won, ${e.lives}/${e.startLives} lives` : `lost at wave ${e.wavesCleared + 1}`;
    const h = (k: keyof typeof SKILLS) => `${pct(r.humans[k].winRate)} (♥${r.humans[k].avgLives.toFixed(1).padStart(4)})`;
    console.log(`${level.id.padEnd(12)} ${r.unlocked.join(',').padEnd(30)} ${expert.padEnd(21)} ${h('novice')}  ${h('average')}  ${h('good')}`);
  });
  if (!only.length || only.includes('endless')) {
    const unlocked = typicalUnlocks(2);
    const waves = (skill: number) => {
      const runs = Array.from({ length: Math.min(games, 8) }, (_, s) =>
        playHuman(new World(ENDLESS, { endlessWaves: endlessWave, unlocked }), skill, s + 1, 50).wavesCleared);
      return (runs.reduce((a, b) => a + b, 0) / runs.length).toFixed(1);
    };
    console.log(`endless      average waves survived: novice ${waves(SKILLS.novice)}, average ${waves(SKILLS.average)}, good ${waves(SKILLS.good)}`);
  }
}

// Run when executed directly (not when imported by tests).
if (process.argv[1]?.endsWith('report.ts')) main();
