import * as Phaser from 'phaser';
import { TILE, COLS, ROWS, FIELD_W, FIELD_H } from '../config';
import type { TowerKind } from '../data/towers';
import type { World, WorldEvent } from '../sim/world';
import type { Enemy } from '../sim/enemy';
import type { Tower } from '../sim/tower';
import type { Bullet } from '../sim/bullet';
import { GameMap, tileCenter, type Tile } from '../sim/map';
import { audio, type SfxName } from '../audio/audio';
import { COLORS, CSS, GEN, addText, lerp, lerpAngle, spriteScale } from '../ui/theme';

// Depths of the layers inside the playing field.
export const DEPTH = {
  map: 0,
  pathPreview: 2,
  shadows: 5,
  auras: 6,
  towers: 10,
  enemies: 20,
  air: 26,
  bullets: 30,
  beams: 32,
  bars: 40,
  overlay: 45,
  effects: 50,
  floaters: 60,
};

const SHOT_SOUND: Record<TowerKind, SfxName | null> = {
  gun: 'gun', missile: 'missile', cannon: 'cannon', frost: null, laser: null, support: null,
};

interface TowerSprites { shadow: Phaser.GameObjects.Image; body: Phaser.GameObjects.Image; baseScale: number }
interface EnemySprites { shadow: Phaser.GameObjects.Image; body: Phaser.GameObjects.Image; baseScale: number }

/**
 * Renders a World: owns one sprite per simulated entity, positions them with
 * interpolation between simulation ticks, and turns world events into
 * particles, floating text, camera effects and sounds.
 */
export class FieldView {
  private readonly towers = new Map<Tower, TowerSprites>();
  private readonly enemies = new Map<Enemy, EnemySprites>();
  private readonly bullets = new Map<Bullet, Phaser.GameObjects.Image>();
  private readonly bars: Phaser.GameObjects.Graphics;
  private readonly beams: Phaser.GameObjects.Graphics;
  private readonly pathPreview: Phaser.GameObjects.Graphics;
  private readonly explosion: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly sparks: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly smoke: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly dust: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly frost: Phaser.GameObjects.Particles.ParticleEmitter;
  private readonly stars: Phaser.GameObjects.Particles.ParticleEmitter;
  private frameCount = 0;
  private pathKey = '';
  /** Menu demo: no floating text, camera effects or sound. */
  quiet = false;

  constructor(private readonly scene: Phaser.Scene, private readonly world: World) {
    this.drawMap();
    this.pathPreview = scene.add.graphics().setDepth(DEPTH.pathPreview);
    this.bars = scene.add.graphics().setDepth(DEPTH.bars);
    this.beams = scene.add.graphics().setDepth(DEPTH.beams);

    const emitter = (depth: number, config: Phaser.Types.GameObjects.Particles.ParticleEmitterConfig) =>
      scene.add.particles(0, 0, 'dot', { emitting: false, ...config }).setDepth(depth);
    this.explosion = emitter(DEPTH.effects, {
      speed: { min: 40, max: 170 }, lifespan: { min: 250, max: 550 }, scale: { start: 0.7, end: 0 },
      tint: [0xffd166, 0xff8c42, 0xef476f, 0x8d99ae],
    });
    this.sparks = emitter(DEPTH.effects, {
      speed: { min: 60, max: 140 }, lifespan: 180, scale: { start: 0.35, end: 0 }, tint: [0xffffff, 0xffe28a],
    });
    this.smoke = emitter(DEPTH.bullets - 1, {
      speed: { min: 2, max: 12 }, lifespan: 450, scale: { start: 0.35, end: 0.9 }, alpha: { start: 0.45, end: 0 },
      tint: 0xd0d0d0,
    });
    this.dust = emitter(DEPTH.effects, {
      speed: { min: 30, max: 80 }, lifespan: 400, scale: { start: 0.6, end: 0 }, alpha: { start: 0.7, end: 0 },
      tint: 0xe9dcb8,
    });
    this.frost = emitter(DEPTH.effects, {
      speed: { min: 20, max: 60 }, lifespan: 500, scale: { start: 0.4, end: 0 }, alpha: { start: 0.9, end: 0 },
      tint: [0xffffff, 0xbfe9ff, 0x7ad3ff],
    });
    this.stars = emitter(DEPTH.effects, {
      speed: { min: 40, max: 110 }, lifespan: 600, scale: { start: 0.5, end: 0 }, gravityY: 120,
      tint: [0xf5c542, 0xffffff],
    });
  }

