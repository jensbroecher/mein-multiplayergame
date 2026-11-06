extends RefCounted
## Rheinufer (Kronburg GP, stage 2): the Rhine's two bridges, the elevated roads' piers and abutments, the Autobahn's
## furniture and the power line's towers. All fictional: generic German types, no real bridge copied.
##
## Two kinds of builder:
##  * GAME metres (the preview and the generator call new_kit(1.0) and place them with a translation only), fitted to the
##    race road: old_bridge, harp_bridge, viaduct_pier, abutment. Human-scale parts in them (railings, lamp posts, plaques,
##    ladders) are life x 1.6 (PS). Their labels are in game metres too: do NOT grow them by PROP_SCALE.
##  * LIFE size (the caller grows them by PROP_SCALE 1.6): sign_gantry, exit_sign, notrufsaeule, noise_wall,
##    concrete_barrier, guardrail, race_closure, kilometre_board, transmission_tower, conductor.
##
## The road surfaces ("ribbons") and every collider are the generator's: nothing here is drivable, and nothing is built in
## the carriageways' clearance boxes (see old_bridge and harp_bridge; check_clearance() samples a kit against them).
##
## Material keys (make_material): masonry "ashlar" (hut_masonry 10: sandstone and, darker, basalt lava), "kbrick" (12, Ruhr
## brick), "kslate" (11, slate), "concrete" (8, board-formed); steel "bsteel" (the old bridge's painted riveted steel),
## "rivet" (the same with rivet heads drawn on a grid from the UVs: gusset and cover plates), "msteel" (modern painted steel),
## "galv" (galvanised), "galv2" (galvanised, two-sided sheet: guardrail beams), all rhein_steel.gdshader but galv2; "cable"
## (stays and conductors), "railing" and "barrail" (rhein_railing.gdshader: an ornamental cast-iron railing and a modern bar
## railing drawn on a quad, two-sided, holes discarded), "glasswall" (rhein_noise_glass.gdshader: a noise wall's clear panels
## with bird-strike stripes), "cassette" (hut_roof_iron: aluminium noise-wall cassettes), "walk" (paving), "signface"
## (sign paint), "paint", "matte", "rubber", "plastic", "steel" and "lamp" (YardKit.lantern's keys), "glow" (LampGlow: lamps
## that are lit: warning and obstacle lights), "lens" (an unlit lamp's glass), "copper", "gold".
##
## Godot's front faces wind clockwise; PropKit.tri winds every triangle for the `out` it is given.

const PropKit = preload("res://PropKit.gd")
const YardKit = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")
const LampGlow = preload("res://LampGlow.gd")

static var uvk := 1.0
static var _mats := {}
## The current sub-assembly's offset inside the kit's own frame (labels are given in kit coordinates).
static var _lx := Transform3D.IDENTITY

## Human-scale parts on the game-metre bridges are life x PS.
const PS := 1.6
## Masonry UVs on the game-metre builders are scaled by this: hut_masonry's ashlar courses (0.62 UV) come out 0.89m.
const MUV := 0.7
## Bearings on the viaduct piers and abutments stand this high over the cap's top (top_y).
const BEARING_H := 0.4
const TANGENT_KEYS := ["concrete", "kslate", "cassette"]

const SANDSTONE := Color(0.71, 0.63, 0.51)
const SANDSTONE_DK := Color(0.62, 0.55, 0.45)
const BASALT := Color(0.44, 0.43, 0.42)
const BRICK := Color(0.47, 0.23, 0.17)
const SLATE := Color(0.27, 0.29, 0.32)
const VERDIGRIS := Color(0.38, 0.60, 0.52)
const OLD_STEEL := Color(0.34, 0.41, 0.38)
const OLD_STEEL_DK := Color(0.25, 0.30, 0.28)
const CAST := Color(0.15, 0.18, 0.17)
const GRANITE := Color(0.58, 0.58, 0.57)
const WALK := Color(0.40, 0.39, 0.37)
const NEW_STEEL := Color(0.70, 0.73, 0.72)
const CONCRETE := Color(0.62, 0.62, 0.60)
const GALV := Color(0.66, 0.68, 0.68)
const CABLE := Color(0.30, 0.31, 0.32)
const SIGN_BLUE := Color(0.05, 0.25, 0.60)
const WHITE := Color(0.95, 0.95, 0.93)
const BLACK := Color(0.04, 0.04, 0.04)
const SIGN_RED := Color(0.78, 0.07, 0.08)
const SIGN_YELLOW := Color(0.98, 0.78, 0.05)
const ORANGE := Color(0.95, 0.42, 0.06)
const KR_RED := Color(0.72, 0.10, 0.10)
const KR_GOLD := Color(0.92, 0.72, 0.22)
const BRONZE := Color(0.36, 0.26, 0.15)


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"ashlar", "kbrick", "kslate", "concrete":
			var m := ShaderMaterial.new()
			m.shader = load("res://hut_masonry.gdshader")
			m.set_shader_parameter("style", {"ashlar": 10, "kbrick": 12, "kslate": 11, "concrete": 8}[key])
			return m
		"bsteel", "rivet", "msteel", "galv":
			var s := ShaderMaterial.new()
			s.shader = load("res://rhein_steel.gdshader")
			match key:
				"bsteel", "rivet":
					s.set_shader_parameter("rust_amount", 0.14)
					s.set_shader_parameter("grime", 0.45)
					s.set_shader_parameter("rough", 0.6)
					s.set_shader_parameter("metal", 0.2)
					s.set_shader_parameter("patch_size", 3.5)
					s.set_shader_parameter("rivets", 1.0 if key == "rivet" else 0.0)
				"msteel":
					s.set_shader_parameter("rust_amount", 0.03)
					s.set_shader_parameter("grime", 0.3)
					s.set_shader_parameter("rough", 0.5)
					s.set_shader_parameter("metal", 0.15)
					s.set_shader_parameter("patch_size", 6.0)
				"galv":
					s.set_shader_parameter("rust_amount", 0.02)
					s.set_shader_parameter("grime", 0.25)
					s.set_shader_parameter("rough", 0.42)
					s.set_shader_parameter("metal", 0.6)
					s.set_shader_parameter("patch_size", 2.0)
			return s
		"railing", "barrail":
			var r := ShaderMaterial.new()
			r.shader = load("res://rhein_railing.gdshader")
			r.set_shader_parameter("style", 0 if key == "railing" else 1)
			r.set_shader_parameter("height", 1.76 if key == "railing" else HB_RAIL_H)
			return r
		"glasswall":
			var g := ShaderMaterial.new()
			g.shader = load("res://rhein_noise_glass.gdshader")
			return g
		"cassette":
			var c := ShaderMaterial.new()
			c.shader = load("res://hut_roof_iron.gdshader")
			c.set_shader_parameter("rust_amount", 0.0)
			c.set_shader_parameter("pitch", 0.2)
			c.set_shader_parameter("sheet_w", 0.5)
			c.set_shader_parameter("sheet_len", 4.0)
			return c
		"glow":
			return LampGlow.material(2.6)
		"lamp":
			return CampKit.make_material("lamp")
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.vertex_color_is_srgb = true
	sm.roughness = 0.7
	match key:
		"cable":
			sm.metallic = 0.7
			sm.roughness = 0.4
		"galv2":
			sm.metallic = 0.6
			sm.roughness = 0.38
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		"walk":
			sm.roughness = 0.95
		"signface":
			sm.roughness = 0.32
		"paint":
			sm.roughness = 0.5
		"matte":
			sm.roughness = 0.95
		"rubber":
			sm.roughness = 0.92
			sm.metallic_specular = 0.25
		"plastic":
			sm.roughness = 0.38
		"steel":
			sm.metallic = 0.3
			sm.roughness = 0.55
		"lens":
			sm.roughness = 0.12
			sm.metallic = 0.3
		"copper":
			sm.roughness = 0.62
			sm.metallic = 0.2
		"gold":
			sm.metallic = 1.0
			sm.roughness = 0.3
	return sm


## A kit growing everything by `scale`, its materials shared with every other kit made here.
static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	_lx = Transform3D.IDENTITY
	return pk


## The materials made so far, by key (the generator saves them so every mesh shares one per key).
static func materials() -> Dictionary:
	return _mats


## Commits a kit (a surface per key, named after it) with tangents on the surfaces whose shaders read a normal map.
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in TANGENT_KEYS:
		if kit.has(key):
			var s: SurfaceTool = kit[key]
			s.index()
			s.generate_tangents()
	var mesh := ArrayMesh.new()
	var keys: Array = kit.keys()
	keys.sort()
	for key in keys:
		var st: SurfaceTool = kit[key]
		st.index()
		var before := mesh.get_surface_count()
		st.commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(before, pk.material_for.call(key))
			mesh.surface_set_name(before, key)
	return mesh


# ======================================================================================
#  Helpers
# ======================================================================================

## Moves the kit's frame by `t` (a sub-assembly); returns what `_pop` puts back.
static func _push(pk: PropKit, t: Transform3D) -> Array:
	var saved: Array = [pk.xf, _lx]
	pk.set_frame(pk.xf * t)
	_lx = _lx * t
	return saved


static func _pop(pk: PropKit, saved: Array) -> void:
	pk.set_frame(saved[0])
	_lx = saved[1]


## A label in the current sub-assembly's frame, stored in the kit's: its cap height and width grow with the frame's scale.
static func _label(labels: Array, text: String, p: Vector3, n: Vector3, cap: float, col: Color, w := 0.0) -> void:
	var s: float = _lx.basis.x.length()
	labels.append([text, _lx * p, (_lx.basis * n).normalized(), cap * s, col, w * s])


## Axis-aligned block between two corners, UVs in metres.
static func _blk(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color, uvs := 1.0) -> void:
	pk.block(kit, key, Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z)), Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z)), col, uvk * uvs)


## A box centred at `c` turned by `basis`, UVs in metres.
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color, uvs := 1.0) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk * uvs)


## A beam from a to b, `w` across `side`, `t` across both, UVs in metres.
static func _bar(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, t: float, col: Color, side := Vector3.ZERO) -> void:
	pk.beam(kit, key, a, b, w, t, col, side, uvk)


## A four-sided member from a to b with no end caps (8 triangles): lattice bars, posts, struts whose ends are buried.
static func _strut(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, w: float, t: float, col: Color, side := Vector3.ZERO) -> void:
	var ax := b - a
	var l := ax.length()
	if l < 1e-4:
		return
	var zz := ax / l
	var xx := side
	if xx.length_squared() < 1e-8 or absf(xx.normalized().dot(zz)) > 0.99:
		xx = Vector3.UP.cross(zz)
		if xx.length_squared() < 1e-6:
			xx = Vector3.RIGHT
	xx = (xx - zz * xx.dot(zz)).normalized()
	var yy := zz.cross(xx).normalized()
	var hx := xx * (w * 0.5)
	var hy := yy * (t * 0.5)
	var c: Array = [hx + hy, -hx + hy, -hx - hy, hx - hy]
	for k in 4:
		var p0: Vector3 = c[k]
		var p1: Vector3 = c[(k + 1) % 4]
		var n: Vector3 = (p0 + p1).normalized()
		pk.quad(kit, key, [a + p0, a + p1, b + p1, b + p0], n, col)


## A quad with a normal per corner (smooth shading across a curved surface).
static func _qn(pk: PropKit, kit: Dictionary, key: String, p: Array, n: Array, col: Color, uv: Array = []) -> void:
	var out: Vector3 = (n[0] as Vector3) + (n[1] as Vector3) + (n[2] as Vector3) + (n[3] as Vector3)
	if uv.size() == 4:
		pk.tri(kit, key, p[0], p[1], p[2], n[0], n[1], n[2], col, out, uv[0], uv[1], uv[2])
		pk.tri(kit, key, p[0], p[2], p[3], n[0], n[2], n[3], col, out, uv[0], uv[2], uv[3])
	else:
		pk.tri(kit, key, p[0], p[1], p[2], n[0], n[1], n[2], col, out)
		pk.tri(kit, key, p[0], p[2], p[3], n[0], n[2], n[3], col, out)


## Sweeps a cross-section along a path: at station k the profile point (a, b) lies at origins[k] + sides[k] * a + ups[k] * b.
## Walk the profile with the solid on your left (a to the right, b up; a closed profile counter-clockwise): each edge then
## faces right of its travel. `smooth` shades across the profile's corners (round sections); along the path it is always
## smooth. UVs in metres times `uvs`: u along the path, v round the profile. `caps` closes the ends of a closed profile.
static func _sweep(pk: PropKit, kit: Dictionary, key: String, origins: PackedVector3Array, sides: Array, ups: Array, prof: PackedVector2Array, col: Color,
		closed := false, smooth := false, caps := false, uvs := 1.0) -> void:
	var ns := origins.size()
	var np := prof.size()
	if ns < 2 or np < 2:
		return
	var ne: int = np if closed else np - 1
	# Edge normals in profile space (right of travel), and per-point normals for smooth sections.
	var en: Array = []
	var elen: Array = []
	for e in ne:
		var p: Vector2 = prof[e]
		var q: Vector2 = prof[(e + 1) % np]
		var d := q - p
		en.append(Vector2(d.y, -d.x).normalized())
		elen.append(d.length())
	var run: Array = [0.0]
	for k in range(1, ns):
		run.append(float(run[k - 1]) + origins[k].distance_to(origins[k - 1]))
	var vrun: Array = [0.0]
	for e in ne:
		vrun.append(float(vrun[e]) + float(elen[e]))
	for e in ne:
		var i0: int = e
		var i1: int = (e + 1) % np
		var a0: Vector2 = prof[i0]
		var a1: Vector2 = prof[i1]
		var n_e: Vector2 = en[e]
		var n0: Vector2 = n_e
		var n1: Vector2 = n_e
		if smooth:
			var prev: int = e - 1 if e > 0 else (ne - 1 if closed else -1)
			var nxt: int = e + 1 if e < ne - 1 else (0 if closed else -1)
			if prev >= 0:
				n0 = (n_e + (en[prev] as Vector2)).normalized()
			if nxt >= 0:
				n1 = (n_e + (en[nxt] as Vector2)).normalized()
		for k in ns - 1:
			var o0: Vector3 = origins[k]
			var o1: Vector3 = origins[k + 1]
			var s0: Vector3 = sides[k]
			var s1: Vector3 = sides[k + 1]
			var u0: Vector3 = ups[k]
			var u1: Vector3 = ups[k + 1]
			var pa := o0 + s0 * a0.x + u0 * a0.y
			var pb := o0 + s0 * a1.x + u0 * a1.y
			var pc := o1 + s1 * a1.x + u1 * a1.y
			var pd := o1 + s1 * a0.x + u1 * a0.y
			var na := (s0 * n0.x + u0 * n0.y).normalized()
			var nb := (s0 * n1.x + u0 * n1.y).normalized()
			var nc := (s1 * n1.x + u1 * n1.y).normalized()
			var nd := (s1 * n0.x + u1 * n0.y).normalized()
			var uk: float = uvk * uvs
			var uv := [Vector2(float(run[k]), float(vrun[e])) * uk, Vector2(float(run[k]), float(vrun[e + 1])) * uk,
					Vector2(float(run[k + 1]), float(vrun[e + 1])) * uk, Vector2(float(run[k + 1]), float(vrun[e])) * uk]
			_qn(pk, kit, key, [pa, pb, pc, pd], [na, nb, nc, nd], col, uv)
	if caps and closed and np >= 3:
		var tris := Geometry2D.triangulate_polygon(prof)
		for end in [0, ns - 1]:
			var o: Vector3 = origins[end]
			var sd: Vector3 = sides[end]
			var up: Vector3 = ups[end]
			var along: Vector3 = (origins[mini(end + 1, ns - 1)] - origins[maxi(end - 1, 0)]).normalized()
			var cn: Vector3 = -along if end == 0 else along
			for i in range(0, tris.size(), 3):
				var a: Vector2 = prof[tris[i]]
				var b: Vector2 = prof[tris[i + 1]]
				var c: Vector2 = prof[tris[i + 2]]
				pk.tri(kit, key, o + sd * a.x + up * a.y, o + sd * b.x + up * b.y, o + sd * c.x + up * c.y, cn, cn, cn, col, cn,
						a * uvk * uvs, b * uvk * uvs, c * uvk * uvs)


## The profile mirrored across a = 0 (and walked the other way, so it still keeps the solid on its left).
static func _mirror_prof(prof: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(prof.size() - 1, -1, -1):
		out.append(Vector2(-prof[i].x, prof[i].y))
	return out


## A rectangle (a counter-clockwise profile) centred on (ca, cb), `w` wide (a) and `h` tall (b).
static func _rect_prof(w: float, h: float, ca := 0.0, cb := 0.0) -> PackedVector2Array:
	return PackedVector2Array([Vector2(ca - w * 0.5, cb - h * 0.5), Vector2(ca + w * 0.5, cb - h * 0.5), Vector2(ca + w * 0.5, cb + h * 0.5),
			Vector2(ca - w * 0.5, cb + h * 0.5)])


## Stations for a section swept along a polyline whose side axis is fixed (`side`, horizontal): the up axis is the
## path's normal in the plane square to `side`, turned upward. Returns [origins, sides, ups].
static func _path_frames(pts: PackedVector3Array, side: Vector3) -> Array:
	var sd := side.normalized()
	var sides: Array = []
	var ups: Array = []
	var n := pts.size()
	for i in n:
		var t: Vector3
		if i == 0:
			t = pts[1] - pts[0]
		elif i == n - 1:
			t = pts[n - 1] - pts[n - 2]
		else:
			t = pts[i + 1] - pts[i - 1]
		t = (t - sd * t.dot(sd)).normalized()
		var u := sd.cross(t).normalized()
		if u.y < 0.0:
			u = -u
		sides.append(sd)
		ups.append(u)
	return [pts, sides, ups]


## A rectangular member `w` (across `side`) by `h` swept along `pts`, offset (a, b) from the path: chords, ties, rails.
static func _loft_box(pk: PropKit, kit: Dictionary, key: String, pts: PackedVector3Array, side: Vector3, w: float, h: float, col: Color, caps := true,
		off := Vector2.ZERO) -> void:
	if pts.size() < 2:
		return
	var f: Array = _path_frames(pts, side)
	_sweep(pk, kit, key, f[0], f[1], f[2], _rect_prof(w, h, off.x, off.y), col, true, false, caps)


## Stations along x for a section that follows y = yfn(x) (vertical sections across z): [origins, sides, ups].
static func _x_frames(xs: Array, yfn: Callable, z := 0.0) -> Array:
	var o := PackedVector3Array()
	var s: Array = []
	var u: Array = []
	for x in xs:
		o.append(Vector3(float(x), float(yfn.call(float(x))), z))
		s.append(Vector3(0, 0, 1))
		u.append(Vector3(0, 1, 0))
	return [o, s, u]


## Evenly spaced stations from x0 to x1, about `step` apart, both ends included.
static func _stations(x0: float, x1: float, step: float) -> Array:
	var n: int = maxi(1, int(ceil(absf(x1 - x0) / step)))
	var out: Array = []
	for i in n + 1:
		out.append(lerpf(x0, x1, float(i) / float(n)))
	return out


## An outline in the z-y plane (a, b = z, y) extruded across x from x0 to x1 (PropKit.extrude through a swapped frame).
static func _ext_zy(pk: PropKit, kit: Dictionary, key: String, outline: PackedVector2Array, x0: float, x1: float, col: Color, bevel := 0.0, uvs := 1.0) -> void:
	var saved := _push(pk, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3.ZERO))
	pk.extrude(kit, key, outline, x0, x1, bevel, col, Callable(), uvk * uvs)
	_pop(pk, saved)


## An outline in the x-y plane extruded across z from z0 to z1.
static func _ext_xy(pk: PropKit, kit: Dictionary, key: String, outline: PackedVector2Array, z0: float, z1: float, col: Color, bevel := 0.0, uvs := 1.0) -> void:
	pk.extrude(kit, key, outline, z0, z1, bevel, col, Callable(), uvk * uvs)


## Rings of equal point count, each a closed loop (x, y, z), joined into a band of quads facing away from each ring's
## vertical axis (or up/down where they lie flat). Corners sharper than `crease` degrees stay sharp. UVs in metres times
## `uvs`: u round the first ring, v the height.
static func _rings(pk: PropKit, kit: Dictionary, key: String, rings: Array, col: Color, crease := 35.0, uvs := MUV, flat_up := true) -> void:
	var nr := rings.size()
	if nr < 2:
		return
	var r0: PackedVector3Array = rings[0]
	var np := r0.size()
	var urun: Array = [0.0]
	for i in np:
		urun.append(float(urun[i]) + Vector2(r0[(i + 1) % np].x - r0[i].x, r0[(i + 1) % np].z - r0[i].z).length())
	var cosc := cos(deg_to_rad(crease))
	for k in nr - 1:
		var lo: PackedVector3Array = rings[k]
		var hi: PackedVector3Array = rings[k + 1]
		var c := Vector3.ZERO
		for p in lo:
			c += p
		c /= float(np)
		# Face normals.
		var fn: Array = []
		for i in np:
			var j: int = (i + 1) % np
			var n := (lo[j] - lo[i]).cross(hi[i] - lo[i])
			if n.length_squared() < 1e-12:
				n = (lo[j] - lo[i]).cross(hi[j] - lo[i])
			n = n.normalized()
			var mid: Vector3 = (lo[i] + lo[j] + hi[i] + hi[j]) * 0.25
			var away := Vector3(mid.x - c.x, 0, mid.z - c.z)
			if absf(n.y) > 0.7:
				# Lying flat (a ledge's top, a corbel's underside, a hood): up or down as asked.
				if (n.y < 0.0) == flat_up:
					n = -n
			elif away.length_squared() > 1e-6:
				if n.dot(away) < 0.0:
					n = -n
			fn.append(n)
		for i in np:
			var j: int = (i + 1) % np
			var n_i: Vector3 = fn[i]
			var n_prev: Vector3 = fn[(i - 1 + np) % np]
			var n_next: Vector3 = fn[j]
			var na: Vector3 = (n_i + n_prev).normalized() if n_i.dot(n_prev) > cosc else n_i
			var nb: Vector3 = (n_i + n_next).normalized() if n_i.dot(n_next) > cosc else n_i
			var u0: float = float(urun[i]) * uvk * uvs
			var u1: float = float(urun[i + 1]) * uvk * uvs
			_qn(pk, kit, key, [lo[i], lo[j], hi[j], hi[i]], [na, nb, nb, na], col,
					[Vector2(u0, lo[i].y * uvk * uvs), Vector2(u1, lo[j].y * uvk * uvs), Vector2(u1, hi[j].y * uvk * uvs), Vector2(u0, hi[i].y * uvk * uvs)])


## A flat cap over a ring (x, z at its own heights), facing up (or down).
static func _cap(pk: PropKit, kit: Dictionary, key: String, ring: PackedVector3Array, col: Color, up := true, uvs := MUV) -> void:
	var poly := PackedVector2Array()
	for p in ring:
		poly.append(Vector2(p.x, p.z))
	var tris := Geometry2D.triangulate_polygon(poly)
	var n := Vector3.UP if up else Vector3.DOWN
	for i in range(0, tris.size(), 3):
		var a: Vector3 = ring[tris[i]]
		var b: Vector3 = ring[tris[i + 1]]
		var c: Vector3 = ring[tris[i + 2]]
		pk.tri(kit, key, a, b, c, n, n, n, col, n, Vector2(a.x, a.z) * uvk * uvs, Vector2(b.x, b.z) * uvk * uvs, Vector2(c.x, c.z) * uvk * uvs)


