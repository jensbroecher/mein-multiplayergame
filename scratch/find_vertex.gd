extends SceneTree

const MirageBuilder = preload("res://MirageBuilder.gd")
const CB = preload("res://CarBuilder.gd")

func _init() -> void:
	var TestClass = load("res://scratch/test_mirage_fix.gd").TestMirageBuilder
	var builder = TestClass.new()
	var body = CB.new()
	builder.build_body(body)

	var target = Vector3(0.137525, 0.425452, -1.042781)
	for k in body._v.size():
		if body._v[k].distance_to(target) < 0.001:
			print("Found vertex %d at %s: mat=%d (uv2.x=%f), col=%s" % [
				k, str(body._v[k]), int(round(body._uv2[k].x)), body._uv2[k].x, str(body._c[k])
			])

	quit(0)

