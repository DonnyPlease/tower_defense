extends TestCase
## Run perks ("field orders"): picked from a few offered at the start of a
## game and after waves 5 and 10, they change how that one game plays.


func level(money: int = 100_000, waves: int = 12) -> LevelDef:
	var l := LevelDef.new()
	l.id = "test"
	l.base_id = "test"
	l.name = "Test"
	l.tiles = Levels.by_id("meadow").tiles
	l.money = money
	l.lives = 20
	l.hp_scale = 1.0
	var list: Array[Wave] = []
	for i: int in waves:
		list.append(Wave.new([SpawnGroup.new("scout", 1, 1.0, 0.0)]))
	l.waves = list
	return l


func run(w: World, ticks: int) -> void:
	for i: int in ticks:
		w.update()


## A world with run perks turned on (and `perks` already taken).
func drafted(perks: Array[String] = [], money: int = 100_000) -> World:
	var w := World.new(level(money))
	for id: String in perks:
		w.add_run_perk(id)
	return w


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


## Clears a wave by killing everything as it spawns.
func clear_wave(w: World) -> void:
	w.start_next_wave()
	for i: int in 600:
		for e: Enemy in w.enemies:
			e.hitpoints = 0.1
		w.update()
		for e: Enemy in w.enemies.duplicate():
			w.damage_enemy(e, 1000)
		if not w.wave_in_progress():
			break


# ---- the data and the draft ----------------------------------------------------------

func test_every_run_perk_has_a_name_and_a_description() -> void:
	expect_ge(RunPerks.IDS.size(), 10)
	for id: String in RunPerks.IDS:
		var d: RunPerks.RunPerkDef = RunPerks.get_def(id)
		expect_false(d.name.is_empty(), id)
		expect_false(d.description.is_empty(), id)


func test_without_orders_there_is_no_draft() -> void:
	var w := World.new(level())
	expect_true(w.perk_offer.is_empty())
	expect_true(w.can_start_wave())


func test_a_game_with_orders_starts_with_an_offer_that_must_be_answered() -> void:
	var w := World.new(level())
	w.enable_drafts(3, 42)
	expect_eq(w.perk_offer.size(), 3)
	var distinct: Dictionary[String, bool] = {}
	for id: String in w.perk_offer:
		distinct[id] = true
		expect_true(RunPerks.is_id(id), id)
	expect_eq(distinct.size(), 3, "three different perks")
	expect_false(w.can_start_wave(), "choose first")
	expect_false(w.choose_run_perk("not-offered"))
	var pick: String = w.perk_offer[1]
	w.events.clear()
	expect_true(w.choose_run_perk(pick))
	expect_eq(w.run_perks, [pick] as Array[String])
	expect_true(w.perk_offer.is_empty())
	expect_true(w.can_start_wave())
	expect_eq(w.events[0].type, WorldEvent.Type.RUN_PERK)


func test_the_same_seed_offers_the_same_perks() -> void:
	var a := World.new(level())
	a.enable_drafts(4, 7)
	var b := World.new(level())
	b.enable_drafts(4, 7)
	expect_eq(a.perk_offer, b.perk_offer)
	var c := World.new(level())
	c.enable_drafts(4, 8)
	expect_ne(a.perk_offer, c.perk_offer, "another seed, another offer (very likely)")


func test_new_offers_come_after_waves_5_and_10_and_never_repeat_a_perk() -> void:
	var w := World.new(level())
	w.enable_drafts(3, 1)
	w.choose_run_perk(w.perk_offer[0])
	for i: int in 4:
		clear_wave(w)
		expect_true(w.perk_offer.is_empty(), "no offer after wave %d" % (i + 1))
	clear_wave(w)
	expect_eq(w.waves_cleared, 5)
	expect_eq(w.perk_offer.size(), 3, "an offer after wave 5")
	expect_false(w.perk_offer.has(w.run_perks[0]), "a perk already taken isn't offered again")
	w.choose_run_perk(w.perk_offer[2])
	for i: int in 5:
		clear_wave(w)
	expect_eq(w.waves_cleared, 10)
	expect_eq(w.perk_offer.size(), 3)
	w.choose_run_perk(w.perk_offer[0])
	expect_eq(w.run_perks.size(), 3)
	clear_wave(w)
	expect_true(w.perk_offer.is_empty(), "three perks per game")


func test_perks_and_a_pending_offer_are_saved() -> void:
	var w := World.new(level())
	w.enable_drafts(3, 5)
	var pick: String = w.perk_offer[0]
	w.choose_run_perk(pick)
	for i: int in 5:
		clear_wave(w)
	var offer: Array[String] = w.perk_offer.duplicate()
	var snap: WorldSnapshot = WorldSnapshot.from_dict(JSON.parse_string(JSON.stringify(w.snapshot().to_dict())))
	var w2 := World.new(level())
	w2.enable_drafts(3, 99)
	w2.restore(snap)
	expect_eq(w2.run_perks, [pick] as Array[String])
	expect_eq(w2.perk_offer, offer, "the same choice is waiting")


# ---- what the perks do --------------------------------------------------------------------

func test_greed_doubles_interest_but_halves_lives() -> void:
	var w := drafted(["greed"], 1000)
	expect_eq(w.lives, 10)
	var plain := drafted([], 1000)
	clear_wave(w)
	clear_wave(plain)
	expect_gt(w.money, plain.money, "more interest")


func test_reinforcements_add_lives() -> void:
	expect_eq(drafted(["reinforcements"]).lives, 30)


