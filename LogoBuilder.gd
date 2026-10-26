extends RefCounted
## Builds the 3D RC VIBE GP logo from the traced shapes: scratch/logo_trace.gd writes them to
## generated/logo/logo_shapes.json (clean lines and curves, not the JPEG's pixels), regenerate_logo.gd runs
## this and saves the scene.
##
## Three tiers stand on one flat back, as the picture's layers do: the amber rim (the lowest, a thin outline
## round everything), the navy body (every letter's outline, joined) and on it the eight letter faces. Each
## shape is extruded with a rounded edge: a wall up to where the edge starts to turn, then BEVEL_STEPS rings
## of a quarter ellipse, each a copy of the outline pushed in (the "miter" of every vertex, so the rings
## correspond vertex for vertex), then a flat top. Where the outline is thin the push is held back to
## ROOM_SHARE of the room there, so the two sides of a neck or a spike don't cross. Vertices the tracer
## marked as corners get a crease (separate normals for the two edges); everywhere else normals are
## smooth, which is what keeps the clearcoat's highlights clean along a curve.
##
## Space: picture pixels, x right, y up, the logo's centre the origin and z toward the viewer from the flat
## back (z = 0), scaled by PX when the vertices are written. UV is the vertex's place in the picture
## (planar, from the front), UV2.x the tier and UV2.y how far up a wall from where it meets the tier below,
## 0 to 1 (logo_3d.gdshader shades the foot of a wall darker). The faces are built round their own centres
## so a letter can be moved and turned on its own.
##
## Winding: Godot front faces wind clockwise, the face normal of (a, b, c) is (c - a) x (b - a); tri()
## turns any triangle that disagrees with its vertices' normals.

const PolyTriangulate = preload("res://PolyTriangulate.gd")

## Metres per picture pixel: the logo comes out about 11 m wide.
const PX := 0.004
## Where each tier's top lies above the back, in pixels.
const RIM_TOP := 80.0
const BODY_TOP := 108.0
const FACE_TOP := 146.0
## A tier's rounded edge: how far in it runs (x) and how high it rises (y).
const RIM_BEVEL := Vector2(5.0, 5.0)
const BODY_BEVEL := Vector2(13.0, 13.0)
const FACE_BEVEL := Vector2(10.0, 10.0)
const BEVEL_STEPS := 4
## The longest a corner's push may be, in times the push (a spike's tip would otherwise run off).
const MITER_LIMIT := 3.0
const ROOM_SHARE := 0.45
## Edges nearer than this along the outline are the point's own stretch of it, not the far side of a neck.
const SKIP_ARC := 30.0
## A wall is shaded darker over this height (pixels) from where it meets the tier below.
const AO_HEIGHT := 36.0
## The picture is looked up at least this far (pixels) inside a shape's edge, on its walls and bevel too:
## the colours right at the edge are blended with what lies beyond it, and a wall that looked up the edge
## itself showed that as a row of dark ticks.
const UV_INSET := 4.0

const LAYER_RIM := 0
const LAYER_BODY := 1
const LAYER_FACE := 2

const LETTERS_TOP := "RCVIBE"
const LETTERS_BOTTOM := "GP"

## The picture's size, the logo's centre in it (the rim's bounding box) and its top and bottom row.
var size_px := Vector2.ONE
var centre_px := Vector2.ZERO
var y_range := Vector2.ZERO