## A 2D ring (x, z) lifted to height y, offset to (cx, cz).
static func _lift(ring: PackedVector2Array, y: float, cx := 0.0, cz := 0.0) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in ring:
		out.append(Vector3(p.x + cx, y, p.y + cz))
	return out


## A vertical prism over a 2D ring from y0 to y1 (sides and, with `top`, a cap), its ring shrunk to `ring_hi` at the top
## for a batter (same point count).
static func _prism(pk: PropKit, kit: Dictionary, key: String, ring_lo: PackedVector2Array, y0: float, ring_hi: PackedVector2Array, y1: float, col: Color,
		top := true, cx := 0.0, cz := 0.0, crease := 35.0) -> void:
	var lo := _lift(ring_lo, y0, cx, cz)
	var hi := _lift(ring_hi, y1, cx, cz)
	_rings(pk, kit, key, [lo, hi], col, crease)
	if top:
		_cap(pk, kit, key, hi, col.lightened(0.04))


## A rounded rectangle ring (x, z): half sizes hx, hz, corner radius r, `seg` points a corner. Counter-clockwise seen from
## above with z toward the viewer... (the helpers above orient by geometry, so the sense does not matter).
static func _rrect(hx: float, hz: float, r: float, seg := 3) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rr: float = minf(r, minf(hx, hz) - 0.001)
	var cs := [Vector2(hx - rr, hz - rr), Vector2(-hx + rr, hz - rr), Vector2(-hx + rr, -hz + rr), Vector2(hx - rr, -hz + rr)]
	for k in 4:
		var c: Vector2 = cs[k]
		for i in seg + 1:
			var a: float = PI * 0.5 * float(k) + PI * 0.5 * float(i) / float(seg)
			out.append(c + Vector2(cos(a), sin(a)) * rr)
	return out


## A river pier's plan (x, z): a body hx by hz, a pointed cutwater `nose` long on +z (the current comes from +z: the
## Rhine flows toward -z) and a round end on -z. `n_arc` points on each curve.
static func _pier_plan(hx: float, hz: float, nose: float, n_arc := 6) -> PackedVector2Array:
	var out := PackedVector2Array()
	# Up the +x side from the round end's start to the cutwater's.
	out.append(Vector2(hx, -hz))
	out.append(Vector2(hx, hz))
	# The pointed nose: two circular arcs meeting on the axis.
	var r: float = (hx * hx + nose * nose) / (2.0 * hx)
	var c := Vector2(hx - r, hz)
	var tip_a: float = atan2(nose, -(hx - r))
	for i in range(1, n_arc + 1):
		var a: float = tip_a * float(i) / float(n_arc)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	var c2 := Vector2(-(hx - r), hz)
	for i in range(n_arc - 1, -1, -1):
		var a: float = tip_a * float(i) / float(n_arc)
		out.append(c2 + Vector2(-cos(a), sin(a)) * r)
	out.append(Vector2(-hx, -hz))
	# The round downstream end.
	for i in range(1, n_arc * 2):
		var a: float = PI + PI * float(i) / float(n_arc * 2)
		out.append(Vector2(0, -hz) + Vector2(cos(a), sin(a)) * hx)
	return out


## The same plan with every point beyond the body (|z| > hz) pulled back onto the body's end: a cutwater's hood's top ring.
static func _plan_clamped(plan: PackedVector2Array, hz: float, shrink := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in plan:
		out.append(Vector2(p.x * shrink, clampf(p.y, -hz, hz)))
	return out


## Every point of a ring moved out by `d` along its corner's bisector (a mitred offset with the same points).
static func _offset_ring(ring: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ring.size()
	var c := Vector2.ZERO
	for p in ring:
		c += p
	c /= float(n)
	for i in n:
		var p := ring[i]
		var e0 := (p - ring[(i - 1 + n) % n]).normalized()
		var e1 := (ring[(i + 1) % n] - p).normalized()
		var n0 := Vector2(e0.y, -e0.x)
		var n1 := Vector2(e1.y, -e1.x)
		var m := n0 + n1
		if m.length_squared() < 1e-8:
			m = n0
		m = m.normalized()
		# Outward: away from the centre.
		if m.dot(p - c) < 0.0:
			m = -m
			n0 = -n0
		out.append(p + m * (d / maxf(absf(m.dot(n0)), 0.4)))
	return out


## Samples a kit's triangles against clearance bands: each band [z0, z1, allow] (local z, game metres) is clear from
## deck(x) + allow up to deck(x) + 9.5 (allow -0.06: nothing over the road; 1.0: a kerb barrier). Returns
## [count, PackedStringArray of the first few: where]. Run it on a bridge's kit before committing (the frame's identity).
static func check_clearance(kit: Dictionary, deck: Callable, bands: Array, x0: float, x1: float, head := 9.5) -> Array:
	var tris := PropKit.kit_triangles(kit)
	var bad := 0
	var notes := PackedStringArray()
	var bary: Array = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0.5, 0.5, 0), Vector3(0, 0.5, 0.5), Vector3(0.5, 0, 0.5),
			Vector3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0), Vector3(0.7, 0.15, 0.15), Vector3(0.15, 0.7, 0.15), Vector3(0.15, 0.15, 0.7)]
	for i in range(0, tris.size(), 3):
		var a: Vector3 = tris[i]
		var b: Vector3 = tris[i + 1]
		var c: Vector3 = tris[i + 2]
		var zmin: float = minf(a.z, minf(b.z, c.z))
		var zmax: float = maxf(a.z, maxf(b.z, c.z))
		var xmin: float = minf(a.x, minf(b.x, c.x))
		var xmax: float = maxf(a.x, maxf(b.x, c.x))
		if xmax < x0 or xmin > x1:
			continue
		for band in bands:
			var z0: float = band[0]
			var z1: float = band[1]
			if zmax <= z0 + 0.005 or zmin >= z1 - 0.005:
				continue
			var hit := false
			for w in bary:
				var p: Vector3 = a * w.x + b * w.y + c * w.z
				if p.z <= z0 + 0.005 or p.z >= z1 - 0.005 or p.x < x0 or p.x > x1:
					continue
				var d: float = deck.call(p.x)
				if p.y > d + float(band[2]) + 0.005 and p.y < d + head - 0.005:
					hit = true
					if notes.size() < 12:
						notes.append("(%.2f, %.2f, %.2f) deck %.2f band %.1f..%.1f" % [p.x, p.y, p.z, d, z0, z1])
					break
			if hit:
				bad += 1
				break
	return [bad, notes]


## An I-section from a to b: `d` deep along `up` (made square to the axis), flanges `f` wide (36 triangles).
static func _ibeam(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, d: float, f: float, col: Color, up := Vector3.UP, tw := 0.04, tf := 0.06) -> void:
	var ax := b - a
	if ax.length_squared() < 1e-8:
		return
	ax = ax.normalized()
	var u := up - ax * up.dot(ax)
	if u.length_squared() < 1e-6:
		u = Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.BACK
	u = u.normalized()
	var s := ax.cross(u).normalized()
	pk.beam(kit, key, a, b, tw, d - tf * 2.0 + 0.012, col, s)
	for sg in [-1.0, 1.0]:
		var o: Vector3 = u * (sg * (d * 0.5 - tf * 0.5))
		pk.beam(kit, key, a + o, b + o, f, tf, col, s)


## A wall face in the plane through `o` (its lower left corner seen from outside; o.y is ignored, v is the height), `along`
## to the right, facing `out`, `w` wide from height y0 to y1. Openings [u0, u1, sill, spring, depth, round] (u along the
## face): `round` heads them with a semicircle over `spring`; `depth` > 0 adds reveals and a dark back panel that deep.
## Openings stacked in one column must share u0 and u1. `surround` (alpha > 0) frames each opening with a band of it, 4cm
## proud. UVs in metres x MUV.
static func _wall_face(pk: PropKit, kit: Dictionary, key: String, o: Vector3, along: Vector3, out: Vector3, w: float, y0: float, y1: float,
		openings: Array, col: Color, surround := Color(0, 0, 0, 0)) -> void:
	var base := Vector3(o.x, 0.0, o.z)
	var uk: float = uvk * MUV
	var cuts: Array = [0.0, w]
	for op in openings:
		cuts.append(float(op[0]))
		cuts.append(float(op[1]))
	cuts.sort()
	var cs: Array = []
	for c in cuts:
		if cs.is_empty() or float(c) - float(cs[-1]) > 0.001:
			cs.append(c)
	for i in cs.size() - 1:
		var ua: float = cs[i]
		var ub: float = cs[i + 1]
		var um: float = (ua + ub) * 0.5
		var col_ops: Array = []
		for op in openings:
			if float(op[0]) <= um and um <= float(op[1]):
				col_ops.append(op)
		col_ops.sort_custom(func(a, b): return float(a[2]) < float(b[2]))
		var yc: float = y0
		for k in col_ops.size():
			var op: Array = col_ops[k]
			var sill: float = op[2]
			var spring: float = op[3]
			var rnd: bool = op[5]
			var r: float = (float(op[1]) - float(op[0])) * 0.5
			var ytop: float = float(col_ops[k + 1][2]) if k + 1 < col_ops.size() else y1
			_face_rect(pk, kit, key, base, along, out, ua, ub, yc, sill, col, uk)
			if rnd:
				var uc: float = (float(op[0]) + float(op[1])) * 0.5
				for side in [-1.0, 1.0]:
					var poly := PackedVector2Array()
					var ue: float = uc + side * r
					poly.append(Vector2(ue, spring))
					poly.append(Vector2(ue, ytop))
					poly.append(Vector2(uc, ytop))
					poly.append(Vector2(uc, spring + r))
					for s in range(1, 8):
						var th: float = PI * 0.5 - side * PI * 0.5 * float(s) / 8.0
						poly.append(Vector2(uc + cos(th) * r, spring + sin(th) * r))
					_face_poly(pk, kit, key, base, along, out, poly, col, uk)
			else:
				_face_rect(pk, kit, key, base, along, out, ua, ub, spring, ytop, col, uk)
			yc = ytop
		if col_ops.is_empty():
			_face_rect(pk, kit, key, base, along, out, ua, ub, y0, y1, col, uk)
	for op in openings:
		var u0: float = op[0]
		var u1: float = op[1]
		var sill: float = op[2]
		var spring: float = op[3]
		var d: float = op[4]
		var rnd: bool = op[5]
		var r: float = (u1 - u0) * 0.5
		var uc: float = (u0 + u1) * 0.5
		var arc: Array = []
		if rnd:
			for s in 17:
				var th: float = PI - PI * float(s) / 16.0
				arc.append(Vector2(uc + cos(th) * r, spring + sin(th) * r))
		if d > 0.0:
			var back := -out * d
			var p0 := base + along * u0
			var p1 := base + along * u1
			pk.quad(kit, key, [p0 + Vector3(0, sill, 0), p0 + Vector3(0, spring, 0), p0 + Vector3(0, spring, 0) + back, p0 + Vector3(0, sill, 0) + back], along, col.darkened(0.12))
			pk.quad(kit, key, [p1 + Vector3(0, sill, 0), p1 + Vector3(0, spring, 0), p1 + Vector3(0, spring, 0) + back, p1 + Vector3(0, sill, 0) + back], -along, col.darkened(0.12))
			pk.quad(kit, key, [p0 + Vector3(0, sill, 0), p1 + Vector3(0, sill, 0), p1 + Vector3(0, sill, 0) + back, p0 + Vector3(0, sill, 0) + back], Vector3.UP, col.lightened(0.05))
			var bpoly := PackedVector2Array([Vector2(u0, sill), Vector2(u1, sill)])
			if rnd:
				for s in arc.size() - 1:
					var a2: Vector2 = arc[s]
					var b2: Vector2 = arc[s + 1]
					var pa := base + along * a2.x + Vector3(0, a2.y, 0)
					var pb := base + along * b2.x + Vector3(0, b2.y, 0)
					var mid2: Vector2 = (a2 + b2) * 0.5
					var inward: Vector3 = (along * (uc - mid2.x) + Vector3(0, spring - mid2.y, 0)).normalized()
					pk.quad(kit, key, [pa, pb, pb + back, pa + back], inward, col.darkened(0.2))
				for s in range(arc.size() - 1, -1, -1):
					bpoly.append(arc[s])
			else:
				pk.quad(kit, key, [p0 + Vector3(0, spring, 0), p1 + Vector3(0, spring, 0), p1 + Vector3(0, spring, 0) + back, p0 + Vector3(0, spring, 0) + back], Vector3.DOWN, col.darkened(0.25))
				bpoly.append(Vector2(u1, spring))
				bpoly.append(Vector2(u0, spring))
			_face_poly(pk, kit, "matte", base + back, along, out, bpoly, Color(0.05, 0.055, 0.06), uk)
		if surround.a > 0.0:
			var sw := 0.28
			var pr := out * 0.04
			for side in [-1.0, 1.0]:
				var ue: float = uc + side * (r + sw * 0.5)
				_box(pk, kit, "ashlar", base + along * ue + Vector3(0, (sill + spring) * 0.5, 0) + pr * 0.5, Basis(along, Vector3.UP, out),
						Vector3(sw, spring - sill, 0.04 + 0.002), surround, MUV)
			_box(pk, kit, "ashlar", base + along * uc + Vector3(0, sill - 0.12, 0) + out * 0.06, Basis(along, Vector3.UP, out), Vector3(u1 - u0 + sw * 2.0 + 0.2, 0.24, 0.12), surround, MUV)
			if rnd:
				for s in 8:
					var t0: float = PI - PI * float(s) / 8.0
					var t1: float = PI - PI * float(s + 1) / 8.0
					var ri: float = r
					var ro: float = r + sw + (0.12 if s == 3 or s == 4 else 0.0)
					var q: Array = [Vector2(uc + cos(t0) * ri, spring + sin(t0) * ri), Vector2(uc + cos(t1) * ri, spring + sin(t1) * ri),
							Vector2(uc + cos(t1) * ro, spring + sin(t1) * ro), Vector2(uc + cos(t0) * ro, spring + sin(t0) * ro)]
					var p3: Array = []
					for v in q:
						p3.append(base + along * (v as Vector2).x + Vector3(0, (v as Vector2).y, 0) + pr)
					pk.quad(kit, "ashlar", p3, out, surround if s % 2 == 0 else surround.darkened(0.07))
					# The band's outer edge, back to the wall.
					pk.quad(kit, "ashlar", [p3[3], p3[2], (p3[2] as Vector3) - pr, (p3[3] as Vector3) - pr],
							(along * cos((t0 + t1) * 0.5) + Vector3(0, sin((t0 + t1) * 0.5), 0)).normalized(), surround.darkened(0.1))


static func _face_rect(pk: PropKit, kit: Dictionary, key: String, base: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v0: float, v1: float,
		col: Color, uk: float) -> void:
	if v1 - v0 < 0.001 or u1 - u0 < 0.001:
		return
	pk.quad(kit, key, [base + along * u0 + Vector3(0, v0, 0), base + along * u1 + Vector3(0, v0, 0), base + along * u1 + Vector3(0, v1, 0),
			base + along * u0 + Vector3(0, v1, 0)], out, col, [Vector2(u0, v0) * uk, Vector2(u1, v0) * uk, Vector2(u1, v1) * uk, Vector2(u0, v1) * uk])


static func _face_poly(pk: PropKit, kit: Dictionary, key: String, base: Vector3, along: Vector3, out: Vector3, poly: PackedVector2Array, col: Color, uk: float) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		var a: Vector2 = poly[tris[i]]
		var b: Vector2 = poly[tris[i + 1]]
		var c: Vector2 = poly[tris[i + 2]]
		pk.tri(kit, key, base + along * a.x + Vector3(0, a.y, 0), base + along * b.x + Vector3(0, b.y, 0), base + along * c.x + Vector3(0, c.y, 0),
				out, out, out, col, out, a * uk, b * uk, c * uk)


# ======================================================================================
#  1) Alte Rheinbrücke Kronburg (1912): GAME metres
# ======================================================================================

## The frame: local x = world x, local z = world z - 200, y the world height. The road (the generator's ribbon) covers
## |z| <= OB_ROAD at y = deck(x); the kerb barrier (granite kerb and a low steel guard) |z| OB_ROAD..OB_KERB, its top
## OB_KERB_H over the deck; the arch ribs and the tie girders |z| 8.35..9.45; the walkways |z| 9.45..12.85 at deck + 0.18,
## railing at |z| 12.8 (1.76 high); over the flood arches the walkway runs from the kerb to a stone parapet (|z| 12.85..13.5).
const OB_EAST := 202.0
const OB_WEST := -310.0
const OB_ROAD := 7.5
const OB_KERB := 8.3
const OB_KERB_H := 0.96
const OB_RIB_Z := 8.9
const OB_RIB_W := 1.0
const OB_TIE_TOP := 1.15
const OB_TIE_BOT := 1.9
const OB_TIE_W := 1.06
const OB_WALK_IN := 9.45
const OB_WALK_OUT := 12.85
const OB_WALK_UP := 0.18
const OB_RAIL_Z := 12.8
const OB_RAIL_H := 1.76
## The river piers' caps lie this far under the deck at their bearings (tie girder 1.9 + bearing 1.0).
const OB_CAP_DROP := 2.9
const OB_HEAD := 9.5
## Spans: [x of the first bearing, x of the last, rise of the ribs' lower chord over the tie chord, rib depth, panels
## (hangers + 1), chord depth]. Bearings sit 1.6 either side of the pier centres (+-110, +-200).
const OB_SPANS := [[198.4, 111.6, 17.0, 3.0, 8, 0.55], [108.4, -108.4, 36.0, 4.4, 20, 0.7], [-111.6, -198.4, 17.0, 3.0, 8, 0.55]]
const OB_SUB := 3
const OB_RIVER_PIERS := [110.0, -110.0]
## The gate towers: a pair at each end, centred on x, |z| 9.6..19.4 (the walkways pass through them).
const OB_TOWER_X := [200.0, -200.0]
const OB_TOWER_HX := 5.0
const OB_TOWER_Z0 := 9.6
const OB_TOWER_Z1 := 19.4
## The flood arches (Flutbrücke) between the west towers' west face and the west abutment.
const OB_FLOOD_X0 := -205.1
const OB_FLOOD_X1 := -306.0
const OB_FLOOD_N := 6
const OB_FLOOD_PIER := 3.4
const OB_FACE_Z := 13.2
const OB_LAMPS := [178.0, 150.0, 110.0, 55.0, -55.0, -110.0, -150.0, -178.0, -232.0, -268.0, -300.0]

## How far under the road the piers' and the abutment's feet stop at the most, wherever the ground stands that high.
const OB_FOOT_UNDER := 0.3
## A flood arch with less rise than this over the ground is buried in the dyke: filled with masonry instead.
const OB_FLOOD_MIN_RISE := 1.5

## The tie girder's middle under the deck.
const OB_TIE_MID := (OB_TIE_TOP - OB_TIE_BOT) * 0.5


## The Alte Rheinbrücke: three riveted steel tied arches over the river (east side span +200..+110, main span +110..-110,
## west side span -110..-200), masonry river piers at +-110, end piers at +-200 carrying a pair of gate towers each, and
## the masonry flood arches from -205 to the west abutment at -306..-312 (the deck ends at -310). See the constants above
## for every band; nothing stands over |z| <= 8.3 lower than deck + 9.5, nothing over the road (|z| <= 7.5) higher than
## deck - 0.06, and the kerb barrier (|z| 7.5..8.3) stays under deck + 1.0. `deck(x)` is the road surface's height,
## `ground(x)` the ground or river bed under the axis. Labels (game metres): the towers' plaques.
static func old_bridge(pk: PropKit, kit: Dictionary, labels: Array, deck: Callable, ground: Callable) -> void:
	for sp in OB_SPANS:
		_ob_span(pk, kit, deck, sp)
	_ob_kerbs(pk, kit, deck)
	_ob_walkways(pk, kit, deck)
	for xc in OB_RIVER_PIERS:
		_ob_river_pier(pk, kit, deck, ground, xc)
	_ob_end_piers(pk, kit, deck, ground)
	_ob_flood_arches(pk, kit, deck, ground)
	for xt in OB_TOWER_X:
		for sz in [-1.0, 1.0]:
			_ob_tower(pk, kit, labels, deck, ground, xt, sz)
	for x in OB_LAMPS:
		for sz in [-1.0, 1.0]:
			_ob_lamp(pk, kit, deck, x, sz)


## The clearance bands of the old bridge, for check_clearance(kit, deck, OB_BANDS, OB_WEST, OB_EAST).
const OB_BANDS := [[-OB_ROAD, OB_ROAD, -0.06], [OB_ROAD, OB_KERB, 1.0], [-OB_KERB, -OB_ROAD, 1.0]]


## The lower and upper chords' middle lines of one span's rib (z = 0) at its sub-panel nodes.
static func _ob_chords(deck: Callable, sp: Array) -> Array:
	var xa: float = sp[0]
	var xb: float = sp[1]
	var rise: float = sp[2]
	var dep: float = sp[3]
	var n: int = int(sp[4]) * OB_SUB
	var tya: float = float(deck.call(xa)) + OB_TIE_MID
	var tyb: float = float(deck.call(xb)) + OB_TIE_MID
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	for j in n + 1:
		var t: float = float(j) / float(n)
		var x: float = lerpf(xa, xb, t)
		var yl: float = lerpf(tya, tyb, t) + rise * 4.0 * t * (1.0 - t)
		lo.append(Vector3(x, yl, 0))
		hi.append(Vector3(x, yl + dep, 0))
	return [lo, hi]


