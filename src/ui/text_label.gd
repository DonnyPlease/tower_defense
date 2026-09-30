class_name TextLabel
extends Label
## A label that keeps a chosen point of its box (`origin`, 0..1 per axis) at
## `at` whenever its text changes, like Phaser text objects. Create with Ui.text().

var at: Vector2 = Vector2.ZERO
var origin: Vector2 = Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Sets the text (if it changed) and re-anchors the label.
func show_text(value: String) -> TextLabel:
	if text != value:
		text = value
		place()
	return self


func set_color(color: Color) -> TextLabel:
	if label_settings.font_color != color:
		label_settings.font_color = color
	return self


## Text stroke, like Phaser's stroke + strokeThickness.
func set_outline(thickness: int, color: Color = Color.BLACK) -> TextLabel:
	label_settings.outline_size = thickness
	label_settings.outline_color = color
	place()
	return self


## Wraps the text at `width` pixels.
func set_wrap(width: float) -> TextLabel:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	custom_minimum_size.x = width
	place()
	return self


func set_line_spacing(spacing: float) -> TextLabel:
	label_settings.line_spacing = spacing
	place()
	return self


func move_to(x: float, y: float) -> TextLabel:
	at = Vector2(x, y)
	place()
	return self


func place() -> void:
	reset_size()
	position = at - size * origin
