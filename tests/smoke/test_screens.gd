extends SceneTestCase
## Plays through the real screens like a player (these replace the browser
## smoke tests of the web version). Any script error fails the run (tests/run.sh).

const ALL_STARS: Dictionary[String, int] = {"meadow": 3, "riverside": 3, "highlands": 3}


func tower_names(game: GameScene) -> Array[String]:
	var out: Array[String] = []
	for t: Tower in game.world.towers:
		out.append("%s@%d,%d" % [t.kind, t.col, t.row])
	return out


func open_game(level_id: String) -> GameScene:
	Router.goto_game(level_id)
	if not await wait_for_scene("GameScene"):
		return null
	return scene()


func test_menu_to_level_select_then_build_upgrade_sell_and_play_a_wave() -> void:
	use_profile()
	Router.goto_menu()
	if not await wait_for_scene("MenuScene"):
		return
	var menu: MenuScene = scene()
	await click_button(menu.buttons["play"])
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	await click_button(levels.play_buttons["meadow"])
	if not await wait_for_scene("GameScene"):
		return
	var game: GameScene = scene()

	# Build a missile tower with the sidebar and a click on the grass.
	await click_button(game.hud.tower_buttons["missile"])
	await click_tile(6, 9)
	expect_eq(tower_names(game), ["missile@6,9"])

	# Select it, upgrade it, change its target, then build a second one and sell it.
	await click_tile(6, 9)
	expect_true(game.selected != null and game.selected.kind == "missile", "selected")
	await click_button(game.hud.upgrade_button)
	await click_button(game.hud.target_button)
	if game.selected != null:
		expect_eq(game.selected.level, 1)
		expect_eq(game.selected.target_mode, Towers.TargetMode.LAST)
	await press_key(KEY_2)
	await click_tile(13, 7)
	await click_tile(13, 7)
	await click_button(game.hud.sell_button)
	expect_eq(game.world.towers.size(), 1)

	# Start the wave and let the tower shoot something.
	await click_button(game.hud.wave_button)
	expect_true(await until(func() -> bool: return game.world.kills > 0), "the tower killed something")


func test_pausing_leaving_and_continuing_a_saved_game() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	await click_tile(3, 9)
	await press_key(KEY_ESCAPE) # cancel the build tool
	await press_key(KEY_ESCAPE) # pause
	expect_true(game.paused)
	await click_button(game.pause_overlay.button("Main menu"))
	if not await wait_for_scene("MenuScene"):
		return
	Profile.forget_cache() # as if the game had been restarted
	var p: Profile = Profile.load_profile()
	expect_not_null(p.save)
	if p.save != null:
		expect_eq(p.save.towers.size(), 1)

	Router.goto_menu()
	if not await wait_for_scene("MenuScene"):
		return
	var menu: MenuScene = scene()
	expect_true(menu.buttons.has("continue"), "Continue is offered")
	if not menu.buttons.has("continue"):
		return
	await click_button(menu.buttons["continue"])
	if not await wait_for_scene("GameScene"):
		return
	game = scene()
	expect_eq(tower_names(game), ["gun@3,9"])
	expect_true(game.resumed)


func test_winning_a_level_awards_stars_and_unlocks_towers() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var w: World = game.world
	w.money = 1_000_000
	w.wave_index = w.total_waves() - 2
	for spot: Vector2i in [Vector2i(6, 9), Vector2i(9, 9), Vector2i(13, 8), Vector2i(12, 11), Vector2i(14, 5),
			Vector2i(9, 7), Vector2i(16, 5), Vector2i(17, 8), Vector2i(13, 10), Vector2i(10, 13)]:
		var t: Tower = w.build("missile" if spot.x % 2 == 1 else "gun", spot.x, spot.y)
		if t != null:
			w.upgrade(t)
			w.upgrade(t)
	w.start_next_wave()
	game.speed = 3
	expect_true(await until(func() -> bool: return w.status != World.Status.PLAYING), "the game ended")
	expect_eq(w.status, World.Status.WON)
	expect_true(game.win_overlay.visible, "victory dialog")
	Profile.forget_cache()
	var p: Profile = Profile.load_profile()
	expect_ge(p.stars_on("meadow"), 1)
	expect_null(p.save)


