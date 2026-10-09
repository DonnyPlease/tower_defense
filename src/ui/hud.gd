class_name Hud
extends Control
## The slim rail at the right edge of the game screen: money, lives and wave
## at the top, the towers to build, and the wave controls at the bottom. The
## gear button opens a small menu (music, sound, the pause menu).
##
## The selected tower's (or wall's) controls are not here but on the
## TowerCard next to it; what a button does is shown on a HelpCard beside it
## while the pointer is on the button (or it is held down).

const W: float = 116.0 ## width of the rail
const PAD: float = 8.0
const INNER: float = W - 2 * PAD
const DEPTH: int = 100
const TOWERS_Y: float = 80.0
const TILE_W: float = (INNER - 4) / 2
const TILE_H: float = 50.0
const TILE_GAP: float = 4.0
const MENU_W: float = 168.0

## Build buttons of the towers the player owns (locked ones live in the tech tree).
var tower_buttons: Dictionary[String, GameButton] = {}
## The "?" slot after them while some towers are still locked (null when all are owned).
var teaser_button: GameButton = null
var wave_button: GameButton
var pause_button: GameButton
var speed_button: GameButton
var menu_button: GameButton
## In the gear menu.
var music_button: GameButton
var sfx_button: GameButton
var quit_button: GameButton
var auto_button: GameButton
## Opens the list of the field orders taken in this game (shown once there is one).
var orders_button: GameButton
## Where the help appears.
var help: HelpCard
## The card next to the selected tower or wall (made by the game screen).
var card: TowerCard
## The rail's free space for the wall and ability buttons (see AbilityBar) starts here.
var tools_y: float = 0.0

## The selected tower's buttons, on its card.
var upgrade_button: GameButton:
	get:
		return card.upgrade_button
var branch_buttons: Array[GameButton]:
	get:
		return card.branch_buttons
var target_button: GameButton:
	get:
		return card.target_button
var sell_button: GameButton:
	get:
		return card.sell_button

var _host: GameScene
var _money: TextLabel
var _lives: TextLabel
var _wave: TextLabel
var _preview_label: TextLabel
var _preview: Control
var _preview_key: String = "-"
## The next wave's enemy types, each a button that tells about it (hover, or tap).
var preview_buttons: Dictionary[String, GameButton] = {}
var _hovered_enemy: String = ""
var _pinned_enemy: String = "" ## tapped: shown until tapped again or the wave starts
var _preview_y: float = 0.0
var _hovered: String = ""
var _hovered_ability: String = ""
var _hovered_branch: int = -1
var _menu: Control
var _menu_tween: Tween
var _orders: Control
var _orders_text: TextLabel
var _orders_key: String = "-"


func _init(host: GameScene) -> void:
	_host = host
	size = Vector2(W, Config.HEIGHT)
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_money = Ui.text(self, PAD + 4, 8, "", 19, Palette.GOLD, true)
	_lives = Ui.text(self, PAD + 4, 33, "", 16, Palette.RED, true)
	_wave = Ui.text(self, PAD + 4, 55, "", 13, Palette.TEXT, true)

	# Two columns of build buttons: the towers the player owns, then a "?".
	var kinds: Array[String] = _host.buildable_kinds()
	for i: int in kinds.size():
		var kind: String = kinds[i]
		var b := GameButton.new(_cell(i), "", func() -> void: _host.select_tool("" if _host.tool == kind else kind))
		b.tile().font(12).key(str(i + 1)).icon(func(ci: CanvasItem, center: Vector2, s: float) -> void:
			TowerArt.draw_icon(ci, kind, center, s))
		b.hover_callback(func(on: bool) -> void: show_tower_help(kind, on))
		add_child(b)
		tower_buttons[kind] = b
	var slots: int = kinds.size()
	if kinds.size() < Towers.KINDS.size():
		teaser_button = GameButton.new(_cell(kinds.size()), "?", func() -> void: Audio.play("error")).font(20)
		teaser_button.hover_callback(func(on: bool) -> void: show_tower_help("?", on))
		add_child(teaser_button)
		slots += 1
	@warning_ignore("integer_division")
	var rows: int = (slots + 1) / 2
	tools_y = TOWERS_Y + rows * (TILE_H + TILE_GAP) + 4

	_preview_label = Ui.text(self, PAD + 2, 0, "Next", 11, Palette.TEXT_DIM, true)
	_preview = Control.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)

	wave_button = GameButton.new(Rect2(PAD, 0, INNER, 54), "Start wave", _host.start_wave).primary().font(13).sublabel("")
	add_child(wave_button)
	var q: float = (INNER - 2 * 5) / 3
	pause_button = _small(0, q, "II", _host.toggle_pause)
	speed_button = _small(1, q, "1x", _host.toggle_speed)
	menu_button = _small(2, q, "", toggle_menu, Icons.gear)
	_build_menu()
	_build_orders()


