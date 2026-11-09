extends Node

# Glacier Highway's tower crane (regenerate_glacier_dressing.gd, Anlegg_KranTopp): how high its load hangs, and the tallest
# thing under the arc its trolley sweeps (SlewHazard's centre_deg +- amplitude_deg: trees' instances by their mesh's top,
# single meshes by their bounds, the terrain and the crane's own batch left out), so the load can't swing through
# anything. Headless (a scene, since the level's scripts need the autoloads):
#   Godot --headless --path . res://scratch/crane_clearance_probe.tscn -- [level=res://levels/GlacierHighwayLevel.tscn]

const BaustelleKit = preload("res://BaustelleKit.gd")
const PROP_SCALE := 1.6

func _ready() -> void:
	var path := "res://levels/GlacierHighwayLevel.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			path = a.substr(6)
	var level: Node3D = load(path).instantiate()
	add_child(level)
	var top := level.find_child("Anlegg_KranTopp", true, false) as Node3D
	if top == null:
		print("no crane")
		get_tree().quit()
		return
	var c := top.global_position
	var reach: float = -BaustelleKit.TROLLEY_Z * PROP_SCALE
	var load_y: float = c.y + (BaustelleKit.TC_LOAD_Y - 0.4) * PROP_SCALE
	print("crane at (%.0f, %.0f), its top %.1fm up, trolley %.1fm out, the load's bottom at y %.1f" % [c.x, c.z, c.y, reach, load_y])
	var arc: Array = []
	var cd: float = float(top.get("centre_deg"))
	var amp: float = float(top.get("amplitude_deg"))
	for k in range(41):
		var th := deg_to_rad(cd - amp + 2.0 * amp * float(k) / 40.0)
		arc.append(Vector2(c.x, c.z) + Vector2(-sin(th), -cos(th)) * reach)
	var under := func(x: float, z: float, r: float) -> bool:
		for q in arc:
			if (q as Vector2).distance_to(Vector2(x, z)) < r:
				return true
		return false
	var worst := -INF
	var what := ""
	for mmi in level.find_children("*", "MultiMeshInstance3D", true, false):
		var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			continue
		var top_local: float = mm.mesh.get_aabb().end.y
		var buf := mm.buffer
		if mm.instance_count <= 0 or buf.size() < mm.instance_count * 12:
			continue
		# 12 floats a transform, then the colour's and custom data's 4 each if the MultiMesh has them.
		var stride := buf.size() / mm.instance_count
		var mxf := (mmi as MultiMeshInstance3D).global_transform
		for i in range(mm.instance_count):
			var o := i * stride
			var wp := mxf * Vector3(buf[o + 3], buf[o + 7], buf[o + 11])
			var x := wp.x
			var y := wp.y
			var z := wp.z
			var sy := Vector3(buf[o + 1], buf[o + 5], buf[o + 9]).length()
			if not under.call(x, z, 8.0):
				continue
			var t := y + top_local * sy
			if t > worst:
				worst = t
				what = "%s instance at (%.0f, %.0f)" % [mmi.name, x, z]
	for mi in level.find_children("*", "MeshInstance3D", true, false):
		if top.is_ancestor_of(mi):
			continue
		var mp := String(mi.get_path())
		if "Chunk_" in mp or "Country" in mp or "Valley" in mp or "Massif" in mp or "Anlegg_Plass" in mp or "Backdrop" in mp:
			continue
		var aabb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		if aabb.size.x > 400.0 or aabb.size.z > 400.0:
			continue
		# Anything whose bounds the trolley's arc passes over (or within 5m of).
		var hit := false
		for q in arc:
			var qq: Vector2 = q
			if qq.x > aabb.position.x - 5.0 and qq.x < aabb.end.x + 5.0 and qq.y > aabb.position.z - 5.0 and qq.y < aabb.end.z + 5.0:
				hit = true
				break
		if not hit:
			continue
		if aabb.end.y > worst:
			worst = aabb.end.y
			what = "%s (bounds)" % mi.get_path()
	print("tallest under the trolley's circle: y %.1f, %s; the load clears it by %.1fm" % [worst, what, load_y - worst])
	get_tree().quit()
