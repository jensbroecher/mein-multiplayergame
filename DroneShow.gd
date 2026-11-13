extends Node3D
## A drone light show in the sky (the user's idea, after the drone shows of Chinese cities): `count` drones forming a
## dragon chasing its flaming pearl, a peony, three red lanterns, a pair of koi circling, and the RC Vibe GP logo, one
## after another, flying from each picture to the next.
##
## Everything is built at runtime from a seed (every peer the same), on the wall clock (every LAN peer sees the same
## picture): each formation is `count` points in the show's frame (metres, x right, y up, +z toward the audience, the
## node's -z... see `face`), sorted by x so each drone keeps its place across the picture and the morphs read as
## pictures turning into each other. The points go into two textures (a row per formation) and drone_show.gdshader
## moves every drone on the GPU from INSTANCE_ID and `show_time` (see its header). Nothing is solid.

@export var count := 2000
## Seconds each picture holds, and the flight between pictures.
@export var hold := 14.0
@export var trans := 8.0
## The show's scale (the pictures are drawn about 220m across at 1).
@export var show_scale := 1.0
@export var energy := 3.0
## Holds the show at this many seconds into its cycle (>= 0; previews).
@export var time_override := -1.0

var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _formations := 0

const GOLD := Color(1.0, 0.72, 0.18)
const GOLD_DARK := Color(1.0, 0.45, 0.08)
const CREAM := Color(1.0, 0.92, 0.7)
const RED := Color(1.0, 0.12, 0.08)
const WHITE := Color(0.95, 0.97, 1.0)
const CYAN := Color(0.3, 0.9, 1.0)


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_rng.seed = 8128
	var forms: Array = [_dragon(), _peony(), _lanterns(), _koi(), _logo()]
	_formations = forms.size()
	var pos := Image.create_empty(count, _formations, false, Image.FORMAT_RGBAF)
	var col := Image.create_empty(count, _formations, false, Image.FORMAT_RGBA8)
	for k in range(_formations):
		var f: Array = _fit(forms[k])
		for i in range(count):
			var e: Array = f[i]
			var p: Vector3 = (e[0] as Vector3) * show_scale
			pos.set_pixel(i, k, Color(p.x, p.y, p.z, float(e[2])))
			var c: Color = e[1]
			col.set_pixel(i, k, Color(c.r, c.g, c.b, 1.0))
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://drone_show.gdshader")
	_mat.set_shader_parameter("pos_tex", ImageTexture.create_from_image(pos))
	_mat.set_shader_parameter("col_tex", ImageTexture.create_from_image(col))
	_mat.set_shader_parameter("formations", _formations)
	_mat.set_shader_parameter("hold", hold)
	_mat.set_shader_parameter("trans", trans)
	_mat.set_shader_parameter("energy", energy)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = count
	# Identity transforms, written straight into the buffer (the dummy renderer ignores set_instance_transform).
	var buf := PackedFloat32Array()
	buf.resize(count * 12)
	for i in range(count):
		var o := i * 12
		buf[o] = 1.0
		buf[o + 5] = 1.0
		buf[o + 10] = 1.0
	mm.buffer = buf
	var r: float = 200.0 * show_scale
	mm.custom_aabb = AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Drones"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.set_meta(&"skip_dressing_colliders", true)
	add_child(mmi, false, Node.INTERNAL_MODE_BACK)
	_process(0.0)


func _process(_delta: float) -> void:
	if _mat:
		var cyc: float = (hold + trans) * float(_formations)
		var t: float = time_override if time_override >= 0.0 else float(fposmod(Time.get_unix_time_from_system(), cyc * 40.0))
		_mat.set_shader_parameter("show_time", t)


## Exactly `count` points from a formation's [pos, colour, motion] list: a random sample when there are more, repeats
## (jittered) when fewer; sorted by x so drones keep their place across the pictures.
func _fit(pts: Array) -> Array:
	var out: Array = []
	if pts.size() >= count:
		var idx: Array = range(pts.size())
		for i in range(idx.size() - 1, 0, -1):
			var j: int = _rng.randi_range(0, i)
			var tmp = idx[i]
			idx[i] = idx[j]
			idx[j] = tmp
		for i in range(count):
			out.append(pts[idx[i]])
	else:
		out = pts.duplicate()
		while out.size() < count:
			var e: Array = pts[_rng.randi() % pts.size()]
			out.append([(e[0] as Vector3) + Vector3(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2), 0), e[1], e[2]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).x + (a[0] as Vector3).y * 0.001 < (b[0] as Vector3).x + (b[0] as Vector3).y * 0.001)
	return out


