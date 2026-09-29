import { describe, it, expect, beforeEach, vi } from 'vitest';
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

describe('profile storage', () => {
  it('records the best endless run', async () => {
    const { resetProfile, recordEndless } = await import('../src/game/profile');
    const p = resetProfile();
    expect(recordEndless(p, 12)).toBe(true);
    expect(recordEndless(p, 8)).toBe(false);
    expect(p.endlessBest).toBe(12);
  });

  it('saves to and loads from localStorage', async () => {
    const store = new Map<string, string>();
    vi.stubGlobal('localStorage', {
      getItem: (k: string) => store.get(k) ?? null,
      setItem: (k: string, v: string) => void store.set(k, v),
    });
    vi.resetModules();
    const a = await import('../src/game/profile');
    const p = a.loadProfile();
    a.recordWin(p, 'meadow', 2);
    expect(JSON.parse(store.get('tower-defense-profile')!).stars.meadow).toBe(2);

    vi.resetModules(); // simulate a page reload
    const b = await import('../src/game/profile');
    expect(b.loadProfile().stars.meadow).toBe(2);
    vi.unstubAllGlobals();
  });

  it('starts fresh when the stored data is corrupt or from another version', async () => {
    for (const raw of ['{not json', JSON.stringify({ v: 99, stars: { meadow: 3 } })]) {
      vi.stubGlobal('localStorage', { getItem: () => raw, setItem: () => undefined });
      vi.resetModules();
      const { loadProfile } = await import('../src/game/profile');
      expect(loadProfile().stars).toEqual({});
      vi.unstubAllGlobals();
    }
  });
});
