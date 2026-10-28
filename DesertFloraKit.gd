extends RefCounted
## Procedural non-FBX desert flora for Canyon Chasm (`ChasmDressing.gd`), built in code with
## vertex colors and smooth normals so the level uses zero `.fbx` plant models:
##   joshua   Mojave/Sonoran Joshua tree (`Yucca brevifolia`): fibrous furrowed bark trunk and
##            forking limbs topped with dense spherical rosettes of dagger-like spiky leaves
##            and a skirt of dry golden-tan dead thatch underneath each crown.
##   agave    Blue-green desert century plant (`Agave`): a sculptured basal rosette of thick,
##            curving succulent leaves with marginal teeth and dark terminal spines, nestled on
##            a cluster of desert cobbles.
##   yucca    Fountain-like desert yucca / sotol: dozens of narrow sword-like olive-green leaves
##            radiating from a short caudex trunk, with tall creamy-white flower panicles.
##   shrub    Multi-stemmed desert creosote / sagebrush bush with gnarled twigs and billowy
##            foliage clusters in dusty olive and sage-green tones.
##   flowers  Low desert brittlebush & marigold clump with silvery-green leaves and warm
##            golden-yellow / orange desert blooms beside small stones.

const SPECIES := ["joshua", "agave", "yucca", "shrub", "flowers"]
const VARIANTS := {"joshua": 3, "agave": 3, "yucca": 3, "shrub": 3, "flowers": 3}
const KIND := {"joshua": "tall", "agave": "plant", "yucca": "plant", "shrub": "plant", "flowers": "plant"}
const HEIGHT_RANGE := {
	"joshua": Vector2(5.2, 8.8),
	"agave": Vector2(1.4, 2.5),
	"yucca": Vector2(1.6, 2.8),
	"shrub": Vector2(1.3, 2.4),
	"flowers": Vector2(0.9, 1.6),
}

static var _mat: StandardMaterial3D = null


static func material() -> StandardMaterial3D:
	if _mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.82
		m.metallic_specular = 0.18
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat = m
	return _mat


static func build(species: String, variant: int, lod: int, mat: Material = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19391 * (SPECIES.find(species) + 1) + variant * 65537
	match species:
		"joshua":
			_build_joshua(st, rng, variant, lod)
		"agave":
			_build_agave(st, rng, variant, lod)
		"yucca":
			_build_yucca(st, rng, variant, lod)
		"shrub":
			_build_shrub(st, rng, variant, lod)
		"flowers":
			_build_flowers(st, rng, variant, lod)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat if mat != null else material())
	return mesh


# ------------------------------------------------------------------
# 1. Joshua Tree (fibrous branching trunk + spiky dagger-leaf crowns)
# ------------------------------------------------------------------
static func _build_joshua(st: SurfaceTool, rng: RandomNumberGenerator, variant: int, lod: int) -> void:
	var bark_base := Color(0.36, 0.29, 0.22)
	var bark_top := Color(0.46, 0.38, 0.29)
	var thatch_col := Color(0.58, 0.49, 0.34)
	var leaf_base := Color(0.28, 0.38, 0.20)
	var leaf_tip := Color(0.42, 0.50, 0.26)

	var sides := 7 if lod == 0 else 4
	var trunk_h := 0.44 + float(variant) * 0.04
	var lean := Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))
	var p0 := Vector3(0.0, -0.04, 0.0)
	var p1 := Vector3(lean.x * 0.5, trunk_h * 0.5, lean.z * 0.5)
	var p2 := Vector3(lean.x, trunk_h, lean.z)
	_add_tube(st, [p0, p1, p2], [0.085, 0.068, 0.056], sides, bark_base, bark_top)

	# 3 to 5 primary limbs forking from trunk top, some forking once more
	var branch_count := 3 + (variant % 3)
	for b in branch_count:
		var az := TAU * float(b) / float(branch_count) + rng.randf_range(-0.28, 0.28)
		var out_r := rng.randf_range(0.18, 0.28)
		var b_top_y := rng.randf_range(0.76, 0.94)
		var dir_xz := Vector3(cos(az), 0.0, sin(az))
		var bp1 := p2 + dir_xz * (out_r * 0.55) + Vector3(0.0, (b_top_y - trunk_h) * 0.45, 0.0)
		var bp2 := p2 + dir_xz * out_r + Vector3(0.0, b_top_y - trunk_h, 0.0)
		_add_tube(st, [p2, bp1, bp2], [0.052, 0.044, 0.038], sides, bark_base, bark_top)
		_add_joshua_crown(st, bp2, (bp2 - bp1).normalized(), 0.14, leaf_base, leaf_tip, thatch_col, rng, lod)

		# Secondary fork on alternate limbs
		if b % 2 == 0:
			var az2 := az + rng.randf_range(0.45, 0.75) * (1.0 if b == 0 else -1.0)
			var dir2 := Vector3(cos(az2), 0.0, sin(az2))
			var sp2 := bp1 + dir2 * rng.randf_range(0.14, 0.22) + Vector3(0.0, rng.randf_range(0.18, 0.26), 0.0)
			_add_tube(st, [bp1, (bp1 + sp2) * 0.5 + Vector3(0, -0.02, 0), sp2], [0.042, 0.036, 0.032], sides, bark_base, bark_top)
			_add_joshua_crown(st, sp2, (sp2 - bp1).normalized(), 0.12, leaf_base, leaf_tip, thatch_col, rng, lod)


