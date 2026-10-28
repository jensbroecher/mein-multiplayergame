extends Node
## Builds non-FBX procedural chasm cliff rock formations and desert flora/rock dressing
## for CanyonChasmLevel.tscn:
##   - res://generated/canyon_chasm_rock_material.res
##   - res://generated/canyon_chasm_road_rock_material.res
##   - res://generated/canyon_chasm_cliffs.res (+ _shape.res)
##   - res://generated/canyon_chasm_dressing/*.res
##   - res://ChasmDressing.tscn

const PropKit = preload("res://PropKit.gd")
const CactusKit = preload("res://CactusKit.gd")
const SandstoneKit = preload("res://SandstoneKit.gd")
const DesertFloraKit = preload("res://DesertFloraKit.gd")

const DRESS_DIR := "res://generated/canyon_chasm_dressing/"
const DRESS_SCENE_PATH := "res://ChasmDressing.tscn"
const DRESS_CELL := 96.0
const DRESS_RANGE := {"plant": 210.0, "tall": 440.0, "rock": 380.0}
const DRESS_SWAP := {"plant": 52.0, "tall": 80.0, "rock": 65.0}

const CACTUS_KIND := {
	"saguaro": "tall",
	"organ": "tall",
	"ocotillo": "tall",
	"barrel": "plant",
	"pear": "plant",
	"cholla": "plant",
	"hedgehog": "plant",
}
const FLORA_KIND := {
	"joshua": "tall",
	"agave": "plant",
	"yucca": "plant",
	"shrub": "plant",
	"flowers": "plant",
}
const BLOCKS := 8
const STONES := 4

const FLOOR_MIX := [
	["agave", 6], ["yucca", 5], ["shrub", 7], ["flowers", 4],
	["saguaro", 6], ["organ", 3], ["ocotillo", 3], ["joshua", 3],
	["barrel", 4], ["pear", 5], ["cholla", 4], ["hedgehog", 3],
	["stones", 6], ["block", 4],
]
const HIGH_MIX := [
	["joshua", 6], ["yucca", 5], ["agave", 4], ["shrub", 6], ["flowers", 2],
	["saguaro", 3], ["organ", 2], ["ocotillo", 3], ["cholla", 4], ["pear", 3],
	["stones", 6], ["block", 5],
]
const RIM_MIX := [
	["agave", 5], ["yucca", 4], ["shrub", 6], ["flowers", 5],
	["barrel", 4], ["pear", 4], ["hedgehog", 3], ["ocotillo", 2],
	["stones", 6], ["block", 6],
]

# Height grid extracted from canyon_chasm_terrain_visual.res (801x801 over [-1000, 1000]).
const GRID_RES := 800
const GRID_STRIDE := 801
const GRID_START := -1000.0
const GRID_STEP := 2.5
var _heights := PackedFloat32Array()
var _normals := PackedVector3Array()

# Track samples along TrackPath for fast distance checks.
const CELL := 40.0
var _rs_pos := PackedVector3Array()
var _rs_right := PackedVector3Array()
var _rs_cells := {}

# Keep-out footprints (Vector3(x, z, radius)) for buildings, windmill, ramps, chasm rocks, etc.
var _keepouts: Array[Vector3] = [
	Vector3(-232.0, 65.0, 18.0),   # CasitaHouse (courtyard gets custom placement)
	Vector3(92.0, -227.0, 22.0),   # LargeHouse
	Vector3(66.3, -95.5, 18.0),    # House (AdobeHouse)
	Vector3(-92.1, -127.0, 12.0),  # Windmill
	Vector3(172.8, 57.0, 8.0),     # ArrowSign
	Vector3(227.8, -86.1, 10.0),   # DirtRamp
	Vector3(0.0, 48.2, 10.0),      # DirtRamp2
	Vector3(35.7, -99.0, 8.0),     # Barrier2
	Vector3(44.4, -110.2, 8.0),    # Barrier
	Vector3(219.2, -203.9, 10.0),  # Rock_Curve4
	Vector3(-68.3, 260.2, 10.0),   # Rock_Curve5
	Vector3(225.7, -46.7, 10.0),   # Rock_Curve6
	Vector3(163.9, 54.9, 10.0),    # Rock5
	Vector3(13.2, 120.2, 10.0),    # Rock4
	Vector3(203.7, -280.4, 10.0),  # Rock3
	Vector3(82.7, -129.1, 10.0),   # Rock
	Vector3(94.9, -296.1, 12.0),   # RockArc
	Vector3(18.5, -221.5, 10.0),   # Rock2
	Vector3(68.4, -174.7, 10.0),   # Rock6
	Vector3(69.7, -181.6, 10.0),   # Rock7
	Vector3(69.7, -192.1, 10.0),   # Rock8
]

