class_name Minimap
extends RefCounted
## Small picture of a map (level-select cards).


static func draw(ci: CanvasItem, map: GameMap, x: float, y: float, tile: float) -> void:
	for r: int in Config.ROWS:
		for c: int in Config.COLS:
			var color: Color
			match map.terrain_at(c, r):
				GameMap.Terrain.ROAD:
					color = Palette.PATH
				GameMap.Terrain.HIGH:
					color = Palette.HIGH
				GameMap.Terrain.ROCK:
					color = Palette.ROCK
				GameMap.Terrain.WATER:
					color = Palette.WATER
				GameMap.Terrain.BRIDGE:
					color = Palette.BRIDGE
				_:
					color = Palette.GRASS if (r + c) % 2 == 1 else Palette.GRASS_ALT
			ci.draw_rect(Rect2(x + c * tile, y + r * tile, tile, tile), color)
	ci.draw_rect(Rect2(x, y, Config.COLS * tile, Config.ROWS * tile), Color(0, 0, 0, 0.4), false, 1.0)
