@tool
extends Node3D
## An item box: a hologram cube of glass (item_box_glass.gdshader) with a gold "?" floating in it that
## turns to face the camera (item_box_glyph), inside a soap bubble (item_box_bubble), with sparkles
## drifting round it (item_box_sparkles) and a glow on the ground under it (item_box_glow). The look is
## built here as internal children, shared meshes and materials for every box, so level files only store
## the box's transform. Once the level's collision exists the box finds the ground under it, hovers
## HOVER over it and lays its glow there. Its light is divided by the level's exposure.
## Taken, it bursts (`pop`); while it is away the ring on the ground fills round (`charge`), and it comes
## back built up from the bottom (`build`). These are per-box shader instance parameters.

@onready var area = $Area3D
@onready var visuals = $Visuals
@onready var sfx_pickup = $SFX_Pickup

var is_active = true
var respawn_timer = 0.0
const RESPAWN_TIME = 5.0

const SFX_PICKUP_SOUND = preload("res://sounds/item_box_pickup.wav")
const GLASS_SHADER := preload("res://item_box_glass.gdshader")
const GLYPH_SHADER := preload("res://item_box_glyph.gdshader")
const BUBBLE_SHADER := preload("res://item_box_bubble.gdshader")
const SPARKLE_SHADER := preload("res://item_box_sparkles.gdshader")
const GLOW_SHADER := preload("res://item_box_glow.gdshader")

const CUBE := 1.5             # edge of the glass cube
const GLYPH_HEIGHT := 1.02    # the "?", dot included
const GLYPH_TUBE := 0.082     # its stroke's radius, in glyph heights
const BUBBLE_RADIUS := 1.18
const SPARKS := 56
const GLOW_SIZE := 3.4
const HOVER := 1.45           # cube centre over the ground
const MAX_SEAT_SHIFT := 0.9   # how far the visuals may move off the node to hover, inside the 2.5m pickup area
const SPIN := 0.9             # rad/s
const TILT := 0.09            # the cube's tumble, radians
const BOB := 0.12
const BUILD_TIME := 0.6
const POP_TIME := 0.5

static var _meshes := {}
static var _materials := {}

var _shell: MeshInstance3D
var _glyph: MeshInstance3D
var _bubble: MeshInstance3D
var _sparks: MeshInstance3D
var _glow: MeshInstance3D
var _base_y := 0.25
var _phase := -1.0
var _build := 0.0
var _pop := 1.0
var _away := 0.0


func _ready():
	_build_visuals()
	if Engine.is_editor_hint():
		return
	add_to_group("item_boxes")
	area.body_entered.connect(_on_body_entered)
	if sfx_pickup:
		sfx_pickup.bus = &"SFX"
		sfx_pickup.stream = SFX_PICKUP_SOUND
	_apply_build()
	_settle()


func _process(delta):
	if Engine.is_editor_hint():
		return
	if _phase < 0.0:
		# Levels place a box after adding it, so its position is only known from the first frame.
		_phase = fposmod(global_position.x * 0.173 + global_position.z * 0.097, 1.0)
		for mi in [_shell, _glyph, _bubble, _sparks, _glow]:
			mi.set_instance_shader_parameter("phase", _phase)
	var t := Time.get_ticks_msec() * 0.001
	visuals.rotate_y(delta * SPIN)
	visuals.position.y = _base_y + sin(t * 1.8 + _phase * TAU) * BOB
	_shell.rotation = Vector3(sin(t * 0.9 + _phase * 7.0) * TILT, 0.0, cos(t * 0.7 + _phase * 5.0) * TILT)

	if is_active:
		if _build < 1.0:
			_build = minf(_build + delta / BUILD_TIME, 1.0)
			_apply_build()
	else:
		if _pop < 1.0:
			_pop = minf(_pop + delta / POP_TIME, 1.0)
			_apply_pop()
			if _pop >= 1.0:
				visuals.visible = false
		_away += delta
		_glow.set_instance_shader_parameter("charge", clampf(_away / RESPAWN_TIME, 0.0, 1.0))

	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return

	if not is_active:
		respawn_timer -= delta
		if respawn_timer <= 0:
			if multiplayer.multiplayer_peer != null:
				_activate_rpc.rpc()
			else:
				_activate_rpc()