var _rock_mat: ShaderMaterial
var _dress_meshes := {}
var _dress_far := {}
var _dress_heights := {}
var _dress_radius := {}
var _dress_aabb := {}
var _dress_trunk := {}


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	print("=== Generating Canyon Chasm Cliffs & Non-FBX Desert Dressing ===")
	if not DirAccess.dir_exists_absolute("res://generated/"):
		DirAccess.make_dir_absolute("res://generated/")
	if not DirAccess.dir_exists_absolute(DRESS_DIR):
		DirAccess.make_dir_absolute(DRESS_DIR)

	_load_terrain_and_track()
	_build_rock_materials()

	var root := Node3D.new()
	# Named CanyonDressing so Level.gd does not bake slow runtime trimesh colliders on MultiMeshes.
	root.name = "CanyonDressing"
	root.set_script(load("res://CanyonDetail.gd"))

	_build_chasm_cliffs(root)
	_build_dressing(root)

	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(root)
	if pack_err != OK:
		push_error("Failed to pack ChasmDressing.tscn: %d" % pack_err)
		get_tree().quit(1)
		return
	var save_err: Error = ResourceSaver.save(packed, DRESS_SCENE_PATH)
	if save_err != OK:
		push_error("Failed to save ChasmDressing.tscn: %d" % save_err)
		get_tree().quit(1)
		return
	root.free()
	print("=== Saved %s in %.2fs ===" % [DRESS_SCENE_PATH, (Time.get_ticks_msec() - t0) / 1000.0])
	get_tree().quit(0)


func _load_terrain_and_track() -> void:
	var terrain_mesh: ArrayMesh = load("res://generated/canyon_chasm_terrain_visual.res")
	var arrays: Array = terrain_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_heights.resize(GRID_STRIDE * GRID_STRIDE)
	_normals.resize(GRID_STRIDE * GRID_STRIDE)
	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		var ix: int = clampi(roundi((v.x - GRID_START) / GRID_STEP), 0, GRID_RES)
		var iz: int = clampi(roundi((v.z - GRID_START) / GRID_STEP), 0, GRID_RES)
		var idx: int = iz * GRID_STRIDE + ix
		_heights[idx] = v.y
		_normals[idx] = nrms[i]

	var level_ps: PackedScene = load("res://levels/CanyonChasmLevel.tscn")
	var level: Node = level_ps.instantiate()
	var track_path: Path3D = level.get_node("TrackPath")
	var curve: Curve3D = track_path.curve
	var xform: Transform3D = track_path.transform
	var length: float = curve.get_baked_length()
	var step := 2.0
	var s := 0.0
	while s < length:
		var p: Vector3 = xform * curve.sample_baked(s)
		var p_next: Vector3 = xform * curve.sample_baked(fposmod(s + 1.0, length))
		var fwd: Vector3 = p_next - p
		fwd.y = 0.0
		fwd = fwd.normalized() if fwd.length_squared() > 1e-6 else Vector3.FORWARD
		var right: Vector3 = fwd.cross(Vector3.UP).normalized()
		var k: int = _rs_pos.size()
		_rs_pos.append(p)
		_rs_right.append(right)
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		var bucket: PackedInt32Array = _rs_cells.get(key, PackedInt32Array())
		bucket.append(k)
		_rs_cells[key] = bucket
		s += step
	level.free()
	print("  loaded terrain grid (%dx%d) and %d track samples" % [GRID_STRIDE, GRID_STRIDE, _rs_pos.size()])


