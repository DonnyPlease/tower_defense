class_name Hud
extends Control
## The right-hand sidebar: stats, build grid, context panel and wave controls.
## Positions are relative to the sidebar, which starts at x = FIELD_W.

const X: float = 12.0
const W: float = Config.SIDEBAR_W - 24
const DEPTH: int = 100
const PANEL_Y: float = 290.0
const PANEL_H: float = 180.0
const MODE_LABEL: Array[String] = ["First", "Last", "Strongest", "Closest"]
const UNAFFORDABLE: Color = Color("#ffd0cc")

## Build buttons of the towers the player owns (locked ones live in the tech tree).
var tower_buttons: Dictionary[String, GameButton] = {}
## The "?" slot after them while some towers are still locked (null when all are owned).
var teaser_button: GameButton = null
var upgrade_button: GameButton
## The two branches a level-3 tower can grow into (shown instead of Upgrade).
var branch_buttons: Array[GameButton] = []
var target_button: GameButton
var sell_button: GameButton
var wave_button: GameButton
var pause_button: GameButton
var speed_button: GameButton
var music_button: GameButton
var sfx_button: GameButton

var _host: GameScene
var _money: TextLabel
var _lives: TextLabel
var _wave: TextLabel
var _panel_title: TextLabel
var _panel_body: TextLabel
var _preview_label: TextLabel
var _preview: Control
var _preview_key: String = "-"
var _hovered: String = ""
var _hovered_ability: String = ""
var _hovered_branch: int = -1
var _panel_extra: TextLabel


func _init(host: GameScene) -> void:
	_host = host
	position = Vector2(Config.FIELD_W, 0)
	size = Vector2(Config.SIDEBAR_W, Config.HEIGHT)
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_money = Ui.text(self, X + 4, 10, "", 19, Palette.GOLD, true)
	_lives = Ui.text(self, X + 4, 36, "", 19, Palette.RED, true)
	_wave = Ui.text(self, X + 4, 62, "", 19, Palette.TEXT, true)

	# 2 x 4 grid of build buttons: the towers the player owns, then a "?".
	var kinds: Array[String] = _host.buildable_kinds()
	for i: int in kinds.size():
		var kind: String = kinds[i]
		var b := GameButton.new(_cell(i), "", func() -> void: _host.select_tool("" if _host.tool == kind else kind))
		b.font(13).key(str(i + 1)).icon(func(ci: CanvasItem, center: Vector2, s: float) -> void:
			TowerArt.draw_icon(ci, kind, center, s))
		b.hover_callback(func(on: bool) -> void: _on_tower_hover(kind, on))
		add_child(b)
		tower_buttons[kind] = b
	if kinds.size() < Towers.KINDS.size():
		teaser_button = GameButton.new(_cell(kinds.size()), "?", func() -> void: Audio.play("error")).font(22)
		teaser_button.hover_callback(func(on: bool) -> void: _on_tower_hover("?", on))
		add_child(teaser_button)

	# Context panel: the selected tower, or info about a tower type, or tips.
	_panel_title = Ui.text(self, X + 10, PANEL_Y + 8, "", 15, Palette.TEXT, true)
	_panel_body = Ui.text(self, X + 10, PANEL_Y + 30, "", 12, Palette.TEXT_DIM)
	_panel_body.set_wrap(W - 20)
	_panel_body.set_line_spacing(2)
	upgrade_button = GameButton.new(Rect2(X + 8, PANEL_Y + 80, W - 16, 34), "Upgrade", _host.upgrade_selected) \
		.primary().font(14).key("U")
	add_child(upgrade_button)
	var bw: float = (W - 16 - 6) / 2
	for i: int in 2:
		var b := GameButton.new(Rect2(X + 8 + i * (bw + 6), PANEL_Y + 78, bw, 38), "", func() -> void: _host.choose_branch(i)) \
			.primary().font(12).sublabel("")
		b.hover_callback(func(on: bool) -> void:
			if on:
				_hovered_branch = i
			elif _hovered_branch == i:
				_hovered_branch = -1)
		b.visible = false
		add_child(b)
		branch_buttons.append(b)
	_panel_extra = Ui.text(self, X + 10, PANEL_Y + 122, "", 12, Palette.TEXT_DIM)
	_panel_extra.set_wrap(W - 20)
	_panel_extra.set_line_spacing(2)
	target_button = GameButton.new(Rect2(X + 8, PANEL_Y + 118, W - 16, 28), "Target: First", _host.cycle_target_mode) \
		.font(13).key("T")
	add_child(target_button)
	sell_button = GameButton.new(Rect2(X + 8, PANEL_Y + 150, W - 16, 28), "Sell", _host.sell_selected) \
		.danger().font(13).key("S")
	add_child(sell_button)

	_preview_label = Ui.text(self, X, 474, "Next:", 12, Palette.TEXT_DIM)
	_preview = Control.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)

	wave_button = GameButton.new(Rect2(X, 494, W, 50), "Start wave", _host.start_wave).primary().font(15).sublabel("")
	add_child(wave_button)
	var q: float = (W - 3 * 6) / 4
	pause_button = _small(0, q, "II", _host.toggle_pause)
	speed_button = _small(1, q, "1x", _host.toggle_speed)
	music_button = _small(2, q, "♪", _host.toggle_music)
	sfx_button = _small(3, q, "FX", _host.toggle_sfx)


