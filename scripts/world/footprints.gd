class_name Footprints
extends Node3D
## Felt-boot prints pressed into the snow as decals, pooled and slowly
## filled back in by falling snow.

const MAX := 160
var _pool: Array[Decal] = []
var _ages: PackedFloat32Array
var _next := 0
var _tex_l: ImageTexture
var _tex_r: ImageTexture
var _norm: ImageTexture
var fill_rate := 0.004


func _ready() -> void:
	_tex_l = _make_print(false)
	_tex_r = _make_print(true)
	_norm = _make_normal()
	_ages.resize(MAX)
	for i in MAX:
		var d := Decal.new()
		d.size = Vector3(0.16, 0.4, 0.36)
		d.cull_mask = 1
		d.normal_fade = 0.4
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		d.visible = false
		d.texture_normal = _norm
		d.albedo_mix = 0.85
		add_child(d)
		_pool.append(d)


func add(pos: Vector3, yaw: float, right: bool) -> void:
	var d := _pool[_next]
	_ages[_next] = 0.0
	_next = (_next + 1) % MAX
	d.texture_albedo = _tex_r if right else _tex_l
	d.global_position = pos
	d.rotation = Vector3(0, yaw, 0)
	d.modulate = Color(1, 1, 1, 1)
	d.visible = true


func _process(delta: float) -> void:
	for i in MAX:
		var d := _pool[i]
		if not d.visible:
			continue
		_ages[i] += delta
		var a := clampf(1.0 - _ages[i] * fill_rate, 0.0, 1.0)
		d.modulate.a = a
		if a <= 0.0:
			d.visible = false


static func _make_print(right: bool) -> ImageTexture:
	# valenok sole: rounded toe, narrow waist, round heel; slightly darker,
	# blue-shadowed compressed snow with a bright rim.
	var w := 32
	var h := 80
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h
			if right:
				u = -u
			var cx := 0.06 * sin(v * PI)
			var width := 0.0
			if v < 0.42:
				width = 0.92 * sqrt(maxf(0.0, 1.0 - pow((v - 0.24) / 0.25, 2.0)))
			elif v < 0.62:
				width = 0.62
			else:
				width = 0.78 * sqrt(maxf(0.0, 1.0 - pow((v - 0.8) / 0.19, 2.0)))
			var d := absf(u - cx) / maxf(width, 0.001)
			var inside := 1.0 - smoothstep(0.82, 1.0, d) if width > 0.0 else 0.0
			var rim := smoothstep(0.75, 0.95, d) * (1.0 - smoothstep(1.0, 1.2, d)) if width > 0.0 else 0.0
			var c := Color(0.62, 0.68, 0.8).lerp(Color(0.98, 0.99, 1.0), rim)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(inside * 0.75 + rim * 0.3, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _make_normal() -> ImageTexture:
	var w := 32
	var h := 80
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := (x + 0.5) / w * 2.0 - 1.0
			var v := (y + 0.5) / h * 2.0 - 1.0
			var n := Vector3(u * 0.5, v * 0.25, 1.0).normalized()
			img.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))
	return ImageTexture.create_from_image(img)
