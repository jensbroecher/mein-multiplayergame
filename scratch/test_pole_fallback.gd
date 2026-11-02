extends SceneTree

const PropKit = preload("res://PropKit.gd")
const FreightKit = preload("res://FreightKit.gd")

func _init() -> void:
	var pk = FreightKit.new_kit()
	var kit = {}
	FreightKit.pole(pk, kit)
	var mesh = pk.commit(kit)
	
	var aabb: AABB = mesh.get_aabb()
	var foot: float = maxf(aabb.position.y, 0.0)
	var h: float = aabb.end.y - foot
	var band := PackedFloat32Array()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var reach_top: float = foot + minf(h, 2.6)
	
	var b0: float = foot + (h * 0.04 if h > 6.0 else minf(0.3, h * 0.3))
	var b1: float = foot + (h * 0.22 if h > 6.0 else minf(1.8, h))
	
	for si in range(mesh.get_surface_count()):
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var step: int = maxi(1, v.size() / 6000)
		for k in range(0, v.size(), step):
			var q: Vector3 = v[k]
			if q.y >= b0 and q.y <= b1:
				band.append(Vector2(q.x, q.z).length())
			if q.y <= reach_top:
				lo = lo.min(q)
				hi = hi.max(q)
				
	print("Initial band size: ", band.size())
	if band.is_empty() and lo.x != INF:
		# Mesh has vertices below reach_top (e.g. at the foot of a tall cylinder/post), but none strictly in [b0, b1].
		# Sample vertices near the foot to get the trunk/post radius.
		for si in range(mesh.get_surface_count()):
			var arr := mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for q in v:
				if q.y <= reach_top:
					band.append(Vector2(q.x, q.z).length())
		print("Fallback band size: ", band.size())
	
	if not band.is_empty() and lo.x != INF:
		band.sort()
		var r_med: float = band[band.size() / 2]
		var horiz: float = maxf(hi.x - lo.x, hi.z - lo.z) * 0.5
		var info := {}
		if h > 4.0 * maxf(r_med, 0.01) and r_med < horiz * 0.7:
			var ch: float = minf(h, 6.0)
			info = {"kind": "cyl", "r": maxf(r_med * 0.9, 0.05), "h": h, "ch": ch, "centre": Vector3(0.0, foot + ch * 0.5, 0.0)}
		else:
			var size: Vector3 = hi - lo
			size.x *= 0.85
			size.z *= 0.85
			info = {"kind": "box", "r": horiz * 0.85, "h": h, "size": size, "centre": (lo + hi) * 0.5}
		print("Computed info: ", info)
	quit()

