extends Node3D
## Eagle AI: glides down, grabs a car, flies up/forward along the road while
## flapping wings (part_4 + part_7), then drops the car over the track.

enum Phase { PATROL, DIVE, GRAB, CARRY, RELEASE, COOLDOWN }

@export_group("Wings")
@export var wing_part_names: PackedStringArray = ["part_4", "part_7"]
## Parts of the model that are hidden: part_8 is a stray feather floating over the head.
@export var hidden_part_names: PackedStringArray = ["part_8"]
## Local axis the wings hinge on at the shoulder (the body's long axis in the model).
@export var wing_hinge_axis: Vector3 = Vector3.RIGHT
## The wings' angle over level (degrees) when gliding: a shallow V, as an eagle soars. The model holds
## them raised steeply; each wing's own angle is measured off it and lowered to this.
@export var glide_dihedral_deg: float = 9.0
## A full beat: the top and bottom of the stroke over level (degrees). The downstroke, the power
## stroke, takes 40% of the beat; the wing twists leading edge down through it.
@export var beat_top_deg: float = 44.0
@export var beat_bottom_deg: float = -36.0
@export var wing_twist_deg: float = 9.0
## Wingbeats per second: heaving a car up, braking over it for the grab, a burst while soaring.
@export var beat_rate_carry: float = 1.5
@export var beat_rate_grab: float = 2.1
@export var beat_rate_soar: float = 1.25
## In the stoop (the dive) the wings are drawn up and back, half closed.
@export var stoop_deg: float = 52.0
## How far it banks into a turn, at most (degrees).
@export var bank_max_deg: float = 24.0

@export_group("Flight")
@export var patrol_height: float = 75.0
@export var dive_speed: float = 54.0
@export var carry_speed: float = 28.0
@export var climb_speed: float = 24.0
@export var flight_smooth: float = 7.5
@export var turn_smooth: float = 6.0
@export var grab_radius: float = 12.0
@export var grab_height_above_car: float = 3.5
## Where the carried cart's middle hangs, in world metres under and ahead of the eagle's origin. The
## model's talons reach down to its origin's height, 0.13 model units behind it (0.85m at the level's 6.5):
## the cart's roof just under them.
@export var carry_hold_below: float = 0.6
@export var carry_hold_forward: float = -0.8
## The cart follows the talons on a critically damped spring at this rate (1/s), from where it was grabbed
## and at the speed it was going: lifted off the road over half a second, swinging a little as the eagle
## turns. It used to jump 3m up into the grip in one frame.
@export var carry_follow_rate: float = 6.5
## The climb eases in over this long after the grab, and the eagle turns its flight from the cart's way onto
## the way to the drop at carry_turn_rate (1/s, flight_smooth's half by the end): a heavy lift.
@export var lift_time: float = 1.3
@export var carry_turn_rate: float = 2.2
## How far the carried cart leans to hang under the talons as it swings (0 upright, 1 fully).
@export var carry_swing: float = 0.6
@export var release_height: float = 64.0
@export var shockwave_push_speed: float = 48.0
@export var shockwave_push_up: float = 18.0
@export var shockwave_stun_time: float = 3.5
@export var drop_along_track: float = 90.0
@export var release_down_speed: float = 8.0
@export var cooldown_time: float = 8.0
@export var patrol_retarget_time: float = 4.0
## Extra yaw so the mesh nose matches flight (many FBX birds face +X or +Z, not -Z).
@export var model_yaw_offset_deg: float = 90.0

@export_group("Hunt")
@export var hunt_only_while_racing: bool = true
## Seconds after race start before the eagle can dive on cars.
@export var hunt_start_delay: float = 20.0
## If true, slightly prefer local player; still often picks AI / other cars at random.
@export var prefer_local_player: bool = false
@export var randomize_targets: bool = true
## A cart going at least this share of its top speed outruns the eagle: it is never picked, and a dive
## on a cart that speeds up to it breaks off.
@export var escape_speed_share: float = 0.88

@export_group("Audio")
@export var scream_volume_db: float = -2.0
@export var flap_volume_db: float = -6.0

var scream_streams: Array[AudioStream] = []
var flap_stream: AudioStream = null

var _phase: int = Phase.PATROL
var _wing_pivots: Array[Node3D] = []
## Which side of the hinge axis each wing reaches out on (+1 / -1), so both beat as a mirrored pair.
var _wing_side: Array[float] = []
## Each wing's angle over level in the model's own pose (radians).
var _wing_rest: Array[float] = []
## Local scale of each wing pivot after reparent (cancels parent FBX scale).
var _wing_pivot_scales: Array[Vector3] = []
## The beat: where in it (0..1, the downstroke first), how much of it shows (0 gliding, 1 full),
## how many beats are left in a burst while soaring, and the time to the next burst.
var _beat_phase: float = 0.0
var _beat_amp: float = 0.0
var _burst_left: int = 0
var _soar_timer: float = 2.0
var _glide_t: float = 0.0
var _pose_deg: float = 9.0
var _bank: float = 0.0

