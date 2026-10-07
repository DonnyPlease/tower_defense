class_name AbilityArt
extends RefCounted
## Vector drawings for the walls and abilities: the button icons, the wall
## blocks and the mines on the field. Icons are drawn in a `size` box around a
## centre (like TowerArt.draw_icon).

const STONE: Color = Color("#8d939c")
const STONE_LIGHT: Color = Color("#b3b9c2")
const STONE_DARK: Color = Color("#4f555e")
const MORTAR: Color = Color("#3b4047")


static func draw_icon(ci: CanvasItem, id: String, center: Vector2, size: float) -> void:
	var k: float = size / 40.0
	ci.draw_set_transform(center, 0, Vector2(k, k))
	match id:
		"wall":
			_wall(ci, -18, -18, 36)
		"slow":
			_clock(ci)
		"boost":
			_bolt(ci)
		"strike":
			_crosshair(ci, Palette.rgb(0xff8c42), true)
		"mine":
			_mine(ci, true)
		"bounty":
			_coin(ci)
		"mark":
			_crosshair(ci, Palette.RED, false)
		"wind":
			_heart(ci)
	ci.draw_set_transform(Vector2.ZERO)


## A wall block filling the tile whose top-left corner is (x, y).
static func draw_wall_tile(ci: CanvasItem, x: float, y: float) -> void:
	var t: float = Config.TILE
	Paint.fill_rounded_rect(ci, x + 2, y + 5, t - 4, t - 4, 4, Color(0, 0, 0, 0.3)) # shadow
	_wall(ci, x + 2, y + 2, t - 4)


## A landmine at a tile centre; `blink` (0..1) is the pulse of its light.
static func draw_mine(ci: CanvasItem, center: Vector2, blink: float) -> void:
	ci.draw_set_transform(center, 0, Vector2(0.7, 0.7))
	_mine(ci, false)
	var light: float = 0.4 + 0.6 * blink
	Paint.fill_circle(ci, 0, 0, 4.5, Color(Palette.RED, light))
	ci.draw_set_transform(Vector2.ZERO)


static func _wall(g: CanvasItem, x: float, y: float, s: float) -> void:
	Paint.fill_rounded_rect(g, x, y, s, s, 4, STONE_DARK)
	Paint.fill_rounded_rect(g, x + 1, y + 1, s - 2, s - 2, 3, STONE)
	# Bricks: three rows, the middle one shifted.
	var row_h: float = s / 3.0
	for r: int in 3:
		var yy: float = y + r * row_h
		if r > 0:
			g.draw_line(Vector2(x + 1, yy), Vector2(x + s - 1, yy), MORTAR, 1.5)
		var shift: float = s / 2.0 if r == 1 else s / 4.0
		var xx: float = x + shift
		while xx < x + s - 1:
			g.draw_line(Vector2(xx, yy), Vector2(xx, yy + row_h), MORTAR, 1.5)
			xx += s / 2.0
	g.draw_line(Vector2(x + 3, y + 2), Vector2(x + s - 3, y + 2), STONE_LIGHT, 1.5)


static func _clock(g: CanvasItem) -> void:
	Paint.fill_circle(g, 0, 0, 17, Palette.rgb(0x2b6cb0))
	Paint.fill_circle(g, 0, 0, 14, Palette.rgb(0xe8f1ff))
	Paint.line(g, 0, 0, 0, -10, 3, Palette.rgb(0x1c3f6e))
	Paint.line(g, 0, 0, 7, 3, 3, Palette.rgb(0x1c3f6e))
	Paint.fill_circle(g, 0, 0, 2.5, Palette.rgb(0x1c3f6e))


static func _bolt(g: CanvasItem) -> void:
	var pts := PackedVector2Array([Vector2(4, -19), Vector2(-11, 3), Vector2(-1, 3), Vector2(-5, 19),
		Vector2(11, -4), Vector2(1, -4)])
	Paint.polygon(g, pts, Palette.GOLD)
	Paint.stroke_circle(g, 0, 0, 18, 2, Color(Palette.GOLD, 0.35))


static func _crosshair(g: CanvasItem, color: Color, filled: bool) -> void:
	if filled:
		Paint.fill_circle(g, 0, 0, 13, Color(color, 0.35))
	Paint.stroke_circle(g, 0, 0, 14, 3, color)
	Paint.line(g, -19, 0, -8, 0, 3, color)
	Paint.line(g, 8, 0, 19, 0, 3, color)
	Paint.line(g, 0, -19, 0, -8, 3, color)
	Paint.line(g, 0, 8, 0, 19, 3, color)
	Paint.fill_circle(g, 0, 0, 3, color)


static func _mine(g: CanvasItem, icon: bool) -> void:
	for i: int in 8:
		var a: float = i * PI / 4.0
		Paint.line(g, cos(a) * 10, sin(a) * 10, cos(a) * 17, sin(a) * 17, 4, STONE_DARK)
	Paint.fill_circle(g, 0, 0, 12, STONE_DARK)
	Paint.fill_circle(g, 0, 0, 10, Palette.rgb(0x6c757d))
	if icon:
		Paint.fill_circle(g, 0, 0, 4.5, Palette.RED)


static func _coin(g: CanvasItem) -> void:
	Paint.fill_circle(g, 0, 0, 17, Palette.rgb(0xb8860b))
	Paint.fill_circle(g, 0, 0, 14.5, Palette.GOLD)
	Paint.stroke_circle(g, 0, 0, 10.5, 2, Palette.rgb(0xb8860b))
	Paint.line(g, 0, -7, 0, 7, 3, Palette.rgb(0xb8860b))
	Paint.line(g, -4, -3.5, 4, -3.5, 3, Palette.rgb(0xb8860b))
	Paint.line(g, -4, 3.5, 4, 3.5, 3, Palette.rgb(0xb8860b))


static func _heart(g: CanvasItem) -> void:
	Paint.fill_circle(g, -8, -6, 9.5, Palette.RED)
	Paint.fill_circle(g, 8, -6, 9.5, Palette.RED)
	Paint.fill_triangle(g, -17, -2, 17, -2, 0, 17, Palette.RED)
	Paint.fill_circle(g, -9, -9, 2.5, Color(1, 1, 1, 0.6))
