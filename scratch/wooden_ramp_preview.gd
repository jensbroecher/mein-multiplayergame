extends SceneTree
## Renders WoodenRamp.gd's three kinds side by side on a flat grey road in a second or two: a kicker, a
## table-top and a roller (the Lakeside bridge's shapes). Windowed:
##   Godot --path . --resolution 1600x900 -s res://scratch/wooden_ramp_preview.gd -- <dir> name:x,y,z:tx,ty,tz ...
## The ramps' toes are at z = 0, x = -18, 0 and 18; they rise toward -z. Prints each one's triangles.

const KINDS := [
	["kicker", Vector3(-18, 0, 0), {"length": 7.0, "height": 1.4, "width": 15.0, "curve": 0.6}],
	["table", Vector3(0, 0, 0), {"length": 6.0, "height": 1.2, "width": 15.0, "curve": 0.5, "table_length": 5.0, "tail_length": 6.0}],
	["roller", Vector3(18, 0, 0), {"length": 5.0, "height": 0.9, "width": 15.0, "curve": 0.7, "tail_length": 5.0}],
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "/tmp/wooden_ramp"
	DirAccess.make_dir_recursive_absolute(dir)
	var shots: Array = []
	for a in args.slice(1):
		var parts := String(a).split(":")
		if parts.size() >= 3:
			var p := parts[1].split_floats(",")
			var t := parts[2].split_floats(",")
			shots.append([parts[0], Vector3(p[0], p[1], p[2]), Vector3(t[0], t[1], t[2])])
	if shots.is_empty():
		shots = [["approach", Vector3(-8.0, 4.0, 14.0), Vector3(0, 0.5, -6)], ["side", Vector3(34.0, 3.0, -8.0), Vector3(0, 0.6, -7)],
				["back", Vector3(-10.0, 4.0, -24.0), Vector3(-16, 0.5, -4)], ["close", Vector3(-12.0, 1.6, 3.0), Vector3(-18, 0.6, -4)]]

	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(-140.0), 0.0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var road := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	road.mesh = plane
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.25, 0.25, 0.26)
	rm.roughness = 0.9
	road.material_override = rm
	root.add_child(road)

	# The ramps build themselves in _ready, once the tree is running.
	await process_frame
	var scene: PackedScene = load("res://WoodenRamp.tscn")
	for k in KINDS:
		var ramp := scene.instantiate()
		ramp.name = "Ramp_" + k[0]
		ramp.set("settle_on_track", false)
		ramp.set("face_lap", false)
		for p in k[2]:
			ramp.set(p, k[2][p])
		ramp.position = k[1]
		root.add_child(ramp)
		var mi: MeshInstance3D = null
		for c in ramp.get_children(true):
			if c is MeshInstance3D:
				mi = c
		var tris := 0
		for si in range(mi.mesh.get_surface_count()):
			tris += (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		var lip: Dictionary = ramp.call("lip_info")
		print("%s: %d triangles, %d surfaces, lip %s dir %s (%.1f deg)" % [k[0], tris, mi.mesh.get_surface_count(), lip["lip"], lip["dir"],
				rad_to_deg(asin((lip["dir"] as Vector3).y))])

	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.current = true
	for i in range(40):
		await process_frame
	for s in shots:
		cam.look_at_from_position(s[1], s[2])
		for i in range(4):
			await process_frame
		var img := get_root().get_texture().get_image()
		var path: String = dir.path_join("%s.png" % s[0])
		img.save_png(path)
		print("SHOT ", path)
	quit()
