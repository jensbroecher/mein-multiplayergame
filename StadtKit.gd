extends RefCounted
## Kronburg's city centre (Kronburg GP finale, the city rally): the main station Kronburg Hbf with its elevated platforms
## and train sheds, the walled railway embankment and the riveted trough bridge the route passes under, the 1960s
## department store KAUFHAUS KRONE, the city's trams and the traffic on the ring road (buses, delivery trucks, cars, a
## taxi, vans), a tram stop, catenary masts, traffic lights, a pedestrian-zone fountain, café terraces, planters, bike
## racks, bollards, a U-Bahn entrance and the race's scaffold grandstand. Everything fictional: Kronburg, the Kronburger
## Stadtwerke (KSW), the shops and liveries; generic German street furniture.
##
## Everything is built at LIFE size through a PropKit in its own frame (y = 0 the ground, footings down to y = -1.5, the
## front toward +z unless a builder says otherwise) and grown by the caller (PROP_SCALE 1.6): make a kit with
## `new_kit(scale)`, set its frame to the prop's place (scaled), call a builder, `commit(pk, kit)`. UVs are in metres
## times `uvk` (the caller's scale) where a shader tiles (brick, ashlar, slate, zinc, concrete, honeycomb, rivets, LEDs),
## in life metres on steel glazing ("glass": steel_glazing draws its panes). Labels are [text, position, outward normal,
## cap height, colour, board width] in life-size kit coordinates. Solids are [Transform3D (life, in the prop's frame,
## its origin the box's centre), Vector3 size] boxes.
##
## Material keys (make_material): SteelworksKit's "brick" (ruhr_brick), "glass"/"skylight" (steel_glazing outside/inside),
## "grime", "floor", "shell", "rusty", "corten", "roofing" (industrial_paint), "hazard", "lamp" (LampGlow, lit), "lens"
## (unlit lamp glass); KronburgTownKit's "ashlar" (sandstone), "kslate" (slate), "pane" (opaque glossy glass, also the
## Kaufhaus's polished granite), "gold", "enamel", "leaf" (two-sided: crowns, grass, flowers), "kwater"; RheinStadtKit's
## "copper" (green patina), "bulb" (soft daytime glow), "pennant" (two-sided cloth); YardKit's "concrete", "zinc" (standing
## seams), "stone", "plaster", "painted", "timber", "iron"; CampKit's vertex-colour "paint", "gloss", "metal", "steel",
## "chrome", "matte", "plastic", "rubber", "canvas", "wood"; and this kit's own: "honeycomb" (stadt_honeycomb.gdshader:
## the store's white ceramic honeycomb tiles), "rivet" (stadt_rivet.gdshader: riveted painted plate), "led"
## (stadt_led.gdshader: lit dot-matrix displays, UV u along from the left, v down from the top), "bronze", "sglass"
## (see-through tinted glass: shelters, wind screens, shop windows; vertex alpha the opacity) and "wsheet"
## (fountain_water's falling sheet: UV.x round, UV.y down it). The traffic and the trams use few keys ("gloss", "matte",
## "plastic", "rubber", "metal", "lamp", "led"), since each is drawn as a MultiMesh: a surface a draw call.
##
## Faces never share a plane: trims stand 2.5cm or more proud of what is behind them, panes 2cm, and parts that meet
## overlap or step. Godot's front faces wind clockwise: PropKit.tri winds every triangle for the `out` it's given.
##
## The builders (life size):
##   hauptbahnhof(pk, kit, labels)        street front x -62..62 at z = 0 facing +z (entrance hall to z 1.2, the clock tower
##                                        (TOWER_X, to TOWER_TOP 42.6) to 0.5, pavilions to 0.8, taxi canopy over x -32..-10
##                                        to z 7.9, its rank sign at z 8.7), the building to z -28; behind it the elevated
##                                        block x -64..64 (BLOCK_HX, where the generator's walled embankment butts on), z
##                                        -28..-100, its top BED_Y between the platforms; four platforms (PLATFORMS, top
##                                        PLATFORM_TOP), the tracks TRACKS_Z (rail top PLATFORM_Y: Gleis 2 and 3 are the line's,
##                                        the generator lays them; Gleis 1 and 4 are stubs drawn here), three arched sheds over
##                                        SHED_ROWS. About 75k triangles. hauptbahnhof_solids()
##   rail_embankment(pk, kit, length, h, half_width, seed, caps, labels)   along x 0..length, |z| <= half_width, top y = h
##   railway_bridge(pk, kit, labels, span, h)   trough bridge along x over a street along z; abutment faces x = +-span/2,
##                                        each abutment BRIDGE_ABUTMENT deep beyond its face
##   department_store(pk, kit, labels, w, d)    x -w/2..w/2, front z = 0 (+z), back z = -d; canopy to z 3.06 (underside
##                                        KH_CANOPY_Y 4.45), main roof KH_TOP 23, the roof restaurant to KH_REST 26.4.
##                                        department_store_solids(w, d)
##   tram(pk, kit, variant) -> size       centred, TRAM_LEN 30.0 x 2.30, y = 0 the rail top, cabs at both ends (toward -z and
##                                        +z), the pantograph raised to TRAM_PAN_TOP 5.975 (the Ring's contact wire at 6.0)
##   city_bus(variant), box_truck(variant), hatchback(col), saloon(col, taxi), delivery_van(col) (pk, kit, ...) -> size
##                                        centred, nose toward -z, y = 0 the road: 12.0 x 2.55, 7.8 x 2.5, 4.05 x 1.78,
##                                        4.84 x 1.84, 5.95 x 2.0 (mirrors a little wider)
##   tram_stop(pk, kit, labels, length, name)   along x centred on the origin, the road's kerb toward +z: the raised kerb
##                                        z 0.55..2.05 (top STOP_KERB), the shelter and furniture back to z -1.25.
##                                        tram_stop_solids(length)
##   catenary_mast(pk, kit, reach, wire_y), catenary_wire_point(reach, wire_y)   mast on the origin, arm toward -x, the
##                                        contact wire at (-reach, wire_y), the messenger MESSENGER_RISE over it
##   traffic_light(pk, kit, arm_len)      pole on the origin, heads facing +z (and a pair facing -z on the pole), the arm
##                                        along +x; pedestrian_light(pk, kit), bollard(pk, kit)
##   city_fountain(pk, kit)               centred, basin 8m across its flats (to 4.33 at the corners), crown 5.0m.
##                                        city_fountain_solids()
##   cafe_terrace(pk, kit, w, d, seed)    within x +-w/2, z +-d/2 (the building side toward -z)
##   planter(pk, kit, seed)               centred, 1.4m square, 0.72m high (a tree to 3.3m)
##   bike_rack(pk, kit, n)                n hoops 1m apart along x centred, each along z (within +-0.9)
##   u_bahn_entrance(pk, kit, labels)     open toward +z, x +-2.9, z -4.4..4.0. u_bahn_entrance_solids()
##   temp_grandstand(pk, kit, labels, rows, length)   x +-length/2, front z = 0 (+z), back z = -(GS_WALK_D + rows *
##                                        GS_TREAD); temp_grandstand_seats(rows, length) -> the seats' tops (Vector3),
##                                        temp_grandstand_solids(rows, length)

const PropKit = preload("res://PropKit.gd")
const SW = preload("res://SteelworksKit.gd")
const KT = preload("res://KronburgTownKit.gd")
const YK = preload("res://YardKit.gd")
const RS = preload("res://RheinStadtKit.gd")
const ZK = preload("res://ZechenKit.gd")
const CampKit = preload("res://CampKit.gd")
const LampGlow = preload("res://LampGlow.gd")
const MK = preload("res://MatatuKit.gd")
const ShopNames = preload("res://ShopNames.gd")

static var uvk := 1.6
static var _mats := {}

const SW_KEYS := ["hot", "glass", "skylight", "rusty", "corten", "grime", "floor", "shell", "roofing", "hazard", "lamp", "lens", "heap", "brick"]
const KT_KEYS := ["biber", "ashlar", "kslate", "kbrick", "pane", "gold", "enamel", "leaf", "kwater", "hedge"]
const RS_KEYS := ["copper", "bulb", "pennant", "wglass"]
const TANGENT_KEYS := ["iron", "concrete", "slate", "kslate", "biber", "tile", "zinc", "honeycomb", "rivet"]

const UP := Vector3.UP
const WHITE := Color(1, 1, 1)
## Ruhr sandstone, a little sooty, and its lighter dressings.
const SAND := Color(0.74, 0.65, 0.51)
const SAND_LIGHT := Color(0.82, 0.74, 0.60)
const SAND_DARK := Color(0.60, 0.52, 0.41)
const CARVED := Color(0.22, 0.17, 0.12)
const BRICK := Color(0.47, 0.22, 0.15)
const BRICK_DARK := Color(0.33, 0.15, 0.11)
const SLATE := Color(0.30, 0.31, 0.35)
const PATINA := Color(0.40, 0.64, 0.54)
const GOLD := Color(0.86, 0.68, 0.28)
const IRON_GREEN := Color(0.20, 0.27, 0.24)
const STEEL_DARK := Color(0.15, 0.16, 0.16)
const GALV := Color(0.64, 0.66, 0.66)
const CONC := Color(0.66, 0.65, 0.61)
const BLACK := Color(0.03, 0.03, 0.035)
const GLASS_DARK := Color(0.05, 0.07, 0.09)
const TYRE := Color(0.06, 0.06, 0.065)
const TRIM_BLACK := Color(0.08, 0.085, 0.09)
const AMBER := Color(1.0, 0.62, 0.12)
const HEAD_LAMP := Color(1.0, 0.97, 0.88)
const TAIL_LAMP := Color(0.85, 0.06, 0.04)
const DB_BLUE := Color(0.10, 0.20, 0.42)
const SIGN_YELLOW := Color(0.98, 0.78, 0.05)
const STOP_GREEN := Color(0.05, 0.50, 0.25)
const U_BLUE := Color(0.08, 0.26, 0.62)

## The Kronburger Stadtwerke's two liveries: [primary, secondary, skirt, roof].
const KSW_LIVERIES := [
	[Color(0.95, 0.95, 0.93), Color(0.78, 0.08, 0.10), Color(0.62, 0.06, 0.08), Color(0.80, 0.81, 0.82)],
	[Color(0.97, 0.76, 0.10), Color(0.38, 0.40, 0.43), Color(0.26, 0.27, 0.29), Color(0.74, 0.75, 0.76)],
]


# ======================================================================================
#  Materials and kits
# ======================================================================================

static func make_material(key: String) -> Material:
	match key:
		"honeycomb":
			var h := ShaderMaterial.new()
			h.shader = load("res://stadt_honeycomb.gdshader")
			return h
		"rivet":
			var r := ShaderMaterial.new()
			r.shader = load("res://stadt_rivet.gdshader")
			return r
		"led":
			var l := ShaderMaterial.new()
			l.shader = load("res://stadt_led.gdshader")
			return l
		"wsheet":
			var w := ShaderMaterial.new()
			w.shader = load("res://fountain_water.gdshader")
			w.set_shader_parameter("mode", 1)
			return w
		"bronze":
			var b := StandardMaterial3D.new()
			b.vertex_color_use_as_albedo = true
			b.vertex_color_is_srgb = true
			b.metallic = 0.85
			b.roughness = 0.38
			return b
		"sglass":
			var g := StandardMaterial3D.new()
			g.vertex_color_use_as_albedo = true
			g.vertex_color_is_srgb = true
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.metallic = 0.3
			g.roughness = 0.05
			g.cull_mode = BaseMaterial3D.CULL_DISABLED
			return g
	if key in SW_KEYS:
		return SW.make_material(key)
	if key in KT_KEYS:
		return KT.make_material(key)
	if key in RS_KEYS:
		return RS.make_material(key)
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
	ZK.uvk = scale
	RS.uvk = scale
	SW._lx = Transform3D.IDENTITY
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


## A box centred at `c` turned by `basis`, UVs in metres.
static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## An axis-aligned block between two corners (any order), UVs in metres.
static func _blk(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color) -> void:
	pk.block(kit, key, Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)), Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)), col, uvk)


## A wall frame (KronburgTownKit's): x along the wall (up x out), y up, z out of it, origin `o` (u = 0 at its foot).
static func _wf(o: Vector3, out: Vector3) -> Transform3D:
	return KT._wf(o, out)


## A flat face [u0, u1] x [v0, v1] at depth d in a wall frame, UVs in metres.
static func _face(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, d: float, col: Color) -> void:
	KT._face(pk, kit, key, wf, u0, v0, u1, v1, d, col)


## A rectangle standing d0..d1 off a wall frame (its rim too).
static func _rect(pk: PropKit, kit: Dictionary, key: String, wf: Transform3D, u0: float, v0: float, u1: float, v1: float, d0: float, d1: float, col: Color) -> void:
	KT._rect(pk, kit, key, wf, u0, v0, u1, v1, d0, d1, col)


## A flat quad with UVs (u along a->b, v along a->d) in metres times `uvk`, facing `n`.
static func _uvquad(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, scale := -1.0) -> void:
	var s: float = uvk if scale < 0.0 else scale
	var lu: float = a.distance_to(b)
	var lv: float = a.distance_to(d)
	pk.quad(kit, key, [a, b, c, d], n, col, [Vector2(0, 0), Vector2(lu * s, 0), Vector2(lu * s, lv * s), Vector2(0, lv * s)])


## A lit dot-matrix panel ("led") centred at c facing `out` (w wide, h tall), UVs from its top left in game metres, in
## a dark housing `housing` deep behind it.
static func _led(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, col := AMBER, up := UP, housing := 0.04) -> void:
	var right: Vector3 = up.cross(out).normalized()
	var tl: Vector3 = c - right * (w * 0.5) + up * (h * 0.5)
	var s: float = uvk
	pk.quad(kit, "led", [tl, tl + right * w, tl + right * w - up * h, tl - up * h], out, col,
			[Vector2(0, 0), Vector2(w * s, 0), Vector2(w * s, h * s), Vector2(0, h * s)])
	if housing > 0.0:
		_box(pk, kit, "matte", c - out * (housing * 0.5 + 0.004), Basis(right, up, out), Vector3(w + 0.06, h + 0.06, housing), TRIM_BLACK)


## The number of glyph cells `text` takes in MatatuKit's pixel font.
static func _cells(text: String) -> int:
	var w := -1
	for ch in text:
		if MK.GLYPHS.has(ch):
			w += (MK.GLYPHS[ch][0] as String).length() + 1
		else:
			w += 3
	return w


## `text` in MatatuKit's pixel font (block capitals), `cell` metres a cell, centred on `centre`, reading along `right`, its
## up along `up`, facing right x up: one quad per run of lit cells. For lettering inside MultiMesh vehicles (no labels).
static func _gtext(pk: PropKit, kit: Dictionary, key: String, centre: Vector3, right: Vector3, up: Vector3, cell: float, text: String, col: Color) -> void:
	var face: Vector3 = right.cross(up).normalized()
	var origin: Vector3 = centre - right * (float(_cells(text)) * cell * 0.5) - up * (2.5 * cell)
	var x := 0
	for ch in text:
		if not MK.GLYPHS.has(ch):
			x += 3
			continue
		var rows: Array = MK.GLYPHS[ch]
		for r in range(5):
			var row: String = rows[r]
			var i := 0
			while i < row.length():
				if row[i] != "X":
					i += 1
					continue
				var j := i
				while j < row.length() and row[j] == "X":
					j += 1
				var lo: Vector3 = origin + right * (float(x + i) * cell) + up * (float(4 - r) * cell)
				var span: Vector3 = right * (float(j - i) * cell)
				pk.quad(kit, key, [lo, lo + span, lo + span + up * cell, lo + up * cell], face, col)
				i = j
		x += (rows[0] as String).length() + 1


## A disc of radius r round c facing `n` (`segs` sides), both faces with `back`.
static func _disc(pk: PropKit, kit: Dictionary, key: String, c: Vector3, n: Vector3, r: float, segs: int, col: Color, back := false) -> void:
	var a: Vector3 = n.cross(UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var b: Vector3 = n.cross(a).normalized()
	for k in range(segs):
		var t0: float = TAU * float(k) / float(segs)
		var t1: float = TAU * float(k + 1) / float(segs)
		var p0: Vector3 = c + (a * cos(t0) + b * sin(t0)) * r
		var p1: Vector3 = c + (a * cos(t1) + b * sin(t1)) * r
		pk.tri(kit, key, c, p0, p1, n, n, n, col, n)
		if back:
			pk.tri(kit, key, c - n * 0.004, p1 - n * 0.004, p0 - n * 0.004, -n, -n, -n, col, -n)


## A grid surface through `rows` (Arrays of Vector3, all the same length): quads between neighbouring rows, smooth
## vertex normals from the faces round each point, each face turned away from `inside` (a point within the body, or a
## Callable(Vector3) -> Vector3 giving one for a face's middle). `col_fn(mid, normal) -> Color` colours each quad.
static func _grid(pk: PropKit, kit: Dictionary, key: String, rows: Array, inside, col_fn: Callable, closed := false) -> void:
	var nr: int = rows.size()
	var nc: int = (rows[0] as Array).size()
	var cols: int = nc if closed else nc - 1
	var fn := []
	for i in range(nr - 1):
		var line := []
		for j in range(cols):
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i][(j + 1) % nc]
			var c: Vector3 = rows[i + 1][(j + 1) % nc]
			var d: Vector3 = rows[i + 1][j]
			var n: Vector3 = (c - a).cross(d - b)
			if n.length_squared() < 1e-14:
				n = (b - a).cross(d - a)
			n = n.normalized()
			var mid: Vector3 = (a + b + c + d) * 0.25
			var ins: Vector3 = inside.call(mid) if inside is Callable else inside
			if n.dot(mid - ins) < 0.0:
				n = -n
			line.append(n)
		fn.append(line)
	var vn := []
	for i in range(nr):
		var line2 := []
		for j in range(nc):
			var acc := Vector3.ZERO
			for di in [-1, 0]:
				for dj in [-1, 0]:
					var fi: int = i + di
					var fj: int = j + dj
					if closed:
						fj = posmod(fj, nc)
					if fi >= 0 and fi < nr - 1 and fj >= 0 and fj < cols:
						acc += fn[fi][fj]
			line2.append(acc.normalized() if acc.length_squared() > 1e-10 else UP)
		vn.append(line2)
	for i in range(nr - 1):
		for j in range(cols):
			var j1: int = (j + 1) % nc
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i][j1]
			var c: Vector3 = rows[i + 1][j1]
			var d: Vector3 = rows[i + 1][j]
			var n: Vector3 = fn[i][j]
			var col: Color = col_fn.call((a + b + c + d) * 0.25, n)
			pk.tri(kit, key, a, b, c, vn[i][j], vn[i][j1], vn[i + 1][j1], col, n)
			pk.tri(kit, key, a, c, d, vn[i][j], vn[i + 1][j1], vn[i + 1][j], col, n)


## A side-profile body: `outline` in (forward, up) (forward = -z), extruded across x from x0 to x1 with bevelled edges:
## PropKit.extrude turned so its x is the vehicle's forward (-z) and its z the vehicle's x. `col_fn(mid, normal)` gets
## the face's middle and normal in the vehicle's frame.
static func _side_extrude(pk: PropKit, kit: Dictionary, key: String, outline: PackedVector2Array, x0: float, x1: float, bevel: float, col: Color,
		col_fn := Callable()) -> void:
	var saved := _push(pk, Transform3D(Basis(Vector3(0, 0, -1), UP, Vector3(1, 0, 0)), Vector3.ZERO))
	var fn := Callable()
	if col_fn.is_valid():
		fn = func(m: Vector3, n: Vector3) -> Color:
			return col_fn.call(Vector3(m.z, m.y, -m.x), Vector3(n.z, n.y, -n.x))
	pk.extrude(kit, key, outline, x0, x1, bevel, col, fn)
	_pop(pk, saved)


## A wheel at `c` (its axle along x), tyre radius r, width w, on side `side` (-1 left, +1 right): a tyre, a rim dish and
## hub facing outward, a dark well behind it (so no daylight shows through the arch); `dual` a second tyre inside.
static func _wheel(pk: PropKit, kit: Dictionary, c: Vector3, r: float, w: float, side: float, rim_col := Color(0.72, 0.73, 0.75), segs := 12, dual := false) -> void:
	var ab := Basis(Vector3.BACK, PI * 0.5 * -side)
	pk.tyre(kit, "rubber", c, r * 0.6, r, w, segs, TYRE, ab)
	var face: float = c.x + side * (w * 0.5 - 0.01)
	pk.lathe(kit, "metal", Vector3(face, c.y, c.z), [Vector2(r * 0.62, -0.012), Vector2(r * 0.55, 0.0), Vector2(r * 0.2, -0.03), Vector2(0.001, -0.02)],
			segs, rim_col, false, ab)
	if dual:
		pk.tyre(kit, "rubber", c - Vector3(side * w, 0, 0), r * 0.6, r, w * 0.95, segs, TYRE, ab)
	var inner: float = c.x - side * (w * (1.6 if dual else 0.55))
	pk.tube(kit, "matte", Vector3(inner, c.y + 0.02, c.z), Vector3(inner - side * w, c.y + 0.02, c.z), r * 1.08, r * 1.08, 10, BLACK, true)


# ======================================================================================
#  Brick arch walls (the embankment, the station's block)
# ======================================================================================

const ARCH_RECESS := 0.35     # how deep a blind arch is set into the wall
const ARCH_PILASTER := 1.1    # the pilasters between the bays, standing 0.22 proud
const ARCH_FOOT := 0.45       # the plinth's top: the arches' feet

## Workshop fronts in the filled arches: [name, kind] (fictional; kind: garage, shop, window).
const ARCH_SHOPS := [
	["Kfz Brammertz", "garage"], ["Reifen Kowalski", "garage"], ["Fahrräder Ernst", "shop"], ["Tischlerei Overmann", "garage"],
	["Getränke Kamps", "shop"], ["Imbiss Am Bogen", "shop"], ["Lager", "garage"], ["Schlüsseldienst Pieper", "shop"],
	["Motorrad Hülsbusch", "garage"], ["Atelier Bogen 7", "window"], ["Probenraum", "window"], ["Polsterei Wessel", "shop"],
]


## The arch geometry of an arch wall: [bays, pitch, half width, spring, rise] for a wall `length` long, `y_top` high.
static func _arch_layout(length: float, y_top: float, bay: float) -> Array:
	var n: int = maxi(1, int(round(length / bay)))
	var pitch: float = length / float(n)
	var band_lo: float = y_top - 0.8
	var half: float = clampf(pitch * 0.5 - ARCH_PILASTER * 0.5 - 0.45, 0.8, 4.2)
	var rise: float = half
	var spring: float = band_lo - 0.5 - rise
	if spring - ARCH_FOOT < 1.6:
		rise = clampf((band_lo - 0.5 - ARCH_FOOT) * 0.3, 0.3, half)
		spring = band_lo - 0.5 - rise
	return [n, pitch, half, spring, rise]


## A walled embankment's face (or any brick viaduct wall): in the plane through p0 (y 0) along `along`, facing `out`,
## from u = 0 to `length`, from y0 up to y_top. Bays about `bay` long: brick pilasters between blind round arches
## recessed ARCH_RECESS (segmental when the wall is low), some arches filled with a workshop (a roller door, a shop
## front, a fanlight window) by `shops` share; a sandstone plinth to ARCH_FOOT, a corbel table of little arches and a
## sandstone coping (its top at y_top + 0.15, `cope_back` deep behind the face) along the top.
## Options in `o`: bay (8.0), y0 (-1.5), shops (0.3), frieze (true), cope_back (0.5), dark (Array of bay indices left
## open and dark: a passage), rng (a RandomNumberGenerator), labels (an Array for the shops' names).
static func _arch_wall(pk: PropKit, kit: Dictionary, p0: Vector3, along: Vector3, out: Vector3, length: float, y_top: float, o := {}) -> void:
	var bay: float = o.get("bay", 8.0)
	var y0: float = o.get("y0", -1.5)
	var rng: RandomNumberGenerator = o.get("rng", null)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 7
	var labels: Array = o.get("labels", [])
	var lay: Array = _arch_layout(length, y_top, bay)
	var n: int = lay[0]
	var pitch: float = lay[1]
	var half: float = lay[2]
	var spring: float = lay[3]
	var rise: float = lay[4]
	var band_lo: float = y_top - 0.8
	var v0: float = ARCH_FOOT
	var kind: String = "round" if absf(rise - half) < 0.01 else "seg"
	var holes: Array = []
	for k in range(n):
		holes.append(ZK._arch_hole((float(k) + 0.5) * pitch, v0, half, spring - v0, rise))
	ZK._wall(pk, kit, "brick", p0, along, out, 0.0, length, y0, y_top - 0.35, holes, BRICK, ARCH_RECESS)
	var wf := ZK._wf(p0, along, out)
	var dark: Array = o.get("dark", [])
	var share: float = o.get("shops", 0.3)
	for k in range(n):
		var cu: float = (float(k) + 0.5) * pitch
		ZK._arch_open(pk, kit, "brick", p0, along, out, cu, v0, half, spring - v0, rise, ARCH_RECESS, BRICK,
				{"trim": "brick", "trim_col": BRICK_DARK, "trim_w": 0.38, "segs": 8, "glass": false, "sill": false})
		var back: Vector3 = p0 - out * ARCH_RECESS
		var poly := PackedVector2Array([Vector2(cu - half, v0), Vector2(cu + half, v0)])
		var arc: PackedVector2Array = KT._arch(cu, spring, half, kind, 8, rise)
		for i in range(arc.size() - 1, -1, -1):
			poly.append(arc[i])
		if k in dark:
			ZK._wpoly(pk, kit, "matte", back - out * 1.5, along, out, poly, BLACK)
			# The passage's vault and walls carry on into the dark.
			var cyy: float = spring + rise - (half * half + rise * rise) / (2.0 * rise)
			for i in range(arc.size() - 1):
				var a0: Vector2 = arc[i]
				var a1: Vector2 = arc[i + 1]
				var am: Vector2 = (a0 + a1) * 0.5
				var inw: Vector3 = -(along * (am.x - cu) + UP * (am.y - cyy)).normalized()
				pk.quad(kit, "brick", [back + along * a0.x + UP * a0.y, back + along * a1.x + UP * a1.y, back + along * a1.x + UP * a1.y - out * 1.5,
						back + along * a0.x + UP * a0.y - out * 1.5], inw, BRICK_DARK)
			for sx in [-1.0, 1.0]:
				var u: float = cu + sx * half
				var n2: Vector3 = (along * -sx).normalized()
				pk.quad(kit, "brick", [back + along * u + UP * v0, back + along * u + UP * spring, back + along * u + UP * spring - out * 1.5,
						back + along * u + UP * v0 - out * 1.5], n2, BRICK_DARK, [Vector2(0, v0) * uvk, Vector2(0, spring) * uvk, Vector2(1.5, spring) * uvk,
						Vector2(1.5, v0) * uvk])
			pk.quad(kit, "stone", [back + along * (cu - half) + UP * (v0 - 0.02), back + along * (cu + half) + UP * (v0 - 0.02),
					back + along * (cu + half) + UP * (v0 - 0.02) - out * 1.5, back + along * (cu - half) + UP * (v0 - 0.02) - out * 1.5], UP, CONC.darkened(0.3))
			continue
		var r: float = rng.randf()
		var shop: Array = ARCH_SHOPS[rng.randi() % ARCH_SHOPS.size()]
		ZK._wpoly(pk, kit, "brick", back, along, out, poly, BRICK.darkened(0.12))
		if r < share:
			_arch_infill(pk, kit, labels, back, along, out, cu, v0, half, spring, rise, shop, rng)
	# Pilasters between the bays (half ones at the ends), the plinth, the corbel table and the coping.
	for k in range(n + 1):
		var uc: float = float(k) * pitch
		var ua: float = maxf(uc - ARCH_PILASTER * 0.5, 0.0)
		var ub: float = minf(uc + ARCH_PILASTER * 0.5, length)
		ZK._band(pk, kit, "brick", p0, along, out, ua, ub, ARCH_FOOT, band_lo, 0.22, BRICK_DARK)
	ZK._band(pk, kit, "ashlar", p0, along, out, 0.0, length, y0, ARCH_FOOT, 0.1, SAND_DARK)
	if o.get("frieze", true):
		ZK._frieze(pk, kit, "brick", p0, along, out, 0.0, length, y_top - 0.35, 0.45, o.get("frieze_pitch", 1.5), 0.12, BRICK_DARK)
	var cb: float = o.get("cope_back", 0.5)
	KT._prism(pk, kit, "ashlar", wf, PackedVector2Array([Vector2(0.0, y_top - 0.35), Vector2(length, y_top - 0.35), Vector2(length, y_top + 0.15),
			Vector2(0.0, y_top + 0.15)]), -cb, 0.2, SAND, Vector2(0, 1), true)


## What fills a workshop's arch, on its back face (`back`, the recess's plane): a roller door or a shop front (a window,
## a glazed door) under a fascia with the name, the arch above it a fanlight with glazing bars.
static func _arch_infill(pk: PropKit, kit: Dictionary, labels: Array, back: Vector3, along: Vector3, out: Vector3, cu: float, v0: float, half: float,
		spring: float, rise: float, shop: Array, rng: RandomNumberGenerator) -> void:
	var wf := ZK._wf(back, along, out)
	var kind: String = shop[1]
	var top: float = minf(spring - 0.15, v0 + 3.6)
	var fascias: Array = [Color(0.12, 0.25, 0.42), Color(0.45, 0.10, 0.10), Color(0.15, 0.32, 0.20), Color(0.20, 0.20, 0.22), Color(0.55, 0.40, 0.12)]
	var fascia: Color = fascias[rng.randi() % fascias.size()]
	var w: float = half * 2.0 - 0.5
	if kind == "garage":
		var col := Color(0.58, 0.60, 0.60) if rng.randf() < 0.6 else Color(0.30, 0.42, 0.50)
		_face(pk, kit, "paint", wf, cu - w * 0.5, v0, cu + w * 0.5, top - 0.25, 0.03, col)
		var nl: int = int((top - 0.25 - v0) / 0.25)
		for k in range(nl):
			var y: float = v0 + 0.12 + float(k) * 0.25
			_face(pk, kit, "paint", wf, cu - w * 0.5 + 0.02, y, cu + w * 0.5 - 0.02, y + 0.04, 0.045, col.darkened(0.2))
		_rect(pk, kit, "steel", wf, cu - w * 0.5 - 0.08, v0, cu - w * 0.5, top - 0.25, 0.0, 0.08, STEEL_DARK)
		_rect(pk, kit, "steel", wf, cu + w * 0.5, v0, cu + w * 0.5 + 0.08, top - 0.25, 0.0, 0.08, STEEL_DARK)
		_rect(pk, kit, "steel", wf, cu - w * 0.5 - 0.08, top - 0.25, cu + w * 0.5 + 0.08, top, 0.0, 0.14, STEEL_DARK)
	else:
		# A shop front: a window and a glazed door in a painted frame.
		var dw := 1.1
		var du: float = cu + w * 0.5 - dw * 0.5 - 0.1
		_face(pk, kit, "pane", wf, cu - w * 0.5 + 0.1, v0 + 0.6, du - dw * 0.5 - 0.12, top - 0.1, 0.025, GLASS_DARK)
		_face(pk, kit, "pane", wf, du - dw * 0.5 + 0.08, v0 + 0.05, du + dw * 0.5 - 0.08, top - 0.1, 0.025, GLASS_DARK.lightened(0.04))
		KT._ring_rect(pk, kit, "painted", wf, cu - w * 0.5, v0, cu + w * 0.5, top, 0.1, 0.0, 0.06, fascia.darkened(0.3))
		_face(pk, kit, "painted", wf, du - dw * 0.5 - 0.12, v0 + 0.1, du - dw * 0.5, top - 0.1, 0.045, fascia.darkened(0.3))
		_face(pk, kit, "painted", wf, cu - w * 0.5 + 0.1, v0 + 0.1, du - dw * 0.5 - 0.12, v0 + 0.6, 0.04, fascia.darkened(0.3))
	# The fascia with the name across the springing, a fanlight in the arch over it.
	_rect(pk, kit, "enamel", wf, cu - half + 0.05, top, cu + half - 0.05, top + 0.5, 0.0, 0.07, fascia)
	# A store is a store ("Lager"); every workshop has a name of its own (ShopNames).
	var sname: String = String(shop[0]) if String(shop[0]) == "Lager" else ShopNames.unique(String(shop[1]), String(shop[0]))
	_lbl(labels, sname, wf * Vector3(cu, top + 0.25, 0.085), out, 0.24, Color(0.96, 0.95, 0.9), half * 2.0 - 0.4)
	var round_arch: bool = absf(rise - half) < 0.01
	var arc: PackedVector2Array = KT._arch(cu, spring, half - 0.12, "round" if round_arch else "seg", 8, maxf(rise - 0.12, 0.2))
	var fan := PackedVector2Array([Vector2(cu - half + 0.12, top + 0.55), Vector2(cu + half - 0.12, top + 0.55)])
	for i in range(arc.size() - 1, -1, -1):
		var ap: Vector2 = arc[i]
		fan.append(Vector2(ap.x, maxf(ap.y, top + 0.56)))
	KT._pface(pk, kit, "pane", wf, fan, 0.02, GLASS_DARK)
	for k in range(1, 4):
		var uu: float = lerpf(cu - half + 0.12, cu + half - 0.12, float(k) / 4.0)
		var hy: float = KT._arch_height(arc, uu)
		if hy > top + 0.6:
			_face(pk, kit, "painted", wf, uu - 0.025, top + 0.55, uu + 0.025, hy, 0.04, fascia.darkened(0.4))


# ======================================================================================
#  The walled railway embankment
# ======================================================================================

## A walled railway embankment along x from 0 to `length`, centred on z = 0: Ruhr brick retaining walls on both faces
## (|z| = half_width) from y -1.5 up to its flat top at y = h, with pilasters and blind arches every ~8m, some filled as
## workshops and garages (roller doors, shop fronts, fanlights, a name on a fascia: `labels`), a sandstone plinth, a
## corbel table and a sandstone coping (outer face 0.2 proud, top 0.15 over h, 0.5 deep). The top between the copings
## is a plain dark surface at y = h for the caller's ballast and track. `caps` closes the ends (1: x = 0, 2: x = length,
## 3: both); leave them open where a piece butts another piece, the station or the bridge. `seed` picks the workshops.
static func rail_embankment(pk: PropKit, kit: Dictionary, length := 100.0, h := 7.5, half_width := 8.0, seed := 0, caps := 0, labels := []) -> void:
	for side in [1.0, -1.0]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed * 31 + (1 if side > 0.0 else 2)
		var p0: Vector3 = Vector3(0, 0, half_width) if side > 0.0 else Vector3(length, 0, -half_width)
		_arch_wall(pk, kit, p0, Vector3.RIGHT * side, Vector3(0, 0, side), length, h, {"rng": rng, "labels": labels, "shops": 0.3})
	var hw: float = half_width - 0.5
	_uvquad(pk, kit, "grime", Vector3(0, h, hw), Vector3(length, h, hw), Vector3(length, h, -hw), Vector3(0, h, -hw), UP, Color(0.36, 0.34, 0.31))
	for e in [[1, 0.0, -1.0], [2, length, 1.0]]:
		if (caps & int(e[0])) == 0:
			continue
		var x: float = e[1]
		var o := Vector3(float(e[2]), 0, 0)
		var p0e: Vector3 = Vector3(x, 0, half_width) if float(e[2]) < 0.0 else Vector3(x, 0, -half_width)
		var al: Vector3 = Vector3(0, 0, -1) if float(e[2]) < 0.0 else Vector3(0, 0, 1)
		_arch_wall(pk, kit, p0e, al, o, half_width * 2.0, h, {"bay": 8.0, "shops": 0.0})


## The embankment's collision: one box over its body and copings.
static func rail_embankment_solids(length := 100.0, h := 7.5, half_width := 8.0) -> Array:
	return [[Transform3D(Basis(), Vector3(length * 0.5, (h + 0.15 - 1.5) * 0.5, 0)), Vector3(length, h + 0.15 + 1.5, half_width * 2.0 + 0.44)]]


# ======================================================================================
#  The railway bridge (a riveted plate-girder trough bridge)
# ======================================================================================

const BR_ABUT := 4.0         # an abutment's length along x behind its face
## How far (life metres) each abutment stands out past the opening on each side: embankments butt at |x| = span/2 + this.
const BRIDGE_ABUTMENT := BR_ABUT
const BR_HW := 8.6           # the abutments' half width (z): 0.6 past a default embankment's walls
const BR_WING := 3.0         # the wing walls' reach along the street past BR_HW
const BR_WING_TOP := 2.6     # the wing walls' ends' height
const BR_GZ := 5.4           # the main girders' webs (z)
const BR_DEPTH := 2.4        # the main girders' depth
const BR_BEAR := 0.55        # how far the girders reach onto each abutment
const BR_STEEL := Color(0.33, 0.40, 0.37)


## Where rail_embankment pieces butt against a bridge of this span: x = +-(span/2 + BRIDGE_ABUTMENT), the same h,
## half_width up to 8.0 (the abutments' sides at z +-BR_HW cover the joint).
static func railway_bridge_ends(span := 14.5) -> float:
	return span * 0.5 + BR_ABUT


