@tool
extends Node3D
## The RC Vibe GP flag on its pole: a white pole on a concrete foot with a gilt ball on top, and the flag
## (logo_flag.gdshader, flag_wave's wave) waving from it, streaming along this node's +x. The node's origin
## is the pole's foot on the ground. Everything is built in code as internal children (shared meshes and
## material, a cylinder collider on the pole), so a level stores only the transform and `pole_height`.
##
## Arco del Viento's generator places one in its start venue. On every other level that has none,
## Level.gd calls `place_at_finish()` once the level's collision exists: it stands a flag on level,
## open, dry ground beside the start gantry, clear of the lap and of anything solid, streaming away from
## the road so the grid sees it broadside.
##
## The artwork is `bake_texture()`'s (the logo, images/logo_transparent.png, on navy between orange bands),
## saved as TEXTURE_PATH by the generators that use it (Arco del Viento, Bloombay Dunes' small logo flags).

const PropKit = preload("res://PropKit.gd")

const TEXTURE_PATH := "res://generated/logo_flag_texture.res"
## The flag's length (hoist to fly) and depth, in metres, and how far under the pole's top it hangs.
const FLAG_SIZE := Vector2(6.6, 4.1)
const FLAG_DROP := 0.45

@export var pole_height := 14.0:
	set(v):
		pole_height = v
		if is_inside_tree():
			_build()

static var _flag_mesh: ArrayMesh
static var _flag_material: ShaderMaterial
static var _pole_meshes := {}
static var _pole_materials := {}

var _root: Node3D


func _ready() -> void:
	add_to_group("logo_flags")
	_build()


func _build() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "Built"
	add_child(_root, false, Node.INTERNAL_MODE_FRONT)
	var pole := MeshInstance3D.new()
	pole.name = "LogoFlagPole"
	pole.mesh = _pole_mesh(pole_height)
	_root.add_child(pole)
	var flag := MeshInstance3D.new()
	flag.name = "LogoFlagCloth"
	flag.mesh = flag_mesh()
	flag.material_override = flag_material(0.12, 5.5)
	flag.position = Vector3(0.1, pole_height - FLAG_DROP, 0.0)
	flag.extra_cull_margin = FLAG_SIZE.x * 0.25
	_root.add_child(flag)
	var body := StaticBody3D.new()
	body.name = "LogoFlagPoleBody"
	body.set_meta(&"surface", "asphalt")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.16
	cyl.height = pole_height
	cs.shape = cyl
	cs.position = Vector3(0, pole_height * 0.5, 0)
	body.add_child(cs)
	var foot := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.65, 1.1)
	foot.shape = box
	foot.position = Vector3(0, 0.03, 0)
	body.add_child(foot)
	_root.add_child(body)


# ======================================================================================
#  Meshes, material, artwork
# ======================================================================================

## The flag: a grid from the hoist (u 0, at the pole) to the fly (u 1) along +x, its top at y = 0, facing
## +z (flag_wave.gdshaderinc reads which way it streams from the normal), UV2 its phase and length.
static func flag_mesh() -> ArrayMesh:
	if _flag_mesh:
		return _flag_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 28
	var nv := 12
	for j in range(nv + 1):
		for i in range(nu + 1):
			var u: float = float(i) / nu
			var v: float = float(j) / nv
			st.set_normal(Vector3(0, 0, 1))
			st.set_uv(Vector2(u, v))
			st.set_uv2(Vector2(0.0, FLAG_SIZE.x))
			st.add_vertex(Vector3(u * FLAG_SIZE.x, -v * FLAG_SIZE.y, 0.0))
	for j in range(nv):
		for i in range(nu):
			var a: int = j * (nu + 1) + i
			var c: int = a + nu + 1
			# Clockwise seen from +z, the front (CLAUDE.md, procedural mesh winding).
			for idx in [c, a, c + 1, a, a + 1, c + 1]:
				st.add_index(idx)
	_flag_mesh = st.commit()
	return _flag_mesh


