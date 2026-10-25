extends RefCounted
## Desert cacti for the Canyon Course (regenerate_canyon.gd), built in code: they replaced imported
## models that read as smooth green blobs up close, in four shapes. Seven species, several variants each:
##   saguaro   a ribbed column with arms that leave it near level and turn up (a spear, one arm, two,
##             three, many, an old giant with a drooping arm, a pair with a bud)
##   organ     organ pipe: many slim stems from one foot, curving up
##   barrel    a squat, deep-ribbed barrel leaning south, a crown of yellow fruit
##   pear      prickly pear: chains of flat pads, magenta fruit on the rims of the top ones
##   cholla    a dark woody trunk under branches of short spiny joints (the spines read pale gold)
##   hedgehog  a clump of short stems with magenta flowers
##   ocotillo  whip-like woody stems fanning out from the ground, red flower spikes at the tips
## Every stem is a sweep of a ribbed cross-section along a path (parallel-transported frames), ridges and
## valleys alternating round it, closed by a dome. cactus.gdshader shades the ribs round, puts areoles
## and spines on the ridges, and varies each plant's colour. Per vertex:
##   COLOR    the base colour (sRGB)
##   UV       x the rib phase (whole numbers on the ridges), y metres along the stem; on a pad, metres
##            across and up it
##   CUSTOM0  x species (SP_ID), y part (FLESH, FLOWER, WOOD), z height up the plant (0..1), w metres
##            between two ridges (on a pad: how near its rim, 0..1)
## lod 1 is the far version: a third of the ribs, a third of the rings, no flowers.

const SPECIES := ["saguaro", "organ", "barrel", "pear", "cholla", "hedgehog", "ocotillo"]
const VARIANTS := {"saguaro": 7, "organ": 3, "barrel": 3, "pear": 4, "cholla": 3, "hedgehog": 2, "ocotillo": 3}
const SP_ID := {"saguaro": 0.0, "organ": 1.0, "barrel": 2.0, "pear": 3.0, "cholla": 4.0, "hedgehog": 5.0, "ocotillo": 6.0}
const FLESH := 0.0
const FLOWER := 1.0
const WOOD := 2.0

var _st: SurfaceTool
var _count := 0
var _lod := 0
var _species := 0.0
var _height := 1.0


func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://cactus.gdshader")
	return m


func build(species: String, variant: int, lod: int, mat: Material) -> ArrayMesh:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	_count = 0
	_lod = lod
	_species = SP_ID[species]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * (SPECIES.find(species) + 1) + variant * 104729
	match species:
		"saguaro":
			_saguaro(rng, variant)
		"organ":
			_organ(rng, variant)
		"barrel":
			_barrel(rng, variant)
		"pear":
			_pear(rng, variant)
		"cholla":
			_cholla(rng, variant)
		"hedgehog":
			_hedgehog(rng, variant)
		"ocotillo":
			_ocotillo(rng, variant)
	_st.generate_normals()
	_st.generate_tangents()
	var mesh: ArrayMesh = _st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


func _vertex(p: Vector3, uv: Vector2, col: Color, part: float, w: float) -> void:
	_st.set_color(col)
	_st.set_uv(uv)
	_st.set_custom(0, Color(_species, part, clampf(p.y / _height, 0.0, 1.0), w))
	_st.add_vertex(p)
	_count += 1


