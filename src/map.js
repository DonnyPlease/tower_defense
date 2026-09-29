import { TILE, COLS, ROWS } from './config.js';

const DIRS = [[1, 0], [0, 1], [-1, 0], [0, -1]];

export class GameMap {
  constructor(def) {
    this.name = def.name;
    if (def.tiles.length !== ROWS || def.tiles.some((r) => r.length !== COLS)) {
      throw new Error(`Map "${def.name}" must be ${COLS}x${ROWS} tiles`);
    }
    this.path = def.tiles.map((row) => [...row].map((ch) => ch !== '.'));
    this.starts = [];
    this.ends = [];
    def.tiles.forEach((row, r) => [...row].forEach((ch, c) => {
      if (ch === 'S') this.starts.push({ col: c, row: r });
      if (ch === 'E') this.ends.push({ col: c, row: r });
    }));
    if (!this.starts.length || !this.ends.length) {
      throw new Error(`Map "${def.name}" needs at least one S and one E tile`);
    }
    // Pre-compute one route (list of pixel waypoints) for every start/end pair.
    this.routes = [];
    for (const s of this.starts) {
      for (const e of this.ends) {
        const tiles = this.findPath(s, e);
        if (!tiles) throw new Error(`Map "${def.name}": no path from S to E`);
        this.routes.push(this.toWaypoints(tiles));
      }
    }
  }

  inBounds(col, row) {
    return col >= 0 && col < COLS && row >= 0 && row < ROWS;
  }

  isPath(col, row) {
    return this.inBounds(col, row) && this.path[row][col];
  }

  // Shortest path over path tiles. Uses a BFS distance field from the end and
  // then walks down the gradient, preferring to keep the current direction, so
  // enemies take the fewest turns among all shortest paths.
  findPath(start, end) {
    const dist = Array.from({ length: ROWS }, () => new Array(COLS).fill(Infinity));
    dist[end.row][end.col] = 0;
    const queue = [end];
    for (let i = 0; i < queue.length; i++) {
      const { col, row } = queue[i];
      for (const [dc, dr] of DIRS) {
        const c = col + dc, r = row + dr;
        if (this.isPath(c, r) && dist[r][c] === Infinity) {
          dist[r][c] = dist[row][col] + 1;
          queue.push({ col: c, row: r });
        }
      }
    }
    if (dist[start.row][start.col] === Infinity) return null;

    const tiles = [start];
    let cur = start;
    let dir = this.outward(start).map((v) => -v);
    while (dist[cur.row][cur.col] > 0) {
      const d = dist[cur.row][cur.col];
      const options = [dir, ...DIRS].filter(([dc, dr]) =>
        this.isPath(cur.col + dc, cur.row + dr) && dist[cur.row + dr][cur.col + dc] === d - 1);
      dir = options[0];
      cur = { col: cur.col + dir[0], row: cur.row + dir[1] };
      tiles.push(cur);
    }
    return tiles;
  }

  // Direction pointing off the map from a border tile.
  outward({ col, row }) {
    if (col === 0) return [-1, 0];
    if (col === COLS - 1) return [1, 0];
    if (row === 0) return [0, -1];
    if (row === ROWS - 1) return [0, 1];
    return [0, 0];
  }

  // Converts a tile path into pixel waypoints, starting one tile outside the
  // map and ending one tile outside the map. Collinear points are dropped.
  toWaypoints(tiles) {
    const center = (t) => ({ x: t.col * TILE + TILE / 2, y: t.row * TILE + TILE / 2 });
    const first = tiles[0], last = tiles[tiles.length - 1];
    const [ic, ir] = this.outward(first);
    const [oc, or] = this.outward(last);
    const pts = [
      center({ col: first.col + ic, row: first.row + ir }),
      ...tiles.map(center),
      center({ col: last.col + oc, row: last.row + or }),
    ];
    const out = [pts[0]];
    for (let i = 1; i < pts.length - 1; i++) {
      const a = out[out.length - 1], b = pts[i], c = pts[i + 1];
      const cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross !== 0) out.push(b);
    }
    out.push(pts[pts.length - 1]);
    return out;
  }
}
