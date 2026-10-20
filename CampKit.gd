extends RefCounted
## Camp and race-meeting props at life size, built through a PropKit: motorhomes, touring caravans, a
## pop-top campervan, an overland SUV, dome, tunnel and ridge tents, gazebos, folding tables, camp
## chairs, a barbecue, cool boxes, crowd barriers and cones. Shared by regenerate_lakeside.gd (the
## fans' camp on the hill) and regenerate_bloombay_dunes.gd (the camps behind the beach), so both
## levels get the same models.
##
## Each builder lays its prop out in its own axes (y up) and emits it through the PropKit's current
## frame: the caller places, turns and scales it (PROP_SCALE) with `PropKit.set_frame`. Vehicles are
## built along x and turned so the nose points to -z; `vehicle()` returns (length, height, width).
## Tents and furniture sit on y = 0. `make_material` makes the material for each kit key, so every
## generator shades the camp the same way (they save and share the instances themselves).

const PropKit = preload("res://PropKit.gd")

const WHITE := Color(0.93, 0.93, 0.91)
const GALV := Color(0.72, 0.74, 0.76)
const GLASS := Color(0.08, 0.13, 0.20, 0.88)
const TYRE := Color(0.07, 0.07, 0.08)
const RUB_TRIM := Color(0.10, 0.11, 0.12)
const CHASSIS_DARK := Color(0.05, 0.05, 0.06)
const CHAIR_COLS := [Color(0.80, 0.12, 0.10), Color(0.14, 0.32, 0.70), Color(0.85, 0.45, 0.12), Color(0.12, 0.40, 0.25), Color(0.15, 0.15, 0.16)]

## Ground footprints at life size, measured off the built meshes (awnings included, since they
## stand out where people sit): Vector4(x0, x1, z0, z1) in the prop's own frame, nose toward -z. The
## `stowed` forms are the variants with the awning rolled in (motorhome 2, caravan 1).
const FOOT := {
	"motorhome": Vector4(-1.32, 3.15, -3.76, 3.97),
	"motorhome_stowed": Vector4(-1.32, 1.41, -3.76, 3.97),
	"caravan": Vector4(-1.17, 3.11, -4.09, 2.84),
	"caravan_stowed": Vector4(-1.17, 1.55, -4.09, 2.84),
	"van": Vector4(-1.24, 1.24, -3.07, 3.16),
	"suv": Vector4(-1.15, 1.15, -2.49, 2.56),
	"dome": Vector4(-1.70, 1.70, -2.27, 1.80),
	"tunnel": Vector4(-1.64, 1.64, -2.69, 2.06),
	"ridge": Vector4(-1.70, 1.70, -2.15, 2.15),
	"gazebo": Vector4(-1.65, 1.65, -1.64, 1.64),
}

var _kit: PropKit


func _init(kit: PropKit) -> void:
	_kit = kit


## Camp layouts in terrace coordinates (metres; x along the terrace, z across it, +z toward the track,
## so vehicles nose toward +z). Each item is [kind, x, z, yaw offset, colour, variant or second colour]:
##   motorhome / caravan / van / suv   colour, variant (0 awning out, 1 out, 2 stowed; the caravan 1 stowed)
##   dome / ridge / tunnel             fly colour, inner or accent colour
##   gazebo                            canopy colour (with its table and three chairs)
##   bbq, cooler                       (the cooler: body colour)
## `half` is the half size of the level pad the layout wants (x, z). Footprints are spaced at least
## CAMP_GAP apart (build_layout reports any that aren't) and keep inside the pad.
const CAMP_GAP := 1.5
const LAYOUT_MAIN := {
	"half": Vector2(17.0, 13.0),
	"items": [
		["motorhome", -11.6, -6.3, -0.03, WHITE, 0],
		["caravan", -1.9, -6.0, 0.02, Color(0.96, 0.95, 0.90), 0],
		["motorhome", 7.2, -6.3, 0.03, Color(0.95, 0.93, 0.87), 1],
		["suv", 13.8, -5.6, 0.08, Color(0.16, 0.34, 0.70), 0],
		["van", -15.0, 7.5, -0.03, Color(0.94, 0.95, 0.93), 0],
		["gazebo", -8.16, 7.5, -0.02, Color(0.10, 0.28, 0.66)],
		["dome", -0.61, 7.5, -0.03, Color(0.14, 0.46, 0.78), Color(0.92, 0.72, 0.18)],
		["ridge", 7.0, 7.5, 0.02, Color(0.18, 0.52, 0.30), Color(0.86, 0.82, 0.72)],
		["tunnel", 14.53, 7.5, -0.02, Color(0.90, 0.50, 0.12), Color(0.24, 0.27, 0.30)],
		["bbq", -8.2, 11.9, 0.0],
		["cooler", -6.5, 11.7, 0.4, Color(0.10, 0.30, 0.70)],
	],
}
const LAYOUT_PAIR := {
	"half": Vector2(9.0, 8.0),
	"items": [
		["caravan", -6.0, -0.5, -0.08, Color(0.96, 0.95, 0.90), 1],
		["motorhome", 6.0, 0.0, 0.08, Color(0.94, 0.92, 0.86), 2],
	],
}
## Tents in a row, with the SUV, a gazebo and the van behind them.
const LAYOUT_VILLAGE := {
	"half": Vector2(13.0, 10.0),
	"items": [
		["dome", -9.0, 6.0, -0.03, Color(0.78, 0.20, 0.18), Color(0.88, 0.88, 0.84)],
		["tunnel", -1.9, 6.0, 0.02, Color(0.16, 0.48, 0.68), Color(0.88, 0.68, 0.16)],
		["ridge", 5.2, 6.0, -0.02, Color(0.86, 0.62, 0.14), Color(0.30, 0.34, 0.40)],
		["suv", -8.5, -4.5, 0.06, Color(0.86, 0.84, 0.78), 0],
		["gazebo", -0.5, -5.5, 0.0, Color(0.80, 0.11, 0.09)],
		["van", 8.0, -4.5, -0.05, Color(0.94, 0.95, 0.93), 0],
		["bbq", 2.9, -2.3, 0.0],
		["cooler", 4.4, -2.4, 0.3, Color(0.80, 0.10, 0.10)],
	],
}


## Builds a layout from the items above on a terrace centred at `centre` (world x, z), turned `yaw` so
## its +z points toward the track, with everything `scale` times life size. `ground` is a
## Callable(x, z) -> world height. Meshes go into `kit` (vehicles, tents, the gazebo) and `gear`
## (table, chairs, barbecue, cool box). Returns {"placed": [[name, footprint]], "boxes": [[centre,
## size, basis]] (the vehicles), "notes": [[name, at, radius]], "bad": PackedStringArray} where
## "bad" lists any pair closer than CAMP_GAP.
func build_layout(kit: Dictionary, gear: Dictionary, layout: Dictionary, centre: Vector2, yaw: float, ground: Callable, scale: float) -> Dictionary:
	var basis := Basis(Vector3.UP, yaw)
	var placed: Array = []
	var boxes: Array = []
	var notes: Array = []
	for it in layout["items"]:
		var kind: String = it[0]
		var w: Vector3 = Vector3(centre.x, 0.0, centre.y) + basis * Vector3(float(it[1]), 0.0, float(it[2]))
		w.y = ground.call(w.x, w.z)
		var pyaw := yaw + PI + float(it[3])
		var xf := Transform3D(Basis(Vector3.UP, pyaw).scaled(Vector3.ONE * scale), w)
		_kit.set_frame(xf)
		match kind:
			"motorhome", "caravan", "van", "suv":
				var size: Vector3 = vehicle(kit, kind, it[4], int(it[5]))
				placed.append(["%s@%.0f,%.0f" % [kind, float(it[1]), float(it[2])], footprint(vehicle_foot(kind, int(it[5])), xf)])
				boxes.append([w + Vector3(0.0, size.y * 0.5 * scale, 0.0), Vector3(size.z, size.y, size.x) * scale, Basis(Vector3.UP, pyaw)])
				notes.append(["Camp" + kind, w, size.x * 0.5 * scale])
			"dome":
				dome_tent(kit, it[4], it[5])
				placed.append(["dome tent", footprint(kind, xf)])
			"ridge":
				ridge_tent(kit, it[4], it[5])
				placed.append(["ridge tent", footprint(kind, xf)])
			"tunnel":
				tunnel_tent(kit, it[4], it[5])
				placed.append(["tunnel tent", footprint(kind, xf)])
			"gazebo":
				gazebo(kit, it[4], false)
				placed.append(["gazebo", footprint(kind, xf)])
				_kit.set_frame(xf * Transform3D(Basis(), Vector3(0, 0, 0.35)))
				folding_table(gear, WHITE)
				for c in range(3):
					_kit.set_frame(xf * Transform3D(Basis(Vector3.UP, PI + c * 0.55 - 0.55), Vector3(-0.9 + c * 0.9, 0, -0.55)))
					camp_chair(gear, CHAIR_COLS[c % CHAIR_COLS.size()])
			"bbq":
				bbq(gear)
			"cooler":
				cooler(gear, it[4], WHITE)
	_kit.reset_frame()
	# Everything inside the pad's half size (a metre of give for the blend), and spaced.
	var half: Vector2 = layout["half"]
	var back := basis.inverse()
	var bad := crowded(placed, CAMP_GAP)
	for p in placed:
		for corner in p[1]:
			var l: Vector3 = back * Vector3(corner.x - centre.x, 0.0, corner.y - centre.y)
			if absf(l.x) > half.x + 1.0 or absf(l.z) > half.y + 1.0:
				bad.append("%s off the pad" % p[0])
				break
	return {"placed": placed, "boxes": boxes, "notes": notes, "bad": bad}


## The footprint key of a vehicle: its awning stowed or out depends on the variant.
static func vehicle_foot(kind: String, variant: int) -> String:
	if kind == "motorhome" and variant >= 2:
		return "motorhome_stowed"
	if kind == "caravan" and variant >= 1:
		return "caravan_stowed"
	return kind


## The ground outline (x, z) of footprint `key` placed at `xf` (the frame the prop is built through,
## scale included).
static func footprint(key: String, xf: Transform3D) -> PackedVector2Array:
	var r: Vector4 = FOOT[key]
	var out := PackedVector2Array()
	for c in [Vector2(r.x, r.z), Vector2(r.y, r.z), Vector2(r.y, r.w), Vector2(r.x, r.w)]:
		var p: Vector3 = xf * Vector3(c.x, 0.0, c.y)
		out.append(Vector2(p.x, p.z))
	return out


## The pairs among `placed` ([name, footprint] each) that stand closer than `gap` metres: each
## outline is grown by half the gap and the grown outlines must not touch.
static func crowded(placed: Array, gap: float) -> PackedStringArray:
	var grown: Array = []
	for p in placed:
		var g: Array = Geometry2D.offset_polygon(p[1], gap * 0.5, Geometry2D.JOIN_MITER)
		grown.append(g[0] if not g.is_empty() else p[1])
	var bad := PackedStringArray()
	for i in range(placed.size()):
		for j in range(i + 1, placed.size()):
			if not Geometry2D.intersect_polygons(grown[i], grown[j]).is_empty():
				bad.append("%s / %s" % [placed[i][0], placed[j][0]])
	return bad


