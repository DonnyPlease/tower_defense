class_name FieldView
extends Node2D
## Renders a World: owns one view per simulated tower and enemy, positions them
## with interpolation between simulation ticks, and turns world events into
## particles, floating text, screen effects and sounds.

## Draw order (z_index) of the layers inside the playing field. Towers (5-10)
## and enemies (5, 20, 26) set their own; see TowerView and EnemyView.
const D_MAP: int = 0
const D_PATH_PREVIEW: int = 2
const D_MINES: int = 3
const D_WALLS: int = 4
const D_BULLETS: int = 30
const D_BEAMS: int = 32
const D_BARS: int = 40
const D_ABILITIES: int = 41
const D_OVERLAY: int = 45
const D_EFFECTS: int = 50
const D_FLOATERS: int = 60

## Sound of a shot, by tower kind or branch id.
const SHOT_SOUND: Dictionary[String, String] = {
	"gun": "gun", "missile": "missile", "cannon": "cannon", "minigun": "gun", "sniper": "rail", "swarm": "missile",
	"seeker": "missile", "mortar": "mortar", "siege": "cannon",
}
const RAIL_TIME: float = 0.18 ## seconds a rail tracer stays on screen

## Menu demo: no floating text, screen effects or sound.
var quiet: bool = false
## Screen shake and flash (optional).
var fx: ScreenFx = null

var world: World
var _towers: Dictionary[Tower, TowerView] = {}
var _enemies: Dictionary[Enemy, EnemyView] = {}
var _alpha: float = 0.0
var _frame_count: int = 0
var _path_key: String = "-"
var _wall_key: String = "-"
var _mines_drawn: bool = false
var _path_preview: DrawNode
var _walls: DrawNode
var _mines: DrawNode
var _abilities: DrawNode
var _bullets: DrawNode
var _beams: DrawNode
var _bars: DrawNode
var _rings: RingLayer
var _explosion: Burst
var _sparks: Burst
var _smoke: Burst
var _dust: Burst
var _frost: Burst
var _stars: Burst
## Rail tracers fading out: [x, y, x2, y2, seconds left].
var _rails: Array[PackedFloat32Array] = []


func _init(p_world: World) -> void:
	world = p_world
	add_child(DrawNode.new(_draw_map, D_MAP))
	_path_preview = DrawNode.new(_draw_path_preview, D_PATH_PREVIEW)
	add_child(_path_preview)
	_mines = DrawNode.new(_draw_mines, D_MINES)
	add_child(_mines)
	_walls = DrawNode.new(_draw_walls, D_WALLS)
	add_child(_walls)
	_bullets = DrawNode.new(_draw_bullets, D_BULLETS)
	add_child(_bullets)
	_beams = DrawNode.new(_draw_beams, D_BEAMS)
	add_child(_beams)
	_bars = DrawNode.new(_draw_bars, D_BARS)
	add_child(_bars)
	_abilities = DrawNode.new(_draw_abilities, D_ABILITIES)
	add_child(_abilities)
	_rings = RingLayer.new(D_EFFECTS)
	add_child(_rings)

	_explosion = Burst.new(D_EFFECTS).speed(40, 170).lifespan(250, 550).scale_over_life(0.7, 0) \
		.colors([0xffd166, 0xff8c42, 0xef476f, 0x8d99ae])
	_sparks = Burst.new(D_EFFECTS).speed(60, 140).lifespan(180).scale_over_life(0.35, 0).colors([0xffffff, 0xffe28a])
	_smoke = Burst.new(D_BULLETS - 1).speed(2, 12).lifespan(450).scale_over_life(0.35, 0.9) \
		.alpha_over_life(0.45, 0).colors([0xd0d0d0])
	_dust = Burst.new(D_EFFECTS).speed(30, 80).lifespan(400).scale_over_life(0.6, 0).alpha_over_life(0.7, 0) \
		.colors([0xe9dcb8])
	_frost = Burst.new(D_EFFECTS).speed(20, 60).lifespan(500).scale_over_life(0.4, 0).alpha_over_life(0.9, 0) \
		.colors([0xffffff, 0xbfe9ff, 0x7ad3ff])
	_stars = Burst.new(D_EFFECTS).speed(40, 110).lifespan(600).scale_over_life(0.5, 0).gravity(120) \
		.colors([0xf5c542, 0xffffff])
	for b: Burst in [_explosion, _sparks, _smoke, _dust, _frost, _stars]:
		add_child(b)


