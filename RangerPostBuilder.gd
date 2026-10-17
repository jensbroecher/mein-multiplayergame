# RangerPostBuilder.gd
#
# The ranger post beside Msitu Falls' start straight, built by regenerate_msitu_falls.gd: a forest
# office with a veranda, a thatched rondavel, a store with a woodshed, a water tank, and a fenced
# yard with a flagpole.
#
# Everything is modelled in a building's own frame at life size (X along the front, Y up, Z out
# of the front, toward the yard) and grown by SCALE, since the carts are RC cars and a life-size
# door would barely clear one. begin() sets the frame; every call after it is in that frame.
# One mesh holds the whole post, one surface per material (see the M_* names), so it is a handful
# of draw calls whatever the detail. Tangents are generated for the shaders that use normal maps.
#
# Coplanar faces flicker on the mobile renderer, so anything laid on a surface (window frames,
# glass, door leaves, signs) stands 2.5cm+ proud of it, and nothing overlaps in one plane.
# Winding: Godot front faces are clockwise, normal (c - a) x (b - a); _tri flips a triangle
# whenever that normal disagrees with the outward direction it is given.
extends RefCounted

const SCALE := 1.6

# Material names. The generator maps each to a ShaderMaterial or StandardMaterial3D.
const M_WOOD := "wood"          # upright board-and-batten walls
const M_WOOD_H := "wood_h"      # horizontal boards: floors, ceilings, louvred shutters
const M_TIMBER := "timber"      # squared timber, grain along v
const M_PAINT := "paint"        # painted wood: trim, doors
const M_ROOF := "roof"          # corrugated iron
const M_THATCH := "thatch"
const M_STONE := "stone"
const M_PLASTER := "plaster"
const M_BRICK := "brick"
const M_GLASS := "glass"
const M_METAL := "metal"        # plastic and sheet metal: tank, drums, gutters

# Palette (sRGB; the shaders linearise their vertex colours).
const C_WALL := Color(0.56, 0.45, 0.34)
const C_WALL_DARK := Color(0.40, 0.31, 0.23)
const C_TIMBER := Color(0.50, 0.38, 0.27)
const C_TRIM := Color(0.88, 0.86, 0.78)
const C_SHUTTER := Color(0.20, 0.40, 0.30)
const C_DOOR := Color(0.44, 0.15, 0.11)
const C_STONE := Color(1.0, 1.0, 1.0)
const C_GLASS := Color(0.07, 0.10, 0.12)
const C_ROOF_GREEN := Color(0.30, 0.48, 0.36)
const C_ROOF_RED := Color(0.52, 0.22, 0.15)
const C_ROOF_GREY := Color(0.42, 0.44, 0.45)
const C_BRICK := Color(0.64, 0.31, 0.22)
const C_PLASTER_LOW := Color(0.66, 0.38, 0.25)
const C_PLASTER_HIGH := Color(0.86, 0.82, 0.72)

var colliders: Array = []     # {"kind": "box", "xf": Transform3D, "size": Vector3} | {"kind": "cyl", "xf", "radius", "height"}
var footprints: Array = []    # {"name": String, "pts": Array[Vector2] (world XZ), "base_y": float}
var labels: Array = []        # {"text": String, "xf": Transform3D (world), "font_size", "pixel_size", "color"}
var flag_world := Vector3.ZERO   # where the yard's flagpole stands (the generator builds it)

var _data := {}
var _order: Array = []
var _xf := Transform3D.IDENTITY
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 5150


## Sets the frame the next calls build in: `origin` is the ground at the building's centre.
func begin(origin: Vector3, yaw: float) -> void:
	_xf = Transform3D(Basis(Vector3.UP, yaw), origin)


func world(p: Vector3) -> Vector3:
	return _xf * (p * SCALE)


# ======================================================================================
#  Primitives
# ======================================================================================

func _surf(mat: String) -> Dictionary:
	if not _data.has(mat):
		_data[mat] = {"v": [], "n": [], "uv": [], "c": []}
		_order.append(mat)
	return _data[mat]


