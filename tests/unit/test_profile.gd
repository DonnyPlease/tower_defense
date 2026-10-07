extends TestCase
## Saved progress: stars, unlocks, perks, storage.

## One file per process, so test runs can go side by side.
static var profile_path: String = "user://unit_profile_%d.json" % OS.get_process_id()


func before_each() -> void:
	Profile.storage_path = profile_path
	Profile.forget_cache()
	DirAccess.remove_absolute(profile_path)
	Profile.reset()


func after_each() -> void:
	DirAccess.remove_absolute(profile_path)
	Profile.storage_path = Profile.DEFAULT_PATH
	Profile.forget_cache()


func test_awards_stars_by_lives_left() -> void:
	expect_eq(Profile.stars_for(20, 20), 3)
	expect_eq(Profile.stars_for(10, 20), 2)
	expect_eq(Profile.stars_for(1, 20), 1)


func test_keeps_the_best_result_and_unlocks_levels() -> void:
	var p: Profile = Profile.load_profile()
	expect_false(p.is_level_unlocked(1))
	expect_eq(p.record_win("meadow", 2), 2, "2 new stars")
	expect_eq(p.record_win("meadow", 1), 0, "no new stars")
	expect_eq(p.record_win("meadow", 3), 1, "one more")
	p.stars["meadow"] = 2
	expect_eq(p.stars["meadow"], 2)
	expect_true(p.is_level_unlocked(1))
	expect_false(p.is_endless_unlocked())
	p.record_win("riverside", 3)
	expect_true(p.is_endless_unlocked())
	expect_eq(p.total_stars(), 5)


func test_spends_stars_on_perks_and_refunds_them() -> void:
	var p: Profile = Profile.load_profile()
	p.record_win("meadow", 3)
	expect_true(p.buy_tech("capital1"), "rank 1 costs 1")
	expect_true(p.buy_tech("capital2"), "rank 2 costs 2")
	expect_eq(p.available_stars(), 0)
	expect_false(p.buy_tech("fortify1"))
	expect_eq(p.modifiers().money, 80)
	p.refund_tech()
	expect_eq(p.available_stars(), 3)


func test_maxed_perks_cost_nothing_more() -> void:
	var p: Profile = Profile.load_profile()
	for level: String in ["meadow", "riverside", "highlands", "openfield"]:
		p.record_win(level, 3)
	expect_true(p.buy_tech("fortify1"))
	expect_true(p.buy_tech("fortify2"))
	expect_false(Tech.is_node("fortify3"), "two ranks only")
	expect_eq(p.perk_rank("fortify"), 2)


func test_records_the_best_endless_run() -> void:
	var p: Profile = Profile.reset()
	expect_true(p.record_endless(12))
	expect_false(p.record_endless(8))
	expect_eq(p.endless_best, 12)


func test_saves_to_and_loads_from_storage() -> void:
	var p: Profile = Profile.load_profile()
	p.record_win("meadow", 2)
	var w := World.new(Levels.by_id("meadow"))
	w.build("gun", 3, 9)
	p.save = w.snapshot()
	p.music = false
	Profile.save_profile(p)
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(profile_path))
	expect_true(stored is Dictionary)

	Profile.forget_cache() # like restarting the game
	var q: Profile = Profile.load_profile()
	expect_false(p == q)
	expect_eq(q.stars["meadow"], 2)
	expect_false(q.music)
	expect_true(q.sfx)
	expect_not_null(q.save)
	if q.save != null:
		expect_eq(q.save.level_id, "meadow")
		expect_eq(q.save.towers.size(), 1)


func test_starts_fresh_when_the_stored_data_is_corrupt_or_from_another_version() -> void:
	for raw: String in ["{not json", JSON.stringify({"v": 99, "stars": {"meadow": 3}}), "[]"]:
		var file := FileAccess.open(profile_path, FileAccess.WRITE)
		file.store_string(raw)
		file.close()
		Profile.forget_cache()
		expect_eq(Profile.load_profile().stars.size(), 0, raw)


func test_reset_keeps_the_sound_settings() -> void:
	var p: Profile = Profile.load_profile()
	p.sfx = false
	p.record_win("meadow", 3)
	var fresh: Profile = Profile.reset()
	expect_false(fresh.sfx)
	expect_eq(fresh.total_stars(), 0)
