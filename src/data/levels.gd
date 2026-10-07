class_name Levels
extends RefCounted
## The levels, and the endless wave generator. See LevelDef for the tile letters.

static var LEVELS: Array[LevelDef] = _build()
static var ENDLESS: LevelDef = _build_endless()


## A level by id; "meadow@night" is Meadow's night variant.
static func by_id(id: String) -> LevelDef:
	var at: int = id.find("@")
	if at >= 0:
		return with_variant(by_id(id.substr(0, at)), id.substr(at + 1))
	for level: LevelDef in LEVELS:
		if level.id == id:
			return level
	if id == ENDLESS.id:
		return ENDLESS
	assert(false, "Unknown level '%s'" % id)
	return null


static func _g(type: String, count: int, interval: float, delay: float = 0.0) -> SpawnGroup:
	return SpawnGroup.new(type, count, interval, delay)


static func _level(id: String, name: String, description: String, money: int, lives: int, hp_scale: float,
		tiles: PackedStringArray, waves: Array[Wave], maze: bool = false, road_walls: bool = false) -> LevelDef:
	var l := LevelDef.new()
	l.id = id
	l.base_id = id
	l.name = name
	l.description = description
	l.money = money
	l.lives = lives
	l.hp_scale = hp_scale
	l.tiles = tiles
	l.waves = waves
	l.maze = maze
	l.road_walls = road_walls
	return l


