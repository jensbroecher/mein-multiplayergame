extends SceneTree
## Saves ScrapKit's props as life-size meshes (new_kit(1.0)) for scratch/zfight_scan.gd:
##   Godot --headless --path . -s res://scratch/scrap_mesh_dump.gd -- <dir> [only=crane,ruin,...]
##   Godot --headless --path . -s res://scratch/zfight_scan.gd -- <dir>/scrap_crane.res ... tol=0.004 detail=1

var SK: Script


func _init() -> void:
	SK = load("res://ScrapKit.gd")
	var args := OS.get_cmdline_user_args()
	var dir: String = "/tmp/scrap_meshes"
	var only: Array = []
	for a in args:
		if a.begins_with("only="):
			only = Array(a.substr(5).split(","))
		else:
			dir = a
	DirAccess.make_dir_recursive_absolute(dir)
	var props := {
		"crane": ["crawler_crane", [[]]], "ball": ["wrecking_ball", [29.3]], "ruin": ["ruin_building", [[], 7]], "rubble": ["rubble_heap", [16.0, 12.0, 4.5, 3]],
		"skip": ["skip", [2]], "bales": ["bale_wall", [12.0, 4, 9]], "heap": ["scrap_heap", [22.0, 14.0, 7.0, 5]], "handler": ["material_handler", [[]]],
		"upper": ["material_handler_upper", []], "magnet": ["scrap_magnet", [3]], "press": ["car_press", [[]]], "office": ["scrapyard_office", [[]]],
		"weigh": ["weighbridge", [[]]], "fence": ["scrap_fence", [12.5]], "bin": ["sorting_bin", [4]], "drums": ["drum_stack", [4]], "tyres": ["tyre_pile", [4]],
	}
	for name in props.keys():
		if not only.is_empty() and not only.has(name):
			continue
		var pk = SK.new_kit(1.0)
		var kit := {}
		SK.callv(props[name][0], [pk, kit] + (props[name][1] as Array))
		var mesh: ArrayMesh = SK.commit(pk, kit)
		var path := "%s/scrap_%s.res" % [dir, name]
		ResourceSaver.save(mesh, path)
		print("saved ", path)
	quit()
