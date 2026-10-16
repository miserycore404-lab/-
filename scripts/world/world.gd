class_name World
extends Node3D
## Builds and owns the whole outdoor/indoor world: environment, terrain,
## forest, the cordon cabin, props, weather and the passing trains.

signal built

const PRESETS := {
	"dusk": {
		"zenith": Color(0.09, 0.14, 0.3), "horizon": Color(0.66, 0.56, 0.62), "ground": Color(0.25, 0.28, 0.36),
		"glow": Color(1.0, 0.5, 0.3), "sun_dir": Vector3(-0.75, -0.04, -0.66), "sun_disc": 0.0,
		"moon_dir": Vector3(0.5, 0.22, 0.84), "moon": 1.0, "stars": 0.25, "clouds": 0.3, "cloud_col": Color(0.3, 0.3, 0.42),
		"light_color": Color(0.62, 0.7, 0.98), "light_energy": 0.42, "light_dir": Vector3(0.5, 0.22, 0.84),
		"ambient": 0.55, "fog_color": Color(0.36, 0.4, 0.55), "fog_density": 0.0042, "exposure": 1.15,
		"vol_fog": 0.012, "vol_albedo": Color(0.7, 0.75, 0.9), "snow_rate": 0.55, "sparkle": 1.0, "mood": "evening",
	},
	"menu": {
		"zenith": Color(0.07, 0.11, 0.25), "horizon": Color(0.6, 0.5, 0.58), "ground": Color(0.22, 0.25, 0.33),
		"glow": Color(1.0, 0.48, 0.3), "sun_dir": Vector3(-0.3, -0.05, -0.95), "sun_disc": 0.0,
		"moon_dir": Vector3(0.35, 0.3, -0.88), "moon": 1.0, "stars": 0.4, "clouds": 0.25, "cloud_col": Color(0.26, 0.27, 0.38),
		"light_color": Color(0.6, 0.68, 0.98), "light_energy": 0.38, "light_dir": Vector3(0.35, 0.3, -0.88),
		"ambient": 0.5, "fog_color": Color(0.32, 0.36, 0.5), "fog_density": 0.005, "exposure": 1.1,
		"vol_fog": 0.014, "vol_albedo": Color(0.7, 0.75, 0.9), "snow_rate": 0.7, "sparkle": 1.0, "mood": "menu",
	},
	"morning": {
		"zenith": Color(0.26, 0.45, 0.76), "horizon": Color(0.9, 0.82, 0.8), "ground": Color(0.6, 0.62, 0.68),
		"glow": Color(1.0, 0.72, 0.5), "sun_dir": Vector3(0.45, 0.13, -0.88), "sun_disc": 1.0,
		"moon_dir": Vector3(-0.6, 0.4, 0.7), "moon": 0.15, "stars": 0.0, "clouds": 0.18, "cloud_col": Color(0.9, 0.86, 0.88),
		"light_color": Color(1.0, 0.82, 0.62), "light_energy": 1.7, "light_dir": Vector3(0.45, 0.13, -0.88),
		"ambient": 0.8, "fog_color": Color(0.78, 0.8, 0.88), "fog_density": 0.0028, "exposure": 0.95,
		"vol_fog": 0.008, "vol_albedo": Color(1.0, 0.95, 0.9), "snow_rate": 0.0, "sparkle": 3.0, "mood": "morning",
	},
	"night": {
		"zenith": Color(0.012, 0.02, 0.05), "horizon": Color(0.09, 0.11, 0.17), "ground": Color(0.04, 0.05, 0.07),
		"glow": Color(0.25, 0.2, 0.25), "sun_dir": Vector3(-0.5, -0.5, -0.5), "sun_disc": 0.0,
		"moon_dir": Vector3(0.3, 0.55, 0.78), "moon": 1.0, "stars": 1.0, "clouds": 0.2, "cloud_col": Color(0.07, 0.08, 0.12),
		"light_color": Color(0.58, 0.68, 1.0), "light_energy": 0.3, "light_dir": Vector3(0.3, 0.55, 0.78),
		"ambient": 0.32, "fog_color": Color(0.07, 0.09, 0.14), "fog_density": 0.006, "exposure": 1.35,
		"vol_fog": 0.01, "vol_albedo": Color(0.6, 0.65, 0.85), "snow_rate": 0.35, "sparkle": 1.6, "mood": "night",
	},
}

