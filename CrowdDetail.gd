# CrowdDetail.gd
#
# Scales Nyota Stadium's crowd to the machine, following the Detail Level setting
# (MusicManager.grass_quality_index: 0 Off .. 4 Ultra; in Auto it moves with the frame time), the way
# DuneDetail.gd and JungleDetail.gd do for their levels. The level is built for the richest setting; this sets
# how far the 3D spectators (the "CrowdNear" cells) are drawn before the flat cards take over:
#   Off   no 3D figures, the cards at every distance
#   Low   about 24m   Medium  about 34m   High  44m (what the level was tuned at)   Ultra  about 57m
# The cards and the figures dither into each other between `lod_fade_begin` and `lod_fade_end`
# (tree_lod.gdshaderinc), which are set on every crowd material, and a figure cell is dropped from the draw
# list once it is out of reach (its visibility range). Nothing is synced or saved: every peer picks its own.
extends Node3D

const RANGE_SCALE := [0.0, 0.55, 0.78, 1.0, 1.3]
## The generator's values (CROWD_LOD_BEGIN / END / JITTER and the cell reach added to a cell's range).
@export var base_begin := 34.0
@export var base_end := 44.0
@export var jitter := 3.0
@export var cell_reach := 24.0

var quality := -1
var _materials: Array[ShaderMaterial] = []
var _cards: Array[ShaderMaterial] = []
var _near_cells: Array[MultiMeshInstance3D] = []
var _near_root: Node3D


func _ready() -> void:
	# The level generator runs this too: it must not bake a level of detail into the level.
	if Engine.is_editor_hint() or _in_generator():
		return
	_near_root = get_node_or_null("CrowdNear") as Node3D
	_collect()
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


func _collect() -> void:
	for node in find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		if mmi.multimesh == null or mmi.multimesh.mesh == null:
			continue
		var mesh: Mesh = mmi.multimesh.mesh
		var mat: ShaderMaterial = null
		if mesh is QuadMesh:
			mat = (mesh as QuadMesh).material as ShaderMaterial
			if mat != null and not _cards.has(mat):
				_cards.append(mat)
		else:
			mat = mesh.surface_get_material(0) as ShaderMaterial
			_near_cells.append(mmi)
		if mat != null and not _materials.has(mat):
			_materials.append(mat)


func apply_vegetation_quality(q: int) -> void:
	q = clampi(q, 0, 4)
	if q == quality:
		return
	quality = q
	var s: float = RANGE_SCALE[q]
	var near_on: bool = s > 0.0
	if _near_root != null:
		_near_root.visible = near_on
	# With no 3D figures the cards are drawn at every distance.
	for card in _cards:
		card.set_shader_parameter("lod_mode", 2 if near_on else 0)
	if not near_on:
		return
	for mat in _materials:
		mat.set_shader_parameter("lod_fade_begin", base_begin * s)
		mat.set_shader_parameter("lod_fade_end", base_end * s)
	for cell in _near_cells:
		cell.visibility_range_end = base_end * s + jitter + cell_reach
