extends TestCase
## Tower branches: after level 3 every tower forks into one of two towers
## (Minigun or Sniper, Swarm or Seeker, ...), each with two more levels.


func level(money: int = 100_000) -> LevelDef:
	var l := LevelDef.new()
	l.id = "test"
	l.name = "Test"
	l.tiles = Levels.by_id("meadow").tiles
	l.money = money
	l.lives = 20
	l.hp_scale = 1.0
	var waves: Array[Wave] = [Wave.new([SpawnGroup.new("scout", 3, 1.0, 0.0)])]
	l.waves = waves
	return l


func run(w: World, ticks: int) -> void:
	for i: int in ticks:
		w.update()


## A tower at level 3 with the given branch chosen (level 4).
func branched(w: World, kind: String, branch: String, col: int, row: int, extra_levels: int = 0) -> Tower:
	var t: Tower = w.build(kind, col, row)
	w.upgrade(t)
	w.upgrade(t)
	expect_true(w.choose_branch(t, branch), "chose %s" % branch)
	for i: int in extra_levels:
		w.upgrade(t)
	return t


## An enemy that stays where it is put (it is frozen with a full slow).
func enemy_at(w: World, type: String, x: float, y: float) -> Enemy:
	var e: Enemy = w.spawn(type)
	e.apply_slow(1.0, 1_000_000)
	e.nav.x = x
	e.nav.y = y
	e.x = x
	e.y = y
	e.prev_x = x
	e.prev_y = y
	return e


## A flyer that hovers at a spot: its route is replaced by one that ends far away.
func flyer_at(w: World, x: float, y: float) -> Enemy:
	var e: Enemy = w.spawn("drone")
	e.nav = StillNav.new(x, y)
	e.x = x
	e.y = y
	e.prev_x = x
	e.prev_y = y
	return e


class StillNav:
	extends Nav

	func _init(p_x: float, p_y: float) -> void:
		x = p_x
		y = p_y

	func move(_step: float) -> bool:
		return true

	func remaining() -> float:
		return 1000.0

	func fall_back(_dist: float) -> void:
		pass

	func clone(_lane_seed: int) -> Nav:
		return StillNav.new(x, y)


func lost(e: Enemy) -> float:
	return e.max_hitpoints - e.hitpoints


# ---- the data ------------------------------------------------------------------------

func test_every_tower_forks_into_two_branches_with_two_levels_each() -> void:
	var seen: Dictionary[String, bool] = {}
	for kind: String in Towers.KINDS:
		var d: TowerDef = Towers.get_def(kind)
		expect_eq(d.branches.size(), 2, kind)
		for b: TowerBranch in d.branches:
			expect_false(seen.has(b.id), "branch id %s is unique" % b.id)
			seen[b.id] = true
			expect_eq(b.kind, kind)
			expect_eq(b.levels.size(), 2, b.id)
			expect_false(b.name.is_empty(), b.id)
			expect_false(b.description.is_empty(), b.id)
			expect_true(Towers.is_branch(b.id))
			expect_true(Towers.get_branch(b.id) == b)
			for l: TowerLevel in b.levels:
				expect_gt(l.cost, 0, b.id)
	expect_eq(seen.size(), Towers.BRANCH_IDS.size())
	for id: String in Towers.BRANCH_IDS:
		expect_true(seen.has(id), id)
	expect_false(Towers.is_branch("gun"))


func test_the_base_levels_are_unchanged() -> void:
	# Branches are new content: levels 1-3 stay as they were (the balance and
	# the simulated players depend on them).
	var gun: TowerDef = Towers.get_def("gun")
	expect_eq(gun.levels.size(), 3)
	expect_eq(gun.levels[2].damage, 8.0)
	expect_eq(Towers.get_def("laser").levels[2].max_heat, Tower.LASER_MAX_HEAT)


# ---- choosing a branch ---------------------------------------------------------------

func test_a_level_3_tower_must_choose_a_branch_to_grow() -> void:
	var w := World.new(level())
	var t: Tower = w.build("gun", 0, 0)
	expect_false(t.needs_branch())
	expect_false(w.choose_branch(t, "minigun"), "too early")
	w.upgrade(t)
	w.upgrade(t)
	expect_true(t.needs_branch())
	expect_false(t.is_max_level(), "it can still grow")
	expect_eq(w.upgrade_cost_of(t), Tower.NO_UPGRADE, "a plain upgrade isn't possible")
	expect_false(w.upgrade(t))
	expect_eq(t.level, 2)


