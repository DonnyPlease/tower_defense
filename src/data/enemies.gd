class_name Enemies
extends RefCounted
## Enemy types.

const TYPES: Array[String] = [
	"scout", "racer", "tank", "armored", "shielded", "splitter", "mini", "healer", "drone", "brute", "boss",
	"saboteur", "hopper", "warchief", "colossus",
]

static var _defs: Dictionary[String, EnemyDef] = _build()


static func get_def(type: String) -> EnemyDef:
	assert(_defs.has(type), "Unknown enemy type '%s'" % type)
	return _defs[type]


static func is_type(type: String) -> bool:
	return _defs.has(type)


static func _enemy(type: String, name: String, art: String, speed: float, hitpoints: float, reward: int,
		damage: int, radius: float, description: String) -> EnemyDef:
	var d := EnemyDef.new()
	d.type = type
	d.name = name
	d.art = art
	d.speed = speed
	d.hitpoints = hitpoints
	d.reward = reward
	d.damage = damage
	d.radius = radius
	d.description = description
	return d


static func _build() -> Dictionary[String, EnemyDef]:
	var out: Dictionary[String, EnemyDef] = {}

	out["scout"] = _enemy("scout", "Scout", "scout", 1.5, 20, 5, 1, 14, "Basic light tank.")
	out["racer"] = _enemy("racer", "Racer", "racer", 3.0, 14, 6, 1, 14, "Very fast, fragile.")
	out["tank"] = _enemy("tank", "Tank", "tank", 1.0, 110, 18, 3, 17, "Slow and tough. Costs 3 lives.")

	var armored := _enemy("armored", "Armored", "armored", 1.1, 60, 15, 2, 16,
		"Armor 4: weak hits barely scratch it. Use cannons or lasers.")
	armored.armor = 4
	out["armored"] = armored

	var shielded := _enemy("shielded", "Shielded", "shielded", 1.4, 30, 12, 1, 15,
		"Energy shield that recharges when not hit for 3 s.")
	shielded.shield = 30
	out["shielded"] = shielded

	var splitter := _enemy("splitter", "Splitter", "splitter", 1.2, 60, 10, 2, 16, "Splits into 3 minis when destroyed.")
	splitter.split = EnemyDef.Split.new("mini", 3)
	out["splitter"] = splitter

	var mini := _enemy("mini", "Mini", "splitter", 2.0, 12, 2, 1, 9, "Fragment of a splitter.")
	mini.scale = 0.55
	out["mini"] = mini

	var healer := _enemy("healer", "Medic", "healer", 1.3, 45, 14, 1, 15, "Repairs nearby enemies every second. Kill it first.")
	healer.heal = EnemyDef.Heal.new(85, 0.06, 1)
	out["healer"] = healer

	var drone := _enemy("drone", "Drone", "drone", 1.6, 22, 8, 1, 13,
		"Flies straight over everything. Only Gun, Missile and Laser can hit it.")
	drone.flying = true
	out["drone"] = drone

	var brute := _enemy("brute", "Juggernaut", "tank", 0.7, 500, 60, 5, 22,
		"Mini-boss. Very tough but unarmored. Costs 5 lives.")
	brute.tint = Palette.rgb(0xffa94d)
	brute.has_tint = true
	brute.scale = 1.4
	brute.boss = true
	out["brute"] = brute

	var boss := _enemy("boss", "Warlord", "tank", 0.55, 1200, 150, 10, 26,
		"Boss. Armored, calls in reinforcements. Costs 10 lives.")
	boss.tint = Palette.rgb(0xff6b6b)
	boss.has_tint = true
	boss.scale = 1.75
	boss.armor = 3
	boss.boss = true
	boss.summon = EnemyDef.Summon.new("scout", 2, 7)
	out["boss"] = boss

	var saboteur := _enemy("saboteur", "Saboteur", "saboteur", 1.4, 50, 14, 1, 15,
		"Every 4 s an EMP switches off the towers near it for 2.5 s.")
	saboteur.emp = EnemyDef.Emp.new(80, 2.5, 4)
	out["saboteur"] = saboteur

	var hopper := _enemy("hopper", "Hopper", "hopper", 1.5, 40, 12, 1, 14,
		"Jumps over walls and towers: a maze can't hold it.")
	hopper.hops = true
	out["hopper"] = hopper

	var warchief := _enemy("warchief", "Warchief", "warchief", 1.0, 150, 25, 2, 18,
		"Enemies near it move 30% faster and take 25% less damage. Kill it first.")
	warchief.rally = EnemyDef.Rally.new(90, 0.3, 0.25)
	out["warchief"] = warchief

	var colossus := _enemy("colossus", "Colossus", "colossus", 0.5, 2600, 300, 15, 28,
		"Final boss. Heavy armor, then rage, then a shield and reinforcements. Costs 15 lives.")
	colossus.armor = 5
	colossus.scale = 1.6
	colossus.boss = true
	colossus.phases = [
		EnemyDef.Phase.new(0.66, "The Colossus sheds its armor!", 0, 1.6),
		EnemyDef.Phase.new(0.33, "The Colossus calls for help!", 0, 1.6).with_summon("warchief", 2).with_shield(300),
	]
	out["colossus"] = colossus

	return out
