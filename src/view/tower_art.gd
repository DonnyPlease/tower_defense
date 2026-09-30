class_name TowerArt
extends RefCounted
## Procedural tower art. Everything is drawn in a 40 x 40 box (one tile)
## centred on the origin; turrets point up. The Gun and Missile towers have a
## still base plate and a turret with TURRET_FRAMES animation frames; the
## other towers are one drawing that rotates or pulses as a whole.
## Being vector drawings, they stay sharp at any size.

const TURRET_FRAMES: int = 7
const HAS_BASE: Array[String] = ["gun", "missile"]

const STEEL_DARK: int = 0x23272e
const STEEL_MID: int = 0x3a4049
const STEEL_LIGHT: int = 0x59616d
const STEEL_SHINE: int = 0x8a939e

static var _textures: Dictionary[String, Array] = {}


static func c(hex: int, alpha: float = 1.0) -> Color:
	return Palette.rgb(hex, alpha)


## Whether `kind` has a separate still base under a rotating turret.
static func has_base(kind: String) -> bool:
	return HAS_BASE.has(kind) and Towers.get_def(kind).sprite.is_empty()


## Draws the still base plate of a Gun or Missile tower.
static func draw_base(ci: CanvasItem, kind: String) -> void:
	ci.draw_set_transform(Vector2(-20, -20))
	_base(ci, Towers.get_def(kind).color)
	ci.draw_set_transform(Vector2.ZERO)


## Draws the part of a tower that turns (or all of it), at animation `frame`.
static func draw_body(ci: CanvasItem, kind: String, frame: int) -> void:
	var def: TowerDef = Towers.get_def(kind)
	if not def.sprite.is_empty():
		var frames: Array = _sprite_frames(def)
		if not frames.is_empty():
			var tex: Texture2D = frames[clampi(frame, 0, frames.size() - 1)]
			var s: float = 40.0 / maxf(1.0, tex.get_width())
			ci.draw_set_transform(Vector2.ZERO, 0, Vector2(s, s))
			ci.draw_texture(tex, -tex.get_size() / 2)
			ci.draw_set_transform(Vector2.ZERO)
			return
	ci.draw_set_transform(Vector2(-20, -20))
	match kind:
		"gun":
			_gun_turret(ci, frame)
		"missile":
			_missile_turret(ci, frame)
		"cannon":
			_cannon(ci)
		"frost":
			_frost(ci)
		"laser":
			_laser(ci)
		"support":
			_support(ci)
	ci.draw_set_transform(Vector2.ZERO)


## A whole tower (base and turret) centred at `center`, `size` pixels wide:
## for icons, previews and the build ghost.
static func draw_icon(ci: CanvasItem, kind: String, center: Vector2, size: float) -> void:
	var s: float = size / 40.0
	var def: TowerDef = Towers.get_def(kind)
	if not def.sprite.is_empty():
		var frames: Array = _sprite_frames(def)
		if not frames.is_empty():
			var tex: Texture2D = frames[0]
			var k: float = s * 40.0 / maxf(1.0, tex.get_width())
			ci.draw_set_transform(center, 0, Vector2(k, k))
			ci.draw_texture(tex, -tex.get_size() / 2)
			ci.draw_set_transform(Vector2.ZERO)
		return
	ci.draw_set_transform(center - Vector2(20, 20) * s, 0, Vector2(s, s))
	if has_base(kind):
		_base(ci, def.color)
	match kind:
		"gun":
			_gun_turret(ci, 0)
		"missile":
			_missile_turret(ci, 0)
		"cannon":
			_cannon(ci)
		"frost":
			_frost(ci)
		"laser":
			_laser(ci)
		"support":
			_support(ci)
	ci.draw_set_transform(Vector2.ZERO)


## PNG frames for towers with a `sprite` folder (res://assets/towers/<sprite>/<i>.png).
static func _sprite_frames(def: TowerDef) -> Array:
	if not _textures.has(def.kind):
		var frames: Array = []
		for i: int in def.frames:
			var path: String = "res://assets/towers/%s/%d.png" % [def.sprite, i]
			if ResourceLoader.exists(path):
				frames.append(load(path))
		_textures[def.kind] = frames
	return _textures[def.kind]


