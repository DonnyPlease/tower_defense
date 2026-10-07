extends SceneTestCase
## Field orders (run perks) in the game: the offer at the start, choosing with
## the mouse or a number key, and what the sidebar shows afterwards.


func test_no_offer_without_field_orders() -> void:
	use_profile({"meadow": 3})
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	expect_false(game.draft.visible)
	expect_false(game.is_modal_open())


func test_a_game_starts_with_an_offer_that_blocks_until_chosen() -> void:
	use_profile({"meadow": 3, "riverside": 3}, ["orders"])
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var w: World = game.world
	expect_true(game.draft.visible, "the offer is shown")
	expect_eq(game.draft.cards.size(), 3)
	expect_eq(game.draft.card_ids, w.perk_offer)
	# While it is open nothing else happens.
	await press_key(KEY_SPACE)
	expect_eq(w.wave_index, -1, "no wave starts")
	await click_tile(6, 9)
	expect_true(w.towers.is_empty(), "no building")
	await click_button(game.hud.wave_button)
	expect_eq(w.wave_index, -1)

	var pick: String = game.draft.card_ids[1]
	await click_button(game.draft.cards[1])
	expect_eq(w.run_perks, [pick] as Array[String])
	await frames(1)
	expect_false(game.draft.visible, "gone once chosen")
	expect_true(game.field.floating_texts().has(RunPerks.get_def(pick).name + "!"))
	expect_eq(game.hud.panel_title_text(), "Field orders")
	expect_contains(game.hud.panel_body_text(), RunPerks.get_def(pick).name)
	await press_key(KEY_SPACE)
	expect_eq(w.wave_index, 0, "now the wave can start")


func test_a_number_key_picks_a_card_and_wider_choice_offers_four() -> void:
	use_profile({"meadow": 3, "riverside": 3, "highlands": 3}, ["orders", "orders2"])
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	expect_eq(game.draft.cards.size(), 4)
	var pick: String = game.draft.card_ids[3]
	await press_key(KEY_4)
	expect_eq(game.world.run_perks, [pick] as Array[String])
	await press_key(KEY_1)
	expect_eq(game.tool, "gun", "afterwards 1 picks the gun again")


func test_a_waiting_offer_is_still_there_after_resuming() -> void:
	use_profile({"meadow": 3, "riverside": 3}, ["orders"])
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var offer: Array[String] = game.world.perk_offer.duplicate()
	Router.goto_menu()
	if not await wait_for_scene("MenuScene"):
		return
	var menu: MenuScene = scene()
	await click_button(menu.buttons["continue"])
	if not await wait_for_scene("GameScene"):
		return
	var resumed: GameScene = scene()
	expect_true(resumed.resumed)
	expect_eq(resumed.world.perk_offer, offer, "the same three perks")
	expect_true(resumed.draft.visible)


func test_the_tech_tree_sells_field_orders() -> void:
	use_profile({"meadow": 3, "riverside": 3})
	Router.goto_tech()
	if not await wait_for_scene("TechTreeScene"):
		return
	var tree: TechTreeScene = scene()
	expect_eq(tree.state_text("orders"), "★ 2")
	expect_eq(tree.state_text("orders2"), "Locked")
	await click_button(tree.node_buttons["orders"])
	expect_eq(tree.state_text("orders"), "Owned")
	expect_eq(tree.state_text("orders2"), "Earn ★9")
