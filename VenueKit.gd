extends RefCounted
## The Lakeside Course's farm and fair props, built in code at life size through a PropKit (front toward
## -z, y up) and placed by regenerate_lakeside.gd at PROP_SCALE: a hay cart, a stack of felled logs, a
## woodcutter's log cabin with its woodpile, a pagoda marquee with beer tables, and the
## paddock's display tables. The cart, the logs and the marquee replaced three Hunyuan FBX that stood two
## to three times too big (the cart tipped up on its tail as the old shortcut's ramp).
##
## Material keys (the generator's _material): "timber" sawn wood (hut_wood.gdshader style 2: the grain
## along UV.y, UVs in metres, the vertex colour the tint), "lapboards" (style 1: lapped boards along UV.x,
## the roof's shakes), "battens" (style 0: upright boards, the gables and doors), "painted" (style 3:
## shutters), "endgrain" (vertex colour: the rings on a cut log), "iron", "stone", "canvas", "metal",
## "gloss" (window panes: opaque, the cabin has no inside). Round logs aren't PropKit's: their bark (and
## the cabin's debarked logs) go on their own SurfaceTools in tree_bark.gdshader's layout
## (WoodlandBuilder.bark_tube), which finish() adds to the mesh.

const PropKit = preload("res://PropKit.gd")
const Woodland = preload("res://WoodlandBuilder.gd")

var _kit: PropKit
var _bark := SurfaceTool.new()
var _bark_base := 0
var _logwall := SurfaceTool.new()
var _logwall_base := 0
## Materials for the two log surfaces, set by the generator.
var bark_material: Material
var logwall_material: Material


func _init(kit: PropKit) -> void:
	_kit = kit
	_reset_logs()


func _reset_logs() -> void:
	_bark = SurfaceTool.new()
	_bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	_bark_base = 0
	_logwall = SurfaceTool.new()
	_logwall.begin(Mesh.PRIMITIVE_TRIANGLES)
	_logwall_base = 0


## Commits `kit` and the log surfaces built since the last finish() into one mesh.
func finish(kit: Dictionary) -> ArrayMesh:
	var mesh := _kit.commit(kit)
	if _bark_base > 0:
		_bark.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, bark_material)
	if _logwall_base > 0:
		_logwall.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, logwall_material)
	_reset_logs()
	return mesh


# ======================================================================================
#  Parts
# ======================================================================================

## A sawn timber from `a` to `b`, `w` wide (along `side`, or any horizontal) and `t` thick, with UVs in
## metres and the grain along v on its long faces; each piece starts the grain somewhere else.
func timber(kit: Dictionary, a: Vector3, b: Vector3, w: float, t: float, col: Color, side := Vector3.ZERO, key := "timber") -> void:
	var ax := b - a
	var length := ax.length()
	if length < 1e-4:
		return
	var z := ax / length
	var x := side
	if x.length_squared() < 1e-8 or absf(x.normalized().dot(z)) > 0.99:
		x = Vector3.UP.cross(z)
		if x.length_squared() < 1e-6:
			x = Vector3.RIGHT
	x = (x - z * x.dot(z)).normalized()
	var y := z.cross(x).normalized()
	var hx := x * (w * 0.5)
	var hy := y * (t * 0.5)
	var u0 := fposmod(a.x * 3.1 + a.z * 1.7 + a.y * 2.3, 5.0)
	var v0 := fposmod(a.x * 1.3 - a.z * 2.9 + a.y * 0.7, 7.0)
	for f in [[y, hy, hx, w], [-y, -hy, -hx, w], [x, hx, -hy, t], [-x, -hx, hy, t]]:
		var c: Vector3 = f[1]
		var e: Vector3 = f[2]
		var wd: float = f[3]
		_kit.quad(kit, key, [a + c - e, b + c - e, b + c + e, a + c + e], f[0], col,
				[Vector2(u0, v0), Vector2(u0, v0 + length), Vector2(u0 + wd, v0 + length), Vector2(u0 + wd, v0)])
	var end_col := col.darkened(0.15)
	for e2 in [[a, -z], [b, z]]:
		var c2: Vector3 = e2[0]
		_kit.quad(kit, key, [c2 - hx - hy, c2 + hx - hy, c2 + hx + hy, c2 - hx + hy], e2[1], end_col,
				[Vector2(u0, v0), Vector2(u0 + w, v0), Vector2(u0 + w, v0 + 0.02), Vector2(u0, v0 + 0.02)])


## A flat panel of boards in the plane of `p` (four corners, in order round its edge) facing `n`, UVs in
## metres from `u_dir` (along the boards for "lapboards", across them for "battens").
func boards(kit: Dictionary, key: String, p: Array, n: Vector3, u_dir: Vector3, col: Color) -> void:
	var v_dir := n.cross(u_dir).normalized()
	var uv: Array = []
	for q in p:
		uv.append(Vector2((q as Vector3).dot(u_dir), (q as Vector3).dot(v_dir)))
	_kit.quad(kit, key, p, n, col, uv)


## A round log from `a` to `b`, radius `ra` to `rb`: bark (or, `debarked`, the cabin's weathered logs)
## round it, and cut ends showing the rings unless `caps` is false.
func round_log(kit: Dictionary, a: Vector3, b: Vector3, ra: float, rb: float, tint: Color, debarked := false, caps := true, sides := 10) -> void:
	var xf: Transform3D = _kit.xf
	var s: float = xf.basis.x.length()
	var pts: Array = []
	var radii: Array = []
	for i in range(5):
		var t := i / 4.0
		pts.append(xf * a.lerp(b, t))
		# A log isn't a perfect cone: a little swelling and a flat side.
		radii.append(lerpf(ra, rb, t) * s * (1.0 + 0.035 * sin(t * 7.0 + a.x * 3.0)))
	if debarked:
		_logwall_base = Woodland.bark_tube(_logwall, _logwall_base, pts, radii, sides, tint, 0.16 * s, Vector2(1e5, 1e5 + 1.0))
	else:
		_bark_base = Woodland.bark_tube(_bark, _bark_base, pts, radii, sides, tint, 0.11 * s, Vector2(1e5, 1e5 + 1.0))
	if caps:
		var d := (b - a).normalized()
		end_grain(kit, a, -d, ra, debarked)
		end_grain(kit, b, d, rb, debarked)


## The cut end of a log at `c` facing `n`: bark, pale sapwood, the warmer heartwood and the pith.
func end_grain(kit: Dictionary, c: Vector3, n: Vector3, r: float, weathered := false) -> void:
	var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var ab := Basis(side, n, side.cross(n))
	var rings := [[1.0, 0.92, Color(0.30, 0.22, 0.15)], [0.92, 0.70, Color(0.86, 0.74, 0.55)],
			[0.70, 0.45, Color(0.78, 0.62, 0.42)], [0.45, 0.14, Color(0.72, 0.55, 0.36)], [0.14, 0.0, Color(0.55, 0.40, 0.26)]]
	for ring in rings:
		var col: Color = ring[2]
		if weathered:
			col = col.lerp(Color(0.52, 0.48, 0.43), 0.55)
		_kit.lathe(kit, "endgrain", c + n * 0.002, [Vector2(r * float(ring[0]), 0.0), Vector2(r * float(ring[1]), 0.0)], 12, col, false, ab)


## A spoked cartwheel at `c` turning about local x, radius `r`.
func cartwheel(kit: Dictionary, c: Vector3, r: float, wood: Color, iron: Color) -> void:
	var ab := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
	_kit.tyre(kit, "iron", c, r - 0.04, r, 0.085, 30, iron, ab)
	var rf := r - 0.075
	var n := 12
	for i in range(n):
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		timber(kit, c + Vector3(0, sin(a0), cos(a0)) * rf, c + Vector3(0, sin(a1), cos(a1)) * rf, 0.075, 0.07, wood, Vector3.RIGHT)
		var am := (a0 + a1) * 0.5
		var dir := Vector3(0, sin(am), cos(am))
		timber(kit, c + dir * 0.1, c + dir * (rf - 0.03), 0.045, 0.034, wood.darkened(0.05), Vector3.RIGHT)
	_kit.lathe(kit, "endgrain", c, [Vector2(0.0, -0.17), Vector2(0.075, -0.17), Vector2(0.11, -0.11), Vector2(0.125, -0.04),
			Vector2(0.125, 0.04), Vector2(0.11, 0.11), Vector2(0.075, 0.17), Vector2(0.0, 0.17)], 12, wood.darkened(0.2), false, ab)
	for hx in [-0.1, 0.1]:
		_kit.tyre(kit, "iron", c + Vector3(hx, 0, 0), 0.105, 0.128, 0.03, 14, iron, ab)
	_kit.lathe(kit, "iron", c + Vector3(0.17, 0, 0), [Vector2(0.05, 0.0), Vector2(0.045, 0.04), Vector2(0.0, 0.05)], 10, iron, false, Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)))


# ======================================================================================
#  The hay cart
# ======================================================================================

## A two-wheeled farm cart, its shafts resting on the ground toward -z: a plank bed on sills and bearers,
## ladder sides, a head- and tailboard, spoked wheels with iron tyres. About 4.7 x 1.9m.
func hay_cart(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.56, 0.44, 0.32)
	var dark := Color(0.42, 0.32, 0.23)
	var iron := Color(0.16, 0.15, 0.15)
	var red := Color(0.52, 0.17, 0.12)
	var bed_y := 1.0
	var hl := 1.3
	var hw := 0.7
	# Floor planks along the cart.
	var np := 7
	for i in range(np):
		var x := -hw + (2.0 * hw) * (i + 0.5) / np
		var tint := wood.lerp(dark, rng.randf() * 0.5)
		timber(kit, Vector3(x, bed_y - 0.02, -hl), Vector3(x, bed_y - 0.02, hl), 2.0 * hw / np - 0.012, 0.04, tint)
	# Sills under the floor, and bearers across them.
	for sx in [-1.0, 1.0]:
		timber(kit, Vector3(sx * 0.55, bed_y - 0.1, -hl - 0.05), Vector3(sx * 0.55, bed_y - 0.1, hl + 0.05), 0.1, 0.12, dark)
	for z in [-1.1, -0.35, 0.4, 1.15]:
		timber(kit, Vector3(-0.72, bed_y - 0.2, z), Vector3(0.72, bed_y - 0.2, z), 0.09, 0.08, dark, Vector3.FORWARD)
	# The axle under it on a bolster, and the wheels.
	var wz := 0.25
	var wr := 0.66
	timber(kit, Vector3(-0.92, wr, wz), Vector3(0.92, wr, wz), 0.11, 0.11, dark, Vector3.FORWARD)
	for sx in [-1.0, 1.0]:
		timber(kit, Vector3(sx * 0.55, wr + 0.05, wz), Vector3(sx * 0.55, bed_y - 0.16, wz), 0.12, 0.1, dark, Vector3.FORWARD)
		cartwheel(kit, Vector3(sx * 0.9, wr, wz), wr, red, iron)
	# Ladder sides, leaning out: stakes from the sills up past the bed, two rails along them.
	for sx in [-1.0, 1.0]:
		var lean := Vector3(sx * 0.12, 0.62, 0.0)
		for z in [-1.22, -0.42, 0.42, 1.22]:
			var foot := Vector3(sx * 0.68, bed_y - 0.12, z)
			timber(kit, foot, foot + lean, 0.06, 0.05, dark, Vector3.FORWARD)
		for f in [0.55, 0.95]:
			var a: Vector3 = Vector3(sx * 0.68, bed_y - 0.12, -1.3) + lean * float(f)
			timber(kit, a, a + Vector3(0, 0, 2.6), 0.05, 0.11, wood.lerp(dark, rng.randf() * 0.4), Vector3.UP)
	# Head- and tailboard.
	for z in [-hl, hl]:
		var h := 0.45 if z < 0.0 else 0.32
		for k in range(2):
			var y := bed_y + 0.06 + k * (h * 0.5)
			timber(kit, Vector3(-0.66, y, z), Vector3(0.66, y, z), 0.16 if z < 0.0 else 0.13, 0.04, wood.lerp(dark, rng.randf() * 0.5), Vector3.UP)
	# Shafts out to the front, resting on the ground, a swingletree across them.
	for sx in [-1.0, 1.0]:
		timber(kit, Vector3(sx * 0.5, bed_y - 0.16, -1.0), Vector3(sx * 0.4, 0.05, -3.35), 0.07, 0.07, dark)
	timber(kit, Vector3(-0.5, 0.26, -2.7), Vector3(0.5, 0.24, -2.7), 0.06, 0.06, dark, Vector3.FORWARD)
	# A bale riding on the bed is the generator's (its own shader); a sack and a pitchfork here.
	_kit.box(kit, "canvas", Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.35, bed_y + 0.2, 0.9)), Vector3(0.45, 0.4, 0.32), Color(0.62, 0.55, 0.40))
	timber(kit, Vector3(-0.45, bed_y, 1.25), Vector3(-0.62, bed_y + 1.4, 0.55), 0.03, 0.03, Color(0.60, 0.48, 0.34))
	for t in [-0.06, 0.0, 0.06]:
		var tip := Vector3(-0.62, bed_y + 1.4, 0.55)
		_kit.tube(kit, "iron", tip + Vector3(t, 0, 0), tip + Vector3(t * 1.6, 0.28, -0.12), 0.008, 0.004, 4, iron)


# ======================================================================================
#  The log stack
# ======================================================================================

## Felled trunks cut to 4m, stacked in a pyramid between pairs of stakes driven into the ground, along z.
## About 2.7 x 4.3m, 1.6m high.
## The felled logs' bark tint (times the oak bark's own colour: untinted it read as birch).
const LOG_TINT := Color(0.66, 0.56, 0.46)

func log_stack(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var rows := [5, 4, 3, 2]
	var pitch := 0.44
	var rise := 0.37
	for k in range(rows.size()):
		var n: int = rows[k]
		for i in range(n):
			var r := 0.21 * rng.randf_range(0.85, 1.12)
			var x := (i - (n - 1) * 0.5) * pitch + rng.randf_range(-0.02, 0.02)
			var y := 0.21 + k * rise
			var z0 := -2.0 + rng.randf_range(-0.15, 0.15)
			var z1 := 2.0 + rng.randf_range(-0.15, 0.15)
			var sk := rng.randf_range(-0.05, 0.05)
			round_log(kit, Vector3(x - sk, y, z0), Vector3(x + sk, y, z1), r, r * 0.9, LOG_TINT.darkened(rng.randf() * 0.15))
	var stake := Color(0.40, 0.31, 0.22)
	for sx in [-1.0, 1.0]:
		for z in [-1.5, 1.5]:
			timber(kit, Vector3(sx * 1.25, -0.1, z), Vector3(sx * 1.2, 1.2, z), 0.12, 0.12, stake)


# ======================================================================================
#  The log cabin
# ======================================================================================

const CABIN_HX := 2.5
const CABIN_HZ := 2.0
const CABIN_LOG_R := 0.14
const CABIN_PITCH := 0.26
const CABIN_ROWS := 9
const CABIN_RIDGE := 3.85

## A woodcutter's cabin, 5 x 4m of saddle-notched logs on a stone footing, the door and a window at the
## front (-z), a window at the back and on the left, a stone chimney up the right end, a shake roof
## overhanging all round, shutters, a bench under the front window. The woodpile is woodpile().
func log_cabin(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var hx := CABIN_HX
	var hz := CABIN_HZ
	var rl := CABIN_LOG_R
	var log_tint := Color(0.92, 0.88, 0.82)
	var wood := Color(0.55, 0.43, 0.31)
	var dark := Color(0.38, 0.29, 0.21)
	var green := Color(0.20, 0.36, 0.24)
	var iron := Color(0.12, 0.12, 0.12)
	# Openings: [wall, from, to (along it), bottom, top]. Walls: 0 front (-z), 1 back, 2 left (-x), 3 right.
	var holes := [[0, -0.45, 0.45, 0.0, 1.95], [0, 1.05, 1.85, 0.85, 1.62], [1, -1.6, -0.8, 0.85, 1.62], [2, -0.45, 0.35, 0.85, 1.62]]
	# Stone footing under the walls.
	for w in range(4):
		var along_x: bool = w < 2
		var half: float = (hx if along_x else hz) + 0.12
		var at: float = ((-hz if w == 0 else hz) if along_x else (-hx if w == 2 else hx))
		var x := -half
		while x < half:
			var l := rng.randf_range(0.28, 0.5)
			var x1 := minf(x + l, half)
			var c := Color(0.55, 0.54, 0.50).lerp(Color(0.42, 0.40, 0.37), rng.randf())
			var lo := Vector3(x, 0.0, at - 0.17) if along_x else Vector3(at - 0.17, 0.0, x)
			var hi := Vector3(x1 - 0.02, 0.18 + rng.randf() * 0.05, at + 0.17) if along_x else Vector3(at + 0.17, 0.18 + rng.randf() * 0.05, x1 - 0.02)
			_kit.block(kit, "stone", lo, hi, c)
			x = x1
	# The walls: logs one above the other, the end walls' half a log higher, each running 0.3m past the corners.
	for k in range(CABIN_ROWS):
		for w in range(4):
			var along_x: bool = w < 2
			var y: float = 0.18 + rl + k * CABIN_PITCH + (0.0 if along_x else CABIN_PITCH * 0.5)
			if not along_x and k == CABIN_ROWS - 1:
				continue
			var half: float = (hx if along_x else hz) + 0.3
			var line: float = ((-hz if w == 0 else hz) if along_x else (-hx if w == 2 else hx))
			# The log's pieces between the openings it crosses.
			var cuts: Array = [[-half, half]]
			for hole in holes:
				if int(hole[0]) != w or y + rl * 0.6 < float(hole[3]) or y - rl * 0.6 > float(hole[4]):
					continue
				var next: Array = []
				for c in cuts:
					if float(hole[2]) <= c[0] or float(hole[1]) >= c[1]:
						next.append(c)
						continue
					if float(hole[1]) > c[0]:
						next.append([c[0], float(hole[1])])
					if float(hole[2]) < c[1]:
						next.append([float(hole[2]), c[1]])
				cuts = next
			for c in cuts:
				if float(c[1]) - float(c[0]) < 0.2:
					continue
				var a := Vector3(float(c[0]), y, line) if along_x else Vector3(line, y, float(c[0]))
				var b := Vector3(float(c[1]), y, line) if along_x else Vector3(line, y, float(c[1]))
				var r := rl * rng.randf_range(0.93, 1.07)
				round_log(kit, a, b, r, r * 0.96, log_tint.darkened(rng.randf() * 0.12), true, true, 9)
	var eave := 0.18 + CABIN_ROWS * CABIN_PITCH
	# Frames round the openings: jambs, a sill and a lintel.
	for hole in holes:
		var w: int = hole[0]
		var along_x: bool = w < 2
		var out: float = -1.0 if (w == 0 or w == 2) else 1.0
		var line: float = ((-hz if w == 0 else hz) if along_x else (-hx if w == 2 else hx)) + out * (rl + 0.01)
		var p := func(u: float, y: float) -> Vector3:
			return Vector3(u, y, line) if along_x else Vector3(line, y, u)
		var u0: float = hole[1]
		var u1: float = hole[2]
		var y0: float = maxf(float(hole[3]), 0.18)
		var y1: float = hole[4]
		var nrm := Vector3(0, 0, out) if along_x else Vector3(out, 0, 0)
		var along := Vector3.RIGHT if along_x else Vector3.BACK
		timber(kit, p.call(u0 - 0.06, y0), p.call(u0 - 0.06, y1 + 0.1), 0.12, 0.1, wood, along)
		timber(kit, p.call(u1 + 0.06, y0), p.call(u1 + 0.06, y1 + 0.1), 0.12, 0.1, wood, along)
		timber(kit, p.call(u0 - 0.14, y1 + 0.08), p.call(u1 + 0.14, y1 + 0.08), 0.14, 0.12, dark, Vector3.UP)
		var inset: Vector3 = nrm * -(rl + 0.04)
		if float(hole[3]) > 0.1:
			timber(kit, p.call(u0 - 0.1, y0 - 0.03) + nrm * 0.04, p.call(u1 + 0.1, y0 - 0.03) + nrm * 0.04, 0.16, 0.05, dark, nrm)
			# The pane, opaque: the cabin has no inside to see.
			_kit.quad(kit, "gloss", [p.call(u0, y0) + inset, p.call(u1, y0) + inset, p.call(u1, y1) + inset, p.call(u0, y1) + inset], nrm,
					Color(0.10, 0.13, 0.16))
			var mid_u := (u0 + u1) * 0.5
			var mid_y := (y0 + y1) * 0.5
			timber(kit, p.call(mid_u, y0) + inset * 0.8, p.call(mid_u, y1) + inset * 0.8, 0.04, 0.04, wood, along)
			timber(kit, p.call(u0, mid_y) + inset * 0.8, p.call(u1, mid_y) + inset * 0.8, 0.04, 0.04, wood, Vector3.UP)
			# Shutters, open against the wall either side.
			var sw := (u1 - u0) * 0.5
			for sgn in [-1.0, 1.0]:
				var e: float = u0 - 0.1 if sgn < 0.0 else u1 + 0.1
				var f: float = e + sgn * sw
				var face: Vector3 = nrm * 0.03
				boards(kit, "painted", [p.call(e, y0) + face, p.call(f, y0) + face, p.call(f, y1) + face, p.call(e, y1) + face], nrm, along, green)
		else:
			# The door: upright boards, recessed, a Z of battens and an iron latch.
			var dp: Vector3 = nrm * -0.05
			boards(kit, "battens", [p.call(u0, 0.18) + dp, p.call(u1, 0.18) + dp, p.call(u1, y1) + dp, p.call(u0, y1) + dp], nrm, along, Color(0.50, 0.38, 0.27))
			var bt: Vector3 = nrm * -0.02
			timber(kit, p.call(u0 + 0.05, 0.45) + bt, p.call(u1 - 0.05, 0.45) + bt, 0.1, 0.03, dark, Vector3.UP)
			timber(kit, p.call(u0 + 0.05, 1.6) + bt, p.call(u1 - 0.05, 1.6) + bt, 0.1, 0.03, dark, Vector3.UP)
			timber(kit, p.call(u0 + 0.08, 0.5) + bt, p.call(u1 - 0.08, 1.55) + bt, 0.09, 0.03, dark, nrm.cross(along))
			_kit.block(kit, "iron", p.call(u1 - 0.14, 1.0) + nrm * 0.01 - Vector3(0.02, 0.02, 0.02), p.call(u1 - 0.08, 1.06) + nrm * 0.03 + Vector3(0.02, 0.02, 0.02), iron)
	# Gables: upright boards from the end walls' top log to the ridge (it runs along x), both ends.
	var end_top := eave - CABIN_PITCH * 0.5
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hx + rl * 0.4)
		var n := Vector3(sx, 0, 0)
		var l := Vector3(x, end_top, -hz - 0.05)
		var r := Vector3(x, end_top, hz + 0.05)
		var top := Vector3(x, CABIN_RIDGE, 0.0)
		var ey2 := CABIN_RIDGE - (hz + 0.05) * (CABIN_RIDGE - eave) / hz
		l.y = minf(l.y, ey2)
		r.y = minf(r.y, ey2)
		_kit.tri(kit, "battens", l, r, top, n, n, n, wood, n, Vector2(l.z, l.y), Vector2(r.z, r.y), Vector2(top.z, top.y))
		_kit.tri(kit, "battens", l, top, r, -n, -n, -n, dark, -n, Vector2(l.z, l.y), Vector2(top.z, top.y), Vector2(r.z, r.y))
		# The strip under the gable down to the end wall's top log.
		_kit.quad(kit, "battens", [Vector3(x, end_top - 0.14, -hz - 0.05), Vector3(x, end_top - 0.14, hz + 0.05), r, l], n, wood,
				[Vector2(-hz, end_top - 0.14), Vector2(hz, end_top - 0.14), Vector2(r.z, r.y), Vector2(l.z, l.y)])
	# The roof: shakes in rows down each slope, an overhang all round, fascia boards and a ridge cap.
	var over_z := 0.55
	var over_x := 0.45
	var slope := (CABIN_RIDGE - eave) / hz
	var ez := hz + over_z
	var ey := CABIN_RIDGE - ez * slope
	for sz in [-1.0, 1.0]:
		var n := Vector3(0, 1.0, sz * slope).normalized()
		var r0 := Vector3(-hx - over_x, CABIN_RIDGE + 0.06, 0.0)
		var r1 := Vector3(hx + over_x, CABIN_RIDGE + 0.06, 0.0)
		var e0 := Vector3(-hx - over_x, ey + 0.06, sz * ez)
		var e1 := Vector3(hx + over_x, ey + 0.06, sz * ez)
		boards(kit, "lapboards", [r0, r1, e1, e0], n, Vector3.RIGHT, Color(0.46, 0.38, 0.30))
		var th := Vector3(0, -0.1, 0)
		_kit.quad(kit, "timber", [r0 + th, e0 + th, e1 + th, r1 + th], -n, dark,
				[Vector2(0, 0), Vector2(0, ez * 1.2), Vector2(hx * 2.0 + over_x * 2.0, ez * 1.2), Vector2(hx * 2.0 + over_x * 2.0, 0)])
		timber(kit, e0 + Vector3(0, 0.0, sz * 0.02), e1 + Vector3(0, 0.0, sz * 0.02), 0.16, 0.04, dark, n.cross(Vector3.RIGHT))
		for sx in [-1.0, 1.0]:
			var a := Vector3(sx * (hx + over_x), CABIN_RIDGE + 0.02, 0.0)
			var b := Vector3(sx * (hx + over_x), ey + 0.02, sz * ez)
			timber(kit, a, b, 0.16, 0.04, dark, Vector3(sx, 0, 0).cross(b - a))
	timber(kit, Vector3(-hx - over_x - 0.05, CABIN_RIDGE + 0.1, 0.0), Vector3(hx + over_x + 0.05, CABIN_RIDGE + 0.1, 0.0), 0.2, 0.06, dark, Vector3.BACK)
	# The chimney: rough stones up the right end and out through the roof.
	var cx := hx + 0.42
	var y := 0.0
	var top_y := CABIN_RIDGE + 0.6
	while y < top_y:
		var h := rng.randf_range(0.18, 0.28)
		var narrow: float = 0.0 if y < 1.6 else 0.12
		var zz := -0.45 + narrow
		while zz < 0.45 - narrow:
			var l := rng.randf_range(0.22, 0.42)
			var z1 := minf(zz + l, 0.45 - narrow)
			var c := Color(0.56, 0.55, 0.52).lerp(Color(0.40, 0.38, 0.35), rng.randf())
			_kit.block(kit, "stone", Vector3(cx - 0.36 + narrow, y, zz + 0.5), Vector3(cx + 0.36 - narrow * 0.5 + rng.randf() * 0.03, y + h - 0.015, z1 + 0.5 - 0.015), c)
			zz = z1
		y += h
	_kit.block(kit, "stone", Vector3(cx - 0.3, top_y, 0.12), Vector3(cx + 0.33, top_y + 0.08, 0.88), Color(0.45, 0.44, 0.41))
	# A bench under the front window.
	timber(kit, Vector3(0.9, 0.45, -hz - 0.45), Vector3(2.0, 0.45, -hz - 0.45), 0.32, 0.05, wood, Vector3.BACK)
	for bx in [1.0, 1.9]:
		timber(kit, Vector3(bx, 0.0, -hz - 0.45), Vector3(bx, 0.43, -hz - 0.45), 0.28, 0.05, dark, Vector3.BACK)


## Split firewood stacked along a wall (`length` along x, from x0, against z = z0 facing -z).
func woodpile(kit: Dictionary, rng: RandomNumberGenerator, x0: float, length: float, z0: float) -> void:
	var rows := 5
	var n := int(length / 0.19)
	for k in range(rows):
		for i in range(n):
			var r := rng.randf_range(0.07, 0.095)
			var x := x0 + (i + 0.5 + (0.5 if k % 2 == 1 else 0.0)) * (length / n)
			if x > x0 + length - 0.05:
				continue
			var y := 0.1 + k * 0.17 + r
			var zf := z0 - 0.02 - rng.randf_range(0.0, 0.05)
			round_log(kit, Vector3(x, y, zf - 0.48), Vector3(x, y, zf), r, r, LOG_TINT, false, true, 7)
	# The rack: a sill and end posts.
	timber(kit, Vector3(x0 - 0.05, 0.05, z0 - 0.25), Vector3(x0 + length + 0.05, 0.05, z0 - 0.25), 0.4, 0.1, Color(0.36, 0.28, 0.2), Vector3.BACK)
	for px in [x0 - 0.06, x0 + length + 0.06]:
		timber(kit, Vector3(px, 0.0, z0 - 0.25), Vector3(px, 1.0, z0 - 0.25), 0.08, 0.08, Color(0.36, 0.28, 0.2))
	# A chopping block with an axe and splits round it stood here; the draws it took are kept so the
	# yard's other props keep their places.
	for i in range(4):
		rng.randf()


# ======================================================================================
#  The marquee
# ======================================================================================

## A 6 x 6m pagoda marquee: four poles, a white roof rising in curves to a peak with a finial, a
## scalloped valance in `trim`, the corner drapes tied back, two beer-table sets inside.
func marquee(kit: Dictionary, trim: Color, rng: RandomNumberGenerator) -> void:
	var hw := 3.0
	var eave := 2.4
	var apex := 5.2
	var white := Color(0.95, 0.95, 0.93)
	var under := Color(0.78, 0.78, 0.76)
	var alu := Color(0.80, 0.81, 0.83)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * hw, 0.0, sz * hw)
			_kit.tube(kit, "metal", p, p + Vector3(0, eave, 0), 0.045, 0.045, 8, alu)
			_kit.block(kit, "metal", p - Vector3(0.14, 0.0, 0.14), p + Vector3(0.14, 0.02, 0.14), alu.darkened(0.25))
	for i in range(4):
		var a: Vector3 = [Vector3(-hw, eave, -hw), Vector3(hw, eave, -hw), Vector3(hw, eave, hw), Vector3(-hw, eave, hw)][i]
		var b: Vector3 = [Vector3(hw, eave, -hw), Vector3(hw, eave, hw), Vector3(-hw, eave, hw), Vector3(-hw, eave, -hw)][i]
		_kit.tube(kit, "metal", a, b, 0.035, 0.035, 6, alu)
	# The roof: four faces, each a grid from its eave to the peak, rising slowly at the eave and steeply
	# near the top (the pagoda's flare). Smooth normals from the grid; a darker underside.
	var nu := 8
	var nt := 10
	var height := func(t: float) -> float:
		return eave + (apex - eave) * pow(t, 1.8)
	for f in range(4):
		var rot := Basis(Vector3.UP, -PI * 0.5 * f)
		var pt := func(u: float, t: float) -> Vector3:
			var d := 1.0 - t
			return rot * Vector3(d * hw * u, height.call(t), -d * hw)
		for i in range(nu):
			for j in range(nt):
				var u0 := -1.0 + 2.0 * i / nu
				var u1 := -1.0 + 2.0 * (i + 1) / nu
				var t0 := float(j) / nt
				var t1 := float(j + 1) / nt * 0.999
				var q00: Vector3 = pt.call(u0, t0)
				var q10: Vector3 = pt.call(u1, t0)
				var q01: Vector3 = pt.call(u0, t1)
				var q11: Vector3 = pt.call(u1, t1)
				var nrm := func(u: float, t: float) -> Vector3:
					var du: Vector3 = (pt.call(u + 0.01, t) as Vector3) - (pt.call(u - 0.01, t) as Vector3)
					var dt: Vector3 = (pt.call(u, minf(t + 0.01, 0.999)) as Vector3) - (pt.call(u, maxf(t - 0.01, 0.0)) as Vector3)
					var nn := du.cross(dt).normalized()
					return nn if nn.y > 0.0 else -nn
				var n00: Vector3 = nrm.call(u0, t0)
				var n10: Vector3 = nrm.call(u1, t0)
				var n01: Vector3 = nrm.call(u0, t1)
				var n11: Vector3 = nrm.call(u1, t1)
				var out := (n00 + n11).normalized()
				_kit.tri(kit, "canvas", q00, q10, q11, n00, n10, n11, white, out)
				_kit.tri(kit, "canvas", q00, q11, q01, n00, n11, n01, white, out)
				_kit.tri(kit, "canvas", q00, q11, q10, -n00, -n11, -n10, under, -out)
				_kit.tri(kit, "canvas", q00, q01, q11, -n00, -n01, -n11, under, -out)
		# The valance: a band down from the eave, its lower edge in scallops, the trim along its top.
		var vt := 0.32
		var sc := 6
		for k in range(sc):
			var x0 := -hw + 2.0 * hw * k / sc
			var x1 := -hw + 2.0 * hw * (k + 1) / sc
			var segs := 6
			for m in range(segs):
				var a0 := float(m) / segs
				var a1 := float(m + 1) / segs
				var xa := lerpf(x0, x1, a0)
				var xb := lerpf(x0, x1, a1)
				var ya := eave - vt - 0.09 * sin(PI * a0)
				var yb := eave - vt - 0.09 * sin(PI * a1)
				var z := -hw - 0.012
				var pts := [rot * Vector3(xa, eave - 0.07, z), rot * Vector3(xb, eave - 0.07, z), rot * Vector3(xb, yb, z), rot * Vector3(xa, ya, z)]
				_kit.panel(kit, "canvas", pts, rot * Vector3(0, 0, -1), white, under)
			var top := [rot * Vector3(x0, eave + 0.02, -hw - 0.016), rot * Vector3(x1, eave + 0.02, -hw - 0.016),
					rot * Vector3(x1, eave - 0.07, -hw - 0.016), rot * Vector3(x0, eave - 0.07, -hw - 0.016)]
			_kit.panel(kit, "canvas", top, rot * Vector3(0, 0, -1), trim, trim.darkened(0.3))
	# Finial on the peak.
	_kit.tube(kit, "metal", Vector3(0, apex - 0.05, 0), Vector3(0, apex + 0.55, 0), 0.025, 0.012, 6, alu)
	_kit.lathe(kit, "metal", Vector3(0, apex + 0.55, 0), [Vector2(0.0, 0.0), Vector2(0.06, 0.04), Vector2(0.06, 0.1), Vector2(0.0, 0.14)], 8, trim)
	# Drapes tied back at the corners.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * (hw - 0.12), 0.0, sz * (hw - 0.12))
			_kit.tube(kit, "canvas", c + Vector3(0, eave - 0.1, 0), c + Vector3(0, 1.1, 0), 0.22, 0.08, 8, white)
			_kit.tube(kit, "canvas", c + Vector3(0, 1.1, 0), c + Vector3(0, 0.05, 0), 0.08, 0.2, 8, white)
			_kit.tube(kit, "canvas", c + Vector3(0, 1.06, 0), c + Vector3(0, 1.14, 0), 0.09, 0.09, 8, trim)
	# Two beer-table sets.
	for z in [-1.2, 1.2]:
		beer_set(kit, Vector3(0.0, 0.0, z), rng)


## A beer table and its two benches, along x, centred at `c`.
func beer_set(kit: Dictionary, c: Vector3, rng: RandomNumberGenerator) -> void:
	var wood := Color(0.66, 0.52, 0.36).darkened(rng.randf() * 0.1)
	var leg := Color(0.30, 0.31, 0.33)
	timber(kit, c + Vector3(-1.1, 0.76, 0.0), c + Vector3(1.1, 0.76, 0.0), 0.5, 0.03, wood, Vector3.BACK)
	for lx in [-0.85, 0.85]:
		_kit.tube(kit, "metal", c + Vector3(lx, 0.0, -0.2), c + Vector3(lx, 0.74, 0.05), 0.014, 0.014, 5, leg)
		_kit.tube(kit, "metal", c + Vector3(lx, 0.0, 0.2), c + Vector3(lx, 0.74, -0.05), 0.014, 0.014, 5, leg)
	for bz in [-0.55, 0.55]:
		timber(kit, c + Vector3(-1.1, 0.46, bz), c + Vector3(1.1, 0.46, bz), 0.25, 0.03, wood, Vector3.BACK)
		for lx in [-0.85, 0.85]:
			_kit.tube(kit, "metal", c + Vector3(lx, 0.0, bz - 0.08), c + Vector3(lx, 0.44, bz), 0.012, 0.012, 5, leg)
			_kit.tube(kit, "metal", c + Vector3(lx, 0.0, bz + 0.08), c + Vector3(lx, 0.44, bz), 0.012, 0.012, 5, leg)


# ======================================================================================
#  The paddock's display tables
# ======================================================================================

const DISPLAY_TOP := 0.78
const DISPLAY_HL := 0.85
const DISPLAY_HW := 0.5

## A sturdy pit bench for a car on show: a 1.7 x 1.0m top on a steel frame with a shelf, a black mat
## on it and a car stand in the middle (the car itself is the generator's: its own model). Returns
## the height of the stand's top, where the car's wheels go.
func display_table(kit: Dictionary, top_col: Color) -> float:
	var steel := Color(0.22, 0.23, 0.25)
	var hl := DISPLAY_HL
	var hw := DISPLAY_HW
	var y := DISPLAY_TOP
	_kit.block(kit, "plastic", Vector3(-hl, y - 0.04, -hw), Vector3(hl, y, hw), top_col)
	_kit.block(kit, "rubber", Vector3(-hl + 0.06, y, -hw + 0.06), Vector3(hl - 0.06, y + 0.008, hw - 0.06), Color(0.06, 0.06, 0.07))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * (hl - 0.06), 0.0, sz * (hw - 0.06))
			_kit.block(kit, "metal", p - Vector3(0.03, 0.0, 0.03), p + Vector3(0.03, y - 0.04, 0.03), steel)
	_kit.block(kit, "metal", Vector3(-hl + 0.04, 0.22, -hw + 0.04), Vector3(hl - 0.04, 0.245, hw - 0.04), steel.lightened(0.1))
	for sx in [-1.0, 1.0]:
		_kit.block(kit, "metal", Vector3(sx * (hl - 0.09), y - 0.12, -hw + 0.05), Vector3(sx * (hl - 0.03), y - 0.04, hw - 0.05), steel)
	# The stand: a low plinth the car's chassis rests on.
	_kit.block(kit, "plastic", Vector3(-0.22, y + 0.008, -0.16), Vector3(0.22, y + 0.06, 0.16), Color(0.85, 0.18, 0.12))
	return y + 0.008
