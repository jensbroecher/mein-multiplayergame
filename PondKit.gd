extends RefCounted
## Plants for Pinecrest Ridge's lake and ponds (regenerate_pinecrest_ridge.gd, _build_pond): bulrushes
## with their brown spikes and soft rushes in the shallows and along the wet bank, yellow flag irises on
## the bank, and rafts of water-lily pads with white and pink flowers floating on the water. Life size,
## standing on y = 0 (the lilies lie on it, so they're placed at the water's level).
## The rushes and irises are for dune_grass.gdshader (COLOR the colour in sRGB, its alpha how far up
## the blade, which sways), the lilies for a plain vertex-coloured material; both draw both sides of a
## face, so every leaf and petal is one face.

const RUSH_GREEN := Color(0.24, 0.40, 0.14)
const RUSH_TIP := Color(0.52, 0.56, 0.26)
const SPIKE := Color(0.36, 0.22, 0.12)
const PAD := Color(0.14, 0.32, 0.12)
const PAD_RIM := Color(0.34, 0.24, 0.14)
const IRIS := Color(0.98, 0.82, 0.12)


## A triangle facing `n`: Godot's front faces wind so (c - a) x (b - a) points out of them.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
	for v in [[a, ca], [b, cb], [c, cc]]:
		st.set_normal(n)
		st.set_color(v[1])
		st.add_vertex(v[0])


## One blade from `foot`: `h` tall, leaning out along `out` by `lean` (more toward the tip), `w` wide at
## its foot and tapering, in `segs` pieces; `flat` turns its face from looking out toward looking across.
static func _blade(st: SurfaceTool, foot: Vector3, out: Vector3, h: float, lean: float, w: float, segs: int, col: Color, tip: Color, flat := 0.0) -> void:
	var side := Vector3.UP.cross(out).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	var face := out.lerp(side.cross(Vector3.UP), flat).normalized()
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_t := 0.0
	for j in range(segs + 1):
		var t := float(j) / float(segs)
		var c := foot + out * (lean * t * t * h) + Vector3.UP * (t * h)
		var wd := w * (1.0 - t * 0.9)
		var l := c - side * wd
		var r := c + side * wd
		if j > 0:
			var c0 := col.lerp(tip, prev_t)
			var c1 := col.lerp(tip, t)
			c0.a = prev_t
			c1.a = t
			var n := (face + Vector3.UP * 0.5).normalized()
			_tri(st, prev_l, prev_r, r, n, c0, c0, c1)
			_tri(st, prev_l, r, l, n, c0, c1, c1)
		prev_l = l
		prev_r = r
		prev_t = t


