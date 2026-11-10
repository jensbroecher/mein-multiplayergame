extends SceneTree
## Lists a level's Label3Ds with their text and world position (headless): -s res://scratch/label_positions.gd -- <level> [max=20]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var lvl: Node = (load(a[0]) as PackedScene).instantiate()
	var n := 0
	var stack: Array = [[lvl, Transform3D()]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var node: Node = e[0]
		var xf: Transform3D = e[1]
		if node is Node3D:
			xf = xf * (node as Node3D).transform
		if node is Label3D and n < 20:
			print("LABEL %s at %s facing %s" % [(node as Label3D).text, str(xf.origin), str(xf.basis.z)])
			n += 1
		for c in node.get_children():
			stack.append([c, xf])
	quit()
