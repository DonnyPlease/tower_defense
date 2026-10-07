extends SceneTestCase
## The screens around the game: menu, level select, the tech tree, and moving
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
	await click_button(menu.buttons["tech"])
	if not await wait_for_scene("TechTreeScene"):
		return
	var tree: TechTreeScene = scene()
	await click_button(tree.levels_button)
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	await click_button(levels.tech_button)
	if not await wait_for_scene("TechTreeScene"):
		return
	tree = scene()
	await click_button(tree.back_button)
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
	Router.goto_tech()
	if not await wait_for_scene("TechTreeScene"):
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
	var p: Profile = use_profile(ALL_STARS, ALL_TECH)
	p.endless_best = 7
	Profile.save_profile(p)
	Router.goto_levels()
	if not await wait_for_scene("LevelSelectScene"):
		return
	var levels: LevelSelectScene = scene()
	expect_eq(levels.status_text("endless"), "Best: 7 waves")
	expect_true(levels.play_buttons["endless"].is_enabled())


func test_buying_and_refunding_in_the_tech_tree() -> void:
	use_profile({"meadow": 3})
	var menu: MenuScene = await open_menu()
	if menu == null:
		return
	expect_eq(menu.buttons["tech"].label_text(), "Tech tree")
	await click_button(menu.buttons["tech"])
	if not await wait_for_scene("TechTreeScene"):
		return
	var tree: TechTreeScene = scene()
	expect_eq(tree.stars_text(), "★ 3 to spend  (3 earned)")
	expect_eq(tree.state_text("gun"), "Owned")
	expect_eq(tree.state_text("capital1"), "★ 1")
	expect_eq(tree.state_text("capital2"), "Locked", "needs War Chest I first")
	expect_eq(tree.state_text("frost"), "Locked", "needs the Cannon first")
	expect_eq(tree.state_text("support"), "Locked")
	expect_true(tree.node_buttons["gun"].is_selected(), "owned nodes are framed")

	# Hovering a node explains it and what it takes.
	var r: Rect2 = tree.node_buttons["capital2"].get_global_rect()
	await hover(r.get_center().x, r.get_center().y)
	expect_eq(tree.info_title_text(), "War Chest II")
	expect_contains(tree.info_body_text(), "starting money")
	expect_contains(tree.info_body_text(), "Needs War Chest I first")

	await click_button(tree.node_buttons["capital1"])
	expect_eq(tree.stars_text(), "★ 2 to spend  (3 earned)")
	expect_eq(tree.state_text("capital1"), "Owned")
	expect_eq(tree.state_text("capital2"), "★ 2")
	Profile.forget_cache()
	expect_eq(Profile.load_profile().perk_rank("capital"), 1)

	# The cannon: then its branches open up (once enough stars are earned).
	await click_button(tree.node_buttons["cannon"])
	expect_eq(tree.state_text("cannon"), "Owned")
	expect_eq(tree.state_text("mortar"), "★ 2", "its branches open up")
	expect_eq(tree.stars_text(), "★ 1 to spend  (3 earned)")
	await click_button(tree.node_buttons["capital2"])
	expect_eq(tree.stars_text(), "★ 1 to spend  (3 earned)", "too expensive: nothing bought")

	await click_button(tree.refund_button)
	expect_eq(tree.stars_text(), "★ 3 to spend  (3 earned)")
	expect_eq(tree.state_text("cannon"), "★ 1")
	Profile.forget_cache()
	expect_eq(Profile.load_profile().perk_rank("capital"), 0, "refunded")

	# Buy War Chest again: the next game starts with more money.
	await click_button(tree.node_buttons["capital1"])
	await click_button(tree.levels_button)
	if not await wait_for_scene("LevelSelectScene"):
		return
	await click_button((scene() as LevelSelectScene).play_buttons["meadow"])
	if not await wait_for_scene("GameScene"):
		return
	var game: GameScene = scene()
	expect_eq(game.world.money, 290)
	expect_eq(game.hud.money_text(), "$ 290")


func test_the_game_shows_only_the_towers_the_player_owns() -> void:
	use_profile({"meadow": 3})
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	expect_eq(game.hud.tower_buttons.keys(), ["gun", "missile"])
	expect_not_null(game.hud.teaser_button, "a ? slot hints at more")
	var r: Rect2 = game.hud.teaser_button.get_global_rect()
	await hover(r.get_center().x, r.get_center().y)
	expect_eq(game.hud.panel_title_text(), "More towers")
	expect_contains(game.hud.panel_body_text(), "tech tree")
	await press_key(KEY_3)
	expect_eq(game.tool, "", "no third tower to pick")

	# Buy the cannon: it is the third button (and key 3) in the next game.
	var p: Profile = Profile.load_profile()
	p.buy_tech("cannon")
	game = await open_game("meadow")
	if game == null:
		return
	expect_eq(game.hud.tower_buttons.keys(), ["gun", "missile", "cannon"])
	await press_key(KEY_3)
	expect_eq(game.tool, "cannon")
	expect_eq(game.world.locked_branches.has("mortar"), true, "its branches are still locked")


func test_owning_everything_leaves_no_teaser() -> void:
	use_profile(ALL_STARS, ALL_TECH)
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	expect_eq(game.hud.tower_buttons.keys(), Towers.KINDS)
	expect_null(game.hud.teaser_button)
	expect_true(game.world.locked_branches.is_empty())
