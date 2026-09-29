import { describe, it, expect } from 'vitest';
import { World } from '../src/sim/world';
import { LEVELS, levelById, ENDLESS, endlessWave } from '../src/data/levels';
import { TOWERS } from '../src/data/towers';
import { modifiersFromPerks } from '../src/data/perks';
import { SELL_REFUND, TICK_RATE, waveBonus, earlyBonus } from '../src/config';

const meadow = levelById('meadow');
const run = (w: World, ticks: number) => { for (let i = 0; i < ticks; i++) w.update(); };

describe('building, upgrading, selling', () => {
  it('builds on grass and charges the cost', () => {
    const w = new World(meadow);
    expect(w.build('missile', 0, 0)).not.toBeNull();
    expect(w.money).toBe(meadow.money - TOWERS.missile.levels[0].cost);
  });

  it('refuses roads, occupied tiles, locked and unaffordable towers', () => {
    const w = new World(meadow, { unlocked: ['gun', 'missile'] });
    expect(w.build('missile', 0, 10)).toBeNull(); // road
    w.build('missile', 0, 0);
    expect(w.build('gun', 0, 0)).toBeNull(); // occupied
    expect(w.build('laser', 1, 0)).toBeNull(); // locked
    w.money = 10;
    expect(w.build('gun', 1, 0)).toBeNull(); // too expensive
  });

  it('upgrades up to level 3 and refunds part of everything invested', () => {
    const w = new World(meadow);
    w.money = 10_000;
    const t = w.build('gun', 0, 0)!;
    expect(w.upgrade(t)).toBe(true);
    expect(w.upgrade(t)).toBe(true);
    expect(w.upgrade(t)).toBe(false); // max level
    expect(t.level).toBe(2);
    const invested = TOWERS.gun.levels.reduce((n, l) => n + l.cost, 0);
    const before = w.money;
    w.sell(t);
    expect(w.money - before).toBe(Math.floor(invested * SELL_REFUND));
  });

  it('applies perk modifiers', () => {
    const mods = modifiersFromPerks({ capital: 2, fortify: 1, engineering: 1, firepower: 0 });
    const w = new World(meadow, { modifiers: mods });
    expect(w.money).toBe(meadow.money + 80);
    expect(w.lives).toBe(meadow.lives + 5);
    expect(w.costOf('gun')).toBe(Math.round(100 * 0.94));
  });
});

describe('enemies', () => {
  it('armor reduces weak hits, lasers ignore it', () => {
    const w = new World(meadow);
    const e = w.spawn('armored');
    const hp = e.hitpoints;
    e.hit(3);
    expect(hp - e.hitpoints).toBeCloseTo(0.75); // 25 % minimum
    e.hit(10, { ignoresArmor: true });
    expect(hp - e.hitpoints).toBeCloseTo(10.75);
  });

  it('shields absorb damage first and recharge', () => {
    const w = new World(meadow);
    const e = w.spawn('shielded');
    e.hit(10);
    expect(e.hitpoints).toBe(e.maxHitpoints);
    expect(e.shield).toBe(e.maxShield - 10);
    run(w, 6 * TICK_RATE);
    expect(e.shield).toBe(e.maxShield);
  });

  it('frost slows ground enemies but not drones', () => {
    const w = new World(meadow);
    const e = w.spawn('scout');
    const d = w.spawn('drone');
    e.applySlow(0.5, 10);
    d.applySlow(0.5, 10);
    expect(e.speed).toBeCloseTo(e.def.speed * 0.5);
    expect(d.speed).toBeCloseTo(d.def.speed);
  });

  it('splitters split into minis', () => {
    const w = new World(meadow);
    w.money = 10_000;
    const e = w.spawn('splitter');
    for (let i = 0; i < 60; i++) w.update(); // walk onto the map
    e.hitpoints = 1;
    w.build('gun', 3, 9);
    w.build('gun', 3, 13);
    for (let i = 0; i < 600 && e.alive; i++) w.update();
    expect(e.alive).toBe(false);
    expect(w.events.some((ev) => ev.type === 'kill' && ev.enemy === 'splitter')).toBe(true);
    expect(w.enemies.filter((m) => m.type === 'mini').length + w.kills - 1).toBeGreaterThanOrEqual(3);
  });

  it('medics heal nearby enemies', () => {
    const w = new World(meadow);
    const m = w.spawn('healer');
    const s = w.spawn('scout');
    s.hitpoints = 5;
    run(w, 2 * TICK_RATE);
    expect(s.hitpoints).toBeGreaterThan(5);
    expect(m.alive).toBe(true);
  });

  it('the boss summons reinforcements', () => {
    const w = new World(meadow);
    w.spawn('boss');
    run(w, 8 * TICK_RATE);
    expect(w.enemies.filter((e) => e.type === 'scout').length).toBeGreaterThanOrEqual(2);
  });

  it('drones fly straight to the exit', () => {
    const w = new World(meadow);
    const d = w.spawn('drone');
    run(w, 30);
    // Along the flight route the drone never touches the road's corner waypoints.
    expect(d.nav.remaining(d.x, d.y)).toBeLessThan(w.map.routes[0].length * 1000);
    for (let i = 0; i < 2000 && d.alive; i++) w.update();
    expect(d.escaped).toBe(true);
  });

  it('escaping enemies cost lives', () => {
    const w = new World(meadow);
    w.spawn('tank');
    for (let i = 0; i < 5000 && w.enemies.length; i++) w.update();
    expect(w.lives).toBe(meadow.lives - 3);
  });
});

