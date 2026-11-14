extends Node3D
## The time trial's ghost: the stage's best run, driven again beside the player as a hologram car (ghost_car.gdshader,
## the menu tile's orange), and the recorder that makes the next one. Level.gd adds it at the green light of a time trial
## (`begin`) and tells it at the finish whether the run was the stage's new best (`finish`).
##
## Recording: the human's car model's transform (Visuals/CartModel: where the car is drawn, its tilt and the steering's
## lean included) and the steering, every `SAMPLE_TICKS` physics ticks from the green light, each with its time on the
## race's clock (real time since the green light, as Level times laps: the game doesn't pause in a race). Playback runs
## on that clock too, interpolating between samples, so the ghost is where the best run was at the time the HUD shows,
## whatever frame rate either run had; the wheels roll by the distance covered and the front ones steer.
## The file (`user://ghosts/<stage>.ghost`, FileAccess.store_var): {version, car_index, paint, laps, total_ms, dt (the
## sampling interval, used when `t` is missing), t: PackedInt32Array (each sample's time, ms since the green light),
## scale (the model's), pos: PackedVector3Array, rot: PackedVector4Array (quaternions), steer: PackedFloat32Array (the
## front wheels' turn)}. A ghost of another number of laps doesn't play.

const TimeTrialRecords = preload("res://TimeTrialRecords.gd")
const CarPaint = preload("res://CarPaint.gd")

const DIR := "user://ghosts/"
const VERSION := 1
const SAMPLE_TICKS := 3
## The hologram's colour: the menu tile's.
const TINT := Color(1.0, 0.62, 0.18)
const WHEELS := ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
const FADE_IN := 0.8
const FADE_OUT := 1.2

var stage_key := ""
var laps := 0

var _cart: Node3D = null
var _rec_pos := PackedVector3Array()
var _rec_rot := PackedVector4Array()
var _rec_steer := PackedFloat32Array()
var _rec_t := PackedInt32Array()
var _go_usec := 0
var _recording := false
var _ticks := 0
var _rec_scale := 2.0

var _ghost: Dictionary = {}
var _car: Node3D = null
var _materials: Array = []
var _wheels: Array = []
var _radii: Array = []
var _rolled := 0.0
var _last_pos := Vector3.INF
var _play_t := 0.0
var _playing := false
var _label: Label3D = null


static func path_of(key: String) -> String:
	return DIR + key + ".ghost"


## A stage's saved ghost (empty if none).
static func load_ghost(key: String) -> Dictionary:
	var p := path_of(key)
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION:
		return {}
	return d


## At the green light: record `cart` (the human's) and play the stage's best run if there is one of `target_laps`.
func begin(key: String, cart: Node3D, target_laps: int) -> void:
	stage_key = key
	laps = target_laps
	_cart = cart
	_recording = cart != null
	_ticks = 0
	_go_usec = Time.get_ticks_usec()
	_ghost = load_ghost(key)
	# The ghost car is placed every drawn frame (from _process), not on the physics tick.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if not _ghost.is_empty() and int(_ghost.get("laps", 0)) == target_laps and (_ghost.get("pos", PackedVector3Array()) as PackedVector3Array).size() > 2:
		_build_car()
		_playing = _car != null
	process_physics_priority = 100


## At the finish: stop recording, and save the run if it was the stage's new best.
func finish(new_best: bool, total_ms: int) -> void:
	_recording = false
	if not new_best or _rec_pos.size() < 2 or _cart == null:
		return
	var idx := 0
	var paint := {}
	var pid: int = int(str(_cart.name)) if str(_cart.name).is_valid_int() else 1
	if NetworkManager.players.has(pid):
		idx = int(NetworkManager.players[pid].get("car_index", 0))
		paint = NetworkManager.players[pid].get("paint", {})
	if "paint" in _cart and _cart.get("paint") is Dictionary:
		paint = _cart.get("paint")
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path_of(stage_key), FileAccess.WRITE)
	if f == null:
		push_warning("TimeTrialGhost: can't write " + path_of(stage_key))
		return
	f.store_var({"version": VERSION, "car_index": idx, "paint": paint, "laps": laps, "total_ms": total_ms,
			"dt": float(SAMPLE_TICKS) / float(Engine.physics_ticks_per_second), "t": _rec_t, "scale": _rec_scale, "pos": _rec_pos, "rot": _rec_rot, "steer": _rec_steer})
	print("[Ghost] saved %s: %d samples, %s" % [stage_key, _rec_pos.size(), TimeTrialRecords.format_ms(total_ms)])


func _physics_process(delta: float) -> void:
	if _recording and is_instance_valid(_cart):
		if _ticks % SAMPLE_TICKS == 0:
			var model := _cart.get_node_or_null("Visuals/CartModel") as Node3D
			var xf: Transform3D = model.global_transform if model else _cart.global_transform
			var q: Quaternion = xf.basis.get_rotation_quaternion()
			_rec_t.append(int((Time.get_ticks_usec() - _go_usec) / 1000))
			_rec_pos.append(xf.origin)
			_rec_rot.append(Vector4(q.x, q.y, q.z, q.w))
			# The front wheels' turn as drawn (PlayerCart's pivots), or the steering's.
			var piv := _cart.get_node_or_null("Visuals/WheelPivotFL") as Node3D
			_rec_steer.append(piv.rotation.y if piv else -0.5 * float(_cart.get("current_steer")) if "current_steer" in _cart else 0.0)
			if _rec_pos.size() == 1:
				_rec_scale = xf.basis.get_scale().x
		_ticks += 1



