extends SceneTestCase
## Whole games played like a person plays them: from the title screen, with
## nothing but clicks and key presses, spending only the money the game gives.
## The tests read the screen (the sidebar and the dialogs) to decide what to do,
## and never change the game's state directly.

## A game that is not over after this many decisions (30 frames each; a win takes
## about 90) is stuck: the test fails instead of waiting for ever.
const MAX_STEPS: int = 200

## What to build, in order: tower key (1 = gun, 2 = missile) and the tile.
const BUILD_ORDER: Array[Array] = [
	[2, Vector2i(6, 10)], [2, Vector2i(7, 9)], [1, Vector2i(8, 8)], [2, Vector2i(12, 9)],
	[2, Vector2i(13, 8)], [1, Vector2i(9, 7)], [2, Vector2i(5, 9)], [1, Vector2i(13, 7)],
	[2, Vector2i(11, 12)], [2, Vector2i(14, 9)],
]


## The number after the "$" of a label ("$ 250", "$50", "Upgrade  $75"), or -1.
func dollars(text: String) -> int:
	var at: int = text.rfind("$")
	return text.substr(at + 1).strip_edges().to_int() if at >= 0 else -1


func money(game: GameScene) -> int:
	return dollars(game.hud.money_text())


func is_over(game: GameScene) -> bool:
	return game.win_overlay.visible or game.lose_overlay.visible


## Opens Meadow from the title screen with the mouse, at the fastest speed (key F).
func start_meadow() -> GameScene:
	Router.goto_menu()
	if not await wait_for_scene("MenuScene"):
		return null
	await click_button((scene() as MenuScene).buttons["play"])
	if not await wait_for_scene("LevelSelectScene"):
		return null
	await click_button((scene() as LevelSelectScene).play_buttons["meadow"])
	if not await wait_for_scene("GameScene"):
		return null
	var game: GameScene = scene()
	await press_key(KEY_F)
	await press_key(KEY_F)
	expect_eq(game.hud.speed_button.label_text(), "3x")
	return game


## Starts the next wave when the sidebar offers it (and nothing is running).
func start_wave_if_offered(game: GameScene) -> void:
	var b: GameButton = game.hud.wave_button
	if b.is_enabled() and b.label_text().begins_with("Start wave"):
		await press_key(KEY_SPACE)


func test_a_level_won_with_clicks_and_keys_only() -> void:
	use_profile()
	var game: GameScene = await start_meadow()
	if game == null:
		return
	var hud: Hud = game.hud
	var spots_built: Array[Vector2i] = []
	var upgrades: Dictionary[Vector2i, int] = {} # upgrades bought per tower
	var maxed: Dictionary[Vector2i, bool] = {}
	var next: int = 0
	for step: int in MAX_STEPS:
		if is_over(game):
			break
		# Build the next tower when its price is on the sidebar and affordable.
		if next < BUILD_ORDER.size():
			var key: int = BUILD_ORDER[next][0]
			var spot: Vector2i = BUILD_ORDER[next][1]
			var kind: String = Towers.KINDS[key - 1]
			if money(game) >= dollars(hud.tower_buttons[kind].label_text()):
				await press_key(KEY_0 + key as Key)
				await click_tile(spot.x, spot.y)
				if tower_names(game).has("%s@%d,%d" % [kind, spot.x, spot.y]):
					spots_built.append(spot)
					upgrades[spot] = 0
				next += 1
				await click(900, 300, MOUSE_BUTTON_RIGHT) # put the tool away
		else:
			# Everything is built: upgrade the weakest tower we can afford.
			var weakest: Vector2i = Vector2i(-1, -1)
			for s: Vector2i in spots_built:
				if not maxed.has(s) and (weakest.x < 0 or upgrades[s] < upgrades[weakest]):
					weakest = s
			if weakest.x >= 0:
				await click_tile(weakest.x, weakest.y)
				var label: String = hud.upgrade_button.label_text()
				if label == "Max level":
					maxed[weakest] = true
				elif money(game) >= dollars(label):
					await click_button(hud.upgrade_button)
					upgrades[weakest] += 1
				await click(900, 300, MOUSE_BUTTON_RIGHT)
		if spots_built.size() >= 2 or game.world.wave_index >= 0:
			await start_wave_if_offered(game)
		await frames(30)
	expect_true(game.win_overlay.visible, "the level was won (lives left: %s)" % hud.lives_text())
	if not game.win_overlay.visible:
		return
	var lives: int = dollars(hud.lives_text().replace("♥", "$")) # "♥ 13" -> 13
	expect_eq(game.win_overlay.title_text(), "Victory!")
	expect_match(game.win_overlay.subtitle_text(), "^★+☆*\\n%d of 20 lives left\\.\\n\\+[1-3] ★ to spend in the tech tree!$" % lives)
	expect_eq(hud.wave_button.label_text(), "Game over")

	# The result is kept: the level select screen and the title screen show it.
	await click_button(game.win_overlay.button("Level select"))
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	expect_match(levels.status_text("meadow"), "^★+☆*$")
	expect_true(levels.play_buttons["riverside"].is_enabled(), "Riverside is open now")
	expect_match(levels.stars_text(), "^★ [1-3] stars$")
	await click_button(levels.back_button)
	if not await wait_for_scene("MenuScene"):
		return
	expect_match((scene() as MenuScene).stars_text(), "^★ [1-3] stars earned$")
	Profile.forget_cache() # as after a restart: it was written to the file
	expect_ge(Profile.load_profile().stars_on("meadow"), 1)

	# ... and the next level can be played.
	await click_button((scene() as MenuScene).buttons["play"])
	if not await wait_for_scene("LevelSelectScene"):
		return
	await click_button((scene() as LevelSelectScene).play_buttons["riverside"])
	if not await wait_for_scene("GameScene"):
		return
	expect_eq((scene() as GameScene).level_id, "riverside")
	expect_eq((scene() as GameScene).hud.wave_text(), "Wave 0 / 10")


func test_a_level_lost_by_never_building() -> void:
	use_profile()
	var game: GameScene = await start_meadow()
	if game == null:
		return
	for step: int in MAX_STEPS:
		if is_over(game):
			break
		await start_wave_if_offered(game)
		await frames(30)
	expect_true(game.lose_overlay.visible, "the level was lost")
	expect_eq(game.hud.lives_text(), "♥ 0")
	expect_eq(game.lose_overlay.title_text(), "Defeat")
	expect_match(game.lose_overlay.subtitle_text(), "^You reached wave \\d of 8\\.$")
	expect_false(game.win_overlay.visible)
	Profile.forget_cache()
	expect_eq(Profile.load_profile().stars_on("meadow"), 0, "no stars for losing")
	await click_button(game.lose_overlay.button("Level select"))
	if not await wait_for_scene("LevelSelectScene"):
		return
	expect_false((scene() as LevelSelectScene).play_buttons["riverside"].is_enabled(), "Riverside stays locked")
