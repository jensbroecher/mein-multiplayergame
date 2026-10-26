# regenerate_logo.gd
#
# Builds the 3D RC VIBE GP logo (LogoBuilder.gd, from the shapes scratch/logo_trace.gd traced out of
# images/logo_simple.jpeg) and saves it as generated/logo/RcVibeLogo.tscn, with its meshes and material
# beside it. Run headless from the project root; the scene saves and quits by itself. The traced shapes and
# the two textures must be there and imported (run the trace, then `Godot --headless --path . --import`):
#   Godot --headless --path . res://regenerate_logo.tscn
extends Node

const LogoBuilder = preload("res://LogoBuilder.gd")
const SHADER = preload("res://logo_3d.gdshader")
const OUT_DIR := "res://generated/logo/"


func _save(res: Resource, path: String) -> Resource:
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s: %d" % [path, err])
	return load(path)


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_set_owner_recursive(c, owner_node)


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(OUT_DIR + "logo_shapes.json"))
	if not data is Dictionary:
		push_error("No traced shapes: run scratch/logo_trace.gd first")
		get_tree().quit(1)
		return
	var faces_tex := load(OUT_DIR + "logo_faces.png") as Texture2D
	var grad_tex := load(OUT_DIR + "logo_gradients.png") as Texture2D
	if faces_tex == null or grad_tex == null:
		push_error("The logo's textures aren't imported: run `Godot --headless --path . --import`")
		get_tree().quit(1)
		return

	var t0 := Time.get_ticks_msec()
	var builder := LogoBuilder.new()
	var built := builder.build(data)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("faces_tex", faces_tex)
	mat.set_shader_parameter("gradients_tex", grad_tex)
	mat.set_shader_parameter("y_range", builder.y_range / builder.size_px.y)
	mat.set_shader_parameter("aspect", builder.size_px.x / builder.size_px.y)
	mat = _save(mat, OUT_DIR + "logo_material.tres") as ShaderMaterial

	var triangles := 0
	var root := Node3D.new()
	root.name = "RcVibeLogo"
	for key in ["rim", "body"]:
		var mesh: ArrayMesh = built[key]
		mesh.surface_set_material(0, mat)
		triangles += (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var mi := MeshInstance3D.new()
		mi.name = key.capitalize()
		mi.mesh = _save(mesh, OUT_DIR + "logo_%s.res" % key) as ArrayMesh
		root.add_child(mi)
	var faces := Node3D.new()
	faces.name = "Faces"
	root.add_child(faces)
	for f in built["faces"]:
		var mesh: ArrayMesh = f["mesh"]
		mesh.surface_set_material(0, mat)
		triangles += (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var mi := MeshInstance3D.new()
		mi.name = "Face_" + f["name"]
		mi.mesh = _save(mesh, OUT_DIR + "logo_face_%s.res" % f["name"]) as ArrayMesh
		mi.position = f["pivot"]
		faces.add_child(mi)
	# The rim's box is the logo's: its size in metres, for the scenes that place it.
	var box: AABB = (root.get_node("Rim") as MeshInstance3D).mesh.get_aabb()
	root.set_meta("logo_size", Vector3(box.size.x, box.size.y, LogoBuilder.FACE_TOP * LogoBuilder.PX))
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT_DIR + "RcVibeLogo.tscn")
	if err != OK:
		push_error("Failed to save the logo scene: %d" % err)
		get_tree().quit(1)
		return
	print("logo: %d triangles, %.2f x %.2f m, saved in %.1fs" % [triangles, box.size.x, box.size.y, (Time.get_ticks_msec() - t0) / 1000.0])
	root.free()
	get_tree().quit(0)
