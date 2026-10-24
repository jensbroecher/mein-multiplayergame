extends RefCounted
## Temperate trees for the Lakeside Course (regenerate_lakeside.gd), built the way Msitu Falls builds
## its rainforest: bark tubes (tree_bark.gdshader) carrying cards of drawn leaf sprays
## (acacia_leaves.gdshader) whose normals are the crown's, so each crown shades as one mass, bright
## on top and dark underneath. Oak, lime, birch, spruce and hazel, two shapes each.
##
## A broadleaf grows from its crown inward: leaf clusters are scattered through the crown's outer
## shell, grouped by direction into limbs, and joined to the trunk by forks, so every cluster hangs
## on a branch that can be seen. Branch radii follow the pipe model (a branch as thick as the twigs it
## carries), scaled to the trunk. A spruce is a trunk with whorls of drooping needle fronds, shorter
## toward the top. Every tree has a far stand-in (`lod` 1): the same outline in a few big cards.

const CELL_OAK := 0
const CELL_ROUND := 1
const CELL_BIRCH := 2
const CELL_SPRUCE := 3

## Broadleaves, in metres: height, trunk radius at the foot, crown radius, the crown's underside as a
## share of the height, where the trunk forks (share), how far a leader runs up (share, 0 for a
## spreading oak), limbs, leaf clusters and their radius, how far into the crown they sit (shell),
## cards per cluster and their size, the atlas cell, the leaves' tint and how much the twigs droop.
const BROADLEAF := {
	"oak": {"h": 15.5, "r": 0.52, "cr": 7.6, "under": 0.27, "fork": 0.26, "leader": 0.0, "limbs": 5,
		"clusters": 46, "cl_r": 1.9, "shell": 0.5, "cards": 10, "card": Vector2(2.3, 3.1), "cell": CELL_OAK,
		"tint": Color(0.84, 0.88, 0.78), "droop": 0.0, "bark": "oak"},
	"lime": {"h": 19.0, "r": 0.46, "cr": 6.2, "under": 0.24, "fork": 0.2, "leader": 0.78, "limbs": 8,
		"clusters": 48, "cl_r": 1.75, "shell": 0.45, "cards": 9, "card": Vector2(2.2, 3.0), "cell": CELL_ROUND,
		"tint": Color(0.88, 0.92, 0.80), "droop": 0.0, "bark": "lime"},
	"birch": {"h": 16.0, "r": 0.21, "cr": 3.9, "under": 0.3, "fork": 0.28, "leader": 0.9, "limbs": 10,
		"clusters": 34, "cl_r": 1.25, "shell": 0.45, "cards": 7, "card": Vector2(1.7, 2.3), "cell": CELL_BIRCH,
		"tint": Color(0.86, 0.90, 0.76), "droop": 0.22, "bark": "birch"},
	"alder": {"h": 13.5, "r": 0.28, "cr": 4.8, "under": 0.25, "fork": 0.22, "leader": 0.72, "limbs": 7,
		"clusters": 36, "cl_r": 1.45, "shell": 0.45, "cards": 8, "card": Vector2(1.9, 2.5), "cell": CELL_ROUND,
		"tint": Color(0.80, 0.88, 0.72), "droop": 0.08, "bark": "alder"},
}
const SPRUCE := {"h": 22.0, "r": 0.36, "base_r": 4.4, "whorls": 26, "per_whorl": 8}
const PINE := {"h": 22.5, "r": 0.42, "cr": 5.4, "under": 0.48}
const FIR := {"h": 24.5, "r": 0.38, "base_r": 3.2, "whorls": 28, "per_whorl": 7}
const LARCH := {"h": 19.5, "r": 0.34, "base_r": 3.9, "whorls": 20, "per_whorl": 6}

## Bark per kind: [bark colour, fissure colour, fissure width, depth, plate stretch, vertex tint].
const BARKS := {
	"oak": [Color(0.58, 0.54, 0.48), Color(0.20, 0.17, 0.14), 0.42, 0.045, 2.6, Color(0.82, 0.80, 0.76)],
	"lime": [Color(0.62, 0.60, 0.56), Color(0.30, 0.27, 0.24), 0.30, 0.025, 3.4, Color(0.82, 0.82, 0.80)],
	"birch": [Color(0.95, 0.94, 0.90), Color(0.16, 0.15, 0.15), 0.18, 0.012, 0.22, Color(0.88, 0.88, 0.86)],
	"spruce": [Color(0.56, 0.42, 0.33), Color(0.22, 0.16, 0.12), 0.36, 0.02, 1.4, Color(0.80, 0.76, 0.74)],
	"hazel": [Color(0.60, 0.50, 0.40), Color(0.30, 0.24, 0.18), 0.25, 0.01, 4.0, Color(0.82, 0.78, 0.74)],
	"pine": [Color(0.68, 0.40, 0.24), Color(0.24, 0.14, 0.10), 0.38, 0.032, 1.9, Color(0.88, 0.78, 0.70)],
	"fir": [Color(0.46, 0.44, 0.42), Color(0.18, 0.17, 0.16), 0.28, 0.02, 2.2, Color(0.78, 0.78, 0.76)],
	"larch": [Color(0.54, 0.44, 0.35), Color(0.22, 0.15, 0.11), 0.38, 0.035, 2.8, Color(0.82, 0.78, 0.74)],
	"alder": [Color(0.48, 0.46, 0.42), Color(0.22, 0.20, 0.18), 0.26, 0.018, 3.0, Color(0.80, 0.80, 0.78)],
}

## The canopy crossfades from the detailed trees to their stand-ins round TREE_NEAR (JungleDetail.gd
## moves it with the detail level setting).
const TREE_NEAR := 115.0
const TREE_FADE := 40.0
const TREE_FADE_JITTER := 12.0

## (res, name) -> the saved resource; set by the generator.
var save_res: Callable
var _atlas: Texture2D


# ======================================================================================
#  The leaf atlas
# ======================================================================================

