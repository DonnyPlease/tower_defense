extends SceneTree
## Headless test runner.
##
##   godot --headless -s res://tests/run_tests.gd -- [suite ...] [--filter=text]
##
## Suites are folders under tests/ (unit, smoke, balance); without any, unit
## and smoke run. Every tests/<suite>/test_*.gd extends TestCase; its methods
## named test_* are the tests. Exits with 1 if anything failed.
##
## GDScript has no exceptions: a runtime error inside a test is printed as
## "SCRIPT ERROR" and ends that test early. tests/run.sh turns such errors
## into a failed run as well.

const DEFAULT_SUITES: Array[String] = ["unit", "smoke"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suites: Array[String] = []
	var filter: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")
		else:
			suites.append(arg)
	if suites.is_empty():
		suites = DEFAULT_SUITES

	var passed: int = 0
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
			if script == null or not script.can_instantiate():
				printerr("Can't load %s/%s" % [dir, file])
				failed.append(file)
				continue
			print("\n%s/%s" % [suite, file])
			for method: Dictionary in script.get_script_method_list():
				var name: String = method["name"]
				if not name.begins_with("test_"):
					continue
				var full: String = "%s/%s > %s" % [suite, file.get_basename(), name]
				if not filter.is_empty() and not full.contains(filter):
					continue
				var test: TestCase = script.new()
				test.tree = self
				var t0: int = Time.get_ticks_msec()
				test.before_each()
				await test.call(name)
				test.after_each()
				await process_frame # let freed nodes go before the next test
				var ms: int = Time.get_ticks_msec() - t0
				if test.failures.is_empty():
					passed += 1
					print("  ✓ %s (%d ms)" % [name, ms])
				else:
					failed.append(full)
					print("  ✗ %s (%d ms)" % [name, ms])
					for f: String in test.failures:
						print("      " + f)

	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	print("\n%d passed, %d failed (%.1f s)" % [passed, failed.size(), seconds])
	for f: String in failed:
		print("  FAILED: " + f)
	quit(1 if not failed.is_empty() else 0)
