extends TestCase
## The abilities: time slow, damage boost, airstrike, landmine, bounty,
## focus mark, second wind (and the wall, see test_walls.gd).
##
## On Meadow enemies appear just outside the left edge. Tests that need enemies
## at certain spots freeze them (see stationary) and put them there (see place).


func level(hp_scale: float = 1.0) -> LevelDef:
	var l := LevelDef.new()
	l.id = "test"
	l.name = "Test"
	l.tiles = Levels.by_id("meadow").tiles
	l.money = 1000
	l.lives = 20
	l.hp_scale = hp_scale
	var waves: Array[Wave] = [Wave.new([SpawnGroup.new("scout", 3, 1.0, 0.0)]), Wave.new([SpawnGroup.new("scout", 3, 1.0, 0.0)])]
	l.waves = waves
	return l


func run(w: World, ticks: int) -> void:
	for i: int in ticks:
		w.update()


func secs(seconds: float) -> int:
	return World.ticks_of(seconds)


## An enemy that stays where it spawns, so abilities can be aimed at it.
func stationary(w: World, type: String = "tank") -> Enemy:
	var e: Enemy = w.spawn(type)
	e.apply_slow(1.0, 100_000)
	return e


## Puts a frozen ground enemy somewhere.
func place(e: Enemy, x: float, y: float) -> Enemy:
	e.nav.x = x
	e.nav.y = y
	e.x = x
	e.y = y
	e.prev_x = x
	e.prev_y = y
	return e


func damage_taken(e: Enemy) -> float:
	return e.max_hitpoints - e.hitpoints


# ---- the data ---------------------------------------------------------------------

func test_every_ability_has_a_name_a_hotkey_and_sane_numbers() -> void:
	var keys: Dictionary[int, bool] = {}
	for id: String in Abilities.IDS:
		var d: Abilities.AbilityDef = Abilities.get_def(id)
		expect_false(d.name.is_empty(), id)
		expect_false(d.description.is_empty(), id)
		expect_gt(d.cost, 0, id)
		expect_false(keys.has(d.key), "%s: the hotkey is taken" % id)
		keys[d.key] = true
	expect_eq(Abilities.enabled_ids().size(), Abilities.IDS.size())


func test_hotkeys_do_not_clash_with_the_game_keys() -> void:
	var taken: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_U, KEY_S, KEY_T, KEY_F, KEY_P, KEY_M,
		KEY_SPACE, KEY_ESCAPE, KEY_DELETE]
	for id: String in Abilities.IDS:
		expect_false(taken.has(Abilities.get_def(id).key), id)


# ---- paying, cooling down, refusing ------------------------------------------------

func test_using_an_ability_costs_money_and_starts_its_cooldown() -> void:
	var w := World.new(level())
	var cost: int = Abilities.get_def("slow").cost
	expect_eq(w.ability_block("slow"), World.AbilityBlock.NONE)
	expect_true(w.use_ability("slow"))
	expect_eq(w.money, 1000 - cost)
	expect_eq(w.cooldown_left("slow"), secs(45))
	expect_eq(w.ability_block("slow"), World.AbilityBlock.COOLING)
	expect_false(w.use_ability("slow"), "still cooling down")
	expect_eq(w.money, 1000 - cost)
	run(w, secs(45))
	expect_eq(w.cooldown_left("slow"), 0)
	expect_true(w.use_ability("slow"), "ready again")


func test_an_ability_needs_the_money() -> void:
	var w := World.new(level())
	w.money = Abilities.get_def("boost").cost - 1
	expect_eq(w.ability_block("boost"), World.AbilityBlock.MONEY)
	expect_false(w.use_ability("boost"))
	expect_eq(w.cooldown_left("boost"), 0, "nothing was used")


func test_nothing_can_be_used_after_the_game_ended() -> void:
	var w := World.new(level())
	w.lives = 0
	w.spawn("scout")
	run(w, 1)
	expect_eq(w.status, World.Status.LOST)
	expect_eq(w.ability_block("slow"), World.AbilityBlock.GAME_OVER)
	expect_false(w.use_ability("wind"))


func test_abilities_cool_down_independently() -> void:
	var w := World.new(level())
	w.use_ability("slow")
	expect_eq(w.ability_block("boost"), World.AbilityBlock.NONE)
	expect_true(w.use_ability("boost"))


func test_a_tile_ability_is_not_used_through_use_ability() -> void:
	var w := World.new(level())
	expect_false(w.use_ability("mine"))
	expect_false(w.use_ability("wall"))
	expect_eq(w.money, 1000)


# ---- time slow --------------------------------------------------------------------

