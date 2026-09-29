import * as Phaser from 'phaser';
import { TILE, COLS, ROWS, FIELD_W, FIELD_H } from '../config';
import type { World, WorldEvent } from '../sim/world';
import type { Enemy } from '../sim/enemy';
import type { Tower } from '../sim/tower';
import type { Bullet } from '../sim/bullet';
import { COLORS, CSS, addText, lerp, lerpAngle } from '../ui/theme';

// Depths of the layers inside the playing field.
export const DEPTH = {
  map: 0,
  shadows: 5,
  towers: 10,
  enemies: 20,
  bullets: 30,
  bars: 40,
  overlay: 45,
  effects: 50,
  floaters: 60,
};

interface TowerSprites { base: Phaser.GameObjects.Image; gun: Phaser.GameObjects.Image }
interface EnemySprites { shadow: Phaser.GameObjects.Image; body: Phaser.GameObjects.Image }

/**
 * Renders a World: owns one sprite per simulated entity, positions them with
 * interpolation between simulation ticks, and turns world events into
 * particles, floating text and camera effects.
 */
export class FieldView {
  private readonly towers = new Map<Tower, TowerSprites>();
  private readonly enemies = new Map<Enemy, EnemySprites>();
  private readonly bullets = new Map<Bullet, Phaser.GameObjects.Image>();
  private readonly bars: Phaser.GameObjects.Graphics;
  private readonly explosion: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly sparks: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly smoke: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly dust: Phaser.GameObjects.Particles.ParticleEmitter;
  private frameCount = 0;
  /** When false, events produce no floating text or camera effects (menu demo). */
  quiet = false;

  constructor(private readonly scene: Phaser.Scene, private readonly world: World) {
    this.drawMap();
    this.bars = scene.add.graphics().setDepth(DEPTH.bars);

    this.explosion = scene.add.particles(0, 0, 'dot', {
      speed: { min: 40, max: 170 },
      lifespan: { min: 250, max: 550 },
      scale: { start: 0.7, end: 0 },
      tint: [0xffd166, 0xff8c42, 0xef476f, 0x8d99ae],
      emitting: false,
    }).setDepth(DEPTH.effects);
    this.sparks = scene.add.particles(0, 0, 'dot', {
      speed: { min: 60, max: 140 },
      lifespan: 180,
      scale: { start: 0.35, end: 0 },
      tint: [0xffffff, 0xffe28a],
      emitting: false,
    }).setDepth(DEPTH.effects);
    this.smoke = scene.add.particles(0, 0, 'dot', {
      speed: { min: 2, max: 12 },
      lifespan: 450,
      scale: { start: 0.35, end: 0.9 },
      alpha: { start: 0.45, end: 0 },
      tint: 0xd0d0d0,
      emitting: false,
    }).setDepth(DEPTH.bullets - 1);
    this.dust = scene.add.particles(0, 0, 'dot', {
      speed: { min: 30, max: 80 },
      lifespan: 400,
      scale: { start: 0.6, end: 0 },
      alpha: { start: 0.7, end: 0 },
      tint: 0xe9dcb8,
      emitting: false,
    }).setDepth(DEPTH.effects);
  }

