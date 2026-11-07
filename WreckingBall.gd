extends Node3D
## A wrecking ball on a crawler crane's hoist line (Quer durch Kronburg's demolition site), swinging on the wall clock so
## every LAN peer sees it in the same place without syncing. This node is the hang point (the boom's tip sheave); its
## first child (the rope, chain and ball, built hanging down its -y) is turned about this node's x axis, so the ball
## swings along this node's z. The generator turns the node so +z points at the building being knocked down and the
## road lies under the hang point.
##
## The swing is a pendulum that strikes the building: it leaves the wall at `wall_deg` (from the vertical, toward +z)
## swinging out, crosses under the hang point (over the road) to `out_deg` on the far side, comes back and strikes the
## wall again: a free pendulum (gravity `gravity` along a line `length` long) between strikes, so it slows at the far
## end and is fastest over the road. `hold` can keep it still at the far end for a while (the operator braking it on the
## drag line); Quer durch Kronburg swings it free and fast (`gravity` 28) and gives its gate tighter margins instead. At
## each strike: a burst of dust and debris off the wall and a crash (`crash`).
##
## The ball's sphere (`ball_radius`, its centre `length` down the line) destroys a cart it meets (`kills`, this peer's
## carts only), with a clang (`clang`); with `kills` off it throws the cart instead: along the ball's way, up, and
## spinning (PlayerCart.apply_blast_impulse). `cover_intervals(gate)` (for HazardGate.gd) says when in the cycle the ball
## is over the road.

@export var length := 48.0
@export var ball_radius := 1.7
@export var wall_deg := 20.0
@export var out_deg := 24.0
@export var gravity := 14.0
## Seconds the ball is held at the far end of its swing (out_deg), every cycle.
@export var hold := 0.0
@export var phase := 0.0
## How hard a hit throws a cart: the ball's speed times this, plus `throw_up` m/s upward.
@export var throw_gain := 1.6
@export var throw_up := 9.0
@export var crash: Array[AudioStream] = []
@export var clang: AudioStream
@export var whoosh: AudioStream
@export var crash_db := 2.0
@export var clang_db := 0.0
@export var whoosh_db := -6.0
## Seconds into the day; set to hold the ball still for tests and shots (negative: the wall clock).
@export var clock_override := -1.0
@export var hits := true
## Destroy a cart the ball meets (as the Ring's traffic does); off, it throws the cart.
@export var kills := true

signal cart_hit(cart: Node)

## The cycle's length (seconds), worked out in _ready.
var period := 10.0
var _omega := 0.5
var _phi := 0.5
var _amp := 0.5
var _swing: Node3D
var _prev_pos := {}
var _cooldown := {}
var _intervals := {}
var _last_cycle := -1
var _crash_player: AudioStreamPlayer3D
var _clang_player: AudioStreamPlayer3D
var _whoosh_player: AudioStreamPlayer3D
var _dust: GPUParticles3D
var _debris: GPUParticles3D
var _headless := false
var _whooshed := false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	for c in get_children():
		if c is Node3D:
			_swing = c
			break
	_omega = sqrt(gravity / maxf(length, 1.0))
	var w: float = deg_to_rad(wall_deg)
	var o: float = deg_to_rad(out_deg)
	# A free swing that reaches out_deg on the far side: its amplitude is out_deg; it leaves the wall at wall_deg.
	_amp = o
	_phi = acos(clampf(w / _amp, -1.0, 1.0))
	period = (TAU - 2.0 * _phi) / _omega + maxf(hold, 0.0)
	if not _headless:
		_crash_player = _player("Crash", crash_db, 60.0)
		_clang_player = _player("Clang", clang_db, 40.0)
		_whoosh_player = _player("Whoosh", whoosh_db, 25.0)
		_whoosh_player.stream = whoosh
		_clang_player.stream = clang
		_make_dust()
	_apply(_clock())


func _player(n: String, db: float, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = n
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 700.0
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p, false, Node.INTERNAL_MODE_BACK)
	return p


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


func cycle_time() -> float:
	return fposmod(_clock() - phase, period)


## The pendulum's own time at cycle time `tc`: it stands still at the far end (where it turns) for `hold` seconds.
func _swing_t(tc: float) -> float:
	var t_far: float = (PI - _phi) / _omega
	if tc < t_far:
		return tc
	return maxf(t_far, tc - maxf(hold, 0.0))


## The line's angle from the vertical (radians, + toward the wall) `tc` seconds into the cycle (0 at a strike).
func angle_at(tc: float) -> float:
	return _amp * cos(_omega * _swing_t(tc) + _phi)


func angular_speed_at(tc: float) -> float:
	return -_amp * _omega * sin(_omega * _swing_t(tc) + _phi)


## The ball's centre in this node's frame at cycle time tc.
func ball_local(tc: float) -> Vector3:
	var a: float = angle_at(tc)
	return Vector3(0.0, -length * cos(a), length * sin(a))


func _apply(t: float) -> void:
	var tc: float = fposmod(t - phase, period)
	if _swing != null:
		_swing.rotation = Vector3(-angle_at(tc), 0.0, 0.0)
	var cyc: int = floori((t - phase) / period)
	if _last_cycle >= 0 and cyc != _last_cycle and not _headless:
		_strike()
	if _last_cycle != cyc:
		_whooshed = false
	_last_cycle = cyc
	# A whoosh as it sweeps down over the road.
	if not _headless and not _whooshed and absf(angle_at(tc)) < 0.12 and _whoosh_player.stream != null:
		_whooshed = true
		_whoosh_player.position = ball_local(tc)
		_whoosh_player.play()