## Where the build button in slot `i` (two per row) goes.
func _cell(i: int) -> Rect2:
	@warning_ignore("integer_division")
	var row: int = i / 2
	return Rect2(PAD + (i % 2) * (TILE_W + 4), TOWERS_Y + row * (TILE_H + TILE_GAP), TILE_W, TILE_H)


func _small(i: int, q: float, label: String, on_click: Callable, icon: Callable = Callable()) -> GameButton:
	var b := GameButton.new(Rect2(PAD + i * (q + 5), 0, q, 32), label, on_click).font(13)
	if icon.is_valid():
		b.icon_only(icon)
	add_child(b)
	return b


## The gear menu: music, sound and the pause menu, opening upwards to the left.
func _build_menu() -> void:
	var h: float = 4 * 40 + 12
	_menu = PainterView.new(func(g: CanvasItem, _center: Vector2, _s: float) -> void:
		Paint.fill_rounded_rect(g, 3, 4, MENU_W, h, 10, Color(0, 0, 0, 0.3))
		Paint.fill_rounded_rect(g, 0, 0, MENU_W, h, 10, Color(Palette.PANEL, 0.98))
		Paint.stroke_rounded_rect(g, 0, 0, MENU_W, h, 10, 1, Palette.BORDER))
	_menu.size = Vector2(MENU_W, h)
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.visible = false
	add_child(_menu)
	music_button = GameButton.new(Rect2(8, 8, MENU_W - 16, 34), "", _host.toggle_music).font(13)
	_menu.add_child(music_button)
	sfx_button = GameButton.new(Rect2(8, 48, MENU_W - 16, 34), "", _host.toggle_sfx).font(13)
	_menu.add_child(sfx_button)
	auto_button = GameButton.new(Rect2(8, 88, MENU_W - 16, 34), "", _host.toggle_auto_waves).font(13)
	_menu.add_child(auto_button)
	quit_button = GameButton.new(Rect2(8, 128, MENU_W - 16, 34), "Pause menu", func() -> void:
		close_menu()
		_host.toggle_pause()).font(13)
	_menu.add_child(quit_button)


## The field orders: a button on the rail and the list it drops down, to its left.
func _build_orders() -> void:
	orders_button = GameButton.new(Rect2(PAD, 0, INNER, 26), "", toggle_orders).flat().font(12)
	orders_button.visible = false
	add_child(orders_button)
	var chevron := PainterView.new(func(ci: CanvasItem, center: Vector2, sz: float) -> void:
		Icons.chevron(ci, center, sz, _orders.visible, Palette.GOLD))
	chevron.position = Vector2(INNER - 20, 4)
	chevron.size = Vector2(18, 18)
	orders_button.add_child(chevron)
	_orders = PainterView.new(func(g: CanvasItem, _center: Vector2, _s: float) -> void:
		var sz: Vector2 = _orders.size
		Paint.fill_rounded_rect(g, 3, 4, sz.x, sz.y, 10, Color(0, 0, 0, 0.3))
		Paint.fill_rounded_rect(g, 0, 0, sz.x, sz.y, 10, Color(Palette.PANEL, 0.98))
		Paint.stroke_rounded_rect(g, 0, 0, sz.x, sz.y, 10, 1, Color(Palette.GOLD, 0.6)))
	_orders.size = Vector2(230, 60)
	_orders.visible = false
	add_child(_orders)
	_orders_text = Ui.text(_orders, 14, 10, "", 12, Palette.TEXT).set_wrap(230 - 28)
	_orders_text.set_line_spacing(3)


