import * as Phaser from 'phaser';
import { MAPS, WIDTH, HEIGHT, ENEMY_TYPES, TICK_RATE } from '../config';
import { World } from '../sim/world';
import { FixedStep } from '../sim/fixedStep';
import { FieldView } from '../view/FieldView';
import { Button } from '../ui/Button';
import { COLORS, CSS, addText, setupCamera } from '../ui/theme';

// Where the attract-mode demo places its towers.
const DEMO_TOWERS = [
  { kind: 'gun', col: 13, row: 7 }, { kind: 'missile', col: 9, row: 11 },
  { kind: 'gun', col: 6, row: 9 }, { kind: 'missile', col: 14, row: 5 },
  { kind: 'missile', col: 17, row: 4 }, { kind: 'gun', col: 3, row: 13 },
] as const;

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
    this.world = new World(MAPS[0], { money: Infinity, lives: Infinity });
    for (const t of DEMO_TOWERS) this.world.build(t.kind, t.col, t.row);
    this.field = new FieldView(this, this.world);
    this.field.quiet = true;
    this.clock = new FixedStep();

    this.add.rectangle(0, 0, WIDTH, HEIGHT, COLORS.background, 0.55).setOrigin(0).setDepth(100);
    const panelW = 420, panelH = 330;
    const px = (WIDTH - panelW) / 2, py = (HEIGHT - panelH) / 2;
    this.add.graphics().setDepth(101)
      .fillStyle(COLORS.panel, 0.94).fillRoundedRect(px, py, panelW, panelH, 16)
      .lineStyle(1, COLORS.border, 1).strokeRoundedRect(px, py, panelW, panelH, 16);

    addText(this, WIDTH / 2, py + 50, 'TOWER DEFENSE', {
      fontSize: '40px', fontStyle: 'bold', color: CSS.gold, stroke: '#000000', strokeThickness: 4,
    }).setOrigin(0.5).setDepth(102);
    addText(this, WIDTH / 2, py + 92, 'Hold the line for 10 waves', {
      fontSize: '16px', color: CSS.textDim,
    }).setOrigin(0.5).setDepth(102);

    new Button(this, WIDTH / 2 - 110, py + 130, 220, 56, {
      label: 'Play', fontSize: 22, variant: 'primary',
      onClick: () => this.scene.start('game'),
    }).setDepth(102);

    addText(this, WIDTH / 2, py + 250, [
      'Click a tower in the sidebar, then click the grass to build.',
      'Q / W  pick tower   S  sell   Space  next wave',
      'Esc  pause / cancel   F  fast forward',
    ].join('\n'), {
      fontSize: '14px', color: CSS.textDim, align: 'center', lineSpacing: 6,
    }).setOrigin(0.5).setDepth(102);

    this.input.keyboard?.on('keydown-ENTER', () => this.scene.start('game'));
    this.input.keyboard?.on('keydown-SPACE', () => this.scene.start('game'));
  }

  update(_time: number, delta: number): void {
    const alpha = this.clock.advance(delta, 1, () => {
      if (this.world.tick % Math.round(TICK_RATE * 0.9) === 0 && this.world.enemies.length < 12) {
        this.world.spawn(ENEMY_TYPES[Math.floor(Math.random() * ENEMY_TYPES.length)]);
      }
      this.world.update();
    });
    this.field.handleEvents(this.world.events);
    this.field.sync(alpha);
  }
}