## The material for a kit key of the camp's vertex-coloured parts (a fresh one each call).
static func make_material(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.7
	match key:
		"matte":
			m.roughness = 0.95
		"metal":
			m.metallic = 0.7
			m.roughness = 0.32
		"steel":
			m.metallic = 0.3
			m.roughness = 0.55
		"chrome":
			m.metallic = 1.0
			m.roughness = 0.12
		"plastic":
			m.roughness = 0.38
		"rubber":
			m.roughness = 0.92
			m.metallic_specular = 0.25
		"canvas":
			m.roughness = 0.93
		"wood":
			m.roughness = 0.85
		"gloss":
			m.roughness = 0.24
			m.metallic = 0.08
		"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic = 0.4
			m.roughness = 0.05
		"lamp":
			m.emission_enabled = true
			m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			m.emission = Color(1.0, 1.0, 1.0)
			m.emission_energy_multiplier = 0.75
			m.roughness = 0.18
	return m


## A vehicle of `kind` at life size, its nose toward -z. Returns its size (length, height, width).
func vehicle(kit: Dictionary, kind: String, col: Color, variant := 0) -> Vector3:
	var k := _kit
	var base := k.xf
	# Built along x (front at +x) and across z (+z right/camp side, -z left), then turned so the nose points to -z.
	k.set_frame(base * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	var size := Vector3.ZERO
	match kind:
		"motorhome":
			size = _motorhome(kit, col, variant)
		"caravan":
			size = _caravan(kit, col, variant)
		"van":
			size = _panel_van(kit, col, variant)
		"suv":
			size = _suv(kit, col)
	k.set_frame(base)
	return size


## Wheel at `c` (vehicle frame: x along, z across), radius `r`, width `w`, on side `side` (-1 or +1),
## backed by a solid dark wheel-well housing and a 5-spoke rim with hubcap and brake disc.
func _wheel(kit: Dictionary, c: Vector3, r: float, w: float, side: float, body_hw := 0.0, arch_trim := Color(0.18, 0.19, 0.21)) -> void:
	var k := _kit
	var ab := Basis(Vector3.RIGHT, PI * 0.5 * side)
	# Dark wheel-well drum inside the body so daylight never shows through the wheel arch cutout.
	var well_r := r * 1.18
	var well_z_out: float = (body_hw - 0.015) * side if body_hw > 0.0 else c.z + side * (w * 0.42)
	var well_z_in: float = well_z_out - side * (w + 0.18)
	k.tube(kit, "matte", Vector3(c.x, c.y + 0.03, well_z_in), Vector3(c.x, c.y + 0.03, well_z_out), well_r, well_r, 14, CHASSIS_DARK)
	# Flared wheel-arch lip over the upper half of the wheel opening.
	if body_hw > 0.0:
		var z_lip0 := (body_hw - 0.02) * side
		var z_lip1 := (body_hw + 0.042) * side
		var flare_r0 := r * 1.12
		var flare_r1 := r * 1.24
		var segs := 10
		for i in range(segs):
			var a0 := -0.12 + (PI + 0.24) * i / segs
			var a1 := -0.12 + (PI + 0.24) * (i + 1) / segs
			var p00 := Vector3(c.x + cos(a0) * flare_r0, maxf(c.y + sin(a0) * flare_r0, 0.40), z_lip1)
			var p01 := Vector3(c.x + cos(a1) * flare_r0, maxf(c.y + sin(a1) * flare_r0, 0.40), z_lip1)
			var p10 := Vector3(c.x + cos(a0) * flare_r1, maxf(c.y + sin(a0) * flare_r1, 0.40), z_lip0)
			var p11 := Vector3(c.x + cos(a1) * flare_r1, maxf(c.y + sin(a1) * flare_r1, 0.40), z_lip0)
			var fn := Vector3(cos((a0 + a1) * 0.5) * 0.35, sin((a0 + a1) * 0.5) * 0.35, side).normalized()
			k.quad(kit, "plastic", [p10, p11, p01, p00], fn, arch_trim)
	# Tyre, brake rotor, alloy rim dish, 5 spokes and centre cap.
	k.tyre(kit, "rubber", c, r * 0.54, r, w, 18, TYRE, ab)
	k.lathe(kit, "steel", c - ab * Vector3(0, w * 0.05, 0), [Vector2(r * 0.44, 0.0), Vector2(0.08, 0.0)], 10, Color(0.28, 0.29, 0.31), false, ab)
	var rim_col := Color(0.80, 0.82, 0.85)
	k.lathe(kit, "metal", c + ab * Vector3(0, w * 0.38, 0), [
		Vector2(r * 0.60, 0.015), Vector2(r * 0.53, 0.015), Vector2(r * 0.48, -0.025), Vector2(0.0, -0.025)
	], 15, rim_col.darkened(0.22), false, ab)
	var face_z := c.z + side * (w * 0.39)
	for sp in range(5):
		var ang := TAU * sp / 5.0 + 0.2
		var p_in := Vector3(c.x + cos(ang) * r * 0.14, c.y + sin(ang) * r * 0.14, face_z + side * 0.006)
		var p_out := Vector3(c.x + cos(ang) * r * 0.52, c.y + sin(ang) * r * 0.52, face_z)
		k.beam(kit, "metal", p_in, p_out, r * 0.11, 0.022, rim_col, Vector3(0, 0, side))
	k.lathe(kit, "chrome", c + ab * Vector3(0, w * 0.40, 0), [
		Vector2(r * 0.18, 0.0), Vector2(r * 0.15, 0.022), Vector2(0.0, 0.026)
	], 10, Color(0.88, 0.89, 0.91), false, ab)


## Framed habitation window on one side (`side` = -1 or +1) at half-width `hw`: rounded rubber bezel,
## dark glass pane, optional upper cream pleated blind (`blind_frac` > 0) and central sliding mullion.
func _hab_window(kit: Dictionary, x0: float, x1: float, y0: float, y1: float, hw: float, side: float, blind_frac := 0.26, mullion := false) -> void:
	var k := _kit
	var n := Vector3(0, 0, side)
	var z_frame := (hw + 0.016) * side
	var z_pane := (hw + 0.024) * side
	var z_bar := (hw + 0.030) * side
	var fw := 0.042
	# Outer rounded rubber frame (4 non-overlapping bars around the perimeter).
	k.quad(kit, "plastic", [Vector3(x0 - fw, y0 - fw, z_frame), Vector3(x1 + fw, y0 - fw, z_frame), Vector3(x1 + fw, y0, z_frame), Vector3(x0 - fw, y0, z_frame)], n, RUB_TRIM)
	k.quad(kit, "plastic", [Vector3(x0 - fw, y1, z_frame), Vector3(x1 + fw, y1, z_frame), Vector3(x1 + fw, y1 + fw, z_frame), Vector3(x0 - fw, y1 + fw, z_frame)], n, RUB_TRIM)
	k.quad(kit, "plastic", [Vector3(x0 - fw, y0, z_frame), Vector3(x0, y0, z_frame), Vector3(x0, y1, z_frame), Vector3(x0 - fw, y1, z_frame)], n, RUB_TRIM)
	k.quad(kit, "plastic", [Vector3(x1, y0, z_frame), Vector3(x1 + fw, y0, z_frame), Vector3(x1 + fw, y1, z_frame), Vector3(x1, y1, z_frame)], n, RUB_TRIM)
	# Glass pane and non-overlapping upper pleated blind strip.
	var y_split := lerpf(y1, y0, clampf(blind_frac, 0.0, 0.85))
	k.quad(kit, "glass", [Vector3(x0, y0, z_pane), Vector3(x1, y0, z_pane), Vector3(x1, y_split, z_pane), Vector3(x0, y_split, z_pane)], n, GLASS)
	if blind_frac > 0.01:
		k.quad(kit, "canvas", [Vector3(x0, y_split, z_pane), Vector3(x1, y_split, z_pane), Vector3(x1, y1, z_pane), Vector3(x0, y1, z_pane)], n, Color(0.88, 0.85, 0.78))
		k.beam(kit, "plastic", Vector3(x0, y_split, z_bar), Vector3(x1, y_split, z_bar), 0.022, 0.014, RUB_TRIM, n)
	if mullion:
		var xm := (x0 + x1) * 0.5
		k.beam(kit, "plastic", Vector3(xm, y0, z_bar), Vector3(xm, y_split, z_bar), 0.024, 0.016, RUB_TRIM, n)


## Framed polygon window on side `side` (cab door windows).
func _framed_poly_window(kit: Dictionary, poly: PackedVector2Array, hw: float, side: float, col := GLASS) -> void:
	var k := _kit
	var n := Vector3(0, 0, side)
	var z_pane := (hw + 0.022) * side
	var z_trim := (hw + 0.028) * side
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		k.tri(kit, "glass", Vector3(poly[tris[i]].x, poly[tris[i]].y, z_pane), Vector3(poly[tris[i + 1]].x, poly[tris[i + 1]].y, z_pane),
				Vector3(poly[tris[i + 2]].x, poly[tris[i + 2]].y, z_pane), n, n, n, col, n)
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		k.beam(kit, "plastic", Vector3(a.x, a.y, z_trim), Vector3(b.x, b.y, z_trim), 0.036, 0.018, RUB_TRIM, n)


##Glass and trim on both sides of a body `hw` half wide.
func _side_window(kit: Dictionary, poly: PackedVector2Array, hw: float, col := GLASS) -> void:
	for side in [-1.0, 1.0]:
		_framed_poly_window(kit, poly, hw, side, col)


## A side stripe band from x0 to x1 between y0 and y1 on both sides (1.2cm proud of the wall).
func _stripe(kit: Dictionary, x0: float, x1: float, y0: float, y1: float, hw: float, col: Color, key := "gloss") -> void:
	for side in [-1.0, 1.0]:
		var z: float = (hw + 0.012) * side
		_kit.quad(kit, key, [Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z)], Vector3(0, 0, side), col)


## Rooftop solar panel with anodized frame and dark photovoltaic cell grid.
func _solar_panel(kit: Dictionary, x0: float, x1: float, y: float, z0: float, z1: float) -> void:
	var k := _kit
	k.block(kit, "metal", Vector3(x0, y, z0), Vector3(x1, y + 0.04, z1), GALV)
	k.quad(kit, "gloss", [Vector3(x0 + 0.04, y + 0.045, z0 + 0.04), Vector3(x1 - 0.04, y + 0.045, z0 + 0.04),
			Vector3(x1 - 0.04, y + 0.045, z1 - 0.04), Vector3(x0 + 0.04, y + 0.045, z1 - 0.04)], Vector3.UP, Color(0.06, 0.11, 0.22))
	var xm := (x0 + x1) * 0.5
	var zm := (z0 + z1) * 0.5
	k.beam(kit, "metal", Vector3(xm, y + 0.048, z0 + 0.04), Vector3(xm, y + 0.048, z1 - 0.04), 0.018, 0.008, GALV, Vector3.UP)
	k.beam(kit, "metal", Vector3(x0 + 0.04, y + 0.048, zm), Vector3(x1 - 0.04, y + 0.048, zm), 0.018, 0.008, GALV, Vector3.UP)


## Shrouded rooftop RV air-conditioner unit with side louvres.
func _roof_ac(kit: Dictionary, cx: float, y: float) -> void:
	var k := _kit
	var ac_outline := PackedVector2Array([Vector2(cx - 0.52, y), Vector2(cx + 0.52, y), Vector2(cx + 0.42, y + 0.22),
			Vector2(cx - 0.38, y + 0.24), Vector2(cx - 0.50, y + 0.14)])
	k.extrude(kit, "plastic", ac_outline, -0.44, 0.44, 0.05, Color(0.92, 0.92, 0.90))
	for side: float in [-1.0, 1.0]:
		var z := 0.445 * side
		k.quad(kit, "matte", [Vector3(cx - 0.36, y + 0.05, z), Vector3(cx + 0.10, y + 0.05, z),
				Vector3(cx + 0.10, y + 0.15, z), Vector3(cx - 0.36, y + 0.15, z)], Vector3(0, 0, side), Color(0.18, 0.19, 0.21))


## Deployed or stowed roll-out RV/caravan awning on side `side` (+1 right/camp side).
func _rv_awning(kit: Dictionary, x0: float, x1: float, y_top: float, hw: float, side: float, deployed: bool, stripe_col: Color) -> void:
	var k := _kit
	var z_cas := hw * side
	# Cassette housing along the upper wall.
	k.block(kit, "plastic", Vector3(x0, y_top - 0.13, z_cas), Vector3(x1, y_top, z_cas + side * 0.11), Color(0.88, 0.89, 0.90))
	for ex in [x0, x1]:
		k.block(kit, "plastic", Vector3(ex - 0.03, y_top - 0.135, z_cas), Vector3(ex + 0.03, y_top + 0.005, z_cas + side * 0.115), RUB_TRIM)
	if not deployed:
		return
	var reach := 1.95
	var z_in := z_cas + side * 0.09
	var z_out := z_cas + side * reach
	var y_in := y_top - 0.05
	var y_out := y_top - 0.68
	var top_n := Vector3(0, reach, (y_in - y_out) * side).normalized()
	var n_strips := 9
	for i in range(n_strips):
		var sx0 := lerpf(x0 + 0.05, x1 - 0.05, float(i) / n_strips)
		var sx1 := lerpf(x0 + 0.05, x1 - 0.05, float(i + 1) / n_strips)
		var c: Color = stripe_col if i % 2 == 0 else Color(0.95, 0.94, 0.90)
		var p := [Vector3(sx0, y_in, z_in), Vector3(sx1, y_in, z_in), Vector3(sx1, y_out, z_out), Vector3(sx0, y_out, z_out)]
		k.panel(kit, "canvas", p, top_n, c, c.darkened(0.22))
		# Front valance drop along the outer roller bar.
		var vn := Vector3(0, 0, side)
		k.panel(kit, "canvas", [Vector3(sx0, y_out, z_out), Vector3(sx1, y_out, z_out),
				Vector3(sx1, y_out - 0.15, z_out), Vector3(sx0, y_out - 0.15, z_out)], vn, c, c.darkened(0.22))
	# Front roller tube and two telescopic support arms anchored to the lower body skirt.
	k.tube(kit, "metal", Vector3(x0 + 0.03, y_out, z_out), Vector3(x1 - 0.03, y_out, z_out), 0.028, 0.028, 8, GALV)
	for lx in [x0 + 0.18, x1 - 0.18]:
		k.beam(kit, "metal", Vector3(lx, y_in - 0.03, z_in), Vector3(lx, y_out - 0.02, z_out - side * 0.04), 0.028, 0.028, GALV)
		k.tube(kit, "metal", Vector3(lx, y_out - 0.02, z_out - side * 0.03), Vector3(lx, 0.56, z_cas + side * 0.03), 0.018, 0.018, 6, GALV)


## Class C motorhome: narrower sculpted van cab with bonnet, grille, headlamps and framed windscreen,
## over-cab Luton sleeper alcove with panoramic window, wider coach body with graphics, habitation
## door & step on the camp side, service vents on the off-side, rooftop A/C & solar, rear ladder,
## bike rack and multi-lens tail lights.
func _motorhome(kit: Dictionary, col: Color, variant := 0) -> Vector3:
	var k := _kit
	var hw := 1.16
	var hw_cab := 0.99
	var accents := [
		[Color(0.62, 0.16, 0.14), Color(0.86, 0.62, 0.20)],
		[Color(0.12, 0.34, 0.64), Color(0.28, 0.68, 0.86)],
		[Color(0.16, 0.44, 0.28), Color(0.82, 0.68, 0.24)],
	]
	var pal: Array = accents[posmod(variant, accents.size())]
	var acc1: Color = pal[0]
	var acc2: Color = pal[1]
	var skirt_col := Color(0.26, 0.28, 0.31)
	# 1. Underbody chassis box so nothing under the body is hollow.
	k.block(kit, "matte", Vector3(-3.35, 0.36, -0.78), Vector3(3.25, 0.54, 0.78), CHASSIS_DARK)
	# 2. Coach habitation body (x = -3.62 .. 1.55, full width hw = 1.16) + Luton bunk (x = 1.55 .. 3.04).
	var coach_outline := _arched([
		Vector2(-3.62, 0.46), Vector2(1.55, 0.46), Vector2(1.55, 2.04), Vector2(2.45, 2.04),
		Vector2(2.72, 2.18), Vector2(3.02, 2.48), Vector2(2.96, 2.86), Vector2(2.60, 3.05),
		Vector2(-3.48, 3.08), Vector2(-3.62, 2.94)
	], [-1.32], 0.40, 0.48)
	k.extrude(kit, "gloss", coach_outline, -hw, hw, 0.08, col)
	# 3. Narrower van cab (x = 1.48 .. 3.68, hw_cab = 0.99) with sloped bonnet and windscreen plane.
	# Windscreen plane runs from (3.02, 1.28) to (2.38, 2.04); bonnet from (3.62, 1.06) to (3.02, 1.28).
	var cab_outline := _arched([
		Vector2(1.42, 0.44), Vector2(3.52, 0.44), Vector2(3.66, 0.62), Vector2(3.62, 1.06),
		Vector2(3.02, 1.28), Vector2(2.38, 2.04), Vector2(1.42, 2.04)
	], [2.42], 0.40, 0.47)
	k.extrude(kit, "gloss", cab_outline, -hw_cab, hw_cab, 0.07, col)
	# Lower anthracite side skirts on coach body and cab steps.
	_stripe(kit, -3.56, -1.84, 0.47, 0.68, hw, skirt_col, "paint")
	_stripe(kit, -0.80, 1.52, 0.47, 0.68, hw, skirt_col, "paint")
	_stripe(kit, 1.52, 1.88, 0.45, 0.64, hw_cab, skirt_col, "paint")
	# Sweeping multi-stripe RV graphics on both sides of the coach body and Luton bunk.
	_stripe(kit, -3.56, 1.50, 0.92, 1.08, hw, acc1)
	_stripe(kit, -3.56, 1.50, 1.11, 1.16, hw, acc2)
	_stripe(kit, -3.52, 0.35, 2.66, 2.74, hw, acc1)
	_stripe(kit, 1.62, 2.84, 2.16, 2.24, hw, acc2)
	# 4. Cab windscreen (proud of the (3.02, 1.28)->(2.38, 2.04) plane), wipers, A-pillars and Luton window.
	var wn := Vector3(0.76, 0.64, 0.0).normalized()
	var ws_b0 := Vector3(3.02, 1.28, -hw_cab + 0.11) + wn * 0.022
	var ws_b1 := Vector3(3.02, 1.28, hw_cab - 0.11) + wn * 0.022
	var ws_t1 := Vector3(2.38, 2.04, hw_cab - 0.13) + wn * 0.022
	var ws_t0 := Vector3(2.38, 2.04, -hw_cab + 0.13) + wn * 0.022
	k.quad(kit, "glass", [ws_b0, ws_b1, ws_t1, ws_t0], wn, GLASS)
	for edge in [[ws_b0, ws_b1], [ws_t0, ws_t1], [ws_b0, ws_t0], [ws_b1, ws_t1]]:
		k.beam(kit, "plastic", (edge[0] as Vector3) + wn * 0.008, (edge[1] as Vector3) + wn * 0.008, 0.045, 0.02, RUB_TRIM, wn)
	# Twin windscreen wipers.
	for wz in [-0.38, 0.12]:
		k.beam(kit, "plastic", Vector3(2.98, 1.32, wz) + wn * 0.032, Vector3(2.76, 1.58, wz + 0.36) + wn * 0.032, 0.022, 0.016, RUB_TRIM, wn)
	# Luton panoramic front window (proud of the (3.02, 2.48)->(2.96, 2.86) front slope).
	var ln := Vector3(0.988, 0.156, 0.0).normalized()
	var lw_b0 := Vector3(3.01, 2.52, -0.68) + ln * 0.024
	var lw_b1 := Vector3(3.01, 2.52, 0.68) + ln * 0.024
	var lw_t1 := Vector3(2.97, 2.80, 0.62) + ln * 0.024
	var lw_t0 := Vector3(2.97, 2.80, -0.62) + ln * 0.024
	k.quad(kit, "glass", [lw_b0, lw_b1, lw_t1, lw_t0], ln, GLASS)
	for edge in [[lw_b0, lw_b1], [lw_t0, lw_t1], [lw_b0, lw_t0], [lw_b1, lw_t1]]:
		k.beam(kit, "plastic", (edge[0] as Vector3) + ln * 0.008, (edge[1] as Vector3) + ln * 0.008, 0.04, 0.02, RUB_TRIM, ln)
	# Cab door windows and Luton side alcove windows on both sides.
	var cab_win := PackedVector2Array([Vector2(1.62, 1.32), Vector2(2.86, 1.28), Vector2(2.32, 1.94), Vector2(1.62, 1.94)])
	for side in [-1.0, 1.0]:
		_framed_poly_window(kit, cab_win, hw_cab, side)
		_hab_window(kit, 1.72, 2.42, 2.34, 2.68, hw, side, 0.22, false)
		# Cab door handle and lower step pocket.
		k.block(kit, "plastic", Vector3(1.68, 1.12, (hw_cab + 0.01) * side), Vector3(1.86, 1.17, (hw_cab + 0.035) * side), RUB_TRIM)
		k.block(kit, "matte", Vector3(1.65, 0.46, (hw_cab - 0.01) * side), Vector3(2.02, 0.58, (hw_cab + 0.015) * side), RUB_TRIM)
	# 5. Camp side (+z = +1): habitation door with window, handle, porch lamp, entry step, windows & storage lockers.
	var zd := (hw + 0.014)
	var nd := Vector3(0, 0, 1)
	# Habitation door leaf (x = 0.42 .. 1.08, y = 0.52 .. 2.36) and outer black rubber frame.
	var dx0 := 0.42
	var dx1 := 1.08
	var dy0 := 0.52
	var dy1 := 2.36
	k.quad(kit, "gloss", [Vector3(dx0, dy0, zd), Vector3(dx1, dy0, zd), Vector3(dx1, dy1, zd), Vector3(dx0, dy1, zd)], nd, col.darkened(0.05))
	for edge in [[dx0, dy0, dx1, dy0], [dx0, dy1, dx1, dy1], [dx0, dy0, dx0, dy1], [dx1, dy0, dx1, dy1]]:
		k.beam(kit, "plastic", Vector3(float(edge[0]), float(edge[1]), zd + 0.01), Vector3(float(edge[2]), float(edge[3]), zd + 0.01), 0.036, 0.018, RUB_TRIM, nd)
	_hab_window(kit, 0.54, 0.96, 1.48, 2.16, hw + 0.014, 1.0, 0.20, false)
	k.block(kit, "chrome", Vector3(0.47, 1.24, zd + 0.01), Vector3(0.54, 1.36, zd + 0.04), Color(0.86, 0.88, 0.90))
	k.block(kit, "lamp", Vector3(0.58, 2.44, hw), Vector3(0.92, 2.50, hw + 0.035), Color(1.0, 0.94, 0.78))
	# Deployed metal entry step under the habitation door.
	k.block(kit, "metal", Vector3(0.44, 0.26, hw - 0.05), Vector3(1.06, 0.32, hw + 0.24), GALV)
	k.block(kit, "rubber", Vector3(0.46, 0.32, hw + 0.02), Vector3(1.04, 0.335, hw + 0.22), RUB_TRIM)
	# Camp-side habitation windows and rear garage hatch.
	_hab_window(kit, -1.18, 0.14, 1.48, 2.22, hw, 1.0, 0.25, true)
	_hab_window(kit, -3.15, -1.95, 1.54, 2.22, hw, 1.0, 0.28, true)
	for edge in [[-3.22, 0.52, -2.05, 0.52], [-3.22, 0.88, -2.05, 0.88], [-3.22, 0.52, -3.22, 0.88], [-2.05, 0.52, -2.05, 0.88]]:
		k.beam(kit, "plastic", Vector3(float(edge[0]), float(edge[1]), hw + 0.016), Vector3(float(edge[2]), float(edge[3]), hw + 0.016), 0.026, 0.014, RUB_TRIM, nd)
	k.block(kit, "chrome", Vector3(-2.68, 0.58, hw + 0.014), Vector3(-2.58, 0.64, hw + 0.032), Color(0.85, 0.86, 0.88))
	# Awning on the camp side (deployed on main terrace motorhomes).
	_rv_awning(kit, -3.25, 1.32, 2.98, hw, 1.0, variant < 2, acc1)
	# 6. Driver / service side (-z = -1): windows, twin louvred fridge vents, service hatch & garage door.
	_hab_window(kit, -0.88, 0.48, 1.48, 2.22, hw, -1.0, 0.25, true)
	_hab_window(kit, -3.15, -1.95, 1.54, 2.22, hw, -1.0, 0.28, true)
	for vy in [1.22, 1.62]:
		k.block(kit, "plastic", Vector3(0.68, vy, -hw - 0.022), Vector3(1.18, vy + 0.22, -hw), Color(0.84, 0.84, 0.82))
		k.quad(kit, "matte", [Vector3(0.72, vy + 0.04, -hw - 0.026), Vector3(1.14, vy + 0.04, -hw - 0.026),
				Vector3(1.14, vy + 0.18, -hw - 0.026), Vector3(0.72, vy + 0.18, -hw - 0.026)], Vector3(0, 0, -1), Color(0.22, 0.23, 0.25))
	for edge in [[-3.22, 0.52, -2.05, 0.52], [-3.22, 0.88, -2.05, 0.88], [-3.22, 0.52, -3.22, 0.88], [-2.05, 0.52, -2.05, 0.88]]:
		k.beam(kit, "plastic", Vector3(float(edge[0]), float(edge[1]), -hw - 0.016), Vector3(float(edge[2]), float(edge[3]), -hw - 0.016), 0.026, 0.014, RUB_TRIM, Vector3(0, 0, -1))
	# 7. Front grille, bumper, skid plate, headlights, fog lamps and twin-arm commercial mirrors.
	k.block(kit, "plastic", Vector3(3.50, 0.40, -hw_cab - 0.02), Vector3(3.72, 0.72, hw_cab + 0.02), Color(0.16, 0.17, 0.19))
	k.block(kit, "metal", Vector3(3.56, 0.40, -0.52), Vector3(3.74, 0.52, 0.52), GALV)
	k.block(kit, "matte", Vector3(3.60, 0.74, -0.56), Vector3(3.66, 1.04, 0.56), Color(0.09, 0.10, 0.11))
	for gy in [0.80, 0.89, 0.98]:
		k.beam(kit, "chrome", Vector3(3.665, gy, -0.52), Vector3(3.665, gy, 0.52), 0.024, 0.018, Color(0.88, 0.90, 0.92), Vector3.RIGHT)
	k.block(kit, "paint", Vector3(3.72, 0.53, -0.24), Vector3(3.75, 0.63, 0.24), WHITE)
	for sz in [-1.0, 1.0]:
		# Headlight bezel, main beam, amber turn indicator, and lower fog light.
		k.block(kit, "plastic", Vector3(3.56, 0.76, sz * 0.74 - 0.18), Vector3(3.65, 1.02, sz * 0.74 + 0.18), RUB_TRIM)
		k.block(kit, "lamp", Vector3(3.60, 0.79, sz * 0.70 - 0.11), Vector3(3.665, 0.99, sz * 0.70 + 0.11), Color(1.0, 0.97, 0.88))
		k.block(kit, "lamp", Vector3(3.60, 0.79, sz * 0.87 - 0.04), Vector3(3.665, 0.99, sz * 0.87 + 0.04), Color(0.98, 0.58, 0.08))
		k.block(kit, "lamp", Vector3(3.68, 0.48, sz * 0.76 - 0.06), Vector3(3.73, 0.56, sz * 0.76 + 0.06), Color(1.0, 0.95, 0.80))
		# Twin-arm commercial wing mirror + convex blind-spot mirror.
		k.beam(kit, "plastic", Vector3(2.58, 1.78, sz * hw_cab), Vector3(2.68, 1.82, sz * (hw_cab + 0.26)), 0.032, 0.032, RUB_TRIM)
		k.beam(kit, "plastic", Vector3(2.58, 1.52, sz * hw_cab), Vector3(2.68, 1.56, sz * (hw_cab + 0.26)), 0.028, 0.028, RUB_TRIM)
		k.block(kit, "plastic", Vector3(2.62, 1.48, sz * (hw_cab + 0.26) - 0.055), Vector3(2.71, 1.88, sz * (hw_cab + 0.26) + 0.055), RUB_TRIM)
	# 8. Rear wall (x = -3.62): framed rear window, roof ladder, twin-bike rack, bumper and tail-light clusters.
	var rx := -3.62
	var rn := Vector3(-1, 0, 0)
	k.quad(kit, "plastic", [Vector3(rx - 0.015, 1.66, -0.62), Vector3(rx - 0.015, 1.66, 0.62), Vector3(rx - 0.015, 2.30, 0.62), Vector3(rx - 0.015, 2.30, -0.62)], rn, RUB_TRIM)
	k.quad(kit, "glass", [Vector3(rx - 0.024, 1.71, -0.56), Vector3(rx - 0.024, 1.71, 0.56), Vector3(rx - 0.024, 2.12, 0.56), Vector3(rx - 0.024, 2.12, -0.56)], rn, GLASS)
	k.quad(kit, "canvas", [Vector3(rx - 0.024, 2.12, -0.56), Vector3(rx - 0.024, 2.12, 0.56), Vector3(rx - 0.024, 2.25, 0.56), Vector3(rx - 0.024, 2.25, -0.56)], rn, Color(0.88, 0.85, 0.78))
	_stripe_rear(kit, rx, -hw + 0.08, hw - 0.08, 0.92, 1.06, acc1)
	# Rear aluminium access ladder on the left side.
	for lz in [-0.96, -0.68]:
		k.tube(kit, "metal", Vector3(rx - 0.07, 0.74, lz), Vector3(rx - 0.07, 2.98, lz), 0.016, 0.016, 6, GALV)
		for y_mount in [0.82, 1.85, 2.90]:
			k.beam(kit, "metal", Vector3(rx, y_mount, lz), Vector3(rx - 0.07, y_mount, lz), 0.024, 0.024, GALV)
	var rung_y := 0.88
	while rung_y <= 2.86:
		k.tube(kit, "metal", Vector3(rx - 0.07, rung_y, -0.96), Vector3(rx - 0.07, rung_y, -0.68), 0.012, 0.012, 5, GALV)
		rung_y += 0.28
	# Rear twin-bike carrier rack on the centre/right.
	for bz in [-0.28, 0.42]:
		k.tube(kit, "metal", Vector3(rx, 1.48, bz), Vector3(rx - 0.06, 0.92, bz), 0.014, 0.014, 5, GALV)
		k.tube(kit, "metal", Vector3(rx - 0.06, 0.92, bz), Vector3(rx - 0.34, 0.92, bz), 0.014, 0.014, 5, GALV)
	k.beam(kit, "metal", Vector3(rx - 0.18, 0.94, -0.42), Vector3(rx - 0.18, 0.94, 0.56), 0.04, 0.02, GALV, Vector3.UP)
	k.beam(kit, "metal", Vector3(rx - 0.30, 0.94, -0.42), Vector3(rx - 0.30, 0.94, 0.56), 0.04, 0.02, acc1, Vector3.UP)
	# Rear bumper, license plate, upper marker lights and multi-section tail lights.
	k.block(kit, "plastic", Vector3(rx - 0.12, 0.42, -hw), Vector3(rx + 0.04, 0.68, hw), skirt_col)
	k.block(kit, "paint", Vector3(rx - 0.14, 0.50, -0.26), Vector3(rx - 0.11, 0.61, 0.26), Color(0.96, 0.82, 0.16))
	k.block(kit, "lamp", Vector3(rx - 0.03, 2.92, -0.18), Vector3(rx, 2.97, 0.18), Color(0.90, 0.08, 0.06))
	for sz: float in [-1.0, 1.0]:
		var tz := sz * 0.94
		k.block(kit, "plastic", Vector3(rx - 0.035, 0.72, tz - 0.10), Vector3(rx, 1.32, tz + 0.10), RUB_TRIM)
		k.block(kit, "lamp", Vector3(rx - 0.048, 1.04, tz - 0.08), Vector3(rx - 0.02, 1.29, tz + 0.08), Color(0.92, 0.08, 0.06))
		k.block(kit, "lamp", Vector3(rx - 0.048, 0.89, tz - 0.08), Vector3(rx - 0.02, 1.02, tz + 0.08), Color(0.98, 0.56, 0.06))
		k.block(kit, "lamp", Vector3(rx - 0.048, 0.75, tz - 0.08), Vector3(rx - 0.02, 0.87, tz + 0.08), Color(0.95, 0.95, 0.92))
		k.block(kit, "lamp", Vector3(rx - 0.03, 2.90, sz * 1.02 - 0.05), Vector3(rx, 2.96, sz * 1.02 + 0.05), Color(0.92, 0.08, 0.06))
	# 9. Roof gear: shrouded A/C unit, solar panel, two skylight domes and satellite dome.
	_roof_ac(kit, -0.55, 3.08)
	_solar_panel(kit, -2.35, -1.25, 3.08, -0.52, 0.52)
	for sk_x in [[0.55, 1.20], [-3.18, -2.62]]:
		k.block(kit, "plastic", Vector3(float(sk_x[0]) - 0.04, 3.08, -0.38), Vector3(float(sk_x[1]) + 0.04, 3.12, 0.38), Color(0.90, 0.90, 0.88))
		k.block(kit, "glass", Vector3(float(sk_x[0]), 3.12, -0.34), Vector3(float(sk_x[1]), 3.17, 0.34), GLASS)
	k.lathe(kit, "plastic", Vector3(1.55, 3.08, -0.48), [Vector2(0.24, 0.0), Vector2(0.22, 0.10), Vector2(0.12, 0.18), Vector2(0.0, 0.20)], 10, WHITE)
	# 10. Wheels (with dark wheel wells and arch flares).
	_wheel(kit, Vector3(2.42, 0.40, -hw_cab + 0.10), 0.40, 0.24, -1.0, hw_cab, skirt_col)
	_wheel(kit, Vector3(2.42, 0.40, hw_cab - 0.10), 0.40, 0.24, 1.0, hw_cab, skirt_col)
	_wheel(kit, Vector3(-1.32, 0.40, -hw + 0.12), 0.40, 0.26, -1.0, hw, skirt_col)
	_wheel(kit, Vector3(-1.32, 0.40, hw - 0.12), 0.40, 0.26, 1.0, hw, skirt_col)
	return Vector3(7.4, 3.3, 2.4)


func _stripe_rear(kit: Dictionary, rx: float, z0: float, z1: float, y0: float, y1: float, col: Color) -> void:
	var x := rx - 0.012
	_kit.quad(kit, "gloss", [Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0)], Vector3(-1, 0, 0), col)