func test_time_slow_halves_the_speed_of_every_enemy_and_wears_off() -> void:
	var free := World.new(level())
	var slowed := World.new(level())
	var a: Enemy = free.spawn("scout")
	var b: Enemy = slowed.spawn("scout")
	var drone_free: Enemy = free.spawn("drone")
	var drone_slowed: Enemy = slowed.spawn("drone")
	var start: float = a.remaining
	slowed.use_ability("slow")
	run(free, 60)
	run(slowed, 60)
	var walked_free: float = start - a.remaining
	var walked_slowed: float = start - b.remaining
	expect_near(walked_slowed / walked_free, 0.5, 1, "half the distance")
	expect_gt(drone_slowed.remaining, drone_free.remaining, "flyers too")
	# Six seconds after it was used, it is over and they are back at full speed.
	run(slowed, secs(6) - 60)
	expect_false(slowed.is_active("slow"))
	var before: float = b.remaining
	run(slowed, 30)
	expect_near(before - b.remaining, 1.5 * 30, -1, "full speed again")


func test_time_slow_and_frost_do_not_add_up() -> void:
	var w := World.new(level())
	var e: Enemy = w.spawn("scout")
	e.apply_slow(0.3, 600)
	var start: float = e.remaining
	w.use_ability("slow")
	run(w, 30)
	expect_near((start - e.remaining) / 30.0, 1.5 * 0.5, 1, "the stronger slow counts: half speed, not 35%")


# ---- damage boost -----------------------------------------------------------------

func test_the_boost_raises_tower_damage_for_a_while() -> void:
	var w := World.new(level())
	expect_eq(w.damage_multiplier, 1.0)
	w.use_ability("boost")
	w.update()
	expect_near(w.damage_multiplier, 1.5, 3)
	run(w, secs(8))
	expect_eq(w.damage_multiplier, 1.0)
	expect_eq(w.effect_left("boost"), 0)


func test_the_boost_stacks_with_perks() -> void:
	var ranks: Dictionary[String, int] = {"firepower": 2}
	var w := World.new(level(), Callable(), Perks.modifiers_from(ranks))
	expect_near(w.damage_multiplier, 1.16, 3)
	w.use_ability("boost")
	w.update()
	expect_near(w.damage_multiplier, 1.16 * 1.5, 3)


func test_boosted_towers_really_hit_harder() -> void:
	var normal := World.new(level())
	var boosted := World.new(level())
	var targets: Array[Enemy] = []
	for w: World in [normal, boosted]:
		w.build("gun", 1, 9) # right next to where enemies appear
		targets.append(stationary(w))
	boosted.use_ability("boost")
	run(normal, 240)
	run(boosted, 240)
	expect_gt(damage_taken(targets[0]), 0.0)
	expect_gt(damage_taken(targets[1]), damage_taken(targets[0]) * 1.3)


# ---- airstrike --------------------------------------------------------------------

func test_the_airstrike_lands_a_second_later_and_hurts_what_is_around() -> void:
	var w := World.new(level())
	var hit: Enemy = place(stationary(w), 300, 300)
	var spared: Enemy = place(stationary(w), 500, 300)
	var at := Vector2(340, 300) # 40 px from the first, 160 px from the second
	expect_true(w.use_ability("strike", at))
	expect_eq(w.strikes.size(), 1)
	run(w, secs(1) - 2)
	expect_eq(damage_taken(hit), 0.0, "not yet")
	run(w, 3)
	expect_eq(w.strikes.size(), 0)
	expect_gt(damage_taken(hit), 100.0)
	expect_eq(damage_taken(spared), 0.0, "out of the blast")


func test_the_airstrike_hits_flyers() -> void:
	# Flyers can't be frozen: find out where one will be in a second, and aim there.
	var ghost := World.new(level())
	var ghost_drone: Enemy = ghost.spawn("drone")
	run(ghost, secs(1))
	var w := World.new(level())
	var drone: Enemy = w.spawn("drone")
	w.use_ability("strike", Vector2(ghost_drone.x, ghost_drone.y))
	run(w, secs(1) + 1)
	expect_false(drone.alive)


func test_the_airstrike_grows_with_the_waves() -> void:
	var early := World.new(level())
	var late := World.new(level())
	late.wave_index = 9
	var shares: Array[float] = []
	for w: World in [early, late]:
		var boss: Enemy = stationary(w, "boss")
		w.use_ability("strike", Vector2(boss.x, boss.y))
		run(w, secs(1) + 2)
		shares.append(damage_taken(boss) / boss.max_hitpoints)
	expect_gt(shares[0], 0.08)
	expect_near(shares[1], shares[0], 1, "the same share of the hitpoints, however late")


