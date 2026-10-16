class_name Layout
extends RefCounted
## World layout and the terrain height function shared by everything that
## needs to sit on the ground.

const WORLD_HALF := 240.0
const PLAY_RADIUS := 150.0

const CABIN := Vector3(0, 0, 0)
const CABIN_GROUND := 0.0
const CLEARING_R := 15.0

const RAIL_Z := 92.0
const RAIL_H := -0.6
const PLATFORM_MIN := Vector2(-34.0, 86.6)
const PLATFORM_MAX := Vector2(-8.0, 89.6)

const POND := Vector2(46.0, -40.0)
const POND_R := 13.0
const POND_H := -1.6

const BIRCH_OF_KOSTYA := Vector2(36.5, -29.0)
const FEEDER := Vector2(-4.2, 6.2)
const WELL := Vector2(-7.5, -3.5)

## The path from the platform up to the porch.
const PATH := [
	Vector2(-20.0, 86.0), Vector2(-17.0, 74.0), Vector2(-9.0, 60.0), Vector2(-10.0, 46.0),
	Vector2(-4.0, 32.0), Vector2(0.0, 20.0), Vector2(1.6, 11.0), Vector2(1.9, 5.2),
]
## Side path from the yard to the pond and the old birch.
const PATH_POND := [
	Vector2(4.0, -6.0), Vector2(12.0, -12.0), Vector2(22.0, -20.0), Vector2(31.0, -26.0), Vector2(38.0, -31.0),
]

static var _n_large: FastNoiseLite
static var _n_mid: FastNoiseLite
static var _n_fine: FastNoiseLite


static func _init_noise() -> void:
	if _n_large:
		return
	_n_large = FastNoiseLite.new()
	_n_large.seed = 1991
	_n_large.frequency = 0.006
	_n_large.fractal_octaves = 3
	_n_mid = FastNoiseLite.new()
	_n_mid.seed = 25
	_n_mid.frequency = 0.03
	_n_mid.fractal_octaves = 2
	_n_fine = FastNoiseLite.new()
	_n_fine.seed = 12
	_n_fine.frequency = 0.15
	_n_fine.fractal_octaves = 1


static func height(x: float, z: float) -> float:
	_init_noise()
	var h := _n_large.get_noise_2d(x, z) * 9.0 + _n_mid.get_noise_2d(x, z) * 1.6 + _n_fine.get_noise_2d(x, z) * 0.15
	# hills rising at the edge of the world close the view naturally
	var d := Vector2(x, z).length()
	h += smoothstep(150.0, 235.0, d) * 22.0
	# cabin clearing
	var dc := Vector2(x - CABIN.x, z - CABIN.z).length()
	h = lerpf(h, CABIN_GROUND, 1.0 - smoothstep(CLEARING_R - 2.0, CLEARING_R + 14.0, dc))
	# frozen pond
	var dp := Vector2(x, z).distance_to(POND)
	h = lerpf(h, POND_H - 0.4, 1.0 - smoothstep(POND_R - 1.0, POND_R + 7.0, dp))
	# railway embankment
	var dz := absf(z - RAIL_Z)
	h = lerpf(h, RAIL_H, 1.0 - smoothstep(6.0, 18.0, dz))
	h += (1.0 - smoothstep(2.2, 5.5, dz)) * 0.9
	# platform area flattened
	if x > PLATFORM_MIN.x - 6.0 and x < PLATFORM_MAX.x + 6.0:
		var near := 1.0 - smoothstep(0.0, 6.0, maxf(PLATFORM_MIN.x - x, x - PLATFORM_MAX.x))
		h = lerpf(h, RAIL_H + 0.3, near * (1.0 - smoothstep(3.0, 9.0, absf(z - 84.0))))
	# path: gently soften the ground along it
	var dpath := path_distance(Vector2(x, z))
	if dpath < 6.0:
		var local := h
		h = lerpf(h, local * 0.85, 1.0 - smoothstep(0.0, 6.0, dpath))
	return h


static func path_distance(p: Vector2) -> float:
	return minf(_poly_dist(p, PATH), _poly_dist(p, PATH_POND))


static func _poly_dist(p: Vector2, poly: Array) -> float:
	var best := 1e9
	for i in poly.size() - 1:
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func ground(x: float, z: float) -> Vector3:
	return Vector3(x, height(x, z), z)


static func normal(x: float, z: float) -> Vector3:
	var e := 0.5
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## Can a tree grow here?
static func tree_allowed(x: float, z: float, margin := 0.0) -> bool:
	var p := Vector2(x, z)
	if p.length() > WORLD_HALF - 4.0:
		return false
	if p.distance_to(Vector2(CABIN.x, CABIN.z)) < CLEARING_R + 3.0 + margin:
		return false
	if p.distance_to(POND) < POND_R + 3.0 + margin:
		return false
	if absf(z - RAIL_Z) < 9.0 + margin:
		return false
	if path_distance(p) < 2.6 + margin:
		return false
	return true