## A riveted steel plate-girder trough bridge carrying two tracks along x over a street running along z. The clear
## opening between the brick abutments' faces is x = +-span/2; the girders' and floor beams' undersides are at h - 0.5
## (7.0 for the default h) across the whole opening; the deck (the trough's ballast top) is flat at y = h between the
## main girders' webs (z +-BR_GZ = 5.4) and on the abutments behind them, so tracks laid at h run on from the
## embankments. The main girders stand BR_DEPTH (2.4) deep: their tops 1.9 over the deck with handrails on them.
## Abutments: x from +-span/2 to +-(span/2 + BRIDGE_ABUTMENT), z +-BR_HW, y -1.5..h, Ruhr brick, a sandstone bearing
## shelf, steel bearings, a sandstone coping; wing walls in the faces' planes run BR_WING further out along the street
## (|z| 8.6..11.6), falling to BR_WING_TOP, with quoins at their ends. Paint grey-green, rivets in the shader, a
## yellow-and-black band and a round clearance sign ("7,0 m") on both outer faces over the street.
## Joining the embankment: on the +x side a rail_embankment piece with its origin at (railway_bridge_ends(span), 0, 0)
## running +x; on the -x side a piece turned 180 degrees about y with its origin at (-railway_bridge_ends(span), 0, 0)
## (or unturned with its origin at -railway_bridge_ends(span) - length). Same h, caps 0 at the joint.
static func railway_bridge(pk: PropKit, kit: Dictionary, labels: Array, span := 14.5, h := 7.5) -> void:
	var hs: float = span * 0.5
	var yb: float = h - 0.5
	var gl: float = hs + BR_BEAR
	for s in [-1.0, 1.0]:
		_bridge_abutment(pk, kit, labels, s, hs, h, yb)
	# Main girders: web, flanges, a cover plate, stiffeners, end posts, handrails.
	for gz in [-BR_GZ, BR_GZ]:
		var so: float = signf(gz)
		_box(pk, kit, "rivet", Vector3(0, yb + BR_DEPTH * 0.5, gz), Basis(), Vector3(gl * 2.0, BR_DEPTH - 0.1, 0.04), BR_STEEL)
		_box(pk, kit, "rivet", Vector3(0, yb + 0.025, gz), Basis(), Vector3(gl * 2.0, 0.05, 0.55), BR_STEEL.darkened(0.05))
		_box(pk, kit, "rivet", Vector3(0, yb + BR_DEPTH - 0.025, gz), Basis(), Vector3(gl * 2.0, 0.05, 0.55), BR_STEEL.darkened(0.05))
		_box(pk, kit, "rivet", Vector3(0, yb + BR_DEPTH + 0.015, gz), Basis(), Vector3(span * 0.66, 0.03, 0.5), BR_STEEL.darkened(0.08))
		var nst: int = int(floor(gl / 1.5))
		for k in range(-nst, nst + 1):
			var x: float = float(k) * 1.5
			var heavy: bool = absf(absf(x) - hs) < 0.8
			for f in [-1.0, 1.0]:
				pk.beam(kit, "steel", Vector3(x, yb + 0.05, gz + f * 0.09), Vector3(x, yb + BR_DEPTH - 0.05, gz + f * 0.09), 0.14, 0.03 if heavy else 0.014,
						BR_STEEL.darkened(0.06), Vector3(0, 0, 1))
		for e in [-1.0, 1.0]:
			_box(pk, kit, "steel", Vector3(e * (gl - 0.02), yb + BR_DEPTH * 0.5, gz), Basis(), Vector3(0.04, BR_DEPTH, 0.56), BR_STEEL.darkened(0.1))
		# The handrail on the top flange's outer edge.
		var rz: float = gz + so * 0.2
		var np: int = int(ceil(gl * 2.0 / 1.6))
		for k in range(np + 1):
			var px: float = lerpf(-gl + 0.1, gl - 0.1, float(k) / float(np))
			pk.beam(kit, "steel", Vector3(px, yb + BR_DEPTH, rz), Vector3(px, yb + BR_DEPTH + 1.0, rz), 0.05, 0.05, BR_STEEL)
		pk.beam(kit, "steel", Vector3(-gl, yb + BR_DEPTH + 1.0, rz), Vector3(gl, yb + BR_DEPTH + 1.0, rz), 0.07, 0.06, BR_STEEL, UP)
		pk.beam(kit, "steel", Vector3(-gl, yb + BR_DEPTH + 0.5, rz), Vector3(gl, yb + BR_DEPTH + 0.5, rz), 0.05, 0.05, BR_STEEL, UP)
		# A yellow-and-black band along the bottom of the outer face, the clearance sign over the street's middle.
		var fz: float = gz + so * 0.026
		_uvquad(pk, kit, "hazard", Vector3(-hs, yb + 0.06, fz), Vector3(hs, yb + 0.06, fz), Vector3(hs, yb + 0.42, fz), Vector3(-hs, yb + 0.42, fz),
				Vector3(0, 0, so), WHITE)
		var sc := Vector3(0.75, yb + 1.15, gz + so * 0.05)
		var sn := Vector3(0, 0, so)
		_disc(pk, kit, "enamel", sc, sn, 0.42, 20, Color(0.80, 0.08, 0.07))
		_disc(pk, kit, "enamel", sc + sn * 0.006, sn, 0.33, 20, Color(0.97, 0.97, 0.95))
		var sr: Vector3 = UP.cross(sn).normalized()
		for ty in [1.0, -1.0]:
			var tb: Vector3 = sc + sn * 0.012 + UP * (ty * 0.13)
			pk.tri(kit, "enamel", tb, tb + UP * (ty * 0.1) - sr * 0.07, tb + UP * (ty * 0.1) + sr * 0.07, sn, sn, sn, BLACK, sn)
		_lbl(labels, "7,0 m", sc + sn * 0.014, sn, 0.13, BLACK, 0.55)
	# The trough: floor beams under a deck plate, the ballast's top at h between the webs.
	var iz: float = BR_GZ - 0.03
	var nfb: int = int(floor(gl / 1.5))
	for k in range(-nfb, nfb + 1):
		var x2: float = float(k) * 1.5 + 0.75
		if absf(x2) > gl - 0.2:
			continue
		_box(pk, kit, "rivet", Vector3(x2, yb + 0.22, 0), Basis(), Vector3(0.05, 0.36, iz * 2.0), BR_STEEL.darkened(0.12))
		_box(pk, kit, "steel", Vector3(x2, yb + 0.02, 0), Basis(), Vector3(0.3, 0.04, iz * 2.0 - 0.02), BR_STEEL.darkened(0.15))
	_box(pk, kit, "rivet", Vector3(0, yb + 0.43, 0), Basis(), Vector3(gl * 2.0, 0.06, iz * 2.0), BR_STEEL.darkened(0.2))
	_blk(pk, kit, "grime", Vector3(-gl, yb + 0.46, -iz), Vector3(gl, h, iz), Color(0.36, 0.34, 0.31))


## One abutment (s = +1: the +x side) and its two wing walls.
static func _bridge_abutment(pk: PropKit, kit: Dictionary, labels: Array, s: float, hs: float, h: float, yb: float) -> void:
	var fx: float = s * hs
	var bx: float = s * (hs + BR_ABUT)
	var out := Vector3(-s, 0, 0)
	var along := Vector3(0, 0, s)
	var p0 := Vector3(fx, 0, -s * BR_HW)
	var shelf: float = yb - 0.15
	# The face under the bearing shelf, the ballast wall over it set back behind the girders' ends.
	ZK._mq(pk, kit, "brick", p0, along, out, 0.0, BR_HW * 2.0, -1.5, shelf - 0.4, BRICK)
	var bwx: float = fx + s * (BR_BEAR + 0.05)
	ZK._mq(pk, kit, "brick", Vector3(bwx, 0, -s * BR_HW), along, out, 0.0, BR_HW * 2.0, shelf, h, BRICK)
	var wfe := ZK._wf(p0, along, out)
	# The sandstone band under the shelf, running 4cm past both sides (ending flush, its ends lay in the brick side walls'
	# planes and flickered).
	KT._prism(pk, kit, "ashlar", wfe, PackedVector2Array([Vector2(-0.04, shelf - 0.4), Vector2(BR_HW * 2.0 + 0.04, shelf - 0.4), Vector2(BR_HW * 2.0 + 0.04, shelf),
			Vector2(-0.04, shelf)]), -0.2, 0.32, SAND, Vector2(0, 1), false)
	pk.quad(kit, "ashlar", [Vector3(fx + s * 0.2, shelf, -BR_HW), Vector3(fx + s * 0.2, shelf, BR_HW), Vector3(bwx, shelf, BR_HW), Vector3(bwx, shelf, -BR_HW)],
			UP, SAND.darkened(0.05))
	for gz in [-BR_GZ, BR_GZ]:
		_box(pk, kit, "steel", Vector3(fx + s * 0.28, shelf + 0.075, gz), Basis(), Vector3(0.45, 0.15, 0.7), STEEL_DARK)
	# The sides (z = +-BR_HW) with their coping, the top behind the ballast wall, the back strips beside the embankment.
	for sz in [-1.0, 1.0]:
		var po: Vector3 = Vector3(bx, 0, sz * BR_HW) if sz * s > 0.0 else Vector3(fx, 0, sz * BR_HW)
		var al: Vector3 = Vector3(-s, 0, 0) if sz * s > 0.0 else Vector3(s, 0, 0)
		ZK._mq(pk, kit, "brick", po, al, Vector3(0, 0, sz), 0.0, BR_ABUT, -1.5, h - 0.35, BRICK)
		# The coping runs 4cm past the bridge's face (flush, its end lay in the face and the wing wall and flickered).
		# (From po along al: with sz * s > 0 it starts at the back and ends at the face, u = BR_ABUT; else it starts at the face.)
		var c0: float = 0.0 if sz * s > 0.0 else -0.04
		var c1: float = BR_ABUT + 0.04 if sz * s > 0.0 else BR_ABUT
		KT._prism(pk, kit, "ashlar", ZK._wf(po, al, Vector3(0, 0, sz)), PackedVector2Array([Vector2(c0, h - 0.35), Vector2(c1, h - 0.35),
				Vector2(c1, h + 0.15), Vector2(c0, h + 0.15)]), -0.6, 0.2, SAND, Vector2(0, 1), true)
	pk.quad(kit, "grime", [Vector3(bwx, h, -BR_HW + 0.6), Vector3(bwx, h, BR_HW - 0.6), Vector3(bx, h, BR_HW - 0.6), Vector3(bx, h, -BR_HW + 0.6)], UP,
			Color(0.36, 0.34, 0.31))
	for sz2 in [-1.0, 1.0]:
		ZK._mq(pk, kit, "brick", Vector3(bx, 0, sz2 * 7.6), Vector3(0, 0, sz2), Vector3(s, 0, 0), 0.0, 1.0, -1.5, h - 0.35, BRICK)
	# The wing walls, in the face's plane, falling to BR_WING_TOP, 0.9 thick, with a sloped coping and quoins at the end.
	for sz3 in [-1.0, 1.0]:
		# Starting 5cm inside the abutment: flush, the wing's end and its coping's end lay in the abutment's side face
		# (z = +-BR_HW) and flickered against its brick.
		var u0: float = BR_HW * 2.0 - 0.05 if sz3 * s > 0.0 else -BR_WING
		var u1: float = BR_HW * 2.0 + BR_WING if sz3 * s > 0.0 else 0.05
		var top0: float = h - 0.2 if sz3 * s > 0.0 else BR_WING_TOP
		var top1: float = BR_WING_TOP if sz3 * s > 0.0 else h - 0.2
		KT._prism(pk, kit, "brick", wfe, PackedVector2Array([Vector2(u0, -1.5), Vector2(u1, -1.5), Vector2(u1, top1), Vector2(u0, top0)]), -0.9, 0.0, BRICK,
				Vector2(0, 1), true, true)
		# The sloped coping, 4cm past the wing's free end (flush, its end lay in the brick's end and flickered).
		var cu0: float = u0 if sz3 * s > 0.0 else u0 - 0.04
		var cu1: float = u1 + 0.04 if sz3 * s > 0.0 else u1
		KT._prism(pk, kit, "ashlar", wfe, PackedVector2Array([Vector2(cu0, top0 - 0.3), Vector2(cu1, top1 - 0.3), Vector2(cu1, top1 + 0.12),
				Vector2(cu0, top0 + 0.12)]), -1.0, 0.12, SAND, Vector2(0, 1), true)
		var endz: float = sz3 * (BR_HW + BR_WING)
		_quoins(pk, kit, Vector3(fx, 0, endz), Vector3(s, 0, 0), Vector3(0, 0, -sz3), -1.5, BR_WING_TOP - 0.3, 0.9, 0.9)
		if sz3 > 0.0 and s > 0.0:
			var tw: Vector3 = wfe * Vector3(u0 + BR_WING * 0.5, 1.6, 0.0)
			_box(pk, kit, "ashlar", tw + out * 0.05, Basis(along, UP, out), Vector3(1.4, 0.5, 0.1), SAND_LIGHT)
			_lbl(labels, "1912", tw + out * 0.105, out, 0.24, CARVED, 1.2)


## Sandstone quoins up a corner from y0 to y1: courses about 0.45 tall, alternately long along the face that `dir_a` runs
## along (away from the corner) and along the face `dir_b` runs along, standing 4cm proud of both. `max_b` caps the run
## along b; `thick` > 0 runs every course right through a wall that thick (a free-standing wall's end), proud both sides.
static func _quoins(pk: PropKit, kit: Dictionary, corner: Vector3, dir_a: Vector3, dir_b: Vector3, y0: float, y1: float, max_b := 0.9, thick := 0.0) -> void:
	var n: int = int((y1 - y0) / 0.45)
	if n < 1:
		return
	var ch: float = (y1 - y0) / float(n)
	for k in range(n):
		var la: float = (0.9 if k % 2 == 0 else 0.45) if thick <= 0.0 else thick + 0.04
		var lb: float = minf(0.45 if k % 2 == 0 else 0.9, max_b)
		var c: Vector3 = corner + dir_a * ((la - 0.04) * 0.5) + dir_b * ((lb - 0.04) * 0.5) + UP * (y0 + ch * (float(k) + 0.5))
		_box(pk, kit, "ashlar", c, Basis(dir_a, UP, dir_b), Vector3(la + 0.04, ch - 0.02, lb + 0.04), SAND_LIGHT if k % 2 == 0 else SAND)


## The bridge's collision: the abutments, the wing walls, the girders and the trough (life size, in its frame).
static func railway_bridge_solids(span := 14.5, h := 7.5) -> Array:
	var hs: float = span * 0.5
	var yb: float = h - 0.5
	var out: Array = []
	for s in [-1.0, 1.0]:
		out.append([Transform3D(Basis(), Vector3(s * (hs + BR_ABUT * 0.5), (h - 1.5) * 0.5, 0)), Vector3(BR_ABUT, h + 1.5, BR_HW * 2.0)])
		for sz in [-1.0, 1.0]:
			out.append([Transform3D(Basis(), Vector3(s * (hs + 0.45), (h - 1.5) * 0.5, sz * (BR_HW + BR_WING * 0.5))), Vector3(0.9, h + 1.5, BR_WING)])
	for gz in [-BR_GZ, BR_GZ]:
		out.append([Transform3D(Basis(), Vector3(0, yb + BR_DEPTH * 0.5 + 0.5, gz)), Vector3(span + BR_BEAR * 2.0, BR_DEPTH + 1.0, 0.6)])
	out.append([Transform3D(Basis(), Vector3(0, yb + 0.25, 0)), Vector3(span + BR_BEAR * 2.0, 0.5, BR_GZ * 2.0)])
	return out


# ======================================================================================
#  Plants and small parts shared by the street furniture
# ======================================================================================

const ANTHRACITE := Color(0.20, 0.21, 0.22)
const RUST := Color(0.48, 0.25, 0.13)
const SOIL := Color(0.16, 0.11, 0.08)
const BARK := Color(0.30, 0.25, 0.20)
const PLANT_GREENS := [Color(0.24, 0.42, 0.16), Color(0.30, 0.47, 0.18), Color(0.20, 0.36, 0.15), Color(0.34, 0.50, 0.22)]
const BLOOMS := [Color(0.90, 0.15, 0.20), Color(0.95, 0.75, 0.15), Color(0.62, 0.30, 0.75), Color(0.96, 0.95, 0.92), Color(0.95, 0.45, 0.10)]
const BIKE_COLS := [Color(0.12, 0.30, 0.55), Color(0.75, 0.12, 0.10), Color(0.15, 0.15, 0.16), Color(0.85, 0.85, 0.82), Color(0.20, 0.45, 0.25)]


## A smooth ellipsoid at c with radii r (a stretched sphere through PropKit.lathe), `segs` round, `rings` up.
static func _ellipsoid(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: Vector3, segs: int, rings: int, col: Color) -> void:
	var prof: Array = []
	for k in range(rings + 1):
		var a: float = -PI * 0.5 + PI * float(k) / float(rings)
		prof.append(Vector2(maxf(cos(a), 0.001), sin(a)))
	pk.lathe(kit, key, c, prof, segs, col, false, Basis.from_scale(r))


## A tree's crown round c, about r across its middle: a few leafy lumps ("leaf", two-sided) in shades of `col`.
static func _crown_lumps(pk: PropKit, kit: Dictionary, c: Vector3, r: float, col: Color, rng: RandomNumberGenerator, n := 5) -> void:
	_ellipsoid(pk, kit, "leaf", c, Vector3(r * 0.78, r * 0.72, r * 0.78), 8, 5, col)
	for k in range(n - 1):
		var a: float = TAU * float(k) / float(n - 1) + rng.randf() * 0.6
		var d := Vector3(cos(a), 0, sin(a))
		var rr: float = r * rng.randf_range(0.42, 0.55)
		var p: Vector3 = c + d * r * 0.48 + Vector3(0, rng.randf_range(-0.25, 0.3) * r, 0)
		_ellipsoid(pk, kit, "leaf", p, Vector3(rr, rr * 0.85, rr), 7, 4, col.darkened(rng.randf_range(-0.06, 0.14)))


## A clump of grass blades standing on c (`n` blades up to h tall, leaning out), two-sided ("leaf").
static func _grass_clump(pk: PropKit, kit: Dictionary, c: Vector3, h: float, n: int, col: Color, rng: RandomNumberGenerator) -> void:
	for k in range(n):
		var a: float = TAU * float(k) / float(n) + rng.randf() * 0.5
		var d := Vector3(cos(a), 0, sin(a))
		var side: Vector3 = UP.cross(d).normalized()
		var tip: Vector3 = c + d * h * rng.randf_range(0.25, 0.5) + UP * h * rng.randf_range(0.7, 1.0)
		var b: Vector3 = c + d * 0.03
		var nn: Vector3 = (d + UP * 0.3).normalized()
		pk.tri(kit, "leaf", b - side * 0.018, b + side * 0.018, tip, nn, nn, nn, col.lightened(rng.randf_range(0.0, 0.18)), nn)


## A few flowers (little diamonds) scattered round c within r, at height y over it.
static func _flowers(pk: PropKit, kit: Dictionary, c: Vector3, r: float, n: int, rng: RandomNumberGenerator, y := 0.25) -> void:
	var bloom: Color = BLOOMS[rng.randi() % BLOOMS.size()]
	for k in range(n):
		var a: float = rng.randf() * TAU
		var rr: float = sqrt(rng.randf()) * r
		var p: Vector3 = c + Vector3(cos(a) * rr, y * rng.randf_range(0.6, 1.1), sin(a) * rr)
		KT._blob(pk, kit, "leaf", p, Vector3(0.045, 0.03, 0.045), bloom.darkened(rng.randf() * 0.15))


## A box's four walls (each `t` thick) round the rectangle x +-hx, z +-hz from y0 to y1, open on top: a planter's or a
## trough's body. The side walls stop 5mm inside the front and back walls, so no end face lies in their inner planes.
static func _open_box(pk: PropKit, kit: Dictionary, key: String, hx: float, hz: float, y0: float, y1: float, t: float, col: Color, c := Vector3.ZERO) -> void:
	_blk(pk, kit, key, c + Vector3(-hx, y0, hz - t), c + Vector3(hx, y1, hz), col)
	_blk(pk, kit, key, c + Vector3(-hx, y0, -hz), c + Vector3(hx, y1, -hz + t), col)
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, key, c + Vector3(sx * (hx - t), y0, -hz + t - 0.005), c + Vector3(sx * hx, y1, hz - t + 0.005), col)


# ======================================================================================
#  The pedestrian zone's furniture
# ======================================================================================

