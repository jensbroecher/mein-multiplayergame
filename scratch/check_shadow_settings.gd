extends SceneTree

func _init() -> void:
	var s := Shader.new()
	s.code = "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(UV2.x); }\n"
	var sm := ShaderMaterial.new()
	sm.shader = s
	print("Shader compiled cleanly.")
	quit()
