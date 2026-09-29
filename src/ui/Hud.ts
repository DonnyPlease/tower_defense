import * as Phaser from 'phaser';
import { FIELD_W, SIDEBAR_W, HEIGHT } from '../config';
import { TOWER_KINDS, towerDef, type TowerKind, type TargetMode } from '../data/towers';
import { enemyDef, type EnemyType } from '../data/enemies';
import type { World } from '../sim/world';
import type { Tower } from '../sim/tower';
import { Button } from './Button';
import { COLORS, CSS, addText, spriteScale, towerIcon } from './theme';
import { towerStatsText } from './format';

/** What the sidebar needs from the game scene. */
export interface HudHost {
  readonly world: World;
  readonly tool: TowerKind | null;
  readonly selected: Tower | null;
  readonly paused: boolean;
  readonly speed: number;
  readonly musicOn: boolean;
  readonly sfxOn: boolean;
  selectTool(tool: TowerKind | null): void;
  startWave(): void;
  togglePause(): void;
  toggleSpeed(): void;
  toggleMusic(): void;
  toggleSfx(): void;
  upgradeSelected(): void;
  sellSelected(): void;
  cycleTargetMode(): void;
}

const X = FIELD_W + 12;
const W = SIDEBAR_W - 24;
const DEPTH = 100;
const PANEL_Y = 270;
const PANEL_H = 196;

const MODE_LABEL: Record<TargetMode, string> = {
  first: 'First', last: 'Last', strongest: 'Strongest', closest: 'Closest',
};

/** The right-hand sidebar: stats, build grid, context panel and wave controls. */
export class Hud {
  private readonly moneyText: Phaser.GameObjects.Text;
  private readonly livesText: Phaser.GameObjects.Text;
  private readonly waveText: Phaser.GameObjects.Text;
  private readonly towerButtons = new Map<TowerKind, Button>();
  private readonly panelTitle: Phaser.GameObjects.Text;
  private readonly panelBody: Phaser.GameObjects.Text;
  private readonly upgradeButton: Button;
  private readonly targetButton: Button;
  private readonly sellButton: Button;
  private readonly previewLabel: Phaser.GameObjects.Text;
  private previewObjects: Phaser.GameObjects.GameObject[] = [];
  private previewKey = '';
  private readonly waveButton: Button;
  private readonly pauseButton: Button;
  private readonly speedButton: Button;
  private readonly musicButton: Button;
  private readonly sfxButton: Button;
  private hovered: TowerKind | null = null;