## The flag's material: logo_flag.gdshader with the baked artwork, waving `amplitude` (a share of the
## flag's length) at `speed`. Shared per pair of values.
static func flag_material(amplitude: float, speed: float) -> ShaderMaterial:
	if _flag_material and is_equal_approx(float(_flag_material.get_shader_parameter("amplitude")), amplitude) \
			and is_equal_approx(float(_flag_material.get_shader_parameter("speed")), speed):
		return _flag_material
	var m := ShaderMaterial.new()
	m.shader = load("res://logo_flag.gdshader")
	m.set_shader_parameter("flag_tex", load(TEXTURE_PATH))
	m.set_shader_parameter("amplitude", amplitude)
	m.set_shader_parameter("speed", speed)
	_flag_material = m
	return m


## The pole, `height` tall from its foot at the origin: a concrete foot, a tapering white pole, a gilt ball.
static func _pole_mesh(height: float) -> ArrayMesh:
	var key := snappedf(height, 0.01)
	if _pole_meshes.has(key):
		return _pole_meshes[key]
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material: return _pole_material(k)
	var kit := {}
	var top := Vector3(0, height, 0)
	pk.block(kit, "concrete", Vector3(-0.55, -0.3, -0.55), Vector3(0.55, 0.35, 0.55), Color(0.80, 0.78, 0.74))
	pk.tube(kit, "metal", Vector3(0, -0.3, 0), top, 0.13, 0.08, 10, Color(0.92, 0.92, 0.90))
	pk.tube(kit, "metal", Vector3(0, height - FLAG_DROP + 0.05, 0.0), Vector3(0, height - FLAG_DROP - FLAG_SIZE.y - 0.05, 0.0), 0.105, 0.1, 10, Color(0.85, 0.85, 0.83))
	pk.lathe(kit, "gilt", top, [Vector2(0.0, 0.0), Vector2(0.17, 0.1), Vector2(0.2, 0.22), Vector2(0.15, 0.36), Vector2(0.0, 0.42)], 12, Color(0.95, 0.72, 0.22))
	var mesh: ArrayMesh = pk.commit(kit)
	_pole_meshes[key] = mesh
	return mesh


static func _pole_material(key: String) -> Material:
	if _pole_materials.has(key):
		return _pole_materials[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	match key:
		"concrete":
			m.roughness = 0.9
		"gilt":
			m.metallic = 0.8
			m.roughness = 0.3
		_:
			m.metallic = 0.4
			m.roughness = 0.35
	_pole_materials[key] = m
	return m


## Draws the flag's artwork and saves it as TEXTURE_PATH: the logo on its own navy between orange bands with
## a white pinstripe, 1024 x 640, mipmapped so it doesn't shimmer at a distance. Run by the generators.
static func bake_texture() -> Texture2D:
	var w := 1024
	var h := 640
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color8(14, 26, 64))
	var band := int(h * 0.075)
	img.fill_rect(Rect2i(0, 0, w, band), Color8(244, 120, 24))
	img.fill_rect(Rect2i(0, h - band, w, band), Color8(244, 120, 24))
	var pin := int(h * 0.014)
	img.fill_rect(Rect2i(0, band, w, pin), Color8(240, 240, 236))
	img.fill_rect(Rect2i(0, h - band - pin, w, pin), Color8(240, 240, 236))
	var logo: Image = (load("res://images/logo_transparent.png") as Texture2D).get_image()
	if logo.is_compressed():
		logo.decompress()
	logo.convert(Image.FORMAT_RGBA8)
	var lw := int(w * 0.84)
	var lh := int(float(lw) * logo.get_height() / logo.get_width())
	logo.resize(lw, lh, Image.INTERPOLATE_LANCZOS)
	img.blend_rect(logo, Rect2i(0, 0, lw, lh), Vector2i((w - lw) / 2, (h - lh) / 2))
	img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	# Kept, or a headless save writes the texture empty (CLAUDE.md, procedural cars).
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	tex.take_over_path(TEXTURE_PATH)
	ResourceSaver.save(tex, TEXTURE_PATH)
	return load(TEXTURE_PATH)


# ======================================================================================
#  Finding a place at the start
# ======================================================================================

