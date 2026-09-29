import { describe, it, expect } from 'vitest';
import { PERKS, PERK_IDS, modifiersFromPerks, NO_MODIFIERS } from '../src/data/perks';

describe('perks', () => {
  it('every perk describes each of its ranks', () => {
    for (const id of PERK_IDS) {
      const perk = PERKS[id];
      perk.costs.forEach((_, i) => expect(perk.effect(i + 1)).toMatch(/\d/));
    }
  });

  it('no perks means no modifiers', () => {
    expect(modifiersFromPerks({})).toEqual(NO_MODIFIERS);
  });

  it('ranks scale the modifiers', () => {
    expect(modifiersFromPerks({ capital: 3, fortify: 2, engineering: 2, firepower: 3 })).toEqual({
      money: 120, lives: 10, costMultiplier: 1 - 0.12, damageMultiplier: 1 + 0.24,
    });
  });
});
