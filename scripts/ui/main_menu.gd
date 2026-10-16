extends Node
## Main menu: the cordon at blue hour behind a typographic menu.

var world: World
var cam: Camera3D
var ui: Control
var menu_box: VBoxContainer
var _t := 0.0
var _mouse := Vector2.ZERO
var _overlay: Control
var _buttons: Array[Button] = []
var _title: Label
var _lang_labels := {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	world = World.new()
	world.preset_name = "menu"
	add_child(world)
	world.cabin.set_lamp_lit(true)
	world.cabin.set_stove_lit(true)
	world.cabin.wood_in_stove.visible = true
	world.cabin.set_door_open(false, false)
	world.props.feeder_seed.visible = true
	world.birds.shy = false
	world.birds.set_active(true, true)
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.1
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	world.follow(cam)
	_update_cam(0.0)
	_build_ui()
	Sfx.set_music_mood("menu", 4.0)
	Loc.language_changed.connect(func(_l): _refresh_lang())
	await get_tree().process_frame
	await get_tree().process_frame
	_intro()


func _process(delta: float) -> void:
	_t += delta
	_update_cam(delta)


func _update_cam(_delta: float) -> void:
	# a slow drift across the yard, with a little mouse parallax
	var vp := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	var target_mouse := (m / vp - Vector2(0.5, 0.5)) if vp.x > 0 else Vector2.ZERO
	_mouse = _mouse.lerp(target_mouse, 0.03)
	var a := 0.42 + sin(_t * 0.035) * 0.28
	var r := 16.5 + sin(_t * 0.05) * 1.0
	var pos := Vector3(sin(a) * r - 1.5, 2.5 + sin(_t * 0.07) * 0.25, cos(a) * r + 2.0)
	pos += Vector3(_mouse.x * -0.6, _mouse.y * 0.3, 0)
	cam.global_position = pos
	cam.look_at(Vector3(-3.2 + _mouse.x * 0.5, 2.6, 1.0), Vector3.UP)


# --- UI ---------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.get_theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	# readability gradient on the left
	var grad := ColorRect.new()
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsh := Shader.new()
	gsh.code = "shader_type canvas_item;\nuniform vec4 ink : source_color;\nvoid fragment() {\n\tfloat a = 1.0 - smoothstep(0.0, 0.62, UV.x);\n\tCOLOR = vec4(ink.rgb, ink.a * (0.35 + 0.65 * a) * (1.0 - smoothstep(0.4, 0.75, UV.x)));\n}"
	var gmat := ShaderMaterial.new()
	gmat.shader = gsh
	gmat.set_shader_parameter("ink", Color(UITheme.INK, 0.9))
	grad.material = gmat
	ui.add_child(grad)
	var grain := ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/grain.gdshader")
	gm.set_shader_parameter("vignette", 0.55)
	grain.material = gm
	ui.add_child(grain)

	var col := VBoxContainer.new()
	col.position = Vector2(150, 150)
	col.custom_minimum_size = Vector2(760, 0)
	col.add_theme_constant_override("separation", 0)
	ui.add_child(col)
	var tag := UITheme.label("MENU_TAGLINE", UITheme.spaced(UITheme.font_sans_bold(), 4), 19, UITheme.FROST)
	tag.uppercase = true
	tag.modulate.a = 0.75
	col.add_child(tag)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 26)
	col.add_child(title_row)
	_title = UITheme.label("GAME_TITLE", UITheme.spaced(UITheme.font_title(), 14), 150, UITheme.PAPER)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_title.add_theme_constant_override("shadow_offset_y", 4)
	title_row.add_child(_title)
	var mark := BullfinchMark.new()
	mark.ink = UITheme.PAPER
	mark.custom_minimum_size = Vector2(110, 92)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(mark)
	var sub := UITheme.label("GAME_SUBTITLE", UITheme.font_serif_italic(), 36, UITheme.FROST)
	col.add_child(sub)
	var rule_m := MarginContainer.new()
	rule_m.add_theme_constant_override("margin_top", 34)
	rule_m.add_theme_constant_override("margin_bottom", 34)
	col.add_child(rule_m)
	var rule := ColorRect.new()
	rule.color = UITheme.RED
	rule.custom_minimum_size = Vector2(120, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.name = "Rule"
	rule_m.add_child(rule)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 4)
	col.add_child(menu_box)
	if Game.has_save():
		_add_item("MENU_CONTINUE", _on_continue, Loc.t("MENU_CONTINUE_HINT") % _roman(Game.chapter))
	_add_item("MENU_NEW_GAME", _on_new_game)
	if Game.chapter_reached > 1:
		_add_item("MENU_CHAPTERS", _on_chapters)
	_add_item("MENU_SETTINGS", _on_settings)
	_add_item("MENU_CREDITS", _on_credits)
	_add_item("MENU_QUIT", _on_quit)
	# footer
	var ver := UITheme.label("MENU_VERSION", UITheme.font_mono(), 18, UITheme.MUTED)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(150, -70)
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(ver)
	var lang := HBoxContainer.new()
	lang.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lang.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lang.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lang.position = Vector2(-240, -80)
	lang.add_theme_constant_override("separation", 18)
	ui.add_child(lang)
	for code in ["ru", "en"]:
		var b := Button.new()
		b.text = code.to_upper()
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.add_theme_font_override("font", UITheme.spaced(UITheme.font_sans_bold(), 3))
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(func():
			Settings.set_value("language", code)
			Sfx.play_ui("ui_click", -8.0))
		b.mouse_entered.connect(func(): Sfx.play_ui("ui_hover", -16.0))
		lang.add_child(b)
		_lang_labels[code] = b
		if code == "ru":
			var sep := UITheme.label("·", UITheme.font_sans(), 24, UITheme.MUTED)
			lang.add_child(sep)
	_refresh_lang()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_overlay)