static func _add_joshua_crown(st: SurfaceTool, center: Vector3, axis: Vector3, radius: float,
		col_base: Color, col_tip: Color, col_thatch: Color, rng: RandomNumberGenerator, lod: int) -> void:
	# Dry golden-brown thatch collar just below the green leaf rosette
	var collar_c := center - axis * (radius * 0.35)
	_add_ellipsoid(st, collar_c, Vector3(radius * 0.52, radius * 0.58, radius * 0.52), 5 if lod == 0 else 4, col_thatch * 0.82, col_thatch)
	# Core green tuft mass so the crown reads solid from any distance
	_add_ellipsoid(st, center, Vector3(radius * 0.56, radius * 0.56, radius * 0.56), 5 if lod == 0 else 4, col_base * 0.85, col_tip)
	# Radiating dagger blades
	var blades := 26 if lod == 0 else 10
	var golden := PI * (3.0 - sqrt(5.0))
	for i in blades:
		var y := 1.0 - (float(i) / float(blades - 1)) * 1.65 # from +1.0 down to -0.65
		var r_ring := sqrt(maxf(0.0, 1.0 - y * y))
		var theta := golden * float(i) + rng.randf_range(-0.1, 0.1)
		var dir := Vector3(cos(theta) * r_ring, y, sin(theta) * r_ring).normalized()
		var is_thatch := y < -0.25
		var c0 := col_thatch * 0.85 if is_thatch else col_base
		var c1 := col_thatch * 1.08 if is_thatch else col_tip
		var len_b := radius * rng.randf_range(0.95, 1.25)
		_add_blade(st, center + dir * (radius * 0.18), dir, len_b, radius * 0.18, 0.08 if is_thatch else -0.05, c0, c1, lod)


# ------------------------------------------------------------------
# 2. Blue Agave (sculpted succulent rosette + basal desert stones)
# ------------------------------------------------------------------
static func _build_agave(st: SurfaceTool, rng: RandomNumberGenerator, variant: int, lod: int) -> void:
	var col_base := Color(0.20, 0.34, 0.28).lerp(Color(0.24, 0.38, 0.34), float(variant) * 0.35)
	var col_mid := Color(0.30, 0.48, 0.42).lerp(Color(0.34, 0.52, 0.46), float(variant) * 0.35)
	var col_tip := Color(0.38, 0.24, 0.18) # dark reddish-brown terminal spine tip
	var rock_col := Color(0.62, 0.46, 0.36)

	# Small basal stones around the agave foot
	var stone_n := 5 if lod == 0 else 3
	for s in stone_n:
		var sa := TAU * float(s) / float(stone_n) + rng.randf_range(-0.3, 0.3)
		var sr := rng.randf_range(0.26, 0.44)
		var sc := Vector3(cos(sa) * sr, 0.05, sin(sa) * sr)
		var rad := Vector3(rng.randf_range(0.10, 0.18), rng.randf_range(0.06, 0.11), rng.randf_range(0.09, 0.16))
		_add_ellipsoid(st, sc, rad, 5 if lod == 0 else 4, rock_col * 0.72, rock_col)

	# Three concentric whorls of thick, recurved succulent blades + central conical bud spire
	var rings := [
		[11 if lod == 0 else 6, 0.32, 0.56, 0.16, 0.22], # outer low spreading whorl
		[9 if lod == 0 else 5, 0.62, 0.52, 0.15, 0.16],  # middle ascending whorl
		[6 if lod == 0 else 4, 1.02, 0.44, 0.12, 0.08],  # inner upright whorl
	]
	for r_idx in rings.size():
		var ring: Array = rings[r_idx]
		var count: int = ring[0]
		var elev: float = ring[1]
		var blen: float = ring[2]
		var bw: float = ring[3]
		var droop: float = ring[4]
		var phase := float(r_idx) * 0.42 + float(variant) * 0.7
		for i in count:
			var a := TAU * float(i) / float(count) + phase + rng.randf_range(-0.08, 0.08)
			var dir := Vector3(cos(a), elev + rng.randf_range(-0.05, 0.05), sin(a)).normalized()
			_add_succulent_leaf(st, Vector3(cos(a) * 0.05, 0.04, sin(a) * 0.05), dir,
				blen * rng.randf_range(0.9, 1.1), bw, droop, col_base, col_mid, col_tip, lod)

	# Central tight bud cone
	_add_tube(st, [Vector3(0, 0.04, 0), Vector3(0, 0.48, 0)], [0.08, 0.01], 6 if lod == 0 else 4, col_base, col_mid)


