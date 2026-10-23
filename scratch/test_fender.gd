extends SceneTree

func _init() -> void:
	var builder = load("res://ZephyrBuilder.gd").new()
	print("--- FRONT FENDER ---")
	for k in 33:
		var t: float = float(k) / 32.0
		var a: float = lerpf(2.45, 0.30, t)
		var z: float = -0.660 + 0.300 * cos(a)
		var y_arch: float = 0.270 + 0.300 * sin(a)
		var body_w: float = builder.prof["w"].at(z)
		var x_in: float = body_w - 0.015
		var y_in: float = builder.top_y(x_in, z) - 0.008
		print("k=%2d  t=%.2f  z=%.3f  y_arch=%.3f  w=%.3f  x_in=%.3f  y_in=%.3f" % [k, t, z, y_arch, body_w, x_in, y_in])

	print("--- REAR FENDER ---")
	for k in 33:
		var t: float = float(k) / 32.0
		var a: float = lerpf(2.65, 0.60, t)
		var z: float = 0.620 + 0.306 * cos(a)
		var y_arch: float = 0.270 + 0.306 * sin(a)
		var body_w: float = builder.prof["w"].at(z)
		var x_in: float = body_w - 0.015
		var y_in: float = builder.top_y(x_in, z) - 0.008
		print("k=%2d  t=%.2f  z=%.3f  y_arch=%.3f  w=%.3f  x_in=%.3f  y_in=%.3f" % [k, t, z, y_arch, body_w, x_in, y_in])
	quit()
