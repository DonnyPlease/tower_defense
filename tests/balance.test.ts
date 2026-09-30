import { describe, it, expect } from 'vitest';
import { World } from '../src/sim/world';
import { LEVELS, levelById, ENDLESS, endlessWave } from '../src/data/levels';
import { playHuman, searchExpert, playExpert } from '../balance/players';
import { typicalUnlocks, SKILLS } from '../balance/report';

// Guards the difficulty curve measured by `npm run balance`. Simulated players
// use fixed seeds, so these results are deterministic.
const SEEDS = 12;
// Whole simulated games: generous, as CI runners with coverage are slow.
const SLOW = 180_000;

function wins(levelIndex: number, skill: number): number {
  const level = LEVELS[levelIndex];
  let n = 0;
  for (let seed = 1; seed <= SEEDS; seed++) {
    if (playHuman(new World(level, { unlocked: typicalUnlocks(levelIndex) }), skill, seed).won) n++;
  }
  return n;
}

describe('balance', () => {
  LEVELS.forEach((level, i) => {
    it(`${level.name}: the best strategy found wins`, () => {
      const best = searchExpert(() => new World(level, { unlocked: typicalUnlocks(i) }), { samples: 6, climbs: 6 });
      expect(best.result.won).toBe(true);
    }, SLOW);
  });

  it('Meadow (tutorial) is won by most novices and nearly all average players', () => {
    expect(wins(0, SKILLS.novice)).toBeGreaterThanOrEqual(8);
    expect(wins(0, SKILLS.average)).toBeGreaterThanOrEqual(10);
  }, SLOW);

  it('Meadow can be won without losing a life (3 stars)', () => {
    const w = new World(levelById('meadow'), { unlocked: ['gun', 'missile'] });
    const best = searchExpert(() => new World(levelById('meadow'), { unlocked: ['gun', 'missile'] }), { samples: 10, climbs: 10 });
    expect(playExpert(w, best.params).lives).toBe(w.startLives);
  }, SLOW);

  LEVELS.slice(1).forEach((level, j) => {
    const i = j + 1;
    it(`${level.name} is doable for average players but not trivial for novices`, () => {
      expect(wins(i, SKILLS.average)).toBeGreaterThanOrEqual(6);
      expect(wins(i, SKILLS.novice)).toBeLessThanOrEqual(9);
    }, SLOW);
  });

  it('endless runs end, but not too soon', () => {
    const w = new World(ENDLESS, { endlessWaves: endlessWave, unlocked: typicalUnlocks(2) });
    const cleared = playHuman(w, SKILLS.average, 1, 40).wavesCleared;
    expect(cleared).toBeGreaterThanOrEqual(10);
    expect(cleared).toBeLessThan(40);
  }, SLOW);
});
