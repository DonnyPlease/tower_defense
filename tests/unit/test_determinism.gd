extends TestCase
## The random numbers match the original JavaScript game exactly, so endless
## waves, enemy lanes and simulated players (the balance) are unchanged.
## Expected values were produced by the TypeScript version (Math.imul based).


func test_hash01_matches_the_javascript_version() -> void:
	expect_eq("%.12f" % MathX.hash01(0, 0), "0.607713825768")
	expect_eq("%.12f" % MathX.hash01(1, 1), "0.726995193399")
	expect_eq("%.12f" % MathX.hash01(3, 6), "0.103370038792")


func test_mulberry32_matches_the_javascript_version() -> void:
	var r := Mulberry32.new(17)
	expect_eq("%.12f" % r.next(), "0.677150296047")
	expect_eq("%.12f" % r.next(), "0.192656921223")
	expect_eq("%.12f" % r.next(), "0.531383906491")


func test_imul_wraps_like_javascript() -> void:
	expect_eq(MathX.imul(0x9e3779b9 ^ 5, 0x85ebca6b), 1389509012)
	expect_eq(MathX.imul(-1, -1), 1)
	expect_eq(MathX.js_round(-2.5), -2)
	expect_eq(MathX.js_round(2.5), 3)
	expect_eq(MathX.to_fixed(30.25, 1), "30.3")
	expect_eq(MathX.to_fixed(12.6, 1), "12.6")


func test_endless_waves_match_the_javascript_version() -> void:
	expect_eq(describe(Levels.endless_wave(0)), "scout:10:0.6:0")
	expect_eq(describe(Levels.endless_wave(9)), "boss:1:8:0 armored:8:1.2:3 healer:1:2.5:6.976 racer:4:0.35:9.854 drone:1:0.6:12.633")
	expect_eq(describe(Levels.endless_wave(30)),
		"drone:30:0.6:0 drone:26:0.6:2.292 splitter:30:1:5.936 healer:30:2.5:10.378")


func describe(wave: Wave) -> String:
	var parts: PackedStringArray = []
	for g: SpawnGroup in wave.groups:
		parts.append("%s:%d:%s:%s" % [g.type, g.count, trim(g.interval), trim(snappedf(g.delay, 0.001))])
	return " ".join(parts)


func trim(x: float) -> String:
	return str(int(x)) if x == floorf(x) else str(x)
