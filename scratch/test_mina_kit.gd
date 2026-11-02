extends SceneTree
## Builds every MinaKit.gd set piece in memory, headless, and prints its size, surfaces and triangles: a quick check
## that the kit still builds after an edit (scratch/mina_kit_preview.gd renders them).
##   Godot --headless --path . -s res://scratch/test_mina_kit.gd

const MinaKit = preload("res://MinaKit.gd")


func _piece(what: String, build: Callable) -> void:
	var t0 := Time.get_ticks_msec()
	var pk = MinaKit.new_kit(1.0)
	var kit := {}
	build.call(pk, kit)
	var mesh: ArrayMesh = pk.commit(kit)
	var tris := 0
	for si in mesh.get_surface_count():
		tris += (mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	print("%-18s %4d ms  %d surfaces  %6d triangles  size %s" % [what, Time.get_ticks_msec() - t0, mesh.get_surface_count(), tris, mesh.get_aabb().size])


func _init() -> void:
	print("--- MinaKit ---")
	_piece("haul truck", func(pk, kit): MinaKit.haul_truck(pk, kit))
	_piece("loaded truck", func(pk, kit): MinaKit.haul_truck(pk, kit, MinaKit.MINE_YELLOW, true))
	_piece("water truck", func(pk, kit): MinaKit.water_truck(pk, kit))
	_piece("rope shovel", func(pk, kit): MinaKit.rope_shovel(pk, kit))
	_piece("radio dish", func(pk, kit): MinaKit.radio_dish(pk, kit, 0.6, 0.9))
	for b in MinaKit.BALLOONS.size():
		_piece("balloon %d" % b, func(pk, kit): MinaKit.balloon(pk, kit, b))
	_piece("inflating balloon", func(pk, kit): MinaKit.balloon_inflating(pk, kit, 1))
	_piece("light tower", func(pk, kit): MinaKit.light_tower(pk, kit))
	_piece("drill rig", func(pk, kit): MinaKit.drill_rig(pk, kit))
	_piece("tumbleweed", func(pk, kit): MinaKit.tumbleweed(pk, kit, 1))
	_piece("mine gate", func(pk, kit): MinaKit.mine_gate(pk, kit, []))
	_piece("crusher", func(pk, kit): MinaKit.crusher(pk, kit, []))
	_piece("truck shop", func(pk, kit): MinaKit.truck_shop(pk, kit, []))
	_piece("stockpile", func(pk, kit): MinaKit.stockpile(pk, kit, 17.0))
	_piece("thickener", func(pk, kit): MinaKit.thickener(pk, kit, 14.0))
	_piece("grandstand", func(pk, kit): MinaKit.grandstand(pk, kit, 44.0, []))
	_piece("muck pile", func(pk, kit): MinaKit.muck_pile(pk, kit, Vector2(34, 17), 11.0, 0.4))
	_piece("conveyor", func(pk, kit): MinaKit.conveyor_run(pk, kit, [Vector3(0, 2, 20), Vector3(0, 2, 0), Vector3(0, 14, -40)], [1]))
	print("--- done ---")
	quit()
