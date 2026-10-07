class_name TowerView
extends Node2D
## Draws one tower: a shadow, the still base plate (Gun, Missile) and the
## body, which turns towards the target and plays the firing animation.

const DEPTH_SHADOW: int = 5
const DEPTH_BASE: int = 9
const DEPTH_BODY: int = 10

var tower: Tower
var _base: DrawNode = null
var _body: DrawNode
var _frame: int = 0


func _init(t: Tower) -> void:
	tower = t
	position = Vector2(t.x, t.y)
	var shadow := DrawNode.new(func(ci: CanvasItem) -> void:
		Paint.fill_ellipse(ci, 0, 3, 34, 20, Color(0, 0, 0, 0.28)), DEPTH_SHADOW)
	add_child(shadow)
	if TowerArt.has_base(t.kind):
		_base = DrawNode.new(func(ci: CanvasItem) -> void: TowerArt.draw_base(ci, tower.kind), DEPTH_BASE)
		add_child(_base)
	_body = DrawNode.new(func(ci: CanvasItem) -> void: TowerArt.draw_body(ci, tower.kind, _frame), DEPTH_BODY)
	add_child(_body)


func sync(alpha: float, frame_count: int) -> void:
	var t: Tower = tower
	var frames: int = t.def.frames
	if frames > 1:
		var f: int = floori(t.frame) % frames
		if f != _frame:
			_frame = f
			_body.queue_redraw()
	var rotates: bool = t.def.behavior == Towers.Behavior.PROJECTILE or t.def.behavior == Towers.Behavior.BEAM
	# The art points up, simulation angle 0 points right.
	_body.rotation = Format.lerp_angle_short(t.prev_angle, t.angle, alpha) + PI / 2 if rotates else 0.0
	if t.def.behavior == Towers.Behavior.SUPPORT:
		_body.rotation = frame_count * 0.02
	var recoil: float = 0.9 if frames == 1 and t.shooting else 1.0
	var level_scale: float = 1 + 0.06 * t.level
	_body.scale = Vector2.ONE * level_scale * recoil
	if _base != null:
		_base.scale = Vector2.ONE * level_scale
