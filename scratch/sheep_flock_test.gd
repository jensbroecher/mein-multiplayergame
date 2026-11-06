extends Node3D
## Test bench for SheepFlock.gd: a flat meadow with a collider and a road strip along z at x = 0, a flock grazing in area A
## (x < 0) with B across the road. The flock's clock is driven by hand (`clock_override`), starting `lead` seconds before
## the walk across of crossing 2 (A to B), stepping 1/30s a physics frame. Run:
##   windowed, saving frames:  Godot --path . --resolution 1400x850 --fixed-fps 30 res://scratch/sheep_flock_test.tscn -- <dir>
##                             [times=0,6,10,14,...] [lead=8] [hit=1] [cam=x,y,z:tx,ty,tz]
##   headless, checking:       Godot --headless --path . --fixed-fps 30 res://scratch/sheep_flock_test.tscn -- [seconds=80] [lead=30] [hit=1]
## Headless it prints where the bodies are every few seconds, how many sheep are in each area at the start and the end,
## how far the bodies moved, the update's CPU cost (forced on by a cart parked by the flock), and with hit=1 drives a stand-in
## cart (a RigidBody3D in "player_carts" with physics authority and a weight) through the grazing flock and reports the knock
## and its speed before and after. Prints PASS or FAIL.

const SheepFlock = preload("res://SheepFlock.gd")
const STEP := 1.0 / 30.0

var _flock: Node3D
var _cart: RigidBody3D
var _clock := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	var times: Array = [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 26.0, 34.0, 44.0]
	var lead := 8.0
	var seconds := 80.0
	var hit := false
	var cams: Array = []
	for a in args:
		if a.begins_with("times="):
			times = Array(a.substr(6).split_floats(","))
		elif a.begins_with("lead="):
			lead = float(a.substr(5))
		elif a.begins_with("seconds="):
			seconds = float(a.substr(8))
		elif a.begins_with("hit="):
			hit = a.substr(4) == "1"
		elif a.begins_with("cam="):
			cams.append(a.substr(4))
		elif not a.contains("="):
			out = a
	var headless: bool = DisplayServer.get_name() == "headless"
	_setup_world(headless)
	_flock = Node3D.new()
	_flock.name = "SheepFlock"
	_flock.set_script(SheepFlock)
	var k0 := 2
	_clock = float(k0) * 110.0 + 26.0 - lead
	_flock.set("clock_override", _clock)
	add_child(_flock)
	for i in 6:
		await get_tree().physics_frame
	if headless or out == "":
		await _check(seconds, hit)
	else:
		await _shoot(out, times, cams, hit)
	get_tree().quit()


func _process(_delta: float) -> void:
	pass


func _advance() -> void:
	_clock += STEP
	_flock.set("clock_override", _clock)


func _in_area(p: Vector3, b: bool) -> bool:
	var c: Vector3 = _flock.get("area_b_centre") if b else _flock.get("area_a_centre")
	var h: Vector2 = _flock.get("area_b_half") if b else _flock.get("area_a_half")
	return absf(p.x - c.x) <= h.x + 1.0 and absf(p.z - c.z) <= h.y + 1.0


func _counts() -> Vector2i:
	var a := 0
	var b := 0
	for p in (_flock.get("_pos") as PackedVector3Array):
		if _in_area(p, false):
			a += 1
		elif _in_area(p, true):
			b += 1
	return Vector2i(a, b)


func _check(seconds: float, hit: bool) -> void:
	var ok := true
	# A parked "cart" by the road keeps the flock updating (as on a server, where it only moves near carts).
	var parked := _make_cart(Vector3(0, 0.8, 60))
	parked.linear_velocity = Vector3.ZERO
	var start: Vector2i = _counts()
	print("start: %d in A, %d in B" % [start.x, start.y])
	var bodies: Array = []
	for c in _flock.get_children(true):
		if c is AnimatableBody3D:
			bodies.append(c)
	var first := PackedVector3Array()
	for b in bodies:
		first.append((b as Node3D).global_position)
	var steps: int = int(seconds / STEP)
	var cost := 0
	var cost_n := 0
	var cost_max := 0
	var on_road_max := 0
	for s in range(steps):
		_advance()
		await get_tree().physics_frame
		var u: int = _flock.get("last_update_usec")
		cost += u
		cost_n += 1
		cost_max = maxi(cost_max, u)
		var on_road := 0
		for b in bodies:
			if absf((b as Node3D).global_position.x) < 4.0:
				on_road += 1
		if s > 10:
			on_road_max = maxi(on_road_max, on_road)
		if s % int(5.0 / STEP) == 0:
			var c: Vector2i = _counts()
			var b0: Vector3 = (bodies[0] as Node3D).global_position
			print("t=%5.1fs  A %2d  B %2d  on the road %2d  body0 (%.1f, %.2f, %.1f)  update %d us" % [float(s) * STEP, c.x, c.y, on_road, b0.x, b0.y, b0.z, u])
	var end: Vector2i = _counts()
	var moved := 0
	var min_move := 1e9
	for i in range(bodies.size()):
		var d: float = (bodies[i] as Node3D).global_position.distance_to(first[i])
		min_move = minf(min_move, d)
		if d > 5.0:
			moved += 1
	print("end: %d in A, %d in B; %d of %d bodies moved over 5m (least %.1fm); most on the road at once %d" % [end.x, end.y, moved, bodies.size(), min_move, on_road_max])
	print("update: mean %.0f us, max %d us over %d frames" % [float(cost) / maxf(float(cost_n), 1.0), cost_max, cost_n])
	if start.x < bodies.size() * 0.8 or end.y < bodies.size() * 0.8 or moved < bodies.size():
		ok = false
	if hit:
		ok = await _hit_test() and ok
	print("PASS" if ok else "FAIL")


