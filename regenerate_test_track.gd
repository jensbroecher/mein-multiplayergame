# regenerate_test_track.gd
#
# Builds levels/TestTrackLevel.tscn - the Test Track: a proving ground for trying the cars, listed under "Other Courses"
# (Time Trial, Spectator, Inspect, VS), never in a cup or the random pick (NetworkManager's ALL_STAGES entry has
# "test"). The lap (1.6km, clockwise): a 580m start straight for top speed (distance boards before the first corner), a
# fast right-hander, the long south leg, a tight hairpin, a table-top jump, a chicane, the surface strip (a patch of
# every surface the tyres know, one after the other: sand, snow, ice, mud, grass, gravel, dirt, wood, cobbles), and a
# hill with a kicker at its crest. Boost pads before the hill and out of the last corner.
#
# Built on MiyoshinoStage.gd (the roads, the ground, the gates, the sky): read its header. Here: the ground, the course,
# the strip (`STRIP`, `_build_strip`: ribbons over the road, each its own body with its `surface` meta and a name with
# "Road" in it, so it is track), the jumps and the signs.
extends "res://MiyoshinoStage.gd"

## The surface strip: [surface (Surfaces.NAMES), its kind in test_surface.gdshader, the sign's words]. Each patch is
## STRIP_PATCH long with STRIP_GAP of asphalt after it, from STRIP_X0 westward along the strip's leg.
const STRIP := [["sand", 0, "SAND"], ["snow", 1, "SNOW"], ["ice", 2, "ICE"], ["mud", 3, "MUD"], ["grass", 4, "GRASS"],
	["gravel", 5, "GRAVEL"], ["dirt", 6, "DIRT"], ["wood", 7, "WOOD"], ["rock", 8, "COBBLES"]]
const STRIP_X0 := 22.0
const STRIP_PATCH := 24.0
const STRIP_GAP := 6.0
const STRIP_Z := 70.0
const STRIP_LIFT := 0.03
## The hill on the west leg: its crest (z) and height, and how far either way it rises.
const HILL_Z := -25.0
const HILL_H := 7.0
const HILL_HALF := 70.0
const HILL_X := -280.0

var s_p1 := 0.0
var s_hairpin := 0.0
var s_chic0 := 0.0
var s_chic1 := 0.0
var s_strip0 := 0.0
var s_crest := 0.0
var _raw_route: Route


func _configure() -> void:
	level_name = "TestTrackLevel"
	level_path = "res://levels/TestTrackLevel.tscn"
	stem = "testtrack"
	title = "Test Track"
	seed_base = 8800
	road_half = 8.0
	max_grade = 0.14
	smooth_half = 10
	corners = [
		[Vector2(300.0, -120.0), 60.0],    # the end of the start straight: right, south
		[Vector2(300.0, 170.0), 16.0],     # the hairpin, back north-west
		[Vector2(220.0, 70.0), 26.0],      # left, west
		[Vector2(140.0, 70.0), 14.0],      # the chicane
		[Vector2(112.0, 92.0), 14.0],
		[Vector2(78.0, 92.0), 14.0],
		[Vector2(50.0, 70.0), 14.0],
		[Vector2(-280.0, STRIP_Z), 32.0],  # the end of the surface strip: right, north over the hill
		[Vector2(-280.0, -120.0), 32.0],   # right onto the start straight
	]
	finish_at = Vector2(-100.0, -120.0)
	fine_x = Vector2(-460.0, 480.0)
	fine_z = Vector2(-300.0, 340.0)
	tree_margin = 260.0


func _init_noise() -> void:
	super._init_noise()
	_raw_route = Route.new()
	_raw_route.build(corners, true)
	s_p1 = _raw_route.closest_s(Vector2(240.0, -120.0))
	s_hairpin = _raw_route.closest_s(Vector2(300.0, 170.0))
	s_chic0 = _raw_route.closest_s(Vector2(150.0, 70.0))
	s_chic1 = _raw_route.closest_s(Vector2(40.0, 70.0))
	s_strip0 = _raw_route.closest_s(Vector2(STRIP_X0, STRIP_Z))
	s_crest = _raw_route.closest_s(Vector2(HILL_X, HILL_Z))


## A flat proving ground, the hill on the west leg, low hills far round it.
func _natural(x: float, z: float) -> float:
	var h := 0.0
	var dz: float = (z - HILL_Z) / HILL_HALF
	var dx: float = (x - HILL_X) / 60.0
	h += HILL_H * exp(-dz * dz * 2.2) * exp(-dx * dx * 1.6)
	var far: float = Vector2(x - 20.0, z - 25.0).length()
	h += smoothstep(650.0, 2600.0, far) * (60.0 + 190.0 * absf(n_ridge.get_noise_2d(x, z)))
	h += smoothstep(500.0, 900.0, far) * 4.0 * n_hill.get_noise_2d(x, z)
	return h


