@tool
class_name PaperBanner
extends Node3D
## A paper run-through banner on a frame, like the ones riders burst through at a supercross. The first cart
## through tears a ragged hole round where it hit, with rips running out of it; the scraps fly off with it,
## flutter down and settle, and whatever the rips cut loose from the frame drops too. Carts after it go
## through the hole, or tear more where they hit paper. One sheet a race: it is never put back.
##
## It builds itself as internal children (frame, colliders, sheet), so a level stores only its transform and
## exports. The origin is on the ground under the sheet's middle; the sheet lies in the node's XY plane and
## carts come from +Z (the artwork's front) and go on toward -Z, like a boost pad.
##
## The sheet is a grid of cells whose inner corners are jittered (`cell`), each cell a quad of its own (UV the
## place on the sheet, UV2 the place in the cell, COLOR which of its edges are torn: paper_banner.gdshader
## draws the bare paper there). A tear removes cells and rebuilds the sheet's mesh; every removed cell
## becomes a scrap, a MeshInstance3D with its own small mesh and the shared material, moved here: thrown,
## slowed hard by the air, fluttering, landing on whatever is under it (a ray), lying a while and shrinking
## away. Local scenery like KickBall: each peer tears its own from the carts it sees. Nothing is synced, and
## a cart loses no speed to it.
##
## The artwork is `bake_texture()`'s (the forest-run poster, images/posters/forestrun.jpeg, between orange bands
## with chequered panels either side), saved as TEXTURE_PATH by the generator that places a banner (Nyota Stadium).

const TEXTURE_PATH := "res://generated/paper_banner_texture.res"
const POSTER := "res://images/posters/forestrun.jpeg"
const SHADER := preload("res://paper_banner.gdshader")

## The hole a cart tears: half widths of an ellipse round its centre, each cell's edge drawn at 0.75-1.3 of it.
const HOLE := Vector2(1.55, 1.25)
const SLITS := Vector2i(2, 4)
const SLIT_LEN := Vector2(0.9, 2.8)
## Scraps: gravity, air drag per second, flutter, how long they lie before shrinking away.
const SCRAP_GRAVITY := 7.0
const SCRAP_DRAG := 1.5
const SCRAP_FLUTTER := 7.0
const SCRAP_LIFE := Vector2(7.0, 10.0)
const SCRAP_SHRINK := 0.6
const MAX_SCRAPS := 160
## The crowd cheers the first cart through (a 5s cheer, RMS -13.6 dBFS), from the banner.
const CHEER := "res://sounds/Fans_cheering.wav"
const CHEER_DB := -3.0

@export var size := Vector2(17.0, 6.6):
	set(v):
		size = v
		_rebuild_if_ready()
## The sheet's bottom edge over the ground.
@export var lift := 0.12:
	set(v):
		lift = v
		_rebuild_if_ready()
@export var cell := 0.45:
	set(v):
		cell = maxf(v, 0.15)
		_rebuild_if_ready()
@export var tear_seed := 7:
	set(v):
		tear_seed = v
		_rebuild_if_ready()

static var _material: ShaderMaterial
static var _rip: AudioStreamWAV

var _nx := 0
var _ny := 0
var _corners := PackedVector2Array()
var _gone := PackedByteArray()
var _cell_jit := PackedFloat32Array()
var _sheet: MeshInstance3D
var _frame: Node3D
var _scraps: Array = []
var _prev := {}
var _rng := RandomNumberGenerator.new()
var _sfx: AudioStreamPlayer3D
var _cheer: AudioStreamPlayer3D
var _built := false


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group("paper_banners")
	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = _rip_sound()
	_sfx.bus = &"SFX"
	_sfx.unit_size = 16.0
	_sfx.max_distance = 180.0
	add_child(_sfx, false, Node.INTERNAL_MODE_BACK)
	_cheer = AudioStreamPlayer3D.new()
	_cheer.stream = load(CHEER)
	_cheer.bus = &"SFX"
	_cheer.volume_db = CHEER_DB
	_cheer.unit_size = 30.0
	_cheer.max_distance = 260.0
	_cheer.position = Vector3(0.0, lift + size.y + 2.0, 0.0)
	add_child(_cheer, false, Node.INTERNAL_MODE_BACK)


