extends RefCounted
## Date palms (Phoenix dactylifera) for the Al-Raihana GP's oases and gardens, built the way Bloombay Dunes
## builds its coconut palms (palm_trunk.gdshader, palm_fronds.gdshader: a tube for the trunk, two leaflet
## cards in a V per frond), but a different tree:
##   - an upright, thick trunk clad in the stubs of old frond bases (the boot runs a long way down), with
##     offshoots (suckers) round the foot of some;
##   - a dense, rounded crown of stiff fronds that arch up and out, the youngest standing straight up, the
##     oldest held out level, a skirt of dead grey-brown fronds hanging under them on unpruned trees;
##   - blue-grey green leaflets, narrow and stiff, set at a sharp angle (the atlas), spines near the base;
##   - bunches of dates (amber, orange or red) hanging on long strands from inside the crown.
## `mesh(variant, lod)` is a palm whose foot is at the origin; surfaces: trunk, fronds, dates (lod 0).

## Trunk height, its lean, the frond count and length, date bunches, dead fronds hanging, offshoots.
const SHAPES := [
	{"h": 9.5, "lean": 0.05, "fronds": 34, "len": 4.4, "bunches": 5, "dead": 6, "suckers": 0},
	{"h": 12.5, "lean": 0.09, "fronds": 32, "len": 4.6, "bunches": 4, "dead": 2, "suckers": 0},
	{"h": 6.5, "lean": 0.12, "fronds": 30, "len": 4.1, "bunches": 6, "dead": 8, "suckers": 2},
	{"h": 15.0, "lean": 0.04, "fronds": 30, "len": 4.5, "bunches": 3, "dead": 0, "suckers": 0},
	{"h": 3.2, "lean": 0.18, "fronds": 26, "len": 3.6, "bunches": 0, "dead": 5, "suckers": 3},
]
const FROND_ROWS := 4           # atlas rows: two greens, a younger one and a dead frond
## Near and far crossfade (tree_lod.gdshaderinc), as Bloombay's palms.
const NEAR := 170.0
const FADE := 50.0
const FADE_JITTER := 15.0

var save_res: Callable          # (res, name) -> saved resource, set by the generator
var _frond_tex: Texture2D


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
		for y in range(maxi(0, int(c.y - r - 1.0)), mini(w - 1, int(c.y + r + 1.0)) + 1):
			for x in range(maxi(0, int(c.x - r - 1.0)), mini(w - 1, int(c.x + r + 1.0)) + 1):
				var a: float = clampf(r + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(c), 0.0, 1.0)
				if a > 0.0:
					_put(y * w + x, a, col)

	func line(a: Vector2, b: Vector2, r: float, r2: float, col: Color) -> void:
		var n: int = maxi(1, int(a.distance_to(b) / 0.7))
		for k in range(n + 1):
			var t: float = float(k) / float(n)
			dot(a.lerp(b, t), lerpf(r, r2, t), col)

	## A narrow, stiff leaflet: almost parallel sided, folded (lighter along the fold), to a sharp point.
	func leaflet(base: Vector2, dir: Vector2, length: float, width: float, col: Color, tip: Color) -> void:
		var d: Vector2 = dir.normalized()
		var perp := Vector2(-d.y, d.x)
		var lo := Vector2(minf(base.x, base.x + d.x * length) - width - 2.0, minf(base.y, base.y + d.y * length) - width - 2.0)
		var hi := Vector2(maxf(base.x, base.x + d.x * length) + width + 2.0, maxf(base.y, base.y + d.y * length) + width + 2.0)
		for y in range(maxi(0, int(lo.y)), mini(w - 1, int(hi.y)) + 1):
			for x in range(maxi(0, int(lo.x)), mini(w - 1, int(hi.x)) + 1):
				var q := Vector2(x + 0.5, y + 0.5) - base
				var along: float = q.dot(d) / length
				if along < 0.0 or along > 1.0:
					continue
				var across: float = q.dot(perp)
				var half: float = width * minf(1.0, along * 8.0) * (1.0 - smoothstep(0.6, 1.0, along))
				var a: float = clampf(half - absf(across) + 0.5, 0.0, 1.0)
				if a <= 0.0:
					continue
				var c: Color = col.lerp(tip, smoothstep(0.75, 1.0, along))
				# The fold: a lighter line down the middle, the far half a shade darker.
				c = c.lightened(0.18 * clampf(1.0 - absf(across) / maxf(width * 0.25, 0.5), 0.0, 1.0))
				if across > 0.0:
					c = c.darkened(0.08)
				_put(y * w + x, a, c)


