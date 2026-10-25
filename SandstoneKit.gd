extends RefCounted
## Procedural sandstone for the Canyon Course (regenerate_canyon.gd), all drawn by canyon_rock.gdshader,
## whose beds come from the world height: a block, a butte and the cliff behind them show the same beds.
## Replaces the imported boulder and formation models, which read as stacked pancakes, cairns and grey
## blobs against the generated cliffs.
##
##   block()    a fallen block: a rounded box sheared by fracture planes into flat broken faces, its
##              bedding weathered into shallow grooves. About 1m across, base at y = 0.
##   pebbles()  a scatter of small stones, some dark with desert varnish, on y = 0 (about 2.4m across).
##   butte()    a small mesa: a talus apron, cliffs in tiers with ledges between, a cap rock overhanging.
##   spires()   a cluster of pinnacles on a shared talus mound.
##   balanced() a pedestal with a block resting on its neck.
## Vertex colour: r how shaded the rock is (its foot, under ledges), g desert varnish (darkens it).

static func _superellipsoid(dir: Vector3, ext: Vector3, n: float) -> Vector3:
	var s: float = pow(pow(absf(dir.x / ext.x), n) + pow(absf(dir.y / ext.y), n) + pow(absf(dir.z / ext.z), n), 1.0 / n)
	return dir / maxf(s, 1e-5)


## Adds a closed block to the arrays: centred on `c`, turned by `basis`, `size` across. Vertices on the
## cube's shared edges are merged, so the normals run smoothly round its rounded edges.
static func _add_block(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, seed_v: int, subdiv: int,
		c: Vector3, basis: Basis, size: float, varnish: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var ext := Vector3(rng.randf_range(0.42, 0.6), rng.randf_range(0.24, 0.46), rng.randf_range(0.32, 0.54))
	var boxy: float = rng.randf_range(6.0, 11.0)
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 1.6
	noise.fractal_octaves = 3
	var cuts: Array = []
	# Fractures across corners and edges, some deep enough to take off a whole side at a slant.
	for k in range(rng.randi_range(3, 6)):
		var nrm := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		cuts.append([nrm, _superellipsoid(nrm, ext, boxy).length() * rng.randf_range(0.6, 0.86)])
	# Often it broke along a bed: a flat top.
	if rng.randf() < 0.6:
		cuts.append([Vector3.UP, ext.y * rng.randf_range(0.78, 0.92)])
	var bed: float = rng.randf_range(0.12, 0.26)
	var bed_ph: float = rng.randf() * TAU
	var bed_depth: float = rng.randf_range(0.006, 0.02)
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	var lookup := {}
	var local := PackedVector3Array()
	var start: int = verts.size()
	var tris := PackedInt32Array()
	for f in faces:
		var fn: Vector3 = f[0]
		var fu: Vector3 = f[1]
		var fv: Vector3 = f[2]
		var grid := PackedInt32Array()
		for j in range(subdiv + 1):
			for i in range(subdiv + 1):
				var cc: Vector3 = fn + fu * (2.0 * float(i) / float(subdiv) - 1.0) + fv * (2.0 * float(j) / float(subdiv) - 1.0)
				var key := Vector3i(roundi(cc.x * 1000.0), roundi(cc.y * 1000.0), roundi(cc.z * 1000.0))
				if lookup.has(key):
					grid.append(lookup[key])
					continue
				var dir: Vector3 = cc.normalized()
				var p: Vector3 = _superellipsoid(dir, ext, boxy)
				for cut in cuts:
					var dd: float = p.dot(cut[0]) - float(cut[1])
					if dd > 0.0:
						p -= (cut[0] as Vector3) * dd
				var disp: float = noise.get_noise_3dv(p) * 0.03 + noise.get_noise_3dv(p * 4.0 + Vector3(7, 3, 1)) * 0.012
				disp -= bed_depth * smoothstep(0.7, 1.0, absf(sin(p.y / bed * PI + bed_ph)))
				p += dir * disp
				lookup[key] = local.size()
				grid.append(local.size())
				local.append(p)
		for j in range(subdiv):
			for i in range(subdiv):
				var a: int = grid[j * (subdiv + 1) + i]
				var b: int = grid[j * (subdiv + 1) + i + 1]
				var c2: int = grid[(j + 1) * (subdiv + 1) + i]
				var d: int = grid[(j + 1) * (subdiv + 1) + i + 1]
				tris.append_array([a, b, d, a, d, c2])
	var lo: float = INF
	var hi: float = -INF
	for p in local:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	for p in local:
		var shade: float = clampf(0.5 - (p.y - lo) / maxf(hi - lo, 0.01) * 0.9, 0.0, 0.5)
		verts.append(c + basis * (p * size))
		cols.append(Color(shade, varnish, 0.0, 1.0))
	# Front faces wind clockwise, (c - a) x (b - a) outward (CLAUDE.md): the shape is star-shaped
	# about its centre, so each triangle is checked against that.
	for t in range(0, tris.size(), 3):
		var a: int = tris[t]
		var b: int = tris[t + 1]
		var e: int = tris[t + 2]
		var pa: Vector3 = local[a]
		var nrm: Vector3 = (local[e] - pa).cross(local[b] - pa)
		if nrm.dot(pa + local[b] + local[e]) < 0.0:
			var tmp: int = b
			b = e
			e = tmp
		idx.append_array([start + a, start + b, start + e])


static func _commit(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, mat: Material) -> ArrayMesh:
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	for t in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[t]]
		var fnm: Vector3 = (verts[idx[t + 2]] - a).cross(verts[idx[t + 1]] - a)
		for k in range(3):
			nrm[idx[t + k]] += fnm
	for i in range(nrm.size()):
		nrm[i] = nrm[i].normalized()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, mat)
	return mesh


