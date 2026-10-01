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


## Stat lines shown in the sidebar for a tower at a given level. `reach` is
## the range to show (default: the level's), `buff` a beacon boost.
static func tower_stats_text(kind: String, level: int, reach: float = -1.0, buff: float = 0.0) -> String:
	var d: TowerDef = Towers.get_def(kind)
	var s: TowerLevel = d.levels[level]
	var range_text: String = "Range %d" % MathX.js_round(s.attack_range if reach < 0 else reach)
	match d.behavior:
		Towers.Behavior.PROJECTILE:
			var lines: PackedStringArray = ["Damage %s  ·  %.1f/s" % [num(s.damage), s.fire_rate], range_text]
			if s.splash > 0:
				lines[1] += "  ·  Splash %s" % num(s.splash)
			if buff > 0:
				lines.append("Boosted +%d%% fire rate" % MathX.js_round(buff * 100))
			return "\n".join(lines)
		Towers.Behavior.BEAM:
			return "%s dps, heats to %s\n%s" % [num(s.damage), num(s.damage * 3), range_text]
		Towers.Behavior.AURA:
			return "Slow %d%%  ·  %s dmg/s\n%s" % [MathX.js_round(s.slow * 100), num(s.damage), range_text]
		Towers.Behavior.SUPPORT:
			return "+%d%% fire rate nearby\n%s" % [MathX.js_round(s.buff * 100), range_text]
	return range_text
