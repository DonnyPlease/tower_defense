# Development ideas

A scratchpad for where the game could go next. Nothing here is promised or
scheduled; it's a list to pick from. Move an idea to **Decided** (or delete it)
as you make up your mind.

**Guiding principle:** this game is first of all for its maker. It has to be
extremely interesting and nice to play for *me* before anything else (price,
stores, marketing). When two ideas compete, build the one that makes the game
more fun to play for hours.

## Where we are

The game is a complete, well-tested, classic tower defense: 4 levels + endless,
6 towers with 3 linear upgrade levels, 10 enemy types, stars that unlock towers
and buy flat stat perks. It works with mouse and touch and has a Web export
preset (no Android or iOS preset yet).

What it lacks is **one thing that makes it special**. Today:

- The most distinctive mechanic is **Open Field** (no road, enemies path around
  your towers, you build the maze). It's one level of four.
- Perks are flat stat bumps (+money, +lives, cheaper, +8% damage). They don't
  change how you play.
- Tower upgrades are linear, so every Gun ends up as the same Gun.
- Three of the four levels are "enemies follow a fixed road", where the only
  decision is where to put towers beside it.
- Visuals are drawn in code and look like a prototype.
- The in-game screen is getting crowded.

---

## 1. Tower branching (favourite idea)

Each tower follows a normal upgrade path, then **branches into two different
towers** at a fork. Every run can end up with a different army, and it gives
the player a real decision about what to build, not just how much to spend.

**Rule of thumb:** base level 1 and 2 as today, then at level 3 choose branch A
or B. Each branch then has its own further levels. Selling and rebuilding is the
only way to change a branch (so the choice matters).

Candidate branches (names and numbers are placeholders, to be balanced):

| Tower | Branch A | Branch B |
| --- | --- | --- |
| Gun | **Minigun**: very fast, short range, spins up | **Sniper**: long range, slow, high damage, pierces |
| Missile | **Swarm**: many small missiles, good vs. groups | **Seeker**: one huge homing missile, good vs. bosses |
| Cannon | **Mortar** (favourite): long range, arcing shell, big splash, minimum range, slow shell so it misses fast targets | **Siege cannon**: armour-piercing, shorter range, high single-target damage |
| Frost | **Blizzard**: huge slow aura, no damage | **Cryo**: slowed enemies take bonus damage, short freeze on a pulse |
| Laser | **Prism**: splits the beam over 2-3 targets | **Lance**: heats up faster and to a higher multiplier on one target |
| Beacon | **Overclock**: bigger fire-rate boost, small radius | **Command**: boosts range as well, big radius, smaller boost |

Mortar notes:

- Needs an arcing shell with a flight time and a **minimum range**. That pairs
  well with Open Field mazes: a mortar behind the walls hitting enemies bunched
  in a long corridor.
- It should be bad against fast enemies (Racer, Scout) and good against Tank,
  Armored and anything slowed by Frost. That gives Frost + Mortar a natural
  combo.

Implementation notes:

- Tower data lives in `src/data/towers.gd` and `tower_level.gd`. Branching
  means the upgrade path becomes a small tree instead of an array.
- The save file (`src/game/profile.gd`) and the "game in progress" save will need
  to store the chosen branch. Version the save format.
- Balance tests (`tests/balance/`) and the determinism tests that compare
  against the original JavaScript version will need updating: branches are new
  content, so keep the old three levels as the base case.
- The HUD's context panel (`src/ui/hud.gd`) needs a "choose a branch" state.

---

## 2. Tech tree

The star system already unlocks towers and buys perks. Grow it into a **tech
tree** that is the long-term progression of the game: a screen where you see
what you have, what's next and what it costs.

- **Nodes** unlock: new towers, **tower branches** (section 1), perks, new
  levels or map variants, and starting bonuses.
- **Currency:** keep stars (earned per level, 1-3 each) or add a separate
  research currency earned per run. Stars are simple and already work.
- **Gating:** nodes can need a parent node *and* a number of stars, so you
  choose the order but can't skip the early game.
- **The tree is where locked content lives.** The game screen shows only what
  you own (see section 7); the tech tree shows the whole picture, including the
  things you haven't got yet.
- More levels, or **several levels on the same map**, make the tree satisfying:
  a short sense of progress after every run. Examples of same-map variants:
  night (short sight range), reversed route, fewer lives, a "no Gun" challenge,
  an ever-narrower road.
- Save data: unlocked node ids, so adding a node never breaks an old save.

Open questions:

- Is the tree one big graph or one branch per tower?
- Can you *refund* a node (respec), or is each choice permanent?

---

## 3. Make pathing the identity

Open Field is the best idea in the game, so use it everywhere.

- Add **build-able gaps** in the roads of the other levels so you can lengthen
  or reroute them. Enemies recalculate their route (`src/sim/flow_field.gd`
  already does this for Open Field).
- Keep the rule that you can't fully block the exit ("That would block the
  path", already in `game_scene.gd`).
