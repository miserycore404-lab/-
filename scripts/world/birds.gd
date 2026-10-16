class_name Birds
extends Node3D
## A small flock of bullfinches (snegiri): rose-red breasts, black caps.
## They come to the feeder once it has seed, hop and peck, and flush to the
## nearest spruce if the player comes too close.

var birds: Array[Dictionary] = []
var active := false
var shy := true
var _rng := RandomNumberGenerator.new()
var _perch_points: Array[Vector3] = []
var _feeder: Vector3
var _chirp_t := 3.0


func build() -> void:
	_rng.seed = 1977
	_feeder = Vector3(Layout.FEEDER.x, Layout.height(Layout.FEEDER.x, Layout.FEEDER.y) + 1.36, Layout.FEEDER.y)
	# perches: branches of the spruces at the clearing edge
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var r := Layout.CLEARING_R + 3.5
		var p := Vector3(cos(a) * r, 0, sin(a) * r + 2.0)
		p.y = Layout.height(p.x, p.z) + _rng.randf_range(2.5, 4.0)
		_perch_points.append(p)
	for i in 6:
		var male := i < 4
		var node := _make_bird(male)
		add_child(node)
		var perch := _perch_points[i % _perch_points.size()] + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
		node.position = perch
		birds.append({
			"node": node, "state": "perched", "from": perch, "to": perch, "t": 0.0, "dur": 1.0,
			"timer": _rng.randf_range(1.0, 5.0), "home": perch, "spot": Vector3.ZERO,
		})
	visible = false


func set_active(on: bool, instant := false) -> void:
	active = on
	visible = true
	if on and instant:
		for b in birds:
			var spot := _feeding_spot()
			b["node"].position = spot
			b["spot"] = spot
			b["state"] = "feeding"
			b["timer"] = _rng.randf_range(0.5, 2.0)


func _feeding_spot() -> Vector3:
	if _rng.randf() < 0.6:
		return _feeder + Vector3(_rng.randf_range(-0.2, 0.2), 0.0, _rng.randf_range(-0.14, 0.14))
	var p := Vector3(_feeder.x + _rng.randf_range(-1.2, 1.2), 0, _feeder.z + _rng.randf_range(-1.2, 1.2))
	p.y = Layout.height(p.x, p.z) + 0.05
	return p


func _process(delta: float) -> void:
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	var player_pos := cam.global_position if cam else Vector3(1000, 0, 0)
	var feeder_close := Vector2(player_pos.x - _feeder.x, player_pos.z - _feeder.z).length() < 3.2
	for b in birds:
		var node: Node3D = b["node"]
		b["timer"] -= delta
		match b["state"]:
			"perched":
				if active and b["timer"] <= 0.0 and not (shy and feeder_close):
					_fly(b, _feeding_spot(), "feeding")
				_idle_anim(node, delta, false)
			"flying":
				b["t"] += delta / b["dur"]
				var t: float = minf(b["t"], 1.0)
				var from: Vector3 = b["from"]
				var to: Vector3 = b["to"]
				var p := from.lerp(to, t)
				p.y += sin(t * PI) * clampf(from.distance_to(to) * 0.25, 0.3, 3.0)
				# little bounding dips like real finches
				p.y += sin(t * PI * 6.0) * 0.12
				var look := to - from
				look.y = 0
				if look.length() > 0.01:
					node.look_at(node.global_position + look.normalized() + Vector3(0, 0.0001, 0), Vector3.UP)
				node.position = p
				_flap(node, true)
				if t >= 1.0:
					b["state"] = b["next"]
					b["timer"] = _rng.randf_range(2.0, 6.0)
					_flap(node, false)
			"feeding":
				if shy and feeder_close:
					var perch: Vector3 = _perch_points[_rng.randi() % _perch_points.size()]
					_fly(b, perch + Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4)), "perched")
					b["timer"] = _rng.randf_range(6.0, 12.0)
					continue
				_idle_anim(node, delta, true)
				if b["timer"] <= 0.0:
					# hop to a new spot nearby
					var to := _feeding_spot()
					if node.position.distance_to(to) < 2.5:
						b["from"] = node.position
						b["to"] = to
						b["t"] = 0.0
						b["dur"] = 0.35
						b["state"] = "flying"
						b["next"] = "feeding"
					b["timer"] = _rng.randf_range(1.5, 5.0)
	_chirp_t -= delta
	if _chirp_t <= 0.0:
		_chirp_t = _rng.randf_range(2.5, 7.0)
		var b: Dictionary = birds[_rng.randi() % birds.size()]
		if b["state"] != "flying" and (active or _rng.randf() < 0.3):
			Sfx.play_3d("bird_%d" % (_rng.randi() % 3), b["node"].global_position, -10.0, _rng.randf_range(0.95, 1.06), "Ambience", 50.0)


