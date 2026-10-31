extends SceneTree
## Prints the eagle model's size per part (model units) and its lowest points, to scale it and place
## the carried cart under its talons. Headless: -s res://scratch/eagle_measure.gd
func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var sc: PackedScene = load("res://models/animals/20260717033727_7db23447.fbx")
	var root: Node3D = sc.instantiate()
	get_root().add_child(root)
	var total := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		var bb: AABB = xf * mi.mesh.get_aabb()
		print("%s parent=%s aabb pos=%s size=%s" % [mi.name, mi.get_parent().name, bb.position, bb.size])
		if first:
			total = bb
			first = false
		else:
			total = total.merge(bb)
	print("TOTAL pos=%s size=%s end=%s" % [total.position, total.size, total.end])
	quit()
