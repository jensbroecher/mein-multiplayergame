extends "res://YardKit.gd"
## The Miyoshino GP's shared kit base (the four stages' generators: Senbon Sakura Pass, Yoshino Rapids, Monzenmachi,
## Yamabushi Trail). Every Miyoshino kit (MiyoshinoTownKit, MiyoshinoPropKit, MiyoshinoRiverKit) extends this one, so
## they share one set of materials and one palette: a prop of one kit standing beside another's is the same vermilion,
## the same roof tile, the same paper.
##
## Built at life size through YardKit's machinery (the hut shaders take UVs in world metres: `uvk` is the caller's
## scale) and grown by the generators' PROP_SCALE (1.6). `new_kit(scale)`, set the frame, call builders,
## `commit(pk, kit)`. A builder's frame: y up from the ground (0), its front toward +z, footings down to FOOT.
##
## Material keys (besides YardKit's "plaster", "tile", "stone", "concrete", "slate", "timber", "lapboards", "battens",
## "painted", "iron" and CampKit's "steel", "wood", "glass", "paint", "matte", "metal", "gloss"):
##   "kawara"     grey Japanese pan tiles (hut_masonry style 5, the barrel tile, tinted by the vertex colour: KAWARA)
##   "hiwada"     cypress-bark / thatch roofing (hut_thatch, dark and aged): temple halls, tea houses, mountain huts
##   "shikkui"    white lime plaster (hut_masonry style 4): kura walls, temple walls
##   "tsuchi"     earthen wall plaster (hut_masonry style 1, tinted ochre by the vertex colour)
##   "ishi"       dressed granite (hut_masonry style 10, tint it grey): steps, lantern stones, plinths, torii of stone
##   "sugi"       weathered cedar boards (hut_wood style 1), "hinoki" squared timber (hut_wood style 2, little weathering)
##   "urushi"     lacquer paint, glossy (vertex colour): vermilion torii, railings, temple timbers (VERMILION, BLACK_LAC)
##   "gold"       gilt metal, "pane" opaque glossy glass, "cloth" two-sided matte cloth (noren, banners: single faces),
##   "leaf"       two-sided matte vertex colour (shrubs, bamboo leaves, straw), "rope" matte straw rope
##   "washi"      paper lit from inside (lanterns, shoji screens, andon): by day a plain matte paper, at dusk
##                (`night` true before the first new_kit) lamp_glow.gdshader, the vertex colour times `glow_energy`
##   "neon"       always self-lit (vending machines' fronts, signs' lamps): lamp_glow at 1.6
## CampKit's "lamp" gives off no light: use "washi" or "neon" for anything that should glow.
##
## Faces never share a plane: trim stands 2.5cm (TP) proud of what carries it, panes 2cm, labels' boards 3cm; parts that
## meet are cut to each other. Roofs and eaves have undersides. Godot's front faces wind clockwise: PropKit.tri winds
## each triangle for the `out` it is given.

const YardKitBase = preload("res://YardKit.gd")
const LampGlow = preload("res://LampGlow.gd")

const MMASONRY := {"kawara": 5, "shikkui": 4, "tsuchi": 1, "ishi": 10}
const MWOOD := {"sugi": 1, "hinoki": 2}
const MTANGENTS := ["tile", "iron", "concrete", "zinc", "slate", "kawara", "hiwada"]
static var _mmats := {}
## Set both before the first new_kit() of a run: the dusk stage's lanterns and paper screens glow.
static var night := false
static var glow_energy := 2.6

const FOOT := -3.0
const TP := 0.025

