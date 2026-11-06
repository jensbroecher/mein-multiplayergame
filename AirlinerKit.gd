extends RefCounted
## Procedural airliners for the skies over the Al-Raihana GP (Airliners.gd flies them; regenerate_airliners.gd saves
## them). Two airframes, generic shapes of no real type: "twin", a wide-body twin-jet (64.5m long, 62m across its
## winglets), and "quad", a four-engine wide-body (71m, 66m). Life size, the nose toward -z, y up, the right wing on +x,
## the origin on the fuselage's axis at the wing root.
##
## The airframe is one mesh with no livery in it: COLOR.r is the part (`P_*`, / 16), and airliner_body.gdshader paints
## each part from the livery's uniforms, so a livery is a material and every airframe takes every livery. The shader
## draws the windows, doors, cheatlines, belly and tail art from the model position (`mpos`) and UV2 (x the angle round
## the fuselage from its top, either side; y the fuselage section's centre height there). Each gear leg is a
## mesh of its own built about its hinge (`gear`: the hinge's place and the axis it folds about), and the lights are a
## mesh of sprites (airliner_lights.gdshader: every corner of a sprite at its light, UV the corner, UV2 its size and
## kind, COLOR its colour and flash phase).

const P_FUSE := 0
const P_WING := 1
const P_FIN := 2
const P_STAB := 3
const P_COWL := 4
const P_LIP := 5
const P_DARK := 6
const P_CORE := 7
const P_PLAIN := 8
const P_STRUT := 9
const P_TYRE := 10
const P_FAIRING := 11
const P_WINGLET := 12
const P_FTF := 13
const P_HUB := 14
const P_SPINNER := 15

## Light sprite kinds (UV2.y).
const L_NAV := 0
const L_STROBE := 1
const L_BEACON := 2
const L_LANDING := 3

const FRAMES := {
	"twin": {
		"nose": -31.5, "cyl0": -22.5, "cyl1": 11.0, "tail": 33.0, "R": 3.0, "nose_y": -0.55,
		"q_top": 1.75, "q_bot": 2.4, "q_w": 2.05, "tail_top": 1.35, "tail_bot": 0.6, "tail_hw": 0.38,
		# Wing: the leading edge's root (x, y, z), its sweep and dihedral (degrees), the inner trailing edge (straight
		# back from the root to the kink), the kink and tip x, the tip chord.
		"wing_root": Vector3(1.2, -1.5, -7.6), "sweep": 31.0, "dihedral": 6.0, "te_in": 6.0, "kink": 10.5, "tip": 30.0,
		"tip_chord": 2.3, "winglet": 4.4,
		"engines": [10.0], "nac_r": 1.86, "nac_len": 7.4, "nac_ahead": 5.0,
		"stab_root": Vector3(0.5, 0.95, 23.6), "stab_chord": 7.2, "stab_tip": 10.8, "stab_tip_chord": 2.35,
		"fin_le0": Vector2(17.0, 2.9), "fin_le1": Vector2(26.2, 13.6), "fin_te0": Vector2(30.0, 1.9), "fin_te1": Vector2(30.7, 13.6),
		"fairing": [-10.0, 10.5, 3.35, -3.45],
		"main_gear": Vector3(4.4, -2.1, 2.3), "axles": 2, "nose_gear": Vector3(0.0, -2.3, -24.6),
		"doors": [-24.0, -12.5, 4.6, 14.6], "win0": -25.0, "win1": 15.6,
		"ftf": [6.5, 15.5, 21.0, 25.5],
	},
	"quad": {
		"nose": -34.5, "cyl0": -25.0, "cyl1": 12.5, "tail": 36.5, "R": 3.2, "nose_y": -0.6,
		"q_top": 1.75, "q_bot": 2.4, "q_w": 2.05, "tail_top": 1.45, "tail_bot": 0.65, "tail_hw": 0.4,
		"wing_root": Vector3(1.3, -1.6, -8.4), "sweep": 33.0, "dihedral": 5.5, "te_in": 6.4, "kink": 12.0, "tip": 32.0,
		"tip_chord": 2.5, "winglet": 3.6,
		"engines": [10.6, 20.4], "nac_r": 1.52, "nac_len": 6.5, "nac_ahead": 4.4,
		"stab_root": Vector3(0.5, 1.0, 26.0), "stab_chord": 7.6, "stab_tip": 11.5, "stab_tip_chord": 2.5,
		"fin_le0": Vector2(19.0, 3.1), "fin_le1": Vector2(28.6, 14.6), "fin_te0": Vector2(32.6, 2.0), "fin_te1": Vector2(33.4, 14.6),
		"fairing": [-11.0, 11.5, 3.55, -3.7],
		"main_gear": Vector3(4.6, -2.2, 2.6), "axles": 3, "nose_gear": Vector3(0.0, -2.4, -27.4),
		"doors": [-27.0, -14.5, 5.0, 16.0], "win0": -28.0, "win1": 17.2,
		"ftf": [6.5, 15.5, 25.0, 28.5],
	},
}

## The main wheels' contact patch below the origin: where Airliners.gd stands an airframe on its path (life size).
static func contact(frame: String) -> Vector3:
	var f: Dictionary = FRAMES[frame]
	var g: Vector3 = f.main_gear
	return Vector3(0.0, g.y - _main_drop(f) - _main_wheel_r(f), g.z)


static func _main_drop(f: Dictionary) -> float:
	return 3.6 if f.axles == 2 else 3.75


static func _main_wheel_r(f: Dictionary) -> float:
	return 0.64 if f.axles == 2 else 0.66


# ======================================================================================
#  Mesh builder: one SurfaceTool, every vertex carrying its part, UV and UV2
# ======================================================================================

class MB:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A triangle facing `out` (Godot's front faces wind clockwise: (c - a) x (b - a) points out).
	func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, part: int, out: Vector3,
			ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, va := Vector2.ZERO, vb := Vector2.ZERO, vc := Vector2.ZERO) -> void:
		if (c - a).cross(b - a).dot(out) < 0.0:
			var tp := b
			b = c
			c = tp
			var tn := nb
			nb = nc
			nc = tn
			var tu := ub
			ub = uc
			uc = tu
			var tv := vb
			vb = vc
			vc = tv
		var col := Color((float(part) + 0.5) / 16.0, 0.0, 0.0, 1.0)
		for v in [[a, na, ua, va], [b, nb, ub, vb], [c, nc, uc, vc]]:
			st.set_color(col)
			st.set_normal(v[1])
			st.set_uv(v[2])
			st.set_uv2(v[3])
			st.add_vertex(v[0])

	## A grid of rows (stations) by columns (points round a section), smooth normals worked out from the neighbours,
	## turned away from each row's centre. `closed`: the columns wrap round. UV/UV2 per point, or zero.
	func loft(P: Array, part: int, closed: bool, centres: Array, U: Array = [], V: Array = []) -> void:
		var ni: int = P.size()
		var nk: int = (P[0] as Array).size()
		var N: Array = []
		for i in range(ni):
			var row: Array = []
			for k in range(nk):
				var kp: int = (k + 1) % nk if closed else mini(k + 1, nk - 1)
				var km: int = (k - 1 + nk) % nk if closed else maxi(k - 1, 0)
				var ip: int = mini(i + 1, ni - 1)
				var im: int = maxi(i - 1, 0)
				var t_ring: Vector3 = (P[i][kp] as Vector3) - (P[i][km] as Vector3)
				var t_span: Vector3 = (P[ip][k] as Vector3) - (P[im][k] as Vector3)
				var n: Vector3 = t_span.cross(t_ring)
				var away: Vector3 = (P[i][k] as Vector3) - (centres[i] as Vector3)
				if n.length_squared() < 1e-12:
					n = away
				n = n.normalized()
				if n.dot(away) < 0.0:
					n = -n
				row.append(n)
			N.append(row)
		var cols: int = nk if closed else nk - 1
		for i in range(ni - 1):
			for k in range(cols):
				var k2: int = (k + 1) % nk
				var a: Vector3 = P[i][k]
				var b: Vector3 = P[i][k2]
				var c: Vector3 = P[i + 1][k2]
				var d: Vector3 = P[i + 1][k]
				var na: Vector3 = N[i][k]
				var nb: Vector3 = N[i][k2]
				var nc: Vector3 = N[i + 1][k2]
				var nd: Vector3 = N[i + 1][k]
				var out: Vector3 = (na + nb + nc + nd)
				var ua := Vector2.ZERO
				var ub := Vector2.ZERO
				var uc := Vector2.ZERO
				var ud := Vector2.ZERO
				if not U.is_empty():
					ua = U[i][k]
					ub = U[i][k2]
					uc = U[i + 1][k2]
					ud = U[i + 1][k]
				var va := Vector2.ZERO
				var vb := Vector2.ZERO
				var vc := Vector2.ZERO
				var vd := Vector2.ZERO
				if not V.is_empty():
					va = V[i][k]
					vb = V[i][k2]
					vc = V[i + 1][k2]
					vd = V[i + 1][k]
				tri(a, b, c, na, nb, nc, part, out, ua, ub, uc, va, vb, vc)
				tri(a, c, d, na, nc, nd, part, out, ua, uc, ud, va, vc, vd)

	## A flat fan closing a ring of points (a section's end), facing `out`.
	func cap(ring: Array, centre: Vector3, part: int, out: Vector3, uv2 := Vector2.ZERO) -> void:
		var n := out.normalized()
		for k in range(ring.size()):
			var a: Vector3 = ring[k]
			var b: Vector3 = ring[(k + 1) % ring.size()]
			tri(centre, a, b, n, n, n, part, n, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, uv2, uv2, uv2)

	## A surface of revolution about the axis through `c` along `axis` (with `side` a unit vector across it): `profile`
	## holds [radius, distance along the axis, part] walking so that the outside of the surface is on the walk's
	## left looking along the axis (the outer cowl walks backward, the inside of an inlet forward). Each segment takes
	## its own part. Normals are smooth across segments that turn less than `crease` (radians).
	func lathe(c: Vector3, axis: Vector3, side: Vector3, profile: Array, segs: int, crease := 0.7) -> void:
		var up := axis.cross(side).normalized()
		var nseg: int = profile.size() - 1
		var n2s: Array = []
		for j in range(nseg):
			var p0: Array = profile[j]
			var p1: Array = profile[j + 1]
			var d := Vector2(float(p1[0]) - float(p0[0]), float(p1[1]) - float(p0[1]))
			n2s.append(Vector2(d.y, -d.x).normalized() if d.length_squared() > 1e-12 else Vector2.ZERO)
		for j in range(nseg):
			var p0: Array = profile[j]
			var p1: Array = profile[j + 1]
			var n2: Vector2 = n2s[j]
			if n2 == Vector2.ZERO:
				continue
			var n_a: Vector2 = n2
			var n_b: Vector2 = n2
			if j > 0 and (n2s[j - 1] as Vector2) != Vector2.ZERO and (n2s[j - 1] as Vector2).angle_to(n2) < crease and (n2s[j - 1] as Vector2).angle_to(n2) > -crease:
				n_a = ((n2s[j - 1] as Vector2) + n2).normalized()
			if j < nseg - 1 and (n2s[j + 1] as Vector2) != Vector2.ZERO and (n2s[j + 1] as Vector2).angle_to(n2) < crease and (n2s[j + 1] as Vector2).angle_to(n2) > -crease:
				n_b = ((n2s[j + 1] as Vector2) + n2).normalized()
			var part: int = int(p0[2])
			for s in range(segs):
				var t0: float = TAU * float(s) / float(segs)
				var t1: float = TAU * float(s + 1) / float(segs)
				var r0 := side * cos(t0) + up * sin(t0)
				var r1 := side * cos(t1) + up * sin(t1)
				var q00: Vector3 = c + r0 * float(p0[0]) + axis * float(p0[1])
				var q01: Vector3 = c + r1 * float(p0[0]) + axis * float(p0[1])
				var q10: Vector3 = c + r0 * float(p1[0]) + axis * float(p1[1])
				var q11: Vector3 = c + r1 * float(p1[0]) + axis * float(p1[1])
				var na0: Vector3 = (r0 * n_a.x + axis * n_a.y).normalized()
				var na1: Vector3 = (r1 * n_a.x + axis * n_a.y).normalized()
				var nb0: Vector3 = (r0 * n_b.x + axis * n_b.y).normalized()
				var nb1: Vector3 = (r1 * n_b.x + axis * n_b.y).normalized()
				var out: Vector3 = ((r0 + r1).normalized() * n2.x + axis * n2.y)
				var uv0 := Vector2(float(p0[1]), t0)
				var uv1 := Vector2(float(p1[1]), t1)
				if float(p0[0]) > 1e-5:
					tri(q00, q01, q11, na0, na1, nb1, part, out, uv0, Vector2(uv0.x, t1), uv1)
				if float(p1[0]) > 1e-5:
					tri(q00, q11, q10, na0, nb1, nb0, part, out, uv0, uv1, Vector2(uv1.x, t0))

	## A tube from a to b (radius ra to rb), capped.
	func tube(a: Vector3, b: Vector3, ra: float, rb: float, segs: int, part: int) -> void:
		var axis := (b - a)
		var L := axis.length()
		if L < 1e-5:
			return
		axis /= L
		var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		lathe(a, axis, side, [[0.0, 0.0, part], [ra, 0.0, part], [rb, L, part], [0.0, L, part]], segs, 0.3)

	## A box (centre, half sizes) in a basis.
	func box(c: Vector3, h: Vector3, part: int, b := Basis()) -> void:
		var ax := [b.x.normalized() * h.x, b.y.normalized() * h.y, b.z.normalized() * h.z]
		for i in range(3):
			for sgn in [-1.0, 1.0]:
				var n: Vector3 = (ax[i] as Vector3).normalized() * sgn
				var u: Vector3 = ax[(i + 1) % 3]
				var v: Vector3 = ax[(i + 2) % 3]
				var f: Vector3 = c + (ax[i] as Vector3) * sgn
				tri(f - u - v, f + u - v, f + u + v, n, n, n, part, n)
				tri(f - u - v, f + u + v, f - u + v, n, n, n, part, n)

	func commit() -> ArrayMesh:
		st.index()
		return st.commit()


