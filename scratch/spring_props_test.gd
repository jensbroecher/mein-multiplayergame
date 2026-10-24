extends Node

# Drives a cart through a SpringProps prop (a flag on its spring base, a tyre stack) and logs how far it
# tips and slides, saving frames as it goes. Windowed, in a spectator race:
#   Godot --path . --resolution 1376x768 res://scratch/spring_props_test.tscn -- <out_dir>
#       [level=res://levels/BloombayDunesLevel.tscn] [props=Flags] [index=0] [speed=25]
# props= picks the first SpringProps node whose path contains it.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var level_path := "res://levels/BloombayDunesLevel.tscn"
	var filter := "Flags"
	var index := 0
	var speed := 25.0
	for a in args.slice(1):
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("props="): filter = a.substr(6)
		elif a.begins_with("index="): index = int(a.substr(6))
		elif a.begins_with("speed="): speed = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	var props: MultiMeshInstance3D = null
	for n in level.find_children("*", "MultiMeshInstance3D", true, false):
		if n.get_script() and str(n.get_script().resource_path).ends_with("SpringProps.gd") and filter in str(n.get_path()):
			props = n
			break
	if props == null:
		print("no SpringProps matching ", filter)
		get_tree().quit()
		return
	var rest: Transform3D = props.global_transform * props.rest[index]
	var cart: RigidBody3D = get_tree().get_nodes_in_group("player_carts")[0]
	for c in get_tree().get_nodes_in_group("player_carts"):
		if c != cart:
			c.global_position += Vector3(0, 0, 4000)
	cart.freeze = true
	var dir := Vector3(1, 0, 0.3).normalized()
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = rest.origin + Vector3(-6, 4, 9)
	cam.look_at(rest.origin + Vector3(0, 2.0, 0))
	cam.make_current()
	print("PROP %s #%d at %s" % [props.get_path(), index, rest.origin])
	var t := -1.2
	var shot := 0
	while t < 3.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		cart.global_position = rest.origin + dir * (t * speed) + Vector3.UP * 0.9
		var now: Transform3D = props.global_transform * props.multimesh.get_instance_transform(index)
		var tip := rad_to_deg(now.basis.y.normalized().angle_to(rest.basis.y.normalized()))
		var slide := Vector2(now.origin.x - rest.origin.x, now.origin.z - rest.origin.z).length()
		if fmod(t + 10.0, 0.25) < dt:
			print("t=%5.2f tip=%5.1f deg slide=%.2fm" % [t, tip, slide])
		if t > 0.0 and shot < 6 and fmod(t, 0.3) < dt:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/spring_%s_%d.png" % [out_dir, filter, shot])
			shot += 1
	get_tree().quit()
