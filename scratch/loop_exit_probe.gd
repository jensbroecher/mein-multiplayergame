extends SceneTree

# Measures how the Lakeside loop (Ramps/LoopCSG) meets the road: raycasts down across its entry and
# exit in the loop's own frame (x across, z along the ground lanes) and prints the surface height
# under each point against the road's, so a step, a bank or a gap shows. Headless:
#   Godot --headless --path . -s res://scratch/loop_exit_probe.gd [-- level=res://levels/LakesideLevel.tscn]
#       [z=-34,-30,...] [x=-9,-6,...]

var _root: Node3D
var _loop: Node3D


func _initialize() -> void:
	var level_path := "res://levels/LakesideLevel.tscn"
	var zs: Array = []
	var xs: Array = [-9.0, -7.0, -5.0, -3.25, -1.5, 0.0, 1.5, 3.25, 5.0, 7.0, 9.0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("z="):
			zs = Array(a.substr(2).split(",")).map(func(v): return float(v))
		elif a.begins_with("x="):
			xs = Array(a.substr(2).split(",")).map(func(v): return float(v))
	if zs.is_empty():
		for z in range(-36, 30, 2):
			zs.append(float(z))
	var level: Node = (load(level_path) as PackedScene).instantiate()
	_root = Node3D.new()
	root.add_child(_root)
	# Only the ground, the road and the loop: Level.gd itself isn't wanted here.
	for n in ["TerrainGenerator", "Ramps"]:
		var c := level.get_node(n)
		level.remove_child(c)
		_root.add_child(c)
	level.free()
	_loop = _root.get_node("Ramps/LoopCSG")
	for i in 6:
		await physics_frame
	await process_frame
	var space := _root.get_world_3d().direct_space_state
	var xf := _loop.global_transform
	print("loop at %s, forward (+z) %s" % [str(xf.origin), str(xf.basis.z)])
	var header := "   z  |"
	for x in xs:
		header += " %6.2f" % x
	print(header + "     (surface y above the loop origin; R = road/terrain, L = loop)")
	for z in zs:
		var line := "%5.1f |" % z
		for x in xs:
			var top := xf * Vector3(x, 6.0, z)
			var q := PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 14.0)
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				line += "     - "
				continue
			var tag := "L" if _is_loop(hit.collider) else "R"
			line += " %+5.2f%s" % [hit.position.y - xf.origin.y, tag]
		print(line)
	quit()


func _is_loop(n: Object) -> bool:
	var node := n as Node
	while node:
		if node == _loop:
			return true
		node = node.get_parent()
	return false