## A planter (Pflanzkübel) centred on the origin: its body 1.4m square and 0.72m high (inside the generator's 1.5m box),
## picked by `seed`: a Corten steel one with a little ball-crowned maple, a concrete one with a slatted seat along its
## front (+z) and shrubs, or an anthracite steel one with ornamental grasses; flowers in all of them.
static func planter(pk: PropKit, kit: Dictionary, seed := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var style: int = rng.randi() % 3
	var h := 0.72
	var hx := 0.7
	var soil_y := 0.62
	match style:
		0:
			_open_box(pk, kit, "corten", hx, hx, -0.2, h, 0.03, RUST)
		1:
			_open_box(pk, kit, "concrete", hx, hx, -0.2, h, 0.09, CONC.lightened(0.08))
			# The seat: five oak slats on bearers across the front wall's top, 1cm over it.
			for k in range(5):
				var z: float = 0.36 + 0.078 * float(k)
				_blk(pk, kit, "timber", Vector3(-hx + 0.02, h + 0.035, z), Vector3(hx - 0.02, h + 0.075, z + 0.064), Color(0.58, 0.42, 0.26))
			for bx in [-0.5, 0.0, 0.5]:
				_blk(pk, kit, "steel", Vector3(bx - 0.03, h + 0.002, 0.34), Vector3(bx + 0.03, h + 0.035, 0.74), ANTHRACITE)
		_:
			_open_box(pk, kit, "paint", hx, hx, -0.2, h, 0.03, ANTHRACITE)
			# A rolled lip round the top, 1.5cm proud.
			for sz in [-1.0, 1.0]:
				_blk(pk, kit, "paint", Vector3(-hx - 0.015, h - 0.05, sz * hx - 0.02), Vector3(hx + 0.015, h + 0.012, sz * hx + 0.02), ANTHRACITE.lightened(0.05))
				_blk(pk, kit, "paint", Vector3(sz * hx - 0.02, h - 0.05, -hx + 0.02), Vector3(sz * hx + 0.02, h + 0.012, hx - 0.02), ANTHRACITE.lightened(0.05))
	var inner: float = hx - (0.09 if style == 1 else 0.03)
	pk.quad(kit, "matte", [Vector3(-inner, soil_y, -inner), Vector3(inner, soil_y, -inner), Vector3(inner, soil_y, inner), Vector3(-inner, soil_y, inner)], UP, SOIL)
	var green: Color = PLANT_GREENS[rng.randi() % PLANT_GREENS.size()]
	match style:
		0:
			pk.tube(kit, "wood", Vector3(0, soil_y - 0.05, 0), Vector3(0, 2.1, 0), 0.065, 0.045, 7, BARK, false)
			for k in range(3):
				var a: float = TAU * float(k) / 3.0 + 0.4
				pk.tube(kit, "wood", Vector3(0, 1.95, 0), Vector3(cos(a) * 0.25, 2.45, sin(a) * 0.25), 0.04, 0.025, 5, BARK, false)
			_crown_lumps(pk, kit, Vector3(0, 2.62, 0), 0.82, green, rng)
			# A tree guard: three stakes and a band.
			for k in range(3):
				var a2: float = TAU * float(k) / 3.0
				pk.tube(kit, "wood", Vector3(cos(a2) * 0.32, soil_y - 0.1, sin(a2) * 0.32), Vector3(cos(a2) * 0.3, 1.5, sin(a2) * 0.3), 0.03, 0.03, 5,
						Color(0.62, 0.48, 0.30), true)
			_flowers(pk, kit, Vector3(0, soil_y, 0), inner - 0.08, 18, rng, 0.12)
		1:
			KT._bush(pk, kit, Vector3(-0.3, soil_y, -0.32), 0.42, green, rng)
			KT._bush(pk, kit, Vector3(0.3, soil_y, -0.25), 0.36, green.darkened(0.1), rng)
			_flowers(pk, kit, Vector3(0, soil_y, 0.05), inner - 0.1, 22, rng, 0.18)
		_:
			for k in range(5):
				var a3: float = TAU * float(k) / 5.0 + rng.randf() * 0.4
				var p: Vector3 = Vector3(cos(a3) * 0.36, soil_y, sin(a3) * 0.36) if k > 0 else Vector3(0, soil_y, 0)
				_grass_clump(pk, kit, p, rng.randf_range(0.6, 0.95), 16, Color(0.52, 0.56, 0.30) if k % 2 == 0 else green, rng)
			_flowers(pk, kit, Vector3(0, soil_y, 0), inner - 0.06, 14, rng, 0.35)


## A row of `n` galvanised bike hoops (Anlehnbügel) 1m apart along x centred on the origin, each standing along z, with
## bicycles leant on two of every three (life size: x from -(n-1)/2 - 0.3 to (n-1)/2 + 0.5, z within +-0.9).
static func bike_rack(pk: PropKit, kit: Dictionary, n := 5) -> void:
	var x0: float = -float(n - 1) * 0.5
	for i in range(n):
		var x: float = x0 + float(i)
		var pts: Array = [Vector3(x, -0.25, -0.38), Vector3(x, 0.6, -0.38)]
		for k in range(1, 6):
			var a: float = PI * float(k) / 6.0
			pts.append(Vector3(x, 0.6 + sin(a) * 0.22, -cos(a) * 0.38))
		pts.append(Vector3(x, 0.6, 0.38))
		pts.append(Vector3(x, -0.25, 0.38))
		KT._tube_path(pk, kit, "metal", pts, 0.025, 7, GALV)
		pk.beam(kit, "metal", Vector3(x, 0.3, -0.36), Vector3(x, 0.3, 0.36), 0.045, 0.022, GALV, UP)
		# A ground plate round each foot.
		for fz in [-0.38, 0.38]:
			pk.lathe(kit, "metal", Vector3(x, 0.0, fz), [Vector2(0.001, 0.0), Vector2(0.07, 0.0), Vector2(0.07, 0.012), Vector2(0.001, 0.015)], 8, GALV.darkened(0.2), true)
		if i % 3 != 1:
			var along := Vector3(0, 0, 1.0 if i % 2 == 0 else -1.0)
			RS._bicycle(pk, kit, Vector3(x + 0.17, 0.0, 0.04 * along.z), along, BIKE_COLS[i % BIKE_COLS.size()])


## A cast-iron bollard (KronburgTownKit's) on the origin.
static func bollard(pk: PropKit, kit: Dictionary) -> void:
	KT.bollard(pk, kit)


const CAFES := [
	["CAFE KRONE", Color(0.42, 0.10, 0.12), Color(0.94, 0.90, 0.80)],
	["EISCAFE DOLOMITI", Color(0.10, 0.36, 0.30), Color(0.96, 0.86, 0.62)],
	["CAFE AM BRUNNEN", Color(0.16, 0.22, 0.38), Color(0.92, 0.92, 0.88)],
	["BISTRO ROSA", Color(0.55, 0.20, 0.30), Color(0.98, 0.84, 0.86)],
	["BACKSTUBE OHM", Color(0.36, 0.24, 0.14), Color(0.95, 0.80, 0.42)],
	["KAFFEEHAUS LINDE", Color(0.20, 0.32, 0.16), Color(0.90, 0.92, 0.82)],
]

## A café table (a square top on a pedestal) at c on the floor with chairs facing it from -z and +z (`chairs` 2) or all
## four sides (4).
static func _cafe_table(pk: PropKit, kit: Dictionary, c: Vector3, top_col: Color, chair_col: Color, chairs := 2) -> void:
	pk.lathe(kit, "metal", c, [Vector2(0.24, 0.0), Vector2(0.24, 0.02), Vector2(0.05, 0.06), Vector2(0.035, 0.72), Vector2(0.001, 0.72)], 8, ANTHRACITE)
	_blk(pk, kit, "paint", c + Vector3(-0.35, 0.715, -0.35), c + Vector3(0.35, 0.745, 0.35), top_col)
	var dirs: Array = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
	for i in range(chairs):
		var dd: Vector3 = dirs[i]
		RS._chair(pk, kit, c + dd * 0.62, -dd, chair_col)


## A café's terrace on the pavement within x +-w/2, z +-d/2 (the building's side toward -z): by `seed` a timber deck or the
## paving itself, glass wind screens on posts along the front and both ends (an opening in the front) with the café's
## colours and name printed along their foot, tables and chairs, square parasols between them, two troughs of flowers
## and an A-board by the opening.
static func cafe_terrace(pk: PropKit, kit: Dictionary, w := 5.5, d := 2.6, seed := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var cafe: Array = CAFES[rng.randi() % CAFES.size()]
	var col: Color = cafe[1]
	var pale: Color = cafe[2]
	var hw: float = w * 0.5
	var hd: float = d * 0.5
	var fy := 0.0
	if rng.randf() < 0.55:
		fy = 0.12
		# The deck: boards along x on a frame, its edge fascia.
		_blk(pk, kit, "timber", Vector3(-hw, -0.05, -hd), Vector3(hw, fy, hd), Color(0.56, 0.42, 0.28))
		var nb: int = int(d / 0.145)
		for k in range(nb):
			var z0: float = -hd + 0.02 + float(k) * (d - 0.04) / float(nb)
			_blk(pk, kit, "timber", Vector3(-hw + 0.01, fy, z0 + 0.006), Vector3(hw - 0.01, fy + 0.012, z0 + (d - 0.04) / float(nb) - 0.006), Color(0.60, 0.45, 0.30).darkened(rng.randf() * 0.1))
		fy += 0.012
	# The wind screens: posts, a glass panel, a printed foot with the café's name on the front's outside.
	var post_col := ANTHRACITE
	var screen_h := 1.15
	var gap_u: float = hw - 1.25
	var runs: Array = [
		[Vector3(-hw + 0.05, 0, hd - 0.05), Vector3(gap_u - 0.5, 0, hd - 0.05), Vector3(0, 0, 1)],
		[Vector3(gap_u + 0.5, 0, hd - 0.05), Vector3(hw - 0.05, 0, hd - 0.05), Vector3(0, 0, 1)],
		[Vector3(-hw + 0.05, 0, -hd + 0.05), Vector3(-hw + 0.05, 0, hd - 0.05), Vector3(-1, 0, 0)],
		[Vector3(hw - 0.05, 0, -hd + 0.05), Vector3(hw - 0.05, 0, hd - 0.05), Vector3(1, 0, 0)],
	]
	var name_done := false
	for run in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var out: Vector3 = run[2]
		var length: float = a.distance_to(b)
		if length < 0.3:
			continue
		var along: Vector3 = (b - a) / length
		var np: int = maxi(1, int(ceil(length / 1.3)))
		for k in range(np + 1):
			var p: Vector3 = a.lerp(b, float(k) / float(np))
			_blk(pk, kit, "metal", p + Vector3(-0.025, fy - 0.02, -0.025), p + Vector3(0.025, fy + screen_h, 0.025), post_col)
			_blk(pk, kit, "metal", p + Vector3(-0.07, fy, -0.07), p + Vector3(0.07, fy + 0.015, 0.07), post_col)
		_blk(pk, kit, "metal", a + along * -0.02 + Vector3(0, fy + screen_h - 0.01, 0) - out * 0.025 + along.cross(UP) * 0.0,
				b + along * 0.02 + Vector3(0, fy + screen_h + 0.03, 0) + out * 0.025, post_col)
		# The glass, 1cm inside the posts' faces; the printed foot on both faces of a thin panel in front of it.
		var gn: Vector3 = out
		var p0: Vector3 = a + along * 0.03 + Vector3(0, fy + 0.42, 0)
		var p1: Vector3 = b - along * 0.03 + Vector3(0, fy + 0.42, 0)
		pk.quad(kit, "sglass", [p0, p1, p1 + Vector3(0, screen_h - 0.45, 0), p0 + Vector3(0, screen_h - 0.45, 0)], gn, Color(0.78, 0.86, 0.88, 0.22))
		_box(pk, kit, "paint", (a + b) * 0.5 + Vector3(0, fy + 0.25, 0), Basis(along, UP, along.cross(UP).normalized()), Vector3(length - 0.06, 0.34, 0.02), col)
		if out.z > 0.5 and not name_done and length > 1.4:
			name_done = true
			var txt: String = cafe[0]
			var cell: float = minf(0.045, (length - 0.3) / float(_cells(txt)))
			_gtext(pk, kit, "enamel", (a + b) * 0.5 + Vector3(0, fy + 0.25, 0.03), Vector3(1, 0, 0), UP, cell, txt, pale)
	# Tables and chairs along x with square parasols between them.
	var nt: int = clampi(int(w / 1.8), 2, 4)
	var top_col: Color = [Color(0.85, 0.84, 0.80), Color(0.20, 0.20, 0.21), Color(0.55, 0.40, 0.25)][rng.randi() % 3]
	var chair_col: Color = [Color(0.18, 0.18, 0.19), Color(0.62, 0.45, 0.28), pale, Color(0.70, 0.71, 0.72)][rng.randi() % 4]
	# The tables from end to end (0.85 in from each), two parasols between them whose canvases meet but never cross.
	for k in range(nt):
		var tx: float = lerpf(-hw + 0.85, hw - 0.85, float(k) / float(maxi(nt - 1, 1)))
		_cafe_table(pk, kit, Vector3(tx, fy, -0.12), top_col, chair_col, 2)
	var pxs: Array = [-w * 0.24, w * 0.24] if w > 4.0 else [0.0]
	for k in range(pxs.size()):
		var ps: float = minf(hd - 0.12, (w * 0.24 - 0.06) if pxs.size() > 1 else hw - 0.2)
		RS._parasol(pk, kit, Vector3(float(pxs[k]), fy, -0.1), ps, pale if k % 2 == 0 else pale.darkened(0.08), col)
	# Two troughs of flowers inside the front corners, an A-board by the opening.
	for sx in [-1.0, 1.0]:
		var tc := Vector3(sx * (hw - 0.45), fy, hd - 0.32)
		_open_box(pk, kit, "paint", 0.32, 0.14, -0.01, 0.4, 0.025, col.darkened(0.3), tc)
		pk.quad(kit, "matte", [tc + Vector3(-0.29, 0.36, -0.11), tc + Vector3(0.29, 0.36, -0.11), tc + Vector3(0.29, 0.36, 0.11), tc + Vector3(-0.29, 0.36, 0.11)], UP, SOIL)
		for k in range(4):
			KT._bush(pk, kit, tc + Vector3(-0.21 + 0.14 * float(k), 0.34, 0.0), 0.11, PLANT_GREENS[k % PLANT_GREENS.size()], rng)
		_flowers(pk, kit, tc + Vector3(0, 0.36, 0), 0.24, 10, rng, 0.2)
	# The A-board (Kundenstopper) in the opening, its two chalk boards facing the street and the terrace.
	var ab := Vector3(gap_u, fy, hd - 0.24)
	for sz in [-1.0, 1.0]:
		var top: Vector3 = ab + Vector3(0, 0.92, sz * 0.012)
		var foot: Vector3 = ab + Vector3(0, 0.0, sz * 0.2)
		var n2: Vector3 = Vector3(0, 0.2, sz * 0.92).normalized()
		var sd := Vector3(0.27, 0, 0)
		var slope: Vector3 = (top - foot).normalized()
		pk.quad(kit, "wood", [foot - sd, foot + sd, top + sd, top - sd], n2, Color(0.50, 0.36, 0.22))
		pk.quad(kit, "wood", [foot + sd - n2 * 0.02, foot - sd - n2 * 0.02, top - sd - n2 * 0.02, top + sd - n2 * 0.02], -n2, Color(0.45, 0.32, 0.20))
		var c0: Vector3 = foot + slope * 0.12 + n2 * 0.012
		var c1: Vector3 = top - slope * 0.08 + n2 * 0.012
		pk.quad(kit, "matte", [c0 - sd * 0.82, c0 + sd * 0.82, c1 + sd * 0.82, c1 - sd * 0.82], n2, Color(0.08, 0.10, 0.09))


# ======================================================================================
#  The Ring: catenary masts and traffic lights
# ======================================================================================

const MAST_GREY := Color(0.36, 0.40, 0.38)
## The messenger wire's height over the contact wire (the generator's 1.1 game metres).
const MESSENGER_RISE := 1.1 / 1.6

## The contact wire's point a catenary_mast(reach, wire_y) holds (life, in the mast's frame).
static func catenary_wire_point(reach := 1.625, wire_y := 6.0) -> Vector3:
	return Vector3(-reach, wire_y, 0)


## A tram line's mast on the origin (y = 0 the median's kerb) with its cantilever reaching toward -x: a tapered steel
## mast on a concrete collar, a bracket tube with a stay over the messenger wire, a hanger and clamp holding the messenger
## MESSENGER_RISE over the contact wire, a registration arm holding the contact wire at (-reach, wire_y, 0), insulators
## next to the mast. Nothing reaches more than 0.3m toward +x.
static func catenary_mast(pk: PropKit, kit: Dictionary, reach := 1.625, wire_y := 6.0) -> void:
	var top: float = wire_y + MESSENGER_RISE + 1.35
	pk.lathe(kit, "concrete", Vector3(0, -0.6, 0), [Vector2(0.001, 0.0), Vector2(0.27, 0.0), Vector2(0.27, 0.7), Vector2(0.24, 0.74), Vector2(0.001, 0.74)], 10, CONC, true)
	pk.lathe(kit, "steel", Vector3.ZERO, [Vector2(0.001, 0.12), Vector2(0.17, 0.12), Vector2(0.17, 0.2), Vector2(0.13, 0.26), Vector2(0.001, 0.26)], 10, MAST_GREY.darkened(0.1), true)
	pk.lathe(kit, "steel", Vector3.ZERO, [Vector2(0.125, 0.1), Vector2(0.115, 0.5), Vector2(0.085, top), Vector2(0.06, top + 0.02), Vector2(0.001, top + 0.05)], 10, MAST_GREY)
	for y in [2.6, top - 0.6]:
		pk.lathe(kit, "steel", Vector3(0, y, 0), [Vector2(0.001, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.08), Vector2(0.001, 0.08)], 10, MAST_GREY.darkened(0.15), true)
	# A number plate and a reflective band.
	_box(pk, kit, "enamel", Vector3(-0.1, 2.9, 0), Basis(Vector3(0, 0, 1), UP, Vector3(-1, 0, 0)), Vector3(0.16, 0.24, 0.01), Color(0.96, 0.96, 0.94))
	_box(pk, kit, "enamel", Vector3(-0.107, 2.95, 0), Basis(Vector3(0, 0, 1), UP, Vector3(-1, 0, 0)), Vector3(0.1, 0.05, 0.004), BLACK)
	_box(pk, kit, "enamel", Vector3(-0.107, 2.85, 0), Basis(Vector3(0, 0, 1), UP, Vector3(-1, 0, 0)), Vector3(0.1, 0.05, 0.004), BLACK)
	var ym: float = wire_y + MESSENGER_RISE
	var yb: float = ym + 0.42
	var tip: float = -reach - 0.35
	# The bracket: a tube from a clamp on the mast out past the wire, a stay from higher up to two thirds along it.
	_box(pk, kit, "steel", Vector3(-0.02, yb, 0), Basis(), Vector3(0.2, 0.2, 0.26), MAST_GREY.darkened(0.2))
	pk.tube(kit, "metal", Vector3(-0.1, yb, 0), Vector3(tip, yb, 0), 0.032, 0.032, 8, GALV, true)
	var stay_a := Vector3(-0.1, yb + 0.95, 0)
	var stay_b := Vector3(-reach * 0.68, yb + 0.03, 0)
	_box(pk, kit, "steel", Vector3(-0.02, yb + 0.95, 0), Basis(), Vector3(0.2, 0.16, 0.24), MAST_GREY.darkened(0.2))
	pk.tube(kit, "metal", stay_a, stay_b, 0.022, 0.022, 6, GALV, true)
	# Insulators (brown porcelain, a few sheds) near the mast on both.
	for ins in [[Vector3(-0.32, yb, 0), Vector3(-0.62, yb, 0)], [stay_a.lerp(stay_b, 0.12), stay_a.lerp(stay_b, 0.3)]]:
		var ia: Vector3 = ins[0]
		var ib: Vector3 = ins[1]
		pk.tube(kit, "plastic", ia, ib, 0.04, 0.04, 8, Color(0.36, 0.20, 0.12), true)
		for k in range(3):
			var c: Vector3 = ia.lerp(ib, 0.2 + 0.3 * float(k))
			pk.tube(kit, "plastic", c - (ib - ia).normalized() * 0.012, c + (ib - ia).normalized() * 0.012, 0.075, 0.075, 8, Color(0.40, 0.22, 0.13), true)
	# The messenger's hanger and clamp, then a dropper down to the contact wire's clip.
	pk.tube(kit, "metal", Vector3(-reach, yb - 0.03, 0), Vector3(-reach, ym + 0.05, 0), 0.015, 0.015, 6, GALV, false)
	_box(pk, kit, "metal", Vector3(-reach, ym + 0.02, 0), Basis(), Vector3(0.06, 0.08, 0.18), GALV.darkened(0.15))
	pk.tube(kit, "metal", Vector3(-reach, ym - 0.02, 0.0), Vector3(-reach, wire_y + 0.03, 0.0), 0.006, 0.006, 4, Color(0.42, 0.34, 0.24), false)
	# The registration arm: a tube from a clamp on the mast falling gently to the contact wire, a clip on its end.
	var ra := Vector3(-0.1, wire_y + 0.32, 0)
	var rb := Vector3(-reach + 0.05, wire_y + 0.04, 0)
	_box(pk, kit, "steel", Vector3(-0.02, wire_y + 0.32, 0), Basis(), Vector3(0.2, 0.14, 0.22), MAST_GREY.darkened(0.2))
	pk.tube(kit, "metal", ra, rb, 0.018, 0.018, 6, GALV, true)
	pk.tube(kit, "plastic", ra.lerp(rb, 0.1), ra.lerp(rb, 0.28), 0.035, 0.035, 8, Color(0.36, 0.20, 0.12), true)
	_box(pk, kit, "metal", Vector3(-reach, wire_y + 0.02, 0), Basis(), Vector3(0.1, 0.05, 0.05), GALV.darkened(0.2))


const SIGNAL_GREY := Color(0.18, 0.19, 0.20)
const RED_DARK := Color(0.30, 0.04, 0.03)
const GREEN_DARK := Color(0.03, 0.18, 0.09)

## A signal head at c facing `out` (horizontal): `n` lenses one over another in a black housing with visors, a black
## backplate with a white border behind it; `lit` the index (from the top) that glows amber (-1 none); `ped` draws a
## pedestrian head's two aspects (red man, green man) instead.
static func _signal_head(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, n := 3, lit := 1, ped := false) -> void:
	var across: Vector3 = UP.cross(out).normalized()
	var bas := Basis(across, UP, out)
	var pitch := 0.3
	var hh: float = pitch * float(n) * 0.5 + 0.04
	_box(pk, kit, "matte", c, bas, Vector3(0.3, hh * 2.0, 0.22), SIGNAL_GREY)
	if not ped:
		_box(pk, kit, "matte", c - out * 0.125, bas, Vector3(0.58, hh * 2.0 + 0.26, 0.02), BLACK)
		for sx in [-1.0, 1.0]:
			_box(pk, kit, "enamel", c - out * 0.112 + across * (sx * 0.27), bas, Vector3(0.04, hh * 2.0 + 0.26, 0.012), Color(0.95, 0.95, 0.93))
		for sy in [-1.0, 1.0]:
			_box(pk, kit, "enamel", c - out * 0.112 + UP * (sy * (hh + 0.11)), bas, Vector3(0.58, 0.04, 0.012), Color(0.95, 0.95, 0.93))
	for k in range(n):
		var lc: Vector3 = c + UP * (hh - 0.04 - pitch * (float(k) + 0.5)) + out * 0.112
		var col: Color = RED_DARK if k == 0 else (GREEN_DARK if k == n - 1 else Color(0.32, 0.20, 0.04))
		if ped:
			col = RED_DARK if k == 0 else GREEN_DARK
		var key: String = "lamp" if k == lit else "lens"
		if k == lit:
			col = AMBER
		pk.tube(kit, key, lc - out * 0.005, lc + out * 0.012, 0.1, 0.1, 14, col, true)
		if ped:
			# The figure, a little prouder: a body and a head in the lens's colour, lightened.
			_box(pk, kit, "lens", lc + out * 0.016 + UP * -0.01, bas, Vector3(0.05, 0.1, 0.006), col.lightened(0.25))
			_box(pk, kit, "lens", lc + out * 0.016 + UP * 0.065, bas, Vector3(0.035, 0.035, 0.006), col.lightened(0.25))
		# The visor: a hood over the lens's top and sides.
		var v0: Vector3 = lc + out * 0.02
		for s in [-1.0, 0.0, 1.0]:
			var dirv: Vector3 = (across * s + UP * (1.0 - absf(s))).normalized()
			var vc: Vector3 = v0 + dirv * 0.125 + out * 0.07
			var vb := Basis(dirv.cross(out).normalized(), dirv, out)
			_box(pk, kit, "matte", vc, vb, Vector3(0.13 if s == 0.0 else 0.012, 0.012, 0.14), SIGNAL_GREY.darkened(0.3))


## A traffic light (Ampelmast mit Ausleger) on the origin: an anthracite pole with its heads facing +z (and a pair back to
## back with them facing -z on the pole), a mast arm reaching `arm_len` along +x over the lanes with two heads hanging from
## it (their bottoms 4.4m up), a brace, a pedestrian head and the yellow push-button box facing +x. Out of order: only the
## amber lamps glow. Its pole and foot stay within 0.35m of the origin.
static func traffic_light(pk: PropKit, kit: Dictionary, arm_len := 7.0) -> void:
	var pole_top := 6.3
	var ya := 5.65
	pk.lathe(kit, "concrete", Vector3(0, -0.4, 0), [Vector2(0.001, 0.0), Vector2(0.3, 0.0), Vector2(0.3, 0.46), Vector2(0.001, 0.46)], 8, CONC, true)
	pk.lathe(kit, "steel", Vector3.ZERO, [Vector2(0.001, 0.04), Vector2(0.2, 0.04), Vector2(0.2, 0.12), Vector2(0.14, 0.2), Vector2(0.001, 0.2)], 8, ANTHRACITE, true)
	pk.lathe(kit, "steel", Vector3.ZERO, [Vector2(0.11, 0.1), Vector2(0.1, 1.0), Vector2(0.075, pole_top), Vector2(0.001, pole_top + 0.03)], 10, ANTHRACITE)
	# The arm: a tube along +x, its brace, a cap; a collar where it meets the pole.
	_box(pk, kit, "steel", Vector3(0, ya, 0), Basis(), Vector3(0.26, 0.34, 0.26), ANTHRACITE.darkened(0.1))
	pk.tube(kit, "steel", Vector3(0.1, ya, 0), Vector3(arm_len, ya, 0), 0.075, 0.055, 10, ANTHRACITE, true)
	pk.tube(kit, "steel", Vector3(0.05, pole_top - 0.15, 0), Vector3(arm_len * 0.42, ya + 0.04, 0), 0.03, 0.03, 6, ANTHRACITE, false)
	var heads: Array = [arm_len - 0.6, arm_len * 0.48]
	for hx in heads:
		var hc := Vector3(hx, ya - 0.72, 0)
		_box(pk, kit, "steel", Vector3(hx, ya - 0.18, 0), Basis(), Vector3(0.08, 0.3, 0.08), ANTHRACITE)
		_signal_head(pk, kit, hc + Vector3(0, -0.06, 0.02), Vector3(0, 0, 1))
	# The pole's heads: back to back at 2.3..3.3m, a pedestrian head and the push-button box facing +x.
	for s in [1.0, -1.0]:
		_box(pk, kit, "steel", Vector3(0, 2.85, s * 0.13), Basis(), Vector3(0.08, 0.5, 0.12), ANTHRACITE)
		_signal_head(pk, kit, Vector3(0, 2.82, s * 0.3), Vector3(0, 0, s))
	_box(pk, kit, "steel", Vector3(0.14, 2.3, 0), Basis(), Vector3(0.12, 0.3, 0.08), ANTHRACITE)
	_signal_head(pk, kit, Vector3(0.3, 2.3, 0), Vector3(1, 0, 0), 2, -1, true)
	_box(pk, kit, "paint", Vector3(0.14, 1.08, 0), Basis(), Vector3(0.14, 0.3, 0.12), SIGN_YELLOW)
	_box(pk, kit, "enamel", Vector3(0.214, 1.12, 0), Basis(), Vector3(0.012, 0.1, 0.08), BLACK)
	_box(pk, kit, "lens", Vector3(0.214, 1.0, 0), Basis(), Vector3(0.012, 0.035, 0.035), Color(0.9, 0.2, 0.1))


## A pedestrian light on the origin: a 3m pole, a pedestrian head facing +z and the push-button box.
static func pedestrian_light(pk: PropKit, kit: Dictionary) -> void:
	pk.lathe(kit, "steel", Vector3.ZERO, [Vector2(0.001, -0.3), Vector2(0.07, -0.3), Vector2(0.065, 3.1), Vector2(0.001, 3.13)], 10, ANTHRACITE)
	_box(pk, kit, "steel", Vector3(0, 2.4, 0.1), Basis(), Vector3(0.08, 0.3, 0.12), ANTHRACITE)
	_signal_head(pk, kit, Vector3(0, 2.4, 0.26), Vector3(0, 0, 1), 2, -1, true)
	_box(pk, kit, "paint", Vector3(0, 1.08, 0.1), Basis(), Vector3(0.12, 0.3, 0.14), SIGN_YELLOW)
	_box(pk, kit, "enamel", Vector3(0, 1.12, 0.174), Basis(), Vector3(0.08, 0.1, 0.012), BLACK)


# ======================================================================================
#  The pedestrian zone's fountain
# ======================================================================================

const FOUNTAIN_APOTHEM := 4.0
const FOUNTAIN_RIM := 0.48
const FOUNTAIN_WATER := 0.36

## A falling sheet of water ("wsheet": UV.x round, UV.y down it) from a ring of radius r0 at y0 to r1 at y1 round c.
static func _sheet(pk: PropKit, kit: Dictionary, c: Vector3, r0: float, y0: float, r1: float, y1: float, segs: int) -> void:
	for j in range(segs):
		var t0: float = TAU * float(j) / float(segs)
		var t1: float = TAU * float(j + 1) / float(segs)
		var d0 := Vector3(cos(t0), 0, sin(t0))
		var d1 := Vector3(cos(t1), 0, sin(t1))
		var a: Vector3 = c + d0 * r0 + UP * y0
		var b: Vector3 = c + d1 * r0 + UP * y0
		var cc: Vector3 = c + d1 * r1 + UP * y1
		var dd: Vector3 = c + d0 * r1 + UP * y1
		var nm: Vector3 = (d0 + d1).normalized()
		var u0: float = float(j) / float(segs)
		var u1: float = float(j + 1) / float(segs)
		pk.quad(kit, "wsheet", [a, b, cc, dd], nm, Color(1, 1, 1), [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)])


## A jet of water along a parabola from a to b (rising `lift` over the straight line), as a thin open tube of "wsheet".
static func _jet(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, lift: float, r: float) -> void:
	var pts: Array = []
	for k in range(9):
		var t: float = float(k) / 8.0
		pts.append(a.lerp(b, t) + UP * (lift * 4.0 * t * (1.0 - t)))
	for k in range(8):
		var p: Vector3 = pts[k]
		var q: Vector3 = pts[k + 1]
		var ax: Vector3 = (q - p).normalized()
		var s1: Vector3 = ax.cross(UP).normalized()
		var s2: Vector3 = s1.cross(ax).normalized()
		for j in range(6):
			var t0: float = TAU * float(j) / 6.0
			var t1: float = TAU * float(j + 1) / 6.0
			var e0: Vector3 = (s1 * cos(t0) + s2 * sin(t0)) * r
			var e1: Vector3 = (s1 * cos(t1) + s2 * sin(t1)) * r
			var nm: Vector3 = (e0 + e1).normalized()
			pk.quad(kit, "wsheet", [p + e0, p + e1, q + e1, q + e0], nm, Color(1, 1, 1),
					[Vector2(float(j) / 6.0, float(k) / 8.0), Vector2(float(j + 1) / 6.0, float(k) / 8.0), Vector2(float(j + 1) / 6.0, float(k + 1) / 8.0),
					Vector2(float(j) / 6.0, float(k + 1) / 8.0)])


## The pedestrian zone's fountain (the Kronenbrunnen), centred on the origin: an octagonal sandstone basin 8m across its
## flats (FOUNTAIN_APOTHEM 4.0) with a moulded rim to sit on (top FOUNTAIN_RIM 0.48), its water at FOUNTAIN_WATER; in the
## middle a stepped octagonal plinth, a fluted column with two bronze bowls whose water falls in sheets, a gilt crown on
## top (5.0m), and four bronze spouts on the plinth jetting into the pool.
static func city_fountain(pk: PropKit, kit: Dictionary) -> void:
	var oct := Basis(UP, PI / 8.0)
	var kc: float = 1.0 / cos(PI / 8.0)
	var ro: float = FOUNTAIN_APOTHEM * kc
	var ri: float = (FOUNTAIN_APOTHEM - 0.42) * kc
	var saved := _push(pk, Transform3D(oct, Vector3.ZERO))
	# The rim: the outer face with a plinth, the rounded coping over the top, the inner face down to the floor.
	SW._lathe_uv(pk, kit, "ashlar", Vector3.ZERO, [Vector2(ro + 0.05, -0.4), Vector2(ro + 0.05, 0.06), Vector2(ro, 0.1), Vector2(ro, 0.36),
			Vector2(ro + 0.06, 0.39), Vector2(ro + 0.08, 0.44), Vector2(ro + 0.05, FOUNTAIN_RIM), Vector2(ri - 0.05, FOUNTAIN_RIM), Vector2(ri - 0.07, 0.44),
			Vector2(ri, 0.4), Vector2(ri, 0.02)], 8, SAND, false, true)
	# The basin's floor under the water, and the water.
	pk.lathe(kit, "stone", Vector3(0, 0.02, 0), [Vector2(ri + 0.01, 0.0), Vector2(0.001, 0.0)], 8, SAND_DARK.darkened(0.3), true)
	pk.lathe(kit, "kwater", Vector3(0, FOUNTAIN_WATER, 0), [Vector2(ri + 0.01, 0.0), Vector2(0.001, 0.0)], 8, WHITE, true)
	# The plinth: three octagonal steps, then a drum.
	var steps: Array = [[1.35, 0.0, 0.55], [1.1, 0.55, 0.85], [0.85, 0.85, 1.15]]
	for st in steps:
		var r: float = float(st[0]) * kc
		SW._lathe_uv(pk, kit, "ashlar", Vector3.ZERO, [Vector2(r, float(st[1])), Vector2(r, float(st[2]) - 0.04), Vector2(r - 0.04, float(st[2])),
				Vector2(0.001, float(st[2]))], 8, SAND_LIGHT if st == steps[0] else SAND, false, true)
	_pop(pk, saved)
	# The column: a fluted shaft (16 facets) on a base, a capital, the lower bowl; a stem, the upper bowl, the crown.
	SW._lathe_uv(pk, kit, "ashlar", Vector3(0, 1.15, 0), [Vector2(0.48, 0.0), Vector2(0.48, 0.12), Vector2(0.4, 0.2), Vector2(0.36, 0.26),
			Vector2(0.33, 1.05), Vector2(0.4, 1.12), Vector2(0.46, 1.22), Vector2(0.001, 1.22)], 16, SAND_LIGHT, false, false)
	var b1 := 2.38
	pk.lathe(kit, "bronze", Vector3(0, b1, 0), [Vector2(0.001, -0.02), Vector2(0.3, -0.02), Vector2(0.75, 0.08), Vector2(1.12, 0.26), Vector2(1.22, 0.38),
			Vector2(1.2, 0.42), Vector2(1.1, 0.34), Vector2(0.72, 0.18), Vector2(0.3, 0.12), Vector2(0.001, 0.12)], 24, Color(0.42, 0.30, 0.16))
	pk.lathe(kit, "kwater", Vector3(0, b1 + 0.3, 0), [Vector2(1.13, 0.0), Vector2(0.001, 0.0)], 24, WHITE)
	pk.lathe(kit, "bronze", Vector3(0, b1 + 0.1, 0), [Vector2(0.16, 0.0), Vector2(0.13, 0.3), Vector2(0.11, 0.9), Vector2(0.15, 1.0), Vector2(0.001, 1.0)], 12,
			Color(0.38, 0.27, 0.15))
	var b2: float = b1 + 1.05
	pk.lathe(kit, "bronze", Vector3(0, b2, 0), [Vector2(0.001, -0.02), Vector2(0.18, -0.02), Vector2(0.45, 0.06), Vector2(0.66, 0.2), Vector2(0.72, 0.3),
			Vector2(0.7, 0.33), Vector2(0.62, 0.26), Vector2(0.4, 0.15), Vector2(0.001, 0.1)], 20, Color(0.42, 0.30, 0.16))
	pk.lathe(kit, "kwater", Vector3(0, b2 + 0.24, 0), [Vector2(0.64, 0.0), Vector2(0.001, 0.0)], 20, WHITE)
	pk.lathe(kit, "bronze", Vector3(0, b2 + 0.2, 0), [Vector2(0.12, 0.0), Vector2(0.09, 0.4), Vector2(0.14, 0.5), Vector2(0.001, 0.55)], 10, Color(0.38, 0.27, 0.15))
	KT._crown(pk, kit, Vector3(0, b2 + 0.74, 0), 0.32)
	# The sheets: off the upper bowl's lip into the lower, off the lower's lip into the pool.
	_sheet(pk, kit, Vector3.ZERO, 0.73, b2 + 0.31, 0.86, b1 + 0.3, 28)
	_sheet(pk, kit, Vector3.ZERO, 1.23, b1 + 0.39, 1.42, FOUNTAIN_WATER + 0.01, 36)
	# Four spouts on the first step's faces (bronze fish mouths), each jetting out into the pool.
	for k in range(4):
		var a: float = TAU * float(k) / 4.0 + PI * 0.25
		var d := Vector3(cos(a), 0, sin(a))
		var p: Vector3 = d * (1.35 + 0.02) + UP * 0.38
		pk.lathe(kit, "bronze", p, [Vector2(0.001, -0.1), Vector2(0.09, -0.06), Vector2(0.11, 0.0), Vector2(0.09, 0.07), Vector2(0.001, 0.1)], 8,
				Color(0.40, 0.29, 0.15), false, Basis(UP.cross(d).normalized(), d, UP.cross(d).normalized().cross(d)))
		pk.tube(kit, "bronze", p, p + d * 0.18, 0.04, 0.03, 8, Color(0.36, 0.26, 0.14), true)
		_jet(pk, kit, p + d * 0.17, d * 2.75 + UP * (FOUNTAIN_WATER + 0.02), 0.35, 0.035)


## The fountain's collision: the rim's eight sides and the middle (plinth and column).
static func city_fountain_solids() -> Array:
	var out: Array = []
	var side_len: float = 2.0 * FOUNTAIN_APOTHEM * tan(PI / 8.0) + 0.1
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		var n := Vector3(cos(a), 0, sin(a))
		var b := Basis(UP.cross(n).normalized(), UP, n)
		out.append([Transform3D(b, n * (FOUNTAIN_APOTHEM - 0.2) + UP * (FOUNTAIN_RIM - 0.4) * 0.5), Vector3(side_len, FOUNTAIN_RIM + 0.4, 0.45)])
	out.append([Transform3D(Basis(), Vector3(0, 1.5, 0)), Vector3(2.4, 3.0, 2.4)])
	out.append([Transform3D(Basis(), Vector3(0, 3.6, 0)), Vector3(1.2, 1.4, 1.2)])
	return out


# ======================================================================================
#  The Ring's tram stop
# ======================================================================================

const KSW_RED := Color(0.78, 0.08, 0.10)
const STOP_KERB := 0.24
const STOP_KERB_Z := Vector2(0.55, 2.05)
const SHELTER_X := Vector2(-6.0, 1.5)
const SHELTER_Z := Vector2(-1.1, 0.95)
const SHELTER_H := 2.65

## The round H sign of a German stop (a green H on a yellow disc, a green ring) on both faces of a disc at c, its face
## toward `out`.
static func _h_sign(pk: PropKit, kit: Dictionary, labels: Array, c: Vector3, out: Vector3, r := 0.3) -> void:
	for s in [1.0, -1.0]:
		var o: Vector3 = out * s
		var wf := Transform3D(Basis(UP.cross(o).normalized(), UP, o), c)
		KT._prism(pk, kit, "enamel", wf, KT._circle_pts(Vector2.ZERO, r, 20), 0.0, 0.015, SIGN_YELLOW, Vector2(0, 1), false)
		KT._circle_ring(pk, kit, "enamel", wf, Vector2.ZERO, r * 0.85, r * 0.97, 0.015, 0.024, STOP_GREEN, 20)
		_lbl(labels, "H", c + o * 0.026, o, r, STOP_GREEN, r * 1.2)


## The Ring's tram stop along x centred on the origin, its front (+z) toward the road: a raised boarding kerb
## (STOP_KERB_Z, top STOP_KERB, ramps at both ends) with a tactile strip, a glass shelter (SHELTER_X, SHELTER_Z, roof at
## SHELTER_H) with a bench, a lit advert case, the passenger display under its roof and the stop's name on its fascia, the
## H sign mast with the name plate and timetable on the kerb, a ticket machine and a bin. Everything within z -1.2..2.05.
static func tram_stop(pk: PropKit, kit: Dictionary, labels: Array, length := 22.0, stop_name := "Botanischer Garten") -> void:
	var hl: float = length * 0.5
	# The kerb: a ramped slab of concrete pavers with a granite edge, then the tactile strip.
	var ol := PackedVector2Array([Vector2(-hl, -0.3), Vector2(hl, -0.3), Vector2(hl, 0.0), Vector2(hl - 1.6, STOP_KERB), Vector2(-hl + 1.6, STOP_KERB), Vector2(-hl, 0.0)])
	pk.extrude(kit, "concrete", ol, STOP_KERB_Z.x, STOP_KERB_Z.y - 0.18, 0.0, CONC.lightened(0.05), Callable(), uvk)
	var ol2 := PackedVector2Array([Vector2(-hl, -0.3), Vector2(hl, -0.3), Vector2(hl, 0.01), Vector2(hl - 1.6, STOP_KERB + 0.01), Vector2(-hl + 1.6, STOP_KERB + 0.01),
			Vector2(-hl, 0.01)])
	pk.extrude(kit, "stone", ol2, STOP_KERB_Z.y - 0.18, STOP_KERB_Z.y, 0.02, Color(0.62, 0.62, 0.62), Callable(), uvk)
	var tz0: float = STOP_KERB_Z.y - 0.75
	_blk(pk, kit, "enamel", Vector3(-hl + 1.7, STOP_KERB - 0.02, tz0), Vector3(hl - 1.7, STOP_KERB + 0.02, tz0 + 0.4), Color(0.92, 0.92, 0.9))
	for k in range(6):
		var z: float = tz0 + 0.04 + 0.064 * float(k)
		_blk(pk, kit, "enamel", Vector3(-hl + 1.75, STOP_KERB + 0.01, z), Vector3(hl - 1.75, STOP_KERB + 0.035, z + 0.03), Color(0.96, 0.96, 0.94))
	# The shelter: back posts, a glass back and ends, a cantilevered roof with its fascia, the bench and the advert case.
	var x0: float = SHELTER_X.x
	var x1: float = SHELTER_X.y
	var zb: float = SHELTER_Z.x
	var frame := Color(0.26, 0.28, 0.30)
	var nposts := 4
	for k in range(nposts):
		var px: float = lerpf(x0 + 0.05, x1 - 0.05, float(k) / float(nposts - 1))
		_blk(pk, kit, "steel", Vector3(px - 0.05, -0.2, zb - 0.05), Vector3(px + 0.05, SHELTER_H, zb + 0.05), frame)
		# A bracket under the roof out to its front.
		pk.beam(kit, "steel", Vector3(px, SHELTER_H - 0.5, zb + 0.05), Vector3(px, SHELTER_H - 0.02, SHELTER_Z.y - 0.25), 0.06, 0.06, frame)
	for k in range(nposts - 1):
		var pa: float = lerpf(x0 + 0.05, x1 - 0.05, float(k) / float(nposts - 1)) + 0.05
		var pb: float = lerpf(x0 + 0.05, x1 - 0.05, float(k + 1) / float(nposts - 1)) - 0.05
		pk.quad(kit, "sglass", [Vector3(pa, 0.1, zb), Vector3(pb, 0.1, zb), Vector3(pb, SHELTER_H - 0.1, zb), Vector3(pa, SHELTER_H - 0.1, zb)], Vector3(0, 0, 1),
				Color(0.72, 0.84, 0.86, 0.22))
		_blk(pk, kit, "steel", Vector3(pa, 0.05, zb - 0.025), Vector3(pb, 0.12, zb + 0.025), frame)
		# A frosted band with dots at eye height, so nobody walks into the glass.
		for d in range(int((pb - pa) / 0.12)):
			var dx: float = pa + 0.06 + 0.12 * float(d)
			_box(pk, kit, "enamel", Vector3(dx, 1.45, zb + 0.004), Basis(), Vector3(0.05, 0.05, 0.002), Color(0.9, 0.9, 0.9))
	# The roof: a slab sloping a little to the back, a fascia band with the name, a gutter.
	_blk(pk, kit, "steel", Vector3(x0 - 0.15, SHELTER_H, zb - 0.15), Vector3(x1 + 0.15, SHELTER_H + 0.08, SHELTER_Z.y), frame.lightened(0.1))
	_blk(pk, kit, "paint", Vector3(x0 - 0.15, SHELTER_H - 0.2, SHELTER_Z.y - 0.06), Vector3(x1 + 0.15, SHELTER_H + 0.14, SHELTER_Z.y + 0.0), KSW_RED)
	_blk(pk, kit, "paint", Vector3(x0 - 0.15, SHELTER_H - 0.2, zb - 0.15), Vector3(x1 + 0.15, SHELTER_H + 0.1, zb - 0.1), frame)
	_lbl(labels, stop_name, Vector3((x0 + x1) * 0.5 - 0.6, SHELTER_H - 0.03, SHELTER_Z.y + 0.03), Vector3(0, 0, 1), 0.2, WHITE, (x1 - x0) - 2.4)
	_lbl(labels, "KSW", Vector3(x1 - 0.55, SHELTER_H - 0.03, SHELTER_Z.y + 0.03), Vector3(0, 0, 1), 0.2, WHITE, 0.8)
	# The ends: glass at the near end, the lit advert case (a city-light poster) at the far one.
	pk.quad(kit, "sglass", [Vector3(x1 - 0.02, 0.1, zb + 0.05), Vector3(x1 - 0.02, 0.1, zb + 1.25), Vector3(x1 - 0.02, SHELTER_H - 0.1, zb + 1.25),
			Vector3(x1 - 0.02, SHELTER_H - 0.1, zb + 0.05)], Vector3(1, 0, 0), Color(0.72, 0.84, 0.86, 0.22))
	_blk(pk, kit, "steel", Vector3(x1 - 0.06, -0.2, zb + 1.2), Vector3(x1 + 0.02, SHELTER_H, zb + 1.3), frame)
	_blk(pk, kit, "steel", Vector3(x0 - 0.04, 0.0, zb + 0.06), Vector3(x0 + 0.14, 2.2, zb + 1.35), frame)
	for s in [-1.0, 1.0]:
		var fx: float = x0 + 0.05 + s * 0.095
		pk.quad(kit, "bulb", [Vector3(fx, 0.35, zb + 0.15), Vector3(fx, 0.35, zb + 1.26), Vector3(fx, 2.05, zb + 1.26), Vector3(fx, 2.05, zb + 0.15)], Vector3(s, 0, 0),
				Color(0.95, 0.55, 0.25) if s > 0.0 else Color(0.35, 0.62, 0.92))
		# A poster's motif: a band and a block of colour over the glow, 1.5cm proud.
		pk.quad(kit, "enamel", [Vector3(fx + s * 0.015, 1.3, zb + 0.3), Vector3(fx + s * 0.015, 1.3, zb + 1.1), Vector3(fx + s * 0.015, 1.9, zb + 1.1),
				Vector3(fx + s * 0.015, 1.9, zb + 0.3)], Vector3(s, 0, 0), Color(0.95, 0.92, 0.85) if s > 0.0 else Color(0.12, 0.2, 0.45))
	YK.bench(pk, kit, Vector3(-2.2, 0.0, zb + 0.66), Vector3(0, 0, 1), 3.2)
	# The passenger display hanging under the roof's front, both faces.
	var dc := Vector3(-1.0, SHELTER_H - 0.62, SHELTER_Z.y - 0.45)
	for zz in [0.04, -0.04]:
		pk.beam(kit, "steel", dc + Vector3(-0.6, 0.2, 0), dc + Vector3(-0.6, 0.62, 0), 0.03, 0.03, frame)
		pk.beam(kit, "steel", dc + Vector3(0.6, 0.2, 0), dc + Vector3(0.6, 0.62, 0), 0.03, 0.03, frame)
	_box(pk, kit, "matte", dc, Basis(), Vector3(1.7, 0.44, 0.1), TRIM_BLACK)
	_led(pk, kit, dc + Vector3(0, 0, 0.052), Vector3(0, 0, 1), 1.55, 0.32, AMBER, UP, 0.0)
	_led(pk, kit, dc + Vector3(0, 0, -0.052), Vector3(0, 0, -1), 1.55, 0.32, AMBER, UP, 0.0)
	# The H mast on the kerb near the shelter's end: the sign, the name plate, the timetable case.
	var hm := Vector3(x1 + 2.6, STOP_KERB, 1.0)
	pk.lathe(kit, "metal", hm - UP * 0.3, [Vector2(0.001, 0.0), Vector2(0.045, 0.0), Vector2(0.04, 3.25), Vector2(0.001, 3.27)], 8, GALV)
	_h_sign(pk, kit, labels, hm + Vector3(0, 2.75, 0.07), Vector3(0, 0, 1))
	_box(pk, kit, "enamel", hm + Vector3(0, 2.28, 0.06), Basis(), Vector3(1.1, 0.24, 0.03), Color(0.97, 0.97, 0.95))
	_lbl(labels, stop_name, hm + Vector3(0, 2.28, 0.082), Vector3(0, 0, 1), 0.085, STOP_GREEN, 1.0)
	_lbl(labels, stop_name, hm + Vector3(0, 2.28, 0.038), Vector3(0, 0, -1), 0.085, STOP_GREEN, 1.0)
	_box(pk, kit, "metal", hm + Vector3(0, 1.55, 0.08), Basis(), Vector3(0.5, 0.65, 0.08), Color(0.85, 0.85, 0.82))
	_box(pk, kit, "enamel", hm + Vector3(0, 1.55, 0.125), Basis(), Vector3(0.42, 0.57, 0.01), Color(0.98, 0.98, 0.97))
	for k in range(6):
		_box(pk, kit, "enamel", hm + Vector3(-0.05, 1.75 - 0.075 * float(k), 0.132), Basis(), Vector3(0.3, 0.02, 0.004), Color(0.25, 0.25, 0.28))
	_lbl(labels, "Fahrplan", hm + Vector3(0, 1.82, 0.137), Vector3(0, 0, 1), 0.04, KSW_RED, 0.36)
	# The ticket machine beside the shelter (its screen and keys facing +z), a bin.
	var tm := Vector3(x0 - 0.9, 0.0, zb + 0.35)
	_blk(pk, kit, "paint", tm + Vector3(-0.38, 0.0, -0.25), tm + Vector3(0.38, 1.75, 0.25), Color(0.90, 0.90, 0.88))
	_blk(pk, kit, "paint", tm + Vector3(-0.385, 1.55, -0.255), tm + Vector3(0.385, 1.8, 0.255), KSW_RED)
	_blk(pk, kit, "pane", tm + Vector3(-0.22, 1.08, 0.25), tm + Vector3(0.22, 1.38, 0.268), GLASS_DARK)
	_blk(pk, kit, "matte", tm + Vector3(-0.2, 0.86, 0.25), tm + Vector3(0.2, 1.02, 0.275), TRIM_BLACK)
	_blk(pk, kit, "matte", tm + Vector3(-0.12, 0.45, 0.25), tm + Vector3(0.12, 0.6, 0.29), TRIM_BLACK)
	_lbl(labels, "Fahrkarten", tm + Vector3(0, 1.675, 0.275), Vector3(0, 0, 1), 0.07, WHITE, 0.66)
	var saved := _push(pk, Transform3D(Basis(UP, PI), Vector3(x0 - 2.0, 0.0, zb + 0.1)))
	RS.bin(pk, kit)
	_pop(pk, saved)


static func tram_stop_solids(length := 22.0) -> Array:
	var hl: float = length * 0.5
	var out: Array = []
	out.append([Transform3D(Basis(), Vector3(0, (STOP_KERB - 0.3) * 0.5, (STOP_KERB_Z.x + STOP_KERB_Z.y) * 0.5)), Vector3(length - 2.4, STOP_KERB + 0.3, STOP_KERB_Z.y - STOP_KERB_Z.x)])
	out.append([Transform3D(Basis(), Vector3((SHELTER_X.x + SHELTER_X.y) * 0.5, SHELTER_H * 0.5, (SHELTER_Z.x - 0.15 + SHELTER_Z.y) * 0.5)),
			Vector3(SHELTER_X.y - SHELTER_X.x + 0.3, SHELTER_H + 0.2, SHELTER_Z.y - SHELTER_Z.x + 0.15)])
	out.append([Transform3D(Basis(), Vector3(SHELTER_X.y + 2.6, 1.6, 1.0)), Vector3(0.3, 3.2, 0.3)])
	out.append([Transform3D(Basis(), Vector3(SHELTER_X.x - 0.9, 0.9, SHELTER_Z.x + 0.35)), Vector3(0.8, 1.8, 0.55)])
	return out


# ======================================================================================
#  The U-Bahn's entrance on the Kaiserplatz
# ======================================================================================

const UB_HX := 2.6
const UB_Z := Vector2(-4.2, 3.0)
const UB_FLOOR := 0.51
const UB_ROOF := 3.3
const UB_CANOPY := 4.0

## The U-Bahn station Kaiserplatz's entrance pavilion on the origin, open toward +z: three granite steps up to its floor
## (UB_FLOOR: a threshold against flooding), a glazed steel pavilion (x +-UB_HX, z UB_Z) on a granite plinth with a blue
## enamelled back wall, a flat roof (UB_ROOF) cantilevered to z UB_CANOPY, the name on its fascia, the big blue U cube on
## its corner (+x, +z) and a U pylon; inside, a wide stair going down past handrails into the dark (only its first steps
## lie over the ground, so a black floor 2cm over the pavilion's foot stands for the rest). Within x +-2.9, z -4.4..4.0.
static func u_bahn_entrance(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var hx := UB_HX
	var z0: float = UB_Z.x
	var z1: float = UB_Z.y
	var frame := Color(0.22, 0.23, 0.25)
	var granite := Color(0.50, 0.50, 0.52)
	# The plinth and the floor slab inside, the steps up at the front.
	_blk(pk, kit, "stone", Vector3(-hx - 0.12, -0.4, z0 - 0.12), Vector3(hx + 0.12, UB_FLOOR, z0 + 1.0), granite)
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "stone", Vector3(sx * (hx + 0.12) - (0.6 if sx > 0.0 else 0.0), -0.4, z0 + 1.0), Vector3(sx * (hx + 0.12) + (0.6 if sx < 0.0 else 0.0), UB_FLOOR, z1 + 0.02), granite)
	_blk(pk, kit, "stone", Vector3(-hx + 0.48, UB_FLOOR - 0.12, z1 - 1.4), Vector3(hx - 0.48, UB_FLOOR, z1 + 0.02), granite.lightened(0.05))
	for k in range(3):
		var top: float = UB_FLOOR - 0.17 * float(k)
		_blk(pk, kit, "stone", Vector3(-hx + 0.3, -0.3, z1 + 0.3 * float(k)), Vector3(hx - 0.3, top, z1 + 0.3 * float(k + 1)), granite.lightened(0.04 - 0.02 * float(k)))
		_blk(pk, kit, "enamel", Vector3(-hx + 0.31, top - 0.01, z1 + 0.3 * float(k + 1) - 0.06), Vector3(hx - 0.31, top + 0.02, z1 + 0.3 * float(k + 1) - 0.01), SIGN_YELLOW)
	# The stair down: two treads over the black, its side walls in white tiles, handrails sloping away into it.
	var sw: float = hx - 0.5
	var zs: float = z1 - 1.4
	for k in range(2):
		var t: float = UB_FLOOR - 0.17 * float(k + 1)
		_blk(pk, kit, "stone", Vector3(-sw + 0.02, t - 0.17, zs - 0.3 * float(k + 1)), Vector3(sw - 0.02, t, zs - 0.3 * float(k)), granite.darkened(0.08 * float(k)))
	pk.quad(kit, "matte", [Vector3(-sw, 0.02, zs - 0.6), Vector3(sw, 0.02, zs - 0.6), Vector3(sw, 0.02, z0 + 1.0), Vector3(-sw, 0.02, z0 + 1.0)], UP, BLACK)
	for sx in [-1.0, 1.0]:
		var wx: float = sx * sw
		pk.quad(kit, "enamel", [Vector3(wx, 0.02, zs), Vector3(wx, 0.02, z0 + 1.0), Vector3(wx, UB_FLOOR, z0 + 1.0), Vector3(wx, UB_FLOOR, zs)], Vector3(-sx, 0, 0),
				Color(0.80, 0.80, 0.76))
		# The handrail: along the wall at 0.9 over the treads' nosings, down at the stair's slope.
		var ra := Vector3(wx - sx * 0.08, UB_FLOOR + 0.9, zs + 0.3)
		var rb := Vector3(wx - sx * 0.08, UB_FLOOR + 0.9 - 0.57 * 4.6, zs - 4.3)
		pk.tube(kit, "metal", ra, rb, 0.025, 0.025, 8, Color(0.75, 0.76, 0.78), true)
		for k in range(4):
			var p: Vector3 = ra.lerp(rb, 0.06 + 0.2 * float(k))
			pk.beam(kit, "metal", p, Vector3(wx - sx * 0.005, p.y - 0.02, p.z), 0.02, 0.02, Color(0.75, 0.76, 0.78))
		# The stair's top edge: a granite kerb on each side at the floor.
		_blk(pk, kit, "stone", Vector3(wx - 0.08 if sx < 0.0 else wx, UB_FLOOR - 0.12, z0 + 1.0), Vector3(wx if sx < 0.0 else wx + 0.08, UB_FLOOR + 0.04, zs), granite)
	# A centre handrail on posts, going down with the stair.
	pk.tube(kit, "metal", Vector3(0, UB_FLOOR + 0.95, zs + 0.2), Vector3(0, UB_FLOOR + 0.95 - 0.57 * 4.5, zs - 4.3), 0.03, 0.03, 8, Color(0.75, 0.76, 0.78), true)
	for k in range(3):
		var pz: float = zs - 0.3 - 0.6 * float(k)
		var fy2: float = UB_FLOOR - 0.17 * (2.0 + 2.0 * float(k))
		pk.tube(kit, "metal", Vector3(0, maxf(fy2, -0.1), pz), Vector3(0, UB_FLOOR + 0.95 - 0.57 * (zs + 0.2 - pz), pz), 0.025, 0.025, 6, Color(0.75, 0.76, 0.78), false)
	# The pavilion: steel posts, the glass sides (opaque dark), the blue back wall, a transom band.
	var posts_z: Array = [z0 + 0.06, -2.0, 0.0, z1 - 0.06]
	for sx in [-1.0, 1.0]:
		for pz in posts_z:
			_blk(pk, kit, "steel", Vector3(sx * hx - 0.06, UB_FLOOR - 0.02, float(pz) - 0.06), Vector3(sx * hx + 0.06, UB_ROOF, float(pz) + 0.06), frame)
		for k in range(posts_z.size() - 1):
			var za: float = float(posts_z[k]) + 0.06
			var zb2: float = float(posts_z[k + 1]) - 0.06
			pk.quad(kit, "pane", [Vector3(sx * hx, UB_FLOOR + 0.1, zb2), Vector3(sx * hx, UB_FLOOR + 0.1, za), Vector3(sx * hx, UB_ROOF - 0.35, za),
					Vector3(sx * hx, UB_ROOF - 0.35, zb2)], Vector3(sx, 0, 0), GLASS_DARK.lightened(0.05))
			pk.quad(kit, "pane", [Vector3(sx * (hx - 0.02), UB_FLOOR + 0.1, za), Vector3(sx * (hx - 0.02), UB_FLOOR + 0.1, zb2), Vector3(sx * (hx - 0.02), UB_ROOF - 0.35, zb2),
					Vector3(sx * (hx - 0.02), UB_ROOF - 0.35, za)], Vector3(-sx, 0, 0), GLASS_DARK)
			_blk(pk, kit, "steel", Vector3(sx * hx - 0.04, UB_ROOF - 0.38, za), Vector3(sx * hx + 0.04, UB_ROOF - 0.3, zb2), frame)
			_blk(pk, kit, "steel", Vector3(sx * hx - 0.04, UB_FLOOR, za), Vector3(sx * hx + 0.04, UB_FLOOR + 0.12, zb2), frame)
	_blk(pk, kit, "enamel", Vector3(-hx + 0.06, UB_FLOOR, z0), Vector3(hx - 0.06, UB_ROOF - 0.05, z0 + 0.1), U_BLUE)
	pk.quad(kit, "enamel", [Vector3(hx - 0.06, UB_FLOOR, z0 + 0.1), Vector3(-hx + 0.06, UB_FLOOR, z0 + 0.1), Vector3(-hx + 0.06, UB_FLOOR, z0 + 0.1),
			Vector3(hx - 0.06, UB_FLOOR, z0 + 0.1)], Vector3(0, 0, 1), U_BLUE)
	_box(pk, kit, "enamel", Vector3(0, 2.2, z0 + 0.13), Basis(), Vector3(2.6, 0.5, 0.04), Color(0.96, 0.96, 0.94))
	_lbl(labels, "Ausgang  Kaiserplatz / Hauptbahnhof", Vector3(0, 2.2, z0 + 0.155), Vector3(0, 0, 1), 0.12, U_BLUE, 2.4)
	_lbl(labels, "U", Vector3(0, 1.45, z0 - 0.125), Vector3(0, 0, -1), 0.9, WHITE, 1.2)
	_box(pk, kit, "enamel", Vector3(0, 1.45, z0 - 0.11), Basis(), Vector3(1.3, 1.3, 0.02), U_BLUE.darkened(0.15))
	# The roof: a slab over all with the canopy, a fascia band all round with the name, downlights under the canopy.
	_blk(pk, kit, "concrete", Vector3(-hx - 0.3, UB_ROOF, z0 - 0.3), Vector3(hx + 0.3, UB_ROOF + 0.25, UB_CANOPY), CONC.lightened(0.1))
	for e in [[Vector3(-hx - 0.33, UB_ROOF - 0.1, UB_CANOPY), Vector3(hx + 0.33, UB_ROOF + 0.32, UB_CANOPY + 0.03), Vector3(0, 0, 1)],
			[Vector3(hx + 0.3, UB_ROOF - 0.1, z0 - 0.33), Vector3(hx + 0.33, UB_ROOF + 0.32, UB_CANOPY), Vector3(1, 0, 0)],
			[Vector3(-hx - 0.33, UB_ROOF - 0.1, z0 - 0.33), Vector3(-hx - 0.3, UB_ROOF + 0.32, UB_CANOPY), Vector3(-1, 0, 0)],
			[Vector3(-hx - 0.33, UB_ROOF - 0.1, z0 - 0.33), Vector3(hx + 0.33, UB_ROOF + 0.32, z0 - 0.3), Vector3(0, 0, -1)]]:
		_blk(pk, kit, "paint", e[0], e[1], U_BLUE)
	_lbl(labels, "U Kaiserplatz", Vector3(-0.5, UB_ROOF + 0.11, UB_CANOPY + 0.04), Vector3(0, 0, 1), 0.24, WHITE, 3.4)
	_lbl(labels, "U Kaiserplatz", Vector3(hx + 0.34, UB_ROOF + 0.11, -0.4), Vector3(1, 0, 0), 0.24, WHITE, 5.5)
	_lbl(labels, "U Kaiserplatz", Vector3(-hx - 0.34, UB_ROOF + 0.11, -0.4), Vector3(-1, 0, 0), 0.24, WHITE, 5.5)
	for dz in [z1 + 0.3, z1 + 0.75]:
		for dx in [-1.2, 0.0, 1.2]:
			pk.lathe(kit, "bulb", Vector3(dx, UB_ROOF - 0.01, dz), [Vector2(0.001, 0.0), Vector2(0.09, 0.0)], 10, Color(1.0, 0.92, 0.78), true)
	# The U cube on the roof's front corner (the street's side, +x): a blue cube, a white U on three faces, on a short mast.
	var cc := Vector3(hx - 0.55, UB_ROOF + 1.15, UB_CANOPY - 0.6)
	pk.tube(kit, "metal", Vector3(cc.x, UB_ROOF + 0.25, cc.z), Vector3(cc.x, cc.y - 0.4, cc.z), 0.06, 0.06, 8, frame, false)
	_box(pk, kit, "enamel", cc, Basis(), Vector3(0.84, 0.84, 0.84), U_BLUE)
	for f in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]:
		_box(pk, kit, "enamel", cc + f * 0.43, Basis(UP.cross(f).normalized(), UP, f), Vector3(0.72, 0.72, 0.01), WHITE)
		_box(pk, kit, "enamel", cc + f * 0.437, Basis(UP.cross(f).normalized(), UP, f), Vector3(0.64, 0.64, 0.004), U_BLUE)
		_lbl(labels, "U", cc + f * 0.441, f, 0.42, WHITE, 0.6)
	# The U pylon on the street's side of the steps (+x, +z): a blue column with the U and the line numbers.
	var pyl := Vector3(hx - 0.1, 0.0, UB_CANOPY - 0.25)
	_blk(pk, kit, "paint", pyl + Vector3(-0.1, -0.3, -0.18), pyl + Vector3(0.1, 2.6, 0.18), frame)
	_box(pk, kit, "enamel", pyl + Vector3(0.11, 2.15, 0), Basis(), Vector3(0.02, 0.5, 0.5), U_BLUE)
	_lbl(labels, "U", pyl + Vector3(0.122, 2.15, 0), Vector3(1, 0, 0), 0.3, WHITE, 0.4)
	_box(pk, kit, "enamel", pyl + Vector3(0.11, 1.6, 0), Basis(), Vector3(0.02, 0.4, 0.34), WHITE)
	_lbl(labels, "U1  U4", pyl + Vector3(0.122, 1.6, 0), Vector3(1, 0, 0), 0.08, U_BLUE, 0.3)


