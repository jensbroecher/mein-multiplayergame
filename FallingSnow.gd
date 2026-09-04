# FallingSnow.gd
extends GPUParticles3D

func _ready() -> void:
	top_level = true

func _process(_delta: float) -> void:
	var vp = get_viewport()
	if vp:
		var cam = vp.get_camera_3d()
		if cam:
			global_position = cam.global_position + Vector3(0.0, 9.0, 0.0)
