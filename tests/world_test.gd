extends Node3D
## Renders the world from a list of viewpoints. Args after "--":
##   preset=dusk shots=name:x,y,z:tx,ty,tz;...
var world: World
func _ready():
	Fader.set_progress(0.0)
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv = a.split("=", true, 1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var t0 := Time.get_ticks_msec()
	world = World.new()
	world.preset_name = args.get("preset", "dusk")
	add_child(world)
	print("BUILD_MS ", Time.get_ticks_msec() - t0)
	if args.get("stove", "0") == "1":
		world.cabin.set_stove_lit(true)
		world.cabin.set_lamp_lit(true)
	if args.get("birds", "0") == "1":
		world.birds.set_active(true, true)
		world.props.feeder_seed.visible = true
	if args.get("train", "0") == "1":
		world.train.start_stopped(100.0)
	var cam := Camera3D.new()
	cam.fov = 75
	cam.near = 0.05
	add_child(cam)
	cam.current = true
	world.follow(cam)
	for spec in args.get("shots", "a:8,3,14:0,2,0").split(";"):
		var p = spec.split(":")
		var pos = _v(p[1]); var tgt = _v(p[2])
		cam.global_position = pos
		cam.look_at(tgt, Vector3.UP)
		for i in 3: await get_tree().process_frame
		await get_tree().create_timer(float(args.get("wait", "1.5"))).timeout
		get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/%s.png" % p[0])
		print("SHOT ", p[0])
	get_tree().quit()
func _v(s: String) -> Vector3:
	var c = s.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))
