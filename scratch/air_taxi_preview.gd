extends SceneTree
## Renders AirTaxis.gd's taxi up close, flying a small loop, from cameras placed round it (in the taxi's own frame:
## x right, y up, z back), in a night or day light.
##   Godot --path . --resolution 1600x1000 -s res://scratch/air_taxi_preview.gd -- <dir> [night=1] name:x,y,z ...

var _dir := "user://"
var _shots: Array = []
var _night := true
var _taxis: Node3D
var _cam: Camera3D
var _frame := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("night="):
			_night = a.substr(6) == "1"
		elif a.count(":") == 1:
			var p: PackedStringArray = a.split(":")
			var v: PackedStringArray = p[1].split(",")
			_shots.append([p[0], Vector3(float(v[0]), float(v[1]), float(v[2]))])
		else:
			_dir = a
	if _shots.is_empty():
		_shots = [["side", Vector3(-14, 3, 2)], ["front", Vector3(-6, 2, -14)], ["above", Vector3(-8, 12, 8)], ["below", Vector3(-6, -6, 6)]]
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.04, 0.1) if _night else Color(0.5, 0.65, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.3, 0.45) if _night else Color(0.7, 0.75, 0.8)
	e.ambient_light_energy = 0.6 if _night else 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 0.4 if _night else 1.6
	world.add_child(sun)
	_taxis = Node3D.new()
	_taxis.set_script(load("res://AirTaxis.gd"))
	var pts := PackedVector3Array()
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		pts.append(Vector3(cos(a) * 400.0, 60.0, sin(a) * 400.0))
	_taxis.set("routes", [{"points": pts, "speed": 0.5, "count": 1}])
	world.add_child(_taxis)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	world.add_child(_cam)
	_cam.make_current()
	DirAccess.make_dir_recursive_absolute(_dir)


func _process(_delta: float) -> bool:
	_frame += 1
	var kids: Array = _taxis.get_children(true)
	if kids.is_empty():
		return false
	var t: Node3D = kids[0]
	var i: int = (_frame - 40) / 4
	if _frame < 40:
		return false
	if i >= _shots.size():
		return true
	var sh: Array = _shots[i]
	var tx: Transform3D = t.global_transform
	var centre: Vector3 = tx * Vector3(0, 2.0, 0)
	_cam.global_position = tx * (sh[1] as Vector3)
	_cam.look_at(centre, Vector3.UP)
	if (_frame - 40) % 4 == 3:
		var img := root.get_texture().get_image()
		img.save_png(_dir.path_join(String(sh[0]) + ".png"))
		print("SHOT ", sh[0])
	return false
