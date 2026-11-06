extends Node3D
## Al-Mu'allaq's trains, the suspended railway down Marina Nights' palm avenue and over the sea to Jazirat al-Fanous
## (regenerate_marina_nights.gd, _build_suspended): one on each track (children "Train0", "Train1", their origin on the
## rail's running surface at the train's middle, the cars hanging below; meta "track" the track's offset from `start`
## and `end`, the line's middle at its two stops), shuttling between the line's two stations on
## the wall clock (seconds into the UTC day, as Train.gd's), so LAN peers see the same trains unsynced. Each speeds up
## at `accel` to `cruise`, brakes into the far station, waits `dwell` there and goes back; the two run half a turn
## apart, so they pass each other out over the water. Hung from the rail, a train swings fore and aft as it speeds up
## and brakes (a damped pendulum about the rail, local only), and sounds as it goes (recorded, tools/elevenlabs): the
## run of its wheels on the rail and the girder's hum, a burst as it passes the listener, the brakes into a station,
## a chime as it pulls out.
## Nothing collides: the line runs 20m over the street.

@export var start := Vector3.ZERO
@export var end := Vector3(0, 0, 100)
@export var cruise := 16.0
@export var accel := 0.9
@export var dwell := 28.0
@export var clock_override := -1.0

const SWING_K := 5.5
const SWING_DAMP := 1.1
const G := 9.81
## Its sounds, recorded with tools/elevenlabs, each levelled by its measured RMS or loudest second: the run (steel
## wheels on the rail, the girder humming: -18 dBFS RMS, to -20 at full speed within its unit size), a pass-by burst
## when it comes by the listener (`PASSBY`, loudest second to -16 dBFS), the brakes as it slows into a station (to -24
## at its unit size) and the station's chime as it pulls out (-14.3 dBFS RMS, to -24).
const RUN_CLIP := "res://sounds/muallaq/suspended_train_run_loop.wav"
const RUN_GAIN := -2.0
const PASSBY := [["res://sounds/muallaq/suspended_passby_1.wav", 2.5], ["res://sounds/muallaq/suspended_passby_2.wav", 4.6]]
const PASSBY_NEAR := 60.0
const PASSBY_REARM := 120.0
const BRAKE_CLIP := "res://sounds/muallaq/suspended_brakes.wav"
const BRAKE_DB := 9.5
const CHIME_CLIP := "res://sounds/muallaq/station_chime.wav"
const CHIME_DB := -9.7

var _trains: Array[Node3D] = []
var _tracks: Array = []
var _swing: Array = []
var _audio: Array = []
var _len := 0.0
var _dir := Vector3.FORWARD
var _trip := 0.0
var _chimes: Array = []
var _was_at: Array = []
var _fx: Array = []
var _passby: Array = []
var _armed: Array = []
var _braking: Array = []
var _brake: AudioStream


func _ready() -> void:
	_len = start.distance_to(end)
	_dir = (end - start).normalized()
	var ramp: float = cruise * cruise / accel
	_trip = 2.0 * cruise / accel + maxf(_len - ramp, 0.0) / cruise if _len > ramp else 2.0 * sqrt(_len / accel)
	for c in get_children():
		if String(c.name).begins_with("Train") and c is Node3D:
			_trains.append(c)
			_tracks.append(c.get_meta("track", Vector3.ZERO))
			_swing.append([0.0, 0.0])
	if DisplayServer.get_name() != "headless":
		var clip: AudioStream = load(RUN_CLIP)
		for pb in PASSBY:
			_passby.append([load(String(pb[0])), float(pb[1])])
		_brake = load(BRAKE_CLIP)
		var bus: StringName = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		for t in _trains:
			var p := AudioStreamPlayer3D.new()
			p.stream = clip
			p.unit_size = 35.0
			p.max_distance = 700.0
			p.volume_db = -60.0
			p.position = Vector3(0, -4.0, 0)
			p.bus = bus
			t.add_child(p)
			_audio.append(p)
			# A second player for its one-shots: the pass-by burst and the brakes.
			var f := AudioStreamPlayer3D.new()
			f.unit_size = 30.0
			f.max_distance = 600.0
			f.position = Vector3(0, -4.0, 0)
			f.bus = bus
			t.add_child(f)
			_fx.append(f)
			_was_at.append(-1)
			_armed.append(true)
			_braking.append(false)
		var chime: AudioStream = load(CHIME_CLIP)
		for at in [start, end]:
			var c := AudioStreamPlayer3D.new()
			c.stream = chime
			c.unit_size = 25.0
			c.max_distance = 400.0
			c.volume_db = CHIME_DB
			c.position = at + Vector3(0, -6.0, 0)
			c.bus = bus
			add_child(c)
			_chimes.append(c)
	_update(0.0)


