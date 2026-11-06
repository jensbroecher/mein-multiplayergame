extends "res://KronburgTownKit.gd"
## Rheinufer's west bank (Kronburg GP, stage 2): the Lower Rhine (Niederrhein) country beside the race. A brick tower
## windmill with a stage (Galerieholländer) and its lattice sails, the brick farmsteads (a Hallenhaus, a barn, a cart
## shed), a shepherd's cart, silage bales, paddock fences and a field gate, a tractor and a hay wagon, and the main block
## of a fictional coal-fired power station, Kraftwerk Weidenhoven. All fictional: generic Lower Rhine types.
##
## Everything is built at LIFE size through YardKit's / KronburgTownKit's kit machinery and grown by the caller (PROP_SCALE
## 1.6): make a kit with `new_kit(scale)`, set its frame to the piece's place, call a builder, `commit(pk, kit)`. UVs are
## in metres times `uvk` (the caller's scale) where a shader reads them. Labels are YardKit's [text, position, outward
## normal, cap height, colour, board width], life size in the piece's frame. No colliders: DressingColliders gives every
## single mesh its own at race time (a trimesh over 5m across, else a hull).
##
## Builders and their frames (life metres; y = 0 the ground, footings down to y = -2 or below):
##   tower_windmill(pk, kit, labels)  the tower's axis at the origin, the cap and sails facing +z; tower 9.4m across at
##                                    the foot, the cap's foot (curb) at MILL_CURB 18.5, the cap's top 22.8; the stage
##                                    (gallery) deck at MILL_STAGE 6.15, reaching to radius 6.65. The sails are separate:
##   windmill_sails(pk, kit)          four lattice sails 24m tip to tip round the local origin, turning about local +z
##                                    (they face +z). Place them with `mill_sails_transform()` in the mill's frame
##                                    (the hub MILL_HUB, the axis tilted up MILL_TILT degrees at the front) and spin them
##                                    about their local z: positive angles turn them anticlockwise seen from the front,
##                                    as Dutch and Lower Rhine mills turn.
##   farmhouse(pk, kit, labels, variant)   0 the Hallenhaus (walls x 0..14, z 0..-26; the front gable with the barn door
##                                    at z 0 facing +z; eaves 0.55 and verges 0.42 over; ridge 11.5m, chimneys 12.8m),
##                                    1 a brick barn and stable (x 0..11, z 0..-20, ridge 10.0m), 2 a cart shed open
##                                    toward +z (x 0..12, z 0..-7, ridge 6.4m, 3.3m clear under its front beam).
##   shepherd_cart(pk, kit, labels)   centred on the origin, drawbar toward -z, door at +z; x +-1.14, z -3.55..3.2, the
##                                    roof 3.33m, the stove pipe 4.5m
##   silage_bales(pk, kit, rng, n)    n round bales from the origin along +x, some stacked; returns the footprint Rect2
##   paddock_fence(pk, kit, points)   posts and rails along a polyline (its points' y the ground under them)
##   field_gate(pk, kit)              a 4m galvanised five-bar gate between two posts, x 0..4.3, closed along x
##   tractor(pk, kit, variant)        0 green, 1 red; on the ground midway between the axles (front z -1.3, rear +1.25),
##                                    nose toward -z; x +-1.24, z -2.63..2.3, cab roof 2.92m, exhaust 3.0m
##   hay_wagon(pk, kit)               a farm trailer with ladder racks and a load of small bales, drawbar toward -z;
##                                    x +-1.18, z -4.6..2.83, the load 2.85m, the racks 3.25m
##   power_station(pk, kit, labels)   Kraftwerk Weidenhoven's main block: the boiler house at the origin (45 x 45m,
##                                    104m to the top of its frame), the turbine hall toward +z, the flue gas cleaning
##                                    toward -z, the switchyard toward +x, the coal yard toward -x. See POWER_* for where
##                                    SteelworksKit's chimney and cooling towers go.
##
## Material keys: the town's and yard's ("kbrick", "biber", "kslate", "ashlar", "pane", "enamel", "leaf", "timber",
## "lapboards", "battens", "painted", "iron", "concrete", "plaster", "steel", "metal", "matte", "rubber", "paint", "canvas",
## "glass", "lamp"), SteelworksKit's industrial ones ("grime", "rusty", "shell", "heap", "hazard"), and new ones: "pantile"
## (niederrhein_pantile.gdshader, Hohlpfannen; UVs in metres, tangents), "wrap" (silage film: glossy vertex colour), "hay"
## (hay_bale.gdshader: the wagon's small bales),
## "cladding" (hut_roof_iron with little rust: the power station's profiled sheet; tangents).
##
## Faces never share a plane: trims, decals, frames, glass and paint layers stand 2.5cm (life) or more proud of what is
## behind them; Godot's front faces wind clockwise and PropKit.tri winds every triangle for the `out` it is given.

const KTK = preload("res://KronburgTownKit.gd")
const SteelworksKit = preload("res://SteelworksKit.gd")

static var _nmats := {}
const NTANGENTS := ["tile", "iron", "concrete", "zinc", "slate", "biber", "kslate", "pantile", "cladding"]

const NR_BRICK := Color(0.44, 0.21, 0.15)
const NR_BRICK_DARK := Color(0.32, 0.15, 0.11)
const TAR := Color(0.11, 0.10, 0.09)
const PANTILE_RED := Color(0.58, 0.25, 0.16)
const WHITE_TRIM := Color(0.94, 0.94, 0.91)
const NR_GREEN := Color(0.10, 0.33, 0.22)
const MILL_SAIL := Color(0.90, 0.88, 0.82)
const MILL_STOCK := Color(0.16, 0.22, 0.19)
const OAK := Color(0.42, 0.31, 0.21)
const WEATHERED := Color(0.48, 0.44, 0.38)


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"pantile":
			var m := ShaderMaterial.new()
			m.shader = load("res://niederrhein_pantile.gdshader")
			return m
		"wrap":
			var w := StandardMaterial3D.new()
			w.vertex_color_use_as_albedo = true
			w.vertex_color_is_srgb = true
			w.roughness = 0.3
			w.metallic_specular = 0.6
			return w
		"cladding":
			var c := ShaderMaterial.new()
			c.shader = load("res://hut_roof_iron.gdshader")
			c.set_shader_parameter("rust_amount", 0.04)
			c.set_shader_parameter("pitch", 0.3)
			c.set_shader_parameter("sheet_w", 1.6)
			c.set_shader_parameter("sheet_len", 9.0)
			return c
		"hay":
			var h := ShaderMaterial.new()
			h.shader = load("res://hay_bale.gdshader")
			return h
		"grime", "rusty", "shell", "heap", "hazard", "roofing", "corten", "floor":
			return SteelworksKit.make_material(key)
	return KTK.make_material(key)


static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _nmats.has(k):
			_nmats[k] = make_material(k)
		return _nmats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	SteelworksKit.uvk = scale
	return pk


## The materials made so far, by key (the generator saves them so every mesh shares one per key).
static func materials() -> Dictionary:
	return _nmats


## Commits a kit with tangents on the surfaces whose shaders read a normal map, each surface named after its key.
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in NTANGENTS:
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

## An arch's outline in a wall frame's x-y plane: straight sides from y0 up to `spring`, a half circle over them
## (`segs` steps), `half` the half width; counter-clockwise.
static func _arch_ol(half: float, y0: float, spring: float, segs := 8, cx := 0.0) -> PackedVector2Array:
	var ol := PackedVector2Array([Vector2(cx - half, y0), Vector2(cx + half, y0)])
	for k in range(segs + 1):
		var a: float = PI * float(k) / float(segs)
		ol.append(Vector2(cx + cos(a) * half, spring + sin(a) * half))
	return ol


## A segmental (flat) arch's outline: straight sides to `spring`, an arc rising `rise` over the span.
static func _segment_ol(half: float, y0: float, spring: float, rise: float, segs := 6, cx := 0.0) -> PackedVector2Array:
	var ol := PackedVector2Array([Vector2(cx - half, y0), Vector2(cx + half, y0)])
	var r: float = (half * half + rise * rise) / (2.0 * rise)
	var cy: float = spring + rise - r
	var a0: float = asin(clampf(half / r, -1.0, 1.0))
	for k in range(segs + 1):
		var a: float = lerpf(a0, -a0, float(k) / float(segs))
		ol.append(Vector2(cx + sin(a) * r, cy + cos(a) * r))
	return ol


## A small window with an arched (or segmental) head, laid on a wall frame `wf` (x along, y up, z out) at u: a brick
## surround (`sur` colour) standing 4.5cm off the wall, a white frame on it, dark glass and glazing bars in front: each
## layer 2.5cm or more proud of the last (a flat stack also sits on a round wall: its edges stay out of it).
static func _arch_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, h: float, sur: Color,
		seg_rise := 0.0, bars := 2, frame := WHITE_TRIM) -> void:
	var half: float = w * 0.5
	var spring: float = v0 + h - (seg_rise if seg_rise > 0.0 else half)
	var outer: PackedVector2Array
	var mid: PackedVector2Array
	var inner: PackedVector2Array
	if seg_rise > 0.0:
		outer = _segment_ol(half + 0.13, v0 - 0.1, spring, seg_rise + 0.07, 6, u)
		mid = _segment_ol(half + 0.04, v0 - 0.03, spring, seg_rise + 0.02, 6, u)
		inner = _segment_ol(half - 0.04, v0 + 0.05, spring, seg_rise - 0.02, 6, u)
	else:
		outer = _arch_ol(half + 0.13, v0 - 0.1, spring, 8, u)
		mid = _arch_ol(half + 0.04, v0 - 0.03, spring, 8, u)
		inner = _arch_ol(half - 0.04, v0 + 0.05, spring, 8, u)
	_prism(pk, kit, "kbrick", wf, outer, 0.0, 0.045, sur, Vector2(1, 0))
	_prism(pk, kit, "painted", wf, mid, 0.045, 0.07, frame, Vector2(0, 1))
	_pface(pk, kit, "pane", wf, inner, 0.075, GLASS)
	# The upright bar a little shallower than the rails across it, so where they cross no two faces share a plane.
	_rect(pk, kit, "painted", wf, u - 0.025, v0 + 0.05, u + 0.025, v0 + h - 0.06, 0.075, 0.09, frame)
	for k in range(1, bars + 1):
		var y: float = lerpf(v0 + 0.05, spring, float(k) / float(bars + 1))
		_rect(pk, kit, "painted", wf, u - half + 0.04, y - 0.022, u + half - 0.04, y + 0.022, 0.075, 0.1, frame)
	# The sill: a brick-on-edge course sloping out under it.
	_rect(pk, kit, "kbrick", wf, u - half - 0.12, v0 - 0.2, u + half + 0.12, v0 - 0.08, 0.0, 0.1, sur.darkened(0.15))


## A plank door (one or two leaves) with an arched or segmental head on a wall frame: a brick surround, the boards
## (vertical, `col`) standing 3.5cm off it, ledges and strap hinges in front.
static func _plank_door(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, w: float, h: float, col: Color, sur: Color,
		leaves := 2, seg_rise := 0.0) -> void:
	var half: float = w * 0.5
	var spring: float = v0 + h - (seg_rise if seg_rise > 0.0 else half)
	var outer: PackedVector2Array = _segment_ol(half + 0.16, v0, spring, seg_rise + 0.1, 6, u) if seg_rise > 0.0 else _arch_ol(half + 0.16, v0, spring, 8, u)
	var leaf_ol: PackedVector2Array = _segment_ol(half, v0 + 0.02, spring, seg_rise, 6, u) if seg_rise > 0.0 else _arch_ol(half, v0 + 0.02, spring, 8, u)
	_prism(pk, kit, "kbrick", wf, outer, 0.0, 0.03, sur, Vector2(1, 0))
	_prism(pk, kit, "painted", wf, leaf_ol, 0.03, 0.065, col, Vector2(0, 1))
	# Board joints: dark grooves standing as thin strips 1cm proud of the boards.
	var nb: int = maxi(int(w / 0.16), 3)
	for k in range(1, nb):
		var x: float = u - half + w * float(k) / float(nb)
		_rect(pk, kit, "painted", wf, x - 0.008, v0 + 0.05, x + 0.008, spring - 0.04, 0.065, 0.075, col.darkened(0.35))
	if leaves == 2:
		_rect(pk, kit, "painted", wf, u - 0.015, v0 + 0.03, u + 0.015, spring + (seg_rise if seg_rise > 0.0 else half) - 0.04, 0.065, 0.08, col.darkened(0.45))
	for yy in [v0 + 0.35, v0 + h * 0.62]:
		_rect(pk, kit, "painted", wf, u - half + 0.08, yy - 0.07, u + half - 0.08, yy + 0.07, 0.065, 0.1, col.darkened(0.08))
		for sx in [-1.0, 1.0]:
			if leaves == 1 and sx > 0.0:
				continue
			var hx: float = u + sx * (half - 0.05)
			_rect(pk, kit, "matte", wf, minf(hx, hx - sx * w * 0.32), yy - 0.03, maxf(hx, hx - sx * w * 0.32), yy + 0.03, 0.1, 0.115, Color(0.08, 0.08, 0.08))


## A board in a frame with letters on it: [text...] go into `labels` (life size, the kit's frame `lx`).
static func _board(pk: PropKit, kit: Dictionary, labels: Array, wf: Transform3D, u: float, v: float, w: float, h: float, text: String,
		bg: Color, fg: Color, lx := Transform3D.IDENTITY) -> void:
	_rect(pk, kit, "painted", wf, u - w * 0.5 - 0.05, v - h * 0.5 - 0.05, u + w * 0.5 + 0.05, v + h * 0.5 + 0.05, 0.0, 0.04, fg.darkened(0.2))
	_rect(pk, kit, "painted", wf, u - w * 0.5, v - h * 0.5, u + w * 0.5, v + h * 0.5, 0.04, 0.07, bg)
	var p: Vector3 = lx * (wf * Vector3(u, v, 0.1))
	var n: Vector3 = (lx.basis * wf.basis.z).normalized()
	labels.append([text, p, n, h * 0.5, fg, w - 0.1])


## A roof polygon (convex, its points in order round its edge) facing `out`, UVs in metres: u along `along`, v up the
## slope from `origin`. With `under` its underside too, `drop` below and darker (boards: "lapboards").
static func _roof_poly(pk: PropKit, kit: Dictionary, key: String, pts: Array, out: Vector3, origin: Vector3, along: Vector3, col: Color,
		under_key := "lapboards", under_col := Color(0.44, 0.32, 0.22), drop := 0.08) -> void:
	var al: Vector3 = along.normalized()
	var upd: Vector3 = out.cross(al).normalized()
	if upd.y < 0.0:
		upd = -upd
	var uvs: Array = []
	for p in pts:
		var d: Vector3 = (p as Vector3) - origin
		uvs.append(Vector2(d.dot(al), d.dot(upd)) * uvk)
	for i in range(1, pts.size() - 1):
		pk.tri(kit, key, pts[0], pts[i], pts[i + 1], out, out, out, col, out, uvs[0], uvs[i], uvs[i + 1])
	if under_key != "":
		var dn: Vector3 = -out * drop
		for i in range(1, pts.size() - 1):
			pk.tri(kit, under_key, (pts[0] as Vector3) + dn, (pts[i] as Vector3) + dn, (pts[i + 1] as Vector3) + dn, -out, -out, -out, under_col, -out,
					uvs[0], uvs[i], uvs[i + 1])


## A wall polygon (convex) in a wall frame at depth d, UVs (x, y) in metres: gables and walls in one call.
static func _wall_ol(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, ol: PackedVector2Array, col: Color, d := 0.0) -> void:
	_pface(pk, kit, key, wf, ol, d, col)


# ======================================================================================
#  The tower windmill (Galerieholländer)
# ======================================================================================

const MILL_R0 := 4.7         ## the tower's radius at the ground
const MILL_R1 := 3.15        ## at the curb (the cap's foot)
const MILL_CURB := 18.5      ## the cap's foot
const MILL_STAGE := 6.15     ## the stage's deck top
const MILL_STAGE_OUT := 6.65 ## the stage's outer edge (radius)
const MILL_TILT := 8.0       ## the windshaft's tilt in degrees: its front end raised, so the sails lean back at the top
const MILL_HUB := Vector3(0.0, 20.75, 5.35)  ## the sails' hub (their local origin) in the mill's frame
const MILL_PLINTH := 1.1
const MILL_CAP_A := 3.55     ## the cap's half width
const MILL_CAP_C := 4.5      ## the cap's half length (along z)
const MILL_CAP_Z := 0.4      ## the cap's middle (along z)
const MILL_CAP_H := 4.3      ## the cap's height over the curb
const MILL_SAIL_R := 12.0    ## the sails' reach from the hub


## The tower's outer radius at height y.
static func mill_radius(y: float) -> float:
	return lerpf(MILL_R0, MILL_R1, clampf(y / MILL_CURB, 0.0, 1.0))


## The windshaft's axis (unit, the mill's frame): forward (+z) and a little up.
static func mill_axis() -> Vector3:
	var t: float = deg_to_rad(MILL_TILT)
	return Vector3(0.0, sin(t), cos(t))


## Where the sails go in the mill's frame: their local z along mill_axis(), their origin at the hub. Spin a child of a node
## with this transform about its local z.
static func mill_sails_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(MILL_TILT)), MILL_HUB)


## A wall frame on the tower's face at angle `th` (round from +x toward +z) and height y: x along the wall, y up it
## (leaning in with the batter), z out of it.
static func _mill_wf(th: float, y: float) -> Transform3D:
	var dr: float = -(MILL_R0 - MILL_R1) / MILL_CURB
	var n0 := Vector3(cos(th), 0.0, sin(th))
	var up: Vector3 = (n0 * dr + Vector3.UP).normalized()
	var out: Vector3 = (n0 - Vector3.UP * dr).normalized()
	var x: Vector3 = up.cross(out).normalized()
	return Transform3D(Basis(x, up, out), n0 * mill_radius(y) + Vector3(0, y, 0))