func _ground_at(x: float, z: float) -> float:
	var fx: float = clampf((x - GRID_START) / GRID_STEP, 0.0, float(GRID_RES - 1))
	var fz: float = clampf((z - GRID_START) / GRID_STEP, 0.0, float(GRID_RES - 1))
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	var i00: int = iz * GRID_STRIDE + ix
	var h00: float = _heights[i00]
	var h10: float = _heights[i00 + 1]
	var h01: float = _heights[i00 + GRID_STRIDE]
	var h11: float = _heights[i00 + GRID_STRIDE + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _normal_at(x: float, z: float) -> Vector3:
	var ix: int = clampi(roundi((x - GRID_START) / GRID_STEP), 0, GRID_RES)
	var iz: int = clampi(roundi((z - GRID_START) / GRID_STEP), 0, GRID_RES)
	return _normals[iz * GRID_STRIDE + ix]


func _road_dist(x: float, z: float) -> float:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best_d2 := 1e12
	var n: int = _rs_pos.size()
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _rs_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var j: int = (i + 1) % n
				var a: Vector3 = _rs_pos[i]
				var b: Vector3 = _rs_pos[j]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = sx * sx + sz * sz
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / maxf(l2, 1e-5), 0.0, 1.0)
				var dx: float = x - (a.x + sx * t)
				var dz: float = z - (a.z + sz * t)
				var d2: float = dx * dx + dz * dz
				if d2 < best_d2:
					best_d2 = d2
	return sqrt(best_d2)


func _in_chasm_box(x: float, z: float, pad: float = 0.0) -> bool:
	return x > (112.0 - pad) and x < (188.0 + pad) and z > (-150.0 - pad) and z < (-34.0 + pad)


func _in_keepout(x: float, z: float, extra: float = 0.0) -> bool:
	for ko in _keepouts:
		if Vector2(x - ko.x, z - ko.y).length() < ko.z + extra:
			return true
	return false


func _rock_normal_texture() -> Texture2D:
	if ResourceLoader.exists("res://generated/canyon_rock_normal.res"):
		return load("res://generated/canyon_rock_normal.res")
	var img: Image = (load("res://materials/dark_rock.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	img.bump_map_to_normal_map(5.0)
	img.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, true, 0.9)
	return _save_res(tex, "res://generated/canyon_rock_normal.res")


func _build_rock_materials() -> void:
	var rock_normal: Texture2D = _rock_normal_texture()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://canyon_rock.gdshader")
	mat.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	mat.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	mat.set_shader_parameter("rock_normal", rock_normal)
	mat.set_shader_parameter("tint", Color(0.68, 0.44, 0.30, 1.0))
	mat.set_shader_parameter("tint_amount", 0.28)
	mat.set_shader_parameter("vertex_occlusion", true)
	_rock_mat = _save_res(mat, "res://generated/canyon_chasm_rock_material.res")

	var road_rock := ShaderMaterial.new()
	road_rock.shader = load("res://canyon_rock.gdshader")
	road_rock.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	road_rock.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	road_rock.set_shader_parameter("rock_normal", rock_normal)
	road_rock.set_shader_parameter("tint", Color(0.68, 0.46, 0.34, 1.0))
	road_rock.set_shader_parameter("tint_amount", 0.32)
	road_rock.set_shader_parameter("vertex_occlusion", false)
	_save_res(road_rock, "res://generated/canyon_chasm_road_rock_material.res")


## Builds the 3D sculpted sandstone cliff gorge around the chasm water pit (x in [114, 186],
## z in [-148, -36]), cladding the stretched terrain trench walls and the lower ramp faces
## while keeping the road deck (x in [140, 160]) and jump flight path completely clear.
func _build_chasm_cliffs(parent: Node3D) -> void:
	var t0: int = Time.get_ticks_msec()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var seed_seq := 8100

	# 1. West & East Chasm Gorge Walls (z from -145 to -38, keeping x in [126, 174] open water)
	for side in [-1.0, 1.0]:
		var wall_x: float = 150.0 + side * 30.5
		# Tier 0: Waterline & lower cliff buttresses (y = -4.5 .. 9.0)
		var z0 := -142.0
		while z0 <= -40.0:
			seed_seq += 1
			var cx: float = wall_x - side * rng.randf_range(0.0, 2.0)
			var cy: float = rng.randf_range(0.5, 2.8)
			var cz: float = z0 + rng.randf_range(-1.5, 1.5)
			var sx: float = rng.randf_range(9.5, 12.5)
			var sy: float = rng.randf_range(13.5, 17.5)
			var sz: float = rng.randf_range(13.0, 17.5)
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.30, 0.30), rng.randf_range(-0.06, 0.06))).scaled(Vector3(sx, sy, sz))
			SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(cx, cy, cz), b, 1.0, rng.randf_range(0.35, 0.58))
			z0 += 7.5

		# Tier 1: Mid cliff strata slabs & pillars (y = 7.0 .. 19.5)
		var z1 := -144.0
		while z1 <= -38.0:
			seed_seq += 1
			var cx: float = wall_x + side * rng.randf_range(1.0, 3.2)
			var cy: float = rng.randf_range(11.0, 13.8)
			var cz: float = z1 + rng.randf_range(-1.8, 1.8)
			var sx: float = rng.randf_range(10.5, 13.5)
			var sy: float = rng.randf_range(14.0, 18.5)
			var sz: float = rng.randf_range(14.0, 18.5)
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.25, 0.25), rng.randf_range(-0.05, 0.05))).scaled(Vector3(sx, sy, sz))
			SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(cx, cy, cz), b, 1.0, rng.randf_range(0.15, 0.35))
			z1 += 8.0

		# Tier 2: Upper rim overhanging caprock ledges (y = 16.5 .. 25.5)
		var z2 := -143.0
		while z2 <= -39.0:
			seed_seq += 1
			var cx: float = wall_x + side * rng.randf_range(2.5, 5.0)
			var rim_y: float = _ground_at(cx + side * 3.0, z2)
			var cy: float = minf(rim_y - 2.4, rng.randf_range(19.5, 22.0))
			var cz: float = z2 + rng.randf_range(-1.8, 1.8)
			var sx: float = rng.randf_range(11.0, 14.5)
			var sy: float = rng.randf_range(8.5, 11.5)
			var sz: float = rng.randf_range(14.0, 18.5)
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.22, 0.22), rng.randf_range(-0.04, 0.04))).scaled(Vector3(sx, sy, sz))
			SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(cx, cy, cz), b, 1.0, rng.randf_range(0.08, 0.22))
			z2 += 8.5

	# 2. North Chasm Wall & Takeoff Ramp Base (z in [-55, -36], keeping water open south of z = -55)
	for side in [-1.0, 1.0]:
		for step_i in range(3):
			var t: float = float(step_i) / 2.0
			var cx: float = 150.0 + side * lerpf(15.5, 27.5, t)
			var cz: float = lerpf(-44.0, -39.0, t) + rng.randf_range(-1.0, 1.0)
			for tier in range(2):
				seed_seq += 1
				var cy: float = 2.5 + float(tier) * 11.5 + rng.randf_range(-0.8, 0.8)
				var sx: float = rng.randf_range(9.5, 12.5)
				var sy: float = rng.randf_range(13.0, 16.5)
				var sz: float = rng.randf_range(9.0, 12.0)
				var b := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.30, 0.30), rng.randf_range(-0.05, 0.05))).scaled(Vector3(sx, sy, sz))
				SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(cx, cy, cz), b, 1.0, 0.38 - float(tier) * 0.16)

		# Tight ramp side-wall rock buttresses along x = 139.5 / 160.5, z in [-51, -43]
		for rz in [-50.5, -44.0]:
			seed_seq += 1
			var cx: float = 150.0 + side * 11.2
			var cy: float = rng.randf_range(7.0, 10.0)
			var sx: float = rng.randf_range(5.5, 7.2)
			var sy: float = rng.randf_range(18.0, 22.0)
			var sz: float = rng.randf_range(8.5, 11.0)
			var b := Basis.from_euler(Vector3(0.0, rng.randf_range(-0.15, 0.15), 0.0)).scaled(Vector3(sx, sy, sz))
			SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(cx, cy, rz), b, 1.0, 0.30)

	# North takeoff ramp lower cliff foot (x in [141, 159], z = -52.8, y up to 16m)
	for nx in [142.0, 147.5, 152.5, 158.0]:
		seed_seq += 1
		var cy: float = rng.randf_range(3.5, 5.5)
		var cz: float = -52.8 + rng.randf_range(-0.5, 0.5)
		var sx: float = rng.randf_range(7.5, 9.5)
		var sy: float = rng.randf_range(14.0, 17.5)
		var sz: float = rng.randf_range(6.5, 8.5)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.20, 0.20), rng.randf_range(-0.05, 0.05))).scaled(Vector3(sx, sy, sz))
		SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(nx, cy, cz), b, 1.0, 0.42)

	# 3. South Chasm Wall & Landing Ramp Base (z in [-147, -108], keeping water open on both sides)
	for side in [-1.0, 1.0]:
		for step_i in range(3):
			var t: float = float(step_i) / 2.0
			var cx: float = 150.0 + side * lerpf(15.5, 27.5, t)
			var cz: float = lerpf(-141.0, -144.0, t) + rng.randf_range(-1.0, 1.0)
			for tier in range(2):
				seed_seq += 1
				var cy: float = 2.5 + float(tier) * 11.0 + rng.randf_range(-0.8, 0.8)
				var sx: float = rng.randf_range(9.5, 12.5)
				var sy: float = rng.randf_range(12.5, 15.5)
				var sz: float = rng.randf_range(9.0, 12.0)
				var b := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.30, 0.30), rng.randf_range(-0.05, 0.05))).scaled(Vector3(sx, sy, sz))
				SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(cx, cy, cz), b, 1.0, 0.38 - float(tier) * 0.16)

		# Tight South ramp side-wall rock buttresses along x = 139.2 / 160.8, z in [-136, -113]
		for rz in [-114.0, -125.0, -135.0]:
			seed_seq += 1
			var cx: float = 150.0 + side * 11.0
			var cy: float = rng.randf_range(4.5, 7.0)
			var sx: float = rng.randf_range(5.5, 7.0)
			var sy: float = rng.randf_range(14.0, 17.5)
			var sz: float = rng.randf_range(9.5, 12.0)
			var b := Basis.from_euler(Vector3(0.0, rng.randf_range(-0.15, 0.15), 0.0)).scaled(Vector3(sx, sy, sz))
			SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(cx, cy, rz), b, 1.0, 0.32)

	# South landing ramp lower cliff foot (x in [141, 159], z = -109.2, y up to 12m)
	for sx_pos in [142.0, 147.5, 152.5, 158.0]:
		seed_seq += 1
		var cy: float = rng.randf_range(1.5, 3.5)
		var cz: float = -109.2 + rng.randf_range(-0.5, 0.5)
		var sx: float = rng.randf_range(7.5, 9.5)
		var sy: float = rng.randf_range(11.0, 14.0)
		var sz: float = rng.randf_range(6.5, 8.5)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.20, 0.20), rng.randf_range(-0.05, 0.05))).scaled(Vector3(sx, sy, sz))
		SandstoneKit._add_block(verts, cols, idx, seed_seq, 6, Vector3(sx_pos, cy, cz), b, 1.0, 0.42)

	var cliff_mesh: ArrayMesh = SandstoneKit._commit(verts, cols, idx, _rock_mat)
	cliff_mesh = _save_res(cliff_mesh, "res://generated/canyon_chasm_cliffs.res")
	var cliff_shape: ConcavePolygonShape3D = cliff_mesh.create_trimesh_shape()
	cliff_shape.backface_collision = true
	cliff_shape = _save_res(cliff_shape, "res://generated/canyon_chasm_cliffs_shape.res")

	var cliff_body := StaticBody3D.new()
	cliff_body.name = "ChasmCliffs"
	cliff_body.set_meta(&"surface", "rock")
	parent.add_child(cliff_body)

	var cliff_mi := MeshInstance3D.new()
	cliff_mi.name = "ChasmCliffsMesh"
	cliff_mi.mesh = cliff_mesh
	cliff_body.add_child(cliff_mi)

	var cliff_cs := CollisionShape3D.new()
	cliff_cs.name = "CollisionShape3D"
	cliff_cs.shape = cliff_shape
	cliff_body.add_child(cliff_cs)

	print("  built ChasmCliffs: %d tris in %.2fs" % [idx.size() / 3, (Time.get_ticks_msec() - t0) / 1000.0])


func _register_dress(kinds: Dictionary, nm: String, near: ArrayMesh, far: ArrayMesh, kind: String, scale_range: Vector2) -> void:
	var ab: AABB = near.get_aabb()
	var h: float = maxf(ab.end.y, 0.05)
	_dress_heights[nm] = h
	_dress_radius[nm] = maxf(ab.size.x, ab.size.z) * 0.5
	_dress_aabb[nm] = ab
	_dress_meshes[nm] = _save_res(near, DRESS_DIR + "dress_" + nm + ".res")
	_dress_far[nm] = _dress_meshes[nm] if far == near else _save_res(far, DRESS_DIR + "dress_" + nm + "_far.res")
	kinds[nm] = [nm, "", Vector2(h * scale_range.x, h * scale_range.y), 0, kind]


func _variant(nm: String, rng: RandomNumberGenerator) -> String:
	if CACTUS_KIND.has(nm):
		return "%s_%d" % [nm, rng.randi() % int(CactusKit.VARIANTS[nm])]
	if FLORA_KIND.has(nm):
		return "%s_%d" % [nm, rng.randi() % int(DesertFloraKit.VARIANTS[nm])]
	if nm == "block":
		return "block_%d" % (rng.randi() % BLOCKS)
	if nm == "stones":
		return "stones_%d" % (rng.randi() % STONES)
	return nm


func _pick(mix: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for m in mix:
		total += int(m[1])
	var r: int = rng.randi() % total
	for m in mix:
		r -= int(m[1])
		if r < 0:
			return m[0]
	return mix[0][0]


func _place(placed: Dictionary, nm: String, x: float, y: float, z: float, height: float, yaw: float, rng: RandomNumberGenerator) -> void:
	var sc: float = height / maxf(float(_dress_heights[nm]), 0.01)
	var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc)
	b = Basis(Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized(), rng.randf_range(0.0, 0.05)) * b
	if not placed.has(nm):
		placed[nm] = []
	placed[nm].append(Transform3D(b, Vector3(x, y - 0.05 * sc, z)))


func _build_dressing(root: Node3D) -> void:
	var t0: int = Time.get_ticks_msec()
	var kinds := {}

	var ckit := CactusKit.new()
	var cmat: Material = _save_res(ckit.material(), DRESS_DIR + "cactus_material.res")
	for sp in CactusKit.SPECIES:
		for v in range(int(CactusKit.VARIANTS[sp])):
			var nm := "%s_%d" % [sp, v]
			_register_dress(kinds, nm, ckit.build(sp, v, 0, cmat), ckit.build(sp, v, 1, cmat), CACTUS_KIND[sp], Vector2(0.85, 1.25))
			if CACTUS_KIND[sp] == "tall":
				_dress_trunk[nm] = 0.28

	var fkit := DesertFloraKit.new()
	var fmat: Material = _save_res(fkit.material(), DRESS_DIR + "flora_material.res")
	for sp2 in DesertFloraKit.SPECIES:
		for v2 in range(int(DesertFloraKit.VARIANTS[sp2])):
			var nm2 := "%s_%d" % [sp2, v2]
			_register_dress(kinds, nm2, fkit.build(sp2, v2, 0, fmat), fkit.build(sp2, v2, 1, fmat), FLORA_KIND[sp2], Vector2(0.85, 1.28))
			if FLORA_KIND[sp2] == "tall":
				_dress_trunk[nm2] = 0.32

	for v3 in range(BLOCKS):
		_register_dress(kinds, "block_%d" % v3, SandstoneKit.block(4100 + v3, 7, _rock_mat), SandstoneKit.block(4100 + v3, 2, _rock_mat), "rock", Vector2(0.9, 2.8))
	for v4 in range(STONES):
		_register_dress(kinds, "stones_%d" % v4, SandstoneKit.pebbles(5100 + v4, 12, 2, _rock_mat), SandstoneKit.pebbles(5100 + v4, 12, 1, _rock_mat), "rock", Vector2(0.85, 1.35))

	var rng := RandomNumberGenerator.new()
	rng.seed = 9421
	var placed := {}

	# 1. Scenic landmark clusters replacing the 12 former FBX plants and framing CasitaHouse, Windmill, and houses
	var hero_spots := [
		# Exact former FBX plant locations (now 100% procedural non-FBX flora)
		[-12.5, -10.3, "saguaro", 6.2],       # Cactus3
		[181.0, 47.7, "agave", 1.7],          # DesertPlant_Curve1
		[197.3, -34.1, "shrub", 1.8],         # RockBush
		[236.8, -152.7, "agave", 1.8],        # AloePlant
		[113.5, -294.2, "yucca", 2.2],        # DesertBush_Curve1
		[162.5, 27.2, "yucca", 2.1],          # DesertFern_Straight1
		[-14.5, 150.6, "joshua", 6.8],        # JehovaTree2
		[-32.4, 244.1, "shrub", 1.7],         # DesertShrub_Straight2
		[132.9, -315.2, "joshua", 6.9],       # JehovaTree
		[147.1, -284.5, "barrel", 1.3],       # SmallCactus
		[102.3, -164.3, "organ", 4.6],        # Cactus2
		[-10.8, -221.5, "saguaro", 6.4],      # Cactus
		# Framing the new CasitaHouse at (-232, 22.8, 65) along the West straight
		[-220.5, 48.0, "saguaro", 5.8],
		[-218.5, 51.5, "agave", 1.5],
		[-217.5, 54.0, "flowers", 1.1],
		[-218.0, 77.5, "joshua", 6.2],
		[-219.5, 81.0, "yucca", 2.0],
		[-217.0, 74.5, "agave", 1.4],
		[-222.0, 84.0, "block", 2.2],
		[-246.0, 49.0, "joshua", 6.6],
		[-247.0, 82.0, "saguaro", 6.0],
		# Framing the rebuilt Windmill at (-92.1, 18.8, -127.0)
		[-81.0, -121.0, "agave", 1.4],
		[-83.5, -135.0, "yucca", 1.9],
		[-102.0, -119.0, "shrub", 1.5],
		[-100.5, -136.0, "block", 2.1],
		[-78.0, -129.0, "stones", 1.2],
		# Framing LargeHouse (92.0, 22.8, -227.0) and House (66.3, 24.4, -95.5)
		[74.0, -218.0, "saguaro", 5.9],
		[76.0, -222.0, "agave", 1.5],
		[52.0, -88.0, "yucca", 2.0],
		[54.5, -92.0, "flowers", 1.1],
	]
	for hs in hero_spots:
		var hx: float = hs[0]
		var hz: float = hs[1]
		if _road_dist(hx, hz) < 13.5 or _in_chasm_box(hx, hz, 2.0):
			continue
		var hy: float = _ground_at(hx, hz)
		var hnm: String = _variant(hs[2], rng)
		var hh: float = float(hs[3])
		if hnm.begins_with("block"):
			hy -= hh * 0.25
		_place(placed, hnm, hx, hy, hz, hh, rng.randf() * TAU, rng)

	# 2. Dense roadside & canyon valley scatter along the entire track loop
	for i in range(0, _rs_pos.size(), 2):
		var p: Vector3 = _rs_pos[i]
		var right: Vector3 = _rs_right[i]
		for k in range(6):
			var side: float = -1.0 if (k % 2 == 0) else 1.0
			var u: float = rng.randf()
			var lat: float = side * (14.5 + u * u * 155.0)
			var q: Vector3 = p + right * lat + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
			_try_scatter_point(placed, kinds, q.x, q.z, rng)

	# 3. Extra clusters on the chasm rims (West & East of the chasm water pit) and midfield hills
	for k in range(700):
		var rx: float = rng.randf_range(-340.0, 360.0)
		var rz: float = rng.randf_range(-380.0, 380.0)
		_try_scatter_point(placed, kinds, rx, rz, rng)

	# 4. Build MultiMesh cells & near-road boulder/trunk colliders
	var cells := 0
	var count := 0
	var collide := StaticBody3D.new()
	collide.name = "CanyonBoulders"
	collide.set_meta(&"surface", "rock")
	root.add_child(collide)

	for nm3 in placed:
		var d3: Array = kinds[nm3]
		var kind: String = d3[4]
		var by_cell := {}
		for xf in placed[nm3]:
			var t3: Transform3D = xf
			var key := Vector2i(floori(t3.origin.x / DRESS_CELL), floori(t3.origin.z / DRESS_CELL))
			if not by_cell.has(key):
				by_cell[key] = []
			by_cell[key].append(t3)
			count += 1
			if kind != "plant" and not nm3.begins_with("stones"):
				var rd: float = _road_dist(t3.origin.x, t3.origin.z)
				if rd < 45.0:
					var sc: float = t3.basis.get_scale().x
					var cs := CollisionShape3D.new()
					if kind == "rock":
						var ab: AABB = _dress_aabb[nm3]
						var box := BoxShape3D.new()
						box.size = ab.size * sc * 0.82
						cs.shape = box
						cs.transform = Transform3D(t3.basis.orthonormalized(), t3 * ab.get_center())
					else:
						var cyl := CylinderShape3D.new()
						cyl.radius = float(_dress_trunk.get(nm3, 0.30)) * sc
						cyl.height = float(_dress_heights[nm3]) * sc * 0.58
						cs.shape = cyl
						cs.position = t3.origin + Vector3.UP * cyl.height * 0.5
					collide.add_child(cs)

		for key in by_cell:
			var list: Array = by_cell[key]
			for k in range(list.size() - 1, 0, -1):
				var j: int = rng.randi() % (k + 1)
				var tmp = list[k]
				list[k] = list[j]
				list[j] = tmp
			var prefix: String = {"plant": "Plants", "tall": "Tall", "rock": "Rocks"}[kind]
			var buf: PackedFloat32Array = PropKit.transform_buffer(list)
			var swap: float = float(DRESS_SWAP[kind])
			for far in [false, true]:
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = _dress_far[nm3] if far else _dress_meshes[nm3]
				mm.instance_count = list.size()
				mm.buffer = buf
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "%s%s_%s_%d_%d" % [prefix, "" if far else "Near", nm3, key.x, key.y]
				mmi.multimesh = mm
				if far:
					mmi.visibility_range_begin = swap
					mmi.visibility_range_end = float(DRESS_RANGE[kind])
					mmi.set_meta(&"base_range", float(DRESS_RANGE[kind]))
				else:
					mmi.visibility_range_end = swap
				if kind == "plant" or nm3.begins_with("stones"):
					mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mmi)
			cells += 1

	print("  scattered %d desert flora & rock instances in %d cells (%d colliders) in %.2fs" % [
		count, cells, collide.get_child_count(), (Time.get_ticks_msec() - t0) / 1000.0])


