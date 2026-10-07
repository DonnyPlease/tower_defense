extends TestCase
## The simulation: building, enemies, towers, waves, economy, mazes, saving.

var meadow: LevelDef = Levels.by_id("meadow")
var field: LevelDef = Levels.by_id("openfield")


func run(w: World, ticks: int) -> void:
	for i: int in ticks:
		w.update()


func count_type(w: World, type: String) -> int:
	var n: int = 0
	for e: Enemy in w.enemies:
		if e.type == type:
			n += 1
	return n


# ---- building, upgrading, selling -----------------------------------------------

func test_builds_on_grass_and_charges_the_cost() -> void:
	var w := World.new(meadow)
	expect_not_null(w.build("missile", 0, 0))
	expect_eq(w.money, meadow.money - Towers.get_def("missile").levels[0].cost)


func test_refuses_roads_occupied_tiles_locked_and_unaffordable_towers() -> void:
	var w := World.new(meadow, Callable(), null, ["gun", "missile"])
	expect_null(w.build("missile", 0, 10), "road")
	w.build("missile", 0, 0)
	expect_null(w.build("gun", 0, 0), "occupied")
	expect_null(w.build("laser", 1, 0), "locked")
	w.money = 10
	expect_null(w.build("gun", 1, 0), "too expensive")


func test_upgrades_up_to_level_3_and_refunds_part_of_everything_invested() -> void:
	var w := World.new(meadow)
	w.money = 10_000
	var t: Tower = w.build("gun", 0, 0)
	expect_true(w.upgrade(t))
	expect_true(w.upgrade(t))
	expect_false(w.upgrade(t), "max level")
	expect_eq(t.level, 2)
	var invested: int = 0
	for l: TowerLevel in Towers.get_def("gun").levels:
		invested += l.cost
	var before: int = w.money
	w.sell(t)
	expect_eq(w.money - before, floori(invested * Config.SELL_REFUND))


func test_applies_perk_modifiers() -> void:
	var ranks: Dictionary[String, int] = {"capital": 2, "fortify": 1, "engineering": 1, "firepower": 0}
	var w := World.new(meadow, Callable(), Perks.modifiers_from(ranks))
	expect_eq(w.money, meadow.money + 80)
	expect_eq(w.lives, meadow.lives + 5)
	expect_eq(w.cost_of("gun"), MathX.js_round(100 * 0.94))


# ---- enemies ------------------------------------------------------------------------

func test_armor_reduces_weak_hits_lasers_ignore_it() -> void:
	var w := World.new(meadow)
	var e: Enemy = w.spawn("armored")
	var hp: float = e.hitpoints
	e.hit(3)
	expect_near(hp - e.hitpoints, 0.75) # 25 % minimum
	e.hit(10, true)
	expect_near(hp - e.hitpoints, 10.75)


func test_shields_absorb_damage_first_and_recharge() -> void:
	var w := World.new(meadow)
	var e: Enemy = w.spawn("shielded")
	e.hit(10)
	expect_eq(e.hitpoints, e.max_hitpoints)
	expect_eq(e.shield, e.max_shield - 10)
	run(w, 6 * Config.TICK_RATE)
	expect_eq(e.shield, e.max_shield)


func test_frost_slows_ground_enemies_but_not_drones() -> void:
	var w := World.new(meadow)
	var e: Enemy = w.spawn("scout")
	var d: Enemy = w.spawn("drone")
	e.apply_slow(0.5, 10)
	d.apply_slow(0.5, 10)
	expect_near(e.speed, e.def.speed * 0.5)
	expect_near(d.speed, d.def.speed)


func test_splitters_split_into_minis() -> void:
	var w := World.new(meadow)
	w.money = 10_000
	var e: Enemy = w.spawn("splitter")
	run(w, 60) # walk onto the map
	e.hitpoints = 1
	w.build("gun", 3, 9)
	w.build("gun", 3, 13)
	var i: int = 0
	while i < 600 and e.alive:
		w.update()
		i += 1
	expect_false(e.alive)
	var killed: bool = w.events.any(func(ev: WorldEvent) -> bool:
		return ev.type == WorldEvent.Type.KILL and ev.enemy == "splitter")
	expect_true(killed)
	expect_ge(count_type(w, "mini") + w.kills - 1, 3)


func test_medics_heal_nearby_enemies() -> void:
	var w := World.new(meadow)
	var m: Enemy = w.spawn("healer")
	var s: Enemy = w.spawn("scout")
	s.hitpoints = 5
	run(w, 2 * Config.TICK_RATE)
	expect_gt(s.hitpoints, 5)
	expect_true(m.alive)


