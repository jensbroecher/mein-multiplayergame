# scratch/frostpeak_road_check.gd
# Walks each shortcut centreline and reports what a car would actually hit, and measures the
# ground clearance under the Glade bridge with the bridge's own collision excluded.
extends SceneTree

var _level: Node3D
var _frames := 0

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "regenerate_road_check"
	root.add_child(holder)
	_level = (load("res://levels/FrostpeakCreekLevel.tscn") as PackedScene).instantiate()
	holder.add_child(_level)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false

	var bridge: Node3D = _level.get_node("GladeTimberBridge")
	var box: BoxMesh = null
	for c in bridge.get_node("BridgeDeck").get_children():
		if c is MeshInstance3D:
			box = (c as MeshInstance3D).mesh as BoxMesh
	var bc: Vector3 = bridge.position
	var yaw: float = bridge.rotation_degrees.y
	var axis := Vector3(cos(deg_to_rad(yaw)), 0.0, -sin(deg_to_rad(yaw))).normalized()
	var half: float = box.size.x * 0.5
	var excl: Array = []
	_collect_bodies(bridge, excl)

	print("=== ground under the Glade bridge (bridge collision excluded) ===")
	print("  deck %.1f x %.1f m, underside Y=%.2f" % [box.size.x, box.size.z, bc.y - box.size.y * 0.5])
	var min_clear := 1e9
	for i in range(11):
		var p: Vector3 = bc + axis * (half - 1.5) * (float(i) / 10.0 * 2.0 - 1.0)
		var hit := _ray_down(p.x, p.z, excl)
		if hit.is_empty():
			print("    x=%7.2f z=%7.2f  MISS" % [p.x, p.z])
			continue
		var hp: Vector3 = hit["position"]
		var clear: float = bc.y - box.size.y * 0.5 - hp.y
		min_clear = minf(min_clear, clear)
		print("    x=%7.2f z=%7.2f  ground %7.2f  clearance %5.2fm  %s %s" % [
			p.x, p.z, hp.y, clear, _cname(hit), "(WATER)" if hp.y < -1.2 else ""])
	print("  minimum clearance: %.2fm" % min_clear)

	for path in ["AlternativePaths/AlternativePath_CanyonCut", "AlternativePaths/AlternativePath_GladeBridge"]:
		var c: Curve3D = (_level.get_node(path) as Path3D).curve
		print("\n=== driving surface along %s (%.1fm) ===" % [path, c.get_baked_length()])
		var len: float = c.get_baked_length()
		var bad := 0
		var i2 := 0
		while i2 <= 40:
			var t: float = float(i2) / 40.0 * len
			var p: Vector3 = c.sample_baked(t)
			var hit := _ray_down(p.x, p.z, [])
			var desc := "MISS"
			if not hit.is_empty():
				var hp: Vector3 = hit["position"]
				desc = "%7.2f via %s" % [hp.y, _cname(hit)]
				if hp.y < p.y - 1.2:
					bad += 1
					desc += "  <-- ROAD MISSING (curve at %.2f)" % p.y
			print("  %6.1fm  %s" % [t, desc])
			i2 += 1
		print("  samples with no road under them: %d / 41" % bad)
	return true


func _collect_bodies(n: Node, out: Array) -> void:
	if n is CollisionObject3D:
		out.append((n as CollisionObject3D).get_rid())
	for c in n.get_children():
		_collect_bodies(c, out)


func _cname(hit: Dictionary) -> String:
	var o = hit["collider"]
	return o.name if o else "?"


func _ray_down(x: float, z: float, exclude: Array) -> Dictionary:
	var space := root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 140.0, z), Vector3(x, -60.0, z))
	q.collide_with_areas = false
	q.exclude = exclude
	return space.intersect_ray(q)