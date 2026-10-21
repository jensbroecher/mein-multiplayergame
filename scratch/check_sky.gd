extends SceneTree

func _init():
	var scene = load("res://levels/LakesideLevel.tscn").instantiate()
	var env_node = scene.get_node_or_null("WorldEnvironment")
	if env_node and env_node.environment and env_node.environment.sky:
		var mat = env_node.environment.sky.sky_material
		print("Sky material: ", mat)
		print("Shader: ", mat.shader.resource_path)
		for p in ["wind_dir", "cloud_lit", "cloud_shade", "cloud_coverage", "cloud_opacity", "cloud_scale", "cloud_seed"]:
			print("param ", p, " = ", mat.get_shader_parameter(p))
	else:
		print("WorldEnvironment not found or no sky")
	quit()
