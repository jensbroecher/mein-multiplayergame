extends RefCounted
## Canyon Chasm's Western wooden-derrick windpump (Windmill), modelled in CSG at life size
## in the exact unscaled local frame of the level's Windmill node:
## - `build_tower()` builds the stationary 25.3m timber derrick tower (with foundations extending
##   SINK = 3.8m below y = 0 so all 4 legs bed solidly into the hillside), base cribbing sills,
##   4 bays of timber X-bracing, the y = 15.5m wooden maintenance platform with safety rails,
##   the front wooden ladder, the central wellhead pump cylinder & vertical steel pump rod,
##   the cast-iron turntable gearbox at y = 23.18m, the rear service walk boom, and the
##   galvanized steel tailbone truss & large sheet-metal tail vane.
## - `build_rotor()` builds the 15.0m diameter, 18-bladed galvanized steel wind-wheel centered
##   at `(0, 0, 0)` (placed on `BladePivot` at `HUB_POS = Vector3(-0.30, 23.18, 1.62)`), with
##   cast-iron hub, inner and outer steel rim hoops, 6 spoke pairs, and 18 pitched steel sails.
##
## regenerate_chasm_houses.gd bakes them to `generated/windmill_tower.res` and
## `generated/windmill_rotor.res`, which `Windmill.tscn` draws at scale 1.0.

const SINK := 3.8
const CENTER_X := -0.40
const CENTER_Z := -0.89
const HUB_POS := Vector3(-0.30, 23.18, 1.62)

const COL_TIMBER := Color(0.56, 0.54, 0.50)
const COL_TIMBER_DARK := Color(0.42, 0.40, 0.37)
const COL_DECK := Color(0.50, 0.47, 0.43)
const COL_IRON := Color(0.24, 0.25, 0.27)
const COL_RUST := Color(0.44, 0.33, 0.26)
const COL_GALV := Color(0.68, 0.72, 0.75)
const COL_GALV_WEATHER := Color(0.58, 0.60, 0.61)

static var _placeholder_mats := {}
static var _final_mats := {}


static func _leg_spread(y: float) -> float:
	if y <= 15.35:
		return lerpf(3.85, 1.92, y / 15.35)
	return lerpf(1.92, 0.62, (y - 15.35) / (22.85 - 15.35))


static func _leg_pt(corner_idx: int, y: float) -> Vector3:
	var signs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var s: Vector2 = signs[corner_idx % 4]
	var sp := _leg_spread(y)
	return Vector3(CENTER_X + s.x * sp, y, CENTER_Z + s.y * sp)


