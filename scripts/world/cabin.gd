class_name Cabin
extends Node3D
## The forest cordon: a log izba with a Russian stove, built entirely in code.
## Local origin = ground level at the centre of the house; the door faces +Z.

const HX := 3.2        # wall centreline half-width (x)
const HZ := 2.6        # wall centreline half-depth (z)
const LR := 0.155      # log radius
const ROW_H := 0.26
const ROWS := 12
const BASE_Y := 0.32
const OVERHANG := 0.32
const FLOOR_Y := 0.5
const CEIL_Y := 2.95
const EAVE_Z := 3.4
const EAVE_Y := 3.3
const RIDGE_Y := 5.0
const ROOF_X := 3.85

const DOOR := Vector4(1.35, 2.35, 0.5, 2.45)   # x0, x1, y0, y1 on the south wall
const WIN_S := Vector4(-2.1, -0.9, 1.3, 2.3)
const WIN_E := Vector4(-0.2, 0.9, 1.3, 2.3)     # z range on the east wall
const WIN_W := Vector4(-0.55, 0.55, 1.3, 2.3)   # z range on the west wall

const C_LOG := Color(0.47, 0.33, 0.22)
const C_LOG_IN := Color(0.62, 0.45, 0.3)
const C_BOARD := Color(0.5, 0.37, 0.26)
const C_PAINT_BLUE := Color(0.22, 0.42, 0.5)
const C_PAINT_WHITE := Color(0.9, 0.9, 0.86)

var _rng := RandomNumberGenerator.new()
var _body: StaticBody3D
var ext: MeshKit
var inn: MeshKit

# Interactive pieces the story director drives
var door: AnimatableBody3D
var door_open := false
var stove_fire: Node3D
var stove_light: OmniLight3D
var stove_lit := false
var lamp_light: OmniLight3D
var lamp_flame: MeshInstance3D
var lamp_lit := false
var kettle: Node3D
var cup: Node3D
var cup_liquid: MeshInstance3D
var cup_steam: GPUParticles3D
var radio_lamp: MeshInstance3D
var radio_lamp_mat: StandardMaterial3D
var receiver_lamp_mat: StandardMaterial3D
var smoke: GPUParticles3D
var window_glows: Array[OmniLight3D] = []
var pendulum: Node3D
var letter_node: Node3D
var wood_in_stove: Node3D
var fire_sound: AudioStreamPlayer3D
var clock_sound_t := 0.0
var interactables := {}
var interior_probe: ReflectionProbe
var seeds_node: Node3D


func build() -> void:
	_rng.seed = 101
	_body = StaticBody3D.new()
	_body.name = "CabinBody"
	add_child(_body)
	ext = MeshKit.new()
	inn = MeshKit.new()
	_build_foundation()
	_build_walls()
	_build_floor_ceiling()
	_build_roof()
	_build_windows()
	_build_porch()
	_build_door()
	_build_stove()
	_build_furniture()
	_build_details()
	_build_lights()
	ext.build(self, "Exterior")
	inn.build(self, "Interior")


func _process(delta: float) -> void:
	if pendulum:
		var t := Time.get_ticks_msec() / 1000.0
		pendulum.rotation.z = sin(t * PI) * 0.22
		clock_sound_t += delta
		if clock_sound_t >= 1.0:
			clock_sound_t -= 1.0
			if is_player_inside():
				Sfx.play_3d("clock_tick", pendulum.global_position, -22.0, 1.0 if int(t) % 2 == 0 else 0.92)
	if stove_lit and stove_light:
		var t := Time.get_ticks_msec() / 1000.0
		stove_light.light_energy = 1.4 + sin(t * 9.0) * 0.16 + sin(t * 23.0) * 0.1 + sin(t * 3.1) * 0.18
	if lamp_lit and lamp_light:
		var t := Time.get_ticks_msec() / 1000.0
		lamp_light.light_energy = 1.25 + sin(t * 13.0) * 0.03 + sin(t * 5.0) * 0.04


func is_player_inside() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	return contains_point(cam.global_position)


func contains_point(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < HX - 0.1 and absf(l.z) < HZ - 0.1 and l.y > 0.0 and l.y < CEIL_Y + 0.5


# --- helpers ------------------------------------------------------------------------------

func _col_box(center: Vector3, size: Vector3, rot_x := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.RIGHT, rot_x), center)
	_body.add_child(cs)


func _log_color() -> Color:
	var v := _rng.randf_range(0.85, 1.12)
	return Color(C_LOG.r * v, C_LOG.g * v, C_LOG.b * v * _rng.randf_range(0.95, 1.05))


func _log_color_in() -> Color:
	var v := _rng.randf_range(0.88, 1.1)
	return Color(C_LOG_IN.r * v, C_LOG_IN.g * v, C_LOG_IN.b * v)


# --- structure ----------------------------------------------------------------------------

func _build_foundation() -> void:
	# stone plinth, mostly buried by drifts
	ext.box_mm("plain", Vector3(-HX - 0.2, -0.4, -HZ - 0.2), Vector3(HX + 0.2, 0.2, HZ + 0.2), Color(0.38, 0.37, 0.36))
	# snow drifts banked against the walls
	for side in 4:
		var count := 9
		for i in count:
			var t := (float(i) + 0.5) / count * 2.0 - 1.0
			var p: Vector3
			var rad: Vector3
			match side:
				0:
					p = Vector3(t * HX, 0.05, HZ + 0.35)
					rad = Vector3(0.75, 0.35 + _rng.randf() * 0.18, 0.45)
					if p.x > 0.8 and p.x < 3.0:
						continue # porch
				1:
					p = Vector3(t * HX, 0.05, -HZ - 0.38)
					rad = Vector3(0.75, 0.45 + _rng.randf() * 0.25, 0.55)
				2:
					p = Vector3(HX + 0.38, 0.05, t * HZ)
					rad = Vector3(0.5, 0.4 + _rng.randf() * 0.2, 0.7)
				_:
					p = Vector3(-HX - 0.38, 0.05, t * HZ)
					rad = Vector3(0.5, 0.45 + _rng.randf() * 0.25, 0.7)
			ext.sphere("snow", p, rad, Color.WHITE, 6, 10)


func _build_walls() -> void:
	# South (+z) and north (-z) walls: logs along X
	_wall_x(HZ, 0.0, [Vector4(DOOR.x, DOOR.y, DOOR.z, DOOR.w), WIN_S])
	_wall_x(-HZ, 0.0, [])
	# East (+x) and west (-x): logs along Z, offset half a row (corner notching)
	_wall_z(HX, ROW_H * 0.5, [WIN_E])
	_wall_z(-HX, ROW_H * 0.5, [WIN_W])


func _cut(segs: Array, a: float, b: float) -> Array:
	var out := []
	for s in segs:
		if b <= s.x or a >= s.y:
			out.append(s)
			continue
		if a > s.x:
			out.append(Vector2(s.x, a))
		if b < s.y:
			out.append(Vector2(b, s.y))
	return out


func _wall_x(z: float, off: float, openings: Array) -> void:
	for row in ROWS:
		var y := BASE_Y + row * ROW_H + off
		var segs := [Vector2(-HX - OVERHANG, HX + OVERHANG)]
		for o in openings:
			if y + LR * 0.6 > o.z and y - LR * 0.6 < o.w:
				segs = _cut(segs, o.x, o.y)
		for s in segs:
			if s.y - s.x < 0.05:
				continue
			var r := LR * _rng.randf_range(0.95, 1.05)
			var a := Vector3(s.x, y, z)
			var b := Vector3(s.y, y, z)
			ext.cyl("wood_ext", a, b, r, _log_color(), 12, true, -1.0, Color(0.62, 0.48, 0.34))
			# interior face: a lighter, cleaner half-log skin
			var zi := z - signf(z) * 0.012
			inn.cyl("wood", Vector3(maxf(s.x, -HX + LR), y, zi), Vector3(minf(s.y, HX - LR), y, zi), r, _log_color_in(), 12, false)
			_col_box(Vector3((s.x + s.y) * 0.5, y, z), Vector3(s.y - s.x, ROW_H + 0.01, LR * 2.0))


func _wall_z(x: float, off: float, openings: Array) -> void:
	for row in ROWS:
		var y := BASE_Y + row * ROW_H + off
		var segs := [Vector2(-HZ - OVERHANG, HZ + OVERHANG)]
		for o in openings:
			if y + LR * 0.6 > o.z and y - LR * 0.6 < o.w:
				segs = _cut(segs, o.x, o.y)
		for s in segs:
			if s.y - s.x < 0.05:
				continue
			var r := LR * _rng.randf_range(0.95, 1.05)
			ext.cyl("wood_ext", Vector3(x, y, s.x), Vector3(x, y, s.y), r, _log_color(), 12, true, -1.0, Color(0.62, 0.48, 0.34))
			var xi := x - signf(x) * 0.012
			inn.cyl("wood", Vector3(xi, y, maxf(s.x, -HZ + LR)), Vector3(xi, y, minf(s.y, HZ - LR)), r, _log_color_in(), 12, false)
			_col_box(Vector3(x, y, (s.x + s.y) * 0.5), Vector3(LR * 2.0, ROW_H + 0.01, s.y - s.x))


func _build_floor_ceiling() -> void:
	var ix := HX - LR
	var iz := HZ - LR
	# floor planks along Z
	var x := -ix
	while x < ix:
		var w := minf(0.21, ix - x)
		var v := _rng.randf_range(0.82, 1.05)
		inn.box_mm("wood", Vector3(x + 0.004, FLOOR_Y - 0.06, -iz), Vector3(x + w - 0.004, FLOOR_Y, iz), Color(0.48 * v, 0.34 * v, 0.23 * v))
		x += w
	inn.box_mm("plain", Vector3(-ix, FLOOR_Y - 0.1, -iz), Vector3(ix, FLOOR_Y - 0.05, iz), Color(0.08, 0.06, 0.05))
	_col_box(Vector3(0, FLOOR_Y - 0.2, 0), Vector3(HX * 2.0, 0.4, HZ * 2.0))
	# ceiling boards along X
	var z := -iz
	while z < iz:
		var w := minf(0.24, iz - z)
		var v := _rng.randf_range(0.85, 1.05)
		inn.box_mm("wood", Vector3(-ix, CEIL_Y, z + 0.003), Vector3(ix, CEIL_Y + 0.04, z + w - 0.003), Color(0.55 * v, 0.41 * v, 0.28 * v))
		z += w
	inn.box_mm("plain", Vector3(-ix, CEIL_Y + 0.04, -iz), Vector3(ix, CEIL_Y + 0.08, iz), Color(0.06, 0.05, 0.04))
	# the matitsa: the great beam that holds the ceiling
	inn.box_mm("wood", Vector3(-ix, CEIL_Y - 0.2, -0.12), Vector3(ix, CEIL_Y, 0.12), Color(0.42, 0.3, 0.2))
	# baseboard shadows
	inn.box_mm("wood", Vector3(-ix, FLOOR_Y, -iz), Vector3(ix, FLOOR_Y + 0.08, -iz + 0.03), Color(0.36, 0.26, 0.18))


func _roof_y(z: float) -> float:
	return EAVE_Y + (EAVE_Z - absf(z)) * (RIDGE_Y - EAVE_Y) / EAVE_Z


