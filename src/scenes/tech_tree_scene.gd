class_name TechTreeScene
extends Node2D
## The tech tree: spend stars on towers, their branches, perks, starting
## bonuses and challenges. Hover (or hold) a node to read it; click it to buy it.

const NODE_W: float = 124
const NODE_H: float = 46
const GAP_X: float = 10
const LEFT_X: float = 20 ## column 0 (towers)
const RIGHT_X: float = 432 ## column 3 (perks)
const TOP_Y: float = 104
const ROW_H: float = 55
const STATE_LABEL_COLOR: Dictionary[Profile.TechState, Color] = {
	Profile.TechState.OWNED: Palette.GREEN,
	Profile.TechState.AVAILABLE: Palette.GOLD,
	Profile.TechState.NEEDS_STARS: Palette.RED,
	Profile.TechState.NEEDS_EARNED: Palette.TEXT_DIM,
	Profile.TechState.NEEDS_PARENTS: Palette.TEXT_DIM,
}

## The button of each node, by node id (tests).
var node_buttons: Dictionary[String, GameButton] = {}
var refund_button: GameButton
var back_button: GameButton
var levels_button: GameButton

var _profile: Profile
var _stars: TextLabel
var _info_title: TextLabel
var _info_body: TextLabel
var _hovered: String = ""
var _links: DrawNode


static func node_rect(n: Tech.TechNode) -> Rect2:
	var x: float = LEFT_X + n.col * (NODE_W + GAP_X) if n.col < 3 else RIGHT_X + (n.col - 3) * (NODE_W + GAP_X)
	return Rect2(x, TOP_Y + n.row * ROW_H, NODE_W, NODE_H)


func _ready() -> void:
	_profile = Profile.load_profile()
	var ui: Control = Screen.centered_page(self)
	_links = DrawNode.new(_draw_links)
	ui.add_child(_links)
	Ui.text(ui, Config.WIDTH / 2.0, 34, "Tech tree", 30, Palette.TEXT, true, Vector2(0.5, 0.5))
	_stars = Ui.text(ui, Config.WIDTH / 2.0, 64, "", 15, Palette.GOLD, false, Vector2(0.5, 0.5))
	back_button = GameButton.new(Rect2(20, 16, 100, 40), "‹ Back", Router.goto_menu)
	ui.add_child(back_button)
	levels_button = GameButton.new(Rect2(Config.WIDTH - 140, 16, 120, 40), "Levels", Router.goto_levels)
	ui.add_child(levels_button)
	Ui.text(ui, LEFT_X, 84, "Towers and their branches", 12, Palette.TEXT_DIM, true)
	Ui.text(ui, RIGHT_X, 84, "Perks and starting bonuses", 12, Palette.TEXT_DIM, true)

	for n: Tech.TechNode in Tech.NODES:
		var r: Rect2 = node_rect(n)
		var id: String = n.id
		var b := GameButton.new(r, n.name, func() -> void: _buy(id)).font(12).sublabel("")
		if n.kind == Tech.Kind.TOWER or n.kind == Tech.Kind.BRANCH:
			var kind: String = n.id if n.kind == Tech.Kind.TOWER else Towers.get_branch(n.id).kind
			var branch: String = n.id if n.kind == Tech.Kind.BRANCH else ""
			b.icon(func(ci: CanvasItem, center: Vector2, s: float) -> void: TowerArt.draw_icon(ci, kind, center, s, branch))
		b.hover_callback(func(on: bool) -> void:
			if on:
				_hovered = id
			elif _hovered == id:
				_hovered = ""
			_refresh_info())
		ui.add_child(b)
		node_buttons[id] = b

	var info := PainterView.new(func(g: CanvasItem, _center: Vector2, _size: float) -> void:
		Paint.fill_rounded_rect(g, 0, 0, Config.WIDTH - 40, 52, 10, Palette.PANEL)
		Paint.stroke_rounded_rect(g, 0, 0, Config.WIDTH - 40, 52, 10, 1, Palette.BORDER))
	info.position = Vector2(20, 494)
	info.size = Vector2(Config.WIDTH - 40, 52)
	ui.add_child(info)
	_info_title = Ui.text(ui, 34, 500, "", 14, Palette.TEXT, true)
	_info_body = Ui.text(ui, 34, 520, "", 12, Palette.TEXT_DIM)
	_info_body.set_wrap(Config.WIDTH - 70)

	refund_button = GameButton.new(Rect2(20, 556, 170, 34), "Refund all stars", func() -> void:
		_profile.refund_tech()
		Audio.play("sell")
		_refresh()).font(13)
	ui.add_child(refund_button)
	Ui.text(ui, Config.WIDTH - 20, 573, "Earn up to 3 stars per level: 3 for losing no lives, 2 for keeping at least half.",
		12, Palette.TEXT_DIM, false, Vector2(1, 0.5))
	_refresh()


