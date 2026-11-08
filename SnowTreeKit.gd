extends RefCounted
## Winter trees for the Svartfjell GP's snowy stages (regenerate_frostpeak_dressing.gd).
##
## - The spruce is Frostfall Gorge's snowy spruce (regenerate_frostfall_gorge.gd, _spruce_mesh): a
##   trunk under whorls of separate drooping branches, each a curved card of drawn needle spray
##   (WoodlandBuilder's spruce atlas cell), alpha-tested by spruce_fronds.gdshader, with snow lying on
##   the upper side of each branch. Copied here so a second level can use it without touching that
##   generator. Two surfaces: 0 the trunk (spruce.gdshader), 1 the fronds.
## - The birch is WoodlandBuilder's birch (its limbs, branches and hanging sprays, BROADLEAF["birch"]),
##   bare for the winter: the leaf cards show a spray of fine, forking twigs (twig_atlas(), drawn in the
##   birch's own atlas cell) through winter_twigs.gdshader, so a crown reads as a purple-brown haze over a
##   white trunk, rimed with frost on top.
##
## Every tree has a far stand-in (`lod` 1). Materials are made once per kit (near and far, for the
## per-tree crossfade, tree_lod.gdshaderinc) and saved through `save_res`; `lod_materials()` lists them
## for JungleDetail.gd, which moves the crossfade with the Detail Level.

const WoodlandBuilder = preload("res://WoodlandBuilder.gd")

## (res, name) -> the saved resource; set by the generator.
var save_res: Callable
## How much snow the spruces carry (spruce_fronds.gdshader's snow_amount) and the frost on the birches' twigs.
var spruce_snow := 0.4
var spruce_snow_shift := 0.2
var birch_frost := 0.3

var _woodland: WoodlandBuilder
var _spray_atlas: Texture2D
var _twig_atlas: Texture2D
var _mats := {}


func _wb() -> WoodlandBuilder:
	if _woodland == null:
		_woodland = WoodlandBuilder.new()
		_woodland.save_res = save_res
	return _woodland


# ======================================================================================
#  Materials
# ======================================================================================

## lod_mode 1: the detailed tree, 2: the far stand-in (tree_lod.gdshaderinc).
func spruce_bark(lod_mode: int) -> ShaderMaterial:
	var key := "spruce_bark_%d" % lod_mode
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://spruce.gdshader")
		WoodlandBuilder.set_lod(m, lod_mode)
		_mats[key] = save_res.call(m, "spruce_bark_%s" % ("near" if lod_mode == 1 else "far"))
	return _mats[key]


func spruce_fronds(lod_mode: int) -> ShaderMaterial:
	var key := "spruce_fronds_%d" % lod_mode
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://spruce_fronds.gdshader")
		m.set_shader_parameter("leaf_tex", spray_atlas())
		# Frostfall Gorge's 0.9 flocks a whole crown white; a lighter load leaves the dark needles showing.
		m.set_shader_parameter("snow_amount", spruce_snow)
		m.set_shader_parameter("snow_cover_shift", spruce_snow_shift)
		# Norway spruce is a dark blue-green.
		m.set_shader_parameter("needle_boost", 1.35)
		WoodlandBuilder.set_lod(m, lod_mode)
		_mats[key] = save_res.call(m, "spruce_fronds_%s" % ("near" if lod_mode == 1 else "far"))
	return _mats[key]


func birch_bark(lod_mode: int) -> ShaderMaterial:
	var key := "birch_bark_%d" % lod_mode
	if not _mats.has(key):
		var m: ShaderMaterial = _wb().bark_material("birch", lod_mode)
		_mats[key] = save_res.call(m, "birch_bark_%s" % ("near" if lod_mode == 1 else "far"))
	return _mats[key]


func birch_twigs(lod_mode: int) -> ShaderMaterial:
	var key := "birch_twigs_%d" % lod_mode
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://winter_twigs.gdshader")
		m.set_shader_parameter("twig_tex", twig_atlas())
		m.set_shader_parameter("sway", 0.08)
		m.set_shader_parameter("sway_height", 14.0)
		m.set_shader_parameter("frost", birch_frost)
		WoodlandBuilder.set_lod(m, lod_mode)
		_mats[key] = save_res.call(m, "birch_twigs_%s" % ("near" if lod_mode == 1 else "far"))
	return _mats[key]


## Every material whose crossfade band JungleDetail moves.
func lod_materials() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for m in _mats.values():
		if m is ShaderMaterial:
			out.append(m)
	return out


## WoodlandBuilder's leaf atlas, whose cell 3 (u and v from 0.5) is a spruce spray drawn upright with
## its base at the cell's foot, with coverage-preserving mipmaps so distant crowns keep their mass.
func spray_atlas() -> Texture2D:
	if _spray_atlas == null:
		_spray_atlas = _wb().atlas()
	return _spray_atlas