const VERMILION := Color(0.78, 0.16, 0.08)
const VERMILION_OLD := Color(0.62, 0.20, 0.12)
const BLACK_LAC := Color(0.05, 0.05, 0.055)
const KAWARA := Color(0.36, 0.38, 0.41)
const KAWARA_OLD := Color(0.30, 0.31, 0.32)
const HIWADA := Color(0.30, 0.22, 0.16)
const SHIKKUI := Color(0.95, 0.94, 0.90)
const TSUCHI := Color(0.80, 0.68, 0.50)
const GRANITE := Color(0.62, 0.62, 0.60)
const GRANITE_MOSSY := Color(0.50, 0.55, 0.46)
const CEDAR := Color(0.42, 0.29, 0.20)
const CEDAR_DARK := Color(0.23, 0.16, 0.12)
const HINOKI := Color(0.78, 0.63, 0.42)
const BAMBOO := Color(0.50, 0.60, 0.30)
const BAMBOO_DRY := Color(0.74, 0.66, 0.42)
const STRAW := Color(0.78, 0.68, 0.42)
const PAPER := Color(0.97, 0.93, 0.82)
const PAPER_WARM := Color(1.0, 0.80, 0.50)
const PAPER_RED := Color(0.92, 0.20, 0.12)
const PAPER_PINK := Color(1.0, 0.66, 0.72)
const INDIGO := Color(0.13, 0.18, 0.36)
const NOREN := [Color(0.13, 0.18, 0.36), Color(0.55, 0.14, 0.12), Color(0.86, 0.82, 0.70), Color(0.20, 0.34, 0.26), Color(0.42, 0.24, 0.40)]
const GOLD := Color(0.92, 0.74, 0.28)
const BRONZE := Color(0.30, 0.36, 0.30)
const MOSS := Color(0.34, 0.46, 0.20)


static func make_material(key: String) -> Material:
	if MMASONRY.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://hut_masonry.gdshader")
		m.set_shader_parameter("style", MMASONRY[key])
		if key == "kawara":
			# Grey pan tiles: none of the barrel tile's buff clay.
			m.set_shader_parameter("tile_buff", 0.0)
		return m
	if MWOOD.has(key):
		var w := ShaderMaterial.new()
		w.shader = load("res://hut_wood.gdshader")
		w.set_shader_parameter("style", MWOOD[key])
		w.set_shader_parameter("weathering", 0.55 if key == "sugi" else 0.18)
		return w
	match key:
		"hiwada":
			var t := ShaderMaterial.new()
			t.shader = load("res://hut_thatch.gdshader")
			t.set_shader_parameter("straw_new", Color(0.36, 0.27, 0.19))
			t.set_shader_parameter("straw_old", Color(0.17, 0.13, 0.10))
			t.set_shader_parameter("age", 0.7)
			return t
		"urushi":
			var u := StandardMaterial3D.new()
			u.vertex_color_use_as_albedo = true
			u.vertex_color_is_srgb = true
			u.roughness = 0.34
			u.metallic_specular = 0.55
			return u
		"gold":
			var au := StandardMaterial3D.new()
			au.vertex_color_use_as_albedo = true
			au.vertex_color_is_srgb = true
			au.metallic = 1.0
			au.roughness = 0.3
			return au
		"pane":
			var g := StandardMaterial3D.new()
			g.vertex_color_use_as_albedo = true
			g.vertex_color_is_srgb = true
			g.metallic = 0.15
			g.roughness = 0.1
			g.metallic_specular = 0.6
			return g
		"cloth", "leaf":
			var c := StandardMaterial3D.new()
			c.vertex_color_use_as_albedo = true
			c.vertex_color_is_srgb = true
			c.roughness = 0.92
			c.cull_mode = BaseMaterial3D.CULL_DISABLED
			return c
		"rope":
			var r := StandardMaterial3D.new()
			r.vertex_color_use_as_albedo = true
			r.vertex_color_is_srgb = true
			r.roughness = 0.96
			return r
		"washi":
			if night:
				return LampGlow.material(glow_energy)
			var p := StandardMaterial3D.new()
			p.vertex_color_use_as_albedo = true
			p.vertex_color_is_srgb = true
			p.roughness = 0.9
			# Paper passes the daylight behind it on: never quite dark in the shade.
			p.emission_enabled = true
			p.emission = Color(0.16, 0.15, 0.13)
			return p
		"neon":
			return LampGlow.material(1.6 if night else 1.0)
	return YardKitBase.make_material(key)


static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mmats.has(k):
			_mmats[k] = make_material(k)
		return _mmats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	return pk


## Commits a kit with tangents on the surfaces whose shaders read a normal map, each surface named after its key.
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in MTANGENTS:
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