## Where the build button in slot `i` of the 2 x 4 grid goes.
func _cell(i: int) -> Rect2:
	var cell_w: float = (W - 8) / 2
	var cell_h: float = 44.0
	@warning_ignore("integer_division")
	var row: int = i / 2
	return Rect2(X + (i % 2) * (cell_w + 8), 90 + row * (cell_h + 6), cell_w, cell_h)


func _small(i: int, q: float, label: String, on_click: Callable) -> GameButton:
	var b := GameButton.new(Rect2(X + i * (q + 6), 552, q, 38), label, on_click).font(14)
	add_child(b)
	return b


func _draw() -> void:
	draw_rect(Rect2(0, 0, Config.SIDEBAR_W, Config.HEIGHT), Palette.PANEL)
	draw_rect(Rect2(0, 0, 2, Config.HEIGHT), Palette.BORDER)
	Paint.fill_rounded_rect(self, X, PANEL_Y, W, PANEL_H, 8, Color(Palette.PANEL_LIGHT, 0.6))


## Shows an ability's help in the panel while the pointer is over its button ("" to stop).
func show_ability_help(id: String) -> void:
	_hovered_ability = id


## Shows a tower's help in the panel while the pointer is over a button for it
## (the build menu's too).
func show_tower_help(kind: String, on: bool) -> void:
	_on_tower_hover(kind, on)


func _on_tower_hover(kind: String, on: bool) -> void:
	if on:
		_hovered = kind
	elif _hovered == kind:
		_hovered = ""


## Called every frame; only touches what changed.
func refresh() -> void:
	var world: World = _host.world
	_money.show_text("$ %d" % world.money)
	_lives.show_text("♥ %d" % world.lives)
	var total: int = world.total_waves()
	_wave.show_text("Wave %d%s" % [maxi(0, world.wave_index + 1), (" / %d" % total) if total > 0 else ""])

	for kind: String in tower_buttons:
		var b: GameButton = tower_buttons[kind]
		var cost: int = world.cost_of(kind)
		b.set_label("$%d" % cost, Palette.TEXT if world.money >= cost else Palette.RED) \
			.set_selected(_host.tool == kind).set_enabled(world.status == World.Status.PLAYING)

	_refresh_panel()
	_refresh_preview()

	if world.status != World.Status.PLAYING:
		wave_button.set_label("Game over").set_sublabel("").set_enabled(false)
	elif world.next_wave() == null:
		wave_button.set_label("Final wave").set_sublabel("%d enemies left" % world.enemies_remaining()).set_enabled(false)
	elif world.is_spawning():
		wave_button.set_label("Wave %d" % (world.wave_index + 1)) \
			.set_sublabel("%d enemies left" % world.enemies_remaining()).set_enabled(false)
	elif world.early_bonus_now() > 0:
		wave_button.set_label("Call wave %d" % (world.wave_index + 2)) \
			.set_sublabel("Space · +$%d early" % world.early_bonus_now(), Palette.GOLD).set_enabled(true)
	else:
		wave_button.set_label("Start wave %d" % (world.wave_index + 2)) \
			.set_sublabel("Space · build first!" if world.wave_index < 0 else "Space · ready").set_enabled(true)
	pause_button.set_label("▶" if _host.paused else "II")
	speed_button.set_label("%dx" % _host.speed).set_selected(_host.speed > 1)
	music_button.set_label("♪", Palette.TEXT if _host.music_on() else Palette.TEXT_DIM).set_selected(_host.music_on())
	sfx_button.set_label("FX", Palette.TEXT if _host.sfx_on() else Palette.TEXT_DIM).set_selected(_host.sfx_on())