func _strike() -> void:
	var at: Vector3 = ball_local(0.0) + Vector3(0, 0, ball_radius)
	if not crash.is_empty() and _crash_player != null:
		_crash_player.stream = crash[randi() % crash.size()]
		_crash_player.position = at
		_crash_player.play()
	if _dust != null:
		_dust.position = at
		_dust.restart()
		_dust.emitting = true
	if _debris != null:
		_debris.position = at
		_debris.restart()
		_debris.emitting = true


func _physics_process(_delta: float) -> void:
	var t: float = _clock()
	_apply(t)
	if hits:
		_check_hits(t)


func _check_hits(t: float) -> void:
	var tc: float = fposmod(t - phase, period)
	var ball_w: Vector3 = to_global(ball_local(tc))
	var ball_prev: Vector3 = to_global(ball_local(fposmod(tc - 1.0 / 60.0, period)))
	var carts := get_tree().get_nodes_in_group("player_carts")
	for c in carts:
		var cart := c as RigidBody3D
		if cart == null or not is_instance_valid(cart):
			continue
		var id := cart.get_instance_id()
		var pos: Vector3 = cart.global_position
		var prev: Vector3 = _prev_pos.get(id, pos)
		_prev_pos[id] = pos
		if pos.distance_to(ball_w) > 30.0:
			continue
		if not cart.has_method("has_physics_authority") or not cart.has_physics_authority():
			continue
		if cart.get("is_finished_race") or cart.get("is_exploding"):
			continue
		if _cooldown.get(id, -10.0) > t:
			continue
		var reach: float = ball_radius + float(cart.get("collision_radius")) * 0.85
		var hit := false
		for k in 5:
			var f: float = k / 4.0
			if pos.lerp(prev, 1.0 - f).distance_to(ball_prev.lerp(ball_w, f)) < reach:
				hit = true
				break
		if not hit:
			continue
		_cooldown[id] = t + 1.5
		var w_speed: float = angular_speed_at(tc) * length
		var along: Vector3 = global_transform.basis.z.normalized() * signf(w_speed if absf(w_speed) > 0.3 else -1.0)
		var away: Vector3 = (pos - ball_w)
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else along
		var dir: Vector3 = (along * 0.75 + away * 0.25).normalized()
		var dv: Vector3 = dir * maxf(absf(w_speed) * throw_gain, 8.0) + Vector3.UP * throw_up
		print("WreckingBall %s hit cart %s (%.1f m/s)" % [name, cart.name, absf(w_speed)])
		cart_hit.emit(cart)
		if kills and cart.has_method("explode"):
			if multiplayer.multiplayer_peer != null:
				cart.explode_rpc.rpc(0, "wrecking_ball")
			else:
				cart.explode(0, "wrecking_ball")
		elif cart.has_method("apply_blast_impulse"):
			cart.apply_blast_impulse(dv * cart.mass)
		else:
			cart.apply_central_impulse(dv * cart.mass)
		if _clang_player != null and _clang_player.stream != null:
			_clang_player.position = to_local(ball_w)
			_clang_player.play()


## When in the cycle the ball is over the road at `gate` (HazardGate.gd), as [start, end] pairs; worked out once per gate.
func cover_intervals(gate: Node) -> Array:
	var key: int = gate.get_instance_id()
	if _intervals.has(key):
		return _intervals[key]
	var out: Array = []
	var start := -1.0
	var tc := 0.0
	var pad: float = ball_radius + 1.0
	while tc <= period:
		var on: bool = gate.on_road(to_global(ball_local(tc)), pad) and to_global(ball_local(tc)).y < (gate as Node3D).global_position.y + 4.0 + ball_radius
		if on and start < 0.0:
			start = tc
		elif not on and start >= 0.0:
			out.append([start, tc])
			start = -1.0
		tc += 0.05
	if start >= 0.0:
		out.append([start, period])
	_intervals[key] = out
	return out


func _make_dust() -> void:
	var puff := StandardMaterial3D.new()
	puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.vertex_color_use_as_albedo = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.7))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 64
	gt.height = 64
	puff.albedo_texture = gt
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	quad.material = puff
	_dust = GPUParticles3D.new()
	_dust.name = "StrikeDust"
	_dust.one_shot = true
	_dust.emitting = false
	_dust.amount = 40
	_dust.lifetime = 4.5
	_dust.explosiveness = 0.9
	_dust.draw_pass_1 = quad
	_dust.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.3, -1)
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0, -0.6, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = 3.0
	pm.scale_max = 7.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	pm.color = Color(0.72, 0.68, 0.62, 0.8)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.0
	_dust.process_material = pm
	add_child(_dust, false, Node.INTERNAL_MODE_BACK)
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.35, 0.25, 0.3)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.58, 0.56, 0.52)
	cm.roughness = 0.95
	chunk.material = cm
	_debris = GPUParticles3D.new()
	_debris.name = "StrikeDebris"
	_debris.one_shot = true
	_debris.emitting = false
	_debris.amount = 24
	_debris.lifetime = 2.2
	_debris.explosiveness = 0.95
	_debris.draw_pass_1 = chunk
	_debris.visibility_aabb = AABB(Vector3(-30, -40, -30), Vector3(60, 60, 60))
	var dm := ParticleProcessMaterial.new()
	dm.direction = Vector3(0, 0.2, -1)
	dm.spread = 55.0
	dm.initial_velocity_min = 3.0
	dm.initial_velocity_max = 9.0
	dm.gravity = Vector3(0, -18.0, 0)
	dm.angular_velocity_min = -360.0
	dm.angular_velocity_max = 360.0
	dm.scale_min = 0.6
	dm.scale_max = 1.8
	dm.collision_mode = ParticleProcessMaterial.COLLISION_DISABLED
	_debris.process_material = dm
	add_child(_debris, false, Node.INTERNAL_MODE_BACK)