# ---- terrain -------------------------------------------------------------------

func _draw_map(g: CanvasItem) -> void:
	var map: GameMap = world.map
	var t: float = Config.TILE
	for r: int in Config.ROWS:
		for c: int in Config.COLS:
			var x: float = c * t
			var y: float = r * t
			var grass: Color = Palette.GRASS if (r + c) % 2 == 1 else Palette.GRASS_ALT
			match map.terrain_at(c, r):
				GameMap.Terrain.ROAD:
					g.draw_rect(Rect2(x, y, t, t), Palette.PATH)
				GameMap.Terrain.HIGH:
					g.draw_rect(Rect2(x, y, t, t), Palette.HIGH)
					g.draw_rect(Rect2(x, y, t, 3), Palette.HIGH_EDGE_LIGHT)
					g.draw_rect(Rect2(x, y, 3, t), Palette.HIGH_EDGE_LIGHT)
					g.draw_rect(Rect2(x, y + t - 3, t, 3), Palette.HIGH_EDGE_DARK)
					g.draw_rect(Rect2(x + t - 3, y, 3, t), Palette.HIGH_EDGE_DARK)
					Paint.fill_triangle(g, x + 12, y + 26, x + 20, y + 14, x + 28, y + 26, Color(Palette.HIGH_EDGE_DARK, 0.5))
				GameMap.Terrain.ROCK:
					g.draw_rect(Rect2(x, y, t, t), grass)
					Paint.fill_ellipse(g, x + 21, y + 24, 32, 24, Palette.ROCK_DARK)
					Paint.fill_ellipse(g, x + 19, y + 20, 28, 22, Palette.ROCK)
					Paint.fill_ellipse(g, x + 15, y + 15, 10, 6, Palette.rgb(0xa3a9b1))
				GameMap.Terrain.WATER, GameMap.Terrain.BRIDGE:
					g.draw_rect(Rect2(x, y, t, t), Palette.WATER)
					var wave := Color(Palette.WATER_LIGHT, 0.7)
					var k: int = r % 2
					Paint.line(g, x + 6 + k * 10, y + 12, x + 18 + k * 10, y + 12, 2, wave)
					Paint.line(g, x + 14 - k * 8, y + 28, x + 26 - k * 8, y + 28, 2, wave)
					if map.terrain_at(c, r) == GameMap.Terrain.BRIDGE:
						g.draw_rect(Rect2(x, y + 2, t, t - 4), Palette.BRIDGE)
						var px: float = x + 8
						while px < x + t:
							Paint.line(g, px, y + 2, px, y + t - 2, 1.5, Palette.BRIDGE_DARK)
							px += 8
						g.draw_rect(Rect2(x, y, t, 3), Palette.BRIDGE_DARK)
						g.draw_rect(Rect2(x, y + t - 3, t, 3), Palette.BRIDGE_DARK)
				_:
					g.draw_rect(Rect2(x, y, t, t), grass)
	# Darker edges where the road meets anything else, so it reads clearly.
	for r: int in Config.ROWS:
		for c: int in Config.COLS:
			if map.terrain_at(c, r) != GameMap.Terrain.ROAD:
				continue
			var x: float = c * t
			var y: float = r * t
			if _is_edge(map, c, r - 1):
				g.draw_rect(Rect2(x, y, t, 3), Palette.PATH_EDGE)
			if _is_edge(map, c, r + 1):
				g.draw_rect(Rect2(x, y + t - 3, t, 3), Palette.PATH_EDGE)
			if _is_edge(map, c - 1, r):
				g.draw_rect(Rect2(x, y, 3, t), Palette.PATH_EDGE)
			if _is_edge(map, c + 1, r):
				g.draw_rect(Rect2(x + t - 3, y, 3, t), Palette.PATH_EDGE)
	# Faint grid on buildable ground.
	var grid := Color(0, 0, 0, 0.08)
	for c: int in range(1, Config.COLS):
		g.draw_line(Vector2(c * t, 0), Vector2(c * t, Config.FIELD_H), grid, 1)
	for r: int in range(1, Config.ROWS):
		g.draw_line(Vector2(0, r * t), Vector2(Config.FIELD_W, r * t), grid, 1)
	# Entry and exit arrows.
	for s: Vector2i in map.starts:
		_arrow(g, s, true)
	for e: Vector2i in map.ends:
		_arrow(g, e, false)


