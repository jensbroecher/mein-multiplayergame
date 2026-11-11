extends RefCounted
## Rheinufer (Kronburg GP, stage 2): the east bank's Rhine promenade and the fun fair on the Rhine meadow.
##
## A) The Rheinuferpromenade: Gründerzeit apartment houses (Altbauten, 1890-1905) with shops, cafés and restaurants on their
## ground floors, a corner house with its turret, the Hotel Rheinkrone with its terrace and winter garden, the Rheintreppe
## (sandstone steps down to the lower promenade), the quay wall, the riverside café pavilion, kiosks, lamps, the plane
## trees' cast-iron grates, benches and bins.
## B) The Rheinkirmes: the travelling Ferris wheel "Kronenrad" (base, rotor, gondolas: KirmesWheel.gd turns it), the chain
## swing ride (Kettenkarussell, KirmesRide.gd), the bumper cars, the stalls (Bratwurst, gebrannte Mandeln, Lebkuchenherzen,
## Lose, Schießbude, Crêpes, Getränke), the beer tent, bunting and the fence. Everything fictional: names, signs, firms.
##
## Everything is built through a PropKit at LIFE size and grown by the caller (PROP_SCALE 1.6): make a kit with
## `new_kit(scale)`, set its frame to the prop's place (scaled), call a builder, `commit(pk, kit)`. UVs are in metres times
## `uvk` (the caller's scale) where a shader reads them (KronburgTownKit's and YardKit's hut shaders).
##
## Buildings: their street front in the plane z = 0 facing +z, x from 0 to w along the street, the back at z = -d, y = 0 the
## ground at the front; footings and plinths run down to FOOT (-4). On the promenade the fronts face the river: the caller
## turns +z toward it. Rides and stalls stand on y = 0 (see each builder). Labels go into `labels` as YardKit's [text,
## position, outward normal, cap height, colour, board width], life size in the builder's frame. No colliders: the
## generator or DressingColliders makes them.
##
## Material keys: KronburgTownKit's and YardKit's ("plaster" stucco, "ashlar", "kslate", "kbrick", "stone", "zinc", "biber",
## "pane", "gold", "enamel", "leaf", "painted", "timber", "lapboards", "iron") and CampKit's vertex-colour keys ("paint",
## "matte", "metal", "steel", "chrome", "plastic", "rubber", "canvas", "wood", "gloss"), plus "copper" (green patina),
## "bulb" (LampGlow, a soft daytime glow: Kirmes bulbs, lamp globes), "pennant" (two-sided cloth: bunting, flags'
## pennants) and "wglass" (the winter garden's see-through glass, alpha in the vertex colour).
##
## Faces never share a plane: trims stand 2.5-6cm proud of the wall, panes 2cm, and where parts meet they step.
##
## The builders (life size; y = 0 the ground at the front or under the middle):
##   gruenderzeit_house(pk, kit, labels, w, floors, variant, rng, d = 13, number = 0, tables = true)
##                                    front z = 0 facing +z, x 0..w, back -d; 4 storeys: eaves 15.4, ridge ~21; 5: 18.8, ~24.5
##   gruenderzeit_house_far(pk, kit, w, floors, variant, rng, d = 13)   the same house (same rng state) in ~0.5k triangles
##   house_extent(floors, variant, tables = true)  how far a house reaches past z = 0 (steps, ground, awning, upper, max)
##   corner_house(pk, kit, labels, w, d, floors, rng, turret_left = false)  fronts on z = 0 (+z) and x = w (+x), corner cut
##                                    CORNER_CUT, turret 2.3m out of the cut, its finial ~29m (5 storeys)
##   hotel(pk, kit, labels)           x 0..HOTEL_W (46), z -18..0, terrace and steps to z 8.2, winter garden x 0.4..8.6 to 7.6
##   rhine_steps(pk, kit, length, drop, depth) -> real depth   top y = 0 at z = 0, down toward +z; cheeks x -0.6 / length + 0.6
##   quay_wall(pk, kit, length, drop, labels = [], railing = false)  face z = 0 (+z), coping top +0.08, back to z -0.6
##   pavilion_cafe(pk, kit, labels)   hall x 0..14, z -8..0, roof overhang 1.8, terrace to z 7
##   kiosk(pk, kit, labels, kind)     x ±1.6, z ±1.2, hatch +z; "eis", "getraenke", "fahrrad"
##   promenade_lamp, plane_tree_guard, bench, bin (pk, kit)   on the origin (the bench's front edge, facing +z)
##   ferris_wheel_base(pk, kit, labels) / ferris_wheel_rotor(pk, kit) / ferris_wheel_gondola(pk, kit, variant)
##                                    base on the ground under the hub (WHEEL_HUB_Y), rotor round the hub turning about z,
##                                    a gondola hanging from its pivot (WHEEL_PIVOT_R from the hub); 47m to the rim's top
##   chair_swing_base(pk, kit, labels) / chair_swing_rotor(pk, kit) / chair_swing_chair(pk, kit, variant)
##                                    base on the ground under the axis, rotor at SWING_HANG_Y turning about y, a chair
##                                    hanging from its hang point (SWING_HANG_R out)
##   bumper_cars(pk, kit, labels)     centred, x ±14.7, z -10.8..13.3 (steps and booth +z), board to 8.7m
##   stall(pk, kit, labels, kind)     counter z = 0 facing +z, x ±2.75, back -2.5, flap to z 1.65, sign to 4.4m
##   beer_tent(pk, kit, labels)       front gable z = 0 facing +z, x ±11.1, back z -40, ridge 8.4m
##   bunting(pk, kit, a, b, sag), kirmes_fence(pk, kit, length, labels = [])  along +x from the origin

const PropKit = preload("res://PropKit.gd")
const T = preload("res://KronburgTownKit.gd")
const YK = preload("res://YardKit.gd")
const CampKit = preload("res://CampKit.gd")
const LampGlow = preload("res://LampGlow.gd")
const ShopNames = preload("res://ShopNames.gd")

static var uvk := 1.6
static var _mats := {}
## The current sub-assembly's offset inside the kit's own frame (labels are given in kit coordinates).
static var _lx := Transform3D.IDENTITY

const TANGENT_KEYS := ["tile", "iron", "concrete", "zinc", "slate", "biber", "kslate"]
const FOOT := -4.0

const WALLS := [Color(0.91, 0.82, 0.62), Color(0.86, 0.67, 0.40), Color(0.69, 0.78, 0.60), Color(0.88, 0.62, 0.52),
		Color(0.60, 0.69, 0.79), Color(0.92, 0.79, 0.46), Color(0.76, 0.74, 0.69), Color(0.86, 0.66, 0.64), Color(0.80, 0.70, 0.56)]
const WHITE_TRIM := Color(0.96, 0.95, 0.91)
const SAND := Color(0.76, 0.68, 0.54)
const BASALT := Color(0.31, 0.31, 0.32)
const GLASS := Color(0.07, 0.10, 0.13)
const IRON := Color(0.10, 0.11, 0.11)
const SLATE := Color(0.29, 0.30, 0.33)
const ZINC := Color(0.56, 0.58, 0.59)
## The firewalls' and chimneys' brick: at 0.34, 0.20, 0.16 it read black in shade wherever a block's corner showed a firewall.
const BRICK := Color(0.52, 0.29, 0.21)
const RENDER := Color(0.60, 0.58, 0.54)
const GOLD := Color(0.92, 0.72, 0.22)
const REAR := Color(0.72, 0.69, 0.63)
const JUG_GREEN := Color(0.20, 0.40, 0.32)
const COPPER := Color(0.36, 0.62, 0.52)
const BULB := Color(1.0, 0.86, 0.58)
const BULB_COLS := [Color(1.0, 0.86, 0.58), Color(1.0, 0.45, 0.35), Color(0.55, 0.85, 1.0), Color(1.0, 0.95, 0.5), Color(0.6, 1.0, 0.6)]

## The ground-floor shops of the promenade: [name, kind (cafe, eis, restaurant, shop), awning stripes, fascia colour].
const SHOPS := [
	["Café Rheinblick", "cafe", [Color(0.95, 0.92, 0.82), Color(0.12, 0.34, 0.24)], Color(0.11, 0.28, 0.20)],
	["Eiscafé Bellamonte", "eis", [Color(0.97, 0.96, 0.94), Color(0.86, 0.36, 0.48)], Color(0.62, 0.16, 0.28)],
	["Weinstube Treidelpfad", "restaurant", [Color(0.95, 0.91, 0.80), Color(0.48, 0.10, 0.14)], Color(0.38, 0.08, 0.11)],
	["Ristorante Isola Verde", "restaurant", [Color(0.97, 0.96, 0.94), Color(0.16, 0.45, 0.24)], Color(0.12, 0.30, 0.18)],
	["Brauhaus Uferkrone", "restaurant", [Color(0.95, 0.90, 0.78), Color(0.40, 0.24, 0.12)], Color(0.28, 0.17, 0.09)],
	["Buchhandlung Löwenkamp", "shop", [Color(0.95, 0.93, 0.86), Color(0.14, 0.24, 0.46)], Color(0.12, 0.20, 0.38)],
	["Blumen Terhorst", "shop", [Color(0.96, 0.96, 0.92), Color(0.36, 0.52, 0.20)], Color(0.24, 0.36, 0.14)],
	["Konditorei Hülsmann", "cafe", [Color(0.96, 0.93, 0.86), Color(0.80, 0.48, 0.52)], Color(0.38, 0.20, 0.14)],
	["Optik Brammertz", "shop", [Color(0.94, 0.94, 0.93), Color(0.38, 0.40, 0.42)], Color(0.16, 0.17, 0.19)],
	["Feinkost Overbeck", "shop", [Color(0.95, 0.91, 0.80), Color(0.66, 0.16, 0.12)], Color(0.42, 0.12, 0.10)],
]


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"copper":
			var c := StandardMaterial3D.new()
			c.vertex_color_use_as_albedo = true
			c.vertex_color_is_srgb = true
			c.metallic = 0.3
			c.roughness = 0.55
			return c
		"bulb":
			return LampGlow.material(1.35)
		"pennant":
			var p := StandardMaterial3D.new()
			p.vertex_color_use_as_albedo = true
			p.vertex_color_is_srgb = true
			p.roughness = 0.85
			p.cull_mode = BaseMaterial3D.CULL_DISABLED
			return p
		"wglass":
			var g := StandardMaterial3D.new()
			g.vertex_color_use_as_albedo = true
			g.vertex_color_is_srgb = true
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.metallic = 0.35
			g.roughness = 0.06
			return g
	return T.make_material(key)


static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	YK.uvk = scale
	_lx = Transform3D.IDENTITY
	return pk


## The materials made so far, by key (the generator saves them so every mesh shares one per key).
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

## Moves the kit's frame by `t` (a local offset for a sub-assembly, mirrors too); returns the frame to put back with `_pop`.
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


## A profile in a wall frame's (out, up) plane, extruded along the wall from u0 to u1, its end caps closed: cornices,
## string courses, consoles.
static func _mould(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, u1: float, prof: PackedVector2Array, col: Color) -> void:
	var b := Basis(wf.basis.z, wf.basis.y, wf.basis.z.cross(wf.basis.y))
	T._prism(pk, kit, key, Transform3D(b, wf.origin), prof, -u1, -u0, col, Vector2(0, 1), true)


## A slab whose plan is `poly` in a wall frame's (u, out) coordinates, from y0 to y1, top and underside closed.
static func _plan_slab(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, poly: PackedVector2Array, y0: float, y1: float, col: Color) -> void:
	var b := Basis(wf.basis.x, wf.basis.z, wf.basis.x.cross(wf.basis.z))
	T._prism(pk, kit, key, Transform3D(b, wf.origin), poly, -y1, -y0, col, Vector2(0, 1), true)


## Quads between two open rings of points (same count), each facing away from `centre` (a loft's sides).
static func _loft(pk: PropKit, kit: Dictionary, key: String, top: Array, bot: Array, col: Color, centre: Vector3) -> void:
	for i in range(top.size() - 1):
		var a: Vector3 = top[i]
		var b: Vector3 = top[i + 1]
		var c: Vector3 = bot[i + 1]
		var d: Vector3 = bot[i]
		var n: Vector3 = (c - a).cross(b - a)
		if n.length_squared() < 1e-10:
			n = (d - a).cross(b - a)
		n = n.normalized()
		if n.dot((a + b + c + d) * 0.25 - centre) < 0.0:
			n = -n
		pk.quad(kit, key, [a, b, c, d], n, col)


## A polygon (points in order) facing `n`, fanned from its first point (convex).
static func _fan(pk: PropKit, kit: Dictionary, key: String, pts: Array, n: Vector3, col: Color) -> void:
	for i in range(1, pts.size() - 1):
		pk.tri(kit, key, pts[0], pts[i], pts[i + 1], n, n, n, col, n)


## The polyline of a hanging rope from a to b sagging `sag` in its middle (a parabola), `segs` pieces.
static func _sag_pts(a: Vector3, b: Vector3, sag: float, segs: int) -> Array:
	var out: Array = []
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		out.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	return out


## A railing along a polyline at floor level: posts at its corners, bars every `gap`, a top rail and a foot rail.
## `curly` adds a wavy band between the rails (Jugendstil).
static func _railing(pk: PropKit, kit: Dictionary, pts: Array, h: float, col: Color, gap := 0.16, curly := false) -> void:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var len_ab: float = a.distance_to(b)
		if len_ab < 0.01:
			continue
		pk.beam(kit, "steel", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.06, 0.045, col, Vector3.UP)
		pk.beam(kit, "steel", a + Vector3(0, 0.1, 0), b + Vector3(0, 0.1, 0), 0.035, 0.035, col, Vector3.UP)
		var nb: int = maxi(int(len_ab / gap), 1)
		for k in range(nb + 1):
			var p: Vector3 = a.lerp(b, float(k) / float(nb))
			var thick: float = 0.035 if (k == 0 or k == nb) else 0.018
			pk.beam(kit, "steel", p + Vector3(0, 0.1, 0), p + Vector3(0, h, 0), thick, thick, col)
		if curly:
			var wave: Array = []
			var nw: int = maxi(int(len_ab / 0.12), 4)
			for k in range(nw + 1):
				var t: float = float(k) / float(nw)
				wave.append(a.lerp(b, t) + Vector3(0, h * 0.55 + sin(t * len_ab * 9.0) * h * 0.18, 0))
			for k in range(wave.size() - 1):
				pk.beam(kit, "steel", wave[k], wave[k + 1], 0.02, 0.03, col)


## A bistro table (a pedestal and a round top) at c on the ground, with two chairs facing it along x.
static func _bistro_set(pk: PropKit, kit: Dictionary, c: Vector3, top_col: Color, chair_col: Color, chairs := 2) -> void:
	pk.lathe(kit, "metal", c, [Vector2(0.22, 0.0), Vector2(0.22, 0.025), Vector2(0.05, 0.06), Vector2(0.03, 0.70), Vector2(0.001, 0.70)], 8, IRON)
	pk.lathe(kit, "paint", c + Vector3(0, 0.695, 0), [Vector2(0.001, 0.0), Vector2(0.33, 0.0), Vector2(0.34, 0.03), Vector2(0.001, 0.035)], 12, top_col)
	var dirs: Array = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	for i in range(chairs):
		var dd: Vector3 = dirs[i]
		_chair(pk, kit, c + dd * 0.62, -dd, chair_col)


## A bistro chair at c (on the ground) facing `face` (horizontal unit): a seat, four legs, a curved back.
static func _chair(pk: PropKit, kit: Dictionary, c: Vector3, face: Vector3, col: Color) -> void:
	var side: Vector3 = Vector3.UP.cross(face).normalized()
	var bas := Basis(side, Vector3.UP, face)
	YK.box_at(pk, kit, "paint", c + Vector3(0, 0.45, 0), bas, Vector3(0.42, 0.04, 0.42), col)
	for sx in [-0.17, 0.17]:
		for sz in [-0.17, 0.17]:
			pk.beam(kit, "metal", c + side * sx + face * sz, c + side * sx + face * sz + Vector3(0, 0.44, 0), 0.025, 0.025, IRON)
	for sx2 in [-0.17, 0.17]:
		pk.beam(kit, "metal", c + side * sx2 - face * 0.19 + Vector3(0, 0.46, 0), c + side * sx2 - face * 0.24 + Vector3(0, 0.88, 0), 0.025, 0.025, IRON)
	YK.box_at(pk, kit, "paint", c - face * 0.235 + Vector3(0, 0.76, 0), Basis(side, Vector3.UP, face).rotated(side, 0.12), Vector3(0.40, 0.2, 0.025), col)


## A square market parasol at c (on the ground): a weighted foot, a pole, four canvas panels and their underside, a
## valance; `s` its half width.
static func _parasol(pk: PropKit, kit: Dictionary, c: Vector3, s: float, col: Color, trim: Color) -> void:
	pk.lathe(kit, "paint", c, [Vector2(0.001, 0.0), Vector2(0.32, 0.0), Vector2(0.3, 0.12), Vector2(0.001, 0.13)], 8, Color(0.3, 0.3, 0.3))
	pk.tube(kit, "wood", c + Vector3(0, 0.1, 0), c + Vector3(0, 2.75, 0), 0.03, 0.03, 6, Color(0.55, 0.40, 0.24), true)
	var top: Vector3 = c + Vector3(0, 2.7, 0)
	var eave: float = 2.25
	var corners: Array = [Vector3(-s, 0, -s), Vector3(s, 0, -s), Vector3(s, 0, s), Vector3(-s, 0, s)]
	for k in range(4):
		var a: Vector3 = c + corners[k] + Vector3(0, eave, 0)
		var b: Vector3 = c + corners[(k + 1) % 4] + Vector3(0, eave, 0)
		var n: Vector3 = (b - a).cross(top - a).normalized()
		if n.y < 0.0:
			n = -n
		pk.tri(kit, "canvas", a, b, top, n, n, n, col, n)
		pk.tri(kit, "canvas", a - Vector3(0, 0.02, 0), b - Vector3(0, 0.02, 0), top - Vector3(0, 0.02, 0), -n, -n, -n, col.darkened(0.35), -n)
		var o: Vector3 = Vector3(corners[k] + corners[(k + 1) % 4]).normalized()
		o = Vector3(o.x, 0, o.z).normalized()
		pk.panel(kit, "canvas", [a, b, b - Vector3(0, 0.22, 0), a - Vector3(0, 0.22, 0)], o, trim, trim.darkened(0.3))


## A simple bicycle standing on the ground at c, its wheels along `along` (horizontal unit).
static func _bicycle(pk: PropKit, kit: Dictionary, c: Vector3, along: Vector3, col: Color) -> void:
	var side: Vector3 = Vector3.UP.cross(along).normalized()
	var r := 0.34
	for sx in [-0.52, 0.52]:
		var wc: Vector3 = c + along * sx + Vector3(0, r, 0)
		for k in range(10):
			var a0: float = TAU * float(k) / 10.0
			var a1: float = TAU * float(k + 1) / 10.0
			pk.tube(kit, "rubber", wc + (along * cos(a0) + Vector3.UP * sin(a0)) * (r - 0.02), wc + (along * cos(a1) + Vector3.UP * sin(a1)) * (r - 0.02), 0.022, 0.022, 3,
					Color(0.08, 0.08, 0.08), false)
		pk.tube(kit, "metal", wc - side * 0.04, wc + side * 0.04, 0.04, 0.04, 5, Color(0.7, 0.7, 0.72), true)
	var rear: Vector3 = c + along * -0.52 + Vector3(0, r, 0)
	var front: Vector3 = c + along * 0.52 + Vector3(0, r, 0)
	var crank: Vector3 = c + along * -0.05 + Vector3(0, 0.3, 0)
	var seat: Vector3 = c + along * -0.18 + Vector3(0, 0.82, 0)
	var head: Vector3 = c + along * 0.38 + Vector3(0, 0.86, 0)
	for seg in [[rear, crank], [rear, seat], [crank, seat], [seat, head], [crank, head], [head, front]]:
		pk.tube(kit, "paint", seg[0], seg[1], 0.018, 0.018, 5, col, false)
	pk.beam(kit, "matte", seat + Vector3(0, 0.05, 0) - along * 0.05, seat + Vector3(0, 0.05, 0) + along * 0.14, 0.12, 0.05, Color(0.1, 0.1, 0.1))
	pk.tube(kit, "metal", head + Vector3(0, 0.12, 0) - side * 0.26, head + Vector3(0, 0.12, 0) + side * 0.26, 0.015, 0.015, 5, Color(0.7, 0.7, 0.72))
	pk.tube(kit, "metal", head, head + Vector3(0, 0.12, 0), 0.018, 0.018, 5, Color(0.7, 0.7, 0.72), false)
	pk.beam(kit, "paint", rear + Vector3(0, r + 0.05, 0) - along * 0.1, rear + Vector3(0, r + 0.05, 0) + along * 0.35, 0.12, 0.02, col.darkened(0.2))


# ======================================================================================
#  Gründerzeit houses: planning
# ======================================================================================

## Every random choice of a Gründerzeit house, drawn once in a fixed order, so the detailed and the far builders of the
## same (w, floors, variant, rng state) make the same house.
static func _gz_plan(w: float, floors: int, variant: int, rng: RandomNumberGenerator, d: float) -> Dictionary:
	var v: int = posmod(variant, 4)
	var n: int = clampi(floors, 3, 6)
	var p := {"v": v, "n": n, "w": w, "d": d}
	var wall: Color = WALLS[rng.randi() % WALLS.size()]
	wall = wall.lightened(rng.randf_range(-0.03, 0.04))
	var tr: float = rng.randf()
	var trim: Color = WHITE_TRIM if tr < 0.6 else (wall.lightened(0.45) if tr < 0.85 else SAND.lightened(0.12))
	var frame: Color = WHITE_TRIM
	if v == 3:
		wall = [Color(0.93, 0.88, 0.74), Color(0.80, 0.86, 0.76), Color(0.92, 0.84, 0.70), Color(0.78, 0.84, 0.86)][rng.randi() % 4]
		trim = WHITE_TRIM.lightened(0.02)
		frame = [JUG_GREEN, Color(0.36, 0.22, 0.14), Color(0.16, 0.26, 0.40)][rng.randi() % 3]
	p["wall"] = wall
	p["trim"] = trim
	p["frame"] = frame
	p["ground"] = "ashlar" if rng.randf() < 0.4 else "plaster"
	p["plinth"] = BASALT if rng.randf() < 0.55 else SAND.darkened(0.18)
	var base_h: Array = [4.5, 3.9, 3.55, 3.4, 3.25, 3.1]
	var hs: Array = []
	var ys: Array = []
	var y := 0.0
	for k in range(n):
		var h: float = float(base_h[k]) + rng.randf_range(-0.06, 0.06)
		ys.append(y)
		hs.append(h)
		y += h
	p["hs"] = hs
	p["ys"] = ys
	p["G"] = hs[0]
	p["YE"] = y
	var na: int = clampi(int(round((w - 0.6) / 2.8)), 2, 8)
	p["na"] = na
	p["ww"] = clampf((w - 0.6) / float(na) * 0.43, 0.95, 1.3)
	p["door"] = 0 if rng.randf() < 0.5 else na - 1
	var sh: float = rng.randf()
	p["shop"] = -1 if sh < 0.14 else rng.randi() % SHOPS.size()
	p["erker"] = -1
	if v == 1 and na >= 3:
		p["erker"] = na / 2
		if p["erker"] == p["door"]:
			p["erker"] = 1
	elif v == 3 and na >= 3:
		p["erker"] = na - 2 if p["door"] == 0 else 1
	var bal: Array = []
	if na >= 3 and v != 1:
		var mid: int = na / 2
		if v != 3 or mid != p["erker"]:
			bal.append([1, mid])
		if v == 0 and rng.randf() < 0.5 and n >= 4:
			bal.append([2, mid])
	if v == 3 and n >= 4:
		bal.append([2, p["door"]])
	p["balconies"] = bal
	p["hood1"] = ["alt", "tri", "seg"][rng.randi() % 3]
	p["hood2"] = "flat" if rng.randf() < 0.7 else "seg"
	p["dormer_hood"] = "tri" if rng.randf() < 0.5 else "seg"
	p["dormers_every"] = rng.randf() < 0.6
	p["upper_key"] = "zinc" if rng.randf() < 0.6 else "kslate"
	p["gable"] = []
	if v == 2 and na >= 3:
		var m: int = na / 2
		p["gable"] = [m - 1, m + 1] if na % 2 == 1 else [m - 1, m]
	p["chimneys"] = 2 + rng.randi() % 2
	p["seed"] = rng.randi()
	p["firewall_render"] = rng.randf() < 0.5
	return p


## The window axes of a facade of length L (positions along it).
static func _axes(L: float, na: int) -> Array:
	var out: Array = []
	for i in range(na):
		out.append(0.3 + (L - 0.6) * (float(i) + 0.5) / float(na))
	return out


## How far a Gründerzeit house reaches out past its front (z = 0) toward the street (+z), life size, whatever its draws:
## "steps" its door steps (on the ground), "ground" anything on the pavement (a café's or restaurant's tables and chairs,
## below 1.2m), "awning" a shop's awning (from 2.5m up), "upper" its balconies, bay (Erker) and cornice (from 4.4m up),
## "max" the most of them. `tables` false leaves the pavement tables out.
static func house_extent(floors: int, variant: int, tables := true) -> Dictionary:
	var _n: int = clampi(floors, 3, 6)
	var v: int = posmod(variant, 4)
	var steps := 0.62
	var ground: float = 2.45 if tables else steps
	var awning := 2.05
	var upper: float = 1.15
	if v == 1 or v == 3:
		upper = maxf(upper, 0.95)
	return {"steps": steps, "ground": ground, "awning": awning, "upper": upper, "max": maxf(ground, maxf(awning, upper))}


# ======================================================================================
#  Gründerzeit houses: the detailed builder
# ======================================================================================

## A Gründerzeit apartment house (Altbau, 1890-1905), `w` wide along the street and `d` deep, `floors` storeys (3-6, the
## ground floor counted), in the building frame (front z = 0 facing +z, x 0..w, back z = -d, footings to FOOT). A
## rusticated ground floor (stucco or sandstone) with a shop, café or restaurant (awning, its name on the fascia, tables on
## the pavement for cafés and restaurants) or flats, a tall entrance door with a fanlight; stucco upper storeys in a
## pastel colour with window surrounds, pediments and keystones, sill bands, a string course and a main cornice on
## consoles; a mansard roof (slate, zinc on top) with dormers and chimneys on brick firewalls; a plain rendered back.
## `variant` % 4: 0 plain with balconies, 1 a canted bay (Erker) on the middle axis with a balcony on top, 2 a decorated
## gable over the middle axes, 3 Jugendstil (asymmetric bay, a bell gable over it, arched top windows, a tile frieze,
## curly railings). `number` (> 0) puts a blue house-number plate by the door. Reaches out as `house_extent` says.
## About 9-14k triangles; `gruenderzeit_house_far` is the same house in about 1.5k.
static func gruenderzeit_house(pk: PropKit, kit: Dictionary, labels: Array, w: float, floors: int, variant: int, rng: RandomNumberGenerator,
		d := 13.0, number := 0, tables := true) -> void:
	var p := _gz_plan(w, floors, variant, rng, d)
	var drng := RandomNumberGenerator.new()
	drng.seed = int(p["seed"])
	var fwf := T._wf(Vector3.ZERO, Vector3(0, 0, 1))
	var opts := {"door": p["door"], "shop": p["shop"], "erker": p["erker"], "gable": p["gable"], "balconies": p["balconies"],
			"number": number, "tables": tables}
	_gz_facade(pk, kit, labels, fwf, w, p, opts, drng)
	_gz_back(pk, kit, p, drng)
	_gz_mansard(pk, kit, p, drng)
	if not (p["gable"] as Array).is_empty():
		_gz_gable(pk, kit, fwf, p, drng)
	if int(p["v"]) == 3 and int(p["erker"]) >= 0:
		_gz_bell_gable(pk, kit, fwf, p)


## The front of a Gründerzeit house in a wall frame `wf` (u along it, 0..L, v up, out of it): the walls, the ground floor,
## the upper storeys' windows, bands, balconies, the bay, the main cornice. `opts`: door (axis), shop (SHOPS index or -1),
## erker (axis or -1), balconies ([storey, axis] ...), number, tables, and "ground_mode" ("shop", "res", "hotel").
static func _gz_facade(pk: PropKit, kit: Dictionary, labels: Array, wf: Transform3D, L: float, p: Dictionary, opts: Dictionary,
		drng: RandomNumberGenerator) -> void:
	var n: int = p["n"]
	var hs: Array = p["hs"]
	var ys: Array = p["ys"]
	var G: float = p["G"]
	var YE: float = p["YE"]
	var wall: Color = p["wall"]
	var trim: Color = p["trim"]
	var jug: bool = int(p["v"]) == 3
	var na: int = int(opts.get("na", p["na"]))
	var ax := _axes(L, na)
	var ww: float = p["ww"]
	var door: int = opts.get("door", -1)
	var erker: int = opts.get("erker", -1)
	var bal: Array = opts.get("balconies", [])
	# The walls: the plinth, the ground floor (sandstone, or stucco to be rusticated), the stucco above.
	T._rect(pk, kit, "stone", wf, 0.0, FOOT, L, 0.45, 0.0, 0.06, p["plinth"])
	var gkey: String = p["ground"]
	var gcol: Color = SAND.lightened(0.06) if gkey == "ashlar" else wall.lerp(trim, 0.35)
	T._face(pk, kit, "ashlar" if gkey == "ashlar" else "plaster", wf, 0.0, 0.45, L, G, 0.0, gcol)
	T._face(pk, kit, "plaster", wf, 0.0, G, L, YE, 0.0, wall)
	# The facade's thickness at its ends (the firewalls stand 5cm back).
	for e in [[0.0, -1.0], [L, 1.0]]:
		var ue: float = e[0]
		var nrm: Vector3 = (wf.basis.x * float(e[1])).normalized()
		pk.quad(kit, "plaster", [wf * Vector3(ue, FOOT, -0.05), wf * Vector3(ue, FOOT, 0.0), wf * Vector3(ue, YE, 0.0), wf * Vector3(ue, YE, -0.05)], nrm, wall)
	# The ground floor.
	var mode: String = opts.get("ground_mode", "shop" if int(opts.get("shop", -1)) >= 0 else "res")
	_gz_ground(pk, kit, labels, wf, L, p, ax, door, mode, opts, drng)
	# The string course over the ground floor.
	_mould(pk, kit, "plaster", wf, 0.0, L, PackedVector2Array([Vector2(0.0, G - 0.26), Vector2(0.1, G - 0.26), Vector2(0.12, G - 0.2),
			Vector2(0.2, G - 0.12), Vector2(0.22, G - 0.02), Vector2(0.0, G - 0.02)]), trim)
	_mould(pk, kit, "plaster", wf, 0.0, L, PackedVector2Array([Vector2(0.0, G - 0.02), Vector2(0.06, G - 0.02), Vector2(0.06, G + 0.06), Vector2(0.0, G + 0.06)]),
			trim.darkened(0.05))
	# Lisenen up both ends of the upper facade.
	var lc: Color = wall.lerp(trim, 0.45)
	# (5mm in from the facade's ends: the bands' end caps lie in the end planes.)
	T._rect(pk, kit, "plaster", wf, 0.005, G + 0.06, 0.42, YE - 0.78, 0.0, 0.04, lc)
	T._rect(pk, kit, "plaster", wf, L - 0.42, G + 0.06, L - 0.005, YE - 0.78, 0.0, 0.04, lc)
	# Upper storeys.
	var bay_top: int = n - 2
	var has_bay: bool = erker >= 0 and n >= 4
	if not has_bay:
		erker = -1
	for k in range(1, n):
		var y0: float = ys[k]
		var h: float = hs[k]
		var top_storey: bool = k == n - 1
		var v0: float = y0 + (0.8 if k == 1 else 0.9)
		var v1: float = y0 + h - (0.5 if top_storey else 0.55)
		var hood: String = "key"
		if k == 1:
			hood = p["hood1"]
		elif k == 2 and n > 3:
			hood = p["hood2"]
		if jug:
			hood = "jug1" if k == 1 else ("arch" if top_storey else "flat")
			if hood == "arch":
				# Its round head and keystone must stay under the frieze.
				v1 = minf(v1, YE - 0.85 - ww * 0.5 - 0.32)
		# A sill band under the windows (not on the Beletage, which has its aprons), broken for balcony doors.
		if k >= 2:
			var cuts: Array = []
			for b0 in bal:
				if int(b0[0]) == k:
					cuts.append(float(ax[int(b0[1])]))
			if has_bay and k == bay_top + 1:
				cuts.append(float(ax[erker]))
			cuts.sort()
			var at := 0.0
			var segs: Array = []
			for cu in cuts:
				segs.append([at, float(cu) - ww * 0.5 - 0.34])
				at = float(cu) + ww * 0.5 + 0.34
			segs.append([at, L])
			for sg in segs:
				if float(sg[1]) - float(sg[0]) > 0.05:
					_mould(pk, kit, "plaster", wf, sg[0], sg[1], PackedVector2Array([Vector2(0.0, v0 - 0.2), Vector2(0.05, v0 - 0.2), Vector2(0.08, v0 - 0.15),
							Vector2(0.08, v0 - 0.05), Vector2(0.0, v0 - 0.05)]), trim)
		for i in range(na):
			var u: float = ax[i]
			if i == erker and k >= 1 and k <= bay_top:
				continue
			var is_bal := false
			for b in bal:
				if int(b[0]) == k and int(b[1]) == i:
					is_bal = true
			var on_bay: bool = i == erker and k == bay_top + 1
			var bal_above := false
			for b2 in bal:
				if int(b2[0]) == k + 1 and int(b2[1]) == i:
					bal_above = true
			var hd: String = hood
			if hood == "alt":
				hd = "tri" if (i == 0 or i == na - 1) else "seg"
			if bal_above:
				hd = "none"
			if is_bal or on_bay:
				# A balcony door: glazed from the floor up to the window head.
				_gz_balcony_door(pk, kit, wf, u, y0 + 0.14, v1, ww + 0.1, p)
				_gz_surround(pk, kit, wf, u, y0 + 0.14, v1, ww + 0.1, trim, hd, false, false, p["frame"])
				if is_bal:
					var shop_below: bool = k == 1 and (int(opts.get("shop", -1)) >= 0 or mode == "hotel")
					_balcony(pk, kit, wf, u, y0, ww * 0.5 + 0.75, 0.95, trim, jug, 0.5 if shop_below else 1.05)
			else:
				_gz_window(pk, kit, wf, u, v0, v1, ww, p["frame"], jug and (k == 1 or top_storey))
				_gz_surround(pk, kit, wf, u, v0, v1, ww, trim, hd, k == 1, true, p["frame"])
	# The bay (Erker) and its balcony.
	if erker >= 0 and n >= 4:
		_gz_erker(pk, kit, wf, ax[erker], p)
	# The main cornice: a frieze, consoles, the corona.
	var fcol: Color = trim if not jug else Color(0.20, 0.46, 0.38)
	T._rect(pk, kit, "plaster" if not jug else "enamel", wf, 0.0, YE - 0.78, L, YE - 0.34, 0.0, 0.03, fcol)
	if jug:
		var nt: int = int(L / 0.55)
		for k2 in range(nt):
			var tu: float = (float(k2) + 0.5) * L / float(nt)
			T._rect(pk, kit, "gold", wf, tu - 0.07, YE - 0.63, tu + 0.07, YE - 0.49, 0.03, 0.045, GOLD)
	var nc: int = int((L - 0.3) / 0.62)
	for k3 in range(nc + 1):
		var cu: float = 0.15 + (L - 0.3) * float(k3) / float(nc)
		_mould(pk, kit, "plaster", wf, cu - 0.08, cu + 0.08, PackedVector2Array([Vector2(0.0, YE - 0.62), Vector2(0.1, YE - 0.62), Vector2(0.12, YE - 0.48),
				Vector2(0.44, YE - 0.26), Vector2(0.48, YE - 0.13), Vector2(0.0, YE - 0.13)]), trim)
	_mould(pk, kit, "plaster", wf, -0.02, L + 0.02, PackedVector2Array([Vector2(0.0, YE - 0.34), Vector2(0.1, YE - 0.34), Vector2(0.1, YE - 0.18),
			Vector2(0.58, YE - 0.13), Vector2(0.6, YE + 0.02), Vector2(0.68, YE + 0.08), Vector2(0.7, YE + 0.2), Vector2(0.62, YE + 0.26),
			Vector2(0.0, YE + 0.26)]), trim)


