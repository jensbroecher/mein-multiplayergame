@tool
extends Node3D
## An item box: a holographic globe of glass (item_box_orb.gdshader; the cube it used to be,
## item_box_glass.gdshader, is kept behind SHELL) with the symbol of the item it holds
## floating in it, a glowing white outline (ItemSymbols.gd, item_box_glyph) that turns to face the
## camera, with sparkles drifting round it (item_box_sparkles) and a glow on the ground under it
## (item_box_glow). What it shows is what it gives: the server picks the item (roll_item) whenever the
## box comes back and tells every peer (_activate_rpc), and a pickup hands over that item. For the first
## START_BOOST_ONLY_SECONDS of a race every box holds a boost (the grid is still bunched up, and one
## bomb or missile could take out half of it); then the boxes still standing are picked again. The one
## exception: a racer in last place always gets a boost. The look is
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
const ItemSymbols = preload("res://ItemSymbols.gd")
## PlayerCart.ItemType: NONE 0, then ItemSymbols.NAMES in order from 1.
const BOOST := 1
const START_BOOST_ONLY_SECONDS := 10.0
## Weighted draw: boosts three times as likely as each of the others.
const ITEM_POOL := [1, 1, 1, 2, 3, 4, 5, 6, 7]
const GLASS_SHADER := preload("res://item_box_glass.gdshader")
const ORB_SHADER := preload("res://item_box_orb.gdshader")
## The glass's shape: a holographic globe (item_box_orb), or the cube it was (item_box_glass). Both are
## kept; switch here.
enum Shell { CUBE, SPHERE }
const SHELL := Shell.SPHERE
const ORB_RADIUS := 0.92
const GLYPH_SHADER := preload("res://item_box_glyph.gdshader")
const SPARKLE_SHADER := preload("res://item_box_sparkles.gdshader")
const GLOW_SHADER := preload("res://item_box_glow.gdshader")

const CUBE := 1.5             # edge of the glass cube
const GLYPH_HEIGHT := 1.15    # the symbols' square, in metres
const GLYPH_TUBE := 0.045     # their strokes' radius, in glyph heights
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
## Until when (Time.get_ticks_msec) the boxes hold boosts only: set by Level at the green light, and
## forever before it.
static var boost_only_until := INF

## The item this box holds (PlayerCart.ItemType).
var item := BOOST

var _shell: MeshInstance3D
var _glyph: MeshInstance3D
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
	# A box that turns up after the boost-only start (the finish line's, 10s in) gets its own item.
	if (multiplayer.multiplayer_peer == null or multiplayer.is_server()) and Time.get_ticks_msec() >= boost_only_until:
		server_reroll.call_deferred()


## The server's draw for a box: a boost during the start, otherwise from ITEM_POOL.
static func roll_item() -> int:
	if Time.get_ticks_msec() < boost_only_until:
		return BOOST
	return ITEM_POOL[randi() % ITEM_POOL.size()]


## Server: picks this box's item again (the end of the boost-only start) and tells every peer.
func server_reroll() -> void:
	if not is_active or not is_inside_tree():
		return
	if multiplayer.multiplayer_peer != null:
		_set_item_rpc.rpc(roll_item())
	else:
		_set_item_rpc(roll_item())


@rpc("authority", "call_local", "reliable")
func _set_item_rpc(it: int) -> void:
	_show_item(it)
	# The new symbol grows in.
	_build = minf(_build, 0.3)
	_apply_build()


func _show_item(it: int) -> void:
	item = clampi(it, 1, ItemSymbols.NAMES.size())
	if _glyph:
		_glyph.mesh = _meshes["glyph_%d" % item]


func _process(delta):
	if Engine.is_editor_hint():
		return
	if _phase < 0.0:
		# Levels place a box after adding it, so its position is only known from the first frame.
		_phase = fposmod(global_position.x * 0.173 + global_position.z * 0.097, 1.0)
		for mi in [_shell, _glyph, _sparks, _glow]:
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
				_activate_rpc.rpc(roll_item())
			else:
				_activate_rpc(roll_item())