func _is_edge(map: GameMap, c: int, r: int) -> bool:
	return GameMap.in_bounds(c, r) and not map.is_road(c, r)


func _arrow(g: CanvasItem, t: Vector2i, inward: bool) -> void:
	var d: Vector2i = GameMap.outward(t)
	var s: float = -1.0 if inward else 1.0
	var p: Vector2 = GameMap.tile_center(t)
	var ax: float = d.x * s
	var ay: float = d.y * s
	Paint.fill_triangle(g, p.x + ax * 10, p.y + ay * 10,
		p.x - ax * 6 - ay * 8, p.y - ay * 6 - ax * 8,
		p.x - ax * 6 + ay * 8, p.y - ay * 6 + ax * 8, Color(1, 1, 1, 0.55))


## Levels where enemies re-route: dotted line showing the route they will take right now.
func _draw_path_preview(g: CanvasItem) -> void:
	var map: GameMap = world.map
	if not map.flow:
		return
	var dist: PackedInt32Array = world.distance_field
	var dot := Color(1, 1, 1, 0.35)
	for s: Vector2i in map.starts:
		var cur: Vector2i = s
		var dir: Vector2i = GameMap.NO_TILE
		var i: int = 0
		while cur != GameMap.NO_TILE and i < 400:
			var p: Vector2 = GameMap.tile_center(cur)
			g.draw_circle(p, 3, dot)
			var next: Vector2i = GameMap.next_tile(dist, cur, dir)
			if next != GameMap.NO_TILE:
				dir = next - cur
				g.draw_circle(p + Vector2(dir) * (Config.TILE / 2.0), 2, dot)
			cur = next
			i += 1


## Walls (and the stone under towers on the road).
func _draw_walls(g: CanvasItem) -> void:
	for tile: Vector2i in world.walls:
		AbilityArt.draw_wall_tile(g, tile.x * Config.TILE, tile.y * Config.TILE)


func _draw_mines(g: CanvasItem) -> void:
	var blink: float = 0.5 + 0.5 * sin(_frame_count * 0.18)
	for m: World.Mine in world.mines:
		AbilityArt.draw_mine(g, Vector2(m.x, m.y), blink)


## What the abilities show on the field: tint and frame while one lasts,
## airstrikes on their way, focus marks.
func _draw_abilities(g: CanvasItem) -> void:
	var field := Rect2(0, 0, Config.FIELD_W, Config.FIELD_H)
	var effects: Dictionary[String, Color] = {
		"slow": Color(0.35, 0.65, 1.0), "boost": Color(1.0, 0.6, 0.2), "bounty": Color(1.0, 0.85, 0.25),
	}
	var inset: float = 1.0
	for id: String in effects:
		if world.is_active(id):
			var c: Color = effects[id]
			g.draw_rect(field, Color(c, 0.06))
			g.draw_rect(field.grow(-inset), Color(c, 0.55), false, 3)
			inset += 4.0
	for st: World.Strike in world.strikes:
		var total: float = Abilities.get_def("strike").duration * Config.TICK_RATE
		var progress: float = clampf(1.0 - (st.due - world.tick) / total, 0.0, 1.0)
		var orange: Color = Palette.rgb(0xff8c42)
		g.draw_circle(Vector2(st.x, st.y), st.radius * progress, Color(orange, 0.22))
		Paint.stroke_circle(g, st.x, st.y, st.radius, 3, Color(orange, 0.9))
		Paint.line(g, st.x - 10, st.y, st.x + 10, st.y, 2, orange)
		Paint.line(g, st.x, st.y - 10, st.x, st.y + 10, 2, orange)
	for e: Enemy in world.enemies:
		if e.mark_ticks > 0:
			var x: float = Format.lerp_value(e.prev_x, e.x, _alpha)
			var y: float = Format.lerp_value(e.prev_y, e.y, _alpha)
			var r: float = e.radius + 7
			Paint.stroke_circle(g, x, y, r, 2.5, Palette.RED)
			for k: int in 4:
				var a: float = k * PI / 2 + _frame_count * 0.05
				Paint.line(g, x + cos(a) * (r - 3), y + sin(a) * (r - 3), x + cos(a) * (r + 5), y + sin(a) * (r + 5), 2.5, Palette.RED)


