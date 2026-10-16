class_name HUD
extends CanvasLayer
## In-game overlay: center dot & prompts, thoughts, radio subtitles with
## timed replies, notebook, chapter cards, document reader, film grain.

signal choice_made(index: int)
signal reader_closed
signal card_finished

const Story := preload("res://scripts/data/story_data.gd")

var player: Player
var root: Control
var grain_rect: ColorRect
var grain_mat: ShaderMaterial

# prompt
var dot: Control
var prompt_box: HBoxContainer
var prompt_key: Label
var prompt_label: Label

# objective toast
var toast: PanelContainer
var toast_title: Label
var toast_text: Label
var _toast_tween: Tween

# subtitles
var sub_box: PanelContainer
var sub_speaker: Label
var sub_text: RichTextLabel
var _sub_tween: Tween
var _sub_generation := 0

# choices
var choice_box: VBoxContainer
var choice_timer: ColorRect
var choice_labels: Array[Label] = []
var choices_active := false
var _choice_sel := 0
var _choice_count := 0
var _choice_silence := -1
var _choice_time := 0.0
var _choice_time_max := 0.0

# notebook
var notebook: Control
var notebook_tasks: VBoxContainer
var notebook_docs: VBoxContainer
var notebook_open := false
var objectives: Array[String] = []
var done_objectives: Array[String] = []

# reader
var reader: Control
var reader_title: Label
var reader_text: RichTextLabel
var reader_page_lbl: Label
var reader_hint: Label
var reader_open := false
var _reader_doc := {}
var _reader_page := 0

# chapter card
var card: Control
var card_num: Label
var card_title: Label
var card_date: Label
var card_sub: Label
var card_line: ColorRect

var dialogue: DialogueRunner


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	_build_grain()
	_build_prompt()
	_build_toast()
	_build_subtitles()
	_build_choices()
	_build_notebook()
	_build_reader()
	_build_card()
	dialogue = DialogueRunner.new()
	dialogue.hud = self
	add_child(dialogue)
	Settings.changed.connect(_on_setting)
	_on_setting("subtitle_size")
	_on_setting("film_grain")
	_on_setting("crosshair")


func _on_setting(key: String) -> void:
	match key:
		"subtitle_size", "subtitle_bg":
			var size: int = [26, 32, 40][int(Settings.get_value("subtitle_size", 1))]
			sub_text.add_theme_font_size_override("normal_font_size", size)
			sub_text.add_theme_font_size_override("italics_font_size", size)
			for l in choice_labels:
				l.add_theme_font_size_override("font_size", size - 2)
			var sb := sub_box.get_theme_stylebox("panel") as StyleBoxFlat
			sb.bg_color = Color(UITheme.INK, float(Settings.get_value("subtitle_bg", 0.55)))
		"film_grain":
			grain_rect.visible = Settings.get_value("film_grain", true)
		"crosshair":
			dot.visible = Settings.get_value("crosshair", true)


# --- construction -------------------------------------------------------------------

func _build_grain() -> void:
	grain_rect = ColorRect.new()
	grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain_mat = ShaderMaterial.new()
	grain_mat.shader = load("res://shaders/grain.gdshader")
	grain_mat.set_shader_parameter("warmth", Color(1.0, 0.62, 0.32, 0.0))
	grain_mat.set_shader_parameter("cold", 0.0)
	grain_mat.set_shader_parameter("grain", 0.05)
	grain_mat.set_shader_parameter("vignette", 0.45)
	grain_rect.material = grain_mat
	root.add_child(grain_rect)


