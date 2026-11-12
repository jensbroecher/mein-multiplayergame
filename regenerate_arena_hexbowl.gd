extends "res://ArenaStage.gd"
## Builds levels/ArenaHexBowlLevel.tscn - the Hex Bowl, the football arena (ArenaGame.gd, kind "football"): a hexagonal
## pitch under floodlights with a goal in the middle of each of its six sides (all against all, each player owns one;
## in teams they alternate red and blue). Not a rocket league box: no curved walls to drive up, a pinball table
## instead: padded walls with glass over them, a slingshot bar across each corner (ArenaBumper.gd), three pop bumpers
## round the centre circle, a launch fan (ArenaFan.gd) toward each corner, item boxes, the stands all round with the
## crowd, light towers at the corners.
##
## The frame (x east, z south, the pitch at y 0): the hexagon's sides face the angles k * 60 degrees, `R` from the
## middle (its corners `RC` out). Goal k sits on side k: its node's -z faces the pitch, x across the mouth (`GOAL_HALF`),
## `GOAL_H` high, `GOAL_D` deep (a GoalNet inside), its posts, bar and goal line in the "arena_paint" group (coloured by
## ArenaGame). Spawn k in front of goal k (ArenaGame gives slot k goal k, and in teams goal k to team k % 2, so a team
## starts at its own goals). The ceiling (invisible, `LID`) and the glass's colliders keep the balls and the launched cars in.

const R := 48.0
const RC := R / 0.8660254
const GOAL_HALF := 7.0
const GOAL_H := 5.5
const GOAL_D := 6.0
const WALL_PAD := 2.6
const GLASS_TOP := 9.0
const LID := 32.0
const STAND_FROM := 8.0
const TIERS := 9
const TIER_DEPTH := 1.5
const TIER_RISE := 0.95
const SPECTATOR_SCALE := 0.86


func _configure() -> void:
	level_name = "ArenaHexBowlLevel"
	level_path = "res://levels/ArenaHexBowlLevel.tscn"
	stem = "arena_hexbowl"


func _side_basis(k: int) -> Basis:
	var a := k * PI / 3.0
	var z := Vector3(cos(a), 0, sin(a))
	return Basis(Vector3.UP.cross(z).normalized(), Vector3.UP, z)


func _build(level: Node3D) -> void:
	game.set("kind", "football")
	game.set("match_seconds", 300.0)
	game.set_meta(&"outline", [_hex_outline(R)])
	_environment({
		"sky_top": Color(0.01, 0.015, 0.04), "sky_horizon": Color(0.08, 0.1, 0.2), "haze": Color(0.09, 0.1, 0.16),
		"ground_bottom": Color(0.02, 0.02, 0.03), "sun_color": Color(1.0, 0.97, 0.92), "sun_glow": 0.0,
		"cloud_lit": Color(0.2, 0.22, 0.3), "cloud_shade": Color(0.04, 0.05, 0.08), "cloud_coverage": 0.3,
		"ambient": 0.55, "ambient_color": Color(0.6, 0.65, 0.8), "exposure": 1.1, "glow": 0.7, "bloom": 0.08,
		"fog_begin": 160.0, "fog_end": 900.0, "fog_sky": 0.0,
		"sun_pitch": -62.0, "sun_yaw": 20.0, "sun_energy": 1.25, "shadow_distance": 180.0,
	})
	var arena := Node3D.new()
	arena.name = "Bowl"
	level.add_child(arena)
	_build_pitch(arena)
	_build_walls(arena)
	_build_goals()
	_build_play(arena)
	_build_stands(level, arena)
	_build_towers(arena)
	print("  hex bowl: %d goals, %d spawns" % [6, spawns.get_child_count()])


