extends TestCase
## Every script in the project compiles, with the project's strict typing
## rules (untyped declarations and unsafe calls are errors, see project.godot),
## including scripts no other test uses.

const FOLDERS: Array[String] = ["res://src", "res://balance", "res://tools", "res://tests"]


func _scripts(dir: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(sub), out)


func test_every_script_compiles() -> void:
	var paths: Array[String] = []
	for folder: String in FOLDERS:
		_scripts(folder, paths)
	expect_gt(paths.size(), 50, "found the scripts")
	for path: String in paths:
		var script: GDScript = load(path)
		expect_true(script != null and script.can_instantiate(), path)


func test_every_scene_loads() -> void:
	for file: String in DirAccess.get_files_at("res://scenes"):
		if file.ends_with(".tscn"):
			var scene: PackedScene = load("res://scenes".path_join(file))
			expect_true(scene != null and scene.can_instantiate(), file)
