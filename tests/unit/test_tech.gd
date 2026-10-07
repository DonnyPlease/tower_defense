extends TestCase
## The tech tree: what stars buy, in what order, and what it changes in a game.

## One file per process, so test runs can go side by side.
static var profile_path: String = "user://unit_tech_%d.json" % OS.get_process_id()


func before_each() -> void:
	Profile.storage_path = profile_path
	Profile.forget_cache()
	DirAccess.remove_absolute(profile_path)
	Profile.reset()


func after_each() -> void:
	DirAccess.remove_absolute(profile_path)
	Profile.storage_path = Profile.DEFAULT_PATH
	Profile.forget_cache()


## A profile with `stars` earned on Meadow and Riverside (3 + rest).
func earned(total: int) -> Profile:
	var p: Profile = Profile.load_profile()
	var left: int = total
	for id: String in ["meadow", "riverside", "highlands", "openfield"]:
		if left > 0:
			p.stars[id] = mini(3, left)
			left -= mini(3, left)
	p.stars["bonus"] = left # anything above 12 (a made-up level, it only counts)
	return p


# ---- the data ------------------------------------------------------------------------

func test_every_node_is_described_placed_and_reachable() -> void:
	var places: Dictionary[Vector2i, String] = {}
	for n: Tech.TechNode in Tech.NODES:
		expect_false(n.name.is_empty(), n.id)
		expect_false(n.description.is_empty(), n.id)
		expect_ge(n.cost, 0, n.id)
		var at := Vector2i(n.col, n.row)
		expect_false(places.has(at), "%s and %s share a place" % [n.id, places.get(at, "")])
		places[at] = n.id
		expect_true(n.col >= 0 and n.col < Tech.COLS and n.row >= 0 and n.row < Tech.ROWS, "%s is on the grid" % n.id)
		for parent: String in n.parents:
			expect_true(Tech.is_node(parent), "%s: parent %s exists" % [n.id, parent])
			expect_le(Tech.get_node(parent).earned, n.earned, "%s: needs no fewer stars than its parent" % n.id)
	# Every node can be reached from the start (no cycles, no orphans).
	var reached: Dictionary[String, bool] = {}
	var grew: bool = true
	while grew:
		grew = false
		for n: Tech.TechNode in Tech.NODES:
			if reached.has(n.id):
				continue
			if n.parents.all(func(p: String) -> bool: return reached.has(p)):
				reached[n.id] = true
				grew = true
	expect_eq(reached.size(), Tech.NODES.size())


func test_the_tree_holds_every_tower_branch_and_perk_rank() -> void:
	for kind: String in Towers.KINDS:
		expect_true(Tech.is_node(kind), kind)
		expect_eq(Tech.get_node(kind).kind, Tech.Kind.TOWER)
	for id: String in Towers.BRANCH_IDS:
		expect_true(Tech.is_node(id), id)
		expect_eq(Tech.get_node(id).parents, [Towers.get_branch(id).kind] as Array[String], "%s grows from its tower" % id)
	for perk: String in Perks.IDS:
		for rank: int in range(1, Perks.get_def(perk).costs.size() + 1):
			expect_true(Tech.is_node(Tech.perk_node(perk, rank)), "%s %d" % [perk, rank])
	expect_eq(Tech.get_node("capital2").name, "War Chest II")


# ---- buying ------------------------------------------------------------------------------

func test_a_fresh_profile_owns_only_the_start() -> void:
	var p: Profile = Profile.load_profile()
	expect_eq(p.unlocked_towers(), ["gun", "missile"])
	expect_true(p.owns("gun"))
	expect_false(p.owns("cannon"))
	expect_eq(p.locked_branches().size(), Towers.BRANCH_IDS.size(), "every branch is locked")
	expect_eq(p.available_stars(), 0)


func test_a_node_needs_its_parents_the_stars_earned_and_the_stars_to_spend() -> void:
	var p: Profile = earned(0)
	expect_eq(p.tech_state("cannon"), Profile.TechState.NEEDS_EARNED)
	p = earned(1)
	expect_eq(p.tech_state("cannon"), Profile.TechState.AVAILABLE)
	expect_eq(p.tech_state("laser"), Profile.TechState.NEEDS_PARENTS)
	expect_eq(p.tech_state("gun"), Profile.TechState.OWNED)
	expect_true(p.buy_tech("cannon"))
	expect_eq(p.tech_state("cannon"), Profile.TechState.OWNED)
	expect_eq(p.available_stars(), 0)
	expect_eq(p.unlocked_towers(), ["gun", "missile", "cannon"])
	expect_eq(p.tech_state("capital1"), Profile.TechState.NEEDS_STARS, "all stars are spent")
	expect_false(p.buy_tech("capital1"))
	p.stars["meadow"] = 3
	expect_eq(p.tech_state("frost"), Profile.TechState.AVAILABLE, "3 earned, 2 to spend")
	expect_false(p.buy_tech("cannon"), "already owned")
	expect_false(p.buy_tech("gun"), "owned from the start")
	expect_false(p.buy_tech("nonsense"))


func test_branches_unlock_in_the_tree() -> void:
	var p: Profile = earned(2)
	expect_true(p.locked_branches().has("minigun"))
	expect_true(p.buy_tech("minigun"))
	expect_false(p.locked_branches().has("minigun"))
	expect_true(p.locked_branches().has("sniper"))
	expect_false(p.buy_tech("mortar"), "the cannon isn't owned")


