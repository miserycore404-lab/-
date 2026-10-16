class_name BullfinchMark
extends Control
## The game's emblem: a bullfinch reduced to a few flat shapes — a red
## breast (the only warm colour in the winter palette), black cap and tail,
## grey back, a white wing bar. Scales to its rect. Breathes gently.

var breathe := true
var ink := UITheme.INK
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if breathe:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x / 120.0, size.y / 100.0)
	var o := (size - Vector2(120, 100) * s) * 0.5
	var b := 1.0 + sin(_t * 1.6) * 0.012
	var xf := Transform2D(0.0, Vector2(s, s * b), 0.0, o + Vector2(0, (1.0 - b) * 100.0 * s))
	draw_set_transform_matrix(xf)
	# branch
	draw_line(Vector2(6, 88), Vector2(116, 80), Color(ink, 0.9), 3.0)
	draw_line(Vector2(84, 82), Vector2(102, 94), Color(ink, 0.9), 2.0)
	# tail
	draw_colored_polygon(PackedVector2Array([Vector2(18, 50), Vector2(0, 74), Vector2(10, 76), Vector2(30, 58)]), ink)
	# back (grey)
	draw_colored_polygon(_ellipse(Vector2(52, 50), Vector2(32, 22), -0.25, 24), Color(0.47, 0.5, 0.56))
	# breast (red)
	draw_colored_polygon(_ellipse(Vector2(60, 60), Vector2(28, 24), 0.15, 24), UITheme.RED)
	# wing: black with a white bar
	draw_colored_polygon(PackedVector2Array([Vector2(28, 44), Vector2(62, 46), Vector2(56, 62), Vector2(26, 58)]), ink)
	draw_colored_polygon(PackedVector2Array([Vector2(34, 47), Vector2(58, 48), Vector2(57, 52), Vector2(33, 51)]), Color(0.92, 0.92, 0.9))
	# head with black cap
	draw_colored_polygon(_ellipse(Vector2(82, 36), Vector2(16, 15), 0.0, 20), UITheme.RED)
	draw_colored_polygon(_ellipse(Vector2(82, 30), Vector2(16, 11), 0.0, 20), ink)
	# beak
	draw_colored_polygon(PackedVector2Array([Vector2(96, 34), Vector2(106, 38), Vector2(96, 42)]), ink)
	# eye
	draw_circle(Vector2(88, 34), 2.0, Color(0.95, 0.93, 0.88))
	# legs
	draw_line(Vector2(56, 82), Vector2(54, 87), ink, 2.0)
	draw_line(Vector2(66, 82), Vector2(66, 86), ink, 2.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)


static func _ellipse(c: Vector2, r: Vector2, rot: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts
