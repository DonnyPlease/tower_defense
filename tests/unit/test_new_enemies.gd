extends TestCase
## The enemies that make you change your build: the Saboteur (switches towers
## off), the Hopper (jumps over walls and towers), the Warchief (makes the
## enemies around it faster and tougher) and the Colossus (a boss in phases).


func level(tiles: PackedStringArray = Levels.by_id("meadow").tiles, maze: bool = false, road_walls: bool = true) -> LevelDef:
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


func run(w: World, ticks: int) -> void:
	for i: int in ticks:
		w.update()


func enemy_at(w: World, type: String, x: float, y: float, frozen: bool = true) -> Enemy:
	var e: Enemy = w.spawn(type)
	if frozen:
		e.apply_slow(1.0, 1_000_000)
	e.nav.x = x
	e.nav.y = y
	e.x = x
	e.y = y
	e.prev_x = x
	e.prev_y = y
	return e


func test_the_new_enemies_exist_with_descriptions() -> void:
	for type: String in ["saboteur", "hopper", "warchief", "colossus"]:
		expect_true(Enemies.is_type(type), type)
		expect_false(Enemies.get_def(type).description.is_empty(), type)
	expect_true(Enemies.get_def("colossus").boss)


# ---- saboteur ---------------------------------------------------------------------------

func test_a_saboteur_switches_off_the_towers_around_it() -> void:
	var w := World.new(level())
	var near: Tower = w.build("gun", 3, 1)
	var far: Tower = w.build("gun", 15, 1)
	var s: Enemy = enemy_at(w, "saboteur", near.x + 40, near.y)
	s.ability_timer = 1
	w.events.clear()
	run(w, 1)
	expect_true(near.is_disabled(), "the tower next to it is off")
	expect_false(far.is_disabled(), "a tower far away is not")
	var emp: int = 0
	for ev: WorldEvent in w.events:
		if ev.type == WorldEvent.Type.EMP:
			emp += 1
	expect_eq(emp, 1)
	# A disabled tower doesn't shoot.
	s.hitpoints = 1e6
	s.max_hitpoints = 1e6
	w.bullets.clear()
	run(w, 30)
	expect_eq(w.bullets.size(), 0, "no shots while it is off")
	run(w, World.ticks_of(Enemies.get_def("saboteur").emp.duration))
	expect_false(near.is_disabled(), "it comes back on")


func test_a_disabled_beacon_boosts_nobody() -> void:
	var w := World.new(level())
	var gun: Tower = w.build("gun", 3, 1)
	var beacon: Tower = w.build("support", 4, 1)
	run(w, 1)
	expect_gt(gun.buff, 0.0)
	beacon.disable(100)
	run(w, 1)
	expect_eq(gun.buff, 0.0)


# ---- hopper -----------------------------------------------------------------------------

func test_a_hopper_goes_straight_through_a_maze() -> void:
	var field: LevelDef = level(Levels.by_id("openfield").tiles, true, false)
	var w := World.new(field)
	# A wall of towers with a gap at the bottom: walkers detour, hoppers don't.
	for r: int in range(1, 13):
		w.build("gun", 10, r)
	var walker: Enemy = w.spawn("scout")
	var hopper: Enemy = w.spawn("hopper")
	expect_gt(walker.remaining, hopper.remaining + Config.TILE * 4, "the walker's way is much longer")
	hopper.hitpoints = 1e9 # the guns can't stop it
	hopper.max_hitpoints = 1e9
	var jumped: bool = false
	for i: int in 2000:
		w.update()
		if w.tower_at(floori(hopper.x / Config.TILE), floori(hopper.y / Config.TILE)) != null:
			jumped = true
			expect_true(hopper.is_jumping(), "in the air over a tower")
		if not hopper.alive:
			break
	expect_true(hopper.escaped, "it got out")
	expect_true(jumped, "over the towers, not around them")


func test_a_hopper_jumps_while_over_a_wall() -> void:
	var w := World.new(level())
	var h: Enemy = w.spawn("hopper")
	expect_false(h.is_jumping())
	w.build_wall(3, 10)
	expect_eq(w.walls.size(), 1)
	h.x = 3 * Config.TILE + 20
	h.y = 10 * Config.TILE + 20
	expect_true(h.is_jumping(), "over a wall it is in the air")


