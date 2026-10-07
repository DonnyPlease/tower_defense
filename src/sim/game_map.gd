class_name GameMap
extends RefCounted
## Map parsing, terrain, pathfinding and distance fields.
##
## Tiles are Vector2i(col, row). A map that fails validation has `error` set
## (GDScript has no exceptions); valid maps have an empty `error`.

enum Terrain { NONE = -1, GRASS, ROAD, HIGH, ROCK, WATER, BRIDGE }

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
## Distance-field value of tiles that can't reach an exit.
const UNREACHABLE: int = 1 << 30
## "No tile" (e.g. no target tile, or no direction yet).
const NO_TILE: Vector2i = Vector2i(-1, -1)

const TERRAIN_CHARS: Dictionary[String, Terrain] = {
	".": Terrain.GRASS, "#": Terrain.ROAD, "S": Terrain.ROAD, "E": Terrain.ROAD, "H": Terrain.HIGH,
	"R": Terrain.ROCK, "~": Terrain.WATER, "=": Terrain.BRIDGE,
}

const VERGE_COST: float = 2.0 # extra cost of a road tile next to the verge (divided by its clearance)
const MAX_LANE: float = 1.2 * Config.TILE # furthest an enemy walks from the middle of the road
const LANE_MARGIN: float = 14.0 # keep enemies' bodies this far inside the road edge
const FLIGHT_LANE: float = 1.2 * Config.TILE # flyers spread this far to either side


## Everything that only depends on the tiles, built once per distinct map.
class Shared:
	var paths: Array[PackedVector2Array] = [] ## tile path per start/end pair
	var routes: Array[Route] = []
	var flight_routes: Array[Route] = []
	var routes_built: bool = false


## Routes only depend on the tiles, and smoothing them takes a moment: build each map's once.
static var _shared: Dictionary[String, Shared] = {}
static var _shared_lock: Mutex = Mutex.new()

var name: String
## Enemies may also walk on grass and high ground (towers form the walls).
var maze: bool
## Enemies stay on the road, but walls can be built on it (see can_hold_wall).
var road_walls: bool
var starts: Array[Vector2i] = []
var ends: Array[Vector2i] = []
## Why the map is invalid, or "" for a valid map.
var error: String = ""
var _terrain: PackedInt32Array
var _walkable: PackedByteArray ## 1 where ground enemies may walk (ignoring towers)
var _key: String
# For every tile, the top-left corners of the unwalkable tiles among its 3 x 3
# neighbours, so clearance lookups during route smoothing are fast. Tile k's
# obstacles are at indices _obstacle_start[k] until _obstacle_end[k];
# _obstacle_start[k] is -1 if tile k itself is unwalkable.
var _obstacle_start: PackedInt32Array
var _obstacle_end: PackedInt32Array
var _obstacle_x0: PackedFloat64Array
var _obstacle_y0: PackedFloat64Array


func _init(p_name: String, tiles: PackedStringArray, p_maze: bool = false, p_road_walls: bool = false) -> void:
	name = p_name
	maze = p_maze
	road_walls = p_road_walls
	if tiles.size() != Config.ROWS or Array(tiles).any(func(r: String) -> bool: return r.length() != Config.COLS):
		error = 'Map "%s" must be %dx%d tiles' % [name, Config.COLS, Config.ROWS]
		return
	_terrain.resize(Config.COLS * Config.ROWS)
	for r: int in Config.ROWS:
		for c: int in Config.COLS:
			var ch: String = tiles[r][c]
			if not TERRAIN_CHARS.has(ch):
				error = "Map \"%s\": unknown tile '%s' at %d,%d" % [name, ch, c, r]
				return
			_terrain[r * Config.COLS + c] = TERRAIN_CHARS[ch]
			if ch == "S":
				starts.append(Vector2i(c, r))
			if ch == "E":
				ends.append(Vector2i(c, r))
	_walkable.resize(Config.COLS * Config.ROWS)
	for k: int in _terrain.size():
		_walkable[k] = 1 if _is_walkable_terrain(_terrain[k] as Terrain) else 0
	if starts.is_empty() or ends.is_empty():
		error = 'Map "%s" needs at least one S and one E tile' % name
		return
	_key = "\n".join(tiles) + ("m" if maze else "") + ("w" if road_walls else "")
	_shared_lock.lock()
	var shared: Shared = _shared.get(_key)
	if shared == null:
		shared = Shared.new()
		for s: Vector2i in starts:
			for e: Vector2i in ends:
				var path: PackedVector2Array = find_path(s, e)
				if path.is_empty():
					error = 'Map "%s": no path from S to E' % name
					_shared_lock.unlock()
					return
				shared.paths.append(path)
		_shared[_key] = shared
	_shared_lock.unlock()


