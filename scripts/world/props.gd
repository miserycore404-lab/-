class_name Props
extends Node3D
## Outdoor set dressing: railway & platform, yard, well, woodshed, fence,
## the bird feeder, Kostya's birch, and the forest floor clutter.

var _rng := RandomNumberGenerator.new()
var _body: StaticBody3D
var k: MeshKit
var feeder_seed: Node3D
var platform_light: OmniLight3D
var interactables := {}


func build() -> void:
	_rng.seed = 55
	_body = StaticBody3D.new()
	_body.name = "PropBodies"
	add_child(_body)
	k = MeshKit.new()
	_build_railway()
	_build_platform()
	_build_fence()
	_build_woodshed()
	_build_well()
	_build_feeder()
	_build_birch_of_kostya()
	_build_boat()
	_build_clutter()
	k.build(self, "Props")


func _col_box(center: Vector3, size: Vector3, rot_y := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = Transform3D(Basis(Vector3.UP, rot_y), center)
	_body.add_child(cs)


func _col_cyl(center: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = center
	_body.add_child(cs)


static func gy(x: float, z: float) -> float:
	return Layout.height(x, z)


# --- railway ---------------------------------------------------------------------------

func _build_railway() -> void:
	var z := Layout.RAIL_Z
	var y := Layout.RAIL_H + 0.9
	var x0 := -260.0
	var x1 := 260.0
	# ballast bed
	k.box_mm("plain", Vector3(x0, y - 0.35, z - 1.9), Vector3(x1, y - 0.05, z + 1.9), Color(0.42, 0.41, 0.4))
	k.box_mm("snow", Vector3(x0, y - 0.07, z - 2.2), Vector3(x1, y - 0.0, z - 1.0), Color.WHITE)
	k.box_mm("snow", Vector3(x0, y - 0.07, z + 1.0), Vector3(x1, y - 0.0, z + 2.2), Color.WHITE)
	# rails: Russian broad gauge, 1520 mm
	for side in [-0.76, 0.76]:
		k.box_mm("chrome", Vector3(x0, y + 0.1, z + side - 0.035), Vector3(x1, y + 0.17, z + side + 0.035), Color(0.55, 0.55, 0.56))
		k.box_mm("metal_rough", Vector3(x0, y, z + side - 0.06), Vector3(x1, y + 0.1, z + side + 0.06), Color(0.3, 0.22, 0.18))
	# sleepers via MultiMesh
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(0.25, 0.14, 2.75)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.22, 0.2, 0.18)
	sm.roughness = 0.95
	sleeper.material = sm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sleeper
	var n := int((x1 - x0) / 0.55)
	mm.instance_count = n
	for i in n:
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf_range(-0.02, 0.02)), Vector3(x0 + i * 0.55, y + 0.02, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	# snow drifted between the sleepers
	k.box_mm("snow", Vector3(x0, y + 0.05, z - 0.62), Vector3(x1, y + 0.1, z + 0.62), Color(0.95, 0.96, 1.0))
	# catenary: concrete masts with arms, contact wire and messenger wire
	var mast_z := z - 3.4
	var wire_y := y + 5.6
	var x := x0
	while x <= x1:
		var gy0 := gy(x, mast_z)
		k.cyl("plain", Vector3(x, gy0 - 0.5, mast_z), Vector3(x, wire_y + 1.4, mast_z), 0.16, Color(0.62, 0.62, 0.6), 8, true, 0.12)
		k.cyl("metal_rough", Vector3(x, wire_y + 1.0, mast_z), Vector3(x, wire_y + 0.5, z + 0.3), 0.04, Color(0.3, 0.3, 0.3), 6)
		k.cyl("metal_rough", Vector3(x, wire_y + 1.2, mast_z), Vector3(x, wire_y + 1.15, z + 0.3), 0.035, Color(0.3, 0.3, 0.3), 6)
		k.cyl("plain", Vector3(x, wire_y + 1.15, z + 0.2), Vector3(x, wire_y + 0.9, z + 0.2), 0.05, Color(0.5, 0.35, 0.25), 8)
		if absf(x - Layout.PLATFORM_MIN.x) < 120.0:
			_col_cyl(Vector3(x, gy0 + 3.0, mast_z), 0.18, 6.0)
		x += 55.0
	k.cyl("metal", Vector3(x0, wire_y, z), Vector3(x1, wire_y, z), 0.012, Color(0.25, 0.22, 0.2), 4, false)
	k.cyl("metal", Vector3(x0, wire_y + 1.1, z), Vector3(x1, wire_y + 1.1, z), 0.01, Color(0.25, 0.22, 0.2), 4, false)
	# kilometre post "101"
	var kp := Vector3(-3.5, 0, z - 2.6)
	kp.y = gy(kp.x, kp.z)
	k.box_mm("paint", kp + Vector3(-0.09, -0.3, -0.09), kp + Vector3(0.09, 1.2, 0.09), Color(0.9, 0.9, 0.88))
	k.box_mm("paint", kp + Vector3(-0.092, 0.0, -0.092), kp + Vector3(0.092, 0.12, 0.092), Color(0.08, 0.08, 0.08))
	k.box_mm("snow", kp + Vector3(-0.1, 1.2, -0.1), kp + Vector3(0.1, 1.24, 0.1), Color.WHITE)
	for face in [[Vector3(0, 0.8, 0.095), 0.0], [Vector3(0, 0.8, -0.095), PI]]:
		var l := Label3D.new()
		l.text = "101"
		l.font = UITheme.font_sans_bold()
		l.font_size = 64
		l.pixel_size = 0.0018
		l.modulate = Color(0.06, 0.06, 0.06)
		l.outline_size = 0
		l.shaded = true
		l.position = kp + face[0]
		l.rotation.y = face[1]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		add_child(l)
	_col_box(kp + Vector3(0, 0.5, 0), Vector3(0.2, 1.4, 0.2))
	interactables["km_post"] = Interactable.make(self, "km_post", {"ru": "Километровый столб", "en": "Kilometre post"}, Vector3(0.4, 1.4, 0.4), kp + Vector3(0, 0.6, 0))
	# boundary: block walking along the tracks out of the play area
	_col_box(Vector3(-52, 2, z), Vector3(1.0, 6.0, 12.0))
	_col_box(Vector3(30, 2, z), Vector3(1.0, 6.0, 12.0))
	# keep the player off the track bed itself (a low invisible kerb)
	_col_box(Vector3(-11, y + 0.6, z + 0.2), Vector3(82, 1.4, 3.0))


func _build_platform() -> void:
	var mn := Layout.PLATFORM_MIN
	var mx := Layout.PLATFORM_MAX
	var top := Layout.RAIL_H + 1.25
	# concrete slabs with a seam every 3 m
	var x := mn.x
	while x < mx.x:
		var v := _rng.randf_range(0.9, 1.05)
		k.box_mm("plain", Vector3(x + 0.01, top - 0.25, mn.y), Vector3(minf(x + 3.0, mx.x) - 0.01, top, mx.y), Color(0.55 * v, 0.55 * v, 0.53 * v))
		x += 3.0
	k.box_mm("plain", Vector3(mn.x, Layout.RAIL_H - 0.5, mn.y + 0.2), Vector3(mx.x, top - 0.25, mx.y), Color(0.45, 0.45, 0.43))
	k.box_mm("paint", Vector3(mn.x, top, mx.y - 0.25), Vector3(mx.x, top + 0.005, mx.y - 0.1), Color(0.9, 0.88, 0.7))
	k.box_mm("snow", Vector3(mn.x + 0.3, top, mn.y + 0.1), Vector3(mx.x - 0.3, top + 0.05, mn.y + 0.9), Color.WHITE)
	_col_box(Vector3((mn.x + mx.x) * 0.5, top - 0.5, (mn.y + mx.y) * 0.5), Vector3(mx.x - mn.x, 1.0, mx.y - mn.y))
	# ramp down at the east end toward the path
	var ramp_len := 3.5
	var ground_y := gy(mx.x + ramp_len, 87.0)
	var rise := top - ground_y
	var ang := atan2(rise, ramp_len)
	var basis := Basis(Vector3.BACK, ang)
	var center := Vector3(mx.x + ramp_len * 0.5, (top + ground_y) * 0.5 - 0.12, (mn.y + mx.y) * 0.5)
	k.box("plain", Transform3D(basis, center), Vector3(sqrt(rise * rise + ramp_len * ramp_len), 0.25, 2.2), Color(0.5, 0.5, 0.48))
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(sqrt(rise * rise + ramp_len * ramp_len), 0.25, 2.2)
	cs.shape = b
	cs.transform = Transform3D(basis, center)
	_body.add_child(cs)
	# west end ramp too
	var gw := gy(mn.x - ramp_len, 87.0)
	var rw := top - gw
	var bw := Basis(Vector3.BACK, -atan2(rw, ramp_len))
	var cw := Vector3(mn.x - ramp_len * 0.5, (top + gw) * 0.5 - 0.12, (mn.y + mx.y) * 0.5)
	k.box("plain", Transform3D(bw, cw), Vector3(sqrt(rw * rw + ramp_len * ramp_len), 0.25, 2.2), Color(0.5, 0.5, 0.48))
	var cs2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(sqrt(rw * rw + ramp_len * ramp_len), 0.25, 2.2)
	cs2.shape = b2
	cs2.transform = Transform3D(bw, cw)
	_body.add_child(cs2)
	# railing along the back edge
	var rx := mn.x
	while rx <= mx.x:
		k.cyl("metal", Vector3(rx, top, mn.y + 0.1), Vector3(rx, top + 1.0, mn.y + 0.1), 0.025, Color(0.35, 0.42, 0.38), 6)
		rx += 2.0
	k.cyl("metal", Vector3(mn.x, top + 1.0, mn.y + 0.1), Vector3(mx.x, top + 1.0, mn.y + 0.1), 0.03, Color(0.35, 0.42, 0.38), 6)
	k.cyl("snow", Vector3(mn.x, top + 1.04, mn.y + 0.1), Vector3(mx.x, top + 1.04, mn.y + 0.1), 0.035, Color.WHITE, 5)
	_col_box(Vector3((mn.x + mx.x) * 0.5, top + 0.5, mn.y + 0.1), Vector3(mx.x - mn.x, 1.0, 0.1))
	# shelter pavilion
	var px := -24.0
	var pz0 := mn.y + 0.15
	var pz1 := mn.y + 1.6
	k.box_mm("plain", Vector3(px - 2.0, top, pz0), Vector3(px + 2.0, top + 2.6, pz0 + 0.12), Color(0.6, 0.6, 0.58))
	k.box_mm("plain", Vector3(px - 2.0, top, pz0), Vector3(px - 1.88, top + 2.6, pz1), Color(0.6, 0.6, 0.58))
	k.box_mm("plain", Vector3(px + 1.88, top, pz0), Vector3(px + 2.0, top + 2.6, pz1), Color(0.6, 0.6, 0.58))
	k.box_mm("plain", Vector3(px - 2.2, top + 2.6, pz0 - 0.1), Vector3(px + 2.2, top + 2.75, pz1 + 0.35), Color(0.5, 0.5, 0.48))
	k.box_mm("snow", Vector3(px - 2.15, top + 2.75, pz0 - 0.05), Vector3(px + 2.15, top + 2.95, pz1 + 0.3), Color.WHITE)
	# mosaic panel on the back wall: a Soviet tradition even at tiny stops
	var colors := [Color(0.75, 0.2, 0.15), Color(0.85, 0.7, 0.3), Color(0.2, 0.35, 0.55), Color(0.85, 0.85, 0.8)]
	for i in 12:
		for j in 5:
			var c: Color = colors[(i * 3 + j * 5 + int(sin(i * 0.7) * 2.0)) % 4]
			if (i - 6) * (i - 6) + (j - 2) * (j - 2) * 4 < 12:
				c = Color(0.85, 0.7, 0.3)
			k.box_mm("ceramic", Vector3(px - 1.5 + i * 0.25, top + 1.0 + j * 0.25, pz0 + 0.12), Vector3(px - 1.27 + i * 0.25, top + 1.23 + j * 0.25, pz0 + 0.13), c)
	# bench
	k.box_mm("wood_ext", Vector3(px - 1.5, top + 0.45, pz0 + 0.2), Vector3(px + 1.5, top + 0.5, pz0 + 0.6), Color(0.4, 0.3, 0.2))
	for bx in [px - 1.3, px + 1.3]:
		k.box_mm("metal", Vector3(bx - 0.03, top, pz0 + 0.25), Vector3(bx + 0.03, top + 0.45, pz0 + 0.55), Color(0.2, 0.25, 0.22))
	_col_box(Vector3(px, top + 1.3, pz0 + 0.06), Vector3(4.0, 2.6, 0.15))
	_col_box(Vector3(px - 1.94, top + 1.3, (pz0 + pz1) * 0.5), Vector3(0.15, 2.6, pz1 - pz0))
	_col_box(Vector3(px + 1.94, top + 1.3, (pz0 + pz1) * 0.5), Vector3(0.15, 2.6, pz1 - pz0))
	# station sign "101 км"
	var sx := -14.0
	for spx in [sx - 0.9, sx + 0.9]:
		k.cyl("metal", Vector3(spx, top, mn.y + 0.5), Vector3(spx, top + 2.6, mn.y + 0.5), 0.035, Color(0.3, 0.3, 0.3), 6)
	k.box_mm("paint", Vector3(sx - 1.05, top + 2.0, mn.y + 0.47), Vector3(sx + 1.05, top + 2.55, mn.y + 0.53), Color(0.92, 0.92, 0.9))
	k.box_mm("paint", Vector3(sx - 1.1, top + 1.97, mn.y + 0.465), Vector3(sx + 1.1, top + 2.0, mn.y + 0.535), Color(0.1, 0.25, 0.5))
	k.box_mm("snow", Vector3(sx - 1.05, top + 2.55, mn.y + 0.45), Vector3(sx + 1.05, top + 2.6, mn.y + 0.55), Color.WHITE)
	for face in [[0.035, 0.0], [-0.035, PI]]:
		var l := Label3D.new()
		l.text = "101 км"
		l.font = UITheme.font_sans_bold()
		l.font_size = 96
		l.pixel_size = 0.0035
		l.modulate = Color(0.1, 0.2, 0.42)
		l.outline_size = 0
		l.shaded = true
		l.position = Vector3(sx, top + 2.27, mn.y + 0.5 + face[0])
		l.rotation.y = face[1]
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		add_child(l)
	interactables["sign"] = Interactable.make(self, "platform_sign", {"ru": "Табличка платформы", "en": "Platform sign"}, Vector3(2.2, 0.8, 0.3), Vector3(sx, top + 2.27, mn.y + 0.5))
	# lamp post with a warm bulb
	var lx := -8.8
	k.cyl("plain", Vector3(lx, top, mn.y + 0.4), Vector3(lx, top + 4.2, mn.y + 0.4), 0.08, Color(0.55, 0.55, 0.53), 8, true, 0.06)
	k.cyl("metal", Vector3(lx, top + 4.1, mn.y + 0.4), Vector3(lx, top + 4.15, mn.y + 1.4), 0.03, Color(0.3, 0.3, 0.3), 6)
	k.lathe("metal", Transform3D(Basis(), Vector3(lx, top + 3.95, mn.y + 1.4)), [Vector2(0.0, 0.18), Vector2(0.2, 0.0), Vector2(0.22, 0.0), Vector2(0.0, 0.22)], Color(0.25, 0.3, 0.28), 12)
	k.sphere("emissive", Vector3(lx, top + 3.98, mn.y + 1.4), Vector3(0.06, 0.06, 0.06), Color(1, 0.8, 0.5), 5, 8)
	platform_light = OmniLight3D.new()
	platform_light.light_color = Color(1.0, 0.72, 0.42)
	platform_light.light_energy = 2.5
	platform_light.omni_range = 14.0
	platform_light.omni_attenuation = 1.2
	platform_light.shadow_enabled = true
	platform_light.position = Vector3(lx, top + 3.85, mn.y + 1.4)
	add_child(platform_light)
	_col_cyl(Vector3(lx, top + 2.0, mn.y + 0.4), 0.1, 4.0)


func _build_fence() -> void:
	# Rough rail fence (zherdi) around the yard with gaps for paths.
	var pts := [Vector2(-11, 13), Vector2(-11, -10), Vector2(11, -10), Vector2(11, 13), Vector2(-11, 13)]
	var gaps := [Vector2(-0.5, 3.8), Vector2(2.5, 6.8)] # along the south edge (x) and the north edge (x)
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var length := a.distance_to(b)
		var steps := int(length / 2.4)
		for s in steps:
			var p0 := a.lerp(b, float(s) / steps)
			var p1 := a.lerp(b, float(s + 1) / steps)
			var mid := (p0 + p1) * 0.5
			var skip := false
			if absf(a.y - b.y) < 0.1:
				for g in gaps:
					if mid.x > g.x and mid.x < g.y and ((a.y > 0 and g == gaps[0]) or (a.y < 0 and g == gaps[1])):
						skip = true
			var y0 := gy(p0.x, p0.y)
			var y1 := gy(p1.x, p1.y)
			k.cyl("wood_ext", Vector3(p0.x, y0 - 0.3, p0.y), Vector3(p0.x + _rng.randf_range(-0.04, 0.04), y0 + 1.25, p0.y), 0.06, Color(0.42, 0.33, 0.25), 6)
			k.sphere("snow", Vector3(p0.x, y0 + 1.28, p0.y), Vector3(0.07, 0.04, 0.07), Color.WHITE, 3, 6)
			if skip:
				continue
			for h in [0.55, 1.05]:
				var sag := _rng.randf_range(-0.04, 0.03)
				k.cyl("wood_ext", Vector3(p0.x, y0 + h, p0.y), Vector3(p1.x, y1 + h + sag, p1.y), 0.045, Color(0.45, 0.36, 0.27), 6, true)
				k.cyl("snow", Vector3(p0.x, y0 + h + 0.045, p0.y), Vector3(p1.x, y1 + h + sag + 0.045, p1.y), 0.035, Color.WHITE, 5, false)
			var c := Vector3(mid.x, (y0 + y1) * 0.5 + 0.6, mid.y)
			var ang := -atan2(p1.y - p0.y, p1.x - p0.x)
			_col_box(c, Vector3(length / steps, 1.6, 0.15), ang)


func _build_woodshed() -> void:
	var x0 := 5.4
	var x1 := 8.8
	var z0 := -3.4
	var z1 := -0.6
	var g := gy((x0 + x1) * 0.5, (z0 + z1) * 0.5)
	# posts
	for px in [x0, x1]:
		for pz in [z0, z1]:
			var h := 2.4 if pz < -2.0 else 2.0
			k.box_mm("wood_ext", Vector3(px - 0.07, g - 0.2, pz - 0.07), Vector3(px + 0.07, g + h, pz + 0.07), Color(0.38, 0.3, 0.22))
	# lean-to roof sloping toward the yard
	var a := Vector3(0, g + 2.45, z0 - 0.35)
	var b := Vector3(0, g + 2.05, z1 + 0.45)
	var mid := (a + b) * 0.5
	var ang := atan2(a.y - b.y, b.z - a.z)
	var basis := Basis(Vector3.RIGHT, ang)
	k.box("wood_ext", Transform3D(basis, Vector3((x0 + x1) * 0.5, mid.y, mid.z)), Vector3(x1 - x0 + 0.6, 0.06, a.distance_to(b)), Color(0.3, 0.25, 0.2))
	k.box("snow", Transform3D(basis, Vector3((x0 + x1) * 0.5, mid.y + 0.15, mid.z)), Vector3(x1 - x0 + 0.5, 0.22, a.distance_to(b) - 0.05), Color.WHITE)
	# split birch logs stacked end-out: a wall of growth rings
	var rows := 9
	for r in rows:
		var y := g + 0.12 + r * 0.19
		var x := x0 + 0.15 + (r % 2) * 0.09
		while x < x1 - 0.15:
			var rad := _rng.randf_range(0.075, 0.1)
			var zz := _rng.randf_range(-0.04, 0.04)
			var birch := _rng.randf() < 0.6
			k.cyl("bark_birch" if birch else "bark_spruce", Vector3(x, y, z0 + 0.2 + zz), Vector3(x, y, z0 + 1.1 + zz), rad, Color.WHITE, 7, true, -1.0, Color(0.85, 0.7, 0.5) if birch else Color(0.78, 0.6, 0.42))
			x += rad * 2.0 + 0.005
	k.box_mm("snow", Vector3(x0 + 0.1, g + 0.12 + rows * 0.19, z0 + 0.6), Vector3(x1 - 0.1, g + 0.2 + rows * 0.19, z0 + 1.15), Color.WHITE)
	_col_box(Vector3((x0 + x1) * 0.5, g + 1.0, z0 + 0.65), Vector3(x1 - x0, 2.0, 1.1))
	for px in [x0, x1]:
		_col_box(Vector3(px, g + 1.0, z1), Vector3(0.15, 2.0, 0.15))
	# chopping block with the axe still in it
	var cb := Vector3(6.4, g, 0.6)
	k.cyl("bark_spruce", cb, cb + Vector3(0, 0.55, 0), 0.26, Color.WHITE, 12, true, -1.0, Color(0.72, 0.56, 0.4))
	k.sphere("snow", cb + Vector3(0.08, 0.57, 0.05), Vector3(0.14, 0.03, 0.12), Color.WHITE, 3, 8)
	var ax := cb + Vector3(-0.05, 0.6, 0)
	var hb := Basis(Vector3.BACK, 0.75) * Basis(Vector3.UP, 0.3)
	k.box("metal", Transform3D(hb, ax), Vector3(0.18, 0.1, 0.02), Color(0.3, 0.3, 0.32))
	k.cyl("wood_dry", ax + hb * Vector3(0.0, 0.0, 0.0), ax + hb * Vector3(0.0, 0.62, 0.0), 0.02, Color(0.62, 0.48, 0.32), 6)
	_col_cyl(cb + Vector3(0, 0.3, 0), 0.28, 0.6)
	# scattered chips in the snow
	for i in 14:
		var p := cb + Vector3(_rng.randf_range(-1.0, 1.0), 0.02, _rng.randf_range(-1.0, 1.0))
		p.y = gy(p.x, p.z) + 0.01
		k.box("wood_dry", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p), Vector3(0.08, 0.015, 0.03), Color(0.8, 0.65, 0.45))
	interactables["woodshed"] = Interactable.make(self, "woodshed", {"ru": "Поленница", "en": "Woodpile"}, Vector3(3.2, 1.8, 1.2), Vector3((x0 + x1) * 0.5, g + 1.0, z0 + 0.65))
	interactables["axe"] = Interactable.make(self, "axe", {"ru": "Колода с топором", "en": "Chopping block"}, Vector3(0.7, 0.9, 0.7), cb + Vector3(0, 0.5, 0))


