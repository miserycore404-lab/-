extends Control
## Prologue: a life told as stations on the Moscow Metro Circle Line.
## Each year is a station; at the end the line breaks off the ring and runs
## out of the city, to the 101st kilometre.

const Story := preload("res://scripts/data/story_data.gd")

var map: Control
var station_lbl: Label
var body: RichTextLabel
var reply: RichTextLabel
var choices: VBoxContainer
var cont: Label
var _beat := -1
var _train_angle := -PI * 0.5
var _visited := 0
var _branch := 0.0
var _pulse := 0.0
var _waiting_continue := false
var _skip_hold := 0.0
var _skip_lbl: Label

const CENTER := Vector2(560, 540)
const RADIUS := 300.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.INK
	add_child(bg)
	var snow := SnowOverlay.new()
	snow.set_anchors_preset(Control.PRESET_FULL_RECT)
	snow.count = 140
	snow.modulate.a = 0.6
	add_child(snow)
	map = Control.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.draw.connect(_draw_map)
	add_child(map)
	var col := VBoxContainer.new()
	col.position = Vector2(1000, 230)
	col.custom_minimum_size = Vector2(800, 0)
	col.add_theme_constant_override("separation", 22)
	add_child(col)
	station_lbl = UITheme.label("", UITheme.spaced(UITheme.font_sans_bold(), 6), 24, UITheme.RED)
	station_lbl.uppercase = true
	station_lbl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(station_lbl)
	body = _rich(34, UITheme.PAPER, UITheme.font_serif())
	col.add_child(body)
	choices = VBoxContainer.new()
	choices.add_theme_constant_override("separation", 10)
	col.add_child(choices)
	reply = _rich(30, UITheme.FROST, UITheme.font_serif_italic())
	col.add_child(reply)
	cont = UITheme.label("→", UITheme.font_serif(), 44, UITheme.RED)
	cont.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cont.modulate.a = 0.0
	col.add_child(cont)
	_skip_lbl = UITheme.label("", UITheme.font_mono(), 18, UITheme.MUTED)
	_skip_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_lbl.position = Vector2(-420, -60)
	_skip_lbl.text = Loc.pick(["удерживайте Esc — пропустить", "hold Esc to skip"])
	_skip_lbl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_skip_lbl)
	Sfx.set_music_mood("menu", 3.0)
	await get_tree().process_frame
	_next()


func _rich(size: int, color: Color, font: Font) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(800, 0)
	r.add_theme_font_override("normal_font", font)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.add_theme_constant_override("line_separation", 6)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _station_angle(i: int) -> float:
	var n := Story.PROLOGUE.size() - 1
	return -PI * 0.5 + TAU * float(i) / float(n)


func _process(delta: float) -> void:
	_pulse += delta
	map.queue_redraw()
	if Input.is_action_pressed("pause"):
		_skip_hold += delta
		_skip_lbl.modulate = Color(1, 1, 1, 0.5 + _skip_hold)
		if _skip_hold > 1.2:
			_skip_hold = -100.0
			_finish()
	else:
		_skip_hold = 0.0