func toggle_orders() -> void:
	_orders.visible = not _orders.visible
	orders_button.set_selected(_orders.visible)
	orders_button.queue_redraw()
	for child: Node in orders_button.get_children():
		(child as CanvasItem).queue_redraw()


## The field orders taken, and the button that shows them (once there is one).
func _refresh_orders() -> void:
	var perks: Array[String] = _host.world.run_perks
	var key: String = ",".join(perks)
	if key == _orders_key:
		return
	_orders_key = key
	orders_button.visible = not perks.is_empty()
	orders_button.set_label("★ %d order%s" % [perks.size(), "" if perks.size() == 1 else "s"], Palette.GOLD)
	var lines: PackedStringArray = []
	for id: String in perks:
		var def: RunPerks.RunPerkDef = RunPerks.get_def(id)
		lines.append("%s\n%s" % [def.name, def.description])
	_orders_text.show_text("\n\n".join(lines))
	_orders.size.y = _orders_text.size.y + 20
	_orders.position = Vector2(-_orders.size.x - 6, orders_button.position.y + orders_button.size.y - _orders.size.y)
	_orders.queue_redraw()


## Places the rail at the right edge of a `screen`-sized view, full height.
func layout(screen: Vector2) -> void:
	position = Vector2(screen.x - W, 0)
	size = Vector2(W, screen.y)
	var y: float = screen.y - PAD - 32
	for b: GameButton in [pause_button, speed_button, menu_button]:
		b.position.y = y
	wave_button.position.y = y - 8 - wave_button.size.y
	_preview_y = wave_button.position.y - 46
	_preview_label.move_to(PAD + 2, _preview_y)
	orders_button.position.y = _preview_y - 32
	_orders_key = "-" # place the list again
	_preview_key = "-" # draw the icons again at the new place
	_menu.position = Vector2(W - PAD - MENU_W, y - 8 - _menu.size.y)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.PANEL, 0.97))
	draw_rect(Rect2(0, 0, 2, size.y), Palette.BORDER)
	draw_rect(Rect2(PAD, TOWERS_Y - 6, INNER, 1), Color(Palette.BORDER, 0.6))


## Whether a point (in the game screen's coordinates) is on the rail or one of its pop-ups.
func covers(p: Vector2) -> bool:
	if get_rect().has_point(p):
		return true
	if _orders.visible and Rect2(position + _orders.position, _orders.size).has_point(p):
		return true
	return _menu.visible and Rect2(position + _menu.position, _menu.size).has_point(p)


func toggle_menu() -> void:
	if _menu.visible:
		close_menu()
		return
	_menu.visible = true
	_menu.modulate.a = 0.0
	_menu.pivot_offset = Vector2(MENU_W, _menu.size.y)
	_menu.scale = Vector2.ONE * 0.92
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_tween = _menu.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_menu_tween.tween_property(_menu, "modulate:a", 1.0, 0.14)
	_menu_tween.tween_property(_menu, "scale", Vector2.ONE, 0.14)
	menu_button.set_selected(true)


func close_menu() -> void:
	if _menu_tween != null:
		_menu_tween.kill()
	_menu.visible = false
	menu_button.set_selected(false)


func is_menu_open() -> bool:
	return _menu.visible


## A tap anywhere but on the tapped enemy of the preview puts its help away.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if _pinned_enemy.is_empty() or mb == null or not mb.pressed:
		return
	var b: GameButton = preview_buttons.get(_pinned_enemy)
	if b == null or not b.get_global_rect().has_point(mb.position):
		_pinned_enemy = ""


## Shows an ability's help while the pointer is over its button ("" to stop).
func show_ability_help(id: String) -> void:
	_hovered_ability = id


