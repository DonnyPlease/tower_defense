extends SceneTestCase
## Plays the game screen like a player, with the mouse and the keyboard, and
## checks what the player sees: the sidebar, banners, dialogs, floating texts.


## Clicks a dialog button that restarts the level (Restart, Try again) and
## waits for the new game screen.
func click_restart(game: GameScene, b: GameButton) -> bool:
	var old: int = game.get_instance_id() # the old scene is freed: keep only its id
	await click_button(b)
	var replaced: bool = await until(func() -> bool:
		return scene() is GameScene and scene().get_instance_id() != old, 300)
	await frames(2)
	return replaced


func test_building_upgrading_retargeting_and_selling_with_the_mouse() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var hud: Hud = game.hud
	var w: World = game.world
	expect_eq(hud.money_text(), "$ 250")
	expect_eq(hud.lives_text(), "♥ 20")
	expect_eq(hud.wave_text(), "Wave 0 / 8")
	expect_eq(hud.panel_title_text(), "", "nothing to read about yet")
	expect_false(game.card.visible, "no tower selected")

	# Pick the missile tower on the rail: a help card beside it describes it.
	var cost: int = w.cost_of("missile")
	await click_button(hud.tower_buttons["missile"])
	expect_eq(game.tool, "missile")
	expect_true(hud.tower_buttons["missile"].is_selected())
	expect_eq(hud.tower_buttons["missile"].label_text(), "$%d" % cost)
	expect_eq(hud.panel_title_text(), "Missile  ·  $%d" % cost)
	expect_contains(hud.panel_body_text(), "Hits: ground + air")

	# Build it on the grass.
	await click_tile(6, 9)
	expect_eq(tower_names(game), ["missile@6,9"])
	expect_eq(hud.money_text(), "$ %d" % (250 - cost))
	expect_gt(game.field.effect_count(), 0, "building raises dust")
	if w.towers.is_empty():
		return
	var t: Tower = w.towers[0]
	expect_not_null(game.field.tower_view(t), "the tower is drawn")

	# Clicking it selects it: a card next to it shows it with its buttons.
	await click_tile(6, 9)
	await frames(10) # the card pops in
	expect_true(game.selected == t, "selected")
	expect_eq(game.tool, "", "selecting puts the build tool away")
	expect_eq(hud.panel_title_text(), "Missile  ·  Level 1")
	expect_true(game.card.visible and hud.upgrade_button.visible and hud.target_button.visible and hud.sell_button.visible)
	var r: Rect2 = game.card.get_global_rect()
	var at: Vector2 = tile(6, 9)
	expect_true(r.position.x > at.x or r.end.x < at.x, "the card is beside the tower, not on it")
	expect_lt(absf(r.get_center().y - at.y), r.size.y, "level with it")
	expect_eq(hud.upgrade_button.label_text(), "Upgrade  $%d" % w.upgrade_cost_of(t))
	var ub: Vector2 = hud.upgrade_button.get_global_rect().get_center()
	await hover(ub.x, ub.y)
	expect_true(game.card.upgrade_hovered, "on Upgrade the next level's reach is drawn")
	expect_gt(t.reach_at_level(1), t.attack_range)
	await click_button(hud.upgrade_button)
	expect_eq(t.level, 1)
	expect_eq(hud.panel_title_text(), "Missile  ·  Level 2")
	expect_eq(hud.target_button.label_text(), "Target: First")
	await click_button(hud.target_button)
	expect_eq(t.target_mode, Towers.TargetMode.LAST)
	expect_eq(hud.target_button.label_text(), "Target: Last")

	# Build a second tower and sell it.
	await press_key(KEY_1)
	await click_tile(13, 7)
	await click_tile(13, 7)
	var gun: Tower = game.selected
	expect_true(gun != null and gun.kind == "gun", "the gun is selected")
	if gun == null:
		return
	var value: int = gun.sell_value()
	var money: int = w.money
	await frames(10)
	expect_eq(hud.sell_button.label_text(), "Sell  +$%d" % value)
	await click_button(hud.sell_button)
	expect_eq(tower_names(game), ["missile@6,9"])
	expect_eq(w.money, money + value)
	expect_true(game.field.floating_texts().has("+$%d" % value), "the refund floats up")
	expect_null(game.selected)
	expect_false(game.card.visible, "the card goes away")
	expect_eq(hud.panel_title_text(), "")

	# Start the wave: the tower shoots, kills pay out.
	await click_button(hud.wave_button)
	game.speed = 3
	expect_true(await until(func() -> bool: return w.kills > 0), "the tower killed something")
	expect_true(Array(game.field.floating_texts()).any(func(s: String) -> bool: return s.begins_with("+$")),
		"the kill reward floats up")


