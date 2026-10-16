class_name SettingsMenu
extends Control
## Settings: a paper card sliding in over the scene. Every change applies
## live and is saved immediately. Shared by the main menu and the pause menu.

signal closed

const TABS := ["SET_TAB_GAME", "SET_TAB_VIDEO", "SET_TAB_AUDIO", "SET_TAB_CONTROLS", "SET_TAB_ACCESS"]

var _panel: PanelContainer
var _tab_buttons: Array[Button] = []
var _tab_marker: ColorRect
var _content: VBoxContainer
var _scroll: ScrollContainer
var _desc: Label
var _rows: Array = []
var _tab := 0
var _rebinding := ""
var _rebind_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.025, 0.04, 0.6)
	add_child(shade)
	_panel = PanelContainer.new()

	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(UITheme.INK_2, 0.97)
	ps.border_width_top = 3
	ps.border_color = UITheme.RED
	ps.content_margin_left = 0
	ps.content_margin_right = 0
	ps.content_margin_top = 0
	ps.content_margin_bottom = 0
	ps.shadow_color = Color(0, 0, 0, 0.6)
	ps.shadow_size = 40
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)
	UITheme.place(_panel, 0.5, 0.5, -660, -410, 660, 410)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	_panel.add_child(h)
	# left column: title + tabs
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color(0.04, 0.05, 0.07, 0.9)
	ls.content_margin_left = 44
	ls.content_margin_top = 46
	ls.content_margin_right = 20
	left.add_theme_stylebox_override("panel", ls)
	h.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	var title := UITheme.label("SET_TITLE", UITheme.font_title(), 54, UITheme.PAPER)
	lv.add_child(title)
	var mark := BullfinchMark.new()
	mark.custom_minimum_size = Vector2(56, 46)
	mark.ink = UITheme.PAPER
	lv.add_child(mark)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 26)
	lv.add_child(sp)
	var tabs_holder := Control.new()
	tabs_holder.custom_minimum_size = Vector2(260, TABS.size() * 58)
	lv.add_child(tabs_holder)
	_tab_marker = ColorRect.new()
	_tab_marker.color = UITheme.RED
	_tab_marker.size = Vector2(4, 34)
	_tab_marker.position = Vector2(-18, 10)
	tabs_holder.add_child(_tab_marker)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", UITheme.spaced(UITheme.font_sans_bold(), 3))
		b.add_theme_font_size_override("font_size", 24)
		b.position = Vector2(0, i * 58)
		b.size = Vector2(260, 54)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_select_tab.bind(i))
		b.mouse_entered.connect(func(): Sfx.play_ui("ui_hover", -16.0))
		tabs_holder.add_child(b)
		_tab_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(spacer)
	var back := Button.new()
	back.text = "MENU_BACK"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.add_theme_font_override("font", UITheme.font_serif_italic())
	back.add_theme_font_size_override("font_size", 32)
	back.pressed.connect(close)
	back.mouse_entered.connect(func(): Sfx.play_ui("ui_hover", -16.0))
	lv.add_child(back)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 36)
	lv.add_child(sp2)
	# right column: options
	var right := MarginContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("margin_left", 56)
	right.add_theme_constant_override("margin_right", 56)
	right.add_theme_constant_override("margin_top", 52)
	right.add_theme_constant_override("margin_bottom", 30)
	h.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 14)
	right.add_child(rv)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 4)
	_scroll.add_child(_content)
	var line := ColorRect.new()
	line.color = Color(UITheme.FROST, 0.15)
	line.custom_minimum_size = Vector2(0, 1)
	rv.add_child(line)
	_desc = UITheme.label("", UITheme.font_serif_italic(), 24, UITheme.MUTED)
	_desc.custom_minimum_size = Vector2(0, 64)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_desc)
	Settings.changed.connect(_on_setting_changed)
	Loc.language_changed.connect(func(_l): _select_tab(_tab, false))
	_select_tab(0, false)
	# entrance
	_panel.modulate.a = 0.0
	_panel.offset_left += 60
	_panel.offset_right += 60
	shade.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(shade, "modulate:a", 1.0, 0.3)
	t.tween_property(_panel, "modulate:a", 1.0, 0.35)
	t.tween_property(_panel, "offset_left", -660.0, 0.45)
	t.tween_property(_panel, "offset_right", 660.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tab_buttons[0].grab_focus.call_deferred()


func close() -> void:
	if _rebinding != "":
		return
	Sfx.play_ui("ui_back", -8.0)
	var t := create_tween().set_parallel()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_property(_panel, "position:x", _panel.position.x + 40, 0.25)
	await t.finished
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if _rebinding != "":
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _rebinding == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var code: int = event.physical_keycode
		if code != KEY_ESCAPE:
			Settings.rebind(_rebinding, code)
			Sfx.play_ui("ui_click", -8.0)
		_rebinding = ""
		_select_tab(_tab, false)


func _select_tab(i: int, sound := true) -> void:
	if sound and i != _tab:
		Sfx.play_ui("ui_click", -10.0)
	_tab = i
	for j in _tab_buttons.size():
		_tab_buttons[j].add_theme_color_override("font_color", UITheme.PAPER if j == i else Color(UITheme.PAPER, 0.45))
	create_tween().tween_property(_tab_marker, "position:y", i * 58 + 10.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for c in _content.get_children():
		c.queue_free()
	_rows.clear()
	match i:
		0:
			_add_selector("language", "SET_LANGUAGE", ["Русский", "English"], ["ru", "en"])
			_add_slider("fov", "SET_FOV", 60.0, 100.0, 1.0, "%d°")
			_add_slider("head_bob", "SET_HEAD_BOB", 0.0, 1.0, 0.05, "%d%%", 100.0)
			_add_slider("text_speed", "SET_TEXT_SPEED", 0.5, 2.0, 0.1, "×%.1f")
		1:
			_add_selector("window_mode", "SET_WINDOW_MODE", ["SET_WM_WINDOWED", "SET_WM_BORDERLESS", "SET_WM_FULLSCREEN"], [0, 1, 2])
			_add_toggle("vsync", "SET_VSYNC")
			_add_selector("max_fps", "SET_MAX_FPS", ["30", "60", "120", "144", "SET_FPS_UNLIMITED"], [30, 60, 120, 144, 0])
			_add_slider("brightness", "SET_BRIGHTNESS", 0.6, 1.6, 0.05, "%d%%", 100.0)
			_add_header()
			_add_selector("quality", "SET_QUALITY", ["SET_Q_LOW", "SET_Q_MEDIUM", "SET_Q_HIGH", "SET_Q_ULTRA"], [0, 1, 2, 3])
			_add_selector("shadows", "SET_SHADOWS", ["SET_Q_LOW", "SET_Q_MEDIUM", "SET_Q_HIGH", "SET_Q_ULTRA"], [0, 1, 2, 3])
			_add_selector("aa", "SET_AA", ["SET_AA_OFF", "FXAA", "TAA", "MSAA 4×"], [0, 1, 2, 3])
			_add_slider("render_scale", "SET_RENDER_SCALE", 0.5, 1.0, 0.05, "%d%%", 100.0)
			_add_selector("draw_distance", "SET_DRAW_DIST", ["SET_DD_NEAR", "SET_DD_MEDIUM", "SET_DD_FAR"], [0, 1, 2])
			_add_toggle("ssao", "SET_SSAO")
			_add_toggle("ssil", "SET_SSIL")
			_add_toggle("volumetric_fog", "SET_VOLFOG")
			_add_toggle("glow", "SET_GLOW")
			_add_toggle("film_grain", "SET_GRAIN")
		2:
			_add_slider("vol_master", "SET_VOL_MASTER", 0.0, 1.0, 0.05, "%d%%", 100.0, "SET_VOL_DESC")
			_add_slider("vol_music", "SET_VOL_MUSIC", 0.0, 1.0, 0.05, "%d%%", 100.0, "SET_VOL_DESC")
			_add_slider("vol_sfx", "SET_VOL_SFX", 0.0, 1.0, 0.05, "%d%%", 100.0, "SET_VOL_DESC")
			_add_slider("vol_ambience", "SET_VOL_AMBIENCE", 0.0, 1.0, 0.05, "%d%%", 100.0, "SET_VOL_DESC")
			_add_slider("vol_voice", "SET_VOL_VOICE", 0.0, 1.0, 0.05, "%d%%", 100.0, "SET_VOL_DESC")
		3:
			_add_slider("mouse_sens", "SET_SENS", 0.05, 1.0, 0.05, "%d%%", 100.0)
			_add_toggle("invert_y", "SET_INVERT_Y")
			_add_toggle("toggle_sprint", "SET_TOGGLE_SPRINT")
			_add_header()
			for a in Settings.ACTIONS:
				_add_keybind(a)
			var reset := Button.new()
			reset.text = "SET_RESET_KEYS"
			reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
			reset.add_theme_font_override("font", UITheme.font_serif_italic())
			reset.add_theme_font_size_override("font_size", 24)
			reset.add_theme_color_override("font_color", UITheme.RED)
			reset.pressed.connect(func():
				Settings.reset_keys()
				_select_tab(3, false))
			_content.add_child(reset)
			var note := UITheme.label("SET_CONTROLS_NOTE", UITheme.font_mono(), 18, UITheme.MUTED)
			_content.add_child(note)
		4:
			_add_selector("subtitle_size", "SET_SUB_SIZE", ["SET_SIZE_S", "SET_SIZE_M", "SET_SIZE_L"], [0, 1, 2])
			_add_slider("subtitle_bg", "SET_SUB_BG", 0.0, 1.0, 0.05, "%d%%", 100.0)
			_add_toggle("timed_choices", "SET_TIMED")
			_add_toggle("crosshair", "SET_CROSSHAIR")
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, 0.25)
	_desc.text = ""
	_scroll.scroll_vertical = 0


func _on_setting_changed(_key: String) -> void:
	for r in _rows:
		if is_instance_valid(r):
			r.refresh()


# --- row builders -------------------------------------------------------------------

func _row(label_key: String, desc_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 58)
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var l := UITheme.label(label_key, UITheme.font_serif(), 27, UITheme.PAPER)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	row.mouse_entered.connect(func():
		_desc.text = Loc.t(desc_key)
		l.add_theme_color_override("font_color", Color.WHITE))
	row.mouse_exited.connect(func(): l.add_theme_color_override("font_color", UITheme.PAPER))
	_content.add_child(row)
	return row


func _add_header() -> void:
	var line := ColorRect.new()
	line.color = Color(UITheme.FROST, 0.1)
	line.custom_minimum_size = Vector2(0, 1)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	m.add_child(line)
	_content.add_child(m)


func _add_selector(key: String, label_key: String, names: Array, values: Array) -> void:
	var row := _row(label_key, label_key + "_DESC")
	var sel := Selector.new()
	sel.setup(key, names, values)
	row.add_child(sel)
	_rows.append(sel)


func _add_toggle(key: String, label_key: String) -> void:
	var row := _row(label_key, label_key + "_DESC")
	var t := Toggle.new()
	t.key = key
	row.add_child(t)
	_rows.append(t)


func _add_slider(key: String, label_key: String, mn: float, mx: float, step: float, fmt: String, disp_mul := 1.0, desc := "") -> void:
	var row := _row(label_key, desc if desc != "" else label_key + "_DESC")
	var s := ValueSlider.new()
	s.setup(key, mn, mx, step, fmt, disp_mul)
	row.add_child(s)
	_rows.append(s)


func _add_keybind(action: String) -> void:
	var row := _row("ACT_" + action, "SET_CONTROLS_NOTE")
	var b := Button.new()
	b.custom_minimum_size = Vector2(380, 46)
	b.add_theme_font_override("font", UITheme.font_mono())
	b.add_theme_font_size_override("font_size", 22)
	var keys: Array = Settings.get_action_keys(action)
	var names := []
	for k in keys:
		names.append(Settings.key_name(int(k)))
	b.text = "  ·  ".join(names)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.FROST, 0.06)
	sb.border_width_bottom = 1
	sb.border_color = Color(UITheme.FROST, 0.25)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.border_color = UITheme.RED
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.pressed.connect(func():
		_rebinding = action
		b.text = Loc.t("SET_PRESS_KEY")
		Sfx.play_ui("ui_click", -10.0))
	row.add_child(b)