## Along the road from the finish line (gate space: the grid is on +z, the cars drive toward -z), the
## places tried first to last: just past the line, where the grid's cameras look.
const TRY_ALONG := [-8.0, -14.0, -3.0, -20.0, 4.0, -27.0, 10.0, -34.0, 16.0]
## Across, from the line's middle.
const TRY_ACROSS := [13.0, 15.5, 18.0, 21.0, 25.0, 30.0]
## No nearer the lap than this (a road's half width and its verge).
const LAP_CLEAR := 11.0
const MIN_POLE := 8.0

## Stands a flag beside `level`'s FinishLine, unless the level has one, where the grid can see it (not behind
## a grandstand or a stack of containers). Returns the flag, or null.
static func place_at_finish(level: Node3D) -> Node3D:
	for f in level.get_tree().get_nodes_in_group("logo_flags"):
		if level.is_ancestor_of(f):
			return null
	var gate := level.get_node_or_null("FinishLine") as Node3D
	if gate == null:
		return null
	var space := level.get_world_3d().direct_space_state
	var paths: Array[Path3D] = []
	for p in level.find_children("*", "Path3D", true, false):
		if (p as Path3D).curve and (p as Path3D).curve.point_count > 1:
			paths.append(p as Path3D)
	var waters := _water_meshes(level)
	var gate_bodies: Array[RID] = []
	for b in gate.find_children("*", "CollisionObject3D", true, false):
		gate_bodies.append((b as CollisionObject3D).get_rid())
	var gb := gate.global_basis.orthonormalized()
	var across := Vector3(gb.x.x, 0.0, gb.x.z).normalized()
	var along := Vector3(gb.z.x, 0.0, gb.z.z).normalized()
	for a in TRY_ALONG:
		for d in TRY_ACROSS:
			for side in [-1.0, 1.0]:
				var q: Vector3 = gate.global_position + along * float(a) + across * (float(d) * float(side))
				var spot := _spot_ok(space, q, across * float(side), gate.global_position.y, paths, waters, gate_bodies)
				if spot.is_empty():
					continue
				# Seen from the grid: nothing solid between the cars waiting there and the flag.
				# Its four corners and its middle (a rock pile hid half of Mountain Pass's).
				var eye: Vector3 = gate.global_position + along * 20.0 + Vector3.UP * 5.0
				var hoist: Vector3 = (spot["pos"] as Vector3) + Vector3.UP * (float(spot["height"]) - FLAG_DROP)
				var fly: Vector3 = across * (float(side) * FLAG_SIZE.x)
				var seen := true
				for c in [hoist, hoist + fly, hoist - Vector3.UP * FLAG_SIZE.y, hoist + fly - Vector3.UP * FLAG_SIZE.y, hoist + fly * 0.5 - Vector3.UP * FLAG_SIZE.y * 0.5]:
					if not _clear_view(space, eye, c, gate_bodies):
						seen = false
						break
				if not seen:
					continue
				var flag := Node3D.new()
				flag.name = "LogoFlag"
				flag.set_script(load("res://LogoFlag.gd"))
				flag.set("pole_height", spot["height"])
				# Streaming away from the road: its +x outward.
				var out: Vector3 = across * float(side)
				flag.transform = Transform3D(Basis(out, Vector3.UP, out.cross(Vector3.UP)), spot["pos"])
				level.add_child(flag)
				print("[LogoFlag] %s: at %s, %.0fm along and %.0fm %s of the line, pole %.1fm" % [level.name, spot["pos"],
						float(a), float(d), "right" if side > 0.0 else "left", float(spot["height"])])
				return flag
	print("[LogoFlag] %s: no open ground beside the start" % level.name)
	return null