static func build_tower() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "WindmillTowerCSG"

	var m_timber := _mat("timber", COL_TIMBER)
	var m_timber_dark := _mat("timber", COL_TIMBER_DARK)
	var m_deck := _mat("wood_h", COL_DECK)
	var m_iron := _mat("iron", COL_IRON)
	var m_rust := _mat("iron", COL_RUST)
	var m_galv := _mat("galv", COL_GALV)
	var m_galv_w := _mat("galv", COL_GALV_WEATHER)

	# ------------------------------------------------------------------
	# 1. Foundation Piers, Base Sill Cribbing & 4 Tapered Corner Posts
	# ------------------------------------------------------------------
	# Four main corner legs from y = -SINK to y = 15.35, then upper mast legs to y = 22.85
	for c in 4:
		var p_bot := _leg_pt(c, -SINK)
		var p_mid := _leg_pt(c, 15.45)
		var p_top := _leg_pt(c, 22.85)
		_add(root, _beam(p_bot, p_mid, 0.46, 0.46, m_timber), CSGShape3D.OPERATION_UNION)
		_add(root, _beam(p_mid, p_top, 0.36, 0.36, m_timber), CSGShape3D.OPERATION_UNION)
		# Heavy timber foot pad & anchor pier at base of each leg (y = -SINK .. 0.85)
		var p0 := _leg_pt(c, 0.0)
		_add(root, _box(Vector3(p0.x, (0.65 - SINK) * 0.5, p0.z), Vector3(0.95, 0.65 + SINK, 0.95), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# Heavy crossed base sill timbers at y = 0.42 and y = 1.35 (extending out as foot sills)
	for sy in [0.42, 1.35]:
		var sp := _leg_spread(sy)
		var ext := sp + (1.15 if sy < 0.8 else 0.55)
		for side_sign in [-1.0, 1.0]:
			_add(root, _box(Vector3(CENTER_X, sy, CENTER_Z + side_sign * sp), Vector3(ext * 2.0, 0.38, 0.42), m_timber_dark), CSGShape3D.OPERATION_UNION)
			_add(root, _box(Vector3(CENTER_X + side_sign * sp, sy + 0.22, CENTER_Z), Vector3(0.42, 0.38, ext * 2.0), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 2. Horizontal Girts & X-Bracing Bays on All 4 Sides
	# ------------------------------------------------------------------
	var girt_ys := [1.35, 4.10, 8.85, 13.80, 15.35, 19.15, 22.45]
	for gy in girt_ys:
		for c in 4:
			var a := _leg_pt(c, gy)
			var b := _leg_pt((c + 1) % 4, gy)
			var w := 0.34 if gy < 16.0 else 0.26
			_add(root, _beam(a, b, w, w, m_timber_dark), CSGShape3D.OPERATION_UNION)

	var brace_bays := [
		[1.35, 4.10, 0.24],
		[4.10, 8.85, 0.26],
		[8.85, 13.80, 0.26],
		[15.65, 19.15, 0.20],
		[19.15, 22.45, 0.18],
	]
	for bay in brace_bays:
		var y0: float = bay[0]
		var y1: float = bay[1]
		var bw: float = bay[2]
		for c in 4:
			var a0 := _leg_pt(c, y0)
			var b0 := _leg_pt((c + 1) % 4, y0)
			var a1 := _leg_pt(c, y1)
			var b1 := _leg_pt((c + 1) % 4, y1)
			_add(root, _beam(a0, b1, bw, bw * 0.75, m_timber), CSGShape3D.OPERATION_UNION)
			_add(root, _beam(b0, a1, bw, bw * 0.75, m_timber), CSGShape3D.OPERATION_UNION)
			# Iron bolt gusset at X intersection
			var mid := (a0 + b0 + a1 + b1) * 0.25
			_add(root, _box(mid, Vector3(0.32, 0.32, 0.32), m_iron), CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 3. Wooden Maintenance Platform & Guardrails (Y = 15.35 .. 17.05)
	# ------------------------------------------------------------------
	var plat_y := 15.55
	# Two pairs of heavy cantilevered bearer joists under the platform
	for jx in [-2.05, -1.25, 1.25, 2.05]:
		_add(root, _box(Vector3(CENTER_X + jx, plat_y - 0.22, CENTER_Z), Vector3(0.28, 0.36, 6.45), m_timber_dark), CSGShape3D.OPERATION_UNION)
	for jz in [-2.05, 2.05]:
		_add(root, _box(Vector3(CENTER_X, plat_y - 0.18, CENTER_Z + jz), Vector3(6.45, 0.32, 0.28), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# Plank deck floor (6.20m x 6.20m) with central pump-rod opening collar
	_add(root, _box(Vector3(CENTER_X, plat_y, CENTER_Z), Vector3(6.20, 0.18, 6.20), m_deck), CSGShape3D.OPERATION_UNION)
	_add(root, _box(Vector3(CENTER_X, plat_y + 0.14, CENTER_Z), Vector3(6.32, 0.22, 6.32), m_timber_dark), CSGShape3D.OPERATION_UNION)

	# Platform perimeter safety posts & top/mid rails (leaving ladder entry gap on +Z front)
	for sx in [-2.95, 0.0, 2.95]:
		for sz in [-2.95, 2.95]:
			if absf(sx) < 0.5 and sz > 0.0:
				continue
			_add(root, _box(Vector3(CENTER_X + sx, plat_y + 0.80, CENTER_Z + sz), Vector3(0.20, 1.50, 0.20), m_timber_dark), CSGShape3D.OPERATION_UNION)
	for rail_y in [plat_y + 0.78, plat_y + 1.45]:
		# Left (-X), Right (+X), Back (-Z) rails
		_add(root, _box(Vector3(CENTER_X - 2.95, rail_y, CENTER_Z), Vector3(0.16, 0.16, 6.06), m_timber), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(CENTER_X + 2.95, rail_y, CENTER_Z), Vector3(0.16, 0.16, 6.06), m_timber), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(CENTER_X, rail_y, CENTER_Z - 2.95), Vector3(6.06, 0.16, 0.16), m_timber), CSGShape3D.OPERATION_UNION)
		# Front (+Z) rails either side of ladder hatch
		_add(root, _box(Vector3(CENTER_X - 1.85, rail_y, CENTER_Z + 2.95), Vector3(2.35, 0.16, 0.16), m_timber), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(CENTER_X + 1.85, rail_y, CENTER_Z + 2.95), Vector3(2.35, 0.16, 0.16), m_timber), CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 4. Front Wooden Ladder (+Z face, from y = -SINK up to y = 16.40)
	# ------------------------------------------------------------------
	var lad_bot_z := CENTER_Z + 4.95
	var lad_top_z := CENTER_Z + 2.85
	for lx_off in [-0.52, 0.52]:
		var lb := Vector3(CENTER_X + lx_off, -SINK, lad_bot_z)
		var lt := Vector3(CENTER_X + lx_off, 16.45, lad_top_z)
		_add(root, _beam(lb, lt, 0.16, 0.24, m_timber_dark), CSGShape3D.OPERATION_UNION)
	var rung_count := 24
	for r in rung_count:
		var t := float(r) / float(rung_count - 1)
		var ry := lerpf(-1.2, 16.0, t)
		var rz := lerpf(lad_bot_z, lad_top_z, (ry - (-SINK)) / (16.45 - (-SINK)))
		_add(root, _box(Vector3(CENTER_X, ry, rz), Vector3(1.18, 0.10, 0.12), m_timber), CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 5. Central Wellhead Casing, Pump Rod & Upper Turntable Gearbox
	# ------------------------------------------------------------------
	# Cast-iron wellhead pump cylinder at base
	var well_cyl := CSGCylinder3D.new()
	well_cyl.radius = 0.42
	well_cyl.height = 2.90 + SINK
	well_cyl.sides = 12
	well_cyl.position = Vector3(CENTER_X, (2.90 - SINK) * 0.5, CENTER_Z)
	well_cyl.material = m_rust
	_add(root, well_cyl, CSGShape3D.OPERATION_UNION)

	var well_flange := CSGCylinder3D.new()
	well_flange.radius = 0.56
	well_flange.height = 0.24
	well_flange.sides = 12
	well_flange.position = Vector3(CENTER_X, 2.75, CENTER_Z)
	well_flange.material = m_iron
	_add(root, well_flange, CSGShape3D.OPERATION_UNION)

	# Vertical steel pump rod from wellhead up to turntable head (y = 23.18)
	var pump_rod := CSGCylinder3D.new()
	pump_rod.radius = 0.14
	pump_rod.height = 23.18 + SINK
	pump_rod.sides = 10
	pump_rod.position = Vector3(CENTER_X, (23.18 - SINK) * 0.5, CENTER_Z)
	pump_rod.material = m_iron
	_add(root, pump_rod, CSGShape3D.OPERATION_UNION)

	# Mast crown cap & turntable ring at y = 22.65
	_add(root, _box(Vector3(CENTER_X, 22.65, CENTER_Z), Vector3(1.75, 0.45, 1.75), m_timber_dark), CSGShape3D.OPERATION_UNION)
	var turntable := CSGCylinder3D.new()
	turntable.radius = 0.72
	turntable.height = 1.85
	turntable.sides = 14
	turntable.position = Vector3(CENTER_X, 23.25, CENTER_Z)
	turntable.material = m_iron
	_add(root, turntable, CSGShape3D.OPERATION_UNION)

	# Main cast-iron gearbox bonnet & horizontal shaft neck reaching HUB_POS
	_add(root, _box(Vector3(CENTER_X + 0.05, 23.25, CENTER_Z + 0.45), Vector3(1.45, 1.65, 2.55), m_iron), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(Vector3(CENTER_X, 23.18, CENTER_Z), HUB_POS, 0.62, 0.62, m_rust), CSGShape3D.OPERATION_UNION)

	# ------------------------------------------------------------------
	# 6. Galvanized Steel Tailbone Boom, Sheet-Metal Tail Vane & Rear Walk
	# ------------------------------------------------------------------
	# Tailbone truss extending from gearbox toward +X (matching original part_21 & part_1)
	var tail_root_top := Vector3(CENTER_X + 0.25, 23.85, -1.25)
	var tail_root_bot := Vector3(CENTER_X + 0.25, 21.85, -1.25)
	var tail_hinge_top := Vector3(6.15, 23.65, -1.28)
	var tail_hinge_bot := Vector3(6.15, 21.65, -1.28)
	_add(root, _beam(tail_root_top, tail_hinge_top, 0.18, 0.18, m_iron), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(tail_root_bot, tail_hinge_bot, 0.18, 0.18, m_iron), CSGShape3D.OPERATION_UNION)
	for tx: float in [1.6, 3.2, 4.8, 6.0]:
		var f: float = (tx - (CENTER_X + 0.25)) / (6.15 - (CENTER_X + 0.25))
		var pt_t := tail_root_top.lerp(tail_hinge_top, f)
		var pt_b := tail_root_bot.lerp(tail_hinge_bot, f)
		_add(root, _beam(pt_t, pt_b, 0.14, 0.14, m_iron), CSGShape3D.OPERATION_UNION)

	# Large trapezoidal galvanized sheet-metal tail vane (x = 5.65 .. 12.05, y = 20.55 .. 25.30, z = -1.30)
	var vane_poly := PackedVector2Array([
		Vector2(5.65, 21.35),
		Vector2(12.05, 20.55),
		Vector2(12.05, 25.30),
		Vector2(5.65, 24.15),
	])
	_add(root, _extrude_z(vane_poly, -1.38, -1.22, m_galv), CSGShape3D.OPERATION_UNION)
	# Riveted perimeter angle-iron frame and horizontal stiffening ribs on the tail vane
	_add(root, _beam(Vector3(5.65, 24.15, -1.30), Vector3(12.05, 25.30, -1.30), 0.22, 0.24, m_rust), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(Vector3(5.65, 21.35, -1.30), Vector3(12.05, 20.55, -1.30), 0.22, 0.24, m_rust), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(Vector3(12.00, 20.55, -1.30), Vector3(12.00, 25.30, -1.30), 0.22, 0.24, m_rust), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(Vector3(5.70, 21.35, -1.30), Vector3(5.70, 24.15, -1.30), 0.22, 0.24, m_rust), CSGShape3D.OPERATION_UNION)
	_add(root, _beam(Vector3(5.65, 22.75, -1.30), Vector3(12.05, 22.92, -1.30), 0.18, 0.22, m_galv_w), CSGShape3D.OPERATION_UNION)

	# Rear horizontal service ladder boom along -Z (matching part_7: z = -1.40 .. -9.20, y = 23.35)
	for rlx in [CENTER_X - 0.36, CENTER_X + 0.36]:
		_add(root, _beam(Vector3(rlx, 23.45, -1.20), Vector3(rlx, 22.85, -9.15), 0.14, 0.16, m_iron), CSGShape3D.OPERATION_UNION)
	for rzi in 8:
		var ft := float(rzi + 1) / 8.5
		var rz := lerpf(-1.20, -9.15, ft)
		var ry := lerpf(23.45, 22.85, ft)
		_add(root, _box(Vector3(CENTER_X, ry, rz), Vector3(0.84, 0.10, 0.12), m_iron), CSGShape3D.OPERATION_UNION)

	return root


static func build_rotor() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "WindmillRotorCSG"

	var m_iron := _mat("iron", COL_IRON)
	var m_rust := _mat("iron", COL_RUST)
	var m_galv := _mat("galv", COL_GALV)
	var m_galv_w := _mat("galv", COL_GALV_WEATHER)

	# 1. Central Cast-Iron Rotor Hub Barrel & Nose Cap (spinning around Z axis at origin)
	var hub_cyl := CSGCylinder3D.new()
	hub_cyl.radius = 0.88
	hub_cyl.height = 1.35
	hub_cyl.sides = 16
	hub_cyl.rotation_degrees.x = 90.0
	hub_cyl.material = m_iron
	_add(root, hub_cyl, CSGShape3D.OPERATION_UNION)

	var nose_cap := CSGCylinder3D.new()
	nose_cap.radius = 0.56
	nose_cap.height = 0.65
	nose_cap.sides = 14
	nose_cap.rotation_degrees.x = 90.0
	nose_cap.position = Vector3(0.0, 0.0, 0.72)
	nose_cap.material = m_rust
	_add(root, nose_cap, CSGShape3D.OPERATION_UNION)

	# 2. Concentric Inner (r = 3.05m) & Outer (r = 6.65m) Steel Rim Hoops (18 segments)
	var sail_count := 18
	for rr in [3.05, 6.65]:
		for i in sail_count:
			var a0 := TAU * float(i) / float(sail_count)
			var a1 := TAU * float(i + 1) / float(sail_count)
			var p0 := Vector3(cos(a0) * rr, sin(a0) * rr, 0.0)
			var p1 := Vector3(cos(a1) * rr, sin(a1) * rr, 0.0)
			_add(root, _beam(p0, p1, 0.16, 0.18, m_iron), CSGShape3D.OPERATION_UNION)

	# 3. Six Heavy Steel Spoke Pairs radiating from Hub to Outer Rim
	for s in 6:
		var sa := TAU * float(s) / 6.0
		var dir := Vector3(cos(sa), sin(sa), 0.0)
		_add(root, _beam(Vector3(0, 0, -0.35) + dir * 0.65, dir * 6.85, 0.16, 0.16, m_iron), CSGShape3D.OPERATION_UNION)
		_add(root, _beam(Vector3(0, 0, 0.35) + dir * 0.65, dir * 3.15, 0.14, 0.14, m_rust), CSGShape3D.OPERATION_UNION)

	# 4. Eighteen Curved / Pitched Galvanized Steel Wind-Wheel Sails (r = 2.40m .. 7.45m)
	# Each sail is a trapezoidal sheet-metal blade pitched at 28 degrees out of the XY wheel plane
	var sail_poly := PackedVector2Array([
		Vector2(-0.34, 2.40),
		Vector2(0.34, 2.40),
		Vector2(0.76, 7.45),
		Vector2(-0.76, 7.45),
	])
	for i in sail_count:
		var ang := TAU * float(i) / float(sail_count)
		var radial := Vector3(cos(ang), sin(ang), 0.0)
		var tang := Vector3(-sin(ang), cos(ang), 0.0)
		var sail_basis := Basis(tang, radial, Vector3.BACK) * Basis(Vector3.UP, deg_to_rad(28.0))
		var mat_s := m_galv if (i % 3 != 0) else m_galv_w
		var sail := _extrude_z(sail_poly, -0.06, 0.06, mat_s)
		sail.transform = Transform3D(sail_basis, Vector3.ZERO)
		_add(root, sail, CSGShape3D.OPERATION_UNION)
		# Center stiffening rib along the sail back
		var rib_a := sail_basis * Vector3(0.0, 2.45, -0.08)
		var rib_b := sail_basis * Vector3(0.0, 7.35, -0.08)
		_add(root, _beam(rib_a, rib_b, 0.12, 0.10, m_rust if (i % 4 == 0) else m_iron), CSGShape3D.OPERATION_UNION)

	return root


static func _extrude_z(poly: PackedVector2Array, z0: float, z1: float, mat: Material) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.polygon = poly
	p.depth = z1 - z0
	p.position = Vector3(0.0, 0.0, z1)
	p.material = mat
	return p


static func _box(at: Vector3, size: Vector3, mat: Material, b := Basis()) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.size = size
	box.transform = Transform3D(b, at)
	box.material = mat
	return box


static func _beam(a: Vector3, b: Vector3, w: float, t: float, mat: Material, side := Vector3.ZERO) -> CSGBox3D:
	var d := b - a
	var length := d.length()
	var z := d / maxf(length, 1e-4)
	var x := side
	if x.length_squared() < 1e-6 or absf(x.normalized().dot(z)) > 0.98:
		x = Vector3.UP.cross(z)
		if x.length_squared() < 1e-6:
			x = Vector3.RIGHT
	x = (x - z * x.dot(z)).normalized()
	var y := z.cross(x).normalized()
	return _box((a + b) * 0.5, Vector3(w, t, length), mat, Basis(x, y, z))


static func _add(parent: CSGShape3D, child: CSGShape3D, op: int) -> void:
	child.operation = op if parent.get_child_count() > 0 else CSGShape3D.OPERATION_UNION
	parent.add_child(child)


static func _mat(key: String, col: Color) -> StandardMaterial3D:
	var tag := "%s:%s" % [key, col.to_html(false)]
	if not _placeholder_mats.has(tag):
		var m := StandardMaterial3D.new()
		m.resource_name = tag
		m.albedo_color = col
		_placeholder_mats[tag] = m
	return _placeholder_mats[tag]


static func _final_material(key: String) -> Material:
	if _final_mats.has(key):
		return _final_mats[key]
	var m: Material
	match key:
		"timber":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_wood.gdshader")
			sm.set_shader_parameter("style", 2)
			sm.set_shader_parameter("weathering", 0.65)
			m = sm
		"wood_h":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://hut_wood.gdshader")
			sm.set_shader_parameter("style", 1)
			sm.set_shader_parameter("weathering", 0.58)
			m = sm
		"galv":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.metallic = 0.62
			sm.roughness = 0.44
			m = sm
		"iron":
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			sm.metallic = 0.58
			sm.roughness = 0.52
			m = sm
		_:
			var sm := StandardMaterial3D.new()
			sm.vertex_color_use_as_albedo = true
			m = sm
	_final_mats[key] = m
	return m


static func bake(root: CSGShape3D) -> ArrayMesh:
	var src: ArrayMesh = root.bake_static_mesh()
	var out := ArrayMesh.new()
	if src == null:
		push_error("WindmillCSG: CSG has not built its mesh yet")
		return out
	var tools := {}
	var order: Array[String] = []
	for si in range(src.get_surface_count()):
		var mat := src.surface_get_material(si)
		var tag := mat.resource_name.split(":") if mat and mat.resource_name.contains(":") else PackedStringArray(["timber", "8f8a80"])
		var key: String = tag[0]
		var col := Color(tag[1])
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			order.append(key)
		var st: SurfaceTool = tools[key]
		var arr := src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if not idx.is_empty() else v.size()
		for t in range(0, count - 2, 3):
			var ids := [t, t + 1, t + 2] if idx.is_empty() else [idx[t], idx[t + 1], idx[t + 2]]
			var a: Vector3 = v[ids[0]]
			var raw_n := (v[ids[2]] - a).cross(v[ids[1]] - a)
			var fn := raw_n.abs()
			for i in ids:
				var p: Vector3 = v[i]
				var uv: Vector2
				if fn.z >= fn.x and fn.z >= fn.y:
					uv = Vector2(p.x, p.y)
				elif fn.x >= fn.y:
					uv = Vector2(p.z, p.y)
				else:
					uv = Vector2(p.x, p.z)
				st.set_color(col)
				st.set_normal(n[i])
				st.set_uv(uv)
				st.add_vertex(p)
	for key in order:
		var st: SurfaceTool = tools[key]
		st.generate_tangents()
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _final_material(key))
	return out
