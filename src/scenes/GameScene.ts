import * as Phaser from 'phaser';
import { TILE, FIELD_W, FIELD_H } from '../config';
import { TOWER_KINDS, TARGET_MODES, towerDef, type TowerKind } from '../data/towers';
import { LEVELS, ENDLESS, endlessWave, levelById } from '../data/levels';
import { World, type WorldEvent } from '../sim/world';
import type { Tower } from '../sim/tower';
import { FixedStep } from '../sim/fixedStep';
import type { Tile } from '../sim/map';
import { FieldView, DEPTH } from '../view/FieldView';
import { Hud, type HudHost } from '../ui/Hud';
import { Overlay } from '../ui/Overlay';
import { COLORS, CSS, addText, setupCamera, starString } from '../ui/theme';
import { audio } from '../audio/audio';
import {
  loadProfile, saveProfile, playerModifiers, unlockedTowers, recordWin, recordEndless, starsFor,
} from '../game/profile';

const SPEEDS = [1, 2, 3];

export interface GameLaunch {
  levelId: string; // a level id, or 'endless'
  resume?: boolean; // continue from the saved game
}

const BLOCK_MESSAGE: Record<string, string> = {
  terrain: "Can't build here",
  occupied: 'Tile taken',
  enemy: 'Enemy in the way',
  'blocks-path': 'That would block the path',
};

export class GameScene extends Phaser.Scene implements HudHost {
  world!: World;
  tool: TowerKind | null = null;
  selected: Tower | null = null;
  paused = false;
  speed = 1;

  private launch!: GameLaunch;
  private field!: FieldView;
  private hud!: Hud;
  private clock!: FixedStep;
  private alpha = 0;
  private hoverTile: Tile | null = null;
  private hoverG!: Phaser.GameObjects.Graphics;
  private ghost!: Phaser.GameObjects.Image;
  private hint!: Phaser.GameObjects.Text;
  private banner!: Phaser.GameObjects.Text;
  private bossBar!: Phaser.GameObjects.Graphics;
  private bossText!: Phaser.GameObjects.Text;
  private pauseOverlay!: Overlay;
  private winOverlay!: Overlay;
  private loseOverlay!: Overlay;

  constructor() {
    super('game');
  }

  init(data: GameLaunch): void {
    this.launch = data?.levelId ? data : { levelId: LEVELS[0].id };
  }

  create(): void {
    // create() also runs on restart, so reset all state here.
    const profile = loadProfile();
    const endless = this.launch.levelId === 'endless';
    const opts = { modifiers: playerModifiers(profile), unlocked: unlockedTowers(profile) };
    this.world = endless
      ? new World(ENDLESS, { ...opts, endlessWaves: endlessWave })
      : new World(levelById(this.launch.levelId), opts);
    const save = profile.save;
    if (this.launch.resume && save && save.levelId === this.world.levelId) this.world.restore(save);
    else this.autosave(); // a fresh start replaces any older saved game

    this.tool = null;
    this.selected = null;
    this.paused = false;
    this.speed = 1;
    this.alpha = 0;
    this.hoverTile = null;
    this.clock = new FixedStep();

    setupCamera(this);
    this.field = new FieldView(this, this.world);
    this.hoverG = this.add.graphics().setDepth(DEPTH.overlay);
    this.ghost = this.add.image(0, 0, `${TOWER_KINDS[0]}-0`).setDepth(DEPTH.overlay).setVisible(false);
    this.hint = addText(this, 0, 0, '', {
      fontSize: '13px', fontStyle: 'bold', color: CSS.red, stroke: '#000000', strokeThickness: 3,
    }).setOrigin(0.5, 1).setDepth(DEPTH.floaters);
    this.banner = addText(this, FIELD_W / 2, 70, '', {
      fontSize: '30px', fontStyle: 'bold', stroke: '#000000', strokeThickness: 5, align: 'center',
    }).setOrigin(0.5).setDepth(DEPTH.floaters).setAlpha(0);
    this.bossBar = this.add.graphics().setDepth(DEPTH.floaters);
    this.bossText = addText(this, FIELD_W / 2, 12, '', {
      fontSize: '13px', fontStyle: 'bold', stroke: '#000000', strokeThickness: 3,
    }).setOrigin(0.5, 0).setDepth(DEPTH.floaters);
    this.hud = new Hud(this, this);

    const toMenu = () => this.scene.start('menu');
    const toLevels = () => this.scene.start('levels');
    const restart = () => this.scene.restart({ levelId: this.launch.levelId });
    this.pauseOverlay = new Overlay(this, 'Paused', CSS.text, [
      { label: 'Resume', variant: 'primary', onClick: () => this.togglePause() },
      { label: 'Restart level', onClick: restart },
      { label: 'Level select', onClick: toLevels },
      { label: 'Main menu', onClick: toMenu },
    ]);
    this.winOverlay = new Overlay(this, 'Victory!', CSS.gold, [
      { label: 'Level select', variant: 'primary', onClick: toLevels },
      { label: 'Play again', onClick: restart },
    ]);
    this.loseOverlay = new Overlay(this, endless ? 'Overrun!' : 'Defeat', CSS.red, [
      { label: 'Try again', variant: 'primary', onClick: restart },
      { label: 'Level select', onClick: toLevels },
    ]);

    this.setupInput();
    const title = endless ? 'Endless mode' : this.world.map.name;
    this.showBanner(this.launch.resume ? `${title}\nGame resumed` : title, CSS.text);
    audio.setIntensity(0);
  }