func test_refunding_gives_every_star_back_but_keeps_the_start() -> void:
	var p: Profile = earned(6)
	p.buy_tech("cannon")
	p.buy_tech("capital1")
	p.buy_tech("capital2")
	expect_eq(p.available_stars(), 2)
	p.refund_tech()
	expect_eq(p.available_stars(), 6)
	expect_eq(p.unlocked_towers(), ["gun", "missile"])
	expect_eq(p.perk_rank("capital"), 0)


func test_perk_ranks_give_the_same_modifiers_as_before() -> void:
	var p: Profile = earned(30)
	for id: String in ["capital1", "capital2", "fortify1", "engineering1", "firepower1", "firepower2"]:
		expect_true(p.buy_tech(id), id)
	expect_eq(p.perk_rank("capital"), 2)
	var m: Perks.Modifiers = p.modifiers()
	var old: Perks.Modifiers = Perks.modifiers_from({"capital": 2, "fortify": 1, "engineering": 1, "firepower": 2})
	expect_eq(m.money, old.money)
	expect_eq(m.lives, old.lives)
	expect_eq(m.cost_multiplier, old.cost_multiplier)
	expect_eq(m.damage_multiplier, old.damage_multiplier)
	expect_false(p.buy_tech("capital1"), "a rank is bought once")


func test_the_tree_is_saved_and_loaded() -> void:
	var p: Profile = earned(5)
	p.buy_tech("cannon")
	p.buy_tech("minigun")
	Profile.save_profile(p)
	Profile.forget_cache()
	var q: Profile = Profile.load_profile()
	expect_true(q.owns("cannon"))
	expect_true(q.owns("minigun"))
	expect_eq(q.available_stars(), p.available_stars())


func test_an_old_profile_keeps_its_towers_perks_and_saved_game() -> void:
	# Version 1 unlocked towers by stars earned and kept perks as ranks.
	var w := World.new(Levels.by_id("meadow"))
	w.build("gun", 3, 9)
	var old: Dictionary = {
		"v": 1, "stars": {"meadow": 3, "riverside": 3}, "perks": {"capital": 2, "fortify": 1},
		"endless_best": 7, "sfx": false, "music": true, "save": w.snapshot().to_dict(),
	}
	var file := FileAccess.open(profile_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	Profile.forget_cache()
	var p: Profile = Profile.load_profile()
	expect_eq(p.total_stars(), 6)
	expect_eq(p.unlocked_towers(), ["gun", "missile", "cannon", "frost", "laser"], "towers unlocked by 6 stars stay")
	expect_eq(p.perk_rank("capital"), 2)
	expect_eq(p.perk_rank("fortify"), 1)
	expect_eq(p.available_stars(), 6 - 1 - 2 - 1, "perks cost what they cost; the old towers are free")
	expect_eq(p.endless_best, 7)
	expect_false(p.sfx)
	expect_not_null(p.save)
	p.refund_tech()
	expect_true(p.owns("laser"), "towers kept from the old profile can't be refunded")
	expect_eq(p.available_stars(), 6)


# ---- in the game ----------------------------------------------------------------------

func test_masonry_makes_the_first_walls_free() -> void:
	var p: Profile = earned(20)
	p.buy_tech("fortify1")
	p.buy_tech("fortify2")
	expect_true(p.buy_tech("masonry"))
	var w := World.new(Levels.by_id("meadow"), Callable(), p.modifiers())
	var money: int = w.money
	for i: int in Tech.MASONRY_WALLS:
		expect_eq(w.wall_cost(), 0, "wall %d is free" % (i + 1))
		expect_true(w.build_wall(i, 0))
	expect_eq(w.money, money)
	expect_eq(w.wall_cost(), Abilities.wall_cost(Tech.MASONRY_WALLS), "then the usual price")
	w.sell_wall(0, 0)
	expect_eq(w.money, money, "a free wall refunds nothing")
	expect_gt(w.wall_cost(), 0, "selling doesn't give the free wall back")


func test_veterans_start_the_first_tower_at_level_2() -> void:
	var p: Profile = earned(20)
	p.buy_tech("engineering1")
	p.buy_tech("engineering2")
	expect_true(p.buy_tech("veterans"))
	var w := World.new(Levels.by_id("meadow"), Callable(), p.modifiers())
	var first: Tower = w.build("gun", 0, 0)
	var second: Tower = w.build("gun", 1, 0)
	expect_eq(first.level, 1)
	expect_eq(first.invested, w.cost_of("gun"), "paid only the build price")
	expect_eq(second.level, 0)
	var plain := World.new(Levels.by_id("meadow"))
	expect_eq(plain.build("gun", 0, 0).level, 0)


func test_starting_bonuses_survive_a_saved_game() -> void:
	var p: Profile = earned(20)
	p.buy_tech("fortify1")
	p.buy_tech("fortify2")
	p.buy_tech("masonry")
	var w := World.new(Levels.by_id("meadow"), Callable(), p.modifiers())
	w.build_wall(0, 0)
	var w2 := World.new(Levels.by_id("meadow"), Callable(), p.modifiers())
	w2.restore(WorldSnapshot.from_dict(JSON.parse_string(JSON.stringify(w.snapshot().to_dict()))))
	expect_eq(w2.free_walls_left, Tech.MASONRY_WALLS - 1)
