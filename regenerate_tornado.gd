# regenerate_tornado.gd
# Builds Canyon Chasm's tornado (TornadoCSG.gd) and bakes it to generated/tornado.res, which
# Tornado.tscn draws. Run it after changing TornadoCSG.gd:
#   Godot --headless --path . res://regenerate_tornado.tscn
extends Node

const TornadoCSG := preload("res://TornadoCSG.gd")
const OUT := "res://generated/tornado.res"

func _ready() -> void:
	var csg := TornadoCSG.build()
	add_child(csg)
	await get_tree().process_frame
	await get_tree().process_frame
	var mesh := TornadoCSG.bake(csg)
	if mesh == null:
		get_tree().quit(1)
		return
	var err := ResourceSaver.save(mesh, OUT, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Saving %s failed: %d" % [OUT, err])
		get_tree().quit(1)
		return
	var tris := 0
	for s in mesh.get_surface_count():
		tris += mesh.surface_get_array_len(s) / 3 if mesh.surface_get_array_index_len(s) == 0 else mesh.surface_get_array_index_len(s) / 3
	print("Tornado: %d surfaces, %d triangles, %s -> %s" % [mesh.get_surface_count(), tris, mesh.get_aabb(), OUT])
	get_tree().quit(0)