## The Galerieholländer: see the header. About 6k triangles.
static func tower_windmill(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var segs := 32
	# The footing and the tarred plinth, then the brick tower to a corbelled cornice under the curb.
	SteelworksKit._lathe_uv(pk, kit, "kbrick", Vector3.ZERO, [Vector2(MILL_R0 + 0.32, -2.0), Vector2(MILL_R0 + 0.32, MILL_PLINTH - 0.25),
			Vector2(MILL_R0 + 0.12, MILL_PLINTH), Vector2(mill_radius(MILL_PLINTH) + 0.04, MILL_PLINTH + 0.03)], segs, TAR, false, true)
	var prof: Array = []
	for k in range(6):
		var y: float = lerpf(MILL_PLINTH, MILL_CURB - 0.9, float(k) / 5.0)
		prof.append(Vector2(mill_radius(y), y))
	SteelworksKit._lathe_uv(pk, kit, "kbrick", Vector3.ZERO, prof, segs, NR_BRICK)
	var yc: float = MILL_CURB - 0.9
	var rc: float = mill_radius(yc)
	SteelworksKit._lathe_uv(pk, kit, "kbrick", Vector3.ZERO, [Vector2(rc, yc), Vector2(rc + 0.12, yc + 0.08), Vector2(rc + 0.12, yc + 0.3),
			Vector2(rc + 0.22, yc + 0.36), Vector2(rc + 0.22, yc + 0.62), Vector2(MILL_R1 - 0.02, MILL_CURB - 0.25)], segs, NR_BRICK_DARK, false, true)
	# A brick band at the stage's height and one higher up.
	for by in [MILL_STAGE - 1.1, 12.6]:
		var r: float = mill_radius(by)
		SteelworksKit._lathe_uv(pk, kit, "kbrick", Vector3.ZERO, [Vector2(r - 0.02, by), Vector2(r + 0.06, by + 0.04), Vector2(r + 0.06, by + 0.3),
				Vector2(r - 0.02, by + 0.34)], segs, NR_BRICK_DARK, false, true)
	# Windows round the tower, in a loose spiral as the floors inside are lit; the doors.
	for wdef in [[PI * 0.75, 2.0, 0.8, 1.3], [-PI * 0.7, 2.0, 0.8, 1.3], [PI * 0.3, 9.0, 0.75, 1.25], [PI * 1.15, 9.2, 0.75, 1.25], [PI * 0.55, 12.0, 0.7, 1.15],
			[-PI * 0.2, 12.3, 0.7, 1.15], [PI * 0.9, 15.0, 0.65, 1.05], [PI * 0.1, 15.2, 0.65, 1.05], [PI * 0.5, MILL_STAGE + 0.85, 0.8, 1.35]]:
		_arch_window(pk, kit, _mill_wf(float(wdef[0]), float(wdef[1])), 0.0, 0.0, float(wdef[2]), float(wdef[3]), NR_BRICK_DARK)
	_plank_door(pk, kit, _mill_wf(0.0, 0.25), 0.0, 0.0, 1.6, 2.45, NR_GREEN, NR_BRICK_DARK, 2)
	# A step before the ground door, and the stage door at the back (toward the tail).
	pk.block(kit, "ashlar", Vector3(MILL_R0 + 0.2, -0.3, -1.1), Vector3(MILL_R0 + 0.75, 0.24, 1.1), KTK.SANDSTONE, uvk)
	_plank_door(pk, kit, _mill_wf(-PI * 0.5, MILL_STAGE + 0.02), 0.0, 0.0, 1.15, 2.1, NR_GREEN, NR_BRICK_DARK, 1)
	_board(pk, kit, labels, _mill_wf(0.0, 3.3), 0.0, 0.0, 2.6, 0.42, "ANNO 1858", WHITE_TRIM, Color(0.1, 0.1, 0.1))
	_mill_stage(pk, kit)
	_mill_cap(pk, kit)


## The stage: a timber deck round the tower on joists and raking struts from the wall, a railing round its edge.
static func _mill_stage(pk: PropKit, kit: Dictionary) -> void:
	var n := 24
	var y1: float = MILL_STAGE
	var y0: float = MILL_STAGE - 0.16
	var ri: float = mill_radius(y1) - 0.15
	var ro: float = MILL_STAGE_OUT
	var deck := OAK.lerp(WEATHERED, 0.5)
	for k in range(n):
		var a0: float = TAU * float(k) / float(n)
		var a1: float = TAU * float(k + 1) / float(n)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var dm: Vector3 = (d0 + d1).normalized()
		# Deck boards run out from the wall (u along the radius); the underside and the outer edge.
		pk.quad(kit, "lapboards", [d0 * ri + Vector3(0, y1, 0), d0 * ro + Vector3(0, y1, 0), d1 * ro + Vector3(0, y1, 0), d1 * ri + Vector3(0, y1, 0)], Vector3.UP, deck,
				[Vector2(ri, a0 * ri) * uvk, Vector2(ro, a0 * ro) * uvk, Vector2(ro, a1 * ro) * uvk, Vector2(ri, a1 * ri) * uvk])
		pk.quad(kit, "lapboards", [d0 * ri + Vector3(0, y0, 0), d1 * ri + Vector3(0, y0, 0), d1 * ro + Vector3(0, y0, 0), d0 * ro + Vector3(0, y0, 0)], Vector3.DOWN, deck.darkened(0.3),
				[Vector2(ri, a0 * ri) * uvk, Vector2(ri, a1 * ri) * uvk, Vector2(ro, a1 * ro) * uvk, Vector2(ro, a0 * ro) * uvk])
		pk.quad(kit, "timber", [d0 * ro + Vector3(0, y0, 0), d1 * ro + Vector3(0, y0, 0), d1 * ro + Vector3(0, y1, 0), d0 * ro + Vector3(0, y1, 0)], dm, deck.darkened(0.1),
				[Vector2(a0 * ro, y0) * uvk, Vector2(a1 * ro, y0) * uvk, Vector2(a1 * ro, y1) * uvk, Vector2(a0 * ro, y1) * uvk])
		# A joist under every board run's edge, a strut under every other one from the wall below.
		var rw: float = mill_radius(y0 - 0.2)
		pk.beam(kit, "timber", d0 * (rw - 0.1) + Vector3(0, y0 - 0.11, 0), d0 * (ro - 0.06) + Vector3(0, y0 - 0.11, 0), 0.22, 0.14, deck.darkened(0.2), Vector3.UP, uvk)
		if k % 2 == 0:
			var rs: float = mill_radius(y0 - 2.6)
			pk.beam(kit, "timber", d0 * (rs - 0.05) + Vector3(0, y0 - 2.6, 0), d0 * (rw + 1.5) + Vector3(0, y0 - 0.2, 0), 0.12, 0.12, deck.darkened(0.25), Vector3.UP, uvk)
		# Railing posts, a top rail and a knee rail, a kick board.
		var rp: float = ro - 0.12
		var pa: Vector3 = d0 * rp
		var pb: Vector3 = d1 * rp
		pk.beam(kit, "timber", pa + Vector3(0, y1, 0), pa + Vector3(0, y1 + 1.12, 0), 0.1, 0.1, deck.darkened(0.15), Vector3.UP, uvk)
		pk.beam(kit, "timber", pa + Vector3(0, y1 + 1.1, 0), pb + Vector3(0, y1 + 1.1, 0), 0.12, 0.07, deck.darkened(0.1), Vector3.UP, uvk)
		pk.beam(kit, "timber", pa + Vector3(0, y1 + 0.58, 0), pb + Vector3(0, y1 + 0.58, 0), 0.07, 0.06, deck.darkened(0.1), Vector3.UP, uvk)
		pk.beam(kit, "timber", pa + dm * 0.02 + Vector3(0, y1 + 0.1, 0), pb + dm * 0.02 + Vector3(0, y1 + 0.1, 0), 0.16, 0.04, deck.darkened(0.2), Vector3.UP, uvk)


## A point on the cap's surface: `ph` round it (0 along +x, toward +z), `s` 0 at its foot to 1 at its ridge. The plan's
## section is a rounded rectangle that narrows faster across than along as it rises, so the top is a short ridge along z:
## a boat-shaped Lower Rhine cap.
static func _cap_point(ph: float, s: float) -> Vector3:
	var y: float = s * MILL_CAP_H
	var fx: float = sqrt(maxf(1.0 - pow(s, 2.0), 0.0))
	var fz: float = pow(maxf(1.0 - pow(s, 4.0), 0.0), 0.25)
	var c: float = cos(ph)
	var sn: float = sin(ph)
	var x: float = MILL_CAP_A * fx * signf(c) * pow(absf(c), 2.0 / 2.4)
	var z: float = MILL_CAP_C * fz * signf(sn) * pow(absf(sn), 2.0 / 3.4)
	# A little flare at the eave.
	var flare: float = 1.0 + 0.05 * (1.0 - smoothstep(0.0, 0.18, s))
	return Vector3(x * flare, MILL_CURB - 0.12 + y, MILL_CAP_Z + z * flare)


## The cap: shingled, boat-shaped, on a timber curb; its underside, the windshaft out of its front, the tail pole with its
## struts down to the stage and the winding wheel on its end.
static func _mill_cap(pk: PropKit, kit: Dictionary) -> void:
	# The curb ring the cap turns on.
	pk.lathe(kit, "timber", Vector3.ZERO, [Vector2(MILL_R1 - 0.15, MILL_CURB - 0.3), Vector2(MILL_R1 + 0.2, MILL_CURB - 0.3), Vector2(MILL_R1 + 0.2, MILL_CURB - 0.1),
			Vector2(MILL_R1 - 0.15, MILL_CURB - 0.1)], 32, OAK.darkened(0.3), true)
	var ni := 28
	var nj := 10
	var grid: Array = []
	for j in range(nj + 1):
		var s: float = 1.0 - pow(1.0 - float(j) / float(nj), 1.4)
		s = minf(s, 0.985)
		var ring: Array = []
		for i in range(ni + 1):
			ring.append(_cap_point(TAU * float(i) / float(ni), s))
		grid.append(ring)
	var shingle := Color(0.44, 0.40, 0.35)
	# UV: u round the cap (metres along the foot ring), v up each meridian (metres).
	var us := PackedFloat32Array([0.0])
	for i in range(ni):
		us.append(us[i] + (grid[0][i] as Vector3).distance_to(grid[0][i + 1]))
	var vs: Array = []
	for i in range(ni + 1):
		var col := PackedFloat32Array([0.0])
		for j in range(nj):
			col.append(col[j] + (grid[j][i] as Vector3).distance_to(grid[j + 1][i]))
		vs.append(col)
	var mid := Vector3(0, MILL_CURB, MILL_CAP_Z)
	for j in range(nj):
		for i in range(ni):
			var p00: Vector3 = grid[j][i]
			var p01: Vector3 = grid[j][i + 1]
			var p10: Vector3 = grid[j + 1][i]
			var p11: Vector3 = grid[j + 1][i + 1]
			var n00: Vector3 = _cap_normal(grid, i, j, ni, nj)
			var n01: Vector3 = _cap_normal(grid, i + 1, j, ni, nj)
			var n10: Vector3 = _cap_normal(grid, i, j + 1, ni, nj)
			var n11: Vector3 = _cap_normal(grid, i + 1, j + 1, ni, nj)
			var out: Vector3 = ((p00 + p11) * 0.5 - mid).normalized()
			var uv00 := Vector2(us[i], vs[i][j]) * uvk
			var uv01 := Vector2(us[i + 1], vs[i + 1][j]) * uvk
			var uv10 := Vector2(us[i], vs[i][j + 1]) * uvk
			var uv11 := Vector2(us[i + 1], vs[i + 1][j + 1]) * uvk
			pk.tri(kit, "kslate", p00, p01, p11, n00, n01, n11, shingle, out, uv00, uv01, uv11)
			pk.tri(kit, "kslate", p00, p11, p10, n00, n11, n10, shingle, out, uv00, uv11, uv10)
	# The ridge closed by a timber ridge piece along the top ring, and a knob on it.
	var top: Array = grid[nj]
	var tc := Vector3.ZERO
	for i in range(ni):
		tc += top[i]
	tc /= float(ni)
	for i in range(ni):
		var a: Vector3 = top[i]
		var b: Vector3 = top[i + 1]
		pk.tri(kit, "kslate", tc + Vector3(0, 0.02, 0), a, b, Vector3.UP, Vector3.UP, Vector3.UP, shingle, Vector3.UP)
	pk.beam(kit, "timber", Vector3(0, tc.y + 0.05, MILL_CAP_Z - 1.6), Vector3(0, tc.y + 0.05, MILL_CAP_Z + 1.6), 0.22, 0.14, OAK.darkened(0.3), Vector3.UP, uvk)
	pk.lathe(kit, "paint", Vector3(0, tc.y + 0.1, MILL_CAP_Z - 1.5), [Vector2(0.001, 0.0), Vector2(0.09, 0.05), Vector2(0.12, 0.25), Vector2(0.06, 0.45), Vector2(0.001, 0.62)], 8, WHITE_TRIM, false)
	# The underside: the foot ring closed by a flat boarded floor.
	var foot: Array = grid[0]
	var fc := Vector3(0, (foot[0] as Vector3).y - 0.02, MILL_CAP_Z)
	for i in range(ni):
		var a2: Vector3 = (foot[i] as Vector3) + Vector3(0, -0.02, 0)
		var b2: Vector3 = (foot[i + 1] as Vector3) + Vector3(0, -0.02, 0)
		pk.tri(kit, "lapboards", fc, b2, a2, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, OAK.darkened(0.45), Vector3.DOWN,
				Vector2(fc.x, fc.z) * uvk, Vector2(b2.x, b2.z) * uvk, Vector2(a2.x, a2.z) * uvk)
	# The windshaft out of the cap's front to the sails' hub.
	var ax: Vector3 = mill_axis()
	pk.tube(kit, "steel", MILL_HUB - ax * 2.8, MILL_HUB - ax * 0.42, 0.3, 0.3, 12, Color(0.16, 0.16, 0.17), true)
	pk.tube(kit, "timber", MILL_HUB - ax * 1.6, MILL_HUB - ax * 1.15, 0.5, 0.5, 12, OAK.darkened(0.35), true)
	# The tail pole (Steert) down the back to the stage, two struts from the cap's sides, the winding wheel at its foot.
	var tail_top := Vector3(0, MILL_CURB - 0.05, MILL_CAP_Z - MILL_CAP_C * 0.86)
	var tail_end := Vector3(0, MILL_STAGE + 1.25, -(MILL_STAGE_OUT - 0.42))
	var tcol: Color = OAK.darkened(0.25)
	pk.beam(kit, "timber", tail_top + Vector3(0, 0.25, 0.5), tail_end, 0.32, 0.32, tcol, Vector3.RIGHT, uvk)
	var on_tail: Vector3 = tail_top.lerp(tail_end, 0.42)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "timber", Vector3(sx * MILL_CAP_A * 0.9, MILL_CURB - 0.1, MILL_CAP_Z - 0.6), on_tail + Vector3(sx * 0.12, 0, 0), 0.18, 0.18, tcol, Vector3.UP, uvk)
		pk.beam(kit, "timber", Vector3(sx * MILL_CAP_A * 0.7, MILL_CURB - 0.1, MILL_CAP_Z - 2.6), on_tail + Vector3(sx * 0.1, 1.2, 0.3), 0.14, 0.14, tcol, Vector3.UP, uvk)
	# The winding wheel (Kruirad): a spoked wheel across the pole's end, its axle along the pole.
	var wc: Vector3 = tail_end + Vector3(0, 0.0, 0.18)
	var wr := 0.95
	var nw := 14
	for k in range(nw):
		var a0: float = TAU * float(k) / float(nw)
		var a1: float = TAU * float(k + 1) / float(nw)
		var p0: Vector3 = wc + Vector3(cos(a0) * wr, sin(a0) * wr, 0)
		var p1: Vector3 = wc + Vector3(cos(a1) * wr, sin(a1) * wr, 0)
		pk.beam(kit, "timber", p0, p1, 0.08, 0.1, tcol.darkened(0.1), Vector3(0, 0, 1), uvk)
		if k % 2 == 0:
			pk.beam(kit, "timber", wc, wc + (p0 - wc) * 0.96, 0.05, 0.05, tcol, Vector3(0, 0, 1), uvk)
		# Handles round the rim.
		if k % 2 == 1:
			pk.beam(kit, "timber", p0, wc + (p0 - wc) * 1.22, 0.04, 0.04, tcol, Vector3(0, 0, 1), uvk)
	pk.tube(kit, "steel", wc + Vector3(0, 0, -0.25), wc + Vector3(0, 0, 0.2), 0.11, 0.11, 8, Color(0.15, 0.15, 0.15), true)
	# The chain from the wheel's axle to a post on the stage's edge.
	pk.beam(kit, "steel", wc + Vector3(0, -0.1, 0.0), Vector3(0.6, MILL_STAGE + 0.5, -(MILL_STAGE_OUT - 0.2)), 0.03, 0.03, Color(0.12, 0.12, 0.12))


static func _cap_normal(grid: Array, i: int, j: int, ni: int, nj: int) -> Vector3:
	var a: Vector3 = grid[j][(i + 1) % ni]
	var b: Vector3 = grid[j][(i - 1 + ni) % ni]
	var c: Vector3 = grid[mini(j + 1, nj)][i % ni]
	var d: Vector3 = grid[maxi(j - 1, 0)][i % ni]
	var n: Vector3 = (c - d).cross(a - b).normalized()
	var mid := Vector3(0, MILL_CURB, MILL_CAP_Z)
	if n.dot((grid[j][i % ni] as Vector3) - mid) < 0.0:
		n = -n
	return n