# ---- per-frame sync ----------------------------------------------------------

## Syncs the views with the world. `alpha` is the fraction between ticks.
func sync(alpha: float) -> void:
	_alpha = alpha
	_frame_count += 1
	if world.map.flow:
		var key: String = ";".join(world.towers.map(func(t: Tower) -> String: return "%d,%d" % [t.col, t.row]))
		key += "|" + ";".join(world.walls.keys().map(func(t: Vector2i) -> String: return "%d,%d" % [t.x, t.y]))
		if key != _path_key:
			_path_key = key
			_path_preview.queue_redraw()
	var walls_key: String = ";".join(world.walls.keys().map(func(t: Vector2i) -> String: return "%d,%d" % [t.x, t.y]))
	if walls_key != _wall_key:
		_wall_key = walls_key
		_walls.queue_redraw()
	if not world.mines.is_empty() or _mines_drawn:
		_mines.queue_redraw()
	_mines_drawn = not world.mines.is_empty()
	_abilities.queue_redraw()
	_sync_towers()
	_sync_enemies()
	if _frame_count % 3 == 0:
		for b: Bullet in world.bullets:
			if b.type == Towers.BulletType.MISSILE:
				var x: float = Format.lerp_value(b.prev_x, b.x, alpha)
				var y: float = Format.lerp_value(b.prev_y, b.y, alpha)
				_smoke.explode(1, x - cos(b.angle) * 6, y - sin(b.angle) * 6)
	if not _rails.is_empty():
		var dt: float = get_process_delta_time()
		for r: PackedFloat32Array in _rails:
			r[4] -= dt
		_rails = _rails.filter(func(r: PackedFloat32Array) -> bool: return r[4] > 0)
	_bullets.queue_redraw()
	_beams.queue_redraw()
	_bars.queue_redraw()


func _sync_towers() -> void:
	var live: Dictionary[Tower, bool] = {}
	for t: Tower in world.towers:
		live[t] = true
	for t: Tower in _towers.keys():
		if not live.has(t):
			_towers[t].queue_free()
			_towers.erase(t)
	for t: Tower in world.towers:
		var v: TowerView = _towers.get(t)
		if v == null:
			v = TowerView.new(t)
			add_child(v)
			_towers[t] = v
		v.sync(_alpha, _frame_count)


func _sync_enemies() -> void:
	var live: Dictionary[Enemy, bool] = {}
	for e: Enemy in world.enemies:
		live[e] = true
	for e: Enemy in _enemies.keys():
		if not live.has(e):
			_enemies[e].queue_free()
			_enemies.erase(e)
	for e: Enemy in world.enemies:
		var v: EnemyView = _enemies.get(e)
		if v == null:
			v = EnemyView.new(e)
			add_child(v)
			_enemies[e] = v
		v.sync(_alpha, _frame_count)


func tower_view(t: Tower) -> TowerView:
	return _towers.get(t)


func enemy_view(e: Enemy) -> EnemyView:
	return _enemies.get(e)


func _draw_beams(g: CanvasItem) -> void:
	for t: Tower in world.towers:
		if t.def.behavior != Towers.Behavior.BEAM:
			continue
		var heat: float = t.heat_fraction
		var glow: Color = t.branch.color if t.branch != null else Palette.rgb(0xd35cff)
		var core: Color = glow.lerp(Color.WHITE, 0.75)
		var width: float = 1.4 if t.branch_id == "lance" else (0.7 if t.branch_id == "prism" else 1.0)
		var sx: float = t.x + cos(t.angle) * 14
		var sy: float = t.y + sin(t.angle) * 14
		for e: Enemy in t.targets:
			if not e.alive:
				continue
			var tx: float = Format.lerp_value(e.prev_x, e.x, _alpha)
			var ty: float = Format.lerp_value(e.prev_y, e.y, _alpha)
			Paint.line(g, sx, sy, tx, ty, (6 + 6 * heat) * width, Color(glow, 0.25 + 0.2 * heat))
			Paint.line(g, sx, sy, tx, ty, (2 + 2 * heat) * width, Color(core, 0.95))
			g.draw_circle(Vector2(tx, ty), (3 + 3 * heat) * width, Color(1, 1, 1, 0.9))
	# Sniper rail shots: a bright line that fades fast.
	var gold: Color = Palette.rgb(0xffd166)
	for r: PackedFloat32Array in _rails:
		var a: float = clampf(r[4] / RAIL_TIME, 0.0, 1.0)
		Paint.line(g, r[0], r[1], r[2], r[3], 7 * a + 1, Color(gold, 0.35 * a))
		Paint.line(g, r[0], r[1], r[2], r[3], 2, Color(1, 1, 1, 0.95 * a))


