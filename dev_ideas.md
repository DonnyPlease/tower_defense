# Development ideas

A scratchpad for where the game could go next. Nothing here is promised or
scheduled; it's a list to pick from. Move an idea to **Decided** (or delete it)
as you make up your mind. Ideas that have been built are gone from this list
(see the README for what the game has).

**Guiding principle:** this game is first of all for its maker. It has to be
extremely interesting and nice to play for *me* before anything else (price,
stores, marketing). When two ideas compete, build the one that makes the game
more fun to play for hours.

## Where we are

5 levels + endless, each level also playable as 4 variants (night, reversed,
last stand, no gun); 7 towers that grow into one of two branches after level 3;
14 enemy types (including the saboteur, hopper, warchief and the phased
Colossus); walls and 7 abilities; a tech tree for stars; field orders (run
perks) during a game; a first-game tutorial. Enemies re-route around walls on
every level but Riverside, and the Magnet bends their way. It works with mouse
and touch (tap-to-build, hold for help) and the Web export is an installable
PWA (no Android or iOS preset yet).

What it still lacks:

- Visuals are drawn in code and look like a prototype.
- The in-game screen is crowded (a 2 x 4 tower grid, the selected-tower panel,
  the ability bar).
- Riverside is the last "fixed road" level.

---

## 1. Visual design

The art is drawn in code (`src/view/tower_art.gd`, `enemy_art.gd`, `burst.gd`,
`screen_fx.gd`) and is not the strong suit. Options, from least to most work:

1. **Better procedural art.** Keep the code-drawn style but pick one strong
   look: a small palette, outlines, soft shadows. (Shots and beams already
   glow, with an additive layer; night levels use a shader.)
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

- A sound of its own for every branch (the Minigun, Swarm, Seeker, Siege and
  Tesla share their base tower's sound; the Laser family has none).
- Real title art (a logo) once the visual direction is decided.

---

## 2. Layout, UI and portability

Current layout: 1000 x 600 logical size (`src/config.gd`): an 800 x 600 field
(20 x 15 tiles of 40 px) plus a 200 px sidebar. The sidebar holds a 2 x 4
tower grid, the selected-tower panel, the next-wave preview, Start wave and
pause/speed/music/sound buttons. Tap-to-build (a menu on an empty tile),
holding a button for its help, and the Android back button (pause) exist.

Problems:

- The sidebar is crowded, and more so with branches and a seventh tower.
- On a phone held sideways (e.g. 844 x 390) everything is scaled to about 65%,
  so 30-38 px buttons become small to tap, and the field and sidebar compete
  for a small screen.
- The safe area (notches and rounded corners) isn't handled. Needs a phone
  with a notch to test; today the letterbox bars of a wide phone happen to
  cover the notch.

Ideas:

- **Expanding / collapsing menus** instead of a fixed sidebar. For example a
  slim tower bar (tap-to-build already makes it optional), and a context card
  for the selected tower that appears only when something is selected.
- **A slim top bar** for money, lives and wave, with Start wave as a floating
  button and pause/speed in a corner.
- **Let the field use the full screen** and overlay the UI on it, instead of
  keeping a fixed sidebar. This needs a different stretch mode (such as
  `expand`) or a layout that adapts to the aspect ratio, rather than letterboxing.
- **Safe-area handling** (`DisplayServer.get_display_safe_area()`).
- **Bigger tap targets** (aim for about 9-10 mm / 44-48 dp on a phone).
- **Portrait mode?** Probably not: a wide field plays better sideways. Decide
  once and test.

Decisions needed before building: one layout for desktop and phone, or two?
(One adaptive layout is more work up front and much less to maintain.)

---

## 3. More content

- An **ever-narrower road** variant (the road shrinks wave by wave).
- More levels, so the tech tree has more to give (each level adds 3 stars, and
  3 more per variant).
- A road for Riverside that walls can reshape too, or keep it as the one
  classic level.

---

## 4. Shipping / platforms

- **Web** is ready (preset, tests, installable PWA). Host it on HTTPS (GitHub
  Pages, itch.io, Netlify) so it can be installed from the browser, including
  on iPhones.
- **Android:** add an Android export preset (JDK, Android SDK, keystore). `.apk`
  to sideload, `.aab` for Google Play. Works from any OS.
- **iOS:** needs a Mac with Xcode, and a paid Apple Developer account for
  TestFlight / the App Store. Without a Mac, use the web build on iOS, or
  rent a cloud Mac / use a CI macOS runner.
- **Selling it:** not a goal for now. If it ever is: expect little without polish
  and a good store page. Try itch.io first (free to list, pay-what-you-want),
  and consider a free first levels + $1 unlock.

---

## 5. Suggested order (if we want one)

1. Decide the visual direction (cheap to decide, affects everything else).
2. UI rework: slimmer HUD, one layout for desktop and phone.
3. More levels and variants to fill the tree.
4. Android preset, safe area, tap sizes.

## 6. Open questions

- What is the *one thing* that makes this game special: pathing, branching
  armies, or something else? (Play each level and note when it felt boring and
  when it felt exciting.)
- One layout for all screens, or separate desktop and phone layouts?
- Which visual direction?
- How many levels is "enough" for the tech tree to feel worth it?
- Which of the walls, abilities, branches, field orders and new enemies to keep
  (and which to tune or drop) after playing them.
