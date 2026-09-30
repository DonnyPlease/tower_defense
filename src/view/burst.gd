class_name Burst
extends Node2D
## A particle emitter that works like Phaser's: every particle flies off at a
## random angle with a random speed, and shrinks / fades / falls over its
## life. Particles are round dots (radius 8 at scale 1) in one of `tints`.

var speed_min: float = 0.0
var speed_max: float = 0.0
var life_min: float = 0.5 ## seconds
var life_max: float = 0.5
var scale_start: float = 1.0
var scale_end: float = 1.0
var alpha_start: float = 1.0
var alpha_end: float = 1.0
var gravity_y: float = 0.0 ## pixels per second squared
var tints: Array[Color] = [Color.WHITE]

var _x := PackedFloat32Array()
var _y := PackedFloat32Array()
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _tint := PackedInt32Array()


func _init(depth: int) -> void:
	z_index = depth
	z_as_relative = false


func speed(min_value: float, max_value: float) -> Burst:
	speed_min = min_value
	speed_max = max_value
	return self


## Lifespan in milliseconds (a random value in [min, max]).
func lifespan(min_ms: float, max_ms: float = -1.0) -> Burst:
	life_min = min_ms / 1000.0
	life_max = (min_ms if max_ms < 0 else max_ms) / 1000.0
	return self


func scale_over_life(start: float, end: float) -> Burst:
	scale_start = start
	scale_end = end
	return self


func alpha_over_life(start: float, end: float) -> Burst:
	alpha_start = start
	alpha_end = end
	return self


func gravity(y: float) -> Burst:
	gravity_y = y
	return self


func colors(hexes: Array[int]) -> Burst:
	tints = []
	for h: int in hexes:
		tints.append(Palette.rgb(h))
	return self


func count() -> int:
	return _x.size()


## Emits `amount` particles at (x, y).
func explode(amount: int, x: float, y: float) -> void:
	for i: int in amount:
		var a: float = randf() * TAU
		var v: float = randf_range(speed_min, speed_max)
		_x.append(x)
		_y.append(y)
		_vx.append(cos(a) * v)
		_vy.append(sin(a) * v)
		_age.append(0.0)
		_life.append(randf_range(life_min, life_max))
		_tint.append(randi() % tints.size())
	queue_redraw()


func _process(delta: float) -> void:
	if _x.is_empty():
		return
	var i: int = 0
	while i < _x.size():
		_age[i] += delta
		if _age[i] >= _life[i]:
			_remove(i)
			continue
		_vy[i] += gravity_y * delta
		_x[i] += _vx[i] * delta
		_y[i] += _vy[i] * delta
		i += 1
	queue_redraw()


func _remove(i: int) -> void:
	# Swap-remove: move the last particle into slot i.
	var last: int = _x.size() - 1
	_x[i] = _x[last]
	_y[i] = _y[last]
	_vx[i] = _vx[last]
	_vy[i] = _vy[last]
	_age[i] = _age[last]
	_life[i] = _life[last]
	_tint[i] = _tint[last]
	_x.resize(last)
	_y.resize(last)
	_vx.resize(last)
	_vy.resize(last)
	_age.resize(last)
	_life.resize(last)
	_tint.resize(last)


func _draw() -> void:
	for i: int in _x.size():
		var t: float = _age[i] / _life[i]
		var r: float = 8.0 * lerpf(scale_start, scale_end, t)
		if r <= 0.05:
			continue
		var color: Color = tints[_tint[i]]
		color.a = lerpf(alpha_start, alpha_end, t)
		draw_circle(Vector2(_x[i], _y[i]), r, color)
