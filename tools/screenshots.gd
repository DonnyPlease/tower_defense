extends Node
## Renders every screen to PNG files, for checking the art and layout.
##
##   godot --path . res://tools/screenshots.tscn -- <output folder>
##
## Needs a display (e.g. xvfb-run); uses a throwaway profile.


func _ready() -> void:
	# This scene is replaced by the screens it visits, so the work is done by
	# a node that lives next to the scenes, under the root.
	var driver := Driver.new()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		driver.out = args[0]
	get_tree().root.add_child.call_deferred(driver)


class Driver:
	extends Node

	var out: String = "user://screenshots"

	func _ready() -> void:
		DirAccess.make_dir_recursive_absolute(out)
		get_tree().create_timer(120).timeout.connect(func() -> void:
			push_error("Screenshots timed out")
			get_tree().quit(2))
		_run()


	func _run() -> void:
		Profile.storage_path = "user://screenshots_profile.json"
		Profile.forget_cache()
		var p: Profile = Profile.reset()
		p.stars = {"meadow": 3, "riverside": 2, "highlands": 1}
		for n: Tech.TechNode in Tech.NODES:
			if n.kind != Tech.Kind.PERK:
				p.free_tech[n.id] = true
		p.music = false
		p.sfx = false
		Profile.save_profile(p)
		Audio.set_music(false)
		Audio.set_sfx(false)

		Router.goto_menu()
		await _wait_for("MenuScene")
		await _frames(90)
		await _snap("menu")
		Router.goto_levels()
		await _wait_for("LevelSelectScene")
		await _snap("levels")
		var levels: LevelSelectScene = get_tree().current_scene
		levels.next_variant("meadow")
		await _frames(2)
		await _snap("levels_variant")
		TechTreeScene.last_page = TechTreeScene.Page.TOWERS
		Router.goto_tech()
		await _wait_for("TechTreeScene")
		await _snap("tech_tree")
		var tech: TechTreeScene = get_tree().current_scene
		tech.show_page(TechTreeScene.Page.UPGRADES, false)
		await _frames(3)
		await _snap("tech_tree_upgrades")

		for id: String in ["meadow", "riverside", "highlands", "openfield", "highlands@night"]:
			Router.goto_game(id)
			await _wait_for("GameScene")
			var s: GameScene = get_tree().current_scene
			if id == "meadow":
				await _frames(30)
				await _snap("field_orders")
			if not s.world.perk_offer.is_empty():
				s.world.choose_run_perk(s.world.perk_offer[0])
			_busy_wave(s)
			await _frames(150)
			await _snap("game_" + id)
			if id == "meadow":
				# The selected tower's details folded out, a tower's help and the abilities' drop-down.
				s.card.toggle_details()
				s.hud.show_tower_help("cannon", true)
				s.ability_bar.open()
				await _frames(20)
				await _snap("game_meadow_menus")
				s.card.toggle_details()
				s.hud.show_tower_help("cannon", false)
				s.ability_bar.close()
				await _phone(s)

		var game: GameScene = get_tree().current_scene
		game.toggle_pause()
		await _frames(3)
		await _snap("paused")
		print("Screenshots saved to ", ProjectSettings.globalize_path(out))
		Profile.storage_path = Profile.DEFAULT_PATH
		Profile.forget_cache()
		get_tree().quit()


	## Lots of towers, a mixed wave with a boss, a selected tower, a build preview.
	func _busy_wave(s: GameScene) -> void:
		var w: World = s.world
		w.money = 100000
		var n: int = 0
		for r: int in Config.ROWS:
			for c: int in range(2, 18, 3):
				if n >= 14:
					break
				var t: Tower = w.build(Towers.KINDS[n % Towers.KINDS.size()], c, r)
				if t != null:
					n += 1
					if n % 2 == 1:
						w.upgrade(t)
					elif n > 6:
						# Grown into a branch.
						w.upgrade(t)
						w.upgrade(t)
						w.choose_branch(t, t.def.branches[n % 2].id)
		for type: String in ["boss", "splitter", "healer", "drone", "shielded", "armored", "tank", "scout"]:
			w.spawn(type)
		w.start_next_wave()
		s.selected = w.towers[1]
		s.field.sync(0) # draw the new towers right away
		s.speed = 2


	## The same game on a phone held sideways, with a notch on the left: a
	## bigger rail in two columns.
	func _phone(s: GameScene) -> void:
		var window: Window = get_window()
		var before: Vector2i = window.size
		Screen.forced_ui_scale = Screen.MAX_UI_SCALE
		Screen.forced_insets = Vector4(40, 0, 0, 14)
		window.size = Vector2i(844, 390)
		await _frames(20)
		await _snap("game_meadow_phone")
		s.ability_bar.open()
		s.hud.show_tower_help("missile", true)
		await _frames(20)
		await _snap("game_meadow_phone_menus")
		s.ability_bar.close()
		s.hud.show_tower_help("missile", false)
		Screen.forced_ui_scale = 0.0
		Screen.forced_insets = null
		window.size = before
		await _frames(20)


	func _wait_for(class_title: String) -> void:
		for i: int in 300:
			await get_tree().process_frame
			var scene: Node = get_tree().current_scene
			if scene != null and scene.get_script() != null and (scene.get_script() as Script).get_global_name() == class_title:
				await _frames(3)
				return
		push_error("Timed out waiting for %s" % class_title)


	func _frames(n: int) -> void:
		for i: int in n:
			await get_tree().process_frame


	func _snap(name: String) -> void:
		await RenderingServer.frame_post_draw
		var path: String = out.path_join(name + ".png")
		get_viewport().get_texture().get_image().save_png(path)
