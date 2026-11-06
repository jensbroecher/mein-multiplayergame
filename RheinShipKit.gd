extends RefCounted
## Rheinufer's river (Kronburg GP, stage 2): the Rhine's vessels and the furniture of its banks. A Gütermotorschiff (110 x
## 11.45m: hatch covers closed, containers, or an open hold of gravel), a Tankmotorschiff (86m), a push convoy (a Schubboot
## pushing one or two Europa IIa barges of ore), the white excursion ship of the made-up Kronburger Rheinflotte (70m), a
## small car ferry (45m), a landing stage with its gangway, the Rhine-kilometre boards, fairway buoys, a riprap groyne, a
## river gauge, a life-ring post and a mooring bollard. All fictional: generic modern Rhine shipping, made-up names and
## home ports; a German or Dutch flag at the stern.
##
## Everything is built through a PropKit at LIFE size and grown by the caller (PROP_SCALE 1.6): `new_kit(scale)`, set the
## frame, call a builder, `commit(pk, kit)`. Labels are [text, position, outward normal, cap height, colour, board width]
## in the builder's life-size frame.
##
## Ships: the bow toward +z, y = 0 the waterline, x = 0 the centre line, the hull centred on its length (SeaBoat.gd's
## convention: `draft` 0). What passes under the stage's bridges stays under AIR_DRAFT (7.2m) over the waterline: Rhine
## skippers lower their wheelhouses on the hydraulic column and fold the masts, so that is how they are built; `raised`
## puts the wheelhouse 4m up and the masts upright (a ship at its mooring: up to about 13m). Highest points lowered (life):
##   cargo_ship(pk, kit, labels, variant, ship_name, raised, home_port, dutch)   110 x 11.45m, 6.3m (parasol; boxes 6.23)
##   tanker(pk, kit, labels, ship_name, raised, home_port)                         86 x 11.45m, 7.12m (the cone mast)
##   push_convoy(pk, kit, labels, barges, raised)    the barges' bows at +z, the pusher at -z; convoy_length(barges); 6.7m
##   excursion_ship(pk, kit, labels, ship_name, raised)   70 x 10.5m, 7.17m (canopy); excursion_seats() passengers' spots
##   car_ferry(pk, kit, labels)                                                   45 x 13m (54.6m over its ramps), 8.25m
## Each ship's hull is a loft of cross-sections (`_hull`): a boxy midbody with vertical sides and a round bilge, the bow
## drawn in and flared, its forefoot rising to a raked stem, the stern rounded to a small transom, painted in bands
## (antifouling, a boot-topping band at the waterline, the topsides, a stripe under the sheer). The hull's surface key
## "hull" carries UV = (metres along, metres over the waterline) for rhein_ship_paint.gdshader's scum band and scrapes.
##
## Furniture (origin on the ground or the water, +z toward the river unless said otherwise):
##   landing_stage(pk, kit, labels, length, drop)  gangway_top(length, drop) says where its top end lands
##   km_board(pk, kit, labels, km), half_km_mark(pk, kit), fairway_buoy(pk, kit, red), groyne(pk, kit, length, drop),
##   pegel(pk, kit, labels, house_at), life_ring_post(pk, kit), mooring_bollard(pk, kit)
##
## Material keys (make_material): "hull", "paint", "white", "deck" (rhein_ship_paint.gdshader: painted steel weathered in
## the mesh's own space, so a moving ship's rust moves with it), "rglass" (rhein_ship_glass.gdshader: opaque windows with a
## made-up reflection; COLOR.a the curtains), "container" (rhein_container.gdshader), "bulk" and "riprap"
## (rhein_bulk.gdshader: gravel, ore, stones), "cloth" and "leaf" (two-sided vertex colour), "enamel" (glossy sign paint),
## "lens" (an unlit lamp), "timber" and "lapboards" (hut_wood), "concrete" (hut_masonry 8), "kbrick" and "biber"
## (hut_masonry 12 and 9), and CampKit's vertex-colour keys ("steel", "chrome", "matte", "rubber", "plastic", "canvas").
## Every mesh's first key (alphabetically) is opaque, so DressingColliders never takes one for see-through.
##
## Faces never share a plane: windows stand 2.5cm proud of their walls and their frames 6.5cm, names are labels 3cm off the
## hull, every trim steps or overlaps. Godot's front faces wind clockwise: PropKit.tri winds each triangle for its `out`.

const PropKit = preload("res://PropKit.gd")
const YardKit = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")

const AIR_DRAFT := 7.2

static var uvk := 1.6
static var _mats := {}
## The current sub-assembly's offset inside the builder's own frame (labels are given in builder coordinates).
static var _lx := Transform3D.IDENTITY

const TANGENT_KEYS := ["concrete", "iron", "biber", "kslate"]

const WHITE := Color(0.94, 0.94, 0.92)
const OFFWHITE := Color(0.90, 0.89, 0.85)
const BLACK := Color(0.05, 0.05, 0.055)
const STEEL_GREY := Color(0.42, 0.44, 0.45)
const DARK := Color(0.12, 0.13, 0.14)
const ANTIFOUL := Color(0.28, 0.10, 0.08)
const CHROME := Color(0.78, 0.79, 0.80)
const SIGNAL_RED := Color(0.80, 0.08, 0.06)
const SIGNAL_GREEN := Color(0.05, 0.55, 0.22)
const SIGNAL_BLUE := Color(0.08, 0.30, 0.72)
const LAMP_WHITE := Color(0.95, 0.94, 0.86)
const LIFEBUOY := Color(0.95, 0.38, 0.06)
const CRANE_YELLOW := Color(0.92, 0.70, 0.10)
const TIMBER := Color(0.52, 0.37, 0.22)
const GERANIUMS := [Color(0.86, 0.08, 0.12), Color(0.94, 0.32, 0.48), Color(0.97, 0.94, 0.92), Color(0.80, 0.10, 0.24)]
const CURTAINS := [Color(0.95, 0.93, 0.86), Color(0.97, 0.97, 0.96), Color(0.92, 0.88, 0.76), Color(0.95, 0.93, 0.86), Color(0.80, 0.32, 0.26),
		Color(0.97, 0.97, 0.97), Color(0.72, 0.80, 0.90)]
## Hull paints of the motor ships: [topsides, stripe under the sheer, deckhouse trim, hatch covers].
const LIVERIES := [
	[Color(0.10, 0.16, 0.30), WHITE, Color(0.10, 0.16, 0.30), Color(0.56, 0.60, 0.58)],
	[Color(0.11, 0.24, 0.17), WHITE, Color(0.11, 0.24, 0.17), Color(0.62, 0.62, 0.58)],
	[Color(0.07, 0.07, 0.08), Color(0.86, 0.68, 0.14), Color(0.52, 0.10, 0.08), Color(0.48, 0.50, 0.50)],
	[Color(0.40, 0.09, 0.08), WHITE, Color(0.40, 0.09, 0.08), Color(0.30, 0.42, 0.36)],
]
## Container paints (made-up lines).
const BOX_PAINTS := [Color(0.16, 0.36, 0.62), Color(0.62, 0.16, 0.13), Color(0.80, 0.42, 0.12), Color(0.18, 0.46, 0.30), Color(0.84, 0.70, 0.20),
		Color(0.86, 0.86, 0.84), Color(0.42, 0.44, 0.46), Color(0.48, 0.24, 0.40), Color(0.12, 0.42, 0.50), Color(0.55, 0.32, 0.20)]
const BOX_40 := Vector3(12.19, 2.59, 2.44)
const BOX_20 := Vector3(6.06, 2.59, 2.44)


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"hull", "paint", "white", "deck":
			var m := ShaderMaterial.new()
			m.shader = load("res://rhein_ship_paint.gdshader")
			m.set_shader_parameter("unit", uvk)
			match key:
				"hull":
					m.set_shader_parameter("hull_uv", true)
					m.set_shader_parameter("rust_amount", 0.16)
					m.set_shader_parameter("grime", 0.4)
					m.set_shader_parameter("patch_size", 4.0)
					m.set_shader_parameter("rough", 0.42)
					m.set_shader_parameter("metal", 0.12)
				"paint":
					m.set_shader_parameter("rust_amount", 0.08)
					m.set_shader_parameter("grime", 0.3)
					m.set_shader_parameter("rough", 0.48)
					m.set_shader_parameter("metal", 0.15)
				"white":
					m.set_shader_parameter("rust_amount", 0.05)
					m.set_shader_parameter("grime", 0.2)
					m.set_shader_parameter("rough", 0.34)
					m.set_shader_parameter("metal", 0.04)
					m.set_shader_parameter("patch_size", 3.5)
				"deck":
					m.set_shader_parameter("deck", true)
					m.set_shader_parameter("rust_amount", 0.25)
					m.set_shader_parameter("grime", 0.55)
					m.set_shader_parameter("rough", 0.82)
					m.set_shader_parameter("metal", 0.05)
					m.set_shader_parameter("patch_size", 3.0)
			return m
		"rglass":
			var g := ShaderMaterial.new()
			g.shader = load("res://rhein_ship_glass.gdshader")
			return g
		"container":
			var c := ShaderMaterial.new()
			c.shader = load("res://rhein_container.gdshader")
			return c
		"bulk", "riprap":
			var b := ShaderMaterial.new()
			b.shader = load("res://rhein_bulk.gdshader")
			b.set_shader_parameter("unit", uvk)
			if key == "riprap":
				b.set_shader_parameter("grain", 0.22)
				b.set_shader_parameter("contrast", 0.25)
				b.set_shader_parameter("stones", 1.0)
			return b
		"cloth", "leaf":
			var l := StandardMaterial3D.new()
			l.vertex_color_use_as_albedo = true
			l.vertex_color_is_srgb = true
			l.roughness = 0.9
			l.cull_mode = BaseMaterial3D.CULL_DISABLED
			return l
		"enamel":
			var e := StandardMaterial3D.new()
			e.vertex_color_use_as_albedo = true
			e.vertex_color_is_srgb = true
			e.roughness = 0.32
			return e
		"lens":
			var le := CampKit.make_material("plastic")
			le.roughness = 0.15
			le.metallic = 0.3
			return le
		"kbrick", "biber":
			var h := ShaderMaterial.new()
			h.shader = load("res://hut_masonry.gdshader")
			h.set_shader_parameter("style", 12 if key == "kbrick" else 9)
			return h
		"timber", "lapboards", "painted", "concrete", "iron":
			return YardKit.make_material(key)
	return CampKit.make_material(key)


## A kit growing everything by `scale`, its materials shared with every other kit made here.
static func new_kit(scale: float) -> PropKit:
	uvk = scale
	YardKit.uvk = scale
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	_lx = Transform3D.IDENTITY
	return pk


## The materials made so far, by key.
static func materials() -> Dictionary:
	return _mats


## Commits a kit with tangents on the surfaces whose shaders read a normal map, each surface named after its key.
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

static func _push(pk: PropKit, t: Transform3D) -> Array:
	var saved: Array = [pk.xf, _lx]
	pk.set_frame(pk.xf * t)
	_lx = _lx * t
	return saved


static func _pop(pk: PropKit, saved: Array) -> void:
	pk.set_frame(saved[0])
	_lx = saved[1]


static func _label(labels: Array, text: String, p: Vector3, n: Vector3, cap: float, col: Color, w := 0.0) -> void:
	labels.append([text, _lx * p, (_lx.basis * n).normalized(), cap, col, w])


## Axis-aligned block between two corners (any order), UVs in metres.
static func _blk(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	pk.block(kit, key, lo, hi, col, uvk)


## A box centred at `c` turned by `basis`, UVs in metres.
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## A slab between two corners: its sides and underside in `key` (`col`), its top in `top_key` (`top_col`): a deck on a
## roof without a second face in the roof's plane.
static func _slab(pk: PropKit, kit: Dictionary, lo: Vector3, hi: Vector3, key: String, col: Color, top_key: String, top_col: Color) -> void:
	var c: Vector3 = (lo + hi) * 0.5
	var sz: Vector3 = hi - lo
	pk.quad(kit, top_key, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], Vector3.UP, top_col,
			[Vector2(lo.x, lo.z) * uvk, Vector2(hi.x, lo.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(lo.x, hi.z) * uvk])
	pk.quad(kit, key, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)], Vector3.DOWN, col.darkened(0.1))
	for sx in [-1.0, 1.0]:
		var x: float = c.x + sx * sz.x * 0.5
		pk.quad(kit, key, [Vector3(x, lo.y, lo.z), Vector3(x, lo.y, hi.z), Vector3(x, hi.y, hi.z), Vector3(x, hi.y, lo.z)], Vector3(sx, 0, 0), col)
	for sz2 in [-1.0, 1.0]:
		var z: float = c.z + sz2 * sz.z * 0.5
		pk.quad(kit, key, [Vector3(lo.x, lo.y, z), Vector3(hi.x, lo.y, z), Vector3(hi.x, hi.y, z), Vector3(lo.x, hi.y, z)], Vector3(0, 0, sz2), col)


## A basis whose z is `out` (horizontal or not) and whose y is as near up as it can be.
static func _face_basis(out: Vector3) -> Basis:
	var z := out.normalized()
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.BACK
	var x := up.cross(z).normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


## A railing along a polyline: posts every 1.5m or so, a top rail and a knee rail (and a foot rail with `toe`).
static func _rail(pk: PropKit, kit: Dictionary, pts: Array, h := 1.0, col := WHITE, key := "white", toe := false, post := 0.038) -> void:
	var closed: bool = pts.size() > 2 and (pts[0] as Vector3).distance_to(pts[pts.size() - 1]) < 0.01
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d: float = a.distance_to(b)
		if d < 0.02:
			continue
		var n: int = maxi(int(ceil(d / 1.5)), 1)
		for k in range(n + 1):
			if k == 0 and i > 0:
				continue
			if k == n and closed and i == pts.size() - 2:
				continue
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			pk.beam(kit, key, p, p + Vector3.UP * h, post, post, col)
		pk.beam(kit, key, a + Vector3.UP * h, b + Vector3.UP * h, 0.055, 0.06, col, Vector3.UP)
		pk.beam(kit, key, a + Vector3.UP * (h * 0.5), b + Vector3.UP * (h * 0.5), 0.03, 0.055, col, Vector3.UP)
		if toe:
			pk.beam(kit, key, a + Vector3.UP * 0.06, b + Vector3.UP * 0.06, 0.02, 0.1, col.darkened(0.15), Vector3.UP)


## A ring of square section (a torus of `segs` sides) about the axis `axis` through `c`: radius r, section t.
static func _ring(pk: PropKit, kit: Dictionary, key: String, c: Vector3, axis: Vector3, r: float, t: float, segs: int, col: Color, cols: Array = []) -> void:
	var ax := axis.normalized()
	var u := ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := ax.cross(u).normalized()
	var h: float = t * 0.5
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var d0: Vector3 = u * cos(a0) + v * sin(a0)
		var d1: Vector3 = u * cos(a1) + v * sin(a1)
		var cc: Color = col if cols.is_empty() else cols[i % cols.size()]
		# Four faces: outer, inner, and the two sides along the axis.
		var faces: Array = [[r + h, r + h, h, -h, 1.0], [r - h, r - h, -h, h, -1.0]]
		for f in faces:
			var ra: float = f[0]
			var p0: Vector3 = c + d0 * ra + ax * float(f[2])
			var p1: Vector3 = c + d1 * ra + ax * float(f[2])
			var p2: Vector3 = c + d1 * ra + ax * float(f[3])
			var p3: Vector3 = c + d0 * ra + ax * float(f[3])
			var o: Vector3 = (d0 + d1).normalized() * float(f[4])
			pk.tri(kit, key, p0, p1, p2, d0 * float(f[4]), d1 * float(f[4]), d1 * float(f[4]), cc, o)
			pk.tri(kit, key, p0, p2, p3, d0 * float(f[4]), d1 * float(f[4]), d0 * float(f[4]), cc, o)
		for sgn in [-1.0, 1.0]:
			var q0: Vector3 = c + d0 * (r - h) + ax * (h * sgn)
			var q1: Vector3 = c + d1 * (r - h) + ax * (h * sgn)
			var q2: Vector3 = c + d1 * (r + h) + ax * (h * sgn)
			var q3: Vector3 = c + d0 * (r + h) + ax * (h * sgn)
			pk.quad(kit, key, [q0, q1, q2, q3], ax * sgn, cc)


## A lifebuoy (orange, four white bands) on a wall or rail facing `out`, its middle at `c`.
static func _lifebuoy(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3) -> void:
	_ring(pk, kit, "plastic", c, out, 0.3, 0.1, 12, LIFEBUOY, [LIFEBUOY, LIFEBUOY, WHITE])


## A double bollard (bitts) on a base plate at `p` (on the deck), its two posts along `along`.
static func _bitts(pk: PropKit, kit: Dictionary, p: Vector3, along := Vector3.BACK, col := DARK) -> void:
	var al := along.normalized()
	var ac := Vector3.UP.cross(al).normalized()
	_box(pk, kit, "paint", p + Vector3(0, 0.03, 0), Basis(ac, Vector3.UP, al), Vector3(0.5, 0.06, 1.0), col)
	for s in [-0.28, 0.28]:
		var b: Vector3 = p + al * float(s)
		pk.tube(kit, "paint", b + Vector3(0, 0.05, 0), b + Vector3(0, 0.5, 0), 0.13, 0.13, 8, col, false)
		pk.tube(kit, "paint", b + Vector3(0, 0.48, 0), b + Vector3(0, 0.56, 0), 0.18, 0.18, 8, col, true)


## A navigation light: a small lamp body facing `out` (or all round) at `p`, its lens `col`.
static func _nav_light(pk: PropKit, kit: Dictionary, p: Vector3, col: Color, out := Vector3.ZERO) -> void:
	if out == Vector3.ZERO:
		pk.tube(kit, "lens", p, p + Vector3(0, 0.22, 0), 0.08, 0.08, 8, col, true)
		pk.tube(kit, "paint", p + Vector3(0, 0.22, 0), p + Vector3(0, 0.27, 0), 0.1, 0.1, 8, DARK, true)
		return
	var b := _face_basis(out)
	_box(pk, kit, "paint", p - out.normalized() * 0.06, b, Vector3(0.24, 0.3, 0.12), DARK)
	_box(pk, kit, "lens", p + out.normalized() * 0.02, b, Vector3(0.16, 0.2, 0.06), col)


## A flag on a staff's top: `top` the head of the staff, flying toward `fly` (horizontal), German (black, red, gold) or
## Dutch (red, white, blue); a waved panel in "cloth" (two-sided).
static func _flag(pk: PropKit, kit: Dictionary, top: Vector3, fly: Vector3, dutch := false, w := 1.2, h := 0.8) -> void:
	var cols: Array = [Color(0.06, 0.06, 0.06), Color(0.82, 0.05, 0.06), Color(0.98, 0.78, 0.0)]
	if dutch:
		cols = [Color(0.72, 0.08, 0.12), Color(0.96, 0.96, 0.96), Color(0.10, 0.22, 0.52)]
	var f := fly.normalized()
	var side := f.cross(Vector3.UP).normalized()
	var nx := 6
	for band in range(3):
		var y0: float = -h * float(band + 1) / 3.0
		var y1: float = -h * float(band) / 3.0
		for i in range(nx):
			var t0: float = float(i) / float(nx)
			var t1: float = float(i + 1) / float(nx)
			var o0: Vector3 = side * (sin(t0 * 5.0) * 0.08 * t0)
			var o1: Vector3 = side * (sin(t1 * 5.0) * 0.08 * t1)
			var a: Vector3 = top + f * (w * t0) + o0 + Vector3(0, y0 - 0.06, 0)
			var b: Vector3 = top + f * (w * t1) + o1 + Vector3(0, y0 - 0.06, 0)
			var c: Vector3 = top + f * (w * t1) + o1 + Vector3(0, y1 - 0.06, 0)
			var d: Vector3 = top + f * (w * t0) + o0 + Vector3(0, y1 - 0.06, 0)
			pk.quad(kit, "cloth", [a, b, c, d], side, cols[band])


## A flag staff from `foot` up `h`, a ball on top and the flag.
static func _flag_staff(pk: PropKit, kit: Dictionary, foot: Vector3, h: float, fly: Vector3, dutch: bool) -> void:
	pk.tube(kit, "white", foot, foot + Vector3(0, h, 0), 0.04, 0.03, 6, WHITE, true)
	pk.tube(kit, "paint", foot + Vector3(0, h, 0), foot + Vector3(0, h + 0.08, 0), 0.05, 0.05, 6, Color(0.8, 0.65, 0.25), true)
	_flag(pk, kit, foot + Vector3(0, h - 0.04, 0), fly, dutch)


## A rectangular frame `fw` wide round the inside of a w x h opening centred on `c` in the plane (along, up), standing
## d0..d1 off it toward `out`: its front, its outer rim and the reveal inside (24 triangles).
static func _frame_ring(pk: PropKit, kit: Dictionary, key: String, c: Vector3, along: Vector3, up: Vector3, out: Vector3, w: float, h: float, fw: float,
		d0: float, d1: float, col: Color) -> void:
	var hw: float = w * 0.5
	var hh: float = h * 0.5
	var o: Array = [Vector2(-hw - fw, -hh - fw), Vector2(hw + fw, -hh - fw), Vector2(hw + fw, hh + fw), Vector2(-hw - fw, hh + fw)]
	var i: Array = [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]
	var P := func(v: Vector2, d: float) -> Vector3:
		return c + along * v.x + up * v.y + out * d
	for k in range(4):
		var a: Vector2 = o[k]
		var b: Vector2 = o[(k + 1) % 4]
		var cc: Vector2 = i[(k + 1) % 4]
		var dd: Vector2 = i[k]
		pk.quad(kit, key, [P.call(a, d1), P.call(b, d1), P.call(cc, d1), P.call(dd, d1)], out, col)
		var eo: Vector2 = (a + b) * 0.5
		var on: Vector3 = (along * eo.x / maxf(hw + fw, 0.001) if absf(eo.x) > 1e-4 else Vector3.ZERO) + (up * eo.y / maxf(hh + fw, 0.001) if absf(eo.y) > 1e-4 else Vector3.ZERO)
		pk.quad(kit, key, [P.call(a, d0), P.call(b, d0), P.call(b, d1), P.call(a, d1)], on.normalized(), col.darkened(0.1))
		pk.quad(kit, key, [P.call(dd, d0), P.call(cc, d0), P.call(cc, d1), P.call(dd, d1)], -on.normalized(), col.darkened(0.2))


