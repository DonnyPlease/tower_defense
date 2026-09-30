extends SceneTree
## Balance report: how do an optimised expert and human-like players of
## different skill fare on every level?
##
##   godot --headless -s res://balance/report.gd                 full report (slow)
##   godot --headless -s res://balance/report.gd -- --quick      fewer games, rougher numbers
##   godot --headless -s res://balance/report.gd -- meadow       only some levels


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var quick: bool = args.has("--quick")
	var only: PackedStringArray = []
	for a: String in args:
		if not a.begins_with("--"):
			only.append(a)
	var games: int = 10 if quick else 40
	var search: int = 12 if quick else 40

	print("Level        Towers                                  Expert (best found)    Novice          Average         Good")
	for i: int in Levels.LEVELS.size():
		var level: LevelDef = Levels.LEVELS[i]
		if not only.is_empty() and not only.has(level.id):
			continue
		var r: BalanceReport.LevelReport = BalanceReport.report_level(level, i, games, search, search)
		var e: BalancePlayers.GameResult = r.expert
		var expert: String = "won, %d/%d lives" % [e.lives, e.start_lives] if e.won else "lost at wave %d" % (e.waves_cleared + 1)
		var cells: PackedStringArray = []
		for skill: String in BalanceReport.SKILL_NAMES:
			var h: BalanceReport.HumanStats = r.humans[skill]
			cells.append("%4d%% (♥%4s)" % [MathX.js_round(h.win_rate * 100), MathX.to_fixed(h.avg_lives, 1)])
		print("%-12s %-39s %-22s %s" % [level.id, ",".join(r.unlocked), expert, "  ".join(cells)])

	if only.is_empty() or only.has("endless"):
		var parts: PackedStringArray = []
		for skill: String in BalanceReport.SKILL_NAMES:
			parts.append("%s %s" % [skill, MathX.to_fixed(BalanceReport.endless_waves(BalanceReport.SKILLS[skill], mini(games, 8)), 1)])
		print("endless      average waves survived: %s" % ", ".join(parts))
	quit(0)