## One triangle in the local frame. `hint` is the outward direction; with `na`..`nc` given the
## triangle is smooth-shaded and they are the outward direction instead.
func _tri(mat: String, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2,
		col: Color, hint: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.length_squared() < 1e-14:
		return
	var smooth: bool = na != Vector3.ZERO
	if smooth:
		hint = na + nb + nc
	if hint != Vector3.ZERO and n.dot(hint) < 0.0:
		var tp: Vector3 = b
		b = c
		c = tp
		var tu: Vector2 = ub
		ub = uc
		uc = tu
		var tn: Vector3 = nb
		nb = nc
		nc = tn
		n = -n
	n = n.normalized()
	if not smooth:
		na = n
		nb = n
		nc = n
	var s: Dictionary = _surf(mat)
	var vs: Array = s["v"]
	var ns: Array = s["n"]
	var uvs: Array = s["uv"]
	var cs: Array = s["c"]
	var pts: Array = [a, b, c]
	var nrm: Array = [na, nb, nc]
	var uv: Array = [ua, ub, uc]
	for k in range(3):
		vs.append(world(pts[k]))
		ns.append((_xf.basis * (nrm[k] as Vector3)).normalized())
		uvs.append((uv[k] as Vector2) * SCALE)
		cs.append(col)


func quad_uv(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2,
		col: Color, hint: Vector3) -> void:
	_tri(mat, a, b, c, ua, ub, uc, col, hint)
	_tri(mat, a, c, d, ua, uc, ud, col, hint)


## A quad whose UVs are the points' coordinates on two axes (metres): a wall's own frame.
func quad_ax(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ux: Vector3, uy: Vector3, col: Color, hint: Vector3) -> void:
	quad_uv(mat, a, b, c, d, Vector2(a.dot(ux), a.dot(uy)), Vector2(b.dot(ux), b.dot(uy)), Vector2(c.dot(ux), c.dot(uy)),
			Vector2(d.dot(ux), d.dot(uy)), col, hint)


## An oriented box: centre `c`, axes `ax`, `ay`, `az` (unit), sizes along them. The UVs are the
## local coordinates on the two axes lying in each face, so adjacent boxes share a pattern. The
## +ay face can take its own material, and the -ay face is only drawn if `bottom`.
func obox(mat: String, c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, sx: float, sy: float, sz: float, col: Color,
		top_mat := "", bottom := false, top_col := Color(-1, -1, -1)) -> void:
	var hx: Vector3 = ax * (sx * 0.5)
	var hy: Vector3 = ay * (sy * 0.5)
	var hz: Vector3 = az * (sz * 0.5)
	# +az and -az faces: u along ax, v along ay.
	quad_ax(mat, c - hx - hy + hz, c + hx - hy + hz, c + hx + hy + hz, c - hx + hy + hz, ax, ay, col, az)
	quad_ax(mat, c + hx - hy - hz, c - hx - hy - hz, c - hx + hy - hz, c + hx + hy - hz, ax, ay, col, -az)
	# +ax and -ax faces: u along az, v along ay.
	quad_ax(mat, c + hx - hy + hz, c + hx - hy - hz, c + hx + hy - hz, c + hx + hy + hz, az, ay, col, ax)
	quad_ax(mat, c - hx - hy - hz, c - hx - hy + hz, c - hx + hy + hz, c - hx + hy - hz, az, ay, col, -ax)
	# +ay face (the top), u along ax, v along az.
	quad_ax(top_mat if top_mat != "" else mat, c - hx + hy + hz, c + hx + hy + hz, c + hx + hy - hz, c - hx + hy - hz, ax, az,
			top_col if top_col.r >= 0.0 else col, ay)
	if bottom:
		quad_ax(mat, c - hx - hy - hz, c + hx - hy - hz, c + hx - hy + hz, c - hx - hy + hz, ax, az, col, -ay)


func box(mat: String, c: Vector3, size: Vector3, col: Color, top_mat := "", bottom := false, top_col := Color(-1, -1, -1)) -> void:
	obox(mat, c, Vector3.RIGHT, Vector3.UP, Vector3.BACK, size.x, size.y, size.z, col, top_mat, bottom, top_col)


## Squared timber from `a` to `b`, `w` wide and `h` deep, the grain (v) along its length. `up`
## says which way the `h` side faces.
func beam(mat: String, a: Vector3, b: Vector3, w: float, h: float, col: Color, up := Vector3.UP, ends := true) -> void:
	var ay: Vector3 = (b - a).normalized()
	var ref: Vector3 = up if absf(ay.dot(up)) < 0.95 else Vector3.RIGHT
	var ax: Vector3 = ay.cross(ref).normalized()
	var az: Vector3 = ax.cross(ay).normalized()
	var length: float = a.distance_to(b)
	var c: Vector3 = (a + b) * 0.5
	var hx: Vector3 = ax * (w * 0.5)
	var hz: Vector3 = az * (h * 0.5)
	var hy: Vector3 = ay * (length * 0.5)
	# Side faces: u across the face, v along the beam.
	quad_uv(mat, c - hy - hx + hz, c - hy + hx + hz, c + hy + hx + hz, c + hy - hx + hz,
			Vector2(0, 0), Vector2(w, 0), Vector2(w, length), Vector2(0, length), col, az)
	quad_uv(mat, c - hy + hx - hz, c - hy - hx - hz, c + hy - hx - hz, c + hy + hx - hz,
			Vector2(0, 0), Vector2(w, 0), Vector2(w, length), Vector2(0, length), col, -az)
	quad_uv(mat, c - hy + hx + hz, c - hy + hx - hz, c + hy + hx - hz, c + hy + hx + hz,
			Vector2(0, 0), Vector2(h, 0), Vector2(h, length), Vector2(0, length), col, ax)
	quad_uv(mat, c - hy - hx - hz, c - hy - hx + hz, c + hy - hx + hz, c + hy - hx - hz,
			Vector2(0, 0), Vector2(h, 0), Vector2(h, length), Vector2(0, length), col, -ax)
	if ends:
		quad_uv(mat, c + hy - hx + hz, c + hy + hx + hz, c + hy + hx - hz, c + hy - hx - hz,
				Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h), col, ay)
		quad_uv(mat, c - hy - hx - hz, c - hy + hx - hz, c - hy + hx + hz, c - hy - hx + hz,
				Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h), col, -ay)


## A (tapering) tube from `a` to `b`, smooth-shaded. UV: u in metres round, v along.
func tube(mat: String, a: Vector3, b: Vector3, r0: float, r1: float, segs: int, col: Color, cap_a := false, cap_b := false) -> void:
	var t: Vector3 = (b - a).normalized()
	var u: Vector3 = t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
	var w: Vector3 = t.cross(u)
	var length: float = a.distance_to(b)
	var rm: float = (r0 + r1) * 0.5
	for k in range(segs):
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var d0: Vector3 = u * cos(a0) + w * sin(a0)
		var d1: Vector3 = u * cos(a1) + w * sin(a1)
		var p00: Vector3 = a + d0 * r0
		var p01: Vector3 = a + d1 * r0
		var p10: Vector3 = b + d0 * r1
		var p11: Vector3 = b + d1 * r1
		var u0: float = TAU * rm * float(k) / float(segs)
		var u1: float = TAU * rm * float(k + 1) / float(segs)
		# A cone's normals lean along its axis.
		var lean: Vector3 = t * ((r0 - r1) / maxf(length, 0.001))
		var n0: Vector3 = (d0 + lean).normalized()
		var n1: Vector3 = (d1 + lean).normalized()
		_tri(mat, p00, p10, p11, Vector2(u0, 0), Vector2(u0, length), Vector2(u1, length), col, Vector3.ZERO, n0, n0, n1)
		_tri(mat, p00, p11, p01, Vector2(u0, 0), Vector2(u1, length), Vector2(u1, 0), col, Vector3.ZERO, n0, n1, n1)
		if cap_a and r0 > 0.0:
			_tri(mat, a, p00, p01, Vector2(0, 0), Vector2(r0, 0), Vector2(0, r0), col, -t)
		if cap_b and r1 > 0.0:
			_tri(mat, b, p10, p11, Vector2(0, 0), Vector2(r1, 0), Vector2(0, r1), col, t)


## A slab: its top plane through p0..p3 (p0 and p1 along one edge, p3 across from p0), `t` thick
## below the plane. UVs on the top and the underside run along the slab's own edges, in metres.
func slab(top_mat: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float, col: Color,
		under_mat := M_WOOD_H, under_col := C_WALL_DARK, edge_mat := M_PAINT, edge_col := C_TRIM) -> void:
	var eu: Vector3 = (p1 - p0).normalized()
	var ev: Vector3 = ((p3 - p0) - eu * (p3 - p0).dot(eu)).normalized()
	var up: Vector3 = eu.cross(ev)
	if up.y < 0.0:
		up = -up
	var d: Vector3 = -up * t
	var uv0 := Vector2.ZERO
	var uv1 := Vector2((p1 - p0).dot(eu), (p1 - p0).dot(ev))
	var uv2 := Vector2((p2 - p0).dot(eu), (p2 - p0).dot(ev))
	var uv3 := Vector2((p3 - p0).dot(eu), (p3 - p0).dot(ev))
	quad_uv(top_mat, p0, p1, p2, p3, uv0, uv1, uv2, uv3, col, up)
	quad_uv(under_mat, p0 + d, p1 + d, p2 + d, p3 + d, uv0, uv1, uv2, uv3, under_col, -up)
	var corners: Array = [p0, p1, p2, p3]
	var centre: Vector3 = (p0 + p1 + p2 + p3) * 0.25
	for k in range(4):
		var ea: Vector3 = corners[k]
		var eb: Vector3 = corners[(k + 1) % 4]
		var out: Vector3 = ((ea + eb) * 0.5 - centre)
		out -= up * out.dot(up)
		var length: float = ea.distance_to(eb)
		quad_uv(edge_mat, ea, eb, eb + d, ea + d, Vector2(0, 0), Vector2(length, 0), Vector2(length, t), Vector2(0, t), edge_col, out)


