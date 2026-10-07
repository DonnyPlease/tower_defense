class_name Towers
extends RefCounted
## Tower types. Each tower has 3 levels: levels[0].cost is the build price,
## levels[1] and levels[2] cost is the price of that upgrade. Then it becomes
## one of two branches (TowerBranch), each with two more levels.

enum Behavior { PROJECTILE, BEAM, AURA, SUPPORT }
enum BulletType { NORMAL, MISSILE, SHELL }
enum TargetMode { FIRST, LAST, STRONGEST, CLOSEST }

const TARGET_MODES: Array[TargetMode] = [
	TargetMode.FIRST, TargetMode.LAST, TargetMode.STRONGEST, TargetMode.CLOSEST,
]
## Names used in saved games.
const TARGET_MODE_IDS: Array[String] = ["first", "last", "strongest", "closest"]
const BULLET_TYPE_IDS: Array[String] = ["normal", "missile", "shell"]

## Tower kinds in sidebar order (keys 1-7).
const KINDS: Array[String] = ["gun", "missile", "cannon", "frost", "laser", "support", "magnet"]
## The towers of the original game. The simulated players (balance/) only
## know these, so their random choices, and the balance, stay as they were.
const CLASSIC_KINDS: Array[String] = ["gun", "missile", "cannon", "frost", "laser", "support"]
## Every branch, two per tower in KINDS order.
const BRANCH_IDS: Array[String] = [
	"minigun", "sniper", "swarm", "seeker", "mortar", "siege", "blizzard", "cryo", "prism", "lance", "overclock", "command",
	"vortex", "tesla",
]
## Level index of a branch's first level (levels 0-2 are the tower's own).
const BRANCH_LEVEL: int = 3
const MAX_LEVEL: int = 4

static var _defs: Dictionary[String, TowerDef] = _build()
static var _branches: Dictionary[String, TowerBranch] = _index_branches()


static func get_def(kind: String) -> TowerDef:
	assert(_defs.has(kind), "Unknown tower kind '%s'" % kind)
	return _defs[kind]


static func is_kind(kind: String) -> bool:
	return _defs.has(kind)


static func get_branch(id: String) -> TowerBranch:
	assert(_branches.has(id), "Unknown tower branch '%s'" % id)
	return _branches[id]


static func is_branch(id: String) -> bool:
	return _branches.has(id)


## Stats of a tower at `level` (0-4); levels 3 and 4 need the branch.
static func level_stats(kind: String, level: int, branch_id: String = "") -> TowerLevel:
	if level >= BRANCH_LEVEL and not branch_id.is_empty():
		return get_branch(branch_id).levels[level - BRANCH_LEVEL]
	return get_def(kind).levels[mini(level, BRANCH_LEVEL - 1)]


static func _index_branches() -> Dictionary[String, TowerBranch]:
	var out: Dictionary[String, TowerBranch] = {}
	for kind: String in KINDS:
		for b: TowerBranch in _defs[kind].branches:
			out[b.id] = b
	return out


static func target_mode_from_id(id: String) -> TargetMode:
	var i: int = TARGET_MODE_IDS.find(id)
	return TARGET_MODES[i] if i >= 0 else TargetMode.FIRST


static func _tower(kind: String, name: String, description: String, behavior: Behavior,
		hits_air: bool, hits_ground: bool, unlock_stars: int, color: int,
		levels: Array[TowerLevel]) -> TowerDef:
	var d := TowerDef.new()
	d.kind = kind
	d.name = name
	d.description = description
	d.behavior = behavior
	d.hits_air = hits_air
	d.hits_ground = hits_ground
	d.unlock_stars = unlock_stars
	d.color = Palette.rgb(color)
	d.levels = levels
	return d