## Mipmaps that keep level 0's alpha coverage (as Bloombay's palms, so fronds don't thin out far off).
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


## The frond atlas: each row one side of a frond, base at the left, tip at the right, the midrib along the
## row's top, the leaflets stiff and steep (a date palm's are set at 30-45 degrees, not swept back), short
## spines in place of leaflets over the first fifth.
func frond_texture() -> Texture2D:
	if _frond_tex:
		return _frond_tex
	const W := 1024
	const ROW := 256
	var cv := LeafCanvas.new(W, Color(0.36, 0.46, 0.36))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var greens := [[Color(0.30, 0.42, 0.33), Color(0.40, 0.50, 0.38)], [Color(0.34, 0.45, 0.32), Color(0.45, 0.53, 0.37)],
			[Color(0.40, 0.52, 0.30), Color(0.50, 0.58, 0.34)]]
	for row in range(FROND_ROWS):
		var dead := row == FROND_ROWS - 1
		var y0: float = float(row * ROW) + 5.0
		var n := 64
		for k in range(n):
			if rng.randf() < (0.3 if dead else 0.03):
				continue
			var u: float = lerpf(0.05, 0.97, float(k) / float(n - 1)) + rng.randf_range(-0.003, 0.003)
			var base := Vector2(u * W, y0)
			if u < 0.2:
				# Spines: short, stiff and pale.
				var sd := Vector2(cos(deg_to_rad(52.0)), sin(deg_to_rad(52.0)))
				cv.line(base, base + sd * rng.randf_range(26.0, 40.0), 2.0, 0.4, Color(0.70, 0.64, 0.44) if not dead else Color(0.52, 0.44, 0.32))
				continue
			var s: float = (u - 0.2) / 0.77
			var prof: float = (0.5 + 0.5 * smoothstep(0.0, 0.25, s)) * (1.0 - 0.6 * smoothstep(0.55, 1.0, s))
			var ang: float = deg_to_rad(lerpf(42.0, 30.0, s) + rng.randf_range(-4.0, 4.0) + (18.0 if dead else 0.0))
			var dir := Vector2(cos(ang), sin(ang))
			var length: float = minf((ROW - 14.0) * prof / dir.y, (W - 6.0 - base.x) / dir.x) * rng.randf_range(0.9, 1.0)
			if length < 12.0:
				continue
			var col: Color
			var tip: Color
			if dead:
				col = Color(0.52, 0.44, 0.33).lerp(Color(0.62, 0.56, 0.44), rng.randf())
				tip = col.darkened(0.15)
			else:
				var pair: Array = greens[row]
				col = (pair[0] as Color).lerp(pair[1], rng.randf())
				tip = col.lerp(Color(0.66, 0.60, 0.40), 0.55) if rng.randf() < 0.25 else col.lightened(0.05)
			cv.leaflet(base, dir, length, 3.4 + rng.randf() * 0.8, col, tip)
		var rib := Color(0.55, 0.47, 0.34) if dead else Color(0.66, 0.64, 0.44)
		cv.line(Vector2(0.0, y0 - 1.0), Vector2(W - 6.0, y0 - 1.0), 4.0, 1.4, rib)
	var img := _coverage_mipmaps(cv, 0.5)
	var tex := ImageTexture.create_from_image(img)
	_frond_tex = save_res.call(tex, "datepalm_fronds") if save_res.is_valid() else tex
	return _frond_tex


