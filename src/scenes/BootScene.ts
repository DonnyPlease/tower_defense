import * as Phaser from 'phaser';
import { WIDTH, HEIGHT } from '../config';
import { TOWERS, TOWER_KINDS } from '../data/towers';
import { COLORS, GEN, setupCamera } from '../ui/theme';
import { TOWER_ART, TURRET_FRAMES, drawBase } from '../view/towerArt';

// Sprite files shipped in public/assets.
const FILE_ENEMIES: Record<string, string> = { scout: 'enemy1', tank: 'enemy2', racer: 'enemy3' };

/** Loads sprites, draws the generated textures, then opens the menu. */
export class BootScene extends Phaser.Scene {
  constructor() {
    super('boot');
  }

  preload(): void {
    setupCamera(this);
    const bar = this.add.graphics();
    this.load.on('progress', (p: number) => {
      bar.clear();
      bar.fillStyle(COLORS.panelLight, 1).fillRoundedRect(WIDTH / 2 - 150, HEIGHT / 2 - 8, 300, 16, 8);
      bar.fillStyle(COLORS.accent, 1).fillRoundedRect(WIDTH / 2 - 150, HEIGHT / 2 - 8, Math.max(16, 300 * p), 16, 8);
    });
    for (const kind of TOWER_KINDS) {
      const def = TOWERS[kind] as { sprite?: string; frames: number };
      if (!def.sprite) continue;
      for (let i = 0; i < def.frames; i++) this.load.image(`${kind}-${i}`, `assets/towers/${def.sprite}/${i}.png`);
    }
    for (const [type, folder] of Object.entries(FILE_ENEMIES)) {
      this.load.image(`enemy-${type}`, `assets/enemies/${folder}/0.png`);
    }
  }

