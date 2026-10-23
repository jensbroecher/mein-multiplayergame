extends SceneTree

func _init() -> void:
	var lvl = (load("res://levels/LakesideLevel.tscn") as PackedScene).instantiate()
	var path = lvl.get_node("TrackPath") as Path3D
	var curve = path.curve
	
	var candidates = [
		{"name": "North Hill 1", "pos": Vector3(-450, 0, -750)},
		{"name": "North Hill 2", "pos": Vector3(-490, 0, -760)},
		{"name": "North Hill 3", "pos": Vector3(-530, 0, -740)},
		{"name": "West Hill 1", "pos": Vector3(-780, 0, -220)},
		{"name": "West Hill 2", "pos": Vector3(-820, 0, -260)},
		{"name": "East Hill 1", "pos": Vector3(40, 0, -560)},
		{"name": "East Hill 2", "pos": Vector3(80, 0, -580)},
	]
	
	for c in candidates:
		var cp = curve.get_closest_point(c.pos)
		var dist = Vector2(cp.x - c.pos.x, cp.z - c.pos.z).length()
		print("%s %s: dist to track = %.1fm (closest track pt = %.1f, %.1f, %.1f)" % [c.name, c.pos, dist, cp.x, cp.y, cp.z])
		
	quit()
