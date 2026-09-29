// Finds, for every level, the enemy hitpoint scale (LevelDef.hpScale) that
// gives human-like players the target win rate, and prints suggested values.
//
//   npm run balance:tune            all levels
//   npm run balance:tune -- meadow  some levels
import { World } from '../src/sim/world';
import { LEVELS, type LevelDef } from '../src/data/levels';
import { playHuman, searchExpert } from './players';
import { typicalUnlocks, SKILLS } from './report';

/** Which simulated player each level is tuned for, and the win rate we want. */
export const TARGETS: Record<string, { skill: keyof typeof SKILLS; winRate: number }> = {
  meadow: { skill: 'novice', winRate: 0.75 },
  riverside: { skill: 'average', winRate: 0.75 },
  highlands: { skill: 'average', winRate: 0.7 },
  openfield: { skill: 'average', winRate: 0.6 },
};

const GAMES = 24;

function winRate(level: LevelDef, index: number, hpScale: number, skill: number): number {
  const unlocked = typicalUnlocks(index);
  let wins = 0;
  for (let seed = 1; seed <= GAMES; seed++) {
    if (playHuman(new World({ ...level, hpScale }, { unlocked }), skill, seed).won) wins++;
  }
  return wins / GAMES;
}

function tune(level: LevelDef, index: number): void {
  const target = TARGETS[level.id];
  if (!target) return;
  const skill = SKILLS[target.skill];
  // Bisection on a log scale: more hitpoints -> lower win rate.
  let lo = Math.log(0.3), hi = Math.log(3);
  for (let i = 0; i < 9; i++) {
    const mid = (lo + hi) / 2;
    if (winRate(level, index, Math.exp(mid), skill) >= target.winRate) lo = mid;
    else hi = mid;
  }
  const hpScale = Math.round(Math.exp(lo) * 100) / 100;
  const rates = Object.entries(SKILLS).map(([name, s]) =>
    `${name} ${Math.round(winRate(level, index, hpScale, s) * 100)}%`).join(', ');
  const expert = searchExpert(() => new World({ ...level, hpScale }, { unlocked: typicalUnlocks(index) }),
    { samples: 16, climbs: 16 }).result;
  console.log(`${level.id.padEnd(10)} hpScale ${hpScale.toFixed(2)}  (${rates}; expert ${expert.won ? `won with ${expert.lives} lives` : 'LOST'})`);
}

if (process.argv[1]?.endsWith('tune.ts')) {
  const only = process.argv.slice(2).filter((a) => !a.startsWith('--'));
  LEVELS.forEach((level, i) => { if (!only.length || only.includes(level.id)) tune(level, i); });
}
