class_name Screen
extends RefCounted
## The screens adapt to the window. The game is designed for a 1000 x 600
## view (Config.WIDTH x HEIGHT); the stretch aspect is "expand", so the view
## keeps that scale and grows to the window's shape instead of showing black
## bars: it is at least 1000 x 600 and wider (or taller) to match the window.

const BASE: Vector2 = Vector2(Config.WIDTH, Config.HEIGHT)


## Touch screens smaller than this (the window's height, in inches) get a bigger UI.
const PHONE_INCHES: float = 3.6
const MAX_UI_SCALE: float = 1.4

## Tests set these to try a phone's layout on any machine (0 / null: measure).
static var forced_ui_scale: float = 0.0
static var forced_insets: Variant = null


## How much bigger than designed the game's buttons should be, so a finger can
## hit them: 1 with a mouse, up to MAX_UI_SCALE on a small touch screen.
static func ui_scale() -> float:
	if forced_ui_scale > 0:
		return forced_ui_scale
	if not DisplayServer.is_touchscreen_available():
		return 1.0
	var dpi: float = DisplayServer.screen_get_dpi()
	if OS.has_feature("web"):
		dpi *= 160.0 / 96.0 # browsers count 96 "pixels" per inch; phones show about 160
	if dpi <= 0:
		return 1.0
	var inches: float = DisplayServer.window_get_size().y / dpi
	return clampf(PHONE_INCHES / inches, 1.0, MAX_UI_SCALE) if inches > 0 else 1.0


## The margins (left, top, right, bottom as x, y, z, w) of the view that a
## notch or rounded corners may hide, in game units. Zero on most screens.
static func safe_insets(node: CanvasItem) -> Vector4:
	if forced_insets is Vector4:
		return forced_insets
	var window := Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size()))
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if not safe.has_area() or not window.has_area() or OS.has_feature("pc"):
		return Vector4.ZERO
	safe = safe.intersection(window)
	var k: float = window.size.y / size(node).y # window pixels per game unit
	return Vector4(safe.position.x - window.position.x, safe.position.y - window.position.y,
		window.end.x - safe.end.x, window.end.y - safe.end.y).max(Vector4.ZERO) / k


## Size of the view `node` is drawn in, in game units.
static func size(node: CanvasItem) -> Vector2:
	return node.get_viewport_rect().size


## Where a centred BASE-sized area starts, so screens laid out for 1000 x 600
## sit in the middle of a wider or taller view.
static func center_offset(node: CanvasItem) -> Vector2:
	return ((size(node) - BASE) / 2).floor()


## Calls `relayout` now and whenever the window changes size (until `node` leaves the tree).
static func on_resize(node: CanvasItem, relayout: Callable) -> void:
	relayout.call()
	node.get_viewport().size_changed.connect(relayout)
	node.tree_exiting.connect(func() -> void:
		if node.get_viewport().size_changed.is_connected(relayout):
			node.get_viewport().size_changed.disconnect(relayout))


## A page laid out for 1000 x 600 (BASE): a background over the whole window
## and a BASE-sized area in the middle of it, kept there when the window
## changes size. Returns the area to put the page's contents in.
static func centered_page(owner: Node2D, color: Color = Palette.BACKGROUND) -> Control:
	var bg := ColorRect.new()
	bg.color = color
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(bg)
	var area := Control.new()
	area.size = BASE
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner.add_child(area)
	on_resize(owner, func() -> void:
		bg.size = size(owner)
		area.position = center_offset(owner))
	return area
