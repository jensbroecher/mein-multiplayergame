extends RefCounted
## Freight Line's yard buildings (regenerate_freight_line.gd), built through a PropKit at life size and grown by
## the caller (PROP_SCALE): the station, Estación del Viento (a stuccoed building under a tile roof with a clock
## tower, a front portico, shuttered windows, a long canopy over the platform on cast-iron columns, a freight
## shed, the platform with its furniture), and the grain cooperative (silos with their gallery, a head house, the
## loadout gantry over the factory track, a warehouse, tanks).
##
## The hut shaders (hut_masonry, hut_wood, hut_roof_iron) draw the plaster, tile, concrete, timber and corrugated
## iron; they read UVs in world metres (u along a wall or a roof's ridge, v up it), so `uvk`, the caller's scale,
## multiplies every UV. Material keys: "plaster", "tile", "stone", "concrete", "slate", "timber", "lapboards",
## "battens", "painted" and "iron", and FreightKit's (CampKit's) "steel", "wood", "glass", "lamp", "paint", "matte".
##
## Both buildings are laid out in a frame with +z toward the road (their fronts), x along, y up from the pad;
## the platform lies behind the station (-z) and the factory's track runs in front of it (+z).
##
## Roofs rest on what holds them up: every post, column and brace is cut to the plane above it (`_plane_y`), so
## nothing hovers.

const PropKit = preload("res://PropKit.gd")
const FreightKit = preload("res://FreightKit.gd")

static var uvk := 1.6
static var _mats := {}

const MASONRY := {"stone": 0, "brick": 2, "plaster": 4, "tile": 5, "slate": 6, "zinc": 7, "concrete": 8}
const WOOD := {"battens": 0, "lapboards": 1, "timber": 2, "painted": 3}
const TANGENT_KEYS := ["tile", "iron", "concrete", "zinc", "slate"]

const CREAM := Color(0.93, 0.88, 0.75)
const STONE := Color(0.66, 0.62, 0.55)
const TERRACOTTA := Color(0.64, 0.27, 0.17)
const TRIM := Color(0.95, 0.94, 0.90)
const SHUTTER := Color(0.20, 0.38, 0.30)
const DOOR := Color(0.38, 0.16, 0.12)
const GLASS_COL := Color(0.10, 0.15, 0.20, 0.9)
const IRON_GREEN := Color(0.22, 0.34, 0.28)
const CAST := Color(0.13, 0.14, 0.15)
const CONCRETE := Color(0.76, 0.75, 0.71)
const BRICK := Color(0.55, 0.26, 0.18)
const QUOIN := Color(0.82, 0.72, 0.55)


static func make_material(key: String) -> Material:
	if MASONRY.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://hut_masonry.gdshader")
		m.set_shader_parameter("style", MASONRY[key])
		return m
	if WOOD.has(key):
		var w := ShaderMaterial.new()
		w.shader = load("res://hut_wood.gdshader")
		w.set_shader_parameter("style", WOOD[key])
		w.set_shader_parameter("weathering", 0.35)
		return w
	if key == "iron":
		var i := ShaderMaterial.new()
		i.shader = load("res://hut_roof_iron.gdshader")
		i.set_shader_parameter("rust_amount", 0.3)
		return i
	return FreightKit.make_material(key)


static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	return pk


## Commits a kit with tangents on the surfaces whose shaders read a normal map.
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in TANGENT_KEYS:
		if kit.has(key):
			var st: SurfaceTool = kit[key]
			st.index()
			st.generate_tangents()
	return pk.commit(kit)


# ======================================================================================
#  Helpers: UV'd walls and roofs, boxes in a wall's frame
# ======================================================================================

## A wall from a to b (their y is ignored) between y0 and y1 facing `out`, UVs in metres: u along it, v up.
static func wall(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, y0: float, y1: float, col: Color, out: Vector3, u0 := 0.0) -> void:
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	pk.quad(kit, key, [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)], out, col,
			[Vector2(u0, y0) * uvk, Vector2(u0 + l, y0) * uvk, Vector2(u0 + l, y1) * uvk, Vector2(u0, y1) * uvk])


## A roof plane: p0 and p1 along the eave (u), p3 up the slope from p0 (v), p2 above p1.
static func roof(pk: PropKit, kit: Dictionary, key: String, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color, out: Vector3) -> void:
	var lu: float = (p1 - p0).length()
	var lv: float = (p3 - p0).length()
	pk.quad(kit, key, [p0, p1, p2, p3], out, col, [Vector2(0, 0), Vector2(lu, 0) * uvk, Vector2(lu, lv) * uvk, Vector2(0, lv) * uvk])


## A triangle of wall (a gable end) facing `out`, UVs in metres.
static func gable(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, apex: Vector3, col: Color, out: Vector3) -> void:
	var l: float = Vector2(b.x - a.x, b.z - a.z).length()
	var mid: float = l * 0.5
	pk.tri(kit, key, a, b, apex, out, out, out, col, out, Vector2(0, 0), Vector2(l, 0) * uvk, Vector2(mid, apex.y - a.y) * uvk)


## A box centred at `c` whose faces follow `basis`, UVs in metres.
static func box_at(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## Axis-aligned block between two corners, UVs in metres.
static func blk(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	pk.block(kit, key, lo, hi, col, uvk)


## The height of the plane through `p0` rising `slope` per metre along `dir` (horizontal, unit), at the point `at`.
static func _plane_y(p0: Vector3, dir: Vector3, slope: float, at: Vector3) -> float:
	return p0.y + slope * Vector3(at.x - p0.x, 0.0, at.z - p0.z).dot(dir)


## A window in a wall: bright frame, dark glass with a cross of mullions, a stone sill and lintel, and (if
## `shutter` has alpha) a pair of louvred shutters folded back either side. `c` is the middle of the opening on the
## wall's face, `out` the wall's outward normal (axis-aligned), `w` x `h` the opening.
static func window(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, shutter := Color(0, 0, 0, 0)) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	# Glass, a hair proud of the wall.
	box_at(pk, kit, "glass", c + out * 0.03, basis, Vector3(w, h, 0.04), GLASS_COL)
	# Frame: four bars standing 6cm out.
	var fw := 0.09
	box_at(pk, kit, "painted", c + Vector3(0, h * 0.5, 0) + out * 0.05, basis, Vector3(w + 2.0 * fw, fw, 0.1), TRIM)
	box_at(pk, kit, "painted", c - Vector3(0, h * 0.5, 0) + out * 0.05, basis, Vector3(w + 2.0 * fw, fw, 0.1), TRIM)
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "painted", c + across * (sx * (w * 0.5 + fw * 0.5)) + out * 0.05, basis, Vector3(fw, h, 0.1), TRIM)
	box_at(pk, kit, "painted", c + out * 0.07, basis, Vector3(0.05, h, 0.06), TRIM)
	box_at(pk, kit, "painted", c + Vector3(0, h * 0.18, 0) + out * 0.07, basis, Vector3(w, 0.05, 0.06), TRIM)
	# Sill and lintel in stone.
	box_at(pk, kit, "stone", c - Vector3(0, h * 0.5 + 0.1, 0) + out * 0.12, basis, Vector3(w + 0.5, 0.14, 0.3), STONE.lightened(0.1))
	box_at(pk, kit, "stone", c + Vector3(0, h * 0.5 + 0.16, 0) + out * 0.08, basis, Vector3(w + 0.4, 0.2, 0.2), STONE.lightened(0.05))
	if shutter.a > 0.0:
		for sx in [-1.0, 1.0]:
			box_at(pk, kit, "painted", c + across * (sx * (w * 0.5 + fw + w * 0.25)) + out * 0.06, basis, Vector3(w * 0.5, h, 0.05), shutter)
			for k in range(1, 6):
				box_at(pk, kit, "painted", c + across * (sx * (w * 0.5 + fw + w * 0.25)) + Vector3(0, (float(k) / 6.0 - 0.5) * h, 0) + out * 0.095,
						basis, Vector3(w * 0.46, 0.04, 0.03), shutter.darkened(0.25))


## A double door with a transom, stone steps and a lantern: `c` the middle of the sill on the wall's face.
static func door(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, steps := true) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	var fw := 0.14
	box_at(pk, kit, "painted", c + Vector3(0, h * 0.5, 0) + out * 0.04, basis, Vector3(w, h, 0.06), DOOR)
	# Panels on each leaf.
	for sx in [-1.0, 1.0]:
		for py in [0.28, 0.72]:
			box_at(pk, kit, "painted", c + across * (sx * w * 0.25) + Vector3(0, h * py, 0) + out * 0.08, basis, Vector3(w * 0.38, h * 0.3, 0.04), DOOR.lightened(0.08))
		box_at(pk, kit, "steel", c + across * (sx * 0.12) + Vector3(0, h * 0.5, 0) + out * 0.11, basis, Vector3(0.05, 0.3, 0.05), Color(0.78, 0.62, 0.25))
	box_at(pk, kit, "painted", c + out * 0.07 + Vector3(0, h * 0.5, 0), basis, Vector3(0.05, h, 0.06), TRIM)
	# Frame, a glazed transom over the door and a stone lintel.
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "painted", c + across * (sx * (w * 0.5 + fw * 0.5)) + Vector3(0, h * 0.5 + 0.3, 0) + out * 0.06, basis, Vector3(fw, h + 0.6, 0.1), TRIM)
	box_at(pk, kit, "painted", c + Vector3(0, h + 0.03, 0) + out * 0.06, basis, Vector3(w + 2.0 * fw, 0.1, 0.1), TRIM)
	box_at(pk, kit, "glass", c + Vector3(0, h + 0.33, 0) + out * 0.04, basis, Vector3(w, 0.5, 0.04), GLASS_COL)
	box_at(pk, kit, "painted", c + Vector3(0, h + 0.63, 0) + out * 0.06, basis, Vector3(w + 2.0 * fw, 0.1, 0.1), TRIM)
	box_at(pk, kit, "stone", c + Vector3(0, h + 0.82, 0) + out * 0.1, basis, Vector3(w + 0.9, 0.24, 0.26), STONE.lightened(0.05))
	if steps:
		box_at(pk, kit, "stone", c + Vector3(0, 0.07, 0) + out * 0.5, basis, Vector3(w + 0.8, 0.14, 1.0), STONE)
		box_at(pk, kit, "stone", c + Vector3(0, 0.21, 0) + out * 0.35, basis, Vector3(w + 0.6, 0.14, 0.7), STONE.lightened(0.06))