func _build_roof() -> void:
	var length := sqrt(EAVE_Z * EAVE_Z + pow(RIDGE_Y - EAVE_Y, 2.0))
	var theta := atan2(RIDGE_Y - EAVE_Y, EAVE_Z)
	for side in [1.0, -1.0]:
		var basis := Basis(Vector3.RIGHT, theta * side)
		var mid := Vector3(0, (EAVE_Y + RIDGE_Y) * 0.5, EAVE_Z * 0.5 * side)
		var nrm := basis * Vector3.UP
		# planks (seen from below at the eaves)
		ext.box("wood_ext", Transform3D(basis, mid), Vector3(ROOF_X * 2.0, 0.07, length + 0.05), Color(0.3, 0.24, 0.2))
		# roofing board battens visible on the underside
		for i in 9:
			var t := (float(i) / 8.0 - 0.5) * length
			var p := mid + basis * Vector3(0, -0.08, t)
			ext.box("wood_ext", Transform3D(basis, p), Vector3(ROOF_X * 2.0, 0.05, 0.1), Color(0.34, 0.26, 0.2))
		# heavy snow load on top
		var sp := mid + nrm * 0.17 + basis * Vector3(0, 0, 0.0)
		ext.box("snow", Transform3D(basis, sp), Vector3(ROOF_X * 2.0 - 0.1, 0.26, length - 0.02), Color.WHITE)
		# rounded snow lip curling over the eave
		var eave := Vector3(0, EAVE_Y, EAVE_Z * side) + nrm * 0.12
		ext.cyl("snow", Vector3(-ROOF_X + 0.05, eave.y, eave.z), Vector3(ROOF_X - 0.05, eave.y, eave.z), 0.16, Color.WHITE, 10, true)
		# icicles
		var x := -ROOF_X + 0.2
		while x < ROOF_X - 0.2:
			x += _rng.randf_range(0.08, 0.35)
			var l := pow(_rng.randf(), 2.0) * 0.55 + 0.06
			if side < 0.0:
				l *= 0.6
			var top := Vector3(x, eave.y - 0.08, eave.z + side * 0.02)
			ext.cyl("icicle", top, top - Vector3(0, l, 0), 0.025 + l * 0.04, Color.WHITE, 6, false, 0.002)
		# under-roof soffit boards between wall and eave
	# ridge board
	ext.box("wood_ext", Transform3D(Basis(), Vector3(0, RIDGE_Y + 0.04, 0)), Vector3(ROOF_X * 2.0, 0.12, 0.25), Color(0.32, 0.25, 0.2))
	ext.cyl("snow", Vector3(-ROOF_X + 0.05, RIDGE_Y + 0.22, 0), Vector3(ROOF_X - 0.05, RIDGE_Y + 0.22, 0), 0.2, Color.WHITE, 10, true)

	# gables: vertical board-and-batten
	for sx in [1.0, -1.0]:
		var gx: float = sx * (HX + 0.05)
		var z := -EAVE_Z + 0.55
		while z < EAVE_Z - 0.55:
			var w := 0.19
			var top := _roof_y(z + w * 0.5) - 0.1
			var bottom := BASE_Y + ROWS * ROW_H - 0.1
			if top > bottom:
				var v := _rng.randf_range(0.85, 1.1)
				ext.box_mm("wood_ext", Vector3(gx - 0.03, bottom, z), Vector3(gx + 0.03, top, z + w - 0.01), Color(0.4 * v, 0.31 * v, 0.24 * v))
			z += w
		# barge boards (prichelina) with a carved "towel" at the peak
		for side in [1.0, -1.0]:
			var a := Vector3(sx * ROOF_X, EAVE_Y - 0.05, side * EAVE_Z)
			var b := Vector3(sx * ROOF_X, RIDGE_Y - 0.05, 0.0)
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			var basis := Basis(Vector3.RIGHT, atan2(dir.y, -dir.z * side) * side)
			ext.box("paint", Transform3D(basis, mid - Vector3(0, 0.15, 0)), Vector3(0.05, 0.3, a.distance_to(b)), C_PAINT_WHITE)
			# scalloped edge
			for k in 9:
				var p: Vector3 = a.lerp(b, (k + 0.5) / 9.0) - Vector3(0, 0.32, 0)
				ext.sphere("paint", p, Vector3(0.03, 0.06, 0.12), C_PAINT_BLUE, 4, 6)
		ext.box_mm("paint", Vector3(sx * ROOF_X - 0.03, RIDGE_Y - 1.1, -0.14), Vector3(sx * ROOF_X + 0.03, RIDGE_Y - 0.1, 0.14), C_PAINT_WHITE)
		ext.sphere("paint", Vector3(sx * ROOF_X, RIDGE_Y - 1.15, 0), Vector3(0.05, 0.12, 0.12), C_PAINT_BLUE, 4, 8)
		# soffit under the gable overhang
	# attic window on the west gable
	ext.box_mm("plain", Vector3(-HX - 0.1, 3.85, -0.28), Vector3(-HX - 0.06, 4.35, 0.28), Color(0.05, 0.05, 0.06))
	ext.box_mm("paint", Vector3(-HX - 0.14, 3.8, -0.33), Vector3(-HX - 0.08, 3.85, 0.33), C_PAINT_WHITE)
	ext.box_mm("paint", Vector3(-HX - 0.14, 4.35, -0.33), Vector3(-HX - 0.08, 4.4, 0.33), C_PAINT_WHITE)
	ext.box_mm("paint", Vector3(-HX - 0.14, 3.85, -0.33), Vector3(-HX - 0.08, 4.35, -0.28), C_PAINT_WHITE)
	ext.box_mm("paint", Vector3(-HX - 0.14, 3.85, 0.28), Vector3(-HX - 0.08, 4.35, 0.33), C_PAINT_WHITE)
	ext.box_mm("paint", Vector3(-HX - 0.14, 4.08, -0.28), Vector3(-HX - 0.08, 4.12, 0.28), C_PAINT_WHITE)

	# brick chimney
	var cx := 2.2
	var cz := -1.65
	var chim := MeshKit.new()
	chim.box_mm("brick", Vector3(cx - 0.3, _roof_y(cz) - 0.4, cz - 0.3), Vector3(cx + 0.3, 5.55, cz + 0.3), Color(1, 1, 1))
	chim.box_mm("brick", Vector3(cx - 0.36, 5.55, cz - 0.36), Vector3(cx + 0.36, 5.65, cz + 0.36), Color(0.2, 0.2, 0.2))
	chim.build(self, "Chimney")
	ext.sphere("snow", Vector3(cx, 5.67, cz), Vector3(0.36, 0.06, 0.36), Color.WHITE, 4, 8)
	# chimney smoke
	smoke = GPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 60
	smoke.lifetime = 9.0
	smoke.preprocess = 9.0
	smoke.position = Vector3(cx, 5.75, cz)
	smoke.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 20, 20))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.18, 0.06, 0.05)
	pm.damping_min = 0.05
	pm.damping_max = 0.1
	pm.scale_min = 0.8
	pm.scale_max = 1.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 3.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.72, 0.78, 0.0))
	grad.add_point(0.12, Color(0.62, 0.64, 0.7, 0.35))
	grad.set_color(grad.get_point_count() - 1, Color(0.55, 0.58, 0.66, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.angle_min = -180
	pm.angle_max = 180
	pm.angular_velocity_min = -12
	pm.angular_velocity_max = 12
	smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = _smoke_tex()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	sm.disable_receive_shadows = true
	q.material = sm
	smoke.draw_pass_1 = q
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.emitting = false
	add_child(smoke)


static func _smoke_tex() -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	nt.width = 64
	nt.height = 64
	var n := FastNoiseLite.new()
	n.frequency = 0.06
	nt.noise = n
	nt.seamless = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	nt.color_ramp = g
	# Radial falloff is applied by shaping alpha through the ramp; good enough
	# for soft wisps at this size.
	return nt


func _build_windows() -> void:
	# south window (in the XY plane at z = +HZ), east & west windows (ZY plane)
	_window(Vector3(0, 0, HZ), Vector3(1, 0, 0), Vector3(0, 0, 1), WIN_S.x, WIN_S.y, WIN_S.z, WIN_S.w)
	_window(Vector3(HX, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0), -WIN_E.y, -WIN_E.x, WIN_E.z, WIN_E.w)
	_window(Vector3(-HX, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), WIN_W.x, WIN_W.y, WIN_W.z, WIN_W.w)


## origin: point on wall centreline; u: along-wall axis; n: outward normal.
func _window(origin: Vector3, u: Vector3, n: Vector3, a: float, b: float, y0: float, y1: float) -> void:
	var basis := Basis(u, Vector3.UP, n)
	var to_w := func(lx: float, ly: float, lz: float) -> Vector3:
		return origin + u * lx + Vector3.UP * ly + n * lz
	var xf := func(lx: float, ly: float, lz: float) -> Transform3D:
		return Transform3D(basis, to_w.call(lx, ly, lz))
	var w := b - a
	var h := y1 - y0
	var cx := (a + b) * 0.5
	var cy := (y0 + y1) * 0.5
	# jambs (inner frame boards lining the cut)
	ext.box("wood", xf.call(cx, y0 + 0.03, 0.0), Vector3(w, 0.06, LR * 2.2), Color(0.55, 0.42, 0.3))
	ext.box("wood", xf.call(cx, y1 - 0.03, 0.0), Vector3(w, 0.06, LR * 2.2), Color(0.55, 0.42, 0.3))
	ext.box("wood", xf.call(a + 0.03, cy, 0.0), Vector3(0.06, h, LR * 2.2), Color(0.55, 0.42, 0.3))
	ext.box("wood", xf.call(b - 0.03, cy, 0.0), Vector3(0.06, h, LR * 2.2), Color(0.55, 0.42, 0.3))
	# double frames (winter + summer sash), painted white
	for depth in [0.07, -0.07]:
		var c := C_PAINT_WHITE if depth > 0.0 else Color(0.82, 0.8, 0.74)
		ext.box("paint", xf.call(cx, cy, depth), Vector3(0.04, h - 0.1, 0.04), c)
		ext.box("paint", xf.call(cx, y0 + h * 0.62, depth), Vector3(w - 0.1, 0.04, 0.04), c)
		ext.box("paint", xf.call(cx, y0 + 0.08, depth), Vector3(w - 0.1, 0.05, 0.05), c)
		ext.box("paint", xf.call(cx, y1 - 0.08, depth), Vector3(w - 0.1, 0.05, 0.05), c)
		ext.box("paint", xf.call(a + 0.08, cy, depth), Vector3(0.05, h - 0.1, 0.05), c)
		ext.box("paint", xf.call(b - 0.08, cy, depth), Vector3(0.05, h - 0.1, 0.05), c)
	# glass panes (frosted outer pane, clear inner)
	var glass := MeshInstance3D.new()
	var gk := MeshKit.new()
	var pw := (w - 0.2) * 0.5
	var ph := h - 0.2
	for i in 2:
		var px0 := a + 0.1 + i * pw
		var p0: Vector3 = to_w.call(px0, y0 + 0.1, 0.075)
		var p1: Vector3 = to_w.call(px0 + pw, y0 + 0.1, 0.075)
		var p2: Vector3 = to_w.call(px0 + pw, y1 - 0.1, 0.075)
		var p3: Vector3 = to_w.call(px0, y1 - 0.1, 0.075)
		gk.quad("glass", p0, p1, p2, p3, Color.WHITE)
	var gm := gk.build(self, "Glass", false)
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(Mats.get_mat("glass") as ShaderMaterial).set_shader_parameter("pane", Vector2(pw, ph))
	# a pad of cotton wool between the frames with little paper snowflakes:
	# the old winter custom
	ext.box("fabric", xf.call(cx, y0 + 0.13, 0.0), Vector3(w - 0.16, 0.05, 0.1), Color(0.95, 0.95, 0.95))
	for k in 3:
		ext.sphere("unshaded", to_w.call(a + 0.25 + k * (w - 0.5) * 0.5, y0 + 0.18, 0.0), Vector3(0.025, 0.025, 0.003), Color(0.95, 0.95, 1.0), 3, 6, basis)
	# --- nalichnik: carved, painted surround ---
	var o := LR + 0.04
	var bw := 0.13
	ext.box("paint", xf.call(a - bw * 0.5, cy, o), Vector3(bw, h + 0.25, 0.04), C_PAINT_BLUE)
	ext.box("paint", xf.call(b + bw * 0.5, cy, o), Vector3(bw, h + 0.25, 0.04), C_PAINT_BLUE)
	ext.box("paint", xf.call(cx, y0 - 0.08, o), Vector3(w + bw * 2.4, 0.12, 0.07), C_PAINT_BLUE)
	# sill skirt with drops
	for k in 7:
		var lx := a - bw + (w + bw * 2.0) * (k + 0.5) / 7.0
		ext.sphere("paint", to_w.call(lx, y0 - 0.19, o), Vector3(0.05, 0.07, 0.02), C_PAINT_WHITE, 4, 6, basis)
	# kokoshnik crest: stepped pediment with a carved sun
	ext.box("paint", xf.call(cx, y1 + 0.1, o), Vector3(w + bw * 2.6, 0.12, 0.06), C_PAINT_BLUE)
	var crest_w := w + bw * 2.2
	for k in 4:
		var kw := crest_w * (1.0 - k * 0.22)
		ext.box("paint", xf.call(cx, y1 + 0.2 + k * 0.08, o), Vector3(kw, 0.08, 0.05), C_PAINT_WHITE if k % 2 == 0 else C_PAINT_BLUE)
	ext.sphere("paint", to_w.call(cx, y1 + 0.32, o + 0.03), Vector3(0.11, 0.11, 0.02), Color(0.85, 0.65, 0.25), 6, 12, basis)
	for k in 8:
		var ang := TAU * k / 8.0
		ext.box("paint", Transform3D(basis * Basis(Vector3.BACK, ang), to_w.call(cx + cos(ang) * 0.16, y1 + 0.32 + sin(ang) * 0.16, o + 0.03)), Vector3(0.07, 0.025, 0.015), Color(0.85, 0.65, 0.25))
	# snow on the sill and crest
	ext.box("snow", xf.call(cx, y0 - 0.0, o + 0.03), Vector3(w + bw * 2.0, 0.05, 0.12), Color.WHITE)
	ext.box("snow", xf.call(cx, y1 + 0.52, o), Vector3(crest_w * 0.35, 0.04, 0.08), Color.WHITE)
	# open shutters
	for side in [-1.0, 1.0]:
		var sx: float = (a - bw - w * 0.27) if side < 0.0 else (b + bw + w * 0.27)
		ext.box("paint", xf.call(sx, cy, o + 0.02), Vector3(w * 0.5, h, 0.035), C_PAINT_BLUE)
		ext.box("paint", xf.call(sx, cy, o + 0.045), Vector3(w * 0.4, h * 0.88, 0.01), Color(0.17, 0.33, 0.4))
		ext.box("paint", Transform3D(basis * Basis(Vector3.BACK, PI * 0.25), to_w.call(sx, cy, o + 0.05)), Vector3(0.14, 0.14, 0.012), C_PAINT_WHITE)
		ext.box("snow", xf.call(sx, y1 + 0.02, o + 0.02), Vector3(w * 0.5, 0.035, 0.06), Color.WHITE)
	# interior: sill board and a warm light that glows outward at night
	var sill: Vector3 = to_w.call(cx, y0 - 0.01, -LR - 0.06)
	inn.box("wood", Transform3D(basis, sill), Vector3(w + 0.2, 0.04, 0.2), Color(0.55, 0.42, 0.3))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.68, 0.38)
	glow.light_energy = 0.0
	glow.omni_range = 4.5
	glow.omni_attenuation = 1.6
	glow.shadow_enabled = false
	glow.light_cull_mask = 1
	add_child(glow)
	glow.position = to_w.call(cx, cy, 0.9)
	window_glows.append(glow)


func _build_porch() -> void:
	var x0 := 0.95
	var x1 := 2.85
	var z0 := HZ + LR
	var z1 := 4.1
	# deck boards
	var z := z0
	while z < z1:
		var v := _rng.randf_range(0.8, 1.05)
		ext.box_mm("wood_ext", Vector3(x0, FLOOR_Y - 0.06, z + 0.005), Vector3(x1, FLOOR_Y, z + 0.17), Color(0.44 * v, 0.34 * v, 0.25 * v))
		z += 0.18
	ext.box_mm("wood_ext", Vector3(x0, -0.2, z0), Vector3(x1, FLOOR_Y - 0.06, z1), Color(0.3, 0.24, 0.18))
	_col_box(Vector3((x0 + x1) * 0.5, FLOOR_Y - 0.2, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.4, z1 - z0))
	# steps
	for s in 3:
		var sy := FLOOR_Y - (s + 1) * 0.13
		var sz := z1 + s * 0.3
		ext.box_mm("wood_ext", Vector3(x0 + 0.15, sy - 0.05, sz), Vector3(x1 - 0.15, sy, sz + 0.3), Color(0.45, 0.35, 0.26))
		ext.box_mm("snow", Vector3(x0 + 0.2, sy, sz + 0.12), Vector3(x0 + 0.5, sy + 0.04, sz + 0.3), Color.WHITE)
	# ramp collider for the steps
	var rise := FLOOR_Y + 0.05
	var run := 0.95
	_col_box(Vector3((x0 + x1) * 0.5, rise * 0.5 - 0.1, z1 + run * 0.5), Vector3(x1 - x0 - 0.3, 0.1, sqrt(rise * rise + run * run)), atan2(rise, run))
	# posts and canopy
	for px in [x0 + 0.08, x1 - 0.08]:
		ext.box_mm("wood_ext", Vector3(px - 0.06, FLOOR_Y, z1 - 0.14), Vector3(px + 0.06, 2.75, z1 - 0.02), Color(0.42, 0.32, 0.23))
		# carved bracket
		ext.box("wood_ext", Transform3D(Basis(Vector3.RIGHT, PI * 0.25), Vector3(px, 2.5, z1 - 0.3)), Vector3(0.06, 0.06, 0.5), Color(0.42, 0.32, 0.23))
	# side railings
	for px in [x0 + 0.08, x1 - 0.08]:
		ext.box_mm("wood_ext", Vector3(px - 0.04, 1.35, z0), Vector3(px + 0.04, 1.42, z1 - 0.1), Color(0.42, 0.32, 0.23))
		var zz := z0 + 0.15
		while zz < z1 - 0.1:
			ext.box_mm("wood_ext", Vector3(px - 0.03, FLOOR_Y, zz), Vector3(px + 0.03, 1.35, zz + 0.06), Color(0.4, 0.31, 0.22))
			zz += 0.22
		ext.box_mm("snow", Vector3(px - 0.05, 1.42, z0), Vector3(px + 0.05, 1.47, z1 - 0.1), Color.WHITE)
		_col_box(Vector3(px, 0.95, (z0 + z1) * 0.5), Vector3(0.1, 0.9, z1 - z0))
	# canopy: small gable roof
	var cy := 2.8
	var cw := (x1 - x0) * 0.5 + 0.25
	var cxm := (x0 + x1) * 0.5
	var ang := 0.5
	for side in [-1.0, 1.0]:
		var basis := Basis(Vector3.BACK, -ang * side)
		var p := Vector3(cxm + side * cw * 0.5, cy + 0.27, (z0 + z1) * 0.5 + 0.15)
		ext.box("wood_ext", Transform3D(basis, p), Vector3(cw * 1.15, 0.06, z1 - z0 + 0.6), Color(0.32, 0.25, 0.2))
		ext.box("snow", Transform3D(basis, p + basis * Vector3(0, 0.12, 0)), Vector3(cw * 1.1, 0.18, z1 - z0 + 0.5), Color.WHITE)
	ext.box_mm("wood_ext", Vector3(x0, cy - 0.06, z1 - 0.15), Vector3(x1, cy + 0.04, z1 - 0.02), Color(0.4, 0.3, 0.22))
	# a broom of birch twigs leaning by the door (venik)
	ext.cyl("wood_dry", Vector3(2.65, FLOOR_Y, HZ + 0.25), Vector3(2.75, FLOOR_Y + 1.1, HZ + 0.2), 0.015, Color(0.6, 0.5, 0.35), 5)
	ext.cyl("twigs_solid", Vector3(2.64, FLOOR_Y, HZ + 0.25), Vector3(2.69, FLOOR_Y + 0.4, HZ + 0.23), 0.07, Color(0.42, 0.32, 0.22), 6, true, 0.02)


func _build_door() -> void:
	door = AnimatableBody3D.new()
	door.name = "Door"
	door.sync_to_physics = false
	door.position = Vector3(DOOR.x, DOOR.z, HZ)
	add_child(door)
	var w := DOOR.y - DOOR.x - 0.04
	var h := DOOR.w - DOOR.z - 0.02
	var k := MeshKit.new()
	# outer planks
	var x := 0.02
	while x < w:
		var v := _rng.randf_range(0.85, 1.05)
		k.box_mm("wood_ext", Vector3(x, 0.0, 0.02), Vector3(minf(x + 0.14, w), h, 0.07), Color(0.36 * v, 0.28 * v, 0.21 * v))
		x += 0.145
	# Z-brace outside
	k.box_mm("wood_ext", Vector3(0.05, 0.25, 0.07), Vector3(w - 0.05, 0.37, 0.1), Color(0.3, 0.23, 0.17))
	k.box_mm("wood_ext", Vector3(0.05, h - 0.37, 0.07), Vector3(w - 0.05, h - 0.25, 0.1), Color(0.3, 0.23, 0.17))
	var diag := Vector3(w - 0.15, h - 0.62, 0)
	k.box("wood_ext", Transform3D(Basis(Vector3.BACK, atan2(diag.y, diag.x)), Vector3(w * 0.5, h * 0.5, 0.085)), Vector3(diag.length(), 0.1, 0.03), Color(0.3, 0.23, 0.17))
	# inside: padded leatherette with brass studs in a diamond lattice
	k.box_mm("fabric", Vector3(0.04, 0.04, -0.03), Vector3(w - 0.02, h - 0.04, 0.02), Color(0.32, 0.12, 0.09))
	for i in 7:
		for j in 13:
			if (i + j) % 2 == 0:
				var sp := Vector3(0.1 + i * (w - 0.16) / 6.0, 0.12 + j * (h - 0.24) / 12.0, -0.035)
				k.sphere("chrome", sp, Vector3(0.012, 0.012, 0.008), Color(0.8, 0.65, 0.35), 3, 5)
	# handles
	k.cyl("metal", Vector3(w - 0.12, 1.0, 0.1), Vector3(w - 0.12, 1.18, 0.1), 0.014, Color(0.15, 0.14, 0.13), 6)
	k.cyl("metal", Vector3(w - 0.12, 1.0, -0.06), Vector3(w - 0.12, 1.18, -0.06), 0.014, Color(0.15, 0.14, 0.13), 6)
	k.build(door, "DoorMesh")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, h, 0.1)
	cs.shape = bs
	cs.position = Vector3(w * 0.5, h * 0.5, 0.02)
	door.add_child(cs)
	# door frame
	ext.box_mm("wood", Vector3(DOOR.x - 0.08, DOOR.z, HZ - LR - 0.02), Vector3(DOOR.x, DOOR.w + 0.08, HZ + LR + 0.02), Color(0.5, 0.38, 0.27))
	ext.box_mm("wood", Vector3(DOOR.y, DOOR.z, HZ - LR - 0.02), Vector3(DOOR.y + 0.08, DOOR.w + 0.08, HZ + LR + 0.02), Color(0.5, 0.38, 0.27))
	ext.box_mm("wood", Vector3(DOOR.x - 0.08, DOOR.w, HZ - LR - 0.02), Vector3(DOOR.y + 0.08, DOOR.w + 0.1, HZ + LR + 0.02), Color(0.5, 0.38, 0.27))
	ext.box_mm("wood", Vector3(DOOR.x, DOOR.z - 0.04, HZ - LR), Vector3(DOOR.y, DOOR.z + 0.03, HZ + LR), Color(0.42, 0.32, 0.24))
	# Kostya's height marks on the inner jamb
	for m in [[1.12, "1972"], [1.31, "1975"], [1.5, "1977"], [1.68, "1979"]]:
		inn.box_mm("plain", Vector3(DOOR.y + 0.005, m[0], HZ - LR - 0.03), Vector3(DOOR.y + 0.07, m[0] + 0.006, HZ - LR - 0.025), Color(0.18, 0.12, 0.08))
		var lbl := Label3D.new()
		lbl.text = "К. " + m[1]
		lbl.font = UITheme.font_hand()
		lbl.font_size = 22
		lbl.pixel_size = 0.0011
		lbl.modulate = Color(0.16, 0.11, 0.08, 0.9)
		lbl.outline_size = 0
		lbl.position = Vector3(DOOR.y + 0.045, m[0] + 0.022, HZ - LR - 0.032)
		lbl.rotation.y = PI
		lbl.shaded = true
		lbl.double_sided = false
		add_child(lbl)
	var it := Interactable.make(self, "door", {"ru": "Открыть дверь", "en": "Open the door"}, Vector3(1.0, 1.9, 0.5), Vector3((DOOR.x + DOOR.y) * 0.5, 1.45, HZ))
	interactables["door"] = it
	interactables["marks"] = Interactable.make(self, "marks", {"ru": "Зарубки на косяке", "en": "Marks on the door frame"}, Vector3(0.2, 0.8, 0.2), Vector3(DOOR.y + 0.06, 1.4, HZ - LR - 0.08))