static func u_bahn_entrance_solids() -> Array:
	return [
		[Transform3D(Basis(), Vector3(0, (UB_ROOF + 0.32 - 0.4) * 0.5, (UB_Z.x - 0.33 + UB_Z.y) * 0.5)), Vector3(UB_HX * 2.0 + 0.66, UB_ROOF + 0.72, UB_Z.y - UB_Z.x + 0.33)],
		[Transform3D(Basis(), Vector3(0, 0.1, UB_Z.y + 0.45)), Vector3(UB_HX * 2.0 - 0.6, 0.8, 0.9)],
		[Transform3D(Basis(), Vector3(UB_HX - 0.1, 1.15, UB_CANOPY - 0.25)), Vector3(0.24, 2.9, 0.4)],
	]


# ======================================================================================
#  The race's scaffold grandstand
# ======================================================================================

const GS_WALK := 1.0
const GS_WALK_D := 1.0
const GS_TREAD := 0.85
const GS_RISE := 0.42
const GS_SEAT_H := 0.45
const GS_SEAT_PITCH := 0.6
const GS_BAY := 2.5
const GS_END := 1.4
const GS_AISLE := 1.1
const GS_SCAFF := Color(0.66, 0.68, 0.69)
const GS_DECK := Color(0.34, 0.35, 0.36)
const GS_SEAT_COLS := [Color(0.12, 0.28, 0.62), Color(0.95, 0.72, 0.10), Color(0.12, 0.28, 0.62), Color(0.80, 0.12, 0.10)]
const GS_BANNERS := [
	["RALLYE KRONBURG", Color(0.10, 0.18, 0.42), Color(0.98, 0.80, 0.18)],
	["STADTWERKE KRONBURG", Color(0.78, 0.08, 0.10), Color(0.98, 0.98, 0.96)],
	["KRONBURGER PILSENER", Color(0.08, 0.30, 0.18), Color(0.95, 0.86, 0.55)],
	["RC VIBE GP", Color(0.06, 0.08, 0.12), Color(1.0, 0.55, 0.10)],
	["RADIO KRONBURG 98,4", Color(0.95, 0.80, 0.15), Color(0.10, 0.10, 0.12)],
	["KAUFHAUS KRONE", Color(0.92, 0.92, 0.90), Color(0.62, 0.48, 0.15)],
]

## Row k's tread: its front z, its top.
static func _gs_row(k: int) -> Vector2:
	return Vector2(-GS_WALK_D - float(k) * GS_TREAD, GS_WALK + GS_RISE * float(k + 1))


## The aisles' middles along x for a stand `length` long (the end stairs at both ends, one in the middle, two more over
## 40m).
static func _gs_aisles(length: float) -> Array:
	var hl: float = length * 0.5
	var out: Array = [-hl + GS_END * 0.5, hl - GS_END * 0.5, 0.0]
	if length > 40.0:
		out.append(-length * 0.25)
		out.append(length * 0.25)
	return out


## The race's temporary grandstand: a scaffold stand x +-length/2, its front (+z) at z = 0, `rows` rows of plastic
## seats (GS_TREAD deep, GS_RISE apart) over a front walkway (GS_WALK up, its railing and a fascia of sponsors' banners
## below it), stairs at both ends and aisles between the blocks, the back railing over a wall of banners, flags on the
## back corners, the scaffold (standards on base plates, ledgers, rakers, braces) under it all. temp_grandstand_seats gives
## the seats (the top of each seat), temp_grandstand_solids its boxes. Depth GS_WALK_D + rows * GS_TREAD.
static func temp_grandstand(pk: PropKit, kit: Dictionary, labels: Array, rows := 8, length := 60.0) -> void:
	var hl: float = length * 0.5
	var back: float = _gs_row(rows - 1).x - GS_TREAD
	var top: float = _gs_row(rows - 1).y
	var aisles: Array = _gs_aisles(length)
	# The scaffold: standards at every bay line and every other row line.
	var nb: int = maxi(1, int(round(length / GS_BAY)))
	var zl: Array = [-0.08, -GS_WALK_D + 0.05]
	for k in range(1, rows + 1, 2):
		zl.append(_gs_row(k).x - GS_TREAD + 0.05 if k < rows else back + 0.05)
	if float(zl[-1]) > back + 0.1:
		zl.append(back + 0.05)
	for i in range(nb + 1):
		var x: float = lerpf(-hl + 0.06, hl - 0.06, float(i) / float(nb))
		var prev_y := 0.0
		for zz in zl:
			var z: float = zz
			var ytop: float = _gs_height_at(z, rows) - 0.06
			pk.tube(kit, "metal", Vector3(x, 0.0, z), Vector3(x, ytop, z), 0.024, 0.024, 6, GS_SCAFF, false)
			_blk(pk, kit, "metal", Vector3(x - 0.08, 0.0, z - 0.08), Vector3(x + 0.08, 0.02, z + 0.08), GS_SCAFF.darkened(0.2))
			_blk(pk, kit, "timber", Vector3(x - 0.14, -0.04, z - 0.12), Vector3(x + 0.14, 0.0, z + 0.12), Color(0.55, 0.42, 0.27))
			prev_y = ytop
		# The raker under the treads along z, and a transom at knee height.
		pk.beam(kit, "metal", Vector3(x, GS_WALK - 0.1, -GS_WALK_D), Vector3(x, top - 0.1, back), 0.08, 0.14, GS_SCAFF.darkened(0.1), Vector3(1, 0, 0))
		pk.tube(kit, "metal", Vector3(x, 0.45, -0.08), Vector3(x, 0.45, back + 0.05), 0.024, 0.024, 6, GS_SCAFF, false)
		# Braces in the end frames and every fourth bay.
		if i == 0 or i == nb or i % 4 == 2:
			for k in range(zl.size() - 1):
				var za: float = zl[k]
				var zb: float = zl[k + 1]
				var ya: float = 0.15
				var yb2: float = minf(_gs_height_at(zb, rows) - 0.2, _gs_height_at(za, rows) + 1.5)
				pk.tube(kit, "metal", Vector3(x + 0.03, ya, za), Vector3(x + 0.03, yb2, zb), 0.022, 0.022, 5, GS_SCAFF.darkened(0.05), false)
	# Ledgers along x at each standard line, low and high, and longitudinal braces.
	for zz in zl:
		var z: float = zz
		var yh: float = _gs_height_at(z, rows) - 0.25
		for y in [0.45, (0.45 + yh) * 0.5, yh]:
			if y > 0.3 and y <= yh:
				pk.tube(kit, "metal", Vector3(-hl + 0.06, y, z + 0.03), Vector3(hl - 0.06, y, z + 0.03), 0.022, 0.022, 5, GS_SCAFF, false)
	for i in range(0, nb, 3):
		var xa: float = lerpf(-hl + 0.06, hl - 0.06, float(i) / float(nb))
		var xb: float = lerpf(-hl + 0.06, hl - 0.06, float(mini(i + 1, nb)) / float(nb))
		pk.tube(kit, "metal", Vector3(xa, 0.2, back + 0.08), Vector3(xb, _gs_height_at(back + 0.05, rows) - 0.3, back + 0.08), 0.022, 0.022, 5, GS_SCAFF, false)
	# The front walkway: its deck, the fascia of banners below it, the railing on it.
	_blk(pk, kit, "steel", Vector3(-hl, GS_WALK - 0.06, -GS_WALK_D), Vector3(hl, GS_WALK, 0.0), GS_DECK)
	var nbn: int = maxi(1, int(length / 9.0))
	for i in range(nbn):
		var xa2: float = -hl + length * float(i) / float(nbn)
		var xb2: float = -hl + length * float(i + 1) / float(nbn)
		var bn: Array = GS_BANNERS[i % GS_BANNERS.size()]
		pk.quad(kit, "canvas", [Vector3(xa2 + 0.03, 0.08, 0.02), Vector3(xb2 - 0.03, 0.08, 0.02), Vector3(xb2 - 0.03, GS_WALK - 0.08, 0.02), Vector3(xa2 + 0.03, GS_WALK - 0.08, 0.02)],
				Vector3(0, 0, 1), bn[1])
		_lbl(labels, String(bn[0]), Vector3((xa2 + xb2) * 0.5, GS_WALK * 0.5, 0.035), Vector3(0, 0, 1), 0.36, bn[2], xb2 - xa2 - 0.6)
	_gs_rail(pk, kit, Vector3(-hl + 0.05, GS_WALK, -0.05), Vector3(hl - 0.05, GS_WALK, -0.05))
	# The rows: risers, treads, the seats on a bench rail at the back of each tread (gaps at the aisles).
	for k in range(rows):
		var r: Vector2 = _gs_row(k)
		var zf: float = r.x
		var zb3: float = r.x - GS_TREAD
		_blk(pk, kit, "steel", Vector3(-hl, r.y - GS_RISE - 0.02, zf - 0.03), Vector3(hl, r.y, zf), GS_DECK.darkened(0.25))
		_blk(pk, kit, "steel", Vector3(-hl, r.y - 0.05, zb3), Vector3(hl, r.y, zf - 0.03), GS_DECK)
		var col: Color = GS_SEAT_COLS[k % GS_SEAT_COLS.size()] if k % 4 != 1 else GS_SEAT_COLS[1]
		var runs: Array = _gs_seat_runs(length)
		for run in runs:
			var xa3: float = run[0]
			var xb3: float = run[1]
			var sz: float = zb3 + 0.32
			# A bench rail, then the moulded seats as one pan and one back per run, grooved at every seat.
			_blk(pk, kit, "metal", Vector3(xa3, r.y, sz - 0.05), Vector3(xb3, r.y + GS_SEAT_H - 0.07, sz + 0.05), ANTHRACITE)
			_blk(pk, kit, "plastic", Vector3(xa3, r.y + GS_SEAT_H - 0.06, sz - 0.2), Vector3(xb3, r.y + GS_SEAT_H, sz + 0.2), col)
			var bb := Basis(Vector3(1, 0, 0), Vector3(0, cos(0.18), -sin(0.18)), Vector3(0, sin(0.18), cos(0.18)))
			_box(pk, kit, "plastic", Vector3((xa3 + xb3) * 0.5, r.y + GS_SEAT_H + 0.2, sz - 0.24), bb, Vector3(xb3 - xa3, 0.36, 0.04), col.darkened(0.05))
			var ns: int = int(round((xb3 - xa3) / GS_SEAT_PITCH))
			# The grooves between the seats: a dark line across the pan and up the back, 4mm proud (single quads).
			var gcol: Color = col.darkened(0.4)
			var bf: Vector3 = Vector3((xa3 + xb3) * 0.5, r.y + GS_SEAT_H + 0.2, sz - 0.24) + bb.z * 0.024
			for s in range(1, ns):
				var gx: float = xa3 + (xb3 - xa3) * float(s) / float(ns)
				var gy: float = r.y + GS_SEAT_H + 0.004
				pk.quad(kit, "plastic", [Vector3(gx - 0.012, gy, sz + 0.19), Vector3(gx + 0.012, gy, sz + 0.19), Vector3(gx + 0.012, gy, sz - 0.19),
						Vector3(gx - 0.012, gy, sz - 0.19)], UP, gcol)
				var b0: Vector3 = Vector3(gx, bf.y, bf.z) - bb.y * 0.17
				var b1: Vector3 = Vector3(gx, bf.y, bf.z) + bb.y * 0.17
				pk.quad(kit, "plastic", [b0 - bb.x * 0.012, b0 + bb.x * 0.012, b1 + bb.x * 0.012, b1 - bb.x * 0.012], bb.z, gcol)
		# Aisle half-steps up to the next row (two per tread).
		for ax in aisles:
			var hw2: float = GS_END * 0.45 if absf(absf(float(ax)) - (hl - GS_END * 0.5)) < 0.01 else GS_AISLE * 0.45
			_blk(pk, kit, "steel", Vector3(float(ax) - hw2, r.y, zf - GS_TREAD * 0.5), Vector3(float(ax) + hw2, r.y + GS_RISE * 0.5, zb3), GS_DECK.lightened(0.05))
			_blk(pk, kit, "enamel", Vector3(float(ax) - hw2, r.y + GS_RISE * 0.5 - 0.01, zf - GS_TREAD * 0.5 - 0.05), Vector3(float(ax) + hw2, r.y + GS_RISE * 0.5 + 0.02,
					zf - GS_TREAD * 0.5 + 0.005), SIGN_YELLOW)
			_blk(pk, kit, "enamel", Vector3(float(ax) - hw2, r.y - 0.01, zf - 0.05), Vector3(float(ax) + hw2, r.y + 0.02, zf - 0.025), SIGN_YELLOW)
	# The end stairs from the ground up to the walkway (along -z at both ends), the end railings up the rake.
	for sx in [-1.0, 1.0]:
		var ex: float = sx * (hl - GS_END * 0.5)
		var nst := 5
		for s in range(nst):
			var y1: float = GS_WALK * float(s + 1) / float(nst)
			var zf2: float = 0.55 - 0.31 * float(s)
			_blk(pk, kit, "steel", Vector3(ex - GS_END * 0.45, y1 - 0.05, zf2 - 0.31), Vector3(ex + GS_END * 0.45, y1, zf2), GS_DECK.lightened(0.05))
			_blk(pk, kit, "enamel", Vector3(ex - GS_END * 0.45, y1 - 0.01, zf2 - 0.05), Vector3(ex + GS_END * 0.45, y1 + 0.02, zf2 + 0.005), SIGN_YELLOW)
		for side in [-1.0, 1.0]:
			var rx: float = ex + side * GS_END * 0.47
			pk.tube(kit, "metal", Vector3(rx, 0.05, 0.55), Vector3(rx, 1.0, 0.55), 0.025, 0.025, 6, GS_SCAFF, true)
			pk.tube(kit, "metal", Vector3(rx, 1.0, 0.55), Vector3(rx, GS_WALK + 1.0, -GS_WALK_D + 0.05), 0.025, 0.025, 6, GS_SCAFF, true)
		var ox: float = sx * (hl - 0.04)
		var pts: Array = [Vector3(ox, GS_WALK + 1.05, -0.05)]
		for k in range(rows):
			var rr: Vector2 = _gs_row(k)
			pts.append(Vector3(ox, rr.y + 1.05, rr.x - GS_TREAD * 0.5))
		pts.append(Vector3(ox, top + 1.05, back + 0.05))
		for k in range(pts.size() - 1):
			var p: Vector3 = pts[k]
			var q: Vector3 = pts[k + 1]
			pk.tube(kit, "metal", p, q, 0.025, 0.025, 6, GS_SCAFF, k == 0 or k == pts.size() - 2)
			pk.tube(kit, "metal", p - UP * 0.5, q - UP * 0.5, 0.02, 0.02, 6, GS_SCAFF, false)
			pk.tube(kit, "metal", Vector3(q.x, q.y - 1.05, q.z), q, 0.024, 0.024, 6, GS_SCAFF, false)
	# The back: a railing over a wall of banners down to the ground, facing out.
	_gs_rail(pk, kit, Vector3(hl - 0.05, top, back + 0.05), Vector3(-hl + 0.05, top, back + 0.05))
	for i in range(nbn):
		var xa4: float = -hl + length * float(i) / float(nbn)
		var xb4: float = -hl + length * float(i + 1) / float(nbn)
		var bn2: Array = GS_BANNERS[(i + 2) % GS_BANNERS.size()]
		pk.quad(kit, "canvas", [Vector3(xb4 - 0.03, 0.3, back - 0.03), Vector3(xa4 + 0.03, 0.3, back - 0.03), Vector3(xa4 + 0.03, top - 0.15, back - 0.03),
				Vector3(xb4 - 0.03, top - 0.15, back - 0.03)], Vector3(0, 0, -1), bn2[1])
		_lbl(labels, String(bn2[0]), Vector3((xa4 + xb4) * 0.5, top * 0.55, back - 0.045), Vector3(0, 0, -1), 0.6, bn2[2], xb4 - xa4 - 0.8)
	# Flags on poles at the back corners.
	for sx2 in [-1.0, 1.0]:
		var fp := Vector3(sx2 * (hl - 0.1), top, back + 0.1)
		pk.tube(kit, "metal", fp, fp + UP * 4.2, 0.035, 0.025, 6, GALV, true)
		var fc: Color = [Color(0.10, 0.18, 0.42), Color(0.98, 0.78, 0.15)][int(sx2 > 0.0)]
		var fa: Vector3 = fp + UP * 4.1
		pk.panel(kit, "pennant", [fa, fa + Vector3(-sx2 * 1.6, -0.08, 0.04), fa + Vector3(-sx2 * 1.6, -1.0, 0.04), fa + Vector3(0, -1.0, 0)], Vector3(0, 0, 1), fc, fc)


## The height of the stand's surface over z (the walkway, then each tread).
static func _gs_height_at(z: float, rows: int) -> float:
	if z > -GS_WALK_D:
		return GS_WALK
	var k: int = clampi(int(floor((-GS_WALK_D - z) / GS_TREAD)), 0, rows - 1)
	return _gs_row(k).y


## The seat runs along x between the aisles: [x0, x1] pairs.
static func _gs_seat_runs(length: float) -> Array:
	var hl: float = length * 0.5
	var cuts: Array = []
	for ax in _gs_aisles(length):
		var hw: float = GS_END * 0.5 if absf(absf(float(ax)) - (hl - GS_END * 0.5)) < 0.01 else GS_AISLE * 0.5
		cuts.append([float(ax) - hw, float(ax) + hw])
	cuts.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var out: Array = []
	var x: float = -hl
	for c in cuts:
		if float(c[0]) - x > 0.5:
			out.append([x + 0.05, float(c[0]) - 0.05])
		x = maxf(x, float(c[1]))
	if hl - x > 0.5:
		out.append([x + 0.05, hl - 0.05])
	return out


## A railing from a to b at floor height (posts, a top rail, a knee rail, a toe board) in galvanised tube.
static func _gs_rail(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3) -> void:
	var n: int = maxi(1, int(ceil(a.distance_to(b) / 2.0)))
	for k in range(n + 1):
		var p: Vector3 = a.lerp(b, float(k) / float(n))
		pk.tube(kit, "metal", p, p + UP * 1.1, 0.025, 0.025, 6, GS_SCAFF, true)
	pk.tube(kit, "metal", a + UP * 1.1, b + UP * 1.1, 0.025, 0.025, 6, GS_SCAFF, true)
	pk.tube(kit, "metal", a + UP * 0.55, b + UP * 0.55, 0.02, 0.02, 6, GS_SCAFF, true)
	pk.beam(kit, "metal", a + UP * 0.08, b + UP * 0.08, 0.15, 0.02, GS_SCAFF.darkened(0.15), UP.cross(b - a).normalized())


## The spectators' seats: the top of each seat's middle (life, the stand's frame), every GS_SEAT_PITCH along each run.
static func temp_grandstand_seats(rows := 8, length := 60.0) -> Array:
	var out: Array = []
	for k in range(rows):
		var r: Vector2 = _gs_row(k)
		var sz: float = r.x - GS_TREAD + 0.32
		for run in _gs_seat_runs(length):
			var xa: float = run[0]
			var xb: float = run[1]
			var ns: int = int(round((xb - xa) / GS_SEAT_PITCH))
			for s in range(ns):
				out.append(Vector3(xa + (xb - xa) * (float(s) + 0.5) / float(ns), r.y + GS_SEAT_H, sz))
	return out


## The stand's collision: the walkway and its front, then a box per row from the ground up to its tread.
static func temp_grandstand_solids(rows := 8, length := 60.0) -> Array:
	var out: Array = []
	out.append([Transform3D(Basis(), Vector3(0, (GS_WALK + 1.1) * 0.5, -GS_WALK_D * 0.5)), Vector3(length, GS_WALK + 1.1, GS_WALK_D)])
	for k in range(rows):
		var r: Vector2 = _gs_row(k)
		out.append([Transform3D(Basis(), Vector3(0, r.y * 0.5, r.x - GS_TREAD * 0.5)), Vector3(length, r.y, GS_TREAD)])
	return out


# ======================================================================================
#  The Ring's traffic (each a MultiMesh: few keys, nothing read from the world position) and the trams
# ======================================================================================

const CAR_GLASS := Color(0.05, 0.07, 0.09)
const PLATE := Color(0.95, 0.95, 0.93)

## A side profile with its wheel arches: from (f_back, bottom) forward along the bottom, a notch of radius R round each
## axle (centre at cy over the ground), to (f_front, bottom), then `upper` (from the front over the top to the back). CCW
## in (forward, up).
static func _profile(bottom: float, f_back: float, f_front: float, axles: Array, R: float, cy: float, upper: Array) -> PackedVector2Array:
	var ol := PackedVector2Array()
	ol.append(Vector2(f_back, bottom))
	var axs: Array = axles.duplicate()
	axs.sort()
	for ax in axs:
		var a: float = ax
		ol.append(Vector2(a - R, bottom))
		for k in range(9):
			var t: float = PI - PI * float(k) / 8.0
			ol.append(Vector2(a + cos(t) * R, cy + sin(t) * R))
		ol.append(Vector2(a + R, bottom))
	ol.append(Vector2(f_front, bottom))
	for p in upper:
		ol.append(p)
	return ol


## The colour function for a body with arches: black under `trim_y` and in the arches (and undersides), `col` elsewhere,
## `roof` on faces looking up over `roof_y`.
static func _body_fn(col: Color, trim_y: float, axles: Array, R: float, cy: float, roof := Color(0, 0, 0, 0), roof_y := 99.0) -> Callable:
	return func(m: Vector3, n: Vector3) -> Color:
		var f: float = -m.z
		if n.y < -0.4:
			return TRIM_BLACK
		for ax in axles:
			if Vector2(f - float(ax), m.y - cy).length() < R + 0.04 and m.y < cy + R + 0.05:
				return TRIM_BLACK
		if m.y < trim_y:
			return TRIM_BLACK
		if roof.a > 0.0 and n.y > 0.6 and m.y > roof_y:
			return roof
		return col


