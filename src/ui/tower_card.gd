class_name TowerCard
extends Control
## Pops up next to the selected tower (or wall): its name and level, then
## Upgrade (or its two branches at level 3), Target and Sell, and a "Details"
## section that folds out with its stats, what the next level brings and how
## it has done. Folded or not is remembered for the next tower.

const W: float = 232.0
const PAD: float = 10.0
const DEPTH: int = 150
const MODE_LABEL: Array[String] = ["First", "Last", "Strongest", "Closest"]
const UNAFFORDABLE: Color = Color("#ffd0cc")
const GAP: float = 28.0 ## from the tower's centre to the card, in screen units
const WALL_TEXT: String = "Enemies walk around it, if there is room: it can never block the path completely. A tower on it gets +25% range."

## Whether the details are folded out (kept for the next tower selected).
static var details_open: bool = false

var upgrade_button: GameButton
## The two branches a level-3 tower can grow into (shown instead of Upgrade).
var branch_buttons: Array[GameButton] = []
var target_button: GameButton
var sell_button: GameButton
var details_button: GameButton
## Drawn this many times bigger (on phones, see Screen.ui_scale).
var ui_scale: float = 1.0:
	set(value):
		ui_scale = value
		if _tween == null or not _tween.is_running():
			scale = Vector2(value, value)
## Whether the pointer is on Upgrade (the next level's reach is then drawn on the map).
var upgrade_hovered: bool = false

var _host: GameScene
var _tower: Tower = null
var _wall: Vector2i = GameMap.NO_TILE
var _icon: PainterView
var _title: TextLabel
var _level: TextLabel
var _badge: TextLabel
var _pips: PainterView
var _details: TextLabel
var _chevron: PainterView
var _tween: Tween
var _pointer: Vector2 = Vector2.ZERO ## where the tower is, in the card's coordinates


func _init(host: GameScene) -> void:
	_host = host
	size = Vector2(W, 200)
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_icon = PainterView.new(func(ci: CanvasItem, center: Vector2, s: float) -> void:
		if _tower != null:
			TowerArt.draw_icon(ci, _tower.kind, center, s, _tower.branch_id)
		elif _wall != GameMap.NO_TILE:
			AbilityArt.draw_icon(ci, "wall", center, s))
	_icon.position = Vector2(PAD, 8)
	_icon.size = Vector2(34, 34)
	add_child(_icon)
	_title = Ui.text(self, 52, 7, "", 16, Palette.TEXT, true)
	_level = Ui.text(self, 52, 28, "", 12, Palette.TEXT_DIM)
	_pips = PainterView.new(func(g: CanvasItem, _center: Vector2, _s: float) -> void:
		if _tower == null:
			return
		var count: int = Towers.MAX_LEVEL + 1 if not _tower.def.branches.is_empty() else _tower.def.levels.size()
		for i: int in count:
			var color: Color = Palette.PANEL_LIGHTER
			if i <= _tower.level:
				color = Palette.GOLD if i < Towers.BRANCH_LEVEL else _tower.def.color
			Paint.fill_circle(g, 5 + i * 12, 5, 4, color))
	_pips.size = Vector2(70, 10)
	add_child(_pips)
	_badge = Ui.text(self, PAD + 2, 48, "", 12, Palette.GOLD)
	_badge.set_wrap(W - 2 * PAD - 4)

	upgrade_button = GameButton.new(Rect2(PAD, 0, W - 2 * PAD, 36), "Upgrade", _host.upgrade_selected) \
		.primary().font(14).key("U")
	upgrade_button.hover_callback(func(on: bool) -> void: upgrade_hovered = on)
	add_child(upgrade_button)
	var bw: float = (W - 2 * PAD - 6) / 2
	for i: int in 2:
		var b := GameButton.new(Rect2(PAD + i * (bw + 6), 0, bw, 40), "", func() -> void: _host.choose_branch(i)) \
			.primary().font(12).sublabel("")
		b.hover_callback(func(on: bool) -> void: _host.hud.show_branch_help(i, on))
		b.visible = false
		add_child(b)
		branch_buttons.append(b)
	target_button = GameButton.new(Rect2(PAD, 0, W - 2 * PAD, 30), "Target: First", _host.cycle_target_mode) \
		.font(13).key("T")
	add_child(target_button)
	sell_button = GameButton.new(Rect2(PAD, 0, W - 2 * PAD, 30), "Sell", _host.sell_selected).danger().font(13).key("S")
	add_child(sell_button)
	details_button = GameButton.new(Rect2(PAD, 0, W - 2 * PAD, 24), "Details", toggle_details).flat().font(12)
	add_child(details_button)
	_chevron = PainterView.new(func(ci: CanvasItem, center: Vector2, s: float) -> void:
		Icons.chevron(ci, center, s, details_open))
	_chevron.position = Vector2(details_button.size.x - 26, 2)
	_chevron.size = Vector2(20, 20)
	details_button.add_child(_chevron)
	_details = Ui.text(self, PAD + 4, 0, "", 12, Palette.TEXT_DIM).set_wrap(W - 2 * PAD - 8)
	_details.set_line_spacing(2)


