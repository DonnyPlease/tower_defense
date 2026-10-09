class_name TechTreeScene
extends Node2D
## The tech tree: spend stars on towers, their branches, perks, starting
## bonuses and challenges. Two pages with a switch at the top (also Tab or the
## arrow keys):
## - Towers: every tower as a round badge, in the order stars unlock them,
##   with its two branches under it and a track of the stars earned;
## - Upgrades: the perks' ranks as tracks, the starting bonuses, field orders
##   and level variants.
## Hover (or hold) a node to read it; click it to buy it. The layout comes
## from the data (Towers.KINDS, Tech.NODES), so new towers and perks find
## their place without changes here.

enum Page { TOWERS, UPGRADES }

const TAB_W: float = 150.0
const TAB_H: float = 36.0
const TABS_Y: float = 86.0
const TOWER_Y: float = 196.0 ## centre of the tower badges
const TOWER_R: float = 28.0
const BRANCH_Y: float = 334.0
const BRANCH_R: float = 21.0
const BRANCH_DX: float = 33.0
const TRACK_Y: float = 418.0
const COL_X0: float = 80.0
const COL_X1: float = 920.0
const PILL_W: float = 112.0
const PILL_H: float = 44.0
const STATE_LABEL_COLOR: Dictionary[Profile.TechState, Color] = {
	Profile.TechState.OWNED: Palette.GREEN,
	Profile.TechState.AVAILABLE: Palette.GOLD,
	Profile.TechState.NEEDS_STARS: Palette.RED,
	Profile.TechState.NEEDS_EARNED: Palette.TEXT_DIM,
	Profile.TechState.NEEDS_PARENTS: Palette.TEXT_DIM,
}

## The page shown when the screen opens (the last one looked at).
static var last_page: Page = Page.TOWERS

## The button of each node, by node id (tests).
var node_buttons: Dictionary[String, GameButton] = {}
## The page switch: "towers" and "upgrades".
var tab_buttons: Dictionary[String, GameButton] = {}
var refund_button: GameButton
var back_button: GameButton
var levels_button: GameButton
var page: Page = Page.TOWERS

var _profile: Profile
var _ui: Control
var _stars: TextLabel
var _info_title: TextLabel
var _info_body: TextLabel
var _hovered: String = ""
var _pages: Dictionary[Page, Control] = {}
var _links: Dictionary[Page, DrawNode] = {}
var _state_labels: Dictionary[String, TextLabel] = {}
var _tab_marker: PainterView
var _tab_tween: Tween
## Where each node is drawn (its rectangle on its page), for the links.
var _rects: Dictionary[String, Rect2] = {}


func _ready() -> void:
	_profile = Profile.load_profile()
	_ui = Screen.centered_page(self)
	Ui.text(_ui, Config.WIDTH / 2.0, 32, "Tech tree", 30, Palette.TEXT, true, Vector2(0.5, 0.5))
	_stars = Ui.text(_ui, Config.WIDTH / 2.0, 62, "", 15, Palette.GOLD, false, Vector2(0.5, 0.5))
	back_button = GameButton.new(Rect2(20, 16, 100, 40), "‹ Back", Router.goto_menu)
	_ui.add_child(back_button)
	levels_button = GameButton.new(Rect2(Config.WIDTH - 140, 16, 120, 40), "Levels", Router.goto_levels)
	_ui.add_child(levels_button)
	_build_tabs()
	for p: Page in [Page.TOWERS, Page.UPGRADES]:
		var c := Control.new()
		c.size = Screen.BASE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(c)
		_pages[p] = c
		_links[p] = DrawNode.new(func(g: CanvasItem) -> void: _draw_links(g, p))
		c.add_child(_links[p])
	_build_towers(_pages[Page.TOWERS])
	_build_upgrades(_pages[Page.UPGRADES])

	var info := PainterView.new(func(g: CanvasItem, _center: Vector2, _size: float) -> void:
		Paint.fill_rounded_rect(g, 0, 0, Config.WIDTH - 40, 64, 10, Palette.PANEL)
		Paint.stroke_rounded_rect(g, 0, 0, Config.WIDTH - 40, 64, 10, 1, Palette.BORDER))
	info.position = Vector2(20, 478)
	info.size = Vector2(Config.WIDTH - 40, 64)
	_ui.add_child(info)
	_info_title = Ui.text(_ui, 36, 487, "", 15, Palette.TEXT, true)
	_info_body = Ui.text(_ui, 36, 510, "", 12, Palette.TEXT_DIM)
	_info_body.set_wrap(Config.WIDTH - 72)

	refund_button = GameButton.new(Rect2(20, 554, 170, 34), "Refund all stars", func() -> void:
		_profile.refund_tech()
		Audio.play("sell")
		_refresh()).font(13)
	_ui.add_child(refund_button)
	Ui.text(_ui, Config.WIDTH - 20, 571, "Earn up to 3 stars per level: 3 for losing no lives, 2 for keeping at least half.",
		12, Palette.TEXT_DIM, false, Vector2(1, 0.5))
	show_page(last_page, false)
	_refresh()


