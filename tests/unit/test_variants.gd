extends TestCase
## Level variants: the same maps with a twist (night, reversed, last stand,
## no gun), each with stars of its own and unlocked in the tech tree.

static var profile_path: String = "user://unit_variants_%d.json" % OS.get_process_id()


func before_each() -> void:
	Profile.storage_path = profile_path
	Profile.forget_cache()
	DirAccess.remove_absolute(profile_path)
	Profile.reset()


func after_each() -> void:
	DirAccess.remove_absolute(profile_path)
	Profile.storage_path = Profile.DEFAULT_PATH
	Profile.forget_cache()


func test_every_variant_has_a_name_a_description_and_a_tech_node() -> void:
	for id: String in Levels.VARIANTS:
		var v: Levels.LevelVariant = Levels.get_variant(id)
		expect_false(v.name.is_empty(), id)
		expect_false(v.description.is_empty(), id)
		expect_true(Tech.is_node(id), "%s is unlocked in the tree" % id)


func test_a_variant_level_has_its_own_id_and_resolves_back() -> void:
	var night: LevelDef = Levels.with_variant(Levels.by_id("meadow"), "night")
	expect_eq(night.id, "meadow@night")
	expect_eq(night.base_id, "meadow")
	expect_eq(night.variant, "night")
	expect_eq(night.name, "Meadow (Night)")
	var again: LevelDef = Levels.by_id("meadow@night")
	expect_eq(again.id, "meadow@night")
	expect_eq(again.tower_range, night.tower_range)
	expect_eq(Levels.with_variant(Levels.by_id("meadow"), "").id, "meadow", "no variant: the level itself")


func test_night_shortens_every_tower_range() -> void:
	var w := World.new(Levels.by_id("meadow@night"))
	var t: Tower = w.build("gun", 0, 0)
	expect_near(t.attack_range, Towers.get_def("gun").levels[0].attack_range * Levels.get_variant("night").tower_range)
	w.upgrade(t)
	expect_near(t.attack_range, Towers.get_def("gun").levels[1].attack_range * Levels.get_variant("night").tower_range)


func test_reversed_swaps_the_entrances_and_the_exits() -> void:
	var normal := World.new(Levels.by_id("riverside"))
	var reversed := World.new(Levels.by_id("riverside@reversed"))
	expect_eq(reversed.map.starts, normal.map.ends)
	expect_eq(reversed.map.ends, normal.map.starts)
	var e: Enemy = reversed.spawn("scout")
	expect_gt(e.x, Config.FIELD_W / 2.0, "enemies come from the right now")


func test_last_stand_has_few_lives_and_no_gun_bans_the_gun() -> void:
	var last := World.new(Levels.by_id("highlands@laststand"))
	expect_eq(last.lives, Levels.get_variant("laststand").lives)
	var unarmed := World.new(Levels.by_id("meadow@nogun"))
	expect_false(unarmed.is_unlocked("gun"))
	expect_null(unarmed.build("gun", 0, 0))
	expect_not_null(unarmed.build("missile", 0, 0))


func test_variants_earn_their_own_stars() -> void:
	var p: Profile = Profile.load_profile()
	p.record_win("meadow", 2)
	expect_eq(p.record_win("meadow@night", 3), 3)
	expect_eq(p.stars_on("meadow"), 2)
	expect_eq(p.stars_on("meadow@night"), 3)
	expect_eq(p.total_stars(), 5)
	expect_true(p.is_level_unlocked(1), "the base level unlocks the next one")


func test_variants_are_played_only_once_unlocked() -> void:
	var p: Profile = Profile.load_profile()
	expect_eq(p.variants_for("meadow"), [""] as Array[String], "only the normal level at first")
	p.stars["meadow"] = 3
	p.stars["riverside"] = 3
	expect_false(p.is_variant_unlocked("night"))
	expect_true(p.buy_tech("night"))
	expect_true(p.is_variant_unlocked("night"))
	expect_eq(p.variants_for("meadow"), ["", "night"] as Array[String])
	expect_eq(p.variants_for(Levels.ENDLESS.id), [""] as Array[String], "endless has no variants")


func test_a_variant_game_is_saved_and_resumed_as_that_variant() -> void:
	var w := World.new(Levels.by_id("riverside@reversed"))
	w.build("missile", 2, 1)
	var snap: WorldSnapshot = WorldSnapshot.from_dict(JSON.parse_string(JSON.stringify(w.snapshot().to_dict())))
	expect_eq(snap.level_id, "riverside@reversed")
	var w2 := World.new(Levels.by_id(snap.level_id))
	w2.restore(snap)
	expect_eq(w2.map.starts, w.map.starts)
	expect_eq(w2.towers.size(), 1)
