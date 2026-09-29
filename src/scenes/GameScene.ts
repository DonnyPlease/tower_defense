import * as Phaser from 'phaser';
import { MAPS, TILE, FIELD_W, FIELD_H, TOWERS, TOWER_KINDS, ENEMY_TYPES, type TowerKind } from '../config';
import { World, type WorldEvent } from '../sim/world';
import { FixedStep } from '../sim/fixedStep';
import type { Tile } from '../sim/map';
import { FieldView, DEPTH } from '../view/FieldView';
import { Hud, type HudHost, type Tool } from '../ui/Hud';
import { Overlay } from '../ui/Overlay';
import { COLORS, CSS, addText, setupCamera } from '../ui/theme';

const SPEEDS = [1, 2, 3];

export class GameScene extends Phaser.Scene implements HudHost {
  world!: World;
  tool: Tool = null;
  paused = false;
  speed = 1;

  private field!: FieldView;
  private hud!: Hud;
  private clock!: FixedStep;
  private alpha = 0;
  private hoverTile: Tile | null = null;
  private hoverG!: Phaser.GameObjects.Graphics;
  private ghost!: Phaser.GameObjects.Image;
  private banner!: Phaser.GameObjects.Text;
  private pauseOverlay!: Overlay;
  private winOverlay!: Overlay;
  private loseOverlay!: Overlay;

  constructor() {
    super('game');
  }

  create(): void {
    // create() also runs on restart, so reset all state here.
    this.world = new World(MAPS[0]);
    this.tool = null;
    this.paused = false;
    this.speed = 1;
    this.alpha = 0;
    this.hoverTile = null;
    this.clock = new FixedStep();

    setupCamera(this);
    this.field = new FieldView(this, this.world);
    this.hoverG = this.add.graphics().setDepth(DEPTH.overlay);
    this.ghost = this.add.image(0, 0, `${TOWER_KINDS[0]}-0`).setDepth(DEPTH.overlay).setVisible(false);
    this.banner = addText(this, FIELD_W / 2, 60, '', {
      fontSize: '30px', fontStyle: 'bold', stroke: '#000000', strokeThickness: 5,
    }).setOrigin(0.5).setDepth(DEPTH.floaters).setAlpha(0);
    this.hud = new Hud(this, this);

    const toMenu = () => this.scene.start('menu');
    const restart = () => this.scene.restart();
    this.pauseOverlay = new Overlay(this, 'Paused', CSS.text, [
      { label: 'Resume', variant: 'primary', onClick: () => this.togglePause() },
      { label: 'Restart', onClick: restart },
      { label: 'Main menu', onClick: toMenu },
    ]);
    this.winOverlay = new Overlay(this, 'Victory!', CSS.gold, [
      { label: 'Play again', variant: 'primary', onClick: restart },
      { label: 'Main menu', onClick: toMenu },
    ]);
    this.loseOverlay = new Overlay(this, 'Defeat', CSS.red, [
      { label: 'Try again', variant: 'primary', onClick: restart },
      { label: 'Main menu', onClick: toMenu },
    ]);

    this.setupInput();
    this.showBanner('Build towers, then start the wave', CSS.text);
  }

  // ---- HudHost -------------------------------------------------------------

  selectTool(tool: Tool): void {
    this.tool = tool;
  }

  startWave(): void {
    if (!this.paused) this.world.startNextWave();
  }

  togglePause(): void {
    if (this.world.status !== 'playing') return;
    this.paused = !this.paused;
    if (this.paused) this.pauseOverlay.show('Press Esc to resume');
    else this.pauseOverlay.hide();
  }

  toggleSpeed(): void {
    this.speed = SPEEDS[(SPEEDS.indexOf(this.speed) + 1) % SPEEDS.length];
  }

  infoSubject(): TowerKind | 'sell' | null {
    if (this.tool) return this.tool;
    const t = this.hoverTile && this.world.towerAt(this.hoverTile.col, this.hoverTile.row);
    return t ? t.kind : null;
  }

  // ---- input ---------------------------------------------------------------

  private get modalOpen(): boolean {
    return this.paused || this.world.status !== 'playing';
  }

  private setupInput(): void {
    this.input.mouse?.disableContextMenu();

    this.input.on('pointermove', (p: Phaser.Input.Pointer) => this.updateHover(p));
    this.input.on('pointerdown', (p: Phaser.Input.Pointer, over: Phaser.GameObjects.GameObject[]) => {
      this.updateHover(p);
      if (over.length > 0 || this.modalOpen) return; // a button or dialog took it
      if (p.rightButtonDown()) {
        this.tool = null;
        return;
      }
      if (this.hoverTile) this.clickTile(this.hoverTile);
    });

    const kb = this.input.keyboard;
    kb?.addCapture('SPACE');
    kb?.on('keydown', (e: KeyboardEvent) => {
      const key = e.key.toLowerCase();
      if (key === 'escape') {
        if (this.tool && !this.modalOpen) this.tool = null;
        else this.togglePause();
        return;
      }
      if (key === 'p') return this.togglePause();
      if (this.modalOpen) return;
      const kind = TOWER_KINDS.find((k) => TOWERS[k].hotkey.toLowerCase() === key);
      if (kind) this.tool = this.tool === kind ? null : kind;
      else if (key === 's') this.tool = this.tool === 'sell' ? null : 'sell';
      else if (key === ' ') this.startWave();
      else if (key === 'f') this.toggleSpeed();
      // Debug: spawn single enemies with 1 / 2 / 3.
      else if (/^[1-9]$/.test(key) && ENEMY_TYPES[Number(key) - 1]) this.world.spawn(ENEMY_TYPES[Number(key) - 1]);
    });

    // Pause automatically when the window loses focus.
    const onBlur = () => { if (!this.modalOpen) this.togglePause(); };
    this.game.events.on(Phaser.Core.Events.BLUR, onBlur);
    this.events.once(Phaser.Scenes.Events.SHUTDOWN, () => this.game.events.off(Phaser.Core.Events.BLUR, onBlur));
  }