## The ground floor's front: the rusticated piers, the house door (and steps), a shop (windows, a glazed door, the fascia
## with its name, an awning, café tables) or flats' windows over cellar lights, or a hotel's arched French windows.
static func _gz_ground(pk: PropKit, kit: Dictionary, labels: Array, wf: Transform3D, L: float, p: Dictionary, ax: Array, door: int, mode: String,
		opts: Dictionary, drng: RandomNumberGenerator) -> void:
	var G: float = p["G"]
	var trim: Color = p["trim"]
	var na: int = ax.size()
	var sp: float = (L - 0.6) / float(na)
	var shop_i: int = opts.get("shop", -1)
	var shop: Array = SHOPS[shop_i] if shop_i >= 0 else []
	var fascia: Color = shop[3] if shop_i >= 0 else Color(0.2, 0.2, 0.2)
	var openings: Array = []
	var sw: float = sp - 0.7
	var run0 := INF
	var run1 := -INF
	var shop_door: int = -1
	if mode == "shop":
		shop_door = door + 1 if door == 0 else door - 1
		if na <= 2:
			shop_door = -1
	for i in range(na):
		var u: float = ax[i]
		if i == door and mode == "hotel":
			# The hotel's door opens onto its terrace: a glazed double door under a fanlight in a round arch.
			_gz_arched_window(pk, kit, wf, u, HOTEL_TERRACE_Y + 0.02, G - 0.45, 1.9, Color(0.16, 0.22, 0.18), trim)
			openings.append([u - 1.3, u + 1.3])
			continue
		if i == door:
			_gz_house_door(pk, kit, wf, u, p, trim)
			openings.append([u - 1.0, u + 1.0])
			if int(opts.get("number", 0)) > 0:
				var nu: float = u + 1.25 if i == 0 else u - 1.25
				T._rect(pk, kit, "enamel", wf, nu - 0.15, 2.25, nu + 0.15, 2.47, 0.0, 0.065, Color(0.10, 0.22, 0.52))
				T._rect(pk, kit, "enamel", wf, nu - 0.13, 2.27, nu + 0.13, 2.45, 0.065, 0.07, Color(0.97, 0.97, 0.95))
				T._rect(pk, kit, "enamel", wf, nu - 0.115, 2.285, nu + 0.115, 2.435, 0.07, 0.076, Color(0.10, 0.22, 0.52))
				_label(labels, str(int(opts["number"])), wf * Vector3(nu, 2.36, 0.085), wf.basis.z, 0.1, Color(0.98, 0.98, 0.96), 0.2)
			continue
		if mode == "shop":
			var x0: float = u - sw * 0.5
			var x1: float = u + sw * 0.5
			run0 = minf(run0, x0)
			run1 = maxf(run1, x1)
			openings.append([x0 - 0.1, x1 + 0.1])
			if i == shop_door:
				_gz_shop_door(pk, kit, wf, u, sw, fascia)
			else:
				_gz_shop_window(pk, kit, wf, u, sw, fascia)
		elif mode == "hotel":
			openings.append([u - _ww_half(p) - 0.3, u + _ww_half(p) + 0.3])
			_gz_arched_window(pk, kit, wf, u, 1.0, G - 0.6, p["ww"] + 0.2, p["frame"], trim)
		else:
			var wwr: float = p["ww"]
			openings.append([u - wwr * 0.5 - 0.2, u + wwr * 0.5 + 0.2])
			_gz_window(pk, kit, wf, u, 1.35, G - 0.85, wwr, p["frame"], false)
			_gz_surround(pk, kit, wf, u, 1.35, G - 0.85, wwr, trim, "key", true)
			# A cellar light in the plinth, behind a grille.
			T._rect(pk, kit, "matte", wf, u - 0.4, 0.1, u + 0.4, 0.36, 0.06, 0.07, Color(0.05, 0.05, 0.06))
			for k in range(5):
				var gx: float = u - 0.32 + 0.16 * float(k)
				T._rect(pk, kit, "steel", wf, gx - 0.012, 0.1, gx + 0.012, 0.36, 0.07, 0.095, IRON)
	# Rustication: bands across every pier between the openings (stucco ground floors).
	if String(p["ground"]) == "plaster":
		openings.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
		var piers: Array = []
		var at := 0.0
		for o in openings:
			if float(o[0]) - at > 0.12:
				piers.append([at, float(o[0])])
			at = maxf(at, float(o[1]))
		if L - at > 0.12:
			piers.append([at, L])
		var rc: Color = p["wall"].lerp(trim, 0.5)
		for pr in piers:
			var y := 0.5
			while y + 0.39 < G - 0.3:
				T._rect(pk, kit, "plaster", wf, float(pr[0]) + 0.005, y, float(pr[1]) - 0.005, y + 0.39, 0.0, 0.035, rc)
				y += 0.45
	if mode != "shop" or run1 < run0:
		return
	# The fascia over the shop windows with the shop's name, and an awning over them.
	T._rect(pk, kit, "painted", wf, run0 - 0.25, 3.32, run1 + 0.25, 3.98, 0.0, 0.08, fascia)
	T._rect(pk, kit, "painted", wf, run0 - 0.17, 3.38, run1 + 0.17, 3.92, 0.08, 0.1, fascia.darkened(0.3))
	# Each shop's own name (ShopNames): SHOPS' were drawn at random and the same café stood down the street three times.
	_label(labels, ShopNames.unique(String(shop[1]), String(shop[0])), wf * Vector3((run0 + run1) * 0.5, 3.65, 0.12), wf.basis.z, 0.3,
			GOLD.lightened(0.15), run1 - run0 + 0.1)
	var kind: String = shop[1]
	if kind != "shop" or drng.randf() < 0.5:
		_awning(pk, kit, wf, run0 - 0.15, run1 + 0.15, 3.28, 1.9, 0.55, shop[2])
	if bool(opts.get("tables", true)) and kind != "shop":
		for i in range(na):
			if i == door or i == shop_door:
				continue
			var tc: Vector3 = wf * Vector3(float(ax[i]), 0.0, 1.55)
			var cc: Color = shop[3] if kind != "eis" else Color(0.92, 0.9, 0.86)
			_bistro_set(pk, kit, tc, Color(0.92, 0.91, 0.88), cc)


static func _ww_half(p: Dictionary) -> float:
	return float(p["ww"]) * 0.5 + 0.1


## A striped awning on the wall frame from u0 to u1, its top on the wall at y, `reach` out and `drop` down, a scalloped
## valance, its arms (and their undersides: it is seen from below).
static func _awning(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, u1: float, y: float, reach: float, drop: float, stripes: Array) -> void:
	var nstr: int = maxi(int((u1 - u0) / 0.34), 4)
	var nrm: Vector3 = (wf.basis * Vector3(0, reach, drop)).normalized()
	var fz: Vector3 = wf.basis.z
	for k in range(nstr):
		var xa: float = lerpf(u0, u1, float(k) / float(nstr))
		var xb: float = lerpf(u0, u1, float(k + 1) / float(nstr))
		var c: Color = stripes[k % 2]
		pk.quad(kit, "canvas", [wf * Vector3(xa, y, 0.05), wf * Vector3(xb, y, 0.05), wf * Vector3(xb, y - drop, reach), wf * Vector3(xa, y - drop, reach)], nrm, c)
		pk.quad(kit, "canvas", [wf * Vector3(xa, y - 0.02, 0.05), wf * Vector3(xa, y - drop - 0.02, reach), wf * Vector3(xb, y - drop - 0.02, reach),
				wf * Vector3(xb, y - 0.02, 0.05)], -nrm, c.darkened(0.3))
		var vy: float = y - drop
		pk.panel(kit, "canvas", [wf * Vector3(xa, vy, reach + 0.01), wf * Vector3(xb, vy, reach + 0.01), wf * Vector3(xb, vy - 0.22, reach + 0.01),
				wf * Vector3(xa, vy - 0.22, reach + 0.01)], fz, c, c.darkened(0.3))
		pk.tri(kit, "canvas", wf * Vector3(xa, vy - 0.22, reach + 0.01), wf * Vector3(xb, vy - 0.22, reach + 0.01), wf * Vector3((xa + xb) * 0.5, vy - 0.32, reach + 0.01),
				fz, fz, fz, c, fz)
		pk.tri(kit, "canvas", wf * Vector3(xa, vy - 0.22, reach + 0.005), wf * Vector3((xa + xb) * 0.5, vy - 0.32, reach + 0.005), wf * Vector3(xb, vy - 0.22, reach + 0.005),
				-fz, -fz, -fz, c.darkened(0.3), -fz)
	for au in [u0 + 0.05, u1 - 0.05]:
		pk.beam(kit, "steel", wf * Vector3(au, y - 0.95, 0.03), wf * Vector3(au, y - drop + 0.03, reach - 0.05), 0.045, 0.045, IRON)
	pk.tube(kit, "steel", wf * Vector3(u0, y - drop - 0.03, reach), wf * Vector3(u1, y - drop - 0.03, reach), 0.035, 0.035, 6, IRON)
	pk.tube(kit, "metal", wf * Vector3(u0, y + 0.05, 0.12), wf * Vector3(u1, y + 0.05, 0.12), 0.09, 0.09, 8, Color(0.55, 0.56, 0.57))


## A shop window on axis u, `sw` wide: a stall riser, the plate glass, its frame and transom bar in the shop's colour.
static func _gz_shop_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, sw: float, col: Color) -> void:
	var x0: float = u - sw * 0.5
	var x1: float = u + sw * 0.5
	T._rect(pk, kit, "painted", wf, x0, 0.45, x1, 0.82, 0.0, 0.06, col)
	T._rect(pk, kit, "painted", wf, x0 + 0.12, 0.52, x1 - 0.12, 0.75, 0.06, 0.075, col.lightened(0.12))
	T._face(pk, kit, "pane", wf, x0 + 0.03, 0.82, x1 - 0.03, 3.2, 0.02, GLASS.lightened(0.04))
	T._ring_rect(pk, kit, "painted", wf, x0, 0.82, x1, 3.28, 0.09, 0.0, 0.07, col)
	T._face(pk, kit, "painted", wf, x0 + 0.09, 2.55, x1 - 0.09, 2.62, 0.045, col)
	if sw > 2.0:
		T._face(pk, kit, "painted", wf, u - 0.035, 0.91, u + 0.035, 2.55, 0.045, col)
	for k in range(1, 4):
		var bx: float = lerpf(x0 + 0.09, x1 - 0.09, float(k) / 4.0)
		T._face(pk, kit, "painted", wf, bx - 0.02, 2.62, bx + 0.02, 3.19, 0.045, col)


## A shop door on axis u in a shop front `sw` wide: a glazed door with a transom, glazed side panels.
static func _gz_shop_door(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, sw: float, col: Color) -> void:
	var x0: float = u - sw * 0.5
	var x1: float = u + sw * 0.5
	T._face(pk, kit, "pane", wf, x0 + 0.03, 0.85, u - 0.6, 3.2, 0.02, GLASS.lightened(0.04))
	T._face(pk, kit, "pane", wf, u + 0.6, 0.85, x1 - 0.03, 3.2, 0.02, GLASS.lightened(0.04))
	T._rect(pk, kit, "painted", wf, x0, 0.45, u - 0.6, 0.85, 0.0, 0.06, col)
	T._rect(pk, kit, "painted", wf, u + 0.6, 0.45, x1, 0.85, 0.0, 0.06, col)
	T._ring_rect(pk, kit, "painted", wf, x0, 0.45, x1, 3.28, 0.09, 0.0, 0.07, col)
	T._rect(pk, kit, "painted", wf, u - 0.66, 0.45, u - 0.54, 3.2, 0.0, 0.07, col)
	T._rect(pk, kit, "painted", wf, u + 0.54, 0.45, u + 0.66, 3.2, 0.0, 0.07, col)
	T._face(pk, kit, "pane", wf, u - 0.54, 0.6, u + 0.54, 2.55, 0.03, GLASS)
	T._ring_rect(pk, kit, "painted", wf, u - 0.54, 0.12, u + 0.54, 2.62, 0.1, 0.0, 0.065, col.lightened(0.08))
	T._face(pk, kit, "painted", wf, u - 0.44, 0.22, u + 0.44, 0.6, 0.04, col.lightened(0.08))
	T._face(pk, kit, "pane", wf, u - 0.54, 2.62, u + 0.54, 3.2, 0.02, GLASS)
	pk.tube(kit, "gold", wf * Vector3(u + 0.32, 1.1, 0.065), wf * Vector3(u + 0.32, 1.5, 0.065), 0.018, 0.018, 6, GOLD)
	T._rect(pk, kit, "ashlar", wf, u - 0.7, -0.4, u + 0.7, 0.1, 0.0, 0.32, SAND)


## The house door on axis u: a tall panelled double door with a fanlight under a stone surround, steps up to it.
static func _gz_house_door(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, p: Dictionary, trim: Color) -> void:
	var dc: Color = [Color(0.36, 0.22, 0.12), Color(0.14, 0.28, 0.20), Color(0.42, 0.12, 0.10), Color(0.16, 0.22, 0.34)][int(p["seed"]) % 4]
	var sur: Color = SAND.lightened(0.1) if String(p["ground"]) == "ashlar" else trim
	T._door(pk, kit, wf, u, 0.3, 1.4, 2.75, dc, "ashlar" if String(p["ground"]) == "ashlar" else "plaster", sur, 0.0, 0.6, false)


## A Gründerzeit window: white frame, a transom bar at about three quarters with the casements' meeting stile under it,
## dark glass; `small` divides the upper lights into small panes (Jugendstil).
static func _gz_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, ww: float, frame: Color, small := false) -> void:
	var x0: float = u - ww * 0.5
	var x1: float = u + ww * 0.5
	var F := 0.08
	T._face(pk, kit, "pane", wf, x0 + 0.03, v0 + 0.03, x1 - 0.03, v1 - 0.03, 0.02, GLASS)
	T._ring_rect(pk, kit, "painted", wf, x0, v0, x1, v1, F, 0.0, 0.06, frame)
	var tv: float = lerpf(v0, v1, 0.72)
	T._face(pk, kit, "painted", wf, x0 + F, tv - 0.035, x1 - F, tv + 0.035, 0.045, frame)
	T._face(pk, kit, "painted", wf, u - 0.035, v0 + F, u + 0.035, tv - 0.035, 0.045, frame)
	if small:
		for k in range(1, 3):
			var bx: float = lerpf(x0 + F, x1 - F, float(k) / 3.0)
			T._face(pk, kit, "painted", wf, bx - 0.018, tv + 0.035, bx + 0.018, v1 - F, 0.045, frame)
		var hy: float = (tv + v1) * 0.5
		T._face(pk, kit, "painted", wf, x0 + F, hy - 0.018, _bx_left(x0, x1, F), hy + 0.018, 0.046, frame)
		T._face(pk, kit, "painted", wf, _bx_right(x0, x1, F), hy - 0.018, x1 - F, hy + 0.018, 0.046, frame)


static func _bx_left(x0: float, x1: float, f: float) -> float:
	return lerpf(x0 + f, x1 - f, 1.0 / 3.0) - 0.018


static func _bx_right(x0: float, x1: float, f: float) -> float:
	return lerpf(x0 + f, x1 - f, 2.0 / 3.0) + 0.018


## A balcony door (French window) from the floor v0 to v1: two glazed leaves and a transom light.
static func _gz_balcony_door(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, ww: float, p: Dictionary) -> void:
	var x0: float = u - ww * 0.5
	var x1: float = u + ww * 0.5
	var fr: Color = p["frame"]
	T._face(pk, kit, "pane", wf, x0 + 0.03, v0 + 0.03, x1 - 0.03, v1 - 0.03, 0.02, GLASS)
	T._ring_rect(pk, kit, "painted", wf, x0, v0, x1, v1, 0.08, 0.0, 0.06, fr)
	var tv: float = v1 - 0.55
	T._face(pk, kit, "painted", wf, x0 + 0.08, tv - 0.035, x1 - 0.08, tv + 0.035, 0.045, fr)
	T._face(pk, kit, "painted", wf, u - 0.035, v0 + 0.08, u + 0.035, tv - 0.035, 0.045, fr)
	for sx in [-1.0, 1.0]:
		var a: float = u + sx * 0.035
		var b: float = u + sx * (ww * 0.5 - 0.08)
		T._face(pk, kit, "painted", wf, minf(a, b), v0 + 0.08, maxf(a, b), v0 + 0.55, 0.04, fr)


## The surround of a window [u ± ww/2] x [v0, v1]: jambs and a head 16cm wide standing 5cm proud, and its hood: "key"
## (ears and a keystone), "flat" (a frieze and a cornice on two consoles), "tri" or "seg" (a pediment on a cornice and
## consoles), "jug1" (a flat hood with a medallion of leaves over it), "arch" (a round-arched head: the window gets a
## fanlight), "none". `beletage` adds a sill on consoles and an apron panel under it.
static func _gz_surround(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, ww: float, trim: Color, hood: String, beletage: bool,
		sill := true, frame := WHITE_TRIM) -> void:
	var x0: float = u - ww * 0.5
	var x1: float = u + ww * 0.5
	var f := 0.16
	if hood == "arch":
		# A round head over the window: a fanlight of radiating bars inside an arched surround with a keystone.
		var half: float = ww * 0.5
		T._pface(pk, kit, "pane", wf, T._arch(u, v1, half, "round", 10), 0.02, GLASS)
		T._arch_ring(pk, kit, "painted", wf, u, v1, half - 0.08, "round", 0.08, 0.0, 0.06, frame, NAN, 10)
		for k in range(1, 4):
			var a: float = PI * float(k) / 4.0
			pk.beam(kit, "painted", wf * Vector3(u, v1, 0.045), wf * Vector3(u - cos(a) * (half - 0.08), v1 + sin(a) * (half - 0.08), 0.045), 0.03, 0.02, frame, wf.basis.z)
		T._arch_ring(pk, kit, "plaster", wf, u, v1, half + 0.01, "round", f, 0.0, 0.05, trim, v0, 10)
		T._rect(pk, kit, "plaster", wf, u - 0.11, v1 + half - 0.02, u + 0.11, v1 + half + 0.3, 0.05, 0.09, trim.darkened(0.04))
		if sill:
			_gz_sill(pk, kit, wf, x0, x1, v0, trim, beletage)
		return
	T._rect(pk, kit, "plaster", wf, x0 - f - 0.01, v0, x0 - 0.01, v1, 0.0, 0.05, trim)
	T._rect(pk, kit, "plaster", wf, x1 + 0.01, v0, x1 + f + 0.01, v1, 0.0, 0.05, trim)
	var head_top: float = v1 + f + 0.04
	match hood:
		"key":
			T._rect(pk, kit, "plaster", wf, x0 - f - 0.11, v1, x1 + f + 0.11, head_top, 0.0, 0.05, trim)
			T._rect(pk, kit, "plaster", wf, x0 - f - 0.11, v1 - 0.16, x0 - f - 0.01, v1, 0.0, 0.05, trim)
			T._rect(pk, kit, "plaster", wf, x1 + f + 0.01, v1 - 0.16, x1 + f + 0.11, v1, 0.0, 0.05, trim)
			T._prism(pk, kit, "plaster", wf, PackedVector2Array([Vector2(u - 0.1, v1 - 0.03), Vector2(u + 0.1, v1 - 0.03), Vector2(u + 0.15, head_top + 0.12),
					Vector2(u - 0.15, head_top + 0.12)]), 0.0, 0.09, trim.darkened(0.04))
		"none":
			T._rect(pk, kit, "plaster", wf, x0 - f - 0.01, v1, x1 + f + 0.01, head_top, 0.0, 0.05, trim)
		_:
			T._rect(pk, kit, "plaster", wf, x0 - f - 0.01, v1, x1 + f + 0.01, head_top, 0.0, 0.05, trim)
			# Consoles either side carrying the hood's cornice.
			for cx in [x0 - f - 0.1, x1 + f + 0.1]:
				_mould(pk, kit, "plaster", wf, float(cx) - 0.07, float(cx) + 0.07, PackedVector2Array([Vector2(0.0, v1 - 0.42), Vector2(0.07, v1 - 0.42),
						Vector2(0.15, v1 - 0.1), Vector2(0.15, head_top + 0.2), Vector2(0.0, head_top + 0.2)]), trim.darkened(0.03))
			if hood == "flat" or hood == "jug1":
				T._rect(pk, kit, "plaster", wf, x0 - f, head_top, x1 + f, head_top + 0.2, 0.0, 0.04, trim.darkened(0.02))
			_mould(pk, kit, "plaster", wf, x0 - f - 0.2, x1 + f + 0.2, PackedVector2Array([Vector2(0.0, head_top + 0.2), Vector2(0.17, head_top + 0.2),
					Vector2(0.2, head_top + 0.27), Vector2(0.2, head_top + 0.34), Vector2(0.0, head_top + 0.34)]), trim)
			var base_y: float = head_top + 0.34
			var half2: float = ww * 0.5 + f + 0.18
			if hood == "tri":
				T._prism(pk, kit, "plaster", wf, PackedVector2Array([Vector2(u - half2, base_y), Vector2(u + half2, base_y), Vector2(u, base_y + half2 * 0.42)]),
						0.0, 0.17, trim)
			elif hood == "seg":
				var arc2 := T._arch(u, base_y, half2, "segment", 8, half2 * 0.32)
				T._prism(pk, kit, "plaster", wf, arc2, 0.0, 0.17, trim)
			elif hood == "jug1":
				# A medallion over the hood: a disc with four leaves round it and a bud.
				var mc := Vector3(u, base_y + 0.36, 0.0)
				pk.tube(kit, "plaster", wf * (mc + Vector3(0, 0, 0.0)), wf * (mc + Vector3(0, 0, 0.07)), 0.2, 0.2, 14, trim, true)
				for k in range(4):
					var a2: float = PI * 0.25 + PI * 0.5 * float(k)
					var lc: Vector3 = mc + Vector3(cos(a2) * 0.33, sin(a2) * 0.2, 0.05)
					T._blob(pk, kit, "plaster", wf * lc, Vector3(0.16, 0.07, 0.04), Color(0.68, 0.80, 0.66))
				T._blob(pk, kit, "gold", wf * (mc + Vector3(0, 0, 0.09)), Vector3(0.07, 0.07, 0.04), GOLD)
	if sill:
		_gz_sill(pk, kit, wf, x0, x1, v0, trim, beletage)


## A window's sill under v0 (and, on the Beletage, its consoles and an apron panel under it).
static func _gz_sill(pk: PropKit, kit: Dictionary, wf: Transform3D, x0: float, x1: float, v0: float, trim: Color, beletage: bool) -> void:
	T._rect(pk, kit, "plaster", wf, x0 - 0.26, v0 - 0.17, x1 + 0.26, v0 - 0.02, 0.0, 0.15, trim)
	if beletage:
		for cx in [x0 - 0.16, x1 + 0.16]:
			_mould(pk, kit, "plaster", wf, float(cx) - 0.06, float(cx) + 0.06, PackedVector2Array([Vector2(0.0, v0 - 0.42), Vector2(0.05, v0 - 0.42),
					Vector2(0.11, v0 - 0.17), Vector2(0.0, v0 - 0.17)]), trim.darkened(0.03))
		T._rect(pk, kit, "plaster", wf, x0 + 0.02, v0 - 0.85, x1 - 0.02, v0 - 0.3, 0.0, 0.03, trim.darkened(0.02))
		T._rect(pk, kit, "plaster", wf, x0 + 0.14, v0 - 0.74, x1 - 0.14, v0 - 0.41, 0.03, 0.05, trim)


## A round-arched French window (a hotel's ground floor): glazed leaves under a fanlight, an arched stone surround.
static func _gz_arched_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, top: float, ww: float, frame: Color, trim: Color) -> void:
	var half: float = ww * 0.5
	var spring: float = top - half
	_gz_balcony_door(pk, kit, wf, u, v0, spring, ww, {"frame": frame})
	T._pface(pk, kit, "pane", wf, T._arch(u, spring, half, "round", 10), 0.02, GLASS)
	for k in range(1, 4):
		var a: float = PI * float(k) / 4.0
		pk.beam(kit, "painted", wf * Vector3(u, spring, 0.045), wf * Vector3(u - cos(a) * half, spring + sin(a) * half, 0.045), 0.035, 0.02, frame, wf.basis.z)
	T._arch_ring(pk, kit, "ashlar", wf, u, spring, half + 0.01, "round", 0.24, 0.0, 0.08, SAND.lightened(0.1), v0, 10)
	T._rect(pk, kit, "ashlar", wf, u - 0.14, top - 0.02, u + 0.14, top + 0.34, 0.08, 0.13, SAND.lightened(0.16))
	T._rect(pk, kit, "ashlar", wf, u - half - 0.3, v0 - 0.12, u + half + 0.3, v0, 0.0, 0.14, SAND.lightened(0.05))


## A balcony in front of the storey whose floor is y0, on axis u: a stone slab `half` either side and `depth` out on
## three consoles, an iron railing (curly for Jugendstil).
static func _balcony(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, y0: float, half: float, depth: float, trim: Color, curly: bool,
		drop := 1.05) -> void:
	var y: float = y0 + 0.1
	T._rect(pk, kit, "plaster", wf, u - half, y - 0.22, u + half, y, 0.0, depth, trim)
	_mould(pk, kit, "plaster", wf, u - half - 0.02, u + half + 0.02, PackedVector2Array([Vector2(0.0, y - 0.32), Vector2(depth - 0.12, y - 0.32), Vector2(depth + 0.03, y - 0.22),
			Vector2(depth + 0.03, y - 0.18), Vector2(0.0, y - 0.18)]), trim.darkened(0.04))
	for cx in [u - half + 0.25, u, u + half - 0.25]:
		_mould(pk, kit, "plaster", wf, float(cx) - 0.1, float(cx) + 0.1, PackedVector2Array([Vector2(0.0, y - drop), Vector2(0.1, y - drop),
				Vector2(0.18, y - 0.32 - (drop - 0.32) * 0.7), Vector2(depth - 0.2, y - 0.32 - (drop - 0.32) * 0.12), Vector2(depth - 0.15, y - 0.32),
				Vector2(0.0, y - 0.32)]), trim.darkened(0.06))
	var pts: Array = [wf * Vector3(u - half + 0.05, y, 0.02), wf * Vector3(u - half + 0.05, y, depth - 0.05), wf * Vector3(u + half - 0.05, y, depth - 0.05),
			wf * Vector3(u + half - 0.05, y, 0.02)]
	_railing(pk, kit, pts, 1.0, IRON, 0.17, curly)


## The canted bay (Erker) on axis u from the first floor up to the top storey's floor, on a tapering corbel; a balcony on
## its roof in front of the top storey.
static func _gz_erker(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, p: Dictionary) -> void:
	var n: int = p["n"]
	var ys: Array = p["ys"]
	var hs: Array = p["hs"]
	var G: float = p["G"]
	var trim: Color = p["trim"]
	var wall: Color = p["wall"].lerp(trim, 0.15)
	var ww: float = p["ww"]
	var jug: bool = int(p["v"]) == 3
	var P := 0.75
	var bf: float = ww + 0.6
	var plan: Array = [Vector2(u - bf * 0.5 - P, 0.0), Vector2(u - bf * 0.5, P), Vector2(u + bf * 0.5, P), Vector2(u + bf * 0.5 + P, 0.0)]
	var y_top: float = ys[n - 1]
	# The corbel: a slab, then a tapering block down to a boss under it.
	var grow := _grow_plan(plan, 0.08)
	_plan_slab(pk, kit, "plaster", wf, _close_plan(grow), G + 0.06, G + 0.3, trim)
	var top: Array = []
	var bot: Array = []
	var bplan: Array = [Vector2(u - bf * 0.5 - 0.1, 0.0), Vector2(u - bf * 0.5 + 0.15, 0.22), Vector2(u + bf * 0.5 - 0.15, 0.22), Vector2(u + bf * 0.5 + 0.1, 0.0)]
	for i in range(4):
		var a: Vector2 = grow[i]
		var b: Vector2 = bplan[i]
		top.append(wf * Vector3(a.x, G + 0.06, a.y))
		bot.append(wf * Vector3(b.x, G - 0.42, b.y))
	_loft(pk, kit, "plaster", top, bot, trim.darkened(0.05), wf * Vector3(u, G - 0.2, -0.5))
	var under := PackedVector2Array()
	for q0 in bplan:
		under.append(q0)
	_plan_slab(pk, kit, "plaster", wf, under, G - 0.44, G - 0.42, trim.darkened(0.1))
	# The storeys: three walls each, windows in them, a band between.
	for k in range(1, n - 1):
		var y0: float = ys[k] + (0.3 if k == 1 else 0.0)
		var y1: float = ys[k] + float(hs[k])
		var v0: float = ys[k] + (0.8 if k == 1 else 0.9)
		var v1: float = ys[k] + float(hs[k]) - 0.55
		for f in range(3):
			var a2: Vector2 = plan[f]
			var b2: Vector2 = plan[f + 1]
			var along: Vector3 = (wf.basis.x * (b2.x - a2.x) + wf.basis.z * (b2.y - a2.y))
			var flen: float = along.length()
			# Facing out of the bay (along x up is out for a wall running left to right seen from outside).
			var out: Vector3 = along.normalized().cross(Vector3.UP).normalized()
			var fwf := T._wf(wf * Vector3(a2.x, 0.0, a2.y), out)
			T._face(pk, kit, "plaster", fwf, 0.0, y0, flen, y1, 0.0, wall)
			var wwf: float = ww if f == 1 else 0.5
			_gz_window(pk, kit, fwf, flen * 0.5, v0, v1, wwf, p["frame"], jug)
			if f == 1:
				_gz_surround(pk, kit, fwf, flen * 0.5, v0, v1, wwf, trim, "none", false)
			else:
				T._rect(pk, kit, "plaster", fwf, flen * 0.5 - wwf * 0.5 - 0.09, v0 - 0.12, flen * 0.5 + wwf * 0.5 + 0.09, v0 - 0.01, 0.0, 0.1, trim)
		# A band round the bay at the next floor.
		_plan_slab(pk, kit, "plaster", wf, _close_plan(_grow_plan(plan, 0.05)), y1 - 0.05, y1 + 0.13, trim)
	# The roof: a balcony slab and its railing.
	var rp := _grow_plan(plan, 0.12)
	_plan_slab(pk, kit, "plaster", wf, _close_plan(rp), y_top + 0.0, y_top + 0.18, trim)
	var rail: Array = []
	for q in _grow_plan(plan, 0.06):
		rail.append(wf * Vector3(q.x, y_top + 0.18, q.y))
	_railing(pk, kit, rail, 0.95, IRON, 0.17, jug)


## A bay's plan (points along the wall's u and out from it, left to right) offset `g` outward, its ends kept on the wall.
static func _grow_plan(plan: Array, g: float) -> Array:
	var n: int = plan.size()
	var lines: Array = []
	for i in range(n - 1):
		var a: Vector2 = plan[i]
		var b: Vector2 = plan[i + 1]
		var e: Vector2 = (b - a).normalized()
		lines.append([a + Vector2(-e.y, e.x) * g, e])
	var out: Array = []
	for i in range(n):
		var hit = null
		if i == 0:
			hit = Geometry2D.line_intersects_line(lines[0][0], lines[0][1], Vector2.ZERO, Vector2(1, 0))
		elif i == n - 1:
			hit = Geometry2D.line_intersects_line(lines[n - 2][0], lines[n - 2][1], Vector2.ZERO, Vector2(1, 0))
		else:
			hit = Geometry2D.line_intersects_line(lines[i - 1][0], lines[i - 1][1], lines[i][0], lines[i][1])
		out.append(hit if hit != null else plan[i])
	return out


