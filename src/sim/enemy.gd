class_name Enemy
extends RefCounted
## One enemy in the simulation.

const SHIELD_DELAY: int = 3 * Config.TICK_RATE # ticks without damage before the shield recharges
const SHIELD_REGEN: float = 0.25 / Config.TICK_RATE # fraction of max shield per tick
const MIN_DAMAGE_FRACTION: float = 0.25 # armor never blocks more than 75 % of a hit

static var _next_id: int = 1

var id: int
var type: String
var def: EnemyDef
var nav: Nav
var radius: float
var max_hitpoints: float
var max_shield: float
var hitpoints: float
var shield: float
var flying: bool

var x: float
var y: float
var prev_x: float ## position at the previous tick, for render interpolation
var prev_y: float
var vx: float = 0.0 ## displacement during the last tick, used for aim prediction
var vy: float = 0.0
var angle: float ## smoothed heading, for drawing
var prev_angle: float
var remaining: float = INF ## path length left to the exit, used for "first"/"last" targeting
var alive: bool = true
var escaped: bool = false

var slow: float = 0.0 ## current speed reduction 0..1
var hit_flash: int = 0 ## ticks left of the white "got hit" flash
var mark_ticks: int = 0 ## ticks left of a focus mark (it takes more damage while marked)
var mark_factor: float = 1.0 ## damage multiplier while marked
var ability_timer: int = 0 ## ticks until the next heal / summon
var armor: float ## flat damage reduction per hit (a boss phase can change it)
var phase: int = 0 ## boss phases passed (EnemyDef.phases)
var speed_mult: float = 1.0 ## from boss phases
var rallied: bool = false ## near a warchief (set by the world every tick)
var rally_speed: float = 0.0
var rally_toughness: float = 0.0
## Hoppers: the world's obstacles, to know when they are in the air.
var obstacles: FlowField = null
var stun_ticks: int = 0 ## ticks left frozen solid (a cryo pulse): it doesn't move
var vulnerability: float = 0.0 ## extra damage taken while chilled by a cryo tower (0.3 = +30 %)

var _slow_ticks: int = 0
var _chill_ticks: int = 0
var _shield_cooldown: int = 0

## Current speed in pixels per tick (slowed by frost).
var speed: float:
	get:
		return def.speed * (1 - slow)


func _init(p_type: String, p_nav: Nav, hp_multiplier: float = 1.0) -> void:
	id = _next_id
	_next_id += 1
	type = p_type
	nav = p_nav
	def = Enemies.get_def(p_type)
	radius = def.radius
	flying = def.flying
	armor = def.armor
	max_hitpoints = MathX.js_round(def.hitpoints * hp_multiplier)
	hitpoints = max_hitpoints
	max_shield = MathX.js_round(def.shield * hp_multiplier)
	shield = max_shield
	x = nav.x
	prev_x = x
	y = nav.y
	prev_y = y
	angle = nav.heading
	prev_angle = angle
	var ability: float = 0.0
	if def.heal != null:
		ability = def.heal.interval
	elif def.summon != null:
		ability = def.summon.interval
	elif def.emp != null:
		ability = def.emp.interval
	ability_timer = MathX.js_round(ability * Config.TICK_RATE)
	remaining = nav.remaining()


## Walks along the path (the Nav decides how). `extra_slow` (0..1) is a speed
## reduction on top of frost that applies to every enemy, flying ones too (time slow).
func update(extra_slow: float = 0.0) -> void:
	prev_x = x
	prev_y = y
	prev_angle = angle
	if hit_flash > 0:
		hit_flash -= 1
	if mark_ticks > 0:
		mark_ticks -= 1
	if _slow_ticks > 0:
		_slow_ticks -= 1
		if _slow_ticks == 0:
			slow = 0.0
	if _chill_ticks > 0:
		_chill_ticks -= 1
		if _chill_ticks == 0:
			vulnerability = 0.0
	if max_shield > 0:
		if _shield_cooldown > 0:
			_shield_cooldown -= 1
		else:
			shield = minf(max_shield, shield + max_shield * SHIELD_REGEN)
	if stun_ticks > 0:
		stun_ticks -= 1
		vx = 0.0
		vy = 0.0
		return

	if not nav.move(def.speed * speed_factor() * (1 - maxf(slow, extra_slow))):
		alive = false
		escaped = true
	x = nav.x
	y = nav.y
	vx = x - prev_x
	vy = y - prev_y
	remaining = nav.remaining()

	# Turn the sprite smoothly instead of snapping at corners.
	angle += MathX.angle_diff(angle, nav.heading) * 0.25


func is_marked() -> bool:
	return mark_ticks > 0


func mark(ticks: int, factor: float) -> void:
	mark_ticks = ticks
	mark_factor = factor


## Speed multiplier from boss phases and a warchief's rally (before slows).
func speed_factor() -> float:
	return speed_mult * (1 + rally_speed if rallied else 1.0)


## A hopper over a wall or a tower is in the air.
func is_jumping() -> bool:
	if not def.hops or obstacles == null or obstacles.blocked.is_empty():
		return false
	var col: int = floori(x / Config.TILE)
	var row: int = floori(y / Config.TILE)
	return GameMap.in_bounds(col, row) and obstacles.blocked[row * Config.COLS + col] != 0


func is_frozen() -> bool:
	return stun_ticks > 0


## Freezes it in place for `ticks` (a cryo pulse).
func freeze(ticks: int) -> void:
	stun_ticks = maxi(stun_ticks, ticks)


## While chilled it takes `factor` more damage from everything.
func chill(factor: float, ticks: int) -> void:
	vulnerability = maxf(vulnerability, factor)
	_chill_ticks = maxi(_chill_ticks, ticks)


func apply_slow(amount: float, ticks: int) -> void:
	if flying:
		return
	slow = maxf(slow, amount)
	_slow_ticks = maxi(_slow_ticks, ticks)


## Heals up to max hitpoints; returns how much was healed.
func heal(amount: float) -> float:
	var before: float = hitpoints
	hitpoints = minf(max_hitpoints, hitpoints + amount)
	return hitpoints - before


## Applies damage through armor and shield. Returns true when this hit killed the enemy.
func hit(damage: float, ignores_armor: bool = false, flash: bool = true) -> bool:
	if not alive or damage <= 0:
		return false
	var dmg: float = damage
	if armor > 0 and not ignores_armor:
		dmg = maxf(dmg * MIN_DAMAGE_FRACTION, dmg - armor)
	if max_shield > 0:
		_shield_cooldown = SHIELD_DELAY
		var absorbed: float = minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
	if flash:
		hit_flash = 4
	hitpoints -= dmg
	if hitpoints <= 0:
		hitpoints = 0.0
		alive = false
		return true
	return false
