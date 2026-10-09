extends SceneTestCase
## Tap-to-build, holding a button for its help, and Android's back button.


func test_a_click_on_empty_grass_opens_a_menu_of_what_can_go_there() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var menu: BuildMenu = game.build_menu
	expect_false(menu.is_open())
	await click_tile(6, 9)
	expect_true(menu.is_open(), "the menu opens")
	expect_eq(menu.buttons.keys(), ["gun", "missile", "wall"], "the towers owned, and a wall")
	expect_eq(menu.buttons["gun"].label_text(), "$%d" % game.world.cost_of("gun"))
	var r: Rect2 = menu.get_global_rect()
	expect_true(game.map_rect().encloses(r), "inside the field")
	expect_false(r.has_point(tile(6, 9)), "beside the tile, not over it")
	# Hovering a choice explains it.
	var b: Rect2 = menu.buttons["missile"].get_global_rect()
	await hover(b.get_center().x, b.get_center().y)
	expect_eq(game.hud.panel_title_text(), "Missile  ·  $%d" % game.world.cost_of("missile"))
	expect_eq(menu.previewing, "missile", "and its reach is drawn around the tile")
	var money: int = game.world.money
	await click_button(menu.buttons["missile"])
	expect_eq(tower_names(game), ["missile@6,9"])
	expect_eq(game.world.money, money - game.world.cost_of("missile"))
	expect_false(menu.is_open(), "closed after building")
	expect_eq(menu.previewing, "", "and the reach with it")


func test_on_a_wide_road_the_menu_offers_a_wall() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await click_tile(12, 3) # Meadow's wide road
	var menu: BuildMenu = game.build_menu
	expect_true(menu.is_open())
	expect_eq(menu.buttons.keys(), ["wall"], "towers need a wall first on the road")
	await click_button(menu.buttons["wall"])
	expect_true(game.world.has_wall(12, 3))
	# Now the wall is selected by a click, not built over.
	await click_tile(12, 3)
	expect_false(menu.is_open())
	expect_eq(game.selected_wall, Vector2i(12, 3))


func test_the_menu_closes_without_building() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var menu: BuildMenu = game.build_menu
	await click_tile(6, 9)
	expect_true(menu.is_open())
	await click_tile(2, 2) # anywhere else
	expect_false(menu.is_open(), "a click elsewhere closes it")
	expect_true(game.world.towers.is_empty())
	await click_tile(6, 9)
	await press_key(KEY_ESCAPE)
	expect_false(menu.is_open(), "Esc closes it")
	expect_false(game.paused, "and doesn't pause")
	await click_tile(6, 9)
	await press_key(KEY_1)
	expect_false(menu.is_open(), "picking a tower closes it")
	expect_eq(game.tool, "gun")


func test_no_menu_where_nothing_can_be_built_or_when_deselecting() -> void:
	use_profile()
	var game: GameScene = await open_game("riverside")
	if game == null:
		return
	await click_tile(9, 5) # the river
	expect_false(game.build_menu.is_open())
	await press_key(KEY_1)
	await click_tile(2, 1)
	await press_key(KEY_ESCAPE)
	await click_tile(2, 1)
	expect_not_null(game.selected)
	await click_tile(1, 6) # grass away from the tower (and its card): this click only deselects
	expect_null(game.selected)
	expect_false(game.build_menu.is_open())


func test_unaffordable_towers_are_greyed_out_in_the_menu() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.world.money = 60
	await click_tile(6, 9)
	await frames(1)
	expect_false(game.build_menu.buttons["gun"].is_enabled())
	expect_true(game.build_menu.buttons["missile"].is_enabled())


func test_holding_a_button_shows_its_help_without_pressing_it() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var b: GameButton = game.hud.tower_buttons["missile"]
	var r: Rect2 = b.get_global_rect()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = r.get_center()
	down.global_position = down.position
	await hover(r.get_center().x, r.get_center().y)
	await hover_field(400, 300) # the help must come from holding, not from hovering
	tree.root.push_input(down, true)
	await frames(roundi(GameButton.LONG_PRESS * 60) + 5)
	expect_true(b.is_long_pressed())
	expect_eq(game.hud.panel_title_text(), "Missile  ·  $%d" % game.world.cost_of("missile"))
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = r.get_center()
	up.global_position = up.position
	tree.root.push_input(up, true)
	await frames(2)
	expect_eq(game.tool, "", "held, so not picked")
	await click_button(b)
	expect_eq(game.tool, "missile", "a normal click picks it")


func test_the_back_button_pauses_the_game_and_leaves_menus() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(1)
	expect_true(game.paused)
	expect_true(game.pause_overlay.visible)
	game.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(1)
	expect_false(game.paused, "pressed again it resumes")
	Router.goto_levels()
	if not await wait_for_scene("LevelSelectScene"):
		return
	scene().propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	expect_true(await wait_for_scene("MenuScene"), "back to the menu")
	Router.goto_tech()
	if not await wait_for_scene("TechTreeScene"):
		return
	scene().propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	expect_true(await wait_for_scene("MenuScene"))