func _refresh_panel() -> void:
	var world: World = _host.world
	var selected: Tower = _host.selected
	var show_tower_buttons: bool = selected != null
	var picking: bool = selected != null and selected.needs_branch()
	if not picking:
		_hovered_branch = -1
	var describing: bool = picking and _hovered_branch >= 0
	upgrade_button.visible = show_tower_buttons and not picking
	for b: GameButton in branch_buttons:
		b.visible = picking
	target_button.visible = show_tower_buttons and not describing and selected.def.behavior != Towers.Behavior.SUPPORT \
		and selected.def.behavior != Towers.Behavior.AURA
	# Set once per frame: hiding a button and showing it again resets a press
	# in progress, so a click that spans two frames would be lost.
	var wall_selected: bool = selected == null and _host.selected_wall != GameMap.NO_TILE
	sell_button.visible = (show_tower_buttons and not describing) or wall_selected
	_panel_extra.show_text("")

	if selected != null:
		_panel_title.show_text("%s  ·  Level %d" % [selected.display_name, selected.level + 1])
		if picking:
			_refresh_branches(world, selected)
		if describing:
			var br: TowerBranch = selected.def.branches[_hovered_branch]
			_panel_title.show_text("%s  ·  $%d" % [br.name, world.branch_cost_of(selected, br.id)])
			_panel_body.show_text(br.description)
			_panel_extra.show_text(Format.tower_stats_text(selected.kind, Towers.BRANCH_LEVEL, -1, 0, br.id) +
				("" if world.is_branch_unlocked(br.id) else "\n\nUnlock it in the tech tree."))
			return
		var extra: String = ""
		if selected.high_ground:
			var on_wall: bool = world.has_wall(selected.col, selected.row) and not world.map.is_high_ground(selected.col, selected.row)
			extra = "\nOn a wall: +25% range" if on_wall else "\nHigh ground: +25% range"
		_panel_body.show_text(Format.tower_stats_text(selected.kind, selected.level, selected.attack_range, selected.buff,
			selected.branch_id) + extra)
		var cost: int = world.upgrade_cost_of(selected)
		if cost == Tower.NO_UPGRADE:
			upgrade_button.set_label("Max level").set_enabled(false)
		else:
			upgrade_button.set_label("Upgrade  $%d" % cost, Palette.TEXT if world.money >= cost else UNAFFORDABLE) \
				.set_enabled(world.money >= cost and world.status == World.Status.PLAYING)
		target_button.set_label("Target: %s" % MODE_LABEL[selected.target_mode])
		sell_button.set_label("Sell  +$%d" % selected.sell_value())
		return

	var wall_tile: Vector2i = _host.selected_wall
	if wall_tile != GameMap.NO_TILE:
		var paid: int = world.walls.get(wall_tile, 0)
		sell_button.set_label("Sell  +$%d" % paid)
		_panel_title.show_text("Wall")
		_panel_body.show_text("Enemies walk around it, if there is room: it can never block the path completely.\n\nBuild a tower on top of it for +25% range.")
		return

	var help: String = _hovered_ability
	if help.is_empty() and _hovered.is_empty() and _host.tool.is_empty():
		help = _host.aim
	if not help.is_empty():
		var def: Abilities.AbilityDef = Abilities.get_def(help)
		_panel_title.show_text("%s  ·  $%d" % [def.name, world.ability_cost(help)])
		_panel_body.show_text(_ability_text(def))
		return

	if _hovered == "?":
		_panel_title.show_text("More towers")
		_panel_body.show_text("Spend your stars in the tech tree (main menu) to unlock more towers and their branches.")
		return
	var kind: String = _hovered if not _hovered.is_empty() else _host.tool
	if not kind.is_empty():
		var d: TowerDef = Towers.get_def(kind)
		_panel_title.show_text("%s  ·  $%d" % [d.name, world.cost_of(kind)])
		var hits: PackedStringArray = []
		if d.hits_ground:
			hits.append("ground")
		if d.hits_air:
			hits.append("air")
		_panel_body.show_text("\n".join(PackedStringArray([
			Format.tower_stats_text(kind, 0),
			"Hits: %s" % (" + ".join(hits) if not hits.is_empty() else "—"),
			"",
			d.description,
		])))
		return

	if not world.run_perks.is_empty():
		_panel_title.show_text("Field orders")
		var lines: PackedStringArray = []
		for id: String in world.run_perks:
			var def: RunPerks.RunPerkDef = RunPerks.get_def(id)
			lines.append("%s: %s" % [def.name, def.description])
		_panel_body.show_text("\n".join(lines))
		return
	_panel_title.show_text("Tips")
	if world.map.maze:
		_panel_body.show_text("No road here: enemies walk around your towers and walls.\n\nClick a tower or wall to upgrade or sell it.\nQ: wall. Bottom bar: abilities.")
	else:
		_panel_body.show_text("Pick a tower above, then click the grass to build.\n\nClick a placed tower to upgrade it, change its target or sell it.\nQ: wall. Bottom bar: abilities.")