## The plan as a closed polygon (the points, then back along the wall).
static func _close_plan(plan: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in plan:
		out.append(q)
	return out


## The back of a house: plain render on a plinth, windows on the axes with sills, a simple cornice, the back door.
static func _gz_back(pk: PropKit, kit: Dictionary, p: Dictionary, drng: RandomNumberGenerator) -> void:
	var w: float = p["w"]
	var d: float = p["d"]
	var n: int = p["n"]
	var ys: Array = p["ys"]
	var hs: Array = p["hs"]
	var YE: float = p["YE"]
	var bwf := T._wf(Vector3(w, 0, -d), Vector3(0, 0, -1))
	T._rect(pk, kit, "stone", bwf, 0.0, FOOT, w, 0.4, 0.0, 0.05, BASALT.lightened(0.1))
	var rc: Color = REAR.lerp(p["wall"], 0.25)
	T._face(pk, kit, "plaster", bwf, 0.0, 0.4, w, YE, 0.0, rc)
	for e in [[0.0, -1.0], [w, 1.0]]:
		var ex: float = e[0]
		pk.quad(kit, "plaster", [Vector3(ex, FOOT, -d), Vector3(ex, FOOT, -d + 0.05), Vector3(ex, YE, -d + 0.05), Vector3(ex, YE, -d)], Vector3(float(e[1]), 0, 0), rc)
	var na: int = maxi(int(p["na"]) - (1 if int(p["na"]) > 3 else 0), 2)
	var ax := _axes(w, na)
	for k in range(n):
		var y0: float = ys[k]
		var h: float = hs[k]
		for i in range(na):
			var u: float = ax[i]
			if k == 0 and i == na / 2:
				T._door(pk, kit, bwf, u, 0.3, 1.0, 2.2, Color(0.30, 0.26, 0.2), "plaster", rc.darkened(0.08), 0.0, 0.0, false)
				continue
			var v0: float = y0 + (1.4 if k == 0 else 0.9)
			var v1: float = y0 + h - 0.6
			# The staircase's windows sit between the floors.
			if i == na / 2 and k > 0:
				v0 -= 1.3
				v1 -= 1.4
			_gz_window(pk, kit, bwf, u, v0, v1, 0.95, WHITE_TRIM, false)
			T._rect(pk, kit, "plaster", bwf, u - 0.6, v0 - 0.12, u + 0.6, v0 - 0.01, 0.0, 0.08, rc.lightened(0.1))
	_mould(pk, kit, "plaster", bwf, -0.02, w + 0.02, PackedVector2Array([Vector2(0.0, YE - 0.3), Vector2(0.08, YE - 0.3), Vector2(0.3, YE + 0.05),
			Vector2(0.32, YE + 0.2), Vector2(0.0, YE + 0.2)]), rc.lightened(0.08))
	# Drainpipes at the back corners.
	for px in [0.35, w - 0.35]:
		pk.tube(kit, "metal", Vector3(px, -0.2, -d - 0.12), Vector3(px, YE + 0.1, -d - 0.12), 0.055, 0.055, 6, ZINC, true)


## The mansard roof over a house `w` wide and `d` deep with its eaves at YE: steep slate slopes front and back to a break
## 3.4m up, a zinc (or slate) upper roof to the ridge, the brick firewalls at both ends standing over it, dormers on the
## axes, chimneys on the firewalls.
static func _gz_mansard(pk: PropKit, kit: Dictionary, p: Dictionary, drng: RandomNumberGenerator) -> void:
	var w: float = p["w"]
	var d: float = p["d"]
	var YE: float = p["YE"]
	var ye: float = YE + 0.2
	var ybk: float = ye + 3.4
	var run := 1.24
	var t_up: float = tan(deg_to_rad(21.0))
	var yr: float = ybk + (d * 0.5 - run - 0.05) * t_up
	var x0 := 0.24
	var x1: float = w - 0.24
	var zf := 0.05
	var zb: float = -d - 0.05
	var lo_key := "kslate"
	var up_key: String = p["upper_key"]
	var up_col: Color = ZINC if up_key == "zinc" else SLATE.lightened(0.04)
	var nf := Vector3(0, run, 3.4).normalized()
	var nb := Vector3(0, run, -3.4).normalized()
	YK.roof(pk, kit, lo_key, Vector3(x0, ye, zf), Vector3(x1, ye, zf), Vector3(x1, ybk, zf - run), Vector3(x0, ybk, zf - run), SLATE, nf, false)
	YK.roof(pk, kit, lo_key, Vector3(x1, ye, zb), Vector3(x0, ye, zb), Vector3(x0, ybk, zb + run), Vector3(x1, ybk, zb + run), SLATE, nb, false)
	var zr: float = -d * 0.5
	var nuf := Vector3(0, 1.0, t_up).normalized()
	var nub := Vector3(0, 1.0, -t_up).normalized()
	YK.roof(pk, kit, up_key, Vector3(x0, ybk, zf - run), Vector3(x1, ybk, zf - run), Vector3(x1, yr, zr), Vector3(x0, yr, zr), up_col, nuf, false)
	YK.roof(pk, kit, up_key, Vector3(x1, ybk, zb + run), Vector3(x0, ybk, zb + run), Vector3(x0, yr, zr), Vector3(x1, yr, zr), up_col, nub, false)
	# Rolls along the breaks and the ridge.
	for z in [zf - run, zb + run]:
		pk.tube(kit, "metal", Vector3(x0, ybk + 0.03, z), Vector3(x1, ybk + 0.03, z), 0.07, 0.07, 6, ZINC.darkened(0.1), true)
	pk.tube(kit, "metal", Vector3(x0, yr + 0.04, zr), Vector3(x1, yr + 0.04, zr), 0.08, 0.08, 6, ZINC.darkened(0.1), true)
	# The firewalls: brick, following the roof's section 25cm over it, from the ground up, with a coping.
	# (5cm short of the back wall and of the front: their end faces had lain in the walls' planes.)
	var sec: Array = [Vector2(0.05, FOOT), Vector2(d - 0.05, FOOT), Vector2(d - 0.05, ye + 0.42), Vector2(d - run + 0.03, ybk + 0.28),
			Vector2(d * 0.5, yr + 0.3), Vector2(run - 0.03, ybk + 0.28), Vector2(0.08, ye + 0.42), Vector2(0.05, ye + 0.42)]
	var ol := PackedVector2Array()
	for q in sec:
		ol.append(q)
	for side in [-1.0, 1.0]:
		var swf: Transform3D
		if side < 0.0:
			swf = T._wf(Vector3(0, 0, -d), Vector3(-1, 0, 0))
		else:
			swf = T._wf(Vector3(w, 0, -0.0), Vector3(1, 0, 0))
		var sol := ol
		if side > 0.0:
			sol = PackedVector2Array()
			for q2 in sec:
				sol.append(Vector2(d - q2.x, q2.y))
		var rendered: bool = p.get("firewall_render", false)
		T._prism(pk, kit, "plaster" if rendered else "kbrick", swf, sol, -0.24, 0.0, RENDER if rendered else BRICK, Vector2(0, 1), true)
		# The coping along the firewall's top.
		var tops: Array = [sec[2], sec[3], sec[4], sec[5], sec[6]]
		for i in range(tops.size() - 1):
			var a: Vector2 = tops[i]
			var b: Vector2 = tops[i + 1]
			if side > 0.0:
				a = Vector2(d - a.x, a.y)
				b = Vector2(d - b.x, b.y)
			pk.beam(kit, "metal", swf * Vector3(a.x, a.y + 0.03, -0.12), swf * Vector3(b.x, b.y + 0.03, -0.12), 0.34, 0.07, ZINC.darkened(0.15))
	# Dormers on the front slope: on every axis (or every other one), none where the gable stands.
	var na: int = p["na"]
	var ax := _axes(w, na)
	var gab: Array = p["gable"]
	var dw: float = float(p["ww"]) * 0.85
	var dy0: float = ye + 0.35
	for i in range(na):
		if not gab.is_empty() and i >= int(gab[0]) and i <= int(gab[1]):
			continue
		# The Jugendstil house's bell gable stands over its bay's axis.
		if int(p["v"]) == 3 and i == int(p["erker"]):
			continue
		if not bool(p["dormers_every"]) and i % 2 == 1:
			continue
		_dormer(pk, kit, T._wf(Vector3(0, 0, -0.06), Vector3(0, 0, 1)), ax[i], dy0, dw, 2.05, p, p["dormer_hood"])
	# Two dormers at the back.
	for u in [w * 0.3, w * 0.7]:
		_dormer(pk, kit, T._wf(Vector3(w, 0, -d + 0.06), Vector3(0, 0, -1)), float(u), dy0, dw, 2.0, p, "seg")
	# Chimneys on the firewalls.
	var nch: int = p["chimneys"]
	for k in range(nch):
		var cz: float = -d * (0.3 + 0.4 * float(k % 2))
		var cx: float = 0.18 if k < 2 else w - 0.18
		if k == 1:
			cx = w - 0.18
		_chimney(pk, kit, cx, cz, ybk, yr + 1.0 + drng.randf() * 0.4)


## A chimney stack at (x, z) from y0 (inside the roof) to `top`: sooty brick, a stone cap, two clay pots.
static func _chimney(pk: PropKit, kit: Dictionary, x: float, z: float, y0: float, top: float) -> void:
	T._wblock(pk, kit, "kbrick", Vector3(x - 0.32, y0, z - 0.42), Vector3(x + 0.32, top, z + 0.42), BRICK.darkened(0.1))
	T._wblock(pk, kit, "ashlar", Vector3(x - 0.4, top, z - 0.5), Vector3(x + 0.4, top + 0.12, z + 0.5), SAND.darkened(0.25))
	for dz in [-0.18, 0.18]:
		pk.tube(kit, "matte", Vector3(x, top + 0.12, z + dz), Vector3(x, top + 0.42, z + dz), 0.09, 0.08, 6, Color(0.42, 0.24, 0.18), true)


## A mansard dormer in the wall frame `wf` (its front plane), centred on u, its sill zone from y0, `dw` wide and `dh` tall:
## a slate-hung body reaching back into the roof, a stucco front with the window, a pediment hood ("tri" or "seg") over a
## zinc roof.
static func _dormer(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, y0: float, dw: float, dh: float, p: Dictionary, hood: String) -> void:
	var trim: Color = p["trim"]
	var hw: float = dw * 0.5 + 0.16
	T._rect(pk, kit, "kslate", wf, u - hw, y0 - 0.6, u + hw, y0 + dh, -1.7, 0.0, SLATE.darkened(0.05))
	T._rect(pk, kit, "plaster", wf, u - hw, y0, u + hw, y0 + dh, 0.0, 0.04, trim)
	var wf2: Transform3D = wf.translated_local(Vector3(0, 0, 0.04))
	_gz_window(pk, kit, wf2, u, y0 + 0.2, y0 + dh - 0.12, dw, p["frame"], false)
	T._rect(pk, kit, "plaster", wf2, u - hw - 0.04, y0 + 0.04, u + hw + 0.04, y0 + 0.18, 0.0, 0.1, trim)
	var hh: float = hw + 0.14
	var base_y: float = y0 + dh
	var ol: PackedVector2Array
	if hood == "tri":
		ol = PackedVector2Array([Vector2(u - hh, base_y), Vector2(u + hh, base_y), Vector2(u, base_y + hh * 0.5)])
	else:
		ol = T._arch(u, base_y, hh, "segment", 8, hh * 0.38)
	T._prism(pk, kit, "zinc", wf, ol, -1.8, 0.02, ZINC)
	T._prism(pk, kit, "plaster", wf, ol, 0.02, 0.15, trim)


## The decorated gable (Ziergiebel) over the middle axes of a variant-2 house: a stucco gable rising from the main cornice
## with volutes, shoulders with obelisks, a segmental crown, two windows and an oculus; a slate cross roof behind it.
static func _gz_gable(pk: PropKit, kit: Dictionary, wf: Transform3D, p: Dictionary, drng: RandomNumberGenerator) -> void:
	var w: float = p["w"]
	var na: int = p["na"]
	var ax := _axes(w, na)
	var sp: float = (w - 0.6) / float(na)
	var gab: Array = p["gable"]
	var u0: float = float(ax[int(gab[0])]) - sp * 0.5 + 0.1
	var u1: float = float(ax[int(gab[1])]) + sp * 0.5 - 0.1
	var um: float = (u0 + u1) * 0.5
	var hw: float = (u1 - u0) * 0.5
	var YE: float = p["YE"]
	var y0: float = YE + 0.26
	var trim: Color = p["trim"]
	var wall: Color = p["wall"]
	var H := 4.6
	# The outline: sides up 1.7m, volutes curving in to the shoulders, a step, the segmental crown.
	var ol := PackedVector2Array()
	ol.append(Vector2(u0, y0))
	ol.append(Vector2(u1, y0))
	var rv: float = minf(0.85, hw * 0.3)
	var right: Array = [Vector2(u1, y0 + 1.7)]
	for k in range(1, 7):
		var a: float = PI * 0.5 * float(k) / 6.0
		right.append(Vector2(u1 - rv + cos(a) * rv, y0 + 1.7 + sin(a) * rv * 1.2))
	right.append(Vector2(u1 - rv - 0.1, y0 + 1.7 + rv * 1.2 + 0.25))
	right.append(Vector2(um + hw * 0.5, y0 + 1.7 + rv * 1.2 + 0.25))
	for q in right:
		ol.append(q)
	# The crown: half an ellipse over the middle half (a segment arch can't rise more than its half span).
	var arc := PackedVector2Array()
	var crise: float = H - 1.95 - rv * 1.2
	for k in range(11):
		var ca: float = PI - PI * float(k) / 10.0
		arc.append(Vector2(um + cos(ca) * hw * 0.5, y0 + 1.7 + rv * 1.2 + 0.25 + sin(ca) * crise))
	for k3 in range(arc.size() - 1, -1, -1):
		ol.append(arc[k3])
	for k4 in range(right.size() - 1, -1, -1):
		var q4: Vector2 = right[k4]
		ol.append(Vector2(2.0 * um - q4.x, q4.y))
	var clean := PackedVector2Array()
	for q5 in ol:
		if clean.is_empty() or (clean[clean.size() - 1] as Vector2).distance_to(q5) > 0.01:
			clean.append(q5)
	if clean[0].distance_to(clean[clean.size() - 1]) < 0.01:
		clean.remove_at(clean.size() - 1)
	T._prism(pk, kit, "plaster", wf, clean, -0.45, 0.0, wall, Vector2(0, 1), true)
	# A coping band along its top edge: a thin slab just over the outline's upper run.
	var top_pts: Array = []
	for q6 in clean:
		if q6.y > y0 + 1.0:
			top_pts.append(q6)
	for k5 in range(top_pts.size() - 1):
		var a5: Vector2 = top_pts[k5]
		var b5: Vector2 = top_pts[k5 + 1]
		pk.beam(kit, "plaster", wf * Vector3(a5.x, a5.y + 0.05, -0.2), wf * Vector3(b5.x, b5.y + 0.05, -0.2), 0.62, 0.1, trim)
	# Pilasters at the edges, two windows, an oculus over them.
	T._rect(pk, kit, "plaster", wf, u0, y0, u0 + 0.35, y0 + 1.6, 0.0, 0.05, trim)
	T._rect(pk, kit, "plaster", wf, u1 - 0.35, y0, u1, y0 + 1.6, 0.0, 0.05, trim)
	var gw: float = float(p["ww"]) * 0.8
	for wu in [um - hw * 0.42, um + hw * 0.42]:
		_gz_window(pk, kit, wf, float(wu), y0 + 0.45, y0 + 2.15, gw, p["frame"], false)
		_gz_surround(pk, kit, wf, float(wu), y0 + 0.45, y0 + 2.15, gw, trim, "key", false)
	var oc := Vector3(um, y0 + 3.05, 0.0)
	pk.tube(kit, "pane", wf * oc, wf * (oc + Vector3(0, 0, 0.02)), 0.36, 0.36, 16, GLASS, true)
	T._circle_ring(pk, kit, "plaster", wf, Vector2(um, y0 + 3.05), 0.36, 0.54, 0.0, 0.07, trim, 18)
	# Obelisks on the shoulders and a finial on the crown.
	var sh_y: float = y0 + 1.7 + rv * 1.2 + 0.25
	for su in [u0 + rv * 0.5, u1 - rv * 0.5]:
		var base := wf * Vector3(float(su), sh_y - 0.6, -0.22)
		pk.lathe(kit, "plaster", base, [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.2, 0.75), Vector2(0.13, 0.8), Vector2(0.06, 1.45), Vector2(0.001, 1.6)], 4, trim, true,
				Basis(Vector3.UP, PI * 0.25))
	var apex := wf * Vector3(um, y0 + H + 0.05, -0.22)
	pk.lathe(kit, "plaster", apex - Vector3(0, 0.15, 0), [Vector2(0.001, 0.0), Vector2(0.24, 0.0), Vector2(0.18, 0.3), Vector2(0.24, 0.55), Vector2(0.06, 0.95), Vector2(0.001, 1.05)], 10, trim)
	T._blob(pk, kit, "gold", apex + Vector3(0, 1.0, 0), Vector3(0.1, 0.12, 0.1), GOLD)
	# The cross roof behind: two slate planes from the gable's shoulders back into the mansard.
	var rz0: float = -0.44
	var rz1: float = -3.8
	var ry: float = y0 + 3.6
	var ey: float = y0 + 1.7
	var nl: Vector3 = (wf.basis * Vector3(-(ry - ey), hw - 0.2, 0.0)).normalized()
	var nr: Vector3 = (wf.basis * Vector3(ry - ey, hw - 0.2, 0.0)).normalized()
	YK.roof(pk, kit, "kslate", wf * Vector3(u0 + 0.2, ey, rz1), wf * Vector3(u0 + 0.2, ey, rz0), wf * Vector3(um, ry, rz0), wf * Vector3(um, ry, rz1), SLATE, nl, false)
	YK.roof(pk, kit, "kslate", wf * Vector3(u1 - 0.2, ey, rz0), wf * Vector3(u1 - 0.2, ey, rz1), wf * Vector3(um, ry, rz1), wf * Vector3(um, ry, rz0), SLATE, nr, false)


## The Jugendstil house's bell gable over its bay's axis: a curved stucco gable rising from the cornice with a round-headed
## window, a sunburst over it, green tile bands and a gilt finial; a slate cross roof behind it.
static func _gz_bell_gable(pk: PropKit, kit: Dictionary, wf: Transform3D, p: Dictionary) -> void:
	var w: float = p["w"]
	var ax := _axes(w, p["na"])
	var um: float = ax[int(p["erker"])]
	var YE: float = p["YE"]
	var y0: float = YE + 0.26
	var hw := 1.75
	var H := 4.9
	var trim: Color = p["trim"]
	var wall: Color = p["wall"]
	var ctrl: Array = [Vector2(1.0, 0.0), Vector2(1.0, 0.22), Vector2(0.82, 0.42), Vector2(0.6, 0.55), Vector2(0.56, 0.7), Vector2(0.42, 0.88), Vector2(0.0, 1.0)]
	var sm: Array = T._spline(ctrl, 4, false)
	var ol := PackedVector2Array()
	for q in sm:
		ol.append(Vector2(um + (q as Vector2).x * hw, y0 + (q as Vector2).y * H))
	for k in range(sm.size() - 2, 0, -1):
		var q2: Vector2 = sm[k]
		ol.append(Vector2(um - q2.x * hw, y0 + q2.y * H))
	ol.append(Vector2(um - hw, y0))
	var clean := PackedVector2Array()
	for q3 in ol:
		if clean.is_empty() or (clean[clean.size() - 1] as Vector2).distance_to(q3) > 0.01:
			clean.append(q3)
	T._prism(pk, kit, "plaster", wf, clean, -0.45, 0.0, wall, Vector2(0, 1), true)
	# A band of green tiles along the outline's edge (in front of the face), a gilt finial.
	for k2 in range(clean.size() - 1):
		var a: Vector2 = clean[k2]
		var b: Vector2 = clean[k2 + 1]
		if a.y < y0 + 0.3 and b.y < y0 + 0.3:
			continue
		var m: Vector2 = (a + b) * 0.5
		var inward: Vector2 = Vector2(um, y0 + H * 0.4) - m
		var nn: Vector2 = Vector2(-(b - a).y, (b - a).x).normalized()
		if nn.dot(inward) < 0.0:
			nn = -nn
		var quad := PackedVector2Array([a, b, b + nn * 0.16, a + nn * 0.16])
		if PropKit._signed_area(quad) < 0.0:
			quad = PackedVector2Array([a, a + nn * 0.16, b + nn * 0.16, b])
		T._prism(pk, kit, "enamel", wf, quad, 0.0, 0.03, JUG_GREEN.lightened(0.1))
	pk.lathe(kit, "gold", wf * Vector3(um, y0 + H - 0.05, -0.22), [Vector2(0.001, 0.0), Vector2(0.12, 0.0), Vector2(0.18, 0.25), Vector2(0.05, 0.55), Vector2(0.11, 0.7),
			Vector2(0.001, 1.15)], 10, GOLD)
	# The round-headed window and the sunburst over it.
	var wwg: float = float(p["ww"]) * 0.9
	_gz_window(pk, kit, wf, um, y0 + 0.35, y0 + 2.05, wwg, p["frame"], true)
	_gz_surround(pk, kit, wf, um, y0 + 0.35, y0 + 2.05, wwg, trim, "arch", false, true, p["frame"])
	var sc := Vector3(um, y0 + 3.45, 0.0)
	pk.tube(kit, "gold", wf * sc, wf * (sc + Vector3(0, 0, 0.06)), 0.16, 0.16, 12, GOLD, true)
	for k3 in range(9):
		var a3: float = PI * float(k3) / 8.0
		var d3 := Vector3(cos(a3), sin(a3), 0.0)
		pk.beam(kit, "plaster", wf * (sc + d3 * 0.24 + Vector3(0, 0, 0.03)), wf * (sc + d3 * 0.62 + Vector3(0, 0, 0.03)), 0.06, 0.05, trim.darkened(0.04), wf.basis.z)
	# The cross roof behind.
	var rz0: float = -0.44
	var rz1: float = -3.6
	var ry: float = y0 + 3.4
	var ey: float = y0 + 1.0
	var nl: Vector3 = (wf.basis * Vector3(-(ry - ey), hw - 0.2, 0.0)).normalized()
	var nr: Vector3 = (wf.basis * Vector3(ry - ey, hw - 0.2, 0.0)).normalized()
	YK.roof(pk, kit, "kslate", wf * Vector3(um - hw + 0.2, ey, rz1), wf * Vector3(um - hw + 0.2, ey, rz0), wf * Vector3(um, ry, rz0), wf * Vector3(um, ry, rz1), SLATE, nl, false)
	YK.roof(pk, kit, "kslate", wf * Vector3(um + hw - 0.2, ey, rz0), wf * Vector3(um + hw - 0.2, ey, rz1), wf * Vector3(um, ry, rz1), wf * Vector3(um, ry, rz0), SLATE, nr, false)


# ======================================================================================
#  Gründerzeit houses: the far stand-in
# ======================================================================================

## The same house as `gruenderzeit_house` with the same arguments (it draws the same plan from `rng`), for far away (past
## about 150m): its walls in their colours, dark windows in white frames on the wall, the shop's fascia and awning as
## plain slabs, the string course and cornice as boxes, the mansard with box dormers, the firewalls and chimneys. About
## 1.2-2k triangles. No labels.
static func gruenderzeit_house_far(pk: PropKit, kit: Dictionary, w: float, floors: int, variant: int, rng: RandomNumberGenerator, d := 13.0) -> void:
	var p := _gz_plan(w, floors, variant, rng, d)
	var n: int = p["n"]
	var ys: Array = p["ys"]
	var hs: Array = p["hs"]
	var G: float = p["G"]
	var YE: float = p["YE"]
	var wall: Color = p["wall"]
	var trim: Color = p["trim"]
	var fwf := T._wf(Vector3.ZERO, Vector3(0, 0, 1))
	T._rect(pk, kit, "stone", fwf, 0.0, FOOT, w, 0.45, 0.0, 0.06, p["plinth"])
	T._face(pk, kit, "plaster", fwf, 0.0, 0.45, w, G, 0.0, SAND.lightened(0.06) if String(p["ground"]) == "ashlar" else wall.lerp(trim, 0.35))
	T._face(pk, kit, "plaster", fwf, 0.0, G, w, YE, 0.0, wall)
	var na: int = p["na"]
	var ax := _axes(w, na)
	var ww: float = p["ww"]
	var shop_i: int = p["shop"]
	var sp: float = (w - 0.6) / float(na)
	for i in range(na):
		var u: float = ax[i]
		if i == int(p["door"]):
			T._face(pk, kit, "painted", fwf, u - 0.7, 0.3, u + 0.7, 3.6, 0.03, Color(0.3, 0.2, 0.12))
		elif shop_i >= 0:
			T._face(pk, kit, "pane", fwf, u - (sp - 0.7) * 0.5, 0.8, u + (sp - 0.7) * 0.5, 3.25, 0.03, GLASS.lightened(0.04))
		else:
			T._face(pk, kit, "pane", fwf, u - ww * 0.5, 1.35, u + ww * 0.5, G - 0.85, 0.03, GLASS)
		for k in range(1, n):
			var y0: float = ys[k]
			var v0: float = y0 + (0.8 if k == 1 else 0.9)
			var v1: float = y0 + float(hs[k]) - 0.55
			T._rect(pk, kit, "plaster", fwf, u - ww * 0.5 - 0.14, v0 - 0.14, u + ww * 0.5 + 0.14, v1 + 0.2, 0.0, 0.03, trim)
			T._face(pk, kit, "pane", fwf, u - ww * 0.5, v0, u + ww * 0.5, v1, 0.045, GLASS)
	if shop_i >= 0:
		var shop: Array = SHOPS[shop_i]
		T._rect(pk, kit, "painted", fwf, 0.5, 3.32, w - 0.5, 3.98, 0.0, 0.08, shop[3])
		if String(shop[1]) != "shop":
			var nrm := Vector3(0, 1.9, 0.55).normalized()
			pk.quad(kit, "canvas", [Vector3(0.6, 3.28, 0.05), Vector3(w - 0.6, 3.28, 0.05), Vector3(w - 0.6, 2.73, 1.9), Vector3(0.6, 2.73, 1.9)], nrm, (shop[2] as Array)[1])
			pk.quad(kit, "canvas", [Vector3(0.6, 3.26, 0.05), Vector3(0.6, 2.71, 1.9), Vector3(w - 0.6, 2.71, 1.9), Vector3(w - 0.6, 3.26, 0.05)], -nrm, (shop[2] as Array)[1].darkened(0.3))
	T._rect(pk, kit, "plaster", fwf, 0.0, G - 0.26, w, G + 0.06, 0.0, 0.2, trim)
	T._rect(pk, kit, "plaster", fwf, -0.02, YE - 0.34, w + 0.02, YE + 0.26, 0.0, 0.62, trim)
	if int(p["erker"]) >= 0 and n >= 4:
		var eu: float = ax[int(p["erker"])]
		T._rect(pk, kit, "plaster", fwf, eu - ww * 0.5 - 0.6, G + 0.06, eu + ww * 0.5 + 0.6, float(ys[n - 1]) + 0.18, 0.0, 0.75, wall.lerp(trim, 0.15))
	# The back.
	var bwf := T._wf(Vector3(w, 0, -d), Vector3(0, 0, -1))
	T._face(pk, kit, "plaster", bwf, 0.0, FOOT, w, YE, 0.0, REAR.lerp(wall, 0.25))
	for k2 in range(n):
		for i2 in range(maxi(na - 1, 2)):
			var bu: float = (float(i2) + 0.5) * w / float(maxi(na - 1, 2))
			T._face(pk, kit, "pane", bwf, bu - 0.45, float(ys[k2]) + 1.0, bu + 0.45, float(ys[k2]) + float(hs[k2]) - 0.6, 0.03, GLASS)
	# The roof: the mansard and the firewalls as in the detailed house, box dormers.
	var ye: float = YE + 0.2
	var ybk: float = ye + 3.4
	var run := 1.24
	var t_up: float = tan(deg_to_rad(21.0))
	var yr: float = ybk + (d * 0.5 - run - 0.05) * t_up
	var zr: float = -d * 0.5
	var up_key: String = p["upper_key"]
	var up_col: Color = ZINC if up_key == "zinc" else SLATE.lightened(0.04)
	YK.roof(pk, kit, "kslate", Vector3(0.24, ye, 0.05), Vector3(w - 0.24, ye, 0.05), Vector3(w - 0.24, ybk, 0.05 - run), Vector3(0.24, ybk, 0.05 - run), SLATE,
			Vector3(0, run, 3.4).normalized(), false)
	YK.roof(pk, kit, "kslate", Vector3(w - 0.24, ye, -d - 0.05), Vector3(0.24, ye, -d - 0.05), Vector3(0.24, ybk, -d - 0.05 + run), Vector3(w - 0.24, ybk, -d - 0.05 + run),
			SLATE, Vector3(0, run, -3.4).normalized(), false)
	YK.roof(pk, kit, up_key, Vector3(0.24, ybk, 0.05 - run), Vector3(w - 0.24, ybk, 0.05 - run), Vector3(w - 0.24, yr, zr), Vector3(0.24, yr, zr), up_col,
			Vector3(0, 1.0, t_up).normalized(), false)
	YK.roof(pk, kit, up_key, Vector3(w - 0.24, ybk, -d - 0.05 + run), Vector3(0.24, ybk, -d - 0.05 + run), Vector3(0.24, yr, zr), Vector3(w - 0.24, yr, zr), up_col,
			Vector3(0, 1.0, -t_up).normalized(), false)
	var sec := PackedVector2Array([Vector2(0.05, FOOT), Vector2(d - 0.05, FOOT), Vector2(d - 0.05, ye + 0.42), Vector2(d - run + 0.03, ybk + 0.28),
			Vector2(d * 0.5, yr + 0.3), Vector2(run - 0.03, ybk + 0.28), Vector2(0.05, ye + 0.42)])
	var rendered: bool = p.get("firewall_render", false)
	T._prism(pk, kit, "plaster" if rendered else "kbrick", T._wf(Vector3(0, 0, -d), Vector3(-1, 0, 0)), sec, -0.24, 0.0, RENDER if rendered else BRICK, Vector2(0, 1), true)
	var sec2 := PackedVector2Array()
	for q in sec:
		sec2.append(Vector2(d - q.x, q.y))
	T._prism(pk, kit, "plaster" if rendered else "kbrick", T._wf(Vector3(w, 0, 0), Vector3(1, 0, 0)), sec2, -0.24, 0.0, RENDER if rendered else BRICK, Vector2(0, 1), true)
	for i3 in range(na):
		if not bool(p["dormers_every"]) and i3 % 2 == 1:
			continue
		var du: float = ax[i3]
		var hw: float = ww * 0.42 + 0.16
		T._wblock(pk, kit, "kslate", Vector3(du - hw, ye - 0.25, -1.7), Vector3(du + hw, ye + 2.4, -0.06), SLATE.darkened(0.05))
		T._face(pk, kit, "pane", T._wf(Vector3(0, 0, -0.06), Vector3(0, 0, 1)), du - hw + 0.18, ye + 0.55, du + hw - 0.18, ye + 2.25, 0.03, GLASS)
	for k3 in range(int(p["chimneys"])):
		var cx: float = 0.18 if k3 == 0 else w - 0.18
		T._wblock(pk, kit, "kbrick", Vector3(cx - 0.32, ybk, -d * (0.3 + 0.4 * float(k3 % 2)) - 0.42), Vector3(cx + 0.32, yr + 1.1, -d * (0.3 + 0.4 * float(k3 % 2)) + 0.42),
				BRICK.darkened(0.1))


# ======================================================================================
#  A mansard round a polygon (the corner house, the hotel)
# ======================================================================================

## A flat-topped mansard over a convex plan `outline` (points as Vector2(x, z), either winding): each edge i (from point i to
## i + 1) is a street side (`slopes[i]` true: a steep slate slope from 5cm outside the wall at `ye` up to the break `rise`
## higher and `run` in) or a firewall (the roof stops 24cm inside it). The top is a zinc deck at the break. Returns
## {"breaks", "eaves" (x-z points), "ybk"}.
static func _mansard_ring(pk: PropKit, kit: Dictionary, outline: Array, slopes: Array, ye: float, run := 1.24, rise := 3.4, deck_key := "zinc") -> Dictionary:
	var n: int = outline.size()
	var area := 0.0
	for i in range(n):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	# Outward normal of edge i in (x, z).
	var eaves: Array = []
	var breaks: Array = []
	var lines_e: Array = []
	var lines_b: Array = []
	for i in range(n):
		var a2: Vector2 = outline[i]
		var b2: Vector2 = outline[(i + 1) % n]
		var e: Vector2 = (b2 - a2).normalized()
		var on := Vector2(e.y, -e.x) if area > 0.0 else Vector2(-e.y, e.x)
		var de: float = 0.05 if slopes[i] else -0.24
		var db: float = (0.05 - run) if slopes[i] else -0.24
		lines_e.append([a2 + on * de, e])
		lines_b.append([a2 + on * db, e])
	for i in range(n):
		var j: int = (i - 1 + n) % n
		var he = Geometry2D.line_intersects_line(lines_e[j][0], lines_e[j][1], lines_e[i][0], lines_e[i][1])
		var hb = Geometry2D.line_intersects_line(lines_b[j][0], lines_b[j][1], lines_b[i][0], lines_b[i][1])
		eaves.append(he if he != null else lines_e[i][0])
		breaks.append(hb if hb != null else lines_b[i][0])
	var ybk: float = ye + rise
	for i in range(n):
		if not slopes[i]:
			continue
		var e0: Vector2 = eaves[i]
		var e1: Vector2 = eaves[(i + 1) % n]
		var b0: Vector2 = breaks[i]
		var b1: Vector2 = breaks[(i + 1) % n]
		var p0 := Vector3(e0.x, ye, e0.y)
		var p1 := Vector3(e1.x, ye, e1.y)
		var p2 := Vector3(b1.x, ybk, b1.y)
		var p3 := Vector3(b0.x, ybk, b0.y)
		var nrm: Vector3 = (p1 - p0).cross(p3 - p0).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		YK.roof(pk, kit, "kslate", p0, p1, p2, p3, SLATE, nrm, false)
		pk.tube(kit, "metal", p3 + Vector3(0, 0.03, 0), p2 + Vector3(0, 0.03, 0), 0.07, 0.07, 6, ZINC.darkened(0.1), true)
	# The deck: a thin zinc slab over the break polygon.
	var ol := PackedVector2Array()
	for q in breaks:
		ol.append(Vector2((q as Vector2).x, -(q as Vector2).y))
	T._plan_prism(pk, kit, deck_key, Vector3.ZERO, ol, ybk - 0.12, ybk + 0.02, ZINC)
	return {"breaks": breaks, "eaves": eaves, "ybk": ybk}


# ======================================================================================
#  The corner house
# ======================================================================================

const CORNER_CUT := 2.4

## A Gründerzeit corner house (Eckhaus) at a street corner: its front along x (0..w) in the plane z = 0 facing +z, its side
## along the side street (z from 0 to -d) in the plane x = w facing +x, the corner between them cut back CORNER_CUT along
## both (a 45-degree face), with a corner turret (Eckturm) standing out over the cut face from the first floor up, a storey
## over the main cornice, under a bell-shaped copper dome (welsche Haube) with a lantern and a gilt finial; a corner café
## (its door in the cut, its name on both fascias, an awning, tables) and the house door on the front; a mansard round both
## street sides, firewalls at x = 0 and z = -d. `turret_left` builds it mirrored (the corner at x = 0, the side street
## facing -x). Reaches out like `house_extent(floors, 0)`, the turret 2.3m out from the cut face. About 18-24k triangles.
static func corner_house(pk: PropKit, kit: Dictionary, labels: Array, w: float, d: float, floors: int, rng: RandomNumberGenerator, turret_left := false) -> void:
	var saved: Array = []
	if turret_left:
		saved = _push(pk, Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3(w, 0, 0)))
	var p := _gz_plan(w, floors, 0, rng, d)
	p["gable"] = []
	var drng := RandomNumberGenerator.new()
	drng.seed = int(p["seed"])
	var c := CORNER_CUT
	var shop_i: int = p["shop"]
	if shop_i < 0 or String((SHOPS[shop_i] as Array)[1]) == "shop":
		shop_i = [0, 2, 4, 7][drng.randi() % 4]
	var n: int = p["n"]
	var G: float = p["G"]
	var YE: float = p["YE"]
	var trim: Color = p["trim"]
	var wall: Color = p["wall"]
	# The two street fronts.
	var lf: float = w - c
	var ls: float = d - c
	var naf: int = clampi(int(round((lf - 0.6) / 2.8)), 2, 8)
	var nas: int = clampi(int(round((ls - 0.6) / 2.8)), 2, 8)
	var fwf := T._wf(Vector3.ZERO, Vector3(0, 0, 1))
	var swf := T._wf(Vector3(w, 0, -c), Vector3(1, 0, 0))
	var bal_f: Array = [[1, naf / 2]] if naf >= 3 else []
	var bal_s: Array = [[1, nas / 2]] if nas >= 3 else []
	_gz_facade(pk, kit, labels, fwf, lf, p, {"na": naf, "door": 0, "shop": shop_i, "balconies": bal_f, "tables": true}, drng)
	_gz_facade(pk, kit, labels, swf, ls, p, {"na": nas, "door": -1, "shop": shop_i, "balconies": bal_s, "tables": true}, drng)
	# The cut corner: its own short facade, the café door in it, the turret over it.
	var cn := Vector3(1, 0, 1).normalized()
	var cwf := T._wf(Vector3(w - c, 0, 0), cn)
	var cl: float = c * sqrt(2.0)
	T._rect(pk, kit, "stone", cwf, 0.0, FOOT, cl, 0.45, 0.0, 0.06, p["plinth"])
	T._face(pk, kit, "ashlar" if String(p["ground"]) == "ashlar" else "plaster", cwf, 0.0, 0.45, cl, G, 0.0,
			SAND.lightened(0.06) if String(p["ground"]) == "ashlar" else wall.lerp(trim, 0.35))
	T._face(pk, kit, "plaster", cwf, 0.0, G, cl, YE, 0.0, wall)
	var shop: Array = SHOPS[shop_i]
	_gz_shop_door(pk, kit, cwf, cl * 0.5, cl - 0.5, shop[3])
	T._rect(pk, kit, "painted", cwf, 0.15, 3.32, cl - 0.15, 3.98, 0.0, 0.08, shop[3])
	_mould(pk, kit, "plaster", cwf, 0.0, cl, PackedVector2Array([Vector2(0.0, G - 0.26), Vector2(0.1, G - 0.26), Vector2(0.12, G - 0.2),
			Vector2(0.2, G - 0.12), Vector2(0.22, G - 0.02), Vector2(0.0, G - 0.02)]), trim)
	_mould(pk, kit, "plaster", cwf, -0.02, cl + 0.02, PackedVector2Array([Vector2(0.0, YE - 0.34), Vector2(0.1, YE - 0.34), Vector2(0.1, YE - 0.18),
			Vector2(0.58, YE - 0.13), Vector2(0.6, YE + 0.02), Vector2(0.68, YE + 0.08), Vector2(0.7, YE + 0.2), Vector2(0.62, YE + 0.26),
			Vector2(0.0, YE + 0.26)]), trim)
	_turret(pk, kit, Vector3(w - c * 0.5, 0.0, -c * 0.5) + cn * 0.35, cn, p)
	# The roof: a mansard round both street sides, the firewalls on the other two.
	var ye: float = YE + 0.2
	var outline: Array = [Vector2(0, 0), Vector2(w - c, 0), Vector2(w, -c), Vector2(w, -d), Vector2(0, -d)]
	var slopes: Array = [true, true, true, false, false]
	var r := _mansard_ring(pk, kit, outline, slopes, ye)
	var ybk: float = r["ybk"]
	# Firewalls at x = 0 (u along +z from the back) and z = -d (u along -x from x = w).
	var lsec := PackedVector2Array([Vector2(0.0, FOOT), Vector2(d - 0.05, FOOT), Vector2(d - 0.05, ye + 0.42), Vector2(d - 1.21, ybk + 0.28), Vector2(0.0, ybk + 0.28)])
	T._prism(pk, kit, "kbrick", T._wf(Vector3(0, 0, -d), Vector3(-1, 0, 0)), lsec, -0.24, 0.0, BRICK, Vector2(0, 1), true)
	var bsec := PackedVector2Array([Vector2(0.05, FOOT), Vector2(w - 0.24, FOOT), Vector2(w - 0.24, ybk + 0.28), Vector2(1.21, ybk + 0.28), Vector2(0.05, ye + 0.42)])
	T._prism(pk, kit, "kbrick", T._wf(Vector3(w, 0, -d), Vector3(0, 0, -1)), bsec, -0.24, 0.0, BRICK, Vector2(0, 1), true)
	# Dormers on both street slopes, chimneys on the firewalls.
	var axf := _axes(lf, naf)
	for i in range(naf):
		_dormer(pk, kit, T._wf(Vector3(0, 0, -0.06), Vector3(0, 0, 1)), axf[i], ye + 0.35, float(p["ww"]) * 0.85, 2.05, p, p["dormer_hood"])
	var axs := _axes(ls, nas)
	for i2 in range(nas):
		_dormer(pk, kit, T._wf(Vector3(w - 0.06, 0, -c), Vector3(1, 0, 0)), axs[i2], ye + 0.35, float(p["ww"]) * 0.85, 2.05, p, p["dormer_hood"])
	_chimney(pk, kit, 0.18, -d * 0.5, ybk - 0.3, ybk + 1.5)
	_chimney(pk, kit, w * 0.5, -d + 0.18, ybk - 0.3, ybk + 1.5)
	if turret_left:
		_pop(pk, saved)


