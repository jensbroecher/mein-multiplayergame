# regenerate_chasm_houses.gd
# Builds Canyon Chasm's CSG architectural props (LargeHouseCSG.gd, AdobeHouseCSG.gd, CasitaHouseCSG.gd,
# WindmillCSG.gd, ChasmBarrierCSG.gd) in CSG and bakes them to generated/*.res, which their scenes draw.
# Run headless:
#   Godot --headless --path . res://regenerate_chasm_houses.tscn
extends Node

const LargeHouseCSG := preload("res://LargeHouseCSG.gd")
const AdobeHouseCSG := preload("res://AdobeHouseCSG.gd")
const CasitaHouseCSG := preload("res://CasitaHouseCSG.gd")
const WindmillCSG := preload("res://WindmillCSG.gd")
const ChasmBarrierCSG := preload("res://ChasmBarrierCSG.gd")

const TARGETS := [
	["LargeHouse", LargeHouseCSG, "build", "res://generated/large_house.res"],
	["AdobeHouse", AdobeHouseCSG, "build", "res://generated/adobe_house.res"],
	["CasitaHouse", CasitaHouseCSG, "build", "res://generated/casita_house.res"],
	["WindmillTower", WindmillCSG, "build_tower", "res://generated/windmill_tower.res"],
	["WindmillRotor", WindmillCSG, "build_rotor", "res://generated/windmill_rotor.res"],
	["ChasmBarrier", ChasmBarrierCSG, "build", "res://generated/chasm_barrier.res"],
]

func _ready() -> void:
	var nodes: Array[CSGShape3D] = []
	for t in TARGETS:
		var csg: CSGShape3D = t[1].call(t[2])
		add_child(csg)
		nodes.append(csg)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in TARGETS.size():
		var label: String = TARGETS[i][0]
		var builder = TARGETS[i][1]
		var out_path: String = TARGETS[i][3]
		var mesh: ArrayMesh = builder.bake(nodes[i])
		if mesh == null or mesh.get_surface_count() == 0:
			push_error("%s bake produced an empty mesh" % label)
			get_tree().quit(1)
			return
		var err := ResourceSaver.save(mesh, out_path, ResourceSaver.FLAG_COMPRESS)
		if err != OK:
			push_error("Saving %s failed: %d" % [out_path, err])
			get_tree().quit(1)
			return
		var tris := 0
		for s in mesh.get_surface_count():
			tris += mesh.surface_get_array_len(s) / 3 if mesh.surface_get_array_index_len(s) == 0 else mesh.surface_get_array_index_len(s) / 3
		print("%s: %d surfaces, %d triangles, %s -> %s" % [label, mesh.get_surface_count(), tris, mesh.get_aabb(), out_path])
	get_tree().quit(0)
