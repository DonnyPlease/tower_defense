extends SceneTestCase
## Touch controls on a phone held sideways. tests/run.sh runs this suite in an
## 844 x 390 window: the 1000 x 600 game is scaled to 0.65 and letterboxed,
## with 97 px bars left and right. Taps are given in game coordinates and
## mapped to the window like a real finger would land.

const WINDOW: Vector2 = Vector2(844, 390)


func letterboxed() -> bool:
	return rendering_available() and Vector2(tree.root.size) == WINDOW


func test_the_game_is_scaled_to_fit_and_letterboxed() -> void:
	if not letterboxed():
		skip("needs an 844 x 390 window; tests/run.sh phone runs one in xvfb")
		return
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var t: Transform2D = tree.root.get_final_transform()
	expect_near(t.get_scale().x, 0.65, 3, "scale")
	expect_near(t.get_scale().y, 0.65, 3, "scale")
	expect_near(t.origin.x, 97, 1, "left bar")
	expect_near(t.origin.y, 0, 1, "no bar at the top")
	var img: Image = await screenshot()
	expect_eq(Vector2(img.get_size()), Vector2(650, 390), "the game is drawn at 65 %")
	var p: Vector2 = tile(0, 0)
	expect_color(pixel_at(img, p.x, p.y), Palette.GRASS_ALT, "the field")
	expect_color(pixel_at(img, 805, 250), Palette.PANEL, "the sidebar")

	# The window itself, bars included, as the X server shows it.
	await RenderingServer.frame_post_draw
	var screen: Image = DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
	if screen == null or screen.is_empty():
		return
	var at: Vector2i = DisplayServer.window_get_position()
	expect_color(screen.get_pixelv(at + Vector2i(10, 200)), Color.BLACK, "left bar")
	expect_color(screen.get_pixelv(at + Vector2i(835, 200)), Color.BLACK, "right bar")
	p = tile(1, 0)
	expect_color(screen.get_pixelv(at + Vector2i(t * p)), Palette.GRASS, "the field, right of the left bar")
	expect_color(screen.get_pixelv(at + Vector2i(t * Vector2(805, 250))), Palette.PANEL, "the sidebar, left of the right bar")


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
	expect_eq(game.tool, "missile")
	var p: Vector2 = tile(6, 9)
	await tap(p.x, p.y)
	expect_eq(tower_names(game), ["missile@6,9"], "built where the finger landed")
	await tap(p.x, p.y)
	expect_not_null(game.selected, "a second tap selects it")
	expect_eq(game.hud.panel_title_text(), "Missile  ·  Level 1")
	await tap_button(game.hud.upgrade_button)
	expect_eq(game.hud.panel_title_text(), "Missile  ·  Level 2")
	await tap_button(game.hud.wave_button)
	expect_eq(game.world.wave_index, 0)
	expect_eq(game.banner_text(), "Wave 1")
	await tap_button(game.hud.pause_button)
	expect_true(game.paused)
	await tap_button(game.pause_overlay.button("Resume"))
	expect_false(game.paused)


func test_taps_on_the_letterbox_bars_do_nothing() -> void:
	if not letterboxed():
		skip("needs an 844 x 390 window; tests/run.sh phone runs one in xvfb")
		return
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	for x: float in [10.0, 90.0]:
		await tap_window(x, 10) # left bar, level with the top row of tiles
	expect_eq(game.world.towers.size(), 0, "nothing built")
	expect_eq(game.tool, "gun", "the tool is still picked")
	await tap_window(835, 380) # right bar, level with the sidebar's sound buttons
	Profile.forget_cache()
	expect_false(Profile.load_profile().sfx, "no button pressed")
	var p: Vector2 = tile(0, 0)
	await tap(p.x, p.y) # just inside the field
	expect_eq(tower_names(game), ["gun@0,0"])


func test_walls_and_abilities_work_by_touch() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await tap_button(game.ability_bar.buttons["wall"])
	expect_eq(game.aim, "wall")
	var p: Vector2 = tile(5, 11)
	await tap(p.x, p.y)
	expect_true(game.world.has_wall(5, 11), "a wall where the finger landed")
	await tap_button(game.ability_bar.buttons["slow"])
	expect_true(game.world.is_active("slow"))
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 15 - 60))
