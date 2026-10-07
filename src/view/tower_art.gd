class_name TowerArt
extends RefCounted
## Procedural tower art. Everything is drawn in a 40 x 40 box (one tile)
## centred on the origin; turrets point up. The Gun and Missile towers have a
## still base plate and a turret with TURRET_FRAMES animation frames; the
## other towers are one drawing that rotates or pulses as a whole.
## Branches (Minigun, Sniper, ...) have drawings of their own; `branch` is ""
## for the base tower. Being vector drawings, they stay sharp at any size.

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


## Draws the still base plate of a Gun or Missile tower (its ring in the branch's colour).
static func draw_base(ci: CanvasItem, kind: String, branch: String = "") -> void:
	ci.draw_set_transform(Vector2(-20, -20))
	_base(ci, Towers.get_branch(branch).color if Towers.is_branch(branch) else Towers.get_def(kind).color)
	ci.draw_set_transform(Vector2.ZERO)


## Draws the part of a tower that turns (or all of it), at animation `frame`.
static func draw_body(ci: CanvasItem, kind: String, frame: int, branch: String = "") -> void:
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
	_body(ci, kind, frame, branch)
	ci.draw_set_transform(Vector2.ZERO)


static func _body(ci: CanvasItem, kind: String, frame: int, branch: String) -> void:
	match branch:
		"minigun":
			_minigun_turret(ci, frame)
		"sniper":
			_sniper_turret(ci, frame)
		"swarm":
			_swarm_turret(ci, frame)
		"seeker":
			_seeker_turret(ci, frame)
		"mortar":
			_mortar(ci)
		"siege":
			_siege(ci)
		"blizzard":
			_blizzard(ci)
		"cryo":
			_cryo(ci)
		"prism":
			_prism(ci)
		"lance":
			_lance(ci)
		"overclock":
			_overclock(ci)
		"command":
			_command(ci)
		_:
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


## A whole tower (base and turret) centred at `center`, `size` pixels wide:
## for icons, previews and the build ghost.
static func draw_icon(ci: CanvasItem, kind: String, center: Vector2, size: float, branch: String = "") -> void:
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
		_base(ci, Towers.get_branch(branch).color if Towers.is_branch(branch) else def.color)
	_body(ci, kind, 0, branch)
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


# ---- branches ------------------------------------------------------------------

## Muzzle flash at (x, y) on the first frames of a shot.
static func _flash(g: CanvasItem, x: float, y: float, frame: int, size: float = 1.0) -> void:
	if frame != 1 and frame != 2:
		return
	var s: float = (1.0 if frame == 1 else 0.6) * size
	Paint.fill_triangle(g, x, y - 8 * s, x - 3 * s, y + 0.5, x + 3 * s, y + 0.5, c(0xff9f1c, 0.85))
	Paint.fill_triangle(g, x, y - 5.5 * s, x - 1.8 * s, y + 0.5, x + 1.8 * s, y + 0.5, c(0xffd166))
	Paint.fill_circle(g, x, y, 1.5 * s, c(0xffffff))


## Rotary cannon: a bundle of barrels that turns while it fires.
static func _minigun_turret(g: CanvasItem, frame: int) -> void:
	Paint.fill_rounded_rect(g, 13.5, 1, 13, 21, 3, c(STEEL_DARK))
	for i: int in 4:
		var bx: float = 14.6 + i * 2.85
		var lit: bool = (i + frame) % 4 == 0
		Paint.fill_rounded_rect(g, bx, 1.5, 2.3, 19, 1, c(STEEL_SHINE if lit else STEEL_MID))
	Paint.fill_rect(g, 13.5, 5, 13, 1.6, c(0x15181c))
	Paint.fill_rect(g, 13.5, 12, 13, 1.6, c(0x15181c))
	Paint.polygon(g, _octagon(20, 26, 9.8), c(0x5c1d10))
	Paint.polygon(g, _octagon(20, 25.4, 8.8), c(0xc94b2c))
	Paint.polygon(g, _octagon(19.6, 24.8, 7.2), c(0xff6b4a))
	Paint.fill_ellipse(g, 17, 21.6, 5, 2.4, c(0xffb199, 0.85))
	# Ammo belt feeding in from the side.
	for i: int in 4:
		Paint.fill_rect(g, 27 + i * 0.6, 20 + i * 2.2, 3, 1.6, c(0xc9a227))
	_flash(g, 20, 0.5, frame, 1.2)