## Whether enemies re-route when something is built (maze and wall levels):
## they steer with the flow field instead of following a fixed route.
var flow: bool:
	get:
		return maze or road_walls


## Road levels: one smooth route along the middle of the road per start/end pair.
## Built on first use (it takes a moment) and shared by all maps with these tiles.
var routes: Array[Route]:
	get:
		return _shared_routes().routes


## Nearly straight routes for flying enemies, one per start/end pair.
var flight_routes: Array[Route]:
	get:
		return _shared_routes().flight_routes


func _shared_routes() -> Shared:
	_shared_lock.lock()
	var shared: Shared = _shared.get(_key)
	if shared != null and not shared.routes_built:
		var i: int = 0
		for s: Vector2i in starts:
			for e: Vector2i in ends:
				var path: PackedVector2Array = shared.paths[i]
				i += 1
				var pts := Route.Polyline.new()
				var start: Vector2 = outside(s)
				pts.add(start.x, start.y)
				for t: Vector2 in path:
					pts.add(t.x * Config.TILE + Config.TILE * 0.5, t.y * Config.TILE + Config.TILE * 0.5)
				var finish: Vector2 = outside(e)
				pts.add(finish.x, finish.y)
				# Levels with walls steer with the flow field instead, so skip the smoothing.
				shared.routes.append(Route.new(pts, _road_width, Callable() if flow else _clearance_at))
				var flight := Route.Polyline.new()
				flight.add(start.x, start.y)
				flight.add(s.x * Config.TILE + Config.TILE * 0.5, s.y * Config.TILE + Config.TILE * 0.5)
				flight.add(e.x * Config.TILE + Config.TILE * 0.5, e.y * Config.TILE + Config.TILE * 0.5)
				flight.add(finish.x, finish.y)
				shared.flight_routes.append(Route.new(flight, _flight_width))
		shared.routes_built = true
	_shared_lock.unlock()
	if shared == null:
		return Shared.new()
	return shared


## Identifies the map's tiles and flags: maps with the same key are the same.
func key() -> String:
	return _key


## Builds this map's routes now (e.g. on a background thread while a menu is open).
func warm_up() -> void:
	_shared_routes()


static func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * Config.TILE + Config.TILE * 0.5, t.y * Config.TILE + Config.TILE * 0.5)


static func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < Config.COLS and row >= 0 and row < Config.ROWS


func terrain_at(col: int, row: int) -> Terrain:
	if not in_bounds(col, row):
		return Terrain.NONE
	return _terrain[row * Config.COLS + col] as Terrain


## Drawn as road (road or bridge).
func is_road(col: int, row: int) -> bool:
	var t: Terrain = terrain_at(col, row)
	return t == Terrain.ROAD or t == Terrain.BRIDGE


func is_buildable_terrain(col: int, row: int) -> bool:
	var t: Terrain = terrain_at(col, row)
	return t == Terrain.GRASS or t == Terrain.HIGH


func is_high_ground(col: int, row: int) -> bool:
	return terrain_at(col, row) == Terrain.HIGH


## Where enemies enter or leave the map (these can never be built on).
func is_gate(col: int, row: int) -> bool:
	var t := Vector2i(col, row)
	return starts.has(t) or ends.has(t)


## Whether a wall may stand here: on grass and high ground, and on the road
## of levels where enemies re-route (but never on the tiles where they enter
## and leave). Whether it is allowed right now also depends on the path (World).
func can_hold_wall(col: int, row: int) -> bool:
	if is_buildable_terrain(col, row):
		return true
	return flow and terrain_at(col, row) == Terrain.ROAD and not is_gate(col, row)


## Whether ground enemies may walk here, ignoring towers.
func is_walkable(col: int, row: int) -> bool:
	return in_bounds(col, row) and _walkable[row * Config.COLS + col] != 0


func _is_walkable_terrain(t: Terrain) -> bool:
	if t == Terrain.ROAD or t == Terrain.BRIDGE:
		return true
	return maze and (t == Terrain.GRASS or t == Terrain.HIGH)


