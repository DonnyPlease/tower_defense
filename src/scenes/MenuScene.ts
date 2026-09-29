import * as Phaser from 'phaser';
import { WIDTH, HEIGHT, TICK_RATE } from '../config';
import { LEVELS, levelById } from '../data/levels';
import type { EnemyType } from '../data/enemies';
import { World } from '../sim/world';
import { FixedStep } from '../sim/fixedStep';
import { FieldView } from '../view/FieldView';
import { Button } from '../ui/Button';
import { COLORS, CSS, addText, setupCamera } from '../ui/theme';
import { loadProfile, saveProfile, totalStars } from '../game/profile';
import { audio } from '../audio/audio';

// Where the attract-mode demo places its towers.
const DEMO_TOWERS = [
  { kind: 'gun', col: 13, row: 7 }, { kind: 'missile', col: 9, row: 11 },
  { kind: 'cannon', col: 6, row: 9 }, { kind: 'laser', col: 14, row: 5 },
  { kind: 'frost', col: 9, row: 7 }, { kind: 'missile', col: 17, row: 4 },
  { kind: 'gun', col: 3, row: 13 }, { kind: 'support', col: 14, row: 8 },
] as const;
const DEMO_ENEMIES: EnemyType[] = ['scout', 'racer', 'tank', 'shielded', 'drone', 'healer', 'splitter', 'armored'];

/** Title screen with a live, self-playing game in the background. */
export class MenuScene extends Phaser.Scene {
  private world!: World;
  private field!: FieldView;
  private clock!: FixedStep;

  constructor() {
    super('menu');
  }

  create(): void {
    setupCamera(this);
    this.world = new World(levelById(LEVELS[0].id));
    this.world.money = Infinity;
    this.world.lives = Infinity;
    for (const t of DEMO_TOWERS) {
      const tower = this.world.build(t.kind, t.col, t.row);
      if (tower) tower.level = (t.col + t.row) % 3;
    }
    this.field = new FieldView(this, this.world);
    this.field.quiet = true;
    this.clock = new FixedStep();

    this.add.rectangle(0, 0, WIDTH, HEIGHT, COLORS.background, 0.55).setOrigin(0).setDepth(100);
    const profile = loadProfile();
    const hasSave = profile.save !== null;
    const panelW = 420, panelH = hasSave ? 420 : 360;
    const px = (WIDTH - panelW) / 2, py = (HEIGHT - panelH) / 2;
    this.add.graphics().setDepth(101)
      .fillStyle(COLORS.panel, 0.94).fillRoundedRect(px, py, panelW, panelH, 16)
      .lineStyle(1, COLORS.border, 1).strokeRoundedRect(px, py, panelW, panelH, 16);

    addText(this, WIDTH / 2, py + 48, 'TOWER DEFENSE', {
      fontSize: '40px', fontStyle: 'bold', color: CSS.gold, stroke: '#000000', strokeThickness: 4,
    }).setOrigin(0.5).setDepth(102);
    addText(this, WIDTH / 2, py + 88, `★ ${totalStars(profile)} stars earned`, {
      fontSize: '16px', color: CSS.textDim,
    }).setOrigin(0.5).setDepth(102);

    let y = py + 118;
    const button = (label: string, variant: 'primary' | 'default', onClick: () => void, sub?: string) => {
      new Button(this, WIDTH / 2 - 130, y, 260, 50, { label, sublabel: sub, fontSize: 19, variant, onClick }).setDepth(102);
      y += 60;
    };
    if (hasSave) {
      const save = profile.save!;
      const name = save.endless ? 'Endless' : levelById(save.levelId).name;
      button('Continue', 'primary', () => this.scene.start('game', { levelId: save.levelId, resume: true }),
        `${name} · wave ${save.waveIndex + 2}`);
    }
    button('Play', hasSave ? 'default' : 'primary', () => this.scene.start('levels'));
    button('Upgrades', 'default', () => this.scene.start('upgrades'));

    const music = new Button(this, WIDTH / 2 - 130, y + 6, 125, 40, {
      label: '', fontSize: 14,
      onClick: () => { profile.music = !profile.music; audio.setMusic(profile.music); saveProfile(profile); refresh(); },
    }).setDepth(102);
    const sfx = new Button(this, WIDTH / 2 + 5, y + 6, 125, 40, {
      label: '', fontSize: 14,
      onClick: () => { profile.sfx = !profile.sfx; audio.setSfx(profile.sfx); saveProfile(profile); refresh(); },
    }).setDepth(102);
    const refresh = () => {
      music.setLabel(`♪ Music ${profile.music ? 'on' : 'off'}`, profile.music ? CSS.text : CSS.textDim).setSelected(profile.music);
      sfx.setLabel(`Sound ${profile.sfx ? 'on' : 'off'}`, profile.sfx ? CSS.text : CSS.textDim).setSelected(profile.sfx);
    };
    refresh();

    addText(this, WIDTH / 2, py + panelH - 22, '1-6 build  ·  U upgrade  ·  S sell  ·  T target  ·  Space wave  ·  F speed', {
      fontSize: '12px', color: CSS.textDim,
    }).setOrigin(0.5).setDepth(102);

    const start = () => this.scene.start(hasSave ? 'game' : 'levels',
      hasSave ? { levelId: profile.save!.levelId, resume: true } : undefined);
    this.input.keyboard?.on('keydown-ENTER', start);
  }

  update(_time: number, delta: number): void {
    const alpha = this.clock.advance(delta, 1, () => {
      if (this.world.tick % Math.round(TICK_RATE * 0.9) === 0 && this.world.enemies.length < 14) {
        this.world.spawn(DEMO_ENEMIES[Math.floor(Math.random() * DEMO_ENEMIES.length)]);
      }
      this.world.update();
    });
    this.field.handleEvents(this.world.events);
    this.field.sync(alpha);
  }
}
