import * as Phaser from 'phaser';
import { WIDTH, HEIGHT } from '../config';
import { Button, type ButtonVariant } from './Button';
import { COLORS, CSS, addText } from './theme';

export interface OverlayAction {
  label: string;
  variant?: ButtonVariant;
  onClick: () => void;
}

const DEPTH = 200;

/** A modal dialog (pause, victory, defeat) that dims and blocks the game. */
export class Overlay {
  private readonly objects: (Phaser.GameObjects.GameObject & Phaser.GameObjects.Components.Visible)[] = [];
  private readonly buttons: Button[] = [];
  private readonly blocker: Phaser.GameObjects.Zone;
  private readonly subtitleText: Phaser.GameObjects.Text;
  visible = true;

  constructor(scene: Phaser.Scene, title: string, titleColor: string, actions: OverlayAction[]) {
    const panelW = 320;
    const panelH = 136 + actions.length * 60;
    const px = (WIDTH - panelW) / 2, py = (HEIGHT - panelH) / 2;

    const dim = scene.add.rectangle(0, 0, WIDTH, HEIGHT, 0x000000, 0.5).setOrigin(0).setDepth(DEPTH);
    // Swallows clicks so nothing underneath reacts while the overlay is open.
    this.blocker = scene.add.zone(0, 0, WIDTH, HEIGHT).setOrigin(0).setDepth(DEPTH).setInteractive();
    const panel = scene.add.graphics().setDepth(DEPTH)
      .fillStyle(COLORS.panel, 0.97).fillRoundedRect(px, py, panelW, panelH, 14)
      .lineStyle(1, COLORS.border, 1).strokeRoundedRect(px, py, panelW, panelH, 14);
    const titleText = addText(scene, WIDTH / 2, py + 36, title, {
      fontSize: '32px', fontStyle: 'bold', color: titleColor,
    }).setOrigin(0.5).setDepth(DEPTH);
    this.subtitleText = addText(scene, WIDTH / 2, py + 84, '', {
      fontSize: '15px', color: CSS.textDim, align: 'center',
    }).setOrigin(0.5).setDepth(DEPTH);
    this.objects.push(dim, this.blocker, panel, titleText, this.subtitleText);

    actions.forEach((a, i) => {
      this.buttons.push(new Button(scene, px + 40, py + 120 + i * 60, panelW - 80, 48, {
        label: a.label, variant: a.variant, onClick: a.onClick,
      }).setDepth(DEPTH + 1));
    });
    this.hide();
  }

  show(subtitle = ''): void {
    this.subtitleText.setText(subtitle);
    this.setVisible(true);
  }

  hide(): void {
    this.setVisible(false);
  }

  private setVisible(v: boolean): void {
    if (v === this.visible) return;
    this.visible = v;
    for (const o of this.objects) o.setVisible(v);
    if (this.blocker.input) this.blocker.input.enabled = v;
    for (const b of this.buttons) b.setVisible(v);
  }
}
