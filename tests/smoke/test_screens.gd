extends SceneTestCase
## The screens around the game: menu, level select, upgrades, and moving
## between them with the mouse and the keyboard. Checks what the player reads.


func open_menu() -> MenuScene:
	Router.goto_menu()
	if not await wait_for_scene("MenuScene"):
		return null
	return scene()


func test_menu_shows_the_stars_and_offers_play_without_a_saved_game() -> void:
	use_profile({"meadow": 2})
	var menu: MenuScene = await open_menu()
	if menu == null:
		return
	expect_eq(menu.stars_text(), "★ 2 stars earned")
	expect_false(menu.buttons.has("continue"), "nothing to continue")
	expect_eq(menu.buttons["play"].label_text(), "Play")
	expect_eq(menu.buttons["music"].label_text(), "♪ Music off")
	expect_eq(menu.buttons["sfx"].label_text(), "Sound off")


func test_menu_sound_buttons_switch_music_and_effects() -> void:
	use_profile()
	var menu: MenuScene = await open_menu()
	if menu == null:
		return
	await click_button(menu.buttons["music"])
	expect_eq(menu.buttons["music"].label_text(), "♪ Music on")
	expect_true(menu.buttons["music"].is_selected())
	await click_button(menu.buttons["sfx"])
	expect_eq(menu.buttons["sfx"].label_text(), "Sound on")
	Profile.forget_cache()
	var p: Profile = Profile.load_profile()
	expect_true(p.music, "music saved")
	expect_true(p.sfx, "effects saved")
	await click_button(menu.buttons["music"])
	expect_eq(menu.buttons["music"].label_text(), "♪ Music off")
	Profile.forget_cache()
	expect_false(Profile.load_profile().music, "music off saved")


func test_navigating_with_the_buttons() -> void:
	use_profile()
	var menu: MenuScene = await open_menu()
	if menu == null:
		return
	await click_button(menu.buttons["upgrades"])
	if not await wait_for_scene("UpgradesScene"):
		return
	var upgrades: UpgradesScene = scene()
	await click_button(upgrades.levels_button)
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	await click_button(levels.upgrades_button)
	if not await wait_for_scene("UpgradesScene"):
		return
	upgrades = scene()
	await click_button(upgrades.back_button)
	if not await wait_for_scene("MenuScene"):
		return
	menu = scene()
	await click_button(menu.buttons["play"])
	if not await wait_for_scene("LevelSelectScene"):
		return
	levels = scene()
	await click_button(levels.back_button)
	expect_true(await wait_for_scene("MenuScene"), "back to the menu")


func test_navigating_with_the_keyboard() -> void:
	use_profile()
	var menu: MenuScene = await open_menu()
	if menu == null:
		return
	await press_key(KEY_ENTER) # no saved game: Enter goes to the levels
	if not await wait_for_scene("LevelSelectScene"):
		return
	await press_key(KEY_ESCAPE)
	if not await wait_for_scene("MenuScene"):
		return
	Router.goto_upgrades()
	if not await wait_for_scene("UpgradesScene"):
		return
	await press_key(KEY_ESCAPE)
	if not await wait_for_scene("MenuScene"):
		return

	# With a saved game, Enter continues it.
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_1)
	await click_tile(3, 9)
	await press_key(KEY_ESCAPE) # put the tool away
	await press_key(KEY_ESCAPE) # pause
	await click_button(game.pause_overlay.button("Main menu"))
	if not await wait_for_scene("MenuScene"):
		return
	await press_key(KEY_ENTER)
	if not await wait_for_scene("GameScene"):
		return
	game = scene()
	expect_true(game.resumed, "Enter continued the saved game")
	expect_eq(tower_names(game), ["gun@3,9"])


