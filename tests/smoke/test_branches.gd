extends SceneTestCase
## Choosing a tower's branch in the sidebar, like a player: a level-3 tower
## offers two buttons instead of Upgrade, hovering one explains it, clicking
## one grows the tower.


const BRANCHES: Array[String] = ["minigun", "sniper"]


func near(a: Color, b: Color, tolerance: float = 0.04) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


## A gun at level 3 on Meadow's grass, selected, with plenty of money.
func level_3_gun(game: GameScene, col: int = 6, row: int = 9) -> Tower:
	game.world.money = 5000
	await press_key(KEY_1)
	await click_tile(col, row)
	await click_tile(col, row)
	await click_button(game.hud.upgrade_button)
	await click_button(game.hud.upgrade_button)
	return game.selected


func test_a_level_3_tower_offers_its_two_branches() -> void:
	use_profile({}, BRANCHES)
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var hud: Hud = game.hud
	var t: Tower = await level_3_gun(game)
	expect_true(t != null and t.level == 2, "a level-3 gun is selected")
	if t == null:
		return
	expect_eq(hud.panel_title_text(), "Gun  ·  Level 3")
	expect_false(hud.upgrade_button.visible, "no plain upgrade any more")
	expect_true(hud.branch_buttons[0].visible and hud.branch_buttons[1].visible)
	expect_eq(hud.branch_buttons[0].label_text(), "Minigun")
	expect_eq(hud.branch_buttons[0].sublabel_text(), "$%d" % game.world.branch_cost_of(t, "minigun"))
	expect_eq(hud.branch_buttons[1].label_text(), "Sniper")
	expect_true(hud.target_button.visible and hud.sell_button.visible)

	# Hovering a branch explains it, on a help card beside the tower's card.
	var r: Rect2 = hud.branch_buttons[1].get_global_rect()
	await hover(r.get_center().x, r.get_center().y)
	await frames(2)
	expect_eq(hud.panel_title_text(), "Sniper  ·  $%d" % game.world.branch_cost_of(t, "sniper"))
	expect_contains(hud.panel_body_text(), "through a line of enemies")
	expect_contains(hud.panel_extra_text(), "Hits 3 in a line")
	expect_true(hud.help.get_global_rect().intersects(game.card.get_global_rect()) == false, "beside the card, not on it")

	# Clicking it grows the tower.
	var money: int = game.world.money
	var price: int = game.world.branch_cost_of(t, "sniper")
	await click_button(hud.branch_buttons[1])
	await hover_field(400, 300)
	await frames(2)
	expect_eq(t.branch_id, "sniper")
	expect_eq(game.world.money, money - price)
	expect_eq(hud.panel_title_text(), "Sniper  ·  Level 4")
	await click_button(game.card.details_button) # the stats fold out
	expect_contains(hud.panel_body_text(), "Hits 3 in a line")
	expect_false(hud.branch_buttons[0].visible, "the choice is made")
	expect_true(hud.upgrade_button.visible)
	expect_eq(hud.upgrade_button.label_text(), "Upgrade  $%d" % game.world.upgrade_cost_of(t))
	expect_true(game.field.floating_texts().has("Sniper!"), "the new tower is announced")
	await press_key(KEY_U)
	expect_eq(t.level, 4)
	expect_eq(hud.panel_title_text(), "Sniper  ·  Level 5")
	expect_eq(hud.upgrade_button.label_text(), "Max level")
	expect_false(hud.upgrade_button.is_enabled())


func test_u_at_level_3_asks_for_a_branch() -> void:
	use_profile({}, BRANCHES)
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var t: Tower = await level_3_gun(game)
	if t == null:
		return
	var money: int = game.world.money
	await press_key(KEY_U)
	expect_eq(t.level, 2)
	expect_eq(game.world.money, money)
	expect_true(game.field.floating_texts().has("Choose a branch"))


