class_name Tower
extends RefCounted
## One tower in the simulation.

const ANIMATION_SPEED: float = 0.35 # frames per tick while shooting
const MUZZLE: float = 16.0 # distance from the tower centre where bullets appear
const LASER_MAX_HEAT: float = 2.0 # extra damage multiplier at full heat (so up to 3x)
const LASER_HEAT_TIME: int = 2 * Config.TICK_RATE # ticks on one target to reach full heat
const SLOW_TICKS: int = 12 # frost slow lingers this long after leaving the aura
## upgrade_cost() at max level.
const NO_UPGRADE: int = -1

static var _next_id: int = 1

var id: int
var kind: String
var def: TowerDef
var col: int
var row: int
var x: float
var y: float
var high_ground: bool
## 0..2. Setting it updates `stats` and `attack_range`.
var level: int = 0:
	set(value):
		level = value
		_refresh_stats()
var target_mode: Towers.TargetMode = Towers.TargetMode.FIRST
var invested: int ## money spent on this tower, for the sell refund
var angle: float = -PI / 2 ## pointing up
var prev_angle: float = -PI / 2
var cooldown: int = 0 ## ticks until the next shot is allowed
var frame: float = 0.0 ## animation frame (fractional)
var shooting: bool = false
var target: Enemy = null
var buff: float = 0.0 ## fire-rate bonus from nearby beacons, set by the world every tick
var heat: int = 0 ## laser: ticks spent on the current target

## Stats of the current level.
var stats: TowerLevel
## Current range, including the high-ground bonus.
var attack_range: float

## Fire rate including the beacon boost.
var fire_rate: float:
	get:
		return stats.fire_rate * (1 + buff)

## Laser heat as 0..1.
var heat_fraction: float:
	get:
		return minf(1.0, float(heat) / LASER_HEAT_TIME)


## `invested` defaults to the build price.
func _init(p_kind: String, p_col: int, p_row: int, p_high_ground: bool = false, p_invested: int = -1) -> void:
	id = _next_id
	_next_id += 1
	kind = p_kind
	def = Towers.get_def(p_kind)
	col = p_col
	row = p_row
	x = p_col * Config.TILE + Config.TILE * 0.5
	y = p_row * Config.TILE + Config.TILE * 0.5
	high_ground = p_high_ground
	invested = p_invested if p_invested >= 0 else def.levels[0].cost
	_refresh_stats()


func _refresh_stats() -> void:
	stats = def.levels[level]
	attack_range = stats.attack_range * (Config.HIGH_GROUND_RANGE if high_ground else 1.0)


func is_max_level() -> bool:
	return level >= def.levels.size() - 1


## Base price of the next upgrade, or NO_UPGRADE at max level.
func upgrade_cost() -> int:
	return NO_UPGRADE if is_max_level() else def.levels[level + 1].cost


func sell_value() -> int:
	return floori(invested * Config.SELL_REFUND)


func can_target(e: Enemy) -> bool:
	return e.alive and (def.hits_air if e.flying else def.hits_ground)


## Whether a circle at (ex, ey) with radius `radius` touches the given range
## (default: this tower's range).
func in_range(ex: float, ey: float, radius: float, reach: float = -1.0) -> bool:
	var r: float = (attack_range if reach < 0 else reach) + radius
	var dx: float = ex - x
	var dy: float = ey - y
	return dx * dx + dy * dy <= r * r


func pick_target(enemies: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_score: float = -INF
	var hits_air: bool = def.hits_air
	var hits_ground: bool = def.hits_ground
	for e: Enemy in enemies:
		# can_target() and in_range(), inlined: this is the game's hottest loop.
		if not e.alive or not (hits_air if e.flying else hits_ground):
			continue
		var reach: float = attack_range + e.radius
		var dx: float = e.x - x
		var dy: float = e.y - y
		if dx * dx + dy * dy > reach * reach:
			continue
		var score: float
		match target_mode:
			Towers.TargetMode.FIRST:
				score = -e.remaining
			Towers.TargetMode.LAST:
				score = e.remaining
			Towers.TargetMode.STRONGEST:
				score = e.hitpoints + e.shield
			Towers.TargetMode.CLOSEST:
				score = -MathX.hypot(e.x - x, e.y - y)
		if score > best_score:
			best = e
			best_score = score
	return best


func update(world: World) -> void:
	prev_angle = angle
	if cooldown > 0:
		cooldown -= 1
	if shooting:
		frame += ANIMATION_SPEED
		if frame >= def.frames:
			frame = 0.0
			shooting = false
	match def.behavior:
		Towers.Behavior.PROJECTILE:
			_update_projectile(world)
		Towers.Behavior.BEAM:
			_update_beam(world)
		Towers.Behavior.AURA:
			_update_aura(world)
		Towers.Behavior.SUPPORT:
			pass # handled by the world (buffs)


func _start_shot() -> void:
	cooldown = MathX.js_round(Config.TICK_RATE / fire_rate)
	shooting = true
	frame = 0.0


func _update_projectile(world: World) -> void:
	target = pick_target(world.enemies)
	if target == null:
		return
	var speed: float = def.bullet_speed
	# Missiles home in, so they aim at the target; the rest lead it.
	var aim_x: float = target.x
	var aim_y: float = target.y
	if def.bullet != Towers.BulletType.MISSILE:
		var t: float = Aim.intercept_time(x, y, target.x, target.y, target.vx, target.vy, speed)
		if t > 0:
			aim_x = target.x + target.vx * t
			aim_y = target.y + target.vy * t
	angle = atan2(aim_y - y, aim_x - x)
	if cooldown > 0:
		return
	_start_shot()
	world.fire(Bullet.new(
		x + cos(angle) * MUZZLE,
		y + sin(angle) * MUZZLE,
		angle,
		speed,
		stats.damage * world.damage_multiplier,
		def.bullet,
		def.hits_air,
		def.hits_ground,
		target,
		aim_x,
		aim_y,
		stats.splash,
	), self)


func _update_beam(world: World) -> void:
	var previous: Enemy = target
	# Keep burning the same target while it stays in range, to build heat.
	if previous != null and can_target(previous) and in_range(previous.x, previous.y, previous.radius):
		target = previous
	else:
		target = pick_target(world.enemies)
	if target == null:
		heat = 0
		return
	heat = heat + 1 if target == previous else 0
	angle = atan2(target.y - y, target.x - x)
	var per_tick: float = (stats.damage * (1 + buff) * world.damage_multiplier) / Config.TICK_RATE
	world.damage_enemy(target, per_tick * (1 + LASER_MAX_HEAT * heat_fraction), def.ignores_armor, false)


func _update_aura(world: World) -> void:
	var slow: float = stats.slow
	var any: bool = false
	for e: Enemy in world.enemies:
		if can_target(e) and in_range(e.x, e.y, e.radius):
			e.apply_slow(slow, SLOW_TICKS)
			any = true
	if not any or cooldown > 0:
		return
	_start_shot()
	world.pulse(self)
	# Index loop: enemies split by this pulse are appended and hit too, as before.
	var i: int = 0
	while i < world.enemies.size():
		var e: Enemy = world.enemies[i]
		if can_target(e) and in_range(e.x, e.y, e.radius):
			world.damage_enemy(e, stats.damage * world.damage_multiplier, false, true)
		i += 1
