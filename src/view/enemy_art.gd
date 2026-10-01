class_name EnemyArt
extends RefCounted
## Enemy art, drawn in a 40 x 40 box centred on the origin, facing right.
## Scout, racer and tank are sprites from res://assets/enemies; the others are
## drawn in code.

const FILE_ART: Array[String] = ["scout", "racer", "tank"]

static var _textures: Dictionary[String, Texture2D] = {}


static func c(hex: int, alpha: float = 1.0) -> Color:
	return Palette.rgb(hex, alpha)


static func texture(art: String) -> Texture2D:
	if not _textures.has(art):
		_textures[art] = load("res://assets/enemies/%s.png" % art)
	return _textures[art]


## Draws enemy art `art` centred at `center`, `size` pixels wide (40 = one tile).
static func draw(ci: CanvasItem, art: String, center: Vector2 = Vector2.ZERO, size: float = 40.0) -> void:
	var s: float = size / 40.0
	if FILE_ART.has(art):
		var tex: Texture2D = texture(art)
		ci.draw_texture_rect(tex, Rect2(center - Vector2(20, 20) * s, Vector2(40, 40) * s), false)
		return
	ci.draw_set_transform(center - Vector2(20, 20) * s, 0, Vector2(s, s))
	match art:
		"armored":
			Paint.fill_rect(ci, 4, 5, 32, 6, c(0x1b1f24))
			Paint.fill_rect(ci, 4, 29, 32, 6, c(0x1b1f24))
			Paint.fill_rounded_rect(ci, 6, 9, 28, 22, 3, c(0x4f5b66))
			for x: float in [13, 20, 27]:
				Paint.line(ci, x, 10, x, 30, 1.5, c(0x2b3038))
			Paint.fill_circle(ci, 20, 20, 6, c(0x6c7a86))
			Paint.fill_rect(ci, 20, 18.5, 15, 3, c(0x2b3038))
		"shielded":
			Paint.fill_rect(ci, 6, 7, 28, 5, c(0x1b1f24))
			Paint.fill_rect(ci, 6, 28, 28, 5, c(0x1b1f24))
			Paint.fill_rounded_rect(ci, 8, 10, 24, 20, 5, c(0x16a085))
			Paint.fill_circle(ci, 20, 20, 6, c(0x48dbc3))
			Paint.fill_circle(ci, 22, 18, 2, c(0xe0fff9))
		"splitter":
			Paint.fill_circle(ci, 14, 14, 9, c(0x6a2c91))
			Paint.fill_circle(ci, 14, 26, 9, c(0x6a2c91))
			Paint.fill_circle(ci, 26, 20, 10, c(0x6a2c91))
			Paint.fill_circle(ci, 14, 14, 5, c(0xb15cf0))
			Paint.fill_circle(ci, 14, 26, 5, c(0xb15cf0))
			Paint.fill_circle(ci, 26, 20, 6, c(0xb15cf0))
			Paint.fill_circle(ci, 29, 18, 2, c(0xffffff))
		"healer":
			Paint.fill_rect(ci, 6, 7, 28, 5, c(0x1b1f24))
			Paint.fill_rect(ci, 6, 28, 28, 5, c(0x1b1f24))
			Paint.fill_rounded_rect(ci, 7, 10, 26, 20, 4, c(0xf1f3f5))
			Paint.fill_rect(ci, 17.5, 13, 5, 14, c(0xe03131))
			Paint.fill_rect(ci, 13, 17.5, 14, 5, c(0xe03131))
		"drone":
			Paint.line(ci, 8, 8, 32, 32, 3, c(0x343a40))
			Paint.line(ci, 8, 32, 32, 8, 3, c(0x343a40))
			for p: Vector2 in [Vector2(8, 8), Vector2(32, 8), Vector2(8, 32), Vector2(32, 32)]:
				Paint.fill_circle(ci, p.x, p.y, 6, c(0x868e96, 0.8))
			Paint.fill_circle(ci, 20, 20, 7, c(0xf08c00))
			Paint.fill_circle(ci, 23, 20, 2.5, c(0xffe066))
	ci.draw_set_transform(Vector2.ZERO)
