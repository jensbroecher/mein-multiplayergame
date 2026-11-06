# regenerate_airliners.gd
# Builds AirlinerKit's airframes and saves each as generated/airliners/airliner_<frame>.tscn (Body, its gear legs at
# their hinges with the meta "fold_axis" and "fold_angle", Lights), its meshes beside it as .res. Airliners.gd puts
# the livery on (material_override) and flies them. Run it after changing AirlinerKit.gd:
#   Godot --headless --path . res://regenerate_airliners.tscn
extends Node

const AirlinerKit := preload("res://AirlinerKit.gd")
const DIR := "res://generated/airliners/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var failed := false
	for frame in AirlinerKit.FRAMES.keys():
		if not _save_frame(frame):
			failed = true
	get_tree().quit(1 if failed else 0)


func _save_frame(frame: String) -> bool:
	var root := Node3D.new()
	root.name = "Airliner_%s" % frame
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _save(AirlinerKit.airframe(frame), "airliner_%s_body" % frame)
	root.add_child(body)
	body.owner = root
	var tris := _tris(body.mesh)
	for g in AirlinerKit.gear(frame):
		var mi := MeshInstance3D.new()
		mi.name = g[0]
		mi.mesh = _save(g[1], "airliner_%s_%s" % [frame, String(g[0]).to_lower()])
		mi.position = g[2]
		mi.set_meta("fold_axis", g[3])
		mi.set_meta("fold_angle", g[4])
		root.add_child(mi)
		mi.owner = root
		tris += _tris(mi.mesh)
	var lights := MeshInstance3D.new()
	lights.name = "Lights"
	lights.mesh = _save(AirlinerKit.lights_mesh(frame), "airliner_%s_lights" % frame)
	lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lights.extra_cull_margin = 80.0
	root.add_child(lights)
	lights.owner = root
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, DIR + "airliner_%s.tscn" % frame)
	print("Airliner %s: %d triangles (with its gear) -> %sairliner_%s.tscn: %d" % [frame, tris, DIR, frame, err])
	root.free()
	return err == OK


func _save(mesh: Mesh, nm: String) -> Mesh:
	var path: String = DIR + nm + ".res"
	var err := ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Saving %s failed: %d" % [path, err])
		return mesh
	mesh.take_over_path(path)
	return mesh


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var il: int = mesh.surface_get_array_index_len(s)
		n += (mesh.surface_get_array_len(s) if il == 0 else il) / 3
	return n
