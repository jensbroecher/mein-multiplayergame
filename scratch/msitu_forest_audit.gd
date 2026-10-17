extends SceneTree

# Audits the saved Msitu Falls level's forest against its terrain mesh: how far every plant's
# root stands above the ground, and how far the buttress roots of the canopy trees hang over the
# slope. Needs the level generated, and a window: the dummy renderer of --headless returns zeroed
# multimesh transforms.
#   Godot --path . --resolution 400x300 -s res://scratch/msitu_forest_audit.gd
# Roots should never be above the ground (a gap > 0); a few buttress feet may still hang on steep ground.

const TREE_REACH := {0: 4.8, 1: 3.5}   # metres at scale 1, TREE_SHAPES' "r" + "but" * 0.9


func _init() -> void:
	var faces := PackedVector3Array()
	for n in ["ground_collision_shape", "jungleroad_collision_shape", "matopemudroad_collision_shape"]:
		faces.append_array((load("res://generated/msitu_%s.res" % n) as ConcavePolygonShape3D).get_faces())
	var tm := TriangleMesh.new()
	tm.create_from_faces(faces)
	var level: Node3D = load("res://levels/MsituFallsLevel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var stats := {}
	var trees := 0
	var hang03 := 0
	var hang06 := 0
	var hang12 := 0
	var worst := 0.0
	for mmi in level.get_node("JungleDressing/Rainforest").get_children():
		if not (mmi is MultiMeshInstance3D):
			continue
		var nm := str(mmi.name)
		var parts := nm.split("_")
		var key := ""
		if nm.begins_with("Plants_"):
			key = "plant %s" % parts[3]
		elif nm.begins_with("Tree_") or nm.begins_with("TreeDeep_"):
			key = "tree"
		elif nm.begins_with("GroundCover_"):
			key = "cover"
		else:
			continue
		var mm: MultiMesh = mmi.multimesh
		for i in mm.instance_count:
			var xf: Transform3D = mm.get_instance_transform(i)
			var o := xf.origin
			var h := tm.intersect_ray(Vector3(o.x, 300, o.z), Vector3.DOWN)
			if h.is_empty():
				continue
			var gap: float = o.y - h["position"].y
			if not stats.has(key):
				stats[key] = {"n": 0, "hi": 0, "max": -99.0, "min": 99.0}
			var s: Dictionary = stats[key]
			s["n"] += 1
			if gap > 0.1:
				s["hi"] += 1
			s["max"] = maxf(s["max"], gap)
			s["min"] = minf(s["min"], gap)
			# Buttress feet end ~0.6m under the root, 0.85 of their reach out.
			if key == "tree" and TREE_REACH.has(int(parts[3])):
				var r: float = TREE_REACH[int(parts[3])] * xf.basis.get_scale().x * 0.85
				var low := 1e9
				for k in 8:
					var a := TAU * k / 8.0
					var hr := tm.intersect_ray(Vector3(o.x + cos(a) * r, 300, o.z + sin(a) * r), Vector3.DOWN)
					if not hr.is_empty():
						low = minf(low, hr["position"].y)
				var hang: float = (o.y - low) - 0.6
				trees += 1
				hang03 += 1 if hang > 0.3 else 0
				hang06 += 1 if hang > 0.6 else 0
				hang12 += 1 if hang > 1.2 else 0
				worst = maxf(worst, hang)
	var keys := stats.keys()
	keys.sort()
	for k in keys:
		var s: Dictionary = stats[k]
		print("%-10s %6d instances, root >10cm above ground: %d, gap range %.2f .. %.2f" % [k, s["n"], s["hi"], s["min"], s["max"]])
	print("%d buttressed trees: roots hang >0.3m: %d, >0.6m: %d, >1.2m: %d, worst %.2fm" % [trees, hang03, hang06, hang12, worst])
	quit()