## Square steel plate with bevelled edges, bolts and an accent ring.
static func _base(g: CanvasItem, accent: Color) -> void:
	Paint.fill_rounded_rect(g, 3.5, 4.5, 34, 34, 8, c(0x000000, 0.25)) # contact shadow
	Paint.fill_rounded_rect(g, 3, 3, 34, 34, 8, c(STEEL_DARK))
	Paint.fill_rounded_rect(g, 4.5, 4.5, 31, 31, 7, c(STEEL_MID))
	# Bevel: light top-left edge, darker bottom-right edge.
	Paint.fill_rounded_rect(g, 4.5, 4.5, 31, 3, 2, c(STEEL_LIGHT))
	Paint.fill_rounded_rect(g, 4.5, 4.5, 3, 31, 2, c(STEEL_LIGHT))
	Paint.fill_rounded_rect(g, 6, 6, 28, 28, 6, c(0x2d323a))
	# Diagonal tread plates.
	for i: int in 6:
		Paint.line(g, 9 + i * 4.5, 7, 7, 9 + i * 4.5, 0.8, c(0x363c45))
	# Accent ring the turret sits in.
	Paint.fill_circle(g, 20, 20, 13, c(0x1c1f25))
	Paint.stroke_circle(g, 20, 20, 12.5, 1.4, Color(accent, 0.85))
	# Corner bolts.
	for p: Vector2 in [Vector2(8, 8), Vector2(32, 8), Vector2(8, 32), Vector2(32, 32)]:
		Paint.fill_circle(g, p.x, p.y, 2, c(STEEL_DARK))
		Paint.fill_circle(g, p.x - 0.5, p.y - 0.5, 1, c(STEEL_SHINE))