static func _hex_outline(r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rc := r / 0.8660254
	for k in 6:
		var a := k * PI / 3.0 + PI / 6.0
		out.append(Vector2(cos(a), sin(a)) * rc)
	return out


func _build_pitch(arena: Node3D) -> void:
	# One floor body under the pitch and the goals' pockets, the pitch drawn on a hexagon over it.
	box(arena, "PitchTrack", Vector3(320, 2, 320), Transform3D(Basis(), Vector3(0, -1.0, 0)), mat("floor", Color(0.1, 0.1, 0.12)), "asphalt", true, false)
	var outline := _hex_outline(R + 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 6:
		var a := outline[k]
		var b := outline[(k + 1) % 6]
		st.add_vertex(Vector3(0, 0.01, 0))
		st.add_vertex(Vector3(a.x, 0.01, a.y))
		st.add_vertex(Vector3(b.x, 0.01, b.y))
	var mi := MeshInstance3D.new()
	mi.name = "PitchGround"
	mi.mesh = _save_res(st.commit(), "pitch_mesh")
	var sm := ShaderMaterial.new()
	sm.shader = load("res://arena_pitch.gdshader")
	sm.set_shader_parameter("inradius", R)
	sm.set_shader_parameter("grain", load("res://materials/grass.png"))
	mi.material_override = _save_res(sm, "pitch_material")
	arena.add_child(mi)
	# The concourse round the walls, under the stands.
	var ring := SurfaceTool.new()
	ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	ring.set_normal(Vector3.UP)
	var inner := _hex_outline(R + 1.0)
	var outer := _hex_outline(R + 60.0)
	for k in 6:
		var a0 := inner[k]
		var a1 := inner[(k + 1) % 6]
		var b0 := outer[k]
		var b1 := outer[(k + 1) % 6]
		for v in [a0, b0, b1, a0, b1, a1]:
			ring.add_vertex(Vector3((v as Vector2).x, 0.0, (v as Vector2).y))
	var rmi := MeshInstance3D.new()
	rmi.name = "ConcourseGround"
	rmi.mesh = _save_res(ring.commit(), "concourse_mesh")
	rmi.material_override = tex_mat("concourse", "res://materials/concrete.png", Color(0.42, 0.43, 0.46), 6.0)
	arena.add_child(rmi)


func _build_walls(arena: Node3D) -> void:
	var pad := mat("pad", Color(0.08, 0.12, 0.3), 0.55)
	var stripe := mat("stripe", Color(0.2, 0.85, 1.0), 0.4, 0.0, 2.2)
	var glass := mat("glass", Color(0.7, 0.85, 1.0, 0.16), 0.05, 0.2)
	var frame := mat("frame", Color(0.5, 0.52, 0.58), 0.3, 0.8)
	var walls := Node3D.new()
	walls.name = "ArenaWalls"
	arena.add_child(walls)
	var half_side := RC * 0.5
	for k in 6:
		var b := _side_basis(k)
		var origin := b.z * R
		for sgn in [-1.0, 1.0]:
			var x0: float = GOAL_HALF + 0.6
			var x1: float = half_side + 1.0
			var mid: float = (x0 + x1) * 0.5 * sgn
			var seg_len: float = x1 - x0
			var c := origin + b.x * mid
			var xf := Transform3D(b, c + b.z * 0.5 + Vector3(0, WALL_PAD * 0.5, 0))
			box(walls, "Wall%d_%d" % [k, int(sgn)], Vector3(seg_len, WALL_PAD, 1.0), xf, pad, "rock")
			deco_box(walls, Vector3(seg_len, 0.22, 0.12), Transform3D(b, c + Vector3(0, WALL_PAD - 0.2, -0.02)), stripe)
			deco_box(walls, Vector3(seg_len, GLASS_TOP - WALL_PAD, 0.08), Transform3D(b, c + b.z * 0.3 + Vector3(0, (GLASS_TOP + WALL_PAD) * 0.5, 0)), glass)
			deco_box(walls, Vector3(seg_len, 0.18, 0.25), Transform3D(b, c + b.z * 0.3 + Vector3(0, GLASS_TOP, 0)), frame)
			# The glass's collider, and the invisible screen over it up to the lid.
			box(walls, "Screen%d_%d" % [k, int(sgn)], Vector3(seg_len, LID - WALL_PAD, 1.0),
				Transform3D(b, c + b.z * 0.5 + Vector3(0, (LID + WALL_PAD) * 0.5, 0)), glass, "rock", false, false)
		# Over the goal's mouth.
		box(walls, "Lintel%d" % k, Vector3(GOAL_HALF * 2.0 + 1.4, LID - GOAL_H, 1.0),
			Transform3D(b, origin + b.z * 0.5 + Vector3(0, (LID + GOAL_H) * 0.5, 0)), glass, "rock", false, false)
		deco_box(walls, Vector3(GOAL_HALF * 2.0 + 1.2, GLASS_TOP - GOAL_H - 0.4, 0.08), Transform3D(b, origin + b.z * 0.3 + Vector3(0, (GLASS_TOP + GOAL_H + 0.4) * 0.5, 0)), glass)
	box(walls, "Lid", Vector3(260, 1, 260), Transform3D(Basis(), Vector3(0, LID + 0.5, 0)), pad, "rock", false, false)


func _build_goals() -> void:
	var goals := Node3D.new()
	goals.name = "Goals"
	game.add_child(goals)
	var white := mat("post", Color(0.95, 0.95, 0.97), 0.3, 0.2)
	var dark := mat("goal_dark", Color(0.05, 0.06, 0.08), 0.8)
	var net_scene: Script = load("res://GoalNet.gd")
	for k in 6:
		var b := _side_basis(k)
		var g := Node3D.new()
		g.name = "Goal_%d" % k
		g.transform = Transform3D(b, b.z * R)
		g.set_meta(&"half_width", GOAL_HALF)
		g.set_meta(&"height", GOAL_H)
		goals.add_child(g)
		for sx in [-1.0, 1.0]:
			var post := cyl(g, 0.22, 0.22, GOAL_H, Transform3D(Basis(), Vector3(sx * (GOAL_HALF + 0.22), GOAL_H * 0.5, 0)), white, 12)
			post.add_to_group(&"arena_paint", true)
			# The pocket's sides (solid) behind each post.
			var side := StaticBody3D.new()
			side.name = "PocketSide%d" % int(sx)
			side.set_meta(&"surface", "rock")
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.6, GOAL_H + 0.5, GOAL_D + 1.0)
			cs.shape = bs
			side.position = Vector3(sx * (GOAL_HALF + 0.75), (GOAL_H + 0.5) * 0.5, (GOAL_D + 1.0) * 0.5)
			side.add_child(cs)
			g.add_child(side)
			deco_box(side, Vector3(0.6, GOAL_H + 0.5, GOAL_D + 1.0), Transform3D(), dark)
		var bar := deco_box(g, Vector3(GOAL_HALF * 2.0 + 0.88, 0.44, 0.44), Transform3D(Basis(), Vector3(0, GOAL_H + 0.22, 0)), white)
		bar.add_to_group(&"arena_paint", true)
		var line := deco_box(g, Vector3(GOAL_HALF * 2.0, 0.04, 0.5), Transform3D(Basis(), Vector3(0, 0.03, -0.3)), white)
		line.add_to_group(&"arena_paint", true)
		var back := StaticBody3D.new()
		back.name = "PocketBack"
		back.set_meta(&"surface", "rock")
		var bcs := CollisionShape3D.new()
		var bbs := BoxShape3D.new()
		bbs.size = Vector3(GOAL_HALF * 2.0 + 2.0, GOAL_H + 0.5, 0.6)
		bcs.shape = bbs
		back.position = Vector3(0, (GOAL_H + 0.5) * 0.5, GOAL_D + 1.2)
		back.add_child(bcs)
		g.add_child(back)
		deco_box(back, bbs.size, Transform3D(), dark)
		var roof := deco_box(g, Vector3(GOAL_HALF * 2.0 + 2.0, 0.3, GOAL_D + 1.4), Transform3D(Basis(), Vector3(0, GOAL_H + 0.65, (GOAL_D + 1.0) * 0.5)), dark)
		roof.name = "PocketRoof"
		var net := Node3D.new()
		net.name = "Net"
		net.set_script(net_scene)
		net.set("half_width", GOAL_HALF)
		net.set("height", GOAL_H)
		net.set("top_depth", 2.0)
		net.set("depth", GOAL_D)
		g.add_child(net)
		# Spawn k faces the middle from in front of goal k.
		spawn(b.z * (R - 12.0) + Vector3(0, 0.6, 0), Vector3.ZERO)


func _build_play(arena: Node3D) -> void:
	var play := Node3D.new()
	play.name = "Pinball"
	arena.add_child(play)
	for k in 3:
		var a := k * TAU / 3.0 + PI / 2.0
		bumper(play, "PopBumper%d" % k, Transform3D(Basis(), Vector3(cos(a), 0, sin(a)) * 14.0), 2.0, 0.0, Color(1.0, 0.3, 0.75), 18.0)
	for k in 6:
		var a := k * PI / 3.0 + PI / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		var at := dir * (RC - 5.0)
		bumper(play, "Slingshot%d" % k, facing(at, Vector3.ZERO), 1.4, 17.5, Color(1.0, 0.75, 0.15), 16.0)
		# Behind the bar: the corner filled in, so nothing gets stuck there.
		box(play, "CornerFill%d" % k, Vector3(17.5, WALL_PAD, 4.0), facing(dir * (RC - 2.6) + Vector3(0, WALL_PAD * 0.5, 0), Vector3.ZERO), mat("pad", Color()), "rock")
		fan(play, "Fan%d" % k, Transform3D(Basis(), dir * 30.0), 28.0, 0.0, 3.2)
		item_spot(dir * 20.0)
	var balls := Node3D.new()
	balls.name = "Balls"
	game.add_child(balls)
	for i in 2:
		var ball := RigidBody3D.new()
		ball.name = "Ball_%d" % i
		ball.set_script(load("res://KickBall.gd"))
		ball.set("style", 2)
		ball.position = Vector3(0, 3.0 + i * 2.0, 0)
		balls.add_child(ball)
	var bs := Marker3D.new()
	bs.name = "BallSpawn"
	bs.position = Vector3(0, 0.5, 0)
	game.add_child(bs)


func _build_stands(level: Node3D, arena: Node3D) -> void:
	var stands := Node3D.new()
	stands.name = "Stands"
	arena.add_child(stands)
	var seat_cols := [mat("seat_a", Color(0.12, 0.2, 0.55), 0.6), mat("seat_b", Color(0.75, 0.12, 0.14), 0.6)]
	var conc := tex_mat("stand", "res://materials/concrete.png", Color(0.55, 0.56, 0.6), 4.0)
	var people: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in 6:
		var b := _side_basis(k)
		for t in TIERS:
			var d := R + STAND_FROM + t * TIER_DEPTH + TIER_DEPTH * 0.5
			var top := GLASS_TOP - 3.0 + t * TIER_RISE
			var seg_len := 2.0 * d * tan(PI / 6.0)
			var c := b.z * d + Vector3(0, top * 0.5, 0)
			deco_box(stands, Vector3(seg_len, top, TIER_DEPTH), Transform3D(b, c), conc)
			deco_box(stands, Vector3(seg_len - 1.0, 0.35, TIER_DEPTH * 0.5), Transform3D(b, b.z * (d + 0.2) + Vector3(0, top + 0.17, 0)), seat_cols[(k + t / 3) % 2])
			var n := int((seg_len - 4.0) / 1.25)
			for i in n:
				if rng.randf() < 0.12:
					continue
				var x := -seg_len * 0.5 + 2.0 + (i + 0.5) * (seg_len - 4.0) / n
				var p := b.z * (d - 0.15) + b.x * x + Vector3(0, top + 0.05, 0)
				people.append([p, -b.z, true, true, -1, rng.randf_range(0.94, 1.05)])
		# The back wall over the top tier, an LED ribbon along it.
		var d_back := R + STAND_FROM + TIERS * TIER_DEPTH + 0.5
		var top_back := GLASS_TOP - 3.0 + TIERS * TIER_RISE + 3.0
		var seg_len_b := 2.0 * d_back * tan(PI / 6.0)
		deco_box(stands, Vector3(seg_len_b, top_back, 1.0), Transform3D(b, b.z * d_back + Vector3(0, top_back * 0.5, 0)), conc)
		deco_box(stands, Vector3(seg_len_b - 2.0, 1.4, 0.1), Transform3D(b, b.z * (d_back - 0.56) + Vector3(0, top_back - 1.6, 0)), mat("ribbon%d" % (k % 3), [Color(0.2, 0.85, 1.0), Color(1.0, 0.35, 0.75), Color(0.6, 1.0, 0.3)][k % 3], 0.4, 0.0, 2.5))
		# Under the first tier: the wall between the concourse and the stand, with the arena's name.
		var lab := Label3D.new()
		lab.text = "HEX BOWL" if k % 2 == 0 else "RC VIBE GP ARENA"
		lab.font_size = 160
		lab.pixel_size = 0.02
		lab.modulate = Color(0.85, 0.95, 1.0)
		lab.outline_size = 0
		lab.transform = Transform3D(b.rotated(Vector3.UP, PI), b.z * (R + STAND_FROM - 0.05) + Vector3(0, 3.6, 0))
		stands.add_child(lab)
	var crowd: Node3D = load("res://CrowdPlacer.gd").build(level, people, SPECTATOR_SCALE, [0.15, 0.15, 0.4, 0.2, 0.1], 77,
		func(res: Resource, n: String) -> Resource: return _save_res(res, "crowd_" + n))
	print("  crowd: %d" % people.size())
	if crowd and crowd.get_parent() == null:
		level.add_child(crowd)


func _build_towers(arena: Node3D) -> void:
	var steel := mat("tower", Color(0.3, 0.32, 0.36), 0.4, 0.7)
	var lamp := mat("lamp", Color(1.0, 0.97, 0.9), 0.3, 0.0, 6.0)
	for k in 6:
		var a := k * PI / 3.0 + PI / 6.0
		var dir := Vector3(cos(a), 0, sin(a))
		var at := dir * (RC + 26.0)
		cyl(arena, 0.7, 1.1, 40.0, Transform3D(Basis(), at + Vector3(0, 20.0, 0)), steel, 10)
		var head := facing(at + Vector3(0, 40.0, 0), Vector3(0, 0, 0))
		deco_box(arena, Vector3(9.0, 4.0, 0.6), head, steel)
		deco_box(arena, Vector3(8.4, 3.4, 0.2), Transform3D(head.basis, head.origin - head.basis.z * 0.35), lamp)
		var light := OmniLight3D.new()
		light.position = at + Vector3(0, 36.0, 0) - dir * 6.0
		light.omni_range = 95.0
		light.light_energy = 1.1
		light.light_color = Color(1.0, 0.96, 0.9)
		light.shadow_enabled = false
		arena.add_child(light)
