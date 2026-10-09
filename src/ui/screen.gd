class_name Screen
extends RefCounted
## The screens adapt to the window. The game is designed for a 1000 x 600
## view (Config.WIDTH x HEIGHT); the stretch aspect is "expand", so the view
## keeps that scale and grows to the window's shape instead of showing black
## bars: it is at least 1000 x 600 and wider (or taller) to match the window.

const BASE: Vector2 = Vector2(Config.WIDTH, Config.HEIGHT)


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
