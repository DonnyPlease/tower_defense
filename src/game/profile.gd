class_name Profile
extends RefCounted
## The player's progress: stars, perks, settings and the game in progress.
## Stored as JSON in user:// (the browser's IndexedDB in web builds).

const VERSION: int = 1
const DEFAULT_PATH: String = "user://profile.json"

## Where the profile is stored (tests point this somewhere else).
static var storage_path: String = DEFAULT_PATH
static var _cached: Profile = null

var stars: Dictionary[String, int] = {} ## best stars per level id
var perks: Dictionary[String, int] = {} ## bought ranks
var endless_best: int = 0 ## most waves cleared in endless mode
var sfx: bool = true
var music: bool = true
var save: WorldSnapshot = null ## game in progress


## The profile (loaded once, then cached). Missing, corrupt or other-version
## files give a fresh profile.
static func load_profile() -> Profile:
	if _cached != null:
		return _cached
	var p := Profile.new()
	if FileAccess.file_exists(storage_path):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(storage_path)) == OK:
			var parsed: Profile = from_dict(json.data)
			if parsed != null:
				p = parsed
	_cached = p
	return p


## Writes the profile (default: the loaded one). If storage fails, progress
## lives for this session only.
static func save_profile(p: Profile = null) -> void:
	if p == null:
		p = load_profile()
	_cached = p
	var tmp: String = storage_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_warning("Can't save the profile: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(p.to_dict()))
	file.close()
	# Replace the old file only once the new one is complete.
	if DirAccess.rename_absolute(tmp, storage_path) != OK:
		DirAccess.remove_absolute(storage_path)
		DirAccess.rename_absolute(tmp, storage_path)


## Starts over (keeping the sound settings).
static func reset() -> Profile:
	var keep: Profile = load_profile()
	var p := Profile.new()
	p.sfx = keep.sfx
	p.music = keep.music
	save_profile(p)
	return p


## Forgets the cached profile, so the next load reads storage again (tests).
static func forget_cache() -> void:
	_cached = null


func to_dict() -> Dictionary:
	return {
		"v": VERSION, "stars": stars, "perks": perks, "endless_best": endless_best,
		"sfx": sfx, "music": music, "save": save.to_dict() if save != null else null,
	}


## Reads a profile written by to_dict(); null if it is not one (or another version).
static func from_dict(d: Variant) -> Profile:
	if not d is Dictionary:
		return null
	var dict: Dictionary = d
	if JsonRead.int_or(dict.get("v"), -1) != VERSION:
		return null
	var p := Profile.new()
	p.stars = _int_map(dict.get("stars"))
	p.perks = _int_map(dict.get("perks"))
	p.endless_best = JsonRead.int_or(dict.get("endless_best"))
	p.sfx = dict.get("sfx") != false
	p.music = dict.get("music") != false
	p.save = WorldSnapshot.from_dict(dict.get("save"))
	return p


static func _int_map(d: Variant) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	if d is Dictionary:
		var dict: Dictionary = d
		for key: Variant in dict:
			var value: Variant = dict[key]
			if key is String and JsonRead.is_number(value):
				out[str(key)] = JsonRead.int_or(value)
	return out


# ---- stars and unlocks ---------------------------------------------------------

## 3 stars for losing no lives, 2 for keeping at least half, else 1.
static func stars_for(lives: int, start_lives: int) -> int:
	if lives >= start_lives:
		return 3
	if lives >= start_lives / 2.0:
		return 2
	return 1


## Best stars earned on a level (0 if not won yet).
func stars_on(level_id: String) -> int:
	return stars[level_id] if stars.has(level_id) else 0


## Bought rank of a perk (0 if none).
func perk_rank(id: String) -> int:
	return perks[id] if perks.has(id) else 0


func total_stars() -> int:
	var n: int = 0
	for s: int in stars.values():
		n += s
	return n


func spent_stars() -> int:
	var n: int = 0
	for id: String in Perks.IDS:
		var costs: Array[int] = Perks.get_def(id).costs
		for i: int in mini(perk_rank(id), costs.size()):
			n += costs[i]
	return n


func available_stars() -> int:
	return total_stars() - spent_stars()


func unlocked_towers() -> Array[String]:
	var total: int = total_stars()
	var out: Array[String] = []
	for kind: String in Towers.KINDS:
		if Towers.get_def(kind).unlock_stars <= total:
			out.append(kind)
	return out


func is_level_unlocked(index: int) -> bool:
	return index == 0 or stars_on(Levels.LEVELS[index - 1].id) > 0


## Endless mode opens after beating the second level.
func is_endless_unlocked() -> bool:
	return stars_on(Levels.LEVELS[1].id) > 0


## Keeps the best result for a level; returns the towers this unlocked.
func record_win(level_id: String, earned: int) -> Array[String]:
	var before: Array[String] = unlocked_towers()
	stars[level_id] = maxi(stars_on(level_id), earned)
	var new_towers: Array[String] = []
	for kind: String in unlocked_towers():
		if not before.has(kind):
			new_towers.append(kind)
	save_profile(self)
	return new_towers


## Records an endless run; true if it is a new best.
func record_endless(waves: int) -> bool:
	var best: bool = waves > endless_best
	if best:
		endless_best = waves
		save_profile(self)
	return best


# ---- perks -----------------------------------------------------------------------

## Star cost of the perk's next rank, or -1 when it is maxed.
func next_perk_cost(id: String) -> int:
	var rank: int = perk_rank(id)
	var costs: Array[int] = Perks.get_def(id).costs
	return costs[rank] if rank < costs.size() else -1


func buy_perk(id: String) -> bool:
	var cost: int = next_perk_cost(id)
	if cost < 0 or cost > available_stars():
		return false
	perks[id] = perk_rank(id) + 1
	save_profile(self)
	return true


func refund_perks() -> void:
	perks = {}
	save_profile(self)


func modifiers() -> Perks.Modifiers:
	return Perks.modifiers_from(perks)
