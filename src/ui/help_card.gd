class_name HelpCard
extends Control
## A small card that explains what the pointer is on (a tower to build, an
## ability, a branch), placed beside it. Fades in; ignores the mouse.

const W: float = 232.0
const PAD: float = 14.0
const DEPTH: int = 180

var _title: TextLabel
var _body: TextLabel
var _extra: TextLabel
var _key: String = ""
var _tween: Tween


func _init() -> void:
	size = Vector2(W, 80)
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	_title = Ui.text(self, PAD, 10, "", 15, Palette.TEXT, true)
	_body = Ui.text(self, PAD, 34, "", 12, Palette.TEXT_DIM).set_wrap(W - 2 * PAD)
	_body.set_line_spacing(2)
	_extra = Ui.text(self, PAD, 0, "", 12, Palette.TEXT_DIM).set_wrap(W - 2 * PAD)
	_extra.set_line_spacing(2)


func _draw() -> void:
	Paint.fill_rounded_rect(self, 3, 4, size.x, size.y, 10, Color(0, 0, 0, 0.3))
	Paint.fill_rounded_rect(self, 0, 0, size.x, size.y, 10, Color(Palette.PANEL, 0.97))
	Paint.stroke_rounded_rect(self, 0, 0, size.x, size.y, 10, 1, Palette.BORDER)


## Shows a title and text beside `anchor` (a rectangle on the screen), inside `bounds`.
func show_help(title: String, body: String, extra: String, anchor: Rect2, bounds: Rect2) -> void:
	var key: String = "%s|%s|%s|%s" % [title, body, extra, anchor]
	_title.show_text(title)
	_body.show_text(body)
	_extra.show_text(extra)
	_extra.move_to(PAD, _body.position.y + _body.size.y + (8 if not extra.is_empty() else 0))
	var h: float = (_extra.position.y + _extra.size.y if not extra.is_empty() else _body.position.y + _body.size.y) + 12
	if size.y != h:
		size.y = h
		queue_redraw()
	# Beside the anchor: on its left when it is in the right half of the screen.
	var x: float = anchor.position.x - W - 8 if anchor.get_center().x > bounds.get_center().x else anchor.end.x + 8
	x = clampf(x, bounds.position.x + 4, bounds.end.x - W - 4)
	var y: float = clampf(anchor.get_center().y - h / 2, bounds.position.y + 4, bounds.end.y - h - 4)
	position = Vector2(x, y).round()
	if key == _key and visible:
		return
	var appearing: bool = not visible
	_key = key
	visible = true
	if appearing:
		if _tween != null:
			_tween.kill()
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, 0.1)


func hide_help() -> void:
	visible = false
	_key = ""


func title_text() -> String:
	return _title.text if visible else ""


func body_text() -> String:
	return _body.text if visible else ""


func extra_text() -> String:
	return _extra.text if visible else ""