describe('towers in action', () => {
  it('cannon shells hit every ground enemy in the splash', () => {
    const w = new World(meadow);
    w.money = 10_000;
    const a = w.spawn('scout'), b = w.spawn('scout');
    run(w, 90);
    w.build('cannon', 3, 9);
    for (let i = 0; i < 400 && a.alive; i++) w.update();
    expect(a.hitpoints < a.maxHitpoints || !a.alive).toBe(true);
    expect(b.hitpoints < b.maxHitpoints || !b.alive).toBe(true);
  });

  it('beacons boost the fire rate of nearby towers', () => {
    const w = new World(meadow);
    w.money = 10_000;
    const gun = w.build('gun', 0, 0)!;
    w.build('support', 1, 0);
    w.update();
    expect(gun.fireRate).toBeCloseTo(gun.stats.fireRate * 1.2);
  });

  it('lasers heat up on the same target', () => {
    const w = new World(meadow);
    w.money = 10_000;
    const laser = w.build('laser', 3, 9)!;
    const e = w.spawn('tank');
    for (let i = 0; i < 1000 && !laser.target; i++) w.update();
    run(w, 60);
    expect(laser.target).toBe(e);
    expect(laser.heatFraction).toBeGreaterThan(0.4);
  });
});

describe('waves and economy', () => {
  it('pays the wave bonus plus interest when a wave is cleared', () => {
    const w = new World(meadow);
    w.lives = 1000;
    w.startNextWave();
    const before = w.money;
    let cleared = null;
    for (let i = 0; i < 20000 && !cleared; i++) {
      w.update();
      cleared = w.events.find((e) => e.type === 'waveCleared');
      w.events.length = 0;
    }
    expect(cleared).toMatchObject({ bonus: waveBonus(0) });
    expect(w.money).toBe(before + waveBonus(0) + (cleared as { interest: number }).interest);
  });

  it('pays an early bonus for calling a wave while enemies remain', () => {
    const w = new World(meadow);
    w.startNextWave();
    expect(w.canStartWave).toBe(false); // still spawning
    for (let i = 0; i < 20000 && w.spawning; i++) w.update();
    expect(w.canStartWave).toBe(true);
    const before = w.money;
    w.startNextWave();
    expect(w.money - before).toBe(earlyBonus(1));
  });

  it('endless mode never runs out of waves', () => {
    const w = new World(ENDLESS, { endlessWaves: endlessWave });
    expect(w.totalWaves).toBeNull();
    expect(w.waveAt(500)?.length).toBeGreaterThan(0);
    expect(endlessWave(9).some((g) => g.type === 'boss')).toBe(true);
  });
});

describe('maze levels', () => {
  const field = levelById('openfield');

  it('enemies walk around towers', () => {
    const w = new World(field);
    const len = () => Math.min(...w.map.starts.map((s) => w.distanceField[s.row][s.col]));
    const before = len();
    w.money = 10_000;
    for (let r = 1; r <= 13; r++) w.build('missile', 10, r);
    expect(len()).toBeGreaterThan(before);
  });

  it('refuses a tower that would cut off the exit', () => {
    const w = new World(field);
    w.money = 100_000;
    let refused = false;
    for (let r = 1; r <= 13; r++) {
      if (!w.build('missile', 16, r)) refused = true;
    }
    expect(refused).toBe(true);
    expect(w.map.starts.every((s) => Number.isFinite(w.distanceField[s.row][s.col]))).toBe(true);
  });
});

