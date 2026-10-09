class_name World
extends RefCounted
## The whole game simulation for one level. It knows nothing about rendering
## or input, so it can run headless (see tests/).

enum Status { PLAYING, WON, LOST }
enum BlockReason { NONE, TERRAIN, OCCUPIED, ENEMY, BLOCKS_PATH, NEEDS_WALL }
## Why an ability can't be used right now.
enum AbilityBlock { NONE, OFF, GAME_OVER, COOLING, MONEY, USED, LIMIT }


class SpawnEntry:
	var tick: int
	var type: String
	var order: int ## insertion order, so equal ticks keep their order (a stable sort)

	func _init(p_tick: int, p_type: String, p_order: int) -> void:
		tick = p_tick
		type = p_type
		order = p_order


## Half the width of a sniper's rail shot (on top of the enemy's radius).
const RAIL_WIDTH: float = 4.0
## From this many enemies on, towers and bullets look them up in a grid
## (see nearby()) instead of checking every one.
const GRID_MIN_ENEMIES: int = 64


## A landmine waiting for a ground enemy.
class Mine:
	var col: int
	var row: int
	var x: float
	var y: float

	func _init(p_col: int, p_row: int) -> void:
		col = p_col
		row = p_row
		x = p_col * Config.TILE + Config.TILE * 0.5
		y = p_row * Config.TILE + Config.TILE * 0.5


## An airstrike on its way down.
class Strike:
	var x: float
	var y: float
	var due: int ## the tick it lands
	var radius: float

	func _init(p_x: float, p_y: float, p_due: int, p_radius: float) -> void:
		x = p_x
		y = p_y
		due = p_due
		radius = p_radius


var map: GameMap
var level_id: String
var variant: String = "" ## the level's variant ("" as designed), see Levels.VARIANTS
var endless: bool
var modifiers: Perks.Modifiers
var start_lives: int
var hp_scale: float
var money: int
var lives: int
var tick: int = 0
var enemies: Array[Enemy] = []
var towers: Array[Tower] = []
var bullets: Array[Bullet] = []
var wave_index: int = -1 ## index of the last started wave
var waves_cleared: int = 0
var kills: int = 0
var status: Status = Status.PLAYING
var events: Array[WorldEvent] = []
## Walls by tile, with what each cost (the refund when it is sold).
var walls: Dictionary[Vector2i, int] = {}
var mines: Array[Mine] = []
var strikes: Array[Strike] = []
## Damage multiplier of every tower: perks, and the damage boost while it lasts.
var damage_multiplier: float = 1.0
## Tower branches the player can't choose yet (all are open by default).
var locked_branches: Dictionary[String, bool] = {}
## Run perks taken in this game, and the offer waiting for a choice (empty
## when none is). See RunPerks.
var run_perks: Array[String] = []
var perk_offer: Array[String] = []
## Every tower's range is multiplied by this (a night variant).
var tower_range: float = 1.0
## Starting bonuses from the tech tree: walls still free in this game, and
## whether the next tower built starts at level 2.
var free_walls_left: int = 0
var veteran_left: bool = false

var _draft_size: int = 0 ## perks per offer; 0: no run perks in this game
var _draft_seed: int = 0
var _drafts_made: int = 0
var _built_kinds: Dictionary[String, bool] = {} ## towers built at least once (free samples)
var _cooldowns: Dictionary[String, int] = {} ## ticks until an ability can be used again
var _effects: Dictionary[String, int] = {} ## ticks left of timed abilities (slow, boost, bounty)
var _used: Dictionary[String, bool] = {} ## once-per-game abilities already used
var _unlocked: Dictionary[String, bool] = {}
var _static_waves: Array[Wave]
var _endless_waves: Callable
var _wave_cache: Dictionary[int, Wave] = {}
var _spawn_queue: Array[SpawnEntry] = []
var _pending_bonus: int = 0
var _spawn_counter: int = 0
var _lane_counter: int = 0 # gives every enemy its own lane
var _flow: FlowField
var _open_flow: FlowField ## the way out ignoring towers and walls (hoppers)
var _tower_grid: Array[Tower] = []
var _block_mask: PackedByteArray ## 1 where a tower or wall stands
## Enemies by position, rebuilt every tick before the towers act (see nearby()).
var _grid := EnemyGrid.new()
# The distance field with one more obstacle, by tile, for the current towers
# and walls (the build check asks for it every frame the player hovers a tile).
var _what_if: Dictionary[int, PackedInt32Array] = {}
var _grid_ready: bool = false ## the grid matches `enemies` (during the towers' and bullets' turn)


## `endless_waves(index) -> Wave` turns on endless mode: waves come from it
## and never run out. `unlocked` lists the towers the player may build.
func _init(level: LevelDef, endless_waves: Callable = Callable(), p_modifiers: Perks.Modifiers = null,
		unlocked: Array[String] = Towers.KINDS) -> void:
	map = GameMap.new(level.name, level.tiles, level.maze, level.road_walls)
	assert(map.error.is_empty(), map.error)
	level_id = level.id
	variant = level.variant
	modifiers = p_modifiers if p_modifiers != null else Perks.no_modifiers()
	for kind: String in unlocked:
		if not level.banned.has(kind):
			_unlocked[kind] = true
	tower_range = level.tower_range
	_endless_waves = endless_waves
	endless = endless_waves.is_valid()
	_static_waves = level.waves
	money = level.money + modifiers.money
	start_lives = level.lives + modifiers.lives
	lives = start_lives
	hp_scale = level.hp_scale
	damage_multiplier = modifiers.damage_multiplier
	free_walls_left = modifiers.free_walls
	veteran_left = modifiers.veteran
	_tower_grid.resize(Config.COLS * Config.ROWS)
	_block_mask.resize(Config.COLS * Config.ROWS)
	_flow = FlowField.new(map.distance_field(_block_mask))
	_flow.blocked = _block_mask.duplicate()
	_open_flow = FlowField.new(map.distance_field(_block_mask))