## A gable roof of two slabs (the same pitch each side) with a ridge roll. The ridge runs along
## X at (y_ridge, z_ridge); the eaves fall to z_back and z_front.
func gable_roof(x0: float, x1: float, z_back: float, z_ridge: float, z_front: float, y_ridge: float, pitch: float, t: float,
		col: Color, under_col := C_WALL_DARK) -> void:
	var yb: float = y_ridge - (z_ridge - z_back) * tan(pitch)
	var yf: float = y_ridge - (z_front - z_ridge) * tan(pitch)
	slab(M_ROOF, Vector3(x0, yb, z_back), Vector3(x1, yb, z_back), Vector3(x1, y_ridge, z_ridge), Vector3(x0, y_ridge, z_ridge), t, col, M_WOOD_H, under_col)
	slab(M_ROOF, Vector3(x1, yf, z_front), Vector3(x0, yf, z_front), Vector3(x0, y_ridge, z_ridge), Vector3(x1, y_ridge, z_ridge), t, col, M_WOOD_H, under_col)
	tube(M_ROOF, Vector3(x0 - 0.04, y_ridge + 0.03, z_ridge), Vector3(x1 + 0.04, y_ridge + 0.03, z_ridge), 0.11, 0.11, 7, col.darkened(0.15), true, true)


## The triangle of wall under a gable roof's end, at x, from the wall plates to the ridge.
func gable_end(x: float, z_back: float, z_front: float, y_plate: float, y_apex: float, col: Color, out: float) -> void:
	var zc: float = (z_back + z_front) * 0.5
	var a := Vector3(x, y_plate, z_back)
	var b := Vector3(x, y_plate, z_front)
	var c := Vector3(x, y_apex, zc)
	_tri(M_WOOD, a, b, c, Vector2(a.z, a.y), Vector2(b.z, b.y), Vector2(c.z, c.y), col, Vector3(out, 0, 0))


## A wall opening's glazing on a wall: `c` is the middle of the opening on the wall surface, `right`
## along the wall, `out` the wall's outward normal.
func window(c: Vector3, right: Vector3, out: Vector3, w: float, h: float, shutters := true, sh_col := C_SHUTTER) -> void:
	var fw := 0.085
	# Glass, then a frame and mullions standing proud of it, a sill, and shutters folded flat.
	_rect(M_GLASS, c + out * 0.02, right, w - fw * 2.0, h - fw * 2.0, C_GLASS, out)
	obox(M_PAINT, c + Vector3.UP * (h * 0.5 - fw * 0.5) + out * 0.032, right, Vector3.UP, out, w, fw, 0.064, C_TRIM)
	obox(M_PAINT, c - Vector3.UP * (h * 0.5 - fw * 0.5) + out * 0.032, right, Vector3.UP, out, w, fw, 0.064, C_TRIM)
	obox(M_PAINT, c - right * (w * 0.5 - fw * 0.5) + out * 0.032, right, Vector3.UP, out, fw, h - fw * 2.0, 0.064, C_TRIM)
	obox(M_PAINT, c + right * (w * 0.5 - fw * 0.5) + out * 0.032, right, Vector3.UP, out, fw, h - fw * 2.0, 0.064, C_TRIM)
	obox(M_PAINT, c + out * 0.05, right, Vector3.UP, out, 0.035, h - fw * 2.0, 0.04, C_TRIM)
	obox(M_PAINT, c + out * 0.05, right, Vector3.UP, out, w - fw * 2.0, 0.035, 0.04, C_TRIM)
	obox(M_PAINT, c - Vector3.UP * (h * 0.5 + 0.025) + out * 0.075, right, Vector3.UP, out, w + 0.18, 0.055, 0.15, C_TRIM)
	if shutters:
		for side in [-1.0, 1.0]:
			var sc: Vector3 = c + right * (side * (w * 0.5 + w * 0.25 + 0.02)) + out * 0.03
			obox(M_WOOD_H, sc, right, Vector3.UP, out, w * 0.5, h, 0.045, sh_col)


## A door on a wall: `c` the middle of its foot on the wall surface.
func door(c: Vector3, right: Vector3, out: Vector3, w: float, h: float, leaf_col := C_DOOR) -> void:
	var fw := 0.1
	var mid: Vector3 = c + Vector3.UP * (h * 0.5)
	obox(M_PAINT, mid + out * 0.02, right, Vector3.UP, out, w - fw * 2.0, h - fw, 0.05, leaf_col)
	obox(M_PAINT, c + Vector3.UP * (h - fw * 0.5) + out * 0.035, right, Vector3.UP, out, w, fw, 0.07, C_TRIM)
	obox(M_PAINT, c - right * (w * 0.5 - fw * 0.5) + Vector3.UP * ((h - fw) * 0.5) + out * 0.035, right, Vector3.UP, out, fw, h - fw, 0.07, C_TRIM)
	obox(M_PAINT, c + right * (w * 0.5 - fw * 0.5) + Vector3.UP * ((h - fw) * 0.5) + out * 0.035, right, Vector3.UP, out, fw, h - fw, 0.07, C_TRIM)
	# Three ledges across the leaf, and a handle.
	for ly in [0.22, 0.5, 0.8]:
		obox(M_TIMBER, c + Vector3.UP * (h * ly) + out * 0.058, right, Vector3.UP, out, w - fw * 2.0, 0.11, 0.02, leaf_col.darkened(0.2))
	obox(M_METAL, c + right * (w * 0.5 - 0.22) + Vector3.UP * (h * 0.46) + out * 0.085, right, Vector3.UP, out, 0.05, 0.16, 0.05, Color(0.1, 0.1, 0.1))


## A flat rectangle facing `out`, centred on `c`, `w` wide along `right`, `h` high.
func _rect(mat: String, c: Vector3, right: Vector3, w: float, h: float, col: Color, out: Vector3) -> void:
	var hx: Vector3 = right * (w * 0.5)
	var hy: Vector3 = Vector3.UP * (h * 0.5)
	quad_uv(mat, c - hx - hy, c + hx - hy, c + hx + hy, c - hx + hy, Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h), col, out)


## A railing between two posts: top and bottom rails and balusters.
func railing(a: Vector3, b: Vector3, height := 0.95) -> void:
	var dir: Vector3 = (b - a)
	var length: float = dir.length()
	dir = dir.normalized()
	beam(M_TIMBER, a + Vector3.UP * height, b + Vector3.UP * height, 0.11, 0.07, C_TIMBER)
	beam(M_TIMBER, a + Vector3.UP * 0.32, b + Vector3.UP * 0.32, 0.09, 0.06, C_TIMBER)
	var n: int = maxi(int(length / 0.3), 1)
	for k in range(1, n):
		var p: Vector3 = a + dir * (length * float(k) / float(n))
		beam(M_TIMBER, p + Vector3.UP * 0.32, p + Vector3.UP * height, 0.05, 0.05, C_TIMBER, Vector3.UP, false)


