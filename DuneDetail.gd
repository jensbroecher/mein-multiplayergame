# DuneDetail.gd
#
# Scales Bloombay Dunes' inland dressing to the machine, following the Detail Level setting
# (MusicManager.grass_quality_index: 0 Off .. 4 Ultra; in Auto it moves with the frame time), the way
# JungleDetail.gd does for Msitu Falls. The level keeps the dunes at their richest; this hides what a
# level of detail doesn't draw:
#   - the dune grass (Grass_*): a share of each cell's tufts, and how far they are drawn
#   - the pebbles and rocks (Rocks_*): the same
#   - the bent palms (the Palms/PalmsFar cells of the bent shapes): a share of each cell
# Instances in every MultiMesh are stored in random order (the generator shuffles each cell), so
# drawing the first N of them thins a cell evenly. The tyre walls, barriers and flags are few and stay.
# Nothing here is synced or saved: every peer picks its own detail.
extends Node3D

## Per level of detail, Off/Low/Medium/High/Ultra.
const GRASS_SHARE := [0.0, 0.25, 0.5, 0.8, 1.0]
const GRASS_RANGE := [0.5, 0.55, 0.7, 0.85, 1.0]
const ROCK_SHARE := [0.3, 0.5, 0.75, 1.0, 1.0]
const ROCK_RANGE := [0.5, 0.6, 0.75, 0.9, 1.0]
const BENT_PALM_SHARE := [0.35, 0.5, 0.75, 1.0, 1.0]
## The index of the first bent palm shape (regenerate_bloombay_dunes.gd's BENT_FIRST).
const BENT_FIRST := 4

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
	for node in find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var n := str(mmi.name)
		if n.begins_with("Grass_"):
			_scale(mmi, GRASS_SHARE[q], GRASS_RANGE[q])
		elif n.begins_with("Rocks_"):
			_scale(mmi, ROCK_SHARE[q], ROCK_RANGE[q])
	var palms := get_parent().get_node_or_null("Palms") if get_parent() else null
	if palms:
		for child in palms.get_children():
			var pm := child as MultiMeshInstance3D
			if pm != null and int(str(pm.name).get_slice("_", str(pm.name).get_slice_count("_") - 1)) >= BENT_FIRST:
				_show_share(pm, BENT_PALM_SHARE[q])


## Thins a MultiMesh to `share` of its instances and pulls its draw distance in to `range_scale` of
## the generator's.
func _scale(mmi: MultiMeshInstance3D, share: float, range_scale: float) -> void:
	_show_share(mmi, share)
	mmi.visibility_range_end = float(mmi.get_meta(&"base_range", mmi.visibility_range_end)) * range_scale


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