func _sections(r: Route) -> Array:
	return [[0.0, r.length, K_ASPHALT, r.half]]


func _environment() -> Dictionary:
	return {"sun_pitch": -58.0, "sun_yaw": 20.0, "cloud_coverage": 0.3, "cloud_seed": 51.7, "fog_end": 3600.0, "sun_energy": 1.4}


func _ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("petal_amount", 0.0)


func _petals_at(_x: float, _z: float) -> float:
	return 0.0


# ======================================================================================
#  Gameplay
# ======================================================================================

func _place_gameplay(root: Node3D) -> void:
	var fin: float = _finish_s()
	_checkpoints([
		_closest_s(Vector2(300.0, 60.0)),      # the south leg
		_closest_s(Vector2(170.0, 70.0)),      # before the chicane
		_closest_s(Vector2(-130.0, STRIP_Z)),  # the surface strip
		_closest_s(Vector2(-280.0, -70.0)),    # over the hill
	])
	_boosts([
		["Boost_Hill", _closest_s(Vector2(-280.0, 22.0)), 0.0],
		["Boost_StraightL", fin - 95.0, -3.0],
		["Boost_StraightR", fin - 95.0, 3.0],
	])
	# A kicker just before the hill's crest: big air over the top.
	_kicker(root, "CrestJump", lap, s_crest - 12.0, 9.0, 1.3, 0.35)
	# A table-top on the leg out of the hairpin: up, along the top, down the far side.
	_ramp(root, "TableTop", s_hairpin + 58.0, 8.0, 1.6, 7.0, 9.0)


## A WoodenRamp across the lap, its toe at s: `table` along the top, `tail` back down (0: a kicker).
func _ramp(root: Node3D, jump_name: String, toe: float, length: float, height: float, table: float, tail: float) -> void:
	var j: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	j.name = jump_name
	var sp: Dictionary = lap.spot(toe, 0.0, 0.0)
	j.position = sp["pos"]
	j.rotation_degrees = Vector3(0, sp["yaw"], 0)
	j.set("length", length)
	j.set("height", height)
	j.set("curve", 0.3)
	j.set("table_length", table)
	j.set("tail_length", tail)
	j.set("width", lap.half * 2.0)
	j.set("wood_color", Color(0.55, 0.42, 0.30))
	j.set("trim_color", Color(0.95, 0.80, 0.12))
	root.add_child(j)
	var lp: Dictionary = lap.spot(toe + length, 0.0, 0.0)
	var slope: float = height / length * 1.3
	_jump_lips.append({"name": jump_name, "lip": (lp["pos"] as Vector3) + Vector3(0, height, 0),
			"dir": ((lp["fwd"] as Vector3) + Vector3(0, slope, 0)).normalized()})


# ======================================================================================
#  The surface strip and the signs
# ======================================================================================

func _build_dressing(root: Node3D) -> void:
	_build_strip(root)
	_build_signs(root)
	var fin: float = _finish_s()
	_build_start_crowd(root, fin - 70.0, fin + 70.0, road_half + 3.0, fin - 8.0, fin + 8.0, seed_base + 11)
	_build_paddock(root)
	_build_buildings(root)
	_build_cones(root)
	# Guardrails round the outside of the corners (every corner turns right: the outside is the left).
	var body: StaticBody3D = _body(root, "GuardrailBody_Lap")
	for c in [Vector2(300.0, -120.0), Vector2(300.0, 170.0), Vector2(-280.0, STRIP_Z), Vector2(-280.0, -120.0)]:
		var sc: float = lap.closest_s(c)
		_rails(body, sc - 60.0, sc + 60.0, -1.0)


# ======================================================================================
#  The proving ground's buildings
# ======================================================================================

const PGK = preload("res://ProvingGroundKit.gd")
## [builder, x, z, yaw (degrees: 0 faces +z, south), range]. The pit building and the office face the start straight
## from the north, in the sun; the control tower (the 3D logo turning on its roof) and the Tech Centre face it from the
## infield.
const BUILDINGS := [["pit", 30.0, -161.2, 0.0, 0.0], ["office", -207.0, -178.0, 0.0, 1600.0],
	["tower", -55.0, -70.0, 180.0, 0.0], ["workshop", 178.0, -75.0, 180.0, 1600.0]]
## The logo on the tower, in model units to game metres (the model is 9 x 3.4m: 21.6m across here), turning slowly.
const LOGO_SCALE := 2.4
const LOGO_SPIN := 9.0