## The corner turret standing on the cut face whose middle (on the ground) is `base`, facing `out`: an octagon from a
## corbel at the first floor up past the main cornice by a storey, windows on its outer faces, bands at each floor, its own
## cornice, a copper bell dome with a lantern, a gilt ball and a spike.
static func _turret(pk: PropKit, kit: Dictionary, base: Vector3, out: Vector3, p: Dictionary) -> void:
	var n: int = p["n"]
	var ys: Array = p["ys"]
	var hs: Array = p["hs"]
	var G: float = p["G"]
	var YE: float = p["YE"]
	var trim: Color = p["trim"]
	var wall: Color = p["wall"].lerp(trim, 0.12)
	var R := 1.85
	var a0: float = atan2(-out.z, out.x)
	var oct := T._ngon(R, 8, a0 + PI / 8.0)
	# The corbel: an inverted cone of mouldings under the first floor.
	var rot := Basis(Vector3.UP, a0 + PI / 8.0)
	pk.lathe(kit, "plaster", base + Vector3(0, G - 1.3, 0), [Vector2(0.001, 0.0), Vector2(0.35, 0.0), Vector2(0.5, 0.25), Vector2(1.2, 0.8), Vector2(R + 0.05, 1.3),
			Vector2(R + 0.12, 1.36), Vector2(R + 0.12, 1.6), Vector2(0.001, 1.6)], 8, trim, true, rot)
	var top_y: float = YE + 0.26 + 3.2
	var floors_y: Array = []
	for k in range(1, n):
		floors_y.append([float(ys[k]) + (0.3 if k == 1 else 0.0), float(ys[k]) + float(hs[k]), float(ys[k]) + (0.8 if k == 1 else 0.9), float(ys[k]) + float(hs[k]) - 0.55])
	floors_y.append([YE + 0.26, top_y, YE + 1.0, top_y - 0.55])
	for k2 in range(floors_y.size()):
		var f: Array = floors_y[k2]
		for i in range(8):
			var a: Vector2 = oct[i]
			var b: Vector2 = oct[(i + 1) % 8]
			var mid: Vector2 = (a + b) * 0.5
			var fo := Vector3(mid.x, 0.0, -mid.y).normalized()
			if fo.dot(out) < -0.45:
				continue
			var pa: Vector3 = base + Vector3(a.x, 0, -a.y)
			var pb: Vector3 = base + Vector3(b.x, 0, -b.y)
			var fwf := T._wf(pa, fo)
			var flen: float = pa.distance_to(pb)
			if fwf.basis.x.dot(pb - pa) < 0.0:
				fwf = T._wf(pb, fo)
			T._face(pk, kit, "plaster", fwf, 0.0, float(f[0]), flen, float(f[1]), 0.0, wall)
			if fo.dot(out) > 0.3:
				_gz_window(pk, kit, fwf, flen * 0.5, float(f[2]), float(f[3]), 0.62, p["frame"], k2 == floors_y.size() - 1)
				T._rect(pk, kit, "plaster", fwf, flen * 0.5 - 0.42, float(f[2]) - 0.14, flen * 0.5 + 0.42, float(f[2]) - 0.02, 0.0, 0.1, trim)
				T._rect(pk, kit, "plaster", fwf, flen * 0.5 - 0.42, float(f[3]), flen * 0.5 + 0.42, float(f[3]) + 0.16, 0.0, 0.06, trim)
		# A band at the top of each floor (the octagon grown 8cm).
		T._plan_prism(pk, kit, "plaster", base, T._ngon(R + 0.09, 8, a0 + PI / 8.0), float(f[1]) - 0.06, float(f[1]) + 0.12, trim, true)
	# Its cornice and the dome.
	T._plan_prism(pk, kit, "plaster", base, T._ngon(R + 0.38, 8, a0 + PI / 8.0), top_y + 0.06, top_y + 0.32, trim, true)
	var rb: float = R + 0.3
	var dome: Array = [Vector2(rb, 0.0), Vector2(rb * 0.97, 0.35), Vector2(rb * 0.8, 0.9), Vector2(rb * 0.55, 1.45), Vector2(rb * 0.42, 1.9),
			Vector2(rb * 0.5, 2.3), Vector2(rb * 0.46, 2.75), Vector2(rb * 0.28, 3.15), Vector2(0.38, 3.35), Vector2(0.001, 3.36)]
	pk.lathe(kit, "copper", base + Vector3(0, top_y + 0.32, 0), dome, 8, COPPER, true, rot)
	# The lantern: posts round a little drum, its cap, the ball and spike.
	var ly: float = top_y + 0.32 + 3.3
	for k3 in range(8):
		var aa: float = TAU * float(k3) / 8.0
		pk.beam(kit, "copper", base + Vector3(cos(aa) * 0.42, ly, sin(aa) * 0.42), base + Vector3(cos(aa) * 0.42, ly + 1.0, sin(aa) * 0.42), 0.08, 0.08, COPPER)
	pk.lathe(kit, "copper", base + Vector3(0, ly + 0.95, 0), [Vector2(0.001, 0.0), Vector2(0.62, 0.0), Vector2(0.55, 0.12), Vector2(0.3, 0.5), Vector2(0.12, 0.85),
			Vector2(0.001, 0.9)], 8, COPPER, true)
	pk.lathe(kit, "gold", base + Vector3(0, ly + 1.8, 0), [Vector2(0.001, 0.0), Vector2(0.16, 0.06), Vector2(0.2, 0.2), Vector2(0.16, 0.34), Vector2(0.001, 0.4)], 10, GOLD)
	pk.tube(kit, "gold", base + Vector3(0, ly + 2.15, 0), base + Vector3(0, ly + 3.2, 0), 0.035, 0.005, 6, GOLD, true)


# ======================================================================================
#  The hotel
# ======================================================================================

const HOTEL_W := 46.0
const HOTEL_D := 18.0
const HOTEL_TERRACE := 6.6
const HOTEL_TERRACE_Y := 0.9

## The Hotel Rheinkrone: a grand hotel of about 1900, 46m along the street (x 0..46) and 18m deep (z 0..-18), five
## storeys, freestanding: a cream stucco front in five parts (corner pavilions 0.5m forward under square slate domes with
## lanterns, the wings, a middle risalit 0.9m forward with the name in gilt letters on its attic and a gilt crown), a
## sandstone ground floor of round-arched French windows, the entrance under a glass and iron marquee; a raised terrace
## (0.9m) along the front between the pavilions with a balustrade, steps in the middle, tables under parasols (out to
## z = 8.2 with the steps); a glazed winter garden (Wintergarten) in front of the left pavilion (x 0.4..8.6, out to z = 7.6)
## with palms inside; finished sides, a plain back, a hipped mansard. About 30k triangles.
static func hotel(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var W := HOTEL_W
	var D := HOTEL_D
	var p := {"v": 0, "n": 5, "w": W, "d": D, "wall": Color(0.94, 0.88, 0.74), "trim": WHITE_TRIM, "frame": WHITE_TRIM, "ground": "ashlar",
			"plinth": BASALT, "ww": 1.2, "hood1": "tri", "hood2": "flat", "dormer_hood": "seg", "dormers_every": true, "upper_key": "zinc", "gable": [],
			"chimneys": 0, "seed": 4242, "door": -1, "shop": -1, "erker": -1, "balconies": [], "na": 3}
	var hs: Array = [5.0, 4.2, 3.8, 3.6, 3.3]
	var ys: Array = []
	var y := 0.0
	for h in hs:
		ys.append(y)
		y += float(h)
	p["hs"] = hs
	p["ys"] = ys
	p["G"] = hs[0]
	p["YE"] = y
	var YE: float = y
	var G: float = hs[0]
	var drng := RandomNumberGenerator.new()
	drng.seed = 4242
	var trim: Color = p["trim"]
	var wall: Color = p["wall"]
	# The front in five parts: [x0, x1, forward, axes, balconies, door axis].
	var parts: Array = [[0.0, 9.0, 0.5, 3, [[1, 1]], -1], [9.0, 17.5, 0.0, 3, [], -1], [17.5, 28.5, 0.9, 3, [[1, 0], [1, 1], [1, 2]], 1],
			[28.5, 37.0, 0.0, 3, [], -1], [37.0, 46.0, 0.5, 3, [[1, 1]], -1]]
	for pt in parts:
		var x0: float = pt[0]
		var x1: float = pt[1]
		var fz: float = pt[2]
		var wf := T._wf(Vector3(x0, 0, fz), Vector3(0, 0, 1))
		_gz_facade(pk, kit, labels, wf, x1 - x0, p, {"na": pt[3], "door": pt[5], "balconies": pt[4], "ground_mode": "hotel"}, drng)
		if fz > 0.0:
			for e in [[x0, -1.0], [x1, 1.0]]:
				var ex: float = e[0]
				# The building's own ends are its side facades.
				if ex < 0.01 or ex > W - 0.01:
					continue
				var nrm := Vector3(float(e[1]), 0, 0)
				pk.quad(kit, "plaster", [Vector3(ex, FOOT, 0.0), Vector3(ex, FOOT, fz - 0.05), Vector3(ex, YE, fz - 0.05), Vector3(ex, YE, 0.0)], nrm, wall)
	# The sides: plain facades of four axes (x = 0 facing -x, x = W facing +x).
	var lwf := T._wf(Vector3(0, 0, -D), Vector3(-1, 0, 0))
	_gz_facade(pk, kit, labels, lwf, D + 0.45, p, {"na": 5, "door": -1, "ground_mode": "res"}, drng)
	var rwf := T._wf(Vector3(W, 0, 0.45), Vector3(1, 0, 0))
	_gz_facade(pk, kit, labels, rwf, D + 0.45, p, {"na": 5, "door": -1, "ground_mode": "res"}, drng)
	# The back.
	var bp: Dictionary = p.duplicate()
	bp["na"] = 12
	_gz_back(pk, kit, bp, drng)
	# The attic over the middle risalit: a panel with the name, a segmental crest, the crown and two urns.
	var rx0 := 17.5
	var rx1 := 28.5
	var rz := 0.9
	var awf := T._wf(Vector3(rx0, 0, rz), Vector3(0, 0, 1))
	var ay0: float = YE + 0.26
	T._prism(pk, kit, "plaster", awf, T._rp(0.3, ay0, rx1 - rx0 - 0.3, ay0 + 2.4), -0.5, 0.0, wall, Vector2(0, 1), true)
	var crest := T._arch((rx1 - rx0) * 0.5, ay0 + 2.4, 3.4, "segment", 12, 1.3)
	T._prism(pk, kit, "plaster", awf, crest, -0.5, 0.0, wall, Vector2(0, 1), true)
	T._rect(pk, kit, "plaster", awf, 0.2, ay0 + 2.4, rx1 - rx0 - 0.2, ay0 + 2.6, -0.55, 0.12, trim)
	T._rect(pk, kit, "painted", awf, 0.9, ay0 + 0.5, rx1 - rx0 - 0.9, ay0 + 1.9, 0.0, 0.05, Color(0.10, 0.18, 0.14))
	_label(labels, "HOTEL RHEINKRONE", awf * Vector3((rx1 - rx0) * 0.5, ay0 + 1.2, 0.09), Vector3(0, 0, 1), 0.85, GOLD.lightened(0.2), rx1 - rx0 - 2.2)
	var cr: Vector3 = awf * Vector3((rx1 - rx0) * 0.5, ay0 + 3.75, -0.25)
	_crown(pk, kit, cr, 1.1)
	for ux in [0.55, rx1 - rx0 - 0.55]:
		pk.lathe(kit, "plaster", awf * Vector3(float(ux), ay0 + 2.6, -0.25), [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.15), Vector2(0.14, 0.3), Vector2(0.36, 0.7),
				Vector2(0.3, 1.0), Vector2(0.12, 1.1), Vector2(0.18, 1.3), Vector2(0.001, 1.38)], 10, trim)
	# The roof: a hipped mansard over the whole block, square domes over the pavilions; zinc over the gap behind the attic.
	var ye: float = YE + 0.2
	T._wblock(pk, kit, "zinc", Vector3(rx0, ye - 0.04, 0.0), Vector3(rx1, ye + 0.04, rz - 0.45), ZINC)
	_mansard_ring(pk, kit, [Vector2(0, 0), Vector2(W, 0), Vector2(W, -D), Vector2(0, -D)], [true, true, true, true], ye)
	for px in [4.5, W - 4.5]:
		_pavilion_dome(pk, kit, Vector3(float(px), YE + 0.26, 0.5 - 4.6), 4.6, trim)
	# Dormers on the wings' slopes and over the middle.
	for dx in [10.8, 13.25, 15.7, 30.3, 32.75, 35.2]:
		_dormer(pk, kit, T._wf(Vector3(0, 0, -0.06), Vector3(0, 0, 1)), float(dx), ye + 0.35, 1.0, 2.05, p, "seg")
	for dx2 in [8.0, 15.0, 23.0, 31.0, 38.0]:
		_dormer(pk, kit, T._wf(Vector3(W, 0, -D + 0.06), Vector3(0, 0, -1)), float(dx2), ye + 0.35, 1.0, 2.0, p, "seg")
	for cz in [-6.0, -12.0]:
		for cx in [14.0, 32.0]:
			_chimney(pk, kit, float(cx), float(cz), ye + 3.2, ye + 5.0)
	# The entrance's marquee: glass on an iron frame hung on rods from the wall, its fascia with the name.
	_marquee(pk, kit, labels, Vector3(23.0, 0, rz), 3.4)
	# The terrace, its balustrade, steps and tables.
	_hotel_terrace(pk, kit, drng)
	# The winter garden.
	_winter_garden(pk, kit, Vector3(4.5, 0, 0.5), 8.2, 7.1)


## A gilt crown standing at c (its foot), `s` metres across: a band with jewels, five points with balls, two arches over it,
## an orb and a cross.
static func _crown(pk: PropKit, kit: Dictionary, c: Vector3, s: float) -> void:
	var r: float = s * 0.5
	pk.lathe(kit, "gold", c, [Vector2(r * 0.8, 0.0), Vector2(r, 0.1 * s), Vector2(r, 0.3 * s), Vector2(r * 0.86, 0.34 * s), Vector2(r * 0.86, 0.3 * s)], 16, GOLD)
	for k in range(5):
		var a: float = TAU * float(k) / 5.0
		var b: Vector3 = c + Vector3(cos(a) * r * 0.92, 0.3 * s, sin(a) * r * 0.92)
		pk.tube(kit, "gold", b, b + Vector3(0, 0.28 * s, 0), 0.06 * s, 0.02 * s, 6, GOLD, true)
		T._blob(pk, kit, "gold", b + Vector3(0, 0.33 * s, 0), Vector3.ONE * 0.06 * s, GOLD)
		T._blob(pk, kit, "enamel", c + Vector3(cos(a + 0.6) * r * 1.0, 0.18 * s, sin(a + 0.6) * r * 1.0), Vector3.ONE * 0.05 * s, Color(0.7, 0.08, 0.1))
	for k2 in range(2):
		var axis: Vector3 = Vector3(1, 0, 0) if k2 == 0 else Vector3(0, 0, 1)
		var prev := Vector3.ZERO
		for j in range(9):
			var t: float = PI * float(j) / 8.0
			var q: Vector3 = c + Vector3(0, 0.3 * s, 0) + axis * cos(t) * r * 0.86 + Vector3(0, sin(t) * 0.45 * s, 0)
			if j > 0:
				pk.tube(kit, "gold", prev, q, 0.03 * s, 0.03 * s, 6, GOLD, false)
			prev = q
	T._blob(pk, kit, "gold", c + Vector3(0, 0.82 * s, 0), Vector3.ONE * 0.09 * s, GOLD)
	pk.beam(kit, "gold", c + Vector3(0, 0.88 * s, 0), c + Vector3(0, 1.08 * s, 0), 0.03 * s, 0.03 * s, GOLD)
	pk.beam(kit, "gold", c + Vector3(-0.06 * s, 1.0 * s, 0), c + Vector3(0.06 * s, 1.0 * s, 0), 0.03 * s, 0.03 * s, GOLD)


## A square pavilion dome (a curved mansard) on a pavilion whose cornice top is at c.y, centred on c, `h` its half width:
## slate faces curving up to a little flat top, zinc ribs on the hips, an oval dormer on the front face, a lantern of
## posts with its cap and a spike.
static func _pavilion_dome(pk: PropKit, kit: Dictionary, c: Vector3, h: float, trim: Color) -> void:
	var prof: Array = [Vector2(h + 0.05, 0.0), Vector2(h * 0.98, 0.8), Vector2(h * 0.9, 1.9), Vector2(h * 0.72, 3.1), Vector2(h * 0.48, 4.1), Vector2(h * 0.3, 4.6)]
	var corners: Array = [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for side in range(4):
		var ca: Vector2 = corners[side]
		var cb: Vector2 = corners[(side + 1) % 4]
		for k in range(prof.size() - 1):
			var p0: Vector2 = prof[k]
			var p1: Vector2 = prof[k + 1]
			var a0 := c + Vector3(ca.x * p0.x, p0.y, ca.y * p0.x)
			var b0 := c + Vector3(cb.x * p0.x, p0.y, cb.y * p0.x)
			var a1 := c + Vector3(ca.x * p1.x, p1.y, ca.y * p1.x)
			var b1 := c + Vector3(cb.x * p1.x, p1.y, cb.y * p1.x)
			var nrm: Vector3 = (b0 - a0).cross(a1 - a0).normalized()
			var mid: Vector3 = (a0 + b0) * 0.5 - c
			if nrm.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
				nrm = -nrm
			YK.roof(pk, kit, "kslate", a0, b0, b1, a1, SLATE.lightened(0.03), nrm, false)
		# The hip rib.
		var rib: Array = []
		for q in prof:
			rib.append(c + Vector3(ca.x * (q as Vector2).x, (q as Vector2).y + 0.04, ca.y * (q as Vector2).x))
		for k2 in range(rib.size() - 1):
			pk.tube(kit, "metal", rib[k2], rib[k2 + 1], 0.08, 0.08, 6, ZINC.darkened(0.1), k2 == 0)
	var tp: Vector2 = prof[prof.size() - 1]
	T._wblock(pk, kit, "zinc", c + Vector3(-tp.x, 4.5, -tp.x), c + Vector3(tp.x, 4.7, tp.x), ZINC)
	# The front's oval dormer (Ochsenauge).
	var oc: Vector3 = c + Vector3(0, 1.7, h * 0.9 + 0.12)
	var owf := T._wf(oc, Vector3(0, 0, 1))
	T._prism(pk, kit, "kslate", owf, T._rp(-0.8, -0.95, 0.8, 0.95), -1.2, 0.0, SLATE)
	T._circle_ring(pk, kit, "plaster", owf, Vector2.ZERO, 0.52, 0.8, 0.0, 0.12, trim, 16)
	pk.tube(kit, "pane", owf * Vector3(0, 0, 0.0), owf * Vector3(0, 0, 0.04), 0.53, 0.53, 16, GLASS, true)
	# The lantern.
	var ly: float = c.y + 4.7
	for k3 in range(4):
		var cc: Vector2 = corners[k3]
		pk.beam(kit, "metal", Vector3(c.x + cc.x * 0.6, ly, c.z + cc.y * 0.6), Vector3(c.x + cc.x * 0.6, ly + 1.3, c.z + cc.y * 0.6), 0.12, 0.12, ZINC.darkened(0.2))
	T._wblock(pk, kit, "zinc", Vector3(c.x - 0.8, ly + 1.3, c.z - 0.8), Vector3(c.x + 0.8, ly + 1.45, c.z + 0.8), ZINC)
	pk.lathe(kit, "metal", Vector3(c.x, ly + 1.45, c.z), [Vector2(0.75, 0.0), Vector2(0.55, 0.3), Vector2(0.2, 0.75), Vector2(0.001, 0.85)], 4, ZINC.darkened(0.15), true,
			Basis(Vector3.UP, PI * 0.25))
	pk.lathe(kit, "gold", Vector3(c.x, ly + 2.3, c.z), [Vector2(0.001, 0.0), Vector2(0.14, 0.08), Vector2(0.17, 0.2), Vector2(0.12, 0.32), Vector2(0.001, 0.36)], 10, GOLD)
	pk.tube(kit, "metal", Vector3(c.x, ly + 2.6, c.z), Vector3(c.x, ly + 3.8, c.z), 0.04, 0.01, 6, IRON, true)


## The entrance's marquee (a glass canopy on an iron frame) on the wall at `at` (the wall's foot under its middle), `half`
## either side: hung on rods from the wall, a fascia with the hotel's name round it, lamps under it.
static func _marquee(pk: PropKit, kit: Dictionary, labels: Array, at: Vector3, half: float) -> void:
	var y := 4.3
	var reach := 3.2
	var x0: float = at.x - half
	var x1: float = at.x + half
	var z0: float = at.z
	var z1: float = at.z + reach
	# The glass roof sloping out from the wall, its ribs, the fascia round its edge.
	pk.quad(kit, "wglass", [Vector3(x0, y + 0.35, z0 + 0.05), Vector3(x1, y + 0.35, z0 + 0.05), Vector3(x1, y, z1), Vector3(x0, y, z1)], Vector3(0, 1, 0.1).normalized(),
			Color(0.75, 0.85, 0.9, 0.35))
	pk.quad(kit, "wglass", [Vector3(x0, y + 0.33, z0 + 0.05), Vector3(x0, y - 0.02, z1), Vector3(x1, y - 0.02, z1), Vector3(x1, y + 0.33, z0 + 0.05)], Vector3(0, -1, -0.1).normalized(),
			Color(0.75, 0.85, 0.9, 0.3))
	var nr: int = int((x1 - x0) / 0.9)
	for k in range(nr + 1):
		var rx: float = lerpf(x0, x1, float(k) / float(nr))
		pk.beam(kit, "steel", Vector3(rx, y + 0.38, z0 + 0.05), Vector3(rx, y + 0.03, z1), 0.06, 0.08, IRON)
	T._wblock(pk, kit, "steel", Vector3(x0 - 0.06, y - 0.42, z1 - 0.06), Vector3(x1 + 0.06, y + 0.12, z1 + 0.06), IRON)
	for sx in [x0, x1]:
		T._wblock(pk, kit, "steel", Vector3(float(sx) - 0.06, y - 0.42, z0 + 0.05), Vector3(float(sx) + 0.06, y + 0.12, z1), IRON)
	T._wblock(pk, kit, "gold", Vector3(x0 - 0.07, y - 0.32, z1 + 0.06), Vector3(x1 + 0.07, y - 0.28, z1 + 0.075), GOLD)
	_label(labels, "Hotel Rheinkrone", Vector3(at.x, y - 0.13, z1 + 0.09), Vector3(0, 0, 1), 0.2, GOLD.lightened(0.2), x1 - x0 - 0.6)
	for sx2 in [x0 + 0.3, x1 - 0.3]:
		pk.beam(kit, "steel", Vector3(float(sx2), y + 2.6, z0 + 0.02), Vector3(float(sx2), y + 0.05, z1 - 0.1), 0.04, 0.04, IRON)
	for lx in [at.x - half * 0.5, at.x + half * 0.5]:
		pk.tube(kit, "steel", Vector3(float(lx), y - 0.02, z0 + reach * 0.5), Vector3(float(lx), y - 0.4, z0 + reach * 0.5), 0.015, 0.015, 4, IRON, false)
		pk.lathe(kit, "bulb", Vector3(float(lx), y - 0.75, z0 + reach * 0.5), [Vector2(0.001, 0.0), Vector2(0.17, 0.08), Vector2(0.2, 0.2), Vector2(0.16, 0.33), Vector2(0.001, 0.36)],
				10, Color(1.0, 0.9, 0.7))


## The terrace along the hotel's front between the pavilions (x 9..37): a sandstone platform HOTEL_TERRACE_Y up, its front
## wall with a balustrade, steps down in the middle (to z = 8.2), tables under parasols on it.
static func _hotel_terrace(pk: PropKit, kit: Dictionary, drng: RandomNumberGenerator) -> void:
	var ty := HOTEL_TERRACE_Y
	var x0 := 9.0
	var x1 := 37.0
	var z1 := HOTEL_TERRACE
	var sx0 := 20.0
	var sx1 := 26.0
	# The platform: the part in front of the wings (to the risalit's front) and the main slab.
	T._wblock(pk, kit, "ashlar", Vector3(x0, FOOT, 0.02), Vector3(x1, ty, z1), SAND.lightened(0.02))
	# The balustrade along the front and the ends, a gap for the steps.
	var runs: Array = [[Vector3(x0 + 0.2, ty, z1 - 0.2), Vector3(sx0, ty, z1 - 0.2)], [Vector3(sx1, ty, z1 - 0.2), Vector3(x1 - 0.2, ty, z1 - 0.2)],
			[Vector3(x0 + 0.2, ty, 0.6), Vector3(x0 + 0.2, ty, z1 - 0.2)], [Vector3(x1 - 0.2, ty, 0.6), Vector3(x1 - 0.2, ty, z1 - 0.2)]]
	for r in runs:
		_balustrade(pk, kit, r[0], r[1], SAND.lightened(0.12))
	# The steps.
	var n := 5
	var rh: float = ty / float(n)
	for k in range(n):
		var top: float = ty - rh * float(k + 1)
		T._wblock(pk, kit, "ashlar", Vector3(sx0 - 0.3 * float(k + 1), FOOT, z1), Vector3(sx1 + 0.3 * float(k + 1), top + 0.001 * float(k), z1 + 0.32 * float(k + 1)),
				SAND.lightened(0.06 - 0.02 * float(k % 2)))
	for sx in [sx0 - 0.25, sx1 + 0.25]:
		T._wblock(pk, kit, "ashlar", Vector3(float(sx) - 0.3, ty, z1 - 0.45), Vector3(float(sx) + 0.3, ty + 1.15, z1 + 0.15), SAND.lightened(0.1))
		pk.lathe(kit, "plaster", Vector3(float(sx), ty + 1.15, z1 - 0.15), [Vector2(0.001, 0.0), Vector2(0.24, 0.0), Vector2(0.14, 0.2), Vector2(0.3, 0.55), Vector2(0.001, 0.62)],
				10, WHITE_TRIM)
	# Tables, chairs and parasols on it.
	var tx := x0 + 2.2
	var k2 := 0
	while tx < x1 - 1.5:
		if tx > sx0 - 1.6 and tx < sx1 + 1.6:
			tx += 2.4
			continue
		var tc := Vector3(tx, ty, 3.7)
		_bistro_set(pk, kit, tc, WHITE_TRIM, Color(0.12, 0.26, 0.20), 4)
		if k2 % 2 == 0:
			_parasol(pk, kit, tc + Vector3(1.2, 0, 0), 1.5, Color(0.93, 0.92, 0.88), Color(0.12, 0.30, 0.22))
		tx += 3.4
		k2 += 1


## A stone balustrade from a to b (its foot): a plinth, square balusters, a handrail coping.
static func _balustrade(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, col: Color) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 0.1:
		return
	var along: Vector3 = d / l
	pk.beam(kit, "ashlar", a + Vector3(0, 0.08, 0), b + Vector3(0, 0.08, 0), 0.32, 0.16, col, Vector3.ZERO, uvk)
	pk.beam(kit, "ashlar", a + Vector3(0, 0.98, 0), b + Vector3(0, 0.98, 0), 0.36, 0.14, col.lightened(0.04), Vector3.ZERO, uvk)
	var nb: int = int(l / 0.3)
	for k in range(nb):
		var p: Vector3 = a + along * ((float(k) + 0.5) * l / float(nb))
		pk.lathe(kit, "ashlar", p + Vector3(0, 0.16, 0), [Vector2(0.07, 0.0), Vector2(0.1, 0.3), Vector2(0.11, 0.45), Vector2(0.06, 0.66), Vector2(0.08, 0.76)], 4, col, true,
				Basis(Vector3.UP, PI * 0.25))


## The winter garden: a glazed iron conservatory centred on `front` (the middle of its back on the wall), `w` wide and
## `depth` out (+z), on a low plinth: glass walls between white iron posts, a hipped glass roof with a crest, palms and
## tables inside.
static func _winter_garden(pk: PropKit, kit: Dictionary, front: Vector3, w: float, depth: float) -> void:
	var x0: float = front.x - w * 0.5
	var x1: float = front.x + w * 0.5
	var z0: float = front.z
	var z1: float = front.z + depth
	var pl := 0.6
	var eave := 4.6
	var ridge := 6.4
	var white := Color(0.93, 0.94, 0.92)
	var glass := Color(0.72, 0.84, 0.82, 0.28)
	T._wblock(pk, kit, "ashlar", Vector3(x0, FOOT, z0 + 0.02), Vector3(x1, pl, z1), SAND.darkened(0.04))
	T._wblock(pk, kit, "matte", Vector3(x0 + 0.1, pl, z0 + 0.1), Vector3(x1 - 0.1, pl + 0.02, z1 - 0.1), Color(0.55, 0.28, 0.20))
	# Glass walls: front and both sides, posts every 1.2m, a transom bar.
	var walls: Array = [[Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(0, 0, 1)], [Vector3(x1, 0, z1), Vector3(x1, 0, z0 + 0.05), Vector3(1, 0, 0)],
			[Vector3(x0, 0, z0 + 0.05), Vector3(x0, 0, z1), Vector3(-1, 0, 0)]]
	for wl in walls:
		var a: Vector3 = wl[0]
		var b: Vector3 = wl[1]
		var o: Vector3 = wl[2]
		pk.quad(kit, "wglass", [a + Vector3(0, pl, 0), b + Vector3(0, pl, 0), b + Vector3(0, eave, 0), a + Vector3(0, eave, 0)], o, glass)
		var l: float = a.distance_to(b)
		var np: int = maxi(int(l / 1.2), 1)
		for k in range(np + 1):
			var q: Vector3 = a.lerp(b, float(k) / float(np)) + o * 0.04
			pk.beam(kit, "paint", q + Vector3(0, pl, 0), q + Vector3(0, eave, 0), 0.09, 0.09, white)
		for yy in [pl + 0.05, 1.3, 3.6, eave - 0.05]:
			pk.beam(kit, "paint", a + o * 0.05 + Vector3(0, float(yy), 0), b + o * 0.05 + Vector3(0, float(yy), 0), 0.07, 0.07, white, Vector3.UP)
	# The roof: hipped glass to a ridge along x, ribs, a cresting along the ridge.
	var rz: float = (z0 + z1) * 0.5
	var rx0: float = x0 + depth * 0.5
	var rx1: float = x1 - depth * 0.5
	if rx1 < rx0:
		rx0 = front.x
		rx1 = front.x
	var e: Array = [Vector3(x0, eave, z1), Vector3(x1, eave, z1), Vector3(x1, eave, z0 + 0.05), Vector3(x0, eave, z0 + 0.05)]
	var rl := Vector3(rx0, ridge, rz)
	var rr := Vector3(rx1, ridge, rz)
	var faces: Array = [[e[0], e[1], rr, rl], [e[1], e[2], rr], [e[3], e[0], rl], [e[2], e[3], rl, rr]]
	for f in faces:
		var pts: Array = f
		var nrm: Vector3 = ((pts[1] as Vector3) - (pts[0] as Vector3)).cross((pts[pts.size() - 1] as Vector3) - (pts[0] as Vector3)).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		if pts.size() == 4:
			pk.quad(kit, "wglass", pts, nrm, glass)
		else:
			pk.tri(kit, "wglass", pts[0], pts[1], pts[2], nrm, nrm, nrm, glass, nrm)
	var nrib: int = int(w / 1.2)
	for k2 in range(nrib + 1):
		var ex: float = lerpf(x0, x1, float(k2) / float(nrib))
		var top: Vector3 = Vector3(clampf(ex, rx0, rx1), ridge, rz)
		pk.beam(kit, "paint", Vector3(ex, eave, z1), top, 0.07, 0.07, white)
	for c0 in [e[0], e[1]]:
		pk.beam(kit, "paint", c0, rr if c0 == e[1] else rl, 0.09, 0.09, white)
	pk.beam(kit, "paint", rl + Vector3(0, 0.05, 0), rr + Vector3(0, 0.05, 0), 0.12, 0.1, white)
	var cx := rx0
	while cx <= rx1 + 0.01:
		pk.lathe(kit, "paint", Vector3(cx, ridge + 0.08, rz), [Vector2(0.001, 0.0), Vector2(0.05, 0.0), Vector2(0.03, 0.25), Vector2(0.08, 0.32), Vector2(0.001, 0.45)], 6, white)
		cx += 0.6
	# Inside: palms in tubs and two tables.
	for pc in [Vector3(x0 + 1.2, pl, z1 - 1.2), Vector3(x1 - 1.2, pl, z1 - 1.2), Vector3(front.x, pl, z0 + 1.4)]:
		_potted_palm(pk, kit, pc, 2.6)
	_bistro_set(pk, kit, Vector3(front.x - 1.4, pl, z1 - 2.6), WHITE_TRIM, Color(0.85, 0.82, 0.74), 2)
	_bistro_set(pk, kit, Vector3(front.x + 1.4, pl, z1 - 2.6), WHITE_TRIM, Color(0.85, 0.82, 0.74), 2)


## A palm in a tub standing on `c`, `h` tall: a wooden tub, a ringed trunk, a crown of drooping fronds (two-sided leaves).
static func _potted_palm(pk: PropKit, kit: Dictionary, c: Vector3, h: float) -> void:
	pk.lathe(kit, "wood", c, [Vector2(0.001, 0.0), Vector2(0.32, 0.0), Vector2(0.4, 0.55), Vector2(0.37, 0.58), Vector2(0.001, 0.56)], 8, Color(0.45, 0.30, 0.18), true)
	var top: Vector3 = c + Vector3(0.05, h, 0.03)
	pk.tube(kit, "wood", c + Vector3(0, 0.5, 0), top, 0.09, 0.06, 6, Color(0.42, 0.34, 0.24), true)
	for k in range(9):
		var a: float = TAU * float(k) / 9.0 + 0.3
		var d := Vector3(cos(a), 0, sin(a))
		var side: Vector3 = d.cross(Vector3.UP)
		var mid: Vector3 = top + d * 0.7 + Vector3(0, 0.25, 0)
		var tip: Vector3 = top + d * 1.3 + Vector3(0, -0.35, 0)
		for seg in [[top, mid, 0.18], [mid, tip, 0.12]]:
			var p0: Vector3 = seg[0]
			var p1: Vector3 = seg[1]
			var hw: float = seg[2]
			pk.quad(kit, "leaf", [p0 - side * hw * 0.4, p1 - side * hw, p1 + side * hw, p0 + side * hw * 0.4], Vector3.UP, Color(0.20, 0.42, 0.18))


# ======================================================================================
#  The Rhine steps and the quay wall
# ======================================================================================

## The Rheintreppe: wide sandstone steps from the upper promenade (y = 0 at z = 0) down `drop` metres toward +z to the
## lower promenade (y = -drop), `length` metres along x (0..length). A coping 3cm proud at the top (z -0.4..0.35), risers
## of about 16cm in flights of ten with landings between, treads sized so the last riser stands at z = depth (at least
## 28cm: deeper if `depth` is too short); sandstone cheek walls (x -0.6..0 and length..length + 0.6) standing a metre over
## the steps with copings and piers at both ends, handrails along both and down the middle every 8m or so. Solid down to
## 0.8m under the lower promenade. Returns the steps' real depth.
static func rhine_steps(pk: PropKit, kit: Dictionary, length: float, drop: float, depth: float) -> float:
	var n: int = maxi(int(ceil(drop / 0.165)), 2)
	var rh: float = drop / float(n)
	var per := 10
	var lands: int = int(ceil(float(n) / float(per))) - 1
	var land := 1.6
	var steps_z: float = depth - 0.35
	var tread: float = (steps_z - float(lands) * land) / float(maxi(n - 1 - lands, 1))
	if tread < 0.3:
		land = maxf(0.9, (steps_z - float(n - 1 - lands) * 0.3) / maxf(float(lands), 1.0))
		tread = maxf(0.28, (steps_z - float(lands) * land) / float(maxi(n - 1 - lands, 1)))
	var stone := SAND.lightened(0.04)
	var ol := PackedVector2Array([Vector2(-0.4, 0.03)])
	var z := 0.35
	var y := 0.03
	var nose: Array = [Vector2(0.35, 0.03)]
	for k in range(n):
		y = -rh * float(k + 1)
		ol.append(Vector2(z, y))
		if k == n - 1:
			break
		var is_land: bool = (k + 1) % per == 0
		if is_land:
			nose.append(Vector2(z, y))
		z += land if is_land else tread
		ol.append(Vector2(z, y))
		if is_land:
			nose.append(Vector2(z, y))
	nose.append(Vector2(z, -drop))
	ol.append(Vector2(z, -drop - 0.8))
	ol.append(Vector2(-0.4, -drop - 0.8))
	var real_depth: float = z
	var wf := T._wf(Vector3.ZERO, Vector3(0, 0, 1))
	_mould(pk, kit, "ashlar", wf, 0.0, length, ol, stone)
	# The coping along the top edge, a band of darker stone.
	_mould(pk, kit, "ashlar", wf, 0.0, length, PackedVector2Array([Vector2(-0.4, 0.0), Vector2(0.38, 0.0), Vector2(0.38, 0.05), Vector2(-0.4, 0.05)]), stone.darkened(0.08))
	# The cheek walls with their copings and piers.
	var top_a := Vector2(-0.4, 1.0)
	var top_b := Vector2(real_depth + 0.3, -drop + 1.0)
	var cheek := PackedVector2Array([Vector2(-0.4, -drop - 0.8), Vector2(real_depth + 0.3, -drop - 0.8), top_b, top_a])
	for cx in [[-0.6, 0.0], [length, length + 0.6]]:
		_mould(pk, kit, "ashlar", wf, cx[0], cx[1], cheek, stone.darkened(0.04))
		var mx: float = (float(cx[0]) + float(cx[1])) * 0.5
		pk.beam(kit, "ashlar", Vector3(mx, top_a.y + 0.06, top_a.x), Vector3(mx, top_b.y + 0.06, top_b.x), 0.76, 0.12, stone.lightened(0.05), Vector3(1, 0, 0), uvk)
		for pz in [[-0.4, 0.0], [real_depth - 0.5, -drop]]:
			var py: float = pz[1]
			var pzz: float = pz[0]
			T._wblock(pk, kit, "ashlar", Vector3(mx - 0.42, py - 0.3, pzz - 0.4 + 0.4), Vector3(mx + 0.42, py + 1.35, pzz + 0.42 + 0.4), stone.lightened(0.02))
			T._wblock(pk, kit, "ashlar", Vector3(mx - 0.5, py + 1.35, pzz - 0.08 + 0.4 - 0.4), Vector3(mx + 0.5, py + 1.5, pzz + 0.5 + 0.4), stone.lightened(0.08))
			pk.lathe(kit, "ashlar", Vector3(mx, py + 1.5, pzz + 0.41), [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.18, 0.12), Vector2(0.24, 0.32), Vector2(0.001, 0.52)],
					10, stone.lightened(0.08))
	# Handrails: along both cheek walls' inner faces and down the middle, every 8m or so.
	var rails: Array = [0.22, length - 0.22]
	var nm: int = int(length / 8.0)
	for k2 in range(1, nm):
		rails.append(length * float(k2) / float(nm))
	for rx in rails:
		var pts: Array = []
		for q in nose:
			pts.append(Vector3(float(rx), (q as Vector2).y + 0.9, (q as Vector2).x))
		for i in range(pts.size() - 1):
			pk.tube(kit, "metal", pts[i], pts[i + 1], 0.03, 0.03, 6, IRON, i == 0 or i == pts.size() - 2)
		for i2 in range(pts.size()):
			var top: Vector3 = pts[i2]
			pk.tube(kit, "metal", top - Vector3(0, 0.9, 0), top, 0.022, 0.022, 5, IRON, false)
		# Posts between the bends.
		for i3 in range(pts.size() - 1):
			var a: Vector3 = pts[i3]
			var b: Vector3 = pts[i3 + 1]
			var np: int = int(a.distance_to(b) / 1.8)
			for k3 in range(1, np):
				var q2: Vector3 = a.lerp(b, float(k3) / float(np))
				pk.tube(kit, "metal", q2 - Vector3(0, 0.9, 0), q2, 0.02, 0.02, 5, IRON, false)
	return real_depth


