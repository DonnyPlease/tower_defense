class_name TowerLevel
extends RefCounted
## Stats of one tower level. The fields after `buff` are only used by some
## branches (see TowerBranch); their defaults leave the tower as it was.

var cost: int
var attack_range: float
var damage: float ## per shot; per second for beams; per pulse for auras
var fire_rate: float ## shots (or pulses) per second
var splash: float = 0.0 ## cannon: explosion radius
var slow: float = 0.0 ## frost: speed reduction, 0.4 = 40 % slower
var buff: float = 0.0 ## support: fire-rate bonus for nearby towers, 0.2 = +20 %
var max_heat: float = 2.0 ## laser: extra damage multiplier at full heat (2 = up to 3x)
var heat_time: float = 2.0 ## laser: seconds on one target to reach full heat
var spin_up: float = 0.0 ## minigun: seconds of firing to reach the full fire rate
var pierce: int = 0 ## sniper: enemies one shot goes through (0 = an ordinary bullet)
var volley: int = 1 ## swarm: missiles per shot, at different targets
var boss_bonus: float = 1.0 ## seeker: damage multiplier against bosses
var min_range: float = 0.0 ## mortar: can't hit enemies closer than this
var stun: float = 0.0 ## cryo: seconds a pulse freezes enemies (bosses a third)
var vulnerability: float = 0.0 ## cryo: chilled enemies take this much more damage (0.3 = +30 %)
var beams: int = 1 ## prism: enemies burned at once
var range_buff: float = 0.0 ## command: range bonus for nearby towers


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


func with_heat(max_value: float, seconds: float) -> TowerLevel:
	max_heat = max_value
	heat_time = seconds
	return self


func with_spin_up(seconds: float) -> TowerLevel:
	spin_up = seconds
	return self


func with_pierce(count: int) -> TowerLevel:
	pierce = count
	return self


func with_volley(count: int) -> TowerLevel:
	volley = count
	return self


func with_boss_bonus(value: float) -> TowerLevel:
	boss_bonus = value
	return self


func with_min_range(value: float) -> TowerLevel:
	min_range = value
	return self


func with_freeze(seconds: float, extra_damage: float) -> TowerLevel:
	stun = seconds
	vulnerability = extra_damage
	return self


func with_beams(count: int) -> TowerLevel:
	beams = count
	return self


func with_range_buff(value: float) -> TowerLevel:
	range_buff = value
	return self
