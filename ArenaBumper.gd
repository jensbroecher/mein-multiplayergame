@tool
extends Node3D
## A pinball bumper for the arenas (ArenaGame.gd's levels): a round post (`bar_length` 0) or a straight slingshot bar
## along local x (its face toward -z), with a rubber ring that lights up and a pop when something hits it. A cart
## that touches it (the cart this peer drives, so every peer bumps its own) is flung off at at least `kick` m/s, a
## little up; a ball (the host's) too. It builds its body and meshes as internal children from its exports, so a
## level stores only the transform and the sizes.

@export var radius := 1.7:
	set(v):
		radius = v
		_rebuild()
@export var height := 1.5:
	set(v):
		height = v
		_rebuild()
## 0: a round post. Over 0: a slingshot bar this long along x, pushing toward -z.
@export var bar_length := 0.0:
	set(v):
		bar_length = v
		_rebuild()
@export var kick := 17.0
@export var color := Color(1.0, 0.3, 0.75):
	set(v):
		color = v
		_rebuild()

const REACH := 1.45
const COOLDOWN := 0.3
const FLASH_TIME := 0.25

static var _pop: AudioStreamWAV

var _ring_mat: StandardMaterial3D
var _last := {}
var _flash := 0.0
var _sfx: AudioStreamPlayer3D
var _built: Node3D


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = _pop_sound()
	_sfx.bus = &"SFX"
	_sfx.unit_size = 10.0
	_sfx.max_distance = 120.0
	add_child(_sfx, false, Node.INTERNAL_MODE_BACK)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _built != null:
		_built.queue_free()
	_built = Node3D.new()
	add_child(_built, false, Node.INTERNAL_MODE_BACK)
	var body := StaticBody3D.new()
	body.name = "BumperBody"
	body.set_meta(&"surface", "rock")
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.6
	body.physics_material_override = pm
	_built.add_child(body)
	var shape := CollisionShape3D.new()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.12, 0.13, 0.16)
	dark.metallic = 0.6
	dark.roughness = 0.35
	var cap := StandardMaterial3D.new()
	cap.albedo_color = Color(0.95, 0.95, 0.97)
	cap.roughness = 0.25
	cap.emission_enabled = true
	cap.emission = color * 0.3
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = color
	_ring_mat.emission_enabled = true
	_ring_mat.emission = color
	_ring_mat.emission_energy_multiplier = 1.2
	_ring_mat.roughness = 0.4
	if bar_length <= 0.0:
		var cs := CylinderShape3D.new()
		cs.radius = radius
		cs.height = height + 1.0
		shape.shape = cs
		shape.position = Vector3(0, (height + 1.0) * 0.5 - 0.5, 0)
		_add_cyl(radius * 0.92, radius * 1.05, height * 0.45, height * 0.225, dark)
		_add_cyl(radius, radius, height * 0.35, height * 0.62, _ring_mat)
		_add_cyl(radius * 0.7, radius * 0.95, height * 0.2, height * 0.9, cap)
	else:
		var bs := BoxShape3D.new()
		bs.size = Vector3(bar_length, height + 1.0, radius)
		shape.shape = bs
		shape.position = Vector3(0, (height + 1.0) * 0.5 - 0.5, 0)
		_add_box(Vector3(bar_length, height * 0.5, radius * 0.9), Vector3(0, height * 0.25, 0.05), dark)
		_add_box(Vector3(bar_length, height * 0.38, radius * 0.25), Vector3(0, height * 0.62, -radius * 0.4), _ring_mat)
		_add_box(Vector3(bar_length, height * 0.15, radius * 0.9), Vector3(0, height * 0.88, 0.05), cap)
	body.add_child(shape)


func _add_cyl(top: float, bottom: float, h: float, y: float, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 28
	mi.mesh = cm
	mi.position = Vector3(0, y, 0)
	mi.material_override = m
	_built.add_child(mi)


func _add_box(size: Vector3, at: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = at
	mi.material_override = m
	_built.add_child(mi)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_ring_mat.emission_energy_multiplier = 1.2 + 7.0 * (_flash / FLASH_TIME)
	var now := Time.get_ticks_msec() * 0.001
	for cart in get_tree().get_nodes_in_group("player_carts"):
		var body := cart as RigidBody3D
		if body == null or not body.has_method("has_physics_authority") or not body.has_physics_authority():
			continue
		var n := _push_dir(body.global_position, REACH)
		if n == Vector3.ZERO:
			continue
		var key := body.get_instance_id()
		if now - float(_last.get(key, -10.0)) < COOLDOWN:
			continue
		_last[key] = now
		var v := body.linear_velocity
		var along := v.dot(n)
		v += n * (maxf(kick, -along * 0.9) - along)
		v.y = maxf(v.y, 3.0)
		if body.has_method("arena_launch"):
			body.arena_launch(v)
		else:
			body.linear_velocity = v
		_hit()
	var host := multiplayer.multiplayer_peer == null or multiplayer.is_server()
	if host:
		for ball in get_tree().get_nodes_in_group("kick_balls"):
			var rb := ball as RigidBody3D
			if rb == null or not rb.visible or rb.get("remote_driven"):
				continue
			var n := _push_dir(rb.global_position, 1.2)
			if n == Vector3.ZERO:
				continue
			var key := rb.get_instance_id()
			if now - float(_last.get(key, -10.0)) < COOLDOWN:
				continue
			_last[key] = now
			var v := rb.linear_velocity
			v += n * (maxf(kick * 1.15, -v.dot(n)) - v.dot(n))
			v.y = maxf(v.y, 4.0)
			rb.linear_velocity = v
			_hit()


## Away from the bumper in the plan, for something at `p` within `reach` of its face (zero for anything further).
func _push_dir(p: Vector3, reach: float) -> Vector3:
	var lp := to_local(p)
	if lp.y < -1.0 or lp.y > height + 2.0:
		return Vector3.ZERO
	if bar_length <= 0.0:
		var flat := Vector2(lp.x, lp.z)
		if flat.length() > radius + reach or flat.length() < 0.01:
			return Vector3.ZERO
		return (global_transform.basis * Vector3(flat.x, 0, flat.y)).normalized() * Vector3(1, 0, 1)
	if absf(lp.x) > bar_length * 0.5 + 0.5 or lp.z > radius * 0.5 or lp.z < -radius * 0.5 - reach:
		return Vector3.ZERO
	var n := global_transform.basis * Vector3(0, 0, -1)
	n.y = 0.0
	return n.normalized()


func _hit() -> void:
	_flash = FLASH_TIME
	if _sfx:
		_sfx.pitch_scale = randf_range(0.92, 1.1)
		_sfx.play()


## A pinball bumper's pop, made once: a quick rising chirp over a click.
static func _pop_sound() -> AudioStreamWAV:
	if _pop != null:
		return _pop
	var rate := 22050
	var n := int(rate * 0.22)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var f := lerpf(520.0, 1350.0, minf(t / 0.05, 1.0))
		phase += TAU * f / rate
		var v := (sin(phase) * 0.7 + sin(phase * 2.01) * 0.25) * exp(-t / 0.06)
		v += (randf() * 2.0 - 1.0) * exp(-t / 0.004) * 0.6
		data.encode_s16(i * 2, int(clampf(v * 0.75, -1.0, 1.0) * 32767.0))
	_pop = AudioStreamWAV.new()
	_pop.format = AudioStreamWAV.FORMAT_16_BITS
	_pop.mix_rate = rate
	_pop.data = data
	return _pop
