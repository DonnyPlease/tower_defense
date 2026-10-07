extends SceneTestCase
## Level variants on the level select screen and in the game: choosing one,
## playing it, and what it looks like (night is dark).


func open_levels() -> LevelSelectScene:
	Router.goto_levels()
	if not await wait_for_scene("LevelSelectScene"):
		return null
	return scene()


func test_without_variants_a_card_just_plays_the_level() -> void:
	use_profile({"meadow": 3})
	var levels: LevelSelectScene = await open_levels()
	if levels == null:
		return
	expect_true(levels.variant_buttons.is_empty(), "no variants unlocked: no switch")


func test_choosing_and_playing_a_variant() -> void:
	var p: Profile = use_profile({"meadow": 3, "riverside": 1, "meadow@night": 2}, ["night", "reversed"])
	p.music = false
	var levels: LevelSelectScene = await open_levels()
	if levels == null:
		return
	expect_true(levels.variant_buttons.has("meadow"))
	expect_false(levels.variant_buttons.has("openfield"), "locked levels have no switch")
	expect_false(levels.variant_buttons.has("endless"), "endless has no variants")
	var b: GameButton = levels.variant_buttons["meadow"]
	expect_eq(b.label_text(), "Normal  ▸")
	expect_eq(levels.status_text("meadow"), "★★★")
	await click_button(b)
	expect_eq(b.label_text(), "Night  ▸")
	expect_eq(levels.status_text("meadow"), "★★☆", "the night's own stars")
	expect_contains(levels.description_text("meadow"), "20% less far")
	await click_button(b)
	expect_eq(b.label_text(), "Reversed  ▸")
	expect_eq(levels.status_text("meadow"), "☆☆☆")
	await click_button(b)
	expect_eq(b.label_text(), "Normal  ▸", "back round to the level as designed")
	await click_button(b)
	await click_button(levels.play_buttons["meadow"])
	if not await wait_for_scene("GameScene"):
		return
	var game: GameScene = scene()
	expect_eq(game.level_id, "meadow@night")
	expect_eq(game.world.variant, "night")
	expect_contains(game.banner_text(), "Meadow (Night)")
	await press_key(KEY_1)
	await click_tile(6, 9)
	expect_eq(game.world.towers.size(), 1)
	if game.world.towers.is_empty():
		return
	var t: Tower = game.world.towers[0]
	expect_near(t.attack_range, Towers.get_def("gun").levels[0].attack_range * 0.8)
	# Restarting keeps the variant.
	await press_key(KEY_ESCAPE)
	await press_key(KEY_ESCAPE)
	var old: int = game.get_instance_id()
	await click_button(game.pause_overlay.button("Restart level"))
	expect_true(await until(func() -> bool: return scene() is GameScene and scene().get_instance_id() != old, 300))
	expect_eq((scene() as GameScene).level_id, "meadow@night")


func test_reversed_enemies_come_from_the_other_side() -> void:
	use_profile({"meadow": 3}, ["reversed"])
	var game: GameScene = await open_game("riverside@reversed")
	if game == null:
		return
	await press_key(KEY_SPACE)
	expect_true(await until(func() -> bool: return not game.world.enemies.is_empty(), 300), "an enemy appears")
	if game.world.enemies.is_empty():
		return
	expect_gt(game.world.enemies[0].x, Config.FIELD_W / 2.0, "from the right, where they used to leave")


func test_night_is_dark_except_around_towers() -> void:
	if not rendering_available():
		skip("needs a display; tests/run.sh uses xvfb-run")
		return
	use_profile({"meadow": 3}, ["night"])
	var game: GameScene = await open_game("meadow@night")
	if game == null:
		return
	expect_not_null(game.field.night)
	game.world.build("gun", 3, 1)
	await frames(40) # the dust settles
	var img: Image = await screenshot()
	var far: Color = pixel_at(img, tile(16, 13).x + 12, tile(16, 13).y + 12) # grass far from the tower
	var lit: Color = pixel_at(img, tile(4, 1).x, tile(4, 1).y + 12) # grass right next to it
	expect_lt(far.get_luminance(), Palette.GRASS.get_luminance() * 0.7, "dark far from the towers")
	expect_gt(lit.get_luminance(), far.get_luminance() * 1.4, "lit next to a tower")


func test_a_normal_level_has_no_darkness() -> void:
	use_profile()
	var game: GameScene = await open_game("meadow")
	if game == null:
		return
	expect_null(game.field.night)
