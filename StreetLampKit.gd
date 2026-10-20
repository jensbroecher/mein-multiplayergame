extends RefCounted
## A street light at life size (8.9m pole, 2.3m swan-neck arm), built through a PropKit: a base plate with
## bolts and a sleeve with a service door, a tapered round pole with collars, a swept arm with a brace, and a
## cobra-head luminaire: a lofted aluminium shell, a dark underside and a glowing lens, with a photocell
## on top. The pole stands at the origin and the arm reaches along +x; the caller turns and scales it
## (Nyota Stadium places it at LAMP_SCALE, 1.35, with the arm over the road).
##
## Four material keys (`make_material`): `paint` (powder-coated pole), `metal` (galvanised and aluminium
## parts), `matte` (the underside, the photocell, rubber) and `lamp` (the emissive lens).

const PropKit = preload("res://PropKit.gd")

const PAINT := Color(0.20, 0.22, 0.24)
const PAINT_DARK := Color(0.10, 0.11, 0.12)
const GALV := Color(0.62, 0.64, 0.66)
const ALUM := Color(0.68, 0.70, 0.72)
const DARK := Color(0.05, 0.05, 0.06)
const LENS := Color(1.0, 0.96, 0.84)

const POLE_TOP := 8.55
## The luminaire: rear end x, length, and the height of its underside.
const LUM_X0 := 2.05
const LUM_LEN := 1.12
const LUM_Y := 8.93
const RING_PTS := 13
## Cross-sections along the luminaire (fractions of its length).
const LUM_STATIONS := [0.0, 0.02, 0.08, 0.2, 0.4, 0.6, 0.8, 0.93, 0.985, 1.0]

var _k: PropKit
var _kit := {}


func _init(kit: PropKit) -> void:
	_k = kit


