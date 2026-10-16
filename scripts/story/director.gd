class_name Director
extends Node
## Runs the chapters. Each chapter is a linear coroutine that waits on the
## player's actions; anything the script isn't waiting for falls through to
## a default handler (thoughts, doors, reading, the coffee glass).

signal interacted(id: String)
signal drank
signal chapter_done

const Story := preload("res://scripts/data/story_data.gd")

var world: World
var player: Player
var hud: HUD
var cabin: Cabin
var props: Props

var _awaiting: Array = []
var _door_locked := false
var _calling := false
var _seen_thoughts := {}
var _wood_held: Node3D
var _kettle_boiled := false
var _kettle_sound: AudioStreamPlayer3D
var _ending := false


func _ready() -> void:
	add_to_group("interact_listeners")


func start(chapter: int) -> void:
	cabin = world.cabin
	props = world.props
	match chapter:
		1:
			_chapter_1()
		2:
			_chapter_2()
		3:
			_chapter_3()


# --- helpers ----------------------------------------------------------------------

func on_interact(id: String, it: Interactable) -> void:
	if id in _awaiting:
		interacted.emit(id)
		return
	_default_interact(id, it)


func wait_for(ids: Array) -> String:
	_awaiting = ids
	var got: String = ""
	while true:
		got = await interacted
		if got in ids:
			break
	_awaiting = []
	return got


func wait_near(p: Vector3, radius: float) -> void:
	while Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length() > radius:
		await get_tree().process_frame


func wait_inside(inside := true) -> void:
	while cabin.contains_point(player.camera.global_position) != inside:
		await get_tree().process_frame


func _emit_when_near(p: Vector3, radius: float, id: String) -> void:
	await wait_near(p, radius)
	interacted.emit(id)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func think(key: String) -> void:
	var t := _thought_text(key)
	if t != "":
		hud.thought(t)


func think_wait(key: String) -> void:
	var t := _thought_text(key)
	if t == "":
		return
	hud.thought(t)
	await wait(HUD.line_duration(t) + 0.5)


func _thought_text(key: String) -> String:
	var ck := "%s@%d" % [key, Game.chapter]
	if Story.THOUGHTS.has(ck):
		return Loc.pick(Story.THOUGHTS[ck])
	if Story.THOUGHTS.has(key):
		return Loc.pick(Story.THOUGHTS[key])
	return ""


func objective(id: String) -> void:
	hud.add_objective(id)


func done(id: String) -> void:
	hud.complete_objective(id)


func prompt(id: String, ru: String, en: String) -> void:
	var it: Interactable = cabin.interactables.get(id, props.interactables.get(id))
	if it:
		it.prompt = [ru, en]


## The base station rings until answered (or the portable crackles at once).
func radio_call(dialog_id: String, portable := false) -> void:
	if not portable:
		_calling = true
		prompt("radio", "Ответить", "Answer")
		objective("answer_radio")
		var answered := false
		var blink := func():
			var on := false
			while _calling:
				on = not on
				cabin.set_radio_lamp(on)
				if on:
					Sfx.play_3d("radio_squelch", cabin.radio_lamp.global_position, -6.0, randf_range(0.9, 1.1), "SFX", 25.0)
				await get_tree().create_timer(0.6, false).timeout
			cabin.set_radio_lamp(false)
		blink.call()
		await wait_for(["radio"])
		_calling = false
		done("answer_radio")
		prompt("radio", "Рация", "Radio set")
		Sfx.play("pickup", -6.0)
		player.reach_toward(cabin.radio_lamp.global_position)
	else:
		Sfx.play("radio_squelch", -4.0, 1.0, "Voice")
		await wait(0.8)
	await hud.dialogue.play(dialog_id)


func _default_interact(id: String, it: Interactable) -> void:
	match id:
		"door":
			if _door_locked:
				think("door_stuck")
				return
			cabin.set_door_open(not cabin.door_open)
			return
		"logbook", "station_log":
			if Game.add_doc(id):
				pass
			hud.open_reader(id)
			return
		"cup":
			if player.held == null and cabin.cup.get_node("Liquid").visible:
				_pick_cup()
			else:
				think("table")
			return
		"table":
			if player.held_id == "cup":
				_put_cup_down()
				return
		"radio":
			think("radio_idle")
			return
		"receiver":
			think("receiver_idle")
			return
		"bed":
			think("bed_early")
			return
		"stove":
			think("stove_warm" if cabin.stove_lit else "stove_cold")
			return
		"kettle":
			think("kettle_cold" if not cabin.stove_lit else "kettle_on")
			return
		"wood":
			think("wood_taken")
			return
		"feeder":
			think("feeder_filled" if props.feeder_seed.visible else "feeder")
			return
	think(id)


