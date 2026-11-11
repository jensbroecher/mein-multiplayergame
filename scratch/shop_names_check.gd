extends SceneTree
## Draws a stage's worth of shop names from ShopNames.gd (a few hundred, as Quer durch Kronburg paints) and prints any
## name drawn twice and a sample of the cafés and brewhouses. Headless:
##   Godot --headless --path . -s res://scratch/shop_names_check.gd
func _init() -> void:
	var SN = load("res://ShopNames.gd")
	SN.reset(4)
	var names := {}
	var kinds := ["cafe", "eis", "restaurant", "shop", "book", "pretzel", "ox", "apotheke", "garage", "window", "kiosk"]
	var counts := {"cafe": 60, "eis": 25, "restaurant": 70, "shop": 120, "book": 10, "pretzel": 15, "ox": 10, "apotheke": 10, "garage": 20, "window": 10, "kiosk": 10}
	var dup := 0
	var words := {}
	for k in kinds:
		for i in counts[k]:
			var n: String = SN.unique(k, "Café Rheinblick" if (k == "cafe" and i < 3) else "")
			if names.has(n):
				dup += 1
				print("DUP ", n)
			names[n] = true
	print("names ", names.size(), " dups ", dup)
	var sample := []
	for n in names.keys():
		if String(n).begins_with("Brauhaus") or String(n).begins_with("Café") or String(n).contains("Rheinblick"):
			sample.append(n)
	print(", ".join(sample.slice(0, 40)))
	quit()
