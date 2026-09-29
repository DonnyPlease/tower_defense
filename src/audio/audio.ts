// Procedural sound effects and music, synthesised with the Web Audio API,
// so the game needs no audio files.

export type SfxName =
  | 'gun' | 'missile' | 'cannon' | 'zap' | 'frost' | 'hit' | 'explode' | 'pop' | 'bigExplosion'
  | 'build' | 'upgrade' | 'sell' | 'error' | 'click' | 'leak' | 'heal' | 'summon'
  | 'waveStart' | 'waveClear' | 'win' | 'lose';

// Minimum time between two plays of the same sound (ms), so 20 guns don't deafen you.
const THROTTLE: Partial<Record<SfxName, number>> = {
  gun: 45, hit: 35, missile: 70, cannon: 60, zap: 90, frost: 120, pop: 30, explode: 50, heal: 200,
};

const midi = (n: number) => 440 * Math.pow(2, (n - 69) / 12);

// Am - F - C - G, as MIDI notes.
const PROGRESSION = [
  { bass: 45, chord: [57, 60, 64] },
  { bass: 41, chord: [57, 60, 65] },
  { bass: 48, chord: [55, 60, 64] },
  { bass: 43, chord: [55, 59, 62] },
];
const ARP = [0, 1, 2, 1, 0, 2, 1, 2];
const BPM = 104;

export class AudioEngine {
  private ctx: AudioContext | null = null;
  private sfxGain!: GainNode;
  private musicGain!: GainNode;
  private noiseBuffer!: AudioBuffer;
  private last = new Map<SfxName, number>();
  private sfxOn = true;
  private musicOn = true;
  private intensity = 0; // 0 calm, 1 wave in progress (adds drums)
  private step = 0;
  private nextStepTime = 0;
  private timer: number | null = null;