## A cast-iron lamp post: a flared foot, a fluted shaft, a bracket and a glowing lantern. `p` on the ground.
static func lamp_post(pk: PropKit, kit: Dictionary, p: Vector3, height := 3.6) -> void:
	pk.tube(kit, "steel", p, p + Vector3(0, 0.5, 0), 0.26, 0.14, 10, CAST, true)
	pk.tube(kit, "steel", p + Vector3(0, 0.5, 0), p + Vector3(0, height, 0), 0.1, 0.07, 10, CAST, false)
	pk.tube(kit, "steel", p + Vector3(0, 1.1, 0), p + Vector3(0, 1.2, 0), 0.15, 0.15, 10, CAST, true)
	pk.tube(kit, "steel", p + Vector3(0, height - 0.15, 0), p + Vector3(0, height, 0), 0.14, 0.1, 10, CAST, true)
	# The lantern: a glowing glass body between a base and a cap.
	pk.block(kit, "steel", p + Vector3(-0.2, height, -0.2), p + Vector3(0.2, height + 0.08, 0.2), CAST)
	pk.block(kit, "lamp", p + Vector3(-0.16, height + 0.08, -0.16), p + Vector3(0.16, height + 0.55, 0.16), Color(1.0, 0.88, 0.58))
	pk.lathe(kit, "steel", p + Vector3(0, height + 0.55, 0), [Vector2(0.28, 0.0), Vector2(0.16, 0.14), Vector2(0.001, 0.3)], 8, CAST, true)


## A station bench: a slatted seat and back on cast-iron ends, `c` the middle of the seat's front edge on the
## ground, facing `out` (axis-aligned).
static func bench(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, length := 1.9) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	for k in range(5):
		box_at(pk, kit, "timber", c + Vector3(0, 0.46, 0) - out * (0.06 + 0.1 * float(k)), basis, Vector3(length, 0.035, 0.085), Color(0.50, 0.33, 0.18))
	for k in range(3):
		box_at(pk, kit, "timber", c + Vector3(0, 0.62 + 0.13 * float(k), 0) - out * 0.52, basis, Vector3(length, 0.1, 0.03), Color(0.50, 0.33, 0.18))
	for sx in [-1.0, 1.0]:
		var e: Vector3 = c + across * (sx * (length * 0.5 - 0.1))
		box_at(pk, kit, "steel", e + Vector3(0, 0.23, 0) - out * 0.3, basis, Vector3(0.05, 0.46, 0.6), CAST)
		box_at(pk, kit, "steel", e + Vector3(0, 0.62, 0) - out * 0.52, basis, Vector3(0.05, 0.5, 0.05), CAST)
		box_at(pk, kit, "steel", e + Vector3(0, 0.0, 0) - out * 0.3 + Vector3(0, 0.02, 0), basis, Vector3(0.08, 0.04, 0.7), CAST)


## A clock face on a wall (or hung, double faced, by the caller): a cream disc in a dark ring with twelve dots and
## two hands, `c` its middle, `out` the way it faces.
static func clock_face(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, r: float, hour := 10.1, minute := 8.6) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	pk.tube(kit, "paint", c - out * 0.02, c + out * 0.04, r * 1.14, r * 1.14, 24, Color(0.12, 0.12, 0.13), true)
	pk.tube(kit, "paint", c + out * 0.04, c + out * 0.075, r, r, 24, Color(0.96, 0.94, 0.86), true)
	for k in range(12):
		var a: float = TAU * float(k) / 12.0
		var d: Vector3 = across * sin(a) + Vector3.UP * cos(a)
		var big: bool = k % 3 == 0
		box_at(pk, kit, "paint", c + d * r * 0.84 + out * 0.09, basis, Vector3(0.07 if big else 0.05, 0.07 if big else 0.05, 0.03), Color(0.1, 0.1, 0.1))
	for hand in [[hour, 0.5, 0.09], [minute, 0.8, 0.06]]:
		var a2: float = TAU * float(hand[0]) / 12.0
		var d2: Vector3 = across * sin(a2) + Vector3.UP * cos(a2)
		var b2: Vector3 = c + out * 0.1 + d2 * r * float(hand[1])
		pk.beam(kit, "paint", c + out * 0.1, b2, float(hand[2]), 0.03, Color(0.08, 0.08, 0.08), d2.cross(out))


# ======================================================================================
#  The station
# ======================================================================================

