class_name TechBadge
extends GameButton
## A round node of the tech tree for a tower or a branch: the tower in a ring
## that shows its state (owned: the tower's colour; can be bought: gold;
## locked: grey, with a padlock). Behaves like any GameButton.

var kind: String
var branch: String
var state: Profile.TechState = Profile.TechState.NEEDS_PARENTS


func _init(center: Vector2, radius: float, p_kind: String, p_branch: String, click: Callable) -> void:
	super(Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2), "", click)
	kind = p_kind
	branch = p_branch


func _ready() -> void:
	super()
	_label.visible = false


func set_state(value: Profile.TechState) -> void:
	if value != state:
		state = value
		queue_redraw()


func _draw() -> void:
	var r: float = size.x / 2
	var c := Vector2(r, r)
	var owned: bool = state == Profile.TechState.OWNED
	var buyable: bool = state == Profile.TechState.AVAILABLE
	var color: Color = Towers.get_def(kind).color
	if buyable:
		Paint.fill_circle(self, c.x, c.y, r + 6, Color(Palette.GOLD, 0.18))
	Paint.fill_circle(self, c.x, c.y + 3, r, Color(0, 0, 0, 0.35))
	Paint.fill_circle(self, c.x, c.y, r, Palette.PANEL_LIGHT if owned or buyable else Palette.PANEL)
	if _hover:
		Paint.fill_circle(self, c.x, c.y, r, Color(1, 1, 1, 0.08))
	var ring: Color = color if owned else (Palette.GOLD if buyable else Palette.BORDER)
	Paint.stroke_circle(self, c.x, c.y, r, 3.0 if owned or buyable else 1.5, ring)
	TowerArt.draw_icon(self, kind, c, r * 1.3, branch)
	if not owned:
		Paint.fill_circle(self, c.x, c.y, r - 2, Color(Palette.PANEL, 0.25 if buyable else 0.6)) # greyed out
	if not owned and not buyable:
		# A small padlock at the bottom right.
		var p: Vector2 = c + Vector2(r, r) * 0.62
		Paint.fill_circle(self, p.x, p.y, 10, Palette.PANEL)
		Paint.stroke_circle(self, p.x, p.y, 10, 1.5, Palette.BORDER)
		Paint.fill_rounded_rect(self, p.x - 4.5, p.y - 1.5, 9, 7, 2, Palette.TEXT_DIM)
		draw_arc(Vector2(p.x, p.y - 1.5), 3.2, PI, TAU, 8, Palette.TEXT_DIM, 1.6, true)
