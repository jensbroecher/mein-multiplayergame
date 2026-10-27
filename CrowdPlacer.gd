extends RefCounted
## Spectators for a level outside Nyota Stadium, the same people as its crowd (see CLAUDE.md, "The crowd"):
## each a card (stadium_crowd.gdshader) and, near the lap, a 3D figure (CrowdKit.gd's mesh, shared as
## generated/crowd_person.res, stadium_person.gdshader), swapping by dither, under a "Crowd" node that
## CrowdDetail.gd scales with the Detail Level. regenerate_nyota_stadium.gd builds its own (the same
## numbers); this is the part a level only adds people with.
##
## A spot is [position, facing (horizontal), seated, in a stand (optional), pose (optional: one of the 16;
## drawn from the odds otherwise)]: a standing one's position is the
## ground (or the stand's tread) under its feet, a seated one's the top of its seat. Only people in a stand
## wave flags: anywhere else a gazebo, a tent or a stall can hang over them, and the flag stood through it. `scale` takes Nyota's 1.86 times life size to the level's.
## `skin` weights the four groups crowd_common.gdshaderinc draws from INSTANCE_CUSTOM.g:
## [African, South Asian, European, East Asian, Arab or mixed].

const CrowdKit = preload("res://CrowdKit.gd")

const CELL := 40.0
const NEAR_CELL := 24.0
const LOD_BEGIN := 34.0
const LOD_END := 44.0
const LOD_JITTER := 3.0
## The card shapes by pose class (Nyota's CROWD_CARDS): [width, height, reach below the pelvis, x and y of
## its middle in the spectator's frame].
const CARDS := [
	[1.1, 2.75, 0.9, 0.0, 0.475],
	[2.1, 3.15, 0.9, 0.0, 0.675],
	[1.1, 3.5, 1.65, 0.0, 1.75],
	[2.1, 3.9, 1.65, 0.0, 1.95],
	[3.0, 4.9, 1.65, -0.5, 2.45],
]
## Seated cards stand forward of the seat, so the shins hang in front of it.
const CARD_FORWARD := 0.6
const POSE_SEATED := [0.34, 0.13, 0.12, 0.17, 0.08, 0.09, 0.07]
const POSE_STANDING := [0.26, 0.10, 0.08, 0.17, 0.12, 0.0, 0.14, 0.05, 0.08]
## Standing with the arms crossed (stadium_person.gdshader's pose 11).
const POSE_ARMS_CROSSED := 11
## Standing up in a stand: more cheering, and the flags.
const POSE_STAND_FANS := [0.16, 0.13, 0.22, 0.10, 0.06, 0.14, 0.06, 0.08, 0.05]
## The g ranges of crowd_skin's groups.
const SKIN_RANGES := [Vector2(0.0, 0.80), Vector2(0.80, 0.86), Vector2(0.86, 0.93), Vector2(0.93, 0.96), Vector2(0.96, 1.0)]


static func material(mode: int, card: Array = []) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://stadium_person.gdshader" if mode == 1 else "res://stadium_crowd.gdshader")
	m.set_shader_parameter("lod_mode", mode)
	m.set_shader_parameter("lod_fade_begin", LOD_BEGIN)
	m.set_shader_parameter("lod_fade_end", LOD_END)
	m.set_shader_parameter("lod_jitter", LOD_JITTER)
	if mode == 2:
		m.set_shader_parameter("card_w", card[0])
		m.set_shader_parameter("card_h", card[1])
		m.set_shader_parameter("card_below", card[2])
		m.set_shader_parameter("card_x", card[3])
	return m


static func card_class(pose: int) -> int:
	if pose == 5:
		return 1
	if pose == 9 or pose == 14:
		return 3
	if pose == 12:
		return 4
	return 2 if pose >= 7 else 0


static func pick(rng: RandomNumberGenerator, odds: Array, first: int) -> int:
	var total := 0.0
	for o in odds:
		total += float(o)
	var r := rng.randf() * total
	for i in range(odds.size()):
		r -= float(odds[i])
		if r <= 0.0:
			return first + i
	return first


