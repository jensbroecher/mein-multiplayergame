extends RefCounted
## Mesh kit for procedural set dressing (regenerate_lakeside.gd): triangles, boxes, tubes, lathes and
## extruded outlines in vertex colour, one SurfaceTool per material key.
##
## Everything is emitted through a frame (`set_frame`), so a builder lays a prop out at life size in
## its own axes (y up, front toward -z) and the caller places, turns, scales and even shears it (a
## barrier following a slope) in one go. Normals go through the frame's inverse transpose and every
## triangle is wound to face the side it's told is out, so a mirrored frame still builds front faces.
## Godot's front faces wind clockwise: the face normal is (c - a) x (b - a).
##
## A "kit" is a Dictionary of material key -> SurfaceTool; `commit()` turns it into one ArrayMesh with
## a surface per key, using the materials `material_for` returns (shared, so meshes of a level
## reference one material per key).

var xf := Transform3D.IDENTITY
var _nb := Basis()
## Returns the Material for a key: set by the generator, which saves and shares them.
var material_for: Callable


func set_frame(t: Transform3D) -> void:
	xf = t
	_nb = t.basis.inverse().transposed()


func reset_frame() -> void:
	set_frame(Transform3D.IDENTITY)


func st(kit: Dictionary, key: String) -> SurfaceTool:
	if not kit.has(key):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		kit[key] = s
	return kit[key]