## A touring caravan: raked aerodynamic front with 3-pane panoramic bay window and moulded gas locker,
## galvanised A-frame drawbar with hitch and jockey wheel, corner steadies, habitation door with step,
## touring stripes, rooftop solar & skylight, and a detailed rear lounge window & light cluster panel.
func _caravan(kit: Dictionary, col: Color, variant := 0) -> Vector3:
	var k := _kit
	var hw := 1.12
	var accents := [
		[Color(0.16, 0.42, 0.68), Color(0.52, 0.72, 0.88)],
		[Color(0.76, 0.34, 0.14), Color(0.90, 0.68, 0.24)],
	]
	var pal: Array = accents[posmod(variant, accents.size())]
	var acc1: Color = pal[0]
	var acc2: Color = pal[1]
	var skirt_col := Color(0.28, 0.30, 0.33)
	# Underbody chassis box.
	k.block(kit, "matte", Vector3(-2.45, 0.36, -0.76), Vector3(2.45, 0.50, 0.76), CHASSIS_DARK)
	# Body shell: front wall slopes cleanly from (2.92, 1.18) up to (2.54, 2.46).
	var outline := _arched([
		Vector2(-2.72, 0.45), Vector2(2.58, 0.45), Vector2(2.82, 0.58), Vector2(2.92, 1.18),
		Vector2(2.54, 2.46), Vector2(2.22, 2.62), Vector2(-2.52, 2.62), Vector2(-2.72, 2.46)
	], [0.05], 0.34, 0.42)
	k.extrude(kit, "gloss", outline, -hw, hw, 0.09, col)
	# Lower skirt and sweeping two-tone touring stripes.
	_stripe(kit, -2.68, -0.42, 0.46, 0.62, hw, skirt_col, "paint")
	_stripe(kit, 0.52, 2.62, 0.46, 0.62, hw, skirt_col, "paint")
	_stripe(kit, -2.68, 2.82, 0.86, 1.00, hw, acc1)
	_stripe(kit, -2.68, 2.80, 1.03, 1.08, hw, acc2)
	_stripe(kit, -2.58, 2.30, 2.38, 2.44, hw, acc1)
	# Front 3-pane panoramic bay window sitting 2.5cm proud of the (2.92, 1.18)->(2.54, 2.46) front plane.
	var fn := Vector3(1.28, 0.38, 0.0).normalized()
	var wy0 := 1.38
	var wy1 := 2.18
	var wx0 := lerpf(2.92, 2.54, (wy0 - 1.18) / (2.46 - 1.18))
	var wx1 := lerpf(2.92, 2.54, (wy1 - 1.18) / (2.46 - 1.18))
	var fb0 := Vector3(wx0, wy0, -0.88) + fn * 0.024
	var fb1 := Vector3(wx0, wy0, 0.88) + fn * 0.024
	var ft1 := Vector3(wx1, wy1, 0.88) + fn * 0.024
	var ft0 := Vector3(wx1, wy1, -0.88) + fn * 0.024
	k.quad(kit, "glass", [fb0, fb1, ft1, ft0], fn, GLASS)
	for edge in [[fb0, fb1], [ft0, ft1], [fb0, ft0], [fb1, ft1]]:
		k.beam(kit, "plastic", (edge[0] as Vector3) + fn * 0.008, (edge[1] as Vector3) + fn * 0.008, 0.042, 0.02, RUB_TRIM, fn)
	for mz in [-0.30, 0.30]:
		k.beam(kit, "paint", Vector3(wx0, wy0, mz) + fn * 0.03, Vector3(wx1, wy1, mz) + fn * 0.03, 0.034, 0.018, col, fn)
	# Moulded front gas-bottle locker box below the front window.
	var locker_outline := PackedVector2Array([Vector2(2.65, 0.48), Vector2(3.14, 0.48), Vector2(3.16, 0.92), Vector2(2.92, 1.16), Vector2(2.65, 1.16)])
	k.extrude(kit, "plastic", locker_outline, -0.82, 0.82, 0.06, col.darkened(0.05))
	k.block(kit, "plastic", Vector3(3.14, 0.72, -0.10), Vector3(3.19, 0.80, 0.10), RUB_TRIM)
	for sz in [-1.0, 1.0]:
		k.block(kit, "chrome", Vector3(2.86, 1.20, sz * 0.92 - 0.03), Vector3(2.96, 1.38, sz * 0.92 + 0.03), Color(0.86, 0.88, 0.90))
		k.block(kit, "lamp", Vector3(2.80, 0.52, sz * 0.92 - 0.05), Vector3(2.86, 0.60, sz * 0.92 + 0.05), Color(0.95, 0.95, 0.90))
	# Camp side (+z): habitation door with upper window, porch lamp, portable step, windows and awning cassette.
	var zd := hw + 0.014
	var nd := Vector3(0, 0, 1)
	var dx0 := 0.92
	var dx1 := 1.54
	var dy0 := 0.50
	var dy1 := 2.24
	k.quad(kit, "gloss", [Vector3(dx0, dy0, zd), Vector3(dx1, dy0, zd), Vector3(dx1, dy1, zd), Vector3(dx0, dy1, zd)], nd, col.darkened(0.05))
	for edge in [[dx0, dy0, dx1, dy0], [dx0, dy1, dx1, dy1], [dx0, dy0, dx0, dy1], [dx1, dy0, dx1, dy1]]:
		k.beam(kit, "plastic", Vector3(float(edge[0]), float(edge[1]), zd + 0.01), Vector3(float(edge[2]), float(edge[3]), zd + 0.01), 0.034, 0.016, RUB_TRIM, nd)
	_hab_window(kit, 1.04, 1.42, 1.42, 2.04, hw + 0.014, 1.0, 0.18, false)
	k.block(kit, "plastic", Vector3(0.97, 1.20, zd + 0.01), Vector3(1.04, 1.32, zd + 0.035), RUB_TRIM)
	k.block(kit, "lamp", Vector3(1.08, 2.30, hw), Vector3(1.38, 2.36, hw + 0.03), Color(1.0, 0.94, 0.78))
	# Portable caravan step on the ground outside the door.
	k.block(kit, "metal", Vector3(0.96, 0.0, hw + 0.08), Vector3(1.50, 0.22, hw + 0.42), skirt_col)
	k.block(kit, "rubber", Vector3(0.98, 0.22, hw + 0.10), Vector3(1.48, 0.24, hw + 0.40), RUB_TRIM)
	_hab_window(kit, -0.42, 0.68, 1.42, 2.12, hw, 1.0, 0.26, true)
	_hab_window(kit, -2.28, -1.08, 1.42, 2.12, hw, 1.0, 0.26, true)
	_rv_awning(kit, -2.35, 1.65, 2.52, hw, 1.0, variant == 0, acc1)
	# Off-side (-z): three framed touring windows and fridge vents.
	_hab_window(kit, 1.15, 2.22, 1.42, 2.12, hw, -1.0, 0.24, true)
	_hab_window(kit, -0.38, 0.72, 1.42, 2.12, hw, -1.0, 0.26, true)
	_hab_window(kit, -2.28, -1.08, 1.42, 2.12, hw, -1.0, 0.26, true)
	for vy in [1.12, 1.34]:
		k.block(kit, "plastic", Vector3(0.05, vy, -hw - 0.02), Vector3(0.48, vy + 0.14, -hw), Color(0.86, 0.86, 0.84))
	# Rear wall (x = -2.72): framed rear lounge window, bumper/light bar, reflectors, grab handles & high brake lamp.
	var rx := -2.72
	var rn := Vector3(-1, 0, 0)
	k.quad(kit, "plastic", [Vector3(rx - 0.015, 1.42, -0.72), Vector3(rx - 0.015, 1.42, 0.72), Vector3(rx - 0.015, 2.14, 0.72), Vector3(rx - 0.015, 2.14, -0.72)], rn, RUB_TRIM)
	k.quad(kit, "glass", [Vector3(rx - 0.024, 1.47, -0.66), Vector3(rx - 0.024, 1.47, 0.66), Vector3(rx - 0.024, 1.94, 0.66), Vector3(rx - 0.024, 1.94, -0.66)], rn, GLASS)
	k.quad(kit, "canvas", [Vector3(rx - 0.024, 1.94, -0.66), Vector3(rx - 0.024, 1.94, 0.66), Vector3(rx - 0.024, 2.09, 0.66), Vector3(rx - 0.024, 2.09, -0.66)], rn, Color(0.88, 0.85, 0.78))
	_stripe_rear(kit, rx, -hw + 0.09, hw - 0.09, 0.86, 1.00, acc1)
	k.block(kit, "plastic", Vector3(rx - 0.09, 0.45, -hw + 0.04), Vector3(rx + 0.02, 0.76, hw - 0.04), skirt_col)
	k.block(kit, "paint", Vector3(rx - 0.11, 0.52, -0.25), Vector3(rx - 0.08, 0.63, 0.25), Color(0.96, 0.82, 0.16))
	k.block(kit, "lamp", Vector3(rx - 0.03, 2.48, -0.18), Vector3(rx, 2.53, 0.18), Color(0.92, 0.08, 0.06))
	for sz: float in [-1.0, 1.0]:
		var tz := sz * 0.78
		k.block(kit, "lamp", Vector3(rx - 0.11, 0.53, tz - 0.18), Vector3(rx - 0.08, 0.68, tz + 0.04), Color(0.92, 0.08, 0.06))
		k.block(kit, "lamp", Vector3(rx - 0.11, 0.53, tz + 0.05), Vector3(rx - 0.08, 0.68, tz + 0.16), Color(0.98, 0.56, 0.06))
		k.block(kit, "chrome", Vector3(rx - 0.05, 1.12, sz * 0.90 - 0.03), Vector3(rx, 1.30, sz * 0.90 + 0.03), Color(0.86, 0.88, 0.90))
	# Roof: Heki skylight, solar panel and flue chimney.
	k.block(kit, "plastic", Vector3(0.32, 2.62, -0.38), Vector3(1.05, 2.67, 0.38), Color(0.92, 0.92, 0.90))
	k.block(kit, "glass", Vector3(0.36, 2.67, -0.34), Vector3(1.01, 2.72, 0.34), GLASS)
	_solar_panel(kit, -1.35, -0.25, 2.62, -0.46, 0.46)
	k.tube(kit, "plastic", Vector3(-1.75, 2.62, -0.55), Vector3(-1.75, 2.76, -0.55), 0.055, 0.055, 8, Color(0.85, 0.85, 0.83))
	k.lathe(kit, "plastic", Vector3(-1.75, 2.76, -0.55), [Vector2(0.09, 0.0), Vector2(0.0, 0.035)], 8, Color(0.75, 0.75, 0.73))
	# A-frame drawbar, hitch head, handbrake, jockey wheel and four corner steadies.
	k.beam(kit, "metal", Vector3(2.45, 0.42, -0.58), Vector3(3.96, 0.42, 0.0), 0.085, 0.085, GALV)
	k.beam(kit, "metal", Vector3(2.45, 0.42, 0.58), Vector3(3.96, 0.42, 0.0), 0.085, 0.085, GALV)
	k.block(kit, "metal", Vector3(3.15, 0.45, -0.32), Vector3(3.65, 0.48, 0.32), GALV.darkened(0.12))
	k.block(kit, "plastic", Vector3(3.88, 0.38, -0.09), Vector3(4.08, 0.50, 0.09), RUB_TRIM)
	k.beam(kit, "plastic", Vector3(3.98, 0.50, 0.0), Vector3(3.82, 0.64, 0.0), 0.04, 0.03, Color(0.86, 0.14, 0.12))
	k.beam(kit, "metal", Vector3(3.68, 0.46, 0.12), Vector3(3.52, 0.72, 0.14), 0.022, 0.022, Color(0.86, 0.14, 0.12))
	k.tube(kit, "metal", Vector3(3.62, 0.64, -0.08), Vector3(3.62, 0.09, -0.08), 0.032, 0.032, 6, GALV)
	k.tube(kit, "rubber", Vector3(3.62, 0.09, -0.12), Vector3(3.62, 0.09, -0.04), 0.09, 0.09, 10, TYRE)
	for sx in [-2.42, 2.38]:
		for sz in [-1.0, 1.0]:
			k.tube(kit, "metal", Vector3(sx, 0.45, sz * 0.88), Vector3(sx, 0.02, sz * 0.94), 0.022, 0.022, 5, GALV)
			k.block(kit, "plastic", Vector3(sx - 0.06, 0.0, sz * 0.94 - 0.06), Vector3(sx + 0.06, 0.025, sz * 0.94 + 0.06), RUB_TRIM)
	_wheel(kit, Vector3(0.05, 0.34, -hw + 0.09), 0.34, 0.22, -1.0, hw, skirt_col)
	_wheel(kit, Vector3(0.05, 0.34, hw - 0.09), 0.34, 0.22, 1.0, hw, skirt_col)
	return Vector3(6.8, 2.75, 2.3)


