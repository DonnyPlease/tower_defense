extends SceneTestCase
## The wall tool and the abilities, used like a player uses them: with the
## buttons along the bottom of the field, the hotkeys and the mouse. Checks
## what the player sees: prices and countdowns on the buttons, the sidebar's
## help, hints and floating messages.


## Puts a frozen enemy somewhere on the field (a stand-in for "an enemy is there").
func frozen_enemy(game: GameScene, type: String, x: float, y: float) -> Enemy:
	var e: Enemy = game.world.spawn(type)
	e.apply_slow(1.0, 100_000)
	e.nav.x = x
	e.nav.y = y
	e.x = x
	e.y = y
	e.prev_x = x
	e.prev_y = y
	return e


func said(game: GameScene, text: String) -> bool:
	return game.field.floating_texts().has(text)


# ---- the bar --------------------------------------------------------------------------

func test_the_bar_offers_every_ability_with_its_price_and_hotkey() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var buttons: Dictionary[String, GameButton] = game.ability_bar.buttons
	expect_eq(buttons.keys(), Abilities.enabled_ids())
	var prices: Dictionary[String, String] = {"wall": "$15", "slow": "$60", "boost": "$80", "strike": "$100",
		"mine": "$25", "bounty": "$50", "mark": "$40", "wind": "$120"}
	var keys: Dictionary[String, String] = {"wall": "Q", "slow": "W", "boost": "E", "strike": "R", "mine": "Z",
		"bounty": "X", "mark": "C", "wind": "V"}
	for id: String in prices:
		expect_eq(buttons[id].label_text(), prices[id], id)
		expect_eq(buttons[id].hotkey, keys[id], id)
	# The bar sits along the bottom edge of the field, inside it.
	for id: String in buttons:
		var r: Rect2 = buttons[id].get_global_rect()
		expect_ge(r.position.x, 0.0, id)
		expect_le(r.end.x, float(Config.FIELD_W), id)
		expect_ge(r.position.y, float(Config.FIELD_H - 45), id)
		expect_le(r.end.y, float(Config.FIELD_H), id)


func test_hovering_a_button_explains_the_ability_in_the_sidebar() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var r: Rect2 = game.ability_bar.buttons["slow"].get_global_rect()
	await hover(r.get_center().x, r.get_center().y)
	await frames(2)
	expect_eq(game.hud.panel_title_text(), "Time slow  ·  $60")
	expect_contains(game.hud.panel_body_text(), "half speed")
	expect_contains(game.hud.panel_body_text(), "key W")
	expect_contains(game.hud.panel_body_text(), "cooldown 45 s")
	await hover(300, 200)
	await frames(2)
	expect_eq(game.hud.panel_title_text(), "Tips")


func test_buttons_turn_red_without_the_money_and_show_the_wait_afterwards() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.world.money = 70 # a time slow ($60) but nothing dearer
	await frames(2)
	expect_true(game.ability_bar.buttons["slow"].is_enabled())
	await click_button(game.ability_bar.buttons["slow"])
	await frames(2)
	expect_eq(game.world.money, 10)
	var slow: GameButton = game.ability_bar.buttons["slow"]
	expect_eq(slow.label_text(), "6 s", "it lasts 6 seconds")
	expect_true(slow.is_selected(), "lit while it lasts")
	# When it is over, the button shows how long until it works again.
	expect_true(await until(func() -> bool: return not game.world.is_active("slow"), 600))
	await frames(2)
	expect_match(slow.label_text(), "^\\d+ s$")
	expect_false(slow.is_enabled(), "cooling down")
	expect_false(slow.is_selected())
	expect_eq(game.ability_bar.buttons["strike"].label_text(), "$100")


# ---- the wall tool ---------------------------------------------------------------------

func test_a_wall_is_built_with_the_button_and_a_click_and_the_price_rises() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await click_button(game.ability_bar.buttons["wall"])
	expect_eq(game.aim, "wall")
	expect_true(game.ability_bar.buttons["wall"].is_selected())
	expect_eq(game.hud.panel_title_text(), "Wall  ·  $15")
	await hover_tile(5, 11) # the middle of the road
	expect_eq(game.ghost_state(), "ok")
	await click_tile(5, 11)
	expect_true(game.world.has_wall(5, 11))
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 15))
	expect_eq(game.ability_bar.buttons["wall"].label_text(), "$16")
	expect_eq(game.aim, "wall", "the tool stays picked, to build more")
	await click_tile(6, 11)
	expect_eq(game.world.walls.size(), 2)
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 15 - 16))


func test_walls_follow_the_hotkey_and_can_be_put_away() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_Q)
	expect_eq(game.aim, "wall")
	await press_key(KEY_Q)
	expect_eq(game.aim, "", "the same key again puts it away")
	await press_key(KEY_Q)
	var p: Vector2 = tile(5, 3)
	await click(p.x, p.y, MOUSE_BUTTON_RIGHT)
	expect_eq(game.aim, "", "right click puts it away")
	await press_key(KEY_Q)
	await press_key(KEY_ESCAPE)
	expect_eq(game.aim, "", "so does Esc")
	expect_false(game.paused, "(and Esc didn't pause)")
	await press_key(KEY_Q)
	await press_key(KEY_1)
	expect_eq(game.aim, "", "picking a tower puts the wall away")
	expect_eq(game.tool, "gun")
	await press_key(KEY_Q)
	expect_eq(game.tool, "", "and the other way round")