# ------------------------------------------------------------------
# 3. Desert Yucca / Sotol (spiky fountain crown + optional bloom stalk)
# ------------------------------------------------------------------
static func _build_yucca(st: SurfaceTool, rng: RandomNumberGenerator, variant: int, lod: int) -> void:
	var col_trunk := Color(0.38, 0.31, 0.24)
	var col_leaf0 := Color(0.26, 0.36, 0.18)
	var col_leaf1 := Color(0.44, 0.52, 0.26)
	var col_bloom := Color(0.94, 0.90, 0.78)

	# Short fibrous caudex base
	var base_h := 0.18 + float(variant) * 0.05
	_add_tube(st, [Vector3(0, -0.02, 0), Vector3(0, base_h, 0)], [0.11, 0.09], 6 if lod == 0 else 4, col_trunk * 0.8, col_trunk)

	var center := Vector3(0.0, base_h, 0.0)
	var blade_count := 34 if lod == 0 else 14
	var golden := PI * (3.0 - sqrt(5.0))
	for i in blade_count:
		var t := float(i) / float(blade_count - 1)
		var y := lerpf(0.10, 0.96, t)
		var r_ring := sqrt(maxf(0.0, 1.0 - y * y))
		var theta := golden * float(i) + float(variant)
		var dir := Vector3(cos(theta) * r_ring, y, sin(theta) * r_ring).normalized()
		var blen := rng.randf_range(0.46, 0.62)
		_add_blade(st, center + dir * 0.04, dir, blen, 0.045, 0.18 * (1.0 - t), col_leaf0, col_leaf1, lod)

	# Tall central creamy-white yucca flower stalk on variants 0 and 2
	if variant != 1:
		var stalk_top := Vector3(rng.randf_range(-0.03, 0.03), 1.02, rng.randf_range(-0.03, 0.03))
		_add_tube(st, [center, (center + stalk_top) * 0.5, stalk_top], [0.024, 0.018, 0.010], 5 if lod == 0 else 4, col_trunk, col_leaf1)
		for b in (5 if lod == 0 else 2):
			var bt := float(b) / 4.5
			var bp := center.lerp(stalk_top, 0.58 + bt * 0.38)
			var br := lerpf(0.09, 0.045, bt)
			_add_ellipsoid(st, bp, Vector3(br, br * 1.35, br), 5 if lod == 0 else 4, col_bloom * 0.85, col_bloom)