func _line(out: Array, a: Vector3, b: Vector3, n: int, c: Color, w: float) -> void:
	for i in range(n):
		out.append([a.lerp(b, (float(i) + 0.5) / float(n)), c, w])


## Points over an ellipsoid's front half (the side the audience sees), rx, ry, rz.
func _ellipsoid(out: Array, c: Vector3, rx: float, ry: float, rz: float, n: int, col_fn: Callable, w: float) -> void:
	for i in range(n):
		var y: float = 1.0 - 2.0 * (float(i) + 0.5) / float(n)
		var rr: float = sqrt(maxf(1.0 - y * y, 0.0))
		var a: float = float(i) * 2.39996
		var d := Vector3(cos(a) * rr, y, absf(sin(a)) * rr)
		out.append([c + Vector3(d.x * rx, d.y * ry, d.z * rz), col_fn.call(d), w])


# ---- The pictures -------------------------------------------------------------------------------------------------

## A Chinese dragon, gold with a red crest, flying to the right after its flaming pearl; its body waves (motion 0..1).
func _dragon() -> Array:
	var out: Array = []
	var curve := func(t: float) -> Vector3:
		var x: float = lerpf(-115.0, 70.0, t)
		return Vector3(x, 26.0 * sin(t * 2.4 * PI + 0.4) * (0.35 + 0.65 * t) - 5.0, 0.0)
	var stations := 72
	for i in range(stations):
		var t: float = float(i) / float(stations - 1)
		var c: Vector3 = curve.call(t)
		var tg: Vector3 = ((curve.call(minf(t + 0.01, 1.0)) as Vector3) - (curve.call(maxf(t - 0.01, 0.0)) as Vector3)).normalized()
		var nrm := Vector3(-tg.y, tg.x, 0.0)
		var r: float = lerpf(1.6, 8.5, smoothstep(0.0, 0.8, t))
		var ring := 14
		for j in range(ring):
			var a: float = PI * float(j) / float(ring - 1) - PI * 0.5
			var off: Vector3 = nrm * sin(a) * r + Vector3(0, 0, cos(a) * r)
			var col: Color = GOLD if sin(a) > -0.35 else CREAM
			if sin(a) > 0.75:
				col = GOLD_DARK
			out.append([c + off, col, t])
		# The crest along its back.
		if i % 3 == 0 and t < 0.95:
			for s in range(5):
				out.append([c + nrm * (r + float(s) * 1.4) - tg * float(s) * 0.6, RED, t])
	# Four legs with claws.
	for lt in [0.22, 0.38, 0.6, 0.76]:
		var c2: Vector3 = curve.call(lt)
		var r2: float = lerpf(1.6, 8.5, smoothstep(0.0, 0.8, lt))
		var hip := c2 + Vector3(0, -r2 * 0.8, 2.0)
		var knee := hip + Vector3(6.0, -8.0, 1.0)
		var foot := knee + Vector3(-3.0, -6.0, 0.0)
		_line(out, hip, knee, 7, GOLD, lt)
		_line(out, knee, foot, 6, GOLD, lt)
		for cl in [-1.0, 0.0, 1.0]:
			_line(out, foot, foot + Vector3(cl * 2.5 + 1.0, -3.0, 0), 3, RED, lt)
	# The head at the body's end.
	var h: Vector3 = (curve.call(1.0) as Vector3) + Vector3(9.0, 3.0, 0.0)
	var head_col := func(d: Vector3) -> Color: return GOLD if d.y > -0.2 else CREAM
	_ellipsoid(out, h, 13.0, 9.0, 8.0, 230, head_col, 1.0)
	_ellipsoid(out, h + Vector3(13.0, -1.5, 0.0), 9.0, 5.0, 5.0, 120, head_col, 1.0)
	_ellipsoid(out, h + Vector3(11.0, -9.0, 0.0), 8.5, 2.6, 4.0, 70, func(_d: Vector3) -> Color: return RED, 1.0)
	for k in range(8):
		out.append([h + Vector3(6.0 + float(k) * 1.7, -6.0, 3.5), WHITE, 1.0])
	for e in [Vector3(4.0, 4.0, 7.0), Vector3(4.5, 4.4, 7.2), Vector3(3.5, 4.4, 7.2)]:
		out.append([h + e, Color(0.4, 1.0, 0.5), 1.0])
	# Antlers sweeping back, the mane of flame behind the head, whiskers trailing.
	for side in [-1.0, 1.0]:
		var a0 := h + Vector3(-3.0, 8.0, side * 3.0)
		var a1 := a0 + Vector3(-14.0, 12.0, side * 2.0)
		_line(out, a0, a1, 14, CYAN, 1.0)
		_line(out, a0.lerp(a1, 0.5), a0.lerp(a1, 0.5) + Vector3(-2.0, 6.0, 0.0), 5, CYAN, 1.0)
		var wp := h + Vector3(20.0, -2.0, side * 3.0)
		for k2 in range(26):
			var u: float = float(k2) / 25.0
			out.append([wp + Vector3(8.0 * u - 30.0 * u * u, -6.0 * u + 5.0 * sin(u * 7.0) * side, 0.0), WHITE, 1.0])
	for k3 in range(110):
		var u2: float = _rng.randf()
		var ang: float = lerpf(0.6, 2.9, _rng.randf())
		var rad: float = 10.0 + 8.0 * u2
		out.append([h + Vector3(cos(ang) * rad - 6.0, sin(ang) * rad * 0.9, -2.0), Color(1.0, lerpf(0.15, 0.55, u2), 0.05), 1.0])
	# The flaming pearl ahead of its jaws.
	var pearl := h + Vector3(42.0, -2.0, 0.0)
	_ellipsoid(out, pearl, 6.0, 6.0, 6.0, 90, func(_d: Vector3) -> Color: return Color(0.85, 0.95, 1.0), -1.0)
	for k4 in range(40):
		var ang2: float = TAU * float(k4) / 40.0
		var fr: float = 9.0 + 4.0 * absf(sin(ang2 * 3.0))
		out.append([pearl + Vector3(cos(ang2) * fr, sin(ang2) * fr, -1.0), Color(1.0, 0.5, 0.1), -1.0])
	return out


