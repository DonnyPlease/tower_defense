class_name NightLayer
extends ColorRect
## Night variants: darkness over the field, lit around every tower (a shader).

const MAX_LIGHTS: int = 64
const LIGHT_RADIUS: float = 70.0
const DEPTH: int = 39 ## over towers and enemies, under health bars and effects

var _material := ShaderMaterial.new()


func _init() -> void:
	size = Vector2(Config.FIELD_W, Config.FIELD_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = DEPTH
	z_as_relative = false
	_material.shader = load("res://src/view/night.gdshader")
	_material.set_shader_parameter("field_size", size)
	material = _material


## Puts a light on every tower (and the exits, so the way out is never lost).
func sync(world: World) -> void:
	var lights: Array[Vector4] = []
	for e: Vector2i in world.map.ends:
		var p: Vector2 = GameMap.tile_center(e)
		lights.append(Vector4(p.x, p.y, LIGHT_RADIUS, 0))
	for t: Tower in world.towers:
		if lights.size() >= MAX_LIGHTS:
			break
		lights.append(Vector4(t.x, t.y, LIGHT_RADIUS, 0))
	var packed: Array[Vector4] = lights.duplicate()
	packed.resize(MAX_LIGHTS)
	for i: int in range(lights.size(), MAX_LIGHTS):
		packed[i] = Vector4.ZERO
	_material.set_shader_parameter("lights", packed)
	_material.set_shader_parameter("count", lights.size())
