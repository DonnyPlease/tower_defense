class_name SceneTestCase
extends TestCase
## Base class for tests that drive the real screens: switches scenes through
## the Router and clicks, taps and types like a player (events go through the
## normal input pipeline, so buttons, dialogs and the field react as in play).

## Every level won with 3 stars: every level is open.
const ALL_STARS: Dictionary[String, int] = {"meadow": 3, "riverside": 3, "highlands": 3}

## Every node of the tech tree (use_profile gives them for free), except
## Field Orders: its offer at the start of every game would need answering.
static var ALL_TECH: Array[String] = _all_tech()


static func _all_tech() -> Array[String]:
	var out: Array[String] = []
	for n: Tech.TechNode in Tech.NODES:
		if n.id != "orders" and n.id != "orders2":
			out.append(n.id)
	return out

## The tests' own save file, one per process so runs can go side by side
## (all copies of the project share one user:// folder).
static var profile_path: String = "user://test_profile_%d.json" % OS.get_process_id()


func after_each() -> void:
	# Screens remember a few choices for the session; every test starts afresh.
	TowerCard.details_open = false
	TechTreeScene.last_page = TechTreeScene.Page.TOWERS
	Profile.storage_path = Profile.DEFAULT_PATH
	Profile.forget_cache()
	DirAccess.remove_absolute(profile_path)


## Starts from a fresh profile (sound off), optionally with stars already
## earned and tech tree nodes owned (for free).
func use_profile(stars: Dictionary[String, int] = {}, tech: Array[String] = []) -> Profile:
	Profile.storage_path = profile_path
	Profile.forget_cache()
	DirAccess.remove_absolute(profile_path)
	var p := Profile.new()
	p.stars = stars
	for id: String in tech:
		p.free_tech[id] = true
	p.tutorial_done = true # the tutorial has tests of its own
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


## Starts a level and waits for the game screen (null if it never appeared).
func open_game(level_id: String) -> GameScene:
	Router.goto_game(level_id)
	if not await wait_for_scene("GameScene"):
		return null
	return scene()


## Towers on the field as "kind@col,row".
func tower_names(game: GameScene) -> Array[String]:
	var out: Array[String] = []
	for t: Tower in game.world.towers:
		out.append("%s@%d,%d" % [t.kind, t.col, t.row])
	return out


## Waits (up to `max_frames` frames of 1/60 s) until `condition` returns true.
func until(condition: Callable, max_frames: int = 3600) -> bool:
	for i: int in max_frames:
		if condition.call():
			return true
		await tree.process_frame
	return condition.call()


## Clicks at a point of the view (game units: 1000 x 600 or more, see Screen) with the mouse.
func click(x: float, y: float, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(x, y)
	motion.global_position = motion.position
	tree.root.push_input(motion, true)
	# Pressed and released on different frames, like a real click: the game
	# runs a frame in between (a button that flickers then loses the press).
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = Vector2(x, y)
		ev.global_position = ev.position
		tree.root.push_input(ev, true)
		await frames(1)


## Taps at a point of the view with a finger (the game sees emulated mouse events).
func tap(x: float, y: float) -> void:
	var at: Vector2 = tree.root.get_final_transform() * Vector2(x, y)
	await tap_window(at.x, at.y)


## Taps at a point in window pixels (e.g. on a letterbox bar).
func tap_window(x: float, y: float) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.pressed = pressed
		ev.position = Vector2(x, y)
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


## Centre of a map tile on the screen (in view coordinates): where the game
## screen draws it, or in field coordinates on other screens.
func tile(col: int, row: int) -> Vector2:
	return field_point(Vector2(col * Config.TILE + Config.TILE / 2.0, row * Config.TILE + Config.TILE / 2.0))


## A point of the field (simulation coordinates) on the screen.
func field_point(p: Vector2) -> Vector2:
	var game := scene() as GameScene
	return game.field_to_screen(p) if game != null else p


## Clicks a point of the field (simulation coordinates, 800 x 600).
func click_field(x: float, y: float, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var p: Vector2 = field_point(Vector2(x, y))
	await click(p.x, p.y, button)


## Moves the mouse to a point of the field (simulation coordinates).
func hover_field(x: float, y: float) -> void:
	var p: Vector2 = field_point(Vector2(x, y))
	await hover(p.x, p.y)


## Colour of the screenshot under a point of the field (simulation coordinates).
func field_pixel(img: Image, x: float, y: float) -> Color:
	var p: Vector2 = field_point(Vector2(x, y))
	return pixel_at(img, p.x, p.y)


## Right-clicks the land beside the map (or its corner tile when there is no
## room beside it): puts the tool away and lets go of what is selected.
func right_click_beside_map() -> void:
	var game := scene() as GameScene
	if game == null:
		return
	var map: Rect2 = game.map_rect()
	var p: Vector2 = Vector2(map.position.x / 2, map.get_center().y) if map.position.x >= 8 else tile(0, 0)
	await click(p.x, p.y, MOUSE_BUTTON_RIGHT)


## A point on the game screen's rail (not on any of its buttons).
func on_rail() -> Vector2:
	var game := scene() as GameScene
	return game.hud.get_global_rect().position + Vector2(Hud.W / 2, game.hud.tools_y + 150) if game != null else Vector2.ZERO


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


## Moves the mouse to a point of the view (hover effects, build preview).
func hover(x: float, y: float) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(x, y)
	motion.global_position = motion.position
	tree.root.push_input(motion, true)
	await frames(1)


func hover_tile(col: int, row: int) -> void:
	var p: Vector2 = tile(col, row)
	await hover(p.x, p.y)


## The window loses focus (the player switched to another app).
func lose_focus() -> void:
	tree.root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(1)


# ---- pixels --------------------------------------------------------------------

## Whether frames are really drawn (not when running headless).
func rendering_available() -> bool:
	return DisplayServer.get_name() != "headless"


## The next frame the game draws (scaled like the window, without the
## letterbox bars). Only call it when rendering_available().
func screenshot() -> Image:
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image()


## Colour of the screenshot under a point of the view.
func pixel_at(img: Image, x: float, y: float) -> Color:
	var p: Vector2 = Vector2(x, y) * Vector2(img.get_size()) / tree.root.get_visible_rect().size
	return img.get_pixel(clampi(floori(p.x), 0, img.get_width() - 1), clampi(floori(p.y), 0, img.get_height() - 1))


## Expects two colours to match within `tolerance` per channel (RGB only).
func expect_color(actual: Color, expected: Color, message: String = "", tolerance: float = 0.04) -> void:
	if absf(actual.r - expected.r) > tolerance or absf(actual.g - expected.g) > tolerance \
			or absf(actual.b - expected.b) > tolerance:
		fail("expected colour #%s, got #%s%s" % [expected.to_html(false), actual.to_html(false), _where(message)])