## BFS distance field from all exits over walkable tiles, as a flat
## COLS x ROWS array (see dist_at); UNREACHABLE where no exit can be reached.
## `blocked` marks extra obstacles (towers in maze levels): a non-zero byte
## per tile, or an empty array for none.
func distance_field(blocked: PackedByteArray = PackedByteArray(), exits: Array[Vector2i] = []) -> PackedInt32Array:
	var n: int = Config.COLS * Config.ROWS
	var cols: int = Config.COLS
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(UNREACHABLE)
	var sources: Array[Vector2i] = exits if not exits.is_empty() else ends
	# Every tile enters the queue at most once (plus possibly repeated exits).
	var queue := PackedInt32Array()
	queue.resize(n + sources.size())
	var tail: int = 0
	for e: Vector2i in sources:
		var k: int = e.y * cols + e.x
		dist[k] = 0
		queue[tail] = k
		tail += 1
	var has_blocked: bool = not blocked.is_empty()
	var walk: PackedByteArray = _walkable
	var head: int = 0
	while head < tail:
		var k: int = queue[head]
		head += 1
		var d: int = dist[k] + 1
		var c: int = k % cols
		# Right, down, left, up (unrolled: this runs a lot while planning mazes).
		var nk: int = k + 1
		if c + 1 < cols and walk[nk] != 0 and dist[nk] == UNREACHABLE and not (has_blocked and blocked[nk] != 0):
			dist[nk] = d
			queue[tail] = nk
			tail += 1
		nk = k + cols
		if nk < n and walk[nk] != 0 and dist[nk] == UNREACHABLE and not (has_blocked and blocked[nk] != 0):
			dist[nk] = d
			queue[tail] = nk
			tail += 1
		nk = k - 1
		if c > 0 and walk[nk] != 0 and dist[nk] == UNREACHABLE and not (has_blocked and blocked[nk] != 0):
			dist[nk] = d
			queue[tail] = nk
			tail += 1
		nk = k - cols
		if nk >= 0 and walk[nk] != 0 and dist[nk] == UNREACHABLE and not (has_blocked and blocked[nk] != 0):
			dist[nk] = d
			queue[tail] = nk
			tail += 1
	return dist


## Value of a distance field at a tile; UNREACHABLE off the map.
static func dist_at(dist: PackedInt32Array, col: int, row: int) -> int:
	if not in_bounds(col, row):
		return UNREACHABLE
	return dist[row * Config.COLS + col]


## Next tile towards the exit, following the distance field and preferring
## to keep going in direction `dir` (fewer turns; NO_TILE for none). NO_TILE
## at an exit or when the tile can't reach one.
static func next_tile(dist: PackedInt32Array, cur: Vector2i, dir: Vector2i) -> Vector2i:
	var d: int = dist_at(dist, cur.x, cur.y)
	if d == 0 or d == UNREACHABLE:
		return NO_TILE # at the exit, or cut off from it
	if dir != NO_TILE:
		var c: int = cur.x + dir.x
		var r: int = cur.y + dir.y
		if dist_at(dist, c, r) == d - 1:
			return Vector2i(c, r)
	for o: Vector2i in DIRS:
		var c: int = cur.x + o.x
		var r: int = cur.y + o.y
		if dist_at(dist, c, r) == d - 1:
			return Vector2i(c, r)
	return NO_TILE


## Path of tiles from `start` to the exit `end` that is short but keeps to
## the middle of wide roads (tiles next to the verge cost more). Empty if
## there is none.
func find_path(start: Vector2i, end: Vector2i) -> PackedVector2Array:
	var n: int = Config.COLS * Config.ROWS
	var clear: PackedInt32Array = _clearance()
	var cost := PackedFloat64Array()
	cost.resize(n)
	cost.fill(INF)
	var done := PackedByteArray()
	done.resize(n)
	cost[end.y * Config.COLS + end.x] = 0.0
	while true:
		var cur: int = -1
		for k: int in n:
			if done[k] == 0 and cost[k] < INF and (cur < 0 or cost[k] < cost[cur]):
				cur = k
		if cur < 0:
			break
		done[cur] = 1
		var cc: int = cur % Config.COLS
		@warning_ignore("integer_division")
		var cr: int = cur / Config.COLS
		for dir: Vector2i in DIRS:
			var c: int = cc + dir.x
			var r: int = cr + dir.y
			if not is_walkable(c, r):
				continue
			var k: int = r * Config.COLS + c
			# A tile with no unwalkable tile anywhere has infinite clearance: no verge cost.
			var verge: float = 0.0 if clear[k] == UNREACHABLE else VERGE_COST / clear[k]
			var d: float = cost[cur] + 1 + verge
			if d < cost[k]:
				cost[k] = d
	if cost[start.y * Config.COLS + start.x] == INF:
		return PackedVector2Array()
	var tiles := PackedVector2Array([Vector2(start)])
	var at: Vector2i = start
	while at != end:
		var best: Vector2i = NO_TILE
		for dir: Vector2i in DIRS:
			var c: int = at.x + dir.x
			var r: int = at.y + dir.y
			if in_bounds(c, r) and (best == NO_TILE or cost[r * Config.COLS + c] < cost[best.y * Config.COLS + best.x]):
				best = Vector2i(c, r)
		at = best
		tiles.append(Vector2(at))
	return tiles