func test_a_wall_on_the_road_makes_enemies_go_around_and_a_full_block_is_refused() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var before: int = GameMap.dist_at(game.world.distance_field, 0, 10)
	await press_key(KEY_Q)
	await click_tile(1, 10)
	await click_tile(1, 11)
	expect_eq(game.world.walls.size(), 2)
	expect_gt(GameMap.dist_at(game.world.distance_field, 0, 10), before, "the way is longer now")
	# The third wall would close the last gap of the three-tile road.
	await hover_tile(1, 12)
	expect_eq(game.ghost_state(), "blocked")
	expect_eq(game.hint_text(), "That would block the path")
	await click_tile(1, 12)
	expect_false(game.world.has_wall(1, 12))
	expect_true(said(game, "That would block the path"))
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 15 - 16), "nothing was charged")


func test_a_wall_is_refused_where_nothing_can_stand_and_without_the_money() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_Q)
	await hover_tile(0, 10) # where enemies enter
	expect_eq(game.ghost_state(), "hidden")
	await click_tile(0, 10)
	expect_eq(game.world.walls.size(), 0)
	expect_true(said(game, "Can't build here"))
	game.world.money = 10
	await click_tile(5, 3)
	expect_false(game.world.has_wall(5, 3))
	expect_true(said(game, "Not enough money"))


func test_walls_on_a_level_without_walls_go_on_grass_only() -> void:
	use_profile(ALL_STARS, ALL_TECH)
	var game: GameScene = await open_game("riverside")
	if game == null:
		return
	await press_key(KEY_Q)
	await click_tile(3, 3) # road
	expect_eq(game.world.walls.size(), 0)
	expect_true(said(game, "Can't build here"))
	await click_tile(3, 5) # grass
	expect_true(game.world.has_wall(3, 5))


func test_a_tower_goes_on_a_wall_and_gets_the_range_of_high_ground() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_Q)
	await click_tile(5, 11)
	await press_key(KEY_1)
	await click_tile(5, 11)
	expect_eq(tower_names(game), ["gun@5,11"])
	var tower: Tower = game.world.towers[0]
	expect_true(tower.high_ground)
	await click_tile(5, 11)
	expect_true(game.selected == tower)
	expect_eq(game.hud.panel_title_text(), "Gun  ·  Level 1")
	expect_contains(game.hud.panel_body_text(), "On a wall: +25% range")


func test_a_wall_can_be_selected_and_sold_when_empty() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_Q)
	await click_tile(5, 11)
	await press_key(KEY_ESCAPE) # put the tool away
	expect_eq(game.aim, "")
	await click_tile(5, 11)
	expect_eq(game.selected_wall, Vector2i(5, 11))
	expect_eq(game.hud.panel_title_text(), "Wall")
	expect_contains(game.hud.panel_body_text(), "+25% range")
	expect_eq(game.hud.sell_button.label_text(), "Sell  +$15")
	expect_true(game.hud.sell_button.visible)
	expect_false(game.hud.upgrade_button.visible)
	await click_button(game.hud.sell_button)
	expect_false(game.world.has_wall(5, 11))
	expect_eq(game.hud.money_text(), "$ 250")
	expect_eq(game.selected_wall, GameMap.NO_TILE)
	expect_eq(game.hud.panel_title_text(), "Tips")


func test_a_wall_with_a_tower_is_sold_in_two_steps() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_Q)
	await click_tile(5, 11)
	await press_key(KEY_1)
	await click_tile(5, 11)
	await press_key(KEY_ESCAPE)
	await click_tile(5, 11) # selects the tower, not the wall
	await press_key(KEY_S)
	expect_eq(game.world.towers.size(), 0)
	expect_true(game.world.has_wall(5, 11), "the wall stays")
	await click_tile(5, 11)
	expect_eq(game.selected_wall, Vector2i(5, 11))
	await press_key(KEY_S)
	expect_false(game.world.has_wall(5, 11))


# ---- abilities that work at once ---------------------------------------------------------

func test_time_slow_by_hotkey() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_W)
	expect_true(game.world.is_active("slow"))
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 60))
	expect_true(said(game, "Time slow"))
	await press_key(KEY_W)
	expect_true(said(game, "Time slow: 45 s to go"), "it cools down")
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 60), "and nothing more is charged")


