# regenerate_cars.gd
#
# Builds the procedural cars (CarBuilder.gd + one *Builder.gd per car) and saves each as
# generated/cars/<Name>.tscn, with its meshes, detail map and material beside it. PlayerCart and
# CarSelection load that scene like any other car model. Run headless from the project root (the
# scene saves and quits by itself):
#   Godot --headless --path . res://regenerate_cars.tscn
extends Node

const CB = preload("res://CarBuilder.gd")
const CAR_SHADER = preload("res://car_body.gdshader")
const OUT_DIR := "res://generated/cars/"
const DETAIL_SIZE := Vector2i(1024, 512)

## The procedural cars: scene name, file prefix and builder.
const CARS := [
	{"name": "Mudrunner", "prefix": "mudrunner", "builder": preload("res://MudrunnerBuilder.gd")},
	{"name": "Phantom", "prefix": "phantom", "builder": preload("res://PhantomBuilder.gd")},
	{"name": "Strikeforce", "prefix": "strikeforce", "builder": preload("res://StrikeforceBuilder.gd")},
	{"name": "Centurion", "prefix": "centurion", "builder": preload("res://CenturionBuilder.gd")},
]


## Builds one car in memory: {"body", "wheel_l", "wheel_r"} ArrayMeshes sharing "material",
## the "detail" map, and the "design" (builder instance) for its layout constants.
static func build_car(builder_script: Script) -> Dictionary:
	var design = builder_script.new()
	var detail: Image = design.build_detail_map(DETAIL_SIZE.x, DETAIL_SIZE.y)
	var tex := ImageTexture.create_from_image(detail)
	var mat := ShaderMaterial.new()
	mat.shader = CAR_SHADER
	mat.set_shader_parameter("detail_map", tex)
	var lay: Dictionary = design.PAINT_LAYOUT
	for key in ["nose_z", "tail_z", "belt_y", "side_x", "roundel_r", "hood_z", "hood_r", "stripe_w",
			"stripe_gap"]:
		mat.set_shader_parameter(key, lay[key])
	mat.set_shader_parameter("door_roundel", Vector2(lay["door_z"], lay["door_y"]))
	# Fading carts (PlayerCart: drowning, teleport) go transparent; draw them before the water.
	mat.render_priority = -1
	var body := CB.new()
	design.build_body(body)
	var wr := CB.new()
	design.build_wheel(wr, 1.0)
	var wl := CB.new()
	design.build_wheel(wl, -1.0)
	return {
		"body": body.commit(mat), "wheel_r": wr.commit(mat), "wheel_l": wl.commit(mat),
		"material": mat, "detail": tex, "detail_image": detail, "design": design,
		"triangles": body.triangle_count() + 2 * wr.triangle_count() + 2 * wl.triangle_count(),
	}


## The car's scene. PlayerCart scales the root x2 and turns it half round (the Hunyuan models
## faced backward at half size); "Model" undoes that, so everything under it is in the cart
## frame. Every mesh is tagged "car_shader" for CarPaint.apply and PlayerCart's flashes.
static func assemble(car_name: String, parts: Dictionary) -> Node3D:
	var design = parts["design"]
	var root := Node3D.new()
	root.name = car_name
	root.set_meta("procedural_car", true)
	var model := Node3D.new()
	model.name = "Model"
	model.transform = Transform3D(Basis(Vector3.UP, PI) * 0.5, Vector3.ZERO)
	root.add_child(model)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = parts["body"]
	body.set_meta("car_shader", true)
	model.add_child(body)
	for corner in ["FL", "FR", "RL", "RR"]:
		var w := MeshInstance3D.new()
		w.name = "Wheel_" + corner
		w.mesh = parts["wheel_l"] if corner.ends_with("L") else parts["wheel_r"]
		w.position = design.WHEEL_POSITIONS[corner]
		w.set_meta("car_shader", true)
		model.add_child(w)
	var ant := Node3D.new()
	ant.name = "AntennaPlacement"
	ant.position = design.ANTENNA_POS
	model.add_child(ant)
	return root


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
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for car in CARS:
		var t0 := Time.get_ticks_msec()
		var parts: Dictionary = build_car(car["builder"])
		var prefix: String = OUT_DIR + car["prefix"]
		# Save the pieces first, so the scene references them instead of embedding them. The detail
		# map is mostly empty: lossless WebP (mipmaps included) makes it ~30KB instead of ~3MB.
		var ptex := PortableCompressedTexture2D.new()
		ptex.keep_compressed_buffer = true
		ptex.create_from_image(parts["detail_image"], PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		var tex: Texture2D = _save(ptex, prefix + "_detail.res")
		var mat: ShaderMaterial = parts["material"]
		mat.set_shader_parameter("detail_map", tex)
		mat = _save(mat, prefix + "_material.tres")
		for key in ["body", "wheel_l", "wheel_r"]:
			var mesh: ArrayMesh = parts[key]
			mesh.surface_set_material(0, mat)
			parts[key] = _save(mesh, "%s_%s.res" % [prefix, key])
		var root: Node3D = assemble(car["name"], parts)
		_set_owner_recursive(root, root)
		var packed := PackedScene.new()
		var err := packed.pack(root)
		if err == OK:
			err = ResourceSaver.save(packed, OUT_DIR + car["name"] + ".tscn")
		if err != OK:
			push_error("Failed to save %s: %d" % [car["name"], err])
			get_tree().quit(1)
			return
		print("%s: %d triangles, saved in %.1fs" % [car["name"], parts["triangles"], (Time.get_ticks_msec() - t0) / 1000.0])
		root.free()
	get_tree().quit(0)