## Builds every mesh: {"rim": ArrayMesh, "body": ArrayMesh, "faces": [{"name": "R", "mesh": ArrayMesh,
## "pivot": Vector3 (metres, where the face's origin lies in the logo)}, ...]}. `data` is the tracer's JSON.
func build(data: Dictionary) -> Dictionary:
	size_px = Vector2(data["size"][0], data["size"][1])
	y_range = Vector2(data["y_range"][0], data["y_range"][1])
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for s in data["rim"]:
		var flat: Array = s["outer"]["p"]
		for i in flat.size() / 2:
			lo = Vector2(minf(lo.x, flat[i * 2]), minf(lo.y, flat[i * 2 + 1]))
			hi = Vector2(maxf(hi.x, flat[i * 2]), maxf(hi.y, flat[i * 2 + 1]))
	centre_px = (lo + hi) * 0.5

	var t0 := Time.get_ticks_msec()
	var out := {}
	out["rim"] = _plate(_prep_shapes(data["rim"]), LAYER_RIM, 0.0, RIM_TOP, RIM_BEVEL, 0.0, true, true)
	print("  rim in %.1fs" % [(Time.get_ticks_msec() - t0) / 1000.0])
	out["body"] = _plate(_prep_shapes(data["body"]), LAYER_BODY, RIM_TOP - 4.0, BODY_TOP, BODY_BEVEL, RIM_TOP, false, true)
	print("  body in %.1fs" % [(Time.get_ticks_msec() - t0) / 1000.0])

	var faces: Array = (data["faces"] as Array).duplicate()
	var y_mid := (y_range.x + y_range.y) * 0.5
	var top: Array = []
	var bottom: Array = []
	for f in faces:
		if f["centre"][1] < y_mid:
			top.append(f)
		else:
			bottom.append(f)
	top.sort_custom(func(a, b): return a["centre"][0] < b["centre"][0])
	bottom.sort_custom(func(a, b): return a["centre"][0] < b["centre"][0])
	if top.size() != LETTERS_TOP.length() or bottom.size() != LETTERS_BOTTOM.length():
		push_error("LogoBuilder: found %d + %d faces, expected %d + %d" % [top.size(), bottom.size(),
			LETTERS_TOP.length(), LETTERS_BOTTOM.length()])
	var named: Array = []
	for i in top.size():
		named.append([LETTERS_TOP[i], top[i]])
	for i in bottom.size():
		named.append([LETTERS_BOTTOM[i], bottom[i]])
	out["faces"] = []
	for entry in named:
		var f: Dictionary = entry[1]
		var c := Vector2(f["centre"][0] - centre_px.x, centre_px.y - f["centre"][1])
		var pivot := Vector3(c.x, c.y, BODY_TOP)
		var shape := _prep_shape(f)
		var mesh := _plate([shape], LAYER_FACE, BODY_TOP - 4.0, FACE_TOP, FACE_BEVEL, BODY_TOP, false, true, pivot)
		out["faces"].append({"name": entry[0], "mesh": mesh, "pivot": pivot * PX})
	print("  faces in %.1fs" % [(Time.get_ticks_msec() - t0) / 1000.0])
	return out


# ---- Shapes ------------------------------------------------------------------------------------------

func _prep_shapes(shapes: Array) -> Array:
	var out := []
	for s in shapes:
		out.append(_prep_shape(s))
	return out


## A shape as {"outer": loop, "holes": [loop, ...]} in logo space, the outline counter-clockwise and
## the holes clockwise (so the material is always on the left of the way round, and "in" is a left turn).
func _prep_shape(s: Dictionary) -> Dictionary:
	var holes := []
	for hole in s["holes"]:
		holes.append(_prep_loop(hole, false))
	return {"outer": _prep_loop(s["outer"], true), "holes": holes}


func _prep_loop(j: Dictionary, outer: bool) -> Dictionary:
	var flat: Array = j["p"]
	var n := flat.size() / 2
	var pts := PackedVector2Array()
	var corner := PackedByteArray()
	corner.resize(n)
	for i in n:
		pts.append(Vector2(flat[i * 2] - centre_px.x, centre_px.y - flat[i * 2 + 1]))
	for c in j["c"]:
		corner[int(c)] = 1
	if (_area(pts) > 0.0) != outer:
		pts.reverse()
		corner.reverse()
	return {"p": pts, "corner": corner}