# ---- the switch ------------------------------------------------------------------

func _build_tabs() -> void:
	var x0: float = Config.WIDTH / 2.0 - TAB_W
	var track := PainterView.new(func(g: CanvasItem, _center: Vector2, _s: float) -> void:
		Paint.fill_rounded_rect(g, 0, 0, TAB_W * 2 + 8, TAB_H + 8, (TAB_H + 8) / 2, Palette.PANEL)
		Paint.stroke_rounded_rect(g, 0, 0, TAB_W * 2 + 8, TAB_H + 8, (TAB_H + 8) / 2, 1, Palette.BORDER))
	track.position = Vector2(x0 - 4, TABS_Y - 4)
	track.size = Vector2(TAB_W * 2 + 8, TAB_H + 8)
	_ui.add_child(track)
	# The highlight slides under the chosen tab.
	_tab_marker = PainterView.new(func(g: CanvasItem, _center: Vector2, _s: float) -> void:
		Paint.fill_rounded_rect(g, 0, 0, TAB_W, TAB_H, TAB_H / 2, Palette.ACCENT))
	_tab_marker.size = Vector2(TAB_W, TAB_H)
	_tab_marker.position = Vector2(x0, TABS_Y)
	_ui.add_child(_tab_marker)
	var labels: Dictionary[String, String] = {"towers": "Towers", "upgrades": "Upgrades"}
	var i: int = 0
	for id: String in labels:
		var target: Page = Page.TOWERS if id == "towers" else Page.UPGRADES
		var b := GameButton.new(Rect2(x0 + i * TAB_W, TABS_Y, TAB_W, TAB_H), labels[id], func() -> void:
			show_page(target)).flat().font(15)
		_ui.add_child(b)
		tab_buttons[id] = b
		i += 1


## Switches the page (the highlight slides over unless `animate` is false).
func show_page(which: Page, animate: bool = true) -> void:
	page = which
	last_page = which
	for p: Page in _pages:
		_pages[p].visible = p == which
	var x: float = Config.WIDTH / 2.0 - TAB_W + (TAB_W if which == Page.UPGRADES else 0.0)
	if _tab_tween != null:
		_tab_tween.kill()
	if animate:
		_tab_tween = _tab_marker.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tab_tween.tween_property(_tab_marker, "position:x", x, 0.18)
		var shown: Control = _pages[which]
		shown.modulate.a = 0.0
		_tab_tween.parallel().tween_property(shown, "modulate:a", 1.0, 0.18)
	else:
		_tab_marker.position.x = x
	tab_buttons["towers"].set_label("Towers", Palette.TEXT if which == Page.TOWERS else Palette.TEXT_DIM)
	tab_buttons["upgrades"].set_label("Upgrades", Palette.TEXT if which == Page.UPGRADES else Palette.TEXT_DIM)
	_hovered = ""
	_refresh_info()