var _target_cart: RigidBody3D = null
## While a cart is locked in the talons: where it is and how fast it goes (the follow spring's state).
var _holding: bool = false
var _cart_pos: Vector3 = Vector3.ZERO
var _cart_vel: Vector3 = Vector3.ZERO
var _carry_time: float = 0.0
var _cooldown_left: float = 0.0
var _patrol_timer: float = 0.0
var _patrol_target: Vector3 = Vector3.ZERO
var _drop_world: Vector3 = Vector3.ZERO
var _home: Vector3 = Vector3.ZERO
var _home_basis: Basis = Basis.IDENTITY
var _last_flat_fwd: Vector3 = Vector3.FORWARD
var _velocity: Vector3 = Vector3.ZERO
var _face_dir_smooth: Vector3 = Vector3.FORWARD
var _sfx_scream: AudioStreamPlayer3D = null
var _sfx_flap: AudioStreamPlayer3D = null
var _scream_played_this_hunt: bool = false
## Counts down only while race is active; hunts blocked until 0.
var _hunt_unlock_left: float = 20.0
var _was_racing: bool = false


func _ready() -> void:
	# The level generator runs this too: the wing pivots and sound players it adds are saved into the
	# level, and at runtime the model's own wings came back beside them (two eagles, one in another).
	if Engine.is_editor_hint() or _in_generator():
		set_physics_process(false)
		return
	add_to_group("eagles")
	_home = global_position
	_home_basis = global_basis.orthonormalized()
	_setup_audio()
	for n in hidden_part_names:
		var part := _find_desc_named(self, str(n)) as Node3D
		if part:
			part.visible = false
	_setup_wings()
	_phase = Phase.PATROL
	_patrol_timer = 0.5
	_patrol_target = _high_point_near_track(0.0)
	_hunt_unlock_left = maxf(0.0, hunt_start_delay)
	_was_racing = false
	# Start high
	global_position = _patrol_target
	set_physics_process(true)


func _in_generator() -> bool:
	for child in get_tree().root.get_children():
		if "regenerate" in str(child.name).to_lower():
			return true
	return false


func _setup_audio() -> void:
	scream_streams = [
		load("res://sounds/eagle/eagle_scream_1.mp3") as AudioStream,
		load("res://sounds/eagle/eagle_scream_2.mp3") as AudioStream,
		load("res://sounds/eagle/eagle_scream_3.mp3") as AudioStream,
	]
	flap_stream = load("res://sounds/eagle/eagle_wing_flap.mp3") as AudioStream

	_sfx_scream = AudioStreamPlayer3D.new()
	_sfx_scream.name = "SFX_Scream"
	_sfx_scream.bus = &"SFX"
	_sfx_scream.volume_db = scream_volume_db
	_sfx_scream.max_distance = 180.0
	_sfx_scream.unit_size = 28.0
	add_child(_sfx_scream)

	_sfx_flap = AudioStreamPlayer3D.new()
	_sfx_flap.name = "SFX_Flap"
	_sfx_flap.bus = &"SFX"
	_sfx_flap.volume_db = flap_volume_db
	_sfx_flap.max_distance = 120.0
	_sfx_flap.unit_size = 22.0
	if flap_stream:
		_sfx_flap.stream = flap_stream
	add_child(_sfx_flap)


func _play_random_scream() -> void:
	if _sfx_scream == null or scream_streams.is_empty():
		return
	var picks: Array[AudioStream] = []
	for s in scream_streams:
		if s != null:
			picks.append(s)
	if picks.is_empty():
		return
	_sfx_scream.stream = picks[randi() % picks.size()]
	_sfx_scream.pitch_scale = randf_range(0.94, 1.06)
	_sfx_scream.play()


func _play_flap_once() -> void:
	if _sfx_flap == null or _sfx_flap.stream == null:
		return
	# Restart so rapid flaps still read as beats
	if _sfx_flap.playing:
		_sfx_flap.stop()
	_sfx_flap.pitch_scale = randf_range(0.96, 1.05)
	_sfx_flap.play()


func _physics_process(delta: float) -> void:
	_update_wings(delta)

	var authority := multiplayer.multiplayer_peer == null or multiplayer.is_server()
	if not authority:
		return

	match _phase:
		Phase.PATROL:
			_tick_patrol(delta)
		Phase.DIVE:
			_tick_dive(delta)
		Phase.GRAB:
			_tick_grab(delta)
		Phase.CARRY:
			_tick_carry(delta)
		Phase.RELEASE:
			_tick_release(delta)
		Phase.COOLDOWN:
			_tick_cooldown(delta)


# --- Wings ---------------------------------------------------------------

