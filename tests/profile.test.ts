import { describe, it, expect, beforeEach } from 'vitest';
import {
  resetProfile, loadProfile, recordWin, totalStars, availableStars, buyPerk, refundPerks,
  unlockedTowers, isLevelUnlocked, isEndlessUnlocked, starsFor, playerModifiers,
} from '../src/game/profile';

// Node has no localStorage: the profile silently lives in memory, which is what we test.
describe('profile', () => {
  beforeEach(() => { resetProfile(); });

  it('awards stars by lives left', () => {
    expect(starsFor(20, 20)).toBe(3);
    expect(starsFor(10, 20)).toBe(2);
    expect(starsFor(1, 20)).toBe(1);
  });

  it('keeps the best result and unlocks levels and towers', () => {
    const p = loadProfile();
    expect(isLevelUnlocked(p, 1)).toBe(false);
    expect(unlockedTowers(p)).toEqual(['gun', 'missile']);
    const { newTowers } = recordWin(p, 'meadow', 2);
    expect(newTowers).toContain('cannon');
    recordWin(p, 'meadow', 1);
    expect(p.stars.meadow).toBe(2);
    expect(isLevelUnlocked(p, 1)).toBe(true);
    expect(isEndlessUnlocked(p)).toBe(false);
    recordWin(p, 'riverside', 3);
    expect(isEndlessUnlocked(p)).toBe(true);
    expect(totalStars(p)).toBe(5);
  });

  it('spends stars on perks and refunds them', () => {
    const p = loadProfile();
    recordWin(p, 'meadow', 3);
    expect(buyPerk(p, 'capital')).toBe(true); // 1
    expect(buyPerk(p, 'capital')).toBe(true); // 2
    expect(availableStars(p)).toBe(0);
    expect(buyPerk(p, 'fortify')).toBe(false);
    expect(playerModifiers(p).money).toBe(80);
    refundPerks(p);
    expect(availableStars(p)).toBe(3);
  });
});