# ======================================================================================
#  Spruce (Frostfall Gorge's)
# ======================================================================================

## `variant` 0 is a tall mature tree (11m), 1 a younger, bushier one (7.6m). `lod` 0 is the near
## mesh, 1 the distant stand-in with the same outline in fewer whorls and fronds. `rich` is Frostfall Gorge's
## tree as it was (17 and 12 whorls, an under-frond on every branch; a 9-whorl stand-in): the Detail Level's
## Ultra. Otherwise the near mesh has 14 and 11 whorls with under-fronds on every other branch (about half the
## triangles) and the stand-in 8 whorls of 6 wide fronds with no under-fronds (about 500 triangles; with 6 whorls of
## flat single-segment fronds, 250, it read from afar as a bare pole).
func spruce_mesh(variant: int, lod: int, rich := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + variant * 31
	var height: float = 11.0 if variant == 0 else 7.6
	var base_r: float = 3.2 if variant == 0 else 3.0
	var whorls: int
	var per: int
	if rich:
		whorls = (17 if variant == 0 else 12) if lod == 0 else 9
		per = (9 if variant == 0 else 8) if lod == 0 else 6
	else:
		whorls = (14 if variant == 0 else 11) if lod == 0 else 8
		per = (8 if variant == 0 else 7) if lod == 0 else 6
	var segs: int = 2
	# The far stand-in's fronds are wider the fewer there are.
	var far_width: float = 0.8 if rich else 0.92

	# The trunk: a tapered tube, thick at the foot, with a swelling at the root.
	var bark_st := SurfaceTool.new()
	bark_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.12, 0.085, 0.06, 0.0)
	var sides: int = 8 if lod == 0 else (5 if rich else 4)
	var rings := 6 if lod == 0 or rich else 4
	var trunk_top: float = height - 0.5
	for ri in range(rings):
		var t0: float = float(ri) / float(rings)
		var t1: float = float(ri + 1) / float(rings)
		var y0: float = lerpf(-0.6, trunk_top, t0)
		var y1: float = lerpf(-0.6, trunk_top, t1)
		var r0: float = 0.36 * lerpf(1.0, 0.16, t0) * (1.0 + 0.3 * (1.0 - smoothstep(0.0, 0.1, t0)))
		var r1: float = 0.36 * lerpf(1.0, 0.16, t1) * (1.0 + 0.3 * (1.0 - smoothstep(0.0, 0.1, t1)))
		for k in range(sides):
			var a0: float = TAU * float(k) / float(sides)
			var a1: float = TAU * float(k + 1) / float(sides)
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var v: Array = [
				[d0 * r0 + Vector3(0, y0, 0), d0, Vector2(float(k) / sides, y0)],
				[d1 * r0 + Vector3(0, y0, 0), d1, Vector2(float(k + 1) / sides, y0)],
				[d0 * r1 + Vector3(0, y1, 0), d0, Vector2(float(k) / sides, y1)],
				[d1 * r1 + Vector3(0, y1, 0), d1, Vector2(float(k + 1) / sides, y1)],
			]
			var shade: float = lerpf(1.0, 0.8, t1)
			for tri in [[0, 2, 1], [1, 2, 3]]:
				for vi in tri:
					bark_st.set_normal(v[vi][1])
					bark_st.set_color(Color(bark.r * shade, bark.g * shade, bark.b * shade, 0.0))
					bark_st.set_uv(v[vi][2])
					bark_st.add_vertex(v[vi][0])

	# The fronds.
	var fr := SurfaceTool.new()
	fr.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vbase := 0
	var y_lo := 1.5
	var tint := Color(0.80, 1.0, 0.78)
	var rot := rng.randf() * TAU
	for w in range(whorls):
		var t: float = float(w) / float(whorls - 1)
		# Whorls close up toward the leader.
		var y: float = lerpf(y_lo, height - 1.6, 1.0 - pow(1.0 - t, 1.25)) + rng.randf_range(-0.12, 0.12)
		var reach: float = base_r * pow(1.0 - t * 0.93, 0.92) + 0.55
		var n: int = maxi(per - int(t * 3.0), 5 if lod == 0 else 4)
		rot += rng.randf_range(0.5, 1.4)
		var shade0: float = lerpf(0.62, 0.92, t)
		for b in range(n):
			var a: float = rot + TAU * float(b) / float(n) + rng.randf_range(-0.22, 0.22)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var length: float = reach * rng.randf_range(0.82, 1.12) * (1.0 if lod == 0 else 1.1)
			var by: float = y + rng.randf_range(-0.28, 0.28)
			# A sunlit upper frond, drooping at the tip; lower branches droop more.
			vbase = _spruce_frond(fr, vbase, Vector3(0, by, 0) + dir * 0.18, dir, rng.randf_range(0.06, 0.30) + t * t * 0.45,
					rng.randf_range(0.9, 1.4) * (1.0 - t * 0.5), length, length * (0.62 if lod == 0 else far_width), segs, tint, shade0,
					minf(shade0 + 0.3, 1.0), 0.30 + rng.randf_range(-0.08, 0.08), 0.95, rng.randf())
			if t < 0.9 and ((lod == 0 and (rich or b % 2 == 0)) or (lod != 0 and rich and b % 2 == 0)):
				# A shorter frond under the branch, between the upper ones: it holds no snow and sits
				# in the crown's shade.
				var d2: Vector3 = dir.rotated(Vector3.UP, PI / float(n) + rng.randf_range(-0.2, 0.2))
				vbase = _spruce_frond(fr, vbase, Vector3(0, by - 0.42, 0) + d2 * 0.18, d2, -0.12, rng.randf_range(0.7, 1.0),
						length * 0.74, length * 0.46, 2, tint.darkened(0.08), shade0 * 0.85, shade0, 0.28, 0.0, rng.randf())
	# The spire: rings of fronds standing up round the leader, shorter and steeper toward the tip.
	var spire := [[height - 2.9, 5, 1.7, 0.85, -0.15, 2.2], [height - 2.1, 5, 1.3, 1.0, -0.2, 1.8],
			[height - 1.35, 4, 1.0, 1.15, -0.2, 1.4], [height - 0.75, 4, 0.7, 1.3, -0.15, 1.0], [height - 0.3, 3, 0.45, 1.4, -0.1, 0.7]]
	if lod != 0 and not rich:
		spire = [spire[0], spire[2], spire[4]]
	for ring in spire:
		var rot2: float = rng.randf() * TAU
		for k in range(int(ring[1])):
			var a2: float = rot2 + TAU * float(k) / float(ring[1])
			var dir2 := Vector3(cos(a2), 0.0, sin(a2))
			vbase = _spruce_frond(fr, vbase, Vector3(0, ring[0], 0) + dir2 * 0.05, dir2, ring[3], ring[4], ring[5], ring[2] * 0.7,
					segs, tint, 0.85, 1.0, 0.28, 0.75, rng.randf())

	var mode: int = 1 if lod == 0 else 2
	var mesh: ArrayMesh = bark_st.commit()
	mesh.surface_set_material(0, spruce_bark(mode))
	fr.commit(mesh)
	mesh.surface_set_material(1, spruce_fronds(mode))
	return mesh


