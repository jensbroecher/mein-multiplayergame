extends "res://WoodlandBuilder.gd"
## The trees of the Miyoshino GP (Japan: the cherry mountains of Yoshino in spring), on WoodlandBuilder's technique:
## bark tubes (tree_bark.gdshader) carrying cards of drawn sprays (acacia_leaves.gdshader) whose normals are the crown's.
##
##   sakura      Somei-yoshino in full bloom: forking low into spreading limbs that arch out and down at their tips,
##               near-black banded bark showing through airy sleeves of pale blossom along every branch
##   yamazakura  the wild mountain cherry: taller, upright on a leader, thinner and pinker, with bronze young leaves
##   shidare     weeping cherry: limbs rising and falling over, long curtains of deeper pink nearly to the ground
##   sugi        Japanese cedar: a straight red-brown stem, a narrow dark cone of upswept sprays (variant even: the
##               forest form, bare below with dead stubs; odd: the edge form, branched low and fuller)
##   momiji      Japanese maple in spring: a low, wide crown in flat tiers of yellow-green (variant odd: twin stems)
##   momiji_red  the same, red-leaved (a deshojo, scarlet in spring): its leaf cards tinted red
##   take        a clump of moso bamboo: green culms with node rings, arching over, feathery sprays in the top third
##   matsu       a garden pine: a twisted leaning trunk, needles in flat cloud pads
##   tsutsuji    an azalea bush in flower (variant even magenta, odd white)
##
## Every kind's sprays are in one atlas of its own (miyo_atlas(): 4 x 4 cells of 512, see CELL_*), so the generators
## need two leaf materials for all of them (miyo_leaf_material(1 near / 2 far, ...)); bark keys come from
## miyo_bark_key() for bark_material(). miyo_mesh() builds any of them; lod 1 is the far stand-in (under 150 triangles).
## Sizes are game metres; the tree stands on y = 0, its roots a little below.

const MIYO_KINDS := ["sakura", "yamazakura", "shidare", "sugi", "momiji", "momiji_red", "take", "matsu", "tsutsuji"]

## The atlas's cells, row by row. Cells with a direction are drawn upright, their base at the cell's foot (v = 1),
## but the weeping cherry's strands, which hang from the cell's top and tile downward (BODY over BODY over TAIL).
const CELL_SAKURA_BOUGH := 0   # a twig sleeved in blossom, from the foot to the top
const CELL_SAKURA_CLUMP := 1   # twigs radiating from the middle, clusters along them
const CELL_SAKURA_MASS := 2    # a dense cloud of blossom: the far stand-ins
const CELL_SAKURA_THIN := 3    # a few twig ends with sparse clusters, sky between
const CELL_YAMA_SPRAY := 4     # pinker, thinner blossom among bronze young leaves
const CELL_YAMA_MASS := 5
const CELL_SHIDARE_BODY := 6   # hanging strands, tiling top to bottom
const CELL_SHIDARE_TAIL := 7   # the strands' ends
const CELL_MOMIJI := 8         # a flat spray of small palmate leaves
const CELL_TAKE := 9           # a bamboo branchlet arching over, narrow leaves
const CELL_TSUTSUJI_PINK := 10
const CELL_TSUTSUJI_WHITE := 11
const CELL_SUGI_SPRAY := 12    # an upswept plume of cedar shoots
const CELL_SUGI_MASS := 13     # plumes packed dense: the crown's inside
const CELL_SUGI_FAR := 14      # a whole crown's silhouette, tip at the top: the far stand-in
const CELL_MATSU := 15         # a pad of pine needle tufts

const MC := 512
const MW := 2048
## What an empty texel of each cell holds (the colour bilinear filtering bleeds in at an edge): the cell's own mean.
const CELL_BG := [
	Color(0.96, 0.86, 0.89), Color(0.96, 0.86, 0.89), Color(0.95, 0.84, 0.88), Color(0.96, 0.86, 0.89),
	Color(0.90, 0.72, 0.74), Color(0.88, 0.68, 0.70), Color(0.92, 0.64, 0.74), Color(0.92, 0.64, 0.74),
	Color(0.52, 0.66, 0.18), Color(0.44, 0.56, 0.18), Color(0.60, 0.20, 0.36), Color(0.70, 0.74, 0.60),
	Color(0.10, 0.20, 0.10), Color(0.08, 0.17, 0.08), Color(0.09, 0.18, 0.09), Color(0.14, 0.26, 0.13),
]

const PAL_SOMEI := {"petal": Color(0.985, 0.90, 0.925), "petal2": Color(1.0, 0.955, 0.96), "heart": Color(0.90, 0.50, 0.62),
		"back": Color(0.95, 0.80, 0.85), "back2": Color(0.90, 0.71, 0.78), "bud": Color(0.90, 0.46, 0.60), "twig": Color(0.17, 0.12, 0.11)}
const PAL_YAMA := {"petal": Color(0.97, 0.79, 0.83), "petal2": Color(0.99, 0.88, 0.89), "heart": Color(0.84, 0.38, 0.48),
		"back": Color(0.90, 0.64, 0.68), "back2": Color(0.82, 0.52, 0.55), "bud": Color(0.84, 0.34, 0.46), "twig": Color(0.20, 0.13, 0.11)}
const PAL_SHIDARE := {"petal": Color(0.96, 0.66, 0.77), "petal2": Color(0.985, 0.79, 0.85), "heart": Color(0.80, 0.26, 0.46),
		"back": Color(0.88, 0.50, 0.63), "back2": Color(0.80, 0.40, 0.55), "bud": Color(0.80, 0.22, 0.44), "twig": Color(0.20, 0.13, 0.12)}
const SUGI_DARK := Color(0.07, 0.16, 0.08)
const SUGI_MID := Color(0.13, 0.26, 0.12)
const SUGI_TIP := Color(0.26, 0.40, 0.17)

## Bark keys this file adds to WoodlandBuilder.BARKS, and what bark_material() sets beside the table's values.
const MIYO_BARK_EXTRA := {
	"sakura": {"roughness_value": 0.62},
	"take": {"roughness_value": 0.42, "node_spacing": 1.0},
}

## The cherries, in metres before the tree is scaled to its height `h` (drawn between x and y): trunk radius, lean,
## where it forks, a leader above the fork (0: none), limbs (outer.x .. outer.y) of length `len` leaving at elevation
## `el0` and ending at `el1` (radians; `bend` > 1 keeps them steep for longer), uprights from the top, secondary
## branches per limb with their lengths (inner, outer), elevations (inner, outer) and how far they arch over, twigs.
const CHERRY := {
	"sakura": {"h": Vector2(9.4, 11.6), "r": 0.38, "lean": 0.35, "fork": 2.0, "leader": 0.0, "outer": Vector2i(4, 5), "limb_r": 0.56,
		"len": 3.4, "el0": 1.1, "el1": -0.12, "bend": 1.0, "upright": 2, "up_len": 5.0, "up_el1": 0.75,
		"sec": 5, "sec_len": Vector2(2.6, 1.4), "sec_el": Vector2(1.0, 0.3), "sec_drop": Vector2(0.7, 1.1), "twigs": 2},
	"yamazakura": {"h": Vector2(13.5, 16.5), "r": 0.36, "lean": 0.5, "fork": 4.4, "leader": 5.2, "outer": Vector2i(6, 7), "limb_r": 0.42,
		"len": 5.0, "el0": 1.0, "el1": 0.42, "bend": 1.0, "upright": 2, "up_len": 4.2, "up_el1": 0.9,
		"sec": 4, "sec_len": Vector2(2.6, 1.5), "sec_el": Vector2(0.8, 0.5), "sec_drop": Vector2(0.3, 0.7), "twigs": 2},
	"shidare": {"h": Vector2(8.2, 9.8), "r": 0.44, "lean": 0.3, "fork": 2.7, "leader": 0.0, "outer": Vector2i(6, 7), "limb_r": 0.46,
		"len": 5.4, "el0": 1.35, "el1": -0.85, "bend": 2.1, "upright": 1, "up_len": 3.4, "up_el1": 0.2,
		"sec": 4, "sec_len": Vector2(2.0, 1.2), "sec_el": Vector2(0.5, -0.1), "sec_drop": Vector2(1.0, 1.4), "twigs": 0},
}

var _miyo_atlas: Texture2D


# ======================================================================================
#  The API
# ======================================================================================

## The bark key (bark_material(key, lod_mode)) of a kind.
func miyo_bark_key(kind: String) -> String:
	match kind:
		"sakura", "yamazakura", "shidare":
			return "sakura"
		"tsutsuji", "momiji_red":
			return "momiji"
	return kind


## bark_material() with what the table can't say: the cherry's sheen, the bamboo's node rings.
func bark_material(kind: String, lod_mode: int) -> ShaderMaterial:
	var m: ShaderMaterial = super(kind, lod_mode)
	if MIYO_BARK_EXTRA.has(kind):
		var extra: Dictionary = MIYO_BARK_EXTRA[kind]
		for k in extra.keys():
			m.set_shader_parameter(k, extra[k])
	return m


