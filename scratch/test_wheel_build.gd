extends SceneTree

func _init() -> void:
	var CB = load("res://CarBuilder.gd")
	var b = CB.new()
	var builder = load("res://ZephyrBuilder.gd").new()
	builder.build_wheel(b, 1.0)
	print("Wheel built successfully! Vertices: ", b.vertex_count(), " Indices: ", b.index_count())
	quit()
