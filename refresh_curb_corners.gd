# refresh_curb_corners.gd
# Writes corner weights into the already-generated curb meshes of every level that has curbs, so
# curb_stripes.gdshader paints the red/white kerb in corners only, without regenerating the levels.
#
# Only the saved generated/*Visual_Curbs.res meshes are rewritten (in place, same path and UID); the
# level scenes are not touched. Levels regenerated after TerrainGenerator._apply_curb_corner_weights
# existed already have the weights and do not need this.
#
# Run headless:  <godot> --headless --path . res://refresh_curb_corners.tscn
extends Node

const LEVELS := [
	"res://levels/Level.tscn",
	"res://levels/MountainLevel.tscn",
	"res://levels/BloombayDunesLevel.tscn",
	"res://levels/PinecrestRidgeLevel.tscn",
	"res://levels/FrostpeakCreekLevel.tscn",
]


func _ready() -> void:
	var failed := 0
	for path in LEVELS:
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("Cannot load %s" % path)
			failed += 1
			continue
		var level: Node = packed.instantiate()
		var tg: Node = level.get_node_or_null("TerrainGenerator")
		var curbs: MeshInstance3D = tg.get_node_or_null("Visual_Curbs") if tg else null
		if tg == null or curbs == null or not (curbs.mesh is ArrayMesh):
			print("  %s: no generated curbs, skipped" % path)
			level.free()
			continue
		# TerrainGenerator resolves its track from the exported track_path, which needs the tree.
		add_child(level)
		var mesh := curbs.mesh as ArrayMesh
		var curve: Curve3D = tg._get_world_curve()
		tg._apply_curb_corner_weights(mesh, curve)
		var err := ResourceSaver.save(mesh, mesh.resource_path)
		if err != OK:
			push_error("Saving %s failed: %d" % [mesh.resource_path, err])
			failed += 1
		else:
			var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			var striped := 0
			for c in colors:
				if c.r > 0.5:
					striped += 1
			print("  %s: %s, %.0f%% of the curb striped" % [path, mesh.resource_path,
				100.0 * float(striped) / maxf(float(colors.size()), 1.0)])
		remove_child(level)
		level.free()
	get_tree().quit(1 if failed > 0 else 0)
