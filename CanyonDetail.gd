# CanyonDetail.gd
#
# Scales the Canyon Course's dressing (regenerate_canyon.gd's CanyonDressing) to the machine,
# following the Detail Level setting (MusicManager.grass_quality_index: 0 Off .. 4 Ultra; in Auto it
# moves with the frame time), the way DuneDetail.gd does for Bloombay Dunes. The level is built at
# its richest; this hides what a level of detail doesn't draw:
#   - the small plants (Plants_*): a share of each cell, and how far they are drawn
#   - the saguaros and joshua trees (Tall_*) and the rocks (Rocks_*): the same, less steeply
# Each cell is two MultiMeshes with the same instances, the near model (PlantsNear_*, ...) out to a
# fixed distance and the far one (Plants_*, ...) from there on; both thin alike, only the far one's
# range scales. Ultra draws further than the generator's ranges. The landmarks always stand.
# Instances in every MultiMesh are stored in random order (the generator shuffles each cell), so
# drawing the first N of them thins a cell evenly. Nothing here is synced or saved.
extends Node3D

## Per level of detail, Off/Low/Medium/High/Ultra.
const PLANT_SHARE := [0.0, 0.3, 0.55, 0.85, 1.0]
const PLANT_RANGE := [0.5, 0.6, 0.75, 1.0, 1.3]
const TALL_SHARE := [0.4, 0.6, 0.8, 1.0, 1.0]
const TALL_RANGE := [0.5, 0.65, 0.8, 1.0, 1.3]
const ROCK_SHARE := [0.35, 0.55, 0.8, 1.0, 1.0]
const ROCK_RANGE := [0.5, 0.65, 0.8, 1.0, 1.3]

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
	for node in get_children():
		var mmi := node as MultiMeshInstance3D
		if mmi == null:
			continue
		var n := str(mmi.name)
		if n.begins_with("Plants"):
			_scale(mmi, PLANT_SHARE[q], PLANT_RANGE[q])
		elif n.begins_with("Tall"):
			_scale(mmi, TALL_SHARE[q], TALL_RANGE[q])
		elif n.begins_with("Rocks"):
			_scale(mmi, ROCK_SHARE[q], ROCK_RANGE[q])


## Thins a MultiMesh to `share` of its instances and scales its draw distance by `range_scale` of the
## generator's.
func _scale(mmi: MultiMeshInstance3D, share: float, range_scale: float) -> void:
	if mmi.multimesh == null:
		return
	if share <= 0.0:
		mmi.visible = false
		return
	mmi.visible = true
	var total: int = mmi.multimesh.instance_count
	var count: int = int(round(float(total) * share))
	mmi.multimesh.visible_instance_count = -1 if count >= total else maxi(1, count)
	if mmi.has_meta(&"base_range"):
		mmi.visibility_range_end = float(mmi.get_meta(&"base_range")) * range_scale