# ---- waves -------------------------------------------------------------------

## Number of waves, or -1 in endless mode.
func total_waves() -> int:
	return -1 if endless else _static_waves.size()


func wave_at(index: int) -> Wave:
	if index < 0:
		return null
	if not endless:
		return _static_waves[index] if index < _static_waves.size() else null
	var wave: Wave = _wave_cache.get(index)
	if wave == null:
		wave = _endless_waves.call(index)
		_wave_cache[index] = wave
	return wave


func next_wave() -> Wave:
	return wave_at(wave_index + 1)


## Enemies of the current wave still waiting to spawn.
func is_spawning() -> bool:
	return not _spawn_queue.is_empty()


func wave_in_progress() -> bool:
	return is_spawning() or not enemies.is_empty()


## The next wave may start once the current one has fully spawned (and a
## run perk offer has been answered).
func can_start_wave() -> bool:
	return status == Status.PLAYING and not is_spawning() and next_wave() != null and perk_offer.is_empty()


## Bonus paid for calling the next wave right now (0 if the field is clear).
func early_bonus_now() -> int:
	return Config.early_bonus(wave_index + 1) if not enemies.is_empty() else 0


func enemies_remaining() -> int:
	return _spawn_queue.size() + enemies.size()


func hp_multiplier() -> float:
	var i: int = maxi(0, wave_index)
	# Endless waves also get tougher quadratically, so every run ends eventually.
	return hp_scale * (1 + Config.WAVE_HP_GROWTH * i + (Config.ENDLESS_HP_GROWTH * i * i if endless else 0.0))


# ---- queries -----------------------------------------------------------------

func tower_at(col: int, row: int) -> Tower:
	if not GameMap.in_bounds(col, row):
		return null
	return _tower_grid[row * Config.COLS + col]


func is_unlocked(kind: String) -> bool:
	return _unlocked.has(kind)


## Build price of a tower (Free Samples: the first of each kind is free).
func cost_of(kind: String) -> int:
	if has_perk("samples") and not _built_kinds.has(kind):
		return 0
	return MathX.js_round(Towers.get_def(kind).levels[0].cost * modifiers.cost_multiplier)


## Build price on a particular tile (Hill Forts: cheaper on high ground and walls).
func build_cost(kind: String, col: int, row: int) -> int:
	var cost: int = cost_of(kind)
	if has_perk("hillforts") and (map.is_high_ground(col, row) or has_wall(col, row)):
		cost = MathX.js_round(cost * RunPerks.HILL_FORT_PRICE)
	return cost


## Price of the tower's next upgrade, or Tower.NO_UPGRADE at max level.
func upgrade_cost_of(tower: Tower) -> int:
	var base: int = tower.upgrade_cost()
	return Tower.NO_UPGRADE if base == Tower.NO_UPGRADE else MathX.js_round(base * modifiers.cost_multiplier)


## Price of growing a level-3 tower into a branch, or Tower.NO_UPGRADE if it can't grow into that one.
func branch_cost_of(tower: Tower, branch_id: String) -> int:
	if not Towers.is_branch(branch_id) or not tower.needs_branch():
		return Tower.NO_UPGRADE
	var b: TowerBranch = Towers.get_branch(branch_id)
	if b.kind != tower.kind:
		return Tower.NO_UPGRADE
	return MathX.js_round(b.levels[0].cost * modifiers.cost_multiplier)


func is_branch_unlocked(branch_id: String) -> bool:
	return Towers.is_branch(branch_id) and not locked_branches.has(branch_id)


func can_afford(kind: String) -> bool:
	return money >= cost_of(kind)


## Why a tower can't be built here (NONE if it can). A tower may stand on a
## wall anywhere; on the road of wall levels it may only stand on a wall.
func build_block_reason(col: int, row: int) -> BlockReason:
	var walled: bool = has_wall(col, row)
	if not map.is_buildable_terrain(col, row) and not walled:
		return BlockReason.NEEDS_WALL if map.can_hold_wall(col, row) else BlockReason.TERRAIN
	if tower_at(col, row) != null:
		return BlockReason.OCCUPIED
	if walled:
		return BlockReason.NONE # the wall already is an obstacle: the path stays as it is
	return _path_block_reason(col, row)


## Why a wall can't be built here (NONE if it can).
func wall_block_reason(col: int, row: int) -> BlockReason:
	if not map.can_hold_wall(col, row):
		return BlockReason.TERRAIN
	if has_wall(col, row) or tower_at(col, row) != null:
		return BlockReason.OCCUPIED
	return _path_block_reason(col, row)


## Levels where enemies re-route: never trap enemies or cut off the exit.
func _path_block_reason(col: int, row: int) -> BlockReason:
	if not map.flow or not map.is_walkable(col, row):
		return BlockReason.NONE # nothing walks here, so nothing changes
	var tile := Vector2i(col, row)
	for e: Enemy in enemies:
		if e.flying or e.def.hops:
			continue
		if (floori(e.x / Config.TILE) == col and floori(e.y / Config.TILE) == row) or e.nav.target_tile() == tile:
			return BlockReason.ENEMY
	var field: PackedInt32Array = _field_with_obstacle_at(col, row)
	if field.is_empty():
		return BlockReason.BLOCKS_PATH # an entrance would be cut off
	for e: Enemy in enemies:
		var t: Vector2i = e.nav.target_tile()
		if not e.flying and not e.def.hops and t != GameMap.NO_TILE and GameMap.dist_at(field, t.x, t.y) == GameMap.UNREACHABLE:
			return BlockReason.BLOCKS_PATH
	return BlockReason.NONE