# ------------------------------------------------------------------
# 4. Desert Scrub / Sagebrush Bush
# ------------------------------------------------------------------
static func _build_shrub(st: SurfaceTool, rng: RandomNumberGenerator, variant: int, lod: int) -> void:
	var wood_col := Color(0.34, 0.28, 0.22)
	var leaf_dark := Color(0.28, 0.35, 0.22).lerp(Color(0.32, 0.38, 0.26), float(variant) * 0.35)
	var leaf_lit := Color(0.44, 0.50, 0.33).lerp(Color(0.48, 0.53, 0.38), float(variant) * 0.35)

	var stems := 6 + (variant % 2)
	for s in stems:
		var a := TAU * float(s) / float(stems) + rng.randf_range(-0.25, 0.25)
		var spread := rng.randf_range(0.26, 0.44)
		var top_y := rng.randf_range(0.48, 0.78)
		var p0 := Vector3(cos(a) * 0.04, -0.02, sin(a) * 0.04)
		var p1 := Vector3(cos(a) * spread * 0.55, top_y * 0.48, sin(a) * spread * 0.55)
		var p2 := Vector3(cos(a) * spread, top_y, sin(a) * spread)
		_add_tube(st, [p0, p1, p2], [0.032, 0.022, 0.014], 5 if lod == 0 else 3, wood_col * 0.85, wood_col)
		# Foliage cushions along upper twigs
		var puffs := 3 if lod == 0 else 1
		for p in puffs:
			var pc := p1.lerp(p2, 0.45 + float(p) * 0.28) + Vector3(
				rng.randf_range(-0.08, 0.08), rng.randf_range(-0.04, 0.06), rng.randf_range(-0.08, 0.08))
			var rx := rng.randf_range(0.16, 0.25)
			var ry := rng.randf_range(0.11, 0.18)
			_add_ellipsoid(st, pc, Vector3(rx, ry, rx * rng.randf_range(0.85, 1.15)), 5 if lod == 0 else 4, leaf_dark, leaf_lit)

	# Central crown cushion so the shrub has a full, natural silhouette
	_add_ellipsoid(st, Vector3(0.0, 0.36, 0.0), Vector3(0.32, 0.22, 0.30), 6 if lod == 0 else 4, leaf_dark * 0.9, leaf_lit)


# ------------------------------------------------------------------
# 5. Desert Brittlebush & Wildflower Clump with Stones
# ------------------------------------------------------------------
static func _build_flowers(st: SurfaceTool, rng: RandomNumberGenerator, variant: int, lod: int) -> void:
	var leaf_dark := Color(0.30, 0.38, 0.26)
	var leaf_lit := Color(0.46, 0.54, 0.38)
	var bloom_col := Color(0.95, 0.74, 0.16) if variant != 1 else Color(0.92, 0.48, 0.18)
	var rock_col := Color(0.64, 0.47, 0.36)

	# 2-3 desert cobbles beside the flower mound
	for r in (3 if lod == 0 else 2):
		var ra := TAU * float(r) / 3.0 + float(variant)
		var rc := Vector3(cos(ra) * 0.28, 0.06, sin(ra) * 0.28)
		_add_ellipsoid(st, rc, Vector3(0.14, 0.09, 0.12), 5 if lod == 0 else 4, rock_col * 0.75, rock_col)

	# Rounded silvery-sage foliage mound
	for m in (5 if lod == 0 else 2):
		var ma := TAU * float(m) / 5.0
		var mr := 0.14 if m > 0 else 0.0
		var mc := Vector3(cos(ma) * mr, 0.18 + (0.05 if m == 0 else 0.0), sin(ma) * mr)
		_add_ellipsoid(st, mc, Vector3(0.24, 0.16, 0.22), 5 if lod == 0 else 4, leaf_dark, leaf_lit)

	# Bright desert flower heads rising just above the foliage mound
	var blooms := 9 if lod == 0 else 4
	for b in blooms:
		var ba := TAU * float(b) / float(blooms) + rng.randf_range(-0.2, 0.2)
		var br := rng.randf_range(0.06, 0.32)
		var by := rng.randf_range(0.32, 0.48)
		var bc := Vector3(cos(ba) * br, by, sin(ba) * br)
		_add_ellipsoid(st, bc, Vector3(0.065, 0.042, 0.065), 4, bloom_col * 0.85, bloom_col)


