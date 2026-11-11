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
	_build_cones(root)
	# Guardrails round the outside of the corners (every corner turns right: the outside is the left).
	var body: StaticBody3D = _body(root, "GuardrailBody_Lap")
	for c in [Vector2(300.0, -120.0), Vector2(300.0, 170.0), Vector2(-280.0, STRIP_Z), Vector2(-280.0, -120.0)]:
		var sc: float = lap.closest_s(c)
		_rails(body, sc - 60.0, sc + 60.0, -1.0)


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
		s = sb
	_edge_boxes(body, lap, s0, s1, side * (lap.half + 4.0), 1.2, 0.4)


## Cones along both edges of the chicane and on the hairpin's apex.
func _build_cones(root: Node3D) -> void:
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var kit := {}
	var spots: Array = []
	var s: float = s_chic0 - 10.0
	while s < s_chic1 + 10.0:
		for side in [-1.0, 1.0]:
			spots.append(lap.spot(s, side * (lap.half + 0.6), 0.0)["pos"])
		s += 5.0
	for k in range(-3, 4):
		spots.append(lap.spot(s_hairpin + float(k) * 4.0, lap.half + 0.6, 0.0)["pos"])
	for p in spots:
		var q: Vector3 = p
		q.y = _ground_at(q.x, q.z)
		pk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PROP_SCALE), q))
		camp.cone(kit)
	pk.reset_frame()
	var mi := MeshInstance3D.new()
	mi.name = "Cones"
	mi.mesh = _save_res(pk.commit(kit), "cones", stem + "prop_")
	mi.visibility_range_end = 500.0
	root.add_child(mi)


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
	var n := Node3D.new()
	n.name = "Sign_" + sign_name
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