func _physics_process(delta: float) -> void:
	_update(delta)


## Whether a train `t` seconds into its turn is going from `start` to `end` (else back, or standing).
func _moving_out(t: float) -> bool:
	return t >= dwell and t < dwell + _trip


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fposmod(Time.get_unix_time_from_system(), 86400.0)


## Distance along the line and the acceleration along it, `t` seconds into a trip from one station to the other.
func _profile(t: float) -> Vector2:
	var ramp_t: float = cruise / accel
	var ramp_d: float = 0.5 * accel * ramp_t * ramp_t
	if _len <= 2.0 * ramp_d:
		var half: float = _trip * 0.5
		if t < half:
			return Vector2(0.5 * accel * t * t, accel)
		var r: float = _trip - t
		return Vector2(_len - 0.5 * accel * r * r, -accel)
	if t < ramp_t:
		return Vector2(0.5 * accel * t * t, accel)
	if t > _trip - ramp_t:
		var r2: float = _trip - t
		return Vector2(_len - 0.5 * accel * r2 * r2, -accel)
	return Vector2(ramp_d + (t - ramp_t) * cruise, 0.0)


func _update(delta: float) -> void:
	var cycle: float = 2.0 * (_trip + dwell)
	var now: float = _clock()
	for i in range(_trains.size()):
		var t: float = fposmod(now + float(i) * (_trip + dwell), cycle)
		var s := 0.0
		var a := 0.0
		var v := 0.0
		# Which station it stands at (0 the start, 1 the end, -1 under way): the chime as it pulls out.
		var at := -1
		if t < dwell:
			s = 0.0
			at = 0
		elif t < dwell + _trip:
			var pr := _profile(t - dwell)
			s = pr.x
			a = pr.y
			v = clampf(minf((t - dwell) * accel, (dwell + _trip - t) * accel), 0.0, cruise)
		elif t < 2.0 * dwell + _trip:
			s = _len
			at = 1
		else:
			var pr2 := _profile(t - 2.0 * dwell - _trip)
			s = _len - pr2.x
			a = -pr2.y
			v = clampf(minf((t - 2.0 * dwell - _trip) * accel, (cycle - t) * accel), 0.0, cruise)
		# The pendulum: it lags behind as the train speeds up, swings ahead as it brakes, and settles.
		var sw: Array = _swing[i]
		if delta > 0.0:
			var target: float = atan(a / G)
			var acc: float = -SWING_K * (float(sw[0]) - target) - SWING_DAMP * float(sw[1])
			sw[1] = float(sw[1]) + acc * delta
			sw[0] = float(sw[0]) + float(sw[1]) * delta
		var tr: Node3D = _trains[i]
		var face := Basis.looking_at(_dir, Vector3.UP)
		tr.transform = Transform3D(face * Basis(Vector3.RIGHT, -float(sw[0])), start + (_tracks[i] as Vector3) + _dir * s)
		if i < _audio.size():
			var p: AudioStreamPlayer3D = _audio[i]
			if v > 0.5:
				p.volume_db = RUN_GAIN + lerpf(-14.0, 0.0, clampf(v / cruise, 0.0, 1.0))
				p.pitch_scale = lerpf(0.85, 1.05, clampf(v / cruise, 0.0, 1.0))
				if not p.playing:
					p.play()
			elif p.playing:
				p.stop()
			if int(_was_at[i]) >= 0 and at < 0 and delta > 0.0:
				(_chimes[int(_was_at[i])] as AudioStreamPlayer3D).play()
			_was_at[i] = at
			var fx: AudioStreamPlayer3D = _fx[i]
			# The brakes as it starts slowing into a station.
			var braking: bool = a * (1.0 if _moving_out(t) else -1.0) < -0.01 and v > 2.0
			if braking and not bool(_braking[i]) and delta > 0.0:
				fx.stream = _brake
				fx.volume_db = BRAKE_DB
				fx.play()
			_braking[i] = braking
			# The pass-by burst when it comes by the listener at speed, once a pass.
			var cam := get_viewport().get_camera_3d()
			if cam and delta > 0.0 and not _passby.is_empty():
				var dist: float = cam.global_position.distance_to(tr.global_position)
				if bool(_armed[i]) and dist < PASSBY_NEAR and v > 8.0 and not (braking and fx.playing):
					var pick: Array = _passby[randi() % _passby.size()]
					fx.stream = pick[0]
					fx.volume_db = float(pick[1])
					fx.pitch_scale = randf_range(0.95, 1.05)
					fx.play()
					_armed[i] = false
				elif dist > PASSBY_REARM:
					_armed[i] = true
