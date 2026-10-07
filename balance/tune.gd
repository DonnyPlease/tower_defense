extends SceneTree
## Finds, for every level, the enemy hitpoint scale (LevelDef.hp_scale) that
## gives human-like players the target win rate (in endless mode: the target
## number of waves survived), and prints suggested values.
##
##   godot --headless -s res://balance/tune.gd                all levels (slow)
##   godot --headless -s res://balance/tune.gd -- meadow      some levels
##   godot --headless -s res://balance/tune.gd -- endless

## Which simulated player each level is tuned for, and the win rate we want.
const TARGETS: Dictionary[String, Array] = {
	"meadow": ["novice", 0.75],
	"riverside": ["average", 0.75],
	"highlands": ["average", 0.7],
	"openfield": ["average", 0.6],
}
const GAMES: int = 24
## Endless mode: average players should survive about this many waves.
const ENDLESS_TARGET_WAVES: float = 20.0
const ENDLESS_RUNS: int = 12


func _initialize() -> void:
	var only: PackedStringArray = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			only.append(a)
	for i: int in Levels.LEVELS.size():
		var level: LevelDef = Levels.LEVELS[i]
		if only.is_empty() or only.has(level.id):
			_tune(level, i)
	if only.is_empty() or only.has("endless"):
		_tune_endless()
	quit(0)


func _endless_waves(hp_scale: float, skill: float) -> float:
	return BalanceReport.endless_waves(skill, ENDLESS_RUNS, Levels.ENDLESS.with_hp_scale(hp_scale))


func _tune_endless() -> void:
	var skill: float = BalanceReport.SKILLS["average"]
	# Bisection on a log scale: more hitpoints -> fewer waves survived.
	var lo: float = log(0.3)
	var hi: float = log(3.0)
	for i: int in 8:
		var mid: float = (lo + hi) / 2
		if _endless_waves(exp(mid), skill) >= ENDLESS_TARGET_WAVES:
			lo = mid
		else:
			hi = mid
	var hp_scale: float = MathX.js_round(exp(lo) * 100) / 100.0
	var parts: PackedStringArray = []
	for name: String in BalanceReport.SKILL_NAMES:
		parts.append("%s %s" % [name, MathX.to_fixed(_endless_waves(hp_scale, BalanceReport.SKILLS[name]), 1)])
	print("endless    hp_scale %.2f  (average waves survived: %s)" % [hp_scale, ", ".join(parts)])


func _win_rate(level: LevelDef, index: int, hp_scale: float, skill: float) -> float:
	return BalanceReport.human_wins(level.with_hp_scale(hp_scale), index, skill, GAMES) / float(GAMES)


func _tune(level: LevelDef, index: int) -> void:
	if not TARGETS.has(level.id):
		return
	var target: Array = TARGETS[level.id]
	var skill_name: String = target[0]
	var wanted: float = target[1]
	var skill: float = BalanceReport.SKILLS[skill_name]
	# Bisection on a log scale: more hitpoints -> lower win rate.
	var lo: float = log(0.3)
	var hi: float = log(3.0)
	for i: int in 9:
		var mid: float = (lo + hi) / 2
		if _win_rate(level, index, exp(mid), skill) >= wanted:
			lo = mid
		else:
			hi = mid
	var hp_scale: float = MathX.js_round(exp(lo) * 100) / 100.0
	var rates: PackedStringArray = []
	for name: String in BalanceReport.SKILL_NAMES:
		rates.append("%s %d%%" % [name, roundi(_win_rate(level, index, hp_scale, BalanceReport.SKILLS[name]) * 100)])
	var scaled: LevelDef = level.with_hp_scale(hp_scale)
	var expert: BalancePlayers.GameResult = BalancePlayers.search_expert(
		func() -> World: return BalanceReport.new_world(scaled, index), 16, 16).result
	print("%-10s hp_scale %.2f  (%s; expert %s)" % [level.id, hp_scale, ", ".join(rates),
		"won with %d lives" % expert.lives if expert.won else "LOST"])