## The distance field with an extra obstacle at (col, row), or an empty array
## if that would cut an entrance off the exit. Kept until towers or walls change.
func _field_with_obstacle_at(col: int, row: int) -> PackedInt32Array:
	var k: int = row * Config.COLS + col
	var cached: Variant = _what_if.get(k)
	if cached != null:
		return cached
	var mask: PackedByteArray = _block_mask.duplicate()
	mask[k] = 1
	var field: PackedInt32Array = map.distance_field(mask)
	for s: Vector2i in map.starts:
		if GameMap.dist_at(field, s.x, s.y) == GameMap.UNREACHABLE:
			field = PackedInt32Array()
			break
	_what_if[k] = field
	return field


func can_build_at(col: int, row: int) -> bool:
	return build_block_reason(col, row) == BlockReason.NONE


func has_wall(col: int, row: int) -> bool:
	return walls.has(Vector2i(col, row))


## Current distance field (maze levels), for drawing the enemy path.
var distance_field: PackedInt32Array:
	get:
		return _flow.dist


# ---- player actions ------------------------------------------------------------

func build(kind: String, col: int, row: int) -> Tower:
	if status != Status.PLAYING or not is_unlocked(kind) or money < build_cost(kind, col, row) or not can_build_at(col, row):
		return null
	var cost: int = build_cost(kind, col, row)
	_built_kinds[kind] = true
	# A wall under a tower raises it like high ground does.
	var tower := Tower.new(kind, col, row, map.is_high_ground(col, row) or has_wall(col, row), cost)
	if tower_range != 1.0:
		tower.set_range_factor(tower_range)
	if veteran_left:
		tower.level = 1 # Veterans: the first tower starts at level 2
		veteran_left = false
	towers.append(tower)
	money -= cost
	_obstacles_changed()
	var ev := WorldEvent.new(WorldEvent.Type.BUILD, tower.x, tower.y)
	ev.kind = kind
	events.append(ev)
	return tower


func upgrade(tower: Tower) -> bool:
	var cost: int = upgrade_cost_of(tower)
	if status != Status.PLAYING or cost == Tower.NO_UPGRADE or money < cost:
		return false
	money -= cost
	tower.invested += cost
	tower.level += 1
	if tower.def.pulls:
		_obstacles_changed() # a wider field pulls from further away
	var ev := WorldEvent.new(WorldEvent.Type.UPGRADE, tower.x, tower.y)
	ev.level = tower.level
	events.append(ev)
	return true


## Grows a level-3 tower into one of its branches (its level 4). The choice is for good.
func choose_branch(tower: Tower, branch_id: String) -> bool:
	var cost: int = branch_cost_of(tower, branch_id)
	if status != Status.PLAYING or cost == Tower.NO_UPGRADE or not is_branch_unlocked(branch_id) \
			or money < cost or not towers.has(tower):
		return false
	money -= cost
	tower.invested += cost
	tower.set_branch(Towers.get_branch(branch_id))
	if tower.def.pulls:
		_obstacles_changed()
	var ev := WorldEvent.new(WorldEvent.Type.UPGRADE, tower.x, tower.y)
	ev.level = tower.level
	ev.kind = branch_id
	events.append(ev)
	return true


func sell(tower: Tower) -> bool:
	var i: int = towers.find(tower)
	if i < 0 or status != Status.PLAYING:
		return false
	towers.remove_at(i)
	money += tower.sell_value()
	_obstacles_changed()
	var ev := WorldEvent.new(WorldEvent.Type.SELL, tower.x, tower.y)
	ev.amount = tower.sell_value()
	events.append(ev)
	return true


## Price of the next wall (0 while Masonry's free walls last).
func wall_cost() -> int:
	if free_walls_left > 0:
		return 0
	return RunPerks.STONEWORK_WALL if has_perk("stonework") else Abilities.wall_cost(walls.size())


func can_build_wall_at(col: int, row: int) -> bool:
	return status == Status.PLAYING and Abilities.ENABLED.get("wall", false) and money >= wall_cost() \
		and wall_block_reason(col, row) == BlockReason.NONE


## Builds a wall. Enemies walk around it where there is room (on levels where
## they re-route); it is refused if it would block the path.
func build_wall(col: int, row: int) -> bool:
	if not can_build_wall_at(col, row):
		return false
	var cost: int = wall_cost()
	if free_walls_left > 0:
		free_walls_left -= 1
	money -= cost
	walls[Vector2i(col, row)] = cost
	_obstacles_changed()
	var ev := WorldEvent.new(WorldEvent.Type.WALL_BUILT, col * Config.TILE + Config.TILE * 0.5, row * Config.TILE + Config.TILE * 0.5)
	ev.amount = cost
	events.append(ev)
	return true


## Sells a wall for what it cost. A wall with a tower on it can't be sold (sell the tower first).
func sell_wall(col: int, row: int) -> bool:
	var tile := Vector2i(col, row)
	if status != Status.PLAYING or not walls.has(tile) or tower_at(col, row) != null:
		return false
	var paid: int = walls[tile]
	walls.erase(tile)
	money += paid
	_obstacles_changed()
	var ev := WorldEvent.new(WorldEvent.Type.WALL_SOLD, col * Config.TILE + Config.TILE * 0.5, row * Config.TILE + Config.TILE * 0.5)
	ev.amount = paid
	events.append(ev)
	return true