## Long rail rifle with a scope.
static func _sniper_turret(g: CanvasItem, frame: int) -> void:
	var recoil: float = 2.5 if frame == 1 else (1.5 if frame == 2 else 0.0)
	Paint.fill_rounded_rect(g, 18.4, -3 + recoil, 3.2, 26, 1, c(STEEL_DARK))
	Paint.fill_rect(g, 19.2, -2 + recoil, 1, 22, c(STEEL_SHINE, 0.9))
	Paint.fill_rounded_rect(g, 16.8, -4 + recoil, 6.4, 3, 1, c(0x15181c)) # muzzle brake
	# Rails glowing along the barrel.
	Paint.line(g, 17.6, 2 + recoil, 17.6, 18, 1, c(0xffd166, 0.8))
	Paint.line(g, 22.4, 2 + recoil, 22.4, 18, 1, c(0xffd166, 0.8))
	Paint.polygon(g, _octagon(20, 25.5, 8.4), c(0x5c4a14))
	Paint.polygon(g, _octagon(20, 25, 7.4), c(0xd4a72c))
	Paint.polygon(g, _octagon(19.7, 24.6, 6), c(0xffd166))
	# Scope.
	Paint.fill_rounded_rect(g, 23.5, 13, 4, 11, 1.5, c(0x15181c))
	Paint.fill_circle(g, 25.5, 14.5, 1.3, c(0x7ad3ff))
	Paint.fill_circle(g, 20, 26, 2, c(0x3b2f0a))
	if frame == 1 or frame == 2:
		Paint.fill_circle(g, 20, -4, 3.5 if frame == 1 else 2.0, c(0xfff3b0, 0.9))


## Box of nine small tubes.
static func _swarm_turret(g: CanvasItem, frame: int) -> void:
	Paint.fill_rounded_rect(g, 7.5, 7.5, 25, 26, 4, c(0x1f3b0c))
	Paint.fill_rounded_rect(g, 8.5, 8.3, 23, 24, 3.5, c(0x5a9e2e))
	Paint.fill_rounded_rect(g, 9.5, 9.3, 21, 22, 3, c(0x9be564))
	Paint.fill_rounded_rect(g, 10, 9.8, 20, 2, 1, c(0xd3f9b4, 0.9))
	var empty: int = 3 if frame >= 1 and frame <= 3 else 0
	for r: int in 3:
		for k: int in 3:
			var x: float = 14 + k * 6
			var y: float = 15 + r * 6.5
			Paint.fill_circle(g, x, y, 2.6, c(0x0d1410))
			if r * 3 + k >= empty:
				Paint.fill_circle(g, x, y, 1.8, c(0xe63946))
				Paint.fill_circle(g, x - 0.4, y - 0.4, 0.6, c(0xffffff, 0.8))
	Paint.fill_rounded_rect(g, 17, 4, 6, 4.5, 1.5, c(0x15181c))
	Paint.fill_circle(g, 20, 6.2, 1.1, c(0xb2f2bb))