## {pos, height} for a pole standing at `q` (x, z) with its flag streaming along `out`, or {} if the ground
## there won't do: steep, uneven, far above or below the line, on the road or near the lap, under water,
## crowded by anything solid round the pole or where the flag hangs, or under a roof lower than MIN_POLE.
static func _spot_ok(space: PhysicsDirectSpaceState3D, q: Vector3, out: Vector3, gate_y: float, paths: Array[Path3D], waters: Array, skip: Array[RID]) -> Dictionary:
	for p in paths:
		var local := p.to_local(q)
		var c := p.to_global(p.curve.get_closest_point(local))
		if Vector2(c.x - q.x, c.z - q.z).length() < LAP_CLEAR:
			return {}
	var ground := _ground(space, q + Vector3.UP * 30.0, q - Vector3.UP * 30.0, skip)
	if ground.is_empty():
		return {}
	var g: Vector3 = ground["pos"]
	if (ground["normal"] as Vector3).y < 0.92 or absf(g.y - gate_y) > 4.0:
		return {}
	var name_l := str(ground["name"]).to_lower()
	for word in ["road", "track", "curb", "ramp", "deck", "bridge", "jump", "water"]:
		if word in name_l:
			return {}
	# Level under the foot and the flag's reach.
	for o in [Vector3(0.9, 0, 0), Vector3(-0.9, 0, 0), Vector3(0, 0, 0.9), Vector3(0, 0, -0.9)]:
		var h := _ground(space, g + o + Vector3.UP * 3.0, g + o - Vector3.UP * 3.0, skip)
		if h.is_empty() or absf((h["pos"] as Vector3).y - g.y) > 0.4:
			return {}
	for w in waters:
		var aabb: AABB = w
		if q.x > aabb.position.x and q.x < aabb.end.x and q.z > aabb.position.z and q.z < aabb.end.z and g.y < aabb.end.y + 0.3:
			return {}
	# Nothing solid round the pole, nor where the flag hangs (from 8m up, out to its fly); anything up where
	# a 14m pole's flag would be lowers the pole.
	var ex: Array[RID] = skip.duplicate()
	ex.append(ground["rid"])
	var height := 14.0
	for c in [Vector3(0, 1.8, 0), Vector3(0, 5.0, 0), out * 2.5 + Vector3(0, 8.0, 0), out * 5.5 + Vector3(0, 8.0, 0),
			Vector3(0, 11.5, 0), out * 2.5 + Vector3(0, 11.5, 0), out * 5.5 + Vector3(0, 11.5, 0)]:
		if _crowded(space, g + (c as Vector3), ex):
			if (c as Vector3).y < 10.0:
				return {}
			height = 10.0
	# Room overhead: a cavern's roof or an arch lowers the pole.
	var up := PhysicsRayQueryParameters3D.create(g + Vector3.UP * 0.5, g + Vector3.UP * 16.0)
	up.exclude = skip
	var roof := space.intersect_ray(up)
	if not roof.is_empty():
		height = minf(height, (roof["position"] as Vector3).y - g.y - 1.5)
	if height < MIN_POLE:
		return {}
	return {"pos": g, "height": height}


static func _clear_view(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, skip: Array[RID]) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = skip
	return space.intersect_ray(q).is_empty()


static func _crowded(space: PhysicsDirectSpaceState3D, at: Vector3, skip: Array[RID]) -> bool:
	var probe := SphereShape3D.new()
	probe.radius = 1.6
	var sq := PhysicsShapeQueryParameters3D.new()
	sq.shape = probe
	sq.transform = Transform3D(Basis(), at)
	sq.exclude = skip
	return not space.intersect_shape(sq, 1).is_empty()


static func _ground(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, skip: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = skip
	q.hit_back_faces = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	var nm := str((hit["collider"] as Node).name) if hit["collider"] is Node else ""
	return {"pos": hit["position"], "normal": hit["normal"], "name": nm, "rid": hit["rid"]}


## The world boxes of the level's water surfaces (meshes and nodes named for water), to keep the flag dry.
static func _water_meshes(level: Node) -> Array:
	var out: Array = []
	for n in level.find_children("*", "GeometryInstance3D", true, false):
		var nm := str(n.name).to_lower()
		if not ("water" in nm or "lake" in nm or "river" in nm or "sea" in nm or "ocean" in nm):
			continue
		var gi := n as GeometryInstance3D
		out.append(gi.global_transform * gi.get_aabb())
	return out
