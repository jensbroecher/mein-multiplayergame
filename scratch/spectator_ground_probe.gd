extends SceneTree

# Checks a level's spectators and grandstands against the ground they stand on (headless):
#   Godot --headless --path . -s res://scratch/spectator_ground_probe.gd -- [level=res://levels/LakesideLevel.tscn] [tol=0.05]
# For every GrandstandBody<n>: the ground under the corners of its base (from its collision hull's lowest
# points) against the base's height. For every 3D figure (CrowdNear_* MultiMesh instances): the ground under
# it against its origin, which is the feet for a standing spectator (seated ones are skipped). Lists everyone
# sunk more than `tol`. Works without Level.gd running (it doesn't compile under -s): the terrain's and the
# dressing's colliders are saved in the level.

var level_path := "res://levels/LakesideLevel.tscn"
var tol := 0.05


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("tol="):
			tol = float(a.substr(4))
	var level: Node = (load(level_path) as PackedScene).instantiate()
	root.add_child(level)
	for i in 6:
		await physics_frame
	var space := (level as Node3D).get_world_3d().direct_space_state
	var stands: Array = []
	_find(level, func(n: Node) -> bool: return n is StaticBody3D and String(n.name).begins_with("GrandstandBody"), stands)
	var stand_rids: Array[RID] = []
	for s in stands:
		stand_rids.append((s as CollisionObject3D).get_rid())
	for s in stands:
		var body := s as StaticBody3D
		for c in body.get_children():
			if not (c is CollisionShape3D and (c as CollisionShape3D).shape is ConvexPolygonShape3D):
				continue
			var cs := c as CollisionShape3D
			var pts: PackedVector3Array = (cs.shape as ConvexPolygonShape3D).points
			var lo := INF
			for p in pts:
				lo = minf(lo, (cs.global_transform * p).y)
			var line := ""
			var worst := -INF
			var mid := Vector3.ZERO
			for p in pts:
				mid += cs.global_transform * p
			mid /= pts.size()
			for p in pts:
				var w: Vector3 = cs.global_transform * p
				if w.y > lo + 0.01:
					continue
				var g := _ground(space, w, stand_rids, 30.0)
				worst = maxf(worst, g - w.y)
				line += " %.2f" % (g - w.y)
			print("%s (middle %.1f, %.1f, %.1f) base y %.2f, ground over the base at its corners:%s  -> %s" % [body.name, mid.x, mid.y, mid.z, lo, line, "SUNK %.2fm" % worst if worst > tol else "ok"])
	var mmis: Array = []
	_find(level, func(n: Node) -> bool: return n is MultiMeshInstance3D and String(n.name).begins_with("CrowdNear_"), mmis)
	var total := 0
	var sunk := 0
	for m in mmis:
		var mmi := m as MultiMeshInstance3D
		var mm := mmi.multimesh
		var buf := mm.buffer
		for i in mm.instance_count:
			var o := i * 16
			var t := Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]), Vector3(buf[o + 2], buf[o + 6], buf[o + 10])), Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
			t = mmi.global_transform * t
			var pose := clampi(int(floor(buf[o + 14] * 16.0)), 0, 15)
			total += 1
			# From 1.5m over the feet (not from high up: a gazebo's roof isn't the ground), past the stands
			# (a fan standing on a foot board is inside the stand's wedge-shaped hull).
			var g := _ground(space, t.origin, stand_rids, 1.5)
			if pose >= 7 and g - t.origin.y > tol:
				sunk += 1
				print("  standing spectator at (%.1f, %.1f, %.1f) pose %d: ground %.2fm over the feet" % [t.origin.x, t.origin.y, t.origin.z, pose, g - t.origin.y])
	print("figures: %d, standing ones sunk: %d" % [total, sunk])
	quit()


## The highest solid surface under `p` (from `up` over it), ignoring `skip`.
func _ground(space: PhysicsDirectSpaceState3D, p: Vector3, skip: Array[RID], up: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0.03, up, 0.017), p + Vector3(0.03, -30.0, 0.017))
	q.exclude = skip
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if hit else -INF


func _find(n: Node, pred: Callable, out: Array) -> void:
	if pred.call(n):
		out.append(n)
	for c in n.get_children():
		_find(c, pred, out)
