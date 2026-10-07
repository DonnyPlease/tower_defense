class_name LevelSelectScene
extends Node2D
## Pick a level (or endless mode), and how to play it: as designed or one of
## the variants unlocked in the tech tree (night, reversed, ...).

const CARD_W: float = 290
const CARD_H: float = 236
const GAP: float = 20

## The Play button of each card, by level id (tests).
var play_buttons: Dictionary[String, GameButton] = {}
var back_button: GameButton
var tech_button: GameButton
## The button that switches a card between its variants, by level id (only
## levels with variants unlocked have one).
var variant_buttons: Dictionary[String, GameButton] = {}

var _stars: TextLabel
## Each card's status line ("★★☆", "Best: 4 waves") and description, by level id.
var _status: Dictionary[String, TextLabel] = {}
var _desc: Dictionary[String, TextLabel] = {}
## The variant each card will play ("" as designed), by level id.
var _chosen: Dictionary[String, String] = {}
var _cards: Dictionary[String, Card] = {}
var _profile: Profile


class Card:
	var id: String
	var title: String
	var desc: String
	var map: GameMap
	var unlocked: bool
	var lock_text: String
	var status: String
	var status_color: Color
	var extra: String


func _ready() -> void:
	var profile: Profile = Profile.load_profile()
	_profile = profile
	var ui := Control.new()
	ui.size = Vector2(Config.WIDTH, Config.HEIGHT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var bg := ColorRect.new()
	bg.color = Palette.BACKGROUND
	bg.size = ui.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)

	Ui.text(ui, Config.WIDTH / 2.0, 36, "Choose a level", 30, Palette.TEXT, true, Vector2(0.5, 0.5))
	_stars = Ui.text(ui, Config.WIDTH / 2.0, 66, "★ %d stars" % profile.total_stars(), 15, Palette.GOLD, false, Vector2(0.5, 0.5))
	back_button = GameButton.new(Rect2(20, 18, 100, 40), "‹ Back", Router.goto_menu)
	ui.add_child(back_button)
	tech_button = GameButton.new(Rect2(Config.WIDTH - 140, 18, 120, 40), "Tech tree", Router.goto_tech)
	ui.add_child(tech_button)

	var cards: Array[Card] = []
	for i: int in Levels.LEVELS.size():
		var level: LevelDef = Levels.LEVELS[i]
		var card := Card.new()
		card.id = level.id
		card.title = "%d. %s" % [i + 1, level.name]
		card.desc = level.description
		card.map = GameMap.new(level.name, level.tiles, level.maze, level.road_walls)
		card.unlocked = profile.is_level_unlocked(i)
		card.lock_text = "Beat %s first" % Levels.LEVELS[i - 1].name if i > 0 else ""
		card.status = Format.star_string(profile.stars_on(level.id))
		card.status_color = Palette.GOLD
		card.extra = "%d waves%s" % [level.waves.size(), " · maze" if level.maze else (" · walls" if level.road_walls else "")]
		cards.append(card)
	var endless := Card.new()
	endless.id = Levels.ENDLESS.id
	endless.title = Levels.ENDLESS.name
	endless.desc = Levels.ENDLESS.description
	endless.map = GameMap.new(Levels.ENDLESS.name, Levels.ENDLESS.tiles)
	endless.unlocked = profile.is_endless_unlocked()
	endless.lock_text = "Beat %s first" % Levels.LEVELS[1].name
	endless.status = "Best: %d waves" % profile.endless_best if profile.endless_best > 0 else "No record yet"
	endless.status_color = Palette.TEXT
	endless.extra = "Survive as long as you can"
	cards.append(endless)

	var x0: float = (Config.WIDTH - 3 * CARD_W - 2 * GAP) / 2
	for i: int in cards.size():
		var card: Card = cards[i]
		@warning_ignore("integer_division")
		var row: int = i / 3
		var x: float = x0 + (i % 3) * (CARD_W + GAP)
		var y: float = 96 + row * (CARD_H + GAP)
		var map: GameMap = card.map
		var unlocked: bool = card.unlocked
		ui.add_child(_card_background(x, y, map, unlocked))
		var alpha: float = 1.0 if unlocked else 0.35
		var status: TextLabel = Ui.text(ui, x + 168, y + 14, card.status, 13 if card.id == Levels.ENDLESS.id else 20,
			card.status_color).set_wrap(110)
		var extra: TextLabel = Ui.text(ui, x + 168, y + 50, card.extra, 12, Palette.TEXT_DIM).set_wrap(110)
		var title: TextLabel = Ui.text(ui, x + 15, y + 124, card.title, 18, Palette.TEXT, true)
		for label: TextLabel in [status, extra, title]:
			label.modulate.a = alpha
		var desc: TextLabel = Ui.text(ui, x + 15, y + 148, card.desc if unlocked else "🔒 %s" % card.lock_text, 13,
			Palette.TEXT_DIM).set_wrap(CARD_W - 30)
		var id: String = card.id
		_status[id] = status
		_desc[id] = desc
		_cards[id] = card
		_chosen[id] = ""
		var play := GameButton.new(Rect2(x + 15, y + CARD_H - 44, CARD_W - 30, 34), "Play" if unlocked else "Locked",
			func() -> void:
				if unlocked:
					Router.goto_game(play_id(id))).font(15)
		var variants: Array[String] = profile.variants_for(id)
		if unlocked and variants.size() > 1:
			var vb := GameButton.new(Rect2(x + 168, y + 84, CARD_W - 183, 28), "Normal  ▸", func() -> void: next_variant(id)) \
				.font(12)
			ui.add_child(vb)
			variant_buttons[id] = vb
		if unlocked:
			play.primary()
		ui.add_child(play)
		play.set_enabled(unlocked)
		play_buttons[id] = play
	Audio.set_intensity(0)


## The level id the card's Play button starts ("meadow" or "meadow@night").
func play_id(id: String) -> String:
	var v: String = _chosen.get(id, "")
	return id if v.is_empty() else "%s@%s" % [id, v]


## Switches a card to its next variant (wrapping back to the level as designed).
func next_variant(id: String) -> void:
	var variants: Array[String] = _profile.variants_for(id)
	var i: int = variants.find(_chosen.get(id, ""))
	var v: String = variants[(i + 1) % variants.size()]
	_chosen[id] = v
	var b: GameButton = variant_buttons[id]
	b.set_label(("%s  ▸" % Levels.get_variant(v).name) if not v.is_empty() else "Normal  ▸")
	b.set_selected(not v.is_empty())
	_status[id].show_text(Format.star_string(_profile.stars_on(play_id(id))))
	_desc[id].show_text(Levels.get_variant(v).description if not v.is_empty() else _cards[id].desc)


func _card_background(x: float, y: float, map: GameMap, unlocked: bool) -> PainterView:
	var card := PainterView.new(func(g: CanvasItem, _center: Vector2, _size: float) -> void:
		Paint.fill_rounded_rect(g, 0, 0, CARD_W, CARD_H, 12, Palette.PANEL)
		Paint.stroke_rounded_rect(g, 0, 0, CARD_W, CARD_H, 12, 1, Palette.BORDER)
		Minimap.draw(g, map, 15, 12, 7)) # 140 x 105
	card.position = Vector2(x, y)
	card.size = Vector2(CARD_W, CARD_H)
	card.modulate.a = 1.0 if unlocked else 0.6
	return card


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


func status_text(id: String) -> String:
	return _status[id].text


func description_text(id: String) -> String:
	return _desc[id].text