func _build_well() -> void:
	var p := Vector3(Layout.WELL.x, 0, Layout.WELL.y)
	p.y = gy(p.x, p.z)
	# log crib
	for r in 5:
		var y := p.y + 0.08 + r * 0.17
		var off := 0.0 if r % 2 == 0 else 0.085
		for side in [-1.0, 1.0]:
			k.cyl("wood_ext", Vector3(p.x - 0.62, y + off, p.z + side * 0.5), Vector3(p.x + 0.62, y + off, p.z + side * 0.5), 0.085, Color(0.4, 0.31, 0.22), 8)
			k.cyl("wood_ext", Vector3(p.x + side * 0.5, y + 0.085 - off, p.z - 0.62), Vector3(p.x + side * 0.5, y + 0.085 - off, p.z + 0.62), 0.085, Color(0.42, 0.32, 0.23), 8)
	k.box_mm("plain", Vector3(p.x - 0.42, p.y + 0.5, p.z - 0.42), Vector3(p.x + 0.42, p.y + 0.52, p.z + 0.42), Color(0.03, 0.03, 0.04))
	# posts, drum, roof
	for side in [-1.0, 1.0]:
		k.box_mm("wood_ext", Vector3(p.x + side * 0.55 - 0.05, p.y, p.z - 0.05), Vector3(p.x + side * 0.55 + 0.05, p.y + 2.0, p.z + 0.05), Color(0.38, 0.3, 0.22))
	k.cyl("wood_ext", Vector3(p.x - 0.5, p.y + 1.3, p.z), Vector3(p.x + 0.5, p.y + 1.3, p.z), 0.09, Color(0.45, 0.35, 0.25), 10)
	k.cyl("metal", Vector3(p.x + 0.6, p.y + 1.3, p.z), Vector3(p.x + 0.72, p.y + 1.3, p.z), 0.015, Color(0.2, 0.2, 0.2), 6)
	k.cyl("metal", Vector3(p.x + 0.72, p.y + 1.3, p.z), Vector3(p.x + 0.72, p.y + 1.0, p.z + 0.1), 0.015, Color(0.2, 0.2, 0.2), 6)
	k.cyl("metal", Vector3(p.x, p.y + 1.25, p.z), Vector3(p.x, p.y + 0.85, p.z), 0.006, Color(0.3, 0.3, 0.3), 4)
	k.lathe("metal", Transform3D(Basis(), Vector3(p.x, p.y + 0.62, p.z)), [Vector2(0, 0), Vector2(0.09, 0), Vector2(0.12, 0.22), Vector2(0.11, 0.22), Vector2(0.08, 0.01), Vector2(0, 0.01)], Color(0.55, 0.57, 0.58), 12)
	for side in [-1.0, 1.0]:
		var basis := Basis(Vector3.RIGHT, 0.6 * side)
		k.box("wood_ext", Transform3D(basis, Vector3(p.x, p.y + 2.15, p.z + side * 0.32)), Vector3(1.4, 0.04, 0.8), Color(0.32, 0.26, 0.2))
		k.box("snow", Transform3D(basis, Vector3(p.x, p.y + 2.25, p.z + side * 0.36)), Vector3(1.35, 0.14, 0.7), Color.WHITE)
	_col_box(p + Vector3(0, 0.5, 0), Vector3(1.3, 1.0, 1.3))
	interactables["well"] = Interactable.make(self, "well", {"ru": "Колодец", "en": "Well"}, Vector3(1.4, 1.2, 1.4), p + Vector3(0, 0.7, 0))