func test_keyboard_shortcuts() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.world.money = 10_000
	await press_key(KEY_2)
	expect_eq(game.tool, "missile")
	expect_true(game.hud.tower_buttons["missile"].is_selected())
	await press_key(KEY_2)
	expect_eq(game.tool, "", "the same key again puts the tool away")
	await press_key(KEY_3)
	expect_eq(game.tool, "", "locked towers can't be picked")
	await press_key(KEY_1)
	await click_tile(6, 9)
	await click_tile(6, 9)
	expect_not_null(game.selected)
	if game.selected == null:
		return
	await press_key(KEY_U)
	await press_key(KEY_T)
	expect_eq(game.selected.level, 1)
	expect_eq(game.selected.target_mode, Towers.TargetMode.LAST)
	await press_key(KEY_F)
	expect_eq(game.speed, 2)
	expect_eq(game.hud.speed_button.label_text(), "2x")
	await press_key(KEY_SPACE)
	expect_eq(game.world.wave_index, 0)
	await press_key(KEY_S)
	expect_eq(game.world.towers.size(), 0)
	await press_key(KEY_ESCAPE)
	expect_true(game.paused)
	await press_key(KEY_SPACE)
	expect_eq(game.world.wave_index, 0, "no new wave while paused")
	await press_key(KEY_ESCAPE)
	expect_false(game.paused)
	await press_key(KEY_P)
	expect_true(game.paused, "P pauses too")
	await press_key(KEY_P)
	expect_false(game.paused)
	await press_key(KEY_M)
	Profile.forget_cache()
	expect_true(Profile.load_profile().music, "M switches the music on")


func test_right_click_and_escape_cancel_the_tool_and_the_selection() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	var p: Vector2 = tile(10, 1)
	await click(p.x, p.y, MOUSE_BUTTON_RIGHT)
	expect_eq(game.tool, "", "right click puts the tool away")
	expect_eq(game.world.towers.size(), 0, "and builds nothing")
	expect_false(game.hud.tower_buttons["gun"].is_selected())

	await press_key(KEY_1)
	await click_tile(3, 9)
	await click_tile(3, 9)
	expect_not_null(game.selected)
	await click(p.x, p.y, MOUSE_BUTTON_RIGHT)
	expect_null(game.selected, "right click deselects")
	expect_false(game.card.visible)

	await click_tile(3, 9)
	await press_key(KEY_ESCAPE)
	expect_null(game.selected, "Esc deselects")
	expect_false(game.paused, "Esc only pauses when nothing is selected")


func test_a_new_game_starts_at_the_speed_last_picked() -> void:
	var p: Profile = use_profile()
	p.speed = 3
	Profile.save_profile(p)
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	expect_eq(game.speed, 3)
	expect_eq(game.hud.speed_button.label_text(), "3x")


func test_auto_waves_start_the_next_wave_after_a_pause() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var hud: Hud = game.hud
	var w: World = game.world
	await click_button(hud.menu_button)
	await frames(10)
	expect_eq(hud.auto_button.label_text(), "Auto waves off")
	await click_button(hud.auto_button)
	expect_eq(hud.auto_button.label_text(), "Auto waves on")
	expect_true(Profile.load_profile().auto_waves, "saved")
	await press_key(KEY_ESCAPE)
	await frames(30)
	expect_eq(w.wave_index, -1, "the first wave still waits for the player")
	expect_eq(hud.wave_button.sublabel_text(), "build first!")

	game.speed = 3
	await click_button(hud.wave_button)
	# Clear the wave at once.
	expect_true(await until(func() -> bool:
		for e: Enemy in w.enemies.duplicate():
			w.damage_enemy(e, 1e9)
		return not w.wave_in_progress()), "wave 1 cleared")
	await frames(2)
	expect_eq(hud.wave_button.sublabel_text(), "auto in 5 s")
	expect_true(await until(func() -> bool: return w.wave_index == 1), "wave 2 starts by itself")


