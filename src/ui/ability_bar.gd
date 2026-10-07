class_name AbilityBar
extends Control
## The row of buttons along the bottom of the field: the wall tool and the
## abilities, each with its price (or the seconds until it can be used again)
## and its hotkey. Only the buttons take clicks; the tiles between them still do.

const BUTTON_W: float = 84.0
const BUTTON_H: float = 36.0
const GAP: float = 4.0
const DEPTH: int = 100

## The buttons by ability id.
var buttons: Dictionary[String, GameButton] = {}

var _host: GameScene


func _init(host: GameScene) -> void:
	_host = host
	var ids: Array[String] = Abilities.enabled_ids()
	var width: float = ids.size() * BUTTON_W + maxi(0, ids.size() - 1) * GAP
	position = Vector2((Config.FIELD_W - width) / 2.0, Config.FIELD_H - BUTTON_H - 3)
	size = Vector2(width, BUTTON_H)
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var x: float = 0.0
	for id: String in Abilities.enabled_ids():
		var def: Abilities.AbilityDef = Abilities.get_def(id)
		var b := GameButton.new(Rect2(x, 0, BUTTON_W, BUTTON_H), "", func() -> void: _host.press_ability(id))
		b.font(13).key(def.key_label()).icon(func(ci: CanvasItem, center: Vector2, s: float) -> void:
			AbilityArt.draw_icon(ci, id, center, s))
		b.hover_callback(func(on: bool) -> void: _host.hud.show_ability_help(id if on else ""))
		add_child(b)
		buttons[id] = b
		x += BUTTON_W + GAP


## Called every frame.
func refresh() -> void:
	var world: World = _host.world
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
		b.set_label(label, color).set_enabled(enabled and world.status == World.Status.PLAYING) \
			.set_selected(active or _host.aim == id)