# ======================================================================================
#  The airframe
# ======================================================================================

## The airframe (no gear, no lights) as one mesh, its material left unset (Airliners.gd puts the livery on).
static func airframe(frame: String) -> ArrayMesh:
	var f: Dictionary = FRAMES[frame]
	var mb := MB.new()
	_fuselage(mb, f)
	_fairing(mb, f)
	for sgn in [-1.0, 1.0]:
		_wing(mb, f, sgn)
		_stab(mb, f, sgn)
		for ex in f.engines:
			_engine(mb, f, float(ex) * sgn)
		for fx in f.ftf:
			_ftf(mb, f, float(fx) * sgn)
	_fin(mb, f)
	return mb.commit()


## The fuselage's section at z: (centre height, half width, half height).
static func section(f: Dictionary, z: float) -> Vector3:
	var R: float = f.R
	if z <= float(f.cyl0):
		var u: float = clampf((z - float(f.nose)) / (float(f.cyl0) - float(f.nose)), 0.0, 1.0)
		var tip_y: float = f.nose_y
		var top: float = tip_y + (R - tip_y) * _ell(u, f.q_top)
		var bot: float = tip_y - (R + tip_y) * _ell(u, f.q_bot)
		var hw: float = R * _ell(u, f.q_w)
		return Vector3((top + bot) * 0.5, hw, (top - bot) * 0.5)
	if z >= float(f.cyl1):
		var v: float = clampf((z - float(f.cyl1)) / (float(f.tail) - float(f.cyl1)), 0.0, 1.0)
		var top: float = R - (R - float(f.tail_top)) * pow(v, 1.8)
		# The upsweep: no slope where it leaves the cylinder, nearly straight up to the tail cone's end.
		var sweep: float = v * v / (v + 0.25) * 1.25
		var bot: float = -R + (R + float(f.tail_bot)) * sweep
		var hw: float = R - (R - float(f.tail_hw)) * pow(v, 1.6)
		return Vector3((top + bot) * 0.5, hw, (top - bot) * 0.5)
	return Vector3(0.0, R, R)


static func _ell(u: float, q: float) -> float:
	return pow(maxf(1.0 - (1.0 - u) * (1.0 - u), 0.0), 1.0 / q)


static func _fuselage(mb: MB, f: Dictionary) -> void:
	var ring_n := 44
	var zs: Array = []
	# Stations: crowded toward the nose's tip, every 2.5m along the cylinder, even down the tail cone.
	var nose: float = f.nose
	for k in range(1, 25):
		var u: float = pow(float(k) / 24.0, 1.7)
		zs.append(nose + (float(f.cyl0) - nose) * u)
	var z: float = float(f.cyl0) + 2.5
	while z < float(f.cyl1) - 0.5:
		zs.append(z)
		z += 2.5
	for k in range(0, 21):
		zs.append(float(f.cyl1) + (float(f.tail) - float(f.cyl1)) * float(k) / 20.0)
	var P: Array = []
	var C: Array = []
	var V: Array = []
	for zz in zs:
		var s := section(f, zz)
		var row: Array = []
		var vrow: Array = []
		for k in range(ring_n):
			# k = 0 at the top, round the right side (+x) to the bottom and back up the left.
			var th: float = TAU * float(k) / float(ring_n)
			var p := Vector3(s.y * sin(th), s.x + s.z * cos(th), zz)
			row.append(p)
			var phi: float = th if th <= PI else th - TAU
			vrow.append(Vector2(absf(phi), s.x))
		P.append(row)
		C.append(Vector3(0.0, s.x, zz))
		V.append(vrow)
	mb.loft(P, P_FUSE, true, C, [], V)
	# The nose's tip: a fan to the point.
	var tip := Vector3(0.0, f.nose_y, nose)
	var first: Array = P[0]
	for k in range(ring_n):
		var a: Vector3 = first[k]
		var b: Vector3 = first[(k + 1) % ring_n]
		var na := (a - Vector3(0, a.y, a.z)).normalized() * 0.35 + Vector3(0, 0, -1)
		var nb := (b - Vector3(0, b.y, b.z)).normalized() * 0.35 + Vector3(0, 0, -1)
		mb.tri(tip, a, b, Vector3(0, 0, -1), na.normalized(), nb.normalized(), P_FUSE, Vector3(0, 0, -1),
				Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2(0.0, f.nose_y), V[0][k], V[0][(k + 1) % ring_n])
	# The tail cone's end: the APU's exhaust, a dark disc set a little in.
	var last: Array = P[P.size() - 1]
	var s_end := section(f, f.tail)
	var cin := Vector3(0.0, s_end.x, float(f.tail) - 0.25)
	var inner: Array = []
	for k in range(ring_n):
		var p: Vector3 = last[k]
		inner.append(Vector3(p.x * 0.8, s_end.x + (p.y - s_end.x) * 0.8, float(f.tail)))
	mb.cap(inner, cin, P_DARK, Vector3(0, 0, 1))
	for k in range(ring_n):
		var a: Vector3 = last[k]
		var b: Vector3 = last[(k + 1) % ring_n]
		var c: Vector3 = inner[(k + 1) % ring_n]
		var d: Vector3 = inner[k]
		var n := Vector3(0, 0, 1)
		mb.tri(a, b, c, n, n, n, P_CORE, n)
		mb.tri(a, c, d, n, n, n, P_CORE, n)