## The leaves and blossom of every Miyoshino kind: acacia_leaves.gdshader over miyo_atlas() (saved through save_res
## as "leaf_atlas_miyoshino"). The per-tree colour drift runs from whiter and cooler to pinker and warmer (on the
## greens: fresher to more olive), and what shines through a card is its own colour, not a leaf green.
func miyo_leaf_material(lod_mode: int, sway: float, sway_height: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://acacia_leaves.gdshader")
	m.set_shader_parameter("leaf_tex", miyo_atlas())
	m.set_shader_parameter("backlight_color", Color(1.0, 1.0, 1.0))
	m.set_shader_parameter("backlight_albedo", 1.0)
	m.set_shader_parameter("glow", 0.24)
	m.set_shader_parameter("seed_tint_a", Vector3(0.98, 1.02, 1.03))
	m.set_shader_parameter("seed_tint_b", Vector3(1.04, 0.955, 0.95))
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("sway_height", sway_height)
	set_lod(m, lod_mode)
	return m


## Any Miyoshino kind's tree as a two-surface mesh (bark, leaves); `lod` 1 is the far stand-in.
func miyo_mesh(kind: String, variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	match kind:
		"sakura", "yamazakura", "shidare":
			return _cherry_mesh(kind, variant, lod, bark_mat, leaf_mat)
		"sugi":
			return _sugi_mesh(variant, lod, bark_mat, leaf_mat)
		"momiji", "momiji_red":
			return _momiji_mesh(variant, lod, bark_mat, leaf_mat, kind == "momiji_red")
		"take":
			return _take_mesh(variant, lod, bark_mat, leaf_mat)
		"matsu":
			return _matsu_mesh(variant, lod, bark_mat, leaf_mat)
		"tsutsuji":
			return _tsutsuji_mesh(variant, lod, bark_mat, leaf_mat)
	push_error("MiyoshinoTrees: no kind '%s'" % kind)
	return null


static func miyo_uv(cell: int) -> Rect2:
	var m: float = 3.0 / float(MW)
	return Rect2(float(cell % 4) * 0.25 + m, float(cell / 4) * 0.25 + m, 0.25 - 2.0 * m, 0.25 - 2.0 * m)


# ======================================================================================
#  The atlas
# ======================================================================================

func miyo_atlas() -> Texture2D:
	if _miyo_atlas:
		return _miyo_atlas
	_miyo_atlas = save_res.call(ImageTexture.create_from_image(miyo_atlas_image()), "leaf_atlas_miyoshino")
	return _miyo_atlas


## The atlas as an image with its mipmaps (each cell's coverage kept at every level).
func miyo_atlas_image() -> Image:
	var cv := LeafCanvas.new(1, Color.BLACK)
	cv.w = MW
	var rgb := PackedFloat32Array()
	for row in range(4):
		var line := PackedFloat32Array()
		line.resize(MW * 3)
		for x in range(MW):
			var c: Color = CELL_BG[row * 4 + x / MC]
			line[x * 3] = c.r
			line[x * 3 + 1] = c.g
			line[x * 3 + 2] = c.b
		for y in range(MC):
			rgb.append_array(line)
	cv.rgb = rgb
	var alpha := PackedFloat32Array()
	alpha.resize(MW * MW)
	cv.alpha = alpha
	var rng := RandomNumberGenerator.new()
	rng.seed = 1603
	var somei := {"every": 30.0, "rad": 25.0, "n": 5, "R": Vector2(12.0, 16.5), "side": 0.3, "side_len": Vector2(70.0, 150.0),
			"wander": 0.14, "skip": 0.1, "bare": 30.0}
	# --- sakura bough: one twig up the cell, spurs and side twigs sleeved in clusters.
	var o: Vector2 = _cell_o(CELL_SAKURA_BOUGH)
	var opt: Dictionary = somei.duplicate()
	opt["pull"] = Vector2(0.0, -0.22)
	_blossom_twig(cv, rng, o, o + Vector2(256.0, 506.0), Vector2(0.0, -1.0), 480.0, 3.4, PAL_SOMEI, opt, 1)
	_blossom_twig(cv, rng, o, o + Vector2(250.0, 380.0), Vector2(-0.75, -0.66), 170.0, 2.0, PAL_SOMEI, opt, 0)
	_blossom_twig(cv, rng, o, o + Vector2(262.0, 300.0), Vector2(0.8, -0.6), 160.0, 2.0, PAL_SOMEI, opt, 0)
	# --- sakura clump: twigs radiating.
	o = _cell_o(CELL_SAKURA_CLUMP)
	opt = somei.duplicate()
	opt["bare"] = 0.0
	for k in range(8):
		var a: float = TAU * float(k) / 8.0 + rng.randf_range(-0.25, 0.25)
		_blossom_twig(cv, rng, o, o + Vector2(256.0, 256.0) + Vector2.from_angle(a) * 12.0, Vector2.from_angle(a), rng.randf_range(150.0, 235.0), 2.6, PAL_SOMEI, opt, 1)
	_blossom_cluster(cv, rng, o, o + Vector2(256.0, 256.0), Vector2.UP, 34.0, PAL_SOMEI, opt)
	# --- sakura mass.
	_blossom_mass(cv, rng, _cell_o(CELL_SAKURA_MASS), PAL_SOMEI, 0)
	# --- sakura thin: twig ends fanning from the foot.
	o = _cell_o(CELL_SAKURA_THIN)
	opt = somei.duplicate()
	opt["every"] = 44.0
	opt["skip"] = 0.3
	opt["side"] = 0.22
	opt["bare"] = 70.0
	opt["pull"] = Vector2(0.0, -0.08)
	for k in range(4):
		var a2: float = -PI * 0.5 + lerpf(-0.75, 0.75, (float(k) + 0.5) / 4.0) + rng.randf_range(-0.1, 0.1)
		_blossom_twig(cv, rng, o, o + Vector2(256.0 + rng.randf_range(-16.0, 16.0), 506.0), Vector2.from_angle(a2), rng.randf_range(330.0, 470.0), 2.4, PAL_SOMEI, opt, 1)
	# --- yamazakura.
	o = _cell_o(CELL_YAMA_SPRAY)
	opt = {"every": 40.0, "rad": 23.0, "n": 4, "R": Vector2(11.0, 15.0), "side": 0.25, "side_len": Vector2(60.0, 130.0),
			"wander": 0.14, "skip": 0.15, "bare": 0.0, "leaves": 3}
	for k in range(7):
		var a3: float = TAU * float(k) / 7.0 + rng.randf_range(-0.25, 0.25)
		_blossom_twig(cv, rng, o, o + Vector2(256.0, 256.0) + Vector2.from_angle(a3) * 12.0, Vector2.from_angle(a3), rng.randf_range(150.0, 232.0), 2.6, PAL_YAMA, opt, 1)
	_blossom_mass(cv, rng, _cell_o(CELL_YAMA_MASS), PAL_YAMA, 70)
	# --- shidare: strands down the cell; the body's leave where they came in, so it tiles.
	var xs: Array = []
	for k in range(8):
		xs.append(34.0 + 444.0 * (float(k) + 0.5) / 8.0 + rng.randf_range(-14.0, 14.0))
	for part in range(2):
		o = _cell_o(CELL_SHIDARE_BODY + part)
		for k in range(xs.size()):
			var reach: float = 512.0 if part == 0 else rng.randf_range(170.0, 500.0)
			_strand(cv, rng, o, float(xs[k]), reach, 1.3 + float(k % 3), part == 1)
	# --- momiji.
	_momiji_spray(cv, rng, _cell_o(CELL_MOMIJI))
	# --- take.
	_take_spray(cv, rng, _cell_o(CELL_TAKE))
	# --- tsutsuji.
	_azalea(cv, rng, _cell_o(CELL_TSUTSUJI_PINK), Color(0.86, 0.15, 0.52), Color(0.94, 0.32, 0.64), Color(0.58, 0.04, 0.30))
	_azalea(cv, rng, _cell_o(CELL_TSUTSUJI_WHITE), Color(0.96, 0.95, 0.92), Color(1.0, 1.0, 0.98), Color(0.80, 0.86, 0.52))
	# --- sugi.
	o = _cell_o(CELL_SUGI_SPRAY)
	_sugi_plume(cv, rng, o, o + Vector2(256.0, 504.0), 484.0, 250.0, 6.0)
	o = _cell_o(CELL_SUGI_MASS)
	_blob(cv, rng, o, 232.0, 900, Vector2(10.0, 18.0), Color(0.04, 0.09, 0.05), Color(0.07, 0.14, 0.07))
	for k in range(13):
		var bp: Vector2 = o + Vector2(256.0, 300.0) + Vector2.from_angle(rng.randf() * TAU) * 170.0 * sqrt(rng.randf())
		bp.y += 60.0
		_sugi_plume(cv, rng, o, bp, rng.randf_range(190.0, 260.0), 95.0, 5.0)
	_sugi_far(cv, rng, _cell_o(CELL_SUGI_FAR))
	# --- matsu.
	_matsu_pad(cv, rng, _cell_o(CELL_MATSU))
	return _miyo_mipmaps(cv, 0.5)


static func _cell_o(cell: int) -> Vector2:
	return Vector2(float(cell % 4) * MC, float(cell / 4) * MC)


static func _fits(o: Vector2, p: Vector2, m: float) -> bool:
	return p.x > o.x + m and p.x < o.x + MC - m and p.y > o.y + m and p.y < o.y + MC - m


## RGBA8 with mipmaps, each cell's alpha scaled at every level so the share of it passing `cutoff` stays level 0's
## (WoodlandBuilder's _coverage_mipmaps, per cell: a thin spray beside a dense one keeps its own coverage).
static func _miyo_mipmaps(cv: LeafCanvas, cutoff: float) -> Image:
	var w: int = cv.w
	var data := PackedByteArray()
	data.resize(w * w * 4)
	var rgb: PackedFloat32Array = cv.rgb
	var alpha: PackedFloat32Array = cv.alpha
	var counts := PackedInt32Array()
	counts.resize(16)
	for y in range(w):
		var crow: int = (y / MC) * 4
		for x in range(w):
			var i: int = y * w + x
			var a: float = alpha[i]
			data[i * 4] = int(clampf(rgb[i * 3], 0.0, 1.0) * 255.0 + 0.5)
			data[i * 4 + 1] = int(clampf(rgb[i * 3 + 1], 0.0, 1.0) * 255.0 + 0.5)
			data[i * 4 + 2] = int(clampf(rgb[i * 3 + 2], 0.0, 1.0) * 255.0 + 0.5)
			data[i * 4 + 3] = int(clampf(a, 0.0, 1.0) * 255.0 + 0.5)
			if a >= cutoff:
				counts[crow + x / MC] += 1
	var img := Image.create_from_data(w, w, false, Image.FORMAT_RGBA8, data)
	img.generate_mipmaps()
	var all: PackedByteArray = img.get_data()
	var cut8: float = cutoff * 255.0
	var off: int = w * w * 4
	var size: int = w / 2
	while size >= 8:
		var cs: int = size / 4
		for cell in range(16):
			var need: int = int(float(counts[cell]) / float(MC * MC) * float(cs * cs) + 0.5)
			if need <= 0:
				continue
			var x0: int = (cell % 4) * cs
			var y0: int = (cell / 4) * cs
			var hist := PackedInt32Array()
			hist.resize(256)
			for y in range(cs):
				var row: int = off + ((y0 + y) * size + x0) * 4 + 3
				for x in range(cs):
					hist[all[row + x * 4]] += 1
			var acc := 0
			var thr := 255
			while thr > 1 and acc + hist[thr] < need:
				acc += hist[thr]
				thr -= 1
			var scale: float = clampf(cut8 / float(thr), 1.0, 16.0)
			if scale > 1.004:
				for y in range(cs):
					var row2: int = off + ((y0 + y) * size + x0) * 4 + 3
					for x in range(cs):
						var j: int = row2 + x * 4
						all[j] = mini(255, int(float(all[j]) * scale + 0.5))
		off += size * size * 4
		size /= 2
	return Image.create_from_data(w, w, true, Image.FORMAT_RGBA8, all)


## A five-petalled blossom of radius `r_px`: the petals turned by `ph`, the whole flower seen tilted (`tilt` 1: face
## on) about an axis at `rot`. Pale at the petals' edges, `heart` in the middle, a notch in each petal's tip.
static func _blossom(cv: LeafCanvas, c: Vector2, r_px: float, rot: float, tilt: float, ph: float, petal: Color, heart: Color) -> void:
	var w: int = cv.w
	var x0: int = maxi(0, int(c.x - r_px - 1.0))
	var x1: int = mini(w - 1, int(c.x + r_px + 1.0))
	var y0: int = maxi(0, int(c.y - r_px - 1.0))
	var y1: int = mini(w - 1, int(c.y + r_px + 1.0))
	var ca: float = cos(rot)
	var sa: float = sin(rot)
	var inv_t: float = 1.0 / maxf(tilt, 0.3)
	var edge: Color = petal.lerp(Color(1.0, 1.0, 1.0), 0.45)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var qx: float = float(x) + 0.5 - c.x
			var qy: float = float(y) + 0.5 - c.y
			var u: float = qx * ca + qy * sa
			var v: float = (qy * ca - qx * sa) * inv_t
			var r: float = sqrt(u * u + v * v)
			if r > r_px + 1.0:
				continue
			var lobe: float = absf(cos((atan2(v, u) + ph) * 2.5))
			var rr: float = r_px * (0.38 + 0.62 * pow(lobe, 0.5))
			if lobe > 0.965:
				rr *= 1.0 - 0.17 * (lobe - 0.965) / 0.035
			var a: float = clampf(rr - r + 0.5, 0.0, 1.0)
			if a <= 0.0:
				continue
			var t: float = r / r_px
			var col: Color = heart.lerp(petal, smoothstep(0.08, 0.5, t)).lerp(edge, smoothstep(0.5, 1.0, t))
			col = col.darkened((1.0 - lobe) * 0.10 * smoothstep(0.25, 0.6, t))
			cv._put(y * w + x, a, col)
	# Stamens.
	for k in range(4):
		var sa2: float = ph + TAU * float(k) / 4.0 + 0.4
		var su: float = cos(sa2) * r_px * 0.2
		var sv: float = sin(sa2) * r_px * 0.2 * tilt
		cv.dot(c + Vector2(su * ca - sv * sa, su * sa + sv * ca), 0.9, Color(0.96, 0.82, 0.46))


## A narrow leaf or needle from `base` along `dir`, widest `widest` of the way up; cheap (it only visits its own texels).
static func _blade(cv: LeafCanvas, base: Vector2, dir: Vector2, length: float, width: float, col: Color, tip: Color, widest := 0.35) -> void:
	var d: Vector2 = dir.normalized()
	var perp := Vector2(-d.y, d.x)
	var w: int = cv.w
	var ns: int = int(length / 0.7) + 1
	var rib: Color = col.lightened(0.14)
	for i in range(ns + 1):
		var t: float = float(i) / float(ns)
		var half: float = width * (pow(t / widest, 0.6) if t < widest else pow(maxf(1.0 - (t - widest) / (1.0 - widest), 0.0), 0.8))
		var c: Color = col.lerp(tip, t)
		var na: int = int(half / 0.7) + 1
		var at: Vector2 = base + d * (t * length)
		for j in range(-na, na + 1):
			var a: float = float(j) * 0.7
			var al: float = clampf(half - absf(a) + 0.5, 0.0, 1.0)
			if al <= 0.0:
				continue
			var p: Vector2 = at + perp * a
			var x: int = int(p.x)
			var y: int = int(p.y)
			if x < 0 or y < 0 or x >= w or y >= w:
				continue
			cv._put(y * w + x, al, rib.lerp(tip, t) if j == 0 and half > 2.0 else c.darkened(0.16 * absf(a) / maxf(half, 0.01)))


## A cluster of blossom at `c`: flowers further back as soft discs, young leaves (opt "leaves"), buds, then the flowers.
func _blossom_cluster(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2, c: Vector2, out: Vector2, rad: float, pal: Dictionary, opt: Dictionary) -> void:
	var n: int = int(opt["n"]) + rng.randi_range(-1, 1)
	var rr: Vector2 = opt["R"]
	for k in range(n + 2):
		var q: Vector2 = c + Vector2.from_angle(rng.randf() * TAU) * rad * sqrt(rng.randf()) * 0.85
		if _fits(o, q, rr.y + 2.0):
			cv.dot(q, rng.randf_range(rr.x * 0.5, rr.y * 0.78), (pal["back"] as Color).lerp(pal["back2"], rng.randf()))
	for k in range(rng.randi_range(0, int(opt.get("leaves", 0)))):
		var ld: Vector2 = Vector2.from_angle(out.angle() + rng.randf_range(-1.2, 1.2))
		var ll: float = rng.randf_range(34.0, 54.0)
		if _fits(o, c + ld * (ll + rad * 0.3), 4.0):
			var bronze: Color = Color(0.56, 0.24, 0.15).lerp(Color(0.52, 0.38, 0.16), rng.randf() * 0.7)
			_blade(cv, c + ld * rad * 0.3, ld, ll, rng.randf_range(7.0, 10.0), bronze, bronze.lightened(0.2), 0.4)
	for k in range(rng.randi_range(1, 3)):
		var q2: Vector2 = c + Vector2.from_angle(rng.randf() * TAU) * rad * rng.randf_range(0.75, 1.2)
		if _fits(o, q2, 6.0):
			cv.line(c.lerp(q2, 0.5), q2, 0.8, 0.8, Color(0.46, 0.20, 0.20))
			cv.dot(q2, rng.randf_range(2.6, 4.2), pal["bud"])
	for k in range(n):
		var q3: Vector2 = c + Vector2.from_angle(rng.randf() * TAU) * rad * sqrt(rng.randf())
		var r1: float = rng.randf_range(rr.x, rr.y)
		if not _fits(o, q3, r1 + 2.0):
			continue
		var petal: Color = (pal["petal"] as Color).lerp(pal["petal2"], rng.randf())
		# Lit from above: a flower low in its cluster is a little deeper.
		petal = petal.lerp(pal["back"], clampf((q3.y - c.y) / rad, 0.0, 1.0) * 0.35)
		_blossom(cv, q3, r1, rng.randf() * PI, rng.randf_range(0.5, 1.0), rng.randf() * TAU, petal, pal["heart"])


## A twig from `p0` along `d0` with clusters on spurs to either side and at its end; `depth` > 0 lets it throw side
## twigs. opt: every (texels between clusters), rad, n, R (flower radii), side (chance of a side twig), side_len,
## wander, skip (chance a node is bare), bare (texels before the first cluster), pull (a steady turn), leaves.
func _blossom_twig(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2, p0: Vector2, d0: Vector2, length: float, r0: float,
		pal: Dictionary, opt: Dictionary, depth: int) -> void:
	var p: Vector2 = p0
	var d: Vector2 = d0.normalized()
	var gone := 0.0
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var every: float = opt["every"]
	var rad: float = opt["rad"]
	var pull: Vector2 = opt.get("pull", Vector2.ZERO)
	var marg: float = rad + 20.0
	var since: float = every * rng.randf_range(0.2, 0.8)
	while gone < length:
		var seg: float = rng.randf_range(12.0, 18.0)
		d = (d.rotated(rng.randf_range(-1.0, 1.0) * float(opt["wander"])) + pull * 0.2).normalized()
		var q: Vector2 = p + d * seg
		if not _fits(o, q, 8.0):
			break
		var t: float = gone / length
		cv.line(p, q, lerpf(r0, r0 * 0.4, t), lerpf(r0, r0 * 0.4, t), pal["twig"])
		p = q
		gone += seg
		since += seg
		if since >= every and gone > float(opt.get("bare", 0.0)):
			since = rng.randf_range(-0.25, 0.25) * every
			side = -side
			if depth > 0 and rng.randf() < float(opt["side"]):
				var sl: Vector2 = opt["side_len"]
				_blossom_twig(cv, rng, o, p, d.rotated(side * rng.randf_range(0.5, 1.1)), rng.randf_range(sl.x, sl.y) * (1.0 - t * 0.5),
						r0 * 0.6, pal, opt, depth - 1)
			elif rng.randf() > float(opt["skip"]):
				var sd: Vector2 = d.rotated(side * rng.randf_range(0.5, 1.3))
				var c: Vector2 = p + sd * rng.randf_range(rad * 0.3, rad * 1.1)
				if _fits(o, c, marg):
					cv.line(p, c, r0 * 0.45, r0 * 0.35, pal["twig"])
					_blossom_cluster(cv, rng, o, c, sd, rad * rng.randf_range(0.8, 1.2), pal, opt)
	if _fits(o, p, marg):
		_blossom_cluster(cv, rng, o, p, d, rad, pal, opt)


## Soft discs filling a lumpy round patch of the cell: what lies behind the sprays of a dense cell.
func _blob(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2, radius: float, n: int, size: Vector2, c0: Color, c1: Color) -> void:
	var ph: float = rng.randf() * TAU
	for k in range(n):
		var a: float = rng.randf() * TAU
		var lim: float = radius * (0.88 + 0.08 * sin(a * 3.0 + ph) + 0.04 * sin(a * 7.0 + ph * 2.0))
		var q: Vector2 = o + Vector2(256.0, 256.0) + Vector2.from_angle(a) * lim * sqrt(rng.randf())
		var r: float = rng.randf_range(size.x, size.y)
		if _fits(o, q, r + 3.0):
			cv.dot(q, r, c0.lerp(c1, rng.randf()))


## A dense cloud of blossom (the far stand-ins' cell): puffs of flowers over flowers, deeper toward each puff's
## underside, a few gaps; `leaves` bronze young leaves among them (yamazakura).
func _blossom_mass(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2, pal: Dictionary, leaves: int) -> void:
	_blob(cv, rng, o, 226.0, 620, Vector2(9.0, 17.0), pal["back"], pal["back2"])
	var mid: Vector2 = o + Vector2(256.0, 256.0)
	for k in range(leaves):
		var q0: Vector2 = mid + Vector2.from_angle(rng.randf() * TAU) * 205.0 * sqrt(rng.randf())
		var bronze: Color = Color(0.56, 0.24, 0.15).lerp(Color(0.52, 0.38, 0.16), rng.randf() * 0.7)
		_blade(cv, q0, Vector2.from_angle(rng.randf() * TAU), rng.randf_range(30.0, 46.0), rng.randf_range(7.0, 9.5), bronze, bronze.lightened(0.2), 0.4)
	for k in range(9):
		var q1: Vector2 = mid + Vector2.from_angle(rng.randf() * TAU) * 190.0 * sqrt(rng.randf())
		cv.line(q1, q1 + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(30.0, 70.0), 1.6, 1.0, pal["twig"])
	var puffs: Array = []
	for k in range(12):
		puffs.append(mid + Vector2.from_angle(TAU * float(k) / 12.0 + rng.randf_range(-0.2, 0.2)) * rng.randf_range(60.0, 165.0))
	puffs.append(mid)
	for pf in puffs:
		var pc: Vector2 = pf
		var pr: float = rng.randf_range(62.0, 84.0)
		for k in range(34 if leaves == 0 else 26):
			var q: Vector2 = pc + Vector2.from_angle(rng.randf() * TAU) * pr * sqrt(rng.randf())
			var r1: float = rng.randf_range(11.5, 16.5)
			if not _fits(o, q, r1 + 3.0) or q.distance_to(mid) > 236.0:
				continue
			var petal: Color = (pal["petal"] as Color).lerp(pal["petal2"], rng.randf())
			petal = petal.lerp(pal["back"], clampf((q.y - pc.y) / pr * 0.5 + 0.2, 0.0, 1.0) * 0.5)
			_blossom(cv, q, r1, rng.randf() * PI, rng.randf_range(0.5, 1.0), rng.randf() * TAU, petal, pal["heart"])


## One hanging strand of the weeping cherry down the cell from its top at `x`, `reach` texels long: a thin twig
## swaying about its line (whole waves, so the body cell tiles) with small clusters all along; `taper` thins its end.
func _strand(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2, x: float, reach: float, phase: float, taper: bool) -> void:
	var opt := {"n": 3, "R": Vector2(9.0, 12.5)}
	var prev := Vector2(o.x + x, o.y)
	var y := 0.0
	var k := 0
	while y < reach:
		y = minf(y + 14.0, reach)
		var p := Vector2(o.x + x + 9.0 * sin(TAU * y / 512.0 * 2.0 + phase) - 9.0 * sin(phase), o.y + y)
		cv.line(prev, p, 1.3, 1.3, PAL_SHIDARE["twig"])
		prev = p
		k += 1
		var end_t: float = (y / reach) if taper else 0.0
		if k % 2 == 0 and y > 12.0 and y < 500.0 and rng.randf() > end_t * 0.35:
			var c: Vector2 = p + Vector2(rng.randf_range(-13.0, 13.0), rng.randf_range(-4.0, 4.0))
			var rad: float = lerpf(17.0, 10.0, end_t)
			if _fits(o, c, rad + 14.0):
				_blossom_cluster(cv, rng, o, c, Vector2(0.0, 1.0), rad, PAL_SHIDARE, opt)


## A maple leaf: seven narrow pointed lobes from one base, the middle longest.
static func _momiji_leaf(cv: LeafCanvas, base: Vector2, dir: Vector2, size: float, col: Color, tip: Color) -> void:
	const LOBE := [1.0, 0.92, 0.70, 0.44]
	const STEP := 0.44
	var w: int = cv.w
	var a0: float = dir.angle()
	var x0: int = maxi(0, int(base.x - size - 1.0))
	var x1: int = mini(w - 1, int(base.x + size + 1.0))
	var y0: int = maxi(0, int(base.y - size - 1.0))
	var y1: int = mini(w - 1, int(base.y + size + 1.0))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := Vector2(float(x) + 0.5 - base.x, float(y) + 0.5 - base.y)
			var r: float = q.length()
			if r > size + 1.0:
				continue
			var th: float = wrapf(q.angle() - a0, -PI, PI)
			var k: int = clampi(roundi(th / STEP), -3, 3)
			var dth: float = absf(th - float(k) * STEP)
			var xl: float = r / (size * float(LOBE[absi(k)]))
			if xl > 1.0 or dth > STEP:
				continue
			var half: float = STEP * 0.72 * pow(1.0 - xl, 0.75)
			var a: float = clampf((half - dth) * r + 0.6, 0.0, 1.0)
			if a <= 0.0:
				continue
			var c: Color = col.lerp(tip, smoothstep(0.45, 1.0, xl))
			if dth * r < 0.8:
				c = c.lightened(0.18)
			cv._put(y * w + x, a, c)


## A flat spray of maple leaves on fine reddish twigs radiating from the cell's middle.
func _momiji_spray(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2) -> void:
	var mid: Vector2 = o + Vector2(256.0, 256.0)
	for t in range(17):
		var a: float = TAU * float(t) / 17.0 + rng.randf_range(-0.2, 0.2)
		var d := Vector2.from_angle(a)
		var p: Vector2 = mid + d * rng.randf_range(6.0, 30.0)
		var total: float = rng.randf_range(120.0, 222.0)
		var gone := 0.0
		var side := 1.0
		while gone < total:
			var seg: float = rng.randf_range(15.0, 22.0)
			d = d.rotated(rng.randf_range(-0.2, 0.2))
			var q: Vector2 = p + d * seg
			if not _fits(o, q, 42.0):
				break
			cv.line(p, q, 1.3, 1.0, Color(0.44, 0.22, 0.14))
			side = -side
			for s in [side, -side * 0.6]:
				if rng.randf() < 0.2:
					continue
				var ld: Vector2 = d.rotated(float(s) * rng.randf_range(0.5, 1.1))
				var g: Color = Color(0.48, 0.66, 0.15).lerp(Color(0.68, 0.78, 0.24), rng.randf())
				var tip: Color = Color(0.86, 0.56, 0.24) if rng.randf() < 0.22 else g.lightened(0.2)
				cv.line(q, q + ld * 7.0, 0.8, 0.8, Color(0.62, 0.28, 0.18))
				_momiji_leaf(cv, q + ld * 7.0, ld, rng.randf_range(25.0, 35.0) * (1.0 - gone / total * 0.2), g, tip)
			p = q
			gone += seg
		var g2: Color = Color(0.60, 0.74, 0.20)
		_momiji_leaf(cv, p, d, 28.0, g2, g2.lightened(0.2))


## A bamboo branchlet: thin twigs fanning up from the cell's foot and arching over, narrow leaves in pairs along
## them and in fans at their ends, all drooping.
func _take_spray(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2) -> void:
	var foot: Vector2 = o + Vector2(256.0, 505.0)
	for t in range(7):
		var a0: float = -PI * 0.5 + lerpf(-1.05, 1.05, (float(t) + 0.5) / 7.0) + rng.randf_range(-0.08, 0.08)
		var d := Vector2.from_angle(a0)
		var p: Vector2 = foot + Vector2(rng.randf_range(-10.0, 10.0), 0.0)
		var length: float = rng.randf_range(330.0, 520.0)
		var gone := 0.0
		var side := 1.0
		while gone < length:
			var seg: float = rng.randf_range(17.0, 24.0)
			d = (d + Vector2(0.0, 0.035 + gone / length * 0.09) + Vector2(rng.randf_range(-0.04, 0.04), 0.0)).normalized()
			var q: Vector2 = p + d * seg
			if not _fits(o, q, 10.0):
				break
			cv.line(p, q, 1.5 * (1.0 - gone / length) + 0.6, 0.9, Color(0.46, 0.50, 0.22))
			p = q
			gone += seg
			if gone < 70.0:
				continue
			side = -side
			var n: int = 1 if rng.randf() < 0.6 else 2
			for j in range(n):
				var ld: Vector2 = (d.rotated(side * rng.randf_range(0.35, 0.95) * (1.0 if j == 0 else -1.0)) + Vector2(0.0, 0.35)).normalized()
				var ll: float = rng.randf_range(44.0, 66.0)
				if not _fits(o, q + ld * ll, 4.0):
					continue
				var g: Color = Color(0.36, 0.52, 0.16).lerp(Color(0.56, 0.66, 0.24), rng.randf())
				_blade(cv, q, ld, ll, rng.randf_range(5.0, 7.0), g, g.lerp(Color(0.74, 0.76, 0.36), 0.5), 0.3)
		for j in range(4):
			var ld2: Vector2 = (d.rotated(lerpf(-0.8, 0.8, float(j) / 3.0)) + Vector2(0.0, 0.3)).normalized()
			if _fits(o, p + ld2 * 60.0, 4.0):
				var g3: Color = Color(0.44, 0.60, 0.18).lerp(Color(0.58, 0.68, 0.26), rng.randf())
				_blade(cv, p, ld2, rng.randf_range(46.0, 60.0), 6.0, g3, g3.lightened(0.25), 0.3)


## An azalea's surface: small dark leaves packed in a round patch, funnel flowers all over them.
func _azalea(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2, petal: Color, petal2: Color, heart: Color) -> void:
	_blob(cv, rng, o, 236.0, 500, Vector2(10.0, 16.0), Color(0.06, 0.13, 0.05), Color(0.10, 0.20, 0.07))
	var mid: Vector2 = o + Vector2(256.0, 256.0)
	for k in range(420):
		var q: Vector2 = mid + Vector2.from_angle(rng.randf() * TAU) * 226.0 * sqrt(rng.randf())
		var g: Color = Color(0.10, 0.23, 0.07).lerp(Color(0.22, 0.38, 0.11), rng.randf())
		_blade(cv, q, Vector2.from_angle(rng.randf() * TAU), rng.randf_range(15.0, 22.0), rng.randf_range(4.5, 6.5), g, g.lightened(0.15), 0.45)
	for k in range(175):
		var q2: Vector2 = mid + Vector2.from_angle(rng.randf() * TAU) * 222.0 * sqrt(rng.randf())
		var r1: float = rng.randf_range(13.0, 19.0)
		if _fits(o, q2, r1 + 3.0):
			_blossom(cv, q2, r1, rng.randf() * PI, rng.randf_range(0.55, 1.0), rng.randf() * TAU, petal.lerp(petal2, rng.randf()), heart)


## One cedar shoot: a cord of short incurved needles, curling up toward the light, fresher at its tip.
func _sugi_shoot(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2, p0: Vector2, d0: Vector2, length: float, thick: float, depth: int) -> void:
	var p: Vector2 = p0
	var d: Vector2 = d0.normalized()
	var gone := 0.0
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	while gone < length:
		var t: float = gone / length
		d = (d + Vector2(rng.randf_range(-0.05, 0.05), -0.085)).normalized()
		var q: Vector2 = p + d * 4.0
		if not _fits(o, q, thick + 13.0):
			break
		var g: Color = SUGI_DARK.lerp(SUGI_MID, rng.randf()).lerp(SUGI_TIP, smoothstep(0.6, 1.0, t) * 0.85)
		cv.dot(q, thick * (1.0 - 0.45 * t), g.darkened(0.2))
		for s in [-1.0, 1.0]:
			var nd: Vector2 = (d * 0.75 + Vector2(-d.y, d.x) * float(s) * 0.66).normalized()
			_blade(cv, q, nd, rng.randf_range(9.0, 13.0) * (1.0 - 0.3 * t), 2.1, g, g.lightened(0.18), 0.3)
		p = q
		gone += 4.0
		if depth > 0 and t > 0.12 and t < 0.85 and rng.randf() < 0.13:
			side = -side
			_sugi_shoot(cv, rng, o, q, d.rotated(side * rng.randf_range(0.5, 0.9)), (length - gone) * rng.randf_range(0.5, 0.85), thick * 0.85, depth - 1)


## A plume of cedar shoots standing on `foot`: a leader `height` tall, side shoots sweeping out and up, longest
## (`reach`) below the middle.
func _sugi_plume(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2, foot: Vector2, height: float, reach: float, thick: float) -> void:
	var n: int = int(height / 21.0)
	for k in range(n):
		var t: float = (float(k) + 0.5) / float(n)
		var at: Vector2 = foot + Vector2(sin(t * 5.0) * 6.0, -height * t)
		for s in [-1.0, 1.0]:
			if rng.randf() < 0.12:
				continue
			var sl: float = (reach * pow(sin(PI * clampf(0.12 + t * 0.86, 0.0, 1.0)), 0.8) + 18.0) * rng.randf_range(0.65, 1.12)
			_sugi_shoot(cv, rng, o, at, Vector2(float(s), -0.25 - t * 0.5).rotated(rng.randf_range(-0.15, 0.15)), sl, thick * 0.9, 1)
	_sugi_shoot(cv, rng, o, foot, Vector2(0.0, -1.0), height, thick, 0)


## A whole cedar crown from the side, as the near tree grows it: tiers of boughs from the stem, each drooping out and
## sweeping up into a tuft, their reach short at the very foot, longest a sixth of the way up and nothing at the tip,
## each tier a little different and a few missing, so the outline is ragged with sky between the tiers (painted as a
## smooth triangle, the stand-in read as a cone: the user saw it).
func _sugi_far(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2) -> void:
	var axis: float = o.x + 256.0
	var top: float = o.y + 20.0
	var foot: float = o.y + 494.0
	var span: float = foot - top
	var tiers := 26
	var rows: Array = []
	for w in range(tiers):
		var t: float = clampf((float(w) + rng.randf_range(-0.3, 0.3)) / float(tiers), 0.0, 0.96)
		var reach: float = 226.0 * pow(1.0 - t, 0.8) * lerpf(0.55, 1.0, smoothstep(0.0, 0.18, t)) * rng.randf_range(0.8, 1.06) + 12.0
		rows.append([foot - span * t, reach, t])
	# The dark inside round the stem, tier by tier (no band along the foot).
	for r in rows:
		var y: float = r[0]
		var reach: float = r[1]
		for k in range(int(6.0 + reach * 0.06)):
			var q := Vector2(axis + rng.randf_range(-reach, reach) * 0.42, y + rng.randf_range(-14.0, 6.0))
			var rad: float = rng.randf_range(7.0, 12.0)
			if _fits(o, q, rad + 2.0):
				cv.dot(q, rad, Color(0.04, 0.09, 0.05).lerp(Color(0.07, 0.15, 0.07), rng.randf()))
	# The boughs: a limb out each side, shoots along it sweeping outward and up, a tuft standing up at its end.
	for r in rows:
		var y: float = r[0]
		var reach: float = r[1]
		var t: float = r[2]
		for s in [-1.0, 1.0]:
			if rng.randf() < 0.1 and t > 0.1:
				continue
			var out: float = reach * rng.randf_range(0.82, 1.0)
			var end := Vector2(axis + float(s) * out, y - out * rng.randf_range(0.05, 0.18))
			var start := Vector2(axis + float(s) * 3.0, y + 4.0)
			if _fits(o, end, 14.0):
				cv.line(start, end, 3.0, 1.4, Color(0.10, 0.11, 0.07))
			var n: int = maxi(1, int(out / 34.0))
			for j in range(n):
				var f: float = (float(j) + rng.randf_range(0.2, 0.8)) / float(n)
				var from: Vector2 = start.lerp(end, f * 0.85)
				var room: float = out * (1.0 - f * 0.8)
				_sugi_shoot(cv, rng, o, from, Vector2(float(s), 0.12).rotated(rng.randf_range(-0.12, 0.12)), room * rng.randf_range(0.55, 0.8) + 12.0,
						lerpf(5.5, 3.6, t), 1 if room > 70.0 else 0)
			# The tuft: the lump of the outline at the bough's end.
			_sugi_shoot(cv, rng, o, end + Vector2(-float(s) * 6.0, 4.0), Vector2(float(s) * 0.35, -1.0), clampf(out * 0.35, 18.0, 48.0), 4.2, 0)
	# The leader.
	_sugi_shoot(cv, rng, o, Vector2(axis, top + 70.0), Vector2(0.0, -1.0), 54.0, 4.0, 0)


## A pad of pine: shoots ending in bursts of long needles, mostly upward, a pale candle in each.
func _matsu_pad(cv: LeafCanvas, rng: RandomNumberGenerator, o: Vector2) -> void:
	var mid: Vector2 = o + Vector2(256.0, 256.0)
	var tufts: Array = []
	var tries := 0
	while tufts.size() < 30 and tries < 800:
		tries += 1
		var c: Vector2 = mid + Vector2.from_angle(rng.randf() * TAU) * 190.0 * sqrt(rng.randf())
		var ok := true
		for t in tufts:
			if (t as Vector2).distance_to(c) < 52.0:
				ok = false
				break
		if ok:
			tufts.append(c)
	for t in tufts:
		var c2: Vector2 = t
		cv.line(c2.lerp(mid, 0.45), c2, 2.4, 1.6, Color(0.36, 0.22, 0.15))
	for t in tufts:
		var c3: Vector2 = t
		var up: float = (c3 - mid).angle() if c3.distance_to(mid) > 30.0 else -PI * 0.5
		for k in range(34):
			var a: float = up + rng.randf_range(-1.0, 1.0) * rng.randf_range(0.6, 2.4)
			var g: Color = Color(0.09, 0.20, 0.10).lerp(Color(0.20, 0.36, 0.15), rng.randf())
			_blade(cv, c3, Vector2.from_angle(a), rng.randf_range(34.0, 52.0), 1.5, g, g.lerp(Color(0.34, 0.48, 0.20), 0.6), 0.2)
		cv.dot(c3, 3.2, Color(0.66, 0.58, 0.38))


# ======================================================================================
#  Geometry helpers
# ======================================================================================

## What a card needs of the crown it is in: the crown's normal at a point (a flattened sphere, leaning up by `lift`),
## the shade there (dark low and near the axis) and the tint, turned toward `deep` in the shade.
class Crown:
	var c := Vector3.ZERO
	var r := 5.0
	var under := 2.0
	var top := 10.0
	var lift := 0.5
	var floor_shade := 0.3
	var axis_shade := 0.75
	var deep := Color(1.0, 1.0, 1.0)

	func nrm(v: Vector3) -> Vector3:
		var cn: Vector3 = v - c
		cn = Vector3(cn.x / maxf(r, 0.1), cn.y / maxf((top - under) * 0.7, 0.1), cn.z / maxf(r, 0.1)).normalized()
		return (cn + Vector3.UP * lift).normalized()

	func shade(v: Vector3) -> float:
		var s: float = clampf(floor_shade + (1.0 - floor_shade) * smoothstep(under - 0.5, top - 0.5, v.y), 0.25, 1.0)
		return s * lerpf(axis_shade, 1.0, clampf(Vector2(v.x - c.x, v.z - c.z).length() / maxf(r, 0.1), 0.0, 1.0))

	func col(tint: Color, v: Vector3, bright: float) -> Color:
		var s: float = shade(v)
		var k: float = 1.0 - s
		return Color(tint.r * bright * lerpf(1.0, deep.r, k), tint.g * bright * lerpf(1.0, deep.g, k), tint.b * bright * lerpf(1.0, deep.b, k), s)


static func _dir(az: float, el: float) -> Vector3:
	return Vector3(cos(el) * cos(az), sin(el), cos(el) * sin(az))


## A branch's centre line: `n` segments from `p0`, heading (az0, el0) and turning to (az1, el1) by its end
## (`bend` > 1: late), wandering by `wig`.
static func _arc(rng: RandomNumberGenerator, p0: Vector3, az0: float, el0: float, az1: float, el1: float, length: float, n: int,
		wig: float, bend := 1.0) -> Array:
	var pts: Array = [p0]
	var p: Vector3 = p0
	for k in range(n):
		var t: float = pow((float(k) + 0.5) / float(n), bend)
		var d: Vector3 = _dir(lerpf(az0, az1, t), lerpf(el0, el1, t))
		d = (d + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.6, 0.6), rng.randf_range(-1.0, 1.0)) * wig).normalized()
		p += d * (length / float(n))
		pts.append(p)
	return pts


