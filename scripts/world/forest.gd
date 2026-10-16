class_name Forest
extends Node3D
## Procedural winter forest: spruce, birch and pine meshes generated in code,
## scattered with MultiMesh, plus trunk collisions near the playable area.

const CHUNK := 48.0
const NEAR_RANGE := 110.0

var near_root: Node3D
var far_root: Node3D
var trees: Array = [] # [{pos: Vector3, r: float, kind: String}]
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 7
	near_root = Node3D.new()
	near_root.name = "Near"
	add_child(near_root)
	far_root = Node3D.new()
	far_root.name = "Far"
	add_child(far_root)

	var spruce_meshes := [_spruce_mesh(16.0, 15, 13, 1), _spruce_mesh(13.0, 13, 12, 2), _spruce_mesh(19.0, 17, 13, 3)]
	var spruce_far := _spruce_mesh(16.0, 6, 6, 4, true)
	var pine_far := _pine_low(20.0)
	var birch_far := _birch_low(14.0)
	var birch_meshes := [_birch_mesh(15.0, 5), _birch_mesh(12.0, 6)]
	var pine_meshes := [_pine_mesh(21.0, 8), _pine_mesh(18.0, 9)]
	var sapling := _spruce_mesh(3.2, 6, 9, 10)

	# Transforms bucketed per 48 m chunk so each chunk is frustum-culled and
	# can switch to a low-poly LOD at distance.
	var chunks := {} # Vector2i -> {mesh: [xf]}
	var far_chunks := {} # Vector2i -> [xf] (low-poly spruce impostors)
	var low_of := {}
	for m in spruce_meshes:
		low_of[m] = spruce_far
	for m in pine_meshes:
		low_of[m] = pine_far
	for m in birch_meshes:
		low_of[m] = birch_far

	# Poisson-ish scatter with a spatial hash.
	var grid := {}
	var cell := 3.0
	var attempts := 26000
	for a in attempts:
		var x := _rng.randf_range(-Layout.WORLD_HALF, Layout.WORLD_HALF)
		var z := _rng.randf_range(-Layout.WORLD_HALF, Layout.WORLD_HALF)
		var d := Vector2(x, z).length()
		if not Layout.tree_allowed(x, z):
			continue
		# density: clumpy, denser away from the clearing
		var clump := Layout._n_mid.get_noise_2d(x * 0.6, z * 0.6) * 0.5 + 0.5
		var density := clampf(0.25 + clump * 0.7 + smoothstep(30.0, 120.0, d) * 0.3, 0.0, 1.0)
		if _rng.randf() > density:
			continue
		var min_d := 3.2 if d < 160.0 else 4.5
		var gx := int(floor(x / cell))
		var gz := int(floor(z / cell))
		var ok := true
		for ox in range(-2, 3):
			for oz in range(-2, 3):
				var key := Vector2i(gx + ox, gz + oz)
				if grid.has(key):
					for q in grid[key]:
						if Vector2(x, z).distance_to(q) < min_d:
							ok = false
							break
				if not ok:
					break
			if not ok:
				break
		if not ok:
			continue
		var key0 := Vector2i(gx, gz)
		if not grid.has(key0):
			grid[key0] = []
		grid[key0].append(Vector2(x, z))

		var y := Layout.height(x, z)
		var s := _rng.randf_range(0.7, 1.25)
		var rot := Basis(Vector3.UP, _rng.randf() * TAU)
		# birches like the lower, wetter ground near the pond and clearing edges
		var birch_bias := 0.18 + (1.0 - smoothstep(20.0, 60.0, Vector2(x, z).distance_to(Layout.POND))) * 0.4 + (1.0 - smoothstep(18.0, 40.0, d)) * 0.2
		var roll := _rng.randf()
		var kind := "spruce"
		var mesh: Mesh
		if roll < birch_bias:
			kind = "birch"
			mesh = birch_meshes[_rng.randi() % birch_meshes.size()]
			rot = rot * Basis(Vector3(1, 0, 0), _rng.randf_range(-0.06, 0.06))
		elif roll < birch_bias + 0.16:
			kind = "pine"
			mesh = pine_meshes[_rng.randi() % pine_meshes.size()]
		else:
			mesh = spruce_meshes[_rng.randi() % spruce_meshes.size()]
		var xf := Transform3D(rot.scaled(Vector3(s, s * _rng.randf_range(0.9, 1.1), s)), Vector3(x, y - 0.3, z))
		var ck := Vector2i(int(floor(x / CHUNK)), int(floor(z / CHUNK)))
		if not chunks.has(ck):
			chunks[ck] = {}
		if not chunks[ck].has(mesh):
			chunks[ck][mesh] = []
		chunks[ck][mesh].append(xf)
		trees.append({"pos": Vector3(x, y, z), "r": (0.28 if kind != "birch" else 0.18) * s, "kind": kind})

	# saplings & young spruces at clearing edges
	var saplings := {}
	for a in 900:
		var x := _rng.randf_range(-160, 160)
		var z := _rng.randf_range(-160, 160)
		if not Layout.tree_allowed(x, z, -1.5):
			continue
		var s := _rng.randf_range(0.5, 1.4)
		var ck := Vector2i(int(floor(x / CHUNK)), int(floor(z / CHUNK)))
		if not saplings.has(ck):
			saplings[ck] = []
		saplings[ck].append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, Layout.height(x, z) - 0.1, z)))

	for ck in chunks:
		for mesh in chunks[ck]:
			var xfs: Array = chunks[ck][mesh]
			var near := _add_multimesh(near_root, mesh, xfs, true)
			near.visibility_range_end = NEAR_RANGE
			near.visibility_range_end_margin = 12.0
			near.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			var far := _add_multimesh(far_root, low_of[mesh], xfs, false)
			far.visibility_range_begin = NEAR_RANGE
			far.visibility_range_begin_margin = 12.0
	for ck in saplings:
		var sm := _add_multimesh(near_root, sapling, saplings[ck], true)
		sm.visibility_range_end = 90.0
	_build_collisions()