# --- widgets ---------------------------------------------------------------------------

class Selector extends HBoxContainer:
	var key := ""
	var names: Array = []
	var values: Array = []
	var _label: Label

	func setup(k: String, n: Array, v: Array) -> void:
		key = k
		names = n
		values = v
		custom_minimum_size = Vector2(380, 46)
		alignment = BoxContainer.ALIGNMENT_CENTER
		var l := _arrow("‹", -1)
		add_child(l)
		_label = UITheme.label("", UITheme.spaced(UITheme.font_sans_bold(), 2), 24, UITheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER)
		_label.custom_minimum_size = Vector2(280, 0)
		_label.uppercase = true
		add_child(_label)
		add_child(_arrow("›", 1))
		refresh()

	func _arrow(t: String, dir: int) -> Button:
		var b := Button.new()
		b.text = t
		b.add_theme_font_override("font", UITheme.font_serif())
		b.add_theme_font_size_override("font_size", 40)
		b.add_theme_color_override("font_hover_color", UITheme.RED)
		b.custom_minimum_size = Vector2(44, 46)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.pressed.connect(func(): _step(dir))
		return b

	func _step(dir: int) -> void:
		var i := values.find(Settings.get_value(key))
		i = posmod(i + dir, values.size()) if i >= 0 else 0
		Settings.set_value(key, values[i])
		Sfx.play_ui("ui_click", -10.0)
		var t := create_tween()
		_label.position.x += dir * 8
		t.tween_property(_label, "position:x", _label.position.x - dir * 8, 0.18).set_trans(Tween.TRANS_CUBIC)

	func refresh() -> void:
		var i := values.find(Settings.get_value(key))
		_label.text = str(names[i]) if i >= 0 else "—"