## Drives a stand-in cart at 22 m/s through the flock grazing in B (after the crossing) and checks it was knocked.
func _hit_test() -> bool:
	var pos: PackedVector3Array = _flock.get("_pos")
	var target: Vector3 = pos[0]
	var cart := _make_cart(target + Vector3(-30, 0.8, 0))
	cart.linear_velocity = Vector3(22, 0, 0)
	var before: int = _flock.get("bump_count")
	var v_in: float = 22.0
	var v_out := v_in
	for s in range(int(2.6 / STEP)):
		await get_tree().physics_frame
		var hv := Vector3(cart.linear_velocity.x, 0, cart.linear_velocity.z)
		v_out = minf(v_out, hv.length())
	var bumps: int = int(_flock.get("bump_count")) - before
	var knocked := 0
	for t0 in (_flock.get("_knock_t0") as PackedFloat32Array):
		if t0 >= 0.0:
			knocked += 1
	print("hit test: %d bumps, %d sheep knocked, the cart %.1f m/s in, %.1f out" % [bumps, knocked, v_in, v_out])
	cart.queue_free()
	return bumps > 0 and knocked > 0 and v_out < v_in - 0.5 and v_out > v_in * 0.7


func _make_cart(p: Vector3) -> RigidBody3D:
	var cart := RigidBody3D.new()
	var scr := GDScript.new()
	scr.source_code = "extends RigidBody3D\nvar weight := 1.0\nfunc has_physics_authority() -> bool:\n\treturn true\n"
	scr.reload()
	cart.set_script(scr)
	cart.gravity_scale = 0.0
	cart.collision_layer = 0
	cart.collision_mask = 0
	cart.linear_damp = 0.0
	cart.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.0
	cs.shape = sp
	cart.add_child(cs)
	add_child(cart)
	cart.global_position = p
	cart.add_to_group("player_carts")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.7, 2.2)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.1, 0.08)
	bm.material = m
	mi.mesh = bm
	mi.rotation.y = PI * 0.5
	cart.add_child(mi)
	return cart


func _shoot(out: String, times: Array, cams: Array, hit: bool) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var cam := Camera3D.new()
	cam.fov = 55.0
	cam.far = 2000.0
	add_child(cam)
	cam.make_current()
	if cams.is_empty():
		cams = ["side:-10,14,60:0,0,0", "low:8,3.5,28:-14,1,0", "close:-34,4,18:-45,1,0"]
	var elapsed := 0.0
	times.sort()
	var ti := 0
	# Let the shaders compile with the clock held.
	for i in 40:
		await get_tree().process_frame
	var cart: RigidBody3D = null
	var cost := 0
	var cost_n := 0
	var cost_max := 0
	while ti < times.size():
		if elapsed >= float(times[ti]) - 0.001:
			for c in cams:
				var parts := (c as String).split(":")
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				cam.global_position = Vector3(p[0], p[1], p[2])
				cam.look_at(Vector3(t[0], t[1], t[2]), Vector3.UP)
				for f in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%05.1f.png" % [out, parts[0], float(times[ti])])
			print("SHOT t=%.1f" % float(times[ti]))
			if hit and ti == 0:
				var pos: PackedVector3Array = _flock.get("_pos")
				cart = _make_cart(pos[3] + Vector3(-25, 0.8, 0))
				cart.linear_velocity = Vector3(20, 0, 0)
			ti += 1
			continue
		_advance()
		elapsed += STEP
		await get_tree().physics_frame
		var u: int = _flock.get("last_update_usec")
		cost += u
		cost_n += 1
		cost_max = maxi(cost_max, u)
	print("update (drawn): mean %.0f us, max %d us over %d frames" % [float(cost) / maxf(float(cost_n), 1.0), cost_max, cost_n])


func _setup_world(headless: bool) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(800, 2, 800)
	cs.shape = box
	cs.position = Vector3(0, -1.0, 0)
	body.add_child(cs)
	# A low dyke the flock walks over on B's side, so the ground isn't flat everywhere.
	var dyke := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(10, 2, 120)
	dyke.shape = dbox
	dyke.transform = Transform3D(Basis(Vector3.BACK, 0.12), Vector3(30, -0.4, 0))
	body.add_child(dyke)
	add_child(body)
	if headless:
		return
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	gm.mesh = pm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_texture = load("res://materials/grass.png")
	gmat.uv1_scale = Vector3(80, 80, 1)
	gmat.albedo_color = Color(0.72, 0.74, 0.62)
	gmat.roughness = 1.0
	pm.material = gmat
	add_child(gm)
	var dm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = dbox.size
	bm.material = gmat
	dm.mesh = bm
	dm.transform = dyke.transform
	add_child(dm)
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(9.0, 800.0)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.17, 0.17, 0.18)
	rmat.roughness = 0.9
	rm.material = rmat
	road.mesh = rm
	road.position = Vector3(0, 0.03, 0)
	add_child(road)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.50, 0.80)
	sm.sky_horizon_color = Color(0.86, 0.82, 0.74)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30.0, 240.0, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.91, 0.78)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)