func set_door_open(open: bool, animate := true) -> void:
	door_open = open
	var target := deg_to_rad(100.0) if open else 0.0
	if animate:
		var t := create_tween()
		t.tween_property(door, "rotation:y", target, 1.1 if open else 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
		Sfx.play_3d("door_open" if open else "door_close", door.global_position, -4.0)
	else:
		door.rotation.y = target
	var it: Interactable = interactables["door"]
	it.prompt = {"ru": "Закрыть дверь", "en": "Close the door"} if open else {"ru": "Открыть дверь", "en": "Open the door"}


func _build_stove() -> void:
	# The Russian stove: a whitewashed mass in the north-east corner.
	var x0 := 1.3
	var x1 := HX - LR - 0.02
	var z0 := -HZ + LR + 0.02
	var z1 := -0.72
	var top := 2.15
	var mx := 2.2
	var mw := 0.27
	var my0 := 1.0
	var my1 := 1.45
	var s := MeshKit.new()
	var white := Color(1, 1, 1)
	var soot := Color(0.35, 0.33, 0.31)
	# plinth
	s.box_mm("plaster", Vector3(x0 - 0.04, FLOOR_Y, z0), Vector3(x1, FLOOR_Y + 0.12, z1 + 0.04), Color(0.82, 0.8, 0.76))
	# lower body (with a firewood niche)
	s.box_mm("plaster", Vector3(x0, FLOOR_Y + 0.12, z0), Vector3(x1, my0 - 0.05, z1 - 0.32), white)
	s.box_mm("plaster", Vector3(x0, FLOOR_Y + 0.12, z1 - 0.32), Vector3(mx - 0.35, my0 - 0.05, z1), white)
	s.box_mm("plaster", Vector3(mx + 0.35, FLOOR_Y + 0.12, z1 - 0.32), Vector3(x1, my0 - 0.05, z1), white)
	s.box_mm("plain", Vector3(mx - 0.35, FLOOR_Y + 0.12, z1 - 0.32), Vector3(mx + 0.35, FLOOR_Y + 0.14, z1), Color(0.1, 0.08, 0.07))
	# shestok ledge
	s.box_mm("plaster", Vector3(x0, my0 - 0.05, z1 - 0.3), Vector3(x1, my0, z1 + 0.04), Color(0.88, 0.86, 0.82))
	# mouth level: pillars either side of the arch, solid behind the firebox
	s.box_mm("plaster", Vector3(x0, my0, z1 - 0.3), Vector3(mx - mw, my1 + 0.1, z1), white)
	s.box_mm("plaster", Vector3(mx + mw, my0, z1 - 0.3), Vector3(x1, my1 + 0.1, z1), white)
	s.box_mm("plaster", Vector3(x0, my0, z0), Vector3(x1, my1 + 0.1, z1 - 0.3), white)
	# the firebox: dark sooty interior behind the mouth
	s.box_mm("plain", Vector3(mx - mw, my0 - 0.001, z1 - 0.9), Vector3(mx + mw, my0 + 0.01, z1 - 0.29), Color(0.07, 0.05, 0.04))
	# arch above the mouth
	s.box_mm("plaster", Vector3(mx - mw, my1, z1 - 0.3), Vector3(mx + mw, my1 + 0.1, z1), soot)
	# upper body
	s.box_mm("plaster", Vector3(x0, my1 + 0.1, z0), Vector3(x1, top - 0.08, z1), white)
	s.box_mm("plaster", Vector3(x0 - 0.03, top - 0.08, z0), Vector3(x1, top, z1 + 0.03), Color(0.9, 0.88, 0.84))
	# chimney stack up to the ceiling
	s.box_mm("plaster", Vector3(mx - 0.32, top, -1.97), Vector3(mx + 0.32, CEIL_Y, -1.33), white)
	# damper knob
	s.cyl("metal", Vector3(mx, 2.6, -1.33), Vector3(mx, 2.6, -1.25), 0.025, Color(0.6, 0.45, 0.2), 8)
	# blue painted trim band, a touch of folk decoration
	s.box_mm("paint", Vector3(x0 - 0.005, top - 0.22, z1 + 0.001), Vector3(x1, top - 0.18, z1 + 0.012), C_PAINT_BLUE)
	s.box_mm("paint", Vector3(x0 - 0.012, top - 0.22, z0), Vector3(x0 - 0.001, top - 0.18, z1), C_PAINT_BLUE)
	s.build(self, "Stove")
	# soot inside the firebox walls
	var fb := MeshKit.new()
	fb.box_mm("plain", Vector3(mx - mw - 0.02, my0, z1 - 0.95), Vector3(mx - mw, my1, z1 - 0.29), Color(0.05, 0.04, 0.04))
	fb.box_mm("plain", Vector3(mx + mw, my0, z1 - 0.95), Vector3(mx + mw + 0.02, my1, z1 - 0.29), Color(0.05, 0.04, 0.04))
	fb.box_mm("plain", Vector3(mx - mw, my1 - 0.02, z1 - 0.95), Vector3(mx + mw, my1, z1 - 0.29), Color(0.04, 0.03, 0.03))
	fb.box_mm("plain", Vector3(mx - mw, my0, z1 - 0.95), Vector3(mx + mw, my1, z1 - 0.9), Color(0.04, 0.03, 0.03))
	fb.build(self, "Firebox")
	_col_box(Vector3((x0 + x1) * 0.5, (FLOOR_Y + top) * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, top - FLOOR_Y, z1 - z0))
	# iron oven door (zaslonka) leaning beside the mouth
	var zk := MeshKit.new()
	zk.box("metal_rough", Transform3D(Basis(Vector3.RIGHT, -0.12), Vector3(mx + 0.55, my0 + 0.22, z1 + 0.07)), Vector3(0.48, 0.42, 0.02), Color(0.13, 0.12, 0.12))
	zk.cyl("metal", Vector3(mx + 0.55, my0 + 0.3, z1 + 0.1), Vector3(mx + 0.55, my0 + 0.3, z1 + 0.16), 0.012, Color(0.2, 0.2, 0.2), 6)
	zk.build(self, "Zaslonka")
	# firewood in the firebox (shown after loading)
	wood_in_stove = Node3D.new()
	add_child(wood_in_stove)
	var wk := MeshKit.new()
	for i in 4:
		var px := mx - 0.14 + i * 0.09
		wk.cyl("bark_birch", Vector3(px, my0 + 0.06 + (i % 2) * 0.06, z1 - 0.85), Vector3(px + 0.03, my0 + 0.06 + (i % 2) * 0.06, z1 - 0.42), 0.045, Color.WHITE, 7, true, -1.0, Color(0.75, 0.6, 0.42))
	wk.build(wood_in_stove, "Logs")
	wood_in_stove.visible = false
	# fire
	stove_fire = Node3D.new()
	stove_fire.name = "Fire"
	stove_fire.position = Vector3(mx, my0 + 0.05, z1 - 0.6)
	add_child(stove_fire)
	stove_fire.add_child(_make_fire())
	stove_fire.visible = false
	stove_light = OmniLight3D.new()
	stove_light.light_color = Color(1.0, 0.52, 0.22)
	stove_light.light_energy = 0.0
	stove_light.omni_range = 6.5
	stove_light.omni_attenuation = 1.4
	stove_light.shadow_enabled = true
	stove_light.shadow_bias = 0.06
	stove_light.position = Vector3(mx, my0 + 0.3, z1 + 0.25)
	add_child(stove_light)
	fire_sound = Sfx.make_loop_3d("fire", self, -8.0, "SFX", 2.0)
	fire_sound.position = stove_fire.position
	interactables["stove"] = Interactable.make(self, "stove", {"ru": "Печь", "en": "Stove"}, Vector3(0.7, 0.55, 0.5), Vector3(mx, my0 + 0.25, z1 + 0.02))
	# woodbasket by the stove
	var bk := MeshKit.new()
	var bx := 0.95
	var bz := -1.75
	bk.lathe("wood_dry", Transform3D(Basis(), Vector3(bx, FLOOR_Y, bz)), [Vector2(0.0, 0.0), Vector2(0.24, 0.0), Vector2(0.27, 0.32), Vector2(0.26, 0.34), Vector2(0.0, 0.34)], Color(0.6, 0.45, 0.3), 14)
	for i in 7:
		var a := _rng.randf() * TAU
		var p := Vector3(bx + cos(a) * 0.08, FLOOR_Y + 0.38 + (i % 3) * 0.05, bz + sin(a) * 0.08)
		var d := Vector3(cos(a + 1.6), _rng.randf_range(-0.2, 0.2), sin(a + 1.6)) * 0.22
		bk.cyl("bark_birch", p - d, p + d, 0.045, Color.WHITE, 7, true, -1.0, Color(0.78, 0.62, 0.44))
	bk.build(self, "Woodbasket")
	_col_box(Vector3(bx, FLOOR_Y + 0.2, bz), Vector3(0.5, 0.4, 0.5))
	interactables["wood"] = Interactable.make(self, "wood", {"ru": "Взять дрова", "en": "Take firewood"}, Vector3(0.6, 0.6, 0.6), Vector3(bx, FLOOR_Y + 0.35, bz))
	# kettle on the shestok
	kettle = Node3D.new()
	kettle.name = "Kettle"
	kettle.position = Vector3(mx - 0.6, my0, z1 - 0.08)
	add_child(kettle)
	var kk := MeshKit.new()
	kk.lathe("metal", Transform3D(), [Vector2(0, 0), Vector2(0.1, 0), Vector2(0.12, 0.04), Vector2(0.12, 0.13), Vector2(0.09, 0.19), Vector2(0.03, 0.21), Vector2(0, 0.21)], Color(0.72, 0.73, 0.74), 18)
	kk.cyl("metal", Vector3(0.1, 0.06, 0), Vector3(0.2, 0.17, 0), 0.016, Color(0.7, 0.71, 0.72), 6, true, 0.009)
	kk.torus("metal", Vector3(0, 0.24, 0), 0.08, 0.008, Color(0.15, 0.15, 0.15), 14, 5, Basis(Vector3.RIGHT, PI * 0.5), PI)
	kk.sphere("metal", Vector3(0, 0.215, 0), Vector3(0.02, 0.015, 0.02), Color(0.2, 0.2, 0.2), 4, 6)
	kk.build(kettle, "KettleMesh")
	interactables["kettle"] = Interactable.make(self, "kettle", {"ru": "Чайник", "en": "Kettle"}, Vector3(0.3, 0.3, 0.3), kettle.position + Vector3(0, 0.12, 0))


func _make_fire() -> Node3D:
	var root := Node3D.new()
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.9
	p.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.14, 0.02, 0.12)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.5, 1.0))
	g.add_point(0.4, Color(1.0, 0.45, 0.1, 0.9))
	g.set_color(g.get_point_count() - 1, Color(0.6, 0.1, 0.02, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.22)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = World._soft_dot()
	q.material = m
	p.draw_pass_1 = q
	root.add_child(p)
	# glowing embers bed
	var ek := MeshKit.new()
	for i in 14:
		ek.sphere("emissive", Vector3(_rng.randf_range(-0.16, 0.16), 0.01, _rng.randf_range(-0.12, 0.12)), Vector3(0.04, 0.02, 0.04), Color(1.0, 0.35, 0.08), 3, 5)
	ek.build(root, "Embers", false)
	return root


func set_stove_lit(lit: bool) -> void:
	stove_lit = lit
	stove_fire.visible = lit
	wood_in_stove.visible = lit or wood_in_stove.visible
	smoke.emitting = lit
	if lit:
		fire_sound.play()
		var t := create_tween()
		stove_light.light_energy = 0.0
		t.tween_property(stove_light, "light_energy", 1.4, 3.0)
	else:
		fire_sound.stop()
		stove_light.light_energy = 0.0
	_update_window_glow()


func set_lamp_lit(lit: bool) -> void:
	lamp_lit = lit
	lamp_flame.visible = lit
	lamp_light.visible = lit
	_update_window_glow()


func _update_window_glow() -> void:
	var e := (0.5 if lamp_lit else 0.0) + (0.35 if stove_lit else 0.0)
	for g in window_glows:
		create_tween().tween_property(g, "light_energy", e, 2.0)


func _build_furniture() -> void:
	var f := inn
	# --- iron bed along the north wall, under the carpet ---
	var bx0 := -HX + LR + 0.05
	var bx1 := -1.15
	var bz0 := -HZ + LR + 0.05
	var bz1 := -1.5
	var iron := Color(0.12, 0.14, 0.13)
	for px in [bx0 + 0.03, bx1 - 0.03]:
		for pz in [bz0 + 0.03, bz1 - 0.03]:
			var hgt := 1.45 if px < -2.0 else 1.25
			f.cyl("metal", Vector3(px, FLOOR_Y, pz), Vector3(px, FLOOR_Y + hgt, pz), 0.02, iron, 8)
			f.sphere("chrome", Vector3(px, FLOOR_Y + hgt + 0.03, pz), Vector3(0.04, 0.04, 0.04), Color(0.75, 0.72, 0.65), 6, 8)
	for hx in [bx0 + 0.03, bx1 - 0.03]:
		var hgt := 1.4 if hx < -2.0 else 1.2
		f.cyl("metal", Vector3(hx, FLOOR_Y + hgt, bz0 + 0.03), Vector3(hx, FLOOR_Y + hgt, bz1 - 0.03), 0.015, iron, 6)
		for k in 6:
			var zz := lerpf(bz0 + 0.1, bz1 - 0.1, k / 5.0)
			f.cyl("metal", Vector3(hx, FLOOR_Y + 0.55, zz), Vector3(hx, FLOOR_Y + hgt, zz), 0.008, iron, 5)
	f.box_mm("metal", Vector3(bx0, FLOOR_Y + 0.5, bz0), Vector3(bx1, FLOOR_Y + 0.54, bz1), iron)
	# mattress, wool blanket, pillows stacked under lace
	f.box_mm("fabric", Vector3(bx0 + 0.04, FLOOR_Y + 0.54, bz0 + 0.03), Vector3(bx1 - 0.04, FLOOR_Y + 0.68, bz1 - 0.03), Color(0.75, 0.72, 0.66))
	f.box_mm("fabric", Vector3(bx0 + 0.45, FLOOR_Y + 0.68, bz0 + 0.02), Vector3(bx1 - 0.02, FLOOR_Y + 0.73, bz1 - 0.01), Color(0.42, 0.18, 0.15))
	f.box_mm("fabric", Vector3(bx0 + 0.45, FLOOR_Y + 0.25, bz1 - 0.04), Vector3(bx1 - 0.02, FLOOR_Y + 0.73, bz1 - 0.01), Color(0.38, 0.16, 0.13))
	for k in 5:
		var zz := lerpf(bz0 + 0.12, bz1 - 0.12, k / 4.0)
		f.box_mm("fabric", Vector3(bx0 + 0.45, FLOOR_Y + 0.731, zz - 0.012), Vector3(bx1 - 0.02, FLOOR_Y + 0.733, zz + 0.012), Color(0.75, 0.62, 0.42))
	var px := bx0 + 0.25
	var pz := (bz0 + bz1) * 0.5
	f.sphere("fabric", Vector3(px, FLOOR_Y + 0.8, pz), Vector3(0.2, 0.09, 0.32), Color(0.93, 0.92, 0.88), 6, 12)
	f.sphere("fabric", Vector3(px + 0.02, FLOOR_Y + 0.94, pz), Vector3(0.15, 0.07, 0.24), Color(0.93, 0.92, 0.88), 6, 12)
	f.sphere("fabric", Vector3(px + 0.03, FLOOR_Y + 1.05, pz), Vector3(0.1, 0.05, 0.16), Color(0.93, 0.92, 0.88), 6, 12)
	f.box_mm("fabric", Vector3(px - 0.12, FLOOR_Y + 1.08, pz - 0.18), Vector3(px + 0.15, FLOOR_Y + 1.09, pz + 0.18), Color(0.97, 0.97, 0.95))
	_col_box(Vector3((bx0 + bx1) * 0.5, FLOOR_Y + 0.4, (bz0 + bz1) * 0.5), Vector3(bx1 - bx0, 0.8, bz1 - bz0))
	interactables["bed"] = Interactable.make(self, "bed", {"ru": "Кровать", "en": "Bed"}, Vector3(1.9, 0.6, 0.95), Vector3((bx0 + bx1) * 0.5, FLOOR_Y + 0.8, (bz0 + bz1) * 0.5))
	# wall carpet above the bed
	var cz := -HZ + LR + 0.02
	var ck := MeshKit.new()
	ck.quad("carpet", Vector3(bx0 + 0.05, FLOOR_Y + 0.85, cz), Vector3(bx1 + 0.15, FLOOR_Y + 0.85, cz), Vector3(bx1 + 0.15, FLOOR_Y + 2.2, cz), Vector3(bx0 + 0.05, FLOOR_Y + 2.2, cz), Color.WHITE)
	var cm := ck.build(self, "Carpet")
	var cmat := (Mats.get_mat("carpet") as ShaderMaterial)
	cmat.set_shader_parameter("size", Vector2(bx1 + 0.1 - bx0, 1.35))
	interactables["carpet"] = Interactable.make(self, "carpet", {"ru": "Ковёр", "en": "Wall carpet"}, Vector3(1.9, 1.3, 0.1), Vector3((bx0 + bx1) * 0.5 + 0.05, FLOOR_Y + 1.55, cz + 0.05))

	# --- table under the west window with oilcloth ---
	var tx0 := -HX + LR + 0.05
	var tx1 := -2.0
	var tz0 := -0.7
	var tz1 := 0.75
	var th := FLOOR_Y + 0.76
	for lx in [tx0 + 0.05, tx1 - 0.05]:
		for lz in [tz0 + 0.05, tz1 - 0.05]:
			f.box_mm("wood", Vector3(lx - 0.03, FLOOR_Y, lz - 0.03), Vector3(lx + 0.03, th - 0.04, lz + 0.03), Color(0.38, 0.27, 0.18))
	f.box_mm("wood", Vector3(tx0, th - 0.12, tz0 + 0.02), Vector3(tx1, th - 0.04, tz1 - 0.02), Color(0.4, 0.28, 0.19))
	f.box_mm("wood", Vector3(tx0, th - 0.04, tz0), Vector3(tx1, th, tz1), Color(0.45, 0.32, 0.22))
	var ok := MeshKit.new()
	ok.quad("oilcloth", Vector3(tx0, th + 0.002, tz1), Vector3(tx1 + 0.03, th + 0.002, tz1), Vector3(tx1 + 0.03, th + 0.002, tz0), Vector3(tx0, th + 0.002, tz0), Color.WHITE)
	ok.quad("oilcloth", Vector3(tx1 + 0.03, th + 0.002, tz1), Vector3(tx1 + 0.03, th - 0.12, tz1), Vector3(tx1 + 0.03, th - 0.12, tz0), Vector3(tx1 + 0.03, th + 0.002, tz0), Color.WHITE)
	ok.build(self, "Oilcloth")
	_col_box(Vector3((tx0 + tx1) * 0.5, (FLOOR_Y + th) * 0.5, (tz0 + tz1) * 0.5), Vector3(tx1 - tx0, th - FLOOR_Y, tz1 - tz0))
	interactables["table"] = Interactable.make(self, "table", {"ru": "Стол", "en": "Table"}, Vector3(0.9, 0.12, 1.4), Vector3((tx0 + tx1) * 0.5, th + 0.05, (tz0 + tz1) * 0.5))
	# stools
	for sp in [Vector3(-1.62, 0, 0.05), Vector3(-2.45, 0, 1.15)]:
		var sh := FLOOR_Y + 0.46
		for lx in [-0.13, 0.13]:
			for lz in [-0.13, 0.13]:
				f.box_mm("wood", Vector3(sp.x + lx - 0.022, FLOOR_Y, sp.z + lz - 0.022), Vector3(sp.x + lx + 0.022, sh - 0.03, sp.z + lz + 0.022), Color(0.4, 0.29, 0.2))
		f.box_mm("wood", Vector3(sp.x - 0.18, sh - 0.035, sp.z - 0.18), Vector3(sp.x + 0.18, sh, sp.z + 0.18), Color(0.48, 0.35, 0.24))
		_col_box(Vector3(sp.x, FLOOR_Y + 0.23, sp.z), Vector3(0.36, 0.46, 0.36))
	# --- writing desk under the south window: the radio post ---
	var dx0 := -2.2
	var dx1 := -0.8
	var dz0 := 1.95
	var dz1 := HZ - LR - 0.02
	var dh := FLOOR_Y + 0.76
	for lx in [dx0 + 0.04, dx1 - 0.04]:
		for lz in [dz0 + 0.04, dz1 - 0.04]:
			f.box_mm("wood", Vector3(lx - 0.025, FLOOR_Y, lz - 0.025), Vector3(lx + 0.025, dh, lz + 0.025), Color(0.3, 0.2, 0.14))
	f.box_mm("wood", Vector3(dx0, dh - 0.03, dz0), Vector3(dx1, dh, dz1), Color(0.35, 0.24, 0.16))
	f.box_mm("wood", Vector3(dx0 + 0.05, dh - 0.18, dz0), Vector3(dx0 + 0.55, dh - 0.03, dz0 + 0.02), Color(0.33, 0.22, 0.15))
	f.cyl("chrome", Vector3(dx0 + 0.3, dh - 0.105, dz0 - 0.005), Vector3(dx0 + 0.3, dh - 0.105, dz0 - 0.02), 0.012, Color(0.7, 0.6, 0.4), 6)
	_col_box(Vector3((dx0 + dx1) * 0.5, (FLOOR_Y + dh) * 0.5, (dz0 + dz1) * 0.5), Vector3(dx1 - dx0, dh - FLOOR_Y, dz1 - dz0))
	_build_radio(Vector3(-1.25, dh, 2.2))
	# chair at the desk
	var chx := -1.4
	var chz := 1.55
	var seat := FLOOR_Y + 0.45
	for lx in [-0.17, 0.17]:
		for lz in [-0.17, 0.17]:
			f.box_mm("wood", Vector3(chx + lx - 0.02, FLOOR_Y, chz + lz - 0.02), Vector3(chx + lx + 0.02, seat, chz + lz + 0.02), Color(0.32, 0.22, 0.15))
	f.box_mm("wood", Vector3(chx - 0.2, seat, chz - 0.2), Vector3(chx + 0.2, seat + 0.03, chz + 0.2), Color(0.36, 0.25, 0.17))
	for lx in [-0.17, 0.17]:
		f.box_mm("wood", Vector3(chx + lx - 0.02, seat, chz - 0.2), Vector3(chx + lx + 0.02, seat + 0.5, chz - 0.16), Color(0.32, 0.22, 0.15))
	f.box_mm("wood", Vector3(chx - 0.2, seat + 0.32, chz - 0.2), Vector3(chx + 0.2, seat + 0.48, chz - 0.17), Color(0.36, 0.25, 0.17))
	_col_box(Vector3(chx, FLOOR_Y + 0.4, chz), Vector3(0.4, 0.8, 0.4))
	# --- bench by the door with the water bucket ---
	var bnx0 := -0.35
	var bnx1 := 1.15
	var bnz := HZ - LR - 0.2
	f.box_mm("wood", Vector3(bnx0, FLOOR_Y + 0.42, bnz - 0.17), Vector3(bnx1, FLOOR_Y + 0.46, bnz + 0.17), Color(0.47, 0.34, 0.23))
	for lx in [bnx0 + 0.1, bnx1 - 0.1]:
		f.box_mm("wood", Vector3(lx - 0.03, FLOOR_Y, bnz - 0.14), Vector3(lx + 0.03, FLOOR_Y + 0.42, bnz + 0.14), Color(0.4, 0.29, 0.2))
	_col_box(Vector3((bnx0 + bnx1) * 0.5, FLOOR_Y + 0.23, bnz), Vector3(bnx1 - bnx0, 0.46, 0.34))
	var bucket := Transform3D(Basis(), Vector3(0.75, FLOOR_Y + 0.46, bnz))
	f.lathe("metal", bucket, [Vector2(0, 0), Vector2(0.12, 0), Vector2(0.15, 0.3), Vector2(0.14, 0.3), Vector2(0.11, 0.01), Vector2(0, 0.01)], Color(0.55, 0.57, 0.58), 16)
	f.lathe("ice", bucket, [Vector2(0, 0.25), Vector2(0.142, 0.25)], Color(0.35, 0.42, 0.45), 16)
	f.torus("metal", bucket.origin + Vector3(0, 0.3, 0), 0.15, 0.006, Color(0.3, 0.3, 0.3), 16, 4, Basis(Vector3.RIGHT, PI * 0.5), PI)
	f.cyl("metal", Vector3(0.75, FLOOR_Y + 0.75, bnz), Vector3(0.95, FLOOR_Y + 0.9, bnz), 0.012, Color(0.6, 0.6, 0.6), 6)
	f.lathe("metal", Transform3D(Basis(), Vector3(0.75, FLOOR_Y + 0.72, bnz)), [Vector2(0, 0), Vector2(0.05, 0.0), Vector2(0.055, 0.06), Vector2(0, 0.06)], Color(0.6, 0.6, 0.6), 10)
	# enamel mugs on the bench
	f.lathe("ceramic", Transform3D(Basis(), Vector3(0.2, FLOOR_Y + 0.46, bnz + 0.05)), [Vector2(0, 0), Vector2(0.04, 0), Vector2(0.042, 0.09), Vector2(0.036, 0.09), Vector2(0.034, 0.01), Vector2(0, 0.01)], Color(0.9, 0.9, 0.88), 12)
	# --- runner rug from the door ---
	var rk := MeshKit.new()
	var rz := 2.3
	var stripes := [Color(0.62, 0.18, 0.15), Color(0.85, 0.8, 0.68), Color(0.2, 0.32, 0.45), Color(0.85, 0.8, 0.68), Color(0.4, 0.5, 0.35)]
	var z := rz
	var i := 0
	while z > -0.5:
		var c: Color = stripes[i % stripes.size()]
		var w := 0.06 + (i % 3) * 0.04
		rk.box_mm("fabric", Vector3(0.95, FLOOR_Y + 0.001, z - w), Vector3(1.75, FLOOR_Y + 0.008, z), c)
		z -= w
		i += 1
	rk.build(self, "Rug", false)
	# --- coat hooks on the east wall by the door ---
	var hx := HX - LR - 0.03
	f.box_mm("wood", Vector3(hx - 0.03, 1.85, 1.2), Vector3(hx, 1.95, 2.3), Color(0.38, 0.27, 0.19))
	for hz in [1.4, 1.75, 2.1]:
		f.cyl("wood", Vector3(hx, 1.9, hz), Vector3(hx - 0.12, 1.95, hz), 0.015, Color(0.35, 0.25, 0.17), 6)
	# hanging telogreika and ushanka
	f.box("quilt", Transform3D(Basis(Vector3.BACK, 0.04), Vector3(hx - 0.1, 1.48, 1.75)), Vector3(0.14, 0.82, 0.55), Color(0.16, 0.17, 0.17))
	f.sphere("fabric", Vector3(hx - 0.13, 1.88, 2.1), Vector3(0.12, 0.09, 0.12), Color(0.33, 0.27, 0.21), 6, 10)
	f.box_mm("fabric", Vector3(hx - 0.18, 1.78, 2.0), Vector3(hx - 0.14, 1.9, 2.2), Color(0.3, 0.24, 0.19))
	# valenki standing below
	for vz in [1.55, 1.75]:
		f.cyl("fabric", Vector3(hx - 0.2, FLOOR_Y, vz), Vector3(hx - 0.2, FLOOR_Y + 0.42, vz), 0.06, Color(0.22, 0.2, 0.2), 10)
		f.sphere("fabric", Vector3(hx - 0.28, FLOOR_Y + 0.05, vz), Vector3(0.11, 0.05, 0.06), Color(0.22, 0.2, 0.2), 4, 8)
	# --- wall shelf above the bench with books and jars ---
	var shz := HZ - LR - 0.12
	f.box_mm("wood", Vector3(-0.4, 2.05, shz - 0.1), Vector3(1.15, 2.08, shz + 0.12), Color(0.42, 0.3, 0.2))
	var bxp := -0.35
	var book_cols := [Color(0.5, 0.15, 0.12), Color(0.2, 0.28, 0.2), Color(0.55, 0.45, 0.3), Color(0.18, 0.2, 0.32), Color(0.4, 0.35, 0.3), Color(0.6, 0.55, 0.45)]
	for b in 9:
		var bw := _rng.randf_range(0.03, 0.06)
		var bh := _rng.randf_range(0.17, 0.25)
		f.box_mm("plain", Vector3(bxp, 2.08, shz - 0.08), Vector3(bxp + bw, 2.08 + bh, shz + 0.08), book_cols[b % book_cols.size()])
		bxp += bw + 0.004
	f.lathe("glass_clear", Transform3D(Basis(), Vector3(0.55, 2.08, shz)), [Vector2(0, 0), Vector2(0.06, 0), Vector2(0.06, 0.14), Vector2(0.04, 0.17), Vector2(0, 0.17)], Color(0.7, 0.8, 0.7), 12)
	f.lathe("plain", Transform3D(Basis(), Vector3(0.55, 2.08, shz)), [Vector2(0, 0.0), Vector2(0.055, 0.0), Vector2(0.055, 0.1), Vector2(0, 0.1)], Color(0.55, 0.15, 0.1), 12)
	f.lathe("glass_clear", Transform3D(Basis(), Vector3(0.75, 2.08, shz)), [Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0.12), Vector2(0.035, 0.15), Vector2(0, 0.15)], Color(0.8, 0.85, 0.75), 12)
	f.lathe("plain", Transform3D(Basis(), Vector3(0.75, 2.08, shz)), [Vector2(0, 0.0), Vector2(0.045, 0.0), Vector2(0.045, 0.08), Vector2(0, 0.08)], Color(0.75, 0.6, 0.25), 12)
	_build_receiver(Vector3(0.98, 2.08, shz))
	# a cloth bag of sunflower seeds on the bench (Galya packed it)
	seeds_node = Node3D.new()
	seeds_node.position = Vector3(0.4, FLOOR_Y + 0.46, bnz)
	add_child(seeds_node)
	var sk := MeshKit.new()
	sk.sphere("fabric", Vector3(0, 0.09, 0), Vector3(0.11, 0.1, 0.09), Color(0.72, 0.64, 0.5), 6, 10)
	sk.cyl("fabric", Vector3(0, 0.17, 0), Vector3(0, 0.23, 0), 0.035, Color(0.72, 0.64, 0.5), 8, true, 0.05)
	sk.torus("plain", Vector3(0, 0.18, 0), 0.04, 0.006, Color(0.6, 0.15, 0.1), 10, 4)
	sk.build(seeds_node, "Bag")
	seeds_node.visible = false
	interactables["seeds"] = Interactable.make(self, "seeds", {"ru": "Мешочек семечек", "en": "Bag of seeds"}, Vector3(0.3, 0.3, 0.3), seeds_node.position + Vector3(0, 0.12, 0))
	interactables["drawer"] = Interactable.make(self, "drawer", {"ru": "Ящик стола", "en": "Desk drawer"}, Vector3(0.55, 0.18, 0.12), Vector3(-1.9, FLOOR_Y + 0.66, 1.93))
	# grandfather's logbook
	interactables["logbook"] = Interactable.make(self, "logbook", {"ru": "Журнал лесника", "en": "Forester's logbook"}, Vector3(0.45, 0.3, 0.25), Vector3(-0.15, 2.2, shz))