var _bld_mats := {}
var _sign_font: Font


## Each building one mesh (ProvingGroundKit, life size grown by PROP_SCALE) with its signs, box colliders (nothing on
## this level gets them from DressingColliders), its footprint noted so the woods keep off; paved aprons before the pit
## building and the Tech Centre (track: a car can drive in), car parks, light masts, the logo on the tower, flags.
func _build_buildings(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "ProvingGround"
	root.add_child(holder)
	var body := StaticBody3D.new()
	body.name = "BuildingsBody"
	body.set_meta(&"surface", "rock")
	holder.add_child(body)
	_sign_font = load("res://fonts/NotoSansSC-Yunhai.otf")
	for b in BUILDINGS:
		var kind: String = b[0]
		var yaw: float = deg_to_rad(float(b[3]))
		var c := Vector3(float(b[1]), 0.0, float(b[2]))
		c.y = _ground_at(c.x, c.z)
		var xf := Transform3D(Basis(Vector3.UP, yaw), c)
		var pk = PGK.new_kit(PROP_SCALE)
		pk.set_frame(Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * PROP_SCALE), xf.origin))
		var kit := {}
		var labels: Array = []
		match kind:
			"pit": PGK.pit_building(pk, kit, labels)
			"tower": PGK.control_tower(pk, kit, labels)
			"workshop": PGK.workshop(pk, kit, labels)
			"office": PGK.office(pk, kit, labels)
		var frame: Transform3D = pk.xf
		var mi := MeshInstance3D.new()
		mi.name = kind.to_pascal_case()
		mi.mesh = _save_building_mesh(PGK.commit(pk, kit), "building_" + kind)
		if float(b[4]) > 0.0:
			mi.visibility_range_end = float(b[4])
		holder.add_child(mi)
		for l in labels:
			_building_label(mi, String(l[0]), frame * (l[1] as Vector3), (xf.basis * (l[2] as Vector3)).normalized(),
					float(l[3]) * PROP_SCALE, l[4], float(l[5]) * PROP_SCALE if l.size() > 5 else 0.0)
		# Colliders and the footprint.
		for bx in _building_boxes(kind):
			var lo := Vector3(bx[0], 0.0, bx[2])
			var hi := Vector3(bx[1], bx[4], bx[3])
			_box_shape(body, Transform3D(xf.basis, xf * (((lo + hi) * 0.5) * PROP_SCALE)), (hi - lo) * PROP_SCALE)
		var fp: Array = PGK.footprint(kind)
		_note_frame(xf, Vector2(fp[0], fp[2]), Vector2(fp[1], fp[3]), 6.0)
		if kind == "tower":
			_tower_logo(holder, xf)
			# Two flags either side of the lobby's canopy, streaming away from the road.
			for sx in [-11.0, 11.0]:
				var fpos: Vector3 = xf * (Vector3(sx, 0.0, 11.0) * PROP_SCALE)
				fpos.y = _ground_at(fpos.x, fpos.z)
				var flag := Node3D.new()
				flag.name = "LogoFlag_Tower%d" % (0 if sx < 0.0 else 1)
				flag.set_script(load("res://LogoFlag.gd"))
				flag.set("pole_height", 12.0)
				var fly := Vector3(signf(sx), 0, 0)
				flag.transform = Transform3D(Basis(fly, Vector3.UP, fly.cross(Vector3.UP)), fpos)
				holder.add_child(flag)
	_build_aprons(holder)
	_build_car_parks(holder)


## Box colliders per building: [x0, x1, z0, z1, height] in its frame, life metres.
func _building_boxes(kind: String) -> Array:
	match kind:
		"pit":
			return [[-30.4, 30.4, -6.3, 6.95, 10.4], [30.4, 33.2, -3.6, 6.6, 9.2]]
		"tower":
			return [[-9.6, 9.6, -6.6, 6.6, 5.6], [-3.6, 3.6, -4.1, 3.1, 35.0], [-3.2, 3.2, 8.7, 9.3, 3.6]]
		"workshop":
			return [[-12.3, 12.3, -15.4, 15.4, 10.0], [12.0, 18.4, -2.3, 12.4, 4.2], [-8.2, 16.2, 15.4, 15.7, 6.0]]
		"office":
			return [[-13.2, 13.2, -7.2, 8.0, 11.8], [13.0, 17.3, -3.3, 3.3, 13.2], [-11.8, -6.4, 10.3, 10.7, 3.2]]
	return []