static func make_material(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.6
	match key:
		"paint":
			m.roughness = 0.45
			m.metallic = 0.3
		"metal":
			m.roughness = 0.36
			m.metallic = 0.8
		"matte":
			m.roughness = 0.8
		"lamp":
			# One colour, so plain additive emission: the lens glows whatever the light on it.
			m.emission_enabled = true
			m.emission = Color(1.0, 0.95, 0.80)
			m.emission_energy_multiplier = 2.2
			m.roughness = 0.2
	return m


## The whole lamp as one mesh, through the PropKit's current frame.
func build() -> ArrayMesh:
	_kit = {}
	_build_base()
	_build_pole()
	_build_arm()
	_build_luminaire()
	return _k.commit(_kit)


# ---------------------------------------------------------------------------------------------
#  Base and pole
# ---------------------------------------------------------------------------------------------

func _build_base() -> void:
	# A steel base plate with four bolts, and the sleeve over the foot of the pole with its service door.
	_k.lathe(_kit, "metal", Vector3.ZERO, [Vector2(0.235, 0.0), Vector2(0.235, 0.03), Vector2(0.205, 0.036)], 16, GALV)
	for i in range(4):
		var a := PI * 0.25 + PI * 0.5 * float(i)
		var p := Vector3(cos(a) * 0.17, 0.034, sin(a) * 0.17)
		_k.tube(_kit, "metal", p, p + Vector3(0, 0.03, 0), 0.02, 0.02, 6, GALV)
	_k.tube(_kit, "paint", Vector3(0, 0.034, 0), Vector3(0, 0.95, 0), 0.185, 0.134, 16, PAINT, false)
	# The collar where the sleeve meets the pole.
	_k.lathe(_kit, "metal", Vector3(0, 0.95, 0), [Vector2(0.142, 0.0), Vector2(0.158, 0.012), Vector2(0.158, 0.03), Vector2(0.10, 0.07)], 16, GALV)
	# The service door, on the side away from the arm, with a handle and a seam round it.
	_k.block(_kit, "matte", Vector3(-0.176, 0.26, -0.09), Vector3(-0.145, 0.74, 0.09), PAINT_DARK)
	_k.block(_kit, "paint", Vector3(-0.181, 0.275, -0.075), Vector3(-0.176, 0.725, 0.075), PAINT)
	_k.block(_kit, "metal", Vector3(-0.19, 0.48, 0.04), Vector3(-0.181, 0.56, 0.055), GALV)


func _build_pole() -> void:
	_k.tube(_kit, "paint", Vector3(0, 0.99, 0), Vector3(0, POLE_TOP, 0), 0.098, 0.062, 14, PAINT, false)
	# Joint collars.
	for y in [3.4, 6.0]:
		var r := lerpf(0.098, 0.062, (y - 0.99) / (POLE_TOP - 0.99)) + 0.004
		_k.lathe(_kit, "metal", Vector3(0, y, 0), [Vector2(r, 0.0), Vector2(r + 0.014, 0.008), Vector2(r + 0.014, 0.034), Vector2(r, 0.042)], 14, GALV)


# ---------------------------------------------------------------------------------------------
#  Arm
# ---------------------------------------------------------------------------------------------

## The arm's centre line: up out of the pole, over, and down a little to the luminaire.
static func _arm_pt(t: float) -> Vector3:
	var p0 := Vector3(0.0, POLE_TOP - 0.05, 0.0)
	var p1 := Vector3(0.0, 9.40, 0.0)
	var p2 := Vector3(0.95, 9.58, 0.0)
	var p3 := Vector3(2.25, 9.17, 0.0)
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


func _build_arm() -> void:
	var n := 22
	for i in range(n):
		var t0 := float(i) / float(n)
		var t1 := float(i + 1) / float(n)
		_k.tube(_kit, "paint", _arm_pt(t0), _arm_pt(t1), lerpf(0.064, 0.044, t0), lerpf(0.064, 0.044, t1), 10, PAINT, i == n - 1)
	# A cap over the pole's top where the arm leaves it, and a brace from the pole up to the arm.
	_k.lathe(_kit, "metal", Vector3(0, POLE_TOP - 0.2, 0), [Vector2(0.070, 0.0), Vector2(0.080, 0.02), Vector2(0.080, 0.07), Vector2(0.062, 0.12)], 12, GALV)
	_k.tube(_kit, "paint", Vector3(0, 7.85, 0), _arm_pt(0.6), 0.030, 0.025, 7, PAINT)
	# The bracket that drops from the arm's end onto the luminaire's back.
	var top_y := LUM_Y + _lum_h((2.25 - LUM_X0) / LUM_LEN)
	_k.tube(_kit, "metal", Vector3(2.25, 9.17, 0), Vector3(2.25, top_y - 0.01, 0), 0.040, 0.046, 8, GALV)


# ---------------------------------------------------------------------------------------------
#  Luminaire
# ---------------------------------------------------------------------------------------------

## Half width and height of the shell at fraction t of its length: broad at the arm, tapering to the tip.
static func _lum_w(t: float) -> float:
	if t < 0.22:
		return lerpf(0.185, 0.215, t / 0.22)
	return lerpf(0.215, 0.115, smoothstep(0.22, 1.0, t))


static func _lum_h(t: float) -> float:
	return lerpf(0.15, 0.072, smoothstep(0.3, 1.0, t))


## The ends round off: the section shrinks to a quarter of itself over the last stretch.
static func _lum_cap(t: float) -> float:
	var s_rear := sqrt(maxf(1.0 - pow(1.0 - clampf(t / 0.07, 0.0, 1.0), 2.0), 0.0))
	var s_front := sqrt(maxf(1.0 - pow(1.0 - clampf((1.0 - t) / 0.12, 0.0, 1.0), 2.0), 0.0))
	return maxf(minf(s_rear, s_front), 0.22)


func _lum_ring(t: float) -> Array:
	var w := _lum_w(t) * _lum_cap(t)
	var h := _lum_h(t) * _lum_cap(t)
	var x := LUM_X0 + t * LUM_LEN
	var ring: Array = []
	# From one bottom edge over the top to the other; the segment that closes it is the underside.
	for i in range(RING_PTS):
		var a := PI * float(i) / float(RING_PTS - 1)
		ring.append(Vector3(x, LUM_Y + h * pow(sin(a), 0.75), w * cos(a)))
	return ring


func _build_luminaire() -> void:
	var grid: Array = []
	for t in LUM_STATIONS:
		grid.append(_lum_ring(float(t)))
	var nr: int = RING_PTS
	var normals: Array = []
	for i in range(grid.size()):
		var row: Array = []
		var yc := LUM_Y + 0.4 * _lum_h(float(LUM_STATIONS[i])) * _lum_cap(float(LUM_STATIONS[i]))
		for j in range(nr):
			var p: Vector3 = grid[i][j]
			var t_ring: Vector3 = (grid[i][(j + 1) % nr] as Vector3) - (grid[i][(j - 1 + nr) % nr] as Vector3)
			var t_len: Vector3 = (grid[mini(i + 1, grid.size() - 1)][j] as Vector3) - (grid[maxi(i - 1, 0)][j] as Vector3)
			var n: Vector3 = t_len.cross(t_ring)
			var outward := Vector3(0.0, p.y - yc, p.z)
			if n.length_squared() < 1e-12:
				n = outward
			n = n.normalized()
			if n.dot(outward) < 0.0:
				n = -n
			row.append(n)
		normals.append(row)
	for i in range(grid.size() - 1):
		for j in range(nr):
			var j2 := (j + 1) % nr
			# The segment from the last point back to the first is the flat underside.
			var under := j == nr - 1
			var key := "matte" if under else "metal"
			var col := DARK if under else ALUM
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j2]
			var c: Vector3 = grid[i + 1][j2]
			var d: Vector3 = grid[i + 1][j]
			var na: Vector3 = normals[i][j]
			var nb: Vector3 = normals[i][j2]
			var nc: Vector3 = normals[i + 1][j2]
			var nd: Vector3 = normals[i + 1][j]
			if under:
				na = Vector3.DOWN
				nb = Vector3.DOWN
				nc = Vector3.DOWN
				nd = Vector3.DOWN
			var out := (na + nb + nc + nd).normalized()
			_k.tri(_kit, key, a, b, c, na, nb, nc, col, out)
			_k.tri(_kit, key, a, c, d, na, nc, nd, col, out)
	# The end faces.
	for end in [0, grid.size() - 1]:
		var nrm := Vector3(-1.0 if end == 0 else 1.0, 0.0, 0.0)
		var ring: Array = grid[end]
		var c0 := Vector3(ring[0].x, LUM_Y + 0.3 * _lum_h(float(LUM_STATIONS[end])) * _lum_cap(float(LUM_STATIONS[end])), 0.0)
		for j in range(nr):
			_k.tri(_kit, "metal", c0, ring[j], ring[(j + 1) % nr], nrm, nrm, nrm, ALUM, nrm)
	# The lens: a flat glowing panel just under the shell, following its plan.
	var plan := PackedVector2Array()
	var steps := 9
	for k in range(steps):
		var t := 0.10 + 0.83 * float(k) / float(steps - 1)
		plan.append(Vector2(LUM_X0 + t * LUM_LEN, _lum_w(t) * _lum_cap(t) * 0.78))
	for k in range(steps - 1, -1, -1):
		var t2 := 0.10 + 0.83 * float(k) / float(steps - 1)
		plan.append(Vector2(LUM_X0 + t2 * LUM_LEN, -_lum_w(t2) * _lum_cap(t2) * 0.78))
	var tris := Geometry2D.triangulate_polygon(plan)
	var ly := LUM_Y - 0.014
	for i in range(0, tris.size(), 3):
		var pa := plan[tris[i]]
		var pb := plan[tris[i + 1]]
		var pc := plan[tris[i + 2]]
		_k.tri(_kit, "lamp", Vector3(pa.x, ly, pa.y), Vector3(pb.x, ly, pb.y), Vector3(pc.x, ly, pc.y), Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, LENS, Vector3.DOWN)
	# A thin rim round the lens, so its edge catches the light.
	for k in range(plan.size()):
		var qa := plan[k]
		var qb := plan[(k + 1) % plan.size()]
		var side := Vector3(qa.y - qb.y, 0.0, qb.x - qa.x).normalized()
		_k.quad(_kit, "matte", [Vector3(qa.x, ly, qa.y), Vector3(qb.x, ly, qb.y), Vector3(qb.x, LUM_Y, qb.y), Vector3(qa.x, LUM_Y, qa.y)], side, DARK)
	# The photocell on top.
	var tx := 0.42
	var cx := LUM_X0 + tx * LUM_LEN
	var cy := LUM_Y + _lum_h(tx)
	_k.tube(_kit, "matte", Vector3(cx, cy - 0.01, 0.0), Vector3(cx, cy + 0.045, 0.0), 0.034, 0.034, 10, PAINT_DARK)
	_k.tube(_kit, "matte", Vector3(cx, cy + 0.045, 0.0), Vector3(cx, cy + 0.065, 0.0), 0.026, 0.026, 10, Color(0.75, 0.62, 0.28))