func set_target_mode(tower: Tower, mode: Towers.TargetMode) -> void:
	tower.target_mode = mode


func start_next_wave() -> bool:
	if not can_start_wave():
		return false
	var early: int = early_bonus_now()
	money += early
	wave_index += 1
	_pending_bonus += Config.wave_bonus(wave_index)
	var order: int = _spawn_queue.size()
	for group: SpawnGroup in wave_at(wave_index).groups:
		for i: int in group.count:
			var at: int = tick + MathX.js_round((group.delay + i * group.interval) * Config.TICK_RATE)
			_spawn_queue.append(SpawnEntry.new(at, group.type, order))
			order += 1
	_spawn_queue.sort_custom(func(a: SpawnEntry, b: SpawnEntry) -> bool:
		return a.tick < b.tick or (a.tick == b.tick and a.order < b.order))
	var ev := WorldEvent.new(WorldEvent.Type.WAVE_STARTED)
	ev.wave = wave_index
	ev.early = early
	events.append(ev)
	return true


## Towers or walls were added or removed: enemies re-plan their way.
func _obstacles_changed() -> void:
	_what_if.clear()
	_tower_grid.fill(null)
	_block_mask.fill(0)
	for t: Tower in towers:
		var k: int = t.row * Config.COLS + t.col
		_tower_grid[k] = t
		_block_mask[k] = 1
	for tile: Vector2i in walls:
		_block_mask[tile.y * Config.COLS + tile.x] = 1
	_flow.blocked = _block_mask.duplicate()
	if map.flow:
		var lures: PackedByteArray = _lure_mask()
		if lures.is_empty():
			_flow.dist = map.distance_field(_block_mask)
			_flow.unit = 1
		else:
			_flow.dist = map.weighted_distance_field(_block_mask, lures)
			_flow.unit = GameMap.STEP_COST


## Tiles in the field of a magnet (empty when there are none).
func _lure_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	for t: Tower in towers:
		if not t.def.pulls:
			continue
		if mask.is_empty():
			mask.resize(Config.COLS * Config.ROWS)
		var reach: int = ceili(t.attack_range / Config.TILE)
		for r: int in range(t.row - reach, t.row + reach + 1):
			for c: int in range(t.col - reach, t.col + reach + 1):
				if GameMap.in_bounds(c, r) and GameMap.tile_center(Vector2i(c, r)).distance_to(Vector2(t.x, t.y)) <= t.attack_range:
					mask[r * Config.COLS + c] = 1
	return mask


# ---- enemies -----------------------------------------------------------------

## Spawns an enemy at a map entrance (or, with `from`, as a copy of another's position).
func spawn(type: String, from: Enemy = null) -> Enemy:
	var hp: float = hp_multiplier()
	var lane_seed: int = _lane_counter
	_lane_counter += 1
	var enemy: Enemy
	if from != null:
		enemy = Enemy.new(type, from.nav.clone(lane_seed), hp)
	else:
		var i: int = _spawn_counter
		_spawn_counter += 1
		var nav: Nav
		if Enemies.get_def(type).flying:
			var flights: Array[Route] = map.flight_routes
			nav = RouteNav.new(flights[i % flights.size()], lane_seed, true)
		elif map.flow:
			var field: FlowField = _open_flow if Enemies.get_def(type).hops else _flow
			nav = FlowNav.new(map, field, map.starts[i % map.starts.size()], lane_seed)
		else:
			var roads: Array[Route] = map.routes
			nav = RouteNav.new(roads[i % roads.size()], lane_seed)
		enemy = Enemy.new(type, nav, hp)
	if enemy.def.hops:
		enemy.obstacles = _flow
	enemies.append(enemy)
	if _grid_ready:
		_grid.add(enemies.size() - 1)
	return enemy


## Damages an enemy (armor and shields apply, a focus mark doubles it, a
## cryo chill adds to it); pays
## the reward (doubled during a bounty) and splits splitters when it dies.
func damage_enemy(e: Enemy, amount: float, ignores_armor: bool = false, flash: bool = true) -> void:
	var dealt: float = amount * e.mark_factor if e.mark_ticks > 0 else amount
	if e.vulnerability > 0:
		dealt *= 1 + e.vulnerability
	if e.rallied:
		dealt *= 1 - e.rally_toughness
	if not e.hit(dealt, ignores_armor, flash):
		if e.alive and not e.def.phases.is_empty():
			_check_phase(e)
		return
	kills += 1
	var reward: int = e.def.reward * (roundi(Abilities.get_def("bounty").power) if is_active("bounty") else 1)
	if has_perk("headhunter"):
		reward += RunPerks.HEADHUNTER_BONUS
	money += reward
	var ev := WorldEvent.new(WorldEvent.Type.KILL, e.x, e.y)
	ev.amount = reward
	ev.enemy = e.type
	events.append(ev)
	var split: EnemyDef.Split = e.def.split
	if split != null:
		for i: int in split.count:
			var child: Enemy = spawn(split.type, e)
			# Spread the children a little along the way they're walking.
			child.nav.fall_back((i - (split.count - 1) / 2.0) * 10)
			child.x = child.nav.x
			child.prev_x = child.x
			child.y = child.nav.y
			child.prev_y = child.y


## The enemies that may be within `reach` (plus their radius) of (x, y), in
## the order of `enemies`: during the towers' turn only those near the spot
## (from the grid), otherwise all of them. Callers still check the distance.
func nearby(x: float, y: float, reach: float) -> Array[Enemy]:
	return _grid.pick(_grid.near(x, y, reach)) if _grid_ready else enemies