func _apply_build() -> void:
	var grow := _ease_out_back(_build)
	_shell.scale = Vector3.ONE * lerpf(0.8, 1.0, grow)
	_glyph.scale = Vector3.ONE * maxf(_ease_out_back(clampf((_build - 0.3) / 0.7, 0.0, 1.0)), 0.001)
	for mi in [_shell, _sparks]:
		mi.set_instance_shader_parameter("build", _build)
	_glow.set_instance_shader_parameter("present", _build)


func _apply_pop() -> void:
	var e := 1.0 - pow(1.0 - _pop, 3.0)
	_shell.scale = Vector3.ONE * (1.0 + 0.45 * e)
	_glyph.scale = Vector3.ONE * maxf(1.0 + 0.5 * _pop - 1.5 * _pop * _pop, 0.001)
	_glyph.position.y = 0.7 * e
	for mi in [_shell, _glyph, _sparks, _glow]:
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
	var world := get_world_3d()
	if world == null:
		return
	var env := world.environment
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
			"shell": _shell_mesh() if SHELL == Shell.CUBE else _orb_mesh(),
			"sparks": _spark_mesh(),
			"glow": _glow_mesh(),
		}
		for i in ItemSymbols.NAMES.size():
			_meshes["glyph_%d" % (i + 1)] = _symbol_mesh(ItemSymbols.NAMES[i])
		_meshes["glyph"] = _meshes["glyph_%d" % BOOST]
		for key in ["shell", "glyph", "sparks", "glow"]:
			var mat := ShaderMaterial.new()
			mat.shader = {"shell": GLASS_SHADER if SHELL == Shell.CUBE else ORB_SHADER, "glyph": GLYPH_SHADER,
					"sparks": SPARKLE_SHADER, "glow": GLOW_SHADER}[key]
			_materials[key] = mat
	_glyph = _part("Glyph", "glyph", visuals, 330.0)
	_shell = _part("Glass", "shell", visuals, 330.0)
	_sparks = _part("Sparkles", "sparks", visuals, 100.0)
	# The sparkles are placed by the shader: cover where they fly, the burst included.
	_sparks.custom_aabb = AABB(Vector3(-5.0, -3.0, -5.0), Vector3(10.0, 9.0, 10.0))
	_show_item(item)
	# The symbol turns to the camera, so its box is the space it turns in.
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


## The globe: a UV sphere of ORB_RADIUS, UV x round it (longitude) and y up it (latitude), for
## item_box_orb's grid and traces.
static func _orb_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lon := 40
	var lat := 20
	var pt := func(i: int, j: int) -> Array:
		var a := TAU * i / lon
		var b := lerpf(-PI * 0.5, PI * 0.5, float(j) / lat)
		var n := Vector3(cos(b) * cos(a), sin(b), cos(b) * sin(a))
		return [n * ORB_RADIUS, n, Vector2(float(i) / lon, float(j) / lat)]
	for j in lat:
		for i in lon:
			var q := [pt.call(i, j), pt.call(i + 1, j), pt.call(i + 1, j + 1), pt.call(i, j + 1)]
			_tri(st, q[0], q[1], q[2])
			_tri(st, q[0], q[2], q[3])
	return st.commit()


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