  create(): void {
    const g = this.make.graphics({}, false);
    const tex = (key: string, w: number, h: number, draw: (g: Phaser.GameObjects.Graphics) => void) => {
      g.clear();
      draw(g);
      g.generateTexture(key, w, h);
    };

    // ---- effects (native size) ----
    tex('dot', 16, 16, (g) => g.fillStyle(0xffffff, 1).fillCircle(8, 8, 8));
    tex('ring', 128, 128, (g) => g.lineStyle(6, 0xffffff, 1).strokeCircle(64, 64, 60));
    tex('shadow', 32, 20, (g) => g.fillStyle(0x000000, 0.28).fillEllipse(16, 10, 32, 20));
    tex('bullet', 12, 4, (g) => {
      g.fillStyle(0xfff3b0, 1).fillRoundedRect(0, 0, 12, 4, 2);
      g.fillStyle(0xffffff, 1).fillRoundedRect(7, 0, 5, 4, 2);
    });
    tex('missile', 14, 7, (g) => {
      g.fillStyle(0x6c757d, 1).fillRect(0, 1, 10, 5);
      g.fillStyle(0xe63946, 1).fillTriangle(10, 0, 14, 3.5, 10, 7);
      g.fillStyle(0xffb703, 1).fillRect(0, 2, 2, 3);
    });
    tex('shell', 12, 12, (g) => {
      g.fillStyle(0x222831, 1).fillCircle(6, 6, 6);
      g.fillStyle(0x6c757d, 1).fillCircle(4, 4, 2);
    });

    // ---- towers (GEN x size, pointing up) ----
    const S = 40 * GEN, c = S / 2;
    // Gun and missile: a still base plate, animated turret frames, and an icon of both.
    for (const [kind, art] of Object.entries(TOWER_ART)) {
      tex(`${kind}-base`, S, S, (g) => drawBase(g, art.accent));
      for (let i = 0; i < TURRET_FRAMES; i++) tex(`${kind}-${i}`, S, S, (g) => art.turret(g, i));
      tex(`${kind}-icon`, S, S, (g) => { drawBase(g, art.accent); art.turret(g, 0); });
    }
    tex('cannon-0', S, S, (g) => {
      g.fillStyle(0x3d4451, 1).fillRoundedRect(4 * GEN, 4 * GEN, 32 * GEN, 32 * GEN, 7 * GEN);
      g.fillStyle(0x5c6677, 1).fillCircle(c, c + 3 * GEN, 11 * GEN);
      g.fillStyle(0x2b3038, 1).fillRoundedRect(c - 5 * GEN, 1 * GEN, 10 * GEN, 20 * GEN, 3 * GEN);
      g.fillStyle(0x8d99ae, 1).fillCircle(c - 3 * GEN, c, 3 * GEN);
    });
    tex('frost-0', S, S, (g) => {
      g.fillStyle(0x1d4e89, 1).fillCircle(c, c, 16 * GEN);
      g.fillStyle(0x7ad3ff, 1).fillTriangle(c, 5 * GEN, c + 9 * GEN, c, c - 9 * GEN, c);
      g.fillStyle(0x4aa8e0, 1).fillTriangle(c - 9 * GEN, c, c + 9 * GEN, c, c, S - 5 * GEN);
      g.fillStyle(0xffffff, 0.85).fillTriangle(c, 8 * GEN, c + 3 * GEN, c - 2 * GEN, c - 3 * GEN, c - 2 * GEN);
    });
    tex('laser-0', S, S, (g) => {
      g.fillStyle(0x2d1b3d, 1).fillCircle(c, c, 16 * GEN);
      g.fillStyle(0x5a2d82, 1).fillCircle(c, c + 2 * GEN, 10 * GEN);
      g.fillStyle(0x3b1f52, 1).fillRect(c - 3 * GEN, 3 * GEN, 6 * GEN, 16 * GEN);
      g.fillStyle(0xd35cff, 1).fillCircle(c, 5 * GEN, 3 * GEN);
      g.fillStyle(0xf5d0ff, 1).fillCircle(c, c + 2 * GEN, 4 * GEN);
    });
    tex('support-0', S, S, (g) => {
      g.fillStyle(0x5c4a14, 1).fillRoundedRect(6 * GEN, 6 * GEN, 28 * GEN, 28 * GEN, 6 * GEN);
      g.lineStyle(2 * GEN, 0xf5c542, 1).strokeCircle(c, c, 11 * GEN);
      g.fillStyle(0xf5c542, 1).fillCircle(c, c, 5 * GEN);
      g.fillStyle(0xfff3b0, 1).fillCircle(c, c, 2 * GEN);
    });

    // ---- enemies (GEN x size, facing right) ----
    tex('enemy-armored', S, S, (g) => {
      g.fillStyle(0x1b1f24, 1).fillRect(4 * GEN, 5 * GEN, 32 * GEN, 6 * GEN).fillRect(4 * GEN, 29 * GEN, 32 * GEN, 6 * GEN);
      g.fillStyle(0x4f5b66, 1).fillRoundedRect(6 * GEN, 9 * GEN, 28 * GEN, 22 * GEN, 3 * GEN);
      g.lineStyle(1.5 * GEN, 0x2b3038, 1);
      for (const x of [13, 20, 27]) g.lineBetween(x * GEN, 10 * GEN, x * GEN, 30 * GEN);
      g.fillStyle(0x6c7a86, 1).fillCircle(c, c, 6 * GEN);
      g.fillStyle(0x2b3038, 1).fillRect(c, c - 1.5 * GEN, 15 * GEN, 3 * GEN);
    });
    tex('enemy-shielded', S, S, (g) => {
      g.fillStyle(0x1b1f24, 1).fillRect(6 * GEN, 7 * GEN, 28 * GEN, 5 * GEN).fillRect(6 * GEN, 28 * GEN, 28 * GEN, 5 * GEN);
      g.fillStyle(0x16a085, 1).fillRoundedRect(8 * GEN, 10 * GEN, 24 * GEN, 20 * GEN, 5 * GEN);
      g.fillStyle(0x48dbc3, 1).fillCircle(c, c, 6 * GEN);
      g.fillStyle(0xe0fff9, 1).fillCircle(c + 2 * GEN, c - 2 * GEN, 2 * GEN);
    });
    tex('enemy-splitter', S, S, (g) => {
      g.fillStyle(0x6a2c91, 1).fillCircle(c - 6 * GEN, c - 6 * GEN, 9 * GEN)
        .fillCircle(c - 6 * GEN, c + 6 * GEN, 9 * GEN).fillCircle(c + 6 * GEN, c, 10 * GEN);
      g.fillStyle(0xb15cf0, 1).fillCircle(c - 6 * GEN, c - 6 * GEN, 5 * GEN)
        .fillCircle(c - 6 * GEN, c + 6 * GEN, 5 * GEN).fillCircle(c + 6 * GEN, c, 6 * GEN);
      g.fillStyle(0xffffff, 1).fillCircle(c + 9 * GEN, c - 2 * GEN, 2 * GEN);
    });
    tex('enemy-healer', S, S, (g) => {
      g.fillStyle(0x1b1f24, 1).fillRect(6 * GEN, 7 * GEN, 28 * GEN, 5 * GEN).fillRect(6 * GEN, 28 * GEN, 28 * GEN, 5 * GEN);
      g.fillStyle(0xf1f3f5, 1).fillRoundedRect(7 * GEN, 10 * GEN, 26 * GEN, 20 * GEN, 4 * GEN);
      g.fillStyle(0xe03131, 1).fillRect(c - 2.5 * GEN, c - 7 * GEN, 5 * GEN, 14 * GEN).fillRect(c - 7 * GEN, c - 2.5 * GEN, 14 * GEN, 5 * GEN);
    });
    tex('enemy-drone', S, S, (g) => {
      g.lineStyle(3 * GEN, 0x343a40, 1);
      g.lineBetween(8 * GEN, 8 * GEN, 32 * GEN, 32 * GEN).lineBetween(8 * GEN, 32 * GEN, 32 * GEN, 8 * GEN);
      g.fillStyle(0x868e96, 0.8);
      for (const [x, y] of [[8, 8], [32, 8], [8, 32], [32, 32]]) g.fillCircle(x * GEN, y * GEN, 6 * GEN);
      g.fillStyle(0xf08c00, 1).fillCircle(c, c, 7 * GEN);
      g.fillStyle(0xffe066, 1).fillCircle(c + 3 * GEN, c, 2.5 * GEN);
    });

    g.destroy();
    this.scene.start('menu');
  }
}
