class_name WorldSnapshot
extends RefCounted
## Everything needed to resume a game between waves.

const VERSION: int = 1


class TowerSave:
	var kind: String
	var col: int
	var row: int
	var level: int
	var branch: String = "" ## "" before level 4
	var target_mode: Towers.TargetMode
	var invested: int


class WallSave:
	var col: int
	var row: int
	var paid: int


var level_id: String
var endless: bool
var money: int
var lives: int
var wave_index: int
var waves_cleared: int
var towers: Array[TowerSave] = []
var walls: Array[WallSave] = []
var mines: Array[Vector2i] = []
## Ticks left of each ability's cooldown, and the once-per-game abilities used.
var cooldowns: Dictionary[String, int] = {}
var used: Array[String] = []
## Starting bonuses not used up yet (-1: a save from before they existed).
var free_walls: int = -1
var veteran: bool = true
## Run perks taken, the offer waiting (if any), offers made so far, and the
## tower kinds built at least once (free samples).
var run_perks: Array[String] = []
var perk_offer: Array[String] = []
var drafts_made: int = 0
var built_kinds: Array[String] = []


func to_dict() -> Dictionary:
	var list: Array[Dictionary] = []
	for t: TowerSave in towers:
		var item: Dictionary = {
			"kind": t.kind, "col": t.col, "row": t.row, "level": t.level,
			"target_mode": Towers.TARGET_MODE_IDS[t.target_mode], "invested": t.invested,
		}
		if not t.branch.is_empty():
			item["branch"] = t.branch
		list.append(item)
	var wall_list: Array[Dictionary] = []
	for w: WallSave in walls:
		wall_list.append({"col": w.col, "row": w.row, "paid": w.paid})
	var mine_list: Array[Dictionary] = []
	for m: Vector2i in mines:
		mine_list.append({"col": m.x, "row": m.y})
	return {
		"v": VERSION, "level_id": level_id, "endless": endless, "money": money, "lives": lives,
		"wave_index": wave_index, "waves_cleared": waves_cleared, "towers": list,
		"walls": wall_list, "mines": mine_list, "cooldowns": cooldowns, "used": used,
		"free_walls": free_walls, "veteran": veteran, "run_perks": run_perks, "perk_offer": perk_offer,
		"drafts_made": drafts_made, "built_kinds": built_kinds,
	}


## Reads a snapshot written by to_dict() (e.g. parsed from JSON). Returns null
## if it is missing, from another version or malformed; unknown towers are skipped.
## Saves from before walls and abilities existed have none of those keys.
static func from_dict(d: Variant) -> WorldSnapshot:
	if not d is Dictionary:
		return null
	var dict: Dictionary = d
	if JsonRead.int_or(dict.get("v"), -1) != VERSION:
		return null
	for key: String in ["money", "lives", "wave_index", "waves_cleared"]:
		if not JsonRead.is_number(dict.get(key)):
			return null
	if not dict.get("level_id") is String or not dict.get("towers") is Array:
		return null
	var s := WorldSnapshot.new()
	s.level_id = dict["level_id"]
	s.endless = dict.get("endless") == true
	s.money = JsonRead.int_or(dict.get("money"))
	s.lives = JsonRead.int_or(dict.get("lives"))
	s.wave_index = JsonRead.int_or(dict.get("wave_index"))
	s.waves_cleared = JsonRead.int_or(dict.get("waves_cleared"))
	var list: Array = dict["towers"]
	for item: Variant in list:
		if not item is Dictionary:
			continue
		var t: Dictionary = item
		var kind_value: Variant = t.get("kind")
		if not kind_value is String:
			continue
		var kind: String = kind_value
		if not Towers.is_kind(kind) or not JsonRead.is_number(t.get("col")) or not JsonRead.is_number(t.get("row")):
			continue
		var save := TowerSave.new()
		save.kind = kind
		save.col = JsonRead.int_or(t.get("col"))
		save.row = JsonRead.int_or(t.get("row"))
		save.level = JsonRead.int_or(t.get("level"), 0)
		var branch: Variant = t.get("branch")
		if branch is String:
			save.branch = branch
		save.target_mode = Towers.target_mode_from_id(str(t.get("target_mode", "first")))
		save.invested = JsonRead.int_or(t.get("invested"), Towers.get_def(save.kind).levels[0].cost)
		s.towers.append(save)
	_read_walls(dict, s)
	s.free_walls = JsonRead.int_or(dict.get("free_walls"), -1)
	s.veteran = dict.get("veteran") != false
	s.run_perks = _ids(dict.get("run_perks"), RunPerks.is_id)
	s.perk_offer = _ids(dict.get("perk_offer"), RunPerks.is_id)
	s.drafts_made = JsonRead.int_or(dict.get("drafts_made"))
	s.built_kinds = _ids(dict.get("built_kinds"), Towers.is_kind)
	return s


## Strings from a JSON list that `known` accepts.
static func _ids(d: Variant, known: Callable) -> Array[String]:
	var out: Array[String] = []
	if d is Array:
		var list: Array = d
		for item: Variant in list:
			if item is String:
				var id: String = item
				if known.call(id):
					out.append(id)
	return out


static func _read_walls(dict: Dictionary, s: WorldSnapshot) -> void:
	var wall_list: Variant = dict.get("walls")
	if wall_list is Array:
		var items: Array = wall_list
		for item: Variant in items:
			if item is Dictionary:
				var w: Dictionary = item
				if JsonRead.is_number(w.get("col")) and JsonRead.is_number(w.get("row")):
					var save := WallSave.new()
					save.col = JsonRead.int_or(w.get("col"))
					save.row = JsonRead.int_or(w.get("row"))
					save.paid = JsonRead.int_or(w.get("paid"), Abilities.get_def("wall").cost)
					s.walls.append(save)
	var mine_list: Variant = dict.get("mines")
	if mine_list is Array:
		var items: Array = mine_list
		for item: Variant in items:
			if item is Dictionary:
				var m: Dictionary = item
				if JsonRead.is_number(m.get("col")) and JsonRead.is_number(m.get("row")):
					s.mines.append(Vector2i(JsonRead.int_or(m.get("col")), JsonRead.int_or(m.get("row"))))
	var cooldown_map: Variant = dict.get("cooldowns")
	if cooldown_map is Dictionary:
		var map: Dictionary = cooldown_map
		for key: Variant in map:
			if key is String:
				var id: String = key
				if Abilities.is_id(id) and JsonRead.is_number(map[id]):
					var left: int = JsonRead.int_or(map[id])
					if left > 0:
						s.cooldowns[id] = left
	var used_list: Variant = dict.get("used")
	if used_list is Array:
		var ids: Array = used_list
		for item: Variant in ids:
			if item is String:
				var id: String = item
				if Abilities.is_id(id):
					s.used.append(id)

