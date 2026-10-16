class_name Player
extends CharacterBody3D
## First-person controller for Arkady: heavy winter walk, crunching snow,
## footprints, a visible body, held items, a flashlight and interaction.

signal focus_changed(it: Interactable)
signal used(it: Interactable)

const WALK := 1.75
const RUN := 3.4
const CROUCH_SPEED := 0.9
const EYE := 1.63
const REACH := 2.4

var camera: Camera3D
var head: Node3D
var body: PlayerBody
var ray: RayCast3D
var flashlight: SpotLight3D
var world: World

var controls_enabled := true
var look_enabled := true
var flashlight_allowed := true
var flashlight_on := false
var focused: Interactable
var held: Node3D
var held_id := ""

var _yaw := 0.0
var _pitch := 0.0
var _sprint_toggled := false
var _crouching := false
var _step_dist := 0.0
var _foot_right := false
var _bob_t := 0.0
var _land_kick := 0.0
var _was_on_floor := true
var _look_tween: Tween
var _shake := 0.0
var _breath_t := 0.0
var _inside := false


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 1
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.03
	camera.far = 900.0
	camera.fov = Settings.get_value("fov", 78.0)
	head.add_child(camera)
	camera.current = true
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.collision_mask = 1 | (1 << 1)
	ray.add_exception(self)
	camera.add_child(ray)
	body = PlayerBody.new()
	body.name = "Body"
	add_child(body)
	body.build(self, camera)
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(1.0, 0.9, 0.72)
	flashlight.light_energy = 0.0
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 24.0
	flashlight.spot_angle_attenuation = 1.6
	flashlight.shadow_enabled = true
	flashlight.light_volumetric_fog_energy = 1.5
	body.hold_point_l.add_child(flashlight)
	_make_flashlight_mesh()
	Settings.changed.connect(_on_setting)
	_yaw = rotation.y


func _make_flashlight_mesh() -> void:
	# A Soviet steel pocket torch, the kind with a little red lens switch.
	var k := MeshKit.new()
	k.cyl("metal", Vector3(0, 0, 0.05), Vector3(0, 0, -0.08), 0.017, Color(0.3, 0.32, 0.3), 10)
	k.cyl("chrome", Vector3(0, 0, -0.08), Vector3(0, 0, -0.11), 0.017, Color(0.8, 0.8, 0.78), 10, true, 0.026)
	k.cyl("emissive", Vector3(0, 0, -0.11), Vector3(0, 0, -0.112), 0.025, Color(1, 0.95, 0.8), 10)
	var mi := k.build(body.hold_point_l, "TorchMesh")
	mi.visible = false
	flashlight.set_meta("mesh", mi)


func _on_setting(key: String) -> void:
	if key == "fov":
		camera.fov = Settings.get_value("fov", 78.0)