func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		a += poly[i].cross(poly[(i + 1) % poly.size()])
	return a * 0.5


# ---- Extrusion ---------------------------------------------------------------------------------------

## One tier: every shape extruded from `z_base` up to `z_top` with the bevel. `contact` is the height of
## the tier below (for the foot's shading); `back_cap` closes the bottom. `pivot` is the origin the
## vertices are written relative to.
func _plate(shapes: Array, layer: int, z_base: float, z_top: float, bevel: Vector2, contact: float,
		back_cap: bool, use_room: bool, pivot := Vector3.ZERO) -> ArrayMesh:
	var md := MeshData.new()
	for s in shapes:
		_add_shape(md, s, layer, z_base, z_top, bevel, contact, back_cap, use_room, pivot)
	return md.commit()


func _add_shape(md: MeshData, shape: Dictionary, layer: int, z_base: float, z_top: float, bevel: Vector2,
		contact: float, back_cap: bool, use_room: bool, pivot: Vector3) -> void:
	var loops: Array = [shape["outer"]]
	loops.append_array(shape["holes"])
	for L in loops:
		_loop_geometry(L)
	for L in loops:
		L["cap"] = _room_caps(L, loops) if use_room else _no_caps(L)
	for L in loops:
		L["rings"] = _rings(L, bevel)

	var ctx := {"md": md, "layer": layer, "pivot": pivot, "contact": contact}
	for L in loops:
		var n: int = (L["p"] as PackedVector2Array).size()
		var ln: PackedVector2Array = L["ln"]
		var corner: PackedByteArray = L["corner"]
		var rings: Array = L["rings"]
		# Vertices: per ring, per point, one for each of the two edges meeting there (the same if smooth).
		var verts: Array = []
		for k in BEVEL_STEPS + 1:
			var t := (float(k) / float(BEVEL_STEPS)) * PI * 0.5
			var z := z_top - bevel.y + bevel.y * sin(t)
			var row: Array = []
			for j in n:
				var o_prev := -ln[(j - 1 + n) % n]
				var o_next := -ln[j]
				var sharp := corner[j] == 1
				var o_smooth := (o_prev + o_next).normalized() if (o_prev + o_next).length() > 1e-3 else o_next
				var look := _look_up(L, k, j, bevel)
				var a := _vertex(ctx, rings[k][j], z, _edge_normal(o_prev if sharp else o_smooth, bevel, t), 1.0 if k > 0 else _foot(z, contact), look)
				var b := a
				if sharp:
					b = _vertex(ctx, rings[k][j], z, _edge_normal(o_next, bevel, t), 1.0 if k > 0 else _foot(z, contact), look)
				row.append(Vector2i(a, b))
			verts.append(row)
		# The wall's foot: ring 0 again, at the base.
		var foot: Array = []
		for j in n:
			var o_prev := -ln[(j - 1 + n) % n]
			var o_next := -ln[j]
			var sharp := corner[j] == 1
			var o_smooth := (o_prev + o_next).normalized() if (o_prev + o_next).length() > 1e-3 else o_next
			var look := _look_up(L, 0, j, bevel)
			var a := _vertex(ctx, rings[0][j], z_base, Vector3((o_prev if sharp else o_smooth).x, (o_prev if sharp else o_smooth).y, 0.0), _foot(z_base, contact), look)
			var b := a
			if sharp:
				b = _vertex(ctx, rings[0][j], z_base, Vector3(o_next.x, o_next.y, 0.0), _foot(z_base, contact), look)
			foot.append(Vector2i(a, b))
		for i in n:
			var j := (i + 1) % n
			md.quad(verts[0][i].y, verts[0][j].x, foot[j].x, foot[i].y)
			for k in BEVEL_STEPS:
				md.quad(verts[k][i].y, verts[k][j].x, verts[k + 1][j].x, verts[k + 1][i].y)

	# The top: the last ring of every loop, triangulated with the holes.
	var outline: PackedVector2Array = shape["outer"]["rings"][BEVEL_STEPS]
	var hole_pts: Array = []
	for hole in shape["holes"]:
		hole_pts.append(hole["rings"][BEVEL_STEPS])
	var cap_idx := PackedInt32Array()
	for p in outline:
		cap_idx.append(_vertex(ctx, p, z_top, Vector3.BACK, 1.0))
	for hp in hole_pts:
		for p in hp:
			cap_idx.append(_vertex(ctx, p, z_top, Vector3.BACK, 1.0))
	var tris := PolyTriangulate.triangulate(outline, hole_pts)
	for t in tris.size() / 3:
		md.tri(cap_idx[tris[t * 3]], cap_idx[tris[t * 3 + 1]], cap_idx[tris[t * 3 + 2]])
	if back_cap:
		var outline0: PackedVector2Array = shape["outer"]["rings"][0]
		var hole0: Array = []
		for hole in shape["holes"]:
			hole0.append(hole["rings"][0])
		var back_idx := PackedInt32Array()
		for p in outline0:
			back_idx.append(_vertex(ctx, p, z_base, Vector3.FORWARD, 0.0))
		for hp in hole0:
			for p in hp:
				back_idx.append(_vertex(ctx, p, z_base, Vector3.FORWARD, 0.0))
		var back_tris := PolyTriangulate.triangulate(outline0, hole0)
		for t in back_tris.size() / 3:
			md.tri(back_idx[back_tris[t * 3]], back_idx[back_tris[t * 3 + 1]], back_idx[back_tris[t * 3 + 2]])