static func _build() -> Array[LevelDef]:
	var meadow := _level("meadow", "Meadow", "A gentle start. Learn the basics.", 250, 20,
		1.01, # tuned with the balance tuner (without walls or abilities)
		PackedStringArray([
			"....................",
			"....................",
			"...........######...",
			"...........######...",
			"...........###.###..",
			"..........###..####.",
			"..........###...###E",
			"..........###...###E",
			".........####.......",
			"........####........",
			"S#####.#####........",
			"S###########........",
			"S##########.........",
			"....................",
			"....................",
		]), [
			Wave.new([_g("scout", 8, 1.0)]),
			Wave.new([_g("scout", 12, 0.7)]),
			Wave.new([_g("scout", 8, 0.8), _g("racer", 5, 0.7, 3)]),
			Wave.new([_g("tank", 3, 2.5), _g("scout", 10, 0.6, 2)]),
			Wave.new([_g("racer", 14, 0.45)]),
			Wave.new([_g("tank", 4, 2), _g("scout", 12, 0.5, 1)]),
			Wave.new([_g("tank", 6, 1.6), _g("racer", 10, 0.45, 3)]),
			Wave.new([_g("brute", 1, 1), _g("scout", 14, 0.6, 2), _g("tank", 3, 2, 6)]),
		], false, true)

	var riverside := _level("riverside", "Riverside", "Two roads, one bridge. Watch the sky.", 350, 20,
		0.97, # tuned with the balance tuner
		PackedStringArray([
			".........~~.........",
			".........~~.........",
			".........~~..#####..",
			"S#####...~~..#...#..",
			".....#...~~..#...#..",
			".....#...~~..#...#..",
			".....#...~~..#...#..",
			".....####==###...#..",
			".....#...~~......#..",
			".....#...~~......#..",
			".....#...~~......#..",
			"S#####...~~......##E",
			".........~~.........",
			".........~~.........",
			".........~~.........",
		]), [
			Wave.new([_g("scout", 10, 0.8)]),
			Wave.new([_g("scout", 8, 0.7), _g("racer", 6, 0.6, 3)]),
			Wave.new([_g("drone", 5, 1.2)]),
			Wave.new([_g("shielded", 6, 1.0), _g("scout", 8, 0.6, 2)]),
			Wave.new([_g("tank", 4, 2), _g("healer", 2, 4, 1), _g("scout", 10, 0.5, 3)]),
			Wave.new([_g("drone", 8, 0.7), _g("racer", 10, 0.45, 3)]),
			Wave.new([_g("armored", 6, 1.5), _g("healer", 3, 3, 2)]),
			Wave.new([_g("shielded", 12, 0.5), _g("drone", 8, 0.7, 4)]),
			Wave.new([_g("tank", 8, 1.2), _g("healer", 4, 2.5, 2), _g("racer", 12, 0.35, 5)]),
			Wave.new([_g("boss", 1, 1), _g("shielded", 8, 0.7, 3), _g("drone", 8, 0.6, 6), _g("healer", 2, 4, 4)]),
		])

	var highlands := _level("highlands", "Highlands", "A long winding road. Hold the high ground.", 320, 20,
		0.99, # tuned with the balance tuner (without walls or abilities)
		PackedStringArray([
			"....................",
			"S##########HH.......",
			"..#########.RR......",
			"..HH.....##.........",
			"..HH.....######.....",
			"..............#..R..",
			"..#############.....",
			"..########RR........",
			"..##....HH..........",
			"..##....HH..........",
			"..###########.......",
			"..###########...HH..",
			"..RR........####HH..",
			"............#######E",
			"....................",
		]), [
			Wave.new([_g("scout", 12, 0.7)]),
			Wave.new([_g("splitter", 5, 1.5)]),
			Wave.new([_g("racer", 12, 0.4), _g("drone", 5, 1, 3)]),
			Wave.new([_g("armored", 6, 1.5), _g("scout", 10, 0.5, 2)]),
			Wave.new([_g("splitter", 8, 1.1), _g("healer", 2, 4, 2)]),
			Wave.new([_g("boss", 1, 1), _g("scout", 12, 0.6, 3)]),
			Wave.new([_g("shielded", 12, 0.6), _g("drone", 8, 0.8, 3)]),
			Wave.new([_g("tank", 8, 1.2), _g("armored", 6, 1.4, 4)]),
			Wave.new([_g("splitter", 12, 0.8), _g("healer", 4, 2.5, 3)]),
			Wave.new([_g("racer", 25, 0.25), _g("drone", 12, 0.5, 4)]),
			Wave.new([_g("armored", 10, 1), _g("shielded", 12, 0.5, 3), _g("healer", 4, 2.5, 5)]),
			Wave.new([_g("boss", 2, 8), _g("splitter", 10, 0.9, 3), _g("tank", 8, 1.2, 8)]),
		], false, true)

	var openfield := _level("openfield", "Open Field", "No road at all. Build a maze with your towers.", 500, 20,
		0.94, # tuned with the balance tuner
		PackedStringArray([
			"RRRRRRRRRRRRRRRRRRRR",
			"......R.............",
			"......R.............",
			"......R......R......",
			"......R......R......",
			"......R......R......",
			"S.....R......R.....E",
			"S............R.....E",
			"S............R.....E",
			"......R......R......",
			"......R.............",
			"......R.............",
			"......R.............",
			"......R.............",
			"RRRRRRRRRRRRRRRRRRRR",
		]), [
			Wave.new([_g("scout", 12, 0.8)]),
			Wave.new([_g("racer", 12, 0.5)]),
			Wave.new([_g("tank", 4, 2), _g("scout", 10, 0.5, 2)]),
			Wave.new([_g("shielded", 10, 0.7), _g("drone", 4, 1.2, 3)]),
			Wave.new([_g("splitter", 8, 1.2)]),
			Wave.new([_g("armored", 8, 1.3), _g("healer", 3, 3, 2)]),
			Wave.new([_g("drone", 10, 0.6), _g("shielded", 10, 0.6, 3)]),
			Wave.new([_g("boss", 1, 1), _g("racer", 12, 0.4, 3)]),
			Wave.new([_g("tank", 10, 1.1), _g("healer", 4, 2.5, 2)]),
			Wave.new([_g("splitter", 14, 0.7), _g("armored", 8, 1.2, 4)]),
			Wave.new([_g("racer", 30, 0.2), _g("drone", 14, 0.45, 3), _g("shielded", 12, 0.5, 6)]),
			Wave.new([_g("boss", 2, 10), _g("armored", 12, 0.9, 2), _g("splitter", 12, 0.8, 6), _g("healer", 5, 2, 4)]),
		], true)

	var citadel := _level("citadel", "Citadel", "Wide roads, and the enemies that beat mazes. The Colossus awaits.", 400, 20,
		1.03, # tuned with the balance tuner (without walls or abilities)
		PackedStringArray([
			"....................",
			"S#####..............",
			"S#####.......HH.....",
			"....##.......HH.....",
			"....##..............",
			"....##########......",
			"....##########..R...",
			"..HH........##..R...",
			"..HH........##......",
			"......########......",
			"......########...HH.",
			"......##.........HH.",
			"......#############E",
			"......#############E",
			"....................",
		]), [
			Wave.new([_g("scout", 12, 0.6)]),
			Wave.new([_g("hopper", 8, 1.0)]),
			Wave.new([_g("racer", 10, 0.4), _g("saboteur", 2, 3, 2)]),
			Wave.new([_g("tank", 4, 2), _g("warchief", 1, 1, 3), _g("scout", 10, 0.5, 1)]),
			Wave.new([_g("shielded", 10, 0.6), _g("hopper", 8, 0.8, 3)]),
			Wave.new([_g("armored", 6, 1.3), _g("saboteur", 3, 2.5, 2)]),
			Wave.new([_g("boss", 1, 1), _g("hopper", 10, 0.6, 3)]),
			Wave.new([_g("splitter", 10, 1.0), _g("warchief", 2, 4, 2)]),
			Wave.new([_g("drone", 10, 0.6), _g("saboteur", 4, 2, 2), _g("racer", 12, 0.35, 4)]),
			Wave.new([_g("tank", 8, 1.1), _g("warchief", 3, 3, 2), _g("healer", 3, 3, 3)]),
			Wave.new([_g("hopper", 20, 0.4), _g("shielded", 12, 0.5, 3)]),
			Wave.new([_g("armored", 10, 1), _g("saboteur", 5, 1.8, 2), _g("warchief", 3, 3, 5)]),
			Wave.new([_g("brute", 2, 5), _g("splitter", 12, 0.8, 2), _g("hopper", 14, 0.5, 6)]),
			Wave.new([_g("colossus", 1, 1), _g("warchief", 2, 4, 4), _g("shielded", 12, 0.6, 6), _g("drone", 10, 0.6, 8)]),
		], false, true)

	return [meadow, riverside, highlands, openfield, citadel]


