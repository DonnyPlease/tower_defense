class_name EnemyView
extends Node2D
## Draws one enemy and its shadow. The body turns with the enemy, flashes
## white when hit and is tinted blue while slowed.

const DEPTH_SHADOW: int = 5
const DEPTH_GROUND: int = 20
const DEPTH_AIR: int = 26
const SLOWED_TINT: Color = Color("#9fdcff")

static var _flash_material: ShaderMaterial = null

var enemy: Enemy
var _shadow: DrawNode
var _body: DrawNode


static func flash_material() -> ShaderMaterial:
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = load("res://src/view/flash.gdshader")
	return _flash_material


func _init(e: Enemy) -> void:
	enemy = e
	var size: float = e.radius * 2.2
	var flying: bool = e.flying
	var sw: float = size * (0.7 if flying else 1.0)
	var sh: float = size * (0.45 if flying else 0.65)
	var shadow_alpha: float = 0.28 * (0.6 if flying else 1.0)
	_shadow = DrawNode.new(func(ci: CanvasItem) -> void:
		Paint.fill_ellipse(ci, 0, 0, sw, sh, Color(0, 0, 0, shadow_alpha)), DEPTH_SHADOW)
	_shadow.position = Vector2(8, 16) if flying else Vector2(2, 5)
	add_child(_shadow)
	_body = DrawNode.new(func(ci: CanvasItem) -> void: EnemyArt.draw(ci, enemy.def.art), DEPTH_AIR if flying else DEPTH_GROUND)
	_body.scale = Vector2.ONE * e.def.scale
	add_child(_body)


func sync(alpha: float, frame_count: int) -> void:
	var e: Enemy = enemy
	position = Vector2(Format.lerp_value(e.prev_x, e.x, alpha), Format.lerp_value(e.prev_y, e.y, alpha))
	var bob: float = sin((frame_count + e.id * 13) * 0.12) * 2 if e.flying else 0.0
	# Hoppers leap over walls and towers: up in the air, above the towers.
	var jumping: bool = e.is_jumping()
	if jumping:
		bob = -12.0
	_body.z_index = DEPTH_AIR if (e.flying or jumping) else DEPTH_GROUND
	_body.position = Vector2(0, bob)
	_body.rotation = Format.lerp_angle_short(e.prev_angle, e.angle, alpha)
	if e.hit_flash > 0:
		_body.material = flash_material()
	else:
		_body.material = null
		if e.slow > 0:
			_body.modulate = SLOWED_TINT
		elif e.def.has_tint:
			_body.modulate = e.def.tint
		else:
			_body.modulate = Color.WHITE


func is_flashing() -> bool:
	return _body.material != null


## Where the body is drawn relative to the enemy (hoppers rise while jumping), and its depth.
func body_offset() -> Vector2:
	return _body.position


func body_depth() -> int:
	return _body.z_index