func _save_building_mesh(mesh: ArrayMesh, mesh_name: String) -> Resource:
	for si in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(si)
		if m == null or not m.resource_path.is_empty():
			continue
		var id: int = m.get_instance_id()
		if not _bld_mats.has(id):
			_bld_mats[id] = _save_res(m, "bldmat_%d" % _bld_mats.size(), stem + "prop_")
		mesh.surface_set_material(si, _bld_mats[id])
	return _save_res(mesh, mesh_name, stem + "prop_")


## A sign's letters (the kit's labels: cap height and board width in game metres), in Noto Sans Bold.
func _building_label(parent: Node3D, text: String, at: Vector3, n: Vector3, cap: float, col: Color, max_w: float) -> void:
	var lab := Label3D.new()
	lab.text = text
	lab.font = _sign_font
	lab.font_size = 64
	var pixel: float = cap / 44.8
	if max_w > 0.0:
		var w: float = _sign_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
		pixel = minf(pixel, max_w / maxf(w, 1.0))
	lab.pixel_size = pixel
	lab.modulate = col
	lab.outline_size = 0
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP), at)
	parent.add_child(lab)


## The 3D logo (generated/logo/RcVibeLogo.tscn) back to back on the tower's post, turning slowly (Spinner.gd, wall clock).
func _tower_logo(holder: Node3D, xf: Transform3D) -> void:
	var spin := Node3D.new()
	spin.name = "TowerLogo"
	spin.set_script(load("res://Spinner.gd"))
	spin.set("axis", Vector3.UP)
	spin.set("degrees_per_second", LOGO_SPIN)
	spin.position = xf * (Vector3(0, PGK.TOWER_LOGO_Y, -0.5) * PROP_SCALE)
	holder.add_child(spin)
	var size: Vector3 = Vector3(9.0, 3.416, 0.584)
	for k in 2:
		var logo: Node3D = (load("res://generated/logo/RcVibeLogo.tscn") as PackedScene).instantiate()
		logo.name = "Logo%d" % k
		logo.scale = Vector3.ONE * LOGO_SCALE
		logo.rotation.y = PI * float(k)
		logo.position = Vector3(0, size.y * 0.5 * LOGO_SCALE, 0)
		spin.add_child(logo)


## Concrete aprons before the pit building (to the road's edge) and the Tech Centre: a slab 6cm up with painted bay
## boxes, solid and track ("...Road"), so a car can drive off the straight onto them.
func _build_aprons(holder: Node3D) -> void:
	var pk = PGK.new_kit(1.0)
	var kit := {}
	var body := StaticBody3D.new()
	body.name = "PitApronRoad"
	body.set_meta(&"surface", "asphalt")
	holder.add_child(body)
	# [x0, x1, z0 (the building's side), z1 (the road's edge), bay lines every (0: none)]: the pit apron north of the
	# straight, the Tech Centre's south of it.
	var aprons := [[-19.0, 79.0, -150.0, -120.0 - road_half - 0.4, 9.6], [151.0, 198.0, -100.0, -120.0 + road_half + 0.4, 0.0]]
	for a in aprons:
		var x0: float = a[0]
		var x1: float = a[1]
		var z0: float = minf(a[2], a[3])
		var z1: float = maxf(a[2], a[3])
		var y: float = maxf(maxf(_ground_at(x0, z0), _ground_at(x1, z0)), maxf(_ground_at(x0, z1), _ground_at(x1, z1))) + 0.06
		PGK.blk(pk, kit, "concrete", Vector3(x0, y - 0.5, z0), Vector3(x1, y, z1), Color(0.70, 0.70, 0.68))
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(x1 - x0, 0.5, z1 - z0)
		col.shape = shape
		col.position = Vector3((x0 + x1) * 0.5, y - 0.25, (z0 + z1) * 0.5)
		body.add_child(col)
		# A white line round it, bay lines across, a yellow pit-lane line along its middle.
		var w := 0.15
		for e in [[x0, z0, x1, z0 + w], [x0, z1 - w, x1, z1], [x0, z0, x0 + w, z1], [x1 - w, z0, x1, z1]]:
			PGK.blk(pk, kit, "alu", Vector3(e[0], y, e[1]), Vector3(e[2], y + 0.012, e[3]), Color(0.92, 0.92, 0.90))
		if float(a[4]) > 0.0:
			var bx: float = x0 + 1.4
			while bx < x1:
				PGK.blk(pk, kit, "alu", Vector3(bx - 0.08, y, z0 + 0.2), Vector3(bx + 0.08, y + 0.012, z0 + 9.0), Color(0.92, 0.92, 0.90))
				bx += float(a[4])
			PGK.blk(pk, kit, "alu", Vector3(x0 + 0.5, y, z0 + 11.0), Vector3(x1 - 0.5, y + 0.012, z0 + 11.2), Color(0.95, 0.78, 0.10))
		_note_rect(Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5), x1 - x0, z1 - z0, 0.0, 2.0)
	var mi := MeshInstance3D.new()
	mi.name = "Aprons"
	mi.mesh = _save_building_mesh(PGK.commit(pk, kit), "aprons")
	holder.add_child(mi)
	# Light masts along the pit apron's back and the Tech Centre's apron.
	var mk = PGK.new_kit(PROP_SCALE)
	var mkit := {}
	var spots: Array = []
	var x := -14.0
	while x < 78.0:
		spots.append(Vector3(x, 0, -147.5))
		x += 23.0
	for sx in [154.0, 195.0]:
		spots.append(Vector3(sx, 0, -102.5))
	for sp in spots:
		var p: Vector3 = sp
		p.y = _ground_at(p.x, p.z)
		mk.set_frame(Transform3D(Basis(Vector3.UP, 0.0 if p.z < -120.0 else PI).scaled(Vector3.ONE * PROP_SCALE), p))
		PGK.light_mast(mk, mkit, 7.5)
		_box_shape(body_or(holder), Transform3D(Basis(), p + Vector3(0, 6.0, 0)), Vector3(0.4, 12.0, 0.4))
	mk.reset_frame()
	var mm := MeshInstance3D.new()
	mm.name = "LightMasts"
	mm.mesh = _save_building_mesh(PGK.commit(mk, mkit), "light_masts")
	mm.visibility_range_end = 1200.0
	holder.add_child(mm)


