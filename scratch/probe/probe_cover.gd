extends SceneTree
func _init() -> void:
	var d = load("res://VortexBuilder.gd").new()
	# _cover lives on CarDesign? try calling a protected method through a wrapper
	if d.has_method("_cover"):
		var fp := 0.0012
		for dy in [0.005, 0.002, 0.0, -0.002, -0.01, -0.05]:
			print("dy=%.3f -> cover=%.3f" % [dy, d.call("_cover", dy, fp)])
	quit()
