extends Node

const SIZE := Vector2i(1376, 768)

const STAGE_VIEWS := {
	"res://levels/LakesideLevel.tscn": [
		# shot 0: Inspect view from finish line looking down straight toward lake & hills
		{"name": "lakeside_start", "from": Vector3(28.2, 11.0, 132.3), "to": Vector3(10.9, 1.5, 64.5), "fov": 58.0},
		# shot 1: Iconic bridge apex overlooking lake & wind turbine hill
		{"name": "lakeside_bridge", "from": Vector3(-430.0, 24.5, -450.0), "to": Vector3(-470.0, 45.0, -740.0), "fov": 50.0},
		# shot 2: Overlooking paddock and lake
		{"name": "lakeside_paddock", "from": Vector3(50.0, 18.0, 140.0), "to": Vector3(0.0, 2.0, 80.0), "fov": 62.0},
	],
	"res://levels/PinecrestRidgeLevel.tscn": [
		{"name": "pinecrest_start", "from": Vector3(0.0, 10.0, 185.0), "to": Vector3(0.0, 1.0, 115.0), "fov": 58.0},
		{"name": "pinecrest_hillclimb", "from": Vector3(25.0, 22.0, 70.0), "to": Vector3(-20.0, 8.0, 20.0), "fov": 60.0},
		{"name": "pinecrest_ridge", "from": Vector3(-40.0, 35.0, -50.0), "to": Vector3(10.0, 15.0, -120.0), "fov": 62.0},
	],
	"res://levels/HarborPierLevel.tscn": [
		{"name": "harbor_start", "from": Vector3(-75.0, 13.5, -95.0), "to": Vector3(-5.0, 4.0, -95.0), "fov": 58.0},
		{"name": "harbor_piers", "from": Vector3(-40.0, 22.0, -150.0), "to": Vector3(10.0, 5.0, -80.0), "fov": 62.0},
		{"name": "harbor_dock", "from": Vector3(20.0, 16.0, -60.0), "to": Vector3(-50.0, 4.0, -90.0), "fov": 60.0},
	],
	"res://levels/BloombayDunesLevel.tscn": [
		{"name": "bloombay_start", "from": Vector3(-42.0, 11.0, 185.0), "to": Vector3(-42.0, 1.5, 115.0), "fov": 58.0},
		{"name": "bloombay_ocean", "from": Vector3(-15.0, 18.0, 130.0), "to": Vector3(-80.0, 2.0, 60.0), "fov": 62.0},
		{"name": "bloombay_dunes", "from": Vector3(-70.0, 25.0, -20.0), "to": Vector3(-10.0, 8.0, -90.0), "fov": 60.0},
	],
	"res://levels/FrostpeakCreekLevel.tscn": [
		{"name": "frostpeak_start", "from": Vector3(-45.0, 11.0, 145.0), "to": Vector3(-45.0, 1.5, 75.0), "fov": 58.0},
		{"name": "frostpeak_bridge", "from": Vector3(-20.0, 18.0, 90.0), "to": Vector3(-70.0, 3.0, 20.0), "fov": 60.0},
		{"name": "frostpeak_creek", "from": Vector3(-60.0, 22.0, -40.0), "to": Vector3(-10.0, 6.0, -110.0), "fov": 62.0},
		{"name": "frostpeak_alpine_bridge", "from": Vector3(25.0, 9.0, -280.0), "to": Vector3(-10.0, 5.0, -310.0), "fov": 55.0},
		{"name": "frostpeak_glade_bridge", "from": Vector3(18.0, 6.5, 220.0), "to": Vector3(-15.0, 2.5, 195.0), "fov": 55.0},
	],
	"res://levels/GlacierHighwayLevel.tscn": [
		{"name": "glacier_start", "from": Vector3(-84.9, 13.0, 303.0), "to": Vector3(-85.2, 3.5, 233.0), "fov": 58.0},
		{"name": "glacier_overpass", "from": Vector3(-50.0, 28.0, 200.0), "to": Vector3(-110.0, 8.0, 120.0), "fov": 62.0},
		{"name": "glacier_curve", "from": Vector3(-120.0, 20.0, 80.0), "to": Vector3(-60.0, 5.0, 0.0), "fov": 60.0},
	],
	"res://levels/NorthlightCavernsLevel.tscn": [
		{"name": "northlight_start", "from": Vector3(-112.0, 13.0, 453.0), "to": Vector3(-112.0, 3.5, 383.0), "fov": 60.0},
		{"name": "northlight_aurora_spire", "from": Vector3(-70.0, 28.0, 340.0), "to": Vector3(-130.0, 15.0, 260.0), "fov": 64.0},
		{"name": "northlight_crevasse", "from": Vector3(-130.0, 22.0, 200.0), "to": Vector3(-80.0, 8.0, 130.0), "fov": 62.0},
	],
	"res://levels/FrostfallGorgeLevel.tscn": [
		{"name": "frostfall_start", "from": Vector3(188.8, 12.0, 191.0), "to": Vector3(192.4, 2.5, 121.1), "fov": 58.0},
		{"name": "frostfall_waterfall", "from": Vector3(160.0, 26.0, 100.0), "to": Vector3(210.0, 8.0, 30.0), "fov": 62.0},
		{"name": "frostfall_canyon", "from": Vector3(220.0, 30.0, -10.0), "to": Vector3(170.0, 10.0, -80.0), "fov": 60.0},
	],
	"res://levels/MountainLevel.tscn": [
		{"name": "mountain_start", "from": Vector3(187.9, 23.6, -228.4), "to": Vector3(233.3, 16.2, -175.2), "fov": 58.0},
		{"name": "mountain_ridge", "from": Vector3(150.0, 35.0, -180.0), "to": Vector3(240.0, 20.0, -120.0), "fov": 62.0},
		{"name": "mountain_pass", "from": Vector3(220.0, 38.0, -80.0), "to": Vector3(140.0, 18.0, -20.0), "fov": 60.0},
		{"name": "mountain_summit", "from": Vector3(40.0, 145.0, -60.0), "to": Vector3(-10.0, 120.0, -110.0), "fov": 64.0},
	],
	"res://levels/CanyonLevel.tscn": [
		{"name": "canyon_start", "from": Vector3(-150.0, 17.0, -60.0), "to": Vector3(-150.0, 8.0, 10.0), "fov": 58.0},
		{"name": "canyon_bridge", "from": Vector3(-120.0, 28.0, -10.0), "to": Vector3(-180.0, 12.0, 70.0), "fov": 62.0},
		{"name": "canyon_shelf", "from": Vector3(-180.0, 36.0, 120.0), "to": Vector3(-120.0, 16.0, 200.0), "fov": 60.0},
	],
	"res://levels/CanyonChasmLevel.tscn": [
		{"name": "canyon_chasm_start", "from": Vector3(0.0, 15.0, 201.3), "to": Vector3(0.0, 5.5, 131.3), "fov": 58.0},
		{"name": "canyon_chasm_village", "from": Vector3(-196.0, 22.0, 44.0), "to": Vector3(-226.5, 17.5, 65.0), "fov": 60.0},
		{"name": "canyon_chasm_pit", "from": Vector3(135.0, 24.0, -56.0), "to": Vector3(162.0, 2.0, -108.0), "fov": 60.0},
	],
	"res://levels/DesertWadiLevel.tscn": [
		{"name": "desert_wadi_start", "from": Vector3(291.9, 15.0, -193.0), "to": Vector3(292.2, 5.5, -123.0), "fov": 58.0},
		{"name": "desert_wadi_arch", "from": Vector3(260.0, 24.0, -140.0), "to": Vector3(320.0, 8.0, -70.0), "fov": 62.0},
		{"name": "desert_wadi_canyon", "from": Vector3(320.0, 22.0, -50.0), "to": Vector3(270.0, 6.0, 20.0), "fov": 60.0},
		{"name": "desert_wadi_sweep", "from": Vector3(60.0, 16.0, 165.0), "to": Vector3(0.0, 6.0, 125.0), "fov": 58.0},
		{"name": "desert_wadi_dunes", "from": Vector3(270.0, 18.0, -70.0), "to": Vector3(210.0, 6.0, 30.0), "fov": 58.0},
	],
	"res://levels/MaraCrossingLevel.tscn": [
		{"name": "mara_start", "from": Vector3(0.0, 16.0, 225.0), "to": Vector3(0.0, 7.0, 155.0), "fov": 58.0},
		{"name": "mara_migration", "from": Vector3(160.0, 18.0, -20.0), "to": Vector3(200.0, 8.0, -60.0), "fov": 60.0},
		{"name": "mara_savanna", "from": Vector3(-30.0, 22.0, 120.0), "to": Vector3(50.0, 9.0, 40.0), "fov": 62.0},
	],
	"res://levels/NyotaStadiumLevel.tscn": [
		{"name": "nyota_start", "from": Vector3(95.0, 10.5, 48.0), "to": Vector3(25.0, 1.5, 48.0), "fov": 58.0},
		{"name": "nyota_bowl", "from": Vector3(110.0, 24.0, 80.0), "to": Vector3(30.0, 4.0, 20.0), "fov": 64.0},
		{"name": "nyota_whoops", "from": Vector3(20.0, 16.0, -30.0), "to": Vector3(80.0, 3.0, 20.0), "fov": 62.0},
	],
	"res://levels/MsituFallsLevel.tscn": [
		{"name": "msitu_start", "from": Vector3(-82.7, 14.5, -127.7), "to": Vector3(-82.7, 5.0, -57.7), "fov": 58.0},
		{"name": "msitu_falls_view", "from": Vector3(-50.0, 24.0, -110.0), "to": Vector3(-120.0, 10.0, -40.0), "fov": 62.0},
		{"name": "msitu_jungle", "from": Vector3(-110.0, 20.0, -20.0), "to": Vector3(-60.0, 6.0, 50.0), "fov": 60.0},
	],
	"res://levels/MtaaNightsLevel.tscn": [
		{"name": "mtaa_club", "from": Vector3(-262.0, 14.0, 168.0), "to": Vector3(-345.0, 6.0, 128.0), "fov": 60.0},
		{"name": "mtaa_start", "from": Vector3(-60.0, 12.0, -242.0), "to": Vector3(-180.0, 3.0, -250.0), "fov": 58.0},
		{"name": "mtaa_market", "from": Vector3(150.0, 13.0, -40.0), "to": Vector3(150.0, 3.0, -150.0), "fov": 58.0},
	]
}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := "scratch/candidates"
	var target_stage := ""
	for a in args:
		if a.begins_with("stage="):
			target_stage = a.substr(6)
		elif not a.begins_with("-"):
			out_dir = a
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	AudioServer.set_bus_mute(0, true)
	
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	
	var cam := Camera3D.new()
	cam.far = 4000.0
	vp.add_child(cam)
	cam.make_current()
	
	for stage_path in STAGE_VIEWS.keys():
		if not target_stage.is_empty() and not stage_path.contains(target_stage):
			continue
			
		print("Rendering shots for stage: ", stage_path)
		var lvl: Node = load(stage_path).instantiate()
		vp.add_child(lvl)
		
		# Hide UI
		for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
			n.visible = false
		for n in lvl.find_children("*", "CanvasLayer", true, false):
			n.visible = false
			
		MusicManager.set_shadow_quality(3, false)
		MusicManager.set_grass_setting(4, false)
		
		# Weather tweak if needed
		var nw := lvl.get_node_or_null("NorthlightWeather")
		if nw:
			nw.force_intensity = 0.05
			
		# Wait 20 frames for shaders/particles/transforms to settle
		for i in 25:
			await get_tree().process_frame
			
		var views: Array = STAGE_VIEWS[stage_path]
		for v in views:
			cam.fov = v.get("fov", 60.0)
			cam.global_position = v["from"]
			cam.look_at(v["to"], Vector3.UP)
			for i in 15:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			
			var img: Image = vp.get_texture().get_image()
			var file_path := "%s/%s.png" % [out_dir, v["name"]]
			img.save_png(file_path)
			print("  Saved: ", file_path)
			
		vp.remove_child(lvl)
		lvl.queue_free()
		await get_tree().process_frame
		
	print("ALL SHOTS FINISHED")
	get_tree().quit()