func body_or(holder: Node3D) -> StaticBody3D:
	return holder.get_node("BuildingsBody") as StaticBody3D


## Car parks beside the office and the tower: asphalt with bay lines, CampKit cars in some bays (box colliders).
func _build_car_parks(holder: Node3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var kit := {}
	var lk = PGK.new_kit(1.0)
	var lkit := {}
	var body := body_or(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 77
	var cols := [Color(0.92, 0.92, 0.90), Color(0.10, 0.10, 0.12), Color(0.55, 0.10, 0.10), Color(0.20, 0.30, 0.55),
		Color(0.65, 0.67, 0.70), Color(0.85, 0.45, 0.08)]
	# [x0, x1, z0, z1]: two rows of bays facing a middle aisle along x.
	for lot in [[-180.0, -146.0, -188.0, -160.0], [-112.0, -78.0, -86.0, -58.0]]:
		var x0: float = lot[0]
		var x1: float = lot[1]
		var z0: float = lot[2]
		var z1: float = lot[3]
		var y: float = maxf(_ground_at(x0, z0), _ground_at(x1, z1)) + 0.05
		PGK.blk(lk, lkit, "matte", Vector3(x0, y - 0.4, z0), Vector3(x1, y, z1), Color(0.20, 0.21, 0.22))
		var bay := 4.4
		var depth := 9.0
		var n: int = int((x1 - x0) / bay)
		for row in 2:
			var zr: float = z0 if row == 0 else z1 - depth
			for i in n + 1:
				var bx: float = x0 + float(i) * bay
				PGK.blk(lk, lkit, "alu", Vector3(bx - 0.06, y, zr + 0.3), Vector3(bx + 0.06, y + 0.01, zr + depth - 0.3), Color(0.9, 0.9, 0.88))
			for i in n:
				if rng.randf() < 0.35:
					continue
				var cx: float = x0 + (float(i) + 0.5) * bay
				var cz: float = zr + depth * 0.5
				var yaw: float = 0.0 if row == 0 else PI
				pk.set_frame(Transform3D(Basis(Vector3.UP, yaw + rng.randf_range(-0.04, 0.04)).scaled(Vector3.ONE * PROP_SCALE),
						Vector3(cx, y, cz)))
				camp.vehicle(kit, "suv" if rng.randf() < 0.5 else "van", cols[rng.randi() % cols.size()], rng.randi() % 2)
				_box_shape(body, Transform3D(Basis(Vector3.UP, yaw), Vector3(cx, y + 1.5 * PROP_SCALE * 0.6, cz)),
						Vector3(2.0, 1.8, 5.2) * PROP_SCALE)
		_note_rect(Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5), x1 - x0, z1 - z0, 0.0, 3.0)
	pk.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "CarParkCars"
	mi.mesh = _save_res(pk.commit(kit), "carpark_cars", stem + "prop_")
	mi.visibility_range_end = 900.0
	holder.add_child(mi)
	var li := MeshInstance3D.new()
	li.name = "CarParkPaving"
	li.mesh = _save_building_mesh(PGK.commit(lk, lkit), "carpark_paving")
	holder.add_child(li)


## Guardrail pieces along the lap from s0 to s1 on one side (-1 left), with a box collider along them.
func _rails(body: StaticBody3D, s0: float, s1: float, side: float) -> void:
	var s: float = s0
	while s < s1 - 0.5:
		var sb: float = minf(s + 12.0, s1)
		var a: Vector3 = lap.pt(s) + lap.rt(s) * side * (lap.half + 4.0)
		var b: Vector3 = lap.pt(sb) + lap.rt(sb) * side * (lap.half + 4.0)
		a.y = _ground_at(a.x, a.z)
		b.y = _ground_at(b.x, b.z)
		_put_world("guard", a, prop_kit, "guardrail", [_life(a), _life(b)], 600.0)
		# A box along the piece as drawn, on the ground it stands on (the lap's own height is metres off it on the
		# hill's corners).
		var l: float = a.distance_to(b)
		if l > 0.1:
			var fwd: Vector3 = (b - a) / l
			var x: Vector3 = Vector3.UP.cross(fwd).normalized()
			_box_shape(body, Transform3D(Basis(x, fwd.cross(x).normalized(), fwd).orthonormalized(),
					(a + b) * 0.5 + Vector3(0, 0.5, 0)), Vector3(0.4, 1.8, l + 0.3))
		s = sb


## Cones along both edges of the chicane and on the hairpin's apex: knocked flying by any cart (KnockableProps, as on
## Lakeside). DressingColliders gives nothing on this level a collider ("track" is in the level's name), so every prop
## here brings its own.
func _build_cones(root: Node3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var spots: Array = []
	var s: float = s_chic0 - 10.0
	while s < s_chic1 + 10.0:
		for side in [-1.0, 1.0]:
			spots.append(lap.spot(s, side * (lap.half + 0.6), 0.0)["pos"])
		s += 5.0
	for k in range(-3, 4):
		spots.append(lap.spot(s_hairpin + float(k) * 4.0, lap.half + 0.6, 0.0)["pos"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 41
	var xfs: Array[Transform3D] = []
	for p in spots:
		var q: Vector3 = p
		q.y = _ground_at(q.x, q.z)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), q))
	var kit := {}
	pk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PROP_SCALE), Vector3.ZERO))
	camp.cone(kit)
	pk.reset_frame()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _save_res(pk.commit(kit), "cone", stem + "prop_")
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Cones"
	mmi.set_script(load("res://KnockableProps.gd"))
	mmi.set("prop_transforms", xfs)
	mmi.set("boxes", [[Vector3(0, 0.03, 0) * PROP_SCALE, Vector3(0.38, 0.06, 0.38) * PROP_SCALE],
			[Vector3(0, 0.36, 0) * PROP_SCALE, Vector3(0.2, 0.62, 0.2) * PROP_SCALE]])
	mmi.set("prop_mass", 6.0)
	mmi.set("push_speed", 1.5)
	mmi.set("release_radius", 3.2)
	mmi.set("centre_of_mass_y", 0.06)
	mmi.multimesh = mm
	mmi.visibility_range_end = 500.0
	root.add_child(mmi)