# ------------------------------------------------------------------
# Geometry Primitives
# ------------------------------------------------------------------
static func _add_tube(st: SurfaceTool, pts: Array, radii: Array, sides: int, col0: Color, col1: Color) -> void:
	var n := pts.size()
	if n < 2:
		return
	var t0 := ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var ref := Vector3.RIGHT if absf(t0.dot(Vector3.UP)) > 0.9 else Vector3.UP
	var nrm := t0.cross(ref).normalized()
	var rings: Array = []
	var cols: Array = []
	for i in n:
		var t := ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		var bin := t.cross(nrm)
		var r: float = radii[i]
		var c := col0.lerp(col1, float(i) / float(n - 1))
		var ring := PackedVector3Array()
		for s in sides:
			var a := TAU * float(s) / float(sides)
			ring.append((pts[i] as Vector3) + (nrm * cos(a) + bin * sin(a)) * r)
		rings.append(ring)
		cols.append(c)
	for i in range(n - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var c0: Color = cols[i]
		var c1: Color = cols[i + 1]
		for s in sides:
			var sn := (s + 1) % sides
			_tri(st, r0[s], r0[sn], r1[sn], c0, c0, c1)
			_tri(st, r0[s], r1[sn], r1[s], c0, c1, c1)


static func _add_blade(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float,
		droop: float, col0: Color, col1: Color, lod: int) -> void:
	var side := Vector3.UP.cross(dir)
	if side.length_squared() < 1e-4:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := dir.cross(side).normalized()
	var mid := base + dir * (length * 0.52) - Vector3.UP * (droop * length * 0.35) + up * (width * 0.18)
	var tip := base + dir * length - Vector3.UP * (droop * length)
	var w0 := side * (width * 0.5)
	var w1 := side * (width * 0.32)
	var c_mid := col0.lerp(col1, 0.55)
	if lod == 0:
		_tri(st, base - w0, base + w0, mid + w1, col0, col0, c_mid)
		_tri(st, base - w0, mid + w1, mid - w1, col0, c_mid, c_mid)
		_tri(st, mid - w1, mid + w1, tip, c_mid, c_mid, col1)
	else:
		_tri(st, base - w0, base + w0, tip, col0, col0, col1)


static func _add_succulent_leaf(st: SurfaceTool, base: Vector3, dir: Vector3, length: float, width: float,
		droop: float, col_base: Color, col_mid: Color, col_tip: Color, lod: int) -> void:
	var side := Vector3.UP.cross(dir)
	if side.length_squared() < 1e-4:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := dir.cross(side).normalized()
	var p1 := base + dir * (length * 0.45) + up * (length * 0.08) - Vector3.UP * (droop * length * 0.25)
	var p2 := base + dir * (length * 0.82) - Vector3.UP * (droop * length * 0.70)
	var tip := base + dir * length - Vector3.UP * (droop * length)
	var w0 := side * (width * 0.42)
	var w1 := side * (width * 0.52)
	var w2 := side * (width * 0.26)
	var keel0 := -up * (width * 0.18)
	var keel1 := -up * (width * 0.22)
	if lod == 0:
		# Left and right cupped halves meeting along a lower V-keel so the agave blade has real 3D thickness
		_tri(st, base - w0, base + keel0, p1 + keel1, col_base, col_base, col_mid)
		_tri(st, base - w0, p1 + keel1, p1 - w1, col_base, col_mid, col_mid)
		_tri(st, base + keel0, base + w0, p1 + w1, col_base, col_base, col_mid)
		_tri(st, base + keel0, p1 + w1, p1 + keel1, col_base, col_mid, col_mid)
		_tri(st, p1 - w1, p1 + keel1, p2 - w2, col_mid, col_mid, col_mid)
		_tri(st, p1 + keel1, p1 + w1, p2 + w2, col_mid, col_mid, col_mid)
		_tri(st, p1 + keel1, p2 + w2, p2 - w2, col_mid, col_mid, col_mid)
		_tri(st, p2 - w2, p2 + w2, tip, col_mid, col_mid, col_tip)
	else:
		_tri(st, base - w0, base + w0, p1 + w1, col_base, col_base, col_mid)
		_tri(st, base - w0, p1 + w1, p1 - w1, col_base, col_mid, col_mid)
		_tri(st, p1 - w1, p1 + w1, tip, col_mid, col_mid, col_tip)


static func _add_ellipsoid(st: SurfaceTool, center: Vector3, radii: Vector3, segs: int, col_bot: Color, col_top: Color) -> void:
	var rings := maxi(3, segs / 2 + 1)
	for r in rings:
		var v0 := float(r) / float(rings)
		var v1 := float(r + 1) / float(rings)
		var th0 := v0 * PI
		var th1 := v1 * PI
		var c0 := col_top.lerp(col_bot, v0)
		var c1 := col_top.lerp(col_bot, v1)
		for s in segs:
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			var p00 := center + Vector3(sin(th0) * cos(a0), cos(th0), sin(th0) * sin(a0)) * radii
			var p01 := center + Vector3(sin(th0) * cos(a1), cos(th0), sin(th0) * sin(a1)) * radii
			var p10 := center + Vector3(sin(th1) * cos(a0), cos(th1), sin(th1) * sin(a0)) * radii
			var p11 := center + Vector3(sin(th1) * cos(a1), cos(th1), sin(th1) * sin(a1)) * radii
			if r > 0:
				_tri(st, p00, p01, p11, c0, c0, c1)
			if r < rings - 1:
				_tri(st, p00, p11, p10, c0, c1, c1)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca); st.add_vertex(a)
	st.set_color(cb); st.add_vertex(b)
	st.set_color(cc); st.add_vertex(c)