## Shows a tower's help while the pointer is over a button for it (here or in the build menu).
func show_tower_help(kind: String, on: bool) -> void:
	if on:
		_hovered = kind
	elif _hovered == kind:
		_hovered = ""


## Shows a branch's help while the pointer is over its button on the tower card.
func show_branch_help(index: int, on: bool) -> void:
	if on:
		_hovered_branch = index
	elif _hovered_branch == index:
		_hovered_branch = -1


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

	_refresh_preview() # first: the help may be about one of its enemies
	_refresh_help()
	_refresh_orders()

	if world.status != World.Status.PLAYING:
		wave_button.set_label("Game over").set_sublabel("").set_enabled(false)
	elif world.next_wave() == null:
		wave_button.set_label("Final wave").set_sublabel("%d left" % world.enemies_remaining()).set_enabled(false)
	elif world.is_spawning():
		wave_button.set_label("Wave %d" % (world.wave_index + 1)) \
			.set_sublabel("%d left" % world.enemies_remaining()).set_enabled(false)
	elif world.early_bonus_now() > 0:
		wave_button.set_label("Call wave %d" % (world.wave_index + 2)) \
			.set_sublabel("+$%d early" % world.early_bonus_now(), Palette.GOLD).set_enabled(true)
	elif _host.auto_wave_seconds() >= 0:
		wave_button.set_label("Start wave %d" % (world.wave_index + 2)) \
			.set_sublabel("auto in %d s" % _host.auto_wave_seconds(), Palette.GOLD).set_enabled(true)
	else:
		wave_button.set_label("Start wave %d" % (world.wave_index + 2)) \
			.set_sublabel("build first!" if world.wave_index < 0 else "Space").set_enabled(true)
	pause_button.set_label("▶" if _host.paused else "II")
	speed_button.set_label("%dx" % _host.speed).set_selected(_host.speed > 1)
	music_button.set_label("♪  Music %s" % ("on" if _host.music_on() else "off"),
		Palette.TEXT if _host.music_on() else Palette.TEXT_DIM).set_selected(_host.music_on())
	auto_button.set_label("Auto waves %s" % ("on" if _host.auto_waves_on() else "off"),
		Palette.TEXT if _host.auto_waves_on() else Palette.TEXT_DIM).set_selected(_host.auto_waves_on())
	sfx_button.set_label("Sound %s" % ("on" if _host.sfx_on() else "off"),
		Palette.TEXT if _host.sfx_on() else Palette.TEXT_DIM).set_selected(_host.sfx_on())


