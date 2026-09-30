import type { Point } from './map';

const SAMPLE = 4; // pixels between samples of a smoothed route
const INNER_BEND = 0.6; // fraction of a bend's radius usable on its inside
const WIDTH_SLOPE = 0.2; // how fast the usable width may change along the route (px per px)

/**
 * A smooth path through a list of corner points, sampled every few pixels.
 * For every sample it also knows how far an enemy may walk to either side of
 * the centre line and still stay on the road, so enemies can use lanes.
 */
export class Route {
  readonly points: Point[];
  /** Unit normals pointing to the left of the walking direction. */
  readonly normals: Point[];
  /** Path length from the start to each sample. */
  readonly cum: number[];
  /** Usable offset to the left (positive) and right (negative normal) of each sample. */
  readonly left: number[];
  readonly right: number[];
  readonly length: number;

  /**
   * @param corners  polyline to smooth (first and last points are kept)
   * @param free     how far one may go from `p` along `n` (at most `max`)
   */
  constructor(corners: Point[], free: (p: Point, n: Point) => number, clearance?: (p: Point) => number) {
    this.points = clearance ? roundPath(corners, clearance) : resample(chaikin(corners, 2), SAMPLE);
    const n = this.points.length;
    this.normals = [];
    this.cum = [0];
    for (let i = 0; i < n; i++) {
      const a = this.points[Math.max(0, i - 1)], b = this.points[Math.min(n - 1, i + 1)];
      const len = Math.hypot(b.x - a.x, b.y - a.y) || 1;
      this.normals.push({ x: (b.y - a.y) / len, y: -(b.x - a.x) / len });
      if (i > 0) {
        const p = this.points[i - 1], q = this.points[i];
        this.cum.push(this.cum[i - 1] + Math.hypot(q.x - p.x, q.y - p.y));
      }
    }
    this.length = this.cum[n - 1];
    this.left = this.points.map((p, i) => free(p, this.normals[i]));
    this.right = this.points.map((p, i) => free(p, { x: -this.normals[i].x, y: -this.normals[i].y }));
    // On the inside of a bend, stay closer to the middle than the bend's
    // radius, or the lane would loop backwards.
    for (let i = 1; i < n - 1; i++) {
      const a = this.points[i - 1], b = this.points[i], c = this.points[i + 1];
      const cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (Math.abs(cross) < 1e-9) continue;
      const radius = (Math.hypot(b.x - a.x, b.y - a.y) * Math.hypot(c.x - b.x, c.y - b.y) * Math.hypot(c.x - a.x, c.y - a.y)) /
        (2 * Math.abs(cross));
      const inner = this.normals[i].x * (a.x + c.x - 2 * b.x) + this.normals[i].y * (a.y + c.y - 2 * b.y) > 0 ? this.left : this.right;
      inner[i] = Math.min(inner[i], INNER_BEND * radius);
    }
    limitSlope(this.left, this.cum);
    limitSlope(this.right, this.cum);
  }

  /** Index of the sample segment containing distance `s`, starting the search at `hint`. */
  seek(s: number, hint = 0): number {
    let i = Math.max(0, Math.min(hint, this.points.length - 2));
    while (i < this.points.length - 2 && this.cum[i + 1] <= s) i++;
    while (i > 0 && this.cum[i] > s) i--;
    return i;
  }

  /** Point at distance `s` along the route, shifted `offset` pixels to the left. */
  at(s: number, offset: number, i: number): Point {
    const a = this.points[i], b = this.points[i + 1] ?? a;
    const seg = this.cum[i + 1] - this.cum[i] || 1;
    const t = Math.max(0, Math.min(1, (s - this.cum[i]) / seg));
    const na = this.normals[i], nb = this.normals[i + 1] ?? na;
    return {
      x: a.x + (b.x - a.x) * t + (na.x + (nb.x - na.x) * t) * offset,
      y: a.y + (b.y - a.y) * t + (na.y + (nb.y - na.y) * t) * offset,
    };
  }

  /** Allowed offset range [-right, left] at sample `i`. */
  clampOffset(offset: number, i: number): number {
    return Math.max(-this.right[i], Math.min(this.left[i], offset));
  }
}

const MARGIN = 14; // the centre line keeps this far from the verge
const SMOOTH_PASSES = 200;

/**
 * Turns a tile-by-tile path (along the middle of the road) into a natural
 * curve: relaxes the zig-zags into diagonals and the corners into arcs as
 * wide as the road allows. `clearance(p)` is the distance from p to the
 * nearest spot enemies can't walk on.
 */
export function roundPath(pts: Point[], clearance: (p: Point) => number): Point[] {
  const p = resample(pts, SAMPLE);
  for (let pass = 0; pass < SMOOTH_PASSES; pass++) {
    for (let i = 1; i < p.length - 1; i++) {
      const q = { x: (p[i].x + (p[i - 1].x + p[i + 1].x) / 2) / 2, y: (p[i].y + (p[i - 1].y + p[i + 1].y) / 2) / 2 };
      if (clearance(q) >= Math.min(MARGIN, clearance(p[i]))) p[i] = q;
    }
  }
  return resample(p, SAMPLE);
}

/** Chaikin corner cutting: rounds every corner, keeps the end points. */
export function chaikin(pts: Point[], iterations: number): Point[] {
  let out = pts;
  for (let k = 0; k < iterations; k++) {
    const next: Point[] = [out[0]];
    for (let i = 0; i < out.length - 1; i++) {
      const a = out[i], b = out[i + 1];
      next.push({ x: 0.75 * a.x + 0.25 * b.x, y: 0.75 * a.y + 0.25 * b.y });
      next.push({ x: 0.25 * a.x + 0.75 * b.x, y: 0.25 * a.y + 0.75 * b.y });
    }
    next.push(out[out.length - 1]);
    out = next;
  }
  return out;
}

/** Points spaced `step` pixels apart along the polyline. */
export function resample(pts: Point[], step: number): Point[] {
  const out: Point[] = [pts[0]];
  let carry = 0; // distance walked since the last emitted point
  for (let i = 0; i < pts.length - 1; i++) {
    const a = pts[i], b = pts[i + 1];
    const len = Math.hypot(b.x - a.x, b.y - a.y);
    let t = step - carry;
    while (t <= len) {
      out.push({ x: a.x + ((b.x - a.x) * t) / len, y: a.y + ((b.y - a.y) * t) / len });
      t += step;
    }
    carry = len - (t - step);
  }
  const last = pts[pts.length - 1], tail = out[out.length - 1];
  if (Math.hypot(last.x - tail.x, last.y - tail.y) > 1e-6) out.push(last);
  return out;
}

/** Makes widths change gradually, so a lane narrows before the road does. */
function limitSlope(w: number[], cum: number[]): void {
  for (let i = 1; i < w.length; i++) w[i] = Math.min(w[i], w[i - 1] + WIDTH_SLOPE * (cum[i] - cum[i - 1]));
  for (let i = w.length - 2; i >= 0; i--) w[i] = Math.min(w[i], w[i + 1] + WIDTH_SLOPE * (cum[i + 1] - cum[i]));
}
