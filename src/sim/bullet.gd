class_name Bullet
extends RefCounted
## A projectile: gun bullet, homing missile or cannon shell.

const MISSILE_TURN_RATE: float = 0.15 # radians per tick
const MAX_LIFETIME: int = 6 * Config.TICK_RATE

enum Outcome { NONE, HIT, EXPLODE }

static var _next_id: int = 1

var id: int
var x: float
var y: float
var prev_x: float
var prev_y: float
var angle: float
var speed: float
var damage: float
var type: Towers.BulletType
var radius: float
var hits_air: bool
var hits_ground: bool
var splash: float
var target: Enemy
## Shells: total flight distance and progress, for the arc drawn by the view.
var flight: float
var travelled: float = 0.0
var age: int = 0
var alive: bool = true

## What happened during the last update().
var outcome: Outcome = Outcome.NONE
var hit_enemy: Enemy = null ## Outcome.HIT: the enemy that was hit


## `aim` is where a shell explodes (other bullets ignore it).
func _init(p_x: float, p_y: float, p_angle: float, p_speed: float, p_damage: float, p_type: Towers.BulletType,
		p_hits_air: bool, p_hits_ground: bool, p_target: Enemy = null, aim_x: float = NAN, aim_y: float = NAN,
		p_splash: float = 0.0) -> void:
	id = _next_id
	_next_id += 1
	x = p_x
	prev_x = p_x
	y = p_y
	prev_y = p_y
	angle = p_angle
	speed = p_speed
	damage = p_damage
	type = p_type
	hits_air = p_hits_air
	hits_ground = p_hits_ground
	splash = p_splash
	target = p_target
	radius = 2.5 if type == Towers.BulletType.NORMAL else 4.0
	flight = 0.0 if is_nan(aim_x) else MathX.hypot(aim_x - p_x, aim_y - p_y)


## Moves the bullet. Returns what happened this tick (see `outcome`, `hit_enemy`).
func update(enemies: Array[Enemy]) -> Outcome:
	prev_x = x
	prev_y = y
	age += 1
	outcome = Outcome.NONE
	hit_enemy = null

	# Missiles steer towards their target while it's alive, then fly straight.
	if type == Towers.BulletType.MISSILE and target != null and target.alive:
		var want: float = atan2(target.y - y, target.x - x)
		var diff: float = MathX.angle_diff(angle, want)
		angle += maxf(-MISSILE_TURN_RATE, minf(MISSILE_TURN_RATE, diff))

	# Shells fly over everything and burst at their aim point.
	if type == Towers.BulletType.SHELL:
		var step: float = minf(speed, flight - travelled)
		x += cos(angle) * step
		y += sin(angle) * step
		travelled += step
		if travelled >= flight - 1e-6:
			alive = false
			outcome = Outcome.EXPLODE
		return outcome

	x += cos(angle) * speed
	y += sin(angle) * speed

	var hit: Enemy = find_hit(enemies)
	if hit != null:
		alive = false
		outcome = Outcome.HIT
		hit_enemy = hit
		return outcome
	if age > MAX_LIFETIME or x < -50 or x > Config.FIELD_W + 50 or y < -50 or y > Config.FIELD_H + 50:
		alive = false
	return outcome


func can_hit(e: Enemy) -> bool:
	return e.alive and (hits_air if e.flying else hits_ground)


## Swept collision: tests the whole segment travelled during this tick, so
## fast bullets can't tunnel through enemies. Returns the first enemy hit.
func find_hit(enemies: Array[Enemy]) -> Enemy:
	var sx: float = prev_x
	var sy: float = prev_y
	var dx: float = x - sx
	var dy: float = y - sy
	var len2: float = dx * dx + dy * dy
	var best: Enemy = null
	var best_t: float = INF
	for e: Enemy in enemies:
		if not e.alive or not (hits_air if e.flying else hits_ground): # can_hit(), inlined
			continue
		var r: float = e.radius + radius
		var t: float = ((e.x - sx) * dx + (e.y - sy) * dy) / len2 if len2 > 0 else 0.0
		t = maxf(0.0, minf(1.0, t))
		var qx: float = sx + dx * t - e.x
		var qy: float = sy + dy * t - e.y
		if qx * qx + qy * qy <= r * r and t < best_t:
			best = e
			best_t = t
	return best
