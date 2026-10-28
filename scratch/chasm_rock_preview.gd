extends SceneTree
# -s windowed: -- <dir> [fbx=1] [kind=0..3] [seed=N]  renders Canyon Chasm's rocks (ChasmRock.gd), one kind
# per shot pair, building each in memory (prints how long); fbx=1 stands the old imported model beside it
# (while it still exists) for comparison.
const FBX := ["res://models/desert/462b0835dae4689feaf62903546389ee.fbx", "res://models/desert/0c797c60dd8eef1acae70d532301f210.fbx",
	"res://models/desert/8fc36b06f12d9b9e49c5877a89ef126c.fbx", "res://models/desert/5de45969eb67cee87dc8ebbdd862dc99.fbx"]
const FBX_SCALE := [30.0, 25.0, 31.0, 20.0]
const NAMES := ["cluster", "tor", "arch", "mossy"]
func _initialize():
	var args = OS.get_cmdline_user_args()
	var dir = args[0]
	var with_fbx := args.has("fbx=1")
	var kinds := [0, 1, 2, 3]
	var seed_v := 1
	for a in args:
		if a.begins_with("kind="): kinds = [int(a.substr(5))]
		if a.begins_with("seed="): seed_v = int(a.substr(5))
	var w = Node3D.new(); root.add_child(w)
	var env = WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	w.add_child(env)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -40, 0); sun.shadow_enabled = true; w.add_child(sun)
	var floor = MeshInstance3D.new(); var pm = PlaneMesh.new(); pm.size = Vector2(400, 400); floor.mesh = pm
	var fm = StandardMaterial3D.new(); fm.albedo_color = Color(0.72, 0.52, 0.40); floor.material_override = fm
	w.add_child(floor)
	var cam = Camera3D.new(); w.add_child(cam); cam.current = true
	for k in kinds:
		var r = load("res://ChasmRock.gd").new()
		r.kind = k
		r.rock_seed = seed_v
		var t0 := Time.get_ticks_msec()
		w.add_child(r)
		var tris := 0
		for c in r.get_children(true):
			for mi in c.find_children("*", "MeshInstance3D", true, false):
				tris = mi.mesh.get_faces().size() / 3
		print("%s: built in %d ms, %d triangles" % [NAMES[k], Time.get_ticks_msec() - t0, tris])
		var old = null
		if with_fbx and ResourceLoader.exists(FBX[k]):
			old = load(FBX[k]).instantiate()
			old.scale = Vector3.ONE * FBX_SCALE[k]
			old.position = Vector3(40, 0, 0)
			w.add_child(old)
		var c := Vector3(20 if old else 0, 6, 0)
		for v in [["a", Vector3(0.3, 0.45, 1)], ["b", Vector3(-0.6, 0.3, -1)]]:
			cam.position = c + v[1].normalized() * (75.0 if old else 45.0)
			cam.look_at(c)
			for i in 40: await process_frame
			root.get_texture().get_image().save_png("%s/rock_%s_%s.png" % [dir, NAMES[k], v[0]])
		r.queue_free()
		if old: old.queue_free()
	quit()
