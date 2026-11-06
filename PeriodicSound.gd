extends AudioStreamPlayer3D
## A one-shot that sounds every `every` seconds on the wall clock, offset by `phase` (so LAN peers hear it together):
## Kronburger Hütte's church bells and the mill hall's crane horn. `jitter` > 0 instead waits a random
## every +- jitter between plays (local only, for noises nobody needs to hear in step). Nothing on a headless server.

@export var every := 120.0
@export var phase := 0.0
@export var jitter := 0.0

var _next := 0.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_next = _schedule(_now())


func _now() -> float:
	return Time.get_unix_time_from_system()


func _schedule(t: float) -> float:
	if jitter > 0.0:
		return t + maxf(1.0, every + randf_range(-jitter, jitter))
	var k: float = floor((t - phase) / every) + 1.0
	return phase + k * every


func _process(_delta: float) -> void:
	var t := _now()
	if t >= _next:
		# A long gap (the game paused, the clock jumped) plays once, not once per missed slot.
		if t - _next < 2.0:
			play()
		_next = _schedule(t)
