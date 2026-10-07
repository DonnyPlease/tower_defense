class_name Wave
extends RefCounted
## One wave: groups of enemies that spawn in parallel.

var groups: Array[SpawnGroup]


func _init(p_groups: Array[SpawnGroup] = []) -> void:
	groups = p_groups


func has_boss() -> bool:
	for g: SpawnGroup in groups:
		if Enemies.get_def(g.type).boss:
			return true
	return false


func has_type(type: String) -> bool:
	for g: SpawnGroup in groups:
		if g.type == type:
			return true
	return false


func total_count() -> int:
	var n: int = 0
	for g: SpawnGroup in groups:
		n += g.count
	return n
