class_name PlayerBody
extends Node3D
## Arkady's visible body: felt boots, wool trousers, the quilted telogreika,
## arms and bare hands. Legs and arms are solved with two-bone IK every frame,
## so feet step on the ground and hands reach for whatever they hold.

const HIP_Y := 0.93
const THIGH := 0.45
const SHIN := 0.46
const UPPER_ARM := 0.31
const FOREARM := 0.29

var camera: Camera3D
var player: CharacterBody3D

var _seg := {}   # name -> MeshInstance3D (unit-length along +Y)
var hand_r: Node3D
var hand_l: Node3D
var hold_point_r: Node3D
var hold_point_l: Node3D
var _torso: Node3D
var _head: MeshInstance3D

# animation state
var walk_phase := 0.0
var walk_amount := 0.0
var crouch := 0.0
var right_target_cam := Vector3.ZERO    # camera-space target when raised
var left_target_cam := Vector3.ZERO
var right_raise := 0.0                    # 0 = hanging at side, 1 = in view
var left_raise := 0.0
var reach_point := Vector3.ZERO           # world-space point for a reach gesture
var reach_amount := 0.0
var right_grip := 0.0
var drink := 0.0                          # 0..1 brings the cup to the lips
var _hand_r_cur := Vector3.ZERO
var _hand_l_cur := Vector3.ZERO
var _foot_l := Vector3.ZERO
var _foot_r := Vector3.ZERO

const C_JACKET := Color(0.17, 0.18, 0.18)
const C_TROUSERS := Color(0.16, 0.15, 0.17)
const C_VALENKI := Color(0.24, 0.22, 0.21)
const C_SKIN := Color(0.78, 0.6, 0.5)
const C_SLEEVE := Color(0.16, 0.17, 0.17)
const C_SWEATER := Color(0.42, 0.18, 0.15)


func build(p: CharacterBody3D, cam: Camera3D) -> void:
	player = p
	camera = cam
	var trousers := _mat_std(C_TROUSERS, 0.95)
	var quilt := Mats.get_mat("quilt")
	var felt := _mat_std(C_VALENKI, 1.0)
	var skin := _mat_std(C_SKIN, 0.55)
	skin.subsurf_scatter_enabled = true
	skin.subsurf_scatter_strength = 0.4
	var sleeve := Mats.get_mat("quilt")
	var sweater := _mat_std(C_SWEATER, 1.0)
	for side in ["l", "r"]:
		_make_seg("thigh_" + side, 0.085, 0.07, trousers)
		_make_seg("shin_" + side, 0.07, 0.065, felt)
		_make_seg("upper_" + side, 0.065, 0.058, sleeve, C_SLEEVE)
		_make_seg("fore_" + side, 0.058, 0.05, sleeve, C_SLEEVE)
		_make_foot(side, felt)
	# torso: quilted jacket over a red knitted sweater collar
	_torso = Node3D.new()
	_torso.name = "Torso"
	add_child(_torso)
	var tk := MeshKit.new()
	tk.sphere("quilt", Vector3(0, 0.22, 0.0), Vector3(0.2, 0.26, 0.12), C_JACKET, 10, 16)
	tk.sphere("quilt", Vector3(0, 0.03, -0.01), Vector3(0.18, 0.15, 0.13), C_JACKET, 8, 14)
	# buttons down the front
	for i in 4:
		tk.sphere("plain", Vector3(0.0, 0.04 + i * 0.09, -0.128 - (0.012 if i == 0 else 0.0)), Vector3(0.012, 0.012, 0.008), Color(0.08, 0.07, 0.06), 4, 6)
	# a red knitted scarf end tucked into the jacket
	tk.box("fabric", Transform3D(Basis(Vector3.RIGHT, 0.12), Vector3(0.05, 0.36, -0.115)), Vector3(0.07, 0.16, 0.015), C_SWEATER)
	# trousers below the jacket hem
	tk.sphere("fabric", Vector3(0, -0.08, 0.0), Vector3(0.17, 0.1, 0.12), C_TROUSERS, 6, 12)
	var tmi := tk.build(_torso, "TorsoMesh")
	tmi.layers = 1
	# head: only casts a shadow (with ushanka) — the camera lives inside it
	_head = MeshInstance3D.new()
	var hk := MeshKit.new()
	hk.sphere("skin", Vector3.ZERO, Vector3(0.1, 0.12, 0.11), C_SKIN, 8, 12)
	hk.sphere("fabric", Vector3(0, 0.06, 0.0), Vector3(0.13, 0.09, 0.13), Color(0.3, 0.25, 0.2), 6, 12)
	_head.mesh = hk.build_mesh()
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(_head)
	# hands
	hand_r = _make_hand(true, skin, sweater)
	hand_l = _make_hand(false, skin, sweater)
	hold_point_r = Node3D.new()
	hold_point_r.name = "HoldR"
	hand_r.add_child(hold_point_r)
	hold_point_r.position = Vector3(-0.02, -0.02, -0.06)
	hold_point_l = Node3D.new()
	hold_point_l.name = "HoldL"
	hand_l.add_child(hold_point_l)
	hold_point_l.position = Vector3(0.02, -0.01, -0.06)
	_foot_l = global_position
	_foot_r = global_position


