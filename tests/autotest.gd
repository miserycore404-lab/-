extends Node
## Scripted play-through for headless verification. Lives on the root so it
## survives scene changes. Usage (after --): mode=menu|settings|prologue|ch1|ch2|ch3

const OUT := "/tmp/claude-0/shots/"
var mode := "menu"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("mode="):
			mode = a.substr(5)
	Settings.data["volumetric_fog"] = false
	Settings.data["ssao"] = false
	Settings.data["shadows"] = 1
	Settings.data["language"] = "en" if "lang=en" in OS.get_cmdline_user_args() else Settings.data["language"]
	if not has_meta("runner"):
		var r := Node.new()
		r.set_meta("runner", true)
		r.set_script(get_script())
		get_tree().root.add_child.call_deferred(r)
		return
	_run.call_deferred()


func shot(n: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("SHOT ", n, " fps=", Engine.get_frames_per_second())


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func game() -> Node:
	return get_tree().current_scene


func _run() -> void:
	match mode:
		"menu":
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			await wait(7.0)
			await shot("menu")
		"settings":
			Settings.set_value("language", "en")
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			await wait(5.0)
			game()._on_settings()
			await wait(1.2)
			await shot("settings_game")
			var sm: SettingsMenu = game()._overlay.get_child(0)
			sm._select_tab(1)
			await wait(0.8)
			await shot("settings_video")
			Settings.set_value("language", "ru")
			await wait(0.8)
			await shot("settings_video_ru")
		"prologue":
			get_tree().change_scene_to_file("res://scenes/prologue.tscn")
			Fader.set_progress(0.0)
			await wait(4.0)
			await shot("prologue_0")
			var p := game()
			for i in 3:
				p.body.visible_ratio = 1.0
				await wait(0.3)
				if p.choices.get_child_count() > 0:
					p._choose(p.Story.PROLOGUE[p._beat]["choices"][0])
					await wait(3.0)
				var ev := InputEventAction.new()
				ev.action = "interact"
				ev.pressed = true
				p._waiting_continue = true
				p._unhandled_input(ev)
				await wait(3.5)
			await shot("prologue_3")
		"ch1", "ch2", "ch3":
			Game.chapter = int(mode.substr(2))
			Game.flags = {"promise": true, "met_doors": true}
			get_tree().change_scene_to_file("res://scenes/game.tscn")
			Fader.set_progress(0.0)
			await wait(3.0)
			await shot(mode + "_card")
			await wait(9.0)
			await shot(mode + "_start")
			var g := game()
			var pl: Player = g.player
			if mode == "ch1":
				await _ch1(g, pl)
			elif mode == "ch2":
				await _ch2(g, pl)
			else:
				await _ch3(g, pl)
	print("AUTOTEST_DONE")
	get_tree().quit()


func use(g: Node, id: String) -> void:
	# wait (up to 20 s) until the director is actually listening for this id
	var t0 := Time.get_ticks_msec()
	while not (id in g.director._awaiting) and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	var it: Interactable = g.world.cabin.interactables.get(id, g.world.props.interactables.get(id))
	it.use()
	await wait(0.3)


func put(pl: Player, pos: Vector3, yaw_deg: float, pitch_deg := 0.0) -> void:
	pl.global_position = pos
	pl.velocity = Vector3.ZERO
	pl.set_yaw_pitch(deg_to_rad(yaw_deg), deg_to_rad(pitch_deg))
	await wait(0.6)


func _ch1(g: Node, pl: Player) -> void:
	# look down at own body on the platform
	pl.set_yaw_pitch(pl._yaw, deg_to_rad(-70))
	await wait(0.8)
	await shot("ch1_body")
	await put(pl, Vector3(1.9, 0.1, 9.0), 0.0, 2.0)
	await wait(1.0)
	await shot("ch1_porch")
	await use(g, "door")
	await wait(1.0)
	await use(g, "door")
	await wait(1.5)
	await put(pl, Vector3(1.6, 0.55, 1.6), 30.0, -10.0)
	await wait(1.0)
	await use(g, "lamp")
	await wait(2.5)
	await shot("ch1_lamp")
	await use(g, "wood")
	await wait(1.0)
	await shot("ch1_holding_wood")
	await use(g, "stove")
	await wait(0.5)
	await use(g, "stove")
	await wait(4.0)
	await put(pl, Vector3(1.0, 0.55, 1.3), 10.0, -8.0)
	await shot("ch1_stove")
	await wait(6.0)
	await use(g, "radio")
	await wait(3.0)
	await put(pl, Vector3(0.6, 0.55, 0.9), 120.0, -12.0)
	await shot("ch1_dialogue")
	# skip through the dialogue quickly by picking choices
	for i in 60:
		if g.hud.choices_active:
			g.hud._pick(0)
			await wait(0.5)
		if not g.hud.dialogue.running:
			break
		await wait(1.0)
	await wait(1.0)
	await put(pl, Vector3(-1.4, 0.55, 1.0), 220.0, -18.0)
	await shot("ch1_room_west")
	await put(pl, Vector3(0.0, 0.55, 0.6), 0.0, 0.0)
	await shot("ch1_room_south")
	await put(pl, Vector3(-0.5, 0.55, 0.5), 160.0, -5.0)
	await shot("ch1_room_north")


func _ch2(g: Node, pl: Player) -> void:
	await put(pl, Vector3(-6.0, 0.1, 14.0), 160.0, 2.0)
	g.world.props.feeder_seed.visible = true
	g.world.birds.set_active(true, true)
	await wait(2.0)
	await shot("ch2_yard")
	await put(pl, Vector3(-4.2, 0.1, 8.0), 180.0, 8.0)
	await wait(1.0)
	await shot("ch2_feeder")
	await put(pl, Vector3(33.5, Layout.height(33.5, -26.0) + 0.1, -26.0), 230.0, 8.0)
	await shot("ch2_birch")
	await put(pl, Vector3(-5.0, Layout.height(-5.0, 84.0) + 0.1, 84.0), 120.0, 2.0)
	g.world.train.pass_by(1.0)
	await wait(19.0)
	await shot("ch2_train")


func _ch3(g: Node, pl: Player) -> void:
	await put(pl, Vector3(-1.2, 0.55, 0.6), 90.0, -12.0)
	await shot("ch3_inside")
	g.world.cabin.letter_node.visible = true
	await put(pl, Vector3(-1.9, 0.55, 0.4), 90.0, -45.0)
	await shot("ch3_letter_table")
	g.hud.open_reader("letter")
	await wait(8.0)
	await shot("ch3_letter")
	g.hud.close_reader()
	await put(pl, Vector3(6.0, 0.1, 16.0), 210.0, 6.0)
	await shot("ch3_night_ext")