## Four lattice sails (Gitterflügel) round the local origin, turning about local +z (they face +z): two stocks through the
## cast-iron poll end at the hub, and on each sail 24 sail bars across a lattice 10m long from 2m out, its weather (the
## twist) 18 degrees at the heel to 4 at the tip, the trailing side 1.55m wide and the leading 0.45m, with the canvas
## furled along the stock. About 2k triangles.
static func windmill_sails(pk: PropKit, kit: Dictionary) -> void:
	var z_stock: Array = [-0.16, 0.16]
	# The poll end: a cast-iron box on the shaft, its sockets round the stocks.
	pk.tube(kit, "steel", Vector3(0, 0, -0.55), Vector3(0, 0, 0.36), 0.42, 0.42, 10, Color(0.16, 0.16, 0.17), true)
	for k in range(2):
		var d := Vector3(cos(PI * 0.25 + PI * 0.5 * float(k)), sin(PI * 0.25 + PI * 0.5 * float(k)), 0.0)
		var zs: float = z_stock[k]
		pk.box(kit, "steel", Transform3D(Basis(d, Vector3.BACK.cross(d), Vector3.BACK), Vector3(0, 0, zs)), Vector3(1.5, 0.62, 0.36), Color(0.18, 0.18, 0.19))
		# The stock: a squared timber tapering from the hub to both tips.
		for sgn in [-1.0, 1.0]:
			var tip: Vector3 = d * (MILL_SAIL_R + 0.25) * sgn + Vector3(0, 0, zs)
			pk.tube(kit, "painted", Vector3(0, 0, zs), tip, 0.21, 0.1, 4, MILL_STOCK, true, uvk)
	for k in range(4):
		var ang: float = PI * 0.25 + PI * 0.5 * float(k)
		var d := Vector3(cos(ang), sin(ang), 0.0)
		var m := Vector3(-d.y, d.x, 0.0)
		var zs: float = z_stock[k % 2]
		_sail(pk, kit, d, m, zs)


## One sail along `d`, moving toward `m` (its leading side), on the stock at depth zs.
static func _sail(pk: PropKit, kit: Dictionary, d: Vector3, m: Vector3, zs: float) -> void:
	var r0 := 2.0
	var r1: float = MILL_SAIL_R - 0.15
	var lead := 0.45
	var trail := 1.55
	var chord := func(r: float) -> Vector3:
		var w: float = deg_to_rad(lerpf(18.0, 4.0, (r - r0) / (r1 - r0)))
		# From the trailing edge toward the leading one: forward along m and upwind (+z).
		return (m * cos(w) + Vector3.BACK * sin(w)).normalized()
	var front: float = 0.07   # the lattice lies on the stock's windward face
	var at := func(r: float, c: float) -> Vector3:
		return d * r + Vector3(0, 0, zs + front) + (chord.call(r) as Vector3) * c
	var nb := 24
	for i in range(nb + 1):
		var r: float = lerpf(r0, r1, float(i) / float(nb))
		pk.beam(kit, "painted", at.call(r, lead), at.call(r, -trail), 0.055, 0.045, MILL_SAIL, d, uvk)
	# The laths along the sail: at the leading edge, two across the trailing side and its edge.
	for c in [lead - 0.03, -0.55, -1.05, -trail + 0.03]:
		var prev: Vector3 = at.call(r0 - 0.1, c)
		for j in range(1, 5):
			var r2: float = lerpf(r0 - 0.1, r1 + 0.1, float(j) / 4.0)
			var p: Vector3 = (at.call(r2, c) as Vector3) + Vector3(0, 0, 0.045)
			pk.beam(kit, "painted", prev + (Vector3(0, 0, 0.045) if j > 1 else Vector3(0, 0, 0.045)), p, 0.07, 0.05, MILL_SAIL.darkened(0.06), Vector3.BACK, uvk)
			prev = p - Vector3(0, 0, 0.045)
	# The canvas, furled and tied along the stock's trailing side.
	var c0: Vector3 = d * (r0 + 0.3) + Vector3(0, 0, zs - 0.05) - m * 0.32
	var c1: Vector3 = d * (r1 - 0.6) + Vector3(0, 0, zs - 0.05) - m * 0.3
	pk.tube(kit, "canvas", c0, c1, 0.11, 0.09, 7, Color(0.86, 0.82, 0.72), true)
	for t in [0.2, 0.45, 0.7, 0.92]:
		var p2: Vector3 = c0.lerp(c1, t)
		pk.tube(kit, "matte", p2 - d * 0.03, p2 + d * 0.03, 0.125, 0.125, 7, Color(0.3, 0.26, 0.2), false)


# ======================================================================================
#  Farmsteads: the Hallenhaus, a barn and stable, a cart shed
# ======================================================================================

const STONE_BLUE := Color(0.50, 0.52, 0.54)
const BOARD_TAR := Color(0.16, 0.15, 0.14)

## A pitched roof over walls x 0..w, z 0..-l (plates at y = ye), `pitch` degrees, overhanging the eaves by `oh` and the
## gables by `verge`. `hip` (0..1) is the share of the roof's rise each end is hipped (a Krüppelwalm, about 0.38; 0 a
## plain gable), at `hip_pitch` degrees. Draws the pantile planes over boarded undersides, the ridge and hip tiles, white
## fascias, gutters and downpipes, white verge boards; returns {t, top0, ridge, yk (the gables' top), x0 (where a gable's
## top starts across it), zr (how far in from each gable the ridge ends; negative: past it), eave}.
static func _farm_roof(pk: PropKit, kit: Dictionary, w: float, l: float, ye: float, pitch: float, hip: float, hip_pitch: float, oh: float,
		verge: float, col := PANTILE_RED, trim := WHITE_TRIM, downpipes := true) -> Dictionary:
	var t: float = tan(deg_to_rad(pitch))
	var half: float = w * 0.5
	var top0: float = ye + 0.1
	var ridge: float = top0 + t * half
	var eave: float = top0 - t * oh
	var has_hip: bool = hip > 0.01
	var yk: float = ye + (1.0 - hip) * t * half if has_hip else ridge - 0.1
	var x0: float = (yk - ye) / t
	var tb: float = tan(deg_to_rad(hip_pitch))
	var zr: float = (ridge - (yk + 0.1)) / tb if has_hip else -verge
	var yh: float = yk + 0.1 - tb * verge if has_hip else ridge
	var xc: float = (yh - top0) / t if has_hip else half
	var nl: Vector3 = Vector3(-t, 1.0, 0.0).normalized()
	var nr: Vector3 = Vector3(t, 1.0, 0.0).normalized()
	var under := Color(0.42, 0.31, 0.22)
	var left: Array = [Vector3(-oh, eave, verge), Vector3(-oh, eave, -l - verge)]
	var right: Array = [Vector3(w + oh, eave, -l - verge), Vector3(w + oh, eave, verge)]
	if has_hip:
		left.append_array([Vector3(xc, yh, -l - verge), Vector3(half, ridge, -l + zr), Vector3(half, ridge, -zr), Vector3(xc, yh, verge)])
		right.append_array([Vector3(w - xc, yh, verge), Vector3(half, ridge, -zr), Vector3(half, ridge, -l + zr), Vector3(w - xc, yh, -l - verge)])
	else:
		left.append_array([Vector3(half, ridge, -l - verge), Vector3(half, ridge, verge)])
		right.append_array([Vector3(half, ridge, verge), Vector3(half, ridge, -l - verge)])
	_roof_poly(pk, kit, "pantile", left, nl, Vector3(-oh, eave, verge), Vector3(0, 0, -1), col, "lapboards", under)
	_roof_poly(pk, kit, "pantile", right, nr, Vector3(w + oh, eave, -l - verge), Vector3(0, 0, 1), col, "lapboards", under)
	var ridge_col: Color = col.darkened(0.15)
	if has_hip:
		var nf: Vector3 = Vector3(0.0, 1.0, tb).normalized()
		var nb: Vector3 = Vector3(0.0, 1.0, -tb).normalized()
		_roof_poly(pk, kit, "pantile", [Vector3(xc, yh, verge), Vector3(w - xc, yh, verge), Vector3(half, ridge, -zr)], nf, Vector3(xc, yh, verge), Vector3(1, 0, 0), col, "lapboards", under)
		_roof_poly(pk, kit, "pantile", [Vector3(w - xc, yh, -l - verge), Vector3(xc, yh, -l - verge), Vector3(half, ridge, -l + zr)], nb, Vector3(w - xc, yh, -l - verge),
				Vector3(-1, 0, 0), col, "lapboards", under)
		# Hip tiles down the four hips.
		for e in [[Vector3(xc, yh, verge), Vector3(half, ridge, -zr)], [Vector3(w - xc, yh, verge), Vector3(half, ridge, -zr)],
				[Vector3(xc, yh, -l - verge), Vector3(half, ridge, -l + zr)], [Vector3(w - xc, yh, -l - verge), Vector3(half, ridge, -l + zr)]]:
			pk.tube(kit, "matte", (e[0] as Vector3) + Vector3(0, 0.07, 0), (e[1] as Vector3) + Vector3(0, 0.07, 0), 0.12, 0.12, 6, ridge_col, true)
		# Fascia boards along the hips' eaves.
		for zz in [verge + 0.02, -l - verge - 0.02]:
			pk.beam(kit, "painted", Vector3(xc - 0.05, yh - 0.1, zz), Vector3(w - xc + 0.05, yh - 0.1, zz), 0.04, 0.22, trim, Vector3.BACK, uvk)
	pk.tube(kit, "matte", Vector3(half, ridge + 0.07, -zr + 0.05), Vector3(half, ridge + 0.07, -l + zr - 0.05), 0.13, 0.13, 6, ridge_col, true)
	# Fascias and gutters along the eaves, downpipes at the corners.
	for side in [-1.0, 1.0]:
		var ex: float = -oh if side < 0.0 else w + oh
		pk.beam(kit, "painted", Vector3(ex + side * 0.02, eave - 0.1, verge + 0.02), Vector3(ex + side * 0.02, eave - 0.1, -l - verge - 0.02), 0.04, 0.24, trim, Vector3.RIGHT, uvk)
		var gx: float = ex + side * 0.13
		pk.tube(kit, "metal", Vector3(gx, eave - 0.18, verge), Vector3(gx, eave - 0.18, -l - verge), 0.075, 0.075, 6, Color(0.55, 0.57, 0.55), true)
		if downpipes:
			for zz2 in [verge - 0.3, -l - verge + 0.3]:
				var wx: float = 0.0 if side < 0.0 else w
				pk.tube(kit, "metal", Vector3(gx, eave - 0.18, zz2), Vector3(wx + side * 0.12, eave - 0.5, zz2), 0.045, 0.045, 6, Color(0.55, 0.57, 0.55), false)
				pk.tube(kit, "metal", Vector3(wx + side * 0.12, eave - 0.5, zz2), Vector3(wx + side * 0.12, 0.15, zz2), 0.045, 0.045, 6, Color(0.55, 0.57, 0.55), true)
	# Verge boards along the gables' rakes, 3cm over the tiles' plane.
	for g in [verge + 0.025, -l - verge - 0.025]:
		var gz: float = g
		for side2 in [-1.0, 1.0]:
			var a := Vector3(-oh - 0.03 if side2 < 0.0 else w + oh + 0.03, eave - 0.02, gz)
			var b := Vector3(xc if side2 < 0.0 else w - xc, yh - 0.02, gz)
			if not has_hip:
				b = Vector3(half, ridge, gz)
			var mid_up: Vector3 = Vector3(0, 0.03, 0)
			pk.beam(kit, "painted", a + mid_up - Vector3(0, 0.12, 0), b + mid_up - Vector3(0, 0.12, 0), 0.04, 0.26, trim, Vector3(0, 0, 1), uvk)
	return {"t": t, "top0": top0, "ridge": ridge, "yk": yk, "x0": x0, "zr": zr, "eave": eave, "half": half}


## The roof's top surface's height at x (from the left wall) on a _farm_roof's planes.
static func _roof_y(r: Dictionary, w: float, x: float) -> float:
	var xx: float = minf(x, w - x)
	return float(r["top0"]) + float(r["t"]) * xx


## A shed dormer on the left (side -1) or right (+1) slope of a _farm_roof over a w wide house: its front `x_in` in from
## the wall line, `dw` wide, centred at z; boarded white front with a window, slate-grey cheeks, a pantile roof at 16 degrees.
static func _shed_dormer(pk: PropKit, kit: Dictionary, r: Dictionary, w: float, side: float, z: float, dw: float, x_in: float, shutter: Color) -> void:
	var t: float = r["t"]
	var top0: float = r["top0"]
	var yr: float = top0 + t * x_in
	var yf1: float = yr + 1.5
	var sd: float = tan(deg_to_rad(16.0))
	var xb: float = (yf1 + 0.06 - top0 - sd * x_in) / (t - sd)
	var yb: float = top0 + t * xb
	var X := func(x: float) -> float:
		return x if side < 0.0 else w - x
	var out := Vector3(side, 0, 0)
	var wf: Transform3D = _wf(Vector3(X.call(x_in), 0, z), out)
	# The front: boards round a window, standing on the roof (its foot 15cm under the tiles).
	_face(pk, kit, "lapboards", wf, -dw * 0.5, yr - 0.15, dw * 0.5, yf1, 0.0, WHITE_TRIM.darkened(0.06))
	_win(pk, kit, wf, 0.0, yr + 0.25, yf1 - 0.2, dw - 0.7, {"rows": 2, "frame": WHITE_TRIM, "shutter": shutter, "sill": "painted"})
	# The cheeks.
	for s in [-1.0, 1.0]:
		var zz: float = z + s * dw * 0.5
		var pa := Vector3(X.call(x_in), yr - 0.15, zz)
		var pb := Vector3(X.call(x_in), yf1, zz)
		var pc := Vector3(X.call(xb), yb - 0.02, zz)
		var n := Vector3(0, 0, s)
		pk.tri(kit, "lapboards", pa, pb, pc, n, n, n, Color(0.30, 0.32, 0.33), n, Vector2(pa.x, pa.y) * uvk, Vector2(pb.x, pb.y) * uvk, Vector2(pc.x, pc.y) * uvk)
	# Its roof, overhanging the front and the cheeks.
	var nrm: Vector3 = Vector3(side * sd, 1.0, 0.0).normalized()
	var fy: float = yf1 + 0.06 - sd * 0.3
	var pts: Array = [Vector3(X.call(x_in - 0.3), fy, z - dw * 0.5 - 0.22), Vector3(X.call(x_in - 0.3), fy, z + dw * 0.5 + 0.22),
			Vector3(X.call(xb + 0.05), yb + 0.02, z + dw * 0.5 + 0.22), Vector3(X.call(xb + 0.05), yb + 0.02, z - dw * 0.5 - 0.22)]
	_roof_poly(pk, kit, "pantile", pts, nrm, pts[0], Vector3(0, 0, 1), PANTILE_RED, "lapboards", Color(0.42, 0.31, 0.22), 0.06)
	pk.beam(kit, "painted", Vector3(X.call(x_in - 0.33), fy - 0.08, z - dw * 0.5 - 0.24), Vector3(X.call(x_in - 0.33), fy - 0.08, z + dw * 0.5 + 0.24), 0.04, 0.18, WHITE_TRIM, Vector3.RIGHT, uvk)