func _build_radio(p: Vector3) -> void:
	# Base-station transceiver: a grey-green steel box with a big tuning dial.
	var k := MeshKit.new()
	var body := Color(0.3, 0.36, 0.32)
	k.box_mm("metal_rough", p + Vector3(-0.25, 0, -0.15), p + Vector3(0.25, 0.22, 0.15), body)
	k.box_mm("metal_rough", p + Vector3(-0.26, 0.2, -0.16), p + Vector3(0.26, 0.23, 0.16), body * 0.85)
	# front panel faces -z (into the room)
	var fz := p.z - 0.152
	k.box_mm("plain", Vector3(p.x - 0.22, p.y + 0.03, fz - 0.004), Vector3(p.x + 0.22, p.y + 0.19, fz), Color(0.12, 0.13, 0.12))
	k.box_mm("unshaded", Vector3(p.x - 0.2, p.y + 0.12, fz - 0.006), Vector3(p.x + 0.02, p.y + 0.17, fz - 0.004), Color(0.75, 0.62, 0.35))
	k.box_mm("plain", Vector3(p.x - 0.12, p.y + 0.12, fz - 0.007), Vector3(p.x - 0.115, p.y + 0.17, fz - 0.006), Color(0.6, 0.1, 0.05))
	for kx in [0.08, 0.15]:
		k.cyl("plain", Vector3(p.x + kx, p.y + 0.14, fz), Vector3(p.x + kx, p.y + 0.14, fz - 0.03), 0.022, Color(0.08, 0.08, 0.08), 12)
	for kx in [-0.15, -0.06, 0.03]:
		k.cyl("chrome", Vector3(p.x + kx, p.y + 0.06, fz), Vector3(p.x + kx, p.y + 0.06, fz - 0.02), 0.008, Color(0.7, 0.7, 0.7), 8)
	# grille
	for g in 6:
		k.box_mm("plain", Vector3(p.x + 0.04, p.y + 0.04 + g * 0.012, fz - 0.005), Vector3(p.x + 0.2, p.y + 0.045 + g * 0.012, fz - 0.004), Color(0.05, 0.05, 0.05))
	# antenna lead going up the wall
	k.cyl("plain", p + Vector3(0.2, 0.22, 0.1), p + Vector3(0.25, 1.1, 0.2), 0.004, Color(0.1, 0.1, 0.1), 4)
	# handset on its cradle
	k.box_mm("plain", p + Vector3(-0.22, 0.23, -0.06), p + Vector3(-0.05, 0.25, 0.05), Color(0.08, 0.08, 0.08))
	k.cyl("plain", p + Vector3(-0.21, 0.27, -0.02), p + Vector3(-0.06, 0.27, -0.02), 0.018, Color(0.07, 0.07, 0.07), 8)
	k.sphere("plain", p + Vector3(-0.21, 0.27, -0.02), Vector3(0.03, 0.025, 0.03), Color(0.07, 0.07, 0.07), 5, 8)
	k.sphere("plain", p + Vector3(-0.06, 0.27, -0.02), Vector3(0.03, 0.025, 0.03), Color(0.07, 0.07, 0.07), 5, 8)
	# battery box under the desk
	k.box_mm("plain", Vector3(p.x - 0.15, FLOOR_Y, p.z - 0.1), Vector3(p.x + 0.15, FLOOR_Y + 0.22, p.z + 0.15), Color(0.1, 0.1, 0.1))
	k.cyl("plain", p + Vector3(0.0, -0.1, 0.1), Vector3(p.x, FLOOR_Y + 0.22, p.z + 0.05), 0.006, Color(0.5, 0.1, 0.05), 4)
	# station log and a pencil
	k.box_mm("plain", p + Vector3(-0.68, 0.0, -0.1), p + Vector3(-0.38, 0.015, 0.12), Color(0.25, 0.3, 0.4))
	k.box_mm("plain", p + Vector3(-0.66, 0.015, -0.08), p + Vector3(-0.4, 0.018, 0.1), Color(0.9, 0.88, 0.8))
	k.cyl("plain", p + Vector3(-0.35, 0.008, -0.05), p + Vector3(-0.3, 0.008, 0.1), 0.004, Color(0.75, 0.25, 0.15), 6)
	k.build(self, "Radio")
	radio_lamp = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	radio_lamp_mat = StandardMaterial3D.new()
	radio_lamp_mat.albedo_color = Color(0.3, 0.05, 0.03)
	radio_lamp_mat.emission_enabled = true
	radio_lamp_mat.emission = Color(1.0, 0.15, 0.05)
	radio_lamp_mat.emission_energy_multiplier = 0.0
	sm.material = radio_lamp_mat
	radio_lamp.mesh = sm
	radio_lamp.position = Vector3(p.x - 0.18, p.y + 0.07, fz - 0.005)
	add_child(radio_lamp)
	interactables["radio"] = Interactable.make(self, "radio", {"ru": "Рация", "en": "Radio set"}, Vector3(0.6, 0.35, 0.4), p + Vector3(0, 0.15, 0))
	interactables["station_log"] = Interactable.make(self, "station_log", {"ru": "Журнал связи", "en": "Radio log"}, Vector3(0.32, 0.08, 0.25), p + Vector3(-0.53, 0.03, 0.01))
	# calendar and district map on the wall
	var wz := HZ - LR - 0.015
	var ck := MeshKit.new()
	ck.quad("plain", Vector3(-0.5, 1.45, wz), Vector3(-0.78, 1.45, wz), Vector3(-0.78, 1.85, wz), Vector3(-0.5, 1.85, wz), Color(0.93, 0.9, 0.84))
	ck.quad("plain", Vector3(-0.5, 1.85, wz), Vector3(-0.78, 1.85, wz), Vector3(-0.78, 2.0, wz), Vector3(-0.5, 2.0, wz), Color(0.7, 0.15, 0.12))
	# district map above the desk, beside the window
	ck.quad("plain", Vector3(-2.25, 1.3, wz), Vector3(-2.95, 1.3, wz), Vector3(-2.95, 1.85, wz), Vector3(-2.25, 1.85, wz), Color(0.86, 0.84, 0.72))
	ck.build(self, "WallPapers", false)
	var cal := Label3D.new()
	cal.text = "1991\nДЕКАБРЬ\n\nпн вт ср чт пт сб вс\n                   1\n 2  3  4  5  6  7  8\n 9 10 11 12 13 14 15\n16 17 18 19 20 21 22\n23 24 25 26 27 28 29\n30 31"
	cal.font = UITheme.font_mono()
	cal.font_size = 18
	cal.pixel_size = 0.00062
	cal.modulate = Color(0.15, 0.13, 0.12)
	cal.outline_size = 0
	cal.shaded = true
	cal.position = Vector3(-0.64, 1.72, wz - 0.004)
	cal.rotation.y = PI
	cal.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(cal)
	var cal_top := Label3D.new()
	cal_top.text = "СССР"
	cal_top.font = UITheme.font_serif_bold()
	cal_top.font_size = 40
	cal_top.pixel_size = 0.0012
	cal_top.modulate = Color(0.95, 0.9, 0.8)
	cal_top.outline_size = 0
	cal_top.position = Vector3(-0.64, 1.925, wz - 0.004)
	cal_top.rotation.y = PI
	cal_top.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(cal_top)
	var mp := Label3D.new()
	mp.text = "ТАЛДОМСКИЙ ЛЕСХОЗ\nкв. 41–48 · кордон «101 км»"
	mp.font = UITheme.font_serif()
	mp.font_size = 20
	mp.pixel_size = 0.0008
	mp.modulate = Color(0.25, 0.2, 0.15)
	mp.outline_size = 0
	mp.position = Vector3(-2.6, 1.78, wz - 0.004)
	mp.rotation.y = PI
	mp.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(mp)
	var mapk := MeshKit.new()
	var mr := RandomNumberGenerator.new()
	mr.seed = 4
	for l in 12:
		var a := Vector3(mr.randf_range(-2.9, -2.3), mr.randf_range(1.35, 1.72), wz - 0.003)
		var b := a + Vector3(mr.randf_range(-0.15, 0.15), mr.randf_range(-0.1, 0.1), 0)
		mapk.cyl("unshaded", a, b, 0.0025, Color(0.3, 0.45, 0.3) if l < 8 else Color(0.25, 0.35, 0.6), 3, false)
	mapk.cyl("unshaded", Vector3(-2.95, 1.4, wz - 0.003), Vector3(-2.25, 1.43, wz - 0.003), 0.003, Color(0.1, 0.1, 0.1), 3, false)
	mapk.sphere("unshaded", Vector3(-2.55, 1.6, wz - 0.004), Vector3(0.01, 0.01, 0.002), Color(0.8, 0.1, 0.1), 3, 6)
	mapk.build(self, "MapLines", false)
	interactables["calendar"] = Interactable.make(self, "calendar", {"ru": "Календарь", "en": "Calendar"}, Vector3(0.32, 0.6, 0.08), Vector3(-0.64, 1.72, wz - 0.03))
	interactables["map"] = Interactable.make(self, "map", {"ru": "Карта лесничества", "en": "Forestry map"}, Vector3(0.7, 0.56, 0.08), Vector3(-2.6, 1.57, wz - 0.03))


