class_name Train
extends Node3D
## The suburban electric train (an ER2-style "elektrichka"): green cars,
## warm lit windows, a single headlight. It stops at 101 km, or passes by.

signal departed
signal arrived

const CAR_LEN := 19.6
const CARS := 4
const STOP_X := -21.0 # centre of the train when stopped at the platform

var cars: Array[Node3D] = []
var x := 400.0
var speed := 0.0
var dir := -1.0
var state := "idle" # idle, arriving, stopped, departing, passing
var _stop_timer := 0.0
var _rails: AudioStreamPlayer3D
var _headlight: SpotLight3D
var _y := 0.0


func build() -> void:
	_y = Layout.RAIL_H + 1.07
	var cab := _car_mesh(true)
	var mid := _car_mesh(false)
	for i in CARS:
		var holder := Node3D.new()
		holder.name = "Car%d" % i
		var mi := MeshInstance3D.new()
		mi.mesh = cab if (i == 0 or i == CARS - 1) else mid
		holder.add_child(mi)
		if i == CARS - 1:
			mi.rotation.y = PI
		add_child(holder)
		cars.append(holder)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.55)
		light.light_energy = 0.8
		light.omni_range = 7.0
		light.position = Vector3(0, 2.6, 0)
		holder.add_child(light)
	_headlight = SpotLight3D.new()
	_headlight.light_color = Color(1.0, 0.93, 0.8)
	_headlight.light_energy = 6.0
	_headlight.spot_range = 90.0
	_headlight.spot_angle = 16.0
	_headlight.shadow_enabled = false
	_headlight.rotation.y = PI * 0.5
	cars[0].add_child(_headlight)
	_headlight.position = Vector3(-CAR_LEN * 0.5 - 0.3, 2.4, 0)
	_rails = Sfx.make_loop_3d("train_rails", self, 4.0, "SFX", 18.0)
	_rails.max_distance = 260.0
	visible = false
	_place()


func _process(delta: float) -> void:
	match state:
		"idle":
			return
		"arriving":
			var dist := (x - STOP_X) * -dir
			speed = clampf(sqrt(maxf(-dist, 0.0) * 2.0 * 0.9), 0.0, 22.0)
			if dist >= -0.05:
				speed = 0.0
				x = STOP_X
				state = "stopped"
				_stop_timer = 6.0
				arrived.emit()
		"stopped":
			_stop_timer -= delta
			if _stop_timer <= 0.0:
				depart()
		"departing":
			speed = minf(speed + delta * 0.9, 24.0)
			if absf(x - STOP_X) > 520.0:
				_finish()
		"passing":
			if absf(x) > 520.0 and x * dir > 0.0:
				_finish()
	x += dir * speed * delta
	_place()
	if _rails:
		_rails.pitch_scale = clampf(0.6 + speed / 26.0, 0.6, 1.6)
		_rails.volume_db = linear_to_db(clampf(speed / 18.0, 0.02, 1.0)) + 4.0


func _place() -> void:
	for i in cars.size():
		cars[i].position = Vector3(x - dir * i * (CAR_LEN + 0.6), _y, Layout.RAIL_Z)
		cars[i].rotation.y = 0.0 if dir < 0.0 else PI
	_rails.position = Vector3(x, _y + 1.0, Layout.RAIL_Z)


## Start already standing at the platform (the player has just stepped off).
func start_stopped(wait := 4.0) -> void:
	dir = 1.0
	x = STOP_X
	speed = 0.0
	visible = true
	state = "stopped"
	_stop_timer = wait
	_rails.play()
	_place()


func depart() -> void:
	state = "departing"
	Sfx.play_3d("train_horn", cars[0].global_position, 6.0, 1.0, "SFX", 400.0)
	departed.emit()


func arrive(from_dir := -1.0) -> void:
	dir = from_dir
	x = STOP_X - dir * 480.0
	speed = 22.0
	visible = true
	state = "arriving"
	_rails.play()
	Sfx.play_3d("train_horn", Vector3(x, _y, Layout.RAIL_Z), 4.0, 1.0, "SFX", 600.0)


func pass_by(from_dir := 1.0) -> void:
	dir = from_dir
	x = -dir * 500.0
	speed = 26.0
	visible = true
	state = "passing"
	_rails.play()
	get_tree().create_timer(8.0).timeout.connect(func():
		if state == "passing":
			Sfx.play_3d("train_horn", cars[0].global_position, 6.0, 0.98, "SFX", 600.0))


func _finish() -> void:
	state = "idle"
	visible = false
	_rails.stop()


