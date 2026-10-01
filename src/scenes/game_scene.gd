class_name GameScene
extends Node2D
## A game in progress: runs the simulation at a fixed rate, draws it, and
## handles building, selecting, the sidebar, pausing and the end of the game.
## The level comes from Router (Router.goto_game).

const SPEEDS: Array[int] = [1, 2, 3]
const BLOCK_MESSAGE: Dictionary[World.BlockReason, String] = {
	World.BlockReason.TERRAIN: "Can't build here",
	World.BlockReason.OCCUPIED: "Tile taken",
	World.BlockReason.ENEMY: "Enemy in the way",
	World.BlockReason.BLOCKS_PATH: "That would block the path",
}
const GHOST_BLOCKED: Color = Color("#ff8080")

var world: World
## Tower kind being built, or "" for none.
var tool: String = ""
var selected: Tower = null
var paused: bool = false
var speed: int = 1
var level_id: String
var resumed: bool = false

var field: FieldView
var hud: Hud
var pause_overlay: Overlay
var win_overlay: Overlay
var lose_overlay: Overlay
var fx: ScreenFx

var _stage: Node2D
var _clock := FixedStep.new()
var _alpha: float = 0.0
var _hover_tile: Vector2i = GameMap.NO_TILE
var _hover: DrawNode
var _ghost: DrawNode
var _hint: TextLabel
var _banner: TextLabel
var _banner_tween: Tween
var _boss_bar: DrawNode
var _boss_text: TextLabel


func _ready() -> void:
	level_id = Router.launch_level_id
	var profile: Profile = Profile.load_profile()
	var endless: bool = level_id == Levels.ENDLESS.id
	world = World.new(Levels.by_id(level_id), Levels.endless_wave if endless else Callable(),
		profile.modifiers(), profile.unlocked_towers())
	var save: WorldSnapshot = profile.save
	if Router.launch_resume and save != null and save.level_id == world.level_id:
		world.restore(save)
		resumed = true
	else:
		_autosave() # a fresh start replaces any older saved game

	_stage = Node2D.new()
	add_child(_stage)
	fx = ScreenFx.new(_stage, self)
	add_child(fx)
	field = FieldView.new(world)
	field.fx = fx
	_stage.add_child(field)
	_hover = DrawNode.new(_draw_hover, FieldView.D_OVERLAY)
	_stage.add_child(_hover)
	_ghost = DrawNode.new(func(ci: CanvasItem) -> void:
		if not tool.is_empty():
			TowerArt.draw_icon(ci, tool, Vector2.ZERO, Config.TILE), FieldView.D_OVERLAY)
	_ghost.visible = false
	_stage.add_child(_ghost)
	_hint = Ui.text(_stage, 0, 0, "", 13, Palette.RED, true, Vector2(0.5, 1)).set_outline(3)
	_hint.z_index = FieldView.D_FLOATERS
	_banner = Ui.text(_stage, Config.FIELD_W / 2.0, 70, "", 30, Palette.TEXT, true, Vector2(0.5, 0.5)).set_outline(5)
	_banner.z_index = FieldView.D_FLOATERS
	_banner.modulate.a = 0
	_boss_bar = DrawNode.new(_draw_boss_bar, FieldView.D_FLOATERS)
	_stage.add_child(_boss_bar)
	_boss_text = Ui.text(_stage, Config.FIELD_W / 2.0, 12, "", 13, Palette.TEXT, true, Vector2(0.5, 0)).set_outline(3)
	_boss_text.z_index = FieldView.D_FLOATERS
	hud = Hud.new(self)
	_stage.add_child(hud)

	var restart: Callable = func() -> void: Router.goto_game(level_id)
	pause_overlay = Overlay.new("Paused", Palette.TEXT, [
		Overlay.Action.new("Resume", toggle_pause, true),
		Overlay.Action.new("Restart level", restart),
		Overlay.Action.new("Level select", Router.goto_levels),
		Overlay.Action.new("Main menu", Router.goto_menu),
	])
	win_overlay = Overlay.new("Victory!", Palette.GOLD, [
		Overlay.Action.new("Level select", Router.goto_levels, true),
		Overlay.Action.new("Play again", restart),
	])
	lose_overlay = Overlay.new("Overrun!" if endless else "Defeat", Palette.RED, [
		Overlay.Action.new("Try again", restart, true),
		Overlay.Action.new("Level select", Router.goto_levels),
	])
	for o: Overlay in [pause_overlay, win_overlay, lose_overlay]:
		_stage.add_child(o)

	var title: String = "Endless mode" if endless else world.map.name
	show_banner(title + "\nGame resumed" if resumed else title, Palette.TEXT)
	Audio.set_intensity(0)


