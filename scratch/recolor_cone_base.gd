extends SceneTree
## Recolours the base of saved traffic-cone meshes (CampKit.cone, saved by Lakeside, Bloombay Dunes and Pinecrest
## Ridge) to CampKit.CONE_BASE in place, without regenerating those levels: every vertex in the bottom 8cm whose
## colour is near black. Headless:
##   Godot --headless --path . -s res://scratch/recolor_cone_base.gd -- res://generated/lakeside_cone.res ...

const CampKit = preload("res://CampKit.gd")

func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var mesh: ArrayMesh = load(path)
		var out := ArrayMesh.new()
		var changed := 0
		for si in range(mesh.get_surface_count()):
			var arr: Array = mesh.surface_get_arrays(si)
			var mat: Material = mesh.surface_get_material(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var c = arr[Mesh.ARRAY_COLOR]
			if c is PackedColorArray:
				var cols: PackedColorArray = c
				for i in range(v.size()):
					var q: Color = cols[i]
					if v[i].y < 0.08 and q.r < 0.2 and q.g < 0.2 and q.b < 0.2:
						cols[i] = CampKit.CONE_BASE
						changed += 1
				arr[Mesh.ARRAY_COLOR] = cols
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			out.surface_set_material(si, mat)
			out.surface_set_name(si, mesh.surface_get_name(si))
		out.take_over_path(path)
		var err := ResourceSaver.save(out, path)
		print("%s: %d vertices recoloured (%s)" % [path, changed, error_string(err)])
	quit()