## Labels are [text, position, outward normal, cap height, colour] in the kit's own (life size) units.
##
## Estación del Viento: x in [0, 40], the front (road) on z = 0 facing +z, the back (platform) on z = -12;
## plinth to y = 0.9, stucco walls to 5.9 under a gabled tile roof (ridge at y = 9.2 over z = -6), a clock tower on
## the ridge, a columned portico on the front, six shuttered windows a side, quoins, a cornice, two chimneys, and
## a long iron canopy over the platform on cast-iron columns. `labels` collects [text, position, outward normal,
## letter height, colour] for the generator to letter.
static func station(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	const L := 40.0
	const D := 12.0
	const PL := 0.9
	const WALL := 5.9
	const SLOPE := 0.55
	const OVER := 0.9
	var ridge_y: float = WALL + SLOPE * D * 0.5
	# Plinth and walls.
	blk(pk, kit, "stone", Vector3(-0.25, 0.0, -D - 0.25), Vector3(L + 0.25, PL, 0.25), STONE.lightened(0.18))
	wall(pk, kit, "plaster", Vector3(0, 0, 0), Vector3(L, 0, 0), PL, WALL, CREAM, Vector3(0, 0, 1))
	wall(pk, kit, "plaster", Vector3(L, 0, -D), Vector3(0, 0, -D), PL, WALL, CREAM, Vector3(0, 0, -1))
	wall(pk, kit, "plaster", Vector3(0, 0, -D), Vector3(0, 0, 0), PL, WALL, CREAM, Vector3(-1, 0, 0))
	wall(pk, kit, "plaster", Vector3(L, 0, 0), Vector3(L, 0, -D), PL, WALL, CREAM, Vector3(1, 0, 0))
	# Gable ends above the walls, with a round louvre in each.
	gable(pk, kit, "plaster", Vector3(0, WALL, -D), Vector3(0, WALL, 0), Vector3(0, ridge_y, -D * 0.5), CREAM, Vector3(-1, 0, 0))
	gable(pk, kit, "plaster", Vector3(L, WALL, 0), Vector3(L, WALL, -D), Vector3(L, ridge_y, -D * 0.5), CREAM, Vector3(1, 0, 0))
	for sx in [0.0, L]:
		var o: float = -1.0 if sx == 0.0 else 1.0
		pk.tube(kit, "painted", Vector3(sx, WALL + 1.45, -D * 0.5), Vector3(sx + o * 0.1, WALL + 1.45, -D * 0.5), 0.55, 0.55, 16, TRIM, true)
		pk.tube(kit, "glass", Vector3(sx + o * 0.08, WALL + 1.45, -D * 0.5), Vector3(sx + o * 0.12, WALL + 1.45, -D * 0.5), 0.42, 0.42, 16, GLASS_COL, true)
	# Quoins at the four corners: dressed blocks on both faces of the corner, standing 5cm proud of the plaster, laid
	# alternately long and short (a course long on the front is short on the end), from the plinth to under the
	# cornice. Each lies on its own wall from the corner inward; the front's wraps the corner.
	const PROUD := 0.05
	for cx in [0.0, L]:
		for cz in [0.0, -D]:
			var sxn: float = -1.0 if cx == 0.0 else 1.0    # out of the end wall, along x
			var szn: float = 1.0 if cz == 0.0 else -1.0    # out of the long wall, along z
			var y := PL + 0.04
			var k := 0
			while y + 0.5 <= WALL - 0.55:
				var on_long: float = 0.85 if k % 2 == 0 else 0.5
				var on_end: float = 0.5 if k % 2 == 0 else 0.85
				var x_a: float = cx + sxn * PROUD
				var x_b: float = cx - sxn * on_long
				blk(pk, kit, "plaster", Vector3(minf(x_a, x_b), y, minf(cz, cz + szn * PROUD)), Vector3(maxf(x_a, x_b), y + 0.5, maxf(cz, cz + szn * PROUD)), QUOIN)
				var z_b: float = cz - szn * on_end
				blk(pk, kit, "plaster", Vector3(minf(cx, cx + sxn * PROUD), y, minf(cz, z_b)), Vector3(maxf(cx, cx + sxn * PROUD), y + 0.5, maxf(cz, z_b)), QUOIN)
				y += 0.56
				k += 1
	blk(pk, kit, "stone", Vector3(-0.2, WALL - 0.5, 0.0), Vector3(L + 0.2, WALL - 0.2, 0.28), STONE.lightened(0.1))
	blk(pk, kit, "stone", Vector3(-0.2, WALL - 0.5, -D - 0.28), Vector3(L + 0.2, WALL - 0.2, 0.0), STONE.lightened(0.1))
	blk(pk, kit, "stone", Vector3(-0.28, WALL - 0.5, -D), Vector3(0.0, WALL - 0.2, 0.0), STONE.lightened(0.1))
	blk(pk, kit, "stone", Vector3(L, WALL - 0.5, -D), Vector3(L + 0.28, WALL - 0.2, 0.0), STONE.lightened(0.1))
	# The tile roof: two planes through the wall tops, overhanging the eaves by OVER and the ends by 0.7.
	var ez: float = OVER
	var ey: float = WALL - SLOPE * OVER
	roof(pk, kit, "tile", Vector3(-0.7, ey, ez), Vector3(L + 0.7, ey, ez), Vector3(L + 0.7, ridge_y, -D * 0.5), Vector3(-0.7, ridge_y, -D * 0.5), TERRACOTTA,
			Vector3(0.0, 1.0, SLOPE).normalized())
	roof(pk, kit, "tile", Vector3(L + 0.7, ey, -D - ez), Vector3(-0.7, ey, -D - ez), Vector3(-0.7, ridge_y, -D * 0.5), Vector3(L + 0.7, ridge_y, -D * 0.5), TERRACOTTA,
			Vector3(0.0, 1.0, -SLOPE).normalized())
	pk.beam(kit, "painted", Vector3(-0.8, ridge_y + 0.08, -D * 0.5), Vector3(L + 0.8, ridge_y + 0.08, -D * 0.5), 0.55, 0.3, TERRACOTTA.darkened(0.12), Vector3(0, 0, 1))
	# Eave boards and rake boards.
	for zz in [ez, -D - ez]:
		pk.beam(kit, "painted", Vector3(-0.8, ey - 0.05, zz), Vector3(L + 0.8, ey - 0.05, zz), 0.1, 0.34, TRIM, Vector3(0, 0, 1))
	for xx in [-0.7, L + 0.7]:
		pk.beam(kit, "painted", Vector3(xx, ey, ez), Vector3(xx, ridge_y, -D * 0.5), 0.26, 0.1, TRIM, Vector3(1, 0, 0))
		pk.beam(kit, "painted", Vector3(xx, ey, -D - ez), Vector3(xx, ridge_y, -D * 0.5), 0.26, 0.1, TRIM, Vector3(1, 0, 0))
	# Windows and doors: front.
	for wx in [3.5, 7.0, 10.5, 29.5, 33.0, 36.5]:
		window(pk, kit, Vector3(wx, 2.65, 0.0), Vector3(0, 0, 1), 1.4, 2.1, SHUTTER)
	for wx in [14.3, 25.7]:
		window(pk, kit, Vector3(wx, 2.65, 0.0), Vector3(0, 0, 1), 0.9, 2.1, SHUTTER)
	# Back: windows and three doors onto the platform.
	for wx in [3.5, 7.0, 10.5, 29.5, 33.0, 36.5]:
		window(pk, kit, Vector3(wx, 2.65, -D), Vector3(0, 0, -1), 1.4, 2.1, SHUTTER)
	for dx in [14.5, 20.0, 25.5]:
		door(pk, kit, Vector3(dx, PL, -D), Vector3(0, 0, -1), 1.8, 2.9, false)
	# The ends.
	window(pk, kit, Vector3(0.0, 2.65, -D * 0.5), Vector3(-1, 0, 0), 1.4, 2.1, SHUTTER)
	window(pk, kit, Vector3(L, 2.65, -D * 0.5), Vector3(1, 0, 0), 1.4, 2.1, SHUTTER)
	# Chimneys on the back slope.
	for cxm in [8.0, 32.0]:
		var base_y: float = WALL + SLOPE * (D * 0.5 - 2.3) - 0.4
		blk(pk, kit, "brick", Vector3(cxm - 0.55, base_y, -D * 0.5 - 2.8), Vector3(cxm + 0.55, ridge_y + 2.3, -D * 0.5 - 1.8), BRICK)
		blk(pk, kit, "stone", Vector3(cxm - 0.7, ridge_y + 2.3, -D * 0.5 - 2.95), Vector3(cxm + 0.7, ridge_y + 2.55, -D * 0.5 - 1.65), STONE)
		for fx in [-0.25, 0.25]:
			pk.tube(kit, "paint", Vector3(cxm + fx, ridge_y + 2.55, -D * 0.5 - 2.3), Vector3(cxm + fx, ridge_y + 3.0, -D * 0.5 - 2.3), 0.16, 0.14, 8, TERRACOTTA.darkened(0.1), true)
	# The portico: floor flush with the plinth, four columns to the entablature, a pedimented gable roof.
	var px0 := 17.0
	var px1 := 23.0
	blk(pk, kit, "stone", Vector3(px0 - 0.4, 0.0, 0.0), Vector3(px1 + 0.4, PL, 3.6), STONE)
	blk(pk, kit, "stone", Vector3(px0 - 0.8, 0.0, 3.6), Vector3(px1 + 0.8, 0.3, 4.4), STONE.lightened(0.05))
	blk(pk, kit, "stone", Vector3(px0 - 0.6, 0.3, 3.6), Vector3(px1 + 0.6, 0.6, 4.1), STONE.lightened(0.08))
	var cols: Array = [17.5, 19.17, 20.83, 22.5]
	var beam_y0 := 3.9
	var beam_y1 := 4.55
	for cx2 in cols:
		pk.tube(kit, "painted", Vector3(cx2, PL, 3.15), Vector3(cx2, beam_y0, 3.15), 0.26, 0.22, 14, TRIM, true, 1.0)
		pk.tube(kit, "painted", Vector3(cx2, PL, 3.15), Vector3(cx2, PL + 0.25, 3.15), 0.36, 0.36, 14, TRIM.darkened(0.04), true)
		blk(pk, kit, "painted", Vector3(cx2 - 0.34, beam_y0 - 0.22, 3.15 - 0.34), Vector3(cx2 + 0.34, beam_y0, 3.15 + 0.34), TRIM)
	blk(pk, kit, "painted", Vector3(px0 - 0.2, beam_y0, 2.8), Vector3(px1 + 0.2, beam_y1, 3.5), TRIM)
	for sx in [px0 - 0.1, px1 + 0.1]:
		blk(pk, kit, "painted", Vector3(sx - 0.15, beam_y0, 0.0), Vector3(sx + 0.15, beam_y1, 3.5), TRIM)
	var peak_y: float = beam_y1 + 1.25
	gable(pk, kit, "plaster", Vector3(px0 - 0.2, beam_y1, 3.5), Vector3(px1 + 0.2, beam_y1, 3.5), Vector3(20.0, peak_y, 3.5), CREAM.lightened(0.04), Vector3(0, 0, 1))
	var slope_p: float = (peak_y - beam_y1) / (3.0 + 0.2)
	roof(pk, kit, "tile", Vector3(px0 - 0.5, beam_y1 - slope_p * 0.3, 0.0), Vector3(px0 - 0.5, beam_y1 - slope_p * 0.3, 3.75), Vector3(20.0, peak_y + 0.05, 3.75), Vector3(20.0, peak_y + 0.05, 0.0), TERRACOTTA,
			Vector3(-(peak_y - beam_y1), 3.2, 0.0).normalized())
	roof(pk, kit, "tile", Vector3(px1 + 0.5, beam_y1 - slope_p * 0.3, 3.75), Vector3(px1 + 0.5, beam_y1 - slope_p * 0.3, 0.0), Vector3(20.0, peak_y + 0.05, 0.0), Vector3(20.0, peak_y + 0.05, 3.75), TERRACOTTA,
			Vector3((peak_y - beam_y1), 3.2, 0.0).normalized())
	door(pk, kit, Vector3(20.0, PL, 0.0), Vector3(0, 0, 1), 2.4, 3.1, false)
	# The clock tower on the ridge: stucco shaft, belfry louvres, a clock on each face, a cornice and a hipped roof.
	var tx0 := 17.4
	var tx1 := 22.6
	var tz0 := -D * 0.5 - 2.6
	var tz1 := -D * 0.5 + 2.6
	var ty0: float = ridge_y - 2.4
	var ty1 := 13.0
	wall(pk, kit, "plaster", Vector3(tx0, 0, tz1), Vector3(tx1, 0, tz1), ty0, ty1, CREAM, Vector3(0, 0, 1))
	wall(pk, kit, "plaster", Vector3(tx1, 0, tz0), Vector3(tx0, 0, tz0), ty0, ty1, CREAM, Vector3(0, 0, -1))
	wall(pk, kit, "plaster", Vector3(tx0, 0, tz0), Vector3(tx0, 0, tz1), ty0, ty1, CREAM, Vector3(-1, 0, 0))
	wall(pk, kit, "plaster", Vector3(tx1, 0, tz1), Vector3(tx1, 0, tz0), ty0, ty1, CREAM, Vector3(1, 0, 0))
	var tc := Vector3(20.0, 0.0, -D * 0.5)
	for face in [[Vector3(0, 0, 1), tz1], [Vector3(0, 0, -1), tz0], [Vector3(-1, 0, 0), tx0], [Vector3(1, 0, 0), tx1]]:
		var o: Vector3 = face[0]
		var at: Vector3 = tc + o * (absf(float(face[1]) - (tc.z if absf(o.z) > 0.5 else tc.x)))
		clock_face(pk, kit, Vector3(at.x, 11.1, at.z), o, 1.1)
		# A louvred belfry opening above the clock.
		var ac: Vector3 = o.cross(Vector3.UP).normalized()
		var bas := Basis(ac, Vector3.UP, o)
		box_at(pk, kit, "painted", Vector3(at.x, 12.1, at.z) + o * 0.04, bas, Vector3(1.0, 0.7, 0.06), Color(0.05, 0.05, 0.06))
		for lk in range(4):
			box_at(pk, kit, "painted", Vector3(at.x, 11.85 + 0.15 * float(lk), at.z) + o * 0.07, bas, Vector3(0.9, 0.03, 0.05), TRIM.darkened(0.2))
		# A string course below the clock.
		box_at(pk, kit, "stone", Vector3(at.x, ty0 + 0.0, at.z) + o * 0.0 + Vector3(0, 9.5 - ty0 + 0.0, 0), bas, Vector3(5.5, 0.22, 0.2), STONE.lightened(0.08))
	blk(pk, kit, "stone", Vector3(tx0 - 0.35, ty1, tz0 - 0.35), Vector3(tx1 + 0.35, ty1 + 0.4, tz1 + 0.35), STONE.lightened(0.08))
	var apex := Vector3(20.0, ty1 + 0.4 + 3.4, -D * 0.5)
	var ex0 := tx0 - 0.35
	var ex1 := tx1 + 0.35
	var ez0: float = tz0 - 0.35
	var ez1: float = tz1 + 0.35
	var by: float = ty1 + 0.4
	gable(pk, kit, "tile", Vector3(ex0, by, ez1), Vector3(ex1, by, ez1), apex, TERRACOTTA, Vector3(0, 3.4, 3.0).normalized())
	gable(pk, kit, "tile", Vector3(ex1, by, ez0), Vector3(ex0, by, ez0), apex, TERRACOTTA, Vector3(0, 3.4, -3.0).normalized())
	gable(pk, kit, "tile", Vector3(ex0, by, ez0), Vector3(ex0, by, ez1), apex, TERRACOTTA, Vector3(-3.0, 3.4, 0).normalized())
	gable(pk, kit, "tile", Vector3(ex1, by, ez1), Vector3(ex1, by, ez0), apex, TERRACOTTA, Vector3(3.0, 3.4, 0).normalized())
	pk.tube(kit, "steel", apex, apex + Vector3(0, 1.4, 0), 0.07, 0.04, 8, CAST, true)
	pk.lathe(kit, "steel", apex + Vector3(0, 0.5, 0), [Vector2(0.001, -0.18), Vector2(0.18, 0.0), Vector2(0.001, 0.18)], 10, Color(0.78, 0.62, 0.25), false)
	pk.beam(kit, "steel", apex + Vector3(-0.7, 1.15, 0), apex + Vector3(0.7, 1.15, 0), 0.05, 0.25, CAST, Vector3(0, 0, 1))
	# The platform canopy: an iron roof from the back wall to a girder on cast-iron columns, brackets between them.
	canopy(pk, kit, 1.0, 39.0, -D, 4.9)
	# The name across the portico's entablature (a navy board with cream letters) and on the platform side.
	box_at(pk, kit, "paint", Vector3(20.0, 4.225, 3.53), Basis(), Vector3(5.7, 0.55, 0.05), Color(0.08, 0.20, 0.42))
	labels.append(["ESTACION DEL VIENTO", Vector3(20.0, 4.225, 3.57), Vector3(0, 0, 1), 0.3, Color(0.96, 0.94, 0.86)])
	labels.append(["ESTACION DEL VIENTO", Vector3(20.0, 5.18, -D - 0.32), Vector3(0, 0, -1), 0.3, Color(0.95, 0.92, 0.82)])


## A canopy: x in [x0, x1], from the wall at z = wall_z (the roof's top edge at y = wall_y) out `depth` toward `dir`
## (-1 toward -z, as on the platform side; +1 toward +z), the roof falling `drop` over it, on cast-iron columns every 4m
## from `floor_y` (the platform's top) up to a girder under the roof's outer end; the roof (corrugated iron) rests on the
## girder, which rests on the columns, with brackets, a scalloped valance, a gutter and downpipes.
const PLATFORM_Y := 0.69

static func canopy(pk: PropKit, kit: Dictionary, x0: float, x1: float, wall_z: float, wall_y: float, depth := 6.45, drop := 0.8, dir := -1.0, floor_y := PLATFORM_Y) -> void:
	var out_z: float = wall_z + dir * depth
	var eave_y: float = wall_y - drop
	var slope: float = (wall_y - eave_y) / depth
	var nrm := Vector3(0.0, depth, dir * drop).normalized()
	roof(pk, kit, "iron", Vector3(x0 - 0.6, eave_y, out_z), Vector3(x1 + 0.6, eave_y, out_z), Vector3(x1 + 0.6, wall_y, wall_z), Vector3(x0 - 0.6, wall_y, wall_z), IRON_GREEN, nrm)
	# Under the roof: a flat soffit so the underside is not see-through.
	pk.quad(kit, "paint", [Vector3(x0 - 0.6, eave_y - 0.03, out_z), Vector3(x0 - 0.6, wall_y - 0.03, wall_z), Vector3(x1 + 0.6, wall_y - 0.03, wall_z), Vector3(x1 + 0.6, eave_y - 0.03, out_z)],
			Vector3.DOWN, Color(0.80, 0.78, 0.70))
	# The girder under the roof's outer end: an I-beam, its top touching the roof plane.
	var gz: float = out_z - dir * 0.25
	var gy_top: float = eave_y + slope * 0.25 - 0.04
	blk(pk, kit, "steel", Vector3(x0 - 0.5, gy_top - 0.62, gz - 0.05), Vector3(x1 + 0.5, gy_top - 0.06, gz + 0.05), IRON_GREEN.darkened(0.2))
	blk(pk, kit, "steel", Vector3(x0 - 0.5, gy_top - 0.06, gz - 0.2), Vector3(x1 + 0.5, gy_top, gz + 0.2), IRON_GREEN.darkened(0.25))
	blk(pk, kit, "steel", Vector3(x0 - 0.5, gy_top - 0.68, gz - 0.2), Vector3(x1 + 0.5, gy_top - 0.62, gz + 0.2), IRON_GREEN.darkened(0.25))
	var col_top: float = gy_top - 0.68
	var x := x0
	while x <= x1 + 0.01:
		# Column: foot, shaft, collar and capital up to the girder's underside.
		var c := Vector3(x, floor_y, gz)
		pk.tube(kit, "steel", c, c + Vector3(0, 0.45, 0), 0.24, 0.15, 12, CAST, true)
		pk.tube(kit, "steel", c + Vector3(0, 0.45, 0), Vector3(x, col_top - 0.3, gz), 0.12, 0.1, 12, CAST, false)
		pk.tube(kit, "steel", Vector3(x, col_top - 0.3, gz), Vector3(x, col_top, gz), 0.2, 0.16, 12, CAST, true)
		blk(pk, kit, "steel", Vector3(x - 0.24, col_top - 0.04, gz - 0.24), Vector3(x + 0.24, col_top + 0.02, gz + 0.24), CAST)
		# Brackets: a pair of braces from the shaft up to the girder either side, and a scroll.
		for sx in [-1.0, 1.0]:
			pk.beam(kit, "steel", Vector3(x, col_top - 0.55, gz), Vector3(x + sx * 0.95, col_top, gz), 0.07, 0.07, CAST, Vector3(0, 0, 1))
			pk.tube(kit, "steel", Vector3(x + sx * 0.5, col_top - 0.22, gz - 0.05), Vector3(x + sx * 0.5, col_top - 0.22, gz + 0.05), 0.2, 0.2, 10, CAST, false)
		x += 4.0
	# The valance along the front edge, hanging below the girder: a board with a scalloped lower edge.
	var vy_top: float = gy_top - 0.02
	var vz: float = out_z + dir * 0.0
	blk(pk, kit, "painted", Vector3(x0 - 0.6, vy_top - 0.34, vz - 0.06 if dir < 0.0 else vz - 0.02), Vector3(x1 + 0.6, vy_top, vz + 0.02 if dir < 0.0 else vz + 0.06), TRIM)
	var vx := x0 - 0.5
	var nz := Vector3(0, 0, dir)
	var fz: float = vz + dir * 0.07
	while vx < x1 + 0.5:
		pk.tri(kit, "painted", Vector3(vx, vy_top - 0.34, fz), Vector3(vx + 0.5, vy_top - 0.34, fz), Vector3(vx + 0.25, vy_top - 0.62, fz), nz, nz, nz, TRIM, nz)
		vx += 0.5
	# Gutter and downpipes at every other column.
	pk.tube(kit, "steel", Vector3(x0 - 0.6, eave_y - 0.06, out_z + dir * 0.1), Vector3(x1 + 0.6, eave_y - 0.06, out_z + dir * 0.1), 0.07, 0.07, 8, CAST, true)
	var dx := x0
	while dx <= x1 + 0.01:
		pk.tube(kit, "steel", Vector3(dx + 0.17, eave_y - 0.06, out_z + dir * 0.12), Vector3(dx + 0.17, floor_y, out_z + dir * 0.12), 0.05, 0.05, 6, CAST, true)
		dx += 8.0


# ======================================================================================
#  Steel details shared by the buildings
# ======================================================================================

## A guard rail along a to b: posts about every 1.4m, a top and a mid rail, a toe board.
static func railing(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, h := 1.1, col := Color(0.24, 0.27, 0.28)) -> void:
	var d: Vector3 = b - a
	var n: int = maxi(int(ceil(d.length() / 1.4)), 1)
	for i in range(n + 1):
		var p: Vector3 = a + d * (float(i) / float(n))
		pk.beam(kit, "steel", p, p + Vector3(0, h, 0), 0.05, 0.05, col)
	pk.beam(kit, "steel", a + Vector3(0, h, 0), b + Vector3(0, h, 0), 0.06, 0.05, col, Vector3.UP)
	pk.beam(kit, "steel", a + Vector3(0, h * 0.5, 0), b + Vector3(0, h * 0.5, 0), 0.04, 0.04, col, Vector3.UP)
	pk.beam(kit, "steel", a + Vector3(0, 0.02, 0), b + Vector3(0, 0.02, 0), 0.14, 0.025, col.darkened(0.1), Vector3.UP)


## A vertical ladder from `base` up to `top` (the same x and z) on a wall that faces `out`: two rails and rungs every
## 0.3m, with a cage of half-hoops and straps from 2.2m up when `cage`.
static func ladder(pk: PropKit, kit: Dictionary, base: Vector3, top: Vector3, out: Vector3, cage := false, col := CAST) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var stand := out * 0.14
	for sx in [-1.0, 1.0]:
		var o: Vector3 = across * (sx * 0.23) + stand
		pk.beam(kit, "steel", base + o, top + o, 0.05, 0.05, col)
	var y := base.y + 0.25
	while y < top.y - 0.1:
		pk.beam(kit, "steel", Vector3(base.x, y, base.z) + across * -0.23 + stand, Vector3(base.x, y, base.z) + across * 0.23 + stand, 0.035, 0.035, col)
		y += 0.3
	if not cage:
		return
	var hy: float = base.y + 2.2
	while hy < top.y - 0.2:
		var prev := Vector3.ZERO
		for k in range(9):
			var t: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 8.0)
			var p: Vector3 = Vector3(base.x, hy, base.z) + out * (0.14 + 0.5 * cos(t)) + across * (0.5 * sin(t))
			if k > 0:
				pk.beam(kit, "steel", prev, p, 0.03, 0.03, col)
			prev = p
		hy += 0.9
	for t2 in [-0.6, 0.0, 0.6]:
		var o2: Vector3 = out * (0.14 + 0.5 * cos(t2)) + across * (0.5 * sin(t2))
		pk.beam(kit, "steel", Vector3(base.x, base.y + 2.2, base.z) + o2, Vector3(top.x, top.y - 0.3, top.z) + o2, 0.03, 0.03, col)