func test_choosing_a_branch_pays_for_level_4_and_changes_the_tower() -> void:
	var w := World.new(level())
	var t: Tower = w.build("gun", 0, 0)
	w.upgrade(t)
	w.upgrade(t)
	var money: int = w.money
	var invested: int = t.invested
	var price: int = w.branch_cost_of(t, "sniper")
	expect_eq(price, Towers.get_branch("sniper").levels[0].cost)
	w.events.clear()
	expect_true(w.choose_branch(t, "sniper"))
	expect_eq(w.money, money - price)
	expect_eq(t.invested, invested + price)
	expect_eq(t.level, 3)
	expect_eq(t.branch_id, "sniper")
	expect_eq(t.display_name, "Sniper")
	expect_true(t.stats == Towers.get_branch("sniper").levels[0])
	expect_near(t.attack_range, Towers.get_branch("sniper").levels[0].attack_range)
	expect_false(t.needs_branch())
	expect_eq(w.events.size(), 1)
	expect_eq(w.events[0].type, WorldEvent.Type.UPGRADE)
	expect_eq(w.events[0].kind, "sniper")
	# One more level, then it is done.
	expect_eq(w.upgrade_cost_of(t), Towers.get_branch("sniper").levels[1].cost)
	expect_true(w.upgrade(t))
	expect_eq(t.level, 4)
	expect_true(t.stats == Towers.get_branch("sniper").levels[1])
	expect_true(t.is_max_level())
	expect_false(w.upgrade(t))
	expect_false(w.choose_branch(t, "minigun"), "the branch is chosen for good")


func test_branches_are_refused_when_locked_unaffordable_or_of_another_tower() -> void:
	var w := World.new(level())
	var t: Tower = w.build("gun", 0, 0)
	w.upgrade(t)
	w.upgrade(t)
	expect_false(w.choose_branch(t, "mortar"), "a cannon branch")
	expect_false(w.choose_branch(t, "nonsense"))
	expect_eq(w.branch_cost_of(t, "mortar"), Tower.NO_UPGRADE)
	w.locked_branches["minigun"] = true
	expect_false(w.is_branch_unlocked("minigun"))
	expect_false(w.choose_branch(t, "minigun"), "locked")
	w.money = w.branch_cost_of(t, "sniper") - 1
	expect_false(w.choose_branch(t, "sniper"), "too expensive")
	w.money += 1
	expect_true(w.choose_branch(t, "sniper"))


func test_branch_prices_get_the_engineering_discount_and_selling_refunds_them() -> void:
	var mods := Perks.Modifiers.new()
	mods.cost_multiplier = 0.9
	var w := World.new(level(), Callable(), mods)
	var t: Tower = w.build("cannon", 0, 0)
	w.upgrade(t)
	w.upgrade(t)
	expect_eq(w.branch_cost_of(t, "mortar"), MathX.js_round(Towers.get_branch("mortar").levels[0].cost * 0.9))
	w.choose_branch(t, "mortar")
	w.upgrade(t)
	var before: int = w.money
	w.sell(t)
	expect_eq(w.money - before, floori(t.invested * Config.SELL_REFUND))


func test_a_branched_tower_is_saved_and_restored() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "laser", "lance", 0, 0, 1)
	t.target_mode = Towers.TargetMode.STRONGEST
	var snap: WorldSnapshot = WorldSnapshot.from_dict(JSON.parse_string(JSON.stringify(w.snapshot().to_dict())))
	expect_not_null(snap)
	var w2 := World.new(level())
	w2.restore(snap)
	expect_eq(w2.towers.size(), 1)
	var r: Tower = w2.towers[0]
	expect_eq(r.branch_id, "lance")
	expect_eq(r.level, 4)
	expect_eq(r.invested, t.invested)
	expect_eq(r.target_mode, Towers.TargetMode.STRONGEST)
	expect_true(r.stats == t.stats)


func test_a_save_with_a_bad_branch_falls_back_to_level_3() -> void:
	var w := World.new(level())
	branched(w, "gun", "minigun", 0, 0, 1)
	var d: Dictionary = w.snapshot().to_dict()
	var towers: Array = d["towers"]
	var saved: Dictionary = towers[0]
	saved["branch"] = "mortar" # another tower's branch
	var w2 := World.new(level())
	w2.restore(WorldSnapshot.from_dict(d))
	expect_eq(w2.towers[0].branch_id, "")
	expect_eq(w2.towers[0].level, 2)
	saved.erase("branch")
	saved["level"] = 4 # no branch: at most level 3
	var w3 := World.new(level())
	w3.restore(WorldSnapshot.from_dict(d))
	expect_eq(w3.towers[0].level, 2)


# ---- what each branch does ---------------------------------------------------------------