## The wing-body fairing: a broad, shallow belly under the wing's root, its ends tucked inside the fuselage.
static func _fairing(mb: MB, f: Dictionary) -> void:
	var fa: Array = f.fairing
	var z0: float = fa[0]
	var z1: float = fa[1]
	var hw_max: float = fa[2]
	var bot_max: float = fa[3]
	var R: float = f.R
	var ring_n := 36
	var P: Array = []
	var C: Array = []
	for k in range(0, 23):
		var t: float = float(k) / 22.0
		var zz: float = lerpf(z0, z1, t)
		var bulge: float = sin(PI * t)
		bulge = pow(bulge, 0.55)
		var hw: float = lerpf(R * 0.72, hw_max, bulge)
		var bot: float = lerpf(-R * 0.93, bot_max, bulge)
		var top: float = -0.2
		var cy: float = (top + bot) * 0.5
		var ry: float = (top - bot) * 0.5
		var row: Array = []
		for j in range(ring_n):
			var th: float = TAU * float(j) / float(ring_n)
			row.append(Vector3(hw * sin(th), cy + ry * cos(th), zz))
		P.append(row)
		C.append(Vector3(0.0, cy, zz))
	mb.loft(P, P_FAIRING, true, C)


## An airfoil section's points: from the trailing edge along the upper surface to the leading edge and back along the
## lower one (the trailing edge twice), `n` points a surface, in the frame (le, chord direction, up), `chord` long,
## `tc` thick, cambered by `camber`.
static func _airfoil(le: Vector3, cdir: Vector3, up: Vector3, chord: float, tc: float, camber: float, n := 13) -> Array:
	var pts: Array = []
	for i in range(2 * n + 1):
		var upper: bool = i <= n
		var k: int = n - i if upper else i - n
		var t: float = (1.0 - cos(PI * float(k) / float(n))) * 0.5
		var yt: float = 5.0 * tc * (0.2969 * sqrt(t) - 0.1260 * t - 0.3516 * t * t + 0.2843 * t * t * t - 0.1015 * t * t * t * t)
		var m: float = camber * 4.0 * t * (1.0 - t)
		var y: float = m + yt if upper else m - yt
		pts.append(le + cdir * (t * chord) + up * (y * chord))
	return pts


## A lifting surface from sections [le, chord dir, up, chord, tc, camber] in order along its span, closed at the last.
static func _surface(mb: MB, secs: Array, part: int, close_tip := true, uv_span := true) -> void:
	var P: Array = []
	var C: Array = []
	var U: Array = []
	var span := 0.0
	for i in range(secs.size()):
		var s: Array = secs[i]
		if i > 0:
			span += ((s[0] as Vector3) - ((secs[i - 1] as Array)[0] as Vector3)).length()
		var pts := _airfoil(s[0], s[1], s[2], s[3], s[4], s[5])
		P.append(pts)
		C.append((s[0] as Vector3) + (s[1] as Vector3) * (float(s[3]) * 0.45))
		var urow: Array = []
		var n: int = (pts.size() - 1) >> 1
		for k in range(pts.size()):
			var kk: int = absi(k - n)
			var t: float = (1.0 - cos(PI * float(kk) / float(n))) * 0.5
			urow.append(Vector2(span if uv_span else 0.0, t))
		U.append(urow)
	mb.loft(P, part, false, C, U)
	if close_tip:
		var last: Array = P[P.size() - 1]
		var cen := Vector3.ZERO
		for p in last:
			cen += p
		cen /= float(last.size())
		var prev: Array = P[P.size() - 2]
		var cprev := Vector3.ZERO
		for p in prev:
			cprev += p
		cprev /= float(prev.size())
		var ring := last.slice(0, last.size() - 1)
		mb.cap(ring, cen, part, cen - cprev)


static func _wing(mb: MB, f: Dictionary, sgn: float) -> void:
	var root: Vector3 = f.wing_root
	var tan_sw: float = tan(deg_to_rad(f.sweep))
	var tan_dh: float = tan(deg_to_rad(f.dihedral))
	var kink: float = f.kink
	var tip: float = f.tip
	var te_in: float = f.te_in
	var tip_le_z: float = root.z + (tip - root.x) * tan_sw
	var te_tip: float = tip_le_z + float(f.tip_chord)
	var secs: Array = []
	var dh: float = deg_to_rad(f.dihedral)
	for x in [root.x, root.x + 2.2, (root.x + kink) * 0.5, kink, (kink + tip) * 0.5, tip - 4.0, tip]:
		var le := Vector3(x * sgn, root.y + (x - root.x) * tan_dh, root.z + (x - root.x) * tan_sw)
		var te: float
		if x <= kink:
			te = te_in
		else:
			te = lerpf(te_in, te_tip, (x - kink) / (tip - kink))
		var chord: float = te - le.z
		var u: float = (x - root.x) / (tip - root.x)
		var tc: float = lerpf(0.15, 0.10, clampf(u * 1.6, 0.0, 1.0))
		# Washout: the root's leading edge 2 degrees up, the tip's 2.5 down.
		var tw: float = deg_to_rad(lerpf(2.0, -2.5, u))
		var cdir := Vector3(0.0, -sin(tw), cos(tw))
		var up := Vector3(-sin(dh) * sgn, cos(dh), 0.0)
		up = (up - cdir * up.dot(cdir)).normalized()
		secs.append([le, cdir, up, chord, tc, 0.022])
	# The blended winglet: the tip bends up through a 1.2m arc, then rises, swept back, its chord shrinking.
	var tle: Vector3 = (secs[secs.size() - 1] as Array)[0]
	var tch: float = f.tip_chord
	var wl: float = f.winglet
	var rad := 1.2
	var arc_len := 0.0
	var prev_p := tle
	for a_deg in [22.0, 45.0, 66.0, 84.0]:
		var a: float = deg_to_rad(a_deg)
		var off := Vector2(rad * sin(a), rad * (1.0 - cos(a)))
		var p := Vector3(tle.x + off.x * sgn, tle.y + off.y, 0.0)
		arc_len += Vector2(p.x - prev_p.x, p.y - prev_p.y).length()
		p.z = tle.z + arc_len * tan(deg_to_rad(36.0))
		prev_p = p
		var up := Vector3(-sin(a + dh) * sgn, cos(a + dh), 0.0)
		secs.append([p, Vector3(0, 0, 1), up, lerpf(tch, tch * 0.82, a_deg / 84.0), 0.10, 0.015])
	var top_a := deg_to_rad(84.0)
	var dir := Vector3(cos(top_a) * sgn, sin(top_a), 0.0)
	for h in [wl * 0.45, wl]:
		var p: Vector3 = prev_p + dir * h
		p.z = prev_p.z + h * tan(deg_to_rad(38.0))
		var up := Vector3(-sin(top_a + dh) * sgn, cos(top_a + dh), 0.0)
		secs.append([p, Vector3(0, 0, 1), up, lerpf(tch * 0.82, tch * 0.42, h / wl), 0.09, 0.01])
	_surface(mb, secs.slice(0, 7), P_WING, false)
	_surface(mb, secs.slice(6), P_WINGLET, true)


static func _stab(mb: MB, f: Dictionary, sgn: float) -> void:
	var root: Vector3 = f.stab_root
	var tip_x: float = f.stab_tip
	var tan_sw := tan(deg_to_rad(35.0))
	var dh := deg_to_rad(7.0)
	var secs: Array = []
	for x in [root.x, (root.x + tip_x) * 0.5, tip_x]:
		var u: float = (x - root.x) / (tip_x - root.x)
		var le := Vector3(x * sgn, root.y + (x - root.x) * tan(dh), root.z + (x - root.x) * tan_sw)
		var chord: float = lerpf(f.stab_chord, f.stab_tip_chord, u)
		var up := Vector3(-sin(dh) * sgn, cos(dh), 0.0)
		secs.append([le, Vector3(0, 0, 1), up, chord, lerpf(0.11, 0.09, u), -0.01])
	_surface(mb, secs, P_STAB, true)


static func _fin(mb: MB, f: Dictionary) -> void:
	var le0: Vector2 = f.fin_le0
	var le1: Vector2 = f.fin_le1
	var te0: Vector2 = f.fin_te0
	var te1: Vector2 = f.fin_te1
	var secs: Array = []
	var ys: Array = [te0.y - 0.6, le0.y, le0.y + (le1.y - le0.y) * 0.3, le0.y + (le1.y - le0.y) * 0.65, le1.y]
	for i in range(ys.size()):
		var y: float = ys[i]
		var tl: float = (y - le0.y) / (le1.y - le0.y)
		var tt: float = (y - te0.y) / (te1.y - te0.y)
		var le := Vector3(0.0, y, lerpf(le0.x, le1.x, tl))
		var te := Vector3(0.0, maxf(y, te0.y) if i == 0 else y, lerpf(te0.x, te1.x, tt))
		if i == 0:
			# The root runs down the tail cone's falling top: its leading edge low and well forward.
			le = Vector3(0.0, le0.y - 0.45, le0.x - 1.2)
			te = Vector3(0.0, te0.y - 0.5, te0.x)
		var c: Vector3 = te - le
		var chord: float = c.length()
		var cdir: Vector3 = c / chord
		var up := Vector3(1.0, 0.0, 0.0)
		secs.append([le, cdir, up, chord, lerpf(0.10, 0.085, clampf(tl, 0.0, 1.0)), 0.0])
	_surface(mb, secs, P_FIN, true, false)
	# The dorsal fillet: a low, thin fairing running forward from the fin's root along the top of the fuselage.
	var P: Array = []
	var C: Array = []
	var z0: float = le0.x - 7.0
	var z1: float = le0.x + 1.5
	for k in range(0, 9):
		var t: float = float(k) / 8.0
		var zz: float = lerpf(z0, z1, t)
		var s := section(f, zz)
		var top_y: float = s.x + s.z
		var h: float = pow(t, 1.6) * 1.25
		var w: float = lerpf(0.06, 0.42, pow(t, 0.8))
		var row: Array = []
		for j in range(13):
			var th: float = PI * float(j) / 12.0
			row.append(Vector3(w * cos(th), top_y - 0.25 + (h + 0.25) * sin(th), zz))
		P.append(row)
		C.append(Vector3(0.0, top_y - 0.3, zz))
	mb.loft(P, P_FIN, false, C)