- Towers and objects that **interact with the path**, not just the enemies:
  - A wall/gate: costs money but makes enemies detour.
  - A tower that pulls enemies toward it.
  - A tower that is strong only when enemies walk a long straight line past it.
- Level design: each level becomes its own puzzle, not just "where do I put
  towers beside the road".

---

## 4. Run-defining perks

Replace some flat perks (`src/data/perks.gd`: War Chest, Fortify, Engineering,
Firepower) with **choices that change how you play**.

- Before or during a run, pick 2-3 perks from a few offered. Different every
  run, which gives endless mode a reason to be replayed.
- Examples: Gun bullets pierce; Frost also weakens shields; Beacon also boosts
  range; interest rate doubled but lives halved; towers cost less on high
  ground; the first tower of each kind is free.
- The flat perks can stay in the tech tree as cheap early nodes.

---

## 5. More enemy variety

Enemies are mostly stat variants today. The ones that force you to change your
build (Splitter, Medic, Shielded) are the best ones. More like those:

- An enemy that **destroys or disables** a tower for a while.
- An enemy that **jumps or digs** past walls, so pure mazes aren't enough.
- An enemy that **buffs** others nearby, so you must kill it first.
- Bosses that have phases.

---

## 6. Visual design

The art is drawn in code (`src/view/tower_art.gd`, `enemy_art.gd`, `burst.gd`,
`screen_fx.gd`) and is not the strong suit. Options, from least to most work:

1. **Better procedural art.** Keep the code-drawn style but pick one strong
   look: a small palette, outlines, soft shadows, a glow on projectiles
   and lasers. Check which 2D glow/light features the Compatibility renderer
   supports in the Godot version in use.
2. **Free asset packs.** Kenney (kenney.nl) has CC0 tower defense and UI
   packs, OpenGameArt and itch.io have more. Check each licence before
   shipping, and check whether credit is required.
3. **Commission or buy a pack** from an artist for a consistent look.
4. **AI-assisted art:** for concept art and rough sprites. Check the licence and
   terms of the tool before shipping anything made with it, and expect to
   clean up the results by hand.

Whatever the source, decide on **one visual direction first** (e.g. clean
vector/flat, pixel art, or dark neon) and make everything match it. Mixed styles
look worse than simple ones. The existing PNGs live in `assets/enemies/`.

Other polish:

- Hit feedback: small screen shake, flashes, particles on kills.
- A satisfying sound for each tower (sound is synthesised in `src/audio/`).
- A clear, short tutorial in Meadow.
- Better menu and level-select screens (title art, level thumbnails).

---

## 7. Layout, UI and portability

Current layout: 1000 x 600 logical size (`src/config.gd`): an 800 x 600 field
(20 x 15 tiles of 40 px) plus a 200 px sidebar. The sidebar holds the tower
buttons, the selected-tower panel, the next-wave preview, Start wave and
pause/speed/music/sound buttons. Perks are bought on a separate screen
(`upgrades_scene.gd`), not in the game.

Problems:

- The sidebar is crowded, and will get more so with branches.
- On a phone held sideways (e.g. 844 x 390) everything is scaled to about 65%,
  so 30-38 px buttons become small to tap, and the field and sidebar compete
  for a small screen.
- The safe area (notches and rounded corners) isn't handled.

Ideas:

- **Hide locked towers** in the game. Show only what you own. Locked and
  upcoming content is shown in the tech tree instead. (Maybe one "?" slot as a
  teaser, to be decided.)
- **Expanding / collapsing menus** instead of a fixed sidebar. For example a
  slim tower bar that opens a build menu, and a context card for the selected
  tower that appears only when something is selected.
- **Tap-to-build on a tile.** Tap an empty tile and a small popup lists only
  the towers you can build there. This is the usual mobile pattern and means
  the tower list doesn't need to be on screen all the time.
- **A slim top bar** for money, lives and wave, with Start wave as a floating
  button and pause/speed in a corner.
- **Let the field use the full screen** and overlay the UI on it, instead of
  keeping a fixed sidebar. This needs a different stretch mode (such as
  `expand`) or a layout that adapts to the aspect ratio, rather than letterboxing.
- **Safe-area handling** (`DisplayServer.get_display_safe_area()`).
- **Bigger tap targets** (aim for about 9-10 mm / 44-48 dp on a phone).
- **Portrait mode?** Probably not: a wide field plays better sideways. Decide
  once and test.
- **Android back button** should pause (`NOTIFICATION_WM_GO_BACK_REQUEST`).
- A **range preview** and tower info shown when you press and hold, since touch
  has no hover (hover is used today in `hud.gd`).

Decisions needed before building: one layout for desktop and phone, or two?
(One adaptive layout is more work up front and much less to maintain.)

---

## 8. Shipping / platforms

- **Web** is ready (preset exists, tests exist). Host on HTTPS (GitHub Pages,
  itch.io, Netlify). Optionally turn on PWA (`progressive_web_app/enabled`) so
  it can be installed from the browser, including on iPhones.
