extends Node

# Nyota Stadium's paper run-through banner (PaperBanner.gd): drives a real cart off the Drop-In through it
# and saves frames from a fixed camera while it tears and the scraps come down. Run windowed:
#   Godot --path . --resolution 1600x900 --fixed-fps 60 res://scratch/paper_banner_shots.tscn -- <dir>
#       [speed=34] [lat=0] [times=0.0,0.45,0.55,0.7,1.0,1.6,3.0,6.0] [cam=x,y,z:tx,ty,tz] [carts=1]
# `carts=N` sends N carts in turn (each 1.2s after the last, `lat` apart by 2.5m), times counted from the first.
# The node's name holds "regenerate" so Level.gd skips its race setup.

const CART_SCENE := preload("res://PlayerCart.tscn")


func _ready() -> void:
	var dir := ""
	var speed := 34.0
	var lat := 0.0
	var carts := 1
	var times: Array[float] = [0.0, 0.45, 0.55, 0.7, 1.0, 1.6, 3.0, 6.0]
	var cam_from := Vector3(150.0, 9.5, 64.0)
	var cam_to := Vector3(163.0, 9.0, 48.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("speed="):
			speed = float(a.substr(6))
		elif a.begins_with("lat="):
			lat = float(a.substr(4))
		elif a.begins_with("carts="):
			carts = int(a.substr(6))
		elif a.begins_with("times="):
			times.clear()
			for v in a.substr(6).split(","):
				times.append(float(v))
		elif a.begins_with("cam="):
			var parts := a.substr(4).split(":")
			var f := parts[0].split_floats(",")
			var t2 := parts[1].split_floats(",")
			cam_from = Vector3(f[0], f[1], f[2])
			cam_to = Vector3(t2[0], t2[1], t2[2])
		elif not a.contains("="):
			dir = a
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	var level: Node3D = load("res://levels/NyotaStadiumLevel.tscn").instantiate()
	add_child(level)
	var cam := Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	cam.look_at_from_position(cam_from, cam_to)
	cam.make_current()
	# Shaders compile in the background (CLAUDE.md): wait before the first shot.
	for i in 60:
		await get_tree().process_frame
	var lips: Array = level.get_node("TrackPath").get_meta(&"jump_lips")
	var lip: Dictionary = {}
	for l in lips:
		if l["name"] == "DropIn":
			lip = l
	var p: Vector3 = lip["lip"]
	var d: Vector3 = lip["dir"]
	var right := d.cross(Vector3.UP).normalized()
	var banner: Node = get_tree().get_nodes_in_group("paper_banners")[0]
	var sent: Array = []
	var t := 0.0
	var shot := 0
	var next_cart := 0
	while shot < times.size():
		if next_cart < carts and t >= next_cart * 1.2:
			var off: float = lat + (next_cart - (carts - 1) * 0.5) * 2.5
			# 20m back, timed so the first one reaches the lip about 0.6s in.
			var start: Vector3 = p - d * 20.0 + right * off + Vector3.UP * 1.0
			var cart: RigidBody3D = CART_SCENE.instantiate()
			cart.name = str(next_cart + 1)
			level.get_node("Players").add_child(cart)
			cart.global_position = start
			cart.get_node("Visuals").global_rotation = Vector3(0, atan2(-d.x, -d.z), 0)
			for i in 3:
				await get_tree().physics_frame
			cam.make_current()
			cart.set("is_landing", false)
			cart.set("can_move", true)
			cart.set("max_speed", speed)
			cart.freeze = false
			cart.linear_velocity = d * speed
			sent.append(cart)
			Input.action_press("p1_throttle")
			next_cart += 1
		if t >= times[shot]:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			var path := "%s/banner_%02d_%.2fs.png" % [dir, shot, t]
			img.save_png(path)
			print("SHOT %.2fs cells=%d scraps=%d" % [t, banner.intact_cells(), banner.scrap_count()])
			shot += 1
		await get_tree().physics_frame
		t += 1.0 / 60.0
		for c in sent:
			if is_instance_valid(c):
				(c as RigidBody3D).set("max_speed", speed)
	Input.action_release("p1_throttle")
	get_tree().quit()
