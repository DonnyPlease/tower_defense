class_name DraftOverlay
extends Control
## The run perk offer ("field orders"): a few cards over the dimmed game; the
## player keeps one (click it, or press its number). Shown while the world
## has an offer waiting.

const DEPTH: int = 190
const CARD_W: float = 210
const CARD_H: float = 150
const GAP: float = 16

## The card of each perk offered, in order (tests).
var cards: Array[GameButton] = []
var card_ids: Array[String] = []

var _host: GameScene
var _title: TextLabel
var _subtitle: TextLabel
var _shown_key: String = ""


func _init(host: GameScene) -> void:
	_host = host
	size = Vector2(Config.WIDTH, Config.HEIGHT)
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_title = Ui.text(self, Config.FIELD_W / 2.0, 150, "Field orders", 30, Palette.GOLD, true, Vector2(0.5, 0.5)).set_outline(4)
	_subtitle = Ui.text(self, Config.FIELD_W / 2.0, 186, "Choose one for this game", 15, Palette.TEXT, false,
		Vector2(0.5, 0.5)).set_outline(3)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))


## Called every frame: shows the world's offer, if there is one.
func refresh() -> void:
	var world: World = _host.world
	var offer: Array[String] = []
	if world.status == World.Status.PLAYING:
		offer = world.perk_offer
	visible = not offer.is_empty()
	var key: String = ",".join(offer)
	if key == _shown_key:
		return
	_shown_key = key
	for c: GameButton in cards:
		c.queue_free()
	cards = []
	card_ids = offer.duplicate()
	# Centred over the field; narrower cards when four are offered.
	var n: int = maxi(1, offer.size())
	var w: float = minf(CARD_W, (Config.FIELD_W - 32 - (n - 1) * GAP) / n)
	var x0: float = (Config.FIELD_W - (n * w + (n - 1) * GAP)) / 2
	for i: int in offer.size():
		var id: String = offer[i]
		var def: RunPerks.RunPerkDef = RunPerks.get_def(id)
		var card := GameButton.new(Rect2(x0 + i * (w + GAP), 220, w, CARD_H), "",
			func() -> void: _host.choose_run_perk(id)).key(str(i + 1))
		add_child(card)
		Ui.text(card, w / 2, 30, def.name, 18, Palette.GOLD, true, Vector2(0.5, 0.5))
		Ui.text(card, 16, 56, def.description, 14, Palette.TEXT).set_wrap(w - 32)
		cards.append(card)
	var taken: PackedStringArray = []
	for id: String in world.run_perks:
		taken.append(RunPerks.get_def(id).name)
	_subtitle.show_text("Choose one for this game" + ("   ·   Taken: %s" % ", ".join(taken) if not taken.is_empty() else ""))