# ======================================================================================
#  Colliders and records
# ======================================================================================

func box_collider(c: Vector3, size: Vector3) -> void:
	colliders.append({"kind": "box", "xf": Transform3D(_xf.basis, world(c)), "size": size * SCALE})


func cyl_collider(base: Vector3, radius: float, height: float) -> void:
	colliders.append({"kind": "cyl", "xf": Transform3D(_xf.basis, world(base + Vector3.UP * height * 0.5)), "radius": radius * SCALE, "height": height * SCALE})


## A rectangular footprint (local x0..x1, z0..z1) for the generator's checks.
func footprint_rect(fname: String, x0: float, x1: float, z0: float, z1: float) -> void:
	var pts: Array = []
	for fx in [0.0, 0.5, 1.0]:
		for fz in [0.0, 0.5, 1.0]:
			var w: Vector3 = world(Vector3(lerpf(x0, x1, fx), 0.0, lerpf(z0, z1, fz)))
			pts.append(Vector2(w.x, w.z))
	footprints.append({"name": fname, "pts": pts, "base_y": _xf.origin.y})


func footprint_circle(fname: String, r: float) -> void:
	var pts: Array = [Vector2(_xf.origin.x, _xf.origin.z)]
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		var w: Vector3 = world(Vector3(cos(a) * r, 0.0, sin(a) * r))
		pts.append(Vector2(w.x, w.z))
	footprints.append({"name": fname, "pts": pts, "base_y": _xf.origin.y})


func add_label(text: String, c: Vector3, out: Vector3, font_size: int, pixel_size: float, color: Color) -> void:
	var o: Vector3 = (_xf.basis * out).normalized()
	# Label3D faces its local +Z; look along -o.
	var yaw: float = atan2(o.x, o.z)
	labels.append({"text": text, "xf": Transform3D(Basis(Vector3.UP, yaw), world(c)), "font_size": font_size,
			"pixel_size": pixel_size * SCALE, "color": color})


# ======================================================================================
#  Parts
# ======================================================================================

func drum(c: Vector3, col: Color) -> void:
	var r := 0.3
	var h := 0.88
	tube(M_METAL, c, c + Vector3.UP * h, r, r, 12, col, true, true)
	for ry in [0.18, 0.5, 0.78]:
		tube(M_METAL, c + Vector3.UP * (h * ry), c + Vector3.UP * (h * ry + 0.04), r + 0.012, r + 0.012, 12, col.darkened(0.25), false, false)


func crate(c: Vector3, size: Vector3, yaw := 0.0) -> void:
	var ax := Vector3(cos(yaw), 0.0, -sin(yaw))
	var az := Vector3(sin(yaw), 0.0, cos(yaw))
	obox(M_WOOD_H, c + Vector3.UP * (size.y * 0.5), ax, Vector3.UP, az, size.x, size.y, size.z, Color(0.62, 0.50, 0.34))


func bench(c: Vector3, length: float, yaw := 0.0) -> void:
	var ax := Vector3(cos(yaw), 0.0, -sin(yaw))
	var az := Vector3(sin(yaw), 0.0, cos(yaw))
	obox(M_TIMBER, c + Vector3.UP * 0.46, ax, Vector3.UP, az, length, 0.06, 0.4, C_TIMBER)
	obox(M_TIMBER, c + Vector3.UP * 0.8 - az * 0.17, ax, Vector3.UP, az, length, 0.28, 0.045, C_TIMBER)
	for sx in [-0.42, 0.42]:
		var lc: Vector3 = c + ax * (length * sx)
		obox(M_TIMBER, lc + Vector3.UP * 0.215, ax, Vector3.UP, az, 0.07, 0.43, 0.34, C_TIMBER.darkened(0.1))
		obox(M_TIMBER, lc + Vector3.UP * 0.63 - az * 0.17, ax, Vector3.UP, az, 0.07, 0.34, 0.05, C_TIMBER.darkened(0.1))


## A round water tank on a stone base: dark green plastic with ribs, a domed lid and a tap.
func water_tank(c: Vector3) -> void:
	var r := 0.85
	var h := 2.0
	var green := Color(0.10, 0.27, 0.17)
	box(M_STONE, c + Vector3.UP * 0.05, Vector3(2.0, 0.4, 2.0), C_STONE)
	var base: Vector3 = c + Vector3.UP * 0.25
	tube(M_METAL, base, base + Vector3.UP * h, r, r, 20, green, false, false)
	for ry in [0.2, 0.5, 0.8]:
		tube(M_METAL, base + Vector3.UP * (h * ry), base + Vector3.UP * (h * ry + 0.07), r + 0.018, r + 0.018, 20, green.darkened(0.2), false, false)
	tube(M_METAL, base + Vector3.UP * h, base + Vector3.UP * (h + 0.22), r, r * 0.55, 20, green.lightened(0.05), false, true)
	tube(M_METAL, base + Vector3.UP * (h + 0.22), base + Vector3.UP * (h + 0.3), r * 0.28, r * 0.28, 10, green.darkened(0.1), false, true)
	# The tap, low down on the yard side.
	tube(M_METAL, base + Vector3(0.0, 0.35, r - 0.02), base + Vector3(0.0, 0.35, r + 0.22), 0.04, 0.04, 6, Color(0.2, 0.2, 0.2), false, true)


