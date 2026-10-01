class_name BalancePlayers
extends RefCounted
## Simulated players used to measure how hard each level is.
##
## - play_expert: a parameterised greedy strategy. search_expert tunes its
##   parameters per level, which approximates the best possible play.
## - play_human: a human-like player with a skill level from 0 (novice) to 1.
##   It places towers imperfectly, picks tower types semi-randomly and does
##   not always spend its money well. Run it with many seeds for a win rate.
##
## Every random draw happens in the same order as in the original TypeScript
## version, and sorts are stable like JavaScript's, so the results match it.

const NO_LIMIT: int = 1 << 30


# ---- helpers -------------------------------------------------------------------

## Result of one simulated game.
class GameResult:
	var won: bool
	var lives: int
	var start_lives: int
	var waves_cleared: int


## A candidate build spot.
class Spot:
	var col: int
	var row: int
	var score: float
	var order: int ## position before the latest sort (for stable sorting)

	func _init(p_col: int, p_row: int, p_score: float) -> void:
		col = p_col
		row = p_row
		score = p_score


## Road tiles of each map (they never change), by map key.
static var _road_tiles: Dictionary[String, Array] = {}


## Tiles enemies currently walk on (maze levels follow the live flow field).
static func path_tiles(w: World) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not w.map.maze:
		if not _road_tiles.has(w.map.key()):
			for r: int in Config.ROWS:
				for c: int in Config.COLS:
					if w.map.is_road(c, r):
						out.append(Vector2i(c, r))
			_road_tiles[w.map.key()] = out
		out.assign(_road_tiles[w.map.key()])
		return out
	var seen: Dictionary[Vector2i, bool] = {}
	for s: Vector2i in w.map.starts:
		var cur: Vector2i = s
		while cur != GameMap.NO_TILE and not seen.has(cur):
			seen[cur] = true
			out.append(cur)
			cur = GameMap.next_tile(w.distance_field, cur, GameMap.NO_TILE)
	return out


## A cached coverage grid and the path it was made for.
class CoverageEntry:
	var path: Array[Vector2i]
	var reach: float
	var grid: PackedInt32Array


## Coverage grids by a hash of (path, range); the same ones come up again and again.
static var _coverage_cache: Dictionary[int, CoverageEntry] = {}


## How many path tiles are within `reach` of every tile (flat COLS x ROWS).
static func coverage_grid(path: Array[Vector2i], reach: float) -> PackedInt32Array:
	var key: int = hash([path.hash(), reach])
	var entry: CoverageEntry = _coverage_cache.get(key)
	if entry != null and entry.reach == reach and entry.path == path:
		return entry.grid
	var grid := PackedInt32Array()
	grid.resize(Config.COLS * Config.ROWS)
	# Every path tile counts for the tiles within reach of it (a disc of offsets).
	var r: int = ceili(reach / Config.TILE)
	var offsets: Array[Vector2i] = []
	for dr: int in range(-r, r + 1):
		for dc: int in range(-r, r + 1):
			if MathX.hypot(dc, dr) * Config.TILE <= reach:
				offsets.append(Vector2i(dc, dr))
	for t: Vector2i in path:
		for o: Vector2i in offsets:
			var c: int = t.x + o.x
			var rr: int = t.y + o.y
			if GameMap.in_bounds(c, rr):
				grid[rr * Config.COLS + c] += 1
	if _coverage_cache.size() > 4000:
		_coverage_cache.clear()
	entry = CoverageEntry.new()
	entry.path = path.duplicate()
	entry.reach = reach
	entry.grid = grid
	_coverage_cache[key] = entry
	return grid


## Number of path tiles within `reach` of (col, row).
static func coverage(path: Array[Vector2i], col: int, row: int, reach: float) -> int:
	return coverage_grid(path, reach)[row * Config.COLS + col]


## Rough damage output of a tower level, used to value purchases.
static func power(kind: String, level: int, vs_armor: float = 0.0) -> float:
	var d: TowerDef = Towers.get_def(kind)
	var s: TowerLevel = d.levels[level]
	var hit: float = s.damage if d.ignores_armor else maxf(s.damage * 0.25, s.damage - vs_armor)
	match d.behavior:
		Towers.Behavior.PROJECTILE:
			return hit * s.fire_rate * (2.2 if s.splash > 0 else 1.0)
		Towers.Behavior.BEAM:
			return hit * 2
		Towers.Behavior.AURA:
			return hit * s.fire_rate + 25 * s.slow
	return 0.0


static func _shortest_start(w: World, dist: PackedInt32Array) -> int:
	var best: int = GameMap.UNREACHABLE
	for s: Vector2i in w.map.starts:
		best = mini(best, GameMap.dist_at(dist, s.x, s.y))
	return best