## An item's symbol (ItemSymbols.gd): a tube swept along each stroke, round caps on the open ones,
## mitred at sharp corners, and balls for the dots. Built in metres, centred on the origin, facing +z,
## the symbols' square GLYPH_HEIGHT across.
static func _symbol_mesh(symbol: String) -> ArrayMesh:
	var seg := 10
	var rw := GLYPH_TUBE
	var rd := GLYPH_TUBE * 0.85
	var to_m := func(p: Vector2) -> Vector3:
		return Vector3(p.x, p.y, 0.0) * (GLYPH_HEIGHT * 0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stroke in ItemSymbols.strokes(symbol):
		if stroke.size() > 2:
			# The dot's radius is in the symbols' square (2 across): in glyph heights, half of it.
			_ball(st, to_m.call(stroke[0]), maxf(float(stroke[1]) * 0.5, rw * 1.3), seg)
			continue
		var path: PackedVector2Array = stroke[0]
		var closed: bool = stroke[1]
		var n := path.size()
		var rings := []
		for i in n:
			var prev := path[(i - 1 + n) % n] if (closed or i > 0) else path[i]
			var next := path[(i + 1) % n] if (closed or i < n - 1) else path[i]
			var d_in := (path[i] - prev).normalized() if prev != path[i] else (next - path[i]).normalized()
			var d_out := (next - path[i]).normalized() if next != path[i] else d_in
			var t := (d_in + d_out).normalized() if (d_in + d_out).length() > 0.01 else d_out
			# Mitre: as wide across a corner as along the straights.
			var miter := 1.0 / maxf(t.dot(d_out), 0.5)
			rings.append(_glyph_ring(to_m.call(path[i]), Vector3(-t.y, t.x, 0.0), miter, Vector3.ZERO, 0.0, seg, rw, rd))
		for i in n - 1:
			_join(st, rings[i], rings[i + 1])
		if closed:
			_join(st, rings[n - 1], rings[0])
			continue
		# Round caps: rings shrinking to a point beyond each end.
		for end in [0, n - 1]:
			var t := (path[1] - path[0]).normalized() if end == 0 else (path[end] - path[end - 1]).normalized()
			var out := Vector3(t.x, t.y, 0.0) * (-1.0 if end == 0 else 1.0)
			var prev_ring: Array = rings[end]
			for k in range(1, 5):
				var phi := k / 4.0 * PI * 0.5
				var ring := _glyph_ring(to_m.call(path[end]) + out * sin(phi) * rw * GLYPH_HEIGHT, Vector3(-t.y, t.x, 0.0),
						cos(phi), out, sin(phi), seg, rw, rd)
				_join(st, prev_ring, ring)
				prev_ring = ring
	return st.commit()


## A ball of radius `r` glyph heights at `c` (flattened in depth like the tubes).
static func _ball(st: SurfaceTool, c: Vector3, r: float, seg: int) -> void:
	var lat_rings := []
	for i in 9:
		var phi := lerpf(-PI * 0.5, PI * 0.5, i / 8.0)
		var ring := []
		for j in seg:
			var a := TAU * j / seg
			var d := Vector3(cos(phi) * cos(a), sin(phi), cos(phi) * sin(a))
			ring.append([c + Vector3(d.x * r, d.y * r, d.z * r * 0.85) * GLYPH_HEIGHT, Vector3(d.x, d.y, d.z / 0.85).normalized()])
		lat_rings.append(ring)
	for i in 8:
		_join(st, lat_rings[i], lat_rings[i + 1])


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
		var item_type := item
		# Last place always gets a boost, whatever the box showed: a chance to catch up, without
		# slowing anyone ahead.
		if _is_last_place(body):
			item_type = BOOST
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

func _is_last_place(body: Node) -> bool:
	var level = get_tree().get_first_node_in_group("level")
	if level == null or not level.get("player_stats"):
		return false
	var stats: Dictionary = level.player_stats
	var id := str(body.name).to_int()
	return stats.size() > 1 and stats.has(id) and int(stats[id].get("pos", 0)) == stats.size()


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
func _activate_rpc(it: int = BOOST):
	_show_item(it)
	is_active = true
	visuals.visible = true
	_pop = 0.0
	for mi in [_shell, _glyph, _sparks]:
		mi.set_instance_shader_parameter("pop", 0.0)
	_glyph.position.y = 0.0
	_build = 0.0
	_apply_build()
