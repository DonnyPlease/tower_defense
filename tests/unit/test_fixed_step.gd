extends TestCase
## The fixed-timestep clock.

const STEP: float = 1000.0 / Config.TICK_RATE

var ticks: int = 0


func count() -> void:
	ticks += 1


func test_runs_one_tick_per_step_and_returns_the_leftover_as_alpha() -> void:
	var clock := FixedStep.new()
	var alpha: float = clock.advance(STEP * 2.5, 1, count)
	expect_eq(ticks, 2)
	expect_near(alpha, 0.5)


func test_carries_the_remainder_over_to_the_next_frame() -> void:
	var clock := FixedStep.new()
	clock.advance(STEP * 0.6, 1, count)
	clock.advance(STEP * 0.6, 1, count)
	expect_eq(ticks, 1)


func test_speeds_up_with_the_time_scale() -> void:
	var clock := FixedStep.new()
	clock.advance(STEP * 3, 3, count)
	expect_eq(ticks, 9)


func test_caps_long_frames_instead_of_spiralling() -> void:
	var clock := FixedStep.new()
	var alpha: float = clock.advance(10_000, 1, count) # e.g. the window was in the background
	expect_le(ticks, Config.MAX_TICKS_PER_FRAME)
	expect_ge(alpha, 0)
	expect_lt(alpha, 1)


func test_runs_exactly_one_tick_per_60_hz_frame() -> void:
	# No 0-2-0-2 stutter from floating-point drift.
	var clock := FixedStep.new()
	var other: int = 0
	for f: int in 600:
		ticks = 0
		clock.advance(STEP, 1, count)
		if ticks != 1:
			other += 1
	expect_eq(other, 0)


func test_keeps_real_time_on_a_slow_device_at_every_speed() -> void:
	for speed: int in [1, 2, 3]:
		var clock := FixedStep.new()
		ticks = 0
		for f: int in 150: # 10 seconds at 15 frames per second
			clock.advance(1000.0 / 15, speed, count)
		expect_near(ticks, 600 * speed, -1, "%dx: every tick of 10 s runs" % speed)


func test_a_hitch_costs_at_most_a_few_ticks_in_one_frame() -> void:
	var clock := FixedStep.new()
	clock.advance(250, 3, count) # a quarter-second hitch at 3x
	expect_le(ticks, Config.MAX_TICKS_PER_FRAME * 3, "the next frame stays short")
