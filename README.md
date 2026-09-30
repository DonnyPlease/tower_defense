# Tower Defense

A browser tower defense game built with [Phaser 4](https://phaser.io) and TypeScript.
It runs in any modern browser, works with mouse or touch, and scales to any screen.

## Running it

You need [Node.js](https://nodejs.org) 20 or newer.

```bash
npm install
npm run dev        # dev server with hot reload at http://localhost:5173
npm run build      # type-check and build a static site into dist/
npm run preview    # serve the built dist/ folder
```

`dist/` is a plain static site. You can upload it to GitHub Pages, itch.io or
any web host, or wrap it as an Android/iOS app with
[Capacitor](https://capacitorjs.com).

## The game

**4 levels + endless mode**

| Level | What's special |
| --- | --- |
| Meadow | The tutorial: 8 waves, ends with the first boss |
| Riverside | Two entrances, a river you can't build on, and flying drones |
| Highlands | A long road, rocks, and high ground (+25% tower range) |
| Open Field | No road: enemies walk around your towers, so you build the maze |
| Endless | Waves never stop, with a boss every 10 waves. Beat your best score |

**6 towers, each with 3 upgrade levels**

| Tower | Role | Unlock |
| --- | --- | --- |
| Gun | Rapid fire, aims ahead of moving targets, hits air | start |
| Missile | Cheap homing missiles, hits air | start |
| Cannon | Splash damage, strong against armor, ground only | ★ 1 |
| Frost | Slows everything in range and chills with pulses | ★ 3 |
| Laser | Beam that heats up to 3x on one target, ignores armor | ★ 5 |
| Beacon | Boosts the fire rate of nearby towers | ★ 7 |

Click a placed tower to upgrade it, sell it (50% of everything you spent), or
choose what it shoots at: **First**, **Last**, **Strongest** or **Closest**.

**10 enemy types:** Scout, Racer, Tank, Armored (flat damage reduction),
Shielded (recharging shield), Splitter (breaks into 3 minis), Medic (heals
others), Drone (flies straight over everything), and the Warlord boss
(armored, summons reinforcements).

**Economy.** You get a bonus for every wave you clear, plus 5% interest on
unspent money. Call the next wave early for extra cash. The sidebar shows what
the next wave contains.

**Progression.** Earn 1–3 stars per level: 3 for losing no lives, 2 for keeping
at least half. Stars unlock towers and buy permanent upgrades (starting money,
lives, cheaper towers, damage). Progress and a game in progress are saved in
the browser automatically, and **Continue** on the main menu resumes where you
left off (at the start of the wave).

**Sound.** All sound effects and the music are synthesised with the Web Audio
API, so there are no audio files. You can toggle them in the menu or the sidebar.

## Testing

```bash
npm test               # unit + balance tests (Vitest, a few seconds)
npm run test:coverage  # the same, with a coverage report in coverage/index.html
npm run build && npm run test:e2e   # browser smoke tests (Playwright)
```

- **Unit tests** (`tests/`) cover everything that runs without a browser:
  the simulation, game data, saved profile, audio engine (against a fake
  Web Audio API) and UI formatting helpers. Coverage must stay at least 97%
  of lines and 92% of branches, or the run fails.
- **Balance tests** (`tests/balance.test.ts`) guard the difficulty curve (see below).
- **Browser smoke tests** (`e2e/`) start the built game in Chromium and click
  through it: menus, building, upgrading, selling, waves, saving and
  continuing, winning, every map with a busy wave, and touch controls on a
  phone-sized screen. They fail on any JavaScript error. The first time, run
  `npx playwright install chromium` to download the browser.

**CI:** `.github/workflows/ci.yml` runs on every pull request and push to
`main`. Two jobs run in parallel: *Type-check, unit tests, build* (with a
coverage table in the job summary) and *Browser smoke tests* (uploads the
Playwright report if something fails).

## Balancing

`balance/` contains simulated players:

- **Expert:** a strategy with tunable preferences (tower mix, upgrade
  eagerness, maze building, calling waves early). `searchExpert` tries many
  settings and keeps the best, which approximates optimal play.
- **Human-like players** with a skill from 0 (novice) to 1 (good). They place
  towers imperfectly, pick tower types semi-randomly and don't always spend well.
  Each is played with many fixed seeds to get a win rate.

Each level is played with the towers a typical player has unlocked by then.

```bash
npm run balance          # report: expert result + novice/average/good win rates per level
npm run balance:tune     # finds each level's hpScale for its target win rate
```

Current targets (in `balance/tune.ts`): Meadow is won by about 75% of
novices; Riverside, Highlands and Open Field by about 75%, 70% and 60% of
average players; the best strategy found keeps all lives on every level. Each
level's `hpScale` in `src/data/levels.ts` is the main difficulty knob.

## Controls

| Input | Action |
| --- | --- |
| Click a tower in the sidebar, then the grass | Build |
| Click a placed tower | Select it (upgrade / target / sell) |
| `1`–`6` | Pick a tower to build |
| `U` / `S` / `T` | Upgrade / sell / change target of the selected tower |
| `Space` | Start the next wave (or call it early) |
| `Esc` / right click | Cancel, or pause |
| `F` | Speed 1x / 2x / 3x |
| `M` | Music on/off |

## Project layout

```
src/
  config.ts          global constants (sizes, tick rate, economy formulas)
  data/              game content, which is the place to tweak and add things
    towers.ts        tower stats per level
    enemies.ts       enemy stats and abilities
    levels.ts        maps, waves, endless wave generator
    perks.ts         permanent upgrades bought with stars
  sim/               the game rules, plain TypeScript with no Phaser
    world.ts         one game: money, lives, waves, building, the update tick
    map.ts           map parsing, terrain, pathfinding, distance fields
    route.ts         smooth curved routes along the middle of the road, with lane widths
    nav.ts           how enemies move: lanes and weaving on roads, steering in mazes
    enemy.ts  tower.ts  bullet.ts
    fixedStep.ts     fixed-timestep loop helper
  game/profile.ts    saved progress: stars, perks, settings, saved game
  audio/audio.ts     procedural sound effects and music
  view/FieldView.ts  draws a World with Phaser (sprites, particles, effects)
  view/towerArt.ts   procedural art for the Gun and Missile towers
  ui/                sidebar HUD, buttons, dialogs, colours, minimaps
  scenes/            Boot, Menu, LevelSelect, Upgrades, Game
public/assets/       enemy sprite files (everything else is drawn in code)
tests/               Vitest tests, including a bot that must beat every level
```

**Enemy movement.** Roads are turned into smooth curves that keep to the
middle of the road. Every enemy picks its own lane and weaves a little, so a
wave spreads over wide roads and swings through corners instead of marching in
single file. In Open Field, enemies steer like vehicles: they start turning
before a corner, turn at a limited rate and slow down for sharp turns.

The **simulation** (`src/sim`) and the **view** are kept apart. The simulation
runs at a fixed 60 ticks per second, whatever the monitor's refresh rate. The
view reads its state every frame and interpolates between ticks, so movement
stays smooth on 60, 120 or 144 Hz screens. Because of this split, the whole
game is tested headlessly: `tests/balance.test.ts` has a simple greedy bot play
every level and fails if one becomes unbeatable.

## Adding content

- **New tower:** add an entry to `TOWERS` in `src/data/towers.ts` and give it
  art. Either draw it in code (see `src/view/towerArt.ts`: a still `<kind>-base`
  plate plus rotating turret frames `<kind>-0`, `<kind>-1`, …), or put PNG
  frames (pointing up) in `public/assets/towers/<folder>/` and set `sprite`.
- **New enemy:** add an entry to `ENEMIES` in `src/data/enemies.ts` and a
  texture (facing right). Abilities (`armor`, `shield`, `flying`, `split`,
  `heal`, `summon`) are just fields.
- **New level:** add a 20×15 map to `LEVELS` in `src/data/levels.ts`. The file
  documents the tile letters (road, grass, high ground, rock, water, bridge,
  entry and exit). Set `maze: true` to let enemies walk on grass.
- Run `npm test` afterwards. The balance test tells you if the level is still winnable.

Debug from the browser console: `game.scene.getScene('game').world.spawn('boss')`.
