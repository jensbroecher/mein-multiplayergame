extends Node
## Every SeaBoat's wake on a level: the trail mesh's surfaces and box, the bow wave, the trail's samples. Windowed:
##   Godot --path . res://scratch/harbor_wake_check.tscn [-- res://levels/HarborPierLevel.tscn]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://levels/HarborPierLevel.tscn"
	var level: Node = (load(path) as PackedScene).instantiate()
	add_child(level)
	for i in 30:
		await get_tree().physics_frame
	for n in level.find_children("*", "Node3D", true, false):
		if n.get_script() == load("res://SeaBoat.gd"):
			var line := "  %s width %.1f perimeter %.0f trail %d:" % [n.name, n.wake_width, n._perimeter, n._trail.size()]
			for c in n.get_children(true):
				if c is MeshInstance3D:
					var m: Mesh = (c as MeshInstance3D).mesh
					line += " %s(surfaces %d box %s)" % [c.name, m.get_surface_count() if m else -1, str(m.get_aabb()) if m else "-"]
			var hull: Node = n._hull
			if hull:
				for c2 in hull.get_children():
					if c2.name == "BowWave":
						line += " bow(%s)" % str((c2 as MeshInstance3D).mesh.get_aabb())
			print(line)
	get_tree().quit()
