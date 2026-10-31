extends Node

# Photographs the garage (Garage.gd), the whole window with its HUD, from where the walker stands or from
# the orbit of an inspected car. Steps run in order:
#   Godot --path . --resolution 1600x900 res://scratch/garage_shots.tscn -- <dir>
#       [trophies=demo]                        record made-up trophies first (user://trophies.cfg is backed up and put back)
#       walk:<name>:x,z:yaw_deg[:pitch_deg]    stand the walker there and shoot (yaw 0 looks down the hall, toward -z)
#       inspect:<name>:<car>[:yaw_deg:pitch_deg:dist]   lift that car, orbit it, shoot once it is up
#       lower                                  end the inspection
#       toggle:<car>                           put the car in or out of the line-up (and back at the end)
#       cam:<name>:x,y,z:tx,ty,tz[:fov]        a free camera, no HUD
#       bench:x,z:yaw_deg                      stand there and print the mean and worst frame time over 3s (no --fixed-fps)
#       tile:<path.jpg>:x,y,z:tx,ty,tz[:fov]   a free camera, saved as a menu tile (cropped to the tiles' 16:9 at 1280x720)

var garage: Control
var dir := "user://garage_shots"
var _toggled: Array = []


func _ready() -> void:
	var steps: Array = []
	var demo := false
	for a in OS.get_cmdline_user_args():
		if a == "trophies=demo":
			demo = true
		elif a.contains(":"):
			steps.append(a)
		else:
			dir = a
	DirAccess.make_dir_recursive_absolute(dir)
	var backup := ""
	if demo:
		backup = FileAccess.get_file_as_string("user://trophies.cfg") if FileAccess.file_exists("user://trophies.cfg") else ""
		var T = load("res://Trophies.gd")
		T.record_gp("Bloombay GP", [{"name": "Me", "car_index": 16, "is_bot": false}], ["Me"])
		T.record_gp("Bloombay GP", [{"name": "Me", "car_index": 10, "is_bot": false}], ["Me"])
		T.record_gp("Svartfjell GP", [{"name": "Bot"}, {"name": "Me", "car_index": 13, "is_bot": false}], ["Me"])
		T.record_gp("Matumaini GP", [{"name": "B1"}, {"name": "B2"}, {"name": "Me", "car_index": 5, "is_bot": false}], ["Me"])
	garage = load("res://Garage.gd").new()
	add_child(garage)
	for i in 50:
		await get_tree().process_frame
	garage.start()
	for i in 30:
		await get_tree().process_frame
	for step in steps:
		var p: PackedStringArray = step.split(":")
		match p[0]:
			"walk":
				var xz := p[2].split(",")
				garage._player.global_position = Vector3(float(xz[0]), 0.05, float(xz[1]))
				garage._yaw = deg_to_rad(float(p[3]))
				garage._pitch = deg_to_rad(float(p[4])) if p.size() > 4 else -0.05
				garage._player.rotation.y = garage._yaw
				garage._head.rotation.x = garage._pitch
				await _frames(20)
				await _shoot(p[1])
			"inspect":
				var idx := _bay_of(p[2])
				if idx < 0:
					print("no car ", p[2])
					continue
				garage._begin_inspect(idx)
				if p.size() > 5:
					garage._orbit_goal = Vector3(deg_to_rad(float(p[4])), deg_to_rad(float(p[3])), float(p[5]))
				await get_tree().create_timer(garage.LIFT_TIME + 1.0).timeout
				await _shoot(p[1])
			"lower":
				garage._end_inspect()
				await get_tree().create_timer(garage.LIFT_TIME + 0.5).timeout
			"toggle":
				var ti := _bay_of(p[1])
				garage._toggle_lineup(ti)
				_toggled.append(ti)
				await _frames(40)
			"bench":
				var bxz := p[1].split(",")
				garage._player.global_position = Vector3(float(bxz[0]), 0.05, float(bxz[1]))
				garage._yaw = deg_to_rad(float(p[2]))
				garage._player.rotation.y = garage._yaw
				RenderingServer.viewport_set_measure_render_time(garage._stage.get_viewport_rid(), true)
				await _frames(30)
				var times: Array = []
				var t0 := Time.get_ticks_usec()
				while Time.get_ticks_usec() - t0 < 3000000:
					var a0 := Time.get_ticks_usec()
					await get_tree().process_frame
					times.append((Time.get_ticks_usec() - a0) / 1000.0)
				var sum := 0.0
				for t in times:
					sum += t
				times.sort()
				print("BENCH at %s yaw %s: mean %.2f ms, p95 %.2f ms, worst %.2f ms over %d frames, gpu %.2f ms" % [p[1], p[2],
						sum / times.size(), times[int(times.size() * 0.95)], times[-1], times.size(),
						RenderingServer.viewport_get_measured_render_time_gpu(garage._stage.get_viewport_rid())])
			"tile":
				var tcam := Camera3D.new()
				garage._world.add_child(tcam)
				var ta := p[2].split(",")
				var tt := p[3].split(",")
				tcam.look_at_from_position(Vector3(float(ta[0]), float(ta[1]), float(ta[2])), Vector3(float(tt[0]), float(tt[1]), float(tt[2])), Vector3.UP)
				tcam.fov = float(p[4]) if p.size() > 4 else 55.0
				tcam.current = true
				await _frames(20)
				var timg: Image = garage._stage.get_texture().get_image()
				var w := timg.get_width()
				var h := timg.get_height()
				var cw := mini(w, int(h * 16.0 / 9.0))
				var ch := int(cw * 9.0 / 16.0)
				timg = timg.get_region(Rect2i((w - cw) / 2, (h - ch) / 2, cw, ch))
				timg.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
				timg.save_jpg(p[1], 0.9)
				print("TILE ", p[1])
				tcam.queue_free()
				garage._eye_cam.current = true
			"cam":
				var cam := Camera3D.new()
				garage._world.add_child(cam)
				var a := p[2].split(",")
				var t := p[3].split(",")
				var pos := Vector3(float(a[0]), float(a[1]), float(a[2]))
				cam.look_at_from_position(pos, Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
				cam.fov = float(p[4]) if p.size() > 4 else 60.0
				cam.current = true
				await _frames(20)
				var img: Image = garage._stage.get_texture().get_image()
				img.save_png(dir.path_join(p[1] + ".png"))
				print("SHOT ", p[1])
				cam.queue_free()
				garage._eye_cam.current = true
	for ti in _toggled:
		garage._toggle_lineup(ti)
	if demo:
		if backup == "":
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://trophies.cfg"))
		else:
			var f := FileAccess.open("user://trophies.cfg", FileAccess.WRITE)
			f.store_string(backup)
	get_tree().quit()


func _bay_of(car_name: String) -> int:
	for i in garage._bays.size():
		if str(garage.CAR_PRESETS[garage._bays[i]["index"]].name).to_lower() == car_name.to_lower():
			return i
	return -1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shoot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name, " target=", garage._target)
