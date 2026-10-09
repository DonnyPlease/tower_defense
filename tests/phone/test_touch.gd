extends SceneTestCase
## Touch controls on a phone held sideways. tests/run.sh runs this suite in an
## 844 x 390 window. The game keeps its scale (600 game units tall, so 0.65)
## and grows sideways to the window's shape: 1298 x 600 game units, with no
## black bars. Taps are given in game units and mapped to the window like a
## real finger would land.

const WINDOW: Vector2 = Vector2(844, 390)


func phone_window() -> bool:
	return rendering_available() and Vector2(tree.root.size) == WINDOW


func test_the_game_fills_the_phone_screen() -> void:
	if not phone_window():
		skip("needs an 844 x 390 window; tests/run.sh phone runs one in xvfb")
		return
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var t: Transform2D = tree.root.get_final_transform()
	expect_near(t.get_scale().x, 0.65, 3, "scale")
	expect_near(t.get_scale().y, 0.65, 3, "scale")
	expect_near(t.origin.x, 0, 1, "no bar at the left")
	expect_near(t.origin.y, 0, 1, "no bar at the top")
	expect_near(Screen.size(game).x, WINDOW.x / 0.65, 0, "the view is as wide as the window")
	var img: Image = await screenshot()
	expect_eq(Vector2(img.get_size()), WINDOW, "the whole window is drawn")
	var p: Vector2 = tile(0, 0)
	expect_color(pixel_at(img, p.x, p.y), Palette.GRASS_ALT, "the field")

	var map: Rect2 = game.map_rect()
	expect_near(map.size.y, Screen.size(game).y, 0, "the map is as tall as the screen")

	# The window itself, as the X server shows it: the land goes on to its left
	# edge (no black bar), and the sidebar is at its right edge.
	await RenderingServer.frame_post_draw
	var screen: Image = DisplayServer.screen_get_image(DisplayServer.window_get_current_screen())
	if screen == null or screen.is_empty():
		return
	var at: Vector2i = DisplayServer.window_get_position()
	var left: Color = screen.get_pixelv(at + Vector2i(4, 200))
	expect_gt(left.g, left.r + 0.08, "grass at the left edge of the window (got #%s)" % left.to_html(false))
	var rail: Color = screen.get_pixelv(at + Vector2i(840, 200))
	expect_color(rail, Palette.PANEL, "the sidebar at the right edge", 0.06)
	p = tile(1, 0)
	expect_color(screen.get_pixelv(at + Vector2i(t * p)), Palette.GRASS, "the field")


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


func test_taps_beside_the_field_build_nothing() -> void:
	if not phone_window():
		skip("needs an 844 x 390 window; tests/run.sh phone runs one in xvfb")
		return
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	var left: float = game.field_to_screen(Vector2.ZERO).x
	expect_gt(left, 20, "there is room left of the field")
	for x: float in [6.0, left - 6]:
		await tap(x, tile(0, 0).y) # left of the field, level with its top row
	expect_eq(game.world.towers.size(), 0, "nothing built")
	expect_eq(game.tool, "gun", "the tool is still picked")
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
	# Selected with a tap and sold with a tap (a tap spans several frames).
	await tap(p.x, p.y)
	expect_eq(game.selected_wall, Vector2i(5, 11), "a tap on the wall selects it")
	await tap_button(game.hud.sell_button)
	expect_false(game.world.has_wall(5, 11), "sold by touch")
	await tap_button(game.ability_bar.buttons["wall"])
	await tap(p.x, p.y)
	await tap_button(game.ability_bar.toggle_button)
	await frames(10)
	await tap_button(game.ability_bar.buttons["slow"])
	expect_true(game.world.is_active("slow"))
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 15 - 60))


func test_tap_to_build_by_touch() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var p: Vector2 = tile(6, 9)
	await tap(p.x, p.y)
	expect_true(game.build_menu.is_open(), "a tap on grass opens the build menu")
	if not game.build_menu.is_open():
		return
	await tap_button(game.build_menu.buttons["gun"])
	expect_eq(tower_names(game), ["gun@6,9"])
	expect_false(game.build_menu.is_open())


func test_a_phone_gets_a_bigger_rail_in_two_columns_clear_of_the_notch() -> void:
	if not phone_window():
		skip("needs an 844 x 390 window; tests/run.sh phone runs one in xvfb")
		return
	use_profile()
	Screen.forced_ui_scale = Screen.MAX_UI_SCALE # as a small touch screen measures
	Screen.forced_insets = Vector4(40, 0, 0, 14) # a notch on the left, a home bar below
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var view: Vector2 = Screen.size(game)
	var hud: Hud = game.hud
	expect_eq(hud.columns, 2)
	expect_near(hud.scale.x, Screen.MAX_UI_SCALE, 3)
	var rail: Rect2 = hud.get_global_rect()
	expect_near(rail.end.x, view.x, 0, "at the right edge")
	var map: Rect2 = game.map_rect()
	expect_near(map.size.y, view.y - 14, 0, "the map is still as tall as it can be")
	expect_true(map.position.x >= 40 and map.end.x <= rail.position.x, "between the notch and the rail")
	var tower: Rect2 = hud.tower_buttons["missile"].get_global_rect()
	expect_gt(tower.size.y, 1.39 * Hud.TILE_H, "bigger buttons")
	expect_true(rail.encloses(tower) and tower.end.x < rail.get_center().x, "the towers in the column by the map")
	var wave: Rect2 = hud.wave_button.get_global_rect()
	expect_gt(wave.position.x, rail.get_center().x, "the wave controls in the outer column")
	expect_lt(hud.pause_button.get_global_rect().end.y, view.y - 14, "above the home bar")

	# Everything still works by touch.
	await tap_button(hud.tower_buttons["missile"])
	var p: Vector2 = tile(6, 9)
	await tap(p.x, p.y)
	expect_eq(tower_names(game), ["missile@6,9"])
	await tap(p.x, p.y)
	await frames(10)
	var card: Rect2 = game.card.get_global_rect()
	expect_gt(card.size.x, TowerCard.W * 1.39, "the card is bigger too")
	expect_true(card.position.x >= 0 and card.end.x <= rail.position.x and card.end.y <= view.y, "on the screen, beside the rail")
	await tap_button(hud.upgrade_button)
	expect_eq(game.selected.level, 1)
	await tap_button(game.ability_bar.toggle_button)
	await frames(10)
	expect_true(game.ability_bar.is_open())
	await tap_button(game.ability_bar.buttons["slow"])
	expect_true(game.world.is_active("slow"))
	await tap_button(hud.wave_button)
	expect_eq(game.world.wave_index, 0)
