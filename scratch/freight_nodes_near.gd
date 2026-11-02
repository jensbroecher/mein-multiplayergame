extends Node

# Lists every Node3D of Freight Line (including its runtime-built bodies and areas) within `radius` of a point.
#   Godot --headless --path . res://scratch/freight_nodes_near.tscn -- x,y,z [radius=14]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var c := args[0].split(",")
	var at := Vector3(float(c[0]), float(c[1]), float(c[2]))
	var radius := 14.0
	for a in args:
		if a.begins_with("radius="):
			radius = float(a.substr(7))
	var level: Node3D = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(level)
	for i in 40:
		await get_tree().physics_frame
	for n in level.find_children("*", "Node3D", true, false):
		var n3 := n as Node3D
		if n3.global_position.distance_to(at) < radius and not (n3 is MeshInstance3D and n3.get_parent() is MultiMeshInstance3D):
			var extra := ""
			if n3 is CollisionObject3D:
				extra = " [collision layer %d]" % (n3 as CollisionObject3D).collision_layer
			print("NEAR %s (%s) at %s%s" % [level.get_path_to(n3), n3.get_class(), str(n3.global_position), extra])
	get_tree().quit()
