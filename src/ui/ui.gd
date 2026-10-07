class_name Ui
extends RefCounted
## Fonts, the theme and text helpers shared by all screens.

const SYMBOL_FONTS: Array[String] = [
	"res://assets/fonts/NotoSansSymbols2-subset.ttf", # ★ ☆ ♥ ▶ ✓ 🔒
	"res://assets/fonts/NotoSansSymbols-subset.ttf", # ♪
]

static var _regular: Font
static var _bold: Font
static var _theme: Theme


## The UI font: Godot's default font, with symbol fonts for the few glyphs it lacks.
static func regular() -> Font:
	if _regular == null:
		var fallbacks: Array[Font] = []
		for path: String in SYMBOL_FONTS:
			var font: FontFile = load(path)
			if font != null:
				fallbacks.append(font)
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.fallbacks = fallbacks
		_regular = f
	return _regular


static func bold() -> Font:
	if _bold == null:
		var f := FontVariation.new()
		f.base_font = regular()
		f.variation_embolden = 0.6
		_bold = f
	return _bold


## The project-wide theme (set on the root window by the Router).
static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = regular()
		_theme.default_font_size = 16
	return _theme


## A text label placed like Phaser text: `origin` (0..1 on each axis) of its
## box is at (x, y). With `wrap` > 0 the text wraps at that width.
static func text(parent: Node, x: float, y: float, content: String, font_size: int = 16,
		color: Color = Palette.TEXT, is_bold: bool = false, origin: Vector2 = Vector2.ZERO) -> TextLabel:
	var label := TextLabel.new()
	var settings := LabelSettings.new()
	settings.font = bold() if is_bold else regular()
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	label.at = Vector2(x, y)
	label.origin = origin
	if origin.x == 0.5:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif origin.x == 1.0:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(label)
	label.show_text(content)
	return label
