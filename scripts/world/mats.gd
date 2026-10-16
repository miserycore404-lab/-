class_name Mats
extends RefCounted
## Shared material registry keyed by short names used by MeshKit.

static var _cache := {}


static func get_mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m := _make(key)
	_cache[key] = m
	return m


static func _shader(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func _std(rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic = metal
	return m


static func _make(key: String) -> Material:
	match key:
		"wood":
			return _shader("res://shaders/wood.gdshader", {"weathering": 0.08, "snow_amount": 0.0})
		"wood_ext":
			return _shader("res://shaders/wood.gdshader", {"weathering": 0.5, "snow_amount": 0.4})
		"wood_dry":
			return _shader("res://shaders/wood.gdshader", {"weathering": 0.35, "snow_amount": 0.0})
		"plain":
			return _std(0.88)
		"paint":
			var m := _std(0.55)
			m.clearcoat_enabled = true
			m.clearcoat = 0.2
			return m
		"gloss":
			return _std(0.25)
		"ceramic":
			var m := _std(0.18)
			m.clearcoat_enabled = true
			m.clearcoat = 0.6
			return m
		"metal":
			return _std(0.42, 0.75)
		"metal_rough":
			return _std(0.7, 0.55)
		"chrome":
			return _std(0.12, 1.0)
		"fabric":
			var m := _std(1.0)
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.6
			return m
		"plaster":
			return _shader("res://shaders/plaster.gdshader")
		"brick":
			return _shader("res://shaders/brick.gdshader")
		"snow":
			return _shader("res://shaders/snow_obj.gdshader")
		"twigs_solid":
			return _std(1.0)
		"twigs":
			return _shader("res://shaders/twigs.gdshader")
		"foliage":
			return _shader("res://shaders/foliage.gdshader")
		"bark_spruce":
			return _shader("res://shaders/bark.gdshader", {"mode": 0})
		"bark_birch":
			return _shader("res://shaders/bark.gdshader", {"mode": 1})
		"bark_pine":
			return _shader("res://shaders/bark.gdshader", {"mode": 2})
		"glass":
			return _shader("res://shaders/window_glass.gdshader")
		"glass_clear":
			var m := StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.85, 0.9, 0.85, 0.28)
			m.roughness = 0.05
			m.metallic_specular = 0.9
			m.vertex_color_use_as_albedo = true
			return m
		"emissive":
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.emission_enabled = true
			m.emission = Color(1.0, 0.72, 0.4)
			m.emission_energy_multiplier = 2.5
			return m
		"lit_window":
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.55, 0.45, 0.32)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.76, 0.46)
			m.emission_energy_multiplier = 0.55
			m.roughness = 0.15
			return m
		"unshaded":
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			return m
		"carpet":
			return _shader("res://shaders/carpet.gdshader")
		"oilcloth":
			return _shader("res://shaders/oilcloth.gdshader")
		"skin":
			var m := _std(0.6)
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.35
			m.rim_enabled = true
			m.rim = 0.2
			return m
		"quilt":
			return _shader("res://shaders/quilt.gdshader")
		"ice":
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.62, 0.74, 0.84)
			m.roughness = 0.08
			m.metallic_specular = 0.8
			m.vertex_color_use_as_albedo = true
			return m
		"icicle":
			var m := StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.85, 0.92, 1.0, 0.65)
			m.roughness = 0.05
			m.vertex_color_use_as_albedo = true
			m.rim_enabled = true
			return m
	push_warning("Unknown material key " + key)
	return _std()
