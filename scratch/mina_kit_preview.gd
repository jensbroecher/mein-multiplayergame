extends SceneTree
## Renders MinaKit.gd's set pieces on a flat desert floor in a few seconds, without generating the level. Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/mina_kit_preview.gd -- <dir> [set=truck,shovel,...]
##       [scale=1] [sun=<pitch>,<yaw>] name:x,y,z:tx,ty,tz[:fov] ...
## Each piece stands at its own spot along x (SPOTS), front toward -z, at life size times `scale`.

const MinaKit = preload("res://MinaKit.gd")

## [name, x position] for each piece the preview can build.
const SPOTS := {
	"truck": 0.0, "truckload": 30.0, "shovel": 70.0, "dish": 130.0, "balloon": 190.0, "balloonlow": 230.0,
	"conveyor": 280.0, "light": 330.0, "drill": 360.0, "tumbleweed": 390.0, "watertruck": 420.0, "gate": 460.0, "guardhouse": 500.0,
	"crusher": 520.0, "shop": 600.0, "stockpile": 700.0, "signs": 780.0,
}


func _build(which: String, sc: float) -> Node3D:
	var pk = MinaKit.new_kit(sc)
	var kit := {}
	match which:
		"truck":
			MinaKit.haul_truck(pk, kit)
		"truckload":
			MinaKit.haul_truck(pk, kit, MinaKit.MINE_YELLOW, true, 0.7)
		"watertruck":
			MinaKit.water_truck(pk, kit)
		"shovel":
			MinaKit.rope_shovel(pk, kit)
		"dish":
			MinaKit.radio_dish(pk, kit, deg_to_rad(40.0), deg_to_rad(52.0))
		"balloon":
			MinaKit.balloon(pk, kit, 0, Basis(), true)
		"balloonlow":
			MinaKit.balloon_inflating(pk, kit, 1)
		"light":
			MinaKit.light_tower(pk, kit)
		"drill":
			MinaKit.drill_rig(pk, kit)
		"tumbleweed":
			MinaKit.tumbleweed(pk, kit, 3)
		"gate":
			MinaKit.mine_gate(pk, kit, [])
		"guardhouse":
			MinaKit.guard_house(pk, kit, [])
		"crusher":
			MinaKit.crusher(pk, kit, [])
		"shop":
			MinaKit.truck_shop(pk, kit, [])
		"stockpile":
			MinaKit.stockpile(pk, kit, 22.0)
		"conveyor":
			MinaKit.conveyor_run(pk, kit, [Vector3(0, 2.0, 20), Vector3(0, 2.0, 0), Vector3(0, 14.0, -40)], [1])
		"signs":
			MinaKit.sign_board(pk, kit, Vector3.ZERO, 0.0, "warn")
	var mi := MeshInstance3D.new()
	mi.mesh = pk.commit(kit)
	var n := Node3D.new()
	n.add_child(mi)
	print("%s: %d surfaces, aabb %s" % [which, mi.mesh.get_surface_count(), mi.mesh.get_aabb()])
	return n


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "/tmp/mina_kit"
	DirAccess.make_dir_recursive_absolute(dir)
	var which: Array = ["truck"]
	var sc := 1.0
	var sun_rot := Vector2(-28.0, 120.0)
	var shots: Array = []
	for a in args.slice(1):
		if a.begins_with("set="):
			which = Array(a.substr(4).split(","))
		elif a.begins_with("scale="):
			sc = float(a.substr(6))
		elif a.begins_with("sun="):
			var sv := a.substr(4).split_floats(",")
			sun_rot = Vector2(sv[0], sv[1])
		else:
			var parts := String(a).split(":")
			if parts.size() >= 3:
				var p := parts[1].split_floats(",")
				var t := parts[2].split_floats(",")
				shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2]), float(parts[3]) if parts.size() > 3 else 50.0])
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	var psky := ProceduralSkyMaterial.new()
	psky.sky_top_color = Color(0.22, 0.36, 0.66)
	psky.sky_horizon_color = Color(0.95, 0.76, 0.6)
	psky.ground_horizon_color = Color(0.8, 0.66, 0.54)
	env.sky.sky_material = psky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(sun_rot.x), deg_to_rad(sun_rot.y), 0.0)
	sun.light_color = Color(1.0, 0.86, 0.7)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300.0
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.70, 0.55, 0.42)
	gm.roughness = 0.95
	ground.material_override = gm
	root.add_child(ground)
	for w in which:
		var n := _build(w, sc)
		n.position = Vector3(float(SPOTS.get(w, 0.0)), 0.0, 0.0)
		root.add_child(n)
	var cam := Camera3D.new()
	cam.far = 3000.0
	root.add_child(cam)
	cam.make_current()
	if shots.is_empty():
		var x0: float = float(SPOTS.get(which[0], 0.0))
		shots = [["front", Vector3(x0 - 14, 7, -22), Vector3(x0, 4, 0), 50.0], ["side", Vector3(x0 + 26, 9, 6), Vector3(x0, 4, 0), 50.0],
				["rear", Vector3(x0 + 12, 12, 22), Vector3(x0, 3, 0), 50.0]]
	for i in range(40):
		await process_frame
	for s in shots:
		cam.fov = s[3]
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		for i in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s/%s.png" % [dir, s[0]])
		print("SHOT ", s[0])
	quit()
