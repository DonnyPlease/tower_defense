import { describe, it, expect } from 'vitest';
import { World } from '../src/sim/world';
import { MAPS, TOWERS, TILE, STARTING_MONEY, SELL_REFUND, type TowerKind } from '../src/config';

const newWorld = () => new World(MAPS[0]);

describe('World building and selling', () => {
  it('builds on grass and charges the cost', () => {
    const w = newWorld();
    expect(w.build('missile', 0, 0)).not.toBeNull();
    expect(w.money).toBe(STARTING_MONEY - TOWERS.missile.cost);
  });

  it('refuses path tiles, occupied tiles and unaffordable towers', () => {
    const w = newWorld();
    expect(w.build('missile', 0, 10)).toBeNull(); // path
    w.build('missile', 0, 0);
    expect(w.build('gun', 0, 0)).toBeNull(); // occupied
    w.money = 10;
    expect(w.build('gun', 1, 0)).toBeNull(); // too expensive
  });

  it('refunds part of the cost when selling', () => {
    const w = newWorld();
    w.build('gun', 0, 0);
    expect(w.sell(0, 0)).toBe(true);
    expect(w.money).toBe(STARTING_MONEY - TOWERS.gun.cost + TOWERS.gun.cost * SELL_REFUND);
    expect(w.towerAt(0, 0)).toBeNull();
    expect(w.sell(0, 0)).toBe(false);
  });
});

describe('World simulation', () => {
  it('a tower kills a lone enemy and pays the reward', () => {
    const w = new World(MAPS[0], { money: 1000 });
    w.build('gun', 3, 9);
    w.build('gun', 3, 13);
    const e = w.spawn('scout');
    for (let i = 0; i < 2000 && e.alive; i++) w.update();
    expect(e.escaped).toBe(false);
    expect(w.money).toBe(1000 - 2 * TOWERS.gun.cost + e.reward);
  });

  it('enemies that escape cost lives', () => {
    const w = newWorld();
    w.spawn('tank');
    for (let i = 0; i < 5000 && w.enemies.length; i++) w.update();
    expect(w.lives).toBe(20 - 3);
  });

  it('is lost when no towers are built', () => {
    const w = newWorld();
    for (let i = 0; i < 100_000 && w.status === 'playing'; i++) {
      w.startNextWave();
      w.update();
    }
    expect(w.status).toBe('lost');
  });

  it('can be won by a sensible player', () => {
    // A greedy bot: before every wave, spend everything on the spot that
    // covers the most path tiles.
    const w = newWorld();
    const coverage = (col: number, row: number, range: number) => {
      let n = 0;
      for (let r = 0; r < 15; r++) for (let c = 0; c < 20; c++) {
        if (w.map.isPath(c, r) && Math.hypot(c - col, r - row) * TILE <= range) n++;
      }
      return n;
    };
    const pick = (): TowerKind => (w.towers.length % 2 ? 'gun' : 'missile');
    for (let i = 0; i < 200_000 && w.status === 'playing'; i++) {
      if (w.canStartWave) {
        while (w.canAfford(pick())) {
          const kind = pick();
          let best: [number, number] | null = null, bestScore = -1;
          for (let r = 0; r < 15; r++) for (let c = 0; c < 20; c++) {
            const s = w.canBuildAt(c, r) ? coverage(c, r, TOWERS[kind].range) : -1;
            if (s > bestScore) { bestScore = s; best = [c, r]; }
          }
          w.build(kind, ...best!);
        }
        w.startNextWave();
      }
      w.update();
    }
    expect(w.status).toBe('won');
  });
});
