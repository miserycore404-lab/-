class_name Terrain
extends Node3D
## Snow terrain mesh + heightmap collision built from Layout.height().

const CELL := 2.0
const RES := 240 # cells per side -> 480 m


func build() -> void:
	var half := RES * CELL * 0.5
	var n := RES + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = Layout.height(-half + i * CELL, -half + j * CELL)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	uvs.resize(n * n)
	for j in n:
		for i in n:
			var x := -half + i * CELL
			var z := -half + j * CELL
			var h := heights[j * n + i]
			verts[j * n + i] = Vector3(x, h, z)
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, n - 1) * n + i]
			normals[j * n + i] = Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			var pd := Layout.path_distance(Vector2(x, z))
			var path := 1.0 - smoothstep(0.6, 2.4, pd)
			# yard around the cabin is trodden too
			var yard := 1.0 - smoothstep(5.0, 9.0, Vector2(x - 0.5, z - 3.0).length())
			var plat := 0.0
			if absf(z - Layout.RAIL_Z) < 3.0:
				plat = 0.6
			colors[j * n + i] = Color(clampf(maxf(maxf(path, yard * 0.6), plat), 0.0, 1.0), 0.0, 0.0, 1.0)
			uvs[j * n + i] = Vector2(x, z)
	var idx := PackedInt32Array()
	idx.resize(RES * RES * 6)
	var k := 0
	for j in RES:
		for i in RES:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			idx[k] = a; idx[k + 1] = b; idx[k + 2] = c
			idx[k + 3] = b; idx[k + 4] = d; idx[k + 5] = c
			k += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/snow_ground.gdshader")
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "SnowMesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	# collision: uniform scale so heights are divided by CELL
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	var data := PackedFloat32Array()
	data.resize(n * n)
	for i in n * n:
		data[i] = heights[i] / CELL
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(CELL, CELL, CELL)
	body.add_child(cs)
	add_child(body)

	_build_pond()


func _build_pond() -> void:
	# Frozen pond: dark ice with wind-polished clear patches and snow drifts.
	var mi := MeshInstance3D.new()
	mi.name = "PondIce"
	var disc := CylinderMesh.new()
	disc.top_radius = Layout.POND_R + 2.0
	disc.bottom_radius = Layout.POND_R + 2.0
	disc.height = 0.1
	disc.radial_segments = 48
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ice.gdshader")
	disc.material = mat
	mi.mesh = disc
	mi.position = Vector3(Layout.POND.x, Layout.POND_H - 0.02, Layout.POND.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = Layout.POND_R + 2.0
	cyl.height = 0.1
	cs.shape = cyl
	body.add_child(cs)
	body.position = mi.position
	add_child(body)
