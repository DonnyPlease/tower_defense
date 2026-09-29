import { TICK_RATE, MAX_TICKS_PER_FRAME } from '../config';

const STEP_MS = 1000 / TICK_RATE;
// Tolerance for floating-point drift, so a frame of exactly one step always
// runs exactly one tick (otherwise 60 Hz screens can stutter 0-2-0-2).
const EPSILON = 1e-6;

/**
 * Fixed-timestep accumulator. The simulation always advances in whole ticks,
 * so it behaves the same on 30, 60 or 144 Hz screens; the renderer gets the
 * leftover fraction (`alpha`) to interpolate positions between ticks.
 */
export class FixedStep {
  private accumulator = 0;

  /** Runs `tick` as many times as `deltaMs` allows; returns the interpolation alpha. */
  advance(deltaMs: number, timeScale: number, tick: () => void): number {
    this.accumulator += Math.min(deltaMs, 250) * timeScale;
    let ticks = 0;
    while (this.accumulator >= STEP_MS - EPSILON && ticks < MAX_TICKS_PER_FRAME * timeScale) {
      tick();
      this.accumulator -= STEP_MS;
      ticks++;
    }
    // Fell too far behind (slow device) - drop the backlog instead of spiralling.
    if (this.accumulator >= STEP_MS) this.accumulator = 0;
    return Math.max(0, this.accumulator / STEP_MS);
  }
}
