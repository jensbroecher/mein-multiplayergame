extends SceneTree
func _init() -> void:
	var d = load("res://VortexBuilder.gd").new()
	var shapes: Dictionary = d._detail_shapes()
	var width := 384
	var height := 384
	var half: float = d.half_ring
	var found := 0
	for i in width:
		var z: float = d.z_of_u((i + 0.5) / width)
		if z > -1.07: continue
		var sec: PackedVector2Array = d.section(z)
		var col := PackedVector3Array()
		for j in height:
			var t: float = (j + 0.5) / height * half
			var k: int = mini(int(t), half - 1)
			var p2: Vector2 = sec[k].lerp(sec[k + 1], t - k)
			col.append(Vector3(p2.x, p2.y, z))
		for j in height:
			var p: Vector3 = col[j]
			var du := col[mini(i + 1, width - 1)] - col[maxi(i - 1, 0)]
			var dv := col[mini(j + 1, height - 1)] - col[maxi(j - 1, 0)]
			var nrm := dv.cross(du)
			var sec_out := Vector2(dv.y, -dv.x)
			if Vector2(nrm.x, nrm.y).dot(sec_out) < 0.0 and sec_out.length_squared() > 1e-12:
				nrm = -nrm
			nrm = nrm.normalized()
			# report texels that ARE inside the slat y-band on the face
			if absf(p.x) < 0.16 and p.y > 0.215 and p.y < 0.27 and found < 26:
				var c: Color = d._detail_at(p, nrm, 0.0012, shapes)
				print("z=%.4f p=(%.3f, %.3f, %.3f) n=(%.2f, %.2f, %.2f) -> A=%.2f" % [z, p.x, p.y, p.z, nrm.x, nrm.y, nrm.z, c.a])
				found += 1
	if found == 0:
		print("NO TEXELS COVER THE FACE BOX (y 0.215-0.27, |x|<0.16) near the tip")
	quit()
