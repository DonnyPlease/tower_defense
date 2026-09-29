import * as Phaser from 'phaser';
import { TOWERS, ENEMIES, WIDTH, HEIGHT, TOWER_KINDS, ENEMY_TYPES } from '../config';
import { ANIMATION_FRAMES } from '../sim/tower';
import { COLORS, setupCamera } from '../ui/theme';

/** Loads all sprites, generates a few simple textures, then opens the menu. */
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
      for (let i = 0; i < ANIMATION_FRAMES; i++) {
        this.load.image(`${kind}-${i}`, `assets/towers/${TOWERS[kind].sprite}/${i}.png`);
      }
    }
    for (const type of ENEMY_TYPES) {
      this.load.image(`enemy-${type}`, `assets/enemies/${ENEMIES[type].sprite}/0.png`);
    }
    this.load.image('sell-icon', 'assets/sell/icon.png');
  }

  create(): void {
    const g = this.make.graphics({}, false);

    // Soft round particle.
    g.fillStyle(0xffffff, 1).fillCircle(8, 8, 8);
    g.generateTexture('dot', 16, 16);

    // Drop shadow under towers and enemies.
    g.clear().fillStyle(0x000000, 0.28).fillEllipse(16, 10, 32, 20);
    g.generateTexture('shadow', 32, 20);

    // Gun bullet: a short bright streak pointing right.
    g.clear().fillStyle(0xfff3b0, 1).fillRoundedRect(0, 0, 12, 4, 2);
    g.fillStyle(0xffffff, 1).fillRoundedRect(7, 0, 5, 4, 2);
    g.generateTexture('bullet', 12, 4);

    // Missile: grey body, red nose, pointing right.
    g.clear().fillStyle(0x6c757d, 1).fillRect(0, 1, 10, 5);
    g.fillStyle(0xe63946, 1).fillTriangle(10, 0, 14, 3.5, 10, 7);
    g.fillStyle(0xffb703, 1).fillRect(0, 2, 2, 3);
    g.generateTexture('missile', 14, 7);

    g.destroy();
    this.scene.start('menu');
  }
}
