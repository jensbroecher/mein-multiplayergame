extends Node

# Rides along with an AI cart in a spectator race through its own race camera (as race_cam_shots does)
# and measures how the view moves, for motion comfort: how fast the camera turns (deg/s), how hard
# that turn speeds up and slows down (deg/s^2), the frame-to-frame shake left over after a short
# smoothing, the FOV's swing, and where the cart sits on screen (and how fast it moves there).
# Headless is fine (it reads the transforms PlayerCart sets in _process). Use --fixed-fps 60 so the
# frames line up with physics:
#   Godot --headless --fixed-fps 60 --path . res://scratch/race_cam_motion_probe.tscn --
#       [level=res://levels/LakesideLevel.tscn] [mode=chase|top|follow] [cart=0] [seconds=60] [skip=4]


var _cart: Node
var _mode := "chase"
var _seconds := 60.0
var _skip := 4.0
var _t := 0.0
var _prev_fwd := Vector3.ZERO
var _prev_rate := NAN
var _rates: Array[float] = []
var _accels: Array[float] = []
var _yaw_rates: Array[float] = []
var _pitches: Array[float] = []
var _fovs: Array[float] = []
var _screen: Array[Vector2] = []
var _screen_speed: Array[float] = []
var _shake: Array[float] = []
var _smooth_rate := NAN
var _last_edge_note := -10.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := "res://levels/LakesideLevel.tscn"
	var index := 0
	for a in args:
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("mode="): _mode = a.substr(5)
		elif a.begins_with("cart="): index = int(a.substr(5))
		elif a.begins_with("seconds="): _seconds = float(a.substr(8))
		elif a.begins_with("skip="): _skip = float(a.substr(5))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	var carts: Array = []
	while carts.size() <= index:
		await get_tree().physics_frame
		carts = get_tree().get_nodes_in_group("player_carts")
	var cart = carts[index]
	while not cart.can_move:
		await get_tree().physics_frame
	cart.is_local_player = true
	cart.is_isometric = _mode == "top"
	cart.is_high_chase = _mode == "chase"
	cart.camera_pivot.top_level = true
	cart.camera.make_current()
	_cart = cart


func _process(delta: float) -> void:
	if _cart == null or delta <= 0.0:
		return
	_t += delta
	if _t < _skip:
		return
	var cam: Camera3D = _cart.camera
	var fwd: Vector3 = -cam.global_transform.basis.z
	if _prev_fwd != Vector3.ZERO:
		var rate: float = rad_to_deg(_prev_fwd.angle_to(fwd)) / delta
		_rates.append(rate)
		var hp := Vector2(_prev_fwd.x, _prev_fwd.z)
		var hn := Vector2(fwd.x, fwd.z)
		if hp.length() > 0.01 and hn.length() > 0.01:
			_yaw_rates.append(absf(rad_to_deg(hp.angle_to(hn))) / delta)
		if not is_nan(_prev_rate):
			_accels.append(absf(rate - _prev_rate) / delta)
		_prev_rate = rate
		# Shake: what a 0.15s smoothing of the turn rate doesn't account for.
		_smooth_rate = rate if is_nan(_smooth_rate) else lerpf(_smooth_rate, rate, minf(delta / 0.15, 1.0))
		_shake.append(absf(rate - _smooth_rate))
	_prev_fwd = fwd
	_pitches.append(rad_to_deg(asin(clampf(-fwd.y, -1.0, 1.0))))
	_fovs.append(cam.fov)
	var vp := get_viewport().get_visible_rect().size
	var car_pos: Vector3 = _cart.get_node("Visuals").global_position
	if not cam.is_position_behind(car_pos):
		var p: Vector2 = cam.unproject_position(car_pos)
		var n := Vector2((p.x / vp.x) * 2.0 - 1.0, (p.y / vp.y) * 2.0 - 1.0)
		if not _screen.is_empty():
			_screen_speed.append(n.distance_to(_screen[-1]) / delta)
		_screen.append(n)
		# Moments where the cart nears the frame's edge, at most one line a second.
		if (absf(n.x) > 0.6 or absf(n.y) > 0.7) and _t - _last_edge_note > 1.0:
			_last_edge_note = _t
			print("EDGE t=%.1f screen %s cart %s speed %.1f cam %s pitch %.1f" % [_t, n, car_pos,
					_cart.linear_velocity.length(), cam.global_position, _pitches[-1]])
	if _t >= _skip + _seconds:
		_report()
		get_tree().quit()


func _report() -> void:
	print("MOTION mode=%s frames=%d" % [_mode, _rates.size()])
	print("  turn rate deg/s     mean %6.1f  p95 %6.1f  max %6.1f" % [_mean(_rates), _pct(_rates, 0.95), _pct(_rates, 1.0)])
	print("  yaw rate deg/s      mean %6.1f  p95 %6.1f  max %6.1f" % [_mean(_yaw_rates), _pct(_yaw_rates, 0.95), _pct(_yaw_rates, 1.0)])
	print("  turn accel deg/s^2  mean %6.0f  p95 %6.0f  max %6.0f" % [_mean(_accels), _pct(_accels, 0.95), _pct(_accels, 1.0)])
	print("  shake deg/s         mean %6.2f  p95 %6.2f  max %6.1f" % [_mean(_shake), _pct(_shake, 0.95), _pct(_shake, 1.0)])
	print("  pitch down deg      min %6.1f  mean %6.1f  max %6.1f" % [_pct(_pitches, 0.0), _mean(_pitches), _pct(_pitches, 1.0)])
	print("  fov                 min %6.1f  max %6.1f" % [_pct(_fovs, 0.0), _pct(_fovs, 1.0)])
	var xs: Array[float] = []
	var ys: Array[float] = []
	for s in _screen:
		xs.append(absf(s.x))
		ys.append(s.y)
	print("  cart on screen |x|  mean %5.2f  p95 %5.2f  max %5.2f   y mean %5.2f  range %5.2f..%5.2f" % [
			_mean(xs), _pct(xs, 0.95), _pct(xs, 1.0), _mean(ys), _pct(ys, 0.0), _pct(ys, 1.0)])
	print("  cart screen speed   mean %5.2f  p95 %5.2f  (half-screens/s)" % [_mean(_screen_speed), _pct(_screen_speed, 0.95)])


func _mean(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


func _pct(a: Array[float], q: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	return b[clampi(int(round(q * (b.size() - 1))), 0, b.size() - 1)]
