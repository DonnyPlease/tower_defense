class_name Aim
extends RefCounted
## Aiming at moving targets.


## Time (in ticks) until a projectile with `speed` fired from (from_x, from_y)
## meets a target at (tx, ty) moving with constant velocity (vx, vy): solves
## |d + v*t| = speed*t for the smallest t > 0. Returns -1 if there is no solution.
static func intercept_time(from_x: float, from_y: float, tx: float, ty: float, vx: float, vy: float,
		speed: float) -> float:
	var dx: float = tx - from_x
	var dy: float = ty - from_y
	var a: float = vx * vx + vy * vy - speed * speed
	var b: float = 2 * (dx * vx + dy * vy)
	var c: float = dx * dx + dy * dy
	if absf(a) < 1e-9:
		return -c / b if absf(b) > 1e-9 else -1.0
	var disc: float = b * b - 4 * a * c
	if disc < 0:
		return -1.0
	var s: float = sqrt(disc)
	var t1: float = (-b - s) / (2 * a)
	var t2: float = (-b + s) / (2 * a)
	var lo: float = minf(t1, t2)
	var hi: float = maxf(t1, t2)
	return lo if lo > 0 else hi


## Point where a projectile should be aimed to hit a moving target.
static func lead_point(from_x: float, from_y: float, tx: float, ty: float, vx: float, vy: float,
		speed: float) -> Vector2:
	var t: float = intercept_time(from_x, from_y, tx, ty, vx, vy, speed)
	if t <= 0:
		return Vector2(tx, ty)
	return Vector2(tx + vx * t, ty + vy * t)


## Angle to shoot at so that the projectile meets the moving target.
static func lead_angle(from_x: float, from_y: float, tx: float, ty: float, vx: float, vy: float,
		speed: float) -> float:
	var t: float = intercept_time(from_x, from_y, tx, ty, vx, vy, speed)
	if t <= 0:
		return atan2(ty - from_y, tx - from_x)
	return atan2(ty + vy * t - from_y, tx + vx * t - from_x)