## A Lower Rhine Hallenhaus: see farmhouse().
static func _hallenhaus(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var w := 14.0
	var l := 26.0
	var ye := 3.6
	var pl := 0.55
	_wblock(pk, kit, "kbrick", Vector3(-0.06, -1.6, -l - 0.06), Vector3(w + 0.06, pl, 0.06), TAR, true)
	var r: Dictionary = _farm_roof(pk, kit, w, l, ye, 48.0, 0.3, 60.0, 0.55, 0.42)
	var yk: float = r["yk"]
	var x0: float = r["x0"]
	var ridge: float = r["ridge"]
	var front: Transform3D = _wf(Vector3(0, 0, 0), Vector3(0, 0, 1))
	var back: Transform3D = _wf(Vector3(w, 0, -l), Vector3(0, 0, -1))
	var left: Transform3D = _wf(Vector3(0, 0, -l), Vector3(-1, 0, 0))
	var right: Transform3D = _wf(Vector3(w, 0, 0), Vector3(1, 0, 0))
	var gable := PackedVector2Array([Vector2(0, pl), Vector2(w, pl), Vector2(w, ye), Vector2(w - x0, yk), Vector2(x0, yk), Vector2(0, ye)])
	_wall_ol(pk, kit, "kbrick", front, gable, NR_BRICK)
	_wall_ol(pk, kit, "kbrick", back, gable, NR_BRICK)
	_face(pk, kit, "kbrick", left, 0.0, pl, l, ye + 0.05, 0.0, NR_BRICK)
	_face(pk, kit, "kbrick", right, 0.0, pl, l, ye + 0.05, 0.0, NR_BRICK)
	var half: float = w * 0.5
	# --- The front gable: the barn door (Niendör) in its timber frame under a carved lintel, stable windows either side,
	# a loft hatch over it, patterns in dark brick, the owl hole at the top and the year in iron wall anchors.
	var dw := 4.0
	var dh := 4.15
	for sx in [-1.0, 1.0]:
		var px: float = half + sx * (dw * 0.5 + 0.14)
		_rect(pk, kit, "timber", front, px - 0.14, 0.0, px + 0.14, dh + 0.05, 0.0, 0.14, OAK.darkened(0.25))
	_rect(pk, kit, "timber", front, half - dw * 0.5 - 0.6, dh + 0.05, half + dw * 0.5 + 0.6, dh + 0.5, 0.0, 0.16, OAK.darkened(0.2))
	labels.append(["GOTT SEGNE DIESES HAUS  1784", front * Vector3(half, dh + 0.275, 0.17), Vector3(0, 0, 1), 0.2, Color(0.95, 0.92, 0.80), dw + 0.9])
	for sx in [-1.0, 1.0]:
		var u0: float = half if sx > 0.0 else half - dw * 0.5
		var u1: float = half + dw * 0.5 if sx > 0.0 else half
		_rect(pk, kit, "painted", front, u0 + 0.02, 0.06, u1 - 0.02, dh, 0.03, 0.065, NR_GREEN)
		# A white frame, rails and a brace on each leaf.
		for e in [[u0 + 0.02, 0.06, u0 + 0.16, dh], [u1 - 0.16, 0.06, u1 - 0.02, dh], [u0 + 0.02, dh - 0.16, u1 - 0.02, dh], [u0 + 0.02, 0.06, u1 - 0.02, 0.22],
				[u0 + 0.02, dh * 0.48, u1 - 0.02, dh * 0.48 + 0.14]]:
			_rect(pk, kit, "painted", front, e[0], e[1], e[2], e[3], 0.065, 0.09, WHITE_TRIM)
		for brace in [[Vector2(u0 + 0.1, 0.2), Vector2(u1 - 0.1, dh * 0.48)], [Vector2(u0 + 0.1, dh * 0.5 + 0.12), Vector2(u1 - 0.1, dh - 0.15)]]:
			var a: Vector2 = brace[0] if sx > 0.0 else Vector2(brace[1].x, brace[0].y)
			var b: Vector2 = brace[1] if sx > 0.0 else Vector2(brace[0].x, brace[1].y)
			for piece in _clip(_band(a, b, 0.13), _rp(u0 + 0.16, 0.22, u1 - 0.16, dh - 0.16)):
				_prism(pk, kit, "painted", front, piece, 0.065, 0.085, WHITE_TRIM, b - a)
	# A wicket door in the right leaf.
	_rect(pk, kit, "painted", front, half + 0.55, 0.22, half + 0.6, 1.95, 0.09, 0.1, NR_GREEN.darkened(0.4))
	_rect(pk, kit, "painted", front, half + 1.45, 0.22, half + 1.5, 1.95, 0.09, 0.1, NR_GREEN.darkened(0.4))
	_rect(pk, kit, "painted", front, half + 0.55, 1.95, half + 1.5, 2.0, 0.09, 0.1, NR_GREEN.darkened(0.4))
	for sx in [-1.0, 1.0]:
		_arch_window(pk, kit, front, half + sx * 4.6, 1.35, 1.0, 1.0, NR_BRICK_DARK, 0.14, 2, Color(0.14, 0.15, 0.14))
	_plank_door(pk, kit, front, half, 5.2, 1.2, 1.3, NR_GREEN, NR_BRICK_DARK, 2, 0.12)
	# Dark brick diamonds and the owl hole.
	for dd in [[half - 3.7, ye + 1.0, 0.5], [half + 3.7, ye + 1.0, 0.5], [half - 1.7, yk - 1.55, 0.42], [half + 1.7, yk - 1.55, 0.42]]:
		var c := Vector2(dd[0], dd[1])
		var s: float = dd[2]
		_prism(pk, kit, "kbrick", front, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), 0.0, 0.03, NR_BRICK_DARK, Vector2(1, 0))
		_prism(pk, kit, "kbrick", front, PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.45, 0), c + Vector2(0, s * 0.45), c + Vector2(-s * 0.45, 0)]), 0.03, 0.055,
				NR_BRICK.lightened(0.05), Vector2(1, 0))
	var oy: float = yk - 0.12
	_prism(pk, kit, "painted", front, PackedVector2Array([Vector2(half - 0.75, oy - 0.8), Vector2(half + 0.75, oy - 0.8), Vector2(half, oy)]), 0.0, 0.03, WHITE_TRIM, Vector2(1, 0))
	_prism(pk, kit, "matte", front, PackedVector2Array([Vector2(half - 0.55, oy - 0.7), Vector2(half + 0.55, oy - 0.7), Vector2(half, oy - 0.12)]), 0.03, 0.035, Color(0.04, 0.04, 0.04), Vector2(1, 0))
	labels.append(["1 7 8 4", front * Vector3(half, ye + 2.15, 0.06), Vector3(0, 0, 1), 0.5, Color(0.08, 0.08, 0.08), 2.6])
	# --- The long walls: stable windows along the barn's half, the living end's windows with shutters, the front door.
	var lintel := func(wf: Transform3D, u: float, top: float, ww: float) -> void:
		_rect(pk, kit, "kbrick", wf, u - ww * 0.5 - 0.12, top + 0.02, u + ww * 0.5 + 0.12, top + 0.26, 0.0, 0.03, NR_BRICK_DARK)
	var wopt := {"rows": 3, "frame": WHITE_TRIM, "shutter": NR_GREEN, "sill": "ashlar", "sill_col": STONE_BLUE}
	for u in [14.5, 17.5, 20.5, 23.5]:
		_arch_window(pk, kit, left, u, 1.5, 0.9, 0.9, NR_BRICK_DARK, 0.13, 2, Color(0.14, 0.15, 0.14))
	for u in [2.5, 5.5, 11.5]:
		_arch_window(pk, kit, right, u, 1.5, 0.9, 0.9, NR_BRICK_DARK, 0.13, 2, Color(0.14, 0.15, 0.14))
	_plank_door(pk, kit, right, 8.5, pl - 0.5, 1.3, 2.6, NR_GREEN, NR_BRICK_DARK, 1, 0.15)
	for u in [2.2, 4.8, 8.4, 11.0]:
		_win(pk, kit, left, u, 1.05, 2.55, 1.1, wopt)
		lintel.call(left, u, 2.55, 1.1)
	for u in [15.2, 21.4, 24.0]:
		_win(pk, kit, right, u, 1.05, 2.55, 1.1, wopt)
		lintel.call(right, u, 2.55, 1.1)
	_door(pk, kit, right, 18.2, pl + 0.15, 1.05, 2.15, NR_GREEN, "kbrick", NR_BRICK_DARK, 0.0, 0.4, true)
	# --- The back gable (the living end): two floors of windows and an attic one.
	for u in [2.4, 5.0, 9.0, 11.6]:
		_win(pk, kit, back, u, 1.05, 2.55, 1.1, wopt)
		lintel.call(back, u, 2.55, 1.1)
	for u in [4.6, 9.4]:
		_win(pk, kit, back, u, 4.3, 5.6, 0.95, wopt)
		lintel.call(back, u, 5.6, 0.95)
	_win(pk, kit, back, half, 6.4, 7.2, 0.7, {"rows": 2, "frame": WHITE_TRIM, "sill": "ashlar", "sill_col": STONE_BLUE})
	for dd2 in [[half - 3.1, ye + 0.5, 0.35], [half + 3.1, ye + 0.5, 0.35]]:
		var c2 := Vector2(dd2[0], dd2[1])
		var s2: float = dd2[2]
		_prism(pk, kit, "kbrick", back, PackedVector2Array([c2 + Vector2(0, -s2), c2 + Vector2(s2, 0), c2 + Vector2(0, s2), c2 + Vector2(-s2, 0)]), 0.0, 0.03, NR_BRICK_DARK, Vector2(1, 0))
	# --- Dormers over the living end, chimneys on the ridge.
	for zd in [-17.4, -22.6]:
		_shed_dormer(pk, kit, r, w, -1.0, zd, 2.3, 1.25, NR_GREEN)
		_shed_dormer(pk, kit, r, w, 1.0, zd, 2.3, 1.25, NR_GREEN)
	_chimney(pk, kit, Transform3D.IDENTITY, half, -15.0, ridge - 1.2, ridge + 1.3)
	_chimney(pk, kit, Transform3D.IDENTITY, half, -21.5, ridge - 1.2, ridge + 1.1)


## Farm buildings of the Lower Rhine, red-brown brick under red pantiles (see the header for the frames).
static func farmhouse(pk: PropKit, kit: Dictionary, labels: Array, variant := 0) -> void:
	match variant:
		1:
			_barn(pk, kit, labels)
		2:
			_cart_shed(pk, kit, labels)
		_:
			_hallenhaus(pk, kit, labels)


## A brick barn and stable: x 0..11, z 0..-20, plain gables under pantiles (ridge 9.7m), the barn door in the front gable
## (+z) with a loft door over it and ventilation diamonds, stable windows and doors along the right (+x) side.
static func _barn(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
	var w := 11.0
	var l := 20.0
	var ye := 4.4
	var pl := 0.45
	_wblock(pk, kit, "kbrick", Vector3(-0.06, -1.6, -l - 0.06), Vector3(w + 0.06, pl, 0.06), TAR, true)
	var r: Dictionary = _farm_roof(pk, kit, w, l, ye, 45.0, 0.0, 60.0, 0.45, 0.35, PANTILE_RED.darkened(0.06))
	var ridge: float = r["ridge"]
	var half: float = w * 0.5
	var front: Transform3D = _wf(Vector3(0, 0, 0), Vector3(0, 0, 1))
	var back: Transform3D = _wf(Vector3(w, 0, -l), Vector3(0, 0, -1))
	var left: Transform3D = _wf(Vector3(0, 0, -l), Vector3(-1, 0, 0))
	var right: Transform3D = _wf(Vector3(w, 0, 0), Vector3(1, 0, 0))
	var gable := PackedVector2Array([Vector2(0, pl), Vector2(w, pl), Vector2(w, ye), Vector2(half, ridge - 0.1), Vector2(0, ye)])
	_wall_ol(pk, kit, "kbrick", front, gable, NR_BRICK)
	_wall_ol(pk, kit, "kbrick", back, gable, NR_BRICK)
	_face(pk, kit, "kbrick", left, 0.0, pl, l, ye + 0.05, 0.0, NR_BRICK)
	_face(pk, kit, "kbrick", right, 0.0, pl, l, ye + 0.05, 0.0, NR_BRICK)
	_plank_door(pk, kit, front, half, 0.0, 3.6, 3.9, NR_GREEN, NR_BRICK_DARK, 2, 0.35)
	_plank_door(pk, kit, front, half, 5.0, 1.3, 1.5, NR_GREEN, NR_BRICK_DARK, 2, 0.12)
	# The hoist beam over the loft door.
	pk.beam(kit, "timber", front * Vector3(half, 6.85, -0.3), front * Vector3(half, 6.85, 0.9), 0.22, 0.22, OAK.darkened(0.3), Vector3.UP, uvk)
	# Ventilation: diamonds of open brickwork (dark holes in a lighter frame).
	for vx in [-3.0, 3.0]:
		for vy in [5.4, 6.3]:
			var c := Vector2(half + vx * (1.0 if vy < 6.0 else 0.6), vy)
			for dk in [[0.32, 0.0, 0.03, NR_BRICK_DARK], [0.16, 0.03, 0.035, Color(0.05, 0.04, 0.04)]]:
				var s: float = dk[0]
				_prism(pk, kit, "kbrick", front, PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), dk[1], dk[2], dk[3], Vector2(1, 0))
	for u in [1.6, 4.0, 9.0, 11.4, 16.4, 18.6]:
		_arch_window(pk, kit, right, u, 1.6, 0.9, 0.85, NR_BRICK_DARK, 0.13, 2, Color(0.14, 0.15, 0.14))
	_plank_door(pk, kit, right, 6.5, pl - 0.4, 1.3, 2.5, NR_GREEN, NR_BRICK_DARK, 1, 0.15)
	_plank_door(pk, kit, right, 13.9, pl - 0.4, 1.3, 2.5, NR_GREEN, NR_BRICK_DARK, 1, 0.15)
	for u in [4.0, 10.0, 16.0]:
		_arch_window(pk, kit, left, u, 1.8, 0.9, 0.85, NR_BRICK_DARK, 0.13, 2, Color(0.14, 0.15, 0.14))
	_plank_door(pk, kit, back, half, pl - 0.4, 1.3, 2.4, NR_GREEN, NR_BRICK_DARK, 1, 0.15)
	_arch_window(pk, kit, back, half, 5.5, 0.9, 1.0, NR_BRICK_DARK, 0.0, 2, Color(0.14, 0.15, 0.14))


## A cart shed (Remise): x 0..12 along its open front (+z), 7 deep, a timber frame of posts on stone pads with knee braces
## to the eave beam, boarded back and end walls (black-tarred boards), a pantile roof (ridge 6.0m along x). Clear height
## under the front beam 3.3m between the posts at x 0, 4, 8, 12: room for a tractor or a wagon in each bay.
static func _cart_shed(pk: PropKit, kit: Dictionary, _labels: Array) -> void:
	var w := 12.0
	var d := 7.0
	var ye := 3.6
	# The roof turned so its ridge runs along x: build it in a frame rotated a quarter turn (its x across our z).
	var rf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w, 0, 0))
	var saved: Transform3D = pk.xf
	pk.set_frame(saved * rf)
	var r: Dictionary = _farm_roof(pk, kit, d, w, ye, 38.0, 0.0, 60.0, 0.45, 0.35, PANTILE_RED.darkened(0.1), WHITE_TRIM, false)
	pk.set_frame(saved)
	var ridge: float = r["ridge"]
	var beam_col: Color = OAK.darkened(0.3)
	# The boarded back wall and end walls with their gables.
	wall(pk, kit, "battens", Vector3(w, 0, -d), Vector3(0, 0, -d), -0.3, ye + 0.05, BOARD_TAR, Vector3(0, 0, -1))
	wall(pk, kit, "battens", Vector3(0, 0, -d), Vector3(w, 0, -d), -0.3, ye + 0.05, BOARD_TAR.lightened(0.05), Vector3(0, 0, 1))
	for ex in [0.0, w]:
		var o: float = -1.0 if ex == 0.0 else 1.0
		var ol := PackedVector2Array([Vector2(0, -0.3), Vector2(d, -0.3), Vector2(d, ye), Vector2(d * 0.5, ridge - 0.12), Vector2(0, ye)])
		var wf_out: Transform3D = _wf(Vector3(ex, 0, -d) if o < 0.0 else Vector3(ex, 0, 0), Vector3(o, 0, 0))
		var wf_in: Transform3D = _wf(Vector3(ex, 0, 0) if o < 0.0 else Vector3(ex, 0, -d), Vector3(-o, 0, 0))
		_wall_ol(pk, kit, "battens", wf_out, ol, BOARD_TAR)
		_wall_ol(pk, kit, "battens", wf_in, ol, BOARD_TAR.lightened(0.05), 0.0)
	# Posts on stone pads along the front, the eave beam on them, knee braces, tie beams back to the wall.
	for k in range(4):
		var x: float = float(k) * 4.0
		x = clampf(x, 0.12, w - 0.12)
		pk.block(kit, "ashlar", Vector3(x - 0.25, -0.3, -0.25), Vector3(x + 0.25, 0.2, 0.25), STONE_BLUE, uvk)
		pk.beam(kit, "timber", Vector3(x, 0.2, 0.0), Vector3(x, ye - 0.27, 0.0), 0.2, 0.2, beam_col, Vector3.RIGHT, uvk)
		for s in [-1.0, 1.0]:
			if (k == 0 and s < 0.0) or (k == 3 and s > 0.0):
				continue
			pk.beam(kit, "timber", Vector3(x, ye - 1.3, 0.0), Vector3(x + s * 1.05, ye - 0.3, 0.0), 0.12, 0.12, beam_col, Vector3.BACK, uvk)
		pk.beam(kit, "timber", Vector3(x, ye - 0.15, 0.08), Vector3(x, ye - 0.15, -d + 0.05), 0.16, 0.22, beam_col, Vector3.UP, uvk)
		pk.beam(kit, "timber", Vector3(x, ye - 1.0, -0.12), Vector3(x, ye - 0.3, -1.0), 0.1, 0.1, beam_col, Vector3.RIGHT, uvk)
	pk.beam(kit, "timber", Vector3(-0.2, ye - 0.14, 0.0), Vector3(w + 0.2, ye - 0.14, 0.0), 0.26, 0.26, beam_col, Vector3.UP, uvk)
	# A king post on each tie beam to the ridge purlin, which runs under the ridge.
	for k in range(4):
		var x2: float = clampf(float(k) * 4.0, 0.12, w - 0.12)
		pk.beam(kit, "timber", Vector3(x2, ye - 0.04, -d * 0.5), Vector3(x2, ridge - 0.3, -d * 0.5), 0.14, 0.14, beam_col, Vector3.RIGHT, uvk)
	pk.beam(kit, "timber", Vector3(-0.3, ridge - 0.38, -d * 0.5), Vector3(w + 0.3, ridge - 0.38, -d * 0.5), 0.16, 0.16, beam_col, Vector3.UP, uvk)
	# A stack of firewood against the left end wall inside.
	for row in range(4):
		for k in range(9):
			var y: float = 0.13 + float(row) * 0.23
			var z: float = -d + 0.6 + float(k) * 0.24 + (0.12 if row % 2 == 1 else 0.0)
			pk.tube(kit, "timber", Vector3(0.12, y, z), Vector3(1.05, y, z), 0.11, 0.11, 6, OAK.lerp(WEATHERED, 0.3).darkened(0.1 * float((k + row) % 3)), true, uvk)


# ======================================================================================
#  Farm things: the shepherd's cart, silage bales, fences, a gate, a tractor, a hay wagon
# ======================================================================================

const IRON := Color(0.13, 0.12, 0.12)
const GALVANISED := Color(0.66, 0.68, 0.67)
const RUBBER := Color(0.07, 0.07, 0.07)
const CART_BLUE := Color(0.24, 0.37, 0.46)


## A spoked wheel with an iron tyre, its axle along x through `c`: `r` the outer radius, `n` spokes, `w` the tyre's width.
static func _spoked_wheel(pk: PropKit, kit: Dictionary, c: Vector3, r: float, n: int, w: float, wood: Color) -> void:
	var ax := Basis(Vector3.BACK, -PI * 0.5)
	pk.tyre(kit, "steel", c, r - 0.035, r, w, 22, IRON, ax)
	pk.tyre(kit, "timber", c, r - 0.13, r - 0.03, w * 0.86, 22, wood, ax)
	pk.tube(kit, "timber", c - Vector3(w * 0.9, 0, 0), c + Vector3(w * 0.9, 0, 0), r * 0.16, r * 0.16, 10, wood.darkened(0.15), true, uvk)
	pk.tube(kit, "steel", c - Vector3(w * 1.15, 0, 0), c + Vector3(w * 1.15, 0, 0), r * 0.07, r * 0.07, 8, IRON, true)
	for k in range(n):
		var a: float = TAU * float(k) / float(n)
		var d := Vector3(0, cos(a), sin(a))
		pk.beam(kit, "timber", c + d * r * 0.14, c + d * (r - 0.11), 0.045, 0.06, wood, Vector3.RIGHT, uvk)