class Toggle extends Control:
	var key := ""
	var _k := 0.0
	var _hover := false

	func _set_hover(h: bool) -> void:
		_hover = h
		queue_redraw()

	func _ready() -> void:
		custom_minimum_size = Vector2(380, 46)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		_k = 1.0 if Settings.get_value(key) else 0.0

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			Settings.set_value(key, not Settings.get_value(key))
			Sfx.play_ui("ui_click", -10.0)

	func refresh() -> void:
		var target := 1.0 if Settings.get_value(key) else 0.0
		create_tween().tween_method(_set_k, _k, target, 0.2).set_trans(Tween.TRANS_CUBIC)

	func _set_k(v: float) -> void:
		_k = v
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var w := 64.0
		var h := 26.0
		var r := Rect2(c - Vector2(w * 0.5 + 60, h * 0.5), Vector2(w, h))
		var on_col := UITheme.RED.lerp(Color(UITheme.FROST, 0.2), 1.0 - _k)
		draw_rect(r, on_col, true)
		var kx := lerpf(r.position.x + h * 0.5, r.end.x - h * 0.5, _k)
		draw_circle(Vector2(kx, c.y), h * 0.5 - 3, UITheme.PAPER if not _hover else Color.WHITE)
		var txt := Loc.t("SET_ON") if _k > 0.5 else Loc.t("SET_OFF")
		var f := UITheme.spaced(UITheme.font_sans_bold(), 2)
		draw_string(f, Vector2(r.end.x + 22, c.y + 9), txt.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UITheme.PAPER)