## A window on a wall facing `out`: the glass 2.5cm proud (UV 0..1 over the pane, the curtains' colour and share in the
## vertex colour) and a frame round it to 6.5cm. `c` the opening's middle on the wall's face.
static func _window(pk: PropKit, kit: Dictionary, c: Vector3, along: Vector3, out: Vector3, w: float, h: float, curtain := Color(1, 1, 1, 0),
		frame := Color(0.82, 0.83, 0.84), up := Vector3.UP) -> void:
	var g: Vector3 = c + out * 0.025
	var hu: Vector3 = along * (w * 0.5)
	var hv: Vector3 = up * (h * 0.5)
	pk.quad(kit, "rglass", [g - hu - hv, g + hu - hv, g + hu + hv, g - hu + hv], out, curtain, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_frame_ring(pk, kit, "paint", c, along, up, out, w, h, 0.06, 0.0, 0.065, frame)


## A curtain colour and share drawn from `rng` (some windows bare, some with the curtains half drawn).
static func _curtain(rng: RandomNumberGenerator) -> Color:
	var c: Color = CURTAINS[rng.randi() % CURTAINS.size()]
	var share: float = [0.0, 0.18, 0.25, 0.3, 0.35, 0.5, 1.0][rng.randi() % 7]
	return Color(c.r, c.g, c.b, share)


## A flower box on a sill or a rail at `p` (the middle of its foot), `l` long along `along`: a box and geraniums.
static func _flower_box(pk: PropKit, kit: Dictionary, p: Vector3, along: Vector3, l: float, rng: RandomNumberGenerator) -> void:
	var al := along.normalized()
	var b := Basis(al, Vector3.UP, al.cross(Vector3.UP).normalized())
	_box(pk, kit, "plastic", p + Vector3(0, 0.1, 0), b, Vector3(l, 0.2, 0.2), Color(0.48, 0.30, 0.18))
	_box(pk, kit, "leaf", p + Vector3(0, 0.27, 0), b, Vector3(l - 0.06, 0.16, 0.24), Color(0.20, 0.38, 0.16))
	var col: Color = GERANIUMS[rng.randi() % GERANIUMS.size()]
	var n: int = maxi(int(l / 0.22), 2)
	for k in range(n):
		var t: float = (float(k) + 0.5) / float(n) - 0.5
		var q: Vector3 = p + al * (t * (l - 0.1)) + al.cross(Vector3.UP).normalized() * rng.randf_range(-0.07, 0.07) + Vector3(0, 0.36 + rng.randf_range(0.0, 0.06), 0)
		pk.lathe(kit, "leaf", q, [Vector2(0.001, -0.04), Vector2(0.07, 0.0), Vector2(0.06, 0.05), Vector2(0.001, 0.08)], 5, col.lerp(Color.WHITE, rng.randf_range(0.0, 0.12)), true)


## A small car (a hatchback, 3.9m) standing at `p` on the deck, its nose along `fwd`, painted `col`.
static func _car(pk: PropKit, kit: Dictionary, p: Vector3, fwd: Vector3, col: Color) -> void:
	var f := Vector3(fwd.x, 0, fwd.z).normalized()
	var side := Vector3.UP.cross(f).normalized()
	# The car's own frame: x along the car (the nose +x), y up, z across.
	var saved := _push(pk, Transform3D(Basis(f, Vector3.UP, -side), p))
	var prof := PackedVector2Array([Vector2(-1.95, 0.28), Vector2(-1.94, 0.95), Vector2(-1.72, 1.38), Vector2(-1.35, 1.47), Vector2(0.35, 1.48),
			Vector2(1.05, 1.0), Vector2(1.8, 0.86), Vector2(1.97, 0.62), Vector2(1.93, 0.28)])
	if PropKit._signed_area(prof) < 0.0:
		prof.reverse()
	pk.extrude(kit, "gloss", prof, -0.84, 0.84, 0.07, col)
	# Glass: the side windows, the windscreen and the rear window, 1cm proud.
	var glass := Color(0.08, 0.10, 0.12)
	for sz in [-1.0, 1.0]:
		var z: float = sz * 0.855
		var nz := Vector3(0, 0, sz)
		var win := [Vector3(-1.62, 1.0, z), Vector3(0.75, 1.0, z), Vector3(0.3, 1.38, z), Vector3(-1.3, 1.38, z)]
		pk.quad(kit, "gloss", win, nz, glass)
		pk.beam(kit, "gloss", Vector3(-0.42, 1.0, z + sz * 0.005), Vector3(-0.42, 1.38, z + sz * 0.005), 0.08, 0.01, col.darkened(0.2), Vector3(1, 0, 0))
	var ws := (Vector3(1.05, 1.0, 0) - Vector3(0.35, 1.48, 0))
	var wn := Vector3(-ws.y, ws.x, 0).normalized() * -1.0
	if wn.x < 0.0:
		wn = -wn
	pk.quad(kit, "gloss", [Vector3(0.98, 1.04, -0.7) + wn * 0.012, Vector3(0.98, 1.04, 0.7) + wn * 0.012, Vector3(0.42, 1.42, 0.62) + wn * 0.012, Vector3(0.42, 1.42, -0.62) + wn * 0.012], wn, glass)
	var rs := Vector3(-1.72, 1.38, 0) - Vector3(-1.94, 0.95, 0)
	var rn := Vector3(rs.y, -rs.x, 0).normalized()
	if rn.x > 0.0:
		rn = -rn
	pk.quad(kit, "gloss", [Vector3(-1.93, 1.0, 0.68) + rn * 0.012, Vector3(-1.93, 1.0, -0.68) + rn * 0.012, Vector3(-1.74, 1.35, -0.6) + rn * 0.012, Vector3(-1.74, 1.35, 0.6) + rn * 0.012], rn, glass)
	# Lamps.
	for sz2 in [-0.6, 0.6]:
		_box(pk, kit, "lens", Vector3(1.94, 0.74, sz2), Basis(), Vector3(0.06, 0.12, 0.3), LAMP_WHITE)
		_box(pk, kit, "lens", Vector3(-1.94, 0.88, sz2), Basis(), Vector3(0.06, 0.12, 0.22), SIGNAL_RED)
	# Wheels.
	for wx in [-1.25, 1.25]:
		for sz3 in [-1.0, 1.0]:
			pk.tube(kit, "rubber", Vector3(wx, 0.31, sz3 * 0.68), Vector3(wx, 0.31, sz3 * 0.9), 0.31, 0.31, 12, Color(0.05, 0.05, 0.05), true)
			pk.tube(kit, "chrome", Vector3(wx, 0.31, sz3 * 0.9), Vector3(wx, 0.31, sz3 * 0.91), 0.18, 0.18, 8, Color(0.6, 0.6, 0.62), true)
	_pop(pk, saved)


## A bicycle standing at `p`, along `along`, leaning a little (on a wall).
static func _bicycle(pk: PropKit, kit: Dictionary, p: Vector3, along: Vector3, col: Color) -> void:
	var al := Vector3(along.x, 0, along.z).normalized()
	var ac := Vector3.UP.cross(al).normalized()
	var lean := ac * 0.05
	var rw := p - al * 0.52 + Vector3(0, 0.34, 0)
	var fw := p + al * 0.52 + Vector3(0, 0.34, 0)
	_ring(pk, kit, "rubber", rw, ac, 0.32, 0.04, 12, Color(0.06, 0.06, 0.06))
	_ring(pk, kit, "rubber", fw, ac, 0.32, 0.04, 12, Color(0.06, 0.06, 0.06))
	var bb := p + Vector3(0, 0.32, 0) - al * 0.05 + lean * 0.5
	var seat := p + Vector3(0, 0.88, 0) - al * 0.22 + lean
	var head := p + Vector3(0, 0.92, 0) + al * 0.38 + lean
	for seg in [[rw, bb], [rw, seat], [bb, seat], [bb, head], [seat, head], [head, fw]]:
		pk.beam(kit, "paint", seg[0], seg[1], 0.035, 0.035, col)
	_box(pk, kit, "matte", seat + Vector3(0, 0.04, 0), Basis(al, Vector3.UP, ac), Vector3(0.24, 0.05, 0.1), DARK)
	pk.beam(kit, "steel", head + Vector3(0, 0.08, 0) - ac * 0.28, head + Vector3(0, 0.08, 0) + ac * 0.28, 0.03, 0.03, DARK)
	# A basket on the carrier.
	_box(pk, kit, "matte", rw + Vector3(0, 0.42, 0) + lean, Basis(al, Vector3.UP, ac), Vector3(0.36, 0.22, 0.3), Color(0.30, 0.22, 0.14))


## A dog kennel at `p` (the middle of its floor), its door toward `out`.
static func _kennel(pk: PropKit, kit: Dictionary, p: Vector3, out: Vector3) -> void:
	var z := Vector3(out.x, 0, out.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	var t := Transform3D(Basis(x, Vector3.UP, z), p)
	var saved := _push(pk, t)
	var wall := Color(0.62, 0.44, 0.26)
	_blk(pk, kit, "timber", Vector3(-0.45, 0.0, -0.55), Vector3(0.45, 0.6, 0.55), wall)
	pk.tri(kit, "timber", Vector3(-0.45, 0.6, 0.55), Vector3(0.45, 0.6, 0.55), Vector3(0, 0.95, 0.55), Vector3.BACK, Vector3.BACK, Vector3.BACK, wall, Vector3.BACK)
	pk.tri(kit, "timber", Vector3(0.45, 0.6, -0.55), Vector3(-0.45, 0.6, -0.55), Vector3(0, 0.95, -0.55), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, wall, Vector3.FORWARD)
	var roof := Color(0.28, 0.12, 0.09)
	for sx in [-1.0, 1.0]:
		var n := Vector3(sx * 0.35, 0.55, 0).normalized()
		pk.quad(kit, "paint", [Vector3(sx * 0.55, 0.55, 0.62), Vector3(0, 0.98, 0.62), Vector3(0, 0.98, -0.62), Vector3(sx * 0.55, 0.55, -0.62)], n, roof)
		pk.quad(kit, "paint", [Vector3(sx * 0.55, 0.54, 0.62), Vector3(0, 0.97, 0.62), Vector3(0, 0.97, -0.62), Vector3(sx * 0.55, 0.54, -0.62)], -n, roof.darkened(0.4))
	# The door: a dark arch, 2.5cm proud.
	pk.quad(kit, "matte", [Vector3(-0.18, 0.04, 0.575), Vector3(0.18, 0.04, 0.575), Vector3(0.18, 0.42, 0.575), Vector3(-0.18, 0.42, 0.575)], Vector3.BACK, Color(0.03, 0.03, 0.03))
	pk.tri(kit, "matte", Vector3(-0.18, 0.42, 0.575), Vector3(0.18, 0.42, 0.575), Vector3(0, 0.52, 0.575), Vector3.BACK, Vector3.BACK, Vector3.BACK, Color(0.03, 0.03, 0.03), Vector3.BACK)
	# A bowl.
	pk.tube(kit, "plastic", Vector3(0.3, 0.0, 0.8), Vector3(0.3, 0.08, 0.8), 0.12, 0.14, 8, Color(0.75, 0.12, 0.12), true)
	_pop(pk, saved)


## A deck chair at `p` facing `fwd`: a folding frame and a striped seat.
static func _deck_chair(pk: PropKit, kit: Dictionary, p: Vector3, fwd: Vector3, col: Color) -> void:
	var f := Vector3(fwd.x, 0, fwd.z).normalized()
	var s := Vector3.UP.cross(f).normalized()
	var seat0 := p + f * 0.35 + Vector3(0, 0.32, 0)
	var back1 := p - f * 0.45 + Vector3(0, 0.95, 0)
	for sx in [-0.28, 0.28]:
		pk.beam(kit, "timber", p + f * 0.5 + s * sx, back1 + s * sx, 0.04, 0.03, TIMBER)
		pk.beam(kit, "timber", p - f * 0.5 + s * (sx * 0.86), seat0 + s * (sx * 0.86), 0.04, 0.03, TIMBER)
	var n := (seat0 - back1).cross(s).normalized()
	if n.y < 0.0:
		n = -n
	pk.quad(kit, "cloth", [seat0 - s * 0.26 + n * 0.02, seat0 + s * 0.26 + n * 0.02, back1 + s * 0.26 + n * 0.02, back1 - s * 0.26 + n * 0.02], n, col)


## A parasol at `p` (its foot), open: a pole and a canopy `r` across, in "cloth".
static func _parasol(pk: PropKit, kit: Dictionary, p: Vector3, col: Color, r := 1.1, h := 2.1) -> void:
	pk.tube(kit, "steel", p + Vector3(0, 0.05, 0), p + Vector3(0, h + 0.2, 0), 0.025, 0.025, 6, Color(0.85, 0.85, 0.82), true)
	pk.tube(kit, "plastic", p, p + Vector3(0, 0.1, 0), 0.25, 0.25, 8, Color(0.85, 0.85, 0.82), true)
	pk.lathe(kit, "cloth", p + Vector3(0, h - 0.35, 0), [Vector2(r, 0.0), Vector2(r * 0.55, 0.28), Vector2(0.001, 0.42)], 8, col, true)


## A clothesline between `a` and `b` (the two posts' feet), posts `h` tall, with `n` things on the line.
static func _clothesline(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h: float, rng: RandomNumberGenerator, n := 5) -> void:
	var d: Vector3 = b - a
	var s := Vector3.UP.cross(d.normalized()).normalized()
	for p in [a, b]:
		pk.beam(kit, "steel", p, p + Vector3(0, h, 0), 0.04, 0.04, STEEL_GREY)
		pk.beam(kit, "steel", p + Vector3(0, h, 0) - s * 0.25, p + Vector3(0, h, 0) + s * 0.25, 0.03, 0.06, STEEL_GREY, Vector3.UP)
	for sk in [-0.2, 0.2]:
		pk.beam(kit, "matte", a + Vector3(0, h - 0.02, 0) + s * sk, b + Vector3(0, h - 0.02, 0) + s * sk, 0.012, 0.012, Color(0.9, 0.9, 0.88), Vector3.UP)
	var colours: Array = [Color(0.95, 0.95, 0.93), Color(0.25, 0.42, 0.75), Color(0.85, 0.25, 0.22), Color(0.95, 0.85, 0.40), Color(0.40, 0.65, 0.45),
			Color(0.30, 0.30, 0.34)]
	for k in range(n):
		var t: float = (float(k) + 0.6) / float(n + 0.4)
		var w: float = rng.randf_range(0.35, 0.7)
		var hh: float = rng.randf_range(0.45, 0.85)
		var sk2: float = -0.2 if k % 2 == 0 else 0.2
		var top: Vector3 = a + d * t + Vector3(0, h - 0.03, 0) + s * sk2
		var al: Vector3 = d.normalized()
		pk.quad(kit, "cloth", [top - al * (w * 0.5) - Vector3(0, hh, 0), top + al * (w * 0.5) - Vector3(0, hh, 0), top + al * (w * 0.5), top - al * (w * 0.5)], s,
				colours[rng.randi() % colours.size()])


# ======================================================================================
#  Hulls
# ======================================================================================

## Station rows are [z, half breadth at the sheer, half breadth low down (over the bilge), bottom y, sheer y]. The hull's
## side at height y between the bilge and the sheer flares out from the low breadth to the sheer's (FLARE: more of it up
## high); a round bilge `bilge` in radius turns it under to a flat bottom.
const FLARE := 1.7


static func _st_at(st: Array, z: float) -> Array:
	var f: Array = st[0]
	if z <= float(f[0]):
		return [f[1], f[2], f[3], f[4]]
	for i in range(st.size() - 1):
		var a: Array = st[i]
		var b: Array = st[i + 1]
		if z <= float(b[0]):
			var t: float = (z - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4)
			return [lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t), lerpf(a[4], b[4], t)]
	var l: Array = st[st.size() - 1]
	return [l[1], l[2], l[3], l[4]]


static func _bil(s: Array, bilge: float) -> float:
	return minf(bilge, minf(float(s[1]) * 0.6, (float(s[3]) - float(s[2])) * 0.3))


static func _side_x(s: Array, y: float, bilge: float) -> float:
	var bl: float = _bil(s, bilge)
	var yl: float = float(s[2]) + bl
	var f: float = clampf((y - yl) / maxf(float(s[3]) - yl, 0.01), 0.0, 1.0)
	return lerpf(float(s[1]), float(s[0]), pow(f, FLARE))


## The hull's starboard surface at (z, y): [point, outward normal], for parts laid on it (`side` -1: port).
static func _on_hull(st: Array, z: float, y: float, side: float, bilge: float) -> Array:
	var s: Array = _st_at(st, z)
	var x: float = _side_x(s, y, bilge)
	var dxdz: float = (_side_x(_st_at(st, z + 0.25), y, bilge) - _side_x(_st_at(st, z - 0.25), y, bilge)) / 0.5
	var dxdy: float = (_side_x(s, y + 0.1, bilge) - _side_x(s, y - 0.1, bilge)) / 0.2
	var n := Vector3(1.0, -dxdy, -dxdz).normalized()
	return [Vector3(x * side, y, z), Vector3(n.x * side, n.y, n.z)]


## A hull scheme: the paint bands and the bilge.
static func _scheme(top: Color, stripe_col: Color, boot_col := BLACK, anti := ANTIFOUL, boot := Vector2(0.12, 0.5), stripe := 0.25, bilge := 0.6, key := "hull") -> Dictionary:
	return {"top": top, "stripe_col": stripe_col, "boot_col": boot_col, "anti": anti, "boot": boot, "stripe": stripe, "bilge": bilge, "key": key}


## A station's starboard section from the sheer down to the keel: [points, colour of the segment below each point].
static func _section(row: Array, hs: Dictionary) -> Array:
	var z: float = row[0]
	var s: Array = [row[1], row[2], row[3], row[4]]
	var bl: float = _bil(s, hs["bilge"])
	var ys: float = s[3]
	var yb: float = s[2]
	var ylow: float = yb + bl
	var stripe_y: float = ys - float(hs["stripe"])
	var boot: Vector2 = hs["boot"]
	var lv: Array = [ys, stripe_y, lerpf(boot.y, stripe_y, 0.66), lerpf(boot.y, stripe_y, 0.33), boot.y, boot.x, -0.9, -1.8]
	var lc: Array = [hs["stripe_col"], hs["top"], hs["top"], hs["top"], hs["boot_col"], hs["anti"], hs["anti"], hs["anti"]]
	var pts: Array = []
	var cols: Array = []
	var prev := INF
	for k in range(lv.size()):
		var y: float = minf(clampf(float(lv[k]), ylow, ys), prev)
		prev = y
		pts.append(Vector3(_side_x(s, y, hs["bilge"]), y, z))
		cols.append(lc[k])
	# The bilge's segments take the band of their height (a transom's foot stands over the water in the topsides' paint).
	var cx: float = float(s[1]) - bl
	for k in range(5):
		var a: float = PI * 0.5 * float(k) / 4.0
		var a2: float = PI * 0.5 * float(k + 1) / 4.0
		pts.append(Vector3(cx + bl * cos(a), ylow - bl * sin(a), z))
		var ym: float = ylow - bl * (sin(a) + sin(minf(a2, PI * 0.5))) * 0.5
		cols.append(hs["top"] if ym > boot.y else (hs["boot_col"] if ym > boot.x else hs["anti"]))
	pts.append(Vector3(0.0, yb, z))
	cols.append(hs["anti"])
	return [pts, cols]


## The first distinct point before (dir -1) or after (dir 1) index j in a section.
static func _distinct(pts: Array, j: int, dir: int) -> int:
	var p: Vector3 = pts[j]
	var k: int = j + dir
	while k >= 0 and k < pts.size() and (pts[k] as Vector3).distance_to(p) < 1e-4:
		k += dir
	return clampi(k, 0, pts.size() - 1)


## The hull's loft through the stations `st`, painted by the scheme `hs`, both sides, a flat transom at the first station
## and a flat stem face at the last (each in bands). Normals are smooth along and round the hull. UV: (z, y), life metres.
static func _hull(pk: PropKit, kit: Dictionary, st: Array, hs: Dictionary) -> void:
	var secs: Array = []
	var cols: Array = []
	for row in st:
		var r: Array = _section(row, hs)
		secs.append(r[0])
		cols.append(r[1])
	var ns: int = secs.size()
	var np: int = (secs[0] as Array).size()
	var hk: String = hs["key"]
	var nrm: Array = []
	for i in range(ns):
		var nr: Array = []
		var pts: Array = secs[i]
		for j in range(np):
			var tz: Vector3 = (secs[mini(i + 1, ns - 1)][j] as Vector3) - (secs[maxi(i - 1, 0)][j] as Vector3)
			var ja: int = _distinct(pts, j, -1)
			var jb: int = _distinct(pts, j, 1)
			var ts: Vector3 = (pts[jb] as Vector3) - (pts[ja] as Vector3)
			var nv: Vector3 = tz.cross(ts)
			if nv.length_squared() < 1e-10:
				nv = Vector3.RIGHT
			nr.append(nv.normalized())
		nrm.append(nr)
	for side in [1.0, -1.0]:
		var m := Vector3(side, 1.0, 1.0)
		for i in range(ns - 1):
			for j in range(np - 1):
				var a: Vector3 = (secs[i][j] as Vector3) * m
				var b: Vector3 = (secs[i][j + 1] as Vector3) * m
				var c: Vector3 = (secs[i + 1][j + 1] as Vector3) * m
				var d: Vector3 = (secs[i + 1][j] as Vector3) * m
				var na: Vector3 = (nrm[i][j] as Vector3) * m
				var nb: Vector3 = (nrm[i][j + 1] as Vector3) * m
				var nc: Vector3 = (nrm[i + 1][j + 1] as Vector3) * m
				var nd: Vector3 = (nrm[i + 1][j] as Vector3) * m
				var col: Color = cols[i][j]
				var out: Vector3 = (na + nb + nc + nd).normalized()
				var ab: bool = a.distance_to(b) > 1e-4
				var dc: bool = d.distance_to(c) > 1e-4
				if ab:
					pk.tri(kit, hk, a, b, c, na, nb, nc, col, out, Vector2(a.z, a.y), Vector2(b.z, b.y), Vector2(c.z, c.y))
				if dc:
					pk.tri(kit, hk, a, c, d, na, nc, nd, col, out, Vector2(a.z, a.y), Vector2(c.z, c.y), Vector2(d.z, d.y))
	# The end faces, in bands: trapezoids between the starboard point and its mirror.
	for e in [[0, -1.0], [ns - 1, 1.0]]:
		var pts2: Array = secs[e[0]]
		var cl: Array = cols[e[0]]
		var nn := Vector3(0, 0, float(e[1]))
		for j in range(np - 1):
			var a2: Vector3 = pts2[j]
			var b2: Vector3 = pts2[j + 1]
			if a2.distance_to(b2) < 1e-4:
				continue
			var q: Array = [a2, b2, Vector3(-b2.x, b2.y, b2.z), Vector3(-a2.x, a2.y, a2.z)]
			var uq: Array = [Vector2(a2.z + a2.x, a2.y), Vector2(b2.z + b2.x, b2.y), Vector2(b2.z - b2.x, b2.y), Vector2(a2.z - a2.x, a2.y)]
			if b2.x > 1e-4:
				pk.tri(kit, hk, q[0], q[1], q[2], nn, nn, nn, cl[j], nn, uq[0], uq[1], uq[2])
			if a2.x > 1e-4:
				pk.tri(kit, hk, q[0], q[2], q[3], nn, nn, nn, cl[j], nn, uq[0], uq[2], uq[3])


## A deck at the sheer between z0 and z1, from edge to edge, or (with x_in > 0) only outboard of x_in on both sides (the
## gangboards). It follows the hull's sheer exactly (the same stations). `lift` raises it off the sheer.
static func _deck(pk: PropKit, kit: Dictionary, st: Array, z0: float, z1: float, col: Color, x_in := 0.0, key := "deck", lift := 0.0, inset := 0.0) -> void:
	var zs: Array = [z0]
	for row in st:
		if float(row[0]) > z0 + 0.01 and float(row[0]) < z1 - 0.01:
			zs.append(float(row[0]))
	zs.append(z1)
	for k in range(zs.size() - 1):
		var za: float = zs[k]
		var zb: float = zs[k + 1]
		var sa: Array = _st_at(st, za)
		var sb: Array = _st_at(st, zb)
		var wa: float = float(sa[0]) - inset
		var wb: float = float(sb[0]) - inset
		var ya: float = float(sa[3]) + lift
		var yb: float = float(sb[3]) + lift
		var n := Vector3(0, zb - za, -(yb - ya)).normalized()
		if x_in <= 0.0:
			pk.quad(kit, key, [Vector3(-wa, ya, za), Vector3(wa, ya, za), Vector3(wb, yb, zb), Vector3(-wb, yb, zb)], n, col)
		else:
			for sx in [-1.0, 1.0]:
				pk.quad(kit, key, [Vector3(sx * x_in, ya, za), Vector3(sx * wa, ya, za), Vector3(sx * wb, yb, zb), Vector3(sx * x_in, yb, zb)], n, col)


## The deck's edge from z0 to z1 on one side (`side`), `inset` in from the sheer, `lift` over the deck: points at the stations.
static func _edge(st: Array, z0: float, z1: float, side: float, inset := 0.08, lift := 0.0) -> Array:
	var zs: Array = [z0]
	for row in st:
		if float(row[0]) > z0 + 0.01 and float(row[0]) < z1 - 0.01:
			zs.append(float(row[0]))
	zs.append(z1)
	var out: Array = []
	for z in zs:
		var s: Array = _st_at(st, z)
		out.append(Vector3(side * (float(s[0]) - inset), float(s[3]) + lift, z))
	return out


## A rubbing strake along both sides at height y (or `rel` under the sheer), from z0 to z1: a beam `size` (across x
## height) standing out of the side.
static func _strake(pk: PropKit, kit: Dictionary, st: Array, hs: Dictionary, y: float, z0: float, z1: float, size: Vector2, col: Color, rel := false, key := "paint") -> void:
	var zs: Array = [z0]
	for row in st:
		if float(row[0]) > z0 + 0.01 and float(row[0]) < z1 - 0.01:
			zs.append(float(row[0]))
	zs.append(z1)
	for side in [1.0, -1.0]:
		var prev := Vector3.ZERO
		for k in range(zs.size()):
			var z: float = zs[k]
			var s: Array = _st_at(st, z)
			var yy: float = (float(s[3]) + y) if rel else y
			var p := Vector3(side * (_side_x(s, yy, hs["bilge"]) + size.x * 0.3), yy, z)
			if k > 0:
				pk.beam(kit, key, prev, p, size.x, size.y, col, Vector3(side, 0, 0))
			prev = p


# ======================================================================================
#  Motor ships: the stations, the aft quarters and wheelhouse, the forecastle
# ======================================================================================

## A Rhine motor ship's stations: `L` long, half breadth `hb`, draught `T`, the sheer at `ys` amidships rising
## `bow_rise` to the stem and `stern_rise` to the transom.
static func _motor_stations(L: float, hb: float, T: float, ys: float, bow_rise: float, stern_rise: float) -> Array:
	var h: float = L * 0.5
	return [
		[-h, hb * 0.6, hb * 0.57, 0.45, ys + stern_rise],
		[-h + 0.5, hb * 0.79, hb * 0.74, 0.15, ys + stern_rise * 0.98],
		[-h + 1.5, hb * 0.9, hb * 0.85, -0.45, ys + stern_rise * 0.92],
		[-h + 3.0, hb * 0.96, hb * 0.93, -1.25, ys + stern_rise * 0.8],
		[-h + 5.0, hb * 0.99, hb * 0.975, -T * 0.86, ys + stern_rise * 0.62],
		[-h + 8.0, hb, hb * 0.996, -T, ys + stern_rise * 0.38],
		[-h + 13.0, hb, hb, -T, ys + stern_rise * 0.12],
		[-h + 18.0, hb, hb, -T, ys],
		[h - 17.0, hb, hb, -T, ys],
		[h - 12.0, hb * 0.998, hb * 0.98, -T, ys + bow_rise * 0.1],
		[h - 8.0, hb * 0.978, hb * 0.9, -T * 0.95, ys + bow_rise * 0.3],
		[h - 5.0, hb * 0.91, hb * 0.74, -T * 0.75, ys + bow_rise * 0.55],
		[h - 2.8, hb * 0.78, hb * 0.54, -T * 0.42, ys + bow_rise * 0.76],
		[h - 1.2, hb * 0.58, hb * 0.33, 0.0, ys + bow_rise * 0.91],
		[h - 0.4, hb * 0.38, hb * 0.18, 0.6, ys + bow_rise * 0.975],
		[h, hb * 0.18, hb * 0.08, 1.0, ys + bow_rise],
	]


## The aft quarters of a motor ship: the deckhouse (the skipper's family's flat), the wheelhouse on its hydraulic column
## in front of it, and the aft deck behind it with the car and its crane, a bicycle, a kennel, the flag staff.
## z_stern: the transom; z_front: the wheelhouse's front. Returns the wheelhouse's roof height.
static func _quarters(pk: PropKit, kit: Dictionary, labels: Array, st: Array, hs: Dictionary, z_stern: float, z_front: float, raised: bool, trim: Color,
		ship_name: String, home_port: String, dutch: bool, rng: RandomNumberGenerator, cones := 0, car := true) -> float:
	var hb: float = float(_st_at(st, 0.0)[0])
	var z_dh0: float = z_stern + 5.6
	var z_dh1: float = z_front - 3.7
	var xh: float = hb - 0.85
	var y0: float = float(_st_at(st, z_dh0)[3])
	var y1: float = float(_st_at(st, z_dh1)[3])
	var roof: float = maxf(y0, y1) + 2.45
	# The deckhouse: walls on the deck (their feet following its sheer), white with a trim band under the roof.
	var walls: Array = [
		[Vector3(xh, y0, z_dh0), Vector3(xh, y1, z_dh1), Vector3(1, 0, 0)],
		[Vector3(-xh, y1, z_dh1), Vector3(-xh, y0, z_dh0), Vector3(-1, 0, 0)],
		[Vector3(xh, y1, z_dh1), Vector3(-xh, y1, z_dh1), Vector3(0, 0, 1)],
		[Vector3(-xh, y0, z_dh0), Vector3(xh, y0, z_dh0), Vector3(0, 0, -1)],
	]
	for w in walls:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		var n: Vector3 = w[2]
		pk.quad(kit, "white", [a, b, Vector3(b.x, roof - 0.3, b.z), Vector3(a.x, roof - 0.3, a.z)], n, WHITE)
		pk.quad(kit, "paint", [Vector3(a.x, roof - 0.3, a.z), Vector3(b.x, roof - 0.3, b.z), Vector3(b.x, roof, b.z), Vector3(a.x, roof, a.z)], n, trim)
	# The roof: a slab overhanging 12cm (its underside shows), a railing round the roof deck.
	_slab(pk, kit, Vector3(-xh - 0.12, roof, z_dh0 - 0.12), Vector3(xh + 0.12, roof + 0.16, z_dh1 + 0.12), "white", OFFWHITE, "deck", Color(0.42, 0.46, 0.44))
	var ry: float = roof + 0.16
	_rail(pk, kit, [Vector3(-xh, ry, z_dh1 - 0.06), Vector3(-xh, ry, z_dh0 + 0.06), Vector3(xh, ry, z_dh0 + 0.06), Vector3(xh, ry, z_dh1 - 0.06)], 0.95)
	# Windows: along both sides, two at the back beside the door, two at the front.
	var len_dh: float = z_dh1 - z_dh0
	var nw: int = maxi(int((len_dh - 1.6) / 2.3), 1)
	for side in [1.0, -1.0]:
		for k in range(nw):
			var wz: float = z_dh0 + 0.8 + (len_dh - 1.6) * (float(k) + 0.5) / float(nw)
			var fy: float = lerpf(y0, y1, (wz - z_dh0) / len_dh)
			var c := Vector3(side * xh, fy + 1.45, wz)
			_window(pk, kit, c, Vector3(0, 0, -side), Vector3(side, 0, 0), 1.25, 0.85, _curtain(rng))
			# Flower boxes under some of the windows.
			if k % 2 == 0:
				_flower_box(pk, kit, Vector3(side * (xh + 0.2), fy + 0.72, wz), Vector3(0, 0, 1), 1.1, rng)
	for wx in [-3.2, 2.9]:
		_window(pk, kit, Vector3(wx, y1 + 1.45, z_dh1), Vector3(1, 0, 0), Vector3(0, 0, 1), 1.2, 0.8, _curtain(rng))
	_window(pk, kit, Vector3(-2.4, y0 + 1.45, z_dh0), Vector3(-1, 0, 0), Vector3(0, 0, -1), 1.2, 0.8, _curtain(rng))
	# Doors: the back (onto the aft deck) and the front's side.
	for dd in [[Vector3(1.0, y0, z_dh0), Vector3(0, 0, -1)], [Vector3(-1.4, y1, z_dh1), Vector3(0, 0, 1)]]:
		var dp: Vector3 = dd[0]
		var dn: Vector3 = dd[1]
		var b2 := _face_basis(dn)
		_box(pk, kit, "paint", dp + Vector3(0, 1.0, 0) + dn * 0.03, b2, Vector3(0.82, 2.0, 0.05), trim.lightened(0.05))
		_window(pk, kit, dp + Vector3(0, 1.45, 0) + dn * 0.055, b2.x, dn, 0.45, 0.6, Color(0.95, 0.95, 0.95, 0.0), trim.lightened(0.05))
		_box(pk, kit, "chrome", dp + Vector3(0.28, 1.0, 0) + dn * 0.08, b2, Vector3(0.12, 0.03, 0.04), CHROME)
	# On the roof: chairs, a table, a parasol, a satellite dish, flower boxes on the back rail, the clothesline, exhausts.
	_deck_chair(pk, kit, Vector3(-2.2, ry, z_dh0 + 2.2), Vector3(0.3, 0, 1), Color(0.20, 0.40, 0.70))
	_deck_chair(pk, kit, Vector3(-1.2, ry, z_dh0 + 2.0), Vector3(-0.2, 0, 1), Color(0.85, 0.30, 0.20))
	pk.tube(kit, "plastic", Vector3(-1.7, ry + 0.1, z_dh0 + 3.3), Vector3(-1.7, ry + 0.7, z_dh0 + 3.3), 0.045, 0.045, 6, WHITE, false)
	pk.tube(kit, "plastic", Vector3(-1.7, ry + 0.7, z_dh0 + 3.3), Vector3(-1.7, ry + 0.74, z_dh0 + 3.3), 0.45, 0.45, 10, WHITE, true)
	_parasol(pk, kit, Vector3(-1.7, ry, z_dh0 + 3.3), Color(0.92, 0.80, 0.30), 1.05, 1.95)
	pk.tube(kit, "steel", Vector3(xh - 0.4, ry, z_dh0 + 0.5), Vector3(xh - 0.4, ry + 0.9, z_dh0 + 0.5), 0.03, 0.03, 6, STEEL_GREY, true)
	pk.lathe(kit, "plastic", Vector3(xh - 0.4, ry + 0.8, z_dh0 + 0.62), [Vector2(0.001, 0.0), Vector2(0.3, 0.05), Vector2(0.36, 0.12), Vector2(0.001, 0.1)], 10,
			OFFWHITE, false, Basis(Vector3.RIGHT, -1.2))
	for fx in [-2.2, 0.2, 2.6]:
		_flower_box(pk, kit, Vector3(fx, ry + 0.95, z_dh0 + 0.18), Vector3(1, 0, 0), 1.0, rng)
	if len_dh > 6.0:
		_clothesline(pk, kit, Vector3(xh - 0.6, ry, z_dh0 + 1.6), Vector3(xh - 0.6, ry, z_dh1 - 1.4), 1.6, rng, 5)
	for ex in [-xh + 0.5, -xh + 1.0]:
		pk.tube(kit, "paint", Vector3(ex, ry - 0.02, z_dh0 + 0.9), Vector3(ex, ry + 1.3, z_dh0 + 0.9), 0.15, 0.15, 10, DARK, false)
		pk.tube(kit, "paint", Vector3(ex, ry + 1.3, z_dh0 + 0.9), Vector3(ex, ry + 1.34, z_dh0 + 0.9), 0.22, 0.22, 10, DARK, true)
	# The wheelhouse on its column.
	var wh_top: float = _wheelhouse(pk, kit, labels, Vector3(0, float(_st_at(st, z_front - 1.7)[3]), z_front - 1.7), roof, raised, trim, ry, z_dh0, z_dh1, cones)
	# The aft deck: the car and its crane, the bicycle, the kennel, bitts, the railing round the stern, the flag.
	var ya: float = float(_st_at(st, z_stern + 2.6)[3])
	if car:
		var car_cols: Array = [Color(0.72, 0.10, 0.10), Color(0.15, 0.30, 0.55), Color(0.85, 0.85, 0.85), Color(0.20, 0.22, 0.25), Color(0.30, 0.45, 0.30)]
		_car(pk, kit, Vector3(-0.5, ya, z_stern + 2.8), Vector3(1, 0, 0), car_cols[rng.randi() % car_cols.size()])
		_car_crane(pk, kit, Vector3(xh - 0.2, float(_st_at(st, z_dh0 - 0.8)[3]), z_dh0 - 0.8), Vector3(-0.5, ya + 1.6, z_stern + 2.8))
	_bicycle(pk, kit, Vector3(2.2, y0, z_dh0 - 0.4), Vector3(1, 0, 0), Color(0.15, 0.35, 0.65))
	_kennel(pk, kit, Vector3(-xh + 0.6, y0, z_dh0 - 0.8), Vector3(1, 0, -0.3))
	for sx in [-1.0, 1.0]:
		var bz: float = z_stern + 1.4
		var s: Array = _st_at(st, bz)
		_bitts(pk, kit, Vector3(sx * (float(s[0]) - 0.7), float(s[3]), bz), Vector3(0, 0, 1))
	var rail_pts: Array = _edge(st, z_stern + 0.05, z_dh0 - 0.3, 1.0, 0.1)
	rail_pts.reverse()
	var port_pts: Array = _edge(st, z_stern + 0.05, z_dh0 - 0.3, -1.0, 0.1)
	_rail(pk, kit, rail_pts + port_pts, 1.0, WHITE, "white", true)
	_lifebuoy(pk, kit, Vector3(2.4, float(_st_at(st, z_stern)[3]) + 0.6, z_stern + 0.0), Vector3(0, 0, -1))
	var yt: float = float(_st_at(st, z_stern)[3])
	_flag_staff(pk, kit, Vector3(0, yt, z_stern + 0.25), 2.6, Vector3(-0.3, 0, -1), dutch)
	_nav_light(pk, kit, Vector3(0, yt + 1.15, z_stern + 0.28), LAMP_WHITE, Vector3(0, 0, -1))
	# The name and home port on the transom.
	_label(labels, ship_name, Vector3(0, yt - 0.45, z_stern - 0.03), Vector3(0, 0, -1), 0.36, WHITE, float(_st_at(st, z_stern)[0]) * 1.6)
	_label(labels, home_port, Vector3(0, yt - 0.92, z_stern - 0.03), Vector3(0, 0, -1), 0.22, WHITE, float(_st_at(st, z_stern)[0]) * 1.4)
	return wh_top


## The car crane on the aft deck: a pedestal at `foot`, its jib reaching toward `hook` (over the car), the hook and its
## slings hanging there.
static func _car_crane(pk: PropKit, kit: Dictionary, foot: Vector3, hook: Vector3) -> void:
	var top := foot + Vector3(0, 1.5, 0)
	pk.tube(kit, "paint", foot, top, 0.16, 0.13, 10, CRANE_YELLOW, true)
	var d := Vector3(hook.x - top.x, 0, hook.z - top.z)
	var tip := Vector3(hook.x, hook.y + 0.9, hook.z)
	_box(pk, kit, "paint", top + Vector3(0, 0.15, 0), _face_basis(d), Vector3(0.45, 0.35, 0.55), CRANE_YELLOW.darkened(0.1))
	pk.beam(kit, "paint", top + Vector3(0, 0.25, 0), tip, 0.2, 0.24, CRANE_YELLOW, Vector3.UP)
	pk.tube(kit, "chrome", foot + Vector3(0, 0.6, 0) + d.normalized() * 0.12, top.lerp(tip, 0.45), 0.05, 0.05, 6, CHROME, true)
	pk.beam(kit, "steel", tip, Vector3(hook.x, hook.y + 0.2, hook.z), 0.02, 0.02, DARK)
	_box(pk, kit, "paint", Vector3(hook.x, hook.y + 0.15, hook.z), Basis(), Vector3(0.18, 0.25, 0.12), DARK)


## The wheelhouse on its hydraulic column: `base` on the deck under its middle; lowered its floor 1.55m over the deck,
## raised 4m higher. Front windows lean out, a sun visor over them, the radar and a folding mast on the roof (lowered it
## lies aft over the deckhouse roof on a crutch). Returns the roof's top.
static func _wheelhouse(pk: PropKit, kit: Dictionary, labels: Array, base: Vector3, dh_roof: float, raised: bool, trim: Color, dh_deck: float, z_dh0: float,
		z_dh1: float, cones := 0) -> float:
	var hw := 2.35
	var hl := 1.7
	var yf: float = base.y + 1.55 + (4.0 if raised else 0.0)
	var cz: float = base.z
	var z0: float = cz - hl
	var z1: float = cz + hl
	# The column: a housing on the deck, the chrome ram and its guide up to the floor.
	_blk(pk, kit, "paint", Vector3(-0.8, base.y, cz - 0.7), Vector3(0.8, base.y + 0.75, cz + 0.7), trim)
	pk.tube(kit, "chrome", Vector3(0, base.y + 0.7, cz), Vector3(0, yf + 0.05, cz), 0.3, 0.3, 14, CHROME, false)
	pk.tube(kit, "chrome", Vector3(0.55, base.y + 0.7, cz - 0.3), Vector3(0.55, yf + 0.05, cz - 0.3), 0.08, 0.08, 8, CHROME, false)
	pk.tube(kit, "chrome", Vector3(-0.55, base.y + 0.7, cz - 0.3), Vector3(-0.55, yf + 0.05, cz - 0.3), 0.08, 0.08, 8, CHROME, false)
	# The body: a white lower part (closed underneath), the window band, a fascia, the roof.
	var yw0: float = yf + 1.0
	var yw1: float = yf + 2.2
	var yr: float = yf + 2.42
	var lean := 0.28
	_blk(pk, kit, "white", Vector3(-hw, yf, z0), Vector3(hw, yw0, z1), WHITE)
	_blk(pk, kit, "paint", Vector3(-hw - 0.025, yf + 0.03, z0 - 0.025), Vector3(hw + 0.025, yf + 0.2, z1 + 0.025), trim)
	# The window band's frame: corner pillars (the front ones leaning out with the glass) and the fascia over them.
	var pillar := Color(0.15, 0.16, 0.17)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "paint", Vector3(sx * (hw - 0.05), yw0, z1 - 0.05), Vector3(sx * (hw - 0.05), yw1, z1 + lean - 0.05), 0.1, 0.1, pillar, Vector3(1, 0, 0))
		pk.beam(kit, "paint", Vector3(sx * (hw - 0.05), yw0, z0 + 0.05), Vector3(sx * (hw - 0.05), yw1, z0 + 0.05), 0.1, 0.1, pillar, Vector3(1, 0, 0))
	for mx in [-0.8, 0.8]:
		pk.beam(kit, "paint", Vector3(mx, yw0, z1 + 0.0), Vector3(mx, yw1, z1 + lean), 0.07, 0.06, pillar, Vector3(1, 0, 0))
	# Glass: front (leaning), sides (trapezoids), back.
	var front_n := Vector3(0, -lean, yw1 - yw0).normalized()
	pk.quad(kit, "rglass", [Vector3(-hw + 0.1, yw0, z1 + 0.0), Vector3(hw - 0.1, yw0, z1 + 0.0), Vector3(hw - 0.1, yw1, z1 + lean), Vector3(-hw + 0.1, yw1, z1 + lean)],
			front_n, Color(1, 1, 1, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	for sx2 in [-1.0, 1.0]:
		var xs: float = sx2 * hw
		pk.quad(kit, "rglass", [Vector3(xs, yw0, z0 + 0.1), Vector3(xs, yw0, z1 - 0.1), Vector3(xs, yw1, z1 + lean - 0.1), Vector3(xs, yw1, z0 + 0.1)], Vector3(sx2, 0, 0),
				Color(1, 1, 1, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		# Dark infill under the side glass's slanted edge... a pillar covers it; the side lights at the front corners.
		_nav_light(pk, kit, Vector3(sx2 * (hw + 0.18), yw0 + 0.3, z1 - 0.35), SIGNAL_GREEN if sx2 > 0.0 else SIGNAL_RED, Vector3(sx2, 0, 0.3))
	pk.quad(kit, "rglass", [Vector3(hw - 0.1, yw0, z0), Vector3(-hw + 0.1, yw0, z0), Vector3(-hw + 0.1, yw1, z0), Vector3(hw - 0.1, yw1, z0)], Vector3(0, 0, -1),
			Color(1, 1, 1, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	# The sills and the fascia over the band (the fascia overhangs the leaning front).
	_blk(pk, kit, "white", Vector3(-hw - 0.02, yw1, z0 - 0.02), Vector3(hw + 0.02, yr, z1 + lean + 0.02), WHITE)
	_blk(pk, kit, "paint", Vector3(-hw - 0.15, yr, z0 - 0.12), Vector3(hw + 0.15, yr + 0.1, z1 + lean + 0.45), trim)
	# On the roof: the radar, a searchlight, horns, the whip antennas laid down, and the folding mast.
	var rtop: float = yr + 0.1
	_blk(pk, kit, "paint", Vector3(-0.2, rtop, cz - 0.2), Vector3(0.2, rtop + 0.3, cz + 0.2), DARK)
	_box(pk, kit, "plastic", Vector3(0, rtop + 0.42, cz), Basis(Vector3.UP, 0.35), Vector3(2.0, 0.22, 0.32), OFFWHITE)
	pk.tube(kit, "plastic", Vector3(1.4, rtop, z1 - 0.3), Vector3(1.4, rtop + 0.25, z1 - 0.3), 0.06, 0.06, 6, DARK, true)
	pk.tube(kit, "chrome", Vector3(1.4, rtop + 0.3, z1 - 0.45), Vector3(1.4, rtop + 0.3, z1 - 0.1), 0.15, 0.17, 10, CHROME, true)
	pk.tube(kit, "plastic", Vector3(-1.3, rtop, z1 - 0.3), Vector3(-1.3, rtop + 0.2, z1 - 0.3), 0.05, 0.05, 6, DARK, true)
	pk.tube(kit, "paint", Vector3(-1.3, rtop + 0.25, z1 - 0.6), Vector3(-1.3, rtop + 0.25, z1 - 0.0), 0.05, 0.12, 8, CHROME, true)
	for ax in [-1.9, 1.9]:
		var a0 := Vector3(ax, rtop, z0 + 0.4)
		var a1: Vector3 = a0 + (Vector3(0, 2.4, 0) if raised else Vector3(0, 0.35, -2.3))
		pk.tube(kit, "plastic", a0, a1, 0.025, 0.012, 5, WHITE, true)
	var mast_len := 3.4
	var pivot := Vector3(0, rtop + 0.25, z0 + 0.35)
	_blk(pk, kit, "paint", Vector3(-0.15, rtop, z0 + 0.2), Vector3(0.15, rtop + 0.3, z0 + 0.5), DARK)
	var mtip: Vector3 = pivot + (Vector3(0, mast_len, 0) if raised else Vector3(0, 0.05, -mast_len))
	pk.tube(kit, "paint", pivot, mtip, 0.08, 0.06, 8, WHITE, true)
	if raised:
		pk.beam(kit, "paint", mtip - Vector3(0, 0.6, 0) + Vector3(-0.7, 0, 0), mtip - Vector3(0, 0.6, 0) + Vector3(0.7, 0, 0), 0.06, 0.06, WHITE, Vector3.UP)
		_nav_light(pk, kit, mtip, LAMP_WHITE)
		for k in range(cones):
			_cone_signal(pk, kit, mtip - Vector3(0, 1.0 + 0.95 * float(k), 0) + Vector3(0.5, 0, 0))
	else:
		_nav_light(pk, kit, mtip + Vector3(0, 0.05, 0), LAMP_WHITE)
		# The crutch the lowered mast rests on, on the deckhouse roof.
		var cz2: float = maxf(mtip.z + 0.4, z_dh0 + 0.3)
		pk.beam(kit, "paint", Vector3(0, dh_deck, cz2), Vector3(0, mtip.y - 0.07, cz2), 0.08, 0.08, DARK)
		pk.beam(kit, "paint", Vector3(-0.2, mtip.y - 0.08, cz2), Vector3(0.2, mtip.y - 0.08, cz2), 0.06, 0.06, DARK, Vector3.UP)
		# A short signal mast on the roof's front for the cones (they show whatever the bridges).
		if cones > 0:
			var sm := Vector3(0, rtop, z1 - 0.2)
			pk.tube(kit, "paint", sm, sm + Vector3(0, 1.5, 0), 0.05, 0.04, 6, WHITE, true)
			_cone_signal(pk, kit, sm + Vector3(0, 1.45, 0))
	# A stair from the deck to the wheelhouse door (lowered: on the starboard side, aft).
	if not raised:
		var foot := Vector3(hw + 0.55, base.y, z0 - 0.2)
		var head := Vector3(hw + 0.55, yf, z0 + 1.2)
		_stair(pk, kit, foot, head, 0.6)
		_blk(pk, kit, "deck", Vector3(hw + 0.02, yf - 0.06, z0 + 1.2), Vector3(hw + 0.85, yf, z0 + 2.2), Color(0.38, 0.40, 0.40))
	return rtop + (0.53 if not raised else mast_len + 0.3)


## A blue cone, point down (the dangerous-goods signal), hanging with its top at `top`.
static func _cone_signal(pk: PropKit, kit: Dictionary, top: Vector3) -> void:
	pk.lathe(kit, "paint", top - Vector3(0, 0.62, 0), [Vector2(0.001, 0.0), Vector2(0.36, 0.6), Vector2(0.001, 0.6)], 10, SIGNAL_BLUE, true)
	pk.beam(kit, "steel", top - Vector3(0, 0.02, 0), top + Vector3(0, 0.08, 0), 0.02, 0.02, DARK)


## A steel stair from `a` (its foot) to `b` (its head): stringers, treads every 0.2m rise, handrails.
static func _stair(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, w := 0.7, col := STEEL_GREY, rail := WHITE) -> void:
	var run := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if run.length() < 0.01:
		return
	var dir := run.normalized()
	var across := Vector3(-dir.z, 0.0, dir.x)
	for sd in [-0.5, 0.5]:
		var o: Vector3 = across * (sd * w)
		pk.beam(kit, "paint", a + o, b + o, 0.04, 0.2, col, across)
		pk.beam(kit, "white", a + o * 1.08 + Vector3.UP * 0.95, b + o * 1.08 + Vector3.UP * 0.95, 0.055, 0.055, rail)
		for k in range(3):
			var p: Vector3 = a.lerp(b, float(k) / 2.0) + o * 1.08
			pk.beam(kit, "white", p, p + Vector3.UP * 0.95, 0.035, 0.035, rail)
	var steps: int = maxi(int(ceil((b.y - a.y) / 0.21)), 1)
	for k in range(steps + 1):
		var p2: Vector3 = a.lerp(b, float(k) / float(steps))
		_box(pk, kit, "paint", p2 + Vector3.UP * 0.02, Basis(across, Vector3.UP, dir), Vector3(w - 0.02, 0.04, 0.24), col.darkened(0.2))


## The forecastle of a motor ship from z_from to the stem: the anchor windlass and its chains to the hawse pipes, the
## anchors in pockets on both bows, bitts, the forepeak hatch, the bow mast (folded aft unless raised), a railing round
## the bow, and the name on both bows.
static func _forecastle(pk: PropKit, kit: Dictionary, labels: Array, st: Array, hs: Dictionary, z_from: float, z_tip: float, raised: bool, ship_name: String,
		cones := 0) -> void:
	var zw: float = z_tip - 5.0
	var yw: float = float(_st_at(st, zw)[3])
	# The windlass: a body between two gypsies with brake bands, chains running forward to the hawse pipes.
	_blk(pk, kit, "paint", Vector3(-0.55, yw, zw - 0.6), Vector3(0.55, yw + 0.75, zw + 0.6), Color(0.20, 0.32, 0.26))
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "paint", Vector3(sx * 0.55, yw + 0.55, zw), Vector3(sx * 1.05, yw + 0.55, zw), 0.38, 0.38, 12, DARK, true)
		pk.tube(kit, "paint", Vector3(sx * 1.05, yw + 0.55, zw), Vector3(sx * 1.25, yw + 0.55, zw), 0.25, 0.25, 10, STEEL_GREY, true)
		_blk(pk, kit, "paint", Vector3(sx * 0.62 - 0.2, yw - 0.03, zw - 0.45), Vector3(sx * 0.62 + 0.2, yw + 0.35, zw + 0.45), Color(0.20, 0.32, 0.26))
		# The hawse pipe's deck end and the chain to it, lying on the deck.
		var hz: float = z_tip - 2.6
		var hsr: Array = _st_at(st, hz)
		var hx: float = sx * (float(hsr[0]) - 0.75)
		var hy: float = float(hsr[3])
		pk.tube(kit, "paint", Vector3(hx, hy, hz), Vector3(hx, hy + 0.12, hz), 0.3, 0.3, 10, DARK, true)
		var ca := Vector3(sx * 0.8, yw + 0.2, zw + 0.3)
		var cb := Vector3(hx, hy + 0.1, hz)
		var nlink: int = int(ca.distance_to(cb) / 0.22)
		for k in range(nlink):
			var p: Vector3 = ca.lerp(cb, (float(k) + 0.5) / float(nlink))
			var dir: Vector3 = (cb - ca).normalized()
			var flat: bool = k % 2 == 0
			_box(pk, kit, "steel", p, Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir) if flat else Basis(Vector3.UP, dir.cross(Vector3.UP).normalized(), dir).orthonormalized(),
					Vector3(0.12, 0.03, 0.2), Color(0.18, 0.16, 0.14))
		# The anchor in its pocket on the bow: a dark recess plate on the hull and the anchor's shank and flukes.
		var on: Array = _on_hull(st, z_tip - 3.3, 1.05, sx, hs["bilge"])
		var hp: Vector3 = on[0]
		var hn: Vector3 = on[1]
		var hb2 := _face_basis(hn)
		_box(pk, kit, "paint", hp + hn * 0.03, hb2, Vector3(1.3, 1.0, 0.04), Color(0.05, 0.05, 0.05))
		_box(pk, kit, "paint", hp + hn * 0.12 + hb2.y * 0.15, hb2, Vector3(0.18, 0.75, 0.16), DARK)
		_box(pk, kit, "paint", hp + hn * 0.14 - hb2.y * 0.3, hb2, Vector3(1.0, 0.22, 0.24), DARK)
		for fx in [-0.38, 0.38]:
			_box(pk, kit, "paint", hp + hn * 0.13 - hb2.y * 0.3 + hb2.x * fx + hb2.y * 0.18, hb2, Vector3(0.22, 0.42, 0.14), DARK)
	# Bitts on both sides, a forepeak hatch, the bow mast.
	for sx2 in [-1.0, 1.0]:
		for bz in [z_from + 2.5, z_tip - 1.6]:
			var s: Array = _st_at(st, bz)
			_bitts(pk, kit, Vector3(sx2 * (float(s[0]) - 0.75), float(s[3]), bz), Vector3(0, 0, 1))
	var zh: float = z_tip - 7.6
	var yh: float = float(_st_at(st, zh)[3])
	_blk(pk, kit, "paint", Vector3(-2.9, yh - 0.1, zh - 0.6), Vector3(-1.7, yh + 0.55, zh + 0.6), Color(0.20, 0.32, 0.26))
	_blk(pk, kit, "paint", Vector3(-2.95, yh + 0.55, zh - 0.65), Vector3(-1.65, yh + 0.62, zh + 0.65), Color(0.25, 0.38, 0.30))
	var zm: float = z_tip - 1.6
	var ym: float = float(_st_at(st, zm)[3])
	_blk(pk, kit, "paint", Vector3(-0.25, ym, zm - 0.25), Vector3(0.25, ym + 0.6, zm + 0.25), DARK)
	var mlen: float = minf(4.6, AIR_DRAFT - 0.35 - ym - 0.55) if (cones > 0 and not raised) else 4.6
	var ang: float = 0.0 if (raised or cones > 0) else deg_to_rad(58.0)
	var mdir := Vector3(0, cos(ang), -sin(ang))
	var mb := Vector3(0, ym + 0.55, zm)
	var mt: Vector3 = mb + mdir * mlen
	pk.tube(kit, "paint", mb, mt, 0.08, 0.055, 8, WHITE, true)
	pk.beam(kit, "paint", mb + mdir * (mlen - 0.55) + Vector3(-0.6, 0, 0), mb + mdir * (mlen - 0.55) + Vector3(0.6, 0, 0), 0.05, 0.05, WHITE, Vector3.UP)
	_nav_light(pk, kit, mt, LAMP_WHITE)
	for k in range(cones):
		_cone_signal(pk, kit, mb + mdir * (mlen - 0.6) + Vector3(0.45 - 0.9 * float(k), -0.05, 0))
	if not (raised or cones > 0):
		pk.beam(kit, "paint", Vector3(0, ym, mt.z + 0.3), Vector3(0, mt.y - 0.06, mt.z + 0.3), 0.07, 0.07, DARK)
	# The railing round the bow and the names on both bows.
	var st_pts: Array = _edge(st, z_from + 1.0, z_tip, 1.0, 0.12)
	var po_pts: Array = _edge(st, z_from + 1.0, z_tip, -1.0, 0.12)
	po_pts.reverse()
	_rail(pk, kit, st_pts + po_pts, 1.0, WHITE, "white", true)
	for sx3 in [-1.0, 1.0]:
		var zn: float = z_tip - 9.0
		var sn: Array = _st_at(st, zn)
		var yn: float = (float(hs["boot"].y) + float(sn[3]) - float(hs["stripe"])) * 0.5
		var on2: Array = _on_hull(st, zn, yn, sx3, hs["bilge"])
		_label(labels, ship_name, (on2[0] as Vector3) + (on2[1] as Vector3) * 0.03, on2[1], 0.42, WHITE, 9.0)


# ======================================================================================
#  The Gütermotorschiff
# ======================================================================================

const GMS_L := 110.0
const GMS_HB := 5.725
const GMS_T := 2.6
const GMS_YS := 1.25
const GMS_HOLD := Vector2(-35.4, 43.6)
const GMS_COAMING_X := 5.2
const GMS_COAMING_TOP := 2.5
const GMS_HOLD_FLOOR := -1.55


## A Gütermotorschiff, 110 x 11.45m, loaded (the sheer 1.25m over the water). `variant`: 0 the hold under sliding hatch
## covers, 1 containers (three tiers in the hold, two of them over the coaming: their tops at 6.2m), 2 an open hold of
## gravel heaped over the coaming with the covers stacked at its ends. Aft: the deckhouse and the wheelhouse on its column
## (lowered: its roof at 5.4m, the radar at 5.9m; `raised` 4m higher), the car and its crane, the family's things; the
## forecastle with the windlass and the anchors; the name on both bows and on the transom with the home port.
static func cargo_ship(pk: PropKit, kit: Dictionary, labels: Array, variant: int, ship_name: String, raised := false, home_port := "KRONBURG", dutch := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ship_name) + variant * 7
	var liv: Array = LIVERIES[absi(hash(ship_name)) % LIVERIES.size()]
	var top: Color = liv[0]
	var stripe: Color = liv[1]
	var trim: Color = liv[2]
	var covers: Color = liv[3]
	var hs := _scheme(top, stripe)
	var st: Array = _motor_stations(GMS_L, GMS_HB, GMS_T, GMS_YS, 1.4, 0.5)
	_hull(pk, kit, st, hs)
	var h: float = GMS_L * 0.5
	var z_front: float = GMS_HOLD.x - 0.3
	# Decks: the aft deck to the hold, the gangboards along it, the foredeck.
	var deck_col := Color(0.30, 0.33, 0.32)
	_deck(pk, kit, st, -h, GMS_HOLD.x, deck_col)
	_deck(pk, kit, st, GMS_HOLD.x, GMS_HOLD.y, deck_col, GMS_COAMING_X)
	_deck(pk, kit, st, GMS_HOLD.y, h, deck_col)
	_strake(pk, kit, st, hs, -0.04, -h + 0.6, h - 0.5, Vector2(0.14, 0.14), BLACK, true)
	_strake(pk, kit, st, hs, 0.78, -h + 4.5, h - 13.5, Vector2(0.12, 0.12), BLACK)
	var floor_y: float = NAN if variant == 0 else GMS_HOLD_FLOOR
	_coaming(pk, kit, st, GMS_HOLD.x, GMS_HOLD.y, GMS_COAMING_X, GMS_COAMING_TOP, top.lerp(Color(0.5, 0.5, 0.5), 0.15), floor_y)
	match variant:
		0:
			_hatch_covers(pk, kit, GMS_HOLD.x, GMS_HOLD.y, GMS_COAMING_X, GMS_COAMING_TOP, covers)
		1:
			_container_load(pk, kit, rng, GMS_HOLD.x + COAMING_T, GMS_HOLD.y - COAMING_T, GMS_COAMING_X - COAMING_T, GMS_HOLD_FLOOR)
		_:
			_hatch_stack(pk, kit, GMS_HOLD.x + 0.25, GMS_COAMING_X, GMS_COAMING_TOP, covers, 1.0, 9)
			_hatch_stack(pk, kit, GMS_HOLD.y - 0.25, GMS_COAMING_X, GMS_COAMING_TOP, covers, -1.0, 9)
			_heap(pk, kit, GMS_HOLD.x + 3.2, GMS_HOLD.y - 3.2, GMS_COAMING_X - COAMING_T, GMS_HOLD_FLOOR, 1.7, 3.75, Color(0.66, 0.60, 0.50), rng)
	# Bollards along the gangboards.
	for sx in [-1.0, 1.0]:
		var bz := GMS_HOLD.x + 8.0
		while bz < GMS_HOLD.y - 4.0:
			_bitts(pk, kit, Vector3(sx * (GMS_HB - 0.34), GMS_YS, bz), Vector3(0, 0, 1))
			bz += 18.0
	_quarters(pk, kit, labels, st, hs, -h, z_front, raised, trim, ship_name, home_port, dutch, rng)
	_forecastle(pk, kit, labels, st, hs, GMS_HOLD.y, h, raised, ship_name)


## The coaming plate's thickness (its inner wall that far inside its outer one).
const COAMING_T := 0.1


## The hold's coaming from z0 to z1: walls `x_out` out from the centre line up to `top` (from the gangboards' deck), a
## flange along the top the covers run on, and with `floor_y` the hold inside (its walls down to the floor, the floor).
static func _coaming(pk: PropKit, kit: Dictionary, st: Array, z0: float, z1: float, x_out: float, top: float, col: Color, floor_y: float) -> void:
	var fl := 0.12
	var xi: float = x_out - COAMING_T
	# Outer walls, their feet on the deck (which follows the sheer).
	var zs: Array = [z0]
	for row in st:
		if float(row[0]) > z0 + 0.01 and float(row[0]) < z1 - 0.01:
			zs.append(float(row[0]))
	zs.append(z1)
	for sx in [-1.0, 1.0]:
		for k in range(zs.size() - 1):
			var za: float = zs[k]
			var zb: float = zs[k + 1]
			var ya: float = float(_st_at(st, za)[3])
			var yb: float = float(_st_at(st, zb)[3])
			pk.quad(kit, "paint", [Vector3(sx * x_out, ya, za), Vector3(sx * x_out, yb, zb), Vector3(sx * x_out, top - fl, zb), Vector3(sx * x_out, top - fl, za)],
					Vector3(sx, 0, 0), col)
		_blk(pk, kit, "paint", Vector3(sx * (x_out - COAMING_T - 0.03), top - fl, z0 - 0.05), Vector3(sx * (x_out + 0.05), top, z1 + 0.05), col.darkened(0.15))
	for e in [[z0, -1.0], [z1, 1.0]]:
		var z: float = e[0]
		var sz: float = e[1]
		var yd: float = float(_st_at(st, z)[3])
		pk.quad(kit, "paint", [Vector3(-x_out, yd, z), Vector3(x_out, yd, z), Vector3(x_out, top - fl, z), Vector3(-x_out, top - fl, z)], Vector3(0, 0, sz), col)
		_blk(pk, kit, "paint", Vector3(-(x_out - COAMING_T - 0.03), top - fl, z), Vector3(x_out - COAMING_T - 0.03, top, z - sz * (COAMING_T + 0.03)), col.darkened(0.15))
	# The hold: inner walls, end walls and floor (dark), or a short skirt under the covers.
	var hold := Color(0.22, 0.23, 0.23)
	var yb2: float = (top - fl - 0.5) if is_nan(floor_y) else floor_y
	var zi0: float = z0 + COAMING_T
	var zi1: float = z1 - COAMING_T
	for sx2 in [-1.0, 1.0]:
		pk.quad(kit, "paint", [Vector3(sx2 * xi, yb2, zi1), Vector3(sx2 * xi, yb2, zi0), Vector3(sx2 * xi, top - fl, zi0), Vector3(sx2 * xi, top - fl, zi1)],
				Vector3(-sx2, 0, 0), hold)
	for e2 in [[zi0, 1.0], [zi1, -1.0]]:
		var zz: float = e2[0]
		pk.quad(kit, "paint", [Vector3(xi, yb2, zz), Vector3(-xi, yb2, zz), Vector3(-xi, top - fl, zz), Vector3(xi, top - fl, zz)], Vector3(0, 0, float(e2[1])), hold)
	if not is_nan(floor_y):
		pk.quad(kit, "paint", [Vector3(-xi, floor_y, zi0), Vector3(xi, floor_y, zi0), Vector3(xi, floor_y, zi1), Vector3(-xi, floor_y, zi1)],
				Vector3.UP, hold.darkened(0.2))


## A sliding hatch cover's section: an arched shell over the hold from -w to w, `rise` high in the middle, its edges
## resting at y0, 16cm thick at the edges (so nested covers sit one over the next, COVER_STEP apart).
const COVER_STEP := 0.2

static func _cover_outline(w: float, y0: float, rise: float) -> PackedVector2Array:
	var ol := PackedVector2Array()
	for k in range(13):
		var t: float = float(k) / 12.0
		ol.append(Vector2(lerpf(-w, w, t), y0 + (rise - 0.02) * sin(PI * t)))
	for k in range(13):
		var t: float = float(k) / 12.0
		ol.append(Vector2(lerpf(w, -w, t), y0 + 0.16 + rise * sin(PI * t)))
	return ol


## The closed hold: sliding covers about 2.6m long from z0 to z1 over the coaming, each an arched panel with a ridge
## stiffener down its edges and handles.
static func _hatch_covers(pk: PropKit, kit: Dictionary, z0: float, z1: float, x_out: float, top: float, col: Color) -> void:
	var n: int = int(round((z1 - z0) / 2.6))
	var cl: float = (z1 - z0) / float(n)
	var ol := _cover_outline(x_out + 0.12, top + 0.02, 0.42)
	for k in range(n):
		var c0: float = z0 + cl * float(k) + 0.04
		var c1: float = z0 + cl * float(k + 1) - 0.04
		var cc: Color = col if k % 2 == 0 else col.darkened(0.06)
		pk.extrude(kit, "paint", ol, c0, c1, 0.035, cc)
		for sx in [-1.0, 1.0]:
			_box(pk, kit, "paint", Vector3(sx * (x_out + 0.16), top + 0.12, (c0 + c1) * 0.5), Basis(), Vector3(0.06, 0.08, 0.3), cc.darkened(0.3))


## A stack of covers pushed together at one end of the hold: `n` panels nested one over the next, from z_end toward the
## middle (`dir` +1 from the aft end, -1 from the forward end).
static func _hatch_stack(pk: PropKit, kit: Dictionary, z_end: float, x_out: float, top: float, col: Color, dir: float, n: int) -> void:
	for k in range(n):
		var y0: float = top + 0.02 + COVER_STEP * float(k)
		var ol := _cover_outline(x_out + 0.12, y0, 0.42)
		var za: float = z_end + dir * (0.05 + 0.12 * float(k))
		var zb: float = za + dir * 2.55
		pk.extrude(kit, "paint", ol, minf(za, zb), maxf(za, zb), 0.03, col if k % 2 == 0 else col.darkened(0.07))


## A heap of bulk cargo in the hold between z0 and z1 (its edge `xi` from the centre line): along the walls at `edge_y`,
## heaped to `peak` along the middle in cones where the grab dropped it. Painted in "bulk" with `col`.
static func _heap(pk: PropKit, kit: Dictionary, z0: float, z1: float, xi: float, floor_y: float, edge_y: float, peak: float, col: Color, rng: RandomNumberGenerator) -> void:
	var nx := 10
	var nz: int = maxi(int((z1 - z0) / 1.8), 4)
	var cones: Array = []
	var zc: float = z0 + rng.randf_range(3.0, 6.0)
	while zc < z1 - 2.0:
		cones.append([zc, rng.randf_range(-0.8, 0.8), peak - rng.randf_range(0.0, 0.6)])
		zc += rng.randf_range(6.5, 10.0)
	var H := func(x: float, z: float) -> float:
		var y: float = edge_y
		for c in cones:
			var d: float = Vector2(x - float(c[1]), (z - float(c[0])) * 0.55).length()
			y = maxf(y, float(c[2]) - d * 0.62)
		var ez: float = minf(z - z0, z1 - z)
		y = minf(y, edge_y + ez * 0.7)
		y += 0.08 * sin(x * 3.1 + z * 1.7) + 0.06 * sin(z * 2.3 - x)
		return y
	var grid: Array = []
	for i in range(nz + 1):
		var row: Array = []
		var z: float = lerpf(z0, z1, float(i) / float(nz))
		for j in range(nx + 1):
			var x: float = lerpf(-xi, xi, float(j) / float(nx))
			var y: float = H.call(x, z)
			if j == 0 or j == nx:
				y = edge_y + 0.04 * sin(z * 1.3)
			row.append(Vector3(x, y, z))
		grid.append(row)
	# Smooth normals from the neighbours; the tone drifts over the heap (wetter and darker low down, sun-bleached on top).
	var nrm: Array = []
	for i in range(nz + 1):
		var nr: Array = []
		for j in range(nx + 1):
			var px: Vector3 = (grid[i][mini(j + 1, nx)] as Vector3) - (grid[i][maxi(j - 1, 0)] as Vector3)
			var pz: Vector3 = (grid[mini(i + 1, nz)][j] as Vector3) - (grid[maxi(i - 1, 0)][j] as Vector3)
			var nv: Vector3 = pz.cross(px).normalized()
			if nv.y < 0.0:
				nv = -nv
			nr.append(nv)
		nrm.append(nr)
	var tone := func(p: Vector3) -> Color:
		var t: float = clampf((p.y - edge_y) / maxf(peak - edge_y, 0.1), 0.0, 1.0)
		var wob: float = 0.5 + 0.25 * sin(p.x * 1.7 + p.z * 0.45) + 0.25 * sin(p.z * 1.1 - p.x * 0.6)
		return col.darkened(0.22 * (1.0 - t)).lerp(col.lightened(0.08), wob * 0.35)
	for i in range(nz):
		for j in range(nx):
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j + 1]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i + 1][j]
			var na: Vector3 = nrm[i][j]
			var nb: Vector3 = nrm[i][j + 1]
			var nc: Vector3 = nrm[i + 1][j + 1]
			var nd: Vector3 = nrm[i + 1][j]
			var o: Vector3 = (na + nb + nc + nd).normalized()
			pk.tri(kit, "bulk", a, b, c, na, nb, nc, tone.call((a + b + c) / 3.0), o)
			pk.tri(kit, "bulk", a, c, d, na, nc, nd, tone.call((a + c + d) / 3.0), o)
	# The heap's ends slope down to the hold's floor (the hold walls beyond them).
	for e in [[0, -1.0], [nz, 1.0]]:
		var row2: Array = grid[e[0]]
		var zz: float = (row2[0] as Vector3).z
		var zf: float = zz + float(e[1]) * 2.5
		for j in range(nx):
			var a2: Vector3 = row2[j]
			var b2: Vector3 = row2[j + 1]
			var n2 := Vector3(0, 1.0, float(e[1]) * 0.8).normalized()
			pk.quad(kit, "bulk", [a2, b2, Vector3(b2.x, floor_y + 0.5, zf), Vector3(a2.x, floor_y + 0.5, zf)], n2, col.darkened(0.1))


## Containers in the hold from z0 to z1, four across (`xi` the hold's half width), three tiers from `floor_y`: the bottom
## tier plain, the upper two with corner posts, rails and the doors' bars (the top tier). A few stacks are a tier lower and
## the last bays are twenties.
static func _container_load(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, z0: float, z1: float, xi: float, floor_y: float) -> void:
	var bays: Array = []
	var z: float = z0 + 0.4
	while z + BOX_40.x <= z1 - 0.2:
		bays.append([z, BOX_40])
		z += BOX_40.x + 0.35
	while z + BOX_20.x <= z1 - 0.2:
		bays.append([z, BOX_20])
		z += BOX_20.x + 0.3
	var pitch: float = (xi * 2.0 - 0.1) / 4.0
	for b in bays:
		var bz: float = b[0]
		var size: Vector3 = b[1]
		for col_i in range(4):
			var x: float = -xi + 0.05 + pitch * (float(col_i) + 0.5)
			var tiers: int = 3 if rng.randf() < 0.82 else 2
			for t in range(tiers):
				var p := Vector3(x, floor_y + (BOX_40.y + 0.005) * float(t), bz + size.x * 0.5)
				var paint: Color = BOX_PAINTS[rng.randi() % BOX_PAINTS.size()]
				_box_container(pk, kit, p, size, paint, rng.randf(), t)


## A container standing on `c` (the middle of its floor), its length along z, painted `col`; `detail` 0 plain (walls and
## roof), 1 with corner posts and top rails, 2 also the door end's locking bars (at -z) and castings.
static func _box_container(pk: PropKit, kit: Dictionary, c: Vector3, size: Vector3, col: Color, seed_v: float, detail: int) -> void:
	var hl: float = size.x * 0.5
	var hw: float = size.z * 0.5
	var h: float = size.y
	var paint := Color(col.r, col.g, col.b, seed_v)
	var ins := 0.04
	for sx in [-1.0, 1.0]:
		var x: float = c.x + sx * (hw - ins)
		pk.quad(kit, "container", [Vector3(x, c.y, c.z - hl), Vector3(x, c.y, c.z + hl), Vector3(x, c.y + h, c.z + hl), Vector3(x, c.y + h, c.z - hl)], Vector3(sx, 0, 0), paint,
				[Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, h), Vector2(0, h)])
	for sz in [-1.0, 1.0]:
		var z: float = c.z + sz * (hl - ins)
		var f: float = 100.0 if sz < 0.0 else 200.0
		pk.quad(kit, "container", [Vector3(c.x - hw, c.y, z), Vector3(c.x + hw, c.y, z), Vector3(c.x + hw, c.y + h, z), Vector3(c.x - hw, c.y + h, z)], Vector3(0, 0, sz), paint,
				[Vector2(f, 0), Vector2(f + size.z, 0), Vector2(f + size.z, h), Vector2(f, h)])
	pk.quad(kit, "container", [Vector3(c.x - hw, c.y + h - 0.02, c.z - hl), Vector3(c.x + hw, c.y + h - 0.02, c.z - hl), Vector3(c.x + hw, c.y + h - 0.02, c.z + hl),
			Vector3(c.x - hw, c.y + h - 0.02, c.z + hl)], Vector3.UP, paint, [Vector2(300, 0), Vector2(300 + size.z, 0), Vector2(300 + size.z, size.x), Vector2(300, size.x)])
	if detail < 1:
		return
	var frame: Color = col.darkened(0.3)
	for sx2 in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(c.x + sx2 * hw - (0.1 if sx2 > 0.0 else 0.0), c.y + h - 0.16, c.z - hl + 0.1), Vector3(c.x + sx2 * hw + (0.0 if sx2 > 0.0 else 0.1), c.y + h, c.z + hl - 0.1), frame)
	for sx3 in [-1.0, 1.0]:
		for sz3 in [-1.0, 1.0]:
			var px: float = c.x + sx3 * (hw - 0.08)
			var pz: float = c.z + sz3 * (hl - 0.08)
			pk.block(kit, "steel", Vector3(px - 0.085, c.y + 0.0, pz - 0.085), Vector3(px + 0.085, c.y + h + 0.025, pz + 0.085), frame.darkened(0.2))
	if detail < 2:
		return
	var zd: float = c.z - hl + ins - 0.045
	for k in range(4):
		var xx: float = c.x + [-0.85, -0.42, 0.42, 0.85][k] * hw
		pk.beam(kit, "steel", Vector3(xx, c.y + 0.25, zd), Vector3(xx, c.y + h - 0.25, zd), 0.04, 0.04, frame)
		pk.beam(kit, "steel", Vector3(xx, c.y + 1.1, zd - 0.03), Vector3(xx + (0.25 if k % 2 == 0 else -0.25), c.y + 1.1, zd - 0.03), 0.04, 0.035, frame)