## The rondavel's thatch: a cone from `r_eave` at `y_eave` up to its apex, built in courses,
## the eave edge ragged, with a soffit under it running back in to the wall.
func thatch_cone(r_eave: float, y_eave: float, y_peak: float, r_wall: float, y_wall: float, segs: int, courses: int) -> void:
	var rise: float = y_peak - y_eave
	var thick := 0.42
	var rings: Array = []   # per course: Array of Vector3
	for j in range(courses + 1):
		var t: float = float(j) / float(courses)
		var r: float = r_eave * t
		var y: float = y_peak - rise * pow(t, 0.92)
		var ring: Array = []
		for k in range(segs):
			var a: float = TAU * float(k) / float(segs)
			var rr: float = r
			var yy: float = y
			if j == courses:
				# The ragged eave: the edge wanders in and out and up and down.
				rr += _rng.randf_range(-0.07, 0.05)
				yy += _rng.randf_range(-0.09, 0.05)
			elif j > 0:
				rr *= 1.0 + _rng.randf_range(-0.012, 0.012)
				yy += _rng.randf_range(-0.012, 0.012)
			ring.append(Vector3(cos(a) * rr, yy, sin(a) * rr))
		rings.append(ring)
	var slope_n := Vector2(rise, r_eave).normalized()   # (outward, up) of the cone's normal
	for j in range(courses):
		for k in range(segs):
			var k2: int = (k + 1) % segs
			var p00: Vector3 = (rings[j] as Array)[k]
			var p01: Vector3 = (rings[j] as Array)[k2]
			var p10: Vector3 = (rings[j + 1] as Array)[k]
			var p11: Vector3 = (rings[j + 1] as Array)[k2]
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k2 if k2 != 0 else segs) / float(segs)
			var n0: Vector3 = Vector3(cos(a0) * slope_n.x, slope_n.y, sin(a0) * slope_n.x)
			var n1: Vector3 = Vector3(cos(a1) * slope_n.x, slope_n.y, sin(a1) * slope_n.x)
			var v0: float = Vector2(p00.x, p00.z).length() / r_eave * sqrt(r_eave * r_eave + rise * rise)
			var v1: float = Vector2(p10.x, p10.z).length() / r_eave * sqrt(r_eave * r_eave + rise * rise)
			var u0: float = a0 * r_eave
			var u1: float = a1 * r_eave
			var tint := Color(1, 1, 1, 1)
			_tri(M_THATCH, p00, p10, p11, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), tint, Vector3.ZERO, n0, n0, n1)
			_tri(M_THATCH, p00, p11, p01, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0), tint, Vector3.ZERO, n0, n1, n1)
	# The thick edge of the eave and the soffit under it.
	var eave: Array = rings[courses]
	for k in range(segs):
		var k2: int = (k + 1) % segs
		var e0: Vector3 = eave[k]
		var e1: Vector3 = eave[k2]
		var d0 := Vector3(e0.x, 0.0, e0.z).normalized()
		var d1 := Vector3(e1.x, 0.0, e1.z).normalized()
		var l0: Vector3 = e0 - d0 * 0.09 - Vector3.UP * (thick + _rng.randf_range(-0.05, 0.05))
		var l1: Vector3 = e1 - d1 * 0.09 - Vector3.UP * (thick + _rng.randf_range(-0.05, 0.05))
		var w0 := Vector3(d0.x * r_wall, y_wall, d0.z * r_wall)
		var w1 := Vector3(d1.x * r_wall, y_wall, d1.z * r_wall)
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var dark := Color(0.55, 0.55, 0.55, 0.55)
		_tri(M_THATCH, e0, e1, l1, Vector2(a0 * r_eave, 0.0), Vector2(a1 * r_eave, 0.0), Vector2(a1 * r_eave, thick), dark, d0 + d1)
		_tri(M_THATCH, e0, l1, l0, Vector2(a0 * r_eave, 0.0), Vector2(a1 * r_eave, thick), Vector2(a0 * r_eave, thick), dark, d0 + d1)
		var soffit_dark := Color(0.5, 0.5, 0.5, 0.4)
		_tri(M_THATCH, l0, l1, w1, Vector2(a0 * r_eave, 0.0), Vector2(a1 * r_eave, 0.0), Vector2(a1 * r_wall, 1.0), soffit_dark, -Vector3.UP)
		_tri(M_THATCH, l0, w1, w0, Vector2(a0 * r_eave, 0.0), Vector2(a1 * r_wall, 1.0), Vector2(a0 * r_wall, 1.0), soffit_dark, -Vector3.UP)


# ======================================================================================
#  Buildings
# ======================================================================================

## The forest office: a timber building on a stone base, a lean-to veranda along the front, a
## green iron roof, a brick chimney and a water tank. Faces +Z (local); W along X.
func office(origin: Vector3, yaw: float) -> void:
	begin(origin, yaw)
	var W := 10.0
	var D := 4.6
	var V := 2.3
	var floor_y := 0.55
	var wall_h := 2.8
	var top_y: float = floor_y + wall_h
	var hw: float = W * 0.5
	var hd: float = D * 0.5
	footprint_rect("office", -hw - 2.3, hw + 0.3, -hd - 0.3, hd + V + 1.5)

	# Stone base under the whole building and its veranda; the veranda floor is boards on top.
	box(M_STONE, Vector3(0, 0.2, V * 0.5), Vector3(W + 0.4, 0.7, D + V + 0.4), C_STONE, M_WOOD_H, false, C_WALL_DARK)
	# Walls.
	box(M_WOOD, Vector3(0, floor_y + wall_h * 0.5, 0), Vector3(W, wall_h, D), C_WALL)
	# Corner boards, standing proud.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(M_PAINT, Vector3(sx * (hw - 0.03), floor_y + wall_h * 0.5, sz * (hd - 0.03)), Vector3(0.14, wall_h, 0.14), C_TRIM)
	# Roof: a gable over the main block, its ends filled in with boards.
	var pitch: float = deg_to_rad(27.0)
	var oh_e := 0.65
	var oh_g := 0.55
	var y_ridge: float = top_y + 0.12 + hd * tan(pitch)
	gable_roof(-hw - oh_g, hw + oh_g, -hd - oh_e, 0.0, hd + oh_e, y_ridge, pitch, 0.09, C_ROOF_GREEN)
	for sx in [-1.0, 1.0]:
		gable_end(sx * hw, -hd, hd, top_y, y_ridge - 0.08, C_WALL_DARK, sx)
		# A louvred vent in the gable, under the ridge.
		_rect(M_WOOD_H, Vector3(sx * (hw + 0.025), top_y + 0.62, 0.0), Vector3(0, 0, -sx), 0.7, 0.42, C_WALL_DARK.darkened(0.25), Vector3(sx, 0, 0))

	# Front: the door in the middle, two windows with shutters either side.
	var front_out := Vector3.BACK
	var front_right := Vector3.RIGHT
	door(Vector3(0, floor_y, hd), front_right, front_out, 1.15, 2.15)
	for wx in [-3.9, -2.1, 2.1, 3.9]:
		window(Vector3(wx, floor_y + 1.65, hd), front_right, front_out, 0.9, 1.15)
	# Ends: a window each. Back: two.
	window(Vector3(hw, floor_y + 1.65, 0.0), Vector3.FORWARD, Vector3.RIGHT, 0.9, 1.15)
	window(Vector3(-hw, floor_y + 1.65, 0.0), Vector3.BACK, Vector3.LEFT, 0.9, 1.15)
	for wx in [-2.3, 2.3]:
		window(Vector3(wx, floor_y + 1.65, -hd), Vector3.LEFT, Vector3.FORWARD, 0.9, 1.15, false)

	# Veranda: posts, a beam, a lean-to roof sloping to the front, rails, steps.
	var post_z: float = hd + V - 0.25
	var post_xs: Array = [-5.0, -3.3, -1.65, 1.65, 3.3, 5.0]
	for px in post_xs:
		beam(M_TIMBER, Vector3(px, floor_y, post_z), Vector3(px, 2.55, post_z), 0.17, 0.17, C_TIMBER)
	beam(M_TIMBER, Vector3(-5.2, 2.65, post_z), Vector3(5.2, 2.65, post_z), 0.18, 0.2, C_TIMBER.darkened(0.08))
	var y_back := 3.0
	var y_front := 2.8
	var z_front: float = hd + V + 0.05
	slab(M_ROOF, Vector3(-5.35, y_front, z_front), Vector3(5.35, y_front, z_front), Vector3(5.35, y_back, hd), Vector3(-5.35, y_back, hd), 0.08,
			C_ROOF_GREEN)
	# Gutter along the lean-to's front edge, running on past the east end to the tank.
	tube(M_METAL, Vector3(-5.4, y_front - 0.06, z_front + 0.03), Vector3(5.4, y_front - 0.06, z_front + 0.03), 0.075, 0.075, 8, C_ROOF_GREY.darkened(0.2), true, true)
	railing(Vector3(-5.0, floor_y, post_z), Vector3(-1.65, floor_y, post_z))
	railing(Vector3(1.65, floor_y, post_z), Vector3(5.0, floor_y, post_z))
	railing(Vector3(-5.0, floor_y, hd + 0.1), Vector3(-5.0, floor_y, post_z))
	railing(Vector3(5.0, floor_y, hd + 0.1), Vector3(5.0, floor_y, post_z))
	# Steps down from the veranda's edge at the door.
	var z_edge: float = hd + V + 0.2
	for i in range(1, 4):
		var top: float = floor_y - 0.18 * float(i)
		var zc: float = z_edge + 0.32 * (float(i) - 0.5)
		box(M_STONE, Vector3(0, (top - 0.15) * 0.5, zc), Vector3(2.0, top + 0.15, 0.32), C_STONE, M_STONE)
	bench(Vector3(-3.0, floor_y, hd + 0.4), 1.8)
	bench(Vector3(3.0, floor_y, hd + 0.4), 1.8)

	# Chimney: brick, up through the roof, with a stone cap.
	box(M_BRICK, Vector3(2.9, (3.4 + y_ridge + 1.05) * 0.5, -0.6), Vector3(0.78, y_ridge + 1.05 - 3.4, 0.78), C_BRICK)
	box(M_STONE, Vector3(2.9, y_ridge + 1.1, -0.6), Vector3(1.0, 0.14, 1.0), C_STONE)
	_rect_top(M_PAINT, Vector3(2.9, y_ridge + 1.185, -0.6), 0.5, 0.5, Color(0.04, 0.04, 0.04))

	# Water tank by the east end, fed from the gutter.
	var tank_x := -6.3
	water_tank(Vector3(tank_x, 0.0, hd + 1.3))
	var feed := Vector3(tank_x, y_front - 0.06, hd + 1.3 + 0.85)
	tube(M_METAL, Vector3(-5.4, y_front - 0.06, z_front + 0.03), feed, 0.075, 0.075, 8, C_ROOF_GREY.darkened(0.2), false, true)
	tube(M_METAL, feed, feed - Vector3.UP * 0.5, 0.075, 0.075, 8, C_ROOF_GREY.darkened(0.2), true, true)

	# Collision: the stone base and walls as one block, and the tank.
	box_collider(Vector3(0, 2.4, (V - 0.0) * 0.5 + 0.0), Vector3(W + 0.4, 4.8, D + V + 0.4))
	cyl_collider(Vector3(tank_x, 0.0, hd + 1.3), 0.95, 2.5)


