import * as Phaser from 'phaser';
import { WIDTH } from '../config';
import { LEVELS, ENDLESS } from '../data/levels';
import { GameMap } from '../sim/map';
import { Button } from '../ui/Button';
import { drawMinimap } from '../ui/minimap';
import { COLORS, CSS, addText, setupCamera } from '../ui/theme';
import { starString } from '../ui/format';
import { loadProfile, isLevelUnlocked, isEndlessUnlocked, totalStars } from '../game/profile';
import { audio } from '../audio/audio';

const CARD_W = 290, CARD_H = 236, GAP = 20;

export class LevelSelectScene extends Phaser.Scene {
  constructor() {
    super('levels');
  }

  create(): void {
    setupCamera(this);
    const profile = loadProfile();
    this.add.rectangle(0, 0, WIDTH, 600, COLORS.background).setOrigin(0);

    addText(this, WIDTH / 2, 36, 'Choose a level', { fontSize: '30px', fontStyle: 'bold' }).setOrigin(0.5);
    addText(this, WIDTH / 2, 66, `★ ${totalStars(profile)} stars`, { fontSize: '15px', color: CSS.gold }).setOrigin(0.5);
    new Button(this, 20, 18, 100, 40, { label: '‹ Back', onClick: () => this.scene.start('menu') });
    new Button(this, WIDTH - 140, 18, 120, 40, { label: 'Upgrades', onClick: () => this.scene.start('upgrades') });

    const x0 = (WIDTH - 3 * CARD_W - 2 * GAP) / 2;
    const cards = [
      ...LEVELS.map((level, i) => ({
        title: `${i + 1}. ${level.name}`,
        desc: level.description,
        map: new GameMap(level),
        unlocked: isLevelUnlocked(profile, i),
        lockText: i > 0 ? `Beat ${LEVELS[i - 1].name} first` : '',
        status: starString(profile.stars[level.id] ?? 0),
        statusColor: CSS.gold,
        extra: `${level.waves.length} waves${level.maze ? ' · maze' : ''}`,
        id: level.id,
      })),
      {
        title: ENDLESS.name,
        desc: ENDLESS.description,
        map: new GameMap(ENDLESS),
        unlocked: isEndlessUnlocked(profile),
        lockText: `Beat ${LEVELS[1].name} first`,
        status: profile.endlessBest ? `Best: ${profile.endlessBest} waves` : 'No record yet',
        statusColor: CSS.text,
        extra: 'Survive as long as you can',
        id: 'endless',
      },
    ];

    cards.forEach((card, i) => {
      const x = x0 + (i % 3) * (CARD_W + GAP);
      const y = 96 + Math.floor(i / 3) * (CARD_H + GAP);
      const g = this.add.graphics();
      g.fillStyle(COLORS.panel, 1).fillRoundedRect(x, y, CARD_W, CARD_H, 12);
      g.lineStyle(1, COLORS.border, 1).strokeRoundedRect(x, y, CARD_W, CARD_H, 12);
      drawMinimap(g, card.map, x + 15, y + 12, 7); // 140 x 105
      const alpha = card.unlocked ? 1 : 0.35;
      g.setAlpha(card.unlocked ? 1 : 0.6);
      const tx = x + 168;
      addText(this, tx, y + 14, card.status, {
        fontSize: card.id === 'endless' ? '13px' : '20px', color: card.statusColor, wordWrap: { width: 110 },
      }).setAlpha(alpha);
      addText(this, tx, y + 50, card.extra, { fontSize: '12px', color: CSS.textDim, wordWrap: { width: 110 } }).setAlpha(alpha);
      addText(this, x + 15, y + 124, card.title, { fontSize: '18px', fontStyle: 'bold' }).setAlpha(alpha);
      addText(this, x + 15, y + 148, card.unlocked ? card.desc : `🔒 ${card.lockText}`, {
        fontSize: '13px', color: CSS.textDim, wordWrap: { width: CARD_W - 30 },
      });
      new Button(this, x + 15, y + CARD_H - 44, CARD_W - 30, 34, {
        label: card.unlocked ? 'Play' : 'Locked', variant: card.unlocked ? 'primary' : 'default', fontSize: 15,
        onClick: () => {
          if (!card.unlocked) return;
          this.scene.start('game', { levelId: card.id });
        },
      }).setEnabled(card.unlocked);
    });

    this.input.keyboard?.on('keydown-ESC', () => this.scene.start('menu'));
    audio.setIntensity(0);
  }
}
