extends Node3D
## Compiles, while the stage loads, the shaders of effects that first appear mid-race: missiles,
## bombs, water splashes (and WaterFx's big splash and bubbles) and the lightning's arc and sparks.
## A shader compiles when the first thing using it enters the scene, so each of these froze the race
## for 30-140ms the first time it went off (res://scratch/hitch_probe.tscn measures it). Level adds
## one. It holds hidden stand-ins, the effects' own meshes, particles and materials without their
## scripts or bodies, for the level's lifetime, so the shaders stay compiled. Hidden instances never
## draw but still compile.
##
## The cart's own fades and flashes are warmed by each PlayerCart (_add_fx_twins).

const PlayerCartScript = preload("res://PlayerCart.gd")
const WaterFx = preload("res://WaterFx.gd")
const SCENES := [
	preload("res://Missile.tscn"),
	preload("res://Bomb.tscn"),
	preload("res://WaterSplash.tscn"),
]


func _ready() -> void:
	name = "FxWarmup"
	visible = false
	for scene in SCENES:
		var inst: Node = scene.instantiate()
		_copy_visuals(inst)
		inst.free()

	# The lightning's arc is an ImmediateMesh of triangles, and its sparks a CPUParticles3D of quads.
	var arc := ImmediateMesh.new()
	arc.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	arc.surface_add_vertex(Vector3.ZERO)
	arc.surface_add_vertex(Vector3.RIGHT)
	arc.surface_add_vertex(Vector3.UP)
	arc.surface_end()
	var arc_mi := MeshInstance3D.new()
	arc_mi.mesh = arc
	arc_mi.material_override = PlayerCartScript.lightning_arc_material()
	add_child(arc_mi)
	var sparks := CPUParticles3D.new()
	sparks.emitting = false
	sparks.mesh = PlayerCartScript.lightning_spark_mesh()
	sparks.material_override = PlayerCartScript.lightning_spark_material()
	add_child(sparks)

	# Deep water: the big splash (column, spray, mist, foam) and the sinking cart's bubbles.
	for n in WaterFx.warmup_nodes():
		add_child(n)


## Copies the meshes and particle systems under `node` (nothing else: no scripts, bodies or sounds).
func _copy_visuals(node: Node) -> void:
	if node is MeshInstance3D:
		var src := node as MeshInstance3D
		var mi := MeshInstance3D.new()
		mi.mesh = src.mesh
		mi.material_override = src.material_override
		for i in src.get_surface_override_material_count():
			mi.set_surface_override_material(i, src.get_surface_override_material(i))
		add_child(mi)
	elif node is GPUParticles3D or node is CPUParticles3D:
		var copy: Node3D = node.duplicate(0)
		for child in copy.get_children():
			child.free()
		copy.set("emitting", false)
		add_child(copy)
	for child in node.get_children():
		_copy_visuals(child)