## The quay wall under the upper promenade: its face in the plane z = 0 facing +z (the river side), `length` along x, from
## 0.8m under the lower promenade (y = -drop) up to a sandstone coping whose top is 8cm over the upper promenade (y = 0),
## projecting 14cm (back to z = -0.6). Basalt rubble between sandstone pilasters every 12m on a footing course, mooring
## rings, drain outlets with rust streaks, an iron ladder, flood marks on a sandstone plaque by the middle pilaster
## (Hochwasser 1926, 1988, 1993, 1995), and with `railing` a cast-iron railing on the coping (z -0.3).
static func quay_wall(pk: PropKit, kit: Dictionary, length: float, drop: float, labels := [], railing := false) -> void:
	var wf := T._wf(Vector3.ZERO, Vector3(0, 0, 1))
	var y0: float = -drop - 0.8
	# UV v from the lower promenade up (the rubble shader moss its first half metre).
	pk.quad(kit, "stone", [Vector3(0, y0, 0), Vector3(length, y0, 0), Vector3(length, -0.25, 0), Vector3(0, -0.25, 0)], Vector3(0, 0, 1), BASALT,
			[Vector2(0, y0 + drop) * uvk, Vector2(length, y0 + drop) * uvk, Vector2(length, drop - 0.25) * uvk, Vector2(0, drop - 0.25) * uvk])
	T._rect(pk, kit, "ashlar", wf, 0.0, y0, length, -drop + 0.45, 0.0, 0.16, SAND.darkened(0.12))
	_mould(pk, kit, "ashlar", wf, 0.0, length, PackedVector2Array([Vector2(-0.6, -0.27), Vector2(0.06, -0.27), Vector2(0.14, -0.2), Vector2(0.14, 0.08),
			Vector2(-0.6, 0.08)]), SAND)
	var np: int = maxi(int(round(length / 12.0)), 1)
	var piers: Array = []
	for k in range(np + 1):
		var px: float = clampf(length * float(k) / float(np), 0.45, length - 0.45)
		piers.append(px)
		T._rect(pk, kit, "ashlar", wf, px - 0.45, -drop + 0.45, px + 0.45, -0.27, 0.0, 0.12, SAND.darkened(0.04))
	for k2 in range(np):
		var mx: float = (float(piers[k2]) + float(piers[k2 + 1])) * 0.5
		# A mooring ring on its staple, a drain with its rust streak.
		var ry: float = -drop + 1.25
		T._rect(pk, kit, "steel", wf, mx - 0.07, ry - 0.06, mx + 0.07, ry + 0.06, 0.0, 0.07, IRON)
		pk.tyre(kit, "metal", Vector3(mx, ry - 0.2, 0.09), 0.13, 0.17, 0.04, 12, IRON.lightened(0.05), Basis(Vector3(0, 0, 1), PI * 0.5))
		var dx: float = mx + 3.0
		if dx < length - 1.0:
			pk.tube(kit, "matte", Vector3(dx, -drop + 1.9, 0.0), Vector3(dx, -drop + 1.9, 0.06), 0.11, 0.11, 10, Color(0.04, 0.04, 0.04), true)
			T._rect(pk, kit, "stone", wf, dx - 0.09, -drop + 0.5, dx + 0.09, -drop + 1.8, 0.0, 0.012, Color(0.36, 0.24, 0.16))
	# An iron ladder recessed in the wall.
	var lx: float = length * 0.78
	for sx in [-0.22, 0.22]:
		pk.beam(kit, "steel", Vector3(lx + sx, -drop + 0.1, 0.06), Vector3(lx + sx, -0.3, 0.06), 0.05, 0.06, IRON)
	var ly: float = -drop + 0.35
	while ly < -0.35:
		pk.tube(kit, "metal", Vector3(lx - 0.22, ly, 0.08), Vector3(lx + 0.22, ly, 0.08), 0.018, 0.018, 5, IRON, false)
		ly += 0.3
	# The flood marks on a plaque by the middle pier.
	var fx: float = float(piers[np / 2]) + 0.95
	if fx + 0.5 < length:
		T._rect(pk, kit, "ashlar", wf, fx - 0.35, -drop + drop * 0.55, fx + 0.35, -0.45, 0.0, 0.05, SAND.lightened(0.12))
		var marks: Array = [["Hochwasser 1926", 0.86], ["HW 1995", 0.81], ["HW 1993", 0.78], ["HW 1988", 0.66]]
		for m in marks:
			var my: float = -drop + drop * float(m[1])
			if my > -0.55:
				my = -0.55 - 0.08 * float(marks.find(m))
			T._rect(pk, kit, "enamel", wf, fx - 0.3, my - 0.012, fx + 0.12, my + 0.012, 0.05, 0.07, Color(0.08, 0.08, 0.1))
			pk.tri(kit, "enamel", wf * Vector3(fx + 0.12, my - 0.04, 0.07), wf * Vector3(fx + 0.12, my + 0.04, 0.07), wf * Vector3(fx + 0.2, my, 0.07),
					wf.basis.z, wf.basis.z, wf.basis.z, Color(0.08, 0.08, 0.1), wf.basis.z)
			_label(labels, String(m[0]), wf * Vector3(fx - 0.09, my + 0.06, 0.075), wf.basis.z, 0.045, Color(0.1, 0.1, 0.12), 0.6)
	if railing:
		_cast_railing(pk, kit, Vector3(0.0, 0.08, -0.3), Vector3(length, 0.08, -0.3))


## A cast-iron promenade railing from a to b (its foot): posts every 2.4m with knobs, a handrail, a foot rail, bars every
## 22cm with a band of rings between two middle rails. About 30 triangles a metre.
static func _cast_railing(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 1.05) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	var np: int = maxi(int(ceil(l / 2.4)), 1)
	for k in range(np + 1):
		var p: Vector3 = a + d * (float(k) / float(np))
		pk.tube(kit, "metal", p, p + Vector3(0, h + 0.05, 0), 0.045, 0.035, 6, IRON, false)
		T._blob(pk, kit, "metal", p + Vector3(0, h + 0.1, 0), Vector3(0.06, 0.07, 0.06), IRON)
	pk.tube(kit, "metal", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.03, 0.03, 6, IRON, true)
	pk.tube(kit, "metal", a + Vector3(0, 0.1, 0), b + Vector3(0, 0.1, 0), 0.02, 0.02, 4, IRON, true)
	pk.tube(kit, "metal", a + Vector3(0, h - 0.18, 0), b + Vector3(0, h - 0.18, 0), 0.016, 0.016, 4, IRON, true)
	pk.tube(kit, "metal", a + Vector3(0, h - 0.34, 0), b + Vector3(0, h - 0.34, 0), 0.016, 0.016, 4, IRON, true)
	var nb: int = int(l / 0.22)
	var dn: Vector3 = d.normalized()
	for k2 in range(nb):
		var q: Vector3 = a + d * ((float(k2) + 0.5) / float(nb))
		pk.tube(kit, "metal", q + Vector3(0, 0.1, 0), q + Vector3(0, h, 0), 0.011, 0.011, 3, IRON, false)
		if k2 % 2 == 0 and k2 < nb - 1:
			T._blob(pk, kit, "metal", q + Vector3(0, h - 0.26, 0) + dn * 0.11, Vector3(0.07, 0.07, 0.015), IRON)


# ======================================================================================
#  The promenade's furniture
# ======================================================================================

## The riverside café pavilion "Café am Strom", 1950s: a glazed hall (x 0..14, z 0..-5.4) and a closed kitchen block behind
## it (to z = -8) on a stone plinth 0.45m high, a thin flat roof slab overhanging 1.8m on every side (its underside with
## downlights), the name on the fascia; inside a counter, tables and chairs, pendant lamps; in front a paved terrace (z 0.3
## to 7, its top 12cm up) behind glass wind screens, four square parasols over tables, planters, a menu board.
## Front faces +z. About 9k triangles.
static func pavilion_cafe(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var W := 14.0
	var D := 8.0
	var GD := 5.4
	var fl := 0.45
	var top := 3.45
	var frame := Color(0.30, 0.24, 0.18)
	var glass := Color(0.70, 0.82, 0.80, 0.26)
	var cream := Color(0.95, 0.93, 0.86)
	T._wblock(pk, kit, "ashlar", Vector3(-0.3, FOOT, -D - 0.3), Vector3(W + 0.3, fl, 0.3), SAND.darkened(0.06))
	T._wblock(pk, kit, "timber", Vector3(0.05, fl, -GD), Vector3(W - 0.05, fl + 0.03, -0.05), Color(0.55, 0.38, 0.22))
	# The glass walls (front and the sides of the hall) between bronze mullions.
	var walls: Array = [[Vector3(0, 0, 0), Vector3(W, 0, 0), Vector3(0, 0, 1)], [Vector3(W, 0, 0), Vector3(W, 0, -GD), Vector3(1, 0, 0)],
			[Vector3(0, 0, -GD), Vector3(0, 0, 0), Vector3(-1, 0, 0)]]
	for wl in walls:
		var a: Vector3 = wl[0]
		var b: Vector3 = wl[1]
		var o: Vector3 = wl[2]
		pk.quad(kit, "wglass", [a + Vector3(0, fl + 0.3, 0), b + Vector3(0, fl + 0.3, 0), b + Vector3(0, top, 0), a + Vector3(0, top, 0)], o, glass)
		pk.beam(kit, "paint", a + o * 0.04 + Vector3(0, fl + 0.15, 0), b + o * 0.04 + Vector3(0, fl + 0.15, 0), 0.3, 0.1, frame, Vector3.UP)
		pk.beam(kit, "paint", a + o * 0.04 + Vector3(0, 2.7, 0), b + o * 0.04 + Vector3(0, 2.7, 0), 0.06, 0.08, frame, Vector3.UP)
		var l: float = a.distance_to(b)
		var nm: int = maxi(int(round(l / 1.4)), 1)
		for k in range(nm + 1):
			var q: Vector3 = a.lerp(b, float(k) / float(nm)) + o * 0.04
			pk.beam(kit, "paint", q + Vector3(0, fl, 0), q + Vector3(0, top, 0), 0.08, 0.1, frame)
	# The glazed doors in the middle of the front.
	T._wblock(pk, kit, "painted", Vector3(W * 0.5 - 0.95, fl, 0.02), Vector3(W * 0.5 + 0.95, fl + 0.05, 0.12), frame)
	pk.tube(kit, "metal", Vector3(W * 0.5 - 0.12, 1.4, 0.1), Vector3(W * 0.5 - 0.12, 1.9, 0.1), 0.02, 0.02, 6, Color(0.75, 0.62, 0.3))
	pk.tube(kit, "metal", Vector3(W * 0.5 + 0.12, 1.4, 0.1), Vector3(W * 0.5 + 0.12, 1.9, 0.1), 0.02, 0.02, 6, Color(0.75, 0.62, 0.3))
	# The kitchen block behind: stucco, a door and a vent.
	var kc := Color(0.88, 0.86, 0.80)
	T._wblock(pk, kit, "plaster", Vector3(0.0, fl, -D), Vector3(W, top, -GD), kc)
	T._door(pk, kit, T._wf(Vector3(W, 0, -D), Vector3(0, 0, -1)), 3.0, fl, 1.0, 2.1, Color(0.4, 0.42, 0.4), "plaster", kc.darkened(0.1), 0.0, 0.0)
	T._rect(pk, kit, "metal", T._wf(Vector3(W, 0, -D), Vector3(0, 0, -1)), 8.0, 2.2, 8.8, 2.8, 0.0, 0.06, Color(0.6, 0.6, 0.6))
	# Inside: the counter along the kitchen wall, a coffee machine, a cake display, tables, lamps.
	T._wblock(pk, kit, "timber", Vector3(2.0, fl, -GD + 0.02), Vector3(9.0, fl + 1.05, -GD + 0.7), Color(0.42, 0.26, 0.15))
	T._wblock(pk, kit, "ashlar", Vector3(1.95, fl + 1.05, -GD + 0.0), Vector3(9.05, fl + 1.1, -GD + 0.75), Color(0.85, 0.83, 0.8))
	T._wblock(pk, kit, "metal", Vector3(3.0, fl + 1.1, -GD + 0.1), Vector3(3.7, fl + 1.55, -GD + 0.55), Color(0.75, 0.75, 0.76))
	pk.quad(kit, "wglass", [Vector3(5.0, fl + 1.1, -GD + 0.7), Vector3(7.0, fl + 1.1, -GD + 0.7), Vector3(7.0, fl + 1.6, -GD + 0.7), Vector3(5.0, fl + 1.6, -GD + 0.7)],
			Vector3(0, 0, 1), Color(0.8, 0.9, 0.9, 0.3))
	for cx in [5.4, 6.0, 6.6]:
		pk.lathe(kit, "paint", Vector3(float(cx), fl + 1.12, -GD + 0.4), [Vector2(0.001, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.12), Vector2(0.001, 0.12)], 8,
				[Color(0.55, 0.32, 0.2), Color(0.95, 0.85, 0.8), Color(0.75, 0.2, 0.3)][int(float(cx) * 3.0) % 3])
	for tx in [2.0, 5.0, 8.0, 11.5]:
		for tz in [-1.3, -3.3]:
			_bistro_set(pk, kit, Vector3(float(tx), fl + 0.03, float(tz)), Color(0.94, 0.93, 0.9), Color(0.12, 0.30, 0.26), 2)
			pk.tube(kit, "metal", Vector3(float(tx), top - 0.05, float(tz)), Vector3(float(tx), 2.7, float(tz)), 0.008, 0.008, 3, IRON, false)
			pk.lathe(kit, "bulb", Vector3(float(tx), 2.45, float(tz)), [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.18, 0.12), Vector2(0.06, 0.25), Vector2(0.001, 0.26)],
					10, Color(1.0, 0.88, 0.62))
	# The roof slab, its fascia and soffit with downlights.
	var oh := 1.8
	T._wblock(pk, kit, "plaster", Vector3(-oh, top, -D - 0.6), Vector3(W + oh, top + 0.22, oh), Color(0.9, 0.89, 0.86), true, true)
	T._wblock(pk, kit, "painted", Vector3(-oh - 0.04, top - 0.1, oh - 0.02), Vector3(W + oh + 0.04, top + 0.42, oh + 0.06), cream)
	T._wblock(pk, kit, "painted", Vector3(-oh - 0.06, top - 0.1, -D - 0.6), Vector3(-oh + 0.02, top + 0.42, oh + 0.06), cream)
	T._wblock(pk, kit, "painted", Vector3(W + oh - 0.02, top - 0.1, -D - 0.6), Vector3(W + oh + 0.06, top + 0.42, oh + 0.06), cream)
	T._wblock(pk, kit, "painted", Vector3(-oh - 0.04, top + 0.42, oh - 0.02), Vector3(W + oh + 0.04, top + 0.46, oh + 0.07), Color(0.12, 0.30, 0.26))
	_label(labels, ShopNames.unique("cafe", "Café am Strom"), Vector3(W * 0.5, top + 0.16, oh + 0.09), Vector3(0, 0, 1), 0.36, Color(0.12, 0.30, 0.26), W)
	var lx := -0.8
	while lx < W + 0.9:
		for lz in [0.9, -D - 0.1]:
			pk.tube(kit, "bulb", Vector3(lx, top - 0.005, float(lz)), Vector3(lx, top - 0.02, float(lz)), 0.08, 0.08, 8, Color(1.0, 0.92, 0.75), true)
		lx += 1.6
	# The terrace: paving, glass wind screens on its sides, parasols, tables, planters, a menu board.
	T._wblock(pk, kit, "ashlar", Vector3(-0.3, FOOT, 0.3), Vector3(W + 0.3, 0.12, 7.0), Color(0.72, 0.70, 0.66))
	for sx in [-0.2, W + 0.2]:
		for k2 in range(4):
			var z0: float = 0.6 + float(k2) * 1.6
			pk.quad(kit, "wglass", [Vector3(float(sx), 0.2, z0), Vector3(float(sx), 0.2, z0 + 1.5), Vector3(float(sx), 1.35, z0 + 1.5), Vector3(float(sx), 1.35, z0)],
					Vector3(-1 if sx < 1.0 else 1, 0, 0), Color(0.8, 0.9, 0.9, 0.22))
			pk.quad(kit, "wglass", [Vector3(float(sx), 0.2, z0), Vector3(float(sx), 1.35, z0), Vector3(float(sx), 1.35, z0 + 1.5), Vector3(float(sx), 0.2, z0 + 1.5)],
					Vector3(1 if sx < 1.0 else -1, 0, 0), Color(0.8, 0.9, 0.9, 0.22))
			pk.beam(kit, "metal", Vector3(float(sx), 0.12, z0), Vector3(float(sx), 1.4, z0), 0.05, 0.05, Color(0.6, 0.6, 0.62))
		pk.beam(kit, "metal", Vector3(float(sx), 1.4, 0.6), Vector3(float(sx), 1.4, 7.0), 0.05, 0.05, Color(0.6, 0.6, 0.62), Vector3.UP)
	for k3 in range(4):
		var px: float = 1.9 + float(k3) * 3.4
		_parasol(pk, kit, Vector3(px, 0.12, 4.0), 1.5, Color(0.95, 0.93, 0.86), Color(0.12, 0.30, 0.26))
		_bistro_set(pk, kit, Vector3(px - 0.8, 0.12, 3.4), Color(0.94, 0.93, 0.9), Color(0.12, 0.30, 0.26), 2)
		_bistro_set(pk, kit, Vector3(px + 0.8, 0.12, 4.9), Color(0.94, 0.93, 0.9), Color(0.12, 0.30, 0.26), 2)
	var prng := RandomNumberGenerator.new()
	prng.seed = 77
	for pc in [Vector3(0.4, 0.12, 6.6), Vector3(W - 0.4, 0.12, 6.6)]:
		T._wblock(pk, kit, "painted", pc + Vector3(-0.35, 0, -0.35), pc + Vector3(0.35, 0.55, 0.35), Color(0.2, 0.22, 0.22))
		T._bush(pk, kit, pc + Vector3(0, 0.55, 0), 0.4, Color(0.25, 0.45, 0.2), prng)
	_menu_board(pk, kit, labels, Vector3(W * 0.5 + 1.6, 0.12, 7.2), "Kaffee & Kuchen", Color(0.12, 0.30, 0.26))


## An A-frame menu board (Kundenstopper) at c (on the ground), facing +z: a chalk board with a heading.
static func _menu_board(pk: PropKit, kit: Dictionary, labels: Array, c: Vector3, text: String, col: Color) -> void:
	for sz in [-1.0, 1.0]:
		var a: Vector3 = c + Vector3(-0.32, 0, sz * 0.28)
		var b: Vector3 = c + Vector3(0.32, 0, sz * 0.28)
		var t0: Vector3 = c + Vector3(-0.32, 1.0, sz * 0.03)
		var t1: Vector3 = c + Vector3(0.32, 1.0, sz * 0.03)
		var nrm := Vector3(0, 0.25, sz).normalized()
		pk.quad(kit, "paint", [a, b, t1, t0], nrm, col)
		# The chalk board: the face shrunk toward its middle, 1.2cm in front of it.
		var mid: Vector3 = (a + b + t0 + t1) * 0.25
		var board: Array = []
		for q in [a, b, t1, t0]:
			board.append(mid + ((q as Vector3) - mid) * Vector3(0.82, 0.8, 0.8) + nrm * 0.012)
		pk.quad(kit, "paint", board, nrm, Color(0.12, 0.13, 0.12))
		pk.quad(kit, "paint", [a, t0, t1, b], -nrm, col.darkened(0.3))
	var ln := Vector3(0, 0.25, 1).normalized()
	_label(labels, text, c + Vector3(0, 0.62, 0.28 - 0.25 * 0.62) + ln * 0.025, ln, 0.06, Color(0.95, 0.95, 0.92), 0.48)


## A kiosk on the promenade, its hatch toward +z, x -1.6..1.6, z -1.2..1.2 (its flap awning out to z = 2.0): `kind` "eis"
## (pastel, a big ice cream cone on the roof, a chest freezer under a parasol), "getraenke" (a green drinks kiosk with crates
## and a cooler), "fahrrad" (a timber bike-hire hut with six bikes on a rack). The name on a board over the hatch.
static func kiosk(pk: PropKit, kit: Dictionary, labels: Array, kind: String) -> void:
	var body: Color
	var accent: Color
	var name_text: String
	var key := "painted"
	match kind:
		"eis":
			body = Color(0.96, 0.90, 0.88)
			accent = Color(0.86, 0.36, 0.48)
			name_text = "Eiskiosk Rheinperle"
		"fahrrad":
			body = Color(0.55, 0.40, 0.25)
			accent = Color(0.12, 0.32, 0.52)
			name_text = "Fahrradverleih Rheinrad"
			key = "lapboards"
		_:
			body = Color(0.16, 0.38, 0.27)
			accent = Color(0.92, 0.75, 0.20)
			name_text = "Kiosk am Ufer"
	var hw := 1.6
	var hd := 1.2
	var hgt := 2.75
	# The walls, a hatch in the front, the counter and a flap awning over it.
	var walls: Array = [[Vector3(-hw, 0, hd), Vector3(0, 0, 1), hw * 2.0], [Vector3(hw, 0, hd), Vector3(1, 0, 0), hd * 2.0], [Vector3(hw, 0, -hd), Vector3(0, 0, -1), hw * 2.0],
			[Vector3(-hw, 0, -hd), Vector3(-1, 0, 0), hd * 2.0]]
	for wl in walls:
		var wf := T._wf(wl[0], wl[1])
		if (wl[1] as Vector3).z > 0.5:
			T._face(pk, kit, key, wf, 0.0, -0.3, float(wl[2]), 1.0, 0.0, body)
			T._face(pk, kit, key, wf, 0.0, 2.2, float(wl[2]), hgt, 0.0, body)
			T._face(pk, kit, key, wf, 0.0, 1.0, 0.3, 2.2, 0.0, body)
			T._face(pk, kit, key, wf, float(wl[2]) - 0.3, 1.0, float(wl[2]), 2.2, 0.0, body)
		else:
			T._face(pk, kit, key, wf, 0.0, -0.3, float(wl[2]), hgt, 0.0, body)
	# The inside seen through the hatch: dark, a back shelf of goods.
	T._wblock(pk, kit, "matte", Vector3(-hw + 0.3, 1.0, -hd + 0.05), Vector3(hw - 0.3, 2.2, -hd + 0.1), Color(0.12, 0.10, 0.09))
	T._wblock(pk, kit, "matte", Vector3(-hw + 0.05, 2.15, -hd + 0.05), Vector3(hw - 0.05, 2.2, hd - 0.05), Color(0.2, 0.18, 0.16), false, true)
	for k in range(6):
		T._wblock(pk, kit, "paint", Vector3(-hw + 0.45 + float(k) * 0.42, 1.55, -hd + 0.1), Vector3(-hw + 0.75 + float(k) * 0.42, 1.85, -hd + 0.3),
				[accent, Color(0.9, 0.9, 0.85), Color(0.3, 0.5, 0.8)][k % 3])
	T._wblock(pk, kit, "wood", Vector3(-hw + 0.25, 0.98, hd - 0.25), Vector3(hw - 0.25, 1.04, hd + 0.3), Color(0.62, 0.45, 0.28))
	var nrm := Vector3(0, 1.0, 0.35).normalized()
	var stripes: Array = [accent, Color(0.97, 0.96, 0.94)]
	var ns := 8
	for s in range(ns):
		var xa: float = lerpf(-hw + 0.1, hw - 0.1, float(s) / float(ns))
		var xb: float = lerpf(-hw + 0.1, hw - 0.1, float(s + 1) / float(ns))
		pk.quad(kit, "canvas", [Vector3(xa, 2.32, hd + 0.02), Vector3(xb, 2.32, hd + 0.02), Vector3(xb, 2.05, hd + 0.8), Vector3(xa, 2.05, hd + 0.8)], nrm, stripes[s % 2])
		pk.quad(kit, "canvas", [Vector3(xa, 2.3, hd + 0.02), Vector3(xa, 2.03, hd + 0.8), Vector3(xb, 2.03, hd + 0.8), Vector3(xb, 2.3, hd + 0.02)], -nrm, (stripes[s % 2] as Color).darkened(0.3))
		pk.panel(kit, "canvas", [Vector3(xa, 2.05, hd + 0.81), Vector3(xb, 2.05, hd + 0.81), Vector3(xb, 1.88, hd + 0.81), Vector3(xa, 1.88, hd + 0.81)], Vector3(0, 0, 1),
				stripes[s % 2], (stripes[s % 2] as Color).darkened(0.3))
	# The roof: a slab overhanging 30cm, its fascia in the accent colour, the name board over the hatch.
	T._wblock(pk, kit, "painted", Vector3(-hw - 0.3, hgt, -hd - 0.3), Vector3(hw + 0.3, hgt + 0.18, hd + 0.3), accent, true, true)
	T._wblock(pk, kit, "painted", Vector3(-hw + 0.05, hgt + 0.18, hd + 0.05), Vector3(hw - 0.05, hgt + 0.78, hd + 0.15), Color(0.97, 0.96, 0.92))
	_label(labels, ShopNames.unique("kiosk", name_text), Vector3(0, hgt + 0.48, hd + 0.18), Vector3(0, 0, 1), 0.2, accent.darkened(0.2), hw * 2.0 - 0.3)
	match kind:
		"eis":
			# The cone on the roof and its scoops.
			var cc := Vector3(-0.7, hgt + 0.18, -0.2)
			pk.lathe(kit, "paint", cc, [Vector2(0.001, 0.0), Vector2(0.06, 0.05), Vector2(0.38, 1.1), Vector2(0.4, 1.2), Vector2(0.001, 1.2)], 10, Color(0.82, 0.62, 0.34))
			var scoops: Array = [Color(0.98, 0.94, 0.86), Color(0.92, 0.48, 0.58), Color(0.45, 0.28, 0.18)]
			for k2 in range(3):
				var sc: Vector3 = cc + Vector3(0.0, 1.38 + 0.3 * float(k2), 0.0) + Vector3(sin(float(k2) * 2.0) * 0.06, 0, 0)
				pk.lathe(kit, "gloss", sc, [Vector2(0.001, -0.22), Vector2(0.26, -0.12), Vector2(0.4 - 0.05 * float(k2), 0.02), Vector2(0.3, 0.2), Vector2(0.001, 0.3)], 12,
						scoops[k2])
			# A chest freezer under a parasol, a menu board.
			T._wblock(pk, kit, "gloss", Vector3(hw + 0.3, 0.0, 0.0), Vector3(hw + 1.5, 0.85, 0.75), Color(0.94, 0.94, 0.95))
			pk.quad(kit, "wglass", [Vector3(hw + 0.35, 0.86, 0.05), Vector3(hw + 1.45, 0.86, 0.05), Vector3(hw + 1.45, 0.86, 0.7), Vector3(hw + 0.35, 0.86, 0.7)], Vector3.UP,
					Color(0.7, 0.85, 0.9, 0.4))
			_parasol(pk, kit, Vector3(hw + 0.9, 0.0, 0.4), 1.1, Color(0.96, 0.94, 0.9), accent)
			_menu_board(pk, kit, labels, Vector3(-hw - 0.6, 0.0, 1.4), "Eis · 1,80 € die Kugel", accent)
		"fahrrad":
			var cols: Array = [Color(0.12, 0.32, 0.52), Color(0.7, 0.12, 0.1), Color(0.15, 0.5, 0.3), Color(0.85, 0.6, 0.1), Color(0.2, 0.2, 0.22), Color(0.55, 0.55, 0.6)]
			for k3 in range(6):
				var bx: float = hw + 0.6 + float(k3) * 0.62
				_bicycle(pk, kit, Vector3(bx, 0, 0.4), Vector3(0, 0, 1), cols[k3])
			pk.beam(kit, "metal", Vector3(hw + 0.4, 0.45, 0.95), Vector3(hw + 4.3, 0.45, 0.95), 0.05, 0.05, Color(0.6, 0.6, 0.62), Vector3.UP)
			_menu_board(pk, kit, labels, Vector3(-hw - 0.6, 0.0, 1.4), "Fahrräder ab 9 € am Tag", accent)
		_:
			for k4 in range(4):
				for j in range(1 + k4 % 2):
					var cx: float = hw + 0.5 + float(k4) * 0.42
					T._wblock(pk, kit, "plastic", Vector3(cx, float(j) * 0.29, 0.1), Vector3(cx + 0.4, float(j) * 0.29 + 0.28, 0.4), [Color(0.12, 0.32, 0.55), Color(0.62, 0.12, 0.1)][k4 % 2])
			T._wblock(pk, kit, "gloss", Vector3(-hw - 0.9, 0.0, -0.5), Vector3(-hw - 0.05, 1.9, 0.2), Color(0.85, 0.12, 0.12))
			pk.quad(kit, "wglass", [Vector3(-hw - 0.85, 0.15, 0.21), Vector3(-hw - 0.1, 0.15, 0.21), Vector3(-hw - 0.1, 1.6, 0.21), Vector3(-hw - 0.85, 1.6, 0.21)], Vector3(0, 0, 1),
					Color(0.75, 0.9, 0.95, 0.45))
			for k5 in range(4):
				T._wblock(pk, kit, "paint", Vector3(-hw - 0.8, 0.25 + float(k5) * 0.35, -0.4), Vector3(-hw - 0.15, 0.27 + float(k5) * 0.35, 0.15), Color(0.7, 0.7, 0.7))
			_label(labels, "Getränke", Vector3(-hw - 0.475, 1.75, 0.23), Vector3(0, 0, 1), 0.08, Color(0.98, 0.98, 0.96), 0.7)


## A promenade lamp (Kandelaber), 4.6m, standing on the origin: a fluted cast-iron foot on a plinth, a shaft with collars,
## a scrolled cross-arm carrying two opal globes and a third on top.
static func promenade_lamp(pk: PropKit, kit: Dictionary) -> void:
	var cast := Color(0.12, 0.17, 0.15)
	pk.lathe(kit, "metal", Vector3(0, -0.3, 0), [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.42), Vector2(0.24, 0.5), Vector2(0.22, 0.95), Vector2(0.15, 1.15),
			Vector2(0.11, 1.3), Vector2(0.001, 1.3)], 8, cast, true)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0 + PI / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		pk.beam(kit, "metal", d * 0.225 + Vector3(0, 0.25, 0), d * 0.215 + Vector3(0, 0.62, 0), 0.04, 0.03, cast, Vector3(-d.z, 0, d.x))
	pk.tube(kit, "metal", Vector3(0, 0.95, 0), Vector3(0, 4.0, 0), 0.085, 0.06, 8, cast, false)
	for y in [1.25, 2.6, 3.95]:
		pk.tube(kit, "metal", Vector3(0, float(y), 0), Vector3(0, float(y) + 0.07, 0), 0.11, 0.11, 8, cast, true)
	# The cross-arm: two scrolls out to the globes' fittings.
	for sx in [-1.0, 1.0]:
		var pts: Array = []
		for k2 in range(9):
			var t: float = float(k2) / 8.0
			pts.append(Vector3(sx * 0.75 * t, 3.75 + 0.25 * sin(t * PI), 0))
		for k3 in range(pts.size() - 1):
			pk.tube(kit, "metal", pts[k3], pts[k3 + 1], 0.035, 0.035, 4, cast, false)
		var curl: Array = []
		for k4 in range(8):
			var a2: float = PI * 0.5 + TAU * float(k4) / 8.0
			curl.append(Vector3(sx * (0.32 + cos(a2) * 0.12 * (1.0 - float(k4) / 10.0)), 3.62 + sin(a2) * 0.12 * (1.0 - float(k4) / 10.0), 0))
		for k5 in range(curl.size() - 1):
			pk.tube(kit, "metal", curl[k5], curl[k5 + 1], 0.02, 0.02, 4, cast, false)
		var f: Vector3 = Vector3(sx * 0.75, 3.75, 0)
		_globe(pk, kit, f, cast)
	_globe(pk, kit, Vector3(0, 4.05, 0), cast)


