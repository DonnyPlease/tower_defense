class_name Mulberry32
extends RefCounted
## Small seeded PRNG (mulberry32), identical to the JavaScript version, so
## endless waves and simulated players are the same on every run.

var _a: int


func _init(seed_value: int) -> void:
	_a = seed_value & MathX.MASK32


## Next number in [0, 1).
func next() -> float:
	_a = (_a + 0x6d2b79f5) & MathX.MASK32
	var t: int = _a
	t = MathX.imul(t ^ (t >> 15), t | 1)
	t = t ^ ((t + MathX.imul(t ^ (t >> 7), t | 61)) & MathX.MASK32)
	return float((t ^ (t >> 14)) & MathX.MASK32) / 4294967296.0
