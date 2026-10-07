extends TestCase
## UI formatting helpers.


func test_lerp_interpolates_linearly() -> void:
	expect_eq(Format.lerp_value(0, 10, 0.25), 2.5)
	expect_eq(Format.lerp_value(5, 5, 0.7), 5.0)


func test_lerp_angle_goes_the_short_way_round() -> void:
	var a: float = deg_to_rad(170)
	var b: float = deg_to_rad(-170)
	var mid: float = Format.lerp_angle_short(a, b, 0.5)
	expect_lt(absf(cos(mid) - cos(PI)), 1e-9, "180°, not 0°")


func test_star_string_fills_and_pads() -> void:
	expect_eq(Format.star_string(2), "★★☆")
	expect_eq(Format.star_string(0), "☆☆☆")
	expect_eq(Format.star_string(5, 3), "★★★★★")


func test_numbers_print_like_javascript() -> void:
	expect_eq(Format.num(3), "3")
	expect_eq(Format.num(3.5), "3.5")
	expect_eq(Format.num(27), "27")


func test_describes_every_tower_at_every_level() -> void:
	for kind: String in Towers.KINDS:
		for level: int in [0, 1, 2]:
			expect_match(Format.tower_stats_text(kind, level), "Range \\d+", "%s %d" % [kind, level])
	expect_contains(Format.tower_stats_text("cannon", 0), "Splash 45")
	expect_match(Format.tower_stats_text("gun", 0, 212.4, 0.3), "Range 212[\\s\\S]*Boosted \\+30%")
	expect_contains(Format.tower_stats_text("gun", 0), "Damage 3  ·  3.0/s")
	expect_contains(Format.tower_stats_text("laser", 0), "heats to 27")
	expect_contains(Format.tower_stats_text("frost", 0), "Slow 35%")
	expect_contains(Format.tower_stats_text("support", 0), "+20% fire rate")


func test_describes_every_branch_and_what_makes_it_special() -> void:
	for id: String in Towers.BRANCH_IDS:
		var b: TowerBranch = Towers.get_branch(id)
		for level: int in [3, 4]:
			expect_match(Format.tower_stats_text(b.kind, level, -1, 0, id), "Range \\d+", "%s %d" % [id, level])
	expect_contains(Format.tower_stats_text("gun", 3, -1, 0, "sniper"), "Hits 3 in a line")
	expect_contains(Format.tower_stats_text("gun", 3, -1, 0, "minigun"), "Spins up in 2 s")
	expect_contains(Format.tower_stats_text("missile", 3, -1, 0, "swarm"), "4 x 9 damage")
	expect_contains(Format.tower_stats_text("missile", 4, -1, 0, "seeker"), "x2 vs bosses")
	expect_contains(Format.tower_stats_text("cannon", 3, -1, 0, "mortar"), "Min range 90")
	expect_contains(Format.tower_stats_text("cannon", 3, -1, 0, "siege"), "Ignores armor")
	expect_contains(Format.tower_stats_text("frost", 3, -1, 0, "blizzard"), "no damage")
	expect_contains(Format.tower_stats_text("frost", 3, -1, 0, "cryo"), "Freezes 0.5 s  ·  +25% damage taken")
	expect_contains(Format.tower_stats_text("laser", 4, -1, 0, "prism"), "3 beams of 28 dps")
	expect_contains(Format.tower_stats_text("laser", 4, -1, 0, "lance"), "heats to 200")
	expect_contains(Format.tower_stats_text("support", 3, -1, 0, "command"), "+15% range")
	# Without the branch, levels 4 and 5 fall back to level 3 (they can't exist).
	expect_eq(Format.tower_stats_text("gun", 3), Format.tower_stats_text("gun", 2))


func test_failure_messages_name_objects_instead_of_serialising_them() -> void:
	var w := World.new(Levels.by_id("meadow"))
	var t: Tower = w.build("gun", 0, 0)
	expect_match(TestCase.describe_value(t), "^<Tower#-?\\d+>$")
	expect_match(TestCase.describe_value(w.towers), "^\\[<Tower#-?\\d+>\\]$")
	expect_eq(TestCase.describe_value(3), "3")
	expect_eq(TestCase.describe_value("a"), '"a"')
