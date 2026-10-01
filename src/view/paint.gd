class_name Paint
extends RefCounted
## Drawing helpers with the same arguments as Phaser's Graphics calls the
## original art was written with (fillRoundedRect(x, y, w, h, r), fillEllipse
## centred at (x, y) with full width and height, ...).
##
## The Compatibility renderer has no 2D MSAA, so opaque filled shapes get a
## thin antialiased outline in their own colour for smooth edges.

const AA_WIDTH: float = 0.6
const CORNER_SEGMENTS: int = 6


static func _segments(r: float) -> int:
	return clampi(int(r * 1.2) + 10, 12, 72)


## Fills a convex or concave polygon, smoothing its edges if it is opaque.
static func polygon(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, color)
	if color.a >= 0.999:
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, color, AA_WIDTH, true)


static func circle_points(cx: float, cy: float, r: float) -> PackedVector2Array:
	var n: int = _segments(r)
	var pts := PackedVector2Array()
	pts.resize(n)
	for i: int in n:
		var a: float = TAU * i / n
		pts[i] = Vector2(cx + cos(a) * r, cy + sin(a) * r)
	return pts


static func fill_circle(ci: CanvasItem, cx: float, cy: float, r: float, color: Color) -> void:
	if r <= 0:
		return
	polygon(ci, circle_points(cx, cy, r), color)


static func stroke_circle(ci: CanvasItem, cx: float, cy: float, r: float, width: float, color: Color) -> void:
	ci.draw_arc(Vector2(cx, cy), r, 0, TAU, _segments(r) + 1, color, width, true)


## Ellipse centred at (cx, cy), `w` wide and `h` high.
static func fill_ellipse(ci: CanvasItem, cx: float, cy: float, w: float, h: float, color: Color) -> void:
	var rx: float = w / 2
	var ry: float = h / 2
	var n: int = _segments(maxf(rx, ry))
	var pts := PackedVector2Array()
	pts.resize(n)
	for i: int in n:
		var a: float = TAU * i / n
		pts[i] = Vector2(cx + cos(a) * rx, cy + sin(a) * ry)
	polygon(ci, pts, color)


static func fill_rect(ci: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	polygon(ci, PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]), color)


static func rounded_rect_points(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	r = minf(r, minf(w, h) / 2)
	if r <= 0:
		return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	var pts := PackedVector2Array()
	var corners: Array[Vector2] = [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	for k: int in 4:
		var start: float = -PI / 2 + k * PI / 2
		for i: int in CORNER_SEGMENTS + 1:
			var a: float = start + (PI / 2) * i / CORNER_SEGMENTS
			pts.append(corners[k] + Vector2(cos(a), sin(a)) * r)
	return pts


static func fill_rounded_rect(ci: CanvasItem, x: float, y: float, w: float, h: float, r: float, color: Color) -> void:
	polygon(ci, rounded_rect_points(x, y, w, h, r), color)


static func stroke_rounded_rect(ci: CanvasItem, x: float, y: float, w: float, h: float, r: float, width: float,
		color: Color) -> void:
	var pts: PackedVector2Array = rounded_rect_points(x, y, w, h, r)
	pts.append(pts[0])
	ci.draw_polyline(pts, color, width, true)


static func fill_triangle(ci: CanvasItem, x1: float, y1: float, x2: float, y2: float, x3: float, y3: float,
		color: Color) -> void:
	polygon(ci, PackedVector2Array([Vector2(x1, y1), Vector2(x2, y2), Vector2(x3, y3)]), color)


static func line(ci: CanvasItem, x1: float, y1: float, x2: float, y2: float, width: float, color: Color) -> void:
	ci.draw_line(Vector2(x1, y1), Vector2(x2, y2), color, width, true)
