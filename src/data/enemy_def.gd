class_name EnemyDef
extends RefCounted
## One enemy type. Abilities (armor, shield, flying, split, heal, summon, EMP,
## rally, hopping, boss phases) are just fields.


## Spawns `count` enemies of `type` when killed.
class Split:
	var type: String
	var count: int

	func _init(p_type: String, p_count: int) -> void:
		type = p_type
		count = p_count


## Heals nearby enemies by `fraction` of their max hitpoints every `interval` seconds.
class Heal:
	var radius: float
	var fraction: float
	var interval: float

	func _init(p_radius: float, p_fraction: float, p_interval: float) -> void:
		radius = p_radius
		fraction = p_fraction
		interval = p_interval


## Boss ability: calls in `count` enemies of `type` every `interval` seconds.
class Summon:
	var type: String
	var count: int
	var interval: float

	func _init(p_type: String, p_count: int, p_interval: float) -> void:
		type = p_type
		count = p_count
		interval = p_interval


## Saboteur: every `interval` seconds, switches off the towers within `radius` for `duration` seconds.
class Emp:
	var radius: float
	var duration: float
	var interval: float

	func _init(p_radius: float, p_duration: float, p_interval: float) -> void:
		radius = p_radius
		duration = p_duration
		interval = p_interval


## Warchief: other enemies within `radius` move `speed` faster (0.3 = +30 %)
## and take `toughness` less damage (0.25 = -25 %).
class Rally:
	var radius: float
	var speed: float
	var toughness: float

	func _init(p_radius: float, p_speed: float, p_toughness: float) -> void:
		radius = p_radius
		speed = p_speed
		toughness = p_toughness


## A boss phase: when hitpoints fall below `below` (a fraction), the boss
## changes. Phases happen in order, once each.
class Phase:
	var below: float
	var message: String
	var armor: float
	var speed: float ## speed multiplier from now on
	var summon_type: String = ""
	var summon_count: int = 0
	var shield: float = 0.0 ## raises a shield of this many points (scaled like hitpoints)

	func _init(p_below: float, p_message: String, p_armor: float, p_speed: float) -> void:
		below = p_below
		message = p_message
		armor = p_armor
		speed = p_speed

	func with_summon(type: String, count: int) -> Phase:
		summon_type = type
		summon_count = count
		return self

	func with_shield(points: float) -> Phase:
		shield = points
		return self


var type: String
var name: String
## Which art to draw: scout, racer and tank come from res://assets/enemies,
## the rest are drawn in code (src/view/enemy_art.gd).
var art: String
var tint: Color = Color.WHITE
var has_tint: bool = false
var scale: float = 1.0
var speed: float ## pixels per tick
var hitpoints: float
var reward: int
var damage: int ## lives lost when it escapes
var radius: float
var armor: float = 0.0 ## flat damage reduction per hit (a hit always does at least 25 %)
var shield: float = 0.0 ## regenerating shield points on top of hitpoints
var flying: bool = false ## ignores the road and flies straight to the exit
var split: Split = null
var heal: Heal = null
var summon: Summon = null
var emp: Emp = null
var rally: Rally = null
var hops: bool = false ## jumps over walls and towers (ignores them when finding its way)
var phases: Array[Phase] = []
var boss: bool = false
var description: String
