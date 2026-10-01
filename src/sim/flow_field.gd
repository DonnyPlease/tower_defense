class_name FlowField
extends RefCounted
## The distance field enemies follow in maze levels (see GameMap.distance_field).
## The world replaces `dist` whenever towers change; every FlowNav shares this
## holder, so they re-route around new walls immediately.

var dist: PackedInt32Array


func _init(p_dist: PackedInt32Array = PackedInt32Array()) -> void:
	dist = p_dist
