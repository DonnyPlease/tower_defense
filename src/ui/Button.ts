import * as Phaser from 'phaser';
import { COLORS, CSS, addText } from './theme';

export type ButtonVariant = 'default' | 'primary' | 'danger';

export interface ButtonOptions {
  label: string;
  sublabel?: string;
  icon?: string; // texture key
  hotkey?: string;
  variant?: ButtonVariant;
  fontSize?: number;
  onClick: () => void;
}

/** A rounded, canvas-drawn button with hover / selected / disabled states. */
export class Button {
  private readonly bg: Phaser.GameObjects.Graphics;
  private readonly labelText: Phaser.GameObjects.Text;
  private readonly subText: Phaser.GameObjects.Text | null = null;
  private readonly hotkeyText: Phaser.GameObjects.Text | null = null;
  private readonly icon: Phaser.GameObjects.Image | null = null;
  private readonly zone: Phaser.GameObjects.Zone;
  private hover = false;
  private enabled = true;
  private selected = false;
  private visible = true;

  constructor(
    scene: Phaser.Scene,
    readonly x: number, readonly y: number, readonly w: number, readonly h: number,
    private readonly opts: ButtonOptions,
  ) {
    this.bg = scene.add.graphics();

    let textX = x + w / 2;
    let originX = 0.5;
    if (opts.icon) {
      const s = Math.min(40, h - 12);
      this.icon = scene.add.image(x + 10 + s / 2, y + h / 2, opts.icon).setDisplaySize(s, s);
      textX = x + 18 + s;
      originX = 0;
    }
    const hasSub = opts.sublabel !== undefined;
    this.labelText = addText(scene, textX, y + h / 2 - (hasSub ? 9 : 0), opts.label, {
      fontSize: `${opts.fontSize ?? 16}px`, fontStyle: 'bold',
    }).setOrigin(originX, 0.5);
    if (hasSub) {
      this.subText = addText(scene, textX, y + h / 2 + 11, opts.sublabel!, {
        fontSize: '13px', color: CSS.textDim,
      }).setOrigin(originX, 0.5);
    }
    if (opts.hotkey) {
      this.hotkeyText = addText(scene, x + w - 8, y + 6, opts.hotkey, {
        fontSize: '11px', color: CSS.textDim, fontStyle: 'bold',
      }).setOrigin(1, 0);
    }

    this.zone = scene.add.zone(x, y, w, h).setOrigin(0, 0).setInteractive({ useHandCursor: true });
    this.zone.on('pointerover', () => { this.hover = true; this.redraw(); });
    this.zone.on('pointerout', () => { this.hover = false; this.redraw(); });
    this.zone.on('pointerdown', (pointer: Phaser.Input.Pointer) => {
      if (this.enabled && pointer.button === 0) opts.onClick();
    });
    this.redraw();
  }

  private get objects(): Phaser.GameObjects.GameObject[] {
    return [this.bg, this.labelText, this.subText, this.hotkeyText, this.icon, this.zone]
      .filter((o): o is NonNullable<typeof o> => o !== null);
  }

  setDepth(depth: number): this {
    for (const o of this.objects) (o as unknown as Phaser.GameObjects.Components.Depth).setDepth(depth);
    return this;
  }

  setVisible(visible: boolean): this {
    if (visible === this.visible) return this;
    this.visible = visible;
    for (const o of this.objects) (o as unknown as Phaser.GameObjects.Components.Visible).setVisible(visible);
    if (this.zone.input) this.zone.input.enabled = visible;
    if (!visible) this.hover = false;
    return this;
  }

  setEnabled(enabled: boolean): this {
    if (enabled !== this.enabled) {
      this.enabled = enabled;
      this.redraw();
    }
    return this;
  }

  setSelected(selected: boolean): this {
    if (selected !== this.selected) {
      this.selected = selected;
      this.redraw();
    }
    return this;
  }

  setLabel(label: string): this {
    if (this.labelText.text !== label) this.labelText.setText(label);
    return this;
  }

  setSublabel(text: string, color: string = CSS.textDim): this {
    if (this.subText && (this.subText.text !== text || this.subText.style.color !== color)) {
      this.subText.setText(text).setColor(color);
    }
    return this;
  }

  private redraw(): void {
    const { x, y, w, h } = this;
    const base = {
      default: COLORS.panelLight,
      primary: COLORS.accent,
      danger: COLORS.red,
    }[this.opts.variant ?? 'default'];

    const g = this.bg.clear();
    g.fillStyle(this.selected ? COLORS.panelLighter : base, 1);
    g.fillRoundedRect(x, y, w, h, 8);
    if (this.hover && this.enabled) {
      g.fillStyle(0xffffff, 0.1);
      g.fillRoundedRect(x, y, w, h, 8);
    }
    g.lineStyle(this.selected ? 2.5 : 1, this.selected ? COLORS.gold : COLORS.border, 1);
    g.strokeRoundedRect(x, y, w, h, 8);

    const alpha = this.enabled ? 1 : 0.4;
    for (const o of [this.bg, this.labelText, this.subText, this.hotkeyText, this.icon]) o?.setAlpha(alpha);
  }
}
