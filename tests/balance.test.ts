import { describe, it, expect } from 'vitest';
import { World } from '../src/sim/world';
import { LEVELS, levelById, ENDLESS, endlessWave } from '../src/data/levels';
import { playBot } from './bot';

// A simple greedy bot must be able to win every level; if a balance change
// breaks this, the level became too hard.
describe('balance', () => {
  it('Meadow can be won with only the starting towers', () => {
    const w = playBot(new World(levelById('meadow'), { unlocked: ['gun', 'missile'] }));
    expect(w.status).toBe('won');
  });

  for (const level of LEVELS) {
    it(`${level.name} can be won with all towers`, () => {
      const w = playBot(new World(level));
      expect(w.status).toBe('won');
    }, 30_000);
  }

  it('endless mode lasts at least 15 waves', () => {
    const w = playBot(new World(ENDLESS, { endlessWaves: endlessWave }), 15);
    expect(w.wavesCleared).toBe(15);
  }, 30_000);
});