func _draw() -> void:
	var h: float = size.y
	Paint.fill_rounded_rect(self, 3, 5, W, h, 12, Color(0, 0, 0, 0.32))
	# A little pointer towards the tower, on the side facing it.
	var py: float = clampf(_pointer.y, 18, h - 18)
	var bg := Color(Palette.PANEL, 0.97)
	if _pointer.x < 0:
		Paint.fill_triangle(self, -8, py, 1, py - 9, 1, py + 9, bg)
	elif _pointer.x > W:
		Paint.fill_triangle(self, W + 8, py, W - 1, py - 9, W - 1, py + 9, bg)
	Paint.fill_rounded_rect(self, 0, 0, W, h, 12, bg)
	Paint.stroke_rounded_rect(self, 0, 0, W, h, 12, 1, Palette.BORDER)
	if details_open and _tower != null:
		draw_rect(Rect2(PAD, details_button.position.y + details_button.size.y + 2, W - 2 * PAD, 1), Color(Palette.BORDER, 0.6))


## Shows the card for a tower, or a wall's tile (null and NO_TILE hide it), with a short pop-in.
func show_for(tower: Tower, wall: Vector2i = GameMap.NO_TILE) -> void:
	if tower != null:
		wall = GameMap.NO_TILE
	if tower == _tower and wall == _wall:
		return
	_tower = tower
	_wall = wall
	upgrade_hovered = false
	if _tween != null:
		_tween.kill()
	if tower == null and wall == GameMap.NO_TILE:
		visible = false
		return
	visible = true
	refresh()
	modulate.a = 0.0
	scale = Vector2.ONE * 0.94 * ui_scale
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.14)
	_tween.tween_property(self, "scale", Vector2.ONE * ui_scale, 0.14)


func toggle_details() -> void:
	details_open = not details_open
	_chevron.queue_redraw()
	refresh()


## Puts the card beside `at` (the tower, in screen units), to the right when
## it fits in `bounds`, else to the left, and inside `bounds` vertically.
func place(at: Vector2, bounds: Rect2) -> void:
	var k: float = ui_scale
	var x: float = at.x + GAP
	if x + W * k > bounds.end.x - 4:
		x = at.x - GAP - W * k
	x = maxf(bounds.position.x + 4, x)
	var y: float = clampf(at.y - 44 * k, bounds.position.y + 6, bounds.end.y - size.y * k - 6)
	position = Vector2(x, y).round()
	pivot_offset = Vector2(0.0 if x > at.x else W, clampf((at.y - y) / k, 0, size.y))
	var pointer: Vector2 = (at - position) / k
	if pointer != _pointer:
		_pointer = pointer
		queue_redraw()


## Called every frame while something is selected; only touches what changed.
func refresh() -> void:
	if _tower != null:
		_refresh_tower(_tower)
	elif _wall != GameMap.NO_TILE:
		_refresh_wall()


