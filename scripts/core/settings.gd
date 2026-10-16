extends Node
## Persistent player settings. Everything the settings menu touches lives here,
## and every system that cares listens to `changed`.

signal changed(key: String)

const PATH := "user://settings.cfg"

const QUALITY_PRESETS := {
	0: {"shadows": 0, "ssao": false, "ssil": false, "volumetric_fog": false, "glow": true, "aa": 1, "render_scale": 0.75, "draw_distance": 0},
	1: {"shadows": 1, "ssao": true, "ssil": false, "volumetric_fog": false, "glow": true, "aa": 1, "render_scale": 1.0, "draw_distance": 1},
	2: {"shadows": 2, "ssao": true, "ssil": false, "volumetric_fog": true, "glow": true, "aa": 2, "render_scale": 1.0, "draw_distance": 1},
	3: {"shadows": 3, "ssao": true, "ssil": true, "volumetric_fog": true, "glow": true, "aa": 2, "render_scale": 1.0, "draw_distance": 2},
}

## Rebindable actions, in the order they appear in the Controls tab.
const ACTIONS := [
	"move_forward", "move_back", "move_left", "move_right",
	"sprint", "crouch", "interact", "flashlight", "notebook",
]

const DEFAULT_KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"notebook": [KEY_TAB, KEY_J],
	"pause": [KEY_ESCAPE],
	"choice_1": [KEY_1],
	"choice_2": [KEY_2],
	"choice_3": [KEY_3],
}

var data := {
	"language": "ru",
	# audio, linear 0..1
	"vol_master": 0.85,
	"vol_music": 0.7,
	"vol_sfx": 0.9,
	"vol_ambience": 0.8,
	"vol_voice": 0.9,
	# controls
	"mouse_sens": 0.5,
	"invert_y": false,
	"toggle_sprint": false,
	# camera
	"fov": 78.0,
	"head_bob": 1.0,
	# display
	"window_mode": 0, # 0 windowed, 1 borderless fullscreen, 2 exclusive fullscreen
	"vsync": true,
	"max_fps": 0,
	"brightness": 1.0,
	# graphics
	"quality": 2,
	"shadows": 2,
	"ssao": true,
	"ssil": false,
	"volumetric_fog": true,
	"glow": true,
	"aa": 2, # 0 off, 1 FXAA, 2 TAA, 3 MSAA 4x
	"render_scale": 1.0,
	"draw_distance": 1,
	"film_grain": true,
	# accessibility
	"subtitle_size": 1, # 0 small, 1 medium, 2 large
	"subtitle_bg": 0.55,
	"timed_choices": true,
	"crosshair": true,
	"text_speed": 1.0,
	# key binds: action -> Array[int keycodes]
	"keys": {},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lang := OS.get_locale_language()
	data["language"] = "ru" if lang in ["ru", "uk", "be", "kk"] else "en"
	_load()
	_build_input_map()
	apply_all()


func get_value(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)


func set_value(key: String, value: Variant, save_now := true) -> void:
	if data.get(key) == value:
		return
	data[key] = value
	if key == "quality":
		_apply_preset(int(value))
	_apply_key(key)
	changed.emit(key)
	if save_now:
		save()


func _apply_preset(q: int) -> void:
	var p: Dictionary = QUALITY_PRESETS.get(q, QUALITY_PRESETS[2])
	for k in p:
		data[k] = p[k]
		_apply_key(k)
		changed.emit(k)


func apply_all() -> void:
	for k in data.keys():
		_apply_key(k)


func _apply_key(key: String) -> void:
	match key:
		"vol_master":
			_set_bus("Master", data[key])
		"vol_music":
			_set_bus("Music", data[key])
		"vol_sfx":
			_set_bus("SFX", data[key])
		"vol_ambience":
			_set_bus("Ambience", data[key])
		"vol_voice":
			_set_bus("Voice", data[key])
		"window_mode":
			_apply_window_mode()
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data["vsync"] else DisplayServer.VSYNC_DISABLED)
		"max_fps":
			Engine.max_fps = int(data["max_fps"])
		"render_scale", "aa":
			_apply_viewport_quality()
		"shadows":
			_apply_shadow_quality()
		"language":
			TranslationServer.set_locale(data["language"])


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	match int(data["window_mode"]):
		0:
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _apply_viewport_quality() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var scale := float(data["render_scale"])
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if scale < 0.99 and int(data["aa"]) == 2 else (Viewport.SCALING_3D_MODE_FSR if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR)
	vp.scaling_3d_scale = scale
	var aa := int(data["aa"])
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = aa == 2 and vp.scaling_3d_mode != Viewport.SCALING_3D_MODE_FSR2
	vp.msaa_3d = Viewport.MSAA_4X if aa == 3 else Viewport.MSAA_DISABLED


func _apply_shadow_quality() -> void:
	var q := int(data["shadows"])
	var sizes := [1024, 2048, 4096, 8192]
	var filters := [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH]
	RenderingServer.directional_shadow_atlas_set_size(sizes[q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(filters[q])
	RenderingServer.positional_soft_shadow_filter_set_quality(filters[q])
	var vp := get_viewport()
	if vp:
		vp.positional_shadow_atlas_size = [1024, 2048, 4096, 4096][q]


# --- input -----------------------------------------------------------------

func _build_input_map() -> void:
	for action in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		var keys: Array = data["keys"].get(action, DEFAULT_KEYS[action])
		for k in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(k)
			InputMap.action_add_event(action, ev)
	# mouse
	_add_mouse("interact", MOUSE_BUTTON_LEFT)
	_add_mouse("choice_next", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse("choice_prev", MOUSE_BUTTON_WHEEL_UP)
	# gamepad basics
	_add_joy_button("interact", JOY_BUTTON_A)
	_add_joy_button("pause", JOY_BUTTON_START)
	_add_joy_button("notebook", JOY_BUTTON_BACK)
	_add_joy_button("flashlight", JOY_BUTTON_Y)
	_add_joy_button("sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button("crouch", JOY_BUTTON_B)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: String, axis: JoyAxis, dir: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)


func get_action_keys(action: String) -> Array:
	return data["keys"].get(action, DEFAULT_KEYS.get(action, []))


func rebind(action: String, keycode: int) -> void:
	var keys: Array = get_action_keys(action).duplicate()
	# The new key becomes the primary binding; steal it from any other action.
	for other in ACTIONS:
		if other == action:
			continue
		var ok: Array = get_action_keys(other).duplicate()
		if keycode in ok:
			ok.erase(keycode)
			data["keys"][other] = ok
	keys.erase(keycode)
	keys.push_front(keycode)
	if keys.size() > 2:
		keys.resize(2)
	data["keys"][action] = keys
	_build_input_map()
	changed.emit("keys")
	save()


func reset_keys() -> void:
	data["keys"] = {}
	_build_input_map()
	changed.emit("keys")
	save()


static func key_name(keycode: int) -> String:
	var s := OS.get_keycode_string(keycode)
	return s if s != "" else "?"


# --- persistence -------------------------------------------------------------

func save() -> void:
	var cf := ConfigFile.new()
	for k in data:
		cf.set_value("settings", k, data[k])
	cf.save(PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in cf.get_section_keys("settings"):
		if data.has(k):
			var v: Variant = cf.get_value("settings", k)
			if typeof(v) == typeof(data[k]) or (typeof(data[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				data[k] = v
