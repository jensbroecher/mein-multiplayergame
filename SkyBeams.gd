extends Node3D
## The searchlights round Burj al-Fanous (regenerate_marina_nights.gd, _build_island): every child "Beam*" is a long cone
## of light along its local +y (club_beam.gdshader, additive), which this turns about the vertical in a slow circle,
## tilted out and its tilt breathing, the beams in turn going opposite ways so they cross over the tower. On the wall
## clock, so every peer sees the same sky. A beam's own phase and turning way are its metas "phase" and "spin".

@export var period := 46.0
@export var tilt := 0.32
@export var clock_override := -1.0

var _beams: Array[Node3D] = []


func _ready() -> void:
	for c in get_children():
		if String(c.name).begins_with("Beam") and c is Node3D:
			_beams.append(c)
	_update()


func _physics_process(_delta: float) -> void:
	_update()


func _update() -> void:
	var t: float = clock_override if clock_override >= 0.0 else fposmod(Time.get_unix_time_from_system(), 3600.0)
	for i in range(_beams.size()):
		var b: Node3D = _beams[i]
		var ph: float = float(b.get_meta("phase", 0.0))
		var spin: float = float(b.get_meta("spin", 1.0))
		var yaw: float = ph + spin * TAU * t / period
		var lean: float = tilt * (0.75 + 0.25 * sin(t * 0.21 + ph * 3.0))
		b.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean)
