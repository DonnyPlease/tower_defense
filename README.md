# Tower Defense

A tower defense game made with [Godot 4](https://godotengine.org) in statically
typed GDScript. It plays with mouse or touch, scales to any screen, and exports
to desktop, the web and mobile.

## Running it

You need **Godot 4.4 or newer** (the standard build; the .NET build isn't needed).

- **Editor:** open Godot, choose *Import*, pick `project.godot`, then press
  <kbd>F5</kbd> to play.
- **Command line:** `godot --path .` from this folder.

To ship the game, use *Project → Export* in the editor (install the export
templates when it asks). Web, Windows, Linux, macOS and Android all work; the
project uses the Compatibility renderer, which is what web builds need.

## The game

**4 levels + endless mode**

| Level | What's special |
| --- | --- |
| Meadow | The tutorial: 8 waves, ends with the first boss. A wide road: walls reshape it |
| Riverside | Two entrances, a river you can't build on, and flying drones |
| Highlands | A long road with wide stretches, rocks, and high ground (+25% tower range) |
| Open Field | No road: enemies walk around your towers, so you build the maze |
| Endless | Waves never stop, with a boss every 10 waves. Beat your best score |

**6 towers, each with 3 upgrade levels**

| Tower | Role | In the tech tree |
| --- | --- | --- |
| Gun | Rapid fire, aims ahead of moving targets, hits air | owned from the start |
| Missile | Cheap homing missiles, hits air | owned from the start |
| Cannon | Splash damage, strong against armor, ground only | ★ 1, after the Missile, 1 star earned |
| Frost | Slows everything in range and chills with pulses | ★ 2, after the Cannon, 3 stars earned |
| Laser | Beam that heats up to 3x on one target, ignores armor | ★ 2, after Frost, 5 stars earned |
| Beacon | Boosts the fire rate of nearby towers | ★ 3, after the Laser, 7 stars earned |

Click a placed tower to upgrade it, sell it (50% of everything you spent), or
choose what it shoots at: **First**, **Last**, **Strongest** or **Closest**.

**Branches.** At level 3 a tower stops upgrading in a line: it grows into one of
two different towers, each with two more levels (levels 4 and 5). The choice is
for good (selling and rebuilding is the only way back), so every army ends up
different. Hover a branch button in the sidebar to read what it does.

| Tower | Branch A | Branch B |
| --- | --- | --- |
| Gun | **Minigun**: spins up to a hail of bullets, short range | **Sniper**: long-range rail shots through a line of enemies |
| Missile | **Swarm**: a volley of small missiles at several enemies | **Seeker**: one huge missile, extra damage to bosses |
| Cannon | **Mortar**: long range, huge splash, slow shells, minimum range | **Siege**: armor-piercing, heavy single-target damage |
| Frost | **Blizzard**: a huge slowing field, no damage | **Cryo**: pulses freeze enemies; chilled enemies take extra damage |
| Laser | **Prism**: splits the beam over 2-3 enemies | **Lance**: heats up faster and up to 5x |
| Beacon | **Overclock**: a big fire-rate boost close by | **Command**: a smaller boost over a wide area, plus range |

Branch numbers live with the towers in `src/data/towers.gd`. Levels 1-3 are
unchanged, so the balance measurements (made without branches, see
[Balancing](#balancing)) still describe the base game.

**Walls and abilities.** The bar along the bottom of the field holds the wall
tool and seven abilities. Each costs money (and most have a cooldown), so using
them is a decision. Everything about them (prices, cooldowns, strength, and an
on/off switch for each) is in `src/data/abilities.gd`.

| Key | Ability | What it does |
| --- | --- | --- |
| `Q` | Wall | A block enemies must walk around, if there is room. It is refused if it would block the path completely. A tower built on it gets +25% range. The price rises with every wall standing, and selling refunds what it cost |
| `W` | Time slow | Every enemy moves at half speed for 6 s |
| `E` | Damage boost | Towers deal +50% damage for 8 s |
| `R` | Airstrike | Click a spot: a blast lands a second later and hurts everything around it |
| `Z` | Landmine | Place on ground enemies walk on; the first one to come near sets it off (3 at a time) |
| `X` | Bounty | Kills pay double for 15 s |
| `C` | Focus mark | Click an enemy: it takes double damage from all towers for 6 s |
| `V` | Second wind | Restores 3 lives, once per game |

On levels where the road is wide (Meadow, Highlands, endless), walls can be built
on the road itself, and enemies find a new way around them, so a few well-placed
walls make the way longer and give your towers more time. A tower on the road
needs a wall under it first. Enemies and the path never get trapped: a wall
that would close the last gap is refused. In Open Field walls are a cheap way
to shape the maze.

**10 enemy types:** Scout, Racer, Tank, Armored (flat damage reduction),
Shielded (recharging shield), Splitter (breaks into 3 minis), Medic (heals
others), Drone (flies straight over everything), the Juggernaut mini-boss and
the Warlord boss (armored, summons reinforcements).

**Economy.** You get a bonus for every wave you clear, plus 5% interest on
unspent money. Call the next wave early for extra cash. The sidebar shows what
the next wave contains.

**Progression: the tech tree.** Earn 1–3 stars per level: 3 for losing no
lives, 2 for keeping at least half. Spend them in the **tech tree** (main menu,
level select, or the victory dialog): towers, every tower branch, perks
(starting money, lives, cheaper towers, damage; one node per rank) and starting
bonuses (*Masonry*: the first 3 walls of every game are free; *Veterans*: the
first tower you build starts at level 2). A node needs its parents first and a
number of stars earned in total, so you choose the order but can't skip the
early game. Every star can be refunded. The game screen only shows the towers
you own (a **?** slot hints at the rest); locked content lives in the tree.
The tree's nodes, prices and layout are in `src/data/tech.gd`. Progress and a game in progress are saved
automatically (in Godot's `user://` folder; the browser's storage in web
builds), and **Continue** on the main menu resumes where you left off (at the
start of the wave).

**Sound.** All sound effects and the music are synthesised when the game
starts (on a background thread), so there are no audio files. You can toggle
them in the menu or the sidebar.

## Controls

| Input | Action |
| --- | --- |
| Click a tower in the sidebar, then the grass | Build |
| Click a placed tower or wall | Select it (upgrade / target / sell) |
| `1`–`6` | Pick a tower to build |
| `Q` `W` `E` `R` `Z` `X` `C` `V` | Wall and abilities (see above) |
| `U` / `S` / `T` | Upgrade / sell / change target of the selected tower |
| `Space` | Start the next wave (or call it early) |
| `Esc` / right click | Cancel, or pause |
| `F` | Speed 1x / 2x / 3x |
| `M` | Music on/off |

## Testing

Set `GODOT` if the Godot binary isn't on your `PATH` as `godot`:

```bash
tests/run.sh                        # unit, scene, phone and boot tests (about 4 min)
tests/run.sh balance                # balance tests (several minutes)
tests/run.sh web                    # the exported web build in a browser (about 4 min)
tests/run.sh unit --filter=maze     # only tests whose name contains "maze"
tests/run.sh smoke --filter=wave,maze
```

- **Unit tests** (`tests/unit/`) cover the simulation (including every wall
  rule and every ability), the game data, the saved profile, the synthesiser and
  audio engine, and the UI formatting helpers. `test_scripts.gd` loads every script in the project, so a type error
  anywhere fails the run.
- **Determinism tests** (`test_determinism.gd`) check that the random numbers
  and endless waves are exactly those of the original JavaScript version of
  the game.
- **Scene tests** (`tests/smoke/`) start the real screens and click and type
  like a player, then check what the player sees: the sidebar's money, lives
  and wave, the context panel, button labels, banners, dialog texts, floating
  texts and hints. They cover the menus and their navigation (buttons, Esc,
  Enter), sound buttons, building, upgrading, selling, refused builds and the
  maze rule, walls (on grass and on the road, selling them, towers on them),
  every ability (button, hotkey, aiming, cooldowns, messages), waves, calling a
  wave early, pausing (button, keys, focus loss), game speed, saving and
  continuing (walls and mines too), winning, losing and endless mode, perks and
  refunds, and every map with a busy wave. `test_pixels.gd` checks pixels
  of real frames (terrain, sidebar, health bars, the build preview, dimmed
  dialogs, walls, mines, the ability bar and effects), so the drawing code is
  tested too.
- **Playthroughs** (`test_playthrough.gd`) play whole games from the title
  screen with nothing but clicks and keys, spending only the money the game
  gives (they read the sidebar to decide what to do and never touch the game's
  state): Meadow is won, with its stars, unlocks and saved result checked, and
  a game without towers is lost.
- **Phone tests** (`tests/phone/`) run in an 844 x 390 window (a phone held
  sideways): the game is scaled and letterboxed, taps land where the finger
  does, and taps on the black bars do nothing.
- **Boot test** (`tests/boot/`) starts the project like a player does, with
  its real main scene and no test runner, records the first 90 frames and
  checks the title screen is drawn, its demo game is moving, nothing was logged
  as an error, and the game quits cleanly.
- **Web tests** (`tests/web/`, Playwright) export the game for the web and play
  it in Chromium: it loads without console errors, a level is played (build a
  tower, start a wave), a saved game and the music setting survive reloading
  the page (browser storage), the window can be resized, and on a phone-sized
  window it is letterboxed and played by touch. They only look at the pixels
  of the page and use real mouse clicks and finger taps. The first run installs
  the Web export templates (it downloads a 1.2 GB archive, keeps 18 MB of it)
  and needs `npx playwright install chromium` in `tests/web/`. The tests run
  on a debug export, since release builds don't print script errors; the main
  flows also run on the release export that players get.
- **Balance tests** (`tests/balance/`) guard the difficulty curve (see below).

Unit and balance tests run headless. Headless Godot draws nothing and ignores
the window size, so the scene, phone and boot tests run in a virtual display:
`tests/run.sh` uses `xvfb-run` when it is installed (`apt install xvfb
libgl1-mesa-dri`), otherwise your `$DISPLAY`. Without either, the scene and
phone tests run headless and skip the checks that need real frames.

GDScript has no exceptions: a runtime error only ends the function it happens
in and prints a `SCRIPT ERROR`. So the runner reads the engine's log after
every test, and any script or engine error fails that test (with the error and
where it happened).

`tools/screenshots.tscn` renders every screen to PNG files (it needs a
display, e.g. `xvfb-run`):

```bash
godot --path . res://tools/screenshots.tscn -- /tmp/screenshots
```

**CI:** `.github/workflows/ci.yml` runs on every pull request and push to
`main`: the unit, scene, phone and boot tests (with a virtual display), the web
build in a browser, the balance tests (split over five parallel jobs), and a
job that renders every screen and uploads the screenshots.

## Typed GDScript

Every variable, parameter and return value has a static type, and the project
settings turn Godot's typing warnings into errors (`untyped_declaration`,
`unsafe_property_access`, `unsafe_method_access`, `unsafe_call_argument`,
`integer_division`, `narrowing_conversion`). Data from JSON is converted with
explicit checks (`src/util/json_read.gd`).

## Balancing

`balance/` contains simulated players:

- **Expert:** a strategy with tunable preferences (tower mix, upgrade
  eagerness, maze building, calling waves early). `search_expert` tries many
  settings and keeps the best, which approximates optimal play.
- **Human-like players** with a skill from 0 (novice) to 1 (good). They place
  towers imperfectly, pick tower types semi-randomly and don't always spend well.
  Each is played with many fixed seeds to get a win rate.

Each level is played with the towers a typical player has unlocked by then.

```bash
godot --headless -s res://balance/report.gd              # expert result + win rates per level
godot --headless -s res://balance/report.gd -- --quick   # fewer games, rougher numbers
godot --headless -s res://balance/tune.gd                # each level's hp_scale for its target win rate
```

Current targets (in `balance/tune.gd`): Meadow is won by about 75% of
novices; Riverside, Highlands and Open Field by about 75%, 70% and 60% of
average players; the best strategy found keeps all lives on every level. Each
level's `hp_scale` in `src/data/levels.gd` is the main difficulty knob.

The simulated players don't build walls or use abilities, so these numbers are
the difficulty *without* them: a human who uses them well has an easier game.

## Project layout

```
project.godot        engine settings (1000 x 600 logical size, strict typing)
scenes/              the four screens: menu, level select, tech tree, game
src/
  config.gd          global constants (sizes, tick rate, economy formulas)
  data/              game content, which is the place to tweak and add things
    towers.gd        tower stats per level, and their branches
    tech.gd          the tech tree: nodes, prices, requirements, layout
    enemies.gd       enemy stats and abilities
    levels.gd        maps, waves, endless wave generator
    perks.gd         permanent upgrades (ranks bought in the tech tree)
    abilities.gd     the wall and the seven abilities: prices, cooldowns, strength, on/off
  sim/               the game rules; no nodes, no rendering
    world.gd         one game: money, lives, waves, building, the update tick
    game_map.gd      map parsing, terrain, pathfinding, distance fields
    route.gd         smooth curved routes along the middle of the road, with lane widths
    route_nav.gd     how enemies walk roads: lanes and weaving (and how flyers fly)
    flow_nav.gd      how enemies walk mazes and wall levels: vehicle-like steering
    enemy.gd  tower.gd  bullet.gd  aim.gd
    fixed_step.gd    fixed-timestep loop helper
    math_x.gd  mulberry32.gd   JavaScript-exact maths and random numbers
  game/              saved profile, screen switching (the Router autoload)
  audio/             synthesiser, sound recipes, the Audio autoload
  view/              draws a World: vector art for towers and enemies, effects
  ui/                sidebar, buttons, dialogs, colours, fonts
  scenes/            the scripts of the screens
assets/              enemy sprites; symbol fonts (Noto, SIL Open Font License)
balance/             simulated players, balance report and tuner
tests/               test runner, unit, scene and balance tests
tools/               screenshot renderer
```

**Enemy movement.** On Riverside, roads are turned into smooth curves that keep
to the middle of the road. Every enemy picks its own lane and weaves a little,
so a wave spreads over wide roads and swings through corners instead of
marching in single file. Where walls can be built (Meadow, Highlands, endless,
and Open Field), enemies instead follow a distance field that is recomputed
whenever a tower or wall is built or sold, and steer like vehicles: they start
turning before a corner, turn at a limited rate and slow down for sharp turns.
Flyers always fly straight.

The **simulation** (`src/sim`) and the **view** are kept apart. The simulation
runs at a fixed 60 ticks per second, whatever the monitor's refresh rate. The
view reads its state every frame and interpolates between ticks, so movement
stays smooth on 60, 120 or 144 Hz screens. Because of this split, the
simulation is tested headlessly, and the balance tests play thousands of games.

## Adding content

- **New tower:** add it to `_build()` in `src/data/towers.gd` and to `KINDS`,
  and give it art. Either draw it in code (see `src/view/tower_art.gd`), or put
  PNG frames (pointing up) in `assets/towers/<folder>/0.png`, `1.png`, … and
  set the tower's `sprite` to the folder name.
- **New enemy:** add it to `src/data/enemies.gd` and `TYPES`, and give it art
  (facing right) in `src/view/enemy_art.gd`. Abilities (`armor`, `shield`,
  `flying`, `split`, `heal`, `summon`) are just fields.
- **New level:** add a 20×15 map to `src/data/levels.gd`. `LevelDef` documents
  the tile letters (road, grass, high ground, rock, water, bridge, entry and
  exit). Set `maze` to let enemies walk on grass.
- Run `tests/run.sh` and `tests/run.sh balance` afterwards. The balance tests
  tell you if the level is still winnable.

**Debugging:** while the game runs from the editor, the *Remote* scene tree
shows the live nodes and lets you inspect and change their properties. The
simulation is plain GDScript objects, so the quickest way to try things is a
line in `GameScene._ready()`, e.g. `world.money = 10000` or
`world.spawn("boss")`.