func test_the_airstrike_kills_and_pays() -> void:
	var w := World.new(level())
	var scout: Enemy = stationary(w, "scout")
	var money: int = w.money
	w.use_ability("strike", Vector2(scout.x, scout.y))
	run(w, secs(1) + 2)
	expect_false(scout.alive)
	expect_eq(w.kills, 1)
	expect_eq(w.money, money - Abilities.get_def("strike").cost + scout.def.reward)


# ---- landmine ---------------------------------------------------------------------

func test_a_mine_goes_on_walkable_ground_only() -> void:
	var w := World.new(level())
	expect_eq(w.mine_block_reason(3, 10), World.BlockReason.NONE, "the road")
	expect_eq(w.mine_block_reason(0, 0), World.BlockReason.TERRAIN, "grass on a level where enemies keep to the road")
	expect_true(w.place_mine(3, 10))
	expect_eq(w.money, 1000 - 25)
	expect_eq(w.mine_block_reason(3, 10), World.BlockReason.OCCUPIED, "one mine per tile")
	expect_false(w.place_mine(3, 10))
	expect_eq(w.mines.size(), 1)


func test_a_mine_cannot_go_under_a_tower_or_wall() -> void:
	var tiles: PackedStringArray = Levels.by_id("meadow").tiles
	var l := level()
	l.tiles = tiles
	l.road_walls = true
	var w := World.new(l)
	expect_true(w.build_wall(3, 11))
	expect_eq(w.mine_block_reason(3, 11), World.BlockReason.OCCUPIED)


func test_a_mine_may_go_on_grass_in_a_maze() -> void:
	var w := World.new(Levels.by_id("openfield"))
	expect_eq(w.mine_block_reason(8, 3), World.BlockReason.NONE)


func test_at_most_three_mines_at_a_time() -> void:
	var w := World.new(level())
	for col: int in [2, 3, 4]:
		expect_true(w.place_mine(col, 10))
	expect_eq(w.ability_block("mine"), World.AbilityBlock.LIMIT)
	expect_false(w.place_mine(5, 10))
	expect_eq(w.money, 1000 - 3 * 25)


func test_a_mine_blows_up_under_a_ground_enemy_and_hurts_it() -> void:
	var w := World.new(level())
	var tank: Enemy = stationary(w) # at the start, 40 px from the middle of tile (0, 10)
	expect_true(w.place_mine(0, 10))
	w.update()
	expect_eq(w.mines.size(), 0, "it went off")
	expect_near(damage_taken(tank), 90.0, 0)


func test_a_mine_damage_grows_with_the_waves() -> void:
	var w := World.new(level())
	w.wave_index = 5 # enemies have 50% more hitpoints now
	var tank: Enemy = stationary(w)
	w.place_mine(0, 10)
	w.update()
	expect_near(damage_taken(tank), 90.0 * 1.5, 0)


func test_a_mine_hurts_everything_close_to_it_but_not_the_far_away() -> void:
	var w := World.new(level())
	var close: Enemy = place(stationary(w), 20, 420) # on the mine: sets it off
	var neighbour: Enemy = place(stationary(w), 50, 420) # 30 px away, inside the blast
	var far: Enemy = place(stationary(w), 300, 420)
	w.place_mine(0, 10)
	w.update()
	expect_gt(damage_taken(close), 0.0)
	expect_gt(damage_taken(neighbour), 0.0)
	expect_eq(damage_taken(far), 0.0)


func test_a_mine_ignores_flyers_that_pass_over_it() -> void:
	var w := World.new(level())
	var drone: Enemy = w.spawn("drone")
	w.place_mine(0, 10) # the drone flies right over the middle of this tile
	run(w, 60)
	expect_gt(drone.x, 40.0, "it has flown past the mine")
	expect_eq(w.mines.size(), 1, "and didn't set it off")


func test_a_mine_ignores_enemies_that_are_far_away() -> void:
	var w := World.new(level())
	stationary(w)
	w.place_mine(8, 10)
	w.update()
	expect_eq(w.mines.size(), 1)


func test_a_mine_catches_a_walking_enemy() -> void:
	var w := World.new(level())
	var scout: Enemy = w.spawn("scout")
	run(w, 90)
	var col: int = floori(scout.x / Config.TILE) + 3
	var row: int = floori(scout.y / Config.TILE)
	expect_true(w.place_mine(col, row))
	run(w, 600)
	expect_eq(w.mines.size(), 0, "it went off")
	expect_false(scout.alive)
	expect_false(scout.escaped, "and the scout didn't get away")


# ---- bounty -----------------------------------------------------------------------