## Where the ghost was last drawn, in seconds of its run (for tests).
var shown_t := 0.0

func _process(delta: float) -> void:
	if not _playing or _car == null:
		return
	# The race's clock: real time since the green light.
	_play_t = float(Time.get_ticks_usec() - _go_usec) / 1000000.0
	shown_t = _play_t
	var pos: PackedVector3Array = _ghost["pos"]
	var rot: PackedVector4Array = _ghost["rot"]
	var steer: PackedFloat32Array = _ghost.get("steer", PackedFloat32Array())
	var n: int = pos.size()
	var i: int
	var j: int
	var f: float
	var end_t: float
	var ts: PackedInt32Array = _ghost.get("t", PackedInt32Array())
	if ts.size() == n:
		var ms: float = _play_t * 1000.0
		i = clampi(ts.bsearch(int(floor(ms)), false) - 1, 0, n - 1)
		j = mini(i + 1, n - 1)
		f = clampf((ms - float(ts[i])) / maxf(float(ts[j] - ts[i]), 1.0), 0.0, 1.0)
		end_t = float(ts[n - 1]) / 1000.0
	else:
		var dt: float = float(_ghost.get("dt", 0.05))
		var u: float = _play_t / dt
		i = clampi(int(floor(u)), 0, n - 1)
		j = mini(i + 1, n - 1)
		f = clampf(u - float(i), 0.0, 1.0)
		end_t = float(n - 1) * dt
	var p: Vector3 = pos[i].lerp(pos[j], f)
	var qa := Quaternion(rot[i].x, rot[i].y, rot[i].z, rot[i].w)
	var qb := Quaternion(rot[j].x, rot[j].y, rot[j].z, rot[j].w)
	var sc: float = float(_ghost.get("scale", 2.0))
	_car.global_transform = Transform3D(Basis(qa.slerp(qb, f)).scaled(Vector3.ONE * sc), p)
	# Fade in at the start, out once its run is over.
	var s: float = clampf(_play_t / FADE_IN, 0.0, 1.0) * (1.0 - clampf((_play_t - end_t) / FADE_OUT, 0.0, 1.0))
	for m in _materials:
		(m as ShaderMaterial).set_shader_parameter("strength", s)
	if _label:
		_label.modulate.a = 0.85 * s
	if s <= 0.0 and _play_t > end_t:
		_car.visible = false
		_playing = false
		return
	# The wheels roll by the distance covered along the car's nose (+z of a car's scene: forward is a falling angle);
	# a teleport (a respawn in the recorded run) doesn't roll them.
	if _last_pos != Vector3.INF and p.distance_to(_last_pos) < 6.0:
		_rolled += (p - _last_pos).dot(_car.global_transform.basis.z.normalized())
	_last_pos = p
	var st: float = lerpf(steer[i], steer[j], f) if steer.size() == n else 0.0
	for k in range(_wheels.size()):
		var w: Node3D = _wheels[k]
		if w == null:
			continue
		w.rotation = Vector3(-_rolled / float(_radii[k]), st if k < 2 else 0.0, 0.0)


func _build_car() -> void:
	var presets: Array = preload("res://PlayerCart.gd").CAR_PRESETS
	var idx: int = clampi(int(_ghost.get("car_index", 0)), 0, presets.size() - 1)
	var preset: Dictionary = presets[idx]
	var scene := load(str(preset.get("model_path", ""))) as PackedScene
	if scene == null:
		return
	_car = scene.instantiate() as Node3D
	_car.name = "GhostCar"
	add_child(_car)
	if CarPaint.is_paintable(_car):
		CarPaint.apply(_car, CarPaint.sanitize(_ghost.get("paint", {}), str(preset.get("name", ""))))
	_ghostify(_car)
	for w in WHEELS:
		var node := _car.find_child(w, true, false) as Node3D
		_wheels.append(node)
		var mi := node as MeshInstance3D
		_radii.append(maxf(mi.mesh.get_aabb().size.y * 0.5, 0.1) if mi and mi.mesh else 0.35)
	_label = Label3D.new()
	_label.name = "GhostLabel"
	_label.text = "BEST  " + TimeTrialRecords.format_ms(int(_ghost.get("total_ms", 0)))
	# In the world, so it shrinks with the car: as a fixed size on the screen it stood over the road ahead as a banner.
	# Under the car's scale (2), about 0.4m high, 0.4m over its roof.
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0045
	_label.font_size = 44
	_label.outline_size = 10
	_label.modulate = Color(TINT.r, TINT.g, TINT.b, 0.0)
	_label.outline_modulate = Color(0, 0, 0, 0.5)
	_label.no_depth_test = false
	_label.position = Vector3(0, 0.95, 0)
	_car.add_child(_label)
	_car.global_transform = Transform3D(Basis(), Vector3(0, -1000, 0))


func _ghostify(node: Node) -> void:
	if node is GeometryInstance3D and not (node is Label3D):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://ghost_car.gdshader")
		mat.set_shader_parameter("tint", TINT)
		mat.set_shader_parameter("strength", 0.0)
		(node as GeometryInstance3D).material_override = mat
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_materials.append(mat)
	for c in node.get_children():
		_ghostify(c)
