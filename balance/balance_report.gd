class_name BalanceReport
extends RefCounted
## What the balance report and tuner measure (see report.gd, tune.gd and the
## balance tests).

## Simulated player skills.
const SKILLS: Dictionary[String, float] = {"novice": 0.25, "average": 0.55, "good": 0.85}
const SKILL_NAMES: Array[String] = ["novice", "average", "good"]


class HumanStats:
	var win_rate: float
	var avg_lives: float
	var avg_waves: float


class LevelReport:
	var level: String
	var unlocked: Array[String]
	var expert: BalancePlayers.GameResult
	var humans: Dictionary[String, HumanStats] = {}


## Towers a typical player has when reaching level `index` (about 2 stars per level).
static func typical_unlocks(index: int) -> Array[String]:
	var out: Array[String] = []
	for k: String in Towers.CLASSIC_KINDS:
		if Towers.get_def(k).unlock_stars <= 2 * index:
			out.append(k)
	return out


static func new_world(level: LevelDef, index: int) -> World:
	return World.new(level, Callable(), null, typical_unlocks(index))


## Games (out of seeds 1..`games`) a human-like player of `skill` wins.
static func human_wins(level: LevelDef, index: int, skill: float, games: int) -> int:
	var wins: int = 0
	for seed_value: int in range(1, games + 1):
		if BalancePlayers.play_human(new_world(level, index), skill, seed_value).won:
			wins += 1
	return wins


static func report_level(level: LevelDef, index: int, games: int, samples: int = 40, climbs: int = 40) -> LevelReport:
	var r := LevelReport.new()
	r.level = level.id
	r.unlocked = typical_unlocks(index)
	r.expert = BalancePlayers.search_expert(func() -> World: return new_world(level, index), samples, climbs).result
	for name: String in SKILL_NAMES:
		var stats := HumanStats.new()
		var won: int = 0
		var lives: int = 0
		var waves: int = 0
		for seed_value: int in range(1, games + 1):
			var result: BalancePlayers.GameResult = BalancePlayers.play_human(new_world(level, index), SKILLS[name], seed_value)
			won += 1 if result.won else 0
			lives += result.lives
			waves += result.waves_cleared
		stats.win_rate = float(won) / games
		stats.avg_lives = float(lives) / games
		stats.avg_waves = float(waves) / games
		r.humans[name] = stats
	return r


## Average waves an endless run lasts (up to 50) for a player of `skill`, over seeds 1..`runs`
## (on the endless level, or on `level`, e.g. with another hp_scale).
static func endless_waves(skill: float, runs: int, level: LevelDef = null) -> float:
	var played: LevelDef = level if level != null else Levels.ENDLESS
	var total: int = 0
	for seed_value: int in range(1, runs + 1):
		var w := World.new(played, Levels.endless_wave, null, typical_unlocks(2))
		total += BalancePlayers.play_human(w, skill, seed_value, 50).waves_cleared
	return float(total) / runs