func test_bounty_doubles_kill_rewards_while_it_lasts() -> void:
	var w := World.new(level())
	var scout: Enemy = stationary(w, "scout")
	w.use_ability("bounty")
	w.update()
	var money: int = w.money
	w.damage_enemy(scout, 1000.0)
	expect_eq(w.money - money, scout.def.reward * 2)
	run(w, secs(15))
	var other: Enemy = stationary(w, "scout")
	money = w.money
	w.damage_enemy(other, 1000.0)
	expect_eq(w.money - money, other.def.reward, "over")


func test_bounty_shows_the_doubled_amount_in_the_kill_event() -> void:
	var w := World.new(level())
	var scout: Enemy = stationary(w, "scout")
	w.use_ability("bounty")
	w.events.clear()
	w.damage_enemy(scout, 1000.0)
	var amount: int = -1
	for ev: WorldEvent in w.events:
		if ev.type == WorldEvent.Type.KILL:
			amount = ev.amount
	expect_eq(amount, scout.def.reward * 2)


# ---- focus mark -------------------------------------------------------------------

func test_a_marked_enemy_takes_double_damage_for_a_while() -> void:
	var w := World.new(level())
	var marked: Enemy = stationary(w)
	var plain: Enemy = stationary(w)
	expect_true(w.use_ability("mark", Vector2(marked.x, marked.y)))
	expect_true(marked.is_marked())
	w.damage_enemy(marked, 10.0)
	w.damage_enemy(plain, 10.0)
	expect_near(damage_taken(marked), 2 * damage_taken(plain), 2)
	run(w, secs(6))
	expect_false(marked.is_marked())
	var before: float = marked.hitpoints
	w.damage_enemy(marked, 10.0)
	expect_near(before - marked.hitpoints, 10.0, 2, "normal damage again")


func test_the_mark_needs_an_enemy_under_the_pointer() -> void:
	var w := World.new(level())
	var e: Enemy = stationary(w)
	expect_false(w.use_ability("mark", Vector2(e.x + 300, e.y)))
	expect_eq(w.money, 1000, "nothing is charged for a miss")
	expect_eq(w.cooldown_left("mark"), 0)
	expect_true(w.use_ability("mark", Vector2(e.x + 5, e.y + 5)))


func test_the_mark_picks_the_enemy_nearest_the_pointer() -> void:
	var w := World.new(level())
	var a: Enemy = place(stationary(w, "scout"), 300, 300)
	var b: Enemy = place(stationary(w, "scout"), 320, 300) # 20 px to the right
	w.use_ability("mark", Vector2(b.x + 1, b.y))
	expect_true(b.is_marked())
	expect_false(a.is_marked())


func test_the_mark_makes_towers_kill_faster() -> void:
	var plain := World.new(level())
	var marked := World.new(level())
	var targets: Array[Enemy] = []
	for w: World in [plain, marked]:
		w.build("gun", 1, 9)
		targets.append(stationary(w))
	marked.use_ability("mark", Vector2(targets[1].x, targets[1].y))
	run(plain, 300)
	run(marked, 300)
	expect_gt(damage_taken(targets[1]), damage_taken(targets[0]) * 1.5)


# ---- second wind ------------------------------------------------------------------

func test_second_wind_gives_three_lives_once_per_game() -> void:
	var w := World.new(level())
	w.lives = 5
	expect_true(w.use_ability("wind"))
	expect_eq(w.lives, 8)
	expect_eq(w.money, 1000 - 120)
	expect_true(w.is_used("wind"))
	expect_eq(w.ability_block("wind"), World.AbilityBlock.USED)
	expect_false(w.use_ability("wind"))
	expect_eq(w.lives, 8)


# ---- saving -----------------------------------------------------------------------

func test_cooldowns_mines_and_used_abilities_survive_a_save() -> void:
	var w := World.new(level())
	w.use_ability("wind")
	w.use_ability("slow")
	w.place_mine(3, 10)
	run(w, 100)
	var left: int = w.cooldown_left("slow")
	var snap: WorldSnapshot = w.snapshot()
	var back: WorldSnapshot = WorldSnapshot.from_dict(JSON.parse_string(JSON.stringify(snap.to_dict())))
	var w2 := World.new(level())
	w2.restore(back)
	expect_eq(w2.cooldown_left("slow"), left)
	expect_true(w2.is_used("wind"))
	expect_eq(w2.mines.size(), 1)
	expect_eq(w2.mines[0].col, 3)
	expect_false(w2.is_active("slow"), "effects in progress are not kept")
	expect_eq(w2.ability_block("wind"), World.AbilityBlock.USED)
