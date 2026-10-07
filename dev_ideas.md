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
  change how you play. (They are now cheap nodes in the tech tree.)
- Three of the four levels are "enemies follow a fixed road", where the only
  decision is where to put towers beside it.
- Visuals are drawn in code and look like a prototype.
- The in-game screen is getting crowded.

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

- The sidebar is crowded, and more so now with branches.
- On a phone held sideways (e.g. 844 x 390) everything is scaled to about 65%,
  so 30-38 px buttons become small to tap, and the field and sidebar compete
  for a small screen.
- The safe area (notches and rounded corners) isn't handled.

Ideas:

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

## 9. Suggested order (if we want one)

1. Decide the visual direction (cheap to decide, affects everything else).
3. UI rework: tap-to-build popup, slimmer HUD.
5. Pathing in more levels and path-interacting towers.
6. Run-defining perks.
7. More levels / map variants to fill the tree.
8. Android preset, safe area, back button, tap sizes.

## 10. Open questions

- What is the *one thing* that makes this game special: pathing, branching
  armies, or something else? (Play each level and note when it felt boring and
  when it felt exciting.)
- One layout for all screens, or separate desktop and phone layouts?
- Which visual direction?
- How many levels is "enough" for the tech tree to feel worth it?