var preset_name := "dusk"
var menu_mode := false

var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var terrain: Terrain
var forest: Forest
var cabin: Cabin
var props: Props
var snowfall: GPUParticles3D
var train: Train
var birds: Birds
var footprints: Footprints
var wind_player: AudioStreamPlayer
var _follow: Node3D


func _ready() -> void:
	build()


func build() -> void:
	_build_environment()
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build()
	forest = Forest.new()
	forest.name = "Forest"
	add_child(forest)
	forest.build()
	cabin = Cabin.new()
	cabin.name = "Cabin"
	add_child(cabin)
	cabin.position = Layout.CABIN
	cabin.build()
	props = Props.new()
	props.name = "Props"
	add_child(props)
	props.build()
	train = Train.new()
	train.name = "Train"
	add_child(train)
	train.build()
	birds = Birds.new()
	birds.name = "Birds"
	add_child(birds)
	birds.build()
	footprints = Footprints.new()
	footprints.name = "Footprints"
	add_child(footprints)
	_build_snowfall()
	_build_boundary()
	wind_player = AudioStreamPlayer.new()
	wind_player.stream = Sfx.get_stream("wind")
	wind_player.bus = "Ambience"
	wind_player.volume_db = -8.0
	add_child(wind_player)
	wind_player.play()
	apply_preset(preset_name)
	Settings.changed.connect(_on_setting)
	_apply_graphics()
	built.emit()


func follow(node: Node3D) -> void:
	_follow = node


var _sky_t := 0.0
var _sky_acc := 0.0


func _process(delta: float) -> void:
	# advance the sky clock in coarse steps (cheap radiance updates)
	_sky_t += delta
	_sky_acc += delta
	if _sky_acc > 0.5 and sky_mat:
		_sky_acc = 0.0
		sky_mat.set_shader_parameter("sky_time", _sky_t)
	if _follow and snowfall:
		var p := _follow.global_position
		snowfall.global_position = Vector3(p.x, p.y + 9.0, p.z)


# --- environment ------------------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.35
	env.fog_height = 6.0
	env.fog_height_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.4)
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.92
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "SkyLight"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.6
	sun.shadow_blur = 1.2
	add_child(sun)