## One big missile on a launch rail.
static func _seeker_turret(g: CanvasItem, frame: int) -> void:
	Paint.fill_rounded_rect(g, 12, 6, 16, 28, 3, c(0x12301c))
	Paint.fill_rounded_rect(g, 13, 7, 14, 26, 2.5, c(0x2f9e44))
	Paint.fill_rect(g, 14, 9, 1.5, 22, c(0x8ce99a, 0.7))
	var loaded: bool = frame == 0 or frame >= 5
	if loaded:
		Paint.fill_rounded_rect(g, 16.5, 5, 7, 23, 3, c(0xe9ecef))
		Paint.fill_rect(g, 17.5, 7, 1.5, 19, c(0xffffff, 0.8))
		Paint.fill_triangle(g, 16.5, 7, 20, 0, 23.5, 7, c(0xe63946))
		Paint.fill_triangle(g, 16.5, 24, 13.5, 30, 16.5, 28, c(0xadb5bd))
		Paint.fill_triangle(g, 23.5, 24, 26.5, 30, 23.5, 28, c(0xadb5bd))
		Paint.fill_rect(g, 17.5, 15, 5, 2, c(0xe63946))
	else:
		Paint.fill_rounded_rect(g, 17, 6, 6, 22, 2, c(0x0d1410))
		Paint.fill_circle(g, 20, 8, 4, c(0xd9d9d9, 0.6))
	Paint.fill_circle(g, 20, 32, 2, c(0x7dffb0))


## Short, wide tube seen from above, on a heavy plate.
static func _mortar(g: CanvasItem) -> void:
	Paint.fill_rounded_rect(g, 3, 4, 34, 33, 7, c(0x000000, 0.25))
	Paint.fill_rounded_rect(g, 3, 3, 34, 33, 7, c(0x3d3a38))
	Paint.fill_rounded_rect(g, 5, 5, 30, 29, 6, c(0x5e5552))
	for p: Vector2 in [Vector2(9, 9), Vector2(31, 9), Vector2(9, 30), Vector2(31, 30)]:
		Paint.fill_circle(g, p.x, p.y, 2, c(0x2b2725))
	Paint.line(g, 10, 30, 17, 22, 3, c(0x2b2725))
	Paint.line(g, 30, 30, 23, 22, 3, c(0x2b2725))
	Paint.fill_circle(g, 20, 17, 11, c(0x2b2725))
	Paint.fill_circle(g, 20, 17, 9.5, c(0xc9ada7))
	Paint.fill_circle(g, 20, 17, 7, c(0x8a7570))
	Paint.fill_circle(g, 20, 17, 5.5, c(0x120f0e))
	Paint.fill_ellipse(g, 16.5, 12.5, 4, 2, c(0xffffff, 0.35))


## Heavy cannon with a long armour-piercing barrel.
static func _siege(g: CanvasItem) -> void:
	Paint.fill_rounded_rect(g, 4, 6, 32, 30, 6, c(0x2b3038))
	Paint.fill_rounded_rect(g, 5.5, 7.5, 29, 27, 5, c(0x495057))
	Paint.fill_rect(g, 6, 18, 28, 2, c(0x343a40))
	Paint.fill_circle(g, 20, 24, 11, c(0x343a40))
	Paint.fill_circle(g, 20, 23, 9.5, c(0x6c757d))
	Paint.fill_rounded_rect(g, 16, -2, 8, 24, 2, c(0x212529))
	Paint.fill_rect(g, 17.2, 0, 1.5, 19, c(0xadb5bd, 0.8))
	Paint.fill_rounded_rect(g, 14, -3, 12, 4, 1.5, c(0x15181c))
	Paint.fill_rect(g, 14.5, 6, 11, 1.5, c(0x15181c))
	Paint.fill_circle(g, 20, 25, 3, c(0xffc078))


## Big snowflake.
static func _blizzard(g: CanvasItem) -> void:
	Paint.fill_circle(g, 20, 20, 17, c(0x1d4e89))
	Paint.fill_circle(g, 20, 20, 15, c(0x2b6cb0))
	for i: int in 6:
		var a: float = i * PI / 3 - PI / 2
		var ex: float = 20 + cos(a) * 14
		var ey: float = 20 + sin(a) * 14
		Paint.line(g, 20, 20, ex, ey, 2.4, c(0xffffff))
		for side: float in [-1.0, 1.0]:
			var mx: float = 20 + cos(a) * 8
			var my: float = 20 + sin(a) * 8
			var b: float = a + side * 0.7
			Paint.line(g, mx, my, mx + cos(b) * 5, my + sin(b) * 5, 1.6, c(0xbfe9ff))
	Paint.fill_circle(g, 20, 20, 4, c(0xffffff))
	Paint.fill_circle(g, 20, 20, 2, c(0x7ad3ff))