func _build_receiver(p: Vector3) -> void:
	# Household radio receiver, a VEF-style transistor set.
	var k := MeshKit.new()
	k.box_mm("gloss", p + Vector3(-0.14, 0, -0.05), p + Vector3(0.14, 0.17, 0.05), Color(0.55, 0.15, 0.1))
	k.box_mm("plain", p + Vector3(-0.13, 0.02, -0.052), p + Vector3(0.0, 0.15, -0.05), Color(0.75, 0.72, 0.65))
	for g in 9:
		k.box_mm("plain", p + Vector3(-0.125, 0.03 + g * 0.013, -0.054), p + Vector3(-0.005, 0.034 + g * 0.013, -0.052), Color(0.3, 0.28, 0.26))
	k.box_mm("unshaded", p + Vector3(0.02, 0.1, -0.053), p + Vector3(0.13, 0.14, -0.05), Color(0.82, 0.78, 0.6))
	k.cyl("chrome", p + Vector3(0.07, 0.05, -0.05), p + Vector3(0.07, 0.05, -0.07), 0.018, Color(0.8, 0.8, 0.8), 10)
	k.cyl("chrome", p + Vector3(0.12, 0.17, 0.0), p + Vector3(0.05, 0.6, 0.02), 0.003, Color(0.85, 0.85, 0.85), 4)
	k.cyl("plain", p + Vector3(-0.12, 0.17, 0), p + Vector3(-0.08, 0.2, 0), 0.006, Color(0.1, 0.1, 0.1), 4)
	k.cyl("plain", p + Vector3(0.12, 0.17, 0), p + Vector3(0.08, 0.2, 0), 0.006, Color(0.1, 0.1, 0.1), 4)
	k.cyl("plain", p + Vector3(-0.08, 0.2, 0), p + Vector3(0.08, 0.2, 0), 0.006, Color(0.1, 0.1, 0.1), 4)
	k.build(self, "Receiver")
	var lamp := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.035, 0.002)
	receiver_lamp_mat = StandardMaterial3D.new()
	receiver_lamp_mat.albedo_color = Color(0.82, 0.78, 0.6)
	receiver_lamp_mat.emission_enabled = true
	receiver_lamp_mat.emission = Color(1.0, 0.75, 0.35)
	receiver_lamp_mat.emission_energy_multiplier = 0.0
	bm.material = receiver_lamp_mat
	lamp.mesh = bm
	lamp.position = p + Vector3(0.075, 0.12, -0.055)
	add_child(lamp)
	interactables["receiver"] = Interactable.make(self, "receiver", {"ru": "Радиоприёмник", "en": "Radio receiver"}, Vector3(0.34, 0.25, 0.2), p + Vector3(0, 0.09, -0.02))


