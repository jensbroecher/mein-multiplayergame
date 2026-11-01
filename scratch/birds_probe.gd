extends SceneTree
# Prints the node tree, skeleton and animation of models/animals/birds.glb.
func _init() -> void:
	var path := "res://models/animals/birds.glb"
	for a in OS.get_cmdline_user_args():
		path = a
	var s: Node = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	_dump(s, 0)
	for ap in s.find_children("*", "AnimationPlayer", true, false):
		for a in (ap as AnimationPlayer).get_animation_list():
			var an := (ap as AnimationPlayer).get_animation(a)
			print("ANIM ", a, " len=", an.length, " loop=", an.loop_mode, " tracks=", an.get_track_count())
	quit()
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is Node3D:
		extra = " pos=%s" % (n as Node3D).position
	if n is MeshInstance3D:
		var m := n as MeshInstance3D
		extra += " aabb=%s skel=%s" % [m.get_aabb(), m.skeleton]
	if n is Skeleton3D:
		extra += " bones=%d" % (n as Skeleton3D).get_bone_count()
	print("  ".repeat(d), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_dump(c, d + 1)