## A signboard on two posts, facing +Z (local), the text on it centred.
func signboard(origin: Vector3, yaw: float, text: String) -> void:
	begin(origin, yaw)
	for px in [-1.2, 1.2]:
		beam(M_TIMBER, Vector3(px, -0.2, 0.0), Vector3(px, 2.0, 0.0), 0.14, 0.14, C_TIMBER.darkened(0.1))
	box(M_PAINT, Vector3(0, 1.45, 0.0), Vector3(2.9, 0.8, 0.09), Color(0.20, 0.34, 0.26))
	box(M_PAINT, Vector3(0, 1.45, 0.0), Vector3(3.0, 0.9, 0.07), C_TRIM)
	add_label(text, Vector3(0, 1.45, 0.075), Vector3.BACK, 64, 0.0021, Color(0.96, 0.93, 0.80))
	box_collider(Vector3(0, 1.0, 0.0), Vector3(3.2, 2.2, 0.4))


## A flat square facing up, centred on `c`.
func _rect_top(mat: String, c: Vector3, w: float, d: float, col: Color) -> void:
	var hx := Vector3(w * 0.5, 0, 0)
	var hz := Vector3(0, 0, d * 0.5)
	quad_uv(mat, c - hx + hz, c + hx + hz, c + hx - hz, c - hx - hz, Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d), col, Vector3.UP)


## The rondavel: a round plastered house under a thatched cone, the eaves held on poles.
func rondavel(origin: Vector3, yaw: float) -> void:
	begin(origin, yaw)
	var R := 2.4
	var y_plinth := 0.45
	var y_split := 1.35
	var y_top := 2.55
	var r_eave := 3.55
	var y_eave := 2.5
	var y_peak := 4.95
	var segs := 28
	footprint_circle("rondavel", r_eave)
	# Stone plinth ring and its cap.
	tube(M_STONE, Vector3(0, -0.15, 0), Vector3(0, y_plinth, 0), R + 0.1, R + 0.1, segs, C_STONE, false, false)
	for k in range(segs):
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		var ya := Vector3(0, y_plinth, 0)
		quad_uv(M_STONE, ya + o0 * R, ya + o0 * (R + 0.1), ya + o1 * (R + 0.1), ya + o1 * R, Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.1), Vector2(0, 0.1), C_STONE, Vector3.UP)
	# Walls in two bands, a terracotta skirt and a lime-washed upper wall.
	tube(M_PLASTER, Vector3(0, y_plinth, 0), Vector3(0, y_split, 0), R, R, segs, C_PLASTER_LOW, false, false)
	tube(M_PLASTER, Vector3(0, y_split, 0), Vector3(0, y_top, 0), R, R, segs, C_PLASTER_HIGH, false, false)
	# Ring beam under the thatch.
	tube(M_TIMBER, Vector3(0, y_top, 0), Vector3(0, y_top + 0.14, 0), R + 0.06, R + 0.06, segs, C_TIMBER.darkened(0.15), false, true)
	thatch_cone(r_eave, y_eave, y_peak, R + 0.06, y_top + 0.14, segs, 8)
	# A finial.
	tube(M_TIMBER, Vector3(0, y_peak - 0.1, 0), Vector3(0, y_peak + 0.55, 0), 0.07, 0.03, 6, C_TIMBER.darkened(0.2), false, true)
	tube(M_THATCH, Vector3(0, y_peak - 0.25, 0), Vector3(0, y_peak + 0.12, 0), 0.34, 0.06, 10, Color(0.9, 0.9, 0.9, 1.0), false, true)
	# Poles holding up the eaves.
	var n_poles := 10
	for k in range(n_poles):
		var a: float = TAU * (float(k) + 0.5) / float(n_poles) + 0.1
		var pr := 3.12
		# Up to the soffit, which runs from the eave's lower edge back in to the ring beam.
		var r_low: float = r_eave - 0.09
		var top_y2: float = lerpf(y_eave - 0.42, y_top + 0.14, (r_low - pr) / (r_low - (R + 0.06)))
		tube(M_TIMBER, Vector3(cos(a) * pr, -0.1, sin(a) * pr), Vector3(cos(a) * pr, top_y2, sin(a) * pr), 0.085, 0.07, 6, C_TIMBER.darkened(0.12), false, true)
	# Door and windows on the plaster, on the chords of the wall.
	var out_d := Vector3(0, 0, 1)
	door(Vector3(0, y_plinth, R), Vector3.RIGHT, out_d, 1.0, 1.95)
	for a_deg in [-62.0, 62.0]:
		var a: float = deg_to_rad(90.0 + a_deg)
		var out := Vector3(cos(a), 0, sin(a))
		var right: Vector3 = Vector3.UP.cross(out)
		window(Vector3(cos(a) * R, y_plinth + 1.1, sin(a) * R), right, out, 0.55, 0.65, true)
	cyl_collider(Vector3.ZERO, R + 0.2, 3.0)


