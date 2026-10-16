class_name MeshKit
extends RefCounted
## Batches procedural primitives into a single ArrayMesh with one surface
## per material. UVs are in metres: U runs along the longest dimension
## (wood grain), V across it. Vertex colour alpha = 0 marks end-grain caps.

var _tools := {}   # material key -> SurfaceTool
var _mats := {}    # material key -> Material


func _st(mat_key: String) -> SurfaceTool:
	if not _tools.has(mat_key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[mat_key] = st
		_mats[mat_key] = Mats.get_mat(mat_key)
	return _tools[mat_key]


func _vert(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)


func quad(mat_key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, uv_scale := 1.0) -> void:
	# a-b-c-d counter-clockwise when seen from the front
	var st := _st(mat_key)
	var n := (b - a).cross(d - a).normalized()
	var lc := col.srgb_to_linear()
	var w := a.distance_to(b) * uv_scale
	var h := a.distance_to(d) * uv_scale
	_vert(st, a, n, Vector2(0, h), lc)
	_vert(st, c, n, Vector2(w, 0), lc)
	_vert(st, b, n, Vector2(w, h), lc)
	_vert(st, a, n, Vector2(0, h), lc)
	_vert(st, d, n, Vector2(0, 0), lc)
	_vert(st, c, n, Vector2(w, 0), lc)


func tri(mat_key: String, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var st := _st(mat_key)
	var n := (b - a).cross(c - a).normalized()
	var lc := col.srgb_to_linear()
	_vert(st, a, n, Vector2(a.x + a.z, a.y), lc)
	_vert(st, c, n, Vector2(c.x + c.z, c.y), lc)
	_vert(st, b, n, Vector2(b.x + b.z, b.y), lc)


## Axis-aligned (in local space of `xf`) box of `size`, centred on xf.origin.
func box(mat_key: String, xf: Transform3D, size: Vector3, col: Color) -> void:
	var st := _st(mat_key)
	var h := size * 0.5
	var lc := col.srgb_to_linear()
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	var basis := xf.basis
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var hn := absf(n.dot(h))
		# grain along the longer world dimension of the box
		var su := absf(u.dot(size))
		var sv := absf(v.dot(size))
		var swap := sv > su
		var center := n * hn
		var corners := [
			center - u * hu - v * hv,
			center + u * hu - v * hv,
			center + u * hu + v * hv,
			center - u * hu + v * hv,
		]
		var uvs := [Vector2(0, 0), Vector2(su, 0), Vector2(su, sv), Vector2(0, sv)]
		if swap:
			uvs = [Vector2(0, 0), Vector2(0, su), Vector2(sv, su), Vector2(sv, 0)]
		var wn := (basis * n).normalized()
		var idx := [0, 2, 1, 0, 3, 2]
		for i in idx:
			var p: Vector3 = xf * corners[i]
			_vert(st, p, wn, uvs[i] + Vector2(xf.origin.x * 0.37 + xf.origin.z * 0.51, xf.origin.y * 0.73), lc)


## Convenience: box from min/max corners (axis aligned, untransformed).
func box_mm(mat_key: String, mn: Vector3, mx: Vector3, col: Color) -> void:
	box(mat_key, Transform3D(Basis(), (mn + mx) * 0.5), mx - mn, col)


## Cylinder (optionally tapered) from a to b.
func cyl(mat_key: String, a: Vector3, b: Vector3, r: float, col: Color, segs := 10, caps := true, r2 := -1.0, cap_col := Color(-1, 0, 0)) -> void:
	if r2 < 0.0:
		r2 = r
	var st := _st(mat_key)
	var axis := b - a
	var length := axis.length()
	if length < 0.0001:
		return
	var dir := axis / length
	var ref := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x := dir.cross(ref).normalized()
	var y := dir.cross(x).normalized()
	var lc := col.srgb_to_linear()
	var circ := TAU * r
	var slope := (r - r2) / length
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := x * cos(a0) + y * sin(a0)
		var d1 := x * cos(a1) + y * sin(a1)
		var n0 := (d0 + dir * slope).normalized()
		var n1 := (d1 + dir * slope).normalized()
		var v0 := circ * i / segs
		var v1 := circ * (i + 1) / segs
		var p00 := a + d0 * r
		var p01 := a + d1 * r
		var p10 := b + d0 * r2
		var p11 := b + d1 * r2
		_vert(st, p00, n0, Vector2(0, v0), lc)
		_vert(st, p11, n1, Vector2(length, v1), lc)
		_vert(st, p10, n0, Vector2(length, v0), lc)
		_vert(st, p00, n0, Vector2(0, v0), lc)
		_vert(st, p01, n1, Vector2(0, v1), lc)
		_vert(st, p11, n1, Vector2(length, v1), lc)
	if caps:
		var cc := lc if cap_col.r < 0.0 else cap_col.srgb_to_linear()
		var end_col := Color(cc.r, cc.g, cc.b, 0.0)
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var d0 := x * cos(a0) + y * sin(a0)
			var d1 := x * cos(a1) + y * sin(a1)
			# bottom cap (facing -dir)
			_vert(st, a, -dir, Vector2.ZERO, end_col)
			_vert(st, a + d0 * r, -dir, Vector2(cos(a0), sin(a0)) * r, end_col)
			_vert(st, a + d1 * r, -dir, Vector2(cos(a1), sin(a1)) * r, end_col)
			# top cap
			_vert(st, b, dir, Vector2.ZERO, end_col)
			_vert(st, b + d1 * r2, dir, Vector2(cos(a1), sin(a1)) * r2, end_col)
			_vert(st, b + d0 * r2, dir, Vector2(cos(a0), sin(a0)) * r2, end_col)


## Ellipsoid centred at c with radii rad.
func sphere(mat_key: String, c: Vector3, rad: Vector3, col: Color, rings := 8, segs := 12, basis := Basis()) -> void:
	var st := _st(mat_key)
	var lc := col.srgb_to_linear()
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in segs:
			var p0 := TAU * j / segs
			var p1 := TAU * (j + 1) / segs
			var pts := [_sp(t0, p0), _sp(t0, p1), _sp(t1, p1), _sp(t1, p0)]
			for k in [0, 2, 1, 0, 3, 2]:
				var u: Vector3 = pts[k]
				var p := c + basis * (u * rad)
				var n := (basis * (u / rad)).normalized()
				_vert(st, p, n, Vector2(p0 * rad.x, t0 * rad.y), lc)


static func _sp(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


## Torus in the XZ plane of `basis`, centred at c.
func torus(mat_key: String, c: Vector3, big_r: float, small_r: float, col: Color, segs := 20, sides := 8, basis := Basis(), arc := TAU) -> void:
	var st := _st(mat_key)
	var lc := col.srgb_to_linear()
	for i in segs:
		var a0 := arc * i / segs
		var a1 := arc * (i + 1) / segs
		for j in sides:
			var b0 := TAU * j / sides
			var b1 := TAU * (j + 1) / sides
			var q := [_tp(a0, b0, big_r, small_r), _tp(a1, b0, big_r, small_r), _tp(a1, b1, big_r, small_r), _tp(a0, b1, big_r, small_r)]
			var ns := [_tn(a0, b0), _tn(a1, b0), _tn(a1, b1), _tn(a0, b1)]
			for k in [0, 2, 1, 0, 3, 2]:
				_vert(st, c + basis * q[k], basis * ns[k], Vector2(a0 * big_r, b0 * small_r), lc)


static func _tp(a: float, b: float, R: float, r: float) -> Vector3:
	return Vector3((R + r * cos(b)) * cos(a), r * sin(b), (R + r * cos(b)) * sin(a))


static func _tn(a: float, b: float) -> Vector3:
	return Vector3(cos(b) * cos(a), sin(b), cos(b) * sin(a))


## Surface of revolution around local Y. profile: Array of Vector2(radius, y).
func lathe(mat_key: String, xf: Transform3D, profile: Array, col: Color, segs := 16, smooth := true) -> void:
	var st := _st(mat_key)
	var lc := col.srgb_to_linear()
	for i in profile.size() - 1:
		var p0: Vector2 = profile[i]
		var p1: Vector2 = profile[i + 1]
		var e := p1 - p0
		var pn := Vector2(e.y, -e.x).normalized()
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			var c0 := Vector3(cos(a0), 0, sin(a0))
			var c1 := Vector3(cos(a1), 0, sin(a1))
			var v := [c0 * p0.x + Vector3.UP * p0.y, c1 * p0.x + Vector3.UP * p0.y, c1 * p1.x + Vector3.UP * p1.y, c0 * p1.x + Vector3.UP * p1.y]
			var n := [c0 * pn.x + Vector3.UP * pn.y, c1 * pn.x + Vector3.UP * pn.y, c1 * pn.x + Vector3.UP * pn.y, c0 * pn.x + Vector3.UP * pn.y]
			for k in [0, 2, 1, 0, 3, 2]:
				_vert(st, xf * v[k], (xf.basis * n[k]).normalized(), Vector2(a0 * p0.x, p0.y), lc)


func is_empty() -> bool:
	return _tools.is_empty()


func build_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in _tools:
		var st: SurfaceTool = _tools[key]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[key])
	return mesh


func build(parent: Node3D, node_name := "Mesh", shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = build_mesh()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