func _draw_bullets(g: CanvasItem) -> void:
	for b: Bullet in world.bullets:
		var x: float = Format.lerp_value(b.prev_x, b.x, _alpha)
		var y: float = Format.lerp_value(b.prev_y, b.y, _alpha)
		match b.type:
			Towers.BulletType.SHELL:
				# Fake a ballistic arc: shells grow a little towards the middle of their
				# flight (a lot for a mortar's long lob).
				var p: float = b.travelled / b.flight if b.flight > 0 else 1.0
				var lob: float = 0.5 if b.flight < 200 else 1.2
				var s: float = (1 + sin(PI * p) * lob) / 2
				g.draw_set_transform(Vector2(x, y), 0, Vector2(s, s))
				Paint.fill_circle(g, 0, 0, 6, Palette.rgb(0x222831))
				Paint.fill_circle(g, -2, -2, 2, Palette.rgb(0x6c757d))
			Towers.BulletType.MISSILE:
				var k: float = b.radius / 4.0 # swarm missiles are small, seekers big
				g.draw_set_transform(Vector2(x, y), b.angle, Vector2(k, k))
				Paint.fill_rect(g, -7, -2.5, 10, 5, Palette.rgb(0x6c757d))
				Paint.fill_triangle(g, 3, -3.5, 7, 0, 3, 3.5, Palette.rgb(0xe63946))
				Paint.fill_rect(g, -7, -1.5, 2, 3, Palette.rgb(0xffb703))
			_:
				g.draw_set_transform(Vector2(x, y), b.angle)
				Paint.fill_rounded_rect(g, -6, -2, 12, 4, 2, Palette.rgb(0xfff3b0))
				Paint.fill_rounded_rect(g, 1, -2, 5, 4, 2, Color.WHITE)
	g.draw_set_transform(Vector2.ZERO)


func _draw_bars(g: CanvasItem) -> void:
	var shield_color: Color = Palette.rgb(0x7ad3ff)
	for e: Enemy in world.enemies:
		var x: float = Format.lerp_value(e.prev_x, e.x, _alpha)
		var y: float = Format.lerp_value(e.prev_y, e.y, _alpha)
		if e.max_shield > 0 and e.shield > 0:
			var f: float = e.shield / e.max_shield
			Paint.stroke_circle(g, x, y, e.radius + 5, 2, Color(shield_color, 0.35 + 0.5 * f))
			g.draw_circle(Vector2(x, y), e.radius + 5, Color(shield_color, 0.12 * f))
		if e.def.boss:
			continue # bosses get a big bar at the top of the screen
		if e.hitpoints >= e.max_hitpoints and (e.max_shield == 0 or e.shield >= e.max_shield):
			continue
		var bx: float = x - 12
		var by: float = y - e.radius - 10
		var frac: float = maxf(0.0, e.hitpoints / e.max_hitpoints)
		g.draw_rect(Rect2(bx - 1, by - 1, 26, 6), Color(0, 0, 0, 0.6))
		var bar: Color = Palette.GREEN if frac > 0.5 else (Palette.GOLD if frac > 0.25 else Palette.RED)
		g.draw_rect(Rect2(bx, by, 24 * frac, 4), bar)
		if e.max_shield > 0:
			g.draw_rect(Rect2(bx, by - 3, 24 * (e.shield / e.max_shield), 2), shield_color)
	# Frozen enemies are cased in ice.
	for e: Enemy in world.enemies:
		if e.stun_ticks > 0:
			var x: float = Format.lerp_value(e.prev_x, e.x, _alpha)
			var y: float = Format.lerp_value(e.prev_y, e.y, _alpha)
			g.draw_circle(Vector2(x, y), e.radius + 2, Color(0.75, 0.92, 1.0, 0.45))
			Paint.stroke_circle(g, x, y, e.radius + 2, 2, Color(1, 1, 1, 0.8))
			Paint.line(g, x - e.radius * 0.5, y - e.radius * 0.6, x - e.radius * 0.1, y - e.radius * 0.1, 2, Color(1, 1, 1, 0.8))
	# Tower level pips (in the branch's colour after level 3) and beacon boost marker.
	for t: Tower in world.towers:
		var pip: Color = t.branch.color if t.branch != null else Palette.GOLD
		for i: int in t.level:
			var px: float = t.x - 4 + i * 8 - (t.level - 1) * 4 + 4
			Paint.fill_circle(g, px, t.y + 17, 3.5, Color(0, 0, 0, 0.6))
			Paint.fill_circle(g, px, t.y + 17, 2.5, pip)
		if t.buff > 0:
			Paint.fill_triangle(g, t.x + 12, t.y - 10, t.x + 16, t.y - 16, t.x + 20, t.y - 10, Color(Palette.GOLD, 0.95))


