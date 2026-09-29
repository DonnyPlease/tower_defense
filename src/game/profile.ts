// The player's progress, stored in the browser (localStorage).
import { LEVELS } from '../data/levels';
import { PERKS, PERK_IDS, modifiersFromPerks, type Modifiers, type PerkId } from '../data/perks';
import { TOWER_KINDS, towerDef, type TowerKind } from '../data/towers';
import type { WorldSnapshot } from '../sim/world';

const KEY = 'tower-defense-profile';

export interface Profile {
  v: 1;
  stars: Record<string, number>; // best stars per level id
  perks: Partial<Record<PerkId, number>>; // bought ranks
  endlessBest: number; // most waves cleared in endless mode
  sfx: boolean;
  music: boolean;
  save: WorldSnapshot | null; // game in progress
}

const fresh = (): Profile => ({ v: 1, stars: {}, perks: {}, endlessBest: 0, sfx: true, music: true, save: null });

let cached: Profile | null = null;

export function loadProfile(): Profile {
  if (cached) return cached;
  let p = fresh();
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<Profile>;
      if (parsed.v === 1) p = { ...p, ...parsed };
    }
  } catch {
    // Storage blocked or corrupt: play with a fresh profile.
  }
  cached = p;
  return p;
}

export function saveProfile(p: Profile = loadProfile()): void {
  cached = p;
  try {
    localStorage.setItem(KEY, JSON.stringify(p));
  } catch {
    // Storage unavailable (private mode etc.) - progress lives for this session only.
  }
}

export function resetProfile(): Profile {
  const keep = loadProfile();
  const p = { ...fresh(), sfx: keep.sfx, music: keep.music };
  saveProfile(p);
  return p;
}

// ---- stars and unlocks -------------------------------------------------------

export function starsFor(lives: number, startLives: number): number {
  if (lives >= startLives) return 3;
  if (lives >= startLives / 2) return 2;
  return 1;
}

export function totalStars(p: Profile): number {
  return Object.values(p.stars).reduce((a, b) => a + b, 0);
}

export function spentStars(p: Profile): number {
  return PERK_IDS.reduce((n, id) => n + PERKS[id].costs.slice(0, p.perks[id] ?? 0).reduce((a, b) => a + b, 0), 0);
}

export function availableStars(p: Profile): number {
  return totalStars(p) - spentStars(p);
}

export function unlockedTowers(p: Profile): TowerKind[] {
  const stars = totalStars(p);
  return TOWER_KINDS.filter((k) => towerDef(k).unlockStars <= stars);
}

export function isLevelUnlocked(p: Profile, index: number): boolean {
  return index === 0 || (p.stars[LEVELS[index - 1].id] ?? 0) > 0;
}

/** Endless mode opens after beating the second level. */
export function isEndlessUnlocked(p: Profile): boolean {
  return (p.stars[LEVELS[1].id] ?? 0) > 0;
}

export function recordWin(p: Profile, levelId: string, stars: number): { newTowers: TowerKind[] } {
  const before = unlockedTowers(p);
  p.stars[levelId] = Math.max(p.stars[levelId] ?? 0, stars);
  const after = unlockedTowers(p);
  saveProfile(p);
  return { newTowers: after.filter((k) => !before.includes(k)) };
}

export function recordEndless(p: Profile, waves: number): boolean {
  const best = waves > p.endlessBest;
  if (best) {
    p.endlessBest = waves;
    saveProfile(p);
  }
  return best;
}

// ---- perks -------------------------------------------------------------------

export function nextPerkCost(p: Profile, id: PerkId): number | null {
  const rank = p.perks[id] ?? 0;
  return PERKS[id].costs[rank] ?? null;
}

export function buyPerk(p: Profile, id: PerkId): boolean {
  const cost = nextPerkCost(p, id);
  if (cost === null || cost > availableStars(p)) return false;
  p.perks[id] = (p.perks[id] ?? 0) + 1;
  saveProfile(p);
  return true;
}

export function refundPerks(p: Profile): void {
  p.perks = {};
  saveProfile(p);
}

export function playerModifiers(p: Profile): Modifiers {
  return modifiersFromPerks(p.perks);
}