func _in_box(x0: float, y0: float, x1: float, y1: float) -> Array[Enemy]:
	return _grid.pick(_grid.query(x0, y0, x1, y1)) if _grid_ready else enemies


## The grid of enemies by position, while it is up to date (null otherwise).
func enemy_grid() -> EnemyGrid:
	return _grid if _grid_ready else null


## A tower fired a bullet.
func fire(b: Bullet, from: Tower) -> void:
	bullets.append(b)
	var ev := WorldEvent.new(WorldEvent.Type.SHOT, b.x, b.y)
	ev.kind = from.branch_id if from.branch != null else from.kind
	events.append(ev)


## A sniper's rail shot: instantly hits up to `max_hits` enemies along a line
## of `length` from the tower, nearest first.
func rail(from: Tower, angle: float, length: float, damage: float, max_hits: int) -> void:
	var dx: float = cos(angle)
	var dy: float = sin(angle)
	var hits: Array[Enemy] = []
	var along_of: Dictionary[Enemy, float] = {}
	var pad: float = RAIL_WIDTH + (_grid.max_radius if _grid_ready else 0.0)
	var x1: float = from.x + dx * length
	var y1: float = from.y + dy * length
	for e: Enemy in _in_box(minf(from.x, x1) - pad, minf(from.y, y1) - pad, maxf(from.x, x1) + pad, maxf(from.y, y1) + pad):
		if not from.can_target(e):
			continue
		var rx: float = e.x - from.x
		var ry: float = e.y - from.y
		var along: float = rx * dx + ry * dy
		if along < -e.radius or along > length + e.radius:
			continue
		if absf(rx * dy - ry * dx) <= e.radius + RAIL_WIDTH:
			hits.append(e)
			along_of[e] = along
	hits.sort_custom(func(a: Enemy, b: Enemy) -> bool: return along_of[a] < along_of[b])
	var reach: float = length
	if hits.size() >= max_hits:
		hits.resize(max_hits)
		reach = along_of[hits[max_hits - 1]]
	var shot := WorldEvent.new(WorldEvent.Type.SHOT, from.x, from.y)
	shot.kind = from.branch_id
	events.append(shot)
	var ev := WorldEvent.new(WorldEvent.Type.RAIL, from.x, from.y)
	ev.x2 = from.x + dx * reach
	ev.y2 = from.y + dy * reach
	ev.kind = from.branch_id
	events.append(ev)
	for e: Enemy in hits:
		damage_enemy(e, damage, from.ignores_armor)


## A frost tower pulsed (for effects).
func pulse(t: Tower) -> void:
	var ev := WorldEvent.new(WorldEvent.Type.PULSE, t.x, t.y)
	ev.radius = t.attack_range
	ev.kind = t.kind
	events.append(ev)


## A boss whose hitpoints fell below its next phase's threshold changes.
func _check_phase(e: Enemy) -> void:
	var phases: Array[EnemyDef.Phase] = e.def.phases
	while e.phase < phases.size() and e.hitpoints < e.max_hitpoints * phases[e.phase].below:
		var p: EnemyDef.Phase = phases[e.phase]
		e.phase += 1
		e.armor = p.armor
		e.speed_mult = p.speed
		if p.shield > 0:
			e.max_shield = MathX.js_round(p.shield * e.max_hitpoints / e.def.hitpoints)
			e.shield = e.max_shield
		for i: int in p.summon_count:
			var child: Enemy = spawn(p.summon_type, e)
			child.nav.fall_back((i + 1) * 18)
			child.x = child.nav.x
			child.prev_x = child.x
			child.y = child.nav.y
			child.prev_y = child.y
		var ev := WorldEvent.new(WorldEvent.Type.BOSS_PHASE, e.x, e.y)
		ev.enemy = e.type
		ev.text = p.message
		events.append(ev)


## Warchiefs rally the enemies around them (not themselves).
func _update_rally() -> void:
	var chiefs: Array[Enemy] = []
	for e: Enemy in enemies:
		if e.alive and e.def.rally != null:
			chiefs.append(e)
	for e: Enemy in enemies:
		e.rallied = false
		for c: Enemy in chiefs:
			var r: EnemyDef.Rally = c.def.rally
			if c != e and MathX.hypot(c.x - e.x, c.y - e.y) <= r.radius:
				e.rallied = true
				e.rally_speed = r.speed
				e.rally_toughness = r.toughness
				break


func _update_abilities(e: Enemy) -> void:
	var heal: EnemyDef.Heal = e.def.heal
	var summon: EnemyDef.Summon = e.def.summon
	var emp: EnemyDef.Emp = e.def.emp
	if heal == null and summon == null and emp == null:
		return
	e.ability_timer -= 1
	if e.ability_timer > 0:
		return
	if heal != null:
		e.ability_timer = MathX.js_round(heal.interval * Config.TICK_RATE)
		var healed: float = 0.0
		for o: Enemy in enemies:
			if o != e and o.alive and MathX.hypot(o.x - e.x, o.y - e.y) <= heal.radius:
				healed += o.heal(o.max_hitpoints * heal.fraction)
		if healed > 0:
			var ev := WorldEvent.new(WorldEvent.Type.HEAL, e.x, e.y)
			ev.radius = heal.radius
			events.append(ev)
	if summon != null:
		e.ability_timer = MathX.js_round(summon.interval * Config.TICK_RATE)
		for i: int in summon.count:
			spawn(summon.type, e)
		events.append(WorldEvent.new(WorldEvent.Type.SUMMON, e.x, e.y))
	if emp != null:
		e.ability_timer = MathX.js_round(emp.interval * Config.TICK_RATE)
		var hit_any: bool = false
		for t: Tower in towers:
			if MathX.hypot(t.x - e.x, t.y - e.y) <= emp.radius:
				t.disable(ticks_of(emp.duration))
				hit_any = true
		if hit_any:
			var ev := WorldEvent.new(WorldEvent.Type.EMP, e.x, e.y)
			ev.radius = emp.radius
			events.append(ev)