  constructor(private readonly scene: Phaser.Scene, private readonly host: HudHost) {
    scene.add.rectangle(FIELD_W, 0, SIDEBAR_W, HEIGHT, COLORS.panel).setOrigin(0).setDepth(DEPTH);
    scene.add.rectangle(FIELD_W, 0, 2, HEIGHT, COLORS.border).setOrigin(0).setDepth(DEPTH);

    const stat = (y: number, color: string) =>
      addText(scene, X + 4, y, '', { fontSize: '19px', fontStyle: 'bold', color }).setDepth(DEPTH);
    this.moneyText = stat(10, CSS.gold);
    this.livesText = stat(36, CSS.red);
    this.waveText = stat(62, CSS.text);

    // 2 x 3 grid of build buttons.
    const cellW = (W - 8) / 2, cellH = 54;
    TOWER_KINDS.forEach((kind, i) => {
      const bx = X + (i % 2) * (cellW + 8), by = 94 + Math.floor(i / 2) * (cellH + 6);
      const b = new Button(scene, bx, by, cellW, cellH, {
        label: '', icon: towerIcon(scene, kind), hotkey: String(i + 1), layout: 'tile', fontSize: 13,
        onClick: () => host.selectTool(host.tool === kind ? null : kind),
        onHover: (on) => { this.hovered = on ? kind : this.hovered === kind ? null : this.hovered; },
      }).setDepth(DEPTH);
      this.towerButtons.set(kind, b);
    });

    // Context panel: selected tower, or info about a tower type, or tips.
    scene.add.graphics().setDepth(DEPTH)
      .fillStyle(COLORS.panelLight, 0.6).fillRoundedRect(X, PANEL_Y, W, PANEL_H, 8);
    this.panelTitle = addText(scene, X + 10, PANEL_Y + 8, '', { fontSize: '15px', fontStyle: 'bold' }).setDepth(DEPTH);
    this.panelBody = addText(scene, X + 10, PANEL_Y + 30, '', {
      fontSize: '12px', color: CSS.textDim, lineSpacing: 2, wordWrap: { width: W - 20 },
    }).setDepth(DEPTH);
    this.upgradeButton = new Button(scene, X + 8, PANEL_Y + 86, W - 16, 36, {
      label: 'Upgrade', hotkey: 'U', variant: 'primary', fontSize: 14, onClick: () => host.upgradeSelected(),
    }).setDepth(DEPTH);
    this.targetButton = new Button(scene, X + 8, PANEL_Y + 126, W - 16, 30, {
      label: 'Target: First', hotkey: 'T', fontSize: 13, onClick: () => host.cycleTargetMode(),
    }).setDepth(DEPTH);
    this.sellButton = new Button(scene, X + 8, PANEL_Y + 160, W - 16, 30, {
      label: 'Sell', hotkey: 'S', variant: 'danger', fontSize: 13, onClick: () => host.sellSelected(),
    }).setDepth(DEPTH);

    this.previewLabel = addText(scene, X, 474, 'Next:', { fontSize: '12px', color: CSS.textDim }).setDepth(DEPTH);

    this.waveButton = new Button(scene, X, 494, W, 50, {
      label: 'Start wave', sublabel: '', variant: 'primary', fontSize: 15, onClick: () => host.startWave(),
    }).setDepth(DEPTH);
    const q = (W - 3 * 6) / 4;
    const small = (i: number, label: string, onClick: () => void) =>
      new Button(scene, X + i * (q + 6), 552, q, 38, { label, fontSize: 14, onClick }).setDepth(DEPTH);
    this.pauseButton = small(0, 'II', () => host.togglePause());
    this.speedButton = small(1, '1x', () => host.toggleSpeed());
    this.musicButton = small(2, '♪', () => host.toggleMusic());
    this.sfxButton = small(3, 'FX', () => host.toggleSfx());
  }

  /** Called every frame; only touches objects whose content changed. */
  refresh(): void {
    const { world, tool } = this.host;
    setText(this.moneyText, `$ ${world.money}`);
    setText(this.livesText, `♥ ${world.lives}`);
    const total = world.totalWaves;
    setText(this.waveText, `Wave ${Math.max(0, world.waveIndex + 1)}${total ? ` / ${total}` : ''}`);

    for (const [kind, b] of this.towerButtons) {
      if (!world.isUnlocked(kind)) {
        b.setLabel(`★ ${towerDef(kind).unlockStars}`, CSS.textDim).setEnabled(false).setSelected(false);
      } else {
        const cost = world.costOf(kind);
        b.setLabel(`$${cost}`, world.money >= cost ? CSS.text : CSS.red)
          .setSelected(tool === kind).setEnabled(world.status === 'playing');
      }
    }

    this.refreshPanel();
    this.refreshPreview();

    if (world.status !== 'playing') {
      this.waveButton.setLabel('Game over').setSublabel('').setEnabled(false);
    } else if (!world.nextWave) {
      this.waveButton.setLabel('Final wave').setSublabel(`${world.enemiesRemaining} enemies left`).setEnabled(false);
    } else if (world.spawning) {
      this.waveButton.setLabel(`Wave ${world.waveIndex + 1}`).setSublabel(`${world.enemiesRemaining} enemies left`)
        .setEnabled(false);
    } else if (world.earlyBonusNow > 0) {
      this.waveButton.setLabel(`Call wave ${world.waveIndex + 2}`).setSublabel(`Space · +$${world.earlyBonusNow} early`, CSS.gold)
        .setEnabled(true);
    } else {
      this.waveButton.setLabel(`Start wave ${world.waveIndex + 2}`)
        .setSublabel(world.waveIndex < 0 ? 'Space · build first!' : 'Space · ready').setEnabled(true);
    }
    this.pauseButton.setLabel(this.host.paused ? '▶' : 'II');
    this.speedButton.setLabel(`${this.host.speed}x`).setSelected(this.host.speed > 1);
    this.musicButton.setLabel('♪', this.host.musicOn ? CSS.text : CSS.textDim).setSelected(this.host.musicOn);
    this.sfxButton.setLabel('FX', this.host.sfxOn ? CSS.text : CSS.textDim).setSelected(this.host.sfxOn);
  }