func set_radio_lamp(on: bool) -> void:
	radio_lamp_mat.emission_energy_multiplier = 4.0 if on else 0.0


func set_receiver_on(on: bool) -> void:
	receiver_lamp_mat.emission_energy_multiplier = 1.8 if on else 0.0


func _build_details() -> void:
	var th := FLOOR_Y + 0.76
	# --- kerosene lamp on the table ---
	var lp := Vector3(-2.75, th, -0.42)
	var lk := MeshKit.new()
	lk.lathe("glass_clear", Transform3D(Basis(), lp), [Vector2(0, 0), Vector2(0.07, 0.0), Vector2(0.075, 0.02), Vector2(0.06, 0.04), Vector2(0.085, 0.1), Vector2(0.05, 0.15), Vector2(0.0, 0.15)], Color(0.6, 0.75, 0.6), 16)
	lk.lathe("metal", Transform3D(Basis(), lp + Vector3(0, 0.15, 0)), [Vector2(0, 0), Vector2(0.045, 0), Vector2(0.05, 0.03), Vector2(0.035, 0.04), Vector2(0, 0.04)], Color(0.7, 0.55, 0.3), 14)
	lk.lathe("glass_clear", Transform3D(Basis(), lp + Vector3(0, 0.19, 0)), [Vector2(0.032, 0), Vector2(0.045, 0.05), Vector2(0.045, 0.08), Vector2(0.025, 0.2), Vector2(0.025, 0.24)], Color(0.95, 0.95, 0.92), 16)
	lk.build(self, "KeroseneLamp")
	lamp_flame = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.012
	fm.height = 0.05
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.75, 0.35)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.6, 0.25)
	fmat.emission_energy_multiplier = 6.0
	fm.material = fmat
	lamp_flame.mesh = fm
	lamp_flame.position = lp + Vector3(0, 0.235, 0)
	lamp_flame.visible = false
	add_child(lamp_flame)
	lamp_light = OmniLight3D.new()
	lamp_light.light_color = Color(1.0, 0.72, 0.42)
	lamp_light.light_energy = 1.25
	lamp_light.omni_range = 7.0
	lamp_light.omni_attenuation = 1.3
	lamp_light.shadow_enabled = true
	lamp_light.shadow_bias = 0.04
	lamp_light.light_size = 0.05
	lamp_light.position = lp + Vector3(0, 0.3, 0)
	lamp_light.visible = false
	add_child(lamp_light)
	interactables["lamp"] = Interactable.make(self, "lamp", {"ru": "Керосиновая лампа", "en": "Kerosene lamp"}, Vector3(0.22, 0.45, 0.22), lp + Vector3(0, 0.2, 0))

	# --- coffee things: tin of Indian instant coffee, glass in a podstakannik ---
	var tin_p := Vector3(-2.38, th, -0.1)
	var tk := MeshKit.new()
	tk.lathe("gloss", Transform3D(Basis(), tin_p), [Vector2(0, 0), Vector2(0.045, 0), Vector2(0.045, 0.11), Vector2(0.0, 0.11)], Color(0.85, 0.62, 0.15), 16)
	tk.lathe("gloss", Transform3D(Basis(), tin_p + Vector3(0, 0.035, 0)), [Vector2(0.0455, 0), Vector2(0.0455, 0.04)], Color(0.55, 0.12, 0.08), 16)
	tk.lathe("chrome", Transform3D(Basis(), tin_p + Vector3(0, 0.11, 0)), [Vector2(0, 0.0), Vector2(0.047, 0.0), Vector2(0.047, 0.012), Vector2(0, 0.012)], Color(0.75, 0.72, 0.6), 16)
	# sugar in a glass jar, a spoon, a folded newspaper
	tk.lathe("glass_clear", Transform3D(Basis(), Vector3(-2.6, th, -0.05)), [Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0.1), Vector2(0, 0.1)], Color(0.85, 0.9, 0.85), 12)
	tk.lathe("plain", Transform3D(Basis(), Vector3(-2.6, th, -0.05)), [Vector2(0, 0.0), Vector2(0.047, 0.0), Vector2(0.047, 0.06), Vector2(0, 0.06)], Color(0.95, 0.95, 0.93), 12)
	tk.box("plain", Transform3D(Basis(Vector3.UP, 0.3), Vector3(-2.35, th + 0.006, 0.45)), Vector3(0.32, 0.012, 0.42), Color(0.86, 0.84, 0.78))
	tk.build(self, "CoffeeThings")
	var paper := Label3D.new()
	paper.text = "ВЕЧЕРНЯЯ МОСКВА"
	paper.font = UITheme.font_serif_bold()
	paper.font_size = 32
	paper.pixel_size = 0.0007
	paper.modulate = Color(0.12, 0.1, 0.1)
	paper.outline_size = 0
	paper.position = Vector3(-2.35, th + 0.013, 0.37)
	paper.rotation = Vector3(-PI * 0.5, 0.3 + PI * 0.5, 0)
	paper.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(paper)
	interactables["coffee_tin"] = Interactable.make(self, "coffee_tin", {"ru": "Банка кофе", "en": "Tin of coffee"}, Vector3(0.14, 0.16, 0.14), tin_p + Vector3(0, 0.06, 0))
	interactables["newspaper"] = Interactable.make(self, "newspaper", {"ru": "Газета", "en": "Newspaper"}, Vector3(0.35, 0.05, 0.4), Vector3(-2.35, th + 0.02, 0.45))

	cup = make_cup()
	cup.position = Vector3(-2.3, th, 0.12)
	add_child(cup)
	interactables["cup"] = Interactable.make(self, "cup", {"ru": "Стакан в подстаканнике", "en": "Glass in a tea-glass holder"}, Vector3(0.14, 0.18, 0.14), cup.position + Vector3(0, 0.07, 0))

	# --- photo of Kostya on the windowsill ---
	var ph_p := Vector3(-HX + LR + 0.13, WIN_W.z - 0.01, 0.32)
	var pk := MeshKit.new()
	pk.box("wood", Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.25) * Basis(Vector3.RIGHT, -0.15), ph_p + Vector3(0, 0.09, 0)), Vector3(0.14, 0.18, 0.012), Color(0.3, 0.2, 0.12))
	pk.box("plain", Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.25) * Basis(Vector3.RIGHT, -0.15), ph_p + Vector3(0.008, 0.09, 0.002)), Vector3(0.11, 0.15, 0.004), Color(0.62, 0.58, 0.5))
	pk.build(self, "Photo")
	interactables["photo"] = Interactable.make(self, "photo", {"ru": "Фотография", "en": "Photograph"}, Vector3(0.16, 0.22, 0.16), ph_p + Vector3(0, 0.09, 0))

	# --- wall clock (khodiki) between window and door, with pendulum ---
	var cp := Vector3(0.3, 2.35, HZ - LR - 0.03)
	var k := MeshKit.new()
	k.box_mm("wood", cp + Vector3(-0.11, -0.12, -0.04), cp + Vector3(0.11, 0.12, 0.0), Color(0.4, 0.26, 0.15))
	k.box_mm("paint", cp + Vector3(-0.09, -0.1, -0.042), cp + Vector3(0.09, 0.08, -0.04), Color(0.88, 0.84, 0.72))
	k.box("wood", Transform3D(Basis(Vector3.BACK, PI * 0.25), cp + Vector3(0, 0.12, -0.02)), Vector3(0.16, 0.16, 0.04), Color(0.4, 0.26, 0.15))
	k.cyl("plain", cp + Vector3(0, -0.01, -0.045), cp + Vector3(0.0, 0.05, -0.046), 0.003, Color(0.1, 0.1, 0.1), 3)
	k.cyl("plain", cp + Vector3(0, -0.01, -0.045), cp + Vector3(0.04, -0.03, -0.046), 0.003, Color(0.1, 0.1, 0.1), 3)
	# weights on chains
	for wx in [-0.04, 0.04]:
		k.cyl("metal", cp + Vector3(wx, -0.12, -0.02), cp + Vector3(wx, -0.62 + absf(wx) * 3.0, -0.02), 0.002, Color(0.3, 0.3, 0.3), 3)
		k.cyl("metal", cp + Vector3(wx, -0.62 + absf(wx) * 3.0, -0.02), cp + Vector3(wx, -0.76 + absf(wx) * 3.0, -0.02), 0.018, Color(0.25, 0.25, 0.23), 8)
	k.build(self, "Clock")
	pendulum = Node3D.new()
	pendulum.position = cp + Vector3(0, -0.12, -0.035)
	add_child(pendulum)
	var pk2 := MeshKit.new()
	pk2.cyl("chrome", Vector3.ZERO, Vector3(0, -0.4, 0), 0.003, Color(0.7, 0.6, 0.35), 4)
	pk2.cyl("chrome", Vector3(0, -0.4, 0.005), Vector3(0, -0.4, -0.005), 0.03, Color(0.8, 0.68, 0.4), 12)
	pk2.build(pendulum, "Pendulum")
	interactables["clock"] = Interactable.make(self, "clock", {"ru": "Часы-ходики", "en": "Wall clock"}, Vector3(0.3, 0.4, 0.1), cp)

	# --- dried herbs hanging from the beam ---
	var hk := MeshKit.new()
	for i in 3:
		var hp := Vector3(-1.4 + i * 0.25, CEIL_Y - 0.2, 0.0)
		hk.cyl("plain", hp, hp - Vector3(0, 0.15, 0), 0.003, Color(0.5, 0.45, 0.35), 3)
		hk.cyl("plain", hp - Vector3(0, 0.15, 0), hp - Vector3(0, 0.45, 0), 0.06, Color(0.42, 0.45, 0.28), 6, true, 0.02)
	hk.build(self, "Herbs")

	# --- the letter: appears on the table in the last chapter ---
	letter_node = Node3D.new()
	letter_node.position = Vector3(-2.5, th + 0.004, 0.15)
	letter_node.rotation.y = 0.4
	add_child(letter_node)
	var lek := MeshKit.new()
	lek.box("plain", Transform3D(), Vector3(0.11, 0.004, 0.16), Color(0.82, 0.78, 0.68))
	lek.tri("plain", Vector3(-0.055, 0.0025, -0.08), Vector3(0.055, 0.0025, -0.08), Vector3(0, 0.0025, -0.02), Color(0.75, 0.7, 0.6))
	lek.box("plain", Transform3D(Basis(), Vector3(0.025, 0.003, 0.05)), Vector3(0.03, 0.002, 0.035), Color(0.5, 0.2, 0.15))
	lek.build(letter_node, "Envelope")
	letter_node.visible = false
	interactables["letter"] = Interactable.make(self, "letter", {"ru": "Письмо Кости", "en": "Kostya's letter"}, Vector3(0.2, 0.1, 0.24), letter_node.position + Vector3(0, 0.03, 0))
	interactables["letter"].enabled = false

	interactables["window_s"] = Interactable.make(self, "window", {"ru": "Окно", "en": "Window"}, Vector3(1.0, 0.9, 0.1), Vector3((WIN_S.x + WIN_S.y) * 0.5, 1.8, HZ - LR - 0.12))


