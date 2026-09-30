class_name SceneTestCase
extends TestCase
## Base class for tests that drive the real screens: switches scenes through
## the Router and clicks, taps and types like a player (events go through the
## normal input pipeline, so buttons, dialogs and the field react as in play).

const PROFILE_PATH: String = "user://smoke_profile.json"


func after_each() -> void:
	Profile.storage_path = Profile.DEFAULT_PATH
	Profile.forget_cache()


## Starts from a fresh profile (sound off), optionally with stars already earned.
func use_profile(stars: Dictionary[String, int] = {}) -> Profile:
	Profile.storage_path = PROFILE_PATH
	Profile.forget_cache()
	DirAccess.remove_absolute(PROFILE_PATH)
	var p := Profile.new()
	p.stars = stars
	p.sfx = false
	p.music = false
	Profile.save_profile(p)
	return p


func scene() -> Node:
	return tree.current_scene


## Waits until the current scene's script has class_name `title`; false on timeout.
func wait_for_scene(title: String, max_frames: int = 300) -> bool:
	for i: int in max_frames:
		await tree.process_frame
		var s: Node = tree.current_scene
		if s != null and s.get_script() != null and (s.get_script() as Script).get_global_name() == title:
			await frames(2) # let the first frame render
			return true
	fail("timed out waiting for the %s screen" % title)
	return false


## Waits (up to `max_frames` frames of 1/60 s) until `condition` returns true.
func until(condition: Callable, max_frames: int = 3600) -> bool:
	for i: int in max_frames:
		if condition.call():
			return true
		await tree.process_frame
	return condition.call()


## Clicks at a point in game coordinates (1000 x 600) with the mouse.
func click(x: float, y: float, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(x, y)
	motion.global_position = motion.position
	tree.root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = Vector2(x, y)
		ev.global_position = ev.position
		tree.root.push_input(ev, true)
	await frames(1)


## Taps at a point in game coordinates with a finger (the game sees emulated mouse events).
func tap(x: float, y: float) -> void:
	var at: Vector2 = tree.root.get_final_transform() * Vector2(x, y)
	for pressed: bool in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = pressed
		ev.position = at
		Input.parse_input_event(ev)
		await frames(1)
	await frames(1)


func click_button(b: GameButton) -> void:
	expect_not_null(b, "button exists")
	if b != null:
		var r: Rect2 = b.get_global_rect()
		await click(r.get_center().x, r.get_center().y)


func tap_button(b: GameButton) -> void:
	var r: Rect2 = b.get_global_rect()
	await tap(r.get_center().x, r.get_center().y)


## Centre of a map tile in game coordinates.
func tile(col: int, row: int) -> Vector2:
	return Vector2(col * Config.TILE + Config.TILE / 2.0, row * Config.TILE + Config.TILE / 2.0)


func click_tile(col: int, row: int) -> void:
	var p: Vector2 = tile(col, row)
	await click(p.x, p.y)


func press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		tree.root.push_input(ev, true)
	await frames(1)
