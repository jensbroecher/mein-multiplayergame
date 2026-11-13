extends SceneTree
## Renders DroneShow.gd's pictures in memory against a night sky: one shot per formation in the middle of its hold, and
## one halfway through each flight to the next (`morph=1`).
##   Godot --path . --resolution 1600x1000 -s res://scratch/drone_show_preview.gd -- <dir> [morph=1] [dist=420]

var _dir := "user://"
var _show: Node3D
var _cam: Camera3D
var _frame := 0
var _times: Array = []
var _names: Array = []


func _init() -> void:
	var morph := false
	var dist := 420.0
	for a in OS.get_cmdline_user_args():
		if a == "morph=1":
			morph = true
		elif a.begins_with("dist="):
			dist = float(a.substr(5))
		else:
			_dir = a
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.03, 0.08)
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.95
	env.environment = e
	world.add_child(env)
	_show = Node3D.new()
	_show.set_script(load("res://DroneShow.gd"))
	world.add_child(_show)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.far = 4000.0
	_cam.position = Vector3(0, 0, dist)
	world.add_child(_cam)
	_cam.make_current()
	var seg: float = 14.0 + 8.0
	for k in range(5):
		_times.append(seg * float(k) + 7.0)
		_names.append("form%d" % k)
		if morph:
			_times.append(seg * float(k) + 14.0 + 4.5)
			_names.append("morph%d" % k)
	DirAccess.make_dir_recursive_absolute(_dir)


func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 30:
		return false
	var i: int = (_frame - 30) / 4
	if i >= _times.size():
		return true
	_show.set("time_override", _times[i])
	if (_frame - 30) % 4 == 3:
		root.get_texture().get_image().save_png(_dir.path_join(String(_names[i]) + ".png"))
		print("SHOT ", _names[i])
	return false