static func _plen(path: Array) -> float:
	var l := 0.0
	for k in range(path.size() - 1):
		l += (path[k] as Vector3).distance_to(path[k + 1])
	return l


## The point `s` metres along a path (past its end: on along its last segment).
static func _pat(path: Array, s: float) -> Vector3:
	var left: float = maxf(s, 0.0)
	for k in range(path.size() - 1):
		var a: Vector3 = path[k]
		var b: Vector3 = path[k + 1]
		var l: float = a.distance_to(b)
		if left <= l or k == path.size() - 2:
			return a + (b - a) / maxf(l, 1e-5) * left
		left -= l
	return path[path.size() - 1]


static func _ptan(path: Array, s: float) -> Vector3:
	var d: Vector3 = _pat(path, s + 0.25) - _pat(path, maxf(s - 0.25, 0.0))
	return d.normalized() if d.length_squared() > 1e-8 else Vector3.UP


static func _radii(n: int, r0: float, r1: float, k := 1.0) -> Array:
	var out: Array = []
	for i in range(n):
		out.append(lerpf(r0, r1, pow(float(i) / float(maxi(n - 1, 1)), k)))
	return out


## One card: centred on `p`, `t1` across and `t2` toward the cell's top, half sizes `hw`, `hl`.
static func _card(st: SurfaceTool, base: int, p: Vector3, t1: Vector3, t2: Vector3, hw: float, hl: float, cell: int, tint: Color,
		cr: Crown, bright := 1.0, flip := false) -> int:
	var uvr: Rect2 = miyo_uv(cell)
	var u0: float = uvr.end.x if flip else uvr.position.x
	var u1: float = uvr.position.x if flip else uvr.end.x
	var corners: Array = [p - t1 * hw - t2 * hl, p + t1 * hw - t2 * hl, p + t1 * hw + t2 * hl, p - t1 * hw + t2 * hl]
	var uvs: Array = [Vector2(u0, uvr.end.y), Vector2(u1, uvr.end.y), Vector2(u1, uvr.position.y), Vector2(u0, uvr.position.y)]
	for j in range(4):
		var v: Vector3 = corners[j]
		st.set_normal(cr.nrm(v))
		st.set_color(cr.col(tint, v, bright))
		st.set_uv(uvs[j])
		st.add_vertex(v)
	for idx in [0, 1, 2, 0, 2, 3]:
		st.add_index(base + idx)
	return base + 4