# ---- Variants -------------------------------------------------------------------

## Twists on the same maps. Each is unlocked in the tech tree (the node has the
## variant's id) and earns stars of its own.
const VARIANTS: Array[String] = ["night", "reversed", "laststand", "nogun"]


class LevelVariant:
	var id: String
	var name: String
	var description: String
	var tower_range: float = 1.0
	var lives: int = 0 ## 0: the level's own
	var banned: Array[String] = []
	var reversed: bool = false

	func _init(p_id: String, p_name: String, p_description: String) -> void:
		id = p_id
		name = p_name
		description = p_description


static var _variants: Dictionary[String, LevelVariant] = _build_variants()


static func _build_variants() -> Dictionary[String, LevelVariant]:
	var night := LevelVariant.new("night", "Night", "It's dark: every tower sees 20% less far.")
	night.tower_range = 0.8
	var reversed := LevelVariant.new("reversed", "Reversed", "Enemies come in where they used to leave, and leave where they came in.")
	reversed.reversed = true
	var last := LevelVariant.new("laststand", "Last Stand", "Only 5 lives.")
	last.lives = 5
	var nogun := LevelVariant.new("nogun", "No Gun", "The Gun can't be built.")
	nogun.banned = ["gun"]
	return {"night": night, "reversed": reversed, "laststand": last, "nogun": nogun}


static func get_variant(id: String) -> LevelVariant:
	assert(_variants.has(id), "Unknown variant '%s'" % id)
	return _variants[id]


static func is_variant(id: String) -> bool:
	return _variants.has(id)