func test_the_boost_the_bounty_and_the_second_wind() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.world.money = 1000
	game.world.lives = 10
	await press_key(KEY_E)
	expect_true(game.world.is_active("boost"))
	expect_true(said(game, "Damage boost"))
	await press_key(KEY_X)
	expect_true(game.world.is_active("bounty"))
	expect_true(said(game, "Bounty: kills pay double"))
	await press_key(KEY_V)
	expect_eq(game.hud.lives_text(), "♥ 13")
	expect_true(said(game, "+3 ♥"))
	expect_eq(game.ability_bar.buttons["wind"].label_text(), "Used")
	expect_false(game.ability_bar.buttons["wind"].is_enabled())
	await press_key(KEY_V)
	expect_eq(game.hud.lives_text(), "♥ 13", "once per game")
	expect_true(said(game, "Second wind is used up"))
	expect_eq(game.world.money, 1000 - 80 - 50 - 120)


func test_an_ability_the_player_cannot_afford_says_so() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.world.money = 30
	await press_key(KEY_E)
	expect_false(game.world.is_active("boost"))
	expect_true(said(game, "Not enough money"))
	expect_eq(game.hud.money_text(), "$ 30")


# ---- aimed abilities -----------------------------------------------------------------------

func test_the_airstrike_is_aimed_with_a_click_and_lands_a_second_later() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var tank: Enemy = frozen_enemy(game, "tank", 300, 300)
	var far: Enemy = frozen_enemy(game, "tank", 600, 300)
	await press_key(KEY_R)
	expect_eq(game.aim, "strike")
	expect_eq(game.hud.panel_title_text(), "Airstrike  ·  $100")
	await hover(310, 300)
	await click(310, 300)
	expect_eq(game.aim, "", "one strike per pick")
	expect_eq(game.world.strikes.size(), 1)
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 100))
	expect_eq(tank.hitpoints, tank.max_hitpoints, "not yet")
	expect_true(await until(func() -> bool: return game.world.strikes.is_empty(), 200), "it landed")
	expect_lt(tank.hitpoints, tank.max_hitpoints)
	expect_eq(far.hitpoints, far.max_hitpoints, "out of the blast")
	await press_key(KEY_R)
	expect_eq(game.aim, "", "cooling down: it can't be picked")
	expect_true(said(game, "Airstrike: 39 s to go") or said(game, "Airstrike: 40 s to go"))


func test_the_focus_mark_needs_an_enemy_under_the_pointer() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var scout: Enemy = frozen_enemy(game, "scout", 300, 300)
	await press_key(KEY_C)
	expect_eq(game.aim, "mark")
	await click(500, 200) # nothing there
	expect_true(said(game, "No enemy there"))
	expect_eq(game.aim, "mark", "still aiming")
	expect_eq(game.hud.money_text(), "$ 250")
	await click(305, 300)
	expect_true(scout.is_marked())
	expect_eq(game.aim, "")
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 40))


func test_landmines_go_on_the_road_up_to_three() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_Z)
	expect_eq(game.aim, "mine")
	await hover_tile(5, 3) # grass
	expect_eq(game.ghost_state(), "hidden")
	await click_tile(5, 3)
	expect_true(said(game, "Enemies don't walk here"))
	expect_eq(game.world.mines.size(), 0)
	await hover_tile(5, 11)
	expect_eq(game.ghost_state(), "ok")
	await click_tile(5, 11)
	await click_tile(7, 11)
	await click_tile(9, 11)
	expect_eq(game.world.mines.size(), 3)
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 75))
	expect_eq(game.ability_bar.buttons["mine"].label_text(), "Max")
	await click_tile(11, 11)
	expect_true(said(game, "No more landmines"))
	await click_tile(5, 11) # one mine per tile: ... but the limit comes first
	expect_eq(game.world.mines.size(), 3)


func test_a_mine_goes_off_under_an_enemy_and_leaves_the_field() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var tank: Enemy = frozen_enemy(game, "tank", 5 * 40 + 20, 11 * 40 + 20)
	await press_key(KEY_Z)
	await click_tile(5, 11)
	await frames(3)
	expect_eq(game.world.mines.size(), 0, "it went off")
	expect_lt(tank.hitpoints, tank.max_hitpoints)


# ---- saving ----------------------------------------------------------------------------

func test_walls_towers_on_them_and_mines_are_still_there_after_continuing() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	await press_key(KEY_Q)
	await click_tile(5, 11)
	await press_key(KEY_1)
	await click_tile(5, 11)
	await press_key(KEY_Z)
	await click_tile(8, 11)
	await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE) # pause
	await click_button(game.pause_overlay.button("Main menu"))
	if not await wait_for_scene("MenuScene"):
		return
	await click_button((scene() as MenuScene).buttons["continue"])
	if not await wait_for_scene("GameScene"):
		return
	game = scene()
	expect_true(game.resumed)
	expect_true(game.world.has_wall(5, 11))
	expect_eq(tower_names(game), ["gun@5,11"])
	expect_true(game.world.towers[0].high_ground)
	expect_eq(game.world.mines.size(), 1)
	expect_eq(game.hud.money_text(), "$ %d" % (250 - 15 - 100 - 25))
	expect_eq(game.ability_bar.buttons["wall"].label_text(), "$16")