static func _engine(mb: MB, f: Dictionary, ex: float) -> void:
	var root: Vector3 = f.wing_root
	var ax: float = absf(ex)
	var le_z: float = root.z + (ax - root.x) * tan(deg_to_rad(f.sweep))
	var le_y: float = root.y + (ax - root.x) * tan(deg_to_rad(f.dihedral))
	var r: float = f.nac_r
	var L: float = f.nac_len
	var cy: float = le_y - 0.62 - r
	var front: float = le_z - float(f.nac_ahead)
	var c := Vector3(ex, cy, front)
	var k: float = r / 1.86
	var kl: float = L / 7.4
	# Walks with the surface's outside on its left: the inlet's inside forward from the fan, round the lip, back along
	# the cowl to the fan nozzle, in across its exit, back along the core cowl, the core nozzle and the plug.
	var prof := [
		[1.50 * k, 1.10 * kl, P_LIP], [1.55 * k, 0.40 * kl, P_LIP], [1.60 * k, 0.10 * kl, P_LIP], [1.67 * k, 0.0, P_LIP],
		[1.76 * k, 0.05 * kl, P_LIP], [1.82 * k, 0.22 * kl, P_COWL], [1.86 * k, 0.70 * kl, P_COWL], [1.87 * k, 1.60 * kl, P_COWL],
		[1.84 * k, 2.70 * kl, P_COWL], [1.74 * k, 3.80 * kl, P_COWL], [1.58 * k, 4.62 * kl, P_COWL], [1.52 * k, 4.64 * kl, P_DARK],
		[1.16 * k, 4.58 * kl, P_DARK], [1.16 * k, 4.70 * kl, P_CORE], [1.04 * k, 5.80 * kl, P_CORE], [0.86 * k, 6.55 * kl, P_CORE],
		[0.78 * k, 6.58 * kl, P_DARK], [0.62 * k, 6.45 * kl, P_DARK], [0.58 * k, 6.50 * kl, P_CORE], [0.36 * k, 7.05 * kl, P_CORE],
		[0.06 * k, 7.45 * kl, P_CORE], [0.0, 7.48 * kl, P_CORE],
	]
	mb.lathe(c, Vector3(0, 0, 1), Vector3(1, 0, 0), prof, 30, 0.75)
	# The fan: a dark disc with the spinner in front of it.
	var fan := [[0.0, 0.42 * kl, P_SPINNER], [0.22 * k, 0.56 * kl, P_SPINNER], [0.40 * k, 0.86 * kl, P_SPINNER],
			[0.50 * k, 1.12 * kl, P_SPINNER], [0.52 * k, 1.12 * kl, P_DARK], [1.50 * k, 1.12 * kl, P_DARK]]
	mb.lathe(c, Vector3(0, 0, 1), Vector3(1, 0, 0), fan, 24, 0.6)
	# The pylon: a slender fairing from the cowl's top up into the wing, running back under it.
	var top_y: float = cy + 1.80 * k
	var w := 0.30 * k
	var z_a: float = front + 1.6 * kl
	var z_b: float = front + 5.4 * kl
	var z_c: float = le_z - 0.9
	var z_d: float = le_z + 4.2
	var y_w: float = le_y - 0.10
	var side: Array = [Vector2(z_a, top_y - 0.2), Vector2(z_b + 0.9, top_y - 0.2), Vector2(z_d, y_w + 0.15),
			Vector2(z_c, y_w + 0.15), Vector2(z_a - 0.4, top_y + 0.35)]
	_prism_x(mb, side, ex, w, P_PLAIN)


## A side outline (z, y) extruded `w` either side of x, its sides flat, its top and bottom bevelled in a little.
static func _prism_x(mb: MB, outline: Array, x: float, w: float, part: int) -> void:
	var n: int = outline.size()
	var cen := Vector2.ZERO
	for p in outline:
		cen += p
	cen /= float(n)
	for sgn in [-1.0, 1.0]:
		var nrm := Vector3(sgn, 0, 0)
		var cc := Vector3(x + w * sgn, cen.y, cen.x)
		for i in range(n):
			var a: Vector2 = outline[i]
			var b: Vector2 = outline[(i + 1) % n]
			mb.tri(cc, Vector3(x + w * sgn, a.y, a.x), Vector3(x + w * sgn, b.y, b.x), nrm, nrm, nrm, part, nrm)
	for i in range(n):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		var e := b - a
		var n2 := Vector2(e.y, -e.x).normalized()
		if n2.dot((a + b) * 0.5 - cen) < 0.0:
			n2 = -n2
		var nrm := Vector3(0, n2.y, n2.x)
		var p0 := Vector3(x - w, a.y, a.x)
		var p1 := Vector3(x + w, a.y, a.x)
		var p2 := Vector3(x + w, b.y, b.x)
		var p3 := Vector3(x - w, b.y, b.x)
		mb.tri(p0, p1, p2, nrm, nrm, nrm, part, nrm)
		mb.tri(p0, p2, p3, nrm, nrm, nrm, part, nrm)


## A flap track fairing: a slim canoe under the wing at x, from ahead of the trailing edge to past it.
static func _ftf(mb: MB, f: Dictionary, x: float) -> void:
	var root: Vector3 = f.wing_root
	var ax: float = absf(x)
	var le_z: float = root.z + (ax - root.x) * tan(deg_to_rad(f.sweep))
	var le_y: float = root.y + (ax - root.x) * tan(deg_to_rad(f.dihedral))
	var tip: float = f.tip
	var kink: float = f.kink
	var te_tip: float = root.z + (tip - root.x) * tan(deg_to_rad(f.sweep)) + float(f.tip_chord)
	var te: float = float(f.te_in) if ax <= kink else lerpf(f.te_in, te_tip, (ax - kink) / (tip - kink))
	var chord: float = te - le_z
	var len_: float = clampf(chord * 0.55, 2.4, 5.0)
	var r := clampf(chord * 0.05, 0.16, 0.34)
	var a := Vector3(x, le_y - r * 0.6, te - len_ * 0.72)
	var b := Vector3(x, le_y - r * 0.9 - 0.2, te + len_ * 0.28)
	var axis := (b - a).normalized()
	var L := (b - a).length()
	var prof := [[0.0, 0.0, P_FTF], [r * 0.7, L * 0.08, P_FTF], [r, L * 0.3, P_FTF], [r * 0.85, L * 0.7, P_FTF],
			[r * 0.3, L * 0.95, P_FTF], [0.0, L, P_FTF]]
	mb.lathe(a, axis, Vector3(1, 0, 0), prof, 12, 0.9)


# ======================================================================================
#  Gear and lights
# ======================================================================================

