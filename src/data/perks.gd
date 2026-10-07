class_name Perks
extends RefCounted
## Permanent upgrades bought with stars in the tech tree (each rank is a node,
## see Tech), and what the tree changes in a game (Modifiers).

const IDS: Array[String] = ["capital", "fortify", "engineering", "firepower"]


class PerkDef:
	var id: String
	var name: String
	var costs: Array[int] ## star cost of each rank
	var _effect: String ## describes the effect; %d is the rank's amount
	var _per_rank: int

	func _init(p_id: String, p_name: String, p_effect: String, p_per_rank: int, p_costs: Array[int]) -> void:
		id = p_id
		name = p_name
		_effect = p_effect
		_per_rank = p_per_rank
		costs = p_costs

	## Describes the effect at a given rank (1-based).
	func effect(rank: int) -> String:
		return _effect % (_per_rank * rank)


static var _defs: Dictionary[String, PerkDef] = {
	"capital": PerkDef.new("capital", "War Chest", "+$%d starting money", 40, [1, 2, 3]),
	"fortify": PerkDef.new("fortify", "Fortify", "+%d lives", 5, [1, 2]),
	"engineering": PerkDef.new("engineering", "Engineering", "Towers and upgrades %d%% cheaper", 6, [2, 3]),
	"firepower": PerkDef.new("firepower", "Firepower", "+%d%% tower damage", 8, [2, 3, 4]),
}


static func get_def(id: String) -> PerkDef:
	assert(_defs.has(id), "Unknown perk '%s'" % id)
	return _defs[id]


## What bought perks change in a game.
class Modifiers:
	var money: int = 0 ## added to the level's starting money
	var lives: int = 0
	var cost_multiplier: float = 1.0
	var damage_multiplier: float = 1.0
	var free_walls: int = 0 ## Masonry: walls that cost nothing, per game
	var veteran: bool = false ## Veterans: the first tower built starts at level 2


static func no_modifiers() -> Modifiers:
	return Modifiers.new()


## `ranks` maps perk ids to bought ranks; missing ids count as 0.
static func modifiers_from(ranks: Dictionary[String, int]) -> Modifiers:
	var m := Modifiers.new()
	m.money = 40 * ranks.get("capital", 0)
	m.lives = 5 * ranks.get("fortify", 0)
	m.cost_multiplier = 1 - 0.06 * ranks.get("engineering", 0)
	m.damage_multiplier = 1 + 0.08 * ranks.get("firepower", 0)
	return m