func test_the_boss_summons_reinforcements() -> void:
	var w := World.new(meadow)
	w.spawn("boss")
	run(w, 8 * Config.TICK_RATE)
	expect_ge(count_type(w, "scout"), 2)


func test_drones_fly_straight_to_the_exit() -> void:
	var w := World.new(meadow)
	var d: Enemy = w.spawn("drone")
	run(w, 30)
	# The flight route is much shorter than the road.
	expect_lt(d.remaining, w.map.routes[0].length - 100)
	var i: int = 0
	while i < 2000 and d.alive:
		w.update()
		i += 1
	expect_true(d.escaped)


func test_escaping_enemies_cost_lives() -> void:
	var w := World.new(meadow)
	w.spawn("tank")
	var i: int = 0
	while i < 5000 and not w.enemies.is_empty():
		w.update()
		i += 1
	expect_eq(w.lives, meadow.lives - 3)


# ---- towers in action ---------------------------------------------------------------

func test_cannon_shells_hit_every_ground_enemy_in_the_splash() -> void:
	var w := World.new(meadow)
	w.money = 10_000
	var a: Enemy = w.spawn("scout")
	var b: Enemy = w.spawn("scout")
	run(w, 90)
	w.build("cannon", 3, 9)
	var i: int = 0
	while i < 400 and a.alive:
		w.update()
		i += 1
	expect_true(a.hitpoints < a.max_hitpoints or not a.alive)
	expect_true(b.hitpoints < b.max_hitpoints or not b.alive)


func test_beacons_boost_the_fire_rate_of_nearby_towers() -> void:
	var w := World.new(meadow)
	w.money = 10_000
	var gun: Tower = w.build("gun", 0, 0)
	w.build("support", 1, 0)
	w.update()
	expect_near(gun.fire_rate, gun.stats.fire_rate * 1.2)


func test_lasers_heat_up_on_the_same_target() -> void:
	var w := World.new(meadow)
	w.money = 10_000
	var laser: Tower = w.build("laser", 3, 9)
	var e: Enemy = w.spawn("tank")
	var i: int = 0
	while i < 1000 and laser.target == null:
		w.update()
		i += 1
	run(w, 60)
	expect_true(laser.target == e)
	expect_gt(laser.heat_fraction, 0.4)


# ---- waves and economy ------------------------------------------------------------

func test_pays_the_wave_bonus_plus_interest_when_a_wave_is_cleared() -> void:
	var w := World.new(meadow)
	w.lives = 1000
	w.start_next_wave()
	var before: int = w.money
	var cleared: WorldEvent = null
	var i: int = 0
	while i < 20000 and cleared == null:
		w.update()
		for ev: WorldEvent in w.events:
			if ev.type == WorldEvent.Type.WAVE_CLEARED:
				cleared = ev
		w.events.clear()
		i += 1
	expect_not_null(cleared)
	if cleared != null:
		expect_eq(cleared.bonus, Config.wave_bonus(0))
		expect_eq(w.money, before + Config.wave_bonus(0) + cleared.interest)


func test_pays_an_early_bonus_for_calling_a_wave_while_enemies_remain() -> void:
	var w := World.new(meadow)
	w.start_next_wave()
	expect_false(w.can_start_wave(), "still spawning")
	var i: int = 0
	while i < 20000 and w.is_spawning():
		w.update()
		i += 1
	expect_true(w.can_start_wave())
	var before: int = w.money
	w.start_next_wave()
	expect_eq(w.money - before, Config.early_bonus(1))


func test_endless_mode_never_runs_out_of_waves() -> void:
	var w := World.new(Levels.ENDLESS, Levels.endless_wave)
	expect_eq(w.total_waves(), -1)
	expect_gt(w.wave_at(500).groups.size(), 0)
	expect_true(Levels.endless_wave(9).has_type("boss"))


# ---- maze levels ----------------------------------------------------------------------

func start_distance(w: World) -> int:
	var best: int = GameMap.UNREACHABLE
	for s: Vector2i in w.map.starts:
		best = mini(best, GameMap.dist_at(w.distance_field, s.x, s.y))
	return best


func test_maze_enemies_walk_around_towers() -> void:
	var w := World.new(field)
	var before: int = start_distance(w)
	w.money = 10_000
	for r: int in range(1, 14):
		w.build("missile", 10, r)
	expect_gt(start_distance(w), before)


func test_maze_refuses_a_tower_that_would_cut_off_the_exit() -> void:
	var w := World.new(field)
	w.money = 100_000
	var refused: bool = false
	for r: int in range(1, 14):
		if w.build("missile", 16, r) == null:
			refused = true
	expect_true(refused)
	for s: Vector2i in w.map.starts:
		expect_ne(GameMap.dist_at(w.distance_field, s.x, s.y), GameMap.UNREACHABLE)


