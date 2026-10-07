class_name Tower
extends RefCounted
## One tower in the simulation.

const ANIMATION_SPEED: float = 0.35 # frames per tick while shooting
const MUZZLE: float = 16.0 # distance from the tower centre where bullets appear
const LASER_MAX_HEAT: float = 2.0 # extra damage multiplier at full heat (so up to 3x)
const LASER_HEAT_TIME: int = 2 * Config.TICK_RATE # ticks on one target to reach full heat
const SLOW_TICKS: int = 12 # frost slow lingers this long after leaving the aura
const MIN_SPIN: float = 0.25 # minigun: fraction of its fire rate when it starts spinning
const VOLLEY_SPREAD: float = 0.3 # swarm: radians between the missiles of a volley as they leave
## upgrade_cost() at max level (or when a branch must be chosen first).
const NO_UPGRADE: int = -1

static var _next_id: int = 1

var id: int
var kind: String
var def: TowerDef
## The branch it grew into after level 3 (null before).
var branch: TowerBranch = null
var col: int
var row: int
var x: float
var y: float
var high_ground: bool
## 0..4 (3 and 4 need a branch). Setting it updates `stats` and `attack_range`.
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
## Prism: every enemy being burned (the others: just `target`, or none).
var targets: Array[Enemy] = []
var buff: float = 0.0 ## fire-rate bonus from nearby beacons, set by the world every tick
var range_buff: float = 0.0 ## range bonus from a nearby command post, set by the world every tick
var range_factor: float = 1.0 ## the level's range multiplier (night), see set_range_factor
var heat: int = 0 ## laser: ticks spent on the current target
var spin: float = 0.0 ## minigun: 0..1, how far it has spun up

## Stats of the current level.
var stats: TowerLevel
## Current range, including the high-ground and command post bonuses.
var attack_range: float
var _base_range: float

## Fire rate including the beacon boost (and a minigun's spin).
var fire_rate: float:
	get:
		var rate: float = stats.fire_rate * (1 + buff)
		if stats.spin_up > 0:
			rate *= MIN_SPIN + (1 - MIN_SPIN) * spin
		return rate

## Laser heat as 0..1.
var heat_fraction: float:
	get:
		return minf(1.0, float(heat) / maxf(1.0, MathX.js_round(stats.heat_time * Config.TICK_RATE)))

## "" before a branch is chosen.
var branch_id: String:
	get:
		return branch.id if branch != null else ""

## The branch's name once it has one ("Minigun"), else the tower's ("Gun").
var display_name: String:
	get:
		return branch.name if branch != null else def.name

var bullet_speed: float:
	get:
		return branch.bullet_speed if branch != null and branch.bullet_speed > 0 else def.bullet_speed

var ignores_armor: bool:
	get:
		return def.ignores_armor or (branch != null and branch.ignores_armor)


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
	stats = Towers.level_stats(kind, level, branch_id)
	_base_range = stats.attack_range * (Config.HIGH_GROUND_RANGE if high_ground else 1.0) * range_factor
	attack_range = _base_range * (1 + range_buff)


## Grows into a branch: level 4, the branch's first level.
func set_branch(b: TowerBranch) -> void:
	branch = b
	level = Towers.BRANCH_LEVEL


func set_range_factor(value: float) -> void:
	range_factor = value
	_refresh_stats()


func set_range_buff(value: float) -> void:
	if value != range_buff:
		range_buff = value
		attack_range = _base_range * (1 + range_buff)


## At level 3 a tower grows only by choosing a branch.
func needs_branch() -> bool:
	return branch == null and level == Towers.BRANCH_LEVEL - 1 and not def.branches.is_empty()


func is_max_level() -> bool:
	if branch == null:
		return level >= Towers.BRANCH_LEVEL - 1 and def.branches.is_empty()
	return level >= Towers.MAX_LEVEL


## Base price of the next upgrade, or NO_UPGRADE at max level or when a branch must be chosen.
func upgrade_cost() -> int:
	if is_max_level() or needs_branch():
		return NO_UPGRADE
	return Towers.level_stats(kind, level + 1, branch_id).cost


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


func _score(e: Enemy) -> float:
	match target_mode:
		Towers.TargetMode.FIRST:
			return -e.remaining
		Towers.TargetMode.LAST:
			return e.remaining
		Towers.TargetMode.STRONGEST:
			return e.hitpoints + e.shield
		_:
			return -MathX.hypot(e.x - x, e.y - y)


func pick_target(enemies: Array[Enemy]) -> Enemy:
	var best: Enemy = null
	var best_score: float = -INF
	var hits_air: bool = def.hits_air
	var hits_ground: bool = def.hits_ground
	var min_reach: float = stats.min_range
	for e: Enemy in enemies:
		# can_target() and in_range(), inlined: this is the game's hottest loop.
		if not e.alive or not (hits_air if e.flying else hits_ground):
			continue
		var reach: float = attack_range + e.radius
		var dx: float = e.x - x
		var dy: float = e.y - y
		var d2: float = dx * dx + dy * dy
		if d2 > reach * reach:
			continue
		if min_reach > 0 and d2 < min_reach * min_reach:
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


## Up to `count` enemies in range, best first (by the target mode).
func pick_targets(enemies: Array[Enemy], count: int) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for e: Enemy in enemies:
		if can_target(e) and in_range(e.x, e.y, e.radius):
			found.append(e)
	if found.size() > count:
		var scores: Dictionary[Enemy, float] = {}
		for e: Enemy in found:
			scores[e] = _score(e)
		found.sort_custom(func(a: Enemy, b: Enemy) -> bool: return scores[a] > scores[b])
		found.resize(count)
	elif found.size() > 1:
		found.sort_custom(func(a: Enemy, b: Enemy) -> bool: return _score(a) > _score(b))
	return found


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