func test_rail_pause_speed_and_sound_buttons() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var hud: Hud = game.hud
	expect_eq(hud.speed_button.label_text(), "1x")
	for label: String in ["2x", "3x", "1x"]:
		await click_button(hud.speed_button)
		expect_eq(hud.speed_button.label_text(), label)
		expect_eq(game.speed, label.to_int())
		expect_eq(hud.speed_button.is_selected(), label != "1x", label)

	await click_button(hud.speed_button)
	Profile.forget_cache()
	expect_eq(Profile.load_profile().speed, 2, "the speed is remembered")
	await click_button(hud.speed_button)
	await click_button(hud.speed_button)

	# The sound switches are in the gear menu.
	expect_false(hud.music_button.is_visible_in_tree(), "the gear menu starts closed")
	await click_button(hud.menu_button)
	expect_true(hud.is_menu_open())
	await frames(10) # it fades in
	expect_false(hud.music_button.is_selected())
	await click_button(hud.music_button)
	expect_true(hud.music_button.is_selected(), "music on")
	await click_button(hud.sfx_button)
	expect_true(hud.sfx_button.is_selected(), "effects on")
	expect_true(hud.is_menu_open(), "it stays open while it's used")
	Profile.forget_cache()
	var p: Profile = Profile.load_profile()
	expect_true(p.music and p.sfx, "saved")
	var grass: Vector2 = tile(3, 3)
	await click(grass.x, grass.y)
	expect_false(hud.is_menu_open(), "a click elsewhere closes it")
	await click_button(hud.menu_button)
	await press_key(KEY_ESCAPE)
	expect_false(hud.is_menu_open(), "so does Esc")
	expect_false(game.paused, "without pausing")
	await click_button(hud.menu_button)
	await frames(10)
	await click_button(hud.quit_button)
	expect_true(game.paused, "the menu opens the pause dialog")
	expect_false(hud.is_menu_open())
	await click_button(game.pause_overlay.button("Resume"))
	game.build_menu.close()

	expect_eq(hud.pause_button.label_text(), "II")
	await click_button(hud.pause_button)
	expect_true(game.paused)
	expect_eq(hud.pause_button.label_text(), "▶")
	expect_true(game.pause_overlay.visible)
	expect_eq(game.pause_overlay.title_text(), "Paused")
	expect_eq(game.pause_overlay.subtitle_text(), "Esc to resume")
	var tick: int = game.world.tick
	await frames(10)
	expect_eq(game.world.tick, tick, "time stands still")
	await click_button(hud.wave_button) # covered by the dialog
	expect_eq(game.world.wave_index, -1, "the dialog blocks the rail")
	await click_button(game.pause_overlay.button("Resume"))
	expect_false(game.paused)
	expect_false(game.pause_overlay.visible)
	expect_eq(hud.pause_button.label_text(), "II")
	await frames(2)
	expect_gt(game.world.tick, tick, "time runs again")


func test_the_pause_dialog_restarts_and_leaves() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	await click_tile(3, 9)
	await press_key(KEY_P)
	expect_true(await click_restart(game, game.pause_overlay.button("Restart level")), "restarted")
	var again: GameScene = scene()
	expect_eq(again.world.towers.size(), 0, "a fresh start")
	expect_false(again.paused)
	await press_key(KEY_P)
	await click_button(again.pause_overlay.button("Level select"))
	expect_true(await wait_for_scene("LevelSelectScene"))