## The help card: about the hovered branch, ability or tower, beside its button.
func _refresh_help() -> void:
	var world: World = _host.world
	var selected: Tower = _host.selected
	if selected == null or not selected.needs_branch():
		_hovered_branch = -1
	var bounds := Rect2(Vector2.ZERO, Screen.size(self))

	if _hovered_branch >= 0:
		var br: TowerBranch = selected.def.branches[_hovered_branch]
		help.show_help("%s  ·  $%d" % [br.name, world.branch_cost_of(selected, br.id)], br.description,
			Format.tower_stats_text(selected.kind, Towers.BRANCH_LEVEL, -1, 0, br.id) +
			("" if world.is_branch_unlocked(br.id) else "\n\nUnlock it in the tech tree."),
			card.get_global_rect(), bounds) # beside the tower's card
		return

	var ability: String = _hovered_ability
	if ability.is_empty() and _hovered.is_empty() and _host.tool.is_empty():
		ability = _host.aim
	if not ability.is_empty():
		var def: Abilities.AbilityDef = Abilities.get_def(ability)
		var button: GameButton = _host.ability_bar.buttons.get(ability)
		var anchor: Rect2 = button.get_global_rect() if button != null and button.is_visible_in_tree() else get_global_rect()
		help.show_help("%s  ·  $%d" % [def.name, world.ability_cost(ability)], _ability_text(def), "", anchor, bounds)
		return

	var enemy: String = _hovered_enemy if not _hovered_enemy.is_empty() else _pinned_enemy
	if preview_buttons.has(enemy) and _hovered.is_empty():
		var wave: Wave = world.next_wave()
		var count: int = 0
		for g: SpawnGroup in wave.groups:
			if g.type == enemy:
				count += g.count
		var def: EnemyDef = Enemies.get_def(enemy)
		help.show_help("%s  ·  ×%d" % [def.name, count], Format.enemy_text(def, world.hp_multiplier_at(world.wave_index + 1)),
			"", preview_buttons[enemy].get_global_rect(), bounds)
		return

	if _hovered == "?" and teaser_button != null:
		help.show_help("More towers", "Spend your stars in the tech tree (main menu) to unlock more towers and their branches.",
			"", teaser_button.get_global_rect(), bounds)
		return
	if not _hovered.is_empty():
		var d: TowerDef = Towers.get_def(_hovered)
		var hits: PackedStringArray = []
		if d.hits_ground:
			hits.append("ground")
		if d.hits_air:
			hits.append("air")
		var from_menu: GameButton = _host.build_menu.buttons.get(_hovered) if _host.build_menu.is_open() else null
		var anchor: Control = from_menu if from_menu != null else tower_buttons.get(_hovered)
		help.show_help("%s  ·  $%d" % [d.name, world.cost_of(_hovered)], "\n".join(PackedStringArray([
			Format.tower_stats_text(_hovered, 0),
			"Hits: %s" % (" + ".join(hits) if not hits.is_empty() else "—"),
			"",
			d.description,
		])), "", anchor.get_global_rect() if anchor != null else get_global_rect(), bounds)
		return
	help.hide_help()


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


## Small icons showing what the next wave brings (two rows at most).
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
	preview_buttons = {}
	_hovered_enemy = ""
	_pinned_enemy = ""
	_preview_label.show_text("Next" if wave != null else "")
	var x: float = PAD + 2
	var y: float = _preview_y + 16
	for type: String in types:
		var def: EnemyDef = Enemies.get_def(type)
		var label: String = "%d" % counts[type]
		var w: float = 18 + 7 * label.length() + 6
		if x + w > W - PAD:
			x = PAD + 2
			y += 20
			if y > _preview_y + 40:
				break
		var icon := PainterView.new(func(ci: CanvasItem, center: Vector2, s: float) -> void:
			EnemyArt.draw(ci, def.art, center, s))
		icon.position = Vector2(x, y)
		icon.size = Vector2(16, 16)
		if def.has_tint:
			icon.modulate = def.tint
		_preview.add_child(icon)
		Ui.text(_preview, x + 17, y + 1, label, 11, Palette.TEXT, true)
		var b := GameButton.new(Rect2(x - 2, y - 2, w - 2, 20), "", func() -> void:
			_pinned_enemy = "" if _pinned_enemy == type else type).flat()
		b.hover_callback(func(on: bool) -> void:
			if on:
				_hovered_enemy = type
			elif _hovered_enemy == type:
				_hovered_enemy = "")
		_preview.add_child(b)
		preview_buttons[type] = b
		x += w


# ---- what the player sees (read by the scene tests) ---------------------------

func money_text() -> String:
	return _money.text


func lives_text() -> String:
	return _lives.text


func wave_text() -> String:
	return _wave.text


## The title of what the player is reading about: the help card beside a
## hovered button, else the selected tower's (or wall's) card; "" when neither shows.
func panel_title_text() -> String:
	if help.visible:
		return help.title_text()
	return card.title_text()


func panel_body_text() -> String:
	if help.visible:
		return help.body_text()
	return card.body_text()


## The help card's second text block (a branch's stats while its button is hovered).
func panel_extra_text() -> String:
	return help.extra_text()


## The field orders listed in their drop-down ("" while it is closed).
func orders_text() -> String:
	return _orders_text.text if _orders.visible else ""


## The next-wave preview as "type count" pairs, e.g. "scout8,racer5".
func preview_key() -> String:
	return _preview_key