  // ---- HudHost ---------------------------------------------------------------

  get musicOn(): boolean {
    return loadProfile().music;
  }

  get sfxOn(): boolean {
    return loadProfile().sfx;
  }

  selectTool(tool: TowerKind | null): void {
    if (tool && !this.world.isUnlocked(tool)) {
      audio.play('error');
      return;
    }
    this.tool = tool;
    if (tool) this.selected = null;
  }

  startWave(): void {
    if (this.modalOpen) return;
    if (this.world.startNextWave()) audio.play('waveStart');
  }

  togglePause(): void {
    if (this.world.status !== 'playing') return;
    this.paused = !this.paused;
    if (this.paused) this.pauseOverlay.show('Esc to resume');
    else this.pauseOverlay.hide();
  }

  toggleSpeed(): void {
    this.speed = SPEEDS[(SPEEDS.indexOf(this.speed) + 1) % SPEEDS.length];
  }

  toggleMusic(): void {
    const p = loadProfile();
    p.music = !p.music;
    audio.setMusic(p.music);
    saveProfile(p);
  }

  toggleSfx(): void {
    const p = loadProfile();
    p.sfx = !p.sfx;
    audio.setSfx(p.sfx);
    saveProfile(p);
  }

  upgradeSelected(): void {
    if (!this.selected) return;
    if (this.world.upgrade(this.selected)) this.autosave();
    else audio.play('error');
  }

  sellSelected(): void {
    if (this.selected && this.world.sell(this.selected)) {
      this.selected = null;
      this.autosave();
    }
  }

  cycleTargetMode(): void {
    const t = this.selected;
    if (!t || t.def.behavior === 'support' || t.def.behavior === 'aura') return;
    this.world.setTargetMode(t, TARGET_MODES[(TARGET_MODES.indexOf(t.targetMode) + 1) % TARGET_MODES.length]);
    this.autosave();
  }