## Pop-top adventure campervan: two-tone paintwork, sculpted bonnet and grille, framed windscreen,
## tinted camper windows, side awning cassette, elevated pop-up sleeping roof with canvas bellows
## and mesh vents, and rear barn doors with ladder and spare wheel.
func _panel_van(kit: Dictionary, col: Color, _variant := 0) -> Vector3:
	var k := _kit
	var hw := 0.98
	var lower_col := Color(0.18, 0.44, 0.48)
	var cladding := Color(0.15, 0.16, 0.18)
	var stripe_acc := Color(0.92, 0.56, 0.14)
	# Underbody chassis box.
	k.block(kit, "matte", Vector3(-2.65, 0.34, -0.74), Vector3(2.65, 0.50, 0.74), CHASSIS_DARK)
	# Body shell: windscreen plane from (2.28, 1.28) to (1.36, 2.28); bonnet from (2.94, 1.06) to (2.28, 1.28).
	var outline := _arched([
		Vector2(-2.92, 0.45), Vector2(2.84, 0.44), Vector2(2.96, 0.62), Vector2(2.94, 1.06),
		Vector2(2.28, 1.28), Vector2(1.36, 2.28), Vector2(1.12, 2.38), Vector2(-2.82, 2.38), Vector2(-2.92, 2.26)
	], [1.88, -1.72], 0.37, 0.44)
	k.extrude(kit, "gloss", outline, -hw, hw, 0.08, col)
	# Two-tone lower body band, matte rocker cladding and adventure stripe.
	_stripe(kit, -2.86, 1.40, 0.62, 1.12, hw, lower_col)
	_stripe(kit, -2.86, -2.20, 0.45, 0.62, hw, cladding, "paint")
	_stripe(kit, -1.26, 1.42, 0.45, 0.62, hw, cladding, "paint")
	_stripe(kit, -2.86, 1.65, 1.13, 1.18, hw, stripe_acc)
	# Windscreen sitting 2.2cm proud of the (2.28, 1.28)->(1.36, 2.28) slope, with rubber frame & wipers.
	var wn := Vector3(1.00, 0.92, 0.0).normalized()
	var wb0 := Vector3(2.26, 1.30, -hw + 0.10) + wn * 0.022
	var wb1 := Vector3(2.26, 1.30, hw - 0.10) + wn * 0.022
	var wt1 := Vector3(1.38, 2.26, hw - 0.12) + wn * 0.022
	var wt0 := Vector3(1.38, 2.26, -hw + 0.12) + wn * 0.022
	k.quad(kit, "glass", [wb0, wb1, wt1, wt0], wn, GLASS)
	for edge in [[wb0, wb1], [wt0, wt1], [wb0, wt0], [wb1, wt1]]:
		k.beam(kit, "plastic", (edge[0] as Vector3) + wn * 0.008, (edge[1] as Vector3) + wn * 0.008, 0.04, 0.02, RUB_TRIM, wn)
	for wz in [-0.36, 0.12]:
		k.beam(kit, "plastic", Vector3(2.22, 1.34, wz) + wn * 0.03, Vector3(1.98, 1.60, wz + 0.34) + wn * 0.03, 0.02, 0.015, RUB_TRIM, wn)
	# Cab door windows and tinted flush camper windows along both sides.
	var cab_win := PackedVector2Array([Vector2(0.82, 1.32), Vector2(2.16, 1.28), Vector2(1.36, 2.16), Vector2(0.82, 2.16)])
	for side in [-1.0, 1.0]:
		_framed_poly_window(kit, cab_win, hw, side)
		_hab_window(kit, -0.72, 0.64, 1.32, 2.08, hw, side, 0.18, true)
		_hab_window(kit, -2.58, -0.92, 1.32, 2.08, hw, side, 0.22, false)
		k.block(kit, "plastic", Vector3(0.88, 1.16, (hw + 0.01) * side), Vector3(1.04, 1.21, (hw + 0.035) * side), RUB_TRIM)
	# Sliding door track & black awning cassette on the camp side (+z).
	k.beam(kit, "plastic", Vector3(-1.95, 1.24, hw + 0.018), Vector3(0.58, 1.24, hw + 0.018), 0.022, 0.016, RUB_TRIM, Vector3(0, 0, 1))
	k.block(kit, "plastic", Vector3(-2.55, 2.24, hw), Vector3(0.85, 2.36, hw + 0.10), RUB_TRIM)
	# Pop-up sleeping roof (hinged at rear x = -2.62, raised at front x = 0.96 to y = 2.78) + front wind spoiler.
	var px0 := -2.62
	var px1_bot := 0.98
	var px1_top := 0.78
	var py0 := 2.38
	var py_rear := 2.44
	var py_front := 2.78
	var phw := 0.80
	var canvas_col := Color(0.78, 0.73, 0.62)
	var mesh_col := Color(0.16, 0.18, 0.20)
	var spoiler_outline := PackedVector2Array([Vector2(0.98, 2.36), Vector2(1.28, 2.30), Vector2(1.12, 2.42), Vector2(0.96, 2.45)])
	k.extrude(kit, "gloss", spoiler_outline, -phw - 0.04, phw + 0.04, 0.03, RUB_TRIM)
	# Canvas bellows: two side trapezoids and a sloped front wall with a mesh vent window.
	for side: float in [-1.0, 1.0]:
		var pz := phw * side
		var sn := Vector3(0, 0, side)
		k.quad(kit, "canvas", [Vector3(px0, py0, pz), Vector3(px1_bot, py0, pz), Vector3(px1_top, py_front, pz), Vector3(px0, py_rear, pz)], sn, canvas_col)
		var wz := (phw + 0.012) * side
		k.tri(kit, "matte", Vector3(-0.95, 2.43, wz), Vector3(0.25, 2.43, wz), Vector3(-0.30, 2.64, wz), sn, sn, sn, mesh_col, sn)
	var pfn := Vector3(0.40, 0.20, 0.0).normalized()
	k.quad(kit, "canvas", [Vector3(px1_bot, py0, -phw), Vector3(px1_bot, py0, phw), Vector3(px1_top, py_front, phw), Vector3(px1_top, py_front, -phw)], pfn, canvas_col.lightened(0.04))
	k.quad(kit, "matte", [Vector3(0.93, 2.46, -0.46), Vector3(0.93, 2.46, 0.46), Vector3(0.83, 2.70, 0.38), Vector3(0.83, 2.70, -0.38)], pfn, mesh_col)
	# Tilted fiberglass pop-top roof lid above the canvas bellows.
	var lid_n := Vector3(-0.10, 0.995, 0.0).normalized()
	var lid_dir := Vector3(px1_top - px0 + 0.14, py_front - py_rear, 0.0)
	var lid_len := lid_dir.length()
	var lid_xf := Transform3D(Basis(lid_dir / lid_len, lid_n, Vector3.BACK), Vector3((px0 + px1_top) * 0.5 + 0.02, (py_rear + py_front) * 0.5 + 0.025, 0.0))
	k.box(kit, "gloss", lid_xf, Vector3(lid_len + 0.12, 0.06, (phw + 0.06) * 2.0), col)
	# Front bumper, skid plate, grille, headlamps and wing mirrors on arms.
	k.block(kit, "plastic", Vector3(2.82, 0.40, -hw - 0.02), Vector3(3.04, 0.70, hw + 0.02), cladding)
	k.block(kit, "metal", Vector3(2.88, 0.40, -0.48), Vector3(3.06, 0.50, 0.48), GALV)
	k.block(kit, "matte", Vector3(2.90, 0.74, -0.52), Vector3(2.97, 1.02, 0.52), Color(0.09, 0.10, 0.11))
	k.beam(kit, "chrome", Vector3(2.975, 0.88, -0.50), Vector3(2.975, 0.88, 0.50), 0.03, 0.018, Color(0.88, 0.90, 0.92), Vector3.RIGHT)
	k.block(kit, "paint", Vector3(3.03, 0.52, -0.22), Vector3(3.06, 0.61, 0.22), WHITE)
	for sz: float in [-1.0, 1.0]:
		k.block(kit, "plastic", Vector3(2.86, 0.76, sz * 0.72 - 0.16), Vector3(2.96, 1.02, sz * 0.72 + 0.16), RUB_TRIM)
		k.block(kit, "lamp", Vector3(2.90, 0.79, sz * 0.68 - 0.10), Vector3(2.975, 0.99, sz * 0.68 + 0.10), Color(1.0, 0.97, 0.88))
		k.block(kit, "lamp", Vector3(2.90, 0.79, sz * 0.83 - 0.035), Vector3(2.975, 0.99, sz * 0.83 + 0.035), Color(0.98, 0.56, 0.06))
		k.block(kit, "lamp", Vector3(2.98, 0.48, sz * 0.72 - 0.05), Vector3(3.04, 0.55, sz * 0.72 + 0.05), Color(1.0, 0.95, 0.80))
		k.beam(kit, "plastic", Vector3(1.88, 1.48, sz * hw), Vector3(1.94, 1.52, sz * (hw + 0.20)), 0.03, 0.03, RUB_TRIM)
		k.beam(kit, "plastic", Vector3(1.88, 1.66, sz * hw), Vector3(1.94, 1.68, sz * (hw + 0.20)), 0.025, 0.025, RUB_TRIM)
		k.block(kit, "plastic", Vector3(1.90, 1.44, sz * (hw + 0.20) - 0.05), Vector3(1.98, 1.78, sz * (hw + 0.20) + 0.05), RUB_TRIM)
	# Rear barn doors (x = -2.92): twin windows, door shut line, rear ladder, spare tyre, tail lights & bumper.
	var rx := -2.92
	var rn := Vector3(-1, 0, 0)
	k.beam(kit, "plastic", Vector3(rx - 0.015, 0.66, 0.0), Vector3(rx - 0.015, 2.28, 0.0), 0.024, 0.014, RUB_TRIM, rn)
	for sz: float in [-1.0, 1.0]:
		var wz0 := -0.76 if sz < 0.0 else 0.08
		var wz1 := -0.08 if sz < 0.0 else 0.76
		k.quad(kit, "plastic", [Vector3(rx - 0.014, 1.32, wz0 - 0.03), Vector3(rx - 0.014, 1.32, wz1 + 0.03), Vector3(rx - 0.014, 2.04, wz1 + 0.03), Vector3(rx - 0.014, 2.04, wz0 - 0.03)], rn, RUB_TRIM)
		k.quad(kit, "glass", [Vector3(rx - 0.022, 1.36, wz0), Vector3(rx - 0.022, 1.36, wz1), Vector3(rx - 0.022, 2.00, wz1), Vector3(rx - 0.022, 2.00, wz0)], rn, GLASS)
		var tz := sz * 0.88
		k.block(kit, "plastic", Vector3(rx - 0.03, 0.72, tz - 0.075), Vector3(rx, 1.28, tz + 0.075), RUB_TRIM)
		k.block(kit, "lamp", Vector3(rx - 0.042, 0.98, tz - 0.06), Vector3(rx - 0.02, 1.25, tz + 0.06), Color(0.92, 0.08, 0.06))
		k.block(kit, "lamp", Vector3(rx - 0.042, 0.85, tz - 0.06), Vector3(rx - 0.02, 0.96, tz + 0.06), Color(0.98, 0.56, 0.06))
		k.block(kit, "lamp", Vector3(rx - 0.042, 0.74, tz - 0.06), Vector3(rx - 0.02, 0.83, tz + 0.06), WHITE)
	# Rear door ladder (left door) and mounted spare tyre (right door).
	for lz in [-0.62, -0.36]:
		k.tube(kit, "plastic", Vector3(rx - 0.06, 0.74, lz), Vector3(rx - 0.06, 2.22, lz), 0.014, 0.014, 5, RUB_TRIM)
	for ry in [0.88, 1.16, 1.44, 1.72, 2.00]:
		k.tube(kit, "plastic", Vector3(rx - 0.06, ry, -0.62), Vector3(rx - 0.06, ry, -0.36), 0.011, 0.011, 5, RUB_TRIM)
	var sp_ab := Basis(Vector3.BACK, PI * 0.5)
	k.tyre(kit, "rubber", Vector3(rx - 0.13, 1.06, 0.42), 0.18, 0.34, 0.20, 16, TYRE, sp_ab)
	k.lathe(kit, "metal", Vector3(rx - 0.21, 1.06, 0.42), [Vector2(0.19, 0.0), Vector2(0.0, 0.02)], 10, Color(0.25, 0.26, 0.28), false, sp_ab)
	k.block(kit, "plastic", Vector3(rx - 0.12, 0.44, -hw), Vector3(rx + 0.04, 0.68, hw), cladding)
	k.block(kit, "paint", Vector3(rx - 0.14, 0.51, -0.52), Vector3(rx - 0.11, 0.61, -0.12), Color(0.96, 0.82, 0.16))
	_wheel(kit, Vector3(1.88, 0.37, -hw + 0.10), 0.37, 0.23, -1.0, hw, cladding)
	_wheel(kit, Vector3(1.88, 0.37, hw - 0.10), 0.37, 0.23, 1.0, hw, cladding)
	_wheel(kit, Vector3(-1.72, 0.37, -hw + 0.10), 0.37, 0.23, -1.0, hw, cladding)
	_wheel(kit, Vector3(-1.72, 0.37, hw - 0.10), 0.37, 0.23, 1.0, hw, cladding)
	return Vector3(6.1, 3.0, 2.1)