## The paddock north of the start straight: gazebos over tables, the team's vehicles.
func _build_paddock(root: Node3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var kit := {}
	var fin: float = _finish_s()
	var body := StaticBody3D.new()
	body.name = "PaddockBody"
	root.add_child(body)
	var canopies := [Color(0.95, 0.80, 0.10), Color(0.10, 0.40, 0.85), Color(0.90, 0.20, 0.15), Color(0.12, 0.62, 0.40)]
	for i in range(4):
		var sp: Dictionary = lap.spot(fin - 40.0 + float(i) * 26.0, -(lap.half + 24.0), 0.0)
		var pos: Vector3 = sp["pos"]
		pos.y = _ground_at(pos.x, pos.z)
		var fwd: Vector3 = sp["fwd"]
		var xf := Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)).rotated(Vector3.UP, PI * 0.5), pos)
		pk.set_frame(xf.scaled_local(Vector3.ONE * PROP_SCALE * 1.4))
		camp.gazebo(kit, canopies[i], i % 2 == 0)
		pk.set_frame(xf.translated_local(Vector3(0, 0, 0)).scaled_local(Vector3.ONE * PROP_SCALE))
		camp.folding_table(kit, Color(0.92, 0.92, 0.90))
		# The gazebo's four legs and the table (life size 1.84 x 0.74 x 0.76m), solid.
		var gs: float = PROP_SCALE * 1.4
		for lx in [-1.47, 1.47]:
			for lz in [-1.47, 1.47]:
				_box_shape(body, xf * Transform3D(Basis(), Vector3(lx, 1.03, lz) * gs), Vector3(0.12, 2.06, 0.12) * gs)
		_box_shape(body, xf * Transform3D(Basis(), Vector3(0, 0.37, 0) * PROP_SCALE), Vector3(1.84, 0.74, 0.76) * PROP_SCALE)
		if i % 2 == 0:
			# The walled gazebo's back wall and its two side banners.
			_box_shape(body, xf * Transform3D(Basis(), Vector3(0, 1.03, 1.5) * gs), Vector3(2.94, 2.06, 0.1) * gs)
			for wx in [-1.49, 1.49]:
				_box_shape(body, xf * Transform3D(Basis(), Vector3(wx, 0.45, 0) * gs), Vector3(0.1, 0.9, 2.94) * gs)
		var vp: Dictionary = lap.spot(fin - 40.0 + float(i) * 26.0 + 2.0, -(lap.half + 40.0), 0.0)
		var vpos: Vector3 = vp["pos"]
		vpos.y = _ground_at(vpos.x, vpos.z)
		var vxf := Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)), vpos)
		pk.set_frame(vxf.scaled_local(Vector3.ONE * PROP_SCALE))
		camp.vehicle(kit, ["motorhome", "van", "suv", "van"][i], [Color(0.95, 0.95, 0.93), Color(0.20, 0.30, 0.55), Color(0.55, 0.10, 0.10), Color(0.85, 0.85, 0.82)][i], i % 2)
		var bs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(4.0, 3.0, 9.0) * PROP_SCALE
		bs.shape = bx
		bs.transform = Transform3D(vxf.basis, vpos + Vector3(0, 1.5 * PROP_SCALE, 0))
		body.add_child(bs)
	pk.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "Paddock"
	mi.mesh = _save_res(pk.commit(kit), "paddock", stem + "prop_")
	mi.visibility_range_end = 900.0
	root.add_child(mi)