static func make_cup() -> Node3D:
	# Faceted tea glass in a filigree metal podstakannik.
	var root := Node3D.new()
	root.name = "Cup"
	var k := MeshKit.new()
	k.lathe("chrome", Transform3D(), [Vector2(0, 0), Vector2(0.036, 0), Vector2(0.038, 0.01), Vector2(0.033, 0.016), Vector2(0.036, 0.075), Vector2(0.034, 0.078), Vector2(0.031, 0.02), Vector2(0, 0.02)], Color(0.78, 0.7, 0.55), 18)
	# filigree openings
	for i in 6:
		var a := TAU * i / 6.0
		k.sphere("plain", Vector3(cos(a) * 0.0355, 0.048, sin(a) * 0.0355), Vector3(0.006, 0.016, 0.006), Color(0.12, 0.1, 0.08), 3, 5)
	# handle
	k.torus("chrome", Vector3(0.05, 0.045, 0), 0.022, 0.0045, Color(0.78, 0.7, 0.55), 12, 5, Basis(Vector3.RIGHT, PI * 0.5), PI * 1.2)
	k.lathe("glass_clear", Transform3D(Basis(), Vector3(0, 0.012, 0)), [Vector2(0, 0), Vector2(0.029, 0.0), Vector2(0.034, 0.1), Vector2(0.032, 0.1), Vector2(0.027, 0.004), Vector2(0, 0.004)], Color(0.9, 0.95, 0.95), 14, false)
	var mi := k.build(root, "CupMesh")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var liquid := MeshInstance3D.new()
	liquid.name = "Liquid"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.031
	cm.bottom_radius = 0.028
	cm.height = 0.07
	cm.radial_segments = 14
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.12, 0.06, 0.03)
	lm.roughness = 0.08
	lm.metallic_specular = 0.8
	cm.material = lm
	liquid.mesh = cm
	liquid.position = Vector3(0, 0.05, 0)
	liquid.visible = false
	root.add_child(liquid)
	var steam := GPUParticles3D.new()
	steam.name = "Steam"
	steam.amount = 14
	steam.lifetime = 2.2
	steam.position = Vector3(0, 0.11, 0)
	steam.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.02
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.1
	pm.gravity = Vector3(0.01, 0.04, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 1.0
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.2, Color(1, 1, 1, 0.18))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	steam.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.08)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = World._soft_dot()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = sm
	steam.draw_pass_1 = q
	steam.emitting = false
	root.add_child(steam)
	return root


func set_cup_full(full: bool) -> void:
	cup.get_node("Liquid").visible = full
	(cup.get_node("Steam") as GPUParticles3D).emitting = full


func _build_lights() -> void:
	# Interior probe: makes the inside of the house use its own (dim, warm)
	# ambient instead of the open sky.
	interior_probe = ReflectionProbe.new()
	interior_probe.name = "InteriorProbe"
	interior_probe.size = Vector3(HX * 2.0 - 0.2, CEIL_Y - FLOOR_Y + 0.4, HZ * 2.0 - 0.2)
	interior_probe.position = Vector3(0, (FLOOR_Y + CEIL_Y) * 0.5, 0)
	interior_probe.interior = true
	interior_probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	interior_probe.ambient_color = Color(0.16, 0.15, 0.17)
	interior_probe.ambient_color_energy = 0.45
	interior_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	interior_probe.box_projection = true
	interior_probe.max_distance = 8.0
	add_child(interior_probe)


func set_interior_ambient(color: Color, energy: float) -> void:
	interior_probe.ambient_color = color
	interior_probe.ambient_color_energy = energy