func _apply_build() -> void:
	var grow := _ease_out_back(_build)
	_shell.scale = Vector3.ONE * lerpf(0.8, 1.0, grow)
	_bubble.scale = Vector3.ONE * lerpf(0.5, 1.0, grow)
	_glyph.scale = Vector3.ONE * maxf(_ease_out_back(clampf((_build - 0.3) / 0.7, 0.0, 1.0)), 0.001)
	for mi in [_shell, _bubble, _sparks]:
		mi.set_instance_shader_parameter("build", _build)
	_glow.set_instance_shader_parameter("present", _build)


func _apply_pop() -> void:
	var e := 1.0 - pow(1.0 - _pop, 3.0)
	_shell.scale = Vector3.ONE * (1.0 + 0.45 * e)
	_bubble.scale = Vector3.ONE * (1.0 + 0.8 * e)
	_glyph.scale = Vector3.ONE * maxf(1.0 + 0.5 * _pop - 1.5 * _pop * _pop, 0.001)
	_glyph.position.y = 0.7 * e
	for mi in [_shell, _glyph, _bubble, _sparks, _glow]:
		mi.set_instance_shader_parameter("pop", _pop)
	_glow.set_instance_shader_parameter("present", 1.0 - e)


static func _ease_out_back(x: float) -> float:
	const C1 := 1.70158
	return 1.0 + (C1 + 1.0) * pow(x - 1.0, 3.0) + C1 * pow(x - 1.0, 2.0)


## Hover over the ground under the box and lay the glow on it, once the level's collision exists.
func _settle() -> void:
	await get_tree().physics_frame
	# The hologram gives off its own light: keep it as bright on screen whatever the level's exposure
	# (Northlight's night runs at 1.45, which bloomed the boxes into white balls).
	var env := get_world_3d().environment
	if env:
		for mat in _materials.values():
			mat.set_shader_parameter("gain", 1.0 / maxf(env.tonemap_exposure, 0.1))
	var level: Node = get_parent()
	while level and not level.is_in_group("level"):
		level = level.get_parent()
	if level and level.has_method("wait_for_collisions"):
		await level.wait_for_collisions()
	if not is_inside_tree():
		return
	# Nudged off the grid lines: a ray straight down one can miss the terrain.
	var from := global_position + Vector3(0.023, 1.0, 0.017)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 7.0, 1)
	q.hit_back_faces = false
	var hit := {}
	for i in 4:
		hit = get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or not (hit.collider is Node and hit.collider.is_in_group("player_carts")):
			break
		var skip: Array[RID] = q.exclude
		skip.append(hit.rid)
		q.exclude = skip
	if hit.is_empty() or (hit.collider is Node and hit.collider.is_in_group("player_carts")):
		return
	_base_y = clampf(hit.position.y + HOVER - global_position.y, -MAX_SEAT_SHIFT, MAX_SEAT_SHIFT)
	var n: Vector3 = hit.normal if hit.normal.y > 0.5 else Vector3.UP
	var side := n.cross(Vector3.FORWARD).normalized()
	_glow.global_transform = Transform3D(Basis(side, n, side.cross(n)), hit.position + n * 0.04)
	_glow.visible = true


func _build_visuals() -> void:
	if _shell:
		return
	if _meshes.is_empty():
		_meshes = {
			"shell": _shell_mesh(),
			"glyph": _glyph_mesh(),
			"bubble": _bubble_mesh(),
			"sparks": _spark_mesh(),
			"glow": _glow_mesh(),
		}
		for key in ["shell", "glyph", "bubble", "sparks", "glow"]:
			var mat := ShaderMaterial.new()
			mat.shader = {"shell": GLASS_SHADER, "glyph": GLYPH_SHADER, "bubble": BUBBLE_SHADER,
					"sparks": SPARKLE_SHADER, "glow": GLOW_SHADER}[key]
			_materials[key] = mat
	_glyph = _part("Glyph", "glyph", visuals, 330.0)
	_shell = _part("Glass", "shell", visuals, 330.0)
	_bubble = _part("Bubble", "bubble", visuals, 140.0)
	_sparks = _part("Sparkles", "sparks", visuals, 100.0)
	# The sparkles are placed by the shader: cover where they fly, the burst included.
	_sparks.custom_aabb = AABB(Vector3(-5.0, -3.0, -5.0), Vector3(10.0, 9.0, 10.0))
	# The "?" turns to the camera, so its box is the space it turns in.
	_glyph.custom_aabb = AABB(Vector3(-0.6, -0.6, -0.6), Vector3(1.2, 1.2, 1.2))
	_glow = _part("GroundGlow", "glow", self, 200.0)
	# Where most boxes' ground is until they find it; in the editor it stays there.
	_glow.position = Vector3(0.0, -1.25, 0.0)
	_glow.visible = Engine.is_editor_hint()