## An I-beam along a to b with its top flange on the line: web `depth` tall, flanges `flange` wide.
static func girder(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, depth := 0.4, flange := 0.2, col := Color(0.24, 0.27, 0.28)) -> void:
	pk.beam(kit, "steel", a + Vector3(0, -depth * 0.5, 0), b + Vector3(0, -depth * 0.5, 0), depth, 0.03, col, Vector3.UP)
	pk.beam(kit, "steel", a + Vector3(0, -0.015, 0), b + Vector3(0, -0.015, 0), 0.03, flange, col, Vector3.UP)
	pk.beam(kit, "steel", a + Vector3(0, -depth + 0.015, 0), b + Vector3(0, -depth + 0.015, 0), 0.03, flange, col, Vector3.UP)


## A square steel column from the ground (or `y0`) to `y1`, hollow-section sized `w`.
static func column(pk: PropKit, kit: Dictionary, p: Vector3, y0: float, y1: float, w := 0.4, col := Color(0.24, 0.27, 0.28)) -> void:
	blk(pk, kit, "steel", Vector3(p.x - w * 0.5, y0, p.z - w * 0.5), Vector3(p.x + w * 0.5, y1, p.z + w * 0.5), col)
	blk(pk, kit, "steel", Vector3(p.x - w * 0.5 - 0.06, y0, p.z - w * 0.5 - 0.06), Vector3(p.x + w * 0.5 + 0.06, y0 + 0.08, p.z + w * 0.5 + 0.06), col.darkened(0.15))