## One spruce frond: a card strip from `root` along `dir`, rising at `rise` and drooping by `droop`
## toward the tip, `length` long and `width` out to each side, in `segs` quads, folded into a shallow V
## (`fold` radians each side). Normals are the crown's. The vertex colour is the tint shaded from
## `shade0` at the root to `shade1` at the tip, with `snow` in alpha. Returns the next vertex index.
func _spruce_frond(st: SurfaceTool, base: int, root: Vector3, dir: Vector3, rise: float, droop: float, length: float,
		width: float, segs: int, tint: Color, shade0: float, shade1: float, fold: float, snow: float, jitter: float) -> int:
	var cell := Rect2(0.5, 0.5, 0.5, 0.5)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	var p := root
	var pts: Array = [p]
	for k in range(segs):
		var t: float = (float(k) + 0.5) / float(segs)
		var ang: float = rise - (rise + droop) * t * t
		p += (flat * cos(ang) + Vector3.UP * sin(ang)) * (length / float(segs))
		pts.append(p)
	var cf: float = cos(fold)
	var sf: float = sin(fold)
	var under: bool = snow <= 0.0
	var u0: float = cell.position.x + cell.size.x * (0.02 + jitter * 0.04)
	var u1: float = cell.position.x + cell.size.x * (0.98 - (1.0 - jitter) * 0.04)
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		var q: Vector3 = pts[k]
		var w: float = width * (0.45 + 0.55 * sin(PI * clampf(0.15 + t * 0.85, 0.0, 1.0)))
		var fwd: Vector3 = ((pts[mini(k + 1, segs)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		var up: Vector3 = side.cross(fwd).normalized()
		if up.y < 0.0:
			up = -up
		var v: float = cell.position.y + cell.size.y * (1.0 - t)
		var shade: float = lerpf(shade0, shade1, t)
		var out_n: Vector3 = (flat * 0.9 + (Vector3.DOWN * 0.5 if under else Vector3.UP * (0.5 + 0.4 * (1.0 - t)))).normalized()
		for e in [-1.0, 0.0, 1.0]:
			var pos: Vector3 = q + side * (w * cf * e) + up * (w * sf * absf(e))
			st.set_normal(out_n)
			st.set_color(Color(tint.r * shade, tint.g * shade, tint.b * shade, snow * (0.75 + 0.25 * t) if not under else 0.0))
			st.set_uv(Vector2(lerpf(u0, u1, 0.5 + e * 0.5), v))
			st.add_vertex(pos)
	for k in range(segs):
		var a0: int = base + k * 3
		for idx in [a0, a0 + 3, a0 + 1, a0 + 1, a0 + 3, a0 + 4, a0 + 1, a0 + 4, a0 + 2, a0 + 2, a0 + 4, a0 + 5]:
			st.add_index(idx)
	return base + (segs + 1) * 3


# ======================================================================================
#  Winter birch
# ======================================================================================

## WoodlandBuilder's birch with bare twig sprays for leaves. `variant` 0 or 1 (its two shapes).
func birch_mesh(variant: int, lod: int) -> ArrayMesh:
	var mode: int = 1 if lod == 0 else 2
	return _wb().broadleaf_mesh("birch", variant, lod, birch_bark(mode), birch_twigs(mode))


## The twig atlas: WoodlandBuilder's 2 x 2 layout (cell_uv), with the birch's cell (2: u 0..0.5, v 0.5..1)
## drawn as a winter spray: fine twigs rising from the cell's foot, forking, arching over and hanging at
## their ends, dark purple-brown, with a few catkins. The other cells are empty. Coverage-preserving
## mipmaps keep a far crown's haze.
func twig_atlas() -> Texture2D:
	if _twig_atlas:
		return _twig_atlas
	const W := 1024
	const C := 512
	var cv := WoodlandBuilder.LeafCanvas.new(W, Color(0.22, 0.14, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 8821
	var foot := Vector2(C * 0.5, C * 2.0 - 6.0)
	var lo := Vector2(4.0, C + 4.0)
	var hi := Vector2(C - 4.0, C * 2.0 - 4.0)
	for t in range(11):
		var a0: float = lerpf(-PI * 0.86, -PI * 0.14, (float(t) + 0.5) / 11.0) + rng.randf_range(-0.07, 0.07)
		var p := foot + Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-36.0, 0.0))
		_twig(cv, rng, p, Vector2(cos(a0), sin(a0)), rng.randf_range(300.0, 420.0), 2.1, 0, lo, hi)
	var img: Image = WoodlandBuilder._coverage_mipmaps(cv, 0.5)
	_twig_atlas = save_res.call(ImageTexture.create_from_image(img), "twig_atlas")
	return _twig_atlas


## One twig from `p` along `d`, `length` pixels, `r` thick at its root, arching down as it grows and
## forking into thinner twigs (to `depth` 3), a catkin or two hanging off the older ones.
func _twig(cv, rng: RandomNumberGenerator, p: Vector2, d: Vector2, length: float, r: float, depth: int, lo: Vector2,
		hi: Vector2) -> void:
	var gone := 0.0
	var next_fork: float = rng.randf_range(0.18, 0.32) * length
	while gone < length:
		var seg: float = rng.randf_range(9.0, 14.0)
		# Arching over: the twig bends down as it grows (birch twigs hang at their ends).
		d = (d + Vector2(0.0, 0.035 + gone / length * 0.07) + Vector2(rng.randf_range(-0.07, 0.07), 0.0)).normalized()
		var q: Vector2 = p + d * seg
		if q.x < lo.x or q.x > hi.x or q.y < lo.y or q.y > hi.y:
			return
		var k: float = gone / length
		var rr: float = lerpf(r, 0.45, k)
		# Older wood darker and browner, the young shoots redder and glossier.
		var col := Color(0.20, 0.13, 0.11).lerp(Color(0.36, 0.17, 0.14), k * 0.8 + float(depth) * 0.1)
		cv.line(p, q, rr, lerpf(r, 0.45, (gone + seg) / length), col)
		if depth < 3 and gone > next_fork:
			next_fork += rng.randf_range(0.16, 0.30) * length
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			var fd: Vector2 = d.rotated(side * rng.randf_range(0.35, 0.8))
			_twig(cv, rng, q, fd, (length - gone) * rng.randf_range(0.45, 0.75), rr * 0.75, depth + 1, lo, hi)
		if depth <= 1 and rng.randf() < 0.035:
			# A male catkin: a short, dark, scaly pendant.
			var cd := Vector2(rng.randf_range(-0.25, 0.25), 1.0).normalized()
			cv.line(q, q + cd * rng.randf_range(14.0, 22.0), 1.9, 1.3, Color(0.30, 0.20, 0.13))
		p = q
		gone += seg
