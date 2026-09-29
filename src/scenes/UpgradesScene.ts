import * as Phaser from 'phaser';
import { WIDTH } from '../config';
import { PERKS, PERK_IDS } from '../data/perks';
import { TOWER_KINDS, towerDef } from '../data/towers';
import { Button } from '../ui/Button';
import { COLORS, CSS, addText, setupCamera, towerIcon } from '../ui/theme';
import {
  loadProfile, availableStars, totalStars, nextPerkCost, buyPerk, refundPerks, unlockedTowers,
} from '../game/profile';
import { audio } from '../audio/audio';

/** Spend stars on permanent upgrades; also shows which towers are unlocked. */
export class UpgradesScene extends Phaser.Scene {
  constructor() {
    super('upgrades');
  }

  create(): void {
    setupCamera(this);
    const profile = loadProfile();
    this.add.rectangle(0, 0, WIDTH, 600, COLORS.background).setOrigin(0);
    addText(this, WIDTH / 2, 36, 'Upgrades', { fontSize: '30px', fontStyle: 'bold' }).setOrigin(0.5);
    const starsText = addText(this, WIDTH / 2, 66, '', { fontSize: '15px', color: CSS.gold }).setOrigin(0.5);
    new Button(this, 20, 18, 100, 40, { label: '‹ Back', onClick: () => this.scene.start('menu') });
    new Button(this, WIDTH - 140, 18, 120, 40, { label: 'Levels', onClick: () => this.scene.start('levels') });

    // Perk rows.
    const rows = PERK_IDS.map((id, i) => {
      const y = 100 + i * 76;
      const perk = PERKS[id];
      this.add.graphics().fillStyle(COLORS.panel, 1).fillRoundedRect(60, y, 560, 64, 10)
        .lineStyle(1, COLORS.border, 1).strokeRoundedRect(60, y, 560, 64, 10);
      const name = addText(this, 78, y + 10, perk.name, { fontSize: '17px', fontStyle: 'bold' });
      const effect = addText(this, 78, y + 36, '', { fontSize: '13px', color: CSS.textDim });
      const pips = this.add.graphics();
      const pipX = 78 + name.width + 18;
      const buy = new Button(this, 470, y + 12, 136, 40, {
        label: '', variant: 'primary', fontSize: 14,
        onClick: () => {
          if (buyPerk(profile, id)) audio.play('upgrade');
          refresh();
        },
      });
      return { id, perk, y, effect, pips, pipX, buy };
    });

    new Button(this, 60, 412, 180, 36, {
      label: 'Refund all stars', fontSize: 13,
      onClick: () => { refundPerks(profile); audio.play('sell'); refresh(); },
    });

    // Tower unlocks.
    this.add.graphics().fillStyle(COLORS.panel, 1).fillRoundedRect(650, 100, 290, 348, 10)
      .lineStyle(1, COLORS.border, 1).strokeRoundedRect(650, 100, 290, 348, 10);
    addText(this, 668, 110, 'Towers', { fontSize: '17px', fontStyle: 'bold' });
    addText(this, 668, 134, 'Unlocked by total stars earned', { fontSize: '12px', color: CSS.textDim });
    const unlocked = unlockedTowers(profile);
    TOWER_KINDS.forEach((kind, i) => {
      const y = 164 + i * 46;
      const d = towerDef(kind);
      const have = unlocked.includes(kind);
      this.add.image(690, y + 16, towerIcon(this, kind)).setDisplaySize(32, 32).setAlpha(have ? 1 : 0.35);
      addText(this, 716, y + 6, d.name, { fontSize: '15px', fontStyle: 'bold', color: have ? CSS.text : CSS.textDim });
      addText(this, 920, y + 7, have ? '✓' : `★ ${d.unlockStars}`, {
        fontSize: '15px', color: have ? CSS.green : CSS.gold,
      }).setOrigin(1, 0);
    });

    addText(this, WIDTH / 2, 490, 'Earn up to 3 stars per level: 3 for losing no lives, 2 for keeping at least half.', {
      fontSize: '13px', color: CSS.textDim,
    }).setOrigin(0.5);

    const refresh = () => {
      starsText.setText(`★ ${availableStars(profile)} to spend  (${totalStars(profile)} earned)`);
      for (const r of rows) {
        const rank = profile.perks[r.id] ?? 0;
        const max = r.perk.costs.length;
        r.effect.setText(rank > 0
          ? r.perk.effect(rank) + (rank < max ? `   (next: ${r.perk.effect(rank + 1)})` : '')
          : `Next: ${r.perk.effect(1)}`);
        r.pips.clear();
        for (let i = 0; i < max; i++) {
          r.pips.fillStyle(i < rank ? COLORS.gold : COLORS.panelLighter, 1).fillCircle(r.pipX + i * 16, r.y + 21, 5);
        }
        const cost = nextPerkCost(profile, r.id);
        if (cost === null) r.buy.setLabel('Maxed').setEnabled(false);
        else r.buy.setLabel(`Buy  ★ ${cost}`).setEnabled(cost <= availableStars(profile));
      }
    };
    refresh();
    this.input.keyboard?.on('keydown-ESC', () => this.scene.start('menu'));
  }
}