static func _build() -> Dictionary[String, TowerDef]:
	var out: Dictionary[String, TowerDef] = {}

	var gun := _tower("gun", "Gun", "Rapid fire. Aims ahead of moving targets. Hits air.",
		Behavior.PROJECTILE, true, true, 0, 0xe63946, [
			TowerLevel.new(100, 170, 3, 3),
			TowerLevel.new(70, 180, 5, 3.5),
			TowerLevel.new(130, 195, 8, 4),
		])
	gun.bullet = BulletType.NORMAL
	gun.bullet_speed = 16
	gun.frames = 7
	gun.branches = [
		TowerBranch.new("minigun", "gun", "Minigun", "Spins up to a hail of bullets. Short range, weak against armor.", 0xff6b4a, [
			TowerLevel.new(200, 150, 6, 10).with_spin_up(2.0),
			TowerLevel.new(260, 160, 7, 14).with_spin_up(1.5),
		]),
		TowerBranch.new("sniper", "gun", "Sniper", "Long range rail shots that go through a line of enemies.", 0xffd166, [
			TowerLevel.new(220, 300, 60, 0.8).with_pierce(3),
			TowerLevel.new(300, 340, 95, 0.9).with_pierce(5),
		]),
	]
	out[gun.kind] = gun

	var missile := _tower("missile", "Missile", "Cheap homing missiles that never miss. Hits air.",
		Behavior.PROJECTILE, true, true, 0, 0x57c26b, [
			TowerLevel.new(50, 200, 6, 0.8),
			TowerLevel.new(50, 215, 10, 0.9),
			TowerLevel.new(90, 230, 16, 1),
		])
	missile.bullet = BulletType.MISSILE
	missile.bullet_speed = 4
	missile.frames = 7
	missile.branches = [
		TowerBranch.new("swarm", "missile", "Swarm", "A volley of small missiles at several enemies at once.", 0x9be564, [
			TowerLevel.new(160, 230, 9, 1).with_volley(4),
			TowerLevel.new(220, 240, 12, 1.1).with_volley(6),
		]),
		TowerBranch.new("seeker", "missile", "Seeker", "One huge homing missile that hits bosses extra hard.", 0x2f9e44, [
			TowerLevel.new(180, 280, 90, 0.4).with_boss_bonus(1.5),
			TowerLevel.new(240, 300, 160, 0.45).with_boss_bonus(2.0),
		]),
	]
	missile.branches[1].bullet_speed = 3.2
	out[missile.kind] = missile

	var cannon := _tower("cannon", "Cannon", "Heavy shells with splash damage. Breaks armor. Ground only.",
		Behavior.PROJECTILE, false, true, 1, 0x8d99ae, [
			TowerLevel.new(120, 160, 16, 0.6).with_splash(45),
			TowerLevel.new(100, 170, 26, 0.65).with_splash(55),
			TowerLevel.new(160, 180, 40, 0.7).with_splash(65),
		])
	cannon.bullet = BulletType.SHELL
	cannon.bullet_speed = 6
	var mortar := TowerBranch.new("mortar", "cannon", "Mortar",
		"Lobs slow shells far away: huge splash, can't hit enemies close by, and fast ones dodge.", 0xc9ada7, [
			TowerLevel.new(220, 300, 60, 0.45).with_splash(95).with_min_range(90),
			TowerLevel.new(300, 330, 95, 0.5).with_splash(110).with_min_range(90),
		])
	mortar.bullet_speed = 2.6
	mortar.leads = false
	var siege := TowerBranch.new("siege", "cannon", "Siege", "Armor-piercing shells: heavy single-target damage, shorter range.", 0x6c757d, [
			TowerLevel.new(200, 150, 110, 0.6).with_splash(22),
			TowerLevel.new(280, 160, 170, 0.65).with_splash(22),
		])
	siege.bullet_speed = 9
	siege.ignores_armor = true
	cannon.branches = [mortar, siege]
	out[cannon.kind] = cannon

	var frost := _tower("frost", "Frost", "Slows every ground enemy in range and chills them with pulses.",
		Behavior.AURA, false, true, 3, 0x7ad3ff, [
			TowerLevel.new(90, 110, 2, 1).with_slow(0.35),
			TowerLevel.new(80, 120, 3, 1).with_slow(0.45),
			TowerLevel.new(120, 135, 5, 1).with_slow(0.55),
		])
	frost.branches = [
		TowerBranch.new("blizzard", "frost", "Blizzard", "A huge field of cold that slows everything in it. No damage.", 0xbfe9ff, [
			TowerLevel.new(160, 185, 0, 1).with_slow(0.65),
			TowerLevel.new(220, 215, 0, 1).with_slow(0.72),
		]),
		TowerBranch.new("cryo", "frost", "Cryo", "Pulses freeze enemies solid; chilled enemies take extra damage from every tower.", 0x4dabf7, [
			TowerLevel.new(180, 130, 10, 0.4).with_slow(0.5).with_freeze(0.5, 0.25),
			TowerLevel.new(240, 140, 16, 0.45).with_slow(0.5).with_freeze(0.7, 0.4),
		]),
	]
	out[frost.kind] = frost

	var laser := _tower("laser", "Laser", "Beam that heats up (up to 3x) on one target. Ignores armor.",
		Behavior.BEAM, true, true, 5, 0xd35cff, [
			TowerLevel.new(150, 150, 9, 1),
			TowerLevel.new(130, 160, 15, 1),
			TowerLevel.new(200, 175, 24, 1),
		])
	laser.ignores_armor = true
	var prism := TowerBranch.new("prism", "laser", "Prism", "Splits its beam over several enemies. Heats up less.", 0xff8cf0, [
			TowerLevel.new(260, 175, 22, 1).with_beams(2).with_heat(0.5, 2.0),
			TowerLevel.new(340, 185, 28, 1).with_beams(3).with_heat(0.5, 2.0),
		])
	prism.ignores_armor = true
	var lance := TowerBranch.new("lance", "laser", "Lance", "One focused beam that heats up faster and far hotter.", 0x9d4edd, [
			TowerLevel.new(240, 185, 30, 1).with_heat(3.0, 1.5),
			TowerLevel.new(320, 195, 40, 1).with_heat(4.0, 1.0),
		])
	lance.ignores_armor = true
	laser.branches = [prism, lance]
	out[laser.kind] = laser

	var support := _tower("support", "Beacon", "Boosts the fire rate of towers in range. Does not attack.",
		Behavior.SUPPORT, false, false, 7, 0xf5c542, [
			TowerLevel.new(120, 100, 0, 0).with_buff(0.2),
			TowerLevel.new(100, 115, 0, 0).with_buff(0.3),
			TowerLevel.new(150, 130, 0, 0).with_buff(0.45),
		])
	support.branches = [
		TowerBranch.new("overclock", "support", "Overclock", "A big fire-rate boost for the towers right next to it.", 0xffa94d, [
			TowerLevel.new(180, 80, 0, 0).with_buff(0.7),
			TowerLevel.new(240, 90, 0, 0).with_buff(0.9),
		]),
		TowerBranch.new("command", "support", "Command", "A smaller boost over a wide area, plus extra range.", 0xffe066, [
			TowerLevel.new(200, 170, 0, 0).with_buff(0.35).with_range_buff(0.15),
			TowerLevel.new(260, 195, 0, 0).with_buff(0.4).with_range_buff(0.22),
		]),
	]
	out[support.kind] = support

	var magnet := _tower("magnet", "Magnet", "Pulls the enemies' way towards it (where they re-route) and slows them in its field.",
		Behavior.AURA, false, true, 9, 0xb197fc, [
			TowerLevel.new(110, 90, 0, 1).with_slow(0.15),
			TowerLevel.new(80, 105, 0, 1).with_slow(0.2),
			TowerLevel.new(110, 120, 0, 1).with_slow(0.25),
		])
	magnet.pulls = true
	magnet.branches = [
		TowerBranch.new("vortex", "magnet", "Vortex", "A much wider field that pulls from further away and slows harder.", 0x9775fa, [
			TowerLevel.new(180, 150, 0, 1).with_slow(0.35),
			TowerLevel.new(240, 175, 0, 1).with_slow(0.45),
		]),
		TowerBranch.new("tesla", "magnet", "Tesla Coil", "Its field also shocks everything in it every second.", 0x66d9e8, [
			TowerLevel.new(200, 115, 14, 1).with_slow(0.25),
			TowerLevel.new(260, 125, 24, 1).with_slow(0.25),
		]),
	]
	out[magnet.kind] = magnet

	return out