func _setup_wings() -> void:
	_wing_pivots.clear()
	_wing_side.clear()
	_wing_rest.clear()
	_wing_pivot_scales.clear()
	var wings: Array[Node3D] = []
	for n in wing_part_names:
		var node := _find_desc_named(self, str(n))
		if node is Node3D:
			wings.append(node as Node3D)
		else:
			push_warning("[Eagle] wing part not found: %s" % n)
	if wings.is_empty():
		return

	# Body hub = average of non-wing mesh centers (falls back to eagle origin).
	var body_center: Vector3 = _estimate_body_center(wings)

	# Collect (local_x, wing) so we can assign mirror signs left/right reliably.
	var tagged: Array = []
	for w in wings:
		var root_g: Vector3 = _wing_root_global(w, body_center)
		var local_off: Vector3 = global_transform.affine_inverse() * root_g
		tagged.append({"w": w, "root": root_g, "lx": local_off.x})
	tagged.sort_custom(func(a, b): return float(a["lx"]) < float(b["lx"]))

	var axis := wing_hinge_axis.normalized() if wing_hinge_axis.length_squared() > 0.0001 else Vector3.RIGHT
	var inv := global_transform.affine_inverse()
	for i in range(tagged.size()):
		var w: Node3D = tagged[i]["w"]
		var root_g: Vector3 = tagged[i]["root"]
		# The wing's tip: the corner of its mesh farthest from the shoulder (eagle's local frame).
		var root_l: Vector3 = inv * root_g
		var tip_l: Vector3 = root_l
		var mi := w as MeshInstance3D
		if mi and mi.mesh:
			var aabb: AABB = mi.mesh.get_aabb()
			for k in range(8):
				var q: Vector3 = inv * mi.to_global(aabb.get_endpoint(k))
				if q.distance_squared_to(root_l) > tip_l.distance_squared_to(root_l):
					tip_l = q
		var reach: Vector3 = tip_l - root_l
		reach -= axis * reach.dot(axis)
		var up_l := Vector3.UP - axis * axis.y
		var out_l: Vector3 = (reach - up_l * reach.dot(up_l)).normalized()
		# Hinge at the shoulder (closest point to body), not wing center.
		var pivot := Node3D.new()
		pivot.name = "WingPivot_" + w.name
		add_child(pivot)
		pivot.global_position = root_g
		# Match eagle orientation but cancel FBX scale in world (scale lives on wing local).
		pivot.global_basis = global_basis.orthonormalized()
		var gt := w.global_transform
		var parent := w.get_parent()
		if parent:
			parent.remove_child(w)
		pivot.add_child(w)
		w.global_transform = gt
		_wing_pivots.append(pivot)
		# Critical: keep the local scale that compensates parent scale (~1/10).
		# Overwriting basis with Basis(axis,ang) alone made wings ~10x huge.
		_wing_pivot_scales.append(pivot.scale)
		# Rotating about the hinge by +a turns this wing's tip down when it reaches out on this side.
		var down_dir: Vector3 = Basis(axis, 0.1) * out_l - out_l
		_wing_side.append(1.0 if down_dir.dot(Vector3.UP) < 0.0 else -1.0)
		_wing_rest.append(atan2(reach.dot(up_l), maxf(reach.dot(out_l), 0.0001)))


## The wings: a shallow V soaring, with a burst of beats now and then (and while climbing); drawn up
## and back in the stoop; full beats braking over a car and heaving it up.
func _update_wings(delta: float) -> void:
	_glide_t += delta
	var base: float = glide_dihedral_deg + sin(_glide_t * 0.9) * 2.0
	var rate: float = beat_rate_soar
	var amp_target: float = 0.0
	match _phase:
		Phase.DIVE:
			base = stoop_deg
		Phase.GRAB:
			rate = beat_rate_grab
			amp_target = 1.0
		Phase.CARRY:
			rate = beat_rate_carry
			amp_target = 1.0
		_:
			_soar_timer -= delta
			if _burst_left <= 0 and _soar_timer <= 0.0:
				_burst_left = randi_range(3, 5)
				_soar_timer = randf_range(5.0, 9.0)
			if _velocity.y > 3.0:
				_burst_left = maxi(_burst_left, 1)
			amp_target = 0.75 if _burst_left > 0 else 0.0
	_beat_amp = lerpf(_beat_amp, amp_target, 1.0 - exp(-4.0 * delta))
	if amp_target > 0.0 or _beat_amp > 0.02:
		var before: float = _beat_phase
		_beat_phase += delta * rate
		if _beat_phase >= 1.0:
			_beat_phase -= 1.0
			_burst_left = maxi(_burst_left - 1, 0)
		# One flap sound per downstroke while heaving a car up.
		if _phase == Phase.CARRY and before > _beat_phase:
			_play_flap_once()
	var stroke: float = stroke_angle(_beat_phase)
	var target: float = lerpf(base, stroke, _beat_amp)
	_pose_deg = lerpf(_pose_deg, target, 1.0 - exp(-18.0 * delta))
	set_wing_pose(_pose_deg, stroke_twist(_beat_phase) * _beat_amp)


## The wing's angle over level (degrees) at `phase` of a beat: down fast, up slower.
func stroke_angle(phase: float) -> float:
	if phase < 0.4:
		return lerpf(beat_top_deg, beat_bottom_deg, smoothstep(0.0, 1.0, phase / 0.4))
	return lerpf(beat_bottom_deg, beat_top_deg, smoothstep(0.0, 1.0, (phase - 0.4) / 0.6))


## The twist (degrees): leading edge down through the downstroke, a little up on the way back.
func stroke_twist(phase: float) -> float:
	if phase < 0.4:
		return -wing_twist_deg * sin(phase / 0.4 * PI)
	return wing_twist_deg * 0.5 * sin((phase - 0.4) / 0.6 * PI)


