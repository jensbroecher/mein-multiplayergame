extends SceneTree
## Lists a level's TrackPath control points (index, offset along the lap, position, handles):
##   Godot --headless --path . -s res://scratch/curve_points.gd -- <level.tscn>
func _init():
	var level: Node = (load(OS.get_cmdline_user_args()[0]) as PackedScene).instantiate()
	var c: Curve3D = (level.get_node("TrackPath") as Path3D).curve
	for i in c.point_count:
		var p := c.get_point_position(i)
		print("%2d s=%6.0f p=(%.1f, %.1f, %.1f) in=%s out=%s tilt=%.2f" % [i, c.get_closest_offset(p), p.x, p.y, p.z, c.get_point_in(i).snapped(Vector3.ONE * 0.1), c.get_point_out(i).snapped(Vector3.ONE * 0.1), c.get_point_tilt(i)])
	print("length ", c.get_baked_length(), " finish ", level.get_node("FinishLine").position)
	quit()
