import { describe, it, expect } from 'vitest';
import { leadAngle } from '../src/sim/tower';

describe('leadAngle', () => {
  it('aims straight at a stationary target', () => {
    expect(leadAngle(0, 0, { x: 100, y: 0, vx: 0, vy: 0 }, 10)).toBeCloseTo(0);
    expect(leadAngle(0, 0, { x: 0, y: 100, vx: 0, vy: 0 }, 10)).toBeCloseTo(Math.PI / 2);
  });

  it('leads a moving target so the bullet meets it', () => {
    const target = { x: 100, y: 0, vx: 0, vy: 2 };
    const speed = 10;
    const a = leadAngle(0, 0, target, speed);
    // Simulate: find the tick where the bullet is closest to the target.
    let best = Infinity;
    for (let t = 0; t < 30; t += 0.01) {
      const bx = Math.cos(a) * speed * t, by = Math.sin(a) * speed * t;
      best = Math.min(best, Math.hypot(bx - target.x, by - (target.y + target.vy * t)));
    }
    expect(best).toBeLessThan(0.5);
  });

  it('falls back to direct aim when the target is too fast to catch', () => {
    const a = leadAngle(0, 0, { x: 100, y: 0, vx: 50, vy: 0 }, 1);
    expect(a).toBeCloseTo(0);
  });
});