func test_losing_focus_pauses_the_game() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await lose_focus()
	expect_true(game.paused, "paused")
	expect_true(game.pause_overlay.visible)
	await lose_focus()
	expect_true(game.paused, "still paused (not toggled back)")
	await press_key(KEY_ESCAPE)
	expect_false(game.paused)


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
	expect_eq(menu.buttons["continue"].sublabel_text(), "Meadow · wave 1")
	expect_true(menu.buttons["continue"].get_global_rect().position.y < menu.buttons["play"].get_global_rect().position.y,
		"above Play")
	await click_button(menu.buttons["continue"])
	if not await wait_for_scene("GameScene"):
		return
	game = scene()
	expect_eq(tower_names(game), ["gun@3,9"])
	expect_true(game.resumed)
	expect_eq(game.banner_text(), "Meadow\nGame resumed")


func test_the_next_wave_preview_tells_about_its_enemies() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var hud: Hud = game.hud
	var scout: GameButton = hud.preview_buttons["scout"]
	var at: Vector2 = scout.get_global_rect().get_center()
	await hover(at.x, at.y)
	expect_eq(hud.panel_title_text(), "Scout  ·  ×8")
	expect_contains(hud.panel_body_text(), "HP %d  ·  Speed 90" % MathX.js_round(20 * game.world.hp_multiplier_at(0)))
	expect_contains(hud.panel_body_text(), "Worth $5  ·  Costs 1 life")
	await hover_field(400, 300)
	expect_eq(hud.panel_title_text(), "", "gone when the pointer leaves")
	# A tap keeps it up (touch screens can't hover), until a tap elsewhere.
	await click_button(scout)
	await hover_field(400, 300)
	expect_eq(hud.panel_title_text(), "Scout  ·  ×8")
	await right_click_beside_map()
	expect_eq(hud.panel_title_text(), "")


func test_the_wave_button_previews_the_next_wave_and_pays_for_calling_early() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var hud: Hud = game.hud
	var w: World = game.world
	expect_eq(game.banner_text(), "Meadow")
	expect_eq(hud.wave_button.label_text(), "Start wave 1")
	expect_eq(hud.wave_button.sublabel_text(), "build first!")
	expect_eq(hud.preview_key(), "scout8")

	await click_button(hud.wave_button)
	expect_eq(w.wave_index, 0)
	expect_eq(game.banner_text(), "Wave 1")
	await frames(20)
	expect_true(game.banner_showing(), "the banner fades in")
	expect_eq(hud.wave_text(), "Wave 1 / 8")
	expect_eq(hud.preview_key(), "scout12", "the preview moves on")
	expect_eq(hud.wave_button.label_text(), "Wave 1")
	expect_match(hud.wave_button.sublabel_text(), "^\\d+ left$")
	expect_false(hud.wave_button.is_enabled(), "can't call while spawning")
	await frames(150)
	expect_false(game.banner_showing(), "the banner fades out")

	expect_true(await until(func() -> bool: return not w.is_spawning()), "spawned")
	expect_false(w.enemies.is_empty(), "enemies are still walking")
	await frames(1)
	expect_eq(hud.wave_button.label_text(), "Call wave 2")
	expect_eq(hud.wave_button.sublabel_text(), "+$14 early")
	expect_true(hud.wave_button.is_enabled())
	var money: int = w.money
	await click_button(hud.wave_button)
	expect_eq(w.wave_index, 1)
	expect_eq(w.money, money + 14)
	expect_true(game.field.floating_texts().has("Early call +$14"), "the bonus floats up")
	expect_eq(game.banner_text(), "Wave 2")


func test_clearing_a_wave_pays_a_bonus() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var w: World = game.world
	for spot: Vector2i in [Vector2i(6, 9), Vector2i(9, 9), Vector2i(13, 8)]:
		w.build("missile", spot.x, spot.y)
	await press_key(KEY_SPACE)
	game.speed = 3
	expect_true(await until(func() -> bool: return w.waves_cleared == 1), "cleared")
	expect_match(game.banner_text(), "^Wave cleared  \\+\\$20(\\nInterest \\+\\$\\d+)?$")
	await frames(1)
	expect_eq(game.hud.wave_button.label_text(), "Start wave 2")
	expect_eq(game.hud.wave_button.sublabel_text(), "Space")
	expect_eq(game.hud.money_text(), "$ %d" % w.money)