func _rebuild_if_ready() -> void:
	if _built and is_inside_tree():
		_build()


func _build() -> void:
	for c in get_children(true):
		if c != _sfx and c != _cheer and c.get_parent() == self and c.owner == null:
			c.queue_free()
	_scraps.clear()
	_built = true
	_plan_grid()
	_build_frame()
	_sheet = MeshInstance3D.new()
	_sheet.name = "Sheet"
	_sheet.material_override = _shared_material()
	_material.set_shader_parameter(&"sheet_size", size)
	add_child(_sheet, false, Node.INTERNAL_MODE_BACK)
	_rebuild_sheet()


static func _shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		if ResourceLoader.exists(TEXTURE_PATH):
			_material.set_shader_parameter("art", load(TEXTURE_PATH))
	return _material


# ======================================================================================
#  The sheet
# ======================================================================================

func _plan_grid() -> void:
	_nx = maxi(int(round(size.x / cell)), 2)
	_ny = maxi(int(round(size.y / cell)), 2)
	var cw: float = size.x / _nx
	var ch: float = size.y / _ny
	var rng := RandomNumberGenerator.new()
	rng.seed = tear_seed
	_corners.resize((_nx + 1) * (_ny + 1))
	for j in range(_ny + 1):
		for i in range(_nx + 1):
			var p := Vector2(-size.x * 0.5 + i * cw, lift + size.y - j * ch)
			if i > 0 and i < _nx:
				p.x += rng.randf_range(-0.32, 0.32) * cw
			if j > 0 and j < _ny:
				p.y += rng.randf_range(-0.32, 0.32) * ch
			_corners[j * (_nx + 1) + i] = p
	_gone.resize(_nx * _ny)
	_gone.fill(0)
	_cell_jit.resize(_nx * _ny)
	for k in range(_nx * _ny):
		_cell_jit[k] = rng.randf()


func _corner(i: int, j: int) -> Vector2:
	return _corners[j * (_nx + 1) + i]


func _uv(p: Vector2) -> Vector2:
	return Vector2((p.x + size.x * 0.5) / size.x, (lift + size.y - p.y) / size.y)


func _cell_centre(i: int, j: int) -> Vector2:
	return (_corner(i, j) + _corner(i + 1, j) + _corner(i + 1, j + 1) + _corner(i, j + 1)) * 0.25


## Whether the neighbour across an edge is torn away (a sheet border is a clean cut, not a tear).
func _torn_side(i: int, j: int) -> Color:
	var f := func(a: int, b: int) -> float:
		if a < 0 or b < 0 or a >= _nx or b >= _ny:
			return 0.0
		return 1.0 if _gone[b * _nx + a] != 0 else 0.0
	return Color(f.call(i - 1, j), f.call(i + 1, j), f.call(i, j - 1), f.call(i, j + 1))


