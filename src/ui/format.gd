class_name Format
extends RefCounted
## Pure formatting and maths helpers for the UI (unit-tested headlessly).


static func lerp_value(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


## Interpolates between two angles along the shorter way round.
static func lerp_angle_short(a: float, b: float, t: float) -> float:
	return a + MathX.angle_diff(a, b) * t


static func star_string(stars: int, max_stars: int = 3) -> String:
	return "★".repeat(stars) + "☆".repeat(maxi(0, max_stars - stars))


## A number the way JavaScript prints it: no ".0" on whole numbers.
static func num(x: float) -> String:
	return str(int(x)) if x == floorf(x) and absf(x) < 1e15 else str(x)


## A count kept short: 950, 12.3k, 4.1M.
static func compact(x: float) -> String:
	var v: float = absf(x)
	if v < 1000:
		return str(roundi(x))
	if v < 1e6:
		return "%sk" % num(snappedf(x / 1000.0, 0.1 if v < 1e5 else 1.0))
	return "%sM" % num(snappedf(x / 1e6, 0.1))


## What an enemy is like, for the next-wave preview: its hitpoints (times
## `hp_multiplier`), speed, defences, reward and description.
static func enemy_text(def: EnemyDef, hp_multiplier: float) -> String:
	var lines: PackedStringArray = ["HP %d  ·  Speed %d" % [MathX.js_round(def.hitpoints * hp_multiplier),
		roundi(def.speed * Config.TICK_RATE)]]
	var traits: PackedStringArray = []
	if def.armor > 0:
		traits.append("Armor %s" % num(def.armor))
	if def.shield > 0:
		traits.append("Shield %d" % MathX.js_round(def.shield * hp_multiplier))
	if def.flying:
		traits.append("Flying")
	if not traits.is_empty():
		lines.append("  ·  ".join(traits))
	lines.append("Worth $%d  ·  Costs %d %s" % [def.reward, def.damage, "life" if def.damage == 1 else "lives"])
	lines.append("")
	lines.append(def.description)
	return "\n".join(lines)


## Stat lines shown in the sidebar for a tower at a given level (levels 3 and
## 4 with its branch). `reach` is the range to show (default: the level's),
## `buff` a beacon boost.
static func tower_stats_text(kind: String, level: int, reach: float = -1.0, buff: float = 0.0,
		branch_id: String = "") -> String:
	var d: TowerDef = Towers.get_def(kind)
	var s: TowerLevel = Towers.level_stats(kind, level, branch_id)
	var b: TowerBranch = Towers.get_branch(branch_id) if Towers.is_branch(branch_id) else null
	var range_text: String = "Range %d" % MathX.js_round(s.attack_range if reach < 0 else reach)
	var lines: PackedStringArray = []
	match d.behavior:
		Towers.Behavior.PROJECTILE:
			var shot: String = "Damage %s" % num(s.damage)
			if s.volley > 1:
				shot = "%d x %s damage" % [s.volley, num(s.damage)]
			lines = [shot + "  ·  %.1f/s" % s.fire_rate, range_text]
			if s.splash > 0:
				lines[1] += "  ·  Splash %s" % num(s.splash)
			var extras: PackedStringArray = []
			if s.pierce > 0:
				extras.append("Hits %d in a line" % s.pierce)
			if s.spin_up > 0:
				extras.append("Spins up in %s s" % num(s.spin_up))
			if s.boss_bonus > 1:
				extras.append("x%s vs bosses" % num(s.boss_bonus))
			if s.min_range > 0:
				extras.append("Min range %d" % MathX.js_round(s.min_range))
			if b != null and b.ignores_armor:
				extras.append("Ignores armor")
			if not extras.is_empty():
				lines.append("  ·  ".join(extras))
			if buff > 0:
				lines.append("Boosted +%d%% fire rate" % MathX.js_round(buff * 100))
		Towers.Behavior.BEAM:
			var beams: String = "%d beams of " % s.beams if s.beams > 1 else ""
			lines = ["%s%s dps, heats to %s" % [beams, num(s.damage), num(s.damage * (1 + s.max_heat))], range_text]
		Towers.Behavior.AURA:
			if s.damage > 0:
				lines = ["Slow %d%%  ·  %s dmg/s" % [MathX.js_round(s.slow * 100), num(s.damage * s.fire_rate)], range_text]
			else:
				lines = ["Slow %d%%  ·  no damage" % MathX.js_round(s.slow * 100), range_text]
			if s.stun > 0:
				lines.append("Freezes %s s  ·  +%d%% damage taken" % [num(s.stun), MathX.js_round(s.vulnerability * 100)])
		Towers.Behavior.SUPPORT:
			lines = ["+%d%% fire rate nearby" % MathX.js_round(s.buff * 100), range_text]
			if s.range_buff > 0:
				lines[0] += "  ·  +%d%% range" % MathX.js_round(s.range_buff * 100)
	return "\n".join(lines)
