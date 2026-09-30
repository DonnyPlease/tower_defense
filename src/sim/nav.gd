class_name Nav
extends RefCounted
## Moves one enemy through the map. Each enemy owns its own Nav.
## Base class of RouteNav and FlowNav; the methods below are overridden.

var x: float = 0.0
var y: float = 0.0
## Direction the enemy is walking in (radians).
var heading: float = 0.0


## Walks `step` pixels. Returns false once the enemy has left the map.
func move(_step: float) -> bool:
	assert(false, "Nav.move is abstract")
	return false


## Remaining path length to the exit, used for targeting.
func remaining() -> float:
	assert(false, "Nav.remaining is abstract")
	return 0.0


## Tile the enemy is heading to (maze levels only), or GameMap.NO_TILE.
func target_tile() -> Vector2i:
	return GameMap.NO_TILE


## Moves `dist` pixels back along the way the enemy came (splitters' children).
func fall_back(_dist: float) -> void:
	assert(false, "Nav.fall_back is abstract")


## Copy at the same spot (for splitters' children), with its own lane from `lane_seed`.
func clone(_lane_seed: int) -> Nav:
	assert(false, "Nav.clone is abstract")
	return null