- **Android:** add an Android export preset (JDK, Android SDK, keystore). `.apk`
  to sideload, `.aab` for Google Play. Works from any OS.
- **iOS:** needs a Mac with Xcode, and a paid Apple Developer account for
  TestFlight / the App Store. Without a Mac, use the web build on iOS, or
  rent a cloud Mac / use a CI macOS runner.
- **Selling it:** not a goal for now. If it ever is: expect little without polish
  and a good store page. Try itch.io first (free to list, pay-what-you-want),
  and consider a free first levels + $1 unlock.

---

## 9. Performance (frame rate is poor on the phone)

Reported while playing the web build on a phone: the FPS is low. Nothing has
been measured yet, so the list below is a set of suspects, not findings.
**Measure first, then change things.**

How to measure:

- Note which device and browser, which level, which wave, and which game speed
  (1x / 2x / 3x) it happens at. Does it start low, or get worse as the wave grows?
- In the editor: *Debugger → Monitors* (FPS, draw calls, objects) and *Profiler*.
  A debug build of the web export shows an FPS counter and script errors in the
  browser console.
- Compare the phone with a desktop browser. If the desktop is also slow, the
  problem is in the game; if only the phone is, it is mostly fill rate / draw
  calls / CPU speed.

Suspects (from reading the code, not from a profile):

- **Everything is drawn in code.** The views use `DrawNode` (`src/view/draw_node.gd`)
  with `_draw()` callbacks, and the bullets, beams and health bars layers
  redraw **every frame** (`field_view.gd`, `sync()`). Thousands of small
  `draw_circle` / `draw_polyline` / `draw_arc` calls per frame add up on a
  phone, and a lot of them run in GDScript on a single thread (and in the
  browser, WebAssembly is slower than a native build).
- **Per-tower and per-enemy nodes.** Each tower and enemy is its own node
  with its own draw callbacks. Many of them redrawing every frame is costly.
- **Simulation catch-up.** The fixed-step loop (`fixed_step.gd`) runs up to
  `10 * speed` simulation ticks in one frame. If a frame is slow, the next one
  has more ticks to run, which makes it slower still. At 3x speed this is the
  most likely place for the frame rate to collapse.
- **Pathing:** the flow field and the path preview in the maze level
  (`flow_field.gd`, the key string built every `sync()` in `field_view.gd`) may
  cost a lot with many towers.
- **Transparency and glow:** large translucent areas, range circles and
  screen effects (`screen_fx.gd`, `burst.gd`) cost fill rate on a phone GPU.
- **Resolution:** the viewport is 1000 x 600 and scaled up. On a high-DPI
  phone this may still be heavy for the browser's canvas.
- **Audio:** sound is synthesised on a background thread at start. Without
  threads (the Web preset has them off) it falls back to something else
  (`audio_engine.gd`), which could cause a hitch at start.

Ideas, roughly from cheapest:

1. Redraw only what changed: static things (terrain, tower bases, the path)
   are drawn once and cached, and only moving things redraw.
2. Draw bullets, particles and health bars in **batches**, with
   `MultiMeshInstance2D`, or fewer, larger draw calls instead of many small ones.
3. Pre-render tower and enemy art into **textures** once (or use real sprite
   textures, which also helps the look, see section 6) and draw sprites instead
   of vector shapes every frame.
4. Cap the catch-up: run fewer ticks per frame (a smaller `MAX_TICKS_PER_FRAME`)
   and let the game slow down instead of spiralling. Give 3x speed a lower cap.
5. Only recompute the maze path when a tower is built or sold, not every frame.
6. A **quality setting** (low / high) that turns off glow, particles and the
   screen effects, and a lower internal resolution on phones.
7. Check the web export settings (threads, compression, `vram_texture_compression`)
   and test whether a threaded build is faster. Threads need special server
   headers, which GitHub Pages doesn't set, so this may mean another host.
8. Add a frame-time counter to a debug overlay in the game, so the numbers are
   visible on the phone without any tools.

## 10. Suggested order (if we want one)

1. Measure the frame rate on the phone (section 9) and fix the worst cause,
   so everything after it is tested on a game that runs well.
2. Decide the visual direction (cheap to decide, affects everything else).
3. Tower branching with the Mortar branch of Cannon first, as the first test
   of the idea, then the other branches.
4. UI rework: hide locked towers, tap-to-build popup, slimmer HUD.
5. Tech tree screen (needs branches to be worth having).
6. Pathing in more levels and path-interacting towers.
7. Run-defining perks.
8. More levels / map variants to fill the tree.
9. Android preset, safe area, back button, tap sizes.

## 11. Open questions

- What is the *one thing* that makes this game special: pathing, branching
  armies, or something else? (Play each level and note when it felt boring and
  when it felt exciting.)
- Stars only, or a second currency for the tech tree?
- One layout for all screens, or separate desktop and phone layouts?
- Which visual direction?
- How many levels is "enough" for the tech tree to feel worth it?