func set_yaw_pitch(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	rotation.y = _yaw
	head.rotation.x = _pitch


func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var sens := 0.0006 + float(Settings.get_value("mouse_sens", 0.5)) * 0.0042
		var inv := -1.0 if Settings.get_value("invert_y", false) else 1.0
		_yaw -= event.relative.x * sens
		_pitch = clampf(_pitch - event.relative.y * sens * inv, deg_to_rad(-84.0), deg_to_rad(82.0))
		if _look_tween and _look_tween.is_running():
			_look_tween.kill()
	if not controls_enabled:
		return
	if event.is_action_pressed("interact") and focused and focused.enabled:
		_use(focused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("flashlight") and flashlight_allowed:
		set_flashlight(not flashlight_on)
	elif event.is_action_pressed("sprint") and Settings.get_value("toggle_sprint", false):
		_sprint_toggled = not _sprint_toggled


func _use(it: Interactable) -> void:
	reach_toward(it.global_position)
	it.use()
	used.emit(it)


func reach_toward(p: Vector3) -> void:
	body.reach_point = p
	var t := create_tween()
	t.tween_property(body, "reach_amount", 0.8, 0.22).set_trans(Tween.TRANS_SINE)
	t.tween_property(body, "reach_amount", 0.0, 0.35).set_trans(Tween.TRANS_SINE)


func set_flashlight(on: bool) -> void:
	flashlight_on = on
	Sfx.play("ui_hover", -4.0, 0.7)
	var t := create_tween().set_parallel()
	t.tween_property(body, "left_raise", 1.0 if on else 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_property(flashlight, "light_energy", 2.6 if on else 0.0, 0.12)
	(flashlight.get_meta("mesh") as Node3D).visible = true
	if not on:
		t.chain().tween_callback(func(): (flashlight.get_meta("mesh") as Node3D).visible = flashlight_on)
	body.left_target_cam = Vector3(-0.2, -0.22, -0.42)


func hold(node: Node3D, id: String, cam_offset := Vector3(0.17, -0.2, -0.38)) -> void:
	held = node
	held_id = id
	node.reparent(body.hold_point_r, false)
	node.position = Vector3(0, -0.04, 0)
	node.rotation = Vector3.ZERO
	body.right_target_cam = cam_offset
	var t := create_tween().set_parallel()
	t.tween_property(body, "right_raise", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(body, "right_grip", 0.8, 0.3)
	Sfx.play("pickup", -6.0)


func release(to_parent: Node3D, to_xf: Transform3D) -> Node3D:
	var n := held
	held = null
	held_id = ""
	if n:
		n.reparent(to_parent, false)
		n.transform = to_xf
	var t := create_tween().set_parallel()
	t.tween_property(body, "right_raise", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(body, "right_grip", 0.0, 0.3)
	return n


func play_drink() -> void:
	var t := create_tween()
	t.tween_property(body, "drink", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "_pitch", clampf(_pitch, deg_to_rad(-10.0), deg_to_rad(25.0)) + 0.12, 0.7)
	t.tween_callback(func(): Sfx.play("sip", -4.0))
	t.tween_interval(1.0)
	t.tween_property(body, "drink", 0.0, 0.8).set_trans(Tween.TRANS_SINE)


## Smoothly turn the camera to look at a world point.
func look_at_point(p: Vector3, duration := 1.2) -> void:
	var dir := (p - camera.global_position).normalized()
	var target_yaw := atan2(-dir.x, -dir.z)
	var target_pitch := asin(clampf(dir.y, -1.0, 1.0))
	var dy := wrapf(target_yaw - _yaw, -PI, PI)
	if _look_tween:
		_look_tween.kill()
	_look_tween = create_tween().set_parallel()
	_look_tween.tween_property(self, "_yaw", _yaw + dy, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_look_tween.tween_property(self, "_pitch", target_pitch, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_crouching = controls_enabled and Input.is_action_pressed("crouch")
	body.crouch = move_toward(body.crouch, 1.0 if _crouching else 0.0, delta * 3.0)
	var sprinting := (Input.is_action_pressed("sprint") if not Settings.get_value("toggle_sprint", false) else _sprint_toggled) and input.y < -0.1 and not _crouching
	if input.length() < 0.1:
		_sprint_toggled = false
	var speed := RUN if sprinting else (CROUCH_SPEED if _crouching else WALK)
	if _inside:
		speed *= 0.85
	var wish := (transform.basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	wish = wish.normalized() * speed * minf(input.length(), 1.0)
	var accel := 7.0 if is_on_floor() else 1.5
	velocity.x = lerpf(velocity.x, wish.x, 1.0 - exp(-accel * delta))
	velocity.z = lerpf(velocity.z, wish.z, 1.0 - exp(-accel * delta))
	if not is_on_floor():
		velocity.y -= 12.0 * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)
	move_and_slide()
	var hspeed := Vector2(velocity.x, velocity.z).length()
	# landing
	if is_on_floor() and not _was_on_floor:
		_land_kick = 0.06
	_was_on_floor = is_on_floor()
	# steps
	if is_on_floor() and hspeed > 0.3:
		var stride := 0.72 if sprinting else 0.62
		_step_dist += hspeed * delta
		body.walk_phase += hspeed * delta / stride * PI
		if _step_dist >= stride:
			_step_dist -= stride
			_footstep(sprinting)
	else:
		body.walk_phase = lerpf(body.walk_phase, roundf(body.walk_phase / PI) * PI, 1.0 - exp(-delta * 6.0))
	# camera
	rotation.y = _yaw
	var bob_amt := float(Settings.get_value("head_bob", 1.0))
	_bob_t += delta
	var bob := Vector3.ZERO
	if is_on_floor():
		var w := clampf(hspeed / WALK, 0.0, 1.8)
		bob.y = -absf(sin(body.walk_phase)) * 0.045 * w * bob_amt
		bob.x = sin(body.walk_phase) * 0.022 * w * bob_amt
	# breathing sway when standing still
	_breath_t += delta
	bob.y += sin(_breath_t * 1.4) * 0.006 * bob_amt
	_land_kick = move_toward(_land_kick, 0.0, delta * 0.4)
	_shake = move_toward(_shake, 0.0, delta * 0.5)
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.02
	head.position = Vector3(bob.x, EYE - body.crouch * 0.42 + bob.y - _land_kick, 0) + shake
	head.rotation.x = _pitch
	head.rotation.z = -sin(body.walk_phase) * 0.006 * bob_amt * clampf(hspeed / WALK, 0.0, 1.5)
	body.update_pose(delta, hspeed, is_on_floor())
	_update_focus()
	_update_inside()


func _footstep(sprinting: bool) -> void:
	var on_snow := not _inside and absf(global_position.y - Layout.height(global_position.x, global_position.z)) < 0.25
	var vol := -9.0 if not sprinting else -6.0
	if _crouching:
		vol -= 6.0
	if on_snow:
		Sfx.play("step_snow_%d" % randi_range(0, 3), vol, randf_range(0.9, 1.1))
		if world and world.footprints:
			_foot_right = not _foot_right
			var side := transform.basis.x * (0.12 if _foot_right else -0.12)
			var p := global_position + side
			p.y = Layout.height(p.x, p.z)
			world.footprints.add(p, rotation.y + randf_range(-0.08, 0.08), _foot_right)
	else:
		Sfx.play("step_wood_%d" % randi_range(0, 2), vol - 1.0, randf_range(0.92, 1.08))


func _update_focus() -> void:
	var it: Interactable = null
	if controls_enabled:
		ray.force_raycast_update()
		var c := ray.get_collider()
		if c is Interactable and c.enabled and c.visible:
			var dist := camera.global_position.distance_to(ray.get_collision_point())
			if dist <= c.max_distance:
				it = c
	if it != focused:
		focused = it
		focus_changed.emit(it)


func _update_inside() -> void:
	var inside := world != null and world.cabin.contains_point(camera.global_position)
	if inside != _inside:
		_inside = inside
		Sfx.set_interior(inside)
		if world:
			world.set_player_inside(inside)
