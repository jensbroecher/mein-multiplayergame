extends Node

# Looks across a level's tree LOD band from the middle of its forest, in four directions.
#   Godot --path . res://scratch/lod_shots.tscn -- <level.tscn> <out_dir> <forest_node> [height]

const SIZE := Vector2i(1376, 768)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var level: Node3D = load(args[0]).instantiate()
	vp.add_child(level)
	MusicManager.set_shadow_quality(3, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var forest: Node = level.find_child(args[2], true, false)
	var sum := Vector3.ZERO
	var count := 0
	for c in forest.get_children():
		if c is MultiMeshInstance3D and c.visibility_range_begin == 0.0 and c.visibility_range_end < 1000.0:
			var mm: MultiMesh = c.multimesh
			for i in mm.instance_count:
				sum += mm.get_instance_transform(i).origin
				count += 1
	var centre := sum / maxf(count, 1)
	var h := float(args[3]) if args.size() > 3 else 25.0
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 4000.0
	vp.add_child(cam)
	cam.make_current()
	var dirs := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
	for d in dirs.size():
		cam.global_position = centre + Vector3.UP * h
		cam.look_at(cam.global_position + dirs[d] * 100.0 + Vector3.DOWN * 8.0, Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s_%d.png" % [args[1], args[2], d])
		print("SHOT ", d)
	get_tree().quit()
