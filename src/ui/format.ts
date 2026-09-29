// Pure formatting and maths helpers for the UI. No Phaser here, so they can
// be unit-tested in Node.
import { towerDef, type TowerKind } from '../data/towers';

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/** Interpolates between two angles along the shorter way round. */
export function lerpAngle(a: number, b: number, t: number): number {
  const diff = Math.atan2(Math.sin(b - a), Math.cos(b - a));
  return a + diff * t;
}

export function starString(stars: number, max = 3): string {
  return '★'.repeat(stars) + '☆'.repeat(Math.max(0, max - stars));
}

/** Stat lines shown in the sidebar for a tower at a given level. */
export function towerStatsText(kind: TowerKind, level: number, opts: { range?: number; buff?: number } = {}): string {
  const d = towerDef(kind), s = d.levels[level];
  const range = Math.round(opts.range ?? s.range);
  switch (d.behavior) {
    case 'projectile': {
      const lines = [`Damage ${s.damage}  ·  ${s.fireRate.toFixed(1)}/s`, `Range ${range}`];
      if (s.splash) lines[1] += `  ·  Splash ${s.splash}`;
      if (opts.buff) lines.push(`Boosted +${Math.round(opts.buff * 100)}% fire rate`);
      return lines.join('\n');
    }
    case 'beam':
      return `${s.damage} dps, heats to ${s.damage * 3}\nRange ${range}`;
    case 'aura':
      return `Slow ${Math.round((s.slow ?? 0) * 100)}%  ·  ${s.damage} dmg/s\nRange ${range}`;
    case 'support':
      return `+${Math.round((s.buff ?? 0) * 100)}% fire rate nearby\nRange ${range}`;
  }
}