func _build_feeder() -> void:
	var p := Vector3(Layout.FEEDER.x, 0, Layout.FEEDER.y)
	p.y = gy(p.x, p.z)
	k.cyl("wood_ext", p + Vector3(0, -0.3, 0), p + Vector3(0, 1.3, 0), 0.05, Color(0.4, 0.32, 0.24), 8)
	k.box_mm("wood_ext", p + Vector3(-0.3, 1.3, -0.22), p + Vector3(0.3, 1.34, 0.22), Color(0.45, 0.35, 0.26))
	for side in [-1.0, 1.0]:
		k.box_mm("wood_ext", p + Vector3(-0.3, 1.34, side * 0.22 - 0.01), p + Vector3(0.3, 1.38, side * 0.22 + 0.01), Color(0.42, 0.33, 0.24))
		k.cyl("wood_ext", p + Vector3(side * 0.27, 1.34, side * 0.18), p + Vector3(side * 0.27, 1.68, side * 0.18), 0.015, Color(0.4, 0.32, 0.24), 5)
		k.cyl("wood_ext", p + Vector3(side * 0.27, 1.34, -side * 0.18), p + Vector3(side * 0.27, 1.68, -side * 0.18), 0.015, Color(0.4, 0.32, 0.24), 5)
		var basis := Basis(Vector3.RIGHT, 0.55 * side)
		k.box("wood_ext", Transform3D(basis, p + Vector3(0, 1.78, side * 0.15)), Vector3(0.75, 0.025, 0.4), Color(0.36, 0.28, 0.21))
		k.box("snow", Transform3D(basis, p + Vector3(0, 1.85, side * 0.17)), Vector3(0.72, 0.09, 0.36), Color.WHITE)
	# little carved bird on the ridge — grandfather's work
	k.sphere("paint", p + Vector3(0.0, 1.98, 0), Vector3(0.05, 0.04, 0.035), Color(0.8, 0.25, 0.2), 4, 8)
	k.sphere("paint", p + Vector3(0.05, 2.01, 0), Vector3(0.025, 0.025, 0.025), Color(0.1, 0.1, 0.1), 4, 6)
	_col_cyl(p + Vector3(0, 0.6, 0), 0.08, 1.4)
	feeder_seed = Node3D.new()
	feeder_seed.position = p + Vector3(0, 1.34, 0)
	add_child(feeder_seed)
	var sk := MeshKit.new()
	for i in 40:
		sk.sphere("plain", Vector3(_rng.randf_range(-0.22, 0.22), 0.01, _rng.randf_range(-0.16, 0.16)), Vector3(0.012, 0.008, 0.008), Color(0.35, 0.3, 0.2), 2, 4)
	sk.build(feeder_seed, "Seeds", false)
	feeder_seed.visible = false
	interactables["feeder"] = Interactable.make(self, "feeder", {"ru": "Кормушка", "en": "Bird feeder"}, Vector3(0.7, 0.7, 0.6), p + Vector3(0, 1.55, 0))