static func _shift(pts: PackedVector3Array, d: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in pts:
		out.append(p + d)
	return out


static func _ob_span(pk: PropKit, kit: Dictionary, deck: Callable, sp: Array) -> void:
	var xa: float = sp[0]
	var xb: float = sp[1]
	var dep: float = sp[3]
	var panels: int = sp[4]
	var hc: float = sp[5]
	var n: int = panels * OB_SUB
	var dir: float = signf(xb - xa)
	var ch: Array = _ob_chords(deck, sp)
	var lo0: PackedVector3Array = ch[0]
	var hi0: PackedVector3Array = ch[1]
	var flo: Array = _path_frames(lo0, Vector3.BACK)
	var fhi: Array = _path_frames(hi0, Vector3.BACK)
	var ups_lo: Array = flo[2]
	var ups_hi: Array = fhi[2]
	var zb := Vector3.BACK
	for sz in [-1.0, 1.0]:
		var zc: float = sz * OB_RIB_Z
		var dz := Vector3(0, 0, zc)
		var lo := _shift(lo0, dz)
		var hi := _shift(hi0, dz)
		# The chords: box sections with riveted cover plates over and under them.
		_loft_box(pk, kit, "bsteel", lo, zb, OB_RIB_W, hc, OLD_STEEL, false)
		_loft_box(pk, kit, "bsteel", hi, zb, OB_RIB_W, hc, OLD_STEEL, true)
		for sg in [-1.0, 1.0]:
			_loft_box(pk, kit, "rivet", lo, zb, OB_RIB_W + 0.1, 0.05, OLD_STEEL, false, Vector2(0, sg * (hc * 0.5 + 0.03)))
			_loft_box(pk, kit, "rivet", hi, zb, OB_RIB_W + 0.1, 0.05, OLD_STEEL, true, Vector2(0, sg * (hc * 0.5 + 0.03)))
		# The lattice: in two planes 0.38 either side of the rib's middle, a vertical at every node and a diagonal in every
		# sub-panel (a Warren pattern with verticals), from inside one chord to inside the other.
		for pl in [-0.38, 0.38]:
			var off := Vector3(0, 0, pl)
			for j in range(1, n):
				var ul: Vector3 = ups_lo[j]
				var uu: Vector3 = ups_hi[j]
				var a: Vector3 = lo[j] + ul * (hc * 0.5 - 0.06) + off
				var b: Vector3 = hi[j] - uu * (hc * 0.5 - 0.06) + off
				_strut(pk, kit, "bsteel", a, b, 0.07, 0.42 if j % OB_SUB == 0 else 0.3, OLD_STEEL, zb)
			for j in n:
				var a2: Vector3
				var b2: Vector3
				if j % 2 == 0:
					a2 = lo[j] + (ups_lo[j] as Vector3) * (hc * 0.5 - 0.06)
					b2 = hi[j + 1] - (ups_hi[j + 1] as Vector3) * (hc * 0.5 - 0.06)
				else:
					a2 = hi[j] - (ups_hi[j] as Vector3) * (hc * 0.5 - 0.06)
					b2 = lo[j + 1] + (ups_lo[j + 1] as Vector3) * (hc * 0.5 - 0.06)
				# 1.5 or 3cm further out than the verticals (alternately), so where members meet no two faces share a plane.
				var ko: float = 1.04 if j % 2 == 0 else 1.08
				_strut(pk, kit, "bsteel", a2 + off * ko, b2 + off * ko, 0.07, 0.28, OLD_STEEL, zb)
		# Gusset plates on both faces of both chords at every hanger node.
		for j in range(OB_SUB, n, OB_SUB):
			for side in [-1.0, 1.0]:
				var pz := Vector3(0, 0, side * (OB_RIB_W * 0.5 + 0.03))
				for which in [0, 1]:
					var p: Vector3 = (lo[j] if which == 0 else hi[j])
					var up: Vector3 = (ups_lo[j] if which == 0 else -(ups_hi[j] as Vector3))
					var t: Vector3 = up.cross(zb).normalized()
					_box(pk, kit, "rivet", p + up * 0.42 + pz, Basis(t, up, zb), Vector3(1.7, hc + 0.85, 0.05), OLD_STEEL)
		# Hangers: a pair of flats from the lower chord down to the tie girder, a riveted shoe on the tie's faces.
		for j in range(OB_SUB, n, OB_SUB):
			var x: float = lo[j].x
			var ytie: float = float(deck.call(x)) + OB_TIE_TOP
			for hz in [-0.3, 0.3]:
				_strut(pk, kit, "bsteel", Vector3(x, lo[j].y - hc * 0.5 + 0.05, zc + hz), Vector3(x, ytie - 0.04, zc + hz), 0.06, 0.45, OLD_STEEL_DK, zb)
			for side in [-1.0, 1.0]:
				_blk(pk, kit, "rivet", Vector3(x - 0.55, ytie - 1.05, zc + side * (OB_TIE_W * 0.5)), Vector3(x + 0.55, ytie - 0.05, zc + side * (OB_TIE_W * 0.5 + 0.05)), OLD_STEEL)
			# A batten tying the flats together halfway up.
			var ym: float = (lo[j].y - hc * 0.5 + ytie) * 0.5
			_blk(pk, kit, "rivet", Vector3(x - 0.24, ym - 0.3, zc - 0.36), Vector3(x + 0.24, ym + 0.3, zc + 0.36), OLD_STEEL)
		# End posts: from the tie girder's top up through the upper chord's end, with a riveted plate on each face.
		for j in [0, n]:
			var x: float = hi[j].x
			var yt: float = float(deck.call(x)) + OB_TIE_TOP - 0.05
			_bar(pk, kit, "bsteel", Vector3(x, yt, zc), Vector3(x, hi[j].y + hc * 0.5, zc), 0.85, OB_RIB_W - 0.04, OLD_STEEL, Vector3.RIGHT)
			for side in [-1.0, 1.0]:
				_blk(pk, kit, "rivet", Vector3(x - 0.75, yt + 0.1, zc + side * (OB_RIB_W * 0.5 - 0.02)), Vector3(x + 0.75, yt + 1.7, zc + side * (OB_RIB_W * 0.5 + 0.03)), OLD_STEEL)
		# The tie girder (the deck's edge girder): a box section following the deck, cover plates, stiffeners on both faces.
		var txs: Array = [xa - dir * 0.6]
		for j in n + 1:
			txs.append(lo0[j].x)
		txs.append(xb + dir * 0.6)
		var tf: Array = _x_frames(txs, func(x: float) -> float: return float(deck.call(x)) + OB_TIE_MID, zc)
		var th: float = OB_TIE_TOP + OB_TIE_BOT
		_sweep(pk, kit, "bsteel", tf[0], tf[1], tf[2], _rect_prof(OB_TIE_W, th), OLD_STEEL, true, false, true)
		for sg in [-1.0, 1.0]:
			_sweep(pk, kit, "rivet", tf[0], tf[1], tf[2], _rect_prof(OB_TIE_W + 0.12, 0.05, 0.0, sg * (th * 0.5 + 0.03)), OLD_STEEL, true, false, true)
		for j in range(1, n):
			if j % OB_SUB == 0:
				continue
			var x: float = lo0[j].x
			var dk: float = deck.call(x)
			for side in [-1.0, 1.0]:
				_blk(pk, kit, "bsteel", Vector3(x - 0.12, dk - OB_TIE_BOT + 0.08, zc + side * (OB_TIE_W * 0.5 - 0.01)), Vector3(x + 0.12, dk + OB_TIE_TOP - 0.06, zc + side * (OB_TIE_W * 0.5 + 0.045)), OLD_STEEL)
	# The floor: cross girders at the hanger and end nodes, stringers between them, the deck plates' underside.
	var nodes: Array = []
	for j in range(0, n + 1, OB_SUB):
		nodes.append(lo0[j].x)
	for k in nodes.size():
		var x: float = nodes[k]
		var dk: float = deck.call(x)
		var zi: float = OB_RIB_Z - OB_TIE_W * 0.5
		if k == 0 or k == nodes.size() - 1:
			_blk(pk, kit, "bsteel", Vector3(x - 0.45, dk - OB_TIE_BOT + 0.05, -zi), Vector3(x + 0.45, dk - 0.51, zi), OLD_STEEL_DK)
		else:
			_ibeam(pk, kit, "bsteel", Vector3(x, dk - 1.21, -zi), Vector3(x, dk - 1.21, zi), 1.4, 0.5, OLD_STEEL_DK)
	for k in nodes.size() - 1:
		var x0: float = nodes[k]
		var x1: float = nodes[k + 1]
		var d0: float = deck.call(x0)
		var d1: float = deck.call(x1)
		for zs in [-6.0, -3.0, 0.0, 3.0, 6.0]:
			_bar(pk, kit, "bsteel", Vector3(x0, d0 - 0.91, zs), Vector3(x1, d1 - 0.91, zs), 0.32, 0.8, OLD_STEEL_DK, Vector3.BACK)
		var zi2: float = OB_RIB_Z - OB_TIE_W * 0.5
		pk.quad(kit, "bsteel", [Vector3(x0, d0 - 0.5, -zi2), Vector3(x1, d1 - 0.5, -zi2), Vector3(x1, d1 - 0.5, zi2), Vector3(x0, d0 - 0.5, zi2)], Vector3.DOWN, OLD_STEEL_DK.darkened(0.2))
	# Bearings under the tie girders' ends.
	for x in [xa, xb]:
		var xp: float = (x - dir * 1.6) if x == xa else (x + dir * 1.6)
		var cap: float = minf(float(deck.call(xp - 1.6)), float(deck.call(xp + 1.6))) - OB_CAP_DROP
		for sz in [-1.0, 1.0]:
			_ob_bearing(pk, kit, x, sz * OB_RIB_Z, cap, float(deck.call(x)) - OB_TIE_BOT)
	# Portals and wind bracing where the ribs stand high enough over the road.
	var jp := -1
	for j in range(OB_SUB, n / 2 + 1, OB_SUB):
		if lo0[j].y - hc * 0.5 >= float(deck.call(lo0[j].x)) + OB_HEAD + 0.25:
			jp = j
			break
	if jp < 0:
		return
	for j in [jp, n - jp]:
		_ob_portal(pk, kit, lo0[j], hi0[j], hc, -dir if j == jp else dir, n > 30)
	var braced: Array = []
	for j in range(jp, n - jp + 1, OB_SUB):
		braced.append(j)
	var zi3: float = OB_RIB_Z - OB_RIB_W * 0.5
	for k in braced.size():
		var j: int = braced[k]
		if k > 0 and k < braced.size() - 1:
			_bar(pk, kit, "bsteel", Vector3(lo0[j].x, lo0[j].y, -zi3), Vector3(lo0[j].x, lo0[j].y, zi3), 0.45, 0.5, OLD_STEEL, Vector3.RIGHT)
			_bar(pk, kit, "bsteel", Vector3(hi0[j].x, hi0[j].y, -zi3), Vector3(hi0[j].x, hi0[j].y, zi3), 0.45, 0.5, OLD_STEEL, Vector3.RIGHT)
		if k < braced.size() - 1:
			var j2: int = braced[k + 1]
			for ch2 in [lo0, hi0]:
				var p0: Vector3 = (ch2 as PackedVector3Array)[j]
				var p1: Vector3 = (ch2 as PackedVector3Array)[j2]
				_strut(pk, kit, "bsteel", Vector3(p0.x, p0.y, -zi3), Vector3(p1.x, p1.y, zi3), 0.32, 0.26, OLD_STEEL)
				_strut(pk, kit, "bsteel", Vector3(p0.x, p0.y + 0.02, zi3), Vector3(p1.x, p1.y + 0.02, -zi3), 0.32, 0.26, OLD_STEEL)
				# A riveted plate where the two diagonals cross.
				var mc: Vector3 = (p0 + p1) * 0.5
				_box(pk, kit, "rivet", mc + Vector3(0, 0.0, 0), Basis(), Vector3(1.0, 0.36, 1.0), OLD_STEEL)


## A cast-steel rocker bearing at (x, z) between the pier's cap (y0) and the tie girder's underside (y1): a plinth stone,
## the lower shoe, the rocker with its pin, the upper shoe.
static func _ob_bearing(pk: PropKit, kit: Dictionary, x: float, z: float, y0: float, y1: float) -> void:
	var h: float = y1 - y0
	_blk(pk, kit, "ashlar", Vector3(x - 1.2, y0 - 0.05, z - 1.1), Vector3(x + 1.2, y0 + 0.22, z + 1.1), GRANITE, MUV)
	_blk(pk, kit, "bsteel", Vector3(x - 0.9, y0 + 0.22, z - 0.8), Vector3(x + 0.9, y0 + 0.36, z + 0.8), CAST)
	var ym: float = y0 + 0.36 + (h - 0.36 - 0.14) * 0.5
	_blk(pk, kit, "bsteel", Vector3(x - 0.55, y0 + 0.36, z - 0.6), Vector3(x + 0.55, ym - 0.12, z + 0.6), CAST)
	pk.tube(kit, "bsteel", Vector3(x, ym, z - 0.72), Vector3(x, ym, z + 0.72), 0.24, 0.24, 10, CAST.lightened(0.1), true)
	_blk(pk, kit, "bsteel", Vector3(x - 0.5, ym + 0.12, z - 0.6), Vector3(x + 0.5, y1 - 0.14, z + 0.6), CAST)
	_blk(pk, kit, "bsteel", Vector3(x - 0.85, y1 - 0.14, z - 0.65), Vector3(x + 0.85, y1 + 0.01, z + 0.65), CAST)


## A portal frame between the ribs at a braced end node, in the vertical plane through it: a girder between the upper
## chords, an arched one under it springing from the lower chords (its lowest point at the ribs, as high as their
## underside), a lattice between, riveted plates at the knees and, on the main span, Kronburg's arms over the middle.
## `face` is the way its outer face looks (toward the span's end).
static func _ob_portal(pk: PropKit, kit: Dictionary, lo: Vector3, hi: Vector3, hc: float, face: float, main: bool) -> void:
	var x: float = lo.x
	var zi: float = OB_RIB_Z - OB_RIB_W * 0.5
	var yk: float = lo.y - hc * 0.5 + 0.33
	var crown: float = 1.7
	var r: float = (zi * zi + crown * crown) / (2.0 * crown)
	var cy: float = yk + crown - r
	var arc := PackedVector3Array()
	var a0: float = asin(zi / r)
	for i in 13:
		var a: float = lerpf(-a0, a0, float(i) / 12.0)
		arc.append(Vector3(x, cy + cos(a) * r, sin(a) * r))
	_loft_box(pk, kit, "bsteel", arc, Vector3.RIGHT, 0.62, 0.55, OLD_STEEL, true)
	_loft_box(pk, kit, "rivet", arc, Vector3.RIGHT, 0.72, 0.05, OLD_STEEL, true, Vector2(0, -0.3))
	_bar(pk, kit, "bsteel", Vector3(x, hi.y, -zi), Vector3(x, hi.y, zi), 0.62, hc, OLD_STEEL, Vector3.RIGHT)
	_bar(pk, kit, "rivet", Vector3(x, hi.y - hc * 0.5 - 0.03, -zi), Vector3(x, hi.y - hc * 0.5 - 0.03, zi), 0.72, 0.05, OLD_STEEL, Vector3.RIGHT)
	# The lattice: posts and diagonals between the arch and the top girder.
	var nb := 6
	var top_under: float = hi.y - hc * 0.5
	var prev_top := Vector3.ZERO
	var prev_bot := Vector3.ZERO
	for k in nb + 1:
		var z: float = lerpf(-zi, zi, float(k) / float(nb))
		var a: float = asin(clampf(z / r, -1.0, 1.0))
		var yb: float = cy + cos(a) * r + 0.25
		var pb := Vector3(x, yb, z)
		var pt := Vector3(x, top_under + 0.02, z)
		if k > 0 and k < nb:
			_strut(pk, kit, "bsteel", pb, pt, 0.36, 0.3, OLD_STEEL, Vector3.RIGHT)
		if k > 0:
			var from: Vector3 = prev_bot if k <= nb / 2 else prev_top
			var to: Vector3 = pt if k <= nb / 2 else pb
			# Alternate diagonals 1.5cm apart along x, so the two meeting at a post never share a plane.
			var dx := Vector3(0.015 * float(k % 2), 0, 0)
			_strut(pk, kit, "bsteel", from + dx, to + dx, 0.3, 0.24, OLD_STEEL, Vector3.RIGHT)
		prev_top = pt
		prev_bot = pb
	# Knee plates where the portal meets the ribs.
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "rivet", Vector3(x - 0.4, yk - 0.25, sz * zi - 0.9 * sz), Vector3(x + 0.4, hi.y + hc * 0.5 + 0.025, sz * (zi + 0.06)), OLD_STEEL)
	if main:
		var c := Vector3(x + face * 0.36, (yk + crown + top_under) * 0.5 + 0.1, 0.0)
		_box(pk, kit, "rivet", c - Vector3(face * 0.02, 0, 0), Basis(), Vector3(0.06, top_under - yk - crown - 0.25, 3.4), OLD_STEEL)
		var saved := _push(pk, Transform3D(Basis(Vector3(0, 0, -face), Vector3.UP, Vector3(face, 0, 0)), c + Vector3(face * 0.05, 0, 0)))
		_arms(pk, kit, 1.5)
		_pop(pk, saved)


## Kronburg's arms: a red heater shield with a gold crown, facing +z in the current frame, `s` metres tall, its back on z = 0.
static func _arms(pk: PropKit, kit: Dictionary, s: float) -> void:
	var sh := PackedVector2Array()
	var w: float = s * 0.42
	sh.append(Vector2(-w, s * 0.5))
	sh.append(Vector2(-w, s * 0.05))
	for i in range(1, 8):
		var t: float = float(i) / 8.0
		sh.append(Vector2(-w * cos(t * PI * 0.5), s * 0.05 - s * 0.55 * sin(t * PI * 0.5)))
	sh.append(Vector2(0, -s * 0.5))
	for i in range(7, 0, -1):
		var t: float = float(i) / 8.0
		sh.append(Vector2(w * cos(t * PI * 0.5), s * 0.05 - s * 0.55 * sin(t * PI * 0.5)))
	sh.append(Vector2(w, s * 0.05))
	sh.append(Vector2(w, s * 0.5))
	pk.extrude(kit, "paint", sh, 0.0, s * 0.06, s * 0.012, KR_RED)
	var cw: float = w * 0.62
	var crown := PackedVector2Array([Vector2(-cw, -s * 0.14), Vector2(cw, -s * 0.14), Vector2(cw, s * 0.12), Vector2(cw * 0.55, s * 0.0), Vector2(cw * 0.3, s * 0.2),
			Vector2(0, s * 0.04), Vector2(-cw * 0.3, s * 0.2), Vector2(-cw * 0.55, s * 0.0), Vector2(-cw, s * 0.12)])
	pk.extrude(kit, "gold", crown, s * 0.06, s * 0.085, 0.0, KR_GOLD)


## The kerb barrier the whole length (a granite kerb |z| 7.5..8.3 and a low steel guard on it, under deck + 1.0) and,
## on the steel spans, the deck plates' edge strip under it out to the walkways.
static func _ob_kerbs(pk: PropKit, kit: Dictionary, deck: Callable) -> void:
	var xs: Array = _stations(OB_EAST, OB_WEST, 3.6)
	var fr: Array = _x_frames(xs, deck)
	for sz in [-1.0, 1.0]:
		var zc: float = sz * (OB_ROAD + OB_KERB) * 0.5
		_sweep(pk, kit, "ashlar", fr[0], fr[1], fr[2], _rect_prof(OB_KERB - OB_ROAD, 0.6, zc, -0.05), GRANITE, true, false, true, MUV)
		for yy in [0.58, 0.9]:
			_sweep(pk, kit, "paint", fr[0], fr[1], fr[2], _rect_prof(0.07, 0.07, sz * 7.95, yy), CAST, true, false, true)
		for i in range(0, xs.size(), 2):
			var x: float = xs[i]
			var dk: float = deck.call(x)
			_blk(pk, kit, "paint", Vector3(x - 0.05, dk + 0.25, sz * 7.95 - 0.05), Vector3(x + 0.05, dk + 0.955, sz * 7.95 + 0.05), CAST)
	var sx: Array = _stations(196.0, -196.0, 7.2)
	var sf: Array = _x_frames(sx, deck)
	for sz in [-1.0, 1.0]:
		var p := PackedVector2Array([Vector2(OB_WALK_IN + 0.05, -0.1), Vector2(OB_KERB - 0.05, -0.1)])
		if sz < 0.0:
			p = _mirror_prof(p)
		_sweep(pk, kit, "bsteel", sf[0], sf[1], sf[2], p, OLD_STEEL_DK)


## The walkways on the steel spans (between the towers): cantilever brackets off the tie girders, the plates, a riveted
## fascia girder along the outside, the cast-iron railing on posts.
static func _ob_walkways(pk: PropKit, kit: Dictionary, deck: Callable) -> void:
	var x0: float = OB_TOWER_X[0] - OB_TOWER_HX - 0.1
	var x1: float = OB_TOWER_X[1] + OB_TOWER_HX + 0.1
	var xs: Array = _stations(x0, x1, 3.6)
	var fr: Array = _x_frames(xs, deck)
	var run := 0.0
	for sz in [-1.0, 1.0]:
		var top := PackedVector2Array([Vector2(OB_WALK_OUT, OB_WALK_UP), Vector2(OB_WALK_IN, OB_WALK_UP)])
		var bot := PackedVector2Array([Vector2(OB_WALK_IN, OB_WALK_UP - 0.32), Vector2(OB_WALK_OUT, OB_WALK_UP - 0.32)])
		if sz < 0.0:
			top = _mirror_prof(top)
			bot = _mirror_prof(bot)
		_sweep(pk, kit, "walk", fr[0], fr[1], fr[2], top, WALK)
		_sweep(pk, kit, "bsteel", fr[0], fr[1], fr[2], bot, OLD_STEEL_DK)
		_sweep(pk, kit, "rivet", fr[0], fr[1], fr[2], _rect_prof(0.2, 0.9, sz * (OB_WALK_OUT + 0.1), -0.15), OLD_STEEL, true, false, true)
		var br := PackedVector2Array([Vector2(OB_RIB_Z + OB_TIE_W * 0.5 - 0.02, -1.6), Vector2(OB_WALK_OUT - 0.02, -0.55), Vector2(OB_WALK_OUT - 0.02, OB_WALK_UP - 0.33),
				Vector2(OB_RIB_Z + OB_TIE_W * 0.5 - 0.02, OB_WALK_UP - 0.33)])
		run = 0.0
		for i in xs.size():
			var x: float = xs[i]
			var dk: float = deck.call(x)
			var ol := PackedVector2Array()
			for p in br:
				ol.append(Vector2(sz * p.x, dk + p.y))
			if sz < 0.0:
				ol.reverse()
			if i > 0 and i < xs.size() - 1:
				_ext_zy(pk, kit, "bsteel", ol, x - 0.11, x + 0.11, OLD_STEEL_DK)
			# The railing's posts (a ball on each) and its panels.
			var yb: float = dk + OB_WALK_UP
			var pz: float = sz * OB_RAIL_Z
			_blk(pk, kit, "paint", Vector3(x - 0.08, yb, pz - 0.08), Vector3(x + 0.08, yb + OB_RAIL_H + 0.06, pz + 0.08), CAST)
			_blk(pk, kit, "paint", Vector3(x - 0.12, yb + OB_RAIL_H + 0.06, pz - 0.12), Vector3(x + 0.12, yb + OB_RAIL_H + 0.16, pz + 0.12), CAST)
			if i < xs.size() - 1:
				var xn: float = xs[i + 1]
				var ybn: float = float(deck.call(xn)) + OB_WALK_UP
				var l: float = absf(xn - x)
				pk.quad(kit, "railing", [Vector3(x, yb, pz), Vector3(xn, ybn, pz), Vector3(xn, ybn + OB_RAIL_H, pz), Vector3(x, yb + OB_RAIL_H, pz)],
						Vector3(0, 0, sz), CAST, [Vector2(run, 0), Vector2(run + l, 0), Vector2(run + l, OB_RAIL_H), Vector2(run, OB_RAIL_H)])
				run += l


## A river pier: basalt-lava ashlar up to a string course over the high water, a pointed cutwater upstream (+z) and a
## round end downstream, both under sloping sandstone hoods, a battered sandstone shaft, a corbelled cornice and cap.
static func _ob_river_pier(pk: PropKit, kit: Dictionary, deck: Callable, ground: Callable, xc: float) -> void:
	var cap: float = minf(float(deck.call(xc - 1.6)), float(deck.call(xc + 1.6))) - OB_CAP_DROP
	var bed: float = ground.call(xc)
	const HZ := 13.6
	const NOSE := 7.5
	var yc: float = 6.3
	var yh: float = 9.4
	var plan0 := _pier_plan(4.45, HZ, NOSE)
	var plan1 := _pier_plan(4.05, HZ, NOSE)
	_prism(pk, kit, "ashlar", _pier_plan(5.4, HZ, NOSE + 1.0), bed - 3.0, _pier_plan(5.4, HZ, NOSE + 1.0), bed + 0.35, BASALT.darkened(0.15), true, xc)
	_prism(pk, kit, "ashlar", plan0, bed, plan1, yc, BASALT, false, xc)
	var course := _offset_ring(plan1, 0.25)
	_prism(pk, kit, "ashlar", course, yc, course, yc + 0.42, SANDSTONE, false, xc)
	_rings(pk, kit, "ashlar", [_lift(course, yc + 0.42, xc), _lift(plan1, yc + 0.42, xc)], SANDSTONE.lightened(0.05))
	_rings(pk, kit, "ashlar", [_lift(plan1, yc + 0.42, xc), _lift(_plan_clamped(plan1, HZ, 3.9 / 4.05), yh, xc)], SANDSTONE_DK)
	var body0 := _rrect(3.9, HZ, 0.35, 1)
	var body1 := _rrect(3.72, HZ - 0.1, 0.35, 1)
	_prism(pk, kit, "ashlar", body0, yc + 0.3, body1, cap - 1.0, SANDSTONE, false, xc)
	var corb := _offset_ring(body1, 0.32)
	_prism(pk, kit, "ashlar", corb, cap - 1.0, corb, cap - 0.62, SANDSTONE.lightened(0.04), false, xc)
	_rings(pk, kit, "ashlar", [_lift(body1, cap - 1.0, xc), _lift(corb, cap - 1.0, xc)], SANDSTONE_DK, 35.0, MUV, false)
	var capr := _offset_ring(body1, 0.58)
	_prism(pk, kit, "ashlar", capr, cap - 0.62, capr, cap, SANDSTONE.lightened(0.07), true, xc)
	_rings(pk, kit, "ashlar", [_lift(corb, cap - 0.62, xc), _lift(capr, cap - 0.62, xc)], SANDSTONE_DK, 35.0, MUV, false)


## The end piers at +-200 under the steel spans' outer ends: a bearing shelf for the tie girders and, behind it, a block
## up to the deck (the abutment on the east bank; the start of the flood arches on the west). The gate towers stand on
## their flanks.
static func _ob_end_piers(pk: PropKit, kit: Dictionary, deck: Callable, ground: Callable) -> void:
	for side in [1.0, -1.0]:
		var xp: float = 200.0 * side
		var g: float = minf(float(ground.call(xp - 4.0 * side)), float(ground.call(xp)))
		var cap: float = minf(float(deck.call(xp - 1.6 * side)), float(deck.call(xp + 1.6 * side))) - OB_CAP_DROP
		var xf: float = xp - 4.0 * side
		var xw: float = xp + 0.6 * side
		var xe: float = xp + (6.0 if side > 0.0 else 5.1) * side
		var hz: float = OB_TOWER_Z0 - 0.13
		# The shelf (river side) up to the cap, a cornice along its front: none where the bank stands as high as the cap
		# (the east head, on the town's quay terrace).
		if cap - 0.6 > g - 2.5 + 0.3:
			_blk(pk, kit, "ashlar", Vector3(xf, g - 2.5, -hz), Vector3(xw, cap - 0.6, hz), SANDSTONE, MUV)
			_blk(pk, kit, "ashlar", Vector3(xf - 0.45 * side, cap - 0.6, -hz), Vector3(xw, cap, hz), SANDSTONE.lightened(0.07), MUV)
		# The basalt plinth at the foot, kept under the road (OB_FOOT_UNDER): with the bank at the road's height it stood
		# 1.1m up across it at the east head.
		var plinth: float = minf(g + 1.2, minf(float(deck.call(xf)), float(deck.call(xw))) - OB_FOOT_UNDER)
		if plinth > g - 0.3:
			_blk(pk, kit, "ashlar", Vector3(xf - 0.25 * side, g - 0.6, -hz - 0.01), Vector3(xw - 0.5 * side, plinth, hz + 0.01), BASALT, MUV)
		# The ballast wall and the block behind, up to the road.
		var top: float = minf(float(deck.call(xw)), float(deck.call(xe))) - 0.08
		_blk(pk, kit, "ashlar", Vector3(xw - 0.3 * side, g - 2.5, -hz + 0.02), Vector3(xe, top, hz - 0.02), SANDSTONE, MUV)
		# The paving between the kerb and the towers, from the tie girders' ends over the block (the bearings are the spans').
		var xj: float = xp - 1.0 * side
		for sz in [-1.0, 1.0]:
			var ya: float = float(deck.call(xj)) + OB_WALK_UP
			var yb: float = float(deck.call(xe)) + OB_WALK_UP
			pk.quad(kit, "walk", [Vector3(xj, ya, sz * OB_KERB), Vector3(xe, yb, sz * OB_KERB), Vector3(xe, yb, sz * OB_TOWER_Z0), Vector3(xj, ya, sz * OB_TOWER_Z0)],
					Vector3.UP, WALK)
			var xs2: float = xe - 0.04 * side
			_blk(pk, kit, "ashlar", Vector3(minf(xj, xs2), minf(ya, yb) - 0.6, sz * OB_KERB - 0.01 * sz), Vector3(maxf(xj, xs2), minf(ya, yb) - 0.02, sz * OB_TOWER_Z0),
					SANDSTONE, MUV)


## The flood arches (Flutbrücke) from the west towers to the west abutment: segmental brick vaults between ashlar piers
## (pointed cutwaters upstream), brick spandrels with sandstone voussoirs and keystones, a cornice, a stone parapet, the
## walkway paving, and the abutment (x -312..-306) with a parapet pillar at the bridge's end.
static func _ob_flood_arches(pk: PropKit, kit: Dictionary, deck: Callable, ground: Callable) -> void:
	var total: float = absf(OB_FLOOD_X1 - OB_FLOOD_X0)
	var span: float = (total - float(OB_FLOOD_N - 1) * OB_FLOOD_PIER) / float(OB_FLOOD_N)
	var arches: Array = []
	for i in OB_FLOOD_N:
		var xe: float = OB_FLOOD_X0 - float(i) * (span + OB_FLOOD_PIER)
		var xw: float = xe - span
		var xm: float = (xe + xw) * 0.5
		var yc: float = float(deck.call(xm)) - 1.6
		var ys: float = maxf(float(ground.call(xm)) + 1.2, yc - 0.45 * span)
		var rise: float = yc - ys
		var r: float = (rise * rise + span * span * 0.25) / (2.0 * rise)
		arches.append([xe, xw, ys, yc, r])
	# Arches from the east while they rise clear of the ground; the rest (the dyke's foot at the west end) are one
	# masonry fill: with the ground over the crown, an arch turned upside down and stood up through the road.
	var n_open := 0
	for a in arches:
		if float(a[3]) - float(a[2]) < OB_FLOOD_MIN_RISE:
			break
		n_open += 1
	var x_fill: float = OB_FLOOD_X0 if n_open == 0 else float((arches[n_open - 1] as Array)[1])
	var K := 14
	# Each arch's intrados points, east springing to west springing.
	var arcs: Array = []
	for a in arches:
		var xe: float = a[0]
		var xw: float = a[1]
		var yc: float = a[3]
		var r: float = a[4]
		var xm: float = (xe + xw) * 0.5
		var al: float = asin(clampf((xe - xw) * 0.5 / r, -1.0, 1.0))
		var pts: Array = []
		for k in K + 1:
			var th: float = PI * 0.5 - al + 2.0 * al * float(k) / float(K)
			pts.append(Vector2(xm + cos(th) * r, yc - r + sin(th) * r))
		arcs.append(pts)
	var uk: float = uvk * MUV
	for sz in [-1.0, 1.0]:
		var zf: float = sz * OB_FACE_Z
		var out := Vector3(0, 0, sz)
		# The spandrel face: the top under the cornice, then back along the bottom over every intrados and pier foot.
		var poly := PackedVector2Array()
		for x in _stations(OB_FLOOD_X0, OB_FLOOD_X1, 6.0):
			poly.append(Vector2(float(x), float(deck.call(float(x))) - 0.55))
		# Along the ground under the filled stretch, from the abutment back to the last open arch.
		if n_open < OB_FLOOD_N:
			for x in _stations(OB_FLOOD_X1, x_fill, 4.0):
				poly.append(Vector2(float(x), minf(float(ground.call(float(x))) - 1.0, float(deck.call(float(x))) - 1.2)))
		for i in range(n_open - 1, -1, -1):
			var pts: Array = arcs[i]
			for k in range(K, -1, -1):
				poly.append(pts[k])
			if i > 0:
				var xpw: float = (arches[i - 1] as Array)[1]
				var xpe: float = (arches[i] as Array)[0]
				var gp: float = float(ground.call((xpw + xpe) * 0.5)) - 1.0
				poly.append(Vector2(xpe, gp))
				poly.append(Vector2(xpw, gp))
		var tris := Geometry2D.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			var a: Vector2 = poly[tris[t]]
			var b: Vector2 = poly[tris[t + 1]]
			var c: Vector2 = poly[tris[t + 2]]
			pk.tri(kit, "kbrick", Vector3(a.x, a.y, zf), Vector3(b.x, b.y, zf), Vector3(c.x, c.y, zf), out, out, out, BRICK, out,
					a * uk, b * uk, c * uk)
		# Voussoirs round each arch, 6cm proud, alternating in tone, and a keystone.
		for i in n_open:
			var a: Array = arches[i]
			var xm: float = (float(a[0]) + float(a[1])) * 0.5
			var cy: float = float(a[3]) - float(a[4])
			var r: float = a[4]
			var al: float = asin(clampf((float(a[0]) - float(a[1])) * 0.5 / r, -1.0, 1.0))
			var nv := 17
			for k in nv:
				var t0: float = PI * 0.5 - al + 2.0 * al * float(k) / float(nv)
				var t1: float = PI * 0.5 - al + 2.0 * al * float(k + 1) / float(nv)
				var key_stone: bool = k == nv / 2
				var ro: float = r + (1.35 if key_stone else 0.95 + 0.12 * float(k % 2))
				var pr: float = 0.12 if key_stone else 0.06
				var d0 := Vector2(cos(t0), sin(t0))
				var d1 := Vector2(cos(t1), sin(t1))
				var c0 := Vector2(xm, cy)
				var p: Array = [c0 + d0 * r, c0 + d1 * r, c0 + d1 * ro, c0 + d0 * ro]
				var p3: Array = []
				for v in p:
					p3.append(Vector3((v as Vector2).x, (v as Vector2).y, zf + sz * pr))
				var col: Color = SANDSTONE.lightened(0.04) if k % 2 == 0 else SANDSTONE_DK
				pk.quad(kit, "ashlar", p3, out, col, [(p[0] as Vector2) * uk, (p[1] as Vector2) * uk, (p[2] as Vector2) * uk, (p[3] as Vector2) * uk])
				var back := Vector3(0, 0, -sz * pr)
				var dm := Vector3((d0 + d1).x, (d0 + d1).y, 0).normalized()
				pk.quad(kit, "ashlar", [p3[2], p3[3], (p3[3] as Vector3) + back, (p3[2] as Vector3) + back], dm, col.darkened(0.1))
				pk.quad(kit, "ashlar", [p3[0], p3[1], (p3[1] as Vector3) + back, (p3[0] as Vector3) + back], -dm, col.darkened(0.2))
				if k == 0 or k == nv - 1:
					var ds: Vector2 = d0 if k == 0 else d1
					var e0: Vector3 = p3[0] if k == 0 else p3[1]
					var e1: Vector3 = p3[3] if k == 0 else p3[2]
					var tn := Vector3(-ds.y, ds.x, 0) * (-1.0 if k == 0 else 1.0)
					pk.quad(kit, "ashlar", [e0, e1, e1 + back, e0 + back], tn, col.darkened(0.1))
		# Piers: ashlar pilasters on the faces; upstream (+z) a pointed cutwater under a hood.
		for i in range(1, n_open):
			var xpw: float = (arches[i - 1] as Array)[1]
			var xpe: float = (arches[i] as Array)[0]
			var xc: float = (xpw + xpe) * 0.5
			var hw: float = (xpw - xpe) * 0.5
			var gp: float = float(ground.call(xc)) - 1.0
			var ys: float = minf(float((arches[i - 1] as Array)[2]), float((arches[i] as Array)[2]))
			var top: float = minf(float(deck.call(xpw)), float(deck.call(xpe))) - 0.55
			if sz > 0.0:
				var nose := PackedVector2Array([Vector2(hw, 0.0), Vector2(hw * 0.7, 1.4), Vector2(0.0, 2.6), Vector2(-hw * 0.7, 1.4), Vector2(-hw, 0.0)])
				var ring := PackedVector2Array()
				for p in nose:
					ring.append(Vector2(p.x, p.y + OB_FACE_Z - 0.05))
				ring.append(Vector2(-hw * 0.96, OB_FACE_Z - 0.6))
				ring.append(Vector2(hw * 0.96, OB_FACE_Z - 0.6))
				_prism(pk, kit, "ashlar", ring, gp, ring, ys + 0.6, SANDSTONE_DK, false, xc)
				var hood := PackedVector2Array()
				for p in ring:
					hood.append(Vector2(p.x * 0.92, minf(p.y, OB_FACE_Z + 0.08)))
				_rings(pk, kit, "ashlar", [_lift(ring, ys + 0.6, xc), _lift(hood, ys + 2.6, xc)], SANDSTONE)
				_blk(pk, kit, "ashlar", Vector3(xpe - 0.12, ys + 2.4, OB_FACE_Z - 0.05), Vector3(xpw + 0.12, top, OB_FACE_Z + 0.12), SANDSTONE, MUV)
			else:
				_blk(pk, kit, "ashlar", Vector3(xpe - 0.12, gp, -OB_FACE_Z - 0.12), Vector3(xpw + 0.12, top, -OB_FACE_Z + 0.05), SANDSTONE, MUV)
	# Under each arch: the vault (brick) and the piers' faces (ashlar) between the spandrels.
	for i in n_open:
		var pts: Array = arcs[i]
		var a: Array = arches[i]
		var xm: float = (float(a[0]) + float(a[1])) * 0.5
		var cy: float = float(a[3]) - float(a[4])
		var run := 0.0
		for k in K:
			var p0: Vector2 = pts[k]
			var p1: Vector2 = pts[k + 1]
			var l: float = p0.distance_to(p1)
			var n0 := Vector3(xm - p0.x, cy - p0.y, 0).normalized()
			var n1 := Vector3(xm - p1.x, cy - p1.y, 0).normalized()
			_qn(pk, kit, "kbrick", [Vector3(p0.x, p0.y, -OB_FACE_Z), Vector3(p1.x, p1.y, -OB_FACE_Z), Vector3(p1.x, p1.y, OB_FACE_Z), Vector3(p0.x, p0.y, OB_FACE_Z)],
					[n0, n1, n1, n0], BRICK.darkened(0.08), [Vector2(run, -OB_FACE_Z) * uk, Vector2(run + l, -OB_FACE_Z) * uk, Vector2(run + l, OB_FACE_Z) * uk,
					Vector2(run, OB_FACE_Z) * uk])
			run += l
		for e in [0, 1]:
			# The first arch's east face is the end pier's; the last open arch's west face the fill's or the abutment's.
			if (i == 0 and e == 0) or (i == n_open - 1 and e == 1):
				continue
			var x: float = a[e]
			var nx := Vector3(-1, 0, 0) if e == 0 else Vector3(1, 0, 0)
			var gx: float = float(ground.call(x)) - 1.0
			var ys: float = a[2]
			pk.quad(kit, "ashlar", [Vector3(x, gx, -OB_FACE_Z), Vector3(x, ys, -OB_FACE_Z), Vector3(x, ys, OB_FACE_Z), Vector3(x, gx, OB_FACE_Z)], nx, SANDSTONE_DK,
					[Vector2(-OB_FACE_Z, gx) * uk, Vector2(-OB_FACE_Z, ys) * uk, Vector2(OB_FACE_Z, ys) * uk, Vector2(OB_FACE_Z, gx) * uk])
	# The buried arches' fill, 5cm inside the spandrel faces.
	if n_open < OB_FLOOD_N:
		var gf: float = 1e9
		for x in _stations(OB_FLOOD_X1, x_fill, 4.0):
			gf = minf(gf, float(ground.call(float(x))))
		var tf: float = minf(float(deck.call(x_fill)), float(deck.call(OB_FLOOD_X1))) - 0.55
		_blk(pk, kit, "ashlar", Vector3(OB_FLOOD_X1, gf - 1.5, -OB_FACE_Z + 0.05), Vector3(x_fill, tf, OB_FACE_Z - 0.05), SANDSTONE_DK, MUV)
	# The west abutment; its basalt plinth kept under the road (it stood 0.7m up across it on the dyke).
	var xa0: float = OB_FLOOD_X1
	var xa1: float = OB_FLOOD_X1 - 6.0
	var ga: float = minf(float(ground.call(xa0)), float(ground.call(xa1))) - 1.5
	_blk(pk, kit, "ashlar", Vector3(xa1, ga, -OB_FACE_Z), Vector3(xa0, float(deck.call(xa0)) - 0.55, OB_FACE_Z), SANDSTONE, MUV)
	var pa: float = minf(float(ground.call(xa0)) + 0.8, minf(float(deck.call(xa0)), float(deck.call(xa1))) - OB_FOOT_UNDER)
	_blk(pk, kit, "ashlar", Vector3(xa1 - 0.3, ga, -OB_FACE_Z - 0.3), Vector3(xa0 + 0.3, pa, OB_FACE_Z + 0.3), BASALT, MUV)
	# Cornice, parapet and coping, the walkway paving, from the towers to the bridge's end.
	var xs: Array = _stations(OB_FLOOD_X0 + 0.05, OB_WEST, 4.0)
	var fr: Array = _x_frames(xs, deck)
	for sz in [-1.0, 1.0]:
		var cor := _rect_prof(0.5, 0.36, sz * (OB_FACE_Z + 0.15), -0.37)
		_sweep(pk, kit, "ashlar", fr[0], fr[1], fr[2], cor, SANDSTONE.lightened(0.05), true, false, true, MUV)
		_sweep(pk, kit, "ashlar", fr[0], fr[1], fr[2], _rect_prof(0.55, 2.0, sz * (OB_WALK_OUT + 0.275), 0.8), SANDSTONE, true, false, true, MUV)
		_sweep(pk, kit, "ashlar", fr[0], fr[1], fr[2], _rect_prof(0.8, 0.2, sz * (OB_WALK_OUT + 0.3), 1.9), SANDSTONE.lightened(0.08), true, false, true, MUV)
		var top := PackedVector2Array([Vector2(OB_WALK_OUT + 0.01, OB_WALK_UP), Vector2(OB_KERB - 0.01, OB_WALK_UP)])
		if sz < 0.0:
			top = _mirror_prof(top)
		_sweep(pk, kit, "walk", fr[0], fr[1], fr[2], top, WALK)
		# The parapet's end pillar at the bridge's end, a stone ball on it.
		var xe: float = OB_WEST + 0.6
		var ye: float = deck.call(xe)
		_blk(pk, kit, "ashlar", Vector3(xe - 0.75, ye - 0.3, sz * (OB_WALK_OUT + 0.275) - 0.75), Vector3(xe + 0.75, ye + 2.4, sz * (OB_WALK_OUT + 0.275) + 0.75),
				SANDSTONE.lightened(0.04), MUV)
		_blk(pk, kit, "ashlar", Vector3(xe - 0.9, ye + 2.4, sz * (OB_WALK_OUT + 0.275) - 0.9), Vector3(xe + 0.9, ye + 2.65, sz * (OB_WALK_OUT + 0.275) + 0.9),
				SANDSTONE.lightened(0.08), MUV)
		pk.lathe(kit, "ashlar", Vector3(xe, ye + 2.65, sz * (OB_WALK_OUT + 0.275)), [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.18, 0.15),
				Vector2(0.45, 0.45), Vector2(0.5, 0.65), Vector2(0.42, 0.88), Vector2(0.2, 1.0), Vector2(0.001, 1.03)], 10, SANDSTONE.lightened(0.05))