## A ribbed stem along `path` (foot first) with a radius per point, closed by a dome on top. `depth` is
## how deep the valleys run, as a share of the radius; `twist` turns the ribs (radians per metre).
func _stem(path: Array, radii: Array, ribs: int, depth: float, col: Color, part := FLESH, twist := 0.0) -> void:
	if _lod == 1:
		ribs = maxi(3, ribs / 3)
		var p2: Array = []
		var r2: Array = []
		for i in range(path.size()):
			if i % 3 == 0 or i == path.size() - 1:
				p2.append(path[i])
				r2.append(radii[i])
		path = p2
		radii = r2
	var n: int = path.size()
	if n < 2:
		return
	# The dome: rings shrinking round the top, then the apex.
	var tip: Vector3 = (path[n - 1] - path[n - 2]).normalized()
	var r_top: float = radii[n - 1]
	var steps: int = 3 if _lod == 0 else 1
	var pts: Array = path.duplicate()
	var rad: Array = radii.duplicate()
	for j in range(1, steps + 1):
		var th: float = float(j) / float(steps + 1) * PI * 0.5
		pts.append(path[n - 1] + tip * r_top * sin(th) * 0.85)
		rad.append(r_top * cos(th))
	# Parallel-transported frames.
	var t0: Vector3 = (pts[1] - pts[0]).normalized()
	var ref: Vector3 = Vector3.RIGHT if absf(t0.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var nrm: Vector3 = t0.cross(ref).normalized()
	var ring_n: int = 2 * ribs
	var start: int = _count
	var along := 0.0
	for i in range(pts.size()):
		var t: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin: Vector3 = t.cross(nrm)
		if i > 0:
			along += (pts[i] as Vector3).distance_to(pts[i - 1])
		var r: float = rad[i]
		for k in range(ring_n + 1):
			var a: float = float(k) * PI / float(ribs) + twist * along
			var rr: float = r * (1.0 if k % 2 == 0 else 1.0 - depth)
			var q: Vector3 = (pts[i] as Vector3) + (nrm * cos(a) + bin * sin(a)) * rr
			_vertex(q, Vector2(float(k) * 0.5, along), col, part, TAU * maxf(r, 0.01) / float(ribs))
	var apex: int = _count
	_vertex((pts[pts.size() - 1] as Vector3) + tip * r_top * 0.12, Vector2(0.0, along + r_top * 0.12), col, part, 0.01)
	# The ring runs from nrm toward bin = t x nrm, so the quad (ring i, k), (ring i + 1, k + 1),
	# (ring i, k + 1) has (c - a) x (b - a) along nrm, outward (CLAUDE.md: clockwise front faces).
	for i in range(pts.size() - 1):
		for k in range(ring_n):
			var i0: int = start + i * (ring_n + 1) + k
			var j0: int = i0 + ring_n + 1
			_tri(i0, j0 + 1, i0 + 1)
			_tri(i0, j0, j0 + 1)
	var last: int = start + (pts.size() - 1) * (ring_n + 1)
	for k in range(ring_n):
		_tri(last + k, apex, last + k + 1)


func _tri(a: int, b: int, c: int) -> void:
	_st.add_index(a)
	_st.add_index(b)
	_st.add_index(c)


## Points along a polyline every `step` metres (the corners kept).
static func _resample(corners: Array, step: float) -> Array:
	var out: Array = [corners[0]]
	for i in range(corners.size() - 1):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[i + 1]
		var n: int = maxi(1, int(ceil(a.distance_to(b) / step)))
		for k in range(1, n + 1):
			out.append(a.lerp(b, float(k) / float(n)))
	return out


## A small closed blob (fruit, bud, flower) along `axis`.
func _blob(c: Vector3, axis: Vector3, r: float, length: float, col: Color, part := FLOWER) -> void:
	if _lod == 1:
		return
	var path: Array = [c - axis * length * 0.1, c + axis * length * 0.5]
	_stem(path, [r * 0.75, r], 3, 0.0, col, part)


# --------------------------------------------------------------------------------------------------
#  Saguaro
# --------------------------------------------------------------------------------------------------

const SAGUARO_GREEN := Color(0.47, 0.54, 0.38)
## Per variant: height, [arm height share, azimuth (turns), reach out, length up, droop], ...
const SAGUARO_ARMS := [
	[4.6, []],
	[7.4, [[0.52, 0.1, 0.55, 2.4, false]]],
	[8.6, [[0.48, 0.05, 0.6, 2.9, false], [0.55, 0.52, 0.5, 2.5, false]]],
	[9.4, [[0.42, 0.0, 0.65, 3.1, false], [0.5, 0.36, 0.55, 2.7, false], [0.57, 0.7, 0.5, 2.2, false]]],
	[10.2, [[0.38, 0.15, 0.7, 3.2, false], [0.46, 0.48, 0.6, 3.0, false], [0.6, 0.78, 0.55, 2.4, false], [0.66, 0.3, 0.45, 1.7, false]]],
	[11.4, [[0.36, 0.05, 0.75, 3.5, false], [0.42, 0.33, 0.7, 3.1, false], [0.5, 0.6, 0.9, 2.2, true], [0.58, 0.85, 0.55, 2.6, false], [0.66, 0.2, 0.45, 1.6, false]]],
	[8.0, [[0.5, 0.25, 0.6, 2.6, false], [0.56, 0.72, 0.55, 2.3, false], [0.7, 0.5, 0.25, 0.45, false]]],
]

func _saguaro(rng: RandomNumberGenerator, variant: int) -> void:
	var spec: Array = SAGUARO_ARMS[variant % SAGUARO_ARMS.size()]
	var h: float = float(spec[0])
	_height = h
	var r: float = rng.randf_range(0.3, 0.36) * (0.85 if variant == 0 else 1.0)
	var ribs: int = rng.randi_range(14, 18)
	var col: Color = SAGUARO_GREEN.lerp(Color(0.46, 0.52, 0.42), rng.randf())
	var step: float = 0.22 if _lod == 0 else 0.22
	# The trunk: a slight sway, a little fuller in the middle, rounding off at the top.
	var lean := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.0, 0.035)
	var trunk: Array = []
	var radii: Array = []
	var y := -0.3
	while y <= h - r:
		var t: float = clampf(y / h, 0.0, 1.0)
		trunk.append(Vector3(lean.x * y + sin(y * 0.7) * 0.03, y, lean.z * y))
		radii.append(r * (1.0 + 0.06 * sin(t * PI) - 0.1 * smoothstep(0.85, 1.0, t)))
		y += step
	_stem(trunk, radii, ribs, 0.13, col)
	for arm in spec[1]:
		var hs: float = float(arm[0]) * h
		var az: float = float(arm[1]) * TAU + rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(az), 0.0, sin(az))
		var ra: float = r * rng.randf_range(0.72, 0.84)
		var reach: float = float(arm[2]) * rng.randf_range(1.3, 1.7)
		var up_len: float = float(arm[3])
		var origin := Vector3(lean.x * hs, hs, lean.z * hs)
		var corners: Array = [origin]
		if arm[4]:
			# An old arm that sagged: out and down, then turning up.
			corners.append(origin + dir * (r + reach * 0.5) + Vector3.DOWN * 0.15)
			corners.append(origin + dir * (r + reach * 1.0) + Vector3.DOWN * 0.7)
			corners.append(origin + dir * (r + reach * 1.5) + Vector3.DOWN * 0.95)
			corners.append(origin + dir * (r + reach * 1.95) + Vector3.DOWN * 0.7)
			corners.append(origin + dir * (r + reach * 2.15) + Vector3.DOWN * 0.15)
		else:
			corners.append(origin + dir * (r + reach * 0.45) + Vector3.UP * 0.12)
		# The elbow, then up, leaning out a touch.
		var e0: Vector3 = corners[corners.size() - 1]
		var elbow: float = ra * rng.randf_range(1.2, 1.7)
		for k in range(1, 5):
			var th: float = float(k) / 4.0 * PI * 0.5
			corners.append(e0 + dir * (sin(th) * elbow) + Vector3.UP * ((1.0 - cos(th)) * elbow + 0.08 * float(k)))
		var top: Vector3 = corners[corners.size() - 1]
		corners.append(top + Vector3.UP * up_len * 0.5 + dir * 0.05)
		corners.append(top + Vector3.UP * up_len + dir * 0.12)
		var path: Array = _resample(corners, step)
		var ar: Array = []
		for i in range(path.size()):
			var t2: float = float(i) / float(path.size() - 1)
			ar.append(ra * (0.82 + 0.18 * smoothstep(0.0, 0.15, t2)) * (1.0 - 0.08 * smoothstep(0.85, 1.0, t2)))
		_stem(path, ar, ribs - 2, 0.13, col)
		# Late spring: a crown of white flowers on some arm tips.
		if rng.randf() < 0.3:
			_flower_crown(path[path.size() - 1], ra, Color(0.95, 0.93, 0.86), rng)
	if variant != 0 and rng.randf() < 0.5:
		_flower_crown(trunk[trunk.size() - 1] + Vector3.UP * r * 0.6, r, Color(0.95, 0.93, 0.86), rng)


