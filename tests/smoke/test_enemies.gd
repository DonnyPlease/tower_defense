extends SceneTestCase
## The newer enemies on screen: the Colossus's phases, a saboteur's EMP, a
## hopper in the air, a warchief's rally, and the Citadel level.


func near(a: Color, b: Color, tolerance: float = 0.04) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


func frozen(game: GameScene, type: String, x: float, y: float) -> Enemy:
	var e: Enemy = game.world.spawn(type)
	e.apply_slow(1.0, 1_000_000)
	e.nav.x = x
	e.nav.y = y
	e.x = x
	e.y = y
	e.prev_x = x
	e.prev_y = y
	return e


func test_the_colossus_announces_its_phases() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var c: Enemy = frozen(game, "colossus", 300, 420)
	await frames(2)
	expect_match(game.boss_label(), "^Colossus  \\d+ / \\d+$")
	game.world.damage_enemy(c, c.max_hitpoints * 0.4, true)
	await frames(2)
	expect_eq(game.banner_text(), "The Colossus sheds its armor!")
	game.world.damage_enemy(c, c.max_hitpoints * 0.3, true)
	await frames(2)
	expect_eq(game.banner_text(), "The Colossus calls for help!")
	expect_gt(game.world.enemies.size(), 1, "its helpers are on the field")


func test_a_saboteur_greys_out_the_towers_it_switches_off() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var w: World = game.world
	var t: Tower = w.build("gun", 3, 1)
	await frames(2)
	var view: TowerView = game.field.tower_view(t)
	expect_not_null(view)
	var s: Enemy = frozen(game, "saboteur", t.x + 40, t.y)
	s.ability_timer = 1
	expect_true(await until(func() -> bool: return t.is_disabled(), 30), "the EMP went off")
	await frames(1)
	expect_lt(view.body_tint().r, 0.6, "the tower is drawn grey")
	expect_true(await until(func() -> bool: return not t.is_disabled(), 400), "it comes back on")
	await frames(1)
	expect_eq(view.body_tint(), Color.WHITE)


func test_a_hopper_is_drawn_in_the_air_over_a_wall() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var w: World = game.world
	w.build_wall(3, 10)
	var h: Enemy = frozen(game, "hopper", 3 * Config.TILE + 20, 10 * Config.TILE + 20)
	await frames(2)
	var view: EnemyView = game.field.enemy_view(h)
	expect_not_null(view)
	expect_true(h.is_jumping())
	expect_lt(view.body_offset().y, -5.0, "lifted up")
	expect_eq(view.body_depth(), EnemyView.DEPTH_AIR, "drawn above walls and towers")


func test_the_citadel_opens_after_open_field() -> void:
	use_profile({"meadow": 3, "riverside": 3, "highlands": 3})
	Router.goto_levels()
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	expect_eq(levels.description_text("citadel"), "🔒 Beat Open Field first")
	expect_false(levels.play_buttons["citadel"].is_enabled())
	use_profile({"meadow": 3, "riverside": 3, "highlands": 3, "openfield": 1})
	Router.goto_levels()
	if not await wait_for_scene("LevelSelectScene"):
		return
	levels = scene()
	expect_true(levels.play_buttons["citadel"].is_enabled())
	await click_button(levels.play_buttons["citadel"])
	if not await wait_for_scene("GameScene"):
		return
	var game: GameScene = scene()
	expect_eq(game.level_id, "citadel")
	expect_eq(game.hud.wave_text(), "Wave 0 / 14")


func test_the_citadel_runs_a_busy_wave_without_errors() -> void:
	use_profile({}, ALL_TECH)
	var game: GameScene = await open_game("citadel")
	if game == null:
		return
	var w: World = game.world
	w.money = 100_000
	for spot: Vector2i in [Vector2i(3, 3), Vector2i(8, 7), Vector2i(10, 3), Vector2i(15, 8), Vector2i(4, 10), Vector2i(16, 10)]:
		var t: Tower = w.build(Towers.KINDS[(spot.x + spot.y) % Towers.KINDS.size()], spot.x, spot.y)
		if t != null:
			w.upgrade(t)
	for type: String in ["saboteur", "hopper", "warchief", "colossus", "scout", "tank"]:
		w.spawn(type)
	w.start_next_wave()
	game.speed = 3
	await frames(400)
	expect_eq(w.status, World.Status.PLAYING)
	expect_gt(w.kills, 0, "the towers fight")
