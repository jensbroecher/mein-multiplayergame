# scratch/frostpeak_obstruction_check.gd
# Walks each shortcut's full width over its first and last 30m and reports any collider that is
# not road/terrain, standing proud of the driving surface. That is what a car actually hits.
extends SceneTree

var _level: Node3D
var _frames := 0

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "regenerate_obstruction_check"
	root.add_child(holder)
	_level = (load("res://levels/FrostpeakCreekLevel.tscn") as PackedScene).instantiate()
	holder.add_child(_level)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false

	var EXPECTED := ["AlternativeRoad", "Track_Collision", "BridgeDeck", "Unified_World", "StoneAbutment"]
	for path in ["AlternativePaths/AlternativePath_CanyonCut", "AlternativePaths/AlternativePath_GladeBridge"]:
		var c: Curve3D = (_level.get_node(path) as Path3D).curve
		var len: float = c.get_baked_length()
		print("=== %s (%.1fm) ===" % [path, len])
		var found := {}
		for t in _stations(len):
			var p: Vector3 = c.sample_baked(t)
			var fwd := _tangent(c, t)
			var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
			for o in [-4.0, -2.0, 0.0, 2.0, 4.0]:
				var q: Vector3 = p + right * o
				var hit := _ray(q.x, q.z, p.y + 6.0, p.y + 0.02)
				if hit.is_empty():
					continue
				var coll = hit["collider"]
				var nm: String = coll.name if coll else "?"
				if _expected(nm, EXPECTED):
					continue
				var key := nm
				if not found.has(key):
					found[key] = {"t": t, "off": o, "h": (hit["position"] as Vector3).y - p.y}
		if found.is_empty():
			print("  nothing standing on the shortcut near either junction")
		for k in found.keys():
			var d: Dictionary = found[k]
			print("  OBSTRUCTION %-24s first at %.0fm, %.0fm off centre, %.2fm above the road" % [
				k, float(d["t"]), float(d["off"]), float(d["h"])])
	return true


func _stations(len: float) -> Array:
	var out: Array = []
	var i := 0
	while i <= 30:
		out.append(minf(float(i), len))
		out.append(maxf(len - float(i), 0.0))
		i += 1
	return out


func _expected(nm: String, list: Array) -> bool:
	for e in list:
		if nm.begins_with(e):
			return true
	return false


func _tangent(curve: Curve3D, off: float) -> Vector3:
	var length: float = curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var v: Vector3 = curve.sample_baked(minf(length, off + 0.5)) - curve.sample_baked(maxf(0.0, off - 0.5))
	return v.normalized() if v.length() > 1e-5 else Vector3.FORWARD


func _ray(x: float, z: float, y0: float, y1: float) -> Dictionary:
	var space := root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y0, z), Vector3(x, y1, z))
	q.collide_with_areas = false
	return space.intersect_ray(q)