## [trunk, fronds, dates] materials; lod_mode 0 none, 1 the near palm, 2 the far stand-in.
func materials(lod_mode: int) -> Array:
	var trunk := ShaderMaterial.new()
	trunk.shader = load("res://palm_trunk.gdshader")
	trunk.set_shader_parameter("bark_color", Color(0.47, 0.37, 0.27))
	trunk.set_shader_parameter("ring_color", Color(0.27, 0.20, 0.14))
	trunk.set_shader_parameter("boot_color", Color(0.42, 0.31, 0.20))
	trunk.set_shader_parameter("ring_spacing", 0.32)
	var fronds := ShaderMaterial.new()
	fronds.shader = load("res://palm_fronds.gdshader")
	fronds.set_shader_parameter("frond_tex", frond_texture())
	fronds.set_shader_parameter("backlight_color", Color(0.55, 0.62, 0.36))
	fronds.set_shader_parameter("flutter", 0.12)
	for m in [trunk, fronds]:
		m.set_shader_parameter("lod_mode", lod_mode)
		m.set_shader_parameter("lod_fade_begin", NEAR - FADE * 0.5)
		m.set_shader_parameter("lod_fade_end", NEAR + FADE * 0.5)
		m.set_shader_parameter("lod_jitter", FADE_JITTER)
	var dates := StandardMaterial3D.new()
	dates.vertex_color_use_as_albedo = true
	dates.vertex_color_is_srgb = true
	dates.roughness = 0.5
	return [trunk, fronds, dates]


static func _pv(st: SurfaceTool, c: Array) -> void:
	st.set_normal(c[1])
	st.set_uv(c[2])
	st.set_uv2(c[3])
	st.set_color(c[4])
	st.add_vertex(c[0])


static func _pquad(st: SurfaceTool, c: Array) -> void:
	var n: Vector3 = (c[0][1] as Vector3) + c[1][1] + c[2][1] + c[3][1]
	var order := [0, 1, 2, 0, 2, 3]
	if ((c[2][0] as Vector3) - c[0][0]).cross((c[1][0] as Vector3) - c[0][0]).dot(n) < 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		_pv(st, c[i])


## A tube along `pts`: UV.x round it, UV.y metres up; COLOR rgb tint, a the boot (frond-base stubs).
static func _tube(st: SurfaceTool, pts: Array, radii: Array, boot: Array, sides: int, tint: Color, lumps := 0.0) -> void:
	var lens: Array = [0.0]
	for k in range(1, pts.size()):
		lens.append(float(lens[k - 1]) + (pts[k] as Vector3).distance_to(pts[k - 1]))
	var rings: Array = []
	var side := Vector3.FORWARD
	for k in range(pts.size()):
		var tan: Vector3 = ((pts[mini(k + 1, pts.size() - 1)] as Vector3) - pts[maxi(k - 1, 0)]).normalized()
		side = (side - tan * side.dot(tan)).normalized()
		var up := tan.cross(side)
		var ring: Array = []
		for j in range(sides + 1):
			var a: float = TAU * float(j) / float(sides)
			var n: Vector3 = side * cos(a) + up * sin(a)
			# The stubs of old frond bases make the clad trunk knobbly: a little in and out round it.
			var r: float = float(radii[k]) * (1.0 + lumps * float(boot[k]) * sin(a * 5.0 + float(k) * 2.1) * 0.12)
			ring.append([(pts[k] as Vector3) + n * r, n, Vector2(float(j) / float(sides), lens[k]), Vector2.ZERO, Color(tint.r, tint.g, tint.b, boot[k])])
		rings.append(ring)
	for k in range(pts.size() - 1):
		for j in range(sides):
			_pquad(st, [rings[k][j], rings[k][j + 1], rings[k + 1][j + 1], rings[k + 1][j]])


## A frond (the leaflet cards hung from the midrib in a V), as Bloombay's `_palm_frond`: `az` round the
## trunk, `elev` at the root, `bend` how far it arches down by the tip, `keel` how far the leaflets hang.
static func _frond(st: SurfaceTool, root: Vector3, az: float, elev: float, bend: float, length: float, width: float,
		keel: float, twist: float, segs: int, row: int, tint: Color, phase: float) -> void:
	var horiz := Vector3(cos(az), 0.0, sin(az))
	var s0 := Vector3(-horiz.z, 0.0, horiz.x)
	var pts: Array = [root]
	var p := root
	for k in range(segs):
		var t: float = (float(k) + 0.5) / float(segs)
		var e: float = elev - bend * pow(t, 1.8)
		p += (horiz * cos(e) + Vector3.UP * sin(e)) * (length / float(segs))
		pts.append(p)
	var v0: float = (float(row) + 0.01) / float(FROND_ROWS)
	var v1: float = (float(row) + 0.99) / float(FROND_ROWS)
	var rows: Array = []
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		var tan: Vector3 = ((pts[mini(k + 1, segs)] as Vector3) - pts[maxi(k - 1, 0)]).normalized()
		var up: Vector3 = tan.cross(s0).normalized()
		if up.y < 0.0:
			up = -up
		var roll: float = twist * t
		var sd: Vector3 = s0 * cos(roll) + up * sin(roll)
		var ud: Vector3 = up * cos(roll) - s0 * sin(roll)
		var hang: float = keel * (0.7 + 0.3 * t)
		var shade: float = lerpf(0.5, 1.0, sqrt(t))
		var col := Color(tint.r, tint.g, tint.b, shade)
		var u: float = lerpf(0.004, 0.996, t)
		var pair: Array = []
		for sgn in [-1.0, 1.0]:
			var d: Vector3 = sd * sgn * cos(hang) - ud * sin(hang)
			var n: Vector3 = d.cross(tan).normalized()
			if n.dot(ud) < 0.0:
				n = -n
			n = (n + Vector3.UP * 0.25).normalized()
			pair.append([[pts[k], n, Vector2(u, v0), Vector2(t, phase), col], [(pts[k] as Vector3) + d * width, n, Vector2(u, v1), Vector2(t, phase), col]])
		rows.append(pair)
	for k in range(segs):
		for s in range(2):
			_pquad(st, [rows[k][s][0], rows[k][s][1], rows[k + 1][s][1], rows[k + 1][s][0]])


