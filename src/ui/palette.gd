class_name Palette
extends RefCounted
## Colours shared by the UI and the renderer.


## Colour from a 0xRRGGBB value.
static func rgb(hex: int, alpha: float = 1.0) -> Color:
	return Color(((hex >> 16) & 0xFF) / 255.0, ((hex >> 8) & 0xFF) / 255.0, (hex & 0xFF) / 255.0, alpha)


const BACKGROUND: Color = Color("#14171f")
const PANEL: Color = Color("#1e2230")
const PANEL_LIGHT: Color = Color("#2a3042")
const PANEL_LIGHTER: Color = Color("#353d54")
const BORDER: Color = Color("#454f6b")
const GOLD: Color = Color("#f5c542")
const RED: Color = Color("#e5534b")
const GREEN: Color = Color("#57c26b")
const ACCENT: Color = Color("#4f8ef7")
const GRASS: Color = Color("#5d8f3b")
const GRASS_ALT: Color = Color("#659a41")
const PATH: Color = Color("#dcc594")
const PATH_EDGE: Color = Color("#b89f6b")
const HIGH: Color = Color("#86b25a")
const HIGH_EDGE_LIGHT: Color = Color("#a9cf7c")
const HIGH_EDGE_DARK: Color = Color("#4d7530")
const ROCK: Color = Color("#7b8088")
const ROCK_DARK: Color = Color("#555a61")
const WATER: Color = Color("#3a7bd5")
const WATER_LIGHT: Color = Color("#6fa8f0")
const BRIDGE: Color = Color("#9c6b3c")
const BRIDGE_DARK: Color = Color("#6e4a27")

# Text colours.
const TEXT: Color = Color("#e8ecf4")
const TEXT_DIM: Color = Color("#9aa3b8")