# ---- abilities ---------------------------------------------------------------

static func ticks_of(seconds: float) -> int:
	return MathX.js_round(seconds * Config.TICK_RATE)


func ability_cost(id: String) -> int:
	return wall_cost() if id == "wall" else Abilities.get_def(id).cost


## Ticks until the ability can be used again (0 when it is ready).
func cooldown_left(id: String) -> int:
	var left: int = _cooldowns.get(id, 0)
	return left


## Ticks left of a timed ability (time slow, damage boost, bounty).
func effect_left(id: String) -> int:
	var left: int = _effects.get(id, 0)
	return left


func is_active(id: String) -> bool:
	return effect_left(id) > 0


func is_used(id: String) -> bool:
	return _used.has(id)


## Why the ability can't be used right now (NONE if it can). Where it is
## aimed (a tile, a spot, an enemy) may still turn out to be wrong.
func ability_block(id: String) -> AbilityBlock:
	if status != Status.PLAYING:
		return AbilityBlock.GAME_OVER
	if not Abilities.ENABLED.get(id, false):
		return AbilityBlock.OFF
	var d: Abilities.AbilityDef = Abilities.get_def(id)
	if d.once and is_used(id):
		return AbilityBlock.USED
	if cooldown_left(id) > 0:
		return AbilityBlock.COOLING
	if d.limit > 0 and id == "mine" and mines.size() >= d.limit:
		return AbilityBlock.LIMIT
	if money < ability_cost(id):
		return AbilityBlock.MONEY
	return AbilityBlock.NONE


## Uses an ability that is not placed on a tile: time slow, damage boost,
## bounty, second wind, and (aimed at the spot `at`) the airstrike and the
## focus mark (the enemy nearest to `at`). False if it can't be used.
func use_ability(id: String, at: Vector2 = Vector2.ZERO) -> bool:
	var d: Abilities.AbilityDef = Abilities.get_def(id)
	if d.target == Abilities.Target.TILE or ability_block(id) != AbilityBlock.NONE:
		return false
	var ev := WorldEvent.new(WorldEvent.Type.ABILITY, at.x, at.y)
	ev.kind = id
	ev.radius = d.radius
	match id:
		"slow", "boost", "bounty":
			_effects[id] = ticks_of(d.duration)
		"strike":
			strikes.append(Strike.new(at.x, at.y, tick + ticks_of(d.duration), d.radius))
		"mark":
			var target: Enemy = enemy_near(at)
			if target == null:
				return false
			target.mark(ticks_of(d.duration), d.power)
			ev.x = target.x
			ev.y = target.y
		"wind":
			lives += roundi(d.power)
			_used[id] = true
	_pay_for(id)
	events.append(ev)
	return true


## The enemy closest to a spot, if the spot is on it (or near).
func enemy_near(at: Vector2, slack: float = 14.0) -> Enemy:
	var best: Enemy = null
	var best_dist: float = INF
	for e: Enemy in enemies:
		var dist: float = MathX.hypot(e.x - at.x, e.y - at.y)
		if e.alive and dist <= e.radius + slack and dist < best_dist:
			best = e
			best_dist = dist
	return best


func mine_at(col: int, row: int) -> Mine:
	for m: Mine in mines:
		if m.col == col and m.row == row:
			return m
	return null


## Why a mine can't be placed on this tile (NONE if it can): ground enemies must walk there.
func mine_block_reason(col: int, row: int) -> BlockReason:
	if not map.is_walkable(col, row):
		return BlockReason.TERRAIN
	if _block_mask[row * Config.COLS + col] != 0 or mine_at(col, row) != null:
		return BlockReason.OCCUPIED
	return BlockReason.NONE


func place_mine(col: int, row: int) -> bool:
	if ability_block("mine") != AbilityBlock.NONE or mine_block_reason(col, row) != BlockReason.NONE:
		return false
	var m := Mine.new(col, row)
	mines.append(m)
	_pay_for("mine")
	events.append(WorldEvent.new(WorldEvent.Type.MINE_PLACED, m.x, m.y))
	return true


func _pay_for(id: String) -> void:
	money -= ability_cost(id)
	var cooldown: float = Abilities.get_def(id).cooldown
	if has_perk("quickhands"):
		cooldown *= RunPerks.QUICK_COOLDOWN
	if cooldown > 0:
		_cooldowns[id] = ticks_of(cooldown)


## Cooldowns and timed effects run down by one tick.
func _tick_abilities() -> void:
	for id: String in _cooldowns.keys():
		_cooldowns[id] -= 1
		if _cooldowns[id] <= 0:
			_cooldowns.erase(id)
	for id: String in _effects.keys():
		_effects[id] -= 1
		if _effects[id] <= 0:
			_effects.erase(id)
	damage_multiplier = modifiers.damage_multiplier
	if is_active("boost"):
		damage_multiplier *= 1.0 + Abilities.get_def("boost").power


