extends TestCase
## Walls: obstacles that enemies walk around (never a full block), platforms
## for towers, and the only way to build on the road.

## A road three tiles wide, straight across the map.
const CORRIDOR: PackedStringArray = [
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
	"S##################E",
	"S##################E",
	"S##################E",
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
]

## A road one tile wide.
const LANE: PackedStringArray = [
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
	"S##################E",
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
	"....................",
]


func level(tiles: PackedStringArray, road_walls: bool = true, maze: bool = false) -> LevelDef:
	var l := LevelDef.new()
	l.id = "test"
	l.name = "Test"
	l.tiles = tiles
	l.road_walls = road_walls
	l.maze = maze
	l.money = 1000
	l.lives = 20
	var waves: Array[Wave] = [Wave.new([SpawnGroup.new("scout", 3, 1.0, 0.0)])]
	l.waves = waves
	return l


func run(w: World, ticks: int) -> void:
	for i: int in ticks:
		w.update()


## Steps from the start tile (0, 7) to the exit along the current flow field.
func walk_length(w: World) -> int:
	return GameMap.dist_at(w.distance_field, 0, 7)


# ---- where walls may stand ---------------------------------------------------------

func test_builds_on_grass_and_charges_a_price_that_rises_with_every_wall() -> void:
	var w := World.new(level(CORRIDOR))
	expect_eq(w.wall_cost(), 15)
	expect_true(w.build_wall(3, 3))
	expect_eq(w.money, 1000 - 15)
	expect_eq(w.wall_cost(), 16)
	expect_true(w.build_wall(4, 3))
	expect_eq(w.money, 1000 - 15 - 16)
	expect_true(w.has_wall(3, 3))
	expect_eq(w.walls.size(), 2)


func test_refuses_what_is_not_buildable_taken_or_unaffordable() -> void:
	var w := World.new(level(CORRIDOR))
	var rock: PackedStringArray = CORRIDOR.duplicate()
	rock[2] = "..R................."
	var wr := World.new(level(rock))
	expect_false(wr.build_wall(2, 2), "rock")
	expect_eq(wr.wall_block_reason(2, 2), World.BlockReason.TERRAIN)
	expect_eq(w.wall_block_reason(0, 6), World.BlockReason.TERRAIN, "where enemies enter")
	expect_eq(w.wall_block_reason(19, 7), World.BlockReason.TERRAIN, "where enemies leave")
	expect_true(w.build_wall(3, 3))
	expect_false(w.build_wall(3, 3), "taken by a wall")
	expect_eq(w.wall_block_reason(3, 3), World.BlockReason.OCCUPIED)
	w.build("gun", 5, 3)
	expect_eq(w.wall_block_reason(5, 3), World.BlockReason.OCCUPIED, "a tower is there")
	w.money = 10
	expect_false(w.build_wall(8, 3), "too expensive")
	expect_eq(w.money, 10)


func test_the_road_only_takes_walls_on_levels_with_walls() -> void:
	var with_walls := World.new(level(CORRIDOR, true))
	var without := World.new(level(CORRIDOR, false))
	expect_true(with_walls.map.can_hold_wall(5, 7))
	expect_false(without.map.can_hold_wall(5, 7))
	expect_false(without.build_wall(5, 7))
	expect_eq(without.wall_block_reason(5, 7), World.BlockReason.TERRAIN)
	# Grass is fine on every level.
	expect_true(without.build_wall(5, 3))


func test_walls_on_grass_do_not_change_the_road() -> void:
	var w := World.new(level(CORRIDOR))
	var before: PackedInt32Array = w.distance_field.duplicate()
	w.build_wall(5, 3)
	expect_eq(w.distance_field, before)


# ---- the path ----------------------------------------------------------------------

func test_a_wall_on_a_wide_road_makes_enemies_walk_around_it() -> void:
	var w := World.new(level(CORRIDOR))
	var straight: int = walk_length(w)
	expect_eq(straight, 19)
	# Two walls leave one gap each: the way now has to zigzag.
	expect_true(w.build_wall(5, 6))
	expect_true(w.build_wall(5, 7))
	expect_true(w.build_wall(10, 7))
	expect_true(w.build_wall(10, 8))
	expect_gt(walk_length(w), straight, "the walk got longer")
	expect_eq(GameMap.dist_at(w.distance_field, 5, 6), GameMap.UNREACHABLE, "walls are not walkable")


func test_a_full_block_is_refused() -> void:
	var w := World.new(level(CORRIDOR))
	expect_true(w.build_wall(5, 6))
	expect_true(w.build_wall(5, 7))
	expect_false(w.build_wall(5, 8), "the last gap")
	expect_eq(w.wall_block_reason(5, 8), World.BlockReason.BLOCKS_PATH)
	expect_false(w.has_wall(5, 8))
	expect_lt(walk_length(w), GameMap.UNREACHABLE)


func test_a_wall_in_a_one_tile_road_is_refused() -> void:
	var w := World.new(level(LANE))
	expect_eq(w.wall_block_reason(10, 7), World.BlockReason.BLOCKS_PATH)
	expect_false(w.build_wall(10, 7))
	expect_eq(w.money, 1000)