func _draw_map() -> void:
	var brown := UITheme.METRO_BROWN
	var n := Story.PROLOGUE.size() - 1
	# the ring: dim, with the travelled part bright
	map.draw_arc(CENTER, RADIUS, 0, TAU, 128, Color(brown, 0.22), 14.0, true)
	var travelled := _train_angle + PI * 0.5
	if travelled > 0.0:
		map.draw_arc(CENTER, RADIUS, -PI * 0.5, _train_angle, 96, brown, 14.0, true)
	# the river, a nod to the real map
	var pts := PackedVector2Array()
	for i in 40:
		var t := i / 39.0
		pts.append(CENTER + Vector2(-480 + t * 960, 150 + sin(t * 5.0) * 70 - t * 120))
	map.draw_polyline(pts, Color(0.35, 0.5, 0.7, 0.12), 26.0, true)
	# stations
	for i in n:
		var a := _station_angle(i)
		var p := CENTER + Vector2(cos(a), sin(a)) * RADIUS
		var visited := i <= _visited and _beat >= 0
		map.draw_circle(p, 16.0, UITheme.INK)
		map.draw_arc(p, 13.0, 0, TAU, 24, UITheme.PAPER if visited else Color(UITheme.PAPER, 0.25), 4.0, true)
		if i == _beat:
			var r := 18.0 + fmod(_pulse * 18.0, 22.0)
			map.draw_arc(p, r, 0, TAU, 32, Color(UITheme.RED, 1.0 - (r - 18.0) / 22.0), 2.0, true)
		if visited:
			var name: String = Loc.pick(Story.PROLOGUE[i]["station"])
			var out := Vector2(cos(a), sin(a))
			var tp := p + out * 34.0 + Vector2(-60 if out.x < -0.3 else (0 if out.x > 0.3 else -30), 8)
			map.draw_string(UITheme.font_sans_bold(), tp, name, HORIZONTAL_ALIGNMENT_LEFT, 140, 22, Color(UITheme.PAPER, 0.85))
	# the branch out of the ring to "101 km"
	if _branch > 0.0:
		var a0 := _station_angle(n - 1)
		var start := CENTER + Vector2(cos(a0), sin(a0)) * RADIUS
		var dir := Vector2(cos(a0 - 0.35), sin(a0 - 0.35))
		var end := start + dir * 420.0 * _branch
		var seg := 18.0
		var d := start.distance_to(end)
		var k := 0.0
		while k < d:
			map.draw_line(start + dir * k, start + dir * minf(k + seg * 0.6, d), UITheme.RED, 8.0, true)
			k += seg
		if _branch >= 0.99:
			map.draw_circle(end, 15.0, UITheme.RED)
			map.draw_circle(end, 7.0, UITheme.INK)
			map.draw_string(UITheme.font_sans_bold(), end + Vector2(-40, -30), Loc.pick(Story.PROLOGUE[n]["station"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UITheme.PAPER)
	# the train
	var tpos := CENTER + Vector2(cos(_train_angle), sin(_train_angle)) * RADIUS
	if _branch > 0.0:
		var a0 := _station_angle(n - 1)
		var start := CENTER + Vector2(cos(a0), sin(a0)) * RADIUS
		tpos = start + Vector2(cos(a0 - 0.35), sin(a0 - 0.35)) * 420.0 * _branch
	map.draw_circle(tpos, 8.0, Color.WHITE)
	map.draw_circle(tpos, 16.0, Color(1, 0.9, 0.6, 0.15))
	# the "M" in the middle, quietly
	map.draw_string(UITheme.font_title(), CENTER + Vector2(-34, 36), "М", HORIZONTAL_ALIGNMENT_LEFT, -1, 110, Color(UITheme.RED, 0.12))


func _next() -> void:
	_beat += 1
	var beats := Story.PROLOGUE
	if _beat >= beats.size():
		_finish()
		return
	var b: Dictionary = beats[_beat]
	# move the train
	var t := create_tween()
	if _beat < beats.size() - 1:
		var target := _station_angle(_beat)
		if _beat > 0:
			Sfx.play("train_rails", -18.0, 1.2)
		t.tween_property(self, "_train_angle", target, 1.4 if _beat > 0 else 0.01).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_visited = _beat
	else:
		Sfx.play("train_rails", -14.0, 0.9)
		t.tween_property(self, "_branch", 1.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# text
	for c in choices.get_children():
		c.queue_free()
	reply.text = ""
	cont.modulate.a = 0.0
	station_lbl.text = Loc.pick(b["station"])
	body.text = Loc.pick(b["text"])
	body.visible_ratio = 0.0
	var fade := create_tween()
	fade.tween_interval(0.5)
	fade.tween_property(body, "visible_ratio", 1.0, body.text.length() / (60.0 * float(Settings.get_value("text_speed", 1.0))))
	await fade.finished
	var opts: Array = b["choices"]
	if opts.is_empty():
		_show_continue()
		return
	for o in opts:
		var btn := Button.new()
		btn.text = "— " + Loc.pick(o[0])
		btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_override("font", UITheme.font_serif_italic())
		btn.add_theme_font_size_override("font_size", 32)
		btn.add_theme_color_override("font_color", Color(UITheme.PAPER, 0.7))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_focus_color", Color.WHITE)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(800, 0)
		btn.mouse_entered.connect(func(): Sfx.play_ui("ui_hover", -14.0))
		btn.pressed.connect(_choose.bind(o))
		btn.modulate.a = 0.0
		choices.add_child(btn)
		create_tween().tween_property(btn, "modulate:a", 1.0, 0.5)
	(choices.get_child(0) as Button).grab_focus.call_deferred()


func _choose(o: Array) -> void:
	Sfx.play_ui("ui_click", -6.0)
	if o[1] != "":
		Game.set_flag(o[1])
	for c in choices.get_children():
		var b: Button = c
		b.disabled = true
		if b.text != "— " + Loc.pick(o[0]):
			create_tween().tween_property(b, "modulate:a", 0.0, 0.4)
		else:
			b.add_theme_color_override("font_disabled_color", UITheme.PAPER)
	var resp := Loc.pick(o[2])
	if resp == "":
		_next()
		return
	reply.text = resp
	reply.visible_ratio = 0.0
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(reply, "visible_ratio", 1.0, resp.length() / (55.0 * float(Settings.get_value("text_speed", 1.0))))
	await t.finished
	_show_continue()


func _show_continue() -> void:
	_waiting_continue = true
	var t := create_tween().set_loops()
	t.tween_property(cont, "modulate:a", 1.0, 0.7)
	t.tween_property(cont, "modulate:a", 0.4, 0.7)
	cont.set_meta("tween", t)


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_continue:
		# allow clicking through the typewriter
		if (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			if body.visible_ratio < 1.0:
				body.visible_ratio = 1.0
			if reply.visible_ratio < 1.0 and reply.text != "":
				reply.visible_ratio = 1.0
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_waiting_continue = false
		var t: Tween = cont.get_meta("tween")
		if t:
			t.kill()
		cont.modulate.a = 0.0
		Sfx.play_ui("ui_click", -10.0)
		_next()
		get_viewport().set_input_as_handled()


func _finish() -> void:
	set_process_unhandled_input(false)
	Sfx.set_music_mood("", 2.0)
	Game.start_chapter(1)
