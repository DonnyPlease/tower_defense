class_name RunPerks
extends RefCounted
## Run perks ("field orders"): perks that change how one game plays. Once
## unlocked in the tech tree, a game offers a few at its start and after
## waves 5 and 10 (see DRAFTS); the player keeps one of each offer.

## Waves cleared before each offer (0: at the start of the game).
const DRAFTS: Array[int] = [0, 5, 10]
const PIERCE: int = 1 ## piercing: extra enemies a gun bullet goes through
const WIDE_BEACON_RANGE: float = 0.15 ## wide beacons: range bonus near a beacon
const DEMOLITION_SPLASH: float = 1.3 ## demolition: cannon splash multiplier
const HILL_FORT_PRICE: float = 0.75 ## hill forts: price of towers on high ground or walls
const STONEWORK_WALL: int = 10 ## stonework: price of every wall
const HEADHUNTER_BONUS: int = 2 ## headhunter: extra money per kill
const QUICK_COOLDOWN: float = 0.6 ## quick hands: cooldown multiplier
const REINFORCEMENTS: int = 10 ## reinforcements: extra lives

const IDS: Array[String] = [
	"piercing", "shatter", "widebeacons", "greed", "hillforts", "samples", "quickhands", "headhunter",
	"demolition", "overcharge", "reinforcements", "stonework",
]


class RunPerkDef:
	var id: String
	var name: String
	var description: String

	func _init(p_id: String, p_name: String, p_description: String) -> void:
		id = p_id
		name = p_name
		description = p_description


static var _defs: Dictionary[String, RunPerkDef] = {
	"piercing": RunPerkDef.new("piercing", "Piercing Rounds", "Gun bullets go through one more enemy."),
	"shatter": RunPerkDef.new("shatter", "Shatter", "Frost pulses break half of every shield they touch."),
	"widebeacons": RunPerkDef.new("widebeacons", "Wide Beacons", "Beacons also give +15% range to towers near them."),
	"greed": RunPerkDef.new("greed", "Greed", "Double interest between waves, but half your lives."),
	"hillforts": RunPerkDef.new("hillforts", "Hill Forts", "Towers on high ground or on a wall cost 25% less."),
	"samples": RunPerkDef.new("samples", "Free Samples", "The first tower of each kind is free."),
	"quickhands": RunPerkDef.new("quickhands", "Quick Hands", "Ability cooldowns are 40% shorter."),
	"headhunter": RunPerkDef.new("headhunter", "Headhunter", "Every kill pays $2 more."),
	"demolition": RunPerkDef.new("demolition", "Demolition", "Cannon shells (and mortars, siege) splash 30% wider."),
	"overcharge": RunPerkDef.new("overcharge", "Overcharge", "Lasers heat up twice as fast."),
	"reinforcements": RunPerkDef.new("reinforcements", "Reinforcements", "+10 lives right now."),
	"stonework": RunPerkDef.new("stonework", "Stonework", "Every wall costs $10: the price never rises."),
}


static func get_def(id: String) -> RunPerkDef:
	assert(_defs.has(id), "Unknown run perk '%s'" % id)
	return _defs[id]


static func is_id(id: String) -> bool:
	return _defs.has(id)