## A float RGB + alpha canvas for drawing the atlas (Msitu Falls' LeafCanvas, with lobed, serrated
## and needle leaves added).
class LeafCanvas:
	var w := 0
	var rgb := PackedFloat32Array()
	var alpha := PackedFloat32Array()

	func _init(size: int, bg: Color) -> void:
		w = size
		rgb.resize(size * size * 3)
		alpha.resize(size * size)
		for i in range(size * size):
			rgb[i * 3] = bg.r
			rgb[i * 3 + 1] = bg.g
			rgb[i * 3 + 2] = bg.b

	func _put(i: int, a: float, col: Color) -> void:
		var k: float = a if alpha[i] > 0.0 else 1.0
		rgb[i * 3] = lerpf(rgb[i * 3], col.r, k)
		rgb[i * 3 + 1] = lerpf(rgb[i * 3 + 1], col.g, k)
		rgb[i * 3 + 2] = lerpf(rgb[i * 3 + 2], col.b, k)
		alpha[i] = maxf(alpha[i], a)

	func dot(c: Vector2, r: float, col: Color) -> void:
		var x0: int = maxi(0, int(c.x - r - 1.0))
		var x1: int = mini(w - 1, int(c.x + r + 1.0))
		var y0: int = maxi(0, int(c.y - r - 1.0))
		var y1: int = mini(w - 1, int(c.y + r + 1.0))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var a: float = clampf(r + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(c), 0.0, 1.0)
				if a > 0.0:
					_put(y * w + x, a, col)

	func line(a: Vector2, b: Vector2, r: float, r2: float, col: Color) -> void:
		var n: int = maxi(1, int(a.distance_to(b) / 0.7))
		for k in range(n + 1):
			var t: float = float(k) / float(n)
			dot(a.lerp(b, t), lerpf(r, r2, t), col)

	## A leaf from `base` along `dir`, widest a third of the way up. `lobes` > 0 cuts rounded lobes
	## into its edge (an oak leaf), `teeth` > 0 a fine serration (birch, hazel); `round_tip` blunts it.
	func leaf(base: Vector2, dir: Vector2, length: float, width: float, col: Color, rib: Color,
			lobes := 0.0, teeth := 0.0, round_tip := 0.0) -> void:
		var d: Vector2 = dir.normalized()
		var perp := Vector2(-d.y, d.x)
		var reach: float = maxf(length, width) + 2.0
		var lo := base - Vector2(reach, reach)
		var hi := base + Vector2(reach, reach)
		for y in range(maxi(0, int(lo.y)), mini(w - 1, int(hi.y) + 1)):
			for x in range(maxi(0, int(lo.x)), mini(w - 1, int(hi.x) + 1)):
				var q := Vector2(x + 0.5, y + 0.5) - base
				var along: float = q.dot(d) / length
				if along < 0.0 or along > 1.0:
					continue
				var across: float = q.dot(perp)
				var prof: float = pow(sin(PI * clampf(pow(along, 0.75), 0.0, 1.0)), 0.7)
				if round_tip > 0.0:
					prof = lerpf(prof, sqrt(maxf(1.0 - pow(maxf(along - 0.35, 0.0) / 0.65, 2.0), 0.0)), round_tip)
				var half: float = width * prof
				if lobes > 0.0:
					half *= 0.68 + 0.32 * absf(cos(along * lobes * PI))
				if teeth > 0.0:
					half *= 1.0 - teeth * (0.5 + 0.5 * sin(along * 60.0))
				var a: float = clampf(half - absf(across) + 0.5, 0.0, 1.0)
				if a <= 0.0:
					continue
				var c: Color = col.lerp(col.lightened(0.16), along * 0.5)
				c = c.darkened(0.18 * (absf(across) / maxf(half, 0.001)))
				var r: float = clampf(1.2 - absf(across) / maxf(width * 0.07, 0.6), 0.0, 1.0)
				c = c.lerp(rib, r * 0.5)
				_put(y * w + x, a, c)


## Mipmapped RGBA8 image whose every level keeps level 0's coverage at alpha `cutoff` (Msitu Falls'
## _coverage_mipmaps), so distant crowns don't thin out to nothing.
static func _coverage_mipmaps(cv: LeafCanvas, cutoff: float) -> Image:
	var size: int = cv.w
	var rgb: PackedFloat32Array = cv.rgb
	var alpha: PackedFloat32Array = cv.alpha
	var target := 0.0
	for a in alpha:
		if a >= cutoff:
			target += 1.0
	target /= float(alpha.size())
	var data := PackedByteArray()
	var scale := 1.0
	while true:
		var n: int = size * size
		var level := PackedByteArray()
		level.resize(n * 4)
		for i in range(n):
			level[i * 4] = int(clampf(rgb[i * 3], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 1] = int(clampf(rgb[i * 3 + 1], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 2] = int(clampf(rgb[i * 3 + 2], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 3] = int(clampf(alpha[i] * scale, 0.0, 1.0) * 255.0 + 0.5)
		data.append_array(level)
		if size == 1:
			break
		var half: int = size / 2
		var rgb2 := PackedFloat32Array()
		rgb2.resize(half * half * 3)
		var alpha2 := PackedFloat32Array()
		alpha2.resize(half * half)
		for y in range(half):
			for x in range(half):
				var sa := 0.0
				var sr := 0.0
				var sg := 0.0
				var sb := 0.0
				for dy in range(2):
					for dx in range(2):
						var i2: int = (y * 2 + dy) * size + x * 2 + dx
						var wgt: float = alpha[i2] + 0.001
						sa += alpha[i2]
						sr += rgb[i2 * 3] * wgt
						sg += rgb[i2 * 3 + 1] * wgt
						sb += rgb[i2 * 3 + 2] * wgt
				var j: int = y * half + x
				var wsum: float = sa + 0.004
				alpha2[j] = sa * 0.25
				rgb2[j * 3] = sr / wsum
				rgb2[j * 3 + 1] = sg / wsum
				rgb2[j * 3 + 2] = sb / wsum
		size = half
		rgb = rgb2
		alpha = alpha2
		var lo := 1.0
		var hi := 16.0
		for it in range(14):
			var mid: float = (lo + hi) * 0.5
			var covered := 0
			var need: float = cutoff / mid
			for a2 in alpha:
				if a2 >= need:
					covered += 1
			if float(covered) / float(alpha.size()) < target:
				lo = mid
			else:
				hi = mid
		scale = hi
	return Image.create_from_data(cv.w, cv.w, true, Image.FORMAT_RGBA8, data)


## The atlas, 2 x 2 cells of 512: an oak spray, a spray of round lime leaves (also the hazel's), a
## hanging birch spray and a spruce branchlet, each drawn upright with its base at the cell's foot.
func atlas() -> Texture2D:
	if _atlas:
		return _atlas
	const W := 1024
	const C := 512
	var cv := LeafCanvas.new(W, Color(0.12, 0.20, 0.06))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3141
	# --- 0: oak, twigs radiating from the middle with lobed leaves in tufts.
	_spray(cv, rng, Vector2(C * 0.5, C * 0.5), C, 10, Vector2(150.0, 205.0),
			func(p: Vector2, d: Vector2, s: float, g: Color) -> void:
				cv.leaf(p, d, 46.0 * s, 13.5 * s, g, g.lightened(0.22), 4.5, 0.0, 0.5),
			[Color(0.20, 0.32, 0.08), Color(0.28, 0.40, 0.10), Color(0.32, 0.38, 0.09)])
	# --- 1: lime/hazel, broad heart-shaped leaves on twigs.
	_spray(cv, rng, Vector2(C * 1.5, C * 0.5), C, 10, Vector2(150.0, 200.0),
			func(p: Vector2, d: Vector2, s: float, g: Color) -> void:
				cv.leaf(p, d, 44.0 * s, 19.0 * s, g, g.lightened(0.22), 0.0, 0.08, 0.35),
			[Color(0.28, 0.44, 0.11), Color(0.36, 0.52, 0.14), Color(0.32, 0.48, 0.15)])
	# --- 2: birch, fine twigs arching out from the foot of the cell and drooping at their ends,
	# small toothed leaves along them.
	var bfoot := Vector2(C * 0.5, C * 2.0 - 6.0)
	for t in range(13):
		var a0: float = lerpf(-PI * 0.88, -PI * 0.12, (float(t) + 0.5) / 13.0) + rng.randf_range(-0.08, 0.08)
		var p := bfoot + Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-30.0, 0.0))
		var d := Vector2(cos(a0), sin(a0))
		var length := rng.randf_range(300.0, 420.0)
		var gone := 0.0
		var side := 1.0
		while gone < length:
			var seg := rng.randf_range(11.0, 16.0)
			# Arching over: the twig bends down as it grows.
			d = (d + Vector2(0.0, 0.045 + gone / length * 0.06) + Vector2(rng.randf_range(-0.05, 0.05), 0.0)).normalized()
			var q: Vector2 = p + d * seg
			if q.y > C * 2.0 - 4.0 or q.y < C + 4.0 or q.x < 4.0 or q.x > C - 4.0:
				break
			cv.line(p, q, 1.3 * (1.0 - gone / length) + 0.5, 0.9, Color(0.32, 0.22, 0.16))
			side = -side
			var la: float = d.angle() + side * rng.randf_range(0.5, 1.1)
			var g: Color = Color(0.40, 0.56, 0.14).lerp(Color(0.50, 0.64, 0.18), rng.randf())
			cv.leaf(q, Vector2(cos(la), sin(la)), rng.randf_range(20.0, 28.0), 10.0, g, g.lightened(0.2), 0.0, 0.15, 0.0)
			p = q
			gone += seg
	# --- 3: spruce: a fan of shoots off a main axis, every shoot thick with needles, lighter at the
	# tips where the new growth is.
	var base3 := Vector2(C * 1.5, C * 2.0 - 6.0)
	var tip3 := Vector2(C * 1.5, C + 12.0)
	var steps := 36
	for k in range(steps):
		var t: float = float(k) / float(steps)
		var at: Vector2 = base3.lerp(tip3, t)
		_needles(cv, rng, at, Vector2(0, -1), 30.0 * (1.0 - t * 0.4), t)
		if k % 2 == 1 and t < 0.94:
			for sgn in [-1.0, 1.0]:
				# Shoots of uneven length, the odd one missing: a ragged, lacy edge, not a leaf's.
				if rng.randf() < 0.14:
					continue
				var sd := Vector2(sgn, -0.55).rotated(rng.randf_range(-0.12, 0.12) * sgn).normalized()
				var sl: float = (205.0 * sin(PI * clampf(t * 0.92 + 0.08, 0.0, 1.0)) * (1.0 - t * 0.35) + 24.0) * rng.randf_range(0.62, 1.12)
				var n2 := int(sl / 6.0)
				for j in range(n2):
					var u: float = float(j) / float(n2)
					var sp: Vector2 = at + sd * sl * u + Vector2(0, -sin(u * PI) * 14.0)
					_needles(cv, rng, sp, sd, 24.0 * (1.0 - u * 0.45), u)
	var img := _coverage_mipmaps(cv, 0.5)
	_atlas = save_res.call(ImageTexture.create_from_image(img), "leaf_atlas")
	return _atlas


## A rough disc of twigs in a cell, `draw_leaf` called for every leaf along them (alternate sides,
## a tuft at each twig's end).
func _spray(cv: LeafCanvas, rng: RandomNumberGenerator, centre: Vector2, cell: int, twigs: int, length: Vector2,
		draw_leaf: Callable, greens: Array) -> void:
	for t in range(twigs):
		var a: float = TAU * float(t) / float(twigs) + rng.randf_range(-0.25, 0.25)
		var p: Vector2 = centre + Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 40.0)
		var dir := Vector2(cos(a), sin(a))
		var total: float = rng.randf_range(length.x, length.y)
		var gone := 0.0
		var side := 1.0
		while gone < total:
			var seg: float = rng.randf_range(16.0, 24.0)
			dir = dir.rotated(rng.randf_range(-0.18, 0.18))
			var q: Vector2 = p + dir * seg
			if q.distance_to(centre) > cell * 0.46:
				break
			cv.line(p, q, 1.6, 1.2, Color(0.26, 0.20, 0.13))
			side = -side
			var la: float = dir.angle() + side * rng.randf_range(0.5, 1.1)
			var g: Color = (greens[rng.randi() % greens.size()] as Color).lerp(greens[0], rng.randf() * 0.4)
			draw_leaf.call(q, Vector2(cos(la), sin(la)), rng.randf_range(0.7, 1.0) * (1.0 - gone / total * 0.3), g)
			p = q
			gone += seg
		for k in range(3):
			var la2: float = dir.angle() + rng.randf_range(-0.6, 0.6)
			draw_leaf.call(p, Vector2(cos(la2), sin(la2)), rng.randf_range(0.8, 1.0), greens[1])


