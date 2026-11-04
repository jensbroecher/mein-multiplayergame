# HarborDetail.gd
#
# Scales Harbor Pier's port (regenerate_harbor_pier.gd's PortScenery) to the machine, following the Detail Level
# setting (MusicManager.grass_quality_index: 0 Off .. 4 Ultra; in Auto it moves with the frame time), the way
# DuneDetail.gd does for Bloombay Dunes. The level is built at its richest; High draws what the generator meant for
# it, Ultra draws everything and reaches further, the lower levels thin and shorten:
#   - the trees on the hills (Trees_*): a share of each cell's trees (High leaves out the Ultra-only fifth), and how far
#   - the breakwaters' tetrapods and boulders (Tetrapods_*, Boulders_*): the same
#   - every single prop with a draw distance (sheds, stacks, moored boats, the yard, the furniture): its distance
# Instances in every MultiMesh are stored in random order (the generator shuffles each cell), so drawing the first N of
# them thins a cell evenly. The town, the shores, the ship and the cranes stay: they are the harbour's skyline. Each
# node's own distance is kept in its meta `base_range` by the generator. Nothing here is synced or saved.
extends Node3D

## Per level of detail, Off/Low/Medium/High/Ultra.
const TREE_SHARE := [0.3, 0.45, 0.65, 0.8, 1.0]
const TREE_RANGE := [0.45, 0.6, 0.8, 1.0, 1.3]
const ARMOUR_SHARE := [0.45, 0.65, 0.85, 1.0, 1.0]
const ARMOUR_RANGE := [0.5, 0.65, 0.85, 1.0, 1.3]
const PROP_RANGE := [0.55, 0.7, 0.85, 1.0, 1.25]

var quality := -1


func _ready() -> void:
	# The level generator runs this too: it must not bake a level of detail into the level.
	if Engine.is_editor_hint() or _in_generator():
		return
	add_to_group(&"vegetation_detail")
	var q: int = 3
	if get_node_or_null("/root/MusicManager"):
		q = int(get_node("/root/MusicManager").grass_quality_index)
	apply_vegetation_quality(q)


func _in_generator() -> bool:
	for child in get_tree().root.get_children():
		if "regenerate" in str(child.name).to_lower():
			return true
	return false


func apply_vegetation_quality(q: int) -> void:
	q = clampi(q, 0, 4)
	if q == quality:
		return
	quality = q
	for node in find_children("*", "GeometryInstance3D", true, false):
		var gi := node as GeometryInstance3D
		var n := str(gi.name)
		if not gi.has_meta(&"base_range") and not n.begins_with("Tree_") and not n.begins_with("TreeShadow_"):
			continue
		var base: float = float(gi.get_meta(&"base_range", gi.visibility_range_end))
		if gi is MultiMeshInstance3D and (n.begins_with("Tree_") or n.begins_with("TreeShadow_")):
			# The detailed trees near the camera: JungleDetail moves their distance; the share matches the far cells'.
			_show_share(gi as MultiMeshInstance3D, TREE_SHARE[q])
			continue
		if gi is MultiMeshInstance3D and n.begins_with("Trees_"):
			_show_share(gi as MultiMeshInstance3D, TREE_SHARE[q])
			gi.visibility_range_end = base * TREE_RANGE[q]
		elif gi is MultiMeshInstance3D and (n.begins_with("Tetrapods_") or n.begins_with("Boulders_")):
			_show_share(gi as MultiMeshInstance3D, ARMOUR_SHARE[q])
			gi.visibility_range_end = base * ARMOUR_RANGE[q]
		else:
			gi.visibility_range_end = base * PROP_RANGE[q]
		gi.visibility_range_end_margin = gi.visibility_range_end * 0.1


func _show_share(mmi: MultiMeshInstance3D, share: float) -> void:
	if mmi.multimesh == null:
		return
	if share <= 0.0:
		mmi.visible = false
		return
	mmi.visible = true
	var total: int = mmi.multimesh.instance_count
	var count: int = int(round(float(total) * share))
	mmi.multimesh.visible_instance_count = -1 if count >= total else maxi(1, count)