  private updateHover(p: Phaser.Input.Pointer): void {
    const x = p.worldX, y = p.worldY;
    this.hoverTile = x >= 0 && x < FIELD_W && y >= 0 && y < FIELD_H
      ? { col: Math.floor(x / TILE), row: Math.floor(y / TILE) }
      : null;
  }

  private clickTile({ col, row }: Tile): void {
    const { world, tool } = this;
    if (tool === 'sell') {
      world.sell(col, row);
    } else if (tool) {
      if (!world.canBuildAt(col, row)) return;
      if (!world.canAfford(tool)) {
        this.field.floatText(col * TILE + TILE / 2, row * TILE, 'Not enough money', CSS.red);
        return;
      }
      world.build(tool, col, row);
    }
  }

  // ---- frame ---------------------------------------------------------------

  update(_time: number, delta: number): void {
    if (!this.modalOpen) {
      this.alpha = this.clock.advance(delta, this.speed, () => this.world.update());
    }
    this.handleSceneEvents(this.world.events);
    this.field.handleEvents(this.world.events);
    this.field.sync(this.alpha);
    this.drawHover();
    this.hud.refresh();
  }

  private handleSceneEvents(events: readonly WorldEvent[]): void {
    const total = this.world.waves.length;
    for (const ev of events) {
      if (ev.type === 'waveStarted') {
        this.showBanner(ev.wave === total - 1 ? 'Final wave!' : `Wave ${ev.wave + 1}`, CSS.text);
      } else if (ev.type === 'waveCleared' && ev.wave < total - 1) {
        this.showBanner(`Wave cleared  +$${ev.amount}`, CSS.gold);
      } else if (ev.type === 'won') {
        this.tool = null;
        this.winOverlay.show(`All ${total} waves cleared\nwith ${this.world.lives} lives left.`);
      } else if (ev.type === 'lost') {
        this.tool = null;
        this.loseOverlay.show(`You reached wave ${this.world.waveIndex + 1} of ${total}.`);
      }
    }
  }

  private showBanner(text: string, color: string): void {
    this.tweens.killTweensOf(this.banner);
    this.banner.setText(text).setColor(color).setAlpha(0).setScale(0.8);
    this.tweens.chain({
      targets: this.banner,
      tweens: [
        { alpha: 1, scale: 1, duration: 250, ease: 'Back.easeOut' },
        { alpha: 0, duration: 400, delay: 1300 },
      ],
    });
  }

  private drawHover(): void {
    const g = this.hoverG.clear();
    this.ghost.setVisible(false);
    if (!this.hoverTile || this.modalOpen) return;

    const { col, row } = this.hoverTile;
    const cx = col * TILE + TILE / 2, cy = row * TILE + TILE / 2;
    const tower = this.world.towerAt(col, row);

    if (this.tool && this.tool !== 'sell') {
      const buildable = this.world.canBuildAt(col, row);
      const ok = buildable && this.world.canAfford(this.tool);
      const color = ok ? 0xffffff : COLORS.red;
      if (buildable) {
        g.fillStyle(color, 0.12).fillCircle(cx, cy, TOWERS[this.tool].range);
        g.lineStyle(2, color, 0.6).strokeCircle(cx, cy, TOWERS[this.tool].range);
        this.ghost.setTexture(`${this.tool}-0`).setPosition(cx, cy).setRotation(0)
          .setAlpha(0.75).setTint(ok ? 0xffffff : 0xff8080).setVisible(true);
      }
      g.lineStyle(2, color, 0.9).strokeRect(col * TILE + 1, row * TILE + 1, TILE - 2, TILE - 2);
    } else if (this.tool === 'sell') {
      if (tower) {
        g.fillStyle(COLORS.red, 0.35).fillRect(col * TILE, row * TILE, TILE, TILE);
        g.lineStyle(2, COLORS.red, 1).strokeRect(col * TILE + 1, row * TILE + 1, TILE - 2, TILE - 2);
      }
    } else if (tower) {
      g.fillStyle(0xffffff, 0.1).fillCircle(cx, cy, tower.def.range);
      g.lineStyle(2, 0xffffff, 0.5).strokeCircle(cx, cy, tower.def.range);
    }
  }
}