## A blue enamel name board on two posts: `c` the middle of its foot on the ground, facing `out` (axis-aligned).
static func name_board(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, text: String, labels: Array) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "steel", c + across * (sx * (w * 0.5 - 0.2)), c + across * (sx * (w * 0.5 - 0.2)) + Vector3(0, 2.4, 0), 0.07, 0.06, 8, CAST, true)
	var mid: Vector3 = c + Vector3(0, 1.85, 0)
	box_at(pk, kit, "paint", mid + out * 0.05, basis, Vector3(w + 0.1, 0.72, 0.08), Color(0.92, 0.92, 0.88))
	box_at(pk, kit, "paint", mid + out * 0.1, basis, Vector3(w - 0.06, 0.62, 0.04), Color(0.08, 0.20, 0.42))
	labels.append([text, mid + out * 0.135, out, 0.22, Color(0.96, 0.96, 0.92)])


## A platform clock hung by a bracket from a point `p` on a girder, double faced along ±x.
static func hung_clock(pk: PropKit, kit: Dictionary, p: Vector3, drop := 0.9, r := 0.5) -> void:
	pk.beam(kit, "steel", p, p + Vector3(0, -drop, 0), 0.06, 0.06, CAST)
	var c: Vector3 = p + Vector3(0, -drop - r - 0.05, 0)
	clock_face(pk, kit, c + Vector3(0.14, 0, 0), Vector3(1, 0, 0), r)
	clock_face(pk, kit, c - Vector3(0.14, 0, 0), Vector3(-1, 0, 0), r, 10.1, 8.6)
	blk(pk, kit, "steel", c + Vector3(-0.14, -r - 0.05, -0.06), c + Vector3(0.14, r + 0.05, 0.06), CAST)
	pk.beam(kit, "steel", p + Vector3(0, -drop, 0), c + Vector3(0, r + 0.04, 0), 0.06, 0.06, CAST)