## How many tiles longer the enemies' walk gets if (col, row) is blocked (maze levels).
static func _maze_gain(w: World, col: int, row: int) -> float:
	var before: int = _shortest_start(w, w.distance_field)
	var mask := PackedByteArray()
	mask.resize(Config.COLS * Config.ROWS)
	for t: Tower in w.towers:
		mask[t.row * Config.COLS + t.col] = 1
	mask[row * Config.COLS + col] = 1
	var after: int = _shortest_start(w, w.map.distance_field(mask))
	return float(after - before) if after != GameMap.UNREACHABLE else -100.0


## Sorts by score, best first, keeping the current order of equal scores (like JavaScript).
static func _sort_spots(spots: Array[Spot]) -> void:
	for i: int in spots.size():
		spots[i].order = i
	spots.sort_custom(func(a: Spot, b: Spot) -> bool:
		return a.score > b.score or (a.score == b.score and a.order < b.order))


## Candidate build spots for a tower kind, best first.
static func rank_spots(w: World, kind: String, path: Array[Vector2i], maze_weight: float) -> Array[Spot]:
	var spots: Array[Spot] = []
	var support: bool = kind == "support"
	var base_range: float = Towers.get_def(kind).levels[0].attack_range
	var high_range: float = base_range * Config.HIGH_GROUND_RANGE
	var low_grid: PackedInt32Array = PackedInt32Array() if support else coverage_grid(path, base_range)
	var high_grid: PackedInt32Array = PackedInt32Array() if support else coverage_grid(path, high_range)
	for r: int in Config.ROWS:
		for c: int in Config.COLS:
			if not w.map.is_buildable_terrain(c, r) or w.tower_at(c, r) != null:
				continue
			var high: bool = w.map.is_high_ground(c, r)
			var reach: float = high_range if high else base_range
			var score: float
			if support:
				var n: int = 0
				for t: Tower in w.towers:
					if t.def.behavior != Towers.Behavior.SUPPORT and \
							MathX.hypot(t.x - (c * Config.TILE + 20), t.y - (r * Config.TILE + 20)) <= reach:
						n += 1
				score = n
			else:
				score = (high_grid if high else low_grid)[r * Config.COLS + c]
			if score > 0:
				spots.append(Spot.new(c, r, score))
	_sort_spots(spots)
	# Maze levels: also value making the path longer. That needs a path search
	# per spot, so only the most promising spots are checked.
	if w.map.maze and kind != "support" and maze_weight > 0:
		for i: int in mini(30, spots.size()):
			spots[i].score += maze_weight * _maze_gain(w, spots[i].col, spots[i].row)
		_sort_spots(spots)
	return spots


## Share of flying enemies in the next wave, and whether it has armored ones.
class Threat:
	var air: float = 0.0
	var armored: bool = false


static func next_wave_threat(w: World) -> Threat:
	var total: int = 0
	var air: int = 0
	var armor: int = 0
	var wave: Wave = w.next_wave()
	if wave != null:
		for g: SpawnGroup in wave.groups:
			total += g.count
			if g.type == "drone":
				air += g.count
			if g.type == "armored" or g.type == "boss":
				armor += g.count
	var t := Threat.new()
	t.air = float(air) / total if total > 0 else 0.0
	t.armored = armor > 0
	return t


static func result_of(w: World) -> GameResult:
	var r := GameResult.new()
	r.won = w.status == World.Status.WON
	r.lives = w.lives
	r.start_lives = w.start_lives
	r.waves_cleared = w.waves_cleared
	return r


## Plays until the game ends (or `max_waves` are cleared); `before_wave(w)` spends money.
static func run(w: World, before_wave: Callable, max_waves: int, call_early: bool = false) -> GameResult:
	var i: int = 0
	while i < 3_000_000 and w.status == World.Status.PLAYING and w.waves_cleared < max_waves:
		if not w.wave_in_progress():
			before_wave.call(w)
			w.start_next_wave()
		elif call_early and w.can_start_wave() and w.enemies.size() <= 2:
			before_wave.call(w)
			w.start_next_wave()
		w.update()
		i += 1
	return result_of(w)


# ---- expert ----------------------------------------------------------------------

