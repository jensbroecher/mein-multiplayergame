extends RefCounted
## The Lakeside Course's meadow grass (meadow_grass.gdshader), built by regenerate_lakeside.gd's
## _build_meadow: tufts of real blades instead of the old crossed picture cards.
##
## A blade is a strip along a curved spine that leans out of the tuft and bends further toward its
## tip, tapering to a point, with normals rounded across it so it shades like a folded leaf. A tuft
## is a dozen or so blades round a small root circle, and some tufts carry flowers (a stalk and a
## head of petals) that the shader shows in drifts.
##
## Three tiers share the meadow: TIERS[0] the dense near grass, [1] and [2] sparser and coarser, drawn
## further and growing wider as the nearer tiers fade (the shader). Each tier is one MultiMesh of a
## cell's worth of tufts at y = 0, shuffled, which every cell of that tier draws; the shader stands the
## tufts on the ground from the height map and grows them as the grass map says.

## Per tier: cell (m), tufts per square metre, blades a tuft, segments a blade, flowers a tuft, blade
## width (m at the root), fade begin and end (m), and the shader's two widening stages.
const TIERS := [
	{"cell": 24.0, "density": 2.4, "blades": 18, "segs": 3, "flowers": 1, "width": 0.045,
		"fade": Vector2(36.0, 48.0), "widen_a": Vector3(40.0, 62.0, 1.0), "widen_b": Vector3(130.0, 152.0, 1.0)},
	{"cell": 48.0, "density": 0.8, "blades": 10, "segs": 2, "flowers": 0, "width": 0.065,
		"fade": Vector2(96.0, 116.0), "widen_a": Vector3(32.0, 48.0, 1.7), "widen_b": Vector3(130.0, 152.0, 1.0)},
	{"cell": 96.0, "density": 0.22, "blades": 7, "segs": 2, "flowers": 0, "width": 0.09,
		"fade": Vector2(190.0, 230.0), "widen_a": Vector3(32.0, 48.0, 1.7), "widen_b": Vector3(94.0, 116.0, 1.8)},
]

## Blade length range (m, before the shader's tuft_height and the map's height), lean from upright
## at the root (radians) and the extra bend toward the tip.
const BLADE_LEN := Vector2(0.45, 0.95)
const LEAN := Vector2(0.06, 0.5)
const CURL := Vector2(0.2, 0.75)
const ROOT_R := 0.2


## One tuft for `tier`: blades (COLOR.b 0), then flower stalks (0.5) and heads (1). COLOR.r is how
## far up, COLOR.g a random per blade, COLOR.a the flower head's shade.
static func tuft_mesh(tier: int, seed_value: int) -> ArrayMesh:
	var t: Dictionary = TIERS[tier]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades: int = t["blades"]
	for b in range(blades):
		# Round the root circle, a little random, leaning outward from it.
		var a: float = TAU * (float(b) + rng.randf_range(-0.35, 0.35)) / blades
		var r: float = ROOT_R * sqrt(rng.randf_range(0.15, 1.0))
		var root := Vector3(cos(a) * r, -0.12, sin(a) * r)
		var out_a: float = a + rng.randf_range(-0.6, 0.6)
		var dir := Vector3(cos(out_a), 0.0, sin(out_a))
		# The inner blades stand up, the outer ones lean out.
		var lean: float = lerpf(LEAN.x, LEAN.y, r / ROOT_R) * rng.randf_range(0.7, 1.3)
		var length: float = rng.randf_range(BLADE_LEN.x, BLADE_LEN.y) * lerpf(1.08, 0.82, r / ROOT_R)
		_blade(st, root, dir, lean, rng.randf_range(CURL.x, CURL.y), length, float(t["width"]) * rng.randf_range(0.8, 1.2),
				int(t["segs"]), rng.randf(), rng.randf_range(-0.5, 0.5))
	for f in range(int(t["flowers"])):
		var a2: float = rng.randf() * TAU
		var root2 := Vector3(cos(a2), 0.0, sin(a2)) * ROOT_R * 0.6 + Vector3(0.0, -0.12, 0.0)
		var top := root2 + Vector3(cos(a2) * 0.1, rng.randf_range(0.6, 0.85), sin(a2) * 0.1)
		_flower(st, root2, top, rng)
	# Shared vertices once: each blade's rows, not three per triangle.
	st.index()
	return st.commit()


