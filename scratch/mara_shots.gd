extends Node

# Menu tiles for Mara Crossing / the Matumaini GP, rendered into a fixed-size SubViewport (the
# window's size is not reliable on every platform). A shot named herd* first waits until the
# wildebeest are streaming across the road. Run windowed:
#   Godot --path . res://scratch/mara_shots.tscn -- <out_dir> name:x,y,z:tx,ty,tz ...

const SIZE := Vector2i(1376, 768)
const HERD_CROSS := Vector3(190.0, 7.0, -55.0)

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = SIZE * 2
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var level: Node3D = load("res://levels/MaraCrossingLevel.tscn").instantiate()
	vp.add_child(level)
	MusicManager.set_shadow_quality(3, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 4000.0
	vp.add_child(cam)
	cam.make_current()
	var herd: Node = level.get_node("MigrationHerd")
	for a in args.slice(1):
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		if parts[0].begins_with("herd"):
			for i in 3000:
				await get_tree().process_frame
				var near := 0
				for k in herd._xforms.size():
					if herd._visible[k] == 1 and Vector2(herd._xforms[k].origin.x - HERD_CROSS.x, herd._xforms[k].origin.z - HERD_CROSS.z).length() < 16.0:
						near += 1
				if near >= 9:
					break
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		img.save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	get_tree().quit()