class ExpertParams:
	var weights: Dictionary[String, float] = {} ## preference multiplier per tower
	var upgrade_bias: float ## multiplier on the value of upgrades
	var diversity: float ## 0..1, penalty for building the same tower again
	var maze_weight: float ## maze levels: how much to value lengthening the path
	var armor_aware: bool ## value damage against armored enemies
	var call_early: bool ## call waves early for the bonus

	func copy() -> ExpertParams:
		var q := ExpertParams.new()
		q.weights = weights.duplicate()
		q.upgrade_bias = upgrade_bias
		q.diversity = diversity
		q.maze_weight = maze_weight
		q.armor_aware = armor_aware
		q.call_early = call_early
		return q

	func describe() -> String:
		var parts: PackedStringArray = []
		for k: String in Towers.KINDS:
			parts.append("%s %.2f" % [k, weights[k]])
		return "%s; upgrades %.2f, diversity %.2f, maze %.2f, armor %s, early %s" % [
			", ".join(parts), upgrade_bias, diversity, maze_weight, armor_aware, call_early]


static func default_expert() -> ExpertParams:
	var p := ExpertParams.new()
	for k: String in Towers.KINDS:
		p.weights[k] = 1.0
	p.upgrade_bias = 1.1
	p.diversity = 0.1
	p.maze_weight = 0.6
	p.armor_aware = true
	p.call_early = false
	return p


## Makes the purchase worth the most; false when nothing is worth buying.
static func _expert_buy(w: World, p: ExpertParams) -> bool:
	var path: Array[Vector2i] = path_tiles(w)
	var threat: Threat = next_wave_threat(w)
	var armor: float = 3.0 if p.armor_aware and threat.armored else 0.0
	var air_power: float = 0.0
	for t: Tower in w.towers:
		if t.def.hits_air:
			air_power += power(t.kind, t.level)
	var needs_air: bool = threat.air > 0 and air_power < 6 + 40 * threat.air
	var best_value: float = 0.0
	var best_kind: String = ""
	var best_spot: Spot = null
	var best_tower: Tower = null

	for kind: String in Towers.KINDS:
		if not w.is_unlocked(kind) or not w.can_afford(kind) or p.weights[kind] <= 0:
			continue
		if needs_air and not Towers.get_def(kind).hits_air:
			continue
		if kind == "support" and w.towers.size() < 6:
			continue
		var spot: Spot = null
		for s: Spot in rank_spots(w, kind, path, p.maze_weight):
			if w.can_build_at(s.col, s.row):
				spot = s
				break
		if spot == null:
			continue
		var same: int = 0
		for t: Tower in w.towers:
			if t.kind == kind:
				same += 1
		var base: float = spot.score * 6 if kind == "support" else spot.score * power(kind, 0, armor)
		var value: float = (base / w.cost_of(kind)) * p.weights[kind] * pow(1 - p.diversity, same)
		if value > best_value:
			best_value = value
			best_kind = kind
			best_spot = spot
			best_tower = null
	for t: Tower in w.towers:
		var cost: int = w.upgrade_cost_of(t)
		if cost == Tower.NO_UPGRADE or cost > w.money or t.def.behavior == Towers.Behavior.SUPPORT:
			continue
		if needs_air and not t.def.hits_air:
			continue
		var cov: int = coverage(path, t.col, t.row, t.attack_range)
		var gain: float = power(t.kind, t.level + 1, armor) - power(t.kind, t.level, armor)
		var value: float = ((cov * gain) / cost) * p.upgrade_bias * p.weights[t.kind]
		if value > best_value:
			best_value = value
			best_tower = t
			best_spot = null
	if best_tower != null:
		w.upgrade(best_tower)
		return true
	if best_spot != null:
		w.build(best_kind, best_spot.col, best_spot.row)
		return true
	return false


static func play_expert(w: World, p: ExpertParams = null, max_waves: int = NO_LIMIT) -> GameResult:
	var params: ExpertParams = p if p != null else default_expert()
	return run(w, func(world: World) -> void:
		while _expert_buy(world, params):
			pass, max_waves, params.call_early)


# ---- human-like --------------------------------------------------------------------

