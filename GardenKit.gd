extends RefCounted
## Kronburg GP finale: the city's Botanischer Garten. The Palmenhaus the route drives straight through (a Victorian
## iron-and-glass palm house: a domed central pavilion between two vaulted wings, full of palms, bananas, tree ferns
## and aroids), the main gate with its iron overthrow, the garden's railings, formal carpet bedding (Teppichbeete) and
## mixed borders, the rose pergola over the road (Rosenlaube) and rose beds, two stone bridges (the city's moat bridge
## and the garden's pond bridge, whose road surface is the caller's), the Alpinum's stones and cushion plants, the
## belvedere, balustrades, terrace walls and steps, the parterre fountain, and the small things: benches, lamps, plant
## labels, wayfinding boards, topiary, hedges, urns, a statue, a small glasshouse and a sundial. Fictional throughout.
##
## Everything is built at LIFE size through a PropKit in its own frame (y = 0 the ground, footings and plinths down to
## about y = -1.5, the front toward +z unless a builder says otherwise) and grown by the caller (PROP_SCALE 1.6). Make a
## kit with `new_kit(scale)`, call a builder (into a dictionary `kit`), `commit(pk, kit)`. UVs are in metres times `uvk`
## (the caller's scale) where an existing shader reads world metres (ashlar, hedge, timber, slate), and in LIFE metres
## on this kit's own shaders (garden_glass, garden_flowers, garden_foliage), whose patterns are sized in life metres.
## Labels are [text, position, outward normal, cap height, colour, board width] in life-size kit coordinates.
## `<name>_solids(...)` give [Transform3D (life size, in the prop's frame), Vector3 size] boxes for colliders.
##
## Material keys (make_material): KronburgTownKit's "ashlar" (dressed sandstone, coursed), "kbrick" (the small
## glasshouse's dwarf wall), "kslate", "gold", "enamel", "pane", "leaf", "kwater" (the fountains' water), "hedge" (the hedges
## and topiary); SteelworksKit's "lens"; YardKit's "timber", "painted", "stone", "concrete", "plaster" (hut_masonry's
## stucco, tinted: carved stone without joints, the urns; the belvedere's painted dome), "zinc" (standing seams: the
## belvedere's verdigris copper dome), "lamp" (the park lamps' lanterns); CampKit's vertex-colour "paint" (white-painted
## ironwork), "steel" (dark wrought iron), "metal", "matte" (soil, mulch, clay pots), "wood"; and this kit's own:
## "gglass" (garden_glass.gdshader: the glasshouses' glazing, transparent, with the glazing bars drawn), "gflower"
## (garden_flowers.gdshader: bedding, borders, roses, cushions, the wall's trailing rock plants), "gleaf"
## (garden_foliage.gdshader: palms, bananas, ferns, aroids, lilies, cacti and their trunks), "grock" (garden_rock.gdshader:
## the Alpinum's limestone, COLOR.a its hollows), "gspray" (a fountain's jets and spills, translucent), "gbronze" (statues',
## the sundial's and the dome's ribs' patinated bronze). Faces never share a plane: trims stand 2.5cm or more proud and
## parts that meet overlap or step. Godot's front faces wind clockwise: PropKit.tri winds every triangle for the `out` it's
## given.
##
## The builders (life metres, each in its own frame; the generator's call in brackets where it isn't obvious):
##   palm_house(pk, kit, labels)          road along z through it: footprint PALM_HOUSE_HALF, corridor PH_CLEAR_*
##   garden_gate(pk, kit, labels, text)   road along z: piers |x| 6.6-7.8 to 9.15 (lidded urns on them), overthrow to 12.4
##   garden_fence(pk, kit, length)        along x 0..length, its street face +z, 2.2m railings on a 0.5m wall
##   flower_bed(pk, kit, w, d, shape, style, seed), rose_arch(pk, kit, span, bay, seed), rose_bed(pk, kit, length, depth, seed)
##   stone_bridge(pk, kit, length, rise, half, wy, style)  driven over: road along z, deck BRIDGE_UNDER under bridge_deck_y
##   belvedere(pk, kit, labels)           +-5.42 square, its stair to z 7.56; 11.9m to the finial
##   terrace_wall(pk, kit, length, h)     x 0..length, top y 0, face +z down h; z -0.56..+0.62
##   balustrade(pk, kit, length)          x 0..length on y 0, +-0.28 of z 0, 1.0m (1.25 to the balls)
##   terrace_steps(pk, kit, width, h)     from the terrace's edge (z 0, y 0) down +z, |x| <= width/2 + 0.5, about 3 h long
##   hedge(pk, kit, length, h, w)         x 0..length, centred on z 0
##   rockery_stone(pk, kit, r, seed), alpine_cushion(pk, kit, r, seed)   on y 0 (a stone sinks 0.6 r into it)
##   parterre_fountain(pk, kit)           basin r 4.98, flags to r 6.1, jet to 5.9m
##   topiary(pk, kit, kind, size), urn(pk, kit, at, scale, lidded), park_lamp, park_bench, plant_label(pk, kit, labels, text),
##   garden_sign(pk, kit, labels, lines), sundial, statue, greenhouse_small(pk, kit, labels) (x +-3.6, z -6.1..6.6)
##   and their `*_solids` where the generator asks for them (palm_house, garden_gate, garden_fence, rose_arch,
##   stone_bridge, belvedere, parterre_fountain; greenhouse_small_solids for a caller that wants it).

const PropKit = preload("res://PropKit.gd")
const SW = preload("res://SteelworksKit.gd")
const KT = preload("res://KronburgTownKit.gd")
const YK = preload("res://YardKit.gd")

static var uvk := 1.6
static var _mats := {}

const SW_KEYS := ["lens"]
const KT_KEYS := ["biber", "ashlar", "kslate", "kbrick", "pane", "gold", "enamel", "leaf", "kwater", "hedge"]
const TANGENT_KEYS := ["iron", "concrete", "slate", "kslate", "biber", "tile", "zinc", "hedge"]

const WHITE := Color(1, 1, 1)
## White-painted ironwork, a little warm.
const IRON_WHITE := Color(0.93, 0.93, 0.90)
## Wrought iron: Kronburg's railings and gates, a black green.
const IRON_DARK := Color(0.07, 0.09, 0.08)
const SAND := Color(0.80, 0.72, 0.58)
const SAND_LIGHT := Color(0.86, 0.79, 0.66)
const SAND_DARK := Color(0.66, 0.58, 0.46)
const SOIL := Color(0.16, 0.11, 0.08)
const MULCH := Color(0.24, 0.16, 0.10)
const GRAVEL := Color(0.72, 0.68, 0.60)
const BOX_GREEN := Color(0.16, 0.30, 0.10)
const YEW := Color(0.10, 0.20, 0.08)
const BRONZE := Color(0.24, 0.36, 0.30)
const GILT := Color(0.86, 0.68, 0.26)
const ENAMEL_GREEN := Color(0.06, 0.22, 0.15)

const UP := Vector3.UP

# The Palmenhaus (life metres, its own frame: the road along z on x = 0, y = 0 the road).
## The wings' glass walls stand at |x| = PH_WING_HALF; their vault (a half ellipse from the eaves) rises PH_WING_RISE.
const PH_WING_HALF := 11.0
const PH_WING_EAVE := 4.2
const PH_WING_RISE := 7.0
## The central pavilion: square, its glass walls at |x|, |z| = PH_PAV_HALF up to its eaves, a curved hipped roof up to a
## square ring of half PH_RING at PH_RING_Y, a drum and a dome.
const PH_PAV_HALF := 14.5
const PH_PAV_EAVE := 11.8
const PH_RING := 8.0
const PH_RING_Y := 16.8
const PH_DRUM_R := 7.0
const PH_DRUM_TOP := 18.0
const PH_DOME_TOP := 21.8
## The wings' end gables; the portals stand in front of them to PH_PORTAL_Z.
const PH_END := 32.0
const PH_PORTAL_Z := 32.95
## The plinth's coping top, where the glass stands.
const PH_SILL := 1.0
## Footprint half extents (x, z), the plinths and the portals included.
const PALM_HOUSE_HALF := Vector2(14.85, 33.0)
## The route's corridor through it: nothing in |x| <= PH_CLEAR_X below PH_CLEAR_Y; nothing in |x| <= PH_KERB_X below it
## but the bed kerb (top PH_KERB_TOP), for |z| <= PH_CLEAR_Z.
const PH_CLEAR_X := 5.0
const PH_KERB_X := 6.2
const PH_CLEAR_Y := 9.0
const PH_CLEAR_Z := 34.0
const PH_KERB_TOP := 0.18
## The portal's opening: |x| <= PH_PORTAL_HALF up to PH_PORTAL_SPRING, a segmental arch to PH_PORTAL_CROWN.
const PH_PORTAL_HALF := 6.45
const PH_PORTAL_SPRING := 9.2
const PH_PORTAL_CROWN := 10.3

# The main gate: piers at |x| GATE_PIER_IN..GATE_PIER_OUT, the overthrow's underside at GATE_ARCH_Y.
const GATE_PIER_IN := 6.6
const GATE_PIER_OUT := 7.8
const GATE_PIER_H := 9.3
const GATE_ARCH_Y := 9.15
const GATE_LEAF_W := 6.5
const GATE_LEAF_H := 3.1

# The rose pergola's arch: posts at |x| = span / 2, the underside >= ROSE_ARCH_CLEAR for |x| <= ROSE_ARCH_CLEAR_X.
const ROSE_POST_TOP := 6.4
const ROSE_ARCH_RISE := 2.7
const ROSE_ARCH_CLEAR := 7.5
const ROSE_ARCH_CLEAR_X := 5.2

# While the Palmenhaus's plants are built, every leaf vertex below the corridor's height is kept out of it.
static var _clamp_corr := false
const CORR_X := 6.27
const CORR_Y := 9.05
const CORR_Z := 34.5


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"gglass":
			var g := ShaderMaterial.new()
			g.shader = load("res://garden_glass.gdshader")
			return g
		"gflower":
			var f := ShaderMaterial.new()
			f.shader = load("res://garden_flowers.gdshader")
			return f
		"gleaf":
			var l := ShaderMaterial.new()
			l.shader = load("res://garden_foliage.gdshader")
			return l
		"grock":
			var r := ShaderMaterial.new()
			r.shader = load("res://garden_rock.gdshader")
			r.set_shader_parameter("inv_scale", 1.0 / maxf(uvk, 0.01))
			return r
		"gspray":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.vertex_color_is_srgb = true
			s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			s.cull_mode = BaseMaterial3D.CULL_DISABLED
			s.roughness = 0.08
			s.metallic_specular = 0.8
			s.emission_enabled = true
			s.emission = Color(0.55, 0.62, 0.66)
			s.emission_energy_multiplier = 0.35
			s.shadow_to_opacity = false
			return s
		"gbronze":
			var b := StandardMaterial3D.new()
			b.vertex_color_use_as_albedo = true
			b.vertex_color_is_srgb = true
			b.metallic = 0.55
			b.roughness = 0.5
			return b
	if key in SW_KEYS:
		return SW.make_material(key)
	if key in KT_KEYS:
		return KT.make_material(key)
	return YK.make_material(key)


## A kit growing everything by `scale`, its materials shared with every other kit made here.
static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	SW.uvk = scale
	YK.uvk = scale
	SW._lx = Transform3D.IDENTITY
	_clamp_corr = false
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

static func _push(pk: PropKit, t: Transform3D) -> Array:
	return SW._push(pk, t)


static func _pop(pk: PropKit, saved: Array) -> void:
	SW._pop(pk, saved)


static func _lbl(labels: Array, text: String, p: Vector3, n: Vector3, cap: float, col: Color, w := 0.0) -> void:
	SW._label(labels, text, p, n, cap, col, w)


## A box centred at `c` turned by `basis`, UVs in metres (times uvk).
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## A masonry quad facing `out` (u along, v up, UVs in metres times uvk from p0).
static func _mq(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, along: Vector3, out: Vector3, u0: float, u1: float, v0: float, v1: float, col: Color) -> void:
	if u1 - u0 < 1e-4 or v1 - v0 < 1e-4:
		return
	pk.quad(kit, key, [p0 + along * u0 + UP * v0, p0 + along * u1 + UP * v0, p0 + along * u1 + UP * v1, p0 + along * u0 + UP * v1], out, col,
			[Vector2(u0, v0) * uvk, Vector2(u1, v0) * uvk, Vector2(u1, v1) * uvk, Vector2(u0, v1) * uvk])


## An axis-aligned block with masonry UVs: its four sides as walls (u along each, v up), its top (and bottom) in plan.
static func _mblock(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color, top := true, bottom := false) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	# u runs on from block to block (the plan coordinate along each face), so courses of neighbouring blocks line up.
	_mq(pk, kit, key, Vector3(0, 0, hi.z), Vector3.RIGHT, Vector3.BACK, lo.x, hi.x, lo.y, hi.y, col)
	_mq(pk, kit, key, Vector3(0, 0, lo.z), Vector3.LEFT, Vector3.FORWARD, -hi.x, -lo.x, lo.y, hi.y, col)
	_mq(pk, kit, key, Vector3(hi.x, 0, 0), Vector3.FORWARD, Vector3.RIGHT, -hi.z, -lo.z, lo.y, hi.y, col)
	_mq(pk, kit, key, Vector3(lo.x, 0, 0), Vector3.BACK, Vector3.LEFT, lo.z, hi.z, lo.y, hi.y, col)
	if top:
		pk.quad(kit, key, [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)], UP, col,
				[Vector2(lo.x, lo.z) * uvk, Vector2(hi.x, lo.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(lo.x, hi.z) * uvk])
	if bottom:
		pk.quad(kit, key, [Vector3(lo.x, lo.y, lo.z), Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, lo.y, lo.z)], Vector3.DOWN, col.darkened(0.2),
				[Vector2(lo.x, lo.z) * uvk, Vector2(lo.x, hi.z) * uvk, Vector2(hi.x, hi.z) * uvk, Vector2(hi.x, lo.z) * uvk])


## A wall-like slab of masonry from a to b (plan, y ignored) `thick` deep, centred on the line, y0..y1: both faces, ends, top.
static func _slab(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, thick: float, y0: float, y1: float, col: Color, top := true, ends := true) -> void:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var l := d.length()
	if l < 1e-4:
		return
	var al: Vector3 = d / l
	var nrm := Vector3(-al.z, 0, al.x)
	var h: Vector3 = nrm * (thick * 0.5)
	var a0 := Vector3(a.x, 0, a.z)
	_mq(pk, kit, key, a0 + h, al, nrm, 0.0, l, y0, y1, col)
	_mq(pk, kit, key, a0 - h + al * l, -al, -nrm, 0.0, l, y0, y1, col)
	if ends:
		_mq(pk, kit, key, a0 - h, nrm, -al, 0.0, thick, y0, y1, col)
		_mq(pk, kit, key, a0 + h + al * l, -nrm, al, 0.0, thick, y0, y1, col)
	if top:
		var p: Array = [a0 - h + UP * y1, a0 + h + UP * y1, a0 + h + al * l + UP * y1, a0 - h + al * l + UP * y1]
		pk.quad(kit, key, p, UP, col.lightened(0.04), [Vector2(0, 0), Vector2(thick, 0) * uvk, Vector2(thick, l) * uvk, Vector2(0, l) * uvk])


## A sloped slab of masonry from a to b (their y the top line's heights at each end), `thick` deep, `h` tall under that
## line: both faces, the top and the ends; a balustrade's base and rail, a parapet's coping on a hump.
static func _sloped(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, thick: float, h: float, col: Color, bottom := false, ends := false, u0 := 0.0) -> void:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var l := d.length()
	if l < 1e-4:
		return
	var al: Vector3 = d / l
	var nrm := Vector3(-al.z, 0, al.x)
	var hv: Vector3 = nrm * (thick * 0.5)
	var dn := Vector3(0, -h, 0)
	for s in [1.0, -1.0]:
		var o: Vector3 = hv * s
		var p: Array = [a + o + dn, b + o + dn, b + o, a + o]
		pk.quad(kit, key, p, nrm * s, col, [Vector2(u0, a.y - h) * uvk, Vector2(u0 + l, b.y - h) * uvk, Vector2(u0 + l, b.y) * uvk, Vector2(u0, a.y) * uvk])
	var tn: Vector3 = (b - a).cross(nrm).normalized()
	if tn.y < 0.0:
		tn = -tn
	pk.quad(kit, key, [a - hv, a + hv, b + hv, b - hv], tn, col.lightened(0.05), [Vector2(0, u0) * uvk, Vector2(thick, u0) * uvk, Vector2(thick, u0 + l) * uvk, Vector2(0, u0 + l) * uvk])
	if bottom:
		pk.quad(kit, key, [a - hv + dn, b - hv + dn, b + hv + dn, a + hv + dn], -tn, col.darkened(0.25), [Vector2(0, 0), Vector2(0, l) * uvk, Vector2(thick, l) * uvk, Vector2(thick, 0) * uvk])
	if ends:
		pk.quad(kit, key, [a - hv + dn, a + hv + dn, a + hv, a - hv], -al, col, [Vector2(0, a.y - h) * uvk, Vector2(thick, a.y - h) * uvk, Vector2(thick, a.y) * uvk, Vector2(0, a.y) * uvk])
		pk.quad(kit, key, [b - hv + dn, b + hv + dn, b + hv, b - hv], al, col, [Vector2(0, b.y - h) * uvk, Vector2(thick, b.y - h) * uvk, Vector2(thick, b.y) * uvk, Vector2(0, b.y) * uvk])


## A lathe with UVs in metres (times uvk): u round, v along the profile (SteelworksKit's).
static func _lathe(pk: PropKit, kit: Dictionary, key: String, c: Vector3, profile: Array, segs: int, col: Color) -> void:
	SW._lathe_uv(pk, kit, key, c, profile, segs, col)


## A smooth tube through `pts` with a radius per point (`radii`, or one float) and a colour per point (`cols`, or one
## Color), `segs` round: UV.x round it and UV.y along it, both in life metres (the trunk modes of "gleaf"). Rings are
## carried along by parallel transport so a bent trunk doesn't twist. `cap` closes the far end. Plants go through `_lt`
## (the corridor clamp) with `plant`. `uvs` scales the UVs (uvk for a shader that reads world metres: "hedge", "ashlar").
static func _tube(pk: PropKit, kit: Dictionary, key: String, pts: Array, radii, segs: int, cols, cap := false, plant := false, uvs := 1.0) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var frames: Array = []
	var side := Vector3.ZERO
	var runs: Array = []
	var run := 0.0
	for i in range(n):
		var t: Vector3
		if i == 0:
			t = (pts[1] - pts[0]).normalized()
		elif i == n - 1:
			t = (pts[n - 1] - pts[n - 2]).normalized()
		else:
			t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
		if i == 0:
			side = t.cross(UP if absf(t.y) < 0.95 else Vector3.RIGHT).normalized()
		else:
			side = (side - t * side.dot(t)).normalized()
			run += (pts[i] as Vector3).distance_to(pts[i - 1])
		frames.append([side, t.cross(side).normalized()])
		runs.append(run)
	for i in range(n - 1):
		var ra: float = radii[i] if radii is Array else float(radii)
		var rb: float = radii[i + 1] if radii is Array else float(radii)
		var ca: Color = cols[i] if cols is Array else cols
		var cb: Color = cols[i + 1] if cols is Array else cols
		var sa: Vector3 = frames[i][0]
		var ua: Vector3 = frames[i][1]
		var sb: Vector3 = frames[i + 1][0]
		var ub: Vector3 = frames[i + 1][1]
		var circ: float = TAU * (ra + rb) * 0.5
		for j in range(segs):
			var a0: float = TAU * float(j) / float(segs)
			var a1: float = TAU * float(j + 1) / float(segs)
			var da0: Vector3 = sa * cos(a0) + ua * sin(a0)
			var da1: Vector3 = sa * cos(a1) + ua * sin(a1)
			var db0: Vector3 = sb * cos(a0) + ub * sin(a0)
			var db1: Vector3 = sb * cos(a1) + ub * sin(a1)
			var p00: Vector3 = pts[i] + da0 * ra
			var p01: Vector3 = pts[i] + da1 * ra
			var p10: Vector3 = pts[i + 1] + db0 * rb
			var p11: Vector3 = pts[i + 1] + db1 * rb
			var u0: float = circ * float(j) / float(segs) * uvs
			var u1: float = circ * float(j + 1) / float(segs) * uvs
			var v0: float = float(runs[i]) * uvs
			var v1: float = float(runs[i + 1]) * uvs
			var out: Vector3 = (da0 + da1 + db0 + db1).normalized()
			if plant:
				_lt(pk, kit, key, p00, p01, p11, da0, da1, db1, ca.lerp(cb, 0.5), out, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				_lt(pk, kit, key, p00, p11, p10, da0, db1, db0, ca.lerp(cb, 0.5), out, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
			else:
				pk.tri(kit, key, p00, p01, p11, da0, da1, db1, ca.lerp(cb, 0.5), out, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				pk.tri(kit, key, p00, p11, p10, da0, db1, db0, ca.lerp(cb, 0.5), out, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
	if cap:
		var e: Vector3 = pts[n - 1]
		var re: float = radii[n - 1] if radii is Array else float(radii)
		var se: Vector3 = frames[n - 1][0]
		var ue: Vector3 = frames[n - 1][1]
		var te: Vector3 = ue.cross(se).normalized()
		var ce: Color = cols[n - 1] if cols is Array else cols
		for j in range(segs):
			var a0: float = TAU * float(j) / float(segs)
			var a1: float = TAU * float(j + 1) / float(segs)
			pk.tri(kit, key, e, e + (se * cos(a0) + ue * sin(a0)) * re, e + (se * cos(a1) + ue * sin(a1)) * re, te, te, te, ce, te)


## A plant's triangle: kept out of the Palmenhaus's corridor while `_clamp_corr` is on (a vertex under its height inside
## it is pushed out to its side). One colour a triangle: faces carry their shader mode in the alpha.
static func _lt(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color,
		out: Vector3, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	if _clamp_corr:
		a = _cc(a)
		b = _cc(b)
		c = _cc(c)
	pk.tri(kit, key, a, b, c, na, nb, nc, col, out, ua, ub, uc)


static func _cc(p: Vector3) -> Vector3:
	if p.y < CORR_Y and absf(p.x) < CORR_X and absf(p.z) < CORR_Z:
		p.x = CORR_X if p.x >= 0.0 else -CORR_X
	return p


## A leaf card along a curved spine: from `base` along `dir` (unit), `length` long, `half_w` either side of its midrib,
## falling `droop` metres at the tip (a parabola), its halves folded up by `fold` radians about the midrib (a V) and
## turned by `twist` radians about it by the tip. UV.x = id + 0..1 across (0.5 the midrib), UV.y 0..1 from base to tip:
## the "gleaf" card modes (0.7 frond, 0.5 banana, 0.4/0.35 aroid, 0.3 fern, 0.2 strap) in `col`'s alpha. `lat_hint`
## sets which way is across (default: horizontal, square to dir).
static func _card(pk: PropKit, kit: Dictionary, base: Vector3, dir: Vector3, length: float, half_w: float, droop: float, fold: float, col: Color,
		id: float, segs := 6, twist := 0.0, lat_hint := Vector3.ZERO, key := "gleaf", taper := 1.0) -> void:
	var lat: Vector3 = lat_hint if lat_hint.length_squared() > 1e-6 else dir.cross(UP)
	if lat.length_squared() < 1e-4:
		lat = Vector3.RIGHT
	lat = (lat - dir * lat.dot(dir)).normalized()
	var sp: Array = []
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		sp.append(base + dir * (length * t) + Vector3.DOWN * (droop * t * t))
	var idf: float = floor(id)
	for i in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var e: Array = []
		for k in [i, i + 1]:
			var tk: float = float(k) / float(segs)
			var tg: Vector3
			if k == 0:
				tg = (sp[1] - sp[0]).normalized()
			elif k == segs:
				tg = (sp[segs] - sp[segs - 1]).normalized()
			else:
				tg = (sp[k + 1] - sp[k - 1]).normalized()
			var lk: Vector3 = (lat - tg * lat.dot(tg)).normalized().rotated(tg, twist * tk)
			var upk: Vector3 = lk.cross(tg).normalized()
			if upk.y < 0.0:
				upk = -upk
			var w: float = half_w * lerpf(1.0, taper, tk)
			var left: Vector3 = (-lk * cos(fold) + upk * sin(fold)) * w
			var right: Vector3 = (lk * cos(fold) + upk * sin(fold)) * w
			e.append([sp[k], sp[k] + left, sp[k] + right, tg])
		var m0: Vector3 = e[0][0]
		var m1: Vector3 = e[1][0]
		var l0: Vector3 = e[0][1]
		var l1: Vector3 = e[1][1]
		var r0: Vector3 = e[0][2]
		var r1: Vector3 = e[1][2]
		var nl: Vector3 = (l0 - m0).cross(e[0][3]).normalized()
		if nl.y < 0.0:
			nl = -nl
		var nr: Vector3 = (e[0][3] as Vector3).cross(r0 - m0).normalized()
		if nr.y < 0.0:
			nr = -nr
		var nm: Vector3 = (nl + nr).normalized()
		_lt(pk, kit, key, m0, m1, l1, nm, nm, nl, col, nl, Vector2(idf + 0.5, t0), Vector2(idf + 0.5, t1), Vector2(idf + 0.001, t1))
		_lt(pk, kit, key, m0, l1, l0, nm, nl, nl, col, nl, Vector2(idf + 0.5, t0), Vector2(idf + 0.001, t1), Vector2(idf + 0.001, t0))
		_lt(pk, kit, key, m0, r1, m1, nm, nr, nm, col, nr, Vector2(idf + 0.5, t0), Vector2(idf + 0.999, t1), Vector2(idf + 0.5, t1))
		_lt(pk, kit, key, m0, r0, r1, nm, nr, nr, col, nr, Vector2(idf + 0.5, t0), Vector2(idf + 0.999, t0), Vector2(idf + 0.999, t1))


## A fan palm's leaf: its hastula at `c`, the blade spreading `spread` radians about `axis` (outward from the crown,
## unit) in the plane of `axis` and `lat`, `radius` across, its outer part drooping `droop` metres, pleated in the
## geometry (alternate spokes stand off the plane) and drawn by "gleaf" mode 0.6.
static func _fan(pk: PropKit, kit: Dictionary, c: Vector3, axis: Vector3, lat: Vector3, radius: float, spread: float, droop: float, col: Color, id: float) -> void:
	var nrm: Vector3 = axis.cross(lat).normalized()
	if nrm.y < 0.0:
		nrm = -nrm
	var na := 12
	var rings: Array = [0.0, 0.3, 0.62, 1.0]
	var grid: Array = []
	for ri in range(rings.size()):
		var r: float = rings[ri]
		var row: Array = []
		for ai in range(na + 1):
			var t: float = float(ai) / float(na)
			var ph: float = (t - 0.5) * spread
			var d: Vector3 = axis * cos(ph) + lat * sin(ph)
			var pleat: float = (0.06 if ai % 2 == 0 else -0.06) * radius * r * (1.0 - r * 0.4)
			var side_fall: float = absf(sin(ph)) * 0.35 * r * radius
			var p: Vector3 = c + d * (r * radius) + nrm * pleat + Vector3.DOWN * (droop * r * r + side_fall * r)
			row.append(p)
		grid.append(row)
	var idf: float = floor(id)
	for ri in range(rings.size() - 1):
		for ai in range(na):
			var p00: Vector3 = grid[ri][ai]
			var p01: Vector3 = grid[ri][ai + 1]
			var p10: Vector3 = grid[ri + 1][ai]
			var p11: Vector3 = grid[ri + 1][ai + 1]
			var u0: float = idf + 0.001 + 0.998 * float(ai) / float(na)
			var u1: float = idf + 0.001 + 0.998 * float(ai + 1) / float(na)
			var v0: float = rings[ri]
			var v1: float = rings[ri + 1]
			var n: Vector3 = (p10 - p00).cross(p01 - p00).normalized()
			if n.dot(nrm) < 0.0:
				n = -n
			if ri == 0:
				_lt(pk, kit, "gleaf", p00, p11, p10, n, n, n, col, n, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))
			else:
				_lt(pk, kit, "gleaf", p00, p01, p11, n, n, n, col, n, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				_lt(pk, kit, "gleaf", p00, p11, p10, n, n, n, col, n, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))


## A lumpy clump (an ellipsoid of radii `r` dented by noise), its bottom `sink` of r.y below `c`: rose bushes, climbing
## roses, flower mounds, cushions. UV in life metres round it (u) and up it (v): the "gflower" kinds.
static func _lump(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: Vector3, col: Color, rng: RandomNumberGenerator, segs := 8, rings := 4,
		bumpy := 0.18, flat_base := true) -> void:
	var pts: Array = []
	var nrm: Array = []
	var ph := rng.randf() * TAU
	var bump: Array = []
	for i in range(rings + 1):
		var row: Array = []
		for j in range(segs):
			row.append(1.0 + bumpy * (rng.randf() - 0.5) * 2.0)
		bump.append(row)
	for i in range(rings + 1):
		var th: float = -PI * 0.5 + PI * float(i) / float(rings)
		if flat_base:
			th = lerpf(-0.35, PI * 0.5, float(i) / float(rings))
		var row_p: Array = []
		var row_n: Array = []
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs) + ph
			var k: float = bump[i][j] if i < rings else 1.0
			var d := Vector3(cos(a) * cos(th), sin(th), sin(a) * cos(th))
			row_p.append(c + Vector3(d.x * r.x, d.y * r.y, d.z * r.z) * k)
			row_n.append(Vector3(d.x / r.x, d.y / r.y, d.z / r.z).normalized())
		pts.append(row_p)
		nrm.append(row_n)
	var circ: float = TAU * (r.x + r.z) * 0.5
	for i in range(rings):
		for j in range(segs):
			var j1: int = (j + 1) % segs
			var u0: float = circ * float(j) / float(segs)
			var u1: float = circ * float(j + 1) / float(segs)
			var v0: float = r.y * 1.6 * float(i) / float(rings)
			var v1: float = r.y * 1.6 * float(i + 1) / float(rings)
			var p00: Vector3 = pts[i][j]
			var p01: Vector3 = pts[i][j1]
			var p10: Vector3 = pts[i + 1][j]
			var p11: Vector3 = pts[i + 1][j1]
			var out: Vector3 = (nrm[i][j] + nrm[i + 1][j1]).normalized()
			if i == rings - 1:
				_lt(pk, kit, key, p00, p01, p10, nrm[i][j], nrm[i][j1], nrm[i + 1][j], col, out, Vector2(u0, v0), Vector2(u1, v0), Vector2((u0 + u1) * 0.5, v1))
			else:
				_lt(pk, kit, key, p00, p01, p11, nrm[i][j], nrm[i][j1], nrm[i + 1][j1], col, out, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1))
				_lt(pk, kit, key, p00, p11, p10, nrm[i][j], nrm[i + 1][j1], nrm[i + 1][j], col, out, Vector2(u0, v0), Vector2(u1, v1), Vector2(u0, v1))


## A "gflower" colour: the blossom colour (sRGB) and the kind (garden_flowers.gdshader's table) in the alpha.
static func _fk(c: Color, kind: int) -> Color:
	return Color(c.r, c.g, c.b, (float(kind) + 0.5) / 16.0)


## A "gleaf" colour: the colour and the mode in the alpha (garden_foliage.gdshader's table).
static func _gm(c: Color, mode: float) -> Color:
	return Color(c.r, c.g, c.b, mode)


## A ring of small boxes (a polyline beam) along `pts`: ironwork scrolls and curved members.
static func _bars(pk: PropKit, kit: Dictionary, key: String, pts: Array, w: float, t: float, col: Color, side := Vector3.ZERO) -> void:
	for i in range(pts.size() - 1):
		pk.beam(kit, key, pts[i], pts[i + 1], w, t, col, side)


## Points along a scroll (a spiral of `turns` turns from radius r0 out to r1) in the plane through c spanned by ax, ay.
static func _scroll_pts(c: Vector3, ax: Vector3, ay: Vector3, r0: float, r1: float, a0: float, turns: float, n := 10) -> Array:
	var out: Array = []
	for k in range(n + 1):
		var t: float = float(k) / float(n)
		var a: float = a0 + t * turns * TAU
		var r: float = lerpf(r0, r1, t)
		out.append(c + (ax * cos(a) + ay * sin(a)) * r)
	return out


## A small lantern (cast iron and glass, the glass unlit by day: "lens") standing on `base`, `s` its scale (1: 0.9m).
static func _lantern(pk: PropKit, kit: Dictionary, base: Vector3, s := 1.0) -> void:
	var cast := Color(0.10, 0.12, 0.11)
	var rot := Basis(UP, PI * 0.25)
	pk.lathe(kit, "steel", base, [Vector2(0.001, 0.0), Vector2(0.12 * s, 0.0), Vector2(0.15 * s, 0.04 * s), Vector2(0.12 * s, 0.09 * s), Vector2(0.001, 0.09 * s)], 4, cast, true, rot)
	pk.lathe(kit, "lens", base + Vector3(0, 0.08 * s, 0), [Vector2(0.001, 0.0), Vector2(0.15 * s, 0.0), Vector2(0.21 * s, 0.44 * s), Vector2(0.001, 0.44 * s)], 4,
			Color(0.95, 0.92, 0.80), true, rot)
	for k in 4:
		var a: float = PI * 0.5 * float(k)
		var c := Vector3(cos(a), 0, sin(a))
		var sd := Vector3(-sin(a), 0, cos(a))
		var c0: Vector3 = base + Vector3(0, 0.08 * s, 0) + (c + sd) * 0.112 * s
		var c1: Vector3 = base + Vector3(0, 0.52 * s, 0) + (c + sd) * 0.157 * s
		pk.beam(kit, "steel", c0, c1, 0.025 * s, 0.025 * s, cast)
	pk.lathe(kit, "steel", base + Vector3(0, 0.51 * s, 0), [Vector2(0.27 * s, 0.0), Vector2(0.32 * s, 0.04 * s), Vector2(0.15 * s, 0.25 * s), Vector2(0.06 * s, 0.32 * s),
			Vector2(0.001, 0.33 * s)], 4, cast, true, rot)
	pk.lathe(kit, "steel", base + Vector3(0, 0.505 * s, 0), [Vector2(0.001, 0.0), Vector2(0.32 * s, 0.045 * s)], 4, cast.darkened(0.3), true, rot)
	pk.lathe(kit, "steel", base + Vector3(0, 0.83 * s, 0), [Vector2(0.03 * s, 0.0), Vector2(0.05 * s, 0.05 * s), Vector2(0.001, 0.16 * s)], 6, cast, true)


# ======================================================================================
#  Tropical plants (the Palmenhaus's; they work anywhere)
# ======================================================================================

const PALM_GREEN := Color(0.20, 0.37, 0.10)
const KENTIA_GREEN := Color(0.16, 0.33, 0.10)
const FAN_GREEN := Color(0.22, 0.40, 0.22)
const BANANA_GREEN := Color(0.38, 0.58, 0.14)
const FERN_GREEN := Color(0.30, 0.50, 0.10)
const ALOCASIA_GREEN := Color(0.06, 0.16, 0.08)
const MONSTERA_GREEN := Color(0.10, 0.27, 0.07)
const STRAP_GREEN := Color(0.16, 0.32, 0.12)
const TRUNK_GREY := Color(0.55, 0.51, 0.45)
const TRUNK_BROWN := Color(0.40, 0.31, 0.22)
const FIBRE_BROWN := Color(0.30, 0.20, 0.12)
const CROWNSHAFT := Color(0.34, 0.46, 0.20)
const DEAD_FROND := Color(0.48, 0.36, 0.18)

## A feather palm (a Kentia or king palm) standing on `base`: a slender ringed trunk `height` tall bending toward `lean`
## (the crown's offset in plan from over the base), a smooth green crownshaft, `n` arching fronds `flen` long and a spear
## leaf. The crown is at base + (lean.x, height, lean.z).
static func feather_palm(pk: PropKit, kit: Dictionary, base: Vector3, height: float, lean: Vector3, n: int, flen: float, rng: RandomNumberGenerator,
		col := PALM_GREEN) -> void:
	var pts: Array = []
	var radii: Array = []
	var cols: Array = []
	var segs := 10
	var r0: float = clampf(height * 0.016, 0.14, 0.3)
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		pts.append(base + Vector3(lean.x * t * t, height * 0.9 * t - 0.4 * (1.0 - t), lean.z * t * t))
		radii.append(r0 * (1.0 + 0.35 * pow(1.0 - t, 6.0)) * lerpf(1.0, 0.72, t))
		cols.append(_gm(TRUNK_GREY.lerp(TRUNK_GREY.darkened(0.25), rng.randf() * 0.3), 0.9))
	_tube(pk, kit, "gleaf", pts, radii, 9, cols, false, true)
	# The crownshaft: the fronds' sheaths, smooth and green, a little thicker than the trunk.
	var top: Vector3 = pts[segs]
	var tdir: Vector3 = (pts[segs] - pts[segs - 1]).normalized()
	var crown: Vector3 = top + tdir * (height * 0.1)
	_tube(pk, kit, "gleaf", [top - tdir * 0.05, top + tdir * (height * 0.05), crown], [radii[segs] * 1.05, radii[segs] * 1.12, radii[segs] * 0.85], 9,
			_gm(CROWNSHAFT, 1.0), false, true)
	# Fronds: a spiral of them, the youngest standing up, the oldest hanging.
	var a0: float = rng.randf() * TAU
	for k in range(n):
		var age: float = float(k) / float(maxi(n - 1, 1))
		var az: float = a0 + float(k) * 2.39996
		var el: float = lerpf(1.05, -0.35, age) + rng.randf_range(-0.12, 0.12)
		var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var fl: float = flen * rng.randf_range(0.85, 1.05) * lerpf(0.8, 1.0, minf(age * 3.0, 1.0))
		var droop: float = fl * lerpf(0.22, 0.5, age)
		var fc: Color = col.lerp(col.darkened(0.2), rng.randf() * 0.5)
		if age > 0.92 and rng.randf() < 0.5:
			fc = DEAD_FROND
		_card(pk, kit, crown - Vector3(0, 0.1, 0) + dir * 0.12, dir, fl, fl * 0.2, droop, 0.32, _gm(fc, 0.7), float(rng.randi_range(0, 900)), 7,
				rng.randf_range(-0.3, 0.3))
	# The spear leaf: the next frond, still furled.
	_card(pk, kit, crown, (tdir + Vector3(0, 1.5, 0)).normalized(), flen * 0.35, 0.04, 0.0, 0.0, _gm(col.lightened(0.15), 0.2), 3.0, 2)


## A fan palm (a Chinese fan palm) on `base`: a stout ringed trunk `height` tall leaning to `lean`, a crown of `n` fan
## leaves `radius` across on long petioles, with a skirt of dead leaves hanging under it when `skirt`.
static func fan_palm(pk: PropKit, kit: Dictionary, base: Vector3, height: float, lean: Vector3, n: int, radius: float, rng: RandomNumberGenerator,
		skirt := true, col := FAN_GREEN) -> void:
	var pts: Array = []
	var radii: Array = []
	var segs := 8
	var r0: float = clampf(height * 0.035, 0.14, 0.32)
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		pts.append(base + Vector3(lean.x * t * t, height * t - 0.4 * (1.0 - t), lean.z * t * t))
		radii.append(r0 * (1.0 + 0.3 * pow(1.0 - t, 5.0)) * lerpf(1.0, 0.85, t))
	_tube(pk, kit, "gleaf", pts, radii, 9, _gm(TRUNK_BROWN, 0.9), false, true)
	var top: Vector3 = pts[segs]
	# The leaf bases' boot under the crown.
	_tube(pk, kit, "gleaf", [top - Vector3(0, height * 0.12, 0), top, top + Vector3(0, 0.25, 0)], [radii[segs] * 1.1, radii[segs] * 1.35, radii[segs] * 0.6], 9,
			_gm(FIBRE_BROWN, 0.8), true, true)
	var a0: float = rng.randf() * TAU
	for k in range(n):
		var age: float = float(k) / float(maxi(n - 1, 1))
		var az: float = a0 + float(k) * 2.39996
		var el: float = lerpf(1.0, -0.1, age) + rng.randf_range(-0.1, 0.1)
		var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var plen: float = radius * rng.randf_range(0.8, 1.15)
		var p0: Vector3 = top + Vector3(0, 0.1, 0)
		var p1: Vector3 = p0 + dir * plen * 0.55 + Vector3(0, -plen * 0.05, 0)
		var p2: Vector3 = p0 + dir * plen + Vector3(0, -plen * 0.15 * age, 0)
		_tube(pk, kit, "gleaf", [p0, p1, p2], [0.035, 0.03, 0.025], 4, _gm(col.darkened(0.15), 1.0), false, true)
		var axis: Vector3 = (p2 - p1).normalized()
		axis = (axis + Vector3(0, 0.35, 0)).normalized()
		var lat: Vector3 = axis.cross(UP)
		if lat.length_squared() < 1e-3:
			lat = Vector3.RIGHT
		lat = lat.normalized()
		var fc: Color = col.lerp(col.lightened(0.15), rng.randf() * 0.6)
		_fan(pk, kit, p2, axis, lat, radius * rng.randf_range(0.85, 1.05), 4.2, radius * lerpf(0.3, 0.55, age), _gm(fc, 0.6), float(rng.randi_range(0, 900)))
	if skirt:
		for k in range(5):
			var az2: float = a0 + TAU * float(k) / 5.0 + rng.randf_range(-0.3, 0.3)
			var d2 := Vector3(cos(az2), 0, sin(az2))
			var hang: Vector3 = top + d2 * (radii[segs] * 1.2) + Vector3(0, -0.2, 0)
			_fan(pk, kit, hang, (d2 * 0.25 + Vector3(0, -1, 0)).normalized(), Vector3(-d2.z, 0, d2.x), radius * 0.75, 2.4, 0.05,
					_gm(DEAD_FROND.darkened(rng.randf() * 0.3), 0.6), float(rng.randi_range(0, 900)))


## A clump of bananas on `base`: `stems` pseudostems `height` tall with their paddle leaves (torn along the veins),
## a dead leaf hanging down each stem, and on the first a hanging bunch with its purple bud. `away` (unit, or zero)
## turns the clump's leaves away from it (the road).
static func banana(pk: PropKit, kit: Dictionary, base: Vector3, height: float, rng: RandomNumberGenerator, stems := 3, away := Vector3.ZERO) -> void:
	for s in range(stems):
		var off := Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) if s > 0 else Vector3.ZERO
		var h: float = height * (1.0 if s == 0 else rng.randf_range(0.55, 0.85))
		var sb: Vector3 = base + off
		var top: Vector3 = sb + Vector3(rng.randf_range(-0.15, 0.15), h * 0.62, rng.randf_range(-0.15, 0.15))
		_tube(pk, kit, "gleaf", [sb - Vector3(0, 0.3, 0), sb + Vector3(0, h * 0.3, 0), top], [0.2, 0.16, 0.11], 8, _gm(Color(0.34, 0.40, 0.18), 1.0), false, true)
		var nl: int = rng.randi_range(6, 8)
		var a0: float = rng.randf() * TAU
		for k in range(nl):
			var age: float = float(k) / float(nl - 1)
			var az: float = a0 + float(k) * 2.1
			var d := Vector3(cos(az), 0, sin(az))
			if away.length_squared() > 0.5 and d.dot(away) < -0.3:
				d = (d - away * (d.dot(away) + 0.3)).normalized()
			var el: float = lerpf(1.25, 0.35, age) + rng.randf_range(-0.1, 0.1)
			var dir: Vector3 = (d * cos(el) + UP * sin(el)).normalized()
			var ll: float = h * rng.randf_range(0.42, 0.55)
			var lb: Vector3 = top + Vector3(0, -age * 0.4, 0)
			_card(pk, kit, lb, dir, ll, ll * 0.2, ll * lerpf(0.2, 0.6, age), 0.22, _gm(BANANA_GREEN.lerp(BANANA_GREEN.darkened(0.25), rng.randf()), 0.5),
					float(rng.randi_range(0, 900)), 7, rng.randf_range(-0.4, 0.4))
		# Now and then a dead leaf hanging against the stem, folded flat.
		if rng.randf() < 0.35:
			var dd := Vector3(cos(a0 + 1.0), 0, sin(a0 + 1.0))
			_card(pk, kit, top + dd * 0.14 + Vector3(0, -0.1, 0), (dd * 0.2 + Vector3(0, -1, 0)).normalized(), h * 0.3, h * 0.035, 0.0, 1.2,
					_gm(DEAD_FROND.darkened(0.35), 0.5), float(rng.randi_range(0, 900)), 3)
		if s == 0:
			var dir2 := Vector3(cos(a0 + 2.5), 0, sin(a0 + 2.5))
			var p1: Vector3 = top + dir2 * 0.4 + Vector3(0, 0.2, 0)
			var p2: Vector3 = top + dir2 * 0.8 + Vector3(0, -0.6, 0)
			var p3: Vector3 = top + dir2 * 0.85 + Vector3(0, -1.4, 0)
			_tube(pk, kit, "gleaf", [top, p1, p2, p3], [0.05, 0.045, 0.04, 0.035], 6, _gm(Color(0.32, 0.42, 0.16), 1.0), false, true)
			# Hands of green fruit round the stalk, the bud (purple bracts) at its end.
			for hnd in range(4):
				var hp: Vector3 = p1.lerp(p2, 0.3 + 0.22 * float(hnd))
				for f in range(6):
					var fa: float = TAU * float(f) / 6.0 + float(hnd)
					var fd := Vector3(cos(fa), 0.9, sin(fa)).normalized()
					_tube(pk, kit, "gleaf", [hp, hp + fd * 0.16, hp + fd * 0.24 + Vector3(0, 0.08, 0)], [0.025, 0.028, 0.012], 4, _gm(Color(0.40, 0.55, 0.16), 1.0), false, true)
			_tube(pk, kit, "gleaf", [p3, p3 + Vector3(0, -0.12, 0), p3 + Vector3(0, -0.34, 0)], [0.09, 0.08, 0.01], 6, _gm(Color(0.36, 0.10, 0.18), 1.0), false, true)


## A tree fern (Dicksonia) on `base`: a fibrous trunk `height` tall, a crown of lacy fronds and a few croziers unrolling.
static func tree_fern(pk: PropKit, kit: Dictionary, base: Vector3, height: float, rng: RandomNumberGenerator, n := 12) -> void:
	var lean := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
	var pts: Array = []
	var radii: Array = []
	for i in range(6):
		var t: float = float(i) / 5.0
		pts.append(base + Vector3(lean.x * t, height * t - 0.3 * (1.0 - t), lean.z * t))
		radii.append(lerpf(0.3, 0.22, t) * (1.0 + 0.08 * sin(t * 9.0)))
	_tube(pk, kit, "gleaf", pts, radii, 9, _gm(FIBRE_BROWN, 0.8), true, true)
	var top: Vector3 = pts[5]
	var a0: float = rng.randf() * TAU
	for k in range(n):
		var az: float = a0 + TAU * float(k) / float(n) + rng.randf_range(-0.15, 0.15)
		var el: float = rng.randf_range(0.15, 0.75)
		var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var fl: float = rng.randf_range(1.9, 2.5) * clampf(height / 3.5, 0.7, 1.2)
		_card(pk, kit, top + Vector3(0, 0.05, 0) + dir * 0.15, dir, fl, fl * 0.24, fl * 0.55, 0.15, _gm(FERN_GREEN.lerp(FERN_GREEN.darkened(0.25), rng.randf()), 0.3),
				float(rng.randi_range(0, 900)), 6, rng.randf_range(-0.25, 0.25))
	for k in range(3):
		var az2: float = a0 + TAU * float(k) / 3.0 + 0.5
		var c := top + Vector3(cos(az2) * 0.08, 0.2, sin(az2) * 0.08)
		_tube(pk, kit, "gleaf", _scroll_pts(c + Vector3(0, 0.12, 0), Vector3(cos(az2), 0, sin(az2)), UP, 0.05, 0.14, -PI * 0.5, 0.9, 6),
				0.025, 4, _gm(Color(0.42, 0.40, 0.18), 1.0), false, true)


## An aroid on `base`: `kind` 0 an elephant's ear (Alocasia: dark heart-shaped leaves with pale veins, hanging from tall
## petioles), 1 a Swiss cheese plant (Monstera: torn and holed leaves). `size` the leaves' length; `away` (unit, or zero)
## turns the leaves toward it.
static func aroid(pk: PropKit, kit: Dictionary, base: Vector3, size: float, kind: int, rng: RandomNumberGenerator, away := Vector3.ZERO, n := 7) -> void:
	var col: Color = ALOCASIA_GREEN if kind == 0 else MONSTERA_GREEN
	var mode: float = 0.4 if kind == 0 else 0.35
	var a0: float = rng.randf() * TAU
	for k in range(n):
		var az: float = a0 + TAU * float(k) / float(n) + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(az), 0, sin(az))
		if away.length_squared() > 0.5:
			d = (d + away * 0.9).normalized()
		var plen: float = size * rng.randf_range(0.8, 1.3) * (1.1 if kind == 0 else 0.8)
		var el: float = rng.randf_range(0.7, 1.15)
		var p1: Vector3 = base + d * (plen * cos(el) * 0.5) + Vector3(0, plen * sin(el) * 0.55, 0)
		var tip: Vector3 = base + d * (plen * cos(el)) + Vector3(0, plen * sin(el) * 0.85, 0)
		_tube(pk, kit, "gleaf", [base + Vector3(0, -0.1, 0), p1, tip], [0.035 * size, 0.028 * size, 0.022 * size], 5, _gm(col.lightened(0.2), 1.0), false, true)
		var bl: float = size * rng.randf_range(0.8, 1.1)
		var dip: float = rng.randf_range(-0.9, -0.25) if kind == 0 else rng.randf_range(-0.5, 0.1)
		var bdir: Vector3 = (d * cos(dip) + UP * sin(dip)).normalized()
		_card(pk, kit, tip - bdir * (bl * 0.22), bdir, bl, bl * 0.42, bl * 0.06, 0.12, _gm(col.lerp(col.lightened(0.12), rng.randf()), mode), float(rng.randi_range(0, 900)), 4)


## A clump of strap-leaved plants on `base` (a bird of paradise with `flowers`, a clivia, a cordyline in `col`): `n`
## leaves `size` long fanning up from it.
static func strap_clump(pk: PropKit, kit: Dictionary, base: Vector3, size: float, rng: RandomNumberGenerator, col := STRAP_GREEN, flowers := false, n := 10,
		away := Vector3.ZERO) -> void:
	var a0: float = rng.randf() * TAU
	for k in range(n):
		var az: float = a0 + float(k) * 2.39996
		var d := Vector3(cos(az), 0, sin(az))
		if away.length_squared() > 0.5:
			d = (d + away * 0.7).normalized()
		var el: float = rng.randf_range(0.75, 1.35)
		var dir: Vector3 = (d * cos(el) + UP * sin(el)).normalized()
		var ll: float = size * rng.randf_range(0.7, 1.1)
		_card(pk, kit, base + d * 0.05, dir, ll, ll * 0.09, ll * 0.3, 0.3, _gm(col.lerp(col.lightened(0.15), rng.randf()), 0.2), float(rng.randi_range(0, 900)), 4,
				rng.randf_range(-0.5, 0.5))
	if flowers:
		# Strelitzia's birds: a beak-shaped spathe on a stalk, orange crests and a blue tongue.
		for f in range(3):
			var az2: float = a0 + TAU * float(f) / 3.0 + 0.4
			var d2 := Vector3(cos(az2), 0, sin(az2))
			var head: Vector3 = base + d2 * (size * 0.2) + Vector3(0, size * rng.randf_range(0.75, 0.95), 0)
			_tube(pk, kit, "gleaf", [base, head], [0.02, 0.015], 4, _gm(STRAP_GREEN.lightened(0.1), 1.0), false, true)
			var beak: Vector3 = head + d2 * 0.28 + Vector3(0, 0.03, 0)
			_tube(pk, kit, "gleaf", [head - d2 * 0.05, head + d2 * 0.12, beak], [0.035, 0.03, 0.005], 5, _gm(Color(0.25, 0.35, 0.22), 1.0), false, true)
			for c in range(3):
				var cp: Vector3 = head + d2 * (0.05 + 0.06 * float(c))
				var cd: Vector3 = (UP * 1.0 - d2 * 0.4 + Vector3(0, 0, 0)).normalized()
				_card(pk, kit, cp, cd, 0.18, 0.025, -0.02, 0.0, _gm(Color(0.98, 0.52, 0.06), 0.2), float(c), 2)
			_card(pk, kit, head + d2 * 0.1 + Vector3(0, 0.02, 0), (UP + d2 * 0.6).normalized(), 0.13, 0.02, 0.0, 0.0, _gm(Color(0.18, 0.22, 0.75), 0.2), 7.0, 2)


## A ground fern (a sword fern) on `base`: `n` fronds `size` long arching out of it.
static func fern_clump(pk: PropKit, kit: Dictionary, base: Vector3, size: float, rng: RandomNumberGenerator, n := 9, col := FERN_GREEN) -> void:
	var a0: float = rng.randf() * TAU
	for k in range(n):
		var az: float = a0 + TAU * float(k) / float(n) + rng.randf_range(-0.2, 0.2)
		var el: float = rng.randf_range(0.5, 1.2)
		var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var fl: float = size * rng.randf_range(0.75, 1.1)
		_card(pk, kit, base, dir, fl, fl * 0.16, fl * 0.5, 0.1, _gm(col.lerp(col.lightened(0.2), rng.randf()), 0.3), float(rng.randi_range(0, 900)), 4)


## A low leafy mound on `base` (ground cover: coleus, caladium, begonia foliage): a "gflower" clump `r` across in `col`
## as `kind` (6 coloured foliage, 0 plain green, 1 begonia in flower).
static func leaf_mound(pk: PropKit, kit: Dictionary, base: Vector3, r: float, col: Color, kind: int, rng: RandomNumberGenerator) -> void:
	_lump(pk, kit, "gflower", base + Vector3(0, -0.05, 0), Vector3(r, r * 0.55, r * rng.randf_range(0.8, 1.1)), _fk(col, kind), rng, 7, 3, 0.2)


## A leafy shrub on `base` (a rubber plant, a philodendron or, with `croton`, crotons' yellow-veined, red-blotched leaves):
## `stems` stems up to `h`, each with a cluster of broad ovate leaves ("gleaf" mode 0.45) at and below its top.
static func leafy_shrub(pk: PropKit, kit: Dictionary, base: Vector3, h: float, rng: RandomNumberGenerator, col := Color(0.10, 0.28, 0.08), croton := false,
		stems := 4) -> void:
	for s in range(stems):
		var a: float = rng.randf() * TAU
		var d := Vector3(cos(a), 0, sin(a))
		var hh: float = h * rng.randf_range(0.6, 1.0)
		var top: Vector3 = base + d * (hh * 0.25) + Vector3(0, hh * 0.8, 0)
		_tube(pk, kit, "gleaf", [base + Vector3(0, -0.1, 0), base + d * (hh * 0.1) + Vector3(0, hh * 0.45, 0), top], [0.03, 0.025, 0.018], 4,
				_gm(Color(0.30, 0.26, 0.16), 1.0), false, true)
		var nl: int = rng.randi_range(5, 8)
		for k in range(nl):
			var t: float = float(k) / float(nl)
			var at: Vector3 = top.lerp(base + Vector3(0, hh * 0.35, 0), t * 0.7)
			var az: float = a + float(k) * 2.4
			var el: float = lerpf(0.6, -0.4, t) + rng.randf_range(-0.2, 0.2)
			var ld := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
			var ll: float = h * rng.randf_range(0.28, 0.4)
			var idv: float = float(rng.randi_range(0, 450) * 2 + (1 if croton else 0))
			# The croton's draw: GardenKit leaves pick by hash(id); push the id until it lands the right way.
			var lc: Color = col.lerp(col.lightened(0.2), rng.randf())
			_card(pk, kit, at, ld, ll, ll * 0.32, ll * 0.15, 0.25, _gm(lc, 0.45), _croton_id(idv, croton), 3, rng.randf_range(-0.3, 0.3))


## An id for a "gleaf" ovate leaf whose croton draw (hash(id, 5) > 0.55 in the shader) is `croton`.
static func _croton_id(start: float, croton: bool) -> float:
	var id: float = floor(start)
	for k in range(40):
		var hv: float = _hash12(Vector2(id, 5.0))
		if (hv > 0.55) == croton:
			return id
		id += 1.0
	return id


## garden_foliage's hash12, on the CPU (float32 differs a little; only used to choose ids, not to match pixels).
static func _hash12(p: Vector2) -> float:
	var q := Vector2(fposmod(p.x * 123.34, 1.0), fposmod(p.y * 456.21, 1.0))
	var d: float = q.dot(q + Vector2(45.32, 45.32))
	q += Vector2(d, d)
	return fposmod(q.x * q.y, 1.0)


## A cordyline (ti plant) on `base`: a bare stem `h` tall with a topknot of strap leaves in `col` (red, purple, bronze).
static func cordyline(pk: PropKit, kit: Dictionary, base: Vector3, h: float, col: Color, rng: RandomNumberGenerator) -> void:
	var top: Vector3 = base + Vector3(rng.randf_range(-0.2, 0.2), h, rng.randf_range(-0.2, 0.2))
	_tube(pk, kit, "gleaf", [base + Vector3(0, -0.1, 0), base.lerp(top, 0.5) + Vector3(0.05, 0, 0), top], [0.04, 0.035, 0.03], 5, _gm(Color(0.40, 0.33, 0.24), 1.0), false, true)
	for k in range(14):
		var az: float = float(k) * 2.39996 + rng.randf()
		var el: float = lerpf(1.3, -0.2, float(k) / 14.0)
		var d := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var ll: float = h * rng.randf_range(0.35, 0.5)
		_card(pk, kit, top, d, ll, ll * 0.07, ll * 0.25, 0.2, _gm(col.lerp(col.lightened(0.25), rng.randf()), 0.2), float(rng.randi_range(0, 900)), 3)


## A dense green carpet over a bed (x0..x1, z0..z1 at y): a lumpy mat of low ferns and baby's tears ("gflower" kind 0,
## no flowers), 10-35cm high, its colour drifting from deep to fresh green and, here and there, bronze.
static func ground_cover(pk: PropKit, kit: Dictionary, x0: float, x1: float, z0: float, z1: float, y: float, seed_v: int, cell := 0.6) -> void:
	var nx: int = maxi(1, int(ceil((x1 - x0) / cell)))
	var nz: int = maxi(1, int(ceil((z1 - z0) / cell)))
	var hf := func(x: float, z: float) -> float:
		var e: float = minf(minf(x - x0, x1 - x), minf(z - z0, z1 - z))
		return y + (0.08 + 0.25 * _vn2(x * 1.3, z * 1.3, seed_v)) * clampf(e / 0.4, 0.15, 1.0)
	var greens: Array = [Color(0.10, 0.24, 0.07), Color(0.16, 0.34, 0.08), Color(0.22, 0.40, 0.10), Color(0.30, 0.30, 0.10)]
	for i in range(nx):
		for j in range(nz):
			var xa: float = lerpf(x0, x1, float(i) / nx)
			var xb: float = lerpf(x0, x1, float(i + 1) / nx)
			var za: float = lerpf(z0, z1, float(j) / nz)
			var zb: float = lerpf(z0, z1, float(j + 1) / nz)
			var p00 := Vector3(xa, hf.call(xa, za), za)
			var p10 := Vector3(xb, hf.call(xb, za), za)
			var p11 := Vector3(xb, hf.call(xb, zb), zb)
			var p01 := Vector3(xa, hf.call(xa, zb), zb)
			var n: Vector3 = (p01 - p00).cross(p10 - p00).normalized()
			if n.y < 0.0:
				n = -n
			var c00: Color = _fk(_green_at(greens, xa, za, seed_v), 0)
			var c10: Color = _fk(_green_at(greens, xb, za, seed_v), 0)
			var c11: Color = _fk(_green_at(greens, xb, zb, seed_v), 0)
			var c01: Color = _fk(_green_at(greens, xa, zb, seed_v), 0)
			_ctri(pk, kit, "gflower", p00, p10, p11, n, c00, c10, c11, Vector2(xa, za), Vector2(xb, za), Vector2(xb, zb))
			_ctri(pk, kit, "gflower", p00, p11, p01, n, c00, c11, c01, Vector2(xa, za), Vector2(xb, zb), Vector2(xa, zb))


static func _green_at(greens: Array, x: float, z: float, seed_v: int) -> Color:
	var g: float = clampf(_vn2(x * 0.45, z * 0.45, seed_v + 7) * 3.0, 0.0, 2.999)
	var i: int = int(g)
	return (greens[i] as Color).lerp(greens[i + 1], g - float(i))


## PropKit.tri with a colour per corner (for smooth colour across a surface whose faces share one shader mode).
static func _ctri(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color,
		ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var st := pk.st(kit, key)
	var wa: Vector3 = pk.xf * a
	var wb: Vector3 = pk.xf * b
	var wc: Vector3 = pk.xf * c
	var wn: Vector3 = (pk._nb * n).normalized()
	if (wc - wa).cross(wb - wa).dot(wn) < 0.0:
		var tp: Vector3 = wb
		wb = wc
		wc = tp
		var tc: Color = cb
		cb = cc
		cc = tc
		var tu: Vector2 = ub
		ub = uc
		uc = tu
	for v in [[wa, ca, ua], [wb, cb, ub], [wc, cc, uc]]:
		st.set_color(v[1])
		st.set_normal(wn)
		st.set_uv(v[2])
		st.add_vertex(v[0])


## Value noise in 0..1 (smooth, deterministic by `seed_v`).
static func _vn2(x: float, z: float, seed_v: int) -> float:
	var ix: float = floor(x)
	var iz: float = floor(z)
	var fx: float = x - ix
	var fz: float = z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var s := float(seed_v) * 17.13
	var a: float = _hash12(Vector2(ix + s, iz))
	var b: float = _hash12(Vector2(ix + 1.0 + s, iz))
	var c: float = _hash12(Vector2(ix + s, iz + 1.0))
	var d: float = _hash12(Vector2(ix + 1.0 + s, iz + 1.0))
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


## A hanging basket: a chain from `hook` (a point on a rib) down `drop` metres to a wire basket lined with moss, ferns
## and fuchsias trailing over its rim. Nothing hangs more than 0.75m under the basket's rim.
static func hanging_basket(pk: PropKit, kit: Dictionary, hook: Vector3, drop: float, rng: RandomNumberGenerator) -> void:
	var rim: Vector3 = hook + Vector3(0, -drop, 0)
	for k in range(3):
		var a: float = TAU * float(k) / 3.0
		pk.beam(kit, "steel", hook, rim + Vector3(cos(a) * 0.3, 0.02, sin(a) * 0.3), 0.012, 0.012, IRON_DARK)
	pk.lathe(kit, "steel", rim + Vector3(0, -0.32, 0), [Vector2(0.001, 0.0), Vector2(0.12, 0.0), Vector2(0.24, 0.08), Vector2(0.31, 0.22), Vector2(0.33, 0.32),
			Vector2(0.001, 0.32)], 10, Color(0.20, 0.24, 0.14), true)
	_lump(pk, kit, "gflower", rim + Vector3(0, -0.02, 0), Vector3(0.36, 0.16, 0.36), _fk(Color(0.85, 0.15, 0.45), 14), rng, 8, 3, 0.25)
	for k in range(7):
		var a2: float = TAU * float(k) / 7.0 + rng.randf() * 0.4
		var d := Vector3(cos(a2), 0, sin(a2))
		var dir: Vector3 = (d * 0.5 + Vector3(0, -0.85, 0)).normalized()
		_card(pk, kit, rim + d * 0.25, dir, 0.6, 0.09, 0.0, 0.1, _gm(FERN_GREEN.lightened(0.1), 0.3), float(rng.randi_range(0, 900)), 3)


## A climbing philodendron up a column: small heart leaves spiralling round it from y0 to y1, `r` the column's radius.
static func column_climber(pk: PropKit, kit: Dictionary, c: Vector3, r: float, y0: float, y1: float, rng: RandomNumberGenerator) -> void:
	var n: int = int((y1 - y0) / 0.32)
	for k in range(n):
		var y: float = y0 + (y1 - y0) * float(k) / float(n)
		var a: float = float(k) * 1.9 + rng.randf() * 0.5
		var d := Vector3(cos(a), 0, sin(a))
		var at: Vector3 = c + d * (r + 0.03) + Vector3(0, y, 0)
		var dir: Vector3 = (d * 0.7 + Vector3(0, -0.6, 0) + Vector3(-d.z, 0, d.x) * 0.3).normalized()
		_card(pk, kit, at, dir, 0.32, 0.14, 0.02, 0.1, _gm(MONSTERA_GREEN.lightened(0.18), 0.4), float(rng.randi_range(0, 900)), 2, 0.0, d)


# ======================================================================================
#  The Palmenhaus
# ======================================================================================

## The height of the wings' vault (their glass) over |x| (life metres; the eave's height past the walls).
static func wing_roof_y(x: float) -> float:
	var t: float = clampf(absf(x) / PH_WING_HALF, 0.0, 1.0)
	return PH_WING_EAVE + PH_WING_RISE * sqrt(1.0 - t * t)


## The wings' cross-section: the glass from the left sill up the wall, over the vault and down to the right sill.
static func _wing_arch(n := 14) -> Array:
	var right: Array = [Vector2(PH_WING_HALF, PH_SILL), Vector2(PH_WING_HALF, PH_WING_EAVE)]
	for k in range(1, n + 1):
		var th: float = PI * 0.5 * float(k) / float(n)
		right.append(Vector2(PH_WING_HALF * cos(th), PH_WING_EAVE + PH_WING_RISE * sin(th)))
	right[right.size() - 1] = Vector2(0.0, PH_WING_EAVE + PH_WING_RISE)
	var out: Array = []
	for p in right:
		out.append(Vector2(-(p as Vector2).x, (p as Vector2).y))
	for k in range(right.size() - 2, -1, -1):
		out.append(right[k])
	return out


## The outward normal (in the x-y plane) of the arch's segment from a to b (walked left to right over the top).
static func _arch_out(a: Vector2, b: Vector2) -> Vector2:
	var d: Vector2 = (b - a).normalized()
	return Vector2(-d.y, d.x)


## The pavilion's curved hipped roof: (inset from the walls, height) at `t` 0 (the eaves) to 1 (the ring).
static func _pav_vault(t: float) -> Vector2:
	var th: float = t * PI * 0.5
	return Vector2((PH_PAV_HALF - PH_RING) * (1.0 - cos(th)), PH_PAV_EAVE + (PH_RING_Y - PH_PAV_EAVE) * sin(th))


## The Palmenhaus: the route drives straight through it along z on x = 0 (the floor there is the caller's road). Two
## vaulted wings (z +-14.5..32) either side of a square central pavilion (|x|, |z| <= 14.5) under a curved hipped roof, a
## drum and a glass dome (21.8m, its finial 24.2m); arched portals with PALMENHAUS over them at both ends (+z and -z);
## white-painted ironwork, one sheet of glass per pane plane ("gglass"), a sandstone plinth round it; inside, beds either
## side of the road with palms of several kinds (the tallest under the dome), bananas, tree ferns, aroids, ferns, a lily
## pool, climbers up the pavilion's columns and baskets hanging over the road. The corridor (|x| <= PH_CLEAR_X, and
## |x| <= PH_KERB_X but for the kerb, below PH_CLEAR_Y, |z| <= PH_CLEAR_Z) is clear. About 120k triangles.
static func palm_house(pk: PropKit, kit: Dictionary, labels: Array, seed_v := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	_ph_plinths(pk, kit)
	for sz in [1.0, -1.0]:
		_ph_wing(pk, kit, sz)
	_ph_pavilion(pk, kit)
	_ph_portal(pk, kit, labels, Transform3D.IDENTITY)
	_ph_portal(pk, kit, labels, Transform3D(Basis(UP, PI), Vector3.ZERO))
	_ph_floor(pk, kit)
	_clamp_corr = true
	_ph_planting(pk, kit, rng)
	_clamp_corr = false


## The sandstone plinth round the house (to y -1.5, its coping at PH_SILL), the beds' kerbs along the road.
static func _ph_plinths(pk: PropKit, kit: Dictionary) -> void:
	var st := SAND
	var cop := SAND_LIGHT
	var w0: float = PH_WING_HALF - 0.25
	var w1: float = PH_WING_HALF + 0.25
	var p0: float = PH_PAV_HALF - 0.25
	var p1: float = PH_PAV_HALF + 0.25
	for sx in [1.0, -1.0]:
		# The wings' sides.
		for sz in [1.0, -1.0]:
			var za: float = sz * (PH_PAV_HALF - 0.2)
			var zb: float = sz * (PH_END + 0.25)
			_mblock(pk, kit, "ashlar", Vector3(sx * w0, -1.5, za), Vector3(sx * w1, PH_SILL - 0.1, zb), st)
			_mblock(pk, kit, "ashlar", Vector3(sx * (w0 - 0.07), PH_SILL - 0.1, za), Vector3(sx * (w1 + 0.07), PH_SILL + 0.02, zb + sz * 0.07), cop, true, true)
			# The ends' plinth beside the portal.
			_mblock(pk, kit, "ashlar", Vector3(sx * PH_PORTAL_HALF, -1.5, sz * (PH_END - 0.25)), Vector3(sx * w0, PH_SILL - 0.1, sz * (PH_END + 0.25)), st)
			_mblock(pk, kit, "ashlar", Vector3(sx * PH_PORTAL_HALF, PH_SILL - 0.1, sz * (PH_END - 0.32)), Vector3(sx * (w0 + 0.01), PH_SILL + 0.02, sz * (PH_END + 0.32)), cop, true, true)
			# The pavilion's walls beside the wings.
			_mblock(pk, kit, "ashlar", Vector3(sx * (w1 - 0.05), -1.5, sz * p0), Vector3(sx * p1, PH_SILL - 0.1, sz * p1), st)
			_mblock(pk, kit, "ashlar", Vector3(sx * (w1 + 0.02), PH_SILL - 0.1, sz * (p0 - 0.07)), Vector3(sx * (p1 + 0.07), PH_SILL + 0.02, sz * (p1 + 0.07)), cop, true, true)
			# Cast-iron grilles (the heating's vents) in the wing plinths, one a bay.
			for k in range(7):
				var zc: float = sz * (PH_PAV_HALF + 1.25 + 2.5 * float(k))
				_box(pk, kit, "steel", Vector3(sx * (w1 + 0.02), 0.35, zc), Basis(), Vector3(0.06, 0.32, 0.9), IRON_DARK)
		# The pavilion's sides.
		_mblock(pk, kit, "ashlar", Vector3(sx * p0, -1.5, -p1), Vector3(sx * p1, PH_SILL - 0.1, p1), st)
		_mblock(pk, kit, "ashlar", Vector3(sx * (p0 - 0.07), PH_SILL - 0.1, -p1 - 0.07), Vector3(sx * (p1 + 0.07), PH_SILL + 0.02, p1 + 0.07), cop, true, true)
		for k in range(6):
			_box(pk, kit, "steel", Vector3(sx * (p1 + 0.02), 0.35, -12.0 + 4.8 * float(k)), Basis(), Vector3(0.06, 0.32, 0.9), IRON_DARK)
		# The kerb along the road (top PH_KERB_TOP) and the beds' inner edge.
		_mblock(pk, kit, "ashlar", Vector3(sx * PH_CLEAR_X, -0.4, -PH_END - 0.25), Vector3(sx * (PH_CLEAR_X + 0.42), PH_KERB_TOP - 0.02, PH_END + 0.25), SAND_LIGHT)


## The beds inside: soil (y 0.1, from the kerb to the plinth), dark and uneven, and over it, from 0.3m off the
## corridor's edge, a dense green carpet of low ferns.
static func _ph_floor(pk: PropKit, kit: Dictionary) -> void:
	for sx in [1.0, -1.0]:
		var x0: float = PH_CLEAR_X + 0.42
		_soil(pk, kit, Vector3(sx * x0, 0.1, -PH_PAV_HALF + 0.25), Vector3(sx * (PH_PAV_HALF - 0.25), 0.1, PH_PAV_HALF - 0.25))
		var c0: float = PH_KERB_X + 0.3
		var ca: float = minf(sx * c0, sx * (PH_PAV_HALF - 0.3))
		var cb: float = maxf(sx * c0, sx * (PH_PAV_HALF - 0.3))
		ground_cover(pk, kit, ca, cb, -PH_PAV_HALF + 0.3, PH_PAV_HALF - 0.3, 0.06, 11 + int(sx))
		for sz in [1.0, -1.0]:
			_soil(pk, kit, Vector3(sx * x0, 0.1, sz * (PH_PAV_HALF - 0.25)), Vector3(sx * (PH_WING_HALF - 0.25), 0.1, sz * (PH_END - 0.25)))
			var wa: float = minf(sx * c0, sx * (PH_WING_HALF - 0.3))
			var wb: float = maxf(sx * c0, sx * (PH_WING_HALF - 0.3))
			var za: float = minf(sz * (PH_PAV_HALF + 0.3), sz * (PH_END - 0.35))
			var zb: float = maxf(sz * (PH_PAV_HALF + 0.3), sz * (PH_END - 0.35))
			ground_cover(pk, kit, wa, wb, za, zb, 0.06, 21 + int(sx) * 3 + int(sz))


## A rectangle of soil (corners a, b at their own y), in 1m squares of slightly varied colour.
static func _soil(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3) -> void:
	var lo := Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), a.y, maxf(a.z, b.z))
	var nx: int = maxi(1, int(ceil((hi.x - lo.x) / 1.2)))
	var nz: int = maxi(1, int(ceil((hi.z - lo.z) / 1.2)))
	for i in range(nx):
		for j in range(nz):
			var x0: float = lerpf(lo.x, hi.x, float(i) / nx)
			var x1: float = lerpf(lo.x, hi.x, float(i + 1) / nx)
			var z0: float = lerpf(lo.z, hi.z, float(j) / nz)
			var z1: float = lerpf(lo.z, hi.z, float(j + 1) / nz)
			var k: float = 0.85 + 0.3 * fposmod(sin(x0 * 12.9898 + z0 * 78.233) * 43758.5453, 1.0)
			var c: Color = SOIL.lerp(MULCH, fposmod(sin(x0 * 3.1 + z0 * 7.7) * 921.3, 1.0) * 0.7) * k
			pk.quad(kit, "matte", [Vector3(x0, lo.y, z0), Vector3(x1, lo.y, z0), Vector3(x1, lo.y, z1), Vector3(x0, lo.y, z1)], UP, c)


## One wing (sz +1: z 14.5..32, -1 the other way): its glass (walls and vault), ribs every 2.5m, purlins, the eaves'
## gutters, the ridge's cresting, the end gable's glass round the portal and its mullions.
static func _ph_wing(pk: PropKit, kit: Dictionary, sz: float) -> void:
	var arch: Array = _wing_arch()
	var za: float = sz * PH_PAV_HALF
	var zb: float = sz * PH_END
	var z0: float = minf(za, zb)
	var z1: float = maxf(za, zb)
	# Glass: one strip per segment of the arch, the length of the wing.
	var run := 0.0
	var outs: Array = []
	for i in range(arch.size() - 1):
		var a: Vector2 = arch[i]
		var b: Vector2 = arch[i + 1]
		var o: Vector2 = _arch_out(a, b)
		outs.append(o)
		var l: float = a.distance_to(b)
		var n3 := Vector3(o.x, o.y, 0)
		pk.quad(kit, "gglass", [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)], n3, WHITE,
				[Vector2(z0, run), Vector2(z0, run + l), Vector2(z1, run + l), Vector2(z1, run)])
		run += l
	# The normal at each arch point (the mean of its segments').
	var pn: Array = []
	for i in range(arch.size()):
		var o2: Vector2 = Vector2.ZERO
		if i > 0:
			o2 += outs[i - 1]
		if i < outs.size():
			o2 += outs[i]
		pn.append(o2.normalized())
	# Ribs: the arch's line 9cm inside the glass, 11cm wide, 20cm deep; brackets where the walls meet the vault.
	for k in range(8):
		var zr: float = sz * (PH_PAV_HALF + 2.5 * float(k))
		var pts: Array = []
		for i in range(arch.size()):
			var p: Vector2 = arch[i] - pn[i] * 0.09
			pts.append(Vector3(p.x, p.y, zr))
		_bars(pk, kit, "paint", pts, 0.2, 0.11, IRON_WHITE, Vector3(0, 0, 1))
		for sx in [1.0, -1.0]:
			# A quadrant bracket with a scroll inside the eave.
			var c := Vector3(sx * (PH_WING_HALF - 0.75), PH_WING_EAVE - 0.75, zr)
			_bars(pk, kit, "paint", _scroll_pts(c, Vector3(sx, 0, 0), UP, 0.66, 0.66, -PI * 0.5, 0.25, 5), 0.06, 0.05, IRON_WHITE, Vector3(0, 0, 1))
			_bars(pk, kit, "paint", _scroll_pts(c + Vector3(sx * 0.2, 0.2, 0), Vector3(sx, 0, 0), UP, 0.06, 0.28, PI, 0.85, 8), 0.04, 0.04, IRON_WHITE, Vector3(0, 0, 1))
	# Purlins along the wing at the eaves, up the vault and at the ridge; a transom across each wall.
	var pis: Array = [1, 4, 7, 10, 13, 15]
	for i in pis:
		for side in [0, 1]:
			var idx: int = i if side == 0 else arch.size() - 1 - i
			if side == 1 and idx == i:
				continue
			var p2: Vector2 = arch[idx] - pn[idx] * 0.06
			pk.beam(kit, "paint", Vector3(p2.x, p2.y, z0), Vector3(p2.x, p2.y, z1), 0.07, 0.09, IRON_WHITE)
	for sx in [1.0, -1.0]:
		pk.beam(kit, "paint", Vector3(sx * (PH_WING_HALF - 0.05), 2.6, z0), Vector3(sx * (PH_WING_HALF - 0.05), 2.6, z1), 0.07, 0.08, IRON_WHITE)
		# The cast-iron gutter along the eave, outside.
		_box(pk, kit, "paint", Vector3(sx * (PH_WING_HALF + 0.12), PH_WING_EAVE - 0.02, (z0 + z1) * 0.5), Basis(), Vector3(0.26, 0.2, z1 - z0 + 0.1), IRON_WHITE.darkened(0.05))
		# Thin mullions between the ribs on the walls.
		for k in range(15):
			var zm: float = sz * (PH_PAV_HALF + 1.25 * float(k) + 0.625)
			if absf(zm) > PH_END - 0.1:
				continue
			pk.beam(kit, "paint", Vector3(sx * (PH_WING_HALF - 0.04), PH_SILL, zm), Vector3(sx * (PH_WING_HALF - 0.04), PH_WING_EAVE, zm), 0.06, 0.06, IRON_WHITE)
	# The ridge: a bar along the top and its cresting (posts with fleurons, a rail).
	var ry: float = PH_WING_EAVE + PH_WING_RISE
	pk.beam(kit, "paint", Vector3(0, ry + 0.04, z0), Vector3(0, ry + 0.04, z1), 0.14, 0.12, IRON_WHITE)
	var nc: int = int((z1 - z0) / 0.55)
	for k in range(nc + 1):
		var zc: float = lerpf(z0, z1, float(k) / float(nc))
		var tall: bool = k % 2 == 0
		pk.beam(kit, "paint", Vector3(0, ry + 0.08, zc), Vector3(0, ry + (0.42 if tall else 0.3), zc), 0.035, 0.035, IRON_WHITE)
		KT._blob(pk, kit, "paint", Vector3(0, ry + (0.48 if tall else 0.34), zc), Vector3(0.05, 0.09 if tall else 0.06, 0.05), IRON_WHITE)
	pk.beam(kit, "paint", Vector3(0, ry + 0.26, z0), Vector3(0, ry + 0.26, z1), 0.03, 0.03, IRON_WHITE)
	# The end gable: glass round the portal's opening, mullions and a transom.
	var gable := PackedVector2Array()
	for p in arch:
		gable.append(p)
	var open: PackedVector2Array = _portal_opening(-1.0)
	var pieces: Array = Geometry2D.clip_polygons(gable, open)
	var ze: float = zb - sz * 0.02
	var ne := Vector3(0, 0, sz)
	for poly in pieces:
		if Geometry2D.is_polygon_clockwise(poly) and pieces.size() > 1:
			continue
		_glass_poly(pk, kit, poly, ze, ne)
	for xm in [7.75, 9.0, 10.2]:
		for sx in [1.0, -1.0]:
			pk.beam(kit, "paint", Vector3(sx * xm, PH_SILL, zb - sz * 0.08), Vector3(sx * xm, wing_roof_y(xm) - 0.08, zb - sz * 0.08), 0.08, 0.1, IRON_WHITE)
	for sx in [1.0, -1.0]:
		pk.beam(kit, "paint", Vector3(sx * PH_PORTAL_HALF, PH_WING_EAVE, zb - sz * 0.08), Vector3(sx * (PH_WING_HALF - 0.1), PH_WING_EAVE, zb - sz * 0.08), 0.08, 0.1, IRON_WHITE, UP)


## The portal's opening in the gable plane: |x| <= PH_PORTAL_HALF from y0 up to the springing, a segmental arch over.
static func _portal_opening(y0: float) -> PackedVector2Array:
	var arc: PackedVector2Array = KT._arch(0.0, PH_PORTAL_SPRING, PH_PORTAL_HALF, "seg", 14, PH_PORTAL_CROWN - PH_PORTAL_SPRING)
	var out := PackedVector2Array()
	out.append(Vector2(-PH_PORTAL_HALF, y0))
	for p in arc:
		out.append(p)
	out.append(Vector2(PH_PORTAL_HALF, y0))
	return out


## A glass polygon (x, y) in the plane z = `z`, facing `n`, UVs (x, y) in life metres.
static func _glass_poly(pk: PropKit, kit: Dictionary, poly: PackedVector2Array, z: float, n: Vector3) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		var a: Vector2 = poly[tris[i]]
		var b: Vector2 = poly[tris[i + 1]]
		var c: Vector2 = poly[tris[i + 2]]
		pk.tri(kit, "gglass", Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), Vector3(c.x, c.y, z), n, n, n, WHITE, n, a, b, c)


## The central pavilion: glass walls with mullions and transoms, corner columns, the eaves' cornice, the curved hipped
## roof with its ribs and hips, the ring, the deck round the drum, the drum, the dome, the lantern; inside, four cast-iron
## columns carrying the ring on arched lattice girders.
static func _ph_pavilion(pk: PropKit, kit: Dictionary) -> void:
	var H: float = PH_PAV_HALF
	var E: float = PH_PAV_EAVE
	var nb := 12
	var bay: float = 2.0 * H / float(nb)
	# The wing's outline on the pavilion's faces (closed under the floor), for the glass's notch and the mullions.
	var wing := PackedVector2Array()
	for p in _wing_arch():
		wing.append(p)
	wing.append(Vector2(PH_WING_HALF, -1.0))
	wing.append(Vector2(-PH_WING_HALF, -1.0))
	for f in range(4):
		var e: Vector3 = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD][f]
		var l: Vector3 = e.cross(UP)    # along the face
		var notch: bool = f == 1 or f == 3
		# The wall's glass (u along l, v up).
		var rect := PackedVector2Array([Vector2(-H, PH_SILL), Vector2(H, PH_SILL), Vector2(H, E), Vector2(-H, E)])
		var polys: Array = [rect]
		if notch:
			polys = Geometry2D.clip_polygons(rect, wing)
		for poly in polys:
			var tris := Geometry2D.triangulate_polygon(poly)
			for i in range(0, tris.size(), 3):
				var a: Vector2 = poly[tris[i]]
				var b: Vector2 = poly[tris[i + 1]]
				var c: Vector2 = poly[tris[i + 2]]
				pk.tri(kit, "gglass", e * H + l * a.x + UP * a.y, e * H + l * b.x + UP * b.y, e * H + l * c.x + UP * c.y, e, e, e, WHITE, e, a, b, c)
		# Mullions (above the wing's vault on the notched faces) and transoms.
		for m in range(1, nb):
			var u: float = -H + bay * float(m)
			var y0: float = PH_SILL
			if notch and absf(u) < PH_WING_HALF:
				y0 = wing_roof_y(u) + 0.05
			pk.beam(kit, "paint", e * (H - 0.06) + l * u + UP * y0, e * (H - 0.06) + l * u + UP * E, 0.1, 0.2, IRON_WHITE, l)
		for ty in [PH_WING_EAVE, 8.0]:
			var x_in: float = 0.0
			if notch:
				var tt: float = clampf((ty - PH_WING_EAVE) / PH_WING_RISE, 0.0, 1.0)
				x_in = PH_WING_HALF * sqrt(1.0 - tt * tt) + 0.05
			for s in [1.0, -1.0]:
				if notch:
					pk.beam(kit, "paint", e * (H - 0.06) + l * (s * x_in) + UP * ty, e * (H - 0.06) + l * (s * H) + UP * ty, 0.12, 0.16, IRON_WHITE, UP)
				elif s > 0.0:
					pk.beam(kit, "paint", e * (H - 0.06) + l * (-H) + UP * ty, e * (H - 0.06) + l * H + UP * ty, 0.12, 0.16, IRON_WHITE, UP)
		# The eaves' cornice: a gutter and a moulded band, standing out of the wall. Odd faces' run into the even ones' at
		# the corners, 2cm lower, so no two tops share a plane.
		var ext: float = 0.3 if f % 2 == 0 else 0.0
		var dy: float = 0.0 if f % 2 == 0 else -0.02
		pk.beam(kit, "paint", e * (H + 0.1) + l * (-H - ext) + UP * (E - 0.1 + dy), e * (H + 0.1) + l * (H + ext) + UP * (E - 0.1 + dy), 0.3, 0.42, IRON_WHITE, UP)
		pk.beam(kit, "paint", e * (H + 0.05) + l * (-H - ext * 0.7) + UP * (E - 0.5 + dy), e * (H + 0.05) + l * (H + ext * 0.7) + UP * (E - 0.5 + dy), 0.12, 0.14,
				IRON_WHITE.darkened(0.06), UP)
		# The curved hipped roof's face: trapezoids from the eaves to the ring.
		var nv := 8
		var vrun := 0.0
		for k in range(nv):
			var v0: Vector2 = _pav_vault(float(k) / nv)
			var v1: Vector2 = _pav_vault(float(k + 1) / nv)
			var h0: float = H - v0.x
			var h1: float = H - v1.x
			var sl: float = v0.distance_to(v1)
			var nn: Vector3 = (e * (v1.y - v0.y) + UP * (v1.x - v0.x)).normalized()
			pk.quad(kit, "gglass", [e * h0 + l * (-h0) + UP * v0.y, e * h0 + l * h0 + UP * v0.y, e * h1 + l * h1 + UP * v1.y, e * h1 + l * (-h1) + UP * v1.y], nn, WHITE,
					[Vector2(-h0, vrun), Vector2(h0, vrun), Vector2(h1, vrun + sl), Vector2(-h1, vrun + sl)])
			vrun += sl
		# Its ribs, continuing the mullions up to the hips (or the ring).
		for m in range(1, nb):
			var u2: float = -H + bay * float(m)
			var d_max: float = H - absf(u2)
			var pts: Array = []
			for k in range(9):
				var t: float = float(k) / 8.0
				var v: Vector2 = _pav_vault(t)
				if v.x > d_max:
					var c0: float = 1.0 - d_max / (H - PH_RING)
					var tm: float = acos(clampf(c0, -1.0, 1.0)) / (PI * 0.5)
					v = _pav_vault(tm)
					pts.append(e * (H - v.x - 0.08) + l * u2 + UP * (v.y - 0.06))
					break
				pts.append(e * (H - v.x - 0.08) + l * u2 + UP * (v.y - 0.06))
			if pts.size() > 1:
				_bars(pk, kit, "paint", pts, 0.18, 0.1, IRON_WHITE, l)
		# The hip rib at this face's left corner.
		var hip: Array = []
		for k in range(9):
			var v3: Vector2 = _pav_vault(float(k) / 8.0)
			var hh: float = H - v3.x - 0.06
			hip.append(e * hh + l * (-hh) + UP * (v3.y - 0.04))
		_bars(pk, kit, "paint", hip, 0.22, 0.16, IRON_WHITE)
		# Purlins round the roof.
		for k in [3, 6]:
			var v4: Vector2 = _pav_vault(float(k) / 8.0)
			var h4: float = H - v4.x - 0.05
			pk.beam(kit, "paint", e * h4 + l * (-h4) + UP * (v4.y - 0.05), e * h4 + l * h4 + UP * (v4.y - 0.05), 0.08, 0.1, IRON_WHITE)
	# Corner columns and their finials (urns on the eaves' corners).
	for sx in [1.0, -1.0]:
		for szz in [1.0, -1.0]:
			var c := Vector3(sx * H, 0, szz * H)
			_box(pk, kit, "paint", c + Vector3(0, (PH_SILL + E) * 0.5, 0), Basis(), Vector3(0.5, E - PH_SILL, 0.5), IRON_WHITE)
			_box(pk, kit, "paint", c + Vector3(0, PH_SILL + 0.15, 0), Basis(), Vector3(0.62, 0.3, 0.62), IRON_WHITE.darkened(0.04))
			_lathe(pk, kit, "paint", c + Vector3(0, E + 0.04, 0), [Vector2(0.001, 0.0), Vector2(0.26, 0.0), Vector2(0.3, 0.12), Vector2(0.18, 0.3), Vector2(0.32, 0.6),
					Vector2(0.28, 0.85), Vector2(0.08, 0.95), Vector2(0.06, 1.2), Vector2(0.001, 1.35)], 10, IRON_WHITE)
	# The ring at the roof's top, the deck round the drum, its railing.
	var R: float = PH_RING
	var deck_y: float = PH_RING_Y + 0.15
	for f in range(4):
		var e2: Vector3 = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD][f]
		var l2: Vector3 = e2.cross(UP)
		var ext2: float = 0.2 if f % 2 == 0 else 0.0
		var dy2: float = 0.0 if f % 2 == 0 else -0.02
		pk.beam(kit, "paint", e2 * R + l2 * (-R - ext2) + UP * (PH_RING_Y - 0.08 + dy2), e2 * R + l2 * (R + ext2) + UP * (PH_RING_Y - 0.08 + dy2), 0.45, 0.38, IRON_WHITE, UP)
		# The railing round the deck.
		pk.beam(kit, "paint", e2 * (R - 0.15) + l2 * (-R) + UP * (deck_y + 0.95), e2 * (R - 0.15) + l2 * R + UP * (deck_y + 0.95), 0.05, 0.05, IRON_WHITE)
		for k in range(17):
			var u3: float = -R + 2.0 * R * float(k) / 16.0
			pk.beam(kit, "paint", e2 * (R - 0.15) + l2 * u3 + UP * deck_y, e2 * (R - 0.15) + l2 * u3 + UP * (deck_y + 0.95), 0.035, 0.035, IRON_WHITE)
	# Inside, the ring girder's underside and four columns with arched lattice girders between them.
	for sx in [1.0, -1.0]:
		for szz in [1.0, -1.0]:
			_iron_column(pk, kit, Vector3(sx * R, 0.1, szz * R), PH_RING_Y - 0.3)
	for f in range(4):
		var e3: Vector3 = [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD][f]
		var l3: Vector3 = e3.cross(UP)
		_lattice_girder(pk, kit, e3 * (R - 0.02) + l3 * (-R), e3 * (R - 0.02) + l3 * R, PH_RING_Y - 0.3, 13.8, 15.9)
	# The deck: from the ring square to the drum's circle.
	var segs := 32
	for k in range(segs):
		var a0: float = TAU * float(k) / segs
		var a1: float = TAU * float(k + 1) / segs
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var s0: Vector3 = d0 * (R / maxf(absf(d0.x), absf(d0.z)))
		var s1: Vector3 = d1 * (R / maxf(absf(d1.x), absf(d1.z)))
		var dy := UP * deck_y
		pk.quad(kit, "kslate", [d0 * PH_DRUM_R + dy, d1 * PH_DRUM_R + dy, s1 + dy, s0 + dy], UP, Color(0.42, 0.44, 0.46),
				[Vector2(d0.x, d0.z) * PH_DRUM_R * uvk, Vector2(d1.x, d1.z) * PH_DRUM_R * uvk, Vector2(s1.x, s1.z) * uvk, Vector2(s0.x, s0.z) * uvk])
		pk.quad(kit, "paint", [s0 + dy - UP * 0.04, s1 + dy - UP * 0.04, d1 * PH_DRUM_R + dy - UP * 0.04, d0 * PH_DRUM_R + dy - UP * 0.04], Vector3.DOWN, IRON_WHITE.darkened(0.15))
	# The drum: glass between pilasters, a cornice.
	var dr: float = PH_DRUM_R
	for k in range(segs):
		var a0: float = TAU * float(k) / segs
		var a1: float = TAU * float(k + 1) / segs
		var p0 := Vector3(cos(a0) * dr, 0, sin(a0) * dr)
		var p1 := Vector3(cos(a1) * dr, 0, sin(a1) * dr)
		var nm: Vector3 = (p0 + p1).normalized()
		pk.quad(kit, "gglass", [p0 + UP * deck_y, p1 + UP * deck_y, p1 + UP * PH_DRUM_TOP, p0 + UP * PH_DRUM_TOP], nm, WHITE,
				[Vector2(a0 * dr, deck_y), Vector2(a1 * dr, deck_y), Vector2(a1 * dr, PH_DRUM_TOP), Vector2(a0 * dr, PH_DRUM_TOP)])
		if k % 2 == 0:
			var pc: Vector3 = Vector3(cos(a0), 0, sin(a0)) * (dr - 0.02)
			_box(pk, kit, "paint", pc + UP * ((deck_y + PH_DRUM_TOP) * 0.5), Basis(UP, -a0), Vector3(0.14, PH_DRUM_TOP - deck_y, 0.16), IRON_WHITE)
	_lathe(pk, kit, "paint", Vector3.ZERO, [Vector2(dr - 0.12, PH_DRUM_TOP - 0.1), Vector2(dr + 0.18, PH_DRUM_TOP - 0.1), Vector2(dr + 0.28, PH_DRUM_TOP + 0.08),
			Vector2(dr + 0.1, PH_DRUM_TOP + 0.14), Vector2(dr - 0.12, PH_DRUM_TOP + 0.14)], segs, IRON_WHITE)
	_lathe(pk, kit, "paint", Vector3.ZERO, [Vector2(dr + 0.12, deck_y - 0.02), Vector2(dr + 0.12, deck_y + 0.22), Vector2(dr - 0.1, deck_y + 0.22), Vector2(dr - 0.1, deck_y - 0.02)],
			segs, IRON_WHITE)
	# The dome: glass in rings, sixteen ribs, two bands; up to the lantern.
	var lr := 1.25
	var th_max: float = acos(lr / dr)
	var nr := 9
	var prof: Array = []
	for k in range(nr + 1):
		var th: float = th_max * float(k) / nr
		prof.append(Vector2(dr * cos(th), PH_DRUM_TOP + (PH_DOME_TOP - PH_DRUM_TOP) * sin(th)))
	var vr := 0.0
	for k in range(nr):
		var q0: Vector2 = prof[k]
		var q1: Vector2 = prof[k + 1]
		var sl2: float = q0.distance_to(q1)
		for j in range(segs):
			var a0: float = TAU * float(j) / segs
			var a1: float = TAU * float(j + 1) / segs
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var dm: Vector3 = (d0 + d1).normalized()
			var nn2: Vector3 = (dm * (q1.y - q0.y) + UP * (q0.x - q1.x)).normalized()
			pk.quad(kit, "gglass", [d0 * q0.x + UP * q0.y, d1 * q0.x + UP * q0.y, d1 * q1.x + UP * q1.y, d0 * q1.x + UP * q1.y], nn2, WHITE,
					[Vector2(a0 * dr, vr), Vector2(a1 * dr, vr), Vector2(a1 * dr, vr + sl2), Vector2(a0 * dr, vr + sl2)])
		vr += sl2
	for j in range(16):
		var a: float = TAU * float(j) / 16.0
		var d := Vector3(cos(a), 0, sin(a))
		var pts2: Array = []
		for k in range(nr + 1):
			var q: Vector2 = prof[k]
			pts2.append(d * (q.x - 0.07) + UP * (q.y - 0.04))
		_bars(pk, kit, "paint", pts2, 0.16, 0.12, IRON_WHITE, Vector3(-d.z, 0, d.x))
	for k in [3, 6]:
		var q2: Vector2 = prof[k]
		_lathe(pk, kit, "paint", Vector3.ZERO, [Vector2(q2.x - 0.12, q2.y - 0.06), Vector2(q2.x + 0.03, q2.y - 0.06), Vector2(q2.x + 0.03, q2.y + 0.04),
				Vector2(q2.x - 0.12, q2.y + 0.04)], segs, IRON_WHITE)
	# The lantern: a glazed ring with posts, a cap and a gilt finial.
	var ly0: float = (prof[nr] as Vector2).y - 0.05
	var ly1: float = ly0 + 0.95
	for j in range(12):
		var a0: float = TAU * float(j) / 12.0
		var a1: float = TAU * float(j + 1) / 12.0
		var p0 := Vector3(cos(a0) * lr, 0, sin(a0) * lr)
		var p1 := Vector3(cos(a1) * lr, 0, sin(a1) * lr)
		pk.quad(kit, "gglass", [p0 + UP * ly0, p1 + UP * ly0, p1 + UP * ly1, p0 + UP * ly1], (p0 + p1).normalized(), WHITE,
				[Vector2(a0 * lr, ly0), Vector2(a1 * lr, ly0), Vector2(a1 * lr, ly1), Vector2(a0 * lr, ly1)])
		pk.beam(kit, "paint", Vector3(cos(a0), 0, sin(a0)) * (lr - 0.02) + UP * ly0, Vector3(cos(a0), 0, sin(a0)) * (lr - 0.02) + UP * ly1, 0.08, 0.08, IRON_WHITE)
	_lathe(pk, kit, "paint", Vector3.ZERO, [Vector2(lr - 0.15, ly0 - 0.08), Vector2(lr + 0.12, ly0 - 0.08), Vector2(lr + 0.12, ly0 + 0.06), Vector2(lr - 0.15, ly0 + 0.06)], 16, IRON_WHITE)
	_lathe(pk, kit, "paint", Vector3.ZERO, [Vector2(0.001, ly1 - 0.05), Vector2(lr + 0.25, ly1 - 0.05), Vector2(lr + 0.3, ly1 + 0.08), Vector2(lr * 0.8, ly1 + 0.3),
			Vector2(lr * 0.45, ly1 + 0.55), Vector2(0.15, ly1 + 0.68), Vector2(0.001, ly1 + 0.7)], 16, IRON_WHITE)
	pk.lathe(kit, "gold", UP * (ly1 + 0.66), [Vector2(0.001, 0.0), Vector2(0.09, 0.03), Vector2(0.16, 0.16), Vector2(0.09, 0.3), Vector2(0.04, 0.34),
			Vector2(0.03, 0.9), Vector2(0.001, 1.15)], 10, GILT)


## A cast-iron column standing on `base` to `top` (its capital's top): a moulded base, a slender shaft with rings, a
## flared capital with brackets.
static func _iron_column(pk: PropKit, kit: Dictionary, base: Vector3, top: float) -> void:
	var h: float = top - base.y
	_lathe(pk, kit, "paint", base, [Vector2(0.001, -0.2), Vector2(0.36, -0.2), Vector2(0.36, 0.12), Vector2(0.28, 0.2), Vector2(0.26, 0.42), Vector2(0.2, 0.5),
			Vector2(0.001, 0.5)], 12, IRON_WHITE)
	pk.tube(kit, "paint", base + UP * 0.45, base + UP * (h - 0.5), 0.17, 0.15, 12, IRON_WHITE, false)
	for y in [2.6, h * 0.55]:
		pk.tube(kit, "paint", base + UP * y, base + UP * (y + 0.12), 0.21, 0.21, 12, IRON_WHITE.darkened(0.04), true)
	_lathe(pk, kit, "paint", base + UP * (h - 0.55), [Vector2(0.001, 0.0), Vector2(0.17, 0.0), Vector2(0.2, 0.08), Vector2(0.38, 0.4), Vector2(0.42, 0.52),
			Vector2(0.001, 0.55)], 12, IRON_WHITE)


## An arched lattice girder from a to b (plan; on the columns' tops): its top chord at `top_y`, its bottom chord an arch
## from `foot_y` at the ends to `crown_y`, verticals and rings between them.
static func _lattice_girder(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, top_y: float, foot_y: float, crown_y: float) -> void:
	var a0 := Vector3(a.x, top_y, a.z)
	var b0 := Vector3(b.x, top_y, b.z)
	pk.beam(kit, "paint", a0, b0, 0.22, 0.26, IRON_WHITE, UP)
	var n := 16
	var pts: Array = []
	for k in range(n + 1):
		var t: float = float(k) / float(n)
		var y: float = foot_y + (crown_y - foot_y) * sin(t * PI)
		pts.append(a0.lerp(b0, t) + UP * (y - top_y))
	_bars(pk, kit, "paint", pts, 0.18, 0.2, IRON_WHITE, UP)
	for k in range(1, n):
		var p: Vector3 = pts[k]
		var q: Vector3 = Vector3(p.x, top_y, p.z)
		if q.y - p.y > 0.25:
			pk.beam(kit, "paint", p, q, 0.06, 0.06, IRON_WHITE)
	# Rings in the spandrels.
	var along: Vector3 = (b0 - a0).normalized()
	var across: Vector3 = along.cross(UP).normalized()
	for t in [0.12, 0.88]:
		var c: Vector3 = a0.lerp(b0, t) + UP * ((foot_y + (crown_y - foot_y) * sin(t * PI) - top_y) * 0.5)
		var r: float = minf(0.5, (top_y - (foot_y + (crown_y - foot_y) * sin(t * PI))) * 0.4)
		_bars(pk, kit, "paint", _scroll_pts(c, along, UP, r, r, 0.0, 1.0, 10), 0.05, 0.05, IRON_WHITE, across)


## A portal (in the frame where its gable is at z = PH_END and outside is +z; `t` turns it to the other end): sandstone
## bases under white iron piers with paired columns, a segmental arch over the opening, glazed spandrels with rings, the
## PALMENHAUS plate on a frieze, a cornice, a glazed pediment with a sunburst and the date, finials, wall lanterns.
static func _ph_portal(pk: PropKit, kit: Dictionary, labels: Array, t: Transform3D) -> void:
	var saved := _push(pk, t)
	var zf: float = PH_END
	var hx: float = PH_PORTAL_HALF
	var pw := 0.95
	for sx in [1.0, -1.0]:
		var x0: float = sx * hx
		var x1: float = sx * (hx + pw)
		var xc: float = sx * (hx + pw * 0.5)
		_mblock(pk, kit, "ashlar", Vector3(x0, -1.5, zf - 0.15), Vector3(x1, 1.45, zf + 0.92), SAND)
		_mblock(pk, kit, "ashlar", Vector3(sx * (hx - 0.05), 1.45, zf - 0.2), Vector3(sx * (hx + pw + 0.06), 1.6, zf + 0.98), SAND_LIGHT, true, true)
		_box(pk, kit, "paint", Vector3(xc, 6.8, zf + 0.25), Basis(), Vector3(pw - 0.12, 10.4, 0.7), IRON_WHITE.darkened(0.03))
		for cx in [hx + 0.25, hx + 0.7]:
			var cb := Vector3(sx * cx, 1.6, zf + 0.75)
			_lathe(pk, kit, "paint", cb, [Vector2(0.001, -0.02), Vector2(0.22, -0.02), Vector2(0.22, 0.1), Vector2(0.17, 0.18), Vector2(0.001, 0.18)], 12, IRON_WHITE)
			pk.tube(kit, "paint", cb + UP * 0.15, cb + UP * 7.25, 0.15, 0.13, 12, IRON_WHITE, false)
			pk.tube(kit, "paint", cb + UP * 3.4, cb + UP * 3.52, 0.18, 0.18, 12, IRON_WHITE.darkened(0.05), true)
			_lathe(pk, kit, "paint", cb + UP * 7.2, [Vector2(0.001, 0.0), Vector2(0.14, 0.0), Vector2(0.17, 0.1), Vector2(0.26, 0.32), Vector2(0.29, 0.42),
					Vector2(0.001, 0.42)], 12, IRON_WHITE)
		# Above the capitals a pilaster up to the cornice, panelled.
		_box(pk, kit, "paint", Vector3(xc, 10.55, zf + 0.72), Basis(), Vector3(pw - 0.05, 2.4, 0.3), IRON_WHITE)
		_box(pk, kit, "paint", Vector3(xc, 10.55, zf + 0.9), Basis(), Vector3(pw - 0.35, 1.8, 0.06), IRON_WHITE.darkened(0.08))
		# A wall lantern on a scrolled bracket.
		var bp := Vector3(xc, 5.3, zf + 0.6)
		pk.beam(kit, "steel", bp, bp + Vector3(0, 0, 0.75), 0.06, 0.06, IRON_DARK, UP)
		_bars(pk, kit, "steel", _scroll_pts(bp + Vector3(0, -0.25, 0.25), Vector3(0, 0, 1), UP, 0.05, 0.22, PI, 0.75, 8), 0.04, 0.04, IRON_DARK, Vector3.RIGHT)
		_lantern(pk, kit, bp + Vector3(0, 0.02, 0.72), 0.85)
		# Finials on the piers' tops (over the cornice).
		_lathe(pk, kit, "paint", Vector3(xc, 12.2, zf + 0.4), [Vector2(0.001, 0.0), Vector2(0.32, 0.0), Vector2(0.32, 0.12), Vector2(0.18, 0.2), Vector2(0.3, 0.5),
				Vector2(0.25, 0.75), Vector2(0.1, 0.82), Vector2(0.001, 0.82)], 12, IRON_WHITE)
		pk.lathe(kit, "gold", Vector3(xc, 13.0, zf + 0.4), [Vector2(0.001, 0.0), Vector2(0.1, 0.05), Vector2(0.12, 0.14), Vector2(0.05, 0.24), Vector2(0.02, 0.6),
				Vector2(0.001, 0.62)], 8, GILT)
	# The arch over the opening.
	var rise: float = PH_PORTAL_CROWN - PH_PORTAL_SPRING
	var rr: float = (hx * hx + rise * rise) / (2.0 * rise)
	var cy: float = PH_PORTAL_SPRING + rise - rr
	var intr: PackedVector2Array = KT._arch(0.0, PH_PORTAL_SPRING, hx, "seg", 16, rise)
	var extr := PackedVector2Array()
	for p in intr:
		var d: Vector2 = (p - Vector2(0, cy)).normalized()
		extr.append(Vector2(0, cy) + d * (rr + 0.34))
	var z0: float = zf + 0.28
	var z1: float = zf + 0.78
	for i in range(intr.size() - 1):
		var a: Vector2 = intr[i]
		var b: Vector2 = intr[i + 1]
		var c: Vector2 = extr[i + 1]
		var d2: Vector2 = extr[i]
		for zz in [z0, z1]:
			var nz := Vector3(0, 0, 1 if zz > z0 else -1)
			pk.quad(kit, "paint", [Vector3(a.x, a.y, zz), Vector3(b.x, b.y, zz), Vector3(c.x, c.y, zz), Vector3(d2.x, d2.y, zz)], nz, IRON_WHITE)
		var ni: Vector2 = (Vector2(0, cy) - (a + b) * 0.5).normalized()
		pk.quad(kit, "paint", [Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1)], Vector3(ni.x, ni.y, 0), IRON_WHITE.darkened(0.08))
		pk.quad(kit, "paint", [Vector3(d2.x, d2.y, z0), Vector3(c.x, c.y, z0), Vector3(c.x, c.y, z1), Vector3(d2.x, d2.y, z1)], Vector3(-ni.x, -ni.y, 0), IRON_WHITE)
	# A moulding along the arch's face and a gilt keystone.
	var mold: Array = []
	for p in intr:
		var d3: Vector2 = (p - Vector2(0, cy)).normalized()
		var q: Vector2 = Vector2(0, cy) + d3 * (rr + 0.1)
		mold.append(Vector3(q.x, q.y, z1 + 0.03))
	_bars(pk, kit, "paint", mold, 0.06, 0.07, IRON_WHITE.darkened(0.06))
	_box(pk, kit, "gold", Vector3(0, PH_PORTAL_CROWN + 0.2, z1 + 0.05), Basis(), Vector3(0.42, 0.5, 0.1), GILT)
	# Glazed spandrels with rings, up to the frieze.
	var sp := PackedVector2Array()
	sp.append(Vector2(-hx - 0.02, 10.78))
	sp.append(Vector2(-hx - 0.02, (extr[0] as Vector2).y))
	for p in extr:
		sp.append(p)
	sp.append(Vector2(hx + 0.02, (extr[extr.size() - 1] as Vector2).y))
	sp.append(Vector2(hx + 0.02, 10.78))
	_glass_poly(pk, kit, sp, zf + 0.53, Vector3(0, 0, 1))
	for sx in [1.0, -1.0]:
		_bars(pk, kit, "paint", _scroll_pts(Vector3(sx * 5.25, 10.35, zf + 0.53), Vector3.RIGHT, UP, 0.28, 0.28, 0.0, 1.0, 12), 0.05, 0.05, IRON_WHITE, Vector3(0, 0, 1))
		_bars(pk, kit, "paint", _scroll_pts(Vector3(sx * 5.25, 10.35, zf + 0.53), Vector3.RIGHT, UP, 0.12, 0.12, 0.0, 1.0, 8), 0.04, 0.04, IRON_WHITE, Vector3(0, 0, 1))
		_bars(pk, kit, "paint", _scroll_pts(Vector3(sx * 3.55, 10.56, zf + 0.53), Vector3.RIGHT, UP, 0.17, 0.17, 0.0, 1.0, 10), 0.04, 0.04, IRON_WHITE, Vector3(0, 0, 1))
	# The frieze, the plate and its gilt frame, the name.
	_box(pk, kit, "paint", Vector3(0, 11.27, zf + 0.5), Basis(), Vector3(2.0 * hx + 0.3, 1.0, 0.44), IRON_WHITE)
	_box(pk, kit, "enamel", Vector3(0, 11.25, zf + 0.76), Basis(), Vector3(11.0, 0.86, 0.08), ENAMEL_GREEN)
	for yy in [10.84, 11.66]:
		pk.beam(kit, "gold", Vector3(-5.5, yy, zf + 0.82), Vector3(5.5, yy, zf + 0.82), 0.05, 0.04, GILT, UP)
	for xx in [-5.5, 5.5]:
		pk.beam(kit, "gold", Vector3(xx, 10.81, zf + 0.82), Vector3(xx, 11.69, zf + 0.82), 0.05, 0.04, GILT, Vector3.RIGHT)
	_lbl(labels, "PALMENHAUS", Vector3(0, 11.25, zf + 0.86), Vector3(0, 0, 1), 0.46, GILT, 10.2)
	# The cornice over the frieze and the piers.
	_box(pk, kit, "paint", Vector3(0, 11.92, zf + 0.4), Basis(), Vector3(2.0 * (hx + pw) + 0.1, 0.34, 1.1), IRON_WHITE.darkened(0.03))
	_box(pk, kit, "paint", Vector3(0, 12.14, zf + 0.42), Basis(), Vector3(2.0 * (hx + pw) + 0.45, 0.13, 1.32), IRON_WHITE)
	# The pediment: a segmental frame, glass with a sunburst, a gilt half sun and the date.
	var p_half: float = hx + 0.45
	var p_rise := 1.3
	var py := 12.2
	var parc: PackedVector2Array = KT._arch(0.0, py, p_half, "seg", 16, p_rise)
	var prr: float = (p_half * p_half + p_rise * p_rise) / (2.0 * p_rise)
	var pcy: float = py + p_rise - prr
	var pz0: float = zf + 0.22
	var pz1: float = zf + 0.62
	for i in range(parc.size() - 1):
		var a2: Vector2 = parc[i]
		var b2: Vector2 = parc[i + 1]
		var da: Vector2 = (a2 - Vector2(0, pcy)).normalized()
		var db: Vector2 = (b2 - Vector2(0, pcy)).normalized()
		var a3: Vector2 = Vector2(0, pcy) + da * (prr + 0.26)
		var b3: Vector2 = Vector2(0, pcy) + db * (prr + 0.26)
		for zz in [pz0, pz1]:
			pk.quad(kit, "paint", [Vector3(a2.x, a2.y, zz), Vector3(b2.x, b2.y, zz), Vector3(b3.x, b3.y, zz), Vector3(a3.x, a3.y, zz)], Vector3(0, 0, 1 if zz > pz0 else -1), IRON_WHITE)
		var nb2: Vector3 = Vector3(((da + db) * 0.5).x, ((da + db) * 0.5).y, 0).normalized()
		pk.quad(kit, "paint", [Vector3(a3.x, a3.y, pz0), Vector3(b3.x, b3.y, pz0), Vector3(b3.x, b3.y, pz1), Vector3(a3.x, a3.y, pz1)], nb2, IRON_WHITE)
		pk.quad(kit, "paint", [Vector3(a2.x, a2.y, pz0), Vector3(b2.x, b2.y, pz0), Vector3(b2.x, b2.y, pz1), Vector3(a2.x, a2.y, pz1)], -nb2, IRON_WHITE.darkened(0.1))
	var tym := PackedVector2Array()
	for p in parc:
		tym.append(p)
	_glass_poly(pk, kit, tym, zf + 0.42, Vector3(0, 0, 1))
	for k in range(1, 12):
		var ang: float = PI * float(k) / 12.0
		var dr := Vector2(cos(ang), sin(ang))
		var far_pt: Vector2 = Vector2(0, py)
		for j in range(60):
			var tp: Vector2 = Vector2(0, py) + dr * (0.05 * float(j))
			if tp.y > KT._arch_height(parc, tp.x) - 0.02 or absf(tp.x) > p_half:
				break
			far_pt = tp
		pk.beam(kit, "paint", Vector3(dr.x * 0.6, py + dr.y * 0.6, zf + 0.42), Vector3(far_pt.x, far_pt.y, zf + 0.42), 0.035, 0.035, IRON_WHITE)
	var sun_c := Vector3(0, py, zf + 0.5)
	for k in range(10):
		var a0: float = PI * float(k) / 10.0
		var a1: float = PI * float(k + 1) / 10.0
		pk.tri(kit, "gold", sun_c, sun_c + Vector3(cos(a0), sin(a0), 0) * 0.55, sun_c + Vector3(cos(a1), sin(a1), 0) * 0.55, Vector3.BACK, Vector3.BACK, Vector3.BACK, GILT, Vector3.BACK)
	_box(pk, kit, "enamel", Vector3(0, 12.96, zf + 0.62), Basis(), Vector3(1.7, 0.3, 0.05), ENAMEL_GREEN)
	_lbl(labels, "ANNO 1889", Vector3(0, 12.96, zf + 0.655), Vector3(0, 0, 1), 0.15, GILT, 1.55)
	pk.lathe(kit, "gold", Vector3(0, py + p_rise + 0.2, zf + 0.42), [Vector2(0.001, 0.0), Vector2(0.14, 0.05), Vector2(0.16, 0.18), Vector2(0.06, 0.3), Vector2(0.03, 0.85),
			Vector2(0.001, 0.9)], 8, GILT)
	_pop(pk, saved)


## The planting: the pavilion's tall palms leaning in toward the light under the dome, fan palms, bananas, tree ferns,
## aroids, birds of paradise, the lily pool, the columns' climbers; the wings' bananas, tree ferns, small fan palms and
## aroids; ground cover between them; baskets over the road. Every plant goes through the corridor clamp (`_lt`).
static func _ph_planting(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var taken: Array = []
	var g := 0.1
	# The pavilion.
	feather_palm(pk, kit, Vector3(9.5, g, -2.6), 15.5, Vector3(-6.0, 0, 0.6), 16, 4.2, rng)
	taken.append([Vector2(9.5, -2.6), 0.9])
	feather_palm(pk, kit, Vector3(-9.6, g, 3.4), 16.4, Vector3(6.3, 0, -1.0), 16, 4.4, rng, KENTIA_GREEN)
	taken.append([Vector2(-9.6, 3.4), 0.9])
	feather_palm(pk, kit, Vector3(10.6, g, 9.8), 12.0, Vector3(-1.2, 0, -1.0), 14, 3.5, rng)
	taken.append([Vector2(10.6, 9.8), 0.8])
	feather_palm(pk, kit, Vector3(-10.8, g, -9.6), 11.4, Vector3(1.2, 0, 1.0), 14, 3.4, rng, KENTIA_GREEN)
	taken.append([Vector2(-10.8, -9.6), 0.8])
	feather_palm(pk, kit, Vector3(-12.4, g, 9.2), 8.5, Vector3(0.6, 0, -0.4), 12, 3.0, rng)
	taken.append([Vector2(-12.4, 9.2), 0.7])
	fan_palm(pk, kit, Vector3(11.6, g, 3.4), 7.4, Vector3(-0.4, 0, 0.2), 14, 1.25, rng)
	taken.append([Vector2(11.6, 3.4), 1.0])
	fan_palm(pk, kit, Vector3(-11.6, g, -3.0), 8.2, Vector3(0.4, 0, 0.0), 14, 1.3, rng)
	taken.append([Vector2(-11.6, -3.0), 1.0])
	for k in range(3):
		var bp := Vector3(12.6 + 0.5 * cos(float(k) * 2.1), g, -11.8 + 0.5 * sin(float(k) * 2.1))
		fan_palm(pk, kit, bp, 2.4 + 0.7 * float(k), Vector3(0.2 * cos(float(k) * 2.1), 0, 0.2 * sin(float(k) * 2.1)), 9, 0.85, rng, false)
	taken.append([Vector2(12.6, -11.8), 1.4])
	banana(pk, kit, Vector3(12.2, g, 12.0), 5.2, rng, 3, Vector3(1, 0, 0))
	taken.append([Vector2(12.2, 12.0), 1.5])
	banana(pk, kit, Vector3(-8.0, g, -12.2), 4.8, rng, 3, Vector3(-1, 0, 0))
	taken.append([Vector2(-8.0, -12.2), 1.5])
	banana(pk, kit, Vector3(-12.8, g, 1.6), 4.6, rng, 2, Vector3(-1, 0, 0))
	taken.append([Vector2(-12.8, 1.6), 1.2])
	tree_fern(pk, kit, Vector3(7.6, g, -11.6), 3.4, rng)
	taken.append([Vector2(7.6, -11.6), 0.8])
	tree_fern(pk, kit, Vector3(-7.8, g, 10.6), 3.8, rng)
	taken.append([Vector2(-7.8, 10.6), 0.8])
	tree_fern(pk, kit, Vector3(13.0, g, 7.0), 2.8, rng)
	taken.append([Vector2(13.0, 7.0), 0.8])
	aroid(pk, kit, Vector3(7.7, g, 4.2), 0.9, 0, rng, Vector3(1, 0, 0))
	aroid(pk, kit, Vector3(8.0, g, 11.4), 1.0, 1, rng, Vector3(1, 0, 0))
	aroid(pk, kit, Vector3(-7.7, g, -4.4), 0.95, 0, rng, Vector3(-1, 0, 0))
	aroid(pk, kit, Vector3(-8.2, g, -0.6), 1.0, 1, rng, Vector3(-1, 0, 0))
	aroid(pk, kit, Vector3(9.4, g, -10.4), 0.9, 0, rng, Vector3(0, 0, -1))
	aroid(pk, kit, Vector3(-10.8, g, 7.4), 0.9, 0, rng)
	for a in [[7.7, 4.2], [8.0, 11.4], [-7.7, -4.4], [-8.2, -0.6], [9.4, -10.4], [-10.8, 7.4]]:
		taken.append([Vector2(a[0], a[1]), 1.0])
	strap_clump(pk, kit, Vector3(10.2, g, 0.8), 1.4, rng, STRAP_GREEN, true, 11)
	strap_clump(pk, kit, Vector3(-10.6, g, 0.6), 1.3, rng, STRAP_GREEN, true, 10)
	taken.append([Vector2(10.2, 0.8), 0.9])
	taken.append([Vector2(-10.6, 0.6), 0.9])
	# The lily pool.
	var pc := Vector3(11.0, 0.0, -7.4)
	_lathe(pk, kit, "ashlar", pc, [Vector2(2.3, -0.2), Vector2(2.3, 0.42), Vector2(1.9, 0.42), Vector2(1.9, 0.05)], 24, SAND_LIGHT)
	pk.lathe(kit, "kwater", pc, [Vector2(1.92, 0.3), Vector2(0.001, 0.3)], 24, WHITE)
	for k in range(9):
		var a3: float = rng.randf() * TAU
		var r3: float = rng.randf_range(0.3, 1.5)
		var pp: Vector3 = pc + Vector3(cos(a3) * r3, 0.315, sin(a3) * r3)
		var pr: float = rng.randf_range(0.18, 0.32)
		var rot: float = rng.randf() * TAU
		var ax := Vector3(cos(rot), 0, sin(rot)) * pr
		var az := Vector3(-sin(rot), 0, cos(rot)) * pr
		var idf := float(rng.randi_range(0, 900))
		pk.quad(kit, "gleaf", [pp - ax - az, pp + ax - az, pp + ax + az, pp - ax + az], UP, _gm(Color(0.20, 0.38, 0.12), 0.1),
				[Vector2(idf, 0), Vector2(idf + 0.999, 0), Vector2(idf + 0.999, 0.999), Vector2(idf, 0.999)])
		if k % 3 == 0:
			_lump(pk, kit, "gflower", pp + Vector3(0.05, 0.0, 0.05), Vector3(0.1, 0.07, 0.1), _fk(Color(0.98, 0.62, 0.78), 11), rng, 6, 2, 0.1)
	taken.append([Vector2(11.0, -7.4), 2.5])
	# Climbers up the pavilion's columns.
	for sx in [1.0, -1.0]:
		for szz in [1.0, -1.0]:
			column_climber(pk, kit, Vector3(sx * PH_RING, 0.1, szz * PH_RING), 0.17, 0.5, 9.5, rng)
			taken.append([Vector2(sx * PH_RING, szz * PH_RING), 0.7])
	# The wings.
	for sx in [1.0, -1.0]:
		for sz in [1.0, -1.0]:
			var away := Vector3(sx, 0, 0)
			var zs: Array = [16.2, 19.0, 21.8, 24.6, 27.4, 30.2]
			for i in range(zs.size()):
				var z: float = sz * (zs[i] as float + rng.randf_range(-0.4, 0.4))
				var kind: int = (i + (1 if sx > 0.0 else 0) + (2 if sz > 0.0 else 0)) % 4
				match kind:
					0:
						banana(pk, kit, Vector3(sx * 9.2, g, z), 4.6, rng, 3, away)
						taken.append([Vector2(sx * 9.2, z), 1.3])
					1:
						tree_fern(pk, kit, Vector3(sx * 9.3, g, z), 3.0 + rng.randf() * 0.6, rng, 10)
						taken.append([Vector2(sx * 9.3, z), 0.8])
					2:
						fan_palm(pk, kit, Vector3(sx * 9.6, g, z), 3.0 + rng.randf() * 0.6, Vector3(-sx * 0.2, 0, 0), 11, 0.9, rng, false)
						taken.append([Vector2(sx * 9.6, z), 0.9])
					3:
						feather_palm(pk, kit, Vector3(sx * 9.4, g, z), 5.0 + rng.randf() * 0.6, Vector3(0, 0, 0), 11, 2.2, rng)
						taken.append([Vector2(sx * 9.4, z), 0.8])
				# In front of each, toward the road, something lower.
				var zf2: float = z + sz * 1.4
				if absf(zf2) < PH_END - 0.8:
					match (i + int(sx > 0.0)) % 3:
						0:
							aroid(pk, kit, Vector3(sx * 7.6, g, zf2), 0.8, i % 2, rng, away, 6)
						1:
							strap_clump(pk, kit, Vector3(sx * 7.3, g, zf2), 1.1, rng, STRAP_GREEN, i % 2 == 0, 9, away)
						2:
							strap_clump(pk, kit, Vector3(sx * 7.2, g, zf2), 0.55, rng, Color(0.62, 0.12, 0.14), false, 12, away)
					taken.append([Vector2(sx * 7.5, zf2), 0.7])
	# Baskets hanging over the road from the wings' ribs.
	for sz in [1.0, -1.0]:
		for k in [2, 5]:
			for sx in [1.0, -1.0]:
				var hz: float = sz * (PH_PAV_HALF + 2.5 * float(k))
				var hy: float = wing_roof_y(3.2) - 0.32
				hanging_basket(pk, kit, Vector3(sx * 3.2, hy, hz), hy - 10.05, rng)
	# The layer under them: ferns, leafy shrubs and crotons, cordylines, small aroids, begonias in flower.
	var regions: Array = [[6.6, 14.0, -14.0, 14.0, 46], [6.6, 10.5, 14.7, 31.6, 24], [6.6, 10.5, -31.6, -14.7, 24]]
	var tints: Array = [Color(0.55, 0.06, 0.14), Color(0.42, 0.10, 0.30), Color(0.62, 0.20, 0.10), Color(0.30, 0.12, 0.10)]
	for sx in [1.0, -1.0]:
		for reg in regions:
			var placed := 0
			var tries := 0
			while placed < int(reg[4]) and tries < int(reg[4]) * 8:
				tries += 1
				var x: float = sx * rng.randf_range(reg[0], reg[1])
				var z2: float = rng.randf_range(reg[2], reg[3])
				var r: float = rng.randf_range(0.45, 0.8)
				var ok := true
				for tk in taken:
					if Vector2(x, z2).distance_to(tk[0]) < r + float(tk[1]) * 0.8:
						ok = false
						break
				if not ok:
					continue
				taken.append([Vector2(x, z2), r * 0.8])
				placed += 1
				var roll: float = rng.randf()
				var p := Vector3(x, g, z2)
				if roll < 0.36:
					fern_clump(pk, kit, p, r * 1.7, rng, 10)
				elif roll < 0.62:
					leafy_shrub(pk, kit, p, r * 2.0, rng, Color(0.10, 0.28, 0.08) if rng.randf() < 0.5 else Color(0.14, 0.34, 0.10), rng.randf() < 0.45, 3)
				elif roll < 0.74:
					cordyline(pk, kit, p, r * 2.4, tints[rng.randi_range(0, tints.size() - 1)], rng)
				elif roll < 0.86:
					leaf_mound(pk, kit, p, r * 0.7, Color(0.92, 0.25, 0.30), 1, rng)
				else:
					aroid(pk, kit, p, r * 0.9, 0, rng, Vector3(sx, 0, 0), 4)


## Boxes for the Palmenhaus's colliders (life size, its frame): the plinths, the kerbs, the portals' piers, the walls'
## glass up to the eaves, the pavilion's columns and the big palms' trunks near their feet.
static func palm_house_solids() -> Array:
	var out: Array = []
	for sx in [1.0, -1.0]:
		for sz in [1.0, -1.0]:
			var zm: float = sz * (PH_PAV_HALF + PH_END) * 0.5
			var zl: float = PH_END - PH_PAV_HALF + 0.5
			out.append([Transform3D(Basis(), Vector3(sx * PH_WING_HALF, (PH_WING_EAVE - 1.5) * 0.5, zm)), Vector3(0.6, PH_WING_EAVE + 1.5, zl)])
			out.append([Transform3D(Basis(), Vector3(sx * (PH_PORTAL_HALF + PH_WING_HALF + 0.25) * 0.5, 0.0, sz * PH_END)),
					Vector3(PH_WING_HALF + 0.25 - PH_PORTAL_HALF, 3.0, 0.6)])
			out.append([Transform3D(Basis(), Vector3(sx * (PH_PORTAL_HALF + 0.475), 5.5, sz * (PH_END + 0.4))), Vector3(0.95, 14.0, 1.1)])
			out.append([Transform3D(Basis(), Vector3(sx * (PH_WING_HALF + PH_PAV_HALF) * 0.5, PH_PAV_EAVE * 0.5 - 0.75, sz * PH_PAV_HALF)),
					Vector3(PH_PAV_HALF - PH_WING_HALF + 0.5, PH_PAV_EAVE + 1.5, 0.6)])
			out.append([Transform3D(Basis(), Vector3(sx * PH_RING, 8.0, sz * PH_RING)), Vector3(0.5, 16.5, 0.5)])
		out.append([Transform3D(Basis(), Vector3(sx * PH_PAV_HALF, PH_PAV_EAVE * 0.5 - 0.75, 0)), Vector3(0.6, PH_PAV_EAVE + 1.5, 2.0 * PH_PAV_HALF + 0.5)])
		out.append([Transform3D(Basis(), Vector3(sx * (PH_CLEAR_X + 0.21), -0.11, 0)), Vector3(0.42, 0.58, 2.0 * PH_END + 0.5)])
	for p in [Vector3(9.5, 0, -2.6), Vector3(-9.6, 0, 3.4), Vector3(10.6, 0, 9.8), Vector3(-10.8, 0, -9.6), Vector3(11.6, 0, 3.4), Vector3(-11.6, 0, -3.0)]:
		out.append([Transform3D(Basis(), p + Vector3(0, 1.5, 0)), Vector3(0.6, 3.0, 0.6)])
	return out


# ======================================================================================
#  The main gate and the railings
# ======================================================================================

## The garden's main gate: the road runs along z through x = 0, the street on +z, the garden on -z. Two tall sandstone
## pillars (|x| GATE_PIER_IN..GATE_PIER_OUT, z +-0.6, to GATE_PIER_H) with urns, wrought-iron double gates standing open
## (each swung into the garden flat along x = +-6.5, z -0.62..-7.1, |x| >= 6.44), an iron overthrow on the pillars (its
## underside GATE_ARCH_Y, the crown on its crest at 12.4) carrying `text` on a plate (read from both sides), fence stubs
## out to |x| = 10 with end piers and lanterns.
static func garden_gate(pk: PropKit, kit: Dictionary, labels: Array, text := "BOTANISCHER GARTEN KRONBURG") -> void:
	for sx in [1.0, -1.0]:
		var xi: float = sx * GATE_PIER_IN
		var xo: float = sx * GATE_PIER_OUT
		var xc: float = (xi + xo) * 0.5
		# The pillar: a base, a shaft with bands, a cornice and a cap.
		_mblock(pk, kit, "ashlar", Vector3(xi, -1.5, -0.68), Vector3(xo + sx * 0.08, 0.6, 0.68), SAND_DARK)
		_mblock(pk, kit, "ashlar", Vector3(xi, 0.6, -0.6), Vector3(xo, 8.4, 0.6), SAND)
		for by in [0.6, 3.2, 6.0]:
			_mblock(pk, kit, "ashlar", Vector3(xi, by, -0.66), Vector3(xo + sx * 0.06, by + 0.22, 0.66), SAND_LIGHT)
		# A sunk panel on the street face with the arms in gold.
		_mblock(pk, kit, "ashlar", Vector3(xi + sx * 0.25, 4.0, 0.6), Vector3(xo - sx * 0.25, 5.6, 0.63), SAND_LIGHT)
		KT._arms(pk, kit, Transform3D(Basis(), Vector3(0, 0, 0.635)), xc, 4.8, 0.7, 0.0)
		_mblock(pk, kit, "ashlar", Vector3(xi, 8.4, -0.72), Vector3(xo + sx * 0.12, 8.75, 0.72), SAND_LIGHT)
		_mblock(pk, kit, "ashlar", Vector3(xi, 8.75, -0.62), Vector3(xo + sx * 0.02, GATE_ARCH_Y, 0.62), SAND)
		urn(pk, kit, Vector3(sx * 7.32, GATE_ARCH_Y - 0.01, 0.0), 0.75, true)
		# The gate leaf, swung open into the garden along the road's edge.
		_gate_leaf(pk, kit, Vector3(sx * 6.5, 0.0, -0.62), Vector3(0, 0, -1), GATE_LEAF_W)
		# The fence stub out to |x| 10, its end pier and a lantern on it.
		var saved := _push(pk, Transform3D(Basis(), Vector3(xo if sx > 0.0 else -10.0, 0, 0)))
		_fence_run(pk, kit, 0.0, 10.0 - GATE_PIER_OUT, false)
		_pop(pk, saved)
		_fence_pier(pk, kit, Vector3(sx * 9.7, 0, 0), 2.6)
		_lantern(pk, kit, Vector3(sx * 9.7, 2.93, 0), 0.9)
	_overthrow(pk, kit, labels, text)


## One gate leaf from its hinge at `h` (on the ground) along `along` (horizontal unit), `w` long: a frame, its top rail
## rising to the meeting stile, bars with spear tips, dog bars, a band of C-scrolls under the top rail.
static func _gate_leaf(pk: PropKit, kit: Dictionary, h: Vector3, along: Vector3, w: float) -> void:
	var c := IRON_DARK
	var side: Vector3 = along.cross(UP).normalized()
	var top := func(t: float) -> float: return 2.85 + 0.55 * t * t
	pk.beam(kit, "steel", h + UP * 0.05, h + UP * (top.call(0.0) + 0.25), 0.1, 0.1, c, side)
	pk.beam(kit, "steel", h + along * w + UP * 0.05, h + along * w + UP * (top.call(1.0) + 0.25), 0.1, 0.1, c, side)
	pk.beam(kit, "steel", h + UP * 0.15, h + along * w + UP * 0.15, 0.08, 0.06, c, side)
	pk.beam(kit, "steel", h + UP * 0.95, h + along * w + UP * 0.95, 0.06, 0.05, c, side)
	var n := 12
	var prev: Vector3 = h + UP * float(top.call(0.0))
	for k in range(1, n + 1):
		var t: float = float(k) / n
		var p: Vector3 = h + along * (w * t) + UP * top.call(t)
		pk.beam(kit, "steel", prev, p, 0.07, 0.05, c, side)
		pk.beam(kit, "steel", prev - UP * 0.5, p - UP * 0.5, 0.05, 0.04, c, side)
		prev = p
	var nb: int = int(w / 0.14)
	for k in range(1, nb):
		var t2: float = float(k) / nb
		var b: Vector3 = h + along * (w * t2)
		var ty: float = top.call(t2)
		pk.beam(kit, "steel", b + UP * 0.12, b + UP * (ty + 0.08), 0.028, 0.028, c, side)
		pk.lathe(kit, "steel", b + UP * (ty + 0.06), [Vector2(0.001, 0.0), Vector2(0.045, 0.03), Vector2(0.001, 0.2)], 4, c, true)
		if k % 2 == 1:
			pk.beam(kit, "steel", b + UP * 0.16, b + UP * 0.92, 0.022, 0.022, c, side)
	# C-scrolls in the band under the top rail.
	var ns: int = int(w / 0.55)
	for k in range(ns):
		var t3: float = (float(k) + 0.5) / ns
		var cp: Vector3 = h + along * (w * t3) + UP * (top.call(t3) - 0.26)
		_bars(pk, kit, "steel", _scroll_pts(cp, along, UP, 0.03, 0.17, PI * 0.5, 0.85, 8), 0.022, 0.03, c, side)
		_bars(pk, kit, "steel", _scroll_pts(cp + along * 0.1, -along, -UP, 0.03, 0.12, PI * 0.5, 0.8, 6), 0.022, 0.03, c, side)
	# A gilt lock box at the meeting stile.
	_box(pk, kit, "gold", h + along * (w - 0.12) + UP * 1.25, Basis(side, UP, side.cross(UP).normalized()), Vector3(0.05, 0.3, 0.16), GILT)


## The overthrow on the pillars' caps: bars across at GATE_ARCH_Y, uprights over the pillars, an arched crest, the plate
## with `text` on both faces, scrolls round it and Kronburg's crown on top.
static func _overthrow(pk: PropKit, kit: Dictionary, labels: Array, text: String) -> void:
	var c := IRON_DARK
	var x0 := 6.86
	var y0: float = GATE_ARCH_Y + 0.02
	for y in [y0 + 0.04, y0 + 0.36]:
		pk.beam(kit, "steel", Vector3(-x0 - 0.1, y, 0), Vector3(x0 + 0.1, y, 0), 0.08, 0.07, c, UP)
	var top_y := 10.75
	var crown_y := 12.0
	for sx in [1.0, -1.0]:
		for dx in [0.0, 0.16]:
			pk.beam(kit, "steel", Vector3(sx * (x0 - dx), y0, 0), Vector3(sx * (x0 - dx), top_y, 0), 0.07, 0.07, c)
		pk.lathe(kit, "gold", Vector3(sx * (x0 - 0.08), top_y - 0.02, 0), [Vector2(0.001, 0.0), Vector2(0.09, 0.05), Vector2(0.11, 0.16), Vector2(0.04, 0.26),
				Vector2(0.02, 0.6), Vector2(0.001, 0.62)], 8, GILT)
		# Scrolls between the plate and the uprights.
		_bars(pk, kit, "steel", _scroll_pts(Vector3(sx * 6.2, y0 + 0.75, 0), Vector3(sx, 0, 0), UP, 0.04, 0.32, -PI * 0.5, 1.1, 12), 0.03, 0.04, c, Vector3(0, 0, 1))
		_bars(pk, kit, "steel", _scroll_pts(Vector3(sx * 6.2, y0 + 1.25, 0), Vector3(sx, 0, 0), -UP, 0.04, 0.2, -PI * 0.5, 0.9, 10), 0.03, 0.04, c, Vector3(0, 0, 1))
	# The crest: two concentric arcs over the plate, rings and lilies between them.
	for off in [0.0, 0.3]:
		var pts: Array = []
		for k in range(21):
			var t: float = float(k) / 20.0
			var x: float = lerpf(-x0, x0, t)
			var y: float = top_y + (crown_y - top_y) * sin(t * PI) - off
			pts.append(Vector3(x, y, 0))
		_bars(pk, kit, "steel", pts, 0.07, 0.06, c, Vector3(0, 0, 1))
	for k in range(1, 8):
		var t2: float = float(k) / 8.0
		var x2: float = lerpf(-x0, x0, t2)
		var yc: float = top_y + (crown_y - top_y) * sin(t2 * PI) - 0.15
		_bars(pk, kit, "steel", _scroll_pts(Vector3(x2, yc, 0), Vector3.RIGHT, UP, 0.11, 0.11, 0.0, 1.0, 8), 0.025, 0.03, c, Vector3(0, 0, 1))
		KT._blob(pk, kit, "gold", Vector3(x2, yc, 0), Vector3(0.05, 0.05, 0.05), GILT)
	# Scrolls rising under the crest from the plate's top.
	for sx in [1.0, -1.0]:
		for k in range(3):
			var cx: float = sx * (1.4 + 1.6 * float(k))
			_bars(pk, kit, "steel", _scroll_pts(Vector3(cx, 10.85 + 0.12 * float(2 - k), 0), Vector3(sx, 0, 0), UP, 0.04, 0.26, PI, 1.0, 10), 0.025, 0.035, c, Vector3(0, 0, 1))
	# The plate, its gilt frame, the name both ways.
	_box(pk, kit, "enamel", Vector3(0, 10.12, 0), Basis(), Vector3(10.6, 0.78, 0.06), ENAMEL_GREEN)
	for zs in [1.0, -1.0]:
		for yy in [9.75, 10.49]:
			pk.beam(kit, "gold", Vector3(-5.3, yy, zs * 0.035), Vector3(5.3, yy, zs * 0.035), 0.04, 0.02, GILT, UP)
		for xx in [-5.3, 5.3]:
			pk.beam(kit, "gold", Vector3(xx, 9.73, zs * 0.035), Vector3(xx, 10.51, zs * 0.035), 0.04, 0.02, GILT, Vector3.RIGHT)
		_lbl(labels, text, Vector3(0, 10.12, zs * 0.05), Vector3(0, 0, zs), 0.38, GILT, 10.0)
	KT._crown(pk, kit, Vector3(0, crown_y + 0.03, 0), 0.4)


## The gate's colliders: the pillars, the open leaves along the road's edges, the stubs and their piers, the overthrow.
static func garden_gate_solids() -> Array:
	var out: Array = []
	for sx in [1.0, -1.0]:
		out.append([Transform3D(Basis(), Vector3(sx * (GATE_PIER_IN + GATE_PIER_OUT) * 0.5, 3.8, 0)), Vector3(GATE_PIER_OUT - GATE_PIER_IN, 10.6, 1.36)])
		out.append([Transform3D(Basis(), Vector3(sx * 6.5, 1.7, -0.62 - GATE_LEAF_W * 0.5)), Vector3(0.12, 3.5, GATE_LEAF_W)])
		out.append([Transform3D(Basis(), Vector3(sx * (GATE_PIER_OUT + 10.0) * 0.5, 0.55, 0)), Vector3(10.0 - GATE_PIER_OUT, 3.1, 0.5)])
	out.append([Transform3D(Basis(), Vector3(0, 10.6, 0)), Vector3(14.0, 2.8, 0.2)])
	return out


## The garden's railing along x from 0 to `length`, its street face toward +z: a sandstone base wall 0.5 high (footing
## to -1.5) with a coping, wrought-iron railings with spear tops to 2.2m, a sandstone pier every 12m and at both ends.
static func garden_fence(pk: PropKit, kit: Dictionary, length: float) -> void:
	_fence_run(pk, kit, 0.0, length, true)


## The railing's colliders: the wall and railing as one box per 12m, the piers.
static func garden_fence_solids(length: float) -> Array:
	var out: Array = []
	var n: int = maxi(1, int(ceil(length / 12.0)))
	for k in range(n):
		var a: float = length * float(k) / n
		var b: float = length * float(k + 1) / n
		out.append([Transform3D(Basis(), Vector3((a + b) * 0.5, 0.35, 0)), Vector3(b - a, 3.7, 0.5)])
	return out


static func _fence_run(pk: PropKit, kit: Dictionary, x0: float, x1: float, piers: bool) -> void:
	var l: float = x1 - x0
	_mblock(pk, kit, "ashlar", Vector3(x0, -1.5, -0.21), Vector3(x1, 0.42, 0.21), SAND)
	_mblock(pk, kit, "ashlar", Vector3(x0, 0.42, -0.26), Vector3(x1, 0.5, 0.26), SAND_LIGHT, true, true)
	var np: int = maxi(1, int(ceil(l / 12.0)))
	var pxs: Array = []
	if piers:
		for k in range(np + 1):
			pxs.append(lerpf(x0, x1, float(k) / np))
	for k in range(np):
		var a: float = lerpf(x0, x1, float(k) / np) + (0.3 if piers else 0.0)
		var b: float = lerpf(x0, x1, float(k + 1) / np) - (0.3 if piers else 0.0)
		if b - a < 0.2:
			continue
		var c := IRON_DARK
		for y in [0.66, 1.78, 1.96]:
			pk.beam(kit, "steel", Vector3(a, y, 0), Vector3(b, y, 0), 0.04, 0.035, c, UP)
		var nb: int = int((b - a) / 0.15)
		for i in range(nb + 1):
			var x: float = lerpf(a + 0.06, b - 0.06, float(i) / maxf(nb, 1))
			pk.beam(kit, "steel", Vector3(x, 0.47, 0), Vector3(x, 2.04, 0), 0.022, 0.022, c)
			pk.lathe(kit, "steel", Vector3(x, 2.02, 0), [Vector2(0.001, 0.0), Vector2(0.035, 0.02), Vector2(0.001, 0.17)], 4, c, true)
			if i % 2 == 0 and i < nb:
				var xm: float = x + (b - a - 0.12) / maxf(nb, 1) * 0.5
				KT._blob(pk, kit, "steel", Vector3(xm, 1.87, 0), Vector3(0.05, 0.07, 0.02), c)
	for px in pxs:
		_fence_pier(pk, kit, Vector3(px, 0, 0), 2.6)


## A railing's sandstone pier at `p`: 0.6 square to `h`, a cap and a ball.
static func _fence_pier(pk: PropKit, kit: Dictionary, p: Vector3, h: float) -> void:
	_mblock(pk, kit, "ashlar", p + Vector3(-0.3, -1.5, -0.3), p + Vector3(0.3, h, 0.3), SAND)
	_mblock(pk, kit, "ashlar", p + Vector3(-0.37, h, -0.37), p + Vector3(0.37, h + 0.16, 0.37), SAND_LIGHT, true, true)
	_lathe(pk, kit, "ashlar", p + Vector3(0, h + 0.15, 0), [Vector2(0.001, 0.0), Vector2(0.13, 0.0), Vector2(0.08, 0.05), Vector2(0.17, 0.17), Vector2(0.15, 0.27),
			Vector2(0.06, 0.33), Vector2(0.001, 0.34)], 10, SAND_LIGHT)


# ======================================================================================
#  Carpet bedding and borders
# ======================================================================================

const FL_RED := Color(0.86, 0.07, 0.09)
const FL_SCARLET := Color(0.90, 0.12, 0.05)
const FL_WHITE := Color(0.97, 0.97, 0.94)
const FL_BLUE := Color(0.40, 0.44, 0.92)
const FL_SILVER := Color(0.74, 0.76, 0.71)
const FL_YELLOW := Color(0.99, 0.80, 0.08)
const FL_ORANGE := Color(0.99, 0.47, 0.04)
const FL_PINK := Color(0.96, 0.42, 0.64)
const FL_PURPLE := Color(0.50, 0.24, 0.78)
const FL_DARK := Color(0.36, 0.06, 0.12)
const FL_LIME := Color(0.56, 0.76, 0.18)
const FL_LILAC := Color(0.72, 0.58, 0.92)
const SPIRE_COLS := [Color(0.24, 0.36, 0.90), Color(0.88, 0.44, 0.70), Color(0.95, 0.95, 0.92), Color(0.82, 0.18, 0.40), Color(0.46, 0.22, 0.72)]

## A formal bed of carpet bedding (a Teppichbeet), centred on the origin, `w` along x and `d` along z: `shape` 0 a
## rectangle with rounded corners, 1 a circle (diameter w), 2 an ellipse, 3 a long mixed border (its back -z, its front
## +z). `style` 0..5 picks the pattern and palette: 0 concentric rings (salvia, alyssum, ageratum, silver, begonias),
## 1 stripes (salvia, dusty miller, marigolds), 2 a harlequin of diamonds (begonias, heliotrope, marigold lines), 3 scrolls
## (a silver braid outlined in dark foliage on red begonias, a marigold edge), 4 a star (marigolds on ageratum), 5 a
## perennial border (drifts of dahlias, rudbeckias, asters, lavender, with delphinium and foxglove spires up to 1.2m).
## Shape 3 is always planted in drifts, its palette by style (warm, cool, pastel). Styles 0, 2 and 4 are edged in clipped
## box (0.3m), the others with a sandstone kerb. The planting is a mound up to 0.45m whose faces carry the pattern in
## their colours; garden_flowers draws the blossoms. About 2.5k triangles for a 10 x 6 bed.
static func flower_bed(pk: PropKit, kit: Dictionary, w: float, d: float, shape := 0, style := 0, seed_v := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + style * 31 + shape
	var outline: PackedVector2Array = _bed_outline(w, d, shape)
	var drift: bool = shape == 3 or style == 5
	var boxed: bool = not drift and style % 2 == 0
	var ew: float = 0.26 if boxed else 0.22
	if boxed:
		_band(pk, kit, "hedge", outline, ew, -0.1, 0.3, BOX_GREEN, true)
	else:
		_band(pk, kit, "ashlar", outline, ew, -0.35, 0.12, SAND_LIGHT, false)
	var inner: Array = Geometry2D.offset_polygon(outline, -ew * 0.55)
	if inner.is_empty():
		return
	var pin: PackedVector2Array = inner[0]
	var sites: Array = []
	if drift:
		sites = _drift_sites(w, d, style if shape == 3 else 0, rng)
	var info := {"w": w, "d": d, "shape": shape, "style": style, "drift": drift, "sites": sites, "seed": seed_v}
	var cell: float = clampf(sqrt(w * d / 950.0), 0.18, 0.5)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pin:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var nx: int = int(ceil((hi.x - lo.x) / cell))
	var nz: int = int(ceil((hi.y - lo.y) / cell))
	for i in range(nx):
		for j in range(nz):
			var a := Vector2(lo.x + cell * i, lo.y + cell * j)
			var sq := PackedVector2Array([a, a + Vector2(cell, 0), a + Vector2(cell, cell), a + Vector2(0, cell)])
			var full := true
			for q in sq:
				if not Geometry2D.is_point_in_polygon(q, pin):
					full = false
					break
			if full:
				# The diagonal that keeps each triangle's corners in its own colour zone (smoother zone edges).
				var c0: Color = _bed_colour(info, (sq[0] + sq[1] + sq[2]) / 3.0)
				var c1: Color = _bed_colour(info, (sq[0] + sq[2] + sq[3]) / 3.0)
				var c2: Color = _bed_colour(info, (sq[0] + sq[1] + sq[3]) / 3.0)
				var c3: Color = _bed_colour(info, (sq[1] + sq[2] + sq[3]) / 3.0)
				var m02: int = int(_bed_colour(info, sq[1]) == c0) + int(_bed_colour(info, sq[3]) == c1)
				var m13: int = int(_bed_colour(info, sq[0]) == c2) + int(_bed_colour(info, sq[2]) == c3)
				if m13 > m02:
					_bed_tri(pk, kit, info, sq[0], sq[1], sq[3], c2)
					_bed_tri(pk, kit, info, sq[1], sq[2], sq[3], c3)
				else:
					_bed_tri(pk, kit, info, sq[0], sq[1], sq[2], c0)
					_bed_tri(pk, kit, info, sq[0], sq[2], sq[3], c1)
			else:
				for piece in Geometry2D.intersect_polygons(sq, pin):
					var tris := Geometry2D.triangulate_polygon(piece)
					for k in range(0, tris.size(), 3):
						var pa: Vector2 = piece[tris[k]]
						var pb: Vector2 = piece[tris[k + 1]]
						var pc: Vector2 = piece[tris[k + 2]]
						_bed_tri(pk, kit, info, pa, pb, pc, _bed_colour(info, (pa + pb + pc) / 3.0))
	if drift:
		# Spires toward the back: delphiniums, foxgloves, hollyhocks.
		var ns: int = int(w * d * 0.55)
		for k in range(ns):
			var p := Vector2(rng.randf_range(-w * 0.45, w * 0.45), rng.randf_range(-d * 0.45, d * 0.15 if shape == 3 else d * 0.4))
			if not Geometry2D.is_point_in_polygon(p, pin):
				continue
			var y0: float = _bed_height(info, p) - 0.06
			var hgt: float = minf(rng.randf_range(0.75, 1.2) - y0, 1.2 - y0)
			var col: Color = SPIRE_COLS[rng.randi_range(0, SPIRE_COLS.size() - 1)]
			_spire(pk, kit, Vector3(p.x, y0, p.y), hgt, rng.randf_range(0.18, 0.26), col, rng.randf() * PI, float(rng.randi_range(0, 900)))


## A bed's outline in (x, z), counter-clockwise.
static func _bed_outline(w: float, d: float, shape: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	match shape:
		1, 2:
			var rx: float = w * 0.5
			var rz: float = (w if shape == 1 else d) * 0.5
			var n: int = clampi(int(TAU * maxf(rx, rz) / 0.45), 24, 64)
			for k in range(n):
				var a: float = TAU * float(k) / n
				out.append(Vector2(cos(a) * rx, sin(a) * rz))
		_:
			var rc: float = minf(w, d) * (0.22 if shape == 0 else 0.12)
			var hx: float = w * 0.5 - rc
			var hz: float = d * 0.5 - rc
			var cs: Array = [Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(hx, -hz)]
			for c in range(4):
				for k in range(7):
					var a: float = PI * 0.5 * float(c) + PI * 0.5 * float(k) / 6.0
					out.append((cs[c] as Vector2) + Vector2(cos(a), sin(a)) * rc)
	if PropKit._signed_area(out) < 0.0:
		out.reverse()
	return out


## A band along a closed outline (counter-clockwise, in x-z), `width` in from it, y0..y1: box edging (a crowned top,
## "hedge") or a kerb (a flat top). UVs in metres times uvk: along the outline, and up or across.
static func _band(pk: PropKit, kit: Dictionary, key: String, outline: PackedVector2Array, width: float, y0: float, y1: float, col: Color, crowned: bool) -> void:
	var n: int = outline.size()
	var inner: PackedVector2Array = PropKit._inset(outline, width)
	var q1: PackedVector2Array = PropKit._inset(outline, width * 0.22)
	var q2: PackedVector2Array = PropKit._inset(outline, width * 0.78)
	var run := 0.0
	var top_o: float = y1 - (0.07 if crowned else 0.0)
	for i in range(n):
		var j: int = (i + 1) % n
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[j]
		var e: Vector2 = b - a
		var l: float = e.length()
		if l < 1e-4:
			continue
		var o2 := Vector2(e.y, -e.x) / l
		var o := Vector3(o2.x, 0, o2.y)
		var u0: float = run * uvk
		var u1: float = (run + l) * uvk
		pk.quad(kit, key, [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, top_o, b.y), Vector3(a.x, top_o, a.y)], o, col,
				[Vector2(u0, y0 * uvk), Vector2(u1, y0 * uvk), Vector2(u1, top_o * uvk), Vector2(u0, top_o * uvk)])
		var ia: Vector2 = inner[i]
		var ib: Vector2 = inner[j]
		pk.quad(kit, key, [Vector3(ib.x, y0, ib.y), Vector3(ia.x, y0, ia.y), Vector3(ia.x, top_o, ia.y), Vector3(ib.x, top_o, ib.y)], -o, col.darkened(0.08),
				[Vector2(u0, y0 * uvk), Vector2(u1, y0 * uvk), Vector2(u1, top_o * uvk), Vector2(u0, top_o * uvk)])
		if crowned:
			var ring: Array = [[a, top_o], [q1[i], y1, q1[j]], [q2[i], y1, q2[j]], [ia, top_o]]
			var pts_i: Array = [Vector3(a.x, top_o, a.y), Vector3((q1[i] as Vector2).x, y1, (q1[i] as Vector2).y), Vector3((q2[i] as Vector2).x, y1, (q2[i] as Vector2).y),
					Vector3(ia.x, top_o, ia.y)]
			var pts_j: Array = [Vector3(b.x, top_o, b.y), Vector3((q1[j] as Vector2).x, y1, (q1[j] as Vector2).y), Vector3((q2[j] as Vector2).x, y1, (q2[j] as Vector2).y),
					Vector3(ib.x, top_o, ib.y)]
			var vs: Array = [0.0, width * 0.25, width * 0.75, width]
			for k in range(3):
				var nn: Vector3 = (o * (0.6 if k == 0 else (-0.6 if k == 2 else 0.0)) + UP).normalized()
				pk.quad(kit, key, [pts_i[k], pts_j[k], pts_j[k + 1], pts_i[k + 1]], nn, col.lightened(0.05),
						[Vector2(u0, vs[k] * uvk), Vector2(u1, vs[k] * uvk), Vector2(u1, vs[k + 1] * uvk), Vector2(u0, vs[k + 1] * uvk)])
			ring.clear()
		else:
			pk.quad(kit, key, [Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(ib.x, y1, ib.y), Vector3(ia.x, y1, ia.y)], UP, col.lightened(0.05),
					[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, width * uvk), Vector2(u0, width * uvk)])
		run += l


## A bed's planting triangle (plan points), at the mound's heights, smooth normals, coloured `col` (one zone).
static func _bed_tri(pk: PropKit, kit: Dictionary, info: Dictionary, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var pa := Vector3(a.x, _bed_height(info, a), a.y)
	var pb := Vector3(b.x, _bed_height(info, b), b.y)
	var pc := Vector3(c.x, _bed_height(info, c), c.y)
	var na: Vector3 = _bed_normal(info, a)
	var nb: Vector3 = _bed_normal(info, b)
	var nc: Vector3 = _bed_normal(info, c)
	pk.tri(kit, "gflower", pa, pb, pc, na, nb, nc, col, UP, a, b, c)


static func _bed_normal(info: Dictionary, p: Vector2) -> Vector3:
	var e := 0.08
	var hx: float = _bed_height(info, p + Vector2(e, 0)) - _bed_height(info, p - Vector2(e, 0))
	var hz: float = _bed_height(info, p + Vector2(0, e)) - _bed_height(info, p - Vector2(0, e))
	return Vector3(-hx, 2.0 * e, -hz).normalized()


## The mound's height over a plan point: low at the edge, rising inward (to 0.45 at most), lumpy; a border rises to its
## back and steps with its drifts.
static func _bed_height(info: Dictionary, p: Vector2) -> float:
	var w: float = info["w"]
	var d: float = info["d"]
	var u: float = p.x / (w * 0.5)
	var v: float = p.y / (d * 0.5)
	var lump: float = 0.035 * _vn2(p.x * 2.2, p.y * 2.2, int(info["seed"]))
	if info["drift"]:
		var dr: Array = _drift_at(info, p)
		var dh: float = dr[2]
		var e: float = minf(minf(w * 0.5 - absf(p.x), d * 0.5 - absf(p.y)) / 0.6, 1.0) if int(info["shape"]) != 1 and int(info["shape"]) != 2 else clampf((1.0 - sqrt(u * u + v * v)) * 2.5, 0.0, 1.0)
		return 0.1 + (dh - 0.1) * clampf(e, 0.25, 1.0) + lump
	var r: float = _bed_r(info, u, v)
	var h: float = 0.1 + 0.28 * (1.0 - r * r)
	var style: int = info["style"]
	if (style == 0 or style == 4) and r < 0.24:
		h += 0.06 * (1.0 - r / 0.24)
	return minf(h + lump, 0.45)


static func _bed_r(info: Dictionary, u: float, v: float) -> float:
	var shape: int = info["shape"]
	if shape == 1 or shape == 2:
		return sqrt(u * u + v * v)
	return pow(pow(absf(u), 4.0) + pow(absf(v), 4.0), 0.25)


## The planting's colour (and garden_flowers kind) at a plan point.
static func _bed_colour(info: Dictionary, p: Vector2) -> Color:
	var w: float = info["w"]
	var d: float = info["d"]
	var u: float = p.x / (w * 0.5)
	var v: float = p.y / (d * 0.5)
	if info["drift"]:
		return (_drift_at(info, p)[1] as Color)
	var r: float = _bed_r(info, u, v)
	match int(info["style"]):
		0:
			if r < 0.22:
				return _fk(FL_SCARLET, 2)
			if r < 0.38:
				return _fk(FL_WHITE, 9)
			if r < 0.62:
				return _fk(FL_BLUE, 4)
			if r < 0.74:
				return _fk(FL_SILVER, 5)
			if r < 0.88:
				return _fk(FL_RED, 1)
			return _fk(FL_DARK, 6)
		1:
			if r > 0.86:
				return _fk(FL_DARK, 6)
			var idx: int = posmod(int(floor(p.x / 0.7 + 0.5)), 4)
			return [_fk(FL_SCARLET, 2), _fk(FL_SILVER, 5), _fk(FL_ORANGE, 3), _fk(FL_SILVER, 5)][idx]
		2:
			if r > 0.86:
				return _fk(FL_WHITE, 9)
			var a: float = (p.x + p.y) / 0.95
			var b: float = (p.x - p.y) / 0.95
			var fa: float = absf(a - round(a))
			var fb: float = absf(b - round(b))
			if minf(fa, fb) < 0.09:
				return _fk(FL_YELLOW, 3)
			return _fk(FL_PINK, 1) if posmod(int(floor(a)) + int(floor(b)), 2) == 0 else _fk(FL_PURPLE, 4)
		3:
			if r > 0.86:
				return _fk(FL_YELLOW, 3)
			var wave: float = 0.4 * sin(u * PI * 1.5)
			var s1: float = absf(v - wave)
			var s2: float = absf(v + wave)
			var s: float = minf(s1, s2)
			if s < 0.11:
				return _fk(FL_SILVER, 5)
			if s < 0.18:
				return _fk(FL_DARK, 6)
			return _fk(FL_RED, 1)
		_:
			var ang: float = atan2(v, u)
			var star: float = 0.3 + 0.42 * pow(absf(cos(4.0 * ang)), 2.5)
			if r < 0.16:
				return _fk(FL_SCARLET, 2)
			if r < star:
				return _fk(FL_YELLOW, 3)
			if r < 0.84:
				return _fk(FL_BLUE, 4)
			if r < 0.93:
				return _fk(FL_WHITE, 9)
			return _fk(FL_DARK, 6)


## A border's drifts: sites on a jittered grid stretched along x, each with a plant (colour and kind) and a height by
## how far back it stands. `palette` 0 warm, 1 cool, 2 pastel.
static func _drift_sites(w: float, d: float, palette: int, rng: RandomNumberGenerator) -> Array:
	var back: Array
	var mid: Array
	var front: Array
	match palette % 3:
		0:
			back = [_fk(FL_SCARLET, 7), _fk(FL_ORANGE, 7), _fk(FL_YELLOW, 10), _fk(FL_PURPLE, 8)]
			mid = [_fk(FL_YELLOW, 10), _fk(FL_RED, 7), _fk(FL_LILAC, 8), _fk(FL_PURPLE, 12)]
			front = [_fk(FL_ORANGE, 3), _fk(FL_BLUE, 4), _fk(FL_WHITE, 9), _fk(FL_RED, 1)]
		1:
			back = [_fk(FL_PURPLE, 8), _fk(FL_LILAC, 8), _fk(FL_PINK, 7), _fk(FL_WHITE, 7)]
			mid = [_fk(FL_PURPLE, 12), _fk(FL_LILAC, 8), _fk(FL_BLUE, 4), _fk(FL_PINK, 7)]
			front = [_fk(FL_WHITE, 9), _fk(FL_BLUE, 4), _fk(FL_SILVER, 5), _fk(FL_PINK, 1)]
		_:
			back = [_fk(FL_PINK, 7), _fk(FL_WHITE, 7), _fk(Color(0.98, 0.72, 0.55), 7), _fk(FL_LILAC, 8)]
			mid = [_fk(Color(0.98, 0.88, 0.45), 10), _fk(FL_PINK, 8), _fk(FL_PURPLE, 12), _fk(FL_WHITE, 8)]
			front = [_fk(FL_WHITE, 9), _fk(FL_PINK, 1), _fk(FL_LILAC, 4), _fk(FL_SILVER, 5)]
	var out: Array = []
	var sx := 1.3
	var sz := 0.9
	var nx: int = maxi(1, int(ceil(w / sx)))
	var nz: int = maxi(1, int(ceil(d / sz)))
	for i in range(nx + 1):
		for j in range(nz + 1):
			var p := Vector2(-w * 0.5 + (float(i) + rng.randf_range(-0.35, 0.35)) * w / nx, -d * 0.5 + (float(j) + rng.randf_range(-0.35, 0.35)) * d / nz)
			var depth: float = p.y / (d * 0.5)
			var list: Array = back if depth < -0.3 else (mid if depth < 0.35 else front)
			var hgt: float = (0.43 if depth < -0.3 else (0.33 if depth < 0.35 else 0.2)) + rng.randf_range(-0.03, 0.02)
			out.append([p, list[rng.randi_range(0, list.size() - 1)], hgt])
	return out


## The drift (site) nearest a plan point, its distance stretched along x so drifts run along the border.
static func _drift_at(info: Dictionary, p: Vector2) -> Array:
	var best: Array = info["sites"][0]
	var bd := INF
	for s in info["sites"]:
		var q: Vector2 = s[0]
		var dd: float = Vector2((p.x - q.x) * 0.7, p.y - q.y).length_squared()
		if dd < bd:
			bd = dd
			best = s
	return best


## A flower spire (a card pair crossed at right angles, garden_flowers kind 15) standing at `base`, `h` tall, `w` wide.
static func _spire(pk: PropKit, kit: Dictionary, base: Vector3, h: float, w: float, col: Color, yaw: float, id: float) -> void:
	var fc: Color = _fk(col, 15)
	for k in range(2):
		var a: float = yaw + PI * 0.5 * float(k)
		var s := Vector3(cos(a), 0, sin(a)) * (w * 0.5)
		var n := Vector3(-sin(a), 0, cos(a))
		var idf: float = id + float(k) * 3.0
		pk.quad(kit, "gflower", [base - s, base + s, base + s + UP * h, base - s + UP * h], n, fc,
				[Vector2(idf + 0.001, 0), Vector2(idf + 0.999, 0), Vector2(idf + 0.999, 1), Vector2(idf + 0.001, 1)])


# ======================================================================================
#  Roses: the pergola over the road and the rose beds
# ======================================================================================

const ROSE_COLS := [Color(0.80, 0.05, 0.10), Color(0.95, 0.45, 0.62), Color(0.98, 0.70, 0.75), Color(0.95, 0.94, 0.88), Color(0.98, 0.62, 0.40),
		Color(0.62, 0.04, 0.12)]
const IRON_GREEN := Color(0.10, 0.20, 0.15)

## One arch of the rose pergola (Rosenlaube) over the road, the road along z on x = 0: lattice posts at |x| = span / 2
## on sandstone bases, a double iron arch with rings between its bars (its underside at least ROSE_ARCH_CLEAR for |x| <=
## ROSE_ARCH_CLEAR_X; crown 9.1), rails toward -z for `bay` metres to the next arch's posts (0: none, the row's last),
## and climbing roses up the posts, along the arch and in swags along the rails. Under 4k triangles.
static func rose_arch(pk: PropKit, kit: Dictionary, span := 13.0, bay := 6.0, seed_v := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 977 + 5
	var hx: float = span * 0.5
	var c := IRON_GREEN
	var b_out: float = ROSE_ARCH_RISE
	var b_in: float = ROSE_ARCH_RISE - 0.32
	var arch_y := func(x: float, b: float) -> float:
		var t: float = clampf(x / hx, -1.0, 1.0)
		return ROSE_POST_TOP + b * sqrt(1.0 - t * t)
	for sx in [1.0, -1.0]:
		var px: float = sx * hx
		_mblock(pk, kit, "ashlar", Vector3(px - 0.32, -1.0, -0.32), Vector3(px + 0.32, 0.5, 0.32), SAND)
		_mblock(pk, kit, "ashlar", Vector3(px - 0.37, 0.5, -0.37), Vector3(px + 0.37, 0.62, 0.37), SAND_LIGHT, true, true)
		for dz in [-0.16, 0.16]:
			for dx in [-0.12, 0.12]:
				pk.beam(kit, "steel", Vector3(px + dx, 0.6, dz), Vector3(px + dx, ROSE_POST_TOP + 0.05, dz), 0.045, 0.045, c)
		var ny := 9
		for k in range(ny):
			var y0: float = 0.9 + (ROSE_POST_TOP - 1.0) * float(k) / ny
			var y1: float = 0.9 + (ROSE_POST_TOP - 1.0) * float(k + 1) / ny
			for dz in [-0.16, 0.16]:
				pk.beam(kit, "steel", Vector3(px - 0.12, y0, dz), Vector3(px + 0.12, y1, dz), 0.025, 0.02, c, Vector3(0, 0, 1))
			pk.beam(kit, "steel", Vector3(px - 0.12, y0, -0.16), Vector3(px - 0.12, y0, 0.16), 0.025, 0.025, c)
			pk.beam(kit, "steel", Vector3(px + 0.12, y0, -0.16), Vector3(px + 0.12, y0, 0.16), 0.025, 0.025, c)
		pk.lathe(kit, "steel", Vector3(px, ROSE_POST_TOP + 0.02, 0), [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.2, 0.06), Vector2(0.001, 0.08)], 4, c, true,
				Basis(UP, PI * 0.25))
	# The double arch and its rings.
	for b in [b_out, b_in]:
		var pts: Array = []
		for k in range(25):
			var x: float = lerpf(-hx, hx, float(k) / 24.0)
			pts.append(Vector3(x, arch_y.call(x, b), 0))
		_bars(pk, kit, "steel", pts, 0.05, 0.06, c, Vector3(0, 0, 1))
	for k in range(1, 10):
		var x2: float = lerpf(-hx, hx, float(k) / 10.0)
		var yc: float = (arch_y.call(x2, b_out) + arch_y.call(x2, b_in)) * 0.5
		var rr: float = (arch_y.call(x2, b_out) - arch_y.call(x2, b_in)) * 0.42
		if rr > 0.05:
			_bars(pk, kit, "steel", _scroll_pts(Vector3(x2, yc, 0), Vector3.RIGHT, UP, rr, rr, 0.0, 1.0, 6), 0.025, 0.03, c, Vector3(0, 0, 1))
	pk.lathe(kit, "gold", Vector3(0, ROSE_POST_TOP + b_out + 0.02, 0), [Vector2(0.001, 0.0), Vector2(0.06, 0.04), Vector2(0.07, 0.1), Vector2(0.001, 0.22)], 6, GILT)
	# Rails toward the next arch.
	var rails: Array = []
	if bay > 0.01:
		for x3 in [-hx, -4.2, 0.0, 4.2, hx]:
			var y3: float = ROSE_POST_TOP if absf(x3) >= hx - 0.01 else arch_y.call(x3, b_out)
			pk.beam(kit, "steel", Vector3(x3, y3, 0.0), Vector3(x3, y3, -bay), 0.04, 0.04, c, UP)
			rails.append(Vector3(x3, y3, 0))
	# Climbing roses: stems up the posts with clumps of leaves and blooms, garlands along the arch, swags along the rails.
	var pal: Array = [ROSE_COLS[rng.randi_range(0, 5)], ROSE_COLS[rng.randi_range(0, 5)]]
	for sx in [1.0, -1.0]:
		var px2: float = sx * hx
		var stem: Array = []
		for k in range(9):
			var y4: float = 0.6 + (ROSE_POST_TOP - 0.4) * float(k) / 8.0
			var a4: float = float(k) * 1.4
			stem.append(Vector3(px2 + cos(a4) * 0.2, y4, sin(a4) * 0.22))
		_tube(pk, kit, "gleaf", stem, 0.025, 4, _gm(Color(0.28, 0.25, 0.14), 1.0))
		for k in range(7):
			var y5: float = 1.0 + (ROSE_POST_TOP - 0.8) * float(k) / 6.0
			var a5: float = float(k) * 2.1 + rng.randf()
			var cpos := Vector3(px2 + cos(a5) * 0.24, y5, sin(a5) * 0.26)
			_lump(pk, kit, "gflower", cpos, Vector3(0.36, 0.34, 0.36) * rng.randf_range(0.85, 1.15), _fk(pal[k % 2], 11), rng, 6, 3, 0.25, false)
	for k in range(13):
		var t: float = lerpf(-0.97, 0.97, float(k) / 12.0)
		var x6: float = hx * t
		var y6: float = arch_y.call(x6, b_out)
		var size: float = rng.randf_range(0.3, 0.42)
		var lift: float = 0.12 if absf(x6) <= ROSE_ARCH_CLEAR_X + 0.4 else -0.05
		_lump(pk, kit, "gflower", Vector3(x6, y6 + lift, rng.randf_range(-0.12, 0.12)), Vector3(size, size * 0.85, size * 1.1), _fk(pal[k % 2], 11), rng, 6, 3, 0.25, false)
	if bay > 0.01:
		for r in rails:
			var rp: Vector3 = r
			var sag: float = 0.35 if absf(rp.x) < hx - 0.01 else 0.5
			for k in range(1, 5):
				var t2: float = float(k) / 5.0
				var dy: float = -sag * sin(t2 * PI)
				var q := Vector3(rp.x, rp.y + dy + (0.05 if absf(rp.x) < hx - 0.01 else -0.1), -bay * t2)
				var size2: float = rng.randf_range(0.26, 0.36)
				_lump(pk, kit, "gflower", q, Vector3(size2, size2 * 0.8, size2 * 1.3), _fk(pal[(k + int(rp.x)) % 2], 11), rng, 6, 2, 0.25, false)


## The rose arch's colliders: its posts and bases (both sides).
static func rose_arch_solids(span := 13.0) -> Array:
	var out: Array = []
	for sx in [1.0, -1.0]:
		out.append([Transform3D(Basis(), Vector3(sx * span * 0.5, (ROSE_POST_TOP - 1.0) * 0.5, 0)), Vector3(0.7, ROSE_POST_TOP + 1.0, 0.7)])
	return out


## A rose bed centred on the origin, `length` along x and `depth` along z: a clipped box edge, dark mulch, two or three rows
## of bush roses in blocks of colour, standard (tree) roses on stakes down the middle every 2.5m and lavender along the
## front (+z).
static func rose_bed(pk: PropKit, kit: Dictionary, length := 10.0, depth := 2.4, seed_v := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 613 + 11
	var outline: PackedVector2Array = _bed_outline(length, depth, 3)
	_band(pk, kit, "hedge", outline, 0.22, -0.1, 0.26, BOX_GREEN, true)
	var inner: Array = Geometry2D.offset_polygon(outline, -0.12)
	if not inner.is_empty():
		var pin: PackedVector2Array = inner[0]
		var tris := Geometry2D.triangulate_polygon(pin)
		for i in range(0, tris.size(), 3):
			var a: Vector2 = pin[tris[i]]
			var b: Vector2 = pin[tris[i + 1]]
			var c: Vector2 = pin[tris[i + 2]]
			pk.tri(kit, "matte", Vector3(a.x, 0.08, a.y), Vector3(b.x, 0.08, b.y), Vector3(c.x, 0.08, c.y), UP, UP, UP, MULCH, UP)
	var hl: float = length * 0.5 - 0.45
	var rows: int = 3 if depth >= 2.2 else 2
	var block: float = 2.5
	for r in range(rows):
		var z: float = lerpf(-depth * 0.5 + 0.5, depth * 0.5 - 0.55, float(r) / maxf(rows - 1, 1))
		if rows == 3 and r == 1:
			continue
		var n: int = int(2.0 * hl / 0.62) + 1
		for k in range(n):
			var x: float = -hl + 2.0 * hl * float(k) / maxf(n - 1, 1) + rng.randf_range(-0.06, 0.06)
			var col: Color = ROSE_COLS[posmod(int(floor((x + hl) / block)) + seed_v, ROSE_COLS.size())]
			var s: float = rng.randf_range(0.3, 0.38)
			_lump(pk, kit, "gflower", Vector3(x, 0.06, z + rng.randf_range(-0.06, 0.06)), Vector3(s, 0.62, s), _fk(col, 11), rng, 7, 3, 0.2)
	# Standard roses down the middle.
	var ns: int = maxi(1, int(length / 2.5))
	for k in range(ns):
		var x2: float = -length * 0.5 + length * (float(k) + 0.5) / ns
		var col2: Color = ROSE_COLS[(k * 2 + seed_v) % ROSE_COLS.size()]
		_tube(pk, kit, "gleaf", [Vector3(x2, 0.0, 0.0), Vector3(x2, 1.35, 0.0)], 0.025, 5, _gm(Color(0.34, 0.28, 0.18), 1.0))
		_box(pk, kit, "timber", Vector3(x2 + 0.06, 0.65, 0.0), Basis(), Vector3(0.035, 1.4, 0.035), Color(0.55, 0.42, 0.28))
		_lump(pk, kit, "gflower", Vector3(x2, 1.25, 0.0), Vector3(0.4, 0.36, 0.4), _fk(col2, 11), rng, 8, 4, 0.2, false)
	# Lavender along the front.
	var nl: int = int(length / 0.5)
	for k in range(nl):
		var x3: float = -length * 0.5 + 0.4 + (length - 0.8) * float(k) / maxf(nl - 1, 1)
		_lump(pk, kit, "gflower", Vector3(x3, 0.04, depth * 0.5 - 0.3), Vector3(0.26, 0.38, 0.22), _fk(Color(0.48, 0.38, 0.80), 12), rng, 6, 2, 0.2)


# ======================================================================================
#  Dressed stone: balusters, balustrades, urns
# ======================================================================================

## A turned baluster standing on `foot`, `h` tall (0.62 the standard): a vase with its belly low, a neck and a collar,
## six-sided and smooth. Open at both ends: they stand a centimetre into the plinth and the rail.
static func _baluster(pk: PropKit, kit: Dictionary, foot: Vector3, h: float, col: Color) -> void:
	var k: float = h / 0.62
	var prof: Array = [Vector2(0.062, 0.0), Vector2(0.066, 0.03 * k), Vector2(0.054, 0.06 * k), Vector2(0.086, 0.19 * k), Vector2(0.078, 0.28 * k),
			Vector2(0.042, 0.42 * k), Vector2(0.034, 0.48 * k), Vector2(0.053, 0.515 * k), Vector2(0.04, 0.545 * k), Vector2(0.064, 0.6 * k), Vector2(0.064, h)]
	_lathe(pk, kit, "ashlar", foot, prof, 6, col)


## A ball finial on a pedestal's cap at `p`: a square base, a neck and a ball `r` across its half.
static func _ball_finial(pk: PropKit, kit: Dictionary, p: Vector3, r: float, col: Color) -> void:
	_box(pk, kit, "ashlar", p + Vector3(0, 0.035, 0), Basis(), Vector3(r * 1.5, 0.08, r * 1.5), col)
	var prof: Array = [Vector2(0.001, 0.07), Vector2(r * 0.42, 0.07), Vector2(r * 0.32, 0.07 + r * 0.25)]
	for k in range(1, 9):
		var a: float = -PI * 0.5 + PI * float(k) / 8.0
		prof.append(Vector2(r * cos(a) + 0.0005, 0.07 + r * 0.25 + r + r * sin(a)))
	_lathe(pk, kit, "ashlar", p, prof, 10, col)


## A stone balustrade along the polyline `pts` (its foot line, the top of what it stands on, y included), `h` from its foot
## to the top of its rail: a plinth, turned balusters about 0.3m apart (upright on a slope), a moulded rail, and pedestals
## `pw` square (caps `cap_w`) at both ends (with `end_peds`), at the line's corners and about every `every` metres. Finials
## (0 none, 1 a ball, 2 an urn) on the end pedestals (`fin_end`) and the others (`fin_mid`). It keeps within
## max(0.19, cap_w / 2) of the line.
static func _balustrade_run(pk: PropKit, kit: Dictionary, pts: Array, h := 1.0, col := SAND_LIGHT, every := 3.0, fin_end := 1, fin_mid := 0,
		pw := 0.46, cap_w := 0.56, end_peds := true) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	# The plinth (its top 0.17 over the foot, sunk 5cm) and the rail, each running on through the pedestals.
	var run := 0.0
	for i in range(n - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var l: float = Vector2(b.x - a.x, b.z - a.z).length()
		if l < 1e-4:
			continue
		var last: bool = i == n - 2
		_sloped(pk, kit, "ashlar", a + UP * 0.17, b + UP * 0.17, 0.34, 0.22, col.darkened(0.04), false, i == 0 or last, run)
		_sloped(pk, kit, "ashlar", a + UP * h, b + UP * h, 0.38, 0.13, col, true, i == 0 or last, run)
		_sloped(pk, kit, "ashlar", a + UP * (h - 0.12), b + UP * (h - 0.12), 0.3, 0.07, col.darkened(0.06), true, i == 0 or last, run)
		run += l
	# Pedestals: [position (foot), along (plan, unit), is_end]: at the ends, at the line's corners (a turn in plan over 10
	# degrees, or a break in its slope: a stair's landing), and evenly along each leg between them, about `every` apart.
	var peds: Array = []
	var legs: Array = [0]
	for i in range(1, n - 1):
		var p0: Vector3 = pts[i - 1]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var d0 := Vector2(p1.x - p0.x, p1.z - p0.z)
		var d1 := Vector2(p2.x - p1.x, p2.z - p1.z)
		if d0.length() < 1e-4 or d1.length() < 1e-4:
			continue
		var g0: float = (p1.y - p0.y) / d0.length()
		var g1: float = (p2.y - p1.y) / d1.length()
		if d0.normalized().dot(d1.normalized()) < cos(deg_to_rad(10.0)) or absf(g1 - g0) > 0.12:
			legs.append(i)
	legs.append(n - 1)
	for li in range(legs.size() - 1):
		var i0: int = legs[li]
		var i1: int = legs[li + 1]
		var cum: Array = [0.0]
		for i in range(i0, i1):
			cum.append(float(cum[cum.size() - 1]) + Vector2((pts[i + 1] as Vector3).x - (pts[i] as Vector3).x, (pts[i + 1] as Vector3).z - (pts[i] as Vector3).z).length())
		var ll: float = cum[cum.size() - 1]
		if ll < 1e-3:
			continue
		var al0: Vector3 = Vector3((pts[i0 + 1] as Vector3).x - (pts[i0] as Vector3).x, 0, (pts[i0 + 1] as Vector3).z - (pts[i0] as Vector3).z).normalized()
		if li == 0:
			if end_peds:
				peds.append([(pts[0] as Vector3) + al0 * (pw * 0.5), al0, true])
		else:
			peds.append([pts[i0], al0, false])
		var np: int = maxi(1, int(round(ll / every)))
		for k in range(1, np):
			var d: float = ll * float(k) / float(np)
			for j in range(cum.size() - 1):
				if d <= float(cum[j + 1]) + 1e-5:
					var pa: Vector3 = pts[i0 + j]
					var pb: Vector3 = pts[i0 + j + 1]
					var t: float = (d - float(cum[j])) / maxf(float(cum[j + 1]) - float(cum[j]), 1e-5)
					peds.append([pa.lerp(pb, t), Vector3(pb.x - pa.x, 0, pb.z - pa.z).normalized(), false])
					break
		if li == legs.size() - 2 and end_peds:
			var pe: Vector3 = pts[n - 1]
			var pq: Vector3 = pts[n - 2]
			var al1 := Vector3(pe.x - pq.x, 0, pe.z - pq.z).normalized()
			peds.append([pe - al1 * (pw * 0.5), al1, true])
	# Balusters between the pedestals.
	for i in range(n - 1):
		var a2: Vector3 = pts[i]
		var b2: Vector3 = pts[i + 1]
		var l2: float = Vector2(b2.x - a2.x, b2.z - a2.z).length()
		var nb: int = int(l2 / 0.3)
		for k in range(nb):
			var t: float = (float(k) + 0.5) / float(nb)
			var p: Vector3 = a2.lerp(b2, t)
			var near := false
			for pd in peds:
				var q: Vector3 = pd[0]
				if Vector2(p.x - q.x, p.z - q.z).length() < pw * 0.5 + 0.12:
					near = true
					break
			if not near:
				_baluster(pk, kit, p + UP * 0.16, h - 0.27, col)
	for pd in peds:
		var q2: Vector3 = pd[0]
		var al3: Vector3 = pd[1]
		var bs := Basis(al3.cross(UP).normalized(), UP, al3)
		# On a slope the pedestal stands on the line's lower side, so its foot is never in the air.
		var dy: float = 0.0
		for j in range(n - 1):
			var pa: Vector3 = pts[j]
			var pb: Vector3 = pts[j + 1]
			var sl: float = (pb.y - pa.y) / maxf(Vector2(pb.x - pa.x, pb.z - pa.z).length(), 1e-3)
			dy = maxf(dy, absf(sl) * pw * 0.5)
		var foot: float = q2.y - dy - 0.05
		var top: float = q2.y + h + 0.04
		_box(pk, kit, "ashlar", Vector3(q2.x, (foot + top) * 0.5, q2.z), bs, Vector3(pw, top - foot, pw), col.lightened(0.02))
		_box(pk, kit, "ashlar", Vector3(q2.x, foot + 0.11, q2.z), bs, Vector3(pw + 0.06, 0.22, pw + 0.06), col.darkened(0.03))
		_box(pk, kit, "ashlar", Vector3(q2.x, top + 0.04, q2.z), bs, Vector3(cap_w, 0.1, cap_w), col.lightened(0.04))
		var fin: int = fin_end if pd[2] else fin_mid
		if fin == 1:
			_ball_finial(pk, kit, Vector3(q2.x, top + 0.085, q2.z), 0.16, col)
		elif fin == 2:
			urn(pk, kit, Vector3(q2.x, top + 0.085, q2.z), 0.55)


## A garden urn (Vase) of dressed sandstone at `at`, `s` its scale (1: 1.0m to its rim, 0.64m across the lip): a square
## plinth, a turned foot and stem, a campana body with a band of gadroons, its handles, a moulded lip; planted with
## geraniums and trailing ivy, or (`lidded`) closed by a domed lid with a flame finial (a gate pier's).
static func urn(pk: PropKit, kit: Dictionary, at := Vector3.ZERO, s := 1.0, lidded := false) -> void:
	var col: Color = SAND_LIGHT
	_box(pk, kit, "plaster", at + Vector3(0, 0.05 * s, 0), Basis(), Vector3(0.46, 0.2, 0.46) * s, col.darkened(0.04))
	_box(pk, kit, "plaster", at + Vector3(0, 0.16 * s, 0), Basis(), Vector3(0.4, 0.04, 0.4) * s, col)
	var prof: Array = [Vector2(0.17, 0.17), Vector2(0.17, 0.21), Vector2(0.12, 0.235), Vector2(0.075, 0.28), Vector2(0.07, 0.33), Vector2(0.1, 0.35),
			Vector2(0.1, 0.37), Vector2(0.14, 0.39), Vector2(0.21, 0.45), Vector2(0.255, 0.53), Vector2(0.27, 0.6), Vector2(0.255, 0.66), Vector2(0.235, 0.7),
			Vector2(0.245, 0.73), Vector2(0.275, 0.79), Vector2(0.31, 0.86), Vector2(0.325, 0.9), Vector2(0.32, 0.93), Vector2(0.29, 0.94),
			Vector2(0.275, 0.9)]
	var sp: Array = []
	for q in prof:
		sp.append((q as Vector2) * s)
	_lathe(pk, kit, "plaster", at, sp, 12, col)
	# Gadroons round the lower body: rounded lobes standing a little proud of it.
	var grng := RandomNumberGenerator.new()
	grng.seed = 11
	for k in range(12):
		var a: float = TAU * (float(k) + 0.5) / 12.0
		var d := Vector3(cos(a), 0, sin(a))
		_lump(pk, kit, "plaster", at + (d * 0.2 + Vector3(0, 0.47, 0)) * s, Vector3(0.05, 0.08, 0.05) * s, col.darkened(0.03), grng, 5, 2, 0.0, false)
	# Two scroll handles on the shoulder.
	for sx in [1.0, -1.0]:
		var hp: Array = []
		for k in range(7):
			var t: float = float(k) / 6.0
			var ang: float = lerpf(-PI * 0.4, PI * 0.75, t)
			hp.append(at + Vector3(sx * (0.26 + 0.07 * cos(ang)), 0.66 + 0.08 * sin(ang), 0) * s)
		_tube(pk, kit, "plaster", hp, 0.022 * s, 5, col, true, false, uvk)
	if lidded:
		_lathe(pk, kit, "plaster", at + Vector3(0, 0.885 * s, 0), [Vector2(0.001, 0.0), Vector2(0.3 * s, 0.0), Vector2(0.3 * s, 0.03 * s),
				Vector2(0.24 * s, 0.1 * s), Vector2(0.14 * s, 0.16 * s), Vector2(0.07 * s, 0.19 * s), Vector2(0.08 * s, 0.22 * s), Vector2(0.11 * s, 0.3 * s),
				Vector2(0.09 * s, 0.39 * s), Vector2(0.05 * s, 0.46 * s), Vector2(0.001, 0.56 * s)], 12, col)
		return
	# Soil, a mound of geraniums and ivy trailing over the lip.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(at.x * 13.0 + at.z * 7.0)) + 3
	pk.lathe(kit, "matte", at + Vector3(0, 0.88 * s, 0), [Vector2(0.28 * s, 0.0), Vector2(0.001, 0.0)], 10, SOIL)
	var bloom: Color = [FL_RED, FL_SCARLET, FL_PINK, FL_WHITE][rng.randi_range(0, 3)]
	# The mound spills just over the lip (its foot ring r 0.34 at 0.89, outside the lip's 0.325).
	_lump(pk, kit, "gflower", at + Vector3(0, 0.96 * s, 0), Vector3(0.365, 0.2, 0.365) * s, _fk(bloom, 14), rng, 12, 3, 0.16, true)
	# A spiky dracaena in the middle, over the geraniums.
	for k2 in range(9):
		var a3: float = TAU * float(k2) / 9.0 + rng.randf() * 0.4
		var up: float = rng.randf_range(1.3, 2.6)
		_card(pk, kit, at + Vector3(0, 1.04 * s, 0), Vector3(cos(a3), up, sin(a3)).normalized(), rng.randf_range(0.32, 0.45) * s, 0.025 * s, 0.06 * s, 0.25,
				_gm(Color(0.20, 0.34, 0.16), 0.2), float(k2), 3, 0.0, Vector3.ZERO, "gleaf", 0.2)
	# Ivy over the lip on the urns that stand on the ground (a pedestal's small ones go without).
	for k in range(4 if s >= 0.8 else 0):
		var a2: float = TAU * (float(k) + rng.randf() * 0.5) / 4.0
		var d2 := Vector3(cos(a2), 0, sin(a2))
		var ivy: Array = []
		for j in range(5):
			var t2: float = float(j) / 4.0
			ivy.append(at + (d2 * (0.33 + 0.06 * sin(t2 * PI)) + Vector3(0, 0.93 - 0.42 * t2, 0) + d2 * 0.04 * t2) * s)
		_tube(pk, kit, "gleaf", ivy, 0.012 * s, 3, _gm(Color(0.25, 0.22, 0.12), 1.0))
		for j in range(1, 5):
			for side in [-1.0, 1.0]:
				var ld: Vector3 = (d2.cross(UP) * side + d2 * 0.6 + Vector3(0, -0.3, 0)).normalized()
				_card(pk, kit, ivy[j], ld, 0.09 * s, 0.04 * s, 0.01 * s, 0.25, _gm(Color(0.12, 0.30, 0.10), 0.45), _croton_id(float(rng.randi_range(0, 400)), false), 2)


## The terrace's balustrade along x from 0 to `length` (life m), its foot on y = 0, centred on z = 0: plinth, turned
## balusters, rail, pedestals every 3m with balls on the end ones. 1.0m to the rail's top, 1.25m to the finials.
static func balustrade(pk: PropKit, kit: Dictionary, length: float) -> void:
	if length < 0.6:
		return
	_balustrade_run(pk, kit, [Vector3(0, 0, 0), Vector3(length, 0, 0)], 1.0, SAND_LIGHT, 3.0, 1, 0)


# ======================================================================================
#  Hedges and topiary
# ======================================================================================

const HEDGE_GREEN := Color(0.16, 0.29, 0.11)

## A clipped hedge (yew and box) along x from 0 to `length`, `h` tall and `w` wide, centred on z = 0: a slightly battered
## section, fuller at the waist, its top edges rounded by the shears, wavering a little along its length; "hedge" foliage,
## its foot sunk 6cm. About 20 triangles a metre.
static func hedge(pk: PropKit, kit: Dictionary, length: float, h := 1.1, w := 0.8) -> void:
	if length < 0.2:
		return
	var hw: float = w * 0.5
	# The section from the foot on one side over the top to the other foot: (offset from the middle, height).
	var sec: Array = [Vector2(hw - 0.04, -0.06), Vector2(hw, h * 0.32), Vector2(hw - 0.012, h * 0.78), Vector2(hw - 0.05, h - 0.035),
			Vector2(hw - 0.13, h), Vector2(0.0, h + 0.012), Vector2(-(hw - 0.13), h), Vector2(-(hw - 0.05), h - 0.035), Vector2(-(hw - 0.012), h * 0.78),
			Vector2(-hw, h * 0.32), Vector2(-(hw - 0.04), -0.06)]
	var vs: Array = [0.0]
	for i in range(1, sec.size()):
		vs.append(float(vs[i - 1]) + (sec[i] as Vector2).distance_to(sec[i - 1]))
	var ns: int = maxi(1, int(ceil(length / 1.4)))
	var rows: Array = []
	for i in range(ns + 1):
		var x: float = length * float(i) / float(ns)
		var bulge: float = 0.025 * sin(x * 1.7 + 0.6) + 0.015 * sin(x * 4.3)
		var lift: float = 0.02 * sin(x * 2.3 + 1.1)
		var row: Array = []
		for q in sec:
			var v: Vector2 = q
			var o: float = v.x + signf(v.x) * bulge * clampf(v.y / h, 0.0, 1.0)
			row.append(Vector3(x, v.y + (lift if v.y > h * 0.9 else 0.0), o))
		rows.append(row)
	var col: Color = HEDGE_GREEN
	for i in range(ns):
		var xa: float = length * float(i) / float(ns)
		var xb: float = length * float(i + 1) / float(ns)
		for j in range(sec.size() - 1):
			var p00: Vector3 = rows[i][j]
			var p01: Vector3 = rows[i][j + 1]
			var p10: Vector3 = rows[i + 1][j]
			var p11: Vector3 = rows[i + 1][j + 1]
			# The section runs up the +z side, over the top and down the other (counter-clockwise): out is (e.y, -e.x).
			var e: Vector2 = (sec[j + 1] as Vector2) - (sec[j] as Vector2)
			var o2: Vector2 = Vector2(e.y, -e.x).normalized()
			var n := Vector3(0, o2.y, o2.x).normalized()
			pk.quad(kit, "hedge", [p00, p10, p11, p01], n, col, [Vector2(xa, vs[j]) * uvk, Vector2(xb, vs[j]) * uvk, Vector2(xb, vs[j + 1]) * uvk,
					Vector2(xa, vs[j + 1]) * uvk])
	# The ends: the section as a flat face (a fan from its middle).
	for e2 in [[0, -1.0], [ns, 1.0]]:
		var row2: Array = rows[e2[0]]
		var cx: float = (row2[0] as Vector3).x
		var c3 := Vector3(cx, h * 0.5, 0.0)
		var nn := Vector3(float(e2[1]), 0, 0)
		for j in range(sec.size()):
			var pa: Vector3 = row2[j]
			var pb: Vector3 = row2[(j + 1) % sec.size()]
			pk.tri(kit, "hedge", c3, pa, pb, nn, nn, nn, col.darkened(0.04), nn, Vector2(c3.z, c3.y) * uvk, Vector2(pa.z, pa.y) * uvk, Vector2(pb.z, pb.y) * uvk)


## A topiary figure on the ground: `kind` "cone", "ball" (a clipped ball on a clear stem), "spiral" (a corkscrew round a
## slender core) or "column", `size` its height (life m). Yew and box ("hedge"), about 0.45 of its height across (a ball
## 1m, its stem the rest), a ring of mulch at its foot.
static func topiary(pk: PropKit, kit: Dictionary, kind := "cone", size := 2.4) -> void:
	var k: float = size / 2.4
	var col: Color = HEDGE_GREEN.darkened(0.12) if kind != "ball" else HEDGE_GREEN.lightened(0.05)
	pk.lathe(kit, "matte", Vector3(0, 0.025, 0), [Vector2(0.7, 0.0), Vector2(0.001, 0.0)], 12, MULCH)
	match kind:
		"ball":
			var r: float = minf(0.5, size * 0.33)
			var cy: float = size - r
			_tube(pk, kit, "gleaf", [Vector3(0, -0.05, 0), Vector3(0, cy - r * 0.5, 0)], 0.045, 6, _gm(TRUNK_BROWN, 1.0))
			var prof: Array = []
			for i in range(9):
				var a: float = -PI * 0.5 + PI * float(i) / 8.0
				prof.append(Vector2(r * cos(a) + 0.001, cy + r * sin(a) * 0.96))
			_lathe(pk, kit, "hedge", Vector3.ZERO, prof, 12, col)
		"spiral":
			_lathe(pk, kit, "hedge", Vector3.ZERO, [Vector2(0.16 * k, -0.05), Vector2(0.14 * k, size * 0.5), Vector2(0.07 * k, size * 0.9),
					Vector2(0.001, size)], 8, col.darkened(0.2))
			var pts: Array = []
			var radii: Array = []
			var n := 44
			for i in range(n + 1):
				var t: float = float(i) / float(n)
				var ang: float = t * TAU * 3.25
				var rr: float = (0.36 * (1.0 - t) + 0.07) * k
				pts.append(Vector3(cos(ang) * rr, (0.16 + (size - 0.32) * t), sin(ang) * rr))
				radii.append((0.22 * (1.0 - t) + 0.06) * k)
			_tube(pk, kit, "hedge", pts, radii, 8, col, true, false, uvk)
		"column":
			_lathe(pk, kit, "hedge", Vector3.ZERO, [Vector2(0.36 * k, -0.05), Vector2(0.39 * k, size * 0.3), Vector2(0.37 * k, size * 0.85),
					Vector2(0.3 * k, size * 0.96), Vector2(0.14 * k, size), Vector2(0.001, size + 0.01)], 12, col)
		_:
			_lathe(pk, kit, "hedge", Vector3.ZERO, [Vector2(0.48 * k, -0.05), Vector2(0.53 * k, 0.14 * k), Vector2(0.47 * k, 0.6 * k),
					Vector2(0.32 * k, 1.35 * k), Vector2(0.16 * k, 1.95 * k), Vector2(0.05 * k, 2.3 * k), Vector2(0.001, size)], 12, col)


# ======================================================================================
#  The terrace: retaining walls, steps
# ======================================================================================

## The battered front face's z at height y (the wall leans back 4cm in a metre from its coping).
static func _tw_face(y: float) -> float:
	return 0.3 + 0.04 * maxf(-0.16 - y, 0.0)


## A retaining wall along the terrace's edge: x from 0 to `length` (life m), its top (the terrace's level) at y = 0, its
## dressed face toward +z falling `h` to the ground below (the footing to h + 1.2), the back dressed too (where the
## ground behind falls away it shows): coursed ashlar battered 4cm a metre, a plinth course, pilasters about every 4.5m,
## weep holes, a moulded coping (y -0.16 to 0, z -0.5 to +0.44), a pier at each end (x 0.05-0.8 and its mirror) rising
## 1.1m over the coping with a cap and a ball, trailing rock plants over the coping. It keeps to x 0..length, z
## -0.56..+0.62 (the piers' caps and the plinth at the foot).
static func terrace_wall(pk: PropKit, kit: Dictionary, length: float, h: float) -> void:
	if length < 2.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 100.0) + int(h * 10.0)
	var yb: float = -h - 1.2
	# The wall seen end on, (z, y), extruded along x: its battered face, the back plumb.
	var wf := Transform3D(Basis(Vector3(0, 0, 1), UP, Vector3(1, 0, 0)), Vector3.ZERO)
	var body := PackedVector2Array([Vector2(-0.42, yb), Vector2(_tw_face(yb), yb), Vector2(_tw_face(-0.16), -0.15), Vector2(-0.42, -0.15)])
	KT._prism(pk, kit, "ashlar", wf, body, 0.0, length, SAND, Vector2(0, 1), true)
	# The plinth course at the foot, 6cm proud, chamfered back.
	var pt: float = -h + 0.38
	var plinth := PackedVector2Array([Vector2(0.0, yb), Vector2(_tw_face(yb) + 0.07, yb), Vector2(_tw_face(pt) + 0.07, pt - 0.06),
			Vector2(_tw_face(pt) + 0.005, pt + 0.02), Vector2(0.0, pt + 0.02)])
	KT._prism(pk, kit, "ashlar", wf, plinth, 0.78, length - 0.78, SAND_DARK, Vector2(0, 1), false)
	# The coping.
	var cop := PackedVector2Array([Vector2(-0.5, -0.17), Vector2(0.4, -0.17), Vector2(0.44, -0.13), Vector2(0.44, -0.05), Vector2(0.4, 0.0),
			Vector2(-0.46, 0.0), Vector2(-0.5, -0.04)])
	KT._prism(pk, kit, "ashlar", wf, cop, 0.78, length - 0.78, SAND_LIGHT, Vector2(0, 1), false)
	# Pilasters between the piers.
	var span: float = length - 1.6
	var np: int = maxi(1, int(round(span / 4.5)))
	for k in range(1, np):
		var xc: float = 0.8 + span * float(k) / float(np)
		var pil := PackedVector2Array([Vector2(0.15, yb), Vector2(_tw_face(yb) + 0.11, yb), Vector2(_tw_face(-0.16) + 0.11, -0.16), Vector2(0.15, -0.16)])
		KT._prism(pk, kit, "ashlar", wf, pil, xc - 0.3, xc + 0.3, SAND.lightened(0.03), Vector2(0, 1), true)
		# A weep hole in the bay before it.
		var xp: float = 0.8 + span * (float(k) - 0.5) / float(np)
		_box(pk, kit, "matte", Vector3(xp, -h + 0.7, _tw_face(-h + 0.7) + 0.005), Basis(), Vector3(0.09, 0.11, 0.03), Color(0.06, 0.05, 0.04))
	var xl: float = 0.8 + span * (float(np) - 0.5) / float(np)
	_box(pk, kit, "matte", Vector3(xl, -h + 0.7, _tw_face(-h + 0.7) + 0.005), Basis(), Vector3(0.09, 0.11, 0.03), Color(0.06, 0.05, 0.04))
	# The piers at both ends: a shaft to 1.1m over the coping, a band, a cap and a ball.
	for x0 in [0.05, length - 0.8]:
		_mblock(pk, kit, "ashlar", Vector3(x0, yb, -0.52), Vector3(x0 + 0.75, 1.08, 0.56), SAND)
		_mblock(pk, kit, "ashlar", Vector3(x0 - 0.02, -0.18, -0.54), Vector3(x0 + 0.77, 0.02, 0.58), SAND_LIGHT, true, true)
		_mblock(pk, kit, "ashlar", Vector3(x0 - 0.045, 1.06, -0.555), Vector3(x0 + 0.795, 1.2, 0.595), SAND_LIGHT, true, true)
		_ball_finial(pk, kit, Vector3(x0 + 0.375, 1.195, 0.02), 0.2, SAND_LIGHT)
	# Rock plants trailing over the coping: aubrieta, campanula, yellow alyssum, candytuft, cascading down the face.
	var cols: Array = [FL_PURPLE, Color(0.58, 0.46, 0.92), Color(0.98, 0.90, 0.45), FL_WHITE, Color(0.72, 0.36, 0.78), Color(0.92, 0.48, 0.66), FL_PURPLE]
	# One in most bays between the pilasters, clear of them.
	var bay: float = span / float(np)
	for k in range(np):
		if rng.randf() > 0.65:
			continue
		var wid: float = minf(rng.randf_range(1.1, 2.0), bay - 1.0)
		if wid < 0.4:
			continue
		var xc2: float = 0.8 + bay * (float(k) + 0.5) + rng.randf_range(-1.0, 1.0) * maxf(bay * 0.5 - 0.4 - wid * 0.5, 0.0)
		var cc: Color = cols[rng.randi_range(0, cols.size() - 1)]
		_wall_cascade(pk, kit, xc2, wid, rng.randf_range(0.3, minf(0.8, h - 0.6)), cc, rng)


## A rock plant spilling over the terrace wall's coping at x = `xc`: a mound on the coping's top that turns over its front
## edge and drapes down the battered face, `wid` across, longest in its middle (`drop`), its lower edge a ragged lobe,
## standing 3-8cm off the stone; garden_flowers kind 13 (a mat of leaves under tiny flowers) in `col`.
static func _wall_cascade(pk: PropKit, kit: Dictionary, xc: float, wid: float, drop: float, col: Color, rng: RandomNumberGenerator) -> void:
	var ncol := 10
	var nrow := 7
	var grid: Array = []
	for i in range(ncol + 1):
		var u: float = float(i) / float(ncol)
		var bell: float = sin(u * PI)
		var dc: float = drop * (0.25 + 0.75 * pow(bell, 0.6)) * rng.randf_range(0.85, 1.12)
		var col_pts: Array = []
		for r in range(nrow + 1):
			var x: float = xc + (u - 0.5) * wid
			var p: Vector3
			if r == 0:
				p = Vector3(0, 0.02 + 0.08 * bell, 0.08)
				x = xc + (u - 0.5) * wid * 0.85
			elif r == 1:
				p = Vector3(0, 0.03 + 0.07 * bell, 0.4)
			elif r == 2:
				p = Vector3(0, -0.06 + 0.02 * bell, 0.5 + 0.03 * bell)
			else:
				var t: float = float(r - 3) / float(nrow - 3)
				var y: float = lerpf(-0.16, -0.16 - dc, t)
				x = xc + (u - 0.5) * wid * (1.0 - 0.12 * t)
				p = Vector3(0, y, _tw_face(y) + 0.03 + 0.05 * bell * (1.0 - t) + 0.03 * _vn2(x * 3.0, y * 3.0, 5))
			col_pts.append(Vector3(x, p.y, p.z))
		grid.append(col_pts)
	var green := Color(0.20, 0.34, 0.12)
	for i in range(ncol):
		var va := 0.0
		for r in range(nrow):
			var p00: Vector3 = grid[i][r]
			var p10: Vector3 = grid[i + 1][r]
			var p01: Vector3 = grid[i][r + 1]
			var p11: Vector3 = grid[i + 1][r + 1]
			var n: Vector3 = (p10 - p00).cross(p01 - p00).normalized()
			if n.z + n.y < 0.0:
				n = -n
			var l: float = p00.distance_to(p01)
			var c: Color = col.lerp(green, clampf(_vn2(p00.x * 2.5, p00.y * 2.5, 9) * 0.9 - 0.45, 0.0, 0.35) + (0.25 if r < 2 else 0.0))
			var fc: Color = _fk(c, 13)
			pk.tri(kit, "gflower", p00, p10, p11, n, n, n, fc, n, Vector2(p00.x, va), Vector2(p10.x, va), Vector2(p11.x, va + l))
			pk.tri(kit, "gflower", p00, p11, p01, n, n, n, fc, n, Vector2(p00.x, va), Vector2(p11.x, va + l), Vector2(p01.x, va + l))
			va += l


## Steps down the terrace's face beside the route: the frame's origin on the terrace's edge (y = 0 its level, z = 0 the
## wall's line), +z down the drop, `width` (life m) across x, falling `h`. A top landing over the wall's coping (z -0.6
## to 0.9, 3cm over it), two flights of risers 15-17cm and treads 34cm with a landing between, a last tread running on
## into the ground at y = -h; cheek walls (x +-(width/2 .. width/2 + 0.42)) down to h + 1.0 carrying balustrades, an urn
## at the foot of each. It stays within x +-(width/2 + 0.5) (the newels' caps).
static func terrace_steps(pk: PropKit, kit: Dictionary, width: float, h: float) -> void:
	var n: int = maxi(2, int(round(h / 0.16)))
	var r: float = h / float(n)
	var g := 0.34
	var n1: int = n / 2
	var land := 1.3
	var hw: float = width * 0.5
	var z_top0 := -0.6
	var za := 0.9
	# Riser i (1..n) at z_i, from -(i-1) r down to -i r; tread i at -i r from z_i to z_(i+1).
	var zs: Array = [za]
	for i in range(1, n):
		zs.append(float(zs[i - 1]) + (land if i == n1 else g))
	var z_end: float = float(zs[n - 1]) + 0.7
	var tread_col: Color = SAND_LIGHT
	var riser_col: Color = SAND.darkened(0.06)
	# The top landing, 3cm over the coping.
	pk.quad(kit, "ashlar", [Vector3(-hw, 0.03, z_top0), Vector3(hw, 0.03, z_top0), Vector3(hw, 0.03, za + 0.03), Vector3(-hw, 0.03, za + 0.03)], UP, tread_col,
			[Vector2(-hw, z_top0) * uvk, Vector2(hw, z_top0) * uvk, Vector2(hw, za) * uvk, Vector2(-hw, za) * uvk])
	_mq(pk, kit, "ashlar", Vector3(0, 0, z_top0), Vector3.LEFT, Vector3.FORWARD, -hw, hw, -0.2, 0.03, riser_col)
	for i in range(1, n + 1):
		var zi: float = zs[i - 1]
		var z_next: float = float(zs[i]) if i < n else z_end
		var y_top: float = 0.03 if i == 1 else -float(i - 1) * r
		var y_t: float = -float(i) * r
		# The riser, then the tread, its nosing 3cm over the next riser.
		var zn: float = z_next + (0.03 if i < n else 0.0)
		_mq(pk, kit, "ashlar", Vector3(0, 0, zi), Vector3.RIGHT, Vector3.BACK, -hw, hw, y_t, y_top, riser_col)
		pk.quad(kit, "ashlar", [Vector3(-hw, y_t, zi), Vector3(hw, y_t, zi), Vector3(hw, y_t, zn), Vector3(-hw, y_t, zn)], UP, tread_col,
				[Vector2(-hw, zi) * uvk, Vector2(hw, zi) * uvk, Vector2(hw, z_next) * uvk, Vector2(-hw, z_next) * uvk])
	# The nosing line, for the cheeks' tops and their balustrades.
	var line: Array = [Vector2(z_top0, 0.03), Vector2(za - 0.15, 0.03)]
	line.append(Vector2(float(zs[n1 - 1]) + 0.1, -float(n1 - 1) * r - r * 0.5))
	line.append(Vector2(float(zs[n1]) - 0.1, -float(n1) * r))
	line.append(Vector2(float(zs[n - 1]) + 0.1, -float(n - 1) * r - r * 0.5))
	line.append(Vector2(z_end, -h))
	var ch := 0.24
	for sx in [1.0, -1.0]:
		var x0: float = sx * hw
		var x1: float = sx * (hw + 0.42)
		var xm: float = (x0 + x1) * 0.5
		var ol := PackedVector2Array()
		ol.append(Vector2(z_top0, -h - 1.0))
		ol.append(Vector2(z_end + 0.25, -h - 1.0))
		ol.append(Vector2(z_end + 0.25, -h + ch))
		for k in range(line.size() - 1, -1, -1):
			var q: Vector2 = line[k]
			ol.append(Vector2(q.x, q.y + ch))
		var cwf := Transform3D(Basis(Vector3(0, 0, 1), UP, Vector3(sx, 0, 0)), Vector3(minf(x0, x1), 0, 0))
		if sx < 0.0:
			cwf = Transform3D(Basis(Vector3(0, 0, 1), UP, Vector3(1, 0, 0)), Vector3(x1, 0, 0))
		KT._prism(pk, kit, "ashlar", cwf, ol, 0.0, 0.42, SAND, Vector2(0, 1), true)
		# The coping along the cheek, then the balustrade on it.
		var pts: Array = []
		for k in range(line.size()):
			var q2: Vector2 = line[k]
			pts.append(Vector3(xm, q2.y + ch + 0.08, q2.x))
		pts.append(Vector3(xm, -h + ch + 0.08, z_end + 0.25))
		for k in range(pts.size() - 1):
			_sloped(pk, kit, "ashlar", (pts[k] as Vector3), (pts[k + 1] as Vector3), 0.5, 0.12, SAND_LIGHT, true, k == 0 or k == pts.size() - 2)
		# The balustrade from the top to the last riser; the newel stands at the foot.
		_balustrade_run(pk, kit, [pts[0], pts[1], pts[2], pts[3], pts[4]], 0.95, SAND_LIGHT, 2.6, 0, 0, 0.44, 0.5)
		# The newel at the foot: a pedestal with an urn on it.
		var nz: float = z_end - 0.05
		var ny: float = -h + ch + 0.08
		_box(pk, kit, "ashlar", Vector3(xm, ny + 0.45, nz), Basis(), Vector3(0.52, 1.0, 0.52), SAND)
		_box(pk, kit, "ashlar", Vector3(xm, ny + 0.99, nz), Basis(), Vector3(0.58, 0.1, 0.58), SAND_LIGHT)
		urn(pk, kit, Vector3(xm, ny + 1.035, nz), 0.6)


# ======================================================================================
#  Stone bridges: the city's moat bridge (style 0) and the lily pond's (style 1)
# ======================================================================================

## The deck's top lies this far (life m) under the road ribbon the generator lays over a bridge.
const BRIDGE_UNDER := 0.05
## A parapet's thickness: from |x| = half (the deck's edge, the road's side) out to the bridge's face.
const BRIDGE_PARAPET := 0.5
## The generator's road ribbon over each style (half its width, life m): the moat bridge's carries the pavements too
## (ROAD_HALF + PAVEMENT, 10.9 game m), the pond bridge's the carriageway (ROAD_HALF, 7.5).
const BRIDGE_RIBBON := [6.8125, 4.6875]
## The city's red sandstone (style 0) and its dressings.
const RED_SAND := Color(0.64, 0.45, 0.37)
const RED_SAND_LIGHT := Color(0.72, 0.53, 0.44)


## The road's height over a bridge `length` long rising `rise` to its middle, at `z` along it (0 the middle), over its
## ends' height: rise * cos^2(pi z / length), 0 past the ends. The generator lays its road ribbon to it
## (`_plan_profile`); the deck's top lies BRIDGE_UNDER under it.
static func bridge_deck_y(z: float, length: float, rise: float) -> float:
	var c: float = cos(clampf(z / length, -0.5, 0.5) * PI)
	return rise * c * c


static func _seg_radius(hs: float, r: float) -> float:
	return (hs * hs + r * r) / (2.0 * maxf(r, 0.01))


## The depth of an arch's ring of voussoirs.
static func _bridge_ring(length: float) -> float:
	return clampf(length * 0.018, 0.34, 0.72)


## The bridge's three segmental arches, [zc, half span, springing y, crown y (the intrados), radius], the middle one first:
## the middle spanning 0.3 of the length, a side arch of 0.2 either side of it on piers of 0.05, abutments of 0.1 at the
## ends. Each crown is as high as the deck lets it: the ring's extrados keeps `cover` under the road all along.
static func _bridge_arches(length: float, rise: float, wy: float, style: int) -> Array:
	var ch: float = length * 0.15
	var tp: float = length * 0.05
	var sh: float = length * 0.1
	var ring: float = _bridge_ring(length)
	var cover: float = 0.36 if style == 0 else 0.26
	var spring: float = wy + (0.4 if style == 0 else 0.3)
	var out: Array = []
	for zh in [[0.0, ch], [-(ch + tp + sh), sh], [ch + tp + sh, sh]]:
		var zc: float = zh[0]
		var hs: float = zh[1]
		var crown: float = bridge_deck_y(zc, length, rise) - cover - ring
		for _it in range(6):
			var r_arc: float = _seg_radius(hs, crown - spring)
			var cy: float = crown - r_arc
			var excess: float = -INF
			for k in range(11):
				var z: float = zc - hs + 2.0 * hs * float(k) / 10.0
				var dz: float = z - zc
				var ext: float = cy + sqrt(maxf((r_arc + ring) * (r_arc + ring) - dz * dz, 0.0))
				excess = maxf(excess, ext - (bridge_deck_y(z, length, rise) - cover))
			crown -= maxf(excess, 0.0)
		crown = maxf(crown, spring + 0.25)
		out.append([zc, hs, spring, crown, _seg_radius(hs, crown - spring)])
	return out


## A band along a bridge: x from x0 to x1, from deck + y0 to deck + y1 (deck = bridge_deck_y), z from z0 to z1 in steps
## under 0.8m; the faces `faces` asks for (1 the +x side, 2 the -x side, 4 the top, 8 the underside, 16 both ends).
static func _hump_band(pk: PropKit, kit: Dictionary, key: String, length: float, rise: float, z0: float, z1: float, x0: float, x1: float,
		y0: float, y1: float, col: Color, faces: int) -> void:
	var n: int = maxi(1, int(ceil((z1 - z0) / 0.8)))
	for k in range(n):
		var za: float = lerpf(z0, z1, float(k) / float(n))
		var zb: float = lerpf(z0, z1, float(k + 1) / float(n))
		var da: float = bridge_deck_y(za, length, rise)
		var db: float = bridge_deck_y(zb, length, rise)
		if faces & 1:
			pk.quad(kit, key, [Vector3(x1, da + y0, za), Vector3(x1, db + y0, zb), Vector3(x1, db + y1, zb), Vector3(x1, da + y1, za)], Vector3.RIGHT, col,
					[Vector2(za, da + y0) * uvk, Vector2(zb, db + y0) * uvk, Vector2(zb, db + y1) * uvk, Vector2(za, da + y1) * uvk])
		if faces & 2:
			pk.quad(kit, key, [Vector3(x0, da + y0, za), Vector3(x0, db + y0, zb), Vector3(x0, db + y1, zb), Vector3(x0, da + y1, za)], Vector3.LEFT, col,
					[Vector2(-za, da + y0) * uvk, Vector2(-zb, db + y0) * uvk, Vector2(-zb, db + y1) * uvk, Vector2(-za, da + y1) * uvk])
		var tn := Vector3(0, zb - za, -(db - da)).normalized()
		if faces & 4:
			pk.quad(kit, key, [Vector3(x0, da + y1, za), Vector3(x1, da + y1, za), Vector3(x1, db + y1, zb), Vector3(x0, db + y1, zb)], tn, col.lightened(0.04),
					[Vector2(x0, za) * uvk, Vector2(x1, za) * uvk, Vector2(x1, zb) * uvk, Vector2(x0, zb) * uvk])
		if faces & 8:
			pk.quad(kit, key, [Vector3(x0, da + y0, za), Vector3(x1, da + y0, za), Vector3(x1, db + y0, zb), Vector3(x0, db + y0, zb)], -tn, col.darkened(0.2),
					[Vector2(x0, za) * uvk, Vector2(x1, za) * uvk, Vector2(x1, zb) * uvk, Vector2(x0, zb) * uvk])
	if faces & 16:
		for e in [[z0, -1.0], [z1, 1.0]]:
			var ze: float = e[0]
			var de: float = bridge_deck_y(ze, length, rise)
			pk.quad(kit, key, [Vector3(x0, de + y0, ze), Vector3(x1, de + y0, ze), Vector3(x1, de + y1, ze), Vector3(x0, de + y1, ze)], Vector3(0, 0, float(e[1])),
					col, [Vector2(x0, de + y0) * uvk, Vector2(x1, de + y0) * uvk, Vector2(x1, de + y1) * uvk, Vector2(x0, de + y1) * uvk])


## A stone arch bridge the route drives over: the road along z (the frame's +z the way of travel) on x = 0, the bridge's
## middle at z = 0 and its ends at z = +-length/2, y = 0 the road's height at the ends; its deck's top BRIDGE_UNDER under
## the road ribbon the generator lays to bridge_deck_y (rise at the middle), from x = -half to half; the parapets from
## |x| = half to half + BRIDGE_PARAPET, about a metre over the road; the water at y = `wy` (negative), the footings to
## wy - 1.6. Three segmental arches (the middle over 0.3 of the length, one each side over 0.2, on piers with cutwaters),
## voussoirs and keystones on both faces, a string course along the road's line, wing walls splaying out at the ends.
## Style 0 is the city's moat bridge in red sandstone, its parapets solid under a coping, pilasters and pedestals over the
## piers, Kronburg's arms on the middle keystones, balls on the end newels; style 1 the garden's pond bridge in pale
## sandstone, balustraded with turned balusters between pedestals, urns on the newels. Nothing stands inside |x| < half
## above the deck (the coping's inner face is flush with half, the parapet's 2cm behind it); the end newels and wings
## reach |x| = half + 0.65 and 2.2m past the ends.
static func stone_bridge(pk: PropKit, kit: Dictionary, length: float, rise: float, half: float, wy: float, style := 0) -> void:
	var L2: float = length * 0.5
	var W: float = half + BRIDGE_PARAPET
	var ring: float = _bridge_ring(length)
	var arches: Array = _bridge_arches(length, rise, wy, style)
	var stone: Color = RED_SAND if style == 0 else SAND
	var trim: Color = RED_SAND_LIGHT if style == 0 else SAND_LIGHT
	var ybot: float = wy - 1.6
	var ch: float = length * 0.15
	var tp: float = length * 0.05
	var arcs: Array = []
	for a in arches:
		arcs.append(KT._arch(float(a[0]), float(a[2]), float(a[1]), "seg", 20 if float(a[1]) > 3.0 else 14, float(a[3]) - float(a[2])))
	# The faces (x = +-W): the spandrels from the footing to the string course's foot, less the arches' openings.
	var ol := PackedVector2Array()
	ol.append(Vector2(-L2, ybot))
	for i in [1, 0, 2]:
		var a2: Array = arches[i]
		ol.append(Vector2(float(a2[0]) - float(a2[1]), ybot))
		for p in (arcs[i] as PackedVector2Array):
			ol.append(p)
		ol.append(Vector2(float(a2[0]) + float(a2[1]), ybot))
	ol.append(Vector2(L2, ybot))
	var nt: int = int(ceil(length / 0.8))
	for k in range(nt + 1):
		var z: float = L2 - length * float(k) / float(nt)
		ol.append(Vector2(z, bridge_deck_y(z, length, rise) - 0.14))
	var tris := Geometry2D.triangulate_polygon(ol)
	if tris.is_empty():
		push_warning("GardenKit.stone_bridge: the face didn't triangulate")
	for sx in [1.0, -1.0]:
		var nf := Vector3(sx, 0, 0)
		for i in range(0, tris.size(), 3):
			var pa: Vector2 = ol[tris[i]]
			var pb: Vector2 = ol[tris[i + 1]]
			var pc: Vector2 = ol[tris[i + 2]]
			pk.tri(kit, "ashlar", Vector3(sx * W, pa.y, pa.x), Vector3(sx * W, pb.y, pb.x), Vector3(sx * W, pc.y, pc.x), nf, nf, nf, stone, nf,
					Vector2(-sx * pa.x, pa.y) * uvk, Vector2(-sx * pb.x, pb.y) * uvk, Vector2(-sx * pc.x, pc.y) * uvk)
	# The ends of the bridge (in the embankments).
	for e in [-1.0, 1.0]:
		_mq(pk, kit, "ashlar", Vector3(0, 0, e * L2), Vector3(-e, 0, 0), Vector3(0, 0, e), -W, W, ybot, -0.14, stone.darkened(0.1))
	# Under the arches: the barrels (the intrados), the piers' and abutments' faces down to the footings, the voussoirs.
	for i in range(3):
		var a3: Array = arches[i]
		var zc: float = a3[0]
		var hs: float = a3[1]
		var spring: float = a3[2]
		var crown: float = a3[3]
		var R: float = a3[4]
		var cy: float = crown - R
		var pts: PackedVector2Array = arcs[i]
		var run := 0.0
		for k in range(pts.size() - 1):
			var p: Vector2 = pts[k]
			var q: Vector2 = pts[k + 1]
			var m: Vector2 = (p + q) * 0.5
			var inward := Vector3(0, cy - m.y, zc - m.x).normalized()
			var l: float = p.distance_to(q)
			pk.quad(kit, "ashlar", [Vector3(-W, p.y, p.x), Vector3(W, p.y, p.x), Vector3(W, q.y, q.x), Vector3(-W, q.y, q.x)], inward, stone.darkened(0.14),
					[Vector2(-W, run) * uvk, Vector2(W, run) * uvk, Vector2(W, run + l) * uvk, Vector2(-W, run + l) * uvk])
			run += l
		for e2 in [-1.0, 1.0]:
			var zf: float = zc + e2 * hs
			_mq(pk, kit, "ashlar", Vector3(0, 0, zf), Vector3(e2, 0, 0), Vector3(0, 0, -e2), -W, W, ybot, spring, stone.darkened(0.08))
		# Voussoirs: an odd number round the arch, alternately 3.5 and 5cm proud, the keystone 8cm and taller.
		var ang0: float = atan2(spring - cy, -hs)
		var ang1: float = atan2(spring - cy, hs)
		var nv: int = int(R * absf(ang0 - ang1) / 0.42)
		if nv % 2 == 0:
			nv += 1
		nv = maxi(nv, 7)
		for sx2 in [1.0, -1.0]:
			for k in range(nv):
				var t0: float = lerpf(ang0, ang1, float(k) / float(nv))
				var t1: float = lerpf(ang0, ang1, float(k + 1) / float(nv))
				var key_stone: bool = k == nv / 2
				var ri: float = R - 0.02
				var ro: float = R + ring + (0.16 if key_stone else (0.05 if k % 2 == 0 else 0.0))
				var d1: float = 0.08 if key_stone else (0.035 if k % 2 == 0 else 0.05)
				var col: Color = trim if k % 2 == 0 else trim.darkened(0.05)
				_voussoir(pk, kit, zc, cy, t0, t1, ri, ro, sx2 * (W - 0.02), sx2 * (W + d1), sx2, col)
			if style == 0 and i == 0:
				# Kronburg's arms on the middle keystone.
				var kv: float = cy + R + ring * 0.55
				KT._arms(pk, kit, KT._wf(Vector3(sx2 * (W + 0.081), 0, zc), Vector3(sx2, 0, 0)), 0.0, kv, ring * 0.7, 0.0)
	# The piers' cutwaters (both faces), pilasters over them on style 0, and pedestals in the parapets.
	for e3 in [-1.0, 1.0]:
		var pc: float = e3 * (ch + tp * 0.5)
		var spring2: float = arches[0][2]
		var ycw: float = spring2 + (0.55 if style == 0 else 0.4)
		for sx3 in [1.0, -1.0]:
			_cutwater(pk, kit, pc, tp, sx3 * W, sx3, ybot, ycw, stone, trim)
			if style == 0:
				var dpc: float = bridge_deck_y(pc, length, rise)
				var x0: float = minf(sx3 * (W - 0.02), sx3 * (W + 0.1))
				var x1: float = maxf(sx3 * (W - 0.02), sx3 * (W + 0.1))
				_mblock(pk, kit, "ashlar", Vector3(x0, ycw + tp * 0.5, pc - tp * 0.36), Vector3(x1, dpc - 0.12, pc + tp * 0.36), stone.lightened(0.03), false)
			_bridge_pedestal(pk, kit, length, rise, pc, half, W, sx3, 1.22 if style == 0 else 1.14, maxf(tp * 0.8, 0.6), trim, style, false)
	# The deck's top under the ribbon; style 1's edge strips between the ribbon and the parapets.
	var rib: float = minf(float(BRIDGE_RIBBON[clampi(style, 0, 1)]), half)
	_hump_band(pk, kit, "ashlar", length, rise, -L2, L2, -half, half, -BRIDGE_UNDER - 0.3, -BRIDGE_UNDER, stone.darkened(0.25), 4)
	if half - rib > 0.02:
		for sx4 in [1.0, -1.0]:
			var a4: float = sx4 * (rib - 0.03)
			var b4: float = sx4 * (half + 0.02)
			_hump_band(pk, kit, "ashlar", length, rise, -L2 + 0.75, L2 - 0.75, minf(a4, b4), maxf(a4, b4), -0.1, -0.02, trim.darkened(0.06), 4)
	# The parapets, the string course, the newels and the wings.
	for sx5 in [1.0, -1.0]:
		var xin: float = sx5 * (half + 0.02)
		var xout: float = sx5 * W
		var xa: float = minf(xin, xout)
		var xb: float = maxf(xin, xout)
		var f_in: int = 2 if sx5 > 0.0 else 1
		var f_out: int = 1 if sx5 > 0.0 else 2
		# The string course: the road's line on the face, 9cm proud. Its ends stop 4cm inside the end newels (ending at
		# the bridge's ends, they lay in the newels' end faces and flickered).
		var sa: float = minf(sx5 * (W - 0.02), sx5 * (W + 0.09))
		var sb: float = maxf(sx5 * (W - 0.02), sx5 * (W + 0.09))
		_hump_band(pk, kit, "ashlar", length, rise, -L2 + 0.04, L2 - 0.04, sa, sb, -0.14, 0.1, trim, f_out | 4 | 8 | 16)
		if style == 0:
			_hump_band(pk, kit, "ashlar", length, rise, -L2 + 0.7, L2 - 0.7, xa, xb, -BRIDGE_UNDER - 0.06, 0.9, stone, f_in | f_out)
			var ca: float = minf(sx5 * half, sx5 * (W + 0.06))
			var cb: float = maxf(sx5 * half, sx5 * (W + 0.06))
			_hump_band(pk, kit, "ashlar", length, rise, -L2 + 0.68, L2 - 0.68, ca, cb, 0.89, 1.03, trim, 1 | 2 | 4 | 8 | 16)
		else:
			_hump_band(pk, kit, "ashlar", length, rise, -L2 + 0.7, L2 - 0.7, xa, xb, -BRIDGE_UNDER - 0.06, 0.3, stone, f_in | f_out | 4)
			var xm: float = sx5 * (half + 0.26)
			var bounds: Array = [-L2 + 0.75, -(ch + tp * 0.5) - 0.3, -(ch + tp * 0.5) + 0.3, (ch + tp * 0.5) - 0.3, (ch + tp * 0.5) + 0.3, L2 - 0.75]
			for r2 in range(3):
				var z0: float = bounds[r2 * 2]
				var z1: float = bounds[r2 * 2 + 1]
				var nr: int = maxi(2, int(ceil((z1 - z0) / 1.5)))
				var bp: Array = []
				for k in range(nr + 1):
					var zz: float = lerpf(z0, z1, float(k) / float(nr))
					bp.append(Vector3(xm, bridge_deck_y(zz, length, rise) + 0.29, zz))
				_balustrade_run(pk, kit, bp, 0.72, SAND_LIGHT, 3.2, 0, 0, 0.44, 0.5, false)
		for e5 in [-1.0, 1.0]:
			# The end newel stops 1.5cm short of the bridge's end, whose face below the road (the end wall) lay in its own.
			_bridge_pedestal(pk, kit, length, rise, e5 * (L2 - 0.39), half, W, sx5, 1.3, 0.75, trim, style, true)
			# The wing wall, splaying out from the newel's outer side into the bank: a footing slab with the sloped wall
			# on it under a coping. The footing stands 1.5cm proud of the wall on both faces and runs 2.5cm past its
			# outer end (so does the coping): the same thickness, their faces shared a plane wherever the wall's foot
			# dips under the footing's top (2cm at the newel, 57cm at the bank), and it flickered.
			var wa := Vector3(sx5 * (W - 0.1), 0, e5 * (L2 - 0.3))
			var wb := Vector3(sx5 * (W + 2.0), 0, e5 * (L2 + 2.2))
			var past: Vector3 = (wb - wa).normalized() * 0.025
			_slab(pk, kit, "ashlar", wa, wb + past, 0.48, ybot, 0.25, stone, true, true)
			_sloped(pk, kit, "ashlar", wa + Vector3(0, 0.95, 0), wb + Vector3(0, 0.4, 0), 0.45, 0.72, stone, false, true)
			_sloped(pk, kit, "ashlar", wa + Vector3(0, 1.05, 0), wb + past + Vector3(0, 0.5, 0), 0.55, 0.12, trim, true, true)


## One voussoir of an arch on a face: the ring between radius ri and ro from angle t0 to t1 about (zc, cy) (in the
## face's (z, y)), from x_in to x_out (its front at x_out, facing `sx`).
static func _voussoir(pk: PropKit, kit: Dictionary, zc: float, cy: float, t0: float, t1: float, ri: float, ro: float, x_in: float, x_out: float, sx: float,
		col: Color) -> void:
	var d0 := Vector2(cos(t0), sin(t0))
	var d1 := Vector2(cos(t1), sin(t1))
	var i0: Vector2 = Vector2(zc, cy) + d0 * ri
	var i1: Vector2 = Vector2(zc, cy) + d1 * ri
	var o0: Vector2 = Vector2(zc, cy) + d0 * ro
	var o1: Vector2 = Vector2(zc, cy) + d1 * ro
	var nf := Vector3(sx, 0, 0)
	pk.quad(kit, "ashlar", [Vector3(x_out, i0.y, i0.x), Vector3(x_out, i1.y, i1.x), Vector3(x_out, o1.y, o1.x), Vector3(x_out, o0.y, o0.x)], nf, col,
			[Vector2(i0.x, i0.y) * uvk, Vector2(i1.x, i1.y) * uvk, Vector2(o1.x, o1.y) * uvk, Vector2(o0.x, o0.y) * uvk])
	var dm: Vector2 = (d0 + d1).normalized()
	pk.quad(kit, "ashlar", [Vector3(x_in, i0.y, i0.x), Vector3(x_in, i1.y, i1.x), Vector3(x_out, i1.y, i1.x), Vector3(x_out, i0.y, i0.x)], Vector3(0, -dm.y, -dm.x),
			col.darkened(0.12))
	pk.quad(kit, "ashlar", [Vector3(x_in, o0.y, o0.x), Vector3(x_in, o1.y, o1.x), Vector3(x_out, o1.y, o1.x), Vector3(x_out, o0.y, o0.x)], Vector3(0, dm.y, dm.x), col)
	var s0 := Vector2(sin(t0), -cos(t0))
	var s1 := Vector2(-sin(t1), cos(t1))
	if s0.dot(d1 - d0) > 0.0:
		s0 = -s0
	if s1.dot(d0 - d1) > 0.0:
		s1 = -s1
	pk.quad(kit, "ashlar", [Vector3(x_in, i0.y, i0.x), Vector3(x_out, i0.y, i0.x), Vector3(x_out, o0.y, o0.x), Vector3(x_in, o0.y, o0.x)], Vector3(0, s0.y, s0.x), col)
	pk.quad(kit, "ashlar", [Vector3(x_in, i1.y, i1.x), Vector3(x_out, i1.y, i1.x), Vector3(x_out, o1.y, o1.x), Vector3(x_in, o1.y, o1.x)], Vector3(0, s1.y, s1.x), col)


## A pier's cutwater on a bridge's face at x = `xf` (facing `sx`): a pointed prism standing out 0.75 of the pier's
## thickness `tp`, from the footing `yb` to `ytop`, under a pyramid cap leaning back onto the face.
static func _cutwater(pk: PropKit, kit: Dictionary, pc: float, tp: float, xf: float, sx: float, yb: float, ytop: float, col: Color, trim: Color) -> void:
	var b0 := Vector3(xf, 0, pc - tp * 0.5)
	var b1 := Vector3(xf, 0, pc + tp * 0.5)
	var tip := Vector3(xf + sx * tp * 0.75, 0, pc)
	var up0 := Vector3(0, yb, 0)
	var up1 := Vector3(0, ytop, 0)
	for s in [[b0, tip], [tip, b1]]:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var n: Vector3 = (b - a).cross(UP).normalized()
		if n.x * sx < 0.0:
			n = -n
		var l: float = a.distance_to(b)
		pk.quad(kit, "ashlar", [a + up0, b + up0, b + up1, a + up1], n, col, [Vector2(0, yb) * uvk, Vector2(l, yb) * uvk, Vector2(l, ytop) * uvk, Vector2(0, ytop) * uvk])
	# The cap: a sloped hood from the cutwater's top back up the face, with a lip 3cm over its sides.
	var lip := 0.03
	var c0: Vector3 = b0 + Vector3(0, ytop - 0.02, -lip)
	var c1: Vector3 = b1 + Vector3(0, ytop - 0.02, lip)
	var ct: Vector3 = tip + Vector3(sx * lip * 1.6, ytop - 0.02, 0)
	var apex := Vector3(xf, ytop + tp * 0.55, pc)
	for s2 in [[c0, ct], [ct, c1]]:
		var a2: Vector3 = s2[0]
		var b2: Vector3 = s2[1]
		var n2: Vector3 = (b2 - a2).cross(apex - a2).normalized()
		if n2.y < 0.0:
			n2 = -n2
		pk.tri(kit, "ashlar", a2, b2, apex, n2, n2, n2, trim, n2, Vector2(a2.z, a2.y) * uvk, Vector2(b2.z, b2.y) * uvk, Vector2(apex.z, apex.y) * uvk)
	pk.tri(kit, "ashlar", c0, ct, c1, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, trim.darkened(0.2), Vector3.DOWN)


## A pedestal in a bridge's parapet at z = `zc` (side `sx`): from 3cm behind the parapet's inner face out to 0.15 past the
## bridge's face, `d` long, `h` over the road, a base, a cap; on the newels (`newel`) a ball (style 0) or an urn (style 1),
## on the piers' a ball (style 1) or nothing.
static func _bridge_pedestal(pk: PropKit, kit: Dictionary, length: float, rise: float, zc: float, half: float, W: float, sx: float, h: float, d: float,
		trim: Color, style: int, newel: bool) -> void:
	var dy: float = bridge_deck_y(zc, length, rise)
	var slope: float = absf(bridge_deck_y(zc + d * 0.5, length, rise) - bridge_deck_y(zc - d * 0.5, length, rise))
	var x0: float = minf(sx * (half + 0.03), sx * (W + 0.15))
	var x1: float = maxf(sx * (half + 0.03), sx * (W + 0.15))
	var y0: float = dy - slope - 0.4
	_mblock(pk, kit, "ashlar", Vector3(x0, y0, zc - d * 0.5), Vector3(x1, dy + h, zc + d * 0.5), trim)
	var c0: float = minf(sx * (half + 0.03), sx * (W + 0.22))
	var c1: float = maxf(sx * (half + 0.03), sx * (W + 0.22))
	_mblock(pk, kit, "ashlar", Vector3(c0, dy + h - 0.01, zc - d * 0.5 - 0.06), Vector3(c1, dy + h + 0.11, zc + d * 0.5 + 0.06), trim.lightened(0.05), true, true)
	var top := Vector3((x0 + x1) * 0.5, dy + h + 0.105, zc)
	if newel:
		if style == 0:
			_ball_finial(pk, kit, top, 0.22, trim)
		else:
			urn(pk, kit, top, 0.6)
	elif style == 1:
		_ball_finial(pk, kit, top, 0.16, trim)


## The bridge's colliders (life metres, its frame): the parapets in pieces along the hump (from |x| = half outward), the
## newels, the wing walls, the piers and their cutwaters in the water.
static func stone_bridge_solids(length: float, rise: float, half: float, wy: float, style := 0) -> Array:
	var out: Array = []
	var L2: float = length * 0.5
	var W: float = half + BRIDGE_PARAPET
	var n: int = maxi(2, int(ceil(length / 2.5)))
	var top: float = 1.04 if style == 0 else 1.02
	for sx in [1.0, -1.0]:
		for k in range(n):
			var za: float = lerpf(-L2, L2, float(k) / float(n))
			var zb: float = lerpf(-L2, L2, float(k + 1) / float(n))
			var da: float = bridge_deck_y(za, length, rise)
			var db: float = bridge_deck_y(zb, length, rise)
			var al := Vector3(0, db - da, zb - za)
			var l: float = al.length()
			al /= l
			var yv := Vector3(0, al.z, -al.y)
			out.append([Transform3D(Basis(Vector3.RIGHT, yv, al), Vector3(sx * (half + W) * 0.5, (da + db) * 0.5 + (top - 0.3) * 0.5, (za + zb) * 0.5)),
					Vector3(W - half, top + 0.3, l + 0.05)])
		for e in [-1.0, 1.0]:
			out.append([Transform3D(Basis(), Vector3(sx * (half + W + 0.15) * 0.5, 0.45, e * (L2 - 0.39))), Vector3(W + 0.15 - half, 1.9, 0.75)])
			var wa := Vector3(sx * (W - 0.1), 0, e * (L2 - 0.3))
			var wb := Vector3(sx * (W + 2.0), 0, e * (L2 + 2.2))
			var wd: Vector3 = (wb - wa).normalized()
			out.append([Transform3D(Basis(wd.cross(UP).normalized(), UP, wd), (wa + wb) * 0.5 + Vector3(0, 0.1, 0)), Vector3(0.5, 2.0, wa.distance_to(wb))])
	var arches: Array = _bridge_arches(length, rise, wy, style)
	var spring: float = arches[0][2]
	var tp: float = length * 0.05
	var ch: float = length * 0.15
	for e2 in [-1.0, 1.0]:
		var y0: float = wy - 1.6
		var y1: float = spring + 0.6
		out.append([Transform3D(Basis(), Vector3(0, (y0 + y1) * 0.5, e2 * (ch + tp * 0.5))), Vector3(2.0 * (W + tp * 0.75), y1 - y0, tp)])
	return out


# ======================================================================================
#  The belvedere on the summit
# ======================================================================================

## The podium's half width (its walls; the coping +0.1), its floor's height.
const BV_HALF := 5.2
const BV_FLOOR := 1.12
## The temple: its columns at the corners of an octagon of this radius, the stylobate's top, the columns' top.
const BV_COL_R := 3.1
const BV_STYLO := 1.66
const BV_ENT := 5.76
const VERDIGRIS := Color(0.36, 0.58, 0.50)
const TELESCOPE_GREEN := Color(0.10, 0.30, 0.20)

## A corner of the temple's octagon (k 0..7) at radius r: KronburgTownKit's plan polygons (x, -z) turned to the kit's.
static func _oct(r: float, k: int) -> Vector3:
	var a: float = PI / 8.0 + TAU * float(k) / 8.0
	return Vector3(cos(a) * r, 0.0, -sin(a) * r)


## An octagonal ring (r_out to r_in at the corners) from y0 to y1, side by side as trapezoids: KronburgTownKit's plan prisms.
static func _oct_ring(pk: PropKit, kit: Dictionary, key: String, r_out: float, r_in: float, y0: float, y1: float, col: Color, bottom := true) -> void:
	var o: PackedVector2Array = KT._ngon(r_out, 8, PI / 8.0)
	var i: PackedVector2Array = KT._ngon(r_in, 8, PI / 8.0)
	for k in range(8):
		var k1: int = (k + 1) % 8
		KT._plan_prism(pk, kit, key, Vector3.ZERO, PackedVector2Array([o[k], o[k1], i[k1], i[k]]), y0, y1, col, bottom)


## A flight of stone steps going down toward +z: `n` risers from `y0` to the ground (y 0), the first at z0, treads `going`
## deep, |x| <= hw; the risers run 0.3 into the ground, the last tread is the ground's.
static func _step_flight(pk: PropKit, kit: Dictionary, hw: float, z0: float, y0: float, n: int, going: float, col: Color) -> void:
	var r: float = y0 / float(n)
	for k in range(n):
		var z: float = z0 + going * float(k)
		var yt: float = y0 - r * float(k)
		var yb: float = y0 - r * float(k + 1)
		_mq(pk, kit, "ashlar", Vector3(0, 0, z), Vector3.RIGHT, Vector3.BACK, -hw, hw, -0.3 if k == n - 1 else yb, yt, col.darkened(0.07))
		if k < n - 1:
			pk.quad(kit, "ashlar", [Vector3(-hw, yb, z - 0.03), Vector3(hw, yb, z - 0.03), Vector3(hw, yb, z + going), Vector3(-hw, yb, z + going)], UP, col,
					[Vector2(-hw, z) * uvk, Vector2(hw, z) * uvk, Vector2(hw, z + going) * uvk, Vector2(-hw, z + going) * uvk])


## The belvedere on the summit, centred on the origin, its front (+z) toward the view and the route. A square podium of
## coursed ashlar (walls +-5.2, coping +-5.3, its floor 1.12 up) with blind panels and a balustrade round its edge, open
## at the front stair (six steps between cheek walls down to the ground at z 7.4, urns on the newels); on it an octagonal
## open temple: three steps, eight Tuscan columns on a radius of 3.1, an entablature with dentils and BELVEDERE on its
## frieze over the front, an attic, a verdigris copper dome with ribs, an open lantern and a gilt finial 11.5m up; a
## painted sky in the dome, stone benches and a compass rose inside, coin telescopes at the front corners. Within x, z
## +-5.42 but the stair (|x| <= 2.31, to z 7.56). About 28k triangles.
static func belvedere(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var H: float = BV_HALF
	var F: float = BV_FLOOR
	# The podium: a base course, the walls, the coping that is its floor.
	_mblock(pk, kit, "ashlar", Vector3(-H - 0.12, -1.5, -H - 0.12), Vector3(H + 0.12, 0.28, H + 0.12), SAND_DARK)
	_mblock(pk, kit, "ashlar", Vector3(-H, 0.2, -H), Vector3(H, 0.98, H), SAND, false)
	_mblock(pk, kit, "ashlar", Vector3(-H - 0.1, 0.96, -H - 0.1), Vector3(H + 0.1, F, H + 0.1), SAND_LIGHT, true, true)
	# Blind panels on the walls (the front's either side of the stair).
	for f in range(4):
		var out: Vector3 = [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)][f]
		var wf: Transform3D = KT._wf(out * H, out)
		var spans: Array = [[-4.4, -2.75], [2.75, 4.4]] if f == 0 else [[-4.4, -1.65], [-1.35, 1.35], [1.65, 4.4]]
		for sp in spans:
			KT._ring_rect(pk, kit, "ashlar", wf, float(sp[0]), 0.4, float(sp[1]), 0.86, 0.08, 0.0, 0.03, SAND_LIGHT)
	# The balustrade round the edge, open over the stair.
	var e: float = H - 0.12
	_balustrade_run(pk, kit, [Vector3(2.05, F, e), Vector3(e, F, e), Vector3(e, F, -e), Vector3(-e, F, -e), Vector3(-e, F, e), Vector3(-2.05, F, e)],
			1.0, SAND_LIGHT, 3.4, 2, 1)
	# The front stair: six steps between cheek walls, a newel with an urn at the foot of each.
	_step_flight(pk, kit, 1.7, H + 0.1, F, 6, 0.36, SAND_LIGHT)
	for sx in [1.0, -1.0]:
		var xm: float = sx * 1.95
		_sloped(pk, kit, "ashlar", Vector3(xm, F + 0.2, H - 0.2), Vector3(xm, 0.5, H + 1.85), 0.5, F + 0.7, SAND, false, true)
		_sloped(pk, kit, "ashlar", Vector3(xm, F + 0.3, H - 0.25), Vector3(xm, 0.6, H + 1.85), 0.6, 0.12, SAND_LIGHT, true, true)
		_mblock(pk, kit, "ashlar", Vector3(xm - 0.3, -0.3, H + 1.75), Vector3(xm + 0.3, 0.95, H + 2.25), SAND)
		_mblock(pk, kit, "ashlar", Vector3(xm - 0.36, 0.94, H + 1.69), Vector3(xm + 0.36, 1.06, H + 2.31), SAND_LIGHT, true, true)
		urn(pk, kit, Vector3(xm, 1.055, H + 2.0), 0.55)
	# The temple's steps and the compass rose on its floor.
	for st in [[4.05, F - 0.02, F + 0.18], [3.75, F + 0.18, F + 0.36], [3.45, F + 0.36, BV_STYLO]]:
		KT._plan_prism(pk, kit, "ashlar", Vector3.ZERO, KT._ngon(float(st[0]), 8, PI / 8.0), float(st[1]), float(st[2]), SAND_LIGHT if st[0] < 3.5 else SAND)
	_compass(pk, kit, Vector3(0, BV_STYLO + 0.012, 0), 1.6)
	# Eight Tuscan columns.
	for k in range(8):
		_tuscan_column(pk, kit, _oct(BV_COL_R, k) + Vector3(0, BV_STYLO, 0), BV_ENT - BV_STYLO)
	# The entablature: architrave, frieze, dentils, cornice; an attic over it.
	_oct_ring(pk, kit, "ashlar", 3.44, 2.78, BV_ENT - 0.01, BV_ENT + 0.38, SAND_LIGHT)
	_oct_ring(pk, kit, "ashlar", 3.5, 2.78, BV_ENT + 0.3, BV_ENT + 0.38, SAND_LIGHT.lightened(0.04), false)
	_oct_ring(pk, kit, "ashlar", 3.36, 2.84, BV_ENT + 0.37, BV_ENT + 0.86, SAND)
	for k in range(8):
		var a: Vector3 = _oct(3.36, k)
		var b: Vector3 = _oct(3.36, (k + 1) % 8)
		var al: Vector3 = (b - a).normalized()
		var on: Vector3 = al.cross(UP).normalized()
		if on.dot((a + b) * 0.5) < 0.0:
			on = -on
		var l: float = a.distance_to(b)
		var nd: int = int(l / 0.21)
		for j in range(nd):
			var p: Vector3 = a.lerp(b, (float(j) + 0.5) / float(nd)) + on * 0.035
			_box(pk, kit, "ashlar", p + Vector3(0, BV_ENT + 0.91, 0), Basis(al, UP, on), Vector3(0.1, 0.1, 0.1), SAND_LIGHT)
	_oct_ring(pk, kit, "ashlar", 3.56, 2.84, BV_ENT + 0.85, BV_ENT + 0.98, SAND_LIGHT)
	_oct_ring(pk, kit, "ashlar", 3.72, 2.84, BV_ENT + 0.97, BV_ENT + 1.12, SAND_LIGHT.lightened(0.05))
	_oct_ring(pk, kit, "ashlar", 3.34, 2.62, BV_ENT + 1.1, BV_ENT + 1.42, SAND)
	# The inscriptions on the frieze: the name over the front, the year at the back.
	var apo: float = 3.36 * cos(PI / 8.0)
	_lbl(labels, "BELVEDERE", Vector3(0, BV_ENT + 0.615, apo + 0.012), Vector3(0, 0, 1), 0.26, Color(0.30, 0.25, 0.18), 2.3)
	_lbl(labels, "ANNO MDCCCXCII", Vector3(0, BV_ENT + 0.615, -apo - 0.012), Vector3(0, 0, -1), 0.2, Color(0.30, 0.25, 0.18), 2.3)
	# The dome: copper gone green, its ribs, the lantern and the finial; inside, a painted sky.
	var dy0: float = BV_ENT + 1.4
	var dprof: Array = []
	var top_r := 0.6
	var th_end: float = acos(top_r / 3.24)
	for k in range(13):
		var th: float = th_end * float(k) / 12.0
		dprof.append(Vector2(3.24 * cos(th), dy0 + 2.5 * sin(th)))
	_lathe(pk, kit, "zinc", Vector3.ZERO, dprof, 32, VERDIGRIS)
	var dome_top: float = dy0 + 2.5 * sin(th_end)
	for k in range(8):
		var a2: float = PI / 8.0 + TAU * float(k) / 8.0
		var d := Vector3(cos(a2), 0, -sin(a2))
		var rib: Array = []
		for j in range(11):
			var th2: float = th_end * float(j) / 10.0
			rib.append(d * (3.24 * cos(th2) + 0.03) + Vector3(0, dy0 + 2.5 * sin(th2) + 0.03, 0))
		_bars(pk, kit, "gbronze", rib, 0.12, 0.07, VERDIGRIS.darkened(0.25), Vector3(-d.z, 0, d.x))
	_lathe(pk, kit, "gbronze", Vector3.ZERO, [Vector2(3.32, dy0 - 0.06), Vector2(3.34, dy0 + 0.02), Vector2(3.2, dy0 + 0.1)], 32, VERDIGRIS.darkened(0.2))
	var iprof: Array = []
	for k in range(9):
		var th3: float = PI * 0.5 * float(k) / 8.0
		iprof.append(Vector2(2.6 * cos(th3) + 0.001, BV_ENT + 1.3 + 2.0 * sin(th3)))
	SW._lathe_uv(pk, kit, "plaster", Vector3.ZERO, iprof, 24, Color(0.60, 0.72, 0.86), true)
	pk.lathe(kit, "gold", Vector3(0, BV_ENT + 3.28, 0), [Vector2(0.001, 0.0), Vector2(0.42, 0.0), Vector2(0.3, -0.05), Vector2(0.001, -0.07)], 12, GILT)
	# The lantern: a ring on the dome, six colonnettes, a cap, a ball and a spike.
	var ly: float = dome_top - 0.05
	_lathe(pk, kit, "ashlar", Vector3(0, ly, 0), [Vector2(0.001, 0.0), Vector2(0.72, 0.0), Vector2(0.72, 0.16), Vector2(0.64, 0.2), Vector2(0.001, 0.2)], 16, SAND_LIGHT)
	for k in range(6):
		var a3: float = TAU * float(k) / 6.0
		var cp := Vector3(cos(a3) * 0.5, 0, sin(a3) * 0.5)
		pk.lathe(kit, "ashlar", cp + Vector3(0, ly + 0.18, 0), [Vector2(0.075, 0.0), Vector2(0.06, 0.08), Vector2(0.05, 0.62), Vector2(0.075, 0.7)], 8, SAND_LIGHT)
	_lathe(pk, kit, "zinc", Vector3(0, ly + 0.86, 0), [Vector2(0.001, 0.0), Vector2(0.7, 0.0), Vector2(0.66, 0.08), Vector2(0.5, 0.26), Vector2(0.28, 0.4),
			Vector2(0.1, 0.48), Vector2(0.001, 0.5)], 16, VERDIGRIS)
	pk.lathe(kit, "gold", Vector3(0, ly + 1.32, 0), [Vector2(0.001, 0.0), Vector2(0.06, 0.02), Vector2(0.06, 0.1), Vector2(0.17, 0.2), Vector2(0.19, 0.3), Vector2(0.15, 0.42),
			Vector2(0.04, 0.5), Vector2(0.03, 0.85), Vector2(0.001, 1.05)], 12, GILT)
	# Stone benches inside, along the back three sides.
	for k in [1, 2, 3]:
		var a4: Vector3 = _oct(2.35, k)
		var b4: Vector3 = _oct(2.35, k + 1)
		var al4: Vector3 = (b4 - a4).normalized()
		var on4: Vector3 = -((a4 + b4) * 0.5).normalized()
		var mid: Vector3 = (a4 + b4) * 0.5 + Vector3(0, BV_STYLO, 0)
		var bs := Basis(al4, UP, on4)
		_box(pk, kit, "ashlar", mid + Vector3(0, 0.42, 0), bs, Vector3(1.55, 0.09, 0.46), SAND_LIGHT)
		for s in [-0.55, 0.55]:
			_box(pk, kit, "ashlar", mid + al4 * s + Vector3(0, 0.19, 0), bs, Vector3(0.14, 0.4, 0.36), SAND)
	# Coin telescopes at the front corners.
	for sx2 in [1.0, -1.0]:
		_telescope(pk, kit, Vector3(sx2 * 4.25, F, 4.25), Vector3(sx2 * 0.35, 0, 1).normalized())


## A Tuscan column standing on `base`, `h` to the top of its abacus: a square plinth, a torus, a shaft with entasis, a
## necking, an echinus and the abacus.
static func _tuscan_column(pk: PropKit, kit: Dictionary, base: Vector3, h: float) -> void:
	_box(pk, kit, "ashlar", base + Vector3(0, 0.06, 0), Basis(), Vector3(0.6, 0.14, 0.6), SAND_LIGHT)
	_lathe(pk, kit, "ashlar", base + Vector3(0, 0.12, 0), [Vector2(0.28, 0.0), Vector2(0.3, 0.05), Vector2(0.28, 0.12), Vector2(0.25, 0.15), Vector2(0.245, 0.19)], 14, SAND_LIGHT)
	var sh: float = h - 0.52
	_lathe(pk, kit, "ashlar", base + Vector3(0, 0.18, 0), [Vector2(0.245, 0.0), Vector2(0.248, sh * 0.33), Vector2(0.232, sh * 0.7), Vector2(0.205, sh)], 14,
			SAND_LIGHT.lightened(0.03))
	var y1: float = 0.18 + sh
	_lathe(pk, kit, "ashlar", base + Vector3(0, y1 - 0.02, 0), [Vector2(0.2, 0.0), Vector2(0.225, 0.02), Vector2(0.225, 0.06), Vector2(0.205, 0.08), Vector2(0.205, 0.12),
			Vector2(0.24, 0.16), Vector2(0.3, 0.24), Vector2(0.31, 0.27)], 14, SAND_LIGHT)
	_box(pk, kit, "ashlar", base + Vector3(0, h - 0.075, 0), Basis(), Vector3(0.66, 0.16, 0.66), SAND_LIGHT.lightened(0.04))


## A compass rose let into a floor at `c`, `r` to its points: an eight-pointed star in two stones and a ring, 1.2cm proud.
static func _compass(pk: PropKit, kit: Dictionary, c: Vector3, r: float) -> void:
	for k in range(16):
		var a: float = TAU * float(k) / 16.0
		var long: bool = k % 2 == 0
		var tip: Vector3 = c + Vector3(cos(a), 0, sin(a)) * (r if long else r * 0.62)
		var s0: Vector3 = c + Vector3(cos(a - TAU / 32.0), 0, sin(a - TAU / 32.0)) * r * 0.2
		var s1: Vector3 = c + Vector3(cos(a + TAU / 32.0), 0, sin(a + TAU / 32.0)) * r * 0.2
		var col: Color = Color(0.36, 0.30, 0.26) if long else Color(0.74, 0.70, 0.62)
		var lift := Vector3(0, 0.0 if long else 0.004, 0)
		pk.tri(kit, "ashlar", c + lift, s0 + lift, tip + lift, UP, UP, UP, col, UP, Vector2.ZERO, Vector2(0.1, 0), Vector2(0, 0.5))
		pk.tri(kit, "ashlar", c + lift, tip + lift, s1 + lift, UP, UP, UP, col.darkened(0.15), UP, Vector2.ZERO, Vector2(0, 0.5), Vector2(0.1, 0))
	pk.lathe(kit, "ashlar", c + Vector3(0, -0.004, 0), [Vector2(r * 1.08, 0.0), Vector2(r * 0.98, 0.0)], 32, Color(0.36, 0.30, 0.26))


## A coin-operated telescope standing at `p`, looking along `look`: a green post on a foot, a yoke, the binocular head
## with its hood and eyepieces, the coin box.
static func _telescope(pk: PropKit, kit: Dictionary, p: Vector3, look: Vector3) -> void:
	var g: Color = TELESCOPE_GREEN
	pk.lathe(kit, "paint", p, [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.18, 0.05), Vector2(0.07, 0.12), Vector2(0.06, 1.0), Vector2(0.001, 1.02)], 10, g)
	var side: Vector3 = look.cross(UP).normalized()
	var fwd: Vector3 = (look - UP * 0.12).normalized()
	var upv: Vector3 = side.cross(fwd).normalized()
	var bs := Basis(side, upv, fwd)
	var hc: Vector3 = p + Vector3(0, 1.18, 0)
	pk.beam(kit, "paint", p + Vector3(0, 0.98, 0) - side * 0.2, p + Vector3(0, 0.98, 0) + side * 0.2, 0.06, 0.06, g, UP)
	for s in [-1.0, 1.0]:
		pk.beam(kit, "paint", p + Vector3(0, 0.96, 0) + side * (s * 0.2), hc + side * (s * 0.2), 0.05, 0.05, g)
	pk.box(kit, "paint", Transform3D(bs, hc), Vector3(0.34, 0.22, 0.42), g)
	for s2 in [-1.0, 1.0]:
		pk.tube(kit, "paint", hc + side * (s2 * 0.085) + fwd * 0.2, hc + side * (s2 * 0.085) + fwd * 0.34, 0.075, 0.085, 10, g.darkened(0.2))
		pk.tube(kit, "steel", hc + side * (s2 * 0.06) - fwd * 0.2, hc + side * (s2 * 0.06) - fwd * 0.3, 0.025, 0.035, 8, IRON_DARK)
	pk.box(kit, "paint", Transform3D(bs, hc - upv * 0.16 - fwd * 0.05), Vector3(0.14, 0.12, 0.16), Color(0.75, 0.62, 0.28))


## The belvedere's colliders: the podium, the stair, the balustrades, the temple's steps, columns and the roof over them,
## the telescopes.
static func belvedere_solids() -> Array:
	var out: Array = []
	var H: float = BV_HALF
	out.append([Transform3D(Basis(), Vector3(0, 0.3, 0)), Vector3(2.0 * H + 0.24, 1.64, 2.0 * H + 0.24)])
	out.append([Transform3D(Basis(), Vector3(0, 0.35, H + 1.2)), Vector3(4.6, 1.3, 2.6)])
	for sx in [1.0, -1.0]:
		out.append([Transform3D(Basis(), Vector3(sx * (H - 0.12), BV_FLOOR + 0.6, 0)), Vector3(0.6, 1.2, 2.0 * H)])
		out.append([Transform3D(Basis(), Vector3(sx * (H + 2.05) * 0.5, BV_FLOOR + 0.6, H - 0.12)), Vector3(H - 2.05 + 0.3, 1.2, 0.6)])
		out.append([Transform3D(Basis(), Vector3(sx * 4.25, BV_FLOOR + 0.65, 4.25)), Vector3(0.5, 1.3, 0.6)])
	out.append([Transform3D(Basis(), Vector3(0, BV_FLOOR + 0.6, -(H - 0.12))), Vector3(2.0 * H, 1.2, 0.6)])
	out.append([Transform3D(Basis(), Vector3(0, (BV_FLOOR + BV_STYLO) * 0.5, 0)), Vector3(7.4, BV_STYLO - BV_FLOOR, 7.4)])
	for k in range(8):
		out.append([Transform3D(Basis(), _oct(BV_COL_R, k) + Vector3(0, (BV_STYLO + BV_ENT) * 0.5, 0)), Vector3(0.6, BV_ENT - BV_STYLO, 0.6)])
	out.append([Transform3D(Basis(), Vector3(0, BV_ENT + 2.3, 0)), Vector3(7.2, 4.6, 7.2)])
	return out


# ======================================================================================
#  The Alpinum: limestone and cushion plants
# ======================================================================================

static var _ico_cache := {}

## A unit icosphere subdivided `level` times: [PackedVector3Array corners, PackedInt32Array faces (three a face, wound
## counter-clockwise seen from outside)].
static func _icosphere(level: int) -> Array:
	if _ico_cache.has(level):
		return _ico_cache[level]
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var verts: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
			Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	for i in range(verts.size()):
		verts[i] = (verts[i] as Vector3).normalized()
	var faces: Array = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6,
			3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	for _l in range(level):
		var mids := {}
		var nf: Array = []
		for f in range(0, faces.size(), 3):
			var a: int = faces[f]
			var b: int = faces[f + 1]
			var c: int = faces[f + 2]
			var ab: int = _ico_mid(verts, mids, a, b)
			var bc: int = _ico_mid(verts, mids, b, c)
			var ca: int = _ico_mid(verts, mids, c, a)
			nf.append_array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca])
		faces = nf
	var out: Array = [PackedVector3Array(verts), PackedInt32Array(faces)]
	_ico_cache[level] = out
	return out


static func _ico_mid(verts: Array, mids: Dictionary, a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if mids.has(key):
		return mids[key]
	verts.append(((verts[a] as Vector3) + (verts[b] as Vector3)).normalized())
	mids[key] = verts.size() - 1
	return verts.size() - 1


## 3D value noise in 0..1.
static func _vn3(p: Vector3) -> float:
	var i := Vector3(floor(p.x), floor(p.y), floor(p.z))
	var f: Vector3 = p - i
	f = f * f * (Vector3(3, 3, 3) - 2.0 * f)
	var h := func(q: Vector3) -> float: return fposmod(sin(q.x * 127.1 + q.y * 311.7 + q.z * 74.7) * 43758.5453, 1.0)
	var x00: float = lerpf(h.call(i), h.call(i + Vector3(1, 0, 0)), f.x)
	var x10: float = lerpf(h.call(i + Vector3(0, 1, 0)), h.call(i + Vector3(1, 1, 0)), f.x)
	var x01: float = lerpf(h.call(i + Vector3(0, 0, 1)), h.call(i + Vector3(1, 0, 1)), f.x)
	var x11: float = lerpf(h.call(i + Vector3(0, 1, 1)), h.call(i + Vector3(1, 1, 1)), f.x)
	return lerpf(lerpf(x00, x10, f.y), lerpf(x01, x11, f.y), f.z)


## PropKit.tri with a normal and a colour per corner (smooth, its COLOR.a varying: the rocks' hollows).
static func _stri(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ca: Color,
		cb: Color, cc: Color, out: Vector3) -> void:
	var st := pk.st(kit, key)
	var wa: Vector3 = pk.xf * a
	var wb: Vector3 = pk.xf * b
	var wc: Vector3 = pk.xf * c
	var wo: Vector3 = pk._nb * out
	var va: Array = [wa, (pk._nb * na).normalized(), ca]
	var vb: Array = [wb, (pk._nb * nb).normalized(), cb]
	var vc: Array = [wc, (pk._nb * nc).normalized(), cc]
	if (wc - wa).cross(wb - wa).dot(wo) < 0.0:
		var tmp: Array = vb
		vb = vc
		vc = tmp
	for v in [va, vb, vc]:
		st.set_color(v[2])
		st.set_normal(v[1])
		st.set_uv(Vector2.ZERO)
		st.add_vertex(v[0])


## A weathered block of limestone (or tuff) centred at `c`, its half extents `s` before `rot`: an icosphere dented by
## noise, cut by a few joint planes (the flat fractured faces) and a bedding plane over and under it, grooved along its
## beds; normals smooth over the weathered rounds and creased where a fracture face meets them (over 38 degrees), COLOR.a
## how open each corner is (garden_rock darkens and moss-fills the folds and the foot).
static func _rock(pk: PropKit, kit: Dictionary, c: Vector3, s: Vector3, rot: Basis, rng: RandomNumberGenerator, tint: Color, level := 2) -> void:
	var ico: Array = _icosphere(level)
	var uv: PackedVector3Array = ico[0]
	var faces: PackedInt32Array = ico[1]
	var ph := Vector3(rng.randf() * 40.0, rng.randf() * 40.0, rng.randf() * 40.0)
	var planes: Array = [[Vector3(rng.randf_range(-0.15, 0.15), 1.0, rng.randf_range(-0.15, 0.15)).normalized(), rng.randf_range(0.42, 0.62)],
			[Vector3(0, -1, 0), rng.randf_range(0.45, 0.6)]]
	var a0: float = rng.randf() * TAU
	var nside: int = rng.randi_range(3, 5)
	for k in range(nside):
		var a: float = a0 + TAU * (float(k) + rng.randf_range(-0.25, 0.25)) / float(nside)
		planes.append([Vector3(cos(a), rng.randf_range(-0.25, 0.25), sin(a)).normalized(), rng.randf_range(0.6, 0.86)])
	var bed_ph: float = rng.randf() * TAU
	var pts := PackedVector3Array()
	var open := PackedFloat32Array()
	for v in uv:
		var rad: float = 1.0 + 0.2 * (_vn3(v * 1.5 + ph) - 0.5) + 0.08 * (_vn3(v * 4.2 + ph * 1.7) - 0.5)
		rad *= 1.0 - 0.06 * pow(maxf(sin(v.y * 8.0 + bed_ph), 0.0), 5.0)
		var p: Vector3 = v * rad
		var cut := 0.0
		for pl in planes:
			var n: Vector3 = pl[0]
			var ex: float = p.dot(n) - float(pl[1])
			if ex > 0.0:
				p -= n * ex
				cut = maxf(cut, ex)
		pts.append(c + rot * Vector3(p.x * s.x, p.y * s.y, p.z * s.z))
		# Hollows dark, fresh fractures open, the foot (under a third of the way up) shaded and mossy.
		var foot: float = smoothstep(-0.55, 0.05, p.y)
		open.append(clampf((0.7 + 2.4 * (rad - 1.0) + 0.5 * cut) * lerpf(0.45, 1.0, foot), 0.22, 1.0))
	var nf: int = faces.size() / 3
	var fn: Array = []
	var vf: Array = []
	vf.resize(pts.size())
	for i in range(pts.size()):
		vf[i] = []
	for f in range(nf):
		var a2: Vector3 = pts[faces[f * 3]]
		var b2: Vector3 = pts[faces[f * 3 + 1]]
		var c2: Vector3 = pts[faces[f * 3 + 2]]
		var n2: Vector3 = (b2 - a2).cross(c2 - a2)
		if n2.dot((a2 + b2 + c2) / 3.0 - c) < 0.0:
			n2 = -n2
		fn.append(n2)
		for j in range(3):
			(vf[faces[f * 3 + j]] as Array).append(f)
	var crease: float = cos(deg_to_rad(38.0))
	for f2 in range(nf):
		var own: Vector3 = (fn[f2] as Vector3).normalized()
		var vn: Array = []
		var vc: Array = []
		for j2 in range(3):
			var vi: int = faces[f2 * 3 + j2]
			var acc := Vector3.ZERO
			for g in (vf[vi] as Array):
				var gn: Vector3 = fn[g]
				if gn.normalized().dot(own) > crease:
					acc += gn
			vn.append(acc.normalized() if acc.length_squared() > 1e-12 else own)
			vc.append(Color(tint.r, tint.g, tint.b, open[vi]))
		_stri(pk, kit, "grock", pts[faces[f2 * 3]], pts[faces[f2 * 3 + 1]], pts[faces[f2 * 3 + 2]], vn[0], vn[1], vn[2], vc[0], vc[1], vc[2], own)


## One of the Alpinum's stones, about `r` (life m) across its half: a weathered limestone or tuff block set into the slope
## with its beds tilted a little (its foot 0.6 r under y = 0, about 0.7 r of it showing), often a thinner slab leaning on
## it and a chip or two at its foot. "grock". About 80-560 triangles (the main block 320 from r 0.85, else 80).
static func rockery_stone(pk: PropKit, kit: Dictionary, r: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var tuff: bool = rng.randf() < 0.25
	var tint: Color = Color(0.64, 0.57, 0.47) if tuff else Color(0.66, 0.65, 0.61).lerp(Color(0.58, 0.58, 0.56), rng.randf())
	var s := Vector3(r * rng.randf_range(1.0, 1.3), r * rng.randf_range(0.5, 0.72), r * rng.randf_range(0.75, 1.0))
	var tilt := Basis(Vector3(1, 0, 0), rng.randf_range(-0.18, 0.18)) * Basis(Vector3(0, 0, 1), rng.randf_range(-0.12, 0.12))
	_rock(pk, kit, Vector3(0, s.y * 0.15, 0), s, tilt, rng, tint, 2 if r >= 0.85 else 1)
	if rng.randf() < 0.55:
		var a: float = rng.randf() * TAU
		var d := Vector3(cos(a), 0, sin(a))
		var s2 := Vector3(r * rng.randf_range(0.55, 0.8), r * rng.randf_range(0.25, 0.38), r * rng.randf_range(0.45, 0.65))
		var lean := Basis(d.cross(UP).normalized(), rng.randf_range(0.2, 0.42)) * Basis(UP, a + PI * 0.5)
		_rock(pk, kit, d * (s.x * 0.85) + Vector3(0, s2.y * 0.2, 0), s2, lean, rng, tint.darkened(0.03), 1)
	for k in range(rng.randi_range(0, 2)):
		var a2: float = rng.randf() * TAU
		var rr: float = r * rng.randf_range(0.14, 0.28)
		_rock(pk, kit, Vector3(cos(a2), 0, sin(a2)) * (s.x * rng.randf_range(1.0, 1.3)) + Vector3(0, rr * 0.1, 0), Vector3(rr * 1.2, rr * 0.7, rr), Basis(UP, rng.randf() * TAU),
				rng, tint, 1)


## A cushion plant on the Alpinum, `r` (life m) across its half: a low, lumpy dome of tiny leaves and flowers
## (garden_flowers kind 13) spilling over in a lobe or two: saxifrage white or pink, gentian blue, aubrieta purple, yellow
## alyssum, sea pink, thyme, or a moss-green cushion with no flowers; a houseleek rosette beside some. Sits on y = 0.
static func alpine_cushion(pk: PropKit, kit: Dictionary, r: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cols: Array = [FL_WHITE, Color(0.96, 0.62, 0.78), Color(0.10, 0.25, 0.85), FL_PURPLE, Color(0.98, 0.86, 0.18), Color(0.92, 0.48, 0.66),
			Color(0.72, 0.52, 0.86)]
	var mossy: bool = rng.randf() < 0.18
	var col: Color = _fk(Color(0.30, 0.46, 0.14), 0) if mossy else _fk(cols[rng.randi_range(0, cols.size() - 1)], 13)
	if not mossy:
		# Its leaves showing round the flowers' dome.
		_lump(pk, kit, "gflower", Vector3(0, 0.02, 0), Vector3(r * 1.12, r * 0.26, r * 0.97), _fk(Color(0.22, 0.38, 0.14), 0), rng, 9, 2, 0.12, true)
	_lump(pk, kit, "gflower", Vector3(0, 0.05, 0), Vector3(r, r * 0.5, r * 0.85), col, rng, 12, 4, 0.14, true)
	for k in range(rng.randi_range(1, 2)):
		var a: float = rng.randf() * TAU
		var rr: float = r * rng.randf_range(0.45, 0.65)
		_lump(pk, kit, "gflower", Vector3(cos(a), 0, sin(a)) * r * 0.75 + Vector3(0, 0.03, 0), Vector3(rr, rr * 0.45, rr * 0.8), col, rng, 9, 3, 0.16, true)
	if rng.randf() < 0.35:
		var a2: float = rng.randf() * TAU
		var hc := Vector3(cos(a2), 0, sin(a2)) * (r * 1.15) + Vector3(0, 0.02, 0)
		var hcol: Color = Color(0.36, 0.52, 0.30).lerp(Color(0.52, 0.30, 0.28), rng.randf() * 0.6)
		for k in range(9):
			var a3: float = TAU * float(k) / 9.0 + rng.randf() * 0.2
			var d := Vector3(cos(a3), 0.45, sin(a3)).normalized()
			_card(pk, kit, hc, d, 0.09, 0.025, 0.0, 0.2, _gm(hcol, 0.2), float(k), 2, 0.0, Vector3.ZERO, "gleaf", 0.15)
		_lump(pk, kit, "gflower", hc + Vector3(0, 0.02, 0), Vector3(0.04, 0.04, 0.04), _fk(hcol.lightened(0.2), 0), rng, 5, 2, 0.1, true)


# ======================================================================================
#  The parterre's fountain
# ======================================================================================

const FOUNTAIN_R := 4.9
const SPRAY := Color(0.86, 0.93, 0.96, 0.42)

## The parterre's fountain, centred on the origin: a round basin (its moulded rim r 4.98, 0.55 up), a ring of sandstone
## flags round it to r 6.1, still water; in the middle a pedestal carrying two tazze the water spills over in strands, a
## jet from the top 2.35m high falling back in ten streams, and eight small jets arching in from the rim. 5.9m to the
## jet's top. Spray is "gspray", water "kwater".
static func parterre_fountain(pk: PropKit, kit: Dictionary) -> void:
	var R: float = FOUNTAIN_R
	# The flags round the basin, 3cm over the ground, in rings of slabs.
	var rings: Array = [R + 0.05, R + 0.62, 6.1]
	for ri in range(rings.size() - 1):
		var r0: float = rings[ri]
		var r1: float = rings[ri + 1]
		var n: int = int(TAU * r1 / 0.9)
		for k in range(n):
			var a0: float = TAU * (float(k) + 0.5 * float(ri)) / float(n)
			var a1: float = TAU * (float(k + 1) + 0.5 * float(ri)) / float(n)
			var g: float = 0.006
			var col: Color = SAND_LIGHT.darkened(0.04 + 0.08 * fposmod(sin(float(k) * 12.9 + float(ri) * 4.1) * 437.5, 1.0))
			var p: Array = [Vector3(cos(a0 + g) * r0, 0.03, sin(a0 + g) * r0), Vector3(cos(a1 - g) * r0, 0.03, sin(a1 - g) * r0),
					Vector3(cos(a1 - g / r1 * r0) * (r1 - 0.012), 0.03, sin(a1 - g / r1 * r0) * (r1 - 0.012)), Vector3(cos(a0 + g / r1 * r0) * (r1 - 0.012), 0.03, sin(a0 + g / r1 * r0) * (r1 - 0.012))]
			pk.quad(kit, "ashlar", p, UP, col, [Vector2(p[0].x, p[0].z) * uvk, Vector2(p[1].x, p[1].z) * uvk, Vector2(p[2].x, p[2].z) * uvk, Vector2(p[3].x, p[3].z) * uvk])
	pk.lathe(kit, "matte", Vector3(0, 0.022, 0), [Vector2(6.1, 0.0), Vector2(R - 0.12, 0.0)], 48, Color(0.30, 0.27, 0.22))
	# The basin's wall and its moulded rim, the inner face down into the water.
	_lathe(pk, kit, "ashlar", Vector3.ZERO, [Vector2(R - 0.05, -0.3), Vector2(R - 0.05, 0.36), Vector2(R + 0.05, 0.4), Vector2(R + 0.08, 0.46), Vector2(R + 0.04, 0.53),
			Vector2(R - 0.06, 0.55), Vector2(R - 0.46, 0.55), Vector2(R - 0.5, 0.5), Vector2(R - 0.5, 0.1)], 48, SAND_LIGHT)
	pk.lathe(kit, "kwater", Vector3(0, 0.34, 0), [Vector2(R - 0.49, 0.0), Vector2(0.001, 0.0)], 48, WHITE)
	# The pedestal on its octagonal base in the water, the lower tazza, the stem, the upper tazza, a pine cone.
	KT._plan_prism(pk, kit, "ashlar", Vector3.ZERO, KT._ngon(1.15, 8, PI / 8.0), 0.0, 0.58, SAND)
	KT._plan_prism(pk, kit, "ashlar", Vector3.ZERO, KT._ngon(1.24, 8, PI / 8.0), 0.56, 0.66, SAND_LIGHT, true)
	_lathe(pk, kit, "ashlar", Vector3(0, 0.66, 0), [Vector2(0.5, 0.0), Vector2(0.42, 0.08), Vector2(0.24, 0.2), Vector2(0.2, 0.5), Vector2(0.26, 0.62),
			Vector2(0.2, 0.7), Vector2(0.16, 0.84), Vector2(0.24, 0.9)], 16, SAND_LIGHT)
	var t1: float = 1.56
	_lathe(pk, kit, "ashlar", Vector3(0, t1, 0), [Vector2(0.24, 0.0), Vector2(0.6, 0.05), Vector2(1.2, 0.18), Vector2(1.66, 0.34), Vector2(1.78, 0.42),
			Vector2(1.78, 0.5), Vector2(1.7, 0.5), Vector2(1.66, 0.44)], 32, SAND_LIGHT)
	pk.lathe(kit, "kwater", Vector3(0, t1 + 0.44, 0), [Vector2(1.67, 0.0), Vector2(0.001, 0.0)], 32, WHITE)
	_lathe(pk, kit, "ashlar", Vector3(0, t1 + 0.4, 0), [Vector2(0.2, 0.0), Vector2(0.15, 0.2), Vector2(0.13, 0.62), Vector2(0.2, 0.72), Vector2(0.14, 0.82),
			Vector2(0.18, 0.88)], 14, SAND_LIGHT)
	var t2: float = t1 + 1.26
	_lathe(pk, kit, "ashlar", Vector3(0, t2, 0), [Vector2(0.18, 0.0), Vector2(0.5, 0.06), Vector2(0.82, 0.2), Vector2(0.9, 0.28), Vector2(0.9, 0.34),
			Vector2(0.84, 0.34), Vector2(0.8, 0.3)], 24, SAND_LIGHT)
	pk.lathe(kit, "kwater", Vector3(0, t2 + 0.3, 0), [Vector2(0.81, 0.0), Vector2(0.001, 0.0)], 24, WHITE)
	_lathe(pk, kit, "ashlar", Vector3(0, t2 + 0.26, 0), [Vector2(0.14, 0.0), Vector2(0.18, 0.12), Vector2(0.15, 0.3), Vector2(0.07, 0.42), Vector2(0.001, 0.48)], 12, SAND)
	# The water: strands spilling off both tazze, the jet and the streams it falls back in, the rim's arching jets.
	_spill(pk, kit, 0.9, t2 + 0.33, 1.0, t1 + 0.44, 20, 0.022)
	_spill(pk, kit, 1.8, t1 + 0.5, 1.92, 0.34, 30, 0.026)
	var jt: float = t2 + 0.7
	pk.lathe(kit, "gspray", Vector3(0, jt, 0), [Vector2(0.06, 0.0), Vector2(0.045, 1.2), Vector2(0.035, 2.1), Vector2(0.001, 2.35)], 8, SPRAY)
	for k2 in range(10):
		var a2: float = TAU * (float(k2) + 0.3) / 10.0
		var d2 := Vector3(cos(a2), 0, sin(a2))
		var fall: Array = []
		for j2 in range(8):
			var s2: float = float(j2) / 7.0
			fall.append(Vector3(0, jt + 2.2, 0) + d2 * (0.72 * s2) + Vector3(0, 0.12 * s2 - (2.2 - 0.3 + 0.12) * s2 * s2, 0))
		_tube(pk, kit, "gspray", fall, 0.018, 4, Color(SPRAY.r, SPRAY.g, SPRAY.b, 0.36))
	for k in range(8):
		var a: float = TAU * (float(k) + 0.5) / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		var p0: Vector3 = d * (R - 0.25) + Vector3(0, 0.56, 0)
		_lathe(pk, kit, "ashlar", d * (R - 0.25) + Vector3(0, 0.54, 0), [Vector2(0.07, 0.0), Vector2(0.05, 0.06), Vector2(0.025, 0.1)], 8, SAND)
		var arc: Array = []
		for j in range(9):
			var s: float = float(j) / 8.0
			arc.append(p0 - d * (2.2 * s) + Vector3(0, 1.35 * s - 1.55 * s * s, 0))
		_tube(pk, kit, "gspray", arc, 0.022, 5, SPRAY)


## Water spilling over a round rim: `n` thin strands from radius r0 at y0, curving out to r1 as they fall to y1, each a
## little wavy and of its own width (r about `w`), translucent "gspray".
static func _spill(pk: PropKit, kit: Dictionary, r0: float, y0: float, r1: float, y1: float, n: int, w: float) -> void:
	for k in range(n):
		var a: float = TAU * (float(k) + 0.37 * sin(float(k) * 2.3)) / float(n)
		var d := Vector3(cos(a), 0, sin(a))
		var pts: Array = []
		for j in range(6):
			var t: float = float(j) / 5.0
			pts.append(d * lerpf(r0, r1, sqrt(t)) + Vector3(0, lerpf(y0, y1, t * t * 0.4 + t * 0.6), 0))
		_tube(pk, kit, "gspray", pts, w * (0.7 + 0.6 * fposmod(float(k) * 0.618, 1.0)), 4, SPRAY)


## The fountain's colliders: its rim (twelve boxes round it) and the pedestal with the lower tazza.
static func parterre_fountain_solids() -> Array:
	var out: Array = []
	for k in range(12):
		var a: float = TAU * float(k) / 12.0
		var d := Vector3(cos(a), 0, sin(a))
		out.append([Transform3D(Basis(Vector3(-d.z, 0, d.x), UP, d), d * (FOUNTAIN_R - 0.23) + Vector3(0, 0.2, 0)), Vector3(2.65, 0.8, 0.6)])
	out.append([Transform3D(Basis(), Vector3(0, 1.0, 0)), Vector3(2.0, 2.0, 2.0)])
	out.append([Transform3D(Basis(), Vector3(0, 2.6, 0)), Vector3(1.0, 1.2, 1.0)])
	return out


# ======================================================================================
#  Garden furniture: lamps, benches, labels, the plan, the sundial, the statue
# ======================================================================================

## A park lamp on the ground at the origin: YardKit's cast-iron post (a fluted foot, collars, a ladder bar) and its
## lantern, 4.15m to the finial.
static func park_lamp(pk: PropKit, kit: Dictionary) -> void:
	YK.lamp_post(pk, kit, Vector3.ZERO, 3.3)


## A park bench on the ground facing +z: slatted seat and back on cast-iron ends, 1.9m long, 0.6m deep (z -0.3 to 0.3).
static func park_bench(pk: PropKit, kit: Dictionary) -> void:
	YK.bench(pk, kit, Vector3(0, 0, 0.3), Vector3(0, 0, 1), 1.9)


## A botanical label facing +z: a black enamel plate (0.4 x 0.2m) tilted back on an iron stake 0.62m up, `text` (the
## plant's Latin name) in white with a thin white rule round it.
static func plant_label(pk: PropKit, kit: Dictionary, labels: Array, text := "Ginkgo biloba") -> void:
	pk.beam(kit, "steel", Vector3(0, -0.2, -0.03), Vector3(0, 0.6, -0.03), 0.025, 0.025, IRON_DARK)
	var tilt: float = deg_to_rad(35.0)
	var n := Vector3(0, sin(tilt), cos(tilt))
	var upv := Vector3(0, cos(tilt), -sin(tilt))
	var c := Vector3(0, 0.66, 0.0)
	var bs := Basis(Vector3.RIGHT, upv, n)
	_box(pk, kit, "enamel", c, bs, Vector3(0.4, 0.2, 0.012), Color(0.04, 0.05, 0.05))
	for y in [-0.085, 0.085]:
		_box(pk, kit, "enamel", c + upv * y + n * 0.0075, bs, Vector3(0.37, 0.006, 0.004), Color(0.9, 0.9, 0.86))
	for x in [-0.185, 0.185]:
		_box(pk, kit, "enamel", c + Vector3(x, 0, 0) + n * 0.0075, bs, Vector3(0.006, 0.17, 0.004), Color(0.9, 0.9, 0.86))
	_lbl(labels, text, c + n * 0.012, n, 0.045, Color(0.95, 0.95, 0.9), 0.34)


## The garden's plan by the gate, facing +z: a green enamel board (2.2 x 1.5m) in a gilt frame on two cast-iron posts
## under a little slate roof; `lines` [title, then the ways] on its left half, a plan of the garden on its right (beds,
## the Palmenhaus, the pond, the paths in colour).
static func garden_sign(pk: PropKit, kit: Dictionary, labels: Array, lines := ["BOTANISCHER GARTEN"]) -> void:
	var w := 2.2
	var hb := 1.5
	var y0 := 0.9
	for sx in [1.0, -1.0]:
		pk.lathe(kit, "steel", Vector3(sx * 1.2, 0, 0), [Vector2(0.001, -0.3), Vector2(0.11, -0.3), Vector2(0.11, 0.08), Vector2(0.07, 0.16), Vector2(0.06, 2.62),
				Vector2(0.09, 2.66), Vector2(0.001, 2.7)], 8, IRON_DARK)
	_box(pk, kit, "enamel", Vector3(0, y0 + hb * 0.5, 0), Basis(), Vector3(w, hb, 0.05), ENAMEL_GREEN)
	for y in [y0 - 0.02, y0 + hb + 0.02]:
		_box(pk, kit, "gold", Vector3(0, y, 0), Basis(), Vector3(w + 0.08, 0.05, 0.08), GILT)
	for x in [-w * 0.5 - 0.02, w * 0.5 + 0.02]:
		_box(pk, kit, "gold", Vector3(x, y0 + hb * 0.5, 0), Basis(), Vector3(0.05, hb + 0.08, 0.08), GILT)
	_box(pk, kit, "gold", Vector3(0, y0 + hb - 0.3, 0.03), Basis(), Vector3(w - 0.12, 0.02, 0.012), GILT)
	# The roof: two slate slopes over the board, a ridge, a gilt ball at each end.
	var ry := y0 + hb + 0.5
	for sz in [1.0, -1.0]:
		YK.roof(pk, kit, "kslate", Vector3(-1.35, y0 + hb + 0.14, sz * 0.45), Vector3(1.35, y0 + hb + 0.14, sz * 0.45), Vector3(1.35, ry, 0), Vector3(-1.35, ry, 0),
				Color(0.30, 0.31, 0.33), Vector3(0, 0.36, sz * 0.45).normalized())
	pk.beam(kit, "steel", Vector3(-1.4, ry + 0.02, 0), Vector3(1.4, ry + 0.02, 0), 0.08, 0.06, IRON_DARK, Vector3(0, 0, 1))
	for sx2 in [1.0, -1.0]:
		KT._blob(pk, kit, "gold", Vector3(sx2 * 1.42, ry + 0.08, 0), Vector3(0.06, 0.06, 0.06), GILT)
		pk.beam(kit, "steel", Vector3(sx2 * 1.2, ry - 0.3, 0), Vector3(sx2 * 1.2, ry, 0), 0.06, 0.06, IRON_DARK)
	# The plan: lawns, beds, the glasshouse, the pond, the paths, a red dot (you are here).
	var pz := 0.045
	var plan: Array = [[0.1, 1.0, 0.95, 0.6, Color(0.30, 0.52, 0.22)], [0.18, 0.92, 0.38, 0.72, Color(0.85, 0.30, 0.25)], [0.45, 0.93, 0.62, 0.7, Color(0.95, 0.85, 0.3)],
			[0.7, 0.85, 0.88, 0.62, Color(0.85, 0.88, 0.9)], [0.12, 0.55, 0.95, 0.12, Color(0.32, 0.55, 0.24)], [0.3, 0.45, 0.62, 0.22, Color(0.25, 0.45, 0.75)],
			[0.7, 0.5, 0.92, 0.15, Color(0.6, 0.58, 0.52)]]
	# Each layer of the plan 6mm over the one under it (lawns, then what stands on them, then each path): one plane fought.
	for i in range(plan.size()):
		var p: Array = plan[i]
		var xa: float = lerpf(0.05, w * 0.5 - 0.06, float(p[0]))
		var xb: float = lerpf(0.05, w * 0.5 - 0.06, float(p[2]))
		var ya: float = y0 + 0.08 + (hb - 0.45) * float(p[3])
		var yb: float = y0 + 0.08 + (hb - 0.45) * float(p[1])
		var zl: float = pz + (0.0 if i == 0 or i == 4 else 0.006)
		pk.quad(kit, "enamel", [Vector3(xa, ya, zl), Vector3(xb, ya, zl), Vector3(xb, yb, zl), Vector3(xa, yb, zl)], Vector3(0, 0, 1), p[4])
	var paths: Array = [[0.08, 0.58, 0.96, 0.6], [0.5, 0.1, 0.52, 1.0]]
	for j in range(paths.size()):
		var q: Array = paths[j]
		var xa2: float = lerpf(0.05, w * 0.5 - 0.06, float(q[0]))
		var xb2: float = lerpf(0.05, w * 0.5 - 0.06, float(q[2]))
		var ya2: float = y0 + 0.08 + (hb - 0.45) * float(q[1])
		var yb2: float = y0 + 0.08 + (hb - 0.45) * float(q[3])
		var zp: float = pz + 0.012 + 0.006 * float(j)
		pk.quad(kit, "enamel", [Vector3(xa2, ya2, zp), Vector3(xb2, ya2, zp), Vector3(xb2, yb2, zp), Vector3(xa2, yb2, zp)], Vector3(0, 0, 1), Color(0.92, 0.88, 0.76))
	KT._blob(pk, kit, "enamel", Vector3(0.2, y0 + 0.2, pz + 0.03), Vector3(0.04, 0.04, 0.01), Color(0.9, 0.08, 0.06))
	# The words.
	if lines.size() > 0:
		_lbl(labels, String(lines[0]), Vector3(0, y0 + hb - 0.15, 0.03), Vector3(0, 0, 1), 0.13, Color(0.95, 0.92, 0.8), w - 0.2)
	for i in range(1, lines.size()):
		_lbl(labels, String(lines[i]), Vector3(-w * 0.25, y0 + hb - 0.42 - 0.2 * float(i - 1), 0.03), Vector3(0, 0, 1), 0.09, Color(0.95, 0.92, 0.8), w * 0.46)


## A sundial on the ground: a turned sandstone pedestal (a square base, a baluster, a square cap) 0.92m high carrying a
## bronze dial with its hour lines and numerals' ticks, and a gnomon pointing north (-z).
static func sundial(pk: PropKit, kit: Dictionary) -> void:
	_box(pk, kit, "ashlar", Vector3(0, -0.05, 0), Basis(), Vector3(0.62, 0.2, 0.62), SAND)
	_box(pk, kit, "ashlar", Vector3(0, 0.1, 0), Basis(), Vector3(0.5, 0.12, 0.5), SAND_LIGHT)
	_baluster(pk, kit, Vector3(0, 0.15, 0), 0.65, SAND_LIGHT)
	_lathe(pk, kit, "ashlar", Vector3(0, 0.15, 0), [Vector2(0.001, -0.01), Vector2(0.14, -0.01), Vector2(0.14, 0.04), Vector2(0.001, 0.04)], 8, SAND_LIGHT)
	_box(pk, kit, "ashlar", Vector3(0, 0.84, 0), Basis(), Vector3(0.5, 0.1, 0.5), SAND_LIGHT)
	var b: Color = BRONZE
	pk.lathe(kit, "gbronze", Vector3(0, 0.89, 0), [Vector2(0.001, 0.0), Vector2(0.21, 0.0), Vector2(0.22, 0.015), Vector2(0.001, 0.02)], 24, b)
	for k in range(13):
		var a: float = PI * (float(k) / 12.0)
		var d := Vector3(cos(a), 0, -sin(a))
		_box(pk, kit, "gbronze", Vector3(0, 0.912, 0) + d * 0.15, Basis(Vector3(-d.z, 0, d.x), UP, d), Vector3(0.006, 0.006, 0.08 if k % 3 == 0 else 0.05), b.lightened(0.25))
	var lat: float = deg_to_rad(51.5)
	var g0 := Vector3(0, 0.91, 0.12)
	var g1 := Vector3(0, 0.91 + 0.24 * tan(lat), -0.12)
	pk.quad(kit, "gbronze", [g0, Vector3(0, 0.91, -0.12), g1, g0 + Vector3(0, 0.001, 0)], Vector3.RIGHT, b.lightened(0.1))
	pk.quad(kit, "gbronze", [g0 + Vector3(0, 0.001, 0), g1, Vector3(0, 0.91, -0.12), g0], Vector3.LEFT, b.lightened(0.1))
	pk.beam(kit, "gbronze", g0 + Vector3(0, 0.002, 0), g1, 0.012, 0.012, b)


## A statue of Flora on the pond's shore, facing +z: a sandstone pedestal (a plinth, a die with a wreath, a cornice) 1.25m
## high and on it the goddess in patinated bronze, 1.75m: a draped gown falling in folds, a mantle over one shoulder, her
## right arm raising a wreath, her left holding a basket of flowers at her hip.
static func statue(pk: PropKit, kit: Dictionary) -> void:
	_mblock(pk, kit, "ashlar", Vector3(-0.62, -0.5, -0.62), Vector3(0.62, 0.22, 0.62), SAND_DARK)
	_mblock(pk, kit, "ashlar", Vector3(-0.5, 0.2, -0.5), Vector3(0.5, 0.32, 0.5), SAND_LIGHT, true, true)
	_mblock(pk, kit, "ashlar", Vector3(-0.42, 0.3, -0.42), Vector3(0.42, 1.08, 0.42), SAND)
	_mblock(pk, kit, "ashlar", Vector3(-0.5, 1.06, -0.5), Vector3(0.5, 1.18, 0.5), SAND_LIGHT, true, true)
	_mblock(pk, kit, "ashlar", Vector3(-0.44, 1.16, -0.44), Vector3(0.44, 1.25, 0.44), SAND_LIGHT)
	# A wreath in relief on the die's front.
	var wr: Array = []
	for k in range(17):
		var a: float = TAU * float(k) / 16.0
		wr.append(Vector3(cos(a) * 0.17, 0.7 + sin(a) * 0.17, 0.44))
	_tube(pk, kit, "ashlar", wr, 0.028, 5, SAND_LIGHT, false, false, uvk)
	var b: Color = BRONZE
	var base := Vector3(0, 1.25, 0)
	# The gown: a lathe falling from the waist to a hem spread on the plinth (oval, wider than deep), its folds as ridges.
	var oval := Basis.from_scale(Vector3(1.18, 1.0, 0.86))
	pk.lathe(kit, "gbronze", base, [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.31, 0.04), Vector2(0.27, 0.3), Vector2(0.21, 0.62), Vector2(0.16, 0.86),
			Vector2(0.13, 0.96)], 16, b, false, oval)
	for k in range(10):
		var a2: float = TAU * float(k) / 10.0 + 0.2
		var d := Vector3(cos(a2) * 1.18, 0, sin(a2) * 0.86)
		pk.tube(kit, "gbronze", base + d * 0.3 + Vector3(0, 0.03, 0), base + d * 0.15 + Vector3(0, 0.88, 0), 0.03, 0.012, 5, b.darkened(0.05), false)
	# The body: waist, bust, sloping shoulders, neck; the head with her hair in a knot.
	pk.lathe(kit, "gbronze", base + Vector3(0, 0.94, 0), [Vector2(0.13, 0.0), Vector2(0.142, 0.12), Vector2(0.158, 0.24), Vector2(0.16, 0.3), Vector2(0.148, 0.37),
			Vector2(0.168, 0.42), Vector2(0.12, 0.49), Vector2(0.05, 0.53), Vector2(0.045, 0.62), Vector2(0.001, 0.63)], 14, b, false, oval)
	var head: Vector3 = base + Vector3(0, 1.66, 0.01)
	var hp: Array = []
	for k in range(9):
		var th: float = -PI * 0.5 + PI * float(k) / 8.0
		hp.append(Vector2(0.088 * cos(th) + 0.001, 0.112 * sin(th)))
	pk.lathe(kit, "gbronze", head, hp, 12, b)
	KT._blob(pk, kit, "gbronze", head + Vector3(0, 0.05, -0.09), Vector3(0.06, 0.05, 0.05), b.darkened(0.1))
	KT._blob(pk, kit, "gbronze", head + Vector3(0, -0.01, 0.085), Vector3(0.018, 0.025, 0.022), b)
	# The mantle over her left shoulder, falling down her back.
	pk.tube(kit, "gbronze", base + Vector3(-0.15, 1.38, -0.02), base + Vector3(-0.22, 0.5, -0.13), 0.08, 0.14, 8, b.darkened(0.08))
	# Her right arm raising a wreath of leaves, her left holding the basket.
	var sr: Vector3 = base + Vector3(0.19, 1.36, 0)
	var er: Vector3 = sr + Vector3(0.12, 0.22, 0.08)
	var hr: Vector3 = er + Vector3(-0.04, 0.26, 0.06)
	_tube(pk, kit, "gbronze", [sr, er, hr], [0.05, 0.04, 0.034], 7, b, true)
	var wc: Vector3 = hr + Vector3(0, 0.13, 0.02)
	var ring: Array = []
	for k in range(13):
		var a3: float = TAU * float(k) / 12.0
		ring.append(wc + Vector3(cos(a3) * 0.13, sin(a3) * 0.13, 0))
	_tube(pk, kit, "gbronze", ring, 0.02, 5, b.lightened(0.05))
	for k in range(14):
		var a5: float = TAU * float(k) / 14.0
		var lp: Vector3 = wc + Vector3(cos(a5) * 0.13, sin(a5) * 0.13, 0)
		KT._blob(pk, kit, "gbronze", lp + Vector3(cos(a5 + 0.6) * 0.02, sin(a5 + 0.6) * 0.02, 0.012 * (1.0 if k % 2 == 0 else -1.0)), Vector3(0.035, 0.035, 0.018),
				b.lightened(0.08))
	var sl: Vector3 = base + Vector3(-0.19, 1.36, 0)
	var el: Vector3 = sl + Vector3(-0.06, -0.26, 0.04)
	var hl: Vector3 = el + Vector3(0.06, -0.06, 0.22)
	_tube(pk, kit, "gbronze", [sl, el, hl], [0.05, 0.042, 0.035], 7, b, true)
	var bk: Vector3 = hl + Vector3(-0.08, -0.08, 0.06)
	pk.lathe(kit, "gbronze", bk, [Vector2(0.001, 0.0), Vector2(0.08, 0.0), Vector2(0.16, 0.12), Vector2(0.15, 0.13)], 12, b.darkened(0.05))
	for k in range(7):
		var a4: float = TAU * float(k) / 7.0
		KT._blob(pk, kit, "gbronze", bk + Vector3(cos(a4) * 0.08, 0.15, sin(a4) * 0.08), Vector3(0.05, 0.045, 0.05), b.lightened(0.08))


# ======================================================================================
#  The small glasshouse (Kakteenhaus) beside the Palmenhaus
# ======================================================================================

const GH_HALF := 3.25   # the glass walls at |x|
const GH_LEN := 6.0     # its gables at |z|
const GH_SILL := 0.78   # the brick dwarf wall's coping
const GH_EAVE := 2.55
const GH_RIDGE := 4.25
const TERRACOTTA := Color(0.66, 0.34, 0.22)
const CACTUS := Color(0.26, 0.42, 0.22)

## A small span-roofed glasshouse, the cactus house, centred on the origin, its door in the front gable (+z): a brick dwarf
## wall under a sandstone coping, glass walls (|x| 3.25) to the eaves at 2.55 and a glass roof to the ridge at 4.25,
## white-painted iron posts, rafters, gutters, a ridge with cresting and finials, two vents propped open each side, a
## glazed door under a name board; inside, a brick path between slatted staging carrying cacti and succulents in clay
## pots; a water butt and a stack of pots by the door. Within x +-3.6, z -6.1..6.6. About 6k triangles.
static func greenhouse_small(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var X: float = GH_HALF
	var Z: float = GH_LEN
	var brick := Color(0.56, 0.28, 0.20)
	# The dwarf wall (the door's gap in the front) and its coping.
	for sx in [1.0, -1.0]:
		_mblock(pk, kit, "kbrick", Vector3(sx * (X - 0.15), -0.6, -Z), Vector3(sx * (X + 0.15), GH_SILL - 0.06, Z), brick)
		_mblock(pk, kit, "ashlar", Vector3(sx * (X - 0.19), GH_SILL - 0.08, -Z - 0.04), Vector3(sx * (X + 0.19), GH_SILL, Z + 0.04), SAND_LIGHT, true, true)
		_mblock(pk, kit, "kbrick", Vector3(sx * 0.58, -0.6, Z - 0.3), Vector3(sx * (X - 0.15), GH_SILL - 0.06, Z), brick)
		_mblock(pk, kit, "ashlar", Vector3(sx * 0.58, GH_SILL - 0.08, Z - 0.34), Vector3(sx * (X - 0.19), GH_SILL, Z + 0.04), SAND_LIGHT, true, true)
	_mblock(pk, kit, "kbrick", Vector3(-X + 0.15, -0.6, -Z), Vector3(X - 0.15, GH_SILL - 0.06, -Z + 0.3), brick)
	_mblock(pk, kit, "ashlar", Vector3(-X + 0.19, GH_SILL - 0.08, -Z - 0.04), Vector3(X - 0.19, GH_SILL, -Z + 0.34), SAND_LIGHT, true, true)
	# A step up to the door.
	_mblock(pk, kit, "ashlar", Vector3(-0.75, -0.3, Z - 0.3), Vector3(0.75, 0.12, Z + 0.45), SAND_LIGHT)
	# The floor: a brick path down the middle, soil under the staging.
	pk.quad(kit, "kbrick", [Vector3(-0.58, 0.13, -Z + 0.3), Vector3(0.58, 0.13, -Z + 0.3), Vector3(0.58, 0.13, Z - 0.3), Vector3(-0.58, 0.13, Z - 0.3)], UP,
			brick.lightened(0.08), [Vector2(-0.58, -Z) * uvk, Vector2(0.58, -Z) * uvk, Vector2(0.58, Z) * uvk, Vector2(-0.58, Z) * uvk])
	for sx2 in [1.0, -1.0]:
		var a: float = minf(sx2 * 0.58, sx2 * (X - 0.15))
		var b: float = maxf(sx2 * 0.58, sx2 * (X - 0.15))
		pk.quad(kit, "matte", [Vector3(a, 0.1, -Z + 0.3), Vector3(b, 0.1, -Z + 0.3), Vector3(b, 0.1, Z - 0.3), Vector3(a, 0.1, Z - 0.3)], UP, Color(0.36, 0.31, 0.25))
	# Glass: the side walls, the roof's slopes, the gables (the front's round the door).
	for sx3 in [1.0, -1.0]:
		var n := Vector3(sx3, 0, 0)
		pk.quad(kit, "gglass", [Vector3(sx3 * X, GH_SILL, -Z), Vector3(sx3 * X, GH_SILL, Z), Vector3(sx3 * X, GH_EAVE, Z), Vector3(sx3 * X, GH_EAVE, -Z)], n, WHITE,
				[Vector2(-Z, GH_SILL), Vector2(Z, GH_SILL), Vector2(Z, GH_EAVE), Vector2(-Z, GH_EAVE)])
		var rn := Vector3(sx3 * (GH_RIDGE - GH_EAVE), X, 0).normalized()
		var sl: float = Vector2(X, GH_RIDGE - GH_EAVE).length()
		pk.quad(kit, "gglass", [Vector3(sx3 * (X + 0.04), GH_EAVE + 0.02, -Z - 0.06), Vector3(sx3 * (X + 0.04), GH_EAVE + 0.02, Z + 0.06), Vector3(0, GH_RIDGE + 0.02, Z + 0.06),
				Vector3(0, GH_RIDGE + 0.02, -Z - 0.06)], rn, WHITE, [Vector2(-Z, 0), Vector2(Z, 0), Vector2(Z, sl), Vector2(-Z, sl)])
	var gable := PackedVector2Array([Vector2(-X, GH_SILL), Vector2(X, GH_SILL), Vector2(X, GH_EAVE), Vector2(0, GH_RIDGE), Vector2(-X, GH_EAVE)])
	_glass_poly(pk, kit, gable, -Z, Vector3(0, 0, -1))
	var door := PackedVector2Array([Vector2(-0.58, -1.0), Vector2(0.58, -1.0), Vector2(0.58, 2.32), Vector2(-0.58, 2.32)])
	var pieces: Array = Geometry2D.clip_polygons(gable, door)
	for poly in pieces:
		if Geometry2D.is_polygon_clockwise(poly) and pieces.size() > 1:
			continue
		_glass_poly(pk, kit, poly, Z, Vector3(0, 0, 1))
	# The ironwork: posts, rafters, plates, transoms, the gables' frames, gutters, the ridge and its cresting.
	var c: Color = IRON_WHITE
	var nb := 10
	for k in range(nb + 1):
		var z: float = lerpf(-Z, Z, float(k) / float(nb))
		for sx4 in [1.0, -1.0]:
			pk.beam(kit, "paint", Vector3(sx4 * X, GH_SILL - 0.01, z), Vector3(sx4 * X, GH_EAVE + 0.02, z), 0.07, 0.08, c)
			pk.beam(kit, "paint", Vector3(sx4 * (X - 0.03), GH_EAVE - 0.03, z), Vector3(0, GH_RIDGE - 0.05, z), 0.06, 0.07, c, Vector3(0, 0, 1))
	for sx5 in [1.0, -1.0]:
		pk.beam(kit, "paint", Vector3(sx5 * X, GH_EAVE, -Z - 0.05), Vector3(sx5 * X, GH_EAVE, Z + 0.05), 0.09, 0.1, c)
		pk.beam(kit, "paint", Vector3(sx5 * (X + 0.015), 1.68, -Z), Vector3(sx5 * (X + 0.015), 1.68, Z), 0.05, 0.05, c)
		_box(pk, kit, "paint", Vector3(sx5 * (X + 0.13), GH_EAVE - 0.03, 0), Basis(), Vector3(0.16, 0.12, 2.0 * Z + 0.2), c.darkened(0.05))
		for sz in [1.0, -1.0]:
			pk.beam(kit, "paint", Vector3(sx5 * (X + 0.05), GH_EAVE + 0.04, sz * (Z + 0.06)), Vector3(0, GH_RIDGE + 0.06, sz * (Z + 0.06)), 0.1, 0.07, c, Vector3(0, 0, 1))
			pk.beam(kit, "paint", Vector3(sx5 * 1.6, GH_SILL, sz * (Z + 0.01)), Vector3(sx5 * 1.6, GH_EAVE + (GH_RIDGE - GH_EAVE) * (1.0 - 1.6 / X), sz * (Z + 0.01)), 0.06, 0.06, c)
		# Two roof vents a side, propped open on their stays.
		for zv in [-2.4, 2.4]:
			var hinge := Vector3(sx5 * 0.12, GH_RIDGE - 0.06, zv)
			var down: Vector3 = Vector3(sx5 * X, GH_EAVE - GH_RIDGE, 0).normalized()
			var opened: Vector3 = down.rotated(Vector3(0, 0, 1), sx5 * 0.42)
			var p0: Vector3 = hinge + Vector3(0, 0.04, 0)
			var p1: Vector3 = p0 + opened * 0.9
			var vn: Vector3 = Vector3(0, 0, 1).cross(opened).normalized()
			if vn.y < 0.0:
				vn = -vn
			pk.quad(kit, "gglass", [p0 + Vector3(0, 0, -0.6), p0 + Vector3(0, 0, 0.6), p1 + Vector3(0, 0, 0.6), p1 + Vector3(0, 0, -0.6)], vn, WHITE,
					[Vector2(-0.6, 0), Vector2(0.6, 0), Vector2(0.6, 0.9), Vector2(-0.6, 0.9)])
			for e in [-0.6, 0.6]:
				pk.beam(kit, "paint", p0 + Vector3(0, 0.01, e), p1 + Vector3(0, 0.01, e), 0.04, 0.04, c)
			pk.beam(kit, "paint", p1 + Vector3(0, 0.01, -0.62), p1 + Vector3(0, 0.01, 0.62), 0.04, 0.04, c, UP)
			pk.beam(kit, "paint", p1, p0 + down * 0.9, 0.015, 0.015, c)
	pk.beam(kit, "paint", Vector3(0, GH_RIDGE + 0.05, -Z - 0.1), Vector3(0, GH_RIDGE + 0.05, Z + 0.1), 0.12, 0.1, c)
	var ncr: int = int(2.0 * Z / 0.4)
	for k in range(ncr + 1):
		var zc: float = lerpf(-Z, Z, float(k) / float(ncr))
		var tall: bool = k % 2 == 0
		pk.beam(kit, "paint", Vector3(0, GH_RIDGE + 0.09, zc), Vector3(0, GH_RIDGE + (0.32 if tall else 0.22), zc), 0.025, 0.025, c)
		KT._blob(pk, kit, "paint", Vector3(0, GH_RIDGE + (0.36 if tall else 0.25), zc), Vector3(0.035, 0.06 if tall else 0.04, 0.035), c)
	pk.beam(kit, "paint", Vector3(0, GH_RIDGE + 0.2, -Z), Vector3(0, GH_RIDGE + 0.2, Z), 0.02, 0.02, c)
	for sz2 in [1.0, -1.0]:
		pk.lathe(kit, "paint", Vector3(0, GH_RIDGE + 0.08, sz2 * (Z + 0.1)), [Vector2(0.001, 0.0), Vector2(0.06, 0.0), Vector2(0.09, 0.12), Vector2(0.05, 0.22),
				Vector2(0.03, 0.5), Vector2(0.06, 0.56), Vector2(0.001, 0.75)], 8, c)
	# The door: its frame, a glazed leaf with a kick panel, a brass handle; the name board over it.
	for sx6 in [1.0, -1.0]:
		pk.beam(kit, "paint", Vector3(sx6 * 0.62, 0.1, Z + 0.02), Vector3(sx6 * 0.62, 2.36, Z + 0.02), 0.09, 0.09, c)
	pk.beam(kit, "paint", Vector3(-0.68, 2.36, Z + 0.02), Vector3(0.68, 2.36, Z + 0.02), 0.09, 0.1, c, UP)
	_box(pk, kit, "paint", Vector3(0, 0.45, Z), Basis(), Vector3(1.1, 0.62, 0.05), c)
	pk.quad(kit, "gglass", [Vector3(-0.52, 0.76, Z), Vector3(0.52, 0.76, Z), Vector3(0.52, 2.28, Z), Vector3(-0.52, 2.28, Z)], Vector3(0, 0, 1), WHITE,
			[Vector2(-0.52, 0.76), Vector2(0.52, 0.76), Vector2(0.52, 2.28), Vector2(-0.52, 2.28)])
	for y in [0.78, 1.52, 2.26]:
		pk.beam(kit, "paint", Vector3(-0.55, y, Z + 0.01), Vector3(0.55, y, Z + 0.01), 0.05, 0.05, c, UP)
	for x in [-0.53, 0.53]:
		pk.beam(kit, "paint", Vector3(x, 0.14, Z + 0.01), Vector3(x, 2.3, Z + 0.01), 0.05, 0.05, c)
	_box(pk, kit, "gold", Vector3(0.4, 1.12, Z + 0.06), Basis(), Vector3(0.03, 0.14, 0.04), Color(0.8, 0.64, 0.3))
	_box(pk, kit, "enamel", Vector3(0, 2.64, Z + 0.06), Basis(), Vector3(1.6, 0.3, 0.04), ENAMEL_GREEN)
	_box(pk, kit, "gold", Vector3(0, 2.64, Z + 0.075), Basis(), Vector3(1.66, 0.36, 0.01), GILT)
	_box(pk, kit, "enamel", Vector3(0, 2.64, Z + 0.083), Basis(), Vector3(1.6, 0.3, 0.01), ENAMEL_GREEN)
	_lbl(labels, "KAKTEENHAUS", Vector3(0, 2.64, Z + 0.095), Vector3(0, 0, 1), 0.15, GILT, 1.45)
	# The staging down both sides: slatted tops on iron legs, pots of cacti and succulents on them.
	for sx7 in [1.0, -1.0]:
		var xs0: float = sx7 * 0.85
		var xs1: float = sx7 * (X - 0.3)
		var xm: float = (xs0 + xs1) * 0.5
		var wid: float = absf(xs1 - xs0)
		for k in range(5):
			var x: float = lerpf(minf(xs0, xs1), maxf(xs0, xs1), (float(k) + 0.5) / 5.0)
			_box(pk, kit, "timber", Vector3(x, 0.86, 0), Basis(), Vector3(wid / 5.0 - 0.03, 0.035, 2.0 * Z - 1.0), Color(0.56, 0.42, 0.28))
		for zl in [-Z + 0.7, -1.7, 1.7, Z - 0.7]:
			for xl in [xs0, xs1]:
				pk.beam(kit, "paint", Vector3(xl - sx7 * 0.04, 0.1, zl), Vector3(xl - sx7 * 0.04, 0.85, zl), 0.04, 0.04, IRON_DARK)
			pk.beam(kit, "paint", Vector3(xs0, 0.83, zl), Vector3(xs1, 0.83, zl), 0.04, 0.04, IRON_DARK, UP)
		var npots: int = 12
		for k2 in range(npots):
			var z2: float = lerpf(-Z + 0.9, Z - 0.9, (float(k2) + rng.randf_range(0.2, 0.8)) / float(npots))
			var x2: float = xm + rng.randf_range(-wid * 0.3, wid * 0.3)
			_cactus_pot(pk, kit, Vector3(x2, 0.88, z2), rng)
	# A tall agave and a column cactus at the back end, a water butt and pots by the door.
	_cactus_pot(pk, kit, Vector3(1.6, 0.13, -Z + 0.8), rng, 2.2)
	strap_clump(pk, kit, Vector3(-1.6, 0.13, -Z + 0.9), 1.3, rng, Color(0.36, 0.48, 0.42), false, 12)
	pk.lathe(kit, "timber", Vector3(1.4, 0.0, Z + 0.6), [Vector2(0.001, 0.0), Vector2(0.34, 0.0), Vector2(0.4, 0.45), Vector2(0.34, 0.9), Vector2(0.001, 0.9)], 14,
			Color(0.42, 0.30, 0.20))
	for y2 in [0.12, 0.78]:
		pk.lathe(kit, "steel", Vector3(1.4, y2, Z + 0.6), [Vector2(0.37, 0.0), Vector2(0.38, 0.03), Vector2(0.37, 0.06)], 14, IRON_DARK)
	pk.lathe(kit, "kwater", Vector3(1.4, 0.86, Z + 0.6), [Vector2(0.33, 0.0), Vector2(0.001, 0.0)], 14, WHITE)
	for k3 in range(4):
		pk.lathe(kit, "matte", Vector3(-1.3, 0.13 * float(k3), Z + 0.55), [Vector2(0.001, 0.0), Vector2(0.11, 0.0), Vector2(0.16, 0.15), Vector2(0.14, 0.17)], 10,
				TERRACOTTA)


## A clay pot on `base` with a cactus or a succulent in it (`big` scales the plant: 1 for the staging's): a column cactus
## with arms, a barrel, a prickly-pear's pads, or an aloe's rosette.
static func _cactus_pot(pk: PropKit, kit: Dictionary, base: Vector3, rng: RandomNumberGenerator, big := 1.0) -> void:
	var pr: float = 0.11 * sqrt(big)
	pk.lathe(kit, "matte", base, [Vector2(0.001, 0.0), Vector2(pr * 0.75, 0.0), Vector2(pr, pr * 1.2), Vector2(pr * 1.12, pr * 1.25), Vector2(pr * 1.12, pr * 1.42),
			Vector2(pr * 0.95, pr * 1.42)], 10, TERRACOTTA.darkened(rng.randf() * 0.15))
	var top: Vector3 = base + Vector3(0, pr * 1.3, 0)
	pk.lathe(kit, "matte", top, [Vector2(pr * 0.96, 0.0), Vector2(0.001, 0.0)], 10, SOIL)
	var g: Color = CACTUS.lerp(Color(0.40, 0.52, 0.36), rng.randf() * 0.6)
	match rng.randi_range(0, 3):
		0:
			var h: float = rng.randf_range(0.25, 0.5) * big
			var r: float = pr * 0.45
			pk.lathe(kit, "gleaf", top, [Vector2(r, 0.0), Vector2(r, h * 0.9), Vector2(r * 0.6, h * 0.98), Vector2(0.001, h)], 8, _gm(g, 1.0))
			if big > 1.5 or rng.randf() < 0.5:
				for s in [-1.0, 1.0]:
					var y0: float = h * rng.randf_range(0.3, 0.55)
					var arm: Array = [top + Vector3(0, y0, 0), top + Vector3(s * r * 2.2, y0 + r * 0.4, 0), top + Vector3(s * r * 2.4, y0 + h * 0.4, 0)]
					_tube(pk, kit, "gleaf", arm, r * 0.7, 6, _gm(g, 1.0), true)
		1:
			var r2: float = pr * rng.randf_range(0.6, 0.85) * big
			var prof: Array = []
			for k in range(6):
				var th: float = PI * 0.5 * float(k) / 5.0
				prof.append(Vector2(r2 * cos(th) + 0.001, r2 * 1.1 * sin(th)))
			pk.lathe(kit, "gleaf", top, prof, 12, _gm(g.lightened(0.05), 1.0))
			KT._blob(pk, kit, "enamel", top + Vector3(0, r2 * 1.1, 0), Vector3(0.025, 0.02, 0.025), Color(0.95, 0.35, 0.55))
		2:
			for k2 in range(3):
				var a: float = rng.randf() * TAU
				var d := Vector3(cos(a), 0, sin(a))
				var pad: Vector3 = top + Vector3(0, 0.06 + 0.07 * float(k2), 0) + d * 0.03 * float(k2)
				var pr3: Vector3 = Vector3(0.065, 0.08, 0.022) if k2 % 2 == 0 else Vector3(0.022, 0.08, 0.065)
				_lump(pk, kit, "gleaf", pad + Vector3(0, 0.07 * big, 0), pr3 * big, _gm(g, 1.0), rng, 7, 4, 0.05, false)
		_:
			for k3 in range(8):
				var a2: float = TAU * float(k3) / 8.0 + rng.randf() * 0.3
				_card(pk, kit, top + Vector3(0, 0.01, 0), Vector3(cos(a2), 0.7, sin(a2)).normalized(), 0.2 * big, 0.03 * big, 0.04 * big, 0.3,
						_gm(Color(0.40, 0.52, 0.40), 0.2), float(k3), 2, 0.0, Vector3.ZERO, "gleaf", 0.1)


## The glasshouse's colliders: its dwarf walls and glass as four walls, the roof over them.
static func greenhouse_small_solids() -> Array:
	return [[Transform3D(Basis(), Vector3(GH_HALF, 1.3, 0)), Vector3(0.4, 2.6, 2.0 * GH_LEN)], [Transform3D(Basis(), Vector3(-GH_HALF, 1.3, 0)), Vector3(0.4, 2.6, 2.0 * GH_LEN)],
			[Transform3D(Basis(), Vector3(0, 1.6, -GH_LEN)), Vector3(2.0 * GH_HALF, 3.2, 0.4)], [Transform3D(Basis(), Vector3(0, 1.6, GH_LEN)), Vector3(2.0 * GH_HALF, 3.2, 0.4)],
			[Transform3D(Basis(), Vector3(0, 3.4, 0)), Vector3(2.0 * GH_HALF, 1.7, 2.0 * GH_LEN)]]
