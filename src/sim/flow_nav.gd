class_name FlowNav
extends Nav
## Walks tile by tile down a shared distance field that the world recomputes
## whenever towers change (maze levels), so enemies re-route around new walls.
## Enemies steer like vehicles: they start the next turn before reaching a
## tile's centre, turn at a limited rate and slow down for sharp turns.

const TURN_RADIUS: float = 0.3 * Config.TILE # tightest turn when walking at full speed
const ADVANCE: float = 0.45 * Config.TILE # head for the next tile once this close to the current one
const AIM_JITTER: float = 0.18 * Config.TILE # how far from tile centres each enemy walks

var _map: GameMap
var _field: FlowField
var _tile: Vector2i
var _dir: Vector2i
var _target_x: float
var _target_y: float
var _exiting: bool = false
var _ax: float # this enemy's aim offset from tile centres
var _seen_version: int # the field's version when the next tile was picked
var _ay: float


func _init(map: GameMap, field: FlowField, tile: Vector2i, lane_seed: int, dir: Vector2i = GameMap.NO_TILE,
		from: FlowNav = null) -> void:
	_map = map
	_field = field
	_seen_version = field.version
	_tile = tile
	_dir = dir
	_ax = (MathX.hash01(lane_seed, 5) * 2 - 1) * AIM_JITTER
	_ay = (MathX.hash01(lane_seed, 6) * 2 - 1) * AIM_JITTER
	if from != null:
		x = from.x
		y = from.y
		heading = from.heading
		_exiting = from._exiting
		if _exiting:
			_target_x = from._target_x
			_target_y = from._target_y
		else:
			_aim(tile)
	else:
		var start: Vector2 = GameMap.outside(tile)
		x = start.x
		y = start.y
		_aim(tile)
		heading = atan2(_target_y - y, _target_x - x)


func target_tile() -> Vector2i:
	return GameMap.NO_TILE if _exiting else _tile


func _aim(t: Vector2i) -> void:
	_target_x = t.x * Config.TILE + Config.TILE * 0.5 + _ax
	_target_y = t.y * Config.TILE + Config.TILE * 0.5 + _ay


## Picks the next tile. Returns false when there is nowhere to go (cut off).
func _advance() -> bool:
	var dist: PackedInt32Array = _field.dist
	var next: Vector2i = GameMap.next_tile(dist, _tile, _dir)
	if next == GameMap.NO_TILE:
		if GameMap.dist_at(dist, _tile.x, _tile.y) != 0:
			return false # cut off: should not happen, wait
		_exiting = true
		var out: Vector2 = GameMap.outside(_tile)
		_target_x = out.x + _ax
		_target_y = out.y + _ay
		return true
	_dir = next - _tile
	_tile = next
	_aim(next)
	return true


## Towers or walls changed: if a neighbour of the tile the enemy stands on is
## now a better step than the tile it is walking to (a wall was sold and a
## shorter way opened, say), turn towards it at once instead of first walking
## on to the old tile and turning back.
func _replan() -> void:
	_seen_version = _field.version
	if _exiting:
		return
	var dist: PackedInt32Array = _field.dist
	var here := Vector2i(floori(x / Config.TILE), floori(y / Config.TILE))
	var d_here: int = GameMap.dist_at(dist, here.x, here.y)
	if here == _tile or d_here == GameMap.UNREACHABLE or d_here == 0:
		return
	var next: Vector2i = GameMap.next_tile(dist, here, _tile - here if (_tile - here).length_squared() == 1 else _dir)
	if next == GameMap.NO_TILE or next == _tile:
		return
	if GameMap.dist_at(dist, next.x, next.y) >= GameMap.dist_at(dist, _tile.x, _tile.y):
		return # the old step is as good
	_dir = next - here
	_tile = next
	_aim(next)


func move(step: float) -> bool:
	if step <= 0:
		return true
	if _seen_version != _field.version:
		_replan()
	var d: float = MathX.hypot(_target_x - x, _target_y - y)
	if _exiting:
		if d <= step:
			return false
	elif d < ADVANCE:
		if not _advance():
			# Nowhere to go: walk onto the tile and wait.
			var k: float = minf(1.0, step / (d if d != 0.0 else 1.0))
			x += (_target_x - x) * k
			y += (_target_y - y) * k
			return true
		d = MathX.hypot(_target_x - x, _target_y - y)
	var want: float = atan2(_target_y - y, _target_x - x)
	var diff: float = MathX.angle_diff(heading, want)
	var max_turn: float = step / TURN_RADIUS
	heading += maxf(-max_turn, minf(max_turn, diff))
	# Slow down while facing away from the target, like a vehicle turning.
	var off: float = MathX.angle_diff(heading, want)
	var forward: float = minf(d, step * maxf(0.25, cos(off)))
	x += cos(heading) * forward
	y += sin(heading) * forward
	return true


func fall_back(dist: float) -> void:
	x -= cos(heading) * dist
	y -= sin(heading) * dist


func remaining() -> float:
	var to_target: float = MathX.hypot(_target_x - x, _target_y - y)
	if _exiting:
		return to_target
	var d: int = GameMap.dist_at(_field.dist, _tile.x, _tile.y)
	var tiles: float = float(d) / _field.unit if d != GameMap.UNREACHABLE else 99.0
	return to_target + tiles * Config.TILE + Config.TILE


func clone(lane_seed: int) -> Nav:
	return FlowNav.new(_map, _field, _tile, lane_seed, _dir, self)