# ---- what the sidebar can do ---------------------------------------------------

func music_on() -> bool:
	return Profile.load_profile().music


func sfx_on() -> bool:
	return Profile.load_profile().sfx


## Picks the tower to build ("" for none).
func select_tool(kind: String) -> void:
	if not kind.is_empty() and not world.is_unlocked(kind):
		Audio.play("error")
		return
	tool = kind
	if not kind.is_empty():
		selected = null


func start_wave() -> void:
	if is_modal_open():
		return
	if world.start_next_wave():
		Audio.play("waveStart")


func toggle_pause() -> void:
	if world.status != World.Status.PLAYING:
		return
	paused = not paused
	if paused:
		pause_overlay.show_dialog("Esc to resume")
	else:
		pause_overlay.hide_dialog()


func toggle_speed() -> void:
	speed = SPEEDS[(SPEEDS.find(speed) + 1) % SPEEDS.size()]


func toggle_music() -> void:
	var p: Profile = Profile.load_profile()
	p.music = not p.music
	Audio.set_music(p.music)
	Profile.save_profile(p)


func toggle_sfx() -> void:
	var p: Profile = Profile.load_profile()
	p.sfx = not p.sfx
	Audio.set_sfx(p.sfx)
	Profile.save_profile(p)


func upgrade_selected() -> void:
	if selected == null:
		return
	if world.upgrade(selected):
		_autosave()
	else:
		Audio.play("error")


func sell_selected() -> void:
	if selected != null and world.sell(selected):
		selected = null
		_autosave()


func cycle_target_mode() -> void:
	var t: Tower = selected
	if t == null or t.def.behavior == Towers.Behavior.SUPPORT or t.def.behavior == Towers.Behavior.AURA:
		return
	var i: int = Towers.TARGET_MODES.find(t.target_mode)
	world.set_target_mode(t, Towers.TARGET_MODES[(i + 1) % Towers.TARGET_MODES.size()])
	_autosave()


# ---- input -------------------------------------------------------------------

func is_modal_open() -> bool:
	return paused or world.status != World.Status.PLAYING


func _input(event: InputEvent) -> void:
	# Track the hovered tile everywhere (the sidebar and dialogs clear it).
	var motion := event as InputEventMouseMotion
	if motion != null:
		_update_hover(motion.position)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed:
		_update_hover(mb.position)
		if is_modal_open():
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			tool = ""
			selected = null
		elif mb.button_index == MOUSE_BUTTON_LEFT and _hover_tile != GameMap.NO_TILE:
			click_tile(_hover_tile.x, _hover_tile.y)
		get_viewport().set_input_as_handled()
		return

	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	match key.keycode:
		KEY_ESCAPE:
			if (not tool.is_empty() or selected != null) and not is_modal_open():
				tool = ""
				selected = null
			else:
				toggle_pause()
			return
		KEY_P:
			toggle_pause()
			return
		KEY_M:
			toggle_music()
			return
	if is_modal_open():
		return
	var n: int = key.keycode - KEY_0
	if n >= 1 and n <= Towers.KINDS.size():
		var kind: String = Towers.KINDS[n - 1]
		select_tool("" if tool == kind else kind)
		return
	match key.keycode:
		KEY_SPACE:
			start_wave()
		KEY_F:
			toggle_speed()
		KEY_U:
			upgrade_selected()
		KEY_S, KEY_DELETE:
			sell_selected()
		KEY_T:
			cycle_target_mode()


func _notification(what: int) -> void:
	# Pause automatically when the window loses focus.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and world != null and not is_modal_open():
		toggle_pause()


func _update_hover(p: Vector2) -> void:
	if p.x >= 0 and p.x < Config.FIELD_W and p.y >= 0 and p.y < Config.FIELD_H:
		_hover_tile = Vector2i(floori(p.x / Config.TILE), floori(p.y / Config.TILE))
	else:
		_hover_tile = GameMap.NO_TILE