## Minigun: spins up while it has a target, twice as fast down without one.
func _spin(firing: bool) -> void:
	if stats.spin_up <= 0:
		return
	var step: float = 1.0 / (stats.spin_up * Config.TICK_RATE)
	spin = minf(1.0, spin + step) if firing else maxf(0.0, spin - 2 * step)


func _update_projectile(world: World) -> void:
	if stats.volley > 1:
		_update_volley(world)
		return
	target = pick_target(world.enemies)
	_spin(target != null)
	if target == null:
		return
	if stats.pierce > 0:
		angle = atan2(target.y - y, target.x - x)
		if cooldown > 0:
			return
		_start_shot()
		world.rail(self, angle, attack_range, stats.damage * world.damage_multiplier, stats.pierce)
		return
	var speed: float = bullet_speed
	# Missiles home in, so they aim at the target; the rest lead it (unless
	# the branch lobs its shells where the target is now).
	var aim_x: float = target.x
	var aim_y: float = target.y
	if def.bullet != Towers.BulletType.MISSILE and (branch == null or branch.leads):
		var t: float = Aim.intercept_time(x, y, target.x, target.y, target.vx, target.vy, speed)
		if t > 0:
			aim_x = target.x + target.vx * t
			aim_y = target.y + target.vy * t
	angle = atan2(aim_y - y, aim_x - x)
	if cooldown > 0:
		return
	_start_shot()
	var b := Bullet.new(
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
	)
	b.ignores_armor = ignores_armor
	b.boss_bonus = stats.boss_bonus
	if kind == "gun" and world.has_perk("piercing"):
		b.pierce_left = RunPerks.PIERCE
	if kind == "cannon" and world.has_perk("demolition"):
		b.splash *= RunPerks.DEMOLITION_SPLASH
	if stats.boss_bonus > 1:
		b.radius = 6.0 # a seeker's missile is a big one
	world.fire(b, self)


## Swarm: a volley of missiles, spread over the best targets in range.
func _update_volley(world: World) -> void:
	var picks: Array[Enemy] = pick_targets(world.enemies, stats.volley)
	target = picks[0] if not picks.is_empty() else null
	if target == null:
		return
	angle = atan2(target.y - y, target.x - x)
	if cooldown > 0:
		return
	_start_shot()
	for i: int in stats.volley:
		var tgt: Enemy = picks[i % picks.size()]
		var a: float = atan2(tgt.y - y, tgt.x - x) + (i - (stats.volley - 1) / 2.0) * VOLLEY_SPREAD
		var b := Bullet.new(x + cos(a) * MUZZLE, y + sin(a) * MUZZLE, a, bullet_speed,
			stats.damage * world.damage_multiplier, def.bullet, def.hits_air, def.hits_ground, tgt)
		b.radius = 3.0
		world.fire(b, self)


func _update_beam(world: World) -> void:
	if stats.beams > 1:
		_update_prism(world)
		return
	var previous: Enemy = target
	# Keep burning the same target while it stays in range, to build heat.
	if previous != null and can_target(previous) and in_range(previous.x, previous.y, previous.radius):
		target = previous
	else:
		target = pick_target(world.enemies)
	targets.clear()
	if target == null:
		heat = 0
		return
	targets.append(target)
	heat = heat + (2 if world.has_perk("overcharge") else 1) if target == previous else 0
	angle = atan2(target.y - y, target.x - x)
	world.damage_enemy(target, _beam_damage(world), ignores_armor, false)


## Prism: burns several enemies at once; heat builds while it burns anything.
func _update_prism(world: World) -> void:
	targets = pick_targets(world.enemies, stats.beams)
	target = targets[0] if not targets.is_empty() else null
	if target == null:
		heat = 0
		return
	heat += 2 if world.has_perk("overcharge") else 1
	angle = atan2(target.y - y, target.x - x)
	var per_tick: float = _beam_damage(world)
	for e: Enemy in targets.duplicate():
		world.damage_enemy(e, per_tick, ignores_armor, false)


func _beam_damage(world: World) -> float:
	var per_tick: float = (stats.damage * (1 + buff) * world.damage_multiplier) / Config.TICK_RATE
	return per_tick * (1 + stats.max_heat * heat_fraction)


func _update_aura(world: World) -> void:
	var slow: float = stats.slow
	var chill: float = stats.vulnerability
	var any: bool = false
	for e: Enemy in world.enemies:
		if can_target(e) and in_range(e.x, e.y, e.radius):
			e.apply_slow(slow, SLOW_TICKS)
			if chill > 0:
				e.chill(chill, SLOW_TICKS)
			any = true
	if not any or cooldown > 0:
		return
	_start_shot()
	world.pulse(self)
	if stats.damage <= 0 and stats.stun <= 0 and not world.has_perk("shatter"):
		return
	var freeze: int = MathX.js_round(stats.stun * Config.TICK_RATE)
	# Index loop: enemies split by this pulse are appended and hit too, as before.
	var i: int = 0
	while i < world.enemies.size():
		var e: Enemy = world.enemies[i]
		if can_target(e) and in_range(e.x, e.y, e.radius):
			if e.max_shield > 0 and world.has_perk("shatter"):
				e.shield = maxf(0.0, e.shield - e.max_shield * 0.5)
			if stats.damage > 0:
				world.damage_enemy(e, stats.damage * world.damage_multiplier, false, true)
			if freeze > 0 and e.alive:
				e.freeze(maxi(1, floori(freeze / 3.0)) if e.def.boss else freeze)
		i += 1
