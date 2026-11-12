@tool
extends Node3D
## A launch fan for the arenas (ArenaGame.gd's levels): a round grate flush with the ground over a propeller that
## spins in a well, wind streaks rising off it. Drive over it and it blasts you up at `launch` m/s, carried on toward
## the node's -z by `push` (a launch onto a ledge is aimed so). Every peer launches the cart it drives; the host the
## balls. Built from its exports as internal children: a level stores the transform and the sizes. It has no collider:
## the ground under it is the level's.

@export var radius := 3.4:
	set(v):
		radius = v
		_rebuild()
@export var launch := 21.0
@export var push := 0.0
## Over zero: an aimed fan. A car is thrown to land here (in the fan's own space: a ledge, a deck) whatever way it came
## in: up at `launch`, on across at whatever speed the flight's time needs (the carts fall at CART_G).
@export var land_at := Vector3.ZERO
@export var color := Color(0.3, 0.9, 1.0):
	set(v):
		color = v
		_rebuild()

const COOLDOWN := 1.2
## A cart's fall in the air: the world's gravity and PlayerCart's GRAVITY on top.
const CART_G := 39.8
const HOLD := 2.5
## A cart keeps about this share of the launch (its first moments off the ground take the rest): the flight is timed
## by it.
const LAUNCH_KEPT := 0.85

static var _whoosh: AudioStreamWAV

var _rotor: Node3D
## Cars an aimed fan is carrying: [body, its horizontal velocity, seconds left]. A cart's own grip, for its first
## moments off the ground, would otherwise eat the speed across the flight needs.
var _carry: Array = []
var _last := {}
var _sfx: AudioStreamPlayer3D
var _built: Node3D


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	_sfx = AudioStreamPlayer3D.new()
	_sfx.stream = _whoosh_sound()
	_sfx.bus = &"SFX"
	_sfx.unit_size = 10.0
	_sfx.max_distance = 140.0
	add_child(_sfx, false, Node.INTERNAL_MODE_BACK)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _built != null:
		_built.queue_free()
	_built = Node3D.new()
	add_child(_built, false, Node.INTERNAL_MODE_BACK)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.22, 0.23, 0.26)
	steel.metallic = 0.7
	steel.roughness = 0.35
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 1.6
	var pit := StandardMaterial3D.new()
	pit.albedo_color = Color(0.03, 0.03, 0.04)
	# The well: a dark disc just under the grate, the rim's glowing ring round it.
	var well := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = radius
	wm.bottom_radius = radius
	wm.height = 0.04
	wm.radial_segments = 40
	well.mesh = wm
	well.position = Vector3(0, 0.025, 0)
	well.material_override = pit
	_built.add_child(well)
	var rim := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = radius - 0.12
	rm.outer_radius = radius + 0.35
	rm.rings = 48
	rm.ring_segments = 6
	rim.mesh = rm
	rim.scale = Vector3(1, 0.3, 1)
	rim.position = Vector3(0, 0.06, 0)
	rim.material_override = glow
	_built.add_child(rim)
	# The propeller under the grate.
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 0.07, 0)
	_built.add_child(_rotor)
	for k in 4:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(radius * 0.9, 0.04, radius * 0.28)
		blade.mesh = bm
		blade.material_override = steel
		blade.position = Vector3(cos(k * PI * 0.5), 0, sin(k * PI * 0.5)) * radius * 0.47
		blade.rotation = Vector3(0.35, -k * PI * 0.5, 0)
		_rotor.add_child(blade)
	# The grate: bars across, flush with the ground.
	var bars := int(radius * 2.0 / 0.5)
	for i in bars:
		var x := -radius + (i + 0.5) * radius * 2.0 / bars
		var half := sqrt(maxf(radius * radius - x * x, 0.0))
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.06, half * 2.0)
		bar.mesh = bm
		bar.position = Vector3(x, 0.1, 0)
		bar.material_override = steel
		_built.add_child(bar)
	# Wind streaks rising off it.
	var wind := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 1.1
	cm.bottom_radius = radius * 0.95
	cm.height = 9.0
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 24
	wind.mesh = cm
	wind.position = Vector3(0, 4.6, 0)
	var sh := Shader.new()
	sh.code = WIND_SHADER
	var wmat := ShaderMaterial.new()
	wmat.shader = sh
	wmat.set_shader_parameter("color", color)
	wind.material_override = wmat
	wind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_built.add_child(wind)


