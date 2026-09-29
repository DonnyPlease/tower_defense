import type * as Phaser from 'phaser';
import { GEN } from '../ui/theme';

// Procedural art for the Gun and Missile towers. Everything is drawn in a
// 40 x 40 unit box (one tile), scaled by GEN so the textures stay sharp.
// Turrets point up; the base plate does not rotate.

type G = Phaser.GameObjects.Graphics;
const u = (v: number) => v * GEN;

export const TURRET_FRAMES = 7;

const STEEL = { dark: 0x23272e, mid: 0x3a4049, light: 0x59616d, shine: 0x8a939e };

/** Square steel plate with bevelled edges, bolts and an accent ring. */
export function drawBase(g: G, accent: number): void {
  g.fillStyle(0x000000, 0.25).fillRoundedRect(u(3.5), u(4.5), u(34), u(34), u(8)); // contact shadow
  g.fillStyle(STEEL.dark, 1).fillRoundedRect(u(3), u(3), u(34), u(34), u(8));
  g.fillStyle(STEEL.mid, 1).fillRoundedRect(u(4.5), u(4.5), u(31), u(31), u(7));
  // Bevel: light top-left edge, darker bottom-right edge.
  g.fillStyle(STEEL.light, 1).fillRoundedRect(u(4.5), u(4.5), u(31), u(3), u(2));
  g.fillStyle(STEEL.light, 1).fillRoundedRect(u(4.5), u(4.5), u(3), u(31), u(2));
  g.fillStyle(0x2d323a, 1).fillRoundedRect(u(6), u(6), u(28), u(28), u(6));
  // Diagonal tread plates.
  g.lineStyle(u(0.8), 0x363c45, 1);
  for (let i = 0; i < 6; i++) g.lineBetween(u(9 + i * 4.5), u(7), u(7), u(9 + i * 4.5));
  // Accent ring the turret sits in.
  g.fillStyle(0x1c1f25, 1).fillCircle(u(20), u(20), u(13));
  g.lineStyle(u(1.4), accent, 0.85).strokeCircle(u(20), u(20), u(12.5));
  // Corner bolts.
  for (const [x, y] of [[8, 8], [32, 8], [8, 32], [32, 32]]) {
    g.fillStyle(STEEL.dark, 1).fillCircle(u(x), u(y), u(2));
    g.fillStyle(STEEL.shine, 1).fillCircle(u(x - 0.5), u(y - 0.5), u(1));
  }
}

/** Twin-barrel gun. Frames 1-6 recoil the barrels and flash the muzzles. */
export function drawGunTurret(g: G, frame: number): void {
  const recoil = [0, 4, 3, 2, 1.2, 0.5, 0][frame] ?? 0;
  const top = 2.5 + recoil;

  // Barrels.
  for (const dx of [-3.4, 3.4]) {
    const x = 20 + dx;
    g.fillStyle(STEEL.dark, 1).fillRoundedRect(u(x - 2.2), u(top), u(4.4), u(19 - top), u(1.2));
    g.fillStyle(STEEL.mid, 1).fillRoundedRect(u(x - 1.6), u(top + 0.5), u(3.2), u(18 - top), u(1));
    g.fillStyle(STEEL.shine, 0.9).fillRect(u(x - 1.2), u(top + 2), u(0.9), u(14 - top));
    // Muzzle brake.
    g.fillStyle(0x15181c, 1).fillRoundedRect(u(x - 2.6), u(top - 0.5), u(5.2), u(3), u(0.8));
    g.fillStyle(0x000000, 1).fillCircle(u(x), u(top + 0.6), u(1));
    // Cooling rings.
    g.fillStyle(STEEL.dark, 1).fillRect(u(x - 2.3), u(top + 5), u(4.6), u(1)).fillRect(u(x - 2.3), u(top + 8), u(4.6), u(1));
  }
  // Armoured octagonal housing.
  const oct = (cx: number, cy: number, r: number) => Array.from({ length: 8 }, (_, i) => {
    const a = Math.PI / 8 + (i * Math.PI) / 4;
    return { x: u(cx + Math.cos(a) * r), y: u(cy + Math.sin(a) * r) };
  }) as Phaser.Math.Vector2[]; // fillPoints only reads x and y
  g.fillStyle(0x4a0a12, 1).fillPoints(oct(20, 25, 9.6), true);
  g.fillStyle(0xa81c29, 1).fillPoints(oct(20, 24.4, 8.8), true);
  g.fillStyle(0xe63946, 1).fillPoints(oct(19.6, 23.8, 7.4), true);
  g.fillStyle(0xff7a85, 0.85).fillEllipse(u(16.8), u(20.6), u(5), u(2.6));
  g.fillStyle(0xffffff, 0.75).fillEllipse(u(16.2), u(20.2), u(2), u(1));
  // Barrel mount across the front of the housing.
  g.fillStyle(STEEL.dark, 1).fillRoundedRect(u(13.5), u(15), u(13), u(4.5), u(1.5));
  g.fillStyle(STEEL.light, 1).fillRoundedRect(u(14.2), u(15.5), u(11.6), u(1.2), u(0.6));
  // Ammo drum on the side and a commander's hatch.
  g.fillStyle(STEEL.dark, 1).fillRoundedRect(u(26.5), u(21), u(4.5), u(8), u(1.5));
  g.fillStyle(0xc9a227, 1).fillRoundedRect(u(27.2), u(21.8), u(3), u(6.4), u(1));
  g.fillStyle(0xffe08a, 0.9).fillRect(u(27.6), u(22.4), u(0.8), u(5.2));
  g.fillStyle(0x3b0810, 1).fillCircle(u(20.5), u(26.5), u(2.6));
  g.fillStyle(0x8f1823, 1).fillCircle(u(20.2), u(26.2), u(1.8));
  g.fillStyle(STEEL.shine, 1).fillCircle(u(19.7), u(25.7), u(0.55));

  // Muzzle flash on the first frames of a shot.
  if (frame === 1 || frame === 2) {
    const s = frame === 1 ? 1 : 0.6;
    for (const dx of [-3.4, 3.4]) {
      const x = 20 + dx, y = top - 1.5;
      g.fillStyle(0xff9f1c, 0.85).fillTriangle(u(x), u(y - 7 * s), u(x - 2.6 * s), u(y + 0.5), u(x + 2.6 * s), u(y + 0.5));
      g.fillStyle(0xffd166, 1).fillTriangle(u(x), u(y - 5 * s), u(x - 1.6 * s), u(y + 0.5), u(x + 1.6 * s), u(y + 0.5));
      g.fillStyle(0xffffff, 1).fillCircle(u(x), u(y), u(1.4 * s));
    }
  }
}

