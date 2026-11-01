extends SceneTree

# Lists Ridgecrest's box colliders (Pinecrest Ridge, RidgecrestBody) whose centre lies within `r` metres in plan
# of each x,z given, with their size: to check that a piece of furniture or a terrace is solid.
#   Godot --headless --path . -s res://scratch/ridgecrest_solids.gd -- x,z [x,z ...] [r=3]

func _init() -> void:
	var r := 3.0
	var pts: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("r="):
			r = float(a.substr(2))
		else:
			var c := a.split(",")
			pts.append(Vector2(float(c[0]), float(c[1])))
	var level: Node = (load("res://levels/PinecrestRidgeLevel.tscn") as PackedScene).instantiate()
	var body: Node = level.find_child("RidgecrestBody", true, false)
	for p in pts:
		print("NEAR %s:" % p)
		for cs in body.get_children():
			if not (cs is CollisionShape3D and cs.shape is BoxShape3D):
				continue
			var o: Vector3 = cs.transform.origin
			if Vector2(o.x, o.z).distance_to(p) <= r:
				print("  box at %s size %s" % [o, (cs.shape as BoxShape3D).size])
	level.free()
	quit()
