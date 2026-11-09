## IceSculptureKit.gd
##
## Northlight Caverns' ice sculpture exhibition: carved-ice sculptures modelled as signed distance fields (round shapes
## blended smoothly into one another, as a carver's chisel leaves them) and meshed by surface nets into one smooth,
## closed mesh. Each stands on y = 0 (its base), faces +z, in metres (the generator places them at game scale), about
## 4-5m tall. Drawn by ice_sculpture.gdshader (clear ice, a glow of its uplight's colour, chisel marks).
##
## DESIGNS: "owl" (a snowy owl on a branch, its wings half spread), "reindeer" (a bust with branching antlers), "whale"
## (a whale's tail rising out of a wave), "swan" (wings raised, neck arched), "bear" (a polar bear sitting up),
## "snowflake" (a six-armed flake standing on one arm), "spiral" (a twisted double ribbon), "wave" (a breaking wave's
## curl), "fox" (an arctic fox curled up asleep). All made up for the stage.
##
## mesh(design, voxel) samples the field on a grid `voxel` apart over the design's bounds (BOUNDS) and returns an
## ArrayMesh with normals from the field's gradient. Surface nets: a vertex in every cell the surface passes through
## (the mean of its edges' crossings), a quad across every grid edge the surface crosses, wound to face out (Godot's
## front faces are clockwise).
extends RefCounted

const BOUNDS := {
	"owl": [Vector3(-2.3, -0.1, -1.1), Vector3(2.3, 4.6, 1.2)],
	"reindeer": [Vector3(-2.0, -0.1, -1.4), Vector3(2.0, 5.2, 2.0)],
	"whale": [Vector3(-2.6, -0.1, -1.5), Vector3(2.6, 5.4, 1.5)],
	"swan": [Vector3(-2.6, -0.1, -1.6), Vector3(2.6, 4.4, 2.0)],
	"bear": [Vector3(-1.5, -0.1, -1.4), Vector3(1.5, 4.4, 1.7)],
	"snowflake": [Vector3(-2.5, -0.1, -0.4), Vector3(2.5, 5.2, 0.4)],
	"spiral": [Vector3(-1.4, -0.1, -1.4), Vector3(1.4, 5.4, 1.4)],
	"wave": [Vector3(-2.2, -0.1, -1.8), Vector3(2.2, 4.2, 1.8)],
	"fox": [Vector3(-1.6, -0.1, -1.4), Vector3(1.6, 1.6, 1.4)],
}


# --- Primitives (Inigo Quilez's) -----------------------------------------------------------------------------------

static func smin(a: float, b: float, k: float) -> float:
	var h: float = clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)

static func smax(a: float, b: float, k: float) -> float:
	return -smin(-a, -b, k)

static func sphere(p: Vector3, c: Vector3, r: float) -> float:
	return p.distance_to(c) - r

static func ellipsoid(p: Vector3, c: Vector3, r: Vector3) -> float:
	var q: Vector3 = p - c
	var k0: float = (q / r).length()
	var k1: float = (q / (r * r)).length()
	if k1 < 1e-6:
		return -minf(r.x, minf(r.y, r.z))
	return k0 * (k0 - 1.0) / k1

## An ellipsoid turned by `b` (its axes the basis's columns).
static func ellipsoid_b(p: Vector3, c: Vector3, r: Vector3, b: Basis) -> float:
	return ellipsoid(b.inverse() * (p - c), Vector3.ZERO, r)