## A milk churn: a tapering can with a neck, shoulder, lid and two handles; `p` on the ground.
static func churn(pk: PropKit, kit: Dictionary, p: Vector3, col := Color(0.70, 0.71, 0.72)) -> void:
	pk.lathe(kit, "steel", p, [Vector2(0.001, 0.0), Vector2(0.2, 0.0), Vector2(0.22, 0.12), Vector2(0.2, 0.62), Vector2(0.15, 0.78), Vector2(0.12, 0.9), Vector2(0.15, 0.95), Vector2(0.001, 0.99)], 12, col, false)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", p + Vector3(sx * 0.12, 0.8, 0), p + Vector3(sx * 0.24, 0.62, 0), 0.04, 0.04, col.darkened(0.2))


## A wooden crate (or a stack of two) with battens, `p` the middle of its base. The battens stand 2.5cm proud of the
## boards on every face: flush with the sides, they shared their planes and flickered.
static func crate(pk: PropKit, kit: Dictionary, p: Vector3, yaw: float, size: Vector3, col := Color(0.54, 0.40, 0.26)) -> void:
	var basis := Basis(Vector3.UP, yaw)
	box_at(pk, kit, "timber", p + Vector3(0, size.y * 0.5, 0), basis, size, col)
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "timber", p + basis * Vector3(sx * (size.x * 0.5 - 0.015), size.y * 0.5, 0), basis, Vector3(0.08, size.y + 0.03, size.z + 0.05), col.darkened(0.2))
	box_at(pk, kit, "timber", p + Vector3(0, size.y + 0.01, 0), basis, Vector3(size.x + 0.02, 0.04, 0.08), col.darkened(0.2))


## A drum with two rolling hoops, `p` on the ground.
static func drum(pk: PropKit, kit: Dictionary, p: Vector3, col: Color, h := 0.9, r := 0.3) -> void:
	pk.tube(kit, "paint", p, p + Vector3(0, h, 0), r, r, 14, col, true)
	for y in [h * 0.28, h * 0.72]:
		pk.tube(kit, "paint", p + Vector3(0, y - 0.02, 0), p + Vector3(0, y + 0.02, 0), r + 0.012, r + 0.012, 14, col.darkened(0.25), false)
	pk.tube(kit, "paint", p + Vector3(0, h, 0), p + Vector3(0, h + 0.03, 0), r - 0.02, r - 0.03, 14, col.darkened(0.35), true)