func test_boss_and_final_wave_banners() -> void:
	use_profile(ALL_STARS, ALL_TECH)
	var game: GameScene = await open_game("highlands")
	if game == null:
		return
	var w: World = game.world
	w.wave_index = 4
	await frames(1)
	expect_eq(game.hud.wave_button.label_text(), "Start wave 6")
	expect_eq(game.hud.preview_key(), "boss1,scout12")
	await click_button(game.hud.wave_button)
	expect_eq(game.banner_text(), "Wave 6\nBoss incoming!")
	expect_true(await until(func() -> bool: return w.enemies.any(func(e: Enemy) -> bool: return e.def.boss)),
		"the boss came")
	if rendering_available(): # the boss bar's label is set while it is drawn
		await frames(2)
		expect_match(game.boss_label(), "^Warlord  \\d+ / \\d+$")

	game = await open_game("meadow")
	if game == null:
		return
	game.world.wave_index = 6
	await press_key(KEY_SPACE)
	expect_eq(game.banner_text(), "Final wave!")
	expect_eq(game.hud.preview_key(), "", "nothing comes after")
	expect_eq(game.hud.wave_button.label_text(), "Final wave")
	expect_false(game.hud.wave_button.is_enabled())


func test_an_enemy_reaching_the_exit_costs_a_life() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var w: World = game.world
	await press_key(KEY_SPACE)
	game.speed = 3
	expect_true(await until(func() -> bool: return w.lives < 20), "an enemy got through")
	expect_eq(game.hud.lives_text(), "♥ 19")
	expect_true(game.field.floating_texts().has("-1 ♥"), "the lost life floats up")
	expect_true(game.fx.is_flashing(), "the screen flashes red")
	expect_true(game.fx.is_shaking(), "the screen shakes")


func test_hit_enemies_flash_and_everything_has_a_view() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var w: World = game.world
	w.build("gun", 3, 9)
	w.build("gun", 6, 9)
	await press_key(KEY_SPACE)
	var hit := func() -> bool: return w.enemies.any(func(e: Enemy) -> bool: return e.hit_flash > 0)
	expect_true(await until(hit), "something was hit")
	for e: Enemy in w.enemies:
		var view: EnemyView = game.field.enemy_view(e)
		expect_not_null(view, "every enemy is drawn")
		if view != null:
			expect_eq(view.is_flashing(), e.hit_flash > 0, "enemy %d flashes exactly while hit" % e.id)
	for t: Tower in w.towers:
		expect_not_null(game.field.tower_view(t), "every tower is drawn")


func test_refused_builds_explain_why() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	await hover_tile(3, 10) # the road of a level with walls: a tower needs a wall there
	expect_eq(game.ghost_state(), "blocked", "red preview")
	expect_eq(game.hint_text(), "Build a wall first")
	await click_tile(3, 10)
	expect_eq(game.world.towers.size(), 0)
	expect_true(game.field.floating_texts().has("Build a wall first"), "says why")

	await hover_tile(3, 9)
	expect_eq(game.ghost_state(), "ok", "white preview on free grass")
	expect_eq(game.hint_text(), "")
	await click_tile(3, 9)
	expect_eq(game.world.towers.size(), 1)
	await hover_tile(3, 9)
	expect_eq(game.ghost_state(), "hidden", "no preview over a tower")

	game.world.money = 0
	await hover_tile(4, 9)
	expect_eq(game.ghost_state(), "blocked", "red preview when it's too expensive")
	await click_tile(4, 9)
	expect_eq(game.world.towers.size(), 1, "not built")
	expect_true(game.field.floating_texts().has("Not enough money"), "says why")
	expect_true(game.hud.tower_buttons["gun"].is_selected(), "the tool stays picked")

	var rail: Vector2 = on_rail()
	await hover(rail.x, rail.y)
	expect_eq(game.ghost_state(), "hidden")


