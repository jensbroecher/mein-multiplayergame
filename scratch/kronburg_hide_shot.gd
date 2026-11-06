extends Node
## Look-dev for Kronburger Hütte: renders the level from one camera with some nodes hidden, to find what draws what.
##   Godot --path . --resolution 1280x720 res://scratch/kronburg_hide_shot.tscn -- <out.png> x,y,z:tx,ty,tz [hide=<node path> ...]
func _ready() -> void:
	var root := get_tree().root
	for n in root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var cam_spec: PackedStringArray = args[1].split(":")
	var level: Node3D = (load("res://levels/KronburgLevel.tscn") as PackedScene).instantiate()
	add_child(level)
	for a in args.slice(2):
		if a.begins_with("hide="):
			var n := level.get_node_or_null(a.substr(5))
			if n:
				n.queue_free()
			else:
				print("no node ", a.substr(5))
	var p := cam_spec[0].split_floats(",")
	var t := cam_spec[1].split_floats(",")
	var cam := Camera3D.new()
	cam.far = 4000.0
	add_child(cam)
	cam.look_at_from_position(Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]))
	cam.make_current()
	for i in 60:
		await get_tree().process_frame
	root.get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
