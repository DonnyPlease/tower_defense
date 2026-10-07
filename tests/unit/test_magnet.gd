extends TestCase
## The Magnet: a tower that pulls the enemies' way towards it (on levels where
## they re-route) and slows them in its field.


func level(tiles: PackedStringArray, maze: bool = false, road_walls: bool = true) -> LevelDef:
	var l := LevelDef.new()
	l.id = "test"
	l.base_id = "test"
	l.name = "Test"
	l.tiles = tiles
	l.maze = maze
	l.road_walls = road_walls
	l.money = 100_000
	l.lives = 50
	l.hp_scale = 1.0
	var waves: Array[Wave] = [Wave.new([SpawnGroup.new("scout", 1, 1.0, 0.0)])]
	l.waves = waves
	return l


func open_field() -> LevelDef:
	return level(Levels.by_id("openfield").tiles, true, false)


## Tiles of the way from the first entrance to the exit.
func path_of(w: World) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cur: Vector2i = w.map.starts[0]
	var dir: Vector2i = GameMap.NO_TILE
	while cur != GameMap.NO_TILE and out.size() < 400:
		out.append(cur)
		var next: Vector2i = GameMap.next_tile(w.distance_field, cur, dir)
		if next != GameMap.NO_TILE:
			dir = next - cur
		cur = next
	return out


func distance_to(path: Array[Vector2i], p: Vector2) -> float:
	var best: float = INF
	for t: Vector2i in path:
		best = minf(best, GameMap.tile_center(t).distance_to(p))
	return best


func test_the_magnet_is_a_tower_with_two_branches() -> void:
	expect_true(Towers.KINDS.has("magnet"))
	var d: TowerDef = Towers.get_def("magnet")
	expect_true(d.pulls)
	expect_eq(d.branches.size(), 2)
	expect_true(Tech.is_node("magnet"))


func test_without_magnets_the_way_is_the_shortest_one() -> void:
	# The weighted field is only used when a magnet stands: otherwise the
	# field is the plain one (and enemies, previews and players agree).
	var w := World.new(open_field())
	expect_eq(w.distance_field, w.map.distance_field())


func test_a_magnet_bends_the_way_towards_it() -> void:
	var w := World.new(open_field())
	var before: Array[Vector2i] = path_of(w)
	var spot := Vector2i(10, 12) # well below the straight way across
	var magnet_at: Vector2 = GameMap.tile_center(spot)
	var far: float = distance_to(before, magnet_at)
	expect_gt(far, 100.0, "the straight way passes far from the magnet")
	expect_not_null(w.build("magnet", spot.x, spot.y))
	var after: Array[Vector2i] = path_of(w)
	expect_lt(distance_to(after, magnet_at), Towers.get_def("magnet").levels[0].attack_range, "the way now passes through its field")
	expect_ne(after, before, "another way")
	# Selling it puts the way back.
	w.sell(w.towers[0])
	expect_eq(path_of(w), before)


func test_enemies_really_walk_to_the_magnet() -> void:
	var w := World.new(open_field())
	var spot := Vector2i(10, 11)
	var t: Tower = w.build("magnet", spot.x, spot.y)
	var e: Enemy = w.spawn("tank")
	e.hitpoints = 1e9
	e.max_hitpoints = 1e9
	var closest: float = INF
	for i: int in 3000:
		w.update()
		closest = minf(closest, MathX.hypot(e.x - t.x, e.y - t.y))
		if not e.alive:
			break
	expect_lt(closest, t.attack_range, "it walked through the field")
	expect_true(e.escaped, "and still got out")


func test_the_magnet_slows_what_is_in_its_field_but_never_flyers() -> void:
	var w := World.new(open_field())
	var t: Tower = w.build("magnet", 10, 11)
	var e: Enemy = w.spawn("scout")
	e.nav.x = t.x + 30
	e.nav.y = t.y
	e.x = t.x + 30
	e.y = t.y
	t.update(w)
	expect_near(e.slow, t.stats.slow)
	var d: Enemy = w.spawn("drone")
	d.x = t.x
	d.y = t.y
	t.update(w)
	expect_eq(d.slow, 0.0)


func test_remaining_distance_stays_in_pixels_with_a_magnet() -> void:
	var w := World.new(open_field())
	var e: Enemy = w.spawn("scout")
	var plain: float = e.remaining
	w.build("magnet", 18, 1)
	var with_magnet: float = e.nav.remaining()
	expect_lt(absf(with_magnet - plain), Config.TILE * 6.0, "a magnet in a corner hardly changes the way, so the distance stays about the same")


func test_hoppers_ignore_magnets() -> void:
	var w := World.new(open_field())
	var h: Enemy = w.spawn("hopper")
	var before: float = h.nav.remaining()
	w.build("magnet", 10, 11)
	expect_near(h.nav.remaining(), before, 0, "its way is unchanged")


func test_tesla_shocks_and_vortex_pulls_harder() -> void:
	var w := World.new(open_field())
	var tesla: Tower = w.build("magnet", 10, 11)
	w.upgrade(tesla)
	w.upgrade(tesla)
	expect_true(w.choose_branch(tesla, "tesla"))
	var e: Enemy = w.spawn("tank")
	e.nav.x = tesla.x + 30
	e.nav.y = tesla.y
	e.x = tesla.x + 30
	e.y = tesla.y
	tesla.cooldown = 0
	tesla.update(w)
	expect_gt(e.max_hitpoints - e.hitpoints, 0.0, "shocked")
	var v: TowerBranch = Towers.get_branch("vortex")
	expect_gt(v.levels[0].attack_range, Towers.get_def("magnet").levels[2].attack_range)
	expect_gt(v.levels[0].slow, Towers.get_def("magnet").levels[2].slow)
