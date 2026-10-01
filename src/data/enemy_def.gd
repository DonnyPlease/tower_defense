class_name EnemyDef
extends RefCounted
## One enemy type. Abilities (armor, shield, flying, split, heal, summon) are just fields.


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
var boss: bool = false
var description: String