## One triangle facing `out` (local frame). UVs default to zero (vertex-colour materials ignore them).
func tri(kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		col: Color, out: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var s := st(kit, key)
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var wo := (_nb * out)
	var ra := (_nb * na).normalized()
	var rb := (_nb * nb).normalized()
	var rc := (_nb * nc).normalized()
	# Front face toward `out`: (c - a) x (b - a) must point along it.
	if (wc - wa).cross(wb - wa).dot(wo) < 0.0:
		var tp := wb
		wb = wc
		wc = tp
		var tn := rb
		rb = rc
		rc = tn
		var tu := ub
		ub = uc
		uc = tu
	s.set_color(col)
	s.set_normal(ra)
	s.set_uv(ua)
	s.add_vertex(wa)
	s.set_normal(rb)
	s.set_uv(ub)
	s.add_vertex(wb)
	s.set_normal(rc)
	s.set_uv(uc)
	s.add_vertex(wc)


## A flat quad p[0..3] (in order round its edge) facing `n`.
func quad(kit: Dictionary, key: String, p: Array, n: Vector3, col: Color, uv: Array = []) -> void:
	if uv.size() == 4:
		tri(kit, key, p[0], p[1], p[2], n, n, n, col, n, uv[0], uv[1], uv[2])
		tri(kit, key, p[0], p[2], p[3], n, n, n, col, n, uv[0], uv[2], uv[3])
	else:
		tri(kit, key, p[0], p[1], p[2], n, n, n, col, n)
		tri(kit, key, p[0], p[2], p[3], n, n, n, col, n)


## A double-sided flat quad (two faces, so it lights correctly from both sides on a culled material).
func panel(kit: Dictionary, key: String, p: Array, n: Vector3, col: Color, back_col: Color, uv: Array = []) -> void:
	quad(kit, key, p, n, col, uv)
	var r: Array = [p[3], p[2], p[1], p[0]]
	var ruv: Array = [uv[3], uv[2], uv[1], uv[0]] if uv.size() == 4 else []
	quad(kit, key, r, -n, back_col, ruv)


## A box of `size` centred at `lx` (a local transform inside the frame). `uv_scale` > 0 maps UVs in
## metres (times it) on every face, for tiled textures.
func box(kit: Dictionary, key: String, lx: Transform3D, size: Vector3, col: Color, uv_scale := 0.0, skip_bottom := false) -> void:
	var h := size * 0.5
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for a in range(3):
		for sgn in [-1.0, 1.0]:
			if skip_bottom and a == 1 and sgn < 0.0:
				continue
			var n: Vector3 = axes[a] * sgn
			var u: Vector3 = axes[(a + 1) % 3]
			var v: Vector3 = axes[(a + 2) % 3]
			var c: Vector3 = n * h
			var hu: Vector3 = u * h
			var hv: Vector3 = v * h
			var pts := [lx * (c - hu - hv), lx * (c + hu - hv), lx * (c + hu + hv), lx * (c - hu + hv)]
			var nn: Vector3 = (lx.basis.inverse().transposed() * n).normalized()
			if uv_scale > 0.0:
				var su: float = (lx.basis * (u * size)).length() * uv_scale
				var sv: float = (lx.basis * (v * size)).length() * uv_scale
				quad(kit, key, pts, nn, col, [Vector2(0, 0), Vector2(su, 0), Vector2(su, sv), Vector2(0, sv)])
			else:
				quad(kit, key, pts, nn, col)


## Axis-aligned box between two corners (local frame).
func block(kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color, uv_scale := 0.0) -> void:
	box(kit, key, Transform3D(Basis(), (lo + hi) * 0.5), (hi - lo).abs(), col, uv_scale)


## A box from `a` to `b` (its long axis), `w` wide and `t` thick, the width along `side` (or any
## horizontal if zero): beams, rails, planks and bars.
func beam(kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, t: float, col: Color, side := Vector3.ZERO) -> void:
	var ax := b - a
	var length := ax.length()
	if length < 1e-5:
		return
	var z := ax / length
	var x := side
	if x.length_squared() < 1e-8 or absf(x.normalized().dot(z)) > 0.99:
		x = Vector3.UP.cross(z)
		if x.length_squared() < 1e-6:
			x = Vector3.RIGHT
	x = (x - z * x.dot(z)).normalized()
	var y := z.cross(x).normalized()
	box(kit, key, Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(w, t, length), col)


## A tube from a to b (radius ra at a, rb at b), smooth sided, with optional caps.
func tube(kit: Dictionary, key: String, a: Vector3, b: Vector3, ra: float, rb: float, segs: int, col: Color, caps := true) -> void:
	var d := b - a
	if d.length_squared() < 1e-10:
		return
	var axis := d.normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	var slope := (ra - rb) / maxf(d.length(), 0.001)
	for i in range(segs):
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var n0 := (d0 + axis * slope).normalized()
		var n1 := (d1 + axis * slope).normalized()
		var mid := (d0 + d1).normalized()
		tri(kit, key, a + d0 * ra, a + d1 * ra, b + d1 * rb, n0, n1, n1, col, mid)
		tri(kit, key, a + d0 * ra, b + d1 * rb, b + d0 * rb, n0, n1, n0, col, mid)
		if caps:
			if rb > 0.0:
				tri(kit, key, b, b + d0 * rb, b + d1 * rb, axis, axis, axis, col, axis)
			if ra > 0.0:
				tri(kit, key, a, a + d1 * ra, a + d0 * ra, -axis, -axis, -axis, col, -axis)


## A surface of revolution about the local vertical through `c`: `profile` holds (radius, height)
## pairs from the bottom up, walking the outside. Smooth round the axis, or faceted with `flat`.
## `axis_basis` turns the revolution axis (identity = vertical).
func lathe(kit: Dictionary, key: String, c: Vector3, profile: Array, segs: int, col: Color, flat := false, axis_basis := Basis()) -> void:
	for k in range(profile.size() - 1):
		var p0: Vector2 = profile[k]
		var p1: Vector2 = profile[k + 1]
		var d := p1 - p0
		if d.length_squared() < 1e-12:
			continue
		var n2 := Vector2(d.y, -d.x).normalized()
		for j in range(segs):
			var t0 := TAU * j / segs
			var t1 := TAU * (j + 1) / segs
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var um := (u0 + u1).normalized()
			var out := axis_basis * (um * n2.x + Vector3.UP * n2.y)
			var n0 := out if flat else axis_basis * (u0 * n2.x + Vector3.UP * n2.y)
			var n1 := out if flat else axis_basis * (u1 * n2.x + Vector3.UP * n2.y)
			var q00 := c + axis_basis * (u0 * p0.x + Vector3.UP * p0.y)
			var q01 := c + axis_basis * (u1 * p0.x + Vector3.UP * p0.y)
			var q10 := c + axis_basis * (u0 * p1.x + Vector3.UP * p1.y)
			var q11 := c + axis_basis * (u1 * p1.x + Vector3.UP * p1.y)
			if p0.x > 1e-5 or p1.x > 1e-5:
				tri(kit, key, q00, q01, q11, n0, n1, n1, col, out)
				tri(kit, key, q00, q11, q10, n0, n1, n0, col, out)


## A ring (tyre, torus-like) about the local axis `axis_basis.y` through `c`: a lathe of a rounded
## rectangle between radii r_in and r_out, `h` tall.
func tyre(kit: Dictionary, key: String, c: Vector3, r_in: float, r_out: float, h: float, segs: int, col: Color, axis_basis := Basis()) -> void:
	var rr := minf(h * 0.32, (r_out - r_in) * 0.35)
	var prof: Array = []
	# Outside wall, from the bottom inner edge round to the top inner edge (a closed rounded section).
	prof.append(Vector2(r_in, -h * 0.5 + rr * 0.4))
	prof.append(Vector2(r_in + rr * 0.6, -h * 0.5))
	prof.append(Vector2(r_out - rr, -h * 0.5))
	prof.append(Vector2(r_out - rr * 0.3, -h * 0.5 + rr * 0.3))
	prof.append(Vector2(r_out, -h * 0.5 + rr))
	prof.append(Vector2(r_out, h * 0.5 - rr))
	prof.append(Vector2(r_out - rr * 0.3, h * 0.5 - rr * 0.3))
	prof.append(Vector2(r_out - rr, h * 0.5))
	prof.append(Vector2(r_in + rr * 0.6, h * 0.5))
	prof.append(Vector2(r_in, h * 0.5 - rr * 0.4))
	prof.append(Vector2(r_in, -h * 0.5 + rr * 0.4))
	lathe(kit, key, c, prof, segs, col, false, axis_basis)


## A painted tyre lying flat at `c`: a lathe of a rounded section with tyre_wall.gdshader's UVs (x round
## the tyre, y across the section: lower sidewall, tread, upper sidewall, then the inside of the ring),
## its paint in the vertex colour (black: bare rubber) and `seed` in the alpha, tipped by `tip`. The
## key's material should be tyre_wall.gdshader's.
func painted_tyre(kit: Dictionary, key: String, c: Vector3, r_in: float, r_out: float, h: float, col: Color, seed_v: float, tip := Basis()) -> void:
	var rr := minf(h * 0.3, (r_out - r_in) * 0.32)
	# [radius, height, v]: from the inner bead under it, out across the bottom, up the tread, back in
	# over the top, and down the inside of the ring.
	var prof: Array = [
		[r_in + 0.01, -h * 0.5 + 0.02, 0.0], [r_in + rr * 0.8, -h * 0.5, 0.08], [(r_in + r_out) * 0.5, -h * 0.5 - 0.004, 0.17],
		[r_out - rr, -h * 0.5 + 0.002, 0.26], [r_out - rr * 0.29, -h * 0.5 + rr * 0.29, 0.3], [r_out, -h * 0.5 + rr, 0.34],
		[r_out + 0.004, 0.0, 0.5], [r_out, h * 0.5 - rr, 0.66], [r_out - rr * 0.29, h * 0.5 - rr * 0.29, 0.7],
		[r_out - rr, h * 0.5 - 0.002, 0.74], [(r_in + r_out) * 0.5, h * 0.5 + 0.004, 0.83], [r_in + rr * 0.8, h * 0.5, 0.92],
		[r_in + 0.01, h * 0.5 - 0.02, 1.0], [r_in, 0.0, 1.05], [r_in + 0.01, -h * 0.5 + 0.02, 1.1],
	]
	var segs := 22
	var paint := Color(col.r, col.g, col.b, seed_v)
	for kk in range(prof.size() - 1):
		var p0: Array = prof[kk]
		var p1: Array = prof[kk + 1]
		var d := Vector2(float(p1[0]) - float(p0[0]), float(p1[1]) - float(p0[1]))
		var n2 := Vector2(d.y, -d.x).normalized()
		for j in range(segs):
			var t0 := TAU * j / segs
			var t1 := TAU * (j + 1) / segs
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var q00 := c + tip * (u0 * float(p0[0]) + Vector3.UP * float(p0[1]))
			var q01 := c + tip * (u1 * float(p0[0]) + Vector3.UP * float(p0[1]))
			var q10 := c + tip * (u0 * float(p1[0]) + Vector3.UP * float(p1[1]))
			var q11 := c + tip * (u1 * float(p1[0]) + Vector3.UP * float(p1[1]))
			var n0 := tip * (u0 * n2.x + Vector3.UP * n2.y)
			var n1 := tip * (u1 * n2.x + Vector3.UP * n2.y)
			var out := (n0 + n1).normalized()
			var uv00 := Vector2(float(j) / segs, float(p0[2]))
			var uv01 := Vector2(float(j + 1) / segs, float(p0[2]))
			var uv10 := Vector2(float(j) / segs, float(p1[2]))
			var uv11 := Vector2(float(j + 1) / segs, float(p1[2]))
			tri(kit, key, q00, q01, q11, n0, n1, n1, paint, out, uv00, uv01, uv11)
			tri(kit, key, q00, q11, q10, n0, n1, n0, paint, out, uv00, uv11, uv10)


## An outline in the local x-y plane (x along, y up), extruded across z from z0 to z1, with its edges
## bevelled by `bevel`: vehicle bodies, booths, ramps' side frames. The outline runs counter-clockwise
## seen from +z and may be concave (the side faces are triangulated). Returns nothing; `col_fn`, if
## valid, gives the colour of a face from its centre and normal (stripes, two-tone paint).
func extrude(kit: Dictionary, key: String, outline: PackedVector2Array, z0: float, z1: float, bevel: float, col: Color, col_fn := Callable()) -> void:
	var n := outline.size()
	var ccw := _signed_area(outline) > 0.0
	var inner: PackedVector2Array = _inset(outline, bevel) if bevel > 0.0 else outline
	# Side faces (the outline's planes), from the inset outline.
	var tris := Geometry2D.triangulate_polygon(inner)
	for side in [-1.0, 1.0]:
		var z: float = z0 if side < 0.0 else z1
		var nz := Vector3(0, 0, side)
		for i in range(0, tris.size(), 3):
			var a := Vector3(inner[tris[i]].x, inner[tris[i]].y, z)
			var b := Vector3(inner[tris[i + 1]].x, inner[tris[i + 1]].y, z)
			var c := Vector3(inner[tris[i + 2]].x, inner[tris[i + 2]].y, z)
			var cc: Color = col if not col_fn.is_valid() else col_fn.call((a + b + c) / 3.0, nz)
			tri(kit, key, a, b, c, nz, nz, nz, cc, nz)
	# The rim round the outline: the full outline between the bevels, the bevels out to the sides.
	var zi0 := z0 + bevel
	var zi1 := z1 - bevel
	for i in range(n):
		var j := (i + 1) % n
		var p := outline[i]
		var q := outline[j]
		var e := q - p
		if e.length_squared() < 1e-12:
			continue
		var o2 := Vector2(e.y, -e.x).normalized() if ccw else Vector2(-e.y, e.x).normalized()
		var o3 := Vector3(o2.x, o2.y, 0.0)
		var pi_: Vector2 = inner[i]
		var qi: Vector2 = inner[j]
		var mid := Vector3((p.x + q.x) * 0.5, (p.y + q.y) * 0.5, (z0 + z1) * 0.5)
		var cc: Color = col if not col_fn.is_valid() else col_fn.call(mid, o3)
		quad(kit, key, [Vector3(p.x, p.y, zi0), Vector3(q.x, q.y, zi0), Vector3(q.x, q.y, zi1), Vector3(p.x, p.y, zi1)], o3, cc)
		if bevel > 0.0:
			var nb0 := (o3 - Vector3(0, 0, 1)).normalized()
			var nb1 := (o3 + Vector3(0, 0, 1)).normalized()
			quad(kit, key, [Vector3(pi_.x, pi_.y, z0), Vector3(qi.x, qi.y, z0), Vector3(q.x, q.y, zi0), Vector3(p.x, p.y, zi0)], nb0, cc)
			quad(kit, key, [Vector3(p.x, p.y, zi1), Vector3(q.x, q.y, zi1), Vector3(qi.x, qi.y, z1), Vector3(pi_.x, pi_.y, z1)], nb1, cc)


## Each point of the outline moved `d` inward along its corner's bisector (a mitred inset with the
## same points, so the bevel faces pair up one to one).
static func _inset(outline: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := outline.size()
	var ccw := _signed_area(outline) > 0.0
	for i in range(n):
		var p := outline[i]
		var e0 := (p - outline[(i - 1 + n) % n]).normalized()
		var e1 := (outline[(i + 1) % n] - p).normalized()
		# Inward normals: left of travel on a counter-clockwise outline.
		var n0 := Vector2(-e0.y, e0.x) if ccw else Vector2(e0.y, -e0.x)
		var n1 := Vector2(-e1.y, e1.x) if ccw else Vector2(e1.y, -e1.x)
		var m := (n0 + n1)
		if m.length_squared() < 1e-8:
			m = n0
		m = m.normalized()
		out.append(p + m * (d / maxf(m.dot(n0), 0.35)))
	return out


static func _signed_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(poly.size()):
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		area += p.x * q.y - q.x * p.y
	return area * 0.5


## Commits a kit into one ArrayMesh, a surface per material key (empty surfaces skipped).
func commit(kit: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var keys: Array = kit.keys()
	keys.sort()
	for key in keys:
		var s: SurfaceTool = kit[key]
		s.index()
		var before := mesh.get_surface_count()
		s.commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(mesh.get_surface_count() - 1, material_for.call(key))
	return mesh


## Transform3D array -> MultiMesh buffer (TRANSFORM_3D, no colours or custom data). The dummy
## renderer drops set_instance_transform(), so generators write the buffer itself (CLAUDE.md).
static func transform_buffer(transforms: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(transforms.size() * 12)
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var b: Basis = t.basis
		var o: int = i * 12
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = t.origin.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = t.origin.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = t.origin.z
	return buf