func _flower_crown(top: Vector3, r: float, col: Color, rng: RandomNumberGenerator) -> void:
	for k in range(rng.randi_range(3, 6)):
		var a: float = rng.randf() * TAU
		var d := Vector3(cos(a), 0.0, sin(a))
		_blob(top + d * r * 0.55, (d * 0.6 + Vector3.UP).normalized(), r * 0.22, r * 0.5, col)


# --------------------------------------------------------------------------------------------------
#  Organ pipe
# --------------------------------------------------------------------------------------------------

func _organ(rng: RandomNumberGenerator, variant: int) -> void:
	var stems: int = [7, 11, 15][variant % 3]
	_height = rng.randf_range(3.2, 4.4)
	var col := Color(0.33, 0.44, 0.28)
	for k in range(stems):
		var a: float = TAU * float(k) / float(stems) + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0.0, sin(a))
		var foot := d * rng.randf_range(0.05, 0.3)
		var h: float = _height * rng.randf_range(0.55, 1.0)
		var splay: float = rng.randf_range(0.25, 0.7)
		var r: float = rng.randf_range(0.11, 0.15)
		var path: Array = []
		var radii: Array = []
		var segs := 16
		for i in range(segs + 1):
			var t: float = float(i) / float(segs)
			# Out from the foot, then curving up.
			var out: float = splay * (1.0 - pow(1.0 - minf(t * 1.6, 1.0), 2.0))
			path.append(foot + d * out + Vector3.UP * (t * h - 0.25))
			radii.append(r * (1.0 - 0.1 * smoothstep(0.8, 1.0, t)))
		_stem(path, radii, rng.randi_range(12, 15), 0.14, col.lerp(Color(0.36, 0.46, 0.30), rng.randf()))


