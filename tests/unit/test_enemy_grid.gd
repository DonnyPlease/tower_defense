extends TestCase
## The enemy grid: finding the enemies near a point must give exactly what
## looking at every enemy gives (the same enemies, in the same order).


## A world full of enemies spread over the map (and just outside it), some dead.
func crowded_world() -> World:
	var w := World.new(Levels.by_id("highlands"))
	var rand := Mulberry32.new(7)
	var types: Array[String] = ["scout", "tank", "drone", "boss", "racer", "colossus"]
	for i: int in 160:
		var e: Enemy = w.spawn(types[i % types.size()])
		e.x = rand.next() * (Config.FIELD_W + 160) - 80
		e.y = rand.next() * (Config.FIELD_H + 160) - 80
		if i % 9 == 0:
			e.alive = false
	return w


func test_near_finds_every_enemy_in_reach_in_array_order() -> void:
	var w: World = crowded_world()
	var grid := EnemyGrid.new()
	grid.rebuild(w.enemies)
	var rand := Mulberry32.new(3)
	for k: int in 200:
		var x: float = rand.next() * (Config.FIELD_W + 100) - 50
		var y: float = rand.next() * (Config.FIELD_H + 100) - 50
		var reach: float = 20 + rand.next() * 260
		var near: PackedInt32Array = grid.near(x, y, reach)
		for j: int in range(1, near.size()):
			expect_lt(near[j - 1], near[j], "in increasing order, no repeats")
		for i: int in w.enemies.size():
			var e: Enemy = w.enemies[i]
			if MathX.hypot(e.x - x, e.y - y) <= reach + e.radius and not near.has(i):
				fail("enemy %d at %.0f,%.0f is in reach of %.0f,%.0f but not found" % [i, e.x, e.y, x, y])
				return


func test_towers_pick_the_same_targets_from_the_grid() -> void:
	var w: World = crowded_world()
	var grid := EnemyGrid.new()
	grid.rebuild(w.enemies)
	for kind: String in ["gun", "missile", "cannon", "laser"]:
		for mode: Towers.TargetMode in Towers.TARGET_MODES:
			for spot: Vector2i in [Vector2i(0, 0), Vector2i(7, 7), Vector2i(19, 14), Vector2i(12, 3)]:
				var t := Tower.new(kind, spot.x, spot.y)
				t.target_mode = mode
				var near: Array[Enemy] = grid.pick(grid.near(t.x, t.y, t.attack_range))
				var what: String = "%s %s at %s" % [kind, Towers.TARGET_MODE_IDS[mode], spot]
				expect_true(t.pick_target(w.enemies) == t.pick_target(near), what)
				expect_eq(t.pick_targets(w.enemies, 3), t.pick_targets(near, 3), what + " (volley)")


func test_bullets_hit_the_same_enemy_with_the_grid() -> void:
	var w: World = crowded_world()
	var grid := EnemyGrid.new()
	grid.rebuild(w.enemies)
	var rand := Mulberry32.new(11)
	for k: int in 300:
		var b := Bullet.new(rand.next() * Config.FIELD_W, rand.next() * Config.FIELD_H, rand.next() * TAU, 16, 1,
			Towers.BulletType.NORMAL, true, true)
		b.x += cos(b.angle) * b.speed
		b.y += sin(b.angle) * b.speed
		expect_true(b.find_hit(w.enemies) == b.find_hit(w.enemies, grid), "bullet %d" % k)


func test_enemies_added_after_a_rebuild_are_found_where_they_end_up() -> void:
	var w := World.new(Levels.by_id("meadow"))
	var e: Enemy = w.spawn("splitter")
	e.x = 300
	e.y = 300
	var grid := EnemyGrid.new()
	grid.rebuild(w.enemies)
	var child: Enemy = w.spawn("mini")
	grid.add(w.enemies.size() - 1)
	# Moved into place after being added, like a splitter's children.
	child.x = 610
	child.y = 300
	expect_eq(Array(grid.near(305, 300, 30)), [0])
	expect_eq(Array(grid.near(600, 300, 30)), [1])


func test_a_crowded_field_plays_like_a_quiet_one() -> void:
	# Two copies of the same game, one with enough enemies for the grid to be
	# used and one just below; enemies far away don't take part, so the fight
	# near the towers must go exactly the same way.
	var results: Array[String] = []
	for extra: int in [World.GRID_MIN_ENEMIES + 20, World.GRID_MIN_ENEMIES - 40]:
		var w := World.new(Levels.by_id("openfield"))
		w.money = 100_000
		w.lives = 1 << 20
		for spot: Vector2i in [Vector2i(3, 5), Vector2i(3, 9), Vector2i(5, 3), Vector2i(4, 11)]:
			w.build("gun" if spot.y % 2 == 1 else "missile", spot.x, spot.y)
		for i: int in 8:
			w.spawn("scout")
		# Bystanders, frozen far away beyond every tower's reach.
		for i: int in extra:
			var b: Enemy = w.spawn("tank")
			b.apply_slow(1.0, 1 << 20)
			b.max_hitpoints = 1e9
			b.hitpoints = 1e9
			b.nav.x = 760
			b.nav.y = 40
			b.x = 760
			b.y = 40
		for t: int in 600:
			w.update()
			w.events.clear()
		var near_ones: PackedStringArray = []
		for e: Enemy in w.enemies:
			if e.type == "scout":
				near_ones.append("%.3f,%.3f,%.3f" % [e.x, e.y, e.hitpoints])
		results.append("kills=%d money=%d %s" % [w.kills, w.money, ";".join(near_ones)])
	expect_eq(results[0], results[1])
