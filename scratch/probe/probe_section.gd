extends SceneTree
func _init() -> void:
	var d = load("res://VortexBuilder.gd").new()
	# for a set of target y's find the outline's |x| on the right half (upper branch and lower branch)
	var targets := [0.220, 0.235, 0.245, 0.255, 0.265, 0.272]
	for z in [-1.112, -1.118, -1.126, -1.134]:
		var sec: PackedVector2Array = d.section(z)
		# walk pairs; find crossing of each target y, take the FORWARD-facing x (larger x per y branch)
		var out := []
		for ty in targets:
			var xlo := -1.0
			var xhi := -1.0
			for k in sec.size():
				var a: Vector2 = sec[k]
				var bb: Vector2 = sec[(k + 1) % sec.size()]
				if (a.y - ty) * (bb.y - ty) <= 0.0 and absf(bb.y - a.y) > 1e-9:
					var f: float = (ty - a.y) / (bb.y - a.y)
					var xx: float = lerpf(a.x, bb.x, f)
					if a.x < 0.0: xx = -xx
					if xx > 0.001:
						if xlo < 0.0: xlo = xx
						xhi = xx
			out.append("y%.3f: x∈[%.3f..%.3f]" % [ty, xlo, xhi])
		print("z=%.3f  %s" % [z, ", ".join(out)])
	quit()