## A gate tower at x = xt on the side sz (|z| 9.6..19.4): a battered basalt plinth course, a sandstone base with the
## walkway's arched passage through it along x, a string course, a brick shaft with sandstone quoins and round-arched
## windows, a corbel table, an arcaded gallery, a cornice, four gables and a Rhenish rhombic helm in slate with a copper
## ball and a gilded crown. Plaques over the passage on both x faces: the north tower (sz < 0) "RHEINBRÜCKE KRONBURG",
## the south tower "1912"; Kronburg's arms on the face toward the road.
static func _ob_tower(pk: PropKit, kit: Dictionary, labels: Array, deck: Callable, ground: Callable, xt: float, sz: float) -> void:
	var hx: float = OB_TOWER_HX
	var zc: float = sz * (OB_TOWER_Z0 + OB_TOWER_Z1) * 0.5
	var hz: float = (OB_TOWER_Z1 - OB_TOWER_Z0) * 0.5
	var yb: float = float(deck.call(xt)) + OB_WALK_UP
	var g: float = minf(float(ground.call(xt - hx)), minf(float(ground.call(xt + hx)), float(ground.call(xt))))
	var foot: float = g - 1.5
	var p_top: float = yb + 5.5
	var g0: float = yb + 21.5
	var g1: float = yb + 25.6
	var he: float = g1 + 0.6
	var hs: float = he + 15.0
	var hg: float = (he + hs) * 0.5
	# The passage for the walkway along x.
	var pz0: float = minf(sz * (OB_WALK_IN + 0.3), sz * (OB_WALK_OUT))
	var pz1: float = maxf(sz * (OB_WALK_IN + 0.3), sz * (OB_WALK_OUT))
	# 1. Plinth course and base (faces 0.1 proud of the shaft).
	_blk(pk, kit, "ashlar", Vector3(xt - hx - 0.45, foot, zc - hz - 0.45), Vector3(xt + hx + 0.45, g + 1.0, zc + hz + 0.45), BASALT, MUV)
	var bx: float = hx + 0.1
	var bz: float = hz + 0.1
	var base_y0: float = g + 1.0
	var faces: Array = _tower_faces(xt, zc, bx, bz)
	for f in faces:
		var o: Vector3 = f[0]
		var along: Vector3 = f[1]
		var out: Vector3 = f[2]
		var w: float = f[3]
		var ops: Array = []
		if absf(out.x) > 0.5:
			var xf: float = xt + out.x * bx
			var sill: float = float(deck.call(xf)) + OB_WALK_UP
			var u0: float = _face_u(o, along, Vector3(xf, 0, pz0))
			var u1: float = _face_u(o, along, Vector3(xf, 0, pz1))
			ops.append([minf(u0, u1), maxf(u0, u1), sill, sill + 2.9, 0.0, true])
		elif out.z * sz > 0.0 and p_top - base_y0 > 4.0:
			for uu in [w * 0.3, w * 0.7]:
				ops.append([uu - 0.3, uu + 0.3, (base_y0 + p_top) * 0.5 - 0.9, (base_y0 + p_top) * 0.5 + 0.6, 0.45, true])
		_wall_face(pk, kit, "ashlar", o, along, out, w, base_y0, p_top, ops, SANDSTONE_DK)
	# The passage: its floor, side walls and barrel vault.
	var r: float = (pz1 - pz0) * 0.5
	var pzm: float = (pz0 + pz1) * 0.5
	var xa: float = xt - bx
	var xb: float = xt + bx
	var ya: float = float(deck.call(xa)) + OB_WALK_UP
	var yb2: float = float(deck.call(xb)) + OB_WALK_UP
	pk.quad(kit, "walk", [Vector3(xa, ya, pz0), Vector3(xb, yb2, pz0), Vector3(xb, yb2, pz1), Vector3(xa, ya, pz1)], Vector3.UP, WALK)
	pk.quad(kit, "ashlar", [Vector3(xa, ya, pz0), Vector3(xb, yb2, pz0), Vector3(xb, yb2 + 2.9, pz0), Vector3(xa, ya + 2.9, pz0)], Vector3.BACK, SANDSTONE_DK.darkened(0.15),
			[Vector2(xa, ya) * uvk * MUV, Vector2(xb, yb2) * uvk * MUV, Vector2(xb, yb2 + 2.9) * uvk * MUV, Vector2(xa, ya + 2.9) * uvk * MUV])
	pk.quad(kit, "ashlar", [Vector3(xa, ya, pz1), Vector3(xb, yb2, pz1), Vector3(xb, yb2 + 2.9, pz1), Vector3(xa, ya + 2.9, pz1)], Vector3.FORWARD, SANDSTONE_DK.darkened(0.15),
			[Vector2(xa, ya) * uvk * MUV, Vector2(xb, yb2) * uvk * MUV, Vector2(xb, yb2 + 2.9) * uvk * MUV, Vector2(xa, ya + 2.9) * uvk * MUV])
	var vault := PackedVector2Array()
	for k in 13:
		var th: float = PI - PI * float(k) / 12.0
		vault.append(Vector2(cos(th) * r, sin(th) * r))
	var vf: Array = _x_frames([xa, xb], func(x: float) -> float: return float(deck.call(x)) + OB_WALK_UP + 2.9, pzm)
	_sweep(pk, kit, "ashlar", vf[0], vf[1], vf[2], vault, SANDSTONE_DK.darkened(0.2), false, true, false, MUV)
	# A lamp in the passage's vault.
	pk.lathe(kit, "lamp", Vector3(xt, yb + 2.9 + r - 0.05, pzm), [Vector2(0.001, -0.35), Vector2(0.28, -0.3), Vector2(0.3, 0.0), Vector2(0.001, 0.0)], 8,
			Color(1.0, 0.9, 0.7))
	# 2. String course over the base.
	_blk(pk, kit, "ashlar", Vector3(xt - hx - 0.35, p_top, zc - hz - 0.35), Vector3(xt + hx + 0.35, p_top + 0.5, zc + hz + 0.35), SANDSTONE.lightened(0.06), MUV)
	# 3. The brick shaft with quoins and windows.
	var s0: float = p_top + 0.5
	var s1: float = g0 - 0.7
	for f in _tower_faces(xt, zc, hx, hz):
		var o: Vector3 = f[0]
		var along: Vector3 = f[1]
		var out: Vector3 = f[2]
		var w: float = f[3]
		var ops: Array = [[w * 0.5 - 0.75, w * 0.5 + 0.75, s0 + 3.2, s0 + 6.6, 0.55, true], [w * 0.5 - 0.75, w * 0.5 + 0.75, s0 + 10.0, s0 + 11.8, 0.55, true]]
		if out.z * sz < -0.5:
			ops = [[w * 0.5 - 0.75, w * 0.5 + 0.75, s0 + 10.0, s0 + 11.8, 0.55, true]]
		_wall_face(pk, kit, "kbrick", o, along, out, w, s0, s1, ops, BRICK, SANDSTONE)
	var y := s0
	var k := 0
	while y + 0.86 <= s1 + 0.01:
		for cx in [-1.0, 1.0]:
			for cz2 in [-1.0, 1.0]:
				var lx: float = 1.05 if k % 2 == 0 else 0.6
				var lz: float = 0.6 if k % 2 == 0 else 1.05
				var corner := Vector3(xt + cx * hx, 0, zc + cz2 * hz)
				_blk(pk, kit, "ashlar", Vector3(corner.x + cx * 0.05, y, corner.z + cz2 * 0.05), Vector3(corner.x - cx * lx, y + 0.84, corner.z - cz2 * lz), SANDSTONE, MUV)
		y += 0.9
		k += 1
	# Kronburg's arms on the face toward the road, between the windows.
	var fz: float = zc - sz * hz
	var saved := _push(pk, Transform3D(Basis(Vector3(-sz, 0, 0), Vector3.UP, Vector3(0, 0, -sz)), Vector3(xt, s0 + 8.3, fz - sz * 0.03)))
	_blk(pk, kit, "ashlar", Vector3(-1.25, -1.5, -0.1), Vector3(1.25, 1.5, 0.1), SANDSTONE.lightened(0.05), MUV)
	_push(pk, Transform3D(Basis(), Vector3(0, 0, 0.1)))
	_arms(pk, kit, 2.4)
	_pop(pk, saved)
	# 4. The corbel table: a projecting band on small corbels.
	_blk(pk, kit, "ashlar", Vector3(xt - hx - 0.3, g0 - 0.7, zc - hz - 0.3), Vector3(xt + hx + 0.3, g0, zc + hz + 0.3), SANDSTONE.lightened(0.04), MUV)
	for f in _tower_faces(xt, zc, hx, hz):
		var o: Vector3 = f[0]
		var along: Vector3 = f[1]
		var out: Vector3 = f[2]
		var w: float = f[3]
		var nc := 9
		for c in nc:
			var u: float = w * (float(c) + 0.5) / float(nc)
			var p: Vector3 = Vector3(o.x, 0, o.z) + along * u
			_box(pk, kit, "ashlar", p + out * 0.14 + Vector3(0, g0 - 0.95, 0), Basis(along, Vector3.UP, out), Vector3(0.36, 0.5, 0.3), SANDSTONE_DK, MUV)
	# 5. The gallery: three round arches a face, deep and dark.
	for f in _tower_faces(xt, zc, hx, hz):
		var o: Vector3 = f[0]
		var along: Vector3 = f[1]
		var out: Vector3 = f[2]
		var w: float = f[3]
		var ops: Array = []
		for c in [-1.0, 0.0, 1.0]:
			var u: float = w * 0.5 + c * 2.9
			ops.append([u - 0.85, u + 0.85, g0 + 0.55, g1 - 1.45, 1.1, true])
		_wall_face(pk, kit, "ashlar", o, along, out, w, g0, g1, ops, SANDSTONE)
	# 6. Cornice.
	_blk(pk, kit, "ashlar", Vector3(xt - hx - 0.45, g1, zc - hz - 0.45), Vector3(xt + hx + 0.45, he, zc + hz + 0.45), SANDSTONE.lightened(0.07), MUV)
	# 7. Gables, their copings and oculi; 8. the rhombic helm.
	var corners: Array = [Vector3(xt + hx, he, zc + hz), Vector3(xt - hx, he, zc + hz), Vector3(xt - hx, he, zc - hz), Vector3(xt + hx, he, zc - hz)]
	var apex := Vector3(xt, hs, zc)
	var mids: Array = []
	for i in 4:
		var c0: Vector3 = corners[i]
		var c1: Vector3 = corners[(i + 1) % 4]
		var m: Vector3 = (c0 + c1) * 0.5
		m.y = hg
		mids.append(m)
		var out := Vector3(m.x - xt, 0, m.z - zc).normalized()
		pk.tri(kit, "ashlar", c0, c1, m, out, out, out, SANDSTONE, out, Vector2(0, he) * uvk * MUV, Vector2(c0.distance_to(c1), he) * uvk * MUV,
				Vector2(c0.distance_to(c1) * 0.5, hg) * uvk * MUV)
		for ei in 2:
			var e: Vector3 = c0 if ei == 0 else c1
			var pr: float = 0.12 + 0.015 * float(ei)
			_bar(pk, kit, "ashlar", e + out * pr, m + out * pr + Vector3(0, 0.12, 0), 0.34, 0.36, SANDSTONE.lightened(0.05), out)
		var oc: Vector3 = Vector3(m.x, he + 2.6, m.z)
		pk.tube(kit, "ashlar", oc - out * 0.05, oc + out * 0.06, 1.0, 1.0, 14, SANDSTONE.lightened(0.06), true)
		pk.tube(kit, "matte", oc - out * 0.04, oc + out * 0.1, 0.72, 0.72, 14, Color(0.05, 0.055, 0.06), true)
	for i in 4:
		var c: Vector3 = corners[i]
		var ma: Vector3 = mids[(i + 3) % 4]
		var mb: Vector3 = mids[i]
		for tri in [[c, mb, apex], [c, apex, ma]]:
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var d: Vector3 = tri[2]
			var n := (d - a).cross(b - a).normalized()
			if n.dot(Vector3(a.x + b.x + d.x - 3.0 * xt, 0, a.z + b.z + d.z - 3.0 * zc)) < 0.0:
				n = -n
			var hd := Vector3(n.x, 0, n.z).normalized().cross(Vector3.UP)
			var up2 := n.cross(hd).normalized()
			pk.tri(kit, "kslate", a, b, d, n, n, n, SLATE, n, Vector2((a - c).dot(hd), (a - c).dot(up2)) * uvk,
					Vector2((b - c).dot(hd), (b - c).dot(up2)) * uvk, Vector2((d - c).dot(hd), (d - c).dot(up2)) * uvk)
	# Finial: a copper ball, a gilded crown on a rod.
	pk.lathe(kit, "copper", apex - Vector3(0, 0.6, 0), [Vector2(0.55, 0.0), Vector2(0.62, 0.3), Vector2(0.001, 0.62)], 8, VERDIGRIS)
	pk.lathe(kit, "copper", apex, [Vector2(0.001, -0.02), Vector2(0.35, 0.1), Vector2(0.48, 0.45), Vector2(0.35, 0.8), Vector2(0.001, 0.92)], 10, VERDIGRIS)
	pk.tube(kit, "gold", apex + Vector3(0, 0.9, 0), apex + Vector3(0, 2.6, 0), 0.05, 0.04, 6, KR_GOLD, true)
	pk.lathe(kit, "gold", apex + Vector3(0, 2.6, 0), [Vector2(0.001, 0.0), Vector2(0.32, 0.0), Vector2(0.34, 0.12), Vector2(0.3, 0.2), Vector2(0.001, 0.2)], 8, KR_GOLD)
	for kk in 5:
		var aa: float = TAU * float(kk) / 5.0
		var pp: Vector3 = apex + Vector3(cos(aa) * 0.28, 2.8, sin(aa) * 0.28)
		pk.tube(kit, "gold", pp, pp + Vector3(0, 0.32, 0), 0.05, 0.02, 5, KR_GOLD, true)
	# Plaques over the passage on both x faces.
	for sx in [-1.0, 1.0]:
		var xf: float = xt + sx * bx
		var cy: float = float(deck.call(xf)) + OB_WALK_UP + 4.9
		var n := Vector3(sx, 0, 0)
		var cz: float = zc
		_blk(pk, kit, "ashlar", Vector3(xf, cy - 0.4, cz - 4.55), Vector3(xf + sx * 0.12, cy + 0.4, cz + 4.55), SANDSTONE.lightened(0.1), MUV)
		_blk(pk, kit, "paint", Vector3(xf + sx * 0.12, cy - 0.3, cz - 4.4), Vector3(xf + sx * 0.15, cy + 0.3, cz + 4.4), BRONZE)
		var text: String = "RHEINBRÜCKE KRONBURG" if sz < 0.0 else "1912"
		var cap: float = 0.36 if sz < 0.0 else 0.48
		_label(labels, text, Vector3(xf + sx * 0.17, cy, cz), n, cap, KR_GOLD, 8.4)


## The four outer faces of a box tower [origin (left lower corner seen from outside, y 0), along, out, width].
static func _tower_faces(xt: float, zc: float, hx: float, hz: float) -> Array:
	return [
		[Vector3(xt + hx, 0, zc + hz), Vector3(0, 0, -1), Vector3(1, 0, 0), hz * 2.0],
		[Vector3(xt - hx, 0, zc - hz), Vector3(0, 0, 1), Vector3(-1, 0, 0), hz * 2.0],
		[Vector3(xt - hx, 0, zc + hz), Vector3(1, 0, 0), Vector3(0, 0, 1), hx * 2.0],
		[Vector3(xt + hx, 0, zc - hz), Vector3(-1, 0, 0), Vector3(0, 0, -1), hx * 2.0],
	]


static func _face_u(o: Vector3, along: Vector3, p: Vector3) -> float:
	return Vector3(p.x - o.x, 0, p.z - o.z).dot(along)


## A cast-iron candelabrum on the walkway (5.2m life x PS): a fluted foot, a shaft with collars, two scrolled arms along
## the walkway, each with a lantern, and a finial.
static func _ob_lamp(pk: PropKit, kit: Dictionary, deck: Callable, x: float, sz: float) -> void:
	var p := Vector3(x, float(deck.call(x)) + OB_WALK_UP, sz * 12.25)
	var saved := _push(pk, Transform3D(Basis.from_scale(Vector3.ONE * PS), p))
	_candelabrum(pk, kit)
	_pop(pk, saved)


## The candelabrum at life size on the origin (5.2m), its arms along x.
static func _candelabrum(pk: PropKit, kit: Dictionary) -> void:
	pk.lathe(kit, "steel", Vector3.ZERO, [Vector2(0.3, 0.0), Vector2(0.3, 0.1), Vector2(0.24, 0.16), Vector2(0.24, 0.45), Vector2(0.15, 0.62), Vector2(0.12, 0.9),
			Vector2(0.001, 0.9)], 8, CAST, true)
	pk.tube(kit, "steel", Vector3(0, 0.85, 0), Vector3(0, 4.45, 0), 0.085, 0.06, 8, CAST, false)
	for yy in [1.3, 1.38, 3.1]:
		pk.tube(kit, "steel", Vector3(0, yy, 0), Vector3(0, yy + 0.07, 0), 0.11, 0.11, 8, CAST, true)
	pk.lathe(kit, "steel", Vector3(0, 4.4, 0), [Vector2(0.001, 0.0), Vector2(0.07, 0.0), Vector2(0.15, 0.18), Vector2(0.16, 0.26), Vector2(0.001, 0.26)], 8, CAST, true)
	for sx in [-1.0, 1.0]:
		var a := Vector3(0, 4.55, 0)
		var b := Vector3(sx * 0.75, 4.75, 0)
		pk.beam(kit, "steel", a, b, 0.05, 0.06, CAST, Vector3.BACK)
		pk.beam(kit, "steel", Vector3(0, 4.1, 0), Vector3(sx * 0.55, 4.72, 0), 0.04, 0.04, CAST, Vector3.BACK)
		pk.tube(kit, "steel", Vector3(sx * 0.32, 4.33, -0.03), Vector3(sx * 0.32, 4.33, 0.03), 0.13, 0.13, 8, CAST, false)
		YardKit.lantern(pk, kit, b + Vector3(0, 0.02, 0), 0.75)
	pk.lathe(kit, "steel", Vector3(0, 4.66, 0), [Vector2(0.001, 0.0), Vector2(0.06, 0.0), Vector2(0.04, 0.4), Vector2(0.08, 0.5), Vector2(0.001, 0.62)], 8, CAST, true)


# ======================================================================================
#  2) A 47 Rheinbrücke: a 1970s single-pylon cable-stayed bridge (harp), GAME metres
# ======================================================================================

## The frame: local x = world x, local z = world z + 360 (the median's middle on z = 0), y the world height. Bands (z):
## carriageways (the generator's ribbons) HB_CW_IN..HB_CW_OUT either side at y = deck(x); the median |z| < HB_CW_IN (mine:
## a raised cap, step barriers |z| 4.6..5.5 1.1 high, the stays' anchor housings, lamp masts); the edge caps
## |z| HB_CW_OUT..HB_EDGE with a guardrail (top deck + 1.27) and a steel railing (top deck + 1.28) on them.
const HB_X0 := -345.0
const HB_X1 := 180.0
const HB_CW_IN := 5.5
const HB_CW_OUT := 20.5
const HB_EDGE := 22.5
const HB_PYLON_X := -150.0
## Auxiliary piers in the back span, over the floodplain.
const HB_AUX := [-215.0, -280.0]
## The steel box girder: its bottom flange |z| <= 8 at deck - 5, its webs leaning out to |z| 11.6 under the deck plate.
const HB_BOX_D := 5.0
const HB_BOX_BOT := 8.0
const HB_BOX_TOP := 11.6
const HB_CAP_Y := 0.12
## The stays: 8 a side, harp (parallel), anchored on the pylon from deck + 22 to deck + 66 and on the median.
const HB_STAYS := 8
const HB_STAY_H0 := 22.0
const HB_STAY_H1 := 66.0
const HB_STAY_SLOPE := 0.375
const HB_ANCHOR_Y := 0.6
const HB_PYLON_TOP := 70.0
## The edge railing's height over the cap (its handrail's top at deck + 1.28).
const HB_RAIL_H := 1.1
const HB_LAMP_STEP := 46.0

const HB_BANDS := [[HB_CW_IN, HB_CW_OUT, -0.06], [-HB_CW_OUT, -HB_CW_IN, -0.06]]


## The A 47's Rhine bridge from x -345 (over the dyke) to +180 (the east bank): a steel box girder 5m deep with
## cantilevers on struts, one concrete pylon in the median at x -150 on a pier in the river (70m over the deck), eight
## pairs of parallel locked-coil stays a side in the median's plane, auxiliary piers at -215 and -280, an abutment on
## the dyke and an end pier on the east bank. Nothing stands in the carriageways (|z| 5.5..20.5) above deck - 0.06 or
## over them under deck + 9.5. `ground(x)`: the ground or bed under the axis.
static func harp_bridge(pk: PropKit, kit: Dictionary, labels: Array, deck: Callable, ground: Callable) -> void:
	var xs: Array = _stations(HB_X0, HB_X1, 7.5)
	var fr: Array = _x_frames(xs, deck)
	_hb_girder(pk, kit, deck, xs, fr)
	_hb_median(pk, kit, deck, xs, fr)
	_hb_edges(pk, kit, deck, xs, fr)
	var stays: Array = hb_stays(deck)
	_hb_pylon(pk, kit, labels, deck, ground, stays)
	_hb_stays(pk, kit, deck, stays)
	_hb_lamps(pk, kit, deck, stays)
	for x in HB_AUX:
		var top: float = float(deck.call(x)) - HB_BOX_D - BEARING_H
		var saved := _push(pk, Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3(x, 0, 0)))
		viaduct_pier(pk, kit, top, float(ground.call(x)), 12.0, 0)
		_pop(pk, saved)
	# The east end pier: a wall across the girder on the bank, its crossbeam carrying the girder's end.
	var xe: float = HB_X1 - 1.6
	var ge: float = ground.call(xe)
	var te: float = float(deck.call(xe)) - HB_BOX_D - BEARING_H
	_blk(pk, kit, "concrete", Vector3(xe - 1.7, ge - 2.0, -9.0), Vector3(xe + 1.7, te - 2.2, 9.0), CONCRETE)
	_ext_zy(pk, kit, "concrete", PackedVector2Array([Vector2(-12.0, te - 1.2), Vector2(-9.0, te - 2.4), Vector2(9.0, te - 2.4), Vector2(12.0, te - 1.2),
			Vector2(12.0, te), Vector2(-12.0, te)]), xe - 2.0, xe + 2.0, CONCRETE, 0.05)
	for z in [-6.0, 6.0]:
		_hb_bearing(pk, kit, Vector3(xe, te, z))
	# The west abutment on the dyke: the road leaves along -x onto the embankment behind it.
	var xa: float = HB_X0 + 1.0
	var ta: float = float(deck.call(xa)) - HB_BOX_D - BEARING_H
	var saved2 := _push(pk, Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3(xa, 0, 0)))
	abutment(pk, kit, HB_EDGE + 0.5, ta, float(ground.call(xa)), 9.0, HB_BOX_D, 0, 6.0)
	_pop(pk, saved2)


## The stays' anchor points: [pylon anchor, deck anchor] pairs, main span first (toward +x), then the back span.
static func hb_stays(deck: Callable) -> Array:
	var out: Array = []
	var px: float = HB_PYLON_X
	var d0: float = deck.call(px)
	for dirx in [1.0, -1.0]:
		for i in HB_STAYS:
			var h: float = lerpf(HB_STAY_H0, HB_STAY_H1, float(i) / float(HB_STAYS - 1))
			var yp: float = d0 + h
			var hx: float = _hb_pylon_half(yp).x
			var x0: float = px + dirx * (hx + 0.35)
			# Bisect for where the stay meets the median's anchor level.
			var lo_d := 5.0
			var hi_d := 400.0
			for it in 40:
				var mid: float = (lo_d + hi_d) * 0.5
				var x: float = x0 + dirx * mid
				var ys: float = yp - HB_STAY_SLOPE * mid
				if ys > float(deck.call(clampf(x, HB_X0, HB_X1))) + HB_ANCHOR_Y:
					lo_d = mid
				else:
					hi_d = mid
			var dd: float = (lo_d + hi_d) * 0.5
			var xa: float = x0 + dirx * dd
			out.append([Vector3(x0, yp, 0), Vector3(xa, yp - HB_STAY_SLOPE * dd, 0)])
	return out


## The pylon's half sizes (x along the bridge, z across) at height y: from (3.2, 2.5) at the crossbeam's top to (2.1, 1.6)
## at its top.
static func _hb_pylon_half(y: float) -> Vector2:
	var y0: float = 16.1
	var y1: float = 91.6
	var t: float = clampf((y - y0) / (y1 - y0), 0.0, 1.0)
	return Vector2(lerpf(3.2, 2.1, t), lerpf(2.5, 1.6, t))


static func _hb_girder(pk: PropKit, kit: Dictionary, deck: Callable, xs: Array, fr: Array) -> void:
	# The box: webs and bottom flange; the cantilevers' deck plate underside.
	var box := PackedVector2Array([Vector2(-HB_BOX_TOP, -0.45), Vector2(-HB_BOX_BOT, -HB_BOX_D), Vector2(HB_BOX_BOT, -HB_BOX_D), Vector2(HB_BOX_TOP, -0.45)])
	_sweep(pk, kit, "msteel", fr[0], fr[1], fr[2], box, NEW_STEEL)
	for sz in [-1.0, 1.0]:
		var under := PackedVector2Array([Vector2(HB_BOX_TOP - 0.3, -0.36), Vector2(HB_EDGE, -0.36)])
		if sz < 0.0:
			under = _mirror_prof(under)
		_sweep(pk, kit, "msteel", fr[0], fr[1], fr[2], under, NEW_STEEL.darkened(0.1))
		# A drain pipe along under the cantilever.
		_sweep(pk, kit, "paint", fr[0], fr[1], fr[2], _circle_prof(0.22, 6, sz * 12.6, -0.9), Color(0.35, 0.36, 0.36), true, true)
		# Inspection rails under the cantilevers' tips.
		_sweep(pk, kit, "msteel", fr[0], fr[1], fr[2], _rect_prof(0.22, 0.3, sz * 21.4, -0.55), NEW_STEEL.darkened(0.25), true)
	# The box's end diaphragms.
	for end in [0, xs.size() - 1]:
		var x: float = xs[end]
		var dk: float = deck.call(x)
		var ol := PackedVector2Array()
		for p in box:
			ol.append(Vector2(p.x, dk + p.y))
		ol.reverse()
		_ext_zy(pk, kit, "msteel", ol, x - 0.05 if end == 0 else x - 0.3, x + 0.3 if end == 0 else x + 0.05, NEW_STEEL.darkened(0.15))
	# Cantilever ribs (tapered) every station, struts from the box's bottom corners to them every other one.
	for i in xs.size():
		var x: float = xs[i]
		var dk: float = deck.call(x)
		for sz in [-1.0, 1.0]:
			var rib := PackedVector2Array([Vector2(HB_BOX_TOP - 0.5, dk - 0.37), Vector2(HB_EDGE - 0.05, dk - 0.37), Vector2(HB_EDGE - 0.05, dk - 0.95),
					Vector2(HB_BOX_TOP - 0.5, dk - 1.9)])
			var ol := PackedVector2Array()
			for p in rib:
				ol.append(Vector2(sz * p.x, p.y))
			if i > 0 and i < xs.size() - 1:
				_ext_zy(pk, kit, "msteel", ol, x - 0.14, x + 0.14, NEW_STEEL.darkened(0.05))
			if i % 2 == 1 and i < xs.size() - 1:
				var a := Vector3(x, dk - HB_BOX_D + 0.35, sz * (HB_BOX_BOT + 0.22))
				var b := Vector3(x, dk - 1.25, sz * 18.0)
				_strut(pk, kit, "msteel", a, b, 0.5, 0.5, NEW_STEEL.darkened(0.05), Vector3.RIGHT)
	# The inspection gantry parked under the main span: a light truss across under the girder, hung from the rails.
	var gx: float = 135.0
	var gd: float = deck.call(gx)
	var gy: float = gd - HB_BOX_D - 0.9
	for sx in [-1.2, 1.2]:
		for sz in [-1.0, 1.0]:
			_strut(pk, kit, "galv", Vector3(gx + sx, gd - 0.62, sz * 21.4), Vector3(gx + sx, gy, sz * 21.4), 0.18, 0.18, SIGN_YELLOW.darkened(0.15))
		_loft_box(pk, kit, "galv", PackedVector3Array([Vector3(gx + sx, gy, -21.6), Vector3(gx + sx, gy, 21.6)]), Vector3.RIGHT, 0.22, 0.22, SIGN_YELLOW.darkened(0.15))
		_loft_box(pk, kit, "galv", PackedVector3Array([Vector3(gx + sx, gy + 1.1, -21.6), Vector3(gx + sx, gy + 1.1, 21.6)]), Vector3.RIGHT, 0.08, 0.08, SIGN_YELLOW)
	pk.quad(kit, "galv", [Vector3(gx - 1.25, gy + 0.12, -21.6), Vector3(gx + 1.25, gy + 0.12, -21.6), Vector3(gx + 1.25, gy + 0.12, 21.6),
			Vector3(gx - 1.25, gy + 0.12, 21.6)], Vector3.UP, GALV)
	pk.quad(kit, "galv", [Vector3(gx - 1.25, gy + 0.1, -21.6), Vector3(gx + 1.25, gy + 0.1, -21.6), Vector3(gx + 1.25, gy + 0.1, 21.6),
			Vector3(gx - 1.25, gy + 0.1, 21.6)], Vector3.DOWN, GALV.darkened(0.3))
	for k in 13:
		var z: float = lerpf(-21.6, 21.6, float(k) / 12.0)
		for sx in [-1.2, 1.2]:
			_strut(pk, kit, "galv", Vector3(gx + sx, gy, z), Vector3(gx + sx, gy + 1.1, z), 0.06, 0.06, SIGN_YELLOW.darkened(0.1))