func _refresh_lang() -> void:
	for code in _lang_labels:
		var b: Button = _lang_labels[code]
		var active: bool = Loc.lang() == code
		b.add_theme_color_override("font_color", UITheme.PAPER if active else Color(UITheme.PAPER, 0.4))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
	for b in _buttons:
		if b.has_meta("hint_label"):
			var hl: Label = b.get_meta("hint_label")
			hl.text = Loc.t("MENU_CONTINUE_HINT") % _roman(Game.chapter)


static func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV"][clampi(n, 0, 4)]


func _add_item(key: String, cb: Callable, hint := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	menu_box.add_child(row)
	# metro-map station marker: a ring that fills on hover
	var marker := Control.new()
	marker.custom_minimum_size = Vector2(26, 26)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.set_meta("k", 0.0)
	marker.draw.connect(func():
		var k: float = marker.get_meta("k")
		marker.draw_circle(Vector2(13, 13), 9, Color(UITheme.PAPER, 0.25 + k * 0.75), false, 2.5)
		marker.draw_circle(Vector2(13, 13), 6.0 * k, UITheme.RED))
	row.add_child(marker)
	var b := Button.new()
	b.text = key
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", UITheme.font_serif())
	b.add_theme_font_size_override("font_size", 44)
	b.add_theme_color_override("font_color", Color(UITheme.PAPER, 0.82))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.focus_mode = Control.FOCUS_ALL
	row.add_child(b)
	if hint != "":
		var hl := UITheme.label(hint, UITheme.font_mono(), 20, UITheme.MUTED)
		hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.add_child(hl)
		b.set_meta("hint_label", hl)
	var hover := func(on: bool):
		var t := create_tween().set_parallel()
		t.tween_method(_set_marker.bind(marker), marker.get_meta("k"), 1.0 if on else 0.0, 0.22)
		t.tween_property(b, "position:x", 58.0 if on else 44.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if on:
			Sfx.play_ui("ui_hover", -14.0)
	b.mouse_entered.connect(hover.bind(true))
	b.mouse_exited.connect(hover.bind(false))
	b.focus_entered.connect(hover.bind(true))
	b.focus_exited.connect(hover.bind(false))
	b.pressed.connect(func():
		Sfx.play_ui("ui_click", -6.0)
		cb.call())
	_buttons.append(b)
	row.modulate.a = 0.0


func _set_marker(v: float, m: Control) -> void:
	m.set_meta("k", v)
	m.queue_redraw()


func _intro() -> void:
	await Fader.reveal(2.4)
	var t := create_tween()
	for i in menu_box.get_child_count():
		var row: Control = menu_box.get_child(i)
		row.position.x -= 30
		t.tween_property(row, "modulate:a", 1.0, 0.35)
		t.parallel().tween_property(row, "position:x", row.position.x + 30, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _buttons.size() > 0:
		_buttons[0].grab_focus()


func _set_menu_enabled(on: bool) -> void:
	for b in _buttons:
		b.disabled = not on
	create_tween().tween_property(menu_box, "modulate:a", 1.0 if on else 0.25, 0.25)


# --- actions --------------------------------------------------------------------------

func _on_continue() -> void:
	_set_menu_enabled(false)
	Sfx.set_music_mood("", 1.2)
	Game.continue_game()


func _on_new_game() -> void:
	if Game.has_save():
		var ok := await _confirm(Loc.t("MENU_NEW_CONFIRM"))
		if not ok:
			return
	_set_menu_enabled(false)
	Sfx.set_music_mood("", 1.5)
	Game.delete_save()
	Game.new_game()


func _on_chapters() -> void:
	_set_menu_enabled(false)
	var box := _modal()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	v.add_child(UITheme.label("MENU_CHAPTERS", UITheme.font_title(), 52, UITheme.PAPER))
	const Story := preload("res://scripts/data/story_data.gd")
	for n in range(1, Game.chapter_reached + 1):
		var info: Dictionary = Story.CHAPTERS[n]
		var b := Button.new()
		b.text = "%s.  %s" % [_roman(n), Loc.pick(info["title"])]
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 36)
		b.add_theme_color_override("font_hover_color", UITheme.RED)
		b.mouse_entered.connect(func(): Sfx.play_ui("ui_hover", -14.0))
		b.pressed.connect(func():
			Sfx.play_ui("ui_click", -6.0)
			Sfx.set_music_mood("", 1.2)
			Game.flags = {}
			Game.found_docs = []
			Game.start_chapter(n))
		v.add_child(b)
		var d := UITheme.label(Loc.pick(info["date"]), UITheme.font_serif_italic(), 22, UITheme.MUTED)
		d.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		v.add_child(d)
	var back := Button.new()
	back.text = "MENU_BACK"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.add_theme_font_override("font", UITheme.font_serif_italic())
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(func():
		_close_modal(box)
		_set_menu_enabled(true))
	v.add_child(back)


func _on_settings() -> void:
	_set_menu_enabled(false)
	var s := SettingsMenu.new()
	_overlay.add_child(s)
	s.closed.connect(func(): _set_menu_enabled(true))


func _on_credits() -> void:
	_set_menu_enabled(false)
	var box := _modal()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	box.add_child(v)
	v.add_child(UITheme.label("CREDITS_TITLE", UITheme.font_title(), 52, UITheme.PAPER))
	var body := UITheme.label("CREDITS_BODY", UITheme.font_serif(), 26, UITheme.FROST)
	v.add_child(body)
	var back := Button.new()
	back.text = "MENU_BACK"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.add_theme_font_override("font", UITheme.font_serif_italic())
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(func():
		_close_modal(box)
		_set_menu_enabled(true))
	v.add_child(back)


func _on_quit() -> void:
	_set_menu_enabled(false)
	await Fader.cover(0.8)
	get_tree().quit()


func _modal() -> PanelContainer:
	var p := PanelContainer.new()
	p.position = Vector2(1010, 200)
	p.custom_minimum_size = Vector2(700, 0)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UITheme.INK_2, 0.94)
	s.border_width_left = 3
	s.border_color = UITheme.RED
	s.content_margin_left = 50
	s.content_margin_right = 50
	s.content_margin_top = 40
	s.content_margin_bottom = 40
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 30
	p.add_theme_stylebox_override("panel", s)
	_overlay.add_child(p)
	p.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(p, "modulate:a", 1.0, 0.3)
	t.tween_property(p, "position:x", 960.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return p


func _close_modal(p: Control) -> void:
	Sfx.play_ui("ui_back", -8.0)
	var t := create_tween()
	t.tween_property(p, "modulate:a", 0.0, 0.2)
	t.tween_callback(p.queue_free)


func _confirm(text: String) -> bool:
	_set_menu_enabled(false)
	var box := _modal()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 24)
	box.add_child(v)
	var l := UITheme.label(text, UITheme.font_serif(), 30, UITheme.PAPER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	v.add_child(l)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 40)
	v.add_child(h)
	var result := [false]
	var done := [false]
	for i in 2:
		var b := Button.new()
		b.text = "MENU_YES" if i == 0 else "MENU_NO"
		b.add_theme_font_size_override("font_size", 34)
		b.add_theme_color_override("font_hover_color", UITheme.RED)
		b.pressed.connect(func():
			result[0] = i == 0
			done[0] = true)
		h.add_child(b)
	while not done[0]:
		await get_tree().process_frame
	_close_modal(box)
	_set_menu_enabled(true)
	return result[0]