static func _octagon(cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in 8:
		var a: float = PI / 8 + (i * PI) / 4
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	return pts


## Twin-barrel gun. Frames 1-6 recoil the barrels and flash the muzzles.
static func _gun_turret(g: CanvasItem, frame: int) -> void:
	var recoils: Array[float] = [0, 4, 3, 2, 1.2, 0.5, 0]
	var recoil: float = recoils[frame] if frame >= 0 and frame < recoils.size() else 0.0
	var top: float = 2.5 + recoil

	# Barrels.
	for dx: float in [-3.4, 3.4]:
		var x: float = 20 + dx
		Paint.fill_rounded_rect(g, x - 2.2, top, 4.4, 19 - top, 1.2, c(STEEL_DARK))
		Paint.fill_rounded_rect(g, x - 1.6, top + 0.5, 3.2, 18 - top, 1, c(STEEL_MID))
		Paint.fill_rect(g, x - 1.2, top + 2, 0.9, 14 - top, c(STEEL_SHINE, 0.9))
		# Muzzle brake.
		Paint.fill_rounded_rect(g, x - 2.6, top - 0.5, 5.2, 3, 0.8, c(0x15181c))
		Paint.fill_circle(g, x, top + 0.6, 1, c(0x000000))
		# Cooling rings.
		Paint.fill_rect(g, x - 2.3, top + 5, 4.6, 1, c(STEEL_DARK))
		Paint.fill_rect(g, x - 2.3, top + 8, 4.6, 1, c(STEEL_DARK))
	# Armoured octagonal housing.
	Paint.polygon(g, _octagon(20, 25, 9.6), c(0x4a0a12))
	Paint.polygon(g, _octagon(20, 24.4, 8.8), c(0xa81c29))
	Paint.polygon(g, _octagon(19.6, 23.8, 7.4), c(0xe63946))
	Paint.fill_ellipse(g, 16.8, 20.6, 5, 2.6, c(0xff7a85, 0.85))
	Paint.fill_ellipse(g, 16.2, 20.2, 2, 1, c(0xffffff, 0.75))
	# Barrel mount across the front of the housing.
	Paint.fill_rounded_rect(g, 13.5, 15, 13, 4.5, 1.5, c(STEEL_DARK))
	Paint.fill_rounded_rect(g, 14.2, 15.5, 11.6, 1.2, 0.6, c(STEEL_LIGHT))
	# Ammo drum on the side and a commander's hatch.
	Paint.fill_rounded_rect(g, 26.5, 21, 4.5, 8, 1.5, c(STEEL_DARK))
	Paint.fill_rounded_rect(g, 27.2, 21.8, 3, 6.4, 1, c(0xc9a227))
	Paint.fill_rect(g, 27.6, 22.4, 0.8, 5.2, c(0xffe08a, 0.9))
	Paint.fill_circle(g, 20.5, 26.5, 2.6, c(0x3b0810))
	Paint.fill_circle(g, 20.2, 26.2, 1.8, c(0x8f1823))
	Paint.fill_circle(g, 19.7, 25.7, 0.55, c(STEEL_SHINE))

	# Muzzle flash on the first frames of a shot.
	if frame == 1 or frame == 2:
		var s: float = 1.0 if frame == 1 else 0.6
		for dx: float in [-3.4, 3.4]:
			var x: float = 20 + dx
			var y: float = top - 1.5
			Paint.fill_triangle(g, x, y - 7 * s, x - 2.6 * s, y + 0.5, x + 2.6 * s, y + 0.5, c(0xff9f1c, 0.85))
			Paint.fill_triangle(g, x, y - 5 * s, x - 1.6 * s, y + 0.5, x + 1.6 * s, y + 0.5, c(0xffd166))
			Paint.fill_circle(g, x, y, 1.4 * s, c(0xffffff))


## Four-tube missile launcher. Frames 1-2 show a launch, 3-6 the reload.
static func _missile_turret(g: CanvasItem, frame: int) -> void:
	# Launcher box, slightly longer than wide.
	Paint.fill_rounded_rect(g, 8.5, 8, 23, 25, 4, c(0x10301a))
	Paint.fill_rounded_rect(g, 9.5, 8.8, 21, 23, 3.5, c(0x2e7d45))
	Paint.fill_rounded_rect(g, 10.5, 9.8, 19, 21, 3, c(0x57c26b))
	Paint.fill_rounded_rect(g, 11, 10.2, 18, 2.2, 1, c(0x8fe3a0, 0.9))
	Paint.fill_rounded_rect(g, 11, 10.2, 2, 19, 1, c(0x8fe3a0, 0.6))
	# Camo patches.
	Paint.fill_ellipse(g, 25.5, 28, 6, 3, c(0x3f9a56))
	Paint.fill_ellipse(g, 14, 27.5, 4, 2.5, c(0x3f9a56))

	# Tubes; the first one fires and reloads.
	var tubes: Array[Vector2] = [Vector2(15.5, 15.5), Vector2(24.5, 15.5), Vector2(15.5, 24), Vector2(24.5, 24)]
	# Missile nose size per frame for the firing tube (0 = empty).
	var reloads: Array[float] = [1, 0, 0, 0.3, 0.6, 0.85, 1]
	var reload: float = reloads[frame] if frame >= 0 and frame < reloads.size() else 1.0
	for i: int in tubes.size():
		var x: float = tubes[i].x
		var y: float = tubes[i].y
		Paint.fill_circle(g, x, y, 3.8, c(0x0d1410))
		Paint.fill_circle(g, x, y, 3.2, c(0x3a4049))
		Paint.fill_circle(g, x, y, 2.6, c(0x121518))
		var k: float = reload if i == 0 else 1.0
		if k > 0:
			Paint.fill_circle(g, x, y, 2.3 * k, c(0xb8202e))
			Paint.fill_circle(g, x - 0.3, y - 0.3, 1.7 * k, c(0xe63946))
			Paint.fill_circle(g, x - 0.8, y - 0.8, 0.6 * k, c(0xffffff, 0.85))
	# Launch flash and smoke from the empty tube.
	if frame == 1 or frame == 2:
		var x: float = tubes[0].x
		var y: float = tubes[0].y
		var s: float = 1.0 if frame == 1 else 0.7
		Paint.fill_circle(g, x, y - 1, 4 * s, c(0xd9d9d9, 0.7))
		Paint.fill_circle(g, x, y, 2.2 * s, c(0xffd166, 0.9))
		Paint.fill_circle(g, x, y, 1.1 * s, c(0xffffff))

	# Targeting sensor at the front.
	Paint.fill_rounded_rect(g, 16.5, 3.5, 7, 5.5, 1.5, c(0x15181c))
	Paint.fill_rounded_rect(g, 17.2, 4.2, 5.6, 4, 1.2, c(STEEL_MID))
	Paint.fill_circle(g, 20, 6.2, 1.2, c(0x7dffb0))
	Paint.fill_circle(g, 19.6, 5.8, 0.45, c(0xffffff, 0.9))


static func _cannon(g: CanvasItem) -> void:
	Paint.fill_rounded_rect(g, 4, 4, 32, 32, 7, c(0x3d4451))
	Paint.fill_circle(g, 20, 23, 11, c(0x5c6677))
	Paint.fill_rounded_rect(g, 15, 1, 10, 20, 3, c(0x2b3038))
	Paint.fill_circle(g, 17, 20, 3, c(0x8d99ae))


static func _frost(g: CanvasItem) -> void:
	Paint.fill_circle(g, 20, 20, 16, c(0x1d4e89))
	Paint.fill_triangle(g, 20, 5, 29, 20, 11, 20, c(0x7ad3ff))
	Paint.fill_triangle(g, 11, 20, 29, 20, 20, 35, c(0x4aa8e0))
	Paint.fill_triangle(g, 20, 8, 23, 18, 17, 18, c(0xffffff, 0.85))


static func _laser(g: CanvasItem) -> void:
	Paint.fill_circle(g, 20, 20, 16, c(0x2d1b3d))
	Paint.fill_circle(g, 20, 22, 10, c(0x5a2d82))
	Paint.fill_rect(g, 17, 3, 6, 16, c(0x3b1f52))
	Paint.fill_circle(g, 20, 5, 3, c(0xd35cff))
	Paint.fill_circle(g, 20, 22, 4, c(0xf5d0ff))


static func _support(g: CanvasItem) -> void:
	Paint.fill_rounded_rect(g, 6, 6, 28, 28, 6, c(0x5c4a14))
	Paint.stroke_circle(g, 20, 20, 11, 2, c(0xf5c542))
	Paint.fill_circle(g, 20, 20, 5, c(0xf5c542))
	Paint.fill_circle(g, 20, 20, 2, c(0xfff3b0))
