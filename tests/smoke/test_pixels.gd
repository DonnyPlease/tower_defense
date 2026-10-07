extends SceneTestCase
## Checks pixels of real frames, so the drawing code is tested too (it never
## runs headless). tests/run.sh runs this suite in a virtual display (xvfb).


func before_each() -> void:
	if not rendering_available():
		skip("needs a display; tests/run.sh uses xvfb-run")


func near(a: Color, b: Color, tolerance: float = 0.04) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


func test_the_field_and_the_sidebar_are_drawn() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var img: Image = await screenshot()
	var p: Vector2 = tile(0, 0)
	expect_color(pixel_at(img, p.x, p.y), Palette.GRASS_ALT, "grass, light square")
	p = tile(1, 0)
	expect_color(pixel_at(img, p.x, p.y), Palette.GRASS, "grass, dark square")
	p = tile(3, 10)
	expect_color(pixel_at(img, p.x, p.y), Palette.PATH, "the road")
	p = tile(3, 10)
	expect_color(pixel_at(img, p.x, p.y - 19), Palette.PATH_EDGE, "the road's edge")
	expect_color(pixel_at(img, 805, 250), Palette.PANEL, "the sidebar")
	expect_color(pixel_at(img, 800.5, 250), Palette.BORDER, "the sidebar's border")


func test_a_damaged_enemy_shows_its_health_bar() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.speed = 0 # freeze the simulation (the screen still updates)
	var e: Enemy = game.world.spawn("scout")
	e.x = tile(3, 10).x
	e.y = tile(3, 10).y
	e.prev_x = e.x
	e.prev_y = e.y
	var bar := Vector2(e.x - 12 + 3, e.y - e.radius - 10 + 2) # inside the bar
	await frames(2)
	var img: Image = await screenshot()
	expect_false(near(pixel_at(img, bar.x, bar.y), Palette.GREEN, 0.1), "no bar at full health")
	e.hitpoints = e.max_hitpoints * 0.8
	await frames(2)
	img = await screenshot()
	expect_color(pixel_at(img, bar.x, bar.y), Palette.GREEN, "green bar")
	e.hitpoints = e.max_hitpoints * 0.2
	await frames(2)
	img = await screenshot()
	expect_color(pixel_at(img, bar.x, bar.y), Palette.RED, "red bar when almost dead")


func test_the_build_preview_outline_is_white_or_red() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	await hover_tile(3, 9)
	await frames(1)
	var edge := Vector2(3 * Config.TILE + 1.5, 9 * Config.TILE + Config.TILE / 2.0) # on the 2 px outline
	var img: Image = await screenshot()
	expect_color(pixel_at(img, edge.x, edge.y), Color.WHITE, "white outline where it can be built", 0.12)
	game.world.money = 0
	await hover_tile(3, 9)
	await frames(1)
	img = await screenshot()
	expect_color(pixel_at(img, edge.x, edge.y), Palette.RED, "red outline when it's too expensive", 0.12)


func test_a_dialog_dims_the_game_behind_it() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_P)
	await frames(1)
	var img: Image = await screenshot()
	var dimmed := Color(Palette.GRASS.r * 0.5, Palette.GRASS.g * 0.5, Palette.GRASS.b * 0.5)
	expect_color(pixel_at(img, 100, 300), dimmed, "the field is dimmed")
	# Bottom-left corner of the pause dialog (4 buttons: 400 px tall).
	expect_color(pixel_at(img, 350, 490), Palette.PANEL, "the dialog's panel", 0.05)