# ---- events ------------------------------------------------------------------

func _sound(name: String) -> void:
	if not quiet:
		Audio.play(name)


func _shake(duration_ms: float, intensity: float) -> void:
	if not quiet and fx != null:
		fx.shake(duration_ms, intensity)


## Turns world events into visual effects and sounds. Clears the world's event list.
func handle_events(events: Array[WorldEvent]) -> void:
	for ev: WorldEvent in events:
		match ev.type:
			WorldEvent.Type.SHOT:
				if SHOT_SOUND.has(ev.kind):
					_sound(SHOT_SOUND[ev.kind])
			WorldEvent.Type.KILL:
				var boss: bool = Enemies.get_def(ev.enemy).boss
				var big: bool = ev.enemy == "tank" or ev.enemy == "armored"
				_explosion.explode(60 if boss else (22 if big else 12), ev.x, ev.y)
				if boss:
					_rings.add(ev.x, ev.y, 120, Palette.rgb(0xff8c42), 700)
					_shake(400, 0.012)
					_sound("bigExplosion")
				else:
					_sound("explode" if big else "pop")
					if big:
						_shake(120, 0.003)
				if not quiet:
					float_text(ev.x, ev.y - 10, "+$%d" % ev.amount, Palette.GOLD)
			WorldEvent.Type.HIT:
				_sparks.explode(6 if ev.bullet == Towers.BulletType.MISSILE else 3, ev.x, ev.y)
				_sound("hit")
			WorldEvent.Type.EXPLODE:
				_explosion.explode(16, ev.x, ev.y)
				_rings.add(ev.x, ev.y, ev.radius, Palette.rgb(0xffb347), 350)
				_sound("explode")
			WorldEvent.Type.PULSE:
				_rings.add(ev.x, ev.y, ev.radius, Palette.rgb(0x7ad3ff), 600)
				_frost.explode(10, ev.x, ev.y)
				_sound("frost")
			WorldEvent.Type.HEAL:
				_rings.add(ev.x, ev.y, ev.radius, Palette.rgb(0x69db7c), 500)
				_sound("heal")
			WorldEvent.Type.SUMMON:
				_rings.add(ev.x, ev.y, 60, Palette.rgb(0xff6b6b), 500)
				_sound("summon")
			WorldEvent.Type.BUILD:
				_dust.explode(14, ev.x, ev.y + 8)
				_sound("build")
			WorldEvent.Type.UPGRADE:
				_stars.explode(16, ev.x, ev.y)
				_rings.add(ev.x, ev.y, 30, Palette.GOLD, 400)
				if Towers.is_branch(ev.kind):
					var b: TowerBranch = Towers.get_branch(ev.kind)
					_rings.add(ev.x, ev.y, 55, b.color, 700)
					if not quiet:
						float_text(ev.x, ev.y - 14, b.name + "!", b.color)
				_sound("upgrade")
			WorldEvent.Type.RAIL:
				_rails.append(PackedFloat32Array([ev.x, ev.y, ev.x2, ev.y2, RAIL_TIME]))
				_sparks.explode(4, ev.x2, ev.y2)
			WorldEvent.Type.SELL:
				_dust.explode(10, ev.x, ev.y)
				float_text(ev.x, ev.y - 10, "+$%d" % ev.amount, Palette.GOLD)
				_sound("sell")
			WorldEvent.Type.WALL_BUILT:
				_dust.explode(10, ev.x, ev.y + 8)
				_sound("build")
			WorldEvent.Type.WALL_SOLD:
				_dust.explode(10, ev.x, ev.y)
				float_text(ev.x, ev.y - 10, "+$%d" % ev.amount, Palette.GOLD)
				_sound("sell")
			WorldEvent.Type.MINE_PLACED:
				_dust.explode(6, ev.x, ev.y)
				_sound("build")
			WorldEvent.Type.MINE_BLAST:
				_explosion.explode(18, ev.x, ev.y)
				_rings.add(ev.x, ev.y, ev.radius, Palette.rgb(0xffb347), 350)
				_shake(120, 0.003)
				_sound("explode")
			WorldEvent.Type.STRIKE:
				_explosion.explode(40, ev.x, ev.y)
				_rings.add(ev.x, ev.y, ev.radius, Palette.rgb(0xffb347), 450)
				_rings.add(ev.x, ev.y, ev.radius * 0.6, Palette.rgb(0xff6b6b), 300)
				_shake(260, 0.007)
				_sound("bigExplosion")
			WorldEvent.Type.ABILITY:
				_ability_used(ev)
			WorldEvent.Type.LEAK:
				if quiet:
					continue
				float_text(clampf(ev.x, 30, Config.FIELD_W - 30), clampf(ev.y, 20, Config.FIELD_H - 20),
					"-%d ♥" % ev.amount, Palette.RED)
				_shake(140, 0.004)
				if fx != null:
					fx.flash(160, Color8(180, 30, 30))
				_sound("leak")
	events.clear()


