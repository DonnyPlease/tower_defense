class_name World
extends RefCounted
## The whole game simulation for one level. It knows nothing about rendering
## or input, so it can run headless (see tests/).

enum Status { PLAYING, WON, LOST }
enum BlockReason { NONE, TERRAIN, OCCUPIED, ENEMY, BLOCKS_PATH }


class SpawnEntry:
	var tick: int
	var type: String
	var order: int ## insertion order, so equal ticks keep their order (a stable sort)

	func _init(p_tick: int, p_type: String, p_order: int) -> void:
		tick = p_tick
		type = p_type
		order = p_order


var map: GameMap
var level_id: String
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

var _unlocked: Dictionary[String, bool] = {}
var _static_waves: Array[Wave]
var _endless_waves: Callable
var _wave_cache: Dictionary[int, Wave] = {}
var _spawn_queue: Array[SpawnEntry] = []
var _pending_bonus: int = 0
var _spawn_counter: int = 0
var _lane_counter: int = 0 # gives every enemy its own lane
var _flow: FlowField
var _tower_grid: Array[Tower] = []
var _tower_mask: PackedByteArray


## `endless_waves(index) -> Wave` turns on endless mode: waves come from it
## and never run out. `unlocked` lists the towers the player may build.
func _init(level: LevelDef, endless_waves: Callable = Callable(), p_modifiers: Perks.Modifiers = null,
		unlocked: Array[String] = Towers.KINDS) -> void:
	map = GameMap.new(level.name, level.tiles, level.maze)
	assert(map.error.is_empty(), map.error)
	level_id = level.id
	modifiers = p_modifiers if p_modifiers != null else Perks.no_modifiers()
	for kind: String in unlocked:
		_unlocked[kind] = true
	_endless_waves = endless_waves
	endless = endless_waves.is_valid()
	_static_waves = level.waves
	money = level.money + modifiers.money
	start_lives = level.lives + modifiers.lives
	lives = start_lives
	hp_scale = level.hp_scale
	_tower_grid.resize(Config.COLS * Config.ROWS)
	_tower_mask.resize(Config.COLS * Config.ROWS)
	_flow = FlowField.new(map.distance_field(_tower_mask))


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


## The next wave may start once the current one has fully spawned.
func can_start_wave() -> bool:
	return status == Status.PLAYING and not is_spawning() and next_wave() != null


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


func cost_of(kind: String) -> int:
	return MathX.js_round(Towers.get_def(kind).levels[0].cost * modifiers.cost_multiplier)


## Price of the tower's next upgrade, or Tower.NO_UPGRADE at max level.
func upgrade_cost_of(tower: Tower) -> int:
	var base: int = tower.upgrade_cost()
	return Tower.NO_UPGRADE if base == Tower.NO_UPGRADE else MathX.js_round(base * modifiers.cost_multiplier)


func can_afford(kind: String) -> bool:
	return money >= cost_of(kind)


func build_block_reason(col: int, row: int) -> BlockReason:
	if not map.is_buildable_terrain(col, row):
		return BlockReason.TERRAIN
	if tower_at(col, row) != null:
		return BlockReason.OCCUPIED
	if not map.maze:
		return BlockReason.NONE

	# Maze levels: never trap enemies or cut off the exit.
	var tile := Vector2i(col, row)
	for e: Enemy in enemies:
		if e.flying:
			continue
		if (floori(e.x / Config.TILE) == col and floori(e.y / Config.TILE) == row) or e.nav.target_tile() == tile:
			return BlockReason.ENEMY
	var mask: PackedByteArray = _tower_mask.duplicate()
	mask[row * Config.COLS + col] = 1
	var field: PackedInt32Array = map.distance_field(mask)
	for s: Vector2i in map.starts:
		if GameMap.dist_at(field, s.x, s.y) == GameMap.UNREACHABLE:
			return BlockReason.BLOCKS_PATH
	for e: Enemy in enemies:
		var t: Vector2i = e.nav.target_tile()
		if not e.flying and t != GameMap.NO_TILE and GameMap.dist_at(field, t.x, t.y) == GameMap.UNREACHABLE:
			return BlockReason.BLOCKS_PATH
	return BlockReason.NONE


func can_build_at(col: int, row: int) -> bool:
	return build_block_reason(col, row) == BlockReason.NONE


## Current distance field (maze levels), for drawing the enemy path.
var distance_field: PackedInt32Array:
	get:
		return _flow.dist


# ---- player actions ------------------------------------------------------------

func build(kind: String, col: int, row: int) -> Tower:
	if status != Status.PLAYING or not is_unlocked(kind) or not can_afford(kind) or not can_build_at(col, row):
		return null
	var cost: int = cost_of(kind)
	var tower := Tower.new(kind, col, row, map.is_high_ground(col, row), cost)
	towers.append(tower)
	money -= cost
	_towers_changed()
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
	var ev := WorldEvent.new(WorldEvent.Type.UPGRADE, tower.x, tower.y)
	ev.level = tower.level
	events.append(ev)
	return true