## A circle (counter-clockwise) of radius r about (ca, cb).
static func _circle_prof(r: float, n: int, ca := 0.0, cb := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(Vector2(ca + cos(a) * r, cb + sin(a) * r))
	return out


## The median: a raised concrete cap, a step-profile concrete barrier facing each carriageway (|z| 4.6..5.5, 1.1 high).
static func _hb_median(pk: PropKit, kit: Dictionary, deck: Callable, xs: Array, fr: Array) -> void:
	var cap := PackedVector2Array([Vector2(HB_CW_IN, -0.06), Vector2(HB_CW_IN, HB_CAP_Y), Vector2(-HB_CW_IN, HB_CAP_Y), Vector2(-HB_CW_IN, -0.06)])
	_sweep(pk, kit, "concrete", fr[0], fr[1], fr[2], cap, CONCRETE.darkened(0.12))
	var bar := PackedVector2Array([Vector2(5.5, HB_CAP_Y), Vector2(5.5, HB_CAP_Y + 0.13), Vector2(5.3, 1.1), Vector2(4.88, 1.1), Vector2(4.6, HB_CAP_Y)])
	# The barriers, in elements of 6m with a joint between.
	var x := HB_X0
	while x < HB_X1 - 0.5:
		var x1: float = minf(x + 6.0, HB_X1)
		var sx: Array = [x + 0.01, (x + x1) * 0.5, x1 - 0.01]
		var f: Array = _x_frames(sx, deck)
		for sz in [-1.0, 1.0]:
			var p: PackedVector2Array = bar if sz > 0.0 else _mirror_prof(bar)
			var closed := PackedVector2Array(p)
			_sweep(pk, kit, "concrete", f[0], f[1], f[2], closed, CONCRETE.lightened(0.05), true, false, true)
		x = x1


## The edge caps (|z| 20.5..22.5) with the cornice beam outside, the guardrail and the railing on them.
static func _hb_edges(pk: PropKit, kit: Dictionary, deck: Callable, xs: Array, fr: Array) -> void:
	var ed := PackedVector2Array([Vector2(22.5, -0.36), Vector2(22.5, -1.15), Vector2(22.85, -1.15), Vector2(22.85, HB_CAP_Y + 0.12), Vector2(22.45, HB_CAP_Y + 0.12),
			Vector2(22.45, HB_CAP_Y), Vector2(HB_CW_OUT, HB_CAP_Y), Vector2(HB_CW_OUT, -0.06)])
	for sz in [-1.0, 1.0]:
		var p: PackedVector2Array = ed if sz > 0.0 else _mirror_prof(ed)
		_sweep(pk, kit, "concrete", fr[0], fr[1], fr[2], p, CONCRETE.lightened(0.03))
	# The guardrail (the A-profile beam at 1.55x life, its top at deck + 1.27) at |z| 20.95, its face toward the road, on
	# posts with base plates every 4m (game).
	var gs: Array = _stations(HB_X0 + 0.5, HB_X1 - 0.5, 6.4)
	var gf: Array = _x_frames(gs, deck)
	for sz in [-1.0, 1.0]:
		var prof := PackedVector2Array()
		for p in _guard_profile():
			prof.append(Vector2(sz * (20.95 - p.x * 1.55), HB_CAP_Y + p.y * 1.55))
		if sz > 0.0:
			prof.reverse()
		_sweep(pk, kit, "galv2", gf[0], gf[1], gf[2], prof, GALV)
		for xg in _stations(HB_X0 + 0.5, HB_X1 - 0.5, 4.0):
			var dg: float = float(deck.call(float(xg))) + HB_CAP_Y
			var zp: float = sz * (20.95 + 0.19 * 1.55)
			_blk(pk, kit, "galv", Vector3(float(xg) - 0.08, dg, zp - 0.1), Vector3(float(xg) + 0.08, dg + 0.96, zp + 0.1), GALV.darkened(0.1))
			_blk(pk, kit, "galv", Vector3(float(xg) - 0.06, dg + 0.78, sz * 20.97), Vector3(float(xg) + 0.06, dg + 1.05, zp), GALV.darkened(0.05))
			_blk(pk, kit, "galv", Vector3(float(xg) - 0.24, dg - 0.02, zp - 0.24), Vector3(float(xg) + 0.24, dg + 0.03, zp + 0.24), GALV.darkened(0.15))
	# The railing: square posts every 2.6m, bar panels between (the "barrail" quad).
	var rs: Array = _stations(HB_X0 + 0.3, HB_X1 - 0.3, 2.6)
	for sz in [-1.0, 1.0]:
		var pz: float = sz * 22.2
		var run := 0.0
		for i in rs.size():
			var x2: float = rs[i]
			var yb2: float = float(deck.call(x2)) + HB_CAP_Y
			_blk(pk, kit, "galv", Vector3(x2 - 0.05, yb2, pz - 0.05), Vector3(x2 + 0.05, yb2 + HB_RAIL_H, pz + 0.05), GALV)
			if i < rs.size() - 1:
				var xn: float = rs[i + 1]
				var ybn: float = float(deck.call(xn)) + HB_CAP_Y
				var l: float = absf(xn - x2)
				pk.quad(kit, "barrail", [Vector3(x2, yb2, pz), Vector3(xn, ybn, pz), Vector3(xn, ybn + HB_RAIL_H, pz), Vector3(x2, yb2 + HB_RAIL_H, pz)],
						Vector3(0, 0, sz), GALV, [Vector2(run, 0), Vector2(run + l, 0), Vector2(run + l, HB_RAIL_H), Vector2(run, HB_RAIL_H)])
				run += l
		# The handrail tube along the top.
		var f: Array = _x_frames(rs, func(xx: float) -> float: return float(deck.call(xx)) + HB_CAP_Y + HB_RAIL_H)
		_sweep(pk, kit, "galv", f[0], f[1], f[2], _circle_prof(0.06, 6, pz, 0.0), GALV, true, true)
	# Drain spouts through the cornice every 30m, dripping down.
	for xd in _stations(HB_X0 + 10.0, HB_X1 - 10.0, 30.0):
		var dk: float = deck.call(float(xd))
		for sz in [-1.0, 1.0]:
			pk.tube(kit, "paint", Vector3(float(xd), dk - 0.9, sz * 12.6), Vector3(float(xd), dk - 2.2, sz * 12.6), 0.12, 0.12, 6, Color(0.35, 0.36, 0.36), true)


## A pot bearing on its plinth, its top at `p` + BEARING_H (p on the cap's top).
static func _hb_bearing(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	_blk(pk, kit, "concrete", p + Vector3(-0.9, -0.02, -0.9), p + Vector3(0.9, 0.16, 0.9), CONCRETE.lightened(0.05))
	pk.tube(kit, "msteel", p + Vector3(0, 0.16, 0), p + Vector3(0, 0.3, 0), 0.6, 0.6, 12, NEW_STEEL.darkened(0.35), true)
	_blk(pk, kit, "msteel", p + Vector3(-0.7, 0.3, -0.7), p + Vector3(0.7, BEARING_H + 0.01, 0.7), NEW_STEEL.darkened(0.3))


## The pylon: a pier in the river (pointed upstream), the shaft below the deck, the crossbeam the girder rests on, the
## tapering concrete pylon through the median to deck + 70 with the stays' anchor blocks, a door, a cap, a red light.
static func _hb_pylon(pk: PropKit, kit: Dictionary, labels: Array, deck: Callable, ground: Callable, stays: Array) -> void:
	var px: float = HB_PYLON_X
	var bed: float = ground.call(px)
	var d0: float = deck.call(px)
	var plan := _pier_plan(7.0, 12.0, 9.0)
	_prism(pk, kit, "concrete", _pier_plan(8.0, 12.0, 10.0), bed - 3.0, _pier_plan(8.0, 12.0, 10.0), bed + 0.3, CONCRETE.darkened(0.25), true, px)
	_prism(pk, kit, "concrete", plan, bed, _pier_plan(6.6, 12.0, 9.0), 4.5, CONCRETE.darkened(0.08), true, px)
	var cb_top: float = d0 - HB_BOX_D - BEARING_H
	var cb_bot: float = cb_top - 3.0
	var low := _rrect(4.2, 3.2, 0.6, 2)
	var low1 := _rrect(3.6, 2.8, 0.6, 2)
	_prism(pk, kit, "concrete", low, 4.4, low1, cb_bot + 0.5, CONCRETE, false, px)
	_ext_zy(pk, kit, "concrete", PackedVector2Array([Vector2(-10.5, cb_top - 1.2), Vector2(-7.0, cb_bot), Vector2(7.0, cb_bot), Vector2(10.5, cb_top - 1.2),
			Vector2(10.5, cb_top), Vector2(-10.5, cb_top)]), px - 4.0, px + 4.0, CONCRETE, 0.06)
	for z in [-6.0, 6.0]:
		for sx in [-2.4, 2.4]:
			_hb_bearing(pk, kit, Vector3(px + sx, cb_top, z))
	# The pylon over the crossbeam: rings every 6m, chamfered corners.
	var rings: Array = []
	var top: float = d0 + HB_PYLON_TOP
	var ys: Array = _stations(cb_top - 0.5, top, 7.6)
	for y in ys:
		var h2: Vector2 = _hb_pylon_half(float(y))
		rings.append(_lift(_rrect(h2.x, h2.y, 0.5, 1), float(y), px))
	_rings(pk, kit, "concrete", rings, CONCRETE.lightened(0.04), 35.0, 1.0)
	var ht: Vector2 = _hb_pylon_half(top)
	var capr := _rrect(ht.x + 0.3, ht.y + 0.3, 0.6, 1)
	_prism(pk, kit, "concrete", capr, top, capr, top + 0.8, CONCRETE.lightened(0.08), true, px)
	_rings(pk, kit, "concrete", [_lift(_rrect(ht.x, ht.y, 0.5, 1), top, px), _lift(capr, top, px)], CONCRETE, 35.0, 1.0, false)
	pk.tube(kit, "galv", Vector3(px, top + 0.8, 0), Vector3(px, top + 3.5, 0), 0.06, 0.03, 6, GALV, true)
	pk.lathe(kit, "glow", Vector3(px + 0.8, top + 0.8, 0), [Vector2(0.001, 0.0), Vector2(0.25, 0.0), Vector2(0.25, 0.3), Vector2(0.001, 0.42)], 8, Color(1.0, 0.1, 0.05))
	# The stays' anchor blocks on the pylon's faces.
	for s in stays:
		var pa: Vector3 = s[0]
		var dirx: float = signf(pa.x - px)
		var hh: Vector2 = _hb_pylon_half(pa.y)
		_blk(pk, kit, "msteel", Vector3(px + dirx * (hh.x - 0.05), pa.y - 0.55, -1.0), Vector3(px + dirx * (hh.x + 0.4), pa.y + 0.55, 1.0), NEW_STEEL.darkened(0.3))
	# A door at the median's level and plaques with the bridge's name on both faces along the road.
	_blk(pk, kit, "msteel", Vector3(px - 1.0, d0 + HB_CAP_Y, -2.7), Vector3(px + 1.0, d0 + HB_CAP_Y + 3.3, -2.3), Color(0.25, 0.3, 0.33))
	for sx in [-1.0, 1.0]:
		var hh: Vector2 = _hb_pylon_half(d0 + 5.0)
		var fx: float = px + sx * hh.x
		_blk(pk, kit, "msteel", Vector3(fx - sx * 0.1, d0 + 4.3, -1.5), Vector3(fx + sx * 0.04, d0 + 5.7, 1.5), NEW_STEEL.darkened(0.45))
		_label(labels, "A 47  RHEINBRÜCKE  1974", Vector3(fx + sx * 0.06, d0 + 5.0, 0), Vector3(sx, 0, 0), 0.3, WHITE, 2.8)


## The stays: a pair of locked-coil ropes side by side per stay, clamped together every 20m, entering steel sleeves over
## anchor housings on the median.
static func _hb_stays(pk: PropKit, kit: Dictionary, deck: Callable, stays: Array) -> void:
	for s in stays:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var dirv: Vector3 = (b - a).normalized()
		for oz in [-0.34, 0.34]:
			pk.tube(kit, "cable", a + Vector3(0, 0, oz), b + Vector3(0, 0, oz) - dirv * 1.6, 0.17, 0.17, 6, CABLE, false)
		var l: float = a.distance_to(b)
		var n: int = int(l / 20.0)
		for k in range(1, n):
			var c: Vector3 = a + dirv * (l * float(k) / float(n))
			_box(pk, kit, "msteel", c, Basis(Vector3(0, 0, 1).cross(dirv).normalized(), dirv, Vector3(0, 0, 1)).orthonormalized(), Vector3(0.5, 0.45, 1.15),
					CABLE.darkened(0.2))
		# The anchor housing on the median, its top running 0.2 over the stay, and a steel collar where the stay goes in.
		var dk: float = deck.call(b.x)
		var sx: float = signf(dirv.x)
		var x_in: float = b.x - sx * 3.0
		var y_in: float = b.y + 3.0 * HB_STAY_SLOPE
		var ol := PackedVector2Array([Vector2(x_in, dk + HB_CAP_Y - 0.02), Vector2(b.x + sx * 1.2, dk + HB_CAP_Y - 0.02),
				Vector2(b.x + sx * 1.2, b.y - 1.2 * HB_STAY_SLOPE + 0.55), Vector2(x_in, y_in + 0.75)])
		_ext_xy(pk, kit, "concrete", ol, -1.3, 1.3, CONCRETE.lightened(0.02), 0.06)
		var t_in: float = (b.x - x_in) / dirv.x
		pk.tube(kit, "msteel", b - dirv * (t_in + 1.4), b - dirv * (t_in - 0.3), 0.62, 0.62, 10, NEW_STEEL.darkened(0.1), true)


## Lamp masts in the median: a tapered galvanised pole with two arms over the carriageways (heads at deck + 17), kept
## clear of the anchor housings and the pylon.
static func _hb_lamps(pk: PropKit, kit: Dictionary, deck: Callable, stays: Array) -> void:
	var x := HB_X0 + 20.0
	while x < HB_X1 - 10.0:
		var ok := absf(x - HB_PYLON_X) > 12.0
		for s in stays:
			if absf((s[1] as Vector3).x - x) < 6.0:
				ok = false
		if ok:
			var dk: float = deck.call(x)
			var p := Vector3(x, dk + HB_CAP_Y, 0)
			pk.lathe(kit, "concrete", p, [Vector2(0.001, -0.05), Vector2(0.55, -0.05), Vector2(0.55, 0.4), Vector2(0.001, 0.4)], 8, CONCRETE)
			pk.tube(kit, "galv", p + Vector3(0, 0.4, 0), p + Vector3(0, 15.6, 0), 0.24, 0.12, 8, GALV, true)
			for sz in [-1.0, 1.0]:
				var pts: Array = [p + Vector3(0, 15.0, 0), p + Vector3(0, 16.2, sz * 0.9), p + Vector3(0, 16.9, sz * 2.4), p + Vector3(0, 17.15, sz * 4.2)]
				for i in pts.size() - 1:
					pk.tube(kit, "galv", pts[i], pts[i + 1], 0.09, 0.08, 6, GALV, i == pts.size() - 2)
				var head: Vector3 = pts[pts.size() - 1] + Vector3(0, -0.08, sz * 0.7)
				_box(pk, kit, "galv", head, Basis(), Vector3(0.7, 0.28, 1.6), GALV.lightened(0.05))
				_box(pk, kit, "lens", head + Vector3(0, -0.15, 0), Basis(), Vector3(0.5, 0.04, 1.3), Color(0.9, 0.9, 0.85))
		x += HB_LAMP_STEP


# ======================================================================================
#  3) Piers and abutments for the generator's own elevated roads: GAME metres
# ======================================================================================

## A pier for an elevated road, in its own frame: x across the road, z along it, y up; centred on the origin's x and z.
## The cap's top is at `top_y` and spans x +-deck_half*0.7; two bearings on it at x +-deck_half*0.42 reach BEARING_H
## higher (the girder's underside goes there). The column starts under `foot_y` (the ground), its footing hidden 1-2.6m
## under it.
##   style 0: a modern Autobahn hammerhead pier: a rounded concrete column (x +-clamp(deck_half*0.18, 1.1, 2.6), z +-1.2)
##            under a cap 2.6m deep in the middle, 1.0 at its ends, pot bearings on plinths.
##   style 1: a sandstone and brick wall pier for the old bridge's side: battered brick between ashlar quoins on an ashlar
##            plinth, a corbelled ashlar cornice and cap (x +-deck_half*0.72, z +-1.7 at the top), cast-steel bearings.
static func viaduct_pier(pk: PropKit, kit: Dictionary, top_y: float, foot_y: float, deck_half: float, style: int) -> void:
	var l: float = deck_half * 0.7
	var bx: float = deck_half * 0.42
	if style == 0:
		var cx: float = clampf(deck_half * 0.18, 1.1, 2.6)
		var cz := 1.2
		_blk(pk, kit, "concrete", Vector3(-cx - 1.6, foot_y - 2.6, -cz - 1.6), Vector3(cx + 1.6, foot_y - 1.0, cz + 1.6), CONCRETE.darkened(0.15))
		var col := _rrect(cx, cz, 0.55, 3)
		_prism(pk, kit, "concrete", col, foot_y - 1.0, col, top_y - 2.0, CONCRETE, false, 0.0, 0.0, 35.0)
		var ol := PackedVector2Array([Vector2(-l, top_y - 1.0), Vector2(-cx - 0.35, top_y - 2.6), Vector2(cx + 0.35, top_y - 2.6), Vector2(l, top_y - 1.0),
				Vector2(l, top_y), Vector2(-l, top_y)])
		_ext_xy(pk, kit, "concrete", ol, -cz - 0.35, cz + 0.35, CONCRETE.lightened(0.03), 0.06, 1.0)
		for sx in [-1.0, 1.0]:
			_hb_bearing(pk, kit, Vector3(sx * bx, top_y, 0))
		# A drain down the column's side and a little pier number plate.
		pk.tube(kit, "paint", Vector3(cx + 0.12, top_y - 1.4, cz - 0.3), Vector3(cx + 0.12, foot_y + 0.2, cz - 0.3), 0.09, 0.09, 6, Color(0.3, 0.31, 0.31), true)
		_blk(pk, kit, "signface", Vector3(-0.3, foot_y + 2.2, cz - 0.0), Vector3(0.3, foot_y + 2.6, cz + 0.03), WHITE)
	else:
		var hx0: float = deck_half * 0.72 + 0.35
		var hz0 := 2.15
		var hx1: float = deck_half * 0.72
		var hz1 := 1.7
		var plinth: float = foot_y + 2.0
		_blk(pk, kit, "ashlar", Vector3(-hx0 - 0.5, foot_y - 2.0, -hz0 - 0.5), Vector3(hx0 + 0.5, plinth, hz0 + 0.5), SANDSTONE_DK, MUV)
		var b0 := _rrect(hx0, hz0, 0.25, 1)
		var b1 := _rrect(hx1, hz1, 0.25, 1)
		_prism(pk, kit, "kbrick", b0, plinth, b1, top_y - 1.0, BRICK, false, 0.0, 0.0, 35.0)
		# Quoins up the four corners, alternately long and short, following the batter.
		var y := plinth
		var k := 0
		while y + 0.85 <= top_y - 1.0:
			var t: float = (y - plinth) / maxf(top_y - 1.0 - plinth, 0.01)
			var hx: float = lerpf(hx0, hx1, t)
			var hz: float = lerpf(hz0, hz1, t)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var lx: float = 1.0 if k % 2 == 0 else 0.55
					var lz: float = 0.55 if k % 2 == 0 else 1.0
					_blk(pk, kit, "ashlar", Vector3(sx * (hx + 0.05), y, sz * (hz + 0.05)), Vector3(sx * (hx - lx), y + 0.8, sz * (hz - lz)), SANDSTONE, MUV)
			y += 0.85
			k += 1
		var corb := _offset_ring(b1, 0.3)
		_prism(pk, kit, "ashlar", corb, top_y - 1.0, corb, top_y - 0.6, SANDSTONE.lightened(0.04), false)
		_rings(pk, kit, "ashlar", [_lift(b1, top_y - 1.0), _lift(corb, top_y - 1.0)], SANDSTONE_DK, 35.0, MUV, false)
		var capr := _offset_ring(b1, 0.55)
		_prism(pk, kit, "ashlar", capr, top_y - 0.6, capr, top_y, SANDSTONE.lightened(0.07), true)
		_rings(pk, kit, "ashlar", [_lift(corb, top_y - 0.6), _lift(capr, top_y - 0.6)], SANDSTONE_DK, 35.0, MUV, false)
		for sx in [-1.0, 1.0]:
			_hb_bearing(pk, kit, Vector3(sx * bx, top_y, 0))


## An abutment (Widerlager), in its own frame: x across the road (+-half_width), y up, the front wall's face on z = 0 facing
## +z toward the span; the road leaves along -z onto the embankment behind. The bearing shelf at `top_y` runs from z = 0 back
## to -1.6 (bearings at x +-bearing_half, default half_width*0.42, their tops BEARING_H higher: the girder's underside); the
## ballast wall from z -1.6 to -2.4 rises to top_y + BEARING_H + deck_depth - 0.06 (6cm under the road); wing walls 0.9 thick
## at x = +-half_width (outside to +-(half_width + 0.9)) run back from z = 0 to z = -wing, level with the road for the first
## 2.4m and then falling 1:1.5 (1 down for 1.5 back) toward foot_y + 0.5; the front wall stands from 1.5m under `foot_y`
## (the ground). style 0 concrete, style 1 sandstone ashlar with a cornice.
static func abutment(pk: PropKit, kit: Dictionary, half_width: float, top_y: float, foot_y: float, wing: float, deck_depth := 2.4, style := 0,
		bearing_half := 0.0) -> void:
	var key: String = "concrete" if style == 0 else "ashlar"
	var col: Color = CONCRETE if style == 0 else SANDSTONE
	var uvs: float = 1.0 if style == 0 else MUV
	var road: float = top_y + BEARING_H + deck_depth - 0.06
	var hw: float = half_width
	var ww := 0.9
	var bot: float = foot_y - 1.5
	# Footing, front wall up to the shelf, ballast wall.
	_blk(pk, kit, key, Vector3(-hw - ww - 0.6, bot - 1.0, -wing - 0.5), Vector3(hw + ww + 0.6, bot, 0.8), col.darkened(0.15), uvs)
	_blk(pk, kit, key, Vector3(-hw, bot, -1.6), Vector3(hw, top_y, 0.0), col, uvs)
	_blk(pk, kit, key, Vector3(-hw, bot, -2.4), Vector3(hw, road, -1.6), col.darkened(0.05), uvs)
	if style == 1:
		_blk(pk, kit, key, Vector3(-hw, top_y - 0.45, 0.0), Vector3(hw, top_y, 0.35), col.lightened(0.06), uvs)
	# Wing walls: an outline in their own plane (z along, y up) extruded across x.
	for sx in [-1.0, 1.0]:
		var ol := PackedVector2Array()
		var drop_start := -2.4
		var low: float = foot_y + 0.5
		var z_low: float = drop_start - (road - low) * 1.5
		var z_end: float = maxf(-wing, z_low)
		var y_end: float = road - (drop_start - z_end) / 1.5
		ol.append(Vector2(0.0, bot))
		ol.append(Vector2(0.0, road + 0.25))
		ol.append(Vector2(drop_start, road + 0.25))
		ol.append(Vector2(z_end, y_end + 0.25))
		ol.append(Vector2(z_end, bot))
		var saved := _push(pk, Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3.ZERO))
		var x0: float = sx * hw
		var x1: float = sx * (hw + ww)
		pk.extrude(kit, key, ol, minf(x0, x1), maxf(x0, x1), 0.0, col, Callable(), uvk * uvs)
		_pop(pk, saved)
		# A coping along the wing's top.
		var cop := [Vector3(sx * (hw + ww * 0.5), road + 0.25, 0.1), Vector3(sx * (hw + ww * 0.5), road + 0.25, drop_start), Vector3(sx * (hw + ww * 0.5), y_end + 0.25, z_end)]
		for i in 2:
			_bar(pk, kit, key, (cop[i] as Vector3) + Vector3(0, 0.1, 0), (cop[i + 1] as Vector3) + Vector3(0, 0.1, 0), ww + 0.2, 0.2, col.lightened(0.08))
	var bh: float = bearing_half if bearing_half > 0.0 else hw * 0.42
	for sx in [-1.0, 1.0]:
		_hb_bearing(pk, kit, Vector3(sx * bh, top_y, -0.8))


# ======================================================================================
#  4) Autobahn furniture: LIFE size (the caller grows it by PROP_SCALE)
# ======================================================================================

## A German sign gantry (Schilderbrücke) over a carriageway, in its own frame: x across (its posts at +-half_span), y up
## from the road, z along the road; the signs face +z (traffic driving toward -z reads them). A box truss of tubes
## (chords at y clearance + 0.6 and + 2.6, z +-0.55) on two lattice posts on concrete footings (their tops 0.3 over y = 0,
## down to -1.4), a maintenance walkway with a railing behind the truss, a ladder on the +x post. Each sign
## [centre x, width, line, line, ...] hangs in front of the truss (its face at z +0.94) with its bottom edge at `clearance`:
## blue, a white border, white lettering (labels). Lines: "A 47" (or "A 47 Name"): the blue Autobahn number shield with a
## white border [and the name beside it]; "v", "vv", ...: that many lane arrows pointing down along the sign's foot; "/" an
## exit arrow up and right, "\\" up and left, "^" straight up; anything else is text. Returns the gantry's top height.
static func sign_gantry(pk: PropKit, kit: Dictionary, labels: Array, half_span: float, clearance: float, signs: Array) -> float:
	var y_lo: float = clearance + 0.6
	var y_hi: float = clearance + 2.6
	var hmax := 0.0
	for s in signs:
		hmax = maxf(hmax, _sign_height(s))
	y_hi = maxf(y_hi, clearance + hmax - 0.4)
	var zt := 0.55
	var x0: float = -half_span - 0.25
	var x1: float = half_span + 0.25
	# Footings and posts: two tubes a post (z +-0.55) laced together, a cap plate at the top.
	for sx in [-1.0, 1.0]:
		var px: float = sx * half_span
		_blk(pk, kit, "concrete", Vector3(px - 0.8, -1.4, -1.0), Vector3(px + 0.8, 0.3, 1.0), CONCRETE)
		for pz in [-zt, zt]:
			pk.tube(kit, "galv", Vector3(px, 0.25, pz), Vector3(px, y_hi + 0.15, pz), 0.14, 0.12, 8, GALV, true)
			_blk(pk, kit, "galv", Vector3(px - 0.3, 0.3, pz - 0.3), Vector3(px + 0.3, 0.34, pz + 0.3), GALV.darkened(0.1))
		var yy := 0.9
		var up := true
		while yy < y_hi - 0.4:
			var yn: float = minf(yy + 1.1, y_hi)
			_strut(pk, kit, "galv", Vector3(px + 0.012, yy, -zt if up else zt), Vector3(px + 0.012, yn, zt if up else -zt), 0.07, 0.07, GALV)
			_strut(pk, kit, "galv", Vector3(px, yy, -zt), Vector3(px, yy, zt), 0.07, 0.07, GALV)
			yy = yn
			up = not up
	# The truss: four chords and lacing on all four faces.
	for cy in [y_lo, y_hi]:
		for cz in [-zt, zt]:
			pk.tube(kit, "galv", Vector3(x0, cy, cz), Vector3(x1, cy, cz), 0.1, 0.1, 8, GALV, true)
	var nb: int = maxi(2, int(ceil((x1 - x0) / 1.25)))
	for i in nb + 1:
		var x: float = lerpf(x0, x1, float(i) / float(nb))
		for cz in [-zt, zt]:
			_strut(pk, kit, "galv", Vector3(x, y_lo, cz), Vector3(x, y_hi, cz), 0.06, 0.06, GALV)
		_strut(pk, kit, "galv", Vector3(x, y_hi, -zt), Vector3(x, y_hi, zt), 0.06, 0.06, GALV)
		_strut(pk, kit, "galv", Vector3(x, y_lo, -zt), Vector3(x, y_lo, zt), 0.06, 0.06, GALV)
		if i < nb:
			var xn: float = lerpf(x0, x1, float(i + 1) / float(nb))
			var flip: bool = i % 2 == 0
			for cz in [-zt, zt]:
				_strut(pk, kit, "galv", Vector3(x, y_lo if flip else y_hi, cz), Vector3(xn, y_hi if flip else y_lo, cz), 0.05, 0.05, GALV)
			_strut(pk, kit, "galv", Vector3(x, y_hi, -zt if flip else zt), Vector3(xn, y_hi, zt if flip else -zt), 0.05, 0.05, GALV)
	# The walkway behind (z -0.6..-1.4) on brackets, a grating and a railing.
	var wy: float = y_lo - 0.05
	_blk(pk, kit, "galv", Vector3(x0 + 0.3, wy - 0.06, -1.45), Vector3(x1 - 0.3, wy, -0.62), GALV.darkened(0.25))
	for i in range(0, nb + 1, 2):
		var x: float = lerpf(x0, x1, float(i) / float(nb))
		_strut(pk, kit, "galv", Vector3(x, wy - 0.06, -zt), Vector3(x, wy - 0.06, -1.45), 0.06, 0.08, GALV)
		pk.tube(kit, "galv", Vector3(x, wy, -1.42), Vector3(x, wy + 1.1, -1.42), 0.025, 0.025, 6, GALV, false)
	for ry in [0.55, 1.1]:
		pk.tube(kit, "galv", Vector3(x0 + 0.3, wy + ry, -1.42), Vector3(x1 - 0.3, wy + ry, -1.42), 0.025, 0.025, 6, GALV, true)
	# A ladder up the +x post.
	var lxp: float = half_span
	for sz in [-0.22, 0.22]:
		pk.tube(kit, "galv", Vector3(lxp + 0.35, 0.3, -zt - 0.35 + sz), Vector3(lxp + 0.35, wy + 1.0, -zt - 0.35 + sz), 0.025, 0.025, 6, GALV, true)
	var ly := 0.6
	while ly < wy:
		pk.tube(kit, "galv", Vector3(lxp + 0.35, ly, -zt - 0.57), Vector3(lxp + 0.35, ly, -zt - 0.13), 0.018, 0.018, 5, GALV, false)
		ly += 0.3
	# The signs.
	for s in signs:
		_gantry_sign(pk, kit, labels, s, clearance, y_lo, y_hi)
	return y_hi + 0.15


static func _sign_height(s: Array) -> float:
	var h := 0.45
	for i in range(2, s.size()):
		var line: String = s[i]
		if line.begins_with("v") and line.replace("v", "") == "":
			h += 0.85
		elif line == "/" or line == "\\" or line == "^":
			h += 1.0
		else:
			h += 0.72
	return h


## One sign of a gantry: [centre x, width, lines...], its bottom at `clearance`, hung from the truss on two Z-rails.
static func _gantry_sign(pk: PropKit, kit: Dictionary, labels: Array, s: Array, clearance: float, y_lo: float, y_hi: float) -> void:
	var cx: float = s[0]
	var w: float = s[1]
	var h: float = _sign_height(s)
	var zf := 0.9
	var y0: float = clearance
	var y1: float = clearance + h
	# Mounting rails from the sign's back up the truss's front.
	for rx in [cx - w * 0.3, cx + w * 0.3]:
		_blk(pk, kit, "galv", Vector3(rx - 0.05, minf(y0 + 0.2, y_lo), 0.62), Vector3(rx + 0.05, maxf(y1 - 0.2, y_hi), 0.86), GALV.darkened(0.1))
	_blk(pk, kit, "galv", Vector3(cx - w * 0.5, y0, zf - 0.04), Vector3(cx + w * 0.5, y1, zf), GALV.darkened(0.2))
	_blk(pk, kit, "signface", Vector3(cx - w * 0.5 + 0.005, y0 + 0.005, zf), Vector3(cx + w * 0.5 - 0.005, y1 - 0.005, zf + 0.025), WHITE)
	_blk(pk, kit, "signface", Vector3(cx - w * 0.5 + 0.06, y0 + 0.06, zf + 0.025), Vector3(cx + w * 0.5 - 0.06, y1 - 0.06, zf + 0.05), SIGN_BLUE)
	var front: float = zf + 0.05
	var y: float = y1 - 0.25
	for i in range(2, s.size()):
		var line: String = s[i]
		if line.begins_with("v") and line.replace("v", "") == "":
			var n: int = line.length()
			y -= 0.85
			for k in n:
				var ax: float = cx - w * 0.5 + w * (float(k) + 0.5) / float(n)
				_arrow(pk, kit, Vector3(ax, y + 0.42, front), Vector2(0, -1), 0.75)
		elif line == "/" or line == "\\" or line == "^":
			y -= 1.0
			var d := Vector2(0.7071, 0.7071) if line == "/" else (Vector2(-0.7071, 0.7071) if line == "\\" else Vector2(0, 1))
			var ax2: float = cx + (w * 0.5 - 0.7 if line == "/" else (-w * 0.5 + 0.7 if line == "\\" else 0.0))
			_arrow(pk, kit, Vector3(ax2, y + 0.5, front), d, 0.85)
		else:
			y -= 0.72
			var text: String = line
			var tx: float = cx
			var tw: float = w - 0.4
			if line.begins_with("A ") and line.length() >= 3 and line.substr(2, 1).is_valid_int():
				var parts: PackedStringArray = line.split(" ", false)
				var num: String = "A " + parts[1]
				var shx: float = cx - w * 0.5 + 0.75 if parts.size() > 2 else cx
				_shield(pk, kit, labels, Vector3(shx, y + 0.36, front), num)
				text = " ".join(parts.slice(2))
				tx = (shx + 0.6 + cx + w * 0.5) * 0.5
				tw = (cx + w * 0.5) - (shx + 0.6) - 0.2
			if text != "":
				_label(labels, text, Vector3(tx, y + 0.36, front + 0.015), Vector3.BACK, 0.34, WHITE, tw)


## A white arrow 2.5cm proud at `c` (on a sign facing +z) pointing along `d` (in the sign's x-y plane), `l` long.
static func _arrow(pk: PropKit, kit: Dictionary, c: Vector3, d: Vector2, l: float) -> void:
	var dn := d.normalized()
	var sd := Vector2(-dn.y, dn.x)
	var sw: float = l * 0.11
	var hw: float = l * 0.3
	var hl: float = l * 0.42
	var tail: Vector2 = -dn * l * 0.5
	var neck: Vector2 = dn * (l * 0.5 - hl)
	var tip: Vector2 = dn * l * 0.5
	var ol := PackedVector2Array([tail - sd * sw, neck - sd * sw, neck - sd * hw, tip, neck + sd * hw, neck + sd * sw, tail + sd * sw])
	var saved := _push(pk, Transform3D(Basis(), c))
	pk.extrude(kit, "signface", ol, 0.0, 0.025, 0.0, WHITE)
	_pop(pk, saved)


## The Autobahn number shield (Zeichen 405): blue with a white border, its top edge bowed up, at `c` on a face looking +z.
static func _shield(pk: PropKit, kit: Dictionary, labels: Array, c: Vector3, num: String) -> void:
	var saved := _push(pk, Transform3D(Basis(), c))
	for layer in [[0.0, 0.025, 1.0, WHITE], [0.025, 0.045, 0.86, SIGN_BLUE]]:
		var sc: float = layer[2]
		var ol := PackedVector2Array()
		var hw: float = 0.55 * sc
		var hh: float = 0.33 * sc
		ol.append(Vector2(-hw, -hh * 0.55))
		for i in 7:
			var t: float = float(i) / 6.0
			ol.append(Vector2(lerpf(-hw, hw, t), -hh - 0.05 * sc * sin(t * PI) + 0.0))
		ol.append(Vector2(hw, -hh * 0.55))
		ol.append(Vector2(hw, hh * 0.8))
		for i in 7:
			var t: float = float(i) / 6.0
			ol.append(Vector2(lerpf(hw, -hw, t), hh * 0.8 + 0.16 * sc * sin(t * PI)))
		pk.extrude(kit, "signface", ol, float(layer[0]), float(layer[1]), 0.0, layer[3])
	_label(labels, num, Vector3(0, 0.03, 0.065), Vector3.BACK, 0.3, WHITE, 0.95)
	_pop(pk, saved)


## The exit sign at an exit's start (Zeichen 333): a blue "Ausfahrt" panel with an arrow up and right (and `text` under it
## if given) on two posts, the exit's number in a white-framed box over its left end. Frame: the foot between the posts
## on y = 0, facing +z; the panel 3.2m wide, its bottom 2.0m up.
static func exit_sign(pk: PropKit, kit: Dictionary, labels: Array, number, text: String) -> void:
	var w := 3.2
	var h: float = 1.4 + (0.62 if text != "" else 0.0)
	var y0 := 2.0
	for px in [-1.1, 1.1]:
		_blk(pk, kit, "concrete", Vector3(px - 0.3, -0.9, -0.3), Vector3(px + 0.3, 0.12, 0.3), CONCRETE)
		pk.tube(kit, "galv", Vector3(px, 0.1, -0.06), Vector3(px, y0 + h + 0.55, -0.06), 0.057, 0.057, 8, GALV, true)
	_blk(pk, kit, "galv", Vector3(-w * 0.5, y0, 0.0), Vector3(w * 0.5, y0 + h, 0.03), GALV.darkened(0.2))
	_blk(pk, kit, "signface", Vector3(-w * 0.5 + 0.005, y0 + 0.005, 0.03), Vector3(w * 0.5 - 0.005, y0 + h - 0.005, 0.05), WHITE)
	_blk(pk, kit, "signface", Vector3(-w * 0.5 + 0.06, y0 + 0.06, 0.05), Vector3(w * 0.5 - 0.06, y0 + h - 0.06, 0.075), SIGN_BLUE)
	var front := 0.075
	_label(labels, "Ausfahrt", Vector3(-0.35, y0 + h - 0.48, front + 0.01), Vector3.BACK, 0.36, WHITE, 2.1)
	_arrow(pk, kit, Vector3(1.05, y0 + h - 0.6, front), Vector2(0.7071, 0.7071), 0.95)
	if text != "":
		_label(labels, text, Vector3(0, y0 + 0.36, front + 0.01), Vector3.BACK, 0.28, WHITE, w - 0.4)
	# The exit number: a blue box with a white frame on top of the panel's left end.
	var ny0: float = y0 + h + 0.05
	_blk(pk, kit, "signface", Vector3(-w * 0.5, ny0, 0.0), Vector3(-w * 0.5 + 0.9, ny0 + 0.55, 0.04), WHITE)
	_blk(pk, kit, "signface", Vector3(-w * 0.5 + 0.05, ny0 + 0.05, 0.04), Vector3(-w * 0.5 + 0.85, ny0 + 0.5, 0.065), SIGN_BLUE)
	_label(labels, str(number), Vector3(-w * 0.5 + 0.45, ny0 + 0.275, 0.075), Vector3.BACK, 0.3, WHITE, 0.7)


## The orange emergency telephone column (Notrufsäule) at the origin, its door toward +z, and beside it (x +0.9) the small
## white plate on a post with a black arrow and handset pointing to it.
static func notrufsaeule(pk: PropKit, kit: Dictionary) -> void:
	_blk(pk, kit, "concrete", Vector3(-0.32, -0.5, -0.28), Vector3(0.32, 0.08, 0.28), CONCRETE)
	var ol := PackedVector2Array([Vector2(-0.2, 0.08), Vector2(0.2, 0.08), Vector2(0.2, 1.18), Vector2(0.14, 1.28), Vector2(-0.14, 1.28), Vector2(-0.2, 1.18)])
	pk.extrude(kit, "paint", ol, -0.17, 0.17, 0.02, ORANGE)
	# The door, the speaker grille, the button and the handset recess, and a black hood band with the white pictogram.
	_blk(pk, kit, "paint", Vector3(-0.16, 0.25, 0.17), Vector3(0.16, 1.05, 0.19), ORANGE.darkened(0.08))
	_blk(pk, kit, "matte", Vector3(-0.1, 0.72, 0.19), Vector3(0.1, 0.92, 0.205), Color(0.1, 0.1, 0.1))
	pk.tube(kit, "plastic", Vector3(0, 0.6, 0.19), Vector3(0, 0.6, 0.215), 0.04, 0.04, 8, Color(0.1, 0.1, 0.1), true)
	_blk(pk, kit, "matte", Vector3(-0.205, 1.08, -0.175), Vector3(0.205, 1.2, 0.175), BLACK)
	_blk(pk, kit, "signface", Vector3(-0.07, 1.1, 0.175), Vector3(0.07, 1.18, 0.182), WHITE)
	pk.lathe(kit, "glow", Vector3(0, 1.28, 0), [Vector2(0.001, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.06), Vector2(0.001, 0.09)], 8, Color(1.0, 0.75, 0.2))
	# The arrow plate.
	pk.tube(kit, "galv", Vector3(0.9, -0.4, 0), Vector3(0.9, 1.0, 0), 0.03, 0.03, 6, GALV, true)
	_blk(pk, kit, "signface", Vector3(0.72, 0.72, 0.03), Vector3(1.08, 0.98, 0.045), WHITE)
	var saved := _push(pk, Transform3D(Basis(), Vector3(0.9, 0.85, 0.045)))
	var arr := PackedVector2Array([Vector2(0.12, -0.03), Vector2(-0.05, -0.03), Vector2(-0.05, -0.08), Vector2(-0.15, 0.0), Vector2(-0.05, 0.08), Vector2(-0.05, 0.03),
			Vector2(0.12, 0.03)])
	pk.extrude(kit, "signface", arr, 0.0, 0.01, 0.0, BLACK)
	_pop(pk, saved)


## A noise wall (Lärmschutzwand) along x from 0 to `length`, `height` tall, its road face toward +z: steel H-posts every 4m
## (flanges in the wall's plane at z +-0.11) on a concrete plinth, aluminium cassettes between them and, as `glass_share`
## of the bays (spread evenly), clear panels with bird-strike stripes in aluminium frames; a coping rail on top.
static func noise_wall(pk: PropKit, kit: Dictionary, length: float, height: float, glass_share: float) -> void:
	var nb: int = maxi(1, int(round(length / 4.0)))
	var bw: float = length / float(nb)
	var acc := 0.5
	var green := Color(0.36, 0.48, 0.40)
	for i in nb + 1:
		var x: float = bw * float(i)
		_blk(pk, kit, "concrete", Vector3(x - 0.35, -1.2, -0.35), Vector3(x + 0.35, 0.05, 0.35), CONCRETE.darkened(0.1))
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "galv", Vector3(x - 0.12, 0.0, sz * 0.105 - 0.01), Vector3(x + 0.12, height + 0.08, sz * 0.105 + 0.01), GALV.darkened(0.05))
		_blk(pk, kit, "galv", Vector3(x - 0.006, 0.0, -0.1), Vector3(x + 0.006, height + 0.08, 0.1), GALV.darkened(0.1))
		_blk(pk, kit, "galv", Vector3(x - 0.15, height + 0.08, -0.13), Vector3(x + 0.15, height + 0.1, 0.13), GALV.darkened(0.05))
	for i in nb:
		var xa: float = bw * float(i) + 0.08
		var xb: float = bw * float(i + 1) - 0.08
		# The plinth panel.
		_blk(pk, kit, "concrete", Vector3(xa, -0.3, -0.07), Vector3(xb, 0.5, 0.07), CONCRETE)
		acc += glass_share
		var glass: bool = acc >= 1.0
		if glass:
			acc -= 1.0
			for yy in [0.5, height - 0.06]:
				_blk(pk, kit, "galv", Vector3(xa, yy - 0.02, -0.05), Vector3(xb, yy + 0.06, 0.05), GALV)
			var y0 := 0.56
			var y1: float = height - 0.06
			pk.quad(kit, "glasswall", [Vector3(xa, y0, 0.0), Vector3(xb, y0, 0.0), Vector3(xb, y1, 0.0), Vector3(xa, y1, 0.0)], Vector3.BACK,
					Color(0.80, 0.88, 0.86, 0.18), [Vector2(xa, y0) * uvk, Vector2(xb, y0) * uvk, Vector2(xb, y1) * uvk, Vector2(xa, y1) * uvk])
		else:
			for sz in [-1.0, 1.0]:
				var zf: float = sz * 0.06
				pk.quad(kit, "cassette", [Vector3(xa, 0.5, zf), Vector3(xb, 0.5, zf), Vector3(xb, height, zf), Vector3(xa, height, zf)], Vector3(0, 0, sz),
						green if sz > 0.0 else green.darkened(0.1), [Vector2(0.5, xa) * uvk, Vector2(0.5, xb) * uvk, Vector2(height, xb) * uvk, Vector2(height, xa) * uvk])
			_blk(pk, kit, "galv", Vector3(xa, height - 0.04, -0.065), Vector3(xb, height + 0.02, 0.065), GALV.darkened(0.15))