func _mat_std(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _make_seg(n: String, r0: float, r1: float, mat: Material, col := Color.WHITE) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var k := MeshKit.new()
	k.cyl("plain", Vector3.ZERO, Vector3(0, 1, 0), 1.0, col, 10, true, r1 / r0)
	var mesh := k.build_mesh()
	mesh.surface_set_material(0, mat)
	mi.mesh = mesh
	mi.set_meta("r0", r0)
	add_child(mi)
	_seg[n] = mi
	# rounded joint cap so segments blend at knees and elbows
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r1 * 1.02
	sm.height = r1 * 2.04
	sm.radial_segments = 10
	sm.rings = 6
	sm.material = mat
	cap.mesh = sm
	cap.name = n + "_cap"
	add_child(cap)
	_seg[n + "_cap"] = cap


func _make_foot(side: String, felt: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "foot_" + side
	var k := MeshKit.new()
	k.sphere("plain", Vector3(0, 0.045, -0.06), Vector3(0.062, 0.05, 0.13), Color.WHITE, 6, 10)
	var mesh := k.build_mesh()
	mesh.surface_set_material(0, felt)
	mi.mesh = mesh
	add_child(mi)
	_seg["foot_" + side] = mi


func _make_hand(right: bool, skin: Material, cuff_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "HandR" if right else "HandL"
	add_child(root)
	var s := 1.0 if right else -1.0
	var k := MeshKit.new()
	# palm (hand space: -Z forward along the fingers, +Y back of the hand)
	k.sphere("plain", Vector3(0, 0, -0.035), Vector3(0.042, 0.018, 0.05), Color.WHITE, 6, 10)
	var mesh := k.build_mesh()
	mesh.surface_set_material(0, skin)
	var palm := MeshInstance3D.new()
	palm.mesh = mesh
	root.add_child(palm)
	# fingers as small capsules
	for f in 4:
		var finger := Node3D.new()
		finger.name = "F%d" % f
		finger.position = Vector3(s * (-0.027 + f * 0.018), 0.0, -0.078)
		root.add_child(finger)
		var fk := MeshKit.new()
		var fl: float = [0.07, 0.078, 0.074, 0.06][f]
		fk.cyl("plain", Vector3.ZERO, Vector3(0, 0, -fl), 0.0085, Color.WHITE, 6, true, 0.85)
		fk.sphere("plain", Vector3(0, 0, -fl), Vector3(0.0075, 0.0075, 0.0075), Color.WHITE, 4, 6)
		var fm := fk.build_mesh()
		fm.surface_set_material(0, skin)
		var fmi := MeshInstance3D.new()
		fmi.mesh = fm
		finger.add_child(fmi)
	var thumb := Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(s * -0.04, -0.008, -0.02)
	thumb.rotation = Vector3(0, s * 0.7, s * -0.3)
	root.add_child(thumb)
	var tk := MeshKit.new()
	tk.cyl("plain", Vector3.ZERO, Vector3(0, 0, -0.055), 0.01, Color.WHITE, 6, true, 0.85)
	var tm := tk.build_mesh()
	tm.surface_set_material(0, skin)
	var tmi := MeshInstance3D.new()
	tmi.mesh = tm
	thumb.add_child(tmi)
	# knitted sweater cuff peeking from the sleeve
	var cuff := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.045
	cm.height = 0.05
	cm.material = cuff_mat
	cuff.mesh = cm
	cuff.rotation.x = PI * 0.5
	cuff.position = Vector3(0, 0, 0.02)
	root.add_child(cuff)
	return root


## Curl the fingers (0 open .. 1 fist / gripping a glass).
func _curl(hand: Node3D, amount: float) -> void:
	for f in 4:
		var finger: Node3D = hand.get_node("F%d" % f)
		finger.rotation.x = -amount * (1.2 + f * 0.05)
	var thumb: Node3D = hand.get_node("Thumb")
	thumb.rotation.x = -amount * 0.6


# --- per-frame solve ---------------------------------------------------------------

func update_pose(delta: float, speed: float, on_floor: bool) -> void:
	var yaw_basis := Basis(Vector3.UP, player.rotation.y)
	var base := player.global_position
	var crouch_drop := crouch * 0.38
	var hip_y := HIP_Y - crouch_drop
	var fwd := yaw_basis * Vector3(0, 0, -1)
	var right := yaw_basis * Vector3(1, 0, 0)
	var up := Vector3.UP

	walk_amount = lerpf(walk_amount, clampf(speed / 2.0, 0.0, 1.4) if on_floor else 0.0, 1.0 - exp(-delta * 8.0))
	var bob := absf(sin(walk_phase)) * 0.025 * walk_amount
	# the body sits a little behind the eyes so that looking down shows the
	# chest, legs and boots instead of the inside of a collar
	var pelvis := base + up * (hip_y + bob) - fwd * 0.1

	# torso: leans forward a little when walking and when looking down
	var pitch := camera.rotation.x
	var lean := 0.05 + walk_amount * 0.06 + clampf(-pitch, 0.0, 1.2) * 0.12
	_torso.global_transform = Transform3D(yaw_basis * Basis(Vector3.RIGHT, -lean), pelvis - fwd * 0.04)
	_head.global_transform = Transform3D(yaw_basis * Basis(Vector3.RIGHT, pitch), camera.global_position + fwd * 0.02)

	# legs: feet trace a stepping ellipse
	var stride := 0.36 * walk_amount
	var lift := 0.12 * walk_amount
	for side in ["l", "r"]:
		var s := -1.0 if side == "l" else 1.0
		var ph := walk_phase + (0.0 if side == "l" else PI)
		var hip := pelvis + right * (s * 0.11) + fwd * -0.02
		var foot := base + right * (s * 0.13) + fwd * (sin(ph) * stride + 0.06 + crouch * 0.12)
		foot.y = base.y + maxf(0.0, cos(ph)) * lift + 0.065
		var knee := _ik(hip, foot, THIGH, SHIN, fwd + up * 0.1)
		_place_seg("thigh_" + side, hip, knee)
		_place_seg("shin_" + side, knee, foot)
		var fm: MeshInstance3D = _seg["foot_" + side]
		var toe_pitch := -maxf(0.0, cos(ph)) * 0.35 * walk_amount
		fm.global_transform = Transform3D(yaw_basis * Basis(Vector3.RIGHT, toe_pitch), foot - up * 0.06)

	# arms
	var cam_xf := camera.global_transform
	for side in ["l", "r"]:
		var s := -1.0 if side == "l" else 1.0
		var shoulder := pelvis + up * (0.44 - crouch * 0.02) + right * (s * 0.2) - fwd * 0.02
		var swing := sin(walk_phase + (PI if side == "l" else 0.0)) * 0.16 * walk_amount
		var rest := pelvis + up * 0.02 + right * (s * 0.24) + fwd * (swing + 0.08)
		var raise := right_raise if side == "r" else left_raise
		var cam_target := right_target_cam if side == "r" else left_target_cam
		var target := rest.lerp(cam_xf * cam_target, raise)
		if side == "r":
			if drink > 0.0:
				var mouth := cam_xf * Vector3(0.03, -0.09, -0.16)
				target = target.lerp(mouth, drink)
			if reach_amount > 0.0:
				target = target.lerp(reach_point, reach_amount)
			_hand_r_cur = target
		else:
			_hand_l_cur = target
		# keep the hand within reach
		var to_t := target - shoulder
		var max_len := (UPPER_ARM + FOREARM) * 0.985
		if to_t.length() > max_len:
			target = shoulder + to_t.normalized() * max_len
		var pole := -up * 0.6 + right * (s * 0.6) - fwd * 0.3
		var elbow := _ik(shoulder, target, UPPER_ARM, FOREARM, pole)
		_place_seg("upper_" + side, shoulder, elbow)
		_place_seg("fore_" + side, elbow, target)
		# hand orientation: fingers continue the forearm; palm turns inward
		var hand: Node3D = hand_r if side == "r" else hand_l
		var dir := (target - elbow).normalized()
		var raised := clampf(raise + (drink if side == "r" else 0.0), 0.0, 1.0)
		var palm_up := right * (-s) * (1.0 - raised) + up * raised
		var z := -dir
		var x := palm_up.cross(z).normalized()
		if x.length() < 0.1:
			x = right
		var y := z.cross(x).normalized()
		var hb := Basis(x, y, z)
		if raised > 0.5:
			# holding something upright in view: knuckles toward the camera side
			var cz := -(cam_xf.basis.z).normalized()
			var hz := (-cz * 0.7 + Vector3.UP * -0.2).normalized()
			hb = hb.slerp(Basis.looking_at(cz, Vector3.UP), raised * 0.8)
		hand.global_transform = Transform3D(hb.orthonormalized(), target)
		_curl(hand, (right_grip if side == "r" else 0.55 * left_raise) * 0.85 + 0.15)


func _place_seg(n: String, a: Vector3, b: Vector3) -> void:
	var mi: MeshInstance3D = _seg[n]
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		return
	var y := d / length
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	var r0: float = mi.get_meta("r0")
	mi.global_transform = Transform3D(Basis(x * r0, y * length, z * r0), a)
	var cap: MeshInstance3D = _seg[n + "_cap"]
	cap.global_position = b


## Two-bone IK: returns the joint position given root, target, bone lengths
## and a pole direction that decides which way the joint bends.
static func _ik(root: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> Vector3:
	var d := target - root
	var dist := clampf(d.length(), 0.001, a + b - 0.0001)
	var dn := d.normalized()
	var cos_a := clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0)
	var along := a * cos_a
	var h := sqrt(maxf(a * a - along * along, 0.0))
	var p := (pole - dn * pole.dot(dn))
	if p.length() < 0.0001:
		p = Vector3.UP
	return root + dn * along + p.normalized() * h