## Woods round the proving ground, well back from the lap.
func _tree_pick(x: float, z: float, roll: float, rng: RandomNumberGenerator) -> Array:
	if _road_dist(x, z) < 70.0:
		return []
	var w: float = smoothstep(0.1, 0.45, n_wood.get_noise_2d(x, z) * 0.5 + 0.5)
	if roll > w * 0.55:
		return []
	if rng.randf() < 0.2:
		return ["momiji", rng.randf_range(0.9, 1.2)]
	return ["sugi", rng.randf_range(0.8, 1.2), rng.randi_range(0, 1)]


func _strip_material(kind: int) -> Material:
	var m := ShaderMaterial.new()
	m.shader = load("res://test_surface.gdshader")
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	m.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	m.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	m.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	m.set_shader_parameter("wood_tex", load("res://materials/wood_planks.png"))
	m.set_shader_parameter("cobble_tex", load("res://materials/cobblestone.png"))
	return _save_res(m, "strip_material_%d" % kind)


## Each patch: a ribbon over the road (its width and a little more), STRIP_LIFT up, in its own body named for the surface
## with "Road" in it (track to PlayerCart) and the surface in its meta; the word painted on the road at its start and a
## board beside it.
func _build_strip(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "SurfaceStrip"
	root.add_child(holder)
	for i in range(STRIP.size()):
		var surf: String = STRIP[i][0]
		var x0: float = STRIP_X0 - float(i) * (STRIP_PATCH + STRIP_GAP)
		var s0: float = lap.closest_s(Vector2(x0, STRIP_Z))
		var s1: float = lap.closest_s(Vector2(x0 - STRIP_PATCH, STRIP_Z))
		var half: float = lap.half + 0.4
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cols := 8
		var s := s0
		var rows: Array = []
		while true:
			var row: Array = []
			for c in range(cols + 1):
				var lat: float = lerpf(-half, half, float(c) / float(cols))
				row.append([lap.surf(s, lat) + Vector3(0, STRIP_LIFT, 0), Vector2(s - s0, lat)])
			rows.append(row)
			if s >= s1:
				break
			s = minf(s + 1.0, s1)
		for k in range(rows.size() - 1):
			for c in range(cols):
				var a: Array = rows[k][c]
				var b: Array = rows[k][c + 1]
				var c2: Array = rows[k + 1][c + 1]
				var d: Array = rows[k + 1][c]
				for v in [a, c2, b, a, d, c2]:
					st.set_normal(Vector3.UP)
					st.set_uv(v[1])
					st.add_vertex(v[0])
		st.generate_normals()
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, _strip_material(int(STRIP[i][1])))
		mesh = _save_res(mesh, "strip_%s" % surf) as ArrayMesh
		var body := StaticBody3D.new()
		body.name = "TestStrip%sRoad" % surf.capitalize()
		body.set_meta(&"surface", surf)
		holder.add_child(body)
		var mi := MeshInstance3D.new()
		mi.name = "Patch"
		mi.mesh = mesh
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		# The word on the road, just past the patch's start, and a board on the right.
		var word := Label3D.new()
		word.name = "Word"
		word.text = String(STRIP[i][2])
		word.font_size = 256
		word.pixel_size = 0.012
		word.outline_size = 0
		word.modulate = Color(1.0, 1.0, 1.0, 0.85) if i != 1 and i != 2 else Color(0.15, 0.25, 0.45, 0.85)
		var wp: Dictionary = lap.spot(s0 + 4.0, 0.0, STRIP_LIFT + 0.02)
		word.position = wp["pos"]
		word.rotation = Vector3(-PI * 0.5, deg_to_rad(float(wp["yaw"])), 0.0)
		holder.add_child(word)
		_sign(root, "Strip_" + surf, s0 - 2.0, lap.half + 3.5, String(STRIP[i][2]), Color(0.10, 0.12, 0.16))
		print("  strip: %s %.0f-%.0fm" % [surf, s0, s1])