func test_level_select_shows_progress_and_locks() -> void:
	use_profile({"meadow": 2})
	Router.goto_levels()
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	expect_eq(levels.stars_text(), "★ 2 stars")
	expect_eq(levels.status_text("meadow"), "★★☆")
	expect_eq(levels.status_text("riverside"), "☆☆☆")
	expect_eq(levels.description_text("riverside"), "Two roads, one bridge. Watch the sky.")
	expect_eq(levels.description_text("highlands"), "🔒 Beat Riverside first")
	expect_eq(levels.status_text("endless"), "No record yet")
	expect_eq(levels.description_text("endless"), "🔒 Beat Riverside first")
	expect_eq(levels.play_buttons["riverside"].label_text(), "Play")
	expect_eq(levels.play_buttons["highlands"].label_text(), "Locked")
	expect_true(levels.play_buttons["riverside"].is_enabled())
	expect_false(levels.play_buttons["highlands"].is_enabled())
	expect_false(levels.play_buttons["endless"].is_enabled())
	await click_button(levels.play_buttons["highlands"])
	await frames(5)
	expect_true(scene() is LevelSelectScene, "a locked level does not start")
	await click_button(levels.play_buttons["riverside"])
	if not await wait_for_scene("GameScene"):
		return
	expect_eq((scene() as GameScene).level_id, "riverside")


func test_endless_card_shows_the_best_run() -> void:
	var p: Profile = use_profile(ALL_STARS)
	p.endless_best = 7
	Profile.save_profile(p)
	Router.goto_levels()
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	expect_eq(levels.status_text("endless"), "Best: 7 waves")
	expect_true(levels.play_buttons["endless"].is_enabled())


func test_buying_and_refunding_a_perk() -> void:
	use_profile({"meadow": 3})
	var menu: MenuScene = await open_menu()
	if menu == null:
		return
	await click_button(menu.buttons["upgrades"])
	if not await wait_for_scene("UpgradesScene"):
		return
	var upgrades: UpgradesScene = scene()
	expect_eq(upgrades.stars_text(), "★ 3 to spend  (3 earned)")
	expect_eq(upgrades.effect_text("capital"), "Next: +$40 starting money")
	expect_eq(upgrades.buy_buttons["capital"].label_text(), "Buy  ★ 1")

	await click_button(upgrades.buy_buttons["capital"])
	expect_eq(upgrades.stars_text(), "★ 2 to spend  (3 earned)")
	expect_eq(upgrades.effect_text("capital"), "+$40 starting money   (next: +$80 starting money)")
	expect_eq(upgrades.buy_buttons["capital"].label_text(), "Buy  ★ 2")
	Profile.forget_cache()
	expect_eq(Profile.load_profile().perk_rank("capital"), 1)

	await click_button(upgrades.refund_button)
	expect_eq(upgrades.stars_text(), "★ 3 to spend  (3 earned)")
	expect_eq(upgrades.effect_text("capital"), "Next: +$40 starting money")
	Profile.forget_cache()
	expect_eq(Profile.load_profile().perk_rank("capital"), 0, "refunded")

	# Buy it again: the next game starts with more money.
	await click_button(upgrades.buy_buttons["capital"])
	await click_button(upgrades.levels_button)
	if not await wait_for_scene("LevelSelectScene"):
		return
	await click_button((scene() as LevelSelectScene).play_buttons["meadow"])
	if not await wait_for_scene("GameScene"):
		return
	var game: GameScene = scene()
	expect_eq(game.world.money, 290)
	expect_eq(game.hud.money_text(), "$ 290")


func test_perks_the_player_cannot_afford_are_disabled() -> void:
	use_profile({"meadow": 1})
	Router.goto_upgrades()
	if not await wait_for_scene("UpgradesScene"):
		return
	var upgrades: UpgradesScene = scene()
	expect_true(upgrades.buy_buttons["capital"].is_enabled(), "costs 1 star")
	expect_false(upgrades.buy_buttons["engineering"].is_enabled(), "costs 2 stars")
	await click_button(upgrades.buy_buttons["engineering"])
	expect_eq(upgrades.stars_text(), "★ 1 to spend  (1 earned)", "nothing was bought")
