class_name Towers
extends RefCounted
## Tower types. Each tower has 3 levels: levels[0].cost is the build price,
## levels[1] and levels[2] cost is the price of that upgrade.

enum Behavior { PROJECTILE, BEAM, AURA, SUPPORT }
enum BulletType { NORMAL, MISSILE, SHELL }
enum TargetMode { FIRST, LAST, STRONGEST, CLOSEST }

const TARGET_MODES: Array[TargetMode] = [
	TargetMode.FIRST, TargetMode.LAST, TargetMode.STRONGEST, TargetMode.CLOSEST,
]
## Names used in saved games.
const TARGET_MODE_IDS: Array[String] = ["first", "last", "strongest", "closest"]
const BULLET_TYPE_IDS: Array[String] = ["normal", "missile", "shell"]

## Tower kinds in sidebar order (keys 1-6).
const KINDS: Array[String] = ["gun", "missile", "cannon", "frost", "laser", "support"]

static var _defs: Dictionary[String, TowerDef] = _build()


static func get_def(kind: String) -> TowerDef:
	assert(_defs.has(kind), "Unknown tower kind '%s'" % kind)
	return _defs[kind]


static func is_kind(kind: String) -> bool:
	return _defs.has(kind)


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
	out[missile.kind] = missile

	var cannon := _tower("cannon", "Cannon", "Heavy shells with splash damage. Breaks armor. Ground only.",
		Behavior.PROJECTILE, false, true, 1, 0x8d99ae, [
			TowerLevel.new(120, 160, 16, 0.6).with_splash(45),
			TowerLevel.new(100, 170, 26, 0.65).with_splash(55),
			TowerLevel.new(160, 180, 40, 0.7).with_splash(65),
		])
	cannon.bullet = BulletType.SHELL
	cannon.bullet_speed = 6
	out[cannon.kind] = cannon

	var frost := _tower("frost", "Frost", "Slows every ground enemy in range and chills them with pulses.",
		Behavior.AURA, false, true, 3, 0x7ad3ff, [
			TowerLevel.new(90, 110, 2, 1).with_slow(0.35),
			TowerLevel.new(80, 120, 3, 1).with_slow(0.45),
			TowerLevel.new(120, 135, 5, 1).with_slow(0.55),
		])
	out[frost.kind] = frost

	var laser := _tower("laser", "Laser", "Beam that heats up (up to 3x) on one target. Ignores armor.",
		Behavior.BEAM, true, true, 5, 0xd35cff, [
			TowerLevel.new(150, 150, 9, 1),
			TowerLevel.new(130, 160, 15, 1),
			TowerLevel.new(200, 175, 24, 1),
		])
	laser.ignores_armor = true
	out[laser.kind] = laser

	var support := _tower("support", "Beacon", "Boosts the fire rate of towers in range. Does not attack.",
		Behavior.SUPPORT, false, false, 7, 0xf5c542, [
			TowerLevel.new(120, 100, 0, 0).with_buff(0.2),
			TowerLevel.new(100, 115, 0, 0).with_buff(0.3),
			TowerLevel.new(150, 130, 0, 0).with_buff(0.45),
		])
	out[support.kind] = support

	return out