## Effects and sounds when an ability is used.
func _ability_used(ev: WorldEvent) -> void:
	var middle := Vector2(Config.FIELD_W / 2.0, Config.FIELD_H / 2.0)
	match ev.kind:
		"slow":
			_rings.add(middle.x, middle.y, 520, Palette.rgb(0x7ad3ff), 800)
			float_text(middle.x, 120, "Time slow", Palette.rgb(0x7ad3ff))
			_sound("frost")
		"boost":
			for t: Tower in world.towers:
				_rings.add(t.x, t.y, 34, Palette.GOLD, 450)
			float_text(middle.x, 120, "Damage boost", Palette.rgb(0xffb347))
			_sound("upgrade")
		"bounty":
			_stars.explode(20, middle.x, 90)
			float_text(middle.x, 120, "Bounty: kills pay double", Palette.GOLD)
			_sound("upgrade")
		"wind":
			_stars.explode(24, middle.x, 90)
			float_text(middle.x, 120, "+%d ♥" % roundi(Abilities.get_def("wind").power), Palette.GREEN)
			_sound("heal")
		"strike":
			_rings.add(ev.x, ev.y, ev.radius, Palette.rgb(0xff8c42), 1000)
			_sound("click")
		"mark":
			_rings.add(ev.x, ev.y, 34, Palette.RED, 500)
			_sound("click")


## Text that floats up and fades out.
func float_text(x: float, y: float, text: String, color: Color) -> void:
	var label: TextLabel = Ui.text(self, x, y, text, 15, color, true, Vector2(0.5, 0.5))
	label.set_outline(3)
	label.z_index = D_FLOATERS
	label.z_as_relative = false
	var tween: Tween = label.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	tween.chain().tween_callback(label.queue_free)


# ---- what the player sees (read by the scene tests) ---------------------------

## Texts floating up right now ("+$5", "-1 ♥", "Not enough money", ...).
func floating_texts() -> PackedStringArray:
	var out: PackedStringArray = []
	for child: Node in get_children():
		var label := child as TextLabel
		if label != null and not label.is_queued_for_deletion():
			out.append(label.text)
	return out


## Particles and rings still playing.
func effect_count() -> int:
	return _rings.count() + _explosion.count() + _sparks.count() + _dust.count() + _frost.count() + _stars.count()