## A double-sided concrete step barrier (Betonschutzwand, step profile, 0.81m) along x from 0 to `length`, centred on z = 0,
## its foot 0.6 wide on y = 0, in 6m elements with a joint between.
static func concrete_barrier(pk: PropKit, kit: Dictionary, length: float) -> void:
	var prof := PackedVector2Array([Vector2(-0.3, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.075), Vector2(0.12, 0.81), Vector2(-0.12, 0.81), Vector2(-0.3, 0.075)])
	var n: int = maxi(1, int(round(length / 6.0)))
	var el: float = length / float(n)
	for i in n:
		var xa: float = el * float(i) + 0.006
		var xb: float = el * float(i + 1) - 0.006
		var o := PackedVector3Array([Vector3(xa, 0, 0), Vector3(xb, 0, 0)])
		_sweep(pk, kit, "concrete", o, [Vector3(0, 0, 1), Vector3(0, 0, 1)], [Vector3.UP, Vector3.UP], prof, CONCRETE.lightened(0.04), true, false, true)


## The A-profile's section (z out toward the road, y up from its foot at 0.45m), bottom to top.
static func _guard_profile() -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, 0.45), Vector2(0.05, 0.48), Vector2(0.085, 0.525), Vector2(0.07, 0.57), Vector2(0.03, 0.605), Vector2(0.07, 0.64),
			Vector2(0.085, 0.685), Vector2(0.05, 0.73), Vector2(0.0, 0.76)])