## A ground enemy near a mine sets it off: it and everything around it takes damage.
func _update_mines() -> void:
	for m: Mine in mines.duplicate():
		var triggered: bool = false
		for e: Enemy in enemies:
			if e.alive and not e.flying and MathX.hypot(e.x - m.x, e.y - m.y) <= Abilities.MINE_TRIGGER + e.radius:
				triggered = true
				break
		if not triggered:
			continue
		mines.erase(m)
		var d: Abilities.AbilityDef = Abilities.get_def("mine")
		var ev := WorldEvent.new(WorldEvent.Type.MINE_BLAST, m.x, m.y)
		ev.radius = d.radius
		events.append(ev)
		var damage: float = d.power * hp_multiplier()
		for e: Enemy in enemies.duplicate():
			if e.alive and not e.flying and MathX.hypot(e.x - m.x, e.y - m.y) <= d.radius + e.radius:
				damage_enemy(e, damage)


## Airstrikes that are due land: everything around the spot takes damage.
func _update_strikes() -> void:
	for st: Strike in strikes.duplicate():
		if st.due > tick:
			continue
		strikes.erase(st)
		var ev := WorldEvent.new(WorldEvent.Type.STRIKE, st.x, st.y)
		ev.radius = st.radius
		events.append(ev)
		var damage: float = Abilities.get_def("strike").power * hp_multiplier()
		for e: Enemy in enemies.duplicate():
			if e.alive and MathX.hypot(e.x - st.x, e.y - st.y) <= st.radius + e.radius:
				damage_enemy(e, damage)


# ---- run perks ---------------------------------------------------------------

## Turns run perks on for this game: offers of `size` perks at the start and
## after the waves in RunPerks.DRAFTS. `seed_value` makes the offers repeatable.
func enable_drafts(size: int, seed_value: int) -> void:
	_draft_size = size
	_draft_seed = seed_value
	_check_draft()


func has_perk(id: String) -> bool:
	return run_perks.has(id)


## Takes a perk now (Greed and Reinforcements change the lives at once).
func add_run_perk(id: String) -> void:
	if has_perk(id) or not RunPerks.is_id(id):
		return
	run_perks.append(id)
	match id:
		"greed":
			lives = maxi(1, ceili(lives / 2.0))
			start_lives = maxi(1, ceili(start_lives / 2.0))
		"reinforcements":
			lives += RunPerks.REINFORCEMENTS
			start_lives += RunPerks.REINFORCEMENTS
	var ev := WorldEvent.new(WorldEvent.Type.RUN_PERK)
	ev.kind = id
	events.append(ev)


## Answers the offer: keeps one of the perks offered.
func choose_run_perk(id: String) -> bool:
	if not perk_offer.has(id) or status != Status.PLAYING:
		return false
	perk_offer = []
	add_run_perk(id)
	return true


## Makes the next offer once it is due.
func _check_draft() -> void:
	if _draft_size <= 0 or not perk_offer.is_empty() or status != Status.PLAYING:
		return
	if _drafts_made >= RunPerks.DRAFTS.size() or waves_cleared < RunPerks.DRAFTS[_drafts_made]:
		return
	_drafts_made += 1
	var pool: Array[String] = RunPerks.IDS.filter(func(id: String) -> bool: return not has_perk(id))
	var rand := Mulberry32.new(_draft_seed * 31 + _drafts_made * 977 + 1)
	var offer: Array[String] = []
	while offer.size() < _draft_size and not pool.is_empty():
		offer.append(pool.pop_at(floori(rand.next() * pool.size())))
	perk_offer = offer


# ---- simulation --------------------------------------------------------------

func update() -> void:
	if status != Status.PLAYING:
		return
	tick += 1
	_tick_abilities()
	var had_wave: bool = wave_in_progress()

	while not _spawn_queue.is_empty() and _spawn_queue[0].tick <= tick:
		var entry: SpawnEntry = _spawn_queue.pop_front()
		spawn(entry.type)

	_update_rally()
	var extra_slow: float = Abilities.get_def("slow").power if is_active("slow") else 0.0
	for e: Enemy in enemies.duplicate():
		e.update(extra_slow)
		if e.escaped:
			lives = maxi(0, lives - e.def.damage)
			var ev := WorldEvent.new(WorldEvent.Type.LEAK, e.x, e.y)
			ev.amount = e.def.damage
			events.append(ev)
		else:
			_update_abilities(e)

	_update_mines()
	_update_strikes()
	# Only worth it on a crowded field: with few enemies (mostly along one
	# road, in range of most towers) looking at all of them is cheaper.
	_grid_ready = enemies.size() >= GRID_MIN_ENEMIES
	if _grid_ready:
		_grid.rebuild(enemies)
	_update_buffs()
	for t: Tower in towers:
		t.update(self)

	for b: Bullet in bullets:
		var outcome: Bullet.Outcome = b.update(enemies, enemy_grid())
		if outcome == Bullet.Outcome.HIT:
			var ev := WorldEvent.new(WorldEvent.Type.HIT, b.x, b.y)
			ev.bullet = b.type
			events.append(ev)
			damage_enemy(b.hit_enemy, b.damage_to(b.hit_enemy), b.ignores_armor)
		elif outcome == Bullet.Outcome.EXPLODE:
			var ev := WorldEvent.new(WorldEvent.Type.EXPLODE, b.x, b.y)
			ev.radius = b.splash
			events.append(ev)
			for e: Enemy in enemies.duplicate():
				if b.can_hit(e) and MathX.hypot(e.x - b.x, e.y - b.y) <= b.splash + e.radius:
					damage_enemy(e, b.damage_to(e), b.ignores_armor)

	_grid_ready = false
	var alive_enemies: Array[Enemy] = []
	for e: Enemy in enemies:
		if e.alive:
			alive_enemies.append(e)
	enemies = alive_enemies
	var alive_bullets: Array[Bullet] = []
	for b: Bullet in bullets:
		if b.alive:
			alive_bullets.append(b)
	bullets = alive_bullets

	if lives <= 0:
		status = Status.LOST
		events.append(WorldEvent.new(WorldEvent.Type.LOST))
	elif had_wave and not wave_in_progress() and _pending_bonus > 0:
		var greed: int = 2 if has_perk("greed") else 1
		var interest: int = mini(floori(money * Config.INTEREST_RATE * greed), Config.interest_cap(wave_index) * greed)
		var bonus: int = _pending_bonus
		money += bonus + interest
		_pending_bonus = 0
		waves_cleared = wave_index + 1
		var ev := WorldEvent.new(WorldEvent.Type.WAVE_CLEARED)
		ev.wave = wave_index
		ev.bonus = bonus
		ev.interest = interest
		events.append(ev)
		if not endless and wave_index == _static_waves.size() - 1:
			status = Status.WON
			events.append(WorldEvent.new(WorldEvent.Type.WON))
		_check_draft()