func _build_birch_of_kostya() -> void:
	var p := Vector3(Layout.BIRCH_OF_KOSTYA.x, 0, Layout.BIRCH_OF_KOSTYA.y)
	p.y = gy(p.x, p.z)
	var bk := MeshKit.new()
	# an old, wide, leaning birch
	var lean := Vector3(0.6, 0, -0.2)
	var a := p + Vector3(0, -0.4, 0)
	var b := p + Vector3(0, 6.0, 0) + lean
	var c := b + Vector3(0.5, 6.0, 0.3)
	bk.cyl("bark_birch", a, b, 0.32, Color.WHITE, 12, false, 0.24)
	bk.cyl("bark_birch", b, c, 0.24, Color.WHITE, 10, false, 0.08)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in 18:
		var base := b.lerp(c, r.randf_range(0.0, 0.9)) if i > 3 else a.lerp(b, r.randf_range(0.6, 1.0))
		var ang := r.randf() * TAU
		var tip := base + Vector3(cos(ang), r.randf_range(0.4, 0.9), sin(ang)).normalized() * r.randf_range(1.8, 3.8)
		bk.cyl("bark_birch", base, tip, 0.07, Color(0.6, 0.55, 0.52), 5, false, 0.015)
		for t in 3:
			var tb := base.lerp(tip, r.randf_range(0.4, 0.95))
			bk.cyl("bark_birch", tb, tb + Vector3(r.randf_range(-0.7, 0.7), -r.randf_range(0.8, 1.8), r.randf_range(-0.7, 0.7)), 0.015, Color(0.25, 0.18, 0.16), 3, false, 0.004)
		bk.sphere("twigs", tip + Vector3(0, -0.5, 0), Vector3(1.3, 1.5, 1.3), Color(0.32, 0.22, 0.2), 5, 8)
	bk.build(self, "KostyaBirch")
	_col_cyl(p + Vector3(0, 1.5, 0), 0.34, 3.0)
	# the carving, facing the pond path
	var face_dir := (Vector3(Layout.PATH_POND[3].x, 0, Layout.PATH_POND[3].y) - Vector3(p.x, 0, p.z)).normalized()
	var carve := Label3D.new()
	carve.text = "К.Б.\n+\n1977"
	carve.font = UITheme.font_hand()
	carve.font_size = 46
	carve.pixel_size = 0.0022
	carve.modulate = Color(0.12, 0.08, 0.06, 0.92)
	carve.outline_size = 0
	carve.shaded = true
	carve.line_spacing = -8
	var cp := p + Vector3(0, 1.5, 0) + face_dir * 0.31 + lean * 0.25 * 0.24
	carve.position = cp
	carve.look_at_from_position(cp, cp - face_dir, Vector3.UP)
	carve.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(carve)
	# a small bullfinch scratched beside the letters
	var bird := Label3D.new()
	bird.text = "~ ●>"
	bird.font = UITheme.font_mono()
	bird.font_size = 30
	bird.pixel_size = 0.0018
	bird.modulate = Color(0.45, 0.1, 0.08, 0.85)
	bird.outline_size = 0
	bird.shaded = true
	var bp := cp + Vector3(0, -0.42, 0) + face_dir * 0.01
	bird.position = bp
	bird.look_at_from_position(bp, bp - face_dir, Vector3.UP)
	bird.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(bird)
	interactables["birch"] = Interactable.make(self, "birch", {"ru": "Старая берёза", "en": "Old birch"}, Vector3(1.0, 1.8, 1.0), p + Vector3(0, 1.4, 0))


