extends SceneTree
## Triangle budget of StadtKit's Hauptbahnhof and Kaufhaus by part (headless): -s res://scratch/stadt_hbf_budget.gd

const SK = preload("res://StadtKit.gd")


func _init() -> void:
	var parts: Array = [
		["wings", func(pk, kit, labels): SK._hb_wings(pk, kit)],
		["central", func(pk, kit, labels): SK._hb_central(pk, kit, labels)],
		["tower", func(pk, kit, labels): SK._hb_tower(pk, kit)],
		["pavilions", func(pk, kit, labels): SK._hb_pavilions(pk, kit)],
		["roof", func(pk, kit, labels): SK._hb_roof(pk, kit)],
		["canopy", func(pk, kit, labels): SK._hb_canopy(pk, kit, labels)],
		["block", func(pk, kit, labels): SK._hb_block(pk, kit, labels)],
		["platforms", func(pk, kit, labels): SK._hb_platforms(pk, kit, labels)],
		["sheds", func(pk, kit, labels): SK._hb_sheds(pk, kit)],
		["rails", func(pk, kit, labels): SK._hb_rails(pk, kit)],
	]
	for p in parts:
		var pk = SK.new_kit(1.6)
		var kit := {}
		var labels: Array = []
		(p[1] as Callable).call(pk, kit, labels)
		var t := 0
		var per := {}
		for key in kit.keys():
			var s: SurfaceTool = kit[key]
			var arr: Array = s.commit_to_arrays()
			var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			per[key] = n
			t += n
		print("%-10s %6d  %s" % [p[0], t, str(per)])
	quit()