/** Four-tube missile launcher. Frames 1-2 show a launch, 3-6 the reload. */
export function drawMissileTurret(g: G, frame: number): void {
  // Launcher box, slightly longer than wide.
  g.fillStyle(0x10301a, 1).fillRoundedRect(u(8.5), u(8), u(23), u(25), u(4));
  g.fillStyle(0x2e7d45, 1).fillRoundedRect(u(9.5), u(8.8), u(21), u(23), u(3.5));
  g.fillStyle(0x57c26b, 1).fillRoundedRect(u(10.5), u(9.8), u(19), u(21), u(3));
  g.fillStyle(0x8fe3a0, 0.9).fillRoundedRect(u(11), u(10.2), u(18), u(2.2), u(1));
  g.fillStyle(0x8fe3a0, 0.6).fillRoundedRect(u(11), u(10.2), u(2), u(19), u(1));
  // Camo patches.
  g.fillStyle(0x3f9a56, 1).fillEllipse(u(25.5), u(28), u(6), u(3)).fillEllipse(u(14), u(27.5), u(4), u(2.5));

  // Tubes: [x, y]; the first one fires and reloads.
  const tubes = [[15.5, 15.5], [24.5, 15.5], [15.5, 24], [24.5, 24]];
  // Missile nose size per frame for the firing tube (0 = empty).
  const reload = [1, 0, 0, 0.3, 0.6, 0.85, 1][frame] ?? 1;
  tubes.forEach(([x, y], i) => {
    g.fillStyle(0x0d1410, 1).fillCircle(u(x), u(y), u(3.8));
    g.fillStyle(0x3a4049, 1).fillCircle(u(x), u(y), u(3.2));
    g.fillStyle(0x121518, 1).fillCircle(u(x), u(y), u(2.6));
    const k = i === 0 ? reload : 1;
    if (k > 0) {
      g.fillStyle(0xb8202e, 1).fillCircle(u(x), u(y), u(2.3 * k));
      g.fillStyle(0xe63946, 1).fillCircle(u(x - 0.3), u(y - 0.3), u(1.7 * k));
      g.fillStyle(0xffffff, 0.85).fillCircle(u(x - 0.8), u(y - 0.8), u(0.6 * k));
    }
  });
  // Launch flash and smoke from the empty tube.
  if (frame === 1 || frame === 2) {
    const [x, y] = tubes[0];
    const s = frame === 1 ? 1 : 0.7;
    g.fillStyle(0xd9d9d9, 0.7).fillCircle(u(x), u(y - 1), u(4 * s));
    g.fillStyle(0xffd166, 0.9).fillCircle(u(x), u(y), u(2.2 * s));
    g.fillStyle(0xffffff, 1).fillCircle(u(x), u(y), u(1.1 * s));
  }

  // Targeting sensor at the front.
  g.fillStyle(0x15181c, 1).fillRoundedRect(u(16.5), u(3.5), u(7), u(5.5), u(1.5));
  g.fillStyle(STEEL.mid, 1).fillRoundedRect(u(17.2), u(4.2), u(5.6), u(4), u(1.2));
  g.fillStyle(0x7dffb0, 1).fillCircle(u(20), u(6.2), u(1.2));
  g.fillStyle(0xffffff, 0.9).fillCircle(u(19.6), u(5.8), u(0.45));
}

export const TOWER_ART = {
  gun: { accent: 0xe63946, turret: drawGunTurret },
  missile: { accent: 0x57c26b, turret: drawMissileTurret },
} as const;