## A polygon in the side plane (forward, up) laid at x facing `nx` (+1 or -1): glass, bands, lettering grounds.
static func _side_poly(pk: PropKit, kit: Dictionary, key: String, poly: PackedVector2Array, x: float, nx: float, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	var n := Vector3(nx, 0, 0)
	for i in range(0, tris.size(), 3):
		var a: Vector2 = poly[tris[i]]
		var b: Vector2 = poly[tris[i + 1]]
		var c: Vector2 = poly[tris[i + 2]]
		pk.tri(kit, key, Vector3(x, a.y, -a.x), Vector3(x, b.y, -b.x), Vector3(x, c.y, -c.x), n, n, n, col, n)


## A rectangle [f0, f1] x [y0, y1] on both sides at +-x (facing out).
static func _side_rect(pk: PropKit, kit: Dictionary, key: String, f0: float, f1: float, y0: float, y1: float, x: float, col: Color) -> void:
	var poly := PackedVector2Array([Vector2(f0, y0), Vector2(f1, y0), Vector2(f1, y1), Vector2(f0, y1)])
	_side_poly(pk, kit, key, poly, x, 1.0, col)
	_side_poly(pk, kit, key, poly, -x, -1.0, col)


## A quad lying on the outline edge a -> b (forward, up), across x +-hx, `off` out along its outward normal (CCW
## outline: the normal is the edge turned clockwise), trimmed by `trim` metres at both ends: a windscreen's glass.
static func _edge_quad(pk: PropKit, kit: Dictionary, key: String, a: Vector2, b: Vector2, hx: float, off: float, trim: float, col: Color) -> void:
	var e: Vector2 = b - a
	var el: float = e.length()
	var t: Vector2 = e / el
	var n2 := Vector2(t.y, -t.x)
	var a2: Vector2 = a + t * trim + n2 * off
	var b2: Vector2 = b - t * trim + n2 * off
	var n3 := Vector3(0, n2.y, -n2.x)
	pk.quad(kit, key, [Vector3(-hx, a2.y, -a2.x), Vector3(hx, a2.y, -a2.x), Vector3(hx, b2.y, -b2.x), Vector3(-hx, b2.y, -b2.x)], n3, col)


## A number plate (white, a blue strip, a made-up number) at c facing `n` (+z or -z).
static func _plate(pk: PropKit, kit: Dictionary, c: Vector3, n: Vector3, text: String) -> void:
	# Seen from in front, the plate's right is UP x n (facing -z, that is -x).
	var right: Vector3 = UP.cross(n).normalized()
	_box(pk, kit, "plastic", c, Basis(right, UP, n), Vector3(0.52, 0.11, 0.012), PLATE)
	_box(pk, kit, "plastic", c + n * 0.007 - right * 0.23, Basis(right, UP, n), Vector3(0.05, 0.1, 0.004), U_BLUE)
	_gtext(pk, kit, "matte", c + n * 0.01 + right * 0.025, right, UP, minf(0.016, 0.42 / float(_cells(text))), text, BLACK)


## A car from two side profiles (nose toward -z, y = 0 the road): `lower` the body to the belt line (hw a side), `cabin`
## the greenhouse on it (0.09 narrower), its side windows `glass` (forward, up) with B-pillars at `pillars` [f0, f1], the
## windscreen and the rear window on the cabin's outline edges `screen` and `back`; wheels of radius r on `axles` in
## arches of radius R.
static func _car(pk: PropKit, kit: Dictionary, o: Dictionary) -> void:
	var col: Color = o["col"]
	var hw: float = o["hw"]
	var axles: Array = o["axles"]
	var R: float = o["R"]
	var cy: float = o["cy"]
	var r: float = o["r"]
	var hc: float = hw - 0.09
	_side_extrude(pk, kit, "gloss", o["lower"], -hw, hw, 0.05, col, _body_fn(col, o["trim_y"], axles, R, cy))
	_side_extrude(pk, kit, "gloss", o["cabin"], -hc, hc, 0.06, col, _body_fn(col, 0.0, [], R, cy, o.get("roof", Color(0, 0, 0, 0)), 1.2))
	for side in [1.0, -1.0]:
		_side_poly(pk, kit, "gloss", o["glass"], side * (hc + 0.015), side, CAR_GLASS)
		for pl in o["pillars"]:
			_side_poly(pk, kit, "matte", PackedVector2Array([Vector2(pl[0], 0.96), Vector2(pl[1], 0.96), Vector2(pl[1], 1.4), Vector2(pl[0], 1.4)]),
					side * (hc + 0.025), side, TRIM_BLACK)
		for ax in axles:
			_wheel(pk, kit, Vector3(side * (hw - 0.12), r, -float(ax)), r, 0.2, side, Color(0.72, 0.73, 0.75), 12)
		# A mirror on a stalk at the window's front corner.
		var mf: float = o["mirror_f"]
		var my: float = o["mirror_y"]
		pk.beam(kit, "matte", Vector3(side * (hc - 0.02), my, -mf), Vector3(side * (hw + 0.1), my, -mf - 0.04), 0.04, 0.05, TRIM_BLACK)
		_box(pk, kit, "gloss", Vector3(side * (hw + 0.14), my + 0.02, -mf - 0.06), Basis(), Vector3(0.1, 0.12, 0.18), col)
		_box(pk, kit, "matte", Vector3(side * (hw + 0.14), my + 0.02, -mf + 0.035), Basis(), Vector3(0.08, 0.1, 0.012), CAR_GLASS)
		# The door shut lines.
		for df in o["doors"]:
			_side_poly(pk, kit, "matte", PackedVector2Array([Vector2(df - 0.008, 0.36), Vector2(df + 0.008, 0.36), Vector2(df + 0.008, 0.9), Vector2(df - 0.008, 0.9)]),
					side * (hw + 0.006), side, TRIM_BLACK)
	var sc: Array = o["screen"]
	_edge_quad(pk, kit, "gloss", sc[0], sc[1], hc - 0.1, 0.012, 0.05, CAR_GLASS)
	var bk: Array = o["back"]
	_edge_quad(pk, kit, "gloss", bk[0], bk[1], hc - 0.12, 0.012, 0.05, CAR_GLASS)
	# Lamps, grille, plates.
	var ff: float = o["front_f"]
	var bf: float = o["back_f"]
	var hy: float = o["head_y"]
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "lamp", Vector3(sx * (hw - 0.26), hy, -ff - 0.01), Basis(), Vector3(0.34, 0.11, 0.05), HEAD_LAMP)
		_box(pk, kit, "lamp", Vector3(sx * (hw - 0.07), hy - 0.02, -ff + 0.04), Basis(), Vector3(0.08, 0.07, 0.06), AMBER)
		_box(pk, kit, "lamp", Vector3(sx * (hw - 0.2), o["tail_y"], -bf + 0.01), Basis(), Vector3(0.3, 0.13, 0.05), TAIL_LAMP)
	_box(pk, kit, "matte", Vector3(0, hy - 0.04, -ff - 0.005), Basis(), Vector3(hw * 0.75, 0.13, 0.05), TRIM_BLACK)
	# The bumper's black strip 3.5cm proud of the body's front, the plate over it.
	_box(pk, kit, "matte", Vector3(0, 0.38, -ff - 0.065), Basis(), Vector3(hw * 1.1, 0.12, 0.06), TRIM_BLACK)
	_plate(pk, kit, Vector3(0, 0.5, -ff - 0.045), Vector3(0, 0, -1), o.get("plate", "KRB-A 123"))
	_plate(pk, kit, Vector3(0, o["plate_back_y"], bf + 0.03), Vector3(0, 0, 1), o.get("plate", "KRB-A 123"))


## A five-door hatchback (life 4.05 x 1.78 x 1.46m) in `col`; returns its size.
static func hatchback(pk: PropKit, kit: Dictionary, col := Color(0.78, 0.10, 0.08)) -> Vector3:
	var axles: Array = [1.175, -1.425]
	var R := 0.37
	var cy := 0.33
	_car(pk, kit, {
		"col": col, "hw": 0.89, "axles": axles, "R": R, "cy": cy, "r": 0.31, "trim_y": 0.3,
		"lower": _profile(0.2, -1.98, 2.0, axles, R, cy, [Vector2(2.03, 0.38), Vector2(2.03, 0.58), Vector2(1.96, 0.72), Vector2(1.0, 0.9), Vector2(0.95, 0.93),
				Vector2(-1.88, 0.97), Vector2(-2.0, 0.93), Vector2(-2.03, 0.62), Vector2(-2.0, 0.3)]),
		"cabin": PackedVector2Array([Vector2(-1.9, 0.9), Vector2(0.97, 0.9), Vector2(0.28, 1.42), Vector2(0.05, 1.46), Vector2(-1.15, 1.45), Vector2(-1.42, 1.38),
				Vector2(-1.93, 0.97)]),
		"glass": PackedVector2Array([Vector2(0.72, 0.98), Vector2(0.18, 1.37), Vector2(-1.05, 1.39), Vector2(-1.3, 1.33), Vector2(-1.58, 0.99)]),
		"pillars": [[-0.32, -0.24]], "doors": [0.86, -0.28, -1.32],
		"screen": [Vector2(0.97, 0.9), Vector2(0.28, 1.42)], "back": [Vector2(-1.42, 1.38), Vector2(-1.93, 0.97)],
		"mirror_f": 0.8, "mirror_y": 1.0, "front_f": 2.0, "back_f": -2.0, "head_y": 0.66, "tail_y": 0.92, "plate_back_y": 0.62,
		"plate": "KRB-HL 41",
	})
	return Vector3(1.78, 1.46, 4.05)


## A saloon (life 4.84 x 1.84 x 1.47m) in `col`; `taxi` puts the lit TAXI sign on its roof (German taxis: ivory).
static func saloon(pk: PropKit, kit: Dictionary, col := Color(0.16, 0.16, 0.17), taxi := false) -> Vector3:
	var axles: Array = [1.5, -1.35]
	var R := 0.38
	var cy := 0.34
	_car(pk, kit, {
		"col": col, "hw": 0.92, "axles": axles, "R": R, "cy": cy, "r": 0.32, "trim_y": 0.3,
		"lower": _profile(0.2, -2.38, 2.38, axles, R, cy, [Vector2(2.42, 0.36), Vector2(2.42, 0.58), Vector2(2.34, 0.74), Vector2(1.25, 0.88), Vector2(1.15, 0.92),
				Vector2(-1.55, 0.97), Vector2(-2.3, 0.98), Vector2(-2.42, 0.9), Vector2(-2.44, 0.5), Vector2(-2.4, 0.3)]),
		"cabin": PackedVector2Array([Vector2(-1.62, 0.9), Vector2(1.18, 0.9), Vector2(0.42, 1.42), Vector2(0.15, 1.46), Vector2(-0.85, 1.45), Vector2(-1.1, 1.38),
				Vector2(-1.68, 0.98)]),
		"glass": PackedVector2Array([Vector2(0.92, 0.98), Vector2(0.36, 1.37), Vector2(-0.8, 1.39), Vector2(-0.95, 1.33), Vector2(-1.42, 0.99)]),
		"pillars": [[-0.12, -0.04]], "doors": [1.05, -0.08, -1.18],
		"screen": [Vector2(1.18, 0.9), Vector2(0.42, 1.42)], "back": [Vector2(-1.1, 1.38), Vector2(-1.68, 0.98)],
		"mirror_f": 1.0, "mirror_y": 1.0, "front_f": 2.42, "back_f": -2.44, "head_y": 0.66, "tail_y": 0.88, "plate_back_y": 0.66,
		"plate": "KRB-TX 7" if taxi else "KRB-S 905",
	})
	if taxi:
		var c := Vector3(0, 1.545, 0.3)
		_box(pk, kit, "plastic", c - Vector3(0, 0.06, 0), Basis(), Vector3(0.66, 0.04, 0.26), Color(0.15, 0.15, 0.15))
		_box(pk, kit, "lamp", c + Vector3(0, 0.04, 0), Basis(), Vector3(0.6, 0.16, 0.2), Color(1.0, 0.86, 0.35))
		for s in [-1.0, 1.0]:
			_gtext(pk, kit, "matte", c + Vector3(0, 0.04, s * 0.106), Vector3(s, 0, 0), UP, 0.022, "TAXI", BLACK)
	return Vector3(1.84, 1.47, 4.84)


## A delivery van (life 5.95 x 2.0 x 2.58m) in `col`, the courier's name along its sides; returns its size.
static func delivery_van(pk: PropKit, kit: Dictionary, col := Color(0.92, 0.92, 0.90)) -> Vector3:
	var axles: Array = [2.0, -1.66]
	var R := 0.42
	var cy := 0.4
	var hw := 1.0
	var ol := _profile(0.3, -2.95, 2.97, axles, R, cy, [Vector2(2.99, 0.42), Vector2(2.99, 0.7), Vector2(2.9, 0.95), Vector2(2.45, 1.12), Vector2(2.38, 1.16),
			Vector2(1.82, 2.08), Vector2(1.62, 2.52), Vector2(1.4, 2.58), Vector2(-2.9, 2.58), Vector2(-2.975, 2.5), Vector2(-2.975, 0.42)])
	_side_extrude(pk, kit, "gloss", ol, -hw, hw, 0.06, col, _body_fn(col, 0.38, axles, R, cy))
	_edge_quad(pk, kit, "gloss", Vector2(2.38, 1.16), Vector2(1.82, 2.08), hw - 0.16, 0.012, 0.06, CAR_GLASS)
	var cab := PackedVector2Array([Vector2(2.15, 1.32), Vector2(1.72, 2.0), Vector2(1.02, 2.0), Vector2(1.02, 1.32)])
	var band := Color(0.85, 0.12, 0.10)
	for side in [1.0, -1.0]:
		_side_poly(pk, kit, "gloss", cab, side * (hw + 0.012), side, CAR_GLASS)
		for ax in axles:
			_wheel(pk, kit, Vector3(side * (hw - 0.13), 0.36, -float(ax)), 0.36, 0.22, side, Color(0.62, 0.63, 0.65), 12)
		# The courier's band and name along the cargo box, the door seams.
		_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(-2.85, 1.0), Vector2(0.95, 1.0), Vector2(0.95, 1.22), Vector2(-2.85, 1.22)]), side * (hw + 0.008),
				side, band)
		var tc := Vector3(side * (hw + 0.014), 1.62, 1.72)
		_gtext(pk, kit, "matte", tc, Vector3(0, 0, -side), UP, 0.04, "BLITZ KURIER", band)
		for sf in ([0.92, -0.42, -2.9] if side > 0.0 else [0.92, -2.9]):
			_side_poly(pk, kit, "matte", PackedVector2Array([Vector2(sf - 0.008, 0.45), Vector2(sf + 0.008, 0.45), Vector2(sf + 0.008, 2.45), Vector2(sf - 0.008, 2.45)]),
					side * (hw + 0.016), side, TRIM_BLACK)
		pk.beam(kit, "matte", Vector3(side * (hw - 0.02), 1.85, -1.95), Vector3(side * (hw + 0.14), 1.85, -2.0), 0.04, 0.05, TRIM_BLACK)
		_box(pk, kit, "matte", Vector3(side * (hw + 0.16), 1.72, -2.0), Basis(), Vector3(0.06, 0.32, 0.16), TRIM_BLACK)
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "lamp", Vector3(sx * 0.68, 0.98, -2.93), Basis(Vector3(1, 0, 0), 0.4), Vector3(0.36, 0.14, 0.06), HEAD_LAMP)
		_box(pk, kit, "lamp", Vector3(sx * 0.9, 0.95, 2.985), Basis(), Vector3(0.14, 0.42, 0.04), TAIL_LAMP)
	_box(pk, kit, "matte", Vector3(0, 0.78, -2.99), Basis(), Vector3(1.0, 0.24, 0.05), TRIM_BLACK)
	_box(pk, kit, "matte", Vector3(0, 0.45, -2.99), Basis(), Vector3(1.96, 0.2, 0.08), TRIM_BLACK)
	_box(pk, kit, "matte", Vector3(0, 0.45, 2.99), Basis(), Vector3(1.96, 0.2, 0.08), TRIM_BLACK)
	_box(pk, kit, "matte", Vector3(0, 1.4, 2.98), Basis(), Vector3(0.016, 2.0, 0.02), TRIM_BLACK)
	_plate(pk, kit, Vector3(0, 0.62, -3.01), Vector3(0, 0, -1), "KRB-BK 88")
	_plate(pk, kit, Vector3(0, 0.62, 3.02), Vector3(0, 0, 1), "KRB-BK 88")
	return Vector3(2.0, 2.58, 5.95)


const TRUCK_LIVERIES := [
	["KRONBURGER GETRAENKE", Color(0.10, 0.36, 0.20), Color(0.96, 0.96, 0.94), Color(0.96, 0.96, 0.94)],
	["MOEBEL HUELSMANN", Color(0.92, 0.92, 0.90), Color(0.12, 0.24, 0.52), Color(0.12, 0.24, 0.52)],
]

## A 7.5t box truck (life 7.8 x 2.5 x 3.6m): a cab with its windscreen and doors, a chassis, the box with the firm's
## livery (`variant`: TRUCK_LIVERIES), dual rear wheels, side guards and the rear underrun bar; returns its size.
static func box_truck(pk: PropKit, kit: Dictionary, variant := 0) -> Vector3:
	var lv: Array = TRUCK_LIVERIES[posmod(variant, TRUCK_LIVERIES.size())]
	var cab_col: Color = lv[3]
	var box_col: Color = lv[1]
	var ink: Color = lv[2]
	var hc := 1.15
	var hb := 1.25
	var fa := 2.75
	var ra := -1.45
	var r := 0.46
	var ol := _profile(0.5, 1.95, 3.9, [fa], 0.52, 0.52, [Vector2(3.92, 0.6), Vector2(3.93, 1.25), Vector2(3.85, 1.42), Vector2(3.62, 2.42), Vector2(3.42, 2.72),
			Vector2(2.0, 2.75), Vector2(1.95, 2.6)])
	_side_extrude(pk, kit, "gloss", ol, -hc, hc, 0.07, cab_col, _body_fn(cab_col, 0.62, [fa], 0.52, 0.52))
	_edge_quad(pk, kit, "gloss", Vector2(3.85, 1.42), Vector2(3.62, 2.42), hc - 0.14, 0.012, 0.06, CAR_GLASS)
	var dw := PackedVector2Array([Vector2(3.55, 1.6), Vector2(3.42, 2.3), Vector2(2.45, 2.35), Vector2(2.45, 1.6)])
	for side in [1.0, -1.0]:
		_side_poly(pk, kit, "gloss", dw, side * (hc + 0.012), side, CAR_GLASS)
		_side_poly(pk, kit, "matte", PackedVector2Array([Vector2(2.37, 0.7), Vector2(2.39, 0.7), Vector2(2.39, 2.45), Vector2(2.37, 2.45)]), side * (hc + 0.014), side, TRIM_BLACK)
		_box(pk, kit, "matte", Vector3(side * (hc - 0.15), 0.85, -2.3), Basis(), Vector3(0.36, 0.08, 0.3), TRIM_BLACK)
		pk.beam(kit, "matte", Vector3(side * (hc - 0.02), 2.25, -3.5), Vector3(side * (hc + 0.2), 2.3, -3.55), 0.05, 0.05, TRIM_BLACK)
		_box(pk, kit, "matte", Vector3(side * (hc + 0.22), 2.0, -3.55), Basis(), Vector3(0.07, 0.48, 0.2), TRIM_BLACK)
		_wheel(pk, kit, Vector3(side * (hc - 0.16), r, -fa), r, 0.28, side, Color(0.70, 0.70, 0.72), 14)
		_wheel(pk, kit, Vector3(side * (hb - 0.16), r, -ra), r, 0.26, side, Color(0.70, 0.70, 0.72), 14, true)
		# The mudguard over the rear wheels, the side guard between the axles.
		_box(pk, kit, "matte", Vector3(side * (hb - 0.3), 1.0, -ra), Basis(), Vector3(0.62, 0.06, 1.15), TRIM_BLACK)
		for gy in [0.55, 0.82]:
			_box(pk, kit, "matte", Vector3(side * (hb - 0.06), gy, -(fa + ra) * 0.5 + 0.2), Basis(), Vector3(0.05, 0.1, 2.5), Color(0.55, 0.56, 0.57))
		# The firm's name along the box, a band under it.
		var tc := Vector3(side * (hb + 0.012), 2.55, 1.025)
		_gtext(pk, kit, "matte", tc, Vector3(0, 0, -side), UP, minf(0.075, 5.2 / float(_cells(String(lv[0])))), String(lv[0]), ink)
		_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(-3.8, 1.25), Vector2(1.75, 1.25), Vector2(1.75, 1.6), Vector2(-3.8, 1.6)]), side * (hb + 0.008), side, ink)
	# The chassis, the tank, the box.
	for sx in [-0.45, 0.45]:
		_blk(pk, kit, "matte", Vector3(sx - 0.05, 0.55, -3.7), Vector3(sx + 0.05, 0.85, 2.1), TRIM_BLACK)
	pk.tube(kit, "metal", Vector3(-1.0, 0.72, -0.4), Vector3(-1.0, 0.72, 0.6), 0.22, 0.22, 10, Color(0.62, 0.63, 0.65), true)
	_blk(pk, kit, "gloss", Vector3(-hb, 0.95, -1.85), Vector3(hb, 3.6, 3.9), box_col)
	for px in [-hb, hb]:
		for pz in [-1.85, 3.9]:
			_blk(pk, kit, "metal", Vector3(px - 0.03, 0.93, pz - 0.03), Vector3(px + 0.03, 3.62, pz + 0.03), Color(0.75, 0.76, 0.77))
	_blk(pk, kit, "metal", Vector3(-hb - 0.02, 3.56, -1.87), Vector3(hb + 0.02, 3.62, 3.92), Color(0.75, 0.76, 0.77))
	_blk(pk, kit, "metal", Vector3(-hb - 0.02, 0.93, -1.87), Vector3(hb + 0.02, 1.0, 3.92), Color(0.55, 0.56, 0.57))
	# The rear: two doors with their bars, lamps, the underrun bar.
	_box(pk, kit, "matte", Vector3(0, 2.28, 3.912), Basis(), Vector3(0.02, 2.6, 0.012), TRIM_BLACK)
	for sx2 in [-0.35, 0.35]:
		_box(pk, kit, "metal", Vector3(sx2, 2.28, 3.92), Basis(), Vector3(0.05, 2.5, 0.03), Color(0.72, 0.73, 0.74))
		_box(pk, kit, "lamp", Vector3(sx2 * 2.9, 0.75, 3.75), Basis(), Vector3(0.3, 0.14, 0.05), TAIL_LAMP)
	_blk(pk, kit, "matte", Vector3(-1.1, 0.42, 3.72), Vector3(1.1, 0.54, 3.82), Color(0.35, 0.36, 0.37))
	for sx3 in [-0.8, 0.8]:
		_blk(pk, kit, "matte", Vector3(sx3 - 0.04, 0.5, 3.6), Vector3(sx3 + 0.04, 0.95, 3.72), TRIM_BLACK)
	# The front: lamps, the grille, the bumper, the plate.
	for sx4 in [-1.0, 1.0]:
		_box(pk, kit, "lamp", Vector3(sx4 * 0.82, 0.92, -3.93), Basis(), Vector3(0.34, 0.16, 0.05), HEAD_LAMP)
		_box(pk, kit, "lamp", Vector3(sx4 * 1.08, 0.92, -3.9), Basis(), Vector3(0.1, 0.12, 0.05), AMBER)
	_box(pk, kit, "matte", Vector3(0, 1.05, -3.935), Basis(), Vector3(1.1, 0.34, 0.03), TRIM_BLACK)
	_box(pk, kit, "matte", Vector3(0, 0.6, -3.94), Basis(), Vector3(2.3, 0.24, 0.1), Color(0.25, 0.25, 0.26))
	_plate(pk, kit, Vector3(0, 0.6, -4.0), Vector3(0, 0, -1), "KRB-LK 302")
	_plate(pk, kit, Vector3(0.5, 0.75, 3.84), Vector3(0, 0, 1), "KRB-LK 302")
	return Vector3(2.5, 3.62, 7.8)


## A 12m low-floor city bus (life 12.0 x 2.55 x 3.3m) in the Kronburger Stadtwerke's livery `variant` (KSW_LIVERIES): a
## band of windows with black pillars, doors on its right (+x), the destination displays, the roof's air conditioning,
## mirrors on their arms; returns its size.
static func city_bus(pk: PropKit, kit: Dictionary, variant := 0) -> Vector3:
	var lv: Array = KSW_LIVERIES[posmod(variant, KSW_LIVERIES.size())]
	var prim: Color = lv[0]
	var sec: Color = lv[1]
	var skirt: Color = lv[2]
	var roof: Color = lv[3]
	var hw := 1.275
	var axles: Array = [3.3, -2.6]
	var R := 0.56
	var cy := 0.36
	var ol := _profile(0.3, -6.0, 6.0, axles, R, cy, [Vector2(6.0, 0.38), Vector2(6.03, 0.95), Vector2(6.0, 1.05), Vector2(5.96, 2.7), Vector2(5.9, 2.95),
			Vector2(5.75, 3.08), Vector2(-5.8, 3.08), Vector2(-5.96, 2.95), Vector2(-6.0, 2.7), Vector2(-6.02, 0.38)])
	_side_extrude(pk, kit, "gloss", ol, -hw, hw, 0.09, prim, _body_fn(prim, 0.32, axles, R, cy, roof, 2.9))
	_edge_quad(pk, kit, "gloss", Vector2(6.0, 1.05), Vector2(5.96, 2.7), hw - 0.14, 0.012, 0.03, CAR_GLASS)
	_edge_quad(pk, kit, "gloss", Vector2(-6.0, 2.7), Vector2(-6.0, 1.75), hw - 0.2, 0.012, 0.02, CAR_GLASS)
	var doors: Array = [[4.25, 5.45], [0.1, 1.3], [-4.6, -3.45]]
	for side in [1.0, -1.0]:
		var x: float = side * (hw + 0.012)
		# The skirt and the band under the windows.
		_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(-5.9, 0.36), Vector2(5.9, 0.36), Vector2(5.9, 0.62), Vector2(-5.9, 0.62)]), side * (hw + 0.006), side, skirt)
		_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(-5.9, 0.88), Vector2(5.9, 0.88), Vector2(5.9, 1.06), Vector2(-5.9, 1.06)]), side * (hw + 0.006), side, sec)
		# The glass band and its pillars (a gap where the doors are on the right).
		_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(-5.72, 1.12), Vector2(5.78, 1.12), Vector2(5.78, 2.74), Vector2(-5.72, 2.74)]), x, side, CAR_GLASS)
		var np := 8
		for k in range(np + 1):
			var pf: float = lerpf(-5.72, 5.78, float(k) / float(np))
			_side_poly(pk, kit, "matte", PackedVector2Array([Vector2(pf - 0.06, 1.12), Vector2(pf + 0.06, 1.12), Vector2(pf + 0.06, 2.74), Vector2(pf - 0.06, 2.74)]),
					side * (hw + 0.022), side, TRIM_BLACK)
		_side_poly(pk, kit, "matte", PackedVector2Array([Vector2(-5.72, 2.16), Vector2(5.78, 2.16), Vector2(5.78, 2.2), Vector2(-5.72, 2.2)]), side * (hw + 0.02), side, TRIM_BLACK)
		if side > 0.0:
			for d in doors:
				var d0: float = d[0]
				var d1: float = d[1]
				_side_poly(pk, kit, "matte", PackedVector2Array([Vector2(d0, 0.34), Vector2(d1, 0.34), Vector2(d1, 2.78), Vector2(d0, 2.78)]), side * (hw + 0.026), side, TRIM_BLACK)
				for hf in [[d0 + 0.05, (d0 + d1) * 0.5 - 0.02], [(d0 + d1) * 0.5 + 0.02, d1 - 0.05]]:
					_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(hf[0], 0.42), Vector2(hf[1], 0.42), Vector2(hf[1], 2.7), Vector2(hf[0], 2.7)]), side * (hw + 0.034),
							side, CAR_GLASS.lightened(0.04))
		for ax in axles:
			_wheel(pk, kit, Vector3(side * (hw - 0.17), 0.48, -float(ax)), 0.48, 0.3, side, Color(0.70, 0.71, 0.72), 14, float(ax) < 0.0)
		# The mirror on its arm out front.
		var ma := Vector3(side * (hw - 0.05), 2.75, -5.86)
		var mb := Vector3(side * (hw + 0.17), 2.85, -6.22)
		pk.tube(kit, "matte", ma, mb, 0.03, 0.03, 6, TRIM_BLACK, true)
		_box(pk, kit, "matte", mb + Vector3(0, -0.28, 0), Basis(), Vector3(0.08, 0.5, 0.2), TRIM_BLACK)
		# The fleet number and the operator's name.
		_gtext(pk, kit, "matte", Vector3(side * (hw + 0.02), 0.75, -4.6), Vector3(0, 0, -side), UP, 0.04, "KSW", sec.darkened(0.2) if variant == 0 else TRIM_BLACK)
		_gtext(pk, kit, "matte", Vector3(side * (hw + 0.02), 0.75, 4.4), Vector3(0, 0, -side), UP, 0.03, "2%02d" % (14 + variant * 7), TRIM_BLACK)
	# The destination displays: over the windscreen and beside the front door.
	_box(pk, kit, "matte", Vector3(0, 2.86, -5.94), Basis(), Vector3(1.9, 0.3, 0.06), TRIM_BLACK)
	_led(pk, kit, Vector3(0, 2.86, -5.975), Vector3(0, 0, -1), 1.8, 0.24, AMBER, UP, 0.0)
	_led(pk, kit, Vector3(hw + 0.04, 2.5, -3.7), Vector3(1, 0, 0), 1.2, 0.2, AMBER, UP, 0.02)
	_led(pk, kit, Vector3(0, 2.78, 6.0), Vector3(0, 0, 1), 0.5, 0.24, AMBER, UP, 0.03)
	# The front: lamps, the bumper, the plate; the rear: the engine's grille, lamps.
	for sx in [-1.0, 1.0]:
		_box(pk, kit, "lamp", Vector3(sx * 0.92, 0.72, -6.03), Basis(), Vector3(0.4, 0.14, 0.04), HEAD_LAMP)
		_box(pk, kit, "lamp", Vector3(sx * 1.12, 0.82, -6.025), Basis(), Vector3(0.1, 0.1, 0.04), AMBER)
		_box(pk, kit, "lamp", Vector3(sx * 1.1, 1.4, 6.02), Basis(), Vector3(0.16, 0.9, 0.04), TAIL_LAMP)
	_box(pk, kit, "matte", Vector3(0, 0.45, -6.04), Basis(), Vector3(2.4, 0.18, 0.06), TRIM_BLACK)
	_box(pk, kit, "matte", Vector3(0, 0.95, 6.02), Basis(), Vector3(1.6, 0.6, 0.04), TRIM_BLACK)
	_plate(pk, kit, Vector3(0, 0.62, -6.08), Vector3(0, 0, -1), "KRB-SW 214")
	_plate(pk, kit, Vector3(0, 0.62, 6.05), Vector3(0, 0, 1), "KRB-SW 214")
	# The roof: the air conditioning and two hatches.
	_blk(pk, kit, "gloss", Vector3(-0.85, 3.06, -2.0), Vector3(0.85, 3.28, 1.2), roof)
	for k in range(4):
		_blk(pk, kit, "matte", Vector3(-0.75, 3.28, -1.85 + 0.75 * float(k)), Vector3(0.75, 3.29, -1.45 + 0.75 * float(k)), TRIM_BLACK)
	for hz in [-4.0, 3.6]:
		_blk(pk, kit, "matte", Vector3(-0.4, 3.07, hz - 0.4), Vector3(0.4, 3.13, hz + 0.4), TRIM_BLACK.lightened(0.1))
	return Vector3(2.55, 3.29, 12.0)


# ----- The tram -------------------------------------------------------------------------

const TRAM_LEN := 30.0
const TRAM_HW := 1.15
const TRAM_ROOF := 3.38
## The pantograph's head: its top touches the contact wire 6.0m over the rail (the Ring's catenary).
const TRAM_PAN_TOP := 5.975
## The modules along f (forward, the cab "A" toward -z): [f0, f1, kind] (kind: cab_a, cab_b, mid).
const TRAM_MODULES := [[9.9, 15.0, "cab_a"], [3.25, 9.55, "mid"], [-2.9, 2.9, "mid"], [-9.55, -3.25, "mid"], [-15.0, -9.9, "cab_b"]]

## A cab module's outline (forward, up) from its back at f0 to the nose at f1 (mirrored for cab B).
static func _tram_cab(f0: float, f1: float, mirror: bool) -> PackedVector2Array:
	var pts: Array = [Vector2(f0, 0.32), Vector2(f1 - 0.4, 0.32), Vector2(f1 - 0.08, 0.42), Vector2(f1, 0.75), Vector2(f1 - 0.02, 1.05), Vector2(f1 - 0.45, 2.6),
			Vector2(f1 - 0.7, 3.1), Vector2(f1 - 1.1, 3.36), Vector2(f0, TRAM_ROOF)]
	var out := PackedVector2Array()
	if not mirror:
		for p in pts:
			out.append(p)
	else:
		for i in range(pts.size() - 1, -1, -1):
			var p2: Vector2 = pts[i]
			out.append(Vector2(-p2.x, p2.y))
	return out


## A low-floor articulated tram of five modules (life TRAM_LEN 30.0 x 2.30m, the roof at 3.38, the pantograph raised to
## TRAM_PAN_TOP), y = 0 the rail top, cabs at both ends (the front toward -z), centred; in the Kronburger Stadtwerke's
## livery `variant` (KSW_LIVERIES): windows with black pillars, double doors on both sides, the bellows between the
## modules, three bogies, the destination displays, air conditioning on the roof and the pantograph on the middle module.
## Returns its size.
static func tram(pk: PropKit, kit: Dictionary, variant := 0) -> Vector3:
	var lv: Array = KSW_LIVERIES[posmod(variant, KSW_LIVERIES.size())]
	var prim: Color = lv[0]
	var sec: Color = lv[1]
	var skirt: Color = lv[2]
	var roof: Color = lv[3]
	var hw := TRAM_HW
	var fn := _body_fn(prim, 0.0, [], 0.0, 0.0, roof, 3.0)
	for m in TRAM_MODULES:
		var f0: float = m[0]
		var f1: float = m[1]
		var kind: String = m[2]
		var ol: PackedVector2Array
		if kind == "cab_a":
			ol = _tram_cab(f0, f1, false)
		elif kind == "cab_b":
			ol = _tram_cab(-f1, -f0, true)
		else:
			ol = PackedVector2Array([Vector2(f0, 0.32), Vector2(f1, 0.32), Vector2(f1, 3.3), Vector2(f1 - 0.08, TRAM_ROOF), Vector2(f0 + 0.08, TRAM_ROOF), Vector2(f0, 3.3)])
		_side_extrude(pk, kit, "gloss", ol, -hw, hw, 0.1, prim, fn)
		# Along each side: the skirt, the band under the windows, the glass band with its pillars, the doors.
		var g0: float = f0 + 0.25
		var g1: float = f1 - 0.25
		if kind == "cab_a":
			g1 = f1 - 1.1
		elif kind == "cab_b":
			g0 = f0 + 1.1
		var doors: Array = []
		if kind == "mid" and absf(f0 + f1) > 1.0:
			doors.append([(f0 + f1) * 0.5 - 0.68, (f0 + f1) * 0.5 + 0.68])
		elif kind == "cab_a":
			doors.append([f0 + 0.6, f0 + 1.9])
		elif kind == "cab_b":
			doors.append([f1 - 1.9, f1 - 0.6])
		for side in [1.0, -1.0]:
			var x6: float = side * (hw + 0.006)
			_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(f0 + 0.12, 0.34), Vector2(f1 - 0.12, 0.34), Vector2(f1 - 0.12, 0.68), Vector2(f0 + 0.12, 0.68)]), x6, side, skirt)
			_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(f0 + 0.12, 0.92), Vector2(f1 - 0.12, 0.92), Vector2(f1 - 0.12, 1.08), Vector2(f0 + 0.12, 1.08)]), x6, side, sec)
			_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(g0, 1.14), Vector2(g1, 1.14), Vector2(g1, 2.72), Vector2(g0, 2.72)]), side * (hw + 0.014), side, CAR_GLASS)
			var np: int = maxi(1, int(round((g1 - g0) / 1.6)))
			for k in range(np + 1):
				var pf: float = lerpf(g0, g1, float(k) / float(np))
				_side_poly(pk, kit, "matte", PackedVector2Array([Vector2(pf - 0.05, 1.14), Vector2(pf + 0.05, 1.14), Vector2(pf + 0.05, 2.72), Vector2(pf - 0.05, 2.72)]),
						side * (hw + 0.022), side, TRIM_BLACK)
			for d in doors:
				var d0: float = d[0]
				var d1: float = d[1]
				_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(d0 - 0.06, 0.34), Vector2(d1 + 0.06, 0.34), Vector2(d1 + 0.06, 2.62), Vector2(d0 - 0.06, 2.62)]),
						side * (hw + 0.026), side, sec.darkened(0.15))
				for hf in [[d0, (d0 + d1) * 0.5 - 0.015], [(d0 + d1) * 0.5 + 0.015, d1]]:
					_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(hf[0] + 0.05, 0.42), Vector2(hf[1] - 0.05, 0.42), Vector2(hf[1] - 0.05, 2.5), Vector2(hf[0] + 0.05, 2.5)]),
							side * (hw + 0.034), side, CAR_GLASS.lightened(0.05))
			if kind != "mid":
				# The cab's side window and the fleet number under it.
				var cf: float = f1 - 0.85 if kind == "cab_a" else f0 + 0.85
				_side_poly(pk, kit, "gloss", PackedVector2Array([Vector2(cf - 0.4, 1.3), Vector2(cf + 0.4, 1.3), Vector2(cf + 0.3, 2.55), Vector2(cf - 0.4, 2.55)]),
						side * (hw - 0.02), side, CAR_GLASS)
				_gtext(pk, kit, "matte", Vector3(side * (hw + 0.012), 0.81, -cf), Vector3(0, 0, -side), UP, 0.035, "4%02d" % (12 + variant * 6), TRIM_BLACK)
			elif absf(f0 + f1) < 1.0:
				_gtext(pk, kit, "matte", Vector3(side * (hw + 0.012), 0.81, 0.0), Vector3(0, 0, -side), UP, 0.05, "KSW", sec)
		# Air conditioning on the module's roof (not the pantograph's).
		if absf(f0 + f1) > 1.0:
			var ac: float = (f0 + f1) * 0.5
			_blk(pk, kit, "gloss", Vector3(-0.8, TRAM_ROOF - 0.02, -(ac + 1.3)), Vector3(0.8, TRAM_ROOF + 0.32, -(ac - 1.3)), roof.lightened(0.05))
			for k in range(3):
				_blk(pk, kit, "matte", Vector3(-0.65, TRAM_ROOF + 0.32, -(ac - 0.95 + 0.7 * float(k)) - 0.2), Vector3(0.65, TRAM_ROOF + 0.33, -(ac - 0.95 + 0.7 * float(k)) + 0.2),
						TRIM_BLACK)
	# The bellows between the modules.
	for j in [[9.55, 9.9], [2.9, 3.25], [-3.25, -2.9], [-9.9, -9.55]]:
		var ja: float = j[0]
		var jb: float = j[1]
		_blk(pk, kit, "matte", Vector3(-hw + 0.08, 0.4, -jb - 0.04), Vector3(hw - 0.08, TRAM_ROOF - 0.06, -ja + 0.04), TRIM_BLACK)
		for k in range(4):
			var jz: float = -lerpf(ja, jb, (float(k) + 0.5) / 4.0)
			_blk(pk, kit, "matte", Vector3(-hw + 0.05, 0.42, jz - 0.02), Vector3(hw - 0.05, TRAM_ROOF - 0.08, jz + 0.02), Color(0.13, 0.13, 0.14))
	# The bogies: a frame and two axles of wheels on the rails under each cab and the middle module.
	for bf in [12.2, 0.0, -12.2]:
		_blk(pk, kit, "matte", Vector3(-0.95, 0.22, -bf - 1.0), Vector3(0.95, 0.5, -bf + 1.0), Color(0.12, 0.12, 0.13))
		for af in [-0.9, 0.9]:
			for sx in [-1.0, 1.0]:
				pk.tyre(kit, "metal", Vector3(sx * 0.72, 0.32, -bf - af), 0.12, 0.32, 0.12, 12, Color(0.42, 0.42, 0.43), Basis(Vector3.BACK, PI * 0.5))
	# The ends: windscreens, destination displays, lamps, the coupler covers.
	for e in [1.0, -1.0]:
		var nose: float = TRAM_LEN * 0.5
		var a := Vector2(nose - 0.02, 1.05)
		var b := Vector2(nose - 0.45, 2.6)
		var a3 := Vector3(0, a.y, -e * a.x)
		var b3 := Vector3(0, b.y, -e * b.x)
		var up3: Vector3 = (b3 - a3).normalized()
		var n3: Vector3 = Vector3(0, 0, -e).cross(Vector3(1, 0, 0)).cross(up3) if false else (Vector3(1, 0, 0).cross(up3) * e).normalized()
		if n3.z * -e < 0.0:
			n3 = -n3
		var gw: float = hw - 0.16
		var gq: Array = [a3 + n3 * 0.012 - Vector3(gw, 0, 0), a3 + n3 * 0.012 + Vector3(gw, 0, 0), b3.lerp(a3, 0.16) + n3 * 0.012 + Vector3(gw, 0, 0),
				b3.lerp(a3, 0.16) + n3 * 0.012 - Vector3(gw, 0, 0)]
		pk.quad(kit, "gloss", gq, n3, CAR_GLASS)
		var dcen: Vector3 = b3.lerp(a3, 0.08) + n3 * 0.025
		_led(pk, kit, dcen, n3, 1.7, 0.24, AMBER, up3, 0.0)
		for sx in [-1.0, 1.0]:
			_box(pk, kit, "lamp", Vector3(sx * 0.78, 0.82, -e * (nose + 0.005)), Basis(), Vector3(0.28, 0.12, 0.04), HEAD_LAMP)
			_box(pk, kit, "lamp", Vector3(sx * 0.78, 0.66, -e * (nose - 0.04)), Basis(), Vector3(0.16, 0.08, 0.06), TAIL_LAMP)
		_box(pk, kit, "matte", Vector3(0, 0.55, -e * (nose - 0.02)), Basis(), Vector3(1.1, 0.3, 0.08), TRIM_BLACK)
	# The pantograph on the middle module: a base on insulators, the lower arm, the knee, the upper arm, the head.
	var base_y: float = TRAM_ROOF + 0.12
	_blk(pk, kit, "metal", Vector3(-0.55, TRAM_ROOF - 0.02, -0.7), Vector3(0.55, TRAM_ROOF + 0.06, 0.7), Color(0.32, 0.33, 0.34))
	for ix in [-0.4, 0.4]:
		for iz in [-0.55, 0.55]:
			pk.tube(kit, "plastic", Vector3(ix, TRAM_ROOF + 0.06, iz), Vector3(ix, base_y, iz), 0.05, 0.05, 8, Color(0.82, 0.30, 0.18), true)
	_blk(pk, kit, "metal", Vector3(-0.5, base_y, -0.62), Vector3(0.5, base_y + 0.08, 0.62), Color(0.40, 0.41, 0.42))
	var hinge := Vector3(0, base_y + 0.12, -0.45)
	var knee := Vector3(0, 4.82, 0.62)
	var head := Vector3(0, TRAM_PAN_TOP - 0.06, -0.12)
	for sx in [-0.12, 0.12]:
		pk.tube(kit, "metal", hinge + Vector3(sx, 0, 0), knee + Vector3(sx * 0.5, 0, 0), 0.035, 0.03, 6, Color(0.55, 0.56, 0.57), true)
	pk.tube(kit, "metal", knee, head, 0.025, 0.022, 6, Color(0.55, 0.56, 0.57), true)
	pk.tube(kit, "metal", hinge + Vector3(0, 0.05, 0.1), knee + Vector3(0, -0.08, -0.1), 0.012, 0.012, 4, Color(0.5, 0.5, 0.5), false)
	_box(pk, kit, "metal", hinge, Basis(), Vector3(0.36, 0.1, 0.14), Color(0.40, 0.41, 0.42))
	# The head: a bar across with its carbon strip on top and horns curling down at the ends.
	_blk(pk, kit, "metal", Vector3(-0.62, TRAM_PAN_TOP - 0.07, -0.18), Vector3(0.62, TRAM_PAN_TOP - 0.03, -0.06), Color(0.55, 0.56, 0.57))
	_blk(pk, kit, "matte", Vector3(-0.6, TRAM_PAN_TOP - 0.03, -0.16), Vector3(0.6, TRAM_PAN_TOP, -0.08), Color(0.08, 0.08, 0.08))
	for sx2 in [-1.0, 1.0]:
		var hp: Array = [Vector3(sx2 * 0.6, TRAM_PAN_TOP - 0.05, -0.12), Vector3(sx2 * 0.74, TRAM_PAN_TOP - 0.07, -0.12), Vector3(sx2 * 0.84, TRAM_PAN_TOP - 0.15, -0.12),
				Vector3(sx2 * 0.88, TRAM_PAN_TOP - 0.27, -0.12)]
		KT._tube_path(pk, kit, "metal", hp, 0.016, 5, Color(0.55, 0.56, 0.57))
	return Vector3(hw * 2.0, TRAM_PAN_TOP, TRAM_LEN)