  private refreshPanel(): void {
    const { world, selected, tool } = this.host;
    const showTowerButtons = selected !== null;
    this.upgradeButton.setVisible(showTowerButtons);
    this.targetButton.setVisible(showTowerButtons && selected!.def.behavior !== 'support' && selected!.def.behavior !== 'aura');
    this.sellButton.setVisible(showTowerButtons);

    if (selected) {
      const d = selected.def;
      setText(this.panelTitle, `${d.name}  ·  Level ${selected.level + 1}`);
      const extra = selected.highGround ? '\nHigh ground: +25% range' : '';
      setText(this.panelBody, towerStatsText(selected.kind, selected.level, { range: selected.range, buff: selected.buff }) + extra);
      const cost = world.upgradeCostOf(selected);
      if (cost === null) {
        this.upgradeButton.setLabel('Max level').setEnabled(false);
      } else {
        this.upgradeButton.setLabel(`Upgrade  $${cost}`, world.money >= cost ? CSS.text : '#ffd0cc')
          .setEnabled(world.money >= cost && world.status === 'playing');
      }
      this.targetButton.setLabel(`Target: ${MODE_LABEL[selected.targetMode]}`);
      this.sellButton.setLabel(`Sell  +$${selected.sellValue}`);
      return;
    }

    const kind = this.hovered ?? tool;
    if (kind) {
      const d = towerDef(kind);
      const locked = !world.isUnlocked(kind);
      setText(this.panelTitle, `${d.name}  ·  $${world.costOf(kind)}`);
      setText(this.panelBody, [
        towerStatsText(kind, 0),
        `Hits: ${[d.hitsGround && 'ground', d.hitsAir && 'air'].filter(Boolean).join(' + ') || '—'}`,
        '',
        d.description,
        locked ? `\nUnlocks at ★ ${d.unlockStars} total stars.` : '',
      ].join('\n'));
      return;
    }

    setText(this.panelTitle, 'Tips');
    setText(this.panelBody, world.map.maze
      ? 'No road here: enemies walk around your towers. Build walls to make their path long.\n\nClick a tower to upgrade or sell it.'
      : 'Pick a tower above, then click the grass to build.\n\nClick a placed tower to upgrade it, change its target or sell it.');
  }

  /** Small icons showing what the next wave brings. */
  private refreshPreview(): void {
    const wave = this.host.world.nextWave;
    const counts = new Map<EnemyType, number>();
    for (const g of wave ?? []) counts.set(g.type, (counts.get(g.type) ?? 0) + g.count);
    const key = [...counts].map(([t, n]) => `${t}${n}`).join(',');
    if (key === this.previewKey) return;
    this.previewKey = key;
    for (const o of this.previewObjects) o.destroy();
    this.previewObjects = [];
    this.previewLabel.setText(wave ? 'Next:' : '');
    let x = X + 36;
    for (const [type, n] of counts) {
      if (x > X + W - 20) break;
      const def = enemyDef(type);
      const img = this.scene.add.image(x + 8, 481, def.texture).setDepth(DEPTH)
        .setScale(spriteScale(this.scene, def.texture) * 0.45);
      if (def.tint) img.setTint(def.tint);
      const t = addText(this.scene, x + 18, 474, `${n}`, { fontSize: '12px', fontStyle: 'bold' }).setDepth(DEPTH);
      this.previewObjects.push(img, t);
      x += 26 + t.width;
    }
  }
}

function setText(t: Phaser.GameObjects.Text, s: string): void {
  if (t.text !== s) t.setText(s);
}
