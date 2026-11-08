# SnowWoodsDetail.gd
#
# Scales Frostpeak Creek's woods (regenerate_frostpeak_dressing.gd, SnowTreeKit.gd) to the machine, following the
# Detail Level setting (MusicManager.grass_quality_index: 0 Off .. 4 Ultra; in Auto it moves with the frame time).
# The level is saved as Ultra draws it: every tree, the rich spruce (Frostfall Gorge's full tree), the detailed trees
# casting their own shadows. Below Ultra this draws:
#   - a share of the trees (TREE_SHARE): every tree has a rank, and each cell (Tree_ near, TreeShadow_ its shadow
#     stand-ins, TreeFar_ the far stand-ins) keeps its trees in rank order with the ranks in its meta `ranks`, so
#     drawing the trees ranked under the share draws the same trees in every layer (thinning each cell by a count,
#     the near and far cells, which group trees differently, would keep different ones). Trees by the roads rank
#     low (the generator's RANK_NEAR_ROAD) and go last. Their colliders (TreeTrunks_*, meta `rank`) switch off with
#     them; DressingColliders does the same for its own.
#   - the light meshes (a cell's metas `rich_mesh` and `light_mesh`: about half the near spruce's triangles and a
#     quarter of its stand-in's)
#   - the detailed trees' crossfade to their stand-ins nearer (TREE_NEAR), and their shadows from the stand-ins
# Auto moves between Low and Ultra, so nothing here may change the light: Low keeps the stand-ins' shadows (as
# JungleDetail.gd does); only Off drops them and the ground's fine detail.
# Nothing here is synced or saved: every peer picks its own detail.
extends Node3D

## Per level of detail, Off/Low/Medium/High/Ultra.
const TREE_SHARE := [0.25, 0.36, 0.48, 0.6, 1.0]
const TREE_NEAR := [70.0, 85.0, 115.0, 135.0, 165.0]
const TREE_SHADOWS := [false, true, true, true, true]
const FINE_GROUND := [0.0, 1.0, 1.0, 1.0, 1.0]

## The LOD materials every tree shares (tree_lod.gdshaderinc): the crossfade band moves with TREE_NEAR.
@export var lod_materials: Array[ShaderMaterial] = []
@export var tree_fade := 40.0
@export var tree_fade_jitter := 12.0
@export var forest_cell := 80.0
## The ground's material (frostpeak_ground.gdshader): `fine_detail`.
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
	var share: float = TREE_SHARE[q]
	var rich: bool = q >= 4
	var near: float = TREE_NEAR[q]
	var near_end: float = near + tree_fade * 0.5 + tree_fade_jitter + forest_cell * 0.72
	for m in lod_materials:
		if m:
			m.set_shader_parameter(&"lod_fade_begin", near - tree_fade * 0.5)
			m.set_shader_parameter(&"lod_fade_end", near + tree_fade * 0.5)
	for child in get_parent().get_children():
		var mmi := child as MultiMeshInstance3D
		if mmi != null and mmi.multimesh != null and mmi.has_meta(&"ranks"):
			var shown := _show_ranked(mmi, share)
			if mmi.has_meta(&"rich_mesh"):
				var mesh: Mesh = mmi.get_meta(&"rich_mesh") if rich else mmi.get_meta(&"light_mesh")
				if mmi.multimesh.mesh != mesh:
					mmi.multimesh.mesh = mesh
			var n: String = str(mmi.name)
			if n.begins_with("Tree_"):
				mmi.visibility_range_end = near_end
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if rich else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif n.begins_with("TreeShadow_"):
				mmi.visibility_range_end = near_end
				mmi.visible = shown and not rich and TREE_SHADOWS[q]
			continue
		var body := child as StaticBody3D
		if body != null and str(body.name).begins_with("TreeTrunks_"):
			for cs in body.get_children():
				if cs is CollisionShape3D and cs.has_meta(&"rank"):
					(cs as CollisionShape3D).disabled = float(cs.get_meta(&"rank")) >= share
	if ground_material:
		ground_material.set_shader_parameter(&"fine_detail", FINE_GROUND[q])


## Draws the cell's trees ranked under `share` (its instances are in rank order). Returns whether any are drawn.
func _show_ranked(mmi: MultiMeshInstance3D, share: float) -> bool:
	var ranks: PackedFloat32Array = mmi.get_meta(&"ranks")
	var count: int = ranks.bsearch(share)
	mmi.visible = count > 0
	mmi.multimesh.visible_instance_count = -1 if count >= ranks.size() else count
	return count > 0
