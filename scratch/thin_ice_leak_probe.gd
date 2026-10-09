extends Node

# Looks for places round the Thin Ice, outside the holes, where the ground under a downward ray is
# below `below`: a gap in the ice sheet that shows the lead's pit under it.
#   Godot --headless --path . res://scratch/thin_ice_leak_probe.tscn -- [step=0.25] [below=1.6]

func _ready() -> void:
	var step := 0.25
	var below := 1.6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("below="):
			below = float(a.substr(6))
	var level: Node = load("res://levels/NorthlightCavernsLevel.tscn").instantiate()
	add_child(level)
	for i in 3:
		await get_tree().physics_frame
	var sheet := level.find_child("ThinIceSheet", true, false) as Node3D
	var faces: PackedVector3Array = ((sheet.get_node("SheetCollision") as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
	var box := Rect2(faces[0].x, faces[0].z, 0.0, 0.0)
	for v in faces:
		box = box.expand(Vector2(v.x, v.z))
	box = box.grow(4.0)
	var holes: Array = []
	for n in level.find_children("ThinIceHoleBarrier_*", "", true, false):
		var cyl := (n.get_child(0) as CollisionShape3D).shape as CylinderShape3D
		holes.append(Vector3(n.global_position.x, n.global_position.z, cyl.radius / 0.9))
	var space := get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 0xFFFFFFFF & ~4
	var bad: Array = []
	var x := box.position.x
	while x <= box.end.x:
		var z := box.position.y
		while z <= box.end.y:
			var in_hole := false
			for h in holes:
				if Vector2(x - h.x, z - h.y).length() < h.z * 1.2:
					in_hole = true
					break
			if not in_hole:
				q.from = Vector3(x, 30.0, z)
				q.to = Vector3(x, -20.0, z)
				var hit := space.intersect_ray(q)
				var y: float = hit["position"].y if hit else -99.0
				if y < below:
					bad.append(Vector3(x, y, z))
			z += step
		x += step
	# Group neighbouring bad points into patches.
	var seen := {}
	var patches: Array = []
	for i in bad.size():
		if seen.has(i):
			continue
		var stack := [i]
		seen[i] = true
		var pts: Array = []
		while not stack.is_empty():
			var k: int = stack.pop_back()
			pts.append(bad[k])
			for j in bad.size():
				if not seen.has(j) and Vector2(bad[j].x - bad[k].x, bad[j].z - bad[k].z).length() <= step * 1.5:
					seen[j] = true
					stack.append(j)
		patches.append(pts)
	print("holes %d" % holes.size())
	print("LEAK probe: %d bad points in %d patches (box %s)" % [bad.size(), patches.size(), box])
	for pts in patches:
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for p in pts:
			lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
			hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
		print("  patch %4d pts  x %.1f..%.1f  z %.1f..%.1f  ground y %.2f..%.2f" % [pts.size(), lo.x, hi.x, lo.z, hi.z, lo.y, hi.y])
	get_tree().quit()

