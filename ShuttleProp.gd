extends AnimatableBody3D
## A slow machine driving back and forth along its own -z on the wall clock (Quer durch Kronburg's road roller on the
## building site's road), so every LAN peer sees it in the same place without syncing. It is solid (an AnimatableBody3D
## with the boxes the generator gives it, `sync_to_physics` off, moved in _physics_process): a cart bumps it and is
## pushed, nothing worse. From where it was placed it drives `distance` metres along its -z at `speed`, stands `dwell`
## seconds, backs up, stands, and again. Its mesh's wheels or drums (children named "Drum*", turned about their x axis by
## the distance) roll with it. A diesel loop (`motor`) and a reversing beeper (`beeper`) while it backs up.

@export var distance := 14.0
@export var speed := 1.8
@export var dwell := 4.0
@export var phase := 0.0
@export var drum_radius := 0.8
@export var motor: AudioStream
@export var motor_db := -10.0
@export var beeper: AudioStream
@export var beeper_db := -14.0
@export var clock_override := -1.0

var period := 30.0
var _home := Transform3D.IDENTITY
var _drums: Array[Node3D] = []
var _motor_player: AudioStreamPlayer3D
var _beep_player: AudioStreamPlayer3D


func _ready() -> void:
	sync_to_physics = false
	# Its place before it ever moved: _apply moves it at once, and a level saved by its generator keeps the moved transform
	# (wherever the clock had it then), so it is kept in a meta the first time and read back from it after.
	if has_meta(&"home"):
		_home = get_meta(&"home")
	else:
		_home = transform
		set_meta(&"home", _home)
	var run: float = distance / maxf(speed, 0.1)
	period = 2.0 * (run + dwell)
	for c in get_children():
		if c is Node3D and String(c.name).begins_with("Drum"):
			_drums.append(c)
	if DisplayServer.get_name() != "headless":
		if motor != null:
			_motor_player = _player("Motor", motor, motor_db)
			_motor_player.play()
		if beeper != null:
			_beep_player = _player("Beeper", beeper, beeper_db)
	_apply(_clock())


func _player(n: String, s: AudioStream, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.stream = s
	p.volume_db = db
	p.unit_size = 18.0
	p.max_distance = 300.0
	p.position = Vector3(0, 2.0, 0)
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p, false, Node.INTERNAL_MODE_BACK)
	return p


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## How far along its run it is `tc` seconds into the cycle, and whether it is backing up.
func _travel(tc: float) -> Vector2:
	var run: float = distance / maxf(speed, 0.1)
	if tc < run:
		return Vector2(distance * _ease(tc / run), 0.0)
	if tc < run + dwell:
		return Vector2(distance, 0.0)
	if tc < 2.0 * run + dwell:
		return Vector2(distance * (1.0 - _ease((tc - run - dwell) / run)), 1.0)
	return Vector2(0.0, 0.0)


func _apply(t: float) -> void:
	var tc: float = fposmod(t - phase, period)
	var tr: Vector2 = _travel(tc)
	transform = Transform3D(_home.basis, _home.origin - _home.basis.z.normalized() * tr.x)
	for d in _drums:
		d.rotation.x = -tr.x / maxf(drum_radius, 0.1)
	if _beep_player != null:
		var backing: bool = tr.y > 0.5 and tr.x > 0.05 and tr.x < distance - 0.05
		if backing and not _beep_player.playing:
			_beep_player.play()
		elif not backing and _beep_player.playing:
			_beep_player.stop()


func _physics_process(_delta: float) -> void:
	_apply(_clock())