func test_locked_and_unaffordable_branches_cannot_be_chosen() -> void:
	use_profile({}, BRANCHES)
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var hud: Hud = game.hud
	game.world.locked_branches["minigun"] = true
	var t: Tower = await level_3_gun(game)
	if t == null:
		return
	await frames(1)
	expect_eq(hud.branch_buttons[0].label_text(), "🔒 Minigun")
	expect_false(hud.branch_buttons[0].is_enabled())
	await click_button(hud.branch_buttons[0])
	expect_eq(t.branch_id, "")
	var r: Rect2 = hud.branch_buttons[0].get_global_rect()
	await hover(r.get_center().x, r.get_center().y)
	await frames(2)
	expect_contains(hud.panel_extra_text(), "Unlock it in the tech tree")
	game.world.money = 10
	await frames(1)
	expect_false(hud.branch_buttons[1].is_enabled(), "too expensive")
	await click_button(hud.branch_buttons[1])
	expect_eq(t.branch_id, "")


func test_a_branched_tower_is_still_there_after_resuming() -> void:
	use_profile({}, BRANCHES)
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var t: Tower = await level_3_gun(game)
	if t == null:
		return
	await click_button(game.hud.branch_buttons[0])
	expect_eq(t.branch_id, "minigun")
	# The game was saved: continue it from the menu.
	Router.goto_menu()
	if not await wait_for_scene("MenuScene"):
		return
	var menu: MenuScene = scene()
	expect_true(menu.buttons.has("continue"), "a game to continue")
	if not menu.buttons.has("continue"):
		return
	await click_button(menu.buttons["continue"])
	if not await wait_for_scene("GameScene"):
		return
	var resumed: GameScene = scene()
	expect_eq(resumed.world.towers.size(), 1)
	if resumed.world.towers.is_empty():
		return
	var r: Tower = resumed.world.towers[0]
	expect_eq(r.branch_id, "minigun")
	await click_tile(r.col, r.row)
	expect_eq(resumed.hud.panel_title_text(), "Minigun  ·  Level 4")


func test_a_branch_looks_different_from_its_tower() -> void:
	if not rendering_available():
		skip("needs a display; tests/run.sh uses xvfb-run")
		return
	use_profile({}, BRANCHES)
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var t: Tower = await level_3_gun(game)
	if t == null:
		return
	await click_tile(0, 0) # deselect: no range circle over the tower
	game.speed = 0
	await frames(3)
	var before: Image = await screenshot()
	var w: World = game.world
	w.choose_branch(t, "sniper")
	await frames(40) # the upgrade sparkle fades
	var after: Image = await screenshot()
	var changed: int = 0
	for dy: int in range(-16, 17, 4):
		for dx: int in range(-16, 17, 4):
			if not near(field_pixel(before, t.x + dx, t.y + dy), field_pixel(after, t.x + dx, t.y + dy), 0.08):
				changed += 1
	expect_gt(changed, 10, "the sniper is drawn, not the gun")


func test_a_sniper_shot_draws_a_tracer() -> void:
	if not rendering_available():
		skip("needs a display; tests/run.sh uses xvfb-run")
		return
	use_profile({}, BRANCHES)
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var w: World = game.world
	w.money = 5000
	var t: Tower = w.build("gun", 3, 1)
	w.upgrade(t)
	w.upgrade(t)
	w.choose_branch(t, "sniper")
	await frames(40)
	# A frozen enemy far to the right on the grass: the tracer crosses the grass between.
	var e: Enemy = w.spawn("brute")
	e.apply_slow(1.0, 100_000)
	e.nav.x = t.x + 240
	e.nav.y = t.y
	e.x = t.x + 240
	e.y = t.y
	e.prev_x = e.x
	e.prev_y = e.y
	var mid := Vector2(t.x + 120, t.y)
	expect_true(await until(func() -> bool: return t.shooting, 120), "it fires")
	var img: Image = await screenshot()
	var c: Color = field_pixel(img, mid.x, mid.y)
	expect_gt(c.r + c.g + c.b, 2.2, "a bright line over the grass")