## A tuft of needles round a point on a shoot running along `d`; `young` 0..1 toward the shoot's
## tip, where the needles are a fresher green.
func _needles(cv: LeafCanvas, rng: RandomNumberGenerator, at: Vector2, d: Vector2, length: float, young := 0.0) -> void:
	var perp := Vector2(-d.y, d.x)
	for k in range(8):
		var side := 1.0 if k % 2 == 0 else -1.0
		var nd: Vector2 = (d * rng.randf_range(0.3, 0.9) + perp * side * rng.randf_range(0.6, 1.0)).normalized()
		var g: Color = Color(0.14, 0.28, 0.14).lerp(Color(0.22, 0.38, 0.18), rng.randf())
		g = g.lerp(Color(0.34, 0.50, 0.20), smoothstep(0.6, 1.0, young) * 0.6)
		cv.line(at, at + nd * length * rng.randf_range(0.65, 1.0), 2.2, 1.0, g)
	cv.line(at, at + d * 5.0, 2.0, 1.8, Color(0.30, 0.22, 0.15))


static func cell_uv(cell: int) -> Rect2:
	return Rect2(float(cell % 2) * 0.5, float(cell / 2) * 0.5, 0.5, 0.5)


# ======================================================================================
#  Materials
# ======================================================================================

func bark_material(kind: String, lod_mode: int) -> ShaderMaterial:
	var b: Array = BARKS[kind]
	var m := ShaderMaterial.new()
	m.shader = load("res://tree_bark.gdshader")
	m.set_shader_parameter("bark_color", b[0])
	m.set_shader_parameter("fissure_color", b[1])
	m.set_shader_parameter("fissure_width", b[2])
	m.set_shader_parameter("fissure_depth", b[3])
	m.set_shader_parameter("plate_stretch", b[4])
	m.set_shader_parameter("roughness_value", 0.85)
	set_lod(m, lod_mode)
	return m