## How dark the foot of a wall is at height z: 0 where it meets the tier below, 1 AO_HEIGHT above.
func _foot(z: float, contact: float) -> float:
	return clampf((z - contact) / AO_HEIGHT, 0.0, 1.0)


## The normal of the bevel at its angle t (0 = where the wall ends, a quarter turn = the flat top): the
## outline's outward normal, raised. A quarter ellipse of x run and y rise has the normal (y cos t, x sin t).
func _edge_normal(out2: Vector2, bevel: Vector2, t: float) -> Vector3:
	return Vector3(out2.x * bevel.y * cos(t), out2.y * bevel.y * cos(t), bevel.x * sin(t)).normalized()


## Where the picture is looked up for ring k's point j: the point pushed in by the ring's own push, but by
## UV_INSET at least.
func _look_up(L: Dictionary, k: int, j: int, bevel: Vector2) -> Vector2:
	var t := (float(k) / float(BEVEL_STEPS)) * PI * 0.5
	var inset := maxf(bevel.x * (1.0 - cos(t)), UV_INSET)
	var miter: Vector2 = (L["miter"] as PackedVector2Array)[j]
	return (L["p"] as PackedVector2Array)[j] + miter * _push(inset, miter, (L["cap"] as PackedFloat32Array)[j])


## A vertex at p (logo space) and height z; its picture UV is at `look` (the same point unless given).
func _vertex(ctx: Dictionary, p: Vector2, z: float, normal: Vector3, foot: float, look := Vector2(INF, INF)) -> int:
	var pivot: Vector3 = ctx["pivot"]
	var at := p if look.x == INF else look
	var uv := Vector2(at.x + centre_px.x, centre_px.y - at.y) / size_px
	return (ctx["md"] as MeshData).vertex(Vector3(p.x - pivot.x, p.y - pivot.y, z - pivot.z) * PX, normal, uv,
		Vector2(ctx["layer"], foot))


## How far in (along the edges' normals) to push a point: `inset`, but not so far that the point itself,
## which a sharp corner's longer miter carries further than that, moves more than `cap`.
func _push(inset: float, miter: Vector2, cap: float) -> float:
	return minf(inset, cap / maxf(miter.length(), 1.0))


