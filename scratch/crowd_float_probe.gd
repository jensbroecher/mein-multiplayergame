extends SceneTree
# Lists spectators whose feet don't rest on anything: every crowd instance (CrowdPlacer's or Nyota's
# Crowd_<x>_<z>_<class> card cells, 3D figures under CrowdNear) is raycast straight down from 1.2m over
# its origin against trimesh colliders made from every visible mesh in the level.
# Run windowed (the dummy renderer has no mesh data):
#   Godot --path . -s res://scratch/crowd_float_probe.gd -- [level=res://levels/NyotaStadiumLevel.tscn] [gap=0.25]
#       [box=x0,z0,x1,z1]
# `box` limits it to the spectators in that rectangle (and the meshes reaching into it): a whole city of
# trimeshes takes many minutes.
# Seated spectators' origins sit CROWD_SEAT_H over their tread, so only standing ones (class 2-4 cards) count.

var level_path := "res://levels/NyotaStadiumLevel.tscn"
var max_gap := 0.25
var box := Rect2(-1e6, -1e6, 2e6, 2e6)


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("gap="):
			max_gap = float(a.substr(4))
		elif a.begins_with("box="):
			var v: PackedFloat64Array = a.substr(4).split_floats(",")
			box = Rect2(minf(v[0], v[2]), minf(v[1], v[3]), absf(v[2] - v[0]), absf(v[3] - v[1]))
	_run.call_deferred()


func _run() -> void:
	var level: Node3D = load(level_path).instantiate()
	level.set_script(null)
	root.add_child(level)
	await process_frame
	var space := StaticBody3D.new()
	root.add_child(space)
	var meshes := 0
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var ab: AABB = m.global_transform * m.get_aabb()
		if not box.grow(2.0).intersects(Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z)):
			continue
		var faces: PackedVector3Array = m.mesh.get_faces()
		if faces.is_empty():
			continue
		var xf: Transform3D = m.global_transform
		for i in faces.size():
			faces[i] = xf * faces[i]
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		space.add_child(cs)
		meshes += 1
	print("colliders from %d meshes" % meshes)
	await physics_frame
	await physics_frame
	var state := space.get_world_3d().direct_space_state
	var bad := 0
	var total := 0
	for mmi in level.find_children("Crowd_*", "MultiMeshInstance3D", true, false):
		var parts: PackedStringArray = String(mmi.name).split("_")
		var cls: int = int(parts[parts.size() - 1])
		if cls < 2:
			continue
		var mm: MultiMesh = mmi.multimesh
		var buf: PackedFloat32Array = mm.buffer
		var stride: int = buf.size() / maxi(mm.instance_count, 1)
		for i in mm.instance_count:
			var o: int = i * stride
			var p: Vector3 = mmi.global_transform * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			if not box.has_point(Vector2(p.x, p.z)):
				continue
			total += 1
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 6.0)
			var hit: Dictionary = state.intersect_ray(q)
			var gap: float = 99.0 if hit.is_empty() else p.y - float(hit["position"].y)
			if absf(gap) > max_gap:
				bad += 1
				print("FLOAT %s at (%.1f, %.2f, %.1f): ground %s" % [mmi.name, p.x, p.y, p.z, "none" if hit.is_empty() else "%.2f" % hit["position"].y])
	print("%d standing spectators, %d off the ground by more than %.2fm" % [total, bad, max_gap])
	quit()
