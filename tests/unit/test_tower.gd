extends TestCase
## Aiming and target selection.

var meadow: LevelDef = Levels.by_id("meadow")


func test_lead_angle_aims_straight_at_a_stationary_target() -> void:
	expect_near(Aim.lead_angle(0, 0, 100, 0, 0, 0, 10), 0)
	expect_near(Aim.lead_angle(0, 0, 0, 100, 0, 0, 10), PI / 2)


func test_lead_angle_leads_a_moving_target_so_the_bullet_meets_it() -> void:
	var speed: float = 10
	var a: float = Aim.lead_angle(0, 0, 100, 0, 0, 2, speed)
	var best: float = INF
	var t: float = 0.0
	while t < 30:
		var bx: float = cos(a) * speed * t
		var by: float = sin(a) * speed * t
		best = minf(best, MathX.hypot(bx - 100, by - (0 + 2 * t)))
		t += 0.01
	expect_lt(best, 0.5)


func test_lead_angle_falls_back_to_direct_aim_when_the_target_is_too_fast_to_catch() -> void:
	expect_near(Aim.lead_angle(0, 0, 100, 0, 50, 0, 1), 0)


func test_lead_point_matches_lead_angle() -> void:
	var p: Vector2 = Aim.lead_point(0, 0, 100, 0, 0, 2, 10)
	expect_near(atan2(p.y, p.x), Aim.lead_angle(0, 0, 100, 0, 0, 2, 10), 4)
	expect_eq(Aim.lead_point(0, 0, 100, 0, 50, 0, 1), Vector2(100, 0))


func test_gets_more_range_on_high_ground() -> void:
	var t := Tower.new("gun", 0, 0, true)
	expect_near(t.attack_range, t.stats.attack_range * Config.HIGH_GROUND_RANGE)


func test_picks_targets_by_mode() -> void:
	var w := World.new(meadow)
	var a: Enemy = w.spawn("scout")
	var b: Enemy = w.spawn("tank")
	a.x = 200
	b.x = 200
	a.y = 400
	b.y = 400
	a.remaining = 100
	b.remaining = 500
	var t := Tower.new("gun", 5, 10)
	t.target_mode = Towers.TargetMode.FIRST
	expect_true(t.pick_target(w.enemies) == a)
	t.target_mode = Towers.TargetMode.LAST
	expect_true(t.pick_target(w.enemies) == b)
	t.target_mode = Towers.TargetMode.STRONGEST
	expect_true(t.pick_target(w.enemies) == b)


func test_ground_only_towers_ignore_flying_enemies() -> void:
	var w := World.new(meadow)
	var d: Enemy = w.spawn("drone")
	d.x = 220
	d.y = 420
	expect_null(Tower.new("cannon", 5, 10).pick_target(w.enemies))
	expect_true(Tower.new("gun", 5, 10).pick_target(w.enemies) == d)


func test_handles_a_target_exactly_as_fast_as_the_bullet() -> void:
	# a == 0 in the intercept equation: catchable only when closing in.
	expect_near(Aim.lead_angle(0, 0, 100, 0, -10, 0, 10), 0)
	expect_near(Aim.lead_angle(0, 0, 100, 0, 0, 10, 10), 0, 2, "no solution: direct aim")


func test_handles_a_stationary_target_at_the_tower() -> void:
	expect_true(is_finite(Aim.lead_angle(0, 0, 0, 0, 0, 0, 5)))


func test_closest_mode_picks_the_nearest_enemy() -> void:
	var w := World.new(meadow)
	var near: Enemy = w.spawn("scout")
	var far: Enemy = w.spawn("scout")
	near.x = 230
	near.y = 420
	far.x = 330
	far.y = 420
	near.remaining = 900
	far.remaining = 100
	var t := Tower.new("gun", 5, 10)
	t.target_mode = Towers.TargetMode.CLOSEST
	expect_true(t.pick_target(w.enemies) == near)


func test_upgrade_cost_and_sell_value() -> void:
	var t := Tower.new("gun", 0, 0)
	expect_eq(t.upgrade_cost(), 70)
	t.level = 2
	expect_eq(t.upgrade_cost(), Tower.NO_UPGRADE)
	expect_near(t.attack_range, 195)
	t.invested = 301
	expect_eq(t.sell_value(), 150)