static func _vary(tint: Color, rng: RandomNumberGenerator, amount := 0.04) -> Color:
	return Color(tint.r * rng.randf_range(1.0 - amount, 1.0 + amount), tint.g * rng.randf_range(1.0 - amount, 1.0 + amount),
			tint.b * rng.randf_range(1.0 - amount, 1.0 + amount))


## Cards sleeving a branch between shares `from` and `to` of its length: crossed pairs (or single cards) `width` by
## `length`, each along the branch there, its cell's foot toward the branch's start. `over` runs the last one on past
## the branch's end.
static func _sleeve(st: SurfaceTool, base: int, path: Array, from: float, to: float, width: float, length: float, cells: Array,
		tint: Color, cr: Crown, rng: RandomNumberGenerator, crossed := true, over := 0.3) -> int:
	var total: float = _plen(path)
	var s0: float = from * total
	var s1: float = to * total + over * length
	var n: int = maxi(1, int(ceil((s1 - s0) / (length * 0.8))))
	for i in range(n):
		var s: float = s0 + (float(i) + 0.5) * (s1 - s0) / float(n)
		var ax: Vector3 = (_pat(path, s + length * 0.4) - _pat(path, maxf(s - length * 0.4, 0.0))).normalized()
		var t1: Vector3 = ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized().rotated(ax, rng.randf() * TAU)
		var p: Vector3 = _pat(path, s)
		for c in range(2 if crossed else 1):
			var cell: int = cells[rng.randi() % cells.size()]
			base = _card(st, base, p, t1.rotated(ax, PI * 0.5 * float(c)), ax, width * 0.5 * rng.randf_range(0.88, 1.1), length * 0.5, cell,
					_vary(tint, rng), cr, rng.randf_range(0.94, 1.05), rng.randf() < 0.5)
	return base


