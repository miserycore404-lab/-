class_name PauseMenu
extends CanvasLayer
## Pause: the world freezes under a frosted veil; the chapter and the
## current notebook entries are shown beside the options.

signal closed

const Story := preload("res://scripts/data/story_data.gd")

var hud: HUD
var _root: Control
var _box: VBoxContainer
var _prev_mouse: Input.MouseMode
var _busy := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play_ui("ui_back", -8.0)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.04, 0.06, 0.72)
	_root.add_child(shade)
	var snow := SnowOverlay.new()
	snow.set_anchors_preset(Control.PRESET_FULL_RECT)
	snow.count = 90
	snow.modulate.a = 0.5
	_root.add_child(snow)
	var col := VBoxContainer.new()
	col.position = Vector2(150, 220)
	col.add_theme_constant_override("separation", 4)
	_root.add_child(col)
	var info: Dictionary = Story.CHAPTERS.get(Game.chapter, {})
	var ch := UITheme.label("%s · %s" % [Loc.pick(info.get("num", ["", ""])), Loc.pick(info.get("date", ["", ""]))], UITheme.spaced(UITheme.font_sans_bold(), 4), 20, UITheme.RED)
	ch.uppercase = true
	ch.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(ch)
	col.add_child(UITheme.label("PAUSE_TITLE", UITheme.font_title(), 96, UITheme.PAPER))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	col.add_child(sp)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	col.add_child(_box)
	_item("PAUSE_RESUME", resume)
	_item("PAUSE_NOTEBOOK", func():
		resume()
		if hud and not hud.notebook_open:
			hud.toggle_notebook())
	_item("PAUSE_SETTINGS", _settings)
	_item("PAUSE_MAIN_MENU", _to_menu)
	# current tasks, handwritten on the right
	if hud and hud.objectives.size() > 0:
		var notes := VBoxContainer.new()
		notes.position = Vector2(1180, 300)
		notes.rotation = 0.02
		_root.add_child(notes)
		var h := UITheme.label("HUD_NOTEBOOK_TASKS", UITheme.spaced(UITheme.font_sans_bold(), 4), 18, UITheme.MUTED)
		h.uppercase = true
		notes.add_child(h)
		for id in hud.objectives:
			var l := UITheme.label("• " + Loc.pick(Story.OBJECTIVES.get(id, [id, id])), UITheme.font_hand(), 38, UITheme.PAPER)
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			notes.add_child(l)
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	(_box.get_child(0) as Button).grab_focus.call_deferred()


func _item(key: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = key
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 42)
	b.add_theme_color_override("font_color", Color(UITheme.PAPER, 0.8))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.mouse_entered.connect(func(): Sfx.play_ui("ui_hover", -14.0))
	b.focus_entered.connect(func(): create_tween().tween_property(b, "position:x", 12.0, 0.2))
	b.focus_exited.connect(func(): create_tween().tween_property(b, "position:x", 0.0, 0.2))
	b.pressed.connect(func():
		Sfx.play_ui("ui_click", -8.0)
		cb.call())
	_box.add_child(b)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _busy:
		get_viewport().set_input_as_handled()
		resume()


func resume() -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, 0.2)
	await t.finished
	closed.emit()
	queue_free()


func _settings() -> void:
	_busy = true
	_box.visible = false
	var s := SettingsMenu.new()
	_root.add_child(s)
	await s.closed
	_box.visible = true
	_busy = false
	(_box.get_child(2) as Button).grab_focus()


func _to_menu() -> void:
	_busy = true
	Game.to_menu()