## A peony in full bloom: three layers of ruffled petals, deep magenta at the heart to pink, yellow stamens, leaves.
func _peony() -> Array:
	var out: Array = []
	var c := Vector3(0, 12, 0)
	var layers: Array = [[9, 64.0, 34.0, -8.0, 0.0, Color(1.0, 0.55, 0.78)], [8, 46.0, 28.0, -2.0, 0.35, Color(1.0, 0.32, 0.62)],
		[6, 28.0, 20.0, 4.0, 0.1, Color(0.95, 0.12, 0.48)]]
	for L in layers:
		var n: int = L[0]
		var length: float = L[1]
		var width: float = L[2]
		for p in range(n):
			var th: float = TAU * (float(p) + float(L[4])) / float(n)
			var dir := Vector2(cos(th), sin(th))
			var side := Vector2(-dir.y, dir.x)
			# The petal's edge, a brighter outline (filled only, the petals ran into each other).
			for e in range(28):
				var u: float = float(e) / 27.0
				var ss: float = u * 2.0 if u < 0.5 else (1.0 - u) * 2.0
				var sgn: float = -1.0 if u < 0.5 else 1.0
				var ss2: float = clampf(ss, 0.0, 1.0)
				var hw2: float = width * 0.5 * pow(sin(PI * clampf(ss2 * 0.95 + 0.05, 0.0, 1.0)), 0.6)
				var q3: Vector2 = dir * (ss2 * length) + side * (sgn * hw2)
				out.append([c + Vector3(q3.x, q3.y, float(L[3]) + 10.0 * ss2 * (1.0 - ss2) + 0.5), (L[5] as Color).lerp(WHITE, 0.35), 2.0])
			var pts := 0
			var want: int = int(length * width * 0.03)
			while pts < want:
				var s: float = _rng.randf()
				var v: float = _rng.randf_range(-1.0, 1.0)
				var hw: float = width * 0.5 * pow(sin(PI * clampf(s * 0.95 + 0.05, 0.0, 1.0)), 0.6)
				var ruffle: float = 1.0 + 0.08 * sin(v * 9.0 + float(p))
				if s > ruffle:
					continue
				var q: Vector2 = dir * (s * length) + side * (v * hw)
				var col: Color = (L[5] as Color).lerp(Color(1.0, 0.85, 0.92), s * 0.5)
				out.append([c + Vector3(q.x, q.y, float(L[3]) + 10.0 * s * (1.0 - s)), col, 2.0])
				pts += 1
	for k in range(140):
		var a: float = _rng.randf() * TAU
		var r: float = sqrt(_rng.randf()) * 9.0
		out.append([c + Vector3(cos(a) * r, sin(a) * r, 8.0), Color(1.0, 0.85, 0.15), 2.0])
	# Leaves either side below the bloom and the stem.
	for side in [-1.0, 1.0]:
		var base := c + Vector3(side * 10.0, -50.0, -6.0)
		var dir2 := Vector2(side * 0.9, 0.45).normalized()
		var sd2 := Vector2(-dir2.y, dir2.x)
		for k2 in range(150):
			var s2: float = _rng.randf()
			var v2: float = _rng.randf_range(-1.0, 1.0) * 11.0 * sin(PI * s2)
			var q2: Vector2 = dir2 * (s2 * 46.0) + sd2 * v2
			out.append([base + Vector3(q2.x, q2.y, 0.0), Color(0.2, 0.85, 0.3).lerp(Color(0.6, 1.0, 0.4), s2), 2.0])
	_line(out, c + Vector3(0, -40.0, -6.0), c + Vector3(-4.0, -110.0, -6.0), 50, Color(0.25, 0.8, 0.3), 2.0)
	return out