## `n` cards scattered within `r` of `p`, facing mostly out of the crown (`flat` 1: lying level, as a maple's tier).
static func _puffs(st: SurfaceTool, base: int, p: Vector3, r: float, n: int, size: Vector2, cell: int, tint: Color, cr: Crown,
		rng: RandomNumberGenerator, flat := 0.0) -> int:
	for k in range(n):
		var off := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.5, 0.8), rng.randf_range(-1.0, 1.0)).normalized()
		var q: Vector3 = p + off * r * sqrt(rng.randf()) * Vector3(1.0, 1.0 - flat * 0.8, 1.0)
		var out: Vector3 = q - cr.c
		out.y *= 0.6
		out = (out.normalized() + Vector3.UP * 0.35 + off * 0.45).normalized()
		var nrm: Vector3 = out if rng.randf() < 0.65 else Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		if flat > 0.0:
			nrm = nrm.lerp(Vector3.UP, flat).normalized()
		var t1: Vector3 = nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized().rotated(nrm, rng.randf() * TAU)
		var hs: float = rng.randf_range(size.x, size.y) * 0.5
		base = _card(st, base, q, t1, nrm.cross(t1), hs, hs, cell, _vary(tint, rng), cr, rng.randf_range(0.93, 1.06), rng.randf() < 0.5)
	return base


## WoodlandBuilder.frond over this atlas: a strip folded into a shallow V from `root` along `dir`, starting at
## elevation `rise` and ending at -`droop` (a negative droop sweeps its tip up).
static func _mfrond(st: SurfaceTool, base: int, root: Vector3, dir: Vector3, rise: float, droop: float, length: float,
		width: float, segs: int, cell: int, tint: Color, shade0: float, shade1: float, fold: float) -> int:
	var uvr: Rect2 = miyo_uv(cell)
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var side := Vector3(-flat.z, 0.0, flat.x)
	var p: Vector3 = root
	var pts: Array = [p]
	for k in range(segs):
		var t: float = (float(k) + 0.5) / float(segs)
		var ang: float = rise - (rise + droop) * t * t
		p += (flat * cos(ang) + Vector3.UP * sin(ang)) * (length / float(segs))
		pts.append(p)
	var cf: float = cos(fold)
	var sf: float = sin(fold)
	var o: Vector3 = (flat * 1.0 + Vector3.UP * 0.45).normalized()
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		var q: Vector3 = pts[k]
		var w: float = width * 0.5
		var fwd: Vector3 = ((pts[mini(k + 1, segs)] as Vector3) - (pts[maxi(k - 1, 0)] as Vector3)).normalized()
		var up: Vector3 = side.cross(fwd).normalized()
		if up.y < 0.0:
			up = -up
		var v: float = uvr.position.y + uvr.size.y * (1.0 - t)
		for e in [-1.0, 0.0, 1.0]:
			st.set_normal((o + up * 0.4 + side * float(e) * 0.35).normalized())
			st.set_color(Color(tint.r, tint.g, tint.b, lerpf(shade0, shade1, t)))
			st.set_uv(Vector2(uvr.position.x + uvr.size.x * (0.5 + float(e) * 0.5), v))
			st.add_vertex(q + side * (w * cf * float(e)) + up * (w * sf * absf(float(e))))
	for k in range(segs):
		var a0: int = base + k * 3
		for idx in [a0, a0 + 3, a0 + 1, a0 + 1, a0 + 3, a0 + 4, a0 + 1, a0 + 4, a0 + 2, a0 + 2, a0 + 4, a0 + 5]:
			st.add_index(idx)
	return base + (segs + 1) * 3


## A weeping cherry's curtain: a strip `width` wide (along `side`) from `top`, swinging out along `out` at first and
## then hanging straight to `bottom_y`, in squares of the strand cells (the last the strands' ends).
static func _curtain(st: SurfaceTool, base: int, top: Vector3, out: Vector3, side: Vector3, width: float, bottom_y: float, tint: Color,
		cr: Crown, rng: RandomNumberGenerator) -> int:
	var drop: float = top.y - bottom_y
	if drop < 0.8:
		return base
	var n: int = maxi(1, int(round(drop / (width * 1.15))))
	var flip: bool = rng.randf() < 0.5
	var bright: float = rng.randf_range(0.94, 1.05)
	var p: Vector3 = top
	for k in range(n):
		var swing: float = 0.35 * maxf(1.0 - float(k) * 0.8, 0.0)
		var q: Vector3 = p + out * (drop / float(n)) * swing
		q.y = top.y - drop * float(k + 1) / float(n)
		var mid: Vector3 = (p + q) * 0.5
		var t2: Vector3 = p - q
		var hl: float = t2.length() * 0.5
		base = _card(st, base, mid, side, t2.normalized(), width * 0.5, hl, CELL_SHIDARE_TAIL if k == n - 1 else CELL_SHIDARE_BODY, tint, cr, bright, flip)
		p = q
	return base


static func _commit(st: SurfaceTool, leaf_st: SurfaceTool, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, bark_mat)
	leaf_st.commit(mesh)
	mesh.surface_set_material(1, leaf_mat)
	return mesh


# ======================================================================================
#  The cherries
# ======================================================================================

## A cherry's frame, the same for both levels of detail: trunk, limbs, secondary branches and twigs as paths with
## their radii, scaled so the tree is as tall as CHERRY says, and its crown.
func _cherry_skeleton(sp: Dictionary, rng: RandomNumberGenerator, variant: int) -> Dictionary:
	var fork: float = float(sp["fork"]) * rng.randf_range(0.85, 1.18)
	var leader: float = float(sp["leader"]) * rng.randf_range(0.9, 1.1)
	var top_y: float = fork + leader
	var r0: float = float(sp["r"]) * rng.randf_range(0.92, 1.1)
	var lean: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)) * float(sp["lean"])
	var trunk: Array = []
	var trunk_r: Array = []
	for k in range(9):
		var t: float = float(k) / 8.0
		var y: float = lerpf(-0.7, top_y, t)
		var lt: float = clampf(y / top_y, 0.0, 1.0)
		trunk.append(Vector3(0.0, y, 0.0) + lean * lt * lt + Vector3(sin(lt * 3.6 + float(variant) * 1.7), 0.0, cos(lt * 2.9 + float(variant))) * 0.1 * minf(lt * 3.0, 1.0))
		var flare: float = 1.0 + 0.5 * (1.0 - smoothstep(-0.7, 0.9, y))
		trunk_r.append(r0 * lerpf(1.0, 0.5 if leader > 0.0 else 0.88, lt) * flare)
	var limbs: Array = []
	var out_n: Vector2i = sp["outer"]
	var n_out: int = rng.randi_range(out_n.x, out_n.y)
	var a0: float = rng.randf() * TAU
	for i in range(n_out):
		var share: float = float(i) / float(maxi(n_out - 1, 1))
		var ay: float = fork - 0.12 * float(i)
		var az: float = a0 + TAU * float(i) / float(n_out) + rng.randf_range(-0.28, 0.28)
		var length: float = float(sp["len"]) * rng.randf_range(0.86, 1.12)
		var lr: float = r0 * float(sp["limb_r"]) * rng.randf_range(0.85, 1.05)
		if leader > 0.0:
			ay = fork + leader * pow(share, 0.9) * 0.92
			az = a0 + float(i) * 2.39996 + rng.randf_range(-0.28, 0.28)
			length *= lerpf(1.0, 0.6, share)
			lr = r0 * float(sp["limb_r"]) * lerpf(1.0, 0.6, share)
		var path: Array = _arc(rng, _trunk_at(trunk, ay), az, float(sp["el0"]) + rng.randf_range(-0.12, 0.12), az + rng.randf_range(-0.5, 0.5),
				float(sp["el1"]) + rng.randf_range(-0.14, 0.1), length, 7, 0.09, float(sp["bend"]))
		limbs.append({"path": path, "r0": lr, "r1": maxf(lr * 0.15, 0.024), "up": false})
	for j in range(int(sp["upright"])):
		var az2: float = rng.randf() * TAU
		var path2: Array = _arc(rng, _trunk_at(trunk, top_y - 0.05), az2, 1.42, az2 + rng.randf_range(-0.6, 0.6), float(sp["up_el1"]),
				float(sp["up_len"]) * rng.randf_range(0.9, 1.1), 6, 0.1)
		var ur: float = r0 * float(sp["limb_r"]) * 0.8
		limbs.append({"path": path2, "r0": ur, "r1": maxf(ur * 0.15, 0.024), "up": true})
	var seconds: Array = []
	var sec_len: Vector2 = sp["sec_len"]
	var sec_el: Vector2 = sp["sec_el"]
	var sec_drop: Vector2 = sp["sec_drop"]
	for limb in limbs:
		var lp: Array = limb["path"]
		var ll: float = _plen(lp)
		var ns: int = int(sp["sec"]) + rng.randi_range(-1, 1)
		var side: float = 1.0 if rng.randf() < 0.5 else -1.0
		for m in range(ns):
			var t2: float = lerpf(0.26, 0.96, (float(m) + rng.randf() * 0.7) / float(ns))
			var tan: Vector3 = _ptan(lp, t2 * ll)
			side = -side
			var az3: float = atan2(tan.z, tan.x) + side * rng.randf_range(0.55, 1.2)
			var e0: float = lerpf(sec_el.x, sec_el.y, t2) + rng.randf_range(-0.15, 0.15)
			if bool(limb["up"]):
				e0 = rng.randf_range(0.35, 0.85)
			var sr: float = maxf(lerpf(float(limb["r0"]), float(limb["r1"]), t2) * 0.55, 0.03)
			var path3: Array = _arc(rng, _pat(lp, t2 * ll), az3, e0, az3 + side * rng.randf_range(-0.2, 0.5), e0 - rng.randf_range(sec_drop.x, sec_drop.y),
					lerpf(sec_len.x, sec_len.y, t2) * rng.randf_range(0.8, 1.15), 4, 0.1)
			seconds.append({"path": path3, "r0": sr, "r1": 0.013, "t": t2})
	var twigs: Array = []
	for sec in seconds:
		var spth: Array = sec["path"]
		var sl: float = _plen(spth)
		for m in range(int(sp["twigs"])):
			var t3: float = rng.randf_range(0.3, 0.9)
			var tan2: Vector3 = _ptan(spth, t3 * sl)
			var az4: float = atan2(tan2.z, tan2.x) + (1.0 if m % 2 == 0 else -1.0) * rng.randf_range(0.5, 1.2)
			var e1: float = asin(clampf(tan2.y, -1.0, 1.0)) + rng.randf_range(-0.2, 0.5)
			twigs.append({"path": _arc(rng, _pat(spth, t3 * sl), az4, e1, az4, e1 - rng.randf_range(0.5, 0.9), rng.randf_range(0.9, 1.6), 2, 0.1)})
	# As tall as it should be.
	var top := 0.0
	for group in [limbs, seconds, twigs]:
		for b in group:
			for p in (b["path"] as Array):
				top = maxf(top, (p as Vector3).y)
	var hh: Vector2 = sp["h"]
	var f: float = rng.randf_range(hh.x, hh.y) / (top + 0.7)
	for k in range(trunk.size()):
		trunk[k] = (trunk[k] as Vector3) * f
		trunk_r[k] = float(trunk_r[k]) * f
	for group in [limbs, seconds, twigs]:
		for b in group:
			var pth: Array = b["path"]
			for k in range(pth.size()):
				pth[k] = (pth[k] as Vector3) * f
			if b.has("r0"):
				b["r0"] = float(b["r0"]) * f
				b["r1"] = float(b["r1"]) * f
	var crown := Crown.new()
	var mean := Vector3.ZERO
	var low := 1e9
	for sec in seconds:
		var tip: Vector3 = (sec["path"] as Array)[4]
		mean += tip
		low = minf(low, tip.y)
	mean /= float(maxi(seconds.size(), 1))
	var rad := 0.0
	for sec in seconds:
		var tip2: Vector3 = (sec["path"] as Array)[4]
		rad = maxf(rad, Vector2(tip2.x - mean.x, tip2.z - mean.z).length())
	crown.under = maxf(low - 0.5, 0.0)
	crown.top = (top + 0.7) * f
	crown.c = Vector3(mean.x, (crown.under + crown.top) * 0.5, mean.z)
	crown.r = rad + 0.6
	return {"trunk": trunk, "trunk_r": trunk_r, "limbs": limbs, "seconds": seconds, "twigs": twigs, "crown": crown, "scale": f, "fork": fork * f}