func test_the_road_of_a_level_without_walls_cannot_be_built_on() -> void:
	use_profile(ALL_STARS, ALL_TECH)
	var game: GameScene = await open_game("riverside")
	if game == null:
		return
	await press_key(KEY_1)
	await hover_tile(3, 3) # the road
	expect_eq(game.ghost_state(), "hidden", "no preview on the road")
	await click_tile(3, 3)
	expect_eq(game.world.towers.size(), 0)
	expect_true(game.field.floating_texts().has("Can't build here"), "says why")


func test_maze_levels_refuse_to_block_the_path() -> void:
	use_profile(ALL_STARS, ALL_TECH)
	var game: GameScene = await open_game("openfield")
	if game == null:
		return
	expect_contains(game.tips_text(), "No road here")
	# Column 6 is rock except rows 7 and 8: closing both would wall the exit off.
	await press_key(KEY_1)
	await click_tile(6, 7)
	expect_eq(tower_names(game), ["gun@6,7"])
	await hover_tile(6, 8)
	expect_eq(game.ghost_state(), "blocked")
	expect_eq(game.hint_text(), "That would block the path")
	await click_tile(6, 8)
	expect_eq(tower_names(game), ["gun@6,7"], "not built")
	expect_true(game.field.floating_texts().has("That would block the path"), "says why")
	await hover_tile(3, 3)
	expect_eq(game.ghost_state(), "ok", "open ground is fine")
	expect_eq(game.hint_text(), "")


func test_winning_a_level_awards_stars_to_spend_in_the_tech_tree() -> void:
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
	expect_eq(game.win_overlay.title_text(), "Victory!")
	expect_eq(game.win_overlay.subtitle_text(), "★★★\n20 of 20 lives left.\n+3 ★ to spend in the tech tree!")
	expect_eq(game.hud.wave_button.label_text(), "Game over")
	Profile.forget_cache()
	var p: Profile = Profile.load_profile()
	expect_eq(p.stars_on("meadow"), 3)
	expect_null(p.save)

	# Spend them on the cannon, then play the next level with it.
	await click_button(game.win_overlay.button("Tech tree"))
	if not await wait_for_scene("TechTreeScene"):
		return
	var tree: TechTreeScene = scene()
	expect_eq(tree.stars_text(), "★ 3 to spend  (3 earned)")
	await click_button(tree.node_buttons["cannon"])
	expect_eq(tree.state_text("cannon"), "Owned")
	await click_button(tree.levels_button)
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	expect_eq(levels.status_text("meadow"), "★★★")
	expect_true(levels.play_buttons["riverside"].is_enabled(), "the next level is open")
	await click_button(levels.play_buttons["riverside"])
	if not await wait_for_scene("GameScene"):
		return
	game = scene()
	await press_key(KEY_3)
	expect_eq(game.tool, "cannon", "the cannon can be built now")


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
	expect_eq(game.lose_overlay.title_text(), "Defeat")
	expect_eq(game.lose_overlay.subtitle_text(), "You reached wave 1 of 8.")
	expect_eq(game.hud.wave_button.label_text(), "Game over")
	expect_false(game.hud.wave_button.is_enabled())
	await press_key(KEY_ESCAPE)
	expect_false(game.pause_overlay.visible, "no pausing after the end")
	Profile.forget_cache()
	expect_null(Profile.load_profile().save)
	expect_true(await click_restart(game, game.lose_overlay.button("Try again")), "restarted")
	var again: GameScene = scene()
	expect_eq(again.world.lives, Levels.by_id("meadow").lives)
	expect_eq(again.hud.lives_text(), "♥ 20")


