extends SceneTree
# -s headless: loads Canyon Chasm and reports each DirtRamp's CSG, collider and world AABB
func _initialize():
	var lvl = load("res://levels/CanyonChasmLevel.tscn").instantiate()
	root.add_child(lvl)
	for i in 5: await process_frame
	for n in ["DirtRamp","DirtRamp2"]:
		var r = lvl.get_node(n)
		for c in r.get_children(true):
			if c is CSGShape3D:
				var m = c.bake_collision_shape() if c.use_collision else null
				print(n, " csg=", c.get_class(), " collision=", c.use_collision, " shape=", m, " aabb=", c.get_aabb(), " pos=", r.global_position)
	quit()
