extends SceneTree
func _initialize():
	var sc = load("res://models/ramps/a0c68129ab868a396612d59572399b8f.fbx").instantiate()
	var mi: MeshInstance3D = sc.get_child(0) if sc.get_child(0) is MeshInstance3D else sc.find_children("*","MeshInstance3D",true,false)[0]
	var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# metres: *100*30 ; print max-height per 1m z bin at centre band, and per-x at peak
	var S = 3000.0
	for zi in range(-17, 18):
		var top=-1e9; var cnt=0
		for p in v:
			if abs(p.z*S - zi) < 0.5 and abs(p.x*S) < 2.0:
				top = max(top, p.y*S); cnt+=1
		print("z=%d top=%.2f n=%d" % [zi, top, cnt])
	for xi in range(-7, 8):
		var top=-1e9
		for p in v:
			if abs(p.x*S - xi) < 0.5 and abs(p.z*S) < 3.0: top=max(top,p.y*S)
		print("x=%d top=%.2f" % [xi, top])
	quit()