func _add_multimesh(parent: Node3D, mesh: Mesh, xfs: Array, shadows: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


func _build_collisions() -> void:
	var body := StaticBody3D.new()
	body.name = "TreeBodies"
	add_child(body)
	for t in trees:
		var p: Vector3 = t["pos"]
		if Vector2(p.x, p.z).length() > Layout.PLAY_RADIUS + 15.0:
			continue
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(t["r"], 0.15)
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = p + Vector3(0, 1.5, 0)
		body.add_child(cs)


func set_draw_distance(level: int) -> void:
	var far_end: float = [170.0, 320.0, 0.0][level]
	for c in far_root.get_children():
		(c as GeometryInstance3D).visibility_range_end = far_end


# --- tree meshes -----------------------------------------------------------------

static func _fv(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.set_uv(Vector2(p.x + p.z, p.y))
	st.add_vertex(p)


func _spruce_mesh(h: float, tiers: int, segs: int, seed_v: int, low := false) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 977
	var kit := MeshKit.new()
	kit.cyl("bark_spruce", Vector3(0, -0.5, 0), Vector3(0, h * (0.3 if low else 0.95), 0), 0.3 * h / 16.0, Color(1, 1, 1), 4 if low else 7, false, 0.03)
	var mesh := kit.build_mesh()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_y := 1.4 * h / 16.0
	var max_r := 3.3 * h / 16.0
	var outer_c := Color(0.15, 0.25, 0.16).srgb_to_linear()
	var inner_c := Color(0.05, 0.09, 0.06).srgb_to_linear()
	var under_c := Color(0.03, 0.05, 0.035).srgb_to_linear()
	for t_i in tiers:
		var t := float(t_i) / float(tiers - 1)
		var y := base_y + t * (h - base_y - 1.2 * h / 16.0)
		var radius := pow(1.0 - t, 1.05) * max_r + 0.35
		var th := (h - base_y) / tiers * 2.1
		var rot := r.randf() * TAU
		var outer: Array[Vector3] = []
		var mid: Array[Vector3] = []
		for s in segs:
			var ang := rot + TAU * s / segs
			var jag := (0.78 + 0.32 * r.randf()) if s % 2 == 0 else (0.6 + 0.2 * r.randf())
			var rr := radius * jag
			var droop := rr * 0.22 + r.randf() * 0.15
			outer.append(Vector3(cos(ang) * rr, y - droop, sin(ang) * rr))
			mid.append(Vector3(cos(ang) * rr * 0.55, y + th * 0.18, sin(ang) * rr * 0.55))
		var top := Vector3(0, y + th * 0.6, 0)
		var bottom := Vector3(0, y - th * 0.05, 0)
		for s in segs:
			var s2 := (s + 1) % segs
			var o0: Vector3 = outer[s]
			var o1: Vector3 = outer[s2]
			var m0: Vector3 = mid[s]
			var m1: Vector3 = mid[s2]
			var rad0 := Vector3(o0.x, 0, o0.z).normalized()
			var rad1 := Vector3(o1.x, 0, o1.z).normalized()
			var n0 := (rad0 * 0.55 + Vector3.UP * 0.8).normalized()
			var n1 := (rad1 * 0.55 + Vector3.UP * 0.8).normalized()
			var nt := Vector3.UP
			var co := Color(outer_c.r, outer_c.g, outer_c.b, 1.0)
			var cm := Color(lerpf(inner_c.r, outer_c.r, 0.6), lerpf(inner_c.g, outer_c.g, 0.6), lerpf(inner_c.b, outer_c.b, 0.6), 0.85)
			var ci := Color(inner_c.r, inner_c.g, inner_c.b, 0.45)
			# upper surface: outer -> mid
			_fv(st, o0, n0, co); _fv(st, o1, n1, co); _fv(st, m1, n1, cm)
			_fv(st, o0, n0, co); _fv(st, m1, n1, cm); _fv(st, m0, n0, cm)
			# upper surface: mid -> top
			_fv(st, m0, n0, cm); _fv(st, m1, n1, cm); _fv(st, top, nt, ci)
			# underside
			var cu := Color(under_c.r, under_c.g, under_c.b, 0.0)
			var nd0 := (rad0 * 0.6 - Vector3.UP * 0.5).normalized()
			var nd1 := (rad1 * 0.6 - Vector3.UP * 0.5).normalized()
			_fv(st, o0, nd0, cu); _fv(st, bottom, -Vector3.UP, cu); _fv(st, o1, nd1, cu)
	# top spike
	var tip := Vector3(0, h, 0)
	for s in 5:
		var a0 := TAU * s / 5.0
		var a1 := TAU * (s + 1) / 5.0
		var y0 := h - 1.4 * h / 16.0
		var p0 := Vector3(cos(a0) * 0.35, y0, sin(a0) * 0.35)
		var p1 := Vector3(cos(a1) * 0.35, y0, sin(a1) * 0.35)
		var c := Color(outer_c.r, outer_c.g, outer_c.b, 0.9)
		_fv(st, p0, (p0 + Vector3.UP).normalized(), c); _fv(st, p1, (p1 + Vector3.UP).normalized(), c); _fv(st, tip, Vector3.UP, c)
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, Mats.get_mat("foliage"))
	return mesh


func _birch_mesh(h: float, seed_v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 131
	var kit := MeshKit.new()
	# slightly crooked trunk in three segments
	var p0 := Vector3(0, -0.5, 0)
	var p1 := Vector3(r.randf_range(-0.2, 0.2), h * 0.4, r.randf_range(-0.2, 0.2))
	var p2 := p1 + Vector3(r.randf_range(-0.3, 0.3), h * 0.35, r.randf_range(-0.3, 0.3))
	var p3 := p2 + Vector3(r.randf_range(-0.3, 0.3), h * 0.25, r.randf_range(-0.3, 0.3))
	kit.cyl("bark_birch", p0, p1, 0.19, Color.WHITE, 9, false, 0.15)
	kit.cyl("bark_birch", p1, p2, 0.15, Color.WHITE, 8, false, 0.09)
	kit.cyl("bark_birch", p2, p3, 0.09, Color.WHITE, 6, false, 0.02)
	var crown_pts: Array[Vector3] = []
	for b in 16:
		var t := r.randf_range(0.42, 0.92)
		var base := p1.lerp(p3, (t - 0.4) / 0.6) if t > 0.4 else p0.lerp(p1, t / 0.4)
		var ang := r.randf() * TAU
		var up := r.randf_range(0.5, 1.1)
		var length := r.randf_range(1.6, 3.6) * (1.2 - t * 0.5)
		var dir := Vector3(cos(ang), up, sin(ang)).normalized()
		var tip := base + dir * length
		kit.cyl("bark_birch", base, tip, 0.055, Color(0.55, 0.5, 0.48), 5, false, 0.012)
		# drooping twigs
		for k in 3:
			var tb := base.lerp(tip, r.randf_range(0.4, 0.95))
			var tt := tb + Vector3(r.randf_range(-0.6, 0.6), -r.randf_range(0.6, 1.6), r.randf_range(-0.6, 0.6))
			kit.cyl("bark_birch", tb, tt, 0.015, Color(0.25, 0.18, 0.16), 3, false, 0.004)
		crown_pts.append(tip)
	# fine twig clouds
	for tip in crown_pts:
		if r.randf() < 0.65:
			kit.sphere("twigs", tip + Vector3(0, -0.4, 0), Vector3(1.2, 1.4, 1.2) * r.randf_range(0.8, 1.3), Color(0.32, 0.22, 0.2), 5, 8)
	return kit.build_mesh()


func _pine_mesh(h: float, seed_v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v * 53
	var kit := MeshKit.new()
	var top := Vector3(r.randf_range(-0.4, 0.4), h, r.randf_range(-0.4, 0.4))
	kit.cyl("bark_pine", Vector3(0, -0.5, 0), top, 0.3, Color.WHITE, 8, false, 0.06)
	var mesh := kit.build_mesh()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := Color(0.17, 0.27, 0.15).srgb_to_linear()
	for c in 9:
		var t := r.randf_range(0.62, 0.98)
		var base := Vector3(0, -0.5, 0).lerp(top, t)
		var ang := r.randf() * TAU
		var length := r.randf_range(1.0, 3.2) * (1.15 - t * 0.6)
		var tip := base + Vector3(cos(ang) * length, r.randf_range(0.2, 0.8), sin(ang) * length)
		_blob(st, tip, Vector3(1.25, 0.55, 1.25) * r.randf_range(0.8, 1.3), green, r)
		_blob(st, tip.lerp(base, 0.4) + Vector3(0, 0.15, 0), Vector3(0.8, 0.4, 0.8), green, r)
	_blob(st, top + Vector3(0, 0.3, 0), Vector3(1.1, 0.7, 1.1), green, r)
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, Mats.get_mat("foliage"))
	# branches
	var bk := MeshKit.new()
	var r2 := RandomNumberGenerator.new()
	r2.seed = seed_v * 53
	r2.randf_range(-0.4, 0.4); r2.randf_range(-0.4, 0.4)
	for c in 9:
		var t := r2.randf_range(0.62, 0.98)
		var base := Vector3(0, -0.5, 0).lerp(top, t)
		var ang := r2.randf() * TAU
		var length := r2.randf_range(1.0, 3.2) * (1.15 - t * 0.6)
		var tip := base + Vector3(cos(ang) * length, r2.randf_range(0.2, 0.8), sin(ang) * length)
		r2.randf_range(0.8, 1.3)
		bk.cyl("bark_pine", base, tip, 0.08, Color.WHITE, 5, false, 0.03)
	var bmesh := bk.build_mesh()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, bmesh.surface_get_arrays(0))
	mesh.surface_set_material(mesh.get_surface_count() - 1, Mats.get_mat("bark_pine"))
	return mesh


func _blob(st: SurfaceTool, c: Vector3, rad: Vector3, col: Color, r: RandomNumberGenerator) -> void:
	var rings := 5
	var segs := 8
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in segs:
			var ph0 := TAU * j / segs
			var ph1 := TAU * (j + 1) / segs
			var pts := [MeshKit._sp(t0, ph0), MeshKit._sp(t0, ph1), MeshKit._sp(t1, ph1), MeshKit._sp(t1, ph0)]
			for k in [0, 2, 1, 0, 3, 2]:
				var u: Vector3 = pts[k]
				var jitter := 0.85 + 0.3 * absf(sin(u.x * 7.0 + u.z * 5.0 + c.x))
				var p := c + u * rad * jitter
				var exposure := clampf(u.y * 0.8 + 0.4, 0.0, 1.0)
				_fv(st, p, u, Color(col.r, col.g, col.b, exposure))


## Distant pine: a bare trunk with one flattened crown blob.
func _pine_low(h: float) -> ArrayMesh:
	var kit := MeshKit.new()
	kit.cyl("bark_pine", Vector3(0, -0.5, 0), Vector3(0, h, 0), 0.3, Color.WHITE, 4, false, 0.08)
	var mesh := kit.build_mesh()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	_blob(st, Vector3(0, h - 1.5, 0), Vector3(2.4, 1.3, 2.4), Color(0.17, 0.27, 0.15).srgb_to_linear(), r)
	st.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, Mats.get_mat("foliage"))
	return mesh


## Distant birch: trunk plus a single twig haze.
func _birch_low(h: float) -> ArrayMesh:
	var kit := MeshKit.new()
	kit.cyl("bark_birch", Vector3(0, -0.5, 0), Vector3(0, h, 0), 0.17, Color.WHITE, 5, false, 0.03)
	kit.sphere("twigs", Vector3(0, h * 0.72, 0), Vector3(2.4, 3.4, 2.4), Color(0.32, 0.22, 0.2), 5, 8)
	return kit.build_mesh()
