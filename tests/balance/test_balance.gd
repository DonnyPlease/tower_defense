extends TestCase
## Guards the difficulty curve measured by balance/report.gd. Simulated
## players use fixed seeds, so these results are deterministic (and the same
## as in the original TypeScript version of the game).

const SEEDS: int = 12


func _wins(index: int, skill: String) -> int:
	return BalanceReport.human_wins(Levels.LEVELS[index], index, BalanceReport.SKILLS[skill], SEEDS)


func _best_strategy_wins(index: int) -> void:
	var level: LevelDef = Levels.LEVELS[index]
	var best: BalancePlayers.SearchResult = BalancePlayers.search_expert(
		func() -> World: return BalanceReport.new_world(level, index), 6, 6)
	expect_true(best.result.won, "%s: the best strategy found wins" % level.name)


func _doable_but_not_trivial(index: int) -> void:
	expect_ge(_wins(index, "average"), 6, "average players win at least half")
	expect_le(_wins(index, "novice"), 9, "novices don't win nearly every time")


func test_meadow_the_best_strategy_found_wins() -> void:
	_best_strategy_wins(0)


func test_riverside_the_best_strategy_found_wins() -> void:
	_best_strategy_wins(1)


func test_highlands_the_best_strategy_found_wins() -> void:
	_best_strategy_wins(2)


func test_openfield_the_best_strategy_found_wins() -> void:
	_best_strategy_wins(3)


func test_meadow_tutorial_is_won_by_most_novices_and_nearly_all_average_players() -> void:
	expect_ge(_wins(0, "novice"), 8)
	expect_ge(_wins(0, "average"), 10)


func test_meadow_can_be_won_without_losing_a_life() -> void:
	var meadow: LevelDef = Levels.by_id("meadow")
	var starting: Array[String] = ["gun", "missile"]
	var best: BalancePlayers.SearchResult = BalancePlayers.search_expert(
		func() -> World: return World.new(meadow, Callable(), null, starting), 10, 10)
	var w := World.new(meadow, Callable(), null, starting)
	expect_eq(BalancePlayers.play_expert(w, best.params).lives, w.start_lives, "3 stars")


func test_riverside_is_doable_for_average_players_but_not_trivial_for_novices() -> void:
	_doable_but_not_trivial(1)


func test_highlands_is_doable_for_average_players_but_not_trivial_for_novices() -> void:
	_doable_but_not_trivial(2)


func test_openfield_is_doable_for_average_players_but_not_trivial_for_novices() -> void:
	_doable_but_not_trivial(3)


func test_endless_runs_end_but_not_too_soon() -> void:
	var w := World.new(Levels.ENDLESS, Levels.endless_wave, null, BalanceReport.typical_unlocks(2))
	var cleared: int = BalancePlayers.play_human(w, BalanceReport.SKILLS["average"], 1, 40).waves_cleared
	expect_ge(cleared, 10)
	expect_lt(cleared, 40)