## The store: a plank barn with big double doors under a red iron roof, a woodshed on its end.
func store(origin: Vector3, yaw: float) -> void:
	begin(origin, yaw)
	var W := 5.8
	var D := 4.4
	var base_h := 0.35
	var wall_h := 2.55
	var top_y: float = base_h + wall_h
	var hw: float = W * 0.5
	var hd: float = D * 0.5
	footprint_rect("store", -hw - 0.3, hw + 3.4, -hd - 0.3, hd + 0.3)
	box(M_STONE, Vector3(0, (base_h - 0.15) * 0.5, 0), Vector3(W + 0.3, base_h + 0.15, D + 0.3), C_STONE, M_WOOD_H, false, C_WALL_DARK)
	box(M_WOOD, Vector3(0, base_h + wall_h * 0.5, 0), Vector3(W, wall_h, D), C_WALL_DARK.lightened(0.05))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(M_TIMBER, Vector3(sx * (hw - 0.03), base_h + wall_h * 0.5, sz * (hd - 0.03)), Vector3(0.16, wall_h, 0.16), C_TIMBER.darkened(0.15))
	var pitch: float = deg_to_rad(24.0)
	var y_ridge: float = top_y + 0.12 + hd * tan(pitch)
	gable_roof(-hw - 0.5, hw + 0.5, -hd - 0.45, 0.0, hd + 0.95, y_ridge, pitch, 0.09, C_ROOF_RED, C_WALL_DARK)
	for sx in [-1.0, 1.0]:
		gable_end(sx * hw, -hd, hd, top_y, y_ridge - 0.08, C_WALL_DARK, sx)
	# Double doors in the front, each leaf braced with a diagonal.
	var dw := 2.1
	var dh := 2.25
	var out := Vector3.BACK
	var dz: float = hd
	box(M_PAINT, Vector3(0, base_h + dh + 0.07, dz + 0.04), Vector3(dw + 0.3, 0.14, 0.08), C_TRIM)
	box(M_PAINT, Vector3(-dw * 0.5 - 0.075, base_h + dh * 0.5, dz + 0.04), Vector3(0.15, dh, 0.08), C_TRIM)
	box(M_PAINT, Vector3(dw * 0.5 + 0.075, base_h + dh * 0.5, dz + 0.04), Vector3(0.15, dh, 0.08), C_TRIM)
	for lx in [-1.0, 1.0]:
		var cx: float = lx * dw * 0.25
		box(M_PAINT, Vector3(cx, base_h + dh * 0.5, dz + 0.03), Vector3(dw * 0.5 - 0.03, dh, 0.05), Color(0.26, 0.40, 0.30))
		beam(M_TIMBER, Vector3(cx - lx * dw * 0.22, base_h + 0.15, dz + 0.07), Vector3(cx + lx * dw * 0.22, base_h + dh - 0.15, dz + 0.07), 0.1, 0.04, Color(0.26, 0.40, 0.30).darkened(0.2), Vector3.BACK)
		box(M_METAL, Vector3(lx * 0.12, base_h + dh * 0.5, dz + 0.085), Vector3(0.05, 0.28, 0.05), Color(0.1, 0.1, 0.1))
	# A shuttered window high in the end wall, and a stone doorstep.
	window(Vector3(hw, base_h + 1.75, 0.0), Vector3.FORWARD, Vector3.RIGHT, 0.7, 0.7, true, Color(0.30, 0.22, 0.14))
	box(M_STONE, Vector3(0, 0.0, dz + 0.5), Vector3(2.6, 0.3, 0.8), C_STONE, M_STONE)
	# The woodshed on the end: two posts, a sloping iron roof, a stack of logs.
	var sx0: float = hw + 0.4
	var sx1: float = hw + 3.2
	var sz0: float = -hd + 0.4
	var sz1: float = hd - 0.2
	for px in [sx1]:
		for pz in [sz0, sz1]:
			beam(M_TIMBER, Vector3(px, 0.0, pz), Vector3(px, 2.17, pz), 0.15, 0.15, C_TIMBER)
	slab(M_ROOF, Vector3(sx1 + 0.35, 2.2, sz0 - 0.3), Vector3(sx1 + 0.35, 2.2, sz1 + 0.3), Vector3(hw + 0.03, 2.72, sz1 + 0.3), Vector3(hw + 0.03, 2.72, sz0 - 0.3), 0.07, C_ROOF_GREY)
	log_pile(hw + 0.4, sz0 + 0.3, sz1 - 0.3, 5, 6)
	crate(Vector3(-hw + 0.6, 0.0, hd + 0.9), Vector3(0.9, 0.7, 0.7), 0.2)
	crate(Vector3(-hw + 1.55, 0.0, hd + 0.95), Vector3(0.8, 0.55, 0.65), -0.15)
	drum(Vector3(hw - 0.3, 0.0, hd + 0.8), Color(0.45, 0.16, 0.10))
	drum(Vector3(hw - 1.0, 0.0, hd + 0.75), Color(0.14, 0.28, 0.42))
	box_collider(Vector3(0, 2.1, 0), Vector3(W + 0.4, 4.2, D + 0.4))
	box_collider(Vector3((sx0 + sx1) * 0.5, 1.1, (sz0 + sz1) * 0.5), Vector3(sx1 - sx0 + 0.4, 2.2, sz1 - sz0 + 0.4))


## A woodpile against a wall: logs lying along local X from `x`, stacked in `rows` rows of up to `n0`
## along Z, their ends facing the yard.
func log_pile(x: float, z0: float, z1: float, rows: int, n0: int) -> void:
	var r := 0.12
	for row in range(rows):
		var n: int = n0 - row
		for k in range(n):
			var z: float = z0 + (z1 - z0) * (float(k) + 0.5 * float(row) + 0.5) / float(n0)
			var y: float = r + float(row) * r * 1.75
			var col: Color = Color(0.55, 0.42, 0.30).lerp(Color(0.40, 0.30, 0.21), _rng.randf())
			var length: float = _rng.randf_range(1.0, 1.3)
			tube(M_TIMBER, Vector3(x, y, z), Vector3(x + length, y, z), r * _rng.randf_range(0.9, 1.1), r, 7, col, true, true)


