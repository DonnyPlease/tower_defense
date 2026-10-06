extends SceneTree
## Looks at the frames recorded while the game booted (tests/run.sh boot):
##
##   godot --headless -s res://tests/boot/check_boot.gd -- <folder> <frame count>
##
## The game was started like a player starts it (its real main scene), so the
## title screen must be on screen and its demo game must be moving.

const PLAY_BUTTON: Vector2i = Vector2i(400, 250) # the blue Play button, away from its text
const SIDEBAR_SIDE: Vector2i = Vector2i(900, 250) # right of the demo field: the dimmed background

var _problems: PackedStringArray = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("usage: check_boot.gd -- <folder> <frame count>")
		quit(2)
		return
	var folder: String = args[0]
	var count: int = int(args[1])
	var files: PackedStringArray = []
	for f: String in DirAccess.get_files_at(folder):
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	_expect(files.size() == count, "expected %d frames, found %d" % [count, files.size()])
	if files.size() < 2:
		_finish()
		return

	var last: Image = Image.load_from_file(folder.path_join(files[files.size() - 1]))
	_expect(last.get_size() == Vector2i(1000, 600), "frame size is %s, not 1000x600" % last.get_size())
	_expect_color(last, PLAY_BUTTON, Palette.ACCENT, "the Play button on the title screen")
	_expect_color(last, SIDEBAR_SIDE, Color("#14171f"), "the dimmed background next to the demo field")

	# The demo game plays by itself: later frames must differ from earlier ones.
	var earlier: Image = Image.load_from_file(folder.path_join(files[floori(files.size() / 2.0)]))
	var changed: int = 0
	for y: int in range(0, 600, 4):
		for x: int in range(0, 1000, 4):
			if last.get_pixel(x, y) != earlier.get_pixel(x, y):
				changed += 1
	_expect(changed > 20, "the demo game isn't moving (%d sampled pixels changed)" % changed)
	_finish()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_problems.append(message)


func _expect_color(img: Image, at: Vector2i, expected: Color, what: String) -> void:
	var c: Color = img.get_pixelv(at)
	if absf(c.r - expected.r) > 0.04 or absf(c.g - expected.g) > 0.04 or absf(c.b - expected.b) > 0.04:
		_problems.append("%s: expected #%s at %s, got #%s" % [what, expected.to_html(false), at, c.to_html(false)])


func _finish() -> void:
	for p: String in _problems:
		print("  ✗ " + p)
	if _problems.is_empty():
		print("  ✓ the title screen is drawn and its demo game is running")
	quit(1 if not _problems.is_empty() else 0)