## A blade: spine from `root` leaning `lean` toward `dir`, bending `curl` more by the tip, `segs`
## rows of two vertices and a tip. `twist` turns the blade's face about its spine.
static func _blade(st: SurfaceTool, root: Vector3, dir: Vector3, lean: float, curl: float, length: float,
		width: float, segs: int, rand: float, twist: float) -> void:
	var side := Vector3(-dir.z, 0.0, dir.x)
	var spine: Array = []
	var p := root
	spine.append(p)
	var step := length / segs
	for k in range(1, segs + 1):
		var u := (float(k) - 0.5) / segs
		var ang := lean + curl * pow(u, 1.6)
		p += (dir * sin(ang) + Vector3.UP * cos(ang)) * step
		spine.append(p)
	var rows: Array = []
	for k in range(segs + 1):
		var u := float(k) / segs
		var tangent: Vector3 = ((spine[mini(k + 1, segs)] as Vector3) - (spine[maxi(k - 1, 0)] as Vector3)).normalized()
		var s := side.rotated(tangent, twist * u)
		# The face looks out along the lean; its normal rounded toward each edge.
		var face := s.cross(tangent).normalized()
		if face.dot(dir) < 0.0:
			face = -face
		var w := width * (1.0 - pow(u, 1.5)) * 0.5
		if k == segs:
			rows.append([[spine[k], face, u, 0.0]])
		else:
			rows.append([[(spine[k] as Vector3) - s * w, (face - s * 0.55).normalized(), u, -1.0],
					[(spine[k] as Vector3) + s * w, (face + s * 0.55).normalized(), u, 1.0]])
	for k in range(segs):
		var lo: Array = rows[k]
		var hi: Array = rows[k + 1]
		if hi.size() == 1:
			_tri(st, lo[0], lo[1], hi[0], rand, 0.0, 0.0)
		else:
			_tri(st, lo[0], lo[1], hi[1], rand, 0.0, 0.0)
			_tri(st, lo[0], hi[1], hi[0], rand, 0.0, 0.0)


## A flower: a thin stalk (two crossed strips) and a head of petals round a centre, facing up.
static func _flower(st: SurfaceTool, root: Vector3, top: Vector3, rng: RandomNumberGenerator) -> void:
	var up := (top - root).normalized()
	for k in range(2):
		var s := Vector3(cos(k * PI * 0.5), 0.0, sin(k * PI * 0.5)) * 0.008
		var n := s.cross(up).normalized()
		var a := [root - s, n, 0.0, -1.0]
		var b := [root + s, n, 0.0, 1.0]
		var c := [top + s, n, 1.0, 1.0]
		var d := [top - s, n, 1.0, -1.0]
		_tri(st, a, b, c, 0.5, 0.5, 0.0)
		_tri(st, a, c, d, 0.5, 0.5, 0.0)
	var petals := 5
	var radius := rng.randf_range(0.045, 0.065)
	var centre := [top + Vector3(0.0, 0.012, 0.0), Vector3.UP, 1.0, 0.0]
	for i in range(petals):
		var a0 := TAU * i / petals
		var a1 := TAU * (i + 0.5) / petals
		var a2 := TAU * (i + 1) / petals
		var p0 := [top + Vector3(cos(a0), 0.25, sin(a0)) * radius * 0.45, Vector3.UP, 1.0, 0.0]
		var p1 := [top + Vector3(cos(a1) * radius, radius * 0.2, sin(a1) * radius), Vector3.UP, 1.0, 0.0]
		var p2 := [top + Vector3(cos(a2), 0.25, sin(a2)) * radius * 0.45, Vector3.UP, 1.0, 0.0]
		_tri(st, centre, p0, p1, 0.5, 1.0, 0.9)
		_tri(st, centre, p1, p2, 0.5, 1.0, 0.9)
	# A darker eye in the middle.
	for i in range(petals):
		var e0 := [top + Vector3(cos(TAU * i / petals), 0.5, sin(TAU * i / petals)) * radius * 0.3, Vector3.UP, 1.0, 0.0]
		var e1 := [top + Vector3(cos(TAU * (i + 1) / petals), 0.5, sin(TAU * (i + 1) / petals)) * radius * 0.3, Vector3.UP, 1.0, 0.0]
		_tri(st, [top + Vector3(0.0, 0.02, 0.0), Vector3.UP, 1.0, 0.0], e0, e1, 0.5, 1.0, 0.3)