func test_minigun_spins_up_while_firing_and_down_when_idle() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "gun", "minigun", 5, 9)
	var e: Enemy = enemy_at(w, "brute", t.x + 60, t.y)
	e.hitpoints = 1e9
	e.max_hitpoints = 1e9
	var slow_rate: float = t.fire_rate
	run(w, 4 * Config.TICK_RATE)
	expect_near(t.spin, 1.0, 2, "fully spun up")
	expect_gt(t.fire_rate, slow_rate * 2.5, "fires much faster once spun up")
	expect_near(t.fire_rate, t.stats.fire_rate, 2)
	w.enemies.clear()
	run(w, 2 * Config.TICK_RATE)
	expect_lt(t.spin, 0.5, "spins down without a target")


func test_sniper_shoots_through_a_line_of_enemies() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "gun", "sniper", 3, 1) # grass, far from the road
	var pierce: int = t.stats.pierce
	expect_gt(pierce, 1)
	var line: Array[Enemy] = []
	for i: int in pierce + 1:
		line.append(enemy_at(w, "tank", t.x + 60 + i * 30, t.y))
	var off: Enemy = enemy_at(w, "tank", t.x + 90, t.y + 60)
	t.target_mode = Towers.TargetMode.CLOSEST
	w.events.clear()
	run(w, 1)
	var rails: int = 0
	for ev: WorldEvent in w.events:
		if ev.type == WorldEvent.Type.RAIL:
			rails += 1
			expect_near(ev.x, t.x, 0)
			expect_gt(ev.x2, line[pierce - 1].x - 1, "the tracer reaches the last enemy hit")
	expect_eq(rails, 1)
	for i: int in pierce:
		expect_near(lost(line[i]), t.stats.damage, 2, "enemy %d in the line is hit" % i)
	expect_eq(lost(line[pierce]), 0.0, "only `pierce` enemies are hit")
	expect_eq(lost(off), 0.0, "an enemy beside the line isn't hit")


func test_sniper_hits_flyers() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "gun", "sniper", 3, 1)
	var d: Enemy = flyer_at(w, t.x + 100, t.y)
	run(w, 1)
	expect_gt(lost(d), 0.0)


func test_swarm_fires_a_volley_at_several_targets() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "missile", "swarm", 3, 1)
	var a: Enemy = enemy_at(w, "tank", t.x + 80, t.y)
	var b: Enemy = enemy_at(w, "tank", t.x - 80, t.y)
	var c: Enemy = enemy_at(w, "tank", t.x, t.y + 80)
	run(w, 1)
	expect_eq(w.bullets.size(), t.stats.volley, "one shot fires a volley")
	var targets: Dictionary[Enemy, bool] = {}
	for bullet: Bullet in w.bullets:
		targets[bullet.target] = true
	expect_eq(targets.size(), 3, "the missiles go to different enemies")
	run(w, 3 * Config.TICK_RATE)
	for e: Enemy in [a, b, c]:
		expect_gt(lost(e), 0.0)


func test_seeker_hits_bosses_harder() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "missile", "seeker", 3, 1)
	var boss: Enemy = enemy_at(w, "brute", t.x + 80, t.y)
	run(w, 3 * Config.TICK_RATE)
	expect_gt(lost(boss), 0.0)
	var w2 := World.new(level())
	var t2: Tower = branched(w2, "missile", "seeker", 3, 1)
	var tank: Enemy = enemy_at(w2, "tank", t2.x + 80, t2.y)
	tank.hitpoints = 1e6
	tank.max_hitpoints = 1e6
	run(w2, 3 * Config.TICK_RATE)
	expect_near(lost(boss) / lost(tank), t.stats.boss_bonus, 2, "bosses take the bonus")


func test_mortar_has_a_minimum_range_and_does_not_lead() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "cannon", "mortar", 3, 1)
	expect_gt(t.stats.min_range, 0.0)
	var close: Enemy = enemy_at(w, "tank", t.x + t.stats.min_range - 30, t.y)
	run(w, 2)
	expect_eq(w.bullets.size(), 0, "too close for the mortar")
	expect_null(t.target)
	close.alive = false
	w.enemies.clear()
	# A moving target far away: the shell goes where it is now, not where it will be.
	var far: Enemy = w.spawn("racer")
	far.nav = StillNav.new(t.x + 200, t.y)
	far.x = t.x + 200
	far.y = t.y
	far.vx = 1 # slower than the shell: leading would aim ahead of it
	far.vy = 0
	far.prev_x = far.x - 1
	t.cooldown = 0
	w.bullets.clear()
	t.update(w)
	expect_eq(w.bullets.size(), 1)
	var shell: Bullet = w.bullets[0]
	expect_near(shell.flight, MathX.hypot(far.x - shell.x, far.y - shell.y), 1, "aimed at the target itself")


func test_siege_cannon_ignores_armor() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "cannon", "siege", 3, 1)
	var armored: Enemy = enemy_at(w, "armored", t.x + 80, t.y)
	armored.hitpoints = 1e6
	armored.max_hitpoints = 1e6
	run(w, 2 * Config.TICK_RATE)
	var hits: float = lost(armored) / t.stats.damage
	expect_near(hits, roundf(hits), 2, "every hit does full damage")
	expect_gt(hits, 0.5)


