import { describe, it, expect } from 'vitest';
import { lerp, lerpAngle, starString, towerStatsText } from '../src/ui/format';
import { TOWER_KINDS } from '../src/data/towers';

describe('format helpers', () => {
  it('lerp interpolates linearly', () => {
    expect(lerp(0, 10, 0.25)).toBe(2.5);
    expect(lerp(5, 5, 0.7)).toBe(5);
  });

  it('lerpAngle goes the short way round', () => {
    const a = 170 * Math.PI / 180, b = -170 * Math.PI / 180;
    const mid = lerpAngle(a, b, 0.5);
    expect(Math.abs(Math.cos(mid) - Math.cos(Math.PI))).toBeLessThan(1e-9); // 180°, not 0°
  });

  it('starString fills and pads', () => {
    expect(starString(2)).toBe('★★☆');
    expect(starString(0)).toBe('☆☆☆');
    expect(starString(5, 3)).toBe('★★★★★');
  });

  it('describes every tower at every level', () => {
    for (const kind of TOWER_KINDS) {
      for (const level of [0, 1, 2]) expect(towerStatsText(kind, level)).toMatch(/Range \d+/);
    }
    expect(towerStatsText('cannon', 0)).toContain('Splash 45');
    expect(towerStatsText('gun', 0, { buff: 0.3, range: 212.4 })).toMatch(/Range 212[\s\S]*Boosted \+30%/);
    expect(towerStatsText('laser', 0)).toContain('heats to 27');
    expect(towerStatsText('frost', 0)).toContain('Slow 35%');
    expect(towerStatsText('support', 0)).toContain('+20% fire rate');
  });
});
