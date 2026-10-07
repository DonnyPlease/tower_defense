class_name Profile
extends RefCounted
## The player's progress: stars, the tech tree, settings and the game in
## progress. Stored as JSON in user:// (the browser's IndexedDB in web builds).
##
## Version 2 replaced perks bought by rank and towers unlocked by stars earned
## with the tech tree; version 1 profiles are converted when they load.

const VERSION: int = 2
const DEFAULT_PATH: String = "user://profile.json"

## Where a tech tree node stands for this player.
enum TechState { OWNED, AVAILABLE, NEEDS_STARS, NEEDS_EARNED, NEEDS_PARENTS }

## Where the profile is stored (tests point this somewhere else).
static var storage_path: String = DEFAULT_PATH
static var _cached: Profile = null

var stars: Dictionary[String, int] = {} ## best stars per level id
var tech: Dictionary[String, bool] = {} ## tech tree nodes bought with stars
## Nodes owned without spending stars (towers an old profile had already
## unlocked). They can't be refunded.
var free_tech: Dictionary[String, bool] = {}
var endless_best: int = 0 ## most waves cleared in endless mode
var sfx: bool = true
var music: bool = true
var save: WorldSnapshot = null ## game in progress


## The profile (loaded once, then cached). Missing, corrupt or unknown-version
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
		"v": VERSION, "stars": stars, "tech": tech.keys(), "free_tech": free_tech.keys(), "endless_best": endless_best,
		"sfx": sfx, "music": music, "save": save.to_dict() if save != null else null,
	}


## Reads a profile written by to_dict() (this version or version 1); null if
## it is not one.
static func from_dict(d: Variant) -> Profile:
	if not d is Dictionary:
		return null
	var dict: Dictionary = d
	var version: int = JsonRead.int_or(dict.get("v"), -1)
	if version != VERSION and version != 1:
		return null
	var p := Profile.new()
	p.stars = _int_map(dict.get("stars"))
	p.endless_best = JsonRead.int_or(dict.get("endless_best"))
	p.sfx = dict.get("sfx") != false
	p.music = dict.get("music") != false
	p.save = WorldSnapshot.from_dict(dict.get("save"))
	if version == 1:
		p._convert_version_1(_int_map(dict.get("perks")))
	else:
		p.tech = _id_set(dict.get("tech"))
		p.free_tech = _id_set(dict.get("free_tech"))
	return p


## Version 1: perks were ranks (now the rank nodes, at the same price) and
## towers were unlocked by stars earned (now given for free).
func _convert_version_1(ranks: Dictionary[String, int]) -> void:
	for perk: String in ranks:
		if not Perks.IDS.has(perk):
			continue
		for rank: int in range(1, mini(ranks[perk], Perks.get_def(perk).costs.size()) + 1):
			tech[Tech.perk_node(perk, rank)] = true
	var total: int = total_stars()
	for kind: String in Towers.KINDS:
		if Towers.get_def(kind).unlock_stars <= total and not Tech.START.has(kind):
			free_tech[kind] = true


static func _int_map(d: Variant) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	if d is Dictionary:
		var dict: Dictionary = d
		for key: Variant in dict:
			var value: Variant = dict[key]
			if key is String and JsonRead.is_number(value):
				out[str(key)] = JsonRead.int_or(value)
	return out


## Known tech node ids from a JSON list (unknown ones are dropped).
static func _id_set(d: Variant) -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = {}
	if d is Array:
		var list: Array = d
		for item: Variant in list:
			if item is String:
				var id: String = item
				if Tech.is_node(id):
					out[id] = true
	return out


# ---- stars and levels ------------------------------------------------------------

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


func total_stars() -> int:
	var n: int = 0
	for s: int in stars.values():
		n += s
	return n


func is_level_unlocked(index: int) -> bool:
	return index == 0 or stars_on(Levels.LEVELS[index - 1].id) > 0


## Endless mode opens after beating the second level.
func is_endless_unlocked() -> bool:
	return stars_on(Levels.LEVELS[1].id) > 0


## Keeps the best result for a level; returns how many stars it added.
func record_win(level_id: String, earned: int) -> int:
	var before: int = stars_on(level_id)
	stars[level_id] = maxi(before, earned)
	save_profile(self)
	return stars[level_id] - before


## Records an endless run; true if it is a new best.
func record_endless(waves: int) -> bool:
	var best: bool = waves > endless_best
	if best:
		endless_best = waves
		save_profile(self)
	return best


# ---- the tech tree -----------------------------------------------------------------

func owns(id: String) -> bool:
	return Tech.START.has(id) or tech.has(id) or free_tech.has(id)


func tech_state(id: String) -> TechState:
	if owns(id):
		return TechState.OWNED
	var n: Tech.TechNode = Tech.get_node(id)
	for parent: String in n.parents:
		if not owns(parent):
			return TechState.NEEDS_PARENTS
	if total_stars() < n.earned:
		return TechState.NEEDS_EARNED
	if available_stars() < n.cost:
		return TechState.NEEDS_STARS
	return TechState.AVAILABLE


func buy_tech(id: String) -> bool:
	if not Tech.is_node(id) or tech_state(id) != TechState.AVAILABLE:
		return false
	tech[id] = true
	save_profile(self)
	return true


## Gives back every star spent in the tree (free nodes stay).
func refund_tech() -> void:
	tech = {}
	save_profile(self)


func spent_stars() -> int:
	var n: int = 0
	for id: String in tech:
		n += Tech.get_node(id).cost
	return n


func available_stars() -> int:
	return total_stars() - spent_stars()


func unlocked_towers() -> Array[String]:
	var out: Array[String] = []
	for kind: String in Towers.KINDS:
		if owns(kind):
			out.append(kind)
	return out


## Branches not unlocked yet (World.locked_branches).
func locked_branches() -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = {}
	for id: String in Towers.BRANCH_IDS:
		if not owns(id):
			out[id] = true
	return out


## Ranks of a perk owned (0 if none).
func perk_rank(perk: String) -> int:
	var rank: int = 0
	while owns(Tech.perk_node(perk, rank + 1)):
		rank += 1
	return rank


## Level variants unlocked in the tree.
func is_variant_unlocked(variant: String) -> bool:
	return Levels.is_variant(variant) and owns(variant)


## The ways a level can be played: "" (as designed) and the unlocked variants.
func variants_for(level_id: String) -> Array[String]:
	var out: Array[String] = [""]
	if level_id == Levels.ENDLESS.id:
		return out
	for v: String in Levels.VARIANTS:
		if is_variant_unlocked(v):
			out.append(v)
	return out


## What the tree changes in a game: perks and starting bonuses.
func modifiers() -> Perks.Modifiers:
	var ranks: Dictionary[String, int] = {}
	for perk: String in Perks.IDS:
		ranks[perk] = perk_rank(perk)
	var m: Perks.Modifiers = Perks.modifiers_from(ranks)
	m.free_walls = Tech.MASONRY_WALLS if owns("masonry") else 0
	m.veteran = owns("veterans")
	return m
