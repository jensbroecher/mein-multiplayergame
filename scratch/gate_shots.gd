extends Node

# Shots of a level's race gates (CheckpointGate.gd). Run windowed:
#   Godot --path . res://scratch/gate_shots.tscn -- <level.tscn> <out_dir> [carts=N]
#       [fov=deg] [lap=N] [all=x,y,z:tx,ty,tz] name:gate:x,y,z:tx,ty,tz[:step[:scroll]] ...
# Camera and target are in the named gate's space (FinishLine, Checkpoints/Checkpoint_2, ...): X
# across the road, the grid on +Z. step (0..4) is the start-light step the finish gantry shows
# for that shot, as Level.start_race() would set it (-1: none, the ticker or the flag). scroll puts
# the ticker that many LEDs along. lap= feeds the ticker six racers with the leader on lap N (the
# last lap waves the flag). carts= drops carts on the first grid slots; fov=75 matches the chase
# camera. all= shoots every gate in the level from that camera.

const SIZE := Vector2i(1376, 768)
const CART_MODEL := "res://generated/cars/Viper.tscn"
const CarPaint = preload("res://CarPaint.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[1]
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var level: Node3D = load(args[0]).instantiate()
	vp.add_child(level)
	# No race countdown: the shots set the start lights themselves.
	level.race_state = level.RaceState.RACING
	MusicManager.set_shadow_quality(3, false)
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 4000.0
	vp.add_child(cam)
	cam.make_current()
	# The gates settle onto the road once the level has built its runtime collision.
	await level.wait_for_collisions()
	for i in 4:
		await get_tree().physics_frame
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var fl: Node3D = level.get_node_or_null("FinishLine")
	for a in args.slice(2):
		if a.begins_with("fov="):
			cam.fov = float(a.substr(4))
		if a.begins_with("carts=") and fl:
			var slots := fl.get_node("SpawnPoints").get_children()
			for i in mini(int(a.substr(6)), slots.size()):
				var car: Node3D = load(CART_MODEL).instantiate()
				CarPaint.apply(car, CarPaint.factory("Viper"))
				vp.add_child(car)
				var slot: Node3D = slots[i]
				car.global_transform = Transform3D(slot.global_basis.rotated(Vector3.UP, PI).scaled(Vector3.ONE * 2.0), slot.global_position)
	for a in args.slice(2):
		if a.begins_with("lap=") and fl:
			var rows: Array = []
			for i in 6:
				rows.append({"id": 100 + i, "pos": i + 1, "lap": int(a.substr(4)), "finished": false,
						"name": ["Viper", "Shadow", "Apex", "Blaze", "Nova", "Storm"][i]})
			fl.update_standings(rows)
			if not fl._ticker_next.is_empty():
				fl._show_ticker(fl._ticker_next)
	for a in args.slice(2):
		if a.begins_with("carts=") or a.begins_with("fov=") or a.begins_with("lap="):
			continue
		if a.begins_with("all="):
			var gates: Array[Node] = []
			if fl:
				gates.append(fl)
			if level.get_node_or_null("Checkpoints"):
				gates.append_array(level.get_node("Checkpoints").get_children())
			for g in gates:
				await _shoot(vp, cam, g, a.substr(4), "%s/%s.png" % [out_dir, g.name])
			continue
		var parts := a.split(":")
		var gate: Node3D = level.get_node(parts[1])
		if parts.size() > 4 and fl and int(parts[4]) >= 0:
			fl.show_start_lights(int(parts[4]))
		if parts.size() > 5 and fl:
			fl._ticker_scroll = float(parts[5])
		await _shoot(vp, cam, gate, parts[2] + ":" + parts[3], "%s/%s.png" % [out_dir, parts[0]])
	get_tree().quit()


## Frames `view` ("x,y,z:tx,ty,tz" in the gate's space) and saves the render to `path`.
func _shoot(vp: SubViewport, cam: Camera3D, gate: Node3D, view: String, path: String) -> void:
	var pt := view.split(":")
	var p := pt[0].split(",")
	var t := pt[1].split(",")
	cam.global_position = gate.to_global(Vector3(float(p[0]), float(p[1]), float(p[2])))
	cam.look_at(gate.to_global(Vector3(float(t[0]), float(t[1]), float(t[2]))), Vector3.UP)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("SHOT ", path.get_file())