func leaf_material(lod_mode: int, sway: float, sway_height: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://acacia_leaves.gdshader")
	m.set_shader_parameter("leaf_tex", atlas())
	m.set_shader_parameter("backlight_color", Color(0.62, 0.74, 0.30))
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("sway_height", sway_height)
	set_lod(m, lod_mode)
	return m


## How far a tree reaches out (flat, from its axis) between `y0` and `y1` over its foot: a spruce's
## low skirt, an oak's flared foot. The generators size the trees' colliders from it, so a cart
## stops at the branches instead of driving into them up to the trunk.
static func band_radius(mesh: Mesh, y0: float, y1: float) -> float:
	var r := 0.0
	for si in range(mesh.get_surface_count()):
		var v: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for q in v:
			if q.y >= y0 and q.y <= y1:
				r = maxf(r, Vector2(q.x, q.z).length())
	return r


static func set_lod(m: ShaderMaterial, lod_mode: int) -> void:
	m.set_shader_parameter("lod_mode", lod_mode)
	m.set_shader_parameter("lod_fade_begin", TREE_NEAR - TREE_FADE * 0.5)
	m.set_shader_parameter("lod_fade_end", TREE_NEAR + TREE_FADE * 0.5)
	m.set_shader_parameter("lod_jitter", TREE_FADE_JITTER)


# ======================================================================================
#  Geometry
# ======================================================================================

## Appends a bark tube along `pts` (a radius per point) as `sides` faces round plus a seam column, so
## the UVs wrap (tree_bark.gdshader: UV.x round in bark cells, wrapping after UV2.x; UV.y along).
## Colour `col`, its alpha the shade (dark inside the crown, from `shade` heights). Returns the next
## free vertex index. (Msitu Falls' _bark_tube.)
static func bark_tube(st: SurfaceTool, base: int, pts: Array, radii: Array, sides: int, col: Color, cell: float,
		shade: Vector2) -> int:
	var n: int = pts.size()
	var period: float = maxf(3.0, roundf(TAU * float(radii[0]) / cell))
	var grid: Array = []
	var vs := PackedFloat32Array()
	var along := 0.0
	var t0: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).normalized()
	var u: Vector3 = t0.cross(Vector3.UP if absf(t0.y) < 0.95 else Vector3.RIGHT).normalized()
	for k in range(n):
		var t: Vector3 = ((pts[mini(k + 1, n - 1)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		u = (u - t * u.dot(t)).normalized()
		var w: Vector3 = t.cross(u)
		if k > 0:
			along += (pts[k] as Vector3).distance_to(pts[k - 1])
		vs.append(along / cell)
		var ring := PackedVector3Array()
		for s in range(sides + 1):
			var ang: float = TAU * float(s % sides) / float(sides)
			ring.append((pts[k] as Vector3) + (u * cos(ang) + w * sin(ang)) * float(radii[k]))
		grid.append(ring)
	for k in range(n):
		var c: Vector3 = pts[k]
		var a_sh: float = 1.0 - 0.5 * smoothstep(shade.x, shade.y, c.y)
		for s in range(sides + 1):
			var si: int = s % sides
			var around: Vector3 = (grid[k][(si + 1) % sides] as Vector3) - (grid[k][(si - 1 + sides) % sides] as Vector3)
			var length_dir: Vector3 = (grid[mini(k + 1, n - 1)][si] as Vector3) - (grid[maxi(k - 1, 0)][si] as Vector3)
			var nrm: Vector3 = around.cross(length_dir).normalized()
			var p: Vector3 = grid[k][s]
			if nrm.dot(p - c) < 0.0:
				nrm = -nrm
			st.set_normal(nrm)
			st.set_color(Color(col.r, col.g, col.b, a_sh))
			st.set_uv(Vector2(float(s) / float(sides) * period, vs[k]))
			st.set_uv2(Vector2(period, 0.0))
			st.add_vertex(p)
	# Front faces outward: clockwise, face normal (c - a) x (b - a).
	var p0: Vector3 = grid[0][0]
	var p1: Vector3 = grid[0][1]
	var p2: Vector3 = grid[1][1]
	var flip: bool = (p2 - p0).cross(p1 - p0).dot(p0 - (pts[0] as Vector3)) < 0.0
	for k in range(n - 1):
		for s in range(sides):
			var a: int = base + k * (sides + 1) + s
			var b: int = a + 1
			var c2: int = a + sides + 2
			var d: int = a + sides + 1
			if flip:
				for idx in [a, c2, b, a, d, c2]:
					st.add_index(idx)
			else:
				for idx in [a, b, c2, a, c2, d]:
					st.add_index(idx)
	return base + n * (sides + 1)


## Leaf cards filling a cluster at `c` (radius `r`): `n` cards, `size` metres across, turned mostly to
## face out of the crown (centre `crown_c`, radius `crown_r`, from `under` to `top`). The normals are
## the crown's; the colour's alpha is the shade inside it. `hang` > 0 hangs the cards (birch). (After
## Msitu Falls' _cluster_cards.)
static func cluster_cards(st: SurfaceTool, base: int, c: Vector3, r: float, n: int, size: Vector2, crown_c: Vector3,
		crown_r: float, under: float, top: float, cell: int, tint: Color, rng: RandomNumberGenerator, hang := 0.0) -> int:
	var uvr: Rect2 = cell_uv(cell)
	for k in range(n):
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var p: Vector3 = c + dir * r * sqrt(rng.randf()) * 0.85
		var out: Vector3 = p - crown_c
		out.y *= 0.6
		out = (out.normalized() + Vector3.UP * 0.4 + dir * 0.3).normalized()
		var nrm: Vector3 = out if rng.randf() < 0.6 else Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.0), rng.randf_range(-1, 1)).normalized()
		if hang > 0.0:
			# Hanging sprays: the card stands up, its base at the top.
			var flat := Vector3(nrm.x, 0.0, nrm.z)
			if flat.length_squared() < 1e-4:
				flat = Vector3(1, 0, 0)
			nrm = (flat.normalized() + Vector3.UP * (1.0 - hang) * 0.6).normalized()
		var t1: Vector3 = nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized()
		var t2: Vector3 = nrm.cross(t1)
		if hang > 0.0:
			# t2 down the card: the spray's base (the cell's foot) at the top.
			t2 = (Vector3.UP - nrm * nrm.y).normalized()
			t1 = t2.cross(nrm).normalized()
		else:
			t1 = t1.rotated(nrm, rng.randf() * TAU)
			t2 = nrm.cross(t1)
		var hs: float = rng.randf_range(size.x, size.y) * 0.5
		var hl: float = hs * (1.4 if hang > 0.0 else 1.0)
		# The cell's top edge (v = 0) along +t2: up, for a hanging spray, which is drawn hanging.
		var corners: Array = [p - t1 * hs - t2 * hl, p + t1 * hs - t2 * hl, p + t1 * hs + t2 * hl, p - t1 * hs + t2 * hl]
		var uvs: Array = [uvr.position + Vector2(0, uvr.size.y), uvr.position + uvr.size, uvr.position + Vector2(uvr.size.x, 0), uvr.position]
		var bright: float = rng.randf_range(0.9, 1.08)
		for j in range(4):
			var v: Vector3 = corners[j]
			var cn: Vector3 = v - crown_c
			cn = Vector3(cn.x / maxf(crown_r, 0.1), cn.y / maxf((top - under) * 0.7, 0.1), cn.z / maxf(crown_r, 0.1)).normalized()
			var shade: float = clampf(0.3 + 0.7 * smoothstep(under - 0.5, top - 0.5, v.y), 0.25, 1.0)
			shade *= lerpf(0.75, 1.0, clampf(Vector2(v.x - crown_c.x, v.z - crown_c.z).length() / maxf(crown_r, 0.1), 0.0, 1.0))
			st.set_normal((cn + Vector3.UP * 0.5).normalized())
			st.set_color(Color(tint.r * bright, tint.g * bright, tint.b * bright, shade))
			st.set_uv(uvs[j])
			st.add_vertex(v)
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_index(base + idx)
		base += 4
	return base


## A curved card strip (a spruce frond): from `root` along `dir` rising at `rise` and drooping by
## `droop` toward the tip, `length` by `width`, `segs` quads, folded into a shallow V (`fold` radians
## each side) so it stays a branch seen edge-on. Normals lean out of the crown along `out`. (After
## Msitu Falls' _frond.)
static func frond(st: SurfaceTool, base: int, root: Vector3, dir: Vector3, rise: float, droop: float, length: float,
		width: float, segs: int, cell: int, tint: Color, shade0: float, shade1: float, fold: float, out_axis: Vector3) -> int:
	var uvr: Rect2 = cell_uv(cell)
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
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		var q: Vector3 = pts[k]
		var w: float = width * (0.35 + 0.65 * sin(PI * clampf(0.12 + t * 0.88, 0.0, 1.0)))
		var fwd: Vector3 = ((pts[mini(k + 1, segs)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		var up: Vector3 = side.cross(fwd).normalized()
		if up.y < 0.0:
			up = -up
		var v: float = uvr.position.y + uvr.size.y * (1.0 - t)
		var shade: float = lerpf(shade0, shade1, t)
		var o: Vector3 = (out_axis + flat * 0.6 + Vector3.UP * 0.35).normalized()
		for e in [-1.0, 0.0, 1.0]:
			var pos: Vector3 = q + side * (w * cf * e) + up * (w * sf * absf(e))
			var nrm: Vector3 = (o + up * 0.4).normalized()
			st.set_normal(nrm)
			st.set_color(Color(tint.r, tint.g, tint.b, shade))
			st.set_uv(Vector2(uvr.position.x + uvr.size.x * (0.5 + e * 0.5), v))
			st.add_vertex(pos)
	for k in range(segs):
		var a0: int = base + k * 3
		for idx in [a0, a0 + 3, a0 + 1, a0 + 1, a0 + 3, a0 + 4, a0 + 1, a0 + 4, a0 + 2, a0 + 2, a0 + 4, a0 + 5]:
			st.add_index(idx)
	return base + (segs + 1) * 3


# ======================================================================================
#  Broadleaves
# ======================================================================================

## A broadleaf of `kind` (BROADLEAF), shape `variant`, as a two-surface mesh (bark, leaves). `lod` 1
## is the far stand-in: the trunk and limbs only, and a few big cards per group of clusters.
func broadleaf_mesh(kind: String, variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var sp: Dictionary = BROADLEAF[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + 7919 * variant + 13
	var h: float = float(sp["h"]) * rng.randf_range(0.9, 1.1)
	var cr: float = float(sp["cr"]) * rng.randf_range(0.88, 1.12)
	var r0: float = sp["r"]
	var under: float = h * float(sp["under"])
	var lean := Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(-0.6, 0.6))
	var crown_c := Vector3(lean.x, (under + h) * 0.5, lean.z)
	var crown_hr: float = (h - under) * 0.5
	# 1. Leaf clusters through the crown's outer shell, few underneath.
	var n_cl: int = sp["clusters"]
	var cl_r: float = sp["cl_r"]
	var clusters: Array = []
	var tries := 0
	var gap: float = cl_r * 1.05
	while clusters.size() < n_cl and tries < 6000:
		tries += 1
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if d.y < -0.35 and rng.randf() < 0.75:
			continue
		var shell: float = rng.randf_range(float(sp["shell"]), 0.95)
		var p: Vector3 = crown_c + Vector3(d.x * cr, d.y * crown_hr, d.z * cr) * shell
		if p.y < under:
			continue
		var ok := true
		for c in clusters:
			if (c[0] as Vector3).distance_to(p) < gap:
				ok = false
				break
		if ok:
			clusters.append([p, cl_r * rng.randf_range(0.85, 1.15)])
	# 2. The trunk: up to the fork, then (excurrent kinds) a leader on up through the crown.
	var fork_y: float = h * float(sp["fork"])
	var leader_y: float = h * float(sp["leader"])
	var top_y: float = maxf(fork_y, leader_y)
	var trunk: Array = []
	var segs: int = 9 if lod == 0 else 4
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		var y: float = lerpf(-0.8, top_y, t)
		var lt: float = clampf(y / maxf(top_y, 0.1), 0.0, 1.0)
		trunk.append(Vector3(0.0, y, 0.0) + lean * lt * lt + Vector3(sin(lt * 4.0 + variant) * 0.12, 0.0, cos(lt * 3.3 + variant) * 0.12) * minf(lt * 3.0, 1.0))
	# 3. Limbs: the clusters grouped by direction round the trunk.
	var n_limbs: int = mini(int(sp["limbs"]), clusters.size())
	clusters.sort_custom(func(a: Array, b: Array) -> bool:
		return atan2((a[0] as Vector3).z - lean.z, (a[0] as Vector3).x - lean.x) < atan2((b[0] as Vector3).z - lean.z, (b[0] as Vector3).x - lean.x))
	var groups: Array = []
	for g in range(n_limbs):
		groups.append([])
	var off := rng.randi() % maxi(clusters.size(), 1)
	for i in range(clusters.size()):
		groups[(i * n_limbs) / clusters.size()].append(clusters[(i + off) % clusters.size()])
	# Edges as [points, start radius share, end radius share, kind]; radii by the pipe model.
	var total := float(clusters.size())
	var pw := 1.0 / 2.3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark: Color = BARKS[String(sp["bark"])][5]
	var shade := Vector2(under - 1.0, under + 3.0)
	var base_i := 0
	# Trunk with a root flare.
	var tr_radii: Array = []
	for k in range(trunk.size()):
		var y2: float = (trunk[k] as Vector3).y
		var taper: float = lerpf(1.0, 0.55 if leader_y > 0.0 else 0.82, clampf(y2 / maxf(top_y, 0.1), 0.0, 1.0))
		var flare: float = 1.0 + 0.45 * (1.0 - smoothstep(-0.8, 1.2, y2))
		tr_radii.append(r0 * taper * flare)
	base_i = bark_tube(st, base_i, trunk, tr_radii, 10 if lod == 0 else 6, bark, 0.42, shade)
	if lod == 0:
		# Root buttresses: short swellings running into the ground.
		for k in range(5):
			var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var rp: Array = [dir * r0 * 0.4 + Vector3(0, 0.9, 0), dir * r0 * 1.2 + Vector3(0, 0.15, 0), dir * r0 * 2.1 + Vector3(0, -0.35, 0)]
			base_i = bark_tube(st, base_i, rp, [r0 * 0.3, r0 * 0.24, r0 * 0.1], 5, bark, 0.42, shade)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lb := 0
	var tint: Color = sp["tint"]
	var cell: int = sp["cell"]
	var cards: int = sp["cards"]
	var card: Vector2 = sp["card"]
	var droop: float = sp["droop"]
	for g in groups:
		var grp: Array = g
		if grp.is_empty():
			continue
		var centroid := Vector3.ZERO
		for c in grp:
			centroid += c[0]
		centroid /= float(grp.size())
		# Where the limb leaves the trunk: at the fork, or up the leader by the group's height.
		var attach_y: float = fork_y
		if leader_y > 0.0:
			attach_y = clampf(centroid.y - crown_hr * 0.75, fork_y, leader_y - 1.0)
		var a_pt: Vector3 = _trunk_at(trunk, attach_y)
		var share: float = pow(float(grp.size()) / total, pw)
		var limb_r: float = r0 * share * (0.9 if leader_y > 0.0 else 1.0)
		# The limb's own fork: most of the way out, lifted (oak) or level (birch, which droops later).
		var fork_pt: Vector3 = a_pt.lerp(centroid, 0.62) + Vector3(0, (0.9 if droop < 0.3 else 0.2), 0)
		var mid: Vector3 = a_pt.lerp(fork_pt, 0.5) + Vector3(rng.randf_range(-0.4, 0.4), 0.35, rng.randf_range(-0.4, 0.4))
		base_i = bark_tube(st, base_i, [a_pt, mid, fork_pt], [limb_r, limb_r * 0.85, limb_r * 0.7], 7 if lod == 0 else 4, bark, 0.42, shade)
		# Branches from the limb's fork to each cluster (near only), then the cards.
		for c in grp:
			var cp: Vector3 = c[0]
			var br: float = r0 * pow(1.0 / total, pw) * 0.85
			if lod == 0:
				var bm: Vector3 = fork_pt.lerp(cp, 0.5) + Vector3(rng.randf_range(-0.3, 0.3), 0.3 - droop * 0.9, rng.randf_range(-0.3, 0.3))
				var tip: Vector3 = cp - Vector3(0, droop * float(c[1]) * 0.4, 0)
				base_i = bark_tube(st, base_i, [fork_pt, bm, tip], [br, br * 0.7, br * 0.35], 5, bark, 0.42, shade)
				lb = cluster_cards(leaf_st, lb, cp, float(c[1]), cards, card, crown_c, cr, under, h, cell,
						Color(tint.r * rng.randf_range(0.95, 1.05), tint.g * rng.randf_range(0.95, 1.04), tint.b * rng.randf_range(0.92, 1.05)), rng, droop)
		if lod == 1:
			# The stand-in: a few big cards per limb, where its clusters are.
			var spread := 0.0
			for c in grp:
				spread = maxf(spread, (c[0] as Vector3).distance_to(centroid))
			var big: float = spread + cl_r
			var nb: int = clampi(grp.size() + 1, 3, 7)
			lb = cluster_cards(leaf_st, lb, centroid, spread * 0.7 + cl_r * 0.4, nb, Vector2(big * 1.15, big * 1.45),
					crown_c, cr, under, h, cell, tint, rng, droop * 0.5)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## The point on the trunk polyline at height `y`.
static func _trunk_at(trunk: Array, y: float) -> Vector3:
	for k in range(trunk.size() - 1):
		var a: Vector3 = trunk[k]
		var b: Vector3 = trunk[k + 1]
		if y >= a.y and y <= b.y:
			return a.lerp(b, (y - a.y) / maxf(b.y - a.y, 1e-4))
	return trunk[trunk.size() - 1]


# ======================================================================================
#  Spruce, hazel
# ======================================================================================

## A Norway spruce: a straight trunk under whorls of drooping needle fronds, shorter toward a spire.
## `lod` 1 keeps the outline in a third of the whorls and fewer, wider fronds.
func spruce_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7070 + variant * 101
	var h: float = float(SPRUCE["h"]) * rng.randf_range(0.85, 1.12)
	var r0: float = SPRUCE["r"]
	var base_r: float = float(SPRUCE["base_r"]) * rng.randf_range(0.88, 1.1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark: Color = BARKS["spruce"][5]
	var trunk: Array = []
	var radii: Array = []
	for k in range(7):
		var t: float = float(k) / 6.0
		trunk.append(Vector3(sin(t * 3.0 + variant) * 0.06, lerpf(-0.8, h - 0.3, t), cos(t * 2.6) * 0.06))
		radii.append(r0 * lerpf(1.0, 0.08, t) * (1.0 + 0.35 * (1.0 - smoothstep(0.0, 0.12, t))))
	bark_tube(st, 0, trunk, radii, 8 if lod == 0 else 5, bark, 0.35, Vector2(h * 0.3, h * 0.7))
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lb := 0
	var whorls: int = SPRUCE["whorls"]
	if lod == 1:
		whorls = 14
	var per: int = SPRUCE["per_whorl"]
	var y0: float = 1.6
	var tint := Color(0.92, 0.96, 0.92)
	for w in range(whorls):
		var t: float = float(w) / float(whorls - 1)
		# Whorls close up toward the leader, so the tip is a dense cone and not a bare stem with a few
		# fronds spaced a metre apart.
		var y: float = lerpf(y0, h - 1.0, 1.0 - pow(1.0 - t, 1.35)) + rng.randf_range(-0.2, 0.2) * (1.0 - t)
		var reach: float = base_r * (1.0 - t * 0.94) + 0.6
		var n: int = per if lod == 0 else 7
		var rot: float = rng.randf() * TAU
		for b in range(n):
			var a: float = rot + TAU * float(b) / float(n) + rng.randf_range(-0.25, 0.25)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var length: float = reach * rng.randf_range(0.86, 1.1)
			var width: float = length * (0.6 if lod == 0 else 0.75)
			var sh0: float = lerpf(0.45, 0.8, t)
			var by: float = y + rng.randf_range(-0.2, 0.2)
			lb = frond(leaf_st, lb, Vector3(0, by, 0) + dir * 0.1, dir, rng.randf_range(0.15, 0.4) + t * t * 0.5, rng.randf_range(0.7, 1.05) * (1.0 - t * 0.55),
					length, width, 4 if lod == 0 else 2, CELL_SPRUCE, tint, sh0, minf(sh0 + 0.35, 1.0), 0.32, dir)
			if t < 0.88:
				# A shorter frond hanging under each branch, between them, so the tree is solid from
				# the side and from below.
				var d2: Vector3 = dir.rotated(Vector3.UP, PI / float(n))
				lb = frond(leaf_st, lb, Vector3(0, y - 0.5, 0) + d2 * 0.1, d2, -0.1, 0.75,
						length * 0.72, width * 0.85, 3 if lod == 0 else 2, CELL_SPRUCE, tint.darkened(0.1), sh0 * 0.8, sh0 + 0.15, 0.3, d2)
	# The spire: rings of fronds standing up round the leader, shorter and steeper toward the tip, so
	# the crown ends in a narrow cone.
	var spire := [[h - 2.6, 5, 1.5, 0.95, -0.1, 2.2], [h - 1.8, 5, 1.1, 1.15, -0.2, 1.7], [h - 1.0, 4, 0.8, 1.3, -0.15, 1.2], [h - 0.45, 3, 0.45, 1.4, -0.1, 0.8]]
	for ring in spire:
		var rot2: float = rng.randf() * TAU
		for k in range(int(ring[1])):
			var a2: float = rot2 + TAU * k / float(ring[1])
			var dir2 := Vector3(cos(a2), 0.0, sin(a2))
			lb = frond(leaf_st, lb, Vector3(0, ring[0], 0) + dir2 * 0.05, dir2, ring[3], ring[4], ring[5], ring[2], 3 if lod == 0 else 2, CELL_SPRUCE, tint, 0.8, 1.0, 0.3, dir2)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## A hazel bush: a fan of thin stems with leaf clusters along their upper halves.
func shrub_mesh(variant: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4545 + variant * 31
	var r: float = 2.0 + variant * 0.6
	var hgt: float = 3.2 + variant * 0.8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var lb := 0
	var bark: Color = BARKS["hazel"][5]
	var crown_c := Vector3(0, hgt * 0.55, 0)
	for k in range(7):
		var a := TAU * k / 7.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var tip: Vector3 = dir * r * rng.randf_range(0.5, 0.85) + Vector3(0, hgt * rng.randf_range(0.75, 1.0), 0)
		var mid: Vector3 = dir * r * 0.2 + Vector3(0, hgt * 0.45, 0)
		bi = bark_tube(st, bi, [dir * 0.1 + Vector3(0, -0.3, 0), mid, tip], [0.06, 0.045, 0.02], 4, bark, 0.3, Vector2(0.0, hgt))
		for j in range(2):
			var cpos: Vector3 = mid.lerp(tip, 0.55 + 0.45 * j) + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			lb = cluster_cards(leaf_st, lb, cpos, r * 0.38, 5, Vector2(r * 0.7, r * 0.95), crown_c, r, 0.0, hgt * 1.1,
					CELL_ROUND, Color(0.82, 0.88, 0.74), rng)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


# ======================================================================================
#  Alpine conifers & mountain shrubs (Pinecrest Ridge)
# ======================================================================================

## A Scots / mountain pine (Pinus sylvestris): a tall, gently sinuous trunk bare in its lower half,
## dark grey-brown at the foot and warm orange-red higher up, with crooked spreading limbs carrying
## flat-topped tiered pads of pine needles and a domed umbrella crown.
func pine_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8181 + variant * 137
	var h: float = float(PINE["h"]) * rng.randf_range(0.88, 1.12)
	var r0: float = float(PINE["r"]) * rng.randf_range(0.92, 1.08)
	var cr: float = float(PINE["cr"]) * rng.randf_range(0.90, 1.12)
	var under: float = h * float(PINE["under"])
	var crown_c := Vector3(0.0, lerpf(under, h, 0.62), 0.0)
	var shade := Vector2(under - 1.5, h * 0.88)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_i := 0
	var lower_bark := Color(0.62, 0.54, 0.48)
	var upper_bark := Color(0.96, 0.76, 0.62)

	# Sinuous trunk split into lower dark-fissured section and upper reddish-ochre section.
	var sway_x: float = rng.randf_range(-0.65, 0.65)
	var sway_z: float = rng.randf_range(-0.65, 0.65)
	var trunk: Array = []
	var radii: Array = []
	for k in range(9):
		var t: float = float(k) / 8.0
		var y: float = lerpf(-0.9, h - 0.8, t)
		var bend: float = sin(t * PI * 1.35 + float(variant) * 1.2) * (0.15 + 0.85 * t)
		trunk.append(Vector3(sway_x * bend, y, sway_z * bend))
		var flare: float = 1.0 + 0.42 * (1.0 - smoothstep(0.0, 0.14, t))
		radii.append(r0 * lerpf(1.0, 0.16, pow(t, 0.88)) * flare)
	# Lower trunk (indices 0..4)
	base_i = bark_tube(st, base_i, trunk.slice(0, 5), radii.slice(0, 5), 8 if lod == 0 else 5, lower_bark, 0.38, shade)
	# Upper reddish trunk (indices 4..8, overlapping joint 4)
	base_i = bark_tube(st, base_i, trunk.slice(4, 9), radii.slice(4, 9), 8 if lod == 0 else 5, upper_bark, 0.36, shade)

	# A couple of weathered dead snag stubs just below the live crown (near LOD only).
	if lod == 0:
		for s in range(3):
			var sy: float = h * (0.34 + 0.05 * float(s)) + rng.randf_range(-0.3, 0.3)
			var sa: float = rng.randf() * TAU
			var sdir := Vector3(cos(sa), rng.randf_range(-0.18, 0.05), sin(sa)).normalized()
			var sp0: Vector3 = _trunk_at(trunk, sy)
			var sp1: Vector3 = sp0 + sdir * rng.randf_range(0.9, 1.6)
			base_i = bark_tube(st, base_i, [sp0, sp1], [0.09, 0.03], 4, lower_bark.darkened(0.15), 0.3, shade)

	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lb := 0
	var tint := Color(0.80, 0.90, 0.74)

	# Tiered spreading limbs in the upper half + crown umbrella pads at the summit.
	var n_limbs := 8 if lod == 0 else 6
	for l in range(n_limbs):
		var lt: float = float(l) / float(n_limbs - 1)
		var attach_y: float = lerpf(under, h - 1.4, pow(lt, 0.85))
		var a_pt: Vector3 = _trunk_at(trunk, attach_y)
		var ang: float = float(l) * 2.39996 + float(variant) * 1.7 + rng.randf_range(-0.22, 0.22)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var reach: float = cr * lerpf(0.92, 0.48, lt * lt) * rng.randf_range(0.86, 1.12)
		var lift: float = lerpf(0.3, 1.35, lt) + rng.randf_range(-0.2, 0.25)
		var elbow: Vector3 = a_pt + dir * (reach * 0.52) + Vector3(0.0, lift * 0.35 - 0.25, 0.0)
		var tip: Vector3 = a_pt + dir * reach + Vector3(0.0, lift, 0.0)
		var lr: float = r0 * lerpf(0.44, 0.22, lt)
		base_i = bark_tube(st, base_i, [a_pt, elbow, tip], [lr, lr * 0.72, lr * 0.34], 6 if lod == 0 else 4, upper_bark, 0.34, shade)

		# Needle pads at the limb tip and a secondary side pad off the elbow.
		var pad_pts: Array = [tip, elbow.lerp(tip, 0.62) + dir.rotated(Vector3.UP, 0.55 if l % 2 == 0 else -0.55) * (reach * 0.32) + Vector3(0.0, 0.35, 0.0)]
		for pi in range(pad_pts.size()):
			var pc: Vector3 = pad_pts[pi]
			var pad_scale: float = (1.0 if pi == 0 else 0.76) * lerpf(1.05, 0.78, lt)
			if lod == 0 and pi > 0:
				base_i = bark_tube(st, base_i, [elbow, pc], [lr * 0.55, lr * 0.24], 4, upper_bark, 0.32, shade)
			var fan_n: int = (6 if pi == 0 else 4) if lod == 0 else (3 if pi == 0 else 2)
			var rot0: float = ang + rng.randf_range(-0.3, 0.3)
			for f in range(fan_n):
				var fa: float = rot0 + lerpf(-1.15, 1.15, float(f) / float(maxi(fan_n - 1, 1)))
				var fd := Vector3(cos(fa), 0.0, sin(fa))
				var flen: float = (2.15 if lod == 0 else 2.6) * pad_scale * rng.randf_range(0.88, 1.12)
				var fwid: float = flen * (0.72 if lod == 0 else 0.88)
				var sh0: float = clampf(0.42 + 0.45 * lt, 0.38, 0.88)
				lb = frond(leaf_st, lb, pc - fd * 0.35, fd, 0.22, 0.28, flen, fwid, 3 if lod == 0 else 2,
						CELL_SPRUCE, tint, sh0, minf(sh0 + 0.28, 1.0), 0.26, fd)
			# Crown cards on top of each pad so the foliage reads dense from every angle.
			var n_cards: int = (6 if pi == 0 else 4) if lod == 0 else (3 if pi == 0 else 2)
			var c_size := Vector2(1.85, 2.45) * pad_scale * (1.0 if lod == 0 else 1.32)
			lb = cluster_cards(leaf_st, lb, pc + Vector3(0.0, 0.35, 0.0), 1.25 * pad_scale, n_cards, c_size,
					crown_c, cr, under, h, CELL_SPRUCE, tint, rng, 0.0)

	# Domed top umbrella cap at the leader apex.
	var top_pt: Vector3 = trunk[trunk.size() - 1] + Vector3(0.0, 0.4, 0.0)
	var top_fans: int = 7 if lod == 0 else 4
	for f in range(top_fans):
		var fa2: float = TAU * float(f) / float(top_fans) + rng.randf_range(-0.2, 0.2)
		var fd2 := Vector3(cos(fa2), 0.0, sin(fa2))
		lb = frond(leaf_st, lb, top_pt, fd2, 0.35, 0.30, 2.2, 1.65, 3 if lod == 0 else 2,
				CELL_SPRUCE, tint.lightened(0.06), 0.78, 1.0, 0.24, fd2)
	lb = cluster_cards(leaf_st, lb, top_pt + Vector3(0.0, 0.45, 0.0), 1.6, 7 if lod == 0 else 4,
			Vector2(2.1, 2.7) * (1.0 if lod == 0 else 1.3), crown_c, cr, under, h + 1.0,
			CELL_SPRUCE, tint.lightened(0.05), rng, 0.0)

	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## A subalpine silver fir (Abies lasiocarpa): a tall, narrow spire with horizontal layered platters
## of cool blue-green needles (distinct from Lakeside's wide, drooping Norway spruce).
func fir_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9191 + variant * 113
	var h: float = float(FIR["h"]) * rng.randf_range(0.88, 1.12)
	var r0: float = float(FIR["r"])
	var base_r: float = float(FIR["base_r"]) * rng.randf_range(0.88, 1.08)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark: Color = BARKS["fir"][5]
	var trunk: Array = []
	var radii: Array = []
	for k in range(7):
		var t: float = float(k) / 6.0
		trunk.append(Vector3(sin(t * 2.5 + variant) * 0.04, lerpf(-0.8, h - 0.25, t), cos(t * 2.2) * 0.04))
		radii.append(r0 * lerpf(1.0, 0.07, t) * (1.0 + 0.30 * (1.0 - smoothstep(0.0, 0.12, t))))
	bark_tube(st, 0, trunk, radii, 8 if lod == 0 else 5, bark, 0.35, Vector2(h * 0.28, h * 0.72))

	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lb := 0
	var whorls: int = int(FIR["whorls"]) if lod == 0 else 15
	var per: int = int(FIR["per_whorl"])
	var y0: float = 2.0
	var tint := Color(0.74, 0.90, 0.86)
	for w in range(whorls):
		var t: float = float(w) / float(whorls - 1)
		var y: float = lerpf(y0, h - 0.9, 1.0 - pow(1.0 - t, 1.25)) + rng.randf_range(-0.14, 0.14) * (1.0 - t)
		# Narrow, columnar-conical taper with crisp horizontal tier spacing.
		var reach: float = base_r * pow(1.0 - t * 0.92, 0.85) + 0.45
		var n: int = per if lod == 0 else 6
		var rot: float = float(w) * 1.15 + rng.randf_range(-0.2, 0.2)
		for b in range(n):
			var a: float = rot + TAU * float(b) / float(n) + rng.randf_range(-0.18, 0.18)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var length: float = reach * rng.randf_range(0.88, 1.08)
			var width: float = length * (0.66 if lod == 0 else 0.82)
			var sh0: float = lerpf(0.42, 0.82, t)
			var by: float = y + rng.randf_range(-0.1, 0.1)
			# Fir branches sweep slightly upward at their tips rather than weeping downward.
			var rise: float = lerpf(0.08, 0.48, t) + rng.randf_range(-0.05, 0.08)
			var droop: float = lerpf(0.18, -0.08, t)
			lb = frond(leaf_st, lb, Vector3(0, by, 0) + dir * 0.08, dir, rise, droop,
					length, width, 4 if lod == 0 else 2, CELL_SPRUCE, tint, sh0, minf(sh0 + 0.32, 1.0), 0.28, dir)
			if t < 0.82 and (lod == 0 or b % 2 == 0):
				var d2: Vector3 = dir.rotated(Vector3.UP, PI / float(n))
				lb = frond(leaf_st, lb, Vector3(0, y - 0.35, 0) + d2 * 0.08, d2, 0.04, 0.22,
						length * 0.68, width * 0.82, 3 if lod == 0 else 2, CELL_SPRUCE, tint.darkened(0.10), sh0 * 0.82, sh0 + 0.16, 0.26, d2)
	var spire := [[h - 2.3, 5, 1.25, 1.0, -0.15, 1.9], [h - 1.5, 5, 0.92, 1.18, -0.2, 1.45], [h - 0.85, 4, 0.65, 1.32, -0.18, 1.05], [h - 0.35, 3, 0.38, 1.42, -0.12, 0.7]]
	for ring in spire:
		var rot2: float = rng.randf() * TAU
		for k in range(int(ring[1])):
			var a2: float = rot2 + TAU * float(k) / float(ring[1])
			var dir2 := Vector3(cos(a2), 0.0, sin(a2))
			lb = frond(leaf_st, lb, Vector3(0, ring[0], 0) + dir2 * 0.04, dir2, ring[3], ring[4], ring[5], ring[2], 3 if lod == 0 else 2, CELL_SPRUCE, tint.lightened(0.05), 0.82, 1.0, 0.26, dir2)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## An alpine larch (Larix decidua): an open, airy mountain conifer with sunlit golden-green / warm
## olive needle sprays and visible woody branches.
func larch_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6262 + variant * 127
	var h: float = float(LARCH["h"]) * rng.randf_range(0.88, 1.12)
	var r0: float = float(LARCH["r"])
	var base_r: float = float(LARCH["base_r"]) * rng.randf_range(0.90, 1.10)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base_i := 0
	var bark: Color = BARKS["larch"][5]
	var trunk: Array = []
	var radii: Array = []
	for k in range(8):
		var t: float = float(k) / 7.0
		trunk.append(Vector3(sin(t * 3.8 + variant) * 0.22 * t, lerpf(-0.8, h - 0.4, t), cos(t * 3.1 + variant) * 0.22 * t))
		radii.append(r0 * lerpf(1.0, 0.09, t) * (1.0 + 0.36 * (1.0 - smoothstep(0.0, 0.14, t))))
	base_i = bark_tube(st, base_i, trunk, radii, 8 if lod == 0 else 5, bark, 0.36, Vector2(h * 0.32, h * 0.78))

	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lb := 0
	var whorls: int = int(LARCH["whorls"]) if lod == 0 else 11
	var per: int = int(LARCH["per_whorl"])
	var y0: float = 3.0
	var tint := Color(1.06, 1.03, 0.70)
	for w in range(whorls):
		var t: float = float(w) / float(whorls - 1)
		var y: float = lerpf(y0, h - 1.1, 1.0 - pow(1.0 - t, 1.28)) + rng.randf_range(-0.25, 0.25) * (1.0 - t)
		var reach: float = base_r * (1.0 - t * 0.88) + 0.55
		var n: int = per if lod == 0 else 5
		var rot: float = rng.randf() * TAU
		var a_pt: Vector3 = _trunk_at(trunk, y)
		for b in range(n):
			var a: float = rot + TAU * float(b) / float(n) + rng.randf_range(-0.32, 0.32)
			var dir := Vector3(cos(a), 0.0, sin(a))
			var length: float = reach * rng.randf_range(0.82, 1.14)
			var width: float = length * (0.64 if lod == 0 else 0.80)
			var sh0: float = lerpf(0.48, 0.86, t)
			if lod == 0 and w % 2 == 0 and b % 2 == 0 and t < 0.78:
				var tip_b: Vector3 = a_pt + dir * (length * 0.65) + Vector3(0.0, -0.25 + 0.4 * t, 0.0)
				base_i = bark_tube(st, base_i, [a_pt, tip_b], [0.07 * (1.0 - 0.6 * t), 0.025], 4, bark, 0.32, Vector2(y0, h))
			var w_tint := Color(tint.r * rng.randf_range(0.95, 1.05), tint.g * rng.randf_range(0.95, 1.04), tint.b * rng.randf_range(0.90, 1.06))
			lb = frond(leaf_st, lb, a_pt + dir * 0.08, dir, rng.randf_range(0.05, 0.35) + t * 0.35, rng.randf_range(0.45, 0.80) * (1.0 - t * 0.45),
					length, width, 4 if lod == 0 else 2, CELL_SPRUCE, w_tint, sh0, minf(sh0 + 0.32, 1.0), 0.30, dir)
	var spire := [[h - 2.1, 4, 1.2, 0.95, -0.1, 1.8], [h - 1.2, 4, 0.85, 1.18, -0.15, 1.3], [h - 0.5, 3, 0.5, 1.35, -0.1, 0.85]]
	for ring in spire:
		var rot2: float = rng.randf() * TAU
		for k in range(int(ring[1])):
			var a2: float = rot2 + TAU * float(k) / float(ring[1])
			var dir2 := Vector3(cos(a2), 0.0, sin(a2))
			lb = frond(leaf_st, lb, _trunk_at(trunk, float(ring[0])) + dir2 * 0.04, dir2, ring[3], ring[4], ring[5], ring[2], 3 if lod == 0 else 2, CELL_SPRUCE, tint.lightened(0.06), 0.84, 1.0, 0.28, dir2)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


## A dwarf mountain pine / alpine juniper shrub (Pinus mugo): low, sprawling woody stems carrying
## dense cushions of dark-green conifer needles.
func alpine_shrub_mesh(variant: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5353 + variant * 47
	var r: float = 2.1 + float(variant) * 0.45
	var hgt: float = 2.1 + float(variant) * 0.45
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var lb := 0
	var bark: Color = BARKS["pine"][5]
	var crown_c := Vector3(0.0, hgt * 0.48, 0.0)
	var tint := Color(0.76, 0.88, 0.72)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0 + rng.randf_range(-0.28, 0.28)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var reach: float = r * rng.randf_range(0.60, 0.95)
		var top_y: float = hgt * rng.randf_range(0.65, 1.0)
		var mid: Vector3 = dir * (reach * 0.55) + Vector3(0.0, top_y * 0.35, 0.0)
		var tip: Vector3 = dir * reach + Vector3(0.0, top_y, 0.0)
		bi = bark_tube(st, bi, [dir * 0.08 + Vector3(0.0, -0.35, 0.0), mid, tip], [0.065, 0.048, 0.022], 4, bark, 0.3, Vector2(0.0, hgt))
		for j in range(2):
			var cpos: Vector3 = mid.lerp(tip, 0.50 + 0.50 * float(j)) + Vector3(rng.randf_range(-0.22, 0.22), 0.1, rng.randf_range(-0.22, 0.22))
			lb = cluster_cards(leaf_st, lb, cpos, r * 0.36, 5, Vector2(r * 0.68, r * 0.88), crown_c, r, 0.0, hgt * 1.1,
					CELL_SPRUCE, tint, rng)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh
