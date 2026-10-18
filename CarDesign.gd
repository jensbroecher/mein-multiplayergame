# CarDesign.gd
#
# What the procedural cars share (CarBuilder.gd is the geometry toolkit underneath): a body shell
# lofted from cross-sections, fender sweeps along a wheel-arch lip, wheel parts, a coil-over, and
# the body's detail map. Each car's <Name>Builder.gd extends this script: it sets its shape in
# _init() (caps, profile knots via setup_shell()) and builds what is its own (lamps, bumpers,
# chassis, wheels, the detail map's shapes). regenerate_cars.gd calls build_body(), build_wheel()
# and build_detail_map(), and reads the car's PAINT_LAYOUT, WHEEL_POSITIONS and ANTENNA_POS.
#
# Cart frame: metres, X right, Y up, front at -Z, the ground at y = 0.
#
# The shell is one cross-section per station along Z: its right half runs from the bottom of the
# centre line along a flat bottom, round a corner, up a vertical side to the beltline, then over
# the top (_upper(): a cubic for a rounded body; a boxier car overrides it). Every parameter of the
# section is a smooth curve along the car (profile knots, prof["top"] etc.). Each end closes with a
# cap that shrinks the section toward a point, faster across than up for a broad nose. The UVs run
# along the centre line's top by arc length (u), so steep faces such as a windscreen get their share
# of the detail map, and round the half-section (v); the left half mirrors the right.
extends RefCounted

const CB = preload("res://CarBuilder.gd")

# Shell shape: each car sets these in _init().
var nose_tip := -0.8
var nose_cap := 0.05
var nose_cap_y := 0.45
var nose_cap_exp := Vector2(4.0, 2.0)    # superellipse exponents (across, up) of the nose's rounding
var tail_tip := 0.9
var tail_cap := 0.04
var tail_cap_y := 0.4
var tail_cap_exp := Vector2(3.0, 2.0)
var half_ring := 28                       # section points from the bottom of the centre line to its top
var bottom_radius := 0.035                # largest radius of the section's bottom corner
var station_step := 0.025                 # stations along the car; refined where the section changes fast
var refine_tol := 0.02
## Points per segment of the half-section, for sections with features (a tight corner, a step)
## that must sit on the same ring points at every station, or the loft shears between them:
## [bottom, bottom corner, side, then one per segment of _upper_segments()], summing to half_ring.
## Empty: the half-section is resampled as one curve (by arc length, weighted toward bends).
var segment_counts: Array = []
var prof := {}                            # name -> CB.Profile: "top", "bot", "w", "belt" and the car's own
## The fenders' skin and end caps: painted, or black plastic flares (M_DARK in fender_col).
var fender_mat := CB.M_PAINT
var fender_col := Color(1, 1, 1)

var _u_z := PackedFloat32Array()          # u(z) table: arc length along the capped top of the centre line
var _u_val := PackedFloat32Array()


## Profile knots from a keyframe table, rows of [z, one value per name]: every profile gets the same
## knot z's, so a section's features change together between regions (cab, bed, bonnet...).
static func keyed_knots(keys: Array, names: Array) -> Dictionary:
	var knots := {}
	for key_name in names:
		knots[key_name] = []
	for key in keys:
		for k in names.size():
			(knots[names[k]] as Array).append([key[0], key[k + 1]])
	return knots


## Builds the section profiles from {name: [[z, value], ...]} and the u table.
func setup_shell(knots: Dictionary) -> void:
	for key in knots:
		prof[key] = CB.Profile.new(knots[key])
	_u_z = PackedFloat32Array()
	_u_val = PackedFloat32Array()
	var n := 1200
	var acc := 0.0
	var prev := Vector2.ZERO
	for k in n + 1:
		var z: float = lerpf(nose_tip, tail_tip, float(k) / n)
		var q := Vector2(z, _capped_top(z))
		if k > 0:
			acc += q.distance_to(prev)
		prev = q
		_u_z.append(z)
		_u_val.append(acc)
	for k in _u_val.size():
		_u_val[k] /= acc


# ============================================================================================
#  Shell
# ============================================================================================

## The right half of the body's cross-section at z: half_ring + 1 points (x, y) from the bottom of
## the centre line to its top, caps applied.
func section(z: float) -> PackedVector2Array:
	var bot: float = prof["bot"].at(z)
	var top: float = prof["top"].at(z)
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var rb: float = minf(bottom_radius, (belt - bot) * 0.4)
	var bottom := PackedVector2Array()
	for k in 7:
		bottom.append(Vector2((w - rb) * k / 6.0, bot))
	var corner := PackedVector2Array()
	for k in 9:
		var a: float = -PI * 0.5 + PI * 0.5 * k / 8.0
		corner.append(Vector2(w - rb + rb * cos(a), bot + rb + rb * sin(a)))
	var side := PackedVector2Array([Vector2(w, bot + rb), Vector2(w, belt)])
	var sec := PackedVector2Array()
	if segment_counts.is_empty():
		var dense: PackedVector2Array = bottom.slice(0, 6)
		dense.append_array(corner)
		for k in range(1, 10):
			dense.append(Vector2(w, lerpf(bot + rb, belt, k / 9.0)))
		dense.append_array(_upper(z, w, belt, top))
		sec = CB.resample(dense, half_ring + 1, 0.03)
	else:
		var segs: Array = [bottom, corner, side]
		segs.append_array(_upper_segments(z, w, belt, top))
		sec.append(bottom[0])
		for k in segs.size():
			var rs: PackedVector2Array = CB.resample(segs[k], int(segment_counts[k]) + 1, 0.0)
			for m in range(1, rs.size()):
				sec.append(rs[m])
	var c: Array = _cap(z)
	var cap: Vector2 = c[0]
	if cap != Vector2.ONE:
		var cy: float = c[1]
		for k in sec.size():
			sec[k] = Vector2(sec[k].x * cap.x, cy + (sec[k].y - cy) * cap.y)
	return sec


## The section above the beltline: points after (w, belt) up to (0, top). This one is a cubic,
## P0 = (w, belt), P1 = (w - tumble, belt + ka (top - belt)), P2 = (kb w, top), P3 = (0, top),
## from the "tumble", "ka" and "kb" profiles: tumble pulls the glass in, kb flattens the roof.
func _upper(z: float, w: float, belt: float, top: float) -> PackedVector2Array:
	var p0 := Vector2(w, belt)
	var p1 := Vector2(w - prof["tumble"].at(z), belt + prof["ka"].at(z) * (top - belt))
	var p2 := Vector2(prof["kb"].at(z) * w, top)
	var p3 := Vector2(0.0, top)
	var out := PackedVector2Array()
	for k in range(1, 49):
		out.append(p0.bezier_interpolate(p1, p2, p3, k / 48.0))
	return out


## The section above the beltline as segments (polylines, each starting where the last ended,
## the first at (w, belt), the last ending at (0, top)), for cars with segment_counts.
func _upper_segments(_z: float, _w: float, _belt: float, _top: float) -> Array:
	return []


## [cap scale (across, up), the height it shrinks toward] at z: (1, 1) away from the ends.
func _cap(z: float) -> Array:
	if z < nose_tip + nose_cap:
		var t: float = clampf((nose_tip + nose_cap - z) / nose_cap, 0.0, 1.0)
		return [Vector2(_superellipse(t, nose_cap_exp.x), _superellipse(t, nose_cap_exp.y)), nose_cap_y]
	if z > tail_tip - tail_cap:
		var t: float = clampf((z - tail_tip + tail_cap) / tail_cap, 0.0, 1.0)
		return [Vector2(_superellipse(t, tail_cap_exp.x), _superellipse(t, tail_cap_exp.y)), tail_cap_y]
	return [Vector2.ONE, 0.0]


static func _superellipse(t: float, e: float) -> float:
	return pow(maxf(1.0 - pow(t, e), 0.0), 1.0 / e)


func _capped_top(z: float) -> float:
	var c: Array = _cap(z)
	var top: float = prof["top"].at(z)
	return top if (c[0] as Vector2) == Vector2.ONE else c[1] + (top - c[1]) * (c[0] as Vector2).y


func u_of_z(z: float) -> float:
	var f: float = (z - nose_tip) / (tail_tip - nose_tip) * (_u_z.size() - 1)
	var k: int = clampi(int(f), 0, _u_z.size() - 2)
	return lerpf(_u_val[k], _u_val[k + 1], clampf(f - k, 0.0, 1.0))


func z_of_u(u: float) -> float:
	var lo := 0
	var hi: int = _u_val.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if _u_val[mid] < u:
			lo = mid
		else:
			hi = mid
	var span: float = _u_val[hi] - _u_val[lo]
	var t: float = 0.0 if span < 1e-9 else (u - _u_val[lo]) / span
	return lerpf(_u_z[lo], _u_z[hi], clampf(t, 0.0, 1.0))


## Stations along the car: dense through the caps, every station_step between, and halved again
## (up to three times) wherever neighbouring sections differ by more than refine_tol. In doubles:
## a flat cap (high exponents) only closes at the very tip, and the tip rounded to a float32
## (1.025 -> 1.0249999) left a quarter-size hole in it.
func stations() -> PackedFloat64Array:
	var zs := PackedFloat64Array()
	for k in 9:
		zs.append(nose_tip + nose_cap * (1.0 - cos(PI * 0.5 * k / 9.0)))
	var z0: float = nose_tip + nose_cap
	var z1: float = tail_tip - tail_cap
	var n: int = ceili((z1 - z0) / station_step)
	for k in n + 1:
		zs.append(lerpf(z0, z1, float(k) / n))
	for k in range(8, -1, -1):
		zs.append(tail_tip - tail_cap * (1.0 - cos(PI * 0.5 * k / 9.0)))
	zs[0] = nose_tip
	zs[zs.size() - 1] = tail_tip
	var out := PackedFloat64Array()
	for k in zs.size() - 1:
		out.append(zs[k])
		_refine(zs[k], zs[k + 1], section(zs[k]), section(zs[k + 1]), 3, out)
	out.append(zs[zs.size() - 1])
	return out


func _refine(z0: float, z1: float, s0: PackedVector2Array, s1: PackedVector2Array, depth: int, out: PackedFloat64Array) -> void:
	if depth == 0 or z1 - z0 < 0.003:
		return
	var worst := 0.0
	for k in s0.size():
		worst = maxf(worst, s0[k].distance_to(s1[k]))
	if worst <= refine_tol:
		return
	var zm: float = (z0 + z1) * 0.5
	var sm: PackedVector2Array = section(zm)
	_refine(z0, zm, s0, sm, depth - 1, out)
	out.append(zm)
	_refine(zm, z1, sm, s1, depth - 1, out)


func build_shell(b) -> void:
	var rows := []
	var uvs := []
	for z in stations():
		var sec: PackedVector2Array = section(z)
		var row := PackedVector3Array()
		var uv := PackedVector2Array()
		var u: float = u_of_z(z)
		# Right half bottom to top, then the left half back down (mirror), as one closed ring.
		for j in half_ring + 1:
			row.append(Vector3(sec[j].x, sec[j].y, z))
			uv.append(Vector2(u, float(j) / half_ring))
		for j in range(half_ring - 1, 0, -1):
			row.append(Vector3(-sec[j].x, sec[j].y, z))
			uv.append(Vector2(u, float(j) / half_ring))
		rows.append(row)
		uvs.append(uv)
	# Rows run nose to tail (+z) and each ring goes up the right side first, so d/dj x d/di
	# already points outward.
	b.grid(rows, CB.M_BODY, Color(1, 1, 1), false, true, uvs)


## Where the body's surface is at (x, y), searching from the nose (or from the tail): its z.
func shell_z(x: float, y: float, from_front: bool) -> float:
	var z: float = nose_tip if from_front else tail_tip
	var dz: float = 0.002 if from_front else -0.002
	for k in 600:
		if _inside_half(section(z), absf(x), y):
			return z
		z += dz
	return z


## A point on the shell's nose (or tail) at (x, y) and its outward normal there: [point, normal],
## for parts set on those faces (lamps, grilles, plates).
func face_frame(x: float, y: float, front: bool) -> Array:
	var z: float = shell_z(x, y, front)
	var e := 0.01
	var dzdx: float = (shell_z(x + e, y, front) - shell_z(x - e, y, front)) / (2.0 * e)
	var dzdy: float = (shell_z(x, y + e, front) - shell_z(x, y - e, front)) / (2.0 * e)
	var nrm := Vector3(dzdx, dzdy, -1.0 if front else 1.0).normalized()
	if (nrm.z < 0.0) != front:
		nrm = -nrm
	return [Vector3(x, y, z), nrm]


## A basis whose z axis is `fwd` and y axis as near to up as it allows.
static func facing(fwd: Vector3) -> Basis:
	var zb: Vector3 = fwd.normalized()
	var xb: Vector3 = Vector3.UP.cross(zb).normalized()
	return Basis(xb, zb.cross(xb).normalized(), zb)


## Height of the shell's top surface at (x, z) (for parts sitting on a roof or bonnet).
func top_y(x: float, z: float) -> float:
	var sec: PackedVector2Array = section(z)
	var ax: float = absf(x)
	for k in range(sec.size() - 1, 0, -1):
		var a: Vector2 = sec[k]
		var c: Vector2 = sec[k - 1]
		if ax >= a.x and ax <= c.x and c.x - a.x > 1e-9:
			return lerpf(a.y, c.y, (ax - a.x) / (c.x - a.x))
	return sec[sec.size() - 1].y


## An axis-aligned flat-shaded box: cheap trim (grille bars, bolts) where rounding wouldn't show.
func bar(b, c: Vector3, h: Vector3, mat: int, col: Color) -> void:
	for axis in 3:
		for sgn in [-1.0, 1.0]:
			var nrm := Vector3.ZERO
			nrm[axis] = sgn
			var u: int = (axis + 1) % 3
			var v: int = (axis + 2) % 3
			var ids := []
			for k in 4:
				var p: Vector3 = c
				p[axis] += sgn * h[axis]
				p[u] += h[u] * (1.0 if k < 2 else -1.0)
				p[v] += h[v] * (1.0 if k == 0 or k == 3 else -1.0)
				ids.append(b.vertex(p, nrm, mat, col))
			b.quad(ids[0], ids[1], ids[2], ids[3])


## Is (x, y) inside the half-section (x >= 0)? Its outline rises monotonically from the bottom
## corner to the top of the centre line, so the edge at height y is one crossing.
static func _inside_half(sec: PackedVector2Array, x: float, y: float) -> bool:
	if y < sec[0].y or y > sec[sec.size() - 1].y:
		return false
	for k in range(1, sec.size()):
		var a: Vector2 = sec[k - 1]
		var c: Vector2 = sec[k]
		if absf(c.y - a.y) < 1e-9:
			continue
		if y >= minf(a.y, c.y) and y <= maxf(a.y, c.y):
			return x <= lerpf(a.x, c.x, (y - a.y) / (c.y - a.y))
	return false


# ============================================================================================
#  Fenders
# ============================================================================================

## Height of a wheel-arch lip at z, or -1 outside it (for the detail map's wheel wells).
static func _lip_y(lip: Array, z: float) -> float:
	var best := -1.0
	for k in range(1, lip.size()):
		var a: Array = lip[k - 1]
		var c: Array = lip[k]
		var lo: float = minf(a[0], c[0])
		var hi: float = maxf(a[0], c[0])
		if z >= lo and z <= hi and hi - lo > 1e-6:
			best = maxf(best, lerpf(a[1], c[1], (z - a[0]) / (c[0] - a[0])))
	return best


## A smooth spine through the lip points (Catmull-Rom), `n` samples, as (z, y).
static func _spine(lip: Array, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in lip:
		pts.append(Vector2(k[0], k[1]))
	var out := PackedVector2Array()
	var segs: int = pts.size() - 1
	for s in n:
		var f: float = float(s) / (n - 1) * segs
		var i: int = mini(int(f), segs - 1)
		var t: float = f - i
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, pts.size() - 1)]
		if i == 0:
			p0 = p1 * 2.0 - p2
		if i + 2 > pts.size() - 1:
			p3 = p2 * 2.0 - p1
		var t2: float = t * t
		var t3: float = t2 * t
		out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


## One fender (right side; the caller mirrors it), swept along a wheel-arch lip given in side view
## as [[z, y], ...] from the end at the doors round to the outer end. The section (_fender_section)
## stands on the side of the lip away from the hub, `depth` deep, out to x_out, its inner edge
## buried in the body; a dark liner closes it underneath. The outer end rounds off over `taper_len`
## of the spine (an elliptical taper), or stays blunt and capped with 0, like the door end.
## Returns [point, normal, along the spine] on its top near the outer end (where a lamp could sit).
func build_fender(b, lip: Array, hub_z: float, hub_y: float, x_out: float, depth: float, taper_len: float) -> Array:
	var spine: PackedVector2Array = _spine(lip, 40)
	var n: int = spine.size()
	var acc := PackedFloat32Array([0.0])
	for k in range(1, n):
		acc.append(acc[k - 1] + spine[k].distance_to(spine[k - 1]))
	var total: float = acc[n - 1]
	var outer_rows := []
	var liner_rows := []
	var ends := []
	var mark := []
	for k in n:
		var t2: Vector2 = (spine[mini(k + 1, n - 1)] - spine[maxi(k - 1, 0)]).normalized()
		var n2 := Vector2(t2.y, -t2.x)
		if n2.dot(spine[k] - Vector2(hub_z, hub_y)) < 0.0:
			n2 = -n2
		var x_in: float = prof["w"].at(spine[k].x) - 0.035
		var sc := 1.0
		var into_end: float = total - acc[k]
		if taper_len > 0.0 and into_end < taper_len:
			var t: float = 1.0 - into_end / taper_len
			sc = sqrt(maxf(1.0 - t * t, 0.0))
		var sections: Array = _fender_section(x_out, x_in, depth)
		var mid := Vector2(lerpf(x_in, x_out, 0.55), depth * 0.5)
		var rows := []
		for profile in sections:
			var row := PackedVector3Array()
			for p in profile:
				var q: Vector2 = _taper(p, mid, sc)
				row.append(Vector3(q.x, spine[k].y + q.y * n2.y, spine[k].x + q.y * n2.x))
			rows.append(row)
		outer_rows.append(rows[0])
		liner_rows.append(rows[1])
		if k == 0:
			ends.append([rows[0], rows[1], Vector3(0.0, -t2.y, -t2.x)])
		elif k == n - 1 and taper_len <= 0.0:
			ends.append([rows[0], rows[1], Vector3(0.0, t2.y, t2.x)])
		if k == int(n * 0.80):
			mark = [Vector3(lerpf(x_in, x_out, 0.72), spine[k].y + depth * n2.y, spine[k].x + depth * n2.x),
				Vector3(0.0, n2.y, n2.x), Vector3(0.0, t2.y, t2.x)]
	var base: int = b.vertex_count()
	var ibase: int = b.index_count()
	b.grid(outer_rows, fender_mat, fender_col, false, false)
	# The skin faces outward: at its outermost point (the door end's), the normal points along +x.
	var row0: PackedVector3Array = outer_rows[0]
	var far := 0
	for k in row0.size():
		if row0[k].x > row0[far].x:
			far = k
	if b._n[base + far].dot(Vector3.RIGHT) < 0.0:
		b.flip(base, ibase)
	base = b.vertex_count()
	ibase = b.index_count()
	b.grid(liner_rows, CB.M_DARK, Color(0.035, 0.035, 0.04), false, false)
	b.orient_toward(base, ibase, Vector3.DOWN)
	for e in ends:
		var cap := PackedVector3Array()
		for p in e[0]:
			cap.append(p)
		var lr: PackedVector3Array = e[1]
		for k in range(lr.size() - 1, 0, -1):
			cap.append(lr[k])
		b.poly(cap, e[2], fender_mat, fender_col)
	return mark


## A fender's section in (x, height above the lip): [outer skin, liner], both starting at the lip
## and ending buried in the body (x_in). This one is a Beetle fender: a lip, a slightly bulged outer
## face, a rounded shoulder and a flat top running inward.
func _fender_section(xo: float, x_in: float, d: float) -> Array:
	return [
		[Vector2(xo - 0.010, 0.0), Vector2(xo - 0.001, 0.08 * d), Vector2(xo + 0.004, 0.32 * d),
			Vector2(xo + 0.003, 0.55 * d), Vector2(xo - 0.006, 0.78 * d), Vector2(xo - 0.024, 0.95 * d),
			Vector2(xo - 0.055, d), Vector2(x_in + 0.03, d), Vector2(x_in, d - 0.002)],
		[Vector2(xo - 0.010, 0.0), Vector2(xo - 0.026, 0.35 * d), Vector2(x_in, 0.6 * d)],
	]


## A fender section point shrunk toward the section's middle by `sc` (1 = untouched): faster in
## height than across, so the outer end rounds off in plan as well as in profile.
static func _taper(p: Vector2, mid: Vector2, sc: float) -> Vector2:
	if sc >= 1.0:
		return p
	return Vector2(mid.x + (p.x - mid.x) * sqrt(sc), mid.y + (p.y - mid.y) * sc)


# ============================================================================================
#  Wheels and suspension parts
# ============================================================================================

## A tyre carcass about the X axis from half its profile [[x, r], ...] (inner bead to the middle
## of the tread); the other half mirrors it.
func tyre(b, half: Array, segs: int, col: Color) -> void:
	var prof2 := PackedVector2Array()
	for p in half:
		prof2.append(Vector2(p[0], p[1]))
	for k in range(half.size() - 1, -1, -1):
		prof2.append(Vector2(-half[k][0], half[k][1]))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3.ZERO, Vector3.RIGHT, prof2, segs, CB.M_RUBBER, col)
	b.orient_away_from(vb, ib, Vector3.ZERO)


## A lathe about the wheel's axle (X) whose surface faces `face`: "out" (away from `centre`),
## "in" (toward the axle, like the inside of a rim barrel) or "+x" (toward the wheel's face).
func wheel_lathe(b, profile: PackedVector2Array, segs: int, mat: int, col: Color, face: String,
		centre := Vector3.ZERO) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3.ZERO, Vector3.RIGHT, profile, segs, mat, col)
	match face:
		"out":
			b.orient_away_from(vb, ib, centre)
		"+x":
			b.orient_toward(vb, ib, Vector3.RIGHT)
		"in":
			var radial := 0.0
			for k in range(vb, b.vertex_count()):
				radial += b._n[k].dot(Vector3(0.0, b._v[k].y, b._v[k].z))
			if radial > 0.0:
				b.flip(vb, ib)


## The radial direction at angle a round the X axis, and the tangent (rolling direction).
static func wheel_frame(a: float) -> Array:
	return [Vector3(0.0, cos(a), sin(a)), Vector3(0.0, -sin(a), cos(a))]


## A flat-shaded block with no bottom face: centre c, axes a1 (half-size h1), a2 (h2) and up
## (height, from c - up*h_up*0.4 to c + up*h_up*0.6), its top shrunk by `top_scale`.
func block(b, c: Vector3, a1: Vector3, a2: Vector3, up: Vector3, h1: float, h_up: float, h2: float,
		top_scale: float, mat: int, col: Color) -> void:
	var lo: Vector3 = c - up * h_up * 0.4
	var hi: Vector3 = c + up * h_up * 0.6
	var bl := [lo + a1 * h1 + a2 * h2, lo - a1 * h1 + a2 * h2, lo - a1 * h1 - a2 * h2, lo + a1 * h1 - a2 * h2]
	var tl := [hi + (a1 * h1 + a2 * h2) * top_scale, hi + (-a1 * h1 + a2 * h2) * top_scale,
		hi + (-a1 * h1 - a2 * h2) * top_scale, hi + (a1 * h1 - a2 * h2) * top_scale]
	b.poly(PackedVector3Array(tl), up, mat, col)
	for k in 4:
		var p0: Vector3 = bl[k]
		var p1: Vector3 = bl[(k + 1) % 4]
		var p2: Vector3 = tl[(k + 1) % 4]
		var p3: Vector3 = tl[k]
		var nrm: Vector3 = ((p0 + p1 + p2 + p3) * 0.25 - c).normalized()
		var ids := []
		for p in [p0, p1, p2, p3]:
			ids.append(b.vertex(p, nrm, mat, col))
		b.quad(ids[0], ids[1], ids[2], ids[3])


## A four-sided spike from `base` along `dir`, its base `s` across.
func spike(b, base: Vector3, dir: Vector3, tangent: Vector3, length: float, s: float, mat: int, col: Color) -> void:
	var side: Vector3 = dir.cross(tangent).normalized()
	var tip: Vector3 = base + dir * length
	var corners := [base + tangent * s + side * s, base + tangent * s - side * s, base - tangent * s - side * s,
		base - tangent * s + side * s]
	for k in 4:
		var p0: Vector3 = corners[k]
		var p1: Vector3 = corners[(k + 1) % 4]
		var nrm: Vector3 = (p1 - p0).cross(tip - p0).normalized()
		if nrm.dot((p0 + p1) * 0.5 - base) < 0.0:
			nrm = -nrm
		b.tri(b.vertex(p0, nrm, mat, col), b.vertex(p1, nrm, mat, col), b.vertex(tip, nrm, mat, col))


## A flat spoke on the wheel's face from radius r0 (at x0) to r1 (at x1), half-widths w0 and w1,
## `th` thick, its outer end turned `twist` radians ahead.
func spoke(b, a: float, twist: float, r0: float, r1: float, x0: float, x1: float, w0: float, w1: float,
		th: float, mat: int, col: Color) -> void:
	var f0: Array = wheel_frame(a)
	var f1: Array = wheel_frame(a + twist)
	var rd0: Vector3 = f0[0]
	var tg0: Vector3 = f0[1]
	var rd1: Vector3 = f1[0]
	var tg1: Vector3 = f1[1]
	var inner := [rd0 * r0 + tg0 * w0, rd0 * r0 - tg0 * w0]
	var outer := [rd1 * r1 + tg1 * w1, rd1 * r1 - tg1 * w1]
	var front_in := [inner[0] + Vector3(x0, 0, 0), inner[1] + Vector3(x0, 0, 0)]
	var back_in := [inner[0] + Vector3(x0 - th, 0, 0), inner[1] + Vector3(x0 - th, 0, 0)]
	var front_out := [outer[0] + Vector3(x1, 0, 0), outer[1] + Vector3(x1, 0, 0)]
	var back_out := [outer[0] + Vector3(x1 - th, 0, 0), outer[1] + Vector3(x1 - th, 0, 0)]
	face(b, [front_in[0], front_in[1], front_out[1], front_out[0]], Vector3.RIGHT, mat, col)
	face(b, [front_in[0], front_out[0], back_out[0], back_in[0]], (tg0 + tg1).normalized(), mat, col)
	face(b, [front_in[1], front_out[1], back_out[1], back_in[1]], -(tg0 + tg1).normalized(), mat, col)
	face(b, [back_in[0], back_in[1], back_out[1], back_out[0]], -Vector3.RIGHT, mat, col)


## A headlamp's lens (M_HEADLAMP): a shallow dome of radius r, `bulge` proud, facing `fwd`. Its
## UVs are the offset from its centre in metres: car_body.gdshader draws the reflector's rings
## round that.
func lens(b, c: Vector3, fwd: Vector3, r: float, bulge: float, segs: int) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, fwd, PackedVector2Array([Vector2(0.0, r), Vector2(bulge * 0.43, r * 0.9), Vector2(bulge * 0.79, r * 0.63),
			Vector2(bulge, 0.0)]), segs, CB.M_HEADLAMP, Color(1, 1, 1))
	b.orient_away_from(vb, ib, c - fwd * r)
	var e1: Vector3 = CB._perp(fwd)
	var e2: Vector3 = fwd.cross(e1).normalized()
	for k in range(vb, b.vertex_count()):
		var d: Vector3 = b._v[k] - c
		b._uv[k] = Vector2(d.dot(e1), d.dot(e2))


## A polyline with its corners rounded off (a quadratic Bézier over `r` either side of each), for
## tube work: cages, sport bars, bumpers.
static func _rounded(pts: Array, r: float, steps := 4) -> PackedVector3Array:
	var out := PackedVector3Array([pts[0]])
	for k in range(1, pts.size() - 1):
		var p: Vector3 = pts[k]
		var a: Vector3 = p + (pts[k - 1] - p).normalized() * minf(r, (pts[k - 1] - p).length() * 0.45)
		var c: Vector3 = p + (pts[k + 1] - p).normalized() * minf(r, (pts[k + 1] - p).length() * 0.45)
		for s in steps + 1:
			var t: float = float(s) / steps
			out.append(a.lerp(p, t).lerp(p.lerp(c, t), t))
	out.append(pts[pts.size() - 1])
	return out


## A flat-shaded quad facing `hint`.
func face(b, q: Array, hint: Vector3, mat: int, col: Color) -> void:
	var nrm: Vector3 = (q[2] - q[0]).cross(q[1] - q[0]).normalized()
	if nrm.dot(hint) < 0.0:
		nrm = -nrm
	var ids := []
	for p in q:
		ids.append(b.vertex(p, nrm, mat, col))
	b.quad(ids[0], ids[1], ids[2], ids[3])