  // ---- input -----------------------------------------------------------------

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
        this.selected = null;
        return;
      }
      if (this.hoverTile) this.clickTile(this.hoverTile);
    });

    const kb = this.input.keyboard;
    kb?.addCapture('SPACE');
    kb?.on('keydown', (e: KeyboardEvent) => {
      const key = e.key.toLowerCase();
      if (key === 'escape') {
        if ((this.tool || this.selected) && !this.modalOpen) {
          this.tool = null;
          this.selected = null;
        } else {
          this.togglePause();
        }
        return;
      }
      if (key === 'p') return this.togglePause();
      if (key === 'm') return this.toggleMusic();
      if (this.modalOpen) return;
      const n = Number(key);
      if (n >= 1 && n <= TOWER_KINDS.length) {
        const kind = TOWER_KINDS[n - 1];
        this.selectTool(this.tool === kind ? null : kind);
      } else if (key === ' ') this.startWave();
      else if (key === 'f') this.toggleSpeed();
      else if (key === 'u') this.upgradeSelected();
      else if (key === 's' || key === 'delete') this.sellSelected();
      else if (key === 't') this.cycleTargetMode();
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
    const existing = world.towerAt(col, row);
    if (tool) {
      if (existing) {
        // Clicking a tower while building selects it instead.
        this.tool = null;
        this.selected = existing;
        audio.play('click');
        return;
      }
      const reason = world.buildBlockReason(col, row);
      if (reason) {
        this.field.floatText(col * TILE + TILE / 2, row * TILE, BLOCK_MESSAGE[reason], CSS.red);
        audio.play('error');
        return;
      }
      if (!world.canAfford(tool)) {
        this.field.floatText(col * TILE + TILE / 2, row * TILE, 'Not enough money', CSS.red);
        audio.play('error');
        return;
      }
      world.build(tool, col, row);
      this.autosave();
      return;
    }
    this.selected = existing;
    if (existing) audio.play('click');
  }

  // ---- frame -----------------------------------------------------------------

  update(_time: number, delta: number): void {
    if (!this.modalOpen) {
      this.alpha = this.clock.advance(delta, this.speed, () => this.world.update());
    }
    if (this.selected && !this.world.towers.includes(this.selected)) this.selected = null;
    this.handleSceneEvents(this.world.events);
    this.field.handleEvents(this.world.events);
    this.field.sync(this.alpha);
    this.drawHover();
    this.drawBossBar();
    this.hud.refresh();
    audio.setIntensity(this.world.waveInProgress && !this.modalOpen ? 1 : 0);
  }

  private handleSceneEvents(events: readonly WorldEvent[]): void {
    const total = this.world.totalWaves;
    for (const ev of events) {
      if (ev.type === 'waveStarted') {
        const last = total !== null && ev.wave === total - 1;
        const boss = this.world.waveAt(ev.wave)?.some((g) => g.type === 'boss');
        this.showBanner(last ? 'Final wave!' : boss ? `Wave ${ev.wave + 1}\nBoss incoming!` : `Wave ${ev.wave + 1}`,
          boss ? CSS.red : CSS.text);
        if (ev.early) this.field.floatText(FIELD_W / 2, 110, `Early call +$${ev.early}`, CSS.gold);
      } else if (ev.type === 'waveCleared') {
        if (total === null || ev.wave < total - 1) {
          this.showBanner(`Wave cleared  +$${ev.bonus}` + (ev.interest ? `\nInterest +$${ev.interest}` : ''), CSS.gold);
          audio.play('waveClear');
        }
        this.autosave();
      } else if (ev.type === 'won') {
        this.onGameOver(true);
      } else if (ev.type === 'lost') {
        this.onGameOver(false);
      }
    }
  }

  private onGameOver(won: boolean): void {
    this.tool = null;
    this.selected = null;
    const p = loadProfile();
    p.save = null;
    saveProfile(p);
    audio.play(won ? 'win' : 'lose');
    if (this.world.endless) {
      const best = recordEndless(p, this.world.wavesCleared);
      this.loseOverlay.show(`You survived ${this.world.wavesCleared} waves.\n` +
        (best ? 'New personal best!' : `Best: ${p.endlessBest} waves`));
      return;
    }
    if (won) {
      const stars = starsFor(this.world.lives, this.world.startLives);
      const { newTowers } = recordWin(p, this.world.levelId, stars);
      const unlocked = newTowers.length ? `\nUnlocked: ${newTowers.map((k) => towerDef(k).name).join(', ')}!` : '';
      this.winOverlay.show(`${starString(stars)}\n${this.world.lives} of ${this.world.startLives} lives left.${unlocked}`);
    } else {
      this.loseOverlay.show(`You reached wave ${this.world.waveIndex + 1} of ${this.world.totalWaves}.`);
    }
  }

  /** Saves the game so it can be continued later (only possible between waves). */
  private autosave(): void {
    const p = loadProfile();
    const snap = this.world.snapshot();
    if (snap) {
      p.save = snap;
      saveProfile(p);
    }
  }

  private showBanner(text: string, color: string): void {
    this.tweens.killTweensOf(this.banner);
    this.banner.setText(text).setColor(color).setAlpha(0).setScale(0.8);
    this.tweens.chain({
      targets: this.banner,
      tweens: [
        { alpha: 1, scale: 1, duration: 250, ease: 'Back.easeOut' },
        { alpha: 0, duration: 400, delay: 1500 },
      ],
    });
  }

  private drawBossBar(): void {
    const g = this.bossBar.clear();
    const boss = this.world.enemies.find((e) => e.def.boss);
    if (!boss) {
      if (this.bossText.text) this.bossText.setText('');
      return;
    }
    const w = 300, x = (FIELD_W - w) / 2, y = 32;
    const f = Math.max(0, boss.hitpoints / boss.maxHitpoints);
    g.fillStyle(0x000000, 0.6).fillRoundedRect(x - 3, y - 3, w + 6, 16, 5);
    g.fillStyle(0x5c1a1a, 1).fillRoundedRect(x, y, w, 10, 3);
    g.fillStyle(COLORS.red, 1).fillRoundedRect(x, y, Math.max(6, w * f), 10, 3);
    const label = `${boss.def.name}  ${Math.ceil(boss.hitpoints)} / ${boss.maxHitpoints}`;
    if (this.bossText.text !== label) this.bossText.setText(label);
  }

  private drawHover(): void {
    const g = this.hoverG.clear();
    this.ghost.setVisible(false);
    this.hint.setVisible(false);

    if (this.selected && !this.modalOpen) {
      const t = this.selected;
      g.fillStyle(0xffffff, 0.1).fillCircle(t.x, t.y, t.range);
      g.lineStyle(2, COLORS.gold, 0.8).strokeCircle(t.x, t.y, t.range);
      g.lineStyle(2, COLORS.gold, 1).strokeRect(t.col * TILE + 1, t.row * TILE + 1, TILE - 2, TILE - 2);
    }
    if (!this.hoverTile || this.modalOpen) return;

    const { col, row } = this.hoverTile;
    const cx = col * TILE + TILE / 2, cy = row * TILE + TILE / 2;
    const tower = this.world.towerAt(col, row);

    if (this.tool && !tower) {
      const reason = this.world.buildBlockReason(col, row);
      const ok = !reason && this.world.canAfford(this.tool);
      const color = ok ? 0xffffff : COLORS.red;
      if (reason !== 'terrain') {
        const range = towerDef(this.tool).levels[0].range * (this.world.map.isHighGround(col, row) ? 1.25 : 1);
        g.fillStyle(color, 0.12).fillCircle(cx, cy, range);
        g.lineStyle(2, color, 0.6).strokeCircle(cx, cy, range);
        const key = `${this.tool}-0`;
        this.ghost.setTexture(key).setPosition(cx, cy).setRotation(0)
          .setDisplaySize(TILE, TILE).setAlpha(0.75).setTint(ok ? 0xffffff : 0xff8080).setVisible(true);
      }
      if (reason && reason !== 'terrain') {
        this.hint.setText(BLOCK_MESSAGE[reason]).setPosition(cx, row * TILE - 2).setVisible(true);
      }
      g.lineStyle(2, color, 0.9).strokeRect(col * TILE + 1, row * TILE + 1, TILE - 2, TILE - 2);
    } else if (tower && tower !== this.selected) {
      g.fillStyle(0xffffff, 0.08).fillCircle(tower.x, tower.y, tower.range);
      g.lineStyle(2, 0xffffff, 0.45).strokeCircle(tower.x, tower.y, tower.range);
    }
  }
}
