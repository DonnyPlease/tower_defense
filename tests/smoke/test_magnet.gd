extends SceneTestCase
## The Magnet in the game: the seventh tower button and key, and the dotted
## path bending towards it when it is built.


func path_tiles(game: GameScene) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cur: Vector2i = game.world.map.starts[0]
	var dir: Vector2i = GameMap.NO_TILE
	while cur != GameMap.NO_TILE and out.size() < 400:
		out.append(cur)
		var next: Vector2i = GameMap.next_tile(game.world.distance_field, cur, dir)
		if next != GameMap.NO_TILE:
			dir = next - cur
		cur = next
	return out


func test_the_magnet_is_the_seventh_tower_and_bends_the_way() -> void:
	use_profile(ALL_STARS, ALL_TECH)
	var game: GameScene = await open_game("openfield")
	if game == null:
		return
	expect_eq(game.hud.tower_buttons.keys(), Towers.KINDS)
	expect_eq(game.hud.tower_buttons["magnet"].hotkey, "7")
	var r: Rect2 = game.hud.tower_buttons["magnet"].get_global_rect()
	expect_le(r.end.y, Hud.PANEL_Y, "the grid ends above the panel")
	var before: Array[Vector2i] = path_tiles(game)
	await press_key(KEY_7)
	expect_eq(game.tool, "magnet")
	expect_eq(game.hud.panel_title_text(), "Magnet  ·  $%d" % game.world.cost_of("magnet"))
	await click_tile(10, 12)
	expect_eq(tower_names(game), ["magnet@10,12"])
	expect_ne(path_tiles(game), before, "the way bends towards the magnet")