func _cherry_mesh(kind: String, variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var sp: Dictionary = CHERRY[kind]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + 7919 * variant + 5
	var sk: Dictionary = _cherry_skeleton(sp, rng, variant)
	rng.seed = hash(kind) + 104729 * variant + 11 + lod
	var cr: Crown = sk["crown"]
	var f: float = sk["scale"]
	var limbs: Array = sk["limbs"]
	var seconds: Array = sk["seconds"]
	var twigs: Array = sk["twigs"]
	var trunk: Array = sk["trunk"]
	var trunk_r: Array = sk["trunk_r"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var lb := 0
	var bark: Color = BARKS["sakura"][5]
	var shade := Vector2(cr.under - 0.5, cr.under + 4.0)
	# Blossom never goes grey: lit well down into the crown, and pinker, not darker, in its shade.
	cr.lift = 0.75
	cr.floor_shade = 0.62
	cr.axis_shade = 0.84
	var tint := Color(0.80, 0.80, 0.80)
	match kind:
		"sakura":
			cr.deep = Color(1.0, 0.86, 0.91)
			tint = Color(0.81, 0.775, 0.79)
		"yamazakura":
			cr.deep = Color(1.0, 0.84, 0.86)
			tint = Color(0.81, 0.78, 0.76)
		"shidare":
			cr.deep = Color(1.0, 0.86, 0.90)
			cr.under = 0.0
			cr.floor_shade = 0.7
	if lod == 1:
		# The stand-in: the trunk, the biggest limbs, and a cloud card where each branch carries its blossom.
		cr.lift = 0.9
		cr.floor_shade = 0.72
		bi = bark_tube(st, bi, [trunk[0], trunk[4], trunk[8]], [trunk_r[0], trunk_r[4], trunk_r[8]], 4, bark, 0.4, shade)
		for i in range(mini(limbs.size(), 4)):
			var lp: Array = limbs[i]["path"]
			var mid_i: int = lp.size() / 2
			bi = bark_tube(st, bi, [lp[0], lp[mid_i], lp[lp.size() - 1]], [float(limbs[i]["r0"]), float(limbs[i]["r0"]) * 0.6, float(limbs[i]["r1"])], 3, bark, 0.4, shade)
		var budget: int = 40 if kind != "shidare" else 12
		var step: float = maxf(float(seconds.size()) / float(budget), 1.0)
		var mass: int = CELL_YAMA_MASS if kind == "yamazakura" else CELL_SAKURA_MASS
		var far_tint: Color = tint if kind != "shidare" else Color(0.80, 0.62, 0.70)
		var k := 0.0
		while int(k) < seconds.size():
			var spth: Array = seconds[int(k)]["path"]
			var size: float = (_plen(spth) * 0.55 + 1.5 * f) * (0.9 if kind == "yamazakura" else 1.0)
			var far_cell: int = mass
			if int(k) % 3 == 2 and kind != "shidare":
				far_cell = CELL_YAMA_SPRAY if kind == "yamazakura" else CELL_SAKURA_CLUMP
			lb = _puffs(leaf_st, lb, spth[3], 0.4, 1, Vector2(size, size * 1.2) * (1.25 if far_cell != mass else 1.0), far_cell, far_tint, cr, rng)
			k += step
		if kind == "shidare":
			for i in range(limbs.size()):
				var lp2: Array = limbs[i]["path"]
				for s in [0.62, 0.95]:
					var top: Vector3 = _pat(lp2, _plen(lp2) * float(s))
					var out := Vector3(top.x - cr.c.x, 0.0, top.z - cr.c.z).normalized()
					lb = _curtain(leaf_st, lb, top + Vector3(0, 0.3, 0), out, Vector3(-out.z, 0.0, out.x), 3.1 * f, rng.randf_range(0.5, 1.3), tint, cr, rng)
		return _commit(st, leaf_st, bark_mat, leaf_mat)
	# The frame.
	bi = bark_tube(st, bi, trunk, trunk_r, 10, bark, 0.4, shade)
	var r0: float = trunk_r[2]
	for k in range(4):
		var a: float = TAU * float(k) / 4.0 + rng.randf_range(-0.4, 0.4)
		var d := Vector3(cos(a), 0.0, sin(a))
		bi = bark_tube(st, bi, [d * r0 * 0.4 + Vector3(0, 0.8, 0), d * r0 * 1.2 + Vector3(0, 0.12, 0), d * r0 * 2.2 + Vector3(0, -0.35, 0)],
				[r0 * 0.32, r0 * 0.25, r0 * 0.1], 5, bark, 0.4, shade)
	for limb in limbs:
		var lp3: Array = limb["path"]
		bi = bark_tube(st, bi, lp3, _radii(lp3.size(), float(limb["r0"]), float(limb["r1"]), 0.8), 6, bark, 0.4, shade)
	for sec in seconds:
		var sp3: Array = sec["path"]
		bi = bark_tube(st, bi, sp3, _radii(sp3.size(), float(sec["r0"]), float(sec["r1"])), 4, bark, 0.4, shade)
	for tw in twigs:
		var tp: Array = tw["path"]
		bi = bark_tube(st, bi, [tp[0], tp[2]], [0.02 * f, 0.008 * f], 3, bark, 0.4, shade)
	# The blossom.
	match kind:
		"sakura":
			var boughs: Array = [CELL_SAKURA_BOUGH, CELL_SAKURA_BOUGH, CELL_SAKURA_THIN]
			for limb in limbs:
				var lp4: Array = limb["path"]
				lb = _sleeve(leaf_st, lb, lp4, 0.55, 1.0, 1.5 * f, 2.0 * f, boughs, tint, cr, rng)
				# Spurs low on the limb: small tufts on the bare wood.
				for k in range(2):
					lb = _puffs(leaf_st, lb, _pat(lp4, _plen(lp4) * rng.randf_range(0.2, 0.5)), 0.25, 1, Vector2(0.8, 1.15) * f, CELL_SAKURA_CLUMP, tint, cr, rng)
			for sec in seconds:
				var sp4: Array = sec["path"]
				lb = _sleeve(leaf_st, lb, sp4, 0.22, 1.0, 1.45 * f, 1.9 * f, boughs, tint, cr, rng)
				lb = _puffs(leaf_st, lb, sp4[4], 0.5 * f, 3, Vector2(1.3, 1.9) * f, CELL_SAKURA_CLUMP, tint, cr, rng)
			for tw in twigs:
				var tp2: Array = tw["path"]
				lb = _sleeve(leaf_st, lb, tp2, 0.0, 1.0, 1.25 * f, 1.8 * f, [CELL_SAKURA_BOUGH, CELL_SAKURA_BOUGH, CELL_SAKURA_THIN], tint, cr, rng, true, 0.45)
				lb = _puffs(leaf_st, lb, tp2[2], 0.3 * f, 1, Vector2(1.1, 1.5) * f, CELL_SAKURA_CLUMP, tint, cr, rng)
		"yamazakura":
			for limb in limbs:
				var lp5: Array = limb["path"]
				var ll: float = _plen(lp5)
				for k in range(3):
					lb = _puffs(leaf_st, lb, _pat(lp5, ll * (0.6 + 0.2 * float(k))), 0.5 * f, 1, Vector2(1.5, 2.0) * f, CELL_YAMA_SPRAY, tint, cr, rng)
			for sec in seconds:
				var sp5: Array = sec["path"]
				var sl: float = _plen(sp5)
				for k in range(3):
					lb = _puffs(leaf_st, lb, _pat(sp5, sl * (0.4 + 0.3 * float(k))), 0.5 * f, 2, Vector2(1.5, 2.1) * f, CELL_YAMA_SPRAY, tint, cr, rng)
			for tw in twigs:
				var tp3: Array = tw["path"]
				lb = _puffs(leaf_st, lb, tp3[2], 0.4 * f, 2, Vector2(1.3, 1.8) * f, CELL_YAMA_SPRAY, tint, cr, rng)
		"shidare":
			var pink := Color(0.80, 0.62, 0.70)
			var hangs: Array = []
			for limb in limbs:
				var lp6: Array = limb["path"]
				var ll2: float = _plen(lp6)
				# The mound on top, where the limbs turn over.
				for k in range(5):
					lb = _puffs(leaf_st, lb, _pat(lp6, ll2 * (0.42 + 0.12 * float(k))), 0.5 * f, 2, Vector2(1.3, 1.8) * f, CELL_SAKURA_CLUMP, pink, cr, rng)
				var s := ll2 * 0.5
				while s < ll2:
					hangs.append(_pat(lp6, s))
					s += 1.0 * f
				hangs.append(lp6[lp6.size() - 1])
			for sec in seconds:
				var sp6: Array = sec["path"]
				var sl2: float = _plen(sp6)
				for k in range(3):
					hangs.append(_pat(sp6, sl2 * (0.4 + 0.3 * float(k))))
				lb = _puffs(leaf_st, lb, sp6[2], 0.4 * f, 2, Vector2(1.2, 1.6) * f, CELL_SAKURA_CLUMP, pink, cr, rng)
			for hp in hangs:
				var top2: Vector3 = hp
				var out2 := Vector3(top2.x - cr.c.x, 0.0, top2.z - cr.c.z)
				out2 = out2.normalized() if out2.length() > 0.3 else Vector3(1, 0, 0)
				var side: Vector3 = Vector3(-out2.z, 0.0, out2.x).rotated(Vector3.UP, rng.randf_range(-0.5, 0.5) + (PI * 0.5 if rng.randf() < 0.28 else 0.0))
				lb = _curtain(leaf_st, lb, top2 + Vector3(0, 0.25, 0), out2, side, rng.randf_range(1.5, 2.0) * f, rng.randf_range(0.45, 1.7) + top2.y * rng.randf_range(0.0, 0.12), tint, cr, rng)
	return _commit(st, leaf_st, bark_mat, leaf_mat)


# ======================================================================================
#  Sugi
# ======================================================================================

func _sugi_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60606 + variant * 131
	var edge: bool = variant % 2 == 1
	var h: float = rng.randf_range(28.0, 33.5) * (0.95 if edge else 1.0)
	var r0: float = h * 0.0155 * rng.randf_range(0.9, 1.1)
	var base_y: float = h * (rng.randf_range(0.15, 0.2) if edge else rng.randf_range(0.38, 0.48))
	var cr: float = rng.randf_range(3.5, 4.1) if edge else rng.randf_range(2.6, 3.1)
	var bark: Color = BARKS["sugi"][5]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var lb := 0
	var trunk: Array = []
	var radii: Array = []
	var n_tr: int = 8 if lod == 0 else 2
	# The stand-in's stem stops a little into the crown: its cards cross on the stem, and a stem to the tip showed as a
	# line up the middle of every far cedar.
	var stem_top: float = h - 0.4 if lod == 0 else base_y + 2.5
	for k in range(n_tr + 1):
		var t: float = float(k) / float(n_tr)
		var tt: float = t * (stem_top + 0.8) / (h - 0.4 + 0.8)
		trunk.append(Vector3(sin(tt * 2.4 + float(variant)) * 0.04, lerpf(-0.8, stem_top, t), cos(tt * 2.0) * 0.04))
		radii.append(r0 * lerpf(1.0, 0.07, pow(tt, 1.15)) * (1.0 + 0.42 * (1.0 - smoothstep(0.0, 0.07, tt))))
	bi = bark_tube(st, bi, trunk, radii, 8 if lod == 0 else 4, bark, 0.4, Vector2(base_y, base_y + 6.0))
	var tint := Color(0.78, 0.84, 0.78)
	var span: float = h - base_y
	if lod == 1:
		# The stand-in: three cards crossing on the stem, 60 degrees apart, the crown painted on them (its ragged tiers show
		# against the sky from every side; ten cards leaning in to the tip had made a smooth cone). Each card is split down
		# the stem so its halves are lit as the crown's sides: normals leaning out from the stem and up, more up higher.
		var rot: float = rng.randf() * TAU
		var uvr: Rect2 = miyo_uv(CELL_SUGI_FAR)
		var mid_u: float = uvr.position.x + uvr.size.x * 0.5
		var y0: float = base_y - 0.6
		var y1: float = h + 0.5
		var hw: float = cr * 1.12
		var levels: Array = [0.0, 0.35, 0.7, 1.0]
		for i in range(3):
			var a: float = rot + PI * float(i) / 3.0
			var across := Vector3(cos(a), 0.0, sin(a))
			for sgn in [-1.0, 1.0]:
				for lv in levels:
					var v: float = float(lv)
					var y: float = lerpf(y0, y1, v)
					var tv: float = lerpf(uvr.end.y, uvr.position.y, v)
					var shade: float = lerpf(0.42, 0.88, v)
					var up: float = lerpf(0.25, 0.75, v)
					# At the stem, then at the card's edge.
					leaf_st.set_normal((across * float(sgn) * 0.3 + Vector3.UP * (0.5 + up)).normalized())
					leaf_st.set_color(Color(tint.r, tint.g, tint.b, shade * 0.85))
					leaf_st.set_uv(Vector2(mid_u, tv))
					leaf_st.add_vertex(Vector3(0.0, y, 0.0))
					leaf_st.set_normal((across * float(sgn) * 0.9 + Vector3.UP * up).normalized())
					leaf_st.set_color(Color(tint.r, tint.g, tint.b, shade))
					leaf_st.set_uv(Vector2(uvr.end.x if sgn > 0.0 else uvr.position.x, tv))
					leaf_st.add_vertex(across * float(sgn) * hw + Vector3(0.0, y, 0.0))
				for k in range(levels.size() - 1):
					var b0: int = lb + k * 2
					for idx in [b0, b0 + 1, b0 + 3, b0, b0 + 3, b0 + 2]:
						leaf_st.add_index(idx)
				lb += levels.size() * 2
		return _commit(st, leaf_st, bark_mat, leaf_mat)
	# Dead stubs on the bare stem of a forest tree.
	if not edge:
		for k in range(7):
			var sy: float = lerpf(base_y * 0.3, base_y, (float(k) + rng.randf()) / 7.0)
			var sa: float = rng.randf() * TAU
			var p0: Vector3 = _trunk_at(trunk, sy)
			var sd := Vector3(cos(sa), rng.randf_range(-0.35, 0.05), sin(sa)).normalized()
			bi = bark_tube(st, bi, [p0, p0 + sd * rng.randf_range(0.5, 1.5)], [0.06, 0.02], 3, bark.darkened(0.25), 0.4, Vector2(h, h + 1.0))
	var spacing: float = 0.86 if edge else 0.74
	var whorls: int = int((span - 1.4) / spacing)
	var crown := Crown.new()
	crown.c = Vector3(0.0, base_y + span * 0.45, 0.0)
	crown.r = cr
	crown.under = base_y
	crown.top = h
	crown.floor_shade = 0.3
	crown.axis_shade = 0.6
	for w in range(whorls):
		var t: float = float(w) / float(whorls - 1)
		var y: float = lerpf(base_y, h - 1.5, t) + rng.randf_range(-0.15, 0.15)
		# The lowest boughs of a forest tree are short; the cone is a little convex.
		var reach: float = cr * pow(1.0 - t, 0.8) * lerpf(0.6, 1.0, smoothstep(0.0, 0.16, t)) + 0.35
		var n: int = 7
		var rot2: float = rng.randf() * TAU
		for b in range(n):
			var a2: float = rot2 + TAU * float(b) / float(n) + rng.randf_range(-0.22, 0.22)
			var dir := Vector3(cos(a2), 0.0, sin(a2))
			var length: float = reach * rng.randf_range(0.8, 1.14) * 1.12
			var width: float = clampf(length * 1.0, 1.7, 3.3)
			var sh0: float = lerpf(0.3, 0.62, t)
			# Boughs leave the stem drooping and sweep up at their ends.
			lb = _mfrond(leaf_st, lb, Vector3(0.0, y + rng.randf_range(-0.2, 0.2), 0.0) + dir * 0.1, dir, lerpf(-0.42, 0.25, t) + rng.randf_range(-0.1, 0.1),
					-rng.randf_range(0.55, 0.85), length, width, 3, CELL_SUGI_SPRAY, _vary(tint, rng, 0.05), sh0, minf(sh0 + 0.5, 1.0), 0.3)
			if b % 2 == w % 2:
				# A tuft standing up at the bough's end: the lumps of the crown's outline.
				var tp: Vector3 = Vector3(0.0, y + reach * 0.25, 0.0) + dir * reach * rng.randf_range(0.6, 0.85)
				var ts: float = clampf(reach * 0.6, 0.9, 1.6) * rng.randf_range(0.9, 1.15)
				var lean_out: Vector3 = (Vector3.UP + dir * 0.35).normalized()
				lb = _card(leaf_st, lb, tp + lean_out * ts * 0.5, Vector3(-dir.z, 0.0, dir.x).rotated(Vector3.UP, rng.randf_range(-0.5, 0.5)), lean_out, ts * 0.75, ts, CELL_SUGI_SPRAY, _vary(tint, rng, 0.05), crown, 1.0, rng.randf() < 0.5)
		if w % 2 == 0 and t < 0.9:
			# The crown's dark inside, round the stem.
			lb = _puffs(leaf_st, lb, Vector3(0.0, y, 0.0), reach * 0.4, 3, Vector2(reach * 1.1 + 0.9, reach * 1.4 + 1.1), CELL_SUGI_MASS, tint.darkened(0.2), crown, rng)
	for ring in [[h - 1.9, 5, 1.3, 0.85, 1.9], [h - 1.1, 4, 1.0, 1.1, 1.4], [h - 0.45, 3, 0.7, 1.3, 0.95]]:
		var rot3: float = rng.randf() * TAU
		for k in range(int(ring[1])):
			var a3: float = rot3 + TAU * float(k) / float(ring[1])
			lb = _mfrond(leaf_st, lb, Vector3(0.0, float(ring[0]), 0.0), Vector3(cos(a3), 0.0, sin(a3)), float(ring[3]), -float(ring[3]) - 0.1, float(ring[4]), float(ring[2]),
					2, CELL_SUGI_SPRAY, tint, 0.8, 1.0, 0.3)
	return _commit(st, leaf_st, bark_mat, leaf_mat)


# ======================================================================================
#  Momiji
# ======================================================================================

## `red`: a red-leaved maple (a deshojo, scarlet in spring): the same spray tinted red.
func _momiji_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material, red := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33011 + variant * 149
	var h: float = rng.randf_range(6.0, 8.0)
	var cr: float = h * rng.randf_range(0.58, 0.68)
	var twin: bool = variant % 2 == 1
	var bark: Color = BARKS["momiji"][5]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var lb := 0
	var shade := Vector2(h * 0.3, h * 0.7)
	var stems: Array = []
	var la: float = rng.randf() * TAU
	for s in range(2 if twin else 1):
		var lean: Vector3 = Vector3(cos(la + PI * float(s)), 0.0, sin(la + PI * float(s))) * rng.randf_range(0.8, 1.5) * (1.0 if twin else 1.2)
		var pts: Array = []
		var n: int = 7 if lod == 0 else 2
		for k in range(n + 1):
			var t: float = float(k) / float(n)
			pts.append(lean * (pow(t, 1.3) + (0.06 if twin else 0.0)) + Vector3(sin(t * 5.0 + float(s) + float(variant)) * 0.16 * t, lerpf(-0.5, h * 0.84, t), cos(t * 4.1 + float(s)) * 0.16 * t))
		stems.append(pts)
		var sr: float = (0.11 if twin else 0.15) * h / 7.0
		var rr: Array = []
		for k in range(n + 1):
			var t2: float = float(k) / float(n)
			rr.append(sr * lerpf(1.0, 0.22, t2) * (1.0 + 0.5 * (1.0 - smoothstep(0.0, 0.12, t2))))
		bi = bark_tube(st, bi, pts, rr, 6 if lod == 0 else 3, bark, 0.3, shade)
	var crown := Crown.new()
	var top_mid := Vector3.ZERO
	for s in stems:
		top_mid += (s as Array)[(s as Array).size() - 1]
	top_mid /= float(stems.size())
	crown.c = Vector3(top_mid.x * 0.7, h * 0.62, top_mid.z * 0.7)
	crown.r = cr
	crown.under = h * 0.3
	crown.top = h
	crown.lift = 0.8
	crown.floor_shade = 0.5
	crown.axis_shade = 0.8
	var tint := Color(1.0, 0.22, 0.2) if red else Color(0.80, 0.80, 0.78)
	const TIER_R := [0.8, 1.0, 0.9, 0.68, 0.4]
	for tier in range(5):
		var ty: float = h * lerpf(0.36, 0.9, float(tier) / 4.0)
		var tr: float = cr * float(TIER_R[tier])
		var nb: int = 5 if tier < 3 else 4
		var rot: float = rng.randf() * TAU
		for b in range(nb):
			var stem: Array = stems[(b + tier) % stems.size()]
			var from: Vector3 = _trunk_at(stem, ty - 0.35)
			var az: float = rot + TAU * float(b) / float(nb) + rng.randf_range(-0.3, 0.3)
			var want: Vector3 = crown.c + Vector3(cos(az), 0.0, sin(az)) * tr
			var flat := Vector3(want.x - from.x, 0.0, want.z - from.z)
			var length: float = maxf(flat.length(), 1.2) * rng.randf_range(0.85, 1.1)
			var az2: float = atan2(flat.z, flat.x)
			var path: Array = _arc(rng, from, az2, 0.5, az2 + rng.randf_range(-0.4, 0.4), -0.1, length, 4, 0.1)
			if lod == 1:
				lb = _puffs(leaf_st, lb, _pat(path, length * 0.62) + Vector3(0, 0.3, 0), 0.3, 1, Vector2(length * 1.0 + 1.0, length * 1.2 + 1.2), CELL_MOMIJI, tint, crown, rng, 0.82)
				continue
			bi = bark_tube(st, bi, path, _radii(5, 0.05, 0.012), 4, bark, 0.3, shade)
			# Flat sprays along the branch and to both sides of it: the tier.
			var s := length * 0.28
			var side := 1.0
			while s < length * 1.05:
				var p: Vector3 = _pat(path, s)
				var tan: Vector3 = _ptan(path, minf(s, length))
				var perp := Vector3(-tan.z, 0.0, tan.x).normalized()
				side = -side
				var q: Vector3 = p + perp * side * rng.randf_range(0.2, 0.9) + Vector3(0.0, 0.18, 0.0)
				lb = _puffs(leaf_st, lb, q, 0.3, 1, Vector2(1.8, 2.5), CELL_MOMIJI, tint, crown, rng, rng.randf_range(0.6, 0.9))
				lb = _puffs(leaf_st, lb, q - Vector3(0.0, 0.15, 0.0), 0.5, 1, Vector2(1.6, 2.2), CELL_MOMIJI, tint, crown, rng, rng.randf_range(0.3, 0.7))
				if rng.randf() < 0.45:
					var tip: Vector3 = p + perp * side * rng.randf_range(1.0, 1.6) + Vector3(0.0, rng.randf_range(-0.2, 0.2), 0.0)
					bi = bark_tube(st, bi, [p, tip], [0.022, 0.008], 3, bark, 0.3, shade)
					lb = _puffs(leaf_st, lb, tip + Vector3(0.0, 0.12, 0.0), 0.35, 2, Vector2(1.3, 1.8), CELL_MOMIJI, tint, crown, rng, rng.randf_range(0.5, 0.9))
				s += rng.randf_range(0.5, 0.7)
	if lod == 1:
		lb = _puffs(leaf_st, lb, Vector3(crown.c.x, h * 0.93, crown.c.z), 0.3, 2, Vector2(cr * 0.8, cr), CELL_MOMIJI, tint, crown, rng, 0.6)
	else:
		lb = _puffs(leaf_st, lb, Vector3(top_mid.x, h * 0.93, top_mid.z), 0.7, 6, Vector2(1.4, 1.9), CELL_MOMIJI, tint, crown, rng, 0.6)
	return _commit(st, leaf_st, bark_mat, leaf_mat)


# ======================================================================================
#  Take
# ======================================================================================

func _take_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 88211 + variant * 157
	var n: int = rng.randi_range(6, 9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var lb := 0
	var feet: Array = []
	var tries := 0
	while feet.size() < n and tries < 400:
		tries += 1
		var a: float = rng.randf() * TAU
		var p := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.15, 1.35)
		var ok := true
		for q in feet:
			if (q as Vector3).distance_to(p) < 0.45:
				ok = false
				break
		if ok:
			feet.append(p)
	var crown := Crown.new()
	crown.c = Vector3(0.0, 11.0, 0.0)
	crown.r = 4.5
	crown.under = 6.5
	crown.top = 16.0
	crown.lift = 0.6
	crown.floor_shade = 0.6
	crown.axis_shade = 0.85
	var tint := Color(0.80, 0.80, 0.78)
	var no_shade := Vector2(100.0, 101.0)
	for ci in range(feet.size()):
		var foot: Vector3 = feet[ci]
		var hh: float = rng.randf_range(12.0, 16.0)
		var cr0: float = rng.randf_range(0.052, 0.07)
		var az: float = atan2(foot.z, foot.x) + rng.randf_range(-0.5, 0.5)
		var path: Array = _arc(rng, foot - Vector3(0.0, 0.4, 0.0), az, PI * 0.5 - rng.randf_range(0.02, 0.09), az + rng.randf_range(-0.3, 0.3),
				PI * 0.5 - rng.randf_range(0.8, 1.2), hh * 1.04, 9, 0.004, 3.2)
		var total: float = _plen(path)
		var young: float = rng.randf()
		var culm: Color = Color(0.86, 0.84, 0.70).lerp(Color(0.74, 0.86, 0.74), young)
		if lod == 1:
			if ci < 5:
				bi = bark_tube(st, bi, [path[0], path[6], path[9]], [cr0, cr0 * 0.8, 0.015], 3, culm, 0.35, no_shade)
			for s in [0.66, 0.84, 0.98]:
				var p2: Vector3 = _pat(path, total * float(s))
				var tan: Vector3 = _ptan(path, total * float(s))
				var t1: Vector3 = tan.cross(Vector3.UP).normalized().rotated(tan, rng.randf() * TAU)
				lb = _card(leaf_st, lb, p2 + tan * 0.5, t1, tan, 1.4, 1.8, CELL_TAKE, tint, crown, rng.randf_range(0.95, 1.05), rng.randf() < 0.5)
			continue
		var rr: Array = []
		for k in range(10):
			var t: float = float(k) / 9.0
			rr.append(cr0 * (1.0 if t < 0.45 else lerpf(1.0, 0.16, (t - 0.45) / 0.55)))
		bi = bark_tube(st, bi, path, rr, 5, culm, 0.35, no_shade)
		# Branches in the upper part, one each side of the culm in turn, with their leaf sprays.
		var s2: float = total * rng.randf_range(0.5, 0.56)
		var k2 := 0
		while s2 < total * 0.97:
			var share: float = (s2 / total - 0.5) / 0.47
			var p3: Vector3 = _pat(path, s2)
			var tan2: Vector3 = _ptan(path, s2)
			var ba: float = az + float(k2) * 2.4 + rng.randf_range(-0.4, 0.4)
			var d: Vector3 = (tan2 * 0.5 + Vector3(cos(ba), 0.0, sin(ba)) * 0.86).normalized()
			var bl: float = lerpf(2.2, 1.0, share) * rng.randf_range(0.8, 1.15)
			var mid: Vector3 = p3 + d * bl * 0.55
			var tip: Vector3 = p3 + d * bl - Vector3(0.0, bl * 0.28, 0.0)
			bi = bark_tube(st, bi, [p3, mid, tip], [0.014, 0.01, 0.004], 3, culm, 0.35, no_shade)
			var ax: Vector3 = (tip - p3).normalized()
			var t3: Vector3 = ax.cross(Vector3.UP).normalized()
			# Along the branch, lying nearly level; and a plume hanging from its end.
			lb = _card(leaf_st, lb, p3.lerp(tip, 0.6), t3, ax, rng.randf_range(0.6, 0.8), bl * 0.5 + 0.3, CELL_TAKE, _vary(tint, rng), crown, 1.0, rng.randf() < 0.5)
			lb = _card(leaf_st, lb, p3.lerp(tip, 0.55) - Vector3(0.0, 0.25, 0.0), ax.cross(t3).normalized(), ax, rng.randf_range(0.5, 0.7), bl * 0.5 + 0.2, CELL_TAKE, _vary(tint, rng), crown, 0.95, rng.randf() < 0.5)
			var down: Vector3 = (Vector3.DOWN + ax * 0.45).normalized()
			for hk in range(2):
				var hp2: Vector3 = tip if hk == 0 else mid
				lb = _card(leaf_st, lb, hp2 + down * 0.7, down.cross(t3).normalized().rotated(down, rng.randf_range(-1.2, 1.2)), down, rng.randf_range(0.7, 0.95), 0.95, CELL_TAKE, _vary(tint, rng), crown, 1.0, rng.randf() < 0.5)
			s2 += rng.randf_range(0.55, 0.85)
			k2 += 1
		var end_tan: Vector3 = _ptan(path, total)
		lb = _sleeve(leaf_st, lb, [path[8], path[9]], 0.2, 1.0, 1.5, 2.2, [CELL_TAKE], tint, crown, rng, true, 0.5)
	return _commit(st, leaf_st, bark_mat, leaf_mat)


# ======================================================================================
#  Matsu, tsutsuji
# ======================================================================================

func _matsu_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47017 + variant * 163
	var h: float = rng.randf_range(6.2, 8.8)
	var bark: Color = BARKS["matsu"][5]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var lb := 0
	var la: float = rng.randf() * TAU
	var lean := Vector3(cos(la), 0.0, sin(la))
	var perp := Vector3(-lean.z, 0.0, lean.x)
	var trunk: Array = []
	var radii: Array = []
	var n: int = 8 if lod == 0 else 3
	var r0: float = 0.25 * h / 7.5
	for k in range(n + 1):
		var t: float = float(k) / float(n)
		trunk.append(lean * h * 0.26 * (sin(t * PI * 1.15 - 0.3) * 0.6 + t * 0.7 + 0.18) + perp * sin(t * 5.0 + float(variant)) * 0.3 * t + Vector3(0.0, lerpf(-0.5, h * 0.9, t), 0.0))
		radii.append(r0 * lerpf(1.0, 0.3, t) * (1.0 + 0.45 * (1.0 - smoothstep(0.0, 0.1, t))))
	var no_shade := Vector2(100.0, 101.0)
	bi = bark_tube(st, bi, trunk, radii, 8 if lod == 0 else 4, bark, 0.36, no_shade)
	var tint := Color(0.80, 0.82, 0.78)
	var pads: Array = [[(trunk[n] as Vector3) + Vector3(0.0, 0.3, 0.0), rng.randf_range(1.4, 1.8)]]
	var nl: int = 6
	for i in range(nl):
		var share: float = float(i) / float(nl - 1)
		var from: Vector3 = _trunk_at(trunk, h * lerpf(0.4, 0.84, share))
		var az: float = la + PI * 0.5 + float(i) * 2.5 + rng.randf_range(-0.4, 0.4)
		var length: float = lerpf(3.1, 1.5, share) * rng.randf_range(0.85, 1.15) * h / 7.5
		var path: Array = _arc(rng, from, az, 0.3, az + rng.randf_range(-0.6, 0.6), -0.05, length, 4, 0.14)
		var lr: float = r0 * lerpf(0.4, 0.22, share)
		if lod == 0:
			bi = bark_tube(st, bi, path, _radii(5, lr, 0.03), 5, bark, 0.34, no_shade)
		else:
			bi = bark_tube(st, bi, [path[0], path[4]], [lr, 0.03], 3, bark, 0.34, no_shade)
		pads.append([(path[4] as Vector3) + Vector3(0.0, 0.25, 0.0), rng.randf_range(1.3, 1.8) * lerpf(1.0, 0.8, share)])
		if lod == 0 or i % 2 == 0:
			pads.append([(path[2] as Vector3) + Vector3(-sin(az), 0.0, cos(az)) * rng.randf_range(-0.8, 0.8) + Vector3(0.0, 0.3, 0.0), rng.randf_range(0.9, 1.2)])
	for pad in pads:
		var pc: Vector3 = pad[0]
		var pr: float = pad[1]
		var crown := Crown.new()
		crown.c = pc - Vector3(0.0, 0.5, 0.0)
		crown.r = pr
		crown.under = pc.y - 0.6
		crown.top = pc.y + 0.6
		crown.lift = 0.9
		crown.floor_shade = 0.45
		crown.axis_shade = 0.9
		if lod == 1:
			lb = _puffs(leaf_st, lb, pc, 0.1, 1, Vector2(pr * 2.2, pr * 2.5), CELL_MATSU, tint, crown, rng, 0.85)
			continue
		lb = _puffs(leaf_st, lb, pc, pr * 0.7, 6, Vector2(pr * 1.0, pr * 1.35), CELL_MATSU, tint, crown, rng, 0.88)
		# The pad's rim, so it has a thickness from the side.
		for k in range(4):
			var a: float = TAU * float(k) / 4.0 + rng.randf() * 1.5
			var out := Vector3(cos(a), 0.0, sin(a))
			var nrm: Vector3 = (out + Vector3.UP * 0.7).normalized()
			var t1 := Vector3(-out.z, 0.0, out.x)
			lb = _card(leaf_st, lb, pc + out * pr * 0.55 - Vector3(0.0, 0.1, 0.0), t1, nrm.cross(t1), pr * 0.6, pr * 0.5, CELL_MATSU, tint, crown, rng.randf_range(0.9, 1.0), rng.randf() < 0.5)
	return _commit(st, leaf_st, bark_mat, leaf_mat)


func _tsutsuji_mesh(variant: int, lod: int, bark_mat: Material, leaf_mat: Material) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 29123 + variant * 167
	var hgt: float = rng.randf_range(1.1, 1.5)
	var r: float = hgt * rng.randf_range(0.8, 1.0)
	var cell: int = CELL_TSUTSUJI_PINK if variant % 2 == 0 else CELL_TSUTSUJI_WHITE
	var bark: Color = BARKS["momiji"][5]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_st := SurfaceTool.new()
	leaf_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bi := 0
	var lb := 0
	var crown := Crown.new()
	crown.c = Vector3(0.0, hgt * 0.3, 0.0)
	crown.r = r
	crown.under = 0.0
	crown.top = hgt
	crown.lift = 0.5
	crown.floor_shade = 0.55
	crown.axis_shade = 0.9
	var tint := Color(0.80, 0.80, 0.80)
	for k in range(4 if lod == 0 else 1):
		var a: float = TAU * float(k) / 4.0 + rng.randf()
		var d := Vector3(cos(a), 0.0, sin(a))
		bi = bark_tube(st, bi, [d * 0.06 - Vector3(0.0, 0.25, 0.0), d * r * 0.3 + Vector3(0.0, hgt * 0.4, 0.0), d * r * 0.55 + Vector3(0.0, hgt * 0.7, 0.0)],
				[0.035, 0.025, 0.01], 3, bark, 0.3, Vector2(0.0, hgt))
	var n: int = 44 if lod == 0 else 8
	var size: Vector2 = Vector2(0.62, 0.85) * hgt if lod == 0 else Vector2(1.2, 1.5) * hgt
	for k in range(n):
		# Spread evenly over the dome.
		var y: float = 1.0 - (float(k) + 0.5) / float(n) * 0.98
		var a2: float = float(k) * 2.39996 + rng.randf_range(-0.2, 0.2)
		var rad: float = sqrt(maxf(1.0 - y * y, 0.0))
		var nrm := Vector3(cos(a2) * rad, y, sin(a2) * rad)
		var p := Vector3(nrm.x * r, nrm.y * hgt, nrm.z * r) * (0.86 if lod == 0 else 0.7)
		nrm = (nrm + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0.0, 0.3), rng.randf_range(-0.3, 0.3))).normalized()
		var t1: Vector3 = nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized().rotated(nrm, rng.randf() * TAU)
		var hs: float = rng.randf_range(size.x, size.y) * 0.5
		lb = _card(leaf_st, lb, p, t1, nrm.cross(t1), hs, hs, cell, tint, crown, rng.randf_range(0.94, 1.05), rng.randf() < 0.5)
	return _commit(st, leaf_st, bark_mat, leaf_mat)