func test_blizzard_slows_hard_but_does_no_damage() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "frost", "blizzard", 3, 1)
	var e: Enemy = w.spawn("tank")
	e.nav = StillNav.new(t.x + 100, t.y)
	e.x = t.x + 100
	e.y = t.y
	run(w, 3 * Config.TICK_RATE)
	expect_near(e.slow, t.stats.slow, 2)
	expect_gt(t.stats.slow, Towers.get_def("frost").levels[2].slow)
	expect_eq(lost(e), 0.0)


func test_cryo_freezes_on_its_pulse_and_chilled_enemies_take_more_damage() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "frost", "cryo", 3, 1)
	var e: Enemy = w.spawn("tank")
	e.hitpoints = 1e6
	e.max_hitpoints = 1e6
	e.nav = StillNav.new(t.x + 60, t.y)
	e.x = t.x + 60
	e.y = t.y
	run(w, 1)
	expect_true(e.is_frozen(), "the first pulse freezes")
	expect_gt(e.vulnerability, 0.0, "and chills")
	var hp: float = e.hitpoints
	w.damage_enemy(e, 100)
	expect_near(hp - e.hitpoints, 100 * (1 + t.stats.vulnerability), 2)
	# A boss stays frozen for a shorter time.
	var boss: Enemy = w.spawn("brute")
	boss.nav = StillNav.new(t.x - 60, t.y)
	boss.x = t.x - 60
	boss.y = t.y
	t.cooldown = 0
	run(w, 1)
	expect_gt(boss.stun_ticks, 0)
	expect_lt(boss.stun_ticks, e.stun_ticks + 1)


func test_frozen_enemies_do_not_move() -> void:
	var w := World.new(level())
	var e: Enemy = w.spawn("scout")
	run(w, 30)
	e.freeze(20)
	var x: float = e.x
	var y: float = e.y
	run(w, 10)
	expect_eq(e.x, x)
	expect_eq(e.y, y)
	run(w, 30)
	expect_gt(MathX.hypot(e.x - x, e.y - y), 1.0, "it walks on once thawed")


func test_prism_burns_several_enemies_at_once() -> void:
	var w := World.new(level())
	var t: Tower = branched(w, "laser", "prism", 3, 1, 1)
	var es: Array[Enemy] = []
	for i: int in 4:
		var e: Enemy = enemy_at(w, "tank", t.x + 50 + i * 20, t.y + 30)
		e.hitpoints = 1e6
		e.max_hitpoints = 1e6
		es.append(e)
	run(w, 30)
	var burning: int = 0
	for e: Enemy in es:
		if lost(e) > 0:
			burning += 1
	expect_eq(burning, t.stats.beams)
	expect_eq(t.targets.size(), t.stats.beams)


func test_lance_heats_faster_and_hotter_than_the_laser() -> void:
	var w := World.new(level())
	var lance: Tower = branched(w, "laser", "lance", 3, 1)
	var plain: Tower = w.build("laser", 3, 13)
	w.upgrade(plain)
	w.upgrade(plain)
	expect_lt(lance.stats.heat_time, plain.stats.heat_time)
	expect_gt(lance.stats.max_heat, plain.stats.max_heat)
	var e: Enemy = enemy_at(w, "brute", lance.x + 60, lance.y)
	e.hitpoints = 1e9
	e.max_hitpoints = 1e9
	run(w, World.ticks_of(lance.stats.heat_time) + 2)
	expect_near(lance.heat_fraction, 1.0, 2)


func test_overclock_and_command_boost_nearby_towers() -> void:
	var w := World.new(level())
	var gun: Tower = w.build("gun", 3, 1)
	var range_before: float = gun.attack_range
	var oc: Tower = branched(w, "support", "overclock", 4, 1)
	run(w, 1)
	expect_near(gun.buff, oc.stats.buff)
	expect_near(gun.attack_range, range_before, 2, "overclock doesn't add range")
	w.sell(oc)
	var cmd: Tower = branched(w, "support", "command", 4, 1)
	run(w, 1)
	expect_near(gun.buff, cmd.stats.buff)
	expect_near(gun.attack_range, range_before * (1 + cmd.stats.range_buff), 2, "command adds range")
	w.sell(cmd)
	run(w, 1)
	expect_near(gun.attack_range, range_before, 2, "the range goes back to normal")


func test_bots_never_branch_so_the_balance_baseline_stays() -> void:
	# The simulated players only call upgrade(): at level 3 that stops.
	var w := World.new(level())
	var t: Tower = w.build("gun", 0, 0)
	while w.upgrade(t):
		pass
	expect_eq(t.level, 2)