func sell(tower: Tower) -> bool:
	var i: int = towers.find(tower)
	if i < 0 or status != Status.PLAYING:
		return false
	towers.remove_at(i)
	money += tower.sell_value()
	_towers_changed()
	var ev := WorldEvent.new(WorldEvent.Type.SELL, tower.x, tower.y)
	ev.amount = tower.sell_value()
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


func _towers_changed() -> void:
	_tower_grid.fill(null)
	_tower_mask.fill(0)
	for t: Tower in towers:
		var k: int = t.row * Config.COLS + t.col
		_tower_grid[k] = t
		_tower_mask[k] = 1
	if map.maze:
		_flow.dist = map.distance_field(_tower_mask)


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
		elif map.maze:
			nav = FlowNav.new(map, _flow, map.starts[i % map.starts.size()], lane_seed)
		else:
			var roads: Array[Route] = map.routes
			nav = RouteNav.new(roads[i % roads.size()], lane_seed)
		enemy = Enemy.new(type, nav, hp)
	enemies.append(enemy)
	return enemy


## Damages an enemy (armor and shields apply); pays the reward and splits
## splitters when it dies.
func damage_enemy(e: Enemy, amount: float, ignores_armor: bool = false, flash: bool = true) -> void:
	if not e.hit(amount, ignores_armor, flash):
		return
	kills += 1
	money += e.def.reward
	var ev := WorldEvent.new(WorldEvent.Type.KILL, e.x, e.y)
	ev.amount = e.def.reward
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


## A tower fired a bullet.
func fire(b: Bullet, from: Tower) -> void:
	bullets.append(b)
	var ev := WorldEvent.new(WorldEvent.Type.SHOT, b.x, b.y)
	ev.kind = from.kind
	events.append(ev)


## A frost tower pulsed (for effects).
func pulse(t: Tower) -> void:
	var ev := WorldEvent.new(WorldEvent.Type.PULSE, t.x, t.y)
	ev.radius = t.attack_range
	events.append(ev)


func _update_abilities(e: Enemy) -> void:
	var heal: EnemyDef.Heal = e.def.heal
	var summon: EnemyDef.Summon = e.def.summon
	if heal == null and summon == null:
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


# ---- simulation --------------------------------------------------------------

func update() -> void:
	if status != Status.PLAYING:
		return
	tick += 1
	var had_wave: bool = wave_in_progress()

	while not _spawn_queue.is_empty() and _spawn_queue[0].tick <= tick:
		var entry: SpawnEntry = _spawn_queue.pop_front()
		spawn(entry.type)

	for e: Enemy in enemies.duplicate():
		e.update()
		if e.escaped:
			lives = maxi(0, lives - e.def.damage)
			var ev := WorldEvent.new(WorldEvent.Type.LEAK, e.x, e.y)
			ev.amount = e.def.damage
			events.append(ev)
		else:
			_update_abilities(e)

	_update_buffs()
	for t: Tower in towers:
		t.update(self)

	for b: Bullet in bullets:
		var outcome: Bullet.Outcome = b.update(enemies)
		if outcome == Bullet.Outcome.HIT:
			var ev := WorldEvent.new(WorldEvent.Type.HIT, b.x, b.y)
			ev.bullet = b.type
			events.append(ev)
			damage_enemy(b.hit_enemy, b.damage)
		elif outcome == Bullet.Outcome.EXPLODE:
			var ev := WorldEvent.new(WorldEvent.Type.EXPLODE, b.x, b.y)
			ev.radius = b.splash
			events.append(ev)
			for e: Enemy in enemies.duplicate():
				if b.can_hit(e) and MathX.hypot(e.x - b.x, e.y - b.y) <= b.splash + e.radius:
					damage_enemy(e, b.damage)

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
		var interest: int = mini(floori(money * Config.INTEREST_RATE), Config.interest_cap(wave_index))
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


## Beacons boost the fire rate of towers around them (the best one counts).
func _update_buffs() -> void:
	var beacons: Array[Tower] = []
	for t: Tower in towers:
		if t.def.behavior == Towers.Behavior.SUPPORT:
			beacons.append(t)
	for t: Tower in towers:
		t.buff = 0.0
		if t.def.behavior == Towers.Behavior.SUPPORT:
			continue
		for s: Tower in beacons:
			if MathX.hypot(t.x - s.x, t.y - s.y) <= s.attack_range:
				t.buff = maxf(t.buff, s.stats.buff)


# ---- save / resume -------------------------------------------------------------

## A snapshot can only be taken between waves; null otherwise.
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
		save.target_mode = t.target_mode
		save.invested = t.invested
		s.towers.append(save)
	return s


func restore(s: WorldSnapshot) -> void:
	money = s.money
	lives = s.lives
	wave_index = s.wave_index
	waves_cleared = s.waves_cleared
	towers = []
	for save: WorldSnapshot.TowerSave in s.towers:
		if not map.is_buildable_terrain(save.col, save.row) or not Towers.is_kind(save.kind):
			continue
		var tower := Tower.new(save.kind, save.col, save.row, map.is_high_ground(save.col, save.row), save.invested)
		tower.level = clampi(save.level, 0, 2)
		tower.target_mode = save.target_mode
		towers.append(tower)
	_towers_changed()