## Three red lanterns hanging from a gold cord, gold ribs, caps and tassels; they sway (motion 4).
func _lanterns() -> Array:
	var out: Array = []
	var specs: Array = [[-82.0, -8.0, 24.0, 30.0], [0.0, 0.0, 32.0, 40.0], [82.0, -8.0, 24.0, 30.0]]
	for i in range(41):
		var x: float = lerpf(-120.0, 120.0, float(i) / 40.0)
		out.append([Vector3(x, 60.0 - 0.0006 * x * x * 4.0, -2.0), GOLD, 4.0])
	for s in specs:
		var cx: float = s[0]
		var cy: float = s[1]
		var rx: float = s[2]
		var ry: float = s[3]
		_line(out, Vector3(cx, 60.0 - 0.0024 * cx * cx, -2.0), Vector3(cx, cy + ry + 4.0, 0.0), 10, GOLD, 4.0)
		# The body: red filled, brighter toward its middle, with gold ribs down it.
		var n: int = int(rx * ry * 0.75)
		for k in range(n):
			var a: float = _rng.randf() * TAU
			var r: float = sqrt(_rng.randf())
			var px: float = cos(a) * r
			var py: float = sin(a) * r
			var glow: float = 1.0 - r * 0.6
			out.append([Vector3(cx + px * rx, cy + py * ry, sqrt(maxf(1.0 - r * r, 0.0)) * 6.0), Color(1.0, 0.12 + 0.3 * glow, 0.05 + 0.1 * glow), 4.0])
		for rib in [-0.75, -0.4, 0.0, 0.4, 0.75]:
			for k2 in range(18):
				var yy: float = lerpf(-0.95, 0.95, float(k2) / 17.0)
				var xx: float = rib * sqrt(maxf(1.0 - yy * yy, 0.0))
				out.append([Vector3(cx + xx * rx, cy + yy * ry, 7.0), GOLD, 4.0])
		for cap in [ry, -ry]:
			_line(out, Vector3(cx - rx * 0.45, cy + cap, 6.0), Vector3(cx + rx * 0.45, cy + cap, 6.0), 12, GOLD, 4.0)
		for t in range(5):
			var tx: float = cx + float(t - 2) * 2.0
			_line(out, Vector3(tx, cy - ry - 1.0, 5.0), Vector3(tx, cy - ry - 22.0, 5.0), 8, Color(1.0, 0.85, 0.2), 4.0)
	return out