  // ---- terrain -----------------------------------------------------------------

  private drawMap(): void {
    const g = this.scene.add.graphics().setDepth(DEPTH.map);
    const map = this.world.map;
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        const x = c * TILE, y = r * TILE;
        const grass = (r + c) % 2 ? COLORS.grass : COLORS.grassAlt;
        switch (map.terrainAt(c, r)) {
          case 'road':
            g.fillStyle(COLORS.path, 1).fillRect(x, y, TILE, TILE);
            break;
          case 'high':
            g.fillStyle(COLORS.high, 1).fillRect(x, y, TILE, TILE);
            g.fillStyle(COLORS.highEdgeLight, 1).fillRect(x, y, TILE, 3).fillRect(x, y, 3, TILE);
            g.fillStyle(COLORS.highEdgeDark, 1).fillRect(x, y + TILE - 3, TILE, 3).fillRect(x + TILE - 3, y, 3, TILE);
            g.fillStyle(COLORS.highEdgeDark, 0.5).fillTriangle(x + 12, y + 26, x + 20, y + 14, x + 28, y + 26);
            break;
          case 'rock':
            g.fillStyle(grass, 1).fillRect(x, y, TILE, TILE);
            g.fillStyle(COLORS.rockDark, 1).fillEllipse(x + 21, y + 24, 32, 24);
            g.fillStyle(COLORS.rock, 1).fillEllipse(x + 19, y + 20, 28, 22);
            g.fillStyle(0xa3a9b1, 1).fillEllipse(x + 15, y + 15, 10, 6);
            break;
          case 'water':
          case 'bridge':
            g.fillStyle(COLORS.water, 1).fillRect(x, y, TILE, TILE);
            g.lineStyle(2, COLORS.waterLight, 0.7);
            g.lineBetween(x + 6 + (r % 2) * 10, y + 12, x + 18 + (r % 2) * 10, y + 12);
            g.lineBetween(x + 14 - (r % 2) * 8, y + 28, x + 26 - (r % 2) * 8, y + 28);
            if (map.terrainAt(c, r) === 'bridge') {
              g.fillStyle(COLORS.bridge, 1).fillRect(x, y + 2, TILE, TILE - 4);
              g.lineStyle(1.5, COLORS.bridgeDark, 1);
              for (let px = x + 8; px < x + TILE; px += 8) g.lineBetween(px, y + 2, px, y + TILE - 2);
              g.fillStyle(COLORS.bridgeDark, 1).fillRect(x, y, TILE, 3).fillRect(x, y + TILE - 3, TILE, 3);
            }
            break;
          default:
            g.fillStyle(grass, 1).fillRect(x, y, TILE, TILE);
        }
      }
    }
    // Darker edges where the road meets anything else, so it reads clearly.
    g.fillStyle(COLORS.pathEdge, 1);
    for (let r = 0; r < ROWS; r++) {
      for (let c = 0; c < COLS; c++) {
        if (map.terrainAt(c, r) !== 'road') continue;
        const x = c * TILE, y = r * TILE;
        const edge = (cc: number, rr: number) => map.inBounds(cc, rr) && !map.isRoad(cc, rr);
        if (edge(c, r - 1)) g.fillRect(x, y, TILE, 3);
        if (edge(c, r + 1)) g.fillRect(x, y + TILE - 3, TILE, 3);
        if (edge(c - 1, r)) g.fillRect(x, y, 3, TILE);
        if (edge(c + 1, r)) g.fillRect(x + TILE - 3, y, 3, TILE);
      }
    }
    // Faint grid on buildable ground.
    g.lineStyle(1, 0x000000, 0.08);
    for (let c = 1; c < COLS; c++) g.lineBetween(c * TILE, 0, c * TILE, FIELD_H);
    for (let r = 1; r < ROWS; r++) g.lineBetween(0, r * TILE, FIELD_W, r * TILE);

    // Entry and exit arrows.
    g.fillStyle(0xffffff, 0.55);
    const arrow = (t: Tile, inward: boolean) => {
      const [dc, dr] = map.outward(t);
      const s = inward ? -1 : 1;
      const { x, y } = tileCenter(t);
      const ax = dc * s, ay = dr * s;
      g.fillTriangle(x + ax * 10, y + ay * 10, x - ax * 6 - ay * 8, y - ay * 6 - ax * 8, x - ax * 6 + ay * 8, y - ay * 6 + ax * 8);
    };
    for (const s of map.starts) arrow(s, true);
    for (const e of map.ends) arrow(e, false);
  }

  /** Maze levels: dotted line showing the route enemies will take right now. */
  private drawPathPreview(): void {
    const map = this.world.map;
    if (!map.maze) return;
    const key = this.world.towers.map((t) => `${t.col},${t.row}`).join(';');
    if (key === this.pathKey) return;
    this.pathKey = key;
    const g = this.pathPreview.clear();
    const field = this.world.distanceField;
    g.fillStyle(0xffffff, 0.35);
    for (const s of map.starts) {
      let cur: Tile | null = s;
      let dir: readonly [number, number] | null = null;
      for (let i = 0; cur && i < 400; i++) {
        const { x, y } = tileCenter(cur);
        g.fillCircle(x, y, 3);
        const next: Tile | null = GameMap.nextTile(field, cur, dir);
        if (next) {
          dir = [next.col - cur.col, next.row - cur.row];
          g.fillCircle(x + dir[0] * TILE / 2, y + dir[1] * TILE / 2, 2);
        }
        cur = next;
      }
    }
  }

  // ---- per-frame sync ------------------------------------------------------------

  /** Syncs sprites with the world. `alpha` is the fraction between ticks. */
  sync(alpha: number): void {
    this.frameCount++;
    this.drawPathPreview();
    this.syncTowers(alpha);
    this.syncEnemies(alpha);
    this.syncBullets(alpha);
    this.drawBars(alpha);
  }

  private syncTowers(alpha: number): void {
    const live = new Set(this.world.towers);
    for (const [t, s] of this.towers) {
      if (!live.has(t)) {
        s.shadow.destroy();
        s.body.destroy();
        this.towers.delete(t);
      }
    }
    const beams = this.beams.clear();
    for (const t of this.world.towers) {
      let s = this.towers.get(t);
      if (!s) {
        const key = `${t.kind}-0`;
        s = {
          shadow: this.scene.add.image(t.x, t.y + 3, 'shadow').setDepth(DEPTH.shadows).setDisplaySize(34, 20),
          body: this.scene.add.image(t.x, t.y, key).setDepth(DEPTH.towers),
          baseScale: spriteScale(this.scene, key),
        };
        this.towers.set(t, s);
      }
      const frames = t.def.frames;
      if (frames > 1) s.body.setTexture(`${t.kind}-${Math.floor(t.frame) % frames}`);
      const rotates = t.def.behavior === 'projectile' || t.def.behavior === 'beam';
      // Sprites point up, simulation angle 0 points right.
      s.body.setRotation(rotates ? lerpAngle(t.prevAngle, t.angle, alpha) + Math.PI / 2 : 0);
      const recoil = frames === 1 && t.shooting ? 0.9 : 1;
      const levelScale = 1 + 0.06 * t.level;
      s.body.setScale(s.baseScale * levelScale * recoil);
      if (t.def.behavior === 'support') s.body.setRotation(this.frameCount * 0.02);

      if (t.def.behavior === 'beam' && t.target?.alive) {
        const tx = lerp(t.target.prevX, t.target.x, alpha), ty = lerp(t.target.prevY, t.target.y, alpha);
        const heat = t.heatFraction;
        const sx = t.x + Math.cos(t.angle) * 14, sy = t.y + Math.sin(t.angle) * 14;
        beams.lineStyle(6 + 6 * heat, 0xd35cff, 0.25 + 0.2 * heat).lineBetween(sx, sy, tx, ty);
        beams.lineStyle(2 + 2 * heat, 0xf5d0ff, 0.95).lineBetween(sx, sy, tx, ty);
        beams.fillStyle(0xffffff, 0.9).fillCircle(tx, ty, 3 + 3 * heat);
      }
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
        const key = e.def.texture;
        const baseScale = spriteScale(this.scene, key) * (e.def.scale ?? 1);
        const size = e.radius * 2.2;
        s = {
          shadow: this.scene.add.image(0, 0, 'shadow').setDepth(DEPTH.shadows)
            .setDisplaySize(size * (e.flying ? 0.7 : 1), size * (e.flying ? 0.45 : 0.65))
            .setAlpha(e.flying ? 0.6 : 1),
          body: this.scene.add.image(0, 0, key).setDepth(e.flying ? DEPTH.air : DEPTH.enemies).setScale(baseScale),
          baseScale,
        };
        this.enemies.set(e, s);
      }
      const x = lerp(e.prevX, e.x, alpha), y = lerp(e.prevY, e.y, alpha);
      const bob = e.flying ? Math.sin((this.frameCount + e.id * 13) * 0.12) * 2 : 0;
      s.body.setPosition(x, y + bob).setRotation(lerpAngle(e.prevAngle, e.angle, alpha));
      s.shadow.setPosition(x + (e.flying ? 8 : 2), y + (e.flying ? 16 : 5));

      if (e.hitFlash > 0) {
        s.body.setTint(0xffffff).setTintMode(Phaser.TintModes.FILL);
      } else {
        s.body.setTintMode(Phaser.TintModes.MULTIPLY);
        if (e.slow > 0) s.body.setTint(0x9fdcff);
        else if (e.def.tint) s.body.setTint(e.def.tint);
        else s.body.clearTint();
      }
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
        img = this.scene.add.image(0, 0, b.type).setDepth(DEPTH.bullets);
        this.bullets.set(b, img);
      }
      const x = lerp(b.prevX, b.x, alpha), y = lerp(b.prevY, b.y, alpha);
      if (b.type === 'shell') {
        // Fake a ballistic arc: shells grow a little towards the middle of their flight.
        // The texture is drawn at GEN x size, so 1 / GEN is its normal (6 px) size.
        const p = b.flight > 0 ? b.travelled / b.flight : 1;
        img.setPosition(x, y).setScale((1 + Math.sin(Math.PI * p) * 0.5) / GEN);
      } else {
        img.setPosition(x, y).setRotation(b.angle);
      }
      if (b.type === 'missile' && this.frameCount % 3 === 0) {
        this.smoke.emitParticleAt(x - Math.cos(b.angle) * 6, y - Math.sin(b.angle) * 6, 1);
      }
    }
  }

  private drawBars(alpha: number): void {
    const g = this.bars.clear();
    for (const e of this.world.enemies) {
      const x = lerp(e.prevX, e.x, alpha), y = lerp(e.prevY, e.y, alpha);
      if (e.maxShield > 0 && e.shield > 0) {
        const f = e.shield / e.maxShield;
        g.lineStyle(2, 0x7ad3ff, 0.35 + 0.5 * f).strokeCircle(x, y, e.radius + 5);
        g.fillStyle(0x7ad3ff, 0.12 * f).fillCircle(x, y, e.radius + 5);
      }
      if (e.def.boss) continue; // bosses get a big bar at the top of the screen
      if (e.hitpoints >= e.maxHitpoints && (e.maxShield === 0 || e.shield >= e.maxShield)) continue;
      const bx = x - 12, by = y - e.radius - 10;
      const frac = Math.max(0, e.hitpoints / e.maxHitpoints);
      g.fillStyle(0x000000, 0.6).fillRect(bx - 1, by - 1, 26, 6);
      g.fillStyle(frac > 0.5 ? COLORS.green : frac > 0.25 ? COLORS.gold : COLORS.red, 1).fillRect(bx, by, 24 * frac, 4);
      if (e.maxShield > 0) {
        g.fillStyle(0x7ad3ff, 1).fillRect(bx, by - 3, 24 * (e.shield / e.maxShield), 2);
      }
    }
    // Tower level pips and beacon boost marker.
    for (const t of this.world.towers) {
      for (let i = 0; i < t.level; i++) {
        g.fillStyle(0x000000, 0.6).fillCircle(t.x - 4 + i * 8 - (t.level - 1) * 4 + 4, t.y + 17, 3.5);
        g.fillStyle(COLORS.gold, 1).fillCircle(t.x - 4 + i * 8 - (t.level - 1) * 4 + 4, t.y + 17, 2.5);
      }
      if (t.buff > 0) {
        g.fillStyle(COLORS.gold, 0.95).fillTriangle(t.x + 12, t.y - 10, t.x + 16, t.y - 16, t.x + 20, t.y - 10);
      }
    }
  }

  // ---- events ----------------------------------------------------------------

  private sound(name: SfxName): void {
    if (!this.quiet) audio.play(name);
  }

  private ring(x: number, y: number, radius: number, color: number, duration = 450): void {
    const r = this.scene.add.image(x, y, 'ring').setDepth(DEPTH.effects).setTint(color).setAlpha(0.8).setScale(0.1);
    this.scene.tweens.add({
      targets: r, scale: (radius * 2) / 128, alpha: 0, duration, ease: 'Cubic.easeOut',
      onComplete: () => r.destroy(),
    });
  }

  /** Turns world events into visual effects and sounds. Clears the world's event list. */
  handleEvents(events: WorldEvent[]): void {
    for (const ev of events) {
      switch (ev.type) {
        case 'shot': {
          const sfx = SHOT_SOUND[ev.kind];
          if (sfx) this.sound(sfx);
          break;
        }
        case 'kill': {
          const big = ev.enemy === 'tank' || ev.enemy === 'boss' || ev.enemy === 'armored';
          this.explosion.explode(ev.enemy === 'boss' ? 60 : big ? 22 : 12, ev.x, ev.y);
          if (ev.enemy === 'boss') {
            this.ring(ev.x, ev.y, 120, 0xff8c42, 700);
            if (!this.quiet) this.scene.cameras.main.shake(400, 0.012);
            this.sound('bigExplosion');
          } else {
            this.sound(big ? 'explode' : 'pop');
            if (big && !this.quiet) this.scene.cameras.main.shake(120, 0.003);
          }
          if (!this.quiet) this.floatText(ev.x, ev.y - 10, `+$${ev.amount}`, CSS.gold);
          break;
        }
        case 'hit':
          this.sparks.explode(ev.bullet === 'missile' ? 6 : 3, ev.x, ev.y);
          this.sound('hit');
          break;
        case 'explode':
          this.explosion.explode(16, ev.x, ev.y);
          this.ring(ev.x, ev.y, ev.radius, 0xffb347, 350);
          this.sound('explode');
          break;
        case 'pulse':
          this.ring(ev.x, ev.y, ev.radius, 0x7ad3ff, 600);
          this.frost.explode(10, ev.x, ev.y);
          this.sound('frost');
          break;
        case 'heal':
          this.ring(ev.x, ev.y, ev.radius, 0x69db7c, 500);
          this.sound('heal');
          break;
        case 'summon':
          this.ring(ev.x, ev.y, 60, 0xff6b6b, 500);
          this.sound('summon');
          break;
        case 'build':
          this.dust.explode(14, ev.x, ev.y + 8);
          this.sound('build');
          break;
        case 'upgrade':
          this.stars.explode(16, ev.x, ev.y);
          this.ring(ev.x, ev.y, 30, COLORS.gold, 400);
          this.sound('upgrade');
          break;
        case 'sell':
          this.dust.explode(10, ev.x, ev.y);
          this.floatText(ev.x, ev.y - 10, `+$${ev.amount}`, CSS.gold);
          this.sound('sell');
          break;
        case 'leak':
          if (this.quiet) break;
          this.floatText(Math.min(Math.max(ev.x, 30), FIELD_W - 30), Math.min(Math.max(ev.y, 20), FIELD_H - 20),
            `-${ev.amount} ♥`, CSS.red);
          this.scene.cameras.main.shake(140, 0.004);
          this.scene.cameras.main.flash(160, 180, 30, 30);
          this.sound('leak');
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
