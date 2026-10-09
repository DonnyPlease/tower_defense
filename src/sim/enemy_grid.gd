class_name EnemyGrid
extends RefCounted
## A bucket grid over the field that finds the enemies near a point quickly,
## so towers and bullets don't have to look at every enemy on the map (the
## cost of a tick then grows with the number of enemies near each tower, not
## with all of them).
##
## The world rebuilds it every tick once enemies have moved (rebuild()), and
## adds the enemies that appear later in the same tick (add(): splitters'
## children, a boss's escort). Queries return indices into the world's
## `enemies` array in increasing order, so code that walks the result behaves
## exactly like code that walks the whole array.

const CELL: float = 2.0 * Config.TILE
## The grid reaches this far beyond the field (enemies enter and leave from outside).
const MARGIN: float = Config.TILE * 2.0
const COLS: int = ceili((Config.FIELD_W + 2 * MARGIN) / CELL)
const ROWS: int = ceili((Config.FIELD_H + 2 * MARGIN) / CELL)

## Largest enemy radius in the grid: queries grow by it, as enemies are hit at their edge.
var max_radius: float = 0.0

var _enemies: Array[Enemy] = []
# Counting-sort layout: the enemies of cell k are _items[_start[k] .. _start[k] + _count[k]).
var _start := PackedInt32Array()
var _count := PackedInt32Array()
var _items := PackedInt32Array()
# Enemies added after the last rebuild (few). Their cell is worked out when
# asked, so they may still be moved into place after being added.
var _extra := PackedInt32Array()


func _init() -> void:
	_start.resize(COLS * ROWS)
	_count.resize(COLS * ROWS)


static func _col(x: float) -> int:
	return clampi(floori((x + MARGIN) / CELL), 0, COLS - 1)


static func _row(y: float) -> int:
	return clampi(floori((y + MARGIN) / CELL), 0, ROWS - 1)


## Buckets all enemies by position (O(n)).
func rebuild(enemies: Array[Enemy]) -> void:
	_enemies = enemies
	var n: int = enemies.size()
	_count.fill(0)
	_extra.clear()
	max_radius = 0.0
	var cells := PackedInt32Array()
	cells.resize(n)
	for i: int in n:
		var e: Enemy = enemies[i]
		var k: int = _row(e.y) * COLS + _col(e.x)
		cells[i] = k
		_count[k] += 1
		max_radius = maxf(max_radius, e.radius)
	var at: int = 0
	for k: int in _count.size():
		_start[k] = at
		at += _count[k]
	_items.resize(n)
	var fill := _start.duplicate()
	for i: int in n:
		var k: int = cells[i]
		_items[fill[k]] = i
		fill[k] += 1


## Adds the enemy at `index` of the array given to rebuild() (appended since).
func add(index: int) -> void:
	_extra.append(index)
	max_radius = maxf(max_radius, _enemies[index].radius)


## Indices (increasing) of the enemies whose cell overlaps the rectangle
## (x0, y0)-(x1, y1). Callers still check the exact distance.
func query(x0: float, y0: float, x1: float, y1: float) -> PackedInt32Array:
	var c0: int = _col(x0)
	var c1: int = _col(x1)
	var r0: int = _row(y0)
	var r1: int = _row(y1)
	var out := PackedInt32Array()
	for r: int in range(r0, r1 + 1):
		# The cells of a row are next to each other in _items: one slice per row.
		var first: int = r * COLS + c0
		var last: int = r * COLS + c1
		var from: int = _start[first]
		var to: int = _start[last] + _count[last]
		if to > from:
			out.append_array(_items.slice(from, to))
	for i: int in _extra:
		var e: Enemy = _enemies[i]
		var c: int = _col(e.x)
		var r: int = _row(e.y)
		if c >= c0 and c <= c1 and r >= r0 and r <= r1:
			out.append(i)
	out.sort()
	return out


## Enemies that may be within `reach` (plus their radius) of (x, y).
func near(x: float, y: float, reach: float) -> PackedInt32Array:
	var d: float = reach + max_radius
	return query(x - d, y - d, x + d, y + d)


## The enemies at `indices`, in that order.
func pick(indices: PackedInt32Array) -> Array[Enemy]:
	var out: Array[Enemy] = []
	out.resize(indices.size())
	for j: int in indices.size():
		out[j] = _enemies[indices[j]]
	return out