## The Lower Rhine shepherd's cart (Schäferkarren): see the header. About 3k triangles.
static func shepherd_cart(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hx := 1.0
	var z0 := -2.1
	var z1 := 2.1
	var fl := 1.25
	var wt := 2.85
	var rise := 0.42
	var wood := Color(0.40, 0.30, 0.20)
	# Chassis: two beams, cross members, the rear axle bed and the front turntable.
	for sx in [-0.62, 0.62]:
		pk.beam(kit, "timber", Vector3(sx, fl - 0.12, z0 - 0.1), Vector3(sx, fl - 0.12, z1 + 0.05), 0.14, 0.2, wood.darkened(0.3), Vector3.RIGHT, uvk)
	for zz in [z0 + 0.1, -0.6, 0.6, z1 - 0.1]:
		pk.beam(kit, "timber", Vector3(-0.95, fl - 0.08, zz), Vector3(0.95, fl - 0.08, zz), 0.14, 0.12, wood.darkened(0.3), Vector3.BACK, uvk)
	pk.beam(kit, "steel", Vector3(-0.98, 0.58, 1.3), Vector3(0.98, 0.58, 1.3), 0.08, 0.08, IRON, Vector3.UP)
	pk.block(kit, "timber", Vector3(-0.7, 0.62, 1.15), Vector3(0.7, fl - 0.22, 1.45), wood.darkened(0.25), uvk)
	pk.beam(kit, "steel", Vector3(-0.84, 0.46, -1.3), Vector3(0.84, 0.46, -1.3), 0.08, 0.08, IRON, Vector3.UP)
	pk.lathe(kit, "steel", Vector3(0, 0.52, -1.3), [Vector2(0.001, 0.0), Vector2(0.55, 0.0), Vector2(0.55, 0.08), Vector2(0.001, 0.08)], 14, IRON, true)
	pk.block(kit, "timber", Vector3(-0.6, 0.6, -1.45), Vector3(0.6, fl - 0.22, -1.15), wood.darkened(0.25), uvk)
	_spoked_wheel(pk, kit, Vector3(-0.92, 0.58, 1.3), 0.58, 12, 0.08, wood)
	_spoked_wheel(pk, kit, Vector3(0.92, 0.58, 1.3), 0.58, 12, 0.08, wood)
	_spoked_wheel(pk, kit, Vector3(-0.78, 0.46, -1.3), 0.46, 10, 0.07, wood)
	_spoked_wheel(pk, kit, Vector3(0.78, 0.46, -1.3), 0.46, 10, 0.07, wood)
	# The drawbar, propped on a leg, its ring at the end.
	pk.beam(kit, "timber", Vector3(0, 0.46, -1.3), Vector3(0, 0.42, -3.35), 0.12, 0.12, wood.darkened(0.2), Vector3.UP, uvk)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "timber", Vector3(sx * 0.7, 0.46, -1.3), Vector3(0, 0.44, -2.4), 0.08, 0.08, wood.darkened(0.2), Vector3.UP, uvk)
	pk.tyre(kit, "steel", Vector3(0, 0.42, -3.47), 0.07, 0.11, 0.03, 10, IRON, Basis(Vector3.RIGHT, PI * 0.5))
	pk.beam(kit, "timber", Vector3(0, 0.42, -2.9), Vector3(0, -0.05, -2.75), 0.07, 0.07, wood.darkened(0.25), Vector3.RIGHT, uvk)
	# The body: board walls, the floor's edge, end walls under the barrel roof.
	var col := CART_BLUE
	wall(pk, kit, "battens", Vector3(-hx, 0, z1), Vector3(-hx, 0, z0), fl, wt, col, Vector3(-1, 0, 0))
	wall(pk, kit, "battens", Vector3(hx, 0, z0), Vector3(hx, 0, z1), fl, wt, col, Vector3(1, 0, 0))
	var end_ol := PackedVector2Array([Vector2(-hx, fl), Vector2(hx, fl), Vector2(hx, wt)])
	var na := 8
	for k in range(1, na):
		var a: float = PI * float(k) / float(na)
		end_ol.append(Vector2(cos(a) * hx, wt + sin(a) * rise))
	end_ol.append(Vector2(-hx, wt))
	_wall_ol(pk, kit, "battens", _wf(Vector3(0, 0, z1), Vector3(0, 0, 1)), end_ol, col)
	var back_ol := PackedVector2Array()
	for p in end_ol:
		back_ol.append(Vector2(-p.x, p.y))
	back_ol.reverse()
	_wall_ol(pk, kit, "battens", _wf(Vector3(0, 0, z0), Vector3(0, 0, -1)), back_ol, col)
	pk.block(kit, "painted", Vector3(-hx - 0.04, fl - 0.12, z0 - 0.04), Vector3(hx + 0.04, fl + 0.06, z1 + 0.04), col.darkened(0.35), uvk)
	# Corner posts.
	for c in [Vector2(-hx, z0), Vector2(hx, z0), Vector2(-hx, z1), Vector2(hx, z1)]:
		pk.block(kit, "painted", Vector3(c.x - 0.05, fl, c.y - 0.05), Vector3(c.x + 0.05, wt + 0.02, c.y + 0.05), col.darkened(0.25), uvk)
	# The barrel roof in corrugated iron (ribs over the top), its underside, overhanging the sides and the ends.
	var rx: float = hx + 0.14
	var rr: float = rise + 0.06
	var pts: Array = []
	for k in range(na + 1):
		var a: float = PI * float(k) / float(na)
		pts.append(Vector2(cos(a) * rx, wt + 0.03 + sin(a) * rr))
	var arc := 0.0
	var ze0: float = z0 - 0.3
	var ze1: float = z1 + 0.3
	for k in range(na):
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[k + 1]
		var seg: float = p0.distance_to(p1)
		var nm: Vector2 = Vector2(p0.x + p1.x, p0.y + p1.y - 2.0 * (wt + 0.03)).normalized()
		var n3 := Vector3(nm.x, nm.y, 0)
		pk.quad(kit, "iron", [Vector3(p0.x, p0.y, ze0), Vector3(p0.x, p0.y, ze1), Vector3(p1.x, p1.y, ze1), Vector3(p1.x, p1.y, ze0)], n3, Color(0.52, 0.52, 0.50),
				[Vector2(ze0, arc) * uvk, Vector2(ze1, arc) * uvk, Vector2(ze1, arc + seg) * uvk, Vector2(ze0, arc + seg) * uvk])
		var dn := Vector3(0, -0.035, 0)
		pk.quad(kit, "lapboards", [Vector3(p0.x, p0.y, ze0) + dn, Vector3(p1.x, p1.y, ze0) + dn, Vector3(p1.x, p1.y, ze1) + dn, Vector3(p0.x, p0.y, ze1) + dn], -n3,
				wood.darkened(0.3), [Vector2(ze0, arc) * uvk, Vector2(ze0, arc + seg) * uvk, Vector2(ze1, arc + seg) * uvk, Vector2(ze1, arc) * uvk])
		arc += seg
	# The door at the back, a platform and a ladder down; windows with shutters in the sides; a name board.
	var back_wf: Transform3D = _wf(Vector3(0, 0, z1), Vector3(0, 0, 1))
	_rect(pk, kit, "painted", back_wf, -0.4, fl + 0.05, 0.4, fl + 1.8, 0.0, 0.035, col.darkened(0.2))
	_rect(pk, kit, "painted", back_wf, -0.46, fl + 1.8, 0.46, fl + 1.88, 0.0, 0.05, WHITE_TRIM)
	for sx in [-0.46, 0.4]:
		_rect(pk, kit, "painted", back_wf, sx, fl + 0.05, sx + 0.06, fl + 1.8, 0.0, 0.05, WHITE_TRIM)
	_face(pk, kit, "pane", back_wf, -0.22, fl + 1.15, 0.22, fl + 1.6, 0.06, GLASS)
	pk.tube(kit, "metal", back_wf * Vector3(0.28, fl + 0.95, 0.04), back_wf * Vector3(0.28, fl + 0.95, 0.11), 0.025, 0.03, 6, Color(0.7, 0.6, 0.3), true)
	pk.block(kit, "timber", Vector3(-0.6, fl - 0.1, z1 + 0.06), Vector3(0.6, fl - 0.02, z1 + 0.62), wood, uvk)
	for k in range(3):
		var y: float = fl - 0.38 - 0.3 * float(k)
		pk.block(kit, "timber", Vector3(-0.45, y - 0.04, z1 + 0.62 + 0.13 * float(k + 1)), Vector3(0.45, y, z1 + 0.62 + 0.13 * float(k + 1) + 0.24), wood, uvk)
	for sx in [-0.5, 0.5]:
		pk.beam(kit, "timber", Vector3(sx, fl - 0.06, z1 + 0.62), Vector3(sx, -0.05, z1 + 1.08), 0.06, 0.12, wood.darkened(0.2), Vector3.RIGHT, uvk)
	for sd in [-1.0, 1.0]:
		var wf: Transform3D = _wf(Vector3(sd * hx, 0, 0), Vector3(sd, 0, 0))
		_win(pk, kit, wf, -0.5 * sd, fl + 0.75, fl + 1.3, 0.62, {"rows": 2, "frame": WHITE_TRIM, "shutter": WHITE_TRIM.darkened(0.08), "sill": "painted"})
	_board(pk, kit, labels, _wf(Vector3(hx, 0, 0), Vector3(1, 0, 0)), 0.55, fl + 0.35, 1.7, 0.28, "SCHÄFEREI TER HOVEN", WHITE_TRIM, Color(0.12, 0.14, 0.16))
	# The stove pipe through the roof with its rain cap.
	var sp := Vector3(0.48, 0.0, -1.35)
	var ry: float = wt + 0.03 + sqrt(maxf(1.0 - pow(sp.x / rx, 2.0), 0.0)) * rr
	pk.tube(kit, "steel", Vector3(sp.x, ry - 0.2, sp.z), Vector3(sp.x, ry + 0.95, sp.z), 0.065, 0.065, 8, Color(0.16, 0.16, 0.16), true)
	pk.lathe(kit, "steel", Vector3(sp.x, ry + 0.95, sp.z), [Vector2(0.001, 0.04), Vector2(0.17, 0.04), Vector2(0.001, 0.2)], 8, Color(0.16, 0.16, 0.16), true)
	pk.lathe(kit, "steel", Vector3(sp.x, ry - 0.02, sp.z), [Vector2(0.15, 0.0), Vector2(0.065, 0.08)], 8, Color(0.16, 0.16, 0.16), true)


## `n` round silage bales (1.25m across, 1.2m long, in white or green film) from the origin along +x: a row lying on
## their sides (axes along z), the rest stacked in the grooves on top. Returns the footprint (x, z) in life metres.
static func silage_bales(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, n: int) -> Rect2:
	var r := 0.62
	var w := 1.2
	var film: Color = [Color(0.92, 0.93, 0.92), Color(0.46, 0.60, 0.40), Color(0.10, 0.10, 0.10), Color(0.92, 0.93, 0.92)][rng.randi() % 4]
	var bottom: int = maxi(1, int(ceil(float(n + 1) * 0.5)))
	var top: int = mini(n - bottom, bottom - 1)
	var spots: Array = []
	for i in range(bottom):
		spots.append(Vector3(r + float(i) * (2.0 * r + 0.03), r - 0.03, 0.0))
	for i in range(top):
		spots.append(Vector3(2.0 * r + 0.015 + float(i) * (2.0 * r + 0.03), r - 0.03 + 2.0 * r * 0.866, 0.0))
	var ax := Basis(Vector3.RIGHT, PI * 0.5)
	for c in spots:
		var cc: Vector3 = c + Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.12, 0.12))
		var tint: Color = film.darkened(rng.randf_range(0.0, 0.08)) if film.v > 0.5 else film.lightened(rng.randf_range(0.0, 0.05))
		var e := 0.13
		var prof: Array = [Vector2(0.001, -w * 0.5), Vector2(r - e, -w * 0.5), Vector2(r - e * 0.3, -w * 0.5 + e * 0.3), Vector2(r, -w * 0.5 + e),
				Vector2(r + 0.006, 0.0), Vector2(r, w * 0.5 - e), Vector2(r - e * 0.3, w * 0.5 - e * 0.3), Vector2(r - e, w * 0.5), Vector2(0.001, w * 0.5)]
		pk.lathe(kit, "wrap", cc, prof, 18, tint, false, ax.rotated(Vector3.UP, rng.randf_range(-0.06, 0.06)))
	var x1: float = float(bottom) * (2.0 * r + 0.03)
	return Rect2(Vector2(0.0, -w * 0.5 - 0.15), Vector2(x1, w + 0.3))


## A timber post-and-rail paddock fence along `points` (life metres in the kit's frame, their y the ground under each):
## posts at every point and every 2.4m between, three half-round rails on the posts' outside (+right of travel).
static func paddock_fence(pk: PropKit, kit: Dictionary, points: PackedVector3Array) -> void:
	var post_col := Color(0.42, 0.36, 0.29)
	var rail_col := Color(0.50, 0.44, 0.36)
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var length: float = flat.length()
		if length < 0.05:
			continue
		var dir: Vector3 = flat / length
		var right := Vector3(-dir.z, 0.0, dir.x)
		var n: int = maxi(1, int(ceil(length / 2.4)))
		for k in range(n + 1):
			if k == 0 and i > 0:
				continue
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			pk.block(kit, "timber", Vector3(p.x - 0.06, p.y - 0.6, p.z - 0.06), Vector3(p.x + 0.06, p.y + 1.2, p.z + 0.06), post_col.darkened(0.06 * float(k % 3)), uvk)
			# A bevelled top sheds the rain.
			pk.tube(kit, "timber", Vector3(p.x, p.y + 1.2, p.z), Vector3(p.x, p.y + 1.26, p.z), 0.085, 0.02, 4, post_col, true)
		for h in [0.38, 0.74, 1.08]:
			var o: Vector3 = right * 0.1 + Vector3(0, h, 0)
			pk.beam(kit, "timber", a + o - dir * 0.08, b + o + dir * 0.08, 0.05, 0.1, rail_col, right, uvk)


## A galvanised five-bar field gate, 4m, hung on two timber posts at x 0 and 4.3 (posts 1.6m high), closed along x.
static func field_gate(pk: PropKit, kit: Dictionary) -> void:
	var post_col := Color(0.40, 0.34, 0.27)
	for px in [0.0, 4.3]:
		pk.block(kit, "timber", Vector3(px - 0.1, -0.8, -0.1), Vector3(px + 0.1, 1.55, 0.1), post_col, uvk)
		pk.tube(kit, "timber", Vector3(px, 1.55, 0), Vector3(px, 1.62, 0), 0.14, 0.03, 4, post_col, true)
	var x0 := 0.17
	var x1 := 4.13
	var y0 := 0.14
	var y1 := 1.22
	var r := 0.024
	pk.tube(kit, "metal", Vector3(x0, y0, 0), Vector3(x0, y1 + 0.02, 0), 0.032, 0.032, 8, GALVANISED, true)
	pk.tube(kit, "metal", Vector3(x1, y0, 0), Vector3(x1, y1, 0), 0.028, 0.028, 8, GALVANISED, true)
	for k in range(5):
		var y: float = lerpf(y0, y1, float(k) / 4.0)
		pk.tube(kit, "metal", Vector3(x0, y, 0), Vector3(x1, y, 0), r if k > 0 and k < 4 else r * 1.3, r if k > 0 and k < 4 else r * 1.3, 8, GALVANISED, false)
	pk.tube(kit, "metal", Vector3(x0, y0, 0), Vector3(x1 - 0.05, y1 - 0.02, 0), r, r, 8, GALVANISED, false)
	for k in range(1, 4):
		var x: float = lerpf(x0, x1, float(k) / 4.0)
		pk.tube(kit, "metal", Vector3(x, y0, 0), Vector3(x, y1, 0), r * 0.8, r * 0.8, 6, GALVANISED, false)
	# Hinges and the latch.
	for y in [0.3, 1.1]:
		pk.beam(kit, "steel", Vector3(0.08, y, 0), Vector3(0.2, y, 0), 0.05, 0.05, IRON, Vector3.UP)
	pk.beam(kit, "steel", Vector3(x1 - 0.05, 1.0, 0), Vector3(4.24, 1.0, 0), 0.06, 0.03, IRON, Vector3.UP)


## Tyre lugs round a tractor tyre at `c` (axle along x): chevrons, `n` round, `w` the tread's width.
static func _lugs(pk: PropKit, kit: Dictionary, c: Vector3, r: float, w: float, n: int, h: float, col: Color) -> void:
	var ang := deg_to_rad(38.0)
	for k in range(n):
		var a: float = TAU * float(k) / float(n)
		var nrm := Vector3(0, cos(a), sin(a))
		var t := Vector3(0, -sin(a), cos(a))
		for side in [-1.0, 1.0]:
			var dir: Vector3 = (Vector3(side * cos(ang), 0, 0) + t * sin(ang)).normalized()
			var p0: Vector3 = c + nrm * (r + h * 0.3) + Vector3(side * 0.03, 0, 0)
			var length: float = (w * 0.5 - 0.04) / cos(ang)
			pk.beam(kit, "rubber", p0, p0 + dir * length, h, 0.085, col, nrm)


