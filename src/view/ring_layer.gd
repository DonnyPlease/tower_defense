class_name RingLayer
extends Node2D
## Expanding, fading rings (explosions, frost pulses, heals, upgrades).


class Ring:
	var x: float
	var y: float
	var radius: float
	var color: Color
	var duration: float
	var age: float = 0.0


var _rings: Array[Ring] = []


func _init(depth: int) -> void:
	z_index = depth
	z_as_relative = false


## A ring at (x, y) growing to `radius` over `duration_ms`, fading out.
func add(x: float, y: float, radius: float, color: Color, duration_ms: float = 450.0) -> void:
	var r := Ring.new()
	r.x = x
	r.y = y
	r.radius = radius
	r.color = color
	r.duration = duration_ms / 1000.0
	_rings.append(r)
	queue_redraw()


func count() -> int:
	return _rings.size()


func _process(delta: float) -> void:
	if _rings.is_empty():
		return
	var alive: Array[Ring] = []
	for r: Ring in _rings:
		r.age += delta
		if r.age < r.duration:
			alive.append(r)
	_rings = alive
	queue_redraw()


func _draw() -> void:
	for r: Ring in _rings:
		# Cubic ease-out on both the size and the fade, like the original tween.
		var e: float = 1.0 - pow(1.0 - r.age / r.duration, 3)
		# The ring image is a 6 px wide circle of radius 60 in a 128 px square,
		# scaled from 0.1 to radius * 2 / 128.
		var s: float = lerpf(0.1, r.radius * 2 / 128.0, e)
		var color := Color(r.color, 0.8 * (1.0 - e))
		draw_arc(Vector2(r.x, r.y), 60 * s, 0, TAU, 48, color, 6 * s, true)
