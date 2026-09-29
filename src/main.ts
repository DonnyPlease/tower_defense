import * as Phaser from 'phaser';
import { WIDTH, HEIGHT } from './config';
import { RES, COLORS } from './ui/theme';
import { BootScene } from './scenes/BootScene';
import { MenuScene } from './scenes/MenuScene';
import { GameScene } from './scenes/GameScene';

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: 'game',
  backgroundColor: COLORS.background,
  width: WIDTH * RES,
  height: HEIGHT * RES,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  scene: [BootScene, MenuScene, GameScene],
});

// Handy for debugging from the browser console.
(window as unknown as { game: Phaser.Game }).game = game;
