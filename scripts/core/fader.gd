extends CanvasLayer
## Global screen transitions. `await Fader.cover()` / `await Fader.reveal()`.

signal covered

var _rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween
var busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/fade.gdshader")
	_rect.material = _mat
	add_child(_rect)
	set_progress(1.0)


func set_progress(p: float) -> void:
	_mat.set_shader_parameter("progress", p)
	_rect.visible = p > 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP if p > 0.5 else Control.MOUSE_FILTER_IGNORE


func get_progress() -> float:
	return _mat.get_shader_parameter("progress")


func cover(duration := 0.9) -> void:
	await _animate(1.0, duration)
	covered.emit()


func reveal(duration := 1.4) -> void:
	await _animate(0.0, duration)


func _animate(target: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	busy = true
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(set_progress, get_progress(), target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	busy = false


## Cover, swap scene, reveal.
func change_scene(path: String, cover_time := 0.9, reveal_time := 1.4) -> void:
	await cover(cover_time)
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await reveal(reveal_time)