# --------------------------------------------------------------------------------------------------
#  Barrel
# --------------------------------------------------------------------------------------------------

func _barrel(rng: RandomNumberGenerator, variant: int) -> void:
	var n: int = [1, 1, 3][variant % 3]
	_height = 1.4
	for k in range(n):
		var h: float = [0.9, 1.4, 0.8][variant % 3] * rng.randf_range(0.8, 1.1) * (1.0 if k == 0 else 0.7)
		var r: float = h * rng.randf_range(0.36, 0.46)
		var off := Vector3.ZERO if k == 0 else Vector3(cos(k * 2.3), 0.0, sin(k * 2.3)) * r * 1.9
		# Barrels lean south, toward the sun (+z is south in the level).
		var lean := Vector3(rng.randf_range(-0.05, 0.05), 1.0, rng.randf_range(0.08, 0.2)).normalized()
		var path: Array = []
		var radii: Array = []
		var segs := 9
		for i in range(segs + 1):
			var t: float = float(i) / float(segs)
			path.append(off + lean * (t * h - 0.15))
			radii.append(r * (0.84 + 0.2 * sin(minf(t * 1.15, 1.0) * PI * 0.8)) * (1.0 - 0.25 * smoothstep(0.7, 1.0, t)))
		_stem(path, radii, rng.randi_range(20, 24), 0.16, Color(0.40, 0.53, 0.29), FLESH, 0.08)
		# The crown of fruit, yellow.
		var top: Vector3 = path[path.size() - 1]
		for j in range(rng.randi_range(6, 10)):
			var a: float = TAU * float(j) / 8.0 + rng.randf_range(-0.2, 0.2)
			var d := Vector3(cos(a), 0.0, sin(a))
			_blob(top + d * r * 0.42 - lean * r * 0.05, (d * 0.5 + lean).normalized(), r * 0.17, r * 0.34, Color(0.93, 0.78, 0.22))


# --------------------------------------------------------------------------------------------------
#  Prickly pear
# --------------------------------------------------------------------------------------------------

## A pad: a flat lens, `a` half wide and `b` half tall in its own x and y, thick along z; its foot (the
## bottom of the ellipse) at `foot`.
func _pad(foot: Vector3, basis: Basis, a: float, b: float, thick: float, col: Color) -> void:
	var segs: int = 14 if _lod == 0 else 6
	var c: Vector3 = foot + basis.y * b
	var start: int = _count
	# Rings from the front centre out to the rim and back: (scale, z).
	var rings: Array = [Vector2(0.0, thick), Vector2(0.62, thick * 0.78), Vector2(1.0, 0.0), Vector2(0.62, -thick * 0.78), Vector2(0.0, -thick)]
	if _lod == 1:
		rings = [Vector2(0.0, thick), Vector2(1.0, 0.0), Vector2(0.0, -thick)]
	for ri in range(rings.size()):
		var rg: Vector2 = rings[ri]
		for k in range(segs):
			var th: float = TAU * float(k) / float(segs)
			var lx: float = cos(th) * a * rg.x
			var ly: float = sin(th) * b * rg.x
			var q: Vector3 = c + basis.x * lx + basis.y * ly + basis.z * rg.y
			_vertex(q, Vector2(lx, ly), col, FLESH, rg.x)
	for ri in range(rings.size() - 1):
		for k in range(segs):
			var a0: int = start + ri * segs + k
			var a1: int = start + ri * segs + (k + 1) % segs
			var b0: int = a0 + segs
			var b1: int = a1 + segs
			# Front faces out: the pad's frame is right-handed, its front on +z.
			_tri(a0, a1, b1)
			_tri(a0, b1, b0)