## A board on two posts beside the lap at s (lateral `lat`, + right of travel) facing the oncoming cars.
func _sign(root: Node3D, sign_name: String, s: float, lat: float, words: String, board := Color(0.08, 0.30, 0.62)) -> void:
	var w: float = maxf(3.0, 0.62 * float(words.length()) + 1.2)
	# `lat` is the board's inner edge.
	var sp: Dictionary = lap.spot(s, lat + w * 0.5, 0.0)
	var y: float = _ground_at((sp["pos"] as Vector3).x, (sp["pos"] as Vector3).z)
	# A body of its own: DressingColliders gives nothing on this level a collider ("track" is in its name).
	var n := StaticBody3D.new()
	n.name = "Sign_" + sign_name
	n.set_meta(&"surface", "rock")
	n.position = Vector3((sp["pos"] as Vector3).x, y, (sp["pos"] as Vector3).z)
	# Facing back down the road, toward the cars coming.
	n.rotation = Vector3(0.0, deg_to_rad(float(sp["yaw"])) + PI, 0.0)
	root.add_child(n)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = board
	mat.roughness = 0.6
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.75, 0.76, 0.78)
	post_mat.metallic = 0.6
	post_mat.roughness = 0.4
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 1.5, 0.12)
	bm.material = mat
	var bi := MeshInstance3D.new()
	bi.name = "SignBoard"
	bi.mesh = bm
	bi.position = Vector3(0, 3.3, 0)
	n.add_child(bi)
	for sx in [-1.0, 1.0]:
		var pm := CylinderMesh.new()
		pm.top_radius = 0.09
		pm.bottom_radius = 0.09
		pm.height = 4.3
		pm.material = post_mat
		var post := MeshInstance3D.new()
		post.name = "SignPost"
		post.mesh = pm
		post.position = Vector3(sx * (w * 0.5 - 0.5), 2.15, -0.1)
		n.add_child(post)
		var pc := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.12
		cyl.height = 4.3
		pc.shape = cyl
		pc.position = post.position
		n.add_child(pc)
	var bc := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(w, 1.5, 0.2)
	bc.shape = bshape
	bc.position = Vector3(0, 3.3, 0)
	n.add_child(bc)
	for face in [1.0, -1.0]:
		var lb := Label3D.new()
		lb.text = words
		lb.font_size = 96
		lb.pixel_size = 0.01
		lb.outline_size = 0
		lb.modulate = Color.WHITE
		lb.position = Vector3(0, 3.3, 0.07 * face)
		lb.rotation = Vector3(0, 0.0 if face > 0.0 else PI, 0)
		lb.double_sided = false
		n.add_child(lb)


func _build_signs(root: Node3D) -> void:
	var fin: float = _finish_s()
	_sign(root, "TopSpeed", fin + 20.0, lap.half + 4.0, "TOP SPEED STRAIGHT")
	for d in [300, 200, 100]:
		_sign(root, "Board%d" % d, s_p1 - float(d) - 30.0, lap.half + 3.0, str(d), Color(0.10, 0.10, 0.12))
	_sign(root, "Hairpin", s_hairpin - 70.0, lap.half + 4.0, "HAIRPIN")
	_sign(root, "TableTop", s_hairpin + 40.0, lap.half + 4.0, "TABLE-TOP JUMP")
	_sign(root, "Chicane", s_chic0 - 25.0, lap.half + 4.0, "CHICANE")
	_sign(root, "Strip", s_strip0 - 25.0, lap.half + 4.0, "SURFACE STRIP", Color(0.62, 0.30, 0.06))
	_sign(root, "Hill", s_crest - 60.0, lap.half + 4.0, "HILL + CREST JUMP")
