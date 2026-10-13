extends Node

# Renders the same view of a level's water once per parameter variant, to tune a water material
# without regenerating the level. Run windowed:
#   Godot --path . res://scratch/water_debug.tscn -- <level.tscn> <out_dir> <MeshInstance name>
#       x,y,z:tx,ty,tz name:param=value[,param=value...] ...
# Each variant starts from the material as saved and applies its overrides on a duplicate.

const SIZE := Vector2i(1376, 768)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[1]
	var target := args[2]
	var cam_spec := args[3].split(":")
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var level: Node3D = load(args[0]).instantiate()
	vp.add_child(level)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 4000.0
	vp.add_child(cam)
	cam.make_current()
	var p := cam_spec[0].split(",")
	var t := cam_spec[1].split(",")
	cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
	var mis: Array = level.find_children(target, "MeshInstance3D", true, false)
	if mis.is_empty():
		push_error("No MeshInstance3D named %s" % target)
		get_tree().quit(1)
		return
	var mi: MeshInstance3D = mis[0]
	var base: ShaderMaterial = mi.material_override
	for a in args.slice(4):
		var parts := a.split(":")
		var mat: ShaderMaterial = base.duplicate()
		if parts.size() > 1:
			for kv in parts[1].split(","):
				var pair := kv.split("=")
				mat.set_shader_parameter(pair[0], str_to_var(pair[1]))
		mi.material_override = mat
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	get_tree().quit()
