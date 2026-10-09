class_name Overlay
extends Control
## A modal dialog (pause, victory, defeat) that dims and blocks the game.


## One button of the dialog.
class Action:
	var label: String
	var primary: bool
	var on_click: Callable

	func _init(p_label: String, p_on_click: Callable, p_primary: bool = false) -> void:
		label = p_label
		on_click = p_on_click
		primary = p_primary


const DEPTH: int = 200
const PANEL_W: float = 320

var buttons: Array[GameButton] = []
var _title: String
var _title_color: Color
var _actions: Array[Action]
var _panel_h: float
var _title_label: TextLabel
var _subtitle: TextLabel
var _box: Control = null


func _init(title: String, title_color: Color, actions: Array[Action]) -> void:
	_title = title
	_title_color = title_color
	_actions = actions
	_panel_h = 160 + actions.size() * 60
	position = Vector2.ZERO
	size = Screen.BASE
	z_index = DEPTH
	# Swallows clicks so nothing underneath reacts while the overlay is open.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	# The dialog's contents, centred on the screen (see _relayout()).
	_box = Control.new()
	_box.size = Vector2(PANEL_W, _panel_h)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_title_label = Ui.text(_box, PANEL_W / 2.0, 36, _title, 32, _title_color, true, Vector2(0.5, 0.5))
	_subtitle = Ui.text(_box, PANEL_W / 2.0, 66, "", 15, Palette.TEXT_DIM, false, Vector2(0.5, 0))
	_subtitle.set_line_spacing(4)
	for i: int in _actions.size():
		var a: Action = _actions[i]
		var b := GameButton.new(Rect2(40, 144 + i * 60, PANEL_W - 80, 48), a.label, a.on_click)
		if a.primary:
			b.primary()
		_box.add_child(b)
		buttons.append(b)
	Screen.on_resize(self, _relayout)


## Covers the whole screen, with the dialog in the middle.
func _relayout() -> void:
	size = Screen.size(self)
	_box.position = ((size - _box.size) / 2).floor()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
	if _box == null:
		return
	var p: Vector2 = _box.position
	Paint.fill_rounded_rect(self, p.x, p.y, PANEL_W, _panel_h, 14, Color(Palette.PANEL, 0.97))
	Paint.stroke_rounded_rect(self, p.x, p.y, PANEL_W, _panel_h, 14, 1, Palette.BORDER)


func show_dialog(subtitle: String = "") -> void:
	_subtitle.show_text(subtitle)
	visible = true


func hide_dialog() -> void:
	visible = false


## The dialog's button with this label (tests), or null.
func button(label: String) -> GameButton:
	for b: GameButton in buttons:
		if b.label_text() == label:
			return b
	return null


# ---- what the player sees (read by the scene tests) ---------------------------

func title_text() -> String:
	return _title_label.text


func subtitle_text() -> String:
	return _subtitle.text