## Each gear leg: [name, mesh, hinge (model space), fold axis, fold angle (radians, up)]. Built about its hinge, hanging
## down, so turning it by the angle about the axis folds it into its well.
static func gear(frame: String) -> Array:
	var f: Dictionary = FRAMES[frame]
	var out: Array = []
	var mg: Vector3 = f.main_gear
	var drop: float = _main_drop(f)
	var wr: float = _main_wheel_r(f)
	for sgn in [1.0, -1.0]:
		var mb := MB.new()
		mb.tube(Vector3.ZERO, Vector3(0, -drop + 0.65, 0), 0.26, 0.24, 14, P_STRUT)
		mb.tube(Vector3(0, -drop + 0.9, 0), Vector3(0, -drop - 0.05, 0), 0.17, 0.17, 12, P_LIP)
		# The side brace up to the wing's spar, and a door on the leg's outer side.
		mb.tube(Vector3(0, -1.5, 0.05), Vector3(-1.25 * sgn, -0.15, 0.25), 0.11, 0.11, 8, P_STRUT)
		mb.box(Vector3(0.36 * sgn, -1.3, 0.0), Vector3(0.04, 1.15, 0.62), P_PLAIN)
		var axles: Array = [-0.9, 0.9] if f.axles == 2 else [-1.3, 0.0, 1.3]
		var bz0: float = float(axles[0]) - 0.35
		var bz1: float = float(axles[axles.size() - 1]) + 0.35
		mb.tube(Vector3(0, -drop, bz0), Vector3(0, -drop, bz1), 0.16, 0.16, 10, P_STRUT)
		var axb := Basis(Vector3(0, 0, 1), -PI * 0.5)
		for az in axles:
			mb.tube(Vector3(-0.85, -drop, az), Vector3(0.85, -drop, az), 0.09, 0.09, 8, P_STRUT)
			for side in [-1.0, 1.0]:
				var wc := Vector3(0.6 * side, -drop, float(az))
				_wheel(mb, wc, wr, 0.48, axb, side)
		out.append(["GearMain%s" % ("R" if sgn > 0.0 else "L"), mb.commit(), Vector3(mg.x * sgn, mg.y, mg.z),
				Vector3(0, 0, 1), -PI * 0.5 * sgn])
	# The nose gear: a leg forward of its wheels, folding forward into the nose.
	var ng: Vector3 = f.nose_gear
	var main_bottom: float = mg.y - drop - wr
	var nwr := 0.53
	var ndrop: float = (main_bottom + nwr) - ng.y
	var nmb := MB.new()
	nmb.tube(Vector3.ZERO, Vector3(0, ndrop + 0.6, 0), 0.2, 0.18, 12, P_STRUT)
	nmb.tube(Vector3(0, ndrop + 0.8, 0), Vector3(0, ndrop, 0), 0.13, 0.13, 10, P_LIP)
	nmb.tube(Vector3(0, -1.0, 0), Vector3(0, -0.2, 1.3), 0.09, 0.09, 8, P_STRUT)
	nmb.tube(Vector3(-0.5, ndrop, 0), Vector3(0.5, ndrop, 0), 0.08, 0.08, 8, P_STRUT)
	for side in [-1.0, 1.0]:
		_wheel(nmb, Vector3(0.38 * side, ndrop, 0.0), nwr, 0.36, Basis(Vector3(0, 0, 1), -PI * 0.5), side)
	out.append(["GearNose", nmb.commit(), ng, Vector3(1, 0, 0), PI * 0.5])
	return out


static func _wheel(mb: MB, c: Vector3, r: float, w: float, axb: Basis, _side: float) -> void:
	var axis: Vector3 = axb.y
	var sidev: Vector3 = axb.x
	var hw := w * 0.5
	# The tyre: a rounded ring; the hub a dish on its outer face.
	var prof := [[r * 0.62, -hw * 0.9, P_TYRE], [r * 0.9, -hw, P_TYRE], [r, -hw * 0.6, P_TYRE], [r, hw * 0.6, P_TYRE],
			[r * 0.9, hw, P_TYRE], [r * 0.62, hw * 0.9, P_TYRE]]
	mb.lathe(c, axis, sidev, prof, 18, 0.9)
	var hub := [[r * 0.62, hw * 0.9, P_HUB], [r * 0.3, hw * 0.72, P_HUB], [0.0, hw * 0.78, P_HUB]]
	mb.lathe(c, axis, sidev, hub, 14, 0.9)
	var hub2 := [[0.0, -hw * 0.78, P_HUB], [r * 0.3, -hw * 0.72, P_HUB], [r * 0.62, -hw * 0.9, P_HUB]]
	mb.lathe(c, axis, sidev, hub2, 14, 0.9)


## The light sprites: [position, colour, kind, size (m), flash phase]. Navigation lights at the wingtips (red left,
## green right) and the tail, strobes beside them, red beacons on the back and the belly, landing lights in the wing
## roots and on the nose gear.
static func light_list(frame: String) -> Array:
	var f: Dictionary = FRAMES[frame]
	var root: Vector3 = f.wing_root
	var tip: float = f.tip
	var tip_le := Vector3(tip, root.y + (tip - root.x) * tan(deg_to_rad(f.dihedral)), root.z + (tip - root.x) * tan(deg_to_rad(f.sweep)))
	var s_tail := section(f, f.tail)
	var red := Color(1.0, 0.12, 0.08)
	var green := Color(0.15, 1.0, 0.35)
	var white := Color(1.0, 0.97, 0.92)
	var R: float = f.R
	var ng: Vector3 = f.nose_gear
	var lights: Array = [
		[Vector3(-tip_le.x - 0.25, tip_le.y + 0.05, tip_le.z + 0.15), red, L_NAV, 0.5, 0.0],
		[Vector3(tip_le.x + 0.25, tip_le.y + 0.05, tip_le.z + 0.15), green, L_NAV, 0.5, 0.0],
		[Vector3(0.0, s_tail.x, float(f.tail) + 0.12), white, L_NAV, 0.45, 0.0],
		[Vector3(-tip_le.x - 0.3, tip_le.y + 0.1, tip_le.z + 1.4), white, L_STROBE, 0.8, 0.0],
		[Vector3(tip_le.x + 0.3, tip_le.y + 0.1, tip_le.z + 1.4), white, L_STROBE, 0.8, 0.0],
		[Vector3(0.0, s_tail.x + 0.15, float(f.tail) + 0.15), white, L_STROBE, 0.7, 0.0],
		[Vector3(0.0, R + 0.18, 0.6), red, L_BEACON, 0.6, 0.0],
		[Vector3(0.0, float((f.fairing as Array)[3]) - 0.12, 4.0), red, L_BEACON, 0.6, 0.5],
		[Vector3(-(root.x + 2.6), root.y - 0.25, root.z + 2.6 * tan(deg_to_rad(f.sweep)) - 0.1), white, L_LANDING, 1.3, 0.0],
		[Vector3(root.x + 2.6, root.y - 0.25, root.z + 2.6 * tan(deg_to_rad(f.sweep)) - 0.1), white, L_LANDING, 1.3, 0.0],
		[Vector3(0.0, ng.y - 1.6, ng.z - 0.35), white, L_LANDING, 1.0, 0.0],
	]
	return lights