## A luggage trolley: a wooden bed on four iron wheels with a handle, `p` the middle of its base, `yaw` about y.
static func trolley(pk: PropKit, kit: Dictionary, p: Vector3, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	box_at(pk, kit, "timber", p + basis * Vector3(0, 0.55, 0), basis, Vector3(0.7, 0.07, 1.7), Color(0.46, 0.32, 0.20))
	for sz in [-0.65, 0.65]:
		for sx in [-0.33, 0.33]:
			pk.tube(kit, "steel", p + basis * Vector3(sx - 0.03, 0.2, sz), p + basis * Vector3(sx + 0.03, 0.2, sz), 0.2, 0.2, 12, CAST, true)
	pk.beam(kit, "steel", p + basis * Vector3(-0.33, 0.55, 0.85), p + basis * Vector3(-0.33, 1.15, 1.0), 0.04, 0.04, CAST)
	pk.beam(kit, "steel", p + basis * Vector3(0.33, 0.55, 0.85), p + basis * Vector3(0.33, 1.15, 1.0), 0.04, 0.04, CAST)
	pk.beam(kit, "steel", p + basis * Vector3(-0.33, 1.15, 1.0), p + basis * Vector3(0.33, 1.15, 1.0), 0.04, 0.04, CAST)
	# Two trunks and a hat box.
	box_at(pk, kit, "timber", p + basis * Vector3(-0.1, 0.84, -0.35), basis, Vector3(0.6, 0.5, 0.42), Color(0.30, 0.20, 0.14))
	box_at(pk, kit, "steel", p + basis * Vector3(-0.1, 0.84, -0.35), basis, Vector3(0.62, 0.05, 0.44), Color(0.55, 0.45, 0.25))
	box_at(pk, kit, "timber", p + basis * Vector3(0.05, 0.78, 0.25), basis, Vector3(0.5, 0.38, 0.34), Color(0.40, 0.26, 0.16))
	pk.tube(kit, "paint", p + basis * Vector3(0.05, 0.97, 0.25), p + basis * Vector3(0.05, 1.12, 0.25), 0.17, 0.17, 12, Color(0.62, 0.52, 0.34), true)


# ======================================================================================
#  The platform
# ======================================================================================

## The platform behind the station: x in [x0, x1], from the building's back wall (z_wall) out to the edge (z_edge,
## further negative), its top at PLATFORM_Y. A stone-faced edge with a concrete coping and a yellow safety line, joints
## every 4m, a ramp down at each end (`ramp_w` / `ramp_e`), and the furniture: benches against the wall, lamp posts
## along it, a name board at each end, a trolley, churns and crates.
static func platform(pk: PropKit, kit: Dictionary, x0: float, x1: float, z_wall: float, z_edge: float, ramp_w: bool, ramp_e: bool, labels: Array) -> void:
	var top := PLATFORM_Y
	var asphalt := Color(0.30, 0.30, 0.31)
	pk.quad(kit, "matte", [Vector3(x0, top, z_wall), Vector3(x1, top, z_wall), Vector3(x1, top, z_edge), Vector3(x0, top, z_edge)], Vector3.UP, asphalt)
	wall(pk, kit, "stone", Vector3(x0, 0, z_edge), Vector3(x1, 0, z_edge), 0.0, top, STONE.darkened(0.04), Vector3(0, 0, -1))
	# Coping along the edge, and the line behind it.
	blk(pk, kit, "concrete", Vector3(x0, top, z_edge - 0.08), Vector3(x1, top + 0.1, z_edge + 0.5), CONCRETE.lightened(0.05))
	# The line and the slab joints stand 1.2cm (2cm grown) over what they lie on: at 3mm they flickered from afar.
	pk.quad(kit, "paint", [Vector3(x0, top + 0.112, z_edge + 0.62), Vector3(x1, top + 0.112, z_edge + 0.62), Vector3(x1, top + 0.112, z_edge + 0.78), Vector3(x0, top + 0.112, z_edge + 0.78)],
			Vector3.UP, Color(0.95, 0.80, 0.14))
	# The surface is laid in slabs.
	var x := x0 + 4.0
	while x < x1 - 0.1:
		pk.quad(kit, "paint", [Vector3(x - 0.012, top + 0.012, z_wall), Vector3(x + 0.012, top + 0.012, z_wall), Vector3(x + 0.012, top + 0.012, z_edge + 0.5), Vector3(x - 0.012, top + 0.012, z_edge + 0.5)],
				Vector3.UP, Color(0.17, 0.17, 0.18))
		x += 4.0
	var zm: float = (z_wall + z_edge) * 0.5
	pk.quad(kit, "paint", [Vector3(x0, top + 0.014, zm - 0.012), Vector3(x1, top + 0.014, zm - 0.012), Vector3(x1, top + 0.014, zm + 0.012), Vector3(x0, top + 0.014, zm + 0.012)], Vector3.UP, Color(0.17, 0.17, 0.18))
	# Ramps: a sloped surface over the full depth with a stone cheek each side.
	for end in [[ramp_w, x0, -1.0], [ramp_e, x1, 1.0]]:
		if not end[0]:
			continue
		var xe: float = end[1]
		var sg: float = end[2]
		var xr: float = xe + sg * 7.0
		pk.quad(kit, "matte", [Vector3(xe, top, z_wall), Vector3(xr, 0.0, z_wall), Vector3(xr, 0.0, z_edge), Vector3(xe, top, z_edge)], Vector3(sg * top, 7.0, 0.0).normalized(), asphalt)
		for zz in [z_wall, z_edge]:
			var zo: float = 1.0 if zz == z_wall else -1.0
			pk.tri(kit, "stone", Vector3(xe, 0, zz), Vector3(xr, 0, zz), Vector3(xe, top, zz), Vector3(0, 0, zo), Vector3(0, 0, zo), Vector3(0, 0, zo), STONE.darkened(0.04), Vector3(0, 0, zo),
					Vector2(0, 0), Vector2(7.0, 0) * uvk, Vector2(0, top) * uvk)
	# The back of the slab where there is no wall (the freight shed's front is its own).
	# Furniture.
	var span: float = x1 - x0
	var nb: int = int(floor(span / 24.0))
	for k in range(nb):
		var bx: float = x0 + span * (float(k) + 0.5) / float(nb)
		bench(pk, kit, Vector3(bx + 6.0, top, z_wall - 0.55), Vector3(0, 0, -1))
		lamp_post(pk, kit, Vector3(bx - 5.0, top, z_edge + 3.0), 3.7)
	name_board(pk, kit, Vector3(x0 + 9.0, top, z_edge + 1.4), Vector3(0, 0, -1), 3.6, "ESTACION DEL VIENTO", labels)
	name_board(pk, kit, Vector3(x1 - 9.0, top, z_edge + 1.4), Vector3(0, 0, -1), 3.6, "ESTACION DEL VIENTO", labels)
	# A pillar box, a notice board and a bin by the station's doors.
	var tx: float = x0 + span * 0.5
	trolley(pk, kit, Vector3(tx - 11.0, top, z_wall - 2.2), 0.15)
	for k in range(3):
		churn(pk, kit, Vector3(tx - 14.0 + 0.5 * float(k), top, z_wall - 1.0 + 0.18 * float(k % 2)))
	crate(pk, kit, Vector3(tx + 13.0, top, z_wall - 1.0), 0.2, Vector3(0.9, 0.6, 0.6))
	crate(pk, kit, Vector3(tx + 13.1, top + 0.6, z_wall - 1.0), -0.3, Vector3(0.7, 0.5, 0.5))
	crate(pk, kit, Vector3(tx + 14.2, top, z_wall - 1.1), -0.1, Vector3(0.8, 0.55, 0.6), Color(0.46, 0.34, 0.22))


# ======================================================================================
#  The goods shed
# ======================================================================================

const SHED_RED := Color(0.45, 0.17, 0.13)
const SHED_ROOF := Color(0.34, 0.33, 0.31)

## A sliding door on its track: a leaf of boards in a frame with a Z brace, hung from a rail along the wall; `c` the
## middle of the sill on the wall's face, `out` the wall's outward normal.
static func sliding_door(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, col := Color(0.46, 0.56, 0.48)) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	box_at(pk, kit, "painted", c + Vector3(0, h * 0.5, 0) + out * 0.08, basis, Vector3(w, h, 0.07), col)
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "painted", c + across * (sx * (w * 0.5 - 0.1)) + Vector3(0, h * 0.5, 0) + out * 0.13, basis, Vector3(0.2, h, 0.05), col.lightened(0.12))
	for y in [0.14, h * 0.5, h - 0.14]:
		box_at(pk, kit, "painted", c + Vector3(0, y, 0) + out * 0.13, basis, Vector3(w, 0.2, 0.05), col.lightened(0.12))
	var d: Vector3 = Vector3(across.x * (w * 0.5 - 0.1), 0.0, across.z * (w * 0.5 - 0.1))
	pk.beam(kit, "painted", c - d + Vector3(0, 0.2, 0) + out * 0.14, c + d + Vector3(0, h - 0.2, 0) + out * 0.14, 0.2, 0.05, col.lightened(0.12), out)
	# The rail over it, two hangers and the stop at the end.
	var rail_y: float = h + 0.35
	pk.beam(kit, "steel", c - across * (w * 1.1) + Vector3(0, rail_y, 0) + out * 0.2, c + across * (w * 1.1) + Vector3(0, rail_y, 0) + out * 0.2, 0.1, 0.07, CAST, Vector3.UP)
	for sx in [-0.35, 0.35]:
		pk.beam(kit, "steel", c + across * (sx * w) + Vector3(0, h, 0) + out * 0.2, c + across * (sx * w) + Vector3(0, rail_y, 0) + out * 0.2, 0.05, 0.05, CAST)
		pk.tube(kit, "steel", c + across * (sx * w) + Vector3(0, rail_y - 0.06, 0) + out * 0.14, c + across * (sx * w) + Vector3(0, rail_y - 0.06, 0) + out * 0.26, 0.09, 0.09, 10, CAST, true)
	# The door's frame and a lintel board.
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "painted", c + across * (sx * (w * 0.5 + 0.12)) + Vector3(0, h * 0.5, 0) + out * 0.05, basis, Vector3(0.2, h, 0.08), TRIM)
	box_at(pk, kit, "painted", c + Vector3(0, h + 0.05, 0) + out * 0.05, basis, Vector3(w + 0.5, 0.2, 0.08), TRIM)


