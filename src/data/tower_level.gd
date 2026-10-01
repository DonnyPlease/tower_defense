class_name TowerLevel
extends RefCounted
## Stats of one tower level.

var cost: int
var attack_range: float
var damage: float ## per shot; per second for beams; per pulse for auras
var fire_rate: float ## shots (or pulses) per second
var splash: float = 0.0 ## cannon: explosion radius
var slow: float = 0.0 ## frost: speed reduction, 0.4 = 40 % slower
var buff: float = 0.0 ## support: fire-rate bonus for nearby towers, 0.2 = +20 %


func _init(p_cost: int, p_range: float, p_damage: float, p_fire_rate: float) -> void:
	cost = p_cost
	attack_range = p_range
	damage = p_damage
	fire_rate = p_fire_rate


func with_splash(value: float) -> TowerLevel:
	splash = value
	return self


func with_slow(value: float) -> TowerLevel:
	slow = value
	return self


func with_buff(value: float) -> TowerLevel:
	buff = value
	return self