func apply_preset(pname: String, blend := 0.0) -> void:
	preset_name = pname
	var p: Dictionary = PRESETS[pname]
	if blend > 0.0:
		var t := create_tween().set_parallel()
		for k in ["zenith", "horizon", "glow", "cloud_col"]:
			var key: String = {"zenith": "zenith", "horizon": "horizon", "glow": "glow_col", "cloud_col": "cloud_col"}[k]
			t.tween_method(func(c: Color): sky_mat.set_shader_parameter(key, c), sky_mat.get_shader_parameter(key), p[k], blend)
		t.tween_property(sun, "light_energy", p["light_energy"], blend)
		t.tween_property(env, "fog_light_color", p["fog_color"], blend)
		t.tween_property(env, "fog_density", p["fog_density"], blend)
		return
	sky_mat.set_shader_parameter("zenith", p["zenith"])
	sky_mat.set_shader_parameter("horizon", p["horizon"])
	sky_mat.set_shader_parameter("ground_col", p["ground"])
	sky_mat.set_shader_parameter("glow_col", p["glow"])
	sky_mat.set_shader_parameter("sun_dir", p["sun_dir"])
	sky_mat.set_shader_parameter("sun_disc", p["sun_disc"])
	sky_mat.set_shader_parameter("moon_dir", p["moon_dir"])
	sky_mat.set_shader_parameter("moon_amount", p["moon"])
	sky_mat.set_shader_parameter("stars", p["stars"])
	sky_mat.set_shader_parameter("clouds", p["clouds"])
	sky_mat.set_shader_parameter("cloud_col", p["cloud_col"])
	sun.light_color = p["light_color"]
	sun.light_energy = p["light_energy"]
	var ld: Vector3 = p["light_dir"]
	sun.look_at_from_position(Vector3.ZERO, -ld.normalized(), Vector3.UP if absf(ld.normalized().y) < 0.99 else Vector3.FORWARD)
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = p["ambient"]
	env.fog_light_color = p["fog_color"]
	env.fog_density = p["fog_density"]
	env.volumetric_fog_density = p["vol_fog"]
	env.volumetric_fog_albedo = p["vol_albedo"]
	env.volumetric_fog_emission = Color(0, 0, 0)
	env.tonemap_exposure = p["exposure"] * float(Settings.get_value("brightness", 1.0))
	if snowfall:
		snowfall.amount_ratio = p["snow_rate"]
		snowfall.emitting = p["snow_rate"] > 0.0
	var gm := terrain.get_node("SnowMesh") as MeshInstance3D if terrain else null
	if gm:
		(gm.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("sparkle_strength", p["sparkle"])


func _on_setting(key: String) -> void:
	if key in ["ssao", "ssil", "volumetric_fog", "glow", "brightness", "draw_distance", "quality"]:
		_apply_graphics()


func _apply_graphics() -> void:
	env.ssao_enabled = Settings.get_value("ssao")
	env.ssil_enabled = Settings.get_value("ssil")
	env.volumetric_fog_enabled = Settings.get_value("volumetric_fog")
	env.glow_enabled = Settings.get_value("glow")
	env.tonemap_exposure = PRESETS[preset_name]["exposure"] * float(Settings.get_value("brightness", 1.0))
	var dd := int(Settings.get_value("draw_distance", 1))
	if forest:
		forest.set_draw_distance(dd)
	sun.directional_shadow_max_distance = [60.0, 100.0, 160.0][dd]


# --- weather -------------------------------------------------------------------------

func _build_snowfall() -> void:
	snowfall = GPUParticles3D.new()
	snowfall.name = "Snowfall"
	snowfall.amount = 9000
	snowfall.lifetime = 12.0
	snowfall.preprocess = 12.0
	snowfall.visibility_aabb = AABB(Vector3(-30, -25, -30), Vector3(60, 40, 60))
	snowfall.local_coords = false
	snowfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 6, 28)
	pm.direction = Vector3(0.15, -1, 0.05)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0.12, -0.55, 0.04)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.6
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.04
	pm.turbulence_influence_max = 0.12
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	snowfall.process_material = pm
	snowfall.collision_base_size = 0.02
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.92, 0.95, 1.0, 0.85)
	mat.albedo_texture = _soft_dot()
	mat.vertex_color_use_as_albedo = true
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.3
	quad.material = mat
	snowfall.draw_pass_1 = quad
	add_child(snowfall)
	# Keep snow out of the cabin.
	var col := GPUParticlesCollisionBox3D.new()
	col.size = Vector3(8.6, 7.0, 7.6)
	col.position = Layout.CABIN + Vector3(0, 2.5, 0)
	add_child(col)


static func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t


func _build_boundary() -> void:
	# A ring of invisible walls just inside the dense forest.
	var body := StaticBody3D.new()
	body.name = "Boundary"
	add_child(body)
	var segs := 48
	var r := Layout.PLAY_RADIUS + 8.0
	for i in segs:
		var a := TAU * (i + 0.5) / segs
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(TAU * r / segs + 2.0, 60.0, 2.0)
		cs.shape = bs
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = Layout.height(p.x, p.z)
		cs.transform = Transform3D(Basis(Vector3.UP, -a + PI * 0.5), p)
		body.add_child(cs)


## Indoors: thin the distance fog so the room doesn't look hazy, and drop
## the volumetric density (window light shafts stay, mostly from lamps).
func set_player_inside(inside: bool) -> void:
	var p: Dictionary = PRESETS[preset_name]
	var t := create_tween().set_parallel()
	t.tween_property(env, "fog_density", p["fog_density"] * (0.15 if inside else 1.0), 0.8)
	t.tween_property(env, "volumetric_fog_density", p["vol_fog"] * (0.35 if inside else 1.0), 0.8)
	if wind_player:
		t.tween_property(wind_player, "volume_db", -16.0 if inside else -8.0, 1.0)