## For every tile, how many steps (8 directions) to the nearest unwalkable tile.
func _clearance() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(Config.COLS * Config.ROWS)
	out.fill(UNREACHABLE)
	var queue: Array[Vector2i] = []
	for r: int in Config.ROWS:
		for c: int in Config.COLS:
			if not is_walkable(c, r):
				out[r * Config.COLS + c] = 0
				queue.append(Vector2i(c, r))
	var i: int = 0
	while i < queue.size():
		var cur: Vector2i = queue[i]
		i += 1
		for dr: int in range(-1, 2):
			for dc: int in range(-1, 2):
				var c: int = cur.x + dc
				var r: int = cur.y + dr
				if in_bounds(c, r) and out[r * Config.COLS + c] == UNREACHABLE:
					out[r * Config.COLS + c] = out[cur.y * Config.COLS + cur.x] + 1
					queue.append(Vector2i(c, r))
	return out


## Distance (pixels) from (x, y) to the nearest unwalkable tile; negative inside one.
## Only the 3 x 3 tiles around (x, y) count (further ones are beyond MARGIN anyway).
func _clearance_at(x: float, y: float) -> float:
	if _obstacle_start.is_empty():
		_build_obstacles()
	var col: int = mini(Config.COLS - 1, maxi(0, floori(x / Config.TILE)))
	var row: int = mini(Config.ROWS - 1, maxi(0, floori(y / Config.TILE)))
	var k: int = row * Config.COLS + col
	var start: int = _obstacle_start[k]
	if start < 0:
		return -1.0 # inside an unwalkable tile
	var best: float = INF
	for j: int in range(start, _obstacle_end[k]):
		var x0: float = _obstacle_x0[j]
		var y0: float = _obstacle_y0[j]
		var dx: float = maxf(maxf(x0 - x, 0.0), x - (x0 + Config.TILE))
		var dy: float = maxf(maxf(y0 - y, 0.0), y - (y0 + Config.TILE))
		best = minf(best, sqrt(dx * dx + dy * dy))
	return best



func _build_obstacles() -> void:
	_obstacle_start.resize(Config.COLS * Config.ROWS)
	_obstacle_end.resize(Config.COLS * Config.ROWS)
	for row: int in Config.ROWS:
		for col: int in Config.COLS:
			var k: int = row * Config.COLS + col
			if not is_walkable(col, row):
				_obstacle_start[k] = -1
				continue
			_obstacle_start[k] = _obstacle_x0.size()
			for r: int in range(row - 1, row + 2):
				for c: int in range(col - 1, col + 2):
					if in_bounds(c, r) and not is_walkable(c, r):
						_obstacle_x0.append(c * Config.TILE)
						_obstacle_y0.append(r * Config.TILE)
			_obstacle_end[k] = _obstacle_x0.size()


## How far (pixels) an enemy may stray from (x, y) in direction (nx, ny) and
## still walk on the road. Off the map, the nearest border tile counts.
func _road_width(x: float, y: float, nx: float, ny: float) -> float:
	var ok: float = 0.0
	var o: float = 2.0
	while o <= MAX_LANE + LANE_MARGIN:
		var col: int = mini(Config.COLS - 1, maxi(0, floori((x + nx * o) / Config.TILE)))
		var row: int = mini(Config.ROWS - 1, maxi(0, floori((y + ny * o) / Config.TILE)))
		if not is_walkable(col, row):
			break
		ok = o
		o += 2.0
	return maxf(0.0, minf(MAX_LANE, ok - LANE_MARGIN))


static func _flight_width(_x: float, _y: float, _nx: float, _ny: float) -> float:
	return FLIGHT_LANE


## Direction pointing off the map from a border tile.
static func outward(t: Vector2i) -> Vector2i:
	if t.x == 0:
		return Vector2i(-1, 0)
	if t.x == Config.COLS - 1:
		return Vector2i(1, 0)
	if t.y == 0:
		return Vector2i(0, -1)
	if t.y == Config.ROWS - 1:
		return Vector2i(0, 1)
	return Vector2i(0, 0)


## Centre of the tile just outside the map next to a border tile.
static func outside(t: Vector2i) -> Vector2:
	return tile_center(t + outward(t))