func _build_prompt() -> void:
	dot = Control.new()
	UITheme.place(dot, 0.5, 0.5, -4, -4, 4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.draw.connect(func():
		var focused := player != null and player.focused != null
		var r := 4.0 if focused else 2.2
		dot.draw_circle(Vector2(4, 4), r + 1.2, Color(0, 0, 0, 0.35))
		dot.draw_circle(Vector2(4, 4), r, UITheme.PAPER if not focused else Color.WHITE))
	root.add_child(dot)
	prompt_box = HBoxContainer.new()
	prompt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	prompt_box.add_theme_constant_override("separation", 12)
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(prompt_box)
	UITheme.place(prompt_box, 0.5, 0.5, -400, 40, 400, 84)
	var key_panel := PanelContainer.new()
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(UITheme.PAPER, 0.92)
	ks.set_corner_radius_all(3)
	ks.content_margin_left = 9
	ks.content_margin_right = 9
	ks.content_margin_top = 1
	ks.content_margin_bottom = 1
	key_panel.add_theme_stylebox_override("panel", ks)
	prompt_key = UITheme.label("E", UITheme.font_sans_bold(), 22, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	key_panel.add_child(prompt_key)
	prompt_box.add_child(key_panel)
	prompt_label = UITheme.label("", UITheme.spaced(UITheme.font_sans(), 2), 26, UITheme.PAPER)
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	prompt_label.add_theme_constant_override("shadow_offset_x", 0)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.add_theme_constant_override("shadow_outline_size", 6)
	prompt_box.add_child(prompt_label)
	prompt_box.modulate.a = 0.0


func _build_toast() -> void:
	toast = PanelContainer.new()
	toast.position = Vector2(56, 52)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(UITheme.PAPER, 0.95)
	ps.content_margin_left = 22
	ps.content_margin_right = 26
	ps.content_margin_top = 10
	ps.content_margin_bottom = 14
	ps.border_width_left = 5
	ps.border_color = UITheme.RED
	ps.shadow_color = Color(0, 0, 0, 0.35)
	ps.shadow_size = 10
	ps.shadow_offset = Vector2(2, 4)
	toast.add_theme_stylebox_override("panel", ps)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	toast.add_child(v)
	toast_title = UITheme.label("HUD_NEW_TASK", UITheme.spaced(UITheme.font_sans_bold(), 3), 17, UITheme.RED_DEEP)
	toast_title.uppercase = true
	v.add_child(toast_title)
	toast_text = UITheme.label("", UITheme.font_hand(), 34, UITheme.INK)
	v.add_child(toast_text)
	toast.modulate.a = 0.0
	toast.rotation = -0.012
	root.add_child(toast)


func _build_subtitles() -> void:
	sub_box = PanelContainer.new()
	sub_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(UITheme.INK, 0.55)
	ss.set_corner_radius_all(2)
	ss.content_margin_left = 28
	ss.content_margin_right = 28
	ss.content_margin_top = 12
	ss.content_margin_bottom = 16
	sub_box.add_theme_stylebox_override("panel", ss)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	sub_box.add_child(v)
	sub_speaker = UITheme.label("", UITheme.spaced(UITheme.font_sans_bold(), 3), 19, UITheme.AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	sub_speaker.uppercase = true
	v.add_child(sub_speaker)
	sub_text = RichTextLabel.new()
	sub_text.bbcode_enabled = true
	sub_text.fit_content = true
	sub_text.scroll_active = false
	sub_text.custom_minimum_size = Vector2(1040, 0)
	sub_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_text.add_theme_color_override("default_color", UITheme.PAPER)
	sub_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	sub_text.add_theme_constant_override("shadow_offset_y", 2)
	v.add_child(sub_text)
	sub_box.modulate.a = 0.0
	root.add_child(sub_box)
	UITheme.place(sub_box, 0.5, 1.0, -550, -150, 550, -110)


func _build_choices() -> void:
	choice_box = VBoxContainer.new()
	choice_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	choice_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	choice_box.add_theme_constant_override("separation", 6)
	choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(choice_box)
	UITheme.place(choice_box, 0.5, 1.0, -520, -330, 520, -300)
	for i in 4:
		var l := UITheme.label("", UITheme.font_serif_italic(), 30, UITheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("shadow_outline_size", 8)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_box.add_child(l)
		choice_labels.append(l)
	choice_timer = ColorRect.new()
	choice_timer.color = Color(UITheme.RED, 0.85)
	choice_timer.custom_minimum_size = Vector2(0, 3)
	choice_timer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	choice_box.add_child(choice_timer)
	choice_box.visible = false


func _build_notebook() -> void:
	notebook = Control.new()
	notebook.set_anchors_preset(Control.PRESET_FULL_RECT)
	notebook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notebook)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.025, 0.035, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notebook.add_child(shade)
	var page := PanelContainer.new()
	page.rotation = 0.012
	page.pivot_offset = Vector2(380, 410)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.93, 0.91, 0.85)
	ps.content_margin_left = 70
	ps.content_margin_right = 50
	ps.content_margin_top = 50
	ps.content_margin_bottom = 40
	ps.shadow_color = Color(0, 0, 0, 0.5)
	ps.shadow_size = 24
	ps.border_width_left = 3
	ps.border_color = Color(0.8, 0.45, 0.42)
	page.add_theme_stylebox_override("panel", ps)
	notebook.add_child(page)
	UITheme.place(page, 0.5, 0.5, -380, -410, 380, 410)
	# ruled lines drawn behind the text
	var lines := Control.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(func():
		for i in 22:
			lines.draw_line(Vector2(-70, 60 + i * 34), Vector2(700, 60 + i * 34), Color(0.55, 0.65, 0.8, 0.35), 1.0)
		)
	page.add_child(lines)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	page.add_child(v)
	var t := UITheme.label("HUD_NOTEBOOK_TITLE", UITheme.font_title(), 46, UITheme.INK)
	v.add_child(t)
	var ch := UITheme.label("", UITheme.spaced(UITheme.font_sans_bold(), 3), 18, UITheme.RED_DEEP)
	ch.name = "Chapter"
	ch.uppercase = true
	v.add_child(ch)
	var h1 := UITheme.label("HUD_NOTEBOOK_TASKS", UITheme.spaced(UITheme.font_sans_bold(), 3), 18, Color(0.35, 0.35, 0.38))
	h1.uppercase = true
	v.add_child(h1)
	notebook_tasks = VBoxContainer.new()
	notebook_tasks.add_theme_constant_override("separation", 2)
	v.add_child(notebook_tasks)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 18)
	v.add_child(sp)
	var h2 := UITheme.label("HUD_NOTEBOOK_FOUND", UITheme.spaced(UITheme.font_sans_bold(), 3), 18, Color(0.35, 0.35, 0.38))
	h2.uppercase = true
	v.add_child(h2)
	notebook_docs = VBoxContainer.new()
	v.add_child(notebook_docs)
	notebook.visible = false


func _build_reader() -> void:
	reader = Control.new()
	reader.set_anchors_preset(Control.PRESET_FULL_RECT)
	reader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reader)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.025, 0.035, 0.72)
	reader.add_child(shade)
	var page := PanelContainer.new()
	page.name = "Page"
	page.pivot_offset = Vector2(450, 420)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.9, 0.87, 0.79)
	ps.content_margin_left = 80
	ps.content_margin_right = 80
	ps.content_margin_top = 60
	ps.content_margin_bottom = 50
	ps.shadow_color = Color(0, 0, 0, 0.6)
	ps.shadow_size = 30
	page.add_theme_stylebox_override("panel", ps)
	reader.add_child(page)
	UITheme.place(page, 0.5, 0.5, -450, -440, 450, 420)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	page.add_child(v)
	reader_title = UITheme.label("", UITheme.spaced(UITheme.font_sans_bold(), 2), 20, UITheme.RED_DEEP)
	reader_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader_title.uppercase = true
	v.add_child(reader_title)
	reader_text = RichTextLabel.new()
	reader_text.bbcode_enabled = true
	reader_text.fit_content = true
	reader_text.scroll_active = false
	reader_text.custom_minimum_size = Vector2(740, 560)
	reader_text.add_theme_color_override("default_color", Color(0.12, 0.13, 0.2))
	v.add_child(reader_text)
	var foot := HBoxContainer.new()
	v.add_child(foot)
	reader_page_lbl = UITheme.label("", UITheme.font_mono(), 18, Color(0.4, 0.38, 0.35))
	reader_page_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(reader_page_lbl)
	reader_hint = UITheme.label("", UITheme.spaced(UITheme.font_sans(), 2), 18, Color(0.4, 0.38, 0.35))
	foot.add_child(reader_hint)
	reader.visible = false