## A human-like player. `skill` 0 = novice, 1 = very good:
## - places towers somewhere among the top spots (the lower the skill, the wider the pick),
## - chooses tower types at random, only reacting to armor / air when skilled,
## - upgrades now and then instead of building,
## - sometimes keeps a little money unspent.
static func play_human(w: World, skill: float, seed_value: int, max_waves: int = NO_LIMIT) -> GameResult:
	var rand := Mulberry32.new(seed_value)
	var pick_count: int = MathX.js_round(2 + (1 - skill) * 20)
	var upgrade_chance: float = 0.2 + 0.25 * skill

	var buy: Callable = func(world: World) -> void:
		var reserve: float = 20 + rand.next() * 60 if rand.next() < (1 - skill) * 0.5 else 0.0
		var threat: Threat = next_wave_threat(world)
		for guard: int in 60:
			var budget: float = world.money - reserve
			var affordable: Array[String] = []
			for k: String in Towers.KINDS:
				if world.is_unlocked(k) and world.cost_of(k) <= budget and (k != "support" or world.towers.size() >= 5):
					affordable.append(k)
			var upgradable: Array[Tower] = []
			for t: Tower in world.towers:
				var c: int = world.upgrade_cost_of(t)
				if c != Tower.NO_UPGRADE and c <= budget:
					upgradable.append(t)

			# (The random draw only happens when something can be upgraded, as before.)
			if not upgradable.is_empty() and (rand.next() < upgrade_chance or affordable.is_empty()):
				# Skilled players upgrade their best-placed towers; novices pick at random.
				var path: Array[Vector2i] = path_tiles(world)
				var sorted: Array[Spot] = []
				for i: int in upgradable.size():
					var t: Tower = upgradable[i]
					var s := Spot.new(i, 0, coverage(path, t.col, t.row, t.attack_range))
					sorted.append(s)
				_sort_spots(sorted)
				var pick: Spot = sorted[floori(pow(rand.next(), 1 + 2 * skill) * sorted.size())]
				world.upgrade(upgradable[pick.col])
				continue
			if affordable.is_empty():
				break

			var pool: Array[String] = affordable
			if skill >= 0.5 and threat.air > 0.3 and not world.towers.any(func(t: Tower) -> bool: return t.def.hits_air):
				pool = pool.filter(func(k: String) -> bool: return Towers.get_def(k).hits_air)
			if skill >= 0.7 and threat.armored:
				var strong: Array[String] = pool.filter(func(k: String) -> bool:
					return k == "cannon" or k == "laser" or k == "missile")
				if not strong.is_empty():
					pool = strong
			if pool.is_empty():
				break
			var kind: String = pool[floori(rand.next() * pool.size())]
			var spots: Array[Spot] = []
			for s: Spot in rank_spots(world, kind, path_tiles(world), 0.4 * skill if world.map.maze else 0.0):
				if world.can_build_at(s.col, s.row):
					spots.append(s)
			if spots.is_empty():
				break
			var spot: Spot = spots[floori(rand.next() * mini(pick_count, spots.size()))]
			if world.build(kind, spot.col, spot.row) == null:
				break
	return run(w, buy, max_waves)


# ---- strategy search ---------------------------------------------------------------

## Higher is better: winning dominates, then lives kept, then progress.
static func score_result(r: GameResult) -> float:
	return 1000 + r.lives if r.won else r.waves_cleared * 10 + r.lives


static func _random_params(rand: Mulberry32) -> ExpertParams:
	var p := ExpertParams.new()
	for k: String in Towers.KINDS:
		p.weights[k] = 0.0 if rand.next() < 0.15 else 0.3 + rand.next() * 1.7
	p.upgrade_bias = 0.4 + rand.next() * 2
	p.diversity = rand.next() * 0.4
	p.maze_weight = rand.next() * 1.5
	p.armor_aware = rand.next() < 0.7
	p.call_early = rand.next() < 0.3
	return p


static func _mutate(p: ExpertParams, rand: Mulberry32) -> ExpertParams:
	var q: ExpertParams = p.copy()
	var k: String = Towers.KINDS[floori(rand.next() * Towers.KINDS.size())]
	q.weights[k] = maxf(0.0, q.weights[k] + (rand.next() - 0.5))
	q.upgrade_bias = maxf(0.1, q.upgrade_bias * (0.7 + rand.next() * 0.6))
	q.diversity = minf(0.6, maxf(0.0, q.diversity + (rand.next() - 0.5) * 0.1))
	q.maze_weight = maxf(0.0, q.maze_weight + (rand.next() - 0.5) * 0.4)
	if rand.next() < 0.1:
		q.armor_aware = not q.armor_aware
	if rand.next() < 0.1:
		q.call_early = not q.call_early
	return q


## The best strategy found and its result.
class SearchResult:
	var params: ExpertParams
	var result: GameResult


## Random search followed by hill climbing over the expert's parameters.
## `new_world` is a func() -> World that starts a fresh game.
static func search_expert(new_world: Callable, samples: int = 40, climbs: int = 40, seed_value: int = 1) -> SearchResult:
	var rand := Mulberry32.new(seed_value)
	var best := SearchResult.new()
	best.params = default_expert()
	var first: World = new_world.call()
	best.result = play_expert(first, best.params)
	for i: int in samples + climbs:
		var params: ExpertParams = _random_params(rand) if i < samples else _mutate(best.params, rand)
		var world: World = new_world.call()
		var r: GameResult = play_expert(world, params)
		if score_result(r) > score_result(best.result):
			best.params = params
			best.result = r
	return best
