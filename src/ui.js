// Shared colours, fonts and a canvas-drawn Button.

export const COLORS = {
  panel: '#1e2230',
  panelLight: '#2a3042',
  panelLighter: '#353d54',
  border: '#454f6b',
  text: '#e8ecf4',
  textDim: '#9aa3b8',
  gold: '#f5c542',
  red: '#e5534b',
  green: '#57c26b',
  accent: '#4f8ef7',
};

export const font = (size, weight = 600) =>
  `${weight} ${size}px system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`;

export function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

export class Button {
  // opts: onClick, label (string or () => string), sublabel, icon (image),
  //       enabled(), selected(), variant ('default' | 'primary' | 'danger')
  constructor(x, y, w, h, opts) {
    Object.assign(this, { x, y, w, h });
    this.onClick = opts.onClick;
    this.label = opts.label ?? '';
    this.sublabel = opts.sublabel ?? null;
    this.icon = opts.icon ?? null;
    this.enabled = opts.enabled ?? (() => true);
    this.selected = opts.selected ?? (() => false);
    this.variant = opts.variant ?? 'default';
    this.hotkey = opts.hotkey ?? null;
    this.hover = false;
  }

  contains(px, py) {
    return px >= this.x && px < this.x + this.w && py >= this.y && py < this.y + this.h;
  }

  click() {
    if (this.enabled()) this.onClick();
  }

  draw(ctx) {
    const enabled = this.enabled();
    const selected = this.selected();
    const base = { default: COLORS.panelLight, primary: COLORS.accent, danger: COLORS.red }[this.variant];

    ctx.save();
    ctx.globalAlpha = enabled ? 1 : 0.45;
    roundRect(ctx, this.x, this.y, this.w, this.h, 8);
    ctx.fillStyle = selected ? COLORS.panelLighter : base;
    ctx.fill();
    if (this.hover && enabled) {
      ctx.fillStyle = 'rgba(255,255,255,0.08)';
      ctx.fill();
    }
    ctx.lineWidth = selected ? 2.5 : 1;
    ctx.strokeStyle = selected ? COLORS.gold : COLORS.border;
    ctx.stroke();

    let textX = this.x + this.w / 2;
    let align = 'center';
    if (this.icon) {
      const s = Math.min(40, this.h - 12);
      ctx.drawImage(this.icon, this.x + 10, this.y + (this.h - s) / 2, s, s);
      textX = this.x + 18 + s;
      align = 'left';
    }
    const label = typeof this.label === 'function' ? this.label() : this.label;
    const sub = typeof this.sublabel === 'function' ? this.sublabel() : this.sublabel;
    ctx.textAlign = align;
    ctx.textBaseline = 'middle';
    ctx.fillStyle = COLORS.text;
    ctx.font = font(16);
    ctx.fillText(label, textX, this.y + this.h / 2 - (sub ? 9 : 0));
    if (sub) {
      ctx.font = font(13, 500);
      ctx.fillStyle = sub.color ?? COLORS.textDim;
      ctx.fillText(sub.text ?? sub, textX, this.y + this.h / 2 + 11);
    }
    if (this.hotkey) {
      ctx.font = font(11, 700);
      ctx.textAlign = 'right';
      ctx.fillStyle = COLORS.textDim;
      ctx.fillText(this.hotkey.toUpperCase(), this.x + this.w - 8, this.y + 12);
    }
    ctx.restore();
  }
}

// Draws buttons, updates hover state, and routes clicks. Returns true when a
// button consumed the click.
export class ButtonSet {
  constructor(buttons = []) {
    this.buttons = buttons;
  }

  add(b) {
    this.buttons.push(b);
    return b;
  }

  pointerMove(x, y) {
    let any = false;
    for (const b of this.buttons) {
      b.hover = b.contains(x, y);
      any ||= b.hover && b.enabled();
    }
    return any;
  }

  pointerDown(x, y) {
    const b = this.buttons.find((b) => b.contains(x, y));
    if (!b) return false;
    b.click();
    return true;
  }

  draw(ctx) {
    for (const b of this.buttons) b.draw(ctx);
  }
}
