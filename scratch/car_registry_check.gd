extends SceneTree
## Checks that every car is registered everywhere a new car has to be (see "Procedural cars" in CLAUDE.md): the race
## presets (PlayerCart.CAR_PRESETS) and the select screen's (CarSelection.CAR_PRESETS) list the same cars in the same
## order with the same stats, Lobby.CAR_NAMES matches them, and each car has a weight, an accent colour, a factory
## paint, a builder in regenerate_cars.gd, a gallery in CarCollection (not "New Arrivals"), a description, and a model
## and an engine loop that load. Headless:
##   Godot --headless --path . -s res://scratch/car_registry_check.gd
## Prints one line per problem and RESULT: PASS or FAIL.

const STATS := ["max_speed", "acceleration", "steer_speed", "grip", "braking", "offroad"]


## In _initialize, not _init: PlayerCart.gd and CarSelection.gd name autoloads, which exist only once the tree does.
func _initialize() -> void:
	var race: Array = load("res://PlayerCart.gd").CAR_PRESETS
	var select_script: Script = load("res://CarSelection.gd")
	var select: Array = select_script.CAR_PRESETS
	var accents: Dictionary = select_script.CAR_ACCENTS
	var factory: Dictionary = load("res://CarPaint.gd").FACTORY
	var collection: Script = load("res://CarCollection.gd")
	var built := {}
	for car in load("res://regenerate_cars.gd").CARS:
		built["res://generated/cars/%s.tscn" % car["name"]] = car["name"]
	# Lobby.gd is a screen's script; its list is read as text, so nothing of the screen has to load here.
	var lobby: Array = []
	var rx := RegEx.new()
	rx.compile("const CAR_NAMES = \\[(.*)\\]")
	var m := rx.search(FileAccess.get_file_as_string("res://Lobby.gd"))
	if m:
		for part in m.get_string(1).split(","):
			lobby.append(part.strip_edges().trim_prefix("\"").trim_suffix("\""))
	var bad := 0
	if race.size() != select.size():
		bad += _fail("PlayerCart has %d presets, CarSelection %d" % [race.size(), select.size()])
	if lobby.size() != race.size():
		bad += _fail("Lobby.CAR_NAMES has %d names, PlayerCart %d presets" % [lobby.size(), race.size()])
	var placed := {}
	for cat in collection.CATEGORIES:
		for car_name in cat["cars"]:
			if placed.has(car_name):
				bad += _fail("%s is in two galleries" % car_name)
			placed[car_name] = cat["name"]
	var seen := {}
	for i in race.size():
		var p: Dictionary = race[i]
		var car_name: String = p["name"]
		if seen.has(car_name):
			bad += _fail("%s is in the presets twice" % car_name)
		seen[car_name] = true
		if i < select.size():
			var s: Dictionary = select[i]
			if s["name"] != car_name:
				bad += _fail("preset %d is %s in PlayerCart, %s in CarSelection" % [i, car_name, s["name"]])
			else:
				for key in STATS + ["model_path"]:
					if p.get(key) != s.get(key):
						bad += _fail("%s: %s is %s in PlayerCart, %s in CarSelection" % [car_name, key, p.get(key), s.get(key)])
				if str(s.get("desc", "")).is_empty():
					bad += _fail("%s has no description in CarSelection" % car_name)
		if i < lobby.size() and lobby[i] != car_name:
			bad += _fail("preset %d is %s in PlayerCart, %s in Lobby.CAR_NAMES" % [i, car_name, lobby[i]])
		if not p.has("weight"):
			bad += _fail("%s has no weight" % car_name)
		if not accents.has(car_name):
			bad += _fail("%s has no CAR_ACCENTS colour" % car_name)
		if not placed.has(car_name):
			bad += _fail("%s is in no CarCollection gallery (it shows under New Arrivals)" % car_name)
		var model_path: String = p.get("model_path", "")
		if not ResourceLoader.exists(model_path):
			bad += _fail("%s: no model at %s" % [car_name, model_path])
		elif not built.has(model_path):
			bad += _fail("%s: %s is not built by regenerate_cars.gd" % [car_name, model_path])
		elif not factory.has(built[model_path]) and not factory.has(car_name):
			bad += _fail("%s: no factory paint for %s in CarPaint.FACTORY" % [car_name, built[model_path]])
		else:
			var scene := load(model_path) as PackedScene
			var root: Node = scene.instantiate() if scene else null
			if root == null:
				bad += _fail("%s: %s does not load" % [car_name, model_path])
			else:
				for part in (p.get("wheel_parts", {}) as Dictionary).values():
					var wheel := root.find_child(str(part), true, false) as MeshInstance3D
					if wheel == null or wheel.mesh == null or wheel.mesh.get_surface_count() == 0:
						bad += _fail("%s: no wheel mesh %s" % [car_name, part])
				var body := root.find_child("Body", true, false) as MeshInstance3D
				if body == null or body.mesh == null or body.mesh.get_surface_count() == 0:
					bad += _fail("%s: no body mesh" % car_name)
				if root.find_child("AntennaPlacement", true, false) == null:
					bad += _fail("%s: no AntennaPlacement" % car_name)
				root.free()
		var sound_path: String = p.get("engine_sound", "")
		if sound_path.is_empty():
			bad += _fail("%s has no engine_sound" % car_name)
		elif not ResourceLoader.exists(sound_path) or not (load(sound_path) is AudioStream):
			bad += _fail("%s: engine loop %s does not load (import it)" % [car_name, sound_path])
	for car_name in placed:
		if not seen.has(car_name):
			bad += _fail("CarCollection names %s, which is no preset" % car_name)
	print("%d cars checked" % race.size())
	print("RESULT: %s" % ("PASS" if bad == 0 else "FAIL (%d to fix)" % bad))
	quit(0 if bad == 0 else 1)


func _fail(text: String) -> int:
	print("  ", text)
	return 1
