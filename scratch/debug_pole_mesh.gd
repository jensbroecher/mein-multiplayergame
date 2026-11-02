extends SceneTree

const PropKit = preload("res://PropKit.gd")
const FreightKit = preload("res://FreightKit.gd")

func _init() -> void:
	var pk = FreightKit.new_kit()
	var kit = {}
	FreightKit.pole(pk, kit)
	var mesh = pk.commit(kit)
	print("Surfaces: ", mesh.get_surface_count())
	var aabb = mesh.get_aabb()
	print("AABB: ", aabb)
	var foot = maxf(aabb.position.y, 0.0)
	var h = aabb.end.y - foot
	print("foot: ", foot, " h: ", h)
	var b0 = foot + (h * 0.04 if h > 6.0 else minf(0.3, h * 0.3))
	var b1 = foot + (h * 0.22 if h > 6.0 else minf(1.8, h))
	print("b0: ", b0, " b1: ", b1)
	
	for si in range(mesh.get_surface_count()):
		var arr = mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		print("surface ", si, " vertex count: ", v.size())
		var in_band := 0
		for q in v:
			if q.y >= b0 and q.y <= b1:
				in_band += 1
		print("  in band: ", in_band)
	quit()