## A block about a metre across, its base at y = 0 and centred in x and z.
static func block(seed_v: int, subdiv: int, mat: Material) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	_add_block(verts, cols, idx, seed_v, subdiv, Vector3.ZERO, Basis(), 1.0, 0.0)
	_to_ground(verts)
	return _commit(verts, cols, idx, mat)


## Small stones strewn over about 2.4m, a third of each sunk, most of them dark with varnish.
static func pebbles(seed_v: int, count: int, subdiv: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for k in range(count):
		var size: float = rng.randf_range(0.09, 0.32) * (1.6 if rng.randf() < 0.15 else 1.0)
		var r: float = sqrt(rng.randf()) * 1.2
		var a: float = rng.randf() * TAU
		var c := Vector3(cos(a) * r, size * 0.08, sin(a) * r)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		_add_block(verts, cols, idx, seed_v * 31 + k, subdiv, c, b, size, rng.randf_range(0.0, 0.85) if rng.randf() < 0.75 else 0.0)
	return _commit(verts, cols, idx, mat)


static func _to_ground(verts: PackedVector3Array) -> void:
	var lo: float = INF
	for v in verts:
		lo = minf(lo, v.y)
	for i in range(verts.size()):
		verts[i].y -= lo


## A ring-lofted rock column: `profile` is (radius factor, height) from the foot up; each ring's outline
## is `outline` (radius per segment) scaled by its factor, roughened by `noise`. Shade per ring.
static func _loft(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, c: Vector3, outline: PackedFloat32Array,
		profile: Array, shades: Array, noise: FastNoiseLite, rough: float, cap: bool) -> void:
	var segs: int = outline.size()
	var start: int = verts.size()
	for k in range(profile.size()):
		var pr: Vector2 = profile[k]
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var r: float = outline[j] * pr.x
			var q: Vector3 = c + dir * r + Vector3.UP * pr.y
			# Fluting: gullies down the cliffs, worn deeper where the rock is weaker.
			r *= 1.0 + noise.get_noise_3d(q.x * 0.5, q.y * 0.09, q.z * 0.5) * rough + noise.get_noise_3d(q.x * 2.0, q.y * 0.5, q.z * 2.0) * rough * 0.35
			verts.append(c + dir * r + Vector3.UP * pr.y)
			cols.append(Color(float(shades[k]), 0.0, 0.0, 1.0))
	for k in range(profile.size() - 1):
		for j in range(segs):
			var a0: int = start + k * segs + j
			var a1: int = start + k * segs + (j + 1) % segs
			# Outward (clockwise) with the ring running from +x toward +z.
			idx.append_array([a0, a1, a1 + segs, a0, a1 + segs, a0 + segs])
	if cap:
		var top_start: int = start + (profile.size() - 1) * segs
		var top_y: float = (profile[profile.size() - 1] as Vector2).y
		var centre: int = verts.size()
		verts.append(c + Vector3.UP * (top_y + 0.4))
		cols.append(Color(0.0, 0.0, 0.0, 1.0))
		for j in range(segs):
			idx.append_array([top_start + j, top_start + (j + 1) % segs, centre])


## The lobed outline of a rock in plan: radius per segment about 1.
static func _outline(rng: RandomNumberGenerator, segs: int, lobes: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var ph1: float = rng.randf() * TAU
	var ph2: float = rng.randf() * TAU
	var ph3: float = rng.randf() * TAU
	var l1: float = floorf(rng.randf_range(2.0, 3.99))
	for j in range(segs):
		var a: float = TAU * float(j) / float(segs)
		out.append(1.0 + lobes * (0.6 * sin(a * l1 + ph1) + 0.3 * sin(a * (l1 + 2.0) + ph2) + 0.15 * sin(a * 7.0 + ph3)))
	return out


static func _noise(seed_v: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = 0.25
	n.fractal_octaves = 3
	return n


## A small mesa, `radius` across its cliffs and `height` tall: a concave talus apron, two or three tiers
## of cliff with a ledge between each, and a cap rock that overhangs a little. Base at y = 0 (sink it).
static func butte(seed_v: int, radius: float, height: float, segs: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var outline: PackedFloat32Array = _outline(rng, segs, 0.16)
	var prof: Array = []
	var shades: Array = []
	var apron_h: float = height * rng.randf_range(0.18, 0.26)
	for k in range(5):
		var t: float = float(k) / 4.0
		prof.append(Vector2(radius * lerpf(1.75, 1.04, sqrt(t)), apron_h * t))
		shades.append(0.0)
	var tiers: int = rng.randi_range(1, 2)
	var cliff_h: float = (height - apron_h) / float(tiers)
	var r_t: float = 1.04
	for ti in range(tiers):
		var y0: float = apron_h + cliff_h * float(ti)
		var top_tier: bool = ti == tiers - 1
		prof.append(Vector2(radius * r_t, y0 + 0.3))
		shades.append(0.25)
		prof.append(Vector2(radius * (r_t - 0.02), y0 + cliff_h * 0.5))
		shades.append(0.1)
		if top_tier:
			# The cap rock: harder, so it overhangs the softer bed under it.
			prof.append(Vector2(radius * (r_t - 0.05), y0 + cliff_h * 0.78))
			shades.append(0.35)
			prof.append(Vector2(radius * (r_t - 0.01), y0 + cliff_h * 0.82))
			shades.append(0.0)
			prof.append(Vector2(radius * (r_t - 0.02), height))
			shades.append(0.0)
		else:
			prof.append(Vector2(radius * (r_t - 0.04), y0 + cliff_h * 0.97))
			shades.append(0.0)
			# The ledge: a bench of the softer bed, set back.
			r_t -= rng.randf_range(0.05, 0.1)
			prof.append(Vector2(radius * (r_t + 0.03), y0 + cliff_h))
			shades.append(0.0)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	_loft(verts, cols, idx, Vector3.ZERO, outline, prof, shades, _noise(seed_v), 0.1, true)
	return _commit(verts, cols, idx, mat)


## A cluster of `count` pinnacles up to `height` on a shared talus mound, base at y = 0.
static func spires(seed_v: int, count: int, height: float, segs: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var noise: FastNoiseLite = _noise(seed_v)
	var spread: float = height * 0.34
	# The mound they stand on.
	var mound: PackedFloat32Array = _outline(rng, segs, 0.12)
	_loft(verts, cols, idx, Vector3.ZERO, mound, [Vector2(spread * 1.7, 0.0), Vector2(spread * 1.25, height * 0.06), Vector2(spread * 0.7, height * 0.11), Vector2(spread * 0.2, height * 0.13)], [0.0, 0.1, 0.2, 0.3], noise, 0.05, true)
	for k in range(count):
		var a: float = TAU * float(k) / float(count) + rng.randf_range(-0.4, 0.4)
		var d: float = spread * (0.1 if k == 0 else rng.randf_range(0.6, 1.05))
		var c := Vector3(cos(a) * d, 0.0, sin(a) * d)
		var h: float = height * (1.0 if k == 0 else rng.randf_range(0.4, 0.9))
		var r0: float = h * rng.randf_range(0.1, 0.14)
		var outline: PackedFloat32Array = _outline(rng, segs, 0.14)
		var prof: Array = []
		var shades: Array = []
		var rings := 12
		var waves: float = rng.randf_range(2.0, 4.0)
		var ph: float = rng.randf() * TAU
		for i in range(rings + 1):
			var t: float = float(i) / float(rings)
			var r: float = r0 * (1.25 - 0.55 * t) * (1.0 + 0.16 * sin(t * PI * waves + ph))
			prof.append(Vector2(r, t * h))
			shades.append(clampf(0.35 - t * 0.5, 0.0, 0.35))
		prof.append(Vector2(r0 * 0.5, h + r0 * 0.4))
		shades.append(0.0)
		_loft(verts, cols, idx, c, outline, prof, shades, noise, 0.12, true)
	return _commit(verts, cols, idx, mat)


## A pedestal `height` tall, necked under a block that rests on it.
static func balanced(seed_v: int, height: float, segs: int, block_subdiv: int, mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var noise: FastNoiseLite = _noise(seed_v)
	var ped_h: float = height * 0.62
	var r0: float = height * 0.16
	var outline: PackedFloat32Array = _outline(rng, segs, 0.12)
	_loft(verts, cols, idx, Vector3.ZERO, outline, [Vector2(r0 * 1.9, 0.0), Vector2(r0 * 1.25, ped_h * 0.15), Vector2(r0 * 1.0, ped_h * 0.45),
		Vector2(r0 * 0.7, ped_h * 0.8), Vector2(r0 * 0.5, ped_h * 0.96), Vector2(r0 * 0.3, ped_h * 1.02)], [0.0, 0.1, 0.15, 0.3, 0.45, 0.5], noise, 0.1, true)
	var size: float = height * 0.62
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.12, 0.12))
	_add_block(verts, cols, idx, seed_v * 7 + 1, block_subdiv, Vector3(0.0, ped_h + size * 0.22, 0.0), b, size, 0.0)
	return _commit(verts, cols, idx, mat)