func _pear(rng: RandomNumberGenerator, variant: int) -> void:
	var levels: int = [2, 3, 3, 4][variant % 4]
	var roots: int = [2, 3, 4, 3][variant % 4]
	_height = 0.6 * float(levels + 1)
	var col := Color(0.47, 0.57, 0.40)
	var frontier: Array = []
	for k in range(roots):
		var az: float = TAU * float(k) / float(roots) + rng.randf_range(-0.4, 0.4)
		var d := Vector3(cos(az), 0.0, sin(az))
		var basis := _pad_basis(Vector3.UP.lerp(d, rng.randf_range(0.1, 0.45)).normalized(), rng)
		var foot := d * rng.randf_range(0.05, 0.25) + Vector3.DOWN * 0.08
		frontier.append([foot, basis, 0])
	while not frontier.is_empty():
		var f: Array = frontier.pop_front()
		var foot: Vector3 = f[0]
		var basis: Basis = f[1]
		var lvl: int = f[2]
		var a: float = rng.randf_range(0.2, 0.27)
		var b: float = a * rng.randf_range(1.15, 1.4)
		var pcol: Color = col.lerp(Color(0.52, 0.55, 0.38), rng.randf() * 0.6)
		_pad(foot, basis, a, b, 0.035, pcol)
		var centre: Vector3 = foot + basis.y * b
		if lvl + 1 < levels:
			for j in range(rng.randi_range(1, 3)):
				var th: float = deg_to_rad(rng.randf_range(35.0, 145.0))
				var rim: Vector3 = centre + basis.x * cos(th) * a * 0.9 + basis.y * sin(th) * b * 0.9
				var out: Vector3 = (rim - centre).normalized()
				var up: Vector3 = out.lerp(Vector3.UP, rng.randf_range(0.35, 0.75)).normalized()
				frontier.append([rim, _pad_basis(up, rng), lvl + 1])
		elif rng.randf() < 0.75:
			# Fruit (tunas) on the top pads' rims.
			for j in range(rng.randi_range(2, 5)):
				var th2: float = deg_to_rad(rng.randf_range(30.0, 150.0))
				var rim2: Vector3 = centre + basis.x * cos(th2) * a * 0.95 + basis.y * sin(th2) * b * 0.95
				_blob(rim2, (rim2 - centre).normalized(), 0.04, 0.09, Color(0.62, 0.10, 0.28))


## A pad's frame: y along `up`, turned about it to face any way.
static func _pad_basis(up: Vector3, rng: RandomNumberGenerator) -> Basis:
	var side: Vector3 = up.cross(Vector3(cos(rng.randf() * TAU), 0.0, sin(rng.randf() * TAU))).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var z: Vector3 = side.cross(up).normalized()
	return Basis(side, up, z)


# --------------------------------------------------------------------------------------------------
#  Cholla
# --------------------------------------------------------------------------------------------------