# ======================================================================================
#  Kronburg Hbf
# ======================================================================================

const HBF_HX := 62.0             # the street front from x -62 to 62
## The elevated block's ends: the generator cuts its walled embankment at STATION_X +- 64 * PROP_SCALE, so it butts on here.
const BLOCK_HX := 64.0
const HBF_D := 28.0              # the building's depth: its back wall at z = -28
## The rail top under the sheds: the generator's line at the station (its rail top 47.0 over the station's foot at
## CITY_Y - GROUND_UNDER = 33.93, game metres), so the rails it lays through the station sit on the trackbed.
const PLATFORM_Y := (47.0 - 33.93) / 1.6
## The trackbed (the block's top): the generator's EMBANK_UNDER (0.95 game metres) under the rail top, where its ballast lies.
const BED_Y := PLATFORM_Y - 0.95 / 1.6
const PLATFORM_TOP := PLATFORM_Y + 0.55
const BLOCK_Z1 := -100.0         # the embankment block's back face
## The train sheds' column rows (the house platform, the two islands' middles, the back platform): three arched halls.
const SHED_ROWS := [-30.0, -52.975, -72.025, -95.0]
const SHED_SPRING := PLATFORM_TOP + 6.5    # the arches' springing (the columns' tops)
const SHED_RISE := 7.0                     # the arches' rise
const SHED_FRAMES := 9                     # arched trusses along x, -62..62 (15.5m apart)
const SHED_APRON := PLATFORM_TOP + 5.15    # the glazed end screens' lower edge, clear over the trains
## The tracks' centres (z), Gleis 1 to 4, their rail tops at PLATFORM_Y. Gleis 2 and 3 are the line's own: the generator
## lays them RAIL_TRACK_OFF (3.0 game metres) either side of RAIL_Z and puts their middle (TRACKS_Z[1] + [2]) / 2 on
## RAIL_Z. Gleis 1 and 4 are the station's own stub tracks (rails, sleepers, ballast and buffer stops here).
const TRACKS_Z := [-45.325, -60.625, -64.375, -79.675]
## The platforms: [front z, back z]: the house platform (Gleis 1), island A (Gleis 1 | 2), island B (Gleis 3 | 4), the back
## platform (Gleis 4). Their edges stand PLATFORM_EDGE from the tracks' centres.
const PLATFORMS := [[-28.0, -43.675], [-46.975, -58.975], [-66.025, -78.025], [-81.325, -99.5]]
const PLATFORM_EDGE := 1.65
const TOWER_X := 40.0
const TOWER_TOP := 42.6
const HB_PL := 0.8
const HB_GF := 6.0
const HB_EAVE := 14.6
const HB_CORNICE := 15.5
const HB_BREAK := 18.3
const HB_CB := 14.0              # the entrance hall's half width
const HB_CB_Z := 1.2             # its front
const HB_CB_CORNICE := 23.0
const HB_CB_ATTIC := 25.6
const HB_TW := 4.0
const HB_TZ0 := 0.5
const HB_TZ1 := -7.5
const HB_TOWER_SHAFT := 31.2
const HB_PAV := 54.0             # the corner pavilions from |x| 54 to 62
const HB_PAV_Z := 0.8
const HB_PAV_Z1 := -8.0
const HB_PAV_TOP := 19.2
const HB_FRAME := Color(0.26, 0.20, 0.15)
const HB_DOOR := Color(0.30, 0.17, 0.10)