## A wheel for the tractor: tyre, lugs and a dished rim, its outer face toward `side` (-1 left, +1 right).
static func _tractor_wheel(pk: PropKit, kit: Dictionary, c: Vector3, r: float, w: float, side: float, rim_col: Color, n_lugs: int) -> void:
	var ax := Basis(Vector3.BACK, -PI * 0.5)
	pk.tyre(kit, "rubber", c, r * 0.64, r - 0.035, w, 22, RUBBER, ax)
	_lugs(pk, kit, c, r - 0.04, w, n_lugs, 0.055 if r > 0.7 else 0.04, RUBBER.lightened(0.04))
	var out_ax := Basis(Vector3.BACK, -PI * 0.5 * side)
	# Walked from the rim's edge in toward the hub, so the dish faces out (PropKit.lathe's normal is right of travel).
	pk.lathe(kit, "metal", c, [Vector2(r * 0.66, -w * 0.3), Vector2(r * 0.66, w * 0.3), Vector2(r * 0.58, w * 0.02), Vector2(r * 0.24, w * 0.08),
			Vector2(r * 0.18, w * 0.2), Vector2(0.001, w * 0.18)], 16, rim_col, false, out_ax)
	pk.lathe(kit, "steel", c + Vector3(side * w * 0.2, 0, 0), [Vector2(r * 0.11, 0.0), Vector2(r * 0.09, 0.07), Vector2(0.001, 0.08)], 8, Color(0.25, 0.25, 0.25), false, out_ax)


## A generic farm tractor: see the header. `variant` 0 green with grey rims, 1 red with dark rims.
static func tractor(pk: PropKit, kit: Dictionary, variant := 0) -> void:
	var body: Color = Color(0.17, 0.40, 0.19) if variant % 2 == 0 else Color(0.66, 0.11, 0.08)
	var rim: Color = Color(0.74, 0.75, 0.72) if variant % 2 == 0 else Color(0.28, 0.28, 0.30)
	var roof: Color = Color(0.92, 0.92, 0.90) if variant % 2 == 0 else Color(0.12, 0.12, 0.12)
	var dark := Color(0.14, 0.14, 0.15)
	var zr := 1.25
	var zf := -1.3
	var rr := 0.85
	var rf := 0.56
	for sx in [-1.0, 1.0]:
		_tractor_wheel(pk, kit, Vector3(sx * 0.93, rr, zr), rr, 0.55, sx, rim, 24)
		_tractor_wheel(pk, kit, Vector3(sx * 0.82, rf, zf), rf, 0.38, sx, rim, 18)
	# The frame and engine block, the front axle, the front weight.
	pk.block(kit, "steel", Vector3(-0.36, 0.5, -2.1), Vector3(0.36, 1.0, 0.6), dark, uvk)
	pk.beam(kit, "steel", Vector3(-0.66, rf, zf), Vector3(0.66, rf, zf), 0.18, 0.16, dark, Vector3.UP)
	pk.block(kit, "steel", Vector3(-0.5, 0.45, -2.62), Vector3(0.5, 1.0, -2.12), Color(0.2, 0.2, 0.21), uvk)
	for k in range(4):
		pk.block(kit, "steel", Vector3(-0.51, 0.52 + 0.12 * float(k), -2.63), Vector3(0.51, 0.55 + 0.12 * float(k), -2.11), Color(0.12, 0.12, 0.12), uvk)
	# The bonnet: a rounded section extruded along z, the grille and headlamps at its nose, vents along its sides.
	var hood := PackedVector2Array([Vector2(-0.44, 0.95), Vector2(0.44, 0.95), Vector2(0.44, 1.55), Vector2(0.38, 1.68), Vector2(0.24, 1.75), Vector2(-0.24, 1.75),
			Vector2(-0.38, 1.68), Vector2(-0.44, 1.55)])
	pk.extrude(kit, "gloss", hood, -2.08, 0.05, 0.03, body)
	pk.block(kit, "matte", Vector3(-0.36, 1.0, -2.11), Vector3(0.36, 1.6, -2.07), Color(0.08, 0.08, 0.08), uvk)
	for k in range(6):
		var y: float = 1.05 + 0.09 * float(k)
		pk.block(kit, "metal", Vector3(-0.34, y, -2.13), Vector3(0.34, y + 0.03, -2.09), Color(0.55, 0.55, 0.55), uvk)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "lamp", Vector3(sx * 0.28, 1.5, -2.06), Vector3(sx * 0.28, 1.5, -2.14), 0.07, 0.07, 10, Color(0.95, 0.95, 0.85), true)
		for k in range(5):
			pk.block(kit, "matte", Vector3(sx * 0.445 - 0.01, 1.2 + 0.07 * float(k), -1.4), Vector3(sx * 0.445 + 0.01, 1.23 + 0.07 * float(k), -0.6), Color(0.06, 0.06, 0.06), uvk)
	pk.block(kit, "plastic", Vector3(-0.22, 1.12, -2.18), Vector3(0.22, 1.24, -2.15), Color(0.92, 0.92, 0.88), uvk)
	# The cab: floor and footplate, four posts, glass all round, the roof with its overhang, beacon and work lamps.
	var c0 := -0.05
	var c1 := 1.55
	var cy0 := 1.28
	var cy1 := 2.8
	var hw := 0.66
	pk.block(kit, "steel", Vector3(-hw, cy0 - 0.14, c0), Vector3(hw, cy0, c1), dark, uvk)
	pk.block(kit, "gloss", Vector3(-hw, cy0, c0), Vector3(hw, cy0 + 0.45, c0 + 0.5), body, uvk)
	for p in [Vector2(-hw, c0), Vector2(hw, c0), Vector2(-hw, c1), Vector2(hw, c1)]:
		pk.block(kit, "matte", Vector3(p.x - 0.045, cy0, p.y - 0.045), Vector3(p.x + 0.045, cy1, p.y + 0.045), Color(0.1, 0.1, 0.1), uvk)
	var gc := Color(0.10, 0.14, 0.16)
	pk.quad(kit, "pane", [Vector3(-hw + 0.04, cy0 + 0.45, c0 - 0.01), Vector3(hw - 0.04, cy0 + 0.45, c0 - 0.01), Vector3(hw - 0.04, cy1 - 0.04, c0 - 0.01),
			Vector3(-hw + 0.04, cy1 - 0.04, c0 - 0.01)], Vector3(0, 0, -1), gc)
	pk.quad(kit, "pane", [Vector3(hw - 0.04, cy0 + 0.25, c1 + 0.01), Vector3(-hw + 0.04, cy0 + 0.25, c1 + 0.01), Vector3(-hw + 0.04, cy1 - 0.04, c1 + 0.01),
			Vector3(hw - 0.04, cy1 - 0.04, c1 + 0.01)], Vector3(0, 0, 1), gc)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hw + 0.01)
		pk.quad(kit, "pane", [Vector3(x, cy0 + 0.05, c0 + 0.04), Vector3(x, cy0 + 0.05, c1 - 0.04), Vector3(x, cy1 - 0.04, c1 - 0.04), Vector3(x, cy1 - 0.04, c0 + 0.04)],
				Vector3(sx, 0, 0), gc)
		# The door's frame and handle, the mirror on its arm.
		pk.block(kit, "matte", Vector3(x - 0.015, cy0 + 0.05, c0 + 0.62), Vector3(x + 0.015, cy1 - 0.05, c0 + 0.66), Color(0.1, 0.1, 0.1), uvk)
		pk.block(kit, "metal", Vector3(x + sx * 0.01 - 0.015, cy0 + 0.95, c0 + 1.1), Vector3(x + sx * 0.01 + 0.015, cy0 + 1.0, c0 + 1.3), Color(0.6, 0.6, 0.6), uvk)
		pk.beam(kit, "steel", Vector3(sx * hw, cy1 - 0.3, c0 + 0.02), Vector3(sx * (hw + 0.45), cy1 - 0.4, c0 - 0.1), 0.03, 0.03, dark)
		pk.block(kit, "plastic", Vector3(sx * (hw + 0.45) - 0.05, cy1 - 0.62, c0 - 0.14), Vector3(sx * (hw + 0.45) + 0.05, cy1 - 0.3, c0 - 0.08), dark, uvk)
		# The rear mudguard over the big wheel: a curved shell, and the small front ones.
		var prev := Vector3.ZERO
		for k in range(9):
			var a: float = lerpf(deg_to_rad(10.0), deg_to_rad(165.0), float(k) / 8.0)
			var p2 := Vector3(sx * 0.93, rr + cos(a - PI * 0.5) * 0.0 + sin(a) * (rr + 0.12), zr + cos(a) * (rr + 0.12))
			if k > 0:
				pk.beam(kit, "gloss", prev, p2, 0.62, 0.03, body, Vector3.RIGHT)
			prev = p2
		var fprev := Vector3.ZERO
		for k in range(6):
			var a2: float = lerpf(deg_to_rad(40.0), deg_to_rad(140.0), float(k) / 5.0)
			var p3 := Vector3(sx * 0.82, rf + sin(a2) * (rf + 0.1), zf + cos(a2) * (rf + 0.1))
			if k > 0:
				pk.beam(kit, "gloss", fprev, p3, 0.42, 0.025, body, Vector3.RIGHT)
			fprev = p3
	# The steps up on the left, the fuel tank, the exhaust and the air intake.
	for k in range(2):
		pk.block(kit, "steel", Vector3(-hw - 0.32, 0.45 + 0.4 * float(k), c0 + 0.6), Vector3(-hw - 0.02, 0.48 + 0.4 * float(k), c0 + 0.95), dark, uvk)
	pk.block(kit, "gloss", Vector3(-0.42, 0.62, -0.5), Vector3(-0.2, 0.96, 0.0), body.darkened(0.2), uvk)
	pk.tube(kit, "steel", Vector3(0.5, 1.4, -0.2), Vector3(0.5, 3.0, -0.2), 0.06, 0.06, 8, dark, true)
	pk.tube(kit, "steel", Vector3(0.5, 2.6, -0.2), Vector3(0.5, 2.95, -0.2), 0.075, 0.075, 8, Color(0.4, 0.4, 0.4), true)
	pk.tube(kit, "plastic", Vector3(-0.5, 1.5, -0.2), Vector3(-0.5, 2.5, -0.2), 0.09, 0.09, 8, dark, true)
	pk.lathe(kit, "plastic", Vector3(-0.5, 2.5, -0.2), [Vector2(0.13, 0.0), Vector2(0.13, 0.12), Vector2(0.001, 0.16)], 8, dark, true)
	# The roof: a slab overhanging all round with its underside, a beacon and two work lamps.
	pk.block(kit, "gloss", Vector3(-hw - 0.08, cy1, c0 - 0.15), Vector3(hw + 0.08, cy1 + 0.12, c1 + 0.08), roof, uvk)
	pk.lathe(kit, "lamp", Vector3(0.4, cy1 + 0.12, c1 - 0.3), [Vector2(0.08, 0.0), Vector2(0.07, 0.14), Vector2(0.001, 0.17)], 10, Color(1.0, 0.55, 0.05), true)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "lamp", Vector3(sx * 0.4 - 0.08, cy1 + 0.03, c0 - 0.18), Vector3(sx * 0.4 + 0.08, cy1 + 0.1, c0 - 0.14), Color(0.95, 0.95, 0.85), uvk)
	# The three-point hitch at the back.
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(sx * 0.3, 0.62, 1.55), Vector3(sx * 0.42, 0.5, 2.3), 0.06, 0.08, dark)
		pk.beam(kit, "steel", Vector3(sx * 0.35, 1.2, 1.5), Vector3(sx * 0.4, 0.62, 1.95), 0.04, 0.04, dark)
	pk.beam(kit, "steel", Vector3(0, 1.22, 1.58), Vector3(0, 1.0, 2.25), 0.07, 0.07, Color(0.6, 0.55, 0.15))
	pk.tube(kit, "steel", Vector3(0, 0.72, 1.55), Vector3(0, 0.72, 1.75), 0.04, 0.04, 8, Color(0.6, 0.6, 0.6), true)
	pk.block(kit, "steel", Vector3(-0.42, 0.55, 1.45), Vector3(0.42, 1.2, 1.6), dark, uvk)


## A small square bale of hay or straw for hay_bale.gdshader: UVs in metres (along on the long faces, across on the
## ends), COLOR r its weathering, g a random, b the face (0 side, 0.5 top, 1 end). `xf` places it (its length along x).
static func _small_bale(pk: PropKit, kit: Dictionary, xf: Transform3D, size: Vector3, wth: float, rnd: float) -> void:
	var h: Vector3 = size * 0.5
	for f in range(6):
		var a: int = f / 2
		var sg: float = -1.0 if f % 2 == 0 else 1.0
		var n := Vector3.ZERO
		n[a] = sg
		var u := Vector3.ZERO
		var v := Vector3.ZERO
		if a == 0:
			u = Vector3(0, 0, 1)
			v = Vector3(0, 1, 0)
		elif a == 1:
			u = Vector3(1, 0, 0)
			v = Vector3(0, 0, 1)
		else:
			u = Vector3(1, 0, 0)
			v = Vector3(0, 1, 0)
		var cu: float = absf(u.dot(h))
		var cv: float = absf(v.dot(h))
		var c: Vector3 = n * absf(n.dot(h))
		var pts: Array = [c - u * cu - v * cv, c + u * cu - v * cv, c + u * cu + v * cv, c - u * cu + v * cv]
		var face_b: float = 1.0 if a == 0 else (0.5 if a == 1 and sg > 0.0 else 0.0)
		var col := Color(wth, rnd, face_b)
		var wp: Array = []
		for p in pts:
			wp.append(xf * (p as Vector3))
		var wn: Vector3 = (xf.basis * n).normalized()
		var uvs: Array = [Vector2(-cu, -cv) * uvk, Vector2(cu, -cv) * uvk, Vector2(cu, cv) * uvk, Vector2(-cu, cv) * uvk]
		pk.quad(kit, "hay", wp, wn, col, uvs)


## A farm trailer with ladder racks front and back and a load of small bales, the drawbar toward -z: about 7.4m long
## with its drawbar, 2.4m wide, the load's top 3.0m.
static func hay_wagon(pk: PropKit, kit: Dictionary) -> void:
	var red := Color(0.62, 0.14, 0.10)
	var dark := Color(0.13, 0.13, 0.14)
	var bed_y := 1.05
	var hl := 2.8
	var hw := 1.15
	# Chassis, axles, wheels, the turntable and drawbar.
	for sx in [-0.55, 0.55]:
		pk.beam(kit, "steel", Vector3(sx, bed_y - 0.25, -hl), Vector3(sx, bed_y - 0.25, hl), 0.12, 0.2, red, Vector3.RIGHT)
	for zz in [-1.65, 1.65]:
		pk.beam(kit, "steel", Vector3(-1.0, 0.44, zz), Vector3(1.0, 0.44, zz), 0.1, 0.1, dark, Vector3.UP)
		for sx in [-1.0, 1.0]:
			var c := Vector3(sx * 0.98, 0.44, zz)
			pk.tyre(kit, "rubber", c, 0.24, 0.42, 0.26, 18, RUBBER, Basis(Vector3.BACK, -PI * 0.5))
			pk.lathe(kit, "metal", c, [Vector2(0.25, -0.1), Vector2(0.25, 0.1), Vector2(0.18, 0.06), Vector2(0.001, 0.08)], 12, red.lightened(0.1), false,
					Basis(Vector3.BACK, -PI * 0.5 * sx))
	pk.lathe(kit, "steel", Vector3(0, 0.62, -1.65), [Vector2(0.001, 0.0), Vector2(0.6, 0.0), Vector2(0.6, 0.1), Vector2(0.001, 0.1)], 14, dark, true)
	pk.beam(kit, "steel", Vector3(0, 0.5, -1.65), Vector3(0, 0.45, -4.4), 0.1, 0.1, red, Vector3.UP)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(sx * 0.75, 0.5, -1.65), Vector3(0, 0.48, -3.2), 0.07, 0.07, red, Vector3.UP)
	pk.tyre(kit, "steel", Vector3(0, 0.45, -4.5), 0.06, 0.1, 0.04, 10, dark, Basis(Vector3.RIGHT, PI * 0.5))
	# The bed: planks on the frame, low side boards.
	pk.block(kit, "timber", Vector3(-hw, bed_y - 0.1, -hl), Vector3(hw, bed_y, hl), Color(0.48, 0.38, 0.26), uvk)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "painted", Vector3(sx * hw - 0.03, bed_y - 0.12, -hl - 0.03), Vector3(sx * hw + 0.03, bed_y + 0.22, hl + 0.03), red, uvk)
	# Ladder racks at both ends.
	for zz2 in [-hl + 0.05, hl - 0.05]:
		for sx2 in [-1.0, 1.0]:
			pk.block(kit, "painted", Vector3(sx2 * (hw - 0.06) - 0.04, bed_y, zz2 - 0.04), Vector3(sx2 * (hw - 0.06) + 0.04, bed_y + 2.2, zz2 + 0.04), red, uvk)
		for k in range(6):
			var y: float = bed_y + 0.3 + 0.37 * float(k)
			pk.beam(kit, "painted", Vector3(-hw + 0.06, y, zz2), Vector3(hw - 0.06, y, zz2), 0.05, 0.05, red.darkened(0.1), Vector3.UP, uvk)
	# The load: small bales, each layer laid crosswise to the one under it, the top layer short of the ends.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var bl := 0.9
	var bw := 0.46
	var bh := 0.36
	for layer in range(5):
		var y0: float = bed_y + bh * 0.5 + bh * float(layer)
		var lz0: float = -hl + 0.15 + (0.3 if layer == 4 else 0.0)
		var lz1: float = hl - 0.15 - (0.3 if layer == 4 else 0.0)
		if layer % 2 == 0:
			# Lengthwise: rows of bales along z.
			var nx: int = int((2.0 * hw - 0.1) / bw)
			var nz: int = int((lz1 - lz0) / bl)
			for ix in range(nx):
				for iz in range(nz):
					var c2 := Vector3(-hw + 0.05 + bw * (float(ix) + 0.5), y0, lz0 + bl * (float(iz) + 0.5))
					_small_bale(pk, kit, Transform3D(Basis(Vector3.UP, PI * 0.5 + rng.randf_range(-0.03, 0.03)), c2), Vector3(bl - 0.02, bh - 0.01, bw - 0.02),
							rng.randf_range(0.0, 0.3), rng.randf())
		else:
			var nx2: int = int((2.0 * hw - 0.05) / bl)
			var nz2: int = int((lz1 - lz0) / bw)
			for ix in range(nx2):
				for iz in range(nz2):
					var c3 := Vector3(-hw + 0.08 + bl * (float(ix) + 0.5), y0, lz0 + bw * (float(iz) + 0.5))
					_small_bale(pk, kit, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)), c3), Vector3(bl - 0.02, bh - 0.01, bw - 0.02),
							rng.randf_range(0.0, 0.3), rng.randf())
	# Lights and a number plate at the back.
	for sx3 in [-1.0, 1.0]:
		pk.block(kit, "lamp", Vector3(sx3 * 0.95 - 0.1, bed_y - 0.3, hl + 0.01), Vector3(sx3 * 0.95 + 0.1, bed_y - 0.18, hl + 0.05), Color(0.9, 0.1, 0.05), uvk)