## Overland 4x4 SUV: muscular body with matte wheel flares and rock sliders, bullbar and skid plate,
## safari snorkel, framed windows with pillars, expedition roof rack with rooftop box and jerrycans,
## and tailgate-mounted spare wheel.
func _suv(kit: Dictionary, col: Color) -> Vector3:
	var k := _kit
	var hw := 0.94
	var cladding := Color(0.13, 0.14, 0.16)
	# Underbody chassis and rock-slider side steps.
	k.block(kit, "matte", Vector3(-2.05, 0.34, -0.72), Vector3(2.05, 0.50, 0.72), CHASSIS_DARK)
	for side in [-1.0, 1.0]:
		k.tube(kit, "plastic", Vector3(-0.86, 0.40, (hw + 0.04) * side), Vector3(0.88, 0.40, (hw + 0.04) * side), 0.032, 0.032, 6, cladding)
	# Body shell: windscreen plane from (1.44, 1.12) to (0.76, 1.70); rear window from (-1.96, 1.74) to (-2.28, 1.20).
	var outline := _arched([
		Vector2(-2.30, 0.46), Vector2(2.26, 0.46), Vector2(2.38, 0.62), Vector2(2.34, 0.98),
		Vector2(1.44, 1.12), Vector2(0.76, 1.70), Vector2(-1.96, 1.74), Vector2(-2.28, 1.20), Vector2(-2.34, 0.88)
	], [1.42, -1.38], 0.39, 0.46)
	k.extrude(kit, "gloss", outline, -hw, hw, 0.11, col)
	_stripe(kit, -0.88, 0.88, 0.46, 0.64, hw, cladding, "paint")
	_stripe(kit, -2.25, 2.10, 1.02, 1.06, hw, Color(0.85, 0.86, 0.88))
	# Framed windscreen and wipers; framed rear tailgate window.
	var wn := Vector3(0.58, 0.68, 0.0).normalized()
	var wb0 := Vector3(1.44, 1.12, -hw + 0.12) + wn * 0.022
	var wb1 := Vector3(1.44, 1.12, hw - 0.12) + wn * 0.022
	var wt1 := Vector3(0.76, 1.70, hw - 0.14) + wn * 0.022
	var wt0 := Vector3(0.76, 1.70, -hw + 0.14) + wn * 0.022
	k.quad(kit, "glass", [wb0, wb1, wt1, wt0], wn, GLASS)
	for edge in [[wb0, wb1], [wt0, wt1], [wb0, wt0], [wb1, wt1]]:
		k.beam(kit, "plastic", (edge[0] as Vector3) + wn * 0.008, (edge[1] as Vector3) + wn * 0.008, 0.038, 0.018, RUB_TRIM, wn)
	var rn := Vector3(-0.54, 0.32, 0.0).normalized()
	var rb0 := Vector3(-2.26, 1.24, -0.72) + rn * 0.022
	var rb1 := Vector3(-2.26, 1.24, 0.72) + rn * 0.022
	var rt1 := Vector3(-1.98, 1.70, 0.66) + rn * 0.022
	var rt0 := Vector3(-1.98, 1.70, -0.66) + rn * 0.022
	k.quad(kit, "glass", [rb0, rb1, rt1, rt0], rn, GLASS)
	for edge in [[rb0, rb1], [rt0, rt1], [rb0, rt0], [rb1, rt1]]:
		k.beam(kit, "plastic", (edge[0] as Vector3) + rn * 0.008, (edge[1] as Vector3) + rn * 0.008, 0.036, 0.018, RUB_TRIM, rn)
	# Three distinct framed side windows per side (front door, rear door, cargo quarter).
	var win_front := PackedVector2Array([Vector2(0.08, 1.15), Vector2(1.32, 1.13), Vector2(0.76, 1.62), Vector2(0.08, 1.63)])
	for side in [-1.0, 1.0]:
		_framed_poly_window(kit, win_front, hw - 0.02, side)
		_hab_window(kit, -0.98, -0.06, 1.15, 1.64, hw - 0.02, side, 0.0, false)
		_hab_window(kit, -1.96, -1.14, 1.16, 1.65, hw - 0.02, side, 0.0, false)
		for hx in [0.22, -0.82]:
			k.block(kit, "plastic", Vector3(hx, 1.04, (hw - 0.01) * side), Vector3(hx + 0.14, 1.08, (hw + 0.025) * side), RUB_TRIM)
		k.beam(kit, "plastic", Vector3(0.96, 1.16, side * (hw - 0.01)), Vector3(1.02, 1.20, side * (hw + 0.16)), 0.028, 0.028, RUB_TRIM)
		k.block(kit, "plastic", Vector3(0.96, 1.14, side * (hw + 0.16) - 0.045), Vector3(1.06, 1.32, side * (hw + 0.16) + 0.045), RUB_TRIM)
	# Safari snorkel along the right A-pillar.
	k.tube(kit, "plastic", Vector3(1.52, 1.08, hw + 0.02), Vector3(1.24, 1.12, hw + 0.04), 0.032, 0.032, 6, RUB_TRIM)
	k.tube(kit, "plastic", Vector3(1.24, 1.12, hw + 0.04), Vector3(0.76, 1.78, hw + 0.02), 0.032, 0.030, 6, RUB_TRIM)
	k.block(kit, "plastic", Vector3(0.70, 1.76, hw - 0.02), Vector3(0.84, 1.84, hw + 0.06), RUB_TRIM)
	# Front winch bumper, bullbar hoop, spotlights, skid plate, grille and headlamps.
	k.block(kit, "plastic", Vector3(2.26, 0.42, -hw - 0.02), Vector3(2.48, 0.68, hw + 0.02), cladding)
	k.block(kit, "metal", Vector3(2.22, 0.36, -0.46), Vector3(2.46, 0.45, 0.46), GALV)
	k.tube(kit, "steel", Vector3(2.44, 0.66, -0.44), Vector3(2.40, 1.02, -0.36), 0.026, 0.026, 6, cladding)
	k.tube(kit, "steel", Vector3(2.44, 0.66, 0.44), Vector3(2.40, 1.02, 0.36), 0.026, 0.026, 6, cladding)
	k.tube(kit, "steel", Vector3(2.40, 1.02, -0.36), Vector3(2.40, 1.02, 0.36), 0.026, 0.026, 6, cladding)
	for spz in [-0.18, 0.18]:
		k.tube(kit, "plastic", Vector3(2.40, 0.76, spz), Vector3(2.46, 0.76, spz), 0.065, 0.065, 10, RUB_TRIM)
		k.tube(kit, "lamp", Vector3(2.46, 0.76, spz), Vector3(2.47, 0.76, spz), 0.052, 0.052, 10, Color(1.0, 0.96, 0.84))
	k.block(kit, "matte", Vector3(2.30, 0.70, -0.52), Vector3(2.37, 0.96, 0.52), Color(0.08, 0.09, 0.10))
	for gy in [0.76, 0.84, 0.91]:
		k.beam(kit, "metal", Vector3(2.375, gy, -0.48), Vector3(2.375, gy, 0.48), 0.022, 0.016, GALV, Vector3.RIGHT)
	for sz: float in [-1.0, 1.0]:
		k.block(kit, "plastic", Vector3(2.28, 0.72, sz * 0.68 - 0.17), Vector3(2.36, 0.95, sz * 0.68 + 0.17), RUB_TRIM)
		k.block(kit, "lamp", Vector3(2.32, 0.75, sz * 0.64 - 0.10), Vector3(2.375, 0.92, sz * 0.64 + 0.10), Color(1.0, 0.97, 0.88))
		k.block(kit, "lamp", Vector3(2.32, 0.75, sz * 0.79 - 0.04), Vector3(2.375, 0.92, sz * 0.79 + 0.04), Color(0.98, 0.56, 0.06))
		# Rear tail lights.
		var tz := sz * 0.78
		k.block(kit, "plastic", Vector3(-2.36, 0.74, tz - 0.09), Vector3(-2.30, 1.18, tz + 0.09), RUB_TRIM)
		k.block(kit, "lamp", Vector3(-2.375, 0.96, tz - 0.07), Vector3(-2.35, 1.15, tz + 0.07), Color(0.92, 0.08, 0.06))
		k.block(kit, "lamp", Vector3(-2.375, 0.84, tz - 0.07), Vector3(-2.35, 0.94, tz + 0.07), Color(0.98, 0.56, 0.06))
		k.block(kit, "lamp", Vector3(-2.375, 0.76, tz - 0.07), Vector3(-2.35, 0.83, tz + 0.07), WHITE)
	# Rear bumper, license plate and tailgate-mounted full-size spare tyre.
	k.block(kit, "plastic", Vector3(-2.40, 0.44, -hw - 0.01), Vector3(-2.26, 0.68, hw + 0.01), cladding)
	k.block(kit, "paint", Vector3(-2.42, 0.52, -0.58), Vector3(-2.39, 0.61, -0.18), Color(0.96, 0.82, 0.16))
	var sp_ab := Basis(Vector3.BACK, PI * 0.5)
	var sp_c := Vector3(-2.44, 0.96, 0.20)
	k.tyre(kit, "rubber", sp_c, 0.20, 0.37, 0.22, 16, TYRE, sp_ab)
	k.lathe(kit, "metal", sp_c + Vector3(-0.08, 0, 0), [Vector2(0.21, 0.0), Vector2(0.0, 0.02)], 10, GALV, false, sp_ab)
	# Expedition roof rack with LED bar, rooftop cargo box, jerrycans and rolled side awning.
	for rx2 in [-1.85, -0.70, 0.40]:
		for sz in [-1.0, 1.0]:
			k.block(kit, "plastic", Vector3(rx2 - 0.04, 1.72, sz * 0.68 - 0.03), Vector3(rx2 + 0.04, 1.82, sz * 0.68 + 0.03), RUB_TRIM)
	for sz in [-1.0, 1.0]:
		k.tube(kit, "plastic", Vector3(-1.95, 1.82, sz * 0.68), Vector3(0.52, 1.82, sz * 0.68), 0.018, 0.018, 6, RUB_TRIM)
		k.tube(kit, "plastic", Vector3(-1.95, 1.90, sz * 0.68), Vector3(0.52, 1.90, sz * 0.68), 0.016, 0.016, 6, RUB_TRIM)
	for rx3 in [-1.95, -1.35, -0.75, -0.15, 0.52]:
		k.beam(kit, "plastic", Vector3(rx3, 1.82, -0.68), Vector3(rx3, 1.82, 0.68), 0.03, 0.016, RUB_TRIM, Vector3.UP)
	k.block(kit, "lamp", Vector3(0.50, 1.83, -0.48), Vector3(0.55, 1.89, 0.48), Color(1.0, 0.97, 0.88))
	# Rooftop aerodynamic cargo box (left side) and twin expedition jerrycans (right side).
	var box_outline := PackedVector2Array([Vector2(-1.82, 1.83), Vector2(0.35, 1.83), Vector2(0.42, 1.92), Vector2(0.10, 2.08), Vector2(-1.68, 2.08), Vector2(-1.85, 1.95)])
	k.extrude(kit, "gloss", box_outline, -0.62, -0.06, 0.05, Color(0.14, 0.15, 0.17))
	for jx in [-1.55, -1.15]:
		k.block(kit, "paint", Vector3(jx - 0.16, 1.83, 0.12), Vector3(jx + 0.16, 2.12, 0.54), Color(0.78, 0.14, 0.10))
	k.block(kit, "plastic", Vector3(-0.85, 1.83, 0.08), Vector3(0.25, 2.02, 0.58), Color(0.58, 0.52, 0.38))
	k.tube(kit, "canvas", Vector3(-1.95, 1.84, 0.74), Vector3(0.48, 1.84, 0.74), 0.055, 0.055, 8, Color(0.22, 0.23, 0.25))
	_wheel(kit, Vector3(1.42, 0.39, -hw + 0.11), 0.39, 0.25, -1.0, hw, cladding)
	_wheel(kit, Vector3(1.42, 0.39, hw - 0.11), 0.39, 0.25, 1.0, hw, cladding)
	_wheel(kit, Vector3(-1.38, 0.39, -hw + 0.11), 0.39, 0.25, -1.0, hw, cladding)
	_wheel(kit, Vector3(-1.38, 0.39, hw - 0.11), 0.39, 0.25, 1.0, hw, cladding)
	return Vector3(4.9, 2.1, 2.0)