## A coil-over shock from `lo` to `hi`: chrome shaft, damper body, spring seat and a spring in the
## accent colour (M_ANODISED), a mount block at the top.
func coilover(b, lo: Vector3, hi: Vector3, body_r: float, coil_r: float, turns: float,
		alloy: Color, alloy_dark: Color, chrome: Color, dark: Color) -> void:
	var ax: Vector3 = (hi - lo).normalized()
	var body_lo: Vector3 = lo.lerp(hi, 0.42)
	b.tube(PackedVector3Array([lo, body_lo]), body_r * 0.43, 6, CB.M_CHROME, chrome, true, false)
	b.tube(PackedVector3Array([body_lo, hi]), body_r, 10, CB.M_ALLOY, alloy, true, true)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(lo.lerp(hi, 0.16), ax, PackedVector2Array([Vector2(-0.004, 0.0), Vector2(-0.004, coil_r * 1.2),
			Vector2(0.004, coil_r * 1.2), Vector2(0.004, 0.0)]), 12, CB.M_ALLOY, alloy_dark)
	b.orient_away_from(vb, ib, lo.lerp(hi, 0.16))
	b.spring(lo.lerp(hi, 0.18), lo.lerp(hi, 0.94), coil_r, coil_r * 0.207, turns, CB.M_ANODISED, Color(1, 1, 1))
	b.rbox(Transform3D(Basis(), hi + Vector3(-0.01, 0.012, 0.0)), Vector3(0.03, 0.01, 0.03), 0.006, 1, CB.M_DARK, dark)


# ============================================================================================
#  Plates and lamps
# ============================================================================================

## A round lamp facing `fwd`: a chrome bezel round a lens (a headlamp's reflector lens, or a
## coloured one).
func round_lamp(b, c: Vector3, fwd: Vector3, r: float, mat: int, col: Color) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, fwd, PackedVector2Array([Vector2(-0.012, r + 0.004), Vector2(0.002, r + 0.004), Vector2(0.005, r + 0.001),
			Vector2(0.004, r - 0.002)]), 18, CB.M_CHROME, Color(0.92, 0.93, 0.95))
	b.orient_away_from(vb, ib, c - fwd * 0.01)
	if mat == CB.M_HEADLAMP:
		lens(b, c + fwd * 0.001, fwd, r, r * 0.25, 18)
	else:
		vb = b.vertex_count()
		ib = b.index_count()
		b.lathe(c, fwd, PackedVector2Array([Vector2(0.0, r), Vector2(r * 0.15, r * 0.8), Vector2(r * 0.25, 0.0)]), 18,
				mat, col)
		b.orient_away_from(vb, ib, c - fwd * r)


## A profile (across, out) swept along a path, flat-shaded round the profile and smooth along the
## path: plates, roof panels, wings. `across` is the profile's first axis (constant), the
## second is across x tangent, turned toward `up_hint`. Both ends are capped; the caps need a convex
## profile (a bent plate's end hides under its endplate).
func sweep(b, path: PackedVector3Array, across: Vector3, up_hint: Vector3, profile: PackedVector2Array, mat: int,
		col: Color) -> void:
	var n: int = path.size()
	var m: int = profile.size()
	# The profile's winding, so each edge knows its outward side (a centroid test fails on a thin
	# bent plate such as the wing, whose centroid lies off the plate).
	var area := 0.0
	for k in m:
		area += profile[k].cross(profile[(k + 1) % m])
	var rings := []
	var normals := []
	var tangents := []
	for i in n:
		var t: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var nrm: Vector3 = across.cross(t).normalized()
		if nrm.dot(up_hint) < 0.0:
			nrm = -nrm
		var ring := PackedVector3Array()
		for p in profile:
			ring.append(path[i] + across * p.x + nrm * p.y)
		rings.append(ring)
		normals.append(nrm)
		tangents.append(t)
	for k in m:
		var k2: int = (k + 1) % m
		var e: Vector2 = profile[k2] - profile[k]
		var out2: Vector2 = Vector2(e.y, -e.x) * (1.0 if area > 0.0 else -1.0)
		var rows := []
		for i in n:
			rows.append(PackedVector3Array([rings[i][k], rings[i][k2]]))
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.grid(rows, mat, col, false, false)
		var s := 0.0
		for v in range(vb, b.vertex_count()):
			s += b._n[v].dot(across * out2.x + (normals[(v - vb) / 2] as Vector3) * out2.y)
		if s < 0.0:
			b.flip(vb, ib)
	b.poly(rings[0], -(tangents[0] as Vector3), mat, col)
	b.poly(rings[n - 1], tangents[n - 1], mat, col)


## A flat plate across x: a convex outline in side view (z, y), `th` thick, centred on x.
func slab(b, outline: PackedVector2Array, x: float, th: float, mat: int, col: Color) -> void:
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	var c := Vector2.ZERO
	for p in outline:
		outer.append(Vector3(x + th * 0.5, p.y, p.x))
		inner.append(Vector3(x - th * 0.5, p.y, p.x))
		c += p
	c /= outline.size()
	b.poly(outer, Vector3.RIGHT, mat, col)
	b.poly(inner, Vector3.LEFT, mat, col)
	for k in outline.size():
		var k2: int = (k + 1) % outline.size()
		var mid: Vector2 = (outline[k] + outline[k2]) * 0.5 - c
		face(b, [outer[k], outer[k2], inner[k2], inner[k]], Vector3(0.0, mid.y, mid.x), mat, col)


