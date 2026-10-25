extends SceneTree

# Lists the drivable bodies of every level (or the ones given) with how PlayerCart classifies them:
# its track/off-road test, the surface it resolves to, and the metas that tune it. Headless:
#   Godot --headless --path . -s res://scratch/surface_survey.gd -- [res://levels/X.tscn ...]

const TRACK_TOKENS := ["track", "road", "ramp", "bridge", "loop", "deck", "jump", "curb", "pier", "harbor", "checkpoint", "finishline", "gate"]

func _init() -> void:
	var levels: Array = OS.get_cmdline_user_args()
	if levels.is_empty():
		for f in DirAccess.get_files_at("res://levels"):
			if f.ends_with(".tscn"):
				levels.append("res://levels/" + f)
	for path in levels:
		var ps: PackedScene = load(path)
		var root: Node = ps.instantiate()
		print("== ", path.get_file())
		var seen := {}
		for body in root.find_children("*", "CollisionObject3D", true, false):
			if body is Area3D:
				continue
			var p := str(root.get_path_to(body))
			# Collapse numbered siblings (chunks, instances) to one line each.
			var key := p.rstrip("0123456789_")
			if seen.has(key):
				seen[key] += 1
				continue
			seen[key] = 1
			var track := false
			var cur: Node = body
			while cur and cur != root:
				var nm := str(cur.name).to_lower()
				if cur.is_in_group("track_surface") or cur.is_in_group("loop_track") or cur.is_in_group("ramps"):
					track = true
				for t in TRACK_TOKENS:
					if nm.contains(t):
						track = true
				cur = cur.get_parent()
			var metas := []
			for m in body.get_meta_list():
				metas.append("%s=%s" % [m, str(body.get_meta(m))])
			print("  %s %s %s" % ["TRACK" if track else "off  ", p, " ".join(metas)])
		for k in seen:
			if seen[k] > 1:
				print("    (%d bodies like %s)" % [seen[k], k])
		root.free()
	quit()