## Kronburg Hbf (Neo-Renaissance, 1908): the street front along x from -62 to 62 facing +z, the building to z -28. The
## entrance hall (x +-14, front at z 1.2): three portals under a great arched window, giant pilasters, KRONBURG HBF on its
## attic, a segmental gable with a winged wheel, a copper barrel roof. The wings: three storeys of sandstone (arched
## windows on the rusticated ground floor, pedimented windows above), a cornice at 14.6-15.5 and a slate mansard (ridge
## 20.2); corner pavilions (|x| 54-62, front z 0.8) with an attic storey and a slate pavilion roof to 25.6; the clock
## tower at x = TOWER_X (36..44, front z 0.5) with four dials at 28 and a copper helm and lantern to TOWER_TOP; the taxi
## canopy (x -32..-10, z 0..8, glass on steel posts, its eaves 5.4). Behind it, the station's elevated part over the
## whole x range: a brick block with blind arches (z -28..-100; its top BED_Y between the platforms), the four
## platforms (PLATFORMS, top PLATFORM_TOP: stairwells, benches, name boards, clocks, displays), the tracks' centres
## TRACKS_Z (rail top PLATFORM_Y, for the caller's rails), and three arched iron-and-glass train sheds on cast-iron
## columns over SHED_ROWS (z -30..-95, crowns 21.55, ridge lanterns to 23.3) with glazed end screens down to SHED_APRON.
## The block's end walls (x = +-62) stop at BED_Y + 0.15 where the tracks leave.
static func hauptbahnhof(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	_hb_wings(pk, kit)
	_hb_central(pk, kit, labels)
	_hb_tower(pk, kit)
	_hb_pavilions(pk, kit)
	_hb_roof(pk, kit)
	_hb_canopy(pk, kit, labels)
	_hb_block(pk, kit, labels)
	_hb_platforms(pk, kit, labels)
	_hb_sheds(pk, kit)
	_hb_rails(pk, kit)


## Collision boxes for the station (life, in its frame): the building, the entrance hall's front and steps, the tower,
## the pavilions' fronts, the taxi canopy's posts and roof, the embankment block, the platforms and the back parapet.
static func hauptbahnhof_solids() -> Array:
	var out: Array = []
	out.append([Transform3D(Basis(), Vector3(0, 9.0, -14.0)), Vector3(HBF_HX * 2.0, 21.0, HBF_D)])
	out.append([Transform3D(Basis(), Vector3(0, 11.5, 0.6)), Vector3(HB_CB * 2.0, 26.0, 1.2)])
	out.append([Transform3D(Basis(), Vector3(0, 0.075, 1.55)), Vector3(20.0, 0.15, 0.7)])
	out.append([Transform3D(Basis(), Vector3(TOWER_X, 15.0, (HB_TZ0 + HB_TZ1) * 0.5)), Vector3(HB_TW * 2.0, 33.0, HB_TZ0 - HB_TZ1)])
	for s in [-1.0, 1.0]:
		out.append([Transform3D(Basis(), Vector3(s * (HB_PAV + HBF_HX) * 0.5, 9.0, HB_PAV_Z * 0.5)), Vector3(HBF_HX - HB_PAV, 21.0, HB_PAV_Z)])
	for px in [-31.6, -26.15, -20.7, -15.25, -10.4]:
		out.append([Transform3D(Basis(), Vector3(px, 2.45, 7.6)), Vector3(0.36, 4.9, 0.36)])
	out.append([Transform3D(Basis(), Vector3(-21.0, 5.8, 3.9)), Vector3(22.0, 0.9, 7.9)])
	out.append([Transform3D(Basis(), Vector3(0, (BED_Y - 1.5) * 0.5, (-HBF_D + BLOCK_Z1) * 0.5)), Vector3(BLOCK_HX * 2.0, BED_Y + 1.5, -HBF_D - BLOCK_Z1)])
	for p in PLATFORMS:
		var z0: float = p[0]
		var z1: float = p[1]
		out.append([Transform3D(Basis(), Vector3(0, (BED_Y + PLATFORM_TOP) * 0.5, (z0 + z1) * 0.5)), Vector3(HBF_HX * 2.0, PLATFORM_TOP - BED_Y, z0 - z1)])
	out.append([Transform3D(Basis(), Vector3(0, PLATFORM_TOP + 0.625, -99.75)), Vector3(BLOCK_HX * 2.0, 1.25, 0.5)])
	return out


## A window's sandstone surround in a wall frame: jambs and a lintel 18cm wide standing 6cm proud, a sill, and the hood:
## "tri" or "seg" (a cornice and a pediment), "flat" (a cornice), "key" (a keystone), "none".
static func _hb_surround(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, ww: float, hood: String) -> void:
	var x0: float = u - ww * 0.5
	var x1: float = u + ww * 0.5
	var f := 0.18
	var c: Color = SAND_LIGHT
	_rect(pk, kit, "ashlar", wf, x0 - f, v0, x0 - 0.01, v1, 0.0, 0.06, c)
	_rect(pk, kit, "ashlar", wf, x1 + 0.01, v0, x1 + f, v1, 0.0, 0.06, c)
	var ht: float = v1 + f
	_rect(pk, kit, "ashlar", wf, x0 - f, v1 + 0.01, x1 + f, ht, 0.0, 0.06, c)
	_rect(pk, kit, "ashlar", wf, x0 - 0.28, v0 - 0.16, x1 + 0.28, v0 - 0.01, 0.0, 0.16, c)
	match hood:
		"key":
			KT._prism(pk, kit, "ashlar", wf, PackedVector2Array([Vector2(u - 0.12, v1 - 0.05), Vector2(u + 0.12, v1 - 0.05), Vector2(u + 0.17, ht + 0.12),
					Vector2(u - 0.17, ht + 0.12)]), 0.0, 0.1, c.lightened(0.04))
		"tri", "seg", "flat":
			RS._mould(pk, kit, "ashlar", wf, x0 - f - 0.16, x1 + f + 0.16, PackedVector2Array([Vector2(0.0, ht), Vector2(0.1, ht), Vector2(0.18, ht + 0.1),
					Vector2(0.2, ht + 0.22), Vector2(0.0, ht + 0.22)]), c)
			var base: float = ht + 0.22
			var half2: float = ww * 0.5 + f + 0.12
			if hood == "tri":
				KT._prism(pk, kit, "ashlar", wf, PackedVector2Array([Vector2(u - half2, base), Vector2(u + half2, base), Vector2(u, base + half2 * 0.4)]), 0.0, 0.16, c)
			elif hood == "seg":
				KT._prism(pk, kit, "ashlar", wf, KT._arch(u, base, half2, "segment", 8, half2 * 0.3), 0.0, 0.16, c)


## A window with its surround (the glazing from RheinStadtKit: a pane 2cm proud in a painted frame with a transom).
static func _hb_window(pk: PropKit, kit: Dictionary, wf: Transform3D, u: float, v0: float, v1: float, ww: float, hood: String) -> void:
	RS._gz_window(pk, kit, wf, u, v0, v1, ww, HB_FRAME)
	_hb_surround(pk, kit, wf, u, v0, v1, ww, hood)


## A storeyed sandstone facade in a wall frame from u0 to u1: the plinth, the rusticated ground floor (to HB_GF, unless
## v_lo is over it: the back above the platform), the upper storeys to `top`, the string course, the main cornice to
## top + 0.9; windows on `axes` ([u, ground kind: "win", "door", "none"]): arched ones below, pedimented on the first floor
## (alternating), straight-hooded on the second; on the back, glazed doors to the platform and windows over them.
static func _hb_facade(pk: PropKit, kit: Dictionary, wf: Transform3D, u0: float, u1: float, axes: Array, v_lo := 0.0, top := HB_EAVE, cornice := true) -> void:
	if v_lo < HB_GF:
		_rect(pk, kit, "ashlar", wf, u0, -1.5, u1, HB_PL, 0.0, 0.08, SAND_DARK)
		_face(pk, kit, "ashlar", wf, u0, HB_PL, u1, HB_GF, 0.0, SAND_DARK.lightened(0.06))
		_face(pk, kit, "ashlar", wf, u0, HB_GF, u1, top, 0.0, SAND)
		RS._mould(pk, kit, "ashlar", wf, u0, u1, PackedVector2Array([Vector2(0.0, HB_GF - 0.3), Vector2(0.12, HB_GF - 0.3), Vector2(0.15, HB_GF - 0.2),
				Vector2(0.24, HB_GF - 0.05), Vector2(0.24, HB_GF + 0.12), Vector2(0.0, HB_GF + 0.12)]), SAND_LIGHT)
	else:
		_face(pk, kit, "ashlar", wf, u0, v_lo, u1, top, 0.0, SAND)
	if cornice:
		_rect(pk, kit, "ashlar", wf, u0, top - 0.75, u1, top - 0.35, 0.0, 0.03, SAND_LIGHT)
		RS._mould(pk, kit, "ashlar", wf, u0 - 0.02, u1 + 0.02, PackedVector2Array([Vector2(0.0, top - 0.35), Vector2(0.1, top - 0.35), Vector2(0.1, top - 0.2),
				Vector2(0.58, top - 0.12), Vector2(0.62, top + 0.05), Vector2(0.72, top + 0.15), Vector2(0.74, top + 0.5), Vector2(0.66, top + 0.62),
				Vector2(0.66, top + 0.9), Vector2(0.0, top + 0.9)]), SAND_LIGHT)
	var i := 0
	for ax in axes:
		var u: float = ax[0]
		var kind: String = ax[1]
		if v_lo < HB_GF:
			if kind == "win":
				RS._gz_arched_window(pk, kit, wf, u, 1.45, 5.3, 1.9, HB_FRAME, SAND_LIGHT)
			elif kind == "door":
				RS._gz_arched_window(pk, kit, wf, u, HB_PL + 0.06, 5.4, 2.2, HB_DOOR, SAND_LIGHT)
			_hb_window(pk, kit, wf, u, 7.3, 9.8, 1.6, "tri" if i % 2 == 0 else "seg")
			_hb_window(pk, kit, wf, u, 11.4, 13.4, 1.5, "flat")
		else:
			if kind == "door":
				RS._gz_balcony_door(pk, kit, wf, u, v_lo + 0.02, v_lo + 2.5, 1.8, {"frame": HB_DOOR})
				_hb_surround(pk, kit, wf, u, v_lo + 0.02, v_lo + 2.5, 1.8, "flat")
			else:
				_hb_window(pk, kit, wf, u, v_lo + 1.0, v_lo + 2.5, 1.6, "key")
			RS._gz_window(pk, kit, wf, u, v_lo + 3.3, top - 1.2, 1.5, HB_FRAME)
		i += 1


static func _hb_axes(from: float, to: float, step: float, doors: Array) -> Array:
	var out: Array = []
	var u: float = from
	while (step > 0.0 and u <= to + 0.01) or (step < 0.0 and u >= to - 0.01):
		var k := "win"
		for d in doors:
			if absf(float(d) - u) < 0.01:
				k = "door"
		out.append([u, k])
		u += step
	return out


static func _hb_wings(pk: PropKit, kit: Dictionary) -> void:
	var front := _wf(Vector3.ZERO, Vector3(0, 0, 1))
	_hb_facade(pk, kit, front, -HB_PAV, -HB_CB, _hb_axes(-52.0, -16.0, 4.0, [-48.0, -20.0]))
	_hb_facade(pk, kit, front, HB_CB, TOWER_X - HB_TW, _hb_axes(16.0, 32.0, 4.0, [20.0]))
	_hb_facade(pk, kit, front, TOWER_X + HB_TW, HB_PAV, _hb_axes(48.0, 52.0, 4.0, [48.0]))
	# The ends (x = +-62) from the pavilion's front back to z -28, and the back over the house platform.
	for s in [-1.0, 1.0]:
		var ef := _wf(Vector3(s * HBF_HX, 0, HB_PAV_Z if s > 0.0 else -HBF_D), Vector3(s, 0, 0))
		# u runs along -z on the +x end, +z on the -x end.
		var axes: Array = []
		for k in range(7):
			axes.append([2.8 + 4.0 * float(k), "win" if k != 3 else "door"])
		_hb_facade(pk, kit, ef, 0.0, HBF_D + HB_PAV_Z, axes)
		# The back faces -z: u runs along -x, so from x = +14 (s > 0) or x = -14... both runs start at their +x end.
		var bx0: float = HBF_HX if s > 0.0 else -HB_CB
		var bfr := _wf(Vector3(bx0, 0, -HBF_D), Vector3(0, 0, -1))
		var baxes: Array = []
		for k in range(12):
			baxes.append([2.0 + 4.0 * float(k), "door" if k % 3 == 1 else "win"])
		_hb_facade(pk, kit, bfr, 0.0, HBF_HX - HB_CB, baxes, PLATFORM_TOP)
	# The returns where the tower stands out of the front.
	for x in [TOWER_X - HB_TW, TOWER_X + HB_TW]:
		var sx: float = -1.0 if x < TOWER_X else 1.0
		var rf := _wf(Vector3(x, 0, HB_TZ0 if sx > 0.0 else 0.0), Vector3(sx, 0, 0))
		_face(pk, kit, "ashlar", rf, 0.0, -1.5, HB_TZ0, HB_EAVE, 0.0, SAND)


## The entrance hall: its front with the portals and the great window, the giant pilasters, cornice, attic and gable, the
## sides and the back (a second great window over the platforms), the barrel roof.
static func _hb_central(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var p0 := Vector3(0, 0, HB_CB_Z)
	var along := Vector3.RIGHT
	var out := Vector3(0, 0, 1)
	var holes: Array = []
	var portals: Array = [-6.5, 0.0, 6.5]
	for cu in portals:
		holes.append(ZK._arch_hole(cu, 0.15, 2.1, 4.2, 2.1))
	holes.append(ZK._arch_hole(0.0, 7.4, 7.8, 6.8, 7.8))
	ZK._wall(pk, kit, "ashlar", p0, along, out, -HB_CB, HB_CB, HB_PL, HB_CB_CORNICE, holes, SAND, 1.0)
	_rect(pk, kit, "ashlar", _wf(p0, out), -HB_CB, -1.5, HB_CB, HB_PL, 0.0, 0.01, SAND_DARK)
	for cu in portals:
		ZK._arch_open(pk, kit, "ashlar", p0, along, out, cu, 0.15, 2.1, 4.2, 2.1, 1.0, SAND,
				{"trim": "ashlar", "trim_col": SAND_LIGHT, "trim_w": 0.45, "keystone": true, "door": HB_DOOR, "sill": false, "segs": 10, "trim_foot": true})
	ZK._arch_open(pk, kit, "ashlar", p0, along, out, 0.0, 7.4, 7.8, 6.8, 7.8, 1.0, SAND,
			{"trim": "ashlar", "trim_col": SAND_LIGHT, "trim_w": 0.6, "keystone": true, "glass": true, "segs": 16, "sill": true, "sill_col": SAND_LIGHT})
	var wfg := _wf(p0, out)
	var arc: PackedVector2Array = KT._arch(0.0, 14.2, 7.8, "round", 16)
	for k in range(-3, 4):
		var u: float = float(k) * 2.0
		var hy: float = KT._arch_height(arc, u) if absf(u) < 7.8 else 14.2
		_box(pk, kit, "steel", wfg * Vector3(u, (7.4 + hy) * 0.5, -0.1), Basis(along, UP, out), Vector3(0.14, hy - 7.4, 0.1), STEEL_DARK)
	for ty in [9.8, 12.0]:
		_box(pk, kit, "steel", wfg * Vector3(0, ty, -0.1), Basis(along, UP, out), Vector3(15.6, 0.12, 0.1), STEEL_DARK)
	# A step across the portals, giant pilasters with capitals, slender windows between them.
	_blk(pk, kit, "ashlar", Vector3(-10.0, -0.3, HB_CB_Z), Vector3(10.0, 0.15, HB_CB_Z + 0.7), SAND_DARK)
	for s in [-1.0, 1.0]:
		for pu in [10.2, 13.2]:
			_rect(pk, kit, "ashlar", wfg, s * pu - 0.6, HB_PL, s * pu + 0.6, HB_CB_CORNICE - 0.9, 0.0, 0.22, SAND_LIGHT)
			_rect(pk, kit, "ashlar", wfg, s * pu - 0.75, HB_CB_CORNICE - 0.9, s * pu + 0.75, HB_CB_CORNICE - 0.4, 0.0, 0.34, SAND_LIGHT.lightened(0.04))
			_rect(pk, kit, "ashlar", wfg, s * pu - 0.72, HB_PL, s * pu + 0.72, HB_PL + 0.5, 0.0, 0.3, SAND_DARK)
		RS._gz_arched_window(pk, kit, wfg, s * 11.7, 8.6, 13.2, 1.0, HB_FRAME, SAND_LIGHT)
		RS._gz_arched_window(pk, kit, wfg, s * 11.7, 1.6, 5.4, 1.0, HB_FRAME, SAND_LIGHT)
	# The cornice round the hall, the attic with the name, the segmental gable with its winged wheel.
	for f in [[Vector3(-HB_CB, 0, HB_CB_Z), Vector3(0, 0, 1), HB_CB * 2.0], [Vector3(HB_CB, 0, -HBF_D), Vector3(0, 0, -1), HB_CB * 2.0],
			[Vector3(HB_CB, 0, HB_CB_Z), Vector3(1, 0, 0), HBF_D + HB_CB_Z], [Vector3(-HB_CB, 0, -HBF_D), Vector3(-1, 0, 0), HBF_D + HB_CB_Z]]:
		var wf := _wf(f[0], f[1])
		var ln: float = f[2]
		RS._mould(pk, kit, "ashlar", wf, -0.05, ln + 0.05, PackedVector2Array([Vector2(0.0, HB_CB_CORNICE), Vector2(0.12, HB_CB_CORNICE),
				Vector2(0.62, HB_CB_CORNICE + 0.2), Vector2(0.74, HB_CB_CORNICE + 0.55), Vector2(0.66, HB_CB_CORNICE + 0.7),
				Vector2(0.66, HB_CB_CORNICE + 1.0), Vector2(0.0, HB_CB_CORNICE + 1.0)]), SAND_LIGHT)
		KT._prism(pk, kit, "ashlar", wf, KT._rp(0.0, HB_CB_CORNICE + 1.0, ln, HB_CB_ATTIC), -0.5, 0.0, SAND, Vector2(0, 1), true, true)
		KT._prism(pk, kit, "ashlar", wf, KT._rp(-0.05, HB_CB_ATTIC, ln + 0.05, HB_CB_ATTIC + 0.25), -0.6, 0.12, SAND_LIGHT, Vector2(0, 1), true)
	_lbl(labels, "KRONBURG HBF", Vector3(0, (HB_CB_CORNICE + 1.0 + HB_CB_ATTIC) * 0.5 + 0.05, HB_CB_Z + 0.03), out, 0.72, GOLD, 22.0)
	for gz in [[HB_CB_Z, 1.0], [-HBF_D, -1.0]]:
		var gwf := _wf(Vector3(0, 0, float(gz[0])), Vector3(0, 0, float(gz[1])))
		var gable: PackedVector2Array = KT._arch(0.0, HB_CB_ATTIC + 0.25, 13.6, "segment", 16, 3.6)
		KT._prism(pk, kit, "ashlar", gwf, gable, -0.8, 0.0, SAND, Vector2(0, 1), true, true)
		KT._arch_ring(pk, kit, "ashlar", gwf, 0.0, HB_CB_ATTIC + 0.25, 13.35, "segment", 0.3, -0.85, 0.1, SAND_LIGHT, NAN, 16, 3.35)
	_winged_wheel(pk, kit, Vector3(0, HB_CB_ATTIC + 1.8, HB_CB_Z + 0.02), out)
	# The sides above the wings' roof, the returns in front of the wings.
	for s in [-1.0, 1.0]:
		var sf := _wf(Vector3(s * HB_CB, 0, HB_CB_Z if s > 0.0 else -HBF_D), Vector3(s, 0, 0))
		_face(pk, kit, "ashlar", sf, 0.0, HB_CORNICE - 0.6, HBF_D + HB_CB_Z, HB_CB_CORNICE, 0.0, SAND)
		var rf := _wf(Vector3(s * HB_CB, 0, HB_CB_Z if s > 0.0 else 0.0), Vector3(s, 0, 0))
		_face(pk, kit, "ashlar", rf, 0.0, -1.5, HB_CB_Z, HB_CORNICE - 0.6, 0.0, SAND)
		for k in range(3):
			_rect(pk, kit, "ashlar", sf, 6.0 + 9.0 * float(k), HB_CORNICE + 2.5, 7.2 + 9.0 * float(k), HB_CB_CORNICE - 0.2, 0.0, 0.12, SAND_LIGHT)
	# The back over the house platform: a great arched window into the hall.
	var bp := Vector3(0, 0, -HBF_D)
	var bal := Vector3.LEFT
	var bout := Vector3(0, 0, -1)
	var bholes: Array = [ZK._arch_hole(0.0, PLATFORM_TOP + 1.2, 7.0, 5.6, 7.0)]
	ZK._wall(pk, kit, "ashlar", bp, bal, bout, -HB_CB, HB_CB, PLATFORM_TOP, HB_CB_CORNICE, bholes, SAND, 0.8)
	ZK._arch_open(pk, kit, "ashlar", bp, bal, bout, 0.0, PLATFORM_TOP + 1.2, 7.0, 5.6, 7.0, 0.8, SAND,
			{"trim": "ashlar", "trim_col": SAND_LIGHT, "trim_w": 0.5, "keystone": true, "glass": true, "segs": 14, "sill": true, "sill_col": SAND_LIGHT})
	# The barrel roof in patinated copper (standing seams) between the gables.
	var n := 16
	var rr: float = (13.8 * 13.8 + 5.0 * 5.0) / (2.0 * 5.0)
	var cy: float = HB_CB_ATTIC - 1.4 + 5.0 - rr
	var a0: float = atan2(HB_CB_ATTIC - 1.4 - cy, 13.8)
	var pts: Array = []
	for k in range(n + 1):
		var a: float = lerpf(a0, PI - a0, float(k) / float(n))
		pts.append(Vector2(cos(a) * rr, cy + sin(a) * rr))
	var zf: float = HB_CB_Z - 0.85
	var zb: float = -HBF_D + 0.85
	var run := 0.0
	for k in range(n):
		var p: Vector2 = pts[k]
		var q: Vector2 = pts[k + 1]
		var seg: float = p.distance_to(q)
		var nm := Vector3((p.x + q.x) * 0.5, (p.y + q.y) * 0.5 - cy, 0).normalized()
		pk.quad(kit, "zinc", [Vector3(p.x, p.y, zf), Vector3(q.x, q.y, zf), Vector3(q.x, q.y, zb), Vector3(p.x, p.y, zb)], nm, PATINA,
				[Vector2(zf, run) * uvk, Vector2(zf, run + seg) * uvk, Vector2(zb, run + seg) * uvk, Vector2(zb, run) * uvk])
		run += seg


## A winged wheel (the railway's emblem, no company's) in gilt bronze facing `out` at c: a spoked wheel with two
## swept wings behind it.
static func _winged_wheel(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3) -> void:
	var wf := _wf(c, out)
	KT._circle_ring(pk, kit, "gold", wf, Vector2.ZERO, 0.62, 0.8, 0.0, 0.12, GOLD, 20)
	KT._circle_ring(pk, kit, "gold", wf, Vector2.ZERO, 0.0, 0.16, 0.0, 0.16, GOLD, 10)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		pk.beam(kit, "gold", wf * Vector3(cos(a) * 0.14, sin(a) * 0.14, 0.06), wf * Vector3(cos(a) * 0.64, sin(a) * 0.64, 0.06), 0.07, 0.06, GOLD, out)
	for s in [-1.0, 1.0]:
		var wing := PackedVector2Array()
		for k in range(6):
			var t: float = float(k) / 5.0
			wing.append(Vector2(s * (0.7 + 1.9 * t), 0.15 + 0.55 * t - 0.25 * t * t))
		for k in range(5, -1, -1):
			var t2: float = float(k) / 5.0
			wing.append(Vector2(s * (0.7 + 1.9 * t2), -0.25 + 0.75 * t2 * t2 - 0.08 * t2))
		if s < 0.0:
			wing.reverse()
		KT._prism(pk, kit, "gold", wf, wing, -0.02, 0.07, GOLD.darkened(0.08))
		for k in range(1, 5):
			var fx: float = s * (0.7 + 1.9 * float(k) / 5.0)
			pk.beam(kit, "gold", wf * Vector3(fx, -0.15 + 0.1 * float(k), 0.08), wf * Vector3(fx + s * 0.25, 0.1 + 0.1 * float(k), 0.08), 0.04, 0.03, GOLD.lightened(0.1), out)


## The clock tower (x 36..44, z 0.5..-7.5): its front's storeys continue the wing's, then the shaft with tall arched
## windows, the clock stage with four dials (11:36), the cornice with urns, the copper helm and lantern, a gilt finial.
static func _hb_tower(pk: PropKit, kit: Dictionary) -> void:
	var x0: float = TOWER_X - HB_TW
	var x1: float = TOWER_X + HB_TW
	var faces: Array = [[Vector3(x0, 0, HB_TZ0), Vector3(0, 0, 1)], [Vector3(x1, 0, HB_TZ0), Vector3(1, 0, 0)], [Vector3(x1, 0, HB_TZ1), Vector3(0, 0, -1)],
			[Vector3(x0, 0, HB_TZ1), Vector3(-1, 0, 0)]]
	var w: float = HB_TW * 2.0
	for i in range(4):
		var wf := _wf(faces[i][0], faces[i][1])
		var front: bool = i == 0
		if front:
			_hb_facade(pk, kit, wf, 0.0, w, [[w * 0.5, "door"]], 0.0, HB_EAVE, true)
			_face(pk, kit, "ashlar", wf, 0.0, HB_CORNICE, w, HB_TOWER_SHAFT, 0.0, SAND)
		else:
			_face(pk, kit, "ashlar", wf, 0.0, HB_EAVE - 0.5, w, HB_TOWER_SHAFT, 0.0, SAND)
		# Corner lisenes, a string course at 24.6, a tall arched window, the clock in a square frame.
		_rect(pk, kit, "ashlar", wf, 0.0, HB_CORNICE, 0.7, HB_TOWER_SHAFT - 0.8, 0.0, 0.12, SAND_LIGHT)
		_rect(pk, kit, "ashlar", wf, w - 0.7, HB_CORNICE, w, HB_TOWER_SHAFT - 0.8, 0.0, 0.12, SAND_LIGHT)
		RS._mould(pk, kit, "ashlar", wf, -0.02, w + 0.02, PackedVector2Array([Vector2(0.0, 24.4), Vector2(0.18, 24.4), Vector2(0.22, 24.55),
				Vector2(0.22, 24.75), Vector2(0.0, 24.75)]), SAND_LIGHT)
		RS._gz_arched_window(pk, kit, wf, w * 0.5, 17.4, 23.2, 1.5, HB_FRAME, SAND_LIGHT)
		KT._ring_rect(pk, kit, "ashlar", wf, w * 0.5 - 2.2, 25.8, w * 0.5 + 2.2, 30.2, 0.3, 0.0, 0.14, SAND_LIGHT)
		_face(pk, kit, "ashlar", wf, w * 0.5 - 1.9, 26.1, w * 0.5 + 1.9, 29.9, 0.03, SAND_DARK)
		var cc: Vector3 = wf * Vector3(w * 0.5, 28.0, 0.03)
		var saved := _push(pk, Transform3D(Basis.from_scale(Vector3.ONE * 2.4), cc))
		YK.clock_face(pk, kit, Vector3.ZERO, (faces[i][1] as Vector3), 1.6 / 2.4, 11.6, 7.2)
		_pop(pk, saved)
		RS._mould(pk, kit, "ashlar", wf, -0.05, w + 0.05, PackedVector2Array([Vector2(0.0, HB_TOWER_SHAFT - 0.8), Vector2(0.1, HB_TOWER_SHAFT - 0.8),
				Vector2(0.45, HB_TOWER_SHAFT - 0.55), Vector2(0.55, HB_TOWER_SHAFT - 0.3), Vector2(0.5, HB_TOWER_SHAFT - 0.2), Vector2(0.5, HB_TOWER_SHAFT),
				Vector2(0.0, HB_TOWER_SHAFT)]), SAND_LIGHT)
	# The tower's top, urns on its corners, the copper helm (square, flat-faced), the octagonal lantern, the finial.
	var c := Vector3(TOWER_X, 0, (HB_TZ0 + HB_TZ1) * 0.5)
	pk.quad(kit, "ashlar", [c + Vector3(-HB_TW - 0.5, HB_TOWER_SHAFT, -HB_TW - 0.5), c + Vector3(HB_TW + 0.5, HB_TOWER_SHAFT, -HB_TW - 0.5),
			c + Vector3(HB_TW + 0.5, HB_TOWER_SHAFT, HB_TW + 0.5), c + Vector3(-HB_TW - 0.5, HB_TOWER_SHAFT, HB_TW + 0.5)], UP, SAND)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pk.lathe(kit, "ashlar", c + Vector3(sx * (HB_TW - 0.2), HB_TOWER_SHAFT, sz * (HB_TW - 0.2)), [Vector2(0.3, 0.0), Vector2(0.3, 0.2), Vector2(0.18, 0.3),
					Vector2(0.3, 0.55), Vector2(0.34, 0.8), Vector2(0.2, 1.0), Vector2(0.12, 1.15), Vector2(0.001, 1.25)], 8, SAND_LIGHT)
	var sq := Basis(UP, PI * 0.25)
	var r2 := sqrt(2.0)
	var y0: float = HB_TOWER_SHAFT
	pk.lathe(kit, "copper", c + Vector3(0, y0, 0), [Vector2(3.6 * r2, 0.0), Vector2(3.55 * r2, 0.5), Vector2(3.2 * r2, 1.3), Vector2(2.5 * r2, 2.1),
			Vector2(1.9 * r2, 3.0), Vector2(1.55 * r2, 3.8), Vector2(1.35 * r2, 4.5), Vector2(1.35 * r2, 4.8)], 4, PATINA, true, sq)
	pk.lathe(kit, "copper", c + Vector3(0, y0 + 4.8, 0), [Vector2(1.6, 0.0), Vector2(1.6, 0.2), Vector2(1.0, 0.25), Vector2(1.0, 1.9), Vector2(1.25, 2.0),
			Vector2(1.25, 2.15), Vector2(0.95, 2.6), Vector2(0.55, 3.4), Vector2(0.2, 4.4), Vector2(0.001, 4.6)], 8, PATINA, true)
	for k in range(8):
		var a: float = TAU * (float(k) + 0.5) / 8.0
		var d := Vector3(cos(a), 0, sin(a))
		_box(pk, kit, "matte", c + Vector3(0, y0 + 5.9, 0) + d * 0.93, Basis(UP, -a + PI * 0.5), Vector3(0.45, 1.1, 0.06), BLACK)
	pk.lathe(kit, "gold", c + Vector3(0, y0 + 9.3, 0), [Vector2(0.001, 0.0), Vector2(0.22, 0.12), Vector2(0.25, 0.3), Vector2(0.18, 0.48), Vector2(0.001, 0.55)],
			10, GOLD)
	pk.tube(kit, "gold", c + Vector3(0, y0 + 9.8, 0), c + Vector3(0, TOWER_TOP, 0), 0.05, 0.01, 6, GOLD, true)


## The corner pavilions (|x| 54..62): their fronts at z 0.8 with the wing's storeys, an attic storey to HB_PAV_TOP round all
## four sides, a cornice and a steep slate pavilion roof with a finial.
static func _hb_pavilions(pk: PropKit, kit: Dictionary) -> void:
	for s in [-1.0, 1.0]:
		var xa: float = s * HB_PAV
		var xb: float = s * HBF_HX
		var lo: float = minf(xa, xb)
		var front := _wf(Vector3(lo, 0, HB_PAV_Z), Vector3(0, 0, 1))
		var w: float = HBF_HX - HB_PAV
		_hb_facade(pk, kit, front, 0.0, w, [[2.0, "win"], [6.0, "win"]])
		# The return toward the wing.
		var rf := _wf(Vector3(xa, 0, 0.0 if s > 0.0 else HB_PAV_Z), Vector3(-s, 0, 0))
		_face(pk, kit, "ashlar", rf, 0.0, -1.5, HB_PAV_Z, HB_CORNICE, 0.0, SAND)
		# The attic storey round all four sides, its cornice, the roof.
		var c := Vector3((xa + xb) * 0.5, 0, (HB_PAV_Z + HB_PAV_Z1) * 0.5)
		var hx: float = w * 0.5
		var hz: float = (HB_PAV_Z - HB_PAV_Z1) * 0.5
		ZK._ring_sides(pk, kit, "ashlar", c, hx, hz, 0.0, HB_CORNICE - 0.3, HB_PAV_TOP - 0.8, SAND)
		ZK._cornice(pk, kit, "ashlar", c, hx, hz, HB_PAV_TOP - 0.8, [Vector2(0.06, 0.3), Vector2(0.3, 0.25), Vector2(0.55, 0.25)], SAND_LIGHT, 0.4, false)
		for f in [[Vector3(c.x - hx, 0, c.z + hz), Vector3(0, 0, 1), w], [Vector3(c.x + hx, 0, c.z - hz), Vector3(0, 0, -1), w],
				[Vector3(c.x + hx, 0, c.z + hz), Vector3(1, 0, 0), hz * 2.0], [Vector3(c.x - hx, 0, c.z - hz), Vector3(-1, 0, 0), hz * 2.0]]:
			var wf := _wf(f[0], f[1])
			var ln: float = f[2]
			for k in range(2):
				var u: float = ln * (0.25 + 0.5 * float(k))
				KT._circle_ring(pk, kit, "ashlar", wf, Vector2(u, 17.2), 0.55, 0.78, 0.0, 0.08, SAND_LIGHT, 14)
				_disc(pk, kit, "pane", wf * Vector3(u, 17.2, 0.02), wf.basis.z, 0.56, 14, GLASS_DARK)
		ZK._pyramid(pk, kit, "kslate", c, hx + 0.6, hz + 0.6, HB_PAV_TOP - 0.05, HB_PAV_TOP + 6.4, SLATE, true)
		pk.lathe(kit, "copper", c + Vector3(0, HB_PAV_TOP + 6.2, 0), [Vector2(0.4, 0.0), Vector2(0.35, 0.3), Vector2(0.18, 0.5), Vector2(0.22, 0.8),
				Vector2(0.06, 1.2), Vector2(0.001, 2.2)], 8, PATINA)


## The wings' mansard over the whole building: a steep slate lower slope round all four sides and a low hipped top, dormers
## on the front and back, chimneys.
static func _hb_roof(pk: PropKit, kit: Dictionary) -> void:
	var cz: float = (0.5 - HBF_D - 0.2) * 0.5
	var hz0: float = (0.5 + HBF_D + 0.2) * 0.5
	ZK._hopper(pk, kit, "kslate", 0.0, cz, HB_CORNICE - 0.02, HBF_HX + 0.3, hz0, HB_BREAK, HBF_HX - 1.4, hz0 - 1.7, SLATE)
	ZK._hip_roof(pk, kit, "kslate", Vector3(0, 0, cz), HBF_HX - 1.4, hz0 - 1.7, HB_BREAK, 0.15, SLATE)
	var slope := Vector3(0, 1.7, 2.78).normalized()
	for side in [1.0, -1.0]:
		var ze: float = 0.5 if side > 0.0 else -HBF_D - 0.2
		for x in [-50.0, -42.0, -34.0, -26.0, -18.0, 18.0, 26.0, 32.0, 48.0]:
			if side > 0.0 and absf(float(x) - TOWER_X) < 6.0:
				continue
			_hb_dormer(pk, kit, Vector3(float(x), HB_CORNICE + 0.25, ze - side * 0.02), side)
	for cx in [-44.0, -24.0, 24.0, 52.0]:
		_blk(pk, kit, "brick", Vector3(cx - 0.5, HB_BREAK, cz - 0.4), Vector3(cx + 0.5, HB_BREAK + 3.4, cz + 0.4), BRICK)
		_blk(pk, kit, "ashlar", Vector3(cx - 0.6, HB_BREAK + 3.4, cz - 0.5), Vector3(cx + 0.6, HB_BREAK + 3.6, cz + 0.5), SAND_LIGHT)


## A zinc-clad dormer standing on the mansard's lower slope: its front (facing z sign `side`) at `p` (the window's foot), a
## segmental top, its cheeks running back into the roof.
static func _hb_dormer(pk: PropKit, kit: Dictionary, p: Vector3, side: float) -> void:
	var out := Vector3(0, 0, side)
	var wf := _wf(p, out)
	var ol := PackedVector2Array([Vector2(-0.85, -0.2), Vector2(0.85, -0.2)])
	var arc: PackedVector2Array = KT._arch(0.0, 1.7, 0.85, "segment", 6, 0.35)
	for i in range(arc.size() - 1, -1, -1):
		ol.append(arc[i])
	ol.reverse()
	KT._prism(pk, kit, "zinc", wf, ol, -2.2, 0.0, Color(0.55, 0.57, 0.58), Vector2(0, 1), false, true)
	RS._gz_window(pk, kit, wf, 0.0, 0.1, 1.55, 1.1, HB_FRAME)


## The taxi canopy over x -32..-10, z 0..8: steel posts along its front, a box girder with a fascia (TAXI), rafters back to
## the facade, a glass roof falling to the front, lights under it, a lit taxi sign on top and a rank sign on a post.
static func _hb_canopy(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var x0 := -32.0
	var x1 := -10.0
	var zf := 7.6
	var yf := 5.4
	var yb := 6.35
	var col := Color(0.22, 0.25, 0.27)
	for px in [-31.6, -26.15, -20.7, -15.25, -10.4]:
		pk.tube(kit, "steel", Vector3(px, -0.3, zf), Vector3(px, yf - 0.4, zf), 0.12, 0.12, 10, col, true)
		pk.lathe(kit, "steel", Vector3(px, 0, zf), [Vector2(0.2, 0.0), Vector2(0.2, 0.25), Vector2(0.13, 0.4), Vector2(0.001, 0.41)], 10, col)
		pk.lathe(kit, "steel", Vector3(px, yf - 0.6, zf), [Vector2(0.13, 0.0), Vector2(0.22, 0.15), Vector2(0.22, 0.22), Vector2(0.001, 0.23)], 10, col)
	_blk(pk, kit, "steel", Vector3(x0 - 0.1, yf - 0.4, zf - 0.18), Vector3(x1 + 0.1, yf + 0.05, zf + 0.18), col)
	_blk(pk, kit, "enamel", Vector3(x0 - 0.12, yf - 0.38, zf + 0.18), Vector3(x1 + 0.12, yf + 0.12, zf + 0.24), DB_BLUE)
	for lx in [-27.5, -14.5]:
		_lbl(labels, "TAXI", Vector3(lx, yf - 0.13, zf + 0.255), Vector3(0, 0, 1), 0.3, Color(0.97, 0.97, 0.95), 2.0)
	var n := 9
	for k in range(n):
		var x: float = lerpf(x0 + 0.1, x1 - 0.1, float(k) / float(n - 1))
		pk.beam(kit, "steel", Vector3(x, yf, zf + 0.15), Vector3(x, yb, 0.08), 0.1, 0.22, col, Vector3.RIGHT)
	var tn := Vector3(0, zf - 0.08, yb - yf).normalized()
	tn = Vector3(0, 1, (yb - yf) / (zf - 0.08)).normalized()
	var a := Vector3(x0, yf + 0.11, zf + 0.15)
	var b := Vector3(x1, yf + 0.11, zf + 0.15)
	var c := Vector3(x1, yb + 0.11, 0.08)
	var d := Vector3(x0, yb + 0.11, 0.08)
	var lw: float = x1 - x0
	var lv: float = a.distance_to(d)
	pk.quad(kit, "glass", [a, b, c, d], tn, WHITE, [Vector2(0, 0), Vector2(lw, 0), Vector2(lw, lv), Vector2(0, lv)])
	var dn := Vector3(0, -0.13, 0)
	pk.quad(kit, "skylight", [a + dn, b + dn, c + dn, d + dn], -tn, WHITE, [Vector2(0, 0), Vector2(lw, 0), Vector2(lw, lv), Vector2(0, lv)])
	for k in range(4):
		var lx2: float = lerpf(-29.0, -13.0, float(k) / 3.0)
		_box(pk, kit, "bulb", Vector3(lx2, yf - 0.43, zf - 0.6), Basis(), Vector3(0.9, 0.04, 0.2), Color(1.0, 0.95, 0.85))
	# The lit TAXI sign on the girder, the rank sign at the canopy's end.
	_box(pk, kit, "lamp", Vector3(-21.0, yf + 0.38, zf), Basis(), Vector3(1.7, 0.5, 0.26), Color(1.0, 0.82, 0.18))
	for sn in [1.0, -1.0]:
		_lbl(labels, "TAXI", Vector3(-21.0, yf + 0.38, zf + sn * 0.135), Vector3(0, 0, sn), 0.3, BLACK, 1.5)
	pk.tube(kit, "metal", Vector3(-33.0, -0.3, 8.6), Vector3(-33.0, 2.9, 8.6), 0.04, 0.04, 8, GALV, true)
	_box(pk, kit, "enamel", Vector3(-33.0, 2.55, 8.64), Basis(), Vector3(0.72, 0.42, 0.03), SIGN_YELLOW)
	_lbl(labels, "TAXI", Vector3(-33.0, 2.55, 8.66), Vector3(0, 0, 1), 0.2, BLACK, 0.62)


## The elevated part's brick block: its back wall (z -100) with blind arches, workshops and the north exit through one
## arch, a parapet over the back platform; its end walls (x +-62) up to BED_Y; the trackbed between the platforms.
static func _hb_block(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1908
	var ptop: float = PLATFORM_TOP + 1.1
	var bl: float = BLOCK_HX * 2.0
	_arch_wall(pk, kit, Vector3(BLOCK_HX, 0, BLOCK_Z1), Vector3.LEFT, Vector3(0, 0, -1), bl, ptop,
			{"bay": 9.6, "shops": 0.35, "dark": [6], "rng": rng, "labels": labels, "frieze_pitch": 2.0})
	var n: int = int(round(bl / 9.6))
	var cu: float = bl / float(n) * 6.5
	_lbl(labels, "AUSGANG NORD", Vector3(BLOCK_HX - cu, 5.0, BLOCK_Z1 - 0.06), Vector3(0, 0, -1), 0.4, Color(0.95, 0.95, 0.92), 4.0)
	_box(pk, kit, "enamel", Vector3(BLOCK_HX - cu, 5.0, BLOCK_Z1 - 0.03), Basis(), Vector3(4.4, 0.7, 0.04), DB_BLUE)
	# The parapet's inner face over the back platform.
	ZK._mq(pk, kit, "brick", Vector3(-BLOCK_HX, 0, BLOCK_Z1 + 0.5), Vector3.RIGHT, Vector3(0, 0, 1), 0.0, bl, PLATFORM_TOP - 0.05, ptop - 0.35, BRICK)
	for s in [-1.0, 1.0]:
		var p0 := Vector3(s * BLOCK_HX, 0, -HBF_D if s > 0.0 else BLOCK_Z1)
		var al: Vector3 = Vector3(0, 0, -1) if s > 0.0 else Vector3(0, 0, 1)
		var r2 := RandomNumberGenerator.new()
		r2.seed = 77 + int(s)
		_arch_wall(pk, kit, p0, al, Vector3(s, 0, 0), -HBF_D - BLOCK_Z1, BED_Y, {"bay": 9.0, "shops": 0.3, "rng": r2, "labels": labels, "frieze_pitch": 2.4})
		# Where the block reaches past the building's end (|x| 62..64): its front face at z = -28 and a coping.
		var xa: float = minf(s * HBF_HX, s * BLOCK_HX)
		var xb: float = maxf(s * HBF_HX, s * BLOCK_HX)
		ZK._mq(pk, kit, "brick", Vector3(0, 0, -HBF_D), Vector3.RIGHT, Vector3(0, 0, 1), xa, xb, -1.5, BED_Y, BRICK)
		_blk(pk, kit, "ashlar", Vector3(xa, BED_Y, -HBF_D - 0.5), Vector3(xb, BED_Y + 0.15, -HBF_D + 0.2), SAND)
	# The trackbed: one top over the whole block (the platforms stand on it).
	_uvquad(pk, kit, "grime", Vector3(-BLOCK_HX, BED_Y, -HBF_D), Vector3(BLOCK_HX, BED_Y, -HBF_D), Vector3(BLOCK_HX, BED_Y, BLOCK_Z1 + 0.5),
			Vector3(-BLOCK_HX, BED_Y, BLOCK_Z1 + 0.5), UP, Color(0.34, 0.32, 0.30))


## The platforms: concrete edges overhanging recessed walls, a white safety line, the tops (with stairwells down to the
## subway on the islands and the back platform), railings at their ends, benches, name boards, track numbers, clocks,
## train indicators, a news kiosk on the house platform.
static func _hb_platforms(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var top: float = PLATFORM_TOP
	var lx: float = HBF_HX
	var slab := Color(0.70, 0.69, 0.66)
	for pi in range(PLATFORMS.size()):
		var z0: float = PLATFORMS[pi][0]
		var z1: float = PLATFORMS[pi][1]
		var edges: Array = []   # [edge z, outward sign]
		if pi > 0:
			edges.append([z0, 1.0])
		if pi < PLATFORMS.size() - 1:
			edges.append([z1, -1.0])
		var zc: float = (z0 + z1) * 0.5
		var wells: Array = [] if pi == 0 else [-23.0, 23.0]
		var hole_hz := 1.35
		var hole_hx := 4.6
		# The top, around the stairwells.
		var xs: Array = [-lx]
		for wx in wells:
			xs.append(float(wx) - hole_hx)
			xs.append(float(wx) + hole_hx)
		xs.append(lx)
		for k in range(0, xs.size() - 1):
			var xa: float = xs[k]
			var xb: float = xs[k + 1]
			if k % 2 == 0:
				_uvquad(pk, kit, "floor", Vector3(xa, top, z0), Vector3(xb, top, z0), Vector3(xb, top, z1), Vector3(xa, top, z1), UP, slab)
			else:
				_uvquad(pk, kit, "floor", Vector3(xa, top, z0), Vector3(xb, top, z0), Vector3(xb, top, zc + hole_hz), Vector3(xa, top, zc + hole_hz), UP, slab)
				_uvquad(pk, kit, "floor", Vector3(xa, top, zc - hole_hz), Vector3(xb, top, zc - hole_hz), Vector3(xb, top, z1), Vector3(xa, top, z1), UP, slab)
		for e in edges:
			var ez: float = e[0]
			var sg: float = e[1]
			# The edge slab overhanging the recessed wall, the safety line.
			_blk(pk, kit, "concrete", Vector3(-lx, top - 0.24, ez - sg * 0.6), Vector3(lx, top + 0.005, ez), Color(0.78, 0.77, 0.74))
			ZK._mq(pk, kit, "concrete", Vector3(-lx if sg > 0.0 else lx, 0, ez - sg * 0.25), Vector3.RIGHT * sg, Vector3(0, 0, sg), 0.0, lx * 2.0, BED_Y - 0.05,
					top - 0.24, CONC.darkened(0.15))
			var lz: float = ez - sg * 0.85
			pk.quad(kit, "paint", [Vector3(-lx, top + 0.012, lz - 0.05), Vector3(lx, top + 0.012, lz - 0.05), Vector3(lx, top + 0.012, lz + 0.05),
					Vector3(-lx, top + 0.012, lz + 0.05)], UP, Color(0.95, 0.95, 0.93))
		# The ends at x = +-62: an end face and a railing across.
		for sx in [-1.0, 1.0]:
			var x: float = sx * lx
			var zf0: float = z0 if pi > 0 else z0
			var zf1: float = z1
			var ins: float = 0.25
			var za: float = zf0 - (ins if pi > 0 else 0.0)
			var zb: float = zf1 + (ins if pi < PLATFORMS.size() - 1 else 0.0)
			pk.quad(kit, "concrete", [Vector3(x, BED_Y - 0.05, za), Vector3(x, BED_Y - 0.05, zb), Vector3(x, top, zb), Vector3(x, top, za)], Vector3(sx, 0, 0),
					CONC.darkened(0.1), [Vector2(0, BED_Y) * uvk, Vector2(za - zb, BED_Y) * uvk, Vector2(za - zb, top) * uvk, Vector2(0, top) * uvk])
			SW._railing(pk, kit, [Vector3(x - sx * 0.5, top, z0 - 0.4), Vector3(x - sx * 0.5, top, z1 + 0.4)], 1.1, Color(0.30, 0.33, 0.32), "steel")
		# Stairwells down to the subway.
		for wx in wells:
			_stairwell(pk, kit, Vector3(float(wx), top, zc), hole_hx, hole_hz)
		# Furniture along the platform's middle line.
		var fz: float = zc if pi > 0 else (z0 + z1) * 0.5 - 1.5
		for bx in [-38.5, -7.5, 7.5, 38.5]:
			YK.bench(pk, kit, Vector3(float(bx), top, fz + 0.4), Vector3(0, 0, 1), 1.9)
			if pi > 0 and pi < PLATFORMS.size() - 1:
				YK.bench(pk, kit, Vector3(float(bx), top, fz - 0.4), Vector3(0, 0, -1), 1.9)
		for nx in [-50.5, -11.5, 11.5, 50.5]:
			_name_board(pk, kit, labels, Vector3(float(nx), top, fz), pi > 0 and pi < PLATFORMS.size() - 1)
		for cx in [35.0]:
			pk.tube(kit, "steel", Vector3(float(cx), top, fz), Vector3(float(cx), top + 3.3, fz), 0.06, 0.05, 8, IRON_GREEN, true)
			for cs in [-1.0, 1.0]:
				YK.clock_face(pk, kit, Vector3(float(cx) + cs * 0.06, top + 3.55, fz), Vector3(cs, 0, 0), 0.38, 11.6, 7.2)
			_blk(pk, kit, "steel", Vector3(float(cx) - 0.06, top + 3.15, fz - 0.45), Vector3(float(cx) + 0.06, top + 3.95, fz + 0.45), IRON_GREEN)
		# Track numbers and train indicators at the platform's edges.
		for e2 in edges:
			var ez2: float = e2[0]
			var sg2: float = e2[1]
			var tn: int = _track_number(ez2 - sg2 * PLATFORM_EDGE)
			for tx in [-55.0, -20.0, 20.0, 55.0]:
				var tp := Vector3(float(tx), top, ez2 - sg2 * 2.2)
				pk.tube(kit, "steel", tp, tp + Vector3(0, 3.6, 0), 0.05, 0.05, 8, IRON_GREEN, true)
				_box(pk, kit, "enamel", tp + Vector3(0, 3.35, sg2 * 0.06), Basis(), Vector3(0.62, 0.62, 0.05), DB_BLUE)
				_lbl(labels, str(tn), tp + Vector3(0, 3.35, sg2 * 0.09), Vector3(0, 0, sg2), 0.42, Color(0.97, 0.97, 0.95), 0.5)
				if absf(float(tx)) < 30.0:
					_led(pk, kit, tp + Vector3(0, 2.75, sg2 * 0.12), Vector3(0, 0, sg2), 2.2, 0.5, AMBER)
					_box(pk, kit, "steel", tp + Vector3(0, 2.75, sg2 * 0.03), Basis(), Vector3(0.12, 0.3, 0.1), IRON_GREEN)
	# A news kiosk on the house platform.
	var kc := Vector3(-23.0, top, -36.5)
	_blk(pk, kit, "painted", kc + Vector3(-1.6, 0, -1.1), kc + Vector3(1.6, 2.5, 1.1), Color(0.18, 0.30, 0.24))
	_blk(pk, kit, "steel", kc + Vector3(-1.75, 2.5, -1.25), kc + Vector3(1.75, 2.7, 1.25), STEEL_DARK)
	_face(pk, kit, "pane", _wf(kc + Vector3(-1.6, 0, 1.1), Vector3(0, 0, 1)), 0.2, 1.0, 3.0, 2.2, 0.02, GLASS_DARK.lightened(0.05))
	_box(pk, kit, "enamel", kc + Vector3(0, 2.95, 1.0), Basis(), Vector3(2.8, 0.45, 0.06), Color(0.85, 0.12, 0.10))
	_lbl(labels, "PRESSE  TABAK", kc + Vector3(0, 2.95, 1.04), Vector3(0, 0, 1), 0.22, WHITE, 2.6)


## Which track (1..4) runs at z.
static func _track_number(z: float) -> int:
	var best := 0
	for i in range(TRACKS_Z.size()):
		if absf(float(TRACKS_Z[i]) - z) < absf(float(TRACKS_Z[best]) - z):
			best = i
	return best + 1


## A station name board ("Kronburg Hbf", white on blue) on two posts at p (on the platform), its faces toward +z (and
## -z with `both`).
static func _name_board(pk: PropKit, kit: Dictionary, labels: Array, p: Vector3, both: bool) -> void:
	for sx in [-1.25, 1.25]:
		pk.tube(kit, "steel", p + Vector3(sx, 0, 0), p + Vector3(sx, 2.9, 0), 0.05, 0.05, 8, IRON_GREEN, true)
	_box(pk, kit, "enamel", p + Vector3(0, 2.55, 0), Basis(), Vector3(3.0, 0.62, 0.06), DB_BLUE)
	_box(pk, kit, "enamel", p + Vector3(0, 2.55, 0), Basis(), Vector3(3.1, 0.7, 0.04), Color(0.95, 0.95, 0.93))
	_lbl(labels, "Kronburg Hbf", p + Vector3(0, 2.55, 0.035), Vector3(0, 0, 1), 0.3, WHITE, 2.7)
	if both:
		_lbl(labels, "Kronburg Hbf", p + Vector3(0, 2.55, -0.035), Vector3(0, 0, -1), 0.3, WHITE, 2.7)


## A stairwell in a platform: the hole (c its middle on the top, hx along x, hz across) lined with concrete, steps from its
## +x end down toward -x into the dark, railings round its sides and far end.
static func _stairwell(pk: PropKit, kit: Dictionary, c: Vector3, hx: float, hz: float) -> void:
	var depth := 4.4
	var wall := CONC.darkened(0.2)
	for sz in [-1.0, 1.0]:
		var z: float = c.z + sz * hz
		pk.quad(kit, "concrete", [Vector3(c.x - hx, c.y - depth, z), Vector3(c.x + hx, c.y - depth, z), Vector3(c.x + hx, c.y, z), Vector3(c.x - hx, c.y, z)],
				Vector3(0, 0, -sz), wall)
	pk.quad(kit, "matte", [Vector3(c.x - hx, c.y - depth, c.z - hz), Vector3(c.x - hx, c.y - depth, c.z + hz), Vector3(c.x - hx, c.y, c.z + hz),
			Vector3(c.x - hx, c.y, c.z - hz)], Vector3(1, 0, 0), BLACK)
	var n := 26
	var tread: float = hx * 2.0 / float(n)
	var rise: float = depth / float(n)
	for k in range(n):
		var xa: float = c.x + hx - float(k) * tread
		var y: float = c.y - float(k + 1) * rise
		var shade: Color = Color(0.55, 0.55, 0.53).darkened(clampf(float(k) / float(n) * 0.8, 0.0, 0.8))
		pk.quad(kit, "concrete", [Vector3(xa, y, c.z - hz), Vector3(xa, y, c.z + hz), Vector3(xa - tread, y, c.z + hz), Vector3(xa - tread, y, c.z - hz)], UP, shade)
		pk.quad(kit, "concrete", [Vector3(xa, y, c.z - hz), Vector3(xa, y + rise, c.z - hz), Vector3(xa, y + rise, c.z + hz), Vector3(xa, y, c.z + hz)],
				Vector3(1, 0, 0), shade.darkened(0.1))
	var rc := Color(0.30, 0.33, 0.32)
	SW._railing(pk, kit, [Vector3(c.x + hx, c.y, c.z + hz + 0.08), Vector3(c.x - hx - 0.08, c.y, c.z + hz + 0.08), Vector3(c.x - hx - 0.08, c.y, c.z - hz - 0.08),
			Vector3(c.x + hx, c.y, c.z - hz - 0.08)], 1.05, rc, "steel")
	_box(pk, kit, "enamel", Vector3(c.x + hx + 0.3, c.y + 2.3, c.z), Basis(), Vector3(0.05, 0.4, 1.6), DB_BLUE)




## A segmental arc over z from zc + hs to zc - hs springing at `spring` and rising `rise`: [centre y, radius, start angle].
static func _arc_def(hs: float, spring: float, rise: float) -> Array:
	var r: float = (hs * hs + rise * rise) / (2.0 * rise)
	var cy: float = spring + rise - r
	return [cy, r, atan2(spring - cy, hs)]


## n + 1 points (Vector2(z, y)) along that arc grown by `grow` (same centre), from zc + hs round to zc - hs.
static func _arc_pts(zc: float, hs: float, spring: float, rise: float, n: int, grow := 0.0) -> Array:
	var d: Array = _arc_def(hs, spring, rise)
	var cy: float = d[0]
	var r: float = float(d[1]) + grow
	var a0: float = d[2]
	var out: Array = []
	for i in range(n + 1):
		var a: float = lerpf(a0, PI - a0, float(i) / float(n))
		out.append(Vector2(zc + cos(a) * r, cy + sin(a) * r))
	return out


## The arc's height over z (inside its span), grown by `grow`.
static func _arc_y(zc: float, hs: float, spring: float, rise: float, z: float, grow := 0.0) -> float:
	var d: Array = _arc_def(hs, spring, rise)
	var r: float = float(d[1]) + grow
	return float(d[0]) + sqrt(maxf(r * r - (z - zc) * (z - zc), 0.0))


## A flat polygon of steel glazing (UVs the polygon's own coordinates, life metres) in the plane through `o` (u along
## `along`, v up), facing `out`; the inside face ("skylight") `inset` behind it.
static func _glass_poly(pk: PropKit, kit: Dictionary, o: Vector3, along: Vector3, out: Vector3, poly: PackedVector2Array, inset := 0.03) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tris.size(), 3):
		var a: Vector2 = poly[tris[i]]
		var b: Vector2 = poly[tris[i + 1]]
		var c: Vector2 = poly[tris[i + 2]]
		var pa: Vector3 = o + along * a.x + UP * a.y
		var pb: Vector3 = o + along * b.x + UP * b.y
		var pc: Vector3 = o + along * c.x + UP * c.y
		pk.tri(kit, "glass", pa, pb, pc, out, out, out, WHITE, out, a, b, c)
		var di: Vector3 = -out * inset
		pk.tri(kit, "skylight", pa + di, pb + di, pc + di, -out, -out, -out, WHITE, -out, a, b, c)


## The three arched train sheds: cast-iron columns on the column rows with knee braces, a sickle truss at every frame,
## lattice eaves girders along the rows, purlins, the skin (glass over the middle, zinc toward the eaves; daylight under
## the glass, dark boards under the zinc), a glazed lantern along each crown, box gutters, a fretted valance along the
## outer eaves, glazed end screens with muntins over a girder at SHED_APRON, pendant lamps over the platforms.
static func _hb_sheds(pk: PropKit, kit: Dictionary) -> void:
	var lx: float = HBF_HX
	var n := 10
	var iron: Color = IRON_GREEN
	var xs: Array = []
	for k in range(SHED_FRAMES):
		xs.append(lerpf(-lx, lx, float(k) / float(SHED_FRAMES - 1)))
	var colh: float = SHED_SPRING - PLATFORM_TOP
	for hi in range(3):
		var za: float = SHED_ROWS[hi]
		var zb: float = SHED_ROWS[hi + 1]
		var zc: float = (za + zb) * 0.5
		var hs: float = (za - zb) * 0.5
		var outer: Array = _arc_pts(zc, hs, SHED_SPRING, SHED_RISE, n)
		var inner: Array = _arc_pts(zc, hs, SHED_SPRING, SHED_RISE - 1.3, n)
		# The trusses.
		for x in xs:
			for i in range(n):
				var o0: Vector2 = outer[i]
				var o1: Vector2 = outer[i + 1]
				var i0: Vector2 = inner[i]
				var i1: Vector2 = inner[i + 1]
				ZK._bar(pk, kit, "steel", Vector3(x, o0.y, o0.x), Vector3(x, o1.y, o1.x), 0.22, 0.18, iron, Vector3.RIGHT)
				ZK._bar(pk, kit, "steel", Vector3(x, i0.y, i0.x), Vector3(x, i1.y, i1.x), 0.2, 0.14, iron, Vector3.RIGHT)
				if i > 0:
					ZK._bar(pk, kit, "steel", Vector3(x, o0.y, o0.x), Vector3(x, i0.y, i0.x), 0.1, 0.08, iron, Vector3.RIGHT)
				if i % 2 == 0:
					ZK._bar(pk, kit, "steel", Vector3(x, o0.y, o0.x), Vector3(x, i1.y, i1.x), 0.1, 0.07, iron, Vector3.RIGHT)
				else:
					ZK._bar(pk, kit, "steel", Vector3(x, i0.y, i0.x), Vector3(x, o1.y, o1.x), 0.1, 0.07, iron, Vector3.RIGHT)
		# Purlins under the skin.
		for i in range(2, n - 1, 2):
			var op: Vector2 = outer[i]
			ZK._bar(pk, kit, "steel", Vector3(-lx - 0.2, op.y, op.x), Vector3(lx + 0.2, op.y, op.x), 0.14, 0.16, iron)
		# The skin.
		var skin: Array = _arc_pts(zc, hs, SHED_SPRING, SHED_RISE, n, 0.14)
		var under: Array = _arc_pts(zc, hs, SHED_SPRING, SHED_RISE, n, 0.1)
		var cy: float = float(_arc_def(hs, SHED_SPRING, SHED_RISE)[0])
		var run := 0.0
		for j in range(n):
			var s0: Vector2 = skin[j]
			var s1: Vector2 = skin[j + 1]
			var u0: Vector2 = under[j]
			var u1: Vector2 = under[j + 1]
			var seg: float = s0.distance_to(s1)
			var m: Vector2 = (s0 + s1) * 0.5
			var nm := Vector3(0, m.y - cy, m.x - zc).normalized()
			var a := Vector3(-lx - 0.25, s0.y, s0.x)
			var b := Vector3(lx + 0.25, s0.y, s0.x)
			var c := Vector3(lx + 0.25, s1.y, s1.x)
			var d := Vector3(-lx - 0.25, s1.y, s1.x)
			var ua := Vector3(-lx - 0.25, u0.y, u0.x)
			var ub := Vector3(lx + 0.25, u0.y, u0.x)
			var uc := Vector3(lx + 0.25, u1.y, u1.x)
			var ud := Vector3(-lx - 0.25, u1.y, u1.x)
			var w: float = lx * 2.0 + 0.5
			if j >= 3 and j <= n - 4:
				pk.quad(kit, "glass", [a, b, c, d], nm, WHITE, [Vector2(0, run), Vector2(w, run), Vector2(w, run + seg), Vector2(0, run + seg)])
				pk.quad(kit, "skylight", [ua, ub, uc, ud], -nm, WHITE, [Vector2(0, run), Vector2(w, run), Vector2(w, run + seg), Vector2(0, run + seg)])
			else:
				pk.quad(kit, "zinc", [a, b, c, d], nm, Color(0.55, 0.57, 0.58), [Vector2(0, run) * uvk, Vector2(w, run) * uvk, Vector2(w, run + seg) * uvk,
						Vector2(0, run + seg) * uvk])
				pk.quad(kit, "painted", [ua, ub, uc, ud], -nm, Color(0.30, 0.27, 0.24))
			run += seg
		# The lantern along the crown.
		var lw := 1.6
		var y_side: float = _arc_y(zc, hs, SHED_SPRING, SHED_RISE, zc + lw, 0.14)
		var lt: float = y_side + 1.2
		var ll: float = lx - 2.0
		for sz in [-1.0, 1.0]:
			var zz: float = zc + sz * lw
			var po := Vector3(-ll if sz > 0.0 else ll, 0, zz)
			var al: Vector3 = Vector3.RIGHT if sz > 0.0 else Vector3.LEFT
			_glass_poly(pk, kit, po, al, Vector3(0, 0, sz), PackedVector2Array([Vector2(0, y_side - 0.1), Vector2(ll * 2.0, y_side - 0.1),
					Vector2(ll * 2.0, lt), Vector2(0, lt)]), 0.03)
			YK.roof(pk, kit, "zinc", Vector3(ll, lt - 0.1, zc + sz * (lw + 0.35)), Vector3(-ll, lt - 0.1, zc + sz * (lw + 0.35)), Vector3(-ll, lt + 0.55, zc),
					Vector3(ll, lt + 0.55, zc), Color(0.55, 0.57, 0.58), Vector3(0, lw + 0.35, sz * 0.65).normalized())
		for ex in [-ll, ll]:
			var en := Vector3(signf(ex), 0, 0)
			pk.quad(kit, "zinc", [Vector3(ex, y_side - 0.1, zc - lw), Vector3(ex, y_side - 0.1, zc + lw), Vector3(ex, lt, zc + lw), Vector3(ex, lt, zc - lw)], en,
					Color(0.5, 0.52, 0.53))
			pk.tri(kit, "zinc", Vector3(ex, lt, zc - lw - 0.35), Vector3(ex, lt, zc + lw + 0.35), Vector3(ex, lt + 0.55, zc), en, en, en, Color(0.5, 0.52, 0.53), en)
		for k in range(1, SHED_FRAMES - 1):
			pk.beam(kit, "steel", Vector3(xs[k], y_side - 0.1, zc - lw), Vector3(xs[k], lt, zc - lw), 0.08, 0.08, iron)
			pk.beam(kit, "steel", Vector3(xs[k], y_side - 0.1, zc + lw), Vector3(xs[k], lt, zc + lw), 0.08, 0.08, iron)
		# The glazed end screens.
		for s in [-1.0, 1.0]:
			var out := Vector3(s, 0, 0)
			var al2: Vector3 = Vector3(0, 0, -1) if s > 0.0 else Vector3(0, 0, 1)
			var o := Vector3(s * (lx + 0.22), 0, 0)
			var arc: Array = _arc_pts(zc, hs, SHED_SPRING, SHED_RISE, n, 0.08)
			var poly := PackedVector2Array()
			var uf := func(z: float) -> float: return -z * s
			poly.append(Vector2(uf.call(za), SHED_APRON))
			poly.append(Vector2(uf.call(zb), SHED_APRON))
			for i in range(n, -1, -1):
				var ap: Vector2 = arc[i]
				poly.append(Vector2(uf.call(ap.x), ap.y))
			_glass_poly(pk, kit, o, al2, out, poly, 0.03)
			_blk(pk, kit, "steel", Vector3(s * (lx + 0.12), SHED_APRON - 0.4, zb), Vector3(s * (lx + 0.34), SHED_APRON + 0.04, za), iron)
			var nm2: int = int(hs * 2.0 / 1.8)
			for k in range(1, nm2):
				var z: float = lerpf(zb, za, float(k) / float(nm2))
				var yt: float = _arc_y(zc, hs, SHED_SPRING, SHED_RISE, z, 0.08)
				pk.beam(kit, "steel", Vector3(s * (lx + 0.26), SHED_APRON, z), Vector3(s * (lx + 0.26), yt, z), 0.07, 0.07, iron)
			for t in [0.5, 0.75]:
				var yy: float = lerpf(SHED_APRON, SHED_SPRING + SHED_RISE, t)
				var dz: float = sqrt(maxf(pow(float(_arc_def(hs, SHED_SPRING, SHED_RISE)[1]) + 0.08, 2.0) - pow(yy - cy, 2.0), 0.0))
				pk.beam(kit, "steel", Vector3(s * (lx + 0.26), yy, zc - dz), Vector3(s * (lx + 0.26), yy, zc + dz), 0.07, 0.07, iron)
		# Pendant lamps over the platforms under this hall.
		for pl in PLATFORMS:
			var pz0: float = pl[0]
			var pz1: float = pl[1]
			var lzs: Array = []
			for zl in [pz0 - 3.5, (pz0 + pz1) * 0.5 + 2.6, (pz0 + pz1) * 0.5 - 2.6, pz1 + 3.5]:
				if zl < za - 1.5 and zl > zb + 1.5 and zl < pz0 - 1.0 and zl > pz1 + 1.0:
					lzs.append(zl)
			for zl2 in lzs:
				var yi: float = _arc_y(zc, hs, SHED_SPRING, SHED_RISE - 1.3, zl2)
				for k in range(2, SHED_FRAMES - 1, 2):
					var lp := Vector3(xs[k], PLATFORM_TOP + 4.6, zl2)
					pk.beam(kit, "steel", lp, Vector3(xs[k], yi, zl2), 0.03, 0.03, STEEL_DARK)
					pk.lathe(kit, "metal", lp, [Vector2(0.001, -0.02), Vector2(0.42, -0.04), Vector2(0.4, 0.0), Vector2(0.12, 0.2), Vector2(0.001, 0.3)], 8,
							Color(0.18, 0.28, 0.24))
					pk.lathe(kit, "bulb", lp + Vector3(0, -0.06, 0), [Vector2(0.001, -0.06), Vector2(0.12, -0.02), Vector2(0.001, 0.05)], 6, Color(1.0, 0.92, 0.75))
	# The columns with their knee braces, the lattice eaves girders and gutters along the rows, the valances outside.
	for ri in range(SHED_ROWS.size()):
		var zr: float = SHED_ROWS[ri]
		for x in xs:
			pk.lathe(kit, "steel", Vector3(x, PLATFORM_TOP, zr), [Vector2(0.36, 0.0), Vector2(0.36, 0.3), Vector2(0.2, 0.55), Vector2(0.15, colh - 1.05),
					Vector2(0.3, colh - 0.45), Vector2(0.4, colh - 0.18), Vector2(0.4, colh - 0.02), Vector2(0.001, colh - 0.01)], 8, iron)
			for side in [-1.0, 1.0]:
				var hi2: int = ri - 1 if side > 0.0 else ri
				if hi2 < 0 or hi2 > 2:
					continue
				var za2: float = SHED_ROWS[hi2]
				var zb2: float = SHED_ROWS[hi2 + 1]
				var inn: Array = _arc_pts((za2 + zb2) * 0.5, (za2 - zb2) * 0.5, SHED_SPRING, SHED_RISE - 1.3, 14)
				var tip: Vector2 = inn[1] if side < 0.0 else inn[13]
				pk.beam(kit, "steel", Vector3(x, SHED_SPRING - 2.2, zr + side * 0.12), Vector3(x, tip.y, tip.x), 0.1, 0.12, iron, Vector3.RIGHT)
		# The eaves girder along the row: a riveted plate girder from column to column.
		SW._ibeam(pk, kit, "steel", Vector3(-lx, SHED_SPRING - 0.45, zr), Vector3(lx, SHED_SPRING - 0.45, zr), 0.9, 0.36, iron, UP, 0.04, 0.05)
		_blk(pk, kit, "zinc", Vector3(-lx - 0.3, SHED_SPRING + 0.02, zr - 0.42), Vector3(lx + 0.3, SHED_SPRING + 0.36, zr + 0.42), Color(0.52, 0.54, 0.55))
		if ri == 0 or ri == SHED_ROWS.size() - 1:
			var so: float = 1.0 if ri == 0 else -1.0
			var ol := PackedVector2Array([Vector2(-lx - 0.3, SHED_SPRING + 0.36), Vector2(-lx - 0.3, SHED_SPRING - 0.3)])
			var teeth: int = int((lx * 2.0 + 0.6) / 0.8)
			var tp: float = (lx * 2.0 + 0.6) / float(teeth)
			for k in range(teeth):
				var xa: float = -lx - 0.3 + float(k) * tp
				ol.append(Vector2(xa + tp * 0.5, SHED_SPRING - 0.6))
				ol.append(Vector2(xa + tp, SHED_SPRING - 0.3))
			ol.append(Vector2(lx + 0.3, SHED_SPRING + 0.36))
			var vf := Transform3D(Basis(Vector3.RIGHT, UP, Vector3(0, 0, 1)), Vector3(0, 0, zr + so * 0.44))
			KT._prism(pk, kit, "painted", vf, ol, -0.02, 0.02, Color(0.88, 0.84, 0.72), Vector2(1, 0), true)


## Gleis 1 and 4, the station's own stub tracks (the generator lays only the line's two through it): a ballast bed,
## concrete sleepers, rails at PLATFORM_Y, a buffer stop at each end of the platforms.
static func _hb_rails(pk: PropKit, kit: Dictionary) -> void:
	var gh := 0.67
	var x1 := 60.0
	var rail_col := Color(0.36, 0.28, 0.22)
	for ti in [0, TRACKS_Z.size() - 1]:
		var tz: float = TRACKS_Z[ti]
		_blk(pk, kit, "grime", Vector3(-x1 - 1.2, BED_Y - 0.02, tz - 1.45), Vector3(x1 + 1.2, BED_Y + 0.27, tz + 1.45), Color(0.42, 0.40, 0.37))
		var ns: int = int(x1 * 2.0 / 0.8)
		for k in range(ns + 1):
			var x: float = -x1 + float(k) * x1 * 2.0 / float(ns)
			pk.box(kit, "concrete", Transform3D(Basis(), Vector3(x, BED_Y + 0.345, tz)), Vector3(0.26, 0.19, 2.4), CONC.darkened(0.12), uvk, true)
		for sz in [-1.0, 1.0]:
			var rz: float = tz + sz * gh
			_blk(pk, kit, "steel", Vector3(-x1, BED_Y + 0.44, rz - 0.07), Vector3(x1, BED_Y + 0.47, rz + 0.07), rail_col)
			_blk(pk, kit, "steel", Vector3(-x1, BED_Y + 0.47, rz - 0.025), Vector3(x1, PLATFORM_Y - 0.045, rz + 0.025), rail_col)
			_blk(pk, kit, "metal", Vector3(-x1, PLATFORM_Y - 0.045, rz - 0.04), Vector3(x1, PLATFORM_Y, rz + 0.04), Color(0.62, 0.60, 0.58))
		# The buffer stops: two H-section posts on the rails' ends, a striped beam with two buffers facing the track, struts.
		for e in [-1.0, 1.0]:
			var bx: float = e * (x1 + 0.35)
			var by: float = PLATFORM_Y + 0.98
			for sz2 in [-1.0, 1.0]:
				var pz: float = tz + sz2 * gh
				SW._ibeam(pk, kit, "steel", Vector3(bx, BED_Y + 0.27, pz), Vector3(bx, by + 0.35, pz), 0.18, 0.16, STEEL_DARK, Vector3(1, 0, 0))
				SW._ibeam(pk, kit, "steel", Vector3(bx + e * 0.05, by + 0.1, pz), Vector3(bx + e * 1.0, BED_Y + 0.3, pz), 0.14, 0.12, STEEL_DARK, Vector3(0, 0, 1))
				pk.lathe(kit, "metal", Vector3(bx - e * 0.12, by, tz + sz2 * 0.85), [Vector2(0.001, 0.0), Vector2(0.09, 0.0), Vector2(0.09, 0.2), Vector2(0.2, 0.2),
						Vector2(0.21, 0.24), Vector2(0.001, 0.25)], 10, Color(0.20, 0.20, 0.21), false, Basis(Vector3(0, 0, 1), PI * 0.5 * e))
			for k in range(6):
				var z0: float = tz - 1.15 + 2.3 * float(k) / 6.0
				_blk(pk, kit, "paint", Vector3(bx - 0.13, by - 0.22, z0), Vector3(bx + 0.13, by + 0.22, z0 + 2.3 / 6.0),
						Color(0.85, 0.08, 0.06) if k % 2 == 0 else Color(0.95, 0.95, 0.93))
			pk.lathe(kit, "lamp", Vector3(bx, by + 0.22, tz), [Vector2(0.001, 0.0), Vector2(0.08, 0.0), Vector2(0.08, 0.12), Vector2(0.001, 0.14)], 10, TAIL_LAMP)


## A polygon (points in order) facing `n`, fanned from its first point (convex).
static func _fan(pk: PropKit, kit: Dictionary, key: String, pts: Array, n: Vector3, col: Color) -> void:
	for i in range(1, pts.size() - 1):
		pk.tri(kit, key, pts[0], pts[i], pts[i + 1], n, n, n, col, n)


# ======================================================================================
#  KAUFHAUS KRONE: the pedestrian zone's 1960s department store
# ======================================================================================

const KH_GF := 5.2            # the ground floor's height: the upper facade starts here
const KH_TOP := 23.0          # the main roof (the facade's frame stands 0.2 over it)
const KH_REST := 26.4         # the recessed top storey's roof (the restaurant)
const KH_CANOPY := 3.0        # how far the canopy reaches out (+z)
const KH_CANOPY_Y := 4.45     # its underside
const KH_BAY := 7.5
const KH_RECESS := 0.5        # the shop windows' glass behind the columns' faces
const KH_WHITE := Color(0.95, 0.95, 0.92)
const KH_BRONZE := Color(0.36, 0.26, 0.16)
const KH_GRANITE := Color(0.20, 0.20, 0.22)
const KH_DISPLAY := [Color(0.85, 0.80, 0.70), Color(0.62, 0.20, 0.22), Color(0.20, 0.34, 0.52), Color(0.88, 0.86, 0.82), Color(0.30, 0.45, 0.32),
		Color(0.92, 0.72, 0.30)]
const KH_CLOTHES := [Color(0.80, 0.15, 0.18), Color(0.10, 0.12, 0.30), Color(0.95, 0.92, 0.85), Color(0.25, 0.45, 0.35), Color(0.85, 0.60, 0.25),
		Color(0.55, 0.30, 0.55), Color(0.15, 0.15, 0.16)]

## A mannequin standing on c (1.75m): a round foot, a stand, legs, a torso in `col`, a head.
static func _mannequin(pk: PropKit, kit: Dictionary, c: Vector3, col: Color, face: Vector3) -> void:
	var skin := Color(0.92, 0.90, 0.86)
	pk.lathe(kit, "metal", c, [Vector2(0.001, 0.0), Vector2(0.18, 0.0), Vector2(0.18, 0.02), Vector2(0.03, 0.03), Vector2(0.001, 0.03)], 10, Color(0.75, 0.76, 0.77))
	pk.tube(kit, "metal", c, c + UP * 0.9, 0.012, 0.012, 5, Color(0.75, 0.76, 0.77), false)
	var side: Vector3 = UP.cross(face).normalized()
	for s in [-1.0, 1.0]:
		pk.tube(kit, "plastic", c + side * (s * 0.09) + UP * 0.08, c + side * (s * 0.08) + UP * 0.88, 0.05, 0.065, 6, col.darkened(0.25), true)
	pk.lathe(kit, "plastic", c + UP * 0.86, [Vector2(0.001, 0.0), Vector2(0.17, 0.02), Vector2(0.15, 0.22), Vector2(0.16, 0.48), Vector2(0.2, 0.58),
			Vector2(0.06, 0.66), Vector2(0.001, 0.68)], 8, col, false, Basis.from_scale(Vector3(1.0, 1.0, 0.65)))
	for s2 in [-1.0, 1.0]:
		pk.tube(kit, "plastic", c + side * (s2 * 0.2) + UP * 1.42, c + side * (s2 * 0.24) + UP * 0.98 + face * 0.06, 0.04, 0.035, 6, col, true)
	pk.tube(kit, "plastic", c + UP * 1.52, c + UP * 1.6, 0.04, 0.04, 6, skin, false)
	_ellipsoid(pk, kit, "plastic", c + UP * 1.68, Vector3(0.09, 0.115, 0.1), 8, 5, skin)


## One display window's box behind the glass (x0..x1 at the glass's plane z = -KH_RECESS): a raised floor, a coloured back
## wall, sides and a ceiling with spotlights, and what is on show (mannequins, boxes, a bicycle, a toy train...).
static func _kh_display(pk: PropKit, kit: Dictionary, x0: float, x1: float, rng: RandomNumberGenerator) -> void:
	var zg: float = -KH_RECESS
	var zb: float = zg - 1.8
	var fy := 0.55
	var ty := 4.3
	var back: Color = KH_DISPLAY[rng.randi() % KH_DISPLAY.size()]
	_blk(pk, kit, "painted", Vector3(x0, 0.0, zb), Vector3(x1, fy, zg - 0.02), Color(0.80, 0.76, 0.70))
	pk.quad(kit, "enamel", [Vector3(x0, fy, zb), Vector3(x1, fy, zb), Vector3(x1, ty, zb), Vector3(x0, ty, zb)], Vector3(0, 0, 1), back)
	pk.quad(kit, "enamel", [Vector3(x0, fy, zg), Vector3(x0, fy, zb), Vector3(x0, ty, zb), Vector3(x0, ty, zg)], Vector3(1, 0, 0), back.darkened(0.15))
	pk.quad(kit, "enamel", [Vector3(x1, fy, zb), Vector3(x1, fy, zg), Vector3(x1, ty, zg), Vector3(x1, ty, zb)], Vector3(-1, 0, 0), back.darkened(0.15))
	pk.quad(kit, "matte", [Vector3(x0, ty, zg), Vector3(x1, ty, zg), Vector3(x1, ty, zb), Vector3(x0, ty, zb)], Vector3(0, -1, 0), Color(0.25, 0.24, 0.23))
	var nl: int = int((x1 - x0) / 1.4)
	for k in range(nl):
		var lx: float = lerpf(x0 + 0.6, x1 - 0.6, float(k) / float(maxi(nl - 1, 1)))
		pk.lathe(kit, "bulb", Vector3(lx, ty - 0.01, zg - 0.6), [Vector2(0.001, 0.0), Vector2(0.09, 0.0)], 8, Color(1.0, 0.94, 0.80), true, Basis(Vector3.RIGHT, PI))
	var kind: int = rng.randi() % 3
	var w: float = x1 - x0
	if kind < 2:
		var nm: int = 3 if w > 5.0 else 2
		for k in range(nm):
			var mx: float = lerpf(x0 + 1.0, x1 - 1.0, (float(k) + 0.5) / float(nm)) + rng.randf_range(-0.2, 0.2)
			_mannequin(pk, kit, Vector3(mx, fy, zg - 0.95 + rng.randf_range(-0.2, 0.2)), KH_CLOTHES[rng.randi() % KH_CLOTHES.size()],
					Vector3(rng.randf_range(-0.3, 0.3), 0, 1).normalized())
		# A low plinth with folded goods.
		var px: float = lerpf(x0, x1, 0.5)
		_blk(pk, kit, "painted", Vector3(px - 0.5, fy, zg - 0.55), Vector3(px + 0.5, fy + 0.3, zg - 0.15), Color(0.95, 0.95, 0.93))
		for k2 in range(3):
			_blk(pk, kit, "plastic", Vector3(px - 0.4 + 0.27 * float(k2), fy + 0.3, zg - 0.48), Vector3(px - 0.18 + 0.27 * float(k2), fy + 0.36, zg - 0.22),
					KH_CLOTHES[(k2 + 2) % KH_CLOTHES.size()])
	else:
		# Toys and sport: a pyramid of boxes, a bicycle, balls.
		var cx: float = x0 + 1.2
		for k3 in range(3):
			for j in range(3 - k3):
				_blk(pk, kit, "plastic", Vector3(cx + 0.45 * float(j) + 0.22 * float(k3), fy + 0.4 * float(k3), zg - 1.3),
						Vector3(cx + 0.45 * float(j) + 0.22 * float(k3) + 0.42, fy + 0.4 * float(k3) + 0.38, zg - 0.8), KH_DISPLAY[(j + k3 * 2) % KH_DISPLAY.size()].lightened(0.1))
		RS._bicycle(pk, kit, Vector3(x1 - 1.6, fy, zg - 1.0), Vector3(1, 0, 0), KH_CLOTHES[rng.randi() % KH_CLOTHES.size()])
		for k4 in range(3):
			_ellipsoid(pk, kit, "plastic", Vector3(x0 + 2.9 + 0.5 * float(k4), fy + 0.14, zg - 0.45), Vector3(0.14, 0.14, 0.14), 8, 5, KH_CLOTHES[k4 % KH_CLOTHES.size()])


## KAUFHAUS KRONE (1965, fictional), x -w/2..w/2, its front z = 0 facing +z, back z = -d: a ground floor of shop windows
## and two entrances between granite-clad columns (the glass KH_RECESS behind them), a cantilevered canopy (underside
## KH_CANOPY_Y, out to z = KH_CANOPY) with the name and departments on its bronze fascia and spotlights under it; over it
## the windowless upper storeys clad in white ceramic honeycomb tiles in a concrete frame (KH_GF..KH_TOP) with the name in
## gilt letters and a red blade sign at the east corner; a recessed glazed top storey (the roof restaurant, to KH_REST)
## behind a terrace, a gilt crown on the roof. Within x +-(w/2 + 0.3), z -d..KH_CANOPY + 0.06.
static func department_store(pk: PropKit, kit: Dictionary, labels: Array, w := 60.0, d := 40.0) -> void:
	var hw: float = w * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 1965
	var front := _wf(Vector3.ZERO, Vector3(0, 0, 1))
	# --- The upper storeys: the honeycomb field in its frame, on the front and both sides; the back in plain concrete.
	_face(pk, kit, "honeycomb", front, -hw + 0.45, KH_GF + 0.4, hw - 0.45, KH_TOP - 0.25, 0.0, KH_WHITE)
	KT._ring_rect(pk, kit, "concrete", front, -hw, KH_GF, hw + 0.12, KH_TOP + 0.2, 0.45, 0.0, 0.12, KH_WHITE.darkened(0.04))
	for s in [-1.0, 1.0]:
		var sf := _wf(Vector3(s * hw, 0, 0.0 if s > 0.0 else -d), Vector3(s, 0, 0))
		_face(pk, kit, "honeycomb", sf, 0.45, KH_GF + 0.4, d - 0.45, KH_TOP - 0.25, 0.0, KH_WHITE)
		KT._ring_rect(pk, kit, "concrete", sf, 0.0 if s > 0.0 else -0.12, KH_GF, d + (0.12 if s < 0.0 else 0.0), KH_TOP + 0.2, 0.45, 0.0, 0.12, KH_WHITE.darkened(0.04))
		_face(pk, kit, "concrete", sf, 0.0, -1.5, d, KH_GF, 0.0, CONC)
	var bk := _wf(Vector3(hw, 0, -d), Vector3(0, 0, -1))
	_face(pk, kit, "concrete", bk, 0.0, -1.5, w, KH_TOP + 0.2, 0.0, CONC.darkened(0.05))
	for k in range(3):
		_face(pk, kit, "matte", bk, 8.0 + 18.0 * float(k), 0.0, 12.5 + 18.0 * float(k), 4.2, 0.03, Color(0.30, 0.32, 0.33))
	# The soffit under the upper facade over the recessed ground floor; the main roof inside the frame's parapet.
	pk.quad(kit, "concrete", [Vector3(-hw, KH_GF, 0.0), Vector3(hw, KH_GF, 0.0), Vector3(hw, KH_GF, -KH_RECESS - 0.1), Vector3(-hw, KH_GF, -KH_RECESS - 0.1)],
			Vector3(0, -1, 0), CONC.darkened(0.2))
	_uvquad(pk, kit, "grime", Vector3(-hw, KH_TOP, -0.45), Vector3(hw, KH_TOP, -0.45), Vector3(hw, KH_TOP, -d), Vector3(-hw, KH_TOP, -d), UP, Color(0.40, 0.39, 0.37))
	# The name in gilt letters across the honeycomb, the crown over it.
	_lbl(labels, "KAUFHAUS KRONE", Vector3(0, KH_TOP - 4.6, 0.09), Vector3(0, 0, 1), 2.1, GOLD, w - 8.0)
	var saved := _push(pk, Transform3D(Basis(), Vector3(0, KH_TOP - 2.55, 0.0)))
	_blk(pk, kit, "concrete", Vector3(-1.6, -0.12, 0.0), Vector3(1.6, 0.12, 1.4), KH_WHITE.darkened(0.05))
	KT._crown(pk, kit, Vector3(0, 0.12, 0.7), 0.85)
	_pop(pk, saved)
	# --- The ground floor: columns, shop windows with their displays, two entrances, the canopy.
	var nb: int = int(round(w / KH_BAY))
	var bay: float = w / float(nb)
	var doors: Array = [int(nb / 4), nb - 1 - int(nb / 4)]
	for j in range(nb + 1):
		var cx: float = -hw + bay * float(j)
		var c0: float = maxf(cx - 0.4, -hw)
		var c1: float = minf(cx + 0.4, hw)
		_blk(pk, kit, "pane", Vector3(c0, -0.3, -KH_RECESS - 0.1), Vector3(c1, KH_GF, 0.0), KH_GRANITE)
	for k in range(nb):
		var x0: float = -hw + bay * float(k) + 0.4
		var x1: float = -hw + bay * float(k + 1) - 0.4
		var zg: float = -KH_RECESS
		if k in doors:
			# The entrance: a recess to z -2, glass doors in a bronze frame, the dark shop behind, a lit ceiling.
			var zd := -2.2
			_blk(pk, kit, "stone", Vector3(x0, -0.3, zd), Vector3(x1, 0.04, zg), Color(0.55, 0.53, 0.50))
			pk.quad(kit, "concrete", [Vector3(x0, KH_CANOPY_Y - 0.15, zg), Vector3(x1, KH_CANOPY_Y - 0.15, zg), Vector3(x1, KH_CANOPY_Y - 0.15, zd),
					Vector3(x0, KH_CANOPY_Y - 0.15, zd)], Vector3(0, -1, 0), CONC.darkened(0.15))
			pk.quad(kit, "concrete", [Vector3(x0, KH_CANOPY_Y - 0.15, zg), Vector3(x1, KH_CANOPY_Y - 0.15, zg), Vector3(x1, KH_GF, zg), Vector3(x0, KH_GF, zg)],
					Vector3(0, 0, 1), CONC.darkened(0.1))
			for sx in [x0, x1]:
				var n2: Vector3 = Vector3(1, 0, 0) if sx == x0 else Vector3(-1, 0, 0)
				pk.quad(kit, "pane", [Vector3(sx, 0.04, zg), Vector3(sx, 0.04, zd), Vector3(sx, KH_CANOPY_Y - 0.15, zd), Vector3(sx, KH_CANOPY_Y - 0.15, zg)], n2,
						KH_GRANITE)
			pk.quad(kit, "matte", [Vector3(x0, 0.04, zd - 0.6), Vector3(x1, 0.04, zd - 0.6), Vector3(x1, KH_CANOPY_Y - 0.15, zd - 0.6), Vector3(x0, KH_CANOPY_Y - 0.15, zd - 0.6)],
					Vector3(0, 0, 1), Color(0.05, 0.05, 0.05))
			for sx2 in [x0, x1]:
				var n3: Vector3 = Vector3(1, 0, 0) if sx2 == x0 else Vector3(-1, 0, 0)
				pk.quad(kit, "matte", [Vector3(sx2, 0.04, zd), Vector3(sx2, 0.04, zd - 0.6), Vector3(sx2, KH_CANOPY_Y - 0.15, zd - 0.6), Vector3(sx2, KH_CANOPY_Y - 0.15, zd)],
						n3, Color(0.05, 0.05, 0.05))
			for k2 in range(3):
				pk.lathe(kit, "bulb", Vector3(lerpf(x0 + 1.2, x1 - 1.2, float(k2) / 2.0), KH_CANOPY_Y - 0.16, (zg + zd) * 0.5), [Vector2(0.001, 0.0), Vector2(0.11, 0.0)], 8,
						Color(1.0, 0.93, 0.78), true, Basis(Vector3.RIGHT, PI))
			# The doors: four leaves between bronze mullions, a transom of glass over them.
			var nd := 4
			for k3 in range(nd + 1):
				var mx: float = lerpf(x0, x1, float(k3) / float(nd))
				_blk(pk, kit, "bronze", Vector3(mx - 0.05, 0.04, zd - 0.06), Vector3(mx + 0.05, KH_CANOPY_Y - 0.15, zd + 0.06), KH_BRONZE)
			_blk(pk, kit, "bronze", Vector3(x0, 2.55, zd - 0.06), Vector3(x1, 2.68, zd + 0.06), KH_BRONZE)
			pk.quad(kit, "sglass", [Vector3(x0, 0.04, zd), Vector3(x1, 0.04, zd), Vector3(x1, KH_CANOPY_Y - 0.15, zd), Vector3(x0, KH_CANOPY_Y - 0.15, zd)], Vector3(0, 0, 1),
					Color(0.62, 0.70, 0.72, 0.25))
			for k4 in range(nd):
				var hx: float = lerpf(x0, x1, (float(k4) + 0.5) / float(nd))
				_blk(pk, kit, "bronze", Vector3(hx - 0.02, 1.0, zd + 0.06), Vector3(hx + 0.02, 1.6, zd + 0.1), Color(0.75, 0.62, 0.35))
		else:
			_kh_display(pk, kit, x0, x1, rng)
			# The stall riser under the glass, the bronze frame, the glass, a transom band over it.
			_blk(pk, kit, "pane", Vector3(x0, -0.3, zg - 0.05), Vector3(x1, 0.55, zg + 0.06), KH_GRANITE.lightened(0.05))
			_blk(pk, kit, "bronze", Vector3(x0, 0.55, zg - 0.03), Vector3(x1, 0.62, zg + 0.05), KH_BRONZE)
			_blk(pk, kit, "bronze", Vector3(x0, 4.24, zg - 0.03), Vector3(x1, 4.32, zg + 0.05), KH_BRONZE)
			for mx2 in [x0 + 0.04, (x0 + x1) * 0.5, x1 - 0.04]:
				_blk(pk, kit, "bronze", Vector3(mx2 - 0.04, 0.62, zg - 0.03), Vector3(mx2 + 0.04, 4.24, zg + 0.05), KH_BRONZE)
			pk.quad(kit, "sglass", [Vector3(x0, 0.62, zg), Vector3(x1, 0.62, zg), Vector3(x1, 4.24, zg), Vector3(x0, 4.24, zg)], Vector3(0, 0, 1), Color(0.62, 0.70, 0.72, 0.18))
			pk.quad(kit, "concrete", [Vector3(x0, 4.32, zg), Vector3(x1, 4.32, zg), Vector3(x1, KH_GF, zg), Vector3(x0, KH_GF, zg)], Vector3(0, 0, 1), CONC.darkened(0.15))
	# The canopy: a slab from the facade out to KH_CANOPY, its bronze fascia with the name and the departments, lights under it.
	var cy0: float = KH_CANOPY_Y
	_blk(pk, kit, "concrete", Vector3(-hw - 0.3, cy0, -KH_RECESS), Vector3(hw + 0.3, cy0 + 0.35, KH_CANOPY), KH_WHITE.darkened(0.08))
	_blk(pk, kit, "bronze", Vector3(-hw - 0.32, cy0 - 0.1, KH_CANOPY), Vector3(hw + 0.32, cy0 + 0.5, KH_CANOPY + 0.06), KH_BRONZE)
	for sx3 in [-1.0, 1.0]:
		_blk(pk, kit, "bronze", Vector3(sx3 * (hw + 0.3) - 0.03, cy0 - 0.1, -KH_RECESS), Vector3(sx3 * (hw + 0.3) + 0.03, cy0 + 0.5, KH_CANOPY), KH_BRONZE)
	var dep: Array = ["KAUFHAUS KRONE", "MODE  -  SCHUHE", "SPORT  -  SPIELWAREN", "KAUFHAUS KRONE", "HAUSHALT  -  ELEKTRO", "LEBENSMITTEL  -  RESTAURANT"]
	for k5 in range(dep.size()):
		var lx2: float = lerpf(-hw + w / float(dep.size()) * 0.5, hw - w / float(dep.size()) * 0.5, float(k5) / float(dep.size() - 1))
		_lbl(labels, String(dep[k5]), Vector3(lx2, cy0 + 0.2, KH_CANOPY + 0.07), Vector3(0, 0, 1), 0.24 if k5 % 3 == 0 else 0.18,
				Color(0.98, 0.86, 0.50) if k5 % 3 == 0 else KH_WHITE, w / float(dep.size()) - 1.0)
	for k6 in range(nb * 2):
		for row in [0.6, 2.0]:
			var lx3: float = -hw + bay * (float(k6) + 0.5) * 0.5
			pk.lathe(kit, "bulb", Vector3(lx3, cy0 - 0.005, row), [Vector2(0.001, 0.0), Vector2(0.1, 0.0)], 8, Color(1.0, 0.94, 0.80), true, Basis(Vector3.RIGHT, PI))
	# The red blade sign at the east corner: KRONE, a letter over another, on both faces, over a crown.
	var bx: float = hw - 2.6
	var by0: float = KH_GF + 1.5
	var by1: float = KH_TOP - 5.0
	_blk(pk, kit, "steel", Vector3(bx - 0.12, by0 + 0.5, 0.0), Vector3(bx + 0.12, by0 + 0.65, 0.4), STEEL_DARK)
	_blk(pk, kit, "steel", Vector3(bx - 0.12, by1 - 0.65, 0.0), Vector3(bx + 0.12, by1 - 0.5, 0.4), STEEL_DARK)
	_blk(pk, kit, "enamel", Vector3(bx - 0.18, by0, 0.4), Vector3(bx + 0.18, by1, 2.0), Color(0.72, 0.08, 0.10))
	for s2 in [-1.0, 1.0]:
		var fx: float = bx + s2 * 0.19
		var fw := _wf(Vector3(fx, 0, 2.0 if s2 > 0.0 else 0.4), Vector3(s2, 0, 0))
		KT._ring_rect(pk, kit, "enamel", fw, 0.0, by0, 1.6, by1, 0.08, 0.0, 0.025, KH_WHITE)
		var word := "KRONE"
		for i in range(word.length()):
			var ly: float = by1 - 1.6 - 1.75 * float(i)
			_lbl(labels, word[i], Vector3(fx + s2 * 0.03, ly, 1.2), Vector3(s2, 0, 0), 1.05, KH_WHITE, 1.3)
	var saved2 := _push(pk, Transform3D(Basis(), Vector3(bx, by1, 1.2)))
	KT._crown(pk, kit, Vector3.ZERO, 0.5)
	_pop(pk, saved2)
	# --- The roof restaurant: a recessed glazed storey (mullions every 1.5m), its roof slab, the terrace's glass railing.
	var rx: float = hw - 2.0
	var rz0 := -2.5
	var rz1: float = -d + 2.0
	_blk(pk, kit, "concrete", Vector3(-rx, KH_TOP, rz1), Vector3(rx, KH_TOP + 0.6, rz0), CONC)
	for e in [[Vector3(-rx, 0, rz0), Vector3(0, 0, 1), rx * 2.0], [Vector3(rx, 0, rz0), Vector3(1, 0, 0), rz0 - rz1], [Vector3(-rx, 0, rz1), Vector3(-1, 0, 0), rz0 - rz1],
			[Vector3(rx, 0, rz1), Vector3(0, 0, -1), rx * 2.0]]:
		var ef := _wf(e[0], e[1])
		var ln: float = e[2]
		_face(pk, kit, "pane", ef, 0.0, KH_TOP + 0.6, ln, KH_REST - 0.1, 0.0, GLASS_DARK.lightened(0.06))
		var nm: int = int(ln / 1.5)
		for k7 in range(nm + 1):
			var mu: float = ln * float(k7) / float(nm)
			_rect(pk, kit, "steel", ef, maxf(mu - 0.04, 0.0), KH_TOP + 0.6, minf(mu + 0.04, ln), KH_REST - 0.1, 0.0, 0.05, STEEL_DARK)
		_rect(pk, kit, "steel", ef, 0.0, KH_TOP + 1.6, ln, KH_TOP + 1.66, 0.0, 0.04, STEEL_DARK)
	_blk(pk, kit, "concrete", Vector3(-rx - 0.7, KH_REST - 0.1, rz1 - 0.7), Vector3(rx + 0.7, KH_REST + 0.3, rz0 + 0.7), KH_WHITE.darkened(0.05))
	var rail_pts: Array = [Vector3(-hw + 0.5, KH_TOP + 0.2, -0.5), Vector3(hw - 0.5, KH_TOP + 0.2, -0.5)]
	for k8 in range(int((w - 1.0) / 1.6) + 1):
		var px2: float = lerpf(-hw + 0.5, hw - 0.5, float(k8) / float(int((w - 1.0) / 1.6)))
		_blk(pk, kit, "steel", Vector3(px2 - 0.03, KH_TOP + 0.2, -0.53), Vector3(px2 + 0.03, KH_TOP + 1.25, -0.47), STEEL_DARK)
	pk.quad(kit, "sglass", [rail_pts[0] + Vector3(0, 0.05, 0), rail_pts[1] + Vector3(0, 0.05, 0), rail_pts[1] + Vector3(0, 1.0, 0), rail_pts[0] + Vector3(0, 1.0, 0)],
			Vector3(0, 0, 1), Color(0.7, 0.8, 0.82, 0.2))
	_blk(pk, kit, "steel", rail_pts[0] + Vector3(0, 1.0, -0.04), rail_pts[1] + Vector3(0, 1.08, 0.04), STEEL_DARK)
	_lbl(labels, "DACHRESTAURANT KRONE", Vector3(0, KH_REST + 0.1, rz0 + 0.71), Vector3(0, 0, 1), 0.28, KH_WHITE, 12.0)
	# Terrace tables and parasols, the plant room and the crown on the roof.
	for k9 in range(5):
		var tx: float = lerpf(-hw + 6.0, hw - 6.0, float(k9) / 4.0)
		_cafe_table(pk, kit, Vector3(tx - 1.0, KH_TOP, -1.5), Color(0.92, 0.92, 0.9), Color(0.75, 0.12, 0.12), 2)
		_cafe_table(pk, kit, Vector3(tx + 1.0, KH_TOP, -1.5), Color(0.92, 0.92, 0.9), Color(0.75, 0.12, 0.12), 2)
		RS._parasol(pk, kit, Vector3(tx, KH_TOP, -1.4), 0.95, Color(0.85, 0.15, 0.15), KH_WHITE)
	_blk(pk, kit, "concrete", Vector3(-8.0, KH_REST + 0.3, -d + 4.0), Vector3(8.0, KH_REST + 3.2, -d + 10.0), CONC.darkened(0.05))
	for k10 in range(3):
		_blk(pk, kit, "metal", Vector3(-6.5 + 5.0 * float(k10), KH_REST + 3.2, -d + 5.0), Vector3(-3.5 + 5.0 * float(k10), KH_REST + 4.0, -d + 9.0), Color(0.62, 0.63, 0.64))
	pk.lathe(kit, "concrete", Vector3(0, KH_REST + 0.3, -12.0), [Vector2(1.6, 0.0), Vector2(1.6, 0.9), Vector2(1.3, 1.05), Vector2(0.001, 1.05)], 16, KH_WHITE.darkened(0.08))
	KT._crown(pk, kit, Vector3(0, KH_REST + 1.35, -12.0), 1.7)


static func department_store_solids(w := 60.0, d := 40.0) -> Array:
	return [
		[Transform3D(Basis(), Vector3(0, (KH_TOP + 0.2 - 1.5) * 0.5, -d * 0.5)), Vector3(w, KH_TOP + 0.2 + 1.5, d)],
		[Transform3D(Basis(), Vector3(0, (KH_TOP + KH_REST + 0.3) * 0.5, (-2.5 - d + 2.0) * 0.5)), Vector3(w - 4.0, KH_REST + 0.3 - KH_TOP, d - 4.5)],
	]