## An opal glass globe on its fitting, standing on `p`.
static func _globe(pk: PropKit, kit: Dictionary, p: Vector3, cast: Color) -> void:
	pk.lathe(kit, "metal", p, [Vector2(0.06, -0.05), Vector2(0.1, 0.06), Vector2(0.001, 0.07)], 6, cast, true)
	pk.lathe(kit, "gloss", p + Vector3(0, 0.06, 0), [Vector2(0.001, 0.0), Vector2(0.15, 0.03), Vector2(0.23, 0.2), Vector2(0.19, 0.39), Vector2(0.001, 0.48)], 10,
			Color(0.97, 0.96, 0.92))
	pk.lathe(kit, "metal", p + Vector3(0, 0.47, 0), [Vector2(0.06, 0.0), Vector2(0.001, 0.14)], 6, cast, true)


## A plane tree's cast-iron grate and guard, centred on the trunk (the origin, on the ground): a square grate 1.8m across,
## 3.5cm proud, rings of bars round a 0.9m hole; four posts round the trunk with two rings and arches, 1.25m tall.
static func plane_tree_guard(pk: PropKit, kit: Dictionary) -> void:
	var cast := Color(0.12, 0.14, 0.13)
	var h := 0.9
	var gy := 0.035
	T._wblock(pk, kit, "metal", Vector3(-h, 0.0, -h), Vector3(h, gy, -h + 0.08), cast)
	T._wblock(pk, kit, "metal", Vector3(-h, 0.0, h - 0.08), Vector3(h, gy, h), cast)
	T._wblock(pk, kit, "metal", Vector3(-h, 0.0, -h + 0.08), Vector3(-h + 0.08, gy, h - 0.08), cast)
	T._wblock(pk, kit, "metal", Vector3(h - 0.08, 0.0, -h + 0.08), Vector3(h, gy, h - 0.08), cast)
	# The grate's rings and radial bars: flat iron, its top face only (it lies on the pavement).
	var segs := 16
	for r in [0.46, 0.62, 0.78]:
		for k in range(segs):
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k + 1) / float(segs)
			var e0 := Vector3(cos(a0), 0, sin(a0))
			var e1 := Vector3(cos(a1), 0, sin(a1))
			pk.quad(kit, "metal", [e0 * (r - 0.035) + Vector3(0, gy, 0), e1 * (r - 0.035) + Vector3(0, gy, 0), e1 * r + Vector3(0, gy, 0), e0 * r + Vector3(0, gy, 0)],
					Vector3.UP, cast)
	for k2 in range(segs):
		var a: float = TAU * float(k2) / float(segs)
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.018
		var out: float = minf((h - 0.06) / maxf(absf(cos(a)), absf(sin(a))), 1.2)
		pk.quad(kit, "metal", [d * 0.44 - side + Vector3(0, gy - 0.003, 0), d * 0.44 + side + Vector3(0, gy - 0.003, 0), d * out + side + Vector3(0, gy - 0.003, 0),
				d * out - side + Vector3(0, gy - 0.003, 0)], Vector3.UP, cast)
	# The guard: four posts with knobs, two rings, arches between the posts.
	var r2 := 0.58
	for k3 in range(4):
		var a2: float = PI * 0.25 + PI * 0.5 * float(k3)
		var p := Vector3(cos(a2) * r2, 0, sin(a2) * r2)
		pk.tube(kit, "metal", p, p + Vector3(0, 1.25, 0), 0.025, 0.025, 5, cast, false)
		T._blob(pk, kit, "metal", p + Vector3(0, 1.3, 0), Vector3(0.05, 0.06, 0.05), cast)
	for y in [0.35, 1.15]:
		for k4 in range(12):
			var b0: float = TAU * float(k4) / 12.0
			var b1: float = TAU * float(k4 + 1) / 12.0
			pk.tube(kit, "metal", Vector3(cos(b0) * r2, float(y), sin(b0) * r2), Vector3(cos(b1) * r2, float(y), sin(b1) * r2), 0.014, 0.014, 4, cast, false)
	for k5 in range(4):
		var a3: float = PI * 0.25 + PI * 0.5 * float(k5)
		var prev := Vector3.ZERO
		for j in range(6):
			var t: float = float(j) / 5.0
			var ang: float = lerpf(a3, a3 + PI * 0.5, t)
			var q := Vector3(cos(ang) * r2, 0.35 + sin(t * PI) * 0.55, sin(ang) * r2)
			if j > 0:
				pk.tube(kit, "metal", prev, q, 0.012, 0.012, 4, cast, false)
			prev = q


## A promenade bench (YardKit's slatted bench on cast-iron ends), 2m long, the middle of its front edge on the origin,
## facing +z.
static func bench(pk: PropKit, kit: Dictionary) -> void:
	YK.bench(pk, kit, Vector3.ZERO, Vector3(0, 0, 1), 2.0)


## A litter bin on a post standing on the origin: a dark green steel drum with a rain hood and an ashtray, 1.15m.
static func bin(pk: PropKit, kit: Dictionary) -> void:
	var green := Color(0.14, 0.27, 0.20)
	pk.tube(kit, "metal", Vector3(0, -0.3, -0.3), Vector3(0, 1.1, -0.3), 0.04, 0.04, 6, Color(0.5, 0.52, 0.52), true)
	pk.lathe(kit, "paint", Vector3(0, 0.35, 0), [Vector2(0.001, 0.0), Vector2(0.22, 0.0), Vector2(0.25, 0.05), Vector2(0.25, 0.62), Vector2(0.27, 0.66), Vector2(0.22, 0.66),
			Vector2(0.22, 0.6), Vector2(0.001, 0.6)], 12, green, false)
	pk.lathe(kit, "paint", Vector3(0, 1.08, 0), [Vector2(0.001, 0.0), Vector2(0.28, 0.0), Vector2(0.26, 0.05), Vector2(0.14, 0.14), Vector2(0.001, 0.16)], 12, green.darkened(0.1), true)
	for k in range(3):
		var a: float = TAU * float(k) / 3.0
		pk.beam(kit, "metal", Vector3(cos(a) * 0.2, 1.01, sin(a) * 0.2), Vector3(cos(a) * 0.2, 1.09, sin(a) * 0.2), 0.03, 0.03, green)
	pk.lathe(kit, "metal", Vector3(0.0, 0.98, 0.0), [Vector2(0.001, 0.0), Vector2(0.12, 0.0), Vector2(0.12, 0.04), Vector2(0.001, 0.04)], 8, Color(0.6, 0.6, 0.62), true)


# ======================================================================================
#  The Rheinkirmes: the Ferris wheel
# ======================================================================================

## The hub's height over the base's ground (life).
const WHEEL_HUB_Y := 25.6
## The gondolas' pivots' radius (KirmesWheel's / FerrisWheel's `cabin_radius`).
const WHEEL_PIVOT_R := 21.0
const WHEEL_CABINS := 36
## Gondola colourways (ferris_wheel_gondola's `variant`): mount i takes colour i % this.
const WHEEL_GONDOLA_COLOURS := 4
## The rims' planes either side of the wheel's middle, and the A-frames' (the bearings').
const WHEEL_RIM_Z := 1.75
const WHEEL_LEG_Z := 5.0
const WHEEL_WHITE := Color(0.93, 0.93, 0.91)
const GONDOLA_COLS := [Color(0.80, 0.12, 0.12), Color(0.95, 0.74, 0.12), Color(0.14, 0.36, 0.72), Color(0.16, 0.56, 0.32)]


static func _polar(r: float, a: float, z: float) -> Vector3:
	return Vector3(cos(a) * r, sin(a) * r, z)


## A ring of tube round the z axis (radius r, in the plane at z), `segs` pieces, `tr` thick.
static func _ring_z(pk: PropKit, kit: Dictionary, key: String, r: float, z: float, segs: int, tr: float, col: Color, sides := 5) -> void:
	for k in range(segs):
		pk.tube(kit, key, _polar(r, TAU * float(k) / float(segs), z), _polar(r, TAU * float(k + 1) / float(segs), z), tr, tr, sides, col, false)


## The wheel's rotor, built round the hub at the origin turning about z (the wheel's plane x-y): two rims (WHEEL_RIM_Z
## either side; outer and inner chords laced together) on 18 spokes a side from the hub's flanges (2.6m out along the
## axle), thin cross rods, the 36 gondola axles between the rims at WHEEL_PIVOT_R, ties between the rims midway between the
## gondolas, the hub with a gilt sunburst on its front (+z) face, and bulbs (subtle in daylight) along the spokes and rims.
## Rim radius about 21.1m. About 9k triangles.
static func ferris_wheel_rotor(pk: PropKit, kit: Dictionary) -> void:
	var R := WHEEL_PIVOT_R
	var zr := WHEEL_RIM_Z
	var segs := 72
	var w := WHEEL_WHITE
	var ri: float = R - 1.25
	for side in [-1.0, 1.0]:
		var z: float = side * zr
		_ring_z(pk, kit, "steel", R + 0.12, z, segs, 0.11, w)
		_ring_z(pk, kit, "steel", ri, z, segs, 0.1, w)
		for k in range(segs):
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k + 1) / float(segs)
			pk.tube(kit, "steel", _polar(R + 0.12, a0, z), _polar(ri, a1, z), 0.045, 0.045, 4, w, false)
		for j in range(18):
			var a: float = TAU * float(j) / 18.0
			pk.tube(kit, "steel", _polar(1.35, a, side * 2.6), _polar(ri, a, z), 0.1, 0.07, 6, w, false)
			pk.tube(kit, "steel", _polar(1.35, a + TAU / 36.0, side * 2.45), _polar(ri, a + TAU / 36.0 + TAU / 72.0, z), 0.03, 0.03, 4, w.darkened(0.15), false)
			# Bulbs along the spoke on its outer side.
			for b in range(1, 6):
				var t: float = float(b) / 6.0
				var bp: Vector3 = _polar(lerpf(1.35, ri, t), a, lerpf(side * 2.6, z, t)) + Vector3(0, 0, side * 0.11)
				T._blob(pk, kit, "bulb", bp, Vector3.ONE * 0.09, BULB_COLS[(j + b) % 3])
		for k2 in range(segs):
			var a2: float = TAU * (float(k2) + 0.5) / float(segs)
			T._blob(pk, kit, "bulb", _polar(R + 0.12, a2, z + side * 0.13), Vector3.ONE * 0.09, BULB_COLS[k2 % BULB_COLS.size()])
	for i in range(WHEEL_CABINS):
		var a3: float = TAU * float(i) / float(WHEEL_CABINS)
		pk.tube(kit, "steel", _polar(R, a3, -zr - 0.05), _polar(R, a3, zr + 0.05), 0.06, 0.06, 6, IRON, true)
		for side2 in [-1.0, 1.0]:
			pk.beam(kit, "steel", _polar(R, a3, side2 * zr), _polar(R + 0.12, a3, side2 * zr), 0.16, 0.06, w, Vector3(0, 0, 1))
		var a4: float = a3 + TAU / 72.0
		pk.tube(kit, "steel", _polar(R + 0.12, a4, -zr), _polar(R + 0.12, a4, zr), 0.05, 0.05, 4, w, false)
	# The hub: a drum with flanges, a red and white face on the front, a gilt sunburst.
	pk.lathe(kit, "steel", Vector3.ZERO, [Vector2(0.001, -2.8), Vector2(1.5, -2.8), Vector2(1.5, -2.5), Vector2(1.05, -2.35), Vector2(1.05, 2.35), Vector2(1.5, 2.5),
			Vector2(1.5, 2.8), Vector2(0.001, 2.8)], 18, w, false, Basis(Vector3.RIGHT, PI * 0.5))
	pk.tube(kit, "paint", Vector3(0, 0, 2.8), Vector3(0, 0, 2.86), 1.3, 1.3, 18, Color(0.78, 0.12, 0.12), true)
	pk.tube(kit, "paint", Vector3(0, 0, 2.86), Vector3(0, 0, 2.9), 0.75, 0.75, 18, WHEEL_WHITE, true)
	for k3 in range(16):
		var a5: float = TAU * float(k3) / 16.0
		var rl: float = 1.75 if k3 % 2 == 0 else 1.35
		var dd := Vector3(cos(a5), sin(a5), 0.0)
		var side3 := Vector3(-sin(a5), cos(a5), 0.0)
		pk.tri(kit, "gold", Vector3(0, 0, 2.93) + dd * 0.7 + side3 * 0.12, Vector3(0, 0, 2.93) + dd * 0.7 - side3 * 0.12, Vector3(0, 0, 2.93) + dd * rl,
				Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), GOLD, Vector3(0, 0, 1))
	T._blob(pk, kit, "gold", Vector3(0, 0, 2.95), Vector3(0.35, 0.35, 0.12), GOLD)
	pk.tube(kit, "paint", Vector3(0, 0, -2.8), Vector3(0, 0, -2.86), 1.3, 1.3, 18, Color(0.78, 0.12, 0.12), true)


## A gondola, its origin at its pivot on the axle between the rims (it hangs straight down from it): two hanger bars from
## sleeves on the axle (z ±0.72) to the roof, a white domed roof with bulbs round its eave, an open window band on posts, a
## tub in the colourway's colour (`variant` % 4: red, yellow, blue, green) with a white rim and a band, a ring bench and a
## floor inside. 1.72m across (z ±0.86), 2.6m tall (to y = -2.6). About 330 triangles.
static func ferris_wheel_gondola(pk: PropKit, kit: Dictionary, variant := 0) -> void:
	var col: Color = GONDOLA_COLS[posmod(variant, GONDOLA_COLS.size())]
	var w := WHEEL_WHITE
	for sz in [-0.72, 0.72]:
		pk.tube(kit, "steel", Vector3(0, 0, float(sz) - 0.06), Vector3(0, 0, float(sz) + 0.06), 0.1, 0.1, 6, IRON, true)
		pk.beam(kit, "steel", Vector3(0, 0, float(sz)), Vector3(0, -0.62, float(sz) * 0.96), 0.08, 0.04, IRON)
	pk.beam(kit, "steel", Vector3(0, -0.62, -0.72), Vector3(0, -0.62, 0.72), 0.1, 0.06, IRON)
	pk.lathe(kit, "paint", Vector3(0, -1.0, 0), [Vector2(0.001, 0.0), Vector2(0.86, 0.0), Vector2(0.86, 0.06), Vector2(0.62, 0.24), Vector2(0.26, 0.37), Vector2(0.001, 0.4)],
			8, w, false, Basis(Vector3.UP, PI / 8.0))
	for k in range(8):
		var a: float = TAU * float(k) / 8.0 + PI / 8.0
		T._blob(pk, kit, "bulb", Vector3(cos(a) * 0.87, -0.97, sin(a) * 0.87), Vector3.ONE * 0.06, BULB_COLS[k % 2 * 3])
		var pa := Vector3(cos(a) * 0.74, 0, sin(a) * 0.74)
		pk.beam(kit, "steel", pa + Vector3(0, -1.9, 0), pa + Vector3(0, -0.98, 0), 0.05, 0.05, w)
	pk.lathe(kit, "paint", Vector3(0, -2.6, 0), [Vector2(0.001, 0.0), Vector2(0.62, 0.0), Vector2(0.76, 0.1), Vector2(0.8, 0.32), Vector2(0.8, 0.66), Vector2(0.84, 0.7),
			Vector2(0.84, 0.76), Vector2(0.75, 0.76), Vector2(0.75, 0.14), Vector2(0.001, 0.14)], 8, col, false, Basis(Vector3.UP, PI / 8.0))
	pk.lathe(kit, "paint", Vector3(0, -2.2, 0), [Vector2(0.805, 0.0), Vector2(0.805, 0.08)], 8, w, false, Basis(Vector3.UP, PI / 8.0))
	pk.lathe(kit, "paint", Vector3(0, -2.6, 0), [Vector2(0.73, 0.5), Vector2(0.42, 0.5), Vector2(0.42, 0.14)], 8, col.darkened(0.35), false, Basis(Vector3.UP, PI / 8.0))


