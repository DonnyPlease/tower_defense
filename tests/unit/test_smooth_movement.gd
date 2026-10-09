extends TestCase
## Enemies move and turn smoothly: no sideways jitter on roads, no snapping
## round in a U-turn, and no detour after a wall that was in the way is sold.


## How often (per enemy and tick) the drawn body turns fast, and the fastest turn seen.
func turning(level_id: String, waves: int) -> Vector2:
	var w := World.new(Levels.by_id(level_id))
	w.lives = 1 << 30
	var last: Dictionary[Enemy, float] = {}
	var fast: int = 0
	var samples: int = 0
	var worst: float = 0.0
	for wave: int in waves:
		w.start_next_wave()
		for t: int in 60 * 30:
			w.update()
			for e: Enemy in w.enemies:
				if last.has(e):
					samples += 1
					var d: float = absf(MathX.angle_diff(last[e], e.angle))
					worst = maxf(worst, d)
					if d > 0.08:
						fast += 1
				last[e] = e.angle
			w.events.clear()
	return Vector2(float(fast) / maxi(1, samples), worst)


func test_enemies_on_a_road_turn_smoothly() -> void:
	# Riverside's narrow roads used to make enemies twitch where the usable
	# width changed (about 6% of ticks turned fast); now only the corners do.
	var t: Vector2 = turning("riverside", 3)
	expect_lt(t.x, 0.045, "fast turns only at corners (%.3f of ticks)" % t.x)
	expect_le(t.y, Enemy.MAX_TURN + 1e-6, "never faster than a vehicle")


func test_enemies_that_re_route_never_snap_round() -> void:
	expect_le(turning("meadow", 2).y, Enemy.MAX_TURN + 1e-6)


func test_lanes_change_smoothly_where_the_road_narrows() -> void:
	# Along a whole route, the usable offset never jumps between two nearby points.
	var map := GameMap.new("Riverside", Levels.by_id("riverside").tiles)
	var route: Route = map.routes[0]
	var prev: float = route.clamp_offset_at(100.0, 0.0, 0)
	var i: int = 0
	var s: float = 0.0
	while s < route.length:
		i = route.seek(s, i)
		var now: float = route.clamp_offset_at(100.0, s, i)
		expect_lt(absf(now - prev), 0.6, "at %.0f px" % s)
		if absf(now - prev) >= 0.6:
			return
		prev = now
		s += 1.0

