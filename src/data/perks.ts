// Permanent upgrades bought with stars earned in levels.

export type PerkId = 'capital' | 'fortify' | 'engineering' | 'firepower';

export interface PerkDef {
  name: string;
  /** Describes the effect at a given rank (1-based). */
  effect: (rank: number) => string;
  costs: number[]; // star cost of each rank
}

export const PERKS: Record<PerkId, PerkDef> = {
  capital: {
    name: 'War Chest',
    effect: (r) => `+$${40 * r} starting money`,
    costs: [1, 2, 3],
  },
  fortify: {
    name: 'Fortify',
    effect: (r) => `+${5 * r} lives`,
    costs: [1, 2],
  },
  engineering: {
    name: 'Engineering',
    effect: (r) => `Towers and upgrades ${6 * r}% cheaper`,
    costs: [2, 3],
  },
  firepower: {
    name: 'Firepower',
    effect: (r) => `+${8 * r}% tower damage`,
    costs: [2, 3, 4],
  },
};

export const PERK_IDS = Object.keys(PERKS) as PerkId[];

export interface Modifiers {
  money: number; // added to the level's starting money
  lives: number;
  costMultiplier: number;
  damageMultiplier: number;
}

export const NO_MODIFIERS: Modifiers = { money: 0, lives: 0, costMultiplier: 1, damageMultiplier: 1 };

export function modifiersFromPerks(ranks: Partial<Record<PerkId, number>>): Modifiers {
  const r = (id: PerkId) => ranks[id] ?? 0;
  return {
    money: 40 * r('capital'),
    lives: 5 * r('fortify'),
    costMultiplier: 1 - 0.06 * r('engineering'),
    damageMultiplier: 1 + 0.08 * r('firepower'),
  };
}