func _build_card() -> void:
	card = Control.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.INK
	card.add_child(bg)
	var snow := SnowOverlay.new()
	snow.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(snow)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	UITheme.place(v, 0.5, 0.5, -700, -250, 700, 250)
	card_num = UITheme.label("", UITheme.spaced(UITheme.font_sans_bold(), 8), 22, UITheme.RED, HORIZONTAL_ALIGNMENT_CENTER)
	card_num.uppercase = true
	v.add_child(card_num)
	card_title = UITheme.label("", UITheme.font_title(), 104, UITheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(card_title)
	card_line = ColorRect.new()
	card_line.color = UITheme.RED
	card_line.custom_minimum_size = Vector2(0, 2)
	card_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(card_line)
	card_date = UITheme.label("", UITheme.font_serif_italic(), 34, UITheme.FROST, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(card_date)
	card_sub = UITheme.label("", UITheme.font_mono(), 22, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(card_sub)
	card.visible = false


# --- prompt ----------------------------------------------------------------------

func set_focus(it: Interactable) -> void:
	dot.queue_redraw()
	if it == null or reader_open or choices_active:
		create_tween().tween_property(prompt_box, "modulate:a", 0.0, 0.15)
		return
	prompt_label.text = it.get_prompt().to_upper()
	var keys := Settings.get_action_keys("interact")
	prompt_key.text = Settings.key_name(int(keys[0])) if keys.size() > 0 else "E"
	create_tween().tween_property(prompt_box, "modulate:a", 1.0, 0.15)


# --- objectives -------------------------------------------------------------------

func add_objective(id: String) -> void:
	if id in objectives:
		return
	objectives.append(id)
	toast_text.text = Loc.pick(Story.OBJECTIVES.get(id, [id, id]))
	if _toast_tween:
		_toast_tween.kill()
	toast.position.x = 20
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.5)
	_toast_tween.parallel().tween_property(toast, "position:x", 56.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(6.0)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 1.2)
	Sfx.play("page", -10.0)


func complete_objective(id: String) -> void:
	if id in objectives:
		objectives.erase(id)
		done_objectives.append(id)


# --- thoughts & subtitles ---------------------------------------------------------

func show_line(speaker: String, text: String, duration: float) -> void:
	_sub_generation += 1
	var gen := _sub_generation
	var names: Array = Story.SPEAKERS.get(speaker, ["", ""])
	sub_speaker.text = Loc.pick(names)
	sub_speaker.visible = sub_speaker.text != ""
	var col: Color = {"z": UITheme.AMBER, "a": UITheme.FROST, "g": Color(0.95, 0.66, 0.66), "r": UITheme.MUTED}.get(speaker, UITheme.PAPER)
	sub_speaker.add_theme_color_override("font_color", col)
	if speaker == "t":
		sub_text.text = "[center][i]%s[/i][/center]" % text
	else:
		sub_text.text = "[center]%s[/center]" % text
	sub_text.visible_ratio = 0.0
	if _sub_tween:
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(sub_box, "modulate:a", 1.0, 0.25)
	var reveal := text.length() / (55.0 * float(Settings.get_value("text_speed", 1.0)))
	_sub_tween.parallel().tween_property(sub_text, "visible_ratio", 1.0, reveal)
	_sub_tween.tween_interval(maxf(duration - reveal, 0.5))
	_sub_tween.tween_callback(func():
		if gen == _sub_generation:
			hide_line())


func hide_line() -> void:
	create_tween().tween_property(sub_box, "modulate:a", 0.0, 0.4)


static func line_duration(text: String) -> float:
	var words := text.split(" ").size()
	return (1.6 + words * 0.34) / float(Settings.get_value("text_speed", 1.0))


func thought(text: String) -> void:
	show_line("t", text, line_duration(text) + 0.6)


# --- choices -------------------------------------------------------------------------

func show_choices(options: Array, silence_index: int, timed: bool) -> void:
	choices_active = true
	_choice_count = options.size()
	_choice_silence = silence_index
	_choice_sel = 0
	for i in choice_labels.size():
		var l := choice_labels[i]
		l.visible = i < options.size()
		if i < options.size():
			l.set_meta("text", options[i])
	_refresh_choices()
	choice_box.visible = true
	choice_box.modulate.a = 0.0
	create_tween().tween_property(choice_box, "modulate:a", 1.0, 0.3)
	_choice_time_max = 10.0 if timed else 0.0
	_choice_time = _choice_time_max
	choice_timer.visible = timed
	set_focus(null)
	Sfx.play("radio_click", -14.0, 1.3)


func _refresh_choices() -> void:
	for i in _choice_count:
		var l := choice_labels[i]
		var sel := i == _choice_sel
		var txt: String = l.get_meta("text")
		l.text = ("%d.  %s" % [i + 1, txt]) if not sel else ("—  %s  —" % txt)
		l.add_theme_color_override("font_color", Color.WHITE if sel else Color(UITheme.PAPER, 0.62))
		l.add_theme_font_override("font", UITheme.font_serif_italic() if i == _choice_silence else UITheme.font_serif())


func _pick(i: int) -> void:
	if not choices_active:
		return
	choices_active = false
	Sfx.play("radio_squelch", -12.0)
	var t := create_tween()
	t.tween_property(choice_box, "modulate:a", 0.0, 0.25)
	t.tween_callback(func(): choice_box.visible = false)
	choice_made.emit(i)


func _process(delta: float) -> void:
	if choices_active and _choice_time_max > 0.0:
		_choice_time -= delta
		var w := 600.0 * clampf(_choice_time / _choice_time_max, 0.0, 1.0)
		choice_timer.custom_minimum_size.x = w
		if _choice_time <= 0.0:
			_pick(_choice_silence if _choice_silence >= 0 else 0)
	if player and player.focused and not choices_active and not reader_open:
		var p := player.focused.get_prompt().to_upper()
		if p != prompt_label.text:
			prompt_label.text = p
	if player:
		var warm: Color = grain_mat.get_shader_parameter("warmth")
		if warm.a > 0.0:
			warm.a = maxf(0.0, warm.a - delta * 0.12)
			grain_mat.set_shader_parameter("warmth", warm)


func warmth_flash(amount := 0.22) -> void:
	grain_mat.set_shader_parameter("warmth", Color(1.0, 0.62, 0.32, amount))


func set_cold(amount: float) -> void:
	grain_mat.set_shader_parameter("cold", amount)


func _input(event: InputEvent) -> void:
	if reader_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right"):
			_reader_next()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			close_reader()
			get_viewport().set_input_as_handled()
		return
	if choices_active:
		for i in 3:
			if event.is_action_pressed("choice_%d" % (i + 1)) and i < _choice_count:
				_choice_sel = i
				_pick(i)
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("choice_next") or event.is_action_pressed("move_back") and event is InputEventJoypadMotion:
			_choice_sel = (_choice_sel + 1) % _choice_count
			_refresh_choices()
			Sfx.play_ui("ui_hover", -14.0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("choice_prev"):
			_choice_sel = (_choice_sel - 1 + _choice_count) % _choice_count
			_refresh_choices()
			Sfx.play_ui("ui_hover", -14.0)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			_pick(_choice_sel)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("notebook") and not card.visible:
		toggle_notebook()
		get_viewport().set_input_as_handled()


# --- notebook ---------------------------------------------------------------------

func toggle_notebook() -> void:
	notebook_open = not notebook_open
	if notebook_open:
		_fill_notebook()
		notebook.visible = true
		notebook.modulate.a = 0.0
		create_tween().tween_property(notebook, "modulate:a", 1.0, 0.25)
		Sfx.play("page", -6.0)
	else:
		var t := create_tween()
		t.tween_property(notebook, "modulate:a", 0.0, 0.2)
		t.tween_callback(func(): notebook.visible = false)
		Sfx.play("page", -8.0, 0.9)


func _fill_notebook() -> void:
	var ch: Label = notebook.find_child("Chapter", true, false)
	var info: Dictionary = Story.CHAPTERS.get(Game.chapter, {})
	if info:
		ch.text = "%s · %s" % [Loc.pick(info["num"]), Loc.pick(info["title"])]
	for c in notebook_tasks.get_children():
		c.queue_free()
	for c in notebook_docs.get_children():
		c.queue_free()
	for id in done_objectives:
		var l := UITheme.label("— " + Loc.pick(Story.OBJECTIVES.get(id, [id, id])), UITheme.font_hand(), 30, Color(0.45, 0.45, 0.5))
		l.modulate.a = 0.7
		notebook_tasks.add_child(l)
	for id in objectives:
		var l := UITheme.label("• " + Loc.pick(Story.OBJECTIVES.get(id, [id, id])), UITheme.font_hand(), 34, UITheme.INK)
		notebook_tasks.add_child(l)
	if objectives.is_empty() and done_objectives.is_empty():
		notebook_tasks.add_child(UITheme.label(Loc.t("HUD_NOTEBOOK_EMPTY"), UITheme.font_hand(), 30, Color(0.4, 0.4, 0.45)))
	for id in Game.found_docs:
		var doc: Dictionary = Story.DOCS.get(id, {})
		if doc.is_empty():
			continue
		var t := Loc.pick(doc["title"])
		if t == "":
			t = Loc.pick(["Письмо Кости", "Kostya's letter"])
		notebook_docs.add_child(UITheme.label("✎ " + t, UITheme.font_serif_italic(), 24, Color(0.2, 0.22, 0.32)))
	if Game.found_docs.is_empty():
		notebook_docs.add_child(UITheme.label(Loc.t("HUD_NOTEBOOK_EMPTY"), UITheme.font_hand(), 30, Color(0.4, 0.4, 0.45)))


# --- reader -------------------------------------------------------------------------

func open_reader(doc_id: String) -> void:
	_reader_doc = Story.DOCS[doc_id]
	_reader_page = 0
	reader_open = true
	if player:
		player.controls_enabled = false
		player.look_enabled = false
	reader.visible = true
	reader.modulate.a = 0.0
	var page: Control = reader.get_node("Page")
	page.rotation = randf_range(-0.02, 0.02)
	create_tween().tween_property(reader, "modulate:a", 1.0, 0.35)
	reader_title.text = Loc.pick(_reader_doc["title"])
	reader_title.visible = reader_title.text != ""
	var style: String = _reader_doc["style"]
	var font: Font = UITheme.font_hand() if style != "typed" else UITheme.font_mono()
	var size := 38 if style == "hand" else (40 if style == "letter" else 24)
	reader_text.add_theme_font_override("normal_font", font)
	reader_text.add_theme_font_size_override("normal_font_size", size)
	reader_text.add_theme_color_override("default_color", Color(0.1, 0.12, 0.26) if style != "typed" else Color(0.15, 0.14, 0.13))
	_show_page()
	set_focus(null)
	Sfx.play("page", -4.0)


func _show_page() -> void:
	var pages: Array = _reader_doc["pages"]
	reader_text.text = Loc.pick(pages[_reader_page])
	reader_text.visible_ratio = 0.0
	var speed := 70.0 if _reader_doc["style"] != "letter" else 26.0
	create_tween().tween_property(reader_text, "visible_ratio", 1.0, reader_text.text.length() / (speed * float(Settings.get_value("text_speed", 1.0))))
	reader_page_lbl.text = "%d / %d" % [_reader_page + 1, pages.size()] if pages.size() > 1 else ""
	reader_hint.text = Loc.t("READER_NEXT") if _reader_page < pages.size() - 1 else Loc.t("READER_CLOSE")


func _reader_next() -> void:
	if reader_text.visible_ratio < 0.99:
		reader_text.visible_ratio = 1.0
		return
	var pages: Array = _reader_doc["pages"]
	if _reader_page < pages.size() - 1:
		_reader_page += 1
		Sfx.play("page", -5.0, randf_range(0.9, 1.1))
		_show_page()
	else:
		close_reader()


func close_reader() -> void:
	if not reader_open:
		return
	reader_open = false
	var t := create_tween()
	t.tween_property(reader, "modulate:a", 0.0, 0.3)
	t.tween_callback(func(): reader.visible = false)
	if player:
		player.controls_enabled = true
		player.look_enabled = true
	Sfx.play("page", -8.0, 0.85)
	reader_closed.emit()


# --- chapter card --------------------------------------------------------------------

func show_card(info: Dictionary, hold := 4.5) -> void:
	card_num.text = Loc.pick(info["num"])
	card_num.visible = card_num.text != ""
	card_title.text = Loc.pick(info["title"])
	card_date.text = Loc.pick(info["date"])
	card_sub.text = Loc.pick(info["sub"])
	card.visible = true
	card.modulate.a = 1.0
	for l in [card_num, card_title, card_date, card_sub]:
		l.modulate.a = 0.0
	card_line.custom_minimum_size.x = 0
	var t := create_tween()
	t.tween_property(card_num, "modulate:a", 1.0, 0.8)
	t.tween_property(card_title, "modulate:a", 1.0, 1.2)
	t.parallel().tween_property(card_line, "custom_minimum_size:x", 280.0, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(card_date, "modulate:a", 1.0, 0.8)
	t.tween_callback(func(): Sfx.play("typewriter", -10.0))
	t.tween_property(card_sub, "modulate:a", 1.0, 0.6)
	t.tween_interval(hold)
	t.tween_property(card, "modulate:a", 0.0, 1.8)
	t.tween_callback(func():
		card.visible = false
		card_finished.emit())