## Estación del Viento's goods shed: x in [x0, x1], z in [-12, 0] like the station (front on z = 0): red weatherboard
## walls on a stone plinth, a corrugated iron gable roof with a ridge lantern, sliding doors and a deep loading canopy on
## the platform side, windows and a loading door on the road side.
static func goods_shed(pk: PropKit, kit: Dictionary, x0: float, x1: float, labels: Array) -> void:
	const D := 12.0
	const PL := 0.5
	const WALL := 4.6
	const PITCH := 0.45
	var ridge: float = WALL + PITCH * D * 0.5
	blk(pk, kit, "stone", Vector3(x0 - 0.15, 0.0, -D - 0.15), Vector3(x1 + 0.15, PL, 0.15), STONE)
	wall(pk, kit, "lapboards", Vector3(x0, 0, 0), Vector3(x1, 0, 0), PL, WALL, SHED_RED, Vector3(0, 0, 1))
	wall(pk, kit, "lapboards", Vector3(x1, 0, -D), Vector3(x0, 0, -D), PL, WALL, SHED_RED, Vector3(0, 0, -1))
	wall(pk, kit, "lapboards", Vector3(x0, 0, -D), Vector3(x0, 0, 0), PL, WALL, SHED_RED, Vector3(-1, 0, 0))
	wall(pk, kit, "lapboards", Vector3(x1, 0, 0), Vector3(x1, 0, -D), PL, WALL, SHED_RED, Vector3(1, 0, 0))
	gable(pk, kit, "lapboards", Vector3(x0, WALL, -D), Vector3(x0, WALL, 0), Vector3(x0, ridge, -D * 0.5), SHED_RED, Vector3(-1, 0, 0))
	gable(pk, kit, "lapboards", Vector3(x1, WALL, 0), Vector3(x1, WALL, -D), Vector3(x1, ridge, -D * 0.5), SHED_RED, Vector3(1, 0, 0))
	# Corner boards.
	for cx in [x0, x1]:
		for cz in [0.0, -D]:
			var sxn: float = -1.0 if cx == x0 else 1.0
			var szn: float = 1.0 if cz == 0.0 else -1.0
			blk(pk, kit, "painted", Vector3(minf(cx, cx + sxn * 0.2), PL, minf(cz, cz + szn * 0.2)), Vector3(maxf(cx, cx + sxn * 0.2), WALL, maxf(cz, cz + szn * 0.2)), TRIM.darkened(0.04))
	# The roof: planes through the wall tops, overhanging the eaves by 0.7 and the ends by 0.6.
	var oh := 0.7
	var ey: float = WALL - PITCH * oh
	roof(pk, kit, "iron", Vector3(x0 - 0.6, ey, oh), Vector3(x1 + 0.6, ey, oh), Vector3(x1 + 0.6, ridge, -D * 0.5), Vector3(x0 - 0.6, ridge, -D * 0.5), SHED_ROOF, Vector3(0.0, 1.0, PITCH).normalized())
	roof(pk, kit, "iron", Vector3(x1 + 0.6, ey, -D - oh), Vector3(x0 - 0.6, ey, -D - oh), Vector3(x0 - 0.6, ridge, -D * 0.5), Vector3(x1 + 0.6, ridge, -D * 0.5), SHED_ROOF, Vector3(0.0, 1.0, -PITCH).normalized())
	pk.beam(kit, "steel", Vector3(x0 - 0.7, ridge + 0.06, -D * 0.5), Vector3(x1 + 0.7, ridge + 0.06, -D * 0.5), 0.5, 0.22, SHED_ROOF.darkened(0.25), Vector3(0, 0, 1))
	for zz in [oh, -D - oh]:
		pk.beam(kit, "painted", Vector3(x0 - 0.7, ey - 0.04, zz), Vector3(x1 + 0.7, ey - 0.04, zz), 0.1, 0.3, TRIM, Vector3(0, 0, 1))
	for xx in [x0 - 0.6, x1 + 0.6]:
		pk.beam(kit, "painted", Vector3(xx, ey, oh), Vector3(xx, ridge, -D * 0.5), 0.22, 0.09, TRIM, Vector3(1, 0, 0))
		pk.beam(kit, "painted", Vector3(xx, ey, -D - oh), Vector3(xx, ridge, -D * 0.5), 0.22, 0.09, TRIM, Vector3(1, 0, 0))
	# The ridge lantern: louvred sides on the roof planes, a small gable of iron over it.
	var lx0: float = (x0 + x1) * 0.5 - 5.0
	var lx1: float = (x0 + x1) * 0.5 + 5.0
	var lz: float = 0.85
	var ly0: float = ridge - PITCH * lz
	var ly1: float = ridge + 0.95
	for sg in [-1.0, 1.0]:
		pk.quad(kit, "painted", [Vector3(lx0, ly0, -D * 0.5 + sg * lz), Vector3(lx1, ly0, -D * 0.5 + sg * lz), Vector3(lx1, ly1, -D * 0.5 + sg * lz), Vector3(lx0, ly1, -D * 0.5 + sg * lz)],
				Vector3(0, 0, sg), SHED_RED.darkened(0.3))
		var yy: float = ly0 + 0.12
		while yy < ly1 - 0.1:
			pk.beam(kit, "painted", Vector3(lx0 + 0.1, yy, -D * 0.5 + sg * (lz + 0.03)), Vector3(lx1 - 0.1, yy, -D * 0.5 + sg * (lz + 0.03)), 0.05, 0.1, TRIM.darkened(0.25), Vector3.UP)
			yy += 0.16
	for xx in [lx0, lx1]:
		var nx: float = -1.0 if xx == lx0 else 1.0
		pk.quad(kit, "painted", [Vector3(xx, ly0, -D * 0.5 - lz), Vector3(xx, ly0, -D * 0.5 + lz), Vector3(xx, ly1, -D * 0.5 + lz), Vector3(xx, ly1, -D * 0.5 - lz)], Vector3(nx, 0, 0), SHED_RED.darkened(0.3))
	var peak: float = ly1 + 0.35
	roof(pk, kit, "iron", Vector3(lx0 - 0.3, ly1, -D * 0.5 + lz + 0.3), Vector3(lx1 + 0.3, ly1, -D * 0.5 + lz + 0.3), Vector3(lx1 + 0.3, peak, -D * 0.5), Vector3(lx0 - 0.3, peak, -D * 0.5), SHED_ROOF,
			Vector3(0, 1.0, 0.8).normalized())
	roof(pk, kit, "iron", Vector3(lx1 + 0.3, ly1, -D * 0.5 - lz - 0.3), Vector3(lx0 - 0.3, ly1, -D * 0.5 - lz - 0.3), Vector3(lx0 - 0.3, peak, -D * 0.5), Vector3(lx1 + 0.3, peak, -D * 0.5), SHED_ROOF,
			Vector3(0, 1.0, -0.8).normalized())
	# Road side: windows, a loading door with steps.
	var wxs: Array = [x0 + 3.0, x0 + 6.5, x1 - 6.5, x1 - 3.0]
	for wx in wxs:
		window(pk, kit, Vector3(wx, 2.55, 0.0), Vector3(0, 0, 1), 1.0, 1.5, SHUTTER)
	var mid: float = (x0 + x1) * 0.5
	door(pk, kit, Vector3(mid, PL, 0.0), Vector3(0, 0, 1), 2.2, 2.9, true)
	labels.append(["MERCANCIAS", Vector3(mid, 4.05, 0.07), Vector3(0, 0, 1), 0.3, Color(0.95, 0.92, 0.82)])
	# The platform side: two sliding doors and a window between them, the canopy in front.
	var d1: float = x0 + 6.5
	var d2: float = x1 - 6.5
	sliding_door(pk, kit, Vector3(d1, PL, -D), Vector3(0, 0, -1), 3.4, 3.4)
	sliding_door(pk, kit, Vector3(d2, PL, -D), Vector3(0, 0, -1), 3.4, 3.4)
	window(pk, kit, Vector3(mid, 2.55, -D), Vector3(0, 0, -1), 1.0, 1.5, SHUTTER)
	canopy(pk, kit, x0 + 0.5, x1 - 0.5, -D, WALL - 0.45, 4.0, 0.5)
	# The ends: a small window each.
	window(pk, kit, Vector3(x0, 2.55, -D * 0.5), Vector3(-1, 0, 0), 1.0, 1.5, SHUTTER)
	window(pk, kit, Vector3(x1, 2.55, -D * 0.5), Vector3(1, 0, 0), 1.0, 1.5, SHUTTER)
	# Stacked goods on the platform in front of the doors.
	for k in range(3):
		var bx: float = d1 + 4.0 + 0.8 * float(k)
		drum(pk, kit, Vector3(bx, PLATFORM_Y, -D - 1.1), Color(0.18, 0.28, 0.42) if k != 1 else Color(0.55, 0.20, 0.14))
	crate(pk, kit, Vector3(d2 - 4.0, PLATFORM_Y, -D - 1.2), 0.1, Vector3(1.0, 0.7, 0.7))
	crate(pk, kit, Vector3(d2 - 4.1, PLATFORM_Y + 0.7, -D - 1.2), -0.2, Vector3(0.8, 0.6, 0.6))
	crate(pk, kit, Vector3(d2 - 2.9, PLATFORM_Y, -D - 1.3), 0.0, Vector3(0.9, 0.55, 0.7), Color(0.46, 0.34, 0.22))
