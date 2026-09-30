class_name UpgradesScene
extends Node2D
## Spend stars on permanent upgrades; also shows which towers are unlocked.

## The Buy button of each perk, by perk id (tests).
var buy_buttons: Dictionary[String, GameButton] = {}
var refund_button: GameButton

var _profile: Profile
var _stars: TextLabel
var _effects: Dictionary[String, TextLabel] = {}
var _pips: Dictionary[String, DrawNode] = {}


func _ready() -> void:
	_profile = Profile.load_profile()
	var ui := Control.new()
	ui.size = Vector2(Config.WIDTH, Config.HEIGHT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var bg := ColorRect.new()
	bg.color = Palette.BACKGROUND
	bg.size = ui.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	Ui.text(ui, Config.WIDTH / 2.0, 36, "Upgrades", 30, Palette.TEXT, true, Vector2(0.5, 0.5))
	_stars = Ui.text(ui, Config.WIDTH / 2.0, 66, "", 15, Palette.GOLD, false, Vector2(0.5, 0.5))
	ui.add_child(GameButton.new(Rect2(20, 18, 100, 40), "‹ Back", Router.goto_menu))
	ui.add_child(GameButton.new(Rect2(Config.WIDTH - 140, 18, 120, 40), "Levels", Router.goto_levels))

	# Perk rows.
	for i: int in Perks.IDS.size():
		var id: String = Perks.IDS[i]
		var y: float = 100 + i * 76
		var perk: Perks.PerkDef = Perks.get_def(id)
		ui.add_child(_panel(60, y, 560, 64))
		var name: TextLabel = Ui.text(ui, 78, y + 10, perk.name, 17, Palette.TEXT, true)
		_effects[id] = Ui.text(ui, 78, y + 36, "", 13, Palette.TEXT_DIM)
		var pip_x: float = 78 + name.size.x + 18
		var pip_y: float = y + 21
		var pips := DrawNode.new(func(g: CanvasItem) -> void:
			var rank: int = _profile.perk_rank(id)
			for k: int in perk.costs.size():
				Paint.fill_circle(g, pip_x + k * 16, pip_y, 5, Palette.GOLD if k < rank else Palette.PANEL_LIGHTER))
		ui.add_child(pips)
		_pips[id] = pips
		var buy := GameButton.new(Rect2(470, y + 12, 136, 40), "", func() -> void:
			if _profile.buy_perk(id):
				Audio.play("upgrade")
			_refresh()).primary().font(14)
		ui.add_child(buy)
		buy_buttons[id] = buy

	refund_button = GameButton.new(Rect2(60, 412, 180, 36), "Refund all stars", func() -> void:
		_profile.refund_perks()
		Audio.play("sell")
		_refresh()).font(13)
	ui.add_child(refund_button)

	# Tower unlocks.
	ui.add_child(_panel(650, 100, 290, 348))
	Ui.text(ui, 668, 110, "Towers", 17, Palette.TEXT, true)
	Ui.text(ui, 668, 134, "Unlocked by total stars earned", 12, Palette.TEXT_DIM)
	var unlocked: Array[String] = _profile.unlocked_towers()
	for i: int in Towers.KINDS.size():
		var kind: String = Towers.KINDS[i]
		var y: float = 164 + i * 46
		var d: TowerDef = Towers.get_def(kind)
		var have: bool = unlocked.has(kind)
		var icon := PainterView.new(func(g: CanvasItem, center: Vector2, s: float) -> void:
			TowerArt.draw_icon(g, kind, center, s))
		icon.position = Vector2(690 - 16, y + 16 - 16)
		icon.size = Vector2(32, 32)
		icon.modulate.a = 1.0 if have else 0.35
		ui.add_child(icon)
		Ui.text(ui, 716, y + 6, d.name, 15, Palette.TEXT if have else Palette.TEXT_DIM, true)
		Ui.text(ui, 920, y + 7, "✓" if have else "★ %d" % d.unlock_stars, 15, Palette.GREEN if have else Palette.GOLD,
			false, Vector2(1, 0))

	Ui.text(ui, Config.WIDTH / 2.0, 490, "Earn up to 3 stars per level: 3 for losing no lives, 2 for keeping at least half.",
		13, Palette.TEXT_DIM, false, Vector2(0.5, 0.5))
	_refresh()


func _panel(x: float, y: float, w: float, h: float) -> PainterView:
	var p := PainterView.new(func(g: CanvasItem, _center: Vector2, _size: float) -> void:
		Paint.fill_rounded_rect(g, 0, 0, w, h, 10, Palette.PANEL)
		Paint.stroke_rounded_rect(g, 0, 0, w, h, 10, 1, Palette.BORDER))
	p.position = Vector2(x, y)
	p.size = Vector2(w, h)
	return p


func _refresh() -> void:
	_stars.show_text("★ %d to spend  (%d earned)" % [_profile.available_stars(), _profile.total_stars()])
	for id: String in Perks.IDS:
		var perk: Perks.PerkDef = Perks.get_def(id)
		var rank: int = _profile.perk_rank(id)
		var max_rank: int = perk.costs.size()
		if rank > 0:
			var next: String = "   (next: %s)" % perk.effect(rank + 1) if rank < max_rank else ""
			_effects[id].show_text(perk.effect(rank) + next)
		else:
			_effects[id].show_text("Next: %s" % perk.effect(1))
		_pips[id].queue_redraw()
		var cost: int = _profile.next_perk_cost(id)
		if cost < 0:
			buy_buttons[id].set_label("Maxed").set_enabled(false)
		else:
			buy_buttons[id].set_label("Buy  ★ %d" % cost).set_enabled(cost <= _profile.available_stars())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		Router.goto_menu()