func test_free_samples_make_the_first_tower_of_each_kind_free() -> void:
	var w := drafted(["samples"])
	expect_eq(w.cost_of("gun"), 0)
	var money: int = w.money
	var t: Tower = w.build("gun", 0, 0)
	expect_eq(w.money, money)
	expect_eq(t.invested, 0)
	expect_eq(w.cost_of("gun"), Towers.get_def("gun").levels[0].cost, "the second one costs")
	expect_eq(w.cost_of("missile"), 0)
	w.sell(t)
	expect_eq(w.money, money, "a free tower refunds nothing")
	expect_gt(w.cost_of("gun"), 0, "selling doesn't make it free again")


func test_hill_forts_make_towers_on_high_ground_and_walls_cheaper() -> void:
	var w := drafted(["hillforts"])
	var full: int = w.cost_of("gun")
	expect_eq(w.build_cost("gun", 0, 0), full, "on grass: full price")
	w.build_wall(1, 0)
	var money: int = w.money
	w.build("gun", 1, 0)
	expect_eq(money - w.money, MathX.js_round(full * 0.75))


func test_stonework_keeps_every_wall_at_the_base_price() -> void:
	var w := drafted(["stonework"])
	for i: int in 5:
		expect_eq(w.wall_cost(), Abilities.get_def("wall").cost - 5)
		w.build_wall(i, 0)


func test_quick_hands_shortens_cooldowns() -> void:
	var w := drafted(["quickhands"])
	w.use_ability("slow")
	expect_eq(w.cooldown_left("slow"), World.ticks_of(Abilities.get_def("slow").cooldown * 0.6))


func test_headhunter_pays_more_per_kill() -> void:
	var w := drafted(["headhunter"])
	var e: Enemy = w.spawn("scout")
	var money: int = w.money
	w.damage_enemy(e, 1000)
	expect_eq(w.money - money, e.def.reward + 2)


func test_piercing_rounds_go_through_one_more_enemy() -> void:
	var w := drafted(["piercing"])
	var t: Tower = w.build("gun", 3, 1)
	var a: Enemy = enemy_at(w, "tank", t.x + 60, t.y)
	var b: Enemy = enemy_at(w, "tank", t.x + 90, t.y)
	var c: Enemy = enemy_at(w, "tank", t.x + 120, t.y)
	t.target_mode = Towers.TargetMode.CLOSEST
	t.update(w)
	expect_eq(w.bullets.size(), 1)
	for i: int in 40:
		for bullet: Bullet in w.bullets:
			bullet.update(w.enemies)
			if bullet.outcome == Bullet.Outcome.HIT:
				w.damage_enemy(bullet.hit_enemy, bullet.damage)
		w.bullets = w.bullets.filter(func(x: Bullet) -> bool: return x.alive)
	expect_gt(a.max_hitpoints - a.hitpoints, 0.0, "the first enemy is hit")
	expect_gt(b.max_hitpoints - b.hitpoints, 0.0, "the bullet goes on to the second")
	expect_eq(c.max_hitpoints - c.hitpoints, 0.0, "and stops there")


func test_shatter_lets_frost_pulses_break_shields() -> void:
	var w := drafted(["shatter"])
	var t: Tower = w.build("frost", 3, 1)
	var e: Enemy = enemy_at(w, "shielded", t.x + 50, t.y)
	t.update(w)
	expect_lt(e.shield, e.max_shield * 0.6, "half the shield is gone")
	var plain := drafted()
	var t2: Tower = plain.build("frost", 3, 1)
	var e2: Enemy = enemy_at(plain, "shielded", t2.x + 50, t2.y)
	t2.update(plain)
	expect_gt(e2.shield, e2.max_shield * 0.8)


func test_wide_beacons_add_range() -> void:
	var w := drafted(["widebeacons"])
	var gun: Tower = w.build("gun", 3, 1)
	var range_before: float = gun.attack_range
	w.build("support", 4, 1)
	run(w, 1)
	expect_near(gun.attack_range, range_before * (1 + RunPerks.WIDE_BEACON_RANGE))


func test_demolition_widens_cannon_splash() -> void:
	var w := drafted(["demolition"])
	var t: Tower = w.build("cannon", 3, 1)
	enemy_at(w, "tank", t.x + 80, t.y)
	t.update(w)
	expect_eq(w.bullets.size(), 1)
	expect_near(w.bullets[0].splash, t.stats.splash * RunPerks.DEMOLITION_SPLASH)


func test_overcharge_heats_lasers_twice_as_fast() -> void:
	var w := drafted(["overcharge"])
	var t: Tower = w.build("laser", 3, 1)
	var e: Enemy = enemy_at(w, "brute", t.x + 60, t.y)
	e.hitpoints = 1e9
	e.max_hitpoints = 1e9
	run(w, 61)
	expect_near(t.heat_fraction, 1.0, 1, "full heat in half the time")


func test_an_offer_holds_only_perks_not_taken_yet() -> void:
	for seed_value: int in 20:
		var w := World.new(level())
		var left: Array[String] = RunPerks.IDS.duplicate()
		while left.size() > 2:
			var taken: String = left.pop_back()
			w.add_run_perk(taken)
		w.enable_drafts(3, seed_value)
		expect_eq(w.perk_offer.size(), 2, "only two are left (seed %d)" % seed_value)
		for id: String in w.perk_offer:
			expect_true(left.has(id), "%s isn't taken yet (seed %d)" % [id, seed_value])