func _fly(b: Dictionary, to: Vector3, next: String) -> void:
	var node: Node3D = b["node"]
	b["from"] = node.position
	b["to"] = to
	b["t"] = 0.0
	b["dur"] = clampf(node.position.distance_to(to) / 7.0, 0.4, 4.0)
	b["state"] = "flying"
	b["next"] = next


func _idle_anim(node: Node3D, delta: float, pecking: bool) -> void:
	var body: Node3D = node.get_node("Body")
	if pecking and _rng.randf() < delta * 2.5:
		var t := create_tween()
		t.tween_property(body, "rotation:x", 0.6, 0.08)
		t.tween_property(body, "rotation:x", 0.0, 0.12)
	if _rng.randf() < delta * 0.6:
		node.rotate_y(_rng.randf_range(-1.2, 1.2))


func _flap(node: Node3D, on: bool) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for w in ["WingL", "WingR"]:
		var wing: Node3D = node.get_node("Body/" + w)
		var s := 1.0 if w == "WingL" else -1.0
		wing.rotation.z = (sin(t * 38.0) * 0.9 + 0.2) * s if on else 0.0


func _make_bird(male: bool) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var k := MeshKit.new()
	var breast := Color(0.86, 0.22, 0.16) if male else Color(0.55, 0.47, 0.42)
	var back := Color(0.42, 0.45, 0.5)
	var black := Color(0.05, 0.05, 0.06)
	k.sphere("fabric", Vector3(0, 0.05, 0), Vector3(0.045, 0.045, 0.06), back, 6, 10)
	k.sphere("fabric", Vector3(0, 0.035, -0.012), Vector3(0.043, 0.04, 0.048), breast, 6, 10)
	k.sphere("fabric", Vector3(0, 0.09, -0.04), Vector3(0.032, 0.032, 0.032), black, 6, 10)
	k.sphere("fabric", Vector3(0, 0.08, -0.042), Vector3(0.028, 0.025, 0.03), breast, 5, 8)
	k.sphere("gloss", Vector3(0, 0.085, -0.072), Vector3(0.012, 0.01, 0.014), black, 4, 6)
	k.box_mm("fabric", Vector3(-0.012, 0.03, 0.05), Vector3(0.012, 0.045, 0.11), black)
	k.box_mm("fabric", Vector3(-0.03, 0.06, 0.045), Vector3(0.03, 0.068, 0.052), Color(0.95, 0.95, 0.95))
	k.cyl("plain", Vector3(-0.012, 0.01, 0), Vector3(-0.012, -0.015, 0), 0.003, black, 3)
	k.cyl("plain", Vector3(0.012, 0.01, 0), Vector3(0.012, -0.015, 0), 0.003, black, 3)
	var mi := k.build(body, "Mesh")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		wing.position = Vector3(side * 0.035, 0.065, 0.0)
		body.add_child(wing)
		var wk := MeshKit.new()
		wk.box_mm("fabric", Vector3(minf(0.0, side * 0.06), -0.004, -0.02), Vector3(maxf(0.0, side * 0.06), 0.004, 0.05), black)
		wk.box_mm("fabric", Vector3(minf(0.0, side * 0.05), -0.005, -0.005), Vector3(maxf(0.0, side * 0.05), 0.005, 0.005), Color(0.85, 0.85, 0.85))
		wk.build(wing, "W")
	root.scale = Vector3.ONE * 1.15
	return root
