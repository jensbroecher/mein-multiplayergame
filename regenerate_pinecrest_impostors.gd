extends SceneTree

# Bakes the impostor atlas of Pinecrest Ridge's far forest (regenerate_pinecrest_ridge.gd,
# _build_far_forest): its own pine, fir and larch (WoodlandBuilder.gd, the detailed meshes, both
# shapes of each) photographed from the side by an orthographic camera, from IMPOSTOR_VIEWS bearings
# each, into two textures:
#   generated/pinecrest_impostor_albedo.res - RGB the tree's colour unlit (its own shaders made
#       unshaded), A its outline; mipmaps keep the outline's coverage (WoodlandBuilder._coverage_mipmaps),
#       so a forest 3km off doesn't thin out to nothing. Meta "frames": per tree [frame height, foot]
#       in metres (a cell is half as wide as it is tall; foot is how far the frame starts under the
#       tree's foot).
#   generated/pinecrest_impostor_normal.res - the crowns' own normals in the camera's frame (x right,
#       y up, z toward the camera) as 0..1, so tree_impostor.gdshader lights each sprite as the tree is.
# Rendering needs a window, so this is its own step (the generator runs headless). Run it after a change
# to the trees, then regenerate Pinecrest Ridge:
#   Godot --path . --resolution 800x800 -s res://regenerate_pinecrest_impostors.gd
const Woodland = preload("res://WoodlandBuilder.gd")

const KINDS := ["pine", "fir", "larch"]
const VIEWS := 5
const COLS := 8
const CELL := Vector2i(128, 256)
const ATLAS := 1024
## Each cell is rendered this many times larger and boxed down, for soft edges.
const SUPER := 2
const ALBEDO_PATH := "res://generated/pinecrest_impostor_albedo.res"
const NORMAL_PATH := "res://generated/pinecrest_impostor_normal.res"

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	_vp = SubViewport.new()
	_vp.size = CELL * SUPER
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 0.1
	_cam.far = 200.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)

	var w = Woodland.new()
	w.save_res = func(res: Resource, _n: String) -> Resource: return res
	var meshes: Array = []
	for kind in KINDS:
		var bark: ShaderMaterial = w.bark_material(kind, 0)
		var leaf: ShaderMaterial = w.leaf_material(0, 0.0, 18.0)
		for v in range(2):
			match kind:
				"pine":
					meshes.append(w.pine_mesh(v, 0, bark, leaf))
				"fir":
					meshes.append(w.fir_mesh(v, 0, bark, leaf))
				"larch":
					meshes.append(w.larch_mesh(v, 0, bark, leaf))
	# Two passes over the same meshes: the colour unlit, then the normals as colour.
	var albedo := Woodland.LeafCanvas.new(ATLAS, Color(0.10, 0.16, 0.08))
	var normal := Image.create(ATLAS, ATLAS, false, Image.FORMAT_RGB8)
	normal.fill(Color(0.5, 0.5, 1.0))
	var frames := PackedFloat32Array()
	for ti in range(meshes.size()):
		var mesh: ArrayMesh = meshes[ti]
		var reach := 0.0
		var top := 0.0
		for si in range(mesh.get_surface_count()):
			for q in mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				reach = maxf(reach, Vector2(q.x, q.z).length())
				top = maxf(top, q.y)
		var foot := 0.6
		var height := maxf(top + foot + 0.4, reach * 4.0 + 0.6)
		frames.append(height)
		frames.append(foot)
		for pass_i in range(2):
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			for si in range(mesh.get_surface_count()):
				mi.set_surface_override_material(si, _pass_material(mesh.surface_get_material(si), pass_i == 1))
			_holder.add_child(mi)
			for view in range(VIEWS):
				_holder.rotation.y = TAU * view / VIEWS
				_cam.size = height
				_cam.position = Vector3(0.0, height * 0.5 - foot, 60.0)
				for f in range(45 if view == 0 else 4):
					await process_frame
				var img := _vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				var cell := ti * VIEWS + view
				var at := Vector2i((cell % COLS) * CELL.x, (cell / COLS) * CELL.y)
				_put_cell(img, at, albedo if pass_i == 0 else null, normal if pass_i == 1 else null)
			mi.queue_free()
			await process_frame
	_dilate(albedo)
	var a_img: Image = Woodland._coverage_mipmaps(albedo, 0.5)
	var a_tex := _save(a_img, ALBEDO_PATH, frames)
	normal.generate_mipmaps()
	_save(normal, NORMAL_PATH, PackedFloat32Array())
	print("frames (height, foot): ", frames)
	print("baked %d trees x %d views in %.1fs -> %s" % [meshes.size(), VIEWS, (Time.get_ticks_msec() - t0) / 1000.0, a_tex.resource_path])
	quit()