## Both wings at `angle_deg` over level, twisted `twist_deg`, as a mirrored pair.
func set_wing_pose(angle_deg: float, twist_deg: float) -> void:
	var axis := wing_hinge_axis.normalized() if wing_hinge_axis.length_squared() > 0.0001 else Vector3.RIGHT
	for i in range(_wing_pivots.size()):
		var pivot: Node3D = _wing_pivots[i]
		if not is_instance_valid(pivot):
			continue
		var side: float = _wing_side[i]
		var ang: float = side * (_wing_rest[i] - deg_to_rad(angle_deg))
		# The span runs across the hinge: twist about it the same way on both wings.
		var span: Vector3 = axis.cross(Vector3.UP).normalized()
		var sc: Vector3 = _wing_pivot_scales[i] if i < _wing_pivot_scales.size() else Vector3.ONE
		pivot.basis = (Basis(axis, ang) * Basis(span, deg_to_rad(twist_deg))).scaled(sc)


func _estimate_body_center(wings: Array[Node3D]) -> Vector3:
	var wing_set: Dictionary = {}
	for w in wings:
		wing_set[w.get_instance_id()] = true
	var sum := Vector3.ZERO
	var count := 0
	for c in _all_mesh_instances(self):
		if wing_set.has(c.get_instance_id()):
			continue
		sum += _mesh_center_global(c)
		count += 1
	if count > 0:
		return sum / float(count)
	return global_position


func _wing_root_global(wing: Node3D, body_center: Vector3) -> Vector3:
	## Closest point on the wing mesh AABB to the body = shoulder joint.
	var mi := wing as MeshInstance3D
	if mi == null or mi.mesh == null:
		return wing.global_position
	var aabb: AABB = mi.mesh.get_aabb()
	var best: Vector3 = mi.to_global(aabb.get_center())
	var best_d: float = best.distance_squared_to(body_center)
	# Corners
	for i in range(8):
		var p: Vector3 = mi.to_global(aabb.get_endpoint(i))
		var d: float = p.distance_squared_to(body_center)
		if d < best_d:
			best_d = d
			best = p
	# Face centers (better estimate of the root edge)
	var c: Vector3 = aabb.get_center()
	var e: Vector3 = aabb.size * 0.5
	var locals: Array[Vector3] = [
		c + Vector3(e.x, 0, 0), c - Vector3(e.x, 0, 0),
		c + Vector3(0, e.y, 0), c - Vector3(0, e.y, 0),
		c + Vector3(0, 0, e.z), c - Vector3(0, 0, e.z),
	]
	for lp in locals:
		var p2: Vector3 = mi.to_global(lp)
		var d2: float = p2.distance_squared_to(body_center)
		if d2 < best_d:
			best_d = d2
			best = p2
	return best


func _all_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root as MeshInstance3D)
	for c in root.get_children():
		out.append_array(_all_mesh_instances(c))
	return out


# --- Phases --------------------------------------------------------------

