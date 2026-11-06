extends GPUParticles3D
## A one-shot particle burst on the wall clock (so LAN peers see it together): Zeche Kronprinz's quench tower, whose
## steam bursts out every `every` seconds at `phase` as a car of coke is quenched. Plays its child AudioStreamPlayer3D
## "Sound" (if any) with each burst. Nothing on a headless server.

@export var every := 95.0
@export var phase := 0.0

var _next := 0.0


func _ready() -> void:
	one_shot = true
	emitting = false
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_next = _schedule(Time.get_unix_time_from_system())


func _schedule(t: float) -> float:
	return phase + (floor((t - phase) / every) + 1.0) * every


func _process(_delta: float) -> void:
	var t := Time.get_unix_time_from_system()
	if t >= _next:
		if t - _next < 2.0:
			restart()
			emitting = true
			var s := get_node_or_null("Sound") as AudioStreamPlayer3D
			if s:
				s.play()
		_next = _schedule(t)
