extends Node3D
func _ready():
	Fader.set_progress(0.0)
	var k := MeshKit.new()
	k.box("wood", Transform3D(Basis(), Vector3(-1.5,0,0)), Vector3(1,1,1), Color(0.6,0.4,0.25))
	k.cyl("wood_ext", Vector3(0,-0.5,0), Vector3(0,0.5,0.0), 0.4, Color(0.55,0.4,0.28))
	k.cyl("wood", Vector3(1.0,0,-0.5), Vector3(2.0,0,0.5), 0.3, Color(0.55,0.4,0.28))
	k.sphere("snow", Vector3(0,1.2,0), Vector3(0.5,0.3,0.5), Color.WHITE)
	k.box("carpet", Transform3D(Basis(), Vector3(0,-1.2,-1)), Vector3(2,0.02,1.4), Color.WHITE)
	k.build(self)
	var c = Camera3D.new(); add_child(c); c.position = Vector3(0.5,1.5,4); c.look_at(Vector3(0,0,0))
	var l = DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-50,30,0); l.shadow_enabled = true
	var we = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2,0.25,0.3); e.ambient_light_color = Color(0.5,0.5,0.6); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; we.environment = e; add_child(we)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/claude-0/shots/kit.png")
	get_tree().quit()