describe('save and resume', () => {
  it('round-trips a snapshot between waves', () => {
    const w = new World(meadow);
    w.money = 1000;
    const t = w.build('gun', 0, 0)!;
    w.upgrade(t);
    t.targetMode = 'strongest';
    const snap = w.snapshot()!;
    const copy = new World(meadow);
    copy.restore(JSON.parse(JSON.stringify(snap)));
    expect(copy.money).toBe(w.money);
    expect(copy.towers).toHaveLength(1);
    expect(copy.towers[0]).toMatchObject({ kind: 'gun', level: 1, targetMode: 'strongest', invested: t.invested });
  });

  it('cannot snapshot during a wave', () => {
    const w = new World(meadow);
    w.startNextWave();
    expect(w.snapshot()).toBeNull();
  });
});

describe('the game ends', () => {
  it('is lost when nothing is built', () => {
    for (const level of LEVELS) {
      const w = new World(level);
      for (let i = 0; i < 200_000 && w.status === 'playing'; i++) {
        w.startNextWave();
        w.update();
      }
      expect(w.status, level.id).toBe('lost');
    }
  });
});

describe('more world rules', () => {
  it('slows wear off', () => {
    const w = new World(meadow);
    const e = w.spawn('scout');
    e.applySlow(0.5, 3);
    run(w, 3);
    expect(e.slow).toBe(0);
  });

  it('ignores zero damage and hits on dead enemies', () => {
    const w = new World(meadow);
    const e = w.spawn('scout');
    expect(e.hit(0)).toBe(false);
    e.hit(1000);
    expect(e.hit(5)).toBe(false);
  });

  it('refuses to sell a tower twice or change anything after the game ended', () => {
    const w = new World(meadow);
    const t = w.build('missile', 0, 0)!;
    w.setTargetMode(t, 'last');
    expect(t.targetMode).toBe('last');
    expect(w.sell(t)).toBe(true);
    expect(w.sell(t)).toBe(false);
    w.status = 'lost';
    const tick = w.tick;
    w.update();
    expect(w.tick).toBe(tick);
    expect(w.build('missile', 0, 0)).toBeNull();
  });

  it('counts the enemies still to come', () => {
    const w = new World(meadow);
    w.startNextWave();
    expect(w.enemiesRemaining).toBe(8);
    expect(w.waveAt(99)).toBeNull();
  });

  it('beacons outside their range give no boost', () => {
    const w = new World(meadow);
    w.money = 10_000;
    const far = w.build('gun', 19, 14)!;
    w.build('support', 0, 0);
    w.update();
    expect(far.buff).toBe(0);
  });
});

describe('more maze rules', () => {
  const field = levelById('openfield');

  it('refuses to build on a tile an enemy is walking to', () => {
    const w = new World(field);
    w.money = 10_000;
    const e = w.spawn('scout');
    run(w, 40); // walk onto the map
    const t = e.nav.targetTile!;
    expect(w.buildBlockReason(t.col, t.row)).toBe('enemy');
  });

  it('ignores drones when checking for blocked paths', () => {
    const w = new World(field);
    w.spawn('drone');
    run(w, 40);
    expect(w.buildBlockReason(3, 3)).toBeNull();
  });

  it('splitters in a maze hand their route to their minis', () => {
    const w = new World(field);
    w.money = 10_000;
    const e = w.spawn('splitter');
    run(w, 90);
    e.hitpoints = 1;
    w.build('gun', 3, 5);
    w.build('gun', 3, 9);
    for (let i = 0; i < 600 && e.alive; i++) w.update();
    const minis = w.enemies.filter((m) => m.type === 'mini');
    expect(minis.length).toBeGreaterThan(0);
    for (let i = 0; i < 3000 && w.enemies.some((m) => m.type === 'mini'); i++) w.update();
    expect(w.enemies.some((m) => m.type === 'mini')).toBe(false); // they all reached the exit or died
  });

  it('flow navigation reports the remaining distance, even when leaving', () => {
    const w = new World(field);
    const e = w.spawn('racer');
    const start = e.remaining;
    run(w, 60);
    expect(e.remaining).toBeLessThan(start);
    for (let i = 0; i < 2000 && e.nav.targetTile; i++) w.update();
    expect(e.remaining).toBeLessThan(80);
  });
});
