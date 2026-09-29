import * as Phaser from 'phaser';
import { FIELD_W, SIDEBAR_W, HEIGHT, TOWERS, TOWER_KINDS, SELL_REFUND, type TowerKind } from '../config';
import type { World } from '../sim/world';
import { Button } from './Button';
import { COLORS, CSS, addText } from './theme';

export type Tool = TowerKind | 'sell' | null;

/** What the sidebar needs from the game scene. */
export interface HudHost {
  readonly world: World;
  tool: Tool;
  paused: boolean;
  speed: number;
  selectTool(tool: Tool): void;
  startWave(): void;
  togglePause(): void;
  toggleSpeed(): void;
  /** Tower-kind or tile info to show in the info box, if any. */
  infoSubject(): TowerKind | 'sell' | null;
}

const X = FIELD_W + 12;
const W = SIDEBAR_W - 24;
const DEPTH = 100;

/** The right-hand sidebar: stats, build buttons, info box and wave controls. */
export class Hud {
  private readonly moneyText: Phaser.GameObjects.Text;
  private readonly livesText: Phaser.GameObjects.Text;
  private readonly waveText: Phaser.GameObjects.Text;
  private readonly infoTitle: Phaser.GameObjects.Text;
  private readonly infoBody: Phaser.GameObjects.Text;
  private readonly towerButtons = new Map<TowerKind, Button>();
  private readonly sellButton: Button;
  private readonly waveButton: Button;
  private readonly pauseButton: Button;
  private readonly speedButton: Button;

  constructor(scene: Phaser.Scene, private readonly host: HudHost) {
    scene.add.rectangle(FIELD_W, 0, SIDEBAR_W, HEIGHT, COLORS.panel).setOrigin(0).setDepth(DEPTH);
    scene.add.rectangle(FIELD_W, 0, 2, HEIGHT, COLORS.border).setOrigin(0).setDepth(DEPTH);

    const stat = (y: number, color: string) =>
      addText(scene, X + 4, y, '', { fontSize: '20px', fontStyle: 'bold', color }).setDepth(DEPTH);
    this.moneyText = stat(14, CSS.gold);
    this.livesText = stat(42, CSS.red);
    this.waveText = stat(70, CSS.text);

    let y = 108;
    for (const kind of TOWER_KINDS) {
      const def = TOWERS[kind];
      const b = new Button(scene, X, y, W, 60, {
        label: def.name, sublabel: `$${def.cost}`, icon: `${kind}-0`, hotkey: def.hotkey,
        onClick: () => host.selectTool(host.tool === kind ? null : kind),
      }).setDepth(DEPTH);
      this.towerButtons.set(kind, b);
      y += 68;
    }
    this.sellButton = new Button(scene, X, y, W, 44, {
      label: 'Sell', icon: 'sell-icon', hotkey: 'S',
      onClick: () => host.selectTool(host.tool === 'sell' ? null : 'sell'),
    }).setDepth(DEPTH);
    y += 56;

    scene.add.graphics().setDepth(DEPTH)
      .fillStyle(COLORS.panelLight, 0.6).fillRoundedRect(X, y, W, 150, 8);
    this.infoTitle = addText(scene, X + 10, y + 8, '', { fontSize: '15px', fontStyle: 'bold' }).setDepth(DEPTH);
    this.infoBody = addText(scene, X + 10, y + 30, '', {
      fontSize: '13px', color: CSS.textDim, lineSpacing: 2, wordWrap: { width: W - 20 },
    }).setDepth(DEPTH);

    this.waveButton = new Button(scene, X, 470, W, 56, {
      label: 'Start wave', sublabel: '', variant: 'primary',
      onClick: () => host.startWave(),
    }).setDepth(DEPTH);
    const half = (W - 8) / 2;
    this.pauseButton = new Button(scene, X, 536, half, 48, {
      label: 'Pause', onClick: () => host.togglePause(),
    }).setDepth(DEPTH);
    this.speedButton = new Button(scene, X + half + 8, 536, half, 48, {
      label: '1x', onClick: () => host.toggleSpeed(),
    }).setDepth(DEPTH);
  }

  /** Called every frame; only touches objects whose content changed. */
  refresh(): void {
    const { world, tool } = this.host;
    setText(this.moneyText, `$ ${world.money}`);
    setText(this.livesText, `♥ ${world.lives}`);
    setText(this.waveText, `Wave ${Math.max(0, world.waveIndex + 1)} / ${world.waves.length}`);

    for (const [kind, b] of this.towerButtons) {
      b.setSelected(tool === kind).setEnabled(world.status === 'playing' && world.canAfford(kind));
    }
    this.sellButton.setSelected(tool === 'sell').setEnabled(world.status === 'playing');

    if (world.waveInProgress) {
      this.waveButton.setLabel(`Wave ${world.waveIndex + 1}`).setSublabel(`${world.enemiesRemaining} enemies left`)
        .setEnabled(false);
    } else if (world.waveIndex >= world.waves.length - 1) {
      this.waveButton.setLabel('All waves done').setSublabel(world.status === 'won' ? 'Victory!' : '').setEnabled(false);
    } else if (world.waveIndex < 0) {
      this.waveButton.setLabel('Start wave 1').setSublabel('Space · build first!').setEnabled(world.canStartWave);
    } else {
      this.waveButton.setLabel(`Start wave ${world.waveIndex + 2}`).setSublabel('Space · ready').setEnabled(world.canStartWave);
    }
    this.pauseButton.setLabel(this.host.paused ? 'Resume' : 'Pause');
    this.speedButton.setLabel(`${this.host.speed}x`).setSelected(this.host.speed > 1);

    this.refreshInfo();
  }

  private refreshInfo(): void {
    const subject = this.host.infoSubject();
    if (subject === 'sell') {
      setText(this.infoTitle, 'Sell');
      setText(this.infoBody, `Click a tower to sell it for ${SELL_REFUND * 100}% of its price.\n\nRight-click or Esc to cancel.`);
    } else if (subject) {
      const d = TOWERS[subject];
      const dps = (d.damage * d.fireRate).toFixed(1);
      setText(this.infoTitle, `${d.name}  ·  $${d.cost}`);
      setText(this.infoBody, [
        `Damage ${d.damage} × ${d.fireRate}/s = ${dps} dps`,
        `Range ${d.range}`,
        '',
        d.description,
      ].join('\n'));
    } else {
      setText(this.infoTitle, 'How to play');
      setText(this.infoBody, 'Pick a tower above, then click the grass to build.\n\nStop the enemies before they reach the right edge.');
    }
  }
}

function setText(t: Phaser.GameObjects.Text, s: string): void {
  if (t.text !== s) t.setText(s);
}
