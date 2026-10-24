# MeadowDetail.gd
#
# Scales the Lakeside Course's meadow grass (MeadowGrass.gd, meadow_grass.gdshader) to the machine,
# following the Detail Level setting (MusicManager.grass_quality_index: 0 Off .. 4 Ultra; in Auto it moves
# with the frame time) like DuneDetail.gd. Every cell of a tier draws the tier's one MultiMesh, whose
# tufts are stored in random order, so drawing the first N of them thins the whole meadow evenly; the
# draw distance shrinks with the tier materials' range_scale and the cells' visibility ranges.
# It also hands Level.gd the materials that bend round the carts (group "grass_push").
# Nothing here is synced or saved: every peer picks its own detail.
extends Node3D

## Per level of detail, Off/Low/Medium/High/Ultra.
const SHARE := [0.0, 0.4, 0.62, 0.82, 1.0]
const RANGE := [0.5, 0.6, 0.75, 0.88, 1.0]

## The tiers' materials and MultiMeshes, set by the generator.
@export var materials: Array[ShaderMaterial] = []
@export var multimeshes: Array[MultiMesh] = []

var quality := -1


func _ready() -> void:
	# The level generator runs this too: it must not bake a level of detail into the level.
	if Engine.is_editor_hint() or _in_generator():
		return
	add_to_group(&"vegetation_detail")
	add_to_group(&"grass_push")
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
	visible = q > 0
	for mm in multimeshes:
		var total := mm.instance_count
		var count := int(round(float(total) * SHARE[q]))
		mm.visible_instance_count = -1 if count >= total else maxi(1, count)
	for m in materials:
		m.set_shader_parameter("range_scale", RANGE[q])
	# A cell is drawn while any of its tufts can be: its tier's fade distance plus half its diagonal.
	for node in get_children():
		var mmi := node as MultiMeshInstance3D
		if mmi and mmi.has_meta(&"fade_end"):
			mmi.visibility_range_end = float(mmi.get_meta(&"fade_end")) * RANGE[q] + float(mmi.get_meta(&"reach"))


## The materials whose grass Level.gd bends round the carts.
func push_materials() -> Array[ShaderMaterial]:
	return materials
