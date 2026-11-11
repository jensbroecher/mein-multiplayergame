extends SceneTree

# Rebuilds generated/crowd_person.res (every stage's 3D spectator, CrowdPlacer's and Nyota Stadium's) from
# CrowdKit.gd, keeping the material the file already has, so a change to the figure needs no level regenerated:
#   Godot --headless --path . -s res://scratch/rebuild_crowd_person.gd
# regenerate_nyota_stadium.gd writes the same file (with a fresh material) whenever it runs.
const CrowdKit = preload("res://CrowdKit.gd")
const PATH := "res://generated/crowd_person.res"


func _init() -> void:
	var old: Mesh = load(PATH)
	var mat: Material = old.surface_get_material(0) if old else null
	var mesh: ArrayMesh = CrowdKit.new().build()
	if mat:
		mesh.surface_set_material(0, mat)
	else:
		push_error("no material on the old crowd_person.res: run regenerate_nyota_stadium instead")
	mesh.take_over_path(PATH)
	var err := ResourceSaver.save(mesh, PATH)
	var tris := (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	print("crowd_person.res: %d triangles (was %d), saved: %s" % [tris, (old.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if old else 0, error_string(err)])
	quit()