## Each point's edge normals (left = inward), the push that moves it one unit in from both its edges (the
## miter, longer at a sharp corner) and the direction of it.
func _loop_geometry(L: Dictionary) -> void:
	var p: PackedVector2Array = L["p"]
	var n := p.size()
	var ln := PackedVector2Array()
	ln.resize(n)
	for i in n:
		var d := (p[(i + 1) % n] - p[i]).normalized()
		ln[i] = Vector2(-d.y, d.x)
	var miter := PackedVector2Array()
	var bis := PackedVector2Array()
	miter.resize(n)
	bis.resize(n)
	for j in n:
		var n0 := ln[(j - 1 + n) % n]
		var n1 := ln[j]
		var sum := n0 + n1
		var b := n0 if sum.length() < 1e-3 else sum.normalized()
		bis[j] = b
		miter[j] = b / maxf(b.dot(n0), 1.0 / MITER_LIMIT)
	L["ln"] = ln
	L["miter"] = miter
	L["bis"] = bis


func _no_caps(L: Dictionary) -> PackedFloat32Array:
	var caps := PackedFloat32Array()
	caps.resize((L["p"] as PackedVector2Array).size())
	caps.fill(INF)
	return caps


## How far in each point can be pushed: ROOM_SHARE of the distance to the nearest edge across the
## material, which is both the way straight in (the far side of a wall, a hole's rim) and the shortest
## distance to any edge that isn't part of the point's own stretch of outline (SKIP_ARC along it). The
## second is what catches a neck that tapers, where the way straight in runs on past the nearest side.
func _room_caps(L: Dictionary, loops: Array) -> PackedFloat32Array:
	var p: PackedVector2Array = L["p"]
	var bis: PackedVector2Array = L["bis"]
	var n := p.size()
	var arc := PackedFloat32Array()
	arc.resize(n)
	for i in range(1, n):
		arc[i] = arc[i - 1] + p[i - 1].distance_to(p[i])
	var total := arc[n - 1] + p[n - 1].distance_to(p[0])
	var caps := PackedFloat32Array()
	caps.resize(n)
	for j in n:
		var r := bis[j]
		var o := p[j] + r * 0.02
		var ray := INF
		var near := INF
		for M in loops:
			var q: PackedVector2Array = M["p"]
			var m := q.size()
			var same := is_same(M, L)
			for e in m:
				var a := q[e]
				var b := q[(e + 1) % m]
				var ab := b - a
				if not (same and _arc_gap(arc, total, j, e, (e + 1) % m) < SKIP_ARC):
					var f := clampf((p[j] - a).dot(ab) / maxf(ab.length_squared(), 1e-12), 0.0, 1.0)
					near = minf(near, p[j].distance_to(a + ab * f))
				var den := r.cross(ab)
				if absf(den) < 1e-9:
					continue
				var t := (a - o).cross(ab) / den
				if t <= 0.0 or t >= ray:
					continue
				var s := (a - o).cross(r) / den
				if s < 0.0 or s > 1.0:
					continue
				ray = t
		caps[j] = minf(ray, near) * ROOM_SHARE
	return caps


## How far apart, along the outline, point j and the edge between points e0 and e1 are.
func _arc_gap(arc: PackedFloat32Array, total: float, j: int, e0: int, e1: int) -> float:
	var g0 := absf(arc[j] - arc[e0])
	var g1 := absf(arc[j] - arc[e1])
	return minf(minf(g0, total - g0), minf(g1, total - g1))