# ======================================================================================
#  Kraftwerk Weidenhoven: a coal-fired power station's main block (seen from 1-1.5km)
# ======================================================================================

## Where SteelworksKit's chimney stands in power_station's frame (life metres), and how to build it: chimney(pk, kit,
## POWER_CHIMNEY_H, 1) (concrete with red and white bands; 9m across at its foot, 200m tall) in a kit at the stage's
## PROP_SCALE. The flue duct runs into its foot's -z... its +z side at POWER_DUCT_Y.
const POWER_CHIMNEY_AT := Vector3(0.0, 0.0, -142.0)
const POWER_CHIMNEY_H := 200.0
const POWER_DUCT_Y := 28.0
## Where the two cooling towers stand (SteelworksKit.cooling_tower: 50m tall at scale 1, its basin 42.4m across). Grow
## each by POWER_TOWER_SCALE on top of PROP_SCALE (a kit made with new_kit(PROP_SCALE * POWER_TOWER_SCALE)): 130m tall,
## its basin 110m across.
const POWER_TOWERS := [Vector3(152.0, 0.0, -6.0), Vector3(152.0, 0.0, 128.0)]
const POWER_TOWER_SCALE := 2.6
## The boiler house's footprint (half width) and height, the turbine hall's and the other blocks', for the generator's
## planning: everything lies within x -345..95 and z -152..190 (life), the towers out to x 207.
const POWER_BOILER_HALF := 22.5
const POWER_BOILER_TOP := 104.0

const CLAD := Color(0.80, 0.81, 0.80)
const CLAD_BLUE := Color(0.20, 0.36, 0.58)
const CLAD_DARK := Color(0.42, 0.44, 0.45)
const FRAME_GREY := Color(0.36, 0.38, 0.39)


## A clad box between lo and hi: profiled sheet on its four walls (UVs in metres: ribs upright), a dark flat roof.
static func _clad_box(pk: PropKit, kit: Dictionary, lo: Vector3, hi: Vector3, col: Color, roof := true) -> void:
	wall(pk, kit, "cladding", Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z), lo.y, hi.y, col, Vector3(0, 0, 1), lo.x)
	wall(pk, kit, "cladding", Vector3(hi.x, 0, lo.z), Vector3(lo.x, 0, lo.z), lo.y, hi.y, col, Vector3(0, 0, -1), -hi.x)
	wall(pk, kit, "cladding", Vector3(hi.x, 0, hi.z), Vector3(hi.x, 0, lo.z), lo.y, hi.y, col, Vector3(1, 0, 0), -hi.z)
	wall(pk, kit, "cladding", Vector3(lo.x, 0, lo.z), Vector3(lo.x, 0, hi.z), lo.y, hi.y, col, Vector3(-1, 0, 0), lo.z)
	if roof:
		pk.quad(kit, "roofing", [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], Vector3.UP,
				Color(0.30, 0.31, 0.31))
		# A coping round the roof's edge, 30cm proud.
		_ring_coping(pk, kit, lo, hi, col.darkened(0.15))


static func _ring_coping(pk: PropKit, kit: Dictionary, lo: Vector3, hi: Vector3, col: Color) -> void:
	var y: float = hi.y
	var o := 0.27
	pk.block(kit, "metal", Vector3(lo.x - o, y - 0.6, lo.z - o), Vector3(hi.x + o, y + 0.5, lo.z + 0.05), col, uvk)
	pk.block(kit, "metal", Vector3(lo.x - o, y - 0.6, hi.z - 0.05), Vector3(hi.x + o, y + 0.5, hi.z + o), col, uvk)
	pk.block(kit, "metal", Vector3(lo.x - o, y - 0.6, lo.z + 0.05), Vector3(lo.x + 0.05, y + 0.5, hi.z - 0.05), col, uvk)
	pk.block(kit, "metal", Vector3(hi.x - 0.05, y - 0.6, lo.z + 0.05), Vector3(hi.x + o, y + 0.5, hi.z - 0.05), col, uvk)


## A band round a box (lo..hi in plan) from y0 to y1, standing `proud` off its walls: colour stripes, ribbon windows.
static func _wrap_band(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, y0: float, y1: float, col: Color, proud := 0.08, sides := 15) -> void:
	var p: float = proud
	if sides & 1:
		pk.block(kit, key, Vector3(lo.x - p, y0, hi.z), Vector3(hi.x + p, y1, hi.z + p), col, uvk)
	if sides & 2:
		pk.block(kit, key, Vector3(lo.x - p, y0, lo.z - p), Vector3(hi.x + p, y1, lo.z), col, uvk)
	if sides & 4:
		pk.block(kit, key, Vector3(hi.x, y0, lo.z), Vector3(hi.x + p, y1, hi.z), col, uvk)
	if sides & 8:
		pk.block(kit, key, Vector3(lo.x - p, y0, lo.z), Vector3(lo.x, y1, hi.z), col, uvk)


## Kraftwerk Weidenhoven's main block. The frame: the boiler house's middle at the origin, the turbine hall toward +z, the
## flue gas cleaning toward -z (the chimney at POWER_CHIMNEY_AT), the coal yard toward -x, the cooling towers toward +x
## (POWER_TOWERS) and the switchyard beyond the transformers (+z). About 45k triangles.
static func power_station(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var b: float = POWER_BOILER_HALF
	# --- The boiler house: clad to 92m, its steel frame open above it to the roof at 104m, stair towers at two corners.
	var lo := Vector3(-b, 0, -b)
	var hi := Vector3(b, 92.0, b)
	_clad_box(pk, kit, lo, hi, CLAD, false)
	pk.quad(kit, "roofing", [Vector3(-b, 92.0, -b), Vector3(b, 92.0, -b), Vector3(b, 92.0, b), Vector3(-b, 92.0, b)], Vector3.UP, Color(0.3, 0.31, 0.31))
	_wrap_band(pk, kit, "metal", lo, hi, 0.0, 6.0, CLAD_DARK, 0.1)
	_wrap_band(pk, kit, "metal", lo, hi, 58.0, 61.0, CLAD_BLUE, 0.1)
	_wrap_band(pk, kit, "metal", lo, hi, 88.0, 92.0, CLAD_BLUE, 0.1)
	for wy in [18.0, 32.0, 46.0, 70.0, 80.0]:
		pk.block(kit, "pane", Vector3(-b + 5.0, wy, b), Vector3(b - 5.0, wy + 1.3, b + 0.06), Color(0.12, 0.15, 0.18), uvk)
		pk.block(kit, "pane", Vector3(-b + 5.0, wy, -b - 0.06), Vector3(b - 5.0, wy + 1.3, -b), Color(0.12, 0.15, 0.18), uvk)
		# On the ends they stop short of the stair towers (an end face in a tower's wall would flicker).
		pk.block(kit, "pane", Vector3(b, wy, -b + 5.0), Vector3(b + 0.06, wy + 1.3, b - 13.5), Color(0.12, 0.15, 0.18), uvk)
		pk.block(kit, "pane", Vector3(-b - 0.06, wy, -b + 13.5), Vector3(-b, wy + 1.3, b - 5.0), Color(0.12, 0.15, 0.18), uvk)
	# The exposed frame: columns, three tiers of beams, crossed braces on each face, the roof and plant on it.
	var nb := 5
	for side in range(4):
		for k in range(nb + 1):
			var t: float = lerpf(-b, b, float(k) / float(nb))
			var p: Vector3 = [Vector3(t, 0, b), Vector3(t, 0, -b), Vector3(b, 0, t), Vector3(-b, 0, t)][side]
			# Corner columns once (on the two long faces), interior ones on every face.
			if side < 2 or (k > 0 and k < nb):
				SteelworksKit._ibeam(pk, kit, "steel", p + Vector3(0, 91.5, 0), p + Vector3(0, POWER_BOILER_TOP, 0), 0.9, 0.6, FRAME_GREY, Vector3.FORWARD)
		for y in [96.0, 100.0, POWER_BOILER_TOP - 0.4]:
			var a: Vector3 = [Vector3(-b, y, b), Vector3(-b, y, -b), Vector3(b, y, -b), Vector3(-b, y, -b)][side]
			var c: Vector3 = [Vector3(b, y, b), Vector3(b, y, -b), Vector3(b, y, b), Vector3(-b, y, b)][side]
			SteelworksKit._ibeam(pk, kit, "steel", a, c, 0.8, 0.4, FRAME_GREY)
		for k in range(nb):
			var t0: float = lerpf(-b, b, float(k) / float(nb))
			var t1: float = lerpf(-b, b, float(k + 1) / float(nb))
			var e0: Vector3 = [Vector3(t0, 0, b), Vector3(t0, 0, -b), Vector3(b, 0, t0), Vector3(-b, 0, t0)][side]
			var e1: Vector3 = [Vector3(t1, 0, b), Vector3(t1, 0, -b), Vector3(b, 0, t1), Vector3(-b, 0, t1)][side]
			pk.beam(kit, "steel", e0 + Vector3(0, 92.0, 0), e1 + Vector3(0, 100.0, 0), 0.35, 0.35, FRAME_GREY)
			pk.beam(kit, "steel", e1 + Vector3(0, 92.0, 0), e0 + Vector3(0, 100.0, 0), 0.35, 0.35, FRAME_GREY)
	# The roof 5cm over the top beams' flanges (level with them, the two flickered).
	var ry: float = POWER_BOILER_TOP + 0.05
	pk.quad(kit, "roofing", [Vector3(-b - 0.5, ry, -b - 0.5), Vector3(b + 0.5, ry, -b - 0.5), Vector3(b + 0.5, ry, b + 0.5),
			Vector3(-b - 0.5, ry, b + 0.5)], Vector3.UP, Color(0.34, 0.35, 0.35))
	pk.quad(kit, "roofing", [Vector3(-b - 0.5, ry - 0.3, -b - 0.5), Vector3(-b - 0.5, ry - 0.3, b + 0.5), Vector3(b + 0.5, ry - 0.3, b + 0.5),
			Vector3(b + 0.5, ry - 0.3, -b - 0.5)], Vector3.DOWN, Color(0.2, 0.21, 0.21))
	_ring_coping(pk, kit, Vector3(-b - 0.5, 0, -b - 0.5), Vector3(b + 0.5, POWER_BOILER_TOP, b + 0.5), FRAME_GREY)
	# Inside the open top: the boiler's headers and drum housing, seen between the columns.
	pk.block(kit, "shell", Vector3(-14.0, 92.0, -12.0), Vector3(14.0, 99.0, 12.0), Color(0.55, 0.53, 0.50), uvk)
	for k in range(4):
		var z: float = -9.0 + 6.0 * float(k)
		pk.tube(kit, "shell", Vector3(-16.0, 101.0, z), Vector3(16.0, 101.0, z), 1.0, 1.0, 10, Color(0.6, 0.58, 0.55), true)
	pk.block(kit, "cladding", Vector3(8.0, POWER_BOILER_TOP, -16.0), Vector3(18.0, POWER_BOILER_TOP + 5.0, -6.0), CLAD.darkened(0.08), uvk)
	# Stair towers against the +x face near the +z corner and the -x face near the -z corner, a glazed strip up their
	# outer faces, an aircraft warning lamp on top.
	for sx in [1.0, -1.0]:
		var tlo := Vector3(b if sx > 0.0 else -b - 7.0, 0, (b - 12.0) if sx > 0.0 else (-b + 5.0))
		var thi := Vector3(b + 7.0 if sx > 0.0 else -b, 98.0, tlo.z + 7.0)
		_clad_box(pk, kit, tlo, thi, CLAD.darkened(0.05))
		var fx: float = thi.x if sx > 0.0 else tlo.x
		var wz: float = (tlo.z + thi.z) * 0.5
		pk.block(kit, "pane", Vector3(minf(fx, fx + sx * 0.06), 6.0, wz - 1.0), Vector3(maxf(fx, fx + sx * 0.06), 94.0, wz + 1.0), Color(0.12, 0.15, 0.18), uvk)
		pk.lathe(kit, "lamp", Vector3((tlo.x + thi.x) * 0.5, 98.5, wz), [Vector2(0.001, 0.0), Vector2(0.5, 0.0), Vector2(0.4, 0.6), Vector2(0.001, 0.8)], 8, Color(0.9, 0.1, 0.05), true)
	# --- The bunker bay and the turbine hall in front of it, the name on the hall's front.
	_clad_box(pk, kit, Vector3(-b, 0, b), Vector3(b, 66.0, b + 14.0), CLAD.darkened(0.03))
	_wrap_band(pk, kit, "metal", Vector3(-b, 0, b), Vector3(b, 0, b + 14.0), 62.0, 66.0, CLAD_BLUE, 0.1, 13)
	var th_lo := Vector3(-60.0, 0, b + 14.0)
	var th_hi := Vector3(60.0, 34.0, b + 54.0)
	_clad_box(pk, kit, th_lo, th_hi, CLAD)
	_wrap_band(pk, kit, "metal", th_lo, th_hi, 0.0, 4.0, CLAD_DARK, 0.1, 13)
	_wrap_band(pk, kit, "pane", th_lo, th_hi, 22.0, 28.5, Color(0.13, 0.17, 0.21), 0.06, 13)
	_wrap_band(pk, kit, "metal", th_lo, th_hi, 30.5, 34.0, CLAD_BLUE, 0.1, 13)
	for k in range(9):
		var x: float = lerpf(-56.0, 56.0, float(k) / 8.0)
		pk.block(kit, "metal", Vector3(x - 0.4, 4.0, th_hi.z), Vector3(x + 0.4, 30.5, th_hi.z + 0.25), CLAD_DARK, uvk)
	for dx in [-40.0, 40.0]:
		pk.block(kit, "metal", Vector3(dx - 4.0, 0.0, th_hi.z), Vector3(dx + 4.0, 7.0, th_hi.z + 0.12), Color(0.5, 0.52, 0.53), uvk)
	# A logo: a blue square with a white wave and spark (fictional), and the name.
	pk.block(kit, "metal", Vector3(-48.0, 12.0, th_hi.z), Vector3(-38.0, 21.0, th_hi.z + 0.3), CLAD_BLUE, uvk)
	pk.block(kit, "metal", Vector3(-46.5, 15.0, th_hi.z + 0.3), Vector3(-39.5, 16.2, th_hi.z + 0.42), WHITE_TRIM, uvk)
	pk.block(kit, "metal", Vector3(-44.0, 17.4, th_hi.z + 0.3), Vector3(-42.0, 19.6, th_hi.z + 0.42), WHITE_TRIM, uvk)
	labels.append(["KRAFTWERK WEIDENHOVEN", Vector3(8.0, 16.0, th_hi.z + 0.35), Vector3(0, 0, 1), 4.2, CLAD_BLUE.darkened(0.2), 80.0])
	labels.append(["WEIDENHOVEN", Vector3(0.0, 75.6, b + 0.12), Vector3(0, 0, 1), 5.5, CLAD_BLUE.darkened(0.15), 40.0])
	# --- Main transformers in front of the hall behind fire walls, bushings and the lines up to the switchyard.
	for k in range(3):
		var tx: float = -30.0 + 30.0 * float(k)
		_transformer(pk, kit, Vector3(tx, 0, th_hi.z + 16.0))
		pk.block(kit, "concrete", Vector3(tx + 9.0, -1.0, th_hi.z + 8.0), Vector3(tx + 9.6, 11.0, th_hi.z + 24.0), CONCRETE, uvk)
	_switchyard(pk, kit, Vector3(5.0, 0, 145.0))
	# --- Flue gas cleaning: the duct out of the boiler house's back to the precipitator, the precipitator on its hoppers,
	# the induced-draught fans, the two scrubbers and the duct over to the chimney's foot.
	var esp_lo := Vector3(-24.0, 12.0, -72.0)
	var esp_hi := Vector3(24.0, 40.0, -40.0)
	pk.block(kit, "shell", esp_lo, esp_hi, Color(0.56, 0.54, 0.50), uvk)
	pk.block(kit, "shell", Vector3(-25.0, 40.0, -73.0), Vector3(25.0, 42.0, -39.0), Color(0.46, 0.44, 0.41), uvk)
	for k in range(5):
		var x2: float = lerpf(-20.0, 20.0, float(k) / 4.0)
		pk.block(kit, "shell", Vector3(x2 - 3.0, 42.0, -66.0), Vector3(x2 + 3.0, 45.5, -46.0), Color(0.52, 0.50, 0.47), uvk)
	for i in range(4):
		for j in range(2):
			var hc := Vector3(lerpf(-18.0, 18.0, float(i) / 3.0), 12.0, lerpf(-64.0, -48.0, float(j)))
			pk.lathe(kit, "shell", hc, [Vector2(0.9, -7.5), Vector2(7.5, 0.0), Vector2(0.001, 0.0)], 4, Color(0.5, 0.48, 0.45), true, Basis(Vector3.UP, PI * 0.25))
			pk.tube(kit, "steel", hc + Vector3(0, -7.5, 0), hc + Vector3(0, -9.0, 0), 0.5, 0.5, 6, FRAME_GREY, true)
	for i in range(5):
		for j in range(3):
			var cp := Vector3(lerpf(-24.0, 24.0, float(i) / 4.0), 0, lerpf(-72.0, -40.0, float(j) / 2.0))
			SteelworksKit._ibeam(pk, kit, "steel", cp, cp + Vector3(0, 12.0, 0), 0.8, 0.6, FRAME_GREY, Vector3.FORWARD)
	# The duct from the boiler house's back (y 70) down to the precipitator's inlet.
	pk.beam(kit, "shell", Vector3(0, 68.0, -b + 1.0), Vector3(0, 68.0, -b - 8.0), 9.0, 7.0, Color(0.52, 0.5, 0.47), Vector3.RIGHT, uvk)
	pk.beam(kit, "shell", Vector3(0, 71.0, -b - 4.5), Vector3(0, 34.0, -42.0), 9.0, 7.0, Color(0.52, 0.5, 0.47), Vector3.RIGHT, uvk)
	# Fans and the scrubbers (absorbers): two drums with their spray levels' bands, stairs, the outlet ducts.
	for sx in [-1.0, 1.0]:
		var fan := Vector3(sx * 10.0, 0, -82.0)
		pk.beam(kit, "shell", Vector3(sx * 10.0, 20.0, -72.0), fan + Vector3(0, 6.0, 0), 5.0, 5.0, Color(0.5, 0.48, 0.45), Vector3.RIGHT, uvk)
		pk.tube(kit, "shell", fan + Vector3(-4.5, 4.4, 0), fan + Vector3(4.5, 4.4, 0), 4.2, 4.2, 14, Color(0.44, 0.48, 0.52), true)
		pk.block(kit, "concrete", fan + Vector3(-5.0, -1.0, -4.5), fan + Vector3(5.0, 0.4, 4.5), CONCRETE, uvk)
		var ac := Vector3(sx * 14.0, 0, -106.0)
		pk.lathe(kit, "shell", ac, [Vector2(9.6, -1.0), Vector2(9.6, 0.6), Vector2(9.0, 0.6), Vector2(9.0, 46.0), Vector2(7.5, 50.0), Vector2(2.8, 53.0), Vector2(0.001, 53.0)],
				24, Color(0.70, 0.71, 0.70), false)
		for by in [14.0, 22.0, 30.0, 38.0]:
			pk.lathe(kit, "metal", ac, [Vector2(9.05, by), Vector2(9.35, by + 0.2), Vector2(9.35, by + 0.9), Vector2(9.05, by + 1.1)], 24, CLAD_DARK, false)
		pk.beam(kit, "shell", fan + Vector3(0, 6.0, -4.0), ac + Vector3(0, 8.0, 8.5), 4.5, 4.5, Color(0.5, 0.48, 0.45), Vector3.RIGHT, uvk)
		# The outlet: from the drum's top over to the chimney.
		var top: Vector3 = ac + Vector3(0, 51.0, 0)
		pk.beam(kit, "shell", top, top + Vector3(-sx * 5.0, 0, -8.0), 5.0, 5.0, Color(0.6, 0.6, 0.58), Vector3.UP, uvk)
		pk.beam(kit, "shell", top + Vector3(-sx * 5.0, 2.5, -8.0), POWER_CHIMNEY_AT + Vector3(sx * 4.0, POWER_DUCT_Y + 3.0, 12.0), 5.0, 5.0, Color(0.6, 0.6, 0.58), Vector3.UP, uvk)
		# A stair tower up the drum's side.
		SteelworksKit._tower(pk, kit, "steel", ac + Vector3(sx * 12.0, 0, 0), 50.0, 1.6, 1.6, 6.0, FRAME_GREY, 0.3, 0.12, false)
	# The common duct into the chimney's foot on supports.
	pk.beam(kit, "shell", POWER_CHIMNEY_AT + Vector3(0, POWER_DUCT_Y + 3.0, 14.0), POWER_CHIMNEY_AT + Vector3(0, POWER_DUCT_Y + 3.0, 7.5), 13.0, 6.0, Color(0.6, 0.6, 0.58), Vector3.UP, uvk)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "concrete", POWER_CHIMNEY_AT + Vector3(sx * 6.0 - 0.6, 0.0, 10.0), POWER_CHIMNEY_AT + Vector3(sx * 6.0 + 0.6, POWER_DUCT_Y, 11.2), CONCRETE, uvk)
	# --- Coal: the conveyor gallery from the transfer tower up into the bunker bay, the low belt from the yard to the
	# tower, the coal heaps and the stacker-reclaimer between them.
	var tt := Vector3(-120.0, 0, 30.0)
	_clad_box(pk, kit, tt + Vector3(-7.0, 0, -7.0), tt + Vector3(7.0, 42.0, 7.0), CLAD.darkened(0.06))
	_wrap_band(pk, kit, "metal", tt + Vector3(-7.0, 0, -7.0), tt + Vector3(7.0, 0, 7.0), 38.0, 42.0, CLAD_BLUE, 0.1)
	_conveyor(pk, kit, tt + Vector3(7.0, 36.0, 0), Vector3(-b, 60.0, 30.0), 4.0, 3.4)
	_conveyor(pk, kit, Vector3(-185.0, 4.0, 30.0), tt + Vector3(-7.0, 9.0, 0), 3.4, 3.0)
	var saved: Transform3D = pk.xf
	pk.set_frame(saved * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-262.0, 0, -6.0)))
	SteelworksKit.stockpile(pk, kit, 150.0, 34.0, 15.0, true)
	pk.set_frame(saved * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-262.0, 0, 66.0)))
	SteelworksKit.stockpile(pk, kit, 130.0, 30.0, 13.0, true)
	pk.set_frame(saved)
	_stacker_reclaimer(pk, kit, Vector3(-235.0, 0, 30.0))
	# --- The cooling water: two pipes from the hall's east end to the towers' basins.
	for k in range(2):
		var z0: float = b + 30.0 + 6.0 * float(k)
		var tw: Vector3 = POWER_TOWERS[k]
		SteelworksKit.pipe_run(pk, kit, PackedVector3Array([Vector3(60.0, 2.2, z0), Vector3(85.0, 2.2, z0), Vector3(85.0, 2.2, tw.z + 10.0 * (1.0 if k == 0 else -1.0)),
				Vector3(tw.x - 48.0, 2.2, tw.z + 10.0 * (1.0 if k == 0 else -1.0))]), 1.4)