class ValueSlider extends Control:
	var key := ""
	var mn := 0.0
	var mx := 1.0
	var step := 0.05
	var fmt := "%d"
	var mul := 1.0
	var _drag := false
	var _hover := false

	func _set_hover(h: bool) -> void:
		_hover = h
		queue_redraw()

	func setup(k: String, a: float, b: float, s: float, f: String, m: float) -> void:
		key = k
		mn = a
		mx = b
		step = s
		fmt = f
		mul = m
		custom_minimum_size = Vector2(380, 46)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))

	func _track() -> Rect2:
		return Rect2(Vector2(8, size.y * 0.5 - 1), Vector2(size.x - 110, 2))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			_drag = e.pressed
			if e.pressed:
				_set_from_x(e.position.x)
		elif e is InputEventMouseMotion and _drag:
			_set_from_x(e.position.x)
		elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var v := float(Settings.get_value(key)) + (step if e.button_index == MOUSE_BUTTON_WHEEL_UP else -step)
			Settings.set_value(key, clampf(snappedf(v, step), mn, mx))
			accept_event()

	func _set_from_x(x: float) -> void:
		var t := _track()
		var k := clampf((x - t.position.x) / t.size.x, 0.0, 1.0)
		var v := snappedf(lerpf(mn, mx, k), step)
		if absf(v - float(Settings.get_value(key))) > 0.0001:
			Settings.set_value(key, v)
			Sfx.play_ui("ui_hover", -20.0)

	func refresh() -> void:
		queue_redraw()

	func _draw() -> void:
		var t := _track()
		var v := float(Settings.get_value(key))
		var k := clampf((v - mn) / (mx - mn), 0.0, 1.0)
		draw_rect(t, Color(UITheme.FROST, 0.2))
		draw_rect(Rect2(t.position, Vector2(t.size.x * k, t.size.y + 1)), UITheme.RED)
		# tick marks
		for i in 11:
			var x := t.position.x + t.size.x * i / 10.0
			draw_line(Vector2(x, t.position.y + 7), Vector2(x, t.position.y + (12 if i % 5 == 0 else 9)), Color(UITheme.FROST, 0.25), 1.0)
		var kx := t.position.x + t.size.x * k
		draw_circle(Vector2(kx, t.position.y + 1), 9.0 if (_hover or _drag) else 7.0, UITheme.PAPER)
		draw_circle(Vector2(kx, t.position.y + 1), 3.0, UITheme.RED)
		var shown := v * mul
		var s := fmt % shown if not fmt.contains("%d") else fmt % int(roundf(shown))
		draw_string(UITheme.font_mono(), Vector2(size.x - 86, size.y * 0.5 + 8), s, HORIZONTAL_ALIGNMENT_RIGHT, 84, 22, UITheme.PAPER)
