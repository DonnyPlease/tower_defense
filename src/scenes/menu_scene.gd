class_name MenuScene
extends Node2D
## Title screen with a live, self-playing game in the background.

## Where the attract-mode demo places its towers.
const DEMO_TOWERS: Array[Array] = [
	["gun", 13, 7], ["missile", 9, 11], ["cannon", 6, 9], ["laser", 14, 5],
	["frost", 9, 7], ["missile", 17, 4], ["gun", 3, 13], ["support", 14, 8],
]
const DEMO_ENEMIES: Array[String] = ["scout", "racer", "tank", "shielded", "drone", "healer", "splitter", "armored"]
## "Unlimited" money and lives for the demo.
const PLENTY: int = 1 << 40

var world: World
var field: FieldView
var buttons: Dictionary[String, GameButton] = {}
var _clock := FixedStep.new()
var _profile: Profile


func _ready() -> void:
	world = World.new(Levels.LEVELS[0])
	world.money = PLENTY
	world.lives = PLENTY
	for t: Array in DEMO_TOWERS:
		var col: int = t[1]
		var row: int = t[2]
		var tower: Tower = world.build(str(t[0]), col, row)
		if tower != null:
			tower.level = (col + row) % 3
	field = FieldView.new(world)
	field.quiet = true
	add_child(field)

	var dim := ColorRect.new()
	dim.color = Color(Palette.BACKGROUND, 0.55)
	dim.size = Vector2(Config.WIDTH, Config.HEIGHT)
	dim.z_index = 100
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_profile = Profile.load_profile()
	var save: WorldSnapshot = _profile.save
	var panel_w: float = 420
	var panel_h: float = 420 if save != null else 360
	var px: float = (Config.WIDTH - panel_w) / 2
	var py: float = (Config.HEIGHT - panel_h) / 2
	var panel := DrawNode.new(func(g: CanvasItem) -> void:
		Paint.fill_rounded_rect(g, px, py, panel_w, panel_h, 16, Color(Palette.PANEL, 0.94))
		Paint.stroke_rounded_rect(g, px, py, panel_w, panel_h, 16, 1, Palette.BORDER), 101)
	add_child(panel)
	var ui := Control.new()
	ui.z_index = 102
	ui.size = Vector2(Config.WIDTH, Config.HEIGHT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	Ui.text(ui, Config.WIDTH / 2.0, py + 48, "TOWER DEFENSE", 40, Palette.GOLD, true, Vector2(0.5, 0.5)).set_outline(4)
	Ui.text(ui, Config.WIDTH / 2.0, py + 88, "★ %d stars earned" % _profile.total_stars(), 16, Palette.TEXT_DIM, false,
		Vector2(0.5, 0.5))

	var y: float = py + 118
	if save != null:
		var name: String = "Endless" if save.endless else Levels.by_id(save.level_id).name
		buttons["continue"] = _button(ui, y, "Continue", _continue, true).sublabel("%s · wave %d" % [name, save.wave_index + 2])
		y += 60
	buttons["play"] = _button(ui, y, "Play", Router.goto_levels, save == null)
	y += 60
	buttons["upgrades"] = _button(ui, y, "Upgrades", Router.goto_upgrades, false)
	y += 60

	buttons["music"] = GameButton.new(Rect2(Config.WIDTH / 2.0 - 130, y + 6, 125, 40), "", _toggle_music).font(14)
	ui.add_child(buttons["music"])
	buttons["sfx"] = GameButton.new(Rect2(Config.WIDTH / 2.0 + 5, y + 6, 125, 40), "", _toggle_sfx).font(14)
	ui.add_child(buttons["sfx"])
	_refresh_sound_buttons()

	Ui.text(ui, Config.WIDTH / 2.0, py + panel_h - 22, "1-6 build  ·  U upgrade  ·  S sell  ·  T target  ·  Space wave  ·  F speed",
		12, Palette.TEXT_DIM, false, Vector2(0.5, 0.5))


func _button(parent: Control, y: float, label: String, on_click: Callable, primary: bool) -> GameButton:
	var b := GameButton.new(Rect2(Config.WIDTH / 2.0 - 130, y, 260, 50), label, on_click).font(19)
	if primary:
		b.primary()
	parent.add_child(b)
	return b


func _continue() -> void:
	Router.goto_game(_profile.save.level_id, true)


func _toggle_music() -> void:
	_profile.music = not _profile.music
	Audio.set_music(_profile.music)
	Profile.save_profile(_profile)
	_refresh_sound_buttons()


func _toggle_sfx() -> void:
	_profile.sfx = not _profile.sfx
	Audio.set_sfx(_profile.sfx)
	Profile.save_profile(_profile)
	_refresh_sound_buttons()


func _refresh_sound_buttons() -> void:
	buttons["music"].set_label("♪ Music %s" % ("on" if _profile.music else "off"),
		Palette.TEXT if _profile.music else Palette.TEXT_DIM).set_selected(_profile.music)
	buttons["sfx"].set_label("Sound %s" % ("on" if _profile.sfx else "off"),
		Palette.TEXT if _profile.sfx else Palette.TEXT_DIM).set_selected(_profile.sfx)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		get_viewport().set_input_as_handled()
		if _profile.save != null:
			_continue()
		else:
			Router.goto_levels()


func _process(delta: float) -> void:
	var alpha: float = _clock.advance(delta * 1000.0, 1, _demo_tick)
	field.handle_events(world.events)
	field.sync(alpha)


func _demo_tick() -> void:
	if world.tick % MathX.js_round(Config.TICK_RATE * 0.9) == 0 and world.enemies.size() < 14:
		world.spawn(DEMO_ENEMIES[randi() % DEMO_ENEMIES.size()])
	world.update()