## A rough ball (a date, or a bunch's core).
static func _ball(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, lat := 3, lon := 5) -> void:
	var ring: Array = []
	for i in range(lat + 1):
		var row: Array = []
		var th: float = PI * float(i) / float(lat)
		for j in range(lon + 1):
			var ph: float = TAU * float(j) / float(lon)
			var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			row.append([c + n * r, n, Vector2.ZERO, Vector2.ZERO, col])
		ring.append(row)
	for i in range(lat):
		for j in range(lon):
			_pquad(st, [ring[i][j], ring[i][j + 1], ring[i + 1][j + 1], ring[i + 1][j]])


## Palm `variant` with its foot at the origin, leaning toward +x. `lod` 1 is the far stand-in.
func mesh(variant: int, lod: int, mats: Array) -> ArrayMesh:
	var sh: Dictionary = SHAPES[variant % SHAPES.size()]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9101 + variant * 53
	var h: float = sh["h"]
	var lean: float = sh["lean"]
	var tint := Color(rng.randf_range(0.94, 1.04), rng.randf_range(0.95, 1.02), rng.randf_range(0.92, 1.0))
	var segs: int = 10 if lod == 0 else 4
	var pts: Array = [Vector3(0.0, -0.6, 0.0)]
	var radii: Array = [0.5]
	var boot: Array = [0.15]
	var p := Vector3.ZERO
	# Unpruned trunks are clad in frond-base stubs a long way down; pruned ones only near the crown.
	var clad_from: float = 0.15 if int(sh["dead"]) >= 5 else 0.6
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		if k > 0:
			var th: float = lean * (1.0 - 0.5 * t)
			p += Vector3(sin(th), cos(th), 0.0) * (h / float(segs))
		pts.append(p + Vector3(0.0, 0.0, sin(t * 3.0 + rng.randf()) * 0.05 * t))
		radii.append(0.36 * (1.0 - 0.12 * t) + 0.14 * (1.0 - smoothstep(0.0, 0.08, t)))
		boot.append(smoothstep(clad_from, clad_from + 0.15, t) * 0.85 + 0.15)
	var top: Vector3 = pts[pts.size() - 1]
	var tdir: Vector3 = (top - (pts[pts.size() - 2] as Vector3)).normalized()
	for b in [[0.4, 0.42], [0.8, 0.36], [1.1, 0.2]]:
		pts.append(top + tdir * float(b[0]))
		radii.append(b[1])
		boot.append(1.0)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(st, pts, radii, boot, 10 if lod == 0 else 5, tint, 1.0 if lod == 0 else 0.0)
	# Offshoots at the foot: small palms of their own, a trunk stub and a fan of fronds.
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(int(sh["suckers"])):
		var a: float = rng.randf_range(0.0, TAU)
		var sp := Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.7, 1.1)
		var sh_h: float = rng.randf_range(0.5, 1.2)
		if lod == 0:
			_tube(st, [sp - Vector3(0, 0.3, 0), sp + Vector3(cos(a), 4.0, sin(a)) * (sh_h / 4.0)], [0.22, 0.17], [1.0, 1.0], 6, tint)
		var sc: Vector3 = sp + Vector3(cos(a) * 0.1, sh_h, sin(a) * 0.1)
		var nf: int = 10 if lod == 0 else 5
		for f in range(nf):
			var faz: float = float(f) * 2.39996 + a
			_frond(st2, sc, faz, rng.randf_range(0.5, 1.3), 0.5, rng.randf_range(1.6, 2.4), 0.45, 0.85, 0.0, 4 if lod == 0 else 2,
					rng.randi() % 3, tint, rng.randf())
	var crown: Vector3 = top + tdir * 0.9
	var n: int = sh["fronds"]
	var dead: int = sh["dead"]
	var total: int = n + dead
	for i in range(total):
		var is_dead: bool = i >= n
		var age: float = float(i) / float(maxi(n - 1, 1)) if not is_dead else 1.0
		var az: float = float(i) * 2.39996 + rng.randf_range(-0.15, 0.15)
		var flen: float = float(sh["len"]) * lerpf(0.7, 1.0, smoothstep(0.0, 0.3, age)) * rng.randf_range(0.92, 1.06)
		# Stiff: the young stand near upright, the old held out level, little droop at the tips.
		var elev: float = lerpf(1.25, 0.05, age) + rng.randf_range(-0.1, 0.1)
		var bend: float = lerpf(0.25, 0.75, age) + rng.randf_range(-0.1, 0.1)
		var twist: float = rng.randf_range(-0.25, 0.25)
		var phase: float = rng.randf()
		var row: int = rng.randi() % (FROND_ROWS - 1)
		var dead_elev: float = -1.3 + rng.randf_range(-0.12, 0.12)
		if lod == 1 and (i % 3 == 2 or (is_dead and i % 2 == 0)):
			continue
		var keel: float = lerpf(0.45, 0.85, age)
		var width: float = flen * 0.16
		var ftint := tint
		var root: Vector3 = crown + Vector3(cos(az), 0.0, sin(az)) * 0.18 - Vector3(0.0, 0.7 * age, 0.0)
		if is_dead:
			flen *= 0.9
			elev = dead_elev
			bend = 0.1
			keel = 1.0
			row = FROND_ROWS - 1
			ftint = Color(1.0, 1.0, 1.0)
			root = crown - Vector3(0.0, 0.9 + rng.randf() * 0.5, 0.0) + Vector3(cos(az), 0.0, sin(az)) * 0.3
		if lod == 1:
			width *= 1.15
		_frond(st2, root, az, elev, bend, flen, width, keel, twist, 8 if lod == 0 else 3, row, ftint, phase)
	st.index()
	st.commit(mesh)
	mesh.surface_set_material(0, mats[0])
	st2.index()
	st2.commit(mesh)
	mesh.surface_set_material(1, mats[1])
	if lod == 0 and int(sh["bunches"]) > 0:
		var st3 := SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		var ripe: Color = [Color(0.86, 0.58, 0.16), Color(0.78, 0.36, 0.14), Color(0.55, 0.20, 0.12), Color(0.90, 0.72, 0.22)][variant % 4]
		for b in range(int(sh["bunches"])):
			var ba: float = rng.randf_range(0.0, TAU)
			var stalk0: Vector3 = crown + Vector3(cos(ba), 0.0, sin(ba)) * 0.35 - Vector3(0, 0.4, 0)
			var bc: Vector3 = stalk0 + Vector3(cos(ba), 0.0, sin(ba)) * 0.5 - Vector3(0, 0.9, 0)
			# The stalk out of the crown, then the bunch: a core and dates round it.
			_tube(st3, [stalk0, bc + Vector3(0, 0.3, 0)], [0.05, 0.04], [0.0, 0.0], 4, Color(0.80, 0.62, 0.22))
			_ball(st3, bc, Vector3(0.28, 0.42, 0.28), ripe.darkened(0.25), 3, 5)
			for d in range(14):
				var da: float = rng.randf_range(0.0, TAU)
				var dy: float = rng.randf_range(-0.38, 0.3)
				var rr: float = 0.27 * (1.0 - absf(dy) * 0.6)
				_ball(st3, bc + Vector3(cos(da) * rr, dy, sin(da) * rr), Vector3(0.06, 0.09, 0.06), ripe.lerp(ripe.darkened(0.3), rng.randf()), 2, 4)
		st3.index()
		st3.commit(mesh)
		mesh.surface_set_material(2, mats[2])
	return mesh
