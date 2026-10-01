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
