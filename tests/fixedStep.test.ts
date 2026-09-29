import { describe, it, expect } from 'vitest';
import { FixedStep } from '../src/sim/fixedStep';
import { TICK_RATE, MAX_TICKS_PER_FRAME } from '../src/config';

const STEP = 1000 / TICK_RATE;

describe('FixedStep', () => {
  it('runs one tick per step and returns the leftover as alpha', () => {
    const clock = new FixedStep();
    let ticks = 0;
    const alpha = clock.advance(STEP * 2.5, 1, () => ticks++);
    expect(ticks).toBe(2);
    expect(alpha).toBeCloseTo(0.5);
  });

  it('carries the remainder over to the next frame', () => {
    const clock = new FixedStep();
    let ticks = 0;
    clock.advance(STEP * 0.6, 1, () => ticks++);
    clock.advance(STEP * 0.6, 1, () => ticks++);
    expect(ticks).toBe(1);
  });

  it('speeds up with the time scale', () => {
    const clock = new FixedStep();
    let ticks = 0;
    clock.advance(STEP * 3, 3, () => ticks++);
    expect(ticks).toBe(9);
  });

  it('caps long frames instead of spiralling', () => {
    const clock = new FixedStep();
    let ticks = 0;
    const alpha = clock.advance(10_000, 1, () => ticks++); // e.g. tab was in the background
    expect(ticks).toBeLessThanOrEqual(MAX_TICKS_PER_FRAME);
    expect(alpha).toBeGreaterThanOrEqual(0);
    expect(alpha).toBeLessThan(1);
  });
});

describe('FixedStep at the display rate', () => {
  it('runs exactly one tick per 60 Hz frame (no 0-2-0-2 stutter)', () => {
    const clock = new FixedStep();
    const perFrame: number[] = [];
    for (let f = 0; f < 600; f++) {
      let ticks = 0;
      clock.advance(STEP, 1, () => ticks++);
      perFrame.push(ticks);
    }
    expect(new Set(perFrame)).toEqual(new Set([1]));
  });
});
