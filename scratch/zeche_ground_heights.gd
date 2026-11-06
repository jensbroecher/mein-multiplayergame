extends SceneTree

# Prints the ground's height (the level's saved colliders) at points, for aiming look-dev cameras on Zeche Kronprinz
# or any level whose ground is saved as bodies. Headless:
#   Godot --headless --path . -s res://scratch/zeche_ground_heights.gd -- [level=res://levels/ZecheLevel.tscn] [from=600] x,z ...
# from= starts the rays at that height (under a bridge's deck, to find the ground beneath it).

func _init() -> void:
	var level_path := "res://levels/ZecheLevel.tscn"
	var spots: Array = []
	var from := 600.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("from="):
			from = float(a.substr(5))
		elif "," in a:
			var p := a.split(",")
			spots.append(Vector2(float(p[0]), float(p[1])))
	var level: Node3D = load(level_path).instantiate()
	root.add_child(level)
	await physics_frame
	await physics_frame
	var space := level.get_world_3d().direct_space_state
	for s in spots:
		var q := PhysicsRayQueryParameters3D.create(Vector3(s.x, from, s.y), Vector3(s.x, -200.0, s.y))
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			print("GROUND %.1f,%.1f: none" % [s.x, s.y])
		else:
			print("GROUND %.1f,%.1f: y %.2f on %s" % [s.x, s.y, hit.position.y, (hit.collider as Node).name])
	quit()
