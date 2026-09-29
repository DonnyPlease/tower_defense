import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { AudioEngine, type SfxName } from '../src/audio/audio';

// A tiny stand-in for the Web Audio API that just counts the nodes created.
let created: Record<string, number>;
class Param {
  value = 0;
  setValueAtTime() { return this; }
  exponentialRampToValueAtTime() { return this; }
  setTargetAtTime() { return this; }
}
class Node { connect<T>(n: T): T { return n; } }
class Osc extends Node { type = ''; frequency = new Param(); start() {} stop() {} }
class Gain extends Node { gain = new Param(); }
class Filter extends Node { type = ''; frequency = new Param(); }
class Source extends Node { buffer: unknown = null; start() {} stop() {} }
class FakeContext {
  state = 'running';
  currentTime = 0;
  sampleRate = 8000;
  destination = new Node();
  createOscillator() { created.osc++; return new Osc(); }
  createGain() { created.gain++; return new Gain(); }
  createBiquadFilter() { return new Filter(); }
  createBufferSource() { created.noise++; return new Source(); }
  createBuffer(_c: number, len: number) { return { getChannelData: () => new Float32Array(len) }; }
  resume() { this.state = 'running'; return Promise.resolve(); }
}

const ALL: SfxName[] = ['gun', 'missile', 'cannon', 'zap', 'frost', 'hit', 'explode', 'pop', 'bigExplosion',
  'build', 'upgrade', 'sell', 'error', 'click', 'leak', 'heal', 'summon', 'waveStart', 'waveClear', 'win', 'lose'];

describe('AudioEngine', () => {
  let now = 0;
  beforeEach(() => {
    created = { osc: 0, gain: 0, noise: 0 };
    now = 0;
    vi.useFakeTimers();
    vi.stubGlobal('window', { AudioContext: FakeContext, setInterval, clearInterval });
    vi.spyOn(performance, 'now').mockImplementation(() => now);
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('is silent until unlocked by a user gesture', () => {
    const a = new AudioEngine();
    a.play('gun');
    expect(created.osc + created.noise).toBe(0);
  });

  it('plays every sound effect without errors', () => {
    const a = new AudioEngine();
    a.setMusic(false);
    a.unlock();
    for (const name of ALL) {
      const before = created.osc + created.noise;
      now += 1000;
      a.play(name);
      expect(created.osc + created.noise, name).toBeGreaterThan(before);
    }
  });

  it('throttles rapid repeats of the same sound', () => {
    const a = new AudioEngine();
    a.setMusic(false);
    a.unlock();
    now = 1000;
    a.play('gun');
    const once = created.osc;
    a.play('gun'); // same instant: dropped
    expect(created.osc).toBe(once);
    now += 100;
    a.play('gun');
    expect(created.osc).toBeGreaterThan(once);
  });

  it('plays nothing when effects are muted', () => {
    const a = new AudioEngine();
    a.setMusic(false);
    a.unlock();
    a.setSfx(false);
    expect(a.sfxEnabled).toBe(false);
    now = 5000;
    a.play('explode');
    expect(created.osc + created.noise).toBe(0);
  });

  it('schedules music, adds drums during waves, and stops when muted', () => {
    const a = new AudioEngine();
    a.unlock();
    vi.advanceTimersByTime(200);
    expect(created.osc).toBeGreaterThan(0); // the scheduler queued notes

    const ctx = (a as unknown as { ctx: FakeContext }).ctx;
    const calm = created.noise;
    a.setIntensity(1);
    ctx.currentTime += 2;
    vi.advanceTimersByTime(200);
    expect(created.noise).toBeGreaterThan(calm); // hi-hats

    a.setMusic(false);
    expect(a.musicEnabled).toBe(false);
    const stopped = created.osc;
    ctx.currentTime += 2;
    vi.advanceTimersByTime(1000);
    expect(created.osc).toBe(stopped);
  });

  it('does nothing when the browser has no Web Audio', () => {
    vi.stubGlobal('window', { setInterval, clearInterval });
    const a = new AudioEngine();
    expect(() => { a.unlock(); a.play('gun'); a.setSfx(true); a.setMusic(true); }).not.toThrow();
  });
});