func _build_boat() -> void:
	# An upturned rowboat on the pond shore, buried under snow.
	var p := Vector3(Layout.POND.x - 9.0, 0, Layout.POND.y + 11.5)
	p.y = gy(p.x, p.z)
	var basis := Basis(Vector3.UP, 0.7)
	for i in 7:
		var t := (i / 6.0) * 2.0 - 1.0
		var w := 0.62 * sqrt(maxf(1.0 - t * t, 0.0)) + 0.06
		k.box("wood_ext", Transform3D(basis, p + basis * Vector3(0, 0.35 - absf(t) * 0.05, t * 1.6)), Vector3(w * 2.0, 0.08, 0.5), Color(0.3, 0.35, 0.33))
	k.sphere("snow", p + Vector3(0, 0.42, 0), Vector3(0.7, 0.18, 1.8), Color.WHITE, 6, 12, basis)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.3, 0.6, 3.4)
	cs.shape = bs
	cs.transform = Transform3D(basis, p + Vector3(0, 0.3, 0))
	_body.add_child(cs)
	interactables["boat"] = Interactable.make(self, "boat", {"ru": "Перевёрнутая лодка", "en": "Upturned boat"}, Vector3(1.4, 0.8, 3.4), p + Vector3(0, 0.4, 0), 0.7)