# ======================================================================================
#  The Tankmotorschiff
# ======================================================================================

const TMS_L := 86.0
const TMS_HB := 5.725


## A Tankmotorschiff, 86 x 11.45m, a red hull loaded deep (the sheer 1.3m over the water): a flat cargo deck with the
## cargo and vapour lines, tank domes and their vent valves, the manifold amidships with its hose crane, a raised walkway
## on the centre line from the quarters to the forecastle, railings along the sides; aft quarters and the lowered
## wheelhouse as on the cargo ship (no car: tankers keep it ashore); a blue cone on the bow mast and on the wheelhouse.
static func tanker(pk: PropKit, kit: Dictionary, labels: Array, ship_name: String, raised := false, home_port := "VENNHOVEN") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(ship_name) + 31
	var red := Color(0.62, 0.10, 0.08)
	var hs := _scheme(red, WHITE, BLACK, Color(0.18, 0.08, 0.07))
	var ys := 1.3
	var st: Array = _motor_stations(TMS_L, TMS_HB, 2.7, ys, 1.3, 0.45)
	_hull(pk, kit, st, hs)
	var h: float = TMS_L * 0.5
	var z_front := -25.0
	var z_fore := 34.0
	_deck(pk, kit, st, -h, h, Color(0.45, 0.17, 0.12))
	_strake(pk, kit, st, hs, -0.04, -h + 0.6, h - 0.5, Vector2(0.14, 0.14), BLACK, true)
	_strake(pk, kit, st, hs, 0.82, -h + 4.5, h - 13.5, Vector2(0.12, 0.12), BLACK)
	var pipe := Color(0.86, 0.86, 0.82)
	var zt0: float = z_front + 1.5
	var zt1: float = z_fore - 1.0
	# The lines: cargo (bigger, starboard of the walkway) and vapour return, on saddles every 3m.
	for ln in [[1.25, 0.13, pipe], [1.75, 0.09, Color(0.85, 0.75, 0.25)], [-1.4, 0.07, Color(0.30, 0.50, 0.75)]]:
		var lx: float = ln[0]
		var lr: float = ln[1]
		var ly: float = ys + 0.5
		pk.tube(kit, "paint", Vector3(lx, ly, zt0), Vector3(lx, ly, zt1), lr, lr, 8, ln[2], true)
		var sz := zt0 + 1.0
		while sz < zt1:
			_blk(pk, kit, "paint", Vector3(lx - 0.12, ys, sz - 0.06), Vector3(lx + 0.12, ly - lr * 0.6, sz + 0.06), Color(0.3, 0.3, 0.3))
			sz += 3.0
	# Tank domes and vent valves: eight tanks.
	var nt := 8
	var tl: float = (zt1 - zt0) / float(nt)
	for k in range(nt):
		var tz: float = zt0 + tl * (float(k) + 0.5)
		pk.tube(kit, "paint", Vector3(-2.4, ys, tz), Vector3(-2.4, ys + 0.45, tz), 0.5, 0.5, 12, pipe, false)
		pk.tube(kit, "paint", Vector3(-2.4, ys + 0.45, tz), Vector3(-2.4, ys + 0.53, tz), 0.56, 0.56, 12, pipe.darkened(0.15), true)
		pk.tube(kit, "paint", Vector3(-2.4, ys + 0.53, tz), Vector3(-2.4, ys + 0.62, tz), 0.12, 0.12, 6, DARK, true)
		# The drop from the cargo line into the tank.
		pk.tube(kit, "paint", Vector3(1.25, ys + 0.5, tz + 1.2), Vector3(1.25, ys, tz + 1.2), 0.09, 0.09, 6, pipe, false)
		_blk(pk, kit, "paint", Vector3(1.05, ys + 0.2, tz + 1.03), Vector3(1.45, ys + 0.38, tz + 1.37), Color(0.12, 0.45, 0.20))
		# The high-velocity vent valve on its riser.
		pk.tube(kit, "paint", Vector3(-3.6, ys, tz), Vector3(-3.6, ys + 1.6, tz), 0.07, 0.07, 6, pipe, false)
		pk.lathe(kit, "paint", Vector3(-3.6, ys + 1.6, tz), [Vector2(0.001, 0.0), Vector2(0.16, 0.0), Vector2(0.12, 0.35), Vector2(0.001, 0.4)], 8, Color(0.85, 0.15, 0.10), true)
		# Spray line nozzles along the deck edge.
		for sx in [-1.0, 1.0]:
			pk.tube(kit, "paint", Vector3(sx * (TMS_HB - 0.5), ys, tz), Vector3(sx * (TMS_HB - 0.5), ys + 0.5, tz), 0.03, 0.03, 4, pipe, true)
	for sx2 in [-1.0, 1.0]:
		pk.tube(kit, "paint", Vector3(sx2 * (TMS_HB - 0.5), ys + 0.5, zt0), Vector3(sx2 * (TMS_HB - 0.5), ys + 0.5, zt1), 0.04, 0.04, 4, pipe, true)
	# The manifold amidships: lines across the deck to both sides, valves, drip trays, the hose crane.
	var zm := 3.0
	for k2 in range(3):
		var mz: float = zm + 0.7 * float(k2)
		var my: float = ys + 0.85
		pk.tube(kit, "paint", Vector3(-TMS_HB + 0.9, my, mz), Vector3(TMS_HB - 0.9, my, mz), 0.11, 0.11, 8, pipe if k2 != 1 else Color(0.85, 0.75, 0.25), true)
		for sx3 in [-1.0, 1.0]:
			pk.tube(kit, "paint", Vector3(sx3 * (TMS_HB - 0.9), my, mz), Vector3(sx3 * (TMS_HB - 0.82), my, mz), 0.2, 0.2, 10, DARK, true)
			_blk(pk, kit, "paint", Vector3(sx3 * 2.6 - 0.2, my - 0.2, mz - 0.2), Vector3(sx3 * 2.6 + 0.2, my + 0.2, mz + 0.2), Color(0.2, 0.2, 0.22))
			pk.tube(kit, "paint", Vector3(sx3 * 2.6, my + 0.2, mz), Vector3(sx3 * 2.6, my + 0.55, mz), 0.03, 0.03, 4, DARK, false)
			_ring(pk, kit, "paint", Vector3(sx3 * 2.6, my + 0.58, mz), Vector3.UP, 0.16, 0.035, 8, Color(0.85, 0.12, 0.10))
		pk.tube(kit, "paint", Vector3(1.25, ys + 0.5, mz), Vector3(1.25, my, mz), 0.09, 0.09, 6, pipe, false)
	for sx4 in [-1.0, 1.0]:
		_blk(pk, kit, "paint", Vector3(sx4 * (TMS_HB - 0.4), ys, zm - 0.9), Vector3(sx4 * (TMS_HB - 1.8), ys + 0.3, zm + 2.3), Color(0.3, 0.32, 0.32))
	var cf := Vector3(-4.3, ys, zm + 4.2)
	pk.tube(kit, "paint", cf, cf + Vector3(0, 2.2, 0), 0.22, 0.18, 10, CRANE_YELLOW, true)
	var ctip: Vector3 = cf + Vector3(0, 2.2, 0) + Vector3(0, 4.2 * sin(0.6), -4.2 * cos(0.6))
	pk.beam(kit, "paint", cf + Vector3(0, 2.2, 0), ctip, 0.24, 0.26, CRANE_YELLOW, Vector3.UP)
	pk.beam(kit, "steel", ctip, ctip - Vector3(0, 1.5, 0), 0.02, 0.02, DARK)
	_box(pk, kit, "paint", ctip - Vector3(0, 1.6, 0), Basis(), Vector3(0.2, 0.25, 0.14), DARK)
	# The walkway: a grating on posts 1.55m over the deck from the quarters to the forecastle, railed, with stairs.
	var wy: float = ys + 1.55
	var wz0: float = z_front + 0.4
	var wz1: float = z_fore + 1.5
	_blk(pk, kit, "paint", Vector3(-0.5, wy - 0.08, wz0), Vector3(0.5, wy, wz1), Color(0.18, 0.40, 0.25))
	var pz := wz0 + 0.3
	while pz < wz1:
		for sx5 in [-0.42, 0.42]:
			pk.beam(kit, "paint", Vector3(sx5, ys, pz), Vector3(sx5, wy - 0.08, pz), 0.08, 0.08, Color(0.18, 0.40, 0.25))
		pz += 3.0
	for sx6 in [-0.48, 0.48]:
		_rail(pk, kit, [Vector3(sx6, wy, wz0), Vector3(sx6, wy, wz1)], 1.0, WHITE, "white")
	_stair(pk, kit, Vector3(3.0, ys, -10.0), Vector3(0.55, wy - 0.05, -10.0), 0.6)
	# Railings along both sides of the cargo deck, lifebuoys on them, deck lamps on the walkway.
	for sx7 in [-1.0, 1.0]:
		_rail(pk, kit, _edge(st, z_front - 0.5, z_fore - 0.5, sx7, 0.12), 1.0, WHITE, "white")
		_lifebuoy(pk, kit, Vector3(sx7 * (TMS_HB - 0.08), ys + 0.6, -6.0), Vector3(sx7, 0, 0))
	for lz in [-15.0, 0.0, 15.0, 28.0]:
		pk.beam(kit, "paint", Vector3(0.45, wy + 1.0, lz), Vector3(0.45, wy + 2.0, lz), 0.05, 0.05, WHITE)
		_box(pk, kit, "lens", Vector3(0.45, wy + 2.05, lz), Basis(), Vector3(0.3, 0.12, 0.2), LAMP_WHITE)
	_quarters(pk, kit, labels, st, hs, -h, z_front, raised, Color(0.62, 0.10, 0.08), ship_name, home_port, false, rng, 1, false)
	_forecastle(pk, kit, labels, st, hs, z_fore, h, raised, ship_name, 1)