func test_endless_mode_ends_with_the_survived_waves_and_the_record() -> void:
	use_profile(ALL_STARS, ALL_TECH)
	var game: GameScene = await open_game("endless")
	if game == null:
		return
	expect_eq(game.banner_text(), "Endless mode")
	expect_eq(game.hud.wave_text(), "Wave 0", "no wave count in endless mode")
	var w: World = game.world
	w.money = 1_000_000
	for r: int in Config.ROWS:
		for c: int in range(1, Config.COLS, 2):
			var t: Tower = w.build("gun", c, r)
			if t != null:
				w.upgrade(t)
	await press_key(KEY_SPACE)
	game.speed = 3
	expect_true(await until(func() -> bool: return w.waves_cleared == 1), "survived a wave")
	for t: Tower in w.towers.duplicate():
		w.sell(t)
	w.lives = 1
	await press_key(KEY_SPACE)
	expect_true(await until(func() -> bool: return w.status == World.Status.LOST), "overrun")
	expect_eq(game.lose_overlay.title_text(), "Overrun!")
	expect_eq(game.lose_overlay.subtitle_text(), "You survived 1 waves.\nNew personal best!")
	Profile.forget_cache()
	expect_eq(Profile.load_profile().endless_best, 1)

	# Worse than the record this time.
	expect_true(await click_restart(game, game.lose_overlay.button("Try again")), "restarted")
	game = scene()
	game.world.lives = 1
	await press_key(KEY_SPACE)
	game.speed = 3
	expect_true(await until(func() -> bool: return game.world.status == World.Status.LOST), "overrun again")
	expect_eq(game.lose_overlay.subtitle_text(), "You survived 0 waves.\nBest: 1 waves")


func test_every_map_runs_a_busy_wave_without_errors() -> void:
	for level_id: String in ["meadow", "riverside", "highlands", "openfield", "endless"]:
		use_profile(ALL_STARS, ALL_TECH)
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
		expect_gt(game.field.effect_count(), 0, level_id + ": effects play")
		for t: Tower in w.towers:
			expect_not_null(game.field.tower_view(t), "%s: %s is drawn" % [level_id, t.kind])
		for e: Enemy in w.enemies:
			expect_not_null(game.field.enemy_view(e), "%s: %s is drawn" % [level_id, e.type])


func test_the_tower_card_folds_out_its_details() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.world.money = 10_000
	await press_key(KEY_2)
	await click_tile(6, 9)
	await click_tile(6, 9)
	await frames(10)
	var card: TowerCard = game.card
	expect_false(card.body_text().contains("Damage"), "the stats start folded away")
	var folded: float = card.size.y
	await click_button(card.details_button)
	expect_contains(card.body_text(), "Damage 6")
	expect_contains(card.body_text(), "Next level:\nDamage 10")
	expect_contains(card.body_text(), "This game: 0 kills  ·  0 damage", "and how it has done")
	expect_gt(card.size.y, folded + 60, "the card grows to show them")
	# The choice is kept for the next tower.
	await press_key(KEY_ESCAPE)
	await press_key(KEY_1)
	await click_tile(13, 7)
	await click_tile(13, 7)
	await frames(10)
	expect_eq(card.title_text(), "Gun  ·  Level 1")
	expect_contains(card.body_text(), "Damage 3")
	await click_button(card.details_button)
	expect_false(card.body_text().contains("Damage"))
	expect_near(card.size.y, folded, 0)


func test_the_map_fills_the_window_beside_the_rail() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var view: Vector2 = Screen.size(game)
	var rail: Rect2 = game.hud.get_global_rect()
	expect_near(rail.end.x, view.x, 0, "the rail is at the right edge")
	expect_near(rail.size.y, view.y, 0, "full height")
	var map: Rect2 = game.map_rect()
	expect_near(map.size.x / map.size.y, 4.0 / 3.0, 2, "the map keeps its shape")
	expect_true(is_equal_approx(map.size.y, view.y) or is_equal_approx(map.size.x, view.x - Hud.W),
		"the map is as big as it can be")
	expect_le(map.end.x, rail.position.x + 0.5, "and is not under the rail")
	# The land around the map is drawn but can't be built on; a click there lets go of the tower.
	await press_key(KEY_2)
	await click_tile(6, 9)
	await click_tile(6, 9)
	expect_not_null(game.selected)
	if map.position.x >= 4:
		await click(map.position.x / 2, map.get_center().y)
		expect_null(game.selected, "deselected")
		expect_eq(game.world.towers.size(), 1, "nothing built outside the map")