func _car_mesh(cab: bool) -> ArrayMesh:
	var k := MeshKit.new()
	var L := CAR_LEN * 0.5
	var W := 1.62
	var green := Color(0.17, 0.33, 0.22)
	var dark := Color(0.12, 0.13, 0.12)
	var roof := Color(0.45, 0.47, 0.46)
	# undercarriage & bogies
	k.box_mm("metal_rough", Vector3(-L + 0.5, 0.2, -1.2), Vector3(L - 0.5, 0.95, 1.2), dark)
	for bx in [-L + 2.8, L - 2.8]:
		k.box_mm("metal_rough", Vector3(bx - 1.3, 0.1, -1.0), Vector3(bx + 1.3, 0.75, 1.0), Color(0.1, 0.1, 0.1))
		for wx in [-0.9, 0.9]:
			for wz in [-0.76, 0.76]:
				k.cyl("metal", Vector3(bx + wx, 0.48, wz - 0.06), Vector3(bx + wx, 0.48, wz + 0.06), 0.47, Color(0.2, 0.18, 0.17), 14)
	# body
	k.box_mm("paint", Vector3(-L, 0.95, -W), Vector3(L, 3.7, W), green)
	k.box_mm("paint", Vector3(-L, 1.05, -W - 0.005), Vector3(L, 1.2, W + 0.005), Color(0.85, 0.75, 0.3))
	# roof (rounded)
	k.cyl("paint", Vector3(-L, 3.55, 0), Vector3(L, 3.55, 0), W * 1.02, roof, 16, true)
	k.box_mm("snow", Vector3(-L + 0.2, 4.25, -0.9), Vector3(L - 0.2, 4.4, 0.9), Color.WHITE)
	# lit windows along both sides
	for side in [-1.0, 1.0]:
		var zf: float = side * (W + 0.006)
		var wx := -L + 2.2
		while wx < L - 2.0:
			if absf(wx - (-L + 1.2)) > 0.1:
				k.box_mm("lit_window", Vector3(wx, 2.15, minf(zf, zf + side * 0.002) - 0.003), Vector3(wx + 1.05, 3.05, maxf(zf, zf + side * 0.002) + 0.003), Color(1.0, 0.85, 0.6))
				k.box_mm("plain", Vector3(wx + 0.49, 2.15, zf - 0.006), Vector3(wx + 0.56, 3.05, zf + 0.006), dark)
			wx += 1.45
		# sliding doors near each end, a little lighter
		for dx in [-L + 0.6, L - 1.9]:
			k.box_mm("paint", Vector3(dx, 1.0, zf - 0.01), Vector3(dx + 1.25, 3.3, zf + 0.01), Color(0.2, 0.38, 0.26))
			k.box_mm("lit_window", Vector3(dx + 0.12, 2.3, zf - 0.013), Vector3(dx + 0.55, 3.0, zf + 0.013), Color(1.0, 0.85, 0.6))
			k.box_mm("lit_window", Vector3(dx + 0.7, 2.3, zf - 0.013), Vector3(dx + 1.13, 3.0, zf + 0.013), Color(1.0, 0.85, 0.6))
	if cab:
		# cab nose at -x: yellow-red front with windscreen and headlight
		var fx := -L - 0.6
		k.box_mm("paint", Vector3(fx, 0.95, -W), Vector3(-L, 3.7, W), Color(0.85, 0.32, 0.18))
		k.box_mm("paint", Vector3(fx - 0.01, 1.3, -W + 0.1), Vector3(fx, 1.8, W - 0.1), Color(0.92, 0.75, 0.25))
		k.box_mm("plain", Vector3(fx - 0.015, 2.35, -W + 0.2), Vector3(fx, 3.2, -0.1), Color(0.05, 0.06, 0.08))
		k.box_mm("plain", Vector3(fx - 0.015, 2.35, 0.1), Vector3(fx, 3.2, W - 0.2), Color(0.05, 0.06, 0.08))
		k.sphere("emissive", Vector3(fx - 0.03, 3.45, 0), Vector3(0.05, 0.16, 0.16), Color(1, 1, 0.9), 5, 8)
		k.sphere("emissive", Vector3(fx - 0.03, 1.55, -1.1), Vector3(0.04, 0.09, 0.09), Color(1, 0.3, 0.2), 4, 6)
		k.sphere("emissive", Vector3(fx - 0.03, 1.55, 1.1), Vector3(0.04, 0.09, 0.09), Color(1, 0.3, 0.2), 4, 6)
		k.cyl("paint", Vector3(fx, 3.55, 0), Vector3(-L, 3.55, 0), W * 1.02, roof, 16, false)
	else:
		# pantograph
		var py := 4.3
		k.box_mm("metal", Vector3(-1.0, py, -0.6), Vector3(1.0, py + 0.08, 0.6), Color(0.3, 0.3, 0.3))
		k.cyl("metal", Vector3(-0.8, py + 0.08, 0), Vector3(0.2, py + 1.1, 0), 0.03, Color(0.3, 0.3, 0.3), 5)
		k.cyl("metal", Vector3(0.2, py + 1.1, 0), Vector3(-0.3, py + 1.75, 0), 0.025, Color(0.3, 0.3, 0.3), 5)
		k.box_mm("metal", Vector3(-0.4, py + 1.75, -0.8), Vector3(-0.2, py + 1.8, 0.8), Color(0.35, 0.35, 0.35))
	return k.build_mesh()
