@tool
extends Node3D
## Classic open loop-the-loop (NOT a sealed barrel).
## - Open U road (floor + low walls, no ceiling)
## - Short entry/exit ramps outside the ring only
## - Bottom of the loop IS the road you drive on, then it curves up
##
## Place on the ground. Approach from local -Z. Needs speed / boost.

@export_group("Shape")
@export var loop_radius: float = 10.0:
	set(v):
		loop_radius = maxf(v, 5.0)
		_maybe_rebuild()
@export var track_width: float = 11.0:
	set(v):
		track_width = maxf(v, 5.0)
		_maybe_rebuild()
@export var wall_height: float = 1.5:
	set(v):
		wall_height = maxf(v, 0.3)
		_maybe_rebuild()
@export var wall_thickness: float = 0.5:
	set(v):
		wall_thickness = maxf(v, 0.15)
		_maybe_rebuild()
@export var road_thickness: float = 0.5:
	set(v):
		road_thickness = maxf(v, 0.15)
		_maybe_rebuild()
@export var path_segments: int = 48:
	set(v):
		path_segments = clampi(v, 24, 96)
		_maybe_rebuild()

@export_group("Approaches")
@export var approach_length: float = 14.0:
	set(v):
		approach_length = maxf(v, 6.0)
		_maybe_rebuild()

@export_group("Look")
@export var asphalt_color: Color = Color(0.2, 0.2, 0.22, 1.0)
@export var wall_color: Color = Color(0.55, 0.45, 0.28, 1.0)

@export_group("Tools")
@export var rebuild_now: bool = false:
	set(v):
		if v:
			rebuild_now = false
			if is_inside_tree():
				_rebuild()

var _building: bool = false


func _ready() -> void:
	add_to_group("loop_track")
	add_to_group("collision_trimesh")
	call_deferred("_rebuild")


func _maybe_rebuild() -> void:
	if Engine.is_editor_hint() and is_inside_tree() and not _building:
		call_deferred("_rebuild")


func _rebuild() -> void:
	if _building or not is_inside_tree():
		return
	_building = true

	for child in get_children():
		remove_child(child)
		child.free()

	var road_mat := _mat_asphalt()
	var wall_mat := _mat_wall()

	# Full circle of OPEN U-channel (no ceiling → not a barrel)
	var frames: Array = []
	for i in range(path_segments):
		var a: float = float(i) / float(path_segments) * TAU
		frames.append(_frame(a))

	_add_trimesh("LoopRoad", _build_road(frames), road_mat)
	_add_trimesh("LoopWalls", _build_walls(frames), wall_mat)

	# Short ramps ONLY outside the ring (do not span under the hollow center)
	_add_outside_ramp(true, road_mat, wall_mat)
	_add_outside_ramp(false, road_mat, wall_mat)

	if Engine.is_editor_hint() and get_tree():
		_set_owner_recursive(self, get_tree().edited_scene_root)

	_building = false


## a=0 bottom at (0,0,0), tangent +Z. Road normal toward loop center.
func _frame(a: float) -> Dictionary:
	var r: float = loop_radius
	var o := Vector3(0.0, r * (1.0 - cos(a)), r * sin(a))
	var tangent := Vector3(0.0, sin(a), cos(a)).normalized()
	var center := Vector3(0.0, r, 0.0)
	var up: Vector3 = (center - o).normalized()
	var right: Vector3 = tangent.cross(up)
	if right.length_squared() < 1e-8:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	up = right.cross(tangent).normalized()
	return {"o": o, "t": tangent, "r": right, "u": up}


func _build_road(frames: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = track_width * 0.5
	var th: float = road_thickness
	var n: int = frames.size()

	# Non-indexed so each face gets the correct frame normal (driveable side = toward center).
	for i in range(n):
		var f0: Dictionary = frames[i]
		var f1: Dictionary = frames[(i + 1) % n]
		var o0: Vector3 = f0["o"]
		var o1: Vector3 = f1["o"]
		var r0: Vector3 = f0["r"]
		var r1: Vector3 = f1["r"]
		var u0: Vector3 = f0["u"]
		var u1: Vector3 = f1["u"]

		var aL: Vector3 = o0 - r0 * hw
		var aR: Vector3 = o0 + r0 * hw
		var bL: Vector3 = o1 - r1 * hw
		var bR: Vector3 = o1 + r1 * hw
		var nrm: Vector3 = (u0 + u1).normalized()

		# Driveable top (normal toward loop center)
		_tri_n(st, aL, aR, bR, nrm)
		_tri_n(st, aL, bR, bL, nrm)
		# Underside
		_tri_n(st, aL - u0 * th, bL - u1 * th, bR - u1 * th, -nrm)
		_tri_n(st, aL - u0 * th, bR - u1 * th, aR - u0 * th, -nrm)

	return st.commit()


func _build_walls(frames: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw: float = track_width * 0.5
	var wh: float = wall_height
	var wt: float = wall_thickness
	var n: int = frames.size()

	for i in range(n):
		var f: Dictionary = frames[i]
		var o: Vector3 = f["o"]
		var right: Vector3 = f["r"]
		var up: Vector3 = f["u"]
		# Left wall (4) + right wall (4)
		var l0: Vector3 = o - right * hw
		var l1: Vector3 = o - right * (hw + wt)
		var l2: Vector3 = l0 + up * wh
		var l3: Vector3 = l1 + up * wh
		var r0: Vector3 = o + right * hw
		var r1: Vector3 = o + right * (hw + wt)
		var r2: Vector3 = r0 + up * wh
		var r3: Vector3 = r1 + up * wh
		for p in [l0, l1, l2, l3, r0, r1, r2, r3]:
			st.add_vertex(p)

	for i in range(n):
		var a: int = i * 8
		var b: int = ((i + 1) % n) * 8
		# Left inner, outer, top
		st.add_index(a+0); st.add_index(b+0); st.add_index(b+2)
		st.add_index(a+0); st.add_index(b+2); st.add_index(a+2)
		st.add_index(a+1); st.add_index(a+3); st.add_index(b+3)
		st.add_index(a+1); st.add_index(b+3); st.add_index(b+1)
		st.add_index(a+2); st.add_index(b+2); st.add_index(b+3)
		st.add_index(a+2); st.add_index(b+3); st.add_index(a+3)
		# Right
		st.add_index(a+4); st.add_index(a+6); st.add_index(b+6)
		st.add_index(a+4); st.add_index(b+6); st.add_index(b+4)
		st.add_index(a+5); st.add_index(b+5); st.add_index(b+7)
		st.add_index(a+5); st.add_index(b+7); st.add_index(a+7)
		st.add_index(a+6); st.add_index(a+7); st.add_index(b+7)
		st.add_index(a+6); st.add_index(b+7); st.add_index(b+6)

	st.generate_normals()
	return st.commit()


## Ramp strictly outside the ring. Entry: z in [-R_margin-L, -R_margin]. Exit: opposite.
## Top surface at y=0 matching the loop floor at the bottom.
func _add_outside_ramp(is_entry: bool, road_mat: Material, wall_mat: Material) -> void:
	var z_sign: float = -1.0 if is_entry else 1.0
	var label: String = "Entry" if is_entry else "Exit"

	# Keep clear of the ring's side bulk: start a bit outside z=0 only
	# Bottom floor is near z=0; ramp occupies z from z_sign*1.0 to z_sign*(1+length)
	var inner_z: float = z_sign * 0.8
	var outer_z: float = z_sign * (0.8 + approach_length)
	var mid_z: float = (inner_z + outer_z) * 0.5
	var len: float = absf(outer_z - inner_z)

	# Drive slab — TOP at y = 0
	var slab := CSGBox3D.new()
	slab.name = label + "Ramp"
	slab.size = Vector3(track_width, road_thickness, len)
	slab.position = Vector3(0.0, -road_thickness * 0.5, mid_z)
	slab.material = road_mat
	slab.use_collision = true
	slab.collision_layer = 1
	add_child(slab)

	# Outer lip slightly lower so terrain/road blends in
	var lip := CSGBox3D.new()
	lip.name = label + "Lip"
	lip.size = Vector3(track_width, road_thickness, len * 0.4)
	lip.position = Vector3(0.0, -road_thickness * 0.5 - 0.12, z_sign * (0.8 + approach_length - len * 0.2))
	lip.rotation_degrees = Vector3(z_sign * 6.0, 0.0, 0.0)
	lip.material = road_mat
	lip.use_collision = true
	lip.collision_layer = 1
	add_child(lip)

	# Side rails on ramp only
	for side in [-1.0, 1.0]:
		var rail := CSGBox3D.new()
		rail.name = label + "Rail"
		rail.size = Vector3(wall_thickness, wall_height, len)
		rail.position = Vector3(
			side * (track_width * 0.5 + wall_thickness * 0.5),
			wall_height * 0.5 - 0.05,
			mid_z
		)
		rail.material = wall_mat
		rail.use_collision = true
		rail.collision_layer = 1
		add_child(rail)


func _tri_n(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(p0)
	st.set_normal(n)
	st.add_vertex(p1)
	st.set_normal(n)
	st.add_vertex(p2)


func _add_trimesh(mesh_name: String, mesh: ArrayMesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = mesh_name + "Body"
	body.collision_layer = 1
	add_child(body)
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	if shape is ConcavePolygonShape3D:
		(shape as ConcavePolygonShape3D).backface_collision = true
	cs.shape = shape
	body.add_child(cs)


func _mat_asphalt() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = asphalt_color
	mat.roughness = 0.88
	var tex = load("res://materials/asphalt.png")
	if tex:
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	return mat


func _mat_wall() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = wall_color
	mat.roughness = 0.95
	var tex = load("res://materials/dark_canyon_rock.png")
	if tex:
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.08, 0.08, 0.08)
	return mat


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if scene_root == null:
		return
	for c in node.get_children():
		c.owner = scene_root
		_set_owner_recursive(c, scene_root)