static func skin_draw(rng: RandomNumberGenerator, skin: Array) -> float:
	var total := 0.0
	for w in skin:
		total += float(w)
	var r := rng.randf() * total
	for i in range(skin.size()):
		r -= float(skin[i])
		if r <= 0.0:
			var g: Vector2 = SKIN_RANGES[i]
			return lerpf(g.x, g.y - 0.001, rng.randf())
	return 0.9


## Builds the crowd under `parent` and returns the "Crowd" node. `save` saves a resource under a name
## (the generator's), so the card meshes and their materials are shared files.
static func build(parent: Node, spots: Array, scale: float, skin: Array, seed_v: int, save: Callable) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var person: Mesh = load("res://generated/crowd_person.res")
	var cards: Array = []
	for cls in range(CARDS.size()):
		var c: Array = CARDS[cls]
		var q := QuadMesh.new()
		q.size = Vector2(float(c[0]), float(c[1]))
		q.center_offset = Vector3(float(c[3]), float(c[4]), 0.0)
		q.material = save.call(material(2, c), "crowd_card_mat_%d" % cls)
		cards.append(save.call(q, "crowd_card_%d" % cls))
	var cells := {}
	var near := {}
	for sp in spots:
		var pos: Vector3 = sp[0]
		var face: Vector3 = sp[1]
		var seated: bool = sp[2]
		var in_stand: bool = sp.size() > 3 and sp[3]
		# The figure faces its +z.
		var z: Vector3 = Vector3(face.x, 0.0, face.z).normalized()
		var x: Vector3 = Vector3.UP.cross(z).normalized()
		var bs := Basis(x, Vector3.UP, z).rotated(Vector3.UP, rng.randf_range(-0.3, 0.3)).scaled(Vector3.ONE * scale)
		var pose: int = pick(rng, POSE_SEATED, 0) if seated else pick(rng, POSE_STAND_FANS if in_stand else POSE_STANDING, 7)
		if sp.size() > 4:
			pose = int(sp[4])
		var cust := Color(rng.randf(), skin_draw(rng, skin), (float(pose) + 0.5) / 16.0, rng.randf())
		var card_at: Vector3 = pos + z * (CARD_FORWARD * scale) if seated else pos
		var key := Vector3i(floori(pos.x / CELL), floori(pos.z / CELL), card_class(pose))
		if not cells.has(key):
			cells[key] = [[], []]
		cells[key][0].append(Transform3D(bs, card_at))
		cells[key][1].append(cust)
		var nk := Vector2i(floori(pos.x / NEAR_CELL), floori(pos.z / NEAR_CELL))
		if not near.has(nk):
			near[nk] = [[], []]
		near[nk][0].append(Transform3D(bs, pos))
		near[nk][1].append(cust)
	var root := Node3D.new()
	root.name = "Crowd"
	root.set_script(load("res://CrowdDetail.gd"))
	root.set("base_begin", LOD_BEGIN)
	root.set("base_end", LOD_END)
	root.set("jitter", LOD_JITTER)
	root.set("cell_reach", NEAR_CELL)
	parent.add_child(root)
	for key in cells:
		root.add_child(_cell_node("Crowd_%d_%d_%d" % [key.x, key.y, key.z], cards[key.z], cells[key][0], cells[key][1], 0.0))
	var near_root := Node3D.new()
	near_root.name = "CrowdNear"
	root.add_child(near_root)
	for key in near:
		near_root.add_child(_cell_node("CrowdNear_%d_%d" % [key.x, key.y], person, near[key][0], near[key][1], LOD_END + LOD_JITTER + NEAR_CELL))
	return root


static func _cell_node(node_name: String, mesh: Mesh, xfs: Array, customs: Array, range_end: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	var buf := PackedFloat32Array()
	buf.resize(xfs.size() * 16)
	for i in range(xfs.size()):
		var t: Transform3D = xfs[i]
		var b: Basis = t.basis
		var o := i * 16
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = t.origin.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = t.origin.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = t.origin.z
		var c: Color = customs[i]
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = c.a
	mm.buffer = buf
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		mmi.visibility_range_end = range_end
	return mmi