func _part(part_name: String, key: String, parent: Node, reach: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = _meshes[key]
	mi.material_override = _materials[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = reach
	parent.add_child(mi, false, Node.INTERNAL_MODE_BACK)
	return mi


## The cube: six faces, each with UV 0..1 and its index in COLOR.r for the shader's circuit pattern.
static func _shell_mesh() -> ArrayMesh:
	var h := CUBE * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normals := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	for f in 6:
		var n: Vector3 = normals[f]
		var up := Vector3.UP if absf(n.y) < 0.5 else Vector3.FORWARD
		var right := up.cross(n)
		var q := []
		for c in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			q.append([n * h + right * (c.x * 2.0 - 1.0) * h + up * (1.0 - c.y * 2.0) * h, n, c])
		st.set_color(Color(f / 6.0, 0, 0))
		_tri(st, q[0], q[1], q[2])
		_tri(st, q[0], q[2], q[3])
	return st.commit()


## The "?": a tube swept along the hook and stem (an arc over the top, then a curve into the stem), with
## round caps on both ends, and a ball for the dot. Built in glyph heights, centred on the origin, facing
## +z, and scaled to GLYPH_HEIGHT.
static func _glyph_mesh() -> ArrayMesh:
	var path: Array[Vector2] = []
	var centre := Vector2(0.0, 0.7)
	var r := 0.2
	for i in 23:
		var a := deg_to_rad(lerpf(200.0, -40.0, i / 22.0))
		path.append(centre + Vector2(cos(a), sin(a)) * r)
	var p0 := path[-1]
	var a1 := deg_to_rad(-40.0)
	var p1 := p0 + Vector2(sin(a1), -cos(a1)) * 0.09
	var p2 := Vector2(0.0, 0.46)
	var p3 := Vector2(0.0, 0.33)
	for i in range(1, 11):
		path.append(p0.bezier_interpolate(p1, p2, p3, i / 10.0))
	var seg := 12
	var rw := GLYPH_TUBE
	var rd := GLYPH_TUBE * 0.85
	var to_m := func(p: Vector2) -> Vector3:
		return Vector3(p.x, p.y - 0.5, 0.0) * GLYPH_HEIGHT
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := []
	for i in path.size():
		var t := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		rings.append(_glyph_ring(to_m.call(path[i]), Vector3(-t.y, t.x, 0.0), 1.0, Vector3.ZERO, 0.0, seg, rw, rd))
	for i in path.size() - 1:
		_join(st, rings[i], rings[i + 1])
	# Round caps: rings shrinking to a point beyond each end.
	for end in [0, path.size() - 1]:
		var t := (path[1] - path[0]).normalized() if end == 0 else (path[end] - path[end - 1]).normalized()
		var out := Vector3(t.x, t.y, 0.0) * (-1.0 if end == 0 else 1.0)
		var prev: Array = rings[end]
		for k in range(1, 5):
			var phi := k / 4.0 * PI * 0.5
			var ring := _glyph_ring(to_m.call(path[end]) + out * sin(phi) * rw * GLYPH_HEIGHT, Vector3(-t.y, t.x, 0.0),
					cos(phi), out, sin(phi), seg, rw, rd)
			_join(st, prev, ring)
			prev = ring
	# The dot.
	var dot_c := to_m.call(Vector2(0.0, 0.12)) as Vector3
	var dr := rw * 1.3
	var lat_rings := []
	for i in 9:
		var phi := lerpf(-PI * 0.5, PI * 0.5, i / 8.0)
		var ring := []
		for j in seg:
			var a := TAU * j / seg
			var d := Vector3(cos(phi) * cos(a), sin(phi), cos(phi) * sin(a))
			ring.append([dot_c + Vector3(d.x * dr, d.y * dr, d.z * dr * 0.85) * GLYPH_HEIGHT,
					Vector3(d.x, d.y, d.z / 0.85).normalized()])
		lat_rings.append(ring)
	for i in 8:
		_join(st, lat_rings[i], lat_rings[i + 1])
	return st.commit()


## A ring of the glyph's tube round `c`: `side` is the in-plane normal, z the depth. `shrink` and the
## `out` direction with weight `bend` shape the end caps.
static func _glyph_ring(c: Vector3, side: Vector3, shrink: float, out: Vector3, bend: float, seg: int,
		rw: float, rd: float) -> Array:
	var ring := []
	for j in seg:
		var a := TAU * j / seg
		var off := side * cos(a) * rw + Vector3.BACK * sin(a) * rd
		var n := (side * cos(a) / rw + Vector3.BACK * sin(a) / rd).normalized()
		ring.append([c + off * shrink * GLYPH_HEIGHT, (n * sqrt(maxf(1.0 - bend * bend, 0.0)) + out * bend).normalized()])
	return ring


## Joins two rings of [position, normal] (same count, closed) with quads.
static func _join(st: SurfaceTool, ra: Array, rb: Array) -> void:
	var n := ra.size()
	for j in n:
		var k := (j + 1) % n
		_tri(st, ra[j], rb[j], rb[k])
		_tri(st, ra[j], rb[k], ra[k])


## A triangle of [position, normal(, uv)] vertices, wound so its front faces the way its normals point:
## Godot's front faces are clockwise, with (c - a) x (b - a) out of them.
static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var fn: Vector3 = (c[0] - a[0]).cross(b[0] - a[0])
	if fn.dot(a[1] + b[1] + c[1]) < 0.0:
		var s := b
		b = c
		c = s
	for v in [a, b, c]:
		st.set_normal(v[1])
		if v.size() > 2:
			st.set_uv(v[2])
		st.add_vertex(v[0])


static func _bubble_mesh() -> Mesh:
	var m := SphereMesh.new()
	m.radius = BUBBLE_RADIUS
	m.height = BUBBLE_RADIUS * 2.0
	m.radial_segments = 32
	m.rings = 16
	return m


## SPARKS quads, all at the origin: the shader places them. COLOR.rgb seeds a sparkle, COLOR.a picks its
## colour, UV is the corner.
static func _spark_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in SPARKS:
		var seeds := Color(rng.randf(), rng.randf(), rng.randf(), (i % 5 + 0.5) / 5.0)
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(seeds)
			st.set_uv(corners[k])
			st.add_vertex(Vector3((corners[k].x - 0.5) * 0.1, (corners[k].y - 0.5) * 0.1, 0.0))
	return st.commit()


static func _glow_mesh() -> Mesh:
	var m := PlaneMesh.new()
	m.size = Vector2(GLOW_SIZE, GLOW_SIZE)
	return m


func _on_body_entered(body):
	if not is_active: return

	if body.is_in_group("player_carts"):
		if body.get("is_finished_race") == true:
			return
		var is_colliding_racer = body.is_local_player or (body.get("is_ai") and (multiplayer.multiplayer_peer == null or multiplayer.is_server()))
		if is_colliding_racer:
			if body.has_method("give_item_rpc"):
				if multiplayer.multiplayer_peer == null or multiplayer.is_server():
					_server_process_pickup(body)
				else:
					request_pickup.rpc_id(1, body.name.to_int())

@rpc("any_peer", "call_local", "reliable")
func request_pickup(player_id: int):
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server(): return
	if not is_active: return

	var body = null
	for cart in get_tree().get_nodes_in_group("player_carts"):
		if cart.name == str(player_id):
			body = cart
			break

	if body and body.has_method("give_item_rpc"):
		_server_process_pickup(body)

func _server_process_pickup(body):
	if body.has_method("give_item_rpc"):
		var item_type = body._get_random_item_rpc()
		if body.get("is_ai"):
			body.give_item(item_type)
		else:
			if multiplayer.multiplayer_peer != null and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
				body.give_item_rpc.rpc_id(body.name.to_int(), item_type)
			else:
				body.give_item(item_type)
		if multiplayer.multiplayer_peer != null:
			_deactivate_rpc.rpc()
		else:
			_deactivate_rpc()

@rpc("authority", "call_local", "reliable")
func _deactivate_rpc():
	is_active = false
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		respawn_timer = RESPAWN_TIME
	if sfx_pickup: sfx_pickup.play()
	_pop = 0.0
	_away = 0.0
	_glow.set_instance_shader_parameter("charge", 0.0)

@rpc("authority", "call_local", "reliable")
func _activate_rpc():
	is_active = true
	visuals.visible = true
	_pop = 0.0
	for mi in [_shell, _glyph, _bubble, _sparks]:
		mi.set_instance_shader_parameter("pop", 0.0)
	_glyph.position.y = 0.0
	_build = 0.0
	_apply_build()