func test_a_wall_is_refused_where_an_enemy_is() -> void:
	var w := World.new(level(CORRIDOR))
	var e: Enemy = w.spawn("scout")
	run(w, 200)
	var col: int = floori(e.x / Config.TILE)
	var row: int = floori(e.y / Config.TILE)
	expect_eq(w.wall_block_reason(col, row), World.BlockReason.ENEMY)


func test_walls_never_trap_enemies_that_are_already_walking() -> void:
	var w := World.new(level(CORRIDOR))
	for i: int in 6:
		w.spawn("scout")
	run(w, 120)
	# Whatever the player manages to build now, every enemy must still get out.
	for col: int in range(2, 18):
		for row: int in range(6, 9):
			w.build_wall(col, row)
	var steps: int = 0
	while steps < 3000 and not w.enemies.is_empty():
		w.update()
		steps += 1
	expect_true(w.enemies.is_empty(), "everybody reached the exit")
	expect_eq(w.lives, 20 - 6, "and they cost a life each")


func test_enemies_never_step_on_walls() -> void:
	var w := World.new(level(CORRIDOR))
	for tile: Vector2i in [Vector2i(5, 6), Vector2i(5, 7), Vector2i(10, 7), Vector2i(10, 8)]:
		w.build_wall(tile.x, tile.y)
	for i: int in 8:
		w.spawn("scout")
	var inside: int = 0
	var steps: int = 0
	while steps < 3000 and not w.enemies.is_empty():
		w.update()
		for e: Enemy in w.enemies:
			if w.has_wall(floori(e.x / Config.TILE), floori(e.y / Config.TILE)):
				inside += 1
		steps += 1
	expect_eq(inside, 0)


func test_selling_a_wall_opens_the_way_again() -> void:
	var w := World.new(level(CORRIDOR))
	w.build_wall(5, 6)
	w.build_wall(5, 7)
	w.build_wall(10, 7)
	w.build_wall(10, 8)
	var long_way: int = walk_length(w)
	var money: int = w.money
	expect_true(w.sell_wall(5, 7))
	expect_eq(w.money, money + 16, "what it cost")
	expect_lt(walk_length(w), long_way)
	expect_false(w.sell_wall(5, 7), "twice")
	expect_false(w.sell_wall(1, 1), "no wall there")


func test_the_wall_price_follows_the_walls_standing() -> void:
	var w := World.new(level(CORRIDOR))
	w.build_wall(1, 1)
	w.build_wall(2, 1)
	w.build_wall(3, 1)
	expect_eq(w.wall_cost(), 18)
	w.sell_wall(1, 1)
	expect_eq(w.wall_cost(), 17)
	# Selling and buying again can never make money.
	var before: int = w.money
	w.build_wall(1, 1)
	w.sell_wall(1, 1)
	expect_le(w.money, before)


# ---- towers on walls ---------------------------------------------------------------

func test_a_tower_on_the_road_needs_a_wall_under_it() -> void:
	var w := World.new(level(CORRIDOR))
	expect_eq(w.build_block_reason(5, 7), World.BlockReason.NEEDS_WALL)
	expect_null(w.build("gun", 5, 7))
	expect_true(w.build_wall(5, 7))
	expect_eq(w.build_block_reason(5, 7), World.BlockReason.NONE)
	var t: Tower = w.build("gun", 5, 7)
	expect_not_null(t)
	expect_eq(w.build_block_reason(5, 7), World.BlockReason.OCCUPIED)


func test_towers_on_the_road_are_refused_where_the_level_has_no_walls() -> void:
	var w := World.new(level(CORRIDOR, false))
	expect_eq(w.build_block_reason(5, 7), World.BlockReason.TERRAIN)
	expect_null(w.build("gun", 5, 7))


func test_a_tower_on_a_wall_has_the_range_of_high_ground() -> void:
	var w := World.new(level(CORRIDOR))
	var plain: Tower = w.build("gun", 3, 3)
	w.build_wall(6, 3)
	var raised: Tower = w.build("gun", 6, 3)
	expect_false(plain.high_ground)
	expect_true(raised.high_ground)
	expect_near(raised.attack_range, plain.attack_range * Config.HIGH_GROUND_RANGE, 3)


func test_a_wall_on_high_ground_adds_nothing() -> void:
	var tiles: PackedStringArray = CORRIDOR.duplicate()
	tiles[2] = "...H................"
	var w := World.new(level(tiles))
	var on_hill: Tower = w.build("gun", 3, 2)
	w.build_wall(6, 2)
	var on_wall: Tower = w.build("gun", 6, 2)
	expect_near(on_hill.attack_range, on_wall.attack_range, 3, "the bonus is not stacked")


func test_a_wall_with_a_tower_on_it_cannot_be_sold_until_the_tower_is() -> void:
	var w := World.new(level(CORRIDOR))
	w.build_wall(5, 7)
	var t: Tower = w.build("gun", 5, 7)
	expect_false(w.sell_wall(5, 7))
	expect_true(w.sell(t))
	expect_true(w.has_wall(5, 7), "the wall stays")
	expect_true(w.sell_wall(5, 7))


