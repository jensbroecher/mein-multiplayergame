extends Node

# Renders high-quality PNGs of all cars on a clean studio gray background from a 3/4 beauty angle.
# Usage:
#   Godot --path . res://scratch/render_all_cars.tscn [-- out_dir=<path>] [-- car=<name>]

const CarSelectionScript = preload("res://CarSelection.gd")
const CarPaint = preload("res://CarPaint.gd")

const BG_COLOR := Color(0.38, 0.39, 0.42)
const CAMERA_FOV := 25.0
const CAMERA_DIST := 6.5
const CAMERA_PITCH := 12.0
const LOOK_AT := Vector3(0.0, 0.38, 0.0)
const CAR_SCALE := 2.0
const START_YAW := PI + 0.60
const FRONT_WHEEL_STEER_DEG := -12.0

var _out_dir := "scratch/car_renders"
var _filter_car := ""

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)

	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("out_dir="):
			_out_dir = a.substr(8)
		elif a.begins_with("car="):
			_filter_car = a.substr(4)

	if not DirAccess.dir_exists_absolute("res://" + _out_dir):
		DirAccess.make_dir_recursive_absolute("res://" + _out_dir)

	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1920, 1080)

	var vp := get_viewport()
	vp.scaling_3d_scale = 1.0
	vp.msaa_3d = Viewport.MSAA_4X

	# 1. Environment & Tonemapping
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.50, 0.54)
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	world_env.environment = env
	add_child(world_env)

	# 2. Studio Lighting
	var key := DirectionalLight3D.new()
	key.light_energy = 1.7
	key.light_color = Color(1.0, 0.98, 0.95)
	key.shadow_enabled = true
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 2.0
	key.shadow_blur = 1.2
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 12.0
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.65
	fill.light_color = Color(0.85, 0.90, 1.0)
	fill.rotation_degrees = Vector3(-20.0, 55.0, 0.0)
	fill.shadow_enabled = false
	add_child(fill)

	var rim := DirectionalLight3D.new()
	rim.light_energy = 1.15
	rim.light_color = Color(0.88, 0.94, 1.0)
	rim.rotation_degrees = Vector3(-24.0, 155.0, 0.0)
	rim.shadow_enabled = false
	add_child(rim)

	# 3. Seamless Studio Cyclorama Cove
	var ground := MeshInstance3D.new()
	ground.mesh = _create_cyclorama_mesh()
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = BG_COLOR
	ground_mat.roughness = 0.88
	ground_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground.material_override = ground_mat
	add_child(ground)

	# 4. Contact shadow blob
	var blob := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	blob.mesh = quad
	blob.position.y = 0.003
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.65))
	grad.set_color(1, Color(0, 0, 0, 0.0))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(1.0, 0.5)
	var blob_mat := StandardMaterial3D.new()
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.albedo_texture = grad_tex
	blob_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	blob_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blob.material_override = blob_mat
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# 5. Turntable / Car Root
	var pivot := Node3D.new()
	pivot.rotation.y = START_YAW
	add_child(pivot)
	pivot.add_child(blob)

	# 6. SubViewport for exact 1920x1080 render
	var sub_vp := SubViewport.new()
	sub_vp.size = Vector2i(1920, 1080)
	sub_vp.msaa_3d = Viewport.MSAA_4X
	sub_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	sub_vp.scaling_3d_scale = 1.0
	sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sub_vp)

	var cam := Camera3D.new()
	cam.fov = CAMERA_FOV
	cam.near = 0.1
	cam.far = 100.0
	sub_vp.add_child(cam)
	var pitch := deg_to_rad(CAMERA_PITCH)
	var cam_pos := LOOK_AT + Vector3(0.0, sin(pitch), cos(pitch)) * CAMERA_DIST
	cam.look_at_from_position(cam_pos, LOOK_AT, Vector3.UP)
	cam.make_current()

	for i in 10:
		await get_tree().process_frame

	# Iterate over all presets
	var rendered_count := 0
	for preset in CarSelectionScript.CAR_PRESETS:
		var car_name: String = preset["name"]
		if _filter_car != "" and car_name.to_lower() != _filter_car.to_lower():
			continue

		var model_path: String = preset["model_path"]
		if not ResourceLoader.exists(model_path):
			push_warning("Missing model path: %s" % model_path)
			continue

		var scene := load(model_path) as PackedScene
		if scene == null:
			continue

		var car: Node3D = scene.instantiate()
		pivot.add_child(car)

		# Scale and rotate
		var rot: float = preset.get("model_y_rotation", PI)
		car.transform = Transform3D(Basis(Vector3.UP, rot) * CAR_SCALE, Vector3.ZERO)

		# Apply factory paint
		var factory_paint: Dictionary = CarPaint.factory(car_name)
		if CarPaint.is_paintable(car):
			CarPaint.apply(car, factory_paint)

		# Steer front wheels slightly into the camera
		_steer_front_wheels(car, preset, deg_to_rad(FRONT_WHEEL_STEER_DEG))

		# Centre model so it stands on the floor
		var box: AABB = _bounds(car, pivot)
		if box.size != Vector3.ZERO:
			var centre: Vector3 = box.get_center()
			car.position -= Vector3(centre.x, box.position.y, centre.z)
			blob.scale = Vector3(box.size.x * 1.18, 1.0, box.size.z * 1.12)

		# Add antenna if factory paint includes it
		var antenna := _add_antenna(car, factory_paint)

		# Wait frames for rendering & shadows to settle
		for i in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw

		# Save screenshot
		var img: Image = sub_vp.get_texture().get_image()
		var file_name: String = car_name.to_lower().replace(" ", "_") + ".png"
		var save_path := "%s/%s" % [_out_dir, file_name]
		img.save_png(save_path)
		print("Rendered %s -> %s" % [car_name, save_path])
		rendered_count += 1

		# Clean up car node
		if antenna != null:
			antenna.queue_free()
		car.queue_free()
		for i in 3:
			await get_tree().process_frame

	print("Finished rendering %d cars." % rendered_count)
	get_tree().quit()


