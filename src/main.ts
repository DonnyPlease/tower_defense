import * as Phaser from 'phaser';
import { WIDTH, HEIGHT } from './config';
import { RES, COLORS } from './ui/theme';
import { BootScene } from './scenes/BootScene';
import { MenuScene } from './scenes/MenuScene';
import { LevelSelectScene } from './scenes/LevelSelectScene';
import { UpgradesScene } from './scenes/UpgradesScene';
import { GameScene } from './scenes/GameScene';
import { audio } from './audio/audio';
import { loadProfile } from './game/profile';

const profile = loadProfile();
audio.setSfx(profile.sfx);
audio.setMusic(profile.music);

// Browsers only allow audio after the player interacts with the page.
const unlockAudio = () => audio.unlock();
window.addEventListener('pointerdown', unlockAudio);
window.addEventListener('keydown', unlockAudio);

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
  audio: { noAudio: true }, // we synthesise our own sound (src/audio)
  // One texture per draw batch. With multi-texture batching some GPUs pick the
  // wrong texture for a sprite (turrets drawn clipped, black squares flashing).
  // This scene has few sprites, so the extra draw calls cost nothing noticeable.
  render: { maxTextures: 1 },
  scene: [BootScene, MenuScene, LevelSelectScene, UpgradesScene, GameScene],
});

// Handy for debugging from the browser console, e.g.
//   game.scene.getScene('game').world.spawn('boss')
(window as unknown as { game: Phaser.Game }).game = game;