## Beacons boost the fire rate of towers around them (the best one counts);
## command posts add range too.
func _update_buffs() -> void:
	var beacons: Array[Tower] = []
	for t: Tower in towers:
		if t.def.behavior == Towers.Behavior.SUPPORT and not t.is_disabled():
			beacons.append(t)
	for t: Tower in towers:
		t.buff = 0.0
		if t.def.behavior == Towers.Behavior.SUPPORT:
			continue
		var range_buff: float = 0.0
		var wide: float = RunPerks.WIDE_BEACON_RANGE if has_perk("widebeacons") else 0.0
		for s: Tower in beacons:
			if MathX.hypot(t.x - s.x, t.y - s.y) <= s.attack_range:
				t.buff = maxf(t.buff, s.stats.buff)
				range_buff = maxf(range_buff, maxf(s.stats.range_buff, wide))
		t.set_range_buff(range_buff)


# ---- save / resume -------------------------------------------------------------

## A snapshot can only be taken between waves; null otherwise. Timed effects
## (time slow and so on) are not kept; cooldowns are.
func snapshot() -> WorldSnapshot:
	if wave_in_progress() or status != Status.PLAYING:
		return null
	var s := WorldSnapshot.new()
	s.level_id = level_id
	s.endless = endless
	s.money = money
	s.lives = lives
	s.wave_index = wave_index
	s.waves_cleared = waves_cleared
	for t: Tower in towers:
		var save := WorldSnapshot.TowerSave.new()
		save.kind = t.kind
		save.col = t.col
		save.row = t.row
		save.level = t.level
		save.branch = t.branch_id
		save.target_mode = t.target_mode
		save.invested = t.invested
		s.towers.append(save)
	for tile: Vector2i in walls:
		var wall := WorldSnapshot.WallSave.new()
		wall.col = tile.x
		wall.row = tile.y
		wall.paid = walls[tile]
		s.walls.append(wall)
	for m: Mine in mines:
		s.mines.append(Vector2i(m.col, m.row))
	for id: String in _cooldowns:
		s.cooldowns[id] = _cooldowns[id]
	for id: String in _used:
		s.used.append(id)
	s.free_walls = free_walls_left
	s.veteran = veteran_left
	s.run_perks = run_perks.duplicate()
	s.perk_offer = perk_offer.duplicate()
	s.drafts_made = _drafts_made
	for kind: String in _built_kinds:
		s.built_kinds.append(kind)
	return s


func restore(s: WorldSnapshot) -> void:
	money = s.money
	lives = s.lives
	wave_index = s.wave_index
	waves_cleared = s.waves_cleared
	walls = {}
	for save: WorldSnapshot.WallSave in s.walls:
		var tile := Vector2i(save.col, save.row)
		if map.can_hold_wall(save.col, save.row) and not walls.has(tile):
			walls[tile] = save.paid
	towers = []
	for save: WorldSnapshot.TowerSave in s.towers:
		var walled: bool = has_wall(save.col, save.row)
		if not (map.is_buildable_terrain(save.col, save.row) or walled) or not Towers.is_kind(save.kind):
			continue
		var tower := Tower.new(save.kind, save.col, save.row, map.is_high_ground(save.col, save.row) or walled, save.invested)
		tower.range_factor = tower_range
		var b: String = save.branch
		if Towers.is_branch(b) and Towers.get_branch(b).kind == save.kind and save.level >= Towers.BRANCH_LEVEL:
			tower.branch = Towers.get_branch(b)
			tower.level = clampi(save.level, Towers.BRANCH_LEVEL, Towers.MAX_LEVEL)
		else:
			tower.level = clampi(save.level, 0, Towers.BRANCH_LEVEL - 1)
		tower.target_mode = save.target_mode
		towers.append(tower)
	_obstacles_changed()
	mines = []
	for tile: Vector2i in s.mines:
		if map.is_walkable(tile.x, tile.y) and mine_block_reason(tile.x, tile.y) == BlockReason.NONE:
			mines.append(Mine.new(tile.x, tile.y))
	_cooldowns = {}
	for id: String in s.cooldowns:
		_cooldowns[id] = s.cooldowns[id]
	_used = {}
	for id: String in s.used:
		_used[id] = true
	_effects = {}
	strikes = []
	damage_multiplier = modifiers.damage_multiplier
	if s.free_walls >= 0:
		free_walls_left = mini(s.free_walls, modifiers.free_walls)
	veteran_left = modifiers.veteran and s.veteran
	run_perks = s.run_perks.duplicate()
	perk_offer = s.perk_offer.duplicate()
	_drafts_made = maxi(s.drafts_made, 0)
	_built_kinds = {}
	for kind: String in s.built_kinds:
		_built_kinds[kind] = true
	for t: Tower in towers:
		_built_kinds[t.kind] = true
	_check_draft()