## Builds, or selects, at a tile (a click on the field).
func click_tile(col: int, row: int) -> void:
	var existing: Tower = world.tower_at(col, row)
	if not tool.is_empty():
		if existing != null:
			# Clicking a tower while building selects it instead.
			tool = ""
			selected = existing
			Audio.play("click")
			return
		var reason: World.BlockReason = world.build_block_reason(col, row)
		if reason != World.BlockReason.NONE:
			field.float_text(col * Config.TILE + Config.TILE / 2.0, row * Config.TILE, BLOCK_MESSAGE[reason], Palette.RED)
			Audio.play("error")
			return
		if not world.can_afford(tool):
			field.float_text(col * Config.TILE + Config.TILE / 2.0, row * Config.TILE, "Not enough money", Palette.RED)
			Audio.play("error")
			return
		world.build(tool, col, row)
		_autosave()
		return
	selected = existing
	if existing != null:
		Audio.play("click")


# ---- frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_modal_open():
		_alpha = _clock.advance(delta * 1000.0, speed, world.update)
	if selected != null and not world.towers.has(selected):
		selected = null
	_handle_scene_events(world.events)
	field.handle_events(world.events)
	field.sync(_alpha)
	_update_hover_objects()
	_boss_bar.queue_redraw()
	hud.refresh()
	Audio.set_intensity(1 if world.wave_in_progress() and not is_modal_open() else 0)


func _handle_scene_events(events: Array[WorldEvent]) -> void:
	var total: int = world.total_waves()
	for ev: WorldEvent in events:
		match ev.type:
			WorldEvent.Type.WAVE_STARTED:
				var last: bool = total >= 0 and ev.wave == total - 1
				var wave: Wave = world.wave_at(ev.wave)
				var boss: bool = wave != null and wave.has_boss()
				var text: String = "Final wave!" if last else ("Wave %d\nBoss incoming!" % (ev.wave + 1) if boss else "Wave %d" % (ev.wave + 1))
				show_banner(text, Palette.RED if boss else Palette.TEXT)
				if ev.early > 0:
					field.float_text(Config.FIELD_W / 2.0, 110, "Early call +$%d" % ev.early, Palette.GOLD)
			WorldEvent.Type.WAVE_CLEARED:
				if total < 0 or ev.wave < total - 1:
					var interest: String = ("\nInterest +$%d" % ev.interest) if ev.interest > 0 else ""
					show_banner("Wave cleared  +$%d%s" % [ev.bonus, interest], Palette.GOLD)
					Audio.play("waveClear")
				_autosave()
			WorldEvent.Type.WON:
				_on_game_over(true)
			WorldEvent.Type.LOST:
				_on_game_over(false)


func _on_game_over(won: bool) -> void:
	tool = ""
	selected = null
	var p: Profile = Profile.load_profile()
	p.save = null
	Profile.save_profile(p)
	Audio.play("win" if won else "lose")
	if world.endless:
		var best: bool = p.record_endless(world.waves_cleared)
		lose_overlay.show_dialog("You survived %d waves.\n%s" % [world.waves_cleared,
			"New personal best!" if best else "Best: %d waves" % p.endless_best])
		return
	if won:
		var stars: int = Profile.stars_for(world.lives, world.start_lives)
		var new_towers: Array[String] = p.record_win(world.level_id, stars)
		var unlocked: String = ""
		if not new_towers.is_empty():
			var names: PackedStringArray = []
			for kind: String in new_towers:
				names.append(Towers.get_def(kind).name)
			unlocked = "\nUnlocked: %s!" % ", ".join(names)
		win_overlay.show_dialog("%s\n%d of %d lives left.%s" % [Format.star_string(stars), world.lives, world.start_lives, unlocked])
	else:
		lose_overlay.show_dialog("You reached wave %d of %d." % [world.wave_index + 1, world.total_waves()])


## Saves the game so it can be continued later (only possible between waves).
func _autosave() -> void:
	var snap: WorldSnapshot = world.snapshot()
	if snap != null:
		var p: Profile = Profile.load_profile()
		p.save = snap
		Profile.save_profile(p)


func show_banner(text: String, color: Color) -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.show_text(text)
	_banner.set_color(color)
	_banner.pivot_offset = _banner.size / 2
	_banner.modulate.a = 0
	_banner.scale = Vector2.ONE * 0.8
	_banner_tween = _banner.create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.4).set_delay(1.5)


