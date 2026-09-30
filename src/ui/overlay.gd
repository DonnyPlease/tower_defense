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
var _subtitle: TextLabel


func _init(title: String, title_color: Color, actions: Array[Action]) -> void:
	_title = title
	_title_color = title_color
	_actions = actions
	_panel_h = 160 + actions.size() * 60
	position = Vector2.ZERO
	size = Vector2(Config.WIDTH, Config.HEIGHT)
	z_index = DEPTH
	# Swallows clicks so nothing underneath reacts while the overlay is open.
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	var py: float = (Config.HEIGHT - _panel_h) / 2
	var px: float = (Config.WIDTH - PANEL_W) / 2
	Ui.text(self, Config.WIDTH / 2.0, py + 36, _title, 32, _title_color, true, Vector2(0.5, 0.5))
	_subtitle = Ui.text(self, Config.WIDTH / 2.0, py + 66, "", 15, Palette.TEXT_DIM, false, Vector2(0.5, 0))
	_subtitle.set_line_spacing(4)
	for i: int in _actions.size():
		var a: Action = _actions[i]
		var b := GameButton.new(Rect2(px + 40, py + 144 + i * 60, PANEL_W - 80, 48), a.label, a.on_click)
		if a.primary:
			b.primary()
		add_child(b)
		buttons.append(b)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
	var px: float = (Config.WIDTH - PANEL_W) / 2
	var py: float = (Config.HEIGHT - _panel_h) / 2
	Paint.fill_rounded_rect(self, px, py, PANEL_W, _panel_h, 14, Color(Palette.PANEL, 0.97))
	Paint.stroke_rounded_rect(self, px, py, PANEL_W, _panel_h, 14, 1, Palette.BORDER)


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
