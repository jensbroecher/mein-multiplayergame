extends Node3D
## The crowd along a stretch of the lap cheering as the racers go by (regenerate_marina_nights.gd: the start promenade's
## barriers and its grandstand, `_build_cheers`). Each child "Section*" (a Node3D where a part of the crowd stands; meta
## "gain" in dB for a louder part, the grandstand) cheers when a cart comes within `reach` of it faster than `min_speed`:
## a clip from CLIPS (recorded with tools/elevenlabs), picked at random but never the one it played last, from an
## AudioStreamPlayer3D of its own, louder for a faster cart; then it rests `cooldown` seconds and a little more, so a
## pack makes one cheer and the cheers roll along the straight with the leaders. Local only: every peer's crowd reacts
## to the carts it sees (their speed from how far they moved). Nothing on a headless server.

## [clip, gain]: each clip's gain brings its loudest second (scratch/measure_clip_rms.gd) to -20 dBFS within the
## players' unit size.
const CLIPS := [
	["res://sounds/crowd/promenade_cheer_1.wav", 9.0],
	["res://sounds/crowd/promenade_cheer_2.wav", 14.3],
	["res://sounds/crowd/promenade_cheer_3.wav", 12.1],
	["res://sounds/crowd/promenade_cheer_4.wav", 1.5],
	["res://sounds/crowd/promenade_cheer_5.wav", -7.6],
	["res://sounds/crowd/promenade_cheer_6.wav", 8.2],
]

@export var reach := 24.0
@export var min_speed := 12.0
@export var cooldown := 5.0

var _streams: Array = []
var _sections: Array = []
var _carts: Array = []
var _prev := {}
var _refresh := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_physics_process(false)
		return
	_rng.randomize()
	for c in CLIPS:
		if ResourceLoader.exists(String(c[0])):
			_streams.append([load(String(c[0])), float(c[1])])
	for ch in get_children():
		if not (String(ch.name).begins_with("Section") and ch is Node3D):
			continue
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 18.0
		p.max_distance = 260.0
		p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
		ch.add_child(p)
		_sections.append({"node": ch, "player": p, "ready_at": 0.0, "last": -1, "gain": float(ch.get_meta("gain", 0.0))})


func _physics_process(delta: float) -> void:
	if _streams.is_empty() or _sections.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		_carts = get_tree().get_nodes_in_group("player_carts")
	for cart in _carts:
		if not is_instance_valid(cart) or not (cart is Node3D):
			continue
		var pos: Vector3 = (cart as Node3D).global_position
		var id: int = cart.get_instance_id()
		var prev: Vector3 = _prev.get(id, pos)
		_prev[id] = pos
		var speed: float = Vector2(pos.x - prev.x, pos.z - prev.z).length() / maxf(delta, 1e-4)
		if speed < min_speed or speed > 150.0:
			continue
		for sec in _sections:
			if now < float(sec.ready_at):
				continue
			var at: Vector3 = (sec.node as Node3D).global_position
			if Vector2(at.x - pos.x, at.z - pos.z).length() > reach:
				continue
			var k: int = _rng.randi() % _streams.size()
			if k == int(sec.last) and _streams.size() > 1:
				k = (k + 1) % _streams.size()
			sec.last = k
			var p: AudioStreamPlayer3D = sec.player
			p.stream = _streams[k][0]
			# Several overlap as a pack goes by (both sides, a section every 30m, 4-5s each): 4dB under the clip's level.
			p.volume_db = float(_streams[k][1]) + float(sec.gain) + lerpf(-8.0, -2.5, clampf((speed - min_speed) / 40.0, 0.0, 1.0))
			p.pitch_scale = _rng.randf_range(0.96, 1.04)
			p.play()
			sec.ready_at = now + cooldown + _rng.randf_range(0.0, 2.0)