  private drawMap(): void {
    const g = this.scene.add.graphics().setDepth(DEPTH.map);
    const map = this.world.map;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const x = c * TILE, y = r * TILE;
        if (map.isPath(c, r)) {
          g.fillStyle(COLORS.path, 1).fillRect(x, y, TILE, TILE);
        } else {
          g.fillStyle((r + c) % 2 ? COLORS.grass : COLORS.grassAlt, 1).fillRect(x, y, TILE, TILE);
        }
      }
    }
    // Darker edges where the path meets grass, so the road reads clearly.
    g.fillStyle(COLORS.pathEdge, 1);
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (!map.isPath(c, r)) continue;
        const x = c * TILE, y = r * TILE;
        if (map.inBounds(c, r - 1) && !map.isPath(c, r - 1)) g.fillRect(x, y, TILE, 3);
        if (map.inBounds(c, r + 1) && !map.isPath(c, r + 1)) g.fillRect(x, y + TILE - 3, TILE, 3);
        if (map.inBounds(c - 1, r) && !map.isPath(c - 1, r)) g.fillRect(x, y, 3, TILE);
        if (map.inBounds(c + 1, r) && !map.isPath(c + 1, r)) g.fillRect(x + TILE - 3, y, 3, TILE);
      }
    }
    // Faint grid on buildable ground.
    g.lineStyle(1, 0x000000, 0.08);
    for (let c = 1; c < COLS; c++) g.lineBetween(c * TILE, 0, c * TILE, FIELD_H);
    for (let r = 1; r < ROWS; r++) g.lineBetween(0, r * TILE, FIELD_W, r * TILE);
  }

  /** Syncs sprites with the world. `alpha` is the fraction between ticks. */
  sync(alpha: number): void {
    this.frameCount++;
    this.syncTowers(alpha);
    this.syncEnemies(alpha);
    this.syncBullets(alpha);
    this.drawBars(alpha);
  }

  private syncTowers(alpha: number): void {
    const live = new Set(this.world.towers);
    for (const [t, s] of this.towers) {
      if (!live.has(t)) {
        s.base.destroy();
        s.gun.destroy();
        this.towers.delete(t);
      }
    }
    for (const t of this.world.towers) {
      let s = this.towers.get(t);
      if (!s) {
        s = {
          base: this.scene.add.image(t.x, t.y + 3, 'shadow').setDepth(DEPTH.shadows).setDisplaySize(34, 20),
          gun: this.scene.add.image(t.x, t.y, `${t.kind}-0`).setDepth(DEPTH.towers),
        };
        this.towers.set(t, s);
      }
      s.gun.setTexture(`${t.kind}-${Math.floor(t.frame)}`);
      // Sprites point up, simulation angle 0 points right.
      s.gun.setRotation(lerpAngle(t.prevAngle, t.angle, alpha) + Math.PI / 2);
    }
  }

  private syncEnemies(alpha: number): void {
    const live = new Set(this.world.enemies);
    for (const [e, s] of this.enemies) {
      if (!live.has(e)) {
        s.shadow.destroy();
        s.body.destroy();
        this.enemies.delete(e);
      }
    }
    for (const e of this.world.enemies) {
      let s = this.enemies.get(e);
      if (!s) {
        s = {
          shadow: this.scene.add.image(0, 0, 'shadow').setDepth(DEPTH.shadows).setDisplaySize(e.radius * 2.2, e.radius * 1.4),
          body: this.scene.add.image(0, 0, `enemy-${e.type}`).setDepth(DEPTH.enemies),
        };
        this.enemies.set(e, s);
      }
      const x = lerp(e.prevX, e.x, alpha), y = lerp(e.prevY, e.y, alpha);
      s.body.setPosition(x, y).setRotation(lerpAngle(e.prevAngle, e.angle, alpha));
      s.shadow.setPosition(x + 2, y + 5);
    }
  }

  private syncBullets(alpha: number): void {
    const live = new Set(this.world.bullets);
    for (const [b, img] of this.bullets) {
      if (!live.has(b)) {
        img.destroy();
        this.bullets.delete(b);
      }
    }
    for (const b of this.world.bullets) {
      let img = this.bullets.get(b);
      if (!img) {
        img = this.scene.add.image(0, 0, b.type === 'missile' ? 'missile' : 'bullet').setDepth(DEPTH.bullets);
        this.bullets.set(b, img);
      }
      const x = lerp(b.prevX, b.x, alpha), y = lerp(b.prevY, b.y, alpha);
      img.setPosition(x, y).setRotation(b.angle);
      if (b.type === 'missile' && this.frameCount % 3 === 0) {
        this.smoke.emitParticleAt(x - Math.cos(b.angle) * 6, y - Math.sin(b.angle) * 6, 1);
      }
    }
  }

  private drawBars(alpha: number): void {
    const g = this.bars.clear();
    for (const e of this.world.enemies) {
      if (e.hitpoints >= e.maxHitpoints) continue;
      const x = lerp(e.prevX, e.x, alpha) - 12, y = lerp(e.prevY, e.y, alpha) - e.radius - 9;
      const frac = Math.max(0, e.hitpoints / e.maxHitpoints);
      g.fillStyle(0x000000, 0.6).fillRect(x - 1, y - 1, 26, 6);
      g.fillStyle(frac > 0.5 ? COLORS.green : frac > 0.25 ? COLORS.gold : COLORS.red, 1)
        .fillRect(x, y, 24 * frac, 4);
    }
  }

  /** Turns world events into visual effects. Clears the world's event list. */
  handleEvents(events: WorldEvent[]): void {
    for (const ev of events) {
      switch (ev.type) {
        case 'kill':
          this.explosion.explode(ev.enemy === 'tank' ? 22 : 12, ev.x, ev.y);
          if (!this.quiet) this.floatText(ev.x, ev.y - 10, `+$${ev.amount}`, CSS.gold);
          break;
        case 'hit':
          this.sparks.explode(ev.bullet === 'missile' ? 6 : 3, ev.x, ev.y);
          break;
        case 'build':
          this.dust.explode(14, ev.x, ev.y + 8);
          break;
        case 'sell':
          this.dust.explode(10, ev.x, ev.y);
          this.floatText(ev.x, ev.y - 10, `+$${ev.amount}`, CSS.gold);
          break;
        case 'leak':
          if (this.quiet) break;
          this.floatText(Math.min(ev.x, FIELD_W - 30), ev.y, `-${ev.amount} ♥`, CSS.red);
          this.scene.cameras.main.shake(140, 0.004);
          this.scene.cameras.main.flash(160, 180, 30, 30);
          break;
        default:
          break;
      }
    }
    events.length = 0;
  }

  floatText(x: number, y: number, text: string, color: string): void {
    const t = addText(this.scene, x, y, text, {
      fontSize: '15px', fontStyle: 'bold', color, stroke: '#000000', strokeThickness: 3,
    }).setOrigin(0.5).setDepth(DEPTH.floaters);
    this.scene.tweens.add({
      targets: t, y: y - 30, alpha: 0, duration: 900, ease: 'Cubic.easeOut',
      onComplete: () => t.destroy(),
    });
  }
}