# ---- towers ---------------------------------------------------------------------

func _column_x(i: int) -> float:
	return COL_X0 + (COL_X1 - COL_X0) * (float(i) / maxi(1, Towers.KINDS.size() - 1))


func _build_towers(p: Control) -> void:
	Ui.text(p, COL_X0 - 40, 136, "Owned from the start", 11, Palette.TEXT_DIM, true)
	for i: int in Towers.KINDS.size():
		var kind: String = Towers.KINDS[i]
		var x: float = _column_x(i)
		var node: Tech.TechNode = Tech.get_node(kind)
		_badge(p, kind, kind, "", Vector2(x, TOWER_Y), TOWER_R, 14)
		var d: TowerDef = Towers.get_def(kind)
		for j: int in d.branches.size():
			var b: TowerBranch = d.branches[j]
			_badge(p, b.id, kind, b.id, Vector2(x + (j * 2 - 1) * BRANCH_DX, BRANCH_Y), BRANCH_R, 11)
		if node.earned > 0:
			# What it takes, over the badge.
			Ui.text(p, x, 150, "★ %d earned" % node.earned, 11, Palette.TEXT_DIM, false, Vector2(0.5, 0))
	_build_track(p)


## A round node with its name and state under it.
func _badge(p: Control, id: String, kind: String, branch: String, center: Vector2, radius: float, font_size: int) -> void:
	var b := TechBadge.new(center, radius, kind, branch, func() -> void: _buy(id))
	_hookup(b, id)
	p.add_child(b)
	_rects[id] = Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2)
	var name: TextLabel = Ui.text(p, center.x, center.y + radius + 5, Tech.get_node(id).name, font_size, Palette.TEXT, true,
		Vector2(0.5, 0))
	_state_labels[id] = Ui.text(p, center.x, name.position.y + name.size.y, "", font_size - 1, Palette.TEXT_DIM, false,
		Vector2(0.5, 0))


