class_name Abilities
extends RefCounted
## What the player can do during a game besides building towers: the wall
## tool and seven abilities. Every number is here, so they are easy to tune.
## Set an id to false in ENABLED to take an ability out of the game (it loses
## its button and hotkey).

## What an ability needs when it is used.
enum Target {
	NONE, ## works at once
	TILE, ## click a tile (the ability stays picked, to place several)
	POINT, ## click a spot on the field
	ENEMY, ## click an enemy
}

## A ground enemy this close to a mine (to its edge) sets it off.
const MINE_TRIGGER: float = 26.0

const IDS: Array[String] = ["wall", "slow", "boost", "strike", "mine", "bounty", "mark", "wind"]

const ENABLED: Dictionary[String, bool] = {
	"wall": true,
	"slow": true,
	"boost": true,
	"strike": true,
	"mine": true,
	"bounty": true,
	"mark": true,
	"wind": true,
}


class AbilityDef:
	var id: String
	var name: String
	var description: String
	var key: Key ## the hotkey
	var target: Target = Target.NONE
	var cost: int ## money (the wall: the price of the first one)
	var cost_step: int = 0 ## the wall: price rise per wall already built
	var cooldown: float = 0.0 ## seconds until it can be used again
	var duration: float = 0.0 ## seconds an effect lasts (the airstrike: seconds until it lands)
	var power: float = 0.0 ## strength; what it means depends on the ability (see the description)
	var radius: float = 0.0 ## pixels
	var limit: int = 0 ## most that may be in play at once (mines), 0 for no limit
	var once: bool = false ## only once per game

	func key_label() -> String:
		return OS.get_keycode_string(key)


static var _defs: Dictionary[String, AbilityDef] = _build()


static func get_def(id: String) -> AbilityDef:
	assert(_defs.has(id), "Unknown ability '%s'" % id)
	return _defs[id]


static func is_id(id: String) -> bool:
	return _defs.has(id)


## The abilities in the game, in button order.
static func enabled_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in IDS:
		if ENABLED.get(id, false):
			out.append(id)
	return out


static func _def(id: String, name: String, key: Key, target: Target, cost: int, description: String) -> AbilityDef:
	var d := AbilityDef.new()
	d.id = id
	d.name = name
	d.key = key
	d.target = target
	d.cost = cost
	d.description = description
	return d


static func _build() -> Dictionary[String, AbilityDef]:
	var out: Dictionary[String, AbilityDef] = {}

	var wall := _def("wall", "Wall", KEY_Q, Target.TILE, 15,
		"A block enemies must walk around, if there is room (never a full block). A tower built on it gets +25% range.\nOn the road, only where it is wide enough.")
	wall.cost_step = 1
	out["wall"] = wall

	var slow := _def("slow", "Time slow", KEY_W, Target.NONE, 60, "Every enemy moves at half speed.")
	slow.cooldown = 45.0
	slow.duration = 6.0
	slow.power = 0.5 # fraction of their speed they lose
	out["slow"] = slow

	var boost := _def("boost", "Damage boost", KEY_E, Target.NONE, 80, "Towers deal +50% damage.")
	boost.cooldown = 60.0
	boost.duration = 8.0
	boost.power = 0.5 # extra damage
	out["boost"] = boost

	var strike := _def("strike", "Airstrike", KEY_R, Target.POINT, 100,
		"Click a spot: a blast lands there a second later and hurts every enemy around it (damage grows with the waves).")
	strike.cooldown = 40.0
	strike.duration = 1.0 # delay before it lands
	strike.power = 120.0 # damage, times the enemies' hitpoint scale of the wave
	strike.radius = 80.0
	out["strike"] = strike

	var mine := _def("mine", "Landmine", KEY_Z, Target.TILE, 25,
		"Place on ground enemies walk on. The first one to come near sets it off.")
	mine.power = 90.0 # damage, times the hitpoint scale
	mine.radius = 50.0 # blast
	mine.limit = 3
	out["mine"] = mine

	var bounty := _def("bounty", "Bounty", KEY_X, Target.NONE, 50, "Every kill pays double.")
	bounty.cooldown = 60.0
	bounty.duration = 15.0
	bounty.power = 2.0 # reward multiplier
	out["bounty"] = bounty

	var mark := _def("mark", "Focus mark", KEY_C, Target.ENEMY, 40, "Click an enemy: it takes double damage from every tower.")
	mark.cooldown = 25.0
	mark.duration = 6.0
	mark.power = 2.0 # damage multiplier
	out["mark"] = mark

	var wind := _def("wind", "Second wind", KEY_V, Target.NONE, 120, "Restores 3 lives. Once per game.")
	wind.power = 3.0 # lives
	wind.once = true
	out["wind"] = wind

	return out


## Price of the next wall when `built` walls are standing.
static func wall_cost(built: int) -> int:
	var d: AbilityDef = get_def("wall")
	return d.cost + d.cost_step * built