## The wheel's stand, its origin on the ground under the hub, the wheel's plane x-y: a trailer base (x ±16, z ±7.5, 1.2m
## high, its skirts painted in panels), two lattice A-frames (WHEEL_LEG_Z either side, legs to x ±14) up to the axle's
## bearings at WHEEL_HUB_Y with the axle's stubs (out to the hub at z ±2.8), the boarding platform under the wheel (x ±4,
## z ±2.4, its top 2.0m up: the bottom gondola's floor 5cm over it) with railings and steps, stairs up from the front (+z)
## and the back, a decorated front with the name KRONENRAD over the entrance in bulbs, and the ticket booth (x -8, z 9.6).
## About 9k triangles.
static func ferris_wheel_base(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var H := WHEEL_HUB_Y
	var w := WHEEL_WHITE
	var deck := 1.2
	var red := Color(0.78, 0.12, 0.12)
	# The trailer base and its painted skirt.
	T._wblock(pk, kit, "metal", Vector3(-16, -0.3, -7.5), Vector3(16, deck, 7.5), Color(0.30, 0.30, 0.32))
	for sz in [-1.0, 1.0]:
		var wf := T._wf(Vector3(-16 if sz > 0 else 16, 0, sz * 7.5), Vector3(0, 0, sz))
		for k in range(16):
			var u0: float = float(k) * 2.0
			T._rect(pk, kit, "paint", wf, u0 + 0.06, 0.08, u0 + 1.94, deck - 0.08, 0.0, 0.03, red if k % 2 == 0 else w)
			T._rect(pk, kit, "gold", wf, u0 + 0.5, 0.45, u0 + 1.5, 0.55, 0.03, 0.045, GOLD)
	# The A-frames: lattice legs, ties, bearings and the axle's stubs.
	for side in [-1.0, 1.0]:
		var zb: float = side * WHEEL_LEG_Z
		var top := Vector3(0, H - 0.4, zb)
		for sx in [-1.0, 1.0]:
			_lattice_leg(pk, kit, Vector3(sx * 14.0, deck, side * (WHEEL_LEG_Z + 2.2)), top + Vector3(sx * 0.45, 0, 0), 1.2, 0.55, w)
			T._wblock(pk, kit, "metal", Vector3(sx * 14.0 - 0.9, deck, side * (WHEEL_LEG_Z + 2.2) - 0.9), Vector3(sx * 14.0 + 0.9, deck + 0.35, side * (WHEEL_LEG_Z + 2.2) + 0.9),
					Color(0.35, 0.35, 0.37))
		for ty in [9.0, 17.0]:
			var f: float = (float(ty) - deck) / (H - 0.4 - deck)
			var xl: float = lerpf(14.0, 0.45, f)
			var zl: float = side * lerpf(WHEEL_LEG_Z + 2.2, WHEEL_LEG_Z, f)
			pk.beam(kit, "steel", Vector3(-xl, float(ty), zl), Vector3(xl, float(ty), zl), 0.3, 0.3, w, Vector3(0, 0, 1))
		T._wblock(pk, kit, "metal", Vector3(-0.8, H - 1.0, zb - 0.5), Vector3(0.8, H + 0.6, zb + 0.5), Color(0.55, 0.56, 0.58))
		pk.tube(kit, "metal", Vector3(0, H, side * 2.78), Vector3(0, H, side * (WHEEL_LEG_Z + 0.6)), 0.34, 0.34, 12, Color(0.6, 0.6, 0.62), true)
		pk.tube(kit, "metal", Vector3(0, H, side * (WHEEL_LEG_Z + 0.5)), Vector3(0, H, side * (WHEEL_LEG_Z + 0.65)), 0.6, 0.6, 12, Color(0.45, 0.45, 0.47), true)
	# Braces between the two frames, low down.
	for sx2 in [-1.0, 1.0]:
		var a := Vector3(sx2 * 12.4, 4.0, -(WHEEL_LEG_Z + 1.95))
		var b := Vector3(sx2 * 12.4, 4.0, WHEEL_LEG_Z + 1.95)
		pk.beam(kit, "steel", a, b, 0.2, 0.2, w)
		pk.beam(kit, "steel", Vector3(sx2 * 13.6, deck + 0.4, -(WHEEL_LEG_Z + 2.15)), b, 0.12, 0.12, w)
		pk.beam(kit, "steel", Vector3(sx2 * 13.6, deck + 0.4, WHEEL_LEG_Z + 2.15), a, 0.12, 0.12, w)
	# The boarding platform under the wheel, its railings and steps.
	var py := 1.96
	T._wblock(pk, kit, "wood", Vector3(-4.0, deck, -2.4), Vector3(4.0, py, 2.4), Color(0.48, 0.34, 0.22))
	for zz in [-2.4, 2.4]:
		_railing(pk, kit, [Vector3(-4.0, py, float(zz)), Vector3(-1.4, py, float(zz))], 1.05, w, 0.3)
		_railing(pk, kit, [Vector3(1.4, py, float(zz)), Vector3(4.0, py, float(zz))], 1.05, w, 0.3)
		for k2 in range(4):
			T._wblock(pk, kit, "wood", Vector3(-1.4, deck, float(zz) + sign(float(zz)) * (0.3 * float(k2))), Vector3(1.4, py - 0.2 * float(k2), float(zz) + sign(float(zz)) * (0.3 * float(k2 + 1))),
					Color(0.5, 0.36, 0.24))
	for xx in [-4.0, 4.0]:
		_railing(pk, kit, [Vector3(float(xx), py, -2.4), Vector3(float(xx), py, 2.4)], 1.05, w, 0.3)
	# Stairs from the ground to the base at the front and the back, and the decorated front.
	for sz2 in [-1.0, 1.0]:
		for k3 in range(6):
			var top: float = deck - 0.2 * float(k3)
			T._wblock(pk, kit, "wood", Vector3(-2.2, -0.3, sz2 * 7.5 + sz2 * (0.32 * float(k3))), Vector3(2.2, top, sz2 * 7.5 + sz2 * (0.32 * float(k3 + 1))),
					Color(0.5, 0.36, 0.24))
	_wheel_front(pk, kit, labels, deck)
	_ticket_booth(pk, kit, labels, Vector3(-8.0, 0, 9.6), "Kronenrad", red)


## A lattice leg (four chords and laced faces) from the middle of its foot `a` to its top `b`, `wa` and `wb` wide there.
static func _lattice_leg(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, wa: float, wb: float, col: Color) -> void:
	var t: Vector3 = (b - a).normalized()
	var u: Vector3 = Vector3(0, 0, 1).cross(t).normalized()
	var v: Vector3 = t.cross(u).normalized()
	var corners: Array = [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]
	var pa: Array = []
	var pb: Array = []
	for c in corners:
		pa.append(a + u * float(c[0]) * wa * 0.5 + v * float(c[1]) * wa * 0.5)
		pb.append(b + u * float(c[0]) * wb * 0.5 + v * float(c[1]) * wb * 0.5)
	for i in range(4):
		pk.tube(kit, "steel", pa[i], pb[i], 0.07, 0.06, 6, col, false)
	var l: float = a.distance_to(b)
	var nb: int = maxi(int(l / 1.25), 2)
	for f in range(4):
		var i0: int = f
		var i1: int = (f + 1) % 4
		for k in range(nb):
			var t0: float = float(k) / float(nb)
			var t1: float = float(k + 1) / float(nb)
			var p0: Vector3 = (pa[i0] as Vector3).lerp(pb[i0], t0)
			var p1: Vector3 = (pa[i1] as Vector3).lerp(pb[i1], t1)
			pk.tube(kit, "steel", p0, p1, 0.035, 0.035, 4, col, false)
			if k % 3 == 0:
				pk.tube(kit, "steel", p0, (pa[i1] as Vector3).lerp(pb[i1], t0), 0.035, 0.035, 4, col, false)


## The wheel's front (+z) on the base: a low panelled balustrade along it, and over the stairs a portal of two pillars with
## a shaped board carrying the name in bulbs.
static func _wheel_front(pk: PropKit, kit: Dictionary, labels: Array, deck: float) -> void:
	var red := Color(0.78, 0.12, 0.12)
	var navy := Color(0.10, 0.16, 0.38)
	var fz := 7.4
	for xs in [[-15.8, -2.4], [2.4, 15.8]]:
		var x0: float = xs[0]
		var x1: float = xs[1]
		var n: int = int((x1 - x0) / 1.6)
		for k in range(n):
			var a: float = lerpf(x0, x1, float(k) / float(n))
			var b: float = lerpf(x0, x1, float(k + 1) / float(n))
			T._wblock(pk, kit, "paint", Vector3(a + 0.04, deck, fz - 0.08), Vector3(b - 0.04, deck + 1.1, fz), navy if k % 2 == 0 else red)
			T._wblock(pk, kit, "gold", Vector3(a + 0.2, deck + 0.2, fz), Vector3(b - 0.2, deck + 0.9, fz + 0.02), GOLD)
			T._wblock(pk, kit, "paint", Vector3(a + 0.26, deck + 0.26, fz + 0.02), Vector3(b - 0.26, deck + 0.84, fz + 0.035), navy if k % 2 == 1 else red)
			T._blob(pk, kit, "bulb", Vector3((a + b) * 0.5, deck + 1.18, fz - 0.04), Vector3.ONE * 0.08, BULB)
		T._wblock(pk, kit, "gold", Vector3(x0, deck + 1.1, fz - 0.12), Vector3(x1, deck + 1.16, fz + 0.04), GOLD)
	# The portal over the stairs.
	var ph := 6.2
	for sx in [-2.7, 2.7]:
		T._wblock(pk, kit, "paint", Vector3(float(sx) - 0.3, -0.3, fz + 1.5), Vector3(float(sx) + 0.3, ph, fz + 2.1), navy)
		for k2 in range(8):
			T._blob(pk, kit, "bulb", Vector3(float(sx), 0.6 + float(k2) * 0.7, fz + 2.13), Vector3.ONE * 0.08, BULB_COLS[k2 % 3])
		T._wblock(pk, kit, "gold", Vector3(float(sx) - 0.4, ph, fz + 1.4), Vector3(float(sx) + 0.4, ph + 0.15, fz + 2.2), GOLD)
	var bwf := T._wf(Vector3(0, 0, fz + 2.12), Vector3(0, 0, 1))
	var board := T._arch(0.0, ph - 0.6, 3.2, "segment", 14, 1.1)
	var ol := PackedVector2Array([Vector2(-3.2, ph - 1.7)])
	ol.append(Vector2(3.2, ph - 1.7))
	for k3 in range(board.size() - 1, -1, -1):
		ol.append(board[k3])
	var clean := PackedVector2Array()
	for q in ol:
		if clean.is_empty() or (clean[clean.size() - 1] as Vector2).distance_to(q) > 0.01:
			clean.append(q)
	T._prism(pk, kit, "paint", bwf, clean, -0.2, 0.0, red, Vector2(0, 1), true)
	for k4 in range(clean.size()):
		var a2: Vector2 = clean[k4]
		var b2: Vector2 = clean[(k4 + 1) % clean.size()]
		var nb: int = maxi(int(a2.distance_to(b2) / 0.35), 1)
		for j in range(nb):
			var q2: Vector2 = a2.lerp(b2, float(j) / float(nb))
			T._blob(pk, kit, "bulb", bwf * Vector3(q2.x, q2.y, 0.04), Vector3.ONE * 0.09, BULB_COLS[(k4 + j) % 2 * 3])
	_label(labels, "KRONENRAD", bwf * Vector3(0, ph - 0.85, 0.05), Vector3(0, 0, 1), 0.75, GOLD.lightened(0.25), 5.8)
	_crown(pk, kit, bwf * Vector3(0, ph + 0.45, -0.1), 0.9)


## A ticket booth (Kassenhäuschen) standing on c, its window toward +z: a panelled booth with a round-arched window, a gilt
## onion roof, KASSE over the window and the ride's name, a price board.
static func _ticket_booth(pk: PropKit, kit: Dictionary, labels: Array, c: Vector3, ride: String, col: Color) -> void:
	var hw := 1.1
	var hd := 0.9
	T._wblock(pk, kit, "paint", c + Vector3(-hw, 0, -hd), c + Vector3(hw, 2.5, hd), col)
	var wf := T._wf(c + Vector3(-hw, 0, hd), Vector3(0, 0, 1))
	T._pface(pk, kit, "pane", wf, T._opening(hw, 1.0, 0.6, 1.8, "round", 10), 0.02, GLASS)
	T._arch_ring(pk, kit, "gold", wf, hw, 1.8, 0.6, "round", 0.08, 0.0, 0.05, GOLD, 1.0, 10)
	T._rect(pk, kit, "wood", wf, hw - 0.75, 0.95, hw + 0.75, 1.02, 0.0, 0.25, Color(0.5, 0.35, 0.22))
	T._rect(pk, kit, "paint", wf, 0.1, 0.15, hw * 2.0 - 0.1, 0.8, 0.0, 0.03, Color(0.96, 0.92, 0.82))
	_label(labels, "Erwachsene 6 €  ·  Kinder 4 €", wf * Vector3(hw, 0.48, 0.05), Vector3(0, 0, 1), 0.08, Color(0.2, 0.15, 0.1), hw * 2.0 - 0.3)
	T._wblock(pk, kit, "gold", c + Vector3(-hw - 0.15, 2.5, -hd - 0.15), c + Vector3(hw + 0.15, 2.62, hd + 0.15), GOLD)
	T._rect(pk, kit, "paint", wf, 0.15, 2.65, hw * 2.0 - 0.15, 3.0, 0.0, 0.04, Color(0.1, 0.1, 0.12))
	_label(labels, "KASSE", wf * Vector3(hw, 2.81, 0.06), Vector3(0, 0, 1), 0.2, GOLD.lightened(0.2), hw * 2.0 - 0.4)
	pk.lathe(kit, "paint", c + Vector3(0, 2.62, 0), [Vector2(0.001, 0.0), Vector2(1.5, 0.0), Vector2(1.55, 0.2), Vector2(1.15, 0.65), Vector2(0.5, 1.05), Vector2(0.16, 1.35),
			Vector2(0.001, 1.65)], 12, Color(0.93, 0.72, 0.22))
	pk.lathe(kit, "gold", c + Vector3(0, 4.25, 0), [Vector2(0.001, 0.0), Vector2(0.1, 0.05), Vector2(0.12, 0.15), Vector2(0.001, 0.45)], 8, GOLD)
	for k in range(12):
		var a: float = TAU * float(k) / 12.0
		T._blob(pk, kit, "bulb", c + Vector3(cos(a) * 1.56, 2.72, sin(a) * 1.56), Vector3.ONE * 0.07, BULB)


# ======================================================================================
#  The chain swing ride (Kettenkarussell)
# ======================================================================================

## The chairs' hang points: their radius round the axis and their height over the base's ground, at rest (KirmesRide's
## Rotor stands at this height; its `hang_radius`, `chain_length`, `chairs`).
const SWING_HANG_R := 5.2
const SWING_HANG_Y := 6.0
const SWING_CHAIN := 5.0
const SWING_CHAIRS := 32
const SWING_FLOOR := 0.45

## The chain swing's base, its origin on the ground under the axis: a round wooden platform (r 11, 0.45m up) with painted
## skirt panels, a low fence round it with an entrance (+z) and an exit (-z), steps, the machine house and the painted
## column the rotor turns on (to SWING_HANG_Y + 2.3), an arch over the entrance with the ride's name, the ticket booth
## (x 6, z 13). The chairs swing out to about 8.8m from the axis at speed: keep people and props outside the fence (r 10.6).
## About 4.5k triangles.
static func chair_swing_base(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var R := 11.0
	var fl := SWING_FLOOR
	var cols: Array = [Color(0.85, 0.15, 0.15), Color(0.95, 0.75, 0.15), Color(0.15, 0.40, 0.75), Color(0.95, 0.95, 0.92)]
	var segs := 24
	pk.lathe(kit, "wood", Vector3.ZERO, [Vector2(R, -0.3), Vector2(R, fl), Vector2(0.001, fl)], segs, Color(0.55, 0.40, 0.26), true)
	for k in range(segs):
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var p0 := Vector3(cos(a0) * (R + 0.03), 0.0, sin(a0) * (R + 0.03))
		var p1 := Vector3(cos(a1) * (R + 0.03), 0.0, sin(a1) * (R + 0.03))
		var o: Vector3 = ((p0 + p1) * 0.5).normalized()
		pk.quad(kit, "paint", [p0 + Vector3(0, 0.03, 0), p1 + Vector3(0, 0.03, 0), p1 + Vector3(0, fl - 0.03, 0), p0 + Vector3(0, fl - 0.03, 0)], o, cols[k % 4])
	# The fence: posts and two rails with painted boards, gaps at the entrance and exit.
	var rf := 10.6
	for k2 in range(segs):
		var a2: float = TAU * float(k2) / float(segs)
		var a3: float = TAU * float(k2 + 1) / float(segs)
		var mid: float = (a2 + a3) * 0.5
		if absf(angle_difference(mid, PI * 0.5)) < 0.2 or absf(angle_difference(mid, -PI * 0.5)) < 0.2:
			continue
		var q0 := Vector3(cos(a2) * rf, fl, sin(a2) * rf)
		var q1 := Vector3(cos(a3) * rf, fl, sin(a3) * rf)
		pk.tube(kit, "metal", q0, q0 + Vector3(0, 1.05, 0), 0.04, 0.04, 6, WHEEL_WHITE, true)
		pk.beam(kit, "metal", q0 + Vector3(0, 1.0, 0), q1 + Vector3(0, 1.0, 0), 0.06, 0.05, WHEEL_WHITE, Vector3.UP)
		var o2: Vector3 = ((q0 + q1) * 0.5 - Vector3(0, fl, 0)).normalized()
		pk.panel(kit, "paint", [q0 + Vector3(0, 0.2, 0), q1 + Vector3(0, 0.2, 0), q1 + Vector3(0, 0.85, 0), q0 + Vector3(0, 0.85, 0)], o2, cols[(k2 + 1) % 4], cols[(k2 + 1) % 4].darkened(0.3))
	for sz in [-1.0, 1.0]:
		for k3 in range(3):
			T._wblock(pk, kit, "wood", Vector3(-1.4, -0.3, sz * (R + 0.3 * float(k3))), Vector3(1.4, fl - 0.15 * float(k3 + 1) + 0.15, sz * (R + 0.3 * float(k3 + 1))),
					Color(0.5, 0.36, 0.24))
	# The machine house and the column.
	pk.lathe(kit, "paint", Vector3(0, fl, 0), [Vector2(1.7, 0.0), Vector2(1.7, 2.1), Vector2(1.85, 2.18), Vector2(1.85, 2.3), Vector2(0.9, 2.5), Vector2(0.001, 2.52)], 8,
			Color(0.18, 0.30, 0.55), true)
	for k4 in range(8):
		var a4: float = TAU * float(k4) / 8.0 + PI / 8.0
		var face := Vector3(cos(a4), 0, sin(a4))
		var fwf := T._wf(Vector3(0, fl, 0) + face * 1.7 * cos(PI / 8.0) - Vector3(-sin(a4), 0, cos(a4)) * 0.0, face)
		T._rect(pk, kit, "gold", fwf, -0.45, 0.3, 0.45, 1.8, 0.0, 0.02, GOLD)
		T._rect(pk, kit, "paint", fwf, -0.38, 0.37, 0.38, 1.73, 0.02, 0.035, cols[k4 % 4])
	var col_top: float = SWING_HANG_Y + 2.3
	pk.lathe(kit, "paint", Vector3(0, fl + 2.5, 0), [Vector2(0.78, 0.0), Vector2(0.75, col_top - fl - 2.5), Vector2(0.001, col_top - fl - 2.5)], 8, WHEEL_WHITE, true)
	for k5 in range(8):
		var a5: float = TAU * float(k5) / 8.0
		var b0 := Vector3(cos(a5) * 0.8, fl + 2.6, sin(a5) * 0.8)
		pk.beam(kit, "gold", b0, b0 + Vector3(0, 0.7, 0), 0.05, 0.03, GOLD)
	# The entrance arch with the ride's name, the ticket booth.
	var az: float = R + 1.2
	for sx in [-1.6, 1.6]:
		pk.tube(kit, "paint", Vector3(float(sx), -0.3, az), Vector3(float(sx), 3.6, az), 0.12, 0.12, 8, Color(0.85, 0.15, 0.15), true)
		T._blob(pk, kit, "gold", Vector3(float(sx), 3.72, az), Vector3.ONE * 0.16, GOLD)
	T._wblock(pk, kit, "paint", Vector3(-2.0, 2.9, az - 0.06), Vector3(2.0, 3.5, az + 0.06), Color(0.10, 0.16, 0.38))
	_label(labels, "Kettenflieger Rheinwelle", Vector3(0, 3.2, az + 0.08), Vector3(0, 0, 1), 0.22, GOLD.lightened(0.2), 3.7)
	_label(labels, "Kettenflieger Rheinwelle", Vector3(0, 3.2, az - 0.08), Vector3(0, 0, -1), 0.22, GOLD.lightened(0.2), 3.7)
	for k6 in range(9):
		T._blob(pk, kit, "bulb", Vector3(-1.9 + float(k6) * 0.475, 3.56, az), Vector3.ONE * 0.07, BULB_COLS[k6 % 3])
	_ticket_booth(pk, kit, labels, Vector3(6.0, 0, 13.0), "Rheinwelle", Color(0.18, 0.30, 0.55))


## The chain swing's rotor, its origin on the axis at the chairs' hang points' height (KirmesRide turns it about y): the
## sleeve over the column, 32 arms out to the hang points (SWING_HANG_R), struts, the canopy (an umbrella of painted panels
## to r 6.1 and its underside in sun rays), a valance of painted panels and mirrors with bulbs, and a crowned lantern on top
## (to y 4.6). About 4k triangles.
static func chair_swing_rotor(pk: PropKit, kit: Dictionary) -> void:
	var cols: Array = [Color(0.85, 0.15, 0.15), Color(0.95, 0.75, 0.15), Color(0.15, 0.40, 0.75), Color(0.95, 0.95, 0.92)]
	var n := SWING_CHAIRS
	var R := SWING_HANG_R
	pk.tube(kit, "paint", Vector3(0, -2.4, 0), Vector3(0, 2.6, 0), 0.95, 0.95, 12, Color(0.18, 0.30, 0.55), true)
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		var d := Vector3(cos(a), 0, sin(a))
		pk.beam(kit, "steel", d * 0.9 + Vector3(0, 0.12, 0), d * (R + 0.15) + Vector3(0, 0.12, 0), 0.07, 0.1, WHEEL_WHITE)
		pk.tube(kit, "steel", d * R + Vector3(0, 0.08, 0), d * R - Vector3(0, 0.02, 0), 0.04, 0.04, 6, IRON, true)
		if i % 2 == 0:
			pk.beam(kit, "steel", d * 0.9 + Vector3(0, 2.2, 0), d * (R * 0.85) + Vector3(0, 0.15, 0), 0.04, 0.04, WHEEL_WHITE)
	# The canopy: panels from the valance's top up to the lantern, alternating colours, with an underside of rays.
	var segs := 16
	var r0 := 6.1
	var y0 := 0.55
	var r1 := 1.15
	var y1 := 2.5
	for k in range(segs):
		var a0: float = TAU * float(k) / float(segs)
		var a1: float = TAU * float(k + 1) / float(segs)
		var p0 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var q0 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var q1 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		var nrm: Vector3 = (p1 - p0).cross(q0 - p0).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		pk.quad(kit, "paint", [p0, p1, q1, q0], nrm, cols[k % 2] if k % 4 < 2 else cols[(k % 2) + 2])
		var dn := Vector3(0, -0.05, 0)
		pk.quad(kit, "paint", [p0 + dn, q0 + dn, q1 + dn, p1 + dn], -nrm, (cols[k % 4] as Color).darkened(0.25))
		# A rib of bulbs down the seam.
		pk.tube(kit, "gold", p0 + Vector3(0, 0.03, 0), q0 + Vector3(0, 0.03, 0), 0.04, 0.04, 4, GOLD, false)
		for b in range(1, 5):
			T._blob(pk, kit, "bulb", p0.lerp(q0, float(b) / 5.0) + Vector3(0, 0.08, 0), Vector3.ONE * 0.07, BULB_COLS[b % 3])
		# The valance: a painted panel with a gilt frame and a mirror, a scalloped edge, bulbs.
		var v0 := Vector3(cos(a0) * (r0 + 0.04), 0.0, sin(a0) * (r0 + 0.04))
		var v1 := Vector3(cos(a1) * (r0 + 0.04), 0.0, sin(a1) * (r0 + 0.04))
		var o: Vector3 = ((v0 + v1) * 0.5).normalized()
		pk.panel(kit, "paint", [v0 + Vector3(0, -0.55, 0), v1 + Vector3(0, -0.55, 0), v1 + Vector3(0, y0 + 0.02, 0), v0 + Vector3(0, y0 + 0.02, 0)], o, cols[(k + 1) % 4],
				(cols[(k + 1) % 4] as Color).darkened(0.35))
		var m0: Vector3 = v0.lerp(v1, 0.3) + o * 0.02
		var m1: Vector3 = v0.lerp(v1, 0.7) + o * 0.02
		pk.quad(kit, "gold", [m0 + Vector3(0, -0.4, 0), m1 + Vector3(0, -0.4, 0), m1 + Vector3(0, 0.4, 0), m0 + Vector3(0, 0.4, 0)], o, GOLD)
		pk.quad(kit, "chrome", [m0.lerp(m1, 0.12) + o * 0.01 + Vector3(0, -0.32, 0), m1.lerp(m0, 0.12) + o * 0.01 + Vector3(0, -0.32, 0),
				m1.lerp(m0, 0.12) + o * 0.01 + Vector3(0, 0.32, 0), m0.lerp(m1, 0.12) + o * 0.01 + Vector3(0, 0.32, 0)], o, Color(0.85, 0.88, 0.9))
		pk.tri(kit, "paint", v0 + Vector3(0, -0.55, 0) + o * 0.01, v1 + Vector3(0, -0.55, 0) + o * 0.01, (v0 + v1) * 0.5 + Vector3(0, -0.8, 0) + o * 0.01, o, o, o, GOLD, o)
		pk.tri(kit, "paint", v0 + Vector3(0, -0.55, 0) - o * 0.01, (v0 + v1) * 0.5 + Vector3(0, -0.8, 0) - o * 0.01, v1 + Vector3(0, -0.55, 0) - o * 0.01, -o, -o, -o, GOLD.darkened(0.3), -o)
		for b2 in range(2):
			T._blob(pk, kit, "bulb", v0.lerp(v1, 0.25 + 0.5 * float(b2)) + o * 0.06 + Vector3(0, 0.45, 0), Vector3.ONE * 0.07, BULB)
	# The lantern on top: a painted drum, a dome, a gilt finial and a pennant.
	pk.lathe(kit, "paint", Vector3(0, y1 - 0.05, 0), [Vector2(1.2, 0.0), Vector2(1.2, 0.08), Vector2(0.9, 0.12), Vector2(0.9, 1.0), Vector2(1.05, 1.08), Vector2(1.05, 1.16),
			Vector2(0.6, 1.6), Vector2(0.15, 1.85), Vector2(0.001, 1.9)], 8, Color(0.18, 0.30, 0.55), true)
	for k2 in range(8):
		var a2: float = TAU * float(k2) / 8.0 + PI / 8.0
		var f := Vector3(cos(a2), 0, sin(a2))
		var fwf := T._wf(Vector3(0, y1, 0) + f * 0.9 * cos(PI / 8.0), f)
		T._rect(pk, kit, "gold", fwf, -0.25, 0.15, 0.25, 0.85, 0.0, 0.02, GOLD)
		T._rect(pk, kit, "paint", fwf, -0.2, 0.2, 0.2, 0.8, 0.02, 0.035, cols[k2 % 4])
	pk.lathe(kit, "gold", Vector3(0, y1 + 1.85, 0), [Vector2(0.001, 0.0), Vector2(0.12, 0.05), Vector2(0.16, 0.18), Vector2(0.1, 0.3), Vector2(0.03, 0.4), Vector2(0.001, 0.75)], 8, GOLD)
	pk.tri(kit, "pennant", Vector3(0, y1 + 2.35, 0), Vector3(0, y1 + 2.05, 0), Vector3(0.7, y1 + 2.2, 0.1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Color(0.85, 0.12, 0.12),
			Vector3(0, 0, 1))


## A swing chair, its origin at its hang point (it hangs straight down; KirmesRide swings it out about the travel direction,
## local +z, with its outward side local +x): a swivel, a spreader, four chains to a bucket seat SWING_CHAIN under it (the
## seat's top at -SWING_CHAIN + 0.1), a footrest and a safety chain across the front. About 170 triangles.
static func chair_swing_chair(pk: PropKit, kit: Dictionary, variant := 0) -> void:
	var L := SWING_CHAIN
	var seat: Color = [Color(0.85, 0.15, 0.15), Color(0.15, 0.40, 0.75), Color(0.95, 0.75, 0.15)][posmod(variant, 3)]
	var chain := Color(0.6, 0.6, 0.62)
	pk.tube(kit, "metal", Vector3(0, 0.02, 0), Vector3(0, -0.12, 0), 0.04, 0.04, 6, chain, true)
	pk.beam(kit, "metal", Vector3(0, -0.14, -0.3), Vector3(0, -0.14, 0.3), 0.04, 0.04, chain)
	var fr: Array = [Vector3(-0.21, -L + 0.12, 0.2), Vector3(0.21, -L + 0.12, 0.2)]
	var bk: Array = [Vector3(-0.21, -L + 0.68, -0.24), Vector3(0.21, -L + 0.68, -0.24)]
	for p in fr:
		pk.tube(kit, "metal", Vector3(0, -0.14, 0.3), p, 0.012, 0.012, 3, chain, false)
	for p2 in bk:
		pk.tube(kit, "metal", Vector3(0, -0.14, -0.3), p2, 0.012, 0.012, 3, chain, false)
	# The seat: a pan, a back, chrome edges, the footrest, the safety chain.
	T._wblock(pk, kit, "gloss", Vector3(-0.23, -L + 0.0, -0.22), Vector3(0.23, -L + 0.1, 0.22), seat)
	pk.quad(kit, "gloss", [Vector3(-0.23, -L + 0.1, -0.24), Vector3(0.23, -L + 0.1, -0.24), Vector3(0.23, -L + 0.7, -0.29), Vector3(-0.23, -L + 0.7, -0.29)], Vector3(0, 0.08, 1).normalized(), seat)
	pk.quad(kit, "gloss", [Vector3(-0.23, -L + 0.1, -0.26), Vector3(-0.23, -L + 0.7, -0.31), Vector3(0.23, -L + 0.7, -0.31), Vector3(0.23, -L + 0.1, -0.26)], Vector3(0, -0.08, -1).normalized(),
			seat.darkened(0.3))
	pk.tube(kit, "chrome", Vector3(-0.24, -L + 0.11, 0.22), Vector3(0.24, -L + 0.11, 0.22), 0.02, 0.02, 5, Color(0.85, 0.86, 0.88), true)
	for sx in [-0.24, 0.24]:
		pk.tube(kit, "chrome", Vector3(float(sx), -L + 0.11, 0.22), Vector3(float(sx), -L + 0.11, -0.24), 0.018, 0.018, 4, Color(0.85, 0.86, 0.88), false)
		pk.tube(kit, "chrome", Vector3(float(sx), -L + 0.05, 0.2), Vector3(float(sx), -L - 0.38, 0.36), 0.015, 0.015, 4, Color(0.85, 0.86, 0.88), false)
	pk.tube(kit, "chrome", Vector3(-0.24, -L - 0.38, 0.36), Vector3(0.24, -L - 0.38, 0.36), 0.02, 0.02, 4, Color(0.85, 0.86, 0.88), true)
	pk.tube(kit, "metal", fr[0] + Vector3(0, 0.25, 0), fr[1] + Vector3(0, 0.25, 0), 0.012, 0.012, 3, chain, false)


# ======================================================================================
#  The bumper cars (Autoscooter)
# ======================================================================================

## The bumper cars, centred on the origin, the front (and the entrance steps) toward +z: a steel floor (x ±14, z ±10, its top
## 0.42m up) inside a rubber buffer, steel columns carrying a roof at 5m with the electrified ceiling mesh under it, a painted
## back wall, open sides with rails, a tall decorated front board with AUTOSCOOTER and the ride's name (Rhein-Blitz) in
## bulbs and lightning bolts (to 8.6m), the pay booth (x 11, z 12), ten cars standing about on the floor with their poles up
## to the mesh. About 9k triangles.
static func bumper_cars(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hx := 14.0
	var hz := 10.0
	var fl := 0.42
	var roof := 5.0
	var navy := Color(0.10, 0.14, 0.34)
	var yellow := Color(0.98, 0.80, 0.12)
	var red := Color(0.82, 0.12, 0.12)
	T._wblock(pk, kit, "metal", Vector3(-hx - 0.5, -0.3, -hz - 0.5), Vector3(hx + 0.5, fl, hz + 0.5), Color(0.40, 0.41, 0.43))
	T._wblock(pk, kit, "metal", Vector3(-hx, fl, -hz), Vector3(hx, fl + 0.01, hz), Color(0.55, 0.56, 0.58))
	# The buffer round the floor: black rubber with a yellow band.
	var bi: Array = [[Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz)], [Vector3(hx, 0, -hz), Vector3(hx, 0, hz)], [Vector3(hx, 0, hz), Vector3(-hx, 0, hz)],
			[Vector3(-hx, 0, hz), Vector3(-hx, 0, -hz)]]
	for e in bi:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		pk.beam(kit, "rubber", a + Vector3(0, fl + 0.2, 0), b + Vector3(0, fl + 0.2, 0), 0.3, 0.4, Color(0.06, 0.06, 0.06), Vector3.UP)
		pk.beam(kit, "paint", a + Vector3(0, fl + 0.3, 0), b + Vector3(0, fl + 0.3, 0), 0.32, 0.08, yellow, Vector3.UP)
	# The columns, the roof, its fascia, the ceiling mesh.
	for cx in [-hx, -hx * 0.5, 0.0, hx * 0.5, hx]:
		for cz in [-hz - 0.2, hz + 0.2]:
			pk.tube(kit, "steel", Vector3(float(cx), fl, float(cz)), Vector3(float(cx), roof, float(cz)), 0.13, 0.11, 8, WHEEL_WHITE, true)
	T._wblock(pk, kit, "metal", Vector3(-hx - 0.6, roof, -hz - 0.8), Vector3(hx + 0.6, roof + 0.35, hz + 0.8), Color(0.22, 0.22, 0.24), true, true)
	for side in [-1.0, 1.0]:
		YK.roof(pk, kit, "iron", Vector3(-hx - 0.6, roof + 0.35, side * (hz + 0.8)), Vector3(hx + 0.6, roof + 0.35, side * (hz + 0.8)), Vector3(hx + 0.6, roof + 1.3, 0.0),
				Vector3(-hx - 0.6, roof + 1.3, 0.0), Color(0.62, 0.62, 0.6), Vector3(0, hz + 0.8, side * 0.95).normalized(), false)
	for sx in [-hx - 0.6, hx + 0.6]:
		pk.tri(kit, "metal", Vector3(float(sx), roof + 0.35, -hz - 0.8), Vector3(float(sx), roof + 0.35, hz + 0.8), Vector3(float(sx), roof + 1.3, 0.0), Vector3(sign(float(sx)), 0, 0),
				Vector3(sign(float(sx)), 0, 0), Vector3(sign(float(sx)), 0, 0), Color(0.22, 0.22, 0.24), Vector3(sign(float(sx)), 0, 0))
	var my: float = roof - 0.25
	var gx := -hx
	while gx <= hx + 0.01:
		pk.beam(kit, "metal", Vector3(gx, my, -hz), Vector3(gx, my, hz), 0.02, 0.02, Color(0.35, 0.36, 0.37))
		gx += 0.7
	var gz := -hz
	while gz <= hz + 0.01:
		pk.beam(kit, "metal", Vector3(-hx, my, gz), Vector3(hx, my, gz), 0.02, 0.02, Color(0.35, 0.36, 0.37))
		gz += 0.7
	# The painted back wall and the side rails.
	var bwf := T._wf(Vector3(0, 0, -hz - 0.35), Vector3(0, 0, -1))
	T._prism(pk, kit, "paint", Transform3D(Basis(), Vector3.ZERO), T._rp(-hx, fl, hx, roof), -hz - 0.35, -hz - 0.25, navy, Vector2(0, 1), true)
	for k in range(8):
		var u0: float = -hx + float(k) * hx * 0.25
		T._rect(pk, kit, "paint", T._wf(Vector3(0, 0, -hz - 0.25), Vector3(0, 0, 1)), u0 + 0.2, fl + 0.6, u0 + hx * 0.25 - 0.2, roof - 0.6, 0.0, 0.02,
				[red, yellow, Color(0.15, 0.55, 0.85), Color(0.9, 0.35, 0.6)][k % 4])
		T._rect(pk, kit, "paint", bwf, u0 + 0.2, fl + 0.6, u0 + hx * 0.25 - 0.2, roof - 0.6, 0.0, 0.02, navy.lightened(0.15))
	for sx2 in [-hx - 0.25, hx + 0.25]:
		_railing(pk, kit, [Vector3(float(sx2), fl, -hz), Vector3(float(sx2), fl, hz)], 1.0, WHEEL_WHITE, 1.2)
	# The steps along the front, the front board.
	for k2 in range(2):
		T._wblock(pk, kit, "wood", Vector3(-hx + 1.0, -0.3, hz + 0.5 + 0.35 * float(k2)), Vector3(hx - 1.0, fl - 0.14 * float(k2 + 1) + 0.14, hz + 0.5 + 0.35 * float(k2 + 1)),
				Color(0.5, 0.36, 0.24))
	var fwf := T._wf(Vector3(-hx - 0.7, 0, hz + 0.86), Vector3(0, 0, 1))
	var W: float = hx * 2.0 + 1.4
	var ol := PackedVector2Array([Vector2(0.0, roof - 0.2), Vector2(W, roof - 0.2), Vector2(W, roof + 2.0)])
	var arc := T._arch(W * 0.5, roof + 2.0, W * 0.32, "segment", 16, 1.5)
	ol.append(Vector2(W * 0.5 + W * 0.32, roof + 2.0))
	for k3 in range(arc.size() - 1, -1, -1):
		ol.append(arc[k3])
	ol.append(Vector2(W * 0.5 - W * 0.32, roof + 2.0))
	ol.append(Vector2(0.0, roof + 2.0))
	var clean := PackedVector2Array()
	for q in ol:
		if clean.is_empty() or (clean[clean.size() - 1] as Vector2).distance_to(q) > 0.01:
			clean.append(q)
	T._prism(pk, kit, "paint", fwf, clean, -0.25, 0.0, navy, Vector2(0, 1), true)
	for k4 in range(clean.size()):
		var a2: Vector2 = clean[k4]
		var b2: Vector2 = clean[(k4 + 1) % clean.size()]
		if a2.y < roof - 0.1 and b2.y < roof - 0.1:
			continue
		var nb: int = maxi(int(a2.distance_to(b2) / 0.4), 1)
		for j in range(nb):
			var q2: Vector2 = a2.lerp(b2, float(j) / float(nb))
			T._blob(pk, kit, "bulb", fwf * Vector3(q2.x, q2.y, 0.05), Vector3.ONE * 0.1, BULB_COLS[(k4 + j) % BULB_COLS.size()])
	T._rect(pk, kit, "paint", fwf, 0.3, roof, W - 0.3, roof + 0.2, 0.0, 0.03, yellow)
	_label(labels, "AUTOSCOOTER", fwf * Vector3(W * 0.5, roof + 1.05, 0.06), Vector3(0, 0, 1), 1.0, yellow, W * 0.58)
	_label(labels, "Rhein-Blitz", fwf * Vector3(W * 0.5, roof + 2.55, 0.06), Vector3(0, 0, 1), 0.55, Color(1.0, 0.95, 0.9), W * 0.4)
	for bx in [2.2, W - 2.2]:
		var bolt := PackedVector2Array([Vector2(-0.3, 1.2), Vector2(0.45, 1.2), Vector2(0.05, 0.25), Vector2(0.5, 0.25), Vector2(-0.35, -1.2), Vector2(-0.05, -0.1),
				Vector2(-0.5, -0.1)])
		var bo := PackedVector2Array()
		for q3 in bolt:
			bo.append(Vector2(float(bx), roof + 1.0) + q3)
		T._prism(pk, kit, "paint", fwf, bo, 0.0, 0.06, yellow)
	# The cars.
	var crng := RandomNumberGenerator.new()
	crng.seed = 1914
	var spots: Array = [Vector3(-9, 0, -5), Vector3(-4, 0, -6.5), Vector3(3, 0, -4), Vector3(9, 0, -6), Vector3(-10, 0, 3), Vector3(-3, 0, 1),
			Vector3(4, 0, 4), Vector3(10, 0, 2), Vector3(-6, 0, 7), Vector3(7, 0, 7.5)]
	var ccols: Array = [red, yellow, Color(0.15, 0.55, 0.85), Color(0.9, 0.35, 0.6), Color(0.2, 0.7, 0.3), Color(0.95, 0.5, 0.1)]
	for i in range(spots.size()):
		_bumper_car(pk, kit, (spots[i] as Vector3) + Vector3(0, fl + 0.01, 0), crng.randf() * TAU, ccols[i % ccols.size()], my)
	_ticket_booth(pk, kit, labels, Vector3(hx - 3.0, 0, hz + 2.4), "Rhein-Blitz", red)


## A bumper car standing on `c` (the floor), turned `yaw`, its pole reaching up to the ceiling mesh at `mesh_y`: a rounded
## tub in its colour on a fat rubber bumper, a seat, a steering wheel, the pole with its contact.
static func _bumper_car(pk: PropKit, kit: Dictionary, c: Vector3, yaw: float, col: Color, mesh_y: float) -> void:
	var ol := PackedVector2Array()
	var n := 14
	for k in range(n):
		var a: float = TAU * float(k) / float(n)
		var x: float = cos(a) * 0.62
		var z: float = sin(a) * 0.98
		# Local (x across, z along) turned to the world, then to plan coordinates (x, -z).
		var wx: float = cos(yaw) * x + sin(yaw) * z
		var wz: float = -sin(yaw) * x + cos(yaw) * z
		ol.append(Vector2(wx, -wz))
	var ol_r := PackedVector2Array()
	for q in ol:
		ol_r.append(q * 1.12)
	T._plan_prism(pk, kit, "rubber", c, ol_r, c.y + 0.06, c.y + 0.34, Color(0.07, 0.07, 0.07))
	T._plan_prism(pk, kit, "gloss", c, ol, c.y + 0.34, c.y + 0.6, col)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	YK.box_at(pk, kit, "gloss", c + Vector3(0, 0.8, 0) - fwd * 0.55, Basis(side, Vector3.UP, fwd), Vector3(0.7, 0.45, 0.12), col.darkened(0.2))
	YK.box_at(pk, kit, "matte", c + Vector3(0, 0.66, 0) - fwd * 0.3, Basis(side, Vector3.UP, fwd), Vector3(0.6, 0.1, 0.42), Color(0.1, 0.1, 0.1))
	pk.tube(kit, "metal", c + Vector3(0, 0.6, 0) + fwd * 0.35, c + Vector3(0, 0.85, 0) + fwd * 0.25, 0.02, 0.02, 4, Color(0.5, 0.5, 0.5), false)
	pk.tyre(kit, "rubber", c + Vector3(0, 0.88, 0) + fwd * 0.24, 0.12, 0.16, 0.03, 10, Color(0.1, 0.1, 0.1), Basis(side, fwd.rotated(side, 0.0), Vector3.UP).orthonormalized()
			* Basis(Vector3.RIGHT, -0.4))
	var pb: Vector3 = c + Vector3(0, 0.6, 0) - fwd * 0.72
	pk.tube(kit, "metal", pb, Vector3(pb.x, mesh_y - 0.06, pb.z), 0.025, 0.02, 5, Color(0.45, 0.45, 0.46), false)
	pk.beam(kit, "metal", Vector3(pb.x, mesh_y - 0.06, pb.z) - side * 0.15, Vector3(pb.x, mesh_y - 0.06, pb.z) + side * 0.15, 0.04, 0.04, Color(0.7, 0.55, 0.2))
	pk.tri(kit, "pennant", pb + Vector3(0, 1.2, 0), pb + Vector3(0, 0.9, 0), pb + Vector3(0, 1.05, 0) - fwd * 0.4, side, side, side, col.lightened(0.2), side)


# ======================================================================================
#  The stalls
# ======================================================================================

## Each stall kind: [name on the roof sign, the words on its front board, body colour, trim colour].
const STALLS := {
	"bratwurst": ["Grillstube Kuhlmann", "Bratwurst · Currywurst · Pommes", Color(0.74, 0.12, 0.10), Color(0.98, 0.80, 0.14)],
	"mandeln": ["Mandel-Paradies Heuser", "Gebrannte Mandeln", Color(0.90, 0.42, 0.58), Color(0.98, 0.94, 0.90)],
	"lebkuchen": ["Lebkuchen Overbeck", "Lebkuchenherzen", Color(0.56, 0.20, 0.12), Color(0.98, 0.88, 0.62)],
	"lose": ["Glücksbude Fortuna", "Lose – jedes Los gewinnt!", Color(0.36, 0.18, 0.58), Color(0.98, 0.84, 0.18)],
	"schiess": ["Schießhalle Volltreffer", "Schießbude", Color(0.10, 0.34, 0.22), Color(0.94, 0.76, 0.26)],
	"crepes": ["Crêperie Tante Fine", "Crêpes & Waffeln", Color(0.38, 0.64, 0.86), Color(0.98, 0.97, 0.94)],
	"getraenke": ["Schankwagen Rheinterrasse", "Getränke · Bier vom Fass", Color(0.12, 0.28, 0.58), Color(0.98, 0.97, 0.94)],
}

## A fair stall (a trailer-stall), its counter front in the plane z = 0 facing +z, x -2.75..2.75, back to z = -2.5: the
## body on a skirt, the counter (out to z = 0.35) under an opening 1.05-2.6m, a printed front panel under the counter, the
## front board with its words, the front flap propped up as an awning (out to z = 1.65) with a scalloped valance and
## bunting, a roof sign (to 4.3m) with its name in a ring of bulbs, the goods of its `kind` ("bratwurst" with a swinging
## grill out at x 3.5, "mandeln", "lebkuchen", "lose", "schiess", "crepes", "getraenke" with kegs out at x 3.4). About
## 2.5-6k triangles.
static func stall(pk: PropKit, kit: Dictionary, labels: Array, kind: String) -> void:
	var spec: Array = STALLS.get(kind, STALLS["bratwurst"])
	var body: Color = spec[2]
	var trim: Color = spec[3]
	var hw := 2.75
	var D := 2.5
	var top := 3.2
	var o0 := 1.05
	var o1 := 2.6
	# The body: sides and back, the front below the counter and over the opening, skirt to the ground.
	T._wblock(pk, kit, "paint", Vector3(-hw, 0.0, -D), Vector3(-hw + 0.08, top, 0.0), body)
	T._wblock(pk, kit, "paint", Vector3(hw - 0.08, 0.0, -D), Vector3(hw, top, 0.0), body)
	T._wblock(pk, kit, "paint", Vector3(-hw + 0.08, 0.0, -D), Vector3(hw - 0.08, top, -D + 0.08), body)
	T._wblock(pk, kit, "paint", Vector3(-hw + 0.08, 0.0, -0.08), Vector3(hw - 0.08, o0, 0.0), body)
	T._wblock(pk, kit, "paint", Vector3(-hw + 0.08, o1, -0.08), Vector3(hw - 0.08, top, 0.0), body)
	# Inside: the walls' inner faces darker, the floor, the ceiling with a strip of bulbs.
	T._wblock(pk, kit, "matte", Vector3(-hw + 0.08, 0.95, -D + 0.08), Vector3(hw - 0.08, 0.98, -0.08), Color(0.3, 0.26, 0.22))
	pk.quad(kit, "paint", [Vector3(-hw + 0.08, top - 0.02, -D + 0.08), Vector3(hw - 0.08, top - 0.02, -D + 0.08), Vector3(hw - 0.08, top - 0.02, -0.08),
			Vector3(-hw + 0.08, top - 0.02, -0.08)], Vector3.DOWN, trim.darkened(0.4))
	pk.quad(kit, "paint", [Vector3(-hw + 0.09, o0, -D + 0.09), Vector3(-hw + 0.09, top - 0.02, -D + 0.09), Vector3(hw - 0.09, top - 0.02, -D + 0.09),
			Vector3(hw - 0.09, o0, -D + 0.09)], Vector3(0, 0, 1), body.darkened(0.35))
	for k in range(10):
		T._blob(pk, kit, "bulb", Vector3(-hw + 0.4 + float(k) * 0.52, top - 0.08, -0.4), Vector3.ONE * 0.06, BULB)
	# The front: a printed panel under the counter (diagonal stripes), the counter, the front board.
	var fwf := T._wf(Vector3(-hw, 0, 0), Vector3(0, 0, 1))
	# (The words go on the counter's front: over the opening the propped flap's valance hides them.)
	T._rect(pk, kit, "paint", fwf, 0.15, 0.12, hw * 2.0 - 0.15, o0 - 0.1, 0.0, 0.02, trim)
	for k2 in [0, 1, 7, 8]:
		var x0: float = 0.3 + float(k2) * 0.58
		T._prism(pk, kit, "paint", fwf, PackedVector2Array([Vector2(x0, 0.2), Vector2(x0 + 0.28, 0.2), Vector2(x0 + 0.48, o0 - 0.18), Vector2(x0 + 0.2, o0 - 0.18)]), 0.02, 0.035,
				body if k2 % 2 == 0 else body.lightened(0.25))
	T._rect(pk, kit, "paint", fwf, 1.5, 0.22, hw * 2.0 - 1.5, o0 - 0.2, 0.02, 0.04, body)
	_label(labels, String(spec[1]), Vector3(0, (0.22 + o0 - 0.2) * 0.5, 0.06), Vector3(0, 0, 1), 0.17, trim, hw * 2.0 - 3.2)
	T._wblock(pk, kit, "wood", Vector3(-hw + 0.05, o0 - 0.02, -0.15), Vector3(hw - 0.05, o0 + 0.05, 0.38), Color(0.62, 0.45, 0.28))
	T._rect(pk, kit, "paint", fwf, 0.1, o1 + 0.05, hw * 2.0 - 0.1, top - 0.05, 0.0, 0.03, trim)
	# The roof and the flap propped up over the front, its underside, a valance and the bunting along it.
	T._wblock(pk, kit, "paint", Vector3(-hw - 0.05, top, -D - 0.05), Vector3(hw + 0.05, top + 0.1, 0.05), trim, true, true)
	var fy0: float = top - 0.02
	var fz1 := 1.65
	var fy1: float = top - 0.28
	var nrm := Vector3(0, fz1, fy0 - fy1).normalized()
	var ns := 10
	for s in range(ns):
		var xa: float = lerpf(-hw, hw, float(s) / float(ns))
		var xb: float = lerpf(-hw, hw, float(s + 1) / float(ns))
		var sc: Color = body if s % 2 == 0 else trim
		pk.quad(kit, "paint", [Vector3(xa, fy0, 0.06), Vector3(xb, fy0, 0.06), Vector3(xb, fy1, fz1), Vector3(xa, fy1, fz1)], nrm, sc)
		pk.quad(kit, "paint", [Vector3(xa, fy0 - 0.04, 0.06), Vector3(xa, fy1 - 0.04, fz1), Vector3(xb, fy1 - 0.04, fz1), Vector3(xb, fy0 - 0.04, 0.06)], -nrm, sc.darkened(0.35))
		pk.panel(kit, "paint", [Vector3(xa, fy1, fz1 + 0.01), Vector3(xb, fy1, fz1 + 0.01), Vector3(xb, fy1 - 0.25, fz1 + 0.01), Vector3(xa, fy1 - 0.25, fz1 + 0.01)],
				Vector3(0, 0, 1), sc, sc.darkened(0.35))
		pk.tri(kit, "paint", Vector3(xa, fy1 - 0.25, fz1 + 0.01), Vector3(xb, fy1 - 0.25, fz1 + 0.01), Vector3((xa + xb) * 0.5, fy1 - 0.4, fz1 + 0.01), Vector3(0, 0, 1),
				Vector3(0, 0, 1), Vector3(0, 0, 1), sc, Vector3(0, 0, 1))
		pk.tri(kit, "paint", Vector3(xa, fy1 - 0.25, fz1), Vector3((xa + xb) * 0.5, fy1 - 0.4, fz1), Vector3(xb, fy1 - 0.25, fz1), Vector3(0, 0, -1), Vector3(0, 0, -1),
				Vector3(0, 0, -1), sc.darkened(0.35), Vector3(0, 0, -1))
		T._blob(pk, kit, "bulb", Vector3((xa + xb) * 0.5, fy1 - 0.05, fz1 + 0.05), Vector3.ONE * 0.06, BULB_COLS[s % BULB_COLS.size()])
	for sx in [-hw + 0.1, hw - 0.1]:
		pk.beam(kit, "steel", Vector3(float(sx), o1 - 0.3, 0.05), Vector3(float(sx), fy1 - 0.05, fz1 - 0.1), 0.04, 0.04, IRON)
	bunting(pk, kit, Vector3(-hw, fy1 - 0.42, fz1 + 0.02), Vector3(hw, fy1 - 0.42, fz1 + 0.02), 0.18)
	# The roof sign: a shaped board on the roof's front edge, its name, a ring of bulbs.
	var swf := T._wf(Vector3(0, 0, -0.1), Vector3(0, 0, 1))
	var sy0: float = top + 0.1
	var arc := T._arch(0.0, sy0 + 0.75, 2.3, "segment", 12, 0.35)
	var ol := PackedVector2Array([Vector2(-2.3, sy0), Vector2(2.3, sy0)])
	for k3 in range(arc.size() - 1, -1, -1):
		ol.append(arc[k3])
	T._prism(pk, kit, "paint", swf, ol, -0.08, 0.06, body.darkened(0.15), Vector2(0, 1), true)
	T._prism(pk, kit, "paint", swf, PackedVector2Array([Vector2(-2.1, sy0 + 0.12), Vector2(2.1, sy0 + 0.12), Vector2(2.1, sy0 + 0.82), Vector2(-2.1, sy0 + 0.82)]), 0.06, 0.08,
			trim.lightened(0.05))
	for k4 in range(ol.size()):
		var a: Vector2 = ol[k4]
		var b: Vector2 = ol[(k4 + 1) % ol.size()]
		var nb: int = maxi(int(a.distance_to(b) / 0.3), 1)
		for j in range(nb):
			var q: Vector2 = a.lerp(b, float(j) / float(nb))
			T._blob(pk, kit, "bulb", swf * Vector3(q.x, q.y, 0.08), Vector3.ONE * 0.06, BULB if (k4 + j) % 2 == 0 else BULB_COLS[1])
	# Each stall its own showman's name (ShopNames), the same on both faces of its sign.
	var sname: String = ShopNames.unique("stall_" + kind, String(spec[0]))
	_label(labels, sname, Vector3(0, sy0 + 0.47, -0.1 + 0.1), Vector3(0, 0, 1), 0.28, body.darkened(0.25), 4.0)
	_label(labels, sname, Vector3(0, sy0 + 0.47, -0.1 - 0.1), Vector3(0, 0, -1), 0.28, trim, 4.0)
	# A door at the back, its step.
	var bwf := T._wf(Vector3(hw, 0, -D), Vector3(0, 0, -1))
	T._rect(pk, kit, "paint", bwf, 0.6, 0.35, 1.5, 2.3, 0.0, 0.03, body.darkened(0.2))
	T._rect(pk, kit, "metal", bwf, 0.5, 0.0, 1.6, 0.35, 0.0, 0.4, Color(0.5, 0.5, 0.52))
	match kind:
		"bratwurst":
			_swing_grill(pk, kit, Vector3(hw + 1.0, 0, 0.9))
			for k5 in range(3):
				pk.lathe(kit, "plastic", Vector3(-1.8 + float(k5) * 0.2, o0 + 0.05, 0.2), [Vector2(0.001, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.16), Vector2(0.02, 0.22),
						Vector2(0.001, 0.24)], 6, [Color(0.85, 0.1, 0.08), Color(0.95, 0.75, 0.1), Color(0.9, 0.9, 0.85)][k5])
			T._wblock(pk, kit, "metal", Vector3(0.5, o0 + 0.05, -1.4), Vector3(2.2, o0 + 0.9, -0.6), Color(0.7, 0.7, 0.72))
		"mandeln":
			pk.lathe(kit, "copper", Vector3(0.0, o0 + 0.05, -0.3), [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.2, 0.25), Vector2(0.45, 0.32), Vector2(0.62, 0.6),
					Vector2(0.58, 0.6), Vector2(0.4, 0.38), Vector2(0.001, 0.36)], 14, Color(0.78, 0.42, 0.22))
			pk.beam(kit, "metal", Vector3(0.0, o0 + 0.4, -0.3), Vector3(0.0, o0 + 1.1, -0.3), 0.04, 0.04, IRON)
			pk.beam(kit, "metal", Vector3(0.0, o0 + 1.05, -0.3), Vector3(0.45, o0 + 0.55, -0.1), 0.03, 0.03, IRON)
			for k6 in range(12):
				var bx: float = -hw + 0.35 + float(k6) * 0.44
				if absf(bx) < 0.8:
					continue
				var bc := Vector3(bx, o1 - 0.42, 0.12)
				pk.tube(kit, "metal", Vector3(bx, o1 - 0.02, 0.12), bc + Vector3(0, 0.2, 0), 0.006, 0.006, 3, IRON, false)
				pk.lathe(kit, "paint", bc, [Vector2(0.001, 0.0), Vector2(0.09, 0.08), Vector2(0.11, 0.2), Vector2(0.001, 0.22)], 6,
						[Color(0.95, 0.9, 0.85), Color(0.9, 0.5, 0.65)][k6 % 2])
		"lebkuchen":
			_lebkuchen_hearts(pk, kit, labels, hw, o0, o1)
		"lose":
			_lose_prizes(pk, kit, hw, D, o0, o1)
		"schiess":
			_shooting_gallery(pk, kit, hw, D, o0, o1)
		"crepes":
			for px in [-0.8, 0.4]:
				T._wblock(pk, kit, "metal", Vector3(float(px) - 0.25, o0 + 0.05, -0.55), Vector3(float(px) + 0.25, o0 + 0.25, -0.05), Color(0.6, 0.6, 0.62))
				pk.tube(kit, "matte", Vector3(float(px), o0 + 0.25, -0.3), Vector3(float(px), o0 + 0.28, -0.3), 0.21, 0.21, 14, Color(0.08, 0.08, 0.08), true)
			for k7 in range(5):
				pk.lathe(kit, "gloss", Vector3(1.3 + float(k7) * 0.22, o0 + 0.05, -0.2), [Vector2(0.001, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.15), Vector2(0.05, 0.18),
						Vector2(0.001, 0.18)], 8, [Color(0.35, 0.2, 0.12), Color(0.85, 0.2, 0.3), Color(0.95, 0.85, 0.4)][k7 % 3])
			_menu_board(pk, kit, labels, Vector3(-hw - 0.7, 0, 1.2), "Crêpes ab 3,50 €", body)
		"getraenke":
			for k8 in range(4):
				var tx: float = -1.2 + float(k8) * 0.35
				pk.tube(kit, "chrome", Vector3(tx, o0 + 0.05, -0.15), Vector3(tx, o0 + 0.5, -0.15), 0.03, 0.03, 6, Color(0.85, 0.86, 0.88), true)
				pk.tube(kit, "chrome", Vector3(tx, o0 + 0.48, -0.15), Vector3(tx, o0 + 0.48, 0.0), 0.02, 0.015, 6, Color(0.85, 0.86, 0.88), true)
				pk.beam(kit, "plastic", Vector3(tx, o0 + 0.5, -0.15), Vector3(tx, o0 + 0.7, -0.15), 0.04, 0.025, Color(0.1, 0.1, 0.1))
			for kx in range(3):
				for ky in range(2):
					pk.lathe(kit, "metal", Vector3(hw + 0.45 + float(kx) * 0.62, float(ky) * 0.62, 0.6), [Vector2(0.001, 0.0), Vector2(0.27, 0.0), Vector2(0.29, 0.06),
							Vector2(0.29, 0.56), Vector2(0.27, 0.6), Vector2(0.001, 0.6)], 10, Color(0.68, 0.7, 0.72))
			pk.quad(kit, "wglass", [Vector3(0.6, o0 + 0.1, -D + 0.6), Vector3(2.2, o0 + 0.1, -D + 0.6), Vector3(2.2, o1 - 0.1, -D + 0.6), Vector3(0.6, o1 - 0.1, -D + 0.6)],
					Vector3(0, 0, 1), Color(0.75, 0.9, 0.95, 0.45))
			for k9 in range(3):
				for k10 in range(8):
					pk.lathe(kit, "gloss", Vector3(0.75 + float(k10) * 0.19, o0 + 0.2 + float(k9) * 0.45, -D + 0.35), [Vector2(0.001, 0.0), Vector2(0.04, 0.0), Vector2(0.04, 0.2),
							Vector2(0.015, 0.3), Vector2(0.001, 0.3)], 5, [Color(0.3, 0.5, 0.2), Color(0.55, 0.32, 0.12), Color(0.9, 0.6, 0.1)][k9])


## The swinging grill (Schwenkgrill) standing on `c`: a tripod with a hook and chains, a round grate of sausages swinging
## over a glowing fire bowl.
static func _swing_grill(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	var apex: Vector3 = c + Vector3(0, 2.3, 0)
	for k in range(3):
		var a: float = TAU * float(k) / 3.0 + 0.3
		pk.tube(kit, "metal", c + Vector3(cos(a) * 0.95, 0, sin(a) * 0.95), apex, 0.03, 0.03, 5, IRON, false)
	var gy: float = c.y + 0.85
	for k2 in range(3):
		var a2: float = TAU * float(k2) / 3.0
		pk.tube(kit, "metal", apex - Vector3(0, 0.1, 0), c + Vector3(cos(a2) * 0.5, 0.85, sin(a2) * 0.5), 0.006, 0.006, 3, Color(0.4, 0.4, 0.4), false)
	pk.tyre(kit, "metal", Vector3(c.x, gy, c.z), 0.52, 0.56, 0.03, 16, IRON)
	for k3 in range(7):
		var bx: float = -0.45 + float(k3) * 0.15
		var half: float = sqrt(maxf(0.3 - bx * bx, 0.01))
		pk.beam(kit, "metal", Vector3(c.x + bx, gy, c.z - half), Vector3(c.x + bx, gy, c.z + half), 0.012, 0.012, IRON)
	for k4 in range(9):
		var sx: float = -0.36 + float(k4) * 0.09
		pk.tube(kit, "paint", Vector3(c.x + sx, gy + 0.03, c.z - 0.18), Vector3(c.x + sx, gy + 0.03, c.z + 0.18), 0.022, 0.022, 5, Color(0.55, 0.30, 0.15), true)
	pk.lathe(kit, "matte", c, [Vector2(0.001, 0.32), Vector2(0.25, 0.0), Vector2(0.55, 0.32), Vector2(0.5, 0.36), Vector2(0.001, 0.34)], 12, Color(0.12, 0.12, 0.12))
	pk.lathe(kit, "bulb", c + Vector3(0, 0.345, 0), [Vector2(0.001, 0.0), Vector2(0.44, 0.0), Vector2(0.001, 0.03)], 10, Color(0.9, 0.35, 0.08))


## Lebkuchenherzen hanging in three rows across a stall's opening: iced gingerbread hearts on ribbons, a few big ones
## with their words.
static func _lebkuchen_hearts(pk: PropKit, kit: Dictionary, labels: Array, hw: float, o0: float, o1: float) -> void:
	var icing: Array = [Color(0.95, 0.55, 0.7), Color(0.98, 0.97, 0.94), Color(0.55, 0.85, 0.55), Color(0.98, 0.85, 0.3), Color(0.5, 0.75, 0.95)]
	var words: Array = ["Ich mag dich", "Für dich", "Mein Schatz"]
	# Three rails, the big hearts on the front one, smaller ones behind: all above the counter.
	var rows: Array = [[o1 - 0.1, 7, 0.26, 0.17], [o1 - 0.55, 9, 0.2, -0.05], [o1 - 1.0, 10, 0.17, -0.27]]
	for r in range(rows.size()):
		var y: float = rows[r][0]
		var n: int = rows[r][1]
		var s: float = rows[r][2]
		var hz: float = rows[r][3]
		pk.tube(kit, "metal", Vector3(-hw + 0.1, y, hz - 0.01), Vector3(hw - 0.1, y, hz - 0.01), 0.012, 0.012, 4, Color(0.6, 0.6, 0.6), false)
		for k in range(n):
			var x: float = lerpf(-hw + 0.4, hw - 0.4, (float(k) + 0.5) / float(n))
			var big: bool = r == 0 and k % 3 == 1
			var sz: float = s * (1.35 if big else 1.0)
			var c := Vector3(x, y - 0.12 - sz * 0.5, hz)
			pk.beam(kit, "paint", Vector3(x, y, hz - 0.01), c + Vector3(0, sz * 0.3, 0), 0.02, 0.005, icing[(k + r) % icing.size()])
			var hf := Transform3D(Basis(), c)
			T._prism(pk, kit, "paint", hf, _heart(sz * 1.1), -0.012, 0.012, Color(0.98, 0.97, 0.94))
			T._prism(pk, kit, "paint", hf, _heart(sz), -0.02, 0.02, Color(0.50, 0.28, 0.14), Vector2(0, 1), true)
			T._prism(pk, kit, "paint", hf, _heart(sz * 0.55), 0.02, 0.026, icing[(k + r + 1) % icing.size()])
			if big:
				_label(labels, words[(k / 3) % words.size()], c + Vector3(0, -sz * 0.05, 0.03), Vector3(0, 0, 1), sz * 0.16, Color(0.98, 0.97, 0.94), sz * 1.2)


## A heart's outline `s` across, its middle at the origin.
static func _heart(s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(14):
		var t: float = TAU * float(k) / 14.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		out.append(Vector2(x, y) * s / 34.0)
	return out


## A lottery booth's prizes: plush bears in pastel colours on three tiers at the back and hanging along the top, a
## lottery drum on the counter.
static func _lose_prizes(pk: PropKit, kit: Dictionary, hw: float, D: float, o0: float, o1: float) -> void:
	var cols: Array = [Color(0.95, 0.75, 0.82), Color(0.72, 0.85, 0.98), Color(0.98, 0.92, 0.6), Color(0.75, 0.6, 0.45), Color(0.8, 0.95, 0.8)]
	for t in range(3):
		var y: float = o0 + 0.05 + float(t) * 0.5
		var z: float = -D + 0.3 + float(t) * 0.35
		T._wblock(pk, kit, "wood", Vector3(-hw + 0.1, y - 0.04, z - 0.2), Vector3(hw - 0.1, y, z + 0.2), Color(0.5, 0.35, 0.22))
		for k in range(7):
			var x: float = -hw + 0.55 + float(k) * 0.72
			_teddy(pk, kit, Vector3(x, y, z), 0.32 + 0.06 * float((k + t) % 3), cols[(k + t * 2) % cols.size()])
	for k2 in range(6):
		var x2: float = -hw + 0.6 + float(k2) * 0.9
		_teddy(pk, kit, Vector3(x2, o1 - 0.55, -0.3), 0.36, cols[(k2 + 3) % cols.size()])
		pk.tube(kit, "metal", Vector3(x2, o1 - 0.05, -0.3), Vector3(x2, o1 - 0.2, -0.3), 0.006, 0.006, 3, Color(0.6, 0.6, 0.6), false)
	var dc := Vector3(-1.4, o0 + 0.35, 0.05)
	pk.lathe(kit, "wglass", dc, [Vector2(0.001, -0.28), Vector2(0.3, -0.28), Vector2(0.3, 0.28), Vector2(0.001, 0.28)], 6, Color(0.8, 0.9, 1.0, 0.35), true, Basis(Vector3(0, 0, 1), PI * 0.5))
	for k3 in range(6):
		var a: float = TAU * float(k3) / 6.0
		pk.beam(kit, "gold", dc + Vector3(-0.29, cos(a) * 0.3, sin(a) * 0.3), dc + Vector3(0.29, cos(a) * 0.3, sin(a) * 0.3), 0.025, 0.025, GOLD)
	for sx in [-0.34, 0.34]:
		pk.beam(kit, "metal", dc + Vector3(float(sx), 0, 0), Vector3(dc.x + float(sx), o0 + 0.05, dc.z), 0.04, 0.04, IRON)
	for k4 in range(14):
		T._blob(pk, kit, "paint", dc + Vector3(sin(float(k4) * 2.3) * 0.18, -0.2 + float(k4 % 3) * 0.04, cos(float(k4) * 1.7) * 0.18), Vector3(0.04, 0.02, 0.03),
				[Color(0.9, 0.2, 0.2), Color(0.2, 0.5, 0.9), Color(0.95, 0.85, 0.2)][k4 % 3])


## A plush bear sitting on c, `s` tall.
static func _teddy(pk: PropKit, kit: Dictionary, c: Vector3, s: float, col: Color) -> void:
	pk.lathe(kit, "matte", c, [Vector2(0.001, 0.0), Vector2(0.22 * s, 0.02 * s), Vector2(0.27 * s, 0.25 * s), Vector2(0.2 * s, 0.5 * s), Vector2(0.001, 0.56 * s)], 6, col)
	pk.lathe(kit, "matte", c + Vector3(0, 0.5 * s, 0), [Vector2(0.001, 0.0), Vector2(0.18 * s, 0.1 * s), Vector2(0.17 * s, 0.3 * s), Vector2(0.001, 0.4 * s)], 6, col)
	for sx in [-1.0, 1.0]:
		T._blob(pk, kit, "matte", c + Vector3(sx * 0.15 * s, 0.86 * s, 0), Vector3(0.07, 0.07, 0.04) * s, col.darkened(0.1))
		T._blob(pk, kit, "matte", c + Vector3(sx * 0.28 * s, 0.3 * s, 0.05 * s), Vector3(0.08, 0.16, 0.08) * s, col)
		T._blob(pk, kit, "matte", c + Vector3(sx * 0.13 * s, 0.05 * s, 0.2 * s), Vector3(0.08, 0.07, 0.14) * s, col)
	T._blob(pk, kit, "matte", c + Vector3(0, 0.66 * s, 0.17 * s), Vector3(0.07, 0.05, 0.05) * s, col.lightened(0.3))
	T._blob(pk, kit, "matte", c + Vector3(0, 0.68 * s, 0.22 * s), Vector3(0.025, 0.02, 0.02) * s, Color(0.1, 0.07, 0.05))


## A shooting gallery's back: a dark back wall with rows of targets, tubes with paper flowers, prizes on the side walls,
## three rifles on the counter.
static func _shooting_gallery(pk: PropKit, kit: Dictionary, hw: float, D: float, o0: float, o1: float) -> void:
	var bz: float = -D + 0.1
	pk.quad(kit, "paint", [Vector3(-hw + 0.1, o0, bz), Vector3(hw - 0.1, o0, bz), Vector3(hw - 0.1, o1 + 0.4, bz), Vector3(-hw + 0.1, o1 + 0.4, bz)], Vector3(0, 0, 1),
			Color(0.08, 0.12, 0.1))
	for k in range(6):
		var tx: float = -hw + 0.6 + float(k) * 0.85
		var tw := T._wf(Vector3(0, 0, bz + 0.01), Vector3(0, 0, 1))
		T._circle_ring(pk, kit, "paint", tw, Vector2(tx, o1 - 0.25), 0.0, 0.18, 0.0, 0.02, Color(0.95, 0.95, 0.92), 14)
		T._circle_ring(pk, kit, "paint", tw, Vector2(tx, o1 - 0.25), 0.06, 0.12, 0.02, 0.025, Color(0.85, 0.1, 0.1), 14)
		T._circle_ring(pk, kit, "paint", tw, Vector2(tx, o1 - 0.25), 0.0, 0.035, 0.02, 0.025, Color(0.85, 0.1, 0.1), 10)
	for k2 in range(12):
		var fx: float = -hw + 0.4 + float(k2) * 0.42
		var fy: float = o0 + 0.45
		pk.tube(kit, "paint", Vector3(fx, fy - 0.2, bz + 0.3), Vector3(fx, fy + 0.25, bz + 0.3), 0.012, 0.012, 4, Color(0.95, 0.95, 0.92), false)
		T._blob(pk, kit, "paint", Vector3(fx, fy + 0.3, bz + 0.3), Vector3(0.07, 0.07, 0.04), [Color(0.95, 0.2, 0.3), Color(0.98, 0.85, 0.2), Color(0.3, 0.5, 0.95),
				Color(0.98, 0.6, 0.85)][k2 % 4])
	T._wblock(pk, kit, "wood", Vector3(-hw + 0.1, o0 + 0.05, bz + 0.15), Vector3(hw - 0.1, o0 + 0.2, bz + 0.45), Color(0.45, 0.3, 0.2))
	for side in [-1.0, 1.0]:
		for k3 in range(3):
			_teddy(pk, kit, Vector3(side * (hw - 0.35), o0 + 0.3 + float(k3) * 0.5, -1.0 - float(k3) * 0.3), 0.3, [Color(0.95, 0.75, 0.82), Color(0.72, 0.85, 0.98),
					Color(0.98, 0.92, 0.6)][k3])
	for k4 in range(3):
		var rx: float = -1.2 + float(k4) * 1.2
		var a := Vector3(rx - 0.1, o0 + 0.1, 0.25)
		var b := Vector3(rx + 0.1, o0 + 0.1, -0.6)
		pk.beam(kit, "wood", a, a.lerp(b, 0.4), 0.06, 0.1, Color(0.42, 0.26, 0.14))
		pk.tube(kit, "metal", a.lerp(b, 0.4), b, 0.015, 0.015, 5, Color(0.2, 0.2, 0.22), true)


# ======================================================================================
#  The beer tent, bunting, the fence
# ======================================================================================

## The beer tent (Festzelt "Zur Rheinwiese"), its front gable in the plane z = 0 facing +z, x -11..11, back to z = -40: an
## aluminium frame every 5m (eaves 3.6m, ridge 8.4m), green and white striped canvas on the roof (its underside darker) and
## the gables, white side walls with arched windows, the front half of the +x side rolled up; the entrance (x ±2.5, 3.2m
## high) in a painted timber portal with the name and a crest, garlands and bunting; inside a plank floor, three rows of
## beer tables with benches, a band stand at the back, lamps. About 9k triangles.
static func beer_tent(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hw := 11.0
	var L := 40.0
	var eave := 3.6
	var ridge := 8.4
	var green := Color(0.14, 0.46, 0.26)
	var white := Color(0.96, 0.96, 0.93)
	var alu := Color(0.75, 0.76, 0.78)
	# The frame.
	var nb := 8
	for k in range(nb + 1):
		var z: float = -L * float(k) / float(nb)
		for sx in [-1.0, 1.0]:
			pk.beam(kit, "metal", Vector3(sx * hw, 0.0, z), Vector3(sx * hw, eave, z), 0.12, 0.22, alu)
			pk.beam(kit, "metal", Vector3(sx * hw, eave, z), Vector3(0, ridge, z), 0.12, 0.25, alu)
		pk.beam(kit, "metal", Vector3(-hw, eave - 0.05, z), Vector3(hw, eave - 0.05, z), 0.08, 0.12, alu)
	for zz in [[-hw, eave], [hw, eave], [0.0, ridge]]:
		pk.beam(kit, "metal", Vector3(float(zz[0]), float(zz[1]) - 0.15, 0), Vector3(float(zz[0]), float(zz[1]) - 0.15, -L), 0.08, 0.08, alu)
	# The roof: stripes a metre wide down both slopes, the undersides, a valance along the eaves.
	var ns: int = int(L / 1.0)
	for side in [-1.0, 1.0]:
		var nrm: Vector3 = Vector3(side * (ridge - eave), hw, 0).normalized()
		for k2 in range(ns):
			var z0: float = -L * float(k2) / float(ns)
			var z1: float = -L * float(k2 + 1) / float(ns)
			var c: Color = green if k2 % 2 == 0 else white
			var e0 := Vector3(side * (hw + 0.25), eave - 0.1, z0 + 0.1)
			var e1 := Vector3(side * (hw + 0.25), eave - 0.1, z1)
			var r0 := Vector3(0, ridge + 0.05, z0 + 0.1)
			var r1 := Vector3(0, ridge + 0.05, z1)
			if k2 > 0:
				e0.z = z0
				r0.z = z0
			if k2 == ns - 1:
				e1.z = z1 - 0.1
				r1.z = z1 - 0.1
			pk.quad(kit, "canvas", [e0, e1, r1, r0], nrm, c)
			pk.quad(kit, "canvas", [e0 - Vector3(0, 0.03, 0), r0 - Vector3(0, 0.03, 0), r1 - Vector3(0, 0.03, 0), e1 - Vector3(0, 0.03, 0)], -nrm, c.darkened(0.45))
			var vo := Vector3(side, 0, 0)
			pk.panel(kit, "canvas", [e0 + vo * 0.01, e1 + vo * 0.01, e1 + vo * 0.01 + Vector3(0, -0.35, 0), e0 + vo * 0.01 + Vector3(0, -0.35, 0)], vo, c, c.darkened(0.35))
			pk.tri(kit, "canvas", e0 + vo * 0.01 + Vector3(0, -0.35, 0), e1 + vo * 0.01 + Vector3(0, -0.35, 0), (e0 + e1) * 0.5 + vo * 0.01 + Vector3(0, -0.5, 0), vo, vo, vo, c, vo)
	pk.tube(kit, "canvas", Vector3(0, ridge + 0.08, 0.1), Vector3(0, ridge + 0.08, -L - 0.1), 0.12, 0.12, 6, white, true)
	# The side walls: white canvas with arched windows, back faces darker; the front half of the +x side rolled up.
	for side2 in [-1.0, 1.0]:
		var wx: float = side2 * (hw + 0.09)
		var o := Vector3(side2, 0, 0)
		for k3 in range(nb):
			var z0b: float = -L * float(k3) / float(nb)
			var z1b: float = -L * float(k3 + 1) / float(nb)
			if side2 > 0.0 and k3 < 3:
				pk.tube(kit, "canvas", Vector3(wx, eave - 0.3, z0b - 0.1), Vector3(wx, eave - 0.3, z1b + 0.1), 0.17, 0.17, 8, white, true)
				continue
			pk.quad(kit, "canvas", [Vector3(wx, 0, z0b), Vector3(wx, 0, z1b), Vector3(wx, eave - 0.1, z1b), Vector3(wx, eave - 0.1, z0b)], o, white)
			pk.quad(kit, "canvas", [Vector3(wx - side2 * 0.02, 0, z0b), Vector3(wx - side2 * 0.02, eave - 0.1, z0b), Vector3(wx - side2 * 0.02, eave - 0.1, z1b),
					Vector3(wx - side2 * 0.02, 0, z1b)], -o, white.darkened(0.3))
			for wz in [0.3, 0.7]:
				var cz: float = lerpf(z0b, z1b, float(wz))
				var wf := T._wf(Vector3(wx + side2 * 0.01, 0, cz), o)
				T._pface(pk, kit, "canvas", wf, T._opening(0.0, 1.0, 0.55, 2.3, "round", 8), 0.0, Color(0.78, 0.84, 0.86))
	# The gables: the front with the entrance, the back closed; vertical stripes over the eaves.
	for gz in [0.13, -L - 0.13]:
		var front: bool = gz > 0.0
		var o3 := Vector3(0, 0, 1.0 if front else -1.0)
		var nst := 11
		for k4 in range(nst * 2):
			var x0: float = lerpf(-hw, hw, float(k4) / float(nst * 2))
			var x1: float = lerpf(-hw, hw, float(k4 + 1) / float(nst * 2))
			var c2: Color = green if k4 % 2 == 0 else white
			var y0a: float = eave + (ridge - eave) * (1.0 - absf(x0) / hw)
			var y1a: float = eave + (ridge - eave) * (1.0 - absf(x1) / hw)
			var pts: Array = [Vector3(x0, eave, gz), Vector3(x1, eave, gz), Vector3(x1, y1a, gz), Vector3(x0, y0a, gz)]
			pk.quad(kit, "canvas", pts, o3, c2)
			pk.quad(kit, "canvas", [pts[0] - o3 * 0.02, pts[3] - o3 * 0.02, pts[2] - o3 * 0.02, pts[1] - o3 * 0.02], -o3, c2.darkened(0.45))
			# Below the eaves: white walls, with the entrance left open at the front.
			if front and absf((x0 + x1) * 0.5) < 2.5:
				pk.quad(kit, "canvas", [Vector3(x0, 3.2, gz), Vector3(x1, 3.2, gz), Vector3(x1, eave, gz), Vector3(x0, eave, gz)], o3, white)
				continue
			pk.quad(kit, "canvas", [Vector3(x0, 0, gz), Vector3(x1, 0, gz), Vector3(x1, eave, gz), Vector3(x0, eave, gz)], o3, white)
			pk.quad(kit, "canvas", [Vector3(x0, 0, gz - o3.z * 0.02), Vector3(x0, eave, gz - o3.z * 0.02), Vector3(x1, eave, gz - o3.z * 0.02), Vector3(x1, 0, gz - o3.z * 0.02)],
					-o3, white.darkened(0.3))
	# The portal: two painted posts, a board with the name, a crest board, garlands and bunting.
	var red := Color(0.62, 0.12, 0.10)
	for sx3 in [-2.7, 2.7]:
		T._wblock(pk, kit, "painted", Vector3(float(sx3) - 0.2, 0.0, 0.16), Vector3(float(sx3) + 0.2, 4.4, 0.56), red)
	T._wblock(pk, kit, "painted", Vector3(-3.1, 3.3, 0.18), Vector3(3.1, 4.3, 0.48), Color(0.98, 0.95, 0.86))
	_label(labels, "Festzelt Zur Rheinwiese", Vector3(0, 3.8, 0.51), Vector3(0, 0, 1), 0.28, green.darkened(0.2), 5.8)
	var cwf := T._wf(Vector3(0, 0, 0.36), Vector3(0, 0, 1))
	var crest := T._arch(0.0, 4.3, 2.4, "segment", 12, 1.0)
	T._prism(pk, kit, "painted", cwf, crest, -0.15, 0.12, green, Vector2(0, 1), true)
	_crown(pk, kit, Vector3(0, 5.25, 0.36), 0.9)
	var garland: Array = _sag_pts(Vector3(-2.7, 3.2, 0.55), Vector3(2.7, 3.2, 0.55), 0.45, 10)
	for k5 in range(garland.size() - 1):
		pk.tube(kit, "leaf", garland[k5], garland[k5 + 1], 0.09, 0.09, 6, Color(0.18, 0.40, 0.16), false)
		T._blob(pk, kit, "paint", garland[k5], Vector3.ONE * 0.06, [Color(0.9, 0.2, 0.2), Color(0.98, 0.9, 0.3), Color(0.98, 0.98, 0.95)][k5 % 3])
	bunting(pk, kit, Vector3(-hw - 0.3, eave - 0.3, 0.2), Vector3(-3.0, 4.4, 0.6), 0.3)
	bunting(pk, kit, Vector3(3.0, 4.4, 0.6), Vector3(hw + 0.3, eave - 0.3, 0.2), 0.3)
	# Inside: the floor, the tables and benches, the band stand, the lamps.
	T._wblock(pk, kit, "timber", Vector3(-hw + 0.1, 0.0, -L + 0.1), Vector3(hw - 0.1, 0.08, -0.1), Color(0.58, 0.44, 0.28))
	for rx in [-6.5, 0.0, 6.5]:
		var tz := -3.0
		while tz > -L + 7.0:
			_beer_table(pk, kit, Vector3(float(rx), 0.08, tz))
			tz -= 4.0
	var sz0: float = -L + 4.5
	T._wblock(pk, kit, "timber", Vector3(-6.0, 0.08, -L + 0.2), Vector3(6.0, 1.0, sz0), Color(0.5, 0.36, 0.22))
	for k6 in range(12):
		var bx: float = -6.0 + float(k6)
		pk.quad(kit, "canvas", [Vector3(bx, 1.0, -L + 0.25), Vector3(bx + 1.0, 1.0, -L + 0.25), Vector3(bx + 1.0, eave + 1.5, -L + 0.25), Vector3(bx, eave + 1.5, -L + 0.25)],
				Vector3(0, 0, 1), [Color(0.12, 0.2, 0.5), Color(0.96, 0.96, 0.92)][k6 % 2])
	T._wblock(pk, kit, "painted", Vector3(-3.0, eave + 0.6, -L + 0.3), Vector3(3.0, eave + 1.3, -L + 0.4), Color(0.98, 0.95, 0.86))
	_label(labels, "Kapelle Rheinklang", Vector3(0, eave + 0.95, -L + 0.43), Vector3(0, 0, 1), 0.3, red, 5.6)
	for k7 in range(4):
		pk.lathe(kit, "metal", Vector3(-3.0 + float(k7) * 2.0, 1.0, sz0 - 1.5), [Vector2(0.001, 0.0), Vector2(0.22, 0.0), Vector2(0.22, 0.45), Vector2(0.001, 0.45)], 8,
				Color(0.2, 0.2, 0.22), true)
	for lz in [-5.0, -15.0, -25.0, -35.0]:
		for lx in [-5.5, 5.5]:
			pk.tube(kit, "metal", Vector3(float(lx), ridge - (ridge - eave) * absf(float(lx)) / hw - 0.2, float(lz)), Vector3(float(lx), eave + 0.2, float(lz)), 0.01, 0.01, 3,
					IRON, false)
			pk.lathe(kit, "bulb", Vector3(float(lx), eave - 0.15, float(lz)), [Vector2(0.001, 0.0), Vector2(0.3, 0.05), Vector2(0.3, 0.2), Vector2(0.15, 0.35), Vector2(0.001, 0.36)],
					10, Color(1.0, 0.88, 0.62))
	# Garlands along the frames inside.
	for k8 in range(1, nb):
		var gz2: float = -L * float(k8) / float(nb)
		var gp: Array = _sag_pts(Vector3(-hw + 0.3, eave - 0.2, gz2), Vector3(hw - 0.3, eave - 0.2, gz2), 0.8, 12)
		for k9 in range(gp.size() - 1):
			pk.tube(kit, "leaf", gp[k9], gp[k9 + 1], 0.07, 0.07, 5, Color(0.18, 0.40, 0.16), false)


## A beer table set (Bierzeltgarnitur) at c on the floor, along z: a table 2.2 x 0.5m on folding legs, a bench either side.
static func _beer_table(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	var wood := Color(0.66, 0.50, 0.32)
	T._wblock(pk, kit, "timber", c + Vector3(-0.25, 0.73, -1.1), c + Vector3(0.25, 0.76, 1.1), wood)
	for sz in [-0.8, 0.8]:
		for sx in [-0.2, 0.2]:
			pk.beam(kit, "metal", c + Vector3(float(sx), 0.0, float(sz) - 0.12), c + Vector3(float(sx) * 0.3, 0.73, float(sz)), 0.03, 0.03, Color(0.3, 0.3, 0.32))
	for bx in [-0.6, 0.6]:
		T._wblock(pk, kit, "timber", c + Vector3(float(bx) - 0.13, 0.45, -1.1), c + Vector3(float(bx) + 0.13, 0.48, 1.1), wood)
		for sz2 in [-0.85, 0.85]:
			pk.beam(kit, "metal", c + Vector3(float(bx), 0.0, float(sz2)), c + Vector3(float(bx), 0.45, float(sz2)), 0.12, 0.03, Color(0.3, 0.3, 0.32), Vector3(1, 0, 0))


## Bunting from a to b (kit coordinates) sagging `sag` in the middle: a cord with pennants every 45cm, red, yellow, blue,
## green, white and orange in turn (two-sided cloth).
static func bunting(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, sag: float) -> void:
	var l: float = a.distance_to(b)
	var segs: int = maxi(int(l / 0.6), 2)
	var pts: Array = _sag_pts(a, b, sag, segs)
	for k in range(pts.size() - 1):
		pk.tube(kit, "matte", pts[k], pts[k + 1], 0.008, 0.008, 3, Color(0.9, 0.9, 0.88), false)
	var cols: Array = [Color(0.88, 0.12, 0.12), Color(0.98, 0.82, 0.12), Color(0.15, 0.40, 0.80), Color(0.15, 0.60, 0.25), Color(0.97, 0.97, 0.95), Color(0.98, 0.52, 0.10)]
	var n: int = maxi(int(l / 0.45), 1)
	var along: Vector3 = (b - a).normalized()
	var side: Vector3 = along.cross(Vector3.UP).normalized()
	for k2 in range(n):
		var t0: float = (float(k2) + 0.1) / float(n)
		var t1: float = (float(k2) + 0.75) / float(n)
		var p0: Vector3 = a.lerp(b, t0) - Vector3(0, sag * 4.0 * t0 * (1.0 - t0), 0)
		var p1: Vector3 = a.lerp(b, t1) - Vector3(0, sag * 4.0 * t1 * (1.0 - t1), 0)
		var tip: Vector3 = (p0 + p1) * 0.5 - Vector3(0, 0.38, 0) + side * 0.01
		pk.tri(kit, "pennant", p0, p1, tip, side, side, side, cols[k2 % cols.size()], side)


## A fair's fence along +x from the origin, `length` long: building-site fence panels (3.45m, 2m high) in concrete feet,
## each covered by a printed banner (stripes in the fair's colours; with `labels`, RHEINKIRMES KRONBURG on every third),
## clamps at the joints. About 90 triangles a panel.
static func kirmes_fence(pk: PropKit, kit: Dictionary, length: float, labels := []) -> void:
	var n: int = maxi(int(ceil(length / 3.45)), 1)
	var pl: float = length / float(n)
	var galv := Color(0.70, 0.72, 0.73)
	var cols: Array = [[Color(0.10, 0.18, 0.45), Color(0.98, 0.80, 0.12)], [Color(0.80, 0.12, 0.12), Color(0.98, 0.97, 0.94)]]
	for k in range(n):
		var x0: float = float(k) * pl
		var x1: float = x0 + pl
		for x in [x0 + 0.05, x1 - 0.05]:
			pk.tube(kit, "metal", Vector3(float(x), 0.12, 0), Vector3(float(x), 2.0, 0), 0.02, 0.02, 5, galv, true)
		pk.tube(kit, "metal", Vector3(x0 + 0.05, 1.98, 0), Vector3(x1 - 0.05, 1.98, 0), 0.02, 0.02, 5, galv, false)
		pk.tube(kit, "metal", Vector3(x0 + 0.05, 0.14, 0), Vector3(x1 - 0.05, 0.14, 0), 0.02, 0.02, 5, galv, false)
		var cc: Array = cols[k % 2]
		pk.panel(kit, "paint", [Vector3(x0 + 0.1, 0.2, 0.0), Vector3(x1 - 0.1, 0.2, 0.0), Vector3(x1 - 0.1, 1.9, 0.0), Vector3(x0 + 0.1, 1.9, 0.0)], Vector3(0, 0, 1), cc[0],
				(cc[0] as Color).darkened(0.2))
		for by in [0.55, 1.35]:
			pk.quad(kit, "paint", [Vector3(x0 + 0.1, float(by), 0.012), Vector3(x1 - 0.1, float(by), 0.012), Vector3(x1 - 0.1, float(by) + 0.2, 0.012),
					Vector3(x0 + 0.1, float(by) + 0.2, 0.012)], Vector3(0, 0, 1), cc[1])
		if k % 3 == 1:
			_label(labels, "RHEINKIRMES KRONBURG", Vector3((x0 + x1) * 0.5, 1.05, 0.03), Vector3(0, 0, 1), 0.26, Color(0.98, 0.97, 0.94), pl - 0.4)
		# The concrete foot under the joint and the clamp.
		T._wblock(pk, kit, "concrete", Vector3(x0 - 0.35, 0.0, -0.11), Vector3(x0 + 0.35, 0.14, 0.11), Color(0.62, 0.61, 0.58))
		pk.tube(kit, "metal", Vector3(x0, 1.6, -0.04), Vector3(x0, 1.6, 0.04), 0.045, 0.045, 6, galv, true)
	T._wblock(pk, kit, "concrete", Vector3(length - 0.35, 0.0, -0.11), Vector3(length + 0.35, 0.14, 0.11), Color(0.62, 0.61, 0.58))
