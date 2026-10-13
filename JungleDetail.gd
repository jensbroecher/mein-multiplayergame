# JungleDetail.gd
#
# Scales Msitu Falls' rainforest to the machine, following the Vegetation Detail setting
# (MusicManager.grass_quality_index: 0 Off .. 4 Ultra; in Auto it moves with the frame time). The
# level keeps the forest at its richest; this hides what a level of detail doesn't draw:
#   - the understory (Plants_*): a share of each cell's instances, and how far it is drawn
#   - the canopy: how far trees stay detailed before they swap to the stand-in (TREE_NEAR), and
#     whether the detailed trees cast their own leaf shadows (Ultra) or the cheap stand-in does it
#     for them (TreeShadow_*)
#   - the deep forest (TreeDeep*): trees far from the road, seen only as canopy from afar
#   - the ground cover (GroundCover_*): ferns and herbs carpeting the verges
#   - the rain's particle count (JungleRain.particle_scale)
#   - the ground's fine detail (wheel tracks, the soil's bump, the cut banks' triplanar earth)
#   - at Off and Low, the canopy's shadows altogether
# Instances in every MultiMesh are stored in random order, so drawing the first N of them thins a
# cell evenly. Nothing here is synced or saved: every peer picks its own detail.
extends Node3D

## Per level of detail, Off/Low/Medium/High/Ultra.
const UNDERSTORY := [0.4, 0.55, 0.8, 1.0, 1.0]
const RANGE_SCALE := [0.6, 0.75, 1.0, 1.15, 1.35]
const TREE_NEAR := [70.0, 85.0, 115.0, 135.0, 165.0]
const DEEP := [0.0, 0.0, 0.3, 0.7, 1.0]
const COVER := [0.0, 0.0, 0.0, 0.55, 1.0]
const RAIN := [0.4, 0.55, 0.8, 1.0, 1.0]
const LIANAS := [false, false, true, true, true]
const FINE_GROUND := [0.0, 0.3, 1.0, 1.0, 1.0]
const TREE_SHADOWS := [false, false, true, true, true]

## The LOD materials every tree shares (tree_lod.gdshaderinc): the crossfade band moves with
## TREE_NEAR.
@export var lod_materials: Array[ShaderMaterial] = []
@export var tree_fade := 40.0
@export var tree_fade_jitter := 12.0
@export var forest_cell := 80.0
@export var rain_path: NodePath
## The ground's material (jungle_ground.gdshader), shared by every terrain chunk.
@export var ground_material: ShaderMaterial

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
	var near: float = TREE_NEAR[q]
	var near_end: float = near + tree_fade * 0.5 + tree_fade_jitter + forest_cell * 0.72
	for m in lod_materials:
		if m:
			m.set_shader_parameter(&"lod_fade_begin", near - tree_fade * 0.5)
			m.set_shader_parameter(&"lod_fade_end", near + tree_fade * 0.5)
	for child in get_parent().get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi == null:
			continue
		var n: String = str(mmi.name)
		if n.begins_with("Plants_"):
			var liana: bool = mmi.get_meta(&"liana", false)
			_show_share(mmi, (1.0 if LIANAS[q] else 0.0) if liana else UNDERSTORY[q])
			mmi.visibility_range_end = float(mmi.get_meta(&"base_range", mmi.visibility_range_end)) * RANGE_SCALE[q]
		elif n.begins_with("TreeShadow_"):
			mmi.visible = q < 4 and TREE_SHADOWS[q]
			mmi.visibility_range_end = near_end
		elif n.begins_with("TreeDeepFar_"):
			_show_share(mmi, DEEP[q])
		elif n.begins_with("TreeDeep_"):
			_show_share(mmi, DEEP[q])
			mmi.visibility_range_end = near_end
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q >= 4 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n.begins_with("Tree_"):
			mmi.visibility_range_end = near_end
			# The understory trees (variant 2) cast none at any level.
			var casts: bool = q >= 4 and not n.ends_with("_2")
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif n.begins_with("GroundCover_"):
			_show_share(mmi, COVER[q])
			mmi.visibility_range_end = float(mmi.get_meta(&"base_range", mmi.visibility_range_end)) * RANGE_SCALE[q]
	var rain := get_node_or_null(rain_path)
	if rain and "particle_scale" in rain:
		rain.particle_scale = RAIN[q]
	if ground_material:
		ground_material.set_shader_parameter(&"fine_detail", FINE_GROUND[q])


## Draws the first `share` of the MultiMesh's instances (they are stored in random order).
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