func test_hoppers_do_not_stop_walls_from_being_built() -> void:
	# Walls may still never close the path for the others; hoppers don't count.
	var w := World.new(level())
	var h: Enemy = w.spawn("hopper")
	h.nav.x = 3 * Config.TILE + 20
	h.nav.y = 11 * Config.TILE + 20
	h.x = h.nav.x
	h.y = h.nav.y
	expect_eq(w.wall_block_reason(3, 11), World.BlockReason.NONE)


# ---- warchief ---------------------------------------------------------------------------

func test_a_warchief_makes_the_enemies_around_it_faster_and_tougher() -> void:
	var w := World.new(level())
	var chief: Enemy = enemy_at(w, "warchief", 200, 420)
	var buddy: Enemy = enemy_at(w, "tank", 230, 420)
	var alone: Enemy = enemy_at(w, "tank", 700, 100)
	run(w, 1)
	expect_true(buddy.rallied, "near the warchief")
	expect_false(alone.rallied)
	expect_false(chief.rallied, "it doesn't rally itself")
	var hp: float = buddy.hitpoints
	w.damage_enemy(buddy, 100)
	expect_near(hp - buddy.hitpoints, 100 * (1 - Enemies.get_def("warchief").rally.toughness), 2)
	expect_gt(buddy.speed_factor(), 1.0)
	w.damage_enemy(chief, 1e6)
	run(w, 1)
	expect_false(buddy.rallied, "the rally ends with the warchief")


# ---- colossus ---------------------------------------------------------------------------

func test_the_colossus_changes_phase_as_it_takes_damage() -> void:
	var w := World.new(level())
	var c: Enemy = enemy_at(w, "colossus", 300, 420, false)
	var def: EnemyDef = c.def
	expect_eq(c.phase, 0)
	expect_eq(c.armor, def.armor)
	w.events.clear()
	w.damage_enemy(c, c.max_hitpoints * 0.4, true)
	expect_eq(c.phase, 1, "below the first threshold")
	expect_eq(c.armor, def.phases[0].armor, "sheds its armor")
	expect_gt(c.speed_factor(), 1.0, "and speeds up")
	var phased: int = 0
	for ev: WorldEvent in w.events:
		if ev.type == WorldEvent.Type.BOSS_PHASE:
			phased += 1
			expect_false(ev.text.is_empty(), "the phase is announced")
	expect_eq(phased, 1)
	var before: int = w.enemies.size()
	w.damage_enemy(c, c.max_hitpoints * 0.3, true)
	expect_eq(c.phase, 2)
	expect_eq(w.enemies.size(), before + def.phases[1].summon_count, "it calls in help")
	expect_gt(c.shield, 0.0, "and raises a shield")
	w.damage_enemy(c, 1, true)
	expect_eq(c.phase, 2, "each phase happens once")


# ---- where they appear ------------------------------------------------------------------

func test_the_citadel_level_brings_them_all() -> void:
	var citadel: LevelDef = Levels.by_id("citadel")
	expect_true(citadel.road_walls)
	var seen: Dictionary[String, bool] = {}
	for wave: Wave in citadel.waves:
		for g: SpawnGroup in wave.groups:
			seen[g.type] = true
	for type: String in ["saboteur", "hopper", "warchief", "colossus"]:
		expect_true(seen.has(type), type)
	expect_true(citadel.waves[citadel.waves.size() - 1].has_type("colossus"), "the Colossus is the final boss")
	var map := GameMap.new(citadel.name, citadel.tiles, citadel.maze, citadel.road_walls)
	expect_eq(map.error, "")


func test_endless_adds_the_new_enemies_on_top_of_the_classic_waves() -> void:
	for i: int in 6:
		expect_eq(Levels.endless_wave(i).groups.size(), Levels.classic_endless_wave(i).groups.size(), "wave %d is classic" % i)
	var types: Dictionary[String, bool] = {}
	for i: int in 40:
		var classic: int = Levels.classic_endless_wave(i).groups.size()
		var wave: Wave = Levels.endless_wave(i)
		expect_ge(wave.groups.size(), classic)
		for g: SpawnGroup in wave.groups:
			types[g.type] = true
	for type: String in ["saboteur", "hopper", "warchief", "colossus"]:
		expect_true(types.has(type), "%s appears in endless" % type)
