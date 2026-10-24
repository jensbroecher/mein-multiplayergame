extends RefCounted
## Tyre walls made of stacks that give when a cart hits them (SpringProps.gd), shared by the Lakeside
## Course, Bloombay Dunes and Pinecrest Ridge generators. A stack is three painted tyres
## (PropKit.painted_tyre, tyre_wall.gdshader) piled a little untidily; there are a few designs (each
## colour in VARIANTS piles), and each wall's stacks are instances of them. The wall keeps its own box
## colliders (the generator's), so a crash still stops the cart; the stacks only shift and rock.

const COLOURS := [Color(0.80, 0.10, 0.09), Color(0.92, 0.92, 0.90), Color(0.07, 0.07, 0.08)]
const VARIANTS := 2
const TYRES := 3


## The stack designs at life size (COLOURS x VARIANTS), committed through `kit`, whose material for
## `key` must be tyre_wall.gdshader's.
static func meshes(kit, key: String, seed_value: int) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	kit.reset_frame()
	for ci in range(COLOURS.size()):
		for v in range(VARIANTS):
			var k := {}
			var y := 0.0
			for t in range(TYRES):
				var j := Vector3(rng.randf_range(-0.025, 0.025), 0.0, rng.randf_range(-0.025, 0.025))
				var tip := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.035))
				kit.painted_tyre(k, key, Vector3(0, y + 0.1, 0) + j, 0.19, 0.31, 0.2, (COLOURS[ci] as Color).darkened(rng.randf_range(0.0, 0.1)), rng.randf(), tip)
				y += 0.2
			out.append(kit.commit(k))
	return out


## The design for the `i`th stack of a wall: the colours in turn, a variant at random.
static func design(i: int, rng: RandomNumberGenerator) -> int:
	return (i % COLOURS.size()) * VARIANTS + rng.randi() % VARIANTS


## A node holding one SpringProps MultiMesh per design used: `stacks` is [Transform3D, design] pairs
## in the parent's space, `scale` the props' scale (the generator's PROP_SCALE).
static func spring_node(node_name: String, design_meshes: Array, stacks: Array, scale: float) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	var by_design := {}
	for s in stacks:
		if not by_design.has(s[1]):
			by_design[s[1]] = []
		by_design[s[1]].append(s[0])
	for d in by_design.keys():
		var xfs: Array = by_design[d]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = design_meshes[d]
		mm.instance_count = xfs.size()
		# The dummy renderer drops set_instance_transform(): write the buffer (CLAUDE.md, headless gotchas).
		var buf := PackedFloat32Array()
		buf.resize(xfs.size() * 12)
		for i in range(xfs.size()):
			var t: Transform3D = xfs[i]
			var o := i * 12
			buf[o] = t.basis.x.x
			buf[o + 1] = t.basis.y.x
			buf[o + 2] = t.basis.z.x
			buf[o + 3] = t.origin.x
			buf[o + 4] = t.basis.x.y
			buf[o + 5] = t.basis.y.y
			buf[o + 6] = t.basis.z.y
			buf[o + 7] = t.origin.y
			buf[o + 8] = t.basis.x.z
			buf[o + 9] = t.basis.y.z
			buf[o + 10] = t.basis.z.z
			buf[o + 11] = t.origin.z
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Stacks%d" % d
		mmi.multimesh = mm
		mmi.set_script(load("res://SpringProps.gd"))
		var rest: Array[Transform3D] = []
		for t in xfs:
			rest.append(t)
		mmi.set("rest", rest)
		# A cart's sphere (1.35m) against a stack (0.31m at life size).
		mmi.set("reach", 1.45 + 0.31 * scale)
		mmi.set("height", 0.6 * scale + 1.0)
		mmi.set("tip_per_speed", 0.012)
		mmi.set("max_tip", 0.22)
		mmi.set("spring", 12.0)
		mmi.set("damping", 0.35)
		mmi.set("shove_per_speed", 0.025)
		mmi.set("max_shove", 0.6)
		mmi.set("slide_friction", 6.0)
		node.add_child(mmi)
	return node