const WIND_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 color : source_color = vec3(0.3, 0.9, 1.0);
void fragment() {
	float a = UV.x * 24.0;
	float streak = smoothstep(0.82, 1.0, sin(a * 6.2831) * 0.5 + 0.5);
	float rise = fract(UV.y * 2.0 + TIME * 1.6 + floor(a) * 0.37);
	float fade = (1.0 - UV.y) * UV.y * 4.0;
	ALBEDO = color * streak * smoothstep(0.0, 0.3, rise) * (1.0 - rise) * fade * 0.55;
}
"""


func _process(delta: float) -> void:
	if _rotor != null:
		_rotor.rotate_y(delta * 18.0)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var now := Time.get_ticks_msec() * 0.001
	for i in range(_carry.size() - 1, -1, -1):
		var c: Array = _carry[i]
		c[2] = float(c[2]) - _delta
		var b := c[0] as RigidBody3D
		# Until it lands (after the first moments, still on the fan's grate) or runs out.
		if c[2] <= 0.0 or not is_instance_valid(b) or (c[2] < HOLD - 0.3 and bool(b.get("is_on_ground"))):
			_carry.remove_at(i)
			continue
		var hv: Vector3 = c[1]
		b.linear_velocity = Vector3(hv.x, b.linear_velocity.y, hv.z)
	var fwd := global_transform.basis * Vector3(0, 0, -1)
	fwd.y = 0.0
	fwd = fwd.normalized()
	for cart in get_tree().get_nodes_in_group("player_carts"):
		var body := cart as RigidBody3D
		if body == null or not body.has_method("has_physics_authority") or not body.has_physics_authority():
			continue
		if _over(body.global_position, 3.0):
			var key := body.get_instance_id()
			if now - float(_last.get(key, -10.0)) < COOLDOWN:
				continue
			_last[key] = now
			var v := body.linear_velocity
			v.y = launch
			v += fwd * push
			if land_at != Vector3.ZERO:
				v = _aimed(body.global_position)
				_carry.append([body, Vector3(v.x, 0, v.z), HOLD])
			if body.has_method("arena_launch"):
				body.arena_launch(v)
			else:
				body.linear_velocity = v
			_blow()
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		for ball in get_tree().get_nodes_in_group("kick_balls"):
			var rb := ball as RigidBody3D
			if rb == null or not rb.visible or rb.get("remote_driven") or not _over(rb.global_position, 3.5):
				continue
			var key := rb.get_instance_id()
			if now - float(_last.get(key, -10.0)) < COOLDOWN:
				continue
			_last[key] = now
			rb.linear_velocity = Vector3(rb.linear_velocity.x, launch * 0.85, rb.linear_velocity.z) + fwd * push
			_blow()


## The velocity that carries a cart from `from` up at `launch` and down onto `land_at`.
func _aimed(from: Vector3) -> Vector3:
	var to := to_global(land_at)
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var up := launch * LAUNCH_KEPT
	var apex := up * up / (2.0 * CART_G)
	var drop := maxf(apex - (to.y + 0.8 - from.y), 0.5)
	var t := up / CART_G + sqrt(2.0 * drop / CART_G)
	return flat / t + Vector3.UP * launch


func _over(p: Vector3, up: float) -> bool:
	var lp := to_local(p)
	return Vector2(lp.x, lp.z).length() < radius and lp.y > -0.5 and lp.y < up


func _blow() -> void:
	if _sfx:
		_sfx.pitch_scale = randf_range(0.9, 1.08)
		_sfx.play()


## A launch fan's blast, made once: a burst of noise swelling and rising in pitch.
static func _whoosh_sound() -> AudioStreamWAV:
	if _whoosh != null:
		return _whoosh
	var rate := 22050
	var n := int(rate * 0.7)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	var bp := 0.0
	for i in n:
		var t := float(i) / rate
		var k := lerpf(0.05, 0.35, minf(t / 0.25, 1.0))
		lp += (randf() * 2.0 - 1.0 - lp) * k
		bp += (lp - bp) * 0.5
		var env := minf(t / 0.06, 1.0) * exp(-maxf(t - 0.15, 0.0) / 0.18)
		data.encode_s16(i * 2, int(clampf((lp - bp) * 2.2 * env, -1.0, 1.0) * 32767.0))
	_whoosh = AudioStreamWAV.new()
	_whoosh.format = AudioStreamWAV.FORMAT_16_BITS
	_whoosh.mix_rate = rate
	_whoosh.data = data
	return _whoosh
