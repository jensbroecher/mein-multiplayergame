extends SceneTree
## Does CampKit's "lamp" material (StandardMaterial3D, emission MULTIPLY, no emission texture) glow? Renders a box in
## it next to one in the marina_led shader in a dark scene and prints their brightness. Windowed:
##   Godot --path . --resolution 640x360 -s res://scratch/lamp_material_probe.gd
const CampKit = preload("res://CampKit.gd")

func _init() -> void:
	var root3 := Node3D.new()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.BLACK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.05, 0.05, 0.05)
	env.environment = e
	root3.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 6)
	root3.add_child(cam)
	var mats := [CampKit.make_material("lamp")]
	var sm := ShaderMaterial.new()
	sm.shader = load("res://marina_led.gdshader")
	sm.set_shader_parameter("energy", 3.2)
	mats.append(sm)
	var xs := [-1.5, 1.5]
	for i in range(2):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_color(Color(1.0, 0.6, 0.3))
		var bm := BoxMesh.new()
		st.append_from(bm, 0, Transform3D.IDENTITY)
		var arrays := bm.get_mesh_arrays()
		var m := ArrayMesh.new()
		var cols := PackedColorArray()
		cols.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		cols.fill(Color(1.0, 0.6, 0.3))
		arrays[Mesh.ARRAY_COLOR] = cols
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(0, mats[i])
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position = Vector3(xs[i], 0, 0)
		root3.add_child(mi)
	root.add_child(root3)
	for k in range(40):
		await process_frame
	var img := root.get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	# The brightest pixel in each half of the frame.
	for i in range(2):
		var best := Color.BLACK
		for y in range(0, h, 2):
			for x in range(0 if i == 0 else w / 2, w / 2 if i == 0 else w, 2):
				var c := img.get_pixel(x, y)
				if c.get_luminance() > best.get_luminance():
					best = c
		print("%s: brightest %s" % ["CampKit lamp" if i == 0 else "marina_led", best])
	quit()