## The two branch buttons of a level-3 tower: name and price, locked or not.
func _refresh_branches(world: World, tower: Tower) -> void:
	for i: int in branch_buttons.size():
		var b: GameButton = branch_buttons[i]
		var br: TowerBranch = tower.def.branches[i]
		var cost: int = world.branch_cost_of(tower, br.id)
		var unlocked: bool = world.is_branch_unlocked(br.id)
		b.set_label(br.name if unlocked else "🔒 " + br.name)
		b.set_sublabel("$%d" % cost, Palette.TEXT if world.money >= cost else UNAFFORDABLE)
		b.set_enabled(unlocked and world.money >= cost and world.status == World.Status.PLAYING)


func _ability_text(def: Abilities.AbilityDef) -> String:
	var facts: PackedStringArray = ["key %s" % def.key_label()]
	if def.cooldown > 0:
		facts.append("cooldown %d s" % roundi(def.cooldown))
	if def.duration > 0 and def.target != Abilities.Target.POINT:
		facts.append("lasts %d s" % roundi(def.duration))
	if def.cost_step > 0:
		facts.append("+$%d per wall" % def.cost_step)
	if def.limit > 0:
		facts.append("at most %d" % def.limit)
	return "%s\n\n%s" % [def.description, " · ".join(facts)]


## Small icons showing what the next wave brings.
func _refresh_preview() -> void:
	var wave: Wave = _host.world.next_wave()
	var types: Array[String] = []
	var counts: Dictionary[String, int] = {}
	if wave != null:
		for g: SpawnGroup in wave.groups:
			if not counts.has(g.type):
				types.append(g.type)
				counts[g.type] = 0
			counts[g.type] += g.count
	var key: String = ",".join(types.map(func(t: String) -> String: return "%s%d" % [t, counts[t]]))
	if key == _preview_key:
		return
	_preview_key = key
	for child: Node in _preview.get_children():
		child.queue_free()
	_preview_label.show_text("Next:" if wave != null else "")
	var x: float = X + 36
	for type: String in types:
		if x > X + W - 20:
			break
		var def: EnemyDef = Enemies.get_def(type)
		var icon := PainterView.new(func(ci: CanvasItem, center: Vector2, s: float) -> void:
			EnemyArt.draw(ci, def.art, center, s))
		icon.position = Vector2(x + 8 - 9, 481 - 9)
		icon.size = Vector2(18, 18)
		if def.has_tint:
			icon.modulate = def.tint
		_preview.add_child(icon)
		var count: TextLabel = Ui.text(_preview, x + 18, 474, "%d" % counts[type], 12, Palette.TEXT, true)
		x += 26 + count.size.x


# ---- what the player sees (read by the scene tests) ---------------------------

func money_text() -> String:
	return _money.text


func lives_text() -> String:
	return _lives.text


func wave_text() -> String:
	return _wave.text


func panel_title_text() -> String:
	return _panel_title.text


func panel_body_text() -> String:
	return _panel_body.text


## The second text block of the panel (a branch's stats while its button is hovered).
func panel_extra_text() -> String:
	return _panel_extra.text


## The next-wave preview as "type count" pairs, e.g. "scout8,racer5".
func preview_key() -> String:
	return _preview_key