func _pick_cup() -> void:
	player.hold(cabin.cup, "cup")
	cabin.interactables["cup"].enabled = false
	prompt("table", "Поставить стакан", "Put the glass down")


func _put_cup_down() -> void:
	var th := Cabin.FLOOR_Y + 0.76
	player.release(cabin, Transform3D(Basis(), Vector3(-2.3, th, 0.12)))
	cabin.interactables["cup"].enabled = true
	cabin.interactables["cup"].position = Vector3(-2.3, th + 0.07, 0.12)
	prompt("table", "Стол", "Table")
	Sfx.play("pickup", -8.0, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and player and player.controls_enabled and player.held_id == "cup" and player.focused == null:
		if player.body.drink <= 0.01:
			player.play_drink()
			get_tree().create_timer(1.6, false).timeout.connect(func():
				hud.warmth_flash(0.25)
				drank.emit())
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if player and not _ending:
		var d := Vector2(player.global_position.x, player.global_position.z).length()
		if d > Layout.PLAY_RADIUS - 6.0 and not _seen_thoughts.has("boundary"):
			_seen_thoughts["boundary"] = true
			think("boundary")
		elif d < Layout.PLAY_RADIUS - 20.0:
			_seen_thoughts.erase("boundary")


func _place_player(pos: Vector3, yaw_deg: float, pitch_deg := 0.0) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.set_yaw_pitch(deg_to_rad(yaw_deg), deg_to_rad(pitch_deg))


func _freeze(on: bool) -> void:
	player.controls_enabled = not on
	player.look_enabled = not on


func _show_card(ch: int) -> void:
	_freeze(true)
	Fader.set_progress(0.0)
	hud.show_card(Story.CHAPTERS[ch], 3.5)
	await hud.card_finished
	_freeze(false)


func _make_wood_bundle() -> Node3D:
	var n := Node3D.new()
	var k := MeshKit.new()
	for i in 3:
		k.cyl("bark_birch", Vector3(-0.18, i * 0.07, (i - 1) * 0.06), Vector3(0.18, i * 0.07 + 0.02, (i - 1) * 0.05), 0.04, Color.WHITE, 7, true, -1.0, Color(0.8, 0.64, 0.45))
	k.build(n, "Bundle")
	return n


func _end_chapter(next: int) -> void:
	_freeze(true)
	if player.held_id == "cup":
		_put_cup_down()
	await Fader.cover(2.0)
	await wait(0.8)
	if next > Game.CHAPTER_COUNT:
		return
	Game.start_chapter(next)


# --- chapter 1: arrival --------------------------------------------------------------

func _chapter_1() -> void:
	world.apply_preset("dusk")
	Sfx.set_music_mood("evening")
	cabin.set_door_open(false, false)
	cabin.set_stove_lit(false)
	cabin.set_lamp_lit(false)
	cabin.set_cup_full(false)
	var top := Layout.RAIL_H + 1.3
	_place_player(Vector3(-17.0, top, 88.0), 245.0, -2.0)
	world.train.start_stopped(6.0)
	await _show_card(1)
	await think_wait("arrive")
	objective("reach_cordon")
	await wait_near(Vector3(1.9, 0, 6.0), 5.0)
	done("reach_cordon")
	think("nalichniki")
	objective("open_door")
	_door_locked = true
	await wait_for(["door"])
	think("door_stuck")
	Sfx.play_3d("thud", cabin.door.global_position, -2.0)
	player.add_shake(0.6)
	await wait_for(["door"])
	_door_locked = false
	player.add_shake(1.0)
	cabin.set_door_open(true)
	done("open_door")
	await wait_inside()
	think("dark_inside")
	await wait(1.5)
	objective("light_lamp")
	prompt("lamp", "Зажечь лампу", "Light the lamp")
	await wait_for(["lamp"])
	Sfx.play("match", -2.0)
	await wait(0.6)
	cabin.set_lamp_lit(true)
	cabin.set_interior_ambient(Color(0.25, 0.18, 0.13), 0.5)
	prompt("lamp", "Керосиновая лампа", "Kerosene lamp")
	done("light_lamp")
	think("lamp_lit")
	await wait(2.0)
	# the stove
	objective("light_stove")
	prompt("wood", "Взять дрова", "Take firewood")
	while true:
		var got := await wait_for(["wood", "stove"])
		if got == "stove":
			think("stove_cold")
			continue
		break
	_wood_held = _make_wood_bundle()
	cabin.add_child(_wood_held)
	player.hold(_wood_held, "wood", Vector3(0.06, -0.24, -0.4))
	think("wood_taken")
	prompt("stove", "Положить дрова в печь", "Put the wood in the stove")
	await wait_for(["stove"])
	player.release(cabin, Transform3D())
	_wood_held.queue_free()
	Sfx.play_3d("wood_drop", cabin.stove_fire.global_position, -4.0)
	cabin.wood_in_stove.visible = true
	think("wood_in")
	prompt("stove", "Разжечь", "Light it")
	await wait_for(["stove"])
	Sfx.play("match", -2.0)
	await wait(0.8)
	cabin.set_stove_lit(true)
	cabin.set_interior_ambient(Color(0.32, 0.2, 0.13), 0.6)
	hud.warmth_flash(0.18)
	prompt("stove", "Печь", "Stove")
	done("light_stove")
	think("stove_lit")
	await wait(6.0)
	await radio_call("ch1_call")
	# coffee
	objective("make_coffee")
	prompt("kettle", "Поставить чайник к огню", "Put the kettle by the fire")
	await wait_for(["kettle"])
	var t := create_tween()
	t.tween_property(cabin.kettle, "position", cabin.kettle.position + Vector3(0.45, 0.0, -0.08), 0.6).set_trans(Tween.TRANS_SINE)
	Sfx.play_3d("pickup", cabin.kettle.global_position, -6.0)
	think("kettle_on")
	prompt("kettle", "Чайник", "Kettle")
	prompt("coffee_tin", "Банка кофе", "Tin of coffee")
	_kettle_boiled = false
	get_tree().create_timer(9.0, false).timeout.connect(func():
		_kettle_boiled = true
		_kettle_sound = Sfx.make_loop_3d("kettle", cabin.kettle, -10.0, "SFX", 2.0)
		_kettle_sound.play()
		think("kettle_boiled")
		prompt("coffee_tin", "Заварить кофе", "Make the coffee"))
	while true:
		await wait_for(["coffee_tin"])
		if _kettle_boiled:
			break
		think("coffee_tin")
	if _kettle_sound:
		_kettle_sound.queue_free()
	Sfx.play("pickup", -6.0)
	cabin.set_cup_full(true)
	prompt("coffee_tin", "Банка кофе", "Tin of coffee")
	prompt("cup", "Взять стакан", "Pick up the glass")
	done("make_coffee")
	think("coffee_made")
	objective("drink_coffee")
	await drank
	done("drink_coffee")
	think("coffee_drunk")
	await wait(4.0)
	objective("write_log")
	prompt("station_log", "Записать погоду", "Write the weather")
	await wait_for(["station_log"])
	Game.add_doc("station_log")
	hud.open_reader("station_log")
	await hud.reader_closed
	prompt("station_log", "Журнал связи", "Radio log")
	done("write_log")
	think("log_written")
	await wait(5.0)
	await radio_call("ch1_evening")
	objective("sleep")
	prompt("bed", "Лечь спать", "Go to sleep")
	await wait_for(["bed"])
	done("sleep")
	await _end_chapter(2)


# --- chapter 2: the line, the feeder, the birch ----------------------------------

func _chapter_2() -> void:
	world.apply_preset("morning")
	Sfx.set_music_mood("morning")
	cabin.set_door_open(false, false)
	cabin.set_stove_lit(false)
	cabin.wood_in_stove.visible = true
	cabin.set_lamp_lit(false)
	cabin.set_cup_full(false)
	cabin.set_interior_ambient(Color(0.3, 0.3, 0.34), 0.8)
	cabin.seeds_node.visible = true
	_place_player(Vector3(-1.4, Cabin.FLOOR_Y + 0.05, -1.0), 160.0, -8.0)
	await _show_card(2)
	await wait(2.0)
	await radio_call("ch2_morning")
	objective("take_portable")
	prompt("drawer", "Взять рацию", "Take the radio")
	await wait_for(["drawer"])
	Sfx.play("pickup", -4.0)
	cabin.interactables["drawer"].enabled = false
	done("take_portable")
	think("portable")
	objective("feed_birds")
	prompt("seeds", "Взять семечки", "Take the seed")
	await wait_for(["seeds"])
	cabin.seeds_node.visible = false
	Sfx.play("pickup", -6.0)
	think("seeds")
	prompt("feeder", "Насыпать семечек", "Put out seed")
	await wait_for(["feeder"])
	Sfx.play_3d("wood_drop", props.feeder_seed.global_position, -14.0, 1.8)
	props.feeder_seed.visible = true
	world.birds.set_active(true)
	prompt("feeder", "Кормушка", "Bird feeder")
	done("feed_birds")
	think("feeder_filled_promise" if Game.get_flag("promise") else "feeder_filled")
	await wait(3.0)
	objective("check_line")
	var post := Vector3(-3.5, 0, Layout.RAIL_Z - 2.6)
	_emit_when_near(post, 7.0, "__near")
	await wait_for(["km_post", "__near"])
	done("check_line")
	world.train.pass_by(1.0 if randf() < 0.5 else -1.0)
	await wait(4.0)
	player.look_at_point(Vector3(player.global_position.x, Layout.RAIL_H + 3.0, Layout.RAIL_Z), 1.6)
	await wait(10.0)
	think("train_passed")
	await wait(6.0)
	think("line_ok")
	await wait(4.0)
	await radio_call("ch2_post", true)
	objective("find_birch")
	await wait_for(["birch"])
	done("find_birch")
	await think_wait("birch")
	await wait(1.0)
	await radio_call("ch2_birch", true)
	objective("go_home")
	await wait_inside()
	done("go_home")
	objective("sleep")
	prompt("bed", "Лечь спать", "Go to sleep")
	await wait_for(["bed"])
	done("sleep")
	await _end_chapter(3)


# --- chapter 3: the flag, the letter, the call -------------------------------------

func _chapter_3() -> void:
	world.apply_preset("night")
	Sfx.set_music_mood("night")
	cabin.set_door_open(false, false)
	cabin.wood_in_stove.visible = true
	cabin.set_stove_lit(true)
	cabin.set_lamp_lit(true)
	cabin.set_cup_full(false)
	cabin.set_interior_ambient(Color(0.32, 0.2, 0.13), 0.6)
	props.feeder_seed.visible = true
	cabin.interactables["drawer"].enabled = false
	_place_player(Vector3(-1.2, Cabin.FLOOR_Y + 0.05, 0.6), 60.0, -5.0)
	await _show_card(3)
	await wait(1.5)
	objective("turn_on_receiver")
	prompt("receiver", "Включить приёмник", "Turn on the radio")
	await wait_for(["receiver"])
	cabin.set_receiver_on(true)
	Sfx.play("radio_click", -6.0)
	Sfx.set_music_mood("", 2.0)
	done("turn_on_receiver")
	await hud.dialogue.play("ch3_broadcast")
	await wait(1.0)
	cabin.set_receiver_on(false)
	Sfx.play("radio_click", -8.0)
	prompt("receiver", "Радиоприёмник", "Radio receiver")
	await think_wait("broadcast_after")
	await wait(2.0)
	await radio_call("ch3_call")
	# the letter
	cabin.letter_node.visible = true
	cabin.interactables["letter"].enabled = true
	think("letter_out")
	objective("read_letter")
	await wait_for(["letter"])
	_freeze(true)
	Sfx.set_music_mood("letter", 2.0)
	Game.add_doc("letter")
	hud.open_reader("letter")
	await hud.reader_closed
	_freeze(false)
	done("read_letter")
	await think_wait("after_letter")
	objective("call_zoya")
	prompt("radio", "Вызвать «Берёзу»", "Call \"Birch\"")
	await wait_for(["radio"])
	done("call_zoya")
	player.reach_toward(cabin.radio_lamp.global_position)
	hud.dialogue.event.connect(_on_dialogue_event)
	await hud.dialogue.play("ch3_patch")
	hud.dialogue.event.disconnect(_on_dialogue_event)
	await wait(1.5)
	await _epilogue()


func _on_dialogue_event(n: String) -> void:
	if n == "ringing":
		for i in 2:
			Sfx.play("ring", -6.0, 1.0, "Voice")
			await wait(2.2)


func _epilogue() -> void:
	_freeze(true)
	Fader._mat.set_shader_parameter("tint", Color(0.92, 0.93, 0.96, 1.0))
	await Fader.cover(3.0)
	Sfx.set_music_mood("ending", 3.0)
	world.apply_preset("morning")
	cabin.set_lamp_lit(false)
	cabin.set_stove_lit(false)
	world.birds.shy = false
	world.birds.set_active(true, true)
	_place_player(Vector3(-2.2, 0.02, 9.0), 200.0, -6.0)
	hud.show_card(Story.EPILOGUE_CARD, 2.5)
	await wait(0.5)
	await Fader.reveal(1.5)
	await hud.card_finished
	Fader._mat.set_shader_parameter("tint", UITheme.INK)
	_freeze(false)
	objective("whistle")
	prompt("feeder", "Посвистеть", "Whistle")
	await wait_for(["feeder"])
	done("whistle")
	_freeze(true)
	player.look_at_point(props.feeder_seed.global_position + Vector3(0, 0.2, 0), 1.0)
	Sfx.play("whistle", -4.0)
	await wait(1.2)
	for i in 3:
		Sfx.play_3d("bird_%d" % i, props.feeder_seed.global_position, -6.0, randf_range(0.97, 1.03), "Ambience", 40.0)
		await wait(0.7)
	think("whistled")
	await wait(5.0)
	_ending = true
	var ending := EndScreen.new()
	hud.add_child(ending)
	await ending.play(Story.EPILOGUE)
	Game.delete_save()
	Game.to_menu()