## The tree's own shader, unshaded: its colour as it is, or (normals) the crown's normal written as the
## colour, pre-linearised so the sRGB output reads back the 0..1 value itself.
func _pass_material(src: Material, normals: bool) -> ShaderMaterial:
	var sm := src as ShaderMaterial
	var code: String = sm.shader.code.replace("render_mode ", "render_mode unshaded, ")
	if normals:
		var end := code.rfind("}")
		code = code.substr(0, end) + \
				"\tvec3 nv = normalize(NORMAL) * 0.5 + 0.5;\n" + \
				"\tALBEDO = mix(nv / 12.92, pow((nv + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), nv));\n}\n"
	var sh := Shader.new()
	sh.code = code
	var m := sm.duplicate() as ShaderMaterial
	m.shader = sh
	return m


## Boxes a SUPER-sized render down into its cell: colour weighted by coverage into the canvas, or the
## normals into their image.
func _put_cell(img: Image, at: Vector2i, cv, normal: Image) -> void:
	for y in range(CELL.y):
		for x in range(CELL.x):
			var a := 0.0
			var c := Color(0, 0, 0)
			for dy in range(SUPER):
				for dx in range(SUPER):
					var p := img.get_pixel(x * SUPER + dx, y * SUPER + dy)
					var k := 1.0 if p.a > 0.5 else 0.0
					a += k
					c += Color(p.r, p.g, p.b) * k
			a /= float(SUPER * SUPER)
			if a <= 0.0:
				continue
			c /= a * float(SUPER * SUPER)
			if cv:
				var i: int = (at.y + y) * ATLAS + at.x + x
				cv.rgb[i * 3] = c.r
				cv.rgb[i * 3 + 1] = c.g
				cv.rgb[i * 3 + 2] = c.b
				cv.alpha[i] = a
			else:
				normal.set_pixel(at.x + x, at.y + y, c)


## Spreads the colour a few texels out past each outline, so filtering at the edge doesn't pull in the
## background's.
func _dilate(cv) -> void:
	for it in range(4):
		var rgb: PackedFloat32Array = cv.rgb.duplicate()
		var known := PackedByteArray()
		known.resize(ATLAS * ATLAS)
		for i in range(ATLAS * ATLAS):
			known[i] = 1 if cv.alpha[i] > 0.0 or cv.rgb[i * 3 + 2] < 0.0 else 0
		for y in range(1, ATLAS - 1):
			for x in range(1, ATLAS - 1):
				var i := y * ATLAS + x
				if known[i]:
					continue
				var s := Vector3.ZERO
				var n := 0
				for j in [i - 1, i + 1, i - ATLAS, i + ATLAS]:
					if known[j]:
						s += Vector3(cv.rgb[j * 3], cv.rgb[j * 3 + 1], absf(cv.rgb[j * 3 + 2]))
						n += 1
				if n > 0:
					s /= n
					rgb[i * 3] = s.x
					rgb[i * 3 + 1] = s.y
					# Marked as filled (negative blue), so the next pass spreads from it.
					rgb[i * 3 + 2] = -maxf(s.z, 0.0001)
		cv.rgb = rgb
	for i in range(ATLAS * ATLAS):
		cv.rgb[i * 3 + 2] = absf(cv.rgb[i * 3 + 2])


func _save(img: Image, path: String, frames: PackedFloat32Array) -> Texture2D:
	var tex := PortableCompressedTexture2D.new()
	# Kept, or a headless save writes the texture empty (CLAUDE.md, procedural cars).
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	if not frames.is_empty():
		tex.set_meta(&"frames", frames)
	tex.take_over_path(path)
	ResourceSaver.save(tex, path)
	return tex