## Appends cell (i, j) to the arrays, its corners less `centre`.
func _append_cell(verts: PackedVector3Array, uvs: PackedVector2Array, uv2s: PackedVector2Array, cols: PackedColorArray,
		idx: PackedInt32Array, i: int, j: int, centre: Vector2, edges: Color) -> void:
	var tl: Vector2 = _corner(i, j)
	var tr: Vector2 = _corner(i + 1, j)
	var br: Vector2 = _corner(i + 1, j + 1)
	var bl: Vector2 = _corner(i, j + 1)
	var base: int = verts.size()
	for q in [[tl, Vector2(0, 0)], [tr, Vector2(1, 0)], [br, Vector2(1, 1)], [bl, Vector2(0, 1)]]:
		var p: Vector2 = q[0]
		verts.append(Vector3(p.x - centre.x, p.y - centre.y, 0.0))
		uvs.append(_uv(p))
		uv2s.append(q[1])
		cols.append(edges)
	# Clockwise seen from +Z: the front.
	idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func _commit(verts: PackedVector3Array, uvs: PackedVector2Array, uv2s: PackedVector2Array, cols: PackedColorArray,
		idx: PackedInt32Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3(0, 0, 1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _rebuild_sheet() -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in range(_ny):
		for i in range(_nx):
			if _gone[j * _nx + i] == 0:
				_append_cell(verts, uvs, uv2s, cols, idx, i, j, Vector2.ZERO, _torn_side(i, j))
	var mesh := _commit(verts, uvs, uv2s, cols, idx)
	# The flutter moves it a little off its plane.
	mesh.custom_aabb = AABB(Vector3(-size.x * 0.5, lift - 0.2, -0.4), Vector3(size.x, size.y + 0.4, 0.8))
	_sheet.mesh = mesh


# ======================================================================================
#  The frame
# ======================================================================================

func _build_frame() -> void:
	_frame = Node3D.new()
	_frame.name = "Frame"
	add_child(_frame, false, Node.INTERNAL_MODE_BACK)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.93, 0.93, 0.92)
	steel.metallic = 0.4
	steel.roughness = 0.4
	var block := StandardMaterial3D.new()
	block.albedo_color = Color(0.55, 0.55, 0.53)
	block.roughness = 0.9
	var body := StaticBody3D.new()
	body.name = "FrameBody"
	body.set_meta(&"surface", "rock")
	_frame.add_child(body)
	var top: float = lift + size.y + 0.3
	var px: float = size.x * 0.5 + 0.16
	for side in [-1.0, 1.0]:
		var x: float = side * px
		_box(_frame, body, Vector3(x, top * 0.5, 0.0), Vector3(0.2, top, 0.2), steel, Vector3.ZERO)
		_box(_frame, body, Vector3(x + side * 0.1, 0.25, 0.0), Vector3(1.0, 0.5, 1.4), block, Vector3.ZERO)
		# A raking strut to the approach side, outside the post.
		var a := Vector3(x + side * 0.25, 0.4, 2.4)
		var b := Vector3(x, top * 0.62, 0.0)
		var mid: Vector3 = (a + b) * 0.5
		var length: float = a.distance_to(b)
		var tilt: float = atan2(b.z - a.z, b.y - a.y)
		_box(_frame, body, mid, Vector3(0.12, length, 0.12), steel, Vector3(tilt, 0.0, 0.0))
		_box(_frame, body, Vector3(x + side * 0.25, 0.2, 2.4), Vector3(0.6, 0.4, 0.6), block, Vector3.ZERO)
	# The top bar the paper hangs from, and a batten along it that the paper's top is taped under.
	_box(_frame, null, Vector3(0.0, top - 0.05, 0.0), Vector3(size.x + 0.6, 0.18, 0.18), steel, Vector3.ZERO)


func _box(parent: Node3D, body: StaticBody3D, pos: Vector3, sz: Vector3, mat: Material, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	if body != null:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sz
		cs.shape = shape
		cs.position = pos
		cs.rotation = rot
		body.add_child(cs)


# ======================================================================================
#  Tearing
# ======================================================================================

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var inv: Transform3D = global_transform.affine_inverse()
	var seen := {}
	for node in get_tree().get_nodes_in_group("player_carts"):
		var cart := node as Node3D
		if cart == null:
			continue
		var id: int = cart.get_instance_id()
		seen[id] = true
		var now: Vector3 = inv * cart.global_position
		var was: Variant = _prev.get(id)
		_prev[id] = now
		if was == null:
			continue
		var prev: Vector3 = was
		# A respawn or a teleport is no crossing.
		if prev.distance_to(now) > 8.0:
			continue
		if not ((prev.z > 0.0 and now.z <= 0.0) or (prev.z < 0.0 and now.z >= 0.0)):
			continue
		var t: float = prev.z / (prev.z - now.z)
		var p: Vector3 = prev.lerp(now, t)
		if absf(p.x) > size.x * 0.5 + HOLE.x or p.y < lift - HOLE.y or p.y > lift + size.y + HOLE.y:
			continue
		var vel: Vector3 = global_basis * ((now - prev) / maxf(delta, 0.001))
		_tear(Vector2(p.x, p.y), vel)
	for id in _prev.keys():
		if not seen.has(id):
			_prev.erase(id)
	_move_scraps(delta)


## Tears the sheet round local point `h` for a cart moving at `vel` (world).
func _tear(h: Vector2, vel: Vector3) -> void:
	_rng.seed = hash(Vector3i(int(h.x * 100.0), int(h.y * 100.0), Time.get_ticks_msec()))
	var torn := {}
	for j in range(_ny):
		for i in range(_nx):
			var k: int = j * _nx + i
			if _gone[k] != 0:
				continue
			var d: float = ((_cell_centre(i, j) - h) / HOLE).length()
			if d < 0.75 + _cell_jit[k] * 0.55:
				torn[k] = true
	if torn.is_empty():
		return
	# Rips running out of the hole.
	var cw: float = size.x / _nx
	var ch: float = size.y / _ny
	for n in range(_rng.randi_range(SLITS.x, SLITS.y)):
		var ang: float = _rng.randf() * TAU
		var dir := Vector2(cos(ang), sin(ang))
		var reach: float = (dir * HOLE).length()
		var len: float = _rng.randf_range(SLIT_LEN.x, SLIT_LEN.y)
		var t := 0.0
		while t < len:
			var q: Vector2 = h + dir * (reach + t)
			dir = dir.rotated(_rng.randf_range(-0.35, 0.35)).normalized()
			var ci := int(floor((q.x + size.x * 0.5) / cw))
			var cj := int(floor((lift + size.y - q.y) / ch))
			if ci < 0 or cj < 0 or ci >= _nx or cj >= _ny:
				break
			var k2: int = cj * _nx + ci
			if _gone[k2] == 0:
				torn[k2] = true
			t += minf(cw, ch) * 0.5
	for k in torn:
		_gone[k] = 1
	# What the rips cut loose: paper no longer joined to the top bar or a post through paper.
	var held := PackedByteArray()
	held.resize(_nx * _ny)
	held.fill(0)
	var stack: Array[int] = []
	for j in range(_ny):
		for i in range(_nx):
			if (j == 0 or i == 0 or i == _nx - 1) and _gone[j * _nx + i] == 0:
				held[j * _nx + i] = 1
				stack.append(j * _nx + i)
	while not stack.is_empty():
		var k3: int = stack.pop_back()
		var ci2: int = k3 % _nx
		var cj2: int = k3 / _nx
		for nb in [Vector2i(ci2 - 1, cj2), Vector2i(ci2 + 1, cj2), Vector2i(ci2, cj2 - 1), Vector2i(ci2, cj2 + 1)]:
			if nb.x < 0 or nb.y < 0 or nb.x >= _nx or nb.y >= _ny:
				continue
			var kn: int = nb.y * _nx + nb.x
			if _gone[kn] == 0 and held[kn] == 0:
				held[kn] = 1
				stack.append(kn)
	var loose := {}
	for k4 in range(_nx * _ny):
		if _gone[k4] == 0 and held[k4] == 0:
			loose[k4] = true
			_gone[k4] = 1
	for k in torn:
		_spawn_scrap(k, h, vel, false)
	for k in loose:
		_spawn_scrap(k, h, vel, true)
	_rebuild_sheet()
	if _cheer and intact_cells() + torn.size() + loose.size() == _nx * _ny:
		_cheer.play()
	if _sfx:
		_sfx.global_position = global_transform * Vector3(h.x, h.y, 0.0)
		_sfx.pitch_scale = _rng.randf_range(0.9, 1.12)
		_sfx.play()


func _spawn_scrap(k: int, h: Vector2, vel: Vector3, loose: bool) -> void:
	if _scraps.size() >= MAX_SCRAPS:
		return
	var i: int = k % _nx
	var j: int = k / _nx
	var c: Vector2 = _cell_centre(i, j)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	# Every edge it shared with paper is torn.
	var edges := Color(1.0 if i > 0 else 0.0, 1.0 if i < _nx - 1 else 0.0, 1.0 if j > 0 else 0.0, 1.0 if j < _ny - 1 else 0.0)
	_append_cell(verts, uvs, uv2s, cols, idx, i, j, c, edges)
	var mi := MeshInstance3D.new()
	mi.mesh = _commit(verts, uvs, uv2s, cols, idx)
	mi.material_override = _shared_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter(&"flutter", 0.0)
	mi.set_instance_shader_parameter(&"curl", _rng.randf_range(-1.2, 1.2))
	mi.top_level = true
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	mi.global_transform = global_transform * Transform3D(Basis.IDENTITY, Vector3(c.x, c.y, 0.0))
	var out: Vector2 = c - h
	var out3: Vector3 = global_basis * Vector3(out.x, out.y, 0.0).normalized()
	var v: Vector3
	if loose:
		# Cut free by the rips: it drops away with a little of the push.
		v = vel * _rng.randf_range(0.05, 0.2) + out3 * _rng.randf_range(0.2, 1.0)
	else:
		v = vel * _rng.randf_range(0.5, 0.95) + out3 * _rng.randf_range(1.5, 5.5) + Vector3.UP * _rng.randf_range(0.0, 3.0)
	var spin := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(3.0, 11.0)
	_scraps.append({"mi": mi, "vel": v, "spin": spin, "age": 0.0, "life": _rng.randf_range(SCRAP_LIFE.x, SCRAP_LIFE.y),
		"rest": false, "phase": _rng.randf() * TAU, "freq": _rng.randf_range(3.0, 7.0)})


func _move_scraps(delta: float) -> void:
	if _scraps.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var keep: Array = []
	for s in _scraps:
		var mi: MeshInstance3D = s["mi"]
		if not is_instance_valid(mi):
			continue
		s["age"] = float(s["age"]) + delta
		var age: float = s["age"]
		var life: float = s["life"]
		if age > life + SCRAP_SHRINK:
			mi.queue_free()
			continue
		var xf: Transform3D = mi.global_transform
		if not s["rest"]:
			var v: Vector3 = s["vel"]
			v.y -= SCRAP_GRAVITY * delta
			v -= v * minf(SCRAP_DRAG * delta, 1.0)
			var ph: float = float(s["phase"]) + age * float(s["freq"])
			v += Vector3(sin(ph), 0.0, cos(ph * 0.8)) * SCRAP_FLUTTER * delta
			s["vel"] = v
			var to: Vector3 = xf.origin + v * delta
			var q := PhysicsRayQueryParameters3D.create(xf.origin + Vector3.UP * 0.05, to + Vector3.DOWN * 0.03)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty() and not (hit["collider"] as Node).is_in_group("player_carts"):
				# Settles flat on what it fell on, any way round.
				var n: Vector3 = hit["normal"]
				var x: Vector3 = n.cross(Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) + Vector3(0.01, 0, 0)).normalized()
				if x.length_squared() < 0.5:
					x = n.cross(Vector3.FORWARD).normalized()
				var y: Vector3 = n.cross(x)
				xf = Transform3D(Basis(x, y, n), hit["position"] + n * 0.03)
				s["rest"] = true
				mi.set_instance_shader_parameter(&"curl", absf(_rng.randf_range(0.3, 1.0)))
			else:
				var spin: Vector3 = s["spin"]
				if spin.length_squared() > 0.0001:
					xf.basis = Basis(spin.normalized(), spin.length() * delta) * xf.basis
				s["spin"] = spin * maxf(1.0 - 0.4 * delta, 0.0)
				xf.origin = to
				if xf.origin.y < -200.0:
					mi.queue_free()
					continue
		var shrink: float = clampf(1.0 - (age - life) / SCRAP_SHRINK, 0.0, 1.0)
		xf.basis = xf.basis.orthonormalized().scaled(Vector3.ONE * maxf(shrink, 0.001))
		mi.global_transform = xf
		keep.append(s)
	_scraps = keep


## Whole cells still on the frame (for tests).
func intact_cells() -> int:
	var n := 0
	for g in _gone:
		if g == 0:
			n += 1
	return n


func scrap_count() -> int:
	return _scraps.size()


# ======================================================================================
#  Artwork and sound
# ======================================================================================

## Draws the banner's print and saves it as TEXTURE_PATH: the poster (POSTER) across the middle, full height
## between orange bands with white pinstripes, chequered panels on navy either side, mipmapped. The poster is read
## straight from its file, so it needs no import. Run by the generator that places one.
static func bake_texture(sheet := Vector2(17.0, 6.6)) -> Texture2D:
	var w := 2048
	var h := int(round(w * sheet.y / sheet.x))
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var navy := Color8(14, 26, 64)
	var orange := Color8(244, 120, 24)
	var white := Color8(240, 240, 236)
	img.fill(navy)
	var band := int(h * 0.06)
	img.fill_rect(Rect2i(0, 0, w, band), orange)
	img.fill_rect(Rect2i(0, h - band, w, band), orange)
	var pin := maxi(int(h * 0.012), 2)
	img.fill_rect(Rect2i(0, band, w, pin), white)
	img.fill_rect(Rect2i(0, h - band - pin, w, pin), white)
	var y0: int = band + pin
	var y1: int = h - band - pin
	var poster := Image.load_from_file(ProjectSettings.globalize_path(POSTER))
	poster.convert(Image.FORMAT_RGBA8)
	var ph: int = y1 - y0
	var pw: int = mini(int(float(ph) * poster.get_width() / poster.get_height()), w - 200)
	poster.resize(pw, ph, Image.INTERPOLATE_LANCZOS)
	var px: int = (w - pw) / 2
	img.blit_rect(poster, Rect2i(0, 0, pw, ph), Vector2i(px, y0))
	# Pinstripes framing it, and the chequered panels either side.
	img.fill_rect(Rect2i(px - pin, y0, pin, ph), white)
	img.fill_rect(Rect2i(px + pw, y0, pin, ph), white)
	var side_w: int = px - pin - pin
	var rows := 6
	var sq_h: float = float(ph) / rows
	var cols: int = maxi(int(round(side_w / sq_h)), 1)
	var sq_w: float = float(side_w) / cols
	for side in [0, 1]:
		var x0: int = 0 if side == 0 else px + pw + pin + pin
		for r in range(rows):
			for c in range(cols):
				if (r + c + side) % 2 != 0:
					continue
				img.fill_rect(Rect2i(x0 + int(c * sq_w), y0 + int(r * sq_h), int(ceil(sq_w)), int(ceil(sq_h))), white)
		img.fill_rect(Rect2i(px - pin - pin if side == 0 else px + pw + pin, y0, pin, ph), orange)
	img.convert(Image.FORMAT_RGB8)
	img.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	# Kept, or a headless save writes the texture empty (CLAUDE.md, procedural cars).
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	tex.take_over_path(TEXTURE_PATH)
	ResourceSaver.save(tex, TEXTURE_PATH)
	return load(TEXTURE_PATH)


## The rip, made once: the whump of the cart hitting the sheet, then the paper tearing in a crackle of grains.
static func _rip_sound() -> AudioStreamWAV:
	if _rip != null:
		return _rip
	var rate := 22050
	var length := 0.7
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var lp := 0.0
	var lp2 := 0.0
	var phase := 0.0
	var grain := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.25
		var hiss: float = noise - lp
		# The tear: bursts of crackle, thinning out.
		if rng.randf() < 0.012 * exp(-t / 0.35):
			grain = rng.randf_range(0.6, 1.0)
		grain *= 0.993
		var tear: float = hiss * (0.25 + grain) * exp(-t / 0.28) * minf(t / 0.004, 1.0)
		# The whump: a soft low thud as the paper takes the hit.
		phase += TAU * lerpf(110.0, 55.0, minf(t / 0.05, 1.0)) / rate
		lp2 += (noise - lp2) * 0.05
		var whump: float = (sin(phase) * 0.7 + lp2 * 1.5) * exp(-t / 0.045)
		var v: float = tear * 0.75 + whump * 0.6
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	_rip = AudioStreamWAV.new()
	_rip.format = AudioStreamWAV.FORMAT_16_BITS
	_rip.mix_rate = rate
	_rip.data = data
	return _rip
