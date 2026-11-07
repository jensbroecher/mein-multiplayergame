extends SceneTree
## Checks the antenna option (CarPaint.ANTENNAS: off, round, flag): old settings' bools map to off/round, peers' values
## are clamped, and CarAntenna.dress shows the right parts in the accent colour. Headless:
##   Godot --headless --path . -s res://scratch/antenna_style_check.gd
const CarPaint = preload("res://CarPaint.gd")
const CarAntenna = preload("res://CarAntenna.gd")


func _init() -> void:
	var fails := 0
	for c in [[{"antenna": true}, 1], [{"antenna": false}, 0], [{"antenna": 2}, 2], [{"antenna": 7}, 2], [{"antenna": -3}, 0], [{}, 0]]:
		var got: int = CarPaint.antenna_style(CarPaint.sanitize(c[0], "Titan"))
		print("%-18s -> %d %s" % [str(c[0]), got, "ok" if got == c[1] else "FAIL"])
		fails += int(got != c[1])
	var cart: Node = (load("res://PlayerCart.tscn") as PackedScene).instantiate()
	var ant: Node3D = cart.get_node("Visuals/Antenna").duplicate()
	cart.free()
	for style in 3:
		CarAntenna.dress(ant, style, Color(0.2, 0.8, 0.3))
		var tip: MeshInstance3D = ant.get_node("Tip")
		var flag: MeshInstance3D = ant.get_node("Flag")
		var ok: bool = ant.visible == (style > 0) and tip.visible == (style == 1) and flag.visible == (style == 2) \
				and (flag.material_override as StandardMaterial3D).albedo_color == Color(0.2, 0.8, 0.3)
		print("style %d (%s): antenna %s tip %s flag %s %s" % [style, CarPaint.ANTENNAS[style], ant.visible, tip.visible,
				flag.visible, "ok" if ok else "FAIL"])
		fails += int(not ok)
	ant.free()
	print("RESULT: %s" % ("PASS" if fails == 0 else "FAIL"))
	quit()