static func lights_mesh(frame: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for l in light_list(frame):
		var p: Vector3 = l[0]
		var col: Color = l[1]
		col.a = float(l[4])
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(corners[idx])
			st.set_uv2(Vector2(float(l[3]), float(l[2])))
			st.add_vertex(p)
	return st.commit()


# ======================================================================================
#  Liveries: fictional carriers, one material each (airliner_body.gdshader)
# ======================================================================================

const WHITE := Color(0.95, 0.95, 0.94)
const MAROON := Color(0.42, 0.06, 0.10)
const GOLD := Color(0.88, 0.68, 0.30)

## Shader parameters per livery; anything left out takes the shader's default (Raihana's).
const LIVERIES := {
	# Raihana, Al-Raihana's flag carrier: white over a pale grey belly, a gold cheatline, the maroon tail with the
	# gold star sweeping forward over the rear fuselage, maroon engines.
	"raihana": {"fin_col": MAROON, "art_col": GOLD, "art": 1, "sweep_ahead": 13.5, "engine_col": MAROON,
			"winglet_col": MAROON, "cheat_col": GOLD},
	# Raihana Cargo: the flag carrier's freighter, no cabin windows, a maroon line along its side.
	"raihana_cargo": {"windows": 0.0, "fin_col": MAROON, "art_col": GOLD, "art": 1, "sweep_ahead": 13.5,
			"engine_col": WHITE, "winglet_col": MAROON, "cheat_col": MAROON, "cheat_y": 0.1, "cheat_w": 0.5},
	# Bloombay Air, from the Bloombay GP's city: a deep blue lower half under a teal line, the blue tail with white waves.
	"bloombay": {"belly_col": Color(0.06, 0.20, 0.46), "belly_y": -0.85, "cheat_col": Color(0.10, 0.72, 0.74),
			"cheat_y": -0.62, "cheat_w": 0.14, "fin_col": Color(0.06, 0.20, 0.46), "art_col": Color(0.96, 0.97, 0.98),
			"art": 3, "sweep_ahead": 99.0, "engine_col": Color(0.06, 0.20, 0.46), "winglet_col": Color(0.10, 0.72, 0.74)},
	# Matumaini Airways (the Matumaini GP's country): a broad green line and a gold one, the green tail with a gold sun.
	"matumaini": {"belly_y": -99.0, "cheat_col": Color(0.08, 0.42, 0.22), "cheat_y": -0.22, "cheat_w": 0.34,
			"cheat2_col": Color(0.96, 0.76, 0.12), "cheat2_y": -0.56, "cheat2_w": 0.12, "fin_col": Color(0.08, 0.42, 0.22),
			"art_col": Color(0.98, 0.78, 0.14), "art": 2, "sweep_ahead": 11.0, "engine_col": WHITE,
			"winglet_col": Color(0.08, 0.42, 0.22)},
	# Viento (the Sierra del Viento): a grey belly, the red tail raked with an orange band, red engines.
	"viento": {"belly_col": Color(0.62, 0.63, 0.66), "belly_y": -1.55, "cheat_y": -99.0,
			"fin_col": Color(0.74, 0.10, 0.07), "art_col": Color(1.0, 0.56, 0.12), "art": 4, "sweep_ahead": 99.0,
			"engine_col": Color(0.74, 0.10, 0.07), "winglet_col": Color(1.0, 0.56, 0.12)},
	# Sahar Air: teal and gold, a crescent and star on the tail.
	"sahar": {"belly_col": Color(0.86, 0.84, 0.78), "cheat_col": Color(0.04, 0.38, 0.40), "cheat_y": -0.4,
			"cheat_w": 0.22, "cheat2_col": GOLD, "cheat2_y": -0.62, "cheat2_w": 0.08, "fin_col": Color(0.04, 0.38, 0.40),
			"art_col": GOLD, "art": 5, "sweep_ahead": 99.0, "engine_col": Color(0.04, 0.38, 0.40), "winglet_col": GOLD},
}

static var _materials := {}
static var _light_material: ShaderMaterial = null


## The livery's material (shared: Airliners.gd sets `night` on every one).
static func livery_material(livery: String) -> ShaderMaterial:
	if _materials.has(livery):
		return _materials[livery]
	var m := ShaderMaterial.new()
	m.shader = load("res://airliner_body.gdshader")
	var d: Dictionary = LIVERIES.get(livery, LIVERIES["raihana"])
	for k in d.keys():
		m.set_shader_parameter(k, d[k])
	_materials[livery] = m
	return m


static func light_material() -> ShaderMaterial:
	if _light_material == null:
		_light_material = ShaderMaterial.new()
		_light_material.shader = load("res://airliner_lights.gdshader")
	return _light_material


## Every material made so far (to set `night` and the fade on).
static func all_materials() -> Array:
	var out: Array = _materials.values()
	out.append(light_material())
	return out


## The per-instance values the body shader wants for an airframe: its doors, the run of its windows, its tail art's
## middle and its nose.
static func instance_params(frame: String) -> Dictionary:
	var f: Dictionary = FRAMES[frame]
	var doors: Array = f.doors
	var le0: Vector2 = f.fin_le0
	var le1: Vector2 = f.fin_le1
	var te0: Vector2 = f.fin_te0
	var te1: Vector2 = f.fin_te1
	var y: float = lerpf(le0.y, le1.y, 0.48)
	var t: float = (y - le0.y) / (le1.y - le0.y)
	var z: float = (lerpf(le0.x, le1.x, t) + lerpf(te0.x, te1.x, (y - te0.y) / (te1.y - te0.y))) * 0.5
	return {
		"door_z": Vector4(doors[0], doors[1], doors[2], doors[3]),
		"win_z": Vector2(f.win0, f.win1),
		"art_c": Vector2(z, y),
		"nose_z": float(f.nose),
	}