# ======================================================================================
#  The push convoy
# ======================================================================================

const BARGE_L := 76.5
const BARGE_HB := 5.7
const PUSHER_L := 35.0
const CONVOY_GAP := 0.25


## The convoy's length over all: `barges` Europa IIa barges and the pusher.
static func convoy_length(barges: int) -> float:
	var n: int = clampi(barges, 1, 2)
	return BARGE_L * float(n) + PUSHER_L + CONVOY_GAP * float(n)


## A push convoy: a Schubboot (35 x 11.4m, its wheelhouse on a column, the push knees at its bow) pushing 1 or 2
## Schubleichter (76.5 x 11.4m, loaded with iron ore heaped over their coamings) in line ahead. The convoy's front (the
## first barge's raked bow) is at +convoy_length / 2, the pusher's stern at -convoy_length / 2. 188m with two barges,
## 111.75m with one.
static func push_convoy(pk: PropKit, kit: Dictionary, labels: Array, barges: int, raised := false) -> void:
	var n: int = clampi(barges, 1, 2)
	var total: float = convoy_length(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711 + n
	var front: float = total * 0.5
	for k in range(n):
		var zc: float = front - BARGE_L * 0.5 - (BARGE_L + CONVOY_GAP) * float(k)
		var saved := _push(pk, Transform3D(Basis(), Vector3(0, 0, zc)))
		_barge(pk, kit, labels, "KRB %d" % (2104 + k * 17), k == 0, rng)
		_pop(pk, saved)
		# The coupling wires at the joint behind this barge: crossed, from the winch drums to the next unit's bitts.
		var zj: float = zc - BARGE_L * 0.5 - CONVOY_GAP * 0.5
		var yr: float = 1.0 if k < n - 1 else 2.0
		for sx in [-1.0, 1.0]:
			var a := Vector3(sx * 3.4, 1.55, zj + 1.9)
			var b := Vector3(sx * (BARGE_HB - 0.45) if k < n - 1 else sx * 4.8, yr + 0.45, zj - (2.4 if k < n - 1 else 2.6))
			pk.beam(kit, "steel", a, b, 0.035, 0.035, DARK)
			pk.beam(kit, "steel", a, Vector3(-b.x * 0.55, b.y, b.z), 0.035, 0.035, DARK)
	var zp: float = -total * 0.5 + PUSHER_L * 0.5
	var saved2 := _push(pk, Transform3D(Basis(), Vector3(0, 0, zp)))
	_pusher(pk, kit, labels, raised, rng)
	_pop(pk, saved2)


## A Europa IIa barge in its own frame (centred, bow +z): a box hull with a raked bow and a square stern, black, loaded
## deep; the coaming 1m over the gangboards, ore heaped in it; bitts and coupling winches at the corners. `first`: the
## convoy's front barge, with the bow light post.
static func _barge(pk: PropKit, kit: Dictionary, labels: Array, number: String, first: bool, rng: RandomNumberGenerator) -> void:
	var h: float = BARGE_L * 0.5
	var ys := 1.0
	var st: Array = [
		[-h, BARGE_HB, BARGE_HB - 0.05, -3.0, ys],
		[h - 6.5, BARGE_HB, BARGE_HB, -3.0, ys],
		[h - 4.2, BARGE_HB, BARGE_HB, -1.65, ys + 0.04],
		[h - 2.0, BARGE_HB, BARGE_HB - 0.03, -0.35, ys + 0.1],
		[h - 0.5, BARGE_HB - 0.04, BARGE_HB - 0.1, 0.55, ys + 0.17],
		[h, BARGE_HB - 0.12, BARGE_HB - 0.2, 1.0, ys + 0.2],
	]
	var hs := _scheme(Color(0.08, 0.08, 0.09), Color(0.08, 0.08, 0.09), Color(0.10, 0.10, 0.10), Color(0.30, 0.13, 0.09), Vector2(0.25, 0.45), 0.2, 0.3)
	_hull(pk, kit, st, hs)
	var zh0: float = -h + 2.6
	var zh1: float = h - 5.0
	var deck := Color(0.24, 0.24, 0.23)
	_deck(pk, kit, st, -h, zh0, deck)
	_deck(pk, kit, st, zh0, zh1, deck, 4.8)
	_deck(pk, kit, st, zh1, h, deck)
	_strake(pk, kit, st, hs, -0.04, -h, h - 0.3, Vector2(0.12, 0.12), Color(0.02, 0.02, 0.02), true)
	_coaming(pk, kit, st, zh0, zh1, 4.8, ys + 0.95, Color(0.10, 0.10, 0.11), -2.4)
	_heap(pk, kit, zh0 + 1.0, zh1 - 1.0, 4.8 - COAMING_T, -2.4, ys + 0.55, ys + 2.3, Color(0.33, 0.21, 0.17), rng)
	for sx in [-1.0, 1.0]:
		for bz in [-h + 1.2, h - 2.6, 0.0]:
			_bitts(pk, kit, Vector3(sx * (BARGE_HB - 0.45), float(_st_at(st, bz)[3]), bz), Vector3(0, 0, 1))
		# Coupling winches at the stern corners: a drum on a frame.
		var wz: float = -h + 2.2
		_blk(pk, kit, "paint", Vector3(sx * 3.4 - 0.4, ys, wz - 0.4), Vector3(sx * 3.4 + 0.4, ys + 0.3, wz + 0.4), Color(0.18, 0.18, 0.2))
		pk.tube(kit, "paint", Vector3(sx * 3.4 - 0.35, ys + 0.55, wz), Vector3(sx * 3.4 + 0.35, ys + 0.55, wz), 0.25, 0.25, 10, CRANE_YELLOW.darkened(0.2), true)
		_label(labels, number, Vector3(sx * (BARGE_HB + 0.03), 0.62, -h + 6.0), Vector3(sx, 0, 0), 0.32, WHITE, 4.0)
	if first:
		var lz: float = h - 1.4
		var ly: float = float(_st_at(st, lz)[3])
		pk.beam(kit, "paint", Vector3(0, ly, lz), Vector3(0, ly + 3.2, lz), 0.1, 0.1, WHITE)
		_nav_light(pk, kit, Vector3(0, ly + 3.2, lz), LAMP_WHITE)
		_nav_light(pk, kit, Vector3(BARGE_HB - 0.3, ly + 0.9, lz - 0.5), SIGNAL_GREEN, Vector3(0.3, 0, 1))
		_nav_light(pk, kit, Vector3(-BARGE_HB + 0.3, ly + 0.9, lz - 0.5), SIGNAL_RED, Vector3(-0.3, 0, 1))
		for sx2 in [-1.0, 1.0]:
			pk.beam(kit, "paint", Vector3(sx2 * (BARGE_HB - 0.3), ly, lz - 0.5), Vector3(sx2 * (BARGE_HB - 0.3), ly + 0.85, lz - 0.5), 0.06, 0.06, WHITE)


## The pusher in its own frame (centred, its push bow at +z): a beamy hull with a square bow, two push knees, the
## deckhouse, the wheelhouse on its column (lowered: its roof at 6.4m), exhausts, a workboat on the aft deck.
static func _pusher(pk: PropKit, kit: Dictionary, labels: Array, raised: bool, rng: RandomNumberGenerator) -> void:
	var h: float = PUSHER_L * 0.5
	var hb := 5.7
	var ys := 2.0
	var st: Array = [
		[-h, hb * 0.66, hb * 0.6, 0.4, ys + 0.35],
		[-h + 0.6, hb * 0.86, hb * 0.8, 0.0, ys + 0.3],
		[-h + 1.8, hb * 0.96, hb * 0.92, -0.9, ys + 0.2],
		[-h + 3.5, hb, hb * 0.98, -1.8, ys + 0.08],
		[h - 3.0, hb, hb, -1.8, ys],
		[h - 1.4, hb, hb * 0.98, -1.0, ys + 0.02],
		[h - 0.3, hb, hb * 0.95, -0.1, ys + 0.05],
		[h, hb * 0.99, hb * 0.93, 0.25, ys + 0.06],
	]
	var hs := _scheme(Color(0.10, 0.18, 0.36), Color(0.88, 0.62, 0.12), BLACK, ANTIFOUL, Vector2(0.3, 0.6), 0.28, 0.5)
	_hull(pk, kit, st, hs)
	_deck(pk, kit, st, -h, h, Color(0.30, 0.33, 0.32))
	_strake(pk, kit, st, hs, -0.05, -h + 0.3, h - 0.1, Vector2(0.16, 0.16), BLACK, true)
	_strake(pk, kit, st, hs, 1.0, -h + 3.0, h - 0.5, Vector2(0.14, 0.14), BLACK)
	# The push knees at the bow: steel towers with timber fenders on their faces.
	for sx in [-1.0, 1.0]:
		var kx: float = sx * 3.4
		_blk(pk, kit, "paint", Vector3(kx - 0.55, ys, h - 1.4), Vector3(kx + 0.55, ys + 1.9, h - 0.05), Color(0.10, 0.18, 0.36))
		_blk(pk, kit, "timber", Vector3(kx - 0.4, ys - 1.0, h - 0.06), Vector3(kx + 0.4, ys + 1.85, h + 0.2), TIMBER.darkened(0.3))
		_bitts(pk, kit, Vector3(sx * 4.8, ys + 0.06, h - 2.8), Vector3(0, 0, 1))
		# The coupling winch behind the knee.
		pk.tube(kit, "paint", Vector3(kx - 0.4, ys + 0.5, h - 3.6), Vector3(kx + 0.4, ys + 0.5, h - 3.6), 0.3, 0.3, 10, CRANE_YELLOW.darkened(0.2), true)
		_blk(pk, kit, "paint", Vector3(kx - 0.5, ys, h - 4.0), Vector3(kx + 0.5, ys + 0.25, h - 3.2), DARK)
	# The deckhouse.
	var z0: float = -h + 6.5
	var z1: float = h - 9.5
	var xh := 4.6
	var yr: float = ys + 2.5
	var white := WHITE
	for w in [[Vector3(xh, ys, z0), Vector3(xh, ys, z1), Vector3(1, 0, 0)], [Vector3(-xh, ys, z1), Vector3(-xh, ys, z0), Vector3(-1, 0, 0)],
			[Vector3(xh, ys, z1), Vector3(-xh, ys, z1), Vector3(0, 0, 1)], [Vector3(-xh, ys, z0), Vector3(xh, ys, z0), Vector3(0, 0, -1)]]:
		var a: Vector3 = w[0]
		var b: Vector3 = w[1]
		pk.quad(kit, "white", [a, b, Vector3(b.x, yr - 0.3, b.z), Vector3(a.x, yr - 0.3, a.z)], w[2], white)
		pk.quad(kit, "paint", [Vector3(a.x, yr - 0.3, a.z), Vector3(b.x, yr - 0.3, b.z), Vector3(b.x, yr, b.z), Vector3(a.x, yr, a.z)], w[2], Color(0.10, 0.18, 0.36))
	_slab(pk, kit, Vector3(-xh - 0.12, yr, z0 - 0.12), Vector3(xh + 0.12, yr + 0.14, z1 + 0.12), "white", OFFWHITE, "deck", Color(0.42, 0.46, 0.44))
	_rail(pk, kit, [Vector3(-xh, yr + 0.14, z1 - 0.1), Vector3(-xh, yr + 0.14, z0 + 0.1), Vector3(xh, yr + 0.14, z0 + 0.1), Vector3(xh, yr + 0.14, z1 - 0.1)], 0.95)
	for sx2 in [-1.0, 1.0]:
		var nwin := 4
		for k in range(nwin):
			var wz: float = z0 + 1.2 + (z1 - z0 - 2.4) * (float(k) + 0.5) / float(nwin)
			_window(pk, kit, Vector3(sx2 * xh, ys + 1.45, wz), Vector3(0, 0, -sx2), Vector3(sx2, 0, 0), 1.2, 0.8, _curtain(rng))
	for wx in [-2.6, 2.6]:
		_window(pk, kit, Vector3(wx, ys + 1.45, z1), Vector3(1, 0, 0), Vector3(0, 0, 1), 1.2, 0.8, _curtain(rng))
		_window(pk, kit, Vector3(wx, ys + 1.45, z0), Vector3(-1, 0, 0), Vector3(0, 0, -1), 1.2, 0.8, _curtain(rng))
	# Exhausts aft on the roof.
	for ex in [-1.2, 1.2]:
		pk.tube(kit, "paint", Vector3(ex, yr + 0.14, z0 + 1.0), Vector3(ex, yr + 1.6, z0 + 1.0), 0.22, 0.2, 10, Color(0.10, 0.18, 0.36), false)
		pk.tube(kit, "paint", Vector3(ex, yr + 1.6, z0 + 1.0), Vector3(ex, yr + 1.75, z0 + 1.0), 0.24, 0.24, 10, BLACK, true)
	# The wheelhouse on its column in front of the deckhouse (higher than a motor ship's: it looks over the barges).
	var wb := Vector3(0, ys, h - 7.5)
	_wheelhouse(pk, kit, labels, wb, yr, raised, Color(0.10, 0.18, 0.36), yr + 0.14, z0, z1)
	# The aft deck: a workboat in chocks, bitts, the railing, the flag.
	var bz: float = -h + 3.0
	_workboat(pk, kit, Vector3(0, float(_st_at(st, bz)[3]), bz))
	for sx3 in [-1.0, 1.0]:
		_bitts(pk, kit, Vector3(sx3 * 4.3, float(_st_at(st, -h + 1.0)[3]), -h + 1.0), Vector3(0, 0, 1))
	var rp: Array = _edge(st, -h + 0.05, h - 4.6, 1.0, 0.1)
	rp.reverse()
	_rail(pk, kit, rp + _edge(st, -h + 0.05, h - 4.6, -1.0, 0.1), 1.0, WHITE, "white", true)
	_flag_staff(pk, kit, Vector3(0, float(_st_at(st, -h)[3]), -h + 0.25), 2.4, Vector3(-0.3, 0, -1), false)
	_label(labels, "KRONBURG IV", Vector3(0, ys - 0.2, -h - 0.03), Vector3(0, 0, -1), 0.34, WHITE, 6.0)
	for sx4 in [-1.0, 1.0]:
		var on: Array = _on_hull(st, h - 5.0, 1.2, sx4, hs["bilge"])
		_label(labels, "KRONBURG IV", (on[0] as Vector3) + (on[1] as Vector3) * 0.03, on[1], 0.4, WHITE, 7.0)


## A small workboat (5m, open, an outboard) on chocks at `p`, its bow toward +z.
static func _workboat(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	var rows: Array = []
	for k in range(7):
		var t: float = float(k) / 6.0
		var z: float = lerpf(-2.4, 2.5, t)
		var w: float = 0.95 * (1.0 - pow(maxf(t - 0.55, 0.0) / 0.45, 2.0) * 0.85)
		var yb: float = 0.1 + 0.35 * pow(maxf(t - 0.6, 0.0) / 0.4, 1.5)
		rows.append([z, w, w * 0.7, yb, 0.85 + 0.15 * t])
	var hs := _scheme(Color(0.92, 0.45, 0.10), Color(0.92, 0.45, 0.10), Color(0.92, 0.45, 0.10), Color(0.92, 0.45, 0.10), Vector2(0.2, 0.3), 0.1, 0.15, "paint")
	var saved := _push(pk, Transform3D(Basis(), p + Vector3(0, 0.35, 0)))
	_hull(pk, kit, rows, hs)
	_deck(pk, kit, rows, -2.4, 2.5, Color(0.80, 0.80, 0.76), 0.0, "white", -0.35)
	_blk(pk, kit, "matte", Vector3(-0.18, 0.5, -2.55), Vector3(0.18, 1.1, -2.25), DARK)
	for cz in [-1.5, 1.2]:
		_blk(pk, kit, "timber", Vector3(-0.9, -0.35, cz - 0.15), Vector3(0.9, 0.15, cz + 0.15), TIMBER)
	_pop(pk, saved)


# ======================================================================================
#  The excursion ship
# ======================================================================================

const EX_L := 70.0
const EX_HB := 5.25
const EX_DECK := 1.0
const EX_UPPER := 3.2
const EX_SUN := 5.35
const EX_SALOON := Vector2(-26.0, 22.0)
const EX_UPPER_SALOON := Vector2(-18.0, 16.0)
const EX_WALL := 4.45
const EX_CANOPY := Vector2(-17.6, -7.0)


static func _ex_stations() -> Array:
	var hb := EX_HB
	return [
		[-35.0, hb * 0.6, hb * 0.55, 0.45, 1.3],
		[-34.4, hb * 0.82, hb * 0.74, 0.1, 1.27],
		[-33.2, hb * 0.94, hb * 0.88, -0.6, 1.22],
		[-31.5, hb * 0.99, hb * 0.95, -1.3, 1.15],
		[-28.5, hb, hb * 0.99, -1.6, 1.08],
		[-24.0, hb, hb, -1.7, EX_DECK],
		[20.0, hb, hb, -1.7, EX_DECK],
		[25.0, hb * 0.99, hb * 0.95, -1.7, 1.07],
		[28.5, hb * 0.92, hb * 0.8, -1.55, 1.25],
		[31.5, hb * 0.76, hb * 0.58, -1.05, 1.5],
		[33.5, hb * 0.55, hb * 0.34, -0.3, 1.72],
		[34.6, hb * 0.32, hb * 0.15, 0.5, 1.85],
		[35.0, hb * 0.14, hb * 0.06, 1.1, 1.9],
	]


## The white excursion ship of the Kronburger Rheinflotte, 70 x 10.5m: a white hull with a navy boot band, two enclosed
## passenger decks with big windows (the main saloon on the main deck from 1.0 to 3.2m, the upper saloon from 3.2 to
## 5.35m), side decks with railings, open decks at the bow and aft, an aft terrace on the upper deck, the sun deck on top
## (5.37m) with benches, tables and a canopy over its aft part (its ridge at 7.17m; `raised` 7.75m), the wheelhouse
## forward on it (lowered into the upper saloon: its roof at 6.95m, the radar at 7.1m; raised 0.85m higher), a
## funnel-shaped mast (6.9m), lifebuoys, the gangway doors on both sides at z 8 (gaps in the railings from z 6.8 to 9.2),
## and the name on the bows, the stern and the wheelhouse, the line's name along the upper saloon.
static func excursion_ship(pk: PropKit, kit: Dictionary, labels: Array, ship_name: String, raised := false) -> void:
	var st: Array = _ex_stations()
	var navy := Color(0.08, 0.14, 0.34)
	var accent := Color(0.75, 0.10, 0.12)
	var hs := _scheme(WHITE, navy, navy, Color(0.30, 0.10, 0.08), Vector2(0.18, 0.5), 0.16, 0.6)
	_hull(pk, kit, st, hs)
	var h: float = EX_L * 0.5
	_deck(pk, kit, st, -h, h, Color(0.52, 0.55, 0.55))
	_strake(pk, kit, st, hs, -0.03, -h + 0.5, h - 0.4, Vector2(0.12, 0.1), navy, true)
	var wl := EX_WALL
	# Main deck: the saloon with its window band, doors fore and aft and the gangway doors.
	_saloon(pk, kit, EX_SALOON.x, EX_SALOON.y, wl, EX_DECK, EX_UPPER - 0.15, 1.85, 2.8, [8.0], navy)
	# The upper deck: a slab over the saloon and the side decks (planked on top), a navy fascia round its edge, posts
	# under its overhang along the side decks.
	var u0: float = EX_SALOON.x - 4.0
	var u1: float = EX_SALOON.y
	_slab(pk, kit, Vector3(-EX_HB + 0.05, EX_UPPER - 0.15, u0), Vector3(EX_HB - 0.05, EX_UPPER, u1), "white", WHITE, "lapboards", Color(0.74, 0.62, 0.46))
	_blk(pk, kit, "paint", Vector3(-EX_HB + 0.02, EX_UPPER - 0.13, u0 - 0.03), Vector3(EX_HB - 0.02, EX_UPPER - 0.02, u1 + 0.03), navy)
	for sx in [-1.0, 1.0]:
		var pz: float = u0 + 0.4
		while pz < u1:
			if absf(pz - 8.0) > 1.4:
				pk.tube(kit, "white", Vector3(sx * (EX_HB - 0.3), EX_DECK, pz), Vector3(sx * (EX_HB - 0.3), EX_UPPER - 0.15, pz), 0.05, 0.05, 6, WHITE, false)
			pz += 4.0
	# The upper saloon.
	_saloon(pk, kit, EX_UPPER_SALOON.x, EX_UPPER_SALOON.y, wl, EX_UPPER, EX_SUN - 0.15, 3.75, 4.75, [], navy)
	# Railings on the main deck: the sides (gaps at the gangway doors, a chain across), the stern, round the bow.
	# One railing from the starboard gangway gate aft round the stern to the port gate, and one from each gate forward.
	var aft_s: Array = _edge(st, -h + 0.12, 6.8, 1.0, 0.12)
	aft_s.reverse()
	_rail(pk, kit, aft_s + _edge(st, -h + 0.12, 6.8, -1.0, 0.12), 1.0, WHITE, "white", true)
	var fore_p: Array = _edge(st, 9.2, h - 0.06, -1.0, 0.12)
	fore_p.reverse()
	_rail(pk, kit, _edge(st, 9.2, h - 0.06, 1.0, 0.12) + fore_p, 1.0, WHITE, "white", true)
	for sx2 in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(sx2 * (EX_HB - 0.12), EX_DECK + 0.9, 6.8), Vector3(sx2 * (EX_HB - 0.12), EX_DECK + 0.75, 9.2), 0.02, 0.02, Color(0.8, 0.7, 0.2))
	# Railings round the upper deck's edge (a gap aft for the stair up from the main deck).
	var uy: float = EX_UPPER
	var ue: float = EX_HB - 0.15
	_rail(pk, kit, [Vector3(-0.8, uy, u0 + 0.1), Vector3(-ue, uy, u0 + 0.1), Vector3(-ue, uy, u1 - 0.1), Vector3(ue, uy, u1 - 0.1), Vector3(ue, uy, u0 + 0.1),
			Vector3(0.8, uy, u0 + 0.1)], 1.0)
	# Stairs: from the aft main deck up to the upper deck's terrace, and from the terrace to the sun deck.
	_stair(pk, kit, Vector3(0, EX_DECK + 0.08, -h + 0.9), Vector3(0, EX_UPPER, u0 + 0.05), 1.2)
	_stair(pk, kit, Vector3(-2.6, EX_UPPER, EX_UPPER_SALOON.x - 3.6), Vector3(-2.6, EX_SUN, EX_UPPER_SALOON.x + 0.05), 1.0)
	# The upper terrace's tables, lifebuoys on the railings, life rafts on the sun deck.
	for t in _ex_terrace_tables():
		_table_set(pk, kit, t, 4)
	for lb in [[Vector3(EX_HB - 0.12, EX_DECK + 0.62, -h + 6.0), Vector3(1, 0, 0)], [Vector3(-EX_HB + 0.12, EX_DECK + 0.62, -h + 6.0), Vector3(-1, 0, 0)],
			[Vector3(ue, EX_UPPER + 0.62, -2.0), Vector3(1, 0, 0)], [Vector3(-ue, EX_UPPER + 0.62, -2.0), Vector3(-1, 0, 0)],
			[Vector3(EX_HB - 0.12, EX_DECK + 0.62, h - 10.0), Vector3(1, 0, 0)], [Vector3(-EX_HB + 0.12, EX_DECK + 0.62, h - 10.0), Vector3(-1, 0, 0)]]:
		_lifebuoy(pk, kit, (lb[0] as Vector3) + (lb[1] as Vector3) * 0.08, lb[1])
	# The sun deck: the slab over the upper saloon (planked), a navy fascia, its railing, benches, tables, the canopy.
	var sd0: float = EX_UPPER_SALOON.x
	var sd1: float = EX_UPPER_SALOON.y
	var sw: float = wl + 0.2
	_slab(pk, kit, Vector3(-sw, EX_SUN - 0.15, sd0 - 0.15), Vector3(sw, EX_SUN + 0.02, sd1 + 0.15), "white", WHITE, "lapboards", Color(0.74, 0.62, 0.46))
	_blk(pk, kit, "paint", Vector3(-sw - 0.02, EX_SUN - 0.13, sd0 - 0.17), Vector3(sw + 0.02, EX_SUN - 0.03, sd1 + 0.17), navy)
	var sy: float = EX_SUN + 0.02
	_rail(pk, kit, [Vector3(-1.9, sy, sd0 - 0.05), Vector3(sw - 0.08, sy, sd0 - 0.05), Vector3(sw - 0.08, sy, sd1 - 0.05), Vector3(-sw + 0.08, sy, sd1 - 0.05),
			Vector3(-sw + 0.08, sy, sd0 - 0.05), Vector3(-3.15, sy, sd0 - 0.05)], 1.0, WHITE, "white", true)
	for rz in [4.6, 8.2]:
		for sx4 in [-1.0, 1.0]:
			var rc := Vector3(sx4 * (sw - 0.6), sy + 0.35, rz)
			pk.tube(kit, "plastic", rc - Vector3(0, 0, 0.6), rc + Vector3(0, 0, 0.6), 0.3, 0.3, 10, WHITE, true)
			_blk(pk, kit, "paint", rc - Vector3(0.3, 0.35, 0.5), rc + Vector3(0.3, -0.27, 0.5), DARK)
	for b in _ex_benches():
		_bench(pk, kit, b[0], b[1])
	for t2 in _ex_sun_tables():
		_table_set(pk, kit, t2, 4)
	_canopy(pk, kit, EX_CANOPY.x, EX_CANOPY.y, sw - 0.15, sy, (2.3 if raised else 1.68), navy)
	# The wheelhouse forward on the sun deck: its lower half sunk into the upper saloon unless raised.
	_ex_wheelhouse(pk, kit, labels, sy, raised, navy, ship_name)
	# The funnel-shaped mast: a raked oval funnel in white with the line's red band and a black top, a horn on it.
	var fz := 2.6
	var fb: Basis = Basis(Vector3.RIGHT, -0.22)
	var prof: Array = [Vector2(1.05, 0.0), Vector2(0.95, 0.9), Vector2(0.9, 1.2), Vector2(0.86, 1.5), Vector2(0.001, 1.5)]
	_funnel(pk, kit, Vector3(0, sy, fz), prof, fb, accent)
	pk.tube(kit, "chrome", Vector3(0.3, sy + 1.35, fz - 0.6), Vector3(0.3, sy + 1.35, fz - 0.05), 0.06, 0.13, 8, CHROME, true)
	# Navigation lights on the funnel's sides and a stern light.
	_nav_light(pk, kit, Vector3(0.95, sy + 0.6, fz + 0.3), SIGNAL_GREEN, Vector3(1, 0, 0.2))
	_nav_light(pk, kit, Vector3(-0.95, sy + 0.6, fz + 0.3), SIGNAL_RED, Vector3(-1, 0, 0.2))
	_nav_light(pk, kit, Vector3(0, float(_st_at(st, -h)[3]) + 1.1, -h + 0.3), LAMP_WHITE, Vector3(0, 0, -1))
	# Bow and stern: bitts, the windlass, flag staffs.
	for sx5 in [-1.0, 1.0]:
		_bitts(pk, kit, Vector3(sx5 * 3.6, float(_st_at(st, h - 6.0)[3]), h - 6.0), Vector3(0, 0, 1))
		_bitts(pk, kit, Vector3(sx5 * 3.5, float(_st_at(st, -h + 2.0)[3]), -h + 2.0), Vector3(0, 0, 1))
	var zw: float = h - 4.0
	var yw: float = float(_st_at(st, zw)[3])
	_blk(pk, kit, "paint", Vector3(-0.5, yw - 0.1, zw - 0.5), Vector3(0.5, yw + 0.6, zw + 0.5), navy)
	_flag_staff(pk, kit, Vector3(1.4, float(_st_at(st, -h + 0.3)[3]), -h + 0.35), 2.5, Vector3(-0.3, 0, -1), false)
	_flag_staff(pk, kit, Vector3(0, float(_st_at(st, h - 0.4)[3]), h - 0.4), 2.0, Vector3(0.3, 0, -1), false)
	# Names: both bows, the stern, the line's name along the upper saloon over its windows.
	for sx6 in [-1.0, 1.0]:
		var on: Array = _on_hull(st, h - 7.5, 1.0, sx6, hs["bilge"])
		_label(labels, ship_name, (on[0] as Vector3) + (on[1] as Vector3) * 0.03, on[1], 0.36, navy, 7.0)
		_label(labels, "KRONBURGER RHEINFLOTTE", Vector3(sx6 * (wl + 0.03), 4.98, -1.0), Vector3(sx6, 0, 0), 0.2, navy, 16.0)
	_label(labels, ship_name, Vector3(0, 0.95, -h - 0.03), Vector3(0, 0, -1), 0.3, navy, 5.0)
	_label(labels, "KRONBURG", Vector3(0, 0.62, -h - 0.03), Vector3(0, 0, -1), 0.18, navy, 4.0)


## The upper terrace's tables (their feet on the deck).
static func _ex_terrace_tables() -> Array:
	var u0: float = EX_SALOON.x - 4.0
	return [Vector3(2.6, EX_UPPER, u0 + 2.6), Vector3(2.6, EX_UPPER, u0 + 5.4), Vector3(-2.4, EX_UPPER, u0 + 5.4)]


## The sun deck's tables under the canopy.
static func _ex_sun_tables() -> Array:
	var out: Array = []
	for tz in [EX_CANOPY.x + 2.4, EX_CANOPY.x + 5.4, EX_CANOPY.x + 8.4]:
		for tx in [-2.1, 2.1]:
			out.append(Vector3(tx, EX_SUN + 0.02, tz))
	return out


## The sun deck's benches: [the middle of the seat's front edge on the deck, facing], along both sides facing outboard.
static func _ex_benches() -> Array:
	var out: Array = []
	var sw: float = EX_WALL + 0.2
	for sx in [-1.0, 1.0]:
		var bz: float = EX_CANOPY.y + 1.3
		while bz < 1.6:
			out.append([Vector3(sx * (sw - 0.7), EX_SUN + 0.02, bz), Vector3(sx, 0, 0)])
			bz += 2.1
	return out


## A saloon's walls from z0 to z1, x +-w, floor y0 to y1, its window band from wy0 to wy1 along both sides and across the
## ends (big panes between slim mullions), doors at both ends on the centre line, sliding gangway doors at `doors` (z) on
## both sides; a navy band under the windows.
static func _saloon(pk: PropKit, kit: Dictionary, z0: float, z1: float, w: float, y0: float, y1: float, wy0: float, wy1: float, doors: Array, band: Color) -> void:
	var mull := Color(0.20, 0.22, 0.25)
	for sx in [-1.0, 1.0]:
		var x: float = sx * w
		var n := Vector3(sx, 0, 0)
		pk.quad(kit, "white", [Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, wy0, z1), Vector3(x, wy0, z0)], n, WHITE)
		pk.quad(kit, "white", [Vector3(x, wy1, z0), Vector3(x, wy1, z1), Vector3(x, y1, z1), Vector3(x, y1, z0)], n, WHITE)
		pk.quad(kit, "paint", [Vector3(x + sx * 0.02, wy0 - 0.35, z0), Vector3(x + sx * 0.02, wy0 - 0.35, z1), Vector3(x + sx * 0.02, wy0 - 0.15, z1),
				Vector3(x + sx * 0.02, wy0 - 0.15, z0)], n, band)
		# The window band: panes of about 1.9m between mullions; the gangway doors are panes of dark door.
		var nb: int = maxi(int((z1 - z0) / 1.9), 1)
		var pw: float = (z1 - z0) / float(nb)
		for k in range(nb):
			var za: float = z0 + pw * float(k)
			var zb: float = za + pw
			var door: bool = false
			for dz in doors:
				if absf((za + zb) * 0.5 - float(dz)) < pw * 0.5:
					door = true
			if door:
				pk.quad(kit, "white", [Vector3(x, wy0, za), Vector3(x, wy0, zb), Vector3(x, wy1, zb), Vector3(x, wy1, za)], n, WHITE)
				var dc := Vector3(x + sx * 0.025, (y0 + wy1) * 0.5, (za + zb) * 0.5)
				_box(pk, kit, "paint", dc, Basis(), Vector3(0.04, wy1 - y0, pw - 0.3), mull)
				pk.quad(kit, "rglass", [Vector3(x + sx * 0.07, y0 + 0.9, za + 0.35), Vector3(x + sx * 0.07, y0 + 0.9, zb - 0.35), Vector3(x + sx * 0.07, wy1 - 0.1, zb - 0.35),
						Vector3(x + sx * 0.07, wy1 - 0.1, za + 0.35)], n, Color(1, 1, 1, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
				continue
			pk.quad(kit, "rglass", [Vector3(x + sx * 0.025, wy0, za), Vector3(x + sx * 0.025, wy0, zb), Vector3(x + sx * 0.025, wy1, zb), Vector3(x + sx * 0.025, wy1, za)], n,
					Color(0.96, 0.95, 0.9, 0.12 if k % 3 == 0 else 0.0), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
			pk.beam(kit, "paint", Vector3(x + sx * 0.05, wy0, za), Vector3(x + sx * 0.05, wy1, za), 0.09, 0.06, mull, Vector3(0, 0, 1))
		pk.beam(kit, "paint", Vector3(x + sx * 0.05, wy0, z1), Vector3(x + sx * 0.05, wy1, z1), 0.09, 0.06, mull, Vector3(0, 0, 1))
		pk.beam(kit, "paint", Vector3(x + sx * 0.055, wy1 + 0.03, z0), Vector3(x + sx * 0.055, wy1 + 0.03, z1), 0.06, 0.05, mull, Vector3.UP)
		pk.beam(kit, "paint", Vector3(x + sx * 0.055, wy0 - 0.03, z0), Vector3(x + sx * 0.055, wy0 - 0.03, z1), 0.06, 0.05, mull, Vector3.UP)
	# The ends: windows either side of a door on the centre line.
	for e in [[z0, -1.0], [z1, 1.0]]:
		var z: float = e[0]
		var sz: float = e[1]
		var n2 := Vector3(0, 0, sz)
		pk.quad(kit, "white", [Vector3(-w, y0, z), Vector3(w, y0, z), Vector3(w, wy0, z), Vector3(-w, wy0, z)], n2, WHITE)
		pk.quad(kit, "white", [Vector3(-w, wy1, z), Vector3(w, wy1, z), Vector3(w, y1, z), Vector3(-w, y1, z)], n2, WHITE)
		for sx2 in [-1.0, 1.0]:
			pk.quad(kit, "rglass", [Vector3(sx2 * 0.85, wy0, z + sz * 0.025), Vector3(sx2 * w, wy0, z + sz * 0.025), Vector3(sx2 * w, wy1, z + sz * 0.025),
					Vector3(sx2 * 0.85, wy1, z + sz * 0.025)], n2, Color(1, 1, 1, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
			pk.beam(kit, "paint", Vector3(sx2 * w * 0.5, wy0, z + sz * 0.05), Vector3(sx2 * w * 0.5, wy1, z + sz * 0.05), 0.09, 0.06, mull, Vector3(1, 0, 0))
		var dh: float = minf(2.1, y1 - y0 - 0.12)
		if wy1 > y0 + dh:
			pk.quad(kit, "white", [Vector3(-0.85, y0 + dh, z), Vector3(0.85, y0 + dh, z), Vector3(0.85, wy1, z), Vector3(-0.85, wy1, z)], n2, WHITE)
		_box(pk, kit, "paint", Vector3(0, y0 + dh * 0.5, z + sz * 0.03), Basis(), Vector3(1.7, dh, 0.04), mull)
		pk.quad(kit, "rglass", [Vector3(-0.7, y0 + 0.9, z + sz * 0.075), Vector3(0.7, y0 + 0.9, z + sz * 0.075), Vector3(0.7, y0 + dh - 0.1, z + sz * 0.075),
				Vector3(-0.7, y0 + dh - 0.1, z + sz * 0.075)], n2, Color(1, 1, 1, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])


## A bench (two seats' worth, 1.6m) on the deck at `p` (the middle of its seat's front edge, on the floor), its seat
## facing `face`: slats on a white frame, a back.
static func _bench(pk: PropKit, kit: Dictionary, p: Vector3, face: Vector3) -> void:
	var f := Vector3(face.x, 0, face.z).normalized()
	var s := Vector3.UP.cross(f).normalized()
	var b := Basis(s, Vector3.UP, f)
	for k in range(3):
		_box(pk, kit, "timber", p + Vector3(0, 0.45, 0) - f * (0.07 + 0.13 * float(k)), b, Vector3(1.6, 0.035, 0.1), TIMBER)
	for k2 in range(2):
		_box(pk, kit, "timber", p + Vector3(0, 0.66 + 0.18 * float(k2), 0) - f * 0.44, b, Vector3(1.6, 0.11, 0.03), TIMBER)
	for sx in [-0.7, 0.7]:
		_box(pk, kit, "white", p + s * sx + Vector3(0, 0.215, 0) - f * 0.2, b, Vector3(0.05, 0.43, 0.42), WHITE)
		_box(pk, kit, "white", p + s * sx + Vector3(0, 0.62, 0) - f * 0.47, b, Vector3(0.05, 0.5, 0.04), WHITE)


## A round table with `n` chairs at `p` (the table's foot on the deck).
static func _table_set(pk: PropKit, kit: Dictionary, p: Vector3, n: int) -> void:
	pk.tube(kit, "plastic", p, p + Vector3(0, 0.72, 0), 0.05, 0.05, 6, WHITE, false)
	pk.tube(kit, "plastic", p + Vector3(0, 0.72, 0), p + Vector3(0, 0.76, 0), 0.42, 0.42, 10, WHITE, true)
	pk.tube(kit, "plastic", p, p + Vector3(0, 0.03, 0), 0.25, 0.25, 8, WHITE, true)
	for k in range(n):
		var a: float = TAU * float(k) / float(n) + 0.4
		var d := Vector3(cos(a), 0, sin(a))
		var c: Vector3 = p + d * 0.75
		var s := Vector3.UP.cross(d).normalized()
		_box(pk, kit, "plastic", c + Vector3(0, 0.44, 0), Basis(s, Vector3.UP, d), Vector3(0.44, 0.04, 0.42), WHITE)
		_box(pk, kit, "plastic", c + Vector3(0, 0.68, 0) + d * 0.2, Basis(s, Vector3.UP, d), Vector3(0.42, 0.42, 0.04), WHITE)
		for lx in [-0.18, 0.18]:
			for lz in [-0.17, 0.17]:
				pk.beam(kit, "plastic", c + s * lx + d * lz, c + s * lx + d * lz + Vector3(0, 0.42, 0), 0.03, 0.03, WHITE)


## The sun deck's canopy over z0..z1: white posts along both sides, a navy fringe and a cream awning `h` over the deck,
## its underside paler.
static func _canopy(pk: PropKit, kit: Dictionary, z0: float, z1: float, w: float, y: float, h: float, edge: Color) -> void:
	var top: float = y + h
	var pz: float = z0
	while pz <= z1 + 0.01:
		for sx in [-1.0, 1.0]:
			pk.tube(kit, "white", Vector3(sx * w, y, pz), Vector3(sx * w, top, pz), 0.04, 0.04, 6, WHITE, false)
		pz += (z1 - z0) / 3.0
	var cloth := Color(0.93, 0.90, 0.80)
	var rise := 0.12
	for sx2 in [-1.0, 1.0]:
		var n := Vector3(sx2 * rise, w, 0).normalized()
		pk.quad(kit, "canvas", [Vector3(sx2 * (w + 0.1), top, z0 - 0.1), Vector3(sx2 * (w + 0.1), top, z1 + 0.1), Vector3(0, top + rise, z1 + 0.1), Vector3(0, top + rise, z0 - 0.1)], n, cloth)
		pk.quad(kit, "canvas", [Vector3(sx2 * (w + 0.1), top - 0.02, z0 - 0.1), Vector3(sx2 * (w + 0.1), top - 0.02, z1 + 0.1), Vector3(0, top + rise - 0.02, z1 + 0.1),
				Vector3(0, top + rise - 0.02, z0 - 0.1)], -n, cloth.darkened(0.15))
		# The fringe along the side.
		pk.quad(kit, "canvas", [Vector3(sx2 * (w + 0.11), top - 0.22, z0 - 0.1), Vector3(sx2 * (w + 0.11), top - 0.22, z1 + 0.1), Vector3(sx2 * (w + 0.11), top + 0.01, z1 + 0.1),
				Vector3(sx2 * (w + 0.11), top + 0.01, z0 - 0.1)], Vector3(sx2, 0, 0), edge)
		pk.quad(kit, "canvas", [Vector3(sx2 * (w + 0.09), top - 0.22, z1 + 0.1), Vector3(sx2 * (w + 0.09), top - 0.22, z0 - 0.1), Vector3(sx2 * (w + 0.09), top + 0.01, z0 - 0.1),
				Vector3(sx2 * (w + 0.09), top + 0.01, z1 + 0.1)], Vector3(-sx2, 0, 0), edge.darkened(0.2))
	for e in [[z0 - 0.1, -1.0], [z1 + 0.1, 1.0]]:
		var z: float = e[0]
		var sz: float = e[1]
		pk.tri(kit, "canvas", Vector3(-(w + 0.1), top, z), Vector3(w + 0.1, top, z), Vector3(0, top + rise, z), Vector3(0, 0, sz), Vector3(0, 0, sz), Vector3(0, 0, sz), cloth, Vector3(0, 0, sz))
		pk.quad(kit, "canvas", [Vector3(-(w + 0.1), top - 0.22, z + sz * 0.01), Vector3(w + 0.1, top - 0.22, z + sz * 0.01), Vector3(w + 0.1, top + 0.01, z + sz * 0.01),
				Vector3(-(w + 0.1), top + 0.01, z + sz * 0.01)], Vector3(0, 0, sz), edge)


## A funnel: the lathe `prof` (radius, height) squashed to an oval and tilted by `tilt`, at `p` on the deck; white with a
## band of `band` and a black top.
static func _funnel(pk: PropKit, kit: Dictionary, p: Vector3, prof: Array, tilt: Basis, band: Color) -> void:
	var segs := 14
	var oval := Basis.from_scale(Vector3(0.62, 1.0, 1.0))
	for k in range(prof.size() - 1):
		var p0: Vector2 = prof[k]
		var p1: Vector2 = prof[k + 1]
		var ymid: float = (p0.y + p1.y) * 0.5
		var col: Color = WHITE
		if ymid > 0.9 and ymid < 1.2:
			col = band
		elif ymid >= 1.2:
			col = BLACK
		pk.lathe(kit, "white" if col == WHITE else "paint", p, [p0, p1], segs, col, false, tilt * oval)


## The excursion ship's wheelhouse on the sun deck (floor `sy`): a wide box with windows all round, its front raked, a
## roof with the radar and the name board; lowered its roof is at 7.1m.
static func _ex_wheelhouse(pk: PropKit, kit: Dictionary, labels: Array, sy: float, raised: bool, navy: Color, ship_name: String) -> void:
	var z0 := 10.4
	var z1 := 14.4
	var hw := 3.2
	var roof: float = 6.95 + (0.85 if raised else 0.0)
	var wy0: float = roof - 1.3
	var wy1: float = roof - 0.22
	_blk(pk, kit, "white", Vector3(-hw, sy, z0), Vector3(hw, wy0, z1), WHITE)
	_blk(pk, kit, "paint", Vector3(-hw - 0.025, wy0 - 0.14, z0 - 0.025), Vector3(hw + 0.025, wy0 - 0.02, z1 + 0.025), navy)
	var lean := 0.3
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "paint", Vector3(sx * (hw - 0.05), wy0, z1 - 0.05), Vector3(sx * (hw - 0.05), wy1, z1 + lean - 0.05), 0.1, 0.1, DARK, Vector3(1, 0, 0))
		pk.beam(kit, "paint", Vector3(sx * (hw - 0.05), wy0, z0 + 0.05), Vector3(sx * (hw - 0.05), wy1, z0 + 0.05), 0.1, 0.1, DARK, Vector3(1, 0, 0))
		pk.quad(kit, "rglass", [Vector3(sx * hw, wy0, z0 + 0.1), Vector3(sx * hw, wy0, z1 - 0.1), Vector3(sx * hw, wy1, z1 + lean - 0.1), Vector3(sx * hw, wy1, z0 + 0.1)],
				Vector3(sx, 0, 0), Color(1, 1, 1, 0), [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	for mx in [-1.1, 1.1]:
		pk.beam(kit, "paint", Vector3(mx, wy0, z1), Vector3(mx, wy1, z1 + lean), 0.07, 0.06, DARK, Vector3(1, 0, 0))
	var fn := Vector3(0, -lean, wy1 - wy0).normalized()
	pk.quad(kit, "rglass", [Vector3(-hw + 0.1, wy0, z1), Vector3(hw - 0.1, wy0, z1), Vector3(hw - 0.1, wy1, z1 + lean), Vector3(-hw + 0.1, wy1, z1 + lean)], fn, Color(1, 1, 1, 0),
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	pk.quad(kit, "rglass", [Vector3(hw - 0.1, wy0, z0), Vector3(-hw + 0.1, wy0, z0), Vector3(-hw + 0.1, wy1, z0), Vector3(hw - 0.1, wy1, z0)], Vector3(0, 0, -1), Color(1, 1, 1, 0),
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	_blk(pk, kit, "white", Vector3(-hw - 0.02, wy1, z0 - 0.02), Vector3(hw + 0.02, roof - 0.08, z1 + lean + 0.02), WHITE)
	_blk(pk, kit, "paint", Vector3(-hw - 0.12, roof - 0.08, z0 - 0.1), Vector3(hw + 0.12, roof, z1 + lean + 0.35), navy)
	_box(pk, kit, "plastic", Vector3(0, roof + 0.05, 12.0), Basis(Vector3.UP, 0.3), Vector3(1.6, 0.1, 0.25), OFFWHITE)
	_label(labels, ship_name, Vector3(0, wy0 - 0.06, z1 + 0.03), Vector3(0, 0, 1), 0.08, WHITE, 5.0)


## The excursion ship's passengers' places, life size in its frame: [position, facing (horizontal), seated, what]. Seated:
## two to each sun-deck bench (facing outboard), four round each table under the canopy and on the upper terrace, the
## position the top of the seat; standing: at the railings of the bow and the aft main deck, the position the deck under
## their feet. Seated heads on the sun deck stay under 7.2m; nobody stands up there. (`raised` changes none of them.)
static func excursion_seats(_raised := false) -> Array:
	var out: Array = []
	for b in _ex_benches():
		var p: Vector3 = b[0]
		var f: Vector3 = b[1]
		var s := Vector3.UP.cross(f).normalized()
		for k in [-0.42, 0.42]:
			out.append([p + Vector3(0, 0.47, 0) - f * 0.2 + s * float(k), f, true, "bench"])
	var tables: Array = _ex_sun_tables() + _ex_terrace_tables()
	for t in tables:
		for k2 in range(4):
			var a: float = TAU * float(k2) / 4.0 + 0.4
			var d := Vector3(cos(a), 0, sin(a))
			out.append([(t as Vector3) + Vector3(0, 0.46, 0) + d * 0.75, -d, true, "table"])
	# Standing at the bow's railing and on the aft deck.
	var st: Array = _ex_stations()
	for q in [Vector2(1.6, 28.0), Vector2(-1.4, 29.6), Vector2(0.4, 32.6), Vector2(2.6, 26.0), Vector2(-2.8, 25.5)]:
		var y: float = float(_st_at(st, q.y)[3])
		out.append([Vector3(q.x, y, q.y), Vector3(q.x * 0.3, 0, 1).normalized(), false, "stand"])
	for q2 in [Vector3(3.6, 0, -31.0), Vector3(-3.3, 0, -30.8), Vector3(1.8, 0, -33.8), Vector3(-1.9, 0, -33.6)]:
		var y2: float = float(_st_at(st, q2.z)[3])
		var f2: Vector3 = Vector3(signf(q2.x), 0, 0) if q2.z > -32.0 else Vector3(0, 0, -1)
		out.append([Vector3(q2.x, y2, q2.z), f2, false, "stand"])
	return out


# ======================================================================================
#  The car ferry
# ======================================================================================

const FERRY_L := 45.0
const FERRY_HB := 6.5


## A small Rhine car ferry, 45 x 13m, double ended, lying moored: a flat car deck between kerbs (7.6m, two lanes), a
## passenger walkway on the port side, the hinged ramps at both ends raised a little, and on the starboard side a tower:
## the passengers' shelter on the deck and the wheelhouse over it (its roof at 6.6m), railings, lifebuoys, the name.
static func car_ferry(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var h: float = FERRY_L * 0.5
	var hb := FERRY_HB
	var ys := 1.0
	var st: Array = [
		[-h, hb * 0.97, hb * 0.9, 0.55, ys + 0.1],
		[-h + 1.2, hb, hb * 0.96, -0.3, ys + 0.05],
		[-h + 3.2, hb, hb, -1.3, ys],
		[h - 3.2, hb, hb, -1.3, ys],
		[h - 1.2, hb, hb * 0.96, -0.3, ys + 0.05],
		[h, hb * 0.97, hb * 0.9, 0.55, ys + 0.1],
	]
	var green := Color(0.10, 0.30, 0.22)
	var hs := _scheme(green, WHITE, BLACK, ANTIFOUL, Vector2(0.25, 0.5), 0.22, 0.4)
	_hull(pk, kit, st, hs)
	_deck(pk, kit, st, -h, h, Color(0.32, 0.33, 0.33))
	_strake(pk, kit, st, hs, -0.04, -h + 0.2, h - 0.2, Vector2(0.18, 0.16), BLACK, true)
	# Lanes and kerbs: the car deck from x -4.6 to 3.0.
	var cx0 := -4.6
	var cx1 := 3.0
	for kx in [cx0, cx1]:
		_blk(pk, kit, "paint", Vector3(kx - 0.12, ys, -h + 1.0), Vector3(kx + 0.12, ys + 0.3, h - 1.0), Color(0.85, 0.75, 0.15))
	_blk(pk, kit, "paint", Vector3(-0.85, ys, -h + 2.0), Vector3(-0.75, ys + 0.015, h - 2.0), WHITE)
	# Railings outboard of the walkway and round the tower's side.
	# Each railing turns the corner at the deck's end and runs in to the car deck's kerb.
	_rail(pk, kit, [Vector3(cx0 - 0.15, ys, -(h - 1.0))] + _edge(st, -h + 1.0, h - 1.0, -1.0, 0.12) + [Vector3(cx0 - 0.15, ys, h - 1.0)], 1.0, WHITE, "white", true)
	_rail(pk, kit, [Vector3(cx1 + 0.15, ys, -(h - 1.0))] + _edge(st, -h + 1.0, -6.5, 1.0, 0.12), 1.0, WHITE, "white", true)
	_rail(pk, kit, _edge(st, 6.5, h - 1.0, 1.0, 0.12) + [Vector3(cx1 + 0.15, ys, h - 1.0)], 1.0, WHITE, "white", true)
	# The ramps: hinged at the deck's ends, raised 14 degrees, ribbed, with side flaps and the rams.
	for e2 in [-1.0, 1.0]:
		_ferry_ramp(pk, kit, e2 * (h - 0.6), e2, cx0, cx1, ys)
	# The tower: the shelter (glazed, a bench inside) and the wheelhouse over it.
	var tx0 := 3.4
	var tx1: float = hb - 0.2
	var tz0 := -5.5
	var tz1 := 5.5
	var sh: float = ys + 2.4
	_blk(pk, kit, "white", Vector3(tx0, ys, tz0), Vector3(tx1, ys + 1.0, tz1), WHITE)
	_window(pk, kit, Vector3(tx0, ys + 1.65, 0.0), Vector3(0, 0, 1), Vector3(-1, 0, 0), 9.6, 1.2, Color(1, 1, 1, 0), WHITE)
	_window(pk, kit, Vector3(tx1, ys + 1.65, 0.0), Vector3(0, 0, -1), Vector3(1, 0, 0), 9.6, 1.2, Color(1, 1, 1, 0), WHITE)
	for e3 in [[tz0, -1.0], [tz1, 1.0]]:
		_window(pk, kit, Vector3((tx0 + tx1) * 0.5, ys + 1.65, float(e3[0])), Vector3(float(e3[1]) * -1.0, 0, 0), Vector3(0, 0, float(e3[1])), 2.2, 1.2, Color(1, 1, 1, 0), WHITE)
	_blk(pk, kit, "white", Vector3(tx0 - 0.02, ys + 2.25, tz0 - 0.02), Vector3(tx1 + 0.02, sh, tz1 + 0.02), WHITE)
	# The glazed band's frame posts (the wall between the windows' frames).
	for pz in [tz0, tz1]:
		for px in [tx0, tx1]:
			_blk(pk, kit, "white", Vector3(px - 0.08, ys + 1.0, pz - 0.08), Vector3(px + 0.08, ys + 2.25, pz + 0.08), WHITE)
	_blk(pk, kit, "white", Vector3(tx0 - 0.15, sh, tz0 - 0.15), Vector3(tx1 + 0.15, sh + 0.14, tz1 + 0.15), OFFWHITE)
	# The wheelhouse on top, a stair up to it at the tower's end.
	var wf: float = sh + 0.14
	var wz0 := -2.4
	var wz1 := 2.4
	_blk(pk, kit, "white", Vector3(tx0 + 0.2, wf, wz0), Vector3(tx1 - 0.1, wf + 1.0, wz1), WHITE)
	var wy1: float = wf + 2.1
	for sx2 in [-1.0, 1.0]:
		var zz: float = wz1 if sx2 > 0.0 else wz0
		_window(pk, kit, Vector3((tx0 + tx1) * 0.5 + 0.05, wf + 1.55, zz), Vector3(-sx2, 0, 0), Vector3(0, 0, sx2), 2.15, 0.95)
	_window(pk, kit, Vector3(tx0 + 0.2, wf + 1.55, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), 4.2, 0.95)
	_window(pk, kit, Vector3(tx1 - 0.1, wf + 1.55, 0), Vector3(0, 0, -1), Vector3(1, 0, 0), 4.2, 0.95)
	_blk(pk, kit, "white", Vector3(tx0 + 0.18, wf + 1.0, wz0 - 0.02), Vector3(tx1 - 0.08, wf + 1.02, wz1 + 0.02), WHITE)
	for px2 in [tx0 + 0.2, tx1 - 0.1]:
		for pz2 in [wz0, wz1]:
			_blk(pk, kit, "white", Vector3(px2 - 0.07, wf + 1.0, pz2 - 0.07), Vector3(px2 + 0.07, wy1, pz2 + 0.07), WHITE)
	_blk(pk, kit, "paint", Vector3(tx0 + 0.05, wy1, wz0 - 0.2), Vector3(tx1 + 0.05, wy1 + 0.14, wz1 + 0.2), green)
	_rail(pk, kit, [Vector3(tx0 - 0.05, sh + 0.14, tz0 + 0.1), Vector3(tx0 - 0.05, sh + 0.14, tz1 - 0.1), Vector3(tx1 + 0.05, sh + 0.14, tz1 - 0.1),
			Vector3(tx1 + 0.05, sh + 0.14, tz0 + 0.1), Vector3(tx0 - 0.05, sh + 0.14, tz0 + 0.1)], 1.0)
	_stair(pk, kit, Vector3((tx0 + tx1) * 0.5, ys, tz0 - 3.6), Vector3((tx0 + tx1) * 0.5, sh + 0.14, tz0 - 0.05), 0.8)
	# Mast with lights and horn on the wheelhouse roof, lifebuoys, the name.
	var mt := Vector3((tx0 + tx1) * 0.5, wy1 + 0.14, 0)
	pk.tube(kit, "paint", mt, mt + Vector3(0, 2.2, 0), 0.06, 0.05, 6, WHITE, true)
	_nav_light(pk, kit, mt + Vector3(0, 2.2, 0), LAMP_WHITE)
	pk.beam(kit, "paint", mt + Vector3(0, 1.6, -0.5), mt + Vector3(0, 1.6, 0.5), 0.05, 0.05, WHITE, Vector3.UP)
	_nav_light(pk, kit, mt + Vector3(0, 1.65, 0.55), SIGNAL_GREEN)
	_nav_light(pk, kit, mt + Vector3(0, 1.65, -0.55), SIGNAL_RED)
	for lz in [-12.0, 12.0]:
		_lifebuoy(pk, kit, Vector3(-hb + 0.04, ys + 0.62, lz), Vector3(-1, 0, 0))
	_lifebuoy(pk, kit, Vector3(tx0 + 0.55, ys + 0.55, tz1 + 0.09), Vector3(0, 0, 1))
	_label(labels, "RHEINFÄHRE KRONBURG", Vector3(tx0 - 0.04, ys + 0.5, 0), Vector3(-1, 0, 0), 0.3, green, 9.0)
	_label(labels, "RHEINFÄHRE KRONBURG", Vector3(tx1 + 0.04, ys + 0.5, 0), Vector3(1, 0, 0), 0.3, green, 9.0)
	for sx3 in [-1.0, 1.0]:
		var on: Array = _on_hull(st, 0.0, 0.62, sx3, hs["bilge"])
		_label(labels, "FÄHRE VENNHOVEN", (on[0] as Vector3) + (on[1] as Vector3) * 0.03, on[1], 0.24, WHITE, 8.0)
	for bz in [-h + 2.2, h - 2.2]:
		_bitts(pk, kit, Vector3(-hb + 0.6, ys, bz), Vector3(0, 0, 1))
		_bitts(pk, kit, Vector3(hb - 0.6, ys, bz), Vector3(0, 0, 1))


## A ferry ramp hinged at z_h (the deck's end), reaching outward (`dir`) 5.5m, raised 14 degrees: a ribbed plate the car
## deck's width, side flaps, hinge lugs and the hydraulic rams from posts on the deck.
static func _ferry_ramp(pk: PropKit, kit: Dictionary, z_h: float, dir: float, x0: float, x1: float, ys: float) -> void:
	var ang := deg_to_rad(14.0)
	var L := 5.5
	var d := Vector3(0, sin(ang), cos(ang) * dir)
	var hy: float = ys + 0.15
	var hinge := Vector3(0, hy, z_h)
	var n: Vector3 = Vector3(1, 0, 0).cross(d) * dir
	if n.y < 0.0:
		n = -n
	var col := Color(0.35, 0.37, 0.37)
	var t := 0.18
	var a := Vector3(x0, hy, z_h)
	var b := Vector3(x1, hy, z_h)
	var a2: Vector3 = a + d * L
	var b2: Vector3 = b + d * L
	pk.quad(kit, "paint", [a, b, b2, a2], n, col)
	pk.quad(kit, "paint", [a - n * t, b - n * t, b2 - n * t, a2 - n * t], -n, col.darkened(0.3))
	pk.quad(kit, "paint", [a2, b2, b2 - n * t, a2 - n * t], d, col.darkened(0.1))
	for e in [[a, a2, -1.0], [b, b2, 1.0]]:
		var p0: Vector3 = e[0]
		var p1: Vector3 = e[1]
		var s := Vector3(float(e[2]), 0, 0)
		pk.quad(kit, "paint", [p0, p1, p1 - n * t, p0 - n * t], s, col.darkened(0.15))
		# The side flap standing up along the edge.
		pk.beam(kit, "paint", p0 + n * 0.15 + s * 0.05, p1 + n * 0.15 + s * 0.05, 0.3, 0.1, Color(0.85, 0.75, 0.15), n)
	# Ribs across the plate (2cm proud, on top of it).
	var k := 0.4
	while k < L - 0.2:
		var rp: Vector3 = hinge + d * k + n * 0.02
		pk.beam(kit, "paint", Vector3(x0 + 0.15, rp.y, rp.z), Vector3(x1 - 0.15, rp.y, rp.z), 0.05, 0.04, col.lightened(0.08), n)
		k += 0.45
	# The rams: posts on the deck and cylinders to the ramp's sides.
	for px in [x0 - 0.45, x1 + 0.45]:
		var post := Vector3(px, ys, z_h - dir * 1.6)
		pk.beam(kit, "paint", post, post + Vector3(0, 2.0, 0), 0.25, 0.25, Color(0.10, 0.30, 0.22))
		var att := Vector3(px - signf(px - (x0 + x1) * 0.5) * 0.3, hy, z_h) + d * 3.2
		pk.tube(kit, "chrome", post + Vector3(0, 1.85, 0), att, 0.09, 0.07, 8, CHROME, true)


# ======================================================================================
#  The landing stage
# ======================================================================================

const STAGE_W := 9.0
const STAGE_FB := 0.9


## Where the landing stage's gangway lands on the bank, in its frame: the middle of its top end's sill.
static func gangway_top(length: float, drop: float) -> Vector3:
	var run: float = maxf(drop * 3.8, 14.0)
	return Vector3(0.0, STAGE_FB + drop, -STAGE_W * 0.5 - run)


## A Schiffsanleger: a steel pontoon `length` long (along x, centred) and 9m wide, floating with its deck 0.9m over the
## water, the river side +z (fenders, bitts, open for the ships) and the bank side -z (railed); a ticket pavilion of the
## Kronburger Rheinflotte on it, two mooring piles through guide rings at its ends, and the gangway: two truss girders
## and a planked walk, hinged on the bank, rising `drop` metres from the pontoon's deck to its top end (gangway_top(): x
## 0, y 0.9 + drop, z -4.5 - max(3.8 drop, 14)), resting on rollers on the pontoon. A concrete abutment under its top end.
static func landing_stage(pk: PropKit, kit: Dictionary, labels: Array, length: float, drop: float) -> void:
	var L: float = maxf(length, 20.0)
	var hl: float = L * 0.5
	var hw: float = STAGE_W * 0.5
	var fb := STAGE_FB
	# The pontoon: a box hull with chamfered bilges, painted, a white stripe, a steel deck with yellow edges.
	var dark := Color(0.12, 0.20, 0.18)
	var pts := PackedVector2Array([Vector2(-hw, fb), Vector2(-hw, -0.6), Vector2(-hw + 0.4, -1.0), Vector2(hw - 0.4, -1.0), Vector2(hw, -0.6), Vector2(hw, fb)])
	# Built as an extrusion along x: the outline in (z, y) through a frame turning x to the pontoon's length.
	var saved := _push(pk, Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)), Vector3.ZERO))
	var ol := PackedVector2Array()
	for p in pts:
		ol.append(Vector2(-p.x, p.y))
	if PropKit._signed_area(ol) < 0.0:
		ol.reverse()
	pk.extrude(kit, "paint", ol, -hl, hl, 0.06, dark)
	_pop(pk, saved)
	_blk(pk, kit, "paint", Vector3(-hl + 0.1, fb - 0.28, -hw - 0.02), Vector3(hl - 0.1, fb - 0.12, hw + 0.02), WHITE)
	_blk(pk, kit, "deck", Vector3(-hl + 0.05, fb, -hw + 0.05), Vector3(hl - 0.05, fb + 0.02, hw - 0.05), Color(0.40, 0.42, 0.42))
	_blk(pk, kit, "paint", Vector3(-hl + 0.1, fb + 0.02, hw - 0.45), Vector3(hl - 0.1, fb + 0.035, hw - 0.3), Color(0.95, 0.80, 0.10))
	# Fenders along the river side: timber rubbing beams on brackets, tyres hanging.
	_blk(pk, kit, "timber", Vector3(-hl + 0.3, fb - 0.75, hw + 0.03), Vector3(hl - 0.3, fb - 0.35, hw + 0.28), TIMBER.darkened(0.2))
	var fx: float = -hl + 2.0
	while fx < hl - 1.0:
		_ring(pk, kit, "rubber", Vector3(fx, -0.1, hw + 0.38), Vector3(0, 0, 1), 0.38, 0.22, 10, Color(0.05, 0.05, 0.05))
		fx += 4.0
	for bx in [-hl + 1.5, -hl * 0.33, hl * 0.33, hl - 1.5]:
		_bitts(pk, kit, Vector3(bx, fb + 0.02, hw - 0.9), Vector3(1, 0, 0))
	# The railing on the bank side and the ends, open where the gangway lands.
	_rail(pk, kit, [Vector3(-hl + 0.15, fb + 0.02, hw - 1.2), Vector3(-hl + 0.15, fb + 0.02, -hw + 0.15), Vector3(-1.6, fb + 0.02, -hw + 0.15)], 1.1, WHITE, "white", true)
	_rail(pk, kit, [Vector3(1.6, fb + 0.02, -hw + 0.15), Vector3(hl - 0.15, fb + 0.02, -hw + 0.15), Vector3(hl - 0.15, fb + 0.02, hw - 1.2)], 1.1, WHITE, "white", true)
	_lifebuoy(pk, kit, Vector3(hl - 0.08, fb + 0.65, 0.0), Vector3(1, 0, 0))
	_lifebuoy(pk, kit, Vector3(-hl + 0.08, fb + 0.65, 0.0), Vector3(-1, 0, 0))
	# The mooring piles at both ends (outside the pontoon, on the bank side) with their guide rings.
	for px in [-hl - 0.9, hl + 0.9]:
		pk.tube(kit, "paint", Vector3(px, -6.0, -hw + 1.2), Vector3(px, fb + 3.2, -hw + 1.2), 0.45, 0.45, 12, Color(0.18, 0.18, 0.18), true)
		pk.tube(kit, "paint", Vector3(px, fb + 3.2, -hw + 1.2), Vector3(px, fb + 3.4, -hw + 1.2), 0.5, 0.5, 12, Color(0.85, 0.75, 0.15), true)
		_ring(pk, kit, "paint", Vector3(px, fb - 0.2, -hw + 1.2), Vector3.UP, 0.62, 0.16, 12, dark)
		_blk(pk, kit, "paint", Vector3(px - signf(px) * 0.55, fb - 0.3, -hw + 1.0), Vector3(px - signf(px) * 0.9, fb - 0.1, -hw + 1.4), dark)
	# The ticket pavilion: glazed on three sides, a flat roof overhanging toward the river, a timetable and the line's sign.
	var px0: float = -hl + 3.0
	var px1: float = px0 + 4.2
	var pz0: float = -hw + 1.0
	var pz1: float = pz0 + 3.0
	var y0: float = fb + 0.02
	_blk(pk, kit, "white", Vector3(px0, y0, pz0), Vector3(px1, y0 + 0.9, pz1), WHITE)
	_window(pk, kit, Vector3((px0 + px1) * 0.5, y0 + 1.6, pz1), Vector3(1, 0, 0), Vector3(0, 0, 1), 3.9, 1.3)
	_window(pk, kit, Vector3(px1, y0 + 1.6, (pz0 + pz1) * 0.5), Vector3(0, 0, -1), Vector3(1, 0, 0), 2.7, 1.3)
	_window(pk, kit, Vector3(px0, y0 + 1.6, (pz0 + pz1) * 0.5), Vector3(0, 0, 1), Vector3(-1, 0, 0), 2.7, 1.3)
	_blk(pk, kit, "white", Vector3(px0, y0 + 2.3, pz0), Vector3(px1, y0 + 2.6, pz1), WHITE)
	pk.quad(kit, "white", [Vector3(px1, y0 + 0.9, pz0), Vector3(px0, y0 + 0.9, pz0), Vector3(px0, y0 + 2.3, pz0), Vector3(px1, y0 + 2.3, pz0)], Vector3(0, 0, -1), WHITE)
	for cx in [px0, px1]:
		for cz in [pz1]:
			_blk(pk, kit, "white", Vector3(cx - 0.08, y0 + 0.9, cz - 0.08), Vector3(cx + 0.08, y0 + 2.3, cz + 0.08), WHITE)
	var navy := Color(0.08, 0.14, 0.34)
	_blk(pk, kit, "paint", Vector3(px0 - 0.3, y0 + 2.6, pz0 - 0.3), Vector3(px1 + 0.3, y0 + 2.75, pz1 + 1.2), navy)
	_label(labels, "KRONBURGER RHEINFLOTTE", Vector3((px0 + px1) * 0.5, y0 + 2.45, pz1 + 0.03), Vector3(0, 0, 1), 0.16, navy, 4.0)
	_blk(pk, kit, "enamel", Vector3(px1 + 0.4, y0 + 0.9, pz1 - 0.05), Vector3(px1 + 1.4, y0 + 2.0, pz1), Color(0.95, 0.94, 0.88))
	pk.beam(kit, "steel", Vector3(px1 + 0.9, y0, pz1 - 0.1), Vector3(px1 + 0.9, y0 + 0.9, pz1 - 0.1), 0.06, 0.06, DARK)
	_label(labels, "FAHRPLAN", Vector3(px1 + 0.9, y0 + 1.85, pz1 + 0.03), Vector3(0, 0, 1), 0.08, navy, 0.9)
	_label(labels, "ANLEGER KRONBURG", Vector3(0.0, fb + 3.0, -hw - 0.1), Vector3(0, 0, -1), 0.3, navy, 5.0)
	_blk(pk, kit, "enamel", Vector3(-2.7, fb + 2.7, -hw - 0.08), Vector3(2.7, fb + 3.3, -hw - 0.05), Color(0.95, 0.94, 0.88))
	for gx in [-2.6, 2.6]:
		pk.beam(kit, "steel", Vector3(gx, fb + 0.02, -hw + 0.1), Vector3(gx, fb + 3.3, -hw + 0.1), 0.08, 0.08, DARK)
		pk.beam(kit, "steel", Vector3(gx, fb + 3.25, -hw + 0.1), Vector3(gx, fb + 3.25, -hw - 0.06), 0.06, 0.06, DARK)
	_gangway(pk, kit, Vector3(0, fb + 0.02, -hw + 0.6), gangway_top(L, drop))


## A gangway from `a` (its foot on the pontoon) to `b` (its top end on the bank): two truss girders (top and bottom
## chords, posts and diagonals), a planked walk 2.2m wide between them, the foot on rollers, the top on a hinge over a
## concrete abutment, lamps on posts.
static func _gangway(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var dir: Vector3 = d.normalized()
	var across := Vector3(1, 0, 0)
	var hw := 1.2
	var gh := 1.3
	var col := Color(0.86, 0.86, 0.84)
	var nseg: int = maxi(int(d.length() / 2.5), 2)
	for sx in [-1.0, 1.0]:
		var o: Vector3 = across * (sx * hw)
		var bot0: Vector3 = a + o + Vector3(0, 0.1, 0)
		var bot1: Vector3 = b + o + Vector3(0, 0.1, 0)
		pk.beam(kit, "white", bot0, bot1, 0.12, 0.18, col, across)
		pk.beam(kit, "white", bot0 + Vector3.UP * gh, bot1 + Vector3.UP * gh, 0.1, 0.1, col, across)
		for k in range(nseg + 1):
			var p: Vector3 = bot0.lerp(bot1, float(k) / float(nseg))
			pk.beam(kit, "white", p, p + Vector3.UP * gh, 0.07, 0.07, col)
			if k < nseg:
				var q: Vector3 = bot0.lerp(bot1, float(k + 1) / float(nseg))
				pk.beam(kit, "white", p + (Vector3.UP * gh if k % 2 == 0 else Vector3.ZERO), q + (Vector3.ZERO if k % 2 == 0 else Vector3.UP * gh), 0.05, 0.05, col)
	# The walk: planks across, on cross beams.
	var n_pl: int = int(d.length() / 0.32)
	for k2 in range(n_pl):
		var p2: Vector3 = a.lerp(b, (float(k2) + 0.5) / float(n_pl)) + Vector3(0, 0.2, 0)
		_box(pk, kit, "timber", p2, Basis(across, dir.cross(across).normalized() * -1.0, dir).orthonormalized(), Vector3(hw * 2.0 - 0.3, 0.05, 0.28), TIMBER)
	var ub: Basis = Basis(across, dir.cross(across) * -1.0, dir).orthonormalized()
	_box(pk, kit, "paint", a.lerp(b, 0.5) + Vector3(0, 0.12, 0), ub, Vector3(hw * 2.0 - 0.1, 0.08, d.length()), DARK)
	# The foot's rollers on a plate, the top's hinge on the abutment.
	_blk(pk, kit, "paint", a + Vector3(-hw - 0.2, -0.0, -0.4), a + Vector3(hw + 0.2, 0.04, 0.6), DARK)
	pk.tube(kit, "paint", a + Vector3(-hw, 0.14, 0.1), a + Vector3(hw, 0.14, 0.1), 0.12, 0.12, 10, DARK, true)
	_blk(pk, kit, "concrete", b + Vector3(-hw - 0.6, -2.5, -3.0), b + Vector3(hw + 0.6, 0.08, 0.2), Color(0.70, 0.69, 0.66))
	pk.tube(kit, "paint", b + Vector3(-hw - 0.1, 0.25, 0), b + Vector3(hw + 0.1, 0.25, 0), 0.12, 0.12, 10, DARK, true)
	for f in [0.25, 0.75]:
		var lp: Vector3 = a.lerp(b, f) + across * (hw + 0.1) + Vector3(0, gh, 0)
		pk.beam(kit, "steel", lp, lp + Vector3(0, 1.6, 0), 0.05, 0.05, DARK)
		pk.tube(kit, "lens", lp + Vector3(0, 1.6, 0), lp + Vector3(0, 1.85, 0), 0.12, 0.1, 8, LAMP_WHITE, true)


# ======================================================================================
#  Bank furniture
# ======================================================================================

## A Rhine-kilometre board: a white board 2.2 x 1.4m with a black edge on two posts, its bottom 2.4m up, facing the river
## (+z); the number (`km`) as a label, black. The posts' feet at y 0 (footings to -1).
static func km_board(pk: PropKit, kit: Dictionary, labels: Array, km: int) -> void:
	var w := 2.2
	var hh := 1.4
	var y0 := 2.4
	for px in [-0.75, 0.75]:
		pk.beam(kit, "paint", Vector3(px, -0.95, -0.12), Vector3(px, y0 + hh - 0.1, -0.12), 0.1, 0.1, STEEL_GREY)
		_blk(pk, kit, "concrete", Vector3(px - 0.25, -1.0, -0.37), Vector3(px + 0.25, 0.08, 0.13), Color(0.7, 0.7, 0.68))
	_blk(pk, kit, "enamel", Vector3(-w * 0.5, y0, -0.06), Vector3(w * 0.5, y0 + hh, -0.02), BLACK)
	_blk(pk, kit, "enamel", Vector3(-w * 0.5 + 0.07, y0 + 0.07, -0.02), Vector3(w * 0.5 - 0.07, y0 + hh - 0.07, 0.005), WHITE)
	_label(labels, str(km), Vector3(0, y0 + hh * 0.5, 0.03), Vector3(0, 0, 1), 0.82, BLACK, w - 0.3)


## The half-kilometre mark: a white cross (two bars, 1.2m) on a dark board on a post, facing the river (+z).
static func half_km_mark(pk: PropKit, kit: Dictionary) -> void:
	pk.beam(kit, "paint", Vector3(0, -0.8, -0.11), Vector3(0, 2.6, -0.11), 0.09, 0.09, STEEL_GREY)
	_blk(pk, kit, "enamel", Vector3(-0.7, 1.4, -0.05), Vector3(0.7, 2.8, -0.02), BLACK)
	for k in range(2):
		var ang: float = PI * 0.25 * (1.0 if k == 0 else -1.0)
		var d := Vector3(cos(ang), sin(ang), 0)
		var c := Vector3(0, 2.1, 0.005 + 0.025 * float(k))
		pk.beam(kit, "enamel", c - d * 0.6, c + d * 0.6, 0.16, 0.025, WHITE, Vector3(0, 0, 1).cross(d))


## A fairway buoy floating at y 0: a red can (cylindrical, a red can topmark) or a green cone (a green cone topmark),
## a radar reflector, a white reflective band, and its anchor chain going down from the bottom eye.
static func fairway_buoy(pk: PropKit, kit: Dictionary, red: bool) -> void:
	var col: Color = Color(0.82, 0.10, 0.08) if red else Color(0.06, 0.48, 0.20)
	if red:
		pk.lathe(kit, "paint", Vector3.ZERO, [Vector2(0.001, -0.8), Vector2(0.52, -0.75), Vector2(0.58, -0.4), Vector2(0.58, 1.2), Vector2(0.001, 1.2)], 14, col)
		_ring(pk, kit, "paint", Vector3(0, 0.7, 0), Vector3.UP, 0.58, 0.18, 14, WHITE)
	else:
		pk.lathe(kit, "paint", Vector3.ZERO, [Vector2(0.001, -0.8), Vector2(0.55, -0.75), Vector2(0.62, -0.3), Vector2(0.6, 0.2), Vector2(0.12, 1.6), Vector2(0.001, 1.62)], 14, col)
		_ring(pk, kit, "paint", Vector3(0, 0.55, 0), Vector3.UP, 0.48, 0.16, 14, WHITE)
	var mt: float = 1.2 if red else 1.55
	pk.tube(kit, "paint", Vector3(0, mt, 0), Vector3(0, mt + 0.75, 0), 0.04, 0.04, 6, DARK, true)
	if red:
		pk.tube(kit, "paint", Vector3(0, mt + 0.75, 0), Vector3(0, mt + 1.15, 0), 0.17, 0.17, 10, col, true)
	else:
		pk.lathe(kit, "paint", Vector3(0, mt + 0.72, 0), [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.001, 0.42)], 10, col, true)
	# The radar reflector: two crossed plates.
	for a in [0.0, PI * 0.5]:
		_box(pk, kit, "steel", Vector3(0, mt + 0.4 + (0.03 if a > 0.0 else 0.0), 0), Basis(Vector3.UP, a), Vector3(0.36, 0.3, 0.02), Color(0.7, 0.72, 0.74))
	# The chain: links from the bottom eye down and away upstream (-z).
	var p := Vector3(0, -0.85, 0)
	var dir := Vector3(0, -0.8, -0.6).normalized()
	for k in range(16):
		var flat: bool = k % 2 == 0
		var b: Basis = Basis(Vector3(1, 0, 0), dir, Vector3(1, 0, 0).cross(dir)).orthonormalized()
		if not flat:
			b = Basis(dir, PI * 0.5) * b
		_box(pk, kit, "steel", p + dir * 0.12, b, Vector3(0.1, 0.24, 0.03), Color(0.22, 0.17, 0.12))
		p += dir * 0.2


## A Buhne: a riprap groyne from the bank (z 0 at the bank's foot, its crown at y 0) running out along +z for `length`,
## its crown (2.8m wide) sloping down `drop` metres to the head, the sides at 1:1.8 down to a bed 2.5m under the head;
## the head a half cone round the end (reaching about 2.5m past `length` at the crown, more at the bed). Its root runs 3m
## back into the bank (rising 0.8m). The stones in "riprap": a jittered low-poly surface, flat-shaded, boulders on the
## crown; the head beacon on a post at (0, -drop, length).
static func groyne(pk: PropKit, kit: Dictionary, length: float, drop: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 13.0 + drop * 101.0)
	var crown := 1.4
	var slope := 1.8
	var bed: float = -drop - 2.5
	var nz: int = maxi(int((length + 3.0) / 2.0), 4)
	var across: Array = [-1.0, -0.66, -0.3, -0.12, 0.12, 0.3, 0.66, 1.0]
	# A half cross-section: [lateral distance, height] for each `across` value at a crown height yc.
	var sect := func(a: float, yc: float) -> Vector2:
		var t: float = absf(a)
		var toe: float = crown + slope * (yc - bed)
		var r: float = crown * t / 0.3 if t <= 0.3 else crown + (toe - crown) * (t - 0.3) / 0.7
		var y: float = yc if t <= 0.3 else lerpf(yc, bed, (t - 0.3) / 0.7)
		return Vector2(r, y)
	var grid: Array = []
	for i in range(nz + 1):
		var z: float = lerpf(-3.0, length, float(i) / float(nz))
		var yc: float = 0.8 * smoothstep(0.0, -3.0, z) - drop * clampf(z / maxf(length, 1.0), 0.0, 1.0)
		var row: Array = []
		for a in across:
			var ry: Vector2 = sect.call(float(a), yc)
			var j := Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.15, 0.2), rng.randf_range(-0.25, 0.25))
			if absf(float(a)) >= 0.99:
				j.y = 0.0
			row.append(Vector3(signf(float(a)) * ry.x, ry.y, z) + j)
		grid.append(row)
	# The head: the end's cross-section turned round the centre line at z = length, a half cone.
	var y_end: float = -drop
	for k in range(1, 4):
		var phi: float = PI * 0.5 * float(k) / 3.0
		var row2: Array = []
		for a2 in across:
			var ry2: Vector2 = sect.call(float(a2), y_end)
			var j2 := Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.12, 0.15), rng.randf_range(-0.15, 0.15)) if k < 3 else Vector3.ZERO
			if absf(float(a2)) >= 0.99:
				j2.y = 0.0
			row2.append(Vector3(signf(float(a2)) * ry2.x * cos(phi), ry2.y, length + ry2.x * sin(phi) * 0.9) + j2)
		grid.append(row2)
	for i in range(grid.size() - 1):
		for j in range(across.size() - 1):
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j + 1]
			var c: Vector3 = grid[i + 1][j + 1]
			var d: Vector3 = grid[i + 1][j]
			for tr in [[a, b, c], [a, c, d]]:
				var n: Vector3 = ((tr[2] as Vector3) - (tr[0] as Vector3)).cross((tr[1] as Vector3) - (tr[0] as Vector3))
				if n.length_squared() < 1e-6:
					continue
				n = n.normalized()
				if n.y < 0.0:
					n = -n
				var cc: Color = Color(0.30, 0.29, 0.27).lerp(Color(0.42, 0.38, 0.33), rng.randf())
				pk.tri(kit, "riprap", tr[0], tr[1], tr[2], n, n, n, cc, n)
	# Boulders lying on the crown.
	var nb: int = int(length * 0.5)
	for k3 in range(nb):
		var z2: float = rng.randf_range(0.0, length)
		var i2: int = clampi(int((z2 + 3.0) / (length + 3.0) * float(nz)), 0, nz - 1)
		var j3: int = rng.randi_range(2, 4)
		var base: Vector3 = (grid[i2][j3] as Vector3).lerp(grid[i2 + 1][j3 + 1], rng.randf())
		_boulder(pk, kit, base - Vector3(0, 0.12, 0), rng.randf_range(0.3, 0.6), rng)
	# The head beacon: a steel post with a red and white top and a small sign.
	var post_b := Vector3(0, y_end - 0.3, length)
	pk.tube(kit, "paint", post_b, post_b + Vector3(0, 3.15, 0), 0.09, 0.08, 8, Color(0.85, 0.85, 0.82), true)
	for k4 in range(3):
		var yb2: float = 2.3 + 0.3 * float(k4)
		pk.tube(kit, "paint", post_b + Vector3(0, yb2, 0), post_b + Vector3(0, yb2 + 0.3, 0), 0.1, 0.1, 8, SIGNAL_RED if k4 % 2 == 0 else WHITE, k4 == 2)
	_blk(pk, kit, "enamel", post_b + Vector3(-0.35, 1.6, 0.1), post_b + Vector3(0.35, 2.1, 0.13), Color(0.95, 0.78, 0.10))
	_blk(pk, kit, "enamel", post_b + Vector3(-0.27, 1.68, 0.13), post_b + Vector3(0.27, 2.02, 0.16), BLACK)


## A low-poly boulder (an irregular octahedron-ish lump of 20 faces) of radius r sitting on `p`, flat-shaded.
static func _boulder(pk: PropKit, kit: Dictionary, p: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var v: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6],
			[3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var sc := Vector3(rng.randf_range(0.9, 1.3), rng.randf_range(0.55, 0.8), rng.randf_range(0.8, 1.2))
	var rot := Basis(Vector3.UP, rng.randf() * TAU)
	var pts: Array = []
	for q in v:
		var w: Vector3 = (q as Vector3).normalized() * (1.0 + rng.randf_range(-0.18, 0.18))
		pts.append(p + rot * (w * sc * r) + Vector3(0, r * sc.y * 0.55, 0))
	var col: Color = Color(0.32, 0.31, 0.29).lerp(Color(0.45, 0.41, 0.36), rng.randf())
	for fa in f:
		var a: Vector3 = pts[fa[0]]
		var b: Vector3 = pts[fa[1]]
		var c: Vector3 = pts[fa[2]]
		var n: Vector3 = (b - a).cross(c - a).normalized()
		var centre: Vector3 = (a + b + c) / 3.0 - (p + Vector3(0, r * sc.y * 0.55, 0))
		if n.dot(centre) < 0.0:
			n = -n
		pk.tri(kit, "riprap", a, b, c, n, n, n, col, n)


## A river gauge (Pegel): a staff gauge 8m tall facing the river (+z) on an I-section post, its foot at y 0 (the gauge's
## zero, a concrete footing to -2), black metre numbers and the E-pattern decimetre marks on white; and the gauge house
## (a brick hut with a tiled roof, a door, a window, the instrument mast, PEGEL KRONBURG over the door) with its floor at
## `house_at` (footings to 4m under it), its door toward +z.
static func pegel(pk: PropKit, kit: Dictionary, labels: Array, house_at := Vector3(4.5, 3.0, -7.0)) -> void:
	var bh := 8.0
	var bw := 0.42
	_blk(pk, kit, "concrete", Vector3(-0.6, -2.0, -0.7), Vector3(0.6, 0.15, 0.3), Color(0.68, 0.67, 0.64))
	_blk(pk, kit, "paint", Vector3(-0.1, 0.15, -0.3), Vector3(0.1, bh + 0.2, -0.12), STEEL_GREY)
	_blk(pk, kit, "paint", Vector3(-0.25, 0.15, -0.12), Vector3(0.25, bh + 0.2, -0.08), STEEL_GREY)
	_blk(pk, kit, "enamel", Vector3(-bw * 0.5, 0.0, -0.08), Vector3(bw * 0.5, bh + 0.1, -0.04), WHITE)
	# Decimetre marks: an E of black blocks each metre (alternating sides), 2.5cm proud of the board.
	for m in range(int(bh)):
		for d in range(10):
			var y: float = float(m) + float(d) * 0.1
			if d % 2 == 1:
				continue
			var left: bool = (m % 2 == 0)
			var x0: float = -bw * 0.5 + 0.02 if left else 0.0
			var x1: float = x0 + (bw * 0.5 - 0.02 if d != 0 else bw - 0.04)
			if d == 0:
				x0 = -bw * 0.5 + 0.02
				x1 = bw * 0.5 - 0.02
			pk.quad(kit, "enamel", [Vector3(x0, y, -0.015), Vector3(x1, y, -0.015), Vector3(x1, y + 0.05, -0.015), Vector3(x0, y + 0.05, -0.015)], Vector3(0, 0, 1),
					BLACK)
		var nx: float = bw * 0.25 if m % 2 == 0 else -bw * 0.25
		_label(labels, str(m), Vector3(nx, float(m) + 0.5, 0.01), Vector3(0, 0, 1), 0.16, SIGNAL_RED, bw * 0.45)
	# The gauge house.
	var saved := _push(pk, Transform3D(Basis(), house_at))
	var w := 2.6
	var d2 := 2.2
	var wh := 2.5
	_blk(pk, kit, "concrete", Vector3(-w * 0.5 - 0.1, -4.0, -d2 * 0.5 - 0.1), Vector3(w * 0.5 + 0.1, 0.15, d2 * 0.5 + 0.1), Color(0.65, 0.64, 0.61))
	_blk(pk, kit, "kbrick", Vector3(-w * 0.5, 0.15, -d2 * 0.5), Vector3(w * 0.5, wh, d2 * 0.5), Color(0.55, 0.28, 0.20))
	var ridge: float = wh + 1.0
	for sx in [-1.0, 1.0]:
		var n := Vector3(sx * 1.0, 1.15, 0).normalized()
		YardKit.roof(pk, kit, "biber", Vector3(sx * (w * 0.5 + 0.3), wh - 0.3 * 0.87, d2 * 0.5 + 0.25), Vector3(sx * (w * 0.5 + 0.3), wh - 0.3 * 0.87, -d2 * 0.5 - 0.25),
				Vector3(0, ridge, -d2 * 0.5 - 0.25), Vector3(0, ridge, d2 * 0.5 + 0.25), Color(0.58, 0.27, 0.18), n)
	for sz in [-1.0, 1.0]:
		var nz := Vector3(0, 0, sz)
		pk.tri(kit, "kbrick", Vector3(-w * 0.5, wh, sz * d2 * 0.5), Vector3(w * 0.5, wh, sz * d2 * 0.5), Vector3(0, ridge - 0.05, sz * d2 * 0.5), nz, nz, nz, Color(0.55, 0.28, 0.20), nz,
				Vector2(0, wh) * uvk, Vector2(w, wh) * uvk, Vector2(w * 0.5, ridge) * uvk)
	_box(pk, kit, "painted", Vector3(0.3, 1.2, d2 * 0.5 + 0.03), Basis(), Vector3(0.85, 2.0, 0.05), Color(0.12, 0.30, 0.22))
	_window(pk, kit, Vector3(w * 0.5, 1.6, 0.0), Vector3(0, 0, -1), Vector3(1, 0, 0), 0.6, 0.6, Color(1, 1, 1, 0), WHITE)
	_label(labels, "PEGEL KRONBURG", Vector3(0, 2.36, d2 * 0.5 + 0.05), Vector3(0, 0, 1), 0.14, WHITE, 2.2)
	_blk(pk, kit, "enamel", Vector3(-1.1, 2.24, d2 * 0.5), Vector3(1.1, 2.48, d2 * 0.5 + 0.025), Color(0.10, 0.20, 0.45))
	pk.tube(kit, "steel", Vector3(-0.9, ridge - 0.5, -0.4), Vector3(-0.9, ridge + 2.0, -0.4), 0.04, 0.03, 6, STEEL_GREY, true)
	_box(pk, kit, "plastic", Vector3(-0.9, ridge + 1.6, -0.4), Basis(), Vector3(0.12, 0.6, 0.12), OFFWHITE)
	_box(pk, kit, "plastic", Vector3(-0.9, ridge + 1.2, -0.3), Basis(Vector3.RIGHT, -0.7), Vector3(0.6, 0.02, 0.4), Color(0.12, 0.16, 0.25))
	_pop(pk, saved)


## A life-ring post for the promenade: a red and white steel post 1.9m (footing to -0.6) with a box holder and the ring in
## it, a small rope coil, facing +z.
static func life_ring_post(pk: PropKit, kit: Dictionary) -> void:
	_blk(pk, kit, "concrete", Vector3(-0.2, -0.6, -0.2), Vector3(0.2, 0.05, 0.2), Color(0.68, 0.67, 0.64))
	for k in range(6):
		var y0: float = 0.05 + 0.3 * float(k)
		pk.tube(kit, "paint", Vector3(0, y0, 0), Vector3(0, y0 + 0.3, 0), 0.05, 0.05, 8, SIGNAL_RED if k % 2 == 0 else WHITE, k == 5)
	_blk(pk, kit, "paint", Vector3(-0.42, 0.75, 0.06), Vector3(0.42, 1.65, 0.1), SIGNAL_RED)
	_blk(pk, kit, "paint", Vector3(-0.45, 1.65, 0.06), Vector3(0.45, 1.72, 0.28), SIGNAL_RED.darkened(0.2))
	_lifebuoy(pk, kit, Vector3(0, 1.2, 0.2), Vector3(0, 0, 1))
	_ring(pk, kit, "matte", Vector3(0, 0.88, 0.22), Vector3(0, 0, 1), 0.12, 0.04, 8, Color(0.85, 0.80, 0.55))


## A cast-iron mooring bollard on the promenade's quay edge: a squat post with a flared head, black, on a stone plinth
## (to -0.5).
static func mooring_bollard(pk: PropKit, kit: Dictionary) -> void:
	_blk(pk, kit, "concrete", Vector3(-0.45, -0.5, -0.45), Vector3(0.45, 0.06, 0.45), Color(0.64, 0.62, 0.58))
	pk.lathe(kit, "steel", Vector3(0, 0.06, 0), [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.05), Vector2(0.22, 0.1), Vector2(0.19, 0.25), Vector2(0.18, 0.5),
			Vector2(0.27, 0.58), Vector2(0.28, 0.65), Vector2(0.2, 0.69), Vector2(0.001, 0.71)], 14, Color(0.08, 0.08, 0.09))