func _steer_front_wheels(car: Node3D, preset: Dictionary, steer_angle: float) -> void:
	var wp: Dictionary = preset.get("wheel_parts", {})
	var fl_name: String = wp.get("FL", "Wheel_FL")
	var fr_name: String = wp.get("FR", "Wheel_FR")
	for name in [fl_name, fr_name]:
		var wheel := car.find_child(name, true, false) as Node3D
		if wheel != null:
			wheel.rotation.y = steer_angle


func _add_antenna(car: Node3D, paint: Dictionary) -> Node3D:
	if not CarPaint.has_antenna(paint):
		return null
	var placement: Node3D = car.find_child("AntennaPlacement", true, false)
	if placement == null:
		return null
	var ant := Node3D.new()
	var rod := MeshInstance3D.new()
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.005
	rod_mesh.bottom_radius = 0.012
	rod_mesh.height = 0.8
	rod.mesh = rod_mesh
	rod.position.y = 0.4
	ant.add_child(rod)
	var tip := MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.04
	tip_mesh.height = 0.08
	tip.mesh = tip_mesh
	tip.position.y = 0.8
	var tip_mat := StandardMaterial3D.new()
	var accent: Color = paint.get("accent", Color(1, 0.2, 0))
	tip_mat.albedo_color = accent
	tip_mat.emission_enabled = true
	tip_mat.emission = accent
	tip.material_override = tip_mat
	ant.add_child(tip)
	var inv: Vector3 = car.global_transform.basis.get_scale()
	if inv.x != 0.0:
		ant.scale = Vector3.ONE / inv.x
	placement.add_child(ant)
	return ant


static func _bounds(node: Node, space: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var to_space: Transform3D = space.global_transform.affine_inverse()
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).visible:
			var mi := n as MeshInstance3D
			var b: AABB = to_space * mi.global_transform * mi.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		stack.append_array(n.get_children())
	return box


static func _create_cyclorama_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Studio cyclorama profile points (z, y)
	# Camera is at +Z facing -Z.
	var profile: Array[Vector2] = []

	# 1. Front floor (flat under and in front of car)
	profile.append(Vector2(20.0, 0.0))
	profile.append(Vector2(-1.8, 0.0))

	# 2. Smooth curve bevel transitioning up
	var curve_steps := 24
	var radius := 5.0
	var curve_start_z := -1.8
	for s in range(1, curve_steps + 1):
		var frac := float(s) / float(curve_steps)
		var angle := frac * (PI * 0.5)
		var z := curve_start_z - radius * sin(angle)
		var y := radius * (1.0 - cos(angle))
		profile.append(Vector2(z, y))

	# 3. Vertical back wall extending high enough to cover frustum
	profile.append(Vector2(curve_start_z - radius, 18.0))

	# Width subdivisions across X from -35 to +35
	var x_steps := 12
	var min_x := -35.0
	var max_x := 35.0

	# Generate triangle grid
	for p_idx in range(profile.size() - 1):
		var p0: Vector2 = profile[p_idx]
		var p1: Vector2 = profile[p_idx + 1]

		for xi in range(x_steps):
			var x0: float = lerp(min_x, max_x, float(xi) / float(x_steps))
			var x1: float = lerp(min_x, max_x, float(xi + 1) / float(x_steps))

			var v00 := Vector3(x0, p0.y, p0.x)
			var v10 := Vector3(x1, p0.y, p0.x)
			var v01 := Vector3(x0, p1.y, p1.x)
			var v11 := Vector3(x1, p1.y, p1.x)

			# Tri 1: v00, v01, v10
			st.add_vertex(v00)
			st.add_vertex(v01)
			st.add_vertex(v10)

			# Tri 2: v10, v01, v11
			st.add_vertex(v10)
			st.add_vertex(v01)
			st.add_vertex(v11)

	st.generate_normals()
	return st.commit()