## A fence run in world space: posts every ~2.4m (life size) and two rails, along the ground. The
## run goes from `a` to `b`; `ground` gives the ground height at an XZ point.
func fence_run(a: Vector2, b: Vector2, ground: Callable) -> void:
	var dir := (b - a)
	var length: float = dir.length() / SCALE
	var n: int = maxi(int(length / 2.2), 1)
	begin(Vector3(a.x, 0.0, a.y), 0.0)
	var posts: Array = []
	for k in range(n + 1):
		var p: Vector2 = a.lerp(b, float(k) / float(n))
		var gy: float = ground.call(p.x, p.y)
		# In the world frame (SCALE applies to local coordinates round the origin).
		var lp := Vector3((p.x - a.x) / SCALE, gy / SCALE, (p.y - a.y) / SCALE)
		posts.append(lp)
	for lp in posts:
		var p3: Vector3 = lp
		beam(M_TIMBER, p3 - Vector3.UP * 0.15, p3 + Vector3.UP * 1.1, 0.13, 0.13, C_TIMBER.darkened(0.1))
	for k in range(n):
		var p0: Vector3 = posts[k]
		var p1: Vector3 = posts[k + 1]
		for ry in [0.45, 0.88]:
			beam(M_TIMBER, p0 + Vector3.UP * ry, p1 + Vector3.UP * ry, 0.09, 0.07, C_TIMBER, Vector3.UP, false)
		var mid: Vector3 = (p0 + p1) * 0.5
		var seg_len: float = Vector2(p1.x - p0.x, p1.z - p0.z).length()
		var yaw: float = atan2(-(p1.z - p0.z), (p1.x - p0.x))
		colliders.append({"kind": "box", "xf": Transform3D(Basis(Vector3.UP, yaw), world(mid + Vector3.UP * 0.55)),
				"size": Vector3(seg_len * SCALE + 0.2, 1.1 * SCALE, 0.3)})


## Flat stones set in the yard: a path from `a` to `b` in world space.
func stepping_stones(a: Vector2, b: Vector2, ground: Callable) -> void:
	var dir: Vector2 = b - a
	var length: float = dir.length()
	var n: int = int(length / 1.9)
	begin(Vector3(a.x, 0.0, a.y), 0.0)
	for k in range(n + 1):
		var p: Vector2 = a.lerp(b, float(k) / float(maxi(n, 1)))
		var gy: float = ground.call(p.x, p.y)
		var ang: float = _rng.randf_range(-0.5, 0.5)
		var ax := Vector3(cos(ang), 0.0, sin(ang))
		var az := Vector3(-sin(ang), 0.0, cos(ang))
		var sx: float = _rng.randf_range(0.85, 1.1)
		var sz: float = _rng.randf_range(0.6, 0.85)
		var lc := Vector3((p.x - a.x) / SCALE + _rng.randf_range(-0.05, 0.05), gy / SCALE + 0.025, (p.y - a.y) / SCALE + _rng.randf_range(-0.2, 0.2))
		obox(M_STONE, lc, ax, Vector3.UP, az, sx, 0.075, sz, C_STONE.darkened(_rng.randf_range(0.0, 0.2)))


## Lays out the whole post round `centre` (world XZ), on level ground at `pad_y`. The buildings
## face east, to the road. `ground` takes (x, z) and gives the ground height, for the fence and the
## stones, which run out onto the natural ground at the pad's edge.
func build_all(centre: Vector2, pad_y: float, ground: Callable) -> void:
	var yaw_east: float = PI * 0.5   # local +Z -> world +X
	office(Vector3(centre.x - 8.5, pad_y, centre.y), yaw_east)
	rondavel(Vector3(centre.x - 3.5, pad_y, centre.y + 20.0), yaw_east)
	store(Vector3(centre.x - 5.5, pad_y, centre.y - 20.0), yaw_east)
	# The fenced frontage along the pad's east edge, open at the path, with returns at both ends.
	var fx: float = centre.x + 15.5
	fence_run(Vector2(fx, centre.y - 28.0), Vector2(fx, centre.y - 2.8), ground)
	fence_run(Vector2(fx, centre.y + 2.8), Vector2(fx, centre.y + 28.0), ground)
	fence_run(Vector2(fx, centre.y - 28.0), Vector2(centre.x + 3.5, centre.y - 28.0), ground)
	fence_run(Vector2(fx, centre.y + 28.0), Vector2(centre.x + 3.5, centre.y + 28.0), ground)
	stepping_stones(Vector2(fx - 0.5, centre.y), Vector2(centre.x + 1.4, centre.y), ground)
	signboard(Vector3(fx - 2.5, pad_y, centre.y + 6.5), yaw_east, "RANGER STATION\nKITUO CHA WALINZI")
	flag_world = Vector3(centre.x + 9.0, pad_y, centre.y - 8.0)


## The materials for every surface name used above.
static func make_materials() -> Dictionary:
	var m := {}
	m[M_WOOD] = _shader_mat("res://hut_wood.gdshader", {"style": 0, "weathering": 0.65})
	m[M_WOOD_H] = _shader_mat("res://hut_wood.gdshader", {"style": 1, "weathering": 0.5})
	m[M_TIMBER] = _shader_mat("res://hut_wood.gdshader", {"style": 2, "weathering": 0.6})
	m[M_PAINT] = _shader_mat("res://hut_wood.gdshader", {"style": 3, "weathering": 0.55})
	m[M_ROOF] = _shader_mat("res://hut_roof_iron.gdshader", {"rust_amount": 0.3})
	m[M_THATCH] = _shader_mat("res://hut_thatch.gdshader", {"age": 0.5})
	m[M_STONE] = _shader_mat("res://hut_masonry.gdshader", {"style": 0})
	m[M_PLASTER] = _shader_mat("res://hut_masonry.gdshader", {"style": 1})
	m[M_BRICK] = _shader_mat("res://hut_masonry.gdshader", {"style": 2})
	var glass := StandardMaterial3D.new()
	glass.vertex_color_use_as_albedo = true
	glass.vertex_color_is_srgb = true
	glass.metallic = 0.5
	glass.roughness = 0.1
	m[M_GLASS] = glass
	var metal := StandardMaterial3D.new()
	metal.vertex_color_use_as_albedo = true
	metal.vertex_color_is_srgb = true
	metal.metallic = 0.25
	metal.roughness = 0.5
	m[M_METAL] = metal
	return m


static func _shader_mat(path: String, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	for k in params:
		mat.set_shader_parameter(k, params[k])
	return mat


## Builds the whole mesh: one surface per material name, `materials` mapping each to a Material.
func commit(materials: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in _order:
		var s: Dictionary = _data[mat]
		var vs: Array = s["v"]
		var ns: Array = s["n"]
		var uvs: Array = s["uv"]
		var cs: Array = s["c"]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(vs.size()):
			st.set_normal(ns[i])
			st.set_color(cs[i])
			st.set_uv(uvs[i])
			st.add_vertex(vs[i])
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[mat])
	return mesh