func _build_clutter() -> void:
	# stumps, fallen logs and snow-covered shrubs
	for i in 70:
		var x := _rng.randf_range(-120, 120)
		var z := _rng.randf_range(-120, 120)
		if not Layout.tree_allowed(x, z, 0.5):
			continue
		var y := gy(x, z)
		var roll := _rng.randf()
		if roll < 0.4:
			var r := _rng.randf_range(0.18, 0.35)
			var h := _rng.randf_range(0.25, 0.6)
			k.cyl("bark_spruce", Vector3(x, y - 0.2, z), Vector3(x, y + h, z), r, Color.WHITE, 9, true, -1.0, Color(0.55, 0.42, 0.3))
			k.sphere("snow", Vector3(x, y + h + 0.02, z), Vector3(r * 1.1, 0.08, r * 1.1), Color.WHITE, 4, 8)
			if Vector2(x, z).length() < Layout.PLAY_RADIUS:
				_col_cyl(Vector3(x, y + h * 0.5, z), r, h + 0.4)
		elif roll < 0.6:
			var ang := _rng.randf() * TAU
			var length := _rng.randf_range(3.0, 7.0)
			var d := Vector3(cos(ang), 0, sin(ang)) * length * 0.5
			var a := Vector3(x, 0, z) - d
			var b := Vector3(x, 0, z) + d
			a.y = gy(a.x, a.z) + 0.15
			b.y = gy(b.x, b.z) + 0.1
			var r := _rng.randf_range(0.14, 0.26)
			k.cyl("bark_spruce", a, b, r, Color.WHITE, 8, true, r * 0.7, Color(0.6, 0.45, 0.3))
			k.cyl("snow", a + Vector3(0, r * 0.8, 0), b + Vector3(0, r * 0.6, 0), r * 0.75, Color.WHITE, 6, false)
			if Vector2(x, z).length() < Layout.PLAY_RADIUS:
				var c := (a + b) * 0.5
				_col_box(c, Vector3(length, r * 2.0, r * 2.0), -ang)
		else:
			var s := _rng.randf_range(0.5, 1.2)
			k.sphere("snow", Vector3(x, y + 0.1 * s, z), Vector3(0.8, 0.45, 0.7) * s, Color.WHITE, 5, 9)
			k.sphere("twigs", Vector3(x, y + 0.3 * s, z), Vector3(0.9, 0.6, 0.8) * s, Color(0.3, 0.2, 0.18), 4, 7)