func _try_scatter_point(placed: Dictionary, kinds: Dictionary, x: float, z: float, rng: RandomNumberGenerator) -> void:
	if _in_chasm_box(x, z, 3.0) or _in_keepout(x, z):
		return
	var rd: float = _road_dist(x, z)
	if rd < 14.0:
		return
	var y: float = _ground_at(x, z)
	var nrm: Vector3 = _normal_at(x, z)
	var slope: float = 1.0 - nrm.y
	if y < 2.0 or slope > 0.36:
		return

	var mix: Array = FLOOR_MIX
	if _in_chasm_box(x, z, 28.0):
		mix = RIM_MIX
	elif y > 32.0:
		mix = HIGH_MIX

	var base_nm: String = _pick(mix, rng)
	var nm: String = _variant(base_nm, rng)
	var d: Array = kinds[nm]
	var kind: String = d[4]
	if kind == "tall" and (rd < 17.5 or slope > 0.22):
		return
	if kind == "rock" and not nm.begins_with("stones") and rd < 16.5:
		return

	var height: float = rng.randf_range(float(d[2].x), float(d[2].y))
	if nm.begins_with("block"):
		y -= height * 0.25
	_place(placed, nm, x, y, z, height, rng.randf() * TAU, rng)

	# Around some boulders or tall cacti, tuck a companion agave/flower/pebble cluster
	if (kind == "tall" or nm.begins_with("block")) and rng.randf() < 0.42:
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(1.6, 3.2)
		var cx: float = x + cos(ang) * dist
		var cz: float = z + sin(ang) * dist
		if _road_dist(cx, cz) >= 14.2 and not _in_chasm_box(cx, cz, 3.0) and not _in_keepout(cx, cz):
			var cy: float = _ground_at(cx, cz)
			if _normal_at(cx, cz).y > 0.72:
				var comp_pick: String = ["agave", "flowers", "shrub", "barrel", "stones"][rng.randi() % 5]
				var comp_nm: String = _variant(comp_pick, rng)
				var cd: Array = kinds[comp_nm]
				var ch: float = rng.randf_range(float(cd[2].x), float(cd[2].y))
				_place(placed, comp_nm, cx, cy, cz, ch, rng.randf() * TAU, rng)


func _save_res(res: Resource, path: String) -> Resource:
	res.take_over_path(path)
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %d" % [path, err])
	return load(path)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
