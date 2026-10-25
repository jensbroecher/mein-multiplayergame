extends SceneTree

# Prints every level's lap length (its TrackPath's baked length). Headless:
#   Godot --headless --path . -s res://scratch/lap_lengths.gd

func _init() -> void:
	for f in DirAccess.get_files_at("res://levels"):
		if not f.ends_with(".tscn"):
			continue
		var root: Node = (load("res://levels/" + f) as PackedScene).instantiate()
		var tp: Path3D = root.get_node_or_null("TrackPath")
		if tp and tp.curve:
			print("%-28s %6.0f m" % [f, tp.curve.get_baked_length()])
		root.free()
	quit()
