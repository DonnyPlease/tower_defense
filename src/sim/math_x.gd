class_name MathX
extends RefCounted
## Small maths helpers that behave exactly like their JavaScript counterparts,
## so the simulation (and its balance) matches the original game bit for bit
## wherever the maths allows.

const MASK32: int = 0xFFFFFFFF


## Math.round: rounds halves up (towards +infinity), unlike GDScript's round().
static func js_round(x: float) -> int:
	return floori(x + 0.5)


## Number.prototype.toFixed: `digits` decimals, halves rounded up (printf's
## "%.1f" rounds an exact 30.25 down to 30.2; JavaScript prints 30.3).
static func to_fixed(x: float, digits: int) -> String:
	var scale: float = pow(10.0, digits)
	return ("%." + str(digits) + "f") % (js_round(x * scale) / scale)


static func hypot(x: float, y: float) -> float:
	return sqrt(x * x + y * y)


## Difference b - a wrapped to [-PI, PI].
static func angle_diff(a: float, b: float) -> float:
	return atan2(sin(b - a), cos(b - a))


## Math.imul: 32-bit multiplication, result as an unsigned 32-bit value.
static func imul(a: int, b: int) -> int:
	var al: int = a & 0xFFFF
	var ah: int = (a >> 16) & 0xFFFF
	var bl: int = b & 0xFFFF
	var bh: int = (b >> 16) & 0xFFFF
	return (al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16)) & MASK32


## Deterministic pseudo random number in [0, 1) for an integer seed.
static func hash01(seed_value: int, salt: int = 0) -> float:
	var t: int = (imul(seed_value ^ 0x9e3779b9, 0x85ebca6b) + imul(salt + 1, 0xc2b2ae35)) & MASK32
	t = imul(t ^ (t >> 15), t | 1)
	t = t ^ ((t + imul(t ^ (t >> 7), t | 61)) & MASK32)
	return float((t ^ (t >> 14)) & MASK32) / 4294967296.0
