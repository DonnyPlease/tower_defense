extends Node
## Switches between the screens (autoload "Router") and sets up what all of
## them share: the UI theme, the saved sound settings, and the enemy routes,
## which are built on a background thread so starting a level is instant.

const MENU: String = "res://scenes/menu.tscn"
const LEVELS: String = "res://scenes/level_select.tscn"
const TECH: String = "res://scenes/tech_tree.tscn"
const GAME: String = "res://scenes/game.tscn"

## The level the game screen starts (a level id, or "endless").
var launch_level_id: String = "meadow"
## Whether the game screen continues the saved game.
var launch_resume: bool = false

var _warm_up_task: int = -1


func _ready() -> void:
	get_tree().root.theme = Ui.theme()
	var profile: Profile = Profile.load_profile()
	Audio.set_sfx(profile.sfx)
	Audio.set_music(profile.music)
	_warm_up_routes()


func _exit_tree() -> void:
	if _warm_up_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_warm_up_task)
		_warm_up_task = -1


func goto_menu() -> void:
	_change(MENU)


func goto_levels() -> void:
	_change(LEVELS)


func goto_tech() -> void:
	_change(TECH)


## Starts a level ("endless" for endless mode), or continues the saved game with `resume`.
func goto_game(level_id: String, resume: bool = false) -> void:
	launch_level_id = level_id
	launch_resume = resume
	_change(GAME)


func _change(path: String) -> void:
	get_tree().change_scene_to_file.call_deferred(path)


## Smoothing a map's routes takes a moment; do it for every level while the
## player is still in the menus.
func _warm_up_routes() -> void:
	if not OS.has_feature("threads"):
		return
	var sources: Array[LevelDef] = Levels.LEVELS.duplicate()
	sources.append(Levels.ENDLESS)
	_warm_up_task = WorkerThreadPool.add_task(func() -> void:
		for level: LevelDef in sources:
			GameMap.new(level.name, level.tiles, level.maze, level.road_walls).warm_up(), false, "Build enemy routes")