func _cholla(rng: RandomNumberGenerator, variant: int) -> void:
	_height = [1.5, 2.0, 1.15][variant % 3]
	var trunk_h: float = _height * rng.randf_range(0.24, 0.32)
	var trunk_r: float = rng.randf_range(0.09, 0.11)
	_stem([Vector3(0, -0.2, 0), Vector3(0.02, trunk_h * 0.5, 0.0), Vector3(0.0, trunk_h, 0.03)], [trunk_r * 1.25, trunk_r, trunk_r * 0.9], 5, 0.12, Color(0.34, 0.28, 0.22), WOOD)
	var col := Color(0.50, 0.54, 0.32)
	# A crowd of thick, short joints climbing from the trunk's top, the tips turning up.
	var branches: int = rng.randi_range(6, 10)
	for k in range(branches):
		var az: float = TAU * float(k) / float(branches) + rng.randf_range(-0.4, 0.4)
		var d := Vector3(cos(az), 0.0, sin(az))
		var p := Vector3(0.0, trunk_h * rng.randf_range(0.7, 1.0), 0.0) + d * 0.03
		var dir: Vector3 = (d * rng.randf_range(0.4, 1.0) + Vector3.UP * rng.randf_range(0.6, 1.4)).normalized()
		var joints: int = rng.randi_range(2, 4)
		for j in range(joints):
			var length: float = rng.randf_range(0.15, 0.24)
			var r: float = rng.randf_range(0.1, 0.13) * (1.0 - 0.08 * float(j))
			var q: Vector3 = p + dir * length
			_stem([p - dir * 0.04, p + dir * length * 0.5, q], [r * 0.75, r, r * 0.88], 8, 0.24, col)
			p = q - dir * 0.03
			var kink := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.2, 0.8), rng.randf_range(-1.0, 1.0)) * 0.45
			dir = (dir + kink + Vector3.UP * 0.3).normalized()
	# Fallen joints round its foot, dried brown.
	for k in range(rng.randi_range(3, 7)):
		var a: float = rng.randf() * TAU
		var g := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.2, 0.6) + Vector3.UP * 0.03
		var lay := Vector3(cos(a + 1.3), 0.08, sin(a + 1.3)).normalized()
		_stem([g - lay * 0.09, g, g + lay * 0.09], [0.07, 0.08, 0.07], 8, 0.22, Color(0.42, 0.33, 0.22), WOOD)


# --------------------------------------------------------------------------------------------------
#  Hedgehog
# --------------------------------------------------------------------------------------------------

func _hedgehog(rng: RandomNumberGenerator, variant: int) -> void:
	var stems: int = [7, 13][variant % 2]
	_height = 0.5
	for k in range(stems):
		var a: float = TAU * float(k) / float(stems) + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0.0, sin(a))
		var foot := d * rng.randf_range(0.0, 0.22) * sqrt(float(k) / float(stems))
		var h: float = rng.randf_range(0.22, 0.45)
		var axis: Vector3 = (Vector3.UP + d * rng.randf_range(0.05, 0.5)).normalized()
		var r: float = rng.randf_range(0.065, 0.09)
		_stem([foot + axis * -0.08, foot + axis * h * 0.5, foot + axis * h], [r * 0.95, r, r * 0.9], 10, 0.16, Color(0.40, 0.50, 0.31))
		if rng.randf() < 0.35:
			_blob(foot + axis * (h * 0.8) + d * r * 0.8, (d + Vector3.UP * 0.8).normalized(), 0.032, 0.06, Color(0.86, 0.22, 0.52))


# --------------------------------------------------------------------------------------------------
#  Ocotillo
# --------------------------------------------------------------------------------------------------

func _ocotillo(rng: RandomNumberGenerator, variant: int) -> void:
	var stems: int = [12, 18, 24][variant % 3]
	_height = rng.randf_range(4.0, 5.5)
	for k in range(stems):
		var a: float = TAU * float(k) / float(stems) + rng.randf_range(-0.25, 0.25)
		var d := Vector3(cos(a), 0.0, sin(a))
		var h: float = _height * rng.randf_range(0.6, 1.0)
		var splay: float = rng.randf_range(0.08, 0.32)
		var bow: float = rng.randf_range(-0.04, 0.08)
		var path: Array = []
		var radii: Array = []
		var segs := 12
		for i in range(segs + 1):
			var t: float = float(i) / float(segs)
			path.append(d * (0.06 + splay * h * t + bow * h * sin(t * PI)) + Vector3.UP * (t * h - 0.15))
			radii.append(lerpf(0.045, 0.014, t))
		_stem(path, radii, 3, 0.0, Color(0.44, 0.40, 0.33), WOOD)
		if rng.randf() < 0.7:
			var tip: Vector3 = path[path.size() - 1]
			var tdir: Vector3 = (tip - (path[path.size() - 2] as Vector3)).normalized()
			_blob(tip - tdir * 0.05, tdir, 0.035, 0.3, Color(0.86, 0.22, 0.10))
