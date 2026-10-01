class_name ScreenFx
extends Node
## Camera-style effects for a screen: shaking (moves `target`) and a
## full-screen colour flash that fades out.

var target: Node2D
var _flash: ColorRect
var _shake_left: float = 0.0
var _shake_intensity: float = 0.0
var _flash_left: float = 0.0
var _flash_duration: float = 0.0


func _init(p_target: Node2D, flash_parent: Node) -> void:
	target = p_target
	_flash = ColorRect.new()
	_flash.size = Vector2(Config.WIDTH, Config.HEIGHT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.z_index = 300
	_flash.visible = false
	flash_parent.add_child(_flash)


## Shakes for `duration_ms`; `intensity` is a fraction of the screen size.
func shake(duration_ms: float, intensity: float) -> void:
	_shake_left = maxf(_shake_left, duration_ms / 1000.0)
	_shake_intensity = maxf(_shake_intensity if _shake_left > 0 else 0.0, intensity)


## Fills the screen with `color`, fading out over `duration_ms`.
func flash(duration_ms: float, color: Color) -> void:
	_flash_duration = duration_ms / 1000.0
	_flash_left = _flash_duration
	_flash.color = color
	_flash.visible = true


func is_shaking() -> bool:
	return _shake_left > 0


func is_flashing() -> bool:
	return _flash.visible


func _process(delta: float) -> void:
	if _shake_left > 0:
		_shake_left -= delta
		if _shake_left <= 0:
			_shake_intensity = 0.0
			target.position = Vector2.ZERO
		else:
			var dx: float = Config.WIDTH * _shake_intensity
			var dy: float = Config.HEIGHT * _shake_intensity
			target.position = Vector2(randf_range(-dx, dx), randf_range(-dy, dy))
	if _flash_left > 0:
		_flash_left -= delta
		_flash.color.a = maxf(0.0, _flash_left / _flash_duration)
		_flash.visible = _flash_left > 0