## The loop pushed in by each step of the bevel: BEVEL_STEPS + 1 loops, the first the outline itself.
func _rings(L: Dictionary, bevel: Vector2) -> Array:
	var p: PackedVector2Array = L["p"]
	var miter: PackedVector2Array = L["miter"]
	var cap: PackedFloat32Array = L["cap"]
	var n := p.size()
	var rings := []
	for k in BEVEL_STEPS + 1:
		var t := (float(k) / float(BEVEL_STEPS)) * PI * 0.5
		var inset := bevel.x * (1.0 - cos(t))
		var q := PackedVector2Array()
		q.resize(n)
		for j in n:
			q[j] = p[j] + miter[j] * _push(inset, miter[j], cap[j])
		if k > 0:
			# An edge that ends up running backward (a short one between sharp corners) is collapsed to
			# a point, or the ring would cross itself.
			for pass_i in 2:
				for i in n:
					var j := (i + 1) % n
					if (q[j] - q[i]).dot(p[j] - p[i]) < 0.0:
						var mid := (q[i] + q[j]) * 0.5
						q[i] = mid
						q[j] = mid
			_cure(q)
		rings.append(q)
	return rings


## A collapse of more than a few points, or of any area, means a shape the bevel doesn't fit: it is
## reported (the tips of spikes collapse three to nine points of no area, and that is as it should be).
func _warn_big(points: int, area: float, at: Vector2) -> void:
	if points > 12 or absf(area) > 30.0:
		push_warning("LogoBuilder: a bevel ring collapses %d points (area %.0f) at %s" % [points, area, at])


## Wherever two edges of the ring cross (a spike or a neck narrower than the push leaves a swallowtail),
## the stretch of ring between them, the smaller of the two, collapses to the crossing. The ring keeps
## its vertex count, so it still corresponds to the one outside it.
func _cure(q: PackedVector2Array) -> void:
	var n := q.size()
	for round_i in 60:
		var hit := false
		for i in n:
			var a := q[i]
			var b := q[(i + 1) % n]
			if a == b:
				continue
			for j in range(i + 2, n):
				if i == 0 and j == n - 1:
					continue
				var c := q[j]
				var d := q[(j + 1) % n]
				if c == d:
					continue
				var d1 := (b - a).cross(c - a)
				var d2 := (b - a).cross(d - a)
				var d3 := (d - c).cross(a - c)
				var d4 := (d - c).cross(b - c)
				if d1 * d2 >= 0.0 or d3 * d4 >= 0.0:
					continue
				var x := a + (b - a) * (d3 / (d3 - d4))
				var inner := PackedVector2Array([x])
				for k in range(i + 1, j + 1):
					inner.append(q[k])
				var rest := PackedVector2Array([x])
				for k in range(j + 1, n + i + 1):
					rest.append(q[k % n])
				if absf(_area(inner)) <= absf(_area(rest)):
					_warn_big(j - i, _area(inner), x)
					for k in range(i + 1, j + 1):
						q[k] = x
				else:
					_warn_big(n - (j - i), _area(rest), x)
					for k in range(j + 1, n + i + 1):
						q[k % n] = x
				hit = true
				break
			if hit:
				break
		if not hit:
			return


## An indexed mesh being built: vertices with their normal, UV and UV2, and triangles.
class MeshData:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func vertex(p: Vector3, normal: Vector3, uv_: Vector2, uv2_: Vector2) -> int:
		v.append(p)
		n.append(normal)
		uv.append(uv_)
		uv2.append(uv2_)
		return v.size() - 1

	## A triangle whose front face agrees with its vertex normals. Degenerate ones are dropped.
	func tri(a: int, b: int, c: int) -> void:
		var f := (v[c] - v[a]).cross(v[b] - v[a])
		if f.length_squared() < 1e-18:
			return
		if f.dot(n[a] + n[b] + n[c]) < 0.0:
			var t := b
			b = c
			c = t
		idx.append(a)
		idx.append(b)
		idx.append(c)

	## Quad a-b-c-d in order round it.
	func quad(a: int, b: int, c: int, d: int) -> void:
		if v[a].distance_squared_to(v[c]) <= v[b].distance_squared_to(v[d]):
			tri(a, b, c)
			tri(a, c, d)
		else:
			tri(a, b, d)
			tri(b, c, d)

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