## Cluster of ice spikes.
static func _cryo(g: CanvasItem) -> void:
	Paint.fill_circle(g, 20, 20, 16, c(0x0b2545))
	Paint.stroke_circle(g, 20, 20, 15, 1.5, c(0x4dabf7, 0.8))
	Paint.fill_triangle(g, 20, 3, 26, 22, 14, 22, c(0x4dabf7))
	Paint.fill_triangle(g, 9, 11, 19, 26, 9, 27, c(0x74c0fc))
	Paint.fill_triangle(g, 31, 11, 31, 27, 21, 26, c(0x339af0))
	Paint.fill_triangle(g, 20, 6, 22.5, 18, 17.5, 18, c(0xffffff, 0.85))
	Paint.fill_circle(g, 20, 28, 4, c(0xd0ebff))


## Crystal prism that splits the beam.
static func _prism(g: CanvasItem) -> void:
	Paint.fill_circle(g, 20, 20, 16, c(0x2d1b3d))
	Paint.fill_circle(g, 20, 22, 11, c(0x4a2160))
	Paint.fill_triangle(g, 20, 4, 31, 26, 9, 26, c(0xff8cf0))
	Paint.fill_triangle(g, 20, 4, 25.5, 26, 9, 26, c(0xffc9f7))
	Paint.fill_triangle(g, 20, 9, 23, 21, 15, 21, c(0xffffff, 0.75))
	Paint.fill_circle(g, 20, 5, 2.5, c(0xffffff))


## Long focusing lens.
static func _lance(g: CanvasItem) -> void:
	Paint.fill_circle(g, 20, 20, 16, c(0x1f1030))
	Paint.fill_circle(g, 20, 23, 10, c(0x5a189a))
	Paint.fill_rounded_rect(g, 16.5, -1, 7, 22, 2, c(0x240046))
	for y: float in [4.0, 9.0, 14.0]:
		Paint.fill_rect(g, 15.5, y, 9, 2, c(0x9d4edd))
	Paint.fill_circle(g, 20, 0.5, 3.2, c(0xe0aaff))
	Paint.fill_circle(g, 20, 0.5, 1.5, c(0xffffff))
	Paint.fill_circle(g, 20, 23, 4.5, c(0xe0aaff))


## Gear with a lightning bolt.
static func _overclock(g: CanvasItem) -> void:
	Paint.fill_rounded_rect(g, 6, 6, 28, 28, 6, c(0x5c3310))
	for i: int in 8:
		var a: float = i * PI / 4
		Paint.line(g, 20 + cos(a) * 9, 20 + sin(a) * 9, 20 + cos(a) * 14, 20 + sin(a) * 14, 4, c(0xffa94d))
	Paint.fill_circle(g, 20, 20, 10, c(0xffa94d))
	Paint.fill_circle(g, 20, 20, 7.5, c(0x5c3310))
	var bolt := PackedVector2Array([Vector2(21.5, 13), Vector2(16, 21), Vector2(19.5, 21), Vector2(18.5, 27),
		Vector2(24, 19), Vector2(20.5, 19)])
	Paint.polygon(g, bolt, c(0xfff3b0))


## Antenna dish with a star.
static func _command(g: CanvasItem) -> void:
	Paint.fill_rounded_rect(g, 6, 6, 28, 28, 6, c(0x5c4a14))
	Paint.stroke_circle(g, 20, 20, 12, 2, c(0xffe066))
	Paint.stroke_circle(g, 20, 20, 7.5, 1.5, c(0xffe066, 0.7))
	var star := PackedVector2Array()
	for i: int in 8:
		var a: float = i * PI / 4 - PI / 2
		var r: float = 6.5 if i % 2 == 0 else 2.5
		star.append(Vector2(20 + cos(a) * r, 20 + sin(a) * r))
	Paint.polygon(g, star, c(0xfff3b0))
	Paint.line(g, 20, 8, 20, 2, 1.5, c(0xffe066))
	Paint.fill_circle(g, 20, 2, 1.8, c(0xff6b6b))