## A main transformer at `p`: the tank with its radiator banks, conservator, bushings on the lid.
static func _transformer(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	var tank := Color(0.42, 0.46, 0.44)
	pk.block(kit, "concrete", p + Vector3(-6.0, -0.5, -4.0), p + Vector3(6.0, 0.5, 4.0), CONCRETE, uvk)
	pk.block(kit, "metal", p + Vector3(-4.0, 0.5, -2.2), p + Vector3(4.0, 6.0, 2.2), tank, uvk)
	for sx in [-1.0, 1.0]:
		for k in range(8):
			var z: float = -1.9 + 0.54 * float(k)
			pk.block(kit, "metal", p + Vector3(sx * 4.0, 1.0, z - 0.05) + Vector3(minf(0.0, sx * 1.4), 0, 0), p + Vector3(sx * 4.0, 5.4, z + 0.05) + Vector3(maxf(0.0, sx * 1.4), 0, 0),
					tank.darkened(0.1), uvk)
	pk.tube(kit, "metal", p + Vector3(-3.0, 7.4, 1.4), p + Vector3(3.0, 7.4, 1.4), 0.7, 0.7, 10, tank, true)
	pk.beam(kit, "metal", p + Vector3(-2.0, 6.0, 1.4), p + Vector3(-2.0, 6.8, 1.4), 0.3, 0.3, tank)
	for k in range(3):
		var bx: float = -2.4 + 2.4 * float(k)
		_insulator(pk, kit, p + Vector3(bx, 6.0, -0.8), p + Vector3(bx, 10.5, -1.6), 0.35)
	_insulator(pk, kit, p + Vector3(-2.4, 6.0, 0.4), p + Vector3(-2.4, 8.0, 0.4), 0.25)


## A porcelain insulator (a stack of discs, brown) from a to b, `r` its sheds' radius.
static func _insulator(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, r: float) -> void:
	pk.tube(kit, "gloss", a, b, r * 0.4, r * 0.35, 6, Color(0.42, 0.22, 0.14), true)
	var n: int = maxi(int(a.distance_to(b) / 0.5), 2)
	for k in range(1, n):
		var c: Vector3 = a.lerp(b, float(k) / float(n))
		var d: Vector3 = (b - a).normalized() * 0.06
		pk.tube(kit, "gloss", c - d, c + d, r, r, 8, Color(0.46, 0.24, 0.15), true)


## The switchyard round `c`: three rows of lattice portal gantries, strings of insulators, the conductors between them,
## breakers and disconnectors on their stands in the bays, the line portals at the far end.
static func _switchyard(pk: PropKit, kit: Dictionary, c: Vector3) -> void:
	var gal := Color(0.66, 0.67, 0.66)
	var rows: Array = [-30.0, 0.0, 30.0]
	var cols: Array = [-48.0, -16.0, 16.0, 48.0]
	var h := 18.0
	for zr in rows:
		for xc in cols:
			SteelworksKit._tower(pk, kit, "steel", c + Vector3(xc, 0, zr), h, 1.4, 0.9, 4.5, gal, 0.22, 0.09, false)
		SteelworksKit._lattice(pk, kit, "steel", c + Vector3(cols[0], h - 1.0, zr), c + Vector3(cols[cols.size() - 1], h - 1.0, zr), 1.6, 2.0, 4.0, gal, Vector3.UP, 0.16, 0.08, 3)
		# Insulator strings hanging under the beam and the conductors to the next row.
		for k in range(cols.size() - 1):
			for phase in range(3):
				var x: float = lerpf(float(cols[k]), float(cols[k + 1]), (float(phase) + 1.0) / 4.0)
				var top: Vector3 = c + Vector3(x, h - 2.0, zr)
				var bot: Vector3 = top + Vector3(0, -2.8, 0)
				_insulator(pk, kit, top, bot, 0.18)
				if zr < 25.0:
					pk.beam(kit, "steel", bot, bot + Vector3(0, -0.4, 30.0), 0.06, 0.06, Color(0.5, 0.5, 0.48))
	# Equipment in the bays: breakers (three poles on a frame) and disconnectors.
	for zr2 in [-15.0, 15.0]:
		for k in range(cols.size() - 1):
			var mx: float = (float(cols[k]) + float(cols[k + 1])) * 0.5
			for phase in range(3):
				var px: float = mx + (float(phase) - 1.0) * 4.0
				var base: Vector3 = c + Vector3(px, 0, zr2)
				pk.block(kit, "concrete", base + Vector3(-0.6, -0.5, -0.6), base + Vector3(0.6, 0.3, 0.6), CONCRETE, uvk)
				pk.beam(kit, "steel", base + Vector3(0, 0.3, 0), base + Vector3(0, 3.5, 0), 0.35, 0.35, gal)
				_insulator(pk, kit, base + Vector3(0, 3.5, 0), base + Vector3(0, 6.5, 0), 0.22)
				pk.block(kit, "metal", base + Vector3(-0.4, 6.5, -0.4), base + Vector3(0.4, 7.2, 0.4), Color(0.6, 0.6, 0.62), uvk)


## An enclosed belt conveyor gallery from a (lower end) to b (upper), `w` wide and `gh` tall, on a lattice truss under it,
## carried by steel trestles every 30m or so.
static func _conveyor(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, w: float, gh: float) -> void:
	var d: Vector3 = b - a
	var flat := Vector3(d.x, 0, d.z).normalized()
	var side := Vector3(-flat.z, 0, flat.x)
	var dir: Vector3 = d.normalized()
	var up: Vector3 = side.cross(dir).normalized()
	if up.y < 0.0:
		up = -up
	pk.beam(kit, "cladding", a + up * (gh * 0.5), b + up * (gh * 0.5), w, gh, CLAD.darkened(0.04), side, uvk)
	pk.beam(kit, "pane", a + up * (gh * 0.62) + side * (w * 0.5 + 0.03), b + up * (gh * 0.62) + side * (w * 0.5 + 0.03), 0.04, 0.6, Color(0.12, 0.15, 0.18), side)
	pk.beam(kit, "pane", a + up * (gh * 0.62) - side * (w * 0.5 + 0.03), b + up * (gh * 0.62) - side * (w * 0.5 + 0.03), 0.04, 0.6, Color(0.12, 0.15, 0.18), side)
	SteelworksKit._lattice(pk, kit, "steel", a - up * 1.3, b - up * 1.3, w + 0.3, 2.4, 5.0, FRAME_GREY, up, 0.3, 0.14, 12)
	var length: float = Vector3(d.x, 0, d.z).length()
	var n: int = maxi(int(length / 30.0), 1)
	for k in range(1, n + 1):
		var t: float = float(k) / float(n + 1)
		var p: Vector3 = a.lerp(b, t) - up * 2.6
		if p.y < 3.0:
			continue
		var g := Vector3(p.x, 0, p.z)
		for sd in [-1.0, 1.0]:
			pk.beam(kit, "steel", g + side * (sd * (w * 0.5 + 0.6)), p + side * (sd * (w * 0.5 + 0.2)), 0.6, 0.6, FRAME_GREY, flat)
			pk.block(kit, "concrete", g + side * (sd * (w * 0.5 + 0.6)) + Vector3(-1.0, -1.5, -1.0), g + side * (sd * (w * 0.5 + 0.6)) + Vector3(1.0, 0.3, 1.0), CONCRETE, uvk)
		var ny: int = maxi(int(p.y / 8.0), 1)
		for j in range(ny):
			var y0: float = p.y * float(j) / float(ny)
			var y1: float = p.y * float(j + 1) / float(ny)
			pk.beam(kit, "steel", g + side * (-(w * 0.5 + 0.6)) + Vector3(0, y0, 0), g + side * (w * 0.5 + 0.6) + Vector3(0, y1, 0), 0.25, 0.25, FRAME_GREY, flat)


## The coal yard's stacker-reclaimer at `p` on its rails along x: a portal undercarriage, the slewing deck with its
## machinery house and counterweight, a lattice boom 42m long with the belt and the bucket wheel at its end.
static func _stacker_reclaimer(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	var yel := Color(0.88, 0.66, 0.12)
	for sz in [-4.0, 4.0]:
		pk.beam(kit, "steel", p + Vector3(-90.0, 0.2, sz), p + Vector3(90.0, 0.2, sz), 0.4, 0.3, Color(0.3, 0.3, 0.3), Vector3.UP)
		for k in range(4):
			pk.block(kit, "steel", p + Vector3(-6.0 + 3.6 * float(k), 0.4, sz - 0.7), p + Vector3(-4.0 + 3.6 * float(k), 2.0, sz + 0.7), Color(0.2, 0.2, 0.2), uvk)
	pk.block(kit, "paint", p + Vector3(-7.0, 2.0, -5.0), p + Vector3(7.0, 4.0, 5.0), yel, uvk)
	for sx in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			pk.beam(kit, "paint", p + Vector3(sx * 5.5, 4.0, sz2 * 3.5), p + Vector3(sx * 2.5, 12.0, sz2 * 2.0), 0.9, 0.9, yel)
	pk.lathe(kit, "paint", p + Vector3(0, 12.0, 0), [Vector2(0.001, 0.0), Vector2(4.5, 0.0), Vector2(4.5, 1.2), Vector2(0.001, 1.2)], 16, yel.darkened(0.15), true)
	# The upper works slewed toward the heap on the -z side.
	var saved: Transform3D = pk.xf
	pk.set_frame(saved * Transform3D(Basis(Vector3.UP, -0.55), p) * Transform3D(Basis(), -p))
	pk.block(kit, "paint", p + Vector3(-3.5, 13.2, -3.0), p + Vector3(5.0, 18.0, 3.0), Color(0.82, 0.82, 0.80), uvk)
	# The counterweight boom and its weight, the mast with the stays to the boom.
	SteelworksKit._lattice(pk, kit, "paint", p + Vector3(4.0, 14.0, 0), p + Vector3(20.0, 16.0, 0), 2.5, 2.5, 4.0, yel, Vector3.UP, 0.3, 0.14, 15)
	pk.block(kit, "concrete", p + Vector3(18.0, 11.0, -2.5), p + Vector3(24.0, 17.0, 2.5), Color(0.35, 0.36, 0.36), uvk)
	pk.beam(kit, "paint", p + Vector3(0.0, 18.0, 0), p + Vector3(0.0, 28.0, 0), 1.0, 1.0, yel)
	var tip := p + Vector3(-40.0, 9.0, 0)
	pk.beam(kit, "steel", p + Vector3(0.0, 28.0, 0), tip + Vector3(10.0, 3.0, 0), 0.12, 0.12, Color(0.2, 0.2, 0.2))
	pk.beam(kit, "steel", p + Vector3(0.0, 28.0, 0), p + Vector3(20.0, 16.5, 0), 0.12, 0.12, Color(0.2, 0.2, 0.2))
	SteelworksKit._lattice(pk, kit, "paint", p + Vector3(-3.0, 14.0, 0), tip, 3.0, 3.0, 4.0, yel, Vector3.UP, 0.3, 0.14, 15)
	pk.beam(kit, "rubber", p + Vector3(-3.0, 15.7, 0), tip + Vector3(0, 1.7, 0), 1.6, 0.15, Color(0.08, 0.08, 0.08), Vector3.FORWARD)
	# The bucket wheel at the boom's end: a rim with buckets round it, its axle across the boom.
	var wc: Vector3 = tip + Vector3(-3.0, -1.0, -2.2)
	var ax := Basis(Vector3.RIGHT, PI * 0.5)
	pk.tyre(kit, "paint", wc, 3.2, 3.7, 0.8, 20, yel, ax)
	for k in range(10):
		var a: float = TAU * float(k) / 10.0
		var dr := Vector3(cos(a), sin(a), 0)
		pk.box(kit, "steel", Transform3D(Basis(dr, Vector3.BACK.cross(dr), Vector3.BACK), wc + dr * 4.0), Vector3(1.2, 1.0, 1.1), Color(0.25, 0.25, 0.25))
	pk.tube(kit, "steel", wc + Vector3(0, 0, -0.6), wc + Vector3(0, 0, 2.4), 0.5, 0.5, 8, Color(0.3, 0.3, 0.3), true)
	pk.set_frame(saved)
