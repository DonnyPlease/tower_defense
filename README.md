# Tower Defense

A browser tower defense game built with [Phaser 4](https://phaser.io) and TypeScript.
It runs in any modern browser, works with mouse or touch, and scales to any screen.

## Running it

You need [Node.js](https://nodejs.org) 20 or newer.

```bash
npm install
npm run dev        # dev server with hot reload at http://localhost:5173
npm test           # unit tests for the game logic
npm run build      # type-check and build a static site into dist/
npm run preview    # serve the built dist/ folder
```

`dist/` is a plain static site. You can upload it to GitHub Pages, itch.io or
any web host, or wrap it as an Android/iOS app with
[Capacitor](https://capacitorjs.com).

## How to play

Enemies enter on the left and try to leave on the right. Build towers on the
grass to stop them. You lose lives for every enemy that gets through. Survive all 10 waves to win.

| Input | Action |
| --- | --- |
| Click a tower in the sidebar, then the grass | Build |
| `Q` / `W` | Select Missile / Gun tower |
| `S` | Sell tool (50% refund) |
| `Space` | Start the next wave |
| `Esc` / right click | Cancel the tool, or pause |
| `F` | Speed 1x / 2x / 3x |
| `1` `2` `3` | Debug: spawn a single enemy |

## Project layout

```
src/
  config.ts          all balance numbers, waves and maps (start here to tweak)
  sim/               the game rules, plain TypeScript with no Phaser
    world.ts         one level: money, lives, waves, building, the update tick
    map.ts           ASCII map parsing and pathfinding
    enemy.ts  tower.ts  bullet.ts
    fixedStep.ts     fixed-timestep loop helper
  view/FieldView.ts  draws a World with Phaser (sprites, particles, effects)
  ui/                sidebar HUD, buttons, dialogs, colours
  scenes/            Boot (loading), Menu, Game
  main.ts            Phaser game config
public/assets/       sprites
tests/               Vitest tests for the simulation
```

The **simulation** (`src/sim`) and the **view** are kept apart. The simulation
runs at a fixed 60 ticks per second, whatever the monitor's refresh rate. The
view reads its state every frame and interpolates between ticks, so movement
stays smooth on 60, 120 or 144 Hz screens. Because of this split, the whole
game can be tested headlessly. For example, one test has a bot play all 10
waves.

## Adding content

- **New tower:** add an entry to `TOWERS` in `config.ts` and a sprite folder
  with frames `0.png`–`6.png` (pointing up) in `public/assets/towers/`.
- **New enemy:** add an entry to `ENEMIES` and a `0.png` (facing right) in
  `public/assets/enemies/`.
- **New map:** add a 20×15 ASCII grid to `MAPS`. Use `#` for path, `.` for
  grass, and `S`/`E` for entry and exit tiles on the border.
- **Waves:** edit `WAVES`. Each group is `(type, count, interval, delay)`.