## The radius of a tyre carcass at x across the tread, from its half profile (CarDesign.tyre()):
## walked out from the centre, so the tread's side of the shoulder answers, not the sidewall's.
static func carcass_r(half: Array, x: float) -> float:
	var ax: float = absf(x)
	for k in range(half.size() - 1, 0, -1):
		var xa: float = -float(half[k][0])
		var xc: float = -float(half[k - 1][0])
		if ax >= xa and ax <= xc:
			return lerpf(half[k][1], half[k - 1][1], (ax - xa) / (xc - xa))
	return half[0][1]


# ============================================================================================
#  Detail map
# ============================================================================================

## The body's detail map over its UVs (u along the top of the centre line, v round the
## half-section): R glass, G panel gaps, B chrome trim, A black. The car draws it per texel in
## _detail_at() from the surface point and normal there, with shapes from _detail_shapes().
func build_detail_map(width: int, height: int) -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var pos := []
	for i in width:
		var z: float = z_of_u((i + 0.5) / width)
		var sec: PackedVector2Array = section(z)
		var col := PackedVector3Array()
		for j in height:
			var t: float = (j + 0.5) / height * half_ring
			var k: int = mini(int(t), half_ring - 1)
			var p2: Vector2 = sec[k].lerp(sec[k + 1], t - k)
			col.append(Vector3(p2.x, p2.y, z))
		pos.append(col)
	var shapes: Dictionary = _detail_shapes()
	for i in width:
		var col: PackedVector3Array = pos[i]
		var colp: PackedVector3Array = pos[maxi(i - 1, 0)]
		var coln: PackedVector3Array = pos[mini(i + 1, width - 1)]
		for j in height:
			var p: Vector3 = col[j]
			var du: Vector3 = coln[j] - colp[j]
			var dv: Vector3 = col[mini(j + 1, height - 1)] - col[maxi(j - 1, 0)]
			var nrm: Vector3 = dv.cross(du)
			# Outward: the right half's section runs counter-clockwise from the bottom.
			var sec_out := Vector2(dv.y, -dv.x)
			if Vector2(nrm.x, nrm.y).dot(sec_out) < 0.0 and sec_out.length_squared() > 1e-12:
				nrm = -nrm
			nrm = nrm.normalized()
			# Texel footprint in metres, for anti-aliasing.
			var fp: float = maxf(maxf(du.length() * 0.5, dv.length() * 0.5), 0.0008)
			img.set_pixel(i, j, _detail_at(p, nrm, fp, shapes))
	img.generate_mipmaps()
	return img


## Shapes the car's _detail_at() needs, built once per map.
func _detail_shapes() -> Dictionary:
	return {}


## The detail texel at surface point p (right half) with normal n, `fp` metres across.
func _detail_at(_p: Vector3, _n: Vector3, _fp: float, _shapes: Dictionary) -> Color:
	return Color(0, 0, 0, 0)


## Coverage of a signed distance (negative inside) over a texel `fp` metres across.
static func _cover(d: float, fp: float) -> float:
	return clampf(0.5 - d / fp, 0.0, 1.0)


static func _sd_box(p: Vector2, h: Vector2) -> float:
	var d := Vector2(absf(p.x), absf(p.y)) - h
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0)


## Signed distance to a polygon (negative inside), after Inigo Quilez.
static func _sd_poly(p: Vector2, v: PackedVector2Array) -> float:
	var d: float = (p - v[0]).length_squared()
	var s := 1.0
	var n: int = v.size()
	var j: int = n - 1
	for i in n:
		var e: Vector2 = v[j] - v[i]
		var w: Vector2 = p - v[i]
		var bq: Vector2 = w - e * clampf(w.dot(e) / e.dot(e), 0.0, 1.0)
		d = minf(d, bq.length_squared())
		var c1: bool = p.y >= v[i].y
		var c2: bool = p.y < v[j].y
		var c3: bool = e.x * w.y > e.y * w.x
		if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
			s = -s
		j = i
	return s * sqrt(d)


## A rounded polygon: `shape` is [inset polygon, radius] from _inset().
static func _sd_rounded(p: Vector2, shape: Array) -> float:
	return _sd_poly(p, shape[0]) - shape[1]


## Insets a convex polygon by r (for rounded corners: the SDF of the inset minus r).
static func _inset(v: PackedVector2Array, r: float) -> Array:
	var n: int = v.size()
	var area := 0.0
	for k in n:
		area += v[k].cross(v[(k + 1) % n])
	var sgn: float = 1.0 if area > 0.0 else -1.0
	var lines := []
	for k in n:
		var a: Vector2 = v[k]
		var e: Vector2 = (v[(k + 1) % n] - a).normalized()
		lines.append([a + Vector2(-e.y, e.x) * sgn * r, e])
	var out := PackedVector2Array()
	for k in n:
		var l0: Array = lines[(k - 1 + n) % n]
		var l1: Array = lines[k]
		var p0: Vector2 = l0[0]
		var d0: Vector2 = l0[1]
		var p1: Vector2 = l1[0]
		var d1: Vector2 = l1[1]
		var den: float = d0.cross(d1)
		out.append(p1 if absf(den) < 1e-9 else p0 + d0 * ((p1 - p0).cross(d1) / den))
	return [out, r]