## A stand of bulrushes, 1.3-2.1m: long flat leaves arching out, and stems carrying the brown spikes.
static func bulrush(variant: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7100 + variant * 31
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(26 + variant * 6):
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var foot := out * sqrt(rng.randf()) * 0.4
		_blade(st, foot, out, rng.randf_range(1.2, 2.0), rng.randf_range(0.08, 0.32), rng.randf_range(0.018, 0.028), 4,
				RUSH_GREEN.lerp(RUSH_GREEN.darkened(0.2), rng.randf()), RUSH_TIP.lerp(Color(0.68, 0.62, 0.38), rng.randf() * 0.5))
	for k in range(4 + variant):
		var a2 := rng.randf() * TAU
		var foot2 := Vector3(cos(a2), 0.0, sin(a2)) * sqrt(rng.randf()) * 0.3
		var top := foot2 + Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(1.5, 2.1), rng.randf_range(-0.06, 0.06))
		_blade(st, foot2, (top - foot2).normalized() * Vector3(1, 0, 1) + Vector3(0.001, 0, 0), top.y, 0.02, 0.008, 2, RUSH_GREEN, RUSH_TIP)
		# The spike: a short brown cylinder near the stem's top, its tip a thin spur.
		var s0 := top - Vector3(0, 0.34, 0)
		var s1 := top - Vector3(0, 0.08, 0)
		for i in range(6):
			var t0 := TAU * i / 6.0
			var t1 := TAU * (i + 1) / 6.0
			var d0 := Vector3(cos(t0), 0.0, sin(t0)) * 0.035
			var d1 := Vector3(cos(t1), 0.0, sin(t1)) * 0.035
			var n := (d0 + d1).normalized()
			var cs := Color(SPIKE.r, SPIKE.g, SPIKE.b, 0.95)
			_tri(st, s0 + d0, s0 + d1, s1 + d1, n, cs, cs, cs)
			_tri(st, s0 + d0, s1 + d1, s1 + d0, n, cs, cs, cs)
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## A clump of soft rushes, 0.6-1.1m: many thin upright stems, a brown tuft of flowers low on some.
static func rushes(variant: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7300 + variant * 17
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(48):
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		var foot := out * sqrt(rng.randf()) * 0.22
		var h := rng.randf_range(0.6, 1.1)
		_blade(st, foot, out, h, rng.randf_range(0.04, 0.22), 0.009, 3, Color(0.16, 0.30, 0.10), Color(0.30, 0.42, 0.16), 0.5)
		if rng.randf() < 0.25:
			var tuft := foot + out * 0.02 + Vector3(0, h * 0.72, 0)
			var c := Color(0.48, 0.36, 0.20, 0.7)
			_tri(st, tuft, tuft + Vector3(0.05, 0.07, 0.01), tuft + Vector3(-0.03, 0.06, 0.04), Vector3.UP, c, c, c)
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## A clump of yellow flag irises: a fan of stiff sword leaves and two or three flowers on stalks (three
## falls hanging out and down, three smaller standards up).
static func iris(variant: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7500 + variant * 23
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(14):
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0.0, sin(a))
		_blade(st, out * rng.randf_range(0.0, 0.15), out, rng.randf_range(0.6, 1.0), rng.randf_range(0.05, 0.18), 0.03, 3,
				Color(0.20, 0.38, 0.16), Color(0.32, 0.50, 0.20), 1.0)
	for f in range(2 + variant % 2):
		var a2 := rng.randf() * TAU
		var head := Vector3(cos(a2) * 0.1, rng.randf_range(0.8, 1.05), sin(a2) * 0.1)
		_blade(st, Vector3(head.x * 0.5, 0.0, head.z * 0.5), Vector3(cos(a2), 0, sin(a2)), head.y, 0.03, 0.007, 2, Color(0.22, 0.40, 0.16), Color(0.26, 0.44, 0.18))
		for p in range(3):
			var pa := a2 + TAU * p / 3.0
			var pd := Vector3(cos(pa), 0.0, sin(pa))
			var ps := Vector3(-pd.z, 0.0, pd.x)
			var fall_tip := head + pd * 0.09 - Vector3(0, 0.05, 0)
			var std_tip := head + pd.rotated(Vector3.UP, PI / 3.0) * 0.03 + Vector3(0, 0.07, 0)
			var c := Color(IRIS.r, IRIS.g, IRIS.b, 0.95)
			_tri(st, head + ps * 0.02, head - ps * 0.02, fall_tip, (pd + Vector3.UP).normalized(), c, c, c.darkened(0.15))
			_tri(st, head + ps * 0.012, head - ps * 0.012, std_tip, (pd + Vector3.UP * 0.3).normalized(), c, c, c)
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## A raft of water lilies on the water (y = 0): 8-14 round pads with their notch, overlapping a little
## (each a millimetre over the last), and white or pink flowers, a cup of pointed petals round a yellow
## heart.
static func lilies(variant: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700 + variant * 41
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pads := 8 + variant * 3
	for k in range(pads):
		var c := Vector3(rng.randf_range(-1.0, 1.0), 0.012 + 0.002 * k, rng.randf_range(-1.0, 1.0)) * Vector3(0.9, 1.0, 0.9)
		var r := rng.randf_range(0.16, 0.36)
		var notch := rng.randf() * TAU
		var col := PAD.lerp(PAD.lightened(0.25), rng.randf())
		var segs := 14
		for i in range(segs):
			var a0 := notch + 0.35 + (TAU - 0.7) * i / segs
			var a1 := notch + 0.35 + (TAU - 0.7) * (i + 1) / segs
			var p0 := c + Vector3(cos(a0), 0.0, sin(a0)) * r
			var p1 := c + Vector3(cos(a1), 0.0, sin(a1)) * r
			_tri(st, c, p0, p1, Vector3.UP, col, col.lerp(PAD_RIM, 0.35), col.lerp(PAD_RIM, 0.35))
	for f in range(1 + variant % 3):
		var fc := Vector3(rng.randf_range(-0.6, 0.6), 0.03, rng.randf_range(-0.6, 0.6))
		var petal := Color(0.98, 0.97, 0.94) if rng.randf() < 0.6 else Color(0.96, 0.62, 0.74)
		for ring in range(2):
			var n := 8
			var rr := 0.11 - ring * 0.03
			var lift := 0.05 + ring * 0.03
			for p in range(n):
				var pa := TAU * (p + ring * 0.5) / n
				var pd := Vector3(cos(pa), 0.0, sin(pa))
				var ps := Vector3(-pd.z, 0.0, pd.x)
				var tip := fc + pd * rr + Vector3(0, lift, 0)
				var nrm := (pd * 0.6 + Vector3.UP).normalized()
				_tri(st, fc + ps * 0.025, fc - ps * 0.025, tip, nrm, petal.darkened(0.08), petal.darkened(0.08), petal)
		var heart := Color(0.96, 0.78, 0.18)
		for p in range(6):
			var a0 := TAU * p / 6.0
			var a1 := TAU * (p + 1) / 6.0
			_tri(st, fc + Vector3(0, 0.06, 0), fc + Vector3(cos(a0) * 0.03, 0.045, sin(a0) * 0.03), fc + Vector3(cos(a1) * 0.03, 0.045, sin(a1) * 0.03), Vector3.UP, heart, heart, heart)
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh
