# scratch/frostpeak_cross_check.gd
# Walks the surface along the line a car actually takes when it crosses from the trunk road onto
# each shortcut, at several offsets either side of the trunk centreline, and prints the profile.
# Continuous drivable surface means no MISS and no step worth reporting.
extends SceneTree

const ALERT := 0.05

var _level: Node3D
var _frames := 0

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "regenerate_cross_check"
	root.add_child(holder)
	_level = (load("res://levels/FrostpeakCreekLevel.tscn") as PackedScene).instantiate()
	holder.add_child(_level)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false

	var mc: Curve3D = (_level.get_node("TrackPath") as Path3D).curve
	for path in ["AlternativePaths/AlternativePath_CanyonCut", "AlternativePaths/AlternativePath_GladeBridge"]:
		var c: Curve3D = (_level.get_node(path) as Path3D).curve
		var len: float = c.get_baked_length()
		print("=== %s ===" % path)
		for end_i in [0.0, len]:
			var p0: Vector3 = c.sample_baked(end_i)
			var off: float = mc.get_closest_offset(p0)
			var mpos: Vector3 = mc.sample_baked(off)
			var fwd: Vector3 = _tangent(mc, off)
			var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
			var side: float = signf((p0 - mpos).dot(right))
			if is_zero_approx(side):
				side = 1.0
			print("  --- %s (shortcut on %s side) ---" % ["fork" if end_i == 0.0 else "merge",
				"left" if side < 0 else "right"])
			# For each lane a car might be in, walk outward across the junction.
			for lane in [-3.0, 0.0, 3.0]:
				var along: Vector3 = fwd * lane
				var prev := NAN
				var prev_lat := 0.0
				var misses := 0
				var worst := 0.0
				var worst_at := 0.0
				var detail := ""
				var lat := 0.0
				while lat <= 18.01:
					var q: Vector3 = mpos + along + right * (lat * side)
					var hit := _ray(q.x, q.z, p0.y + 14.0, p0.y - 16.0)
					if hit.is_empty():
						misses += 1
						detail += " [lat%.1f MISS]" % lat
					else:
						var y: float = (hit["position"] as Vector3).y
						if not is_nan(prev):
							var d: float = y - prev
							if absf(d) > worst:
								worst = absf(d)
								worst_at = lat
							if absf(d) > ALERT:
								var o = hit["collider"]
								detail += " [lat%.1f %+.3f %s]" % [lat, d, o.name if o else "?"]
						prev = y
						prev_lat = lat
					lat += 0.5
				print("    lane %+4.1fm: %2d misses, worst step %.3fm at lat %.1f%s" % [
					lane, misses, worst, worst_at, detail])
	return true


func _tangent(curve: Curve3D, off: float) -> Vector3:
	var length: float = curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var v: Vector3 = curve.sample_baked(minf(length, off + 1.0)) - curve.sample_baked(off)
	return v.normalized() if v.length() > 1e-5 else Vector3.FORWARD


func _ray(x: float, z: float, y0: float, y1: float) -> Dictionary:
	var space := root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y0, z), Vector3(x, y1, z))
	q.collide_with_areas = false
	return space.intersect_ray(q)