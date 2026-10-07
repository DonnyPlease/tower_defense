class_name FlowField
extends RefCounted
## The distance field enemies follow in maze levels (see GameMap.distance_field).
## The world replaces `dist` whenever towers change; every FlowNav shares this
## holder, so they re-route around new walls immediately.

var dist: PackedInt32Array
## Distance units per tile: 1 for a plain field, GameMap.STEP_COST for a
## weighted one (with magnets).
var unit: int = 1
## 1 where a tower or wall stands (hoppers jump over these tiles).
var blocked: PackedByteArray


func _init(p_dist: PackedInt32Array = PackedInt32Array()) -> void:
	dist = p_dist
