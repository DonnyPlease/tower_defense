class_name Tutorial
extends Control
## A short guided start for a player's first game (on Meadow): one hint at a
## time at the top of the field, each moving on when the player has done it.
## It can be skipped; once finished or skipped it never shows again.

enum Step { BUILD, START, SELECT, UPGRADE, WALLS, DONE }

const DEPTH: int = 120
const W: float = 440
const H: float = 54
const WALLS_SECONDS: float = 9.0 ## how long the last hint stays

const TEXT: Dictionary[Step, String] = {
	Step.BUILD: "Build a tower: click the grass beside the road and pick one\n(or pick a tower on the right, or press 1).",
	Step.START: "Start the first wave: press Space or the Start wave button.\nCalling waves early pays a bonus.",
	Step.SELECT: "Click one of your towers to see what it can do.",
	Step.UPGRADE: "Upgrade it (U). At level 3 it grows into one of two branches.",
	Step.WALLS: "Walls (Q) reshape the road and make the way longer.\nMore tricks drop down from Abilities on the right. Good luck!",
}

var step: Step = Step.BUILD
var skip_button: GameButton

var _host: GameScene
var _label: TextLabel
var _walls_left: float = WALLS_SECONDS


func _init(host: GameScene) -> void:
	_host = host
	position = Vector2((Config.FIELD_W - W) / 2, 4)
	size = Vector2(W, H)
	z_index = DEPTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_label = Ui.text(self, 14, H / 2, "", 13, Palette.TEXT, false, Vector2(0, 0.5))
	_label.set_line_spacing(2)
	skip_button = GameButton.new(Rect2(W - 64, (H - 26) / 2, 54, 26), "Skip", finish).font(12)
	add_child(skip_button)
	_show()


func _draw() -> void:
	Paint.fill_rounded_rect(self, 0, 3, W, size.y, 10, Color(0, 0, 0, 0.3))
	Paint.fill_rounded_rect(self, 0, 0, W, size.y, 10, Color(Palette.PANEL, 0.95))
	Paint.stroke_rounded_rect(self, 0, 0, W, size.y, 10, 2, Palette.GOLD)


## Called every frame: moves on once the player did what the hint asks.
func refresh(delta: float) -> void:
	if step == Step.DONE:
		return
	var world: World = _host.world
	var before: Step = step
	match step:
		Step.BUILD:
			if not world.towers.is_empty():
				step = Step.START
		Step.START:
			if world.wave_index >= 0:
				step = Step.SELECT
		Step.SELECT:
			if _host.selected != null:
				step = Step.UPGRADE
		Step.UPGRADE:
			for t: Tower in world.towers:
				if t.level > 0:
					step = Step.WALLS
		Step.WALLS:
			_walls_left -= delta
			if _walls_left <= 0 or not world.walls.is_empty():
				finish()
				return
	if step != before:
		_show()


## Ends the tutorial for good (also the Skip button).
func finish() -> void:
	step = Step.DONE
	visible = false
	var p: Profile = Profile.load_profile()
	if not p.tutorial_done:
		p.tutorial_done = true
		Profile.save_profile(p)


func _show() -> void:
	if _label != null and TEXT.has(step):
		_label.show_text(TEXT[step])
		_label.set_wrap(W - 90)
		# As tall as the hint needs, the text and the Skip button in the middle.
		var h: float = maxf(H, _label.size.y + 16)
		size.y = h
		_label.move_to(14, h / 2)
		skip_button.position.y = (h - skip_button.size.y) / 2
		queue_redraw()


## The hint showing now ("" when the tutorial is over).
func hint_text() -> String:
	return _label.text if visible and step != Step.DONE else ""