  /** Must be called from a user gesture (browsers block audio until then). */
  unlock(): void {
    if (!this.ctx) {
      const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!Ctx) return;
      this.ctx = new Ctx();
      const master = this.ctx.createGain();
      master.gain.value = 0.8;
      master.connect(this.ctx.destination);
      this.sfxGain = this.ctx.createGain();
      this.sfxGain.gain.value = this.sfxOn ? 1 : 0;
      this.sfxGain.connect(master);
      this.musicGain = this.ctx.createGain();
      this.musicGain.gain.value = this.musicOn ? 0.5 : 0;
      this.musicGain.connect(master);
      this.noiseBuffer = this.ctx.createBuffer(1, this.ctx.sampleRate, this.ctx.sampleRate);
      const data = this.noiseBuffer.getChannelData(0);
      for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    }
    if (this.ctx.state === 'suspended') void this.ctx.resume();
    if (this.musicOn) this.startMusic();
  }

  get sfxEnabled(): boolean {
    return this.sfxOn;
  }

  get musicEnabled(): boolean {
    return this.musicOn;
  }

  setSfx(on: boolean): void {
    this.sfxOn = on;
    if (this.ctx) this.sfxGain.gain.setTargetAtTime(on ? 1 : 0, this.ctx.currentTime, 0.02);
  }

  setMusic(on: boolean): void {
    this.musicOn = on;
    if (!this.ctx) return;
    this.musicGain.gain.setTargetAtTime(on ? 0.5 : 0, this.ctx.currentTime, 0.1);
    if (on) this.startMusic();
    else this.stopMusic();
  }

  setIntensity(level: number): void {
    this.intensity = level;
  }

  // ---- effects ---------------------------------------------------------------

  play(name: SfxName): void {
    const ctx = this.ctx;
    if (!ctx || !this.sfxOn || ctx.state !== 'running') return;
    const now = performance.now();
    const gap = THROTTLE[name] ?? 0;
    if (gap && now - (this.last.get(name) ?? 0) < gap) return;
    this.last.set(name, now);
    const t = ctx.currentTime;

    switch (name) {
      case 'gun':
        this.noise(t, 0.05, 'highpass', 2500, 2500, 0.12);
        this.tone(t, 'square', 900, 300, 0.04, 0.04);
        break;
      case 'missile':
        this.noise(t, 0.28, 'bandpass', 700, 2600, 0.14);
        break;
      case 'cannon':
        this.tone(t, 'sine', 140, 45, 0.28, 0.45);
        this.noise(t, 0.18, 'lowpass', 900, 200, 0.25);
        break;
      case 'zap':
        this.tone(t, 'sawtooth', 500, 1400, 0.12, 0.05);
        break;
      case 'frost':
        this.tone(t, 'sine', 1900, 900, 0.3, 0.05);
        this.noise(t, 0.25, 'highpass', 6000, 6000, 0.04);
        break;
      case 'hit':
        this.tone(t, 'triangle', 1500, 900, 0.03, 0.035);
        break;
      case 'pop':
        this.tone(t, 'square', 520, 180, 0.07, 0.06);
        this.noise(t, 0.08, 'lowpass', 2000, 400, 0.08);
        break;
      case 'explode':
        this.noise(t, 0.35, 'lowpass', 1400, 150, 0.3);
        this.tone(t, 'sine', 90, 35, 0.3, 0.3);
        break;
      case 'bigExplosion':
        this.noise(t, 0.9, 'lowpass', 1800, 80, 0.5);
        this.tone(t, 'sine', 70, 25, 0.8, 0.5);
        break;
      case 'build':
        this.tone(t, 'square', 220, 110, 0.09, 0.08);
        this.noise(t, 0.1, 'lowpass', 900, 300, 0.12);
        break;
      case 'upgrade':
        [523, 659, 784, 1047].forEach((f, i) => this.tone(t + i * 0.06, 'triangle', f, f, 0.1, 0.09));
        break;
      case 'sell':
        this.tone(t, 'square', 988, 988, 0.06, 0.06);
        this.tone(t + 0.07, 'square', 1319, 1319, 0.14, 0.06);
        break;
      case 'error':
        this.tone(t, 'square', 160, 140, 0.14, 0.07);
        break;
      case 'click':
        this.tone(t, 'triangle', 1200, 1000, 0.025, 0.05);
        break;
      case 'leak':
        this.tone(t, 'sawtooth', 240, 100, 0.4, 0.13);
        break;
      case 'heal':
        this.tone(t, 'sine', 700, 1100, 0.2, 0.04);
        break;
      case 'summon':
        this.tone(t, 'sawtooth', 110, 70, 0.5, 0.12);
        this.noise(t, 0.4, 'lowpass', 500, 200, 0.1);
        break;
      case 'waveStart':
        this.tone(t, 'sawtooth', 196, 196, 0.45, 0.07, 900);
        this.tone(t, 'sawtooth', 294, 294, 0.45, 0.07, 900);
        this.tone(t + 0.25, 'sawtooth', 392, 392, 0.5, 0.06, 1200);
        break;
      case 'waveClear':
        [659, 784, 988].forEach((f, i) => this.tone(t + i * 0.09, 'triangle', f, f, 0.18, 0.08));
        break;
      case 'win':
        [523, 659, 784, 1047, 784, 1047].forEach((f, i) =>
          this.tone(t + i * 0.13, 'triangle', f, f, i === 5 ? 0.6 : 0.16, 0.1));
        break;
      case 'lose':
        [392, 349, 311, 262].forEach((f, i) => this.tone(t + i * 0.22, 'sawtooth', f, f * 0.98, 0.3, 0.07, 1400));
        break;
    }
  }

  private tone(t: number, type: OscillatorType, from: number, to: number, dur: number, vol: number, lowpass?: number): void {
    const ctx = this.ctx!;
    const osc = ctx.createOscillator();
    osc.type = type;
    osc.frequency.setValueAtTime(from, t);
    if (to !== from) osc.frequency.exponentialRampToValueAtTime(Math.max(20, to), t + dur);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(vol, t + 0.005);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    let node: AudioNode = osc;
    if (lowpass) {
      const f = ctx.createBiquadFilter();
      f.type = 'lowpass';
      f.frequency.value = lowpass;
      osc.connect(f);
      node = f;
    }
    node.connect(gain).connect(this.sfxGain);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  }

  private noise(t: number, dur: number, type: BiquadFilterType, from: number, to: number, vol: number,
    out: GainNode = this.sfxGain): void {
    const ctx = this.ctx!;
    const src = ctx.createBufferSource();
    src.buffer = this.noiseBuffer;
    const filter = ctx.createBiquadFilter();
    filter.type = type;
    filter.frequency.setValueAtTime(from, t);
    if (to !== from) filter.frequency.exponentialRampToValueAtTime(to, t + dur);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(filter).connect(gain).connect(out);
    src.start(t, Math.random() * 0.5);
    src.stop(t + dur + 0.02);
  }

  // ---- music -----------------------------------------------------------------

  private startMusic(): void {
    if (this.timer !== null || !this.ctx) return;
    this.nextStepTime = this.ctx.currentTime + 0.1;
    // Look-ahead scheduler: a timer wakes up often and queues the notes of
    // the next few hundred milliseconds precisely on the audio clock.
    this.timer = window.setInterval(() => this.schedule(), 50);
  }

  private stopMusic(): void {
    if (this.timer !== null) window.clearInterval(this.timer);
    this.timer = null;
  }

  private schedule(): void {
    const ctx = this.ctx!;
    const sixteenth = 60 / BPM / 4;
    while (this.nextStepTime < ctx.currentTime + 0.25) {
      this.musicStep(this.nextStepTime, this.step);
      this.nextStepTime += sixteenth;
      this.step = (this.step + 1) % (16 * PROGRESSION.length);
    }
  }

  private musicStep(t: number, step: number): void {
    const ctx = this.ctx!;
    const bar = PROGRESSION[Math.floor(step / 16)];
    const s = step % 16;
    const note = (freq: number, dur: number, type: OscillatorType, vol: number, cutoff: number) => {
      const osc = ctx.createOscillator();
      osc.type = type;
      osc.frequency.value = freq;
      const f = ctx.createBiquadFilter();
      f.type = 'lowpass';
      f.frequency.value = cutoff;
      const g = ctx.createGain();
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      osc.connect(f).connect(g).connect(this.musicGain);
      osc.start(t);
      osc.stop(t + dur + 0.05);
    };
    const sixteenth = 60 / BPM / 4;
    if (s % 4 === 0) note(midi(bar.bass), sixteenth * 3.5, 'triangle', 0.22, 600);
    if (s % 2 === 0) note(midi(bar.chord[ARP[(s / 2) % ARP.length]] + 12), sixteenth * 1.8, 'square', 0.035, 1800);
    if (s === 0) for (const n of bar.chord) note(midi(n), sixteenth * 15, 'sine', 0.04, 1200);
    if (this.intensity > 0) {
      if (s % 4 === 0) this.kick(t);
      if (s % 2 === 1) this.noise(t, 0.04, 'highpass', 7000, 7000, 0.05, this.musicGain);
    }
  }

  private kick(t: number): void {
    const ctx = this.ctx!;
    const osc = ctx.createOscillator();
    osc.frequency.setValueAtTime(130, t);
    osc.frequency.exponentialRampToValueAtTime(40, t + 0.12);
    const g = ctx.createGain();
    g.gain.setValueAtTime(0.35, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.15);
    osc.connect(g).connect(this.musicGain);
    osc.start(t);
    osc.stop(t + 0.2);
  }
}

export const audio = new AudioEngine();