func test_towers_on_walls_do_not_re_plan_the_path() -> void:
	var w := World.new(level(CORRIDOR))
	w.build_wall(5, 6)
	w.build_wall(5, 7)
	var before: PackedInt32Array = w.distance_field.duplicate()
	w.build("gun", 5, 6)
	expect_eq(w.distance_field, before)


func test_in_a_maze_a_wall_is_cheaper_than_a_tower_for_lengthening_the_way() -> void:
	var w := World.new(Levels.by_id("openfield"))
	var cheapest_tower: int = w.cost_of("missile")
	expect_lt(w.wall_cost(), cheapest_tower)
	var before: int = GameMap.dist_at(w.distance_field, w.map.starts[0].x, w.map.starts[0].y)
	expect_true(w.build_wall(8, 7))
	expect_true(w.build_wall(8, 6))
	expect_ge(GameMap.dist_at(w.distance_field, w.map.starts[0].x, w.map.starts[0].y), before)


# ---- saving ----------------------------------------------------------------------

func test_walls_and_towers_on_them_survive_a_save() -> void:
	var w := World.new(level(CORRIDOR))
	w.build_wall(5, 6)
	w.build_wall(5, 7)
	w.build("gun", 5, 7)
	var snap: WorldSnapshot = w.snapshot()
	var parsed: Variant = JSON.parse_string(JSON.stringify(snap.to_dict()))
	var back: WorldSnapshot = WorldSnapshot.from_dict(parsed)
	expect_not_null(back)
	var w2 := World.new(level(CORRIDOR))
	w2.restore(back)
	expect_eq(w2.walls.size(), 2)
	expect_eq(w2.walls[Vector2i(5, 6)], 15)
	expect_eq(w2.walls[Vector2i(5, 7)], 16)
	expect_eq(w2.towers.size(), 1)
	expect_true(w2.towers[0].high_ground)
	expect_eq(w2.distance_field, w.distance_field)
	expect_eq(w2.wall_cost(), 17)


func test_old_saves_without_walls_still_load() -> void:
	var w := World.new(level(CORRIDOR))
	w.build("gun", 3, 3)
	var d: Dictionary = w.snapshot().to_dict()
	for key: String in ["walls", "mines", "cooldowns", "used"]:
		d.erase(key)
	var back: WorldSnapshot = WorldSnapshot.from_dict(JSON.parse_string(JSON.stringify(d)))
	expect_not_null(back)
	var w2 := World.new(level(CORRIDOR))
	w2.restore(back)
	expect_eq(w2.towers.size(), 1)
	expect_eq(w2.walls.size(), 0)


func test_a_saved_wall_on_ground_that_cannot_hold_one_is_dropped() -> void:
	var w := World.new(level(CORRIDOR))
	w.build_wall(5, 7)
	var snap: WorldSnapshot = w.snapshot()
	var w2 := World.new(level(CORRIDOR, false)) # same tiles, but the road takes no walls here
	w2.restore(snap)
	expect_eq(w2.walls.size(), 0)


# ---- the levels --------------------------------------------------------------------

func test_the_levels_with_walls_have_room_for_them_and_the_others_do_not() -> void:
	for level: LevelDef in Levels.LEVELS + [Levels.ENDLESS]:
		var w := World.new(level)
		var spots: int = 0
		for row: int in Config.ROWS:
			for col: int in Config.COLS:
				if w.map.terrain_at(col, row) == GameMap.Terrain.ROAD and w.wall_block_reason(col, row) == World.BlockReason.NONE:
					spots += 1
		if level.road_walls:
			expect_ge(spots, 10, "%s: room for walls on the road" % level.name)
		else:
			expect_eq(spots, 0, "%s: no walls on the road" % level.name)


func test_walls_on_every_road_tile_never_close_the_road() -> void:
	for level: LevelDef in Levels.LEVELS + [Levels.ENDLESS]:
		if not level.road_walls:
			continue
		var w := World.new(level)
		w.money = 1_000_000
		var built: int = 0
		var refused: int = 0
		for row: int in Config.ROWS:
			for col: int in Config.COLS:
				if w.map.terrain_at(col, row) == GameMap.Terrain.ROAD:
					if w.build_wall(col, row):
						built += 1
					else:
						refused += 1
		expect_gt(built, 5, level.name)
		expect_gt(refused, 5, "%s: the road is never closed" % level.name)
		for s: Vector2i in w.map.starts:
			expect_lt(GameMap.dist_at(w.distance_field, s.x, s.y), GameMap.UNREACHABLE, "%s: from %s" % [level.name, s])
		# And enemies really get through.
		for i: int in 4:
			w.spawn("scout")
		var steps: int = 0
		while steps < 6000 and not w.enemies.is_empty():
			w.update()
			steps += 1
		expect_true(w.enemies.is_empty(), "%s: everybody got out" % level.name)
