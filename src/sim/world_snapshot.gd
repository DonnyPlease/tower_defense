class_name WorldSnapshot
extends RefCounted
## Everything needed to resume a game between waves.

const VERSION: int = 1


class TowerSave:
	var kind: String
	var col: int
	var row: int
	var level: int
	var target_mode: Towers.TargetMode
	var invested: int


var level_id: String
var endless: bool
var money: int
var lives: int
var wave_index: int
var waves_cleared: int
var towers: Array[TowerSave] = []


func to_dict() -> Dictionary:
	var list: Array[Dictionary] = []
	for t: TowerSave in towers:
		list.append({
			"kind": t.kind, "col": t.col, "row": t.row, "level": t.level,
			"target_mode": Towers.TARGET_MODE_IDS[t.target_mode], "invested": t.invested,
		})
	return {
		"v": VERSION, "level_id": level_id, "endless": endless, "money": money, "lives": lives,
		"wave_index": wave_index, "waves_cleared": waves_cleared, "towers": list,
	}


## Reads a snapshot written by to_dict() (e.g. parsed from JSON). Returns null
## if it is missing, from another version or malformed; unknown towers are skipped.
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
		save.target_mode = Towers.target_mode_from_id(str(t.get("target_mode", "first")))
		save.invested = JsonRead.int_or(t.get("invested"), Towers.get_def(save.kind).levels[0].cost)
		s.towers.append(save)
	return s