## A triangle of [position, normal, height share, across] vertices, wound so its front face is on
## the normals' side (Godot's front face is clockwise: generate_normals() gives (c - a) x (b - a)).
## `rand` (COLOR.g) a random per blade, `part` (COLOR.b) and `shade` (COLOR.a) as the shader reads them.
static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, rand: float, part: float, shade: float) -> void:
	var pa: Vector3 = a[0]
	var pb: Vector3 = b[0]
	var pc: Vector3 = c[0]
	var n: Vector3 = (a[1] as Vector3) + (b[1] as Vector3) + (c[1] as Vector3)
	var verts := [a, b, c]
	if (pc - pa).cross(pb - pa).dot(n) < 0.0:
		verts = [a, c, b]
	for v in verts:
		st.set_color(Color(float(v[2]), rand, part, shade))
		st.set_uv(Vector2(float(v[3]), float(v[2])))
		st.set_normal(v[1])
		st.add_vertex(v[0])


## A cell's worth of tufts for `tier`, on a jittered grid (so they cover the cell evenly), in random
## order, so drawing the first N (MeadowDetail.gd) thins every cell evenly.
static func cell_multimesh(tier: int, mesh: Mesh, seed_value: int) -> MultiMesh:
	var t: Dictionary = TIERS[tier]
	var cell: float = t["cell"]
	var n := int(round(sqrt(float(t["density"])) * cell))
	var gap := cell / n
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spots := PackedVector2Array()
	for i in range(n):
		for j in range(n):
			spots.append(Vector2((i + rng.randf()) * gap, (j + rng.randf()) * gap))
	for i in range(spots.size() - 1, 0, -1):
		var k := rng.randi_range(0, i)
		var tmp := spots[i]
		spots[i] = spots[k]
		spots[k] = tmp
	var buf := PackedFloat32Array()
	buf.resize(spots.size() * 12)
	for i in range(spots.size()):
		var o := i * 12
		buf[o] = 1.0
		buf[o + 3] = spots[i].x
		buf[o + 5] = 1.0
		buf[o + 10] = 1.0
		buf[o + 11] = spots[i].y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()
	# The dummy renderer drops set_instance_transform(): write the buffer (CLAUDE.md, headless gotchas).
	mm.buffer = buf
	return mm


## The terrain's heights (grid order, `side` a row) as a lossless RG8 texture: 16 bits over the
## range [lo, hi]. Returns [texture, Vector2(lo, hi)].
static func height_texture(heights: PackedFloat32Array, side: int) -> Array:
	var lo := INF
	var hi := -INF
	for h in heights:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	lo = floorf(lo) - 1.0
	hi = ceilf(hi) + 1.0
	var data := PackedByteArray()
	data.resize(side * side * 2)
	for i in range(side * side):
		var v := clampi(int(round((heights[i] - lo) / (hi - lo) * 65535.0)), 0, 65535)
		data[i * 2] = v >> 8
		data[i * 2 + 1] = v & 255
	var img := Image.create_from_data(side, side, false, Image.FORMAT_RG8, data)
	return [_lossless(img), Vector2(lo, hi)]


## The grass map (R amount, G height, `side` texels a row) as a lossless RG8 texture with mipmaps.
static func grass_texture(data: PackedByteArray, side: int) -> Texture2D:
	var img := Image.create_from_data(side, side, false, Image.FORMAT_RG8, data)
	return _lossless(img)


static func _lossless(img: Image) -> PortableCompressedTexture2D:
	var tex := PortableCompressedTexture2D.new()
	# Kept, or a headless save writes the texture empty (CLAUDE.md, procedural cars).
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return tex


static func material(tier: int, height_tex: Texture2D, height_range: Vector2, grass_tex: Texture2D,
		height_grid: Vector4, grass_grid: Vector3) -> ShaderMaterial:
	var t: Dictionary = TIERS[tier]
	var m := ShaderMaterial.new()
	m.shader = load("res://meadow_grass.gdshader")
	m.set_shader_parameter("height_map", height_tex)
	m.set_shader_parameter("height_range", height_range)
	m.set_shader_parameter("height_grid", height_grid)
	m.set_shader_parameter("grass_map", grass_tex)
	m.set_shader_parameter("grass_grid", grass_grid)
	m.set_shader_parameter("fade_begin", (t["fade"] as Vector2).x)
	m.set_shader_parameter("fade_end", (t["fade"] as Vector2).y)
	m.set_shader_parameter("widen_a", t["widen_a"])
	m.set_shader_parameter("widen_b", t["widen_b"])
	m.set_shader_parameter("jitter", float(t["cell"]) / round(sqrt(float(t["density"])) * float(t["cell"])) * 0.9)
	return m