# ---- save and resume ---------------------------------------------------------------

func test_round_trips_a_snapshot_between_waves() -> void:
	var w := World.new(meadow)
	w.money = 1000
	var t: Tower = w.build("gun", 0, 0)
	w.upgrade(t)
	t.target_mode = Towers.TargetMode.STRONGEST
	var snap: WorldSnapshot = w.snapshot()
	var copy := World.new(meadow)
	copy.restore(WorldSnapshot.from_dict(JSON.parse_string(JSON.stringify(snap.to_dict()))))
	expect_eq(copy.money, w.money)
	expect_eq(copy.towers.size(), 1)
	var c: Tower = copy.towers[0]
	expect_eq(c.kind, "gun")
	expect_eq(c.level, 1)
	expect_eq(c.target_mode, Towers.TargetMode.STRONGEST)
	expect_eq(c.invested, t.invested)
	expect_true(copy.tower_at(0, 0) == c)


func test_cannot_snapshot_during_a_wave() -> void:
	var w := World.new(meadow)
	w.start_next_wave()
	expect_null(w.snapshot())


func test_ignores_bad_snapshots() -> void:
	expect_null(WorldSnapshot.from_dict(null))
	expect_null(WorldSnapshot.from_dict({"v": 2, "money": 1, "lives": 1, "wave_index": 0, "waves_cleared": 0,
		"level_id": "meadow", "towers": []}))
	var s: WorldSnapshot = WorldSnapshot.from_dict({"v": 1, "money": 5, "lives": 3, "wave_index": 0,
		"waves_cleared": 1, "level_id": "meadow", "towers": [{"kind": "nope", "col": 0, "row": 0}, {"kind": "gun", "col": 1, "row": 0}]})
	expect_eq(s.towers.size(), 1, "unknown towers are skipped")
	var w := World.new(meadow)
	s.towers[0].col = 0
	s.towers[0].row = 10 # the road: not restored
	w.restore(s)
	expect_eq(w.towers.size(), 0)


# ---- the game ends --------------------------------------------------------------

func test_is_lost_when_nothing_is_built() -> void:
	for level: LevelDef in Levels.LEVELS:
		var w := World.new(level)
		var i: int = 0
		while i < 200_000 and w.status == World.Status.PLAYING:
			w.start_next_wave()
			w.update()
			i += 1
		expect_eq(w.status, World.Status.LOST, level.id)


# ---- more world rules ----------------------------------------------------------------

func test_slows_wear_off() -> void:
	var w := World.new(meadow)
	var e: Enemy = w.spawn("scout")
	e.apply_slow(0.5, 3)
	run(w, 3)
	expect_eq(e.slow, 0.0)


func test_ignores_zero_damage_and_hits_on_dead_enemies() -> void:
	var w := World.new(meadow)
	var e: Enemy = w.spawn("scout")
	expect_false(e.hit(0))
	e.hit(1000)
	expect_false(e.hit(5))


func test_refuses_to_sell_a_tower_twice_or_change_anything_after_the_game_ended() -> void:
	var w := World.new(meadow)
	var t: Tower = w.build("missile", 0, 0)
	w.set_target_mode(t, Towers.TargetMode.LAST)
	expect_eq(t.target_mode, Towers.TargetMode.LAST)
	expect_true(w.sell(t))
	expect_false(w.sell(t))
	w.status = World.Status.LOST
	var tick: int = w.tick
	w.update()
	expect_eq(w.tick, tick)
	expect_null(w.build("missile", 0, 0))


func test_counts_the_enemies_still_to_come() -> void:
	var w := World.new(meadow)
	w.start_next_wave()
	expect_eq(w.enemies_remaining(), 8)
	expect_null(w.wave_at(99))


func test_beacons_outside_their_range_give_no_boost() -> void:
	var w := World.new(meadow)
	w.money = 10_000
	var far: Tower = w.build("gun", 19, 14)
	w.build("support", 0, 0)
	w.update()
	expect_eq(far.buff, 0.0)


# ---- more maze rules -----------------------------------------------------------------

func test_maze_refuses_to_build_on_a_tile_an_enemy_is_walking_to() -> void:
	var w := World.new(field)
	w.money = 10_000
	var e: Enemy = w.spawn("scout")
	run(w, 40) # walk onto the map
	var t: Vector2i = e.nav.target_tile()
	expect_eq(w.build_block_reason(t.x, t.y), World.BlockReason.ENEMY)


func test_maze_ignores_drones_when_checking_for_blocked_paths() -> void:
	var w := World.new(field)
	w.spawn("drone")
	run(w, 40)
	expect_eq(w.build_block_reason(3, 3), World.BlockReason.NONE)


