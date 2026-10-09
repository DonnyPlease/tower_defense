class_name BuildMenu
extends Control
## Tap-to-build: a click (or tap) on an empty tile with nothing picked opens
## this small menu next to the tile, listing only what can be built there:
## the towers the player owns (and a wall where one may go). Choosing one
## builds it at once; a click anywhere else closes the menu.

const DEPTH: int = 150
const BUTTON_W: float = 96
const BUTTON_H: float = 36
const GAP: float = 4
const PAD: float = 6

## The menu's buttons by tower kind (and "wall"), while it is open (tests).
var buttons: Dictionary[String, GameButton] = {}
## The tile the menu builds on (GameMap.NO_TILE when closed).
var tile: Vector2i = GameMap.NO_TILE
## The tower whose choice is under the pointer, its reach shown on the tile ("" when none).
var previewing: String = ""

var _host: GameScene
var _size: Vector2 = Vector2.ZERO


func _init(host: GameScene) -> void:
	_host = host
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_open() -> bool:
	return visible


## Opens the menu for a tile; false (and nothing shown) when nothing can be built there.
func open(col: int, row: int) -> bool:
	close()
	var world: World = _host.world
	var options: Array[String] = []
	if world.build_block_reason(col, row) == World.BlockReason.NONE:
		options.assign(_host.buildable_kinds())
	if Abilities.ENABLED.get("wall", false) and world.wall_block_reason(col, row) == World.BlockReason.NONE:
		options.append("wall")
	if options.is_empty():
		return false
	tile = Vector2i(col, row)
	@warning_ignore("integer_division")
	var rows: int = (options.size() + 1) / 2
	var cols: int = mini(2, options.size())
	_size = Vector2(PAD * 2 + cols * BUTTON_W + (cols - 1) * GAP, PAD * 2 + rows * BUTTON_H + (rows - 1) * GAP)
	size = _size
	# Beside the tile, on the side with room, inside the field.
	var center: Vector2 = GameMap.tile_center(tile)
	var shown: Vector2 = _size * scale # bigger on phones (the game screen sets the scale)
	var x: float = center.x + Config.TILE * 0.7
	if x + shown.x > Config.FIELD_W:
		x = center.x - Config.TILE * 0.7 - shown.x
	var y: float = clampf(center.y - shown.y / 2, 4, Config.FIELD_H - shown.y - 4)
	position = Vector2(maxf(4, x), y)
	for i: int in options.size():
		var id: String = options[i]
		@warning_ignore("integer_division")
		var r := Rect2(PAD + (i % 2) * (BUTTON_W + GAP), PAD + (i / 2) * (BUTTON_H + GAP), BUTTON_W, BUTTON_H)
		var b := GameButton.new(r, "", func() -> void: _choose(id)).font(13)
		if id == "wall":
			b.icon(func(ci: CanvasItem, c: Vector2, s: float) -> void: AbilityArt.draw_icon(ci, "wall", c, s))
		else:
			b.icon(func(ci: CanvasItem, c: Vector2, s: float) -> void: TowerArt.draw_icon(ci, id, c, s))
			b.hover_callback(func(on: bool) -> void:
				_host.hud.show_tower_help(id, on)
				if on:
					previewing = id
				elif previewing == id:
					previewing = "")
		add_child(b)
		buttons[id] = b
	visible = true
	queue_redraw()
	refresh()
	return true


func close() -> void:
	for b: GameButton in buttons.values():
		b.queue_free()
	buttons = {}
	tile = GameMap.NO_TILE
	previewing = ""
	visible = false


## Prices (in red when there isn't enough money), every frame while open.
func refresh() -> void:
	if not visible:
		return
	var world: World = _host.world
	for id: String in buttons:
		var cost: int = world.wall_cost() if id == "wall" else world.build_cost(id, tile.x, tile.y)
		var ok: bool = world.money >= cost
		buttons[id].set_label("$%d" % cost, Palette.TEXT if ok else Palette.RED).set_enabled(ok and world.status == World.Status.PLAYING)


func _choose(id: String) -> void:
	var at: Vector2i = tile
	close()
	_host.build_here(id, at)


func _draw() -> void:
	Paint.fill_rounded_rect(self, 0, 3, _size.x, _size.y, 10, Color(0, 0, 0, 0.35))
	Paint.fill_rounded_rect(self, 0, 0, _size.x, _size.y, 10, Color(Palette.PANEL, 0.96))
	Paint.stroke_rounded_rect(self, 0, 0, _size.x, _size.y, 10, 1, Palette.BORDER)
