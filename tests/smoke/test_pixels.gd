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
	# The road is plain: the way the enemies will take is not drawn on it.
	for row: int in [10, 11, 12]:
		for col: int in [1, 3, 5]:
			p = tile(col, row)
			expect_color(pixel_at(img, p.x, p.y), Palette.PATH, "the road at %d,%d, without a path drawn on it" % [col, row])
	p = tile(3, 10)
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


func test_walls_and_mines_are_drawn() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_Q)
	await click_tile(3, 3) # grass
	await click_tile(5, 11) # road
	await press_key(KEY_Z)
	await click_tile(8, 11)
	await press_key(KEY_ESCAPE)
	await click(900, 300) # the pointer off the field
	await frames(40) # the puffs of dust from building are gone (they last 0.4 s)
	var img: Image = await screenshot()
	var stone: Color = AbilityArt.STONE
	for tile_pos: Vector2i in [Vector2i(3, 3), Vector2i(5, 11)]:
		var p: Vector2 = tile(tile_pos.x, tile_pos.y)
		expect_color(pixel_at(img, p.x, p.y - 12), stone, "a wall brick at %s" % tile_pos, 0.06)
	var m: Vector2 = tile(8, 11)
	expect_color(pixel_at(img, m.x + 5.5, m.y), Color("#6c757d"), "the body of a mine", 0.06)
	var plain: Vector2 = tile(4, 11)
	expect_color(pixel_at(img, plain.x + 12, plain.y + 12), Palette.PATH, "road next to them is untouched", 0.04)


func test_the_ability_bar_is_drawn_along_the_bottom() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await frames(2)
	var img: Image = await screenshot()
	var r: Rect2 = game.ability_bar.buttons["wall"].get_global_rect()
	expect_color(pixel_at(img, r.end.x - 6, r.get_center().y + 4), Palette.PANEL_LIGHT, "a button", 0.04)
	var strike: Rect2 = game.ability_bar.buttons["strike"].get_global_rect()
	expect_color(pixel_at(img, strike.end.x - 6, strike.get_center().y + 4), Palette.PANEL_LIGHT, "another button", 0.04)
	# The strip between the buttons is the field.
	expect_color(pixel_at(img, 20, 590), Palette.GRASS, "the field beside the bar", 0.05)


func test_a_running_ability_frames_the_field() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await click(900, 300)
	await frames(2)
	var plain: Image = await screenshot()
	var before: Color = pixel_at(plain, 400, 1)
	await press_key(KEY_W)
	await frames(2)
	var framed: Image = await screenshot()
	var after: Color = pixel_at(framed, 400, 1)
	expect_gt(after.b - after.r, before.b - before.r + 0.12, "a blue frame while time slow lasts")


func test_the_airstrike_aim_circle_follows_the_pointer() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_R)
	await hover(300, 300)
	await frames(2)
	var img: Image = await screenshot()
	var inside: Color = pixel_at(img, 360, 300) # tile (9, 7)
	var outside: Color = pixel_at(img, 140, 300) # tile (3, 7): the same grass, 160 px away
	expect_gt(inside.r, outside.r + 0.04, "tinted orange inside the blast radius")
	await press_key(KEY_ESCAPE)
	await hover(310, 300)
	await frames(2)
	img = await screenshot()
	expect_color(pixel_at(img, 360, 300), outside, "gone once put away", 0.03)
