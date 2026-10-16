class_name SnowOverlay
extends Control
## Soft 2D snowfall with depth layers, drawn directly (no particles node).

var flakes: Array = []
var count := 220
var wind := 18.0
var color := Color(0.9, 0.93, 1.0)
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in count:
		flakes.append(_new_flake(true))


func _new_flake(anywhere: bool) -> Dictionary:
	var depth := randf()
	var s := get_viewport_rect().size if is_inside_tree() else Vector2(1920, 1080)
	return {
		"p": Vector2(randf() * s.x, randf() * s.y if anywhere else -10.0),
		"d": depth,
		"r": lerpf(0.8, 3.4, depth * depth),
		"v": lerpf(18.0, 70.0, depth),
		"ph": randf() * TAU,
	}


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	var s := size
	for i in flakes.size():
		var f: Dictionary = flakes[i]
		var p: Vector2 = f["p"]
		p.y += f["v"] * delta
		p.x += (wind * (0.4 + f["d"]) + sin(_t * 0.8 + f["ph"]) * 12.0) * delta
		if p.y > s.y + 10.0 or p.x > s.x + 20.0:
			f = _new_flake(false)
			p = f["p"]
			p.x = randf() * s.x - 40.0
		f["p"] = p
		flakes[i] = f
	queue_redraw()


func _draw() -> void:
	for f in flakes:
		var a: float = lerpf(0.25, 0.85, f["d"])
		draw_circle(f["p"], f["r"], Color(color, a * modulate.a))
		if f["d"] > 0.75:
			draw_circle(f["p"], f["r"] * 2.2, Color(color, 0.08))
