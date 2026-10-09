class_name Icons
extends RefCounted
## Small UI icons drawn in code (the fonts don't have these symbols). Each is
## a painter func(ci: CanvasItem, center: Vector2, size: float) for
## GameButton.icon() and PainterView.


static func gear(ci: CanvasItem, center: Vector2, size: float) -> void:
	var r: float = size * 0.32
	var color: Color = Palette.TEXT
	for k: int in 8:
		var a: float = k * PI / 4
		var d := Vector2(cos(a), sin(a))
		Paint.line(ci, center.x, center.y, center.x + d.x * (r + size * 0.13), center.y + d.y * (r + size * 0.13),
			size * 0.16, color)
	Paint.fill_circle(ci, center.x, center.y, r, color)
	Paint.fill_circle(ci, center.x, center.y, r * 0.45, Palette.PANEL_LIGHT)


## A chevron pointing down (open a section) or up (close it).
static func chevron(ci: CanvasItem, center: Vector2, size: float, up: bool, color: Color = Palette.TEXT_DIM) -> void:
	var w: float = size * 0.3
	var h: float = size * 0.16 * (-1.0 if up else 1.0)
	var pts := PackedVector2Array([center + Vector2(-w, -h), center + Vector2(0, h), center + Vector2(w, -h)])
	ci.draw_polyline(pts, color, maxf(1.5, size * 0.09), true)
