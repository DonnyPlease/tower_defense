class_name GameButton
extends Control
## A rounded button with hover / selected / disabled states, an optional icon
## (drawn by a painter function), a sub-label and a hotkey hint. Configure it
## with the chainable methods before adding it to the tree:
##
##   add_child(GameButton.new(Rect2(10, 10, 200, 50), "Play", start).primary())
##
## It acts when it is released. Held down for LONG_PRESS seconds it shows its
## help instead (the hover callback, which touch screens can't otherwise
## reach) and does nothing when released.

enum Variant { DEFAULT, PRIMARY, DANGER, FLAT } ## FLAT: no background until hovered

const LONG_PRESS: float = 0.45 ## seconds
enum Layout { ROW, TILE } ## ROW: icon left of the text; TILE: icon on top, text underneath

var on_click: Callable
## Called with true / false when the pointer enters / leaves.
var on_hover: Callable = Callable()
var variant: Variant = Variant.DEFAULT
var layout: Layout = Layout.ROW
var font_size: int = 16
var hotkey: String = ""
## func(ci: CanvasItem, center: Vector2, size: float) that draws the icon.
var icon_painter: Callable = Callable()

var _label_text: String
var _sublabel_text: String = ""
var _has_sublabel: bool = false
var _label: TextLabel
var _sub: TextLabel = null
var _hotkey: TextLabel = null
var _icon: PainterView = null
var _hover: bool = false
var _enabled: bool = true
var _selected: bool = false
var _pressed: bool = false
var _held: float = 0.0
var _long: bool = false
var _icon_only: bool = false


func _init(rect: Rect2, label: String, click: Callable) -> void:
	position = rect.position
	size = rect.size
	_label_text = label
	on_click = click
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	visibility_changed.connect(_on_visibility_changed)


func primary() -> GameButton:
	variant = Variant.PRIMARY
	return self


func danger() -> GameButton:
	variant = Variant.DANGER
	return self


## No background until hovered (e.g. a "Details" toggle).
func flat() -> GameButton:
	variant = Variant.FLAT
	return self


## An icon without text, in the middle.
func icon_only(painter: Callable) -> GameButton:
	icon_painter = painter
	_icon_only = true
	return self


func tile() -> GameButton:
	layout = Layout.TILE
	return self


func font(px: int) -> GameButton:
	font_size = px
	return self


func key(hint: String) -> GameButton:
	hotkey = hint
	return self


func icon(painter: Callable) -> GameButton:
	icon_painter = painter
	return self


func hover_callback(callback: Callable) -> GameButton:
	on_hover = callback
	return self


func sublabel(text: String) -> GameButton:
	_has_sublabel = true
	_sublabel_text = text
	return self


func _ready() -> void:
	set_process(false)
	var w: float = size.x
	var h: float = size.y
	var text_x: float = w / 2
	var text_y: float = h / 2
	var origin_x: float = 0.5
	var is_tile: bool = layout == Layout.TILE
	if icon_painter.is_valid():
		_icon = PainterView.new(icon_painter)
		if is_tile:
			var s: float = h - 24
			_icon.position = Vector2(w / 2 - s / 2, 4)
			_icon.size = Vector2(s, s)
			text_y = h - 11
		elif _icon_only:
			var s: float = minf(w, h) - 10
			_icon.position = Vector2(w / 2 - s / 2, h / 2 - s / 2)
			_icon.size = Vector2(s, s)
		else:
			var s: float = minf(40, h - 12)
			_icon.position = Vector2(10, h / 2 - s / 2)
			_icon.size = Vector2(s, s)
			text_x = 18 + s
			origin_x = 0.0
		add_child(_icon)
	var has_sub: bool = _has_sublabel and not is_tile
	_label = Ui.text(self, text_x, text_y - (9 if has_sub else 0), _label_text, font_size, Palette.TEXT, true,
		Vector2(origin_x, 0.5))
	if has_sub:
		_sub = Ui.text(self, text_x, h / 2 + 11, _sublabel_text, 13, Palette.TEXT_DIM, false, Vector2(origin_x, 0.5))
	if not hotkey.is_empty():
		_hotkey = Ui.text(self, w - 8, 6, hotkey, 11, Palette.TEXT_DIM, true, Vector2(1, 0))
	_apply_alpha()


func _draw() -> void:
	if variant == Variant.FLAT:
		if _hover and _enabled:
			Paint.fill_rounded_rect(self, 0, 0, size.x, size.y, 6, Color(1, 1, 1, 0.07))
		if _selected:
			Paint.stroke_rounded_rect(self, 0, 0, size.x, size.y, 6, 1.5, Palette.GOLD)
		return
	var base: Color = [Palette.PANEL_LIGHT, Palette.ACCENT, Palette.RED, Palette.PANEL_LIGHT][variant]
	Paint.fill_rounded_rect(self, 0, 0, size.x, size.y, 8, Palette.PANEL_LIGHTER if _selected else base)
	if _hover and _enabled:
		Paint.fill_rounded_rect(self, 0, 0, size.x, size.y, 8, Color(1, 1, 1, 0.1))
	Paint.stroke_rounded_rect(self, 0, 0, size.x, size.y, 8, 2.5 if _selected else 1.0,
		Palette.GOLD if _selected else Palette.BORDER)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_pressed = true
		_held = 0.0
		_long = false
		set_process(true)
		return
	if not _pressed:
		return
	_pressed = false
	set_process(false)
	if _long:
		# It was held for its help: let go without acting.
		_long = false
		if on_hover.is_valid() and not _hover:
			on_hover.call(false)
		return
	if _enabled:
		Audio.play("click")
		on_click.call()
	else:
		Audio.play("error")


func _process(delta: float) -> void:
	if not _pressed or _long:
		return
	_held += delta
	if _held >= LONG_PRESS:
		_long = true
		if on_hover.is_valid():
			on_hover.call(true)


## Whether it is being held down long enough to show its help.
func is_long_pressed() -> bool:
	return _long


func is_enabled() -> bool:
	return _enabled


func is_selected() -> bool:
	return _selected


func label_text() -> String:
	return _label.text if _label != null else _label_text


func sublabel_text() -> String:
	return _sub.text if _sub != null else _sublabel_text


func set_enabled(enabled: bool) -> GameButton:
	if enabled != _enabled:
		_enabled = enabled
		_apply_alpha()
		queue_redraw()
	return self


func set_selected(selected: bool) -> GameButton:
	if selected != _selected:
		_selected = selected
		queue_redraw()
	return self


func set_label(text: String, color: Color = Palette.TEXT) -> GameButton:
	_label_text = text
	if _label != null:
		_label.show_text(text)
		_label.set_color(color)
	return self


func set_sublabel(text: String, color: Color = Palette.TEXT_DIM) -> GameButton:
	_sublabel_text = text
	if _sub != null:
		_sub.show_text(text)
		_sub.set_color(color)
	return self


func set_icon(painter: Callable) -> GameButton:
	icon_painter = painter
	if _icon != null:
		_icon.painter = painter
		_icon.queue_redraw()
	return self


func _apply_alpha() -> void:
	modulate.a = 1.0 if _enabled else 0.4


func _on_mouse_entered() -> void:
	_hover = true
	queue_redraw()
	if on_hover.is_valid():
		on_hover.call(true)


func _on_mouse_exited() -> void:
	_hover = false
	queue_redraw()
	if on_hover.is_valid():
		on_hover.call(false)


func _on_visibility_changed() -> void:
	if not visible:
		_pressed = false
		_long = false
	if not visible and _hover:
		_on_mouse_exited()
