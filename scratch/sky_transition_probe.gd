# scratch/sky_transition_probe.gd
extends SceneTree

func _init() -> void:
	print("--- Sky Transition Probe ---")
	var shader: Shader = load("res://sky_tropical_cumulus.gdshader")
	print("Shader loaded: ", shader != null)
	var list: PackedStringArray = RenderingServer.global_shader_parameter_get_list()
	print("Global params list: ", list)
	RenderingServer.global_shader_parameter_set(&"rain_sky_blend", 0.5)
	print("Get StringName: ", RenderingServer.global_shader_parameter_get(&"rain_sky_blend"))
	print("Get String: ", RenderingServer.global_shader_parameter_get("rain_sky_blend"))
	quit(0)