static func capsule(p: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var pa: Vector3 = p - a
	var ba: Vector3 = b - a
	var h: float = clampf(pa.dot(ba) / maxf(ba.dot(ba), 1e-8), 0.0, 1.0)
	return (pa - ba * h).length() - r

## A capsule tapering from ra at a to rb at b (approximate, good for gentle tapers).
static func taper(p: Vector3, a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	var pa: Vector3 = p - a
	var ba: Vector3 = b - a
	var h: float = clampf(pa.dot(ba) / maxf(ba.dot(ba), 1e-8), 0.0, 1.0)
	return (pa - ba * h).length() - lerpf(ra, rb, h)

static func rbox(p: Vector3, c: Vector3, half: Vector3, r: float) -> float:
	var q: Vector3 = (p - c).abs() - half + Vector3.ONE * r
	return Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0) - r

## A chain of tapering capsules through `pts` with radii `rs`, blended.
static func chain(p: Vector3, pts: Array, rs: Array, k: float) -> float:
	var d: float = INF
	for i in range(pts.size() - 1):
		var e: float = taper(p, pts[i], pts[i + 1], rs[i], rs[i + 1])
		d = e if d == INF else smin(d, e, k)
	return d


# --- The designs ---------------------------------------------------------------------------------------------------

static func field(design: String, p: Vector3) -> float:
	match design:
		"owl":
			return _owl(p)
		"reindeer":
			return _reindeer(p)
		"whale":
			return _whale(p)
		"swan":
			return _swan(p)
		"bear":
			return _bear(p)
		"snowflake":
			return _snowflake(p)
		"spiral":
			return _spiral(p)
		"wave":
			return _wave(p)
		"fox":
			return _fox(p)
	return sphere(p, Vector3(0, 1, 0), 1.0)


## A carved base every design stands on: a low rounded block, its top at y 0.35.
static func _base(p: Vector3, half: Vector2) -> float:
	return rbox(p, Vector3(0, 0.17, 0), Vector3(half.x, 0.18, half.y), 0.08)


static func _owl(p: Vector3) -> float:
	var q := Vector3(absf(p.x), p.y, p.z)
	var d: float = _base(p, Vector2(1.0, 0.6))
	# The branch it grips, and the talons.
	d = smin(d, capsule(p, Vector3(-1.1, 0.55, 0.1), Vector3(1.1, 0.62, 0.0), 0.2), 0.25)
	d = smin(d, capsule(q, Vector3(0.22, 0.6, 0.25), Vector3(0.25, 0.48, 0.42), 0.07), 0.08)
	# Body, a pear; the head on it, a little flattened at the face.
	var body: float = ellipsoid(p, Vector3(0, 1.75, 0), Vector3(0.78, 1.15, 0.7))
	var head: float = ellipsoid(p, Vector3(0, 2.95, 0.05), Vector3(0.66, 0.58, 0.6))
	var o: float = smin(body, head, 0.3)
	# The face: two shallow eye dishes and a beak.
	o = smax(o, -sphere(q, Vector3(0.24, 3.0, 0.68), 0.2), 0.08)
	o = smin(o, taper(p, Vector3(0, 2.92, 0.58), Vector3(0, 2.72, 0.78), 0.1, 0.02), 0.05)
	# Wings, half spread and raised: flattened ellipsoids from the shoulders, swept up and back, feathered tips.
	for sx in [-1.0, 1.0]:
		var b := Basis(Vector3(0, 0, 1), sx * 0.75) * Basis(Vector3(1, 0, 0), -0.25)
		o = smin(o, ellipsoid_b(p, Vector3(sx * 1.25, 2.55, -0.15), Vector3(1.05, 0.42, 0.12), b), 0.22)
		for f in range(3):
			var tip: Vector3 = Vector3(sx * (1.75 + 0.18 * f), 3.2 + 0.25 * f - 0.05 * f * f, -0.2 - 0.05 * f)
			o = smin(o, taper(p, Vector3(sx * 1.35, 2.8, -0.15), tip, 0.13, 0.04), 0.1)
	# Tail feathers to the branch.
	o = smin(o, taper(p, Vector3(0, 1.0, -0.45), Vector3(0, 0.55, -0.85), 0.32, 0.12), 0.15)
	return smin(d, o, 0.12)


static func _reindeer(p: Vector3) -> float:
	var q := Vector3(absf(p.x), p.y, p.z)
	var d: float = _base(p, Vector2(0.9, 0.9))
	# A bust: the chest, the neck rising forward, the head, the muzzle.
	d = smin(d, ellipsoid(p, Vector3(0, 0.95, -0.1), Vector3(0.75, 0.7, 0.75)), 0.2)
	d = smin(d, taper(p, Vector3(0, 1.1, -0.05), Vector3(0, 2.4, 0.45), 0.52, 0.34), 0.3)
	d = smin(d, ellipsoid_b(p, Vector3(0, 2.65, 0.85), Vector3(0.3, 0.32, 0.62), Basis(Vector3(1, 0, 0), 0.35)), 0.2)
	d = smin(d, ellipsoid(p, Vector3(0, 2.45, 1.32), Vector3(0.2, 0.18, 0.24)), 0.1)
	# A mane of hanging hair under the throat.
	d = smin(d, ellipsoid(p, Vector3(0, 1.75, 0.45), Vector3(0.28, 0.45, 0.25)), 0.2)
	# Ears.
	d = smin(d, ellipsoid_b(q, Vector3(0.36, 2.9, 0.6), Vector3(0.22, 0.08, 0.1), Basis(Vector3(0, 0, 1), 0.4)), 0.05)
	# Antlers: a beam curving up and back from each brow, tines off it, a palm at the brow.
	var beam := [Vector3(0.18, 2.95, 0.75), Vector3(0.45, 3.5, 0.55), Vector3(0.8, 4.05, 0.15), Vector3(0.95, 4.55, -0.35),
			Vector3(0.85, 4.95, -0.75)]
	var a: float = chain(q, beam, [0.1, 0.09, 0.08, 0.06, 0.04], 0.04)
	var tines := [[1, Vector3(0.75, 3.95, 0.85)], [2, Vector3(1.35, 4.5, 0.35)], [2, Vector3(0.55, 4.6, 0.2)],
			[3, Vector3(1.4, 5.0, -0.2)], [3, Vector3(0.6, 5.05, -0.35)]]
	for t in tines:
		a = smin(a, taper(q, beam[t[0]], t[1], 0.06, 0.03), 0.05)
	a = smin(a, ellipsoid_b(q, Vector3(0.28, 3.15, 1.0), Vector3(0.05, 0.22, 0.28), Basis(Vector3(1, 0, 0), -0.6)), 0.06)
	return smin(d, a, 0.06)


static func _whale(p: Vector3) -> float:
	# The sea: a slab with ripples, out of which the tail rises in an S.
	var sea: float = p.y - (0.45 + 0.08 * sin(p.x * 3.1) * cos(p.z * 2.7))
	sea = smax(sea, rbox(p, Vector3(0, 0.25, 0), Vector3(1.8, 0.6, 1.0), 0.3), 0.1)
	var spine := [Vector3(0, 0.3, 0.6), Vector3(0, 1.4, 0.45), Vector3(0, 2.6, 0.0), Vector3(0, 3.6, -0.35), Vector3(0, 4.25, -0.45)]
	var d: float = chain(p, spine, [0.75, 0.6, 0.42, 0.26, 0.16], 0.2)
	# The flukes: two broad flattened lobes from the tail stock's top, spreading out and up in a shallow V, their tips
	# rounded; a notch between them on the trailing edge.
	for sx in [-1.0, 1.0]:
		var ax := Vector3(sx * cos(0.33), sin(0.33), 0.0)
		var b := Basis(ax, Vector3(-ax.y * sx, ax.x * sx, 0.0).normalized(), Vector3(0, 0, 1))
		var f: float = ellipsoid_b(p, Vector3(0, 4.3, -0.45) + ax * 1.15, Vector3(1.25, 0.42, 0.11), b)
		f = smin(f, ellipsoid_b(p, Vector3(0, 4.3, -0.45) + ax * 2.05, Vector3(0.42, 0.28, 0.09), b), 0.18)
		d = smin(d, f, 0.25)
	d = smax(d, -ellipsoid(p, Vector3(0, 4.62, -0.45), Vector3(0.13, 0.2, 0.4)), 0.06)
	# Splashes round the base.
	for i in range(5):
		var a: float = TAU * float(i) / 5.0 + 0.4
		var c := Vector3(cos(a) * 1.05, 0.55, sin(a) * 0.75)
		d = smin(d, taper(p, c, c + Vector3(cos(a) * 0.35, 0.55 + 0.15 * float(i % 2), sin(a) * 0.25), 0.18, 0.04), 0.12)
	return smin(sea, d, 0.25)


static func _swan(p: Vector3) -> float:
	var d: float = _base(p, Vector2(1.2, 0.9))
	# Water under it, rippled.
	d = smin(d, rbox(p, Vector3(0, 0.45, 0.1), Vector3(1.2, 0.08, 0.95), 0.08), 0.1)
	var body: float = ellipsoid(p, Vector3(0, 1.0, 0.0), Vector3(0.75, 0.55, 1.2))
	body = smin(body, ellipsoid(p, Vector3(0, 1.2, -1.05), Vector3(0.35, 0.3, 0.4)), 0.25)
	# The neck in an S, the head, the beak.
	var neck := [Vector3(0, 1.3, 0.85), Vector3(0, 2.1, 1.1), Vector3(0, 2.85, 0.75), Vector3(0, 3.25, 0.95), Vector3(0, 3.25, 1.25)]
	body = smin(body, chain(p, neck, [0.28, 0.2, 0.16, 0.15, 0.13], 0.1), 0.2)
	body = smin(body, taper(p, Vector3(0, 3.22, 1.25), Vector3(0, 3.1, 1.62), 0.11, 0.04), 0.05)
	# Wings raised in an arch over the back, their feathers fanning up.
	for sx in [-1.0, 1.0]:
		var b := Basis(Vector3(0, 0, 1), sx * 0.95) * Basis(Vector3(1, 0, 0), 0.35)
		body = smin(body, ellipsoid_b(p, Vector3(sx * 0.95, 2.0, -0.35), Vector3(1.0, 0.36, 0.95), b), 0.25)
		for f in range(4):
			var fz: float = -0.95 + 0.42 * float(f)
			var tip: Vector3 = Vector3(sx * (1.55 + 0.12 * f), 3.25 - 0.22 * f, fz - 0.2)
			body = smin(body, taper(p, Vector3(sx * 1.0, 2.3, fz), tip, 0.14, 0.04), 0.1)
	return smin(d, body, 0.15)


static func _bear(p: Vector3) -> float:
	var q := Vector3(absf(p.x), p.y, p.z)
	var d: float = _base(p, Vector2(1.2, 1.1))
	# Sitting up: the haunches, the belly and chest leaning back, the head looking forward and up.
	var o: float = ellipsoid(p, Vector3(0, 1.05, -0.25), Vector3(1.0, 0.75, 1.0))
	o = smin(o, ellipsoid_b(p, Vector3(0, 2.0, 0.0), Vector3(0.82, 1.05, 0.7), Basis(Vector3(1, 0, 0), -0.12)), 0.4)
	o = smin(o, taper(p, Vector3(0, 2.6, 0.1), Vector3(0, 3.2, 0.45), 0.5, 0.36), 0.3)
	o = smin(o, ellipsoid(p, Vector3(0, 3.45, 0.55), Vector3(0.42, 0.38, 0.48)), 0.2)
	o = smin(o, ellipsoid(p, Vector3(0, 3.32, 1.0), Vector3(0.2, 0.18, 0.28)), 0.12)
	o = smin(o, sphere(q, Vector3(0.3, 3.78, 0.42), 0.11), 0.06)
	# Forelegs down between the hind ones, the paws on the ground; the hind feet forward.
	o = smin(o, taper(q, Vector3(0.38, 2.3, 0.35), Vector3(0.3, 0.55, 0.75), 0.3, 0.24), 0.25)
	o = smin(o, ellipsoid(q, Vector3(0.3, 0.5, 0.85), Vector3(0.24, 0.16, 0.3)), 0.1)
	o = smin(o, ellipsoid(q, Vector3(0.72, 0.5, 0.5), Vector3(0.28, 0.2, 0.45)), 0.2)
	return smin(d, o, 0.15)


static func _snowflake(p: Vector3) -> float:
	# Standing on one arm in the plane z = 0, its middle at y 2.6, a slab 0.22 thick with bevelled edges.
	var c := Vector3(0, 2.6, 0)
	var l := p - c
	var r: float = Vector2(l.x, l.y).length()
	var a: float = atan2(l.y, l.x)
	# Fold into one of six sectors, then mirror across its middle.
	var sector: float = TAU / 6.0
	var af: float = fposmod(a + PI * 0.5 + sector * 0.5, sector) - sector * 0.5
	af = absf(af)
	var u := Vector2(cos(af), sin(af)) * r
	var arm: float = capsule(Vector3(u.x, u.y, l.z), Vector3(0, 0, 0), Vector3(2.15, 0, 0), 0.16)
	for b in [[0.75, 0.6], [1.35, 0.45], [1.8, 0.28]]:
		var o: Vector3 = Vector3(b[0], 0, 0)
		var tip: Vector3 = o + Vector3(cos(PI / 3.0), sin(PI / 3.0), 0) * b[1]
		arm = smin(arm, capsule(Vector3(u.x, u.y, l.z), o, tip, 0.1), 0.06)
	arm = smin(arm, sphere(Vector3(u.x, u.y, l.z), Vector3(2.2, 0, 0), 0.2), 0.05)
	var hub: float = r - 0.55
	var f: float = smin(arm, maxf(hub, absf(l.z) - 0.15), 0.1)
	# Flatten to a slab.
	f = smax(f, absf(l.z) - 0.13, 0.05)
	return smin(f, _base(p, Vector2(0.7, 0.4)), 0.2)


static func _spiral(p: Vector3) -> float:
	var d: float = _base(p, Vector2(0.9, 0.9))
	# Two ribbons winding round each other up 5m, joined at the top in a knot.
	for k in range(2):
		var pts: Array = []
		var rs: Array = []
		for i in range(14):
			var t: float = float(i) / 13.0
			var ang: float = t * TAU * 1.4 + PI * float(k)
			var rad: float = lerpf(0.8, 0.35, t)
			pts.append(Vector3(cos(ang) * rad, 0.35 + t * 4.7, sin(ang) * rad))
			rs.append(lerpf(0.26, 0.12, t))
		d = smin(d, chain(p, pts, rs, 0.12), 0.18)
	return smin(d, sphere(p, Vector3(0, 5.05, 0), 0.22), 0.2)


static func _wave(p: Vector3) -> float:
	var d: float = _base(p, Vector2(1.6, 1.2))
	# A breaking wave's curl: a sheet rising and curling over toward +z, thinning to a lip, spray off the lip.
	var curl: float = INF
	for i in range(18):
		var t: float = float(i) / 17.0
		var ang: float = lerpf(-0.3, PI * 1.25, t)
		var rad: float = lerpf(2.1, 0.6, t)
		var cc := Vector3(0, 1.25 + sin(ang) * rad * 0.9, 0.2 - cos(ang) * rad * 0.75)
		var e: float = ellipsoid(p, cc, Vector3(1.5 - 0.5 * t, 0.25 - 0.1 * t, 0.25 - 0.1 * t))
		curl = e if curl == INF else smin(curl, e, 0.25)
	# The trough the wave rises from, joining it to the base.
	curl = smin(curl, ellipsoid(p, Vector3(0, 0.55, -0.6), Vector3(1.5, 0.4, 0.9)), 0.4)
	d = smin(d, curl, 0.3)
	for i in range(4):
		var x: float = -1.0 + float(i) * 0.65
		d = smin(d, taper(p, Vector3(x, 2.15, 1.05), Vector3(x * 1.2, 2.7, 1.25), 0.1, 0.03), 0.08)
	return d


static func _fox(p: Vector3) -> float:
	var d: float = _base(p, Vector2(1.2, 1.1))
	# Curled up asleep: the body a ring, the head on the tail, the brush wrapped round the nose.
	var body: float = ellipsoid(p, Vector3(0, 0.75, -0.1), Vector3(0.95, 0.45, 0.8))
	body = smin(body, ellipsoid(p, Vector3(0.45, 0.85, 0.55), Vector3(0.38, 0.3, 0.32)), 0.18)
	body = smin(body, taper(p, Vector3(0.5, 0.82, 0.8), Vector3(0.3, 0.72, 1.1), 0.18, 0.06), 0.1)
	for ex in [0.25, 0.65]:
		body = smin(body, taper(p, Vector3(ex, 1.05, 0.5), Vector3(ex * 0.9, 1.35, 0.45), 0.1, 0.02), 0.05)
	var tail := [Vector3(-0.85, 0.7, -0.35), Vector3(-0.9, 0.62, 0.45), Vector3(-0.3, 0.6, 1.0), Vector3(0.3, 0.58, 1.15)]
	body = smin(body, chain(p, tail, [0.35, 0.4, 0.33, 0.18], 0.15), 0.15)
	return smin(d, body, 0.12)


# --- Meshing ---------------------------------------------------------------------------------------------------------

## The design's surface as an ArrayMesh, the field sampled `voxel` apart (surface nets).
static func mesh(design: String, voxel := 0.075) -> ArrayMesh:
	var bb: Array = BOUNDS[design]
	var lo: Vector3 = bb[0] - Vector3.ONE * voxel * 2.0
	var hi: Vector3 = bb[1] + Vector3.ONE * voxel * 2.0
	var nx: int = int(ceil((hi.x - lo.x) / voxel)) + 1
	var ny: int = int(ceil((hi.y - lo.y) / voxel)) + 1
	var nz: int = int(ceil((hi.z - lo.z) / voxel)) + 1
	var f := PackedFloat32Array()
	f.resize(nx * ny * nz)
	for k in range(nz):
		for j in range(ny):
			for i in range(nx):
				f[(k * ny + j) * nx + i] = field(design, lo + Vector3(i, j, k) * voxel)
	var cx: int = nx - 1
	var cy: int = ny - 1
	var cz: int = nz - 1
	var vid := PackedInt32Array()
	vid.resize(cx * cy * cz)
	vid.fill(-1)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var corner := [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 1),
			Vector3i(0, 1, 1), Vector3i(1, 1, 1)]
	var edges := [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]
	var eps: float = voxel * 0.5
	for k in range(cz):
		for j in range(cy):
			for i in range(cx):
				var vals: Array = []
				var inside := 0
				for c in corner:
					var v: float = f[((k + c.z) * ny + (j + c.y)) * nx + (i + c.x)]
					vals.append(v)
					if v < 0.0:
						inside += 1
				if inside == 0 or inside == 8:
					continue
				var acc := Vector3.ZERO
				var n := 0
				for e in edges:
					var va: float = vals[e[0]]
					var vb: float = vals[e[1]]
					if (va < 0.0) == (vb < 0.0):
						continue
					var t: float = va / (va - vb)
					var ca: Vector3i = corner[e[0]]
					var cb: Vector3i = corner[e[1]]
					acc += Vector3(ca).lerp(Vector3(cb), t)
					n += 1
				var pos: Vector3 = lo + (Vector3(i, j, k) + acc / float(n)) * voxel
				var g := Vector3(field(design, pos + Vector3(eps, 0, 0)) - field(design, pos - Vector3(eps, 0, 0)),
						field(design, pos + Vector3(0, eps, 0)) - field(design, pos - Vector3(0, eps, 0)),
						field(design, pos + Vector3(0, 0, eps)) - field(design, pos - Vector3(0, 0, eps)))
				vid[(k * cy + j) * cx + i] = verts.size()
				verts.append(pos)
				norms.append(g.normalized() if g.length_squared() > 1e-12 else Vector3.UP)
	var idx := PackedInt32Array()
	# A quad across each grid edge the surface crosses, from the four cells round it.
	for k in range(nz):
		for j in range(ny):
			for i in range(nx):
				var v0: float = f[(k * ny + j) * nx + i]
				for axis in range(3):
					var ni: int = i + (1 if axis == 0 else 0)
					var nj: int = j + (1 if axis == 1 else 0)
					var nk: int = k + (1 if axis == 2 else 0)
					if ni >= nx or nj >= ny or nk >= nz:
						continue
					var v1: float = f[(nk * ny + nj) * nx + ni]
					if (v0 < 0.0) == (v1 < 0.0):
						continue
					# The four cells sharing this edge: offset -1/0 in the two other axes.
					var cells: Array = []
					var ok := true
					for o in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 0)]:
						var ci: int = i
						var cj: int = j
						var ck: int = k
						match axis:
							0:
								cj += o.x
								ck += o.y
							1:
								ci += o.x
								ck += o.y
							2:
								ci += o.x
								cj += o.y
						if ci < 0 or cj < 0 or ck < 0 or ci >= cx or cj >= cy or ck >= cz:
							ok = false
							break
						var id: int = vid[(ck * cy + cj) * cx + ci]
						if id < 0:
							ok = false
							break
						cells.append(id)
					if not ok:
						continue
					# Outward: toward the edge's outside end.
					var out := Vector3.ZERO
					out[axis] = 1.0 if v0 < 0.0 else -1.0
					for tri in [[cells[0], cells[1], cells[2]], [cells[0], cells[2], cells[3]]]:
						var a: Vector3 = verts[tri[0]]
						var b: Vector3 = verts[tri[1]]
						var c: Vector3 = verts[tri[2]]
						if (c - a).cross(b - a).dot(out) > 0.0:
							idx.append_array([tri[0], tri[1], tri[2]])
						else:
							idx.append_array([tri[0], tri[2], tri[1]])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
