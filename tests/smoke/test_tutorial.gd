extends SceneTestCase
## The first-game tutorial on Meadow, and the glow on shots.


## A fresh player's profile: the tutorial hasn't been seen yet.
func first_timer() -> Profile:
	var p: Profile = use_profile()
	p.tutorial_done = false
	Profile.save_profile(p)
	return p


func test_the_tutorial_walks_a_new_player_through_the_first_steps() -> void:
	first_timer()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var t: Tutorial = game.tutorial
	expect_not_null(t, "a first game on Meadow has the tutorial")
	if t == null:
		return
	expect_contains(t.hint_text(), "Build a tower")
	await press_key(KEY_1)
	await click_tile(6, 9)
	await frames(1)
	expect_contains(t.hint_text(), "Start the first wave")
	await press_key(KEY_SPACE)
	await frames(1)
	expect_contains(t.hint_text(), "Click one of your towers")
	await press_key(KEY_ESCAPE) # put the gun tool away
	await click_tile(6, 9)
	await frames(1)
	expect_contains(t.hint_text(), "Upgrade it")
	game.world.money = 1000
	await press_key(KEY_U)
	await frames(1)
	expect_contains(t.hint_text(), "Walls (Q)")
	expect_true(await until(func() -> bool: return t.hint_text().is_empty(), 900), "the last hint goes away")
	Profile.forget_cache()
	expect_true(Profile.load_profile().tutorial_done, "and the tutorial is done for good")
	game = await open_game("meadow")
	if game == null:
		return
	expect_null(game.tutorial, "not shown again")


func test_the_tutorial_can_be_skipped_and_only_runs_on_meadow() -> void:
	first_timer()
	var game: GameScene = await open_game("riverside")
	if game == null:
		return
	expect_null(game.tutorial, "only Meadow teaches")
	game = await open_game("meadow")
	if game == null:
		return
	expect_not_null(game.tutorial)
	await click_button(game.tutorial.skip_button)
	expect_eq(game.tutorial.hint_text(), "")
	expect_false(game.tutorial.visible)
	Profile.forget_cache()
	expect_true(Profile.load_profile().tutorial_done)


func test_the_tutorial_does_not_block_the_field() -> void:
	first_timer()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	var r: Rect2 = game.tutorial.get_global_rect()
	expect_lt(r.end.y, 70.0, "a strip along the top")
	# A click under the hint (not on Skip) still reaches the field.
	await click(r.position.x + 30, r.position.y + 20)
	expect_true(game.build_menu.is_open(), "the tile under it was clicked")


func test_shots_glow() -> void:
	if not rendering_available():
		skip("needs a display; tests/run.sh uses xvfb-run")
		return
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	game.speed = 0 # the screen still updates
	var at: Vector2 = GameMap.tile_center(Vector2i(4, 1))
	await frames(2)
	var before: Color = field_pixel(await screenshot(), at.x, at.y + 6)
	var b := Bullet.new(at.x, at.y, 0, 0, 1, Towers.BulletType.NORMAL, true, true)
	game.world.bullets.append(b)
	await frames(2)
	var lit: Color = field_pixel(await screenshot(), at.x, at.y + 6)
	expect_gt(lit.get_luminance(), before.get_luminance() + 0.05, "the grass next to the bullet is lit up")
	expect_not_null(game.field.glow.material, "an additive layer")
