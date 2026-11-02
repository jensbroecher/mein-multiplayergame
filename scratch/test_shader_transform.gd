extends SceneTree

func _init() -> void:
	var code = """
shader_type spatial;
void vertex() {
	vec3 wp = (MODEL_MATRIX * TRANSFORM * vec4(VERTEX, 1.0)).xyz;
}
"""
	var shader = Shader.new()
	shader.code = code
	var mat = ShaderMaterial.new()
	mat.shader = shader
	var mi = MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = mat
	var mmi = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	mmi.multimesh = mm
	mmi.material_override = mat
	print("Shader compilation test completed without crash.")
	quit()