func _tick_patrol(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_update_hunt_start_delay(delta)
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_patrol_target = _high_point_near_track(randf_range(-40.0, 80.0))
		_patrol_timer = patrol_retarget_time

	_fly_toward(_patrol_target, climb_speed * 0.85, delta, true)
	_ensure_terrain_clearance(4.0)

	if _cooldown_left > 0.0:
		return
	if hunt_only_while_racing and not _is_racing():
		return
	if _hunt_unlock_left > 0.0:
		return

	var cart := _pick_target_cart()
	if cart:
		_target_cart = cart
		_scream_played_this_hunt = false
		_phase = Phase.DIVE
		_play_random_scream()
		_scream_played_this_hunt = true


func _tick_dive(delta: float) -> void:
	if not _valid_cart(_target_cart):
		_abort_hunt(false)
		return
	# Shield protects — break it and abort the dive
	if _target_cart.get("is_shielded") == true:
		_break_cart_shield(_target_cart)
		_abort_hunt(false)
		return

	# A cart that gets up to its top speed outruns the eagle: it pulls up and gives up.
	if _outrunning(_target_cart):
		_abort_hunt(false)
		return

	# Safety: scream once on approach if not already played
	if not _scream_played_this_hunt:
		_play_random_scream()
		_scream_played_this_hunt = true

	# High-speed steep dive at where the car will be when it gets there.
	var lead: float = clampf(global_position.distance_to(_target_cart.global_position) / dive_speed, 0.0, 1.0)
	var aim: Vector3 = _target_cart.global_position + _target_cart.linear_velocity * lead + Vector3.UP * grab_height_above_car
	_fly_toward(aim, dive_speed, delta, true)
	_ensure_terrain_clearance(2.5)

	var dist: float = global_position.distance_to(_target_cart.global_position)
	if dist <= grab_radius:
		_phase = Phase.GRAB
		_carry_time = 0.0


func _tick_grab(delta: float) -> void:
	if not _valid_cart(_target_cart):
		# Bomb/missile/drown while locking on: drop ownership and fly away
		_abort_hunt(true)
		return
	if _target_cart.get("is_shielded") == true:
		_break_cart_shield(_target_cart)
		_abort_hunt(false)
		return

	# Swoop onto it: match its velocity and close on the place that puts the talons on its roof. It used to
	# fly at a point 3.5m over the car and, 0.2s later wherever it was, jump there.
	var cart_vel: Vector3 = _target_cart.linear_velocity
	var to: Vector3 = _talon_anchor(_target_cart.global_position) - global_position
	var desired: Vector3 = (cart_vel + to * 3.5).limit_length(dive_speed)
	_velocity = _velocity.lerp(desired, 1.0 - exp(-flight_smooth * delta))
	global_position += _velocity * delta
	var flat := Vector3(cart_vel.x, 0.0, cart_vel.z)
	if flat.length_squared() < 4.0:
		flat = Vector3(to.x, 0.0, to.z)
	_face_direction(flat, delta)
	_ensure_terrain_clearance(1.0, true)
	_carry_time += delta
	if to.length() < 1.2 or _carry_time > 0.9:
		_cart_pos = _target_cart.global_position
		_cart_vel = cart_vel
		_lock_cart(_target_cart)
		_holding = true
		_drop_world = _compute_road_drop_point(_target_cart.global_position)
		_carry_time = 0.0
		_phase = Phase.CARRY


func _tick_carry(delta: float) -> void:
	if not _valid_cart(_target_cart):
		# Cart destroyed mid-air (bomb/missile/drown): detach + fly away
		_abort_hunt(true)
		return

	_carry_time += delta
	# Climb toward the road drop point: carrying on the cart's way at first, the climb and the turn easing in.
	var lift: float = smoothstep(0.0, lift_time, _carry_time)
	var road_y: float = _sample_track_world(global_position, 0.0).y
	var target_y: float = maxf(road_y + 18.0, release_height)
	var target: Vector3 = Vector3(_drop_world.x, target_y, _drop_world.z)
	var desired: Vector3 = (target - global_position).normalized() * carry_speed
	desired.y = minf(desired.y, climb_speed * lift)
	var rate: float = lerpf(carry_turn_rate, flight_smooth * 0.5, lift)
	_velocity = _velocity.lerp(desired, 1.0 - exp(-rate * delta))
	global_position += _velocity * delta
	_face_direction(Vector3(_velocity.x, 0.0, _velocity.z), delta)
	# Down at the road while it heaves the cart up, the full clearance once it is climbing.
	_ensure_terrain_clearance(lerpf(1.2, 3.5 + carry_hold_below, smoothstep(lift_time, lift_time * 2.5, _carry_time)), true, true)

	_follow_talons(delta)

	var high_enough: bool = global_position.y >= release_height - 1.5
	var near_drop: bool = Vector2(global_position.x - _drop_world.x, global_position.z - _drop_world.z).length() < 16.0
	var timeout: bool = _carry_time > 9.0
	if _carry_time > lift_time and ((high_enough and near_drop) or (high_enough and _carry_time > 4.0)) or timeout:
		_phase = Phase.RELEASE


## Where the eagle's origin goes so its talons hold a cart at `cart_pos`.
func _talon_anchor(cart_pos: Vector3) -> Vector3:
	return cart_pos + Vector3.UP * carry_hold_below - _last_flat_fwd * carry_hold_forward


## Where a held cart's middle hangs.
func _talon_hold() -> Vector3:
	return global_position + Vector3.DOWN * carry_hold_below + _last_flat_fwd * carry_hold_forward


## The held cart follows the talons on a critically damped spring, relative to the eagle's own velocity, so
## it trails only while the eagle changes pace or way.
func _follow_talons(delta: float) -> void:
	var w: float = carry_follow_rate
	var acc: Vector3 = (_talon_hold() - _cart_pos) * (w * w) + (_velocity - _cart_vel) * (2.0 * w)
	_cart_vel += acc * delta
	_cart_pos += _cart_vel * delta
	_target_cart.global_transform = Transform3D(Basis.looking_at(_last_flat_fwd, Vector3.UP), _cart_pos)
	_target_cart.linear_velocity = Vector3.ZERO
	_target_cart.angular_velocity = Vector3.ZERO


## The held cart's model hangs from the talons: it faces the way the eagle flies and leans toward the grip as
## it swings. Per frame, eased, so it turns smoothly whatever the physics rate (its own code only moves the
## model while it is in the air).
func _process(delta: float) -> void:
	if not _holding or not _valid_cart(_target_cart):
		return
	var vis := _target_cart.get("visuals") as Node3D
	if vis == null or not is_instance_valid(vis):
		return
	var hang: Vector3 = (_talon_hold() + Vector3.UP * 2.0 - _cart_pos).normalized()
	var up: Vector3 = Vector3.UP.slerp(hang, carry_swing).normalized()
	var fwd: Vector3 = (_last_flat_fwd - up * _last_flat_fwd.dot(up)).normalized()
	var want := Basis(fwd.cross(up).normalized(), up, -fwd).get_rotation_quaternion()
	var cur: Quaternion = vis.global_basis.orthonormalized().get_rotation_quaternion()
	vis.global_basis = Basis(cur.slerp(want, 1.0 - exp(-6.0 * delta)).normalized())


func _tick_release(_delta: float) -> void:
	if _valid_cart(_target_cart):
		_release_cart(_target_cart)
	_target_cart = null
	_cooldown_left = cooldown_time
	_phase = Phase.COOLDOWN
	_patrol_target = _high_point_near_track(drop_along_track * 0.5)


func _tick_cooldown(delta: float) -> void:
	_cooldown_left -= delta
	# Honor shockwave knockback first, then resume smooth climb-away
	if _velocity.length() > 2.0:
		global_position += _velocity * delta
		_velocity = _velocity.lerp(Vector3.ZERO, 1.0 - exp(-2.8 * delta))
		_velocity.y -= 10.0 * delta
		var flat := Vector3(_velocity.x, 0.0, _velocity.z)
		if flat.length_squared() > 0.01:
			_face_direction(flat, delta)
	else:
		_fly_toward(_patrol_target, climb_speed, delta, true)
	_ensure_terrain_clearance(4.0)
	if _cooldown_left <= 0.0:
		_velocity = Vector3.ZERO
		_phase = Phase.PATROL
		_patrol_timer = 0.2


# --- Flight helpers ------------------------------------------------------

## Keeps the eagle `min_clearance` over whatever is under it (not the carts: a held one under the ray
## pushed it up in steps). `soft`, while it is down at a cart: it steers its climb up to clear the ground
## (with `look_ahead`, the ground 0.6s and 1.2s ahead too: a canyon wall comes up fast) instead of being
## lifted onto it, which jerked it and the cart it held a little every tick; it only snaps where it is more
## than 3m under the ground right under it.
func _ensure_terrain_clearance(min_clearance: float = 3.5, soft: bool = false, look_ahead: bool = false) -> void:
	if not is_inside_tree() or get_world_3d() == null:
		return
	var under: float = _ground_under(global_position) + min_clearance
	var steer: float = under
	if look_ahead:
		var flat := Vector3(_velocity.x, 0.0, _velocity.z)
		for t in [0.6, 1.2]:
			steer = maxf(steer, _ground_under(global_position + flat * float(t) + Vector3.UP * 4.0 * float(t)) + min_clearance)
	if soft:
		if global_position.y < steer:
			var need: float = (steer - global_position.y) * 3.0
			if _velocity.y < need:
				_velocity.y = lerpf(_velocity.y, need, 0.35)
		global_position.y = maxf(global_position.y, under - 3.0)
	elif global_position.y < under:
		global_position.y = under
		if _velocity.y < 0.0:
			_velocity.y = 0.0


## The height of whatever solid is under `at`, from just over it (from 40m up, the start gantry's beam, a
## checkpoint's banner or the bridge's truss over a cart it swooped on counted as the ground, and it jumped
## up onto them); the carts don't count. -INF if nothing is.
func _ground_under(at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 3.0, at + Vector3.DOWN * 120.0)
	q.collision_mask = 1
	var skip: Array[RID] = []
	for c in get_tree().get_nodes_in_group("player_carts"):
		if c is CollisionObject3D:
			skip.append((c as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return -INF if hit.is_empty() else float(hit.position.y)


func _fly_toward(target: Vector3, speed: float, delta: float, face: bool) -> void:
	var to: Vector3 = target - global_position
	var dist: float = to.length()
	if dist < 0.05:
		_velocity = _velocity.lerp(Vector3.ZERO, 1.0 - exp(-flight_smooth * delta))
		return
	var desired_vel: Vector3 = to.normalized() * speed
	# Ease velocity (removes step-y dives / climbs)
	var vblend: float = 1.0 - exp(-flight_smooth * delta)
	_velocity = _velocity.lerp(desired_vel, vblend)
	var step: Vector3 = _velocity * delta
	if step.length() > dist:
		step = to
		_velocity = to.normalized() * minf(speed, dist / maxf(delta, 0.0001))
	global_position += step
	if face:
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length_squared() > 0.001:
			_face_direction(flat, delta)


func _face_direction(flat_dir: Vector3, delta: float = 0.016) -> void:
	flat_dir.y = 0.0
	if flat_dir.length_squared() < 0.0001:
		return
	flat_dir = flat_dir.normalized()
	var before: Vector3 = _face_dir_smooth
	# Smooth yaw so turns aren't jerky
	var tblend: float = 1.0 - exp(-turn_smooth * delta)
	_face_dir_smooth = _face_dir_smooth.lerp(flat_dir, tblend)
	if _face_dir_smooth.length_squared() < 0.0001:
		_face_dir_smooth = flat_dir
	else:
		_face_dir_smooth = _face_dir_smooth.normalized()
	_last_flat_fwd = _face_dir_smooth
	# Bank into the turn: the inside wing low.
	var turn_rate: float = before.cross(_face_dir_smooth).y / maxf(delta, 0.001)
	var bank_cap: float = deg_to_rad(bank_max_deg)
	_bank = lerpf(_bank, clampf(-turn_rate * 0.8, -bank_cap, bank_cap), 1.0 - exp(-4.0 * delta))
	var sc: Vector3 = global_transform.basis.get_scale()
	var b := Basis.looking_at(_face_dir_smooth, Vector3.UP)
	if absf(model_yaw_offset_deg) > 0.01:
		b = b.rotated(Vector3.UP, deg_to_rad(model_yaw_offset_deg))
	b = Basis(_face_dir_smooth, _bank) * b
	b = b.scaled(sc.abs())
	global_transform = Transform3D(b, global_position)


func _high_point_near_track(extra_along: float) -> Vector3:
	var sample := _sample_track_world(global_position, extra_along)
	sample.y = maxf(sample.y, _home.y) + patrol_height
	return sample


func _compute_road_drop_point(from_world: Vector3) -> Vector3:
	# Drop further along the race track from the grab location.
	return _sample_track_world(from_world, drop_along_track)


func _sample_track_world(near_world: Vector3, advance: float) -> Vector3:
	var track := _get_track_path()
	if track == null or track.curve == null:
		# Fallback: forward from home along -Z of level
		return near_world + Vector3(0.0, 0.0, -advance)

	var curve: Curve3D = track.curve
	var length: float = maxf(curve.get_baked_length(), 1.0)
	var local: Vector3 = track.to_local(near_world)
	var off: float = curve.get_closest_offset(local)
	var drop_off: float = fmod(off + advance + length, length)
	var local_pt: Vector3 = curve.sample_baked(drop_off)
	var world: Vector3 = track.to_global(local_pt)
	# Keep slightly above road surface
	world.y += 1.5
	return world


func _get_track_path() -> Path3D:
	var level = get_tree().get_first_node_in_group("level") if get_tree() else null
	if level and level.get("track_path") is Path3D:
		return level.track_path as Path3D
	if level:
		var p = level.get_node_or_null("TrackPath")
		if p is Path3D:
			return p as Path3D
	return get_node_or_null("../TrackPath") as Path3D


func _is_racing() -> bool:
	var level = get_tree().get_first_node_in_group("level") if get_tree() else null
	if level == null or not ("race_state" in level):
		return true
	return int(level.race_state) == 1


func _update_hunt_start_delay(delta: float) -> void:
	var racing := _is_racing()
	if racing and not _was_racing:
		# Race just started (or first frame we see racing) — full grace period
		_hunt_unlock_left = maxf(0.0, hunt_start_delay)
	elif not racing:
		# Pre-race / finished: keep timer armed for the next start
		_hunt_unlock_left = maxf(0.0, hunt_start_delay)
	elif _hunt_unlock_left > 0.0:
		_hunt_unlock_left = maxf(0.0, _hunt_unlock_left - delta)
	_was_racing = racing


# --- Cars ----------------------------------------------------------------

func _pick_target_cart() -> RigidBody3D:
	if not get_tree():
		return null
	var carts := get_tree().get_nodes_in_group("player_carts")
	var candidates: Array[RigidBody3D] = []
	for c in carts:
		if not _valid_cart(c):
			continue
		if c.has_method("has_physics_authority") and not c.has_physics_authority():
			continue
		if _outrunning(c):
			continue
		candidates.append(c as RigidBody3D)
	if candidates.is_empty():
		return null

	if randomize_targets:
		# Weighted random: everyone is eligible; optional mild boost for local player.
		var weights: Array[float] = []
		var total: float = 0.0
		for cart in candidates:
			var w: float = 1.0
			if prefer_local_player and cart.get("is_local_player") == true and cart.get("is_ai") != true:
				w = 1.6
			# Slightly prefer closer cars without ignoring far ones
			var dist: float = global_position.distance_to(cart.global_position)
			w *= 1.0 / (1.0 + dist * 0.01)
			weights.append(w)
			total += w
		var r: float = randf() * total
		var acc: float = 0.0
		for i in range(candidates.size()):
			acc += weights[i]
			if r <= acc:
				return candidates[i]
		return candidates[candidates.size() - 1]

	# Deterministic: nearest (with optional local preference)
	var best: RigidBody3D = null
	var best_score: float = -1.0e12
	for cart in candidates:
		var dist: float = global_position.distance_to(cart.global_position)
		var score: float = -dist
		if prefer_local_player and cart.get("is_local_player") == true and cart.get("is_ai") != true:
			score += 40.0
		if score > best_score:
			best_score = score
			best = cart
	return best


## True while `cart` is going at least escape_speed_share of its top speed.
func _outrunning(cart: Object) -> bool:
	var rb := cart as RigidBody3D
	if rb == null:
		return false
	var top: float = float(cart.get("max_speed")) if cart.get("max_speed") != null else 40.0
	return rb.linear_velocity.length() >= top * escape_speed_share


func _valid_cart(cart: Object) -> bool:
	if cart == null or not is_instance_valid(cart):
		return false
	if not (cart is RigidBody3D):
		return false
	if cart.get("is_exploding") == true or cart.get("is_drowned") == true:
		return false
	return true


func _lock_cart(cart: RigidBody3D) -> void:
	cart.freeze = true
	cart.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	cart.linear_velocity = Vector3.ZERO
	cart.angular_velocity = Vector3.ZERO
	if "can_move" in cart:
		cart.set("can_move", false)
	if "is_carried_by_eagle" in cart:
		cart.set("is_carried_by_eagle", true)
	if "axis_lock_angular_x" in cart:
		cart.axis_lock_angular_x = false
		cart.axis_lock_angular_y = false
		cart.axis_lock_angular_z = false


## Called by player shockwave — drop any car and get shoved away.
func apply_shockwave_push(from_world: Vector3) -> void:
	if _valid_cart(_target_cart) and (_phase == Phase.CARRY or _phase == Phase.GRAB):
		_release_cart(_target_cart)
	_target_cart = null

	var away: Vector3 = global_position - from_world
	away.y = 0.0
	if away.length_squared() < 0.001:
		away = _last_flat_fwd
	else:
		away = away.normalized()
	_velocity = away * shockwave_push_speed + Vector3.UP * shockwave_push_up
	_face_direction(away, 0.05)
	_cooldown_left = maxf(_cooldown_left, shockwave_stun_time)
	_patrol_target = global_position + away * 40.0 + Vector3.UP * 25.0
	_phase = Phase.COOLDOWN


## Called by PlayerCart on explode/drown so the eagle never keeps a dead car locked.
func force_release_cart(cart: Object) -> void:
	if cart == null or _target_cart != cart:
		return
	_abort_hunt(true)


## Drop current prey (if any) without restoring control when the car is dying,
## then fly away on cooldown. Safe if already empty-handed.
func _abort_hunt(was_holding: bool) -> void:
	var cart = _target_cart
	_target_cart = null
	if cart != null and is_instance_valid(cart) and cart is RigidBody3D:
		var rb := cart as RigidBody3D
		var dead: bool = cart.get("is_exploding") == true or cart.get("is_drowned") == true
		if was_holding or _phase == Phase.CARRY or _phase == Phase.GRAB:
			if dead:
				# Death/respawn owns can_move — only clear the kinematic freeze the eagle applied.
				_detach_dead_cart(rb)
			elif _valid_cart(cart):
				_release_cart(rb)
			else:
				_detach_dead_cart(rb)
	_holding = false
	_cooldown_left = maxf(_cooldown_left, cooldown_time * 0.55)
	_patrol_target = _high_point_near_track(50.0)
	# Nudge upward/away so it reads as "flew off" after a kill mid-grab
	var flee := _last_flat_fwd
	flee.y = 0.0
	if flee.length_squared() < 0.001:
		flee = Vector3.FORWARD
	else:
		flee = flee.normalized()
	_velocity = flee * carry_speed + Vector3.UP * climb_speed
	_phase = Phase.COOLDOWN


func _detach_dead_cart(cart: RigidBody3D) -> void:
	if cart == null or not is_instance_valid(cart):
		return
	if "is_carried_by_eagle" in cart:
		cart.set("is_carried_by_eagle", false)
	# Eagle had freeze=true + can_move=false. Explode/drown already set can_move false;
	# leave can_move alone so respawn can re-enable it cleanly.
	cart.freeze = false
	cart.sleeping = false
	# Restore upright angular locks so respawn isn't left in free-spin capture mode
	if "axis_lock_angular_x" in cart:
		cart.axis_lock_angular_x = true
		cart.axis_lock_angular_y = true
		cart.axis_lock_angular_z = true


func _break_cart_shield(cart: Object) -> void:
	if cart == null:
		return
	cart.set("is_shielded", false)
	var cart_id: int = str(cart.name).to_int() if "name" in cart else 0
	var is_ai: bool = cart.get("is_ai") == true
	var is_real_peer: bool = cart_id > 0 and not is_ai
	if multiplayer.multiplayer_peer != null and multiplayer.is_server() and is_real_peer \
			and NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
		if cart.has_method("client_break_shield"):
			cart.client_break_shield.rpc_id(cart_id)
			return
	if cart.get("shield_mesh") != null:
		cart.shield_mesh.visible = false
		cart.shield_mesh.scale = Vector3.ONE
	elif cart.has_method("client_break_shield"):
		cart.client_break_shield()


func _release_cart(cart: RigidBody3D) -> void:
	if "is_carried_by_eagle" in cart:
		cart.set("is_carried_by_eagle", false)
	if not _holding:
		# Let go in the swoop, before the grip: the cart was never locked.
		return
	_holding = false
	# Let go where it hangs (it's already over the road, near the drop), carrying a little of its way.
	var road_y: float = _sample_track_world(cart.global_position, 0.0).y
	if cart.global_position.y < road_y + 3.0:
		cart.global_position.y = road_y + 3.0
	var flat := Vector3(_cart_vel.x, 0.0, _cart_vel.z).limit_length(8.0)

	cart.freeze = false
	cart.sleeping = false
	cart.linear_velocity = flat + Vector3.DOWN * (release_down_speed + maxf(-_cart_vel.y, 0.0))
	cart.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))

	if cart.has_method("_tornado_restore_control"):
		cart._tornado_restore_control()
	elif "can_move" in cart:
		cart.set("can_move", _is_racing())


# --- Utils ---------------------------------------------------------------

func _find_desc_named(root: Node, want: String) -> Node:
	if root.name == want:
		return root
	for c in root.get_children():
		var f := _find_desc_named(c, want)
		if f:
			return f
	return null


func _mesh_center_global(node: Node3D) -> Vector3:
	var mi := node as MeshInstance3D
	if mi == null or mi.mesh == null:
		return node.global_position
	var a: AABB = mi.mesh.get_aabb()
	return mi.to_global(a.get_center())
