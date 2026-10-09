class_name AbilityBar
extends Control
## The wall tool and the abilities, on the rail under the towers: the Wall
## button, and an "Abilities" button that drops down the others beside the
## rail. Each shows its price (or the seconds until it can be used again) and
## its hotkey; the hotkeys work whether the drop-down is open or not.

const W: float = Hud.INNER
const BUTTON_H: float = 34.0
const CELL_W: float = 100.0
const CELL_H: float = 38.0
const GAP: float = 6.0
const DEPTH: int = 100

## The buttons by ability id (the wall's is on the rail, the others in the drop-down).
var buttons: Dictionary[String, GameButton] = {}
## Opens and closes the drop-down.
var toggle_button: GameButton

var _host: GameScene
var _drawer: Control
var _tween: Tween


func _init(host: GameScene) -> void:
	_host = host
	size = Vector2(W, BUTTON_H * 2 + GAP)
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var ids: Array[String] = Abilities.enabled_ids()
	var others: Array[String] = ids.filter(func(id: String) -> bool: return id != "wall")
	var y: float = 0.0
	if ids.has("wall"):
		buttons["wall"] = _button("wall", Rect2(0, 0, W, BUTTON_H))
		add_child(buttons["wall"])
		y += BUTTON_H + GAP
	toggle_button = GameButton.new(Rect2(0, y, W, BUTTON_H), "Abilities", toggle).font(12)
	var chevron := PainterView.new(func(ci: CanvasItem, center: Vector2, s: float) -> void:
		Icons.chevron(ci, center, s, is_open()))
	chevron.position = Vector2(W - 22, (BUTTON_H - 18) / 2)
	chevron.size = Vector2(18, 18)
	toggle_button.add_child(chevron)
	toggle_button.visible = not others.is_empty()
	add_child(toggle_button)

	# The drop-down: two columns beside the rail, its bottom level with the button.
	@warning_ignore("integer_division")
	var rows: int = (others.size() + 1) / 2
	var dw: float = 2 * CELL_W + 3 * GAP
	var dh: float = rows * CELL_H + (rows + 1) * GAP
	_drawer = PainterView.new(func(g: CanvasItem, _center: Vector2, _s: float) -> void:
		Paint.fill_rounded_rect(g, 3, 4, dw, dh, 10, Color(0, 0, 0, 0.3))
		Paint.fill_rounded_rect(g, 0, 0, dw, dh, 10, Color(Palette.PANEL, 0.98))
		Paint.stroke_rounded_rect(g, 0, 0, dw, dh, 10, 1, Palette.BORDER))
	_drawer.size = Vector2(dw, dh)
	_drawer.position = Vector2(-Hud.PAD - dw - 6, y + BUTTON_H - dh)
	_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer.visible = false
	add_child(_drawer)
	for i: int in others.size():
		var id: String = others[i]
		@warning_ignore("integer_division")
		var r := Rect2(GAP + (i % 2) * (CELL_W + GAP), GAP + (i / 2) * (CELL_H + GAP), CELL_W, CELL_H)
		buttons[id] = _button(id, r)
		_drawer.add_child(buttons[id])


func _button(id: String, r: Rect2) -> GameButton:
	var def: Abilities.AbilityDef = Abilities.get_def(id)
	var b := GameButton.new(r, "", func() -> void:
		_host.press_ability(id)
		if id != "wall":
			close() # one ability per opening: the map is free to aim at
		).font(13).key(def.key_label()).icon(func(ci: CanvasItem, center: Vector2, s: float) -> void:
			AbilityArt.draw_icon(ci, id, center, s))
	b.hover_callback(func(on: bool) -> void: _host.hud.show_ability_help(id if on else ""))
	return b


func is_open() -> bool:
	return _drawer.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if is_open():
		return
	_drawer.visible = true
	_drawer.modulate.a = 0.0
	_drawer.pivot_offset = Vector2(_drawer.size.x, _drawer.size.y)
	_drawer.scale = Vector2.ONE * 0.92
	if _tween != null:
		_tween.kill()
	_tween = _drawer.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_drawer, "modulate:a", 1.0, 0.14)
	_tween.tween_property(_drawer, "scale", Vector2.ONE, 0.14)
	_redraw_toggle()


func close() -> void:
	if _tween != null:
		_tween.kill()
	_drawer.visible = false
	_redraw_toggle()


func _redraw_toggle() -> void:
	for child: Node in toggle_button.get_children():
		(child as CanvasItem).queue_redraw()


## Whether a point (in the game screen's coordinates) is on the open drop-down.
func covers(p: Vector2) -> bool:
	return is_open() and _drawer.get_global_rect().has_point(p)


## Called every frame.
func refresh() -> void:
	var world: World = _host.world
	var busy: int = 0 ## abilities running or picked (shown on the toggle)
	for id: String in buttons:
		var b: GameButton = buttons[id]
		var label: String = "$%d" % world.ability_cost(id)
		var color: Color = Palette.TEXT
		var enabled: bool = true
		var active: bool = world.is_active(id)
		if active:
			label = "%d s" % ceili(world.effect_left(id) / float(Config.TICK_RATE))
		elif world.is_used(id):
			label = "Used"
			color = Palette.TEXT_DIM
			enabled = false
		elif world.cooldown_left(id) > 0:
			label = "%d s" % ceili(world.cooldown_left(id) / float(Config.TICK_RATE))
			color = Palette.TEXT_DIM
			enabled = false
		elif world.ability_block(id) == World.AbilityBlock.LIMIT:
			label = "Max"
			color = Palette.TEXT_DIM
		elif world.money < world.ability_cost(id):
			color = Palette.RED
		var picked: bool = active or _host.aim == id
		if picked and id != "wall":
			busy += 1
		b.set_label(label, color).set_enabled(enabled and world.status == World.Status.PLAYING).set_selected(picked)
	toggle_button.set_label("Abilities" if busy == 0 else "Abilities  ·  %d" % busy, Palette.TEXT if busy == 0 else Palette.GOLD)
	toggle_button.set_selected(is_open() or busy > 0)
