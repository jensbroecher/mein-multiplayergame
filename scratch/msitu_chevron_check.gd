extends SceneTree

# Lists every Msitu Falls chevron board in the saved level: where it is, which way its arrows point
# and which way the road turns there. Every board must point into the bend ("ok"); the last line
# counts the ones that don't. Needs the level generated.
#   Godot --headless --path . -s res://scratch/msitu_chevron_check.gd
# (Ignore the "Identifier not found" errors for the autoloads: a -s script has none, and the level loads anyway.)

func _init() -> void:
	var level: Node3D = load("res://levels/MsituFallsLevel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	var mi: MeshInstance3D = level.get_node("JungleDressing/Chevrons/ChevronBoards")
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var curve: Curve3D = (level.get_node("TrackPath") as Path3D).curve
	var length := curve.get_baked_length()
	var bad := 0
	var total := 0
	# 12 vertices per board: 6 for the front, 6 for the back.
	for b in range(v.size() / 12):
		var i0 := b * 12
		var c := Vector3.ZERO
		for k in range(6):
			c += v[i0 + k]
		c /= 6.0
		var nrm := n[i0]
		# The shader draws its arrows toward +UV.x: the gradient of u across the front face, in the world.
		var e1 := v[i0 + 1] - v[i0]
		var e2 := v[i0 + 2] - v[i0]
		var grad: Vector3 = Basis(e1, e2, nrm).transposed().inverse() * Vector3(uv[i0 + 1].x - uv[i0].x, uv[i0 + 2].x - uv[i0].x, 0.0)
		var arrow := grad.normalized()
		var off := curve.get_closest_offset(c)
		var t0 := (curve.sample_baked(fposmod(off + 6.0, length)) - curve.sample_baked(fposmod(off - 6.0, length))).normalized()
		var t_ahead := (curve.sample_baked(fposmod(off + 22.0, length)) - curve.sample_baked(fposmod(off + 18.0, length))).normalized()
		var t_behind := (curve.sample_baked(fposmod(off - 18.0, length)) - curve.sample_baked(fposmod(off - 22.0, length))).normalized()
		# Turning right when the heading swings clockwise seen from above (y of behind x ahead < 0).
		var right_turn: bool = t_behind.cross(t_ahead).y < 0.0
		var right_of_travel: Vector3 = t0.cross(Vector3.UP).normalized()
		var turn_dir: Vector3 = right_of_travel if right_turn else -right_of_travel
		var ok: bool = arrow.dot(turn_dir) > 0.0 and nrm.dot(-t0) > 0.5
		total += 1
		if not ok:
			bad += 1
		print("board %2d at (%7.1f, %5.1f, %7.1f) turn %s, arrows point %s, face the oncoming car %.2f  %s" % [b, c.x, c.y, c.z,
				"R" if right_turn else "L", "right" if arrow.dot(right_of_travel) > 0.0 else "left", nrm.dot(-t0), "ok" if ok else "WRONG"])
	print("wrong %d of %d" % [bad, total])
	quit()