## The German guardrail (Schutzplanke, A-profile) along x from 0 to `length`: a galvanised two-wave beam (0.31m tall, its
## face toward +z, z 0..0.09) at 0.45..0.76 m, on Sigma posts every `post_gap` behind it (z -0.13..-0.25) reaching
## `post_depth` into the ground, spacers between, and on `base_plates` (bridges) a base plate under each post.
static func guardrail(pk: PropKit, kit: Dictionary, length: float, post_depth := 0.9, base_plates := false, post_gap := 2.0) -> void:
	var w := _guard_profile()
	var yb := 0.0
	# Walked bottom to top, so its faces look toward +z (the material is two-sided).
	var prof := PackedVector2Array()
	for i in w.size():
		prof.append(Vector2(w[i].x, yb + w[i].y))
	var segs: int = maxi(1, int(ceil(length / 4.0)))
	for k in segs:
		var xa: float = length * float(k) / float(segs)
		var xb: float = length * float(k + 1) / float(segs)
		var o := PackedVector3Array([Vector3(xa, 0, 0), Vector3(xb, 0, 0)])
		_sweep(pk, kit, "galv2", o, [Vector3(0, 0, 1), Vector3(0, 0, 1)], [Vector3.UP, Vector3.UP], prof, GALV)
	var np: int = maxi(1, int(round(length / post_gap)))
	for i in np + 1:
		var x: float = length * float(i) / float(np)
		_blk(pk, kit, "galv", Vector3(x - 0.05, -post_depth, -0.25), Vector3(x + 0.05, 0.62, -0.13), GALV.darkened(0.1))
		_blk(pk, kit, "galv", Vector3(x - 0.07, -post_depth, -0.25), Vector3(x + 0.07, 0.6, -0.235), GALV.darkened(0.12))
		_blk(pk, kit, "galv", Vector3(x - 0.04, 0.5, -0.13), Vector3(x + 0.04, 0.68, -0.005), GALV.darkened(0.05))
		if base_plates:
			_blk(pk, kit, "galv", Vector3(x - 0.15, 0.0, -0.32), Vector3(x + 0.15, 0.025, -0.06), GALV.darkened(0.15))
	# The beam's end pieces (fishtails) turned back toward the posts.
	for e in [0.0, length]:
		var dx: float = -0.3 if e == 0.0 else 0.3
		_bar(pk, kit, "galv", Vector3(e, 0.605, 0.04), Vector3(e + dx, 0.605, -0.12), 0.31, 0.01, GALV, Vector3.UP)


## A race closure across a carriageway (Vollsperrung), centred on x = 0 (from -width/2 to width/2), facing +z: red and
## white barrier boards (two boards on feet, a yellow warning lamp on each) 0.3 apart, behind them at z -2.2 a big yellow
## arrow board on a stand with four lamps and a "VOLLSPERRUNG" panel, and at the +x end the closed-to-all-vehicles sign
## with a "RENNSTRECKE" plate.
static func race_closure(pk: PropKit, kit: Dictionary, labels: Array, width: float) -> void:
	var n: int = maxi(1, int(round(width / 2.1)))
	var el: float = width / float(n)
	for i in n:
		var xa: float = -width * 0.5 + el * float(i) + 0.05
		var xb: float = xa + el - 0.1
		for fx in [xa + 0.25, xb - 0.25]:
			_blk(pk, kit, "rubber", Vector3(fx - 0.3, 0.0, -0.22), Vector3(fx + 0.3, 0.07, 0.22), Color(0.08, 0.08, 0.08))
			pk.tube(kit, "galv", Vector3(fx, 0.07, 0), Vector3(fx, 1.02, 0), 0.025, 0.025, 6, GALV, true)
		for b in [[0.35, 0.6], [0.75, 1.0]]:
			var segs := 4
			for s in segs:
				var x0: float = lerpf(xa, xb, float(s) / float(segs))
				var x1: float = lerpf(xa, xb, float(s + 1) / float(segs))
				_blk(pk, kit, "signface", Vector3(x0, float(b[0]), 0.03), Vector3(x1, float(b[1]), 0.06), SIGN_RED if (s + i) % 2 == 0 else WHITE)
		pk.tube(kit, "glow", Vector3(xb - 0.25, 1.02, 0.045), Vector3(xb - 0.25, 1.2, 0.045), 0.08, 0.08, 8, SIGN_YELLOW, true)
	# The arrow board.
	var bz := -2.2
	for fx in [-1.2, 1.2]:
		_strut(pk, kit, "galv", Vector3(fx, 0.0, bz - 0.6), Vector3(fx, 1.3, bz), 0.06, 0.06, GALV)
		_strut(pk, kit, "galv", Vector3(fx, 0.0, bz + 0.6), Vector3(fx, 1.3, bz), 0.06, 0.06, GALV)
	_blk(pk, kit, "galv", Vector3(-1.6, 1.25, bz - 0.05), Vector3(1.6, 3.6, bz), GALV.darkened(0.2))
	_blk(pk, kit, "signface", Vector3(-1.55, 1.3, bz), Vector3(1.55, 3.55, bz + 0.03), SIGN_YELLOW)
	_blk(pk, kit, "signface", Vector3(-1.45, 3.0, bz + 0.03), Vector3(1.45, 3.45, bz + 0.05), WHITE)
	_label(labels, "VOLLSPERRUNG", Vector3(0, 3.22, bz + 0.06), Vector3.BACK, 0.2, BLACK, 2.7)
	var saved := _push(pk, Transform3D(Basis(), Vector3(0, 2.15, bz + 0.03)))
	var arr := PackedVector2Array([Vector2(0.9, -0.16), Vector2(-0.3, -0.16), Vector2(-0.3, -0.45), Vector2(-1.0, 0.0), Vector2(-0.3, 0.45), Vector2(-0.3, 0.16),
			Vector2(0.9, 0.16)])
	pk.extrude(kit, "signface", arr, 0.0, 0.025, 0.0, BLACK)
	_pop(pk, saved)
	for lx in [-1.35, 1.35]:
		for ly in [1.5, 2.8]:
			pk.tube(kit, "glow", Vector3(lx, ly, bz + 0.03), Vector3(lx, ly, bz + 0.1), 0.11, 0.11, 10, SIGN_YELLOW, true)
	# The sign: a white disc in a red ring (closed to all vehicles) and the plate.
	var sx: float = width * 0.5 + 0.6
	_blk(pk, kit, "concrete", Vector3(sx - 0.25, -0.6, -0.25), Vector3(sx + 0.25, 0.05, 0.25), CONCRETE)
	pk.tube(kit, "galv", Vector3(sx, 0.0, -0.05), Vector3(sx, 2.75, -0.05), 0.04, 0.04, 6, GALV, true)
	pk.tube(kit, "signface", Vector3(sx, 2.35, 0.0), Vector3(sx, 2.35, 0.02), 0.42, 0.42, 20, SIGN_RED, true)
	pk.tube(kit, "signface", Vector3(sx, 2.35, 0.02), Vector3(sx, 2.35, 0.045), 0.33, 0.33, 20, WHITE, true)
	_blk(pk, kit, "signface", Vector3(sx - 0.45, 1.55, 0.0), Vector3(sx + 0.45, 1.85, 0.02), BLACK)
	_blk(pk, kit, "signface", Vector3(sx - 0.43, 1.57, 0.02), Vector3(sx + 0.43, 1.83, 0.04), WHITE)
	_label(labels, "RENNSTRECKE", Vector3(sx, 1.7, 0.05), Vector3.BACK, 0.12, BLACK, 0.8)


## The small kilometre board (Kilometertafel) at the origin facing +z: a white plate in a black frame on a post, the
## kilometre with a decimal comma ("12,4").
static func kilometre_board(pk: PropKit, kit: Dictionary, labels: Array, km: float) -> void:
	pk.tube(kit, "galv", Vector3(0, -0.5, -0.04), Vector3(0, 1.75, -0.04), 0.03, 0.03, 6, GALV, true)
	_blk(pk, kit, "signface", Vector3(-0.3, 1.32, 0.0), Vector3(0.3, 1.7, 0.02), BLACK)
	_blk(pk, kit, "signface", Vector3(-0.27, 1.35, 0.02), Vector3(0.27, 1.67, 0.04), WHITE)
	var t: String = ("%.1f" % km).replace(".", ",")
	_label(labels, t, Vector3(0, 1.51, 0.05), Vector3.BACK, 0.17, BLACK, 0.5)


# ======================================================================================
#  5) Transmission towers and conductors: LIFE size
# ======================================================================================

## The tower's proportions by style: [base half width, waist half width (at the lowest arm), top half width,
## arms: [[height, half span, depth], ...] (fractions of h), insulator length, conductor x offsets per arm (fractions of h),
## earth-wire peak height, earth-wire arm half span].
static func _tower_spec(h: float, style: int) -> Dictionary:
	if style == 0:
		# The Donaumast: two crossarms, the lower one wider with two conductors a side, the upper one a side; one peak.
		return {"b0": 0.085 * h, "bw": 0.036 * h, "bt": 0.016 * h, "body_top": 0.93 * h,
				"arms": [[0.62 * h, 0.25 * h, 0.045 * h, [0.25 * h, 0.135 * h]], [0.80 * h, 0.15 * h, 0.04 * h, [0.15 * h]]],
				"ins": 0.09 * h, "peak": h, "ew": 0.0, "panels": 9, "bands": false}
	# A Rhine-crossing tower: much taller, three crossarm levels, the middle one widest (a barrel), an earth-wire bridge on
	# top with two peaks, red and white bands over its top third.
	return {"b0": 0.068 * h, "bw": 0.03 * h, "bt": 0.014 * h, "body_top": 0.95 * h,
			"arms": [[0.69 * h, 0.13 * h, 0.03 * h, [0.13 * h]], [0.79 * h, 0.165 * h, 0.032 * h, [0.165 * h]], [0.89 * h, 0.11 * h, 0.028 * h, [0.11 * h]]],
			"ins": 0.05 * h, "peak": h, "ew": 0.07 * h, "panels": 16, "bands": true}


## Where the conductors hang (the insulator strings' lower ends) in the tower's frame: the origin at the foot's middle on
## the ground, y up, the crossarms along x (the line runs along z). Lowest arm first, -x before +x.
static func conductor_points(h: float, style: int) -> Array:
	var sp: Dictionary = _tower_spec(h, style)
	var out: Array = []
	for arm in sp["arms"]:
		for xo in arm[3]:
			for sx in [-1.0, 1.0]:
				out.append(Vector3(sx * float(xo), float(arm[0]) - float(sp["ins"]), 0.0))
	return out


## The earth wires' clamps at the tower's top(s), in the same frame.
static func earthwire_points(h: float, style: int) -> Array:
	var sp: Dictionary = _tower_spec(h, style)
	if float(sp["ew"]) <= 0.0:
		return [Vector3(0, float(sp["peak"]), 0)]
	return [Vector3(-float(sp["ew"]), float(sp["peak"]), 0), Vector3(float(sp["ew"]), float(sp["peak"]), 0)]


## The body's half width at height y (piecewise linear: base to waist at the lowest arm, waist to top).
static func _tower_half(sp: Dictionary, y: float) -> float:
	var ya: float = (sp["arms"][0] as Array)[0]
	var yt: float = sp["body_top"]
	if y <= ya:
		return lerpf(float(sp["b0"]), float(sp["bw"]), y / ya)
	return lerpf(float(sp["bw"]), float(sp["bt"]), clampf((y - ya) / maxf(yt - ya, 0.01), 0.0, 1.0))


## A lattice transmission tower, h metres to its earth-wire peak: four legs of angle steel on concrete footings, X-braced
## panels (shorter as the body narrows), lattice crossarms, insulator strings of glass discs, the earth-wire peak(s);
## style 1 also red and white bands over the top third and red obstacle lights. Frame as conductor_points().
static func transmission_tower(pk: PropKit, kit: Dictionary, h: float, style: int) -> void:
	var sp: Dictionary = _tower_spec(h, style)
	var mw: float = maxf(0.12, h * 0.0032)
	var leg_w: float = mw * 1.9
	# Panel heights: a geometric run so panels stay about as tall as they are wide.
	var yt: float = sp["body_top"]
	var ys: Array = [0.0]
	var y := 0.0
	while y < yt - 0.5:
		var w: float = _tower_half(sp, y) * 2.0
		var step: float = clampf(w * 0.85, 1.6, h * 0.12)
		for arm in sp["arms"]:
			var ay: float = arm[0]
			var ad: float = arm[2]
			if y < ay - ad and y + step > ay - ad - 0.4:
				step = ay - ad - y
		y = minf(y + step, yt)
		ys.append(y)
	for arm in sp["arms"]:
		var ay: float = arm[0]
		if not ys.has(ay):
			ys.append(ay)
	ys.sort()
	# Footings.
	var b0: float = sp["b0"]
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_blk(pk, kit, "concrete", Vector3(cx * b0 - 0.7, -1.5, cz * b0 - 0.7), Vector3(cx * b0 + 0.7, 0.35, cz * b0 + 0.7), CONCRETE)
	var bands: bool = sp["bands"]
	for i in ys.size() - 1:
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		var h0: float = _tower_half(sp, y0)
		var h1: float = _tower_half(sp, y1)
		var key := "galv"
		var col := GALV
		if bands and y0 > h * 0.6:
			key = "paint"
			col = SIGN_RED if int((y0 - h * 0.6) / (h * 0.055)) % 2 == 0 else WHITE
		var c0: Array = [Vector3(h0, y0, h0), Vector3(-h0, y0, h0), Vector3(-h0, y0, -h0), Vector3(h0, y0, -h0)]
		var c1: Array = [Vector3(h1, y1, h1), Vector3(-h1, y1, h1), Vector3(-h1, y1, -h1), Vector3(h1, y1, -h1)]
		for k in 4:
			_strut(pk, kit, key, c0[k], c1[k], leg_w, leg_w, col)
			var a0: Vector3 = c0[k]
			var a1: Vector3 = c0[(k + 1) % 4]
			var e0: Vector3 = c1[k]
			var e1: Vector3 = c1[(k + 1) % 4]
			_strut(pk, kit, key, a0, e1, mw, mw, col)
			_strut(pk, kit, key, a1, e0, mw, mw, col)
			# Alternate faces' horizontals 1.2cm apart in height: at the corners they would share a plane.
			var dy := Vector3(0, 0.012 * float(k % 2), 0)
			_strut(pk, kit, key, e0 + dy, e1 + dy, mw, mw, col)
	# The peak above the body: a pyramid of four members up to the earth-wire clamp (or the earth-wire bridge's middle).
	var ht: float = _tower_half(sp, yt)
	var peak: float = sp["peak"]
	var ew: float = sp["ew"]
	if ew <= 0.0:
		for k in 4:
			var c := Vector3(ht * (1.0 if k == 0 or k == 3 else -1.0), yt, ht * (1.0 if k < 2 else -1.0))
			_strut(pk, kit, "galv", c, Vector3(0, peak - 0.3, 0), leg_w, leg_w, GALV)
		pk.tube(kit, "galv", Vector3(0, peak - 0.6, 0), Vector3(0, peak + 0.2, 0), mw, mw * 0.5, 6, GALV, true)
	else:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_strut(pk, kit, "paint", Vector3(sx * ht, yt, sz * ht), Vector3(sx * ew, peak, sz * mw * 1.5), leg_w, leg_w, WHITE if sx > 0.0 else SIGN_RED)
			_strut(pk, kit, "paint", Vector3(sx * ht, yt, -ht), Vector3(sx * ht, yt, ht), mw, mw, SIGN_RED)
		_strut(pk, kit, "paint", Vector3(-ew, peak, 0), Vector3(ew, peak, 0), leg_w, leg_w, SIGN_RED)
		for sx in [-1.0, 1.0]:
			pk.lathe(kit, "glow", Vector3(sx * ew, peak + 0.1, 0), [Vector2(0.001, 0.0), Vector2(0.22, 0.0), Vector2(0.22, 0.32), Vector2(0.001, 0.45)], 8,
					Color(1.0, 0.1, 0.05))
	# Crossarms: lattice girders, bottom chords level, top chords falling to the tip; insulators.
	var ins: float = sp["ins"]
	for arm in sp["arms"]:
		var ay: float = arm[0]
		var span: float = arm[1]
		var ad: float = arm[2]
		var hb: float = _tower_half(sp, ay)
		for sx in [-1.0, 1.0]:
			var key := "galv"
			var col := GALV
			if bands:
				key = "paint"
				col = WHITE
			var tip := Vector3(sx * span, ay, 0)
			var tw: float = maxf(0.25, hb * 0.18)
			var rb: Array = [Vector3(sx * hb, ay, hb), Vector3(sx * hb, ay, -hb)]
			var rt: Array = [Vector3(sx * hb, ay + ad * 2.2, hb), Vector3(sx * hb, ay + ad * 2.2, -hb)]
			var tb: Array = [tip + Vector3(0, 0, tw), tip + Vector3(0, 0, -tw)]
			var tt: Array = [tip + Vector3(0, ad * 0.6, tw), tip + Vector3(0, ad * 0.6, -tw)]
			for k in 2:
				_strut(pk, kit, key, rb[k], tb[k], leg_w * 0.9, leg_w * 0.9, col)
				_strut(pk, kit, key, rt[k], tt[k], leg_w * 0.8, leg_w * 0.8, col)
			var nseg: int = maxi(3, int(round((span - hb) / maxf(ad * 1.6, 1.0))))
			for s in nseg + 1:
				var t0: float = float(s) / float(nseg)
				var pb0: Vector3 = (rb[0] as Vector3).lerp(tb[0], t0)
				var pb1: Vector3 = (rb[1] as Vector3).lerp(tb[1], t0)
				var pt0: Vector3 = (rt[0] as Vector3).lerp(tt[0], t0)
				var pt1: Vector3 = (rt[1] as Vector3).lerp(tt[1], t0)
				if s > 0:
					# (At the root the body's own members stand there already.)
					_strut(pk, kit, key, pb0, pb1, mw, mw, col)
					_strut(pk, kit, key, pt0, pt1, mw, mw, col)
					_strut(pk, kit, key, pb0, pt0, mw, mw, col)
					_strut(pk, kit, key, pb1, pt1, mw, mw, col)
				if s < nseg:
					var t1: float = float(s + 1) / float(nseg)
					var nb0: Vector3 = (rb[0] as Vector3).lerp(tb[0], t1)
					var nb1: Vector3 = (rb[1] as Vector3).lerp(tb[1], t1)
					var nt0: Vector3 = (rt[0] as Vector3).lerp(tt[0], t1)
					var nt1: Vector3 = (rt[1] as Vector3).lerp(tt[1], t1)
					_strut(pk, kit, key, pb0, nt0, mw, mw, col)
					_strut(pk, kit, key, pb1, nt1, mw, mw, col)
					_strut(pk, kit, key, pb0, nb1, mw, mw, col)
			for xo in arm[3]:
				_insulator(pk, kit, Vector3(sx * float(xo), ay, 0), ins)
			if bands:
				pk.lathe(kit, "glow", tip + Vector3(0, ad * 0.6 + 0.05, 0), [Vector2(0.001, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.25), Vector2(0.001, 0.36)], 6,
						Color(1.0, 0.1, 0.05))
	if bands:
		for k in 4:
			var y2: float = h * 0.5
			var hh: float = _tower_half(sp, y2) + 0.2
			var c := Vector3(hh * (1.0 if k == 0 or k == 3 else -1.0), y2, hh * (1.0 if k < 2 else -1.0))
			pk.lathe(kit, "glow", c, [Vector2(0.001, 0.0), Vector2(0.16, 0.0), Vector2(0.16, 0.22), Vector2(0.001, 0.3)], 6, Color(1.0, 0.1, 0.05))


## An insulator string hanging from `top` down `l` metres: a yoke, a rod of glass caps, the conductor clamp (two bundled
## conductors on a spacer).
static func _insulator(pk: PropKit, kit: Dictionary, top: Vector3, l: float) -> void:
	pk.tube(kit, "galv", top, top - Vector3(0, l, 0), 0.025, 0.025, 4, GALV, false)
	var n: int = clampi(int(l / 0.55), 5, 14)
	for i in n:
		var y: float = top.y - 0.35 - (l - 0.7) * float(i) / float(n - 1)
		pk.lathe(kit, "lens", Vector3(top.x, y, top.z), [Vector2(0.03, -0.02), Vector2(0.15, -0.035), Vector2(0.03, 0.05)], 5, Color(0.45, 0.58, 0.52))
	var b: Vector3 = top - Vector3(0, l, 0)
	_blk(pk, kit, "galv", b + Vector3(-0.06, -0.05, -0.25), b + Vector3(0.06, 0.05, 0.25), GALV.darkened(0.15))


## A conductor (or earth wire) from a to b sagging `sag` at mid-span under the chord: a parabola (a catenary this flat is
## one) of thin three-sided segments, `radius` in the kit's units, about 20m a segment (8 to 30).
static func conductor(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, sag: float, radius := 0.05) -> void:
	var l: float = a.distance_to(b)
	var n: int = clampi(int(l / 20.0), 8, 30)
	var pts := PackedVector3Array()
	for i in n + 1:
		var t: float = float(i) / float(n)
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	var tri := PackedVector2Array([Vector2(radius, 0), Vector2(-radius * 0.5, radius * 0.866), Vector2(-radius * 0.5, -radius * 0.866)])
	var side: Vector3 = (b - a).cross(Vector3.UP)
	if side.length_squared() < 1e-6:
		side = Vector3.RIGHT
	var f: Array = _path_frames(pts, side.normalized())
	_sweep(pk, kit, "cable", f[0], f[1], f[2], tri, CABLE, true, true)