## Lines from every node to the nodes it opens.
func _draw_links(g: CanvasItem) -> void:
	for n: Tech.TechNode in Tech.NODES:
		var to: Rect2 = node_rect(n)
		for parent: String in n.parents:
			var from: Rect2 = node_rect(Tech.get_node(parent))
			var owned: bool = _profile.owns(parent)
			var color: Color = Color(Palette.GOLD, 0.7) if owned else Color(Palette.BORDER, 0.9)
			var pts := PackedVector2Array()
			if from.position.y == to.position.y and to.position.x - from.end.x < NODE_W:
				# Next to it on the same row.
				pts = [Vector2(from.end.x, from.get_center().y), Vector2(to.position.x, to.get_center().y)]
			elif from.position.y == to.position.y:
				# Further along the row: go around underneath the node in between.
				var under: float = from.end.y + (ROW_H - NODE_H) / 2.0
				pts = [Vector2(from.end.x, from.get_center().y), Vector2(from.end.x + GAP_X / 2.0, from.get_center().y),
					Vector2(from.end.x + GAP_X / 2.0, under), Vector2(to.get_center().x, under),
					Vector2(to.get_center().x, to.end.y)]
			else:
				# Straight down the column.
				pts = [Vector2(from.get_center().x, from.end.y), Vector2(to.get_center().x, to.position.y)]
			g.draw_polyline(pts, color, 2.0)


func _buy(id: String) -> void:
	if _profile.buy_tech(id):
		Audio.play("upgrade")
	else:
		Audio.play("error")
	_hovered = id
	_refresh()


func _refresh() -> void:
	_stars.show_text("★ %d to spend  (%d earned)" % [_profile.available_stars(), _profile.total_stars()])
	for id: String in node_buttons:
		var b: GameButton = node_buttons[id]
		var state: Profile.TechState = _profile.tech_state(id)
		b.set_sublabel(state_text(id), STATE_LABEL_COLOR[state])
		b.set_selected(state == Profile.TechState.OWNED)
		b.modulate.a = 1.0 if state == Profile.TechState.OWNED or state == Profile.TechState.AVAILABLE \
			or state == Profile.TechState.NEEDS_STARS else 0.55
	refund_button.set_enabled(_profile.spent_stars() > 0)
	_links.queue_redraw()
	_refresh_info()


## The short status under a node's name.
func state_text(id: String) -> String:
	var n: Tech.TechNode = Tech.get_node(id)
	match _profile.tech_state(id):
		Profile.TechState.OWNED:
			return "Owned"
		Profile.TechState.AVAILABLE, Profile.TechState.NEEDS_STARS:
			return "★ %d" % n.cost
		Profile.TechState.NEEDS_EARNED:
			return "Earn ★%d" % n.earned
	return "Locked"


func _refresh_info() -> void:
	if _hovered.is_empty():
		_info_title.show_text("Hover a node to read it, click to buy it")
		_info_body.show_text("Stars you spend here can all be refunded. Locked content shows up here, not in the game.")
		return
	var n: Tech.TechNode = Tech.get_node(_hovered)
	_info_title.show_text(n.name)
	_info_body.show_text("%s   %s" % [n.description, requirement_text(_hovered)])


## What it takes to buy a node, as the player reads it.
func requirement_text(id: String) -> String:
	var n: Tech.TechNode = Tech.get_node(id)
	match _profile.tech_state(id):
		Profile.TechState.OWNED:
			return "(Owned)"
		Profile.TechState.AVAILABLE:
			return "(Costs ★%d.)" % n.cost
		Profile.TechState.NEEDS_STARS:
			return "(Costs ★%d: you have ★%d to spend.)" % [n.cost, _profile.available_stars()]
		Profile.TechState.NEEDS_EARNED:
			return "(Unlocks at ★%d earned in total.)" % n.earned
	var names: PackedStringArray = []
	for parent: String in n.parents:
		if not _profile.owns(parent):
			names.append(Tech.get_node(parent).name)
	return "(Needs %s first.)" % " and ".join(names)


## Android's back button goes back to the menu.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Router.goto_menu()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		Router.goto_menu()


# ---- what the player sees (read by the scene tests) ---------------------------

func stars_text() -> String:
	return _stars.text


func info_title_text() -> String:
	return _info_title.text


func info_body_text() -> String:
	return _info_body.text