## The track of stars earned under the towers: how far along the tree they reach.
func _build_track(p: Control) -> void:
	var track := PainterView.new(func(g: CanvasItem, _center: Vector2, _s: float) -> void:
		var earned: int = _profile.total_stars()
		var thresholds: Array[int] = []
		for kind: String in Towers.KINDS:
			thresholds.append(Tech.get_node(kind).earned)
		var fill_x: float = COL_X0
		for i: int in thresholds.size():
			if earned >= thresholds[i]:
				fill_x = _column_x(i)
			else:
				var prev: int = thresholds[i - 1] if i > 0 else 0
				var f: float = float(earned - prev) / maxi(1, thresholds[i] - prev)
				fill_x = lerpf(_column_x(maxi(0, i - 1)), _column_x(i), clampf(f, 0, 1))
				break
		Paint.fill_rounded_rect(g, COL_X0 - 6, TRACK_Y - 5, COL_X1 - COL_X0 + 12, 10, 5, Palette.PANEL_LIGHT)
		Paint.fill_rounded_rect(g, COL_X0 - 6, TRACK_Y - 5, fill_x - COL_X0 + 12, 10, 5, Palette.GOLD)
		for i: int in thresholds.size():
			var x: float = _column_x(i)
			Paint.fill_circle(g, x, TRACK_Y, 8, Palette.GOLD if earned >= thresholds[i] else Palette.PANEL_LIGHTER)
			Paint.stroke_circle(g, x, TRACK_Y, 8, 2, Palette.BACKGROUND)
		var label: String = "★ %d earned" % earned
		var font: Font = Ui.bold()
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var lx: float = clampf(fill_x - w / 2, COL_X0 - 40, COL_X1 + 40 - w)
		g.draw_string(font, Vector2(lx, TRACK_Y + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.GOLD))
	track.size = Screen.BASE
	p.add_child(track)


# ---- upgrades ---------------------------------------------------------------------

func _build_upgrades(p: Control) -> void:
	# Perks: one track per perk, its ranks one after another.
	Ui.text(p, 20, 140, "Perks", 13, Palette.TEXT_DIM, true)
	for r: int in Perks.IDS.size():
		var perk: Perks.PerkDef = Perks.get_def(Perks.IDS[r])
		var y: float = 164 + r * 70
		var id: String = perk.id
		var icon := PainterView.new(func(g: CanvasItem, center: Vector2, _s: float) -> void:
			Paint.fill_circle(g, center.x, center.y, 20, Palette.PANEL_LIGHT)
			_perk_icon(g, id, center))
		icon.position = Vector2(20, y + PILL_H / 2 - 22)
		icon.size = Vector2(44, 44)
		p.add_child(icon)
		Ui.text(p, 72, y + PILL_H / 2, perk.name, 14, Palette.TEXT, true, Vector2(0, 0.5))
		for k: int in perk.costs.size():
			_pill(p, Tech.perk_node(perk.id, k + 1), Rect2(180 + k * (PILL_W + 14), y, PILL_W, PILL_H))

	# Everything else, in groups on the right.
	var groups: Array[Array] = [
		["Starting bonuses", Tech.NODES.filter(func(n: Tech.TechNode) -> bool: return n.kind == Tech.Kind.BONUS \
			and not n.id.begins_with("orders"))],
		["Field orders", Tech.NODES.filter(func(n: Tech.TechNode) -> bool: return n.id.begins_with("orders"))],
		["Level variants", Tech.NODES.filter(func(n: Tech.TechNode) -> bool: return n.kind == Tech.Kind.VARIANT)],
	]
	var y: float = 140.0
	for group: Array in groups:
		Ui.text(p, 600, y, str(group[0]), 13, Palette.TEXT_DIM, true)
		y += 24
		var nodes: Array = group[1]
		for i: int in nodes.size():
			var n: Tech.TechNode = nodes[i]
			@warning_ignore("integer_division")
			var row: int = i / 3
			_pill(p, n.id, Rect2(600 + (i % 3) * (PILL_W + 14), y + row * (PILL_H + 10), PILL_W, PILL_H))
		@warning_ignore("integer_division")
		y += ((nodes.size() + 2) / 3) * (PILL_H + 10) + 14


## A rounded node with its name and state.
func _pill(p: Control, id: String, r: Rect2) -> void:
	var b := GameButton.new(r, Tech.get_node(id).name, func() -> void: _buy(id)).font(12).sublabel("")
	_hookup(b, id)
	p.add_child(b)
	_rects[id] = r


## A symbol for each perk (a star for perks without their own).
static func _perk_icon(g: CanvasItem, id: String, c: Vector2) -> void:
	match id:
		"capital": # a stack of coins
			for k: int in 3:
				Paint.fill_ellipse(g, c.x, c.y + 7 - k * 6, 24, 10, Palette.rgb(0xc99a2e))
				Paint.fill_ellipse(g, c.x, c.y + 5 - k * 6, 24, 10, Palette.GOLD)
		"fortify": # a heart
			Paint.fill_circle(g, c.x - 5.5, c.y - 3, 7, Palette.RED)
			Paint.fill_circle(g, c.x + 5.5, c.y - 3, 7, Palette.RED)
			Paint.fill_triangle(g, c.x - 12, c.y - 0.5, c.x + 12, c.y - 0.5, c.x, c.y + 12, Palette.RED)
		"engineering": # a gear
			Icons.gear(g, c, 28)
		"firepower": # crosshairs
			var o: Color = Palette.rgb(0xff8c42)
			Paint.stroke_circle(g, c.x, c.y, 10, 2.5, o)
			for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				Paint.line(g, c.x + d.x * 5, c.y + d.y * 5, c.x + d.x * 15, c.y + d.y * 15, 2.5, o)
		_:
			Paint.fill_circle(g, c.x, c.y, 10, Palette.GOLD)


func _hookup(b: GameButton, id: String) -> void:
	b.hover_callback(func(on: bool) -> void:
		if on:
			_hovered = id
		elif _hovered == id:
			_hovered = ""
		_refresh_info())
	node_buttons[id] = b


## Links from every node to the nodes it opens, on one page: gold once the
## parent is owned, dotted grey before.
func _draw_links(g: CanvasItem, p: Page) -> void:
	for n: Tech.TechNode in Tech.NODES:
		if not _rects.has(n.id) or not _on_page(n, p):
			continue
		var to: Rect2 = _rects[n.id]
		for parent: String in n.parents:
			if not _rects.has(parent):
				continue
			var from: Rect2 = _rects[parent]
			if p == Page.UPGRADES and absf(from.get_center().y - to.get_center().y) >= 1:
				continue # across groups: the node's text says what it needs instead
			var owned: bool = _profile.owns(parent)
			var a: Vector2
			var b: Vector2
			var c1: Vector2
			var c2: Vector2
			if absf(from.get_center().y - to.get_center().y) < 1:
				a = Vector2(from.end.x + 2, from.get_center().y)
				b = Vector2(to.position.x - 2, to.get_center().y)
				c1 = a
				c2 = b
			else:
				# Down from a tower to its branch (or across to another row).
				a = Vector2(from.get_center().x, from.end.y + 44) # under the name and state
				b = Vector2(to.get_center().x, to.position.y - 2)
				c1 = a + Vector2(0, (b.y - a.y) * 0.6)
				c2 = b - Vector2(0, (b.y - a.y) * 0.6)
			var pts := PackedVector2Array()
			for k: int in 17:
				pts.append(a.bezier_interpolate(c1, c2, b, k / 16.0))
			if owned:
				g.draw_polyline(pts, Color(Palette.GOLD, 0.22), 8.0, true)
				g.draw_polyline(pts, Palette.GOLD, 2.5, true)
			else:
				for k: int in range(0, pts.size() - 1, 2):
					g.draw_line(pts[k], pts[k + 1], Palette.BORDER, 2.0, true)


static func _on_page(n: Tech.TechNode, p: Page) -> bool:
	var towers: bool = n.kind == Tech.Kind.TOWER or n.kind == Tech.Kind.BRANCH
	return towers == (p == Page.TOWERS)


# ---- buying and reading ---------------------------------------------------------

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
		b.set_selected(state == Profile.TechState.OWNED)
		var badge := b as TechBadge
		if badge != null:
			badge.set_state(state)
			_state_labels[id].show_text(state_text(id))
			_state_labels[id].set_color(STATE_LABEL_COLOR[state])
		else:
			b.set_sublabel(state_text(id), STATE_LABEL_COLOR[state])
			b.modulate.a = 1.0 if state == Profile.TechState.OWNED or state == Profile.TechState.AVAILABLE \
				or state == Profile.TechState.NEEDS_STARS else 0.55
	refund_button.set_enabled(_profile.spent_stars() > 0)
	for p: Page in _links:
		_links[p].queue_redraw()
	for c: Control in _pages.values():
		for child: Node in c.get_children():
			if child is PainterView:
				(child as PainterView).queue_redraw()
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
	if _info_title == null:
		return
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
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			Router.goto_menu()
		KEY_TAB, KEY_LEFT, KEY_RIGHT:
			get_viewport().set_input_as_handled()
			show_page(Page.UPGRADES if page == Page.TOWERS else Page.TOWERS)


# ---- what the player sees (read by the scene tests) ---------------------------

func stars_text() -> String:
	return _stars.text


func info_title_text() -> String:
	return _info_title.text


func info_body_text() -> String:
	return _info_body.text