func test_losing_shows_the_defeat_dialog_and_clears_the_save() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.world.lives = 1
	await press_key(KEY_SPACE)
	game.speed = 3
	expect_true(await until(func() -> bool: return game.world.status == World.Status.LOST), "lost")
	expect_true(game.lose_overlay.visible, "defeat dialog")
	Profile.forget_cache()
	expect_null(Profile.load_profile().save)
	await click_button(game.lose_overlay.button("Try again"))
	expect_true(await wait_for_scene("GameScene"))
	var again: GameScene = scene()
	expect_eq(again.world.lives, Levels.by_id("meadow").lives)


func test_every_map_runs_a_busy_wave_without_errors() -> void:
	for level_id: String in ["meadow", "riverside", "highlands", "openfield", "endless"]:
		use_profile(ALL_STARS)
		var game: GameScene = await open_game(level_id)
		if game == null:
			return
		var w: World = game.world
		w.money = 1_000_000
		w.lives = 1_000_000
		var n: int = 0
		for r: int in Config.ROWS:
			for c: int in range(2, 18, 3):
				if n >= 14:
					break
				var t: Tower = w.build(Towers.KINDS[n % Towers.KINDS.size()], c, r)
				if t != null:
					n += 1
					if n % 2 == 1:
						w.upgrade(t)
		for type: String in ["boss", "splitter", "healer", "drone", "shielded", "armored"]:
			w.spawn(type)
		w.start_next_wave()
		game.speed = 3
		await frames(240)
		expect_gt(w.tick, 100, level_id)
		expect_gt(w.towers.size(), 5, level_id)
		expect_gt(w.kills, 0, level_id)


func test_keyboard_shortcuts() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.world.money = 10_000
	await press_key(KEY_2)
	expect_eq(game.tool, "missile")
	await press_key(KEY_2)
	expect_eq(game.tool, "", "the same key again puts the tool away")
	await press_key(KEY_1)
	await click_tile(6, 9)
	await click_tile(6, 9)
	await press_key(KEY_U)
	await press_key(KEY_T)
	expect_eq(game.selected.level, 1)
	expect_eq(game.selected.target_mode, Towers.TargetMode.LAST)
	await press_key(KEY_F)
	expect_eq(game.speed, 2)
	await press_key(KEY_SPACE)
	expect_eq(game.world.wave_index, 0)
	await press_key(KEY_S)
	expect_eq(game.world.towers.size(), 0)
	await press_key(KEY_ESCAPE)
	expect_true(game.paused)
	await press_key(KEY_ESCAPE)
	expect_false(game.paused)


func test_the_build_preview_explains_why_a_tile_is_refused() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	await click_tile(3, 10) # the road
	expect_eq(game.world.towers.size(), 0)
	game.world.money = 0
	await click_tile(3, 9)
	expect_eq(game.world.towers.size(), 0, "not enough money")
	expect_true(game.hud.tower_buttons["gun"].is_selected())


func test_locked_levels_cannot_be_started() -> void:
	use_profile()
	Router.goto_levels()
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	expect_true(levels.play_buttons["meadow"].is_enabled())
	expect_false(levels.play_buttons["riverside"].is_enabled())
	expect_false(levels.play_buttons["endless"].is_enabled())
	await click_button(levels.play_buttons["riverside"])
	await frames(5)
	expect_true(scene() is LevelSelectScene, "still on the level select screen")


func test_upgrades_screen_buys_a_perk_with_stars() -> void:
	use_profile({"meadow": 3})
	Router.goto_menu()
	if not await wait_for_scene("MenuScene"):
		return
	var menu: MenuScene = scene()
	await click_button(menu.buttons["upgrades"])
	if not await wait_for_scene("UpgradesScene"):
		return
	var upgrades: UpgradesScene = scene()
	await click_button(upgrades.buy_buttons["capital"])
	Profile.forget_cache()
	expect_eq(Profile.load_profile().perk_rank("capital"), 1)


func test_touch_controls_work_on_a_phone() -> void:
	use_profile()
	Router.goto_menu()
	if not await wait_for_scene("MenuScene"):
		return
	var menu: MenuScene = scene()
	await tap_button(menu.buttons["play"])
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	await tap_button(levels.play_buttons["meadow"])
	if not await wait_for_scene("GameScene"):
		return
	var game: GameScene = scene()
	await tap_button(game.hud.tower_buttons["missile"])
	var p: Vector2 = tile(6, 9)
	await tap(p.x, p.y)
	await tap(p.x, p.y)
	await tap_button(game.hud.upgrade_button)
	await tap_button(game.hud.wave_button)
	expect_eq(game.world.towers.size(), 1)
	if not game.world.towers.is_empty():
		expect_eq(game.world.towers[0].level, 1)
	expect_eq(game.world.wave_index, 0)
