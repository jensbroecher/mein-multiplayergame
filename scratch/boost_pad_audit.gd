extends SceneTree

# Lists every boost pad of every level with the angle between the pad's front (-z, flattened) and
# the way the lap runs under it (the nearest of TrackPath and the alternative paths). Headless:
#   Godot --headless --path . -s res://scratch/boost_pad_audit.gd [-- res://levels/X.tscn ...]
# A pad more than 20 degrees off is flagged. BoostPad.gd turns pads to face the lap at runtime;
# this reads the saved transforms, so it shows what the level file holds.

func _xform_in(node: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _paths(level: Node) -> Array:
	var out: Array = []
	for n in level.find_children("*", "Path3D", true, false):
		var p := n as Path3D
		if p.curve == null or p.curve.get_baked_length() < 50.0:
			continue
		var nm := str(p.name)
		if nm == "TrackPath" or "Alternative" in nm or "Shortcut" in nm or "Path" in str(p.get_parent().name):
			out.append(p)
	return out


func _initialize() -> void:
	var levels: Array = []
	for a in OS.get_cmdline_user_args():
		levels.append(a)
	if levels.is_empty():
		for f in DirAccess.get_files_at("res://levels"):
			if f.ends_with("Level.tscn"):
				levels.append("res://levels/" + f)
	var bad := 0
	for lp in levels:
		var level: Node = (load(lp) as PackedScene).instantiate()
		var paths := _paths(level)
		var pads := level.find_children("*", "Area3D", true, false).filter(func(n): return n.get_script() and str(n.get_script().resource_path).ends_with("BoostPad.gd"))
		print("%s: %d pads, paths %s" % [lp.get_file(), pads.size(), str(paths.map(func(p): return str(p.name)))])
		# The race runs the way the checkpoints are listed: their offsets along TrackPath should rise.
		var tp := level.get_node_or_null("TrackPath") as Path3D
		var cps = level.get("checkpoints")
		if tp and cps is Array and not cps.is_empty():
			var offs: Array = []
			var tpx := _xform_in(tp, level)
			for cp in cps:
				if cp is Node:
					offs.append(int(tp.curve.get_closest_offset(tpx.affine_inverse() * _xform_in(cp, level).origin)))
			print("  checkpoint offsets along TrackPath (of %d): %s" % [int(tp.curve.get_baked_length()), str(offs)])
		for pad in pads:
			var t := _xform_in(pad, level)
			var fwd := -t.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			var best_d := INF
			var best_tan := Vector3.ZERO
			var best_name := ""
			for p in paths:
				var pt := _xform_in(p, level)
				var local := pt.affine_inverse() * t.origin
				var off: float = p.curve.get_closest_offset(local)
				var c: Vector3 = pt * p.curve.sample_baked(off)
				var d := Vector2(c.x - t.origin.x, c.z - t.origin.z).length()
				if d < best_d:
					best_d = d
					var a: Vector3 = pt * p.curve.sample_baked(maxf(off - 2.0, 0.0))
					var b: Vector3 = pt * p.curve.sample_baked(minf(off + 2.0, p.curve.get_baked_length()))
					best_tan = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
					best_name = str(p.name)
			var ang := rad_to_deg(fwd.angle_to(best_tan))
			var flag := ""
			if ang > 20.0:
				flag = "  <-- OFF"
				bad += 1
			print("  %-14s at (%.0f, %.0f, %.0f) %5.1f deg from %s (%.1fm off it), settle=%s%s" % [pad.name, t.origin.x, t.origin.y, t.origin.z,
					ang, best_name, best_d, str(pad.get("settle_on_track")), flag])
		level.free()
	print("%d pads off" % bad)
	quit()
