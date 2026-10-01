extends SceneTree
## Test runner.
##
##   godot -s res://tests/run_tests.gd -- [suite ...] [--filter=text[,text...]] [--log=path]
##
## Suites are folders under tests/ (unit, smoke, phone, balance); without any,
## unit, smoke and phone run. Every tests/<suite>/test_*.gd extends TestCase; its
## methods named test_* are the tests. Exits with 1 if anything failed.
## tests/run.sh picks the right display and window size for each suite.
##
## GDScript has no exceptions: a runtime error ends the function it happens in
## and is only printed. So after every test the runner reads the new lines of
## the engine's log file (--log, which must match Godot's --log-file; default:
## the project's log), and any script or engine error fails that test.

const DEFAULT_SUITES: Array[String] = ["unit", "smoke", "phone"]
const ERROR_PREFIXES: Array[String] = ["SCRIPT ERROR", "ERROR:", "USER ERROR", "USER SCRIPT ERROR"]


## Reads what the engine logged since the last call.
class LogReader:
	var path: String
	var offset: int = 0

	func _init(p_path: String) -> void:
		path = p_path
		offset = _length()

	func _length() -> int:
		var f := FileAccess.open(path, FileAccess.READ)
		return f.get_length() if f != null else 0

	## Error lines (with their "at:" line) logged since the last call.
	func new_errors() -> PackedStringArray:
		var out: PackedStringArray = []
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			return out
		var length: int = f.get_length()
		if length < offset:
			offset = 0 # the log was rotated
		f.seek(offset)
		var lines: PackedStringArray = f.get_buffer(length - offset).get_string_from_utf8().split("\n")
		offset = length
		for i: int in lines.size():
			var line: String = lines[i].strip_edges()
			if ERROR_PREFIXES.any(func(p: String) -> bool: return line.begins_with(p)):
				var at: String = lines[i + 1].strip_edges() if i + 1 < lines.size() else ""
				out.append(line + ("  " + at if at.begins_with("at:") else ""))
		return out


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suites: Array[String] = []
	var filters: PackedStringArray = [] # a test runs if its name contains any of them
	var log_path: String = ProjectSettings.globalize_path(str(ProjectSettings.get_setting("debug/file_logging/log_path")))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filters = arg.trim_prefix("--filter=").split(",", false)
		elif arg.begins_with("--log="):
			log_path = arg.trim_prefix("--log=")
		else:
			suites.append(arg)
	if suites.is_empty():
		suites = DEFAULT_SUITES
	var log := LogReader.new(log_path)
	if not FileAccess.file_exists(log_path):
		printerr("Warning: no log file at %s; errors inside tests can't be told apart." % log_path)

	var passed: int = 0
	var skipped: int = 0
	var failed: PackedStringArray = []
	var started: int = Time.get_ticks_msec()
	for suite: String in suites:
		var dir: String = "res://tests/%s" % suite
		var files: PackedStringArray = DirAccess.get_files_at(dir)
		if files.is_empty():
			printerr("No tests in %s" % dir)
			failed.append(suite)
			continue
		files.sort()
		for file: String in files:
			if not (file.begins_with("test_") and file.ends_with(".gd")):
				continue
			var script: GDScript = load("%s/%s" % [dir, file])
			log.new_errors() # a broken script reports its errors below
			if script == null or not script.can_instantiate():
				printerr("Can't load %s/%s" % [dir, file])
				failed.append(file)
				continue
			var header: String = "\n%s/%s" % [suite, file]
			for method: Dictionary in script.get_script_method_list():
				var name: String = method["name"]
				if not name.begins_with("test_"):
					continue
				var full: String = "%s/%s > %s" % [suite, file.get_basename(), name]
				if not filters.is_empty() and not Array(filters).any(func(f: String) -> bool: return full.contains(f)):
					continue
				if not header.is_empty():
					print(header) # only for files with tests to run
					header = ""
				var test: TestCase = script.new()
				test.tree = self
				var t0: int = Time.get_ticks_msec()
				log.new_errors()
				test.before_each()
				if test.skip_reason.is_empty(): # before_each may skip the test
					await test.call(name)
				test.after_each()
				await process_frame # let freed nodes go before the next test
				var ms: int = Time.get_ticks_msec() - t0
				for error: String in log.new_errors():
					test.fail(error)
				if not test.failures.is_empty():
					failed.append(full)
					print("  ✗ %s (%d ms)" % [name, ms])
					for f: String in test.failures:
						print("      " + f)
				elif not test.skip_reason.is_empty():
					skipped += 1
					print("  - %s (skipped: %s)" % [name, test.skip_reason])
				else:
					passed += 1
					print("  ✓ %s (%d ms)" % [name, ms])

	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	print("\n%d passed, %d failed, %d skipped (%.1f s)" % [passed, failed.size(), skipped, seconds])
	for f: String in failed:
		print("  FAILED: " + f)
	quit(1 if not failed.is_empty() else 0)