func _refresh_tower(t: Tower) -> void:
	var world: World = _host.world
	_title.show_text(t.display_name)
	_level.show_text("Level %d" % (t.level + 1))
	_pips.position = Vector2(_level.position.x + _level.size.x + 8, _level.position.y + 4)
	_pips.queue_redraw()
	_icon.queue_redraw()
	_level.visible = true
	_pips.visible = true
	var badge: String = ""
	if t.high_ground:
		var on_wall: bool = world.has_wall(t.col, t.row) and not world.map.is_high_ground(t.col, t.row)
		badge = "▲ On a wall: +25% range" if on_wall else "▲ High ground: +25% range"
	_badge.show_text(badge)
	var y: float = 48 + (_badge.size.y + 4 if not badge.is_empty() else 0.0)

	var picking: bool = t.needs_branch()
	upgrade_button.visible = not picking
	for b: GameButton in branch_buttons:
		b.visible = picking
		b.position.y = y
	upgrade_button.position.y = y
	if picking:
		for i: int in branch_buttons.size():
			var br: TowerBranch = t.def.branches[i]
			var cost: int = world.branch_cost_of(t, br.id)
			var unlocked: bool = world.is_branch_unlocked(br.id)
			branch_buttons[i].set_label(br.name if unlocked else "🔒 " + br.name)
			branch_buttons[i].set_sublabel("$%d" % cost, Palette.TEXT if world.money >= cost else UNAFFORDABLE)
			branch_buttons[i].set_enabled(unlocked and world.money >= cost and world.status == World.Status.PLAYING)
		y += 46
	else:
		var cost: int = world.upgrade_cost_of(t)
		if cost == Tower.NO_UPGRADE:
			upgrade_button.set_label("Max level").set_enabled(false)
		else:
			upgrade_button.set_label("Upgrade  $%d" % cost, Palette.TEXT if world.money >= cost else UNAFFORDABLE) \
				.set_enabled(world.money >= cost and world.status == World.Status.PLAYING)
		y += 42
	var aims: bool = t.def.behavior != Towers.Behavior.SUPPORT and t.def.behavior != Towers.Behavior.AURA
	target_button.visible = aims
	if aims:
		target_button.position.y = y
		target_button.set_label("Target: %s" % MODE_LABEL[t.target_mode])
		y += 36
	sell_button.position.y = y
	sell_button.set_label("Sell  +$%d" % t.sell_value())
	y += 36
	details_button.visible = true
	details_button.position.y = y
	details_button.set_label("Hide details" if details_open else "Details")
	y += details_button.size.y + 6
	_details.visible = details_open
	if details_open:
		_details.show_text(details_text_for(world, t))
		_details.move_to(PAD + 4, y + 4)
		y += _details.size.y + 12
	_resize(y)


func _refresh_wall() -> void:
	var world: World = _host.world
	_title.show_text("Wall")
	_level.visible = false
	_pips.visible = false
	_icon.queue_redraw()
	_badge.show_text(WALL_TEXT)
	upgrade_button.visible = false
	target_button.visible = false
	details_button.visible = false
	_details.visible = false
	for b: GameButton in branch_buttons:
		b.visible = false
	var y: float = 48 + _badge.size.y + 8
	sell_button.position.y = y
	sell_button.set_label("Sell  +$%d" % world.walls.get(_wall, 0))
	_resize(y + 36)


func _resize(h: float) -> void:
	if size.y != h:
		size.y = h
		queue_redraw()


## Stats now, how it has done, what the next level brings, and the tower's description.
static func details_text_for(world: World, t: Tower) -> String:
	var lines: PackedStringArray = [Format.tower_stats_text(t.kind, t.level, t.attack_range, t.buff, t.branch_id)]
	if t.def.behavior != Towers.Behavior.SUPPORT:
		lines.append("This game: %d kill%s  ·  %s damage" % [t.kills, "" if t.kills == 1 else "s", Format.compact(t.damage_done)])
	if not t.is_max_level() and not t.needs_branch():
		var next: int = t.level + 1
		var reach: float = Towers.level_stats(t.kind, next, t.branch_id).attack_range \
			* (Config.HIGH_GROUND_RANGE if t.high_ground else 1.0) * world.tower_range
		lines.append("")
		lines.append("Next level:")
		lines.append(Format.tower_stats_text(t.kind, next, reach, 0.0, t.branch_id))
	lines.append("")
	lines.append(t.branch.description if t.branch != null else t.def.description)
	return "\n".join(lines)


# ---- what the player sees (read by the scene tests) ---------------------------

## "Missile  ·  Level 2", or "Wall" ("" when hidden).
func title_text() -> String:
	if not visible:
		return ""
	return "%s  ·  %s" % [_title.text, _level.text] if _tower != null else _title.text


## The badge line and, when folded out, the details ("" when hidden).
func body_text() -> String:
	if not visible:
		return ""
	var parts: PackedStringArray = []
	if not _badge.text.is_empty():
		parts.append(_badge.text)
	if _details.visible:
		parts.append(_details.text)
	return "\n".join(parts)
