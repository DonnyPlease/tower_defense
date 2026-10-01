class_name SpawnGroup
extends RefCounted
## Spawns `count` enemies of `type`, one every `interval` seconds, starting
## `delay` seconds after the wave begins.

var type: String
var count: int
var interval: float
var delay: float


func _init(p_type: String, p_count: int, p_interval: float, p_delay: float = 0.0) -> void:
	type = p_type
	count = p_count
	interval = p_interval
	delay = p_delay