func _draw_boss_bar(g: CanvasItem) -> void:
	var boss: Enemy = null
	for e: Enemy in world.enemies:
		if e.def.boss:
			boss = e
			break
	if boss == null:
		_boss_text.show_text("")
		return
	var w: float = 300
	var x: float = (Config.FIELD_W - w) / 2
	var y: float = 32
	var f: float = maxf(0.0, boss.hitpoints / boss.max_hitpoints)
	Paint.fill_rounded_rect(g, x - 3, y - 3, w + 6, 16, 5, Color(0, 0, 0, 0.6))
	Paint.fill_rounded_rect(g, x, y, w, 10, 3, Palette.rgb(0x5c1a1a))
	Paint.fill_rounded_rect(g, x, y, maxf(6, w * f), 10, 3, Palette.RED)
	_boss_text.show_text("%s  %d / %d" % [boss.def.name, ceili(boss.hitpoints), boss.max_hitpoints])


func _update_hover_objects() -> void:
	_hover.queue_redraw()
	_ghost.visible = false
	_hint.visible = false
	if _hover_tile == GameMap.NO_TILE or is_modal_open() or tool.is_empty():
		return
	var col: int = _hover_tile.x
	var row: int = _hover_tile.y
	if world.tower_at(col, row) != null:
		return
	var reason: World.BlockReason = world.build_block_reason(col, row)
	if reason == World.BlockReason.TERRAIN:
		return
	var ok: bool = reason == World.BlockReason.NONE and world.can_afford(tool)
	_ghost.position = GameMap.tile_center(_hover_tile)
	_ghost.modulate = Color(1, 1, 1, 0.75) if ok else Color(GHOST_BLOCKED, 0.75)
	_ghost.visible = true
	_ghost.queue_redraw()
	if reason != World.BlockReason.NONE:
		_hint.show_text(BLOCK_MESSAGE[reason])
		_hint.move_to(col * Config.TILE + Config.TILE / 2.0, row * Config.TILE - 2)
		_hint.visible = true


func _draw_hover(g: CanvasItem) -> void:
	var t: float = Config.TILE
	if selected != null and not is_modal_open():
		var s: Tower = selected
		g.draw_circle(Vector2(s.x, s.y), s.attack_range, Color(1, 1, 1, 0.1))
		Paint.stroke_circle(g, s.x, s.y, s.attack_range, 2, Color(Palette.GOLD, 0.8))
		g.draw_rect(Rect2(s.col * t + 1, s.row * t + 1, t - 2, t - 2), Palette.GOLD, false, 2)
	if _hover_tile == GameMap.NO_TILE or is_modal_open():
		return
	var col: int = _hover_tile.x
	var row: int = _hover_tile.y
	var center: Vector2 = GameMap.tile_center(_hover_tile)
	var tower: Tower = world.tower_at(col, row)
	if not tool.is_empty() and tower == null:
		var reason: World.BlockReason = world.build_block_reason(col, row)
		var ok: bool = reason == World.BlockReason.NONE and world.can_afford(tool)
		var color: Color = Color.WHITE if ok else Palette.RED
		if reason != World.BlockReason.TERRAIN:
			var reach: float = Towers.get_def(tool).levels[0].attack_range \
				* (Config.HIGH_GROUND_RANGE if world.map.is_high_ground(col, row) else 1.0)
			g.draw_circle(center, reach, Color(color, 0.12))
			Paint.stroke_circle(g, center.x, center.y, reach, 2, Color(color, 0.6))
		g.draw_rect(Rect2(col * t + 1, row * t + 1, t - 2, t - 2), Color(color, 0.9), false, 2)
	elif tower != null and tower != selected:
		g.draw_circle(Vector2(tower.x, tower.y), tower.attack_range, Color(1, 1, 1, 0.08))
		Paint.stroke_circle(g, tower.x, tower.y, tower.attack_range, 2, Color(1, 1, 1, 0.45))


# ---- what the player sees (read by the scene tests) ---------------------------

## The latest banner ("Wave 3", "Wave cleared ...").
func banner_text() -> String:
	return _banner.text


## Whether the banner is (mostly) visible right now.
func banner_showing() -> bool:
	return _banner.modulate.a > 0.5


## The hint above the hovered tile ("" when none is shown).
func hint_text() -> String:
	return _hint.text if _hint.visible else ""


## The build preview: "hidden", "ok" (white) or "blocked" (tinted red).
func ghost_state() -> String:
	if not _ghost.visible:
		return "hidden"
	return "ok" if _ghost.modulate.g > 0.9 else "blocked"


## The boss health label at the top ("" without a boss).
func boss_label() -> String:
	return _boss_text.text
