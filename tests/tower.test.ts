import { describe, it, expect } from 'vitest';
import { leadAngle, Tower } from '../src/sim/tower';
import { World } from '../src/sim/world';
import { levelById } from '../src/data/levels';
import { HIGH_GROUND_RANGE } from '../src/config';

const meadow = levelById('meadow');

describe('leadAngle', () => {
  it('aims straight at a stationary target', () => {
    expect(leadAngle(0, 0, { x: 100, y: 0, vx: 0, vy: 0 }, 10)).toBeCloseTo(0);
    expect(leadAngle(0, 0, { x: 0, y: 100, vx: 0, vy: 0 }, 10)).toBeCloseTo(Math.PI / 2);
  });

  it('leads a moving target so the bullet meets it', () => {
    const target = { x: 100, y: 0, vx: 0, vy: 2 };
    const speed = 10;
    const a = leadAngle(0, 0, target, speed);
    let best = Infinity;
    for (let t = 0; t < 30; t += 0.01) {
      const bx = Math.cos(a) * speed * t, by = Math.sin(a) * speed * t;
      best = Math.min(best, Math.hypot(bx - target.x, by - (target.y + target.vy * t)));
    }
    expect(best).toBeLessThan(0.5);
  });

  it('falls back to direct aim when the target is too fast to catch', () => {
    expect(leadAngle(0, 0, { x: 100, y: 0, vx: 50, vy: 0 }, 1)).toBeCloseTo(0);
  });
});

describe('Tower', () => {
  it('gets more range on high ground', () => {
    const t = new Tower('gun', 0, 0, { highGround: true });
    expect(t.range).toBeCloseTo(t.stats.range * HIGH_GROUND_RANGE);
  });

  it('picks targets by mode', () => {
    const w = new World(meadow);
    const a = w.spawn('scout'), b = w.spawn('tank');
    a.x = b.x = 200; a.y = b.y = 400;
    a.remaining = 100; b.remaining = 500;
    const t = new Tower('gun', 5, 10);
    t.targetMode = 'first';
    expect(t.pickTarget(w.enemies)).toBe(a);
    t.targetMode = 'last';
    expect(t.pickTarget(w.enemies)).toBe(b);
    t.targetMode = 'strongest';
    expect(t.pickTarget(w.enemies)).toBe(b);
  });

  it('ground-only towers ignore flying enemies', () => {
    const w = new World(meadow);
    const d = w.spawn('drone');
    d.x = 220; d.y = 420;
    expect(new Tower('cannon', 5, 10).pickTarget(w.enemies)).toBeNull();
    expect(new Tower('gun', 5, 10).pickTarget(w.enemies)).toBe(d);
  });
});