func test_splitters_in_a_maze_hand_their_route_to_their_minis() -> void:
	var w := World.new(field)
	w.money = 10_000
	var e: Enemy = w.spawn("splitter")
	run(w, 90)
	e.hitpoints = 1
	w.build("gun", 3, 5)
	w.build("gun", 3, 9)
	var i: int = 0
	while i < 600 and e.alive:
		w.update()
		i += 1
	expect_gt(count_type(w, "mini"), 0)
	i = 0
	while i < 3000 and count_type(w, "mini") > 0:
		w.update()
		i += 1
	expect_eq(count_type(w, "mini"), 0, "they all reached the exit or died")


func test_flow_navigation_reports_the_remaining_distance_even_when_leaving() -> void:
	var w := World.new(field)
	var e: Enemy = w.spawn("racer")
	var start: float = e.remaining
	run(w, 60)
	expect_lt(e.remaining, start)
	var i: int = 0
	while i < 2000 and e.nav.target_tile() != GameMap.NO_TILE:
		w.update()
		i += 1
	expect_lt(e.remaining, 80)


# ---- natural movement ------------------------------------------------------------------

func test_enemies_spread_over_the_road_but_never_leave_it() -> void:
	for level: LevelDef in Levels.LEVELS:
		var w := World.new(level)
		w.money = 0
		var types: Array[String] = ["scout", "racer", "tank", "brute"]
		for i: int in 24:
			w.spawn(types[i % types.size()])
		var lanes: Dictionary[int, bool] = {}
		var off_road: int = 0
		var t: int = 0
		while t < 4000 and not w.enemies.is_empty():
			w.update()
			for e: Enemy in w.enemies:
				var c: int = clampi(floori(e.x / Config.TILE), 0, Config.COLS - 1)
				var r: int = clampi(floori(e.y / Config.TILE), 0, Config.ROWS - 1)
				if not w.map.is_walkable(c, r):
					off_road += 1
					if off_road == 1:
						fail("%s %s at %d,%d is off the road" % [level.name, e.type, e.x, e.y])
				if t == 60:
					lanes[MathX.js_round(e.y)] = true
			t += 1
		expect_eq(off_road, 0, level.name)
		if level.id == "meadow" or level.maze:
			expect_gt(lanes.size(), 4, level.name + ": not single file")


func test_walks_at_its_speed_and_turns_smoothly() -> void:
	for level: LevelDef in Levels.LEVELS:
		var w := World.new(level)
		var e: Enemy = w.spawn("scout")
		var prev: float = e.angle
		var too_fast: int = 0
		var too_sharp: int = 0
		var t: int = 0
		while t < 3000 and e.alive:
			w.update()
			if not e.alive:
				break
			if MathX.hypot(e.vx, e.vy) > e.speed * 1.35:
				too_fast += 1
			if absf(MathX.angle_diff(prev, e.angle)) >= 0.3:
				too_sharp += 1
			prev = e.angle
			t += 1
		expect_eq(too_fast, 0, level.name + ": steps longer than the speed allows")
		expect_eq(too_sharp, 0, level.name + ": sharp turns")
		expect_true(e.escaped, level.name)


func test_maze_enemies_go_around_towers_not_through_them() -> void:
	var w := World.new(field)
	w.money = 100_000
	for r: int in range(1, 13):
		if r != 3:
			w.build("gun", 3, r)
	for r: int in range(1, 13):
		if r != 11:
			w.build("gun", 10, r)
	for i: int in 12:
		w.spawn("tank" if i % 2 == 1 else "racer")
	var inside: int = 0
	var t: int = 0
	while t < 6000 and not w.enemies.is_empty():
		w.update()
		for e: Enemy in w.enemies:
			if w.tower_at(floori(e.x / Config.TILE), floori(e.y / Config.TILE)) != null:
				inside += 1
		t += 1
	expect_eq(inside, 0)
	expect_eq(w.enemies.size(), 0)


func test_split_children_fan_out_from_their_parent() -> void:
	var w := World.new(meadow)
	var e: Enemy = w.spawn("splitter")
	run(w, 200)
	w.damage_enemy(e, 999)
	var minis: Array[Enemy] = []
	for m: Enemy in w.enemies:
		if m.type == "mini":
			minis.append(m)
	run(w, 60)
	expect_eq(minis.size(), 3)
	var spots: Dictionary[String, bool] = {}
	for m: Enemy in minis:
		spots["%d,%d" % [MathX.js_round(m.x), MathX.js_round(m.y)]] = true
	expect_eq(spots.size(), 3)