## The level with a variant applied ("" or an unknown variant: the level itself).
static func with_variant(level: LevelDef, variant_id: String) -> LevelDef:
	if not is_variant(variant_id) or level.id == ENDLESS.id:
		return level
	var v: LevelVariant = get_variant(variant_id)
	var l: LevelDef = level.with_hp_scale(level.hp_scale)
	l.id = "%s@%s" % [level.id, v.id]
	l.variant = v.id
	l.name = "%s (%s)" % [level.name, v.name]
	l.tower_range = v.tower_range
	l.banned = v.banned
	if v.lives > 0:
		l.lives = v.lives
	if v.reversed:
		var tiles: PackedStringArray = []
		for row: String in level.tiles:
			tiles.append(row.replace("S", "?").replace("E", "S").replace("?", "E"))
		l.tiles = tiles
	return l


# ---- Endless mode ------------------------------------------------------------

static func _build_endless() -> LevelDef:
	return _level("endless", "Endless", "Waves never stop. How long can you last?", 350, 20,
		1.30, # tuned (balance/tune.gd -- endless): average players survive about 20 waves, without walls or abilities
		LEVELS[2].tiles, [], false, true)


## Threat cost of each enemy type, and the first endless wave it may appear in.
class PoolEntry:
	var type: String
	var cost: float
	var from: int
	var interval: float

	func _init(p_type: String, p_cost: float, p_from: int, p_interval: float) -> void:
		type = p_type
		cost = p_cost
		from = p_from
		interval = p_interval


static var ENDLESS_POOL: Array[PoolEntry] = [
	PoolEntry.new("scout", 4, 0, 0.6),
	PoolEntry.new("racer", 4, 1, 0.35),
	PoolEntry.new("tank", 14, 2, 1.4),
	PoolEntry.new("drone", 7, 3, 0.6),
	PoolEntry.new("shielded", 9, 4, 0.6),
	PoolEntry.new("armored", 12, 5, 1.2),
	PoolEntry.new("splitter", 12, 6, 1.0),
	PoolEntry.new("healer", 14, 7, 2.5),
]


## Wave `index` of endless mode: the classic wave, plus (from wave 7) the
## enemies that beat mazes and builds: hoppers, saboteurs, warchiefs and,
## every 25 waves, the Colossus. Deterministic: the same index gives the same wave.
static func endless_wave(index: int) -> Wave:
	var wave: Wave = classic_endless_wave(index)
	if index < 6:
		return wave
	var rand := Mulberry32.new(index * 104729 + 3)
	var delay: float = 3 + rand.next() * 4
	wave.groups.append(_g("hopper", mini(20, 2 + floori(index / 4.0)), 0.6, delay))
	if index >= 9 and index % 2 == 1:
		wave.groups.append(_g("saboteur", 1 + floori(index / 10.0), 2.5, delay + 2 + rand.next() * 3))
	if index >= 12 and index % 3 == 0:
		wave.groups.append(_g("warchief", 1 + floori(index / 15.0), 4, delay + 1 + rand.next() * 3))
	if (index + 1) % 25 == 0:
		wave.groups.append(_g("colossus", floori((index + 1) / 25.0), 10, 2))
	return wave


## The endless wave as the original game made it (still matches it exactly).
static func classic_endless_wave(index: int) -> Wave:
	var rand := Mulberry32.new(index * 7919 + 17)
	var wave := Wave.new()
	var budget: float = 40 + 18 * index + 0.8 * index * index
	var delay: float = 0.0
	if index > 0 and (index + 1) % 10 == 0:
		var bosses: int = floori((index + 1) / 10.0)
		wave.groups.append(_g("boss", bosses, 8))
		budget *= 0.5
		delay = 3
	var pool: Array[PoolEntry] = ENDLESS_POOL.filter(func(p: PoolEntry) -> bool: return p.from <= index)
	var groups: int = mini(4, 1 + floori(index / 3.0))
	var i: int = 0
	while i < groups and budget > 4:
		var p: PoolEntry = pool[floori(rand.next() * pool.size())]
		var share: float = budget if i == groups - 1 else budget * (0.3 + rand.next() * 0.4)
		if p.type == "drone":
			share *= 0.5 # only some towers can hit them
		var count: int = maxi(1, mini(30, MathX.js_round(share / p.cost)))
		wave.groups.append(_g(p.type, count, p.interval, delay))
		budget -= count * p.cost
		delay += 2 + rand.next() * 3
		i += 1
	return wave