## Two koi circling each other, one orange and white, one white with red, among ripples; they turn (motion 6).
func _koi() -> Array:
	var out: Array = []
	for f in range(2):
		var ang0: float = PI * float(f)
		var body: Array = []
		# A fish along an arc round the middle: its spine follows the circle, head first.
		for k in range(520):
			var s: float = _rng.randf()
			var v: float = _rng.randf_range(-1.0, 1.0)
			var hw: float = 15.0 * pow(sin(PI * clampf(s * 0.9 + 0.08, 0.0, 1.0)), 0.8) * (1.0 - 0.35 * s)
			var ang: float = ang0 + s * 1.5
			var rad: float = 52.0 + v * hw
			var p := Vector3(cos(ang) * rad, sin(ang) * rad, 2.0)
			var patch: float = sin(s * 17.0 + float(f) * 2.0) * cos(v * 3.0 + s * 9.0)
			var col: Color
			if f == 0:
				col = Color(1.0, 0.45, 0.05) if patch > -0.2 else WHITE
			else:
				col = WHITE if patch > 0.25 else RED
			body.append([p, col, 6.0])
		out.append_array(body)
		# The tail fan and the fins.
		for k2 in range(120):
			var u: float = _rng.randf()
			var sp: float = _rng.randf_range(-1.0, 1.0)
			var ang2: float = ang0 + 1.5 + 0.35 * u
			var rad2: float = 52.0 + sp * (4.0 + 18.0 * u)
			out.append([Vector3(cos(ang2) * rad2, sin(ang2) * rad2, 1.0), Color(1.0, 0.6, 0.3) if f == 0 else Color(1.0, 0.75, 0.75), 6.0])
		for side in [-1.0, 1.0]:
			for k3 in range(30):
				var u3: float = _rng.randf()
				var ang3: float = ang0 + 0.45 + 0.15 * u3
				var rad3: float = 52.0 + side * (14.0 + 9.0 * u3)
				out.append([Vector3(cos(ang3) * rad3, sin(ang3) * rad3, 1.0), Color(1.0, 0.7, 0.4), 6.0])
		for e in [-1.0, 1.0]:
			var ang4: float = ang0 + 0.1
			out.append([Vector3(cos(ang4) * (52.0 + e * 6.0), sin(ang4) * (52.0 + e * 6.0), 4.0), Color(0.2, 0.4, 1.0), 6.0])
	for ring in [[88.0, 160], [104.0, 180], [22.0, 70]]:
		var rr: float = ring[0]
		for k5 in range(int(ring[1])):
			var a5: float = TAU * float(k5) / float(ring[1])
			out.append([Vector3(cos(a5) * rr, sin(a5) * rr, -4.0), Color(0.2, 0.55, 1.0), 6.0])
	return out


## The RC Vibe GP logo, its own colours, from images/logo_transparent.png.
func _logo() -> Array:
	var out: Array = []
	var tex: Texture2D = load("res://images/logo_transparent.png")
	if tex == null:
		return _peony()
	var img: Image = tex.get_image()
	if img == null:
		return _peony()
	if img.is_compressed():
		img.decompress()
	var w: int = img.get_width()
	var h: int = img.get_height()
	var width_m := 230.0
	var sc: float = width_m / float(w)
	# On a regular grid, like a dot-matrix sign (scattered at random the letters didn't read), only where the logo is
	# bright (its letters and swoosh; the navy body is left dark): the grid step is found so about `count` cells light.
	var lit := func(x: int, y: int) -> bool:
		var c: Color = img.get_pixel(x, y)
		return c.a > 0.6 and c.get_luminance() > 0.28
	var lo := 1.0
	var hi := float(w) / 20.0
	var step := 4.0
	for it in range(14):
		step = (lo + hi) * 0.5
		var n := 0
		var yy := 0.0
		while yy < float(h):
			var xx := 0.0
			while xx < float(w):
				if lit.call(int(xx), int(yy)):
					n += 1
				xx += step
			yy += step
		if n > count:
			lo = step
		else:
			hi = step
	step = hi
	var y2 := step * 0.5
	while y2 < float(h):
		var x2 := step * 0.5
		while x2 < float(w):
			if lit.call(int(x2), int(y2)):
				var col: Color = img.get_pixel(int(x2), int(y2))
				col.a = 1.0
				out.append([Vector3((x2 - float(w) * 0.5) * sc, (float(h) * 0.5 - y2) * sc, 0.0), col, -1.0])
			x2 += step
		y2 += step
	return out
