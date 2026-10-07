extends TestCase
## Map parsing, terrain, pathfinding and smooth routes.

var meadow := GameMap.new("Meadow", Levels.by_id("meadow").tiles)


func map_of(id: String) -> GameMap:
	var level: LevelDef = Levels.by_id(id)
	return GameMap.new(level.name, level.tiles, level.maze, level.road_walls)


func blank() -> PackedStringArray:
	var tiles := PackedStringArray()
	for r: int in Config.ROWS:
		tiles.append(".".repeat(Config.COLS))
	return tiles


func test_every_level_parses_and_has_a_route_for_every_start_exit_pair() -> void:
	for level: LevelDef in Levels.LEVELS:
		var map: GameMap = map_of(level.id)
		expect_eq(map.error, "", level.id)
		expect_eq(map.routes.size(), map.starts.size() * map.ends.size(), level.id)
		expect_eq(map.flight_routes.size(), map.routes.size(), level.id)


func test_routes_start_and_end_one_tile_outside_the_field() -> void:
	for route: Route in meadow.routes:
		expect_eq(route.px[0], -Config.TILE / 2.0)
		expect_eq(route.px[route.point_count() - 1], Config.COLS * Config.TILE + Config.TILE / 2.0)


func test_finds_a_connected_path_over_walkable_tiles() -> void:
	var tiles: PackedVector2Array = meadow.find_path(Vector2i(0, 11), Vector2i(19, 6))
	expect_gt(tiles.size(), 1)
	for i: int in range(1, tiles.size()):
		var a := Vector2i(tiles[i - 1])
		var b := Vector2i(tiles[i])
		expect_eq(absi(a.x - b.x) + absi(a.y - b.y), 1)
		expect_true(meadow.is_walkable(b.x, b.y))


func test_routes_are_smooth_no_sharp_corners_anywhere() -> void:
	for level: LevelDef in Levels.LEVELS:
		var map: GameMap = map_of(level.id)
		var all: Array[Route] = map.routes.duplicate()
		all.append_array(map.flight_routes)
		var sharp: int = 0
		for route: Route in all:
			for i: int in range(1, route.point_count() - 1):
				var a1: float = atan2(route.py[i] - route.py[i - 1], route.px[i] - route.px[i - 1])
				var a2: float = atan2(route.py[i + 1] - route.py[i], route.px[i + 1] - route.px[i])
				if absf(MathX.angle_diff(a1, a2)) >= 0.5:
					sharp += 1
		expect_eq(sharp, 0, level.id)


func test_keeps_to_the_middle_of_wide_roads_and_knows_how_much_room_there_is() -> void:
	# Meadow's first straight is 3 tiles wide (rows 10-12), with room on both sides.
	var route: Route = meadow.routes[0]
	var i: int = first_index_at_or_after(route, 2 * Config.TILE)
	expect_gt(route.py[i], 10 * Config.TILE + 14)
	expect_lt(route.py[i], 13 * Config.TILE - 14)
	expect_gt(route.left[i], Config.TILE / 2.0)
	expect_gt(route.right[i], Config.TILE / 2.0)
	# Riverside's roads are one tile wide: hardly any room to the sides.
	var river: Route = map_of("riverside").routes[0]
	var j: int = first_index_at_or_after(river, 2 * Config.TILE)
	expect_lt(river.left[j], 10)
	expect_lt(river.right[j], 10)


func first_index_at_or_after(route: Route, x: float) -> int:
	for i: int in route.point_count():
		if route.px[i] >= x:
			return i
	return -1


func test_understands_terrain() -> void:
	var river: GameMap = map_of("riverside")
	expect_eq(river.terrain_at(9, 0), GameMap.Terrain.WATER)
	expect_false(river.is_buildable_terrain(9, 0))
	expect_eq(river.terrain_at(9, 7), GameMap.Terrain.BRIDGE)
	expect_true(river.is_walkable(9, 7))
	var high: GameMap = map_of("highlands")
	expect_true(high.is_high_ground(2, 3))
	expect_true(high.is_buildable_terrain(2, 3))
	expect_eq(high.terrain_at(12, 2), GameMap.Terrain.ROCK)
	expect_eq(high.terrain_at(-1, 0), GameMap.Terrain.NONE)


func test_lets_enemies_walk_on_grass_only_in_maze_levels() -> void:
	expect_false(meadow.is_walkable(0, 0))
	var open: GameMap = map_of("openfield")
	expect_true(open.is_walkable(1, 1))
	expect_false(open.is_walkable(6, 1), "rock")


func test_rejects_broken_maps() -> void:
	var tiles: PackedStringArray = blank()
	tiles[0] = "S" + ".".repeat(Config.COLS - 2) + "E"
	expect_contains(GameMap.new("no path", tiles).error, "no path")
	tiles[0] = "S" + "X".repeat(Config.COLS - 2) + "E"
	expect_contains(GameMap.new("bad tile", tiles).error, "unknown tile")


func test_tile_center_is_the_middle_of_the_tile() -> void:
	expect_eq(GameMap.tile_center(Vector2i(2, 3)), Vector2(2 * Config.TILE + Config.TILE / 2.0, 3 * Config.TILE + Config.TILE / 2.0))


func test_rejects_maps_of_the_wrong_size() -> void:
	expect_contains(GameMap.new("small", PackedStringArray(["S..E"])).error, "must be 20x15")


func test_rejects_maps_without_an_entrance_or_exit() -> void:
	var tiles: PackedStringArray = blank()
	tiles[0] = "S" + "#".repeat(Config.COLS - 1)
	expect_contains(GameMap.new("no exit", tiles).error, "at least one S and one E")


func test_points_off_the_map_from_every_border() -> void:
	var tiles: PackedStringArray = blank()
	tiles[0] = ".S" + ".".repeat(Config.COLS - 2)
	for r: int in range(1, Config.ROWS - 1):
		tiles[r] = ".#" + ".".repeat(Config.COLS - 2)
	tiles[Config.ROWS - 1] = ".E" + ".".repeat(Config.COLS - 2)
	var map := GameMap.new("vertical", tiles)
	expect_eq(map.error, "")
	expect_eq(GameMap.outward(Vector2i(1, 0)), Vector2i(0, -1))
	expect_eq(GameMap.outward(Vector2i(1, Config.ROWS - 1)), Vector2i(0, 1))
	expect_eq(GameMap.outward(Vector2i(Config.COLS - 1, 5)), Vector2i(1, 0))
	expect_eq(GameMap.outward(Vector2i(5, 5)), Vector2i(0, 0))
	expect_lt(map.routes[0].py[0], 0, "enters from above")


func test_next_tile_stops_at_the_exit_and_outside_the_field() -> void:
	var dist: PackedInt32Array = meadow.distance_field()
	expect_eq(GameMap.next_tile(dist, meadow.ends[0], GameMap.NO_TILE), GameMap.NO_TILE)
	expect_eq(GameMap.next_tile(dist, Vector2i(-5, -5), GameMap.NO_TILE), GameMap.NO_TILE)