## A side outline with wheel arches: the first two points are the bottom edge (rear to front); a
## half-round notch of radius `r` round each wheel centre x in `wheels` (at height `hub`) is cut up
## into it.
static func _arched(pts: Array, wheels: Array, hub: float, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(pts[0])
	var xs: Array = wheels.duplicate()
	xs.sort()
	var y_bot: float = (pts[0] as Vector2).y
	for wx in xs:
		var c := Vector2(float(wx), hub)
		var dy := y_bot - hub
		var half := sqrt(maxf(r * r - dy * dy, 0.0))
		var a0 := atan2(dy, -half)
		var a1 := atan2(dy, half)
		var steps := 10
		var span := fposmod(a0 - a1, TAU)
		for k in range(steps + 1):
			var a := a0 - span * k / steps
			out.append(c + Vector2(cos(a), sin(a)) * r)
	for i in range(1, pts.size()):
		out.append(pts[i])
	return out


## A rounded rectangle polygon (x0..x1, y0..y1), corner radius r.
static func _rrect(x0: float, x1: float, y0: float, y1: float, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cs := [Vector2(x1 - r, y0 + r), Vector2(x1 - r, y1 - r), Vector2(x0 + r, y1 - r), Vector2(x0 + r, y0 + r)]
	for i in range(4):
		var c: Vector2 = cs[i]
		for j in range(4):
			var a := -PI * 0.5 + PI * 0.5 * i + PI * 0.5 * j / 3.0
			out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## Geodesic dome tent at life size: dark bathtub groundsheet, inner tent peeking under a scalloped
## two-tone rainfly, crossed external pole sleeves, side vents, guy lines, and a pointed front
## vestibule (-z) with one flap rolled back to show a sleeping pad and sleeping bag inside.
func dome_tent(kit: Dictionary, fly: Color, inner: Color) -> void:
	var k := _kit
	var segs := 16
	var r_base := 1.32
	var h_top := 1.32
	var tub_col := Color(0.11, 0.12, 0.14)
	var dark_in := Color(0.06, 0.07, 0.08)
	var cap_col := inner.lerp(fly.lightened(0.18), 0.45)
	# 1. Bathtub groundsheet and full inner tent dome visible under the scalloped rainfly.
	k.lathe(kit, "matte", Vector3.ZERO, [Vector2(r_base, 0.0), Vector2(r_base, 0.13), Vector2(r_base * 0.94, 0.14)], segs, tub_col)
	k.lathe(kit, "canvas", Vector3.ZERO, [
		Vector2(r_base * 0.94, 0.11), Vector2(r_base * 0.89, 0.44),
		Vector2(r_base * 0.72, 0.78), Vector2(r_base * 0.44, 1.04), Vector2(0.0, 1.22)
	], segs, inner)
	# 2. Scalloped geodesic rainfly dome over the rear/side sectors (leaving the 2 front sectors at -z open for the vestibule).
	var rings := [[1.35, 0.16], [1.28, 0.46], [1.06, 0.80], [0.70, 1.08], [0.32, 1.25], [0.0, h_top]]
	for j in range(segs):
		var a0 := TAU * j / segs
		var a1 := TAU * (j + 1) / segs
		var is_front := (j == 11 or j == 12)
		var u0 := Vector3(cos(a0), 0, sin(a0))
		var u1 := Vector3(cos(a1), 0, sin(a1))
		# Catenary scallop lift on the bottom hem.
		var lift0 := 0.08 * absf(sin(a0 * 2.0))
		var lift1 := 0.08 * absf(sin(a1 * 2.0))
		for ri in range(rings.size() - 1):
			if is_front and ri < 2:
				continue
			var r0: float = rings[ri][0]
			var y0: float = rings[ri][1] + (lift0 if ri == 0 else 0.0)
			var y0b: float = rings[ri][1] + (lift1 if ri == 0 else 0.0)
			var r1: float = rings[ri + 1][0]
			var y1: float = rings[ri + 1][1]
			var p00 := u0 * r0 + Vector3(0, y0, 0)
			var p01 := u1 * r0 + Vector3(0, y0b, 0)
			var p10 := u0 * r1 + Vector3(0, y1, 0)
			var p11 := u1 * r1 + Vector3(0, y1, 0)
			var n0 := (u0 * 0.75 + Vector3(0, 0.65, 0)).normalized()
			var n1 := (u1 * 0.75 + Vector3(0, 0.65, 0)).normalized()
			var out := ((u0 + u1) * 0.5 + Vector3(0, 0.65, 0)).normalized()
			var col_r: Color = cap_col if ri >= 3 else fly
			k.tri(kit, "canvas", p00, p01, p11, n0, n1, n1, col_r, out)
			if r1 > 1e-4:
				k.tri(kit, "canvas", p00, p11, p10, n0, n1, n0, col_r, out)
	# 3. Crossed external aluminium pole sleeves (2 diagonal main arches across the dome) and side vents.
	var pole_col := Color(0.20, 0.22, 0.24)
	for a in [PI * 0.25, PI * 0.75]:
		var dir := Vector3(cos(a), 0, sin(a))
		var prev := Vector3.ZERO
		for i in range(15):
			var t := -1.0 + 2.0 * i / 14.0
			var r := absf(t)
			var y := 0.14 + (h_top - 0.12) * sqrt(maxf(1.0 - r * r * 0.92, 0.0))
			var p := dir * (t * 1.36) + Vector3(0, y, 0)
			if i > 0:
				k.tube(kit, "metal", prev, p, 0.015, 0.015, 5, pole_col)
			prev = p
	for sx: float in [-1.0, 1.0]:
		var vx := sx * 1.08
		var vn := Vector3(sx, 0.45, 0).normalized()
		k.tri(kit, "canvas", Vector3(vx, 0.86, 0.0), Vector3(vx + sx * 0.18, 0.64, -0.24), Vector3(vx + sx * 0.18, 0.64, 0.24), vn, vn, vn, cap_col, vn)
	# 4. Pointed front vestibule (-z) seamlessly stitched to the open front arch (j = 11..13, ri = 0..2).
	var a_l := TAU * 11.0 / segs
	var a_r := TAU * 13.0 / segs
	var u_l := Vector3(cos(a_l), 0, sin(a_l))
	var u_r := Vector3(cos(a_r), 0, sin(a_r))
	var lift_l := 0.08 * absf(sin(a_l * 2.0))
	var lift_r := 0.08 * absf(sin(a_r * 2.0))
	var v_l := u_l * 1.35 + Vector3(0, 0.16 + lift_l, 0)
	var v_ml := u_l * 1.28 + Vector3(0, 0.46, 0)
	var v_tl := u_l * 1.06 + Vector3(0, 0.80, 0)
	var v_r := u_r * 1.35 + Vector3(0, 0.16 + lift_r, 0)
	var v_mr := u_r * 1.28 + Vector3(0, 0.46, 0)
	var v_tr := u_r * 1.06 + Vector3(0, 0.80, 0)
	var v_top := Vector3(0.0, 0.80, -1.06)
	var v_apex := Vector3(0.0, 0.05, -1.96)
	# Vestibule groundsheet, dark zipped inner mesh door, and sleeping pad/bag peeking out.
	k.tri(kit, "matte", Vector3(v_l.x, 0.02, v_l.z), v_apex, Vector3(v_r.x, 0.02, v_r.z), Vector3.UP, Vector3.UP, Vector3.UP, tub_col, Vector3.UP)
	k.tri(kit, "matte", v_l * 0.88, v_top + Vector3(0, -0.02, 0.08), v_r * 0.88, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, dark_in, Vector3.FORWARD)
	k.block(kit, "canvas", Vector3(-0.18, 0.06, -1.25), Vector3(0.36, 0.12, -0.55), Color(0.18, 0.55, 0.78))
	k.block(kit, "canvas", Vector3(-0.14, 0.12, -1.10), Vector3(0.32, 0.23, -0.58), inner.lightened(0.08))
	# Left vestibule wing (closed, stitched to v_l -> v_ml -> v_tl -> v_top).
	var nl := (v_apex - v_l).cross(v_top - v_l).normalized()
	if nl.y < 0.0:
		nl = -nl
	for tri_pts in [[v_l, v_apex, v_ml], [v_ml, v_apex, v_tl], [v_tl, v_apex, v_top]]:
		k.tri(kit, "canvas", tri_pts[0], tri_pts[1], tri_pts[2], nl, nl, nl, fly.lightened(0.04), nl)
		k.tri(kit, "canvas", tri_pts[0], tri_pts[2], tri_pts[1], -nl, -nl, -nl, fly.darkened(0.28), -nl)
	# Right vestibule wing (stitched to v_top -> v_tr -> v_mr -> v_r, with front door flap rolled back).
	var v_beak_r := v_apex.lerp(v_r, 0.52)
	var nr := (v_r - v_apex).cross(v_top - v_apex).normalized()
	if nr.y < 0.0:
		nr = -nr
	for tri_pts2 in [[v_top, v_beak_r, v_tr], [v_tr, v_beak_r, v_mr], [v_mr, v_beak_r, v_r]]:
		k.tri(kit, "canvas", tri_pts2[0], tri_pts2[1], tri_pts2[2], nr, nr, nr, fly, nr)
		k.tri(kit, "canvas", tri_pts2[0], tri_pts2[2], tri_pts2[1], -nr, -nr, -nr, fly.darkened(0.28), -nr)
	k.tube(kit, "canvas", v_top + Vector3(0.02, -0.02, -0.02), v_beak_r + Vector3(0.0, 0.04, -0.02), 0.034, 0.042, 7, cap_col)
	# 5. Taut guy lines and angled pegs.
	var cord := Color(0.92, 0.82, 0.18)
	for g in [
		[Vector3(0, 0.94, -0.96), Vector3(0, 0.0, -2.25)],
		[Vector3(-1.14, 0.64, -0.45), Vector3(-1.68, 0.0, -0.68)],
		[Vector3(1.14, 0.64, -0.45), Vector3(1.68, 0.0, -0.68)],
		[Vector3(-1.14, 0.64, 0.55), Vector3(-1.68, 0.0, 0.78)],
		[Vector3(1.14, 0.64, 0.55), Vector3(1.68, 0.0, 0.78)],
		[Vector3(0, 0.72, 1.18), Vector3(0, 0.0, 1.78)],
	]:
		var a: Vector3 = g[0]
		var b: Vector3 = g[1]
		k.tube(kit, "matte", a, b, 0.006, 0.006, 4, cord)
		k.tube(kit, "metal", b + Vector3(0, 0.08, 0), b - Vector3(0, 0.04, 0), 0.012, 0.008, 4, GALV)


## A 3-hoop family tunnel tent at life size: arched pole hoops with tensioned fabric bays between
## them, clear PVC camp windows on the sides, a front porch awning on two upright poles, and an
## inner cabin doorway with camping mat inside.
func tunnel_tent(kit: Dictionary, fly: Color, accent: Color) -> void:
	var k := _kit
	var hw := 1.15
	var h := 1.48
	var hoops_z := [-1.20, 0.20, 1.60]
	var n_pts := 12
	var tub_col := Color(0.11, 0.12, 0.14)
	var pole_col := Color(0.18, 0.20, 0.22)
	var under := fly.darkened(0.30)
	# Arch profile helper: t in [0..1] from right foot (+hw) over crown to left foot (-hw).
	var arch_pt := func(t: float, z: float, r_scale := 1.0, sag := 0.0) -> Vector3:
		var a := PI * t
		var x := cos(a) * hw * r_scale
		var y := 0.14 + pow(sin(a), 0.78) * (h - 0.14) * r_scale - sag * sin(a)
		return Vector3(x, y, z)
	# 1. Bathtub groundsheet under the tunnel body.
	k.block(kit, "matte", Vector3(-hw, 0.0, hoops_z[0]), Vector3(hw, 0.14, hoops_z[2]), tub_col)
	# 2. Tunnel bays between the 3 arched hoops (with mid-bay catenary dip) and external pole sleeves.
	for hi in range(hoops_z.size()):
		var hz: float = hoops_z[hi]
		for i in range(n_pts):
			var p0: Vector3 = arch_pt.call(float(i) / n_pts, hz, 1.015, 0.0)
			var p1: Vector3 = arch_pt.call(float(i + 1) / n_pts, hz, 1.015, 0.0)
			k.tube(kit, "metal", p0, p1, 0.018, 0.018, 5, pole_col)
		if hi == hoops_z.size() - 1:
			break
		var z0: float = hoops_z[hi]
		var z1: float = hoops_z[hi + 1]
		var zm := (z0 + z1) * 0.5
		for sub in [[z0, zm, 0.0, 0.038], [zm, z1, 0.038, 0.0]]:
			var za: float = sub[0]
			var zb: float = sub[1]
			var sa: float = sub[2]
			var sb: float = sub[3]
			for i in range(n_pts):
				var t0 := float(i) / n_pts
				var t1 := float(i + 1) / n_pts
				var a0: Vector3 = arch_pt.call(t0, za, 1.0, sa)
				var a1: Vector3 = arch_pt.call(t1, za, 1.0, sa)
				var b0: Vector3 = arch_pt.call(t0, zb, 1.0, sb)
				var b1: Vector3 = arch_pt.call(t1, zb, 1.0, sb)
				var out := Vector3(cos(PI * (t0 + t1) * 0.5), sin(PI * (t0 + t1) * 0.5), 0.0).normalized()
				var col_p: Color = accent if (i == 0 or i == n_pts - 1) else fly
				k.panel(kit, "canvas", [a0, a1, b1, b0], out, col_p, under)
	# 3. Side PVC camp windows on the front bay (both sides).
	for side in [-1.0, 1.0]:
		var t_bot := 0.10 if side > 0.0 else 0.90
		var t_top := 0.25 if side > 0.0 else 0.75
		var p_b0: Vector3 = arch_pt.call(t_bot, -0.95, 1.018, 0.02)
		var p_b1: Vector3 = arch_pt.call(t_bot, -0.05, 1.018, 0.02)
		var p_t1: Vector3 = arch_pt.call(t_top, -0.05, 1.018, 0.02)
		var p_t0: Vector3 = arch_pt.call(t_top, -0.95, 1.018, 0.02)
		var wn := Vector3(side, 0.32, 0).normalized()
		k.quad(kit, "glass", [p_b0, p_b1, p_t1, p_t0], wn, Color(0.12, 0.20, 0.30, 0.78))
		for edge in [[p_b0, p_b1], [p_t0, p_t1], [p_b0, p_t0], [p_b1, p_t1], [p_b0.lerp(p_b1, 0.5), p_t0.lerp(p_t1, 0.5)]]:
			k.beam(kit, "canvas", (edge[0] as Vector3) + wn * 0.008, (edge[1] as Vector3) + wn * 0.008, 0.028, 0.014, WHITE, wn)
	# 4. Sloped rear vestibule hood (z = 1.60 .. 2.08).
	var rear_base := Vector3(0, 0.14, 2.08)
	for i in range(n_pts):
		var a0: Vector3 = arch_pt.call(float(i) / n_pts, hoops_z[2], 1.0, 0.0)
		var a1: Vector3 = arch_pt.call(float(i + 1) / n_pts, hoops_z[2], 1.0, 0.0)
		var b0 := Vector3(a0.x * 0.65, 0.14, 2.05)
		var b1 := Vector3(a1.x * 0.65, 0.14, 2.05)
		var rn := Vector3((a0.x + a1.x) * 0.3, 0.5, 1.0).normalized()
		k.quad(kit, "canvas", [a0, a1, b1, b0], rn, fly.darkened(0.06))
	k.quad(kit, "canvas", [Vector3(-hw * 0.65, 0.14, 2.05), Vector3(hw * 0.65, 0.14, 2.05), Vector3(0.35, 0.65, 1.60), Vector3(-0.35, 0.65, 1.60)], Vector3.BACK, accent)
	# 5. Inner front cabin wall at z = -1.20 with arched mesh door, rolled flap and sleeping gear.
	var fz: float = hoops_z[0]
	var fc := Vector3(0, 0.14, fz)
	var inner_col := Color(0.93, 0.89, 0.78)
	for i in range(n_pts):
		var a0: Vector3 = arch_pt.call(float(i) / n_pts, fz, 0.99, 0.0)
		var a1: Vector3 = arch_pt.call(float(i + 1) / n_pts, fz, 0.99, 0.0)
		k.tri(kit, "canvas", fc, a0, a1, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, inner_col, Vector3.FORWARD)
	k.quad(kit, "matte", [Vector3(-0.46, 0.14, fz - 0.015), Vector3(0.46, 0.14, fz - 0.015), Vector3(0.38, 1.12, fz - 0.015), Vector3(-0.38, 1.12, fz - 0.015)], Vector3.FORWARD, Color(0.08, 0.09, 0.11))
	for edge in [[-0.46, 0.14, -0.38, 1.12], [-0.38, 1.12, 0.38, 1.12], [0.38, 1.12, 0.46, 0.14]]:
		k.beam(kit, "canvas", Vector3(float(edge[0]), float(edge[1]), fz - 0.022), Vector3(float(edge[2]), float(edge[3]), fz - 0.022), 0.026, 0.014, WHITE, Vector3.FORWARD)
	k.tube(kit, "canvas", Vector3(0.41, 1.08, fz - 0.04), Vector3(0.48, 0.22, fz - 0.04), 0.06, 0.07, 7, fly.lightened(0.12))
	k.block(kit, "canvas", Vector3(-0.32, 0.14, fz - 0.01), Vector3(0.32, 0.24, fz + 0.65), Color(0.16, 0.48, 0.76))
	# Woven front porch mat flush with the ground.
	k.block(kit, "canvas", Vector3(-0.78, 0.004, fz - 0.78), Vector3(0.78, 0.016, fz - 0.02), Color(0.32, 0.36, 0.34))
	# 6. Extended front porch canopy & side windbreak wings supported on two upright poles.
	var pz_out := -2.12
	var py_out := 1.28
	for i in range(2, n_pts - 2):
		var t0 := float(i) / n_pts
		var t1 := float(i + 1) / n_pts
		var a0: Vector3 = arch_pt.call(t0, fz, 1.0, 0.0)
		var a1: Vector3 = arch_pt.call(t1, fz, 1.0, 0.0)
		var b0 := Vector3(a0.x * 0.94, 0.32 + (a0.y - 0.14) * 0.76, pz_out)
		var b1 := Vector3(a1.x * 0.94, 0.32 + (a1.y - 0.14) * 0.76, pz_out)
		var out := Vector3(cos(PI * (t0 + t1) * 0.5), sin(PI * (t0 + t1) * 0.5), -0.15).normalized()
		k.panel(kit, "canvas", [a0, a1, b1, b0], out, fly, under)
	var cord := Color(0.92, 0.82, 0.18)
	for sx: float in [-1.0, 1.0]:
		var t_edge := 2.0 / n_pts if sx > 0.0 else 1.0 - 2.0 / n_pts
		var p_in: Vector3 = arch_pt.call(t_edge, fz, 1.0, 0.0)
		var pt := Vector3(p_in.x * 0.94, 0.32 + (p_in.y - 0.14) * 0.76, pz_out)
		var p_foot := Vector3(sx * hw, 0.14, fz)
		var wn := Vector3(sx, 0.35, -0.15).normalized()
		k.tri(kit, "canvas", p_in, pt, p_foot, wn, wn, wn, accent, wn)
		k.tri(kit, "canvas", p_in, p_foot, pt, -wn, -wn, -wn, under, -wn)
		k.tube(kit, "metal", Vector3(pt.x, 0.0, pz_out), pt + Vector3(0, 0.04, 0), 0.015, 0.015, 6, GALV)
		var g1 := Vector3(sx * 1.35, 0.0, pz_out - 0.55)
		var g2 := Vector3(sx * 1.48, 0.0, pz_out + 0.25)
		k.tube(kit, "matte", pt, g1, 0.006, 0.006, 4, cord)
		k.tube(kit, "matte", pt, g2, 0.006, 0.006, 4, cord)
		k.tube(kit, "metal", g1 + Vector3(0, 0.07, 0), g1 - Vector3(0, 0.03, 0), 0.011, 0.008, 4, GALV)
	for hz in hoops_z:
		for sx in [-1.0, 1.0]:
			var hp: Vector3 = arch_pt.call(0.18 if sx > 0.0 else 0.82, hz, 1.0, 0.0)
			var gp := Vector3(sx * (hw + 0.48), 0.0, hz)
			k.tube(kit, "matte", hp, gp, 0.006, 0.006, 4, cord)


## Classic A-frame ridge tent at life size: bathtub floor, vertical canvas side walls, pitched inner
## tent with tied-back front gable doors showing a sleeping bag inside, and an overhanging tensioned
## rainfly staked out on guy ropes.
func ridge_tent(kit: Dictionary, fly: Color, inner: Color) -> void:
	var k := _kit
	var hw := 1.04
	var hl := 1.34
	var y_wall := 0.42
	var y_ridge := 1.36
	var tub_col := Color(0.11, 0.12, 0.14)
	var dark_in := Color(0.06, 0.07, 0.08)
	var under := fly.darkened(0.30)
	# 1. Bathtub groundsheet and inner tent vertical walls + gable ends.
	k.block(kit, "matte", Vector3(-hw, 0.0, -hl), Vector3(hw, 0.13, hl), tub_col)
	k.block(kit, "canvas", Vector3(-hw + 0.02, 0.13, -hl + 0.02), Vector3(hw - 0.02, y_wall, hl - 0.02), inner)
	# Rear gable triangle and front gable doorway with tied-back canvas doors and bedroll inside.
	var r_l := Vector3(-hw + 0.02, y_wall, hl - 0.02)
	var r_r := Vector3(hw - 0.02, y_wall, hl - 0.02)
	var r_t := Vector3(0.0, y_ridge - 0.04, hl - 0.02)
	k.tri(kit, "canvas", r_l, r_r, r_t, Vector3.BACK, Vector3.BACK, Vector3.BACK, inner.darkened(0.06), Vector3.BACK)
	var f_l := Vector3(-hw + 0.02, 0.13, -hl + 0.008)
	var f_r := Vector3(hw - 0.02, 0.13, -hl + 0.008)
	var f_t := Vector3(0.0, y_ridge - 0.04, -hl + 0.008)
	k.tri(kit, "matte", f_l, f_t, f_r, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, dark_in, Vector3.FORWARD)
	for sx: float in [-1.0, 1.0]:
		var edge_a := Vector3(sx * (hw - 0.02), 0.13, -hl)
		var edge_b := Vector3(sx * (hw - 0.02), y_wall, -hl)
		var edge_top := Vector3(0.0, y_ridge - 0.04, -hl)
		var edge_in := Vector3(sx * 0.42, 0.13, -hl)
		k.tri(kit, "canvas", edge_a, edge_b, edge_top, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, inner, Vector3.FORWARD)
		k.tri(kit, "canvas", edge_a, edge_top, edge_in, Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, inner, Vector3.FORWARD)
		k.tube(kit, "canvas", edge_top.lerp(edge_a, 0.22) + Vector3(0, 0, -0.02), edge_in + Vector3(0, 0.06, -0.03), 0.055, 0.075, 6, fly.lightened(0.10))
	# Sleeping pad, quilted sleeping bag and pillow inside.
	k.block(kit, "canvas", Vector3(-0.36, 0.13, -hl + 0.12), Vector3(0.36, 0.24, 0.65), fly.lightened(0.15))
	k.block(kit, "canvas", Vector3(-0.26, 0.24, 0.18), Vector3(0.26, 0.34, 0.56), WHITE)
	# 2. Overhanging rainfly suspended above the inner tent with catenary sag between guy points.
	var fw := 1.26
	var fl := 1.48
	var fy_eave := 0.36
	var fy_ridge := 1.42
	var nz := 6
	for side in [-1.0, 1.0]:
		var out_n := Vector3(side * (fy_ridge - fy_eave), fw, 0.0).normalized()
		for i in range(nz):
			var t0 := float(i) / nz
			var t1 := float(i + 1) / nz
			var z0 := lerpf(-fl, fl, t0)
			var z1 := lerpf(-fl, fl, t1)
			var sag0 := 0.045 * sin(PI * t0)
			var sag1 := 0.045 * sin(PI * t1)
			var sc0 := 0.03 * absf(sin(PI * t0 * 3.0))
			var sc1 := 0.03 * absf(sin(PI * t1 * 3.0))
			var r0 := Vector3(0.0, fy_ridge - sag0, z0)
			var r1 := Vector3(0.0, fy_ridge - sag1, z1)
			var e0 := Vector3(side * fw, fy_eave + sc0, z0)
			var e1 := Vector3(side * fw, fy_eave + sc1, z1)
			k.panel(kit, "canvas", [r0, r1, e1, e0], out_n, fly, under)
	k.beam(kit, "canvas", Vector3(0, fy_ridge + 0.01, -fl), Vector3(0, fy_ridge + 0.01, fl), 0.07, 0.022, fly.darkened(0.16), Vector3.UP)
	# 3. Upright aluminium ridge poles and taut guy lines to pegs.
	var cord := Color(0.92, 0.82, 0.18)
	for sz: float in [-1.0, 1.0]:
		var pz := sz * (hl + 0.06)
		k.tube(kit, "metal", Vector3(0, 0.0, pz), Vector3(0, fy_ridge + 0.06, pz), 0.016, 0.016, 6, GALV)
		var g_end := Vector3(0, 0.0, sz * (fl + 0.65))
		k.tube(kit, "matte", Vector3(0, fy_ridge, sz * fl), g_end, 0.006, 0.006, 4, cord)
		k.tube(kit, "metal", g_end + Vector3(0, 0.07, 0), g_end - Vector3(0, 0.03, 0), 0.011, 0.008, 4, GALV)
	for i in range(4):
		var gz := lerpf(-fl + 0.06, fl - 0.06, float(i) / 3.0)
		for sx in [-1.0, 1.0]:
			var e_pt := Vector3(sx * fw, fy_eave, gz)
			var p_pt := Vector3(sx * (fw + 0.42), 0.0, gz)
			k.tube(kit, "matte", e_pt, p_pt, 0.006, 0.006, 4, cord)
			k.tube(kit, "metal", p_pt + Vector3(0, 0.07, 0), p_pt - Vector3(0, 0.03, 0), 0.011, 0.008, 4, GALV)


## A kettle barbecue on three wheeled legs with wire shelf and side handle.
func bbq(kit: Dictionary) -> void:
	var k := _kit
	var black := Color(0.07, 0.07, 0.08)
	k.lathe(kit, "gloss", Vector3(0, 0.62, 0), [Vector2(0.0, -0.22), Vector2(0.18, -0.20), Vector2(0.28, -0.08), Vector2(0.30, 0.0)], 16, black)
	k.lathe(kit, "gloss", Vector3(0, 0.62, 0), [Vector2(0.30, 0.0), Vector2(0.27, 0.12), Vector2(0.15, 0.22), Vector2(0.0, 0.25)], 16, Color(0.76, 0.12, 0.10))
	k.block(kit, "chrome", Vector3(-0.07, 0.87, -0.025), Vector3(0.07, 0.91, 0.025), Color(0.86, 0.88, 0.90))
	k.block(kit, "chrome", Vector3(0.29, 0.60, -0.06), Vector3(0.35, 0.63, 0.06), Color(0.86, 0.88, 0.90))
	for i in range(3):
		var a := TAU * i / 3.0
		var foot := Vector3(cos(a) * 0.32, 0.0, sin(a) * 0.32)
		k.tube(kit, "metal", Vector3(cos(a) * 0.20, 0.45, sin(a) * 0.20), foot, 0.013, 0.013, 6, GALV)
		if i < 2:
			k.tube(kit, "rubber", foot + Vector3(-0.015, 0.055, 0), foot + Vector3(0.015, 0.055, 0), 0.055, 0.055, 8, TYRE)


## A pop-up gazebo at life size: 3 x 3 m on four telescopic legs with corner curtains, scissor trusses
## under the eaves, a ribbed pyramid canopy with a ventilator cap and striped valance, and, with
## `wall`, a panelled backdrop and side skirts.
func gazebo(kit: Dictionary, canopy: Color, wall: bool) -> void:
	var k := _kit
	var hw := 1.47
	var eave := 2.05
	var peak := 2.76
	var fr := Color(0.82, 0.84, 0.86)
	var joint := Color(0.11, 0.11, 0.12)
	var under := canopy.darkened(0.32)
	var seam := canopy.darkened(0.16)
	var stripe_col := Color(0.95, 0.95, 0.93) if canopy.v < 0.82 else Color(0.10, 0.24, 0.56)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var x: float = sx * hw
			var z: float = sz * hw
			# Lower and upper telescopic hexagonal/square leg sections, footplate and slider collars.
			k.block(kit, "metal", Vector3(x - 0.017, 0.0, z - 0.017), Vector3(x + 0.017, 1.08, z + 0.017), fr)
			k.block(kit, "metal", Vector3(x - 0.022, 1.05, z - 0.022), Vector3(x + 0.022, eave, z + 0.022), fr)
			k.block(kit, "plastic", Vector3(x - 0.028, 1.02, z - 0.028), Vector3(x + 0.028, 1.09, z + 0.028), joint)
			k.block(kit, "plastic", Vector3(x - 0.028, eave - 0.42, z - 0.028), Vector3(x + 0.028, eave - 0.35, z + 0.028), joint)
			k.block(kit, "plastic", Vector3(x - 0.03, eave - 0.06, z - 0.03), Vector3(x + 0.03, eave + 0.01, z + 0.03), joint)
			k.block(kit, "metal", Vector3(x - 0.08, 0.0, z - 0.08), Vector3(x + 0.08, 0.016, z + 0.08), fr.darkened(0.22))
			# Saddle sandbag weight round the foot with yellow cinch strap.
			var sb_xf := Transform3D(Basis(Vector3.UP, 0.35 * sx * sz), Vector3(x, 0.09, z))
			k.box(kit, "canvas", sb_xf * Transform3D(Basis(), Vector3(-0.07, 0, 0)), Vector3(0.13, 0.18, 0.24), Color(0.10, 0.10, 0.11))
			k.box(kit, "canvas", sb_xf * Transform3D(Basis(), Vector3(0.07, 0, 0)), Vector3(0.13, 0.18, 0.24), Color(0.10, 0.10, 0.11))
			k.box(kit, "canvas", sb_xf * Transform3D(Basis(), Vector3(0, 0.01, 0)), Vector3(0.30, 0.05, 0.07), Color(0.92, 0.72, 0.12))
			# Gathered corner leg curtain tie-back on the upper half of each leg.
			var cx_in: float = x - sx * 0.035
			var cz_in: float = z - sz * 0.035
			k.tube(kit, "canvas", Vector3(cx_in, eave - 0.22, cz_in), Vector3(x - sx * 0.015, 1.25, z - sz * 0.015), 0.11, 0.048, 6, canopy.darkened(0.06))
			k.tube(kit, "canvas", Vector3(x - sx * 0.015, 1.25, z - sz * 0.015), Vector3(cx_in, 0.88, cz_in), 0.048, 0.085, 6, canopy.darkened(0.06))
			k.tube(kit, "canvas", Vector3(x - sx * 0.015, 1.23, z - sz * 0.015), Vector3(x - sx * 0.015, 1.27, z - sz * 0.015), 0.054, 0.054, 6, stripe_col)
	var corners := [Vector3(-hw, 0, -hw), Vector3(hw, 0, -hw), Vector3(hw, 0, hw), Vector3(-hw, 0, hw)]
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		k.beam(kit, "metal", a + Vector3(0, eave - 0.03, 0), b + Vector3(0, eave - 0.03, 0), 0.028, 0.028, fr)
		for h in range(4):
			var p0: Vector3 = a.lerp(b, h / 4.0)
			var p1: Vector3 = a.lerp(b, (h + 1) / 4.0)
			var pm: Vector3 = (p0 + p1) * 0.5
			k.beam(kit, "metal", p0 + Vector3(0, eave - 0.38, 0), p1 + Vector3(0, eave - 0.05, 0), 0.016, 0.016, fr)
			k.beam(kit, "metal", p0 + Vector3(0, eave - 0.05, 0), p1 + Vector3(0, eave - 0.38, 0), 0.016, 0.016, fr)
			k.block(kit, "plastic", pm + Vector3(-0.018, eave - 0.23, -0.018), pm + Vector3(0.018, eave - 0.19, 0.018), joint)
	# Cross-ties and suspended LED pit light bar inside the canopy frame.
	k.beam(kit, "metal", Vector3(-hw, eave - 0.22, 0), Vector3(hw, eave - 0.22, 0), 0.022, 0.022, fr)
	k.beam(kit, "metal", Vector3(0, eave - 0.22, -hw), Vector3(0, eave - 0.22, hw), 0.022, 0.022, fr)
	k.block(kit, "lamp", Vector3(-0.65, eave - 0.25, -0.025), Vector3(0.65, eave - 0.225, 0.025), Color(1.0, 0.97, 0.88))
	# Canopy: tensioned pyramid to a raised square ventilator hood, centre mast under it.
	var e := 1.53
	var c := 0.18
	var base := [Vector3(-e, eave, -e), Vector3(e, eave, -e), Vector3(e, eave, e), Vector3(-e, eave, e)]
	var cap := [Vector3(-c, peak - 0.06, -c), Vector3(c, peak - 0.06, -c), Vector3(c, peak - 0.06, c), Vector3(-c, peak - 0.06, c)]
	for i in range(4):
		var a: Vector3 = base[i]
		var b: Vector3 = base[(i + 1) % 4]
		var cc: Vector3 = cap[(i + 1) % 4]
		var d: Vector3 = cap[i]
		var nrm := (b - a).cross(d - a).normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		var mid := (a + b + cc + d) * 0.25 - Vector3(0, 0.045, 0)
		for t in [[a, b, mid], [b, cc, mid], [cc, d, mid], [d, a, mid]]:
			k.tri(kit, "canvas", t[0], t[1], t[2], nrm, nrm, nrm, canopy, nrm)
			k.tri(kit, "canvas", t[0], t[2], t[1], -nrm, -nrm, -nrm, under, -nrm)
		# Hip seam reinforcement rib from corner to peak cap.
		var hn := (a + Vector3(0, 0.6, 0)).normalized()
		k.beam(kit, "canvas", a + Vector3(0, 0.01, 0), d + Vector3(0, 0.01, 0), 0.045, 0.018, seam, hn)
	# Raised ventilator hood at the peak.
	k.block(kit, "plastic", Vector3(-c * 0.85, peak - 0.07, -c * 0.85), Vector3(c * 0.85, peak - 0.01, c * 0.85), joint)
	var vcap := [Vector3(-c * 1.15, peak - 0.01, -c * 1.15), Vector3(c * 1.15, peak - 0.01, -c * 1.15),
			Vector3(c * 1.15, peak - 0.01, c * 1.15), Vector3(-c * 1.15, peak - 0.01, c * 1.15)]
	var vtop := Vector3(0, peak + 0.07, 0)
	for i in range(4):
		var va: Vector3 = vcap[i]
		var vb: Vector3 = vcap[(i + 1) % 4]
		var vn := (vb - va).cross(vtop - va).normalized()
		if vn.y < 0.0:
			vn = -vn
		k.tri(kit, "canvas", va, vb, vtop, vn, vn, vn, stripe_col, vn)
	k.tube(kit, "metal", Vector3(0, eave - 0.22, 0), Vector3(0, peak - 0.02, 0), 0.022, 0.022, 6, fr)
	for i in range(4):
		var a: Vector3 = base[i]
		k.beam(kit, "metal", Vector3(0, peak - 0.08, 0), a.lerp(Vector3(0, a.y, 0), 0.05) + Vector3(0, -0.05, 0), 0.02, 0.02, fr)
	# Valance with double racing stripe and corner seam binding.
	var vh := 0.27
	for i in range(4):
		var a: Vector3 = base[i]
		var b: Vector3 = base[(i + 1) % 4]
		var outn := Vector3((a + b).x, 0.0, (a + b).z).normalized()
		var along := (b - a).normalized()
		k.panel(kit, "canvas", [a, b, b - Vector3(0, vh, 0), a - Vector3(0, vh, 0)], outn, canopy.lightened(0.04), under)
		# Main contrasting stripe band + lower accent pinstripe.
		k.quad(kit, "canvas", [a - Vector3(0, 0.16, 0) + outn * 0.005, b - Vector3(0, 0.16, 0) + outn * 0.005,
				b - Vector3(0, 0.215, 0) + outn * 0.005, a - Vector3(0, 0.215, 0) + outn * 0.005], outn, stripe_col)
		k.quad(kit, "canvas", [a - Vector3(0, 0.23, 0) + outn * 0.005, b - Vector3(0, 0.23, 0) + outn * 0.005,
				b - Vector3(0, 0.25, 0) + outn * 0.005, a - Vector3(0, 0.25, 0) + outn * 0.005], outn, seam)
		# Corner accent blocks on the valance.
		for end_pt in [[a, a + along * 0.22], [b - along * 0.22, b]]:
			var p0: Vector3 = end_pt[0]
			var p1: Vector3 = end_pt[1]
			k.quad(kit, "canvas", [p0 - Vector3(0, 0.03, 0) + outn * 0.005, p1 - Vector3(0, 0.03, 0) + outn * 0.005,
					p1 - Vector3(0, 0.13, 0) + outn * 0.005, p0 - Vector3(0, 0.13, 0) + outn * 0.005], outn, stripe_col)
	if wall:
		var wz := hw + 0.025
		k.panel(kit, "canvas", [Vector3(-hw, 0.03, wz), Vector3(hw, 0.03, wz), Vector3(hw, eave, wz), Vector3(-hw, eave, wz)],
				Vector3(0, 0, 1), canopy.darkened(0.04), under.lightened(0.08))
		# Central team stripe and framed PVC window across the back wall.
		for sgn: float in [-1.0, 1.0]:
			var fn := Vector3(0, 0, sgn)
			var z_off := wz + sgn * 0.006
			k.quad(kit, "canvas", [Vector3(-hw + 0.04, 0.92, z_off), Vector3(hw - 0.04, 0.92, z_off),
					Vector3(hw - 0.04, 1.18, z_off), Vector3(-hw + 0.04, 1.18, z_off)], fn, stripe_col)
		# Half-height side banner walls spanning between front and rear legs.
		for sx: float in [-1.0, 1.0]:
			var wx := sx * (hw + 0.02)
			var sn := Vector3(sx, 0, 0)
			k.panel(kit, "canvas", [Vector3(wx, 0.03, -hw), Vector3(wx, 0.03, hw), Vector3(wx, 0.88, hw), Vector3(wx, 0.88, -hw)],
					sn, canopy.darkened(0.02), under.lightened(0.08))
			for sgn: float in [-1.0, 1.0]:
				var sx_off := wx + sgn * 0.006
				k.quad(kit, "canvas", [Vector3(sx_off, 0.70, -hw + 0.04), Vector3(sx_off, 0.70, hw - 0.04),
						Vector3(sx_off, 0.82, hw - 0.04), Vector3(sx_off, 0.82, -hw + 0.04)], Vector3(sgn, 0, 0), stripe_col)
			k.beam(kit, "metal", Vector3(sx * hw, 0.89, -hw), Vector3(sx * hw, 0.89, hw), 0.022, 0.022, fr)


func folding_table(kit: Dictionary, top: Color) -> void:
	var k := _kit
	k.block(kit, "plastic", Vector3(-0.92, 0.70, -0.38), Vector3(0.92, 0.74, 0.38), top)
	k.block(kit, "plastic", Vector3(-0.90, 0.66, -0.36), Vector3(0.90, 0.70, 0.36), top.darkened(0.15))
	var g := Color(0.55, 0.56, 0.58)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.78
		for sz in [-1.0, 1.0]:
			k.tube(kit, "metal", Vector3(x, 0.67, sz * 0.31), Vector3(x + sx * 0.03, 0.0, sz * 0.34), 0.014, 0.014, 6, g)
		k.tube(kit, "metal", Vector3(x + sx * 0.02, 0.22, -0.33), Vector3(x + sx * 0.02, 0.22, 0.33), 0.011, 0.011, 6, g)


func camp_chair(kit: Dictionary, fabric: Color) -> void:
	var k := _kit
	var fr := Color(0.10, 0.10, 0.11)
	var seat_y := 0.44
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.tube(kit, "metal", Vector3(sx * 0.29, 0.0, sz * 0.26), Vector3(sx * 0.26, seat_y, sz * 0.22), 0.012, 0.012, 5, fr)
		# X braces on the sides.
		k.tube(kit, "metal", Vector3(sx * 0.28, 0.05, -0.25), Vector3(sx * 0.27, seat_y - 0.03, 0.22), 0.009, 0.009, 4, fr)
		k.tube(kit, "metal", Vector3(sx * 0.28, 0.05, 0.25), Vector3(sx * 0.27, seat_y - 0.03, -0.22), 0.009, 0.009, 4, fr)
		# Back posts and armrests.
		k.tube(kit, "metal", Vector3(sx * 0.26, seat_y, 0.22), Vector3(sx * 0.26, 0.98, 0.33), 0.012, 0.012, 5, fr)
		k.block(kit, "plastic", Vector3(sx * 0.29 - 0.035, 0.62, -0.24), Vector3(sx * 0.29 + 0.035, 0.65, 0.22), fr.lightened(0.05))
		k.tube(kit, "metal", Vector3(sx * 0.29, 0.62, -0.2), Vector3(sx * 0.27, seat_y, -0.2), 0.01, 0.01, 4, fr)
	# Sagging seat and the back, fabric both sides.
	var sag := Vector3(0, -0.05, 0)
	var s0 := Vector3(-0.26, seat_y, -0.22)
	var s1 := Vector3(0.26, seat_y, -0.22)
	var s2 := Vector3(0.26, seat_y, 0.22)
	var s3 := Vector3(-0.26, seat_y, 0.22)
	var sm := (s0 + s1 + s2 + s3) * 0.25 + sag
	for t in [[s0, s1, sm], [s1, s2, sm], [s2, s3, sm], [s3, s0, sm]]:
		k.tri(kit, "canvas", t[0], t[1], t[2], Vector3.UP, Vector3.UP, Vector3.UP, fabric, Vector3.UP)
		k.tri(kit, "canvas", t[0], t[2], t[1], Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, fabric.darkened(0.3), Vector3.DOWN)
	var bn := Vector3(0, 0.2, -1).normalized()
	k.panel(kit, "canvas", [Vector3(-0.26, seat_y + 0.04, 0.24), Vector3(0.26, seat_y + 0.04, 0.24), Vector3(0.26, 0.96, 0.33), Vector3(-0.26, 0.96, 0.33)],
			bn, fabric, fabric.darkened(0.3))
	# A cup holder on the right arm.
	k.tube(kit, "canvas", Vector3(0.36, 0.56, -0.18), Vector3(0.36, 0.65, -0.18), 0.04, 0.045, 6, fabric.darkened(0.15))


func cooler(kit: Dictionary, body: Color, lid: Color) -> void:
	var k := _kit
	k.block(kit, "plastic", Vector3(-0.3, 0.02, -0.19), Vector3(0.3, 0.35, 0.19), body)
	k.block(kit, "plastic", Vector3(-0.31, 0.35, -0.2), Vector3(0.31, 0.41, 0.2), lid)
	for sx in [-1.0, 1.0]:
		k.block(kit, "plastic", Vector3(sx * 0.31 - 0.015, 0.24, -0.06), Vector3(sx * 0.31 + 0.015, 0.29, 0.06), lid)
		for sz in [-1.0, 1.0]:
			k.block(kit, "plastic", Vector3(sx * 0.26 - 0.03, 0.0, sz * 0.15 - 0.03), Vector3(sx * 0.26 + 0.03, 0.02, sz * 0.15 + 0.03), lid.darkened(0.3))


## A steel crowd barrier at life size: 2.3m long (x), 1.1m high, vertical bars in a tube frame on two
## flat feet.
func crowd_barrier(kit: Dictionary) -> void:
	var k := _kit
	var g := GALV
	var hl := 1.12
	k.tube(kit, "metal", Vector3(-hl, 1.07, 0), Vector3(hl, 1.07, 0), 0.02, 0.02, 6, g)
	k.tube(kit, "metal", Vector3(-hl, 0.2, 0), Vector3(hl, 0.2, 0), 0.02, 0.02, 6, g)
	for sx in [-1.0, 1.0]:
		k.tube(kit, "metal", Vector3(sx * hl, 0.12, 0), Vector3(sx * hl, 1.09, 0), 0.02, 0.02, 6, g)
		k.block(kit, "metal", Vector3(sx * (hl - 0.12) - 0.03, 0.0, -0.32), Vector3(sx * (hl - 0.12) + 0.03, 0.03, 0.32), g.darkened(0.15))
		k.tube(kit, "metal", Vector3(sx * (hl - 0.12), 0.03, -0.28), Vector3(sx * (hl - 0.12), 0.2, 0.0), 0.012, 0.012, 4, g)
		k.tube(kit, "metal", Vector3(sx * (hl - 0.12), 0.03, 0.28), Vector3(sx * (hl - 0.12), 0.2, 0.0), 0.012, 0.012, 4, g)
	var nbars := 14
	for b in range(nbars):
		var x := -hl + 2.0 * hl * (b + 0.5) / nbars
		k.tube(kit, "metal", Vector3(x, 0.2, 0), Vector3(x, 1.07, 0), 0.009, 0.009, 4, g)


## A traffic cone at life size (0.7m) on its square base, two reflective bands.
func cone(kit: Dictionary) -> void:
	var k := _kit
	k.block(kit, "rubber", Vector3(-0.19, 0.0, -0.19), Vector3(0.19, 0.04, 0.19), Color(0.08, 0.08, 0.08))
	var orange := Color(0.98, 0.36, 0.05)
	var white := Color(0.95, 0.95, 0.95)
	var prof := [[0.04, 0.15, orange], [0.30, 0.115, white], [0.38, 0.103, orange], [0.47, 0.09, white], [0.53, 0.082, orange], [0.70, 0.03, orange]]
	for i in range(prof.size() - 1):
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		k.lathe(kit, "plastic", Vector3.ZERO, [Vector2(float(a[1]), float(a[0])), Vector2(float(b[1]), float(b[0]))], 14, a[2])
	k.lathe(kit, "plastic", Vector3(0, 0.7, 0), [Vector2(0.03, 0.0), Vector2(0.0, 0.01)], 14, orange)
