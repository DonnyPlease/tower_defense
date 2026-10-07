class_name TowerBranch
extends RefCounted
## One of the two towers a tower can become after its third level (a Gun
## becomes a Minigun or a Sniper, ...). It has two levels of its own: the
## tower's levels 4 and 5. levels[0].cost is the price of choosing it.
## Fields left at their defaults keep the base tower's behaviour.

var id: String
var kind: String ## the tower it grows from
var name: String
var description: String
var levels: Array[TowerLevel]
var color: Color ## accent colour for UI and effects
## Bullets: 0 keeps the base tower's speed.
var bullet_speed: float = 0.0
var ignores_armor: bool = false
## Projectiles aim where a moving target will be (false: where it is now, so
## slow shells miss fast enemies).
var leads: bool = true


func _init(p_id: String, p_kind: String, p_name: String, p_description: String, p_color: int,
		p_levels: Array[TowerLevel]) -> void:
	id = p_id
	kind = p_kind
	name = p_name
	description = p_description
	color = Palette.rgb(p_color)
	levels = p_levels